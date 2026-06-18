using System;

namespace ClarionTplDesigner;

/// <summary>
/// Approximate Clarion prompt-sheet layout: honours explicit AT(x,y); stacks the rest
/// top-to-bottom. Positions are stored on each element as LX/LY/LW/LH (DLU, tab-relative).
/// </summary>
public static class Layout
{
    const double Pad = 4, Gap = 3, Indent = 6;
    const double TabWidth = 480;

    public static void Run(TplElement tab) => LayoutContainer(tab, 0, 0, TabWidth);

    static double LayoutContainer(TplElement c, double ox, double oy, double width)
    {
        double cursor = oy + (c.Kind == TplKind.Tab ? 2 : Pad + 6); // box title eats a row
        double bottom = cursor;

        foreach (var ch in c.Children)
        {
            double w = ch.HasW && ch.W > 0 ? ch.W : DefaultW(ch, width);
            double h = ch.HasH && ch.H > 0 ? ch.H : DefaultH(ch);

            double x, y;
            if (ch.HasX && ch.HasY) { x = ox + ch.X; y = oy + ch.Y; }   // AT is frame-relative
            else { x = ox + Indent; y = cursor; cursor += h + Gap; }

            ch.LX = x; ch.LY = y; ch.LW = w; ch.LH = h;

            if (ch.IsContainer)
            {
                double consumed = LayoutContainer(ch, x, y, (w > 0 ? w : width) - Indent);
                if (!(ch.HasH && ch.H > 0)) ch.LH = Math.Max(h, consumed + Pad);
                cursor = Math.Max(cursor, y + ch.LH + Gap);
            }
            bottom = Math.Max(bottom, y + ch.LH);
        }
        return bottom - oy;
    }

    static double DefaultW(TplElement e, double width) => e.Kind switch
    {
        TplKind.Boxed => Math.Max(60, width - 12),
        TplKind.Button => Math.Max(60, width - 24),
        TplKind.Image => 14,
        TplKind.Display => 240,
        TplKind.Prompt => 220,
        _ => 120
    };

    static double DefaultH(TplElement e) => e.Kind switch
    {
        TplKind.Image => 14,
        TplKind.Boxed or TplKind.Button => 32,
        _ => 11
    };
}
