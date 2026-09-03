#TEMPLATE(BrowseGrid,'BrowseGrid - draw any browse with Direct2D - v1.36'),FAMILY('ABC')
#!-----------------------------------------------------------------------------
#!  BrowseGrid  -  a browse that does not look like 1995.
#!
#!  Drop it on a procedure that already has an ABC browse, point it at the
#!  LIST, and the LIST is hidden and a Direct2D grid drawn in its place:
#!  banded rows, a proper header, frozen columns, crisp DirectWrite text and
#!  any colours you like.
#!
#!  WHAT IT DOES NOT TOUCH. The browse. BrowseClass keeps the file, the sort
#!  order, the filter, the range limit and the locator, exactly as they are -
#!  this only replaces what the rows LOOK like. That is what makes it a drop-in
#!  rather than a rewrite, and it is why an existing browse keeps working if
#!  you disable the extension.
#!
#!  WHERE THE COLUMNS COME FROM. The LIST itself, at run time, through
#!  PROPLIST:Exists / FieldNo / Header / Width / Picture / Left / Right /
#!  Center / Decimal. So the widths, headings, pictures and alignment you
#!  already set in the window formatter carry straight over, and a column the
#!  user has resized or moved comes over as it now is - the same approach
#!  myExport uses to read any browse.
#!
#!  WHERE THE VALUES COME FROM. The browse's own QUEUE, read generically with
#!  WHAT(queue, fieldnumber) - so nothing here knows or cares what the file is.
#!
#!  REQUIRES d2grid.c on the redirection path (with the myImage files, if you
#!  have those). Direct2D and DirectWrite are part of Windows and are bound at
#!  run time, so there is no import library and nothing to ship.
#!-----------------------------------------------------------------------------
#!#############################################################################
#!  GLOBAL EXTENSION - BrowseGridGlobal
#!#############################################################################
#EXTENSION(BrowseGridGlobal,'BrowseGrid - Global (add once per application)'),APPLICATION
#SHEET
  #TAB('General')
    #BOXED('BrowseGrid')
      #DISPLAY('BrowseGrid - Version 1.36')
      #DISPLAY('Draws an ABC browse with Direct2D and DirectWrite instead of')
      #DISPLAY('the runtime LIST, without touching the browse underneath.')
      #DISPLAY('')
      #DISPLAY('REQUIRES d2grid.c on the redirection path.')
      #DISPLAY('Add this extension ONCE per application - and to EVERY app of')
      #DISPLAY('a multi-DLL set that carries a grid.')
    #ENDBOXED
    #BOXED('Options')
      #PROMPT('&Disable this template',CHECK),%bgGDisable,DEFAULT(0),AT(10)
    #ENDBOXED
    #BOXED('Language')
      #PROMPT('Texts the &END USER sees:',DROP('English[EN]|Castellano[ES]')),%bgGLang,DEFAULT('EN')
      #DISPLAY('The heading menu, the two dialogs and the warnings. Every grid in')
      #DISPLAY('the application follows this unless it says otherwise on its own')
      #DISPLAY('prompts.')
      #DISPLAY('')
      #DISPLAY('THESE prompts stay in English whatever is chosen: the programmer')
      #DISPLAY('reads them, not the user. So does the diagnostics line, which is a')
      #DISPLAY('debugging tool rather than part of the product.')
    #ENDBOXED
  #ENDTAB
  #TAB('Heading menu')
    #DISPLAY('Lo que ofrece el menu del encabezado, para toda la aplicacion.')
    #DISPLAY('Cada browse decide si usa esto o lo suyo, con un tilde en su')
    #DISPLAY('propia solapa Heading menu.')
    #DISPLAY('')
    #PROMPT('Excel-style drop-down &button on every heading',CHECK),%bgGFilterBtn,DEFAULT(0),AT(10)
    #PROMPT('  Offer Filter by &value... on that menu',CHECK),%bgGFilterVals,DEFAULT(1),AT(10)
    #PROMPT('  Offer Fi&nd text... on that menu',CHECK),%bgGFilterText,DEFAULT(1),AT(10)
    #PROMPT('&Columns... (show and hide columns)',CHECK),%bgGChooser,DEFAULT(1),AT(10)
    #PROMPT('&Sort Ascending / Descending',CHECK),%bgGMnSort,DEFAULT(1),AT(10)
    #PROMPT('Filter on &this value',CHECK),%bgGMnFiltOn,DEFAULT(1),AT(10)
    #PROMPT('Clear this f&ilter',CHECK),%bgGMnClrThis,DEFAULT(1),AT(10)
    #PROMPT('Clear &all filters',CHECK),%bgGMnClrAll,DEFAULT(1),AT(10)
    #PROMPT('&Reset layout',CHECK),%bgGMnReset,DEFAULT(1),AT(10)
    #PROMPT('La&youts... (save and recall column layouts)',CHECK),%bgGSchemes,DEFAULT(0),AT(10)
    #PROMPT('A&uto-fit column widths on the heading menu',CHECK),%bgGAutoFit,DEFAULT(1),AT(10)
    #PROMPT('  Records to look &ahead:',SPIN(@n7,0,100000,500)),%bgGFitScan,DEFAULT(1000)
  #ENDTAB
  #TAB('Look')
    #DISPLAY('Tipografia y colores para toda la aplicacion. Cada browse decide')
    #DISPLAY('si usa esto o lo suyo, con un tilde en su solapa Look.')
    #DISPLAY('')
    #PROMPT('Take the typeface from SD &Aspecto',CHECK),%bgGSDAsp,DEFAULT(0),AT(10)
    #PROMPT('&Font:',@s32),%bgGFont,DEFAULT('Segoe UI')
    #PROMPT('&Size (points):',SPIN(@n3,6,24,1)),%bgGSize,DEFAULT(9)
    #PROMPT('Draw the text the way the LIST does (&GDI)',CHECK),%bgGGdiText,DEFAULT(1),AT(10)
    #PROMPT('Font wei&ght:',DROP('As the name says[0]|Light[300]|Regular[400]|Medium[500]|SemiBold[600]|Bold[700]')),%bgGWeight,DEFAULT('0')
    #PROMPT('&Wrap text that is too long for its column',CHECK),%bgGWrap,DEFAULT(0),AT(10)
    #PROMPT('  &Lines a cell may use:',SPIN(@n1,2,4,1)),%bgGWrapLines,DEFAULT(2)
    #PROMPT('&Row height (pixels, 0 = follow the browse):',SPIN(@n3,0,80,1)),%bgGRowH,DEFAULT(0)
    #PROMPT('&Header height (pixels, 0 = from the font):',SPIN(@n3,0,80,1)),%bgGHdrH,DEFAULT(0)
  #ENDTAB
  #TAB('Colours')
    #DISPLAY('Los ocho colores del grid, para toda la aplicacion.')
    #DISPLAY('')
    #PROMPT('&Background:',COLOR),%bgGCBack,DEFAULT(00FFFFFFH)
    #PROMPT('B&anding (every other row):',COLOR),%bgGCBand,DEFAULT(00FAF7F5H)
    #PROMPT('&Gridlines:',COLOR),%bgGCGrid,DEFAULT(00EAE5E1H)
    #PROMPT('&Text:',COLOR),%bgGCText,DEFAULT(0033291FH)
    #PROMPT('Header bac&kground:',COLOR),%bgGCHdrBack,DEFAULT(004A3A2BH)
    #PROMPT('Header te&xt:',COLOR),%bgGCHdrText,DEFAULT(00FFFFFFH)
    #PROMPT('Selected ro&w:',COLOR),%bgGCSelBack,DEFAULT(00B56F2FH)
    #PROMPT('Selected t&ext:',COLOR),%bgGCSelText,DEFAULT(00FFFFFFH)
  #ENDTAB
  #TAB('Variables')
    #DISPLAY('Tipografia y colores desde variables del programa, para toda la')
    #DISPLAY('aplicacion. Un campo en blanco conserva el valor fijo de las otras')
    #DISPLAY('dos solapas; uno con un nombre se emite como codigo.')
    #DISPLAY('')
    #PROMPT('Take any of these from a &variable instead',CHECK),%bgGVars,DEFAULT(0),AT(10)
    #PROMPT('  Font name:',@s64),%bgGVFont,DEFAULT('')
    #PROMPT('  Size:',@s64),%bgGVSize,DEFAULT('')
    #PROMPT('  Background:',@s64),%bgGVCBack,DEFAULT('')
    #PROMPT('  Banding:',@s64),%bgGVCBand,DEFAULT('')
    #PROMPT('  Gridlines:',@s64),%bgGVCGrid,DEFAULT('')
    #PROMPT('  Text:',@s64),%bgGVCText,DEFAULT('')
    #PROMPT('  Header background:',@s64),%bgGVCHdrBack,DEFAULT('')
    #PROMPT('  Header text:',@s64),%bgGVCHdrText,DEFAULT('')
    #PROMPT('  Selected row:',@s64),%bgGVCSelBack,DEFAULT('')
    #PROMPT('  Selected text:',@s64),%bgGVCSelText,DEFAULT('')
  #ENDTAB
  #TAB('Mouse')
    #DISPLAY('Barras y clicks para toda la aplicacion. Las columnas que ademas')
    #DISPLAY('reciben el click quedan por browse: son numeros de ESE browse.')
    #DISPLAY('')
    #PROMPT('Scroll&bars on the grid',CHECK),%bgGBars,DEFAULT(1),AT(10)
    #PROMPT('  St&yle:',DROP('Windows|Slim|Overlay')),%bgGBarStyle,DEFAULT('Windows')
    #PROMPT('Hand a right-click back to the browse &popup',CHECK),%bgGPopup,DEFAULT(1),AT(10)
    #PROMPT('A &double click opens the record',CHECK),%bgGDouble,DEFAULT(1),AT(10)
    #PROMPT('Scroll with the mouse &wheel',CHECK),%bgGWheel,DEFAULT(1),AT(10)
    #PROMPT('Show the whole value in a t&ooltip when it does not fit',CHECK),%bgGTips,DEFAULT(1),AT(10)
  #ENDTAB
#ENDSHEET
#!-----------------------------------------------------------------------------
#AT(%AfterGlobalIncludes),WHERE(%bgGDisable=0)
  PRAGMA('compile(d2grid.c)')                                 ! the grid, built by Clarion's own C compiler
BG:Scrolled          EQUATE(EVENT:User + 244)                 ! a grid scrollbar moved
BG:GwlStyle          EQUATE(-16)
BG:GwlWndProc        EQUATE(-4)
BG:HScrollStyle      EQUATE(00100000h)
BG:VScrollStyle      EQUATE(00200000h)
BG:FrameChanged      EQUATE(0020h)
BG:NoMove            EQUATE(0002h)
BG:NoSize            EQUATE(0001h)
BG:NoZOrder          EQUATE(0004h)
BG:ClipSiblings      EQUATE(04000000h)                        ! WS_CLIPSIBLINGS
BG:Visible           EQUATE(10000000h)                        ! WS_VISIBLE
BG:HwndTop           EQUATE(0)
BG:SbHorz            EQUATE(0)
BG:SbVert            EQUATE(1)
BG:WmHScroll         EQUATE(0114h)
BG:WmVScroll         EQUATE(0115h)
BG:SifRange          EQUATE(1)
BG:SifPage           EQUATE(2)
BG:SifPos            EQUATE(4)
BG:SifTrack          EQUATE(10h)
BG:WmMouseWheel      EQUATE(020Ah)
BG:WheelNotch        EQUATE(120)                              ! WHEEL_DELTA
BG:WheelCode         EQUATE(99)                               ! not one of Windows' scroll codes
BG:WheelLines        EQUATE(3)                                ! rows per notch, as everything else does
BG:ThumbPct          EQUATE(12)                               ! fallback when the count is unknown
BG:FontCode          EQUATE(98)                               ! Ctrl-wheel resized the type
BG:MkControl         EQUATE(0008h)
BG:WmLButtonDown     EQUATE(0201h)
BG:WmLButtonUp       EQUATE(0202h)
BG:MkLButton         EQUATE(0001h)
BG:DragSlop          EQUATE(3)                                ! pixels before a click becomes a drag
!  HOW MANY COLUMNS. This has to be the same number as G_COLS in d2grid.c:
!  Clarion sizes its arrays at compile time and the engine checks against its
!  own limit, so if the two drift apart the smaller one wins in silence and
!  the columns past it simply stop existing. Both sides say 64.
BG:MaxCols           EQUATE(64)                               ! columns a grid can carry
BG:MaxScan           EQUATE(50000)                            ! records read looking for values
BG:MaxSum            EQUATE(200000)                           ! records added up for the totals
BG:FitPad            EQUATE(10)                               ! the 8 a cell is drawn with, plus slack
BG:FitMin            EQUATE(16)                               ! a column narrower than this is a line
BG:FitMax            EQUATE(600)                              ! and one wider is a paragraph
BG:FitBox            EQUATE(28)                               ! a tick box: the square, not its text
BG:MaxSch            EQUATE(20)                               ! esquemas de columnas guardados
BG:MaxExpr           EQUATE(950)                              ! how long a filter expression may get
BG:MaxVals           EQUATE(500)                              ! distinct values offered
BG:VkLButton         EQUATE(1)
#ENDAT
#!
#!  The callback cannot hand anything to Clarion through POST, so what it saw
#!  is left here for the ACCEPT loop to pick up. Only one scrollbar can be
#!  moving at a time, so one set of variables is enough.
#AT(%GlobalData),WHERE(%bgGDisable=0)
BG:LastBar           LONG                                     ! 0 horizontal, 1 vertical
BG:LastCode          LONG                                     ! what the user did to it
BG:LastPos           LONG                                     ! and where the thumb ended up
#ENDAT
#!
#AT(%GlobalMap),WHERE(%bgGDisable=0)
#!  cdecl exports from C, so the Clarion name carries a leading underscore.
    MODULE('d2grid.c')
d2g_Available(),LONG,NAME('_d2g_Available')
d2g_Attach(LONG hwnd,*CSTRING face,LONG pt),LONG,RAW,NAME('_d2g_Attach')
d2g_Detach(LONG h),NAME('_d2g_Detach')
d2g_Columns(LONG h,LONG n),NAME('_d2g_Columns')
d2g_Column(LONG h,LONG col,LONG width,LONG align,*CSTRING title),RAW,NAME('_d2g_Column')
d2g_Frozen(LONG h,LONG n),NAME('_d2g_Frozen')
d2g_RowHeight(LONG h,LONG px),NAME('_d2g_RowHeight')
d2g_HeaderHeight(LONG h,LONG px),NAME('_d2g_HeaderHeight')
d2g_Total(LONG h,LONG n),NAME('_d2g_Total')
d2g_Select(LONG h,LONG row),NAME('_d2g_Select')
d2g_ScrollX(LONG h,LONG x),NAME('_d2g_ScrollX')
d2g_ScrollY(LONG h,LONG y),NAME('_d2g_ScrollY')
d2g_Colours(LONG h,ULONG back,ULONG band,ULONG grid,ULONG txt,ULONG hb,ULONG ht,ULONG sb,ULONG st),NAME('_d2g_Colours')
d2g_Page(LONG h,LONG firstRow,LONG rows),NAME('_d2g_Page')
d2g_Cell(LONG h,LONG visRow,LONG col,*CSTRING s),RAW,NAME('_d2g_Cell')
d2g_CellColour(LONG h,LONG visRow,LONG col,LONG nfg,LONG nbg,LONG sfg,LONG sbg),NAME('_d2g_CellColour')
d2g_ColumnColour(LONG h,LONG col,LONG fg,LONG bg,LONG sfg,LONG sbg),NAME('_d2g_ColumnColour')
d2g_CheckCol(LONG h,LONG col,LONG on),NAME('_d2g_CheckCol')
d2g_Footer(LONG h,LONG on),NAME('_d2g_Footer')
d2g_FootCell(LONG h,LONG col,*CSTRING s),RAW,NAME('_d2g_FootCell')
d2g_Repaint(LONG h),NAME('_d2g_Repaint')
d2g_PaintNow(LONG h),LONG,PROC,NAME('_d2g_PaintNow')
d2g_Resize(LONG h),LONG,PROC,NAME('_d2g_Resize')
d2g_PageSize(LONG h),LONG,NAME('_d2g_PageSize')
d2g_RowH(LONG h),LONG,NAME('_d2g_RowH')
d2g_HeaderH(LONG h),LONG,NAME('_d2g_HeaderH')
d2g_HitRow(LONG h,LONG y),LONG,NAME('_d2g_HitRow')
d2g_HitCol(LONG h,LONG x),LONG,NAME('_d2g_HitCol')
d2g_TotalWidth(LONG h),LONG,NAME('_d2g_TotalWidth')
d2g_HitEdge(LONG h,LONG x),LONG,NAME('_d2g_HitEdge')
d2g_ColWidth(LONG h,LONG col),LONG,NAME('_d2g_ColWidth')
d2g_SetWidth(LONG h,LONG col,LONG width),NAME('_d2g_SetWidth')
d2g_HdrHeight(LONG h),LONG,NAME('_d2g_HdrHeight')
d2g_FromHwnd(LONG hwnd),LONG,NAME('_d2g_FromHwnd')
d2g_VBar(LONG h,LONG show,LONG pos,LONG pct),NAME('_d2g_VBar')
d2g_VHit(LONG h,LONG x,LONG y),LONG,NAME('_d2g_VHit')
d2g_VGrab(LONG h,LONG y),LONG,NAME('_d2g_VGrab')
d2g_VDrag(LONG h,LONG y,LONG grab),LONG,NAME('_d2g_VDrag')
d2g_FontSize(LONG h,LONG pt),LONG,PROC,NAME('_d2g_FontSize')
d2g_FontPt(LONG h),LONG,NAME('_d2g_FontPt')
d2g_RowNeed(LONG h),LONG,NAME('_d2g_RowNeed')
d2g_SortMark(LONG h,LONG col,LONG dir),NAME('_d2g_SortMark')
d2g_Lines(LONG h,LONG n),NAME('_d2g_Lines')
d2g_Wrap(LONG h,LONG on,LONG lines),NAME('_d2g_Wrap')
d2g_HitGrpEdge(LONG h,LONG x),LONG,NAME('_d2g_HitGrpEdge')
d2g_GrpWidth(LONG h,LONG g),LONG,NAME('_d2g_GrpWidth')
d2g_SetGrpWidth(LONG h,LONG g,LONG width),NAME('_d2g_SetGrpWidth')
d2g_GrpColW(LONG h,LONG col),LONG,NAME('_d2g_GrpColW')
d2g_ColGrp(LONG h,LONG col),LONG,NAME('_d2g_ColGrp')
d2g_FilterBtns(LONG h,LONG on),NAME('_d2g_FilterBtns')
d2g_HitBtn(LONG h,LONG x,LONG y),LONG,NAME('_d2g_HitBtn')
d2g_FilterOn(LONG h,LONG col,LONG on),NAME('_d2g_FilterOn')
d2g_BarStyle(LONG h,LONG style),NAME('_d2g_BarStyle')
d2g_TextMode(LONG h,LONG gdi),NAME('_d2g_TextMode')
d2g_TextInfo(LONG h,LONG what),LONG,NAME('_d2g_TextInfo')
d2g_Weight(LONG h,LONG w),NAME('_d2g_Weight')
d2g_BarsShow(LONG h,LONG on),NAME('_d2g_BarsShow')
d2g_HBar(LONG h,LONG show,LONG pos,LONG page,LONG total),NAME('_d2g_HBar')
d2g_HitHBar(LONG h,LONG x,LONG y),LONG,NAME('_d2g_HitHBar')
d2g_HGrab(LONG h,LONG x),LONG,NAME('_d2g_HGrab')
d2g_HDrag(LONG h,LONG x,LONG grab),LONG,NAME('_d2g_HDrag')
d2g_Groups(LONG h,LONG n),NAME('_d2g_Groups')
d2g_Group(LONG h,LONG gi,LONG x,LONG width,*CSTRING title),RAW,NAME('_d2g_Group')
d2g_ColumnAt(LONG h,LONG col,LONG grp,LONG line,LONG x,LONG width,LONG align,*CSTRING title),RAW,NAME('_d2g_ColumnAt')
d2g_ViewWidth(LONG h),LONG,NAME('_d2g_ViewWidth')
    END
BG_Rgb(LONG),ULONG
BG_Colr(LONG),LONG
BG_Quote(STRING),STRING
BG_Log(STRING)
BG_BarProc(ULONG,ULONG,ULONG,LONG),LONG,PASCAL
BG_HookBars(LONG,LONG),BYTE,PROC
BG_DropBars(LONG),LONG,PROC
BG_SetBar(LONG,LONG,LONG,LONG,LONG)
BG_BarPos(LONG,LONG),LONG
    MODULE('win32')
bgApi_SetProp(ULONG hWnd,LONG lpString,LONG hData),LONG,PASCAL,PROC,NAME('SetPropA')
bgApi_GetProp(ULONG hWnd,LONG lpString),LONG,PASCAL,NAME('GetPropA')
bgApi_RemoveProp(ULONG hWnd,LONG lpString),LONG,PASCAL,PROC,NAME('RemovePropA')
bgApi_CallWndProc(LONG lpPrev,ULONG hWnd,ULONG wMsg,ULONG wParam,LONG lParam),LONG,PASCAL,NAME('CallWindowProcA')
bgApi_SetWindowLong(ULONG hWnd,LONG nIndex,LONG dwNewLong),LONG,PASCAL,PROC,NAME('SetWindowLongA')
bgApi_GetWindowLong(ULONG hWnd,LONG nIndex),LONG,PASCAL,NAME('GetWindowLongA')
bgApi_SetWindowPos(ULONG hWnd,LONG after,LONG x,LONG y,LONG cx,LONG cy,ULONG flags),LONG,PASCAL,PROC,NAME('SetWindowPos')
bgApi_SetScrollInfo(ULONG hWnd,LONG bar,LONG lpsi,LONG redraw),LONG,PASCAL,PROC,NAME('SetScrollInfo')
bgApi_GetScrollInfo(ULONG hWnd,LONG bar,LONG lpsi),LONG,PASCAL,PROC,NAME('GetScrollInfo')
bgApi_GetAsyncKeyState(LONG vKey),SHORT,PASCAL,NAME('GetAsyncKeyState')
bgApi_GetSysColor(LONG nIndex),ULONG,PASCAL,NAME('GetSysColor')
bgApi_GetDC(ULONG hWnd),LONG,PASCAL,NAME('GetDC')
bgApi_ReleaseDC(ULONG hWnd,LONG hdc),LONG,PASCAL,PROC,NAME('ReleaseDC')
bgApi_GetDeviceCaps(LONG hdc,LONG index),LONG,PASCAL,NAME('GetDeviceCaps')
bgApi_QueryPerfCount(LONG lpCount),LONG,PASCAL,PROC,NAME('QueryPerformanceCounter')
bgApi_QueryPerfFreq(LONG lpFreq),LONG,PASCAL,PROC,NAME('QueryPerformanceFrequency')
bgApi_CreateFile(LONG lpName,ULONG access,ULONG share,LONG sec,ULONG disp,ULONG flags,LONG tmpl),LONG,PASCAL,NAME('CreateFileA')
bgApi_SetFilePointer(LONG hFile,LONG dist,LONG distHi,ULONG method),ULONG,PASCAL,PROC,NAME('SetFilePointer')
bgApi_WriteFile(LONG hFile,LONG buf,ULONG len,LONG written,LONG ov),LONG,PASCAL,PROC,NAME('WriteFile')
bgApi_CloseHandle(LONG hObject),LONG,PASCAL,PROC,NAME('CloseHandle')
bgApi_PostMessage(ULONG hWnd,ULONG msg,ULONG wParam,LONG lParam),LONG,PASCAL,PROC,NAME('PostMessageA')
    END
#ENDAT
#!
#AT(%ProgramProcedures),WHERE(%bgGDisable=0)
!  ---- scrollbars ---------------------------------------------------------
!  A REGION is not born with scrollbars, so the styles go on at run time and
!  the control is subclassed for the two scroll messages. The address of the
!  callback is taken HERE, in the module that defines it - taken in a member
!  module it is an import thunk, not the procedure.
BG_HookBars PROCEDURE(LONG pHwnd,LONG pStyle)
prop CSTRING('BrowseGridBarProc')
old  LONG,AUTO
sty  LONG,AUTO
  CODE
  IF ~pHwnd THEN RETURN 0.
  IF bgApi_GetProp(pHwnd,ADDRESS(prop)) THEN RETURN 0.
!  Only the horizontal bar is Windows'. The vertical one is drawn by the grid,
!  because Windows' cannot be made to follow the data: it drags inside a
!  message loop of its own, and moving the browse needs records, which needs
!  ACCEPT, which that loop is holding up. Sideways needed nothing from the
!  browse so it could be done inside the loop; downwards cannot be.
!  The subclass goes on whatever the style, because the roller comes through it
!  too. The SCROLLBAR only goes on for the Windows style - the other two draw
!  their own, and a Windows bar underneath would take width for nothing.
  IF pStyle = 0
    sty = bgApi_GetWindowLong(pHwnd,BG:GwlStyle)
    bgApi_SetWindowLong(pHwnd,BG:GwlStyle,BOR(sty,BG:HScrollStyle))
  END
  bgApi_SetWindowPos(pHwnd,0,0,0,0,0,BOR(BOR(BOR(BG:FrameChanged,BG:NoMove),BG:NoSize),BG:NoZOrder))
  old = bgApi_SetWindowLong(pHwnd,BG:GwlWndProc,ADDRESS(BG_BarProc))
  IF ~old THEN RETURN 0.
  bgApi_SetProp(pHwnd,ADDRESS(prop),old)
  RETURN 1

BG_DropBars PROCEDURE(LONG pHwnd)
prop CSTRING('BrowseGridBarProc')
old  LONG,AUTO
  CODE
  IF ~pHwnd THEN RETURN 0.
  old = bgApi_GetProp(pHwnd,ADDRESS(prop))
  IF old
    bgApi_SetWindowLong(pHwnd,BG:GwlWndProc,old)
  END
  bgApi_RemoveProp(pHwnd,ADDRESS(prop))
  RETURN old

BG_SetBar PROCEDURE(LONG pHwnd,LONG pBar,LONG pPos,LONG pPage,LONG pTotal)
si   GROUP
cbSize  ULONG
fMask   ULONG
nMin    LONG
nMax    LONG
nPage   ULONG
nPos    LONG
nTrack  LONG
     END
  CODE
  IF ~pHwnd THEN RETURN.
  si.cbSize = SIZE(si)
  si.fMask  = BOR(BOR(BG:SifRange,BG:SifPage),BG:SifPos)
  si.nMin   = 0
  si.nMax   = pTotal - 1
  si.nPage  = pPage
  si.nPos   = pPos
  bgApi_SetScrollInfo(pHwnd,pBar,ADDRESS(si),1)

BG_BarPos PROCEDURE(LONG pHwnd,LONG pBar)
si   GROUP
cbSize  ULONG
fMask   ULONG
nMin    LONG
nMax    LONG
nPage   ULONG
nPos    LONG
nTrack  LONG
     END
  CODE
  IF ~pHwnd THEN RETURN 0.
  si.cbSize = SIZE(si)
  si.fMask  = BG:SifPos
  IF ~bgApi_GetScrollInfo(pHwnd,pBar,ADDRESS(si)) THEN RETURN 0.
  RETURN si.nPos

!  Windows does not work out the new position for a scroll message; this does,
!  writes it back, leaves what happened in the globals and tells the ACCEPT
!  loop. Horizontal scrolling is the grid's own business - it just slides the
!  columns. Vertical is the BROWSE's, so it is passed on rather than acted on.
BG_BarProc PROCEDURE(ULONG hWnd,ULONG wMsg,ULONG wParam,LONG lParam)
prop CSTRING('BrowseGridBarProc')
old  LONG,AUTO
g    LONG,AUTO
dz   LONG,AUTO
bar  LONG,AUTO
code LONG,AUTO
pos  LONG,AUTO
si   GROUP
cbSize  ULONG
fMask   ULONG
nMin    LONG
nMax    LONG
nPage   ULONG
nPos    LONG
nTrack  LONG
     END
  CODE
  old = bgApi_GetProp(hWnd,ADDRESS(prop))
!  The roller. Windows sends this to whatever is under the pointer, which is
!  the region - the LIST underneath is invisible and cannot be hit. There is no
!  modal loop involved here, so unlike a thumb drag it is enough to post: the
!  ACCEPT loop runs between notches and the browse fetches its records as it
!  always would.
  IF wMsg = BG:WmMouseWheel
    dz = BSHIFT(BAND(wParam,0FFFF0000h),-16)
    IF dz > 32767 THEN dz -= 65536.                           ! it is a SIGNED short up there
    IF dz
      IF BAND(wParam,BG:MkControl)
!  Ctrl and the roller: bigger and smaller type, the way every other program
!  does it. The rows grow with the font, so the browse is told to reload - it
!  fits a different number of records now.
        g = d2g_FromHwnd(hWnd)
        IF g
          d2g_FontSize(g,d2g_FontPt(g) + CHOOSE(dz > 0, 1, -1))
          d2g_PaintNow(g)
          BG:LastBar  = BG:SbVert
          BG:LastCode = BG:FontCode
          BG:LastPos  = 0
          POST(BG:Scrolled)
        END
      ELSE
        BG:LastBar  = BG:SbVert
        BG:LastCode = BG:WheelCode
        BG:LastPos  = dz
        POST(BG:Scrolled)
      END
    END
  END
  IF wMsg = BG:WmHScroll OR wMsg = BG:WmVScroll
    bar = CHOOSE(wMsg = BG:WmHScroll, BG:SbHorz, BG:SbVert)
    code = BAND(wParam,0FFFFh)
    si.cbSize = SIZE(si)
    si.fMask  = BOR(BOR(BOR(BG:SifRange,BG:SifPage),BG:SifPos),BG:SifTrack)
    IF bgApi_GetScrollInfo(hWnd,bar,ADDRESS(si))
      pos = si.nPos
      CASE code
      OF 0
        pos -= INT(si.nPage / 8) + 1
      OF 1
        pos += INT(si.nPage / 8) + 1
      OF 2
        pos -= si.nPage
      OF 3
        pos += si.nPage
      OF 4
        pos = si.nTrack
      OF 5
        pos = si.nTrack
      OF 6
        pos = si.nMin
      OF 7
        pos = si.nMax
      END
      IF pos > si.nMax - si.nPage + 1 THEN pos = si.nMax - si.nPage + 1.
      IF pos < si.nMin THEN pos = si.nMin.
      IF bar = BG:SbHorz                                      ! ours: just move the columns
        si.fMask = BG:SifPos
        si.nPos  = pos
        bgApi_SetScrollInfo(hWnd,bar,ADDRESS(si),1)
!  AND MOVE THEM NOW, not on the next ACCEPT. Dragging a scrollbar thumb puts
!  Windows into a message loop of its OWN, and Clarion's ACCEPT does not get a
!  turn until the button comes back up - so anything POSTed from here just
!  queues, and the columns would not budge until you let go. Scrolling
!  sideways needs nothing from the browse though: it is the grid's own pixels.
!  So it is done right here, synchronously, and painted immediately rather than
!  invalidated - an invalidated window would not be repainted until the loop
!  ends either. Downwards is not like this: that one needs records, which only
!  the browse can fetch, so it still waits for the button.
        g = d2g_FromHwnd(hWnd)
        IF g
          d2g_ScrollX(g,pos)
          d2g_PaintNow(g)
        END
      END
      BG:LastBar  = bar
      BG:LastCode = code
      BG:LastPos  = pos
      POST(BG:Scrolled)
    END
  END
  IF old
    RETURN bgApi_CallWndProc(old,hWnd,wMsg,wParam,lParam)
  END
  RETURN 0

!  A line into BrowseGrid.log, beside the executable. Opened, appended to and
!  closed on every call rather than held open: a diagnostic that keeps a
!  handle on a file is a diagnostic that changes what it is measuring, and
!  worse, one that loses the last lines when the thing being diagnosed falls
!  over - which is exactly when they matter.
BG_Log PROCEDURE(STRING pText)
fn   CSTRING(261),AUTO
ln   CSTRING(601),AUTO
h    LONG,AUTO
wr   LONG,AUTO
  CODE
  fn = 'BrowseGrid.log'
  ln = CLIP(pText) & CHR(13) & CHR(10)
  h = bgApi_CreateFile(ADDRESS(fn),40000000h,1,0,4,80h,0)     ! write, share read, open always
  IF h = -1 THEN RETURN.
  bgApi_SetFilePointer(h,0,0,2)                               ! to the end
  bgApi_WriteFile(h,ADDRESS(ln),LEN(ln),ADDRESS(wr),0)
  bgApi_CloseHandle(h)

!  A colour taken out of the BROWSE QUEUE, which is not quite the same thing.
!  ABC writes COLOR:None - which is -1 - into the colour fields of a row where
!  no condition fired, and -1 is not a colour: it has to arrive at the grid AS
!  -1, so the row keeps the colour it would have had. Everything else goes
!  through BG_Rgb, system colours included - and note that those are negative
!  too, which is exactly why this tests for -1 and not for 'less than zero'.
!  Un valor que va a entrar en una expresion de filtro, con sus comillas
!  duplicadas. Un apellido como O<39>Brien cierra la cadena antes de tiempo y lo
!  que sigue queda como sintaxis suelta. Y no falla el programa: falla la
!  EXPRESION, asi que el filtro no coincide con nada y no hay nada que lo
!  diga - de las maneras que tiene esto de fallar callado, es la mas facil
!  de encontrarse en datos reales.
BG_Quote PROCEDURE(STRING pVal)
out CSTRING(261)
i   LONG,AUTO
  CODE
  out = ''
  LOOP i = 1 TO LEN(CLIP(pVal))
    out = out & pVal[i]
    IF pVal[i] = '''' THEN out = out & ''''.
  END
  RETURN out

BG_Colr PROCEDURE(LONG pColor)
  CODE
  IF pColor = -1 THEN RETURN -1.
  RETURN BG_Rgb(pColor)

!  A Clarion COLOR is a BGR long; Direct2D wants 0xRRGGBB. One place, once.
BG_Rgb PROCEDURE(LONG pColor)
c LONG,AUTO
  CODE
  c = pColor
!  A system colour is 80000000h plus the index Windows knows it by - COLOR:Window
!  is 80000005h, and COLOR_WINDOW is 5 - so as a signed LONG it arrives negative
!  and is not a colour at all yet. Ask Windows what that index means NOW, and the
!  grid follows whatever theme the machine is wearing. Painting it white instead
!  was right on exactly one theme and wrong on every other, and it is what put
!  white text on a white row for anyone running dark.
  IF c < 0
    c = bgApi_GetSysColor(BAND(c,0FFh))
  END
  RETURN BOR(BOR(BSHIFT(BAND(c,00000FFh),16),BAND(c,000FF00h)),                |
             BSHIFT(BAND(c,0FF0000h),-16))
#ENDAT
#!#############################################################################
#!  PROCEDURE EXTENSION - BrowseGrid
#!#############################################################################
#EXTENSION(BrowseGrid,'BrowseGrid - draw this browse with Direct2D'),PROCEDURE,MULTI,REQ(BrowseGridGlobal),DESCRIPTION('Grid on ' & %bgList)
#SHEET
  #TAB('Browse')
    #BOXED('This grid')
      #PROMPT('&Disable this grid',CHECK),%bgDisable,DEFAULT(0),AT(10)
      #PROMPT('Show grid diagnostics in the window &title',CHECK),%bgDiag,DEFAULT(0),AT(10)
      #DISPLAY('And a line in BrowseGrid.log whenever the columns change.')
      #PROMPT('&Object name:',@s64),%bgObject,REQ,DEFAULT('Grid' & %ActiveTemplateInstance)
      #PROMPT('Lan&guage:',DROP('As the application[APP]|English[EN]|Castellano[ES]')),%bgLang,DEFAULT('APP')
      #DISPLAY('Of the texts the END USER sees. These prompts stay in English.')
    #ENDBOXED
    #BOXED('What it draws')
      #PROMPT('&LIST control to take over:',CONTROL),%bgList,REQ
      #PROMPT('Browse &queue:',@s64),%bgQueue,DEFAULT('')
      #DISPLAY('Blank: read from the LIST<39>s FROM(). Fill it in only for a LIST')
      #DISPLAY('bound with PROP:From at run time, where there is no FROM() to read.')
      #PROMPT('F&ile the browse reads:',@s64),%bgFile,DEFAULT('')
      #DISPLAY('Blank: this procedure<39>s primary. Sizes the scrollbar thumb and')
      #DISPLAY('feeds Filter by value.')
      #PROMPT('&Re-read the columns once the window has opened',CHECK),%bgReread,DEFAULT(0),AT(10)
      #DISPLAY('Only if the application configures columns at run time - a picture')
      #DISPLAY('from a global, a heading built in code. Costs a second pass.')
    #ENDBOXED
  #ENDTAB
  #TAB('Columns')
    #BOXED('Where they come from')
      #DISPLAY('The LIST itself, at run time: widths, headings, pictures and')
      #DISPLAY('alignment, including any the user has resized or reordered.')
    #ENDBOXED
    #BOXED('Behaviour')
      #PROMPT('&Frozen columns (stay put when scrolled sideways):',SPIN(@n2,0,8,1)),%bgFrozen,DEFAULT(0)
      #PROMPT('Let the user re&size columns by dragging',CHECK),%bgSizeable,DEFAULT(1),AT(10)
      #PROMPT('Sor&t when a heading is clicked',CHECK),%bgSortHdr,DEFAULT(1),AT(10)
      #PROMPT('&Columns... on the heading menu (show and hide columns)',CHECK),%bgChooser,DEFAULT(1),AT(10)
      #PROMPT('Re&member this grid<39>s layout between runs',CHECK),%bgRemember,DEFAULT(1),AT(10)
      #DISPLAY('Widths and filters, through the application<39>s own INIMgr.')
      #PROMPT('Flatten a grouped or multi-&line format',CHECK),%bgFlatten,DEFAULT(1),AT(10)
      #DISPLAY('Every field becomes a column of its own on a single line, so')
      #DISPLAY('resizing, sorting and freezing work per field.')
    #ENDBOXED
    #BOXED('Totals')
      #PROMPT('A row of t&otals along the bottom',CHECK),%bgTotals,DEFAULT(0),AT(10)
      #DISPLAY('Adds up every record the browse shows, filter included - not just')
      #DISPLAY('the page. One pass over the view, paid again when the filter')
      #DISPLAY('changes. Which columns add up is decided by their picture.')
    #ENDBOXED
  #ENDTAB
#!-----------------------------------------------------------------------------
#! TODO LO QUE VIVE EN EL MENU DEL ENCABEZADO, junto. Los dos recuadros de aca
#! cuelgan del mismo tilde - sin el boton desplegable no hay menu donde ponerlo
#! - asi que separarlos de las opciones de columna es agruparlos por lo que
#! realmente comparten.
#!-----------------------------------------------------------------------------
  #TAB('Heading menu')
    #BOXED('What the menu offers')
      #DISPLAY('Cada opcion se puede sacar. El menu se arma con las que queden y')
      #DISPLAY('el CASE se renumera solo, asi que sacar una no descoloca al resto.')
      #DISPLAY('Sin ninguna, no se abre menu.')
      #PROMPT('Take these from the &global extension',CHECK),%bgGlobMenu,DEFAULT(0),AT(10)
      #DISPLAY('Todo lo de esta solapa - y el boton desplegable - sale de la')
      #DISPLAY('extension global, para no repetirlo browse por browse. Si la')
      #DISPLAY('extension global no esta, se usa lo de aca abajo.')
      #DISPLAY('')
      #DISPLAY('OJO: el boton desplegable viene APAGADO tambien en la global, asi')
      #DISPLAY('que tildar esto sin haberlo encendido alla deja el browse sin menu.')
      #DISPLAY('Los valores de la global son los de fabrica hasta que los toques.')
      #ENABLE(%bgGlobMenu = 0)
      #PROMPT('&Sort Ascending / Descending',CHECK),%bgMnSort,DEFAULT(1),AT(10)
      #PROMPT('Filter on &this value',CHECK),%bgMnFiltOn,DEFAULT(1),AT(10)
      #PROMPT('Clear this f&ilter',CHECK),%bgMnClrThis,DEFAULT(1),AT(10)
      #PROMPT('Clear &all filters',CHECK),%bgMnClrAll,DEFAULT(1),AT(10)
      #PROMPT('&Reset layout',CHECK),%bgMnReset,DEFAULT(1),AT(10)
      #PROMPT('La&youts... (save and recall column layouts)',CHECK),%bgSchemes,DEFAULT(0),AT(10)
      #DISPLAY('  Guarda las columnas visibles, sus anchos y cuales totalizan,')
      #DISPLAY('  con un nombre. Necesita que este puesto Remember this grid<39>s')
      #DISPLAY('  layout between runs, que es donde vive el almacenamiento.')
      #ENDENABLE
      #DISPLAY('')
      #DISPLAY('Columns... sale del tilde de la solapa Columns, Filter by value y')
      #DISPLAY('Find text de los de aca abajo, y Auto-fit del de su recuadro.')
    #ENDBOXED
    #BOXED('Filtering')
      #PROMPT('&Excel-style drop-down button on every heading',CHECK),%bgFilterBtn,DEFAULT(0),AT(10)
      #ENABLE(%bgFilterBtn)
        #PROMPT('  Offer &Filter by value... on that menu',CHECK),%bgFilterVals,DEFAULT(1),AT(10)
        #PROMPT('  Offer Fi&nd text... on that menu',CHECK),%bgFilterText,DEFAULT(1),AT(10)
        #DISPLAY('  Free text, in this column or in all of them. No scan: it becomes a')
        #DISPLAY('  filter like any other, so it costs what any filter costs.')
        #DISPLAY('  Reads the whole FILE to collect the distinct values of the column.')
        #DISPLAY('  It is the only sequential scan this template does: on a big table')
        #DISPLAY('  over a slow link it is a visible freeze. Untick it to drop the')
        #DISPLAY('  option from the menu entirely.')
      #ENDENABLE
      #ENABLE(%bgFilterBtn)
        #PROMPT('  Browse o&bject:',@s64),%bgBrowseObj,DEFAULT('')
        #DISPLAY('  Blank: worked out from the queue name. Filtering goes through')
        #DISPLAY('  the object<39>s own SetFilter, so range limits keep working.')
      #ENDENABLE
    #ENDBOXED
    #BOXED('Auto-fit')
      #ENABLE(%bgFilterBtn)
        #PROMPT('A&uto-fit column widths on the heading menu',CHECK),%bgAutoFit,DEFAULT(1),AT(10)
        #DISPLAY('  Sizes every visible column to the widest of its heading and its')
        #DISPLAY('  values, in one go. Needs the drop-down button, which is where')
        #DISPLAY('  the option lives.')
        #DISPLAY('')
        #DISPLAY('  Needs a FLATTENED format too. In a grouped one the width that')
        #DISPLAY('  governs the layout belongs to the GROUP, and sizing the fields')
        #DISPLAY('  inside it without touching that would leave the spanning heading')
        #DISPLAY('  at its old width. With Flatten off the option is not offered.')
        #ENABLE(%bgAutoFit)
          #PROMPT('  Records to look &ahead:',SPIN(@n7,0,100000,500)),%bgFitScan,DEFAULT(1000)
          #DISPLAY('  The loaded page is measured exactly and costs nothing - it is')
          #DISPLAY('  already in memory. Beyond it the browse<39>s own view is walked,')
          #DISPLAY('  which is real reading: this is the dial for how much of it.')
          #DISPLAY('  At 0 only what is loaded is measured, and no file is touched.')
        #ENDENABLE
      #ENDENABLE
    #ENDBOXED
  #ENDTAB
  #TAB('Look')
    #ENABLE(%bgGlobLook = 0)
    #BOXED('Type')
      #PROMPT('Take all of this from the &global extension',CHECK),%bgGlobLook,DEFAULT(0),AT(10)
      #DISPLAY('Tipografia, colores y variables salen de la extension global, para')
      #DISPLAY('no repetirlos browse por browse. Las tres solapas juntas, porque')
      #DISPLAY('Variables pisa a Look y a Colours: heredar una sola dejaria mitad')
      #DISPLAY('de un tema y mitad de otro. Sin extension global, se usa lo de aca.')
      #PROMPT('Take the typeface from SD &Aspecto',CHECK),%bgSDAsp,DEFAULT(0),AT(10)
      #DISPLAY('Font and size come from that application<39>s SDAspecto extension, so')
      #DISPLAY('the grid follows the same typography as everything else. The colours')
      #DISPLAY('below are unaffected.')
      #DISPLAY('')
      #DISPLAY('If SDAspecto is not in the application, or its typography is switched')
      #DISPLAY('off, or its size is -1 (leave alone), the settings below are used.')
      #ENABLE(%bgSDAsp = 0)
        #PROMPT('&Font:',@s32),%bgFont,DEFAULT('Segoe UI')
        #PROMPT('&Size (points):',SPIN(@n3,6,24,1)),%bgSize,DEFAULT(9)
      #ENDENABLE
      #PROMPT('Draw the text the way the LIST does (&GDI)',CHECK),%bgGdiText,DEFAULT(1),AT(10)
      #PROMPT('Font wei&ght:',DROP('As the name says[0]|Light[300]|Regular[400]|Medium[500]|SemiBold[600]|Bold[700]')),%bgWeight,DEFAULT('0')
      #DISPLAY('A family name can carry the weight in it. <39>Roboto Medium<39> is a')
      #DISPLAY('family to GDI, which resolves it to the Medium face; DirectWrite')
      #DISPLAY('may hand that same family its 400-weight member instead. When it')
      #DISPLAY('does you are not seeing the same text rendered differently - you')
      #DISPLAY('are seeing two different FACES, and no amount of contrast will')
      #DISPLAY('match them. Name the weight here and the guessing stops.')
      #DISPLAY('A LIST is drawn by GDI and the grid by DirectWrite, and they do not')
      #DISPLAY('render alike: GDI snaps the stems to the pixel grid and adds')
      #DISPLAY('contrast, so they look thicker. Side by side in one window the')
      #DISPLAY('grid reads as thinner even though the typeface and the size are')
      #DISPLAY('identical. Ticked, the grid is told to hint the way GDI does.')
      #DISPLAY('')
      #DISPLAY('Untick it to get DirectWrite<39>s own rendering, which is smoother')
      #DISPLAY('and lighter - better on its own, different from everything else.')
      #PROMPT('&Wrap text that is too long for its column',CHECK),%bgWrap,DEFAULT(0),AT(10)
      #ENABLE(%bgWrap)
        #PROMPT('  &Lines a cell may use:',SPIN(@n1,2,4,1)),%bgWrapLines,DEFAULT(2)
      #ENDENABLE
      #DISPLAY('Every row is that many lines tall, whether its text needs them or not.')
      #PROMPT('&Row height (pixels, 0 = follow the browse):',SPIN(@n3,0,80,1)),%bgRowH,DEFAULT(0)
      #PROMPT('&Header height (pixels, 0 = from the font):',SPIN(@n3,0,80,1)),%bgHdrH,DEFAULT(0)
    #ENDBOXED
    #ENDENABLE
  #ENDTAB
  #TAB('Colours')
    #ENABLE(%bgGlobLook = 0)
    #BOXED('Colours')
      #PROMPT('&Background:',COLOR),%bgCBack,DEFAULT(00FFFFFFH)
      #PROMPT('B&anding (every other row):',COLOR),%bgCBand,DEFAULT(00FAF7F5H)
      #PROMPT('&Gridlines:',COLOR),%bgCGrid,DEFAULT(00EAE5E1H)
      #PROMPT('&Text:',COLOR),%bgCText,DEFAULT(0033291FH)
      #PROMPT('Header bac&kground:',COLOR),%bgCHdrBack,DEFAULT(004A3A2BH)
      #PROMPT('Header te&xt:',COLOR),%bgCHdrText,DEFAULT(00FFFFFFH)
      #PROMPT('Selected ro&w:',COLOR),%bgCSelBack,DEFAULT(00B56F2FH)
      #PROMPT('Selected t&ext:',COLOR),%bgCSelText,DEFAULT(00FFFFFFH)
      #DISPLAY('A column or a cell with its own colour overrides these.')
    #ENDBOXED
    #ENDENABLE
  #ENDTAB
  #TAB('Variables')
    #ENABLE(%bgGlobLook = 0)
    #BOXED('From application variables')
      #PROMPT('Take any of these from a &variable instead',CHECK),%bgVars,DEFAULT(0),AT(10)
      #DISPLAY('A field left blank keeps the setting above. One with a name in it is')
      #DISPLAY('emitted as code, so a global theme can drive the grid.')
      #ENABLE(%bgVars AND %bgSDAsp = 0)
        #PROMPT('  Font name:',@s64),%bgVFont,DEFAULT('')
        #PROMPT('  Size:',@s64),%bgVSize,DEFAULT('')
      #ENDENABLE
      #ENABLE(%bgVars)
        #PROMPT('  Background:',@s64),%bgVCBack,DEFAULT('')
        #PROMPT('  Banding:',@s64),%bgVCBand,DEFAULT('')
        #PROMPT('  Gridlines:',@s64),%bgVCGrid,DEFAULT('')
        #PROMPT('  Text:',@s64),%bgVCText,DEFAULT('')
        #PROMPT('  Header background:',@s64),%bgVCHdrBack,DEFAULT('')
        #PROMPT('  Header text:',@s64),%bgVCHdrText,DEFAULT('')
        #PROMPT('  Selected row:',@s64),%bgVCSelBack,DEFAULT('')
        #PROMPT('  Selected text:',@s64),%bgVCSelText,DEFAULT('')
      #ENDENABLE
      #DISPLAY('Read once, when the grid starts. Changing a variable afterwards does')
      #DISPLAY('not repaint it on its own.')
    #ENDBOXED
    #ENDENABLE
  #ENDTAB
  #TAB('Mouse')
    #ENABLE(%bgGlobMouse = 0)
    #BOXED('Scrollbars')
      #PROMPT('Take these from the g&lobal extension',CHECK),%bgGlobMouse,DEFAULT(0),AT(10)
      #DISPLAY('Las columnas que ademas reciben el click NO se heredan: son')
      #DISPLAY('numeros de columna de ESTE browse y no significan nada en otro.')
      #PROMPT('Scroll&bars on the grid',CHECK),%bgBars,DEFAULT(1),AT(10)
      #ENABLE(%bgBars)
        #PROMPT('  St&yle:',DROP('Windows|Slim|Overlay')),%bgBarStyle,DEFAULT('Windows')
      #ENDENABLE
      #DISPLAY('Windows - sideways is Windows<39> own, downward is drawn.')
      #DISPLAY('Slim    - both drawn, thin and flat, in the grid<39>s colours.')
      #DISPLAY('Overlay - both drawn over the rows, only while the pointer is on the')
      #DISPLAY('          grid, so the data keeps the whole width.')
    #ENDBOXED
    #BOXED('Clicks')
      #PROMPT('Hand a right-click back to the browse &popup',CHECK),%bgPopup,DEFAULT(1),AT(10)
      #PROMPT('A &double click opens the record, as the browse does',CHECK),%bgDouble,DEFAULT(1),AT(10)
      #PROMPT('Scroll with the mouse &wheel',CHECK),%bgWheel,DEFAULT(1),AT(10)
      #DISPLAY('Ctrl and the wheel makes the type bigger and smaller.')
      #PROMPT('Show the whole value in a t&ooltip when it does not fit',CHECK),%bgTips,DEFAULT(1),AT(10)
      #PROMPT('LIST columns that also get the &click:',@s32),%bgClickCols,DEFAULT('')
      #DISPLAY('Column NUMBERS, comma separated. For templates that tag or toggle by')
      #DISPLAY('clicking a column - DAS_Tagging reads PROPLIST:MouseDownField, and the')
      #DISPLAY('grid covers the LIST so that click never reaches it. Blank unless you')
      #DISPLAY('need it.')
    #ENDBOXED
    #ENDENABLE
  #ENDTAB
#ENDSHEET
#!-----------------------------------------------------------------------------
#!  WHERE THE QUEUE COMES FROM. The LIST's own FROM() attribute, read at
#!  generate time with EXTRACT(%ControlStatement,'FROM',1) - the same call the
#!  shipped BrowseBox makes at ABBROWSE.TPW:825, and the same one myExport
#!  makes to read any list with nothing to type. Typing that name was the one
#!  prompt most likely to be got wrong, and a wrong queue is silent: the grid
#!  draws, empty, over a browse that is working perfectly.
#ATSTART
  #DECLARE(%bgQueueUsed)
  #SET(%bgQueueUsed,%bgQueue)
  #IF(~%bgQueueUsed)
    #FOR(%Control),WHERE(%Control=%bgList)
      #SET(%bgQueueUsed,EXTRACT(%ControlStatement,'FROM',1))
    #ENDFOR
  #ENDIF
#!  AND THE BROWSE OBJECT FROM THE QUEUE. A browse's control, its queue and its
#!  object all carry the SAME instance number - ?Browse:5 is filled from Queue:5
#!  by BRW5 - so the queue just read already says which object it is. The number
#!  is read off the END of the name rather than matched against a prefix,
#!  because the prefix is not one thing: real applications carry Queue:Browse,
#!  Queue:Browse:1 and Queue:5 side by side. No number at all is the first
#!  browse, which is what Queue:Browse means.
#!
#!  A wrong guess here cannot pass quietly: BRW7 that does not exist is an
#!  unknown identifier at compile time, said out loud, on the line that wanted
#!  it. That is the failure mode to want - and the prompt is there to override.
  #DECLARE(%bgBrowseUsed)
  #DECLARE(%bgDigits)
  #DECLARE(%bgAt)
  #DECLARE(%bgI)
  #SET(%bgBrowseUsed,%bgBrowseObj)
  #IF(~%bgBrowseUsed AND %bgQueueUsed)
    #SET(%bgDigits,'')
    #SET(%bgAt,LEN(CLIP(%bgQueueUsed)))
    #LOOP,FOR(%bgI,1,4)
      #IF(%bgAt < 1)
        #BREAK
      #ENDIF
      #IF(INSTRING(SUB(%bgQueueUsed,%bgAt,1),'0123456789',1,1) = 0)
        #BREAK
      #ENDIF
      #SET(%bgDigits,SUB(%bgQueueUsed,%bgAt,1) & %bgDigits)
      #SET(%bgAt,%bgAt - 1)
    #ENDLOOP
    #IF(~%bgDigits)
      #SET(%bgDigits,'1')
    #ENDIF
    #SET(%bgBrowseUsed,'BRW' & %bgDigits)
  #ENDIF
#!  LOS TEXTOS QUE VE EL USUARIO FINAL. Se resuelven ACA, en generacion, no
#!  en ejecucion: la cadena elegida queda escrita en el fuente y no hay tabla
#!  que cargar ni consulta que hacer. Los prompts de AppGen NO entran - los
#!  lee el programador, no el usuario - y la linea de diagnostico tampoco,
#!  que es una herramienta de depuracion y no parte del producto.
#!
#!  El idioma sale de la extension global, salvo que este grid diga otra cosa.
#!  Leer un prompt de la extension global desde una de procedimiento necesita
#!  #CONTEXT(%Application): son ambitos distintos, y sin eso el simbolo no
#!  existe. VAREXISTS lo cubre por si la extension global no estuviera puesta.
#!  (Precedente en el corpus: CRTABCRPT.TPW:66, que documenta este mismo
#!  cambio de ambito.)
!  Y EL ARCHIVO, igual que el queue y el objeto: en blanco es el primario del
!  procedimiento, que en un browse es el archivo que el browse lee. Sigue
!  siendo una etiqueta y no un prompt de archivo - nombrarla aca no cambia lo
!  que AppGen considera que el procedimiento usa.
!  LOS NUMEROS DEL MENU, calculados. POPUP devuelve la POSICION del item, asi
!  que sacar uno corre todos los que siguen - y el CASE que los atiende sigue
!  diciendo lo mismo. Este template ya se comio ese error una vez, con los
!  separadores que contaban como items: limpiar un filtro terminaba aplicando
!  uno. Calculados aca, la lista y el CASE no pueden discrepar.
!  LOCAL O GLOBAL, para la apariencia y el raton. Mismo criterio que el menu:
!  resuelto en un solo punto, porque cada uno de estos gobierna varios #IF de
!  generacion y dos usos que discrepen dan codigo incoherente.
  #DECLARE(%bgSDAspU)
  #DECLARE(%bgFontU)
  #DECLARE(%bgSizeU)
  #DECLARE(%bgGdiTextU)
  #DECLARE(%bgWeightU)
  #DECLARE(%bgWrapU)
  #DECLARE(%bgWrapLinesU)
  #DECLARE(%bgRowHU)
  #DECLARE(%bgHdrHU)
  #DECLARE(%bgCBackU)
  #DECLARE(%bgCBandU)
  #DECLARE(%bgCGridU)
  #DECLARE(%bgCTextU)
  #DECLARE(%bgCHdrBackU)
  #DECLARE(%bgCHdrTextU)
  #DECLARE(%bgCSelBackU)
  #DECLARE(%bgCSelTextU)
  #DECLARE(%bgVarsU)
  #DECLARE(%bgVFontU)
  #DECLARE(%bgVSizeU)
  #DECLARE(%bgVCBackU)
  #DECLARE(%bgVCBandU)
  #DECLARE(%bgVCGridU)
  #DECLARE(%bgVCTextU)
  #DECLARE(%bgVCHdrBackU)
  #DECLARE(%bgVCHdrTextU)
  #DECLARE(%bgVCSelBackU)
  #DECLARE(%bgVCSelTextU)
  #DECLARE(%bgBarsU)
  #DECLARE(%bgBarStyleU)
  #DECLARE(%bgPopupU)
  #DECLARE(%bgDoubleU)
  #DECLARE(%bgWheelU)
  #DECLARE(%bgTipsU)
  #DECLARE(%bgAutoFitU)
  #DECLARE(%bgSchemesU)
  #DECLARE(%bgFitScanU)
  #SET(%bgSDAspU,%bgSDAsp)
  #SET(%bgFontU,%bgFont)
  #SET(%bgSizeU,%bgSize)
  #SET(%bgGdiTextU,%bgGdiText)
  #SET(%bgWeightU,%bgWeight)
  #SET(%bgWrapU,%bgWrap)
  #SET(%bgWrapLinesU,%bgWrapLines)
  #SET(%bgRowHU,%bgRowH)
  #SET(%bgHdrHU,%bgHdrH)
  #SET(%bgCBackU,%bgCBack)
  #SET(%bgCBandU,%bgCBand)
  #SET(%bgCGridU,%bgCGrid)
  #SET(%bgCTextU,%bgCText)
  #SET(%bgCHdrBackU,%bgCHdrBack)
  #SET(%bgCHdrTextU,%bgCHdrText)
  #SET(%bgCSelBackU,%bgCSelBack)
  #SET(%bgCSelTextU,%bgCSelText)
  #SET(%bgVarsU,%bgVars)
  #SET(%bgVFontU,%bgVFont)
  #SET(%bgVSizeU,%bgVSize)
  #SET(%bgVCBackU,%bgVCBack)
  #SET(%bgVCBandU,%bgVCBand)
  #SET(%bgVCGridU,%bgVCGrid)
  #SET(%bgVCTextU,%bgVCText)
  #SET(%bgVCHdrBackU,%bgVCHdrBack)
  #SET(%bgVCHdrTextU,%bgVCHdrText)
  #SET(%bgVCSelBackU,%bgVCSelBack)
  #SET(%bgVCSelTextU,%bgVCSelText)
  #SET(%bgBarsU,%bgBars)
  #SET(%bgBarStyleU,%bgBarStyle)
  #SET(%bgPopupU,%bgPopup)
  #SET(%bgDoubleU,%bgDouble)
  #SET(%bgWheelU,%bgWheel)
  #SET(%bgTipsU,%bgTips)
  #SET(%bgAutoFitU,%bgAutoFit)
  #SET(%bgSchemesU,%bgSchemes)
  #SET(%bgFitScanU,%bgFitScan)
  #IF(%bgGlobLook)
    #CONTEXT(%Application)
      #IF(VAREXISTS(%bgGSDAsp))
        #SET(%bgSDAspU,%bgGSDAsp)
        #SET(%bgFontU,%bgGFont)
        #SET(%bgSizeU,%bgGSize)
        #SET(%bgGdiTextU,%bgGGdiText)
        #SET(%bgWeightU,%bgGWeight)
        #SET(%bgWrapU,%bgGWrap)
        #SET(%bgWrapLinesU,%bgGWrapLines)
        #SET(%bgRowHU,%bgGRowH)
        #SET(%bgHdrHU,%bgGHdrH)
        #SET(%bgCBackU,%bgGCBack)
        #SET(%bgCBandU,%bgGCBand)
        #SET(%bgCGridU,%bgGCGrid)
        #SET(%bgCTextU,%bgGCText)
        #SET(%bgCHdrBackU,%bgGCHdrBack)
        #SET(%bgCHdrTextU,%bgGCHdrText)
        #SET(%bgCSelBackU,%bgGCSelBack)
        #SET(%bgCSelTextU,%bgGCSelText)
        #SET(%bgVarsU,%bgGVars)
        #SET(%bgVFontU,%bgGVFont)
        #SET(%bgVSizeU,%bgGVSize)
        #SET(%bgVCBackU,%bgGVCBack)
        #SET(%bgVCBandU,%bgGVCBand)
        #SET(%bgVCGridU,%bgGVCGrid)
        #SET(%bgVCTextU,%bgGVCText)
        #SET(%bgVCHdrBackU,%bgGVCHdrBack)
        #SET(%bgVCHdrTextU,%bgGVCHdrText)
        #SET(%bgVCSelBackU,%bgGVCSelBack)
        #SET(%bgVCSelTextU,%bgGVCSelText)
      #ENDIF
    #ENDCONTEXT
  #ENDIF
  #IF(%bgGlobMouse)
    #CONTEXT(%Application)
      #IF(VAREXISTS(%bgGBars))
        #SET(%bgBarsU,%bgGBars)
        #SET(%bgBarStyleU,%bgGBarStyle)
        #SET(%bgPopupU,%bgGPopup)
        #SET(%bgDoubleU,%bgGDouble)
        #SET(%bgWheelU,%bgGWheel)
        #SET(%bgTipsU,%bgGTips)
      #ENDIF
    #ENDCONTEXT
  #ENDIF
  #IF(%bgGlobMenu)
    #CONTEXT(%Application)
      #IF(VAREXISTS(%bgGAutoFit))
        #SET(%bgAutoFitU,%bgGAutoFit)
        #SET(%bgFitScanU,%bgGFitScan)
        #SET(%bgSchemesU,%bgGSchemes)
      #ENDIF
    #ENDCONTEXT
  #ENDIF
!  LOCAL O GLOBAL, resuelto UNA VEZ y en simbolos propios.
!
!  No se puede resolver donde se emite cada cosa: estos prompts gobiernan
!  #IF de GENERACION - que rutina se escribe, que opcion entra en el menu, como
!  se numera el CASE - y aparecen en varios lugares cada uno. Resueltos aca, no
!  hay forma de que dos usos del mismo prompt discrepen.
!
!  Con el tilde puesto pero sin extension global en la aplicacion, queda lo
!  local: pedir prestado a algo que no existe no puede apagar un menu entero.
  #DECLARE(%bgFilterBtnU)
  #DECLARE(%bgFilterValsU)
  #DECLARE(%bgFilterTextU)
  #DECLARE(%bgChooserU)
  #DECLARE(%bgMnSortU)
  #DECLARE(%bgMnFiltOnU)
  #DECLARE(%bgMnClrThisU)
  #DECLARE(%bgMnClrAllU)
  #DECLARE(%bgMnResetU)
  #SET(%bgFilterBtnU,%bgFilterBtn)
  #SET(%bgFilterValsU,%bgFilterVals)
  #SET(%bgFilterTextU,%bgFilterText)
  #SET(%bgChooserU,%bgChooser)
  #SET(%bgMnSortU,%bgMnSort)
  #SET(%bgMnFiltOnU,%bgMnFiltOn)
  #SET(%bgMnClrThisU,%bgMnClrThis)
  #SET(%bgMnClrAllU,%bgMnClrAll)
  #SET(%bgMnResetU,%bgMnReset)
  #IF(%bgGlobMenu)
    #CONTEXT(%Application)
      #IF(VAREXISTS(%bgGMnSort))
        #SET(%bgFilterBtnU,%bgGFilterBtn)
        #SET(%bgFilterValsU,%bgGFilterVals)
        #SET(%bgFilterTextU,%bgGFilterText)
        #SET(%bgChooserU,%bgGChooser)
        #SET(%bgMnSortU,%bgGMnSort)
        #SET(%bgMnFiltOnU,%bgGMnFiltOn)
        #SET(%bgMnClrThisU,%bgGMnClrThis)
        #SET(%bgMnClrAllU,%bgGMnClrAll)
        #SET(%bgMnResetU,%bgGMnReset)
      #ENDIF
    #ENDCONTEXT
  #ENDIF
  #DECLARE(%bgMiN)
  #DECLARE(%bgMiAsc)
  #DECLARE(%bgMiDesc)
  #DECLARE(%bgMiFiltOn)
  #DECLARE(%bgMiFiltBy)
  #DECLARE(%bgMiFindTx)
  #DECLARE(%bgMiClrThis)
  #DECLARE(%bgMiClrAll)
  #DECLARE(%bgMiCols)
  #DECLARE(%bgMiAutoFit)
  #DECLARE(%bgMiReset)
  #DECLARE(%bgMiSchemes)
!  Un contador, no numeros escritos a mano. Cada opcion opcional que se agrega
!  o se saca corre a todas las que siguen, y escribirlos sueltos es esperar a
!  que alguna vez no coincidan.
#!  NINGUNO ES FIJO. Antes los tres primeros - ordenar asc, desc y filtrar por
#!  este valor - se daban por puestos y el contador arrancaba en 3, con el CASE
#!  usando OF 1, OF 2 y OF 3 escritos a mano. Poder sacar cualquiera obliga a que
#!  TODOS salgan del mismo contador: un numero escrito a mano entre numeros
#!  calculados es el error que este menu ya se comio una vez.
  #SET(%bgMiN,0)
  #SET(%bgMiAsc,0)
  #SET(%bgMiDesc,0)
  #SET(%bgMiFiltOn,0)
  #SET(%bgMiFiltBy,0)
  #SET(%bgMiFindTx,0)
  #SET(%bgMiClrThis,0)
  #SET(%bgMiClrAll,0)
  #SET(%bgMiCols,0)
  #SET(%bgMiAutoFit,0)
  #SET(%bgMiReset,0)
  #SET(%bgMiSchemes,0)
  #IF(%bgMnSortU)
    #SET(%bgMiN,%bgMiN + 1)
    #SET(%bgMiAsc,%bgMiN)
    #SET(%bgMiN,%bgMiN + 1)
    #SET(%bgMiDesc,%bgMiN)
  #ENDIF
  #IF(%bgMnFiltOnU)
    #SET(%bgMiN,%bgMiN + 1)
    #SET(%bgMiFiltOn,%bgMiN)
  #ENDIF
  #IF(%bgFilterValsU)
    #SET(%bgMiN,%bgMiN + 1)
    #SET(%bgMiFiltBy,%bgMiN)
  #ENDIF
  #IF(%bgFilterTextU)
    #SET(%bgMiN,%bgMiN + 1)
    #SET(%bgMiFindTx,%bgMiN)
  #ENDIF
  #IF(%bgMnClrThisU)
    #SET(%bgMiN,%bgMiN + 1)
    #SET(%bgMiClrThis,%bgMiN)
  #ENDIF
  #IF(%bgMnClrAllU)
    #SET(%bgMiN,%bgMiN + 1)
    #SET(%bgMiClrAll,%bgMiN)
  #ENDIF
  #IF(%bgChooserU)
    #SET(%bgMiN,%bgMiN + 1)
    #SET(%bgMiCols,%bgMiN)
  #ENDIF
  #IF(%bgAutoFitU AND %bgFlatten)
    #SET(%bgMiN,%bgMiN + 1)
    #SET(%bgMiAutoFit,%bgMiN)
  #ENDIF
  #IF(%bgSchemesU AND %bgRemember)
    #SET(%bgMiN,%bgMiN + 1)
    #SET(%bgMiSchemes,%bgMiN)
  #ENDIF
  #IF(%bgMnResetU)
    #SET(%bgMiN,%bgMiN + 1)
    #SET(%bgMiReset,%bgMiN)
  #ENDIF
!  LITERAL O EXPRESION. Un valor puesto en el prompt es una constante y se
!  emite entre comillas; un nombre de variable tiene que salir TAL CUAL para
!  que lo resuelva el compilador. Emitir un nombre entrecomillado no da error:
!  da una fuente que se llama GLO:Tipografia y no existe, o un color que es el
!  numero cero. Por eso se decide aca y no en el codigo emitido.
  #DECLARE(%bgFontUsed)
  #DECLARE(%bgSizeUsed)
  #DECLARE(%bgCBackUsed)
  #DECLARE(%bgCBandUsed)
  #DECLARE(%bgCGridUsed)
  #DECLARE(%bgCTextUsed)
  #DECLARE(%bgCHdrBackUsed)
  #DECLARE(%bgCHdrTextUsed)
  #DECLARE(%bgCSelBackUsed)
  #DECLARE(%bgCSelTextUsed)
!  LA TIPOGRAFIA. Si se pidio integrarse con SDAspecto manda el, pero eso se
!  resuelve EN EJECUCION y no aca; lo unico que hace falta a esta altura es
!  saber COMO SE LLAMA su instancia global. Lo de aca abajo queda igual y pasa
!  a ser el valor de respaldo, para cuando SDAspecto este apagado.
!
!  POR QUE NO SE PUEDE LEER EL PROMPT. Los prompts de SDAspecto son el valor
!  de fabrica, no el que termina aplicando: su propio template lo dice, 'el
!  INI se lee DESPUES de aplicar lo configurado en este template, asi que lo
!  pisa'. Leer el prompt daba el numero equivocado sin fallar nunca - el grid
!  salia en 11 mientras la ventana entera iba en 9, porque el INI decia 9.
  #DECLARE(%bgSDAObj)
  #SET(%bgFontUsed,'')
  #SET(%bgSizeUsed,'')
  #SET(%bgSDAObj,'')
  #IF(%bgSDAspU)
    #CONTEXT(%Application)
!  VAREXISTS por si SDAspecto no esta en esta aplicacion: entonces sus
!  simbolos no existen y preguntarles seria un identificador desconocido.
      #IF(VAREXISTS(%SDAObjName))
        #IF(%SDADisable = 0)
          #SET(%bgSDAObj,%SDAObjName)
        #ENDIF
      #ENDIF
    #ENDCONTEXT
  #ENDIF
  #IF(~%bgFontUsed)
    #IF(%bgVarsU AND %bgVFontU)
      #SET(%bgFontUsed,%bgVFontU)
    #ELSE
      #SET(%bgFontUsed,'''' & %bgFontU & '''')
    #ENDIF
  #ENDIF
  #IF(~%bgSizeUsed)
    #IF(%bgVarsU AND %bgVSizeU)
      #SET(%bgSizeUsed,%bgVSizeU)
    #ELSE
      #SET(%bgSizeUsed,%bgSizeU)
    #ENDIF
  #ENDIF
  #IF(%bgVarsU AND %bgVCBackU)
    #SET(%bgCBackUsed,%bgVCBackU)
  #ELSE
    #SET(%bgCBackUsed,%bgCBackU)
  #ENDIF
  #IF(%bgVarsU AND %bgVCBandU)
    #SET(%bgCBandUsed,%bgVCBandU)
  #ELSE
    #SET(%bgCBandUsed,%bgCBandU)
  #ENDIF
  #IF(%bgVarsU AND %bgVCGridU)
    #SET(%bgCGridUsed,%bgVCGridU)
  #ELSE
    #SET(%bgCGridUsed,%bgCGridU)
  #ENDIF
  #IF(%bgVarsU AND %bgVCTextU)
    #SET(%bgCTextUsed,%bgVCTextU)
  #ELSE
    #SET(%bgCTextUsed,%bgCTextU)
  #ENDIF
  #IF(%bgVarsU AND %bgVCHdrBackU)
    #SET(%bgCHdrBackUsed,%bgVCHdrBackU)
  #ELSE
    #SET(%bgCHdrBackUsed,%bgCHdrBackU)
  #ENDIF
  #IF(%bgVarsU AND %bgVCHdrTextU)
    #SET(%bgCHdrTextUsed,%bgVCHdrTextU)
  #ELSE
    #SET(%bgCHdrTextUsed,%bgCHdrTextU)
  #ENDIF
  #IF(%bgVarsU AND %bgVCSelBackU)
    #SET(%bgCSelBackUsed,%bgVCSelBackU)
  #ELSE
    #SET(%bgCSelBackUsed,%bgCSelBackU)
  #ENDIF
  #IF(%bgVarsU AND %bgVCSelTextU)
    #SET(%bgCSelTextUsed,%bgVCSelTextU)
  #ELSE
    #SET(%bgCSelTextUsed,%bgCSelTextU)
  #ENDIF
  #DECLARE(%bgFileUsed)
  #SET(%bgFileUsed,%bgFile)
  #IF(~%bgFileUsed)
    #SET(%bgFileUsed,%Primary)
  #ENDIF
  #DECLARE(%bgLangUsed)
  #SET(%bgLangUsed,%bgLang)
  #IF(~%bgLangUsed OR %bgLangUsed = 'APP')
    #SET(%bgLangUsed,'EN')
    #CONTEXT(%Application)
      #IF(VAREXISTS(%bgGLang))
        #IF(%bgGLang)
          #SET(%bgLangUsed,%bgGLang)
        #ENDIF
      #ENDIF
    #ENDCONTEXT
  #ENDIF
  #DECLARE(%bgTSortAsc)
  #DECLARE(%bgTSortDesc)
  #DECLARE(%bgTFilterOn)
  #DECLARE(%bgTFilterBy)
  #DECLARE(%bgTClearThis)
  #DECLARE(%bgTClearAll)
  #DECLARE(%bgTColumns)
  #DECLARE(%bgTSchMenu)
  #DECLARE(%bgTSchTitle)
  #DECLARE(%bgTSchHint)
  #DECLARE(%bgTSchName)
  #DECLARE(%bgTSchAs)
  #DECLARE(%bgTSchSave)
  #DECLARE(%bgTSchLoad)
  #DECLARE(%bgTSchDel)
  #DECLARE(%bgTSchClose)
  #DECLARE(%bgTSchNoName)
  #DECLARE(%bgTSchNone)
  #DECLARE(%bgTSchFull)
  #DECLARE(%bgTSchEmpty)
  #DECLARE(%bgTAutoFit)
  #DECLARE(%bgTReset)
  #DECLARE(%bgTNoObject)
  #DECLARE(%bgTNoFile)
  #DECLARE(%bgTOneCol)
  #DECLARE(%bgTColsTitle)
  #DECLARE(%bgTValues)
  #DECLARE(%bgTValuesIn)
  #DECLARE(%bgTKeep)
  #DECLARE(%bgTValue)
  #DECLARE(%bgTShowHdr)
  #DECLARE(%bgTColumnHdr)
  #DECLARE(%bgTAll)
  #DECLARE(%bgTNone)
  #DECLARE(%bgTOk)
  #DECLARE(%bgTCancel)
  #DECLARE(%bgTShowBtn)
  #DECLARE(%bgTHideBtn)
  #DECLARE(%bgTTotHdr)
  #DECLARE(%bgTTotBtn)
  #DECLARE(%bgTNoField)
  #DECLARE(%bgTNoValues)
  #DECLARE(%bgTTooMany)
  #DECLARE(%bgTValsHint)
  #DECLARE(%bgTColsHint)
  #DECLARE(%bgTFindMenu)
  #DECLARE(%bgTFindTitle)
  #DECLARE(%bgTFindHint)
  #DECLARE(%bgTFindLbl)
  #DECLARE(%bgTFindAll)
  #DECLARE(%bgTFindNone)
  #IF(%bgLangUsed = 'EN')
    #SET(%bgTSortAsc,'Sort &Ascending')
    #SET(%bgTSortDesc,'Sort &Descending')
    #SET(%bgTFilterOn,'&Filter on')
    #SET(%bgTFilterBy,'Filter &by value...')
    #SET(%bgTClearThis,'Clear &this filter')
    #SET(%bgTClearAll,'Clear all f&ilters')
    #SET(%bgTColumns,'&Columns...')
    #SET(%bgTSchMenu,'La&youts...')
    #SET(%bgTSchTitle,'Column layouts')
    #SET(%bgTSchHint,'Save the columns you are using under a name, and bring it back later.')
    #SET(%bgTSchName,'Layout')
    #SET(%bgTSchAs,'&Name:')
    #SET(%bgTSchSave,'&Save')
    #SET(%bgTSchLoad,'&Load')
    #SET(%bgTSchDel,'&Delete')
    #SET(%bgTSchClose,'&Close')
    #SET(%bgTSchNoName,'Give the layout a name first.')
    #SET(%bgTSchNone,'Choose a layout from the list first.')
    #SET(%bgTSchFull,'No room for another layout. Delete one you do not use.')
    #SET(%bgTSchEmpty,'That layout has nothing stored in it.')
    #SET(%bgTAutoFit,'Auto-fit &widths')
    #SET(%bgTReset,'&Reset layout')
    #SET(%bgTNoObject,'This grid could not work out which browse object to filter through, because its queue is not named the way ABC names one. Put the object name - BRW1, usually - in Browse object on the BrowseGrid prompts.')
    #SET(%bgTNoFile,'Name the file this browse reads, on the grid prompts, and the column menu can offer the values in it.')
    #SET(%bgTOneCol,'A grid has to show at least one column.')
    #SET(%bgTColsTitle,'Columns')
    #SET(%bgTValues,'Values')
    #SET(%bgTValuesIn,'Values in')
    #SET(%bgTKeep,'Keep')
    #SET(%bgTValue,'Value')
    #SET(%bgTShowHdr,'Show')
    #SET(%bgTColumnHdr,'Column')
    #SET(%bgTAll,'&All')
    #SET(%bgTNone,'&None')
    #SET(%bgTOk,'&OK')
    #SET(%bgTCancel,'&Cancel')
    #SET(%bgTShowBtn,'&Show')
    #SET(%bgTHideBtn,'&Hide')
    #SET(%bgTTotHdr,'Total')
    #SET(%bgTTotBtn,'To&tal')
    #SET(%bgTNoField,'This column does not name a field of the browse queue, so there are no values to look for.')
    #SET(%bgTNoValues,'No values were found in that column.')
    #SET(%bgTTooMany,'Too many values chosen for one filter. Choose fewer, or use Filter on this value.')
    #SET(%bgTValsHint,'Tick the values you want to see. Space toggles the highlighted one.')
    #SET(%bgTFindMenu,'Fi&nd text...')
    #SET(%bgTFindTitle,'Find text')
    #SET(%bgTFindHint,'Type the text to look for. Case is ignored.')
    #SET(%bgTFindLbl,'&Text:')
    #SET(%bgTFindAll,'In &all columns')
    #SET(%bgTFindNone,'There is no column to look for that text in.')
#IF(%bgTotals)
    #SET(%bgTColsHint,'Tick the columns to show, and which ones carry a total.')
#ELSE
    #SET(%bgTColsHint,'Tick the columns you want to see. Space toggles the highlighted one.')
#ENDIF
  #ELSE
    #SET(%bgTSortAsc,'Ordenar &Ascendente')
    #SET(%bgTSortDesc,'Ordenar &Descendente')
    #SET(%bgTFilterOn,'&Filtrar por')
    #SET(%bgTFilterBy,'Filtrar por &valor...')
    #SET(%bgTClearThis,'Limpiar este f&iltro')
    #SET(%bgTClearAll,'Limpiar &todos los filtros')
    #SET(%bgTColumns,'&Columnas...')
    #SET(%bgTSchMenu,'&Esquemas...')
    #SET(%bgTSchTitle,'Esquemas de columnas')
    #SET(%bgTSchHint,'Guarde las columnas que está usando con un nombre, y recupérelas después.')
    #SET(%bgTSchName,'Esquema')
    #SET(%bgTSchAs,'&Nombre:')
    #SET(%bgTSchSave,'&Guardar')
    #SET(%bgTSchLoad,'&Recuperar')
    #SET(%bgTSchDel,'&Borrar')
    #SET(%bgTSchClose,'&Cerrar')
    #SET(%bgTSchNoName,'Escriba primero un nombre para el esquema.')
    #SET(%bgTSchNone,'Elija primero un esquema de la lista.')
    #SET(%bgTSchFull,'No entra otro esquema. Borre alguno que no use.')
    #SET(%bgTSchEmpty,'Ese esquema no tiene nada guardado.')
    #SET(%bgTAutoFit,'A&ncho automático')
    #SET(%bgTReset,'&Restablecer disposición')
    #SET(%bgTNoObject,'Este grid no pudo deducir por cuál objeto browse filtrar, porque su queue no está nombrado como los nombra ABC. Escriba el nombre del objeto - BRW1, normalmente - en Browse object, en los prompts de BrowseGrid.')
    #SET(%bgTNoFile,'Nombre el archivo que lee este browse en los prompts del grid, y el menú de la columna podrá ofrecer los valores que contiene.')
    #SET(%bgTOneCol,'Un grid tiene que mostrar al menos una columna.')
    #SET(%bgTColsTitle,'Columnas')
    #SET(%bgTValues,'Valores')
    #SET(%bgTValuesIn,'Valores en')
    #SET(%bgTKeep,'Usar')
    #SET(%bgTValue,'Valor')
    #SET(%bgTShowHdr,'Ver')
    #SET(%bgTColumnHdr,'Columna')
    #SET(%bgTAll,'&Todos')
    #SET(%bgTNone,'N&inguno')
    #SET(%bgTOk,'&Aceptar')
    #SET(%bgTCancel,'&Cancelar')
    #SET(%bgTShowBtn,'&Mostrar')
    #SET(%bgTHideBtn,'&Ocultar')
    #SET(%bgTTotHdr,'Total')
    #SET(%bgTTotBtn,'Totali&zar')
    #SET(%bgTNoField,'Esta columna no nombra un campo del queue del browse, asi que no hay valores que buscar.')
    #SET(%bgTNoValues,'No se encontraron valores en esa columna.')
    #SET(%bgTTooMany,'Se eligieron demasiados valores para un solo filtro. Elegí menos, o usá Filtrar por este valor.')
    #SET(%bgTValsHint,'Marque los valores que quiere ver. La barra espaciadora alterna el resaltado.')
    #SET(%bgTFindMenu,'&Buscar texto...')
    #SET(%bgTFindTitle,'Buscar texto')
    #SET(%bgTFindHint,'Escriba el texto a buscar. No distingue mayúsculas de minúsculas.')
    #SET(%bgTFindLbl,'&Texto:')
    #SET(%bgTFindAll,'En to&das las columnas')
    #SET(%bgTFindNone,'No hay ninguna columna en la que buscar ese texto.')
#IF(%bgTotals)
    #SET(%bgTColsHint,'Marque las columnas que quiere ver, y cuáles llevan total.')
#ELSE
    #SET(%bgTColsHint,'Marque las columnas que quiere ver. La barra espaciadora alterna el resaltado.')
#ENDIF
  #ENDIF
#ENDAT
#!
#!-----------------------------------------------------------------------------
#AT(%DataSection),WHERE(%bgDisable=0 AND %bgList)
BG:Resized:%bgObject EQUATE(EVENT:User + 240 + %ActiveTemplateInstance)
BG:Popup:%bgObject   EQUATE(EVENT:User + 200 + %ActiveTemplateInstance)
BG:Cover:%bgObject   EQUATE(EVENT:User + 160 + %ActiveTemplateInstance)
BG:Refill:%bgObject  EQUATE(EVENT:User + 120 + %ActiveTemplateInstance)
BG:Dbl:%bgObject     EQUATE(EVENT:User + 80 + %ActiveTemplateInstance)
BG:ClrHit:%bgObject  EQUATE(EVENT:User + 40 + %ActiveTemplateInstance)
%bgObject:G          LONG                                    ! the grid, 0 = not running
%bgObject:Rgn        SIGNED                                  ! the region it is drawn on
%bgObject:Cols       LONG                                    ! how many columns came over
%bgObject:Fld        LONG,DIM(BG:MaxCols)                     ! queue field behind each column
%bgObject:CFld       LONG,DIM(BG:MaxCols)                     ! and where its colours start, 0 none
%bgObject:Num        LONG,DIM(BG:MaxCols)                     ! does its picture say it is a number?
%bgObject:IFld       LONG,DIM(BG:MaxCols)                     ! and its icon id, 0 = not a tick box
%bgObject:IconOn     LONG                                     ! the icon that means ticked
%bgObject:IconChk    LONG                                     ! is the icon list a tick box pair?
%bgObject:W0         LONG,DIM(BG:MaxCols)                     ! the widths as the formatter drew them
#IF(%bgTotals)
%bgObject:Sum        LONG,DIM(BG:MaxCols)                     ! does this column add up?
%bgObject:SumNm      CSTRING(65),DIM(BG:MaxCols)              ! and the field name to read it by
%bgObject:Acc        DECIMAL(31,4),DIM(BG:MaxCols)            ! the running totals
%bgObject:SumN       LONG                                     ! records added, for the cap
%bgObject:SumDue     BYTE                                     ! do the totals need doing?
#ENDIF
#IF(%bgTipsU)
%bgObject:Meas       SIGNED                                   ! a hidden STRING, used as a ruler
%bgObject:TipRow     LONG                                     ! what the pointer was last over,
%bgObject:TipCol     LONG                                     ! so it is measured once, not per pixel
%bgObject:TipTxt     CSTRING(129)
#ENDIF
#IF(%bgDiag)
%bgObject:MapWas     CSTRING(201)                             ! the last map written to the log
#ENDIF
%bgObject:Pic        STRING(32),DIM(BG:MaxCols)               ! and its picture, if it has one
%bgObject:SchName    CSTRING(33)                              ! el esquema a guardar o recuperar
%bgObject:SchDid     LONG                                     ! 1 = habia algo guardado
%bgObject:Face       CSTRING(33)
%bgObject:Pt         LONG                                     ! tamano ya resuelto, en puntos
%bgObject:Cell       CSTRING(129)                              ! as long as the C side G_TEXT
%bgObject:Sel        LONG
%bgObject:Clipped    BYTE                                    ! has the LIST been made invisible?
%bgObject:Barred     BYTE                                    ! does it have scrollbars yet?
%bgObject:ScrollX    LONG                                    ! how far sideways the columns are
%bgObject:Col        LONG,DIM(BG:MaxCols)                     ! LIST column behind each grid one
%bgObject:RzCol      LONG                                    ! column being dragged, 0 = none
%bgObject:RzX        LONG                                    ! where the drag started
%bgObject:RzW        LONG                                    ! and how wide the column was then
%bgObject:RzCur      BYTE                                    ! is the sizing cursor showing?
%bgObject:VDrag      BYTE                                    ! is the thumb being dragged?
%bgObject:VGrab      LONG                                    ! and where it was taken hold of
%bgObject:HDrag      BYTE                                    ! the sideways thumb, being dragged
%bgObject:HGrab      LONG
%bgObject:SortCol    LONG                                    ! heading just clicked, for BG:Sort
%bgObject:RzGrp      BYTE                                    ! is a GROUP being dragged, not a column?
%bgObject:GrpCol     LONG,DIM(BG:MaxCols)                     ! a LIST column in each group
%bgObject:Filters    LONG                                    ! how many columns are filtered
%bgObject:Hidden     LONG                                    ! LIST columns sitting at zero width
%bgObject:ColFilt    CSTRING(1025),DIM(BG:MaxCols)             ! one filter per column, ANDed together
%bgObject:Fills      LONG                                    ! how many times it has been refilled
%bgObject:SortOn     LONG                                    ! LIST column the mark is on, 0 none
%bgObject:SortDir    LONG                                    ! 1 up, -1 down
%bgObject:RzArmed    BYTE                                    ! on an edge, but has it MOVED yet?
%bgObject:RzHide     BYTE                                    ! dragged past nothing: hide it
%bgObject:Lines      LONG                                    ! lines per record in the LIST's format
#IF(%bgReread)
%bgObject:ReSt       BYTE                                    ! the columns are still to be re-read
#ENDIF
#IF(%bgDiag)
!  WHAT A FILL COSTS. CLOCK() counts in hundredths of a second, and a fill is
!  not a hundredth of anything, so it would read zero for ever and prove
!  nothing. QueryPerformanceCounter counts in ticks. Only the low half is
!  kept: at the usual 10 MHz that wraps every seven minutes, and a fill that
!  straddles the wrap comes out negative and is thrown away rather than
!  reported as a lie.
%bgObject:Dpi        LONG                                     ! puntos por pulgada de la pantalla
%bgObject:LgQ        LONG                                     ! ultimo q registrado, para no repetir
%bgObject:LgR        LONG                                     ! ultimo rows registrado
%bgObject:LgL        LONG                                     ! ultimo alto de linea registrado
%bgObject:T1         LONG,DIM(2)                              ! before the fill
%bgObject:T2         LONG,DIM(2)                              ! and after it
%bgObject:Freq       LONG,DIM(2)                              ! ticks per second, asked once
%bgObject:Us         LONG                                     ! what the last fill took
%bgObject:UsTot      REAL                                     ! and all of them together
%bgObject:UsN        LONG                                     ! how many were timed
#ENDIF
#ENDAT
#!
#AT(%WindowManagerMethodCodeSection,'Init','(),BYTE'),PRIORITY(8800),WHERE(%bgDisable=0 AND %bgList)
  IF ReturnValue = Level:Benign
    DO BG:Setup:%bgObject
  END
#ENDAT
#!
#!  WHERE THE REFILL HANGS OFF. Not TakeEvent: that method returns the moment
#!  PARENT.TakeEvent() comes back, so code embedded after it is unreachable -
#!  it generates, it compiles, and it never runs. ABC calls Reset when the
#!  browse has refilled itself, and TakeNewSelection when the highlight moves,
#!  which between them cover scrolling, locating, filtering and editing.
#AT(%WindowManagerMethodCodeSection,'Reset','(BYTE Force=0)'),PRIORITY(8000),WHERE(%bgDisable=0 AND %bgList)
  IF %bgObject:G
    DO BG:Fill:%bgObject
  END
#ENDAT
#!
#AT(%WindowManagerMethodCodeSection,'TakeNewSelection','(),BYTE'),PRIORITY(8000),WHERE(%bgDisable=0 AND %bgList)
  IF %bgObject:G
    DO BG:Fill:%bgObject
  END
#ENDAT
#!
#AT(%WindowManagerMethodCodeSection,'TakeWindowEvent','(),BYTE'),PRIORITY(2000),WHERE(%bgDisable=0 AND %bgList)
  CASE EVENT()
  OF EVENT:OpenWindow
!  The window is up and everything has been given its real place, which is the
!  first moment the LIST can be measured for where it truly is.
    POST(BG:Resized:%bgObject)
  OF EVENT:Sized
!  Do NOT move the region here. The window resizer is working on this same
!  event, and on this window it runs after us - so the LIST has not been given
!  its new size yet, and anything measured from it now is the old one. Posting
!  puts the move at the back of the queue, by which time the resizer has
!  finished and the LIST is the size it is going to be.
    POST(BG:Resized:%bgObject)
#IF(%bgBarsU OR %bgWheelU)
  OF BG:Scrolled
    IF %bgObject:G AND %bgObject:Barred
      DO BG:Scroll:%bgObject
    END
#ENDIF
#IF(%bgPopupU)
  OF BG:Popup:%bgObject
!  By now the SELECT has taken effect and the LIST really has the focus, so the
!  keystroke reaches it. Done in the same breath as the SELECT it would still
!  be sitting on the region.
!
!  Taking the focus is also what makes the LIST draw its own selected row, and
!  it draws it straight through the grid - at its own line height and its own
!  column widths, which is what makes it look like the row appears twice. So
!  the grid is put back over it BEFORE the menu opens, and again afterwards in
!  case the LIST repaints while the menu is up. PaintNow, not Repaint: an
!  invalidated window would not be redrawn until the menu closed.
    DO BG:Cover:%bgObject
    PRESSKEY(AppsKey)
    POST(BG:Cover:%bgObject)
  OF BG:Cover:%bgObject
    DO BG:Cover:%bgObject
#ENDIF
#IF(%bgClickCols)
  OF BG:ClrHit:%bgObject
    %bgList{PROPLIST:MouseDownRow} = 0                    ! un solo uso por click
#ENDIF
#IF(%bgDoubleU)
  OF BG:Dbl:%bgObject
!  Same trick as the popup, and for the same reason: by now the SELECT has
!  taken effect and the LIST really has the focus, so the keystroke reaches
!  it. ABC alerts MouseLeft2 on the list and treats it as Change, so whatever
!  the browse was set up to do on a double click is what happens - update
!  form, popup formatter and all.
    DO BG:Cover:%bgObject
    PRESSKEY(MouseLeft2)
    POST(BG:Cover:%bgObject)
#ENDIF
  OF BG:Refill:%bgObject
!  Posted LAST, so it is handled after everything the browse posted for itself.
!  Refilling the grid depends on ABC calling Reset or TakeNewSelection once it
!  has re-read, and after a filter that is not something to rely on - if
!  neither fires, or fires before the queue is rebuilt, the grid keeps showing
!  what it had. This does not care which: by the time it runs, the queue is
!  whatever the browse ended up with.
    IF %bgObject:G
      DO BG:Fill:%bgObject
      d2g_PaintNow(%bgObject:G)
    END
  OF BG:Resized:%bgObject
    IF %bgObject:G
#IF(%bgReread)
!  ONCE, and only the first time round. The grid read the LIST in Init at
!  priority 8800, and an application that sets a column up afterwards - a
!  picture out of a global, a heading built at run time - was writing where
!  the grid had already stopped looking. Reading again now, with the window
!  up and everything else finished, is what makes the grid show what the LIST
!  really says rather than what it said early on.
!  Not on every resize: this event also arrives whenever the window is
!  dragged, and re-reading the columns there would throw away a width the
!  user had just set by hand.
      IF %bgObject:ReSt
        %bgObject:ReSt = 0
        DO BG:Columns:%bgObject
        DO BG:Rows:%bgObject
#IF(%bgTotals)
        %bgObject:SumDue = 1                                  ! las columnas pueden ser otras
#ENDIF
      END
#ENDIF
      DO BG:Place:%bgObject                                   ! follow the LIST to its new size
      d2g_Resize(%bgObject:G)                                 ! and the render target with it
      DO BG:Items:%bgObject                                   ! and the browse loads to suit
      DO BG:Fill:%bgObject                                    ! a taller browse holds more rows
    END
  END
#ENDAT
#!
#AT(%WindowManagerMethodCodeSection,'TakeFieldEvent','(),BYTE'),PRIORITY(2000),WHERE(%bgDisable=0 AND %bgList)
  IF FIELD() = %bgObject:Rgn AND %bgObject:G
    CASE EVENT()
    OF EVENT:MouseDown
      DO BG:Hit:%bgObject
#IF(%bgPopupU)
    OF EVENT:AlertKey
      IF KEYCODE() = MouseRightUp
        DO BG:Right:%bgObject
      END
#ENDIF
#IF(%bgDoubleU AND ~%bgPopupU)
    OF EVENT:AlertKey
#ENDIF
#IF(%bgDoubleU)
      IF KEYCODE() = MouseLeft2
        DO BG:Double:%bgObject
      END
#ENDIF
#IF(%bgBarStyleU = 'Overlay')
    OF EVENT:MouseIn
      d2g_BarsShow(%bgObject:G,1)
    OF EVENT:MouseOut
      d2g_BarsShow(%bgObject:G,0)
#ENDIF
#IF(%bgSizeable OR %bgTipsU)
    OF EVENT:MouseMove
#ENDIF
#IF(%bgSizeable)
      DO BG:Sizing:%bgObject
#ENDIF
#IF(%bgTipsU)
      DO BG:Tip:%bgObject
#ENDIF
#IF(%bgSizeable)
    OF EVENT:MouseUp
      DO BG:SizeEnd:%bgObject
#ENDIF
    END
  END
#ENDAT
#!
#AT(%WindowManagerMethodCodeSection,'Kill','(),BYTE'),PRIORITY(2000),WHERE(%bgDisable=0 AND %bgList)
#IF(%bgRemember)
  DO BG:Remember:%bgObject                                    ! before anything is taken down
#ENDIF
  DO BG:Reveal:%bgObject
  IF %bgObject:Barred
    BG_DropBars(%bgObject:Rgn{PROP:Handle})
    %bgObject:Barred = 0
  END
  IF %bgObject:G
    d2g_Detach(%bgObject:G)
    %bgObject:G = 0
  END
#ENDAT
#!
#AT(%ProcedureRoutines),WHERE(%bgDisable=0 AND %bgList)
#IF(~%bgQueueUsed)
  #ERROR('BrowseGrid on ' & %bgList & ' in ' & %Procedure & ': cannot tell which QUEUE that LIST is FROM(). Name it on the BrowseGrid prompts.')
#ENDIF
BG:Setup:%bgObject ROUTINE
!  Put a region exactly where the LIST is, hide the LIST, and hand the region
!  to the grid. The LIST stays in the window doing its job - it is simply not
!  the thing you look at any more, which is why the browse carries on working.
  DATA
c  LONG,AUTO
ex LONG,AUTO
dc LONG,AUTO
x  SIGNED,AUTO
y  SIGNED,AUTO
w  SIGNED,AUTO
h  SIGNED,AUTO
  CODE
  IF ~d2g_Available() THEN EXIT.                              ! no Direct2D: leave the LIST alone
  IF ~%bgObject:Rgn
    %bgObject:Rgn = CREATE(0,CREATE:Region,%bgList{PROP:Parent})
    %bgObject:Rgn{PROP:IMM} = 1                               ! or no mouse events arrive
  END
!  LA FUENTE, ANTES QUE LA REGLA. La regla se crea con esta tipografia y solo
!  una vez: creada antes de que este puesta se quedaba con el nombre vacio, o
!  sea midiendo con la fuente por defecto de la ventana en vez de con la del
!  grid. El tooltip seguia apareciendo, pero con el umbral corrido.
#IF(%bgDiag)
!  UNA VEZ, y devolviendo EL MISMO DC que se pidio. Pedir uno por llenado y no
!  soltarlo pierde un handle GDI por vuelta, y son finitos.
  IF ~%bgObject:Dpi
    dc = bgApi_GetDC(0)
    %bgObject:Dpi = bgApi_GetDeviceCaps(dc,90)                ! LOGPIXELSY
    bgApi_ReleaseDC(0,dc)
  END
#ENDIF
  %bgObject:Face = %bgFontUsed
  %bgObject:Pt   = %bgSizeUsed
#IF(%bgSDAObj)
!  LO QUE SDAspecto ESTA APLICANDO AHORA, que no es lo que dicen sus prompts:
!  entre medio pasa el INI, y puede pasar codigo del programa. Preguntarle al
!  objeto es lo unico que da el mismo numero que ve el resto de la ventana.
!
!  FuenteAControles se respeta porque el grid ES un control: si SDAspecto tiene
!  dicho que no toca los controles, el LIST se queda con su tipografia de
!  diseno y el grid tiene que quedarse con la suya, o seria el unico distinto.
!
!  Vacio y -1 quieren decir 'no toques esto' en SDAspecto. Para el grid -1 no
!  es un tamano, asi que ahi queda el de la solapa en vez de pedirle a
!  DirectWrite una fuente de menos un punto.
  IF %bgSDAObj.FuenteActiva = 1 AND %bgSDAObj.FuenteAControles = 1
    IF CLIP(%bgSDAObj.FuenteNombre)
      %bgObject:Face = CLIP(%bgSDAObj.FuenteNombre)
    END
    IF %bgSDAObj.FuenteTamano > 0
      %bgObject:Pt = %bgSDAObj.FuenteTamano
    END
  END
#ENDIF
#IF(%bgTipsU OR %bgAutoFitU)
!  A RULER. To know whether a value fits its column it has to be measured, and
!  measuring text is what Clarion does when it works out how wide a STRING
!  needs to be: give one the font and the text, and PROP:Width is the answer.
!  ABC measures its own auto-sized columns exactly this way (brwext.clw:3468),
!  which beats declaring IDWriteTextLayout by hand to ask DirectWrite the same
!  question. It is never shown - it exists to be asked.
  IF ~%bgObject:Meas
    %bgObject:Meas = CREATE(0,CREATE:String,%bgList{PROP:Parent})
    %bgObject:Meas{PROP:FontName} = %bgObject:Face
    %bgObject:Meas{PROP:FontSize} = %bgObject:Pt
    HIDE(%bgObject:Meas)
  END
#ENDIF
  DO BG:Place:%bgObject
  UNHIDE(%bgObject:Rgn)
#IF(%bgWeightU <> '0')
!  ANTES del attach, que es donde se crean las tipografias.
  d2g_Weight(0,%bgWeightU)
#ENDIF
  %bgObject:G = d2g_Attach(%bgObject:Rgn{PROP:Handle},%bgObject:Face,%bgObject:Pt)
#IF(%bgDiag)
!  CON QUE TIPOGRAFIA QUEDO CADA UNO. El motor arma su superficie clavada en
!  96 DPI, asi que convierte los puntos a pixeles como si la pantalla no
!  estuviera escalada, mientras que Windows dibuja el LIST a los DPI reales.
!  Con dpi=96 los dos numeros significan lo mismo y si se ven distintos es
!  porque son distintos; con dpi mayor, el grid queda mas chico aunque los
!  dos digan el mismo tamano.
  BG_Log('%Procedure %bgObject tipografia: lista=' &                         |
         CLIP(%bgList{PROP:FontName}) & '/' & %bgList{PROP:FontSize} &       |
         ' ventana=' & CLIP(0{PROP:FontName}) & '/' & 0{PROP:FontSize} &     |
         ' grid=' & CLIP(%bgObject:Face) & '/' & d2g_FontPt(%bgObject:G) &   |
         ' dpi=' & %bgObject:Dpi)
#ENDIF
  IF ~%bgObject:G
    HIDE(%bgObject:Rgn)                                       ! could not start: leave the LIST alone
    EXIT
  END
!  THE WIDTHS AS DESIGNED, taken before anything remembered is written over
!  them. Once a remembered width has been put on the LIST the original is
!  gone, and Reset layout had nothing to go back TO: it cleared the INI and
!  left the browse looking exactly as wrong as it did before, which is not
!  what a way out is for.
  LOOP c = 1 TO BG:MaxCols
    ex = %bgList{PROPLIST:Exists,c}
    IF ~ex THEN BREAK.
    %bgObject:W0[c] = %bgList{PROPLIST:Width,c}
  END
#IF(%bgRemember)
  DO BG:Recall:%bgObject                                      ! widths, before they are read
#ENDIF
  DO BG:Columns:%bgObject
#IF(%bgRemember)
  DO BG:RecallF:%bgObject                                     ! and filters, once columns are known
#ENDIF
#IF(%bgTotals AND %bgRemember)
  DO BG:RecallT:%bgObject                                     ! y que columnas totaliza
#ENDIF
  DO BG:Conceal:%bgObject                                     ! only now the grid can be seen
!  The LIST is neither hidden nor moved: it stays exactly where it is, filling
!  its queue, counting its visible rows and holding the selection, and the
!  region sits on top of it. WS_CLIPSIBLINGS is what makes that stick - without
!  it the LIST paints over the grid whenever it redraws.
#IF(%bgWrapU)
!  Before BG:Rows, which asks the engine how tall a row has to be - and with
!  wrapping on, that answer is several lines.
  d2g_Wrap(%bgObject:G,1,%bgWrapLinesU)
#ENDIF
  DO BG:Rows:%bgObject
#IF(%bgTotals)
  d2g_Footer(%bgObject:G,1)                                   ! after BG:Rows: it is a row tall
#ENDIF
  DO BG:Items:%bgObject                                       ! load what there is room to draw
#IF(%bgHdrHU > 0)
  d2g_HeaderHeight(%bgObject:G,%bgHdrHU)
#ENDIF
#IF(%bgBarsU OR %bgWheelU)
#IF(%bgBarStyleU = 'Windows')
  IF BG_HookBars(%bgObject:Rgn{PROP:Handle},0)                ! the roller comes through here too
#ELSE
  IF BG_HookBars(%bgObject:Rgn{PROP:Handle},1)                ! drawn bars: hooked only for the roller
#ENDIF
    %bgObject:Barred = 1
  END
#ENDIF
#IF(%bgPopupU)
!  The region is on top, so it - not the LIST - is what a right-click lands on.
!  Alerting it here is what lets that click be handed back to the browse.
  %bgObject:Rgn{PROP:Alrt,250} = MouseRightUp
#ENDIF
#IF(%bgDoubleU)
  %bgObject:Rgn{PROP:Alrt,251} = MouseLeft2                   ! and the double click, likewise
#ENDIF
#IF(%bgGdiTextU)
!  Antes de dibujar nada. El modo vive en la superficie, y si esta se rehace -
!  un cambio de tamano la rehace - el motor lo vuelve a aplicar solo.
  d2g_TextMode(%bgObject:G,1)
#IF(%bgDiag)
!  SI LAS LLAMADAS ANDUVIERON. Un HRESULT negativo dice que DirectWrite rechazo
!  los parametros y no hay nada que mirar en pantalla; -999 dice que ni se
!  intento, que es otro problema y otro arreglo.
  BG_Log('%Procedure %bgObject texto: hrDef=' & d2g_TextInfo(%bgObject:G,0) &  |
         ' gamma=' & d2g_TextInfo(%bgObject:G,1) &                             |
         ' contraste=' & d2g_TextInfo(%bgObject:G,2) &                         |
         ' nivel=' & d2g_TextInfo(%bgObject:G,3) &                             |
         ' geom=' & d2g_TextInfo(%bgObject:G,4) &                              |
         ' hrPar=' & d2g_TextInfo(%bgObject:G,5))
#ENDIF
#ENDIF
#IF(%bgBarStyleU = 'Slim')
  d2g_BarStyle(%bgObject:G,1)
#ELSIF(%bgBarStyleU = 'Overlay')
  d2g_BarStyle(%bgObject:G,2)
#ELSE
  d2g_BarStyle(%bgObject:G,0)
#ENDIF
#IF(%bgFilterBtnU)
  d2g_FilterBtns(%bgObject:G,1)
  d2g_FilterOn(%bgObject:G,-1,0)                              ! nothing is filtered to begin with
#ENDIF
  d2g_Frozen(%bgObject:G,%bgFrozen)
  d2g_Colours(%bgObject:G,BG_Rgb(%bgCBackUsed),BG_Rgb(%bgCBandUsed),          |
              BG_Rgb(%bgCGridUsed),BG_Rgb(%bgCTextUsed),                       |
              BG_Rgb(%bgCHdrBackUsed),BG_Rgb(%bgCHdrTextUsed),                 |
              BG_Rgb(%bgCSelBackUsed),BG_Rgb(%bgCSelTextUsed))
  DO BG:Fill:%bgObject
#IF(%bgTotals)
  %bgObject:SumDue = 1                                        ! BG:Fill lo hara cuando haya vista
#ENDIF
#IF(%bgReread)
  %bgObject:ReSt = 1                                          ! y las columnas, una vez arriba
#ENDIF
!  ...and then place it again once the window has finished opening. At Init the
!  LIST is still where the DESIGNER put it: the window resizer has not run, and
!  on a window that opens maximised or restores to a remembered size it is about
!  to move. Placing the region now and leaving it there is what put the grid
!  over the buttons until the window was resized by hand. Posting means the
!  second placement happens after everything else has settled.
  POST(BG:Resized:%bgObject)

BG:Place:%bgObject ROUTINE
!  Sit the region exactly on the LIST and keep it on top. The LIST is not moved
!  and not hidden: it is left where the resizer wants it, doing everything it
!  did before, and WS_CLIPSIBLINGS stops it painting into the region's
!  rectangle. Moving it instead fought the resizer, which works out every
!  control's place from the design layout and put it back over the grid.
  DATA
x  SIGNED,AUTO
y  SIGNED,AUTO
w  SIGNED,AUTO
h  SIGNED,AUTO
sty LONG,AUTO
  CODE
  IF ~%bgObject:Rgn THEN EXIT.
  GETPOSITION(%bgList,x,y,w,h)
  SETPOSITION(%bgObject:Rgn,x,y,w,h)
  IF %bgObject:G
    DO BG:Conceal:%bgObject                                   ! a resize can bring it back
  END
!  and raise the region above it, every time, because a resize can restack them
  bgApi_SetWindowPos(%bgObject:Rgn{PROP:Handle},BG:HwndTop,0,0,0,0,             |
                     BOR(BG:NoMove,BG:NoSize))

BG:Columns:%bgObject ROUTINE
!  Read the columns off the LIST as they stand. Every PROPLIST read goes
!  through a LONG first: a property comes back as a STRING, and the STRING '0'
!  is logically TRUE, so a hidden column would otherwise look visible.
  DATA
c     LONG,AUTO
n     LONG,AUTO
ex    LONG,AUTO
fld   LONG,AUTO
wid   LONG,AUTO
algn  LONG,AUTO
p     LONG,AUTO
grp     LONG,AUTO
lines   LONG,AUTO
glines  LONG,AUTO
lastgrp LONG,AUTO
pass    LONG,AUTO
head  CSTRING(129)
ghead CSTRING(129)
  CODE
!  Two passes, not two calls. A ROUTINE that does DO on itself is not a
!  recursive call in Clarion - a routine holds one return address, so calling it
!  from inside itself loses the way back and takes the program down with it.
!  That is what the rescue below did on the first window it was needed on.
!  IS THE ICON LIST A TICK BOX? Clarion draws a tick box as an ICON column -
!  |I in the format, the icon id in the queue right behind the value - and the
!  icons themselves are its own ~BoxOff.ico and ~BoxOn.ico. Those two shapes
!  are a square and a tick, so the grid draws them rather than learning to
!  read .ico files for them. Which id means ticked is decided HERE, where the
!  names can be read, so nothing downstream has to guess.
!
!  A list of two entries that is not named like a tick box is taken as one
!  anyway - a pair is what a tick box is. Anything else is left alone: a
!  column that draws nothing is a great deal easier to notice, and to report,
!  than a tick standing in for some other picture.
  %bgObject:IconOn  = 0
  %bgObject:IconChk = 0
  n = 0
  LOOP c = 1 TO 16
    head = LOWER(CLIP(%bgList{PROP:IconList,c}))
    IF ~head THEN BREAK.
    n += 1
    IF INSTRING('boxoff',head,1,1) OR INSTRING('checkoff',head,1,1)          |
       OR INSTRING('unchecked',head,1,1) OR INSTRING('untick',head,1,1)
      %bgObject:IconChk = 1
    ELSIF INSTRING('boxon',head,1,1) OR INSTRING('checkon',head,1,1)         |
       OR INSTRING('checked',head,1,1) OR INSTRING('tick',head,1,1)
      %bgObject:IconChk = 1
      %bgObject:IconOn  = c
    END
  END
  IF n = 2 AND ~%bgObject:IconOn                              ! a pair, named otherwise
    %bgObject:IconChk = 1
    %bgObject:IconOn  = 2
  END
  IF ~%bgObject:IconOn THEN %bgObject:IconChk = 0.

  LOOP pass = 1 TO 2
  n = 0
  lines = 1
  glines = 1
  lastgrp = -1
  LOOP c = 1 TO 512
    ex = %bgList{PROPLIST:Exists,c}
    IF ~ex THEN BREAK.
    fld = %bgList{PROPLIST:FieldNo,c}
    IF ~fld THEN CYCLE.                                       ! a decoration, not a data column
    wid = %bgList{PROPLIST:Width,c}
    IF wid < 1 THEN CYCLE.                                    ! hidden
    IF n >= BG:MaxCols THEN BREAK.
    algn = 0
    p = %bgList{PROPLIST:Right,c}
    IF p THEN algn = 1.
    p = %bgList{PROPLIST:Decimal,c}
    IF p THEN algn = 1.
    p = %bgList{PROPLIST:Center,c}
    IF p THEN algn = 2.
!  A column inside a GROUP usually carries no heading of its own - the group's
!  heading stands over the whole set of them. Adding PROPLIST:Group to any of
!  these properties reads the GROUP's version of it, which is where the words
!  in the formatter's top row actually live. Flattened, each field becomes a
!  column of its own, so it needs a heading of its own: its own if it has one,
!  the group's if it has not.
    head = CLIP(%bgList{PROPLIST:Header,c})
    grp  = %bgList{PROPLIST:GroupNo,c}
    IF grp
      ghead = CLIP(%bgList{PROPLIST:Header + PROPLIST:Group,c})
      IF ~head
        head = ghead
      ELSIF ghead AND UPPER(ghead) <> UPPER(head)
        head = CLIP(ghead) & ' ' & CLIP(head)                 ! "Address City", not just "City"
      END
!  LastOnLine is where the format wraps onto the next line of the record. A
!  record is as tall as its TALLEST group, not as the sum of every break in
!  every group - counting them all made a three-line record report five, so the
!  LIST was given a line height a third too small and the rows came out stretched
!  with the text floating in the middle of them.
      IF grp <> lastgrp
        lastgrp = grp
        glines  = 1                                           ! a new group starts on line one
      END
      IF %bgList{PROPLIST:LastOnLine,c}
        glines += 1
        IF glines > lines THEN lines = glines.
      END
    END
    LOOP p = 1 TO LEN(head)                                   ! a bar wraps a heading on screen
      IF head[p] = '|' THEN head[p] = ' '.
    END
    head = CLIP(LEFT(head))
    %bgObject:Fld[n + 1] = fld
!  WHERE THE COLOURS ARE. A browse with conditional colours does not need
!  anything drawn differently here - ABC has ALREADY worked them out and put
!  them in the queue, right behind the field they belong to. So they are read
!  the same way everything else is: the LIST says whether the column has any,
!  and the queue holds the answers. The offsets are ABC's own, out of
!  brwext.clw:3473 - the style field sits at FieldNo + 1, an icon takes one
!  place ahead of it, and the four colours take the next four. Through a LONG,
!  like every PROPLIST read here: a property comes back as a STRING, and the
!  STRING '0' is logically TRUE.
    %bgObject:IFld[n + 1] = 0
    p = %bgList{PROPLIST:Icon,c}
    IF ~p THEN p = %bgList{PROPLIST:IconTrn,c}.                ! J, the transparent kind
    IF p AND %bgObject:IconChk
      %bgObject:IFld[n + 1] = fld + 1                          ! the id sits behind the value
    END
    %bgObject:CFld[n + 1] = 0
    p = %bgList{PROPLIST:Color,c}
    IF p
      %bgObject:CFld[n + 1] = fld + 1
      p = %bgList{PROPLIST:Icon,c}
      IF p THEN %bgObject:CFld[n + 1] += 1.
    END
    %bgObject:Col[n + 1] = c                                  ! so a resize can be written back
    %bgObject:Pic[n + 1] = CLIP(%bgList{PROPLIST:Picture,c})
!  QUE COLUMNA ES UN NUMERO. Lo dice el picture: @n y @e son numeros, @s y @d
!  no. Se decide una sola vez aca porque lo preguntan dos cosas - los totales,
!  para saber que sumar, y la busqueda de texto, para saber si comparar por
!  igualdad en vez de buscar dentro. Dos copias de la misma regla es una
!  copia de mas.
    %bgObject:Num[n + 1] = 0
    IF %bgObject:Pic[n + 1]
      IF UPPER(SUB(CLIP(%bgObject:Pic[n + 1]),2,1)) = 'N'                     |
         OR UPPER(SUB(CLIP(%bgObject:Pic[n + 1]),2,1)) = 'E'
        %bgObject:Num[n + 1] = 1
      END
    END
#IF(%bgTotals)
!  WHAT ADDS UP. The picture says it: @n and @e are numbers, @s and @d are
!  not. A tick box is excluded whatever its picture claims - the one under
!  the tick here is @n3, and a column of ones and zeros adds up to nothing
!  anyone wanted to know.
!  This will also total a column of invoice numbers, because an invoice
!  number is a number and nothing here can tell otherwise. Untick the totals
!  or change that column<39>s picture.
    %bgObject:Sum[n + 1] = 0
    IF ~%bgObject:IFld[n + 1] AND %bgObject:Num[n + 1]
      %bgObject:Sum[n + 1] = 1
!  The name once, here, and not once per record per column inside the walk:
!  WHO() is asking the queue about itself, and the answer does not change
!  between one record and the next.
      %bgObject:SumNm[n + 1] = CLIP(WHO(%bgQueueUsed,fld))
      IF ~%bgObject:SumNm[n + 1] THEN %bgObject:Sum[n + 1] = 0.
    END
#ENDIF
    d2g_Column(%bgObject:G,n,wid * 2,algn,head)               ! LIST widths are dialog units
!  And the colours the FORMATTER put on this column, which are not the same
!  thing as the conditional ones: those come out of the queue and change row
!  by row, these are set once in the window and hold for the whole column.
!  Read once per column rather than once per cell, which is why they cost
!  nothing. -1 is Clarion<39>s COLOR:None and has to stay -1.
    d2g_CheckCol(%bgObject:G,n,CHOOSE(%bgObject:IFld[n + 1] > 0,1,0))
    d2g_ColumnColour(%bgObject:G,n,                                            |
                     BG_Colr(%bgList{PROPLIST:TextColor,c}),                    |
                     BG_Colr(%bgList{PROPLIST:BackColor,c}),                    |
                     BG_Colr(%bgList{PROPLIST:TextSelected,c}),                 |
                     BG_Colr(%bgList{PROPLIST:BackSelected,c}))
    n += 1
  END
!  NOTHING VISIBLE. Every column came back zero-width, which means something hid
!  them all - the column chooser could, until it learned not to. An empty grid is
!  unusable and, worse, leaves nothing to click on to undo it, so the widths are
!  put back from what they were before they went and the loop goes round once
!  more. A grid can always be got back to.
  IF ~n AND pass = 1
    LOOP c = 1 TO 512
      ex = %bgList{PROPLIST:Exists,c}
      IF ~ex THEN BREAK.
      fld = %bgList{PROPLIST:FieldNo,c}
      IF ~fld THEN CYCLE.
      head = CLIP(INIMgr.TryFetch('BrowseGrid:%Procedure:%bgObject','h' & c))
      %bgList{PROPLIST:Width,c} = CHOOSE(head <> '' AND head <> '0', head, 40)
      INIMgr.Update('BrowseGrid:%Procedure:%bgObject','w' & c,'')
    END
    CYCLE                                                     ! read them again, once
  END
  BREAK
  END
  %bgObject:Cols = n
  %bgObject:Hidden = 0
  LOOP c = 1 TO 512                                           ! for the diagnostics line
    ex = %bgList{PROPLIST:Exists,c}
    IF ~ex THEN BREAK.
    fld = %bgList{PROPLIST:FieldNo,c}
    IF ~fld THEN CYCLE.
    IF %bgList{PROPLIST:Width,c} < 1 THEN %bgObject:Hidden += 1.
  END
  %bgObject:Lines = lines                                     ! 1 = an ordinary flat browse
  d2g_Columns(%bgObject:G,n)
#IF(%bgFlatten = 0)
  IF lines > 1
    DO BG:Groups:%bgObject                                    ! place them where the format does
  END
#ENDIF

BG:Groups:%bgObject ROUTINE
!  Lay the record out the way the List Box Formatter does: fields sit inside
!  groups, several to a line, and the group's heading spans the lot. Three
!  things say how:
!
!    PROPLIST:GroupNo     which group a column is in
!    PROPLIST:LastOnLine  where the record wraps onto its next line
!    PROPLIST:Group       ADDED to any other property, reads the GROUP's one -
!                         which is where the heading and the overall width live
!
!  A column with no group is a group of its own, one field on one line, which
!  is how an ordinary browse falls out of the same code.
#IF(%bgFlatten = 0)
  DATA
c    LONG,AUTO
n    LONG,AUTO
g    LONG,AUTO
ex   LONG,AUTO
fld  LONG,AUTO
wid  LONG,AUTO
algn LONG,AUTO
p    LONG,AUTO
grp  LONG,AUTO
prev LONG,AUTO
gx   LONG,AUTO
gw   LONG,AUTO
ln   LONG,AUTO
xo   LONG,AUTO
mx   LONG,AUTO
head CSTRING(129)
  CODE
  n    = 0
  g    = -1
  prev = -9999
  gx   = 0
  mx   = 1
  LOOP c = 1 TO 512
    ex = %bgList{PROPLIST:Exists,c}
    IF ~ex THEN BREAK.
    fld = %bgList{PROPLIST:FieldNo,c}
    IF ~fld THEN CYCLE.
    wid = %bgList{PROPLIST:Width,c}
    IF wid < 1 THEN CYCLE.
    IF n >= BG:MaxCols THEN BREAK.
    grp = %bgList{PROPLIST:GroupNo,c}
    IF grp <> prev OR ~grp                                    ! a new group starts here
      IF g >= 0 THEN gx += gw.
      g += 1
      prev = grp
      ln = 0
      xo = 0
      IF grp
        gw   = %bgList{PROPLIST:Width + PROPLIST:Group,c} * 2
        head = CLIP(%bgList{PROPLIST:Header + PROPLIST:Group,c})
      ELSE
        gw   = wid * 2                                        ! ungrouped: a group of one
        head = CLIP(%bgList{PROPLIST:Header,c})
      END
      LOOP p = 1 TO LEN(head)
        IF head[p] = '|' THEN head[p] = ' '.
      END
      head = CLIP(LEFT(head))
      d2g_Group(%bgObject:G,g,gx,gw,head)
      %bgObject:GrpCol[g + 1] = c                             ! for writing a resize back
    END
    algn = 0
    p = %bgList{PROPLIST:Right,c}
    IF p THEN algn = 1.
    p = %bgList{PROPLIST:Decimal,c}
    IF p THEN algn = 1.
    p = %bgList{PROPLIST:Center,c}
    IF p THEN algn = 2.
!  Its own heading, which in a grouped format is where most of the words are.
    head = CLIP(%bgList{PROPLIST:Header,c})
    LOOP p = 1 TO LEN(head)
      IF head[p] = '|' THEN head[p] = ' '.
    END
    head = CLIP(LEFT(head))
    d2g_ColumnAt(%bgObject:G,n,g,ln,gx + xo,wid * 2,algn,head)
    xo += wid * 2
    IF grp AND %bgList{PROPLIST:LastOnLine,c}                 ! the record wraps here
      ln += 1
      xo = 0
      IF ln + 1 > mx THEN mx = ln + 1.
    END
    n += 1
  END
  IF g >= 0
    d2g_Groups(%bgObject:G,g + 1)
    d2g_Lines(%bgObject:G,mx)
  END
#ELSE
  EXIT
#ENDIF

BG:Hit:%bgObject ROUTINE
!  A click picks a row. The browse still owns the selection: it is told which
!  record was chosen and left to do the rest, so locators, range limits and
!  anything hanging off EVENT:NewSelection behave exactly as they always did.
!  MOUSEY answers in WINDOW units and the grid measures in pixels, hence the
!  switch - a window unit is half a pixel.
  DATA
rx SIGNED,AUTO
ry SIGNED,AUTO
rw SIGNED,AUTO
rh SIGNED,AUTO
sp LONG,AUTO
mx LONG,AUTO
my LONG,AUTO
col LONG,AUTO
row LONG,AUTO
  CODE
  IF ~%bgObject:G THEN EXIT.
  sp = 0{PROP:Pixels}
  0{PROP:Pixels} = 1
  GETPOSITION(%bgObject:Rgn,rx,ry,rw,rh)
  mx = MOUSEX() - rx
  my = MOUSEY() - ry
  row = d2g_HitRow(%bgObject:G,my)
  0{PROP:Pixels} = sp
!  The scrollbar first: it is drawn over everything else, so it is clicked
!  before everything else.
#IF(%bgBarStyleU <> 'Windows')
  CASE d2g_HitHBar(%bgObject:G,mx,my)                         ! the drawn sideways bar
  OF 4
    %bgObject:HDrag = 1
    %bgObject:HGrab = d2g_HGrab(%bgObject:G,mx)
    EXIT
  OF 5
    %bgObject:ScrollX = %bgObject:ScrollX - d2g_ViewWidth(%bgObject:G)
    IF %bgObject:ScrollX < 0 THEN %bgObject:ScrollX = 0.
    d2g_ScrollX(%bgObject:G,%bgObject:ScrollX)
    DO BG:Bars:%bgObject
    d2g_PaintNow(%bgObject:G)
    EXIT
  OF 6
    %bgObject:ScrollX = %bgObject:ScrollX + d2g_ViewWidth(%bgObject:G)
    d2g_ScrollX(%bgObject:G,%bgObject:ScrollX)
    DO BG:Bars:%bgObject
    d2g_PaintNow(%bgObject:G)
    EXIT
  END
#ENDIF
  CASE d2g_VHit(%bgObject:G,mx,my)
  OF 1
    %bgObject:VDrag = 1
    %bgObject:VGrab = d2g_VGrab(%bgObject:G,my)               ! anchored, so it cannot jump
    EXIT
  OF 2
    POST(EVENT:PageUp,%bgList)
    EXIT
  OF 3
    POST(EVENT:PageDown,%bgList)
    EXIT
  END
!  A heading. On the edge of a column that is a resize; anywhere else it is a
!  request to sort by that column. Either way it never changes the selection.
  IF my < d2g_HdrHeight(%bgObject:G)
#IF(%bgFilterBtnU)
!  The drop-down box is drawn over the right of the heading, so it is what a
!  click there means - before the resize edge, which is in the same few pixels.
    col = d2g_HitBtn(%bgObject:G,mx,my)
    IF col >= 0
      %bgObject:SortCol = col
      DO BG:Menu:%bgObject
      EXIT
    END
#ENDIF
#IF(%bgSortHdr)
    %bgObject:SortCol = d2g_HitCol(%bgObject:G,mx)            ! remember it either way
#ENDIF
#IF(%bgSizeable)
!  In a grouped format the draggable edges belong to the GROUPS - one heading
!  stands over several fields, and there is nothing sensible to grab between
!  two of them that sit on different lines.
    IF %bgObject:Lines > 1
      col = d2g_HitGrpEdge(%bgObject:G,mx)
      IF col >= 0
        %bgObject:RzGrp   = 1
        %bgObject:RzCol   = col + 1
        %bgObject:RzX     = mx
        %bgObject:RzW     = d2g_GrpWidth(%bgObject:G,col)
        %bgObject:RzArmed = 1
        EXIT
      END
    END
    col = d2g_HitEdge(%bgObject:G,mx)
    IF col >= 0
!  Near an edge - but a click and a drag both start here, and until the mouse
!  MOVES there is no telling which this is. So the resize is only armed. Commit
!  it on the first click and a narrow column can never be sorted at all: the
!  grab margin reaches four pixels either side of every boundary, so a narrow
!  heading is almost entirely edge, and every click on it was being swallowed
!  by a resize that then went nowhere.
      %bgObject:RzGrp   = 0
      %bgObject:RzCol   = col + 1                             ! 1-based: 0 means nothing is being dragged
      %bgObject:RzX     = mx
      %bgObject:RzW     = d2g_ColWidth(%bgObject:G,col)
      %bgObject:RzArmed = 1
      EXIT
    END
#ENDIF
#IF(%bgSortHdr)
    IF %bgObject:SortCol >= 0
      DO BG:Sort:%bgObject
    END
#ENDIF
    EXIT
  END
  IF row < 0 OR row >= RECORDS(%bgQueueUsed) THEN EXIT.
  %bgList{PROP:Selected} = row + 1
  POST(EVENT:NewSelection,%bgList)                            ! let the browse react as usual
!  Give the focus to the BROWSE, not to the region. The LIST is invisible to
!  Windows but perfectly alive to Clarion, so with the focus on it every key an
!  ABC browse has always answered goes on working, unchanged and unwritten by
!  us: up and down arrows, PageUp and PageDown, Ctrl-PageUp and Ctrl-PageDown
!  for the two ends, the incremental locator, Insert, Delete and Enter. The
!  region only ever needed the mouse, and a REGION with PROP:IMM gets that
!  whether it has the focus or not.
  SELECT(%bgList)
  %bgObject:Sel = row
  d2g_Select(%bgObject:G,row)
  d2g_Repaint(%bgObject:G)
#IF(%bgClickCols)
!  HANDING THE CLICK ON. A template that tags or toggles by clicking a column
!  does it by reading PROPLIST:MouseDownRow and MouseDownField off the LIST -
!  where the user clicked ON IT. The grid covers the LIST, so that click never
!  lands there and the column stops answering. Staging those two properties
!  and posting the event is what a real click would have left behind.
!
!  ONLY the columns named on the prompts, and that is not caution for its own
!  sake: EVENT:Accepted on a browse LIST is also how ABC is told a record was
!  CHOSEN, so posting it for every click would open the update form every time
!  anyone clicked a row. Narrow and deliberate beats general and surprising.
  col = d2g_HitCol(%bgObject:G,mx)
  IF col >= 0 AND col < %bgObject:Cols
    IF INSTRING(',' & %bgObject:Col[col + 1] & ',',                            |
                ',' & CLIP('%bgClickCols') & ',',1,1)
      %bgList{PROPLIST:MouseDownRow}   = row + 1          ! solo tiene que ser > 0
      %bgList{PROPLIST:MouseDownField} = %bgObject:Col[col + 1]
      POST(EVENT:Accepted,%bgList)
!  Y DESARMARLO DETRAS. Un click de verdad deja esas propiedades puestas y
!  Windows las limpia en el evento siguiente; puestas a mano no las limpia
!  nadie, y quedan armadas para siempre. Lo que sigue es un lazo cerrado: el
!  manejador tilda, tildar hace ThisWindow.Reset(1), el Reset genera otro
!  Accepted, la condicion sigue siendo verdadera, y vuelve a tildar. El
!  programa deja de responder.
!  Este evento va POSTEADO detras del Accepted, asi que se atiende despues de
!  que el manejador leyo lo que necesitaba, y antes de que nada mas pueda
!  volver a entrar.
      POST(BG:ClrHit:%bgObject)
    END
  END
#ENDIF

BG:Rows:%bgObject ROUTINE
!  Make the grid and the browse agree on how tall a row is, because otherwise
!  they never agree on how long a PAGE is. ABC works out how many records to
!  load from the LIST's height and its line height; the grid works out how many
!  it can draw from the region's height and its row height. Let those differ
!  and the browse loads records the grid has no room for - they end up below
!  the visible area, and the last of them cannot be seen at all.
!
!  PROP:LineHeight answers in whatever PROP:Pixels is currently set to - 8
!  units, 16 pixels, measured in examples/BrowseGrid/lineh.clw - so it is read
!  in pixels, which is what the grid works in.
  DATA
sp   LONG,AUTO
lh   LONG,AUTO
need LONG,AUTO
  CODE
  IF ~%bgObject:G THEN EXIT.
  sp = 0{PROP:Pixels}
  0{PROP:Pixels} = 1
!  Whatever height is wanted, it can never be less than the type needs - that
!  is what made big rows come out short. The engine clamps it too, but the
!  clamped value is what has to go back to the LIST, or the browse still loads
!  to a height nothing is drawn at.
!  d2g_RowNeed already counts the lines in a record and the lines a wrapped
!  cell may use. Multiplying by the line count again here made a row as tall as
!  its lines SQUARED - and on a four-line format that is taller than the whole
!  browse, so ABC worked out that nothing fitted, loaded no records, and the
!  grid had nothing whatever to draw.
  need = d2g_RowNeed(%bgObject:G)
#IF(%bgRowHU > 0)
!  A row height was asked for, so the BROWSE is the one that gives way.
  lh = %bgRowHU
#ELSE
!  Nothing was asked for: take the browse's own line height...
  lh = %bgList{PROP:LineHeight} * %bgObject:Lines             ! which is per LINE, not per record
#ENDIF
  IF lh < need THEN lh = need.                                ! ...but never squash the type
  d2g_RowHeight(%bgObject:G,lh)
!  PROP:LineHeight is the height of one LINE, not of one record. On a
!  multi-line format the LIST multiplies it by the lines in the record itself,
!  so handing it the whole record height meant the browse thought each record
!  was lines-times-taller than it is, worked out that one fitted, and loaded
!  one. The grid keeps the record height; the LIST is given one line of it.
  IF %bgObject:Lines > 1
    %bgList{PROP:LineHeight} = lh / %bgObject:Lines
  ELSE
    %bgList{PROP:LineHeight} = lh
  END
#IF(%bgDiag)
!  QUIEN ESCRIBE EL ALTO DE LINEA, y con que entro. Son tres rutinas las que lo
!  tocan y una de ellas lo LEE para decidirlo, asi que sin saber cual escribio
!  cual numero no se puede distinguir un ajuste de una realimentacion.
  BG_Log('%Procedure %bgObject rows: need=' & need & ' lines=' &             |
         %bgObject:Lines & ' lh=' & lh & ' -> listlh=' &                     |
         %bgList{PROP:LineHeight} & ' rowh=' & d2g_RowH(%bgObject:G))
#ENDIF
  0{PROP:Pixels} = sp

BG:Items:%bgObject ROUTINE
!  Make the browse load as many records as the grid can DRAW.
!
!  ABC works out how many to load from the LIST's own height and line height.
!  The grid works out how many it can draw from the region's height and its row
!  height. Those are close but not equal - the two headings are different sizes,
!  for one - and whatever is left over is drawn as empty grid: one blank banded
!  row and then background, which is the gap under the rows.
!
!  Rather than guess at the difference, it is measured. Whatever the LIST is
!  using for its own heading is (its height - items * line height), and that
!  stays true whatever else changes, so the height it needs to hold `fit` rows
!  is that plus fit line heights. The LIST is invisible, so making it taller or
!  shorter than the region costs nothing and is never seen.
  DATA
sp    LONG,AUTO
x     SIGNED,AUTO
y     SIGNED,AUTO
w     SIGNED,AUTO
h     SIGNED,AUTO
lh    LONG,AUTO
newlh LONG,AUTO
items LONG,AUTO
fit   LONG,AUTO
  CODE
  IF ~%bgObject:G THEN EXIT.
  sp = 0{PROP:Pixels}
  0{PROP:Pixels} = 1
  lh    = %bgList{PROP:LineHeight}
  items = %bgList{PROP:Items}
  fit   = d2g_PageSize(%bgObject:G)
!  Through the LINE HEIGHT, not the geometry. Stretching the LIST taller was
!  the obvious way to make ABC load more records, and it worked - until the
!  region started following the LIST on every fill, at which point the grid
!  inherited the stretch and ran off the bottom of the window and over the
!  buttons. Two mechanisms feeding each other.
!
!  The line height reaches the same answer and touches nothing anyone can see:
!  ABC divides the LIST height by it to decide how many records fit, so asking
!  for  of them is arithmetic on a number that is already invisible.
#IF(%bgDiag)
!  LA GEOMETRIA CON LA QUE SE DECIDE, entera. El alto del area contra el que se
!  mide, lo que se lleva el encabezado, lo que mide una fila, y cuantas dice el
!  motor que entran. Si despues falta una fila abajo, la cuenta esta aca y no
!  hay que deducirla de una captura.
  BG_Log('%Procedure %bgObject items: alto=' & %bgObject:Rgn{PROP:Height} &   |
         ' hdr=' & d2g_HdrHeight(%bgObject:G) &                               |
         ' rowh=' & d2g_RowH(%bgObject:G) &                                   |
         ' page=' & fit & ' listlh=' & lh & ' listitems=' & items)
#ENDIF
  IF lh > 0 AND items > 0 AND fit > 0 AND fit <> items
    newlh = items * lh / fit
    IF newlh < 2 THEN newlh = 2.
    %bgList{PROP:LineHeight} = newlh
#IF(%bgDiag)
    BG_Log('%Procedure %bgObject items: baja el alto de linea a ' & newlh)
#ENDIF
  END
  0{PROP:Pixels} = sp

BG:Conceal:%bgObject ROUTINE
!  Take WS_VISIBLE off the LIST at the WINDOWS level. Not HIDE(): ABC works out
!  how many rows to load from the control's own state, and a hidden browse
!  decides it has none - that was the very first bug this template had. But
!  WS_VISIBLE is Windows' flag, not Clarion's. Strip it and Windows stops
!  painting and hit-testing the control, while PROP:Hide, the queue, the
!  visible-row count and everything else ABC reads are untouched. Proved in
!  examples/BrowseGrid/novis.clw: winvis 1>0, PROP:Hide 0>0, recs 20.
!
!  This replaces WS_CLIPSIBLINGS, which was never enough. The two controls
!  really are siblings - the same harness reports sameparent 1 - so the LIST
!  was painting by some route that ignores the clip, and it did it every time
!  it had any reason to redraw: on being given a new column width, on taking
!  the focus for the popup. A window Windows will not paint cannot do that.
  DATA
sty LONG,AUTO
  CODE
  sty = bgApi_GetWindowLong(%bgList{PROP:Handle},BG:GwlStyle)
  IF BAND(sty,BG:Visible)
    bgApi_SetWindowLong(%bgList{PROP:Handle},BG:GwlStyle,                       |
                        BAND(sty,BXOR(0FFFFFFFFh,BG:Visible)))
    bgApi_SetWindowPos(%bgList{PROP:Handle},0,0,0,0,0,                          |
                       BOR(BOR(BG:FrameChanged,BG:NoMove),BOR(BG:NoSize,BG:NoZOrder)))
    %bgObject:Clipped = 1
  END

BG:Reveal:%bgObject ROUTINE
!  ...and give it back, so a window that gives up on the grid still has a
!  working browse to show.
  DATA
sty LONG,AUTO
  CODE
  IF ~%bgObject:Clipped THEN EXIT.
  sty = bgApi_GetWindowLong(%bgList{PROP:Handle},BG:GwlStyle)
  bgApi_SetWindowLong(%bgList{PROP:Handle},BG:GwlStyle,BOR(sty,BG:Visible))
  bgApi_SetWindowPos(%bgList{PROP:Handle},0,0,0,0,0,                            |
                     BOR(BOR(BG:FrameChanged,BG:NoMove),BOR(BG:NoSize,BG:NoZOrder)))
  %bgObject:Clipped = 0

BG:Mark:%bgObject ROUTINE
!  Where ABC will say which column it sorted by, believe it rather than our own
!  memory of what was clicked - a sort can be changed by a tab, a button or the
!  browse's own code, none of which come through us. PROPLIST:SortColumn is
!  only kept when the browse was given sort colours, so when it says nothing
!  the mark stays where the last click put it.
#IF(%bgSortHdr)
  DATA
sc LONG,AUTO
i  LONG,AUTO
  CODE
#IF(%bgFilterBtnU)
  d2g_FilterOn(%bgObject:G,-1,0)                              ! every mark, every refill
  LOOP i = 1 TO %bgObject:Cols
    IF %bgObject:ColFilt[i] THEN d2g_FilterOn(%bgObject:G,i - 1,1).
  END
#ENDIF
  sc = %bgList{PROPLIST:SortColumn}
  IF ~sc OR sc = %bgObject:SortOn THEN EXIT.
  %bgObject:SortOn = sc
  LOOP i = 1 TO %bgObject:Cols                                ! back to a GRID column
    IF %bgObject:Col[i] = sc
      d2g_SortMark(%bgObject:G,i - 1,%bgObject:SortDir)
      EXIT
    END
  END
  d2g_SortMark(%bgObject:G,-1,1)                              ! sorted on a column we do not draw
#ELSE
  EXIT
#ENDIF

BG:Menu:%bgObject ROUTINE
!  Excel's column drop-down. Sorting goes through the browse exactly as a
!  heading click does; filtering goes through ABC's own SetFilter, so range
!  limits, locators and everything else the browse was given keep working.
!
!  The field name for the filter comes from WHO(): an ABC browse queue labels
!  its fields with the file fields they came from, so WHO() on the browse queue
!  answers "STU:LastName" - which is exactly what a filter expression wants,
!  and means nothing has to be mapped by hand.
#IF(%bgFilterBtnU)
  DATA
pick LONG,AUTO
fld  LONG,AUTO
mnu  CSTRING(301)
lc   LONG,AUTO
nm   CSTRING(65)
val  CSTRING(129)
  CODE
  fld = %bgObject:Fld[%bgObject:SortCol + 1]
  IF ~fld THEN EXIT.
  nm  = CLIP(WHO(%bgQueueUsed,fld))
  GET(%bgQueueUsed,CHOICE(%bgList))
  IF ERRORCODE()
    val = ''
  ELSE
    val = CLIP(LEFT(WHAT(%bgQueueUsed,fld)))
  END
!  NO SEPARATORS. POPUP counts a '-' as an item, so with two of them in here
!  every choice after the first was numbered one or two higher than it looked -
!  "Filter on" was item 3 and matched nothing, and "Clear this filter" was item
!  4, which is why CLEARING a filter is what applied one.
!  ARMADO EN UNA CADENA, no en una expresion con las opciones intercaladas. Con
!  todas obligatorias alcanzaba una constante; con todas opcionales hay que poder
!  no agregar ninguna, y una expresion que puede quedarse sin terminos no se
!  escribe. Cada una deja su separador atras y al final se saca el ultimo.
  mnu = ''
#IF(%bgMnSortU)
  mnu = CLIP(mnu) & '%bgTSortAsc|%bgTSortDesc|'
#ENDIF
#IF(%bgMnFiltOnU)
  mnu = CLIP(mnu) & '%bgTFilterOn {{' & CLIP(val) & '}|'
#ENDIF
#IF(%bgFilterValsU)
  mnu = CLIP(mnu) & '%bgTFilterBy|'
#ENDIF
#IF(%bgFilterTextU)
  mnu = CLIP(mnu) & '%bgTFindMenu|'
#ENDIF
#IF(%bgMnClrThisU)
  mnu = CLIP(mnu) & '%bgTClearThis|'
#ENDIF
#IF(%bgMnClrAllU)
  mnu = CLIP(mnu) & '%bgTClearAll|'
#ENDIF
#IF(%bgChooserU)
  mnu = CLIP(mnu) & '%bgTColumns|'
#ENDIF
#IF(%bgAutoFitU AND %bgFlatten)
  mnu = CLIP(mnu) & '%bgTAutoFit|'
#ENDIF
#IF(%bgSchemesU AND %bgRemember)
  mnu = CLIP(mnu) & '%bgTSchMenu|'
#ENDIF
#IF(%bgMnResetU)
  mnu = CLIP(mnu) & '%bgTReset|'
#ENDIF
!  SIN OPCIONES NO HAY MENU. Un POPUP con la cadena vacia igual abre algo, y ese
!  algo es un rectangulo de nada que el usuario tiene que cerrar.
  IF ~mnu THEN EXIT.
!  Y fuera el ultimo separador, o POPUP cuenta una opcion vacia al final - que
!  se veria como un renglon en blanco y correria la numeracion.
  mnu = SUB(mnu,1,LEN(mnu) - 1)
  pick = POPUP(mnu)
  IF ~pick THEN EXIT.                                       ! se cerro sin elegir
  CASE pick
#IF(%bgMnSortU)
  OF %bgMiAsc                                                 ! ascending
    lc = %bgObject:Col[%bgObject:SortCol + 1]
    IF %bgObject:SortOn <> lc
      DO BG:Sort:%bgObject                                    ! a new heading starts ascending
    ELSIF %bgObject:SortDir < 0
      DO BG:Sort:%bgObject                                    ! it is descending: one press flips it
    END
  OF %bgMiDesc                                                ! descending
!  Clearing SortOn first - which is what this used to do - makes BG:Sort take
!  its "a new column" branch, and that branch always sets ascending. So both
!  menu items came out ascending however many times they were pressed. Ask for
!  the direction instead, and press only as often as getting there takes.
    lc = %bgObject:Col[%bgObject:SortCol + 1]
    IF %bgObject:SortOn <> lc
      DO BG:Sort:%bgObject                                    ! ascending first...
      DO BG:Sort:%bgObject                                    ! ...then over to descending
    ELSIF %bgObject:SortDir > 0
      DO BG:Sort:%bgObject
    END
#ENDIF
#IF(%bgMnFiltOnU)
  OF %bgMiFiltOn                                              ! filter on this value
    IF nm AND val
!  Per column, and they add up - filtering a second column used to replace the
!  first, so the browse quietly stopped being filtered on the one whose glyph
!  had just gone out.
      %bgObject:ColFilt[%bgObject:SortCol + 1] = CLIP(nm) & ' = ' & ''''        |
                                               & BG_Quote(CLIP(val)) & ''''
      d2g_FilterOn(%bgObject:G,%bgObject:SortCol,1)
      d2g_PaintNow(%bgObject:G)                               ! say so NOW, not when the data lands
      DO BG:Filter:%bgObject
    END
#ENDIF
#IF(%bgFilterValsU)
  OF %bgMiFiltBy                                              ! pick from the values in the file
    DO BG:Values:%bgObject
#ENDIF
#IF(%bgFilterTextU)
  OF %bgMiFindTx                                              ! free text
    DO BG:Find:%bgObject
#ENDIF
#IF(%bgMnClrThisU)
  OF %bgMiClrThis                                             ! clear this column's
    %bgObject:ColFilt[%bgObject:SortCol + 1] = ''
    d2g_FilterOn(%bgObject:G,%bgObject:SortCol,0)
    d2g_PaintNow(%bgObject:G)
    DO BG:Filter:%bgObject
#ENDIF
#IF(%bgMnClrAllU)
  OF %bgMiClrAll                                              ! clear every column's
    LOOP fld = 1 TO BG:MaxCols                              ! quedaba clavado en 32
      %bgObject:ColFilt[fld] = ''
    END
    d2g_FilterOn(%bgObject:G,-1,0)
    d2g_PaintNow(%bgObject:G)
    DO BG:Filter:%bgObject
#ENDIF
#IF(%bgChooserU)
  OF %bgMiCols                                                ! which columns to show
    DO BG:Chooser:%bgObject
#ENDIF
#IF(%bgAutoFitU AND %bgFlatten)
  OF %bgMiAutoFit                                             ! size every column to its content
    DO BG:AutoFit:%bgObject
#ENDIF
#IF(%bgSchemesU AND %bgRemember)
  OF %bgMiSchemes                                             ! save / recall a layout
    DO BG:Schemes:%bgObject
#ENDIF
#IF(%bgMnResetU)
  OF %bgMiReset                                               ! put everything back
    DO BG:Reset:%bgObject
#ENDIF
  END
#ELSE
  EXIT
#ENDIF

BG:Filter:%bgObject ROUTINE
!  Hand the filter to the browse itself. Nothing else can do it: the records
!  come out of the VIEW, and only the browse object knows how to re-read them.
#IF(%bgFilterBtnU)
#IF(%bgBrowseUsed)
  DATA
i LONG,AUTO
  CODE
!  A filter ID OF OUR OWN, one per column. Two reasons, and the first is not
!  cosmetic: SetFilter with no ID uses '5 Standard', which is the ID the
!  BrowseBox template itself uses for the filter the developer set on the browse
!  (ABBROWSE.TPW:1120). Filtering from the grid was therefore throwing that
!  filter away, and clearing ours left the browse permanently unfiltered.
!
!  The second is that ABC already does the joining. ApplyFilter walks every ID
!  it holds and ANDs them, each in its own brackets, with the range limits in
!  front (ABFILE.CLW:2613) - so there is nothing to concatenate here, and an
!  empty expression DELETES that ID rather than leaving an empty bracket.
!  Setting all of them every time is therefore both safe and idempotent.
  %bgObject:Filters = 0
  LOOP i = 1 TO %bgObject:Cols
    %bgBrowseUsed.SetFilter(%bgObject:ColFilt[i],'BrowseGrid:' & i)
    IF %bgObject:ColFilt[i] THEN %bgObject:Filters += 1.
  END
!  No DATA section here, so no CODE statement either - a ROUTINE only accepts
!  CODE after a DATA block, and this one emitted a bare one the moment the
!  filter button was switched on.
!
!  Filling the grid HERE reads the old queue. ABC does not finish applying a
!  filter inside SetSort: it ends with PostNewSelection, which is a POST, so
!  the re-read lands on a later ACCEPT cycle - which is why the list only
!  caught up when something else was done to it, and why clearing a filter
!  appeared to do nothing until the next click. SetSort also restarts from the
!  queue's own view position rather than the top, so on a filter that matches
!  nothing where the cursor is, it can come back empty.
!
!  So: apply it, then ask the browse to go to the top of the new set through
!  its own event. ABC re-reads, calls Reset when it has, and the Reset embed
!  fills the grid - by which time there is something to fill it from.
#IF(%bgTotals)
  %bgObject:SumDue = 1                                        ! el conjunto cambio
#ENDIF
  %bgBrowseUsed.ResetSort(1)
  POST(EVENT:ScrollTop,%bgList)
  POST(BG:Refill:%bgObject)                                   ! and refresh once it has landed
#ELSE
  MESSAGE('%bgTNoObject','BrowseGrid',ICON:Exclamation)
#ENDIF
#ELSE
  EXIT
#ENDIF

BG:Sort:%bgObject ROUTINE
!  Sort by the column that was clicked, exactly as clicking the LIST's own
!  heading would. ABC's sort-header class reads PROPLIST:MouseDownField to find
!  out which column was pressed (brwext.clw:2926) - and that property can simply
!  be WRITTEN. So it is set and EVENT:HeaderPressed posted, and there is no
!  geometry in it at all.
!
!  It used to post a fake mouse click at the heading's x instead, which is why
!  a column could not be sorted until it had been resized once.
!  examples/BrowseGrid/mdfield.clw shows why: a posted click on a LIST that
!  Windows will not paint raises no header press whatever - "HeaderPressed n1"
!  counts the written one only, not the clicked one - while writing the field
!  and posting the event works on the concealed control every time.
#IF(%bgSortHdr)
  DATA
lc LONG,AUTO
  CODE
!  One press of a heading, and a note of what it will have done. ABC toggles
!  ascending and descending on each press of the SAME heading and starts a new
!  one ascending; nothing reports the direction back - PROPLIST:SortColumn is
!  an ABS() - so the only way to ask for a direction is to know where it
!  currently is. That is what SortOn and SortDir are: our model of ABC's state,
!  kept by the same rule ABC keeps it.
  lc = %bgObject:Col[%bgObject:SortCol + 1]                   ! which LIST column that was
  IF ~lc THEN EXIT.
  IF %bgObject:SortOn = lc
    %bgObject:SortDir = -%bgObject:SortDir
  ELSE
    %bgObject:SortOn  = lc
    %bgObject:SortDir = 1
  END
  d2g_SortMark(%bgObject:G,%bgObject:SortCol,%bgObject:SortDir)
  %bgList{PROPLIST:MouseDownField} = lc
  POST(EVENT:HeaderPressed,%bgList)
#ELSE
  EXIT
#ENDIF

BG:GrpBack:%bgObject ROUTINE
!  Put a resized group back onto the LIST: the group's own width, and every
!  field inside it, because they were all scaled to fit. The browse goes on
!  believing it owns its columns, and a rebuild reads back what is on screen.
#IF(%bgSizeable)
  DATA
i  LONG,AUTO
lc LONG,AUTO
g  LONG,AUTO
  CODE
  g = %bgObject:RzCol - 1
  lc = %bgObject:GrpCol[g + 1]
  IF lc
    %bgList{PROPLIST:Width + PROPLIST:Group,lc} = d2g_GrpWidth(%bgObject:G,g) / 2
  END
  LOOP i = 1 TO %bgObject:Cols
    IF d2g_ColGrp(%bgObject:G,i - 1) <> g THEN CYCLE.
    lc = %bgObject:Col[i]
    IF lc
      %bgList{PROPLIST:Width,lc} = d2g_GrpColW(%bgObject:G,i - 1) / 2
    END
  END
  DO BG:Place:%bgObject
  d2g_Resize(%bgObject:G)
  d2g_PaintNow(%bgObject:G)
#ELSE
  EXIT
#ENDIF

BG:SchSave:%bgObject ROUTINE
!  Guardar la disposicion de ahora bajo el nombre que haya en %bgObject:SchName.
!  Se puede llamar desde un embed:
!
!      %bgObject:SchName = 'Ventas'
!      DO BG:SchSave:%bgObject
!
!  El dialogo llama a esta misma rutina. Dos copias de esto - una para el
!  usuario y otra para el programador - es como Reset y la apertura se
!  separaron, y ese error ya esta escrito mas abajo en este archivo.
#IF(%bgSchemesU AND %bgRemember)
  DATA
sec CSTRING(193)
c   LONG,AUTO
ex  LONG,AUTO
  CODE
  IF ~%bgObject:G OR ~%bgObject:SchName THEN EXIT.
  sec = 'BrowseGrid:%Procedure:%bgObject' & ':' & CLIP(%bgObject:SchName)
  LOOP c = 1 TO 512
    ex = %bgList{PROPLIST:Exists,c}
    IF ~ex THEN BREAK.
    INIMgr.Update(sec,'w' & c,%bgList{PROPLIST:Width,c})
    INIMgr.Update(sec,'h' & c,CLIP(INIMgr.TryFetch('BrowseGrid:%Procedure:%bgObject','h' & c)))
#IF(%bgTotals)
    INIMgr.Update(sec,'t' & c,CLIP(INIMgr.TryFetch('BrowseGrid:%Procedure:%bgObject','t' & c)))
#ENDIF
  END
!  AL INDICE TAMBIEN. Un esquema guardado desde codigo que no figure en la
!  lista existe pero no se puede elegir, que es una forma rara de no existir.
  DO BG:SchIndex:%bgObject
#ELSE
  EXIT
#ENDIF

BG:SchLoad:%bgObject ROUTINE
!  Recuperar el esquema que nombre %bgObject:SchName. Desde un embed:
!
!      %bgObject:SchName = 'Ventas'
!      DO BG:SchLoad:%bgObject
!      IF ~%bgObject:SchDid ...no habia nada guardado con ese nombre...
!
!  Deja el browse redibujado. Sirve tambien al abrir la ventana, para que cada
!  usuario entre con el suyo.
#IF(%bgSchemesU AND %bgRemember)
  DATA
sec CSTRING(193)
val CSTRING(33)
c   LONG,AUTO
ex  LONG,AUTO
  CODE
  %bgObject:SchDid = 0
  IF ~%bgObject:G OR ~%bgObject:SchName THEN EXIT.
  sec = 'BrowseGrid:%Procedure:%bgObject' & ':' & CLIP(%bgObject:SchName)
!  DEL ESQUEMA A LO QUE SE RECUERDA, y de ahi a la pantalla. Copiarlo tambien a
!  la seccion de siempre es lo que hace que el esquema recuperado sea ademas el
!  que vuelve solo la proxima vez que se abra el browse.
  LOOP c = 1 TO 512
    ex = %bgList{PROPLIST:Exists,c}
    IF ~ex THEN BREAK.
    val = CLIP(INIMgr.TryFetch(sec,'w' & c))
!  Y tiene que parecer un ancho antes de usarse como uno: un INI editado a mano
!  no puede dejar el browse sin columnas.
    IF val AND NUMERIC(val)
      %bgList{PROPLIST:Width,c} = val
      INIMgr.Update('BrowseGrid:%Procedure:%bgObject','w' & c,val)
      %bgObject:SchDid = 1
    END
    INIMgr.Update('BrowseGrid:%Procedure:%bgObject','h' & c,CLIP(INIMgr.TryFetch(sec,'h' & c)))
#IF(%bgTotals)
    INIMgr.Update('BrowseGrid:%Procedure:%bgObject','t' & c,CLIP(INIMgr.TryFetch(sec,'t' & c)))
#ENDIF
  END
  IF %bgObject:SchDid
!  La misma secuencia que abrir la ventana, y en ese orden.
    DO BG:Columns:%bgObject
    DO BG:Rows:%bgObject
    DO BG:Items:%bgObject
    d2g_Resize(%bgObject:G)
    DO BG:Fill:%bgObject
    d2g_PaintNow(%bgObject:G)
  END
#ELSE
  EXIT
#ENDIF

BG:SchIndex:%bgObject ROUTINE
!  Meter %bgObject:SchName en el indice si no estaba. El indice es una lista
!  separada por barras en la seccion de siempre; una clave por nombre obligaria
!  a numerarlas y a renumerarlas al borrar una del medio.
#IF(%bgSchemesU AND %bgRemember)
  DATA
lst CSTRING(1025)
  CODE
  IF ~%bgObject:SchName THEN EXIT.
  lst = CLIP(INIMgr.TryFetch('BrowseGrid:%Procedure:%bgObject','esq'))
!  Las barras del nombre, fuera: son el separador del indice y partirian el
!  nombre en dos al releerlo.
  IF INSTRING('|',CLIP(%bgObject:SchName),1,1) THEN EXIT.
  IF ~INSTRING('|' & CLIP(%bgObject:SchName) & '|','|' & CLIP(lst) & '|',1,1)
    IF lst
      lst = CLIP(lst) & '|' & CLIP(%bgObject:SchName)
    ELSE
      lst = CLIP(%bgObject:SchName)
    END
    INIMgr.Update('BrowseGrid:%Procedure:%bgObject','esq',lst)
  END
#ELSE
  EXIT
#ENDIF

BG:Schemes:%bgObject ROUTINE
!  Guardar las columnas que se estan usando con un nombre, y recuperarlas.
!
!  NO INVENTA ALMACENAMIENTO. Lo que se guarda es exactamente lo que este grid
!  ya recuerda entre corridas - ancho por columna, el ancho original de las
!  ocultas, y cuales totalizan - nada mas que en una seccion con nombre en vez
!  de en la de siempre. Recuperar copia de esa seccion a la de siempre y
!  reabre; asi un esquema recuperado tambien es el que se recuerda la proxima
!  vez, sin un segundo lugar donde la verdad pueda quedar distinta.
!
!  NO SE GUARDAN FILTROS. Es la misma razon por la que no se recuerdan: un
!  filtro es una expresion, y una que no parsea es un error EN TIEMPO DE
!  EJECUCION al abrir la ventana, antes de que haya nada en pantalla que lo
!  explique. Un ancho equivocado se ve raro; un filtro equivocado no deja
!  entrar.
!
!  Y NO SE GUARDA EL ORDEN de las columnas, porque el grid no las reordena.
#IF(%bgSchemesU AND %bgRemember)
  DATA
EQ   QUEUE
Name   STRING(32)
     END
EName STRING(32)
EW   WINDOW('%bgTSchTitle'),AT(,,180,186),GRAY,SYSTEM,CENTER,FONT('Segoe UI',9)
       STRING('%bgTSchHint'),AT(8,7,164,26),USE(?EHint),TRN
       LIST,AT(8,36,164,96),USE(?EList),FROM(EQ),VSCROLL,                       |
            FORMAT('160L(2)~%bgTSchName~@s32@')
       PROMPT('%bgTSchAs'),AT(8,138),USE(?EPmt)
       ENTRY(@s32),AT(40,137,132,11),USE(EName)
       BUTTON('%bgTSchSave'),AT(8,154,52,14),USE(?ESave)
       BUTTON('%bgTSchLoad'),AT(64,154,52,14),USE(?ELoad)
       BUTTON('%bgTSchDel'),AT(120,154,52,14),USE(?EDel)
       BUTTON('%bgTSchClose'),AT(120,170,52,14),USE(?EClose),STD(STD:Close)
     END
lst  CSTRING(1025)
one  CSTRING(33)
sec  CSTRING(193)
val  CSTRING(33)
c    LONG,AUTO
ex   LONG,AUTO
i    LONG,AUTO
did  LONG
act  LONG
  CODE
  IF ~%bgObject:G THEN EXIT.
  did   = 0
  act   = 0
  EName = ''
  FREE(EQ)
!  EL INDICE ES UNA LISTA SEPARADA POR BARRAS, partida a mano porque Clarion no
!  trae un split. Una clave por nombre obligaria a numerarlas, y a renumerarlas
!  al borrar una del medio - que es como se pierde un esquema que nadie toco.
  lst = CLIP(INIMgr.TryFetch('BrowseGrid:%Procedure:%bgObject','esq'))
  LOOP
    IF ~lst THEN BREAK.
    i = INSTRING('|',lst,1,1)
    IF i
      one = SUB(lst,1,i - 1)
      lst = SUB(lst,i + 1,LEN(lst) - i)
    ELSE
      one = lst
      lst = ''
    END
    IF one
      EQ.Name = one
      ADD(EQ,+EQ.Name)
    END
  END
  OPEN(EW)
!  LOS BOTONES NO HACEN EL TRABAJO, solo dicen cual. Un equate de campo se
!  resuelve contra la ventana ACTUAL, y mientras este dialogo esta abierto la
!  actual es EL: cualquier %bgList{...} de aca adentro lee un control de esta
!  ventanita en vez del LIST del browse, y no se queja - devuelve que la columna
!  no existe, el bucle corta en la primera vuelta y no se escribe nada. Que es
!  exactamente como se ve un esquema que se guarda vacio.
!
!  BG:Find ya se habia comido esto y lo dice en su propio comentario. El trabajo
!  va abajo, con la ventana cerrada.
  ACCEPT
    CASE ACCEPTED()
    OF ?EList
      GET(EQ,CHOICE(?EList))
      IF ~ERRORCODE()
        EName = EQ.Name
        DISPLAY(?EName)
      END
    OF ?ESave
      EName = CLIP(LEFT(EName))
      IF ~EName
        MESSAGE('%bgTSchNoName','%bgTSchTitle',ICON:Asterisk)
        CYCLE
      END
!  FUERA LAS BARRAS. El indice las usa de separador, asi que un nombre con una
!  adentro se partiria en dos al releerlo.
      LOOP i = 1 TO LEN(CLIP(EName))
        IF EName[i] = '|' THEN EName[i] = ' '.
      END
      EQ.Name = EName
      GET(EQ,+EQ.Name)
      IF ERRORCODE() OR EQ.Name <> EName
        IF RECORDS(EQ) >= BG:MaxSch
          MESSAGE('%bgTSchFull','%bgTSchTitle',ICON:Exclamation)
          CYCLE
        END
        EQ.Name = EName
        ADD(EQ,+EQ.Name)
      END
      act = 1
      POST(EVENT:CloseWindow)
    OF ?ELoad
      IF ~EName
        MESSAGE('%bgTSchNone','%bgTSchTitle',ICON:Asterisk)
        CYCLE
      END
      act = 2
      POST(EVENT:CloseWindow)
    OF ?EDel
      IF ~EName
        MESSAGE('%bgTSchNone','%bgTSchTitle',ICON:Asterisk)
        CYCLE
      END
      EQ.Name = EName
      GET(EQ,+EQ.Name)
      IF ~ERRORCODE() AND EQ.Name = EName THEN DELETE(EQ).
      act = 3
      POST(EVENT:CloseWindow)
    END
  END
  CLOSE(EW)
!  DE ACA PARA ABAJO la ventana actual vuelve a ser la del browse, que es la
!  unica contra la que %bgList significa algo.
  sec = 'BrowseGrid:%Procedure:%bgObject' & ':' & CLIP(EName)
  CASE act
  OF 1                                                        ! guardar
    %bgObject:SchName = EName
    DO BG:SchSave:%bgObject
  OF 2                                                        ! recuperar
    %bgObject:SchName = EName
    DO BG:SchLoad:%bgObject
!  NADA QUE RECUPERAR es un caso, no un silencio: dejaria el browse igual y al
!  usuario preguntandose si apreto bien.
    IF ~%bgObject:SchDid THEN MESSAGE('%bgTSchEmpty','%bgTSchTitle',ICON:Asterisk).
  OF 3                                                        ! borrar
    sec = 'BrowseGrid:%Procedure:%bgObject' & ':' & CLIP(EName)
    LOOP c = 1 TO 512
      ex = %bgList{PROPLIST:Exists,c}
      IF ~ex THEN BREAK.
      INIMgr.Update(sec,'w' & c,'')
      INIMgr.Update(sec,'h' & c,'')
#IF(%bgTotals)
      INIMgr.Update(sec,'t' & c,'')
#ENDIF
    END
  END
!  EL INDICE, desde la cola: es la que estuvo mandando todo el rato.
  lst = ''
  LOOP i = 1 TO RECORDS(EQ)
    GET(EQ,i)
    IF ERRORCODE() THEN BREAK.
    IF lst
      lst = CLIP(lst) & '|' & CLIP(EQ.Name)
    ELSE
      lst = CLIP(EQ.Name)
    END
  END
  INIMgr.Update('BrowseGrid:%Procedure:%bgObject','esq',lst)
#ELSE
  EXIT
#ENDIF

BG:Reset:%bgObject ROUTINE
!  Throw away everything this grid remembers and read the browse again as it was
!  designed. Anything that can be got into a state has to have a way out of it,
!  and hunting through an INI file is not one.
#IF(%bgRemember)
  DATA
c   LONG,AUTO
ex  LONG,AUTO
fld LONG,AUTO
was CSTRING(32)
  CODE
  IF ~%bgObject:G THEN EXIT.
  LOOP c = 1 TO 512
    ex = %bgList{PROPLIST:Exists,c}
    IF ~ex THEN BREAK.
    fld = %bgList{PROPLIST:FieldNo,c}
    IF ~fld THEN CYCLE.
!  Back to the width the formatter drew, not to the last one that was
!  remembered. Restoring only the hidden ones - which is what this did - left
!  every column that had merely been DRAGGED sitting where it was dragged to.
    IF c <= BG:MaxCols AND %bgObject:W0[c]
      %bgList{PROPLIST:Width,c} = %bgObject:W0[c]
    ELSE
      was = CLIP(INIMgr.TryFetch('BrowseGrid:%Procedure:%bgObject','h' & c))
      IF was AND was <> '0'                                   ! at least un-hide it
        %bgList{PROPLIST:Width,c} = was
      END
    END
    INIMgr.Update('BrowseGrid:%Procedure:%bgObject','w' & c,'')
    INIMgr.Update('BrowseGrid:%Procedure:%bgObject','h' & c,'')
    INIMgr.Update('BrowseGrid:%Procedure:%bgObject','f' & c,'')
#IF(%bgTotals)
    INIMgr.Update('BrowseGrid:%Procedure:%bgObject','t' & c,'')
#ENDIF
  END
  LOOP c = 1 TO BG:MaxCols                                    ! quedaba clavado en 32
    %bgObject:ColFilt[c] = ''
  END
  d2g_FilterOn(%bgObject:G,-1,0)
!  From here on, exactly what opening the window does - and in that order.
!  Reset used to run its own shorter version of it: no BG:Items, so the
!  browse was never told how many records the new layout has room for, and no
!  fill of its own, only the one BG:Filter posts. Two paths that are supposed
!  to end in the same place, written twice, drifting apart - which is how a
!  browse can come back from Reset looking like nothing it ever looked like
!  when it opened.
  DO BG:Columns:%bgObject
  DO BG:Rows:%bgObject
  DO BG:Items:%bgObject
  d2g_Resize(%bgObject:G)
  DO BG:Filter:%bgObject
  DO BG:Fill:%bgObject
  d2g_PaintNow(%bgObject:G)
#ELSE
  EXIT
#ENDIF

BG:AutoFit:%bgObject ROUTINE
!  Size every visible column to the widest thing in it - its heading or one of
!  its values. The measuring is done the way ABC measures its own auto-sized
!  columns (brwext.clw:3468): give a hidden STRING the font and the text and
!  ask it how wide it would have to be.
!
!  TWO PASSES, AND THEY ARE NOT THE SAME PASS ON PURPOSE.
!
!  The loaded page is already in memory, so every cell of it is measured
!  exactly - a few dozen rows, and it is what the user is actually looking at.
!  Past the page there is no queue to read, only the view, and walking it means
!  EVALUATE by field NAME instead of WHAT by field number: the record buffer is
!  what moves, not the queue. That is the expensive call - the totals cost
!  ~14 us a record for the same reason - so out there the longest text is kept
!  by character count and only the winner is measured.
!
!  Which is an approximation, and worth naming: in a proportional font ten i's
!  are narrower than four W's. It costs one measurement a column instead of one
!  a cell, the page - where being wrong would show - is exact, and a column
!  that comes out a few pixels shy can be fixed by dragging it or pressing this
!  again.
#IF(%bgAutoFitU AND %bgFlatten)
  DATA
c    LONG,AUTO
i    LONG,AUTO
lc   LONG,AUTO
w    LONG,AUTO
sp   LONG,AUTO
n    LONG
txt  CSTRING(133)
best LONG,DIM(BG:MaxCols)                                   ! widest so far, in pixels
cand CSTRING(133),DIM(BG:MaxCols)                           ! longest text the walk saw
nm   CSTRING(65),DIM(BG:MaxCols)                            ! field name, to read it by
sav  STRING(1024)
  CODE
  IF ~%bgObject:G OR ~%bgObject:Meas THEN EXIT.
!  PROP:Width answers in whatever units the window is in, and a browse window
!  is in dialog units. Ask in pixels and put the window back, exactly as the
!  tooltip does - the engine thinks in pixels and the LIST stores dialog units,
!  and mixing the two is how a threshold of 20 came to mean 40.
  sp = 0{PROP:Pixels}
  0{PROP:Pixels} = 1
!  The ruler is built once, at setup. Ctrl+wheel can have zoomed the grid since
!  then, so it is asked what point size it is drawing at NOW.
  %bgObject:Meas{PROP:FontName} = %bgObject:Face
  %bgObject:Meas{PROP:FontSize} = d2g_FontPt(%bgObject:G)
!  THE HEADING COUNTS. A column sized to its values alone truncates its own
!  title, which is the one string on screen that never scrolls away.
  LOOP c = 1 TO %bgObject:Cols
    best[c] = 0
    cand[c] = ''
    nm[c]   = ''
    lc = %bgObject:Col[c]
    IF ~lc THEN CYCLE.
    %bgObject:Meas{PROP:Text} = CLIP(%bgList{PROPLIST:Header,lc})
    best[c] = %bgObject:Meas{PROP:Width}
  END
!  The page, exactly. Same formatting as the fill uses, or the measurement
!  would be of a string nobody ever sees.
  LOOP i = 1 TO RECORDS(%bgQueueUsed)
    GET(%bgQueueUsed,i)
    IF ERRORCODE() THEN BREAK.
    LOOP c = 1 TO %bgObject:Cols
      IF %bgObject:IFld[c] THEN CYCLE.                      ! a tick box carries no text
      IF %bgObject:Pic[c]
        txt = CLIP(LEFT(FORMAT(WHAT(%bgQueueUsed,%bgObject:Fld[c]),                |
                               CLIP(%bgObject:Pic[c]))))
      ELSE
        txt = CLIP(LEFT(WHAT(%bgQueueUsed,%bgObject:Fld[c])))
      END
      IF ~txt THEN CYCLE.
      %bgObject:Meas{PROP:Text} = txt
      w = %bgObject:Meas{PROP:Width}
      IF w > best[c] THEN best[c] = w.
    END
  END
#IF(%bgBrowseUsed)
!  Past the page. Same borrowed-view problem the totals have: the view is
!  shared, so moving it moves the record buffer the browse reads from. Take the
!  position first and put it back after, and a NEXT on the restored position
!  reloads the record the browse was sitting on.
  IF %bgFitScanU > 0
    LOOP c = 1 TO %bgObject:Cols
      IF ~%bgObject:IFld[c] AND %bgObject:Col[c]
        nm[c] = CLIP(WHO(%bgQueueUsed,%bgObject:Fld[c]))
      END
    END
!  A view that is not going yet gives back nothing, which is the cheapest way
!  to ask whether there is anything to walk.
    sav = POSITION(%bgBrowseUsed.View)
    IF sav
      n = 0
      SET(%bgBrowseUsed.View)
      LOOP
        NEXT(%bgBrowseUsed.View)
        IF ERRORCODE() THEN BREAK.
        n += 1
        IF n > %bgFitScanU THEN BREAK.
        LOOP c = 1 TO %bgObject:Cols
          IF ~nm[c] THEN CYCLE.
          IF %bgObject:Pic[c]
            txt = CLIP(LEFT(FORMAT(EVALUATE(nm[c]),CLIP(%bgObject:Pic[c]))))
          ELSE
            txt = CLIP(LEFT(EVALUATE(nm[c])))
          END
          IF LEN(txt) > LEN(cand[c]) THEN cand[c] = txt.
        END
      END
      RESET(%bgBrowseUsed.View,sav)
      NEXT(%bgBrowseUsed.View)
      LOOP c = 1 TO %bgObject:Cols
        IF ~cand[c] THEN CYCLE.
        %bgObject:Meas{PROP:Text} = cand[c]
        w = %bgObject:Meas{PROP:Width}
        IF w > best[c] THEN best[c] = w.
      END
    END
  END
#ENDIF
  0{PROP:Pixels} = sp
!  A HIDDEN COLUMN STAYS HIDDEN. Its width is zero because somebody said so,
!  and sizing it to its content is a way of un-hiding it behind their back.
  LOOP c = 1 TO %bgObject:Cols
    lc = %bgObject:Col[c]
    IF ~lc THEN CYCLE.
    IF %bgList{PROPLIST:Width,lc} < 1 THEN CYCLE.
    IF %bgObject:IFld[c]
      w = BG:FitBox
    ELSE
      w = best[c] + BG:FitPad
    END
    IF w < BG:FitMin THEN w = BG:FitMin.
    IF w > BG:FitMax THEN w = BG:FitMax.
    %bgList{PROPLIST:Width,lc} = w / 2                      ! the LIST stores dialog units
  END
!  The same sequence opening the window runs, and in that order. Reset used to
!  keep a shorter version of it and the two drifted apart; there is no reason
!  to start a third.
  DO BG:Columns:%bgObject
  DO BG:Rows:%bgObject
  DO BG:Items:%bgObject
  d2g_Resize(%bgObject:G)
  DO BG:Fill:%bgObject
  d2g_PaintNow(%bgObject:G)
#ELSE
  EXIT
#ENDIF

BG:Sums:%bgObject ROUTINE
!  Add up every record the browse SHOWS. Not the page - the page is fourteen
!  rows and a total of fourteen rows is not a total of anything - and not the
!  file either, because the browse may be filtered or range limited and the
!  number has to agree with what is on screen.
!
!  So it walks the browse's own VIEW, which is the only thing that already
!  knows the filter, the range and the order.
!
!  AND WALKING IT DISTURBS THE BROWSE. The view is shared: moving it moves the
!  record buffer the browse reads from and leaves its position somewhere else.
!  BG:Values ran into the same wall and answers it by re-applying the filters
!  afterwards. This one is cheaper about it: the position is taken before and
!  put back after, and a NEXT on the restored position reloads the record the
!  browse was sitting on - which is the idiom ABC itself uses
!  (RESET(View,POSITION(View)) followed by NEXT).
#IF(%bgTotals)
#IF(%bgBrowseUsed)
  DATA
i   LONG,AUTO
sav STRING(1024)
  CODE
  IF ~%bgObject:G THEN EXIT.
  LOOP i = 1 TO %bgObject:Cols
    %bgObject:Acc[i] = 0
  END
  %bgObject:SumN = 0
#IF(%bgDiag)
  IF ~%bgObject:Freq[1]
    bgApi_QueryPerfFreq(ADDRESS(%bgObject:Freq[1]))
  END
  bgApi_QueryPerfCount(ADDRESS(%bgObject:T1[1]))
#ENDIF
!  NOT BEFORE THE VIEW IS LIVE. Called while the window is still opening, the
!  browse has not opened its view yet and the walk reads nothing at all - a
!  total of zero, arrived at honestly and completely wrong. POSITION on a view
!  that is not going gives back nothing, which is the cheapest way to ask.
  sav = POSITION(%bgBrowseUsed.View)
  IF ~sav THEN EXIT.                                        ! still due, try again later
  %bgObject:SumDue = 0
  SET(%bgBrowseUsed.View)
  LOOP
    NEXT(%bgBrowseUsed.View)
    IF ERRORCODE() THEN BREAK.
    %bgObject:SumN += 1
!  A cap, so a browse pointed at a very large table cannot lock the program up
!  while it counts. Reaching it means the total is short, and saying so is the
!  least this can do - a number that is quietly wrong is worse than none.
    IF %bgObject:SumN > BG:MaxSum THEN BREAK.
    LOOP i = 1 TO %bgObject:Cols
      IF %bgObject:Sum[i]
        %bgObject:Acc[i] += EVALUATE(%bgObject:SumNm[i])
      END
    END
  END
!  Back where the browse left it, and the record buffer with it.
  IF sav
    RESET(%bgBrowseUsed.View,sav)
    NEXT(%bgBrowseUsed.View)
  END
#IF(%bgDiag)
  bgApi_QueryPerfCount(ADDRESS(%bgObject:T2[1]))
  IF %bgObject:Freq[1] >= 1000000 AND %bgObject:T2[1] >= %bgObject:T1[1]
    BG_Log('%Procedure %bgObject totales: ' & %bgObject:SumN & ' registros en '   |
         & INT((%bgObject:T2[1] - %bgObject:T1[1]) / (%bgObject:Freq[1] / 1000)) & ' ms')
  END
#ENDIF
  LOOP i = 1 TO %bgObject:Cols
    IF %bgObject:Sum[i]
      %bgObject:Cell = CLIP(LEFT(FORMAT(%bgObject:Acc[i],CLIP(%bgObject:Pic[i]))))
      IF %bgObject:SumN > BG:MaxSum THEN %bgObject:Cell = '>' & CLIP(%bgObject:Cell).
    ELSE
      %bgObject:Cell = ''
    END
    d2g_FootCell(%bgObject:G,i - 1,%bgObject:Cell)
  END
  d2g_Repaint(%bgObject:G)
#ELSE
!  Without the browse object there is no view to walk, and the file on its own
!  would ignore the filter - a total that does not match the rows above it.
  EXIT
#ENDIF
#ELSE
  EXIT
#ENDIF
BG:Find:%bgObject ROUTINE
!  Texto libre. En esta columna, o en todas si el usuario lo pide.
!
!  No barre el archivo: arma una expresion y se la da al browse como cualquier
!  otro filtro, asi que cuesta lo que cuesta un filtro y convive con los demas -
!  se acumula por columna, lo limpia Limpiar este filtro, y prende el mismo
!  embudo en el encabezado.
!
!  Una columna de texto se busca CONTENIENDO y sin distinguir mayusculas; una
!  numerica, por igualdad, porque UPPER de un numero no significa nada y
!  contener no es lo que nadie espera de un importe. Si lo tipeado no es un
!  numero, las columnas numericas simplemente no participan.
#IF(%bgFilterTextU)
  DATA
FTxt STRING(60)
FAll BYTE
FW   WINDOW('%bgTFindTitle'),AT(,,240,124),GRAY,SYSTEM,CENTER,FONT('Segoe UI',9)
       STRING('%bgTFindHint'),AT(8,7,224,18),USE(?FHint),TRN
       PROMPT('%bgTFindLbl'),AT(8,32,224,10),USE(?FLbl)
       ENTRY(@s60),AT(8,44,224,13),USE(FTxt)
       CHECK('%bgTFindAll'),AT(8,66,224,10),USE(FAll)
       PANEL,AT(0,98,240,26),BEVEL(1)
       BUTTON('%bgTOk'),AT(124,103,54,14),LEFT,ICON('waok.ico'),FONT(,,00235C23h),USE(?FOk),DEFAULT
       BUTTON('%bgTCancel'),AT(180,103,54,14),LEFT,ICON('wacancel.ico'),FONT(,,1600B2h),USE(?FCancel)
     END
i    LONG,AUTO
nm   CSTRING(65)
up   CSTRING(61)
one  CSTRING(201)
expr CSTRING(1025)
ok   LONG
  CODE
  FTxt = ''
  FAll = 0
  ok   = 0
  OPEN(FW)
  ACCEPT
    CASE ACCEPTED()
    OF ?FOk
      ok = 1
      POST(EVENT:CloseWindow)
    OF ?FCancel
      POST(EVENT:CloseWindow)
    END
  END
  CLOSE(FW)
!  ARMADO Y APLICADO CON LA VENTANA YA CERRADA. Un equate de campo se resuelve
!  contra la ventana ACTUAL, y mientras este dialogo estaba abierto la actual era
!  el - cualquier %bgList{...} escrito ahi adentro habria ido a parar a un control
!  de esta ventanita, sin quejarse y sin efecto.
  IF ~ok THEN EXIT.
  up = UPPER(CLIP(LEFT(FTxt)))
  IF ~up THEN EXIT.
  expr = ''
  LOOP i = 1 TO %bgObject:Cols
    IF ~FAll AND i <> %bgObject:SortCol + 1 THEN CYCLE.
    IF %bgObject:IFld[i] THEN CYCLE.                          ! una casilla no lleva texto
    nm = CLIP(WHO(%bgQueueUsed,%bgObject:Fld[i]))
    IF ~nm THEN CYCLE.
    one = ''
    IF %bgObject:Num[i]
      IF NUMERIC(up)
        one = CLIP(nm) & ' = ' & CLIP(up)
      END
    ELSE
      one = 'INSTRING(''' & BG_Quote(up) & ''',UPPER(' & CLIP(nm) & '),1,1)'
    END
    IF ~one THEN CYCLE.
    IF LEN(CLIP(expr)) + LEN(CLIP(one)) + 4 > BG:MaxExpr THEN BREAK.
!  EN UNA SOLA EXPRESION, y no en dos pasos. Separarlo era:
!
!      IF expr THEN expr = CLIP(expr) & ' OR '.
!      expr = CLIP(expr) & CLIP(one)
!
!  ...y el segundo CLIP se come el espacio que acababa de poner el primero. El
!  filtro sale con 'OR' pegado a lo que sigue - ORINSTRING - que el evaluador
!  lee como un identificador solo, y la vista se abre con
!  'BIND has not been called for ORINSTRING' y los filtros ignorados.
!
!  Solo aparecia buscando en varias columnas: con una sola no hay ningun OR que
!  pegar.
    IF expr
      expr = CLIP(expr) & ' OR ' & CLIP(one)
    ELSE
      expr = CLIP(one)
    END
  END
!  Ninguna columna aplicable: la unica del menu es numerica y lo tipeado no es un
!  numero, o no hay nombres de campo. Decirlo, no quedarse quieto.
  IF ~expr
    MESSAGE('%bgTFindNone','BrowseGrid',ICON:Asterisk)
    EXIT
  END
!  Se guarda en la ranura de la columna DESDE LA QUE SE ABRIO el menu, aunque la
!  busqueda haya sido en todas: asi se acumula, se limpia y se señala como
!  cualquier otro filtro, en vez de ser una categoria aparte que despues nadie
!  sabe donde apagar.
#IF(%bgDiag)
!  LA EXPRESION TAL CUAL SE ARMO, antes de que la vea nadie. Discrimina de una:
!  si aparece 'ORINSTRING' pegado, esta corriendo codigo viejo; si aparece
!  'OR INSTRING' separado y falla igual, el problema no es el armado sino algun
!  campo que la vista no tiene bindeado, y el mensaje va a nombrarlo.
  BG_Log('%Procedure %bgObject buscar: cols=' & %bgObject:Cols & ' todas=' &  |
         FAll & ' [' & CLIP(expr) & ']')
#ENDIF
  %bgObject:ColFilt[%bgObject:SortCol + 1] = '(' & CLIP(expr) & ')'
  d2g_FilterOn(%bgObject:G,%bgObject:SortCol,1)
  d2g_PaintNow(%bgObject:G)
  DO BG:Filter:%bgObject
#ELSE
  EXIT
#ENDIF
BG:Values:%bgObject ROUTINE
!  Excel's checklist: every value in this column, tick the ones to keep.
!
!  The field is known only by NAME - WHO() off the browse queue - so the values
!  are read with EVALUATE(), which resolves a name against whatever is bound.
!  ABC binds the whole record buffer (FileManager.BindFields), and the proof it
!  is already bound is that the filter expressions built from the same names
!  work at all.
!
!  Reading the file moves its record buffer, which the browse shares. That is
!  why this always finishes by re-applying the filters: the browse re-reads and
!  is put back where it belongs, whether values were chosen or not.
#IF(%bgFilterBtnU AND %bgFileUsed AND %bgFilterValsU)
  DATA
VQ   QUEUE
Mark   STRING(4)                                              ! shown - see the note on ChQ
Val    STRING(64)                                             ! shown, con el picture puesto
On     BYTE                                                   ! not shown
Raw    STRING(64)                                             ! not shown - con lo que se filtra
     END
VW   WINDOW('%bgTValues'),AT(,,200,250),GRAY,SYSTEM,CENTER,FONT('Segoe UI',9)
       STRING('%bgTValsHint'),AT(8,7,184,18),USE(?VHint),TRN
       LIST,AT(8,28,184,168),USE(?VList),FROM(VQ),VSCROLL,                     |
            FORMAT('22C~%bgTKeep~@s4@158L(2)~%bgTValue~@s64@'),ALRT(SpaceKey)
       BUTTON('%bgTAll'),AT(8,202,52,15),FONT(,,00A00000h),USE(?VAll)
       BUTTON('%bgTNone'),AT(64,202,52,15),FONT(,,00A00000h),USE(?VNone)
       PANEL,AT(0,224,200,26),BEVEL(1)
       BUTTON('%bgTOk'),AT(84,229,54,14),LEFT,ICON('waok.ico'),FONT(,,00235C23h),USE(?VOk),DEFAULT
       BUTTON('%bgTCancel'),AT(140,229,54,14),LEFT,ICON('wacancel.ico'),FONT(,,1600B2h),USE(?VCancel)
     END
nm   CSTRING(65)
v    CSTRING(65)
d    CSTRING(65)
pic  STRING(32)
one  CSTRING(201)
expr CSTRING(1025)
n    LONG,AUTO
i    LONG,AUTO
on   LONG,AUTO
ge   LONG
ae   LONG
off  LONG,AUTO
  CODE
  nm  = CLIP(WHO(%bgQueueUsed,%bgObject:Fld[%bgObject:SortCol + 1]))
  pic = %bgObject:Pic[%bgObject:SortCol + 1]
#IF(%bgDiag)
!  EN LA ENTRADA, antes de cualquier salida. Las sondas de mas adentro no
!  sirven para diagnosticar una rutina que se va antes de llegar a ellas.
  BG_Log('%Procedure %bgObject valores: entra. sortcol=' & %bgObject:SortCol &  |
         ' cols=' & %bgObject:Cols & ' fld=' & %bgObject:Fld[%bgObject:SortCol + 1] & |
         ' nm=[' & CLIP(nm) & ']')
#ENDIF
!  SIN NOMBRE DE CAMPO no hay nada que buscar - y salir callado deja la
!  impresion de que la opcion no hace nada, que es como se ve un EXIT y como
!  se ve un error.
  IF ~nm
    MESSAGE('%bgTNoField','BrowseGrid',ICON:Asterisk)
    EXIT
  END
  FREE(VQ)
!  EN CERO, A MANO. En Clarion AUTO quiere decir SIN INICIALIZAR: la variable
!  se reserva en el stack y arranca con lo que hubiera ahi. Y n gobierna las
!  tres decisiones de este bucle - si ya se leyo algo, si se paso del tope, y
!  si esta es la primera vuelta - asi que con basura mayor al tope corta en la
!  primera lectura y la lista queda vacia despues de haber abierto el archivo.
!
!  Falla o no segun lo que haya dejado el stack, que es por que este camino
!  puede andar en una maquina y no en otra, o andar hasta que cambia el codigo
!  de al lado.
  n = 0
  SET(%bgFileUsed)
  LOOP
    NEXT(%bgFileUsed)
    IF ERRORCODE()
#IF(%bgDiag)
!  POR QUE se corto. Sin esto, un archivo que no esta abierto, uno vacio y un
!  campo que no se puede leer dan los tres el mismo resultado: ningun valor y
!  ninguna explicacion.
      IF ~n
        BG_Log('%Procedure %bgObject valores: 0 registros. campo=[' & CLIP(nm) & |
               '] archivo=[%bgFileUsed] errorcode=' & ERRORCODE() & ' ' & ERROR())
      END
#ENDIF
      BREAK
    END
    n += 1
    IF n > BG:MaxScan THEN BREAK.
!  LO QUE SE MUESTRA Y LO QUE SE COMPARA NO SON LO MISMO. El campo guarda su
!  valor crudo, y para una fecha eso es el numero de dias que Clarion lleva por
!  dentro: la lista ofrecia 81234 en vez de 25/12/2026. Se le pone el picture de
!  la columna para mostrarlo - el mismo que usa el llenado, o seria un texto que
!  nadie vio nunca en el grid.
!
!  Pero el filtro tiene que seguir comparando contra el CRUDO, porque es lo que
!  hay en el campo. Filtrar por '25/12/2026' contra un long no encuentra nada, y
!  no encuentra nada sin dar error: la lista queda vacia y parece que no hubiera
!  registros.
    v = CLIP(LEFT(EVALUATE(nm)))
    IF pic
      d = CLIP(LEFT(FORMAT(EVALUATE(nm),CLIP(pic))))
    ELSE
      d = v
    END
!  Y SE DEDUPLICA POR EL CRUDO, no por lo que se ve. Un picture puede perder
!  informacion - dos importes distintos redondean al mismo texto - y agrupar por
!  el texto dejaria fuera las filas del otro valor sin decirlo.
    VQ.Raw = v
    GET(VQ,+VQ.Raw)                                           ! sorted, so this dedupes as it goes
    ge = ERRORCODE()
!  ES DUPLICADO SOLO SI LO QUE VOLVIO ES ESTE VALOR. Preguntarle nada mas al
!  ERRORCODE es confiar en que un GET por clave sobre una cola siempre falle
!  cuando no hay coincidencia exacta; si vuelve sin error con OTRO registro,
!  la condicion no se cumple nunca, no se agrega nada nunca, y la lista
!  termina vacia despues de haber leido el archivo entero.
    IF ge OR VQ.Raw <> v
      VQ.Raw  = v
      VQ.Val  = d
      VQ.On   = 1
      VQ.Mark = ' X'
      ADD(VQ,+VQ.Raw)
      ae = ERRORCODE()
      IF RECORDS(VQ) >= BG:MaxVals THEN BREAK.
    END
#IF(%bgDiag)
    IF n = 1
      BG_Log('%Procedure %bgObject valores: 1a lectura v=[' & CLIP(v) &        |
             '] get=' & ge & ' add=' & ae & ' recs=' & RECORDS(VQ))
    END
#ENDIF
  END
  IF ~RECORDS(VQ)
    DO BG:Filter:%bgObject                                    ! put the browse back regardless
    MESSAGE('%bgTNoValues','BrowseGrid',ICON:Asterisk)
    EXIT
  END
#IF(%bgDiag)
  BG_Log('%Procedure %bgObject valores: ' & n & ' registros leidos, ' &        |
         RECORDS(VQ) & ' distintos. campo=[' & CLIP(nm) & ']')
#ENDIF
  OPEN(VW)
  VW{PROP:Text} = '%bgTValuesIn ' & CLIP(nm)
  ACCEPT
  IF EVENT() = EVENT:AlertKey AND KEYCODE() = SpaceKey AND FIELD() = ?VList
    GET(VQ,CHOICE(?VList))
    IF ~ERRORCODE()
      VQ.On   = 1 - VQ.On
      VQ.Mark = CHOOSE(VQ.On = 1, ' X', '')
      PUT(VQ)
      DISPLAY(?VList)
    END
    CYCLE
  END
    CASE ACCEPTED()
    OF ?VList
      GET(VQ,CHOICE(?VList))
      IF ~ERRORCODE()
        VQ.On   = 1 - VQ.On
        VQ.Mark = CHOOSE(VQ.On = 1, ' X', '')
        PUT(VQ)
        DISPLAY(?VList)
      END
    OF ?VAll
    OROF ?VNone
      LOOP i = 1 TO RECORDS(VQ)
        GET(VQ,i)
        VQ.On   = CHOOSE(ACCEPTED() = ?VAll, 1, 0)
        VQ.Mark = CHOOSE(VQ.On = 1, ' X', '')
        PUT(VQ)
      END
      DISPLAY(?VList)
    OF ?VOk
!  CONTAR PRIMERO, ARMAR DESPUES. Marcar 197 de 200 valores y excluir los tres
!  que sobran es lo mismo, y una de las dos expresiones es diez veces mas
!  corta que la otra. Se elige la corta: los tildados con OR, o los
!  destildados con <> y AND.
!
!  Lo anterior armaba siempre la forma larga y dejaba de agregar al llegar a
!  120 caracteres, sin decir nada: el filtro que se aplicaba era mas angosto
!  que lo que el usuario habia elegido, y las filas que faltaban no faltaban
!  por ningun motivo visible.
      on = 0
      off = 0
      LOOP i = 1 TO RECORDS(VQ)
        GET(VQ,i)
        IF VQ.On THEN on += 1 ELSE off += 1.
      END
      IF ~off OR ~on                                          ! all of them, or none: no filter
        %bgObject:ColFilt[%bgObject:SortCol + 1] = ''
        d2g_FilterOn(%bgObject:G,%bgObject:SortCol,0)
      ELSE
        expr = ''
        LOOP i = 1 TO RECORDS(VQ)
          GET(VQ,i)
          IF (on <= off AND ~VQ.On) OR (on > off AND VQ.On) THEN CYCLE.
          IF LEN(CLIP(expr)) > BG:MaxExpr THEN BREAK.         ! no entra: se avisa abajo
!  EN UNA SOLA EXPRESION. El mismo tropiezo que la busqueda por texto: poner el
!  separador en un paso y el termino en otro deja que el segundo CLIP se coma el
!  espacio recien puesto, y el filtro sale con ORCUE:FECHA pegado - un
!  identificador que nadie bindeo. Latente aca porque hacen falta tres valores
!  distintos y dos tildados para que aparezca un solo OR.
          one = CLIP(nm) & CHOOSE(on <= off,' = ',' <> ')                       |
              & '''' & BG_Quote(CLIP(VQ.Raw)) & ''''
          IF expr
            expr = CLIP(expr) & CHOOSE(on <= off,' OR ',' AND ') & CLIP(one)
          ELSE
            expr = CLIP(one)
          END
        END
        IF LEN(CLIP(expr)) > BG:MaxExpr
          MESSAGE('%bgTTooMany','BrowseGrid',ICON:Exclamation)
        ELSE
          %bgObject:ColFilt[%bgObject:SortCol + 1] = '(' & CLIP(expr) & ')'
          d2g_FilterOn(%bgObject:G,%bgObject:SortCol,1)
        END
      END
      POST(EVENT:CloseWindow)
    OF ?VCancel
      POST(EVENT:CloseWindow)
    END
  END
  CLOSE(VW)
  d2g_PaintNow(%bgObject:G)
  DO BG:Filter:%bgObject
#ELSE
!  Without a file named on the prompts there is nothing to read the values out
!  of - the grid only ever sees a page of the queue.
  MESSAGE('%bgTNoFile','BrowseGrid',ICON:Asterisk)
#ENDIF

BG:Chooser:%bgObject ROUTINE
!  Which columns to show. Hiding one is not a grid idea at all - a LIST column
!  of zero width is already invisible to Clarion, and BG:Columns already skips
!  those - so this only has to set widths and read them back. The width it had
!  is remembered so unhiding puts it back where it was rather than at some
!  default, and the layout store keeps that across runs for free, because it
!  keys on LIST column number.
#IF(%bgChooserU)
  DATA
!  ORDER MATTERS. A LIST with FROM(queue) hands its format columns the queue's
!  fields in the order they are declared - there is no naming of one to the
!  other - so the fields that are shown have to come first. Declared as
!  Mark, On, Name the second column showed On, which is why every row read "1".
ChQ  QUEUE
Mark   STRING(4)                                              ! shown: plain text, unmistakable
#IF(%bgTotals)
Tot    STRING(4)                                              ! shown - y ANTES de Name
#ENDIF
Name   STRING(64)                                             ! shown
On     BYTE                                                   ! and the rest are not
#IF(%bgTotals)
TotOn  BYTE
#ENDIF
Col    LONG
Wid    LONG
     END
#IF(%bgTotals)
ChW  WINDOW('%bgTColsTitle'),AT(,,236,272),GRAY,SYSTEM,CENTER,FONT('Segoe UI',9)
       STRING('%bgTColsHint'),AT(8,7,220,18),USE(?ChHint),TRN
       LIST,AT(8,28,220,168),USE(?ChList),FROM(ChQ),VSCROLL,                   |
            FORMAT('22C~%bgTShowHdr~@s4@26C~%bgTTotHdr~@s4@164L(2)~%bgTColumnHdr~@s64@'),ALRT(SpaceKey)
       BUTTON('%bgTShowBtn'),AT(8,202,52,14),FONT(,,00A00000h),USE(?ChShow)
       BUTTON('%bgTHideBtn'),AT(64,202,52,14),FONT(,,00A00000h),USE(?ChHide)
       BUTTON('%bgTAll'),AT(120,202,52,14),FONT(,,00A00000h),USE(?ChAll)
       BUTTON('%bgTNone'),AT(176,202,52,14),FONT(,,00A00000h),USE(?ChNone)
       BUTTON('%bgTTotBtn'),AT(8,221,64,14),FONT(,,00A00000h),USE(?ChTot)
       PANEL,AT(0,246,236,26),BEVEL(1)
       BUTTON('%bgTOk'),AT(120,251,54,14),LEFT,ICON('waok.ico'),FONT(,,00235C23h),USE(?ChOk),DEFAULT
       BUTTON('%bgTCancel'),AT(176,251,54,14),LEFT,ICON('wacancel.ico'),FONT(,,1600B2h),USE(?ChCancel)
     END
#ELSE
ChW  WINDOW('%bgTColsTitle'),AT(,,236,252),GRAY,SYSTEM,CENTER,FONT('Segoe UI',9)
       STRING('%bgTColsHint'),AT(8,7,220,18),USE(?ChHint),TRN
       LIST,AT(8,28,220,168),USE(?ChList),FROM(ChQ),VSCROLL,                   |
            FORMAT('22C~%bgTShowHdr~@s4@190L(2)~%bgTColumnHdr~@s64@'),ALRT(SpaceKey)
       BUTTON('%bgTShowBtn'),AT(8,202,52,14),FONT(,,00A00000h),USE(?ChShow)
       BUTTON('%bgTHideBtn'),AT(64,202,52,14),FONT(,,00A00000h),USE(?ChHide)
       BUTTON('%bgTAll'),AT(120,202,52,14),FONT(,,00A00000h),USE(?ChAll)
       BUTTON('%bgTNone'),AT(176,202,52,14),FONT(,,00A00000h),USE(?ChNone)
       PANEL,AT(0,226,236,26),BEVEL(1)
       BUTTON('%bgTOk'),AT(120,251,54,14),LEFT,ICON('waok.ico'),FONT(,,00235C23h),USE(?ChOk),DEFAULT
       BUTTON('%bgTCancel'),AT(176,251,54,14),LEFT,ICON('wacancel.ico'),FONT(,,1600B2h),USE(?ChCancel)
     END
#ENDIF
c    LONG,AUTO
ex   LONG,AUTO
fld  LONG,AUTO
wid  LONG,AUTO
was  CSTRING(32)
head CSTRING(129)
p    LONG,AUTO
ok   LONG,AUTO
  CODE
  FREE(ChQ)
  LOOP c = 1 TO 512
    ex = %bgList{PROPLIST:Exists,c}
    IF ~ex THEN BREAK.
    fld = %bgList{PROPLIST:FieldNo,c}
    IF ~fld THEN CYCLE.                                       ! a decoration, not a column
    wid = %bgList{PROPLIST:Width,c}
    head = CLIP(%bgList{PROPLIST:Header,c})
    IF ~head
      head = CLIP(%bgList{PROPLIST:Header + PROPLIST:Group,c})
    END
    LOOP p = 1 TO LEN(head)
      IF head[p] = '|' THEN head[p] = ' '.
    END
    ChQ.Name = CLIP(LEFT(head))
!  In a grouped format most columns carry no heading of their own - the group's
!  heading stands over the lot - so this list came out blank, and "Column 7" is
!  no better. WHO() answers with the field the column shows, STU:LastName,
!  because an ABC browse queue labels its fields with the file fields they came
!  from. It is the same thing that lets the grid build a filter expression.
    IF ~ChQ.Name
      ChQ.Name = CLIP(WHO(%bgQueueUsed,fld))
    END
    IF ~ChQ.Name THEN ChQ.Name = 'Column ' & c.
    ChQ.Col  = c
    ChQ.On   = CHOOSE(wid > 0, 1, 0)
    ChQ.Mark = CHOOSE(ChQ.On = 1, ' X', '')
#IF(%bgTotals)
!  El estado que tiene HOY. Los indices no son el mismo: ChQ.Col es la columna
!  del LIST y Sum[] va por columna del grid, asi que hay que buscarla.
    ChQ.TotOn = 0
    LOOP p = 1 TO %bgObject:Cols
      IF %bgObject:Col[p] = c
        ChQ.TotOn = %bgObject:Sum[p]
        BREAK
      END
    END
    ChQ.Tot = CHOOSE(ChQ.TotOn = 1, ' X', '')
#ENDIF
    IF wid > 0
      ChQ.Wid = wid
    ELSE                                                      ! hidden: what was it before?
      was = CLIP(INIMgr.TryFetch('BrowseGrid:%Procedure:%bgObject','h' & c))
      ChQ.Wid = CHOOSE(was <> '', was, 40)
    END
    ADD(ChQ)
  END
  IF ~RECORDS(ChQ) THEN EXIT.
  OPEN(ChW)
  ACCEPT
!  A Clarion LIST only raises ACCEPTED on a double click or Enter, so a single
!  click on a row did nothing at all and the dialog looked inert. Space toggles
!  the highlighted row, and there are buttons for people who would rather press
!  one - a list that appears to ignore you is worse than no list.
  IF EVENT() = EVENT:AlertKey AND KEYCODE() = SpaceKey AND FIELD() = ?ChList
    GET(ChQ,CHOICE(?ChList))
    IF ~ERRORCODE()
      ChQ.On   = 1 - ChQ.On
      ChQ.Mark = CHOOSE(ChQ.On = 1, ' X', '')
      PUT(ChQ)
      DISPLAY(?ChList)
    END
    CYCLE
  END
    CASE ACCEPTED()
    OF ?ChList
    OROF ?ChShow
    OROF ?ChHide
      GET(ChQ,CHOICE(?ChList))
      IF ~ERRORCODE()
        CASE ACCEPTED()
        OF ?ChShow ; ChQ.On = 1
        OF ?ChHide ; ChQ.On = 0
        ELSE       ; ChQ.On = 1 - ChQ.On                      ! double click or Enter
        END
        ChQ.Mark = CHOOSE(ChQ.On = 1, ' X', '')
        PUT(ChQ)
        DISPLAY(?ChList)
      END
#IF(%bgTotals)
    OF ?ChTot
      GET(ChQ,CHOICE(?ChList))
      IF ~ERRORCODE()
        ChQ.TotOn = 1 - ChQ.TotOn
        ChQ.Tot   = CHOOSE(ChQ.TotOn = 1, ' X', '')
        PUT(ChQ)
        DISPLAY(?ChList)
      END
#ENDIF
    OF ?ChAll
    OROF ?ChNone
      LOOP p = 1 TO RECORDS(ChQ)
        GET(ChQ,p)
        ChQ.On   = CHOOSE(ACCEPTED() = ?ChAll, 1, 0)
        ChQ.Mark = CHOOSE(ChQ.On = 1, ' X', '')
        PUT(ChQ)
      END
      DISPLAY(?ChList)
    OF ?ChOk
      wid = 0
      LOOP p = 1 TO RECORDS(ChQ)                              ! is anything left to look at?
        GET(ChQ,p)
        IF ChQ.On THEN wid += 1.
      END
      IF ~wid
        MESSAGE('%bgTOneCol','%bgTColsTitle',ICON:Exclamation)
        CYCLE
      END
      ok = 1                                                  ! decided; applied further down
      POST(EVENT:CloseWindow)
    OF ?ChCancel
      CLOSE(ChW)
      EXIT
    END
  END
  CLOSE(ChW)
  IF ~ok THEN EXIT.
!  APPLIED HERE, not in the button. A field equate is resolved against whatever
!  window is CURRENT, and while this dialog was open that was the dialog - so
!  every ?Browse:1{PROPLIST:Width} written inside the ACCEPT loop above went to
!  a control of the Columns window instead of to the browse, and did nothing at
!  all. Nothing complains: the write is legal, it simply lands somewhere else.
!  With the dialog closed the browse window is current again and the same lines
!  do what they read as.
  LOOP p = 1 TO RECORDS(ChQ)
    GET(ChQ,p)
    IF ChQ.On
      %bgList{PROPLIST:Width,ChQ.Col} = ChQ.Wid
    ELSE
!  Remember how wide it was before it went, so it comes back the same size.
      INIMgr.Update('BrowseGrid:%Procedure:%bgObject','h' & ChQ.Col,ChQ.Wid)
      %bgList{PROPLIST:Width,ChQ.Col} = 0
    END
  END
!  The columns are different now, so they have to be read again from scratch.
  DO BG:Columns:%bgObject
#IF(%bgTotals)
!  DESPUES de BG:Columns y no antes: esa rutina vuelve a decidir Sum[] por el
!  picture de cada columna, asi que aplicar la eleccion antes seria escribirla
!  para que la deteccion la pise medio segundo despues. Lo que el usuario
!  eligio manda sobre lo que el picture sugiere - esa es toda la idea de
!  poder elegirlo.
  LOOP p = 1 TO RECORDS(ChQ)
    GET(ChQ,p)
#IF(%bgRemember)
    INIMgr.Update('BrowseGrid:%Procedure:%bgObject','t' & ChQ.Col,ChQ.TotOn)
#ENDIF
    LOOP c = 1 TO %bgObject:Cols
      IF %bgObject:Col[c] = ChQ.Col
        %bgObject:Sum[c] = ChQ.TotOn
        IF ChQ.TotOn AND ~%bgObject:SumNm[c]
          %bgObject:SumNm[c] = CLIP(WHO(%bgQueueUsed,%bgObject:Fld[c]))
          IF ~%bgObject:SumNm[c] THEN %bgObject:Sum[c] = 0.
        END
        BREAK
      END
    END
  END
  %bgObject:SumDue = 1
#ENDIF
  DO BG:Rows:%bgObject
  d2g_Resize(%bgObject:G)
  DO BG:Fill:%bgObject
  d2g_PaintNow(%bgObject:G)
#ELSE
  EXIT
#ENDIF

BG:RecallT:%bgObject ROUTINE
!  Que columnas totaliza el usuario, por encima de lo que sugiere el picture.
!  Corre DESPUES de BG:Columns, que es quien pone la sugerencia.
#IF(%bgTotals AND %bgRemember)
  DATA
i   LONG,AUTO
val CSTRING(8)
  CODE
  LOOP i = 1 TO %bgObject:Cols
    val = CLIP(INIMgr.TryFetch('BrowseGrid:%Procedure:%bgObject','t' & %bgObject:Col[i]))
    IF val AND NUMERIC(val)
      %bgObject:Sum[i] = CHOOSE(val = '1', 1, 0)
      IF %bgObject:Sum[i] AND ~%bgObject:SumNm[i]
        %bgObject:SumNm[i] = CLIP(WHO(%bgQueueUsed,%bgObject:Fld[i]))
        IF ~%bgObject:SumNm[i] THEN %bgObject:Sum[i] = 0.
      END
    END
  END
#ELSE
  EXIT
#ENDIF

BG:Recall:%bgObject ROUTINE
!  Put remembered column widths back on the LIST BEFORE the grid reads them, so
!  there is one path that decides a width and the grid does not have to be told
!  twice. Keyed by LIST column number rather than by grid column, because a
!  hidden column is not in the grid's list at all and its width would otherwise
!  have nowhere to come back to.
#IF(%bgRemember)
  DATA
c   LONG,AUTO
ex  LONG,AUTO
val CSTRING(32)
  CODE
  LOOP c = 1 TO 512
    ex = %bgList{PROPLIST:Exists,c}
    IF ~ex THEN BREAK.
!  A stored 0 means "this column was hidden" and has to be honoured, not
!  skipped - skipping it is what made hiding a column last only until the
!  window was next opened.
!
!  TryFetch, not Fetch: Fetch ASSERTS when the entry is not there
!  (ABUTIL.CLW:697), so the first run after the section was cleared - or the
!  very first run of all - put up one assertion box per column. Worse, once
!  they were dismissed the empty answer went on to be applied as a width,
!  which is a width of nothing, and the browse opened with its columns gone.
!  Nothing remembered is REQUIRED to be there: that is what remembering is.
    val = CLIP(INIMgr.TryFetch('BrowseGrid:%Procedure:%bgObject','w' & c))
!  And it has to look like a width before it is used as one. NUMERIC() keeps
!  an INI that was hand-edited, truncated or written by an older version from
!  turning into a browse with no columns - the one state this template goes
!  out of its way to make impossible to get stuck in.
    IF val AND NUMERIC(val)
      %bgList{PROPLIST:Width,c} = val
    END
  END
#ELSE
  EXIT
#ENDIF

BG:RecallF:%bgObject ROUTINE
!  Filters are NOT restored, and any that were stored are thrown away here.
!
!  Widths are safe to put back: the worst a bad one can do is look wrong. A
!  filter is not. It is handed to ABC as an expression, and an expression that
!  will not parse is a run-time error - at window open, before there is anything
!  on screen to explain it. A filter stored by an earlier version of this
!  template therefore killed the application every time the window opened, and
!  went on doing it through every rebuild, because it was in the INI file and
!  not in the program.
!
!  Restoring them was also the wrong idea on its own merits. Someone who opens
!  a browse expects to see the records, not yesterday's filter with no
!  indication of why three quarters of the file is missing.
#IF(%bgRemember)
  DATA
i LONG,AUTO
  CODE
  LOOP i = 1 TO 512
    INIMgr.Update('BrowseGrid:%Procedure:%bgObject','f' & i,'')
  END
#ELSE
  EXIT
#ENDIF

BG:Remember:%bgObject ROUTINE
!  Written at Kill, so it costs nothing until the window closes.
#IF(%bgRemember)
  DATA
i   LONG,AUTO
c   LONG,AUTO
ex  LONG,AUTO
fld LONG,AUTO
  CODE
  IF ~%bgObject:G THEN EXIT.
!  EVERY column, not only the ones the grid is drawing. A hidden column is not
!  in the grid's list at all, so writing only those left its old width sitting
!  in the file - and BG:Recall put it back on the next open, which is a hidden
!  column coming back from the dead. Zero is a width too, and has to be stored
!  like one.
  LOOP c = 1 TO 512
    ex = %bgList{PROPLIST:Exists,c}
    IF ~ex THEN BREAK.
    fld = %bgList{PROPLIST:FieldNo,c}
    IF ~fld THEN CYCLE.
    INIMgr.Update('BrowseGrid:%Procedure:%bgObject','w' & c,%bgList{PROPLIST:Width,c})
  END
  LOOP i = 1 TO %bgObject:Cols                                ! the drawn ones, at grid precision
    IF ~%bgObject:Col[i] THEN CYCLE.
    INIMgr.Update('BrowseGrid:%Procedure:%bgObject','w' & %bgObject:Col[i], |
                  d2g_ColWidth(%bgObject:G,i - 1) / 2)
  END
#ELSE
  EXIT
#ENDIF

BG:Cover:%bgObject ROUTINE
!  Put the grid back over the LIST and draw it THIS INSTANT. Wanted any time
!  the LIST has had a reason to paint itself - taking the focus, being given a
!  new column width - because the clip style stops it owning the region's
!  pixels but does not stop it drawing into them.
#IF(%bgPopupU)
  IF ~%bgObject:G THEN EXIT.
  DO BG:Place:%bgObject
  d2g_Resize(%bgObject:G)
  d2g_PaintNow(%bgObject:G)
#ELSE
  EXIT
#ENDIF

BG:Right:%bgObject ROUTINE
!  Hand a right-click back to the browse. NOT by forwarding the click itself:
!  the grid's rows and the LIST's rows are not the same height, so the same
!  y would pick a different record. The row is worked out in the grid's own
!  geometry, the LIST is told to select it, and then the browse is sent
!  AppsKey - "show the menu for what is selected", which needs no coordinates
!  at all. ABC alerts AppsKey on the list alongside MouseRightUp and treats
!  the two identically, so Insert/Change/Delete behave exactly as they always
!  did, popup formatter and all.
#IF(%bgPopupU)
  DATA
rx SIGNED,AUTO
ry SIGNED,AUTO
rw SIGNED,AUTO
rh SIGNED,AUTO
sp LONG,AUTO
row LONG,AUTO
  CODE
  IF ~%bgObject:G THEN EXIT.
  sp = 0{PROP:Pixels}
  0{PROP:Pixels} = 1
  GETPOSITION(%bgObject:Rgn,rx,ry,rw,rh)
  row = d2g_HitRow(%bgObject:G,MOUSEY() - ry)
  0{PROP:Pixels} = sp
  IF row >= 0 AND row < RECORDS(%bgQueueUsed)                     ! on a row: take it with us
    %bgList{PROP:Selected} = row + 1
    %bgObject:Sel = row
    d2g_Select(%bgObject:G,row)
    d2g_Repaint(%bgObject:G)
  END
  SELECT(%bgList)
  POST(BG:Popup:%bgObject)
#ELSE
  EXIT
#ENDIF

BG:Tip:%bgObject ROUTINE
!  The whole value, but only when the column is too narrow to show it. A
!  tooltip that repeats what is already legible is noise, and one that appears
!  over every cell is worse than none.
!
!  Measured with the ruler control, in PIXELS - the grid keeps its widths in
!  pixels, and PROP:Width answers in dialog units unless it is asked otherwise.
!  Comparing the two without converting is the mistake that made the drop-down
!  rule do nothing, and it would silently halve the threshold here.
#IF(%bgTipsU)
  DATA
rx  SIGNED,AUTO
ry  SIGNED,AUTO
rw  SIGNED,AUTO
rh  SIGNED,AUTO
sp  LONG,AUTO
row LONG,AUTO
col LONG,AUTO
wid LONG,AUTO
  CODE
  IF ~%bgObject:G OR ~%bgObject:Meas THEN EXIT.
  IF %bgObject:RzCol OR %bgObject:VDrag OR %bgObject:HDrag THEN EXIT.  ! busy dragging
  sp = 0{PROP:Pixels}
  0{PROP:Pixels} = 1
  GETPOSITION(%bgObject:Rgn,rx,ry,rw,rh)
  row = d2g_HitRow(%bgObject:G,MOUSEY() - ry)
  col = d2g_HitCol(%bgObject:G,MOUSEX() - rx)
  0{PROP:Pixels} = sp
!  Once per cell, not once per pixel of travel. Without this the ruler would be
!  asked several hundred times a second for an answer that has not changed.
  IF row = %bgObject:TipRow AND col = %bgObject:TipCol THEN EXIT.
  %bgObject:TipRow = row
  %bgObject:TipCol = col
  %bgObject:Rgn{PROP:Tip} = ''
  IF row < 0 OR col < 0 OR col >= %bgObject:Cols THEN EXIT.   ! the header, or past the last
  IF row >= RECORDS(%bgQueueUsed) THEN EXIT.
  IF %bgObject:IFld[col + 1] THEN EXIT.                       ! a tick box says all it has to
  GET(%bgQueueUsed,row + 1)
  IF ERRORCODE() THEN EXIT.
  IF %bgObject:Pic[col + 1]
    %bgObject:TipTxt = CLIP(LEFT(FORMAT(WHAT(%bgQueueUsed,%bgObject:Fld[col + 1]), |
                                        CLIP(%bgObject:Pic[col + 1]))))
  ELSE
    %bgObject:TipTxt = CLIP(LEFT(WHAT(%bgQueueUsed,%bgObject:Fld[col + 1])))
  END
  IF ~%bgObject:TipTxt THEN EXIT.
  sp = 0{PROP:Pixels}
  0{PROP:Pixels} = 1
  %bgObject:Meas{PROP:Text} = %bgObject:TipTxt
  wid = %bgObject:Meas{PROP:Width}
  0{PROP:Pixels} = sp
!  Eight pixels of padding, the same four a side the cell is drawn with.
  IF wid > d2g_ColWidth(%bgObject:G,col) - 8
    %bgObject:Rgn{PROP:Tip} = %bgObject:TipTxt
  END
#ELSE
  EXIT
#ENDIF

BG:Double:%bgObject ROUTINE
!  Hand a double click back to the browse. The click itself is NOT forwarded:
!  the grid's rows and the LIST's rows are not the same height, so the same y
!  would land on a different record. The row is worked out in the grid's own
!  geometry, the LIST is told to select it, and only then is the browse sent
!  the double click - which needs no coordinates at all.
#IF(%bgDoubleU)
  DATA
rx SIGNED,AUTO
ry SIGNED,AUTO
rw SIGNED,AUTO
rh SIGNED,AUTO
sp LONG,AUTO
row LONG,AUTO
  CODE
  IF ~%bgObject:G THEN EXIT.
  sp = 0{PROP:Pixels}
  0{PROP:Pixels} = 1
  GETPOSITION(%bgObject:Rgn,rx,ry,rw,rh)
  row = d2g_HitRow(%bgObject:G,MOUSEY() - ry)
  0{PROP:Pixels} = sp
  IF row < 0 OR row >= RECORDS(%bgQueueUsed) THEN EXIT.       ! the header, or past the end
  %bgList{PROP:Selected} = row + 1
  %bgObject:Sel = row
  d2g_Select(%bgObject:G,row)
  d2g_Repaint(%bgObject:G)
  SELECT(%bgList)
  POST(BG:Dbl:%bgObject)
#ELSE
  EXIT
#ENDIF

BG:Sizing:%bgObject ROUTINE
!  Two jobs on one event. Dragging: widen or narrow the column under the
!  pointer, measured from where the drag STARTED rather than from the last
!  event - deltas lose their remainder and the column creeps away from the
!  pointer. Not dragging: show the sizing cursor when the edge is grabbable, so
!  the user can see there is something there. Only when it CHANGES, or the
!  cursor is reset on every mouse move and flickers.
#IF(%bgSizeable)
  DATA
rx SIGNED,AUTO
ry SIGNED,AUTO
rw SIGNED,AUTO
rh SIGNED,AUTO
sp LONG,AUTO
mx LONG,AUTO
my LONG,AUTO
col LONG,AUTO
wid LONG,AUTO
vp  LONG,AUTO
  CODE
  IF ~%bgObject:G THEN EXIT.
  sp = 0{PROP:Pixels}
  0{PROP:Pixels} = 1
  GETPOSITION(%bgObject:Rgn,rx,ry,rw,rh)
  mx = MOUSEX() - rx
  my = MOUSEY() - ry
  0{PROP:Pixels} = sp
#IF(%bgBarStyleU <> 'Windows')
  IF %bgObject:HDrag
    IF bgApi_GetAsyncKeyState(BG:VkLButton) >= 0
      %bgObject:HDrag = 0
      EXIT
    END
    %bgObject:ScrollX = d2g_HDrag(%bgObject:G,mx,%bgObject:HGrab)
    d2g_ScrollX(%bgObject:G,%bgObject:ScrollX)
    DO BG:Bars:%bgObject
    d2g_PaintNow(%bgObject:G)                                 ! sideways is ours: instant
    EXIT
  END
#ENDIF
  IF %bgObject:VDrag
!  THIS is what Windows' own scrollbar could not do. There is no modal loop
!  here - it is an ordinary mouse move - so ACCEPT runs, the browse is told to
!  scroll exactly as its own thumb would tell it, and by the time the pointer
!  has moved again the records are on screen. The thumb follows the POINTER
!  while the drag is on rather than the browse, so it cannot stutter.
    IF bgApi_GetAsyncKeyState(BG:VkLButton) >= 0
      %bgObject:VDrag = 0
      EXIT
    END
    vp = d2g_VDrag(%bgObject:G,my,%bgObject:VGrab)
    d2g_VBar(%bgObject:G,1,vp,BG:ThumbPct)
    IF vp <> %bgList{PROP:VScrollPos}
      %bgList{PROP:VScrollPos} = vp
      POST(EVENT:ScrollDrag,%bgList)                          ! ABC fetches, Reset redraws
    ELSE
      d2g_Repaint(%bgObject:G)
    END
    EXIT
  END
  IF %bgObject:RzCol
!  Windows answers with the high bit set while the button is down, and a SHORT
!  is signed, so "still held" is simply "negative". Clarion has no MOUSEDOWN,
!  and the mouse can be released off the grid, where no MouseUp ever arrives.
    IF bgApi_GetAsyncKeyState(BG:VkLButton) >= 0

      DO BG:SizeEnd:%bgObject
      EXIT
    END
    IF %bgObject:RzArmed
      IF ABS(mx - %bgObject:RzX) < BG:DragSlop THEN EXIT.      ! still just a click
      %bgObject:RzArmed = 0                                    ! it has moved: a real drag
    END
    wid = %bgObject:RzW + mx - %bgObject:RzX
!  Dragged shut. The width itself cannot go below the button, so what the
!  developer was reaching for - Excel's "drag it to nothing and it is hidden" -
!  was simply unreachable. The INTENT is caught here, before the clamp, and
!  acted on when the button comes up.
    %bgObject:RzHide = CHOOSE(wid < 8, 1, 0)
    IF wid < 16 THEN wid = 16.
    IF %bgObject:RzGrp
      d2g_SetGrpWidth(%bgObject:G,%bgObject:RzCol - 1,wid)    ! fields inside come with it
    ELSE
      d2g_SetWidth(%bgObject:G,%bgObject:RzCol - 1,wid)
    END
    DO BG:Bars:%bgObject                                      ! the columns are a different width now
    d2g_Repaint(%bgObject:G)
    EXIT
  END
  col = -1
  IF my < d2g_HdrHeight(%bgObject:G)
    col = d2g_HitEdge(%bgObject:G,mx)
  END
  IF col >= 0
    IF ~%bgObject:RzCur
      %bgObject:Rgn{PROP:Cursor} = CURSOR:SizeWE
      %bgObject:RzCur = 1
    END
  ELSIF %bgObject:RzCur
    %bgObject:Rgn{PROP:Cursor} = ''
    %bgObject:RzCur = 0
  END
#ELSE
  EXIT
#ENDIF

BG:SizeEnd:%bgObject ROUTINE
!  Put the new width back on the LIST as well. The browse goes on believing it
!  owns its own columns - anything that reads them, saves them or rebuilds the
!  grid from them then agrees with what is on screen.
#IF(%bgSizeable)
  DATA
c LONG,AUTO
  CODE
  %bgObject:VDrag = 0
  %bgObject:HDrag = 0
  IF ~%bgObject:RzCol THEN EXIT.
  IF %bgObject:RzArmed
!  It never moved, so it was a click on the heading after all - and a click on
!  a heading sorts. Nothing has been resized, so there is no width to write.
    %bgObject:RzArmed = 0
    %bgObject:RzCol   = 0
#IF(%bgSortHdr)
    IF %bgObject:SortCol >= 0
      DO BG:Sort:%bgObject
    END
#ENDIF
    EXIT
  END
  IF %bgObject:RzGrp
    DO BG:GrpBack:%bgObject                                   ! the whole group, fields and all
    %bgObject:RzGrp = 0
    %bgObject:RzCol = 0
    EXIT
  END
  c = %bgObject:Col[%bgObject:RzCol]
#IF(%bgChooserU)
  IF c AND %bgObject:RzHide AND %bgObject:Cols > 1            ! never the last one
!  Hidden by dragging it shut, the way Excel does. Its width is kept so
!  Columns... can put it back the size it was.
    INIMgr.Update('BrowseGrid:%Procedure:%bgObject','h' & c, |
                  d2g_ColWidth(%bgObject:G,%bgObject:RzCol - 1) / 2)
    %bgList{PROPLIST:Width,c} = 0
    %bgObject:RzHide  = 0
    %bgObject:RzCol   = 0
    %bgObject:RzArmed = 0
    DO BG:Columns:%bgObject
    DO BG:Rows:%bgObject
    d2g_Resize(%bgObject:G)
    DO BG:Fill:%bgObject
    d2g_PaintNow(%bgObject:G)
    EXIT
  END
#ENDIF
  %bgObject:RzHide = 0
  IF c
    %bgList{PROPLIST:Width,c} = d2g_ColWidth(%bgObject:G,%bgObject:RzCol - 1) / 2
!  Changing a LIST's format makes it redraw itself, and it comes back over the
!  grid when it does - the clip style and the stacking order both survive the
!  write, so it is the painting that gets through, not the ordering. Putting
!  the region back on top and repainting it undoes that in the same breath.
!  Nothing else in the drag touches the LIST, which is why it only ever
!  happened when the button came up.
    DO BG:Place:%bgObject
    d2g_Resize(%bgObject:G)
    d2g_PaintNow(%bgObject:G)
  END
  %bgObject:RzCol = 0
#ELSE
  EXIT
#ENDIF

BG:Fill:%bgObject ROUTINE
!  Push the browse's queue into the grid. This is every visible row and no
!  more, which is exactly what the queue holds - the grid is told nothing
!  about the file.
  DATA
i     LONG,AUTO
col   LONG,AUTO
rows  LONG,AUTO
fit   LONG,AUTO
sp    LONG,AUTO
dx    SIGNED,AUTO
dy    SIGNED,AUTO
dw    SIGNED,AUTO
dh    SIGNED,AUTO
first LONG,AUTO
full  LONG,AUTO
sel   LONG,AUTO
cf    LONG,AUTO
total LONG,AUTO
sp    LONG,AUTO
map   CSTRING(201)
  CODE
  IF ~%bgObject:G THEN EXIT.
  %bgObject:Fills += 1                                        ! for the diagnostics line
#IF(%bgDiag)
  IF ~%bgObject:Freq[1]
    bgApi_QueryPerfFreq(ADDRESS(%bgObject:Freq[1]))
  END
  bgApi_QueryPerfCount(ADDRESS(%bgObject:T1[1]))
#ENDIF
!  Keep the region ON the LIST, every time. Chasing the one right moment to
!  place it has now been wrong three times - at Init the resizer has not run, at
!  OpenWindow it may not have either, and a window restored to a remembered size
!  need not raise EVENT:Sized at all. A fill already happens whenever anything
!  changes, and following the LIST costs a GETPOSITION and a SETPOSITION.
  DO BG:Place:%bgObject
  total = RECORDS(%bgQueueUsed)
!  DOS NUMEROS, NO UNO. `full` son las filas que entran ENTERAS; `fit` es una
!  mas, la franja de abajo que se dibuja a proposito para que el scroll pueda
!  ser por pixel y no por fila.
!
!  Mezclarlos fue el error: la aritmetica del scroll usaba `fit`, asi que al
!  bajar mas alla de la ultima fila entera el registro SELECCIONADO aterrizaba
!  siempre en la franja - dos pixeles de alto. Dibujado, y por lo tanto
!  invisible. El browse lo tenia bien seleccionado y el panel de datos lo
!  mostraba, que es lo que hacia parecer que faltaba una fila.
!
!  Para dibujar sirve `fit`. Para decidir DONDE mirar sirve `full`.
  full  = d2g_PageSize(%bgObject:G)
  fit   = full + 1
  sel   = CHOICE(%bgList)
  first = 0
  rows  = total
  IF full > 0 AND total > full
!  The grid cannot draw the whole queue. Its rows are taller than the LIST's
!  lines, so the browse has loaded more records than there is room for, and
!  drawing from the top simply throws the tail away. Start far enough down that
!  the SELECTED record is one of the ones drawn - at the bottom of the file ABC
!  selects the last entry, and without this it was never on screen, which is
!  what made Ctrl-PageDown look as though it had selected nothing. The top
!  never showed it: entry one is always drawn.
    rows = fit
    IF sel > full
      first = sel - full
      IF first > total - full THEN first = total - full.
      IF first < 0 THEN first = 0.
    END
!  Y NO PEDIR MAS DE LO QUE HAY. Corrido hasta el final quedan menos registros
!  que filas dibujables; sin esto la ultima queda con lo que hubiera antes,
!  porque el bucle de abajo corta en el GET fallido pero el motor ya recibio
!  cuantas filas mostrar.
    IF first + rows > total THEN rows = total - first.
  END
#IF(%bgDiag)
!  SOLO CUANDO CAMBIA. Esta rutina corre con cada tecla; registrarla siempre
!  entierra la transicion que importa bajo cientos de lineas iguales, que es la
!  misma razon por la que el mapa de columnas se registra solo al cambiar.
  IF total <> %bgObject:LgQ OR rows <> %bgObject:LgR OR                      |
     %bgList{PROP:LineHeight} <> %bgObject:LgL
    %bgObject:LgQ = total
    %bgObject:LgR = rows
    %bgObject:LgL = %bgList{PROP:LineHeight}
!  EN PIXELES, como mide BG:Items. Leerlo sin poner la ventana en pixeles lo da
!  en dialog units y los dos numeros dejan de ser comparables, que es justo la
!  comparacion que hace falta.
    sp = 0{PROP:Pixels}
    0{PROP:Pixels} = 1
    BG_Log('%Procedure %bgObject fill: q=' & total & ' rows=' & rows &        |
           ' first=' & first & ' page=' & d2g_PageSize(%bgObject:G) &         |
           ' alto=' & %bgObject:Rgn{PROP:Height} &                            |
           ' listlh=' & %bgList{PROP:LineHeight} &                            |
           ' listitems=' & %bgList{PROP:Items})
    0{PROP:Pixels} = sp
  END
#ENDIF
  d2g_Page(%bgObject:G,first,rows)
  LOOP i = 1 TO rows
    GET(%bgQueueUsed,first + i)
    IF ERRORCODE() THEN BREAK.
    LOOP col = 1 TO %bgObject:Cols
      IF %bgObject:IFld[col]
!  A tick box carries no text: what goes over is whether it is ticked, and
!  the engine draws the square.
        %bgObject:Cell = CHOOSE(WHAT(%bgQueueUsed,%bgObject:IFld[col]) =      |
                                %bgObject:IconOn, '1', '0')
      ELSIF %bgObject:Pic[col]
        %bgObject:Cell = CLIP(LEFT(FORMAT(WHAT(%bgQueueUsed,%bgObject:Fld[col]), |
                                          CLIP(%bgObject:Pic[col]))))
      ELSE
        %bgObject:Cell = CLIP(LEFT(WHAT(%bgQueueUsed,%bgObject:Fld[col])))
      END
      d2g_Cell(%bgObject:G,i - 1,col - 1,%bgObject:Cell)
      IF %bgObject:CFld[col]
        cf = %bgObject:CFld[col]
        d2g_CellColour(%bgObject:G,i - 1,col - 1,                            |
                       BG_Colr(WHAT(%bgQueueUsed,cf)),                       |
                       BG_Colr(WHAT(%bgQueueUsed,cf + 1)),                   |
                       BG_Colr(WHAT(%bgQueueUsed,cf + 2)),                   |
                       BG_Colr(WHAT(%bgQueueUsed,cf + 3)))
      END
    END
  END
#IF(%bgSortHdr)
  DO BG:Mark:%bgObject
#ENDIF
#IF(%bgDiag)
!  El reloj se para ACA, antes de GETPOSITION: lo que se mide es el llenado,
!  no el diagnostico que lo cuenta.
  bgApi_QueryPerfCount(ADDRESS(%bgObject:T2[1]))
  IF %bgObject:Freq[1] >= 1000000 AND %bgObject:T2[1] >= %bgObject:T1[1]
    %bgObject:Us = (%bgObject:T2[1] - %bgObject:T1[1]) / (%bgObject:Freq[1] / 1000000)
    %bgObject:UsTot += %bgObject:Us
    %bgObject:UsN   += 1
  END
!  WHICH QUEUE FIELD EACH COLUMN ENDED UP ON. When a browse draws the right
!  number of columns with the wrong values in them, this is the one thing
!  worth seeing: c is the LIST column it came from, f the queue field it
!  reads, i the icon field if it is a tick box.
  map = ''
  LOOP i = 1 TO %bgObject:Cols
    map = CLIP(map) & ' ' & %bgObject:Col[i] & '>f' & %bgObject:Fld[i]         |
        & '[' & CLIP(%bgObject:Pic[i]) & ']w' & d2g_ColWidth(%bgObject:G,i - 1)
    IF %bgObject:IFld[i] THEN map = CLIP(map) & 'i' & %bgObject:IFld[i].
    IF %bgObject:CFld[i] THEN map = CLIP(map) & 'c' & %bgObject:CFld[i].
#IF(%bgTotals)
!  Suma o no, y con que nombre de campo. Con el picture al lado en la misma
!  linea, eso distingue las dos unicas causas posibles de un pie vacio: que
!  el picture no se haya reconocido como numerico, o que WHO() no haya dado
!  el nombre con el que leer el campo.
    IF %bgObject:Sum[i]
      map = CLIP(map) & 'S=' & CLIP(%bgObject:SumNm[i])
    ELSE
      map = CLIP(map) & 'S-'
    END
#ENDIF
  END
  sp = 0{PROP:Pixels}
  0{PROP:Pixels} = 1
  GETPOSITION(%bgList,dx,dy,dw,dh)                            ! where the LIST really is
  0{PROP:Pixels} = sp
!  Everything the grid is working from, in the window title. When a browse
!  draws nothing there is no way to tell from the outside whether the queue was
!  empty, the rows were too tall to fit, or the columns never got read - and
!  those want different fixes.
!  Only when it CHANGES. A line per fill would bury the one transition worth
!  seeing - what the columns looked like on opening, and what they looked like
!  after Reset - under hundreds of identical ones.
  IF CLIP(map) <> CLIP(%bgObject:MapWas)
    %bgObject:MapWas = CLIP(map)
    BG_Log('%Procedure %bgObject fill=' & %bgObject:Fills & ' cols=' & %bgObject:Cols |
         & ' q=' & total & ' hid=' & %bgObject:Hidden & '  ' & CLIP(map))
  END
  0{PROP:Text} = 'BG ' & CLIP(map)                                             |
               & ' | q=' & total & ' fill=' & %bgObject:Fills                   |
               & ' filt=' & %bgObject:Filters & ' hid=' & %bgObject:Hidden        |
               & ' cols=' & %bgObject:Cols                                      |
               & ' lines=' & %bgObject:Lines & ' rowh=' & d2g_RowH(%bgObject:G) |
               & ' need=' & d2g_RowNeed(%bgObject:G)                            |
               & ' page=' & d2g_PageSize(%bgObject:G) & ' fit=' & fit           |
               & ' draw=' & rows & ' lh=' & %bgList{PROP:LineHeight}            |
               & ' items=' & %bgList{PROP:Items}                               |
               & ' lst=' & CLIP(%bgList{PROP:FontName}) & '/'                  |
               & %bgList{PROP:FontSize}                                        |
               & ' grid=' & d2g_FontPt(%bgObject:G)                            |
               & ' dpi=' & %bgObject:Dpi                                       |
               & ' us=' & %bgObject:Us                                         |
               & ' avg=' & INT(%bgObject:UsTot /                                |
                   CHOOSE(%bgObject:UsN > 0,%bgObject:UsN,1))                  |
               & ' L=' & dx & ',' & dy & ',' & dw & ',' & dh
#ENDIF
  d2g_Total(%bgObject:G,total)
  %bgObject:Sel = sel                                         ! the browse owns the selection
  d2g_Select(%bgObject:G,sel - 1)                             ! absolute, and now always in view
  DO BG:Bars:%bgObject
#IF(%bgTotals)
!  Aca y no en BG:Setup: para cuando esto corre, ABC ya lleno el queue, o sea
!  que la vista esta abierta y andando. La bandera hace que se pague el
!  recorrido cuando cambia el conjunto y no en cada tecla.
  IF %bgObject:SumDue AND total
    DO BG:Sums:%bgObject
  END
#ENDIF
  d2g_Repaint(%bgObject:G)

BG:Scroll:%bgObject ROUTINE
!  Sideways is ours: slide the columns and repaint, nothing else changes.
!  Downwards is the browse's: it is told to scroll exactly as it would be by
!  its own scrollbar, and when it has refilled its queue ABC calls Reset, which
!  is where the grid picks the new page up. So paging, locators and range
!  limits keep behaving as they always did.
#IF(%bgBarsU OR %bgWheelU)
  DATA
i  LONG,AUTO
n  LONG,AUTO
sp LONG,AUTO
  CODE
  IF BG:LastCode = BG:FontCode
!  The type changed size, so the rows did too - and this time the GRID is the
!  one that knows how tall they are. NOT BG:Rows, which reads the height off
!  the LIST: that would pull the rows straight back down to the old line
!  height, leaving big type crammed into short rows with its descenders cut
!  off. The height goes the other way here, from the grid to the LIST, so the
!  browse reloads to fit however many rows there is now room for.
!  NOT BG:Rows. That asks the LIST how tall a row should be - and the LIST's
!  line height is the number we ourselves pushed up the last time the type grew.
!  Asking it again just gets that number back, so the rows would ratchet up and
!  never come down. When the type changes size the GRID is the authority and the
!  LIST is told, never the other way round.
    sp = 0{PROP:Pixels}
    0{PROP:Pixels} = 1
!  PER LINE, not per record - the same rule BG:Rows follows. This line had its
!  own copy of the calculation and so never got that fix: after a zoom the LIST
!  was told a whole three-line record was ONE line, worked out that a record was
!  three times taller again, and loaded a single one. Which is exactly what
!  zooming a multi-line browse looked like - every row but the first vanishing.
    IF %bgObject:Lines > 1
      %bgList{PROP:LineHeight} = d2g_RowH(%bgObject:G) / %bgObject:Lines
    ELSE
      %bgList{PROP:LineHeight} = d2g_RowH(%bgObject:G)
    END
#IF(%bgDiag)
    BG_Log('%Procedure %bgObject zoom: listlh=' &                            |
           %bgList{PROP:LineHeight} & ' rowh=' & d2g_RowH(%bgObject:G))
#ENDIF
    0{PROP:Pixels} = sp
    DO BG:Items:%bgObject                                     ! and load to the new page size
    DO BG:Fill:%bgObject
    EXIT
  END
  IF BG:LastCode = BG:WheelCode
!  One notch is three rows, the same as everywhere else in Windows. The browse
!  is asked to scroll exactly as its own scrollbar would ask it, so paging,
!  locators and range limits are none of our business.
    n = INT(ABS(BG:LastPos) / BG:WheelNotch) * BG:WheelLines
    IF n < 1 THEN n = 1.
    IF n > 30 THEN n = 30.                                    ! a flicked wheel is not a page jump
    LOOP i = 1 TO n
      IF BG:LastPos > 0
        POST(EVENT:ScrollUp,%bgList)
      ELSE
        POST(EVENT:ScrollDown,%bgList)
      END
    END
    EXIT
  END
  IF BG:LastBar = BG:SbHorz
    %bgObject:ScrollX = BG:LastPos
    d2g_ScrollX(%bgObject:G,%bgObject:ScrollX)
    d2g_Repaint(%bgObject:G)
    EXIT
  END
  CASE BG:LastCode
  OF 0
    POST(EVENT:ScrollUp,%bgList)
  OF 1
    POST(EVENT:ScrollDown,%bgList)
  OF 2
    POST(EVENT:PageUp,%bgList)
  OF 3
    POST(EVENT:PageDown,%bgList)
  OF 6
    POST(EVENT:ScrollTop,%bgList)
  OF 7
    POST(EVENT:ScrollBottom,%bgList)
  ELSE
    %bgList{PROP:VScrollPos} = BG:LastPos                     ! the thumb, dragged
    POST(EVENT:ScrollDrag,%bgList)
  END
#ELSE
  EXIT
#ENDIF

BG:Bars:%bgObject ROUTINE
!  Size both scrollbars from what is actually showing. Windows hides a bar
!  whose page covers its whole range, so the horizontal one appears only when
!  the columns are wider than the view, which is what anyone expects.
#IF(%bgBarsU)
  DATA
tot   LONG,AUTO
view  LONG,AUTO
pct   LONG,AUTO
fRecs LONG,AUTO
  CODE
  IF ~%bgObject:Barred THEN EXIT.
!  Sideways: the grid's own business - the total column width against the view.
  tot  = d2g_TotalWidth(%bgObject:G)
  view = d2g_ViewWidth(%bgObject:G)
  IF view < 1 THEN view = 1.
  IF tot <= view
    %bgObject:ScrollX = 0
    d2g_ScrollX(%bgObject:G,0)
#IF(%bgBarStyleU = 'Windows')
    BG_SetBar(%bgObject:Rgn{PROP:Handle},BG:SbHorz,0,1,1)     ! nothing to scroll: no bar
#ELSE
    d2g_HBar(%bgObject:G,0,0,1,1)
#ENDIF
  ELSE
    IF %bgObject:ScrollX > tot - view THEN %bgObject:ScrollX = tot - view.
#IF(%bgBarStyleU = 'Windows')
    BG_SetBar(%bgObject:Rgn{PROP:Handle},BG:SbHorz,%bgObject:ScrollX,view,tot)
#ELSE
    d2g_HBar(%bgObject:G,1,%bgObject:ScrollX,view,tot)
#ENDIF
  END
!  Down: NOT ours. The browse knows where it is in the file and keeps that in
!  the LIST's own PROP:VScrollPos, nought to a hundred - the same approximate
!  position Clarion's own browse thumb shows, because on an ISAM file that is
!  the only answer there is.
!  Downwards, ABC gives us one number and only one: PROP:VScrollPos, nought to
!  a hundred. It is the same approximate position Clarion's own browse thumb
!  shows, because on an ISAM file that is the only answer there is - nothing
!  knows the record count without reading the whole file. So the thumb is a
!  fixed size and the position is ABC's.
!  ABC only keeps PROP:VScrollPos when the browse was given a thumb, and turns
!  the LIST's scrollbar off when it was not - and with it off, writing
!  PROP:VScrollPos is ignored, so every drag read back as nought and was taken
!  for "go to the top". Turning it on costs nothing: the LIST is invisible, so
!  this is a number we are borrowing, not a scrollbar anyone will see.
  %bgList{PROP:VScroll} = 1
  IF ~%bgObject:VDrag                                         ! not while it is being dragged
    pct = BG:ThumbPct
#IF(%bgFileUsed)
!  How big the thumb should be is a question that CAN be answered honestly:
!  RECORDS() reads the count out of the file header, so it costs nothing. A
!  page against the whole file is what every other scrollbar in Windows means
!  by the size of its thumb.
    fRecs = RECORDS(%bgFileUsed)
    IF fRecs > 0
      pct = 100 * RECORDS(%bgQueueUsed) / fRecs
      IF pct < 4 THEN pct = 4.
      IF pct > 100 THEN pct = 100.
    END
#ENDIF
    d2g_VBar(%bgObject:G,CHOOSE(pct >= 100, 0, 1),%bgList{PROP:VScrollPos},pct)
  END
!  A scrollbar appearing or disappearing RESIZES the client area behind our
!  back - hide the horizontal one and the client grows by its height. Nothing
!  covers the strip it vacated until the render target is grown to match, so
!  what shows there is whatever is underneath, which is the old list. This does
!  nothing at all unless the client area really did change.
  d2g_Resize(%bgObject:G)
#ELSE
  EXIT
#ENDIF
#ENDAT
#!#############################################################################
#!  GROUPS
#!#############################################################################
#!-----------------------------------------------------------------------------
#!  A Clarion COLOR prompt is a BGR long; the grid wants 0xRRGGBB.
#!-----------------------------------------------------------------------------
#!-----------------------------------------------------------------------------
#!-----------------------------------------------------------------------------
#!  CODE TEMPLATE: cargar un esquema de columnas desde codigo.
#!
#!  Para lo que no puede decidir el usuario apretando un boton: el esquema que
#!  corresponde segun quien abrio la ventana - el departamento, el perfil, lo que
#!  sea. Se arrastra a un embed y listo.
#!-----------------------------------------------------------------------------
#CODE(BrowseGridLayout,'BrowseGrid - load a column layout'),DESCRIPTION('BrowseGrid: load layout ' & %bgcName & ' into ' & %bgcGrid)
  #PROMPT('&Grid object name:',@s32),%bgcGrid,DEFAULT('Grid1'),REQ
  #DISPLAY('El mismo que figura en Object name, en la solapa Browse de ese grid.')
  #DISPLAY('')
  #PROMPT('Layout &name:',@s64),%bgcName,REQ
  #PROMPT('That is a &variable, not a literal',CHECK),%bgcVar,DEFAULT(0),AT(10)
  #DISPLAY('')
  #DISPLAY('Tildado, lo de arriba se emite TAL CUAL para que lo resuelva el')
  #DISPLAY('compilador - un nombre de variable, o una expresion. Destildado se')
  #DISPLAY('emite entre comillas, como texto fijo.')
  #DISPLAY('')
  #DISPLAY('Ejemplo: con una variable GLO:Departamento y esquemas guardados con')
  #DISPLAY('esos mismos nombres, cada usuario entra con sus columnas.')
  #DISPLAY('')
  #DISPLAY('DONDE PONERLO: en un embed que corra DESPUES de que el grid exista.')
  #DISPLAY('ThisWindow.Init, despues del padre, es el lugar natural. Antes de que')
  #DISPLAY('el grid arranque no hay nada que recolocar y la llamada se va callada.')
  #DISPLAY('')
  #DISPLAY('Despues de la llamada, %bgcGrid:SchDid vale 1 si habia algo guardado')
  #DISPLAY('con ese nombre y 0 si no - por si conviene avisar o caer en otro.')
#!
#!  LITERAL O EXPRESION, decidido aca y no en el codigo emitido: un nombre de
#!  variable entrecomillado no da error, da un esquema que se llama
#!  GLO:Departamento y no existe.
#IF(%bgcVar)
%bgcGrid:SchName = %bgcName
#ELSE
%bgcGrid:SchName = '%bgcName'
#ENDIF
DO BG:SchLoad:%bgcGrid
#!-----------------------------------------------------------------------------
#!  End of BrowseGrid template set
#!-----------------------------------------------------------------------------
