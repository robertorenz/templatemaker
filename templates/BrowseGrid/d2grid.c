/* ============================================================================
 *  d2grid.c - a grid drawn with Direct2D and DirectWrite, for Clarion.
 *  v1.36 - it ships with the BrowseGrid template of the same number, and the
 *  two are versioned together because the template declares every export here.
 *
 *  WHY. Clarion's LIST is drawn by the runtime and looks it. This draws every
 *  pixel itself into an ordinary Clarion REGION - which owns a real HWND, like
 *  every Clarion control - so a browse can have banded rows, frozen columns,
 *  a proper header, smooth scrolling and any colour scheme you like, without
 *  giving up ABC's BrowseClass underneath.
 *
 *  WHAT IT DOES NOT DO. It holds no data. Clarion pushes the VISIBLE rows in
 *  before each paint - which is exactly what an ABC browse queue already
 *  contains - and the grid draws them. Scrolling posts an event back so the
 *  Clarion side can fetch the next page from the VIEW. The grid never owns the
 *  file, the sort order or the filter; BrowseClass keeps all of that.
 *
 *  BOUND AT RUN TIME. d2d1.dll and dwrite.dll are loaded with LoadLibrary, so
 *  there is no import library to link (Clarion cannot link MSVC COFF libs) and
 *  nothing to ship. Both have been part of Windows since 7.
 *
 *  COM WITHOUT A HEADER. Clacpp has no Windows SDK, so the interfaces are
 *  hand-declared. Every vtable index below was read out of the SDK's own
 *  d2d1.h / dwrite.h by walking each interface's declaration order, base class
 *  first - not remembered. They are named once, here, and nowhere else:
 *
 *    ID2D1Factory            2 Release  14 CreateHwndRenderTarget
 *    ID2D1HwndRenderTarget   2 Release   8 CreateSolidColorBrush
 *                           15 DrawLine 17 FillRectangle  27 DrawText
 *                           30 SetTransform 45 PushAxisAlignedClip
 *                           46 PopAxisAlignedClip 47 Clear 48 BeginDraw
 *                           49 EndDraw 58 Resize
 *    ID2D1SolidColorBrush    2 Release   8 SetColor
 *    IDWriteFactory          2 Release  15 CreateTextFormat
 *
 *  ABI notes:
 *    - 32-bit, stdcall (Clacpp spells it `pascal`).
 *    - D2D1_POINT_2F goes to DrawLine BY VALUE. Two floats on the stack is
 *      byte-identical to the struct, so they are declared as separate floats.
 *    - DrawText wants UTF-16. Clarion hands over ANSI, converted here.
 * ========================================================================== */

#define WINAPI pascal
typedef unsigned long  DWORD;
typedef unsigned int   UINT;
typedef int            BOOL;
typedef unsigned char  BYTE;
typedef unsigned short WCHAR;
typedef void*          HMODULE;
typedef void*          HWND;
typedef long           HRESULT;
typedef int (WINAPI *FARPROC)();
typedef long (WINAPI *WNDPROC)(HWND, UINT, UINT, long);

typedef struct { unsigned long Data1; unsigned short Data2; unsigned short Data3;
                 unsigned char Data4[8]; } GUID;
typedef struct { long left, top, right, bottom; } RECT;

#define LPTR         0x0040
#define CP_ACP       0
#define GWL_WNDPROC  (-4)
#define WM_PAINT      0x000F
#define WM_ERASEBKGND 0x0014

extern "C" {

HMODULE WINAPI LoadLibraryA(const char*);
FARPROC WINAPI GetProcAddress(HMODULE, const char*);
void*   WINAPI LocalAlloc(UINT, unsigned long);
void*   WINAPI LocalFree(void*);
long    WINAPI SetWindowLongA(HWND, int, long);
long    WINAPI GetWindowLongA(HWND, int);
long    WINAPI CallWindowProcA(WNDPROC, HWND, UINT, UINT, long);
long    WINAPI DefWindowProcA(HWND, UINT, UINT, long);
BOOL    WINAPI InvalidateRect(HWND, const RECT*, BOOL);
BOOL    WINAPI GetClientRect(HWND, RECT*);
void*   WINAPI BeginPaint(HWND, void*);
BOOL    WINAPI EndPaint(HWND, const void*);
BOOL    WINAPI IsWindow(HWND);
int     WINAPI MultiByteToWideChar(UINT, DWORD, const char*, int, WCHAR*, int);

/* ---- Direct2D / DirectWrite types, exactly as the SDK lays them out ------ */
typedef struct { unsigned int w, h; }                SIZEU;
typedef struct { float l, t, r, b; }                 RECTF;
typedef struct { float r, g, b, a; }                 COLORF;
typedef struct { int format; int alphaMode; }        PIXFMT;
typedef struct { int type; PIXFMT pf; float dpiX, dpiY;
                 int usage; int minLevel; }          RTPROPS;
typedef struct { HWND hwnd; SIZEU size; int present; } HRTPROPS;

/* DrawText does NOT clip to the rectangle it is given. That rectangle says
   where to LAY the text out, not where to keep it: a value wider than its
   column is drawn straight over the columns to its right, and a heading too
   long for its own column lands on the next one. Asking for CLIP is what
   makes the rectangle mean what it looks like it means.
   Cut rather than an ellipsis on purpose: trimming needs a sign object and
   another vtable slot taken on trust, and the whole value is a hover away
   in the tooltip. */
#define D2D_CLIPTEXT 2       /* D2D1_DRAW_TEXT_OPTIONS_CLIP */

#define DXGI_B8G8R8A8_UNORM  87
#define ALPHA_IGNORE          3
#define FACTORY_SINGLE        0
#define DW_FACTORY_SHARED     0
#define FONT_NORMAL         400
#define FONT_BOLD           700
#define STYLE_NORMAL          0
#define STRETCH_NORMAL        5
#define AA_ALIASED            1     /* D2D1_ANTIALIAS_MODE_ALIASED */
/* IDWriteTextFormat, which inherits straight from IUnknown:
     3 SetTextAlignment   4 SetParagraphAlignment   5 SetWordWrapping        */
#define DW_LEADING            0     /* left   */
#define DW_TRAILING           1     /* right  */
#define DW_CENTER             2
#define DW_PARA_CENTER        2     /* centred down the row, not hugging the top */
#define DW_NO_WRAP            1     /* a cell is one line; clip, never wrap      */
#define DW_WRAP               0     /* ...or let it run onto the next line       */

#define VT(o) (*(void***)(o))

typedef HRESULT (WINAPI *PFN_D2D1CreateFactory)(int, const GUID*, const void*, void**);
typedef HRESULT (WINAPI *PFN_DWriteCreateFactory)(int, const GUID*, void**);

#define G_MAX     16            /* grids at once                              */
#define G_COLS    64            /* columns                                    */
/* A CEILING, not a reservation. The rows on screen are asked for when the
   shape is known, so this only says where a bug stops being a bug and starts
   being a request for a gigabyte. Nothing is reserved for rows nobody has.  */
#define G_MAXROWS 512           /* visible rows the Clarion side may push in  */
#define G_TEXT   128            /* characters per cell. Long enough to be worth
                                   wrapping: at 64 a cell was cut at 63
                                   characters before it ever reached
                                   DirectWrite, which looks exactly like text
                                   that refused to wrap.                      */

typedef struct {
    int   used;
    HWND  hwnd;
    void* rt;                   /* ID2D1HwndRenderTarget */
    void* fmt;                  /* IDWriteTextFormat - the body font   */
    void* fmtHdr;               /* ... and the header font             */
    void* fmtIcon;              /* Windows' icon font, for the funnel  */
    void* brush;                /* one brush, recoloured as it goes    */
    WNDPROC oldProc;

    int   cols;
    int   colW[G_COLS];
    int   colAlign[G_COLS];     /* 0 left 1 right 2 centre */
    char  colTitle[G_COLS][G_TEXT];
    int   frozen;               /* how many columns stay put while scrolling  */

    int   rtW, rtH;             /* what the render target is currently sized to */
    int   rowH, hdrH;
    int   visRows;              /* rows the Clarion side has pushed in        */
    int   firstRow;             /* which record visRow 0 is                   */
    int   totalRows;
    int   selRow;               /* selected, in absolute row numbers          */
    int   scrollX;
    int   scrollY;              /* pixels the page is nudged UP by; 0..rowH-1
                                   is a part-row at the top, which is what
                                   makes scrolling smooth rather than jumpy   */
    /* The rows on screen, one string per cell. This is the only thing in a
       Grid big enough to be worth ASKING for rather than reserving: at a
       fixed 96 rows by 32 columns it was 393 KB per grid, times every slot,
       or 3,5 MB of an executable that had not drawn a pixel yet - and an
       application with no grid at all paid all of it. Asked for once the
       shape is known, a typical grid - forty rows of a dozen columns - takes
       61 KB, and a grid nobody opened takes nothing.
       Indexed by hand rather than declared [rows][cols] because the column
       count is not known until the LIST has been read, and a stride only
       fixed at run time cannot be spelled in a C declaration. */
    char* cells;                /* rowCap * colCap * G_TEXT, or 0           */
    /* What ABC worked out for each cell: NormalFG NormalBG SelectedFG
       SelectedBG, four to a cell. Asked for ONLY when a browse turns out to
       have conditional colours at all, which most do not - sixteen bytes a
       cell against the text's hundred and twenty-eight, and no reason to
       charge it to a grid that never uses one. A negative entry is ABC's own
       COLOR:None: leave the row's colour alone. */
    int*  cellCol;              /* rowCap * colCap * 4 ints, or 0           */
    /* And the colours the FORMATTER put on a whole column, which are a
       different thing from the conditional ones above: those come out of the
       queue and change row by row, these are set once in the window and hold
       for the column. Cheap enough to keep for every column - four ints - and
       read once per column instead of once per cell. -1 is 'none' here too. */
    int   colCheck[G_COLS];     /* draw a tick box instead of the text?     */
    /* A row of totals along the bottom. Asked for like the cells and for the
       same reason: one string per column is small, but a grid that never
       shows totals should not carry it. footH is 0 when there is no footer,
       and everything below reads that as 'there is no footer'. */
    int   footH;
    char* footTxt;              /* footCap * G_TEXT, or 0                   */
    int   footCap;              /* the column count it was asked for        */
    int   colFg[G_COLS], colBg[G_COLS];
    int   colSFg[G_COLS], colSBg[G_COLS];
    int   rowCap, colCap;       /* what was actually asked for and granted  */

    unsigned int cBack, cBand, cGrid, cText, cHdrBack, cHdrText, cSelBack, cSelText;

    /* our own vertical scrollbar. Windows' one cannot be made to track: it
       drags inside a message loop of its own, and moving the browse needs
       records, which needs Clarion's ACCEPT, which that loop is holding up.
       Drawn here it is just pixels, and dragging it is an ordinary mouse
       event like any other. */
    int   vBar;                 /* drawn at all?                            */
    int   vPos;                 /* 0..100, the browse's own scale           */
    int   vPct;                 /* how much of the trough the thumb takes   */

    /* ---- how the bars look ------------------------------------------------
       0 Windows  the horizontal one is Windows' own, the vertical one drawn
       1 Slim     both drawn, thin and flat, taking their width from the rows
       2 Overlay  both drawn, thinner, ON TOP of the rows and only while the
                  pointer is over the grid - so nothing is taken from the data */
    int   barStyle;
    int   gdiText;              /* 1 = dibujar el texto como lo dibuja GDI  */
    int   txDiag[6];            /* que devolvieron las llamadas, para el log */
    int   hBar, hPos, hPage, hTotal;   /* the drawn horizontal one           */
    int   barsShow;                    /* overlay: is the pointer over us?   */

    char  face[64];             /* kept so the font can be rebuilt bigger   */
    int   pt;

    int   btns;                 /* draw a filter button on every heading?   */
    /* Which columns are filtered - a SET, not one column. Filters add up the
       way Excel's do, so more than one can be on at once and every one of them
       has to say so on its own heading. */
    int   colFilt[G_COLS];
    int   sortCol;              /* which column is sorted, -1 for none      */
    int   sortDir;              /* 1 up, -1 down                            */

    /* ---- grouped, multi-line formats -------------------------------------
       An ordinary browse has one line per record and its columns simply follow
       one another, which is what grps == 0 means and nothing below is touched.
       A grouped one puts several fields on each record over several lines,
       under headings that span them - so a column needs to say WHERE it goes
       rather than just how wide it is, and the headings belong to the groups
       rather than to the columns. */
    int   grps;                 /* 0 = an ordinary flat browse              */
    int   grpX[G_COLS], grpW[G_COLS];
    char  grpTitle[G_COLS][G_TEXT];
    int   colX[G_COLS];         /* where the column sits across the record  */
    int   colLine[G_COLS];      /* and which line of it                     */
    int   colGrp[G_COLS];       /* which group it belongs to                */
    /* Where the field sat inside its group when the format was read, and how
       wide the group was then. Resizing recomputes from THESE, never from the
       last result: scaling the current numbers again and again is destructive,
       and integer arithmetic drives them to nothing. Squeeze a group small
       enough that way and every offset rounds to zero, and growing it back
       multiplies zero by a ratio - still zero, so the fields stay piled up on
       the left.
       Keeping the ORIGINAL numbers rather than a proportion of them also means
       no double rounding: back at the width it started from, the arithmetic is
       exact rather than a pixel short. */
    int   colOx[G_COLS], colOw[G_COLS];
    int   grpOw[G_COLS];
    int   lines;                /* lines per record, 1 for an ordinary one  */

    int   wrap;                 /* let long text run onto another line?     */
    int   wrapLines;            /* how many lines a cell is allowed         */
} Grid;

/* Where cell (row, col) lives. The stride is colCap, NOT cols: the block
   keeps its shape when a column is hidden and the count drops. */
#define CELL(c,r,k) ((c)->cells + (((r) * (c)->colCap + (k)) * G_TEXT))
#define CELLCOL(c,r,k) ((c)->cellCol + (((r) * (c)->colCap + (k)) * 4))
#define FOOT(c,k)      ((c)->footTxt + ((k) * G_TEXT))

#define D2G_BARW 15

static Grid  g_g[G_MAX + 1];
static void* g_d2d = 0;
static void* g_dw  = 0;
static int   g_tried = 0;

static long WINAPI d2g_WndProc(HWND h, UINT msg, UINT wp, long lp);

/* How tall a row and a heading are for a given point size. Leading has to grow
   WITH the type, not sit at a fixed number of pixels above it: pt + 10 is
   roomy at 9 point and cramped at 24, where the descenders start being cut off
   by the row below.
   These numbers went UP when the point-to-DIP bug above was fixed. The old
   rule - three halves and a bit - was tuned by eye against type that was a
   quarter too small, so it was right for the wrong reason: the rows fitted
   because the letters were undersized. At the true size a nine point line
   wants about fifteen pixels, so the row is a shade under twice the point
   size plus a little air. */
#define D2G_ROWFOR(pt) ((pt) * 9 / 5 + 5)
/* A record is as tall as its format needs times as many lines as a wrapped
   cell is allowed. Every row is the same height either way - variable-height
   rows would take the page size, the hit testing and the scrolling with them,
   and none of those want to know that a particular address was long. */
/* A format that already says where its lines are does not also get the wrap
   allowance multiplied on top: three lines times two wrapped lines is a row six
   deep with every field floating in the middle of a box twice the size of its
   text. Wrapping is for a flat browse, where a cell has one line and needs
   more; a grouped record has been told exactly how many it wants. */
#define D2G_ROWH(c) (D2G_ROWFOR((c)->pt) * (c)->lines *                        \
                     (((c)->lines > 1) ? 1 : (c)->wrapLines))
#define D2G_HDRFOR(pt) ((pt) * 9 / 5 + 7)
static void d2g_VGeom(Grid* c, int* top, int* len, int* tTop, int* tLen);
static void d2g_HGeom(Grid* c, int* left, int* len, int* tLeft, int* tLen);
static int  barThick(Grid* c);
static int  barTakes(Grid* c);
static void sortMark(Grid* c, float right, float top, int dir, unsigned int rgb);
static void filterBtn(Grid* c, float right, float midY, unsigned int line_, unsigned int fill,
                      int dir, int filt);
static void glyph(Grid* c, unsigned short ch, float l, float t, float r, float b,
                  unsigned int rgb, void* fmt);

/* What the button says, as characters rather than shapes hand-built out of
   one-pixel rows. They scale with the type and read as icons because they are
   icons - the font's, not ours. */
#define D2G_G_MENU  0x02C5      /* a thin arrowhead: this opens a menu */
#define D2G_G_ASC   0x25B2      /* a solid triangle, pointing up       */
#define D2G_G_DESC  0x25BC      /* ...and pointing down                */
#define D2G_G_FILT  0xE71C      /* the funnel, out of Windows' own icon font */
#define D2G_BTNW 15         /* the drop-down box on a heading, as Excel draws it */
/* A column too narrow to hold the drop-down does not get one. Drawn anyway it
   covers its own heading and spills onto the neighbour's, which is what a
   tick box column looked like. The menu is not lost with it: a right-click
   on the heading still opens it.
   IN PIXELS. Widths arrive here doubled - the LIST keeps them in dialog
   units and the Clarion side hands over wid * 2 - so this is the twenty
   units the developer sees in the formatter, not twenty pixels. Written as
   twenty it read true for a ten unit column and changed nothing at all. */
#define D2G_BTNMIN 40
#define BTNON(c,col) ((c)->btns && (c)->colW[col] >= D2G_BTNMIN)

/* ---- the two factories --------------------------------------------------- */
static int d2g_Factories(void) {
    HMODULE d2dDll, dwDll;
    PFN_D2D1CreateFactory   mkD2D;
    PFN_DWriteCreateFactory mkDW;
    GUID iid;

    if (g_d2d && g_dw) return 1;
    if (g_tried) return 0;
    g_tried = 1;

    d2dDll = LoadLibraryA("d2d1.dll");
    dwDll  = LoadLibraryA("dwrite.dll");
    if (!d2dDll || !dwDll) return 0;
    mkD2D = (PFN_D2D1CreateFactory)GetProcAddress(d2dDll, "D2D1CreateFactory");
    mkDW  = (PFN_DWriteCreateFactory)GetProcAddress(dwDll, "DWriteCreateFactory");
    if (!mkD2D || !mkDW) return 0;

    /* IID_ID2D1Factory {06152247-6f50-465a-9245-118bfd3b6007} */
    iid.Data1 = 0x06152247; iid.Data2 = 0x6f50; iid.Data3 = 0x465a;
    iid.Data4[0]=0x92; iid.Data4[1]=0x45; iid.Data4[2]=0x11; iid.Data4[3]=0x8b;
    iid.Data4[4]=0xfd; iid.Data4[5]=0x3b; iid.Data4[6]=0x60; iid.Data4[7]=0x07;
    if (mkD2D(FACTORY_SINGLE, &iid, 0, &g_d2d) < 0) { g_d2d = 0; return 0; }

    /* IID_IDWriteFactory {b859ee5a-d838-4b5b-a2e8-1adc7d93db48} */
    iid.Data1 = 0xb859ee5a; iid.Data2 = 0xd838; iid.Data3 = 0x4b5b;
    iid.Data4[0]=0xa2; iid.Data4[1]=0xe8; iid.Data4[2]=0x1a; iid.Data4[3]=0xdc;
    iid.Data4[4]=0x7d; iid.Data4[5]=0x93; iid.Data4[6]=0xdb; iid.Data4[7]=0x48;
    if (mkDW(DW_FACTORY_SHARED, &iid, &g_dw) < 0) { g_dw = 0; return 0; }
    return 1;
}

/* Grow the cell block to hold rows x cols. GROWS ONLY - a browse paging back
   and forth would otherwise free and allocate on every fill - and the old
   contents are dropped rather than copied, because changing the column count
   changes the stride, and the Clarion side rewrites every visible cell on
   every fill regardless. Returns 0 if Windows refused, and the caller then
   draws fewer rows rather than writing where it must not. */
/* -1 is 'nothing said here', which is what ABC means by COLOR:None. It has to
   be written in rather than left at the zero LocalAlloc gives, because zero
   is a colour: black. */
static void unsetAll(int* p, long n) {
    long i;
    for (i = 0; i < n; i++) p[i] = -1;
}

/* The colour block exists only from the first coloured cell onwards. */
static int ensureColours(Grid* c) {
    long n;
    if (c->cellCol) return 1;
    if (!c->cells)  return 0;
    n = (long)c->rowCap * (long)c->colCap * 4L;
    c->cellCol = (int*)LocalAlloc(LPTR, n * (long)sizeof(int));
    if (!c->cellCol) return 0;
    unsetAll(c->cellCol, n);
    return 1;
}

/* The footer is indexed by COLUMN and by nothing else, so it follows the
   column count and not the shape of the cell block. Tying it to the cells -
   which is what this did - meant every fill that needed one more row threw
   the totals away, and since they are only written when the set changes they
   never came back. The band was there, empty, for good. */
static int ensureFoot(Grid* c) {
    long n;
    if (c->colCap < 1) return 0;
    if (c->footTxt && c->footCap == c->colCap) return 1;
    if (c->footTxt) LocalFree(c->footTxt);
    n = (long)c->colCap * (long)G_TEXT;
    c->footTxt = (char*)LocalAlloc(LPTR, n);
    c->footCap = c->footTxt ? c->colCap : 0;
    return c->footTxt ? 1 : 0;
}

static int ensureCells(Grid* c, int rows, int cols) {
    char* p;
    long  need;
    if (rows < 1) rows = 1;
    if (cols < 1) cols = 1;
    if (rows > G_MAXROWS) rows = G_MAXROWS;
    if (cols > G_COLS)    cols = G_COLS;
    if (c->cells && rows <= c->rowCap && cols <= c->colCap) return 1;
    if (rows < c->rowCap) rows = c->rowCap;
    if (cols < c->colCap) cols = c->colCap;
    need = (long)rows * (long)cols * (long)G_TEXT;
    p = (char*)LocalAlloc(LPTR, need);
    if (!p) return 0;
    if (c->cells) LocalFree(c->cells);
    c->cells  = p;
    c->rowCap = rows;
    c->colCap = cols;
    /* The colours are indexed with the same stride, so they cannot outlive a
       change of shape. Dropped, not copied: the next fill writes them again. */
    if (c->cellCol) {
        LocalFree(c->cellCol);
        c->cellCol = 0;
        ensureColours(c);
    }
    return 1;
}

static Grid* slot(int h) {
    if (h < 1 || h > G_MAX || !g_g[h].used) return 0;
    return &g_g[h];
}

static void wide(const char* src, WCHAR* dst, int cap) {
    int n = MultiByteToWideChar(CP_ACP, 0, src, -1, dst, cap);
    if (n <= 0) dst[0] = 0;
}

/* one text format (a font) */
/* POINTS ARE NOT PIXELS. DirectWrite sizes a format in DIPs, and this render
   target is built at 96 DPI, so a DIP is a pixel. A point is 1/72 inch and a
   pixel here is 1/96, so nine POINTS is twelve pixels - and handing the point
   size straight to CreateTextFormat drew everything at three quarters of the
   size that was asked for. Same font, same number in the prompt, visibly
   smaller than the rest of the application. */
#define D2G_PT2DIP(pt) ((pt) * 96.0f / 72.0f)

static int g_weight = 0;        /* 0 = el normal; si no, el peso pedido */

/* EL NOMBRE DE FAMILIA PUEDE LLEVAR EL PESO ADENTRO. "Roboto Medium" es una
   familia para GDI, que resuelve a la cara Medium; DirectWrite puede darle a
   esa misma familia el miembro de peso 400. Cuando pasa, no se esta viendo el
   mismo texto renderizado distinto: se estan viendo dos CARAS distintas, y no
   hay contraste ni hinting que las iguale. Poder pedir el peso a mano es la
   salida, porque el nombre solo no basta para decidirlo. */
/* SIN RANURA. El peso se necesita ANTES del attach, que es cuando se crean las
   tipografias, y en ese momento todavia no hay grid: pedir slot(h) con un
   handle que aun no existe devuelve nulo y el peso se descartaba callado, que
   es como se ve un prompt que no hace nada. Es un global porque gobierna la
   CREACION de la fuente, no un grid en particular. */
void d2g_Weight(int h, int w) { g_weight = w; }

/* EL PESO QUE DICE EL NOMBRE. "Roboto Medium", "Segoe UI Light": para GDI son
   familias y las resuelve a esa cara; DirectWrite le da a la misma familia su
   miembro de peso 400, mas liviano, y el grid se ve mas fino que el LIST de al
   lado con la misma tipografia configurada. No es renderizado: son dos caras
   distintas, y ningun contraste ni hinting las iguala.
   Se mira la ULTIMA palabra, que es donde va el peso en estos nombres. Si no
   dice ninguno, 0 y queda el normal. */
static int weightFromName(const char* face) {
    const char* w;
    int i, n = 0;
    while (face[n]) n++;
    while (n > 0 && face[n - 1] != ' ') n--;
    if (n == 0) return 0;                       /* una sola palabra: nada que leer */
    w = face + n;
    { struct { const char* s; int v; } tbl[] = {
        {"Thin",100},{"ExtraLight",200},{"UltraLight",200},{"Light",300},
        {"SemiLight",350},{"Medium",500},{"SemiBold",600},{"DemiBold",600},
        {"Bold",700},{"ExtraBold",800},{"UltraBold",800},{"Black",900},
        {"Heavy",900},{0,0} };
      for (i = 0; tbl[i].s; i++) {
          int j = 0;
          while (tbl[i].s[j] && w[j] == tbl[i].s[j]) j++;
          if (!tbl[i].s[j] && !w[j]) return tbl[i].v;
      }
    }
    return 0;
}

static void* d2g_Font(const char* face, float size, int bold) {
    WCHAR wf[64], wl[8];
    void* fmt = 0;
    if (!g_dw) return 0;
    wide(face, wf, 64);
    wl[0] = 'e'; wl[1] = 'n'; wl[2] = '-'; wl[3] = 'u'; wl[4] = 's'; wl[5] = 0;
    /* IDWriteFactory::CreateTextFormat - slot 15 */
    if (((HRESULT (WINAPI*)(void*, const WCHAR*, void*, int, int, int, float,
                            const WCHAR*, void**))VT(g_dw)[15])
        (g_dw, wf, 0, bold ? FONT_BOLD :
              (g_weight ? g_weight :
               (weightFromName(face) ? weightFromName(face) : FONT_NORMAL)),
         STYLE_NORMAL,
         STRETCH_NORMAL, D2G_PT2DIP(size), wl, &fmt) < 0) return 0;
    /* down the middle of the row, and one line only */
    ((HRESULT (WINAPI*)(void*, int))VT(fmt)[4])(fmt, DW_PARA_CENTER);
    ((HRESULT (WINAPI*)(void*, int))VT(fmt)[5])(fmt, DW_NO_WRAP);
    return fmt;
}

/* MISMA FUENTE, MISMO TAMANO, DISTINTO GROSOR.

   Un LIST de Clarion lo dibuja GDI y el grid lo dibuja DirectWrite, y no
   renderizan igual: GDI ajusta los trazos a la grilla de pixeles y les aplica
   contraste realzado, con lo que engordan; DirectWrite por omision posiciona
   con precision subpixel y deja los trazos donde caen, mas finos. Puestos uno
   al lado del otro en la misma ventana, el grid se ve mas delgado aunque la
   tipografia y el tamano sean identicos - y es lo primero que nota quien mira
   las dos cosas juntas.

   DWRITE_RENDERING_MODE_GDI_CLASSIC es el modo que existe justamente para
   esto: mismo hinting y mismo ajuste a la grilla que GDI.

   Los otros cuatro parametros salen de la configuracion de la MAQUINA, no de
   constantes: gamma, contraste, nivel de ClearType y orden de subpixeles son
   lo que el usuario dejo en el panel de ClearType, y pisarlos con numeros
   propios seria arreglar el grosor rompiendo el color del texto en pantallas
   que no son RGB. Solo se cambia el MODO. */
#define DW_MODE_GDI_CLASSIC 2

static void applyTextMode(Grid* c) {
    void *def = 0, *par = 0;
    float gamma, contrast, level;
    int   geom, i;
    for (i = 0; i < 6; i++) c->txDiag[i] = -999;
    if (!c->rt || !g_dw || !c->gdiText) return;
    /* IDWriteFactory::CreateRenderingParams - slot 10: lo de esta maquina */
    c->txDiag[0] = ((HRESULT (WINAPI*)(void*, void**))VT(g_dw)[10])(g_dw, &def);
    if (c->txDiag[0] < 0 || !def) return;
    gamma    = ((float (WINAPI*)(void*))VT(def)[3])(def);   /* GetGamma            */
    contrast = ((float (WINAPI*)(void*))VT(def)[4])(def);   /* GetEnhancedContrast */
    level    = ((float (WINAPI*)(void*))VT(def)[5])(def);   /* GetClearTypeLevel   */
    geom     = ((int   (WINAPI*)(void*))VT(def)[6])(def);   /* GetPixelGeometry    */
    c->txDiag[1] = (int)(gamma    * 100.0f);
    c->txDiag[2] = (int)(contrast * 100.0f);
    c->txDiag[3] = (int)(level    * 100.0f);
    c->txDiag[4] = geom;
/*  EL CONTRASTE ES LO QUE ENGORDA, mas que el hinting. GDI dibuja su ClearType
    con un realce mas fuerte que el que suele traer DirectWrite, y ese realce es
    la mitad de por que un LIST se ve mas grueso. Cambiar solo el MODO fue
    quedarse a mitad de camino: arregla el ajuste de los trazos a la grilla y no
    toca su peso. */
    if (contrast < 1.0f) contrast = 1.0f;
    /* IDWriteFactory::CreateCustomRenderingParams - slot 12 */
    c->txDiag[5] = ((HRESULT (WINAPI*)(void*, float, float, float, int, int, void**))VT(g_dw)[12])
                   (g_dw, gamma, contrast, level, geom, DW_MODE_GDI_CLASSIC, &par);
    if (c->txDiag[5] >= 0 && par) {
        /* ID2D1RenderTarget::SetTextRenderingParams - slot 36 */
        ((void (WINAPI*)(void*, void*))VT(c->rt)[36])(c->rt, par);
/*      Y CLEARTYPE EXPLICITO. Gamma, contraste y nivel de arriba solo pesan
        cuando el antialiasing es ClearType; con el modo en DEFAULT lo elige
        Direct2D, y si elige escala de grises los parametros quedan casi sin
        efecto - que es como se ve pedirlos y que no pase nada.
        SetTextAntialiasMode - slot 34, CLEARTYPE = 1 */
        ((void (WINAPI*)(void*, int))VT(c->rt)[34])(c->rt, 1);
        ((unsigned long (WINAPI*)(void*))VT(par)[2])(par);          /* Release */
    }
    ((unsigned long (WINAPI*)(void*))VT(def)[2])(def);              /* Release */
}

/* 1 = como GDI, 0 = como DirectWrite por omision. Se puede pedir antes de que
   exista la superficie, asi que se guarda y se aplica cuando exista. */
/* Lo que devolvieron las llamadas y con que valores se armaron los parametros.
   0 = hr de CreateRenderingParams, 1..3 = gamma/contraste/nivel por cien,
   4 = geometria de subpixeles, 5 = hr de CreateCustomRenderingParams.
   -999 significa que ni se intento. */
int d2g_TextInfo(int h, int what) {
    Grid* c = slot(h);
    if (!c || what < 0 || what > 5) return -998;
    return c->txDiag[what];
}

void d2g_TextMode(int h, int gdi) {
    Grid* c = slot(h);
    if (!c) return;
    c->gdiText = gdi ? 1 : 0;
    applyTextMode(c);
    if (c->rt) InvalidateRect(c->hwnd, 0, 0);
}

static int d2g_MakeTarget(Grid* c) {
    RTPROPS  rp;
    HRTPROPS hp;
    RECT     r;
    COLORF   col;

    if (!d2g_Factories() || !c->hwnd || !IsWindow(c->hwnd)) return 0;
    if (c->rt) return 1;
    GetClientRect(c->hwnd, &r);
    if (r.right - r.left < 1 || r.bottom - r.top < 1) return 0;

    rp.type = 0; rp.pf.format = DXGI_B8G8R8A8_UNORM; rp.pf.alphaMode = ALPHA_IGNORE;
    rp.dpiX = 96.0f; rp.dpiY = 96.0f; rp.usage = 0; rp.minLevel = 0;
    hp.hwnd = c->hwnd;
    hp.size.w = (unsigned)(r.right - r.left);
    hp.size.h = (unsigned)(r.bottom - r.top);
    hp.present = 0;
    if (((HRESULT (WINAPI*)(void*, const RTPROPS*, const HRTPROPS*, void**))
         VT(g_d2d)[14])(g_d2d, &rp, &hp, &c->rt) < 0) { c->rt = 0; return 0; }
    c->rtW = r.right - r.left;                     /* what it was built at */
    c->rtH = r.bottom - r.top;

    col.r = col.g = col.b = 0.0f; col.a = 1.0f;
    /* ID2D1RenderTarget::CreateSolidColorBrush - slot 8 */
    ((HRESULT (WINAPI*)(void*, const COLORF*, const void*, void**))
     VT(c->rt)[8])(c->rt, &col, 0, &c->brush);
    applyTextMode(c);                  /* la superficie es nueva: hay que repetirlo */
    return c->brush ? 1 : 0;
}

static void setColour(Grid* c, unsigned int rgb) {
    COLORF col;
    col.r = (float)((rgb >> 16) & 0xFF) / 255.0f;
    col.g = (float)((rgb >>  8) & 0xFF) / 255.0f;
    col.b = (float)( rgb        & 0xFF) / 255.0f;
    col.a = 1.0f;
    ((void (WINAPI*)(void*, const COLORF*))VT(c->brush)[8])(c->brush, &col);  /* SetColor */
}

static void fillRect(Grid* c, float l, float t, float r, float b, unsigned int rgb) {
    RECTF rc;
    rc.l = l; rc.t = t; rc.r = r; rc.b = b;
    setColour(c, rgb);
    ((void (WINAPI*)(void*, const RECTF*, void*))VT(c->rt)[17])(c->rt, &rc, c->brush);
}

/* The colours ABC worked out for this cell, if it worked any out. Paints the
   cell's own background first when there is one, and gives back the colour to
   draw the text in - the row's own when this cell has nothing to say. */
static unsigned int cellColour(Grid* c, int row, int col, int sel,
                               unsigned int rowFore,
                               float l, float t, float r, float b) {
    int* p;
    int  fg = -1, bg = -1;
    /* The cell has the last word, the column speaks if the cell did not, and
       the row is what is left. */
    if (c->cellCol) {
        p  = CELLCOL(c, row, col);
        fg = sel ? p[2] : p[0];
        bg = sel ? p[3] : p[1];
    }
    if (fg < 0) fg = sel ? c->colSFg[col] : c->colFg[col];
    if (bg < 0) bg = sel ? c->colSBg[col] : c->colBg[col];
    if (bg >= 0) fillRect(c, l, t, r, b, (unsigned int)bg);
    return (fg >= 0) ? (unsigned int)fg : rowFore;
}

static void line(Grid* c, float x1, float y1, float x2, float y2, unsigned int rgb) {
    setColour(c, rgb);
    /* DrawLine - slot 15. Two POINT_2F by value = four floats on the stack. */
    ((void (WINAPI*)(void*, float, float, float, float, void*, float, void*))
     VT(c->rt)[15])(c->rt, x1, y1, x2, y2, c->brush, 1.0f, 0);
}

/* One character, given by code point rather than by string. The glyphs on a
   heading are not ASCII, and text() converts from ANSI on the way in, which
   would lose them. DirectWrite falls back to another font by itself if the
   chosen one has no glyph, so these draw on any Windows worth supporting. */
static void glyph(Grid* c, unsigned short ch, float l, float t, float r, float b,
                  unsigned int rgb, void* fmt) {
    WCHAR w[2];
    RECTF rc;
    w[0] = (WCHAR)ch; w[1] = 0;
    rc.l = l; rc.t = t; rc.r = r; rc.b = b;
    setColour(c, rgb);
    ((HRESULT (WINAPI*)(void*, int))VT(fmt)[3])(fmt, DW_CENTER);
    ((HRESULT (WINAPI*)(void*, int))VT(fmt)[5])(fmt, DW_NO_WRAP);
    ((void (WINAPI*)(void*, const WCHAR*, unsigned, void*, const RECTF*, void*, int, int))
     VT(c->rt)[27])(c->rt, w, 1, fmt, &rc, c->brush, D2D_CLIPTEXT, 0);
}

static void text(Grid* c, const char* s, float l, float t, float r, float b,
                 unsigned int rgb, int align, void* fmt, int wrap) {
    WCHAR w[G_TEXT * 2];
    RECTF rc;
    int   n = 0;
    if (!s || !s[0]) return;
    wide(s, w, G_TEXT * 2);
    while (w[n]) n++;
    if (!n) return;
    /* the caller has already reserved the padding it wants */
    rc.l = l; rc.t = t; rc.r = r; rc.b = b;
    setColour(c, rgb);
    /* IDWriteTextFormat::SetTextAlignment - slot 3. Set it per cell rather
       than keeping six formats about; it is a field assignment, not work. */
    ((HRESULT (WINAPI*)(void*, int))VT(fmt)[3])(fmt,
        align == 1 ? DW_TRAILING : (align == 2 ? DW_CENTER : DW_LEADING));
    /* IDWriteTextFormat::SetWordWrapping - slot 5, set the same way and for
       the same reason: it is a field assignment, not work. */
    ((HRESULT (WINAPI*)(void*, int))VT(fmt)[5])(fmt, wrap ? DW_WRAP : DW_NO_WRAP);
    ((void (WINAPI*)(void*, const WCHAR*, unsigned, void*, const RECTF*, void*, int, int))
     VT(c->rt)[27])(c->rt, w, (unsigned)n, fmt, &rc, c->brush, D2D_CLIPTEXT, 0);
}

/* A tick box drawn rather than fetched. Clarion's own is a pair of icons,
   ~BoxOff.ico and ~BoxOn.ico, and honouring those literally would mean
   teaching this file to read .ico files - WIC, another set of interfaces
   declared by hand - for two shapes that are a square and a tick. Drawn here
   they also grow with the row instead of staying sixteen pixels while the
   type gets bigger around them.
   Which icon means ticked is decided on the Clarion side, where the icon
   list's names can be read; by the time it arrives the cell holds '1' or
   '0' and there is nothing left to interpret. */
static void checkBox(Grid* c, int row, int col, float l, float t, float r,
                     float b, unsigned int rgb) {
    const char* s = CELL(c, row, col);
    int   on = (s && s[0] == '1');
    float sz = (b - t) * 0.55f;
    float cx, cy, x0, y0, x1, y1;
    if (sz <  7.0f) sz =  7.0f;
    if (sz > 20.0f) sz = 20.0f;
    cx = (l + r) / 2.0f;  cy = (t + b) / 2.0f;
    x0 = cx - sz / 2.0f;  y0 = cy - sz / 2.0f;
    x1 = x0 + sz;         y1 = y0 + sz;
    line(c, x0, y0, x1, y0, rgb);
    line(c, x1, y0, x1, y1, rgb);
    line(c, x1, y1, x0, y1, rgb);
    line(c, x0, y1, x0, y0, rgb);
    if (on) {
        line(c, x0 + sz * 0.22f, cy, cx - sz * 0.04f, y1 - sz * 0.24f, rgb);
        line(c, cx - sz * 0.04f, y1 - sz * 0.24f, x1 - sz * 0.16f, y0 + sz * 0.24f, rgb);
    }
}

/* One cell: its colour worked out, then either a tick box or its text. The
   three places that draw a cell - scrolling, frozen, and frozen inside a
   group - all come through here, so the padding is in one place. */
static void cellOut(Grid* c, int row, int col, int sel, unsigned int rowFore,
                    float l, float t, float r, float b, int align) {
    unsigned int fore = cellColour(c, row, col, sel, rowFore, l, t, r, b);
    if (c->colCheck[col]) { checkBox(c, row, col, l, t, r, b, fore); return; }
    text(c, CELL(c, row, col), l + 4.0f, t + 1.0f, r - 4.0f, b,
         fore, align, c->fmt, c->wrap);
}

/* ---- the paint -----------------------------------------------------------
   Frozen columns are drawn LAST, on top, and the scrolling ones are clipped to
   the right of them. Drawn in plain left-to-right order the scrolling columns
   come after the frozen ones and paint straight over them, which is exactly
   what you see if you freeze two columns and scroll: the third slides over the
   first two instead of under them.                                          */
static void d2g_Draw(Grid* c) {
    RECT  r;
    RECTF clip;
    int   i, col, x, fx, rowsDrawn, absRow, frozenW, barW, lineH;
    float top, bot, cl, cr;

    if (!c->rt && !d2g_MakeTarget(c)) return;
    GetClientRect(c->hwnd, &r);
    barW = c->vBar ? barTakes(c) : 0;
    r.right  -= barW;                      /* the columns stop at the scrollbar */
    r.bottom -= c->hBar ? barTakes(c) : 0; /* and the rows stop above one       */
    r.bottom -= c->footH;                  /* and above the totals, if there are */

    lineH = (c->lines > 1) ? (c->rowH / c->lines) : c->rowH;
    frozenW = 0;
    if (c->grps) {                               /* frozen counts GROUPS, not fields */
        for (col = 0; col < c->frozen && col < c->grps; col++) frozenW += c->grpW[col];
    } else {
        for (col = 0; col < c->frozen && col < c->cols; col++) frozenW += c->colW[col];
    }

    ((void (WINAPI*)(void*))VT(c->rt)[48])(c->rt);                     /* BeginDraw */
    {
        COLORF bg;
        bg.r = (float)((c->cBack >> 16) & 0xFF) / 255.0f;
        bg.g = (float)((c->cBack >>  8) & 0xFF) / 255.0f;
        bg.b = (float)( c->cBack        & 0xFF) / 255.0f;
        bg.a = 1.0f;
        ((void (WINAPI*)(void*, const COLORF*))VT(c->rt)[47])(c->rt, &bg);   /* Clear */
    }

    /* everything below the header is clipped, so a part-row at the top cannot
       paint over the titles - that is what makes pixel scrolling possible */
    clip.l = 0.0f; clip.t = (float)c->hdrH;
    clip.r = (float)r.right; clip.b = (float)r.bottom;
    ((void (WINAPI*)(void*, const RECTF*, int))VT(c->rt)[45])(c->rt, &clip, AA_ALIASED);

    rowsDrawn = c->visRows;
    for (i = 0; i < rowsDrawn; i++) {
        unsigned int back, fore;
        top = (float)(c->hdrH + i * c->rowH - c->scrollY);
        bot = top + c->rowH;
        if (bot < (float)c->hdrH) continue;
        if (top > (float)r.bottom) break;
        absRow = c->firstRow + i;
        if (absRow == c->selRow)      { back = c->cSelBack; fore = c->cSelText; }
        else if (i & 1)               { back = c->cBand;    fore = c->cText;    }
        else                          { back = c->cBack;    fore = c->cText;    }
        fillRect(c, 0.0f, top, (float)r.right, bot, back);

        /* --- the scrolling columns, kept off the frozen strip -------------- */
        clip.l = (float)frozenW; clip.t = top;
        clip.r = (float)r.right; clip.b = bot;
        ((void (WINAPI*)(void*, const RECTF*, int))VT(c->rt)[45])(c->rt, &clip, AA_ALIASED);
        x = -c->scrollX;
        for (col = 0; col < c->cols; col++) {
            float ty, tb;
            if (c->grps) {                       /* grouped: it says where it goes */
                if (c->colGrp[col] < c->frozen) continue;   /* drawn with the frozen block */
                cl = (float)(c->colX[col] - c->scrollX);
                ty = top + (float)(c->colLine[col] * lineH);
                tb = ty + (float)lineH;
            } else {
                cl = (float)x;
                ty = top;
                tb = bot;
            }
            cr = cl + c->colW[col];
            if ((c->grps || col >= c->frozen) && cr > (float)frozenW && cl < (float)r.right)
                cellOut(c, i, col, absRow == c->selRow, fore,
                        cl, ty, cr, tb, c->colAlign[col]);
            x += c->colW[col];
        }
        ((void (WINAPI*)(void*))VT(c->rt)[46])(c->rt);

        /* --- then the frozen ones, on top of them ------------------------- */
        if (c->frozen > 0) {
            fillRect(c, 0.0f, top, (float)frozenW, bot, back);         /* wipe what slid under */
            clip.l = 0.0f; clip.t = top; clip.r = (float)frozenW; clip.b = bot;
            ((void (WINAPI*)(void*, const RECTF*, int))VT(c->rt)[45])(c->rt, &clip, AA_ALIASED);
            if (c->grps) {
                for (col = 0; col < c->cols; col++) {
                    float ty;
                    if (c->colGrp[col] >= c->frozen) continue;
                    ty = top + (float)(c->colLine[col] * lineH);
                    cellOut(c, i, col, absRow == c->selRow, fore,
                            (float)c->colX[col], ty,
                            (float)(c->colX[col] + c->colW[col]), ty + (float)lineH,
                            c->colAlign[col]);
                }
            } else {
                fx = 0;
                for (col = 0; col < c->frozen && col < c->cols; col++) {
                    cellOut(c, i, col, absRow == c->selRow, fore,
                            (float)fx, top, (float)(fx + c->colW[col]), bot,
                            c->colAlign[col]);
                    fx += c->colW[col];
                }
            }
            ((void (WINAPI*)(void*))VT(c->rt)[46])(c->rt);
        }
        line(c, 0.0f, bot - 0.5f, (float)r.right, bot - 0.5f, c->cGrid);
    }
    ((void (WINAPI*)(void*))VT(c->rt)[46])(c->rt);                     /* done with the rows */

    /* ---- the column lines, scrolling ones clipped the same way ---------- */
    clip.l = (float)frozenW; clip.t = 0.0f;
    clip.r = (float)r.right; clip.b = (float)r.bottom;
    ((void (WINAPI*)(void*, const RECTF*, int))VT(c->rt)[45])(c->rt, &clip, AA_ALIASED);
    if (c->grps) {
        for (col = c->frozen; col < c->grps; col++) {
            x = c->grpX[col] + c->grpW[col] - c->scrollX;
            if ((float)x > (float)frozenW && (float)x < (float)r.right)
                line(c, (float)x - 0.5f, 0.0f, (float)x - 0.5f, (float)r.bottom, c->cGrid);
        }
    } else {
        x = -c->scrollX;
        for (col = 0; col < c->cols; col++) {
            x += c->colW[col];
            if (col >= c->frozen && (float)x > (float)frozenW && (float)x < (float)r.right)
                line(c, (float)x - 0.5f, 0.0f, (float)x - 0.5f, (float)r.bottom, c->cGrid);
        }
    }
    ((void (WINAPI*)(void*))VT(c->rt)[46])(c->rt);

    /* ---- the header, over the rows -------------------------------------- */
    fillRect(c, 0.0f, 0.0f, (float)r.right, (float)c->hdrH, c->cHdrBack);
    clip.l = (float)frozenW; clip.t = 0.0f;
    clip.r = (float)r.right; clip.b = (float)c->hdrH;
    ((void (WINAPI*)(void*, const RECTF*, int))VT(c->rt)[45])(c->rt, &clip, AA_ALIASED);
    if (c->grps) {
        int hLine = (c->lines > 1) ? (c->hdrH / c->lines) : c->hdrH;
        for (col = c->frozen; col < c->grps; col++) {          /* the group, spanning */
            cl = (float)(c->grpX[col] - c->scrollX);
            cr = cl + c->grpW[col];
            if (cr > (float)frozenW && cl < (float)r.right) {
                text(c, c->grpTitle[col], cl + 4.0f, 2.0f,
                     cr - (c->btns ? (float)(D2G_BTNW + 6) : 4.0f), (float)c->hdrH,
                     c->cHdrText, 2, c->fmtHdr, 0);
                if (c->btns) {
                    int scol, sdir = 0, fcol = 0, i;
                    for (i = 0; i < c->cols; i++) if (c->colGrp[i] == col) {
                        if (i == c->sortCol)   sdir = c->sortDir;
                        if (c->colFilt[i]) fcol = 1;
                    }
                    scol = sdir;
                    filterBtn(c, cr, (float)(c->hdrH / 2), c->cHdrText,
                              fcol ? c->cSelBack : c->cHdrBack, scol, fcol);
                }
                line(c, cr - 0.5f, 0.0f, cr - 0.5f, (float)c->hdrH, c->cGrid);
            }
        }
        for (col = 0; col < c->cols; col++) {                  /* and each column's own */
            float hy;
            if (c->colGrp[col] < c->frozen) continue;
            cl = (float)(c->colX[col] - c->scrollX);
            cr = cl + c->colW[col];
            hy = (float)(c->colLine[col] * hLine);
            if (cr > (float)frozenW && cl < (float)r.right)
                text(c, c->colTitle[col], cl + 4.0f, hy + 2.0f, cr - 4.0f, hy + (float)hLine,
                     c->cHdrText, c->colAlign[col], c->fmtHdr, 0);
        }
    }
    x = -c->scrollX;
    for (col = 0; col < c->cols && !c->grps; col++) {
        cl = (float)x;
        cr = cl + c->colW[col];
        if (col >= c->frozen && cr > (float)frozenW && cl < (float)r.right) {
            int   bon = BTNON(c, col);
            float bw = bon ? (float)(D2G_BTNW + 4) : 0.0f;
            float tr = cr - bw - ((!bon && col == c->sortCol) ? 14.0f : 4.0f);
            text(c, c->colTitle[col], cl + 4.0f, 2.0f, tr, (float)c->hdrH,
                 c->cHdrText, c->colAlign[col], c->fmtHdr, 0);
            if (bon)
                filterBtn(c, cr, (float)(c->hdrH / 2), c->cHdrText,
                          c->colFilt[col] ? c->cSelBack : c->cHdrBack,
                          (col == c->sortCol) ? c->sortDir : 0,
                          c->colFilt[col]);
            else if (col == c->sortCol)
                sortMark(c, cr, (float)(c->hdrH / 2) - 2.0f, c->sortDir, c->cHdrText);
            line(c, cr - 0.5f, 0.0f, cr - 0.5f, (float)c->hdrH, c->cGrid);
        }
        x += c->colW[col];
    }
    ((void (WINAPI*)(void*))VT(c->rt)[46])(c->rt);

    if (c->frozen > 0) {                                    /* frozen headings on top */
        fillRect(c, 0.0f, 0.0f, (float)frozenW, (float)c->hdrH, c->cHdrBack);
        clip.l = 0.0f; clip.t = 0.0f; clip.r = (float)frozenW; clip.b = (float)c->hdrH;
        ((void (WINAPI*)(void*, const RECTF*, int))VT(c->rt)[45])(c->rt, &clip, AA_ALIASED);
        if (c->grps) {
            int hLine = (c->lines > 1) ? (c->hdrH / c->lines) : c->hdrH;
            for (col = 0; col < c->frozen && col < c->grps; col++) {
                float ge = (float)(c->grpX[col] + c->grpW[col]);
                text(c, c->grpTitle[col], (float)c->grpX[col] + 4.0f, 2.0f, ge - 4.0f,
                     (float)c->hdrH, c->cHdrText, 2, c->fmtHdr, 0);
                line(c, ge - 0.5f, 0.0f, ge - 0.5f, (float)c->hdrH, c->cGrid);
            }
            for (col = 0; col < c->cols; col++) {
                float hy;
                if (c->colGrp[col] >= c->frozen) continue;
                hy = (float)(c->colLine[col] * hLine);
                text(c, c->colTitle[col], (float)c->colX[col] + 4.0f, hy + 2.0f,
                     (float)(c->colX[col] + c->colW[col]) - 4.0f, hy + (float)hLine,
                     c->cHdrText, c->colAlign[col], c->fmtHdr, 0);
            }
        }
        fx = 0;
        for (col = 0; col < c->frozen && col < c->cols && !c->grps; col++) {
            float cre = (float)(fx + c->colW[col]);
            {
                int   bon = BTNON(c, col);
                float bw = bon ? (float)(D2G_BTNW + 4) : 0.0f;
                text(c, c->colTitle[col], (float)fx + 4.0f, 2.0f,
                     cre - bw - ((!bon && col == c->sortCol) ? 14.0f : 4.0f), (float)c->hdrH,
                     c->cHdrText, c->colAlign[col], c->fmtHdr, 0);
                if (bon)
                    filterBtn(c, cre, (float)(c->hdrH / 2), c->cHdrText,
                              c->colFilt[col] ? c->cSelBack : c->cHdrBack,
                              (col == c->sortCol) ? c->sortDir : 0,
                              c->colFilt[col]);
                else if (col == c->sortCol)
                    sortMark(c, cre, (float)(c->hdrH / 2) - 2.0f, c->sortDir, c->cHdrText);
            }
            fx += c->colW[col];
            line(c, (float)fx - 0.5f, 0.0f, (float)fx - 0.5f, (float)c->hdrH, c->cGrid);
        }
        ((void (WINAPI*)(void*))VT(c->rt)[46])(c->rt);
        /* the edge of the frozen block, so it reads as a seam */
        line(c, (float)frozenW - 0.5f, 0.0f, (float)frozenW - 0.5f, (float)r.bottom, c->cGrid);
    }
    line(c, 0.0f, (float)c->hdrH - 0.5f, (float)r.right, (float)c->hdrH - 0.5f, c->cGrid);

    /* ---- the row of totals, along the bottom -----------------------------
       Laid out from the same numbers as the header - same widths, same frozen
       block, same sideways offset - because a total that does not sit under
       its column is worse than no total at all. Grouped formats are left
       alone: there a column is not a column but a field somewhere inside a
       record, and there is no single line along the bottom that means
       anything. */
    if (c->footH > 0 && c->footTxt && !c->grps) {
        float ft = (float)r.bottom;
        float fb = ft + (float)c->footH;
        fillRect(c, 0.0f, ft, (float)r.right, fb, c->cHdrBack);
        line(c, 0.0f, ft + 0.5f, (float)r.right, ft + 0.5f, c->cGrid);
        clip.l = (float)frozenW; clip.t = ft;
        clip.r = (float)r.right; clip.b = fb;
        ((void (WINAPI*)(void*, const RECTF*, int))VT(c->rt)[45])(c->rt, &clip, AA_ALIASED);
        x = -c->scrollX;
        for (col = 0; col < c->cols; col++) {
            cl = (float)x;
            cr = cl + c->colW[col];
            if (col >= c->frozen && cr > (float)frozenW && cl < (float)r.right)
                text(c, FOOT(c, col), cl + 4.0f, ft + 1.0f, cr - 4.0f, fb,
                     c->cHdrText, c->colAlign[col], c->fmtHdr, 0);
            x += c->colW[col];
        }
        ((void (WINAPI*)(void*))VT(c->rt)[46])(c->rt);
        if (c->frozen > 0) {
            fillRect(c, 0.0f, ft + 1.0f, (float)frozenW, fb, c->cHdrBack);
            fx = 0;
            for (col = 0; col < c->frozen && col < c->cols; col++) {
                text(c, FOOT(c, col), (float)fx + 4.0f, ft + 1.0f,
                     (float)(fx + c->colW[col]) - 4.0f, fb,
                     c->cHdrText, c->colAlign[col], c->fmtHdr, 0);
                fx += c->colW[col];
            }
        }
    }

    /* ---- the scrollbars, drawn last so nothing paints over them ---------
       An overlay is drawn ON TOP of the rows rather than beside them, so it
       measures against the full client area, takes no width from the data, and
       appears only while the pointer is over the grid. */
    {
        RECT  full;
        int   thick = barThick(c);
        int   over  = (c->barStyle == 2);
        int   vis   = (!over || c->barsShow);
        GetClientRect(c->hwnd, &full);
        if (c->vBar && vis) {
            int   top, len, tTop, tLen;
            float bl = (float)(full.right - thick), br = (float)full.right;
            d2g_VGeom(c, &top, &len, &tTop, &tLen);
            if (!over) {
                fillRect(c, bl, 0.0f, br, (float)full.bottom, c->cBand);
                line(c, bl + 0.5f, 0.0f, bl + 0.5f, (float)full.bottom, c->cGrid);
            }
            fillRect(c, bl + 2.0f, (float)tTop + 2.0f,
                        br - 2.0f, (float)(tTop + tLen) - 2.0f, c->cHdrBack);
        }
        if (c->hBar && vis) {
            int   left, len, tLeft, tLen;
            float bt = (float)(full.bottom - thick), bb = (float)full.bottom;
            d2g_HGeom(c, &left, &len, &tLeft, &tLen);
            if (!over) {
                fillRect(c, 0.0f, bt, (float)full.right, bb, c->cBand);
                line(c, 0.0f, bt + 0.5f, (float)full.right, bt + 0.5f, c->cGrid);
            }
            fillRect(c, (float)tLeft + 2.0f, bt + 2.0f,
                        (float)(tLeft + tLen) - 2.0f, bb - 2.0f, c->cHdrBack);
        }
    }

    if (((HRESULT (WINAPI*)(void*, void*, void*))VT(c->rt)[49])(c->rt, 0, 0) < 0) {
        if (c->brush) { ((unsigned long (WINAPI*)(void*))VT(c->brush)[2])(c->brush); c->brush = 0; }
        if (c->rt)    { ((unsigned long (WINAPI*)(void*))VT(c->rt)[2])(c->rt);       c->rt = 0; }
        InvalidateRect(c->hwnd, 0, 0);
    }
}

static long WINAPI d2g_WndProc(HWND h, UINT msg, UINT wp, long lp) {
    int i;
    Grid* c = 0;
    char ps[128];
    for (i = 1; i <= G_MAX; i++) if (g_g[i].used && g_g[i].hwnd == h) { c = &g_g[i]; break; }
    if (!c) return DefWindowProcA(h, msg, wp, lp);
    if (msg == WM_PAINT)      { BeginPaint(h, ps); d2g_Draw(c); EndPaint(h, ps); return 0; }
    if (msg == WM_ERASEBKGND) return 1;
    return CallWindowProcA(c->oldProc, h, msg, wp, lp);
}

/* ========================================================================== */
/*  What Clarion calls                                                        */
/* ========================================================================== */

int d2g_Available(void) { return d2g_Factories() ? 1 : 0; }

int d2g_Attach(void* hwnd, const char* face, int pt) {
    int i;
    Grid* c;
    if (!hwnd || !IsWindow((HWND)hwnd) || !d2g_Factories()) return 0;
    for (i = 1; i <= G_MAX; i++) if (!g_g[i].used) break;
    if (i > G_MAX) return 0;
    c = &g_g[i];
    c->used = 1; c->hwnd = (HWND)hwnd; c->rt = 0; c->brush = 0;
    c->cells = 0; c->rowCap = 0; c->colCap = 0; c->cellCol = 0;
    c->footH = 0; c->footTxt = 0; c->footCap = 0;
    { int k; for (k = 0; k < G_COLS; k++) {
        c->colCheck[k] = 0;
        c->colFg[k] = -1; c->colBg[k] = -1;
        c->colSFg[k] = -1; c->colSBg[k] = -1; } }
    c->sortCol = -1; c->sortDir = 1;
    { int k; for (k = 0; k < G_COLS; k++) c->colFilt[k] = 0; }
    c->grps = 0; c->lines = 1; c->wrapLines = 1; c->btns = 0;
    c->barStyle = 0; c->hBar = 0; c->barsShow = 0; c->gdiText = 0;
    c->cols = 0; c->frozen = 0; c->visRows = 0; c->firstRow = 0;
    c->totalRows = 0; c->selRow = -1; c->scrollX = 0;
    c->rowH = D2G_ROWFOR(pt); c->hdrH = D2G_HDRFOR(pt);
    c->cBack = 0xFFFFFF; c->cBand = 0xF5F7FA; c->cGrid = 0xE1E5EA;
    c->cText = 0x1F2933; c->cHdrBack = 0x2B3A4A; c->cHdrText = 0xFFFFFF;
    c->cSelBack = 0x2F6FB5; c->cSelText = 0xFFFFFF;
    if (!d2g_MakeTarget(c)) { c->used = 0; return 0; }
    c->fmt     = d2g_Font(face, (float)pt, 0);
    c->fmtHdr  = d2g_Font(face, (float)pt, 1);
    /* Segoe MDL2 Assets is on Windows 10, Segoe Fluent Icons on 11; whichever
       resolves, the funnel is at the same code point. If neither is there
       DirectWrite falls back and the filled button still says it is filtered,
       so nothing depends on this being found. */
    c->fmtIcon = d2g_Font("Segoe MDL2 Assets", (float)pt, 0);
    if (!c->fmt || !c->fmtHdr) { c->used = 0; return 0; }
    c->wrap = 0; c->wrapLines = 1;
    { int k; for (k = 0; k < 63 && face[k]; k++) c->face[k] = face[k]; c->face[k] = 0; }
    c->pt = pt;
    c->oldProc = (WNDPROC)GetWindowLongA((HWND)hwnd, GWL_WNDPROC);
    SetWindowLongA((HWND)hwnd, GWL_WNDPROC, (long)d2g_WndProc);
    return i;
}

void d2g_Detach(int h) {
    Grid* c = slot(h);
    if (!c) return;
    if (c->oldProc && IsWindow(c->hwnd))
        SetWindowLongA(c->hwnd, GWL_WNDPROC, (long)c->oldProc);
    if (c->brush)  ((unsigned long (WINAPI*)(void*))VT(c->brush)[2])(c->brush);
    if (c->fmtIcon)((unsigned long (WINAPI*)(void*))VT(c->fmtIcon)[2])(c->fmtIcon);
    if (c->fmt)    ((unsigned long (WINAPI*)(void*))VT(c->fmt)[2])(c->fmt);
    if (c->fmtHdr) ((unsigned long (WINAPI*)(void*))VT(c->fmtHdr)[2])(c->fmtHdr);
    if (c->rt)     ((unsigned long (WINAPI*)(void*))VT(c->rt)[2])(c->rt);
    if (c->cells)   LocalFree(c->cells);
    if (c->cellCol) LocalFree(c->cellCol);
    if (c->footTxt) LocalFree(c->footTxt);
    c->cells = 0; c->rowCap = 0; c->colCap = 0; c->cellCol = 0;
    c->footH = 0; c->footTxt = 0; c->footCap = 0;
    c->used = 0; c->hwnd = 0; c->rt = 0; c->brush = 0;
}

/* ---- shape ---------------------------------------------------------------- */
void d2g_Columns(int h, int n) {
    Grid* c = slot(h);
    if (!c) return;
    if (n < 0) n = 0;
    if (n > G_COLS) n = G_COLS;
    if (n > 0 && !ensureCells(c, c->rowCap, n) && n > c->colCap) n = c->colCap;
    c->cols = n;
}

void d2g_Column(int h, int col, int width, int align, const char* title) {
    Grid* c = slot(h);
    int i;
    if (!c || col < 0 || col >= G_COLS) return;
    /* Anything ELSE said about this column starts again from nothing here.
       Not in d2g_Columns: that is called with the total AFTER the loop that
       describes each one, so clearing there wiped every flag the loop had
       just set - the tick boxes came out as their raw 1 and 0, and the
       column colours quietly did nothing at all. Per column there is no
       order to get wrong. */
    c->colCheck[col] = 0;
    c->colFg[col]  = -1; c->colBg[col]  = -1;
    c->colSFg[col] = -1; c->colSBg[col] = -1;
    c->colW[col] = width < 8 ? 8 : width;
    c->colAlign[col] = align;
    for (i = 0; i < G_TEXT - 1 && title && title[i]; i++) c->colTitle[col][i] = title[i];
    c->colTitle[col][i] = 0;
}

void d2g_Frozen(int h, int n)      { Grid* c = slot(h); if (c) c->frozen = n; }
/* A row can never be shorter than the type needs. Whatever asks - the LIST's
   line height, the developer's own setting - it is clamped here, because the
   alternative is big type crammed into short rows with its descenders cut off
   by the row below, and there are several paths that can ask. One place, once,
   instead of trusting all of them to have thought about it. */
void d2g_RowHeight(int h, int px) {
    Grid* c = slot(h);
    int   need;
    if (!c || px <= 4) return;
    need = D2G_ROWH(c);
    c->rowH = px < need ? need : px;
}

/* what the type needs, so the Clarion side can keep the LIST in step */
int d2g_RowNeed(int h) { Grid* c = slot(h); return c ? D2G_ROWH(c) : 0; }
void d2g_HeaderHeight(int h,int px){
    Grid* c = slot(h);
    int   need;
    if (!c || px < 0) return;
    need = D2G_HDRFOR(c->pt);
    c->hdrH = (px && px < need) ? need : px;   /* 0 means no heading at all */
}
void d2g_Total(int h, int n)       { Grid* c = slot(h); if (c) c->totalRows = n; }
void d2g_Select(int h, int row)    { Grid* c = slot(h); if (c) c->selRow = row; }
void d2g_ScrollX(int h, int x)     { Grid* c = slot(h); if (c) c->scrollX = x < 0 ? 0 : x; }
void d2g_ScrollY(int h, int y)     { Grid* c = slot(h); if (c) c->scrollY = y < 0 ? 0 : y; }
int  d2g_RowH(int h)               { Grid* c = slot(h); return c ? c->rowH : 0; }
int  d2g_HeaderH(int h)            { Grid* c = slot(h); return c ? c->hdrH : 0; }

void d2g_Colours(int h, unsigned int back, unsigned int band, unsigned int grid,
                 unsigned int txt, unsigned int hdrBack, unsigned int hdrText,
                 unsigned int selBack, unsigned int selText) {
    Grid* c = slot(h);
    if (!c) return;
    c->cBack = back; c->cBand = band; c->cGrid = grid; c->cText = txt;
    c->cHdrBack = hdrBack; c->cHdrText = hdrText;
    c->cSelBack = selBack; c->cSelText = selText;
}

/* ---- the page of rows Clarion pushes in ---------------------------------- */
void d2g_Page(int h, int firstRow, int rows) {
    Grid* c = slot(h);
    if (!c) return;
    if (rows < 0) rows = 0;
    if (rows > G_MAXROWS) rows = G_MAXROWS;
    if (rows > 0) ensureCells(c, rows, c->cols);
    if (rows > c->rowCap) rows = c->rowCap;   /* refused: draw what fits */
    c->firstRow = firstRow;
    c->visRows  = rows;
}

void d2g_Cell(int h, int visRow, int col, const char* s) {
    Grid* c = slot(h);
    int i;
    char* d;
    if (!c || !c->cells) return;
    if (visRow < 0 || visRow >= c->rowCap || col < 0 || col >= c->colCap) return;
    d = CELL(c, visRow, col);
    for (i = 0; i < G_TEXT - 1 && s && s[i]; i++) d[i] = s[i];
    d[i] = 0;
}

void d2g_Repaint(int h) { Grid* c = slot(h); if (c) InvalidateRect(c->hwnd, 0, 0); }

int d2g_PaintNow(int h) { Grid* c = slot(h); if (!c) return 0; d2g_Draw(c); return 1; }

/* Cheap enough to call whenever anything MIGHT have changed the client area -
   it does nothing at all unless it actually did. That matters because a
   scrollbar appearing or disappearing resizes the client area behind your
   back: hide the horizontal bar and the client grows by its height, and the
   strip it vacated is not covered by the render target until this has run. */
/* The four colours ABC put in its queue for this cell. All four negative -
   the row where no condition fired - says nothing, and deliberately does NOT
   bring the colour block into existence: a browse whose conditions never fire
   should not pay for a block full of -1. */
/* The colours the formatter put on a whole column. -1 for any of them means
   the column says nothing about it. */
/* The footer is as tall as a row: it IS a row, in every way that matters to
   the eye. Off is 0, which every reader of footH takes as 'no footer'. */
void d2g_Footer(int h, int on) {
    Grid* c = slot(h);
    if (!c) return;
    c->footH = on ? c->rowH : 0;
    if (on) ensureFoot(c);
}

void d2g_FootCell(int h, int col, const char* s) {
    Grid* c = slot(h);
    char* d;
    int   i;
    if (!c || col < 0) return;
    if (!ensureFoot(c)) return;
    if (col >= c->footCap) return;
    d = FOOT(c, col);
    for (i = 0; i < G_TEXT - 1 && s && s[i]; i++) d[i] = s[i];
    d[i] = 0;
}

void d2g_CheckCol(int h, int col, int on) {
    Grid* c = slot(h);
    if (!c || col < 0 || col >= G_COLS) return;
    c->colCheck[col] = on ? 1 : 0;
}

void d2g_ColumnColour(int h, int col, int fg, int bg, int sfg, int sbg) {
    Grid* c = slot(h);
    if (!c || col < 0 || col >= G_COLS) return;
    c->colFg[col]  = fg;  c->colBg[col]  = bg;
    c->colSFg[col] = sfg; c->colSBg[col] = sbg;
}

void d2g_CellColour(int h, int visRow, int col, int nfg, int nbg, int sfg, int sbg) {
    Grid* c = slot(h);
    int*  p;
    if (!c || !c->cells) return;
    if (visRow < 0 || visRow >= c->rowCap || col < 0 || col >= c->colCap) return;
    if (nfg < 0 && nbg < 0 && sfg < 0 && sbg < 0) {
        if (!c->cellCol) return;
    } else if (!ensureColours(c)) return;
    p = CELLCOL(c, visRow, col);
    p[0] = nfg; p[1] = nbg; p[2] = sfg; p[3] = sbg;
}

int d2g_Resize(int h) {
    Grid* c = slot(h);
    RECT  r;
    SIZEU s;
    if (!c) return 0;
    if (!c->rt && !d2g_MakeTarget(c)) return 0;
    GetClientRect(c->hwnd, &r);
    s.w = (unsigned)(r.right - r.left);
    s.h = (unsigned)(r.bottom - r.top);
    if (s.w < 1 || s.h < 1) return 0;
    if ((int)s.w == c->rtW && (int)s.h == c->rtH) return 1;    /* nothing moved */
    ((HRESULT (WINAPI*)(void*, const SIZEU*))VT(c->rt)[58])(c->rt, &s);
    c->rtW = (int)s.w;
    c->rtH = (int)s.h;
    InvalidateRect(c->hwnd, 0, 0);
    return 1;
}

/* how many whole rows fit below the header - what the Clarion side needs to
   know to fill a page */
/* how wide every column is together, and how wide the view is - what a
   horizontal scrollbar needs to size itself */
int d2g_TotalWidth(int h) {
    Grid* c = slot(h);
    int col, w = 0;
    if (!c) return 0;
    if (c->grps) {
        for (col = 0; col < c->grps; col++) w += c->grpW[col];
        return w;
    }
    for (col = 0; col < c->cols; col++) w += c->colW[col];
    return w;
}

int d2g_ViewWidth(int h) {
    Grid* c = slot(h);
    RECT  r;
    if (!c || !IsWindow(c->hwnd)) return 0;
    GetClientRect(c->hwnd, &r);
    if (c->vBar) r.right -= barTakes(c);
    return (int)(r.right - r.left);
}

int d2g_PageSize(int h) {
    Grid* c = slot(h);
    RECT  r;
    if (!c || !IsWindow(c->hwnd)) return 0;
    GetClientRect(c->hwnd, &r);
    if (c->rowH < 1) return 0;
    /* The horizontal bar takes its height off the rows, exactly as d2g_Draw
       does ("the rows stop above one"), as d2g_HitRow does when it decides a
       point is in the footer, and as d2g_VGeom does when it measures the
       trough. This was the one of the four that did not, and the Clarion side
       sizes the browse through it: BG:Items asks how many rows fit and sets
       the LIST line height so ABC loads that many. One too many meant the
       last record was loaded, drawn, and then clipped away behind the bar -
       selectable with the arrow key and impossible to see.
       barTakes is 0 for the overlay style, which floats over the rows and
       therefore takes nothing, so this costs that style nothing. */
    return (int)((r.bottom - r.top - c->hdrH - c->footH
                  - (c->hBar ? barTakes(c) : 0)) / c->rowH);
}

/* which row and column a point landed on; row is absolute, -1 for the header */
int d2g_HitRow(int h, int y) {
    Grid* c = slot(h);
    RECT  r;
    if (!c) return -1;
    if (y < c->hdrH) return -1;
    /* The totals are not a record and cannot be clicked into one. Without
       this the arithmetic below happily returns a row number for a point
       inside the footer, and the browse would select whatever it landed on. */
    if (c->footH > 0 && IsWindow(c->hwnd)) {
        GetClientRect(c->hwnd, &r);
        if (y >= r.bottom - c->footH - (c->hBar ? barTakes(c) : 0)) return -1;
    }
    return c->firstRow + (int)((y - c->hdrH + c->scrollY) / c->rowH);
}

/* Which column's RIGHT edge is under x, within a few pixels - the grab handle
   for resizing. Frozen columns keep their own edges, unscrolled. -1 for none. */
int d2g_HitEdge(int h, int x) {
    Grid* c = slot(h);
    int col, at, fx = 0;
    const int grab = 4;
    if (!c || c->grps) return -1;     /* grouped: the fields inside would have to move too */
    for (col = 0; col < c->frozen && col < c->cols; col++) {
        fx += c->colW[col];
        if (x >= fx - grab && x <= fx + grab) return col;
    }
    at = -c->scrollX;
    for (col = 0; col < c->cols; col++) {
        at += c->colW[col];
        if (col >= c->frozen && at > fx && x >= at - grab && x <= at + grab) return col;
    }
    return -1;
}

/* Which grid is drawn on this window? A scrollbar callback is handed an HWND
   and nothing else, and it has to be able to reach the grid from there. */
int d2g_FromHwnd(void* hwnd) {
    int i;
    for (i = 1; i <= G_MAX; i++)
        if (g_g[i].used && g_g[i].hwnd == (HWND)hwnd) return i;
    return 0;
}

/* ---- grouped formats ---------------------------------------------------- */
void d2g_Lines(int h, int n) {
    Grid* c = slot(h);
    if (!c || n < 1 || n > 8) return;
    c->lines = n;
    c->rowH  = D2G_ROWH(c);
    c->hdrH  = D2G_HDRFOR(c->pt) * n;          /* the headings stack the same way */
}

/* Long text runs onto another line instead of being cut off, and every row
   grows to suit. The wrapping itself is DirectWrite's - the only difference is
   which text format the cell is drawn with. */
void d2g_Wrap(int h, int on, int lines) {
    Grid* c = slot(h);
    if (!c) return;
    if (lines < 1) lines = 1;
    if (lines > 4) lines = 4;
    c->wrap      = on ? 1 : 0;
    c->wrapLines = on ? lines : 1;
    c->rowH      = D2G_ROWH(c);
}

void d2g_Groups(int h, int n) {
    Grid* c = slot(h);
    if (!c || n < 0 || n > G_COLS) return;
    c->grps = n;
}

void d2g_Group(int h, int gi, int x, int width, const char* title) {
    Grid* c = slot(h);
    int   k;
    if (!c || gi < 0 || gi >= G_COLS) return;
    c->grpX[gi]  = x;
    c->grpW[gi]  = width;
    c->grpOw[gi] = width;               /* what the fields inside were sized against */
    for (k = 0; k < G_TEXT - 1 && title[k]; k++) c->grpTitle[gi][k] = title[k];
    c->grpTitle[gi][k] = 0;
}

/* A column that says where it goes: which group, which line of the record, how
   far across, how wide. The title is the group's, so it is not repeated here. */
void d2g_ColumnAt(int h, int col, int grp, int line, int x, int width, int align,
                  const char* title) {
    Grid* c = slot(h);
    int   k;
    if (!c || col < 0 || col >= G_COLS) return;
    c->colGrp[col]   = grp;
    c->colLine[col]  = line;
    c->colX[col]     = x;
    c->colW[col]     = width;
    c->colAlign[col] = align;
    c->colOx[col] = (grp >= 0 && grp < G_COLS) ? (x - c->grpX[grp]) : 0;
    c->colOw[col] = width;
    /* Its OWN heading, if it has one. In a grouped format most of the words in
       the header belong to the columns, not the groups - "Last Name", "Major",
       "Grad Year" are the columns', and only "Address" and "Telephone" are
       their groups'. Drawing group headings alone leaves the first group blank,
       which is exactly what it did. */
    for (k = 0; k < G_TEXT - 1 && title && title[k]; k++) c->colTitle[col][k] = title[k];
    c->colTitle[col][k] = 0;
}

void d2g_SortMark(int h, int col, int dir) {
    Grid* c = slot(h);
    if (!c) return;
    c->sortCol = col;
    c->sortDir = dir < 0 ? -1 : 1;
}

void d2g_FilterBtns(int h, int on) {
    Grid* c = slot(h);
    if (c) c->btns = on ? 1 : 0;
}

/* Mark a column as filtered, or unmark it. col < 0 clears the lot, which is
   what "clear all filters" wants and what a fresh grid starts from. */
void d2g_FilterOn(int h, int col, int on) {
    Grid* c = slot(h);
    int   k;
    if (!c) return;
    if (col < 0) {
        for (k = 0; k < G_COLS; k++) c->colFilt[k] = 0;
        return;
    }
    if (col < G_COLS) c->colFilt[col] = on ? 1 : 0;
}

/* Excel's little boxed arrow at the right of a heading, and the one place the
   column says what it is doing. There is no second sort arrow beside the title
   any more - two arrows in the same corner meaning different things is worse
   than one that means something.

      not sorted    a thin chevron: this opens a menu
      ascending     a solid triangle pointing up
      descending    a solid triangle pointing down
      filtered      the button filled, whatever the sort is doing

   Drawn out of one-pixel rows rather than a path, because there is no geometry
   sink in this binding. */
static void filterBtn(Grid* c, float right, float midY, unsigned int line_, unsigned int fill,
                      int dir, int filt) {
    float l = right - (float)D2G_BTNW - 2.0f;
    float t = midY - 7.0f;
    float r = right - 2.0f;
    float b = midY + 7.0f;
    int   i;
    float cx = (l + r) / 2.0f;
    fillRect(c, l, t, r, b, fill);
    line(c, l + 0.5f, t, l + 0.5f, b, line_);
    line(c, r - 0.5f, t, r - 0.5f, b, line_);
    line(c, l, t + 0.5f, r, t + 0.5f, line_);
    line(c, l, b - 0.5f, r, b - 0.5f, line_);
    if (filt && c->fmtIcon) {
        glyph(c, D2G_G_FILT, l, t, r, b, line_, c->fmtIcon);
    } else {
        glyph(c, (unsigned short)(!dir ? D2G_G_MENU : (dir > 0 ? D2G_G_ASC : D2G_G_DESC)),
              l, t, r, b, line_, c->fmt);
    }
    (void)i; (void)cx;
}

/* which heading's button is under the pointer, -1 for none */
int d2g_HitBtn(int h, int x, int y) {
    Grid* c = slot(h);
    int   col, at, fx = 0;
    if (!c || !c->btns || y > c->hdrH) return -1;
    if (c->grps) {
        for (col = 0; col < c->grps; col++) {
            at = c->grpX[col] + c->grpW[col] - ((col < c->frozen) ? 0 : c->scrollX);
            if (x >= at - D2G_BTNW - 2 && x < at - 2) {
                int i;
                for (i = 0; i < c->cols; i++) if (c->colGrp[i] == col) return i;
                return -1;
            }
        }
        return -1;
    }
    for (col = 0; col < c->frozen && col < c->cols; col++) {
        fx += c->colW[col];
        if (BTNON(c, col) && x >= fx - D2G_BTNW - 2 && x < fx - 2) return col;
    }
    at = -c->scrollX;
    for (col = 0; col < c->cols; col++) {
        at += c->colW[col];
        if (col >= c->frozen && at > fx && BTNON(c, col)
            && x >= at - D2G_BTNW - 2 && x < at - 2) return col;
    }
    return -1;
}

/* A small triangle, built out of four one-pixel rows rather than a path -
   there is no geometry sink here and at this size the steps are invisible. */
static void sortMark(Grid* c, float right, float top, int dir, unsigned int rgb) {
    int   i;
    float cx = right - 5.0f;
    for (i = 0; i < 4; i++) {
        float w = (dir > 0) ? (float)(1 + i * 2) : (float)(7 - i * 2);
        float y = top + (float)i;
        fillRect(c, cx - w / 2.0f, y, cx + w / 2.0f, y + 1.0f, rgb);
    }
}

/* ---- our own vertical scrollbar ---------------------------------------- */
/* How thick a drawn bar is, and how much room it takes OUT of the rows. An
   overlay takes none - that is the whole point of it - so the two are not the
   same question and are not answered by the same function. */
static int barThick(Grid* c) {
    if (c->barStyle == 2) return 8;
    if (c->barStyle == 1) return 10;
    return D2G_BARW;
}

static int barTakes(Grid* c) { return (c->barStyle == 2) ? 0 : barThick(c); }

void d2g_BarStyle(int h, int style) {
    Grid* c = slot(h);
    if (!c || style < 0 || style > 2) return;
    c->barStyle = style;
}

/* Overlay only: the bars are shown while the pointer is over the grid. */
void d2g_BarsShow(int h, int on) {
    Grid* c = slot(h);
    if (!c) return;
    if (c->barsShow == (on ? 1 : 0)) return;
    c->barsShow = on ? 1 : 0;
    if (c->barStyle == 2) InvalidateRect(c->hwnd, 0, 0);
}

/* The drawn horizontal bar. Sideways is the grid's own business either way -
   this only changes who paints the furniture. */
void d2g_HBar(int h, int show, int pos, int page, int total) {
    Grid* c = slot(h);
    if (!c) return;
    c->hBar   = show ? 1 : 0;
    c->hPos   = pos < 0 ? 0 : pos;
    c->hPage  = page < 1 ? 1 : page;
    c->hTotal = total < 1 ? 1 : total;
    if (c->hPos > c->hTotal - c->hPage) c->hPos = c->hTotal - c->hPage;
    if (c->hPos < 0) c->hPos = 0;
}

static void d2g_HGeom(Grid* c, int* left, int* len, int* tLeft, int* tLen) {
    RECT r;
    int  l, tl, room;
    GetClientRect(c->hwnd, &r);
    l = (r.right - r.left) - (c->vBar ? barTakes(c) : 0);
    if (l < 0) l = 0;
    tl = (c->hTotal > 0) ? (l * c->hPage / c->hTotal) : l;
    if (tl < 24) tl = 24;
    if (tl > l)  tl = l;
    room = c->hTotal - c->hPage;
    *left = 0; *len = l; *tLen = tl;
    *tLeft = (room > 0) ? (l - tl) * c->hPos / room : 0;
}

/* 0 none, 4 on the thumb, 5 to the left of it, 6 to the right */
int d2g_HitHBar(int h, int x, int y) {
    Grid* c = slot(h);
    RECT  r;
    int   left, len, tLeft, tLen, top;
    if (!c || !c->hBar) return 0;
    if (c->barStyle == 2 && !c->barsShow) return 0;
    GetClientRect(c->hwnd, &r);
    top = (r.bottom - r.top) - barThick(c);
    if (y < top) return 0;
    d2g_HGeom(c, &left, &len, &tLeft, &tLen);
    if (x < tLeft) return 5;
    if (x < tLeft + tLen) return 4;
    return 6;
}

int d2g_HGrab(int h, int x) {
    Grid* c = slot(h);
    int   left, len, tLeft, tLen;
    if (!c || !c->hBar) return 0;
    d2g_HGeom(c, &left, &len, &tLeft, &tLen);
    return x - tLeft;
}

int d2g_HDrag(int h, int x, int grab) {
    Grid* c = slot(h);
    int   left, len, tLeft, tLen, room, pos;
    if (!c || !c->hBar) return 0;
    d2g_HGeom(c, &left, &len, &tLeft, &tLen);
    room = len - tLen;
    if (room < 1) return 0;
    pos = (x - grab) * (c->hTotal - c->hPage) / room;
    if (pos < 0) pos = 0;
    if (pos > c->hTotal - c->hPage) pos = c->hTotal - c->hPage;
    return pos;
}

void d2g_VBar(int h, int show, int pos, int pct) {
    Grid* c = slot(h);
    if (!c) return;
    c->vBar = show ? 1 : 0;
    c->vPos = pos < 0 ? 0 : (pos > 100 ? 100 : pos);
    c->vPct = pct < 4 ? 4 : (pct > 100 ? 100 : pct);
}


/* where the trough runs, and where the thumb sits inside it */
static void d2g_VGeom(Grid* c, int* top, int* len, int* tTop, int* tLen) {
    RECT r;
    int  t, l, tl;
    GetClientRect(c->hwnd, &r);
    t  = c->hdrH;
    l  = (r.bottom - r.top) - t - (c->hBar ? barTakes(c) : 0);
    if (l < 0) l = 0;
    tl = l * c->vPct / 100;
    if (tl < 24) tl = 24;
    if (tl > l)  tl = l;
    *top = t; *len = l; *tLen = tl;
    *tTop = t + (l - tl) * c->vPos / 100;
}

/* 0 nowhere near it, 1 on the thumb, 2 above it, 3 below it */
int d2g_VHit(int h, int x, int y) {
    Grid* c = slot(h);
    RECT  r;
    int   top, len, tTop, tLen;
    if (!c || !c->vBar) return 0;
    GetClientRect(c->hwnd, &r);
    if (c->barStyle == 2 && !c->barsShow) return 0;
    if (x < r.right - barThick(c)) return 0;
    d2g_VGeom(c, &top, &len, &tTop, &tLen);
    if (y < top) return 0;
    if (y < tTop) return 2;
    if (y < tTop + tLen) return 1;
    return 3;
}

/* how far down the thumb the pointer took hold - so the drag is anchored and
   the thumb does not jump under the cursor when it starts */
int d2g_VGrab(int h, int y) {
    Grid* c = slot(h);
    int   top, len, tTop, tLen;
    if (!c || !c->vBar) return 0;
    d2g_VGeom(c, &top, &len, &tTop, &tLen);
    return y - tTop;
}

/* where the thumb has been dragged to, back on the browse's 0..100 scale */
int d2g_VDrag(int h, int y, int grab) {
    Grid* c = slot(h);
    int   top, len, tTop, tLen, room, pos;
    if (!c || !c->vBar) return 0;
    d2g_VGeom(c, &top, &len, &tTop, &tLen);
    room = len - tLen;
    if (room < 1) return 0;
    pos = (y - grab - top) * 100 / room;
    return pos < 0 ? 0 : (pos > 100 ? 100 : pos);
}

/* Build the text formats again at a new size, and grow the rows to match -
   Ctrl and the wheel, the way every other program does it. Returns the size
   actually used, so the caller can see where it stopped. */
int d2g_FontSize(int h, int pt) {
    Grid* c = slot(h);
    void *f, *fh;
    if (!c) return 0;
    if (pt < 6)  pt = 6;
    if (pt > 32) pt = 32;
    if (pt == c->pt) return c->pt;
    f  = d2g_Font(c->face, (float)pt, 0);
    fh = d2g_Font(c->face, (float)pt, 1);
    if (!f || !fh) {
        if (f)  ((unsigned long (WINAPI*)(void*))VT(f)[2])(f);
        if (fh) ((unsigned long (WINAPI*)(void*))VT(fh)[2])(fh);
        return c->pt;
    }
    if (c->fmt)     ((unsigned long (WINAPI*)(void*))VT(c->fmt)[2])(c->fmt);
    if (c->fmtHdr)  ((unsigned long (WINAPI*)(void*))VT(c->fmtHdr)[2])(c->fmtHdr);
    c->fmt = f; c->fmtHdr = fh;
    /* set outright, not through d2g_RowHeight - that clamps against the size
       the type needs, and here the type is what just changed. Going through it
       would let the rows grow and never come back down. */
    /* The columns come with it. Growing the type without growing the columns
       is not a bigger grid, it is the same grid with the words too large for
       it: every cell wraps or clips and the headings run into each other. A
       zoom scales the layout, so the widths, the group boxes and every field's
       place inside its group are all taken along - including the originals a
       group resize measures against, or the next drag would undo this. */
    if (c->pt > 0 && pt != c->pt) {
        int k, was = c->pt;
        for (k = 0; k < G_COLS; k++) {
            c->colW[k]  = c->colW[k]  * pt / was;
            c->colX[k]  = c->colX[k]  * pt / was;
            c->colOx[k] = c->colOx[k] * pt / was;
            c->colOw[k] = c->colOw[k] * pt / was;
            c->grpX[k]  = c->grpX[k]  * pt / was;
            c->grpW[k]  = c->grpW[k]  * pt / was;
            c->grpOw[k] = c->grpOw[k] * pt / was;
        }
    }
    c->pt   = pt;
    c->rowH = D2G_ROWH(c);                      /* the same rule d2g_Attach uses */
    c->hdrH = D2G_HDRFOR(pt);
    c->pt = pt;
    InvalidateRect(c->hwnd, 0, 0);
    return c->pt;
}

int d2g_FontPt(int h) { Grid* c = slot(h); return c ? c->pt : 0; }


/* ---- resizing a GROUP ---------------------------------------------------
   In a grouped format the draggable edges are the groups', not the fields' -
   there is one heading over the lot and nothing sensible to grab between two
   fields that sit on different lines. Widening a group has to carry the fields
   inside it and shift every group to its right, which is why this could not
   just reuse the flat column code. */
int d2g_HitGrpEdge(int h, int x) {
    Grid* c = slot(h);
    int   g, at;
    const int grab = 4;
    if (!c || !c->grps) return -1;
    for (g = 0; g < c->grps; g++) {
        at = c->grpX[g] + c->grpW[g] - ((g < c->frozen) ? 0 : c->scrollX);
        if (x >= at - grab && x <= at + grab) return g;
    }
    return -1;
}

int d2g_GrpWidth(int h, int g) {
    Grid* c = slot(h);
    if (!c || g < 0 || g >= c->grps) return 0;
    return c->grpW[g];
}

void d2g_SetGrpWidth(int h, int g, int w) {
    Grid* c = slot(h);
    int   old, delta, i, gx;
    if (!c || g < 0 || g >= c->grps) return;
    if (w < 32) w = 32;
    old = c->grpW[g];
    if (old < 1) return;
    gx = c->grpX[g];
    delta = w - old;
    c->grpW[g] = w;
    /* Rebuilt from the proportions the format was read with, not from where
       the fields happen to be now - so shrinking and growing again lands back
       where it started instead of collapsing everything onto the left. */
    if (c->grpOw[g] < 1) c->grpOw[g] = old;
    for (i = 0; i < c->cols; i++) {
        if (c->colGrp[i] != g) continue;
        c->colX[i] = gx + c->colOx[i] * w / c->grpOw[g];
        c->colW[i] = c->colOw[i] * w / c->grpOw[g];
        if (c->colW[i] < 8) c->colW[i] = 8;
    }
    for (i = g + 1; i < c->grps; i++) c->grpX[i] += delta;     /* everything right moves */
    for (i = 0; i < c->cols; i++) if (c->colGrp[i] > g) c->colX[i] += delta;
}

/* which field of a group is which, so the new widths can go back on the LIST */
int d2g_GrpColW(int h, int col) {
    Grid* c = slot(h);
    if (!c || col < 0 || col >= c->cols) return 0;
    return c->colW[col];
}

int d2g_ColGrp(int h, int col) {
    Grid* c = slot(h);
    if (!c || col < 0 || col >= c->cols) return -1;
    return c->colGrp[col];
}

int d2g_HdrHeight(int h) {
    Grid* c = slot(h);
    return c ? c->hdrH : 0;
}

int d2g_ColWidth(int h, int col) {
    Grid* c = slot(h);
    if (!c || col < 0 || col >= c->cols) return 0;
    return c->colW[col];
}

/* just the width - d2g_Column would want the title and alignment again */
void d2g_SetWidth(int h, int col, int w) {
    Grid* c = slot(h);
    if (!c || col < 0 || col >= c->cols) return;
    c->colW[col] = w < 16 ? 16 : w;
}

int d2g_HitCol(int h, int x) {
    Grid* c = slot(h);
    int col, at, fx = 0;
    if (!c) return -1;
    if (c->grps) {                    /* a heading is a group: answer its first field */
        int g = -1, gx;
        for (col = 0; col < c->grps; col++) {
            gx = c->grpX[col] - ((col < c->frozen) ? 0 : c->scrollX);
            if (x >= gx && x < gx + c->grpW[col]) { g = col; break; }
        }
        if (g < 0) return -1;
        for (col = 0; col < c->cols; col++) if (c->colGrp[col] == g) return col;
        return -1;
    }
    for (col = 0; col < c->frozen && col < c->cols; col++) {   /* the frozen strip first */
        if (x >= fx && x < fx + c->colW[col]) return col;
        fx += c->colW[col];
    }
    if (x < fx) return -1;
    at = -c->scrollX;
    for (col = 0; col < c->cols; col++) {
        if (col >= c->frozen && x >= at && x < at + c->colW[col]) return col;
        at += c->colW[col];
    }
    return -1;
}

}  /* extern "C" */
