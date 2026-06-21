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
    public bool Foreign;           // pulled in via #INSERT(%group) from a #GROUP (possibly another file): read-only, never saved
    public int SrcFileIndex = -1;  // file (TplDocument.Files) that LineIndex refers to; -1 = the owning component's file
    public int AnchorLine = -1;    // foreign only: the #INSERT(%group) line in the HOST file to navigate to in the source view
    public int MoveAnchorLine = -1; // emit it before this original source line (reorder); -1 = container end
    public string Title = "";      // tab name / box title / display text / prompt label / image file
    public string Symbol = "";     // %Symbol (prompts/images target a feq)
    public string PromptType = ""; // CHECK / @s255 / SPIN(..) / OPTION / RADIO / OPENDIALOG(..)
    public bool Req;               // ,REQ attribute (entry must be filled)
    public string DefaultExpr = "";// literal inside DEFAULT(...), e.g. '39', %Sym, 'AJE'
    public string Where = "";      // WHERE(...) condition (tab visibility), without the WHERE() wrapper
    public bool Section;           // #BOXED,SECTION: child AT() is relative to THIS box (else tab-absolute)

    // AT(x,y,w,h) - which slots were present, and their DLU values.
    public bool HasAt, HasX, HasY, HasW, HasH;
    public int X, Y, W, H;

    // PROMPTAT(x,y,w,h) - the LABEL position for a #PROMPT, independent of AT (which is the entry control).
    // Clarion draws the label here, NOT inside the AT rectangle.
    public bool HasPromptAt, HasPX, HasPY, HasPW, HasPH;
    public int PX, PY, PW, PH;
    public double PLX, PLY, PLW, PLH;   // computed label rect (DLU, tab-relative)

    // PROP(...) styling
    public string FontName = "";
    public int FontSize;
    public uint? FontColor;         // COLORREF 0x00BBGGRR
    public int FontStyle;           // raw PROP(PROP:FontStyle,N); 0 = unset. Weight (low bits, 400/700) + flags.
    public bool Bold;
    // Clarion FONT style flag bits: italic 0x1000, underline 0x2000, strikeout 0x4000 (added to the weight).
    public bool Italic    => (FontStyle & 0x1000) != 0;
    public bool Underline => (FontStyle & 0x2000) != 0;
    public bool Strikeout => (FontStyle & 0x4000) != 0;
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
            Deleted = Deleted, Inserted = Inserted, Moved = Moved, Foreign = Foreign,
            SrcFileIndex = SrcFileIndex, AnchorLine = AnchorLine, MoveAnchorLine = MoveAnchorLine,
            Title = Title, Symbol = Symbol, PromptType = PromptType, Req = Req, DefaultExpr = DefaultExpr, Where = Where, Section = Section,
            HasAt = HasAt, HasX = HasX, HasY = HasY, HasW = HasW, HasH = HasH,
            X = X, Y = Y, W = W, H = H,
            HasPromptAt = HasPromptAt, HasPX = HasPX, HasPY = HasPY, HasPW = HasPW, HasPH = HasPH,
            PX = PX, PY = PY, PW = PW, PH = PH, PLX = PLX, PLY = PLY, PLW = PLW, PLH = PLH,
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
        // Load every file first (main + #INCLUDE chain), THEN parse — a #GROUP referenced by
        // #INSERT can live in an include that follows the file using it, so the registry of
        // groups must be complete before any #SHEET is resolved.
        LoadFile(doc, path, included: false, new HashSet<string>(StringComparer.OrdinalIgnoreCase));
        var groups = BuildGroupRegistry(doc);
        for (int fi = 0; fi < doc.Files.Count; fi++)
            ParseComponents(doc, fi, doc.Files[fi].Lines, groups);
        return doc;
    }

    /// <summary>Parse a single file's text in memory (no #INCLUDE following) — used to preview pending edits.</summary>
    public static TplDocument ParseText(string text, string path)
    {
        var doc = new TplDocument { Path = path };
        var nl = text.Contains("\r\n") ? "\r\n" : "\n";
        var lines = text.Split(new[] { nl }, StringSplitOptions.None);
        doc.Files.Add(new TplFile { Path = path, Newline = nl, Lines = lines });
        // Single-file preview: only groups defined in this same text resolve (cross-file inserts
        // can't, since the includes aren't loaded here) — that's fine for a transient edit preview.
        ParseComponents(doc, 0, lines, BuildGroupRegistry(doc));
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
        doc.Files.Add(new TplFile { Path = full, Newline = nl, Lines = lines, Included = included });

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

    /// <summary>One #GROUP(%name) body — the lines and range a #INSERT(%name) pastes in.</summary>
    sealed class GroupDef { public string[] Lines = Array.Empty<string>(); public int Start, End, FileIndex; }

    // Index every #GROUP(%name) across all loaded files so #INSERT(%name) inside a #SHEET can be resolved.
    static Dictionary<string, GroupDef> BuildGroupRegistry(TplDocument doc)
    {
        var reg = new Dictionary<string, GroupDef>(StringComparer.OrdinalIgnoreCase);
        for (int fi = 0; fi < doc.Files.Count; fi++)
        {
            var lines = doc.Files[fi].Lines;
            var starts = ComponentStarts(lines);
            for (int s = 0; s < starts.Count; s++)
            {
                int start = starts[s];
                if (!Directive(lines[start].TrimStart()).Equals("GROUP", StringComparison.OrdinalIgnoreCase)) continue;
                var m = Regex.Match(lines[start], @"#group\s*\(\s*(%\w+)", RegexOptions.IgnoreCase);
                if (!m.Success) continue;
                int end = (s + 1 < starts.Count ? starts[s + 1] : lines.Length) - 1;
                reg[m.Groups[1].Value] = new GroupDef { Lines = lines, Start = start, End = end, FileIndex = fi };   // last definition wins
            }
        }
        return reg;
    }

    static List<int> ComponentStarts(string[] lines)
    {
        var starts = new List<int>();
        for (int i = 0; i < lines.Length; i++)
        {
            var t = lines[i].TrimStart();
            if (t.Length == 0 || t[0] != '#' || t.StartsWith("#!")) continue;
            if (ComponentKinds.Contains(Directive(t))) starts.Add(i);
        }
        return starts;
    }

    static void ParseComponents(TplDocument doc, int fileIndex, string[] lines, Dictionary<string, GroupDef> groups)
    {
        var starts = ComponentStarts(lines);
        for (int s = 0; s < starts.Count; s++)
        {
            int start = starts[s];
            int end = (s + 1 < starts.Count ? starts[s + 1] : lines.Length) - 1;
            var comp = NewComponent(lines[start], fileIndex, start, end);
            ParseSheet(lines, start, end, comp, groups);
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

    static void ParseSheet(string[] lines, int from, int to, TplComponent comp, Dictionary<string, GroupDef> groups)
    {
        var stack = new Stack<TplElement>();
        var sheetRoot = new TplElement { Kind = TplKind.Sheet };
        bool inSheet = false;
        var inserting = new HashSet<string>(StringComparer.OrdinalIgnoreCase);   // recursion guard across #INSERTs

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

            HandleElement(dir, lines, i, stack, comp, foreign: false, anchorLine: -1, srcFileIndex: -1, groups, inserting);
        }
    }

    // Build the one prompt-UI element on `lines[i]` and slot it into the current container, or —
    // for #INSERT(%group) — inline that group's prompts here. `foreign` marks inlined (read-only) content;
    // `anchorLine` is the host #INSERT line such content navigates to; `srcFileIndex` is the file `lines` lives in.
    static void HandleElement(string dir, string[] lines, int i, Stack<TplElement> stack, TplComponent comp,
                              bool foreign, int anchorLine, int srcFileIndex, Dictionary<string, GroupDef> groups, HashSet<string> inserting)
    {
        switch (dir)
        {
            case "TAB":
                var tab = NewEl(TplKind.Tab, lines[i], i, foreign, anchorLine, srcFileIndex);
                Add(stack, tab); comp.Tabs.Add(tab); stack.Push(tab); break;
            case "ENDTAB": Close(stack, i); break;
            case "BOXED":
                var box = NewEl(TplKind.Boxed, lines[i], i, foreign, anchorLine, srcFileIndex);
                Add(stack, box); stack.Push(box); break;
            case "ENDBOXED": Close(stack, i); break;
            case "BUTTON":
                var btn = NewEl(TplKind.Button, lines[i], i, foreign, anchorLine, srcFileIndex);
                Add(stack, btn); stack.Push(btn); break;
            case "ENDBUTTON": Close(stack, i); break;
            case "ENABLE":
                var en = NewEl(TplKind.Enable, lines[i], i, foreign, anchorLine, srcFileIndex);
                Add(stack, en); stack.Push(en); break;
            case "ENDENABLE": Close(stack, i); break;
            case "PROMPT": Add(stack, NewEl(TplKind.Prompt, lines[i], i, foreign, anchorLine, srcFileIndex)); break;
            case "DISPLAY": Add(stack, NewEl(TplKind.Display, lines[i], i, foreign, anchorLine, srcFileIndex)); break;
            case "IMAGE": Add(stack, NewEl(TplKind.Image, lines[i], i, foreign, anchorLine, srcFileIndex)); break;
            case "INSERT":
                // top-level insert: anchor inlined content to THIS host line; nested inserts keep the original anchor
                InlineGroup(lines[i], anchorLine >= 0 ? anchorLine : i, stack, comp, groups, inserting);
                break;
        }
    }

    // #INSERT(%group[,args]) inside a sheet pastes the prompts a #GROUP(%group) declares.
    // We parse the group's body in place as children of the current container, flagged read-only and
    // anchored (for source navigation) to `hostAnchor` — the #INSERT line in the file being edited.
    static void InlineGroup(string line, int hostAnchor, Stack<TplElement> stack, TplComponent comp,
                            Dictionary<string, GroupDef> groups, HashSet<string> inserting)
    {
        var m = Regex.Match(line, @"#insert\s*\(\s*(%\w+)", RegexOptions.IgnoreCase);
        if (!m.Success) return;
        string name = m.Groups[1].Value;
        if (!groups.TryGetValue(name, out var g)) return;   // not a prompt group we can see -> leave the tab as-is
        if (!inserting.Add(name)) return;                   // guard against a group inserting itself (directly or via a cycle)

        for (int i = g.Start + 1; i <= g.End && i < g.Lines.Length; i++)
        {
            var trimmed = g.Lines[i].TrimStart();
            if (trimmed.Length == 0 || trimmed[0] != '#' || trimmed.StartsWith("#!")) continue;
            var dir = Directive(trimmed);
            if (dir is "SHEET" or "ENDSHEET" or "GROUP") continue;   // a prompt group has no sheet wrapper of its own
            HandleElement(dir, g.Lines, i, stack, comp, foreign: true, hostAnchor, g.FileIndex, groups, inserting);
        }

        inserting.Remove(name);
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

    static TplElement NewEl(TplKind kind, string line, int idx, bool foreign = false, int anchorLine = -1, int srcFileIndex = -1)
    {
        var e = new TplElement { Kind = kind, LineIndex = idx, Foreign = foreign, AnchorLine = anchorLine, SrcFileIndex = srcFileIndex };
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

        var wh = Regex.Match(line, @"\bWHERE\(\s*(.*?)\s*\)\s*(?:,|$)", RegexOptions.IgnoreCase);
        if (wh.Success) e.Where = wh.Groups[1].Value.Trim();

        if (kind == TplKind.Boxed && Regex.IsMatch(line, @",\s*SECTION\b", RegexOptions.IgnoreCase))
            e.Section = true;

        ParseAt(line, e);
        if (kind == TplKind.Prompt) ParsePromptAt(line, e);
        ParseProps(line, e);
        return e;
    }

    // PROMPTAT(x,y,w,h) - the label position. \bAT\( does NOT match inside PROMPTAT( (no word boundary), so
    // ParseAt/ApplyAt never touch this; we parse it separately here.
    static void ParsePromptAt(string line, TplElement e)
    {
        var m = Regex.Match(line, @"\bPROMPTAT\(([^)]*)\)", RegexOptions.IgnoreCase);
        if (!m.Success) return;
        e.HasPromptAt = true;
        var parts = m.Groups[1].Value.Split(',');
        var has = new bool[4]; var val = new int[4];
        for (int k = 0; k < 4 && k < parts.Length; k++)
        {
            var p = parts[k].Trim();
            if (p.Length > 0 && int.TryParse(p, out var v)) { has[k] = true; val[k] = v; }
        }
        e.HasPX = has[0]; e.HasPY = has[1]; e.HasPW = has[2]; e.HasPH = has[3];
        e.PX = val[0]; e.PY = val[1]; e.PW = val[2]; e.PH = val[3];
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
        // The face name is PROP:FontName (PROP:Font is the 4-value array). Accept the legacy bare PROP:Font
        // too so older templates still load; it is rewritten to PROP:FontName on save.
        var fn = Regex.Match(line, @"PROP\(\s*PROP:Font(?:Name)?\s*,\s*'([^']*)'\s*\)", RegexOptions.IgnoreCase);
        if (fn.Success) e.FontName = fn.Groups[1].Value;
        // Legacy bare PROP:Font (wrong property for the face): flag it so a save rewrites it to PROP:FontName.
        if (Regex.IsMatch(line, @"PROP\(\s*PROP:Font\s*,\s*'", RegexOptions.IgnoreCase)) e.FontDirty = true;
        var fst = Regex.Match(line, @"PROP\(\s*PROP:FontStyle\s*,\s*(\d+)\s*\)", RegexOptions.IgnoreCase);
        if (fst.Success) { e.FontStyle = int.Parse(fst.Groups[1].Value); e.Bold = (e.FontStyle & 0xFFF) >= 600; }
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

        // The designer positions a box's children with BOX-RELATIVE coordinates, but Clarion only honours
        // that when the box carries SECTION; without it AppGen reads each child AT as tab-absolute and they
        // pile up at the window top. So any box that holds a positioned child must be a SECTION box. Set the
        // flag (so GenLine/EmitUnit emit it for new/moved boxes) and patch the open line of existing boxes
        // directly here — without touching Dirty, so this is safe to run during a read-only preview too.
        foreach (var tab in docTabs)
            foreach (var e in Flatten(tab))
                if (e.Kind == TplKind.Boxed && !e.Deleted
                    && e.Children.Any(c => !c.Deleted && c.IsPositionable && (c.HasX || c.HasY)))
                {
                    e.Section = true;
                    if (!e.Inserted && !e.Moved && e.LineIndex >= 0 && e.LineIndex < lines.Length)
                        lines[e.LineIndex] = EnsureSection(lines[e.LineIndex], e);
                }

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
                    if (e.Dirty) lines[e.LineIndex] = ApplyPromptAt(lines[e.LineIndex], e);
                    if (e.FontDirty) lines[e.LineIndex] = ApplyProps(lines[e.LineIndex], e);
                    lines[e.LineIndex] = EnsureSection(lines[e.LineIndex], e);
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
                    ln = EnsureSection(ln, e);
                }
                yield return ln;
            }
        }
        else if (e.LineIndex >= 0 && e.LineIndex < lines.Length)
        {
            var ln = lines[e.LineIndex];             // existing leaf, kept verbatim except edited AT/PROPs
            if (e.Dirty) ln = ApplyAt(ln, e);
            if (e.Dirty) ln = ApplyPromptAt(ln, e);
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
        line = RemoveProp(line, "Font");   // drop any legacy PROP(PROP:Font,'x') - the face goes in PROP:FontName
        if (e.FontName.Length > 0) line = SetProp(line, "FontName", $"'{Esc(e.FontName)}'");
        else                       line = RemoveProp(line, "FontName");
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
            TplKind.Tab     => $"{ind}#TAB('{Esc(e.Title)}')" + (e.Where.Length > 0 ? $",WHERE({e.Where})" : ""),
            TplKind.Display => $"{ind}#DISPLAY('{Esc(e.Title)}'),{at}",
            TplKind.Image   => $"{ind}#IMAGE('{Esc(e.Title)}'),{at}",
            TplKind.Boxed   => $"{ind}#BOXED('{Esc(e.Title)}')" + (e.Section ? ",SECTION" : "") + $",{at}",
            TplKind.Button  => $"{ind}#BUTTON('{Esc(e.Title)}'),{at}",
            TplKind.Prompt  => $"{ind}#PROMPT('{Esc(e.Title)}',{e.PromptType})"
                             + (string.IsNullOrEmpty(e.Symbol) ? "" : $",{e.Symbol}")
                             + (e.HasPromptAt ? $",PROMPTAT({e.PX},{e.PY})" : "")
                             + $",{at}"
                             + (e.Req ? ",REQ" : "")
                             + (e.DefaultExpr.Length > 0 ? $",DEFAULT({e.DefaultExpr})"
                                : (e.PromptType.Equals("CHECK", StringComparison.OrdinalIgnoreCase) ? ",DEFAULT(%TRUE)" : "")),
            _ => ""
        };
    }

    static IEnumerable<TplElement> Flatten(TplElement e)
    {
        if (e.Foreign) yield break;   // #INSERT(%group) content is read-only: never dropped, rewritten or re-emitted
        yield return e;
        foreach (var c in e.Children)
            foreach (var x in Flatten(c)) yield return x;
    }

    // Insert ,SECTION into a #BOXED open line (right after #BOXED or #BOXED('title')) when the box is flagged
    // SECTION and the line doesn't already carry it. No-op for non-boxes / non-section / already-present.
    static string EnsureSection(string line, TplElement e)
    {
        if (e.Kind != TplKind.Boxed || !e.Section) return line;
        if (Regex.IsMatch(line, @",\s*SECTION\b", RegexOptions.IgnoreCase)) return line;
        var m = Regex.Match(line, @"#BOXED\s*(\(\s*'(?:[^']|'')*'\s*\))?", RegexOptions.IgnoreCase);
        if (!m.Success) return line;
        int at = m.Index + m.Length;
        return line[..at] + ",SECTION" + line[at..];
    }

    // Update/insert PROMPTAT(x,y) - the label position - for a #PROMPT the designer has positioned.
    static string ApplyPromptAt(string line, TplElement e)
    {
        if (e.Kind != TplKind.Prompt || !e.HasPromptAt) return line;
        string pat = $"PROMPTAT({e.PX},{e.PY})";
        var m = Regex.Match(line, @"\bPROMPTAT\([^)]*\)", RegexOptions.IgnoreCase);
        if (m.Success) return line[..m.Index] + pat + line[(m.Index + m.Length)..];
        int cut = TrailingComment(line);
        if (cut < 0) return line.TrimEnd() + "," + pat;
        return line[..cut].TrimEnd() + "," + pat + " " + line[cut..];
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
