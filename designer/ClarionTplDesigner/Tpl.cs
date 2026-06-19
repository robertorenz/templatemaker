using System;
using System.Collections.Generic;
using System.Globalization;
using System.IO;
using System.Linq;
using System.Text.RegularExpressions;

namespace ClarionTplDesigner;

public enum TplKind { Sheet, Tab, Boxed, Button, Enable, Prompt, Display, Image, Unknown }

/// <summary>One parsed prompt-UI element from a Clarion .tpl #SHEET section.</summary>
public class TplElement
{
    public TplKind Kind;
    public int LineIndex = -1;     // 0-based line of this element's directive
    public int EndLineIndex = -1;  // 0-based line of the matching #END... (containers); -1 = single line
    public bool Deleted;           // marked for removal -> its source line(s) are dropped on Save
    public bool Inserted;          // brand-new control with no source yet -> emitted on Save
    public bool Moved;             // existing control reparented/reordered -> its source line relocates on Save
    public int MoveAnchorLine = -1; // emit it before this original source line (reorder); -1 = container end
    public string Title = "";      // tab name / box title / display text / prompt label / image file
    public string Symbol = "";     // %Symbol (prompts/images target a feq)
    public string PromptType = ""; // CHECK / @s255 / SPIN(..) / OPTION / RADIO / OPENDIALOG(..)
    public bool Req;               // ,REQ attribute (entry must be filled)
    public string DefaultExpr = "";// literal inside DEFAULT(...), e.g. '39', %Sym, 'AJE'

    // AT(x,y,w,h) - which slots were present, and their DLU values.
    public bool HasAt, HasX, HasY, HasW, HasH;
    public int X, Y, W, H;

    // PROP(...) styling
    public string FontName = "";
    public int FontSize;
    public uint? FontColor;         // COLORREF 0x00BBGGRR
    public int FontStyle;           // raw PROP(PROP:FontStyle,N); 0 = unset
    public bool Bold;
    public bool FontDirty;          // font/colour/size/style edited -> rewrite its PROP(...) on save

    // computed absolute layout (DLU, tab-relative) used by the designer
    public double LX, LY, LW, LH;
    public bool Dirty;              // moved/resized -> rewrite its AT on save
    public bool HasZ; public int Z; // z-order override (view aid only)

    public TplElement? Parent;
    public readonly List<TplElement> Children = new();

    /// <summary>Deep copy (subtree), used for undo snapshots.</summary>
    public TplElement Clone(TplElement? parent = null)
    {
        var c = new TplElement
        {
            Kind = Kind, LineIndex = LineIndex, EndLineIndex = EndLineIndex,
            Deleted = Deleted, Inserted = Inserted, Moved = Moved, MoveAnchorLine = MoveAnchorLine,
            Title = Title, Symbol = Symbol, PromptType = PromptType, Req = Req, DefaultExpr = DefaultExpr,
            HasAt = HasAt, HasX = HasX, HasY = HasY, HasW = HasW, HasH = HasH,
            X = X, Y = Y, W = W, H = H,
            FontName = FontName, FontSize = FontSize, FontColor = FontColor, FontStyle = FontStyle,
            Bold = Bold, FontDirty = FontDirty,
            LX = LX, LY = LY, LW = LW, LH = LH, Dirty = Dirty, HasZ = HasZ, Z = Z,
            Parent = parent
        };
        foreach (var ch in Children) c.Children.Add(ch.Clone(c));
        return c;
    }

    public bool IsContainer => Kind is TplKind.Tab or TplKind.Boxed or TplKind.Button or TplKind.Enable;
    public bool IsPositionable => Kind is TplKind.Prompt or TplKind.Display or TplKind.Image or TplKind.Boxed;

    public string Display => Kind switch
    {
        TplKind.Prompt  => $"{Title}  {Symbol}".Trim(),
        TplKind.Display => Title.Length == 0 ? "(blank)" : Title,
        TplKind.Image   => Title,
        TplKind.Boxed   => Title,
        _ => Kind.ToString()
    };
}

/// <summary>One physical template file (the main .tpl or an #INCLUDE'd .tpw).</summary>
public class TplFile
{
    public string Path = "";
    public string Newline = "\r\n";
    public string[] Lines = Array.Empty<string>();
    public bool Included;             // pulled in via #INCLUDE (vs the main .tpl)
    public bool Dirty;                // raw Lines edited directly (e.g. a symbol rename swept the whole file)
}

/// <summary>One template component (#EXTENSION/#CONTROL/#PROCEDURE/#CODE/#GROUP/…) and its prompt UI.</summary>
public class TplComponent
{
    public string Kind = "";         // EXTENSION / CONTROL / PROCEDURE / CODE / GROUP / UTILITY / TEMPLATE / …
    public string Name = "";
    public string Description = "";
    public int FileIndex;            // index into TplDocument.Files
    public int StartLine, EndLine;   // line range within that file
    public int SheetEnd = -1;        // line index of this component's #ENDSHEET (anchor for inserting a new #TAB)
    public readonly List<TplElement> Tabs = new();
    public bool HasSheet => Tabs.Count > 0;
}

public class TplDocument
{
    public string Path = "";                       // the main .tpl
    public readonly List<TplFile> Files = new();
    public readonly List<TplComponent> Components = new();
    public string Newline => Files.Count > 0 ? Files[0].Newline : "\r\n";
}

public static class TplParser
{
    static readonly HashSet<string> ComponentKinds = new(StringComparer.OrdinalIgnoreCase)
        { "TEMPLATE", "EXTENSION", "CONTROL", "PROCEDURE", "CODE", "GROUP", "UTILITY", "APPLICATION", "MODULE" };

    public static TplDocument Parse(string path)
    {
        var doc = new TplDocument { Path = path };
        LoadFile(doc, path, included: false, new HashSet<string>(StringComparer.OrdinalIgnoreCase));
        return doc;
    }

    /// <summary>Parse a single file's text in memory (no #INCLUDE following) — used to preview pending edits.</summary>
    public static TplDocument ParseText(string text, string path)
    {
        var doc = new TplDocument { Path = path };
        var nl = text.Contains("\r\n") ? "\r\n" : "\n";
        var lines = text.Split(new[] { nl }, StringSplitOptions.None);
        doc.Files.Add(new TplFile { Path = path, Newline = nl, Lines = lines });
        ParseComponents(doc, 0, lines);
        return doc;
    }

    static void LoadFile(TplDocument doc, string path, bool included, HashSet<string> visited)
    {
        string full;
        try { full = System.IO.Path.GetFullPath(path); } catch { return; }
        if (!visited.Add(full) || !File.Exists(full)) return;

        var text = File.ReadAllText(full);
        var nl = text.Contains("\r\n") ? "\r\n" : "\n";
        var lines = text.Split(new[] { nl }, StringSplitOptions.None);
        int fileIndex = doc.Files.Count;
        doc.Files.Add(new TplFile { Path = full, Newline = nl, Lines = lines, Included = included });

        ParseComponents(doc, fileIndex, lines);

        // follow #INCLUDE('xxx.tpw') (ignoring commented #! lines), relative to this file's folder
        string dir = System.IO.Path.GetDirectoryName(full) ?? ".";
        foreach (var raw in lines)
        {
            var t = raw.TrimStart();
            if (t.StartsWith("#!")) continue;
            var m = Regex.Match(t, @"^#include\s*\(\s*'([^']+)'", RegexOptions.IgnoreCase);
            if (m.Success) LoadFile(doc, System.IO.Path.Combine(dir, m.Groups[1].Value), true, visited);
        }
    }

    static void ParseComponents(TplDocument doc, int fileIndex, string[] lines)
    {
        var starts = new List<int>();
        for (int i = 0; i < lines.Length; i++)
        {
            var t = lines[i].TrimStart();
            if (t.Length == 0 || t[0] != '#' || t.StartsWith("#!")) continue;
            if (ComponentKinds.Contains(Directive(t))) starts.Add(i);
        }
        for (int s = 0; s < starts.Count; s++)
        {
            int start = starts[s];
            int end = (s + 1 < starts.Count ? starts[s + 1] : lines.Length) - 1;
            var comp = NewComponent(lines[start], fileIndex, start, end);
            ParseSheet(lines, start, end, comp);
            doc.Components.Add(comp);
        }
    }

    static TplComponent NewComponent(string line, int fileIndex, int start, int end)
    {
        var t = line.TrimStart();
        var comp = new TplComponent { FileIndex = fileIndex, StartLine = start, EndLine = end };
        var m = Regex.Match(t, @"^#(\w+)\s*\(\s*([^,'()]*)", RegexOptions.IgnoreCase);
        if (m.Success) { comp.Kind = m.Groups[1].Value.ToUpperInvariant(); comp.Name = m.Groups[2].Value.Trim(); }
        else comp.Kind = Directive(t);
        var d = Regex.Match(t, @"'((?:[^']|'')*)'");
        if (d.Success) comp.Description = d.Groups[1].Value.Replace("''", "'");
        return comp;
    }

    static void ParseSheet(string[] lines, int from, int to, TplComponent comp)
    {
        var stack = new Stack<TplElement>();
        var sheetRoot = new TplElement { Kind = TplKind.Sheet };
        bool inSheet = false;

        for (int i = from; i <= to && i < lines.Length; i++)
        {
            var trimmed = lines[i].TrimStart();
            if (trimmed.Length == 0 || trimmed[0] != '#' || trimmed.StartsWith("#!")) continue;
            var dir = Directive(trimmed);

            switch (dir)
            {
                case "SHEET":
                    if (inSheet) continue;
                    inSheet = true; stack.Clear(); stack.Push(sheetRoot); continue;
                case "ENDSHEET":
                    if (inSheet) { comp.SheetEnd = i; return; }   // first sheet of the component only
                    continue;
            }
            if (!inSheet) continue;

            switch (dir)
            {
                case "TAB":
                    var tab = NewEl(TplKind.Tab, lines[i], i);
                    Add(stack, tab); comp.Tabs.Add(tab); stack.Push(tab); break;
                case "ENDTAB": Close(stack, i); break;
                case "BOXED":
                    var box = NewEl(TplKind.Boxed, lines[i], i);
                    Add(stack, box); stack.Push(box); break;
                case "ENDBOXED": Close(stack, i); break;
                case "BUTTON":
                    var btn = NewEl(TplKind.Button, lines[i], i);
                    Add(stack, btn); stack.Push(btn); break;
                case "ENDBUTTON": Close(stack, i); break;
                case "ENABLE":
                    var en = NewEl(TplKind.Enable, lines[i], i);
                    Add(stack, en); stack.Push(en); break;
                case "ENDENABLE": Close(stack, i); break;
                case "PROMPT": Add(stack, NewEl(TplKind.Prompt, lines[i], i)); break;
                case "DISPLAY": Add(stack, NewEl(TplKind.Display, lines[i], i)); break;
                case "IMAGE": Add(stack, NewEl(TplKind.Image, lines[i], i)); break;
            }
        }
    }

    static string Directive(string t)
    {
        int k = 1; while (k < t.Length && (char.IsLetter(t[k]))) k++;
        return t.Substring(1, k - 1).ToUpperInvariant();
    }

    static void Add(Stack<TplElement> s, TplElement e)
    {
        if (s.Count == 0) return;
        var p = s.Peek(); e.Parent = p; p.Children.Add(e);
    }
    static void Pop(Stack<TplElement> s) { if (s.Count > 1) s.Pop(); }
    static void Close(Stack<TplElement> s, int endLine)
    {
        if (s.Count > 1) { var e = s.Pop(); e.EndLineIndex = endLine; }
    }

    static TplElement NewEl(TplKind kind, string line, int idx)
    {
        var e = new TplElement { Kind = kind, LineIndex = idx };
        var q = Regex.Match(line, @"'((?:[^']|'')*)'");
        if (q.Success) e.Title = q.Groups[1].Value.Replace("''", "'");

        if (kind == TplKind.Prompt)
        {
            var pt = Regex.Match(line, @"#PROMPT\(\s*'(?:[^']|'')*'\s*,\s*([^),]+(?:\([^)]*\))?)", RegexOptions.IgnoreCase);
            if (pt.Success) e.PromptType = pt.Groups[1].Value.Trim();
            var sym = Regex.Match(line, @"\)\s*,\s*%(\w+)");
            if (sym.Success) e.Symbol = "%" + sym.Groups[1].Value;
            if (Regex.IsMatch(line, @",\s*REQ\b", RegexOptions.IgnoreCase)) e.Req = true;
            var def = Regex.Match(line, @"\bDEFAULT\(\s*(.*?)\s*\)\s*(?:,|$)", RegexOptions.IgnoreCase);
            if (def.Success) e.DefaultExpr = def.Groups[1].Value.Trim();
        }
        else if (kind is TplKind.Image)
        {
            var sym = Regex.Match(line, @"%(\w+)");
            if (sym.Success && line.Contains("%")) e.Symbol = "";
        }

        ParseAt(line, e);
        ParseProps(line, e);
        return e;
    }

    static void ParseAt(string line, TplElement e)
    {
        var m = Regex.Match(line, @"\bAT\(([^)]*)\)", RegexOptions.IgnoreCase);
        if (!m.Success) return;
        e.HasAt = true;
        var parts = m.Groups[1].Value.Split(',');
        var has = new bool[4]; var val = new int[4];
        for (int k = 0; k < 4 && k < parts.Length; k++)
        {
            var p = parts[k].Trim();
            if (p.Length > 0 && int.TryParse(p, out var v)) { has[k] = true; val[k] = v; }
        }
        e.HasX = has[0]; e.HasY = has[1]; e.HasW = has[2]; e.HasH = has[3];
        e.X = val[0]; e.Y = val[1]; e.W = val[2]; e.H = val[3];
    }

    static void ParseProps(string line, TplElement e)
    {
        var fc = Regex.Match(line, @"PROP\(\s*PROP:FontColor\s*,\s*0?([0-9A-Fa-f]+)H?\s*\)", RegexOptions.IgnoreCase);
        if (fc.Success && uint.TryParse(fc.Groups[1].Value, NumberStyles.HexNumber, CultureInfo.InvariantCulture, out var c))
            e.FontColor = c;
        var fs = Regex.Match(line, @"PROP\(\s*PROP:FontSize\s*,\s*(\d+)\s*\)", RegexOptions.IgnoreCase);
        if (fs.Success) e.FontSize = int.Parse(fs.Groups[1].Value);
        var fn = Regex.Match(line, @"PROP\(\s*PROP:Font\s*,\s*'([^']*)'\s*\)", RegexOptions.IgnoreCase);
        if (fn.Success) e.FontName = fn.Groups[1].Value;
        var fst = Regex.Match(line, @"PROP\(\s*PROP:FontStyle\s*,\s*(\d+)\s*\)", RegexOptions.IgnoreCase);
        if (fst.Success) { e.FontStyle = int.Parse(fst.Groups[1].Value); e.Bold = e.FontStyle >= 600; }
    }
}

public static class TplWriter
{
    /// <summary>Save every file that has pending edits; untouched files (incl. .tpw includes) are left alone.</summary>
    public static void Save(TplDocument doc)
    {
        for (int fi = 0; fi < doc.Files.Count; fi++)
        {
            var tabs = new List<TplElement>();
            foreach (var c in doc.Components)
                if (c.FileIndex == fi) tabs.AddRange(c.Tabs);
            bool changed = doc.Files[fi].Dirty
                        || tabs.Any(t => Flatten(t).Any(e => e.Dirty || e.Inserted || e.Deleted || e.Moved || e.FontDirty));
            if (changed) SaveFile(doc.Files[fi], tabs);
        }
    }

    /// <summary>
    /// Rewrite AT() of moved controls, drop deleted ones, emit added ones, and relocate reparented
    /// ones into their new container — every other byte is preserved.
    /// </summary>
    static void SaveFile(TplFile file, List<TplElement> docTabs)
        => File.WriteAllText(file.Path, string.Join(file.Newline, BuildLines(file, docTabs)));

    /// <summary>The text a file WOULD have after applying all pending edits — not written to disk.</summary>
    public static string PreviewFile(TplDocument doc, int fileIndex)
    {
        if (fileIndex < 0 || fileIndex >= doc.Files.Count) return "";
        var tabs = new List<TplElement>();
        foreach (var c in doc.Components)
            if (c.FileIndex == fileIndex) tabs.AddRange(c.Tabs);
        var file = doc.Files[fileIndex];
        return string.Join(file.Newline, BuildLines(file, tabs));
    }

    static List<string> BuildLines(TplFile file, List<TplElement> docTabs)
    {
        var lines = (string[])file.Lines.Clone();

        // Lines to remove: deleted elements (containers span to #END...) and relocated controls' old line.
        var drop = new HashSet<int>();
        foreach (var tab in docTabs)
            foreach (var e in Flatten(tab))
            {
                if (e.Deleted && e.LineIndex >= 0)
                {
                    int end = e.EndLineIndex >= 0 ? e.EndLineIndex : e.LineIndex;
                    for (int i = e.LineIndex; i <= end && i < lines.Length; i++) drop.Add(i);
                }
                else if (e.Moved && !e.Inserted && e.LineIndex >= 0)
                {
                    int mend = e.EndLineIndex > e.LineIndex ? e.EndLineIndex : e.LineIndex;   // box = whole block
                    for (int i = e.LineIndex; i <= mend && i < lines.Length; i++) drop.Add(i);
                }
            }

        // In-place AT / PROP rewrite for controls that stayed put (not added/relocated/deleted).
        foreach (var tab in docTabs)
            foreach (var e in Flatten(tab))
                if ((e.Dirty || e.FontDirty) && !e.Deleted && !e.Inserted && !e.Moved && e.LineIndex >= 0)
                {
                    // edit the clone in place; a control inside a moved box is re-emitted from these lines
                    if (e.Dirty) lines[e.LineIndex] = ApplyAt(lines[e.LineIndex], e);
                    if (e.FontDirty) lines[e.LineIndex] = ApplyProps(lines[e.LineIndex], e);
                }

        // Emit added/relocated controls just before their (stationary) container's #END line.
        var emit = new Dictionary<int, List<string>>();
        void AddEmit(int anchor, IEnumerable<string> ss)
        {
            if (!emit.TryGetValue(anchor, out var l)) emit[anchor] = l = new List<string>();
            l.AddRange(ss);
        }
        foreach (var tab in docTabs)
            foreach (var owner in Flatten(tab))
            {
                bool stationary = (owner.Kind is TplKind.Tab or TplKind.Boxed or TplKind.Enable or TplKind.Button)
                                  && !owner.Inserted && !owner.Moved && !owner.Deleted && owner.EndLineIndex >= 0;
                if (!stationary) continue;
                foreach (var child in owner.Children)
                    if (!child.Deleted && (child.Inserted || child.Moved))
                    {
                        int anchor = child.MoveAnchorLine >= 0 ? child.MoveAnchorLine : owner.EndLineIndex;
                        AddEmit(anchor, EmitUnit(child, lines));
                    }
            }

        // Top-level #TABs aren't children of a stationary owner, so the loop above can't relocate them.
        // Re-emit inserted tabs and reordered (moved) tabs at their anchor (a sibling tab's open line, or #ENDSHEET).
        foreach (var tab in docTabs)
            if (tab.Kind == TplKind.Tab && !tab.Deleted && (tab.Inserted || tab.Moved) && tab.MoveAnchorLine >= 0)
                AddEmit(tab.MoveAnchorLine, EmitUnit(tab, lines));

        var kept = new List<string>(lines.Length + 16);
        for (int i = 0; i < lines.Length; i++)
        {
            if (emit.TryGetValue(i, out var ins)) kept.AddRange(ins);   // before the #END... line
            if (!drop.Contains(i)) kept.Add(lines[i]);
        }
        if (emit.TryGetValue(lines.Length, out var tail)) kept.AddRange(tail);

        return kept;
    }

    static string Esc(string s) => (s ?? "").Replace("'", "''");

    /// <summary>The source line(s) for one added/relocated control; boxes recurse over their children.</summary>
    static IEnumerable<string> EmitUnit(TplElement e, string[] lines)
    {
        if (e.Kind == TplKind.Tab && e.Inserted)
        {
            yield return GenLine(e);
            foreach (var c in e.Children)
                if (!c.Deleted)
                    foreach (var s in EmitUnit(c, lines)) yield return s;
            yield return "   #ENDTAB";
        }
        else if (e.Kind == TplKind.Boxed && e.Inserted)
        {
            yield return GenLine(e);
            foreach (var c in e.Children)
                if (!c.Deleted)
                    foreach (var s in EmitUnit(c, lines)) yield return s;
            yield return "   #ENDBOXED";
        }
        else if (e.Inserted)
        {
            yield return ApplyProps(GenLine(e), e);  // freshly generated leaf (+ any font set in the panel)
        }
        else if (e.EndLineIndex > e.LineIndex && e.EndLineIndex < lines.Length)
        {
            for (int i = e.LineIndex; i <= e.EndLineIndex; i++)   // existing box: move the whole block verbatim
            {
                string ln = lines[i];
                if (i == e.LineIndex)                              // only the open line carries this box's AT/PROPs
                {
                    if (e.Dirty) ln = ApplyAt(ln, e);
                    if (e.FontDirty) ln = ApplyProps(ln, e);
                }
                yield return ln;
            }
        }
        else if (e.LineIndex >= 0 && e.LineIndex < lines.Length)
        {
            var ln = lines[e.LineIndex];             // existing leaf, kept verbatim except edited AT/PROPs
            if (e.Dirty) ln = ApplyAt(ln, e);
            if (e.FontDirty) ln = ApplyProps(ln, e);
            yield return ln;
        }
    }

    /// <summary>Preview the line as it would be written, applying any pending AT/PROP edits.</summary>
    public static string PreviewLine(string original, TplElement e)
    {
        if (e.Dirty) original = ApplyAt(original, e);
        if (e.FontDirty) original = ApplyProps(original, e);
        return original;
    }

    /// <summary>Update/insert the PROP(PROP:Font/FontColor/FontSize/FontStyle) clauses from the model.</summary>
    static string ApplyProps(string line, TplElement e)
    {
        line = e.FontColor is uint c ? SetProp(line, "FontColor", $"0{c:X}H") : RemoveProp(line, "FontColor");
        if (e.FontSize > 0)        line = SetProp(line, "FontSize", e.FontSize.ToString());
        if (e.FontName.Length > 0) line = SetProp(line, "Font", $"'{Esc(e.FontName)}'");
        if (e.FontStyle > 0)       line = SetProp(line, "FontStyle", e.FontStyle.ToString());
        return line;
    }

    static string SetProp(string line, string prop, string val)
    {
        string clause = $"PROP(PROP:{prop},{val})";
        var m = Regex.Match(line, $@"PROP\(\s*PROP:{prop}\s*,[^)]*\)", RegexOptions.IgnoreCase);
        if (m.Success) return line[..m.Index] + clause + line[(m.Index + m.Length)..];
        int cut = TrailingComment(line);
        if (cut < 0) return line.TrimEnd() + "," + clause;
        return line[..cut].TrimEnd() + "," + clause + " " + line[cut..];
    }

    static string RemoveProp(string line, string prop)
    {
        var m = Regex.Match(line, $@",?\s*PROP\(\s*PROP:{prop}\s*,[^)]*\)", RegexOptions.IgnoreCase);
        return m.Success ? line.Remove(m.Index, m.Length) : line;
    }

    /// <summary>Generate the directive line for a newly-added control (box = its open line only).</summary>
    static string GenLine(TplElement e)
    {
        const string ind = "   ";
        string at = $"AT({e.X},{e.Y},{e.W},{e.H})";
        return e.Kind switch
        {
            TplKind.Tab     => $"{ind}#TAB('{Esc(e.Title)}')",
            TplKind.Display => $"{ind}#DISPLAY('{Esc(e.Title)}'),{at}",
            TplKind.Image   => $"{ind}#IMAGE('{Esc(e.Title)}'),{at}",
            TplKind.Boxed   => $"{ind}#BOXED('{Esc(e.Title)}'),{at}",
            TplKind.Button  => $"{ind}#BUTTON('{Esc(e.Title)}'),{at}",
            TplKind.Prompt  => $"{ind}#PROMPT('{Esc(e.Title)}',{e.PromptType})"
                             + (string.IsNullOrEmpty(e.Symbol) ? "" : $",{e.Symbol}")
                             + $",{at}"
                             + (e.Req ? ",REQ" : "")
                             + (e.DefaultExpr.Length > 0 ? $",DEFAULT({e.DefaultExpr})"
                                : (e.PromptType.Equals("CHECK", StringComparison.OrdinalIgnoreCase) ? ",DEFAULT(%TRUE)" : "")),
            _ => ""
        };
    }

    static IEnumerable<TplElement> Flatten(TplElement e)
    {
        yield return e;
        foreach (var c in e.Children)
            foreach (var x in Flatten(c)) yield return x;
    }

    static string ApplyAt(string line, TplElement e)
    {
        string at = $"AT({e.X},{e.Y},{e.W},{e.H})";
        var m = Regex.Match(line, @"\bAT\([^)]*\)", RegexOptions.IgnoreCase);
        if (m.Success) return line[..m.Index] + at + line[(m.Index + m.Length)..];

        // No AT yet: append before a trailing ! comment, else at end.
        int cut = TrailingComment(line);
        if (cut < 0) return line.TrimEnd() + "," + at;
        return line[..cut].TrimEnd() + "," + at + " " + line[cut..];
    }

    static int TrailingComment(string line)
    {
        bool inStr = false;
        for (int i = 0; i < line.Length; i++)
        {
            char ch = line[i];
            if (ch == '\'') inStr = !inStr;
            else if (ch == '!' && !inStr) return i;
        }
        return -1;
    }
}
