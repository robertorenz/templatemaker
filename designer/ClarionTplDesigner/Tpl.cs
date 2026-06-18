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
    public int LineIndex = -1;     // 0-based line in source (single-line directives)
    public string Title = "";      // tab name / box title / display text / prompt label / image file
    public string Symbol = "";     // %Symbol (prompts/images target a feq)
    public string PromptType = ""; // CHECK / @s255 / SPIN(..) / OPTION / RADIO / OPENDIALOG(..)

    // AT(x,y,w,h) - which slots were present, and their DLU values.
    public bool HasAt, HasX, HasY, HasW, HasH;
    public int X, Y, W, H;

    // PROP(...) styling
    public string FontName = "";
    public int FontSize;
    public uint? FontColor;         // COLORREF 0x00BBGGRR
    public bool Bold;

    // computed absolute layout (DLU, tab-relative) used by the designer
    public double LX, LY, LW, LH;
    public bool Dirty;              // moved/resized -> rewrite its AT on save

    public TplElement? Parent;
    public readonly List<TplElement> Children = new();

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

public class TplDocument
{
    public string Path = "";
    public string Newline = "\r\n";
    public string[] Lines = Array.Empty<string>();
    public readonly List<TplElement> Tabs = new();   // top-level tabs of the first #SHEET
}

public static class TplParser
{
    public static TplDocument Parse(string path)
    {
        var text = File.ReadAllText(path);
        var nl = text.Contains("\r\n") ? "\r\n" : "\n";
        var lines = text.Split(new[] { nl }, StringSplitOptions.None);

        var doc = new TplDocument { Path = path, Newline = nl, Lines = lines };
        var stack = new Stack<TplElement>();
        var sheetRoot = new TplElement { Kind = TplKind.Sheet };
        bool inSheet = false;

        for (int i = 0; i < lines.Length; i++)
        {
            var trimmed = lines[i].TrimStart();
            if (trimmed.Length == 0 || trimmed[0] != '#') continue;
            var dir = Directive(trimmed);

            switch (dir)
            {
                case "SHEET":
                    if (inSheet) break;
                    inSheet = true; stack.Clear(); stack.Push(sheetRoot); continue;
                case "ENDSHEET":
                    if (inSheet) return doc;     // only the first #SHEET, then stop
                    continue;
            }
            if (!inSheet) continue;

            switch (dir)
            {
                case "TAB":
                    var tab = NewEl(TplKind.Tab, lines[i], i);
                    Add(stack, tab); doc.Tabs.Add(tab); stack.Push(tab); break;
                case "ENDTAB": Pop(stack); break;
                case "BOXED":
                    var box = NewEl(TplKind.Boxed, lines[i], i);
                    Add(stack, box); stack.Push(box); break;
                case "ENDBOXED": Pop(stack); break;
                case "BUTTON":
                    var btn = NewEl(TplKind.Button, lines[i], i);
                    Add(stack, btn); stack.Push(btn); break;
                case "ENDBUTTON": Pop(stack); break;
                case "ENABLE":
                    var en = NewEl(TplKind.Enable, lines[i], i);
                    Add(stack, en); stack.Push(en); break;
                case "ENDENABLE": Pop(stack); break;
                case "PROMPT": Add(stack, NewEl(TplKind.Prompt, lines[i], i)); break;
                case "DISPLAY": Add(stack, NewEl(TplKind.Display, lines[i], i)); break;
                case "IMAGE": Add(stack, NewEl(TplKind.Image, lines[i], i)); break;
            }
        }
        return doc;
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
        if (fst.Success) e.Bold = int.Parse(fst.Groups[1].Value) >= 600;
    }
}

public static class TplWriter
{
    /// <summary>Rewrite only the AT() of moved elements; every other byte is preserved.</summary>
    public static void Save(TplDocument doc, string path)
    {
        var lines = (string[])doc.Lines.Clone();
        foreach (var tab in doc.Tabs)
            foreach (var e in Flatten(tab))
                if (e.Dirty && e.LineIndex >= 0)
                    lines[e.LineIndex] = ApplyAt(lines[e.LineIndex], e);

        File.WriteAllText(path, string.Join(doc.Newline, lines));
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
