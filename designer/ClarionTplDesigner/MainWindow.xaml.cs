using System;
using System.Collections.Generic;
using System.Globalization;
using System.Linq;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Input;
using System.Windows.Media;
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
    readonly List<Guide> _guides = new();

    enum Drag { None, Element, Guide }
    Drag _drag = Drag.None;
    TplElement? _dragEl;
    Guide? _dragGuide;
    Point _dragStart;
    double _elStartX, _elStartY;
    bool _suppressProp;
    bool _ready;          // true once XAML is fully constructed

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
    }

    IEnumerable<TplElement> Positionable(TplElement c)
    {
        foreach (var ch in c.Children)
        {
            if (ch.IsPositionable) yield return ch;
            foreach (var x in Positionable(ch)) yield return x;
        }
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
        if (!box)
        {
            var fg = el.FontColor is uint c ? FromColorRef(c) : Brushes.Black;
            border.Child = new TextBlock
            {
                Text = el.Display,
                Foreground = fg,
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
        Panel.SetZIndex(border, box ? 0 : 5);
        border.MouseLeftButtonDown += Chip_Down;
        canvas.Children.Add(border);
        _chips[el] = border;
    }

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
        else if (_drag == Drag.Guide && _dragGuide != null)
        {
            double v = (_dragGuide.Vertical ? p.X : p.Y) / Scale;
            if (chkSnapGrid.IsChecked == true) v = Math.Round(v / GridStep) * GridStep;
            _dragGuide.Dlu = Math.Max(0, Math.Round(v));
            PositionGuide(_dragGuide);
            status.Text = $"{(_dragGuide.Vertical ? "V" : "H")} guide @ {_dragGuide.Dlu} DLU";
        }
    }

    void Canvas_MouseUp(object s, MouseButtonEventArgs e)
    {
        canvas.ReleaseMouseCapture();
        _drag = Drag.None; _dragEl = null; _dragGuide = null;
    }

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

    void HRuler_Down(object s, MouseButtonEventArgs e)   // top ruler -> vertical guide
        => StartGuide(true, ((e.GetPosition(hRuler).X + scroller.HorizontalOffset) / Scale));
    void VRuler_Down(object s, MouseButtonEventArgs e)   // left ruler -> horizontal guide
        => StartGuide(false, ((e.GetPosition(vRuler).Y + scroller.VerticalOffset) / Scale));

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
            Stroke = new SolidColorBrush(Color.FromRgb(0, 150, 200)),
            StrokeThickness = 1,
            StrokeDashArray = new DoubleCollection { 4, 3 },
            Tag = g, Cursor = g.Vertical ? Cursors.SizeWE : Cursors.SizeNS
        };
        Panel.SetZIndex(line, 50);
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
        if (e.ClickCount == 2) { canvas.Children.Remove(g.Visual); _guides.Remove(g); e.Handled = true; return; }
        _drag = Drag.Guide; _dragGuide = g;
        canvas.CaptureMouse();
        e.Handled = true;
    }

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
