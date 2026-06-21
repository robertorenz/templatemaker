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
            if (ch.Deleted) continue;
            double w = ch.HasW && ch.W > 0 ? ch.W : DefaultW(ch, width);
            double h = ch.HasH && ch.H > 0 ? ch.H : DefaultH(ch);

            double x, y;
            if (ch.HasX && ch.HasY) { x = ox + ch.X; y = oy + ch.Y; }   // AT is frame-relative
            else
            {
                // Auto-flow. A side-label prompt's label is drawn to the LEFT of its entry, so reserve the
                // label-column width here — otherwise the entry sits at the indent and the label underflows
                // off the left of the frame (negative PLX, clipped into the margin).
                double labelW = HasSideLabel(ch) ? (ch.HasPW && ch.PW > 0 ? ch.PW : EstLabelW(ch)) : 0;
                x = ox + Indent + labelW; y = cursor; cursor += h + Gap;
            }

            ch.LX = x; ch.LY = y; ch.LW = w; ch.LH = h;
            LayoutPromptLabel(ch, ox, oy);

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

    // True for prompts that render a separate left-hand label + a right-hand entry (so PROMPTAT positions the
    // label independently of AT). CHECK/OPTION/RADIO carry their caption inline, so they have no side label.
    public static bool HasSideLabel(TplElement e)
    {
        if (e.Kind != TplKind.Prompt) return false;
        string pt = e.PromptType.Trim().ToUpperInvariant();
        return !(pt.StartsWith("CHECK") || pt.StartsWith("OPTION") || pt.StartsWith("RADIO"));
    }

    // Rough DLU width for a label from its text (no font metrics available here; the canvas auto-fits).
    public static double EstLabelW(TplElement e) => Math.Min(200, Math.Max(30, e.Title.Length * 4.0 + 8));

    // Compute the label rectangle (PLX/PLY/PLW/PLH) for a side-label prompt: from PROMPTAT if present, else
    // defaulted to sit immediately left of the entry (AT). ox,oy = the frame origin the entry was placed in.
    static void LayoutPromptLabel(TplElement ch, double ox, double oy)
    {
        if (!HasSideLabel(ch)) { ch.PLW = 0; return; }
        double plw = ch.HasPW && ch.PW > 0 ? ch.PW : EstLabelW(ch);
        double plh = ch.HasPH && ch.PH > 0 ? ch.PH : ch.LH;
        double plx, ply;
        if (ch.HasPromptAt)
        {
            plx = ch.HasPX ? ox + ch.PX : ch.LX - plw;
            ply = ch.HasPY ? oy + ch.PY : ch.LY;
        }
        else { plx = ch.LX - plw; ply = ch.LY; }   // no PROMPTAT yet: label immediately left of the entry
        ch.PLX = plx; ch.PLY = ply; ch.PLW = plw; ch.PLH = plh;
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
