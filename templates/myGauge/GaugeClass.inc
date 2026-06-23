!ABCIncludeFile
! ============================================================================
!  GaugeClass - a configurable analog gauge / dial for Clarion, drawn into an
!  IMAGE control with native graphics primitives (ARC, ELLIPSE, LINE, POLYGON,
!  SHOW). Works on windows and reports. Pure Clarion - no external dependencies.
!
!  Features: any arc span (45/90/180/270/360 presets or custom start+sweep),
!  min/max range, colored zones/bands, major+minor ticks with numeric labels,
!  a value readout, title/units text, a line or triangle needle, fully
!  configurable colors, and smooth needle ANIMATION (driven by a window timer).
!
!  USAGE (handled by the myGauge template, or call it yourself):
!    INCLUDE('GaugeClass.INC'),ONCE   then declare one instance per gauge:
!      Speedo  GaugeClass
!    Speedo.SetRange(0, 220)
!    Speedo.Preset(Gauge:Arc270)
!    Speedo.AddZone(160, 220, COLOR:Red)
!    Speedo.Title = 'SPEED'   ;  Speedo.Units = 'km/h'
!    Speedo.Draw(?GaugeImage)              ! full draw
!    Speedo.AnimateTo(140)                 ! needle sweeps there on the next timer ticks
!
!  This file MUST be stored in ANSI (not UTF-8).
! ============================================================================

Gauge:Arc180       EQUATE(1)                                 ! semicircle, opens downward
Gauge:Arc270       EQUATE(2)                                 ! classic speedometer
Gauge:Arc360       EQUATE(3)                                 ! full dial
Gauge:Arc90        EQUATE(4)                                 ! quarter
Gauge:Arc45        EQUATE(5)                                 ! narrow arc

Gauge:NeedleLine   EQUATE(0)
Gauge:NeedleTri    EQUATE(1)

GaugeClass CLASS,TYPE,MODULE('GaugeClass.CLW'),LINK('GaugeClass.CLW')
Feq                SIGNED                                    ! the IMAGE control (remembered for AnimStep)
! ---- range & value ----
MinVal             REAL
MaxVal             REAL
Value              REAL
Target             REAL                                      ! animation target
! ---- geometry (degrees, math convention: CCW from 3 o'clock) ----
StartAngle         REAL                                      ! angle at MinVal
SweepAngle         REAL                                      ! degrees to MaxVal (negative = clockwise)
PivotXPct          LONG                                      ! pivot position, % of control width
PivotYPct          LONG                                      ! % of control height
RadiusPct          LONG                                      ! radius, % of min(w,h)/2
TrackPct           LONG                                      ! band thickness, % of radius
! ---- colors ----
BackColor          LONG                                      ! control background (COLOR:None = leave it)
FaceColor          LONG                                      ! dial face circle
RimColor           LONG
RimWidth           LONG
TrackColor         LONG                                      ! the empty track
NeedleColor        LONG
HubColor           LONG
TickColor          LONG
TextColor          LONG                                      ! title / value readout
LabelColor         LONG                                      ! tick labels
! ---- features on/off ----
ShowFace           BYTE
ShowRim            BYTE
ShowTrack          BYTE
ShowValue          BYTE
ShowLabels         BYTE
! ---- ticks ----
MajorTicks         LONG
MinorTicks         LONG                                      ! minor divisions between majors (0 = none)
ValueDP            LONG                                      ! decimals in the value readout
LabelDP            LONG                                      ! decimals in tick labels
! ---- needle ----
NeedleStyle        LONG
NeedleLenPct       LONG                                      ! tip radius, % of radius
NeedleWidth        LONG
! ---- text ----
Title              CSTRING(64)
Units              CSTRING(32)
! ---- color zones ----
ZFrom              REAL,DIM(16)
ZTo                REAL,DIM(16)
ZColor             LONG,DIM(16)
NZones             LONG
! ---- animation ----
AnimStepPct        REAL                                      ! % of range moved per AnimStep
! ---- methods --------------------------------------------------------------
Construct          PROCEDURE
SetRange           PROCEDURE(REAL pMin,REAL pMax)
SetValue           PROCEDURE(REAL pValue)                    ! instant (Value = Target = clamped)
AnimateTo          PROCEDURE(REAL pTarget)                   ! set the target; the needle eases there on AnimStep
SetSpan            PROCEDURE(REAL pStart,REAL pSweep)
Preset             PROCEDURE(LONG pStyle)
AddZone            PROCEDURE(REAL pFrom,REAL pTo,LONG pColor)
ClearZones         PROCEDURE
Draw               PROCEDURE(WINDOW pWin,SIGNED pImageFeq)   ! window: target the IMAGE (2-arg SETTARGET), clear, paint
Paint              PROCEDURE(SIGNED pImageFeq,BYTE pWindowMode=0) ! paint into the current target; pWindowMode=1 clears only this gauge's rectangle first (windows), 0 = no clear (reports - each band prints fresh)
AnimStep           PROCEDURE(),BYTE                          ! ease Value->Target one step; 1 = moved (caller repaints)
! ---- internal ----
Clamp              PROCEDURE(REAL v),REAL
AngleFor           PROCEDURE(REAL v),REAL
Rad                PROCEDURE(REAL deg),REAL
PX                 PROCEDURE(LONG cx,REAL r,REAL angDeg),SIGNED
PY                 PROCEDURE(LONG cy,REAL r,REAL angDeg),SIGNED
ArcBand            PROCEDURE(LONG cx,LONG cy,REAL r,REAL a1,REAL a2,LONG thick,LONG color)
FmtNum             PROCEDURE(REAL v,LONG dp),STRING
                   END
