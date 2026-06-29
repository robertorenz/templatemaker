!ABCIncludeFile
! ============================================================================
!  AaCanvasClass - a reusable ANTIALIASED 2D drawing canvas for Clarion.
!
!  Native Clarion ARC/ELLIPSE/LINE/POLYGON have no antialiasing. This class
!  draws into an off-screen 32-bit ARGB bitmap with GDI+ (SmoothingModeAntiAlias
!  + AA text), then saves a PNG you can load into an IMAGE control. The GDI+
!  flat API is bound at runtime (LoadLibrary) in gpcanvas.c - no import library,
!  no redistributable (gdiplus.dll ships with Windows).
!
!  TYPICAL USE:
!    Cv   AaCanvasClass
!    IF Cv.Begin(240, 240)
!      Cv.Clear(Cv.Argb(COLOR:White))
!      Cv.FillCircleGrad(120,120,110, Cv.Argb(0F0F0F0H), Cv.Argb(0C8C8C8H))
!      Cv.Arc(15,15,210,210, 135, 270, 14, Cv.Argb(COLOR:Navy))
!      Cv.Text('72', 120,120, 40, Cv.Argb(COLOR:Black))
!      Cv.SavePng('C:\temp\dial.png')
!      Cv.EndCanvas()
!    END
!
!  ANGLES are GDI+ convention: degrees, 0 = 3 o'clock, sweeping CLOCKWISE.
!  COLORS cross as 0xAARRGGBB; use Argb() to convert a Clarion COLOR (+alpha).
!
!  This file MUST be stored in ANSI (not UTF-8).
! ============================================================================

AaCanvasClass CLASS,TYPE,MODULE('AaCanvasClass.CLW'),LINK('AaCanvasClass.CLW')
H                  LONG                                     ! active canvas handle (0 = none)
! ---- lifecycle ----
BeginCanvas        PROCEDURE(LONG pW,LONG pH),BYTE,PROC     ! create canvas; 1 = ok
ClearCanvas        PROCEDURE(ULONG pArgb)                   ! fill the whole canvas
SavePng            PROCEDURE(STRING pPath),BYTE,PROC        ! 1 = ok
EndCanvas          PROCEDURE                                ! dispose
! ---- primitives (all antialiased) ----
Pie                PROCEDURE(REAL pX,REAL pY,REAL pW,REAL pH,REAL pStart,REAL pSweep,ULONG pArgb)
Arc                PROCEDURE(REAL pX,REAL pY,REAL pW,REAL pH,REAL pStart,REAL pSweep,REAL pPenW,ULONG pArgb,BYTE pRoundCap=1)
Line               PROCEDURE(REAL pX1,REAL pY1,REAL pX2,REAL pY2,REAL pPenW,ULONG pArgb,BYTE pRoundCap=1)
FillCircle         PROCEDURE(REAL pCx,REAL pCy,REAL pR,ULONG pArgb)
Circle             PROCEDURE(REAL pCx,REAL pCy,REAL pR,REAL pPenW,ULONG pArgb)
FillCircleGrad     PROCEDURE(REAL pCx,REAL pCy,REAL pR,ULONG pInner,ULONG pOuter)  ! radial: centre->rim
FillRectGrad       PROCEDURE(REAL pX,REAL pY,REAL pW,REAL pH,ULONG pC1,ULONG pC2,BYTE pVertical=1) ! linear
FillPolygon        PROCEDURE(*REAL pPts,LONG pNPts,ULONG pArgb)    ! pPts = x0,y0,x1,y1,...
Polygon            PROCEDURE(*REAL pPts,LONG pNPts,REAL pPenW,ULONG pArgb)
Text               PROCEDURE(STRING pText,REAL pX,REAL pY,REAL pEmPx,ULONG pArgb,<STRING pFont>,BYTE pAlign=1,BYTE pStyle=0) ! align 0=L 1=C 2=R; style bits 1=bold 2=italic
! ---- helper ----
Argb               PROCEDURE(LONG pColor,BYTE pAlpha=255),ULONG  ! Clarion COLOR (0x00BBGGRR) -> 0xAARRGGBB
LastError          PROCEDURE(),LONG                          ! 0 = ok; diagnostic code from the GDI+ shim
TempDir            PROCEDURE(),STRING                        ! the user's %TEMP% folder (trailing backslash)
                   END
