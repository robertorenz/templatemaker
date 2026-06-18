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
using Microsoft.Win32;

namespace ClarionTplDesigner;

public partial class MainWindow : Window
{
    TplDocument? _doc;
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
            cmbTabs.ItemsSource = _doc.Tabs.Select(t => t.Title).ToList();
            Title = "Clarion Template Designer — " + System.IO.Path.GetFileName(dlg.FileName);
            if (_doc.Tabs.Count > 0) cmbTabs.SelectedIndex = 0;
            status.Text = $"Loaded {_doc.Tabs.Count} tab(s). Click a control to select; drag to move.";
        }
        catch (Exception ex) { MessageBox.Show("Parse failed:\n" + ex.Message); }
    }

    void Save_Click(object s, RoutedEventArgs e)
    {
        if (_doc == null) return;
        try { TplWriter.Save(_doc, _doc.Path); status.Text = "Saved " + _doc.Path; }
        catch (Exception ex) { MessageBox.Show("Save failed:\n" + ex.Message); }
    }

    // Give every positionable control an explicit AT(x,y,w,h) from the current layout,
    // filling only the missing slots so existing coordinates are kept. Makes everything draggable.
    void MaterializeAll_Click(object s, RoutedEventArgs e)
    {
        if (_doc == null) { status.Text = "Open a template first."; return; }
        int n = 0;
        foreach (var tab in _doc.Tabs)
        {
            Layout.Run(tab);
            foreach (var el in Positionable(tab))
                if (MaterializeAt(el)) n++;
        }
        Render();
        status.Text = $"Gave explicit AT() to {n} control(s) across {_doc.Tabs.Count} tab(s). Drag to position, then Save.";
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

    // ---------- tab / render ----------
    void Tab_Changed(object s, SelectionChangedEventArgs e)
    {
        if (_doc == null || cmbTabs.SelectedIndex < 0) return;
        _tab = _doc.Tabs[cmbTabs.SelectedIndex];
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
        el.Deleted = true;
        if (_sel == el) Select(null);
        Render();
        bool block = el.EndLineIndex >= 0;
        status.Text = $"Deleted {el.Display}"
                    + (block ? " and its contents" : "") + ".  Save to write the change (re-open to undo).";
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
        Panel.SetZIndex(border, _z.TryGetValue(el, out var zo) ? zo : (box ? 0 : 5));
        border.ContextMenu = BuildChipMenu(el);
        border.MouseLeftButtonDown += Chip_Down;
        canvas.Children.Add(border);
        _chips[el] = border;
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
        _suppressProp = true;
        txtX.Text = el?.X.ToString() ?? ""; txtY.Text = el?.Y.ToString() ?? "";
        txtW.Text = el?.W.ToString() ?? ""; txtH.Text = el?.H.ToString() ?? "";
        _suppressProp = false;
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
        canvas.ReleaseMouseCapture();
        _drag = Drag.None; _dragEl = null; _dragGuide = null;
    }

    // The pointer is "over a ruler" when it leaves the canvas viewport to the top or left,
    // i.e. scroller-relative coords go negative (the rulers sit above/left of the scroller).
    bool InRulerZone(Point scrollerPt) => scrollerPt.X < 0 || scrollerPt.Y < 0;

    void MoveElement(TplElement el, double lx, double ly)
    {
        lx = Math.Max(0, lx); ly = Math.Max(0, ly);
        el.LX = lx; el.LY = ly;
        var (ox, oy) = FrameOrigin(el);
        el.X = (int)Math.Round(lx - ox);
        el.Y = (int)Math.Round(ly - oy);
        el.HasX = el.HasY = el.Dirty = true;
        if (!el.HasW) { el.W = (int)Math.Round(el.LW); el.HasW = true; }
        if (!el.HasH) { el.H = (int)Math.Round(el.LH); el.HasH = true; }
        if (_chips.TryGetValue(el, out var b))
        {
            Canvas.SetLeft(b, lx * Scale); Canvas.SetTop(b, ly * Scale);
        }
        if (el == _sel) PositionHandles(el);
        _suppressProp = true;
        txtX.Text = el.X.ToString(); txtY.Text = el.Y.ToString();
        _suppressProp = false;
        status.Text = $"{el.Display}  →  AT({el.X},{el.Y},{el.W},{el.H})";
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
