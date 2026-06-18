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
using ICSharpCode.AvalonEdit.Highlighting;
using ICSharpCode.AvalonEdit.Highlighting.Xshd;
using ICSharpCode.AvalonEdit.Rendering;
using AvalonDock.Layout;
using AvalonDock.Layout.Serialization;
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

    readonly List<TplElement> _selection = new();                       // all selected (incl. the primary _sel)
    readonly Dictionary<TplElement, (double X, double Y)> _dragStartPos = new();
    bool _marquee; Point _marqueeStart; Rectangle? _marqueeRect;
    readonly Dictionary<TplElement, Border> _chips = new();
    readonly Dictionary<string, BitmapImage?> _imgCache = new(StringComparer.OrdinalIgnoreCase);
    readonly List<Guide> _guides = new();

    enum Drag { None, Element, Guide, Resize }
    Drag _drag = Drag.None;
    TplElement? _dragEl;
    Guide? _dragGuide;
    Point _dragStart;
    double _elStartX, _elStartY;
    bool _dragMoved;                  // mouse has travelled past the threshold this gesture
    const double DragThreshold = 3;   // px before a click becomes a drag
    bool _suppressProp;
    bool _ready;          // true once XAML is fully constructed
    List<TplElement>? _childList;     // controls listed for the selected group box
    bool _suppressChildSel;

    // ---- undo (snapshot history) ----
    readonly List<Snapshot> _undo = new();
    Snapshot? _gestureSnap;           // captured at a drag/resize start, committed on end if it changed anything
    bool _gestureChanged;
    bool _editGuard;                  // one undo entry per X/Y/W/H or text editing burst
    const int MaxUndo = 100;
    readonly LineHighlighter _lineHi = new();   // highlights selected controls' lines in the source
    bool _srcOpen;                    // source panel visible
    bool _srcDirty, _loadingSrc;      // editor has unapplied edits / suppress TextChanged while loading
    bool _srcLive;                    // show the would-be-saved source (all pending edits) read-only
    IHighlightingDefinition? _clarionHl;

    // panel layout persistence
    FrameworkElement? _designerContent, _sourceContent, _propsContent;
    string? _defaultLayoutXml;
    LayoutAnchorable? _wiredSource;

    sealed class Snapshot
    {
        public readonly List<List<TplElement>> Tabs = new();    // deep-cloned trees, parallel to doc.Components
        public List<(bool V, double Dlu)> Guides = new();
    }

    [Flags] enum Edge { None = 0, Left = 1, Right = 2, Top = 4, Bottom = 8 }
    Edge _resizeEdge;
    double _rStartX, _rStartY, _rStartW, _rStartH;   // selection rect (DLU) at resize start
    readonly List<Rectangle> _handles = new();
    const double MinDlu = 4, HandlePx = 8;

    public MainWindow()
    {
        InitializeComponent();
        KeyDown += OnKeyDown;
        var fonts = System.Windows.Media.Fonts.SystemFontFamilies
            .Select(f => f.Source).OrderBy(n => n, StringComparer.OrdinalIgnoreCase).ToList();
        cmbFont.ItemsSource = fonts;
        cmbFontBar.ItemsSource = fonts;
        WireSource(anchSource);
        _srcOpen = anchSource.IsVisible;
        miViewSource.IsChecked = _srcOpen;
        srcMap.GoToLine += ln => srcEditor.ScrollToLine(Math.Min(srcEditor.Document?.LineCount ?? 1, ln + 1));
        srcEditor.TextArea.TextView.ScrollOffsetChanged += (_, _) => UpdateMinimapViewport();
        srcEditor.TextArea.TextView.BackgroundRenderers.Add(_lineHi);
        _ready = true;

        // remember panel contents + the pristine layout, then restore the user's saved layout
        _designerContent = designerHost;
        _sourceContent = (FrameworkElement)anchSource.Content;
        _propsContent = (FrameworkElement)anchProps.Content;
        try { _defaultLayoutXml = SerializeLayout(); } catch { }
        LoadPrefs();
        Loaded += (_, _) => TryLoadSavedLayout();
        Closing += (_, _) => { SaveLayout(); SavePrefs(); };
    }

    // ---------- file ----------
    void Open_Click(object s, RoutedEventArgs e)
    {
        var dlg = new OpenFileDialog { Filter = "Clarion template (*.tpl;*.tpw)|*.tpl;*.tpw|All files|*.*" };
        if (dlg.ShowDialog() != true) return;
        try
        {
            _doc = TplParser.Parse(dlg.FileName);
            _undo.Clear();
            Title = "Clarion Template Designer — " + System.IO.Path.GetFileName(dlg.FileName);
            PopulateParts(0, 0);
            SetSource(true);          // show the colour-coded source panel so it's never hidden
            int files = _doc.Files.Count, comps = _doc.Components.Count;
            status.Text = $"Loaded {_parts.Count} editable part(s) of {comps} component(s) across {files} file(s). "
                        + "Pick a Part and Tab; the colour-coded source is in the panel below (toggle with “View Source”).";
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
            LoadSource();                          // reflect what's now on disk
            status.Text = "Saved " + System.IO.Path.GetFileName(_doc.Path);
        }
        catch (Exception ex) { MessageBox.Show("Save failed:\n" + ex.Message); }
    }

    void ReloadFromDisk()
    {
        if (_doc == null) return;
        int partIdx = cmbParts.SelectedIndex, tabIdx = cmbTabs.SelectedIndex;
        _doc = TplParser.Parse(_doc.Path);
        _undo.Clear();           // line indices changed on disk; old snapshots no longer apply
        _sel = null;
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

        PushUndo();
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
        PushUndo();
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
        string s = TplWriter.PreviewLine(f.Lines[el.LineIndex], el).Trim();   // reflect pending AT/PROP edits
        if (el.EndLineIndex > el.LineIndex)            // container: note the span
            s += $"\n…\n{f.Lines[Math.Min(el.EndLineIndex, f.Lines.Length - 1)].Trim()}"
               + $"   ({el.EndLineIndex - el.LineIndex + 1} lines)";
        return s;
    }

    // ---------- undo ----------
    Snapshot Capture()
    {
        var s = new Snapshot();
        if (_doc != null)
            foreach (var c in _doc.Components)
                s.Tabs.Add(c.Tabs.Select(t => t.Clone()).ToList());
        s.Guides = _guides.Select(g => (g.Vertical, g.Dlu)).ToList();
        return s;
    }

    void PushUndo()
    {
        if (_doc == null) return;
        _undo.Add(Capture());
        if (_undo.Count > MaxUndo) _undo.RemoveAt(0);
    }

    void Undo_Click(object s, RoutedEventArgs e) => Undo();

    void Undo()
    {
        if (_undo.Count == 0) { status.Text = "Nothing to undo."; return; }
        var snap = _undo[^1];
        _undo.RemoveAt(_undo.Count - 1);
        Restore(snap);
        status.Text = $"Undid last change.  ({_undo.Count} more in history)";
    }

    void Restore(Snapshot snap)
    {
        if (_doc == null) return;
        for (int i = 0; i < _doc.Components.Count && i < snap.Tabs.Count; i++)
        {
            _doc.Components[i].Tabs.Clear();
            _doc.Components[i].Tabs.AddRange(snap.Tabs[i]);
        }
        _guides.Clear();
        foreach (var (v, d) in snap.Guides) _guides.Add(new Guide { Vertical = v, Dlu = d });

        _sel = null;
        if (_component != null)
        {
            int ti = cmbTabs.SelectedIndex;
            _tab = ti >= 0 && ti < _component.Tabs.Count ? _component.Tabs[ti]
                 : (_component.Tabs.Count > 0 ? _component.Tabs[0] : null);
        }
        Render();
        Select(null);
    }

    // Drag/resize gestures: capture once at the start, commit only if something actually changed.
    void BeginGesture() { _gestureSnap = Capture(); _gestureChanged = false; }
    void CommitGesture()
    {
        if (_gestureChanged && _gestureSnap != null)
        {
            _undo.Add(_gestureSnap);
            if (_undo.Count > MaxUndo) _undo.RemoveAt(0);
        }
        _gestureSnap = null; _gestureChanged = false;
        RefreshLiveSource();          // drag/resize move the chips directly (no Render) — refresh now
    }

    TplFile? CurrentFile()
    {
        if (_doc == null || _doc.Files.Count == 0) return null;
        int fi = _component?.FileIndex ?? 0;
        return fi >= 0 && fi < _doc.Files.Count ? _doc.Files[fi] : _doc.Files[0];
    }

    // ---------- source panel (AvalonEdit) ----------
    const string ClarionXshd = @"<?xml version='1.0'?>
<SyntaxDefinition name='ClarionTemplate' xmlns='http://icsharpcode.net/sharpdevelop/syntaxdefinition/2008'>
  <Color name='Comment'   foreground='#208020' />
  <Color name='Directive' foreground='#0A66C2' fontWeight='bold' />
  <Color name='Symbol'    foreground='#0E7C6B' />
  <Color name='Str'       foreground='#B26A00' />
  <RuleSet ignoreCase='true'>
    <Span color='Comment' begin='#!' />
    <Span color='Str'><Begin>'</Begin><End>'</End></Span>
    <Span color='Comment' begin='!' />
    <Rule color='Directive'>\#[A-Za-z][A-Za-z0-9_]*</Rule>
    <Rule color='Symbol'>%[A-Za-z][A-Za-z0-9_:]*</Rule>
  </RuleSet>
</SyntaxDefinition>";

    IHighlightingDefinition ClarionHighlighting()
    {
        if (_clarionHl != null) return _clarionHl;
        using var xr = System.Xml.XmlReader.Create(new System.IO.StringReader(ClarionXshd));
        _clarionHl = HighlightingLoader.Load(xr, HighlightingManager.Instance);
        return _clarionHl;
    }

    void Source_Click(object s, RoutedEventArgs e) => SetSource(miViewSource.IsChecked == true);

    // Show/hide the AvalonDock Source anchorable; the rest is synced by AnchSource_VisChanged.
    void SetSource(bool show)
    {
        if (show) { anchSource.Show(); anchSource.IsActive = true; }
        else anchSource.Hide();
    }

    void AnchSource_VisChanged(object? s, EventArgs e)
    {
        _srcOpen = anchSource.IsVisible;
        miViewSource.IsChecked = _srcOpen;
        if (_srcOpen) { LoadSource(); ScrollSourceTo(_sel); }
    }

    // ---------- panel layout persistence ----------
    void Exit_Click(object s, RoutedEventArgs e) => Close();

    void ResetLayout_Click(object s, RoutedEventArgs e)
    {
        LoadLayout(_defaultLayoutXml);
        status.Text = "Panel layout reset to default.";
    }

    void WireSource(LayoutAnchorable a)
    {
        if (_wiredSource != null) _wiredSource.IsVisibleChanged -= AnchSource_VisChanged;
        _wiredSource = a; anchSource = a;
        if (a != null) a.IsVisibleChanged += AnchSource_VisChanged;
    }

    string LayoutPath => System.IO.Path.Combine(
        Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData),
        "ClarionTemplateDesigner", "layout.xml");

    string SerializeLayout()
    {
        var ser = new XmlLayoutSerializer(dockMgr);
        using var sw = new System.IO.StringWriter();
        ser.Serialize(sw);
        return sw.ToString();
    }

    void LoadLayout(string? xml)
    {
        if (string.IsNullOrWhiteSpace(xml)) return;
        try
        {
            var ser = new XmlLayoutSerializer(dockMgr);
            ser.LayoutSerializationCallback += (_, e) =>
            {
                e.Content = e.Model.ContentId switch
                {
                    "designer" => _designerContent,
                    "source" => _sourceContent,
                    "props" => _propsContent,
                    _ => null
                };
                if (e.Content == null) e.Cancel = true;
            };
            using var sr = new System.IO.StringReader(xml);
            ser.Deserialize(sr);

            var prp = FindAnchorable("props"); if (prp != null) anchProps = prp;
            var src = FindAnchorable("source"); if (src != null) WireSource(src);
            _srcOpen = anchSource?.IsVisible ?? false;
            miViewSource.IsChecked = _srcOpen;
        }
        catch { /* a bad/old layout file must never break startup */ }
    }

    LayoutAnchorable? FindAnchorable(string id) =>
        dockMgr.Layout.Descendents().OfType<LayoutAnchorable>().FirstOrDefault(a => a.ContentId == id);

    void TryLoadSavedLayout()
    {
        try { if (System.IO.File.Exists(LayoutPath)) LoadLayout(System.IO.File.ReadAllText(LayoutPath)); }
        catch { }
    }

    string PrefsPath => System.IO.Path.Combine(
        Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData),
        "ClarionTemplateDesigner", "prefs.txt");

    void LoadPrefs()
    {
        try
        {
            if (!System.IO.File.Exists(PrefsPath)) return;
            var d = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);
            foreach (var line in System.IO.File.ReadAllLines(PrefsPath))
            {
                int i = line.IndexOf('=');
                if (i > 0) d[line[..i].Trim()] = line[(i + 1)..].Trim();
            }
            if (d.TryGetValue("showGrid", out var sg)) miShowGrid.IsChecked = sg == "1";
            if (d.TryGetValue("snapGrid", out var sn)) miSnapGrid.IsChecked = sn == "1";
            if (d.TryGetValue("snapGuide", out var su)) miSnapGuide.IsChecked = su == "1";
            if (d.TryGetValue("minimap", out var mm)) miMinimap.IsChecked = mm == "1";
            if (d.TryGetValue("gridSize", out var gs) && int.TryParse(gs, out _)) txtGrid.Text = gs;
            if (d.TryGetValue("zoom", out var z) &&
                double.TryParse(z, System.Globalization.NumberStyles.Any, System.Globalization.CultureInfo.InvariantCulture, out var zv))
                sldZoom.Value = zv;

            // apply the toggles that need more than their checked state
            srcMap.Visibility = miMinimap.IsChecked == true ? Visibility.Visible : Visibility.Collapsed;
            mapCol.Width = miMinimap.IsChecked == true ? new GridLength(92) : new GridLength(0);
        }
        catch { }
    }

    void SavePrefs()
    {
        try
        {
            var dir = System.IO.Path.GetDirectoryName(PrefsPath);
            if (dir != null) System.IO.Directory.CreateDirectory(dir);
            System.IO.File.WriteAllLines(PrefsPath, new[]
            {
                $"showGrid={(miShowGrid.IsChecked == true ? 1 : 0)}",
                $"snapGrid={(miSnapGrid.IsChecked == true ? 1 : 0)}",
                $"snapGuide={(miSnapGuide.IsChecked == true ? 1 : 0)}",
                $"minimap={(miMinimap.IsChecked == true ? 1 : 0)}",
                $"gridSize={GridStep}",
                $"zoom={sldZoom.Value.ToString(System.Globalization.CultureInfo.InvariantCulture)}",
            });
        }
        catch { }
    }

    void SaveLayout()
    {
        try
        {
            var dir = System.IO.Path.GetDirectoryName(LayoutPath);
            if (dir != null) System.IO.Directory.CreateDirectory(dir);
            System.IO.File.WriteAllText(LayoutPath, SerializeLayout());
        }
        catch { }
    }

    void LiveSrc_Changed(object s, RoutedEventArgs e)
    {
        _srcLive = chkLive.IsChecked == true;
        srcEditor.IsReadOnly = _srcLive;
        btnApplySrc.IsEnabled = !_srcLive && _srcDirty;
        LoadSource();
    }

    // Render the file as it WOULD be saved (all pending edits), without touching disk.
    void RefreshLiveSource()
    {
        if (!_srcOpen || !_srcLive || _doc == null) return;
        int fi = _component?.FileIndex ?? 0;
        _loadingSrc = true;
        try { srcEditor.Text = TplWriter.PreviewFile(_doc, fi); }
        finally { _loadingSrc = false; }
        _srcDirty = false; btnApplySrc.IsEnabled = false;
        var f = CurrentFile();
        srcHeader.Text = (f == null ? "SOURCE" : $"SOURCE — {System.IO.Path.GetFileName(f.Path)}") + "  •  live (unsaved)";
        RefreshMinimap();
        UpdateSourceHighlights();
    }

    void LoadSource()
    {
        if (!_srcOpen) return;
        if (_srcLive) { RefreshLiveSource(); return; }
        var f = CurrentFile();
        srcEditor.SyntaxHighlighting = ClarionHighlighting();
        _loadingSrc = true;
        try
        {
            if (f == null) srcEditor.Text = "(Open a .tpl with the “Open .tpl…” button to view its source here.)";
            else { try { srcEditor.Text = System.IO.File.ReadAllText(f.Path); } catch { srcEditor.Text = string.Join(f.Newline, f.Lines); } }
        }
        finally { _loadingSrc = false; }
        _srcDirty = false; btnApplySrc.IsEnabled = false;
        srcHeader.Text = f == null ? "SOURCE" : $"SOURCE — {System.IO.Path.GetFileName(f.Path)}";
        RefreshMinimap();
        UpdateSourceHighlights();
    }

    void SrcEditor_TextChanged(object? s, EventArgs e)
    {
        RefreshMinimap();
        if (_loadingSrc) return;
        _srcDirty = true; btnApplySrc.IsEnabled = true;
        var f = CurrentFile();
        srcHeader.Text = (f == null ? "SOURCE" : $"SOURCE — {System.IO.Path.GetFileName(f.Path)}") + "  •  edited (Apply to commit)";
    }

    void RevertSrc_Click(object s, RoutedEventArgs e) => LoadSource();

    void ApplySrc_Click(object s, RoutedEventArgs e)
    {
        var f = CurrentFile();
        if (f == null || !_srcDirty) return;
        if (AllElements().Any(el => el.Dirty || el.Inserted || el.Deleted || el.Moved) &&
            MessageBox.Show("Applying source edits re-reads the file and discards unsaved canvas changes. Continue?",
                "Apply source edits", MessageBoxButton.YesNo, MessageBoxImage.Warning, MessageBoxResult.No) != MessageBoxResult.Yes)
            return;
        try
        {
            System.IO.File.WriteAllText(f.Path, srcEditor.Text);
            ReloadFromDisk();          // re-parse the whole set (PopulateParts reloads the editor too)
            status.Text = $"Applied source edits to {System.IO.Path.GetFileName(f.Path)}.";
        }
        catch (Exception ex) { MessageBox.Show("Apply failed:\n" + ex.Message); }
    }

    void ScrollSourceTo(TplElement? el)
    {
        UpdateSourceHighlights();
        if (!_srcOpen || el == null || el.LineIndex < 0) return;
        int line = el.LineIndex + 1;
        if (line < 1 || line > srcEditor.Document.LineCount) return;
        var dl = srcEditor.Document.GetLineByNumber(line);
        srcEditor.CaretOffset = dl.Offset;
        srcEditor.Select(dl.Offset, dl.Length);
        srcEditor.ScrollToLine(line);
    }

    // Band-highlight every selected control's source line in the editor.
    void UpdateSourceHighlights()
    {
        _lineHi.Lines.Clear();
        if (_srcOpen)
            foreach (var el in _selection)
                if (el.LineIndex >= 0) _lineHi.Lines.Add(el.LineIndex + 1);
        srcEditor.TextArea.TextView.InvalidateLayer(KnownLayer.Selection);
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
        LoadSource();           // current part may live in a different file
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
        RefreshLiveSource();          // keep the live source in step with the model
        canvas.Children.Clear();
        _chips.Clear();
        _handles.Clear();
        if (_preview) { RenderPreview(); return; }
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

        DrawGrid();
        foreach (var g in _guides) AddGuideVisual(g);

        UpdateRulers();
        RefreshSelectionVisual();
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

    // ---------- preferences (grid / minimap) ----------
    void DrawGrid()
    {
        if (miShowGrid.IsChecked != true) return;
        double step = GridStep * Scale;
        if (step < 5) return;                       // too dense to be useful
        var brush = new SolidColorBrush(Color.FromRgb(0xE4, 0xE9, 0xF0)); brush.Freeze();
        for (double x = step; x < canvas.Width; x += step)
            AddGridLine(x, 0, x, canvas.Height, brush);
        for (double y = step; y < canvas.Height; y += step)
            AddGridLine(0, y, canvas.Width, y, brush);
    }

    void AddGridLine(double x1, double y1, double x2, double y2, Brush brush)
    {
        var l = new Line { X1 = x1, Y1 = y1, X2 = x2, Y2 = y2, Stroke = brush, StrokeThickness = 0.5, IsHitTestVisible = false };
        Panel.SetZIndex(l, -1);                     // behind the controls
        canvas.Children.Add(l);
    }

    void ShowGrid_Changed(object s, RoutedEventArgs e) => Render();
    void GridSize_Changed(object s, TextChangedEventArgs e) { if (_ready) { UpdateRulers(); Render(); } }

    void Minimap_Toggle(object s, RoutedEventArgs e)
    {
        bool on = miMinimap.IsChecked == true;
        srcMap.Visibility = on ? Visibility.Visible : Visibility.Collapsed;
        mapCol.Width = on ? new GridLength(92) : new GridLength(0);
        if (on) RefreshMinimap();
    }

    void RefreshMinimap()
    {
        if (miMinimap.IsChecked != true) return;
        srcMap.Lines = srcEditor.Text.Split('\n');
        UpdateMinimapViewport();
    }

    void UpdateMinimapViewport()
    {
        if (miMinimap.IsChecked != true) return;
        var tv = srcEditor.TextArea.TextView;
        double lh = tv.DefaultLineHeight > 0 ? tv.DefaultLineHeight : srcEditor.FontSize * 1.3;
        if (lh <= 0) return;
        srcMap.FirstVisible = (int)(srcEditor.VerticalOffset / lh);
        srcMap.VisibleCount = (int)(srcEditor.ViewportHeight / lh) + 1;
        srcMap.InvalidateVisual();
    }

    void DeleteSelection()
    {
        var items = _selection.Count > 0 ? _selection.ToList()
                  : (_sel != null ? new List<TplElement> { _sel } : new List<TplElement>());
        if (items.Count == 0) return;
        if (items.Count == 1) { DeleteControl(items[0]); return; }   // single keeps the detailed warning

        int refd = items.Count(el => ExternalReferences(el).Count > 0);
        string msg = $"Delete {items.Count} controls?"
                   + (refd > 0 ? $"\n\n{refd} of them have a %symbol referenced elsewhere in the template; "
                               + "deleting may break code generation." : "");
        if (MessageBox.Show(msg, "Delete controls", MessageBoxButton.YesNo,
                MessageBoxImage.Warning, MessageBoxResult.No) != MessageBoxResult.Yes) return;
        PushUndo();
        foreach (var el in items) el.Deleted = true;
        Select(null);
        Render();
        status.Text = $"Deleted {items.Count} controls.  Save to write the change (re-open to undo).";
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

        PushUndo();
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
        else if (el.Kind == TplKind.Prompt)
        {
            border.Background = Brushes.Transparent;          // the row's own controls supply the look
            var fg = el.FontColor is uint pc ? FromColorRef(pc) : Brushes.Black;
            var (_, glyph, _) = ClassifyPrompt(el.PromptType);
            string u = el.PromptType.Trim().ToUpperInvariant();

            TextBlock Label() => new()
            {
                Text = el.Title.Length > 0 ? el.Title : el.Symbol,
                Foreground = fg, FontSize = Math.Max(8, el.FontSize > 0 ? el.FontSize : 9),
                FontWeight = el.Bold ? FontWeights.Bold : FontWeights.Normal,
                VerticalAlignment = VerticalAlignment.Center, Margin = new Thickness(3, 0, 4, 0),
                TextTrimming = TextTrimming.CharacterEllipsis
            };

            if (u == "CHECK")
            {
                var dock = new DockPanel { LastChildFill = true };
                var tick = new Border
                {
                    Width = 11, Height = 11, Background = Brushes.White,
                    BorderBrush = new SolidColorBrush(Color.FromRgb(0xB8, 0xC0, 0xCC)),
                    BorderThickness = new Thickness(1), Margin = new Thickness(3, 0, 4, 0),
                    VerticalAlignment = VerticalAlignment.Center
                };
                DockPanel.SetDock(tick, Dock.Left);
                dock.Children.Add(tick); dock.Children.Add(Label());
                border.Child = dock;
            }
            else if (u.StartsWith("OPTION") || u.StartsWith("RADIO"))
            {
                border.Child = Label();
            }
            else                                              // entry / dropdown / picker
            {
                var dock = new DockPanel { LastChildFill = true };
                var lab = Label(); DockPanel.SetDock(lab, Dock.Left); dock.Children.Add(lab);
                if (glyph.Length > 0) { var b2 = FauxButton(glyph); DockPanel.SetDock(b2, Dock.Right); dock.Children.Add(b2); }
                var entry = new Border        // faux entry field, fills the remaining width
                {
                    Background = new SolidColorBrush(Color.FromRgb(0xFB, 0xFC, 0xFE)),
                    BorderBrush = new SolidColorBrush(Color.FromRgb(0xC8, 0xD0, 0xDC)),
                    BorderThickness = new Thickness(1), Margin = new Thickness(0, 1, 1, 1), MinWidth = 20
                };
                if (u.Contains("KEYCODE") && PromptDefaultInt(el) is int kc)   // show the decoded hotkey
                    entry.Child = new TextBlock
                    {
                        Text = DecodeKey(kc), FontSize = 8,
                        Foreground = new SolidColorBrush(Color.FromRgb(0x5B, 0x68, 0x78)),
                        VerticalAlignment = VerticalAlignment.Center, Margin = new Thickness(3, 0, 0, 0)
                    };
                dock.Children.Add(entry);
                border.Child = dock;
            }
        }
        else if (!box)
        {
            var fg = el.FontColor is uint c ? FromColorRef(c) : Brushes.Black;
            string txt = el.Kind == TplKind.Image ? "🖼 " + el.Display : el.Display;   // missing image -> show filename
            border.Child = new TextBlock
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
        Panel.SetZIndex(border, el.HasZ ? el.Z : (box ? 0 : 5));
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

    // Decode a Clarion keycode (Windows VK in the low byte + modifier bits) into e.g. "CtrlF10".
    static string DecodeKey(int code)
    {
        string mod = "";
        if ((code & 0x200) != 0) mod += "Ctrl";
        if ((code & 0x100) != 0) mod += "Shift";
        if ((code & 0x400) != 0) mod += "Alt";
        return mod + KeyName(code & 0xFF);
    }

    static string KeyName(int b)
    {
        if (b >= 0x70 && b <= 0x87) return "F" + (b - 0x6F);        // F1..F24
        if (b >= 0x41 && b <= 0x5A) return ((char)b).ToString();    // A..Z
        if (b >= 0x30 && b <= 0x39) return ((char)b).ToString();    // 0..9
        return b switch
        {
            0x08 => "Bksp", 0x09 => "Tab", 0x0D => "Enter", 0x1B => "Esc", 0x20 => "Space",
            0x2E => "Del", 0x2D => "Ins", 0x24 => "Home", 0x23 => "End", 0x21 => "PgUp", 0x22 => "PgDn",
            0x25 => "Left", 0x26 => "Up", 0x27 => "Right", 0x28 => "Down",
            _ => "Key" + b
        };
    }

    // The numeric default(...) on a prompt's source line, if any (used to decode KEYCODE prompts).
    int? PromptDefaultInt(TplElement el)
    {
        var f = CurrentFile();
        if (f == null || el.LineIndex < 0 || el.LineIndex >= f.Lines.Length) return null;
        var m = Regex.Match(f.Lines[el.LineIndex], @"default\(\s*(\d+)\s*\)", RegexOptions.IgnoreCase);
        return m.Success && int.TryParse(m.Groups[1].Value, out var v) ? v : null;
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
        if (el.Kind is TplKind.Prompt or TplKind.Display or TplKind.Boxed)
        {
            cm.Items.Add(new Separator());
            cm.Items.Add(ZItem("Font && Colour…", () => EditFontDialog(el)));
        }
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
        PushUndo();
        el.HasZ = true; el.Z = z;
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

    // A small bordered button simulating Clarion's auto-built dropdown (▾) / lookup (…) control.
    static Border FauxButton(string glyph) => new()
    {
        Background = new SolidColorBrush(Color.FromRgb(0xEC, 0xEF, 0xF3)),
        BorderBrush = new SolidColorBrush(Color.FromRgb(0xB8, 0xC0, 0xCC)),
        BorderThickness = new Thickness(1), Margin = new Thickness(2, 1, 1, 1),
        Child = new TextBlock
        {
            Text = glyph, FontSize = 9,
            Foreground = new SolidColorBrush(Color.FromRgb(0x5B, 0x68, 0x78)),
            HorizontalAlignment = HorizontalAlignment.Center, VerticalAlignment = VerticalAlignment.Center,
            Margin = new Thickness(3, 0, 3, 0)
        }
    };

    // ---------- selection / properties ----------
    void Chip_Down(object s, MouseButtonEventArgs e)
    {
        var b = (Border)s;
        var el = (TplElement)b.Tag;
        bool ctrl = (Keyboard.Modifiers & ModifierKeys.Control) != 0;
        bool shift = (Keyboard.Modifiers & ModifierKeys.Shift) != 0;
        if (ctrl) { ToggleSelect(el); e.Handled = true; return; }   // Ctrl+click toggles; no drag
        if (shift) AddSelect(el);
        else if (!_selection.Contains(el)) Select(el);
        else { _sel = el; RefreshSelectionVisual(); PopulateProps(el); }   // click a member -> keep group, set primary

        BeginGesture();
        _drag = Drag.Element; _dragEl = el; _dragMoved = false;
        _dragStart = e.GetPosition(canvas);
        _elStartX = el.LX; _elStartY = el.LY;
        _dragStartPos.Clear();
        foreach (var se in _selection) _dragStartPos[se] = (se.LX, se.LY);
        canvas.CaptureMouse();
        e.Handled = true;
    }

    void Select(TplElement? el)        // single-select (replaces the whole selection)
    {
        _selection.Clear();
        if (el != null) _selection.Add(el);
        _sel = el;
        AfterSelectionChanged();
    }

    void ToggleSelect(TplElement el)   // Ctrl+click
    {
        if (!_selection.Remove(el)) _selection.Add(el);
        _sel = _selection.Contains(el) ? el : (_selection.Count > 0 ? _selection[^1] : null);
        AfterSelectionChanged();
    }

    void AddSelect(TplElement el)      // Shift+click
    {
        if (!_selection.Contains(el)) _selection.Add(el);
        _sel = el;
        AfterSelectionChanged();
    }

    void AfterSelectionChanged()
    {
        _editGuard = false;            // next X/Y/W/H or text edit starts a fresh undo entry
        RefreshSelectionVisual();
        PopulateProps(_sel);
        ScrollSourceTo(_sel);
    }

    void RefreshSelectionVisual()
    {
        foreach (var kv in _chips) Highlight(kv.Value, _selection.Contains(kv.Key));
        ShowHandles(_selection.Count == 1 ? _sel : null);   // resize handles only for a single selection
    }

    void PopulateProps(TplElement? el)
    {
        propGrid.IsEnabled = el != null;
        propTitle.Text = _selection.Count > 1 ? $"{_selection.Count} controls selected"
                                              : el?.Display ?? "(none)";
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
            string keyNote = "";
            if (el.PromptType.ToUpperInvariant().Contains("KEYCODE") && PromptDefaultInt(el) is int kc)
                keyNote = $"  Default key: {DecodeKey(kc)}  ({kc}).";
            propType.Text = $"Type: {desc}.{keyNote}"
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
        txtBarText.Text = el?.Title ?? "";
        txtBarText.IsEnabled = el is { Inserted: true };
        cmbFontBar.Text = el?.FontName ?? "";
        txtBarSize.Text = el is { FontSize: > 0 } ? el.FontSize.ToString() : "";
        bool isImg = el is { Kind: TplKind.Image };
        imgRow.Visibility = isImg ? Visibility.Visible : Visibility.Collapsed;
        btnBrowseImg.IsEnabled = isImg && el!.Inserted;  // browsing changes the file name (only added images persist)

        bool styleable = el is { Kind: TplKind.Prompt or TplKind.Display or TplKind.Boxed };
        styleHdr.Visibility = styleGrid.Visibility = styleable ? Visibility.Visible : Visibility.Collapsed;
        if (styleable)
        {
            cmbFont.Text = el!.FontName;
            txtFontSize.Text = el.FontSize > 0 ? el.FontSize.ToString() : "";
            chkBold.IsChecked = el.Bold;
            colorSwatch.Background = el.FontColor is uint cc ? FromColorRef(cc) : Brushes.Transparent;
        }
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
        if (!_editGuard) { PushUndo(); _editGuard = true; }
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
        if (!_editGuard) { PushUndo(); _editGuard = true; }
        if (int.TryParse(txtX.Text, out var x)) _sel.X = x;
        if (int.TryParse(txtY.Text, out var y)) _sel.Y = y;
        if (int.TryParse(txtW.Text, out var w)) _sel.W = w;
        if (int.TryParse(txtH.Text, out var h)) _sel.H = h;
        _sel.HasX = _sel.HasY = _sel.HasW = _sel.HasH = true;
        _sel.Dirty = true;
        Render();
    }

    // ---------- style (font / size / bold / colour) ----------
    void BeginStyleEdit() { if (!_editGuard) { PushUndo(); _editGuard = true; } }

    // Apply a style change to every selected control (one undo entry per editing burst).
    void ApplyStyle(Action<TplElement> set)
    {
        if (_sel == null) return;
        BeginStyleEdit();
        foreach (var el in _selection) { set(el); el.FontDirty = true; }
        Render();                                  // chips reflect the new font/size/colour
        propSource.Text = SourceOf(_sel);          // per-control source preview (primary)
        srcHdr.Visibility = propSource.Visibility = Visibility.Visible;
    }

    void Font_Changed(object s, RoutedEventArgs e)
    {
        if (_suppressProp || _sel == null) return;
        string name = (cmbFont.Text ?? "").Trim();
        if (_selection.Count == 1 && name == _sel.FontName) return;
        ApplyStyle(el => el.FontName = name);
    }

    void FontSize_Changed(object s, TextChangedEventArgs e)
    {
        if (_suppressProp || _sel == null) return;
        int sz = int.TryParse(txtFontSize.Text, out var v) ? v : 0;
        if (_selection.Count == 1 && sz == _sel.FontSize) return;
        ApplyStyle(el => el.FontSize = sz);
    }

    void Bold_Changed(object s, RoutedEventArgs e)
    {
        if (_suppressProp || _sel == null) return;
        bool nb = chkBold.IsChecked == true;
        ApplyStyle(el => { el.Bold = nb; el.FontStyle = nb ? 700 : 400; });
    }

    void Color_Click(object s, RoutedEventArgs e) => ChangeColor();

    void ChangeColor()
    {
        if (_sel == null) return;
        using var dlg = new System.Windows.Forms.ColorDialog { FullOpen = true, AnyColor = true };
        if (_sel.FontColor is uint c)
            dlg.Color = System.Drawing.Color.FromArgb((int)(c & 0xFF), (int)((c >> 8) & 0xFF), (int)((c >> 16) & 0xFF));
        if (dlg.ShowDialog() != System.Windows.Forms.DialogResult.OK) return;
        var col = dlg.Color;
        uint cref = (uint)(col.R | (col.G << 8) | (col.B << 16));     // COLORREF 0x00BBGGRR
        ApplyStyle(el => el.FontColor = cref);
        colorSwatch.Background = FromColorRef(cref);
    }

    void NoColor_Click(object s, RoutedEventArgs e)
    {
        if (_sel == null) return;
        ApplyStyle(el => el.FontColor = null);
        colorSwatch.Background = Brushes.Transparent;
    }

    // ---------- style command bar (text / font / size act on the selection) ----------
    void BarText_Changed(object s, TextChangedEventArgs e)
    {
        if (_suppressProp || _sel == null || !_sel.Inserted) return;
        if (!_editGuard) { PushUndo(); _editGuard = true; }
        _sel.Title = txtBarText.Text; _sel.Dirty = true;
        if (_chips.TryGetValue(_sel, out var b) && b.Child is TextBlock tb)
            tb.Text = _sel.Kind == TplKind.Image ? "🖼 " + _sel.Display : _sel.Display;
        else Render();
    }

    void BarFont_Changed(object s, RoutedEventArgs e)
    {
        if (_suppressProp || _sel == null) return;
        string name = (cmbFontBar.Text ?? "").Trim();
        if (_selection.Count == 1 && name == _sel.FontName) return;
        ApplyStyle(el => el.FontName = name);
    }

    void BarSize_Changed(object s, TextChangedEventArgs e)
    {
        if (_suppressProp || _sel == null) return;
        int sz = int.TryParse(txtBarSize.Text, out var v) ? v : 0;
        if (_selection.Count == 1 && sz == _sel.FontSize) return;
        ApplyStyle(el => el.FontSize = sz);
    }

    // ---------- style command bar / menu (act on all selected) ----------
    void StyleFont_Click(object s, RoutedEventArgs e) => EditFontDialog(_sel);
    void StyleColor_Click(object s, RoutedEventArgs e) => ChangeColor();

    void StyleBold_Click(object s, RoutedEventArgs e)
    {
        if (_sel == null) return;
        bool nb = !_sel.Bold;
        ApplyStyle(el => { el.Bold = nb; el.FontStyle = nb ? 700 : 400; });
        PopulateProps(_sel);
    }

    void StyleBigger_Click(object s, RoutedEventArgs e) => BumpSize(+1);
    void StyleSmaller_Click(object s, RoutedEventArgs e) => BumpSize(-1);

    void BumpSize(int delta)
    {
        if (_sel == null) return;
        ApplyStyle(el => el.FontSize = Math.Max(4, (el.FontSize > 0 ? el.FontSize : 9) + delta));
        PopulateProps(_sel);
    }

    // One-shot font + style + colour picker (right-click menu / toolbar / menu) — applies to all selected.
    void EditFontDialog(TplElement? el)
    {
        if (el == null) return;
        if (!_selection.Contains(el)) Select(el);   // right-clicking a non-selected control acts on just it
        using var fd = new System.Windows.Forms.FontDialog { ShowColor = true, ShowEffects = true, FontMustExist = false };
        try
        {
            var style = el.Bold ? System.Drawing.FontStyle.Bold : System.Drawing.FontStyle.Regular;
            fd.Font = new System.Drawing.Font(el.FontName.Length > 0 ? el.FontName : "Segoe UI",
                                              el.FontSize > 0 ? el.FontSize : 9, style);
            if (el.FontColor is uint c)
                fd.Color = System.Drawing.Color.FromArgb((int)(c & 0xFF), (int)((c >> 8) & 0xFF), (int)((c >> 16) & 0xFF));
        }
        catch { /* invalid current font; dialog opens with defaults */ }

        if (fd.ShowDialog() != System.Windows.Forms.DialogResult.OK) return;
        var ft = fd.Font;
        int pts = (int)Math.Round(ft.SizeInPoints);
        uint cref = (uint)(fd.Color.R | (fd.Color.G << 8) | (fd.Color.B << 16));
        ApplyStyle(t => { t.FontName = ft.Name; t.FontSize = pts; t.Bold = ft.Bold; t.FontStyle = ft.Bold ? 700 : 400; t.FontColor = cref; });
        PopulateProps(_sel);
        status.Text = $"{(_selection.Count > 1 ? _selection.Count + " controls" : _sel?.Display)}  →  {ft.Name} {pts}pt{(ft.Bold ? " Bold" : "")}";
    }

    // ---------- canvas dragging ----------
    void Canvas_MouseDown(object s, MouseButtonEventArgs e)
    {
        if (_preview || e.OriginalSource != canvas) return;
        Select(null);
        _marquee = true; _marqueeStart = e.GetPosition(canvas);
        _marqueeRect = new Rectangle
        {
            Stroke = new SolidColorBrush(Color.FromRgb(0, 120, 200)), StrokeThickness = 1,
            StrokeDashArray = new DoubleCollection { 3, 2 },
            Fill = new SolidColorBrush(Color.FromArgb(28, 0, 120, 200))
        };
        Panel.SetZIndex(_marqueeRect, 3_000_000);
        Canvas.SetLeft(_marqueeRect, _marqueeStart.X); Canvas.SetTop(_marqueeRect, _marqueeStart.Y);
        canvas.Children.Add(_marqueeRect);
        canvas.CaptureMouse();
        e.Handled = true;
    }

    void Canvas_MouseMove(object s, MouseEventArgs e)
    {
        var p = e.GetPosition(canvas);
        hRuler.MouseDlu = p.X / Scale; vRuler.MouseDlu = p.Y / Scale;
        hRuler.InvalidateVisual(); vRuler.InvalidateVisual();

        if (_marquee && _marqueeRect != null)
        {
            double mx = Math.Min(p.X, _marqueeStart.X), my = Math.Min(p.Y, _marqueeStart.Y);
            Canvas.SetLeft(_marqueeRect, mx); Canvas.SetTop(_marqueeRect, my);
            _marqueeRect.Width = Math.Abs(p.X - _marqueeStart.X); _marqueeRect.Height = Math.Abs(p.Y - _marqueeStart.Y);
            return;
        }

        // A plain click must only select — don't move/resize until the mouse really travels.
        if ((_drag == Drag.Element || _drag == Drag.Resize) && !_dragMoved)
        {
            if (Math.Abs(p.X - _dragStart.X) <= DragThreshold && Math.Abs(p.Y - _dragStart.Y) <= DragThreshold) return;
            _dragMoved = true;
        }

        if (_drag == Drag.Element && _dragEl != null)
        {
            double nx = SnapX(_elStartX + (p.X - _dragStart.X) / Scale);
            double ny = SnapY(_elStartY + (p.Y - _dragStart.Y) / Scale);
            if (_selection.Count <= 1) MoveElement(_dragEl, nx, ny);
            else MoveGroup(nx - _elStartX, ny - _elStartY);     // move the whole selection by the same delta
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
            else if (miSnapGrid.IsChecked == true) v = Math.Round(v / GridStep) * GridStep;
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
        if (_marquee)
        {
            _marquee = false;
            if (_marqueeRect != null)
            {
                double x = Canvas.GetLeft(_marqueeRect) / Scale, y = Canvas.GetTop(_marqueeRect) / Scale;
                double w = _marqueeRect.Width / Scale, h = _marqueeRect.Height / Scale;
                canvas.Children.Remove(_marqueeRect); _marqueeRect = null;
                if (w > 1 && h > 1) SelectInRect(x, y, w, h);
            }
            canvas.ReleaseMouseCapture();
            return;
        }
        if (_drag == Drag.Guide && _dragGuide != null && InRulerZone(e.GetPosition(scroller)))
            DeleteGuide(_dragGuide);
        else if (_drag == Drag.Element && _dragEl != null && !_dragEl.IsContainer && _selection.Count <= 1)
            TryReparent(_dragEl);            // dropping a single control may move it in/out of a group box
        bool wasElementGesture = _drag is Drag.Element or Drag.Resize;
        canvas.ReleaseMouseCapture();
        _drag = Drag.None; _dragEl = null; _dragGuide = null;
        if (wasElementGesture) CommitGesture();
    }

    void SelectInRect(double x, double y, double w, double h)
    {
        if (_tab == null) return;
        _selection.Clear();
        foreach (var el in Positionable(_tab))
            if (el.LX < x + w && el.LX + el.LW > x && el.LY < y + h && el.LY + el.LH > y)
                _selection.Add(el);
        _sel = _selection.Count > 0 ? _selection[^1] : null;
        AfterSelectionChanged();
        status.Text = _selection.Count > 0 ? $"{_selection.Count} control(s) selected." : "Nothing selected.";
    }

    bool AncestorSelected(TplElement el)
    {
        for (var p = el.Parent; p != null; p = p.Parent) if (_selection.Contains(p)) return true;
        return false;
    }

    void MoveGroup(double dX, double dY)
    {
        foreach (var el in _selection)
            if (!AncestorSelected(el) && _dragStartPos.TryGetValue(el, out var st))
                MoveElement(el, st.X + dX, st.Y + dY);   // a selected box carries its children
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
        _gestureChanged = true;
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
        _gestureChanged = true;
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
        BeginGesture();
        _resizeEdge = (Edge)((Rectangle)s).Tag;
        _drag = Drag.Resize; _dragMoved = false;
        _dragStart = e.GetPosition(canvas);
        _rStartX = _sel.LX; _rStartY = _sel.LY; _rStartW = _sel.LW; _rStartH = _sel.LH;
        canvas.CaptureMouse();
        e.Handled = true;
    }

    void ResizeElement(TplElement el, double lx, double ly, double lw, double lh)
    {
        _gestureChanged = true;
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
        if (miSnapGuide.IsChecked == true)
            foreach (var g in _guides.Where(g => g.Vertical))
                if (Math.Abs(g.Dlu - dlu) * Scale <= SnapPx) return g.Dlu;
        if (miSnapGrid.IsChecked == true) return Math.Round(dlu / GridStep) * GridStep;
        return Math.Round(dlu);
    }
    double SnapY(double dlu)
    {
        if (miSnapGuide.IsChecked == true)
            foreach (var g in _guides.Where(g => !g.Vertical))
                if (Math.Abs(g.Dlu - dlu) * Scale <= SnapPx) return g.Dlu;
        if (miSnapGrid.IsChecked == true) return Math.Round(dlu / GridStep) * GridStep;
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
        PushUndo();
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
        PushUndo();
        _drag = Drag.Guide; _dragGuide = g;
        canvas.CaptureMouse();
        e.Handled = true;
    }

    void DeleteGuide(Guide g)
    {
        PushUndo();
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
        if (srcEditor.IsKeyboardFocusWithin) return;   // let the source editor handle its own keys
        if ((Keyboard.Modifiers & ModifierKeys.Control) != 0 && e.Key == Key.Z)
        {
            if (Keyboard.FocusedElement is TextBox) return;   // let the editor's own undo run
            Undo(); e.Handled = true; return;
        }
        if (_sel == null) return;
        if (e.Key is Key.Delete or Key.Back)
        {
            if (Keyboard.FocusedElement is TextBox) return;   // let the X/Y/W/H editors handle it
            DeleteSelection(); e.Handled = true; return;
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
        if (!e.IsRepeat) PushUndo();   // one undo per discrete press; a held key reverts as one step
        MoveElement(_sel, Math.Max(0, nx), Math.Max(0, ny));
        RefreshLiveSource();
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
