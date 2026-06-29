! ============================================================================
!  AaCanvasClass - implementation. Thin wrappers over the GDI+ flat API exposed
!  by gpcanvas.c (compiled in by PRAGMA('compile(gpcanvas.c)')). The C side
!  binds gdiplus.dll at runtime, so nothing extra is linked or shipped.
!
!  This file MUST be stored in ANSI (not UTF-8).
! ============================================================================
  MEMBER

  INCLUDE('AaCanvasClass.INC'),ONCE         ! must precede the PRAGMA / gpcanvas.c prototypes

  PRAGMA('compile(gpcanvas.c)')             ! Clarion's own C compiler builds the GDI+ shim

  MAP                                       ! module-level MAP hosting gpcanvas.c (cdecl => leading _)
    MODULE('gpcanvas.c')
gp_begin       PROCEDURE(LONG,LONG),LONG,NAME('_gpcanvas_begin')
gp_clear       PROCEDURE(LONG,ULONG),NAME('_gpcanvas_clear')
gp_pie         PROCEDURE(LONG,REAL,REAL,REAL,REAL,REAL,REAL,ULONG),NAME('_gpcanvas_fill_pie')
gp_arc         PROCEDURE(LONG,REAL,REAL,REAL,REAL,REAL,REAL,REAL,ULONG,LONG),NAME('_gpcanvas_arc')
gp_line        PROCEDURE(LONG,REAL,REAL,REAL,REAL,REAL,ULONG,LONG),NAME('_gpcanvas_line')
gp_fillell     PROCEDURE(LONG,REAL,REAL,REAL,REAL,ULONG),NAME('_gpcanvas_fill_ellipse')
gp_ell         PROCEDURE(LONG,REAL,REAL,REAL,REAL,REAL,ULONG),NAME('_gpcanvas_ellipse')
gp_fillellg    PROCEDURE(LONG,REAL,REAL,REAL,REAL,ULONG,ULONG),NAME('_gpcanvas_fill_ellipse_grad')
gp_fillrectg   PROCEDURE(LONG,REAL,REAL,REAL,REAL,ULONG,ULONG,LONG),NAME('_gpcanvas_fill_rect_grad')
gp_fillpoly    PROCEDURE(LONG,*REAL,LONG,ULONG),RAW,NAME('_gpcanvas_fill_polygon')
gp_poly        PROCEDURE(LONG,*REAL,LONG,REAL,ULONG),RAW,NAME('_gpcanvas_polygon')
gp_text        PROCEDURE(LONG,*CSTRING,REAL,REAL,REAL,ULONG,*CSTRING,LONG,LONG),RAW,NAME('_gpcanvas_text')
gp_savepng     PROCEDURE(LONG,*CSTRING),LONG,RAW,NAME('_gpcanvas_save_png')
gp_end         PROCEDURE(LONG),NAME('_gpcanvas_end')
gp_lasterr     PROCEDURE(),LONG,NAME('_gpcanvas_last_error')
gp_tempdir     PROCEDURE(*CSTRING,LONG),LONG,RAW,NAME('_gpcanvas_temp_dir')
    END
  END

!=== lifecycle ===============================================================
AaCanvasClass.BeginCanvas PROCEDURE(LONG pW,LONG pH)
  CODE
  IF SELF.H THEN SELF.EndCanvas().
  SELF.H = gp_begin(pW, pH)
  RETURN CHOOSE(SELF.H > 0, 1, 0)

AaCanvasClass.ClearCanvas PROCEDURE(ULONG pArgb)
  CODE
  IF SELF.H THEN gp_clear(SELF.H, pArgb).

AaCanvasClass.SavePng PROCEDURE(STRING pPath)
path CSTRING(261)
  CODE
  IF NOT SELF.H THEN RETURN 0.
  path = CLIP(pPath)
  RETURN CHOOSE(gp_savepng(SELF.H, path) = 0, 1, 0)

AaCanvasClass.EndCanvas PROCEDURE
  CODE
  IF SELF.H
    gp_end(SELF.H)
    SELF.H = 0
  END

!=== primitives ==============================================================
AaCanvasClass.Pie PROCEDURE(REAL pX,REAL pY,REAL pW,REAL pH,REAL pStart,REAL pSweep,ULONG pArgb)
  CODE
  IF SELF.H THEN gp_pie(SELF.H, pX,pY,pW,pH, pStart,pSweep, pArgb).

AaCanvasClass.Arc PROCEDURE(REAL pX,REAL pY,REAL pW,REAL pH,REAL pStart,REAL pSweep,REAL pPenW,ULONG pArgb,BYTE pRoundCap)
  CODE
  IF SELF.H THEN gp_arc(SELF.H, pX,pY,pW,pH, pStart,pSweep, pPenW, pArgb, pRoundCap).

AaCanvasClass.Line PROCEDURE(REAL pX1,REAL pY1,REAL pX2,REAL pY2,REAL pPenW,ULONG pArgb,BYTE pRoundCap)
  CODE
  IF SELF.H THEN gp_line(SELF.H, pX1,pY1,pX2,pY2, pPenW, pArgb, pRoundCap).

AaCanvasClass.FillCircle PROCEDURE(REAL pCx,REAL pCy,REAL pR,ULONG pArgb)
  CODE
  IF SELF.H THEN gp_fillell(SELF.H, pCx-pR, pCy-pR, pR*2, pR*2, pArgb).

AaCanvasClass.Circle PROCEDURE(REAL pCx,REAL pCy,REAL pR,REAL pPenW,ULONG pArgb)
  CODE
  IF SELF.H THEN gp_ell(SELF.H, pCx-pR, pCy-pR, pR*2, pR*2, pPenW, pArgb).

AaCanvasClass.FillCircleGrad PROCEDURE(REAL pCx,REAL pCy,REAL pR,ULONG pInner,ULONG pOuter)
  CODE
  IF SELF.H THEN gp_fillellg(SELF.H, pCx-pR, pCy-pR, pR*2, pR*2, pInner, pOuter).

AaCanvasClass.FillRectGrad PROCEDURE(REAL pX,REAL pY,REAL pW,REAL pH,ULONG pC1,ULONG pC2,BYTE pVertical)
  CODE
  IF SELF.H THEN gp_fillrectg(SELF.H, pX,pY,pW,pH, pC1, pC2, pVertical).

AaCanvasClass.FillPolygon PROCEDURE(*REAL pPts,LONG pNPts,ULONG pArgb)
  CODE
  IF SELF.H THEN gp_fillpoly(SELF.H, pPts, pNPts, pArgb).

AaCanvasClass.Polygon PROCEDURE(*REAL pPts,LONG pNPts,REAL pPenW,ULONG pArgb)
  CODE
  IF SELF.H THEN gp_poly(SELF.H, pPts, pNPts, pPenW, pArgb).

AaCanvasClass.Text PROCEDURE(STRING pText,REAL pX,REAL pY,REAL pEmPx,ULONG pArgb,<STRING pFont>,BYTE pAlign,BYTE pStyle)
txt  CSTRING(256)
font CSTRING(64)
  CODE
  IF NOT SELF.H THEN RETURN.
  txt = CLIP(pText)
  IF OMITTED(pFont) THEN font = '' ELSE font = CLIP(pFont).
  gp_text(SELF.H, txt, pX, pY, pEmPx, pArgb, font, pAlign, pStyle)

!=== helper ==================================================================
!  Clarion COLOR is a Windows COLORREF (0x00BBGGRR, red in the low byte).
!  GDI+ wants 0xAARRGGBB. A negative COLOR (COLOR:None = -1, or a system-palette
!  flag in the high bit) has no literal RGB, so we render it fully transparent.
AaCanvasClass.LastError PROCEDURE()
  CODE
  RETURN gp_lasterr()

AaCanvasClass.TempDir PROCEDURE()
dir CSTRING(261)
  CODE
  IF gp_tempdir(dir, SIZE(dir)-1) = 0 THEN RETURN ''.
  RETURN CLIP(dir)

AaCanvasClass.Argb PROCEDURE(LONG pColor,BYTE pAlpha)
r  LONG
g  LONG
b  LONG
  CODE
  IF pColor < 0 THEN RETURN 0.                              ! COLOR:None / system flag -> transparent
  r = BAND(pColor, 0FFh)
  g = BAND(BSHIFT(pColor, -8), 0FFh)
  b = BAND(BSHIFT(pColor, -16), 0FFh)
  RETURN BOR(BOR(BSHIFT(pAlpha,24), BSHIFT(r,16)), BOR(BSHIFT(g,8), b))
