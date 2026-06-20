using System;
using System.Collections.Generic;
using System.Linq;
using System.Text.RegularExpressions;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Input;
using System.Windows.Media;

namespace ClarionTplDesigner;

// "Flow preview" — renders the current part the way Clarion auto-lays a prompt window:
// real WPF controls stacked top-to-bottom (AT() ignored), with the caption / control / button
// columns. Modelled on the CapeSoft "clavte" template editor's previewer.
public partial class MainWindow
{
    bool _preview;
    bool _previewTrueLayout;          // ON = lay out controls by their AT (same-Y on one row); OFF = stack top-to-bottom
    bool _previewPending = true;      // ON = current/unsaved work (interactive); OFF = the saved file on disk
    string[]? _previewLines;          // when set (saved preview), prompt defaults/drops are read from these
    int _previewTabIndex;             // remembered across the rebuild that each selection triggers
    int _previewWidth = 480;          // prompt-window width: 480 (Clarion <=10) or 960 (Clarion 11/12)
    double PreviewFactor => _previewWidth / 480.0;
    TplElement? _dragPreviewEl; Point _dragPreviewStart; bool _dragPreviewing;
    TplElement? _dragTab; Point _dragTabStart; bool _dragTabbing;
    Border? _tabDropMark;   // insertion caret shown while dragging a tab

    void PreviewWidth_Changed(object s, SelectionChangedEventArgs e)
    {
        if (!_ready) return;
        _previewWidth = cmbPreviewWidth.SelectedIndex == 1 ? 960 : 480;
        if (_preview) Render();
    }

    // Clarion prompt types that show a value field + a "…" lookup button.
    static readonly HashSet<string> DialogTypes = new(StringComparer.OrdinalIgnoreCase)
        { "COLOR","COMPONENT","EDIT","FIELD","FILE","FONTDIALOG","FORMAT","ICON","KEY",
          "KEYCODE","OPENDIALOG","OPTFIELD","PICTURE","SAVEDIALOG","EMBED" };

    void Preview_Toggle(object s, RoutedEventArgs e)
    {
        _preview = (s as System.Windows.Controls.Primitives.ToggleButton)?.IsChecked
                   ?? (s as MenuItem)?.IsChecked ?? !_preview;
        miPreview.IsChecked = _preview;
        btnPreview.IsChecked = _preview;
        Select(null);
        Render();
        status.Text = _preview
            ? "Flow preview (read-only) — how Clarion auto-lays out the prompts."
            : "Designer — drag, position and edit controls.";
    }

    void TrueLayout_Toggle(object s, RoutedEventArgs e)
    {
        _previewTrueLayout = (s as System.Windows.Controls.Primitives.ToggleButton)?.IsChecked
                             ?? (s as MenuItem)?.IsChecked ?? !_previewTrueLayout;
        miTrueLayout.IsChecked = _previewTrueLayout;
        btnTrueLayout.IsChecked = _previewTrueLayout;
        if (_previewTrueLayout && !_preview) { _preview = true; miPreview.IsChecked = true; btnPreview.IsChecked = true; }
        Render();
        status.Text = _previewTrueLayout
            ? "Preview: true layout — controls sharing a row sit side by side (by AT)."
            : "Preview: stacked — every control on its own row (AppGen style).";
    }

    void PreviewPending_Toggle(object s, RoutedEventArgs e)
    {
        _previewPending = (s as System.Windows.Controls.Primitives.ToggleButton)?.IsChecked
                          ?? (s as MenuItem)?.IsChecked ?? !_previewPending;
        miPreviewPending.IsChecked = _previewPending;
        btnPreviewPending.IsChecked = _previewPending;
        if (_previewPending && !_preview) { _preview = true; miPreview.IsChecked = true; btnPreview.IsChecked = true; }
        Render();
        status.Text = _previewPending
            ? "Preview: your current, unsaved work (editable)."
            : "Preview: the saved file on disk (read-only).";
    }

    // The on-disk saved text (for the "saved" preview), independent of unsaved edits.
    string SavedText(int fi)
    {
        var f = _doc!.Files[fi];
        try { return System.IO.File.ReadAllText(f.Path); }
        catch { return string.Join(f.Newline, f.Lines); }
    }

    void RenderPreview()
    {
        if (_component == null) { canvas.Width = canvas.Height = 10; return; }

        TplComponent comp = _component;     // ON: live model (interactive, reflects unsaved edits)
        _previewLines = null;
        if (!_previewPending)               // OFF: render the saved file on disk (read-only)
        {
            try
            {
                int fi = _component.FileIndex;
                var temp = TplParser.ParseText(SavedText(fi), _doc!.Files[fi].Path);
                var match = temp.Components.FirstOrDefault(c => c.HasSheet
                                && c.Kind == _component.Kind && c.Name == _component.Name)
                            ?? temp.Components.FirstOrDefault(c => c.HasSheet);
                if (match != null) { comp = match; _previewLines = temp.Files[0].Lines; }
            }
            catch { /* unreadable saved file -> fall back to the model */ }
        }

        var tabs = new TabControl { Width = _previewWidth, BorderThickness = new Thickness(1), Background = Brushes.White };
        foreach (var tab in comp.Tabs)
        {
            if (tab.Deleted) continue;
            if (_previewTrueLayout) Layout.Run(tab);   // compute LX/LY so True layout mirrors the design canvas
            var sp = new StackPanel { Margin = new Thickness(10) };
            BuildFlow(sp, tab.Children);
            object header = tab.Title;
            if (_previewPending)        // interactive preview only: drag a tab header to reorder it
            {
                // Transparent border = the whole header strip is hit-testable, and the event reaches this
                // child BEFORE TabItem's class handler swallows it to switch tabs (so the drag is detectable).
                var hdr = new Border
                {
                    Background = Brushes.Transparent,
                    Child = new TextBlock { Text = tab.Title },
                    Tag = tab,
                    ToolTip = "Drag this tab onto another to reorder it; right-click to rename or delete"
                };
                var tabRef = tab;
                hdr.ContextMenu = new ContextMenu();
                hdr.ContextMenu.Items.Add(ZItem("Rename tab…", () => RenameTab(tabRef)));
                hdr.ContextMenu.Items.Add(ZItem(tabRef.Where.Length > 0 ? "Condition (WHERE)…  ✓" : "Condition (WHERE)…",
                                                () => EditTabWhere(tabRef)));
                hdr.ContextMenu.Items.Add(ZItem("Delete tab",  () => DeleteTab(tabRef)));
                hdr.MouseLeftButtonDown += Tab_HeaderDown;
                hdr.MouseMove += Tab_HeaderMove;
                hdr.MouseLeftButtonUp += Tab_HeaderUp;
                header = hdr;
            }
            tabs.Items.Add(new TabItem { Header = header, Content = sp, Tag = tab });
        }
        _previewLines = null;
        if (tabs.Items.Count == 0) { canvas.Width = canvas.Height = 10; return; }

        tabs.SelectedIndex = Math.Min(Math.Max(0, _previewTabIndex), tabs.Items.Count - 1);
        tabs.SelectionChanged += (_, e) => { if (e.OriginalSource is TabControl tc) _previewTabIndex = tc.SelectedIndex; };

        Canvas.SetLeft(tabs, 12); Canvas.SetTop(tabs, 12);
        canvas.Children.Add(tabs);
        tabs.Measure(new Size(_previewWidth, double.PositiveInfinity));
        canvas.Width = _previewWidth + 30;
        canvas.Height = Math.Max(300, tabs.DesiredSize.Height + 40);
    }

    void BuildFlow(Panel host, IEnumerable<TplElement> children)
    {
        if (_previewTrueLayout)
        {
            var rows = new List<(double y, double x, bool block, FrameworkElement vis)>();
            CollectRows(rows, children);
            FlushRows(host, rows);
            return;
        }

        StackPanel? optionGroup = null;     // RADIOs accumulate into the most recent OPTION group
        foreach (var el in children)
        {
            if (el.Deleted) continue;
            string u = el.Kind == TplKind.Prompt ? el.PromptType.Trim().ToUpperInvariant() : "";

            if (el.Kind == TplKind.Prompt && u.StartsWith("RADIO") && optionGroup != null)
            {
                var rb = new RadioButton { Content = el.Title, Margin = new Thickness(2), IsHitTestVisible = false };
                ApplyFont(rb, el); optionGroup.Children.Add(Selectable(rb, el));
                continue;
            }
            if (!(el.Kind == TplKind.Prompt && u.StartsWith("OPTION"))) optionGroup = null;

            if (el.Kind == TplKind.Enable) { BuildFlow(host, el.Children); continue; }   // transparent group
            if (el.Kind == TplKind.Prompt && u.StartsWith("OPTION"))
            {
                host.Children.Add(Selectable(MakeOptionGroup(el, out optionGroup), el));
                continue;
            }
            var content = BuildContent(el, u);
            if (content != null) host.Children.Add(Selectable(content, el));
        }
    }

    // Collect (y, x, block, visual) for each control, using the COMPUTED layout position LX/LY (not the raw
    // AT). LY honours both an explicit AT(x,y) and Clarion's auto-flow of an omitted Y, so True layout groups
    // controls into rows exactly as they sit on the design canvas. "block" controls (boxes, option groups)
    // get their own full-width row; leaf controls within a few units of Y are grouped side by side.
    void CollectRows(List<(double y, double x, bool block, FrameworkElement vis)> rows, IEnumerable<TplElement> children)
    {
        StackPanel? optionGroup = null;
        foreach (var el in children)
        {
            if (el.Deleted) continue;
            string u = el.Kind == TplKind.Prompt ? el.PromptType.Trim().ToUpperInvariant() : "";

            if (el.Kind == TplKind.Prompt && u.StartsWith("RADIO") && optionGroup != null)
            {
                var rb = new RadioButton { Content = el.Title, Margin = new Thickness(2), IsHitTestVisible = false };
                ApplyFont(rb, el); optionGroup.Children.Add(Selectable(rb, el));
                continue;
            }
            if (!(el.Kind == TplKind.Prompt && u.StartsWith("OPTION"))) optionGroup = null;

            if (el.Kind == TplKind.Enable) { CollectRows(rows, el.Children); continue; }
            double y = el.LY, x = el.LX;   // computed layout position: matches the design canvas
            if (el.Kind == TplKind.Prompt && u.StartsWith("OPTION"))
            {
                rows.Add((y, x, true, Selectable(MakeOptionGroup(el, out optionGroup), el)));
                continue;
            }
            var content = BuildContent(el, u);
            if (content != null) rows.Add((y, x, el.Kind == TplKind.Boxed, Selectable(content, el)));
        }
    }

    // Order rows top-to-bottom by their computed Y (LY), then group leaf controls whose Y is within a few
    // units onto one horizontal row (ordered by X) — so two controls dragged onto the same line on the design
    // canvas sit side by side here too, regardless of their order in the source. Boxes/option groups always
    // take their own row.
    void FlushRows(Panel host, List<(double y, double x, bool block, FrameworkElement vis)> rows)
    {
        var sorted = rows.OrderBy(r => r.y).ToList();
        int i = 0;
        while (i < sorted.Count)
        {
            if (sorted[i].block) { host.Children.Add(sorted[i].vis); i++; continue; }
            double y0 = sorted[i].y;
            var group = new List<(double x, FrameworkElement vis)>();
            while (i < sorted.Count && !sorted[i].block && sorted[i].y - y0 <= 6) { group.Add((sorted[i].x, sorted[i].vis)); i++; }
            if (group.Count == 1) { host.Children.Add(group[0].vis); continue; }
            group.Sort((a, b) => a.x.CompareTo(b.x));
            var row = new StackPanel { Orientation = Orientation.Horizontal };
            foreach (var g in group)
            {
                g.vis.VerticalAlignment = VerticalAlignment.Center;
                row.Children.Add(g.vis);
            }
            host.Children.Add(row);
        }
    }

    GroupBox MakeOptionGroup(TplElement el, out StackPanel inner)
    {
        var og = new GroupBox { Header = el.Title, Margin = new Thickness(0, 4, 0, 4) };
        inner = new StackPanel(); og.Content = inner;
        return og;
    }

    // The visual for one control (no Selectable wrapper, no OPTION/RADIO/ENABLE handling).
    FrameworkElement? BuildContent(TplElement el, string u)
    {
        switch (el.Kind)
        {
            case TplKind.Display:
                var disp = new TextBlock { Text = el.Title.Length > 0 ? el.Title : " ",
                    Margin = new Thickness(0, 2, 0, 2), TextWrapping = TextWrapping.Wrap, IsHitTestVisible = false };
                ApplyFont(disp, el); return disp;
            case TplKind.Image:
                var bmp = ResolveImage(el.Title);
                if (bmp != null)
                {
                    double f = PreviewFactor;
                    return new System.Windows.Controls.Image
                    {
                        Source = bmp, Stretch = Stretch.Uniform, StretchDirection = StretchDirection.DownOnly,
                        IsHitTestVisible = false, SnapsToDevicePixels = true,
                        HorizontalAlignment = HorizontalAlignment.Left, Margin = new Thickness(0, 2, 0, 2),
                        MaxWidth = el.HasW && el.W > 0 ? el.W * f : bmp.PixelWidth,
                        MaxHeight = el.HasH && el.H > 0 ? el.H * f : bmp.PixelHeight
                    };
                }
                return new TextBlock { Text = "🖼 " + el.Title, Margin = new Thickness(0, 2, 0, 2),
                    IsHitTestVisible = false, Foreground = new SolidColorBrush(Color.FromRgb(0x8A, 0x95, 0xA3)) };
            case TplKind.Boxed:
                var gb = new GroupBox { Header = el.Title, Margin = new Thickness(0, 4, 0, 4) };
                var bi = new StackPanel(); BuildFlow(bi, el.Children); gb.Content = bi;
                return gb;
            case TplKind.Button:
                return new Button { Content = el.Title, HorizontalAlignment = HorizontalAlignment.Left,
                    Padding = new Thickness(10, 2, 10, 2), Margin = new Thickness(0, 4, 0, 4), IsHitTestVisible = false };
            case TplKind.Prompt:
                if (u == "CHECK")
                {
                    var cb = new CheckBox { Content = el.Title, Margin = new Thickness(0, 3, 0, 3), IsHitTestVisible = false };
                    ApplyFont(cb, el); return cb;
                }
                return BuildPromptRow(el, u);
            default: return null;
        }
    }

    // Wrap a preview control so clicking it selects the element (Ctrl = add to selection), with a context menu.
    FrameworkElement Selectable(FrameworkElement content, TplElement el)
    {
        if (!_previewPending)       // the "saved" preview is read-only (its elements aren't the live model)
            return new Border { Child = content, Padding = new Thickness(1), BorderThickness = new Thickness(1),
                                BorderBrush = Brushes.Transparent };
        var b = new Border
        {
            Child = content,
            Background = Brushes.Transparent,
            BorderThickness = new Thickness(1),
            BorderBrush = _selection.Contains(el) ? new SolidColorBrush(Color.FromRgb(220, 70, 60)) : Brushes.Transparent,
            Padding = new Thickness(1),
            Tag = el
        };
        // build the menu on open so Arrange reflects the live selection (multi-select doesn't re-render)
        b.ContextMenuOpening += (_, _) =>
        {
            if (_selection.Count <= 1 && !_selection.Contains(el)) Select(el);   // keep an existing multi-selection
            b.ContextMenu = BuildPreviewMenu(el);
        };
        b.MouseLeftButtonDown += PreviewElement_Down;
        b.MouseMove += PreviewDrag_Move;
        b.MouseLeftButtonUp += PreviewDrag_Up;
        return b;
    }

    void PreviewElement_Down(object s, MouseButtonEventArgs e)
    {
        var b = (Border)s;
        if (b.Tag is not TplElement el) return;
        if ((Keyboard.Modifiers & ModifierKeys.Control) != 0) ToggleSelect(el); else Select(el);
        b.BorderBrush = _selection.Contains(el) ? new SolidColorBrush(Color.FromRgb(220, 70, 60)) : Brushes.Transparent;
        // read-only #INSERT content is selectable (to inspect) but not draggable
        _dragPreviewEl = !el.Foreign && (el.IsPositionable || el.Kind == TplKind.Button) ? el : null;   // leaves, boxes, buttons
        _dragPreviewStart = e.GetPosition(canvas);
        _dragPreviewing = false;
        b.CaptureMouse();
        e.Handled = true;
    }

    void PreviewDrag_Move(object s, MouseEventArgs e)
    {
        if (_dragPreviewEl == null || e.LeftButton != MouseButtonState.Pressed || _dragPreviewing) return;
        var p = e.GetPosition(canvas);
        if (Math.Abs(p.X - _dragPreviewStart.X) > 4 || Math.Abs(p.Y - _dragPreviewStart.Y) > 4)
        {
            _dragPreviewing = true; ((Border)s).Opacity = 0.6;
        }
    }

    void PreviewDrag_Up(object s, MouseButtonEventArgs e)
    {
        var b = (Border)s;
        b.ReleaseMouseCapture(); b.Opacity = 1;
        var pt = e.GetPosition(canvas);
        bool reordered = false;
        if (_dragPreviewing && _dragPreviewEl != null)
            // in true layout, reorder by re-flowing Y (source-order reorder wouldn't change the Y-sorted view)
            reordered = (_previewTrueLayout && TrueLayoutReorder(_dragPreviewEl, pt)) || ReorderTo(_dragPreviewEl, pt);
        _dragPreviewEl = null; _dragPreviewing = false;
        Render();
        if (reordered) status.Text = "Reordered — Save to write the new positions.";
    }

    // True-layout drag reorder: move the dragged control's row above/below the target row by re-flowing the
    // parent's rows to a clean vertical stack in the new order (so the Y-sorted preview actually changes).
    bool TrueLayoutReorder(TplElement dragged, Point ptCanvas)
    {
        if (canvas.InputHitTest(ptCanvas) is not DependencyObject hit) return false;
        TplElement? ctrl = null; Border? cb = null;
        for (DependencyObject? d = hit; d != null; d = VisualTreeHelper.GetParent(d))
            if (d is Border bb && bb.Tag is TplElement te) { ctrl = te; cb = bb; break; }
        if (ctrl == null || ctrl == dragged) return false;

        // dropping a leaf onto a box (not its own) is a reparent — let ReorderTo handle it
        if (ctrl.Kind == TplKind.Boxed && dragged.Kind is TplKind.Prompt or TplKind.Display or TplKind.Image
            && !IsAncestor(ctrl, dragged)) return false;

        var p = dragged.Parent;
        if (p == null) return false;
        var target = ctrl;                              // map the target up to a direct sibling of the dragged
        while (target != null && target.Parent != p) target = target.Parent;
        if (target == null || target == dragged) return false;    // different parent -> reparent (ReorderTo)

        bool before = true;
        try { before = canvas.TransformToVisual(cb).Transform(ptCanvas).Y < cb!.ActualHeight / 2; } catch { }
        return ReflowRows(p, dragged, target, before);
    }

    bool ReflowRows(TplElement p, TplElement dragged, TplElement target, bool before)
    {
        EnsureLayout();
        var kids = p.Children.Where(c => !c.Deleted && (c.IsPositionable || c.Kind == TplKind.Button)).ToList();
        if (kids.Count < 2) return false;

        // group into rows (boxes own a row; leaves within a few units of Y share one), ordered top-down
        var sorted = kids.OrderBy(k => k.LY).ToList();
        var rows = new List<(List<TplElement> els, double top, double height)>();
        for (int i = 0; i < sorted.Count;)
        {
            double top = sorted[i].LY, bottom = sorted[i].LY + sorted[i].LH;
            var els = new List<TplElement> { sorted[i] };
            if (sorted[i].Kind == TplKind.Boxed) i++;
            else
            {
                i++;
                while (i < sorted.Count && sorted[i].Kind != TplKind.Boxed && sorted[i].LY - top <= 6)
                { els.Add(sorted[i]); bottom = Math.Max(bottom, sorted[i].LY + sorted[i].LH); i++; }
            }
            rows.Add((els, top, bottom - top));
        }

        int dRow = rows.FindIndex(r => r.els.Contains(dragged));
        int tRow = rows.FindIndex(r => r.els.Contains(target));
        if (dRow < 0 || tRow < 0 || dRow == tRow) return false;

        var moving = rows[dRow]; rows.RemoveAt(dRow);
        int ti = rows.FindIndex(r => r.els.Contains(target));
        rows.Insert(before ? ti : ti + 1, moving);

        PushUndo();
        double anchor = rows.Min(r => r.top), cur = anchor; const double gap = 4;
        foreach (var r in rows)
        {
            double delta = cur - r.top;
            if (Math.Abs(delta) >= 0.5)
                foreach (var el in r.els) MoveElement(el, el.LX, Math.Max(0, el.LY + delta));   // boxes carry contents
            cur += r.height + gap;
        }
        return true;
    }

    // ---------- drag a TAB header to reorder the tabs ----------
    // Down: remember the tab but don't handle the event, so the TabControl still switches to it.
    // (Clicks on a control inside the tab are marked handled by PreviewElement_Down, so they don't reach here.)
    void Tab_HeaderDown(object s, MouseButtonEventArgs e)
    {
        if (s is not Border hdr || hdr.Tag is not TplElement tab) return;
        _dragTab = tab; _dragTabStart = e.GetPosition(canvas); _dragTabbing = false;
        // don't handle: let it bubble to the TabItem so the tab still selects on click
    }

    void Tab_HeaderMove(object s, MouseEventArgs e)
    {
        if (_dragTab == null || e.LeftButton != MouseButtonState.Pressed) return;
        var p = e.GetPosition(canvas);
        if (!_dragTabbing)
        {
            if (Math.Abs(p.X - _dragTabStart.X) <= 6 && Math.Abs(p.Y - _dragTabStart.Y) <= 6) return;
            _dragTabbing = true;
            if (s is Border hdr) { hdr.CaptureMouse(); hdr.Opacity = 0.5; }
        }
        ShowTabDropMark(p);   // caret follows the cursor over the tab strip
    }

    // Draw a vertical caret at the edge of the tab under the cursor (the spot the dragged tab will land).
    void ShowTabDropMark(Point ptCanvas)
    {
        TabItem? ti = null;
        if (canvas.InputHitTest(ptCanvas) is DependencyObject hit)
            for (DependencyObject? d = hit; d != null; d = VisualTreeHelper.GetParent(d))
                if (d is TabItem t) { ti = t; break; }

        if (ti == null || (ti.Tag is TplElement tt && tt == _dragTab)) { HideTabDropMark(); return; }

        bool after; Point tl;
        try
        {
            after = canvas.TransformToVisual(ti).Transform(ptCanvas).X > ti.ActualWidth / 2;
            tl = ti.TransformToVisual(canvas).Transform(new Point(0, 0));
        }
        catch { HideTabDropMark(); return; }

        if (_tabDropMark == null)
        {
            _tabDropMark = new Border
            {
                Width = 3, IsHitTestVisible = false,
                Background = new SolidColorBrush(Color.FromRgb(220, 70, 60)),
                CornerRadius = new CornerRadius(1)
            };
            canvas.Children.Add(_tabDropMark);
        }
        Panel.SetZIndex(_tabDropMark, 1000);
        _tabDropMark.Height = Math.Max(10, ti.ActualHeight);
        Canvas.SetLeft(_tabDropMark, tl.X + (after ? ti.ActualWidth : 0) - 1.5);
        Canvas.SetTop(_tabDropMark, tl.Y);
        _tabDropMark.Visibility = Visibility.Visible;
    }

    void HideTabDropMark()
    {
        if (_tabDropMark != null) { canvas.Children.Remove(_tabDropMark); _tabDropMark = null; }
    }

    void Tab_HeaderUp(object s, MouseButtonEventArgs e)
    {
        if (s is Border hdr) { hdr.ReleaseMouseCapture(); hdr.Opacity = 1; }
        HideTabDropMark();
        var dragged = _dragTab; bool was = _dragTabbing;
        _dragTab = null; _dragTabbing = false;
        if (!was || dragged == null || _component == null) return;

        var hit = TabHit(e.GetPosition(canvas));
        if (hit == null || hit.Value.tab == dragged) return;
        var (target, after) = hit.Value;
        var tabs = _component.Tabs;
        TplElement? insertBefore;
        if (!after) insertBefore = target;
        else { int i = tabs.IndexOf(target); insertBefore = i + 1 < tabs.Count ? tabs[i + 1] : null; }
        if (insertBefore == dragged) return;

        ReorderTab(dragged, insertBefore);
        Render();
        status.Text = "Reordered tab — Save to write the new tab order.";
    }

    // The tab whose header is under a canvas point, and whether the point is past its midpoint.
    (TplElement tab, bool after)? TabHit(Point ptCanvas)
    {
        if (canvas.InputHitTest(ptCanvas) is not DependencyObject hit) return null;
        for (DependencyObject? d = hit; d != null; d = VisualTreeHelper.GetParent(d))
            if (d is TabItem ti && ti.Tag is TplElement te)
            {
                bool after = false;
                try { after = canvas.TransformToVisual(ti).Transform(ptCanvas).X > ti.ActualWidth / 2; } catch { }
                return (te, after);
            }
        return null;
    }

    // Drop the dragged control wherever the cursor is: reorder among siblings, move into a #BOXED,
    // or move to another tab (drop on its header). Same-parent = reorder; different = reparent.
    bool ReorderTo(TplElement el, Point ptCanvas)
    {
        if (canvas.InputHitTest(ptCanvas) is not DependencyObject hit) return false;
        TplElement? ctrl = null; Border? cb = null; TplElement? tabEl = null;
        for (DependencyObject? d = hit; d != null; d = VisualTreeHelper.GetParent(d))
        {
            if (ctrl == null && d is Border bb && bb.Tag is TplElement te) { ctrl = te; cb = bb; }
            if (tabEl == null && d is TabItem ti && ti.Tag is TplElement tte) tabEl = tte;
        }

        TplElement? newParent; TplElement? insertBefore = null;
        if (ctrl != null)
        {
            if (ctrl == el) return false;
            if (ctrl.Kind == TplKind.Boxed && el.Kind is TplKind.Prompt or TplKind.Display or TplKind.Image)
            {
                if (IsAncestor(ctrl, el))                           // already inside this box -> move it OUT (after the box)
                {
                    newParent = ctrl.Parent;
                    var bsibs = newParent?.Children; int bi = bsibs?.IndexOf(ctrl) ?? -1;
                    insertBefore = bsibs != null && bi + 1 < bsibs.Count ? bsibs[bi + 1] : null;
                }
                else newParent = ctrl;                              // a leaf dropped on another box -> into the box
            }
            else
            {
                newParent = ctrl.Parent;
                bool before = true;
                try { before = canvas.TransformToVisual(cb).Transform(ptCanvas).Y < cb!.ActualHeight / 2; } catch { }
                var sibs = newParent?.Children;
                int ti = sibs?.IndexOf(ctrl) ?? -1;
                insertBefore = before ? ctrl : (sibs != null && ti + 1 < sibs.Count ? sibs[ti + 1] : null);
            }
        }
        else if (tabEl != null) newParent = tabEl;                  // dropped on a tab (header/empty area)
        else return false;

        if (newParent == null || newParent == el || IsAncestor(el, newParent)) return false;
        if (newParent == el.Parent && insertBefore == el) return false;

        MoveTo(el, newParent, insertBefore);

        int tabIdx = TabIndexOf(newParent);                        // follow the control to its (possibly new) tab
        if (tabIdx >= 0) _previewTabIndex = tabIdx;
        return true;
    }

    void MoveTo(TplElement el, TplElement newParent, TplElement? insertBefore)
    {
        // read-only #INSERT content can't be reparented, nor can anything be moved into it
        if (el.Foreign || newParent.Foreign) { status.Text = "Inlined #INSERT content is read-only."; return; }
        PushUndo();
        el.Parent?.Children.Remove(el);
        int idx = insertBefore != null ? newParent.Children.IndexOf(insertBefore) : -1;
        if (idx >= 0) newParent.Children.Insert(idx, el); else newParent.Children.Add(el);
        el.Parent = newParent;
        if (!el.Inserted) el.Moved = true;

        int pos = newParent.Children.IndexOf(el);
        el.MoveAnchorLine = -1;
        for (int i = pos + 1; i < newParent.Children.Count; i++)
        {
            var sib = newParent.Children[i];
            // skip foreign siblings: their LineIndex points into the #GROUP's file, not this one
            if (!sib.Inserted && !sib.Deleted && !sib.Foreign && sib.LineIndex >= 0) { el.MoveAnchorLine = sib.LineIndex; break; }
        }
    }

    // ---------- drag a control type from the Add bar onto the preview to insert it ----------
    Point _addBtnStart; bool _addBtnPressed;

    static (TplKind kind, string title, string promptType, int w, int h) SpecFor(string token) => token switch
    {
        "String" => (TplKind.Prompt, "Text:", "@s255", 120, 11),
        "Number" => (TplKind.Prompt, "Number:", "@n8", 80, 11),
        "Spin"   => (TplKind.Prompt, "Count:", "SPIN(@n3,0,100)", 90, 11),
        "Check"  => (TplKind.Prompt, "Enabled", "CHECK", 110, 11),
        "Image"  => (TplKind.Image, "image.png", "", 16, 16),
        "Group"  => (TplKind.Boxed, "Group", "", 200, 60),
        _        => (TplKind.Display, "Label", "", 80, 11),
    };

    void AddBtn_Down(object s, MouseButtonEventArgs e) { _addBtnStart = e.GetPosition(null); _addBtnPressed = true; }

    void AddBtn_DragMove(object s, MouseEventArgs e)
    {
        if (!_addBtnPressed || e.LeftButton != MouseButtonState.Pressed) return;
        var p = e.GetPosition(null);
        if (Math.Abs(p.X - _addBtnStart.X) > 6 || Math.Abs(p.Y - _addBtnStart.Y) > 6)
        {
            _addBtnPressed = false;
            if (s is FrameworkElement fe && fe.Tag is string token)
                DragDrop.DoDragDrop(fe, new DataObject("tplkind", token), DragDropEffects.Copy);
        }
    }

    void Canvas_DragOver(object s, DragEventArgs e)
    {
        e.Effects = e.Data.GetDataPresent("tplkind") ? DragDropEffects.Copy : DragDropEffects.None;
        e.Handled = true;
    }

    void Canvas_Drop(object s, DragEventArgs e)
    {
        if (_doc == null || _component == null || !e.Data.GetDataPresent("tplkind")) return;
        var (kind, title, pt, w, h) = SpecFor((string)e.Data.GetData("tplkind"));
        var p = e.GetPosition(canvas);

        if (_preview && _previewPending)             // flow preview: insert at the drop position
        {
            var (np, before) = PreviewDropTarget(p);
            np ??= _tab;
            if (np == null) return;
            if (np.Foreign) { status.Text = "Can't add controls inside read-only #INSERT content."; return; }
            AddControlAt(kind, title, pt, w, h, np, before);
        }
        else if (_tab != null)                       // positioner: drop at the cursor with that AT
        {
            if (_tab.Foreign) { status.Text = "Can't add controls inside read-only #INSERT content."; return; }
            PushUndo();
            var el = MakeControl(kind, title, pt, w, h);
            el.Parent = _tab; _tab.Children.Add(el);
            el.X = (int)Math.Max(0, Math.Round(p.X / Scale));
            el.Y = (int)Math.Max(0, Math.Round(p.Y / Scale));
            Render(); Select(el);
            status.Text = $"Added {kind} \"{title}\" at ({el.X},{el.Y}).";
        }
    }

    (TplElement?, TplElement?) PreviewDropTarget(Point p)
    {
        if (canvas.InputHitTest(p) is not DependencyObject hit) return (null, null);
        TplElement? ctrl = null; Border? cb = null; TplElement? tabEl = null;
        for (DependencyObject? d = hit; d != null; d = VisualTreeHelper.GetParent(d))
        {
            if (ctrl == null && d is Border bb && bb.Tag is TplElement te) { ctrl = te; cb = bb; }
            if (tabEl == null && d is TabItem ti && ti.Tag is TplElement tte) tabEl = tte;
        }
        if (ctrl != null)
        {
            if (ctrl.Kind == TplKind.Boxed) return (ctrl, null);     // into the box (append)
            var np = ctrl.Parent;
            bool before = true;
            try { before = canvas.TransformToVisual(cb).Transform(p).Y < cb!.ActualHeight / 2; } catch { }
            var sibs = np?.Children; int ti = sibs?.IndexOf(ctrl) ?? -1;
            return (np, before ? ctrl : (sibs != null && ti + 1 < sibs.Count ? sibs[ti + 1] : null));
        }
        return tabEl != null ? (tabEl, null) : (null, null);
    }

    static bool IsAncestor(TplElement anc, TplElement node)
    {
        for (var p = node.Parent; p != null; p = p.Parent) if (p == anc) return true;
        return false;
    }

    int TabIndexOf(TplElement node)
    {
        for (var p = node; p != null; p = p.Parent)
            if (p.Kind == TplKind.Tab && _component != null) return LiveTabs().IndexOf(p);
        return -1;
    }

    ContextMenu BuildPreviewMenu(TplElement el)
    {
        var cm = new ContextMenu();
        cm.Items.Add(BuildArrangeMenu(el));
        cm.Items.Add(new Separator());
        cm.Items.Add(ZItem("Colour…", () => { if (!_selection.Contains(el)) Select(el); ChangeColor(); }));
        cm.Items.Add(ZItem("Duplicate", () => { PickKeep(el); Duplicate(); }));
        cm.Items.Add(ZItem("Copy", () => { PickKeep(el); Copy(); }));
        cm.Items.Add(new Separator());
        cm.Items.Add(ZItem("Delete", () => { PickKeep(el); DeleteSelection(); }));
        return cm;
    }

    FrameworkElement BuildPromptRow(TplElement el, string u)
    {
        string def = PromptDefault(el);

        double f = PreviewFactor;   // 1.0 at 480 (Clarion <=10), 2.0 at 960 (Clarion 11/12)

        if (u.StartsWith("TEXT"))   // multiline: label then a tall box
        {
            var col = new StackPanel { Margin = new Thickness(0, 2, 0, 2) };
            var lab = new TextBlock { Text = el.Title }; ApplyFont(lab, el); col.Children.Add(lab);
            col.Children.Add(new TextBox { Text = def, AcceptsReturn = true, Height = 80, Width = 340 * f, IsHitTestVisible = false,
                HorizontalAlignment = HorizontalAlignment.Left, VerticalScrollBarVisibility = ScrollBarVisibility.Auto });
            return col;
        }

        var g = new Grid { Margin = new Thickness(0, 1, 0, 1) };
        g.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(200 * f) });
        g.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(140 * f) });
        g.ColumnDefinitions.Add(new ColumnDefinition { Width = GridLength.Auto });

        var lbl = new TextBlock { Text = el.Title, VerticalAlignment = VerticalAlignment.Center,
            TextTrimming = TextTrimming.CharacterEllipsis };
        ApplyFont(lbl, el); Grid.SetColumn(lbl, 0); g.Children.Add(lbl);

        FrameworkElement ctrl;
        string? btn = null;
        if (u.StartsWith("PROCEDURE") || u.StartsWith("FROM"))
            ctrl = new ComboBox { Text = def, IsEditable = true };
        else if (u.StartsWith("DROP"))
        {
            var c = new ComboBox { IsEditable = true, Text = def };
            foreach (var it in DropItems(el)) c.Items.Add(it);
            ctrl = c;
        }
        else if (u.StartsWith("SPIN")) ctrl = new TextBox { Text = def };
        else if (u.StartsWith("EXPR")) { ctrl = new TextBox { Text = def }; btn = "E"; }
        else if (DialogTypes.Contains(u))
        {
            string txt = u == "KEYCODE" && PromptDefaultInt(el) is int kc ? DecodeKey(kc) : def;
            ctrl = new TextBox { Text = txt }; btn = "…";
        }
        else ctrl = new TextBox { Text = def };   // @picture entry / anything else

        ctrl.Height = 22; ctrl.VerticalAlignment = VerticalAlignment.Center; ctrl.IsHitTestVisible = false;
        Grid.SetColumn(ctrl, 1); g.Children.Add(ctrl);

        if (btn != null)
        {
            var b = new Button { Content = btn, Width = 24, Height = 22, Margin = new Thickness(2, 0, 0, 0), IsHitTestVisible = false };
            Grid.SetColumn(b, 2); g.Children.Add(b);
        }
        return g;
    }

    static void ApplyFont(TextBlock t, TplElement el)
    {
        if (!string.IsNullOrWhiteSpace(el.FontName)) t.FontFamily = new FontFamily(el.FontName);
        if (el.FontSize > 0) t.FontSize = Math.Max(8, el.FontSize);
        t.FontWeight = el.Bold ? FontWeights.Bold : FontWeights.Normal;
        if (el.Italic) t.FontStyle = FontStyles.Italic;
        if (el.Underline || el.Strikeout)
        {
            var dec = new TextDecorationCollection();
            if (el.Underline) foreach (var d in TextDecorations.Underline) dec.Add(d);
            if (el.Strikeout) foreach (var d in TextDecorations.Strikethrough) dec.Add(d);
            t.TextDecorations = dec;
        }
        if (el.FontColor is uint c) t.Foreground = FromColorRef(c);
    }
    static void ApplyFont(Control c, TplElement el)
    {
        if (!string.IsNullOrWhiteSpace(el.FontName)) c.FontFamily = new FontFamily(el.FontName);
        if (el.FontSize > 0) c.FontSize = Math.Max(8, el.FontSize);
        c.FontWeight = el.Bold ? FontWeights.Bold : FontWeights.Normal;
        if (el.FontColor is uint col) c.Foreground = FromColorRef(col);
    }

    string PromptDefault(TplElement el)
    {
        var src = _previewLines ?? CurrentFile()?.Lines;
        if (src == null || el.LineIndex < 0 || el.LineIndex >= src.Length) return "";
        var line = src[el.LineIndex];
        var m = Regex.Match(line, @"\bdefault\s*\(\s*'([^']*)'", RegexOptions.IgnoreCase);
        if (m.Success) return m.Groups[1].Value;
        var m2 = Regex.Match(line, @"\bdefault\s*\(\s*([^)]*)\)", RegexOptions.IgnoreCase);
        return m2.Success ? m2.Groups[1].Value.Trim() : "";
    }

    IEnumerable<string> DropItems(TplElement el)
    {
        var src = _previewLines ?? CurrentFile()?.Lines;
        if (src == null || el.LineIndex < 0 || el.LineIndex >= src.Length) yield break;
        var m = Regex.Match(src[el.LineIndex], @"\bdrop\s*\(\s*'([^']*)'", RegexOptions.IgnoreCase);
        if (!m.Success) yield break;
        foreach (var part in m.Groups[1].Value.Split('|'))
        {
            int br = part.IndexOf('[');
            yield return (br >= 0 ? part[..br] : part).Trim();
        }
    }
}
