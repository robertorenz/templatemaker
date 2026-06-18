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
    bool _previewPending;             // build the preview from the live/pending source, not the saved file
    string[]? _previewLines;          // when set, prompt defaults/drops are read from these (the pending text)

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

    void PreviewPending_Toggle(object s, RoutedEventArgs e)
    {
        _previewPending = (s as System.Windows.Controls.Primitives.ToggleButton)?.IsChecked
                          ?? (s as MenuItem)?.IsChecked ?? !_previewPending;
        miPreviewPending.IsChecked = _previewPending;
        btnPreviewPending.IsChecked = _previewPending;
        if (_previewPending && !_preview) { _preview = true; miPreview.IsChecked = true; btnPreview.IsChecked = true; }
        Render();
        status.Text = _previewPending
            ? "Preview is reading the LIVE pending source (unsaved edits included)."
            : "Preview is reading the current model.";
    }

    // The source text that includes every pending edit (un-applied hand edits, or the model's would-be save).
    string PendingSourceText(int fi)
    {
        if (_doc == null) return "";
        if (_srcOpen && _srcDirty && !_srcLive && fi == (_component?.FileIndex ?? 0))
            return srcEditor.Text;                       // un-applied hand edits in the source panel
        return TplWriter.PreviewFile(_doc, fi);          // model's would-be-saved text
    }

    void RenderPreview()
    {
        if (_component == null) { canvas.Width = canvas.Height = 10; return; }

        TplComponent comp = _component;
        _previewLines = null;
        if (_previewPending)
        {
            try
            {
                int fi = _component.FileIndex;
                var temp = TplParser.ParseText(PendingSourceText(fi), _doc!.Files[fi].Path);
                var match = temp.Components.FirstOrDefault(c => c.HasSheet
                                && c.Kind == _component.Kind && c.Name == _component.Name)
                            ?? temp.Components.FirstOrDefault(c => c.HasSheet);
                if (match != null) { comp = match; _previewLines = temp.Files[0].Lines; }
            }
            catch { /* broken pending source -> fall back to the model */ }
        }

        var tabs = new TabControl { Width = 480, BorderThickness = new Thickness(1), Background = Brushes.White };
        foreach (var tab in comp.Tabs)
        {
            var sp = new StackPanel { Margin = new Thickness(10) };
            BuildFlow(sp, tab.Children);
            tabs.Items.Add(new TabItem { Header = tab.Title, Content = sp });
        }
        _previewLines = null;
        if (tabs.Items.Count == 0) { canvas.Width = canvas.Height = 10; return; }

        Canvas.SetLeft(tabs, 12); Canvas.SetTop(tabs, 12);
        canvas.Children.Add(tabs);
        tabs.Measure(new Size(480, double.PositiveInfinity));
        canvas.Width = 480 + 30;
        canvas.Height = Math.Max(300, tabs.DesiredSize.Height + 40);
    }

    void BuildFlow(Panel host, IEnumerable<TplElement> children)
    {
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

            FrameworkElement content;
            switch (el.Kind)
            {
                case TplKind.Display:
                    var disp = new TextBlock { Text = el.Title.Length > 0 ? el.Title : " ",
                        Margin = new Thickness(0, 2, 0, 2), TextWrapping = TextWrapping.Wrap, IsHitTestVisible = false };
                    ApplyFont(disp, el); content = disp;
                    break;
                case TplKind.Image:
                    content = new TextBlock { Text = "🖼 " + el.Title, Margin = new Thickness(0, 2, 0, 2),
                        IsHitTestVisible = false, Foreground = new SolidColorBrush(Color.FromRgb(0x8A, 0x95, 0xA3)) };
                    break;
                case TplKind.Boxed:
                    var gb = new GroupBox { Header = el.Title, Margin = new Thickness(0, 4, 0, 4) };
                    var bi = new StackPanel(); BuildFlow(bi, el.Children); gb.Content = bi;
                    content = gb;
                    break;
                case TplKind.Enable:
                    BuildFlow(host, el.Children);   // conditional group, no visual of its own
                    continue;
                case TplKind.Button:
                    content = new Button { Content = el.Title, HorizontalAlignment = HorizontalAlignment.Left,
                        Padding = new Thickness(10, 2, 10, 2), Margin = new Thickness(0, 4, 0, 4), IsHitTestVisible = false };
                    break;
                case TplKind.Prompt:
                    if (u.StartsWith("OPTION"))
                    {
                        var og = new GroupBox { Header = el.Title, Margin = new Thickness(0, 4, 0, 4) };
                        var oi = new StackPanel(); og.Content = oi;
                        host.Children.Add(Selectable(og, el)); optionGroup = oi;
                        continue;
                    }
                    if (u == "CHECK")
                    {
                        var cb = new CheckBox { Content = el.Title, Margin = new Thickness(0, 3, 0, 3), IsHitTestVisible = false };
                        ApplyFont(cb, el); content = cb;
                    }
                    else content = BuildPromptRow(el, u);
                    break;
                default: continue;
            }
            host.Children.Add(Selectable(content, el));
        }
    }

    // Wrap a preview control so clicking it selects the element (Ctrl = add to selection), with a context menu.
    FrameworkElement Selectable(FrameworkElement content, TplElement el)
    {
        if (_previewPending)        // pending preview is read-only (its elements aren't the live model)
            return new Border { Child = content, Padding = new Thickness(1), BorderThickness = new Thickness(1),
                                BorderBrush = Brushes.Transparent };
        var b = new Border
        {
            Child = content,
            Background = Brushes.Transparent,
            BorderThickness = new Thickness(1),
            BorderBrush = _selection.Contains(el) ? new SolidColorBrush(Color.FromRgb(220, 70, 60)) : Brushes.Transparent,
            Padding = new Thickness(1),
            Tag = el,
            ContextMenu = BuildPreviewMenu(el)
        };
        b.MouseLeftButtonDown += PreviewElement_Down;
        return b;
    }

    void PreviewElement_Down(object s, MouseButtonEventArgs e)
    {
        if (((FrameworkElement)s).Tag is not TplElement el) return;
        if ((Keyboard.Modifiers & ModifierKeys.Control) != 0) ToggleSelect(el); else Select(el);
        Render();                 // rebuild the preview so the selection outline shows
        e.Handled = true;
    }

    ContextMenu BuildPreviewMenu(TplElement el)
    {
        var cm = new ContextMenu();
        cm.Items.Add(ZItem("Font && Colour…", () => EditFontDialog(el)));
        cm.Items.Add(new Separator());
        cm.Items.Add(ZItem("Delete", () => { if (!_selection.Contains(el)) Select(el); DeleteSelection(); }));
        return cm;
    }

    FrameworkElement BuildPromptRow(TplElement el, string u)
    {
        string def = PromptDefault(el);

        if (u.StartsWith("TEXT"))   // multiline: label then a tall box
        {
            var col = new StackPanel { Margin = new Thickness(0, 2, 0, 2) };
            var lab = new TextBlock { Text = el.Title }; ApplyFont(lab, el); col.Children.Add(lab);
            col.Children.Add(new TextBox { Text = def, AcceptsReturn = true, Height = 80, Width = 340, IsHitTestVisible = false,
                HorizontalAlignment = HorizontalAlignment.Left, VerticalScrollBarVisibility = ScrollBarVisibility.Auto });
            return col;
        }

        var g = new Grid { Margin = new Thickness(0, 1, 0, 1) };
        g.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(200) });
        g.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(140) });
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
        if (el.FontSize > 0) t.FontSize = Math.Max(8, el.FontSize);
        t.FontWeight = el.Bold ? FontWeights.Bold : FontWeights.Normal;
        if (el.FontColor is uint c) t.Foreground = FromColorRef(c);
    }
    static void ApplyFont(Control c, TplElement el)
    {
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
