!ABCIncludeFile
! ============================================================================
!  GaugePlusClass - a beautiful ANTIALIASED analog gauge / dial for Clarion.
!
!  Same idea and API as the native GaugeClass, but every pixel is drawn with
!  GDI+ (via AaCanvasClass / gpcanvas.c): smooth antialiased arcs with rounded
!  caps, a glossy radial-gradient face, an antialiased needle and crisp text.
!  It renders to a PNG in %TEMP% and points the IMAGE control at it, so the art
!  survives repaints and prints, with NO external dependency (gdiplus.dll ships
!  with Windows) and NO native ARC/LINE/POLYGON aliasing.
!
!  USAGE (handled by the myGaugePlus template, or call it yourself):
!    INCLUDE('GaugePlusClass.INC'),ONCE     then one instance per gauge:
!      Speedo  GaugePlusClass
!    Speedo.SetRange(0, 220)
!    Speedo.Preset(GaugeP:Arc270)
!    Speedo.AddZone(160, 220, 02020E0h)            ! red zone (Clarion COLOR)
!    Speedo.Title = 'SPEED' ;  Speedo.Units = 'km/h'
!    Speedo.SetValue(140)
!    Speedo.Draw(Window, ?GaugeImage)              ! render + show
!    Speedo.AnimateTo(80) ; ... Speedo.AnimStep() on a timer for a smooth sweep
!
!  Angles in the API are MATH convention (degrees CCW from 3 o'clock), exactly
!  like GaugeClass - GaugePlusClass converts to GDI+'s clockwise internally.
!
!  This file MUST be stored in ANSI (not UTF-8).
! ============================================================================

  INCLUDE('AaCanvasClass.INC'),ONCE

GaugeP:Arc180      EQUATE(1)                                 ! semicircle, opens downward
GaugeP:Arc270      EQUATE(2)                                 ! classic speedometer
GaugeP:Arc360      EQUATE(3)                                 ! full dial
GaugeP:Arc90       EQUATE(4)                                 ! quarter
GaugeP:Arc45       EQUATE(5)                                 ! narrow arc

GaugeP:NeedleLine  EQUATE(0)
GaugeP:NeedleTri   EQUATE(1)

GaugePlusClass CLASS,TYPE,MODULE('GaugePlusClass.CLW'),LINK('GaugePlusClass.CLW')
Cv                 &AaCanvasClass                            ! the antialiased canvas (created on first Draw)
Feq                SIGNED                                    ! the IMAGE control
Frame              LONG                                      ! ping-pong counter (forces IMAGE reload each frame)
PngA               CSTRING(261)                              ! the two temp PNG paths (alternated)
PngB               CSTRING(261)
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
! ---- colors (Clarion COLOR, 0x00BBGGRR) ----
BackColor          LONG                                      ! canvas background (COLOR:None = transparent)
FaceColor          LONG                                      ! glossy face: centre highlight
FaceEdge           LONG                                      ! glossy face: rim shade
RimColor           LONG
RimWidth           LONG
TrackColor         LONG                                      ! the empty track
ValueColor         LONG                                      ! the filled value arc (min..value)
NeedleColor        LONG
HubColor           LONG
TickColor          LONG
TextColor          LONG                                      ! title / value readout
LabelColor         LONG                                      ! tick labels
! ---- features on/off ----
ShowFace           BYTE
ShowRim            BYTE
ShowTrack          BYTE
ShowValueArc       BYTE                                      ! the coloured fill from min to value
ShowValue          BYTE                                      ! the numeric readout
ShowLabels         BYTE
ShowGloss          BYTE                                      ! a soft highlight sweep on the face
! ---- ticks ----
MajorTicks         LONG
MinorTicks         LONG
ValueDP            LONG
LabelDP            LONG
! ---- needle ----
NeedleStyle        LONG
NeedleLenPct       LONG
NeedleWidth        LONG
! ---- text ----
Title              CSTRING(64)
Units              CSTRING(32)
FontName           CSTRING(32)
! ---- color zones ----
ZFrom              REAL,DIM(16)
ZTo                REAL,DIM(16)
ZColor             LONG,DIM(16)
NZones             LONG
! ---- animation ----
AnimStepPct        REAL
! ---- methods --------------------------------------------------------------
Construct          PROCEDURE
Destruct           PROCEDURE
SetRange           PROCEDURE(REAL pMin,REAL pMax)
SetValue           PROCEDURE(REAL pValue)
AnimateTo          PROCEDURE(REAL pTarget)
SetSpan            PROCEDURE(REAL pStart,REAL pSweep)
Preset             PROCEDURE(LONG pStyle)
AddZone            PROCEDURE(REAL pFrom,REAL pTo,LONG pColor)
ClearZones         PROCEDURE
Draw               PROCEDURE(WINDOW pWin,SIGNED pImageFeq)   ! render to a PNG and show it in the IMAGE
AnimStep           PROCEDURE(),BYTE                          ! ease Value->Target one step; 1 = moved
! ---- internal ----
Clamp              PROCEDURE(REAL v),REAL
AngleFor           PROCEDURE(REAL v),REAL
PX                 PROCEDURE(REAL cx,REAL r,REAL angDeg),REAL
PY                 PROCEDURE(REAL cy,REAL r,REAL angDeg),REAL
ArcBand            PROCEDURE(REAL cx,REAL cy,REAL r,REAL vFrom,REAL vTo,REAL thick,LONG color) ! between two VALUES
Render             PROCEDURE(LONG pW,LONG pH)                ! paint the whole gauge onto SELF.Cv (pixels)
FmtNum             PROCEDURE(REAL v,LONG dp),STRING
                   END
