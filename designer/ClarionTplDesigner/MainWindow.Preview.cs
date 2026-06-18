using System;
using System.Collections.Generic;
using System.Linq;
using System.Text.RegularExpressions;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Media;

namespace ClarionTplDesigner;

// "Flow preview" — renders the current part the way Clarion auto-lays a prompt window:
// real WPF controls stacked top-to-bottom (AT() ignored), with the caption / control / button
// columns. Modelled on the CapeSoft "clavte" template editor's previewer.
public partial class MainWindow
{
    bool _preview;

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

    void RenderPreview()
    {
        if (_component == null) { canvas.Width = canvas.Height = 10; return; }

        var tabs = new TabControl { Width = 480, BorderThickness = new Thickness(1), Background = Brushes.White };
        foreach (var tab in _component.Tabs)
        {
            var sp = new StackPanel { Margin = new Thickness(10) };
            BuildFlow(sp, tab.Children);
            tabs.Items.Add(new TabItem { Header = tab.Title, Content = sp });
        }
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
                var rb = new RadioButton { Content = el.Title, Margin = new Thickness(2, 2, 2, 2) };
                ApplyFont(rb, el); optionGroup.Children.Add(rb);
                continue;
            }

            if (!(el.Kind == TplKind.Prompt && u.StartsWith("OPTION"))) optionGroup = null;

            switch (el.Kind)
            {
                case TplKind.Display:
                    var disp = new TextBlock { Text = el.Title.Length > 0 ? el.Title : " ",
                        Margin = new Thickness(0, 2, 0, 2), TextWrapping = TextWrapping.Wrap };
                    ApplyFont(disp, el); host.Children.Add(disp);
                    break;
                case TplKind.Image:
                    host.Children.Add(new TextBlock { Text = "🖼 " + el.Title, Margin = new Thickness(0, 2, 0, 2),
                        Foreground = new SolidColorBrush(Color.FromRgb(0x8A, 0x95, 0xA3)) });
                    break;
                case TplKind.Boxed:
                    var gb = new GroupBox { Header = el.Title, Margin = new Thickness(0, 4, 0, 4) };
                    var bi = new StackPanel(); BuildFlow(bi, el.Children); gb.Content = bi;
                    host.Children.Add(gb);
                    break;
                case TplKind.Enable:
                    BuildFlow(host, el.Children);   // conditional group, no visual of its own
                    break;
                case TplKind.Button:
                    host.Children.Add(new Button { Content = el.Title, HorizontalAlignment = HorizontalAlignment.Left,
                        Padding = new Thickness(10, 2, 10, 2), Margin = new Thickness(0, 4, 0, 4) });
                    break;
                case TplKind.Prompt:
                    if (u.StartsWith("OPTION"))
                    {
                        var og = new GroupBox { Header = el.Title, Margin = new Thickness(0, 4, 0, 4) };
                        var oi = new StackPanel(); og.Content = oi; host.Children.Add(og); optionGroup = oi;
                    }
                    else if (u == "CHECK")
                    {
                        var cb = new CheckBox { Content = el.Title, Margin = new Thickness(0, 3, 0, 3) };
                        ApplyFont(cb, el); host.Children.Add(cb);
                    }
                    else host.Children.Add(BuildPromptRow(el, u));
                    break;
            }
        }
    }

    FrameworkElement BuildPromptRow(TplElement el, string u)
    {
        string def = PromptDefault(el);

        if (u.StartsWith("TEXT"))   // multiline: label then a tall box
        {
            var col = new StackPanel { Margin = new Thickness(0, 2, 0, 2) };
            var lab = new TextBlock { Text = el.Title }; ApplyFont(lab, el); col.Children.Add(lab);
            col.Children.Add(new TextBox { Text = def, AcceptsReturn = true, Height = 80, Width = 340,
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

        ctrl.Height = 22; ctrl.VerticalAlignment = VerticalAlignment.Center;
        Grid.SetColumn(ctrl, 1); g.Children.Add(ctrl);

        if (btn != null)
        {
            var b = new Button { Content = btn, Width = 24, Height = 22, Margin = new Thickness(2, 0, 0, 0) };
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
        var f = CurrentFile();
        if (f == null || el.LineIndex < 0 || el.LineIndex >= f.Lines.Length) return "";
        var line = f.Lines[el.LineIndex];
        var m = Regex.Match(line, @"\bdefault\s*\(\s*'([^']*)'", RegexOptions.IgnoreCase);
        if (m.Success) return m.Groups[1].Value;
        var m2 = Regex.Match(line, @"\bdefault\s*\(\s*([^)]*)\)", RegexOptions.IgnoreCase);
        return m2.Success ? m2.Groups[1].Value.Trim() : "";
    }

    IEnumerable<string> DropItems(TplElement el)
    {
        var f = CurrentFile();
        if (f == null || el.LineIndex < 0 || el.LineIndex >= f.Lines.Length) yield break;
        var m = Regex.Match(f.Lines[el.LineIndex], @"\bdrop\s*\(\s*'([^']*)'", RegexOptions.IgnoreCase);
        if (!m.Success) yield break;
        foreach (var part in m.Groups[1].Value.Split('|'))
        {
            int br = part.IndexOf('[');
            yield return (br >= 0 ? part[..br] : part).Trim();
        }
    }
}
