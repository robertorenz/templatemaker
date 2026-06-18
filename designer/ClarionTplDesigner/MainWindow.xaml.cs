using System;
using System.Collections.Generic;
using System.Globalization;
using System.Linq;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Input;
using System.Windows.Media;
using System.Windows.Media.Imaging;
using System.Windows.Shapes;
using System.Text.RegularExpressions;
using Microsoft.Win32;

namespace ClarionTplDesigner;

public partial class MainWindow : Window
{
    TplDocument? _doc;
    TplComponent? _component;          // the template part currently being edited
    List<TplComponent> _parts = new(); // selectable parts (components that have a prompt sheet)
    TplElement? _tab;
    TplElement? _sel;

    double Scale => sldZoom.Value;          // pixels per DLU
    int GridStep => int.TryParse(txtGrid.Text, out var g) && g > 0 ? g : 5;
    const double SnapPx = 6;                 // snap threshold in pixels

    readonly Dictionary<TplElement, Border> _chips = new();
    readonly Dictionary<TplElement, int> _z = new();        // per-element z-order overrides
    readonly Dictionary<string, BitmapImage?> _imgCache = new(StringComparer.OrdinalIgnoreCase);
    readonly List<Guide> _guides = new();

    enum Drag { None, Element, Guide, Resize }
    Drag _drag = Drag.None;
    TplElement? _dragEl;
    Guide? _dragGuide;
    Point _dragStart;
    double _elStartX, _elStartY;
    bool _suppressProp;
    bool _ready;          // true once XAML is fully constructed
    List<TplElement>? _childList;     // controls listed for the selected group box
    bool _suppressChildSel;

    [Flags] enum Edge { None = 0, Left = 1, Right = 2, Top = 4, Bottom = 8 }
    Edge _resizeEdge;
    double _rStartX, _rStartY, _rStartW, _rStartH;   // selection rect (DLU) at resize start
    readonly List<Rectangle> _handles = new();
    const double MinDlu = 4, HandlePx = 8;

    public MainWindow()
    {
        InitializeComponent();
        KeyDown += OnKeyDown;
        _ready = true;
    }

    // ---------- file ----------
    void Open_Click(object s, RoutedEventArgs e)
    {
        var dlg = new OpenFileDialog { Filter = "Clarion template (*.tpl;*.tpw)|*.tpl;*.tpw|All files|*.*" };
        if (dlg.ShowDialog() != true) return;
        try
        {
            _doc = TplParser.Parse(dlg.FileName);
            Title = "Clarion Template Designer — " + System.IO.Path.GetFileName(dlg.FileName);
            PopulateParts(0, 0);
            int files = _doc.Files.Count, comps = _doc.Components.Count;
            status.Text = $"Loaded {_parts.Count} editable part(s) of {comps} component(s) across {files} file(s). "
                        + "Pick a Part, then a Tab.";
        }
        catch (Exception ex) { MessageBox.Show("Parse failed:\n" + ex.Message); }
    }

    void PopulateParts(int partIdx, int tabIdx)
    {
        if (_doc == null) return;
        _parts = _doc.Components.Where(c => c.HasSheet).ToList();
        cmbParts.ItemsSource = _parts.Select(PartLabel).ToList();
        _pendingTabIdx = tabIdx;
        if (_parts.Count > 0) cmbParts.SelectedIndex = Math.Min(Math.Max(partIdx, 0), _parts.Count - 1);
        else { cmbParts.SelectedIndex = -1; _component = null; _tab = null; cmbTabs.ItemsSource = null; Render(); }
    }

    string PartLabel(TplComponent c)
    {
        string title = c.Description.Length > 0 ? c.Description : c.Name;
        string file = _doc != null && c.FileIndex > 0 ? $"[{System.IO.Path.GetFileName(_doc.Files[c.FileIndex].Path)}] " : "";
        return $"{file}{c.Kind}: {title}";
    }

    void Save_Click(object s, RoutedEventArgs e)
    {
        if (_doc == null) return;
        try
        {
            bool structural = AllElements().Any(el => el.Inserted || el.Deleted || el.Moved);
            TplWriter.Save(_doc);
            if (structural) ReloadFromDisk();      // re-sync the model so re-saving can't duplicate/re-drop
            status.Text = "Saved " + System.IO.Path.GetFileName(_doc.Path);
        }
        catch (Exception ex) { MessageBox.Show("Save failed:\n" + ex.Message); }
    }

    void ReloadFromDisk()
    {
        if (_doc == null) return;
        int partIdx = cmbParts.SelectedIndex, tabIdx = cmbTabs.SelectedIndex;
        _doc = TplParser.Parse(_doc.Path);
        _sel = null; _z.Clear();
        PopulateParts(partIdx, tabIdx);
    }

    // Give every positionable control an explicit AT(x,y,w,h) from the current layout,
    // filling only the missing slots so existing coordinates are kept. Makes everything draggable.
    void MaterializeAll_Click(object s, RoutedEventArgs e)
    {
        if (_doc == null || _component == null) { status.Text = "Open a template and pick a part first."; return; }

        int special = _component.Tabs.SelectMany(Positionable).Count(el => el.Kind == TplKind.Prompt && !el.Deleted
                                                && !(el.HasX && el.HasY) && ClassifyPrompt(el.PromptType).Special);
        var msg = "“Add AT to all” gives the controls in this part an explicit AT(x,y,w,h) from the designer’s "
                + "APPROXIMATE layout, so they can all be dragged.\n\n"
                + "Prompts that Clarion auto-builds with a dropdown or “…” button will be SKIPPED — pinning "
                + "those tends to move or hide the auto-generated part. "
                + (special > 0 ? $"{special} such prompt(s) will be left for Clarion to lay out.\n\n" : "\n")
                + "Add AT to the remaining controls?";
        if (MessageBox.Show(msg, "Add AT to all",
                MessageBoxButton.YesNo, MessageBoxImage.Warning, MessageBoxResult.No) != MessageBoxResult.Yes)
        {
            status.Text = "“Add AT to all” cancelled.";
            return;
        }

        int n = 0, skipped = 0;
        foreach (var tab in _component.Tabs)
        {
            Layout.Run(tab);
            foreach (var el in Positionable(tab))
            {
                if (el.Kind == TplKind.Prompt && ClassifyPrompt(el.PromptType).Special) { skipped++; continue; }
                if (MaterializeAt(el)) n++;
            }
        }
        Render();
        status.Text = $"Gave explicit AT() to {n} control(s)"
                    + (skipped > 0 ? $"; left {skipped} auto-built prompt(s) for Clarion to position" : "")
                    + ".  Drag to position, then Save.";
    }

    bool MaterializeAt(TplElement el)
    {
        bool changed = !(el.HasX && el.HasY && el.HasW && el.HasH);
        var (ox, oy) = FrameOrigin(el);
        if (!el.HasX) el.X = (int)Math.Round(el.LX - ox);
        if (!el.HasY) el.Y = (int)Math.Round(el.LY - oy);
        if (!el.HasW) el.W = (int)Math.Round(el.LW);
        if (!el.HasH) el.H = (int)Math.Round(el.LH);
        el.HasX = el.HasY = el.HasW = el.HasH = true;
        if (changed) el.Dirty = true;
        return changed;
    }

    // ---------- add controls ----------
    int _addN;   // cascades the drop position of successive new controls

    void Add_Label_Click(object s, RoutedEventArgs e)  => AddControl(TplKind.Display, "Label", "", 80, 11);
    void Add_String_Click(object s, RoutedEventArgs e) => AddControl(TplKind.Prompt, "Text:", "@s255", 120, 11);
    void Add_Number_Click(object s, RoutedEventArgs e) => AddControl(TplKind.Prompt, "Number:", "@n8", 80, 11);
    void Add_Spin_Click(object s, RoutedEventArgs e)   => AddControl(TplKind.Prompt, "Count:", "SPIN(@n3,0,100)", 90, 11);
    void Add_Check_Click(object s, RoutedEventArgs e)  => AddControl(TplKind.Prompt, "Enabled", "CHECK", 110, 11);
    void Add_Image_Click(object s, RoutedEventArgs e)  => AddControl(TplKind.Image, "image.png", "", 16, 16);
    void Add_Group_Click(object s, RoutedEventArgs e)  => AddControl(TplKind.Boxed, "Group", "", 200, 60);

    void AddControl(TplKind kind, string title, string promptType, int w, int h)
    {
        if (_doc == null || _tab == null)
        {
            MessageBox.Show("Open a template and select a tab first.", "Add control",
                MessageBoxButton.OK, MessageBoxImage.Information);
            return;
        }
        var el = new TplElement
        {
            Kind = kind, Inserted = true, Dirty = true, Parent = _tab,
            Title = title, PromptType = promptType,
            Symbol = kind == TplKind.Prompt ? NewSymbol() : ""
        };
        _addN = (_addN + 1) % 16;
        el.X = 12 + _addN * 4; el.Y = 12 + _addN * 6; el.W = w; el.H = h;
        el.HasX = el.HasY = el.HasW = el.HasH = true;
        _tab.Children.Add(el);
        Render();
        Select(el);
        status.Text = $"Added {kind} \"{title}\".  Drag to position, edit its text in the panel, then Save.";
    }

    string NewSymbol()
    {
        var used = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
        foreach (var f in _doc?.Files ?? Enumerable.Empty<TplFile>())
            foreach (var l in f.Lines)
                foreach (Match m in Regex.Matches(l, @"%[A-Za-z]\w*")) used.Add(m.Value);
        foreach (var e in AllElements())
            if (!string.IsNullOrEmpty(e.Symbol)) used.Add(e.Symbol);

        int n = 1; string sym;
        do { sym = "%NewField" + n++; } while (used.Contains(sym));
        return sym;
    }

    IEnumerable<TplElement> AllElements()
    {
        if (_doc == null) yield break;
        foreach (var c in _doc.Components)
            foreach (var t in c.Tabs)
                foreach (var e in Flat(t)) yield return e;
    }

    // The raw source line(s) of a control, so the panel shows its full definition
    // (default(...), req, prop(...), at(10), etc.) — read-only.
    string SourceOf(TplElement? el)
    {
        if (el == null) return "";
        if (el.Inserted) return "(new control — written to the template on Save)";
        var f = CurrentFile();
        if (f == null || el.LineIndex < 0 || el.LineIndex >= f.Lines.Length) return "";
        string s = f.Lines[el.LineIndex].Trim();
        if (el.EndLineIndex > el.LineIndex)            // container: note the span
            s += $"\n…\n{f.Lines[Math.Min(el.EndLineIndex, f.Lines.Length - 1)].Trim()}"
               + $"   ({el.EndLineIndex - el.LineIndex + 1} lines)";
        return s;
    }

    TplFile? CurrentFile()
    {
        if (_doc == null || _doc.Files.Count == 0) return null;
        int fi = _component?.FileIndex ?? 0;
        return fi >= 0 && fi < _doc.Files.Count ? _doc.Files[fi] : _doc.Files[0];
    }
    static IEnumerable<TplElement> Flat(TplElement e)
    {
        yield return e;
        foreach (var c in e.Children)
            foreach (var x in Flat(c)) yield return x;
    }

    // ---------- part / tab / render ----------
    int _pendingTabIdx;   // tab to select after the next Part_Changed populates cmbTabs

    void Part_Changed(object s, SelectionChangedEventArgs e)
    {
        if (_doc == null || cmbParts.SelectedIndex < 0 || cmbParts.SelectedIndex >= _parts.Count) return;
        _component = _parts[cmbParts.SelectedIndex];
        Select(null);
        cmbTabs.ItemsSource = _component.Tabs.Select(t => t.Title).ToList();
        int want = _pendingTabIdx; _pendingTabIdx = 0;
        if (_component.Tabs.Count > 0) cmbTabs.SelectedIndex = Math.Min(Math.Max(want, 0), _component.Tabs.Count - 1);
        else { _tab = null; Render(); }
    }

    void Tab_Changed(object s, SelectionChangedEventArgs e)
    {
        if (_component == null || cmbTabs.SelectedIndex < 0 || cmbTabs.SelectedIndex >= _component.Tabs.Count) return;
        _tab = _component.Tabs[cmbTabs.SelectedIndex];
        Select(null);
        Render();
    }

    void Zoom_Changed(object s, RoutedPropertyChangedEventArgs<double> e) => Render();

    void Render()
    {
        if (!_ready) return;
        canvas.Children.Clear();
        _chips.Clear();
        _handles.Clear();
        if (_tab == null) return;

        Layout.Run(_tab);

        double maxX = 200, maxY = 200;
        foreach (var el in Positionable(_tab))
        {
            AddChip(el);
            maxX = Math.Max(maxX, (el.LX + el.LW));
            maxY = Math.Max(maxY, (el.LY + el.LH));
        }
        canvas.Width = (maxX + 40) * Scale;
        canvas.Height = (maxY + 60) * Scale;

        foreach (var g in _guides) AddGuideVisual(g);

        UpdateRulers();
        if (_sel != null && _chips.TryGetValue(_sel, out var b)) Highlight(b, true);
        ShowHandles(_sel);
    }

    IEnumerable<TplElement> Positionable(TplElement c)
    {
        foreach (var ch in c.Children)
        {
            if (ch.Deleted) continue;
            if (ch.IsPositionable) yield return ch;
            foreach (var x in Positionable(ch)) yield return x;
        }
    }

    void DeleteControl(TplElement el)
    {
        var refs = ExternalReferences(el);
        if (refs.Count > 0)
        {
            string detail = string.Join("\n", refs.Select(r =>
            {
                var ln = r.Lines.Take(8).Select(n => (n + 1).ToString());
                return $"   {r.Symbol}  —  line {string.Join(", ", ln)}{(r.Lines.Count > 8 ? ", …" : "")}";
            }));
            int total = refs.Sum(r => r.Lines.Count);
            var msg = $"This control's symbol{(refs.Count > 1 ? "s are" : " is")} referenced "
                    + $"{total} other place(s) in this template:\n\n{detail}\n\n"
                    + "Those references are usually the template's generation/logic code. Deleting this "
                    + "control removes where the symbol is set, leaving them dangling — which can break code "
                    + "generation.\n\nDelete anyway?";
            if (MessageBox.Show(msg, "Symbol is referenced — deleting is risky",
                    MessageBoxButton.YesNo, MessageBoxImage.Warning, MessageBoxResult.No) != MessageBoxResult.Yes)
            {
                status.Text = $"Delete cancelled — {el.Display} is referenced elsewhere in the template.";
                return;
            }
        }

        el.Deleted = true;
        if (_sel == el) Select(null);
        Render();
        bool block = el.EndLineIndex >= 0;
        status.Text = $"Deleted {el.Display}"
                    + (block ? " and its contents" : "") + ".  Save to write the change (re-open to undo).";
    }

    // Symbols defined within this control's subtree (a #BOXED carries its child prompts' symbols).
    static IEnumerable<string> SubtreeSymbols(TplElement el)
    {
        if (!string.IsNullOrEmpty(el.Symbol)) yield return el.Symbol;
        foreach (var c in el.Children)
            foreach (var s in SubtreeSymbols(c)) yield return s;
    }

    // Lines OUTSIDE this control's own source range that reference any of its symbols.
    List<(string Symbol, List<int> Lines)> ExternalReferences(TplElement el)
    {
        var result = new List<(string, List<int>)>();
        var file = CurrentFile();
        if (file == null) return result;
        var lines = file.Lines;
        int start = el.LineIndex, end = el.EndLineIndex >= 0 ? el.EndLineIndex : el.LineIndex;

        foreach (var sym in SubtreeSymbols(el).Distinct())
        {
            // match %Symbol not followed by another identifier char (so %Foo doesn't match %FooBar)
            var rx = new Regex(Regex.Escape(sym) + @"(?![A-Za-z0-9_])");
            var hits = new List<int>();
            for (int i = 0; i < lines.Length; i++)
            {
                if (i >= start && i <= end) continue;
                if (rx.IsMatch(lines[i])) hits.Add(i);
            }
            if (hits.Count > 0) result.Add((sym, hits));
        }
        return result;
    }

    void AddChip(TplElement el)
    {
        bool box = el.Kind == TplKind.Boxed;
        var brush = el.Kind switch
        {
            TplKind.Boxed => Brushes.Transparent,
            TplKind.Image => new SolidColorBrush(Color.FromRgb(225, 236, 250)),
            TplKind.Prompt => new SolidColorBrush(Color.FromRgb(238, 243, 249)),
            _ => new SolidColorBrush(Color.FromRgb(247, 249, 252))
        };
        var border = new Border
        {
            Background = brush,
            BorderBrush = box ? new SolidColorBrush(Color.FromRgb(150, 160, 175))
                              : new SolidColorBrush(Color.FromRgb(200, 208, 218)),
            BorderThickness = new Thickness(1),
            CornerRadius = new CornerRadius(box ? 2 : 1),
            Width = Math.Max(6, el.LW * Scale),
            Height = Math.Max(6, el.LH * Scale),
            Tag = el,
            Cursor = Cursors.SizeAll
        };
        BitmapImage? bmp = el.Kind == TplKind.Image ? ResolveImage(el.Title) : null;
        if (bmp != null)
        {
            border.Background = Brushes.Transparent;
            border.BorderBrush = new SolidColorBrush(Color.FromRgb(175, 185, 200));
            if (!el.HasW) border.Width = bmp.PixelWidth;     // no explicit size -> native pixels
            if (!el.HasH) border.Height = bmp.PixelHeight;
            border.Child = new Image
            {
                Source = bmp, Stretch = Stretch.Uniform, StretchDirection = StretchDirection.Both,
                SnapsToDevicePixels = true
            };
        }
        else if (!box)
        {
            var fg = el.FontColor is uint c ? FromColorRef(c) : Brushes.Black;
            string txt = el.Kind == TplKind.Image ? "🖼 " + el.Display : el.Display;   // missing image -> show filename
            var label = new TextBlock
            {
                Text = txt,
                Foreground = el.Kind == TplKind.Image && el.FontColor is null
                             ? new SolidColorBrush(Color.FromRgb(150, 110, 60)) : fg,
                FontWeight = el.Bold ? FontWeights.Bold : FontWeights.Normal,
                FontSize = Math.Max(8, (el.FontSize > 0 ? el.FontSize : 9)),
                Margin = new Thickness(2, 0, 2, 0),
                TextTrimming = TextTrimming.CharacterEllipsis,
                VerticalAlignment = VerticalAlignment.Center
            };

            string glyph = el.Kind == TplKind.Prompt ? ClassifyPrompt(el.PromptType).Glyph : "";
            if (glyph.Length > 0)
            {
                // simulate the auto-generated companion control (dropdown ▾ / lookup … button)
                var dock = new DockPanel { LastChildFill = true };
                var btn = new Border
                {
                    Background = new SolidColorBrush(Color.FromRgb(0xEC, 0xEF, 0xF3)),
                    BorderBrush = new SolidColorBrush(Color.FromRgb(0xB8, 0xC0, 0xCC)),
                    BorderThickness = new Thickness(1),
                    Margin = new Thickness(2, 1, 1, 1),
                    Child = new TextBlock
                    {
                        Text = glyph, FontSize = 9,
                        Foreground = new SolidColorBrush(Color.FromRgb(0x5B, 0x68, 0x78)),
                        HorizontalAlignment = HorizontalAlignment.Center,
                        VerticalAlignment = VerticalAlignment.Center,
                        Margin = new Thickness(3, 0, 3, 0)
                    }
                };
                DockPanel.SetDock(btn, Dock.Right);
                dock.Children.Add(btn);
                dock.Children.Add(label);
                border.Child = dock;
            }
            else border.Child = label;
        }
        else
        {
            border.Child = new TextBlock
            {
                Text = el.Title, Foreground = new SolidColorBrush(Color.FromRgb(90, 100, 115)),
                FontSize = 9, Margin = new Thickness(3, 1, 0, 0), VerticalAlignment = VerticalAlignment.Top
            };
        }
        Canvas.SetLeft(border, el.LX * Scale);
        Canvas.SetTop(border, el.LY * Scale);
        Panel.SetZIndex(border, _z.TryGetValue(el, out var zo) ? zo : (box ? 0 : 5));
        border.ContextMenu = BuildChipMenu(el);
        border.MouseLeftButtonDown += Chip_Down;
        canvas.Children.Add(border);
        _chips[el] = border;
    }

    // ---------- prompt-type awareness ----------
    // Classify a #PROMPT type into a friendly description, an affordance glyph, and whether Clarion
    // auto-builds a companion control (dropdown / lookup button) that the designer can't reposition.
    static (string Desc, string Glyph, bool Special) ClassifyPrompt(string promptType)
    {
        string t = (promptType ?? "").Trim();
        string u = t.ToUpperInvariant();
        bool Has(string s) => u.Contains(s);

        if (u.StartsWith("PROCEDURE")) return ("procedure dropdown", "▾", true);
        if (Has("KEYCODE"))           return ("key picker (Input Key dialog)", "…", true);
        if (Has("OPENDIALOG") || Has("SAVEDIALOG") || Has("FILEDIALOG")) return ("file picker", "…", true);
        if (Has("FONTDIALOG") || u == "FONT")   return ("font picker", "…", true);
        if (Has("COLORDIALOG") || u == "COLOR") return ("colour picker", "…", true);
        if (u.StartsWith("EXPR"))     return ("expression editor", "…", true);
        if (u.StartsWith("FILE"))     return ("table dropdown", "▾", true);
        if (u.StartsWith("FIELD") || u.StartsWith("KEY") || u.StartsWith("COMPONENT"))
                                      return ("field/key dropdown", "▾", true);
        if (u.StartsWith("DROP") || u.StartsWith("FROM")) return ("drop-down list", "▾", true);
        if (u.StartsWith("SPIN"))     return ("spin entry", "⇅", false);
        if (u == "CHECK")             return ("checkbox", "", false);
        if (u.StartsWith("OPTION"))   return ("option group", "", false);
        if (u.StartsWith("RADIO"))    return ("radio button", "", false);
        if (t.StartsWith("@"))        return ($"entry  {t}", "", false);
        return (t.Length == 0 ? "entry" : t, "", false);
    }

    // ---------- images ----------
    BitmapImage? ResolveImage(string file)
    {
        if (string.IsNullOrWhiteSpace(file)) return null;
        if (_imgCache.TryGetValue(file, out var cached)) return cached;

        string? path = FindImage(file);
        BitmapImage? bmp = null;
        if (path != null)
        {
            try
            {
                bmp = new BitmapImage();
                bmp.BeginInit();
                bmp.CacheOption = BitmapCacheOption.OnLoad;   // don't lock the file
                bmp.CreateOptions = BitmapCreateOptions.IgnoreColorProfile;
                bmp.UriSource = new Uri(path);
                bmp.EndInit();
                bmp.Freeze();
            }
            catch { bmp = null; }
        }
        _imgCache[file] = bmp;
        return bmp;
    }

    string? FindImage(string file)
    {
        if (System.IO.Path.IsPathRooted(file) && System.IO.File.Exists(file)) return file;
        foreach (var dir in ImageSearchDirs())
        {
            var p = System.IO.Path.Combine(dir, file);
            if (System.IO.File.Exists(p)) return p;
        }
        return null;
    }

    IEnumerable<string> ImageSearchDirs()
    {
        if (_doc != null) yield return System.IO.Path.GetDirectoryName(_doc.Path) ?? ".";
        yield return @"C:\clarion12\accessory\template\win";
        yield return @"C:\clarion12\images";
    }

    // A bare file name if the picked file lives in a search dir, else the full path (both resolve & render).
    string ChooseImageRef(string fullPath)
    {
        string dir = System.IO.Path.GetDirectoryName(fullPath) ?? "";
        foreach (var sd in ImageSearchDirs())
        {
            try { if (string.Equals(System.IO.Path.GetFullPath(dir).TrimEnd('\\'), System.IO.Path.GetFullPath(sd).TrimEnd('\\'), StringComparison.OrdinalIgnoreCase)) return System.IO.Path.GetFileName(fullPath); }
            catch { /* ignore bad path */ }
        }
        return fullPath;
    }

    void BrowseImg_Click(object s, RoutedEventArgs e)
    {
        if (_sel is not { Kind: TplKind.Image, Inserted: true }) return;
        var dlg = new OpenFileDialog { Filter = "Images|*.png;*.ico;*.bmp;*.jpg;*.jpeg;*.gif|All files|*.*" };
        try { if (_doc != null) dlg.InitialDirectory = System.IO.Path.GetDirectoryName(_doc.Path); } catch { }
        if (dlg.ShowDialog() != true) return;
        string file = ChooseImageRef(dlg.FileName);
        _sel.Title = file; _sel.Dirty = true;
        _imgCache.Remove(file);
        Render(); Select(_sel);
        status.Text = $"Image set to {file}.";
    }

    void RefreshImg_Click(object s, RoutedEventArgs e)
    {
        if (_sel is not { Kind: TplKind.Image }) return;
        _imgCache.Remove(_sel.Title);     // bust the cache so the file is re-read from disk
        Render(); Select(_sel);
        status.Text = $"Refreshed image: {_sel.Title}";
    }

    // ---------- z-order ----------
    ContextMenu BuildChipMenu(TplElement el)
    {
        var cm = new ContextMenu();
        cm.Items.Add(ZItem("Bring to Front", () => ZFront(el)));
        cm.Items.Add(ZItem("Bring Forward", () => ZForward(el)));
        cm.Items.Add(ZItem("Send Backward", () => ZBackward(el)));
        cm.Items.Add(ZItem("Send to Back", () => ZBack(el)));
        cm.Items.Add(new Separator());
        cm.Items.Add(ZItem("Delete", () => DeleteControl(el)));
        return cm;
    }

    static MenuItem ZItem(string header, Action act)
    {
        var mi = new MenuItem { Header = header };
        mi.Click += (_, _) => act();
        return mi;
    }

    int MaxZ() => _chips.Count == 0 ? 5 : _chips.Values.Select(Panel.GetZIndex).Max();
    int MinZ() => _chips.Count == 0 ? 0 : _chips.Values.Select(Panel.GetZIndex).Min();
    int CurZ(TplElement el) => _chips.TryGetValue(el, out var b) ? Panel.GetZIndex(b) : 0;

    void SetZ(TplElement el, int z)
    {
        _z[el] = z;
        if (_chips.TryGetValue(el, out var b)) Panel.SetZIndex(b, z);
        Select(el);
        status.Text = $"{el.Display}  →  z-order {z}";
    }
    void ZFront(TplElement el) => SetZ(el, MaxZ() + 1);
    void ZBack(TplElement el) => SetZ(el, MinZ() - 1);
    void ZForward(TplElement el) => SetZ(el, CurZ(el) + 1);
    void ZBackward(TplElement el) => SetZ(el, CurZ(el) - 1);

    void Front_Click(object s, RoutedEventArgs e) { if (_sel != null) ZFront(_sel); }
    void Forward_Click(object s, RoutedEventArgs e) { if (_sel != null) ZForward(_sel); }
    void Backward_Click(object s, RoutedEventArgs e) { if (_sel != null) ZBackward(_sel); }
    void Back_Click(object s, RoutedEventArgs e) { if (_sel != null) ZBack(_sel); }

    // ---------- selection / properties ----------
    void Chip_Down(object s, MouseButtonEventArgs e)
    {
        var b = (Border)s;
        var el = (TplElement)b.Tag;
        Select(el);
        _drag = Drag.Element; _dragEl = el;
        _dragStart = e.GetPosition(canvas);
        _elStartX = el.LX; _elStartY = el.LY;
        canvas.CaptureMouse();
        e.Handled = true;
    }

    void Select(TplElement? el)
    {
        if (_sel != null && _chips.TryGetValue(_sel, out var old)) Highlight(old, false);
        _sel = el;
        if (el != null && _chips.TryGetValue(el, out var b)) Highlight(b, true);
        ShowHandles(el);
        propGrid.IsEnabled = el != null;
        propTitle.Text = el?.Display ?? "(none)";
        propKind.Text = el == null ? "" : $"{el.Kind}   line {el.LineIndex + 1}";

        var refs = el == null ? new List<(string Symbol, List<int> Lines)>() : ExternalReferences(el);
        if (refs.Count > 0)
        {
            int total = refs.Sum(r => r.Lines.Count);
            propRefs.Text = $"⚠ {string.Join(", ", refs.Select(r => r.Symbol))} referenced in "
                          + $"{total} other place(s). Deleting this control may break generation.";
            propRefsBox.Visibility = Visibility.Visible;
        }
        else propRefsBox.Visibility = Visibility.Collapsed;

        if (el is { Kind: TplKind.Prompt })
        {
            var (desc, glyph, special) = ClassifyPrompt(el.PromptType);
            propType.Text = $"Type: {desc}."
                + (special ? $"  ⚠ Clarion auto-builds this {(glyph == "▾" ? "dropdown" : "“…” button")} next to the "
                           + "field and lays it out for you — giving this control an explicit position (e.g. “Add AT to all”) "
                           + "can move or hide that part. Prefer leaving its position to Clarion."
                           : "");
            propType.Foreground = special ? new SolidColorBrush(Color.FromRgb(0x7A, 0x5C, 0x12))
                                          : new SolidColorBrush(Color.FromRgb(0x6E, 0x78, 0x85));
            propTypeBox.Background = special ? new SolidColorBrush(Color.FromRgb(0xFF, 0xF7, 0xE8))
                                             : new SolidColorBrush(Color.FromRgb(0xF4, 0xF6, 0xF9));
            propTypeBox.Visibility = Visibility.Visible;
        }
        else propTypeBox.Visibility = Visibility.Collapsed;

        string src = SourceOf(el);
        propSource.Text = src;
        srcHdr.Visibility = propSource.Visibility = src.Length > 0 ? Visibility.Visible : Visibility.Collapsed;
        _suppressProp = true;
        txtX.Text = el?.X.ToString() ?? ""; txtY.Text = el?.Y.ToString() ?? "";
        txtW.Text = el?.W.ToString() ?? ""; txtH.Text = el?.H.ToString() ?? "";
        txtText.Text = el?.Title ?? "";
        txtText.IsEnabled = el is { Inserted: true };   // re-titling existing controls would rewrite their line; keep to added ones
        bool isImg = el is { Kind: TplKind.Image };
        imgRow.Visibility = isImg ? Visibility.Visible : Visibility.Collapsed;
        btnBrowseImg.IsEnabled = isImg && el!.Inserted;  // browsing changes the file name (only added images persist)
        _suppressProp = false;

        _suppressChildSel = true;
        if (el is { Kind: TplKind.Boxed })
        {
            _childList = Positionable(el).ToList();
            lstChildren.ItemsSource = _childList.Select(c => $"{c.Kind,-7} {c.Display}").ToList();
            childHdr.Text = $"CONTROLS IN GROUP ({_childList.Count})";
            childHdr.Visibility = lstChildren.Visibility = Visibility.Visible;
        }
        else
        {
            _childList = null;
            lstChildren.ItemsSource = null;
            childHdr.Visibility = lstChildren.Visibility = Visibility.Collapsed;
        }
        _suppressChildSel = false;
    }

    void Children_Select(object s, SelectionChangedEventArgs e)
    {
        if (_suppressChildSel || _childList == null) return;
        int i = lstChildren.SelectedIndex;
        if (i >= 0 && i < _childList.Count) Select(_childList[i]);
    }

    void Text_Changed(object s, TextChangedEventArgs e)
    {
        if (_suppressProp || _sel == null || !_sel.Inserted) return;
        _sel.Title = txtText.Text;
        _sel.Dirty = true;
        if (_chips.TryGetValue(_sel, out var b) && b.Child is TextBlock tb)
            tb.Text = _sel.Kind == TplKind.Image ? "🖼 " + _sel.Display : _sel.Display;
        else
            Render();
    }

    static void Highlight(Border b, bool on) =>
        b.BorderBrush = on ? new SolidColorBrush(Color.FromRgb(220, 70, 60))
                           : new SolidColorBrush(Color.FromRgb(200, 208, 218));

    void Prop_Changed(object s, TextChangedEventArgs e)
    {
        if (_suppressProp || _sel == null) return;
        if (int.TryParse(txtX.Text, out var x)) _sel.X = x;
        if (int.TryParse(txtY.Text, out var y)) _sel.Y = y;
        if (int.TryParse(txtW.Text, out var w)) _sel.W = w;
        if (int.TryParse(txtH.Text, out var h)) _sel.H = h;
        _sel.HasX = _sel.HasY = _sel.HasW = _sel.HasH = true;
        _sel.Dirty = true;
        Render();
    }

    // ---------- canvas dragging ----------
    void Canvas_MouseDown(object s, MouseButtonEventArgs e)
    {
        if (e.OriginalSource == canvas) Select(null);
    }

    void Canvas_MouseMove(object s, MouseEventArgs e)
    {
        var p = e.GetPosition(canvas);
        hRuler.MouseDlu = p.X / Scale; vRuler.MouseDlu = p.Y / Scale;
        hRuler.InvalidateVisual(); vRuler.InvalidateVisual();

        if (_drag == Drag.Element && _dragEl != null)
        {
            double nx = _elStartX + (p.X - _dragStart.X) / Scale;
            double ny = _elStartY + (p.Y - _dragStart.Y) / Scale;
            nx = SnapX(nx); ny = SnapY(ny);
            MoveElement(_dragEl, nx, ny);
        }
        else if (_drag == Drag.Resize && _sel != null)
        {
            double dx = (p.X - _dragStart.X) / Scale, dy = (p.Y - _dragStart.Y) / Scale;
            double left = _rStartX, top = _rStartY, right = _rStartX + _rStartW, bottom = _rStartY + _rStartH;
            if ((_resizeEdge & Edge.Left) != 0) left = Math.Min(Math.Max(0, SnapX(_rStartX + dx)), right - MinDlu);
            if ((_resizeEdge & Edge.Right) != 0) right = Math.Max(SnapX(right + dx), left + MinDlu);
            if ((_resizeEdge & Edge.Top) != 0) top = Math.Min(Math.Max(0, SnapY(_rStartY + dy)), bottom - MinDlu);
            if ((_resizeEdge & Edge.Bottom) != 0) bottom = Math.Max(SnapY(bottom + dy), top + MinDlu);
            ResizeElement(_sel, left, top, right - left, bottom - top);
        }
        else if (_drag == Drag.Guide && _dragGuide != null)
        {
            double v = (_dragGuide.Vertical ? p.X : p.Y) / Scale;
            bool ctrl = (Keyboard.Modifiers & ModifierKeys.Control) != 0;
            int seg = _dragGuide.Vertical ? hRuler.Step : vRuler.Step;   // labelled ruler segment
            if (ctrl) v = Math.Round(v / seg) * seg;                     // Ctrl: snap to ruler segments
            else if (chkSnapGrid.IsChecked == true) v = Math.Round(v / GridStep) * GridStep;
            _dragGuide.Dlu = Math.Max(0, Math.Round(v));
            PositionGuide(_dragGuide);

            bool kill = InRulerZone(e.GetPosition(scroller));           // dragged back onto a ruler -> will delete
            _dragGuide.Visual.Stroke = kill ? GuideKillBrush : GuideBrush;
            status.Text = kill
                ? "Release over the ruler to delete this guide"
                : $"{(_dragGuide.Vertical ? "V" : "H")} guide @ {_dragGuide.Dlu} DLU" + (ctrl ? $"  (snap {seg})" : "");
        }
    }

    void Canvas_MouseUp(object s, MouseButtonEventArgs e)
    {
        if (_drag == Drag.Guide && _dragGuide != null && InRulerZone(e.GetPosition(scroller)))
            DeleteGuide(_dragGuide);
        else if (_drag == Drag.Element && _dragEl != null && !_dragEl.IsContainer)
            TryReparent(_dragEl);            // dropping a control may move it in/out of a group box
        canvas.ReleaseMouseCapture();
        _drag = Drag.None; _dragEl = null; _dragGuide = null;
    }

    // ---------- group containment ----------
    void TryReparent(TplElement el)
    {
        double cx = el.LX + el.LW / 2, cy = el.LY + el.LH / 2;     // the control's centre
        TplElement newParent = DeepestBoxAt(cx, cy, el) ?? _tab!;
        if (newParent == null || newParent == el.Parent) return;
        Reparent(el, newParent);
    }

    TplElement? DeepestBoxAt(double x, double y, TplElement exclude)
    {
        TplElement? best = null; int bestDepth = -1;
        if (_tab == null) return null;
        foreach (var b in Positionable(_tab))
        {
            if (b.Kind != TplKind.Boxed || b == exclude) continue;
            if (x >= b.LX && x <= b.LX + b.LW && y >= b.LY && y <= b.LY + b.LH)
            {
                int depth = Depth(b);
                if (depth > bestDepth) { bestDepth = depth; best = b; }
            }
        }
        return best;
    }

    static int Depth(TplElement e)
    {
        int d = 0; for (var p = e.Parent; p != null; p = p.Parent) d++;
        return d;
    }

    void Reparent(TplElement el, TplElement newParent)
    {
        el.Parent?.Children.Remove(el);
        newParent.Children.Add(el);
        el.Parent = newParent;
        var (ox, oy) = FrameOrigin(el);            // now relative to the new container
        el.X = (int)Math.Round(el.LX - ox);
        el.Y = (int)Math.Round(el.LY - oy);
        el.HasX = el.HasY = el.Dirty = true;
        if (!el.Inserted) el.Moved = true;         // existing control: its source line must relocate
        Render();
        Select(el);
        string where = newParent.Kind == TplKind.Boxed ? $"into group \"{newParent.Title}\"" : "out to the tab";
        status.Text = $"Moved {el.Display} {where}.  Save to write it.";
    }

    // The pointer is "over a ruler" when it leaves the canvas viewport to the top or left,
    // i.e. scroller-relative coords go negative (the rulers sit above/left of the scroller).
    bool InRulerZone(Point scrollerPt) => scrollerPt.X < 0 || scrollerPt.Y < 0;

    void MoveElement(TplElement el, double lx, double ly)
    {
        lx = Math.Max(0, lx); ly = Math.Max(0, ly);
        double dX = lx - el.LX, dY = ly - el.LY;       // incremental shift for any contents
        el.LX = lx; el.LY = ly;
        var (ox, oy) = FrameOrigin(el);
        el.X = (int)Math.Round(lx - ox);
        el.Y = (int)Math.Round(ly - oy);
        el.HasX = el.HasY = el.Dirty = true;
        if (!el.HasW) { el.W = (int)Math.Round(el.LW); el.HasW = true; }
        if (!el.HasH) { el.H = (int)Math.Round(el.LH); el.HasH = true; }
        PlaceChip(el);

        if (el.IsContainer)                            // a group box carries its contents
            foreach (var d in Descendants(el))
            {
                d.LX += dX; d.LY += dY;                // their frame-relative AT is unchanged
                PlaceChip(d);
            }

        if (el == _sel) PositionHandles(el);
        _suppressProp = true;
        txtX.Text = el.X.ToString(); txtY.Text = el.Y.ToString();
        _suppressProp = false;
        status.Text = $"{el.Display}  →  AT({el.X},{el.Y},{el.W},{el.H})";
    }

    void PlaceChip(TplElement el)
    {
        if (_chips.TryGetValue(el, out var b))
        {
            Canvas.SetLeft(b, el.LX * Scale); Canvas.SetTop(b, el.LY * Scale);
        }
    }

    static IEnumerable<TplElement> Descendants(TplElement e)
    {
        foreach (var c in e.Children)
        {
            if (c.Deleted) continue;
            yield return c;
            foreach (var x in Descendants(c)) yield return x;
        }
    }

    (double, double) FrameOrigin(TplElement el)
    {
        var p = el.Parent;
        while (p != null && p.Kind != TplKind.Boxed && p.Kind != TplKind.Tab) p = p.Parent;
        if (p == null || p.Kind == TplKind.Tab) return (0, 0);
        return (p.LX, p.LY);
    }

    // ---------- resize handles ----------
    static readonly (Edge edge, double fx, double fy)[] HandleSpec =
    {
        (Edge.Top | Edge.Left, 0, 0),    (Edge.Top, .5, 0),    (Edge.Top | Edge.Right, 1, 0),
        (Edge.Left, 0, .5),                                     (Edge.Right, 1, .5),
        (Edge.Bottom | Edge.Left, 0, 1), (Edge.Bottom, .5, 1), (Edge.Bottom | Edge.Right, 1, 1),
    };

    void ClearHandles()
    {
        foreach (var r in _handles) canvas.Children.Remove(r);
        _handles.Clear();
    }

    void ShowHandles(TplElement? el)
    {
        ClearHandles();
        if (el == null || !_chips.ContainsKey(el)) return;
        foreach (var (edge, fx, fy) in HandleSpec)
        {
            var r = new Rectangle
            {
                Width = HandlePx, Height = HandlePx,
                Fill = Brushes.White,
                Stroke = new SolidColorBrush(Color.FromRgb(220, 70, 60)),
                StrokeThickness = 1,
                Tag = edge,
                Cursor = HandleCursor(edge)
            };
            Panel.SetZIndex(r, 2_000_000);    // above chips and guides, always grabbable
            r.MouseLeftButtonDown += Handle_Down;
            canvas.Children.Add(r);
            _handles.Add(r);
        }
        PositionHandles(el);
    }

    void PositionHandles(TplElement el)
    {
        double x = el.LX * Scale, y = el.LY * Scale, w = el.LW * Scale, h = el.LH * Scale;
        for (int i = 0; i < _handles.Count && i < HandleSpec.Length; i++)
        {
            var (_, fx, fy) = HandleSpec[i];
            Canvas.SetLeft(_handles[i], x + w * fx - HandlePx / 2);
            Canvas.SetTop(_handles[i], y + h * fy - HandlePx / 2);
        }
    }

    static Cursor HandleCursor(Edge e) => e switch
    {
        (Edge.Top | Edge.Left) or (Edge.Bottom | Edge.Right) => Cursors.SizeNWSE,
        (Edge.Top | Edge.Right) or (Edge.Bottom | Edge.Left) => Cursors.SizeNESW,
        Edge.Left or Edge.Right => Cursors.SizeWE,
        _ => Cursors.SizeNS
    };

    void Handle_Down(object s, MouseButtonEventArgs e)
    {
        if (_sel == null) return;
        _resizeEdge = (Edge)((Rectangle)s).Tag;
        _drag = Drag.Resize;
        _dragStart = e.GetPosition(canvas);
        _rStartX = _sel.LX; _rStartY = _sel.LY; _rStartW = _sel.LW; _rStartH = _sel.LH;
        canvas.CaptureMouse();
        e.Handled = true;
    }

    void ResizeElement(TplElement el, double lx, double ly, double lw, double lh)
    {
        lw = Math.Max(MinDlu, lw); lh = Math.Max(MinDlu, lh);
        lx = Math.Max(0, lx); ly = Math.Max(0, ly);
        el.LX = lx; el.LY = ly; el.LW = lw; el.LH = lh;
        var (ox, oy) = FrameOrigin(el);
        el.X = (int)Math.Round(lx - ox); el.Y = (int)Math.Round(ly - oy);
        el.W = (int)Math.Round(lw); el.H = (int)Math.Round(lh);
        el.HasX = el.HasY = el.HasW = el.HasH = el.Dirty = true;
        if (_chips.TryGetValue(el, out var b))
        {
            Canvas.SetLeft(b, lx * Scale); Canvas.SetTop(b, ly * Scale);
            b.Width = Math.Max(6, lw * Scale); b.Height = Math.Max(6, lh * Scale);
        }
        PositionHandles(el);
        _suppressProp = true;
        txtX.Text = el.X.ToString(); txtY.Text = el.Y.ToString();
        txtW.Text = el.W.ToString(); txtH.Text = el.H.ToString();
        _suppressProp = false;
        status.Text = $"{el.Display}  →  AT({el.X},{el.Y},{el.W},{el.H})";
    }

    double SnapX(double dlu)
    {
        if (chkSnapGuide.IsChecked == true)
            foreach (var g in _guides.Where(g => g.Vertical))
                if (Math.Abs(g.Dlu - dlu) * Scale <= SnapPx) return g.Dlu;
        if (chkSnapGrid.IsChecked == true) return Math.Round(dlu / GridStep) * GridStep;
        return Math.Round(dlu);
    }
    double SnapY(double dlu)
    {
        if (chkSnapGuide.IsChecked == true)
            foreach (var g in _guides.Where(g => !g.Vertical))
                if (Math.Abs(g.Dlu - dlu) * Scale <= SnapPx) return g.Dlu;
        if (chkSnapGrid.IsChecked == true) return Math.Round(dlu / GridStep) * GridStep;
        return Math.Round(dlu);
    }

    // ---------- guides ----------
    void AddVGuide_Click(object s, RoutedEventArgs e) => StartGuide(true, 20);
    void AddHGuide_Click(object s, RoutedEventArgs e) => StartGuide(false, 20);
    void ClearGuides_Click(object s, RoutedEventArgs e)
    {
        foreach (var g in _guides) canvas.Children.Remove(g.Visual);
        _guides.Clear();
    }

    void HRuler_Down(object s, MouseButtonEventArgs e)   // top ruler -> horizontal guide (pull it down)
        => StartGuide(false, ((e.GetPosition(hRuler).Y + scroller.VerticalOffset) / Scale));
    void VRuler_Down(object s, MouseButtonEventArgs e)   // left ruler -> vertical guide (pull it right)
        => StartGuide(true, ((e.GetPosition(vRuler).X + scroller.HorizontalOffset) / Scale));

    void StartGuide(bool vertical, double dlu)
    {
        var g = new Guide { Vertical = vertical, Dlu = Math.Max(0, Math.Round(dlu)) };
        AddGuideVisual(g);
        _guides.Add(g);
        _drag = Drag.Guide; _dragGuide = g;
        canvas.CaptureMouse();
    }

    void AddGuideVisual(Guide g)
    {
        var line = new Line
        {
            Stroke = GuideBrush,
            StrokeThickness = 1,
            StrokeDashArray = new DoubleCollection { 4, 3 },
            Tag = g, Cursor = g.Vertical ? Cursors.SizeWE : Cursors.SizeNS
        };
        Panel.SetZIndex(line, 1_000_000);   // guides stay above any raised chip
        line.MouseLeftButtonDown += Guide_Down;
        g.Visual = line;
        canvas.Children.Add(line);
        PositionGuide(g);
    }

    void PositionGuide(Guide g)
    {
        double p = g.Dlu * Scale;
        if (g.Vertical) { g.Visual.X1 = g.Visual.X2 = p; g.Visual.Y1 = 0; g.Visual.Y2 = canvas.Height; }
        else { g.Visual.Y1 = g.Visual.Y2 = p; g.Visual.X1 = 0; g.Visual.X2 = canvas.Width; }
    }

    void Guide_Down(object s, MouseButtonEventArgs e)
    {
        var g = (Guide)((Line)s).Tag;
        if (e.ClickCount == 2) { DeleteGuide(g); e.Handled = true; return; }
        _drag = Drag.Guide; _dragGuide = g;
        canvas.CaptureMouse();
        e.Handled = true;
    }

    void DeleteGuide(Guide g)
    {
        canvas.Children.Remove(g.Visual);
        _guides.Remove(g);
        status.Text = $"Deleted {(g.Vertical ? "vertical" : "horizontal")} guide.";
    }

    static readonly Brush GuideBrush = new SolidColorBrush(Color.FromRgb(0, 150, 200));
    static readonly Brush GuideKillBrush = new SolidColorBrush(Color.FromRgb(220, 70, 60));

    // ---------- misc ----------
    void Scroller_Scroll(object s, ScrollChangedEventArgs e)
    {
        if (!_ready) return;
        hRuler.Offset = e.HorizontalOffset; vRuler.Offset = e.VerticalOffset;
        UpdateRulers();
    }

    void UpdateRulers()
    {
        hRuler.Scale = Scale; vRuler.Scale = Scale;
        hRuler.Step = Math.Max(5, GridStep * 2); vRuler.Step = hRuler.Step;
        hRuler.InvalidateVisual(); vRuler.InvalidateVisual();
    }

    void OnKeyDown(object s, KeyEventArgs e)
    {
        if (_sel == null) return;
        if (e.Key is Key.Delete or Key.Back)
        {
            if (Keyboard.FocusedElement is TextBox) return;   // let the X/Y/W/H editors handle it
            DeleteControl(_sel); e.Handled = true; return;
        }
        int d = (Keyboard.Modifiers & ModifierKeys.Shift) != 0 ? 5 : 1;
        double nx = _sel.LX, ny = _sel.LY;
        switch (e.Key)
        {
            case Key.Left: nx -= d; break;
            case Key.Right: nx += d; break;
            case Key.Up: ny -= d; break;
            case Key.Down: ny += d; break;
            default: return;
        }
        MoveElement(_sel, Math.Max(0, nx), Math.Max(0, ny));
        e.Handled = true;
    }

    static Brush FromColorRef(uint c)
    {
        byte r = (byte)(c & 0xFF), g = (byte)((c >> 8) & 0xFF), b = (byte)((c >> 16) & 0xFF);
        return new SolidColorBrush(Color.FromRgb(r, g, b));
    }
}

public class Guide
{
    public bool Vertical;
    public double Dlu;
    public Line Visual = null!;
}
