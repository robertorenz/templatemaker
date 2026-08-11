! ============================================================================
!  GraficaBarraClass - implementation. Thirteen chart types, pure Clarion,
!  drawn with BOX / LINE / POLYGON / ELLIPSE / PIE / SHOW so a report PDF
!  stays vector (small). All coordinates come from GETPOSITION of the target
!  control, so the same Paint serves windows (dialog units) and reports
!  (thousandths of an inch) - only the text cell metrics differ (cw/ch).
!  bare MEMBER + module MAP. Store this file in ANSI (not UTF-8), CRLF.
! ============================================================================
  MEMBER

  MAP
  END

  INCLUDE('GraficaBarraClass.INC'),ONCE

!=== construction / data ====================================================
GraficaBarraClass.Construct PROCEDURE()
i  LONG
  CODE
  SELF.ChartType = Chart:Column
  SELF.Title = ''
  SELF.ValueLabel = ''
  SELF.ShowValues = 1; SELF.ValueDP = 0
  SELF.ShowLabels = 1
  SELF.ShowScale = 1;  SELF.ScaleDP = 0
  SELF.ShowGrid = 1;   SELF.GridDivs = 5
  SELF.ShowAxis = 1
  SELF.ShowLegend = 1; SELF.LegendPos = Legend:Bottom
  SELF.ShowMarkers = 1; SELF.MarkerShape = Marker:Circle; SELF.MarkerSize = 0
  SELF.LineWidth = 2;  SELF.Smooth = 0
  SELF.Percent = 0
  SELF.ColorText = 1
  SELF.Depth3D = 0;    SELF.DonutPct = 55; SELF.DonutText = ''
  SELF.HoleColor = COLOR:None
  SELF.StartAngle = 0
  SELF.AutoScale = 1;  SELF.MinVal = 0; SELF.MaxVal = 0
  SELF.BarGapPct = 30
  SELF.TextW = 0; SELF.TextH = 0
  SELF.EraseFirst = 1                                        ! Paint wipes its own rectangle before drawing
  SELF.BackColor = COLOR:None
  SELF.PlotColor = COLOR:None
  SELF.AxisColor = 02B2B2Bh                                  ! near-black
  SELF.GridColor = 0E0E0E0h                                  ! light gray
  SELF.TextColor = 02B2B2Bh
  SELF.BarBorderColor = COLOR:None
  SELF.NBars = 0
  SELF.NSeries = 0
  LOOP i = 1 TO GraficaBarra:MaxSeries
    SELF.SeriesName[i] = ''
    SELF.SeriesColor[i] = COLOR:None
  END

GraficaBarraClass.ClearBars PROCEDURE()
s  LONG
i  LONG
  CODE
  SELF.NBars = 0
  LOOP i = 1 TO GraficaBarra:MaxBars                         ! wipe series 1 as well, so a later SetValue()
    SELF.BarLabel[i] = ''                                    ! cannot inherit a label or a color from the
    SELF.BarValue[i] = 0                                     ! chart that was in here before
    SELF.BarColor[i] = COLOR:None
  END
  LOOP s = 1 TO GraficaBarra:MaxSeries2                      ! the extra series share the categories
    LOOP i = 1 TO GraficaBarra:MaxBars
      SELF.SeriesValue[s,i] = 0
    END
  END

GraficaBarraClass.ClearAll PROCEDURE()
i  LONG
  CODE
  SELF.ClearBars()
  SELF.NSeries = 0
  LOOP i = 1 TO GraficaBarra:MaxSeries
    SELF.SeriesName[i] = ''
    SELF.SeriesColor[i] = COLOR:None
  END

GraficaBarraClass.AddBar PROCEDURE(STRING pLabel,REAL pValue,LONG pColor=-1)
  CODE
  IF SELF.NBars >= GraficaBarra:MaxBars THEN RETURN.
  SELF.NBars += 1
  SELF.BarLabel[SELF.NBars] = pLabel
  SELF.BarValue[SELF.NBars] = pValue
  SELF.BarColor[SELF.NBars] = pColor

GraficaBarraClass.AddSeries PROCEDURE(STRING pName,LONG pColor=-1)
  CODE
  IF SELF.NSeries >= GraficaBarra:MaxSeries THEN RETURN SELF.NSeries.
  SELF.NSeries += 1
  SELF.SeriesName[SELF.NSeries] = pName
  SELF.SeriesColor[SELF.NSeries] = pColor
  RETURN SELF.NSeries

GraficaBarraClass.AddCat PROCEDURE(STRING pLabel,REAL v1,REAL v2=0,REAL v3=0,REAL v4=0,REAL v5=0,REAL v6=0,REAL v7=0,REAL v8=0)
c  LONG
  CODE
  IF SELF.NBars >= GraficaBarra:MaxBars THEN RETURN.
  SELF.NBars += 1
  c = SELF.NBars
  SELF.BarLabel[c] = pLabel
  SELF.BarValue[c] = v1                                      ! series 1
  SELF.BarColor[c] = COLOR:None
  SELF.SeriesValue[1,c] = v2
  SELF.SeriesValue[2,c] = v3
  SELF.SeriesValue[3,c] = v4
  SELF.SeriesValue[4,c] = v5
  SELF.SeriesValue[5,c] = v6
  SELF.SeriesValue[6,c] = v7
  SELF.SeriesValue[7,c] = v8

GraficaBarraClass.SetValue PROCEDURE(LONG pSeries,LONG pCat,REAL pValue)
  CODE
  IF pCat < 1 OR pCat > GraficaBarra:MaxBars THEN RETURN.
  IF pSeries < 1 OR pSeries > GraficaBarra:MaxSeries THEN RETURN.
  IF pSeries > SELF.NSeries THEN SELF.NSeries = pSeries.
  IF pCat > SELF.NBars THEN SELF.NBars = pCat.
  IF pSeries = 1
    SELF.BarValue[pCat] = pValue
  ELSE
    SELF.SeriesValue[pSeries-1,pCat] = pValue
  END

GraficaBarraClass.GetValue PROCEDURE(LONG pSeries,LONG pCat)
  CODE
  IF pCat < 1 OR pCat > GraficaBarra:MaxBars THEN RETURN 0.
  IF pSeries < 1 OR pSeries > GraficaBarra:MaxSeries THEN RETURN 0.
  IF pSeries = 1 THEN RETURN SELF.BarValue[pCat].
  RETURN SELF.SeriesValue[pSeries-1,pCat]

GraficaBarraClass.SetRange PROCEDURE(REAL pMin,REAL pMax)
  CODE
  SELF.MinVal = pMin; SELF.MaxVal = pMax
  SELF.AutoScale = 0

GraficaBarraClass.Demo PROCEDURE()
  CODE
  SELF.ClearAll()
  CASE SELF.ChartType
  OF Chart:Pie OROF Chart:Pie3D OROF Chart:Donut                ! slices
    SELF.AddBar('Norte', 35)
    SELF.AddBar('Sur', 25)
    SELF.AddBar('Este', 20)
    SELF.AddBar('Oeste', 12)
    SELF.AddBar('Centro', 8)
  OF Chart:StackedCol OROF Chart:StackedBar OROF Chart:Stacked100 OROF Chart:StackedArea
    SELF.AddSeries('Norte')                                     ! three series over five months
    SELF.AddSeries('Sur')
    SELF.AddSeries('Centro')
    SELF.AddCat('Ene', 42, 28, 15)
    SELF.AddCat('Feb', 58, 33, 19)
    SELF.AddCat('Mar', 35, 25, 12)
    SELF.AddCat('Abr', 71, 40, 22)
    SELF.AddCat('May', 64, 36, 26)
  ELSE                                                          ! six plain bars / points (v1 behaviour)
    SELF.AddBar('Ene', 42)
    SELF.AddBar('Feb', 58)
    SELF.AddBar('Mar', 35)
    SELF.AddBar('Abr', 71)
    SELF.AddBar('May', 64)
    SELF.AddBar('Jun', 89)
  END

!=== small helpers ==========================================================
GraficaBarraClass.NiceMax PROCEDURE(REAL v)
m  REAL
f  REAL
  CODE
  IF v <= 0 THEN RETURN 1.
  m = 10 ^ INT(LOG10(v))
  IF m > v THEN m = m / 10.                                  ! guard rounding on exact powers
  f = v / m
  IF f <= 1 THEN RETURN m.
  IF f <= 2 THEN RETURN 2 * m.
  IF f <= 5 THEN RETURN 5 * m.
  RETURN 10 * m

GraficaBarraClass.Palette PROCEDURE(LONG i)
k  LONG
  CODE
  k = i - INT((i - 1) / 12) * 12                              ! cycle 1..12, no modulus operator
  CASE k
  OF 1;  RETURN 0B6752Eh                                      ! steel blue
  OF 2;  RETURN 0A4A62Ch                                      ! teal
  OF 3;  RETURN 03DA3E8h                                      ! amber
  OF 4;  RETURN 0794E1Fh                                      ! deep navy
  OF 5;  RETURN 04E996Ah                                      ! sage green
  OF 6;  RETURN 04657C0h                                      ! terracotta
  OF 7;  RETURN 08B7464h                                      ! slate gray
  OF 8;  RETURN 0B1A59Ah                                      ! cool gray
  OF 9;  RETURN 01E69D2h                                      ! burnt orange
  OF 10; RETURN 02626A6h                                      ! deep red
  OF 11; RETURN 03F8C7Fh                                      ! olive
  END
  RETURN 0D59B5Bh                                             ! sky blue

GraficaBarraClass.FmtNum PROCEDURE(REAL v,LONG dp)
pic  CSTRING(16)
  CODE
  IF dp > 0
    pic = '@n-13.' & dp
  ELSE
    pic = '@n-13'
  END
  RETURN CLIP(LEFT(FORMAT(v, pic)))

GraficaBarraClass.SeriesCount PROCEDURE()
  CODE
  IF SELF.NSeries < 1 THEN RETURN 1.
  IF SELF.NSeries > GraficaBarra:MaxSeries THEN RETURN GraficaBarra:MaxSeries.
  RETURN SELF.NSeries

GraficaBarraClass.IsStacked PROCEDURE()
  CODE
  CASE SELF.ChartType
  OF Chart:StackedCol OROF Chart:StackedBar OROF Chart:Stacked100 OROF Chart:StackedArea
    RETURN 1
  END
  RETURN 0

GraficaBarraClass.IsHorizontal PROCEDURE()
  CODE
  IF SELF.ChartType = Chart:Bar OR SELF.ChartType = Chart:StackedBar THEN RETURN 1.
  RETURN 0

GraficaBarraClass.IsPie PROCEDURE()
  CODE
  CASE SELF.ChartType
  OF Chart:Pie OROF Chart:Pie3D OROF Chart:Donut
    RETURN 1
  END
  RETURN 0

GraficaBarraClass.ColorOf PROCEDURE(LONG pSeries,LONG pCat)
c  LONG
  CODE
  IF SELF.IsPie() OR SELF.SeriesCount() = 1                   ! one series: a color per category
    IF pCat > 0 AND pCat <= GraficaBarra:MaxBars
      c = SELF.BarColor[pCat]
      IF c <> COLOR:None THEN RETURN c.
    END
    RETURN SELF.Palette(pCat)
  END
  IF pSeries > 0 AND pSeries <= GraficaBarra:MaxSeries         ! several series: a color per series
    c = SELF.SeriesColor[pSeries]
    IF c <> COLOR:None THEN RETURN c.
  END
  RETURN SELF.Palette(pSeries)

GraficaBarraClass.StackSum PROCEDURE(LONG pCat,BYTE pPositive)
s  LONG
v  REAL
t  REAL
  CODE
  t = 0
  LOOP s = 1 TO SELF.SeriesCount()
    v = SELF.GetValue(s, pCat)
    IF pPositive = 1
      IF v > 0 THEN t += v.
    ELSE
      IF v < 0 THEN t += v.
    END
  END
  RETURN t

GraficaBarraClass.CatTotal PROCEDURE(LONG pCat)
s  LONG
t  REAL
  CODE
  t = 0
  LOOP s = 1 TO SELF.SeriesCount()
    t += ABS(SELF.GetValue(s, pCat))
  END
  RETURN t

!=== drawing primitives =====================================================
GraficaBarraClass.TextAt PROCEDURE(LONG px,LONG py,STRING pTxt,LONG pColor)
  CODE
  IF SELF.ColorText = 1 AND SELF.zFont                       ! SHOW takes its color from the CURRENT TARGET's font
    SETFONT(0, SELF.zFont, SELF.zFSize, pColor, SELF.zFStyle, SELF.zFChar)   ! (0 = the target itself). Neither
  ELSE                                                       ! SETPENCOLOR nor SETFONT(controlfeq) colors SHOW.
    SETPENCOLOR(pColor)
  END
  SELF.zLastColor = pColor
  SHOW(px, py, CLIP(pTxt))

GraficaBarraClass.TextMid PROCEDURE(LONG px,LONG py,STRING pTxt,LONG pColor)
  CODE
  SELF.TextAt(px - INT(LEN(CLIP(pTxt)) * SELF.zCW / 2), py, pTxt, pColor)

GraficaBarraClass.FillBox PROCEDURE(LONG px,LONG py,LONG pw,LONG ph,LONG pColor)
  CODE
  IF pw < 1 OR ph < 1 THEN RETURN.
  SETPENWIDTH(SELF.zSc)
  IF SELF.BarBorderColor <> COLOR:None                       ! BOX outlines with the CURRENT pen - always set it
    SETPENCOLOR(SELF.BarBorderColor)
  ELSE
    SETPENCOLOR(pColor)
  END
  BOX(px, py, pw, ph, pColor)

GraficaBarraClass.Marker PROCEDURE(LONG px,LONG py,LONG pColor)
sz  LONG
hf  LONG
  CODE
  IF SELF.MarkerSize > 0
    sz = SELF.MarkerSize
  ELSE
    sz = INT(SELF.zCH * 3 / 4)
  END
  IF sz < 2 THEN sz = 2.
  hf = INT(sz / 2)
  SETPENWIDTH(SELF.zSc)
  SETPENCOLOR(pColor)
  CASE SELF.MarkerShape
  OF Marker:Square
    BOX(px - hf, py - hf, sz, sz, pColor)
  OF Marker:Diamond
    SELF.PolyStart()
    SELF.PolyAdd(px, py - hf)
    SELF.PolyAdd(px + hf, py)
    SELF.PolyAdd(px, py + hf)
    SELF.PolyAdd(px - hf, py)
    SELF.PolyDraw(pColor)
  ELSE
    ELLIPSE(px - hf, py - hf, sz, sz, pColor)
  END

GraficaBarraClass.PolyStart PROCEDURE()
  CODE
  SELF.zNPoly = 0

GraficaBarraClass.PolyAdd PROCEDURE(LONG px,LONG py)
  CODE
  IF SELF.zNPoly + 2 > GraficaBarra:MaxPoly THEN RETURN.
  SELF.zNPoly += 1; SELF.zPoly[SELF.zNPoly] = px
  SELF.zNPoly += 1; SELF.zPoly[SELF.zNPoly] = py

GraficaBarraClass.PolyDraw PROCEDURE(LONG pFill)
i   LONG
lx  LONG
ly  LONG
  CODE
  IF SELF.zNPoly < 6 THEN RETURN.                            ! three corners minimum
  lx = SELF.zPoly[SELF.zNPoly-1]                             ! POLYGON uses EVERY element of the array,
  ly = SELF.zPoly[SELF.zNPoly]                               ! so pad the tail with the last corner
  LOOP i = SELF.zNPoly + 1 TO GraficaBarra:MaxPoly BY 2      ! (zero-length edges, invisible)
    SELF.zPoly[i] = lx
    SELF.zPoly[i+1] = ly
  END
  POLYGON(SELF.zPoly, pFill)

GraficaBarraClass.VY PROCEDURE(REAL v)
  CODE
  IF SELF.zHi <= SELF.zLo THEN RETURN SELF.zPY + SELF.zPH.
  IF v < SELF.zLo THEN v = SELF.zLo.
  IF v > SELF.zHi THEN v = SELF.zHi.
  RETURN SELF.zPY + SELF.zPH - INT(SELF.zPH * (v - SELF.zLo) / (SELF.zHi - SELF.zLo))

GraficaBarraClass.VX PROCEDURE(REAL v)
  CODE
  IF SELF.zHi <= SELF.zLo THEN RETURN SELF.zPX.
  IF v < SELF.zLo THEN v = SELF.zLo.
  IF v > SELF.zHi THEN v = SELF.zHi.
  RETURN SELF.zPX + INT(SELF.zPW * (v - SELF.zLo) / (SELF.zHi - SELF.zLo))

!=== Paint - set the stage, then hand over to the right painter =============
GraficaBarraClass.Paint PROCEDURE(SIGNED pFeq,BYTE pWindowMode=0)
x      LONG
y      LONG
w      LONG
h      LONG
i      LONG
k      LONG
nitem  LONG
useCat BYTE
maxlen LONG
totw   LONG
avail  LONG
rows   LONG
dummy  LONG
saved  LONG
ex     LONG
ey     LONG
txt    STRING(64)
  CODE
  GETPOSITION(pFeq, x, y, w, h)
  SELF.zFeq = pFeq
  SELF.zWin = pWindowMode
  ! ---- text metrics: dialog units on a window, 1/1000 inch on a report ----
  IF SELF.TextW > 0
    SELF.zCW = SELF.TextW
  ELSIF pWindowMode
    SELF.zCW = 4                                             ! a dialog unit is 1/4 of a char cell
  ELSE
    SELF.zCW = 62                                            ! 9pt on a THOUS report: ~0.062 inch
  END
  IF SELF.TextH > 0
    SELF.zCH = SELF.TextH
  ELSIF pWindowMode
    SELF.zCH = 9
  ELSE
    SELF.zCH = 130
  END
  SELF.zPad = INT(SELF.zCH / 4); IF SELF.zPad < 1 THEN SELF.zPad = 1.
  SELF.zSc = INT(SELF.zCH / 9);  IF SELF.zSc < 1 THEN SELF.zSc = 1.
  ! ---- wipe what was here before -----------------------------------------
  !  A window IMAGE is its own canvas, so BLANK clears the lot. A report BAND
  !  is not: it keeps every primitive ever drawn into it, so painting a second
  !  chart over the same placeholder lands ON TOP of the first - ClearAll()
  !  throws the data away, never the ink. Clear just this chart's rectangle,
  !  with a pad of bleed because a real font descender can sit a hair below
  !  the cell height assumed above.
  IF pWindowMode
    IF SELF.EraseFirst = 1 THEN BLANK.
    x = 0; y = 0                                             ! the IMAGE is the target: its origin is 0,0
  ELSIF SELF.EraseFirst = 1
    ex = x - SELF.zPad; IF ex < 0 THEN ex = 0.               ! never reach outside the band
    ey = y - SELF.zPad; IF ey < 0 THEN ey = 0.
    BLANK(ex, ey, x + w + SELF.zPad - ex, y + h + SELF.zPad - ey)
  END
  SELF.zX = x; SELF.zY = y; SELF.zW = w; SELF.zH = h
  ! ---- remember the target's own font so text can be re-colored ----
  SELF.zFont = ''; SELF.zFSize = 0; SELF.zFStyle = 0; SELF.zFChar = 0
  dummy = 0
  IF SELF.ColorText = 1
    GETFONT(0, SELF.zFont, SELF.zFSize, dummy, SELF.zFStyle, SELF.zFChar)
  END
  SELF.zLastColor = -2                                       ! nothing set yet
  SETPENWIDTH(SELF.zSc)
  SETPENSTYLE()
  ! ---- backgrounds ----
  IF SELF.BackColor <> COLOR:None
    SETPENCOLOR(SELF.BackColor)
    BOX(x, y, w, h, SELF.BackColor)
  END
  ! ---- title ----
  IF SELF.Title
    SELF.TextMid(x + INT(w/2), y + SELF.zPad, CLIP(SELF.Title), SELF.TextColor)
  END
  ! ---- how much room does the legend want? ----
  SELF.zLegW = 0; SELF.zLegH = 0
  IF SELF.ShowLegend = 1
    ! useCat=1: one row per bar/category, "label  value" (or "label  ValueLabel = value") - what a pie
    ! always did, and now also what a single-series bar/line/area gets (it had no legend at all before).
    ! useCat=0: unchanged - one row per series name, for genuine multi-series charts.
    IF SELF.IsPie()
      nitem = SELF.NBars; useCat = 1
    ELSIF SELF.SeriesCount() > 1
      nitem = SELF.SeriesCount(); useCat = 0
    ELSIF SELF.NBars > 1
      nitem = SELF.NBars; useCat = 1
    ELSE
      nitem = 0; useCat = 0
    END
    IF nitem > 0
      maxlen = 0; totw = 0
      LOOP i = 1 TO nitem
        IF useCat = 1
          IF SELF.ValueLabel
            txt = CLIP(SELF.BarLabel[i]) & '   ' & CLIP(SELF.ValueLabel) & ' = ' & CLIP(SELF.FmtNum(SELF.BarValue[i],SELF.ValueDP))
          ELSE
            txt = CLIP(SELF.BarLabel[i]) & '  ' & CLIP(SELF.FmtNum(SELF.BarValue[i],SELF.ValueDP))
          END
        ELSE
          txt = SELF.SeriesName[i]
        END
        k = LEN(CLIP(txt)); IF k < 1 THEN k = 1.
        IF k > maxlen THEN maxlen = k.
        totw += CHOOSE(useCat=1,5,0) * SELF.zCW + SELF.zCH + SELF.zPad + k * SELF.zCW + 2 * SELF.zCW  ! +"100% " if useCat
      END
      IF SELF.LegendPos = Legend:Right
        SELF.zLegW = CHOOSE(useCat=1,5,0) * SELF.zCW + SELF.zCH + SELF.zPad + maxlen * SELF.zCW + 3 * SELF.zCW
        IF SELF.zLegW > INT(w * 2 / 5) THEN SELF.zLegW = INT(w * 2 / 5).
      ELSE
        avail = w - 2 * SELF.zPad
        rows = 1
        IF avail > 0 AND totw > avail THEN rows = INT(totw / avail) + 1.
        IF rows > 3 THEN rows = 3.
        SELF.zLegH = rows * (SELF.zCH + SELF.zPad) + SELF.zPad
      END
    END
  END
  ! ---- content rectangle: what is left for the chart itself ----
  SELF.zPX = x + SELF.zPad
  SELF.zPY = y + SELF.zPad
  SELF.zPW = w - 2 * SELF.zPad
  SELF.zPH = h - 2 * SELF.zPad
  IF SELF.Title
    SELF.zPY += SELF.zCH + SELF.zPad
    SELF.zPH -= SELF.zCH + SELF.zPad
  END
  CASE SELF.LegendPos
  OF Legend:Right
    SELF.zPW -= SELF.zLegW
  OF Legend:Top
    SELF.zPY += SELF.zLegH
    SELF.zPH -= SELF.zLegH
  ELSE
    SELF.zPH -= SELF.zLegH
  END
  IF SELF.zPW < 8 OR SELF.zPH < 8 THEN RETURN.
  ! ---- over to the painter for this chart type ----
  IF SELF.IsPie()
    SELF.PaintPie()
  ELSIF SELF.ChartType = Chart:Radar
    IF SELF.NBars < 3                                        ! a web needs three axes - fall back to a line
      saved = SELF.ChartType
      SELF.ChartType = Chart:Line
      SELF.PaintCartesian()
      SELF.ChartType = saved
    ELSE
      SELF.PaintRadar()
    END
  ELSE
    SELF.PaintCartesian()
  END
  SELF.PaintLegend()
  IF SELF.ColorText = 1 AND SELF.zFont                       ! hand the target back the font color it came with
    SETFONT(0, SELF.zFont, SELF.zFSize, dummy, SELF.zFStyle, SELF.zFChar)
  END

GraficaBarraClass.Draw PROCEDURE(WINDOW pWin,SIGNED pImageFeq)
  CODE
  SETTARGET(pWin, pImageFeq)                                 ! the IMAGE is the target: 0,0 = its top-left, and
  SELF.Paint(pImageFeq, 1)                                   ! the graphics belong to the image so they survive a
  SETTARGET()                                                ! repaint / resize (a window-layer draw gets wiped)

!=== bars, lines, areas: everything with a value axis =======================
GraficaBarraClass.PaintCartesian PROCEDURE()
i     LONG
s     LONG
n     LONG
ns    LONG
ml    LONG
mr    LONG
mt    LONG
mb    LONG
lw    LONG
vw    LONG
labw  LONG
step  LONG
maxc  LONG
stp   REAL
dmin  REAL
dmax  REAL
v     REAL
slot  REAL
txt   STRING(64)
  CODE
  n = SELF.NBars
  ns = SELF.SeriesCount()
  ! ---- value axis range ----
  SELF.zLo = SELF.MinVal; SELF.zHi = SELF.MaxVal
  IF SELF.ChartType = Chart:Stacked100
    SELF.zLo = 0; SELF.zHi = 100
  ELSIF SELF.AutoScale = 1
    dmin = 0; dmax = 0
    IF SELF.IsStacked()
      LOOP i = 1 TO n
        v = SELF.StackSum(i, 1); IF v > dmax THEN dmax = v.
        v = SELF.StackSum(i, 0); IF v < dmin THEN dmin = v.
      END
    ELSE
      LOOP i = 1 TO n
        LOOP s = 1 TO ns
          v = SELF.GetValue(s, i)
          IF v < dmin THEN dmin = v.
          IF v > dmax THEN dmax = v.
        END
      END
    END
    IF dmax > 0 THEN SELF.zHi = SELF.NiceMax(dmax) ELSE SELF.zHi = 0.
    IF dmin < 0 THEN SELF.zLo = -SELF.NiceMax(-dmin) ELSE SELF.zLo = 0.
  END
  IF SELF.zHi <= SELF.zLo THEN SELF.zHi = SELF.zLo + 1.
  IF SELF.GridDivs < 1 THEN SELF.GridDivs = 1.
  SELF.zDivs = SELF.GridDivs
  IF SELF.zLo < 0 AND SELF.zHi > 0                           ! both signs: put ZERO on a gridline by
    stp = SELF.NiceMax((SELF.zHi - SELF.zLo) / SELF.GridDivs) ! stepping in nice units from zero out
    IF stp > 0
      SELF.zHi = stp * INT((SELF.zHi - 0.000001) / stp + 1)
      SELF.zLo = -stp * INT((-SELF.zLo - 0.000001) / stp + 1)
      SELF.zDivs = INT((SELF.zHi - SELF.zLo) / stp + 0.5)
      IF SELF.zDivs < 1 THEN SELF.zDivs = 1.
    END
  END
  ! ---- room for the axis furniture, inside the content rectangle ----
  lw = 0
  IF SELF.ShowScale = 1
    lw = LEN(SELF.FmtNum(SELF.zHi, SELF.ScaleDP))
    i = LEN(SELF.FmtNum(SELF.zLo, SELF.ScaleDP))
    IF i > lw THEN lw = i.
  END
  vw = LEN(SELF.FmtNum(SELF.zHi, SELF.ValueDP))
  labw = 0
  IF SELF.ShowLabels = 1
    LOOP i = 1 TO n
      IF LEN(CLIP(SELF.BarLabel[i])) > labw THEN labw = LEN(CLIP(SELF.BarLabel[i])).
    END
  END
  ml = 0; mr = 2 * SELF.zCW; mt = 0; mb = 0
  IF SELF.IsHorizontal()
    IF SELF.ShowLabels = 1 THEN ml = labw * SELF.zCW + SELF.zPad.
    IF SELF.ShowScale = 1 THEN mb = SELF.zCH + SELF.zPad.
    IF SELF.ShowValues = 1 THEN mr = (vw + 1) * SELF.zCW.
  ELSE
    IF SELF.ShowScale = 1 THEN ml = lw * SELF.zCW + SELF.zPad.
    IF SELF.ShowLabels = 1 THEN mb = SELF.zCH + SELF.zPad.
    IF SELF.ShowValues = 1 THEN mt = SELF.zCH + SELF.zPad.
  END
  SELF.zPX += ml; SELF.zPY += mt
  SELF.zPW -= ml + mr; SELF.zPH -= mt + mb
  IF SELF.zPW < 8 OR SELF.zPH < 8 THEN RETURN.
  ! ---- plot background ----
  IF SELF.PlotColor <> COLOR:None
    SETPENWIDTH(SELF.zSc); SETPENCOLOR(SELF.PlotColor)
    BOX(SELF.zPX, SELF.zPY, SELF.zPW, SELF.zPH, SELF.PlotColor)
  END
  ! ---- where is zero? ----
  IF SELF.zLo < 0 AND SELF.zHi > 0
    SELF.zZY = SELF.VY(0)
    SELF.zZX = SELF.VX(0)
  ELSIF SELF.zLo >= 0
    SELF.zZY = SELF.zPY + SELF.zPH                           ! all positive: baseline at the bottom / left
    SELF.zZX = SELF.zPX
  ELSE
    SELF.zZY = SELF.zPY                                      ! all negative: baseline at the top / right
    SELF.zZX = SELF.zPX + SELF.zPW
  END
  SELF.PaintGrid()
  ! ---- the data ----
  IF n > 0
    CASE SELF.ChartType
    OF Chart:StackedCol OROF Chart:StackedBar OROF Chart:Stacked100
      SELF.PaintStack()
    OF Chart:Area OROF Chart:StackedArea
      SELF.PaintArea()
    OF Chart:Line OROF Chart:Scatter
      LOOP s = 1 TO ns
        SELF.PaintLine(s)
      END
    ELSE
      SELF.PaintBars()
    END
  END
  ! ---- axis on top of the data ----
  IF SELF.ShowAxis = 1
    SETPENWIDTH(SELF.zSc); SETPENCOLOR(SELF.AxisColor)
    IF SELF.IsHorizontal()
      LINE(SELF.zPX, SELF.zPY + SELF.zPH, SELF.zPW, 0)       ! value axis (bottom)
      LINE(SELF.zZX, SELF.zPY, 0, SELF.zPH)                  ! zero baseline
    ELSE
      LINE(SELF.zPX, SELF.zPY, 0, SELF.zPH)                  ! value axis (left)
      LINE(SELF.zPX, SELF.zZY, SELF.zPW, 0)                  ! zero baseline
    END
  END
  ! ---- category labels ----
  IF SELF.ShowLabels = 1 AND n > 0
    IF SELF.IsHorizontal()
      slot = SELF.zPH / n
      step = 1
      LOOP WHILE slot * step < SELF.zCH AND step < n
        step += 1
      END
      LOOP i = 1 TO n
        IF INT((i-1)/step) * step <> i - 1 THEN CYCLE.
        txt = CLIP(SELF.BarLabel[i])
        IF SELF.zCW > 0 AND LEN(txt) * SELF.zCW > ml - SELF.zPad     ! safety: never overrun into the plot area
          txt = txt[1 : INT((ml - SELF.zPad) / SELF.zCW)]            ! if the real font renders wider than estimated
        END
        SELF.TextAt(SELF.zX + SELF.zPad, |                           ! left-aligned, flush against the window edge
                    INT(SELF.zPY + slot * (i - 0.5) - SELF.zCH / 2), txt, SELF.TextColor)
      END
    ELSE
      slot = SELF.zPW / n
      step = 1
      LOOP WHILE (labw + 1) * SELF.zCW > slot * step AND step < n
        step += 1
      END
      maxc = INT(slot * step / SELF.zCW); IF maxc < 1 THEN maxc = 1.
      LOOP i = 1 TO n
        IF INT((i-1)/step) * step <> i - 1 THEN CYCLE.
        txt = CLIP(SELF.BarLabel[i])
        IF LEN(CLIP(txt)) > maxc THEN txt = SUB(txt, 1, maxc).
        SELF.TextMid(INT(SELF.zPX + slot * (i - 0.5)), SELF.zPY + SELF.zPH + SELF.zPad, |
                     txt, SELF.TextColor)
      END
    END
  END

GraficaBarraClass.PaintGrid PROCEDURE()
i    LONG
gy   LONG
gx   LONG
v    REAL
txt  STRING(64)
  CODE
  IF SELF.zDivs < 1 THEN SELF.zDivs = 1.
  LOOP i = 0 TO SELF.zDivs
    v = SELF.zLo + (SELF.zHi - SELF.zLo) * i / SELF.zDivs
    IF SELF.IsHorizontal()
      gx = SELF.VX(v)
      IF SELF.ShowGrid = 1 AND i > 0
        SETPENWIDTH(SELF.zSc); SETPENCOLOR(SELF.GridColor)
        LINE(gx, SELF.zPY, 0, SELF.zPH)
      END
      IF SELF.ShowScale = 1
        txt = SELF.FmtNum(v, SELF.ScaleDP)
        SELF.TextMid(gx, SELF.zPY + SELF.zPH + SELF.zPad, txt, SELF.TextColor)
      END
    ELSE
      gy = SELF.VY(v)
      IF SELF.ShowGrid = 1 AND i > 0
        SETPENWIDTH(SELF.zSc); SETPENCOLOR(SELF.GridColor)
        LINE(SELF.zPX, gy, SELF.zPW, 0)
      END
      IF SELF.ShowScale = 1
        txt = SELF.FmtNum(v, SELF.ScaleDP)
        SELF.TextAt(SELF.zPX - SELF.zPad - LEN(CLIP(txt)) * SELF.zCW, gy - INT(SELF.zCH/2), |
                    txt, SELF.TextColor)
      END
    END
  END

GraficaBarraClass.PaintBars PROCEDURE()
i     LONG
s     LONG
n     LONG
ns    LONG
bx    LONG
ry    LONG
bw    LONG
bh    LONG
bt    LONG
gp    LONG
c     LONG
tx    LONG
ty    LONG
slot  REAL
gap   REAL
band  REAL
one   REAL
v     REAL
tot   REAL
txt   STRING(64)
  CODE
  n = SELF.NBars
  ns = SELF.SeriesCount()
  tot = 0
  IF SELF.Percent = 1                                        ! % of the sum of every bar/series on screen
    LOOP i = 1 TO n
      LOOP s = 1 TO ns
        tot += ABS(SELF.GetValue(s, i))
      END
    END
    IF tot <= 0 THEN tot = 1.
  END
  IF SELF.IsHorizontal()
    slot = SELF.zPH / n
  ELSE
    slot = SELF.zPW / n
  END
  gap = slot * SELF.BarGapPct / 200                          ! half the gap each side of a slot
  band = slot - 2 * gap; IF band < 1 THEN band = 1.
  one = band / ns                                            ! one series' bar inside the slot
  LOOP i = 1 TO n
    LOOP s = 1 TO ns
      v = SELF.GetValue(s, i)
      c = SELF.ColorOf(s, i)
      IF SELF.Percent = 1
        txt = SELF.FmtNum(100 * ABS(v) / tot, SELF.ValueDP) & '%'
      ELSE
        txt = SELF.FmtNum(v, SELF.ValueDP)
      END
      IF SELF.IsHorizontal()
        ry = INT(SELF.zPY + slot * (i-1) + gap + one * (s-1))
        bh = INT(one); IF bh < 1 THEN bh = 1.
        gp = SELF.VX(v)
        IF gp >= SELF.zZX
          bx = SELF.zZX; bw = gp - SELF.zZX
        ELSE
          bx = gp; bw = SELF.zZX - gp
        END
        IF bw < 1 THEN bw = 1.
        SELF.FillBox(bx, ry, bw, bh, c)
        IF SELF.ShowValues = 1 AND bh >= SELF.zCH
          IF SELF.Percent = 1
            IF bw >= (LEN(CLIP(txt))+1) * SELF.zCW            ! only if the % fits inside the bar itself
              tx = bx + INT(bw/2) - INT(LEN(CLIP(txt)) * SELF.zCW / 2)
              SELF.TextAt(tx, ry + INT(bh/2) - INT(SELF.zCH/2), txt, SELF.TextColor)
            END
          ELSE
            IF v >= 0
              tx = bx + bw + INT(SELF.zPad/2)
            ELSE
              tx = bx - INT(SELF.zPad/2) - LEN(CLIP(txt)) * SELF.zCW
            END
            SELF.TextAt(tx, ry + INT(bh/2) - INT(SELF.zCH/2), txt, SELF.TextColor)
          END
        END
      ELSE
        bx = INT(SELF.zPX + slot * (i-1) + gap + one * (s-1))
        bw = INT(one); IF bw < 1 THEN bw = 1.
        gp = SELF.VY(v)
        IF gp <= SELF.zZY
          bt = gp; bh = SELF.zZY - gp
        ELSE
          bt = SELF.zZY; bh = gp - SELF.zZY
        END
        IF bh < 1 THEN bh = 1.
        SELF.FillBox(bx, bt, bw, bh, c)
        IF SELF.ShowValues = 1
          IF SELF.Percent = 1
            IF bh >= SELF.zCH AND bw + SELF.zCW >= LEN(CLIP(txt)) * SELF.zCW   ! only if the % fits inside the bar
              SELF.TextMid(bx + INT(bw/2), bt + INT(bh/2) - INT(SELF.zCH/2), txt, SELF.TextColor)
            END
          ELSE
            IF bw + SELF.zCW >= LEN(CLIP(txt)) * SELF.zCW      ! only if it fits over the bar
              IF v >= 0
                ty = bt - SELF.zCH - INT(SELF.zPad/2)
              ELSE
                ty = bt + bh + INT(SELF.zPad/2)
              END
              SELF.TextMid(bx + INT(bw/2), ty, txt, SELF.TextColor)
            END
          END
        END
      END
    END
  END

GraficaBarraClass.PaintStack PROCEDURE()
i     LONG
s     LONG
n     LONG
ns    LONG
a     LONG
b     LONG
bx    LONG
ry    LONG
bw    LONG
bh    LONG
c     LONG
slot  REAL
gap   REAL
band  REAL
v     REAL
pacc  REAL
nacc  REAL
frm   REAL
tot   REAL
totl  REAL
txt   STRING(64)
  CODE
  n = SELF.NBars
  ns = SELF.SeriesCount()
  IF SELF.IsHorizontal()
    slot = SELF.zPH / n
  ELSE
    slot = SELF.zPW / n
  END
  gap = slot * SELF.BarGapPct / 200
  band = slot - 2 * gap; IF band < 1 THEN band = 1.
  LOOP i = 1 TO n
    totl = SELF.CatTotal(i)
    IF SELF.ChartType = Chart:Stacked100 AND totl = 0 THEN CYCLE.
    pacc = 0; nacc = 0
    LOOP s = 1 TO ns
      v = SELF.GetValue(s, i)
      IF SELF.ChartType = Chart:Stacked100
        v = 100 * ABS(v) / totl                              ! every segment positive, the stack fills 100
      END
      IF v = 0 THEN CYCLE.
      IF v > 0
        frm = pacc; tot = pacc + v; pacc = tot
      ELSE
        frm = nacc; tot = nacc + v; nacc = tot
      END
      c = SELF.ColorOf(s, i)
      IF SELF.IsHorizontal()
        ry = INT(SELF.zPY + slot * (i-1) + gap)
        bh = INT(band); IF bh < 1 THEN bh = 1.
        a = SELF.VX(frm); b = SELF.VX(tot)
        IF b >= a
          bx = a; bw = b - a
        ELSE
          bx = b; bw = a - b
        END
        IF bw < 1 THEN CYCLE.
        SELF.FillBox(bx, ry, bw, bh, c)
        IF SELF.ShowValues = 1
          txt = SELF.FmtNum(v, SELF.ValueDP)
          IF bw >= (LEN(CLIP(txt)) + 1) * SELF.zCW AND bh >= SELF.zCH
            SELF.TextMid(bx + INT(bw/2), ry + INT(bh/2) - INT(SELF.zCH/2), txt, SELF.TextColor)
          END
        END
      ELSE
        bx = INT(SELF.zPX + slot * (i-1) + gap)
        bw = INT(band); IF bw < 1 THEN bw = 1.
        a = SELF.VY(frm); b = SELF.VY(tot)
        IF b <= a
          ry = b; bh = a - b
        ELSE
          ry = a; bh = b - a
        END
        IF bh < 1 THEN CYCLE.
        SELF.FillBox(bx, ry, bw, bh, c)
        IF SELF.ShowValues = 1
          txt = SELF.FmtNum(v, SELF.ValueDP)
          IF bh >= SELF.zCH + 2 AND bw >= (LEN(CLIP(txt)) + 1) * SELF.zCW
            SELF.TextMid(bx + INT(bw/2), ry + INT(bh/2) - INT(SELF.zCH/2), txt, SELF.TextColor)
          END
        END
      END
    END
  END

GraficaBarraClass.PaintLine PROCEDURE(LONG pSeries)
i     LONG
n     LONG
i0    LONG
i3    LONG
t8    LONG
c     LONG
cx    LONG
cy    LONG
lastx LONG
lasty LONG
nx    LONG
ny    LONG
slot  REAL
tot   REAL
t     REAL
t2    REAL
t3    REAL
x0    REAL
x1    REAL
x2    REAL
x3    REAL
y0    REAL
y1    REAL
y2    REAL
y3    REAL
txt   STRING(64)
  CODE
  n = SELF.NBars
  IF n < 1 THEN RETURN.
  tot = 0
  IF SELF.Percent = 1                                        ! % of this series' own total (Linea/Area)
    LOOP i = 1 TO n
      tot += ABS(SELF.GetValue(pSeries, i))
    END
    IF tot <= 0 THEN tot = 1.
  END
  slot = SELF.zPW / n
  c = SELF.ColorOf(pSeries, 1)
  IF SELF.SeriesCount() = 1 THEN c = SELF.ColorOf(1, 1).      ! one series: its first color, not one per point
  ! ---- the line itself ----
  IF SELF.ChartType <> Chart:Scatter AND n > 1
    SETPENWIDTH(SELF.LineWidth * SELF.zSc)
    SETPENCOLOR(c)
    IF SELF.Smooth = 1 AND n > 2                             ! Catmull-Rom through the points
      lastx = INT(SELF.zPX + slot * 0.5)
      lasty = SELF.VY(SELF.GetValue(pSeries, 1))
      LOOP i = 1 TO n - 1
        i0 = i - 1; IF i0 < 1 THEN i0 = 1.
        i3 = i + 2; IF i3 > n THEN i3 = n.
        x0 = SELF.zPX + slot * (i0 - 0.5); y0 = SELF.VY(SELF.GetValue(pSeries, i0))
        x1 = SELF.zPX + slot * (i - 0.5);  y1 = SELF.VY(SELF.GetValue(pSeries, i))
        x2 = SELF.zPX + slot * (i + 0.5);  y2 = SELF.VY(SELF.GetValue(pSeries, i+1))
        x3 = SELF.zPX + slot * (i3 - 0.5); y3 = SELF.VY(SELF.GetValue(pSeries, i3))
        LOOP t8 = 1 TO 8
          t = t8 / 8; t2 = t * t; t3 = t2 * t
          nx = INT(0.5 * (2*x1 + (x2-x0)*t + (2*x0-5*x1+4*x2-x3)*t2 + (3*x1-3*x2+x3-x0)*t3))
          ny = INT(0.5 * (2*y1 + (y2-y0)*t + (2*y0-5*y1+4*y2-y3)*t2 + (3*y1-3*y2+y3-y0)*t3))
          LINE(lastx, lasty, nx - lastx, ny - lasty)
          lastx = nx; lasty = ny
        END
      END
    ELSE
      LOOP i = 1 TO n
        cx = INT(SELF.zPX + slot * (i - 0.5))
        cy = SELF.VY(SELF.GetValue(pSeries, i))
        IF i > 1 THEN LINE(lastx, lasty, cx - lastx, cy - lasty).
        lastx = cx; lasty = cy
      END
    END
    SETPENWIDTH(SELF.zSc)
  END
  ! ---- markers and values ----
  LOOP i = 1 TO n
    cx = INT(SELF.zPX + slot * (i - 0.5))
    cy = SELF.VY(SELF.GetValue(pSeries, i))
    IF SELF.ShowMarkers = 1 OR SELF.ChartType = Chart:Scatter
      SELF.Marker(cx, cy, c)
    END
    IF SELF.ShowValues = 1
      IF SELF.Percent = 1
        txt = SELF.FmtNum(100 * ABS(SELF.GetValue(pSeries, i)) / tot, SELF.ValueDP) & '%'
      ELSE
        txt = SELF.FmtNum(SELF.GetValue(pSeries, i), SELF.ValueDP)
      END
      SELF.TextMid(cx, cy - SELF.zCH - INT(SELF.zPad/2), txt, SELF.TextColor)
    END
  END

GraficaBarraClass.PaintArea PROCEDURE()
i     LONG
s     LONG
n     LONG
ns    LONG
c     LONG
cx    LONG
lastx LONG
lasty LONG
cy    LONG
slot  REAL
acc   REAL,DIM(GraficaBarra:MaxBars)
nxt   REAL,DIM(GraficaBarra:MaxBars)
  CODE
  n = SELF.NBars
  ns = SELF.SeriesCount()
  IF n < 1 THEN RETURN.
  slot = SELF.zPW / n
  IF SELF.ChartType = Chart:StackedArea
    LOOP i = 1 TO n
      acc[i] = 0
    END
    LOOP s = 1 TO ns
      c = SELF.ColorOf(s, 1)
      SELF.PolyStart()
      LOOP i = 1 TO n
        nxt[i] = acc[i] + SELF.GetValue(s, i)
        SELF.PolyAdd(INT(SELF.zPX + slot * (i - 0.5)), SELF.VY(nxt[i]))
      END
      LOOP i = n TO 1 BY -1
        SELF.PolyAdd(INT(SELF.zPX + slot * (i - 0.5)), SELF.VY(acc[i]))
      END
      SETPENWIDTH(SELF.zSc); SETPENCOLOR(c)
      SELF.PolyDraw(c)
      LOOP i = 1 TO n                                        ! crisp top edge
        cx = INT(SELF.zPX + slot * (i - 0.5)); cy = SELF.VY(nxt[i])
        IF i > 1
          SETPENWIDTH(SELF.LineWidth * SELF.zSc); SETPENCOLOR(SELF.AxisColor)
          LINE(lastx, lasty, cx - lastx, cy - lasty)
        END
        lastx = cx; lasty = cy
      END
      SETPENWIDTH(SELF.zSc)
      LOOP i = 1 TO n
        acc[i] = nxt[i]
      END
    END
  ELSE
    LOOP s = ns TO 1 BY -1                                   ! back to front, so series 1 stays visible
      c = SELF.ColorOf(s, 1)
      IF ns = 1 THEN c = SELF.ColorOf(1, 1).
      SELF.PolyStart()
      SELF.PolyAdd(INT(SELF.zPX + slot * 0.5), SELF.zZY)
      LOOP i = 1 TO n
        SELF.PolyAdd(INT(SELF.zPX + slot * (i - 0.5)), SELF.VY(SELF.GetValue(s, i)))
      END
      SELF.PolyAdd(INT(SELF.zPX + slot * (n - 0.5)), SELF.zZY)
      SETPENWIDTH(SELF.zSc); SETPENCOLOR(c)
      SELF.PolyDraw(c)
    END
    LOOP s = 1 TO ns                                         ! the lines, markers and values on top
      SELF.PaintLine(s)
    END
  END

!=== pie / 3D pie / donut ===================================================
GraficaBarraClass.PaintPie PROCEDURE()
i      LONG
n      LONG
c      LONG
cx     LONG
cy     LONG
r      LONG
hr     LONG
d      LONG
dep    LONG
tot    LONG
cum    LONG
sa     LONG
lx     LONG
ly     LONG
hc     LONG
sum    REAL
fac    REAL
fm     REAL
ang    REAL
dx     REAL
dy     REAL
rr     REAL
txt    STRING(64)
  CODE
  n = SELF.NBars
  IF n < 1 THEN RETURN.
  ! ---- PIE reads the WHOLE array, so clear it and let the tail be zero ----
  LOOP i = 1 TO GraficaBarra:MaxBars
    SELF.zSlice[i] = 0
    SELF.zSliceColor[i] = 0
  END
  sum = 0
  LOOP i = 1 TO n
    sum += ABS(SELF.BarValue[i])
  END
  IF sum > 0
    fac = 100000 / sum
  ELSE
    fac = 0
  END
  tot = 0
  LOOP i = 1 TO n
    IF fac > 0
      SELF.zSlice[i] = INT(ABS(SELF.BarValue[i]) * fac + 0.5)
    ELSE
      SELF.zSlice[i] = 1                                     ! no data at all: equal slices
    END
    SELF.zSliceColor[i] = SELF.ColorOf(1, i)
    tot += SELF.zSlice[i]
  END
  IF tot < 1 THEN RETURN.
  ! ---- geometry ----
  dep = 0
  IF SELF.ChartType = Chart:Pie3D
    IF SELF.Depth3D > 0
      dep = SELF.Depth3D
    ELSE
      dep = INT(SELF.zPH / 8)
    END
  END
  d = SELF.zPW; IF SELF.zPH - dep < d THEN d = SELF.zPH - dep.
  IF SELF.ShowLabels = 1
    d = INT(d * 72 / 100)                                    ! leave room for the labels around it
  ELSE
    d = INT(d * 94 / 100)
  END
  IF d < 8 THEN RETURN.
  r = INT(d / 2)
  cx = SELF.zPX + INT(SELF.zPW / 2)
  cy = SELF.zPY + INT((SELF.zPH - dep) / 2)
  ! ---- the pie: one call, vector on a report too ----
  SETPENWIDTH(SELF.zSc)
  IF SELF.BarBorderColor <> COLOR:None                       ! slice separators
    SETPENCOLOR(SELF.BarBorderColor)
  ELSIF SELF.PlotColor <> COLOR:None
    SETPENCOLOR(SELF.PlotColor)
  ELSE
    SETPENCOLOR(0FFFFFFh)                                    ! white hairline between the slices
  END
  sa = 0
  IF SELF.StartAngle THEN sa = INT(tot * SELF.StartAngle / 360).
  PIE(cx - r, cy - r, 2 * r, 2 * r, SELF.zSlice, SELF.zSliceColor, dep, 0, sa)
  ! ---- donut hole ----
  hr = 0
  IF SELF.ChartType = Chart:Donut
    hr = INT(r * SELF.DonutPct / 100)
    IF hr > 1
      hc = SELF.HoleColor
      IF hc = COLOR:None THEN hc = SELF.PlotColor.
      IF hc = COLOR:None THEN hc = SELF.BackColor.
      IF hc = COLOR:None THEN hc = 0FFFFFFh.
      SETPENCOLOR(hc)
      ELLIPSE(cx - hr, cy - hr, 2 * hr, 2 * hr, hc)
      IF SELF.DonutText
        SELF.TextMid(cx, cy - INT(SELF.zCH/2), CLIP(SELF.DonutText), SELF.TextColor)
      END
    END
  END
  ! ---- slice labels and values ----
  cum = 0
  LOOP i = 1 TO n
    IF SELF.zSlice[i] < 1
      cum += SELF.zSlice[i]
      CYCLE
    END
    fm = (cum + SELF.zSlice[i] / 2) / tot
    cum += SELF.zSlice[i]
    ang = 2 * GraficaBarra:Pi * (fm + SELF.StartAngle / 360)  ! clockwise from twelve o'clock
    dx = SIN(ang)
    dy = -COS(ang)
    IF SELF.ShowLabels = 1
      txt = CLIP(SELF.BarLabel[i])
      lx = cx + INT(r * 110 / 100 * dx)
      ly = cy + INT(r * 110 / 100 * dy) - INT(SELF.zCH / 2)
      IF dy > 0 THEN ly += INT(dep / 2).                     ! clear the 3D edge below the pie
      IF dx < 0 THEN lx -= LEN(CLIP(txt)) * SELF.zCW.
      SELF.TextAt(lx, ly, txt, SELF.TextColor)
    END
    IF SELF.ShowValues = 1
      IF SELF.Percent = 1
        txt = SELF.FmtNum(100 * SELF.zSlice[i] / tot, SELF.ValueDP) & '%'
      ELSE
        txt = SELF.FmtNum(SELF.BarValue[i], SELF.ValueDP)
      END
      IF hr > 0
        rr = (r + hr) / 2                                    ! donut: in the middle of the ring
      ELSE
        rr = r * 62 / 100
      END
      SELF.TextMid(cx + INT(rr * dx), cy + INT(rr * dy) - INT(SELF.zCH / 2), txt, SELF.TextColor)
    END
  END

!=== radar / spider web =====================================================
GraficaBarraClass.PaintRadar PROCEDURE()
i     LONG
s     LONG
j     LONG
n     LONG
ns    LONG
c     LONG
cx    LONG
cy    LONG
r     LONG
lx    LONG
ly    LONG
dmax  REAL
v     REAL
ang   REAL
dx    REAL
dy    REAL
rr    REAL
txt   STRING(64)
  CODE
  n = SELF.NBars
  ns = SELF.SeriesCount()
  ! ---- range: always from zero out to a nice maximum ----
  SELF.zLo = 0; SELF.zHi = SELF.MaxVal
  IF SELF.AutoScale = 1
    dmax = 0
    LOOP i = 1 TO n
      LOOP s = 1 TO ns
        v = SELF.GetValue(s, i)
        IF v > dmax THEN dmax = v.
      END
    END
    SELF.zHi = SELF.NiceMax(dmax)
  END
  IF SELF.zHi <= 0 THEN SELF.zHi = 1.
  ! ---- geometry ----
  r = SELF.zPW; IF SELF.zPH < r THEN r = SELF.zPH.
  IF SELF.ShowLabels = 1
    r = INT(r * 70 / 200)                                    ! /2 for the radius, leaving room for labels
  ELSE
    r = INT(r * 94 / 200)
  END
  IF r < 8 THEN RETURN.
  cx = SELF.zPX + INT(SELF.zPW / 2)
  cy = SELF.zPY + INT(SELF.zPH / 2)
  IF SELF.GridDivs < 1 THEN SELF.GridDivs = 1.
  ! ---- the web ----
  IF SELF.ShowGrid = 1
    LOOP j = 1 TO SELF.GridDivs
      rr = r * j / SELF.GridDivs
      SELF.PolyStart()
      LOOP i = 1 TO n
        ang = 2 * GraficaBarra:Pi * (i - 1) / n
        SELF.PolyAdd(cx + INT(rr * SIN(ang)), cy - INT(rr * COS(ang)))
      END
      SETPENWIDTH(SELF.zSc); SETPENCOLOR(SELF.GridColor)
      SELF.PolyDraw(COLOR:None)
    END
  END
  IF SELF.ShowAxis = 1
    SETPENWIDTH(SELF.zSc); SETPENCOLOR(SELF.GridColor)
    LOOP i = 1 TO n
      ang = 2 * GraficaBarra:Pi * (i - 1) / n
      LINE(cx, cy, INT(r * SIN(ang)), -INT(r * COS(ang)))
    END
  END
  ! ---- one closed shape per series ----
  LOOP s = 1 TO ns
    c = SELF.ColorOf(s, 1)
    IF ns = 1 THEN c = SELF.ColorOf(1, 1).
    SELF.PolyStart()
    LOOP i = 1 TO n
      v = SELF.GetValue(s, i)
      IF v < 0 THEN v = 0.
      IF v > SELF.zHi THEN v = SELF.zHi.
      rr = r * v / SELF.zHi
      ang = 2 * GraficaBarra:Pi * (i - 1) / n
      SELF.PolyAdd(cx + INT(rr * SIN(ang)), cy - INT(rr * COS(ang)))
    END
    SETPENWIDTH(SELF.LineWidth * SELF.zSc); SETPENCOLOR(c)
    IF ns = 1
      SELF.PolyDraw(c)                                       ! one series: fill the web
    ELSE
      SELF.PolyDraw(COLOR:None)                              ! several: outlines only, all readable
    END
    SETPENWIDTH(SELF.zSc)
    IF SELF.ShowMarkers = 1
      LOOP i = 1 TO n
        v = SELF.GetValue(s, i)
        IF v < 0 THEN v = 0.
        IF v > SELF.zHi THEN v = SELF.zHi.
        rr = r * v / SELF.zHi
        ang = 2 * GraficaBarra:Pi * (i - 1) / n
        SELF.Marker(cx + INT(rr * SIN(ang)), cy - INT(rr * COS(ang)), c)
      END
    END
  END
  ! ---- scale up the twelve o'clock spoke, ON TOP of the filled web ----
  IF SELF.ShowScale = 1
    LOOP j = 1 TO SELF.GridDivs
      txt = SELF.FmtNum(SELF.zHi * j / SELF.GridDivs, SELF.ScaleDP)
      SELF.TextAt(cx + SELF.zPad, cy - INT(r * j / SELF.GridDivs) - INT(SELF.zCH/2), |
                  txt, SELF.TextColor)
    END
  END
  ! ---- axis labels around the web ----
  IF SELF.ShowLabels = 1
    LOOP i = 1 TO n
      ang = 2 * GraficaBarra:Pi * (i - 1) / n
      dx = SIN(ang); dy = -COS(ang)
      txt = CLIP(SELF.BarLabel[i])
      lx = cx + INT(r * 116 / 100 * dx)
      ly = cy + INT(r * 116 / 100 * dy) - INT(SELF.zCH / 2)
      IF dx < -0.1
        lx -= LEN(CLIP(txt)) * SELF.zCW
      ELSIF dx < 0.1
        lx -= INT(LEN(CLIP(txt)) * SELF.zCW / 2)
      END
      SELF.TextAt(lx, ly, txt, SELF.TextColor)
    END
  END

!=== legend =================================================================
GraficaBarraClass.PaintLegend PROCEDURE()
i      LONG
nitem  LONG
useCat BYTE
sw     LONG
pw     LONG
lx     LONG
ly     LONG
itemw  LONG
c      LONG
tot    REAL
txt    STRING(64)
ptxt   STRING(8)
  CODE
  IF SELF.zLegW < 1 AND SELF.zLegH < 1 THEN RETURN.
  ! useCat=1: one row per bar/category (pie always did; a single-series bar/line/area now does too - it had
  ! no legend at all before). useCat=0: one row per series name, unchanged, for genuine multi-series charts.
  IF SELF.IsPie()
    nitem = SELF.NBars; useCat = 1
  ELSIF SELF.SeriesCount() > 1
    nitem = SELF.SeriesCount(); useCat = 0
  ELSIF SELF.NBars > 1
    nitem = SELF.NBars; useCat = 1
  ELSE
    nitem = 0
  END
  IF nitem < 1 THEN RETURN.
  sw = INT(SELF.zCH * 3 / 4); IF sw < 2 THEN sw = 2.
  pw = 0; tot = 1
  IF useCat = 1
    pw = 5 * SELF.zCW                                        ! room for "100% "
    tot = 0
    LOOP i = 1 TO nitem
      tot += ABS(SELF.BarValue[i])
    END
    IF tot <= 0 THEN tot = 1.
  END
  IF SELF.LegendPos = Legend:Right
    lx = SELF.zX + SELF.zW - SELF.zLegW + SELF.zPad
    ly = SELF.zY + SELF.zPad
    IF SELF.Title THEN ly += SELF.zCH + SELF.zPad.
    LOOP i = 1 TO nitem
      IF ly + SELF.zCH > SELF.zY + SELF.zH THEN BREAK.
      IF useCat = 1
        IF SELF.ValueLabel
          txt = CLIP(SELF.BarLabel[i]) & '   ' & CLIP(SELF.ValueLabel) & ' = ' & CLIP(SELF.FmtNum(SELF.BarValue[i],SELF.ValueDP))
        ELSE
          txt = CLIP(SELF.BarLabel[i]) & '  ' & CLIP(SELF.FmtNum(SELF.BarValue[i],SELF.ValueDP))
        END
        c = SELF.ColorOf(1, i)
        ptxt = SELF.FmtNum(100 * ABS(SELF.BarValue[i]) / tot, 0) & '%'
        SELF.TextAt(lx, ly, ptxt, SELF.TextColor)
      ELSE
        txt = SELF.SeriesName[i]; c = SELF.ColorOf(i, 1)
      END
      SELF.FillBox(lx + pw, ly + INT((SELF.zCH-sw)/2), sw, sw, c)
      SELF.TextAt(lx + pw + sw + SELF.zPad, ly, txt, SELF.TextColor)
      ly += SELF.zCH + SELF.zPad
    END
  ELSE
    IF SELF.LegendPos = Legend:Top
      ly = SELF.zY + SELF.zPad
      IF SELF.Title THEN ly += SELF.zCH + SELF.zPad.
    ELSE
      ly = SELF.zY + SELF.zH - SELF.zLegH + SELF.zPad
    END
    lx = SELF.zX + SELF.zPad
    LOOP i = 1 TO nitem
      IF useCat = 1
        IF SELF.ValueLabel
          txt = CLIP(SELF.BarLabel[i]) & '   ' & CLIP(SELF.ValueLabel) & ' = ' & CLIP(SELF.FmtNum(SELF.BarValue[i],SELF.ValueDP))
        ELSE
          txt = CLIP(SELF.BarLabel[i]) & '  ' & CLIP(SELF.FmtNum(SELF.BarValue[i],SELF.ValueDP))
        END
        c = SELF.ColorOf(1, i)
        ptxt = SELF.FmtNum(100 * ABS(SELF.BarValue[i]) / tot, 0) & '%'
      ELSE
        txt = SELF.SeriesName[i]; c = SELF.ColorOf(i, 1)
      END
      itemw = pw + sw + SELF.zPad + LEN(CLIP(txt)) * SELF.zCW + 2 * SELF.zCW
      IF lx + itemw > SELF.zX + SELF.zW - SELF.zPad AND lx > SELF.zX + SELF.zPad
        lx = SELF.zX + SELF.zPad
        ly += SELF.zCH + SELF.zPad
        IF ly + SELF.zCH > SELF.zY + SELF.zH THEN BREAK.
      END
      IF useCat = 1 THEN SELF.TextAt(lx, ly, ptxt, SELF.TextColor).
      SELF.FillBox(lx + pw, ly + INT((SELF.zCH-sw)/2), sw, sw, c)
      SELF.TextAt(lx + pw + sw + SELF.zPad, ly, txt, SELF.TextColor)
      lx += itemw
    END
  END
