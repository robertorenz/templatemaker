! ============================================================================
!  GaugePlusClass - implementation. Antialiased analog gauge, drawn with GDI+
!  through AaCanvasClass and shown in an IMAGE control as a PNG.
!
!  Public angles are MATH convention (CCW from 3 o'clock); GDI+ measures degrees
!  CLOCKWISE from 3 o'clock (screen Y is down), so a math angle A becomes GDI+
!  angle -A. Point maths use cy - r*SIN() for the same reason.
!
!  This file MUST be stored in ANSI (not UTF-8).
! ============================================================================
  MEMBER

  INCLUDE('GaugePlusClass.INC'),ONCE

  MAP
  END

GaugeP:PI          EQUATE(3.14159265358979)

GaugePlusClass.Construct PROCEDURE()
  CODE
  SELF.Cv &= NEW AaCanvasClass
  SELF.MinVal = 0; SELF.MaxVal = 100; SELF.Value = 0; SELF.Target = 0
  SELF.Preset(GaugeP:Arc270)
  SELF.RadiusPct = 92; SELF.TrackPct = 12
  SELF.BackColor = COLOR:None                                ! transparent canvas
  SELF.FaceColor = 0FAFAFAh                                  ! glossy face: light centre
  SELF.FaceEdge  = 0D4D4D4h                                  ! glossy face: grey rim
  SELF.RimColor  = 0A0A0A0h; SELF.RimWidth = 2
  SELF.TrackColor= 0E2E2E2h
  SELF.ValueColor= 0C86E28h                                  ! professional blue accent (RGB 40,110,200)
  SELF.NeedleColor=02B2B2Bh
  SELF.HubColor  = 02B2B2Bh
  SELF.TickColor = 0909090h
  SELF.TextColor = 03A3A3Ah
  SELF.LabelColor= 0707070h
  SELF.ShowFace = 1; SELF.ShowRim = 1; SELF.ShowTrack = 1
  SELF.ShowValueArc = 1; SELF.ShowValue = 1; SELF.ShowLabels = 1; SELF.ShowGloss = 1
  SELF.MajorTicks = 10; SELF.MinorTicks = 0
  SELF.ValueDP = 0; SELF.LabelDP = 0
  SELF.NeedleStyle = GaugeP:NeedleTri; SELF.NeedleLenPct = 78; SELF.NeedleWidth = 5
  SELF.NZones = 0
  SELF.AnimStepPct = 6
  SELF.FontName = 'Segoe UI'

GaugePlusClass.Destruct PROCEDURE()
  CODE
  IF NOT SELF.Cv &= NULL
    SELF.Cv.EndCanvas()
    DISPOSE(SELF.Cv)
  END

GaugePlusClass.SetRange PROCEDURE(REAL pMin,REAL pMax)
  CODE
  SELF.MinVal = pMin; SELF.MaxVal = pMax

GaugePlusClass.SetValue PROCEDURE(REAL pValue)
  CODE
  SELF.Value = SELF.Clamp(pValue); SELF.Target = SELF.Value

GaugePlusClass.AnimateTo PROCEDURE(REAL pTarget)
  CODE
  SELF.Target = SELF.Clamp(pTarget)

GaugePlusClass.SetSpan PROCEDURE(REAL pStart,REAL pSweep)
  CODE
  SELF.StartAngle = pStart; SELF.SweepAngle = pSweep

GaugePlusClass.Preset PROCEDURE(LONG pStyle)
  CODE
  CASE pStyle
  OF GaugeP:Arc180; SELF.StartAngle = 180;   SELF.SweepAngle = -180; SELF.PivotXPct = 50; SELF.PivotYPct = 66
  OF GaugeP:Arc360; SELF.StartAngle = 90;    SELF.SweepAngle = -360; SELF.PivotXPct = 50; SELF.PivotYPct = 50
  OF GaugeP:Arc90;  SELF.StartAngle = 180;   SELF.SweepAngle = -90;  SELF.PivotXPct = 30; SELF.PivotYPct = 64
  OF GaugeP:Arc45;  SELF.StartAngle = 157.5; SELF.SweepAngle = -45;  SELF.PivotXPct = 50; SELF.PivotYPct = 74
  ELSE                                                       ! GaugeP:Arc270 (default)
    SELF.StartAngle = 225; SELF.SweepAngle = -270; SELF.PivotXPct = 50; SELF.PivotYPct = 54
  END

GaugePlusClass.AddZone PROCEDURE(REAL pFrom,REAL pTo,LONG pColor)
  CODE
  IF SELF.NZones >= 16 THEN RETURN.
  SELF.NZones += 1
  SELF.ZFrom[SELF.NZones] = pFrom; SELF.ZTo[SELF.NZones] = pTo; SELF.ZColor[SELF.NZones] = pColor

GaugePlusClass.ClearZones PROCEDURE()
  CODE
  SELF.NZones = 0

!=== helpers ================================================================
GaugePlusClass.Clamp PROCEDURE(REAL v)
  CODE
  IF v < SELF.MinVal THEN RETURN SELF.MinVal.
  IF v > SELF.MaxVal THEN RETURN SELF.MaxVal.
  RETURN v

GaugePlusClass.AngleFor PROCEDURE(REAL v)
f  REAL
  CODE
  IF SELF.MaxVal = SELF.MinVal THEN RETURN SELF.StartAngle.
  f = (SELF.Clamp(v) - SELF.MinVal) / (SELF.MaxVal - SELF.MinVal)
  RETURN SELF.StartAngle + f * SELF.SweepAngle

GaugePlusClass.PX PROCEDURE(REAL cx,REAL r,REAL angDeg)
  CODE
  RETURN cx + r * COS(angDeg * GaugeP:PI / 180)

GaugePlusClass.PY PROCEDURE(REAL cy,REAL r,REAL angDeg)
  CODE
  RETURN cy - r * SIN(angDeg * GaugeP:PI / 180)             ! screen Y grows downward

!  Draw a band along the track between two VALUES, converting math->GDI+ angles.
GaugePlusClass.ArcBand PROCEDURE(REAL cx,REAL cy,REAL r,REAL vFrom,REAL vTo,REAL thick,LONG color)
a1   REAL
a2   REAL
gStart REAL
gSweep REAL
  CODE
  a1 = SELF.AngleFor(vFrom)
  a2 = SELF.AngleFor(vTo)
  gStart = -a1                                               ! GDI+ angle = -(math angle)
  gSweep = a1 - a2                                           ! = -(a2-a1)
  SELF.Cv.Arc(cx-r, cy-r, 2*r, 2*r, gStart, gSweep, thick, SELF.Cv.Argb(color), 1)

GaugePlusClass.FmtNum PROCEDURE(REAL v,LONG dp)
pic  CSTRING(16)
  CODE
  IF dp > 0
    pic = '@n13.' & dp
  ELSE
    pic = '@n13'
  END
  RETURN CLIP(LEFT(FORMAT(v, pic)))

!=== the paint ==============================================================
GaugePlusClass.Render PROCEDURE(LONG pW,LONG pH)
cx     REAL
cy     REAL
r      REAL
trackR REAL
zoneR  REAL
thick  REAL
i      LONG
mt     LONG
val    REAL
ang    REAL
io     REAL
ii     REAL
nlen   REAL
poly   REAL,DIM(8)
emL    REAL
emV    REAL
full   BYTE
txt    STRING(48)
  CODE
  cx = pW * SELF.PivotXPct / 100
  cy = pH * SELF.PivotYPct / 100
  IF pW < pH THEN r = pW / 2 ELSE r = pH / 2.
  r = r * SELF.RadiusPct / 100
  trackR = r * 0.80
  zoneR  = r * 0.93
  thick  = r * SELF.TrackPct / 100; IF thick < 3 THEN thick = 3.
  ! ---- background ----
  SELF.Cv.ClearCanvas(SELF.Cv.Argb(SELF.BackColor))
  ! ---- glossy face + rim ----
  !  A wide span (270/360) keeps a full round bezel; a narrower one (180/90/45)
  !  gets a half-disc / wedge face clipped to its own angular span, so the empty
  !  half of the dial isn't filled. The clip preserves the gradient + gloss.
  full = CHOOSE(ABS(SELF.SweepAngle) >= 270, 1, 0)
  IF NOT full
    SELF.Cv.ClipPie(cx-r, cy-r, 2*r, 2*r, -SELF.StartAngle, -SELF.SweepAngle)
  END
  IF SELF.ShowFace
    SELF.Cv.FillCircleGrad(cx, cy, r, SELF.Cv.Argb(SELF.FaceColor), SELF.Cv.Argb(SELF.FaceEdge))
  END
  IF SELF.ShowGloss
    SELF.Cv.FillCircle(cx, cy - r*0.34, r*0.58, SELF.Cv.Argb(0FFFFFFh, 38)) ! soft top highlight
  END
  IF SELF.ShowRim
    SELF.Cv.Circle(cx, cy, r, SELF.RimWidth, SELF.Cv.Argb(SELF.RimColor))
  END
  IF NOT full
    SELF.Cv.ClipReset()
  END
  ! ---- track, value fill, zones ----
  IF SELF.ShowTrack
    SELF.ArcBand(cx, cy, trackR, SELF.MinVal, SELF.MaxVal, thick, SELF.TrackColor)
  END
  IF SELF.ShowValueArc AND SELF.Value > SELF.MinVal
    SELF.ArcBand(cx, cy, trackR, SELF.MinVal, SELF.Value, thick, SELF.ValueColor)
  END
  LOOP i = 1 TO SELF.NZones                                  ! zones: a thin ring just outside the fill
    SELF.ArcBand(cx, cy, zoneR, SELF.ZFrom[i], SELF.ZTo[i], thick*0.5, SELF.ZColor[i])
  END
  ! ---- ticks + labels ----
  IF SELF.MajorTicks > 0
    mt = SELF.MajorTicks
    emL = r * 0.13; IF emL < 8 THEN emL = 8.
    LOOP i = 0 TO mt
      val = SELF.MinVal + (SELF.MaxVal - SELF.MinVal) * i / mt
      ang = SELF.AngleFor(val)
      io = trackR - thick/2 - 1
      ii = io - r*0.09
      SELF.Cv.Line(SELF.PX(cx,ii,ang), SELF.PY(cy,ii,ang), SELF.PX(cx,io,ang), SELF.PY(cy,io,ang), 2, SELF.Cv.Argb(SELF.TickColor), 1)
      IF SELF.ShowLabels
        txt = SELF.FmtNum(val, SELF.LabelDP)
        SELF.Cv.Text(CLIP(txt), SELF.PX(cx,r*0.55,ang), SELF.PY(cy,r*0.55,ang), emL, SELF.Cv.Argb(SELF.LabelColor), SELF.FontName, 1, 0)
      END
    END
    IF SELF.MinorTicks > 0
      io = trackR - thick/2 - 1
      ii = io - r*0.05
      LOOP i = 0 TO mt*(SELF.MinorTicks+1)
        IF i - INT(i/(SELF.MinorTicks+1))*(SELF.MinorTicks+1) = 0 THEN CYCLE.
        val = SELF.MinVal + (SELF.MaxVal - SELF.MinVal) * i / (mt*(SELF.MinorTicks+1))
        ang = SELF.AngleFor(val)
        SELF.Cv.Line(SELF.PX(cx,ii,ang), SELF.PY(cy,ii,ang), SELF.PX(cx,io,ang), SELF.PY(cy,io,ang), 1, SELF.Cv.Argb(SELF.TickColor), 1)
      END
    END
  END
  ! ---- title + value readout (clustered in the lower-centre, clear of the labels) ----
  IF SELF.Title
    SELF.Cv.Text(CLIP(SELF.Title), cx, cy + r*0.16, r*0.115, SELF.Cv.Argb(SELF.LabelColor), SELF.FontName, 1, 0)
  END
  IF SELF.ShowValue
    emV = r * 0.30; IF emV < 10 THEN emV = 10.
    txt = SELF.FmtNum(SELF.Value, SELF.ValueDP)
    SELF.Cv.Text(CLIP(txt), cx, cy + r*0.44, emV, SELF.Cv.Argb(SELF.TextColor), SELF.FontName, 1, 1)
    IF SELF.Units
      SELF.Cv.Text(CLIP(SELF.Units), cx, cy + r*0.44 + emV*0.80, r*0.105, SELF.Cv.Argb(SELF.LabelColor), SELF.FontName, 1, 0)
    END
  END
  ! ---- needle + hub ----
  ang = SELF.AngleFor(SELF.Value)
  nlen = r * SELF.NeedleLenPct / 100
  IF SELF.NeedleStyle = GaugeP:NeedleTri
    poly[1] = SELF.PX(cx, nlen, ang)            ; poly[2] = SELF.PY(cy, nlen, ang)        ! tip
    poly[3] = SELF.PX(cx, SELF.NeedleWidth, ang+90) ; poly[4] = SELF.PY(cy, SELF.NeedleWidth, ang+90)
    poly[5] = SELF.PX(cx, r*0.16, ang+180)      ; poly[6] = SELF.PY(cy, r*0.16, ang+180)  ! tail
    poly[7] = SELF.PX(cx, SELF.NeedleWidth, ang-90) ; poly[8] = SELF.PY(cy, SELF.NeedleWidth, ang-90)
    SELF.Cv.FillPolygon(poly[1], 4, SELF.Cv.Argb(SELF.NeedleColor))
  ELSE
    SELF.Cv.Line(cx, cy, SELF.PX(cx,nlen,ang), SELF.PY(cy,nlen,ang), SELF.NeedleWidth, SELF.Cv.Argb(SELF.NeedleColor), 1)
  END
  SELF.Cv.FillCircle(cx, cy, r*0.085, SELF.Cv.Argb(SELF.HubColor))
  SELF.Cv.FillCircle(cx, cy, r*0.040, SELF.Cv.Argb(0E8E8E8h))

!=== render to a PNG and show it ============================================
GaugePlusClass.Draw PROCEDURE(WINDOW pWin,SIGNED pImageFeq)
w      LONG
h      LONG
savePx LONG
tdir   CSTRING(261)
path   CSTRING(261)
  CODE
  SELF.Feq = pImageFeq
  SETTARGET(pWin)
  savePx = 0{PROP:Pixels}
  0{PROP:Pixels} = 1
  w = pImageFeq{PROP:Width}
  h = pImageFeq{PROP:Height}
  0{PROP:Pixels} = savePx
  IF w < 4 OR h < 4 THEN SETTARGET(); RETURN.
  IF NOT SELF.PngA                                            ! pick two temp PNGs (ping-pong => forces reload)
    tdir = SELF.Cv.TempDir()
    SELF.PngA = CLIP(tdir) & 'gplus_' & pImageFeq & '_a.png'
    SELF.PngB = CLIP(tdir) & 'gplus_' & pImageFeq & '_b.png'
  END
  IF NOT SELF.Cv.BeginCanvas(w, h) THEN SETTARGET(); RETURN.
  SELF.Render(w, h)
  SELF.Frame += 1
  IF BAND(SELF.Frame, 1) THEN path = SELF.PngA ELSE path = SELF.PngB.
  SELF.Cv.SavePng(path)
  SELF.Cv.EndCanvas()
  pImageFeq{PROP:Text} = path
  DISPLAY(pImageFeq)
  SETTARGET()

GaugePlusClass.AnimStep PROCEDURE()
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
  RETURN 1
