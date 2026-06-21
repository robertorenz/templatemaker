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
using System.Xml.Linq;
using System.Text.RegularExpressions;
using ICSharpCode.AvalonEdit.CodeCompletion;
using ICSharpCode.AvalonEdit.Document;
using ICSharpCode.AvalonEdit.Editing;
using ICSharpCode.AvalonEdit.Highlighting;
using ICSharpCode.AvalonEdit.Highlighting.Xshd;
using ICSharpCode.AvalonEdit.Rendering;
using ICSharpCode.AvalonEdit.Search;
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

    // ---- open templates (one tab each) ----
    // The fields above are the ACTIVE document's live working set; everything in the file keeps reading
    // them directly. Switching tabs captures the live state into the outgoing session and restores the
    // incoming one, so the ~200 existing references don't need to change.
    readonly List<DocumentSession> _sessions = new();
    DocumentSession? _active;

    double Scale => sldZoom.Value;          // pixels per DLU
    int GridStep => int.TryParse(txtGrid.Text, out var g) && g > 0 ? g : 5;
    const double SnapPx = 6;                 // snap threshold in pixels

    // Clarion prompt windows render text in this dialog font. Calibrated against Clarion 12: a label's width
    // in DLU ~= its Microsoft Sans Serif 8pt pixel width * FontCal, so on the canvas we render the text at
    // (pt * Scale * FontCal) px. This makes a label occupy the SAME number of DLU it will in Clarion, so what
    // fits (or overlaps the entry) here fits (or overlaps) there. Without it the designer under-measured text.
    // The font Clarion's AppGen renders prompt sheets in - read from the IDE "AppGen Dialogs" setting
    // (Options > IDE > Fonts > Dialogs). This is the DEFAULT face and the basis for the DLU calibration;
    // a per-control PROP:FontName still overrides it. Defaults to Segoe UI 9 if the IDE config isn't found.
    string _ideFontName = "Segoe UI";
    double _ideFontSize = 9;
    // Render size: point size scaled to the zoom so text sits in the controls the way Clarion shows it.
    const double FontRenderCal = 0.62;
    // Horizontal dialog-unit metric (px of the IDE font per DLU) used ONLY to judge whether a label fits the
    // gap to its entry. Independent of the render size so the overlap guide stays accurate at any zoom.
    const double ClarionHDlu = 1.1;
    double DluFontPx(TplElement el) => Math.Max(8, (el.FontSize > 0 ? el.FontSize : _ideFontSize) * Scale * FontRenderCal);
    FontFamily UiFontFamily(TplElement el) =>
        new FontFamily(string.IsNullOrWhiteSpace(el.FontName) ? _ideFontName : el.FontName);

    // Read the AppGen dialog font from %APPDATA%\SoftVelocity\Clarion\<ver>\ClarionProperties.xml so the
    // designer renders and measures prompt text exactly as Clarion will. Highest installed version wins.
    void LoadClarionDialogFont()
    {
        try
        {
            string appdata = Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData);
            foreach (var ver in new[] { "15.0", "14.0", "13.0", "12.0", "11.0", "10.0" })
            {
                string p = System.IO.Path.Combine(appdata, "SoftVelocity", "Clarion", ver, "ClarionProperties.xml");
                if (!System.IO.File.Exists(p)) continue;
                var props = XDocument.Load(p).Descendants("Properties")
                                     .FirstOrDefault(e => (string?)e.Attribute("name") == "AppGen Dialogs");
                if (props == null) continue;
                var name = (string?)props.Elements("DlgFontName").FirstOrDefault()?.Attribute("value");
                var size = (string?)props.Elements("DlgFontSize").FirstOrDefault()?.Attribute("value");
                if (!string.IsNullOrWhiteSpace(name)) _ideFontName = name!;
                if (double.TryParse(size, out var s) && s > 0) _ideFontSize = s;
                return;
            }
        }
        catch { /* keep the Segoe UI 9 defaults */ }
    }

    // Apply the Clarion font-STYLE flags (italic / underline / strikeout) to a canvas TextBlock.
    static void ApplyTextStyle(TextBlock t, TplElement el)
    {
        if (el.Italic) t.FontStyle = FontStyles.Italic;
        if (el.Underline || el.Strikeout)
        {
            var dec = new TextDecorationCollection();
            if (el.Underline) foreach (var d in TextDecorations.Underline) dec.Add(d);
            if (el.Strikeout) foreach (var d in TextDecorations.Strikethrough) dec.Add(d);
            t.TextDecorations = dec;
        }
    }

    readonly List<TplElement> _selection = new();                       // all selected (incl. the primary _sel)
    readonly Dictionary<TplElement, (double X, double Y)> _dragStartPos = new();
    bool _marquee; Point _marqueeStart; Rectangle? _marqueeRect;
    readonly Dictionary<TplElement, Border> _chips = new();
    readonly Dictionary<TplElement, Border> _promptLabels = new();   // the separate label visual for side-label prompts
    readonly Dictionary<string, BitmapImage?> _imgCache = new(StringComparer.OrdinalIgnoreCase);
    readonly List<Guide> _guides = new();

    enum Drag { None, Element, Guide, Resize }
    Drag _drag = Drag.None;
    TplElement? _dragEl;
    bool _dragLabel;                    // the current Element drag is moving a prompt's LABEL (PROMPTAT), not its entry
    Guide? _dragGuide;
    Point _dragStart;
    double _elStartX, _elStartY;
    bool _dragMoved;                  // mouse has travelled past the threshold this gesture
    const double DragThreshold = 3;   // px before a click becomes a drag
    bool _suppressProp;
    bool _ready;          // true once XAML is fully constructed
    List<TplElement>? _childList;     // controls listed for the selected group box
    bool _suppressChildSel;
    readonly List<(int File, int Line)> _uses = new();   // usages listed for the selected control's symbol
    bool _suppressUses;

    // ---- undo (snapshot history) ----
    readonly List<Snapshot> _undo = new();
    readonly List<Snapshot> _redo = new();
    Snapshot? _gestureSnap;           // captured at a drag/resize start, committed on end if it changed anything
    bool _gestureChanged;
    bool _editGuard;                  // one undo entry per X/Y/W/H or text editing burst
    const int MaxUndo = 100;
    readonly LineHighlighter _lineHi = new();   // highlights selected controls' lines in the source
    Dictionary<TplElement, int>? _pendingMap;   // model element -> line in the live/pending source text
    bool _srcOpen;                    // source panel visible
    bool _srcDirty, _loadingSrc;      // editor has unapplied edits / suppress TextChanged while loading
    bool _srcLive;                    // show the would-be-saved source (all pending edits) read-only
    int _srcViewFile = -1;            // >=0: panel is showing this file read-only (a #GROUP source for a foreign control), not the part's file
    IHighlightingDefinition? _clarionHl;

    // panel layout persistence
    FrameworkElement? _designerContent, _sourceContent, _propsContent, _outlineContent, _problemsContent, _symbolsContent;
    bool _buildingOutline;
    string? _defaultLayoutXml;
    LayoutAnchorable? _wiredSource;

    sealed class Snapshot
    {
        public readonly List<List<TplElement>> Tabs = new();    // deep-cloned trees, parallel to doc.Components
        public List<(bool V, double Dlu)> Guides = new();
        public readonly List<(string[] Lines, bool Dirty)> Files = new();   // raw file text, so a symbol rename is undoable
    }

    // One open template (its model plus the editing state that should survive a tab switch).
    sealed class DocumentSession
    {
        public TplDocument Doc = null!;
        public int PartIndex, TabIndex;                         // selection to restore
        public readonly List<Snapshot> Undo = new();
        public readonly List<Snapshot> Redo = new();
        public readonly List<Guide> Guides = new();
        public bool SrcLive, SrcDirty;                          // source-panel mode / unapplied editor edits
        public string? PendingSrcText;                          // editor text when SrcDirty (so edits aren't lost on switch)
        public bool HasViewState;                               // false until first captured (fresh open keeps the part-scroll)
        public int SrcCaret;
        public double SrcScroll;
        public readonly Dictionary<string, DateTime> WriteTimes = new(StringComparer.OrdinalIgnoreCase);
        public readonly HashSet<string> DeletedWarned = new(StringComparer.OrdinalIgnoreCase);
        public string Path => Doc?.Path ?? "";
        public string Title => string.IsNullOrEmpty(Path) ? "(untitled)" : System.IO.Path.GetFileName(Path);
    }

    [Flags] enum Edge { None = 0, Left = 1, Right = 2, Top = 4, Bottom = 8 }
    Edge _resizeEdge;
    double _rStartX, _rStartY, _rStartW, _rStartH;   // selection rect (DLU) at resize start
    readonly List<Rectangle> _handles = new();
    const double MinDlu = 4, HandlePx = 8;

    public MainWindow()
    {
        InitializeComponent();
        LoadClarionDialogFont();       // render/measure prompt text in Clarion's actual AppGen dialog font
        PreviewKeyDown += OnKeyDown;   // tunnel: see arrows before the ScrollViewer scrolls on them
        canvas.Focusable = true;       // so the canvas can hold keyboard focus for nudging
        lblDialogFont.Text = lblBarDialogFont.Text = $"{_ideFontName} · {_ideFontSize:0} pt  (Clarion IDE)";
        cmbPromptType.ItemsSource = new[]
        {
            "@s255", "@n8", "@n-12.2", "@d1", "CHECK", "SPIN(@n3,0,100)", "DROP('Item1|Item2')",
            "FROM(%Queue)", "OPTION", "RADIO", "PROCEDURE", "EXPR", "KEYCODE", "COLOR", "FONT", "FILE('All|*.*')"
        };
        WireSource(anchSource);
        _srcOpen = anchSource.IsVisible;
        miViewSource.IsChecked = _srcOpen;
        srcMap.GoToLine += ln => srcEditor.ScrollToLine(Math.Min(srcEditor.Document?.LineCount ?? 1, ln + 1));
        srcEditor.TextArea.TextView.ScrollOffsetChanged += (_, _) => UpdateMinimapViewport();
        srcEditor.TextArea.TextView.BackgroundRenderers.Add(_lineHi);
        SearchPanel.Install(srcEditor);                       // Ctrl+F find/replace in the source
        srcEditor.TextArea.TextEntered += Src_TextEntered;    // %symbol / #directive autocomplete
        srcEditor.PreviewTextInput += (_, e2) =>              // typing into the read-only live preview -> hint
        {
            if (_srcLive) { status.Text = "This is a read-only live preview — uncheck “Live (pending)” to edit the source, then Apply."; e2.Handled = true; }
        };
        _ready = true;

        // remember panel contents + the pristine layout, then restore the user's saved layout
        _designerContent = designerHost;
        _sourceContent = (FrameworkElement)anchSource.Content;
        _propsContent = (FrameworkElement)anchProps.Content;
        _outlineContent = (FrameworkElement)anchOutline.Content;
        _problemsContent = (FrameworkElement)anchProblems.Content;
        _symbolsContent = (FrameworkElement)anchSymbols.Content;
        miViewOutline.IsChecked = anchOutline.IsVisible;
        miViewProblems.IsChecked = anchProblems.IsVisible;
        miViewSymbols.IsChecked = anchSymbols.IsVisible;
        try { _defaultLayoutXml = SerializeLayout(); } catch { }
        LoadPrefs();
        LoadRecent();
        RefreshRecentMenus();
        Loaded += (_, _) => TryLoadSavedLayout();
        Closing += Window_Closing;
        Activated += (_, _) => CheckExternalChanges();   // re-check on focus: catches saves made while unfocused or any FS event we missed
        RefreshDocTabs();
    }

    void Window_Closing(object? sender, System.ComponentModel.CancelEventArgs e)
    {
        CaptureActive();
        var dirty = _sessions.Where(IsSessionDirty).Select(s => s.Title).ToList();
        if (dirty.Count > 0)
        {
            var r = MessageBox.Show(
                "These open templates have unsaved changes:\n  " + string.Join("\n  ", dirty) +
                "\n\nClose anyway and discard them?",
                "Unsaved changes", MessageBoxButton.YesNo, MessageBoxImage.Warning, MessageBoxResult.No);
            if (r != MessageBoxResult.Yes) { e.Cancel = true; return; }
        }
        SaveLayout(); SavePrefs(); StopWatching();
    }

    // ---------- file ----------
    void Open_Click(object s, RoutedEventArgs e)
    {
        var dlg = new OpenFileDialog { Filter = "Clarion template (*.tpl;*.tpw)|*.tpl;*.tpw|All files|*.*" };
        if (dlg.ShowDialog() == true) OpenPath(dlg.FileName);
    }

    void OpenPath(string path)
    {
        if (!System.IO.File.Exists(path))
        {
            MessageBox.Show($"The file no longer exists:\n{path}", "Open",
                MessageBoxButton.OK, MessageBoxImage.Warning);
            RemoveRecent(path);
            return;
        }
        // already open? just bring its tab forward instead of loading a duplicate
        var full = SafeFull(path);
        var already = _sessions.FirstOrDefault(s => string.Equals(SafeFull(s.Doc.Path), full, StringComparison.OrdinalIgnoreCase));
        if (already != null) { ActivateSession(already); status.Text = $"{already.Title} is already open."; return; }
        try
        {
            var doc = TplParser.Parse(path);
            CaptureActive();                                   // stash the current tab before switching away
            var session = new DocumentSession { Doc = doc, PartIndex = 0, TabIndex = 0 };
            _sessions.Add(session);
            ActivateSession(session, captureCurrent: false);   // already captured above
            SetSource(true);                                   // first open: ensure the source panel is visible
            int files = doc.Files.Count, comps = doc.Components.Count;
            status.Text = $"Loaded {_parts.Count} editable part(s) of {comps} component(s) across {files} file(s). "
                        + "Pick a Part and Tab; the colour-coded source is in the panel below (toggle with “View Source”).";
            AddRecent(path);
        }
        catch (Exception ex) { MessageBox.Show("Parse failed:\n" + ex.Message); }
    }

    // ---------- open templates (tab per document) ----------

    // Make `s` the active tab: stash the current tab's live state, load `s`'s state into the live fields,
    // then rebuild the UI from the model. All the existing code keeps reading the live fields unchanged.
    void ActivateSession(DocumentSession s, bool captureCurrent = true)
    {
        if (_active == s) { RefreshDocTabs(); return; }
        if (captureCurrent) CaptureActive();
        StopWatching();

        _active = s;
        _doc = s.Doc;
        _component = null; _tab = null; _sel = null; _selection.Clear();
        _undo.Clear(); _undo.AddRange(s.Undo);
        _redo.Clear(); _redo.AddRange(s.Redo);
        _guides.Clear(); _guides.AddRange(s.Guides);

        // restore source-panel mode (Click doesn't fire on programmatic IsChecked, so set the chrome ourselves)
        _srcLive = s.SrcLive; _srcDirty = false;
        chkLive.IsChecked = s.SrcLive;
        srcEditor.IsReadOnly = _srcLive;
        srcEditor.Background = _srcLive ? new SolidColorBrush(Color.FromRgb(0xF1, 0xF3, 0xF6)) : Brushes.White;

        Title = "Clarion Template Designer — " + s.Title;
        PopulateParts(s.PartIndex, s.TabIndex);   // rebuilds parts/tabs, selects, Render + LoadSource
        Validate();
        PopulateSymbols();

        // put back any unapplied editor edits (normal mode only — the live preview is regenerated text)
        if (!_srcLive && s.PendingSrcText != null)
        {
            _loadingSrc = true;
            try { srcEditor.Text = s.PendingSrcText; } finally { _loadingSrc = false; }
            _srcDirty = true; btnApplySrc.IsEnabled = true;
        }
        if (s.HasViewState) RestoreSrcView(s.SrcCaret, s.SrcScroll);   // fresh opens keep the part-scroll instead

        // restore this doc's watcher baseline, catch edits made while it was backgrounded, then watch it live
        _fileWriteTimes.Clear(); foreach (var kv in s.WriteTimes) _fileWriteTimes[kv.Key] = kv.Value;
        _deletedWarned.Clear();  foreach (var p in s.DeletedWarned) _deletedWarned.Add(p);
        CheckExternalChanges();   // may reload if the file changed while this tab was in the background
        StartWatching();          // re-baseline + watch the now-active document

        RefreshDocTabs();
    }

    // Stash the active tab's live editing state back into its session before we switch away.
    void CaptureActive()
    {
        var s = _active;
        if (s == null || _doc == null) return;
        s.Doc = _doc;                              // keep the (possibly reloaded) model reference
        s.PartIndex = cmbParts.SelectedIndex;
        s.TabIndex = cmbTabs.SelectedIndex;
        s.Undo.Clear(); s.Undo.AddRange(_undo);
        s.Redo.Clear(); s.Redo.AddRange(_redo);
        s.Guides.Clear(); s.Guides.AddRange(_guides);
        s.SrcLive = _srcLive;
        s.SrcDirty = _srcDirty && !_srcLive;
        s.PendingSrcText = s.SrcDirty ? srcEditor.Text : null;
        s.SrcCaret = srcEditor.CaretOffset;
        s.SrcScroll = srcEditor.VerticalOffset;
        s.HasViewState = true;
        s.WriteTimes.Clear(); foreach (var kv in _fileWriteTimes) s.WriteTimes[kv.Key] = kv.Value;
        s.DeletedWarned.Clear(); foreach (var p in _deletedWarned) s.DeletedWarned.Add(p);
    }

    void RestoreSrcView(int caret, double scroll)
    {
        var doc = srcEditor.Document;
        if (doc == null) return;
        try { srcEditor.CaretOffset = Math.Min(Math.Max(caret, 0), doc.TextLength); } catch { }
        Dispatcher.BeginInvoke(new Action(() => { try { srcEditor.ScrollToVerticalOffset(scroll); } catch { } }),
            System.Windows.Threading.DispatcherPriority.Loaded);
    }

    void CloseSession(DocumentSession s)
    {
        if (s == _active) CaptureActive();
        if (IsSessionDirty(s))
        {
            var r = MessageBox.Show($"{s.Title} has unsaved changes. Save before closing?",
                "Close template", MessageBoxButton.YesNoCancel, MessageBoxImage.Warning, MessageBoxResult.Cancel);
            if (r == MessageBoxResult.Cancel) return;
            if (r == MessageBoxResult.Yes)
            {
                if (s != _active) ActivateSession(s);
                Save_Click(this, new RoutedEventArgs());
                if (IsSessionDirty(s)) return;   // save failed — keep the tab open
            }
        }

        int idx = _sessions.IndexOf(s);
        bool wasActive = s == _active;
        _sessions.Remove(s);
        if (wasActive)
        {
            _active = null;
            if (_sessions.Count == 0) ClearToEmptyState();
            else ActivateSession(_sessions[Math.Min(idx, _sessions.Count - 1)], captureCurrent: false);
        }
        RefreshDocTabs();
    }

    // Back to the no-document state (closing the last tab).
    void ClearToEmptyState()
    {
        StopWatching();
        _active = null; _doc = null; _component = null; _tab = null; _sel = null;
        _selection.Clear(); _undo.Clear(); _redo.Clear(); _guides.Clear();
        _fileWriteTimes.Clear(); _deletedWarned.Clear();
        cmbParts.ItemsSource = null; cmbParts.SelectedIndex = -1;
        cmbTabs.ItemsSource = null; cmbTabs.SelectedIndex = -1;
        Title = "Clarion Template Designer";
        Render();        // _tab == null clears the canvas
        LoadSource();    // null file → placeholder text
        Validate();
        PopulateSymbols();
    }

    bool IsSessionDirty(DocumentSession s)
    {
        bool srcDirty = s == _active ? (_srcDirty && !_srcLive) : s.SrcDirty;
        return srcDirty || DocDirty(s.Doc);
    }

    static bool DocDirty(TplDocument? doc) =>
        doc != null && (doc.Files.Any(f => f.Dirty) ||
            doc.Components.SelectMany(c => c.Tabs).SelectMany(Flat).Any(HasPendingEdit));

    // Rebuild the tab strip from _sessions (manual, matching the codebase's code-driven UI style).
    void RefreshDocTabs()
    {
        if (docTabs == null) return;
        docTabs.Children.Clear();
        foreach (var s in _sessions)
        {
            bool active = s == _active;
            var inner = new StackPanel { Orientation = Orientation.Horizontal };
            if (IsSessionDirty(s))
                inner.Children.Add(new TextBlock { Text = "● ", Foreground = Brushes.OrangeRed, FontSize = 10,
                                                   VerticalAlignment = VerticalAlignment.Center });
            inner.Children.Add(new TextBlock
            {
                Text = s.Title, VerticalAlignment = VerticalAlignment.Center,
                Foreground = active ? Brushes.Black : new SolidColorBrush(Color.FromRgb(0x55, 0x5A, 0x61)),
                FontWeight = active ? FontWeights.SemiBold : FontWeights.Normal
            });
            var close = new Button
            {
                Content = "✕", Width = 16, Height = 16, Margin = new Thickness(6, 0, 0, 0), Padding = new Thickness(0),
                FontSize = 9, Background = Brushes.Transparent, BorderThickness = new Thickness(0),
                Cursor = System.Windows.Input.Cursors.Hand, ToolTip = "Close template"
            };
            var captured = s;
            close.Click += (_, e) => { e.Handled = true; CloseSession(captured); };
            inner.Children.Add(close);
            var tab = new Border
            {
                Child = inner,
                Padding = new Thickness(9, 3, 5, 3),
                Margin = new Thickness(0, 2, 2, 0),
                Background = active ? Brushes.White : new SolidColorBrush(Color.FromRgb(0xD3, 0xD9, 0xE0)),
                BorderBrush = new SolidColorBrush(Color.FromRgb(0xC4, 0xCC, 0xD6)),
                BorderThickness = new Thickness(1, 1, 1, active ? 0 : 1),
                CornerRadius = new CornerRadius(4, 4, 0, 0),
                Cursor = System.Windows.Input.Cursors.Hand,
                ToolTip = s.Path
            };
            tab.MouseLeftButtonDown += (_, _) => ActivateSession(captured);
            docTabs.Children.Add(tab);
        }
        docTabBar.Visibility = _sessions.Count > 0 ? Visibility.Visible : Visibility.Collapsed;
    }

    // ---------- recent files (MRU) ----------
    readonly List<string> _recent = new();
    string RecentPath => System.IO.Path.Combine(
        Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData),
        "ClarionTemplateDesigner", "recent.txt");

    void LoadRecent()
    {
        try
        {
            _recent.Clear();
            if (System.IO.File.Exists(RecentPath))
                foreach (var l in System.IO.File.ReadAllLines(RecentPath))
                    if (l.Trim().Length > 0 && !_recent.Contains(l, StringComparer.OrdinalIgnoreCase)) _recent.Add(l.Trim());
        }
        catch { }
    }

    void SaveRecent()
    {
        try
        {
            var dir = System.IO.Path.GetDirectoryName(RecentPath);
            if (dir != null) System.IO.Directory.CreateDirectory(dir);
            System.IO.File.WriteAllLines(RecentPath, _recent.Take(12));
        }
        catch { }
    }

    void AddRecent(string path)
    {
        _recent.RemoveAll(p => string.Equals(p, path, StringComparison.OrdinalIgnoreCase));
        _recent.Insert(0, path);
        while (_recent.Count > 12) _recent.RemoveAt(_recent.Count - 1);
        SaveRecent();
        RefreshRecentMenus();
    }

    void RemoveRecent(string path)
    {
        _recent.RemoveAll(p => string.Equals(p, path, StringComparison.OrdinalIgnoreCase));
        SaveRecent();
        RefreshRecentMenus();
    }

    // Build both Recent menus eagerly — a submenu must already have items or WPF won't open it.
    void RefreshRecentMenus()
    {
        PopulateRecentMenu(miRecentBar);
        PopulateRecentMenu(miRecentFile);
    }

    void RecentBar_Opened(object s, RoutedEventArgs e)
    {
        if (s is MenuItem mi) PopulateRecentMenu(mi);     // refresh on open too
    }

    void PopulateRecentMenu(MenuItem mi)
    {
        if (mi == null) return;
        mi.Items.Clear();
        if (_recent.Count == 0)
        {
            mi.Items.Add(new MenuItem { Header = "(no recent files)", IsEnabled = false });
            return;
        }
        int n = 1;
        foreach (var path in _recent)
        {
            var item = new MenuItem { Header = $"_{n++}  {System.IO.Path.GetFileName(path)}", ToolTip = path };
            var captured = path;
            item.Click += (_, _) => OpenPath(captured);
            mi.Items.Add(item);
        }
        mi.Items.Add(new Separator());
        var clear = new MenuItem { Header = "Clear recent files" };
        clear.Click += (_, _) => { _recent.Clear(); SaveRecent(); RefreshRecentMenus(); };
        mi.Items.Add(clear);
    }

    void ToolbarFind_Click(object s, RoutedEventArgs e)
    {
        if (!_srcOpen) SetSource(true);
        srcEditor.Focus();
        ApplicationCommands.Find.Execute(null, srcEditor.TextArea);   // opens AvalonEdit's search panel
    }

    // Tabs shown in the UI: deleted ones stay in _component.Tabs (so the writer can drop them) but are hidden.
    List<TplElement> LiveTabs() => _component == null ? new() : _component.Tabs.Where(t => !t.Deleted).ToList();

    void RefreshTabSelector(int select = -1)
    {
        if (_component == null) return;
        var lts = LiveTabs();
        int keep = select >= 0 ? select : cmbTabs.SelectedIndex;   // capture BEFORE the ItemsSource swap clears it
        cmbTabs.ItemsSource = lts.Select(t => t.Title).ToList();
        if (lts.Count == 0) { cmbTabs.SelectedIndex = -1; return; }
        // ForceSelect so Tab_Changed always re-fires (rebuilds _tab + re-renders) even when the index is unchanged.
        ForceSelect(cmbTabs, Math.Min(Math.Max(keep, 0), lts.Count - 1));
    }

    void PopulateParts(int partIdx, int tabIdx)
    {
        if (_doc == null) return;
        _parts = _doc.Components.Where(c => c.HasSheet).ToList();
        _pendingTabIdx = tabIdx;
        // WPF preserves a ComboBox selection by VALUE across an ItemsSource swap, so switching to a document
        // whose part label matches would leave SelectedIndex unchanged and Part_Changed would never fire
        // (stale canvas). ForceSelect bounces through -1 so the real selection always raises the event.
        cmbParts.ItemsSource = _parts.Select(PartLabel).ToList();
        if (_parts.Count > 0) ForceSelect(cmbParts, Math.Min(Math.Max(partIdx, 0), _parts.Count - 1));
        else { cmbParts.SelectedIndex = -1; _component = null; _tab = null; cmbTabs.ItemsSource = null; Render(); }
    }

    // The designer is driven purely through cmbParts/cmbTabs SelectionChanged handlers.
    // After swapping a combo's ItemsSource to another document's parts/tabs, WPF can
    // preserve the selected *value* (e.g. an identically-labelled part) so the index
    // never changes — and assigning SelectedIndex the value it already holds raises no
    // event, so Part_Changed/Tab_Changed never run and the canvas keeps showing the
    // previous template. Bounce through -1 so the handler always fires for `index`.
    static void ForceSelect(ComboBox cmb, int index)
    {
        if (cmb.SelectedIndex == index) cmb.SelectedIndex = -1;
        cmb.SelectedIndex = index;
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
            bool structural = AllElements().Any(el => !el.Foreign && (el.Inserted || el.Deleted || el.Moved));
            TplWriter.Save(_doc);
            RecordWriteTimes();                    // our own write — re-baseline so it isn't flagged as an external change
            if (structural) ReloadFromDisk();      // re-sync the model so re-saving can't duplicate/re-drop
            else foreach (var f in _doc.Files) f.Dirty = false;   // raw-text edits (rename) are now on disk
            LoadSource();                          // reflect what's now on disk
            Validate();
            PopulateSymbols();
            RefreshDocTabs();                      // clear the tab's unsaved-changes dot
            status.Text = "Saved " + System.IO.Path.GetFileName(_doc.Path);
        }
        catch (Exception ex) { MessageBox.Show("Save failed:\n" + ex.Message); }
    }

    // ---------- preview pending changes (diff vs disk) ----------
    void PreviewChanges_Click(object s, RoutedEventArgs e)
    {
        if (_doc == null) { status.Text = "Open a template first."; return; }

        var fd = new System.Windows.Documents.FlowDocument
        {
            FontFamily = new FontFamily("Consolas"), FontSize = 12.5, PagePadding = new Thickness(10)
        };
        int changedFiles = 0;
        for (int fi = 0; fi < _doc.Files.Count; fi++)
        {
            var path = _doc.Files[fi].Path;
            string[] before = System.IO.File.Exists(path)
                ? System.IO.File.ReadAllText(path).Replace("\r\n", "\n").Split('\n') : Array.Empty<string>();
            string[] after = TplWriter.PreviewFile(_doc, fi).Replace("\r\n", "\n").Split('\n');
            if (before.SequenceEqual(after)) continue;

            changedFiles++;
            var ops = CollapseContext(DiffLines(before, after), 3);
            int add = ops.Count(o => o.op == '+'), del = ops.Count(o => o.op == '-');
            fd.Blocks.Add(new System.Windows.Documents.Paragraph(
                new System.Windows.Documents.Run($"▸ {System.IO.Path.GetFileName(path)}   +{add}  −{del}"))
            { FontWeight = FontWeights.Bold, Foreground = new SolidColorBrush(Color.FromRgb(0x0E, 0x1A, 0x2B)),
              Margin = new Thickness(0, changedFiles > 1 ? 14 : 0, 0, 4) });

            var p = new System.Windows.Documents.Paragraph { Margin = new Thickness(0) };
            foreach (var (op, text) in ops)
            {
                var run = new System.Windows.Documents.Run((op == ' ' ? "  " : op + " ") + text + "\n");
                if (op == '+') run.Foreground = new SolidColorBrush(Color.FromRgb(0x1E, 0x7C, 0x34));
                else if (op == '-') run.Foreground = new SolidColorBrush(Color.FromRgb(0xB2, 0x3A, 0x2E));
                else if (op == '~') run.Foreground = new SolidColorBrush(Color.FromRgb(0xAA, 0xB2, 0xBE));
                else run.Foreground = new SolidColorBrush(Color.FromRgb(0x55, 0x60, 0x6E));
                p.Inlines.Add(run);
            }
            fd.Blocks.Add(p);
        }
        if (changedFiles == 0)
            fd.Blocks.Add(new System.Windows.Documents.Paragraph(
                new System.Windows.Documents.Run("No pending changes — the files on disk already match the model.")));

        ShowDiffDialog(fd, changedFiles);
    }

    void ShowDiffDialog(System.Windows.Documents.FlowDocument fd, int changedFiles)
    {
        var dlg = new Window
        {
            Title = "Preview changes", Owner = this, Width = 820, Height = 620,
            WindowStartupLocation = WindowStartupLocation.CenterOwner,
            Background = new SolidColorBrush(Color.FromRgb(0xFB, 0xFC, 0xFD))
        };
        var grid = new Grid();
        grid.RowDefinitions.Add(new RowDefinition());
        grid.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto });
        var viewer = new FlowDocumentScrollViewer { Document = fd, VerticalScrollBarVisibility = ScrollBarVisibility.Auto };
        Grid.SetRow(viewer, 0); grid.Children.Add(viewer);

        var bar = new StackPanel { Orientation = Orientation.Horizontal, HorizontalAlignment = HorizontalAlignment.Right,
                                   Margin = new Thickness(10) };
        if (changedFiles > 0)
        {
            var save = new Button { Content = "Save now", Padding = new Thickness(16, 4, 16, 4), MinWidth = 90, IsDefault = true };
            save.Click += (_, __) => { dlg.Close(); Save_Click(this, new RoutedEventArgs()); };
            bar.Children.Add(save);
        }
        var close = new Button { Content = "Close", Padding = new Thickness(14, 4, 14, 4), MinWidth = 80,
                                 Margin = new Thickness(8, 0, 0, 0), IsCancel = true };
        bar.Children.Add(close);
        Grid.SetRow(bar, 1); grid.Children.Add(bar);
        dlg.Content = grid;
        dlg.ShowDialog();
    }

    // A minimal LCS line diff: ' ' context, '-' removed, '+' added.
    static List<(char op, string text)> DiffLines(string[] a, string[] b)
    {
        int n = a.Length, m = b.Length;
        var dp = new int[n + 1, m + 1];
        for (int i = n - 1; i >= 0; i--)
            for (int j = m - 1; j >= 0; j--)
                dp[i, j] = a[i] == b[j] ? dp[i + 1, j + 1] + 1 : Math.Max(dp[i + 1, j], dp[i, j + 1]);
        var res = new List<(char, string)>();
        int x = 0, y = 0;
        while (x < n && y < m)
        {
            if (a[x] == b[y]) { res.Add((' ', a[x])); x++; y++; }
            else if (dp[x + 1, y] >= dp[x, y + 1]) { res.Add(('-', a[x])); x++; }
            else { res.Add(('+', b[y])); y++; }
        }
        while (x < n) res.Add(('-', a[x++]));
        while (y < m) res.Add(('+', b[y++]));
        return res;
    }

    // Keep `ctx` context lines around each change; replace bigger unchanged runs with a single "~" marker.
    static List<(char op, string text)> CollapseContext(List<(char op, string text)> ops, int ctx)
    {
        var keep = new bool[ops.Count];
        for (int i = 0; i < ops.Count; i++)
            if (ops[i].op != ' ')
                for (int j = Math.Max(0, i - ctx); j <= Math.Min(ops.Count - 1, i + ctx); j++) keep[j] = true;
        var res = new List<(char, string)>();
        bool gap = false;
        for (int i = 0; i < ops.Count; i++)
        {
            if (keep[i]) { res.Add(ops[i]); gap = false; }
            else if (!gap) { res.Add(('~', "  …")); gap = true; }
        }
        return res;
    }

    void ReloadFromDisk()
    {
        if (_doc == null) return;
        int partIdx = cmbParts.SelectedIndex, tabIdx = cmbTabs.SelectedIndex;
        _doc = TplParser.Parse(_doc.Path);
        if (_active != null) _active.Doc = _doc;   // the active tab now owns the re-parsed model
        _undo.Clear(); _redo.Clear();   // line indices changed on disk; old snapshots no longer apply
        _sel = null;
        PopulateParts(partIdx, tabIdx);
        StartWatching();                // re-baseline write-times and watchers against what's now on disk
        RefreshDocTabs();               // dirty state changed (back in sync with disk)
    }

    // ---------- external-change detection ----------
    // The designer holds an in-memory model of the open .tpl set; if another tool (VS Code, an AI
    // assistant, etc.) rewrites one of those files on disk, the model goes stale and a later Save here
    // would silently clobber those edits. These watchers notice such writes and reload (or prompt).
    readonly List<System.IO.FileSystemWatcher> _watchers = new();
    readonly Dictionary<string, DateTime> _fileWriteTimes = new(StringComparer.OrdinalIgnoreCase); // path -> last write time we know about
    System.Windows.Threading.DispatcherTimer? _extChangeTimer;   // debounces bursts of FS events into one check
    bool _extPromptOpen;                                          // a reload prompt is already showing — don't stack another
    readonly HashSet<string> _deletedWarned = new(StringComparer.OrdinalIgnoreCase); // files we've already flagged as deleted

    static string FileNames(IEnumerable<TplFile> files) =>
        string.Join(", ", files.Select(f => System.IO.Path.GetFileName(f.Path)).Distinct(StringComparer.OrdinalIgnoreCase));

    void StopWatching()
    {
        foreach (var w in _watchers) { try { w.EnableRaisingEvents = false; w.Dispose(); } catch { } }
        _watchers.Clear();
    }

    // Re-baseline the last-known write times to whatever is on disk right now. Called after our own
    // writes and after every (re)load so those changes are never mistaken for an external edit.
    void RecordWriteTimes()
    {
        _fileWriteTimes.Clear();
        _deletedWarned.Clear();   // a fresh baseline means everything we track currently exists
        if (_doc == null) return;
        foreach (var f in _doc.Files)
        {
            if (string.IsNullOrEmpty(f.Path)) continue;
            try { if (System.IO.File.Exists(f.Path)) _fileWriteTimes[f.Path] = System.IO.File.GetLastWriteTimeUtc(f.Path); }
            catch { }
        }
    }

    void StartWatching()
    {
        StopWatching();
        RecordWriteTimes();
        if (_doc == null) return;
        var dirs = _doc.Files
            .Where(f => !string.IsNullOrEmpty(f.Path))
            .Select(f => SafeDir(f.Path))
            .Where(d => !string.IsNullOrEmpty(d) && System.IO.Directory.Exists(d))
            .Distinct(StringComparer.OrdinalIgnoreCase);
        foreach (var dir in dirs)
        {
            try
            {
                var w = new System.IO.FileSystemWatcher(dir!)
                {
                    NotifyFilter = System.IO.NotifyFilters.LastWrite | System.IO.NotifyFilters.Size
                                 | System.IO.NotifyFilters.FileName | System.IO.NotifyFilters.CreationTime,
                    IncludeSubdirectories = false,
                };
                w.Changed += OnFsEvent;
                w.Created += OnFsEvent;
                w.Deleted += OnFsEvent;
                w.Renamed += OnFsEvent;
                w.Error   += OnFsError;
                w.EnableRaisingEvents = true;
                _watchers.Add(w);
            }
            catch { /* watching is best-effort; the Activated re-check still covers us */ }
        }
    }

    static string? SafeDir(string path)
    {
        try { return System.IO.Path.GetDirectoryName(System.IO.Path.GetFullPath(path)); } catch { return null; }
    }

    static string? SafeFull(string path)
    {
        try { return System.IO.Path.GetFullPath(path); } catch { return null; }
    }

    bool IsTrackedPath(string? path)
    {
        if (_doc == null || string.IsNullOrEmpty(path)) return false;
        var full = SafeFull(path);
        if (full == null) return false;
        foreach (var f in _doc.Files)
            if (!string.IsNullOrEmpty(f.Path) && string.Equals(SafeFull(f.Path), full, StringComparison.OrdinalIgnoreCase))
                return true;
        return false;
    }

    // FileSystemWatcher fires on a background thread; just hop to the UI thread and (re)arm the debounce.
    void OnFsEvent(object sender, System.IO.FileSystemEventArgs e)
    {
        bool relevant = IsTrackedPath(e.FullPath)
                     || (e is System.IO.RenamedEventArgs re && IsTrackedPath(re.OldFullPath));
        if (!relevant) return;
        try { Dispatcher.BeginInvoke(new Action(ScheduleExternalCheck)); } catch { }
    }

    // Buffer overflow (an event storm) or the watched directory going away. Events may have been dropped,
    // so re-check from scratch. We don't restart watchers here — that would re-baseline and could hide a
    // pending change; a plain check (plus the Activated re-check) surfaces anything we missed.
    void OnFsError(object sender, System.IO.ErrorEventArgs e)
    {
        try { Dispatcher.BeginInvoke(new Action(ScheduleExternalCheck)); } catch { }
    }

    void ScheduleExternalCheck()
    {
        if (_extChangeTimer == null)
        {
            _extChangeTimer = new System.Windows.Threading.DispatcherTimer { Interval = TimeSpan.FromMilliseconds(500) };
            _extChangeTimer.Tick += (_, _) => CheckExternalChanges();
        }
        _extChangeTimer.Stop();   // editors often write in several steps; collapse the burst into one check
        _extChangeTimer.Start();
    }

    // Compare disk state against what we last recorded. A newer write-time means an external edit; a
    // tracked file that has vanished means an external delete/move. (A delete+recreate atomic save resolves
    // within the debounce window, so it shows up here as a change, not a deletion.)
    void CheckExternalChanges()
    {
        _extChangeTimer?.Stop();
        if (_doc == null || _extPromptOpen) return;
        var changed = new List<TplFile>();
        var deleted = new List<TplFile>();
        foreach (var f in _doc.Files)
        {
            if (string.IsNullOrEmpty(f.Path)) continue;
            bool tracked = _fileWriteTimes.TryGetValue(f.Path, out var known);
            bool exists;
            try { exists = System.IO.File.Exists(f.Path); } catch { continue; }
            if (!exists)
            {
                if (tracked && _deletedWarned.Add(f.Path)) deleted.Add(f);   // flag each disappearance once
                continue;
            }
            _deletedWarned.Remove(f.Path);   // it's back on disk
            try
            {
                var disk = System.IO.File.GetLastWriteTimeUtc(f.Path);
                if (tracked && disk != known) changed.Add(f);
            }
            catch { }
        }
        if (deleted.Count > 0) HandleDeleted(deleted);
        if (changed.Count > 0) HandleExternalChange(changed);
    }

    void HandleExternalChange(List<TplFile> changed)
    {
        string names = FileNames(changed);

        if (HasUnsavedEdits())
        {
            bool discard;
            _extPromptOpen = true;
            try
            {
                discard = MessageBox.Show(
                    $"{names} was changed by another program, but you have unsaved changes in the designer.\n\n" +
                    "Reload from disk and discard your unsaved changes?",
                    "File changed on disk", MessageBoxButton.YesNo, MessageBoxImage.Warning, MessageBoxResult.No)
                    == MessageBoxResult.Yes;
            }
            finally { _extPromptOpen = false; }

            if (!discard)
            {
                RecordWriteTimes();   // keep the edits; don't nag again until the next external write
                status.Text = $"{names} changed on disk — kept your unsaved edits (Save will overwrite the external change).";
                return;
            }
        }

        // Auto-reload (no unsaved edits) or the user chose to discard them.
        if (TryReload())
            status.Text = $"{names} changed on disk — reloaded.";
        else
        {
            // Couldn't read it yet — most likely still being written or briefly locked. Force a re-check on
            // the next FS event / focus so we retry once it settles, and leave the current model untouched.
            foreach (var f in changed) _fileWriteTimes[f.Path] = DateTime.MinValue;
            status.Text = $"{names} changed on disk — couldn't reload yet (file in use?); will retry.";
        }
    }

    // The file (or a #INCLUDEd one) was deleted or moved away. Don't touch the in-memory model — it's the
    // only surviving copy — just tell the user so a later Save isn't a silent resurrection out of nowhere.
    void HandleDeleted(List<TplFile> gone)
    {
        string names = FileNames(gone);
        _extPromptOpen = true;
        try
        {
            MessageBox.Show(
                $"{names} was deleted or moved outside the designer.\n\n" +
                "Your in-memory copy is kept — use Save to write it back to disk, or close it to discard it.",
                "File removed on disk", MessageBoxButton.OK, MessageBoxImage.Warning);
        }
        finally { _extPromptOpen = false; }
        status.Text = $"{names} was removed on disk — kept your in-memory copy (Save to restore it).";
    }

    // Reload from disk without letting a locked / half-written / vanished file crash the app.
    // ReloadFromDisk parses into _doc as its first action, so a parse failure leaves the model intact.
    bool TryReload()
    {
        try { ReloadPreservingView(() => { ReloadFromDisk(); LoadSource(); }); return true; }
        catch { return false; }
    }

    bool HasUnsavedEdits() =>
        _srcDirty
        || (_doc != null && (_doc.Files.Any(f => f.Dirty)
                             || AllElements().Any(HasPendingEdit)));

    // Run a reload that rewrites srcEditor.Text (which sends AvalonEdit back to line 1) while keeping
    // the source editor looking at roughly the same place — same caret line and same first visible row —
    // so an external-change reload doesn't yank the user to the top of the file. Best-effort: when the
    // external edit added or removed lines above the viewport the row numbers still line up; the content
    // may shift, which matches how editors like VS Code behave on an on-disk reload.
    void ReloadPreservingView(Action reload)
    {
        int caretLine = srcEditor.TextArea.Caret.Line;
        int caretCol  = srcEditor.TextArea.Caret.Column;
        var tv = srcEditor.TextArea.TextView;
        double lh = tv.DefaultLineHeight > 0 ? tv.DefaultLineHeight : srcEditor.FontSize * 1.3;
        int firstVisible = lh > 0 ? (int)(srcEditor.VerticalOffset / lh) : 0;   // 0-based top row

        reload();

        var doc = srcEditor.Document;
        int lines = doc?.LineCount ?? 0;
        if (doc == null || lines <= 0) return;
        try
        {
            int line = Math.Min(Math.Max(caretLine, 1), lines);                  // file may have shrunk below the old line
            var dl = doc.GetLineByNumber(line);
            int col = Math.Min(Math.Max(caretCol, 1), dl.Length + 1);            // and the line itself may now be shorter
            srcEditor.CaretOffset = dl.Offset + (col - 1);                       // set by offset so the position is always valid
        }
        catch { }
        // Defer the scroll until the new document has laid out, otherwise the offset clamps against stale metrics.
        Dispatcher.BeginInvoke(new Action(() =>
        {
            double target = Math.Min(Math.Max(firstVisible, 0), Math.Max(lines - 1, 0)) * lh;
            try { srcEditor.ScrollToVerticalOffset(target); } catch { }
        }), System.Windows.Threading.DispatcherPriority.Loaded);
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

    void AddTab_Click(object s, RoutedEventArgs e) => AddTab();

    // ---------- snippets / pattern library ----------
    void Snippet_Click(object s, RoutedEventArgs e)
    {
        if (s is MenuItem { Tag: string name }) InsertSnippet(name);
    }

    void InsertSnippet(string name)
    {
        var tab = TargetTab();
        if (_doc == null || tab == null)
        {
            MessageBox.Show("Open a template and pick a tab first.", "Snippet",
                MessageBoxButton.OK, MessageBoxImage.Information);
            return;
        }
        var roots = BuildSnippet(name);
        if (roots.Count == 0) return;
        var parent = _sel is { Kind: TplKind.Boxed, Deleted: false } ? _sel : tab;
        PushUndo();
        _addN = (_addN + 1) % 16; int bx = 12 + _addN * 4, by = 12 + _addN * 6;
        foreach (var r in roots) { OffsetTree(r, bx, by); r.Parent = parent; parent.Children.Add(r); }
        foreach (var r in roots) ReassignSymbols(r);     // fresh %symbols so the snippet never duplicates a field
        Render();
        _selection.Clear(); _selection.AddRange(roots); _sel = roots[^1];
        AfterSelectionChanged();
        status.Text = $"Inserted snippet ({roots.Count} top-level control(s)).  Save to write.";
    }

    static void OffsetTree(TplElement e, int dx, int dy)
    {
        e.X += dx; e.Y += dy;
        foreach (var c in e.Children) OffsetTree(c, dx, dy);
    }

    static TplElement SnipPrompt(string title, string pt, int x, int y, int w, int h, string sym = "") => new()
    {
        Kind = TplKind.Prompt, Inserted = true, Dirty = true, Title = title, PromptType = pt, Symbol = sym,
        X = x, Y = y, W = w, H = h, HasX = true, HasY = true, HasW = true, HasH = true
    };

    static List<TplElement> BuildSnippet(string name)
    {
        switch (name)
        {
            case "fieldgroup":
            {
                var box = new TplElement
                {
                    Kind = TplKind.Boxed, Inserted = true, Dirty = true, Title = "Group",
                    X = 0, Y = 0, W = 180, H = 58, HasX = true, HasY = true, HasW = true, HasH = true
                };
                for (int i = 0; i < 3; i++)
                {
                    var p = SnipPrompt($"Field {i + 1}:", "@s30", 8, 12 + i * 14, 150, 10, "%Field");
                    p.Parent = box; box.Children.Add(p);
                }
                return new List<TplElement> { box };
            }
            case "optiongroup":
                return new List<TplElement>
                {
                    SnipPrompt("Choose one:", "OPTION", 0, 0, 160, 10, "%Choice"),
                    SnipPrompt("Option A", "RADIO", 8, 14, 120, 10),
                    SnipPrompt("Option B", "RADIO", 8, 28, 120, 10),
                    SnipPrompt("Option C", "RADIO", 8, 42, 120, 10),
                };
            case "twocol":
                return new List<TplElement>
                {
                    SnipPrompt("Field 1:", "@s30", 0, 0, 140, 10, "%Field"),
                    SnipPrompt("Field 2:", "@s30", 150, 0, 140, 10, "%Field"),
                    SnipPrompt("Field 3:", "@s30", 0, 14, 140, 10, "%Field"),
                    SnipPrompt("Field 4:", "@s30", 150, 14, 140, 10, "%Field"),
                };
            case "checks":
                return new List<TplElement>
                {
                    SnipPrompt("Enabled", "CHECK", 0, 0, 120, 10, "%Flag"),
                    SnipPrompt("Visible", "CHECK", 0, 14, 120, 10, "%Flag"),
                };
            default: return new List<TplElement>();
        }
    }

    // Add a new #TAB to the current part's #SHEET (inserted before #ENDSHEET, after the existing tabs).
    void AddTab()
    {
        if (_doc == null || _component == null)
        {
            MessageBox.Show("Open a template and pick a part first.", "New tab",
                MessageBoxButton.OK, MessageBoxImage.Information);
            return;
        }
        string? name = AskText("New tab", "Tab caption:", "New Tab");
        if (name == null) return;                       // cancelled
        if (name.Trim().Length == 0) name = "New Tab";

        PushUndo();
        var tab = new TplElement { Kind = TplKind.Tab, Inserted = true, Title = name };
        tab.MoveAnchorLine = SheetInsertAnchor();   // insert before #ENDSHEET (after the existing tabs)
        _component.Tabs.Add(tab);

        RefreshTabSelector(LiveTabs().Count - 1);            // Tab_Changed sets _tab + renders
        status.Text = $"Added tab \"{name}\".  Add controls to it, then Save.";
    }

    void RenameTab(TplElement tab)
    {
        if (_doc == null || _component == null) return;
        string? name = AskText("Rename tab", "Tab caption:", tab.Title);
        if (name == null) return;
        PushUndo();
        tab.Title = name;
        if (!tab.Inserted && tab.LineIndex >= 0)      // rewrite the caption in the existing #TAB line
        {
            var f = _doc.Files[_component.FileIndex];
            if (tab.LineIndex < f.Lines.Length)
            {
                var rx = new Regex(@"'(?:[^']|'')*'");
                f.Lines[tab.LineIndex] = rx.Replace(f.Lines[tab.LineIndex], "'" + name.Replace("'", "''") + "'", 1);
                f.Dirty = true;
            }
        }
        RefreshTabSelector();
        Render();
        status.Text = $"Renamed tab to \"{name}\".  Save to write the change.";
    }

    void EditTabWhere(TplElement tab)
    {
        if (_doc == null || _component == null) return;
        string? cond = AskText("Tab visibility condition",
            "WHERE(...) — shown only when true; blank = always shown:", tab.Where);
        if (cond == null) return;
        cond = cond.Trim();
        PushUndo();
        tab.Where = cond;
        if (!tab.Inserted && tab.LineIndex >= 0)          // rewrite the existing #TAB line
        {
            var f = _doc.Files[_component.FileIndex];
            if (tab.LineIndex < f.Lines.Length)
            {
                var line = f.Lines[tab.LineIndex];
                line = System.Text.RegularExpressions.Regex.Replace(line, @",?\s*WHERE\([^)]*\)", "",
                    System.Text.RegularExpressions.RegexOptions.IgnoreCase);     // strip any existing WHERE
                if (cond.Length > 0) line = line.TrimEnd() + $",WHERE({cond})";
                f.Lines[tab.LineIndex] = line;
                f.Dirty = true;
            }
        }
        Render();
        status.Text = cond.Length > 0 ? $"Tab “{tab.Title}” shows when {cond}.  Save to write."
                                      : $"Tab “{tab.Title}” always shows.  Save to write.";
    }

    void DeleteTab(TplElement tab)
    {
        if (_doc == null || _component == null) return;
        if (LiveTabs().Count <= 1)
        {
            MessageBox.Show("A sheet must keep at least one tab.", "Delete tab",
                MessageBoxButton.OK, MessageBoxImage.Information);
            return;
        }
        string warn = "";
        if (!tab.Inserted)
        {
            var refs = ExternalReferences(tab);
            if (refs.Count > 0)
                warn = $"\n\nControls on this tab use {refs.Sum(r => r.Lines.Count)} symbol reference(s) elsewhere in "
                     + "the template; deleting them may break code generation.";
        }
        if (MessageBox.Show($"Delete tab \"{tab.Title}\" and all of its controls?{warn}", "Delete tab",
                MessageBoxButton.YesNo, MessageBoxImage.Warning, MessageBoxResult.No) != MessageBoxResult.Yes) return;

        PushUndo();
        if (tab.Inserted) _component.Tabs.Remove(tab); else tab.Deleted = true;
        _previewTabIndex = 0;
        Select(null);
        RefreshTabSelector(0);
        Render();
        status.Text = $"Deleted tab \"{tab.Title}\".  Save to write the change.";
    }

    // The line a new/last tab should be emitted before: #ENDSHEET, else just after the last tab's #ENDTAB.
    int SheetInsertAnchor()
    {
        if (_component == null) return 0;
        if (_component.SheetEnd >= 0) return _component.SheetEnd;
        var ends = _component.Tabs.Where(t => !t.Inserted && !t.Deleted && t.EndLineIndex >= 0)
                                  .Select(t => t.EndLineIndex);
        return ends.Any() ? ends.Max() + 1 : (CurrentFile()?.Lines.Length ?? 0);
    }

    // Move a tab to a new position among its siblings (drag-reordered in the preview).
    void ReorderTab(TplElement dragged, TplElement? insertBefore)
    {
        if (_component == null || insertBefore == dragged) return;
        PushUndo();
        var tabs = _component.Tabs;
        tabs.Remove(dragged);
        int idx = insertBefore != null ? tabs.IndexOf(insertBefore) : tabs.Count;
        if (idx < 0) idx = tabs.Count;
        tabs.Insert(idx, dragged);
        if (!dragged.Inserted) dragged.Moved = true;
        // anchor before the next stationary sibling tab, else before #ENDSHEET
        dragged.MoveAnchorLine = SheetInsertAnchor();
        for (int i = idx + 1; i < tabs.Count; i++)
        {
            var t = tabs[i];
            if (!t.Inserted && !t.Deleted && t.LineIndex >= 0) { dragged.MoveAnchorLine = t.LineIndex; break; }
        }
        _previewTabIndex = idx;
    }

    // A small modal text prompt (we avoid raw input boxes; this keeps the look consistent).
    string? AskText(string title, string label, string initial)
    {
        var dlg = new Window
        {
            Title = title, Owner = this, Width = 360, SizeToContent = SizeToContent.Height,
            WindowStartupLocation = WindowStartupLocation.CenterOwner, ResizeMode = ResizeMode.NoResize,
            WindowStyle = WindowStyle.ToolWindow, Background = new SolidColorBrush(Color.FromRgb(0xFA, 0xFB, 0xFC))
        };
        var root = new StackPanel { Margin = new Thickness(16) };
        root.Children.Add(new TextBlock { Text = label, Margin = new Thickness(0, 0, 0, 6) });
        var box = new TextBox { Text = initial };
        root.Children.Add(box);
        dlg.Loaded += (_, __) => { box.Focus(); box.SelectAll(); };
        var row = new StackPanel { Orientation = Orientation.Horizontal, HorizontalAlignment = HorizontalAlignment.Right,
                                   Margin = new Thickness(0, 14, 0, 0) };
        var ok = new Button { Content = "OK", IsDefault = true, Padding = new Thickness(16, 3, 16, 3), MinWidth = 74 };
        var cancel = new Button { Content = "Cancel", IsCancel = true, Padding = new Thickness(12, 3, 12, 3),
                                  Margin = new Thickness(8, 0, 0, 0), MinWidth = 74 };
        bool okClicked = false;
        ok.Click += (_, __) => { okClicked = true; dlg.DialogResult = true; };
        row.Children.Add(ok); row.Children.Add(cancel);
        root.Children.Add(row);
        dlg.Content = root;
        return dlg.ShowDialog() == true && okClicked ? box.Text : null;
    }

    TplElement MakeControl(TplKind kind, string title, string promptType, int w, int h)
    {
        var el = new TplElement
        {
            Kind = kind, Inserted = true, Dirty = true,
            Title = title, PromptType = promptType,
            Symbol = kind == TplKind.Prompt ? NewSymbol() : ""
        };
        _addN = (_addN + 1) % 16;
        el.X = 12 + _addN * 4; el.Y = 12 + _addN * 6; el.W = w; el.H = h;
        el.HasX = el.HasY = el.HasW = el.HasH = true;
        return el;
    }

    void AddControl(TplKind kind, string title, string promptType, int w, int h)
    {
        var tab = TargetTab();
        if (_doc == null || tab == null)
        {
            MessageBox.Show("Open a template and select a tab first.", "Add control",
                MessageBoxButton.OK, MessageBoxImage.Information);
            return;
        }
        PushUndo();
        var el = MakeControl(kind, title, promptType, w, h);
        el.Parent = tab; tab.Children.Add(el);
        Render();
        Select(el);
        status.Text = $"Added {kind} \"{title}\".  Drag to position, edit its text in the panel, then Save.";
    }

    // Insert a new control at a chosen place (used by drag-from-the-Add-bar onto the preview).
    void AddControlAt(TplKind kind, string title, string promptType, int w, int h, TplElement newParent, TplElement? insertBefore)
    {
        PushUndo();
        var el = MakeControl(kind, title, promptType, w, h);
        el.Parent = newParent;
        int idx = insertBefore != null ? newParent.Children.IndexOf(insertBefore) : -1;
        if (idx >= 0) newParent.Children.Insert(idx, el); else newParent.Children.Add(el);

        int pos = newParent.Children.IndexOf(el);
        el.MoveAnchorLine = -1;
        for (int i = pos + 1; i < newParent.Children.Count; i++)
        {
            var sib = newParent.Children[i];
            if (!sib.Inserted && !sib.Deleted && sib.LineIndex >= 0) { el.MoveAnchorLine = sib.LineIndex; break; }
        }
        int tabIdx = TabIndexOf(newParent); if (tabIdx >= 0) _previewTabIndex = tabIdx;
        Render(); Select(el);
        status.Text = $"Added {kind} \"{title}\".  Save to write it.";
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
        // Foreign content's real source is in the #GROUP's own file — show it (read-only) from there.
        if (el.Foreign && _doc != null && el.SrcFileIndex >= 0 && el.SrcFileIndex < _doc.Files.Count)
        {
            var gf = _doc.Files[el.SrcFileIndex];
            if (el.LineIndex < 0 || el.LineIndex >= gf.Lines.Length) return "";
            string fs = gf.Lines[el.LineIndex].Trim();
            if (el.EndLineIndex > el.LineIndex)
                fs += $"\n…\n{gf.Lines[Math.Min(el.EndLineIndex, gf.Lines.Length - 1)].Trim()}"
                    + $"   ({el.EndLineIndex - el.LineIndex + 1} lines)";
            return $"from {System.IO.Path.GetFileName(gf.Path)} via #INSERT (read-only):\n{fs}";
        }
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
        if (_doc != null)
            foreach (var f in _doc.Files) s.Files.Add(((string[])f.Lines.Clone(), f.Dirty));
        return s;
    }

    void PushUndo()
    {
        if (_doc == null) return;
        _undo.Add(Capture());
        if (_undo.Count > MaxUndo) _undo.RemoveAt(0);
        _redo.Clear();                 // a fresh edit invalidates the redo stack
        RefreshDocTabs();              // first edit since save marks the tab dirty
    }

    void Undo_Click(object s, RoutedEventArgs e) => Undo();
    void Redo_Click(object s, RoutedEventArgs e) => Redo();

    void Undo()
    {
        if (_undo.Count == 0) { status.Text = "Nothing to undo."; return; }
        _redo.Add(Capture());          // current state becomes redoable
        var snap = _undo[^1];
        _undo.RemoveAt(_undo.Count - 1);
        Restore(snap);
        status.Text = $"Undid last change.  ({_undo.Count} undo, {_redo.Count} redo)";
    }

    void Redo()
    {
        if (_redo.Count == 0) { status.Text = "Nothing to redo."; return; }
        _undo.Add(Capture());          // current state becomes undoable again
        var snap = _redo[^1];
        _redo.RemoveAt(_redo.Count - 1);
        Restore(snap);
        status.Text = $"Redid change.  ({_undo.Count} undo, {_redo.Count} redo)";
    }

    void Restore(Snapshot snap)
    {
        if (_doc == null) return;
        int partIdx = cmbParts.SelectedIndex, tabIdx = cmbTabs.SelectedIndex;   // keep the user where they were
        for (int i = 0; i < _doc.Components.Count && i < snap.Tabs.Count; i++)
        {
            _doc.Components[i].Tabs.Clear();
            _doc.Components[i].Tabs.AddRange(snap.Tabs[i]);
        }
        for (int i = 0; i < _doc.Files.Count && i < snap.Files.Count; i++)
        {
            _doc.Files[i].Lines = (string[])snap.Files[i].Lines.Clone();
            _doc.Files[i].Dirty = snap.Files[i].Dirty;
        }
        _guides.Clear();
        foreach (var (v, d) in snap.Guides) _guides.Add(new Guide { Vertical = v, Dlu = d });

        _sel = null;
        // Rebuild the part/tab selectors from the restored model: an undone tab add/delete changes the
        // tab LIST, not just its contents, so the dropdowns, canvas and panels must all re-sync.
        PopulateParts(partIdx, tabIdx);
    }

    // Drag/resize gestures: capture once at the start, commit only if something actually changed.
    void BeginGesture() { _gestureSnap = Capture(); _gestureChanged = false; }
    void CommitGesture()
    {
        bool changed = _gestureChanged && _gestureSnap != null;
        if (changed)
        {
            _undo.Add(_gestureSnap!);
            if (_undo.Count > MaxUndo) _undo.RemoveAt(0);
            _redo.Clear();             // a fresh edit invalidates the redo stack
        }
        _gestureSnap = null; _gestureChanged = false;
        RefreshLiveSource();          // drag/resize move the chips directly (no Render) — refresh now
        if (changed) RefreshDocTabs();   // a committed move marks the tab dirty
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
        if (_srcOpen) { LoadSource(); SyncSourceToSelection(); }
    }

    // ---------- panel layout persistence ----------
    void Exit_Click(object s, RoutedEventArgs e) => Close();

    // ---------- Help ----------
    void UserManual_Click(object s, RoutedEventArgs e) => OpenDoc("Docs.user-manual.html", "user-manual");
    void ProgRef_Click(object s, RoutedEventArgs e) => OpenDoc("Docs.programmers-reference.html", "programmers-reference");

    // Extract an embedded HTML doc to a temp file and open it in the default browser. Embedding means it
    // works identically from the portable single-file exe and the installed build.
    void OpenDoc(string resource, string baseName)
    {
        try
        {
            string html;
            var asm = System.Reflection.Assembly.GetExecutingAssembly();
            using (var stream = asm.GetManifestResourceStream(resource))
            {
                if (stream == null) { MessageBox.Show("Help document not found.", "Help",
                    MessageBoxButton.OK, MessageBoxImage.Warning); return; }
                using var sr = new System.IO.StreamReader(stream);
                html = sr.ReadToEnd();
            }
            // versioned temp name so an updated build refreshes the cached copy
            string ver = asm.GetName().Version?.ToString() ?? "0";
            string path = System.IO.Path.Combine(System.IO.Path.GetTempPath(), $"ClarionTplDesigner_{baseName}_{ver}.html");
            System.IO.File.WriteAllText(path, html);
            System.Diagnostics.Process.Start(new System.Diagnostics.ProcessStartInfo(path) { UseShellExecute = true });
        }
        catch (Exception ex)
        {
            MessageBox.Show("Couldn't open the help document:\n" + ex.Message, "Help",
                MessageBoxButton.OK, MessageBoxImage.Warning);
        }
    }

    void About_Click(object s, RoutedEventArgs e)
    {
        var ver = System.Reflection.Assembly.GetExecutingAssembly().GetName().Version;
        MessageBox.Show(this,
            $"Clarion Template Designer\nVersion {ver?.ToString(3)}\n\n" +
            "A visual designer for the prompt UI of Clarion templates.\n" +
            "Reddin Assessments.\n\n" +
            "Help ▸ User Manual  (F1)\nHelp ▸ Programmer's Reference",
            "About Clarion Template Designer", MessageBoxButton.OK, MessageBoxImage.Information);
    }

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
                    "outline" => _outlineContent,
                    "problems" => _problemsContent,
                    "symbols" => _symbolsContent,
                    _ => null
                };
                if (e.Content == null) e.Cancel = true;
            };
            using var sr = new System.IO.StringReader(xml);
            ser.Deserialize(sr);

            var prp = FindAnchorable("props"); if (prp != null) anchProps = prp;
            var src = FindAnchorable("source"); if (src != null) WireSource(src);
            EnsureOutline();                          // a layout saved before these panels won't contain them
            EnsureProblems();
            EnsureSymbols();
            _srcOpen = anchSource?.IsVisible ?? false;
            miViewSource.IsChecked = _srcOpen;
            miViewOutline.IsChecked = anchOutline?.IsVisible ?? false;
            miViewProblems.IsChecked = anchProblems?.IsVisible ?? false;
            miViewSymbols.IsChecked = anchSymbols?.IsVisible ?? false;
        }
        catch { /* a bad/old layout file must never break startup */ }
    }

    LayoutAnchorable? FindAnchorable(string id) =>
        dockMgr.Layout.Descendents().OfType<LayoutAnchorable>().FirstOrDefault(a => a.ContentId == id);

    // If a deserialized (older) layout lacks the Outline panel, re-attach it so it isn't lost.
    void EnsureOutline()
    {
        var existing = FindAnchorable("outline");
        if (existing != null) { anchOutline = existing; return; }
        var pane = dockMgr.Layout.Descendents().OfType<LayoutAnchorablePane>().FirstOrDefault();
        if (pane == null || _outlineContent == null) return;
        anchOutline = new LayoutAnchorable { ContentId = "outline", Title = "Outline", Content = _outlineContent };
        pane.Children.Add(anchOutline);
    }

    void EnsureProblems()
    {
        var existing = FindAnchorable("problems");
        if (existing != null) { anchProblems = existing; return; }
        // prefer the pane that hosts Source so Problems tabs alongside it
        var pane = FindAnchorable("source")?.Parent as LayoutAnchorablePane
                   ?? dockMgr.Layout.Descendents().OfType<LayoutAnchorablePane>().FirstOrDefault();
        if (pane == null || _problemsContent == null) return;
        anchProblems = new LayoutAnchorable { ContentId = "problems", Title = "Problems", Content = _problemsContent };
        pane.Children.Add(anchProblems);
    }

    void EnsureSymbols()
    {
        var existing = FindAnchorable("symbols");
        if (existing != null) { anchSymbols = existing; return; }
        var pane = FindAnchorable("outline")?.Parent as LayoutAnchorablePane
                   ?? dockMgr.Layout.Descendents().OfType<LayoutAnchorablePane>().FirstOrDefault();
        if (pane == null || _symbolsContent == null) return;
        anchSymbols = new LayoutAnchorable { ContentId = "symbols", Title = "Symbols", Content = _symbolsContent };
        pane.Children.Add(anchSymbols);
    }

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
            if (d.TryGetValue("smartGuides", out var smg)) miSmartGuides.IsChecked = smg == "1";
            if (d.TryGetValue("trueLayout", out var tl) && tl == "1")
            { _previewTrueLayout = true; miTrueLayout.IsChecked = true; btnTrueLayout.IsChecked = true; }
            if (d.TryGetValue("minimap", out var mm)) miMinimap.IsChecked = mm == "1";
            if (d.TryGetValue("gridSize", out var gs) && int.TryParse(gs, out _)) txtGrid.Text = gs;
            if (d.TryGetValue("previewWidth", out var pw) && int.TryParse(pw, out var pwv))
            { _previewWidth = pwv == 960 ? 960 : 480; cmbPreviewWidth.SelectedIndex = _previewWidth == 960 ? 1 : 0; }
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
                $"smartGuides={(miSmartGuides.IsChecked == true ? 1 : 0)}",
                $"trueLayout={(_previewTrueLayout ? 1 : 0)}",
                $"minimap={(miMinimap.IsChecked == true ? 1 : 0)}",
                $"gridSize={GridStep}",
                $"previewWidth={_previewWidth}",
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
        srcEditor.Background = _srcLive ? new SolidColorBrush(Color.FromRgb(0xF1, 0xF3, 0xF6)) : Brushes.White;
        btnApplySrc.IsEnabled = !_srcLive && _srcDirty;
        LoadSource();
    }

    // Render the file as it WOULD be saved (all pending edits), without touching disk.
    void RefreshLiveSource()
    {
        if (!_srcOpen || !_srcLive || _doc == null || _srcViewFile >= 0) return;   // don't clobber a #GROUP (foreign) view
        int fi = _component?.FileIndex ?? 0;
        _loadingSrc = true;
        try { srcEditor.Text = TplWriter.PreviewFile(_doc, fi); }
        finally { _loadingSrc = false; }
        _srcDirty = false; btnApplySrc.IsEnabled = false;
        var f = CurrentFile();
        srcHeader.Text = (f == null ? "SOURCE" : $"SOURCE — {System.IO.Path.GetFileName(f.Path)}")
                       + "  •  live preview — read-only (uncheck “Live” to edit)";
        RebuildPendingMap();
        RefreshMinimap();
        UpdateSourceHighlights();
    }

    // ---------- source autocomplete (%symbols + #directives) ----------
    CompletionWindow? _completion;
    static readonly string[] Directives =
    {
        "PROMPT", "DISPLAY", "IMAGE", "BUTTON", "ENDBUTTON", "BOXED", "ENDBOXED", "TAB", "ENDTAB",
        "SHEET", "ENDSHEET", "ENABLE", "ENDENABLE", "GROUP", "ENDGROUP", "INSERT", "EQUATE", "DECLARE",
        "SYSTEM", "EXTENSION", "CONTROL", "CODE", "PROCEDURE", "TEMPLATE", "AT", "PROP", "DEFAULT", "REQ",
        "WHERE", "FROM", "DROP", "SPIN", "CHECK", "OPTION", "RADIO", "EXPR", "KEYCODE"
    };

    void Src_TextEntered(object sender, System.Windows.Input.TextCompositionEventArgs e)
    {
        if (e.Text == "%") ShowCompletion(EditorSymbols().Select(x => (x, "%symbol")));
        else if (e.Text == "#") ShowCompletion(Directives.Select(d => (d, "#directive")));
    }

    IEnumerable<string> EditorSymbols()
    {
        var set = new SortedSet<string>(StringComparer.OrdinalIgnoreCase);
        foreach (System.Text.RegularExpressions.Match m in
                 System.Text.RegularExpressions.Regex.Matches(srcEditor.Text, @"%([A-Za-z]\w*)"))
            set.Add(m.Groups[1].Value);
        return set;
    }

    void ShowCompletion(IEnumerable<(string text, string desc)> items)
    {
        var list = items.ToList();
        if (list.Count == 0) return;
        _completion = new CompletionWindow(srcEditor.TextArea);
        foreach (var (t, desc) in list) _completion.CompletionList.CompletionData.Add(new ComplItem(t, desc));
        _completion.Closed += (_, _) => _completion = null;
        _completion.Show();
    }

    sealed class ComplItem : ICompletionData
    {
        readonly string _desc;
        public ComplItem(string text, string desc) { Text = text; _desc = desc; }
        public System.Windows.Media.ImageSource? Image => null;
        public string Text { get; }
        public object Content => Text;
        public object Description => _desc;
        public double Priority => 0;
        public void Complete(TextArea area, ISegment seg, EventArgs e) => area.Document.Replace(seg, Text);
    }

    void LoadSource()
    {
        if (!_srcOpen) return;
        _srcViewFile = -1;                       // loading the part's own source leaves any #GROUP (foreign) view
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
        SetSrcChrome(readOnly: false);           // the part's source is editable again
        _srcDirty = false; btnApplySrc.IsEnabled = false;
        srcHeader.Text = f == null ? "SOURCE" : $"SOURCE — {System.IO.Path.GetFileName(f.Path)}";
        RefreshMinimap();
        UpdateSourceHighlights();
    }

    void SrcEditor_TextChanged(object? s, EventArgs e)
    {
        RefreshMinimap();
        if (_loadingSrc) return;
        bool was = _srcDirty;
        _srcDirty = true; btnApplySrc.IsEnabled = true;
        var f = CurrentFile();
        srcHeader.Text = (f == null ? "SOURCE" : $"SOURCE — {System.IO.Path.GetFileName(f.Path)}") + "  •  edited (Apply to commit)";
        if (!was) RefreshDocTabs();   // first unapplied edit marks the tab dirty
    }

    void RevertSrc_Click(object s, RoutedEventArgs e) => LoadSource();

    void ApplySrc_Click(object s, RoutedEventArgs e)
    {
        var f = CurrentFile();
        if (f == null || !_srcDirty) return;
        if (AllElements().Any(HasPendingEdit) &&
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

    // Bring the selected part into view in the source editor. A part has no chip to scroll to, so
    // selecting one would otherwise leave the editor wherever it happened to be (or at the top after a
    // cross-file reload). The live preview is regenerated text whose line numbers don't track the part's
    // on-disk StartLine, so only reposition in normal (non-live) mode.
    void ScrollSourceToComponent()
    {
        if (!_srcOpen || _srcLive || _component == null || srcEditor.Document == null) return;
        int line = _component.StartLine + 1;   // StartLine is 0-based; editor lines are 1-based
        if (line < 1 || line > srcEditor.Document.LineCount) return;
        var dl = srcEditor.Document.GetLineByNumber(line);
        srcEditor.CaretOffset = dl.Offset;
        srcEditor.Select(dl.Offset, dl.Length);
        srcEditor.ScrollToLine(line);
    }

    void ScrollSourceTo(TplElement? el)
    {
        UpdateSourceHighlights();
        if (!_srcOpen || el == null) return;
        int ln = LineOf(el);
        if (ln < 0) return;
        int line = ln + 1;
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
            {
                int ln = LineOf(el);
                if (ln >= 0) _lineHi.Lines.Add(ln + 1);
            }
        srcEditor.TextArea.TextView.InvalidateLayer(KnownLayer.Selection);
    }

    // The element's line in the text currently shown. Foreign (#INSERT'd) content lives in another file:
    // when the panel is showing that file its real LineIndex applies; otherwise anchor to the #INSERT line.
    int LineOf(TplElement el)
    {
        if (el.Foreign) return _srcViewFile == el.SrcFileIndex ? el.LineIndex : el.AnchorLine;
        return _srcLive && _pendingMap != null && _pendingMap.TryGetValue(el, out var ln) ? ln : el.LineIndex;
    }

    // Point the source panel at whatever defines the current selection. A foreign control's source is in
    // its #GROUP's own file, so the editor follows the selection across files (read-only); native controls
    // (and an empty selection) show the part's own editable source.
    void SyncSourceToSelection()
    {
        if (!_srcOpen) return;
        if (_sel is { Foreign: true } && _doc != null && _sel.SrcFileIndex >= 0 && _sel.SrcFileIndex < _doc.Files.Count)
        {
            ShowForeignSource(_sel);
            return;
        }
        if (_srcViewFile >= 0) { _srcViewFile = -1; LoadSource(); }   // leaving a #GROUP file -> restore the part source
        ScrollSourceTo(_sel);
    }

    // Load a foreign control's defining file read-only and jump to the line that declares it.
    void ShowForeignSource(TplElement el)
    {
        if (_doc == null || el.SrcFileIndex < 0 || el.SrcFileIndex >= _doc.Files.Count) return;
        var f = _doc.Files[el.SrcFileIndex];
        if (_srcViewFile != el.SrcFileIndex)        // already on this file? just re-scroll
        {
            srcEditor.SyntaxHighlighting = ClarionHighlighting();
            _loadingSrc = true;
            try { srcEditor.Text = string.Join(f.Newline, f.Lines); }
            finally { _loadingSrc = false; }
            _srcViewFile = el.SrcFileIndex;
            _srcDirty = false; btnApplySrc.IsEnabled = false;
            SetSrcChrome(readOnly: true);           // this file isn't the template being edited
            srcHeader.Text = $"SOURCE — {System.IO.Path.GetFileName(f.Path)}  •  read-only (declared here, pulled in via #INSERT)";
            RefreshMinimap();
        }
        ScrollSourceTo(el);                          // LineOf -> el.LineIndex while _srcViewFile == its file
    }

    void SetSrcChrome(bool readOnly)
    {
        srcEditor.IsReadOnly = readOnly;
        srcEditor.Background = readOnly ? new SolidColorBrush(Color.FromRgb(0xF1, 0xF3, 0xF6)) : Brushes.White;
    }

    // Map model elements to their line numbers in the live/pending source (which shifts on insert/move/delete).
    void RebuildPendingMap()
    {
        _pendingMap = null;
        if (!_srcLive || _doc == null || _component == null) return;
        try
        {
            var temp = TplParser.ParseText(srcEditor.Text, _doc.Files[_component.FileIndex].Path);
            var tc = temp.Components.FirstOrDefault(c => c.HasSheet && c.Kind == _component.Kind && c.Name == _component.Name)
                     ?? temp.Components.FirstOrDefault(c => c.HasSheet);
            if (tc == null) return;
            var model = new List<TplElement>(); foreach (var t in _component.Tabs) FlattenLive(t, model);
            var tmp = new List<TplElement>(); foreach (var t in tc.Tabs) FlattenAllEls(t, tmp);
            var map = new Dictionary<TplElement, int>();
            for (int i = 0; i < model.Count && i < tmp.Count; i++) map[model[i]] = tmp[i].LineIndex;
            _pendingMap = map;
        }
        catch { /* hand-edited / unparseable -> fall back to parsed line indices */ }
    }

    static void FlattenLive(TplElement e, List<TplElement> o)
    {
        if (e.Deleted) return;                       // deleted controls aren't in the pending text
        if (e.Foreign) return;                       // #INSERT'd content isn't in this file's text, so it has no pending line
        o.Add(e);
        foreach (var c in e.Children) FlattenLive(c, o);
    }
    static void FlattenAllEls(TplElement e, List<TplElement> o)
    {
        o.Add(e);
        foreach (var c in e.Children) FlattenAllEls(c, o);
    }
    static IEnumerable<TplElement> Flat(TplElement e)
    {
        yield return e;
        foreach (var c in e.Children)
            foreach (var x in Flat(c)) yield return x;
    }

    // An element carrying an unsaved edit. Foreign (#INSERT'd) content is read-only, so it never counts as dirty.
    static bool HasPendingEdit(TplElement el) => !el.Foreign && (el.Dirty || el.Inserted || el.Deleted || el.Moved);

    // ---------- part / tab / render ----------
    int _pendingTabIdx;   // tab to select after the next Part_Changed populates cmbTabs

    void Part_Changed(object s, SelectionChangedEventArgs e)
    {
        if (_doc == null || cmbParts.SelectedIndex < 0 || cmbParts.SelectedIndex >= _parts.Count) return;
        _component = _parts[cmbParts.SelectedIndex];
        _previewTabIndex = 0;
        Select(null);
        LoadSource();           // current part may live in a different file
        ScrollSourceToComponent();   // ...and bring that part into view rather than leaving the editor where it was
        cmbTabs.SelectedIndex = -1;   // same value-preservation quirk as the parts combo: force Tab_Changed to fire
        cmbTabs.ItemsSource = LiveTabs().Select(t => t.Title).ToList();
        int want = _pendingTabIdx; _pendingTabIdx = 0;
        var lts = LiveTabs();
        if (lts.Count > 0) ForceSelect(cmbTabs, Math.Min(Math.Max(want, 0), lts.Count - 1));
        else { _tab = null; Render(); }
    }

    void Tab_Changed(object s, SelectionChangedEventArgs e)
    {
        var lts = LiveTabs();
        if (_component == null || cmbTabs.SelectedIndex < 0 || cmbTabs.SelectedIndex >= lts.Count) return;
        _tab = lts[cmbTabs.SelectedIndex];
        Select(null);
        Render();
        ScrollSourceTo(_tab);   // bring the chosen tab's line into view (works in live mode too, via LineOf)
    }

    void Zoom_Changed(object s, RoutedPropertyChangedEventArgs<double> e) => Render();

    void Render()
    {
        if (!_ready) return;
        PopulateOutline();            // keep the structure tree in step with the model
        if (miViewProblems?.IsChecked == true) Validate();        // keep the Problems panel in step (only when open)
        if (miViewSymbols?.IsChecked == true) PopulateSymbols();  // keep the Symbols browser in step (only when open)
        RefreshLiveSource();          // keep the live source in step with the model
        canvas.Children.Clear();
        _chips.Clear();
        _promptLabels.Clear();
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
        DrawVisibilityGuides();

        UpdateRulers();
        RefreshSelectionVisual();
    }

    void VisGuides_Changed(object s, RoutedEventArgs e) => Render();

    // Overlay that shows "what is viewable and what isn't": the auto-fit window edge, plus controls that fall
    // off the window, spill outside their group box, or (for prompts) whose label is hidden under its entry.
    void DrawVisibilityGuides()
    {
        if (miVisGuides?.IsChecked != true || _tab == null) return;
        var items = Positionable(_tab).ToList();

        // The Clarion prompt window auto-sizes (SHEET ADJUST) to fit its content - draw that edge.
        double cw = 0, chgt = 0;
        foreach (var e in items) { cw = Math.Max(cw, e.LX + e.LW); chgt = Math.Max(chgt, e.LY + e.LH); }
        if (cw > 0) AddOverlay(0, 0, cw, chgt, Color.FromRgb(0x7E, 0xA6, 0xC9), 1, "Clarion window (auto-fit to content)", false);

        var red   = Color.FromRgb(0xD9, 0x46, 0x3C);   // clipped / hidden -> will not be fully visible
        var amber = Color.FromRgb(0xC8, 0x86, 0x1A);   // spills outside its group box

        foreach (var e in items)
        {
            if (e.Kind == TplKind.Boxed) continue;

            if (e.LX < 0 || e.LY < 0)
                AddOverlay(e.LX, e.LY, e.LW, e.LH, red, 2, "Off the window edge — clipped in Clarion", true);

            if (e.Parent is { Kind: TplKind.Boxed } box &&
                (e.LX < box.LX - 0.5 || e.LY < box.LY - 0.5 ||
                 e.LX + e.LW > box.LX + box.LW + 0.5 || e.LY + e.LH > box.LY + box.LH + 0.5))
                AddOverlay(e.LX, e.LY, e.LW, e.LH, amber, 1.5, "Extends outside its group box", true);

            if (Layout.HasSideLabel(e))   // a prompt label too wide for the gap -> clipped by its entry in Clarion
            {
                double labDlu = MeasureTextPx(e, e.FontSize > 0 ? e.FontSize : _ideFontSize) / ClarionHDlu;
                if (e.PLX + labDlu + 1 > e.LX)   // reaches/overlaps the entry's left edge (+1 DLU clearance)
                    AddOverlay(e.PLX, e.PLY, labDlu, Math.Max(8, e.PLH), red, 2,
                               "Label is wider than the gap to its entry — it will be clipped in Clarion", true);
            }
        }
    }

    // Width (px) of a control's text at the given em size, in the control's font. The overlap guide calls it
    // with emSize = the Clarion point size (NOT the zoomed render size), so the derived DLU width is zoom-independent.
    double MeasureTextPx(TplElement el, double emSize)
    {
        string text = el.Title.Length > 0 ? el.Title : el.Symbol;
        var tf = new Typeface(UiFontFamily(el), el.Italic ? FontStyles.Italic : FontStyles.Normal,
                              el.Bold ? FontWeights.Bold : FontWeights.Normal, FontStretches.Normal);
        var ft = new FormattedText(text, System.Globalization.CultureInfo.CurrentCulture, FlowDirection.LeftToRight,
                                   tf, emSize, Brushes.Black, VisualTreeHelper.GetDpi(this).PixelsPerDip);
        return ft.WidthIncludingTrailingWhitespace;
    }

    void AddOverlay(double x, double y, double w, double h, Color c, double thick, string tip, bool dashed) =>
        AddOverlayPx(new Rect(x * Scale, y * Scale, Math.Max(6, w * Scale), Math.Max(6, h * Scale)), c, thick, tip, dashed);

    void AddOverlayPx(Rect r, Color c, double thick, string tip, bool dashed)
    {
        var b = new Border
        {
            BorderBrush = new SolidColorBrush(c), BorderThickness = new Thickness(thick),
            Width = r.Width, Height = r.Height, IsHitTestVisible = false, ToolTip = tip,
            Background = dashed ? new SolidColorBrush(Color.FromArgb(0x16, c.R, c.G, c.B)) : Brushes.Transparent
        };
        Canvas.SetLeft(b, r.X); Canvas.SetTop(b, r.Y);
        Panel.SetZIndex(b, 100);
        canvas.Children.Add(b);
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

    // ---------- copy / cut / paste / duplicate ----------
    readonly List<TplElement> _clip = new();   // cloned subtrees; paste re-clones so it can be pasted repeatedly

    void Copy_Click(object s, RoutedEventArgs e) => Copy();
    void Cut_Click(object s, RoutedEventArgs e) => Cut();
    void Paste_Click(object s, RoutedEventArgs e) => Paste();
    void Duplicate_Click(object s, RoutedEventArgs e) => Duplicate();

    void Copy()
    {
        var items = _selection.Where(x => !x.Deleted && (x.IsPositionable || x.Kind == TplKind.Button)).ToList();
        if (items.Count == 0) { status.Text = "Select control(s) to copy."; return; }
        _clip.Clear();
        foreach (var x in items) _clip.Add(x.Clone());
        status.Text = $"Copied {items.Count} control(s).  Paste with Ctrl+V.";
    }

    void Cut()
    {
        Copy();
        if (_clip.Count > 0) DeleteSelection();
    }

    // The tab currently being shown: in flow preview that's the previewed tab, otherwise the canvas tab.
    TplElement? TargetTab()
    {
        if (_preview && _component != null)
        {
            var lts = LiveTabs();
            if (_previewTabIndex >= 0 && _previewTabIndex < lts.Count) return lts[_previewTabIndex];
        }
        return _tab;
    }

    void Paste()
    {
        if (_clip.Count == 0) { status.Text = "Nothing to paste."; return; }
        var tab = TargetTab();
        if (tab == null) { status.Text = "Pick a tab to paste into."; return; }
        if (tab.Foreign) { status.Text = "Can't paste into read-only #INSERT content."; return; }
        // paste into the selected group box, else the current/visible tab (never a read-only foreign box)
        var parent = _sel is { Kind: TplKind.Boxed, Deleted: false, Foreign: false } ? _sel : tab;
        PushUndo();
        var added = new List<TplElement>();
        foreach (var src in _clip)
        {
            var c = src.Clone();
            PrepInserted(c);
            c.X += 4; c.Y += 4;                    // nudge so the copy isn't exactly on top
            c.Parent = parent; parent.Children.Add(c);
            added.Add(c);
        }
        foreach (var c in added) ReassignSymbols(c);   // fresh %symbols so paste never duplicates a field
        Render();
        _selection.Clear(); _selection.AddRange(added); _sel = added[^1];
        AfterSelectionChanged();
        status.Text = $"Pasted {added.Count} control(s) into {(parent.Kind == TplKind.Tab ? "the tab" : "the group")}.  Save to write.";
    }

    void Duplicate()
    {
        if (_selection.Count == 0) { status.Text = "Select control(s) to duplicate."; return; }
        Copy();
        Paste();
    }

    static void PrepInserted(TplElement c)
    {
        c.Inserted = true; c.Dirty = true; c.Moved = false; c.Deleted = false;
        c.Foreign = false;          // a pasted/duplicated copy is a real editable control, not read-only
        c.LineIndex = -1; c.EndLineIndex = -1; c.MoveAnchorLine = -1;
        foreach (var ch in c.Children) PrepInserted(ch);
    }

    void ReassignSymbols(TplElement c)
    {
        if (!string.IsNullOrEmpty(c.Symbol)) c.Symbol = NewSymbol();   // NewSymbol scans the live tree, so each is unique
        foreach (var ch in c.Children) ReassignSymbols(ch);
    }

    void DeleteSelection()
    {
        var items = (_selection.Count > 0 ? _selection.ToList()
                  : (_sel != null ? new List<TplElement> { _sel } : new List<TplElement>()))
                  .Where(x => !x.Foreign).ToList();   // read-only #INSERT content can't be deleted
        if (items.Count == 0) { status.Text = "Nothing to delete (inlined #INSERT content is read-only)."; return; }
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
        if (el.Foreign) { status.Text = "Inlined #INSERT content is read-only — edit it in its source template."; return; }
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

    // ---------- symbol: show, find usages, rename everywhere ----------

    void PopulateSymbol(TplElement? el)
    {
        bool has = el != null && !string.IsNullOrEmpty(el.Symbol) && _selection.Count <= 1;
        symBox.Visibility = has ? Visibility.Visible : Visibility.Collapsed;
        if (!has) { _uses.Clear(); return; }

        _suppressProp = true;
        txtSymbol.Text = el!.Symbol;
        // an unsaved control's symbol lives only in the model until Save, so there's nothing to rename across files yet
        btnRename.Content = el.Inserted ? "Set name" : "Rename";
        _suppressProp = false;

        int ownFile = _component?.FileIndex ?? 0;
        var hits = FindUsages(el.Symbol);
        _suppressUses = true;
        _uses.Clear();
        var rows = new List<string>();
        foreach (var (fi, li, text) in hits)
        {
            _uses.Add((fi, li));
            string tag = (fi == ownFile && li == el.LineIndex) ? "● " : "   ";
            string fn = _doc!.Files.Count > 1 ? System.IO.Path.GetFileName(_doc.Files[fi].Path) + " " : "";
            rows.Add($"{tag}{fn}{li + 1,4}: {text}");
        }
        lstUses.ItemsSource = rows;
        lstUses.SelectedIndex = -1;
        usesHdr.Text = el.Inserted
            ? "Not yet written — usages appear after you Save."
            : $"USES ({hits.Count})   ● = this control";
        usesHdr.Visibility = Visibility.Visible;
        lstUses.Visibility = rows.Count > 0 ? Visibility.Visible : Visibility.Collapsed;
        _suppressUses = false;
    }

    // Every line, across every file, that references the given %symbol (word-boundary so %Foo != %FooBar).
    List<(int File, int Line, string Text)> FindUsages(string sym)
    {
        var res = new List<(int, int, string)>();
        if (_doc == null || string.IsNullOrEmpty(sym)) return res;
        var rx = new Regex(Regex.Escape(sym) + @"(?![A-Za-z0-9_])");
        for (int fi = 0; fi < _doc.Files.Count; fi++)
        {
            var lines = _doc.Files[fi].Lines;
            for (int i = 0; i < lines.Length; i++)
                if (rx.IsMatch(lines[i])) res.Add((fi, i, lines[i].Trim()));
        }
        return res;
    }

    void Uses_Navigate(object s, SelectionChangedEventArgs e)
    {
        if (_suppressUses) return;
        int i = lstUses.SelectedIndex;
        if (i < 0 || i >= _uses.Count) return;
        GotoUsage(_uses[i].File, _uses[i].Line);
    }

    // Jump the source editor to a raw file line, switching the visible part if the usage is in another file.
    void GotoUsage(int fi, int li)
    {
        if (_doc == null || fi < 0 || fi >= _doc.Files.Count) return;
        if (_component == null || _component.FileIndex != fi)
        {
            int p = _parts.FindIndex(c => c.FileIndex == fi);
            if (p >= 0 && p != cmbParts.SelectedIndex) cmbParts.SelectedIndex = p;   // Part_Changed reloads source
        }
        if (!_srcOpen) SetSource(true);
        int line = li + 1;
        if (line < 1 || line > srcEditor.Document.LineCount) return;
        var dl = srcEditor.Document.GetLineByNumber(line);
        srcEditor.CaretOffset = dl.Offset;
        srcEditor.Select(dl.Offset, dl.Length);
        srcEditor.ScrollToLine(line);
        status.Text = $"{System.IO.Path.GetFileName(_doc.Files[fi].Path)}  line {line}";
    }

    void Symbol_KeyDown(object s, KeyEventArgs e)
    {
        if (e.Key == Key.Enter) { RenameSymbol_Click(s, e); e.Handled = true; }
    }

    void RenameSymbol_Click(object s, RoutedEventArgs e)
    {
        if (_sel == null || string.IsNullOrEmpty(_sel.Symbol)) return;
        string old = _sel.Symbol;
        string proposed = txtSymbol.Text.Trim();
        if (!proposed.StartsWith("%")) proposed = "%" + proposed;
        if (!Regex.IsMatch(proposed, @"^%[A-Za-z]\w*$"))
        {
            MessageBox.Show("A symbol must be % followed by a letter, then letters, digits or underscores — e.g. %CustomerName.",
                "Invalid symbol", MessageBoxButton.OK, MessageBoxImage.Warning);
            txtSymbol.Text = old;
            return;
        }
        if (string.Equals(proposed, old, StringComparison.OrdinalIgnoreCase))
        {
            if (proposed != old) ApplyRename(old, proposed);   // case-only change still worth applying
            return;
        }

        // refuse to merge into a symbol that already exists elsewhere
        var clash = new Regex(Regex.Escape(proposed) + @"(?![A-Za-z0-9_])");
        bool exists = (_doc?.Files ?? Enumerable.Empty<TplFile>()).Any(f => f.Lines.Any(l => clash.IsMatch(l)))
                   || AllElements().Any(x => x != _sel && string.Equals(x.Symbol, proposed, StringComparison.OrdinalIgnoreCase));
        if (exists)
        {
            MessageBox.Show($"{proposed} is already used by another field. Renaming to it would merge the two and is blocked.",
                "Symbol already in use", MessageBoxButton.OK, MessageBoxImage.Warning);
            txtSymbol.Text = old;
            return;
        }

        ApplyRename(old, proposed);
    }

    void ApplyRename(string oldSym, string newSym)
    {
        PushUndo();
        int hits = 0, files = 0;
        var rx = new Regex(Regex.Escape(oldSym) + @"(?![A-Za-z0-9_])");
        foreach (var f in _doc!.Files)
        {
            bool touched = false;
            for (int i = 0; i < f.Lines.Length; i++)
            {
                if (!rx.IsMatch(f.Lines[i])) continue;
                f.Lines[i] = rx.Replace(f.Lines[i], newSym.Replace("$", "$$"));
                hits++; touched = true;
            }
            if (touched) { f.Dirty = true; files++; }
        }
        // keep the in-memory model joined to the renamed source
        foreach (var x in AllElements())
            if (string.Equals(x.Symbol, oldSym, StringComparison.OrdinalIgnoreCase)) x.Symbol = newSym;

        Render();
        Select(_sel);
        status.Text = _sel != null && _sel.Inserted
            ? $"Named this control {newSym}.  Save to write it."
            : $"Renamed {oldSym} → {newSym} in {hits} place(s) across {files} file(s).  Save to write the change.";
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

            TextBlock Label()
            {
                var t = new TextBlock
                {
                    Text = el.Title.Length > 0 ? el.Title : el.Symbol,
                    Foreground = fg, FontSize = DluFontPx(el), FontFamily = UiFontFamily(el),
                    FontWeight = el.Bold ? FontWeights.Bold : FontWeights.Normal,
                    VerticalAlignment = VerticalAlignment.Center, Margin = new Thickness(3, 0, 4, 0),
                    TextTrimming = TextTrimming.CharacterEllipsis
                };
                ApplyTextStyle(t, el);
                return t;
            }

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
                // The AT rect is the ENTRY only; the label is drawn separately at PROMPTAT (AddPromptLabel),
                // exactly as Clarion lays it out. So no label goes inside this chip.
                var dock = new DockPanel { LastChildFill = true };
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
            var t = new TextBlock
            {
                Text = txt,
                Foreground = el.Kind == TplKind.Image && el.FontColor is null
                             ? new SolidColorBrush(Color.FromRgb(150, 110, 60)) : fg,
                FontWeight = el.Bold ? FontWeights.Bold : FontWeights.Normal,
                FontSize = DluFontPx(el), FontFamily = UiFontFamily(el),
                Margin = new Thickness(2, 0, 2, 0),
                TextTrimming = TextTrimming.CharacterEllipsis,
                VerticalAlignment = VerticalAlignment.Center
            };
            ApplyTextStyle(t, el);
            border.Child = t;
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
        // Build the menu when it opens so it reflects the live selection (multi-select doesn't re-render).
        border.ContextMenuOpening += (_, _) =>
        {
            // select the clicked control, but keep an existing multi-selection so Group/Align act on it
            if (_selection.Count <= 1 && !_selection.Contains(el)) Select(el);
            border.ContextMenu = BuildChipMenu(el);
        };
        border.MouseLeftButtonDown += Chip_Down;
        canvas.Children.Add(border);
        _chips[el] = border;
        if (Layout.HasSideLabel(el)) AddPromptLabel(el);
    }

    // Draw a side-label prompt's LABEL as its own visual at the PROMPTAT rect (PLX/PLY). Non-interactive: the
    // entry chip is the drag handle, and the label tracks it (PlaceChip/MoveElement), so the canvas shows the
    // label exactly where Clarion will place it.
    void AddPromptLabel(TplElement el)
    {
        var fg = el.FontColor is uint pc ? FromColorRef(pc) : Brushes.Black;
        var t = new TextBlock
        {
            Text = el.Title.Length > 0 ? el.Title : el.Symbol,
            Foreground = fg, FontSize = DluFontPx(el), FontFamily = UiFontFamily(el),
            FontWeight = el.Bold ? FontWeights.Bold : FontWeights.Normal,
            VerticalAlignment = VerticalAlignment.Center, Margin = new Thickness(0, 0, 2, 0)
        };
        ApplyTextStyle(t, el);
        var b = new Border { Background = Brushes.Transparent, Child = t, Tag = el,
                             Cursor = Cursors.SizeAll, ToolTip = "Prompt label (PROMPTAT) — drag to position it independently of the entry",
                             Height = Math.Max(6, el.PLH * Scale) };
        Canvas.SetLeft(b, el.PLX * Scale);
        Canvas.SetTop(b, el.PLY * Scale);
        Panel.SetZIndex(b, el.HasZ ? el.Z : 6);     // just above the entry chip so the label is grabbable
        b.MouseLeftButtonDown += Label_Down;
        canvas.Children.Add(b);
        _promptLabels[el] = b;
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
        var src = _previewLines ?? CurrentFile()?.Lines;
        if (src == null || el.LineIndex < 0 || el.LineIndex >= src.Length) return null;
        var m = Regex.Match(src[el.LineIndex], @"default\(\s*(\d+)\s*\)", RegexOptions.IgnoreCase);
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
        var dirs = new List<string>();
        void Add(string? d)
        {
            if (string.IsNullOrWhiteSpace(d)) return;
            if (!dirs.Any(x => string.Equals(x, d, StringComparison.OrdinalIgnoreCase))) dirs.Add(d);
        }

        // 1. The opened template's own folder.
        if (_doc != null) Add(System.IO.Path.GetDirectoryName(_doc.Path) ?? ".");

        // 2. The Clarion install that OWNS the opened template — found by walking up its path.
        //    This auto-selects the right version (e.g. Clarion11.1-13810 vs clarion12) per file,
        //    so icons resolve from the same install the template lives in.
        var docRoot = _doc != null ? ClarionRootOf(_doc.Path) : null;
        if (docRoot != null)
        {
            Add(System.IO.Path.Combine(docRoot, "accessory", "template", "win"));
            Add(System.IO.Path.Combine(docRoot, "images"));
        }

        // 3. Default root (CLARION_ROOT env var → drive auto-detect → C:\clarion12) as a backstop
        //    for templates edited outside any install tree (e.g. this repo's templates\ folder).
        var root = ClarionRoot();
        Add(System.IO.Path.Combine(root, "accessory", "template", "win"));
        Add(System.IO.Path.Combine(root, "images"));

        return dirs;
    }

    // Walk up from a file to the Clarion install root that owns it: the first ancestor folder
    // that has BOTH a bin\ and a template\win\ subtree (the accessory\ and template\win\ folders
    // alone are NOT roots). Returns null when the file isn't inside a Clarion install.
    static string? ClarionRootOf(string? path)
    {
        try
        {
            var dir = System.IO.Path.GetDirectoryName(System.IO.Path.GetFullPath(path!));
            while (!string.IsNullOrEmpty(dir))
            {
                if (System.IO.Directory.Exists(System.IO.Path.Combine(dir, "bin")) &&
                    System.IO.Directory.Exists(System.IO.Path.Combine(dir, "template", "win")))
                    return dir.TrimEnd('\\');
                dir = System.IO.Path.GetDirectoryName(dir);
            }
        }
        catch { /* malformed path */ }
        return null;
    }

    // Resolve the DEFAULT Clarion install root once (used only as a backstop — see ImageSearchDirs):
    // an explicit CLARION_ROOT environment variable wins; otherwise auto-detect a "clarion*" folder
    // (with a template\win tree) on any ready fixed drive; otherwise fall back to C:\clarion12.
    // Set CLARION_ROOT to pin which install resolves icons for templates edited outside any install.
    static string? _clarionRoot;
    static string ClarionRoot()
    {
        if (_clarionRoot != null) return _clarionRoot;

        static bool HasTemplates(string root) =>
            System.IO.Directory.Exists(System.IO.Path.Combine(root, "template", "win"));

        // 1. Explicit override.
        var env = Environment.GetEnvironmentVariable("CLARION_ROOT");
        if (!string.IsNullOrWhiteSpace(env) && System.IO.Directory.Exists(env))
            return _clarionRoot = env.TrimEnd('\\');

        // 2. Auto-detect a clarion* install on any ready fixed drive (case-insensitive on Windows).
        try
        {
            foreach (var drv in System.IO.DriveInfo.GetDrives())
            {
                if (drv.DriveType != System.IO.DriveType.Fixed || !drv.IsReady) continue;
                try
                {
                    foreach (var dir in System.IO.Directory.EnumerateDirectories(drv.RootDirectory.FullName, "clarion*"))
                        if (HasTemplates(dir)) return _clarionRoot = dir.TrimEnd('\\');
                }
                catch { /* access denied on this drive root */ }
            }
        }
        catch { /* DriveInfo unavailable */ }

        // 3. Historical default.
        return _clarionRoot = @"C:\clarion12";
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
        cm.Items.Add(BuildArrangeMenu(el));
        if (el.Kind is TplKind.Prompt or TplKind.Display or TplKind.Boxed)
        {
            cm.Items.Add(new Separator());
            cm.Items.Add(ZItem("Colour…", () => { if (!_selection.Contains(el)) Select(el); ChangeColor(); }));
        }
        cm.Items.Add(new Separator());
        cm.Items.Add(ZItem("Duplicate", () => { PickKeep(el); Duplicate(); }));
        cm.Items.Add(ZItem("Copy", () => { PickKeep(el); Copy(); }));
        cm.Items.Add(ZItem("Delete", () => { if (_selection.Count > 1 && _selection.Contains(el)) DeleteSelection(); else DeleteControl(el); }));
        return cm;
    }

    // Select the clicked control unless it's already part of a multi-selection (which we keep).
    void PickKeep(TplElement el) { if (_selection.Count <= 1 && !_selection.Contains(el)) Select(el); }

    // The full "Arrange" submenu (z-order, align/size/distribute, group) — shared by the canvas and
    // flow-preview right-click menus. Right-clicking a control that isn't selected selects it first.
    MenuItem BuildArrangeMenu(TplElement el)
    {
        // select the clicked control, but never collapse an existing multi-selection
        void Pick() { if (_selection.Count <= 1 && !_selection.Contains(el)) Select(el); }
        var root = new MenuItem { Header = "Arrange" };
        root.Items.Add(ZItem("Bring to Front", () => { Pick(); ZFront(el); }));
        root.Items.Add(ZItem("Bring Forward",  () => { Pick(); ZForward(el); }));
        root.Items.Add(ZItem("Send Backward",  () => { Pick(); ZBackward(el); }));
        root.Items.Add(ZItem("Send to Back",   () => { Pick(); ZBack(el); }));
        root.Items.Add(new Separator());
        var align = BuildAlignMenu();
        align.IsEnabled = _selection.Count >= 2;     // align/distribute need a reference control
        root.Items.Add(align);
        root.Items.Add(new Separator());
        root.Items.Add(ZItem("Move to a clear row above", () => { Pick(); MoveClearRow(false); }));
        root.Items.Add(ZItem("Move to a clear row below", () => { Pick(); MoveClearRow(true); }));
        root.Items.Add(new Separator());
        // grouping a single control in a box is valid; right-click already ensures it's selected
        root.Items.Add(ZItem(_selection.Count >= 2 ? "Group into box" : "Group into box (this control)",
                             () => { Pick(); GroupSelection(); }));
        if (el.Kind == TplKind.Boxed) root.Items.Add(ZItem("Ungroup box", () => { Pick(); UngroupSelection(); }));
        return root;
    }

    // The Align / Same-size / Distribute submenu used by the right-click menu.
    MenuItem BuildAlignMenu()
    {
        var root = new MenuItem { Header = $"Align / size  ({_selection.Count} selected)" };
        root.Items.Add(ZItem("Align Left",           () => Align("left")));
        root.Items.Add(ZItem("Align Centre (horiz.)", () => Align("hcenter")));
        root.Items.Add(ZItem("Align Right",          () => Align("right")));
        root.Items.Add(new Separator());
        root.Items.Add(ZItem("Align Top",            () => Align("top")));
        root.Items.Add(ZItem("Align Middle (vert.)", () => Align("vcenter")));
        root.Items.Add(ZItem("Align Bottom",         () => Align("bottom")));
        root.Items.Add(new Separator());
        root.Items.Add(ZItem("Same Width",  () => SameSize("w")));
        root.Items.Add(ZItem("Same Height", () => SameSize("h")));
        root.Items.Add(ZItem("Same Both",   () => SameSize("both")));
        root.Items.Add(new Separator());
        root.Items.Add(ZItem("Pack into a row",    () => Pack(true)));
        root.Items.Add(ZItem("Pack into a column", () => Pack(false)));
        if (_selection.Count >= 3)
        {
            root.Items.Add(new Separator());
            root.Items.Add(ZItem("Distribute Horizontally", () => Distribute("h")));
            root.Items.Add(ZItem("Distribute Vertically",   () => Distribute("v")));
        }
        return root;
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

    // ---------- align / distribute / same-size ----------
    List<TplElement> AlignTargets() => _selection.Where(e => e.IsPositionable && !e.Deleted).ToList();

    void Align_Click(object s, RoutedEventArgs e)
    {
        if (s is MenuItem { Tag: string mode }) Align(mode);
    }

    void Align(string mode)
    {
        var items = AlignTargets();
        if (items.Count < 2) { status.Text = "Select two or more controls to align (Ctrl/Shift-click)."; return; }
        EnsureLayout();
        PushUndo();
        double minX = items.Min(e2 => e2.LX), maxR = items.Max(e2 => e2.LX + e2.LW);
        double minY = items.Min(e2 => e2.LY), maxB = items.Max(e2 => e2.LY + e2.LH);
        double cx = (minX + maxR) / 2, cy = (minY + maxB) / 2;
        foreach (var el in items)
            switch (mode)
            {
                case "left":    MoveElement(el, minX, el.LY); break;
                case "right":   MoveElement(el, maxR - el.LW, el.LY); break;
                case "hcenter": MoveElement(el, cx - el.LW / 2, el.LY); break;
                case "top":     MoveElement(el, el.LX, minY); break;
                case "bottom":  MoveElement(el, el.LX, maxB - el.LH); break;
                case "vcenter": MoveElement(el, el.LX, cy - el.LH / 2); break;
            }
        AfterBulkLayout($"Aligned {items.Count} controls.");
    }

    void SameSize_Click(object s, RoutedEventArgs e)
    {
        if (s is MenuItem { Tag: string which }) SameSize(which);
    }

    void SameSize(string which)
    {
        var items = AlignTargets();
        if (items.Count < 2) { status.Text = "Select two or more controls to size together."; return; }
        EnsureLayout();
        PushUndo();
        double w = items.Max(e2 => e2.LW), h = items.Max(e2 => e2.LH);
        foreach (var el in items)
            ResizeElement(el, el.LX, el.LY, which == "h" ? el.LW : w, which == "w" ? el.LH : h);
        AfterBulkLayout($"Sized {items.Count} controls.");
    }

    void Distribute_Click(object s, RoutedEventArgs e)
    {
        if (s is MenuItem { Tag: string dir }) Distribute(dir);
    }

    void Distribute(string dir)
    {
        var items = AlignTargets();
        if (items.Count < 3) { status.Text = "Select three or more controls to distribute."; return; }
        EnsureLayout();
        PushUndo();
        bool horiz = dir == "h";
        items = (horiz ? items.OrderBy(e2 => e2.LX) : items.OrderBy(e2 => e2.LY)).ToList();
        double start = horiz ? items[0].LX : items[0].LY;
        var last = items[^1];
        double end = horiz ? last.LX + last.LW : last.LY + last.LH;
        double sum = items.Sum(e2 => horiz ? e2.LW : e2.LH);
        double gap = (end - start - sum) / (items.Count - 1);
        double p = start;
        foreach (var el in items)
        {
            if (horiz) MoveElement(el, p, el.LY); else MoveElement(el, el.LX, p);
            p += (horiz ? el.LW : el.LH) + gap;
        }
        AfterBulkLayout($"Distributed {items.Count} controls {(horiz ? "horizontally" : "vertically")}.");
    }

    void AfterBulkLayout(string msg)
    {
        Render();
        RefreshSelectionVisual();
        RefreshLiveSource();
        status.Text = msg + "  Save to write the new AT() values.";
    }

    // Lay the selection out flush against each other — a row (left→right) or a column (top→down).
    void PackRow_Click(object s, RoutedEventArgs e) => Pack(true);
    void PackCol_Click(object s, RoutedEventArgs e) => Pack(false);
    void NewRow_Click(object s, RoutedEventArgs e) => MoveClearRow(down: true);
    void NewRowUp_Click(object s, RoutedEventArgs e) => MoveClearRow(down: false);

    // Move the selection straight up/down so it no longer overlaps any other control (carrying box contents).
    // Use case: a #BOXED that overlaps the title row -> one click puts it on a clear row below (or above).
    // The flow preview doesn't run the canvas layout, so refresh LX/LY from the model before a layout op.
    void EnsureLayout() { if (_tab != null) Layout.Run(_tab); }

    void MoveClearRow(bool down)
    {
        var items = AlignTargets();
        if (items.Count == 0 || _tab == null) { status.Text = "Select a control (or box) to move to a clear row."; return; }
        EnsureLayout();
        var sel = new HashSet<TplElement>(items);
        bool InSel(TplElement e) { for (var p = e; p != null; p = p.Parent) if (sel.Contains(p)) return true; return false; }

        double top = items.Min(e => e.LY), bottom = items.Max(e => e.LY + e.LH);
        double left = items.Min(e => e.LX), right = items.Max(e => e.LX + e.LW);
        double clearBottom = top, clearTop = bottom; bool found = false;
        foreach (var e in Positionable(_tab))
        {
            if (InSel(e)) continue;
            bool hOver = e.LX < right && e.LX + e.LW > left;
            bool vOver = e.LY < bottom && e.LY + e.LH > top;
            if (!hOver || !vOver) continue;
            clearBottom = Math.Max(clearBottom, e.LY + e.LH);
            clearTop = Math.Min(clearTop, e.LY);
            found = true;
        }
        if (!found) { status.Text = "Nothing overlaps it — already on a clear row."; return; }

        // drop just below the lowest overlapper, or rise just above the highest one
        double dY = down ? (clearBottom + 4) - top : (clearTop - 4) - bottom;
        if (!down && top + dY < 0) dY = -top;     // don't push off the top of the window
        if (Math.Abs(dY) < 0.5) { status.Text = "Already on a clear row."; return; }

        PushUndo();
        foreach (var el in items)
            if (!AncestorSelected(el)) MoveElement(el, el.LX, Math.Max(0, el.LY + dY));   // boxes carry their contents
        AfterBulkLayout($"Moved the selection to a clear row {(down ? "below" : "above")} ({(dY >= 0 ? "+" : "")}{(int)Math.Round(dY)}).");
    }

    void Pack(bool row)
    {
        // Keep selection order: the FIRST-selected control anchors the row/column; the rest follow it.
        var items = AlignTargets();
        if (items.Count < 2) { status.Text = "Select two or more controls to pack together (the first one selected leads)."; return; }
        EnsureLayout();
        PushUndo();
        const double gap = 4;     // small breathing space between controls (DLU)
        var first = items[0];
        if (row)
        {
            double y0 = first.LY, x = first.LX;
            foreach (var el in items) { MoveElement(el, x, y0); x += el.LW + gap; }
        }
        else
        {
            double x0 = first.LX, y = first.LY;
            foreach (var el in items) { MoveElement(el, x0, y); y += el.LH + gap; }
        }
        AfterBulkLayout($"Packed {items.Count} controls into a {(row ? "row" : "column")} after “{first.Display}”."
                      + (_preview && !_previewTrueLayout ? "  Turn on “True layout” to see them side by side." : ""));
    }

    // ---------- group / ungroup ----------
    void Group_Click(object s, RoutedEventArgs e) => GroupSelection();
    void Ungroup_Click(object s, RoutedEventArgs e) => UngroupSelection();

    void GroupSelection()
    {
        var items = _selection.Where(x => !x.Deleted && !x.Foreign && (x.IsPositionable || x.Kind == TplKind.Button)).ToList();
        if (items.Count == 0) { status.Text = "Select editable control(s) to group into a box."; return; }
        var parent = items[0].Parent;
        if (parent == null || items.Any(x => x.Parent != parent))
        {
            status.Text = "To group, select controls that live in the same tab or box.";
            return;
        }
        PushUndo();

        double minX = items.Min(i => i.LX), minY = items.Min(i => i.LY);
        double maxX = items.Max(i => i.LX + i.LW), maxY = items.Max(i => i.LY + i.LH);
        const int pad = 6;
        var box = new TplElement
        {
            Kind = TplKind.Boxed, Inserted = true, Dirty = true, Title = "Group",
            X = Math.Max(0, (int)Math.Round(minX) - pad), Y = Math.Max(0, (int)Math.Round(minY) - pad),
            W = (int)Math.Round(maxX - minX) + 2 * pad, H = (int)Math.Round(maxY - minY) + 2 * pad,
            HasX = true, HasY = true, HasW = true, HasH = true
        };
        // emit the box where the first existing member sits (its members relocate inside it)
        box.MoveAnchorLine = items.Where(i => !i.Inserted && i.LineIndex >= 0)
                                  .Select(i => i.LineIndex).DefaultIfEmpty(-1).Min();

        int idx = parent.Children.IndexOf(items[0]);
        parent.Children.Insert(Math.Max(0, idx), box);
        box.Parent = parent;
        foreach (var it in items)
        {
            parent.Children.Remove(it);
            it.Parent = box; box.Children.Add(it);
            if (!it.Inserted) it.Moved = true;     // existing members: drop original line, re-emit inside the box
        }
        Render();
        Select(box);
        status.Text = $"Grouped {items.Count} control(s) into a box.  Save to write.";
    }

    void UngroupSelection()
    {
        var box = _sel;
        if (box is not { Kind: TplKind.Boxed } || box.Deleted) { status.Text = "Select a group box to ungroup."; return; }
        if (box.Foreign) { status.Text = "Inlined #INSERT content is read-only — edit it in its source template."; return; }
        var parent = box.Parent;
        if (parent == null) return;
        PushUndo();

        int idx = parent.Children.IndexOf(box);
        var kids = box.Children.Where(c => !c.Deleted).ToList();
        foreach (var c in kids)
        {
            box.Children.Remove(c);
            c.Parent = parent;
            parent.Children.Insert(idx++, c);
            if (!c.Inserted) { c.Moved = true; c.MoveAnchorLine = box.LineIndex >= 0 ? box.LineIndex : -1; }
        }
        if (box.Inserted) parent.Children.Remove(box); else box.Deleted = true;
        Render();
        Select(null);
        _selection.Clear(); _selection.AddRange(kids);
        if (kids.Count > 0) { _sel = kids[^1]; AfterSelectionChanged(); }
        status.Text = $"Ungrouped {kids.Count} control(s).  Save to write.";
    }

    // ---------- outline tree + find ----------
    void Outline_Toggle(object s, RoutedEventArgs e)
    {
        if (anchOutline == null) return;
        if (miViewOutline.IsChecked) { anchOutline.Show(); anchOutline.IsActive = true; }
        else anchOutline.Hide();
    }

    void PopulateOutline()
    {
        if (treeOutline == null) return;
        _buildingOutline = true;
        treeOutline.Items.Clear();
        string f = (txtFind?.Text ?? "").Trim();
        foreach (var tab in LiveTabs()) AddOutlineNode(treeOutline.Items, tab, f);
        _buildingOutline = false;
        HighlightOutline(_sel);
    }

    bool AddOutlineNode(ItemCollection into, TplElement el, string filter)
    {
        if (el.Deleted) return false;
        bool self = OutlineMatches(el, filter);
        var item = new TreeViewItem { Header = OutlineLabel(el), Tag = el };
        bool anyChild = false;
        foreach (var c in el.Children) anyChild |= AddOutlineNode(item.Items, c, filter);
        if (filter.Length > 0 && !self && !anyChild) return false;
        item.IsExpanded = filter.Length > 0 || el.IsContainer;
        into.Add(item);
        return true;
    }

    static bool OutlineMatches(TplElement el, string f) => f.Length == 0
        || el.Title.Contains(f, StringComparison.OrdinalIgnoreCase)
        || (el.Symbol?.Contains(f, StringComparison.OrdinalIgnoreCase) ?? false)
        || el.Kind.ToString().Contains(f, StringComparison.OrdinalIgnoreCase);

    static string OutlineLabel(TplElement el)
    {
        string icon = el.Kind switch
        {
            TplKind.Tab => "▤", TplKind.Boxed => "▭", TplKind.Button => "▢",
            TplKind.Enable => "⌥", TplKind.Image => "🖼", TplKind.Prompt => "✎",
            TplKind.Display => "T", _ => "•"
        };
        string body = el.Title.Length > 0 ? $"'{el.Title}'" : el.Kind.ToString();
        string sym = string.IsNullOrEmpty(el.Symbol) ? "" : $"   {el.Symbol}";
        return $"{icon}  {body}{sym}";
    }

    void Outline_Select(object s, RoutedPropertyChangedEventArgs<object> e)
    {
        if (_buildingOutline) return;
        if (e.NewValue is TreeViewItem { Tag: TplElement el }) SelectFromOutline(el);
    }

    void SelectFromOutline(TplElement el)
    {
        if (_component == null) return;
        var tab = TabOf(el);
        int ti = tab != null ? LiveTabs().IndexOf(tab) : -1;
        if (ti >= 0 && ti != cmbTabs.SelectedIndex) cmbTabs.SelectedIndex = ti;   // Tab_Changed -> Render
        Select(el);
    }

    static TplElement? TabOf(TplElement el)
    {
        var c = el; while (c != null && c.Kind != TplKind.Tab) c = c.Parent; return c;
    }

    // Reflect the current selection in the tree without re-triggering selection logic.
    void HighlightOutline(TplElement? el)
    {
        if (el == null || treeOutline == null) return;
        _buildingOutline = true;
        var tvi = FindTreeItem(treeOutline.Items, el);
        if (tvi != null) { tvi.IsSelected = true; tvi.BringIntoView(); }
        _buildingOutline = false;
    }

    static TreeViewItem? FindTreeItem(ItemCollection items, TplElement el)
    {
        foreach (var it in items.OfType<TreeViewItem>())
        {
            if (ReferenceEquals(it.Tag, el)) return it;
            var sub = FindTreeItem(it.Items, el);
            if (sub != null) { it.IsExpanded = true; return sub; }
        }
        return null;
    }

    void OutlineFind_Changed(object s, TextChangedEventArgs e) => PopulateOutline();

    void OutlineFind_KeyDown(object s, KeyEventArgs e)
    {
        if (e.Key != Key.Enter || _component == null) return;
        string f = txtFind.Text.Trim();
        if (f.Length == 0) return;
        TplElement? first = null, firstLeaf = null;
        foreach (var tab in LiveTabs())
        {
            foreach (var el in Flat(tab))
                if (!el.Deleted && OutlineMatches(el, f))
                {
                    first ??= el;
                    if (!el.IsContainer) { firstLeaf = el; break; }
                }
            if (firstLeaf != null) break;
        }
        var pick = firstLeaf ?? first;
        if (pick != null) { SelectFromOutline(pick); e.Handled = true; }
    }

    // ---------- validation / lint ----------
    sealed class Issue { public bool Warn; public string Text = ""; public TplElement? El; public int File = -1, Line = -1; }
    readonly List<Issue> _problems = new();

    void Problems_Toggle(object s, RoutedEventArgs e)
    {
        if (anchProblems == null) return;
        if (miViewProblems.IsChecked) { anchProblems.Show(); anchProblems.IsActive = true; Validate(); }   // refresh on open
        else anchProblems.Hide();
    }

    void Validate_Click(object s, RoutedEventArgs e)
    {
        anchProblems?.Show(); if (anchProblems != null) anchProblems.IsActive = true;
        miViewProblems.IsChecked = anchProblems?.IsVisible ?? false;
        Validate();
    }

    static string IssueLabel(TplElement e) => e.Title.Length > 0 ? $"{e.Kind} '{e.Title}'" : e.Kind.ToString();

    void Validate()
    {
        _problems.Clear();
        if (_doc == null || _component == null)
        {
            lstProblems.ItemsSource = null;
            if (probSummary != null) probSummary.Text = "Open a template part to check.";
            return;
        }
        var all = LiveTabs().SelectMany(Flat).Where(x => !x.Deleted).ToList();

        // duplicate %symbols within the part
        foreach (var g in all.Where(x => !string.IsNullOrEmpty(x.Symbol))
                             .GroupBy(x => x.Symbol, StringComparer.OrdinalIgnoreCase).Where(g => g.Count() > 1))
            _problems.Add(new Issue { Warn = true, El = g.First(),
                Text = $"Duplicate symbol {g.Key} — used by {g.Count()} controls" });

        // positions: negative, off-canvas, risky AT on auto-built prompts
        foreach (var x in all.Where(x => x.IsPositionable && x.HasX && x.HasY))
        {
            if (x.X < 0 || x.Y < 0)
                _problems.Add(new Issue { Warn = true, El = x, Text = $"{IssueLabel(x)} has a negative position AT({x.X},{x.Y})" });
            else if (x.HasW && x.W > 0 && x.X + x.W > _previewWidth)
                _problems.Add(new Issue { Warn = false, El = x,
                    Text = $"{IssueLabel(x)} extends past the {_previewWidth}-DLU window width" });
        }
        foreach (var x in all.Where(x => x.Kind == TplKind.Prompt && x.HasX && x.HasY && ClassifyPrompt(x.PromptType).Special))
            _problems.Add(new Issue { Warn = false, El = x,
                Text = $"{IssueLabel(x)} is auto-built by Clarion but has an explicit AT — it may move/hide the generated part" });

        // declared symbols never referenced anywhere else
        foreach (var x in all.Where(x => x.Kind == TplKind.Prompt && !string.IsNullOrEmpty(x.Symbol)))
        {
            int others = FindUsages(x.Symbol).Count(u => !(u.File == _component.FileIndex && u.Line == x.LineIndex));
            if (others == 0)
                _problems.Add(new Issue { Warn = false, El = x, Text = $"Symbol {x.Symbol} is never referenced elsewhere" });
        }

        // overlapping leaf controls that share a parent
        foreach (var grp in all.Where(x => x.Kind is TplKind.Prompt or TplKind.Display or TplKind.Image
                                           && x.HasX && x.HasY && x.HasW && x.HasH)
                               .GroupBy(x => x.Parent))
        {
            var sibs = grp.ToList();
            for (int i = 0; i < sibs.Count; i++)
                for (int j = i + 1; j < sibs.Count; j++)
                    if (OverlapArea(sibs[i], sibs[j]) is double a && a > 0)
                    {
                        double min = Math.Min(sibs[i].W * sibs[i].H, sibs[j].W * sibs[j].H);
                        if (min > 0 && a >= 0.5 * min)
                            _problems.Add(new Issue { Warn = false, El = sibs[i],
                                Text = $"{IssueLabel(sibs[i])} overlaps {IssueLabel(sibs[j])}" });
                    }
        }

        // structural balance per file (catches hand-edits)
        for (int fi = 0; fi < _doc.Files.Count; fi++)
            foreach (var (open, close) in CountPairs(_doc.Files[fi].Lines))
                _problems.Add(new Issue { Warn = true, File = fi, Line = 0,
                    Text = $"{System.IO.Path.GetFileName(_doc.Files[fi].Path)}: {open.n} {open.d} vs {close.n} {close.d} — unbalanced" });

        var rows = _problems.Select(p => $"{(p.Warn ? "⚠" : "·")}  {p.Text}").ToList();
        lstProblems.ItemsSource = rows;
        int w = _problems.Count(p => p.Warn), n = _problems.Count - w;
        probSummary.Text = _problems.Count == 0 ? "No problems found ✓" : $"{w} warning(s), {n} note(s)";
    }

    static double OverlapArea(TplElement a, TplElement b)
    {
        double ix = Math.Max(0, Math.Min(a.X + a.W, b.X + b.W) - Math.Max(a.X, b.X));
        double iy = Math.Max(0, Math.Min(a.Y + a.H, b.Y + b.H) - Math.Max(a.Y, b.Y));
        return ix * iy;
    }

    // Directive open/close pairs that don't balance in a file.
    static IEnumerable<((string d, int n) open, (string d, int n) close)> CountPairs(string[] lines)
    {
        (string o, string c)[] pairs =
        {
            ("#SHEET", "#ENDSHEET"), ("#TAB", "#ENDTAB"), ("#BOXED", "#ENDBOXED"),
            ("#BUTTON", "#ENDBUTTON"), ("#ENABLE", "#ENDENABLE")
        };
        foreach (var (o, c) in pairs)
        {
            int no = 0, nc = 0;
            foreach (var l in lines)
            {
                var t = l.TrimStart();
                if (t.StartsWith(c, StringComparison.OrdinalIgnoreCase)) nc++;
                else if (t.StartsWith(o, StringComparison.OrdinalIgnoreCase)
                         && (t.Length == o.Length || !char.IsLetter(t[o.Length]))) no++;
            }
            if (no != nc) yield return ((o, no), (c, nc));
        }
    }

    void Problem_Navigate(object s, SelectionChangedEventArgs e)
    {
        int i = lstProblems.SelectedIndex;
        if (i < 0 || i >= _problems.Count) return;
        var p = _problems[i];
        if (!_srcOpen) SetSource(true);               // make sure the source panel is visible to show the line
        if (p.El != null) SelectFromOutline(p.El);    // selects the control + scrolls/highlights its source line
        else if (p.File >= 0) GotoUsage(p.File, Math.Max(0, p.Line));
    }

    // ---------- symbol browser ----------
    public sealed class SymRow
    {
        public string Sym { get; set; } = "";
        public int Count { get; set; }
        public string Part { get; set; } = "";
        public TplElement? El;
        public int CompIndex;
    }
    List<SymRow> _symRows = new();

    void Symbols_Toggle(object s, RoutedEventArgs e)
    {
        if (anchSymbols == null) return;
        if (miViewSymbols.IsChecked) { anchSymbols.Show(); anchSymbols.IsActive = true; PopulateSymbols(); }
        else anchSymbols.Hide();
    }

    void Symbols_Refresh(object s, RoutedEventArgs e) => PopulateSymbols();

    void PopulateSymbols()
    {
        if (lstSymbols == null) return;
        _symRows = new List<SymRow>();
        if (_doc == null) { lstSymbols.ItemsSource = null; if (symSummary != null) symSummary.Text = ""; return; }

        // total occurrences of each %symbol across all files
        var counts = new Dictionary<string, int>(StringComparer.OrdinalIgnoreCase);
        foreach (var f in _doc.Files)
            foreach (var l in f.Lines)
                foreach (System.Text.RegularExpressions.Match m in
                         System.Text.RegularExpressions.Regex.Matches(l, @"%[A-Za-z]\w*"))
                    counts[m.Value] = counts.GetValueOrDefault(m.Value) + 1;

        // one row per symbol declared by a control (navigable)
        var seen = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
        for (int ci = 0; ci < _doc.Components.Count; ci++)
            foreach (var t in _doc.Components[ci].Tabs)
                foreach (var el in Flat(t))
                    if (!el.Deleted && !string.IsNullOrEmpty(el.Symbol) && seen.Add(el.Symbol))
                        _symRows.Add(new SymRow
                        {
                            Sym = el.Symbol, Count = counts.GetValueOrDefault(el.Symbol),
                            Part = _doc.Components[ci].Name, El = el, CompIndex = ci
                        });

        _symRows = _symRows.OrderBy(r => r.Sym, StringComparer.OrdinalIgnoreCase).ToList();
        lstSymbols.ItemsSource = _symRows;
        symSummary.Text = $"{_symRows.Count} symbol(s)";
    }

    void Symbol_Navigate(object s, SelectionChangedEventArgs e)
    {
        if (lstSymbols.SelectedItem is not SymRow r || r.El == null || _doc == null) return;
        if (r.CompIndex >= 0 && r.CompIndex < _doc.Components.Count)
        {
            int pi = _parts.IndexOf(_doc.Components[r.CompIndex]);
            if (pi >= 0 && pi != cmbParts.SelectedIndex) cmbParts.SelectedIndex = pi;   // switch part if needed
        }
        if (!_srcOpen) SetSource(true);
        SelectFromOutline(r.El);
    }

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

        if (el.Foreign)   // selectable to inspect, but read-only: no drag/move
        {
            status.Text = $"{el.Display} comes from a #GROUP via #INSERT — read-only here. Edit it in its source template.";
            e.Handled = true; return;
        }

        BeginGesture();
        _drag = Drag.Element; _dragEl = el; _dragMoved = false; _dragLabel = false;
        _dragStart = e.GetPosition(canvas);
        _elStartX = el.LX; _elStartY = el.LY;
        _dragStartPos.Clear();
        foreach (var se in _selection) _dragStartPos[se] = (se.LX, se.LY);
        canvas.CaptureMouse();
        canvas.Focus();                 // take keyboard focus so arrow keys nudge this control
        e.Handled = true;
    }

    // Mouse-down on a prompt's LABEL visual: drag just the label (PROMPTAT), leaving the entry put.
    void Label_Down(object s, MouseButtonEventArgs e)
    {
        var el = (TplElement)((Border)s).Tag;
        if ((Keyboard.Modifiers & ModifierKeys.Control) != 0) { ToggleSelect(el); e.Handled = true; return; }
        if (!_selection.Contains(el)) Select(el);
        BeginGesture();
        _drag = Drag.Element; _dragEl = el; _dragMoved = false; _dragLabel = true;
        _dragStart = e.GetPosition(canvas);
        _elStartX = el.PLX; _elStartY = el.PLY;     // reuse the element-drag start to track the label rect
        canvas.CaptureMouse();
        canvas.Focus();
        e.Handled = true;
    }

    // Move just a prompt's label (its PROMPTAT) to a new tab/box position.
    void MoveLabel(TplElement el, double lx, double ly)
    {
        _gestureChanged = true;
        lx = Math.Max(0, lx); ly = Math.Max(0, ly);
        el.PLX = lx; el.PLY = ly;
        var (ox, oy) = FrameOrigin(el);
        el.PX = (int)Math.Round(lx - ox);
        el.PY = (int)Math.Round(ly - oy);
        el.HasPromptAt = el.HasPX = el.HasPY = el.Dirty = true;
        if (_promptLabels.TryGetValue(el, out var lb)) { Canvas.SetLeft(lb, lx * Scale); Canvas.SetTop(lb, ly * Scale); }
        status.Text = $"{el.Display}  label →  PROMPTAT({el.PX},{el.PY})";
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
        SyncSourceToSelection();       // follow the selection to its defining file (foreign content lives elsewhere)
        HighlightOutline(_sel);
    }

    void RefreshSelectionVisual()
    {
        foreach (var kv in _chips) Highlight(kv.Value, _selection.Contains(kv.Key));
        ShowHandles(_selection.Count == 1 ? _sel : null);   // resize handles only for a single selection
    }

    void PopulateProps(TplElement? el)
    {
        propGrid.IsEnabled = el is { Foreign: false };   // inlined #INSERT content is read-only
        propTitle.Text = _selection.Count > 1 ? $"{_selection.Count} controls selected"
                                              : el?.Display ?? "(none)";
        propKind.Text = el == null ? ""
                      : $"{el.Kind}   line {el.LineIndex + 1}" + (el.Foreign ? "   • read-only (from #INSERT)" : "");

        var refs = el == null ? new List<(string Symbol, List<int> Lines)>() : ExternalReferences(el);
        if (refs.Count > 0)
        {
            int total = refs.Sum(r => r.Lines.Count);
            propRefs.Text = $"⚠ {string.Join(", ", refs.Select(r => r.Symbol))} referenced in "
                          + $"{total} other place(s). Deleting this control may break generation.";
            propRefsBox.Visibility = Visibility.Visible;
        }
        else propRefsBox.Visibility = Visibility.Collapsed;

        PopulateSymbol(el);

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
        bool isImg = el is { Kind: TplKind.Image };
        imgRow.Visibility = isImg ? Visibility.Visible : Visibility.Collapsed;
        btnBrowseImg.IsEnabled = isImg && el!.Inserted;  // browsing changes the file name (only added images persist)

        bool isPrompt = el is { Kind: TplKind.Prompt };
        promptBox.Visibility = isPrompt ? Visibility.Visible : Visibility.Collapsed;
        if (isPrompt)
        {
            cmbPromptType.Text = el!.PromptType;
            chkReq.IsChecked = el.Req;
            txtDefault.Text = el.DefaultExpr;
            bool editable = el.Inserted;                  // existing prompts: changing the type rewrites their line
            cmbPromptType.IsEnabled = chkReq.IsEnabled = txtDefault.IsEnabled = editable;
            promptNote.Visibility = editable ? Visibility.Collapsed : Visibility.Visible;
            promptNote.Text = editable ? "" : "Type/attributes are read-only for existing controls (edit them in the source).";
        }

        bool styleable = el is { Kind: TplKind.Prompt or TplKind.Display or TplKind.Boxed };
        styleHdr.Visibility = styleGrid.Visibility = styleable ? Visibility.Visible : Visibility.Collapsed;
        if (styleable)
        {
            chkBold.IsChecked = el!.Bold;
            chkItalic.IsChecked = el.Italic;
            chkUnderline.IsChecked = el.Underline;
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

    // ---------- prompt type / attributes (added controls) ----------
    void PromptType_Changed(object s, RoutedEventArgs e)
    {
        if (_suppressProp || _sel is not { Inserted: true, Kind: TplKind.Prompt }) return;
        string t = cmbPromptType.Text.Trim();
        if (t.Length == 0 || t == _sel.PromptType) return;
        if (!_editGuard) { PushUndo(); _editGuard = true; }
        _sel.PromptType = t;
        _sel.Dirty = true;
        Render();
    }

    void PromptAttr_Changed(object s, RoutedEventArgs e)
    {
        if (_suppressProp || _sel is not { Inserted: true, Kind: TplKind.Prompt }) return;
        bool req = chkReq.IsChecked == true; string def = txtDefault.Text.Trim();
        if (req == _sel.Req && def == _sel.DefaultExpr) return;
        if (!_editGuard) { PushUndo(); _editGuard = true; }
        _sel.Req = req; _sel.DefaultExpr = def;
        _sel.Dirty = true;
        Render();
    }

    void PromptDefault_KeyDown(object s, KeyEventArgs e)
    {
        if (e.Key == Key.Enter) { PromptAttr_Changed(s, e); e.Handled = true; }
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
        if (_sel == null || _selection.All(x => x.Foreign)) return;   // read-only #INSERT content can't be restyled
        BeginStyleEdit();
        foreach (var el in _selection) if (!el.Foreign) { set(el); el.FontDirty = true; }
        Render();                                  // chips reflect the new font/size/colour
        propSource.Text = SourceOf(_sel);          // per-control source preview (primary)
        srcHdr.Visibility = propSource.Visibility = Visibility.Visible;
    }

    void Bold_Changed(object s, RoutedEventArgs e)
    {
        if (_suppressProp || _sel == null) return;
        bool nb = chkBold.IsChecked == true;
        ApplyStyle(el => { el.Bold = nb; el.FontStyle = (nb ? 700 : 400) | (el.FontStyle & 0x7000); });   // keep italic/underline/strikeout
    }

    void Italic_Changed(object s, RoutedEventArgs e)    { if (!_suppressProp) SetStyleFlag(0x1000, chkItalic.IsChecked == true); }
    void Underline_Changed(object s, RoutedEventArgs e) { if (!_suppressProp) SetStyleFlag(0x2000, chkUnderline.IsChecked == true); }

    // Set/clear a Clarion FONT style flag bit (italic 0x1000 / underline 0x2000 / strikeout 0x4000) on the
    // selection, keeping a valid weight (400 if none was set).
    void SetStyleFlag(int bit, bool on)
    {
        if (_sel == null) return;
        ApplyStyle(el =>
        {
            int weight = el.FontStyle & 0xFFF; if (weight == 0) weight = 400;
            int flags = el.FontStyle & 0x7000;
            flags = on ? (flags | bit) : (flags & ~bit);
            el.FontStyle = weight | flags;
        });
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

    // ---------- style command bar / menu (act on all selected) ----------
    void StyleColor_Click(object s, RoutedEventArgs e) => ChangeColor();

    void StyleBold_Click(object s, RoutedEventArgs e)
    {
        if (_sel == null) return;
        bool nb = !_sel.Bold;
        ApplyStyle(el => { el.Bold = nb; el.FontStyle = (nb ? 700 : 400) | (el.FontStyle & 0x7000); });   // keep italic/underline/strikeout
        PopulateProps(_sel);
    }

    void StyleItalic_Click(object s, RoutedEventArgs e)    { if (_sel != null) { SetStyleFlag(0x1000, !_sel.Italic); PopulateProps(_sel); } }
    void StyleUnderline_Click(object s, RoutedEventArgs e) { if (_sel != null) { SetStyleFlag(0x2000, !_sel.Underline); PopulateProps(_sel); } }

    // One-shot font + style + colour picker (right-click menu / toolbar / menu) — applies to all selected.
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

        if (_drag == Drag.Element && _dragLabel && _dragEl != null)   // dragging just the label (PROMPTAT)
        {
            double nx = SnapX(_elStartX + (p.X - _dragStart.X) / Scale);
            double ny = SnapY(_elStartY + (p.Y - _dragStart.Y) / Scale);
            MoveLabel(_dragEl, nx, ny);
        }
        else if (_drag == Drag.Element && _dragEl != null)
        {
            double nx = SnapX(_elStartX + (p.X - _dragStart.X) / Scale);
            double ny = SnapY(_elStartY + (p.Y - _dragStart.Y) / Scale);
            ClearSmartGuides();
            if (_selection.Count <= 1)
            {
                if (miSmartGuides.IsChecked == true) (nx, ny) = SmartSnap(_dragEl, nx, ny);
                MoveElement(_dragEl, nx, ny);
            }
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
        else if (_drag == Drag.Element && !_dragLabel && _dragEl != null && !_dragEl.IsContainer && _selection.Count <= 1)
            TryReparent(_dragEl);            // dropping a single control may move it in/out of a group box
        bool wasElementGesture = _drag is Drag.Element or Drag.Resize;
        ClearSmartGuides();
        canvas.ReleaseMouseCapture();
        _drag = Drag.None; _dragEl = null; _dragGuide = null; _dragLabel = false;
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
        if (Layout.HasSideLabel(el) && el.HasPromptAt)   // rebase the label too (PROMPTAT is frame-relative)
        {
            el.PX = (int)Math.Round(el.PLX - ox);
            el.PY = (int)Math.Round(el.PLY - oy);
        }
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
        if (el.Foreign) return;        // inlined #INSERT content is read-only
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
        if (Layout.HasSideLabel(el))                   // keep the label glued to the entry, write its PROMPTAT
        {
            el.PLX += dX; el.PLY += dY;
            el.PX = (int)Math.Round(el.PLX - ox);
            el.PY = (int)Math.Round(el.PLY - oy);
            el.HasPromptAt = el.HasPX = el.HasPY = true;
        }
        PlaceChip(el);

        if (el.IsContainer)                            // a group box carries its contents
            foreach (var d in Descendants(el))
            {
                d.LX += dX; d.LY += dY;                // their frame-relative AT is unchanged
                d.PLX += dX; d.PLY += dY;              // label tracks too (its box-relative PROMPTAT is unchanged)
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
        if (_promptLabels.TryGetValue(el, out var lb))
        {
            Canvas.SetLeft(lb, el.PLX * Scale); Canvas.SetTop(lb, el.PLY * Scale);
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
        if (el == null || el.Foreign || !_chips.ContainsKey(el)) return;   // no resize handles on read-only content
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
        if (el.Foreign) return;        // inlined #INSERT content is read-only
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

    // ---------- smart guides: snap a dragged control to other controls' edges/centres ----------
    static readonly Brush SmartBrush = new SolidColorBrush(Color.FromRgb(0xE0, 0x3C, 0x8A));   // pink alignment line
    readonly List<System.Windows.Shapes.Line> _smartLines = new();

    void ClearSmartGuides()
    {
        foreach (var l in _smartLines) canvas.Children.Remove(l);
        _smartLines.Clear();
    }

    void AddSmartLine(bool vertical, double dlu)
    {
        var ln = new System.Windows.Shapes.Line
        {
            Stroke = SmartBrush, StrokeThickness = 1, IsHitTestVisible = false,
            StrokeDashArray = new DoubleCollection { 3, 2 }
        };
        if (vertical) { ln.X1 = ln.X2 = dlu * Scale; ln.Y1 = 0; ln.Y2 = canvas.Height; }
        else { ln.Y1 = ln.Y2 = dlu * Scale; ln.X1 = 0; ln.X2 = canvas.Width; }
        Panel.SetZIndex(ln, 2_500_000);
        canvas.Children.Add(ln);
        _smartLines.Add(ln);
    }

    (double nx, double ny) SmartSnap(TplElement drag, double nx, double ny)
    {
        if (_tab == null) return (nx, ny);
        var peers = Positionable(_tab).Where(e => e != drag && !e.Deleted && e.LW > 0 && e.LH > 0
                                                  && !IsAncestor(drag, e) && !IsAncestor(e, drag)).ToList();
        if (peers.Count == 0) return (nx, ny);
        double thr = SnapPx / Scale, w = drag.LW, h = drag.LH;

        var xt = peers.SelectMany(e => new[] { e.LX, e.LX + e.LW / 2, e.LX + e.LW });
        var yt = peers.SelectMany(e => new[] { e.LY, e.LY + e.LH / 2, e.LY + e.LH });
        var (sx, snX, lineX) = Snap1D(nx, w, xt, thr);
        var (sy, snY, lineY) = Snap1D(ny, h, yt, thr);
        if (snX) { nx = sx; AddSmartLine(true, lineX); }
        if (snY) { ny = sy; AddSmartLine(false, lineY); }

        ShowSpacing(drag, peers, nx, ny);
        return (nx, ny);
    }

    // Align one axis: try the dragged edge's left/centre/right (or top/mid/bottom) against each target.
    static (double pos, bool snapped, double line) Snap1D(double start, double size, IEnumerable<double> targets, double thr)
    {
        double[] edges = { start, start + size / 2, start + size };
        double best = double.MaxValue, pos = start, line = 0; bool snapped = false;
        foreach (var t in targets)
            for (int k = 0; k < 3; k++)
            {
                double d = Math.Abs(edges[k] - t);
                if (d <= thr && d < best) { best = d; pos = start + (t - edges[k]); line = t; snapped = true; }
            }
        return (pos, snapped, line);
    }

    void ShowSpacing(TplElement d, List<TplElement> peers, double nx, double ny)
    {
        double r = nx + d.LW, b = ny + d.LH;
        double? gx = null, gy = null;
        foreach (var e in peers)
        {
            if (ny < e.LY + e.LH && b > e.LY)            // vertically overlapping -> horizontal gap
            {
                double g = e.LX >= r ? e.LX - r : (nx >= e.LX + e.LW ? nx - (e.LX + e.LW) : -1);
                if (g >= 0 && (gx == null || g < gx)) gx = g;
            }
            if (nx < e.LX + e.LW && r > e.LX)            // horizontally overlapping -> vertical gap
            {
                double g = e.LY >= b ? e.LY - b : (ny >= e.LY + e.LH ? ny - (e.LY + e.LH) : -1);
                if (g >= 0 && (gy == null || g < gy)) gy = g;
            }
        }
        status.Text = $"AT({(int)Math.Round(nx)},{(int)Math.Round(ny)},{d.W},{d.H})"
                    + (gx != null ? $"   ↔ {Math.Round(gx.Value)}" : "")
                    + (gy != null ? $"   ↕ {Math.Round(gy.Value)}" : "");
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
        if (e.Key == Key.F1) { UserManual_Click(s, e); e.Handled = true; return; }
        if (srcEditor.IsKeyboardFocusWithin) return;        // let the source editor handle its own keys
        // while editing a text field / combo, leave every key to it (caret, copy/paste text, list nav)
        if (Keyboard.FocusedElement is TextBox or ComboBox or ComboBoxItem) return;

        if ((Keyboard.Modifiers & ModifierKeys.Control) != 0)
        {
            bool shift = (Keyboard.Modifiers & ModifierKeys.Shift) != 0;
            switch (e.Key)
            {
                case Key.Z when shift: Redo(); e.Handled = true; return;
                case Key.Z: Undo(); e.Handled = true; return;
                case Key.Y: Redo(); e.Handled = true; return;
                case Key.G when shift: UngroupSelection(); e.Handled = true; return;
                case Key.G: GroupSelection(); e.Handled = true; return;
                case Key.C: Copy(); e.Handled = true; return;
                case Key.X: Cut(); e.Handled = true; return;
                case Key.V: Paste(); e.Handled = true; return;
                case Key.D: Duplicate(); e.Handled = true; return;
            }
        }
        if (_sel == null) return;
        if (e.Key is Key.Delete or Key.Back) { DeleteSelection(); e.Handled = true; return; }
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
