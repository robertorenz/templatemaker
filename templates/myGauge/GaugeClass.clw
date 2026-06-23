! ============================================================================
!  GaugeClass - implementation. Analog gauge drawing + animation, pure Clarion.
!  Angles are in degrees, math convention (CCW from 3 o'clock), which is also
!  what ARC uses (in tenths of a degree). Screen Y grows downward, so points use
!  cy - r*SIN(). bare MEMBER + module MAP. Store this file in ANSI (not UTF-8).
! ============================================================================
  MEMBER

  MAP
  END

  INCLUDE('GaugeClass.INC'),ONCE

Gauge:PI           EQUATE(3.14159265358979)

GaugeClass.Construct PROCEDURE()
  CODE
  SELF.MinVal = 0; SELF.MaxVal = 100; SELF.Value = 0; SELF.Target = 0
  SELF.Preset(Gauge:Arc270)
  SELF.RadiusPct = 92; SELF.TrackPct = 13
  SELF.BackColor = COLOR:None
  SELF.FaceColor = COLOR:White
  SELF.RimColor = 0A0A0A0h; SELF.RimWidth = 1
  SELF.TrackColor = 0DCDCDCh                                 ! light gray
  SELF.NeedleColor = 02B2B2Bh                                ! near-black
  SELF.HubColor = 02B2B2Bh
  SELF.TickColor = 0808080h
  SELF.TextColor = 02B2B2Bh
  SELF.LabelColor = 0606060h
  SELF.ShowFace = 0; SELF.ShowRim = 0; SELF.ShowTrack = 1
  SELF.ShowValue = 1; SELF.ShowLabels = 1
  SELF.MajorTicks = 10; SELF.MinorTicks = 0
  SELF.ValueDP = 0; SELF.LabelDP = 0
  SELF.NeedleStyle = Gauge:NeedleTri; SELF.NeedleLenPct = 80; SELF.NeedleWidth = 5
  SELF.NZones = 0
  SELF.AnimStepPct = 6

GaugeClass.SetRange PROCEDURE(REAL pMin,REAL pMax)
  CODE
  SELF.MinVal = pMin; SELF.MaxVal = pMax

GaugeClass.SetValue PROCEDURE(REAL pValue)
  CODE
  SELF.Value = SELF.Clamp(pValue); SELF.Target = SELF.Value

GaugeClass.AnimateTo PROCEDURE(REAL pTarget)
  CODE
  SELF.Target = SELF.Clamp(pTarget)

GaugeClass.SetSpan PROCEDURE(REAL pStart,REAL pSweep)
  CODE
  SELF.StartAngle = pStart; SELF.SweepAngle = pSweep

GaugeClass.Preset PROCEDURE(LONG pStyle)
  CODE
  CASE pStyle
  OF Gauge:Arc180; SELF.StartAngle = 180;   SELF.SweepAngle = -180; SELF.PivotXPct = 50; SELF.PivotYPct = 66
  OF Gauge:Arc360; SELF.StartAngle = 90;    SELF.SweepAngle = -360; SELF.PivotXPct = 50; SELF.PivotYPct = 50
  OF Gauge:Arc90;  SELF.StartAngle = 180;   SELF.SweepAngle = -90;  SELF.PivotXPct = 28; SELF.PivotYPct = 64
  OF Gauge:Arc45;  SELF.StartAngle = 157.5; SELF.SweepAngle = -45;  SELF.PivotXPct = 50; SELF.PivotYPct = 74
  ELSE                                                       ! Gauge:Arc270 (default)
    SELF.StartAngle = 225; SELF.SweepAngle = -270; SELF.PivotXPct = 50; SELF.PivotYPct = 54
  END

GaugeClass.AddZone PROCEDURE(REAL pFrom,REAL pTo,LONG pColor)
  CODE
  IF SELF.NZones >= 16 THEN RETURN.
  SELF.NZones += 1
  SELF.ZFrom[SELF.NZones] = pFrom; SELF.ZTo[SELF.NZones] = pTo; SELF.ZColor[SELF.NZones] = pColor

GaugeClass.ClearZones PROCEDURE()
  CODE
  SELF.NZones = 0

!=== helpers ================================================================
GaugeClass.Clamp PROCEDURE(REAL v)
  CODE
  IF v < SELF.MinVal THEN RETURN SELF.MinVal.
  IF v > SELF.MaxVal THEN RETURN SELF.MaxVal.
  RETURN v

GaugeClass.AngleFor PROCEDURE(REAL v)
f  REAL
  CODE
  IF SELF.MaxVal = SELF.MinVal THEN RETURN SELF.StartAngle.
  f = (SELF.Clamp(v) - SELF.MinVal) / (SELF.MaxVal - SELF.MinVal)
  RETURN SELF.StartAngle + f * SELF.SweepAngle

GaugeClass.Rad PROCEDURE(REAL deg)
  CODE
  RETURN deg * Gauge:PI / 180

GaugeClass.PX PROCEDURE(LONG cx,REAL r,REAL angDeg)
  CODE
  RETURN cx + INT(r * COS(SELF.Rad(angDeg)))

GaugeClass.PY PROCEDURE(LONG cy,REAL r,REAL angDeg)
  CODE
  RETURN cy - INT(r * SIN(SELF.Rad(angDeg)))               ! screen Y grows downward

GaugeClass.ArcBand PROCEDURE(LONG cx,LONG cy,REAL r,REAL a1,REAL a2,LONG thick,LONG color)
rr  LONG
lo  REAL
hi  REAL
  CODE
  rr = INT(r)
  IF a1 <= a2
    lo = a1; hi = a2
  ELSE
    lo = a2; hi = a1
  END
  SETPENWIDTH(thick)
  SETPENCOLOR(color)
  ARC(cx-rr, cy-rr, 2*rr, 2*rr, INT(lo*10), INT(hi*10))     ! thick pen => a colored band
  SETPENWIDTH(1)

GaugeClass.FmtNum PROCEDURE(REAL v,LONG dp)
pic  CSTRING(16)
  CODE
  IF dp > 0
    pic = '@n13.' & dp
  ELSE
    pic = '@n13'
  END
  RETURN CLIP(LEFT(FORMAT(v, pic)))

!=== drawing ================================================================
GaugeClass.Paint PROCEDURE(SIGNED pImageFeq,BYTE pWindowMode=0)
ImgX  LONG
ImgY  LONG
w     LONG
h     LONG
cx    LONG
cy    LONG
r     REAL
trackR REAL
thick LONG
i     LONG
mt    LONG
val   REAL
ang   REAL
ix    SIGNED
iy    SIGNED
ox    SIGNED
oy    SIGNED
lx    SIGNED
ly    SIGNED
hr    LONG
tipX  SIGNED
tipY  SIGNED
poly  SIGNED,DIM(6)
txt   STRING(48)
  CODE
  GETPOSITION(pImageFeq, ImgX, ImgY, w, h)
  IF pWindowMode                                              ! window: clear ONLY this gauge's rectangle. A bare
    BLANK(ImgX, ImgY, w, h)                                   ! BLANK wipes the whole window graphics layer, so a
  END                                                         ! second gauge's clear would erase the first.
  cx = ImgX + INT(w * SELF.PivotXPct / 100)                   ! window-relative origin (SETTARGET(,feq), myPie #5)
  cy = ImgY + INT(h * SELF.PivotYPct / 100)
  IF w < h THEN r = w / 2 ELSE r = h / 2.
  r = r * SELF.RadiusPct / 100
  trackR = r * 0.82
  thick = INT(r * SELF.TrackPct / 100); IF thick < 2 THEN thick = 2.
  ! ---- background + face ----
  IF SELF.BackColor <> COLOR:None
    SETPENCOLOR(SELF.BackColor); BOX(ImgX, ImgY, w, h, SELF.BackColor)
  END
  IF SELF.ShowFace = 1
    SETPENCOLOR(SELF.FaceColor)
    ELLIPSE(cx-INT(r), cy-INT(r), INT(2*r), INT(2*r), SELF.FaceColor)
  END
  IF SELF.ShowRim = 1
    SETPENWIDTH(SELF.RimWidth); SETPENCOLOR(SELF.RimColor)
    ELLIPSE(cx-INT(r), cy-INT(r), INT(2*r), INT(2*r), COLOR:None)
    SETPENWIDTH(1)
  END
  ! ---- track + zones ----
  IF SELF.ShowTrack = 1
    SELF.ArcBand(cx, cy, trackR, SELF.AngleFor(SELF.MinVal), SELF.AngleFor(SELF.MaxVal), thick, SELF.TrackColor)
  END
  LOOP i = 1 TO SELF.NZones
    SELF.ArcBand(cx, cy, trackR, SELF.AngleFor(SELF.ZFrom[i]), SELF.AngleFor(SELF.ZTo[i]), thick, SELF.ZColor[i])
  END
  ! ---- ticks + labels ----
  IF SELF.MajorTicks > 0
    mt = SELF.MajorTicks
    LOOP i = 0 TO mt
      val = SELF.MinVal + (SELF.MaxVal - SELF.MinVal) * i / mt
      ang = SELF.AngleFor(val)
      ix = SELF.PX(cx, r*0.68, ang); iy = SELF.PY(cy, r*0.68, ang)
      ox = SELF.PX(cx, trackR - thick/2, ang); oy = SELF.PY(cy, trackR - thick/2, ang)
      SETPENWIDTH(2); SETPENCOLOR(SELF.TickColor)
      LINE(ix, iy, ox-ix, oy-iy)
      SETPENWIDTH(1)
      IF SELF.ShowLabels = 1
        txt = SELF.FmtNum(val, SELF.LabelDP)
        lx = SELF.PX(cx, r*0.55, ang); ly = SELF.PY(cy, r*0.55, ang)
        SETPENCOLOR(SELF.LabelColor)
        SHOW(lx - LEN(CLIP(txt))*2, ly-5, CLIP(txt))
      END
    END
    ! minor ticks
    IF SELF.MinorTicks > 0
      LOOP i = 0 TO mt*(SELF.MinorTicks+1)
        IF i - INT(i/(SELF.MinorTicks+1))*(SELF.MinorTicks+1) = 0 THEN CYCLE.   ! skip where a major sits
        val = SELF.MinVal + (SELF.MaxVal - SELF.MinVal) * i / (mt*(SELF.MinorTicks+1))
        ang = SELF.AngleFor(val)
        ix = SELF.PX(cx, r*0.74, ang); iy = SELF.PY(cy, r*0.74, ang)
        ox = SELF.PX(cx, trackR - thick/2, ang); oy = SELF.PY(cy, trackR - thick/2, ang)
        SETPENWIDTH(1); SETPENCOLOR(SELF.TickColor)
        LINE(ix, iy, ox-ix, oy-iy)
      END
    END
  END
  ! ---- title + value readout ----
  IF SELF.Title
    SETPENCOLOR(SELF.TextColor)
    SHOW(cx - LEN(CLIP(SELF.Title))*2, ImgY + INT(h*0.06), CLIP(SELF.Title))
  END
  IF SELF.ShowValue = 1
    txt = SELF.FmtNum(SELF.Value, SELF.ValueDP)
    IF SELF.Units THEN txt = CLIP(txt) & ' ' & CLIP(SELF.Units).
    SETPENCOLOR(SELF.TextColor)
    SHOW(cx - LEN(CLIP(txt))*3, cy + INT(r*0.30), CLIP(txt))
  END
  ! ---- needle + hub ----
  ang = SELF.AngleFor(SELF.Value)
  tipX = SELF.PX(cx, r * SELF.NeedleLenPct / 100, ang)
  tipY = SELF.PY(cy, r * SELF.NeedleLenPct / 100, ang)
  IF SELF.NeedleStyle = Gauge:NeedleTri
    poly[1] = tipX; poly[2] = tipY
    poly[3] = SELF.PX(cx, SELF.NeedleWidth, ang+90); poly[4] = SELF.PY(cy, SELF.NeedleWidth, ang+90)
    poly[5] = SELF.PX(cx, SELF.NeedleWidth, ang-90); poly[6] = SELF.PY(cy, SELF.NeedleWidth, ang-90)
    SETPENCOLOR(SELF.NeedleColor)
    POLYGON(poly, SELF.NeedleColor)
  ELSE
    SETPENWIDTH(SELF.NeedleWidth); SETPENCOLOR(SELF.NeedleColor)
    LINE(cx, cy, tipX-cx, tipY-cy)
    SETPENWIDTH(1)
  END
  hr = INT(r * 0.07); IF hr < 3 THEN hr = 3.
  SETPENCOLOR(SELF.HubColor)
  ELLIPSE(cx-hr, cy-hr, 2*hr, 2*hr, SELF.HubColor)

GaugeClass.Draw PROCEDURE(SIGNED pImageFeq)
  CODE
  SELF.Feq = pImageFeq
  SETTARGET(,pImageFeq)
  SELF.Paint(pImageFeq, 1)                                    ! 1 = window mode: clears only this gauge's rect
  SETTARGET()

GaugeClass.AnimStep PROCEDURE()
step  REAL
diff  REAL
  CODE
  IF SELF.Value = SELF.Target THEN RETURN 0.
  step = ABS(SELF.MaxVal - SELF.MinVal) * SELF.AnimStepPct / 100
  IF step <= 0 THEN step = ABS(SELF.MaxVal - SELF.MinVal) / 25.
  diff = SELF.Target - SELF.Value
  IF ABS(diff) <= step
    SELF.Value = SELF.Target
  ELSIF diff > 0
    SELF.Value += step
  ELSE
    SELF.Value -= step
  END
  IF SELF.Feq THEN SELF.Draw(SELF.Feq).
  RETURN CHOOSE(SELF.Value = SELF.Target, 0, 1)
