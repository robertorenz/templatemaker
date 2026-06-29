/* ============================================================================
 *  gpcanvas.c - a small ANTIALIASED 2D canvas for Clarion, backed by GDI+.
 *
 *  Clarion's native ARC/ELLIPSE/LINE/POLYGON are NOT antialiased. This shim
 *  exposes a tiny immediate-mode drawing API that renders into a 32-bit ARGB
 *  GDI+ bitmap with SmoothingModeAntiAlias (vector AA) + AA text, then saves a
 *  PNG. The Clarion side loads that PNG into an IMAGE control.
 *
 *  No import library and no redistributable: GDI+ (gdiplus.dll) ships with
 *  every Windows since XP, and we bind to its FLAT C API at runtime with
 *  LoadLibrary + GetProcAddress (the same trampoline trick proven in my3D) -
 *  so Clarion never has to link gdiplus.lib (it can't link MSVC COFF libs).
 *
 *  Compiled by Clarion's own C++ compiler (Clacpp) via PRAGMA('compile(...)')
 *  in AaCanvasClass.clw. Exports are extern "C"; Clarion prototypes them in a
 *  MODULE('gpcanvas.c') block with NAME('_gpcanvas_xxx') (cdecl => leading _).
 *
 *  ABI notes (deliberate, to keep the Clarion boundary safe):
 *    - all coordinates/angles cross as C `double` (Clarion REAL), cast to GDI+
 *      `float` (REAL) inside - avoids any 4-vs-8-byte float mismatch.
 *    - colors cross as 32-bit 0xAARRGGBB ARGB (Clarion ULONG, by value).
 *    - strings cross as char* (Clarion *CSTRING,RAW); converted to UTF-16 here.
 *    - a canvas is referenced by a small int handle (1..GP_MAX); 0 = failure.
 *
 *  Angle convention is GDI+'s: degrees, 0 = 3 o'clock, sweeping CLOCKWISE
 *  (because y grows downward). The Clarion gauge converts its own math-angles.
 * ========================================================================== */

/* Clarion's bundled C compiler (Clacpp) has NO Windows SDK headers, so we
   hand-declare the tiny Win32 surface we use. The Clarion linker resolves these
   kernel32 symbols natively (no import lib needed - same as the my3D trampoline).
   NOTE: Clacpp spells the stdcall convention `pascal` (32-bit pascal == __stdcall:
   callee cleans the stack); it does NOT understand __stdcall/_stdcall. */
#define WINAPI pascal
typedef unsigned long  DWORD;
typedef int            BOOL;
typedef unsigned int   UINT;
typedef unsigned short WCHAR;
typedef unsigned char  BYTE;
typedef void*          HMODULE;
typedef unsigned long  ULONG_PTR;            /* pointer-sized on Win32 = 4 bytes */
typedef int (WINAPI *FARPROC)();
typedef struct { unsigned long Data1; unsigned short Data2; unsigned short Data3; unsigned char Data4[8]; } GUID;

#define CP_ACP 0
#define LPTR   0x0040

extern "C" {

HMODULE WINAPI LoadLibraryA(const char*);
FARPROC WINAPI GetProcAddress(HMODULE, const char*);
int     WINAPI MultiByteToWideChar(UINT, DWORD, const char*, int, WCHAR*, int);
void*   WINAPI LocalAlloc(UINT, unsigned long);
void*   WINAPI LocalFree(void*);
DWORD   WINAPI GetTempPathA(DWORD, char*);

/* ---- GDI+ opaque handles (all just pointers) ---- */
typedef void* GpImage;
typedef void* GpBitmap;
typedef void* GpGraphics;
typedef void* GpBrush;
typedef void* GpPen;
typedef void* GpPath;
typedef void* GpFontFamily;
typedef void* GpFont;
typedef void* GpStringFormat;
typedef unsigned int ARGB;

typedef struct { float X, Y; } GpPointF;
typedef struct { float X, Y, W, H; } GpRectF;

typedef struct {
    unsigned int GdiplusVersion;
    void* DebugEventCallback;
    int   SuppressBackgroundThread;
    int   SuppressExternalCodecs;
} GdiplusStartupInput;
typedef struct { void* hook; void* unhook; } GdiplusStartupOutput;

/* PixelFormat32bppARGB, units, modes, caps, alignments */
#define PF_32ARGB         0x0026200A
#define UNIT_PIXEL        2
#define SMOOTH_AA         4   /* SmoothingModeAntiAlias */
#define PIXOFF_HALF       4   /* PixelOffsetModeHighQuality */
#define TEXT_AA           4   /* TextRenderingHintAntiAlias */
#define CAP_ROUND         2   /* LineCapRound */
#define ALIGN_NEAR        0
#define ALIGN_CENTER      1
#define ALIGN_FAR         2

/* ---- flat GDI+ entry points we use (all __stdcall) ---- */
typedef int (WINAPI *PFN_Startup)(ULONG_PTR*, const GdiplusStartupInput*, GdiplusStartupOutput*);
typedef int (WINAPI *PFN_BmpScratch)(int, int, int, int, BYTE*, GpBitmap*);
typedef int (WINAPI *PFN_GetCtx)(GpImage, GpGraphics*);
typedef int (WINAPI *PFN_DelGfx)(GpGraphics);
typedef int (WINAPI *PFN_DispImg)(GpImage);
typedef int (WINAPI *PFN_SetI)(GpGraphics, int);
typedef int (WINAPI *PFN_Clear)(GpGraphics, ARGB);
typedef int (WINAPI *PFN_SolidFill)(ARGB, GpBrush*);
typedef int (WINAPI *PFN_DelBrush)(GpBrush);
typedef int (WINAPI *PFN_Pen1)(ARGB, float, int, GpPen*);
typedef int (WINAPI *PFN_DelPen)(GpPen);
typedef int (WINAPI *PFN_PenCap)(GpPen, int);
typedef int (WINAPI *PFN_Pie)(GpGraphics, GpBrush, float, float, float, float, float, float);
typedef int (WINAPI *PFN_Arc)(GpGraphics, GpPen, float, float, float, float, float, float);
typedef int (WINAPI *PFN_Ell)(GpGraphics, void*, float, float, float, float);
typedef int (WINAPI *PFN_Line)(GpGraphics, GpPen, float, float, float, float);
typedef int (WINAPI *PFN_PolyF)(GpGraphics, GpBrush, const GpPointF*, int, int);
typedef int (WINAPI *PFN_PolyP)(GpGraphics, GpPen, const GpPointF*, int);
typedef int (WINAPI *PFN_LineBrush)(const GpRectF*, ARGB, ARGB, int, int, GpBrush*);
typedef int (WINAPI *PFN_NewPath)(int, GpPath*);
typedef int (WINAPI *PFN_DelPath)(GpPath);
typedef int (WINAPI *PFN_AddEll)(GpPath, float, float, float, float);
typedef int (WINAPI *PFN_PGFromPath)(GpPath, GpBrush*);
typedef int (WINAPI *PFN_PGCenterC)(GpBrush, ARGB);
typedef int (WINAPI *PFN_PGSurround)(GpBrush, const ARGB*, int*);
typedef int (WINAPI *PFN_FillPath)(GpGraphics, GpBrush, GpPath);
typedef int (WINAPI *PFN_FamName)(const WCHAR*, void*, GpFontFamily*);
typedef int (WINAPI *PFN_FamSans)(GpFontFamily*);
typedef int (WINAPI *PFN_DelFam)(GpFontFamily);
typedef int (WINAPI *PFN_NewFont)(GpFontFamily, float, int, int, GpFont*);
typedef int (WINAPI *PFN_DelFont)(GpFont);
typedef int (WINAPI *PFN_NewSF)(int, unsigned short, GpStringFormat*);
typedef int (WINAPI *PFN_SFAlign)(GpStringFormat, int);
typedef int (WINAPI *PFN_DelSF)(GpStringFormat);
typedef int (WINAPI *PFN_DrawStr)(GpGraphics, const WCHAR*, int, GpFont, const GpRectF*, GpStringFormat, GpBrush);
typedef int (WINAPI *PFN_Save)(GpImage, const WCHAR*, const GUID*, const void*);

static PFN_Startup   p_Startup;
static PFN_BmpScratch p_BmpScratch;
static PFN_GetCtx    p_GetCtx;
static PFN_DelGfx    p_DelGfx;
static PFN_DispImg   p_DispImg;
static PFN_SetI      p_SetSmooth, p_SetPixOff, p_SetTextHint;
static PFN_Clear     p_Clear;
static PFN_SolidFill p_SolidFill;
static PFN_DelBrush  p_DelBrush;
static PFN_Pen1      p_Pen1;
static PFN_DelPen    p_DelPen;
static PFN_PenCap    p_PenStart, p_PenEnd;
static PFN_Pie       p_Pie;
static PFN_Arc       p_Arc;
static PFN_Ell       p_FillEll, p_DrawEll;
static PFN_Line      p_DrawLine;
static PFN_PolyF     p_FillPoly;
static PFN_PolyP     p_DrawPoly;
static PFN_LineBrush p_LineBrush;
static PFN_NewPath   p_NewPath;
static PFN_DelPath   p_DelPath;
static PFN_AddEll    p_AddEll;
static PFN_PGFromPath p_PGFromPath;
static PFN_PGCenterC p_PGCenterC;
static PFN_PGSurround p_PGSurround;
static PFN_FillPath  p_FillPath;
static PFN_FamName   p_FamName;
static PFN_FamSans   p_FamSans;
static PFN_DelFam    p_DelFam;
static PFN_NewFont   p_NewFont;
static PFN_DelFont   p_DelFont;
static PFN_NewSF     p_NewSF;
static PFN_SFAlign   p_SFAlign, p_SFLineAlign;
static PFN_DelSF     p_DelSF;
static PFN_DrawStr   p_DrawStr;
static PFN_Save      p_Save;

static int        g_inited = 0;
static ULONG_PTR  g_token = 0;
static int        g_err = 0;     /* diagnostic: last failure point/status */

int gpcanvas_last_error(void) { return g_err; }

/* PNG encoder CLSID {557CF406-1A04-11D3-9A73-0000F81EF32E} */
static const GUID CLSID_PNG =
  {0x557cf406,0x1a04,0x11d3,{0x9a,0x73,0x00,0x00,0xf8,0x1e,0xf3,0x2e}};

static int gp_init(void) {
    HMODULE h;
    GdiplusStartupInput in;
    if (g_inited) return 1;
    h = LoadLibraryA("gdiplus.dll");
    if (!h) { g_err = 1; return 0; }
    /* bind every entry point; if any core one is missing, bail */
    *(FARPROC*)&p_Startup     = GetProcAddress(h, "GdiplusStartup");
    *(FARPROC*)&p_BmpScratch  = GetProcAddress(h, "GdipCreateBitmapFromScan0");
    *(FARPROC*)&p_GetCtx      = GetProcAddress(h, "GdipGetImageGraphicsContext");
    *(FARPROC*)&p_DelGfx      = GetProcAddress(h, "GdipDeleteGraphics");
    *(FARPROC*)&p_DispImg     = GetProcAddress(h, "GdipDisposeImage");
    *(FARPROC*)&p_SetSmooth   = GetProcAddress(h, "GdipSetSmoothingMode");
    *(FARPROC*)&p_SetPixOff   = GetProcAddress(h, "GdipSetPixelOffsetMode");
    *(FARPROC*)&p_SetTextHint = GetProcAddress(h, "GdipSetTextRenderingHint");
    *(FARPROC*)&p_Clear       = GetProcAddress(h, "GdipGraphicsClear");
    *(FARPROC*)&p_SolidFill   = GetProcAddress(h, "GdipCreateSolidFill");
    *(FARPROC*)&p_DelBrush    = GetProcAddress(h, "GdipDeleteBrush");
    *(FARPROC*)&p_Pen1        = GetProcAddress(h, "GdipCreatePen1");
    *(FARPROC*)&p_DelPen      = GetProcAddress(h, "GdipDeletePen");
    *(FARPROC*)&p_PenStart    = GetProcAddress(h, "GdipSetPenStartCap");
    *(FARPROC*)&p_PenEnd      = GetProcAddress(h, "GdipSetPenEndCap");
    *(FARPROC*)&p_Pie         = GetProcAddress(h, "GdipFillPie");
    *(FARPROC*)&p_Arc         = GetProcAddress(h, "GdipDrawArc");
    *(FARPROC*)&p_FillEll     = GetProcAddress(h, "GdipFillEllipse");
    *(FARPROC*)&p_DrawEll     = GetProcAddress(h, "GdipDrawEllipse");
    *(FARPROC*)&p_DrawLine    = GetProcAddress(h, "GdipDrawLine");
    *(FARPROC*)&p_FillPoly    = GetProcAddress(h, "GdipFillPolygon");
    *(FARPROC*)&p_DrawPoly    = GetProcAddress(h, "GdipDrawPolygon");
    *(FARPROC*)&p_LineBrush   = GetProcAddress(h, "GdipCreateLineBrushFromRect");
    *(FARPROC*)&p_NewPath     = GetProcAddress(h, "GdipCreatePath");
    *(FARPROC*)&p_DelPath     = GetProcAddress(h, "GdipDeletePath");
    *(FARPROC*)&p_AddEll      = GetProcAddress(h, "GdipAddPathEllipse");
    *(FARPROC*)&p_PGFromPath  = GetProcAddress(h, "GdipCreatePathGradientFromPath");
    *(FARPROC*)&p_PGCenterC   = GetProcAddress(h, "GdipSetPathGradientCenterColor");
    *(FARPROC*)&p_PGSurround  = GetProcAddress(h, "GdipSetPathGradientSurroundColorsWithCount");
    *(FARPROC*)&p_FillPath    = GetProcAddress(h, "GdipFillPath");
    *(FARPROC*)&p_FamName     = GetProcAddress(h, "GdipCreateFontFamilyFromName");
    *(FARPROC*)&p_FamSans     = GetProcAddress(h, "GdipGetGenericFontFamilySansSerif");
    *(FARPROC*)&p_DelFam      = GetProcAddress(h, "GdipDeleteFontFamily");
    *(FARPROC*)&p_NewFont     = GetProcAddress(h, "GdipCreateFont");
    *(FARPROC*)&p_DelFont     = GetProcAddress(h, "GdipDeleteFont");
    *(FARPROC*)&p_NewSF       = GetProcAddress(h, "GdipCreateStringFormat");
    *(FARPROC*)&p_SFAlign     = GetProcAddress(h, "GdipSetStringFormatAlign");
    *(FARPROC*)&p_SFLineAlign = GetProcAddress(h, "GdipSetStringFormatLineAlign");
    *(FARPROC*)&p_DelSF       = GetProcAddress(h, "GdipDeleteStringFormat");
    *(FARPROC*)&p_DrawStr     = GetProcAddress(h, "GdipDrawString");
    *(FARPROC*)&p_Save        = GetProcAddress(h, "GdipSaveImageToFile");

    if (!p_Startup)    { g_err = 2; return 0; }
    if (!p_BmpScratch) { g_err = 3; return 0; }
    if (!p_GetCtx)     { g_err = 4; return 0; }
    if (!p_Save)       { g_err = 5; return 0; }

    in.GdiplusVersion = 1;
    in.DebugEventCallback = 0;
    in.SuppressBackgroundThread = 0;
    in.SuppressExternalCodecs = 0;
    g_err = p_Startup(&g_token, &in, 0);
    if (g_err != 0) { g_err = 100 + g_err; return 0; }  /* 100+status */
    g_inited = 1;
    return 1;
}

/* ---- canvas handle table ---- */
#define GP_MAX 16
typedef struct { GpBitmap bmp; GpGraphics g; int used; } Canvas;
static Canvas g_cv[GP_MAX];

static Canvas* cv(int h) {
    if (h < 1 || h > GP_MAX) return 0;
    if (!g_cv[h-1].used) return 0;
    return &g_cv[h-1];
}

/* convert a UTF-8/ANSI char* to a freshly-allocated WCHAR* (caller frees) */
static WCHAR* widen(const char* s) {
    int n; WCHAR* w;
    if (!s) return 0;
    n = MultiByteToWideChar(CP_ACP, 0, s, -1, 0, 0);
    if (n <= 0) return 0;
    w = (WCHAR*)LocalAlloc(LPTR, n * sizeof(WCHAR));
    if (!w) return 0;
    MultiByteToWideChar(CP_ACP, 0, s, -1, w, n);
    return w;
}

/* ==========================  PUBLIC API  ============================= */

/* Create a w x h ARGB canvas. Returns a handle (1..GP_MAX) or 0 on failure. */
int gpcanvas_begin(int w, int h) {
    int i;
    GpBitmap bmp = 0; GpGraphics g = 0;
    if (!gp_init()) return 0;
    if (w < 1) w = 1; if (h < 1) h = 1;
    for (i = 0; i < GP_MAX; i++) if (!g_cv[i].used) break;
    if (i == GP_MAX) { g_err = 200; return 0; }
    g_err = p_BmpScratch(w, h, 0, PF_32ARGB, 0, &bmp);
    if (g_err != 0 || !bmp) { g_err = 300 + g_err; return 0; }
    g_err = p_GetCtx(bmp, &g);
    if (g_err != 0 || !g) { p_DispImg(bmp); g_err = 400 + g_err; return 0; }
    g_err = 0;
    p_SetSmooth(g, SMOOTH_AA);
    if (p_SetPixOff)   p_SetPixOff(g, PIXOFF_HALF);
    if (p_SetTextHint) p_SetTextHint(g, TEXT_AA);
    g_cv[i].bmp = bmp; g_cv[i].g = g; g_cv[i].used = 1;
    return i + 1;
}

void gpcanvas_clear(int h, ARGB argb) {
    Canvas* c = cv(h); if (!c) return;
    p_Clear(c->g, argb);
}

/* filled pie slice (a wedge from the centre) */
void gpcanvas_fill_pie(int h, double x, double y, double w, double hh,
                       double start, double sweep, ARGB argb) {
    Canvas* c = cv(h); GpBrush b = 0; if (!c) return;
    if (p_SolidFill(argb, &b) != 0) return;
    p_Pie(c->g, b, (float)x,(float)y,(float)w,(float)hh,(float)start,(float)sweep);
    p_DelBrush(b);
}

/* stroked arc along an ellipse's edge */
void gpcanvas_arc(int h, double x, double y, double w, double hh,
                  double start, double sweep, double penw, ARGB argb, int roundcap) {
    Canvas* c = cv(h); GpPen pen = 0; if (!c) return;
    if (p_Pen1(argb, (float)penw, UNIT_PIXEL, &pen) != 0) return;
    if (roundcap) { if (p_PenStart) p_PenStart(pen, CAP_ROUND); if (p_PenEnd) p_PenEnd(pen, CAP_ROUND); }
    p_Arc(c->g, pen, (float)x,(float)y,(float)w,(float)hh,(float)start,(float)sweep);
    p_DelPen(pen);
}

void gpcanvas_line(int h, double x1, double y1, double x2, double y2,
                   double penw, ARGB argb, int roundcap) {
    Canvas* c = cv(h); GpPen pen = 0; if (!c) return;
    if (p_Pen1(argb, (float)penw, UNIT_PIXEL, &pen) != 0) return;
    if (roundcap) { if (p_PenStart) p_PenStart(pen, CAP_ROUND); if (p_PenEnd) p_PenEnd(pen, CAP_ROUND); }
    p_DrawLine(c->g, pen, (float)x1,(float)y1,(float)x2,(float)y2);
    p_DelPen(pen);
}

void gpcanvas_fill_ellipse(int h, double x, double y, double w, double hh, ARGB argb) {
    Canvas* c = cv(h); GpBrush b = 0; if (!c) return;
    if (p_SolidFill(argb, &b) != 0) return;
    p_FillEll(c->g, b, (float)x,(float)y,(float)w,(float)hh);
    p_DelBrush(b);
}

void gpcanvas_ellipse(int h, double x, double y, double w, double hh, double penw, ARGB argb) {
    Canvas* c = cv(h); GpPen pen = 0; if (!c) return;
    if (p_Pen1(argb, (float)penw, UNIT_PIXEL, &pen) != 0) return;
    p_DrawEll(c->g, pen, (float)x,(float)y,(float)w,(float)hh);
    p_DelPen(pen);
}

/* radial-gradient filled ellipse: inner colour at centre -> outer at the rim.
   Great for a glossy gauge face / hub highlight. */
void gpcanvas_fill_ellipse_grad(int h, double x, double y, double w, double hh,
                                ARGB inner, ARGB outer) {
    Canvas* c = cv(h); GpPath path = 0; GpBrush pg = 0; ARGB surround[1]; int cnt = 1;
    if (!c || !p_NewPath || !p_PGFromPath) { gpcanvas_fill_ellipse(h,x,y,w,hh,outer); return; }
    if (p_NewPath(0, &path) != 0 || !path) return;
    p_AddEll(path, (float)x,(float)y,(float)w,(float)hh);
    if (p_PGFromPath(path, &pg) != 0 || !pg) { p_DelPath(path); return; }
    p_PGCenterC(pg, inner);
    surround[0] = outer;
    p_PGSurround(pg, surround, &cnt);
    p_FillPath(c->g, pg, path);
    p_DelBrush(pg);
    p_DelPath(path);
}

/* linear-gradient filled rectangle. vertical=1 => top->bottom, else left->right */
void gpcanvas_fill_rect_grad(int h, double x, double y, double w, double hh,
                             ARGB c1, ARGB c2, int vertical) {
    Canvas* c = cv(h); GpBrush b = 0; GpRectF r; if (!c || !p_LineBrush) return;
    r.X=(float)x; r.Y=(float)y; r.W=(float)w; r.H=(float)hh;
    if (p_LineBrush(&r, c1, c2, vertical ? 1 : 0, 0, &b) != 0 || !b) return;
    {   /* fill the rectangle with the gradient brush via its 4 corners */
        GpPointF pts[4];
        pts[0].X=(float)x;      pts[0].Y=(float)y;
        pts[1].X=(float)(x+w);  pts[1].Y=(float)y;
        pts[2].X=(float)(x+w);  pts[2].Y=(float)(y+hh);
        pts[3].X=(float)x;      pts[3].Y=(float)(y+hh);
        p_FillPoly(c->g, b, pts, 4, 0);
    }
    p_DelBrush(b);
}

/* filled polygon. pts = x0,y0,x1,y1,... (npts = number of POINTS) */
void gpcanvas_fill_polygon(int h, double* pts, int npts, ARGB argb) {
    Canvas* c = cv(h); GpBrush b = 0; GpPointF buf[128]; int i;
    if (!c || !pts || npts < 2 || npts > 128) return;
    if (p_SolidFill(argb, &b) != 0) return;
    for (i = 0; i < npts; i++) { buf[i].X = (float)pts[i*2]; buf[i].Y = (float)pts[i*2+1]; }
    p_FillPoly(c->g, b, buf, npts, 0);
    p_DelBrush(b);
}

void gpcanvas_polygon(int h, double* pts, int npts, double penw, ARGB argb) {
    Canvas* c = cv(h); GpPen pen = 0; GpPointF buf[128]; int i;
    if (!c || !pts || npts < 2 || npts > 128) return;
    if (p_Pen1(argb, (float)penw, UNIT_PIXEL, &pen) != 0) return;
    if (p_PenStart) p_PenStart(pen, CAP_ROUND);
    if (p_PenEnd)   p_PenEnd(pen, CAP_ROUND);
    for (i = 0; i < npts; i++) { buf[i].X = (float)pts[i*2]; buf[i].Y = (float)pts[i*2+1]; }
    p_DrawPoly(c->g, pen, buf, npts);
    p_DelPen(pen);
}

/* antialiased text, anchored at (x,y). align: 0 left, 1 centre, 2 right
   (horizontal); the text is vertically centred on y. style bits: 1 bold,
   2 italic. emPx = em height in pixels. font = family name ("" => sans-serif). */
void gpcanvas_text(int h, const char* s, double x, double y, double emPx,
                   ARGB argb, const char* font, int align, int style) {
    Canvas* c = cv(h); GpFontFamily fam = 0; GpFont f = 0; GpBrush b = 0;
    GpStringFormat sf = 0; GpRectF r; WCHAR* ws; WCHAR* wf = 0; int gotFam = 0;
    if (!c || !s || !*s) return;
    ws = widen(s); if (!ws) return;
    if (font && *font) { wf = widen(font);
        if (wf && p_FamName && p_FamName(wf, 0, &fam) == 0 && fam) gotFam = 1; }
    if (!gotFam && p_FamSans && p_FamSans(&fam) == 0 && fam) gotFam = 1;
    if (!gotFam) { LocalFree(ws); if (wf) LocalFree(wf); return; }
    if (p_NewFont(fam, (float)emPx, style, UNIT_PIXEL, &f) != 0 || !f) {
        p_DelFam(fam); LocalFree(ws); if (wf) LocalFree(wf); return; }
    p_SolidFill(argb, &b);
    p_NewSF(0, 0, &sf);
    if (sf) { if (p_SFAlign) p_SFAlign(sf, align); if (p_SFLineAlign) p_SFLineAlign(sf, ALIGN_CENTER); }
    /* a wide layout box centred on (x,y): the StringFormat does the alignment */
    r.X = (float)(x - 4000.0); r.W = 8000.0f;
    r.Y = (float)(y - emPx);   r.H = (float)(emPx * 2.0);
    p_DrawStr(c->g, ws, -1, f, &r, sf, b);
    if (sf) p_DelSF(sf);
    if (b)  p_DelBrush(b);
    p_DelFont(f);
    p_DelFam(fam);
    LocalFree(ws); if (wf) LocalFree(wf);
}

/* Save the canvas to a PNG file. Returns 0 on success, non-zero on error. */
int gpcanvas_save_png(int h, const char* path) {
    Canvas* c = cv(h); WCHAR* wp; int st;
    if (!c || !path) return -1;
    wp = widen(path); if (!wp) return -2;
    st = p_Save(c->bmp, wp, &CLSID_PNG, 0);
    LocalFree(wp);
    return st;
}

/* Copy the user's %TEMP% directory (with trailing backslash) into out.
   Returns the length written, 0 on failure. */
int gpcanvas_temp_dir(char* out, int cap) {
    if (!out || cap < 1) return 0;
    return (int)GetTempPathA((DWORD)cap, out);
}

/* Dispose a canvas. */
void gpcanvas_end(int h) {
    Canvas* c = cv(h); if (!c) return;
    if (c->g)   p_DelGfx(c->g);
    if (c->bmp) p_DispImg(c->bmp);
    c->g = 0; c->bmp = 0; c->used = 0;
}

} /* extern "C" */
