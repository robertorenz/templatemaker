using System.Globalization;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Media;

namespace ClarionTplDesigner;

/// <summary>A simple pixel-per-DLU ruler with tick labels. Set Scale/Step and call InvalidateVisual.</summary>
public class RulerControl : FrameworkElement
{
    public Orientation Orientation { get; set; } = Orientation.Horizontal;
    public double Scale { get; set; } = 2.0;   // pixels per DLU
    public int Step { get; set; } = 10;        // DLU between labelled ticks
    public double Offset { get; set; }          // scroll offset in pixels
    public double MouseDlu { get; set; } = -1;  // live cursor marker (DLU), <0 hides

    static readonly Brush Bg = new SolidColorBrush(Color.FromRgb(244, 246, 249));
    static readonly Pen Tick = new(new SolidColorBrush(Color.FromRgb(170, 178, 190)), 1);
    static readonly Pen Minor = new(new SolidColorBrush(Color.FromRgb(212, 218, 226)), 1);
    static readonly Brush Text = new SolidColorBrush(Color.FromRgb(110, 120, 135));
    static readonly Pen CursorPen = new(new SolidColorBrush(Color.FromRgb(220, 70, 60)), 1);
    static readonly Typeface Tf = new("Segoe UI");

    static RulerControl()
    {
        Bg.Freeze(); Tick.Freeze(); Minor.Freeze(); Text.Freeze(); CursorPen.Freeze();
    }

    protected override void OnRender(DrawingContext dc)
    {
        bool h = Orientation == Orientation.Horizontal;
        double len = h ? ActualWidth : ActualHeight;
        double thick = h ? ActualHeight : ActualWidth;
        dc.DrawRectangle(Bg, null, new Rect(0, 0, ActualWidth, ActualHeight));

        for (int dlu = 0; dlu * Scale - Offset <= len; dlu += 5)
        {
            double p = dlu * Scale - Offset;
            if (p < -2) continue;
            bool major = dlu % Step == 0;
            var pen = major ? Tick : Minor;
            double t = major ? 7 : 4;
            if (h) dc.DrawLine(pen, new Point(p, thick - t), new Point(p, thick));
            else dc.DrawLine(pen, new Point(thick - t, p), new Point(thick, p));

            if (major && dlu > 0)
            {
                var ft = new FormattedText(dlu.ToString(), CultureInfo.InvariantCulture,
                    FlowDirection.LeftToRight, Tf, 8, Text, 1.0);
                if (h) dc.DrawText(ft, new Point(p + 1, 0));
                else dc.DrawText(ft, new Point(1, p));
            }
        }

        if (MouseDlu >= 0)
        {
            double p = MouseDlu * Scale - Offset;
            if (h) dc.DrawLine(CursorPen, new Point(p, 0), new Point(p, ActualHeight));
            else dc.DrawLine(CursorPen, new Point(0, p), new Point(ActualWidth, p));
        }
    }
}
