#TEMPLATE(BrowseGridLeg,'BrowseGrid Legacy - draw a Legacy browse with Direct2D - v0.1 (proof of concept)'),FAMILY('CW20')
#!-----------------------------------------------------------------------------
#!  BrowseGridLeg  -  a LEGACY (CW20) port of Roberto Renz's BrowseGrid.
#!
#!  Original (ABC only):  https://github.com/robertorenz/templatemaker
#!  This is a deliberately MINIMAL proof of concept. It exists to answer one
#!  question - does the Direct2D grid attach to a Legacy BrowseBox and follow it
#!  - and nothing else. See "WHAT IS NOT HERE" below before reporting anything
#!  missing as a fault.
#!
#!  WHAT IT DOES. Puts a REGION exactly over the browse LIST, takes WS_VISIBLE
#!  off the LIST at the Windows level, and draws the rows itself with Direct2D
#!  and DirectWrite. The LIST is still there, still filling its queue, still
#!  holding the selection - it is simply not the thing you look at. Disable the
#!  extension and the ordinary browse is back.
#!
#!  WHY IT PORTS AT ALL. Almost none of the original is ABC. The row reading is
#!  RECORDS / GET / WHAT / CHOICE / PROPLIST, the columns are read off the LIST
#!  at run time, and every routine lives in %ProcedureRoutines - an embed both
#!  families share. Only the TRIGGERS were ABC, and Legacy has one for each:
#!
#!    ABC WindowManager.Init          ->  %AfterWindowOpening
#!    ABC WindowManager.Reset         ->  %RefreshWindowBeforeDisplay
#!    ABC WindowManager.TakeWindowEvent -> %EventCaseBeforeGenerated
#!                                         + %WindowEventHandling('DoResize')
#!    ABC WindowManager.TakeFieldEvent -> %AcceptLoopBeforeFieldHandling
#!    ABC WindowManager.Kill          ->  %BeforeWindowClosing
#!
#!  %RefreshWindowBeforeDisplay is the important one. A Legacy BrowseBox hangs
#!  its own refresh off %RefreshWindowAfterLookup (CtlBrow.TPW), which is a
#!  PROCEDURE-level embed - so this template never has to reach into the browse
#!  control's instance-scoped embeds, and never has to know which instance it is
#!  sitting next to. Anything that refills the queue goes through RefreshWindow,
#!  and this hook is after the sort and after the scroll position, immediately
#!  before DISPLAY().
#!
#!  WHY NOT %WindowEventHandling FOR THE CUSTOM EVENTS. That embed is
#!  parameterised by event name and the list of events is fixed
#!  (STANDARD.TPW, %LocWindowEvent), so a new OF clause cannot be added through
#!  it. %EventCaseBeforeGenerated sits inside CASE EVENT() ahead of the
#!  generated clauses and takes ours.
#!
#!  WHAT IS NOT HERE (all present in the ABC original, deliberately dropped for
#!  v0.1): scrollbars and mouse wheel, column resizing by drag, sort on heading
#!  click, the Excel filter button, the column chooser, layout memory between
#!  runs, the right-click popup hand-back, grouped/multi-line formats, and text
#!  wrapping. Keyboard still works throughout, because the LIST keeps the focus.
#!
#!  SORT ON HEADING CLICK is the one item that cannot simply be copied when the
#!  time comes. The ABC original writes PROPLIST:MouseDownField and posts
#!  EVENT:HeaderPressed; generated Legacy source contains no HeaderPressed
#!  handler at all, so nothing would answer. The Legacy route is to set
#!  <prefix>::SortOrder, set ForceRefresh = True and DO <prefix>::SelectSort.
#!
#!  REQUIRES d2gridleg.c, which ships in this folder, somewhere the compiler
#!  can find it - the app folder, or a directory on the redirection path.
#!  Direct2D and DirectWrite are bound at run time with LoadLibrary, so there is
#!  no import library and nothing to ship.
#!-----------------------------------------------------------------------------
#!#############################################################################
#!  GLOBAL EXTENSION - BrowseGridLegGlobal
#!#############################################################################
#EXTENSION(BrowseGridLegGlobal,'BrowseGrid Legacy - Global (add once per application)'),APPLICATION
#SHEET
  #TAB('&General')
    #BOXED('BrowseGrid Legacy')
      #DISPLAY('BrowseGrid Legacy - v0.1, proof of concept')
      #DISPLAY('Draws a Legacy (CW20) browse with Direct2D instead of the')
      #DISPLAY('runtime LIST, without touching the browse underneath.')
      #DISPLAY('')
      #DISPLAY('REQUIRES d2gridleg.c on the redirection path.')
      #DISPLAY('Add this extension ONCE per application.')
    #ENDBOXED
    #BOXED('Options')
      #PROMPT('&Disable this template',CHECK),%bglGDisable,DEFAULT(0),AT(10)
      #PROMPT('Offer the criteria &filter (MyFilterClass)',CHECK),%bglGFilter,DEFAULT(1),AT(10)
      #DISPLAY('Needed by the BrowseGridLegFilter button. Requires')
      #DISPLAY('MyFilterClass.inc / .clw on the redirection path. Untick and')
      #DISPLAY('the class is neither included nor linked.')
    #ENDBOXED
  #ENDTAB
#ENDSHEET
#!-----------------------------------------------------------------------------
#AT(%AfterGlobalIncludes),WHERE(%bglGDisable=0)
  PRAGMA('compile(d2gridleg.c)')                              ! the grid, built by Clarion's own C compiler
#IF(%bglGFilter)
!  The criteria-filter class (Roberto's myFilter, unchanged - it is pure
!  Clarion: its own WINDOW, its own ACCEPT, no ABC anywhere). The LINK()
!  attribute inside the INC pulls MyFilterClass.clw into the build.
  INCLUDE('MyFilterClass.INC'),ONCE
#ENDIF
BGL:Scrolled         EQUATE(EVENT:User + 244)                 ! a grid scrollbar moved
BGL:GwlStyle         EQUATE(-16)
BGL:GwlWndProc       EQUATE(-4)
BGL:Visible          EQUATE(10000000h)                        ! WS_VISIBLE
BGL:HScrollStyle     EQUATE(00100000h)                        ! WS_HSCROLL
BGL:FrameChanged     EQUATE(0020h)
BGL:NoMove           EQUATE(0002h)
BGL:NoSize           EQUATE(0001h)
BGL:NoZOrder         EQUATE(0004h)
BGL:HwndTop          EQUATE(0)
BGL:ClipSib          EQUATE(04000000h)                        ! WS_CLIPSIBLINGS
BGL:SbHorz           EQUATE(0)
BGL:SbVert           EQUATE(1)
BGL:WmHScroll        EQUATE(0114h)
BGL:WmVScroll        EQUATE(0115h)
BGL:SifRange         EQUATE(1)
BGL:SifPage          EQUATE(2)
BGL:SifPos           EQUATE(4)
BGL:SifTrack         EQUATE(10h)
BGL:WmMouseWheel     EQUATE(020Ah)
BGL:WheelNotch       EQUATE(120)                              ! WHEEL_DELTA
BGL:WheelCode        EQUATE(99)                               ! not one of Windows' scroll codes
BGL:FontCode         EQUATE(98)                               ! Ctrl-wheel resized the type
BGL:ThumbPct         EQUATE(12)                               ! fallback when the count is unknown
BGL:MkControl        EQUATE(0008h)
BGL:VkLButton        EQUATE(1)
#ENDAT
#!
#!
#!  The scroll callback cannot hand anything to Clarion through POST, so what it
#!  saw is left here for the ACCEPT loop to pick up. Only one scrollbar can be
#!  moving at a time, so one set of variables is enough. LastG is this port's
#!  addition: the original left the grid unidentified, so with two grids on one
#!  window both answered every scroll. The callback knows the HWND, so it can
#!  say which grid it was.
#AT(%GlobalData),WHERE(%bglGDisable=0)
BGL:LastBar          LONG                                     ! 0 horizontal, 1 vertical
BGL:LastCode         LONG                                     ! what the user did to it
BGL:LastPos          LONG                                     ! and where the thumb ended up
BGL:LastG            LONG                                     ! which grid it happened to
#ENDAT
#!
#AT(%GlobalMap),WHERE(%bglGDisable=0)
#!  cdecl exports from C, so the Clarion name carries a leading underscore.
#!  Only the subset this proof of concept calls is declared; the rest of
#!  d2gridleg.c is still compiled, simply not prototyped here.
    MODULE('d2gridleg.c')
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
d2g_Colours(LONG h,ULONG back,ULONG band,ULONG grid,ULONG txt,ULONG hb,ULONG ht,ULONG sb,ULONG st),NAME('_d2g_Colours')
d2g_Page(LONG h,LONG firstRow,LONG rows),NAME('_d2g_Page')
d2g_Cell(LONG h,LONG visRow,LONG col,*CSTRING s),RAW,NAME('_d2g_Cell')
d2g_Repaint(LONG h),NAME('_d2g_Repaint')
d2g_PaintNow(LONG h),LONG,PROC,NAME('_d2g_PaintNow')
d2g_Resize(LONG h),LONG,PROC,NAME('_d2g_Resize')
d2g_PageSize(LONG h),LONG,NAME('_d2g_PageSize')
d2g_RowH(LONG h),LONG,NAME('_d2g_RowH')
d2g_RowNeed(LONG h),LONG,NAME('_d2g_RowNeed')
d2g_HitRow(LONG h,LONG y),LONG,NAME('_d2g_HitRow')
d2g_ScrollX(LONG h,LONG x),NAME('_d2g_ScrollX')
d2g_TotalWidth(LONG h),LONG,NAME('_d2g_TotalWidth')
d2g_ViewWidth(LONG h),LONG,NAME('_d2g_ViewWidth')
d2g_FromHwnd(LONG hwnd),LONG,NAME('_d2g_FromHwnd')
d2g_BarStyle(LONG h,LONG style),NAME('_d2g_BarStyle')
d2g_BarsShow(LONG h,LONG on),NAME('_d2g_BarsShow')
d2g_VBar(LONG h,LONG show,LONG pos,LONG pct),NAME('_d2g_VBar')
d2g_VHit(LONG h,LONG x,LONG y),LONG,NAME('_d2g_VHit')
d2g_VGrab(LONG h,LONG y),LONG,NAME('_d2g_VGrab')
d2g_VDrag(LONG h,LONG y,LONG grab),LONG,NAME('_d2g_VDrag')
d2g_HBar(LONG h,LONG show,LONG pos,LONG page,LONG total),NAME('_d2g_HBar')
d2g_HitHBar(LONG h,LONG x,LONG y),LONG,NAME('_d2g_HitHBar')
d2g_HGrab(LONG h,LONG x),LONG,NAME('_d2g_HGrab')
d2g_HDrag(LONG h,LONG x,LONG grab),LONG,NAME('_d2g_HDrag')
d2g_FontSize(LONG h,LONG pt),LONG,PROC,NAME('_d2g_FontSize')
d2g_FontPt(LONG h),LONG,NAME('_d2g_FontPt')
d2g_HitCol(LONG h,LONG x),LONG,NAME('_d2g_HitCol')
d2g_HdrHeight(LONG h),LONG,NAME('_d2g_HdrHeight')
d2g_SortMark(LONG h,LONG col,LONG dir),NAME('_d2g_SortMark')
d2g_HitEdge(LONG h,LONG x),LONG,NAME('_d2g_HitEdge')
d2g_ColWidth(LONG h,LONG col),LONG,NAME('_d2g_ColWidth')
d2g_SetWidth(LONG h,LONG col,LONG width),NAME('_d2g_SetWidth')
d2g_FilterBtns(LONG h,LONG n),NAME('_d2g_FilterBtns')
d2g_FilterOn(LONG h,LONG col,LONG n),NAME('_d2g_FilterOn')
d2g_HitBtn(LONG h,LONG x,LONG y),LONG,NAME('_d2g_HitBtn')
d2g_Carry(LONG h,LONG col,LONG x),NAME('_d2g_Carry')
d2g_Wrap(LONG h,LONG n,LONG lines),NAME('_d2g_Wrap')
d2g_VarRows(LONG h,LONG n),NAME('_d2g_VarRows')
d2g_RowsFit(LONG h),LONG,NAME('_d2g_RowsFit')
d2g_FitUpTo(LONG h,LONG k),LONG,NAME('_d2g_FitUpTo')
d2g_PageMax(LONG h),LONG,NAME('_d2g_PageMax')
d2g_TailGap(LONG h),LONG,NAME('_d2g_TailGap')
d2g_FirstRow(LONG h),LONG,NAME('_d2g_FirstRow')
d2g_Sizing(LONG h,LONG n),NAME('_d2g_Sizing')
    END
BGL_Rgb(LONG),ULONG
BGL_BarProc(ULONG,ULONG,ULONG,LONG),LONG,PASCAL
BGL_HookBars(LONG,LONG),BYTE,PROC
BGL_DropBars(LONG),LONG,PROC
BGL_SetBar(LONG,LONG,LONG,LONG,LONG)
    MODULE('win32')
bglApi_SetWindowLong(ULONG hWnd,LONG nIndex,LONG dwNewLong),LONG,PASCAL,PROC,NAME('SetWindowLongA')
bglApi_GetWindowLong(ULONG hWnd,LONG nIndex),LONG,PASCAL,NAME('GetWindowLongA')
bglApi_SetWindowPos(ULONG hWnd,LONG after,LONG x,LONG y,LONG cx,LONG cy,ULONG flags),LONG,PASCAL,PROC,NAME('SetWindowPos')
bglApi_SetProp(ULONG hWnd,LONG lpString,LONG hData),LONG,PASCAL,PROC,NAME('SetPropA')
bglApi_GetProp(ULONG hWnd,LONG lpString),LONG,PASCAL,NAME('GetPropA')
bglApi_RemoveProp(ULONG hWnd,LONG lpString),LONG,PASCAL,PROC,NAME('RemovePropA')
bglApi_CallWndProc(LONG lpPrev,ULONG hWnd,ULONG wMsg,ULONG wParam,LONG lParam),LONG,PASCAL,NAME('CallWindowProcA')
bglApi_SetScrollInfo(ULONG hWnd,LONG bar,LONG lpsi,LONG redraw),LONG,PASCAL,PROC,NAME('SetScrollInfo')
bglApi_GetScrollInfo(ULONG hWnd,LONG bar,LONG lpsi),LONG,PASCAL,PROC,NAME('GetScrollInfo')
bglApi_GetAsyncKeyState(LONG vKey),SHORT,PASCAL,NAME('GetAsyncKeyState')
    END
#ENDAT
#!
#AT(%ProgramProcedures),WHERE(%bglGDisable=0)
!  ---- scrollbars ---------------------------------------------------------
!  A REGION is not born with scrollbars, so the style goes on at run time and
!  the control is subclassed for the two scroll messages. The address of the
!  callback is taken HERE, in the module that defines it - taken in a member
!  module it is an import thunk, not the procedure.
!
!  ONLY THE HORIZONTAL BAR IS WINDOWS'. The vertical one is always drawn by the
!  grid, because Windows' cannot be made to follow the data: it drags inside a
!  message loop of its own, and moving the browse needs records, which needs
!  ACCEPT, which that loop is holding up. Sideways needs nothing from the browse
!  so it can be done inside the loop; downwards cannot be.
BGL_HookBars PROCEDURE(LONG pHwnd,LONG pStyle)
prop CSTRING('BrowseGridLegBarProc')
old  LONG,AUTO
sty  LONG,AUTO
  CODE
  IF ~pHwnd THEN RETURN 0.
  IF bglApi_GetProp(pHwnd,ADDRESS(prop)) THEN RETURN 0.
!  The subclass goes on whatever the style, because the roller comes through it
!  too. The SCROLLBAR only goes on for the Windows style - the other two draw
!  their own, and a Windows bar underneath would take width for nothing.
  IF pStyle = 0
    sty = bglApi_GetWindowLong(pHwnd,BGL:GwlStyle)
    bglApi_SetWindowLong(pHwnd,BGL:GwlStyle,BOR(sty,BGL:HScrollStyle))
  END
  bglApi_SetWindowPos(pHwnd,0,0,0,0,0,                                          |
                      BOR(BOR(BOR(BGL:FrameChanged,BGL:NoMove),BGL:NoSize),BGL:NoZOrder))
  old = bglApi_SetWindowLong(pHwnd,BGL:GwlWndProc,ADDRESS(BGL_BarProc))
  IF ~old THEN RETURN 0.
  bglApi_SetProp(pHwnd,ADDRESS(prop),old)
  RETURN 1

BGL_DropBars PROCEDURE(LONG pHwnd)
prop CSTRING('BrowseGridLegBarProc')
old  LONG,AUTO
  CODE
  IF ~pHwnd THEN RETURN 0.
  old = bglApi_GetProp(pHwnd,ADDRESS(prop))
  IF old
    bglApi_SetWindowLong(pHwnd,BGL:GwlWndProc,old)
  END
  bglApi_RemoveProp(pHwnd,ADDRESS(prop))
  RETURN old

BGL_SetBar PROCEDURE(LONG pHwnd,LONG pBar,LONG pPos,LONG pPage,LONG pTotal)
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
  si.fMask  = BOR(BOR(BGL:SifRange,BGL:SifPage),BGL:SifPos)
  si.nMin   = 0
  si.nMax   = pTotal - 1
  si.nPage  = pPage
  si.nPos   = pPos
  bglApi_SetScrollInfo(pHwnd,pBar,ADDRESS(si),1)

!  Windows does not work out the new position for a scroll message; this does,
!  writes it back, leaves what happened in the globals and tells the ACCEPT
!  loop. Horizontal scrolling is the grid's own business - it just slides the
!  columns. Vertical is the BROWSE's, so it is passed on rather than acted on.
BGL_BarProc PROCEDURE(ULONG hWnd,ULONG wMsg,ULONG wParam,LONG lParam)
prop CSTRING('BrowseGridLegBarProc')
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
  old = bglApi_GetProp(hWnd,ADDRESS(prop))
!  The roller. Windows sends this to whatever is under the pointer, which is the
!  region - the LIST underneath is invisible and cannot be hit. There is no modal
!  loop involved here, so unlike a thumb drag it is enough to post: the ACCEPT
!  loop runs between notches and the browse fetches its records as it always would.
  IF wMsg = BGL:WmMouseWheel
    dz = BSHIFT(BAND(wParam,0FFFF0000h),-16)
    IF dz > 32767 THEN dz -= 65536.                           ! it is a SIGNED short up there
    IF dz
      g = d2g_FromHwnd(hWnd)
      IF g
        IF BAND(wParam,BGL:MkControl)
!  Ctrl and the roller: bigger and smaller type, the way every other program
!  does it. The rows grow with the font, so the browse is told to reload - it
!  fits a different number of records now.
          d2g_FontSize(g,d2g_FontPt(g) + CHOOSE(dz > 0, 1, -1))
          d2g_PaintNow(g)
          BGL:LastBar  = BGL:SbVert
          BGL:LastCode = BGL:FontCode
          BGL:LastPos  = 0
        ELSE
          BGL:LastBar  = BGL:SbVert
          BGL:LastCode = BGL:WheelCode
          BGL:LastPos  = dz
        END
        BGL:LastG = g
        POST(BGL:Scrolled)
      END
    END
!  SWALLOWED, not passed on. Handing the roller to the original WndProc as well
!  lets Clarion act on it a second time, and its own answer to the wheel on an
!  IMM LIST is a PAGE - so one notch scrolled our rows AND paged the browse,
!  which is seen as the wheel doing page-up/page-down instead of scrolling.
!  This is the one message we handle completely, so it stops here.
    RETURN 0
  END
  IF wMsg = BGL:WmHScroll OR wMsg = BGL:WmVScroll
    bar  = CHOOSE(wMsg = BGL:WmHScroll, BGL:SbHorz, BGL:SbVert)
    code = BAND(wParam,0FFFFh)
    si.cbSize = SIZE(si)
    si.fMask  = BOR(BOR(BOR(BGL:SifRange,BGL:SifPage),BGL:SifPos),BGL:SifTrack)
    IF bglApi_GetScrollInfo(hWnd,bar,ADDRESS(si))
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
      OF 4 OROF 5
        pos = si.nTrack
      OF 6
        pos = si.nMin
      OF 7
        pos = si.nMax
      END
      IF pos > si.nMax - si.nPage + 1 THEN pos = si.nMax - si.nPage + 1.
      IF pos < si.nMin THEN pos = si.nMin.
      g = d2g_FromHwnd(hWnd)
      IF bar = BGL:SbHorz                                     ! ours: just move the columns
        si.fMask = BGL:SifPos
        si.nPos  = pos
        bglApi_SetScrollInfo(hWnd,bar,ADDRESS(si),1)
!  AND MOVE THEM NOW, not on the next ACCEPT. Dragging a scrollbar thumb puts
!  Windows into a message loop of its OWN, and Clarion's ACCEPT does not get a
!  turn until the button comes back up - so anything POSTed from here just
!  queues, and the columns would not budge until you let go. Scrolling sideways
!  needs nothing from the browse though: it is the grid's own pixels. So it is
!  done right here, synchronously, and painted immediately rather than
!  invalidated - an invalidated window would not be repainted until the loop
!  ends either. Downwards is not like this: that one needs records, which only
!  the browse can fetch, so it still waits for the button.
        IF g
          d2g_ScrollX(g,pos)
          d2g_PaintNow(g)
        END
      END
      BGL:LastBar  = bar
      BGL:LastCode = code
      BGL:LastPos  = pos
      BGL:LastG    = g
      POST(BGL:Scrolled)
    END
  END
  IF old
    RETURN bglApi_CallWndProc(old,hWnd,wMsg,wParam,lParam)
  END
  RETURN 0

!  A Clarion COLOR is 00BBGGRRh and Direct2D wants RRGGBB, so the two ends are
!  swapped. A negative value is a SYSTEM colour (COLOR:WindowText and friends),
!  which is an index rather than a colour and cannot be swapped - white is the
!  safe answer, and the prompts all default to real colours anyway.
BGL_Rgb PROCEDURE(LONG pColor)
c LONG,AUTO
  CODE
  c = pColor
  IF c < 0 THEN c = 0FFFFFFh.
  RETURN BOR(BOR(BSHIFT(BAND(c,00000FFh),16),BAND(c,000FF00h)),                |
             BSHIFT(BAND(c,0FF0000h),-16))
#ENDAT
#!#############################################################################
#!  PROCEDURE EXTENSION - BrowseGridLeg
#!#############################################################################
#EXTENSION(BrowseGridLeg,'BrowseGrid Legacy - draw this browse with Direct2D'),PROCEDURE,MULTI,REQ(BrowseGridLegGlobal),DESCRIPTION('Grid on ' & %bglList)
#SHEET
  #TAB('&Browse')
    #BOXED('Which browse')
      #PROMPT('&Disable this grid',CHECK),%bglDisable,DEFAULT(0),AT(10)
      #PROMPT('Show grid &diagnostics in the window title',CHECK),%bglDiag,DEFAULT(0),AT(10)
      #PROMPT('&Object name:',@s64),%bglObject,REQ,DEFAULT('Grid' & %ActiveTemplateInstance)
      #PROMPT('&LIST control to take over:',CONTROL),%bglList,REQ
      #PROMPT('Browse &queue:',@s64),%bglQueue,REQ,DEFAULT('Queue:Browse:1')
      #PROMPT('Browse &instance prefix:',@s64),%bglBrowseObj,REQ,DEFAULT('BRW1')
      #PROMPT('&Table the browse reads:',FILE),%bglFile
      #PROMPT('&Keep the selection when the window regains focus',CHECK),%bglKeepFocus,DEFAULT(1),AT(10)
      #PROMPT('&Loading:',DROP('Page loaded|File loaded')),%bglLoad,DEFAULT('Page loaded')
      #ENABLE(%bglLoad = 'File loaded')
        #PROMPT('  Record l&imit:',SPIN(@n7,100,1000000,100)),%bglMaxRecs,DEFAULT(20000)
      #ENDENABLE
      #DISPLAY('Page loaded - the browse drives, holding one screen of records.')
      #DISPLAY('             Everything works as Clarion has always done it.')
      #DISPLAY('File loaded - the grid drives. The whole view is read into the')
      #DISPLAY('             queue once and scrolling, sorting and the thumb are')
      #DISPLAY('             done in memory. Exact scrollbar, instant sorts. See')
      #DISPLAY('             the notes before choosing it.')
      #DISPLAY('Sizes the scrollbar thumb, and gives the field pickers on the')
      #DISPLAY('Sorting tab something to list. Leave blank and the thumb takes a')
      #DISPLAY('fixed size and those pickers stay closed.')
    #ENDBOXED
    #BUTTON('&Notes on the browse settings'),AT(,,200)
      #SHEET
        #TAB('The LIST and queue')
          #BOXED('The LIST control')
            #DISPLAY('Must be the browse LIST itself. A CONTROL prompt offers every')
            #DISPLAY('control in the window, including panels and buttons, and REQ only')
            #DISPLAY('checks that something was chosen.')
            #DISPLAY('')
            #DISPLAY('Point it at a PANEL and everything fails quietly: PROPLIST reads')
            #DISPLAY('come back empty so there are no columns, PROP:Items and')
            #DISPLAY('PROP:LineHeight are meaningless so the browse is never resized,')
            #DISPLAY('CHOICE() is 0, and the grid is drawn wherever the panel happens')
            #DISPLAY('to be while the browse is left alone. Generation refuses it now.')
          #ENDBOXED
          #BOXED('The queue')
            #DISPLAY('The queue the LIST is FROM(). A Legacy BrowseBox names the first')
            #DISPLAY('one Queue:Browse:1, the second Queue:Browse:2, and so on - look')
            #DISPLAY('in the generated source if you are not sure.')
            #DISPLAY('')
            #DISPLAY('Rows are read from it generically, with WHAT() by field number,')
            #DISPLAY('so nothing here knows or cares what the file is.')
          #ENDBOXED
        #ENDTAB
        #TAB('Focus and diagnostics')
          #BOXED('Keeping the selection on regaining focus')
            #DISPLAY('Clarion''s generated GainFocus handler sets ForceRefresh and')
            #DISPLAY('calls RefreshWindow, which rebuilds the browse from the file.')
            #DISPLAY('Click to another window and back and your place is gone. This')
            #DISPLAY('skips that, so the browse is left exactly as you left it.')
            #DISPLAY('')
            #DISPLAY('In FILE LOADED mode it is close to required: that rebuild drops')
            #DISPLAY('the resident copy to a single page, which then has to be read')
            #DISPLAY('again, taking the sort order and the selection with it.')
            #DISPLAY('')
            #DISPLAY('Untick it if a browse must re-read on returning - a window whose')
            #DISPLAY('records another window has just changed, and which has no other')
            #DISPLAY('way of hearing about it. First-time initialisation still runs')
            #DISPLAY('either way, and so does everything else the window does.')
          #ENDBOXED
          #BOXED('Diagnostics')
            #DISPLAY('Puts the grid''s working numbers in the window title. The pair')
            #DISPLAY('that matters is page= against items=: the grid draws page rows')
            #DISPLAY('and the browse loads items records, and the bottom of the list')
            #DISPLAY('misbehaves the moment those differ. first= is which queue entry')
            #DISPLAY('is drawn at the top; anything but 0 means the grid is showing a')
            #DISPLAY('window into the queue rather than all of it.')
          #ENDBOXED
        #ENDTAB
      #ENDSHEET
    #ENDBUTTON
  #ENDTAB
  #TAB('Colu&mns')
    #BOXED('Columns')
      #PROMPT('&Frozen columns (stay put when scrolled sideways):',SPIN(@n2,0,8,1)),%bglFrozen,DEFAULT(0)
      #DISPLAY('Widths, headings, pictures and alignment come off the LIST at')
      #DISPLAY('run time. Draws FLAT only - a grouped format comes over as one')
      #DISPLAY('column per field on a single line.')
      #PROMPT('Let the user &resize columns by dragging',CHECK),%bglSizeable,DEFAULT(1),AT(10)
      #PROMPT('Let the user &choose columns (right-click the headings)',CHECK),%bglChooser,DEFAULT(1),AT(10)
      #PROMPT('Let the user re&order columns by dragging headings',CHECK),%bglMovable,DEFAULT(1),AT(10)
      #DISPLAY('With reordering on, a heading CLICK sorts on release rather')
      #DISPLAY('than press - the only way to tell a click from a drag.')
      #PROMPT('Re&member column widths between runs',CHECK),%bglRemember,DEFAULT(1),AT(10)
      #ENABLE(%bglRemember)
        #PROMPT('  &INI file:',@s64),%bglIni,DEFAULT('.\BrowseGrid.INI')
      #ENDENABLE
      #DISPLAY('Stored under a section named for this procedure and this grid,')
      #DISPLAY('so two grids never tread on each other. Widths, and which')
      #DISPLAY('columns the user chose to see - nothing else is remembered.')
    #ENDBOXED
  #ENDTAB
  #TAB('&Scrolling')
    #BOXED('Scrollbars')
      #PROMPT('&Scrollbars on the grid',CHECK),%bglBars,DEFAULT(1),AT(10)
      #ENABLE(%bglBars)
        #PROMPT('  St&yle:',DROP('Windows|Slim|Overlay')),%bglBarStyle,DEFAULT('Windows')
        #PROMPT('  Move the browse &while the thumb is dragged',CHECK),%bglDragLive,DEFAULT(0),AT(10)
      #ENDENABLE
    #ENDBOXED
    #BOXED('Mouse wheel')
      #PROMPT('Scroll with the mouse &wheel',CHECK),%bglWheel,DEFAULT(1),AT(10)
      #ENABLE(%bglWheel)
        #PROMPT('  &Rows per notch:',SPIN(@n2,1,10,1)),%bglWheelLines,DEFAULT(3)
      #ENDENABLE
      #DISPLAY('Ctrl and the wheel resizes the type.')
    #ENDBOXED
    #BOXED('Thumb size')
      #DISPLAY('Sized from the table named on the Browse tab - a page against the')
      #DISPLAY('whole file. Named nothing there, the thumb takes a fixed size.')
    #ENDBOXED
    #BUTTON('&Notes on scrolling'),AT(,,200)
      #SHEET
        #TAB('Bars and wheel')
          #BOXED('Why the downward bar is always drawn')
            #DISPLAY('Whatever the style, the vertical bar is drawn by the grid and')
            #DISPLAY('only the sideways one can be Windows''. A Windows vertical thumb')
            #DISPLAY('drags inside a message loop of its own, which holds up ACCEPT -')
            #DISPLAY('and moving the browse needs records, which needs ACCEPT. Sideways')
            #DISPLAY('is unaffected because those are the grid''s own pixels, so it can')
            #DISPLAY('be scrolled synchronously inside the drag.')
          #ENDBOXED
          #BOXED('Styles')
            #DISPLAY('Windows - the sideways bar is Windows'' own, the downward drawn.')
            #DISPLAY('Slim    - both drawn, thin and flat, in the grid''s own colours.')
            #DISPLAY('Overlay - both drawn over the rows and only while the pointer is')
            #DISPLAY('          on the grid, so the data keeps the whole width.')
          #ENDBOXED
          #BOXED('Rows per notch')
            #DISPLAY('Three is what Windows uses. In the body of the list that reads as')
            #DISPLAY('smooth scrolling - the highlight stays pinned to the last row and')
            #DISPLAY('the DATA slides three rows. On the LAST page the queue has nothing')
            #DISPLAY('to slide, so ScrollOne moves the highlight instead and it leaps')
            #DISPLAY('three rows at a time. Set 1 for one row a notch everywhere.')
          #ENDBOXED
        #ENDTAB
        #TAB('Thumb')
          #BOXED('Dragging the thumb')
            #DISPLAY('A Legacy thumb does not address records. ScrollDrag indexes a')
            #DISPLAY('100-slot KeyDistribution array of synthetic key values spread')
            #DISPLAY('evenly across the key RANGE, then locates the first record at or')
            #DISPLAY('after that value. Real data is never spread evenly, so several')
            #DISPLAY('slots land on the same few records - and on the last page, where')
            #DISPLAY('the queue has nothing left to slide, each one moves only the')
            #DISPLAY('highlight. That is the jumping, and the native LIST does it too.')
            #DISPLAY('')
            #DISPLAY('Leave continuous updating OFF and the browse is moved once, when')
            #DISPLAY('the button comes up, so a drag cannot walk the highlight through')
            #DISPLAY('half a dozen stops on the way past.')
          #ENDBOXED
          #BOXED('Thumb size')
            #DISPLAY('RECORDS() reads the count from the file header, so the thumb can')
            #DISPLAY('be sized as a page against the whole file. A filtered or range-')
            #DISPLAY('limited browse reads high - the count is the file''s, not the')
            #DISPLAY('view''s. Under a clicked-heading sort the thumb is meaningless:')
            #DISPLAY('KeyDistribution was built for the design-time sort orders.')
          #ENDBOXED
        #ENDTAB
      #ENDSHEET
    #ENDBUTTON
  #ENDTAB
  #TAB('S&orting')
    #BOXED('Heading click')
      #PROMPT('&Sort when a heading is clicked',CHECK),%bglSortHdr,DEFAULT(1),AT(10)
      #DISPLAY('Click a heading to sort by it, again to reverse. The grid draws a')
      #DISPLAY('triangle for the direction.')
    #ENDBOXED
    #BOXED('Filter buttons')
      #PROMPT('&Excel-style filter buttons on headings',CHECK),%bglFilterBtns,DEFAULT(1),AT(10)
      #DISPLAY('A button on every heading: click it for a menu of the column''s')
      #DISPLAY('values, pick one to show only those rows. Filters on several')
      #DISPLAY('columns add up, and the search box narrows within them. The')
      #DISPLAY('button also carries the sort triangle. File loaded only.')
    #ENDBOXED
  #ENDTAB
  #TAB('Sort ord&er')
    #BOXED('Sort order when the window opens')
      #ENABLE(%bglFile)
        #PROMPT('Default sort &column:',FIELD(%bglFile)),%bglSortField
      #ENDENABLE
      #ENABLE(%bglSortField)
#!  NO AT() ON THESE. A prompt's AT(x,y) is an ABSOLUTE coordinate inside the
#!  enclosing container - the TAB - not an offset from the line above and not
#!  relative to the OPTION they belong to. AT(10,5) put them five units down the
#!  Sorting tab, on top of the first box's heading, while the Direction group
#!  they belong to drew empty further down. Left alone they flow into it.
#!  Height only - AT(,,,h). x and y stay omitted so the group still FLOWS into
#!  place; giving either of those would pin it absolutely to the tab, which is
#!  what threw the radios onto the first box's heading before. The group sizes
#!  itself tight to its contents otherwise, leaving Descending against the frame.
        #PROMPT('Direction',OPTION),%bglSortDirn,DEFAULT('Ascending'),AT(,,,38)
        #PROMPT('&Ascending',RADIO)
        #PROMPT('D&escending',RADIO)
      #ENDENABLE
      #DISPLAY('Leave blank to open in whatever order the browse itself uses -')
      #DISPLAY('the key behind the current tab. Name the table on the Browse tab')
      #DISPLAY('first, or the picker has no field list to offer.')
    #ENDBOXED
    #BOXED('Ties')
      #ENABLE(%bglFile)
        #PROMPT('&Unique field to break ties:',FIELD(%bglFile)),%bglSortTie
      #ENDENABLE
      #DISPLAY('Strongly recommended. Appended to every sort this template')
      #DISPLAY('applies. Put the record ID or another field no two records')
      #DISPLAY('share - see the notes for what goes wrong without one.')
    #ENDBOXED
    #BUTTON('&Notes on sorting'),AT(,,200)
      #SHEET
        #TAB('Ties')
          #BOXED('Ties, and why they matter')
            #DISPLAY('A PROP:Order that is not unique breaks POSITION() and RESET(),')
            #DISPLAY('and the browse leans on both hard - FillRecord saves a POSITION')
            #DISPLAY('for every queue entry and RESETs the view to it to read the next')
            #DISPLAY('page. Give two records the same sort value and those positions')
            #DISPLAY('stop identifying a record, so paging and the thumb can land in')
            #DISPLAY('the wrong place or stick.')
            #DISPLAY('')
            #DISPLAY('Naming a unique field here appends it to every order, which makes')
            #DISPLAY('the sort total and the positions dependable again. Duplicates are')
            #DISPLAY('commoner than they look - two customers of the same name is all')
            #DISPLAY('it takes.')
          #ENDBOXED
        #ENDTAB
        #TAB('How it sorts')
          #BOXED('How it sorts')
            #DISPLAY('Not the way the browse does. A Legacy browse picks its sort order')
            #DISPLAY('in SelectSort from CHOICE(?CurrentTab) - a generated ladder - so')
            #DISPLAY('setting SortOrder is pointless, it is recomputed on every refresh,')
            #DISPLAY('and only the orders defined at design time exist anyway.')
            #DISPLAY('')
            #DISPLAY('So the VIEW is given a PROP:Order instead, which can name any')
            #DISPLAY('field the view projects. The order goes on AFTER Reset has run,')
            #DISPLAY('because Reset CLOSEs and re-OPENs the view, and the refill goes')
            #DISPLAY('through FillRecord rather than RefreshPage, because RefreshPage')
            #DISPLAY('calls Reset again on an empty queue.')
            #DISPLAY('')
            #DISPLAY('The column''s field name is read with WHO() off the queue - a')
            #DISPLAY('Legacy browse labels its queue fields after the file fields they')
            #DISPLAY('came from, BRW1::CUS:NAME - so nothing has to be set per column.')
            #DISPLAY('A column whose queue field is not a file field cannot be sorted.')
          #ENDBOXED
        #ENDTAB
        #TAB('Rough edges')
          #BOXED('Known rough edges')
            #DISPLAY('Sorting a string column is case-SENSITIVE, where the browse''s own')
            #DISPLAY('order for a NOCASE key wraps the field in UPPER(). So a clicked')
            #DISPLAY('heading and the matching tab can order mixed-case data differently.')
            #DISPLAY('')
            #DISPLAY('Changing tab hands the order back to the browse and clears the')
            #DISPLAY('triangle, because the new tab would otherwise show its own records')
            #DISPLAY('in the old order.')
          #ENDBOXED
        #ENDTAB
      #ENDSHEET
    #ENDBUTTON
  #ENDTAB
  #TAB('&Look')
    #BOXED('Type')
      #PROMPT('&Font:',@s32),%bglFont,DEFAULT('Segoe UI')
      #PROMPT('&Size (points):',SPIN(@n3,6,24,1)),%bglSize,DEFAULT(9)
      #PROMPT('&Row height (pixels, 0 = follow the browse):',SPIN(@n3,0,80,1)),%bglRowH,DEFAULT(0)
      #PROMPT('&Header height (pixels, 0 = from the font):',SPIN(@n3,0,80,1)),%bglHdrH,DEFAULT(0)
      #PROMPT('&Wrap text that is too long for its column',CHECK),%bglWrap,DEFAULT(0),AT(10)
      #ENABLE(%bglWrap)
        #PROMPT('  &Lines a cell may use:',SPIN(@n1,2,4,1)),%bglWrapLines,DEFAULT(2)
        #ENABLE(%bglLoad = 'File loaded')
          #PROMPT('  &Grow rows only as needed',CHECK),%bglVarRows,DEFAULT(0),AT(10)
        #ENDENABLE
      #ENDENABLE
      #DISPLAY('Every row grows to hold the allowed lines - all rows stay ONE')
      #DISPLAY('height, so paging, the thumb and the browse''s page size simply')
      #DISPLAY('follow. The wrapping itself is DirectWrite''s; a cell shows up')
      #DISPLAY('to 128 characters.')
      #DISPLAY('')
      #DISPLAY('Grow rows only as needed keeps each row at ONE line unless its')
      #DISPLAY('own text wraps - the grid measures every cell and the tallest')
      #DISPLAY('one sets its row. File loaded only: the page size becomes')
      #DISPLAY('content-dependent, and only that mode owns its paging outright.')
    #ENDBOXED
  #ENDTAB
  #TAB('Colo&urs')
    #BOXED('Colours')
      #PROMPT('&Background:',COLOR),%bglCBack,DEFAULT(00FFFFFFH)
      #PROMPT('&Banding (every other row):',COLOR),%bglCBand,DEFAULT(00FAF7F5H)
      #PROMPT('&Gridlines:',COLOR),%bglCGrid,DEFAULT(00EAE5E1H)
      #PROMPT('&Text:',COLOR),%bglCText,DEFAULT(0033291FH)
      #PROMPT('Header b&ackground:',COLOR),%bglCHdrBack,DEFAULT(004A3A2BH)
      #PROMPT('Header te&xt:',COLOR),%bglCHdrText,DEFAULT(00FFFFFFH)
      #PROMPT('&Selected row:',COLOR),%bglCSelBack,DEFAULT(00B56F2FH)
      #PROMPT('Selected te&xt:',COLOR),%bglCSelText,DEFAULT(00FFFFFFH)
    #ENDBOXED
  #ENDTAB
#ENDSHEET
#!-----------------------------------------------------------------------------
#AT(%DataSection),WHERE(%bglDisable=0 AND %bglList)
#!  STOP AT GENERATION IF IT IS NOT A LIST. The CONTROL prompt offers every
#!  control in the window and REQ only enforces "something was chosen", so a
#!  PANEL is accepted as readily as the browse. Everything then fails quietly:
#!  PROPLIST reads come back empty, so there are no columns; PROP:Items and
#!  PROP:LineHeight are meaningless, so the browse is never resized; CHOICE()
#!  is 0; GETPOSITION returns the panel's corner, so the grid is drawn wherever
#!  the panel happens to be; and WS_VISIBLE is stripped from the panel, so the
#!  browse is never concealed. None of that looks like a wrong control - it
#!  looks like a broken template. Say so here instead.
#FOR(%Control),WHERE(%Control = %bglList)
  #IF(%ControlType <> 'LIST')
    #ERROR('BrowseGridLeg on ' & %Procedure & ': "' & %bglList & '" is a ' & %ControlType & ', not a LIST. Set "LIST control to take over" to the browse.')
    #ABORT
  #ENDIF
#ENDFOR
BGL:Resized:%bglObject EQUATE(EVENT:User + 240 + %ActiveTemplateInstance)
BGL:Refill:%bglObject  EQUATE(EVENT:User + 120 + %ActiveTemplateInstance)
%bglObject:G          LONG                                    ! the grid, 0 = not running
%bglObject:Rgn        SIGNED                                  ! the region it is drawn on
%bglObject:Cols       LONG                                    ! how many columns came over
%bglObject:Fld        LONG,DIM(32)                            ! queue field behind each column
%bglObject:Col        LONG,DIM(32)                            ! LIST column behind each grid one
%bglObject:Pic        STRING(32),DIM(32)                      ! and its picture, if it has one
%bglObject:Face       CSTRING(33)
%bglObject:Cell       CSTRING(129)                            ! G_TEXT's size: shorter cut long text at
                                                              ! 64 chars, which looks exactly like text
                                                              ! that refuses to wrap
%bglObject:Sel        LONG
%bglObject:Clipped    BYTE                                    ! has the LIST been made invisible?
%bglObject:Fills      LONG                                    ! how many times it has been refilled
%bglObject:Ready      BYTE                                    ! has Setup run? guards the refresh hook
%bglObject:Barred     BYTE                                    ! is the region subclassed for scrolling?
%bglObject:ScrollX    LONG                                    ! how far sideways the columns are
%bglObject:VDrag      BYTE                                    ! is the downward thumb being dragged?
%bglObject:VGrab      LONG                                    ! and where it was taken hold of
%bglObject:VPos       LONG                                    ! where the drag has got to, 0..100
%bglObject:HDrag      BYTE                                    ! the sideways thumb, being dragged
%bglObject:HGrab      LONG
%bglObject:SortCol    LONG                                    ! heading just clicked, 0-based, -1 none
%bglObject:SortOn     LONG                                    ! LIST column the mark is on, 0 none
%bglObject:SortDir    LONG                                    ! 1 ascending, -1 descending
%bglObject:SortSeen   LONG                                    ! the browse's own sort order, as last seen
%bglObject:RzCol      LONG                                    ! column being dragged, 1-based, 0 = none
%bglObject:RzX        LONG                                    ! where the drag started
%bglObject:RzW        LONG                                    ! and how wide the column was then
%bglObject:RzArmed    BYTE                                    ! on an edge, but has it MOVED yet?
%bglObject:RzCur      BYTE                                    ! is the sizing cursor showing?
%bglObject:Order      CSTRING(81)                             ! page loaded: the PROP:Order we imposed
%bglObject:QOrder     CSTRING(81)                             ! file loaded: the same sort, in QUEUE field names
%bglObject:QFld1      LONG                                    ! file loaded: the sort column's queue field number
%bglObject:QStr1      BYTE                                    ! file loaded: is it text - then sort case-blind
%bglObject:DefDone    BYTE                                    ! has the opening sort been applied yet?
%bglObject:FillEnd    BYTE                                    ! next BGL:Order fills from the END, not the top
%bglObject:Top        LONG                                    ! file-loaded: first VISIBLE row, 0-based
%bglObject:Count      LONG                                    ! file-loaded: records resident in the queue
%bglObject:Loaded     BYTE                                    ! file-loaded: has the load been done?
%bglObject:VOpen      BYTE                                    ! file-loaded: has the view been primed open once?
%bglObject:Full       LONG                                    ! file-loaded: records in the WHOLE queue
%bglObject:LoadMS     LONG                                    ! file-loaded: how long the last load took, ms
#IF(%bglWrap AND %bglVarRows AND %bglLoad = 'File loaded')
%bglObject:BtmFix     BYTE                                    ! bottom-anchor pass: 0 normal, 1 probing, 2 landing
%bglObject:BtmTop     LONG                                    ! Top the last landing settled on...
%bglObject:BtmN       LONG                                    ! ...at this Count; 0 = no landing stands
%bglObject:MeasN      LONG                                    ! Count the grid's window was pushed from
#ENDIF
%bglObject:Expr       CSTRING(1025)                           ! criteria filter for the VIEW, '' = none
%bglObject:FBtn       LONG                                    ! the filter-bar button, 0 = none placed
#IF(%bglChooser)
%bglObject:CHide      BYTE,DIM(64)                            ! columns the USER hid, by LIST column number
#ENDIF
%bglObject:COrd       LONG,DIM(64)                            ! the LIST columns in draw order; [1]=0 = not built
#IF(%bglMovable)
%bglObject:MvCol      LONG                                    ! drawn column a drag may move, 1-based, 0 none
%bglObject:MvX        LONG                                    ! where that press landed
%bglObject:MvOn       BYTE                                    ! it has MOVED: this is a carry, not a click
#ENDIF
%bglObject:FileN      LONG                                    ! RECORDS(file) as of the last load
%bglObject:WasFileN   LONG                                    ! ...and before the disturbance
%bglObject:FiltText   CSTRING(64)                             ! search text, '' = show everything
%bglObject:FiltScope  BYTE                                    ! 0 starts-with on sort column, 1 contains anywhere
%bglObject:FiltOn     BYTE                                    ! is a search or a filter narrowing the view?
#IF(%bglFilterBtns AND %bglLoad = 'File loaded')
%bglObject:FVal       STRING(64),DIM(32)                      ! per-column filter value, uppercased, '' = off
%bglObject:FOn        BYTE,DIM(32)                            ! which drawn columns are filtered
%bglObject:FAny       BYTE                                    ! any of them? saves scanning the array
%bglObject:FiltCol    LONG                                    ! heading button just clicked, 0-based
#ENDIF
%bglObject:Echo       LONG                                    ! the search box control, 0 = none placed
%bglObject:EchoX      LONG                                    ! ...and its clear button, 0 = none
%bglObject:LstF       SIGNED                                  ! the LIST's field number, for others to SELECT
BGLF:%bglObject       QUEUE,PRE()                             ! the VISIBLE rows: references into the queue
%bglObject:Ref          LONG                                  !   ordinal of this visible row in the queue
                      END
BGLK:%bglObject       QUEUE,PRE()                             ! decorate-sort-undecorate scratch, see BGL:SortQ
%bglObject:KKey         STRING(64)                            !   the sort column's value, uppercased
%bglObject:KOrd         LONG                                  !   the record it came from, pre-sort ordinal
                      END
#IF(%bglLoad = 'File loaded' AND %bglSortTie)
%bglObject:Find       LIKE(%bglSortTie)                       ! the record to re-find after a reload
%bglObject:HaveFind   BYTE                                    ! ...is there one?
%bglObject:WasCount   LONG                                    ! how many there were before it
%bglObject:SelFind    LIKE(%bglSortTie)                       ! who is selected, kept while the queue stands
%bglObject:HaveSel    BYTE                                    ! ...and is that capture trustworthy?
#ENDIF
#ENDAT
#!-----------------------------------------------------------------------------
#!  TRIGGER 1 of 5 - Init.  ABC: WindowManager.Init, PRIORITY(8800).
#!  %AfterWindowOpening generates after OPEN(window) and, importantly, AFTER
#!  the global inter-line PROP:LineHeight loop in STANDARD.TPW - so the row
#!  height BGL:Rows sets is not overwritten a line later.
#AT(%AfterWindowOpening),WHERE(%bglDisable=0 AND %bglList)
  DO BGL:Setup:%bglObject
#ENDAT
#!-----------------------------------------------------------------------------
#!  TRIGGER 2 of 5 - the refill.  ABC: WindowManager.Reset / TakeNewSelection.
#!  Everything that changes what the browse is showing - a scroll, a locator, a
#!  new sort, a tab, an insert or delete, a reset field changing - ends up in
#!  RefreshWindow. This is the last thing in it before DISPLAY().
#AT(%RefreshWindowBeforeDisplay),WHERE(%bglDisable=0 AND %bglList)
  IF %bglObject:Ready AND %bglObject:G
    DO BGL:Fill:%bglObject
  END
#ENDAT
#!-----------------------------------------------------------------------------
#!  KEEPING THE SORT ALIVE THROUGH Reset.
#!
#!  Reset does CLOSE(view) ... OPEN(view), and the CLOSE takes PROP:Order with
#!  it. Everything that starts the browse afresh goes through Reset - a tab, a
#!  resize (DoResize sets ForceRefresh and SelectSort answers with a Reset), and
#!  ScrollEnd, which is what EVENT:ScrollBottom calls. So a custom sort could not
#!  survive being scrolled to the end of the file: Reset dropped the order,
#!  ScrollEnd filled backward through the DEFAULT order, and the grid then
#!  noticed the mismatch and reloaded from the top - which is why dragging the
#!  thumb to the bottom landed back on the first page.
#!
#!  THE OBVIOUS SEAM IS NOT AVAILABLE TO US. %AfterOpeningListView is generated
#!  between Reset's OPEN(view) and its SET(view), which is exactly where the
#!  assignment belongs - but it is declared inside the BrowseBox CONTROL template
#!  (CtlBrow.TPW), and a control template's embeds are not addressable by #AT
#!  from a separate extension: generation fails with "Unknown Variable
#!  '%AfterOpeningListView'". Only the procedure and program templates'
#!  embeds - Window.TPW, STANDARD.TPW, Program.TPW - can be reached from here.
#!  It can still be filled BY HAND in the embed editor, and one line there
#!      IF Grid1:Order THEN BRW1::View:Browse{PROP:Order} = Grid1:Order.
#!  would make every Reset carry the sort. The template cannot put it there.
#!
#!  So the order is re-applied after the fact instead, in BGL:Fill, and the two
#!  ends of the file are handled here rather than being left to ScrollEnd.
#!-----------------------------------------------------------------------------
#!  TRIGGER 3 of 5 - our own events.  ABC: WindowManager.TakeWindowEvent.
#!  %WindowEventHandling cannot carry these: it is parameterised by event name
#!  and the name list is closed. %EventCaseBeforeGenerated is inside CASE
#!  EVENT() ahead of the generated OF clauses, which is all this needs.
#AT(%EventCaseBeforeGenerated),WHERE(%bglDisable=0 AND %bglList)
    OF BGL:Resized:%bglObject
!  The LIST has settled somewhere - at open, or after the resizer has run.
!  Follow it, resize the render target, and let the browse reload to suit.
      IF %bglObject:G
        DO BGL:Place:%bglObject
        d2g_Resize(%bglObject:G)
#IF(%bglWrap AND %bglVarRows AND %bglLoad = 'File loaded')
        %bglObject:BtmN = 0                                   ! new client height: a landing that ended at the
                                                              ! old bottom may leave a strip under the new one
#ENDIF
        DO BGL:Items:%bglObject
#IF(%bglSortField)
        IF ~%bglObject:DefDone
          %bglObject:DefDone = 1
          DO BGL:SortDefault:%bglObject                       ! the opening sort, once
        END
#ENDIF
        DO BGL:Fill:%bglObject
      END
    OF BGL:Refill:%bglObject
      IF %bglObject:G
        DO BGL:Fill:%bglObject
        d2g_PaintNow(%bglObject:G)
      END
#ENDAT
#!
#!  A Legacy window posts DoResize to itself on EVENT:Sized and does its
#!  RefreshWindow there. Posting rather than moving the region now puts us
#!  behind the resizer, which has not yet given the LIST its new size.
#!-----------------------------------------------------------------------------
#!  DON'T REBUILD THE BROWSE JUST BECAUSE THE WINDOW CAME BACK.
#!
#!  The generated GainFocus handler sets ForceRefresh and calls RefreshWindow,
#!  which sends SelectSort through a full Reset and refill. Click onto another
#!  window and back and you have lost your place - and in file-loaded mode you
#!  have lost more than that: the queue is rebuilt as one page, our reload puts
#!  the file back, and the sort order and selection go with it.
#!
#!  %WindowEventHandling('GainFocus') generates AHEAD of that block, so CYCLE
#!  here restarts the ACCEPT loop and none of it runs.
#!
#!  Guarded on WindowInitialized because the SAME block carries the first-time
#!  InitializeWindow call. OpenWindow normally gets there first, but a window
#!  that somehow gained focus before opening would never initialise at all if
#!  this cycled unconditionally. Guarded on the grid too: if it never started,
#!  leave the browse behaving exactly as Clarion always made it behave.
#AT(%WindowEventHandling,'GainFocus'),WHERE(%bglDisable=0 AND %bglList AND %bglKeepFocus)
  IF %bglObject:G AND WindowInitialized
    CYCLE
  END
#ENDAT
#!
#AT(%WindowEventHandling,'DoResize'),WHERE(%bglDisable=0 AND %bglList)
  IF %bglObject:G
    POST(BGL:Resized:%bglObject)
  END
#ENDAT
#!-----------------------------------------------------------------------------
#!  TRIGGER 4 of 5 - the mouse.  ABC: WindowManager.TakeFieldEvent.
#!  Not CASE FIELD(): the region is a control NUMBER in a variable, not a
#!  ?label, so it cannot be an OF clause. %AcceptLoopBeforeFieldHandling sits
#!  just outside that CASE and an IF does the same job.
#AT(%AcceptLoopBeforeFieldHandling),WHERE(%bglDisable=0 AND %bglList)
#IF(%bglLoad = 'File loaded')
!  TAKE THE BROWSE'S SCROLL EVENTS BEFORE THE BROWSE DOES.
!
!  The LIST keeps the focus - it is the only focusable control involved - so an
!  arrow key still arrives as EVENT:ScrollUp on the LIST, exactly as it always
!  did. What must not happen now is the browse ACTING on it: ProcessScroll would
!  call ScrollOne, which calls FillRecord, which ADDs and DELETEs against the
!  PROP:Items cap and shreds a queue holding the whole file.
!
!  CYCLE is what prevents that. This embed generates INSIDE the ACCEPT loop and
!  BEFORE its CASE FIELD(), so cycling here restarts the loop and the browse's
!  own handler is never reached for these events. Handled and swallowed.
  IF %bglObject:G AND FIELD() = %bglList
    CASE EVENT()
    OF EVENT:ScrollUp OROF EVENT:ScrollDown                                     |
       OROF EVENT:PageUp OROF EVENT:PageDown                                    |
       OROF EVENT:ScrollTop OROF EVENT:ScrollBottom OROF EVENT:ScrollDrag
      DO BGL:Keys:%bglObject
      CYCLE
    OF EVENT:AlertKey
!  TYPE-TO-SEARCH, the way a Clarion locator always let you: typing lands in
!  the search box even though the LIST has the focus. Only when a box has
!  registered itself (Echo), and only for characters and backspace - anything
!  else falls THROUGH, uncycled, so the browse's own alerted keys (Insert,
!  Delete, CtrlEnter, the popup) keep working exactly as before.
      IF %bglObject:Echo
        IF KEYCODE() = BSKey
!  No CLIP anywhere in this block: FiltText is a CSTRING, so LEN() is its real
!  length and there is no padding to strip - while CLIP would eat a trailing
!  space the user just deliberately typed ("southern " on the way to a name).
          IF LEN(%bglObject:FiltText)
            %bglObject:FiltText = SUB(%bglObject:FiltText,1,LEN(%bglObject:FiltText) - 1)
          END
          %bglObject:Echo{PROP:ScreenText} = %bglObject:FiltText
          IF %bglObject:EchoX
            %bglObject:EchoX{PROP:Hide} = CHOOSE(~%bglObject:FiltText,1,0)
          END
          DO BGL:Refilter:%bglObject
          CYCLE
        ELSIF KEYCODE() = SpaceKey OR KEYCHAR() > 31
!  SpaceKey by name, not through KEYCHAR(): an ALERTED key does not carry a
!  character - KEYCHAR() answers 0 for it - and space only ever arrives here
!  because we alerted it. Letters arrive down the LIST's own printable-key
!  path, which does populate KEYCHAR(). ABC's IncrementalLocatorClass.TakeKey
!  has this exact CHOOSE for this exact reason (abbrowse.clw ~1992).
          %bglObject:FiltText = %bglObject:FiltText & |
                                CHOOSE(KEYCODE() = SpaceKey,' ',CHR(KEYCHAR()))
          %bglObject:Echo{PROP:ScreenText} = %bglObject:FiltText
          IF %bglObject:EchoX
            %bglObject:EchoX{PROP:Hide} = 0                   ! text just arrived: show the x
          END
          DO BGL:Refilter:%bglObject
          CYCLE
        END
      END
    END
  END
#ENDIF
  IF %bglObject:G AND %bglObject:Rgn AND FIELD() = %bglObject:Rgn
    CASE EVENT()
    OF EVENT:MouseDown
      DO BGL:Hit:%bglObject
#IF(%bglBars OR %bglSizeable OR %bglMovable)
    OF EVENT:MouseMove
      DO BGL:Drag:%bglObject
    OF EVENT:MouseUp
#IF(%bglBars)
      IF %bglObject:VDrag
        %bglObject:VDrag = 0
        DO BGL:DragEnd:%bglObject
      END
      %bglObject:HDrag = 0
#ENDIF
#IF(%bglSizeable)
      IF %bglObject:RzCol
        DO BGL:SizeEnd:%bglObject
      END
#ENDIF
#IF(%bglMovable)
      IF %bglObject:MvCol
        DO BGL:MoveEnd:%bglObject
      END
#ENDIF
#IF(%bglBars AND %bglBarStyle = 'Overlay')
    OF EVENT:MouseIn
      d2g_BarsShow(%bglObject:G,1)
    OF EVENT:MouseOut
      d2g_BarsShow(%bglObject:G,0)
#ENDIF
#ENDIF
    END
  END
#ENDAT
#!-----------------------------------------------------------------------------
#!  THE SCROLL CALLBACK'S ANSWER. Deliberately NOT an OF clause in the window's
#!  CASE EVENT(): BGL:Scrolled is one global equate shared by every grid, so two
#!  grids on one window would generate the same OF twice and the procedure would
#!  not compile. Roberto's ABC version is immune because each instance builds a
#!  CASE of its own inside its own method embed; here we are all in the one CASE.
#!  An IF outside it has neither problem, and LastG says which grid it was - the
#!  original could not tell, so with two grids both answered every scroll.
#AT(%AcceptLoopAfterEventHandling),WHERE(%bglDisable=0 AND %bglList)
#IF(%bglBars OR %bglWheel)
  IF EVENT() = BGL:Scrolled AND %bglObject:G AND BGL:LastG = %bglObject:G
    DO BGL:Scroll:%bglObject
  END
#ENDIF
#ENDAT
#!-----------------------------------------------------------------------------
#!  TRIGGER 5 of 5 - Kill.  ABC: WindowManager.Kill, PRIORITY(2000).
#!  Give the LIST back before anything is taken down, so a window that gives up
#!  on the grid still has a working browse behind it.
#AT(%BeforeWindowClosing),WHERE(%bglDisable=0 AND %bglList)
  DO BGL:Remember:%bglObject                                  ! before anything is taken down
  DO BGL:Reveal:%bglObject
  IF %bglObject:Barred
    BGL_DropBars(%bglObject:Rgn{PROP:Handle})                 ! unsubclass before it goes
    %bglObject:Barred = 0
  END
  IF %bglObject:G
    d2g_Detach(%bglObject:G)
    %bglObject:G = 0
  END
  %bglObject:Ready = 0
#ENDAT
#!-----------------------------------------------------------------------------
#!  THE WORK. Every one of these is family-neutral - this whole section is
#!  copied from the ABC original with only the symbol names changed, which is
#!  the finding that made the port worth doing.
#AT(%ProcedureRoutines),WHERE(%bglDisable=0 AND %bglList)
BGL:Setup:%bglObject ROUTINE
!  Put a region exactly where the LIST is, conceal the LIST, and hand the region
!  to the grid. The LIST stays in the window doing its job - it is simply not
!  the thing you look at any more, which is why the browse carries on working.
  IF ~d2g_Available() THEN EXIT.                              ! no Direct2D: leave the LIST alone
  %bglObject:LstF = %bglList                                  ! so the search box can SELECT it back
!  THE BROWSE MUST BE WILLING TO WORK INVISIBLE, because in a moment it will be.
!  Reset, RefreshPage and Fill each begin with
!      IF NOT <prefix>::ActiveInvisible THEN
!         IF NOT ?List{PROP:Visible} THEN ... EXIT
!  and that field is generated as BYTE(%GlobalBrowseActiveInvisible) - an
!  APPLICATION-level checkbox (CW.TPL) that merely happens to default to true.
!  So a grid that works today would stop working the day somebody unticked a
!  global they had no reason to connect with it, and the failure would be a
!  browse that silently never fills. Set it here and depend on nothing.
  %bglBrowseObj::ActiveInvisible = True
  IF ~%bglObject:Rgn
    %bglObject:Rgn = CREATE(0,CREATE:Region,%bglList{PROP:Parent})
    %bglObject:Rgn{PROP:IMM} = 1                              ! or no mouse events arrive
  END
  DO BGL:Place:%bglObject
  UNHIDE(%bglObject:Rgn)
  %bglObject:Face = '%bglFont'
  %bglObject:G = d2g_Attach(%bglObject:Rgn{PROP:Handle},%bglObject:Face,%bglSize)
  IF ~%bglObject:G
    HIDE(%bglObject:Rgn)                                      ! could not start: leave the LIST alone
    EXIT
  END
  DO BGL:Recall:%bglObject                                    ! widths, before they are read
  DO BGL:Columns:%bglObject
  IF ~%bglObject:Cols
!  Nothing came off the LIST. The generation-time assert should have caught the
!  usual cause - a control that is not a LIST - but a browse whose columns are
!  all zero-width would land here too. Either way an empty grid sitting over a
!  browse nobody can see is worse than no grid, so put everything back.
    DO BGL:Reveal:%bglObject
    d2g_Detach(%bglObject:G)
    %bglObject:G = 0
    HIDE(%bglObject:Rgn)
    EXIT
  END
  DO BGL:Conceal:%bglObject                                   ! only now the grid can be seen
#IF(%bglWrap)
!  Wrapping goes on BEFORE the row heights are agreed: d2g_Wrap grows the
!  grid's own row height, d2g_RowNeed answers the taller number from here on,
!  and BGL:Rows carries it into the LIST's line height - so the browse loads
!  exactly as many records as the taller page can show, and nothing else has
!  to know the rows changed size.
  d2g_Wrap(%bglObject:G,1,%bglWrapLines)
#IF(%bglVarRows AND %bglLoad = 'File loaded')
!  ...and rows grow only as far as their own text needs. The grid measures the
!  pushed cells and draws each row at one line unless it wrapped; the row
!  height d2g_RowNeed answers stays the full allowance - it is the worst case
!  the paging arithmetic below leans on.
  d2g_VarRows(%bglObject:G,1)
#ENDIF
#ENDIF
  DO BGL:Rows:%bglObject
  DO BGL:Items:%bglObject                                     ! load what there is room to draw
#IF(%bglHdrH > 0)
  d2g_HeaderHeight(%bglObject:G,%bglHdrH)
#ENDIF
#IF(%bglBars OR %bglWheel)
#IF(%bglBarStyle = 'Windows')
  IF BGL_HookBars(%bglObject:Rgn{PROP:Handle},0)              ! the roller comes through here too
#ELSE
  IF BGL_HookBars(%bglObject:Rgn{PROP:Handle},1)              ! drawn bars: hooked only for the roller
#ENDIF
    %bglObject:Barred = 1
  END
#ENDIF
#IF(%bglBarStyle = 'Slim')
  d2g_BarStyle(%bglObject:G,1)
#ELSIF(%bglBarStyle = 'Overlay')
  d2g_BarStyle(%bglObject:G,2)
#ELSE
  d2g_BarStyle(%bglObject:G,0)
#ENDIF
#!  NO KEY ALERTS ON THE REGION. A REGION takes mouse events through PROP:IMM but
#!  it cannot take the FOCUS - it is not a focusable control - so SELECT() on it
#!  does nothing and PROP:Alrt never fires, because an alert needs the focus.
#!  Trying that left file-loaded mode with no keyboard at all and no way to pick a
#!  row. The LIST keeps the focus in both modes, exactly as it always did; what
#!  file-loaded changes is that the browse is not allowed to ACT on the keys.
#!  See %AcceptLoopBeforeFieldHandling, where they are taken and CYCLEd past.
#IF(%bglLoad = 'File loaded')
!  TYPE-TO-SEARCH. On an IMM LIST, printable keystrokes already arrive as
!  EVENT:AlertKey without any PROP:Alrt - which is why ABC's own incremental
!  locator alerts only BSKey and SpaceKey, the two the LIST would otherwise
!  consume, and reads the character with KEYCHAR(). Same recipe here. Slots
!  248/249: the browse's own alerts sit at 252-255 and ABC's at 250/251.
  %bglList{PROP:Alrt,248} = BSKey
  %bglList{PROP:Alrt,249} = SpaceKey
#ENDIF
  d2g_Frozen(%bglObject:G,%bglFrozen)
#IF(%bglFilterBtns AND %bglLoad = 'File loaded')
  d2g_FilterBtns(%bglObject:G,1)                              ! the chevron/triangle/funnel button
#ENDIF
  d2g_Colours(%bglObject:G,BGL_Rgb(%bglCBack),BGL_Rgb(%bglCBand),               |
              BGL_Rgb(%bglCGrid),BGL_Rgb(%bglCText),                            |
              BGL_Rgb(%bglCHdrBack),BGL_Rgb(%bglCHdrText),                      |
              BGL_Rgb(%bglCSelBack),BGL_Rgb(%bglCSelText))
#IF(%bglSortHdr OR %bglSortField)
  %bglObject:SortCol  = -1                                    ! nothing clicked yet
  %bglObject:SortSeen = %bglBrowseObj::SortOrder              ! so a tab change is noticed, not the first fill
#ENDIF
  %bglObject:Ready = 1                                        ! the refresh hook may fire from here on
  DO BGL:Fill:%bglObject
!  ...and place it again once the window has finished opening. Right now the
!  LIST is still where the DESIGNER put it: the resizer has not run, and a
!  window that opens maximised is about to move it.
  POST(BGL:Resized:%bglObject)

BGL:Place:%bglObject ROUTINE
!  Sit the region exactly on the LIST and keep it on top. The LIST is not moved
!  and not hidden - it is left where the resizer wants it, doing everything it
!  did before.
  DATA
x SIGNED,AUTO
y SIGNED,AUTO
w SIGNED,AUTO
h SIGNED,AUTO
  CODE
  IF ~%bglObject:Rgn THEN EXIT.
  GETPOSITION(%bglList,x,y,w,h)
  SETPOSITION(%bglObject:Rgn,x,y,w,h)
  IF %bglObject:G
    DO BGL:Conceal:%bglObject                                 ! a resize can bring it back
  END
!  and raise the region above it, every time, because a resize can restack them
  bglApi_SetWindowPos(%bglObject:Rgn{PROP:Handle},BGL:HwndTop,0,0,0,0,          |
                      BOR(BGL:NoMove,BGL:NoSize))

BGL:Columns:%bglObject ROUTINE
!  Read the columns off the LIST as they stand. Every PROPLIST read goes through
!  a LONG first: a property comes back as a STRING, and the STRING '0' is
!  logically TRUE, so a hidden column would otherwise look visible.
  DATA
c    LONG,AUTO
n    LONG,AUTO
i2   LONG,AUTO
ex   LONG,AUTO
fld  LONG,AUTO
wid  LONG,AUTO
algn LONG,AUTO
p    LONG,AUTO
head CSTRING(65)
  CODE
!  The draw ORDER is its own array, so reordering is a permutation and nothing
!  else. First call finds it unbuilt and writes the natural order; Recall may
!  already have written a remembered one, which [1] <> 0 protects. Columns
!  beyond 64 do not take part - the drawn cap has always been 32 anyway.
  IF ~%bglObject:COrd[1]
    LOOP c = 1 TO 64
      %bglObject:COrd[c] = c
    END
  END
  n = 0
  LOOP i2 = 1 TO 64
    c = %bglObject:COrd[i2]
    IF ~c OR c > 64 THEN CYCLE.
    ex = %bglList{PROPLIST:Exists,c}
    IF ~ex THEN CYCLE.                                        ! a remembered order can outlive a column
    fld = %bglList{PROPLIST:FieldNo,c}
    IF ~fld THEN CYCLE.                                       ! a decoration, not a data column
    wid = %bglList{PROPLIST:Width,c}
    IF wid < 1 THEN CYCLE.                                    ! hidden by the designer
#IF(%bglChooser)
    IF %bglObject:CHide[c] THEN CYCLE.                        ! hidden by the user
#ENDIF
    IF n >= 32 THEN BREAK.
    algn = 0
    p = %bglList{PROPLIST:Right,c}
    IF p THEN algn = 1.
    p = %bglList{PROPLIST:Decimal,c}
    IF p THEN algn = 1.
    p = %bglList{PROPLIST:Center,c}
    IF p THEN algn = 2.
    head = CLIP(%bglList{PROPLIST:Header,c})
    LOOP p = 1 TO LEN(head)                                   ! a bar wraps a heading on screen
      IF head[p] = '|' THEN head[p] = ' '.
    END
    head = CLIP(LEFT(head))
    %bglObject:Fld[n + 1] = fld
    %bglObject:Col[n + 1] = c
    %bglObject:Pic[n + 1] = CLIP(%bglList{PROPLIST:Picture,c})
    d2g_Column(%bglObject:G,n,wid * 2,algn,head)              ! LIST widths are dialog units
    n += 1
  END
  %bglObject:Cols = n
  d2g_Columns(%bglObject:G,n)

BGL:Rows:%bglObject ROUTINE
!  Make the grid and the browse agree on how tall a row is, because otherwise
!  they never agree on how long a PAGE is. A Legacy browse works out how many
!  records to load from PROP:Items, which the runtime derives from the LIST's
!  height and its line height; the grid works out how many it can draw from the
!  region's height and its row height. Let those differ and the browse loads
!  records the grid has no room for.
  DATA
sp   LONG,AUTO
lh   LONG,AUTO
need LONG,AUTO
  CODE
  IF ~%bglObject:G THEN EXIT.
  sp = 0{PROP:Pixels}
  0{PROP:Pixels} = 1
  need = d2g_RowNeed(%bglObject:G)
#IF(%bglRowH > 0)
  lh = %bglRowH                                               ! asked for: the BROWSE gives way
#ELSE
  lh = %bglList{PROP:LineHeight}                              ! nothing asked for: follow the browse
#ENDIF
  IF lh < need THEN lh = need.                                ! but never squash the type
  d2g_RowHeight(%bglObject:G,lh)
#IF(%bglWrap AND %bglVarRows AND %bglLoad = 'File loaded')
!  Variable rows: the LIST is synced at the BASE height - one line's worth -
!  because most rows will BE one line, and the grid divides the same lh by the
!  same count, so the two sides land on the same number. The full allowance
!  stays with the grid; PROP:Items only matters to update-refill paths that
!  reload anyway.
  %bglList{PROP:LineHeight} = lh / %bglWrapLines
  %bglObject:BtmN = 0                                         ! new heights: the old landing means nothing
#ELSE
  %bglList{PROP:LineHeight} = lh
#ENDIF
  0{PROP:Pixels} = sp

BGL:Items:%bglObject ROUTINE
!  Make the browse load as many records as the grid can DRAW, by changing the
!  LINE HEIGHT rather than the geometry. Verified in the Legacy generated
!  source: BRW#::ItemsToFill = ?List{PROP:Items}, and PROP:Items is the LIST
!  height divided by the line height - so this is arithmetic on a number that
!  is already invisible. Stretching the LIST instead would fight the resizer.
  DATA
sp    LONG,AUTO
lh    LONG,AUTO
items LONG,AUTO
fit   LONG,AUTO
newlh LONG,AUTO
  CODE
  IF ~%bglObject:G THEN EXIT.
  sp = 0{PROP:Pixels}
  0{PROP:Pixels} = 1
  lh    = %bglList{PROP:LineHeight}
  items = %bglList{PROP:Items}
#IF(%bglWrap AND %bglVarRows AND %bglLoad = 'File loaded')
!  Variable rows: aim the browse at the OPTIMISTIC page - the rows it can show
!  when none of them wrap - so an update-refill loads enough records to fill
!  the screen whatever the mix turns out to be. d2g_PageMax for the same
!  reason BGL:Fill uses it: PageSize times the allowance rounds short.
  fit   = d2g_PageMax(%bglObject:G)
#ELSE
  fit   = d2g_PageSize(%bglObject:G)
#ENDIF
  IF lh > 0 AND items > 0 AND fit > 0 AND fit <> items
    newlh = items * lh / fit
    IF newlh < 2 THEN newlh = 2.
    %bglList{PROP:LineHeight} = newlh
  END
  0{PROP:Pixels} = sp

BGL:Conceal:%bglObject ROUTINE
!  Take WS_VISIBLE off the LIST at the WINDOWS level. Not HIDE(): the browse
!  works out how many rows to load from the control's own state, and a hidden
!  browse decides it has none. WS_VISIBLE is Windows' flag, not Clarion's -
!  strip it and Windows stops painting and hit-testing the control, while
!  PROP:Hide, the queue and the visible-row count are all untouched.
  DATA
sty LONG,AUTO
  CODE
  sty = bglApi_GetWindowLong(%bglList{PROP:Handle},BGL:GwlStyle)
  IF BAND(sty,BGL:Visible)
    bglApi_SetWindowLong(%bglList{PROP:Handle},BGL:GwlStyle,                    |
                         BAND(sty,BXOR(0FFFFFFFFh,BGL:Visible)))
    bglApi_SetWindowPos(%bglList{PROP:Handle},0,0,0,0,0,                        |
                        BOR(BOR(BGL:FrameChanged,BGL:NoMove),                   |
                            BOR(BGL:NoSize,BGL:NoZOrder)))
    %bglObject:Clipped = 1
  END

BGL:Reveal:%bglObject ROUTINE
!  ...and give it back.
  DATA
sty LONG,AUTO
  CODE
  IF ~%bglObject:Clipped THEN EXIT.
  sty = bglApi_GetWindowLong(%bglList{PROP:Handle},BGL:GwlStyle)
  bglApi_SetWindowLong(%bglList{PROP:Handle},BGL:GwlStyle,BOR(sty,BGL:Visible))
  bglApi_SetWindowPos(%bglList{PROP:Handle},0,0,0,0,0,                          |
                      BOR(BOR(BGL:FrameChanged,BGL:NoMove),                     |
                          BOR(BGL:NoSize,BGL:NoZOrder)))
  %bglObject:Clipped = 0

BGL:Load:%bglObject ROUTINE
!  FILE LOADED. Read the whole view into the queue, once.
!
!  The browse's own routines do the two hard parts: Reset sets the view up with
!  whatever filter and range limit the tab calls for, and FillQueue moves a view
!  record into the queue buffer with the right field mapping - which is what
!  saves this template from having to know the columns at generate time.
!  Everything after that is ours: the browse is not asked to fetch another
!  record for as long as the queue stands.
!
!  The limit is a guard, not a target. A view that unexpectedly matches the
!  whole file - a range limit that did not take, a filter that did not - should
!  stop rather than read for a minute.
#IF(%bglLoad = 'File loaded')
  DATA
n LONG,AUTO
t LONG,AUTO
f CSTRING(2100)
  CODE
  IF ~%bglObject:G THEN EXIT.
#IF(%bglWrap AND %bglVarRows AND %bglLoad = 'File loaded')
  %bglObject:BtmN = 0                                         ! new records: the old landing means nothing
#ENDIF
  SETCURSOR(Cursor:Wait)
  t = CLOCK()
  FREE(%bglQueue)
  %bglBrowseObj::RecordCount = 0
!  PRIME THE VIEW BEFORE THE BROWSE'S RESET GETS TO IT. This load can run before
!  the browse has ever chosen a sort order - Setup fills, the first fill loads -
!  and Reset in that state is a CLOSE of a view that has never been opened, a
!  CASE on a SortOrder of zero that matches nothing, and an IF ERRORCODE() that
!  reports whatever it finds lying around. The TopSpeed driver let that CLOSE
!  pass in silence; SQLite posts File Not Open (37), and the leftover code
!  surfaced as a spurious "View Open Error" box the moment the procedure opened.
!  One successful OPEN here gives Reset's CLOSE something real to close and
!  leaves ERRORCODE() cleared by an operation that succeeded. A view that
!  genuinely cannot open still says so: this OPEN, Reset's CLOSE and Reset's
!  own OPEN would all fail together.
  IF ~%bglObject:VOpen
    OPEN(%bglBrowseObj::View:Browse)
    %bglObject:VOpen = 1
  END
  DO %bglBrowseObj::Reset
!  THE CRITERIA FILTER GOES ON AFTER Reset, exactly as the sort's PROP:Order
!  does: Reset assigns PROP:Filter itself from the tab's CASE arms, so anything
!  set earlier is thrown away. ANDed with whatever Reset put there rather than
!  replacing it - the tab's own range condition must go on meaning what it
!  meant - and made current with SET(), the documented dance for changing a
!  property on an open view. The expression is runtime-evaluated, which is why
!  the generated BindFields matters: BIND has already been called for every
!  file buffer the expression can name.
  IF %bglObject:Expr
    f = %bglBrowseObj::View:Browse{PROP:Filter}
    IF f
      %bglBrowseObj::View:Browse{PROP:Filter} = '(' & CLIP(f) & ') AND (' & %bglObject:Expr & ')'
    ELSE
      %bglBrowseObj::View:Browse{PROP:Filter} = %bglObject:Expr
    END
    SET(%bglBrowseObj::View:Browse)
  END
  n = 0
  LOOP
    NEXT(%bglBrowseObj::View:Browse)
    IF ERRORCODE() THEN BREAK.
    DO %bglBrowseObj::FillQueue
    ADD(%bglQueue)
    IF ERRORCODE() THEN BREAK.                                ! out of memory: keep what we have
    n += 1
    IF n >= %bglMaxRecs THEN BREAK.
  END
!  How long the read took, for the diagnostics line. This times the driver
!  round-trips only - Reset through the NEXT loop - not the SORT or the map,
!  because the driver is the part that changed underneath us and the part
!  fetch-ahead would fix. CLOCK() counts hundredths since midnight.
  t = CLOCK() - t
  IF t < 0 THEN t += 8640000.                                 ! crossed midnight
  %bglObject:LoadMS = t * 10
!  The browse is told the count as well. It has no work left to do, but its own
!  bounds checks read RecordCount and would otherwise think the queue empty.
  %bglBrowseObj::RecordCount = n
  %bglObject:Full   = n
  %bglObject:Loaded = 1
#IF(%bglFile)
!  The FILE's own count, for telling an insert from a change when a criteria
!  filter is on: a new record that fails the filter never reaches the queue,
!  so the queue counts alone would read an insert as a change and leave the
!  record invisible. The file cannot lie about this.
  %bglObject:FileN = RECORDS(%bglFile)
#ENDIF
#IF(%bglSortHdr OR %bglSortField)
!  PUT OUR ORDER BACK ON. The read above came through the VIEW, and Reset has just
!  pointed that at the key behind the current TAB - so a reload always arrives in
!  the browse's order, not ours. Sorting here rather than at the call sites means
!  every reload ends up in the right order whatever provoked it: after a delete,
!  after an insert, after coming back from a form. Missing it was why deleting a
!  record silently reverted a sort-by-ID browse to name order.
  IF %bglObject:QOrder
    DO BGL:SortQ:%bglObject
  END
#ENDIF
!  ...and rebuild the visible map over the fresh load. The map is what Count and
!  every row the grid draws come from - and because it reads FiltText, a search
!  that was in force survives the reload without anyone re-typing it.
  DO BGL:Map:%bglObject
  IF %bglObject:Sel >= %bglObject:Count THEN %bglObject:Sel = %bglObject:Count - 1.
  IF %bglObject:Sel < 0 THEN %bglObject:Sel = 0.
  DO BGL:Anchor:%bglObject
  SETCURSOR()
#ELSE
  EXIT
#ENDIF

BGL:Keys:%bglObject ROUTINE
!  FILE LOADED TAKES THE KEYBOARD. In page-loaded mode the LIST keeps the focus
!  and every key the browse ever answered goes on working, unwritten by us. Here
!  that would be destructive: a down-arrow reaching the LIST calls ScrollOne,
!  which calls FillRecord, which ADDs and DELETEs against the PROP:Items cap -
!  shredding a queue that is holding the whole file. So the region takes the
!  focus and the navigation keys are answered here, against Sel and Top.
!
!  Only navigation. Insert, Change and Delete are buttons on the window and are
!  reached as they always were; nothing here intercepts them.
#IF(%bglLoad = 'File loaded')
  DATA
page LONG,AUTO
  CODE
  IF ~%bglObject:G THEN EXIT.
  page = d2g_PageSize(%bglObject:G)
  IF page < 1 THEN page = 1.
!  Driven by the browse's own scroll EVENTS, not by keycodes. An IMM LIST turns
!  the navigation keys into these before we ever see them, so answering them here
!  covers the arrows, the page keys and Ctrl-Home/End without alerting anything.
  CASE EVENT()
  OF EVENT:ScrollUp
    %bglObject:Sel -= 1
  OF EVENT:ScrollDown
    %bglObject:Sel += 1
  OF EVENT:PageUp
    %bglObject:Sel -= page
  OF EVENT:PageDown
    %bglObject:Sel += page
  OF EVENT:ScrollTop
    %bglObject:Sel = 0
  OF EVENT:ScrollBottom
    %bglObject:Sel = %bglObject:Count - 1
  OF EVENT:ScrollDrag
!  The LIST's own thumb, which is invisible - only reachable by keyboard. Ours is
!  handled in BGL:DragEnd. Treat it as a proportional jump.
    %bglObject:Sel = (%bglList{PROP:VScrollPos} * (%bglObject:Count - 1)) / 100
  ELSE
    EXIT
  END
  DO BGL:Anchor:%bglObject
  DO BGL:Fill:%bglObject
#ELSE
  EXIT
#ENDIF

BGL:Map:%bglObject ROUTINE
!  Rebuild the map of VISIBLE rows. With no search text the map is bypassed
!  entirely - FiltOn 0, Count = Full, and every path reads the queue directly,
!  exactly as before searching existed. With text, the map holds one Ref per
!  matching queue row, Count is how many matched, and the fill, the hit test,
!  the keys and the thumb all work in visible-row space without knowing a
!  search is on. Called after every load and every SORT (the refs are ordinals,
!  so a re-sort invalidates all of them), and by BGL:Refilter when typing.
!
!  A linear walk per call, on purpose: even the all-columns case is a few
!  hundred thousand in-memory comparisons on a 10k file, which is nothing next
!  to the disk read that loaded it. Matching is case-blind on both sides.
#IF(%bglLoad = 'File loaded')
  DATA
i   LONG,AUTO
c   LONG,AUTO
hit LONG,AUTO
fld LONG,AUTO
txt CSTRING(64)
  CODE
  FREE(BGLF:%bglObject)
#IF(%bglWrap AND %bglVarRows AND %bglLoad = 'File loaded')
  %bglObject:BtmN  = 0                                        ! new visible set: the old landing means nothing
  %bglObject:MeasN = -1                                       ! and the measured heights are the OLD records' -
                                                              ! a re-sort keeps Count, Top and firstRow all equal,
                                                              ! so this is the only guard term that can notice.
                                                              ! -1, not 0: an empty browse compares equal at 0.
#ENDIF
!  NOT CLIPped: a trailing space is a real search character. With "Iskor" and
!  "Is kol" in the file, "is " has to narrow to "Is kol" alone - clipping the
!  text here made the space do nothing until the next letter arrived. FiltText
!  is a CSTRING kept pad-free at its sources, so there is no padding to strip.
  txt = UPPER(%bglObject:FiltText)
#IF(%bglFilterBtns)
  IF ~txt AND ~%bglObject:FAny
#ELSE
  IF ~txt
#ENDIF
    %bglObject:FiltOn = 0
    %bglObject:Count  = %bglObject:Full
    EXIT
  END
  %bglObject:FiltOn = 1
  LOOP i = 1 TO %bglObject:Full
    GET(%bglQueue,i)
    IF ERRORCODE() THEN BREAK.
    hit = 1
    IF txt                                                    ! the search's verdict first...
    hit = 0
    IF %bglObject:FiltScope = 0
!  Starts-with, against the sorted column - the classic locator's question,
!  asked of sorted data. No sort active means no sorted column: the first
!  drawn column stands in.
#IF(%bglSortHdr OR %bglSortField)
      fld = CHOOSE(%bglObject:SortCol >= 0,%bglObject:Fld[%bglObject:SortCol + 1],%bglObject:Fld[1])
#ELSE
      fld = %bglObject:Fld[1]
#ENDIF
      %bglObject:Cell = CLIP(LEFT(WHAT(%bglQueue,fld)))
      IF UPPER(SUB(%bglObject:Cell,1,LEN(txt))) = txt THEN hit = 1.
    ELSE
!  Contains, anywhere in any drawn column - what a search box means everywhere
!  else. Numbers take part through their display text, which is what WHAT()
!  hands back for a numeric queue field.
      LOOP c = 1 TO %bglObject:Cols
        %bglObject:Cell = CLIP(LEFT(WHAT(%bglQueue,%bglObject:Fld[c])))
        IF INSTRING(txt,UPPER(%bglObject:Cell),1,1)
          hit = 1
          BREAK
        END
      END
    END
    END
#IF(%bglFilterBtns)
!  ...then the column filters, ANDed on top: every filtered column must carry
!  the filtered value, compared the same way the menu collected it.
    IF hit AND %bglObject:FAny
      LOOP c = 1 TO %bglObject:Cols
        IF ~%bglObject:FOn[c] THEN CYCLE.
        %bglObject:Cell = CLIP(LEFT(WHAT(%bglQueue,%bglObject:Fld[c])))
        IF UPPER(%bglObject:Cell) <> CLIP(%bglObject:FVal[c])
          hit = 0
          BREAK
        END
      END
    END
#ENDIF
    IF hit
      %bglObject:Ref = i
      ADD(BGLF:%bglObject)
    END
  END
  %bglObject:Count = RECORDS(BGLF:%bglObject)
#ELSE
  EXIT
#ENDIF

BGL:Refilter:%bglObject ROUTINE
!  The search text changed - the locator control template routes every
!  keystroke here after writing FiltText and FiltScope. Remember which record
!  the selection was on, rebuild the map, and try to keep the selection on that
!  record if it survived the narrowing; a record that no longer matches leaves
!  the selection at the top of what does.
!
!  PAGE LOADED: does nothing, by design. The queue holds one page, so there is
!  nothing to search - the box sits inert. Legacy's own locator types remain
!  the answer for a page-loaded browse.
#IF(%bglLoad = 'File loaded')
  IF ~%bglObject:G OR ~%bglObject:Loaded THEN EXIT.
#IF(%bglSortTie)
  %bglObject:HaveFind = 0
  IF %bglObject:Count
    IF %bglObject:FiltOn
      GET(BGLF:%bglObject,%bglObject:Sel + 1)
      IF ~ERRORCODE() THEN GET(%bglQueue,%bglObject:Ref).
    ELSE
      GET(%bglQueue,%bglObject:Sel + 1)
    END
    IF ~ERRORCODE()
      %bglObject:Find     = %bglBrowseObj::%bglSortTie
      %bglObject:HaveFind = 1
    END
  END
#ENDIF
  DO BGL:Map:%bglObject
  %bglObject:Sel = 0
  %bglObject:Top = 0
#IF(%bglSortTie)
  IF %bglObject:HaveFind
    DO BGL:Locate:%bglObject
  END
#ENDIF
  DO BGL:Clamp:%bglObject
  DO BGL:Fill:%bglObject
#ELSE
  EXIT
#ENDIF

BGL:FiltMenu:%bglObject ROUTINE
!  The heading button was pressed: offer the column's values and filter on the
!  one picked. Excel reduced to a POPUP - one value per column, columns ANDed
!  together, the search box narrowing within them; '(All)' lifts this column's
!  filter and the last entry lifts every column's. The values on offer are the
!  column's DISTINCT values as the search sees them - WHAT()'s display text,
!  not the LIST picture - collected through the scratch queue: uppercased for
!  adjacency, the ordinal of the first bearer kept so the menu can show the
!  value in its natural case.
!
!  A tab change reloads the records but keeps these filters: they are values,
!  and the values mean the same thing in the new set. Two silent limits, both
!  deliberate: the menu shows the first 40 distinct values (a POPUP is not a
!  scrolling picker; the column chooser era can revisit this), and a value is
!  matched on its first 64 characters, same as the sort key.
#IF(%bglFilterBtns AND %bglLoad = 'File loaded')
  DATA
c    LONG,AUTO
fld  LONG,AUTO
i    LONG,AUTO
j    LONG,AUTO
n    LONG,AUTO
sel  LONG,AUTO
v    CSTRING(65)
prev CSTRING(65)
m    CSTRING(3000)
  CODE
  IF ~%bglObject:G THEN EXIT.
  c = %bglObject:FiltCol + 1
  IF c < 1 OR c > %bglObject:Cols THEN EXIT.
  fld = %bglObject:Fld[c]
  IF ~fld THEN EXIT.
  IF ~%bglObject:Loaded THEN DO BGL:Load:%bglObject.
  FREE(BGLK:%bglObject)
  LOOP i = 1 TO %bglObject:Full
    GET(%bglQueue,i)
    IF ERRORCODE() THEN BREAK.
    %bglObject:KKey = UPPER(CLIP(LEFT(WHAT(%bglQueue,fld))))
    %bglObject:KOrd = i
    ADD(BGLK:%bglObject)
  END
  SORT(BGLK:%bglObject,'+%bglObject:KKey,+%bglObject:KOrd')
  m    = '(All)'
  prev = '<13,10>'                                            ! no value can equal this
  n    = 0
  LOOP i = 1 TO RECORDS(BGLK:%bglObject)
    GET(BGLK:%bglObject,i)
    IF CLIP(%bglObject:KKey) = prev THEN CYCLE.
    prev = CLIP(%bglObject:KKey)
    n += 1
    IF n > 40 THEN BREAK.                                     ! the silent cap
!  The value in its own case, off the first record that carries it.
    GET(%bglQueue,%bglObject:KOrd)
    v = CLIP(LEFT(WHAT(%bglQueue,fld)))
!  POPUP's structure characters cannot ride along in data.
    LOOP j = 1 TO LEN(v)
      IF v[j] = '|' OR v[j] = '{{' OR v[j] = '}' THEN v[j] = '/'.
    END
    IF ~v THEN v = '(blanks)'.
!  The value this column is already filtered on wears the checkmark.
    IF %bglObject:FOn[c] AND prev = CLIP(%bglObject:FVal[c])
      m = m & '|+' & v
    ELSE
      m = m & '|' & v
    END
  END
  IF n > 40 THEN n = 40.
  IF %bglObject:FAny
    m = m & '|Clear all filters'
  END
  sel = POPUP(m)
  IF ~sel THEN EXIT.
  IF sel = 1                                                  ! (All): this column off
    %bglObject:FOn[c]  = 0
    %bglObject:FVal[c] = ''
    d2g_FilterOn(%bglObject:G,c - 1,0)
  ELSIF %bglObject:FAny AND sel = n + 2                       ! the clear-everything entry
    LOOP i = 1 TO %bglObject:Cols
      %bglObject:FOn[i]  = 0
      %bglObject:FVal[i] = ''
    END
    d2g_FilterOn(%bglObject:G,-1,0)
  ELSE
!  Walk the distinct values again to find the one picked - cheaper than keeping
!  a second array in step, and the queue is already sorted for it.
    prev = '<13,10>'
    n    = 0
    LOOP i = 1 TO RECORDS(BGLK:%bglObject)
      GET(BGLK:%bglObject,i)
      IF CLIP(%bglObject:KKey) = prev THEN CYCLE.
      prev = CLIP(%bglObject:KKey)
      n += 1
      IF n = sel - 1
        %bglObject:FVal[c] = %bglObject:KKey
        %bglObject:FOn[c]  = 1
        d2g_FilterOn(%bglObject:G,c - 1,1)
        BREAK
      END
    END
  END
  FREE(BGLK:%bglObject)
  %bglObject:FAny = 0
  LOOP i = 1 TO %bglObject:Cols
    IF %bglObject:FOn[i]
      %bglObject:FAny = 1
      BREAK
    END
  END
!  Refilter already does everything a changed narrowing needs: remember the
!  record, rebuild the map, keep the selection on it if it survived, fill.
  DO BGL:Refilter:%bglObject
#ELSE
  EXIT
#ENDIF

BGL:Express:%bglObject ROUTINE
!  A criteria filter was applied, changed or cleared - Expr already holds the
!  new expression, or ''. The filter lives on the VIEW, not in the map, so the
!  records have to be read again under it; at the measured 10ms for the whole
!  file that reload costs nothing. The selection is kept the way every other
!  narrowing keeps it: remember the record, reload, find it again if it is
!  still in the result, land at the top if it is not.
#IF(%bglLoad = 'File loaded')
  IF ~%bglObject:G THEN EXIT.
#IF(%bglSortTie)
  %bglObject:HaveFind = 0
  IF %bglObject:Loaded AND %bglObject:Count
    IF %bglObject:FiltOn
      GET(BGLF:%bglObject,%bglObject:Sel + 1)
      IF ~ERRORCODE() THEN GET(%bglQueue,%bglObject:Ref).
    ELSE
      GET(%bglQueue,%bglObject:Sel + 1)
    END
    IF ~ERRORCODE()
      %bglObject:Find     = %bglBrowseObj::%bglSortTie
      %bglObject:HaveFind = 1
    END
  END
#ENDIF
  %bglObject:Loaded = 0
  %bglObject:Sel    = 0
  %bglObject:Top    = 0
  DO BGL:Load:%bglObject
#IF(%bglSortTie)
  IF %bglObject:HaveFind
    DO BGL:Locate:%bglObject
  END
#ENDIF
  DO BGL:Clamp:%bglObject
  DO BGL:Anchor:%bglObject
  DO BGL:Fill:%bglObject
#ELSE
  EXIT
#ENDIF

BGL:Locate:%bglObject ROUTINE
!  Put the selection back on the record it was on, by identity rather than by
!  position. Called after a reload that something else provoked - an insert, a
!  change, a delete - where the row number means nothing any more because the
!  sort has put the record somewhere else, or removed it.
!
!  Needs the unique field from the Sorting tab. Without one there is nothing to
!  recognise a record by, and the selection can only stay where it was sitting.
!  This is the second reason that prompt matters, the first being POSITION.
!
!  A linear walk, deliberately: it runs once per update round-trip, not per
!  paint, and 10,000 in-memory comparisons cost less than the disk read that
!  just happened. Not found - a deleted record - leaves the selection alone, and
!  BGL:Clamp keeps it inside the queue.
#IF(%bglLoad = 'File loaded' AND %bglSortTie)
  DATA
i LONG,AUTO
  CODE
  IF ~%bglObject:HaveFind THEN EXIT.
  %bglObject:HaveFind = 0
!  In VISIBLE space, through the map when a search is narrowing the view - so a
!  record that no longer matches the search is simply not found, which is the
!  right answer.
  LOOP i = 1 TO %bglObject:Count
    IF %bglObject:FiltOn
      GET(BGLF:%bglObject,i)
      IF ERRORCODE() THEN BREAK.
      GET(%bglQueue,%bglObject:Ref)
    ELSE
      GET(%bglQueue,i)
    END
    IF ERRORCODE() THEN BREAK.
    IF %bglBrowseObj::%bglSortTie = %bglObject:Find
      %bglObject:Sel = i - 1
      DO BGL:Anchor:%bglObject                                ! and bring it into view
      BREAK
    END
  END
#ELSE
  EXIT
#ENDIF

BGL:SizeEnd:%bglObject ROUTINE
!  The button came up on a column drag. Put the new width back on the LIST as
!  well as the grid, so the browse goes on believing it owns its own columns -
!  anything that reads them, stores them or rebuilds the grid from them then
!  agrees with what is on screen. LIST widths are dialog units, the grid's are
!  pixels, hence the halving.
#IF(%bglSizeable)
  DATA
c LONG,AUTO
  CODE
  IF ~%bglObject:RzCol THEN EXIT.
  IF %bglObject:RzArmed
!  It never moved, so it was a click on the heading after all - and a click on a
!  heading sorts. Nothing was resized, so there is no width to write.
    %bglObject:RzArmed = 0
    %bglObject:RzCol   = 0
#IF(%bglSortHdr)
    IF %bglObject:SortCol >= 0
      DO BGL:Sort:%bglObject
    END
#ENDIF
    EXIT
  END
  c = %bglObject:Col[%bglObject:RzCol]
#IF(%bglWrap AND %bglVarRows AND %bglLoad = 'File loaded')
  d2g_Sizing(%bglObject:G,0)                                  ! the drag is over: measuring may resume
  %bglObject:BtmN = 0                                         ! new widths: the old landing means nothing
#ENDIF
  IF c
    %bglList{PROPLIST:Width,c} = d2g_ColWidth(%bglObject:G,%bglObject:RzCol - 1) / 2
!  Changing a LIST's format makes it redraw itself, and it comes back OVER the
!  grid when it does - stripping WS_VISIBLE stops Windows painting it, but the
!  format write repaints it by another route. Putting the region back on top in
!  the same breath undoes that. Nothing else in the drag touches the LIST, which
!  is why it only ever happened when the button came up.
    DO BGL:Place:%bglObject
    d2g_Resize(%bglObject:G)
    d2g_PaintNow(%bglObject:G)
  END
  %bglObject:RzCol = 0
#ELSE
  EXIT
#ENDIF

BGL:Recall:%bglObject ROUTINE
!  Remembered widths go back on the LIST BEFORE the grid reads the columns, so
!  there is one path that decides a width and the grid never has to be told
!  twice. Keyed by LIST column number, not by grid column: a zero-width column
!  is not in the grid's list at all, and its width would have nowhere to return.
#IF(%bglRemember)
  DATA
c   LONG,AUTO
i2  LONG,AUTO
j   LONG,AUTO
ex  LONG,AUTO
val CSTRING(32)
  CODE
  LOOP c = 1 TO 512
    ex = %bglList{PROPLIST:Exists,c}
    IF ~ex THEN BREAK.
    val = CLIP(GETINI('BrowseGridLeg:%Procedure:%bglObject','w' & c,'','%bglIni'))
    IF val
      %bglList{PROPLIST:Width,c} = val
    END
#IF(%bglChooser)
    IF c <= 64
      %bglObject:CHide[c] = CHOOSE(CLIP(GETINI('BrowseGridLeg:%Procedure:%bglObject','h' & c,'','%bglIni')) = '1',1,0)
    END
#ENDIF
  END
#IF(%bglMovable)
!  The remembered draw order, VALIDATED on the way in: an entry naming a column
!  twice keeps only its first appearance, and any column the saved order never
!  heard of - the browse gained one since yesterday - is appended at the end so
!  it still shows. A stale entry for a column that no longer exists is left in
!  place; BGL:Columns skips it without complaint.
  LOOP i2 = 1 TO 64
    val = CLIP(GETINI('BrowseGridLeg:%Procedure:%bglObject','o' & i2,'','%bglIni'))
    %bglObject:COrd[i2] = CHOOSE(val <> '',DEFORMAT(val),0)
  END
  IF %bglObject:COrd[1]
    LOOP i2 = 2 TO 64                                         ! keep first appearances only
      IF ~%bglObject:COrd[i2] THEN CYCLE.
      LOOP j = 1 TO i2 - 1
        IF %bglObject:COrd[j] = %bglObject:COrd[i2]
          %bglObject:COrd[i2] = 0
          BREAK
        END
      END
    END
    LOOP c = 1 TO 64                                          ! append what the order missed
      ex = %bglList{PROPLIST:Exists,c}
      IF ~ex THEN BREAK.
      j = 0
      LOOP i2 = 1 TO 64
        IF %bglObject:COrd[i2] = c THEN j = 1 ; BREAK.
      END
      IF j THEN CYCLE.
      LOOP i2 = 1 TO 64
        IF ~%bglObject:COrd[i2]
          %bglObject:COrd[i2] = c
          BREAK
        END
      END
    END
  END
#ENDIF
#ELSE
  EXIT
#ENDIF

BGL:Remember:%bglObject ROUTINE
!  Written once, at close, so it costs nothing while the window is up. Legacy has
!  no INIMgr - that is an ABC class - so this is plain GETINI/PUTINI against a
!  named file, sectioned by procedure and grid so two grids never collide.
#IF(%bglRemember)
  DATA
i   LONG,AUTO
c   LONG,AUTO
ex  LONG,AUTO
fld LONG,AUTO
  CODE
  IF ~%bglObject:G THEN EXIT.
!  EVERY column the LIST has, not only the ones being drawn - then the drawn ones
!  again at the grid's own precision, which is where a drag actually landed.
  LOOP c = 1 TO 512
    ex = %bglList{PROPLIST:Exists,c}
    IF ~ex THEN BREAK.
    fld = %bglList{PROPLIST:FieldNo,c}
    IF ~fld THEN CYCLE.
    PUTINI('BrowseGridLeg:%Procedure:%bglObject','w' & c,%bglList{PROPLIST:Width,c},'%bglIni')
#IF(%bglChooser)
    IF c <= 64
      PUTINI('BrowseGridLeg:%Procedure:%bglObject','h' & c,CHOOSE(%bglObject:CHide[c] = 1,'1',''),'%bglIni')
    END
#ENDIF
  END
  LOOP i = 1 TO %bglObject:Cols
    IF ~%bglObject:Col[i] THEN CYCLE.
    PUTINI('BrowseGridLeg:%Procedure:%bglObject','w' & %bglObject:Col[i],              |
           d2g_ColWidth(%bglObject:G,i - 1) / 2,'%bglIni')
  END
#IF(%bglMovable)
  LOOP i = 1 TO 64
    PUTINI('BrowseGridLeg:%Procedure:%bglObject','o' & i,                              |
           CHOOSE(%bglObject:COrd[i] > 0,'' & %bglObject:COrd[i],''),'%bglIni')
  END
#ENDIF
#ELSE
  EXIT
#ENDIF

BGL:Clamp:%bglObject ROUTINE
!  Bounds only. Keeps the selection inside the queue and the window inside the
!  queue, and moves NEITHER towards the other.
!
!  This is the one every fill calls. Anchoring on every fill was wrong: the wheel
!  and the thumb move the WINDOW, and pulling it straight back to wherever the
!  selection happened to be meant neither could travel more than a page before
!  being reeled in. That is what "the wheel only moves about seven rows" was.
#IF(%bglLoad = 'File loaded')
  DATA
page LONG,AUTO
  CODE
  IF ~%bglObject:G THEN EXIT.
  page = d2g_PageSize(%bglObject:G)
  IF page < 1 THEN page = 1.
  IF %bglObject:Sel > %bglObject:Count - 1 THEN %bglObject:Sel = %bglObject:Count - 1.
  IF %bglObject:Sel < 0 THEN %bglObject:Sel = 0.
  IF %bglObject:Top > %bglObject:Count - page THEN %bglObject:Top = %bglObject:Count - page.
  IF %bglObject:Top < 0 THEN %bglObject:Top = 0.
#ELSE
  EXIT
#ENDIF

BGL:Anchor:%bglObject ROUTINE
!  Bring the SELECTION into view. Only what moves the selection calls this - a
!  key, a click, a sort - because only then should the window chase it. Scrolling
!  does not: the wheel and the thumb leave the selection where it is and let it
!  go off screen, which is how every grid outside Clarion behaves.
#IF(%bglLoad = 'File loaded')
  DATA
page LONG,AUTO
#IF(%bglWrap AND %bglVarRows AND %bglLoad = 'File loaded')
fitN LONG,AUTO
fitB LONG,AUTO
#ENDIF
  CODE
  IF ~%bglObject:G THEN EXIT.
  DO BGL:Clamp:%bglObject
  page = d2g_PageSize(%bglObject:G)
  IF page < 1 THEN page = 1.
#IF(%bglWrap AND %bglVarRows AND %bglLoad = 'File loaded')
!  Variable rows: "on screen" is what MEASURED as fitting, not the conservative
!  page - judging by the page yanked any clicked row below it up the screen,
!  because the click was ruled invisible and anchored.
!
!  But measured answers are only about the window the last fill PUSHED. Top
!  and that window drift apart in exactly two places - the Clamp above just
!  moved Top, or a reload/filter changed the record set with no fill between
!  (BGL:Load runs Map then Anchor) - and then RowsFit and FitUpTo would be
!  walking the heights of the wrong records, placing the selection a row or
!  two adrift. The grid says which record its window starts at and the fill
!  stamps which Count it pushed from; either disagreeing means the measured
!  branch is blind, and the conservative page - always safe, merely farther -
!  takes over for this one placement.
  IF d2g_FirstRow(%bglObject:G) <> %bglObject:Top OR %bglObject:MeasN <> %bglObject:Count
    IF %bglObject:Sel < %bglObject:Top
      %bglObject:Top = %bglObject:Sel
    ELSIF %bglObject:Sel > %bglObject:Top + page - 1
      %bglObject:Top = %bglObject:Sel - page + 1
    END
  ELSE
    fitN = d2g_RowsFit(%bglObject:G)
    IF fitN < page THEN fitN = page.                          ! never worse than certain
    IF %bglObject:Sel < %bglObject:Top
      %bglObject:Top = %bglObject:Sel                         ! scrolled off the top
    ELSIF %bglObject:Sel > %bglObject:Top + fitN - 1
!  Off the bottom - scroll the LEAST that brings it whole into view, walked
!  backwards from the selection over the measured heights. Outside the pushed
!  window there is nothing to measure, so the conservative jump stands in;
!  Sel is certain to be visible either way, only the distance differs.
      fitB = d2g_FitUpTo(%bglObject:G,%bglObject:Sel - %bglObject:Top)
      IF fitB > 0
        %bglObject:Top = %bglObject:Sel - fitB + 1
      ELSE
        %bglObject:Top = %bglObject:Sel - page + 1
      END
    END
  END
#ELSE
  IF %bglObject:Sel < %bglObject:Top
    %bglObject:Top = %bglObject:Sel                           ! scrolled off the top
  ELSIF %bglObject:Sel > %bglObject:Top + page - 1
    %bglObject:Top = %bglObject:Sel - page + 1                ! ...or off the bottom
  END
#ENDIF
  DO BGL:Clamp:%bglObject
#ELSE
  EXIT
#ENDIF

BGL:Fill:%bglObject ROUTINE
!  Push the browse's queue into the grid. This is every visible row and no more,
!  which is exactly what the queue holds - the grid is told nothing about the
!  file. WHAT() reads the queue field by number, so nothing here knows or cares
!  what the file is.
  DATA
i     LONG,AUTO
col   LONG,AUTO
rows  LONG,AUTO
fit   LONG,AUTO
first LONG,AUTO
sel   LONG,AUTO
total LONG,AUTO
sp    LONG,AUTO
dlh   LONG,AUTO
  CODE
  IF ~%bglObject:G THEN EXIT.
  %bglObject:Fills += 1                                       ! for the diagnostics line
#IF(%bglSortHdr OR %bglSortField)
!  Has the browse changed sort order on its own since the last fill? A tab, or a
!  reset field moving, does that - and our column sort has to be given up when it
!  happens, or the new tab shows its own records in our order. Checked here
!  because it is the one place that runs after every refill whatever caused it.
  IF %bglObject:SortOn AND %bglBrowseObj::SortOrder <> %bglObject:SortSeen
    DO BGL:Unsort:%bglObject
  END
  %bglObject:SortSeen = %bglBrowseObj::SortOrder
!  Still sorted the way we asked? Every Reset rebuilds the design-time order and
!  drops ours, and Reset runs for a tab, for a resize (DoResize sets ForceRefresh
!  and SelectSort answers with one) and for a reset field moving. Put it back,
!  rather than quietly reverting to the file's own sequence with the triangle
!  still saying otherwise.
!
!  This costs the scroll position - the rebuild fills from the top. The two ends
!  of the file are therefore intercepted before they get here, in BGL:DragEnd,
!  because those were the cases where losing the position was most obvious.
#IF(%bglLoad <> 'File loaded')
  IF %bglObject:SortOn AND %bglObject:Order
    IF CLIP(%bglBrowseObj::View:Browse{PROP:Order}) <> CLIP(%bglObject:Order)
      DO BGL:Order:%bglObject
    END
  END
#ELSE
!  NOTHING TO RE-ASSERT WHEN THE FILE IS RESIDENT, and asserting anyway was a
!  bug. The sort lives in the QUEUE's own order here - SORT() put it there and
!  nothing disturbs it - so the view's PROP:Order is never set and never will
!  match what we are holding. Comparing them fired BGL:Order on every single
!  fill, which re-SORTed the queue and set Sel back to 0 - so the highlight
!  could not be moved by click or key, and the fill count climbed on every try.
#ENDIF
#ENDIF
!  Keep the region ON the LIST, every time. A fill already happens whenever
!  anything changes, and following the LIST costs a GETPOSITION and a
!  SETPOSITION - much cheaper than hunting for the one right moment to place it.
  DO BGL:Place:%bglObject
#IF(%bglLoad = 'File loaded')
!  FILE LOADED. The queue is the whole view, so the window into it is entirely
!  ours: Top says where it starts and Sel which row is picked, both absolute
!  record numbers, and neither is asked of the browse.
!
!  RELOAD IF THE QUEUE HAS BEEN DISTURBED. Anything that drove the browse
!  through its own refill - most often coming back from an update - leaves the
!  queue holding one page instead of the file, and the count is how that shows.
!  Reloading here rather than hunting for the update means it is caught whatever
!  moved it.
  IF ~%bglObject:Loaded
    DO BGL:Load:%bglObject                                    ! first time: nothing to re-find
  ELSIF RECORDS(%bglQueue) <> %bglObject:Full
#IF(%bglSortTie)
!  KEEP THE SELECTION ON THE RECORD, NOT ON THE ROW NUMBER. The browse has just
!  refilled its own queue around a record it cares about - after an insert,
!  ButtonInsert has already done LocateOnEdit, so CurrentChoice IS the new
!  record; after a change or a delete it is the edited row or its neighbour.
!  Read the identity out of that row NOW, because in a moment the queue holding
!  it will be replaced, and Sel is only an index - after a re-sort the same index
!  is a different record, which is why an inserted row was never the one selected.
    %bglObject:WasCount = %bglObject:Full                     ! to tell a delete from a change
#IF(%bglFile)
    %bglObject:WasFileN = %bglObject:FileN                    ! the file's word on the same question
#ENDIF
    %bglObject:HaveFind = 0
    GET(%bglQueue,%bglBrowseObj::CurrentChoice)
    IF ~ERRORCODE()
      %bglObject:Find     = %bglBrowseObj::%bglSortTie
      %bglObject:HaveFind = 1
    END
#ENDIF
    DO BGL:Load:%bglObject
#IF(%bglSortTie)
!  A DELETE KEEPS ITS PLACE; ANYTHING ELSE FOLLOWS THE RECORD.
!
!  Fewer records than before means one was deleted, and the record we were on is
!  the one that went - there is nothing to re-find. Leaving Sel alone is exactly
!  right once the order has been preserved above: the same ordinal is now the
!  record that FOLLOWED the deleted one, which is the nearest survivor, and
!  BGL:Clamp pulls it back a row if the deleted one was last. Chasing the
!  browse's CurrentChoice here instead would land wherever its own one-page
!  refill happened to leave it, which is what sent a delete to the top.
!
!  Same or more records - a change, an insert, a plain refresh - and the record
!  matters more than the position, so go and find it again.
#IF(%bglFile)
    IF %bglObject:FileN > %bglObject:WasFileN
#ELSE
    IF %bglObject:Full > %bglObject:WasCount
#ENDIF
!  An INSERT. Clear every narrowing first: the new record has to be visible and
!  selected, and under a search, a column filter or a criteria filter it may
!  not match - in which case it would be born hidden, looking exactly like an
!  insert that silently failed. The user asked to see the record they just
!  made; the narrowings give way. The criteria filter goes first because it
!  lives on the VIEW - the load that just happened was filtered by it, so
!  clearing it means reading again; the others are map-level and only need the
!  map rebuilt.
      IF %bglObject:Expr
        %bglObject:Expr = ''
        IF %bglObject:FBtn                                    ! same words as the filter bar's rest caption
          %bglObject:FBtn{PROP:Text} = 'Filter - click here to filter this list'
        END
        DO BGL:Load:%bglObject                                ! again, unfiltered this time
      END
      IF %bglObject:FiltText
        %bglObject:FiltText = ''
        IF %bglObject:Echo
          %bglObject:Echo{PROP:ScreenText} = ''
        END
        IF %bglObject:EchoX
          %bglObject:EchoX{PROP:Hide} = 1                     ! nothing left to clear
        END
        DO BGL:Map:%bglObject                                 ! back to the full set
      END
#IF(%bglFilterBtns)
!  Column filters can hide the new record every bit as well as the search, and
!  the same rule applies: the user asked to see the record they just made.
      IF %bglObject:FAny
        LOOP col = 1 TO %bglObject:Cols
          %bglObject:FOn[col]  = 0
          %bglObject:FVal[col] = ''
        END
        %bglObject:FAny = 0
        d2g_FilterOn(%bglObject:G,-1,0)
        DO BGL:Map:%bglObject
      END
#ENDIF
      DO BGL:Locate:%bglObject
#IF(%bglFile)
    ELSIF %bglObject:FileN = %bglObject:WasFileN
#ELSE
    ELSIF %bglObject:Full = %bglObject:WasCount
#ENDIF
!  A CHANGE OR A CANCEL - and for these, do not trust what the browse's refill
!  called current. Its RefreshPage re-finds the record by matching POSITION
!  strings, and a SQL driver answers POSITION by key value where TopSpeed
!  answered by place - the match can land a row adrift, which walked the
!  highlight one record down after every Change. The identity captured by the
!  LAST fill before the form - our own full queue, our own Sel - is the record
!  the user was on, whatever the driver. An edit cannot change the tie field,
!  so it survives the rename case too. An INSERT stays on the branch above:
!  there the acted-on record is NEW, and CurrentChoice is the only one who
!  knows it.
      IF %bglObject:HaveSel
        %bglObject:Find     = %bglObject:SelFind
        %bglObject:HaveFind = 1
      END
      DO BGL:Locate:%bglObject                                ! a change: follow the record
    END
#ENDIF
  END
  total = %bglObject:Count
  DO BGL:Clamp:%bglObject                                     ! bounds only - never chase the selection
  first = %bglObject:Top
#IF(%bglWrap AND %bglVarRows AND %bglLoad = 'File loaded')
!  Variable rows: push the OPTIMISTIC page - every row the screen could show if
!  none of them wrapped - and let the draw stop where the pixels run out. The
!  conservative d2g_PageSize still governs Clamp, Anchor and the keys, so a
!  selection is never anchored past what is certain to fit; pushing more here
!  only keeps the bottom of the view filled when rows measure short.
!  d2g_PageMax, not PageSize times the allowance: the floor in PageSize
!  multiplied back up came out short, and the deficit stood at the bottom of
!  the view as a blank strip whenever the visible rows happened not to wrap.
  fit   = d2g_PageMax(%bglObject:G) + 1
#ELSE
  fit   = d2g_PageSize(%bglObject:G) + 1
#ENDIF
  rows  = total - first
  IF rows > fit THEN rows = fit.
  IF rows < 0 THEN rows = 0.
  sel   = %bglObject:Sel + 1                                  ! 1-based, as CHOICE() would be
#ELSE
  total = RECORDS(%bglQueue)
  fit   = d2g_PageSize(%bglObject:G) + 1
  sel   = CHOICE(%bglList)
  first = 0
  rows  = total
  IF fit > 0 AND total > fit
!  The grid cannot draw the whole queue - its rows are taller than the LIST's
!  lines, so the browse has loaded more records than there is room for. Start
!  far enough down that the SELECTED record is one of the ones drawn.
    rows = fit
    IF sel > fit
      first = sel - fit
      IF first > total - fit THEN first = total - fit.
      IF first < 0 THEN first = 0.
    END
  END
#ENDIF
  d2g_Page(%bglObject:G,first,rows)
#IF(%bglWrap AND %bglVarRows AND %bglLoad = 'File loaded')
  %bglObject:MeasN = total                                    ! the Count this window was pushed from
#ENDIF
  LOOP i = 1 TO rows
#IF(%bglLoad = 'File loaded')
!  Through the MAP when a search is on: the map says which queue rows are
!  visible, in order, and first/rows count within THOSE. With no search the map
!  is bypassed and this is the plain read it always was.
    IF %bglObject:FiltOn
      GET(BGLF:%bglObject,first + i)
      IF ERRORCODE() THEN BREAK.
      GET(%bglQueue,%bglObject:Ref)
    ELSE
      GET(%bglQueue,first + i)
    END
#ELSE
    GET(%bglQueue,first + i)
#ENDIF
    IF ERRORCODE() THEN BREAK.
    LOOP col = 1 TO %bglObject:Cols
      IF %bglObject:Pic[col]
        %bglObject:Cell = CLIP(LEFT(FORMAT(WHAT(%bglQueue,%bglObject:Fld[col]), |
                                           CLIP(%bglObject:Pic[col]))))
      ELSE
        %bglObject:Cell = CLIP(LEFT(WHAT(%bglQueue,%bglObject:Fld[col])))
      END
      d2g_Cell(%bglObject:G,i - 1,col - 1,%bglObject:Cell)
    END
  END
#IF(%bglDiag)
!  Everything the grid is working from, in the window title. When a browse draws
!  nothing there is no way to tell from the outside whether the queue was empty,
!  the rows were too tall to fit, or the columns never got read - and those want
!  different fixes.
!  PROP:LineHeight answers in whatever PROP:Pixels is currently set to, so it is
!  read in pixels here - reported in dialog units it looked unrelated to rowh,
!  which is always pixels, and the two are meant to be compared.
  sp = 0{PROP:Pixels}
  0{PROP:Pixels} = 1
  dlh = %bglList{PROP:LineHeight}
  0{PROP:Pixels} = sp
!  page vs items is the pair that matters: the grid draws `page` rows and the
!  browse loads `items` records, and the moment those differ the bottom of the
!  list misbehaves. first says which queue entry is being drawn at the top -
!  anything other than 0 means the grid is showing a window into the queue
!  rather than all of it.
  0{PROP:Text} = 'BGL q=' & total & ' fill=' & %bglObject:Fills                 |
               & ' cols=' & %bglObject:Cols                                     |
               & ' rowh=' & d2g_RowH(%bglObject:G)                              |
               & ' need=' & d2g_RowNeed(%bglObject:G)                           |
               & ' page=' & d2g_PageSize(%bglObject:G) & ' fit=' & fit          |
#IF(%bglWrap AND %bglVarRows AND %bglLoad = 'File loaded')
               & ' rfit=' & d2g_RowsFit(%bglObject:G)                           |
#ENDIF
               & ' first=' & first & ' draw=' & rows & ' lh=' & dlh             |
               & ' items=' & %bglList{PROP:Items} & ' sel=' & sel               |
#IF(%bglLoad = 'File loaded')
               & ' load=' & %bglObject:LoadMS & 'ms'                            |
#ENDIF
               & ''
#ENDIF
  d2g_Total(%bglObject:G,total)
#IF(%bglLoad = 'File loaded')
  d2g_Select(%bglObject:G,%bglObject:Sel)                     ! ours, absolute, already 0-based
!  AND TELL THE LIST WHICH ROW THAT IS. The grid owns the selection in this mode,
!  but the browse still resolves "the current record" its own way: GetRecord does
!  CurrentChoice = CHOICE(?List), GETs that queue entry and REGETs the view from
!  its POSITION. Leave the LIST out of it and CHOICE() stays at 1, so Change and
!  Delete operate on the first record whatever is highlighted.
!
!  The queue holds every record in the order the grid draws them, so the LIST's
!  entry number is simply Sel + 1. CurrentChoice is set too, for the places that
!  read it without going through GetRecord first.
#IF(%bglSortTie)
!  ...AND REMEMBER WHO THAT IS, while the full queue is still standing. The
!  next update round-trip replaces the queue with one page before anything of
!  ours runs again, so this - the last fill before the form - is the only
!  honest chance to write down which record the selection is on. The reload
!  logic reads it back for the change-or-cancel case, where the browse's own
!  idea of current cannot be trusted across a SQL driver's POSITION.
  %bglObject:HaveSel = 0
#ENDIF
  IF %bglObject:FiltOn
!  Under a search, the LIST and the browse still count in QUEUE ordinals - that
!  is what GetRecord GETs before an update - so hand them the mapped Ref, not
!  the visible row number. Getting this wrong sends Change to the wrong record
!  the moment a search is narrowing the view.
    IF %bglObject:Count
      GET(BGLF:%bglObject,%bglObject:Sel + 1)
      IF ~ERRORCODE()
        %bglList{PROP:Selected}      = %bglObject:Ref
        %bglBrowseObj::CurrentChoice = %bglObject:Ref
#IF(%bglSortTie)
        GET(%bglQueue,%bglObject:Ref)
        IF ~ERRORCODE()
          %bglObject:SelFind = %bglBrowseObj::%bglSortTie
          %bglObject:HaveSel = 1
        END
#ENDIF
      END
    END
  ELSE
    %bglList{PROP:Selected}      = %bglObject:Sel + 1
    %bglBrowseObj::CurrentChoice = %bglObject:Sel + 1
#IF(%bglSortTie)
    IF %bglObject:Count
      GET(%bglQueue,%bglObject:Sel + 1)
      IF ~ERRORCODE()
        %bglObject:SelFind = %bglBrowseObj::%bglSortTie
        %bglObject:HaveSel = 1
      END
    END
#ENDIF
  END
#ELSE
  %bglObject:Sel = sel                                        ! the browse owns the selection
  d2g_Select(%bglObject:G,sel - 1)
#ENDIF
  DO BGL:Bars:%bglObject                                      ! resize both thumbs to what is showing
  d2g_Repaint(%bglObject:G)
#IF(%bglWrap AND %bglVarRows AND %bglLoad = 'File loaded')
  DO BGL:Bottom:%bglObject                                    ! LAST - it may fill again
#ENDIF

BGL:Bottom:%bglObject ROUTINE
!  BOTTOM-ANCHOR, the way a Clarion browse ends: the last screen is FULL and
!  ends at the last record. With rows of different heights the conservative
!  clamp has to stop Top early - it cannot know the tail's heights before
!  their cells are pushed - so a fill that reached the last record can leave
!  room to spare below it. And the fill's own window starts AT Top, so there
!  is nothing above it measured to pull in: the anchor takes a PROBE. Fill the
!  deepest window that could possibly end the file (pass 1), walk its measured
!  heights backwards from the last record for where the full last screen
!  starts, fill THERE (pass 2), and stop (pass 3). BtmFix carries which pass
!  this is; it only ever steps 0-1-2-0, so the fills cannot cycle whatever the
!  heights measure. Called as the last thing a fill does, so the re-entered
!  fill tramples nothing behind it; the selection stays visible because every
!  row from the anchored Top to the end just measured as fitting.
#IF(%bglWrap AND %bglVarRows AND %bglLoad = 'File loaded')
  DATA
fitB LONG,AUTO
  CODE
  IF ~%bglObject:G THEN EXIT.
  CASE %bglObject:BtmFix
  OF 2                                                        ! the anchored fill, back round: done
    %bglObject:BtmFix = 0
    %bglObject:BtmTop = %bglObject:Top                        ! remember the landing: a wrapped row just
    %bglObject:BtmN   = %bglObject:Count                      ! above the window keeps a gap >= one base
                                                              ! line, and without the stamp every fill at
                                                              ! the tail would probe and re-land HERE
  OF 1                                                        ! the probe is in: land exactly
    fitB = d2g_FitUpTo(%bglObject:G,%bglObject:Count - %bglObject:Top - 1)
    IF fitB < 1                                               ! nothing measurable: give the probe up and
      %bglObject:BtmFix = 0                                   ! leave Top where it stands - a wrong guess
      EXIT                                                    ! here is a one-record screen
    END
    IF %bglObject:Count - fitB <> %bglObject:Top
      %bglObject:BtmFix = 2
      %bglObject:Top    = %bglObject:Count - fitB
      DO BGL:Fill:%bglObject
    ELSE
      %bglObject:BtmFix = 0                                   ! the probe already stood right
      %bglObject:BtmTop = %bglObject:Top
      %bglObject:BtmN   = %bglObject:Count
    END
  ELSE                                                        ! an ordinary fill: is the tail short?
    IF %bglObject:Top <= 0 THEN EXIT.                         ! it all fits already
    IF %bglObject:BtmN AND %bglObject:Top = %bglObject:BtmTop AND %bglObject:Count = %bglObject:BtmN THEN EXIT.  ! standing on the last landing
    IF %bglObject:Count - %bglObject:Top > d2g_PageMax(%bglObject:G) + 1 THEN EXIT.  ! nowhere near the end
    IF d2g_FitUpTo(%bglObject:G,%bglObject:Count - %bglObject:Top - 1) < %bglObject:Count - %bglObject:Top THEN EXIT.  ! rows below the fold: not at the bottom
    IF ~d2g_TailGap(%bglObject:G) THEN EXIT.                  ! the tail touches the bottom: anchored already
    %bglObject:BtmFix = 1
    %bglObject:Top    = %bglObject:Count - d2g_PageMax(%bglObject:G) - 1
    IF %bglObject:Top < 0 THEN %bglObject:Top = 0.
    DO BGL:Fill:%bglObject
  END
#ELSE
  EXIT
#ENDIF

BGL:Hit:%bglObject ROUTINE
!  A click picks a row. The browse still owns the selection: it is told which
!  record was chosen and left to do the rest, so locators, range limits and
!  anything hanging off EVENT:NewSelection behave exactly as they always did.
!  MOUSEY answers in WINDOW units and the grid measures in pixels, hence the
!  switch - a window unit is half a pixel.
  DATA
rx  SIGNED,AUTO
ry  SIGNED,AUTO
rw  SIGNED,AUTO
rh  SIGNED,AUTO
sp  LONG,AUTO
mx  LONG,AUTO
my  LONG,AUTO
row LONG,AUTO
col LONG,AUTO
  CODE
  IF ~%bglObject:G THEN EXIT.
  sp = 0{PROP:Pixels}
  0{PROP:Pixels} = 1
  GETPOSITION(%bglObject:Rgn,rx,ry,rw,rh)
  mx  = MOUSEX() - rx
  my  = MOUSEY() - ry
  row = d2g_HitRow(%bglObject:G,my)
  0{PROP:Pixels} = sp
#IF(%bglBars)
!  The scrollbars first: they are drawn over everything else, so they are
!  clicked before everything else.
#IF(%bglBarStyle <> 'Windows')
  CASE d2g_HitHBar(%bglObject:G,mx,my)                        ! the drawn sideways bar
  OF 4
    %bglObject:HDrag = 1
    %bglObject:HGrab = d2g_HGrab(%bglObject:G,mx)
    EXIT
  OF 5
    %bglObject:ScrollX = %bglObject:ScrollX - d2g_ViewWidth(%bglObject:G)
    IF %bglObject:ScrollX < 0 THEN %bglObject:ScrollX = 0.
    d2g_ScrollX(%bglObject:G,%bglObject:ScrollX)
    DO BGL:Bars:%bglObject
    d2g_PaintNow(%bglObject:G)
    EXIT
  OF 6
    %bglObject:ScrollX = %bglObject:ScrollX + d2g_ViewWidth(%bglObject:G)
    d2g_ScrollX(%bglObject:G,%bglObject:ScrollX)
    DO BGL:Bars:%bglObject
    d2g_PaintNow(%bglObject:G)
    EXIT
  END
#ENDIF
!  The downward bar is drawn whatever the style, so it is hit-tested whatever
!  the style. Paging is the browse's business and goes to it as an event.
  CASE d2g_VHit(%bglObject:G,mx,my)
  OF 1
    %bglObject:VDrag = 1
    %bglObject:VGrab = d2g_VGrab(%bglObject:G,my)             ! anchored, so it cannot jump
    EXIT
  OF 2
    POST(EVENT:PageUp,%bglList)
    EXIT
  OF 3
    POST(EVENT:PageDown,%bglList)
    EXIT
  END
#ENDIF
#IF(%bglChooser)
!  A RIGHT-click on the headings is the column chooser. Checked before anything
!  else in the header, and never reaches the sort or the resize.
  IF my < d2g_HdrHeight(%bglObject:G) AND KEYCODE() = MouseRight
    DO BGL:Choose:%bglObject
    EXIT
  END
#ENDIF
#IF(%bglSortHdr OR %bglSizeable OR %bglMovable)
!  A heading. Never changes the selection - it is a request to sort by that
!  column, and the browse decides what the selection becomes afterwards.
  IF my < d2g_HdrHeight(%bglObject:G)
    %bglObject:SortCol = d2g_HitCol(%bglObject:G,mx)           ! remembered either way
#IF(%bglFilterBtns AND %bglLoad = 'File loaded')
!  The button beats both the resize and the sort: it sits against the heading's
!  right edge, inside the resize grab margin, and a press on it means "show me
!  the values" - the couple of pixels the resize loses on that side it keeps on
!  the other side of the boundary.
    %bglObject:FiltCol = d2g_HitBtn(%bglObject:G,mx,my)
    IF %bglObject:FiltCol >= 0
      DO BGL:FiltMenu:%bglObject
      EXIT
    END
#ENDIF
#IF(%bglSizeable)
!  ON AN EDGE IS A RESIZE, ANYWHERE ELSE IS A SORT - but a click and a drag both
!  start the same way, and until the mouse MOVES there is no telling which this
!  is. So the resize is only ARMED here. Committing it on the press would mean a
!  narrow column could never be sorted at all: the grab margin reaches a few
!  pixels either side of every boundary, so a narrow heading is almost entirely
!  edge. BGL:Drag disarms it into a sort if the pointer never travelled.
    col = d2g_HitEdge(%bglObject:G,mx)
    IF col >= 0
      %bglObject:RzCol   = col + 1                             ! 1-based: 0 means nothing is dragging
      %bglObject:RzX     = mx
      %bglObject:RzW     = d2g_ColWidth(%bglObject:G,col)
      %bglObject:RzArmed = 1
      EXIT
    END
#ENDIF
#IF(%bglMovable)
!  NOT on an edge: this press might be a SORT or the start of a CARRY, and only
!  movement can say which - so nothing happens yet, exactly as with the resize.
!  BGL:MoveEnd converts an unmoved release into the sort.
    IF %bglObject:SortCol >= 0
      %bglObject:MvCol = %bglObject:SortCol + 1               ! 1-based: 0 means nothing armed
      %bglObject:MvX   = mx
      %bglObject:MvOn  = 0
    END
#ELSE
#IF(%bglSortHdr)
    IF %bglObject:SortCol >= 0
      DO BGL:Sort:%bglObject
    END
#ENDIF
#ENDIF
    EXIT
  END
#ENDIF
#IF(%bglLoad = 'File loaded')
!  The clicked row is relative to what is drawn; the selection is absolute.
!  Focus still goes to the LIST, exactly as in page-loaded mode - it is the only
!  focusable control involved, and it is where the navigation keys must arrive
!  for us to intercept them. A REGION cannot hold the focus at all.
!  d2g_HitRow ALREADY RETURNS AN ABSOLUTE ROW. It answers firstRow + offset, and
!  firstRow is the Top we handed to d2g_Page - so adding Top again counted it
!  twice and the click landed Top rows below where it was aimed. Harmless at the
!  top of the file, which is exactly why it survived the first round of testing.
  IF row < 0 THEN EXIT.
  IF row > %bglObject:Count - 1 THEN EXIT.
  %bglObject:Sel = row
  DO BGL:Anchor:%bglObject
  DO BGL:Fill:%bglObject
  SELECT(%bglList)
!  A DOUBLE-CLICK IS THE CHANGE BUTTON, same as it always was on the LIST. The
!  region swallows the mouse, so the alerted MouseLeft2 the browse relies on
!  never reaches the LIST - but KEYCODE() still says MouseLeft2 while THIS
!  event is current, so the browse's own AlertKey routine takes its MouseLeft2
!  arm and posts to whatever button its update template generated there. A
!  browse with no update buttons has no such arm and nothing happens, exactly
!  as before. The row was selected and filled above, so the browse is already
!  looking at the right record.
  IF KEYCODE() = MouseLeft2
    DO %bglBrowseObj::AlertKey
  END
  EXIT
#ENDIF
  IF row < 0 OR row >= RECORDS(%bglQueue) THEN EXIT.
  %bglList{PROP:Selected} = row + 1
  POST(EVENT:NewSelection,%bglList)                           ! let the browse react as usual
!  Give the focus to the BROWSE, not to the region. The LIST is invisible to
!  Windows but perfectly alive to Clarion, so with the focus on it every key the
!  browse has always answered goes on working, unchanged and unwritten by us:
!  the arrows, PageUp and PageDown, the locator, Insert, Delete and Enter. The
!  region only ever needed the mouse, and a REGION with PROP:IMM gets that
!  whether it has the focus or not.
  SELECT(%bglList)
  %bglObject:Sel = row
  d2g_Select(%bglObject:G,row)
  d2g_Repaint(%bglObject:G)
!  A DOUBLE-CLICK IS THE CHANGE BUTTON - see the file-loaded branch above. The
!  NewSelection just posted is processed before the Accepted that AlertKey
!  posts, so the browse refreshes onto the clicked row first, and the Change
!  button's own handler re-reads the selection fresh in any case.
  IF KEYCODE() = MouseLeft2
    DO %bglBrowseObj::AlertKey
  END

BGL:Drag:%bglObject ROUTINE
!  A thumb being dragged. THIS is what Windows' own vertical scrollbar could not
!  do: there is no modal loop here - it is an ordinary mouse move - so ACCEPT
!  runs, the browse is told to scroll exactly as its own thumb would tell it,
!  and by the time the pointer has moved again the records are on screen. The
!  thumb follows the POINTER while the drag is on rather than the browse, so it
!  cannot stutter.
#IF(%bglBars OR %bglSizeable OR %bglMovable)
  DATA
rx  SIGNED,AUTO
ry  SIGNED,AUTO
rw  SIGNED,AUTO
rh  SIGNED,AUTO
sp  LONG,AUTO
mx  LONG,AUTO
my  LONG,AUTO
vp  LONG,AUTO
col LONG,AUTO
wid LONG,AUTO
  CODE
  IF ~%bglObject:G THEN EXIT.
#IF(NOT %bglSizeable AND NOT %bglMovable)
!  Nothing to do unless a thumb is being dragged. It cannot short-circuit like
!  this when columns are resizable, because then the sizing CURSOR has to be
!  tracked over every mouse move, dragging or not - and the same goes for a
!  heading being carried.
  IF ~%bglObject:VDrag AND ~%bglObject:HDrag THEN EXIT.
#ENDIF
  sp = 0{PROP:Pixels}
  0{PROP:Pixels} = 1
  GETPOSITION(%bglObject:Rgn,rx,ry,rw,rh)
  mx = MOUSEX() - rx
  my = MOUSEY() - ry
  0{PROP:Pixels} = sp
!  Windows answers with the high bit set while the button is down, and a SHORT
!  is signed, so "still held" is simply "negative". Clarion has no MOUSEDOWN,
!  and the mouse can be released off the grid, where no MouseUp ever arrives.
!  ONLY WHEN SOMETHING IS ACTUALLY BEING DRAGGED. Unguarded, this exits on every
!  mouse move with the button up - which is every HOVER - so the cursor tracking
!  below it never ran. It was written when this routine only ever fired mid-drag.
#IF(%bglMovable)
  IF %bglObject:VDrag OR %bglObject:HDrag OR %bglObject:RzCol OR %bglObject:MvCol
#ELSE
  IF %bglObject:VDrag OR %bglObject:HDrag OR %bglObject:RzCol
#ENDIF
    IF bglApi_GetAsyncKeyState(BGL:VkLButton) >= 0
!  Released - and possibly off the grid, where no MouseUp ever arrives, so the
!  deferred move has to be committed from here as well as from MouseUp.
      IF %bglObject:VDrag
        %bglObject:VDrag = 0
        DO BGL:DragEnd:%bglObject
      END
      %bglObject:HDrag = 0
#IF(%bglSizeable)
      IF %bglObject:RzCol
        DO BGL:SizeEnd:%bglObject
      END
#ENDIF
#IF(%bglMovable)
      IF %bglObject:MvCol
        DO BGL:MoveEnd:%bglObject
      END
#ENDIF
      EXIT
    END
  END
#IF(%bglBarStyle <> 'Windows')
  IF %bglObject:HDrag
    %bglObject:ScrollX = d2g_HDrag(%bglObject:G,mx,%bglObject:HGrab)
    d2g_ScrollX(%bglObject:G,%bglObject:ScrollX)
    DO BGL:Bars:%bglObject
    d2g_PaintNow(%bglObject:G)                                ! sideways is ours: instant
    EXIT
  END
#ENDIF
#IF(%bglMovable)
!  A HEADING BEING CARRIED - or a press that has not yet decided. Seven pixels
!  of sideways travel is the commitment; under that it is still a click and
!  the release will sort. Once carrying: the ghost chip and the drop line are
!  the grid's to draw - it is told the column and the pointer on every move -
!  and the hand cursor is SETCURSOR, the global override, re-asserted every
!  move because Windows re-evaluates the cursor whenever it likes and PROP on
!  the region only answers that re-evaluation sometimes. (Set once through
!  the region it appeared exactly once per activation, which was the bug.)
  IF %bglObject:MvCol
    IF ~%bglObject:MvOn
      IF ABS(mx - %bglObject:MvX) < 7 THEN EXIT.              ! still just a click
      %bglObject:MvOn = 1
    END
    SETCURSOR(CURSOR:Hand)
    d2g_Carry(%bglObject:G,%bglObject:MvCol - 1,mx)
    d2g_PaintNow(%bglObject:G)
    EXIT
  END
#ENDIF
#IF(%bglSizeable)
!  A COLUMN BEING DRAGGED WIDER OR NARROWER. Measured from where the drag STARTED
!  rather than from the last event: deltas lose their remainder and the edge
!  creeps away from the pointer.
  IF %bglObject:RzCol
!  The button-up case is handled above, for all three kinds of drag at once.
    IF %bglObject:RzArmed
      IF ABS(mx - %bglObject:RzX) < 3 THEN EXIT.               ! still just a click on the heading
      %bglObject:RzArmed = 0                                   ! it moved: a real drag
    END
    wid = %bglObject:RzW + mx - %bglObject:RzX
    IF wid < 16 THEN wid = 16.                                 ! never drag it away entirely
#IF(%bglWrap AND %bglVarRows AND %bglLoad = 'File loaded')
!  Hold the measuring for the duration of the drag: this branch repaints on
!  every mouse move, and re-measuring a page of cells per move is exactly the
!  work the cache exists to avoid. BGL:SizeEnd lets it go again.
    d2g_Sizing(%bglObject:G,1)
#ENDIF
    d2g_SetWidth(%bglObject:G,%bglObject:RzCol - 1,wid)
    DO BGL:Bars:%bglObject                                     ! the columns are a different width now
    d2g_PaintNow(%bglObject:G)
    EXIT
  END
!  Not dragging: show the sizing cursor when an edge is grabbable, so there is
!  something to see. Only when it CHANGES, or it is reset on every mouse move
!  and flickers.
  col = -1
  IF my < d2g_HdrHeight(%bglObject:G)
    col = d2g_HitEdge(%bglObject:G,mx)
  END
  IF col >= 0
    IF ~%bglObject:RzCur
!  DragWE, not SizeWE. SizeWE is Windows' plain horizontal double-arrow, the one
!  you get on a window edge. DragWE is Clarion's own splitter - the vertical bar
!  with an arrow either side - which is what a column boundary wants and what
!  every other grid shows there.
      %bglObject:Rgn{PROP:Cursor} = CURSOR:DragWE
      %bglObject:RzCur = 1
    END
  ELSIF %bglObject:RzCur
    %bglObject:Rgn{PROP:Cursor} = ''
    %bglObject:RzCur = 0
  END
#ENDIF
  IF %bglObject:VDrag
    vp = d2g_VDrag(%bglObject:G,my,%bglObject:VGrab)
    %bglObject:VPos = vp                                      ! remembered, for the commit
    d2g_VBar(%bglObject:G,1,vp,BGL:ThumbPct)
#IF(%bglLoad = 'File loaded')
!  FILE LOADED IS ALWAYS LIVE. The records are resident, so following the thumb
!  is the same in-memory fill a wheel notch costs - there is no driver to spare
!  and no KeyDistribution to stumble through, which is everything the deferred
!  mode ever existed to avoid. Same arithmetic as the ScrollDrag key path.
    %bglObject:Sel = (vp * (%bglObject:Count - 1)) / 100
    DO BGL:Anchor:%bglObject
    DO BGL:Fill:%bglObject
#ELSE
#IF(%bglDragLive)
    IF vp <> %bglList{PROP:VScrollPos}
      %bglList{PROP:VScrollPos} = vp
      POST(EVENT:ScrollDrag,%bglList)                         ! the browse fetches, RefreshWindow redraws
    ELSE
      d2g_Repaint(%bglObject:G)
    END
#ELSE
!  The thumb only. The browse is left alone until the button comes up, so a
!  drag across a small file cannot walk the highlight through half a dozen
!  KeyDistribution stops on the way past.
    d2g_Repaint(%bglObject:G)
#ENDIF
#ENDIF
  END
#ELSE
  EXIT
#ENDIF

BGL:Choose:%bglObject ROUTINE
!  The column chooser: every data column the DESIGNER shows, checkmarked when
!  the user has it visible, one toggle per opening. A designer-hidden column
!  (width zero) is machinery and is not on offer; the last visible column
!  cannot be hidden, or there would be nothing left to right-click. The choice
!  is written to the INI with the widths, so it survives restarts.
!
!  After a toggle the drawn indexes shift, so everything keyed by them is
!  re-derived or given up: the sort MARK is re-found from the LIST column it
!  rides (the ORDER itself is unharmed - data stays sorted, exactly like the
!  sorted-but-undisplayed default sort), and any column-value filters are
!  dropped rather than left filtering on what is now a different column. The
!  criteria filter and the search live on fields, not indexes, and survive.
#IF(%bglChooser)
  DATA
c    LONG,AUTO
n    LONG,AUTO
vis  LONG,AUTO
ex   LONG,AUTO
fld  LONG,AUTO
wid  LONG,AUTO
sel  LONG,AUTO
p    LONG,AUTO
head CSTRING(65)
m    CSTRING(3000)
  CODE
  IF ~%bglObject:G THEN EXIT.
  m   = ''
  n   = 0
  vis = 0
  LOOP c = 1 TO 64
    ex = %bglList{PROPLIST:Exists,c}
    IF ~ex THEN BREAK.
    fld = %bglList{PROPLIST:FieldNo,c}
    IF ~fld THEN CYCLE.
    wid = %bglList{PROPLIST:Width,c}
    IF wid < 1 THEN CYCLE.
    head = CLIP(%bglList{PROPLIST:Header,c})
    LOOP p = 1 TO LEN(head)
      IF head[p] = '|' OR head[p] = '{{' OR head[p] = '}' THEN head[p] = ' '.
    END
    head = CLIP(LEFT(head))
    IF ~head THEN head = 'Column ' & c.
    n += 1
    IF ~%bglObject:CHide[c]
      vis += 1
      m = CHOOSE(m = '','+' & head,CLIP(m) & '|+' & head)
    ELSE
      m = CHOOSE(m = '',head,CLIP(m) & '|' & head)
    END
  END
  IF n < 2 THEN EXIT.                                         ! nothing to choose between
  sel = POPUP(m)
  IF ~sel THEN EXIT.
!  Back to the LIST column by the same walk that built the menu.
  n = 0
  LOOP c = 1 TO 64
    ex = %bglList{PROPLIST:Exists,c}
    IF ~ex THEN BREAK.
    fld = %bglList{PROPLIST:FieldNo,c}
    IF ~fld THEN CYCLE.
    wid = %bglList{PROPLIST:Width,c}
    IF wid < 1 THEN CYCLE.
    n += 1
    IF n = sel
      IF ~%bglObject:CHide[c] AND vis <= 1 THEN EXIT.         ! the last one stays
      %bglObject:CHide[c] = 1 - %bglObject:CHide[c]
      BREAK
    END
  END
  IF n <> sel THEN EXIT.
  DO BGL:Columns:%bglObject
#IF(%bglSortHdr OR %bglSortField)
  %bglObject:SortCol = -1
  IF %bglObject:SortOn
    LOOP c = 1 TO %bglObject:Cols
      IF %bglObject:Col[c] = %bglObject:SortOn
        %bglObject:SortCol = c - 1
        BREAK
      END
    END
  END
  d2g_SortMark(%bglObject:G,%bglObject:SortCol,%bglObject:SortDir)
#ENDIF
#IF(%bglFilterBtns AND %bglLoad = 'File loaded')
  IF %bglObject:FAny
    LOOP c = 1 TO 32
      %bglObject:FOn[c]  = 0
      %bglObject:FVal[c] = ''
    END
    %bglObject:FAny = 0
    d2g_FilterOn(%bglObject:G,-1,0)
  END
#ENDIF
#IF(%bglLoad = 'File loaded')
  DO BGL:Map:%bglObject                                       ! a contains-search reads the drawn columns
#ENDIF
  DO BGL:Fill:%bglObject
#ELSE
  EXIT
#ENDIF

BGL:MoveEnd:%bglObject ROUTINE
!  The button came up on an armed heading. Never moved: it was a click, and a
!  click on a heading sorts - this is where the sort went when arming took its
!  place at the press. Moved: it is a drop, and the carried column takes the
!  slot of the heading it landed on. In COrd that is remove-then-insert at the
!  target's original index, which lands AFTER the target coming from the left
!  and BEFORE it coming from the right - the asymmetry every draggable grid
!  has, falling out of the arithmetic rather than being coded for. Dropped off
!  the headings entirely means "never mind".
#IF(%bglMovable)
  DATA
rx  SIGNED,AUTO
ry  SIGNED,AUTO
rw  SIGNED,AUTO
rh  SIGNED,AUTO
sp  LONG,AUTO
mx  LONG,AUTO
tgt LONG,AUTO
src LONG,AUTO
dst LONG,AUTO
i2  LONG,AUTO
j   LONG,AUTO
k   LONG,AUTO
  CODE
  IF ~%bglObject:MvCol THEN EXIT.
  IF ~%bglObject:MvOn
    %bglObject:SortCol = %bglObject:MvCol - 1
    %bglObject:MvCol   = 0
#IF(%bglSortHdr)
    DO BGL:Sort:%bglObject
#ENDIF
    EXIT
  END
  SETCURSOR()                                                 ! the hand goes back
  d2g_Carry(%bglObject:G,-1,0)                                ! and the chip comes down
  d2g_Repaint(%bglObject:G)                                   ! even when the drop goes nowhere
  sp = 0{PROP:Pixels}
  0{PROP:Pixels} = 1
  GETPOSITION(%bglObject:Rgn,rx,ry,rw,rh)
  mx = MOUSEX() - rx
  0{PROP:Pixels} = sp
  tgt = d2g_HitCol(%bglObject:G,mx)
  src = %bglObject:Col[%bglObject:MvCol]                      ! the LIST column being carried
  dst = CHOOSE(tgt >= 0 AND tgt < %bglObject:Cols,%bglObject:Col[tgt + 1],0)
  %bglObject:MvCol = 0
  %bglObject:MvOn  = 0
  IF ~src OR ~dst OR src = dst THEN EXIT.
  i2 = 0
  j  = 0
  LOOP k = 1 TO 64
    IF %bglObject:COrd[k] = src THEN i2 = k.
    IF %bglObject:COrd[k] = dst THEN j = k.
  END
  IF ~i2 OR ~j THEN EXIT.
  LOOP k = i2 TO 63                                           ! pull it out...
    %bglObject:COrd[k] = %bglObject:COrd[k + 1]
  END
  %bglObject:COrd[64] = 0
  LOOP k = 64 TO j + 1 BY -1                                  ! ...and put it back where the target was
    %bglObject:COrd[k] = %bglObject:COrd[k - 1]
  END
  %bglObject:COrd[j] = src
!  The same rebuild the chooser does: drawn indexes have shifted, so the sort
!  mark is re-found from its LIST column, index-keyed value filters are given
!  up, and the map follows the drawn columns.
  DO BGL:Columns:%bglObject
#IF(%bglSortHdr OR %bglSortField)
  %bglObject:SortCol = -1
  IF %bglObject:SortOn
    LOOP k = 1 TO %bglObject:Cols
      IF %bglObject:Col[k] = %bglObject:SortOn
        %bglObject:SortCol = k - 1
        BREAK
      END
    END
  END
  d2g_SortMark(%bglObject:G,%bglObject:SortCol,%bglObject:SortDir)
#ENDIF
#IF(%bglFilterBtns AND %bglLoad = 'File loaded')
  IF %bglObject:FAny
    LOOP k = 1 TO 32
      %bglObject:FOn[k]  = 0
      %bglObject:FVal[k] = ''
    END
    %bglObject:FAny = 0
    d2g_FilterOn(%bglObject:G,-1,0)
  END
#ENDIF
#IF(%bglLoad = 'File loaded')
  DO BGL:Map:%bglObject
#ENDIF
  DO BGL:Fill:%bglObject
#ELSE
  EXIT
#ENDIF

BGL:Sort:%bglObject ROUTINE
!  Sort by the column whose heading was clicked. This is the one routine that
!  reaches into the browse, and it does so through PROP:Order on the VIEW.
!
!  WHY PROP:Order AND NOT THE BROWSE'S OWN SORT. A Legacy browse chooses its
!  sort order in SelectSort, from the TAB - the CHOICE(?CurrentTab) ladder is
!  generated, so setting SortOrder ourselves is pointless: it is recomputed on
!  every RefreshWindow. And only the orders defined at design time exist, so
!  there is nothing to select for a column that has no tab. PROP:Order is not
!  limited that way: any field the view projects can be sorted on.
!
!  WHY IT SURVIVES. Reset restores the default order ONLY when
!  UsingAdditionalSortOrder is set - that flag means "somebody overrode this,
!  put it back". Left alone, Reset skips the restore, and although it still
!  does SET(<key>), PROP:Order takes precedence over the key on a VIEW. So the
!  order set here stays in force through every refill until we give it up.
#IF(%bglSortHdr)
  DATA
lc  LONG,AUTO
fld LONG,AUTO
p   LONG,AUTO
who CSTRING(65)
nm  CSTRING(65)
pc  CSTRING(33)
  CODE
  IF %bglObject:SortCol < 0 THEN EXIT.
  lc  = %bglObject:Col[%bglObject:SortCol + 1]                ! which LIST column that was
  fld = %bglObject:Fld[%bglObject:SortCol + 1]                ! and which queue field
  IF ~lc OR ~fld THEN EXIT.
!  The field's NAME, off the queue. A Legacy browse declares its queue fields
!  after the file fields they came from, prefixed with the instance -
!  BRW1::CUS:NAME - so cutting the prefix leaves a name PROP:Order understands.
!  A column that is not a file field (a computed one, a marker) has no usable
!  name, and there is nothing to sort it by.
  who = CLIP(WHO(%bglQueue,fld))
  p   = INSTRING('::',who,1,1)
  IF p
    nm = SUB(who,p + 2,LEN(who) - p - 1)
  ELSE
    nm = who
  END
  IF ~nm THEN EXIT.
!  Same heading again reverses; a different one starts ascending.
  IF %bglObject:SortOn = lc
    %bglObject:SortDir = -%bglObject:SortDir
  ELSE
    %bglObject:SortOn  = lc
    %bglObject:SortDir = 1
  END
  %bglObject:Order  = CHOOSE(%bglObject:SortDir > 0,'+','-') & CLIP(nm)
!  The same sort said the other way. PROP:Order names FILE fields; SORT() on the
!  queue names QUEUE fields, which are the file names carrying the browse's own
!  prefix - so the unstripped WHO() answer is exactly what SORT wants.
  %bglObject:QOrder = CHOOSE(%bglObject:SortDir > 0,'+','-') & CLIP(who)
!  ...and the same sort a third way: the field NUMBER and whether it holds
!  text, for the comparison function. Text or number is read off the column's
!  picture - no picture or @s is text and sorts case-blind; @n @e @d @t @p are
!  value pictures and compare as values.
  %bglObject:QFld1 = fld
  %bglObject:QStr1 = 1
  pc = UPPER(CLIP(%bglObject:Pic[%bglObject:SortCol + 1]))
  IF LEN(pc) >= 2
    IF INSTRING(SUB(pc,2,1),'NEDTP',1,1) THEN %bglObject:QStr1 = 0.
  END
#IF(%bglSortTie)
  IF UPPER(CLIP(nm)) <> UPPER('%bglSortTie')                  ! not twice, if they clicked it
    %bglObject:Order  = CLIP(%bglObject:Order) & ',+%bglSortTie'
!  The queue's name for the tie field is the browse prefix and the file name run
!  together, which is known at generate time - no lookup needed.
    %bglObject:QOrder = CLIP(%bglObject:QOrder) & ',+%bglBrowseObj::%bglSortTie'
  END
#ENDIF
  DO BGL:Order:%bglObject
  %bglObject:SortSeen = %bglBrowseObj::SortOrder
  d2g_SortMark(%bglObject:G,%bglObject:SortCol,%bglObject:SortDir)
  DO BGL:Fill:%bglObject
#ELSE
  EXIT
#ENDIF

BGL:SortDefault:%bglObject ROUTINE
!  The sort the window opens on. Applied once, on the first BGL:Resized - by
!  which time the window is up, the resizer has run and the browse has been
!  round its own first fill, so Reset is safe to call and the columns are known.
!  Doing it in Setup would be too early on all three counts.
#IF(%bglSortField)
  DATA
c   LONG,AUTO
p   LONG,AUTO
who CSTRING(65)
nm  CSTRING(65)
  CODE
  IF ~%bglObject:G THEN EXIT.
  %bglObject:SortDir = CHOOSE('%bglSortDirn' = 'Descending',-1,1)
  %bglObject:Order   = CHOOSE(%bglObject:SortDir > 0,'+','-') & '%bglSortField'
!  And the same sort in QUEUE field names, for the file-loaded SORT(). PROP:Order
!  names a FILE field; SORT names a QUEUE MEMBER, and a browse queue declares its
!  members as the file name carrying the instance prefix. Same field, two
!  spellings, and they are not interchangeable - do not "tidy" one into the other.
  %bglObject:QOrder  = CHOOSE(%bglObject:SortDir > 0,'+','-') & '%bglBrowseObj::%bglSortField'
#IF(%bglSortTie)
  IF UPPER('%bglSortField') <> UPPER('%bglSortTie')
    %bglObject:Order  = CLIP(%bglObject:Order) & ',+%bglSortTie'
    %bglObject:QOrder = CLIP(%bglObject:QOrder) & ',+%bglBrowseObj::%bglSortTie'
  END
#ENDIF
!  Which drawn column is that field, so the triangle lands on the right heading.
!  A field that is sorted on but not displayed is perfectly legal - there is
!  simply no heading to mark, and SortCol stays -1.
  %bglObject:SortCol = -1
  %bglObject:SortOn  = 0
  %bglObject:QFld1   = 0
  LOOP c = 1 TO %bglObject:Cols
    who = CLIP(WHO(%bglQueue,%bglObject:Fld[c]))
    p   = INSTRING('::',who,1,1)
    IF p
      nm = SUB(who,p + 2,LEN(who) - p - 1)
    ELSE
      nm = who
    END
    IF UPPER(CLIP(nm)) = UPPER('%bglSortField')
      %bglObject:SortCol = c - 1
      %bglObject:SortOn  = %bglObject:Col[c]
!  The comparison function's view of the same sort: the field number, and text
!  or number off the column's picture, as the heading click does it.
      %bglObject:QFld1 = %bglObject:Fld[c]
      %bglObject:QStr1 = 1
      nm = UPPER(CLIP(%bglObject:Pic[c]))                     ! reusing nm: the picture now
      IF LEN(nm) >= 2
        IF INSTRING(SUB(nm,2,1),'NEDTP',1,1) THEN %bglObject:QStr1 = 0.
      END
      BREAK
    END
  END
  IF ~%bglObject:QFld1
!  Sorted on but not displayed: find the member by its label instead - WHO
!  answers them UPPERCASED. With no column there is no picture, and text is the
!  safe guess: a number sorted as text is ordered oddly but consistently, where
!  a name sorted as binary was the bug this exists to fix.
    LOOP c = 1 TO 512
      who = CLIP(WHO(%bglQueue,c))
      IF ~who THEN BREAK.
      IF who = UPPER('%bglBrowseObj::%bglSortField')
        %bglObject:QFld1 = c
        %bglObject:QStr1 = 1
        BREAK
      END
    END
  END
  DO BGL:Order:%bglObject
#IF(%bglLoad = 'File loaded')
!  ...but the OPENING sort starts at the top. BGL:Order now keeps the selection on
!  its record across a re-sort, which is right when somebody clicks a heading and
!  wrong here: nobody has chosen anything yet, and whatever happened to be first
!  in the file's own order is not a selection worth preserving.
  %bglObject:Sel = 0
  %bglObject:Top = 0
  DO BGL:Anchor:%bglObject
#ENDIF
  IF %bglObject:SortCol >= 0
    d2g_SortMark(%bglObject:G,%bglObject:SortCol,%bglObject:SortDir)
  END
  %bglObject:SortSeen = %bglBrowseObj::SortOrder
#ELSE
  EXIT
#ENDIF

BGL:SortQ:%bglObject ROUTINE
!  The file-loaded SORT itself, case-blind - every sort of the resident queue
!  comes through here so they all agree.
!
!  A NUMBER COLUMN NEEDS NOTHING SPECIAL: the string form of SORT compares
!  queue members by their own types, so numbers, dates and times were always
!  ordered correctly. Only TEXT was wrong - the string form cannot say UPPER(),
!  so every capital sorted before every lowercase letter. Uniformly Title Case
!  demo data hid that; 5000 mixed-case names did not.
!
!  TEXT GOES DECORATE - SORT - UNDECORATE. A first pass copies each record's
!  sort value, uppercased, into a scratch queue alongside the ordinal it came
!  from; the scratch queue is sorted by that key with the ordinal as tiebreak,
!  which makes it a stable permutation; the queue is then rebuilt by appending
!  the records in permutation order and deleting the originals off the front.
!  Every step is GET, ADD, DELETE and a string-form SORT - nothing here asks
!  the runtime for anything exotic. (The first attempt was the comparison-
!  function form of SORT with WHAT() on its two *GROUP parameters, and every
!  sort came back a silent no-op - the callback's groups do not answer WHAT()
!  the way a real queue does. Nothing that matters survives in that form.)
!
!  The tiebreak pre-sort keeps equal keys in the tie field's order, so equal
!  names still line up by the same field the string form appended. A key longer
!  than the scratch column compares on its first 64 characters - names here are
!  20 - and a sort chosen by a path that could not resolve the field number
!  falls back to the old string form: wrongly ordered capitals beat no sort.
#IF((%bglSortHdr OR %bglSortField) AND %bglLoad = 'File loaded')
  DATA
i LONG,AUTO
n LONG,AUTO
  CODE
  IF ~%bglObject:QOrder THEN EXIT.
  IF ~%bglObject:QStr1 OR ~%bglObject:QFld1
    SORT(%bglQueue,%bglObject:QOrder)
    EXIT
  END
#IF(%bglSortTie)
  SORT(%bglQueue,'+%bglBrowseObj::%bglSortTie')               ! equal keys will keep this order
#ENDIF
  FREE(BGLK:%bglObject)
  n = RECORDS(%bglQueue)
  LOOP i = 1 TO n
    GET(%bglQueue,i)
    %bglObject:KKey = UPPER(WHAT(%bglQueue,%bglObject:QFld1))
    %bglObject:KOrd = i
    ADD(BGLK:%bglObject)
  END
  SORT(BGLK:%bglObject,CHOOSE(%bglObject:SortDir < 0,'-','+') & '%bglObject:KKey,+%bglObject:KOrd')
!  The originals sit at 1..n while the copies go on behind them, so GET by the
!  permutation's ordinals stays right all the way through the append.
  LOOP i = 1 TO n
    GET(BGLK:%bglObject,i)
    GET(%bglQueue,%bglObject:KOrd)
    ADD(%bglQueue)
  END
  LOOP i = 1 TO n
    GET(%bglQueue,1)
    DELETE(%bglQueue)
  END
  FREE(BGLK:%bglObject)
#ELSE
  EXIT
#ENDIF

BGL:Order:%bglObject ROUTINE
!  Impose the order we are holding, and reload under it.
!
!  THE ORDER GOES ON AFTER Reset, NOT BEFORE. Reset does CLOSE(view) ... OPEN
!  (view), and a CLOSE throws PROP:Order away - which is why setting it first
!  and then calling RefreshPage did nothing at all: RefreshPage calls Reset when
!  the queue is empty, and the order was discarded before a record was read. The
!  generated code says as much if you read it the right way round: Reset always
!  assigns PROP:Order AFTER its own CLOSE, and never relies on it surviving one.
!
!  So Reset is allowed to do its job first - the key, the filter, the range
!  limit - and the order goes on the open view afterwards, followed by SET() to
!  make it current. That is exactly the sequence that read Tims Pizza first.
#IF(%bglSortHdr OR %bglSortField)
#IF(%bglLoad = 'File loaded')
!  FILE LOADED. The records are already here, so the sort is a SORT - no view, no
!  Reset, no refill, and nothing for a later Reset to undo. This is the whole
!  reason the mode is worth having: the awkwardness of the page-loaded path below
!  exists only because the queue has to be rebuilt from the file to reorder it.
  IF ~%bglObject:QOrder THEN EXIT.
  IF ~%bglObject:Loaded THEN DO BGL:Load:%bglObject.
#IF(%bglSortTie)
!  REMEMBER THE RECORD BEFORE THE ORDER MOVES UNDER IT. Re-sorting does not change
!  which record somebody was looking at, only where it sits - so the selection
!  should travel with it rather than snapping to the top. Read the identity out of
!  the row we are on while the old order still holds; BGL:Locate puts us back on
!  it once the new one is in place.
  %bglObject:HaveFind = 0
  IF %bglObject:Count AND ~%bglObject:FillEnd
    IF %bglObject:FiltOn
      GET(BGLF:%bglObject,%bglObject:Sel + 1)
      IF ~ERRORCODE() THEN GET(%bglQueue,%bglObject:Ref).
    ELSE
      GET(%bglQueue,%bglObject:Sel + 1)
    END
    IF ~ERRORCODE()
      %bglObject:Find     = %bglBrowseObj::%bglSortTie
      %bglObject:HaveFind = 1
    END
  END
#ENDIF
  DO BGL:SortQ:%bglObject
!  The map holds ORDINALS into the queue, and the SORT just moved every record
!  to a different ordinal - so every reference in it is now wrong. Rebuild it
!  before anything reads through it.
  DO BGL:Map:%bglObject
  IF %bglObject:FillEnd
    %bglObject:Sel     = %bglObject:Count - 1                 ! the thumb was dropped at the end
    %bglObject:FillEnd = 0
    DO BGL:Anchor:%bglObject
    EXIT
  END
#IF(%bglSortTie)
  IF %bglObject:HaveFind
    DO BGL:Locate:%bglObject                                  ! sets Sel and brings it into view
    EXIT
  END
#ENDIF
!  No unique field to recognise the record by, so there is nothing to hold on to.
  %bglObject:Sel = 0
  DO BGL:Anchor:%bglObject
#ELSE
  IF ~%bglObject:Order THEN EXIT.
  DO %bglBrowseObj::Reset
  %bglBrowseObj::View:Browse{PROP:Order} = %bglObject:Order
  SET(%bglBrowseObj::View:Browse)
!  Fill through FillRecord, not RefreshPage. RefreshPage would call Reset a
!  second time on the empty queue and undo what has just been done; FillRecord
!  reads the view where it stands and asks nothing about order.
  FREE(%bglQueue)
  %bglBrowseObj::RecordCount   = 0
  %bglBrowseObj::AddQueue      = True
  %bglBrowseObj::ItemsToFill   = %bglList{PROP:Items}
  IF %bglObject:FillEnd
!  Backward from the end of OUR order - what ScrollEnd would have done if Reset
!  had not just thrown the order away on its way past.
    %bglBrowseObj::FillDirection = FillBackward
    DO %bglBrowseObj::FillRecord
    %bglBrowseObj::CurrentChoice = %bglBrowseObj::RecordCount
    %bglObject:FillEnd = 0
  ELSE
    %bglBrowseObj::FillDirection = FillForward
    DO %bglBrowseObj::FillRecord
    %bglBrowseObj::CurrentChoice = 1                          ! a new order starts at the top
  END
!  TELL THE LIST, not just the browse. CurrentChoice is the browse's own idea of
!  the highlight; what the grid draws comes from CHOICE(), which reads the LIST.
!  ProcessScroll writes SelStart before posting the selection for exactly this
!  reason - skip it and the rows move while the highlight stays where it was,
!  which is why the last page arrived with nothing selected on it.
  %bglList{PROP:SelStart} = %bglBrowseObj::CurrentChoice
  DO %bglBrowseObj::PostNewSelection
#ENDIF
#ELSE
  EXIT
#ENDIF

BGL:Unsort:%bglObject ROUTINE
!  Give the order back to the browse. Called when the browse has changed its own
!  sort order underneath us - a tab, or a reset field - because at that point our
!  column sort is no longer what anybody asked for: the new tab would be showing
!  its own records, filtered its own way, but still in our order.
!
!  Setting UsingAdditionalSortOrder is how Reset is asked to put the default
!  order back; it clears the flag itself once it has.
#IF(%bglSortHdr OR %bglSortField)
  IF ~%bglObject:SortOn THEN EXIT.
  %bglObject:SortOn  = 0
  %bglObject:SortDir = 0
  %bglObject:SortCol = -1
  %bglObject:Order   = ''
  %bglObject:QOrder  = ''
  %bglObject:QFld1   = 0
  d2g_SortMark(%bglObject:G,-1,0)
#IF(%bglLoad = 'File loaded')
!  The browse changed its own sort order, which for a Legacy browse means the tab
!  changed - and the tab carries a different FILTER and range limit, not just a
!  different key. So the resident copy is of the wrong set of records and has to
!  be read again. Clearing Loaded is enough: the fill this was called from does
!  the reload a few lines later, under whatever Reset now sets up.
  %bglObject:Loaded = 0
  %bglObject:Sel    = 0
  %bglObject:Top    = 0
  EXIT
#ENDIF
  %bglBrowseObj::UsingAdditionalSortOrder = True
  FREE(%bglQueue)
  %bglBrowseObj::RecordCount = 0
  %bglBrowseObj::RefreshMode = RefreshOnTop
  DO %bglBrowseObj::RefreshPage
  DO %bglBrowseObj::PostNewSelection
#ELSE
  EXIT
#ENDIF

BGL:DragEnd:%bglObject ROUTINE
!  The button came up after a downward drag: move the browse to where the thumb
!  was left. With continuous updating on there is nothing to do - it has been
!  moving all along - so this only has work when the move was deferred.
#IF(%bglBars AND NOT %bglDragLive)
  IF ~%bglObject:G THEN EXIT.
#IF(%bglLoad = 'File loaded')
!  FILE LOADED: the thumb addresses RECORDS, so where it was dropped IS the
!  answer - no KeyDistribution lookup, no ScrollDrag, nothing asked of the
!  browse. This is the payoff the whole mode was for.
  DO BGL:Clamp:%bglObject                                     ! bounds; the thumb sets Top below
  IF %bglObject:Count > d2g_PageSize(%bglObject:G)
    %bglObject:Top = %bglObject:VPos                                            |
                   * (%bglObject:Count - d2g_PageSize(%bglObject:G)) / 100
  ELSE
    %bglObject:Top = 0
  END
  IF %bglObject:Top < 0 THEN %bglObject:Top = 0.
  DO BGL:Fill:%bglObject
  EXIT
#ENDIF
#IF(%bglSortHdr OR %bglSortField)
!  UNDER A SORT OF OUR OWN, THE TWO ENDS ARE OURS TO HANDLE. Dropped through to
!  ScrollDrag, position 100 becomes EVENT:ScrollBottom, which calls ScrollEnd,
!  which opens with a Reset - and that discards our PROP:Order before filling.
!  The rows then come back in the file's own order, BGL:Fill notices and rebuilds
!  from the top, and a drag to the bottom of the bar ends up on the first page.
!  Rebuilding here instead, backward from the end, lands where the pointer says.
  IF %bglObject:Order
    IF %bglObject:VPos >= 100
      %bglObject:FillEnd = 1
      DO BGL:Order:%bglObject
      DO BGL:Fill:%bglObject
      EXIT
    END
    IF %bglObject:VPos <= 1
      DO BGL:Order:%bglObject                                 ! FillEnd is 0: from the top
      DO BGL:Fill:%bglObject
      EXIT
    END
  END
#ENDIF
  IF %bglObject:VPos <> %bglList{PROP:VScrollPos}
    %bglList{PROP:VScrollPos} = %bglObject:VPos
    POST(EVENT:ScrollDrag,%bglList)
  END
#ELSE
  EXIT
#ENDIF

BGL:Scroll:%bglObject ROUTINE
!  Sideways is ours: slide the columns and repaint, nothing else changes.
!  Downwards is the browse's: it is told to scroll exactly as it would be by its
!  own scrollbar, and when it has refilled its queue RefreshWindow runs, which is
!  where the grid picks the new page up. So paging, locators and range limits
!  keep behaving as they always did.
!
!  Every event posted below is one the Legacy BrowseBox already handles in its
!  own CASE FIELD() OF ?List - ScrollUp, ScrollDown, PageUp, PageDown, ScrollTop,
!  ScrollBottom and ScrollDrag - and PROP:VScrollPos is the same property its
!  ScrollDrag routine reads. Nothing here had to be adapted from the ABC version.
#IF(%bglBars OR %bglWheel)
  DATA
i    LONG,AUTO
n    LONG,AUTO
sp   LONG,AUTO
page LONG,AUTO
  CODE
  IF BGL:LastCode = BGL:FontCode
!  The type changed size, so the rows did too - and this time the GRID is the one
!  that knows how tall they are. NOT BGL:Rows, which asks the LIST: the LIST's
!  line height is the number we ourselves pushed up the last time the type grew,
!  so asking it again just gets that number back and the rows ratchet up and
!  never come down. When the type changes size the grid is the authority.
    sp = 0{PROP:Pixels}
    0{PROP:Pixels} = 1
#IF(%bglWrap AND %bglVarRows AND %bglLoad = 'File loaded')
    %bglList{PROP:LineHeight} = d2g_RowH(%bglObject:G) / %bglWrapLines
    %bglObject:BtmN = 0                                       ! new type, new heights: the landing is stale
#ELSE
    %bglList{PROP:LineHeight} = d2g_RowH(%bglObject:G)
#ENDIF
    0{PROP:Pixels} = sp
    DO BGL:Items:%bglObject                                   ! and load to the new page size
    DO BGL:Fill:%bglObject
    EXIT
  END
#IF(%bglLoad = 'File loaded')
!  FILE LOADED: every scroll is ours. Nothing is posted to the browse, because
!  the browse has no page to fetch - the records are already here. The wheel and
!  the bar move the WINDOW (Top); the selection is left where it is, which is how
!  a scrollbar behaves everywhere outside Clarion.
  IF ~%bglObject:G THEN EXIT.
  page = d2g_PageSize(%bglObject:G)
  IF page < 1 THEN page = 1.
  IF BGL:LastCode = BGL:WheelCode
    n = INT(ABS(BGL:LastPos) / BGL:WheelNotch) * %bglWheelLines
    IF n < 1 THEN n = 1.
    IF BGL:LastPos > 0
      %bglObject:Top -= n
    ELSE
      %bglObject:Top += n
    END
  ELSIF BGL:LastBar = BGL:SbHorz
    %bglObject:ScrollX = BGL:LastPos
    d2g_ScrollX(%bglObject:G,%bglObject:ScrollX)
    d2g_Repaint(%bglObject:G)
    EXIT
  ELSE
    CASE BGL:LastCode
    OF 0
      %bglObject:Top -= 1
    OF 1
      %bglObject:Top += 1
    OF 2
      %bglObject:Top -= page
    OF 3
      %bglObject:Top += page
    OF 6
      %bglObject:Top = 0
    OF 7
      %bglObject:Top = %bglObject:Count - page
    END
  END
  IF %bglObject:Top > %bglObject:Count - page THEN %bglObject:Top = %bglObject:Count - page.
  IF %bglObject:Top < 0 THEN %bglObject:Top = 0.
  DO BGL:Fill:%bglObject
  EXIT
#ENDIF
  IF BGL:LastCode = BGL:WheelCode
!  One notch is three rows, the same as everywhere else in Windows. The browse is
!  asked to scroll exactly as its own scrollbar would ask it, so paging, locators
!  and range limits are none of our business.
    n = INT(ABS(BGL:LastPos) / BGL:WheelNotch) * %bglWheelLines
    IF n < 1 THEN n = 1.
    IF n > 30 THEN n = 30.                                    ! a flicked wheel is not a page jump
    LOOP i = 1 TO n
      IF BGL:LastPos > 0
        POST(EVENT:ScrollUp,%bglList)
      ELSE
        POST(EVENT:ScrollDown,%bglList)
      END
    END
    EXIT
  END
  IF BGL:LastBar = BGL:SbHorz
    %bglObject:ScrollX = BGL:LastPos
    d2g_ScrollX(%bglObject:G,%bglObject:ScrollX)
    d2g_Repaint(%bglObject:G)
    EXIT
  END
  CASE BGL:LastCode
  OF 0
    POST(EVENT:ScrollUp,%bglList)
  OF 1
    POST(EVENT:ScrollDown,%bglList)
  OF 2
    POST(EVENT:PageUp,%bglList)
  OF 3
    POST(EVENT:PageDown,%bglList)
  OF 6
    POST(EVENT:ScrollTop,%bglList)
  OF 7
    POST(EVENT:ScrollBottom,%bglList)
  ELSE
    %bglList{PROP:VScrollPos} = BGL:LastPos                   ! the thumb, dragged
    POST(EVENT:ScrollDrag,%bglList)
  END
#ELSE
  EXIT
#ENDIF

BGL:Bars:%bglObject ROUTINE
!  Size both scrollbars from what is actually showing. Windows hides a bar whose
!  page covers its whole range, so the horizontal one appears only when the
!  columns are wider than the view, which is what anyone expects.
#IF(%bglBars)
  DATA
tot   LONG,AUTO
view  LONG,AUTO
pct   LONG,AUTO
fRecs LONG,AUTO
page  LONG,AUTO
room  LONG,AUTO
  CODE
  IF ~%bglObject:G THEN EXIT.
  IF ~%bglObject:Barred THEN EXIT.
!  Sideways: the grid's own business - the total column width against the view.
  tot  = d2g_TotalWidth(%bglObject:G)
  view = d2g_ViewWidth(%bglObject:G)
  IF view < 1 THEN view = 1.
  IF tot <= view
    %bglObject:ScrollX = 0
    d2g_ScrollX(%bglObject:G,0)
#IF(%bglBarStyle = 'Windows')
    BGL_SetBar(%bglObject:Rgn{PROP:Handle},BGL:SbHorz,0,1,1)  ! nothing to scroll: no bar
#ELSE
    d2g_HBar(%bglObject:G,0,0,1,1)
#ENDIF
  ELSE
    IF %bglObject:ScrollX > tot - view THEN %bglObject:ScrollX = tot - view.
#IF(%bglBarStyle = 'Windows')
    BGL_SetBar(%bglObject:Rgn{PROP:Handle},BGL:SbHorz,%bglObject:ScrollX,view,tot)
#ELSE
    d2g_HBar(%bglObject:G,1,%bglObject:ScrollX,view,tot)
#ENDIF
  END
!  Down: NOT ours. The browse knows where it is in the file and keeps that in the
!  LIST's own PROP:VScrollPos, nought to a hundred - the same approximate position
!  Clarion's own browse thumb shows, because on an ISAM file that is the only
!  answer there is.
!
!  PROP:VScrollPos is only kept when the LIST was given a scrollbar, and with it
!  off, writing the property is ignored - so every drag would read back as nought
!  and be taken for "go to the top". Turning it on costs nothing here: the LIST is
!  invisible, so this is a number we are borrowing, not a scrollbar anyone sees.
!  A Legacy browse LIST usually carries HVSCROLL already; this is for the one
!  that does not.
#IF(%bglLoad = 'File loaded')
!  FILE LOADED: THE THUMB CAN BE HONEST. Every record is resident, so both the
!  position and the size of the thumb are arithmetic on record numbers instead of
!  a guess against a hundred synthetic key stops. This is the whole reason the
!  mode is worth having, and it is four lines.
  page = d2g_PageSize(%bglObject:G)
  IF page < 1 THEN page = 1.
  IF %bglObject:Count > page
    room = %bglObject:Count - page
    pct  = page * 100 / %bglObject:Count
    IF pct < 4 THEN pct = 4.
    IF ~%bglObject:VDrag
      d2g_VBar(%bglObject:G,1,%bglObject:Top * 100 / room,pct)
    END
  ELSE
    d2g_VBar(%bglObject:G,0,0,100)                            ! it all fits: no bar wanted
  END
#ELSE
  %bglList{PROP:VScroll} = 1
  IF ~%bglObject:VDrag                                        ! not while it is being dragged
    pct = BGL:ThumbPct
#IF(%bglFile)
!  How big the thumb should be is a question that CAN be answered honestly:
!  RECORDS() reads the count out of the file header, so it costs nothing. A page
!  against the whole file is what every other scrollbar in Windows means by the
!  size of its thumb.
    fRecs = RECORDS(%bglFile)
    IF fRecs > 0
      pct = 100 * RECORDS(%bglQueue) / fRecs
      IF pct < 4 THEN pct = 4.
      IF pct > 100 THEN pct = 100.
    END
#ENDIF
    d2g_VBar(%bglObject:G,CHOOSE(pct >= 100, 0, 1),%bglList{PROP:VScrollPos},pct)
  END
#ENDIF
!  A scrollbar appearing or disappearing RESIZES the client area behind our back -
!  hide the horizontal one and the client grows by its height. Nothing covers the
!  strip it vacated until the render target is grown to match, so what shows there
!  is whatever is underneath, which is the old list. This does nothing at all
!  unless the client area really did change.
  d2g_Resize(%bglObject:G)
!  ...AND PUT THE BROWSE BACK IN STEP WITH IT. This is the whole reason a bar
!  appearing matters. The queue is capped at ?List{PROP:Items} - BrowseBox
!  deletes from the far end once RecordCount reaches it (CtlBrow's FillRecord) -
!  and ScrollOne only slides the queue once the selection has reached the end of
!  it. So PROP:Items decides both how many records exist and when the data
!  starts moving instead of the highlight.
!
!  A horizontal scrollbar appearing takes its own height out of the region's
!  client area, so the grid can draw one row fewer than it could a moment ago.
!  Leave PROP:Items where it was and the browse keeps loading for the taller
!  grid: the last row or two live below the visible area, the highlight walks
!  onto them and vanishes, and when the queue finally does slide it has several
!  rows of catching up to do - which is seen as the list jumping instead of
!  scrolling, and only ever at the bottom, because that is the only place the
!  extra records are.
!
!  Safe to call from here: BGL:Items only reads d2g_PageSize and writes
!  PROP:LineHeight, and it writes nothing at all once the two agree, so this
!  settles rather than oscillating.
  DO BGL:Items:%bglObject
#ELSE
  EXIT
#ENDIF
#ENDAT
#!#############################################################################
#!  CONTROL TEMPLATE - BrowseGridLegSearch
#!#############################################################################
#!  A search box for a file-loaded grid: type, and the grid narrows to matching
#!  rows as you go; clear it and everything is back. This is the browser-style
#!  replacement for Clarion's jump-to locator - deliberately a FILTER, not a
#!  jump, because a search that hides what did not match is what a search box
#!  means everywhere outside Clarion.
#!
#!  DELIBERATELY THIN. The box owns no logic: it writes the text and scope into
#!  the grid's own variables and calls the grid's Refilter routine, which is
#!  where matching, selection-keeping and redrawing live. The grid works the
#!  same whether the text came from here or from anywhere else that cares to
#!  set it - which is what will let the eventual global template, or a class,
#!  drive the same engine without this control existing at all.
#!
#!  PAGE LOADED: the box generates and compiles but does nothing - the queue
#!  holds one page, so there is nothing to search. Legacy's own locator types
#!  remain the answer there.
#CONTROL(BrowseGridLegSearch,'BrowseGrid Legacy - search box for a grid'),MULTI,WINDOW,REQ(BrowseGridLegGlobal),DESCRIPTION('Search box on ' & %blConnect)
  CONTROLS
    PROMPT('Loca&te'),AT(0,1,26,10),USE(?BGLSearchPrompt)
    ENTRY(@s40),AT(28,0,100,10),USE(?BGLSearch),IMM,#REQ
    BUTTON('r'),AT(118,0,10,10),USE(?BGLSearchClear),FONT('Marlett',8),FLAT,SKIP,TIP('Clear the search'),#REQ
  END
#SHEET
  #TAB('&Search')
    #BOXED('Which grid')
      #PROMPT('&Grid object this box searches:',@s64),%blConnect,REQ,DEFAULT('Grid1')
      #DISPLAY('The Object name from the BrowseGridLeg extension on this same')
      #DISPLAY('procedure - Grid1, unless it was changed there. A wrong name')
      #DISPLAY('fails at compile time, complaining about BGL:Refilter.')
    #ENDBOXED
    #BOXED('Matching')
      #PROMPT('&Match:',DROP('Starts with (sort column)|Contains (all columns)')),%blScope,DEFAULT('Starts with (sort column)')
      #DISPLAY('Starts with - the classic locator question, asked of the column')
      #DISPLAY('the grid is currently sorted by. Type "jo" and the grid narrows')
      #DISPLAY('to names beginning Jo.')
      #DISPLAY('Contains - anywhere in any drawn column, the way a browser or')
      #DISPLAY('spreadsheet search behaves. Numbers take part through their')
      #DISPLAY('display text.')
      #DISPLAY('')
      #DISPLAY('Either way the match is case-blind, rows that fail it are HIDDEN')
      #DISPLAY('rather than jumped past, the thumb resizes to the narrowed set,')
      #DISPLAY('and clearing the box brings everything back. The selection stays')
      #DISPLAY('on its record if that record still matches.')
    #ENDBOXED
  #ENDTAB
#ENDSHEET
#ATSTART
#DECLARE(%blControl)
#DECLARE(%blClear)
#FOR(%Control),WHERE(%ControlInstance = %ActiveTemplateInstance)
  #IF(%ControlType = 'ENTRY')
    #SET(%blControl,%Control)
  #ELSIF(%ControlType = 'BUTTON')
    #SET(%blClear,%Control)
  #ENDIF
#ENDFOR
#ENDAT
#!
#AT(%DataSection)
#IF(%blClear)
BGLS:Sty%ActiveTemplateInstance LONG                          ! scratch, for the style juggling at open
#ENDIF
#ENDAT
#!
#!  Every keystroke, not just the accept: the ENTRY carries IMM, so each
#!  character arrives as EVENT:NewSelection with the text readable through
#!  PROP:ScreenText before it is ever "accepted" - the same live-read ABC's own
#!  drop-combo uses for search-as-you-type. Routed through the same embed the
#!  grid uses for all its events, which is proven ground.
#!  Register with the grid, so typing on the LIST itself can be echoed into this
#!  box - the way a Clarion locator always took keystrokes from the browse. The
#!  grid's type-to-search stays dormant (Echo = 0) unless a box has said it is
#!  here to receive it.
#AT(%AfterWindowOpening)
  %blConnect:Echo      = %blControl
  %blConnect:FiltScope = CHOOSE('%blScope' = 'Contains (all columns)',1,0)
!  Give the ENTRY a real backing variable. Its USE is a bare field equate, and a
!  control with no USE variable redisplays from NOTHING whenever it gains the
!  focus - so clicking into the box wiped what type-to-search had put there,
!  while the list stayed narrowed: text and display had parted company. Bound to
!  FiltText itself, the box redraws from the one true value on every focus
!  change. ABC's EntryLocatorClass does precisely this with its Shadow
!  (Control{PROP:Use} = SELF.Shadow).
  %blControl{PROP:Use} = %blConnect:FiltText
#IF(%blClear)
!  The clear button lives INSIDE the box, visually: snapped to the entry's right
!  edge at run time, whatever size the developer stretched the entry to in the
!  designer. Marlett's 'r' is the same x every Windows close button wears, so
!  there is no icon to ship. Hidden until there is something to clear.
  %blConnect:EchoX = %blClear
  %blClear{PROP:XPos}   = %blControl{PROP:XPos} + %blControl{PROP:Width} - 11
  %blClear{PROP:YPos}   = %blControl{PROP:YPos} + 1
  %blClear{PROP:Width}  = 10
  %blClear{PROP:Height} = %blControl{PROP:Height} - 2
  %blClear{PROP:Hide}   = 1
!  AND SETTLE WHO OWNS THE OVERLAP, or Windows decides against us both ways:
!  the ENTRY above the button in z-order took every click meant for the x, and
!  each keystroke's redraw painted the ENTRY's full rectangle straight over it -
!  which is why the x appeared on the first letter (the unhide painted it last)
!  and vanished on the second (Hide was already 0, so nothing repainted it).
!  WS_CLIPSIBLINGS on the ENTRY makes its painting go AROUND siblings, and the
!  SetWindowPos raises the button above it. The grid does the same two moves to
!  keep the LIST from painting over the region - this is that fight in
!  miniature, solved the same way.
  BGLS:Sty%ActiveTemplateInstance = bglApi_GetWindowLong(%blControl{PROP:Handle},BGL:GwlStyle)
  bglApi_SetWindowLong(%blControl{PROP:Handle},BGL:GwlStyle,                    |
                       BOR(BGLS:Sty%ActiveTemplateInstance,BGL:ClipSib))
  bglApi_SetWindowPos(%blControl{PROP:Handle},0,0,0,0,0,                        |
                      BOR(BOR(BGL:FrameChanged,BGL:NoMove),BOR(BGL:NoSize,BGL:NoZOrder)))
  bglApi_SetWindowPos(%blClear{PROP:Handle},BGL:HwndTop,0,0,0,0,                |
                      BOR(BGL:NoMove,BGL:NoSize))
#ENDIF
#ENDAT
#!
#AT(%AcceptLoopBeforeFieldHandling)
  IF FIELD() = %blControl
    CASE EVENT()
    OF EVENT:NewSelection OROF EVENT:Accepted
!  CLIP here, deliberately - the opposite call from the grid's own append path.
!  ScreenText off an ENTRY can come back padded to the picture, and unclipped
!  padding makes FiltText's LEN() lie, so backspacing after typing in the box
!  would eat invisible spaces first and appear dead. The cost - losing a
!  deliberately typed trailing space when typing continues on the LIST - is the
!  lesser evil, and matching CLIPs the text anyway.
      %blConnect:FiltText  = CLIP(%blControl{PROP:ScreenText})
      %blConnect:FiltScope = CHOOSE('%blScope' = 'Contains (all columns)',1,0)
#IF(%blClear)
      %blClear{PROP:Hide}  = CHOOSE(~%blConnect:FiltText,1,0)
#ENDIF
      DO BGL:Refilter:%blConnect
    END
  END
#IF(%blClear)
!  The x. Clear everything, put the full list back, and hand the focus to the
!  LIST - the click meant "done searching", and from the LIST typing starts a
!  fresh search without another click.
  IF FIELD() = %blClear AND EVENT() = EVENT:Accepted
    %blConnect:FiltText = ''
!  ScreenText, not DISPLAY(). DISPLAY redraws from the USE variable, and the
!  runtime PROP:Use rebinding proved less dependable than advertised - the list
!  reset while yesterday's text sat in the box. ScreenText writes the pixels
!  directly and is the same mechanism the type-to-search echo already uses on
!  every keystroke, so it is known to work here.
    %blControl{PROP:ScreenText} = ''
    %blClear{PROP:Hide} = 1
    DO BGL:Refilter:%blConnect
    IF %blConnect:LstF
      SELECT(%blConnect:LstF)
    END
  END
#ENDIF
#ENDAT
#!#############################################################################
#!  CRITERIA FILTER - Roberto's myFilter, converted to Legacy
#!#############################################################################
#!  The class (MyFilterClass.inc/.clw) is used UNCHANGED - it is pure Clarion:
#!  its own WINDOW, its own ACCEPT loop, no ABC anywhere. What was converted is
#!  the template glue: ABC's BRW1.SetFilter(expr,slot) became PROP:Filter on
#!  the view, applied inside BGL:Load after Reset (which discards and rebuilds
#!  the filter every call, exactly as it does PROP:Order); ABC's ResetSort
#!  became the BGL:Express reload; the embeds moved to the CW20 names the
#!  search box already proved. The field-mapping groups below are Roberto's
#!  own, renamed - dictionary symbols read the same from either chain.
#!#############################################################################
#!  GROUP - map a dictionary field to one of the class's field types
#!#############################################################################
#!  Picture first, because a date is very often held in a LONG and only the
#!  picture gives it away. Then the storage type.
#GROUP(%bgfTypeOf,%pType,%pPicture,*%pOut),AUTO
  #SET(%pOut,'Flt:String')
  #IF(%pPicture AND LEN(CLIP(%pPicture)) >= 2)
    #IF(UPPER(SLICE(%pPicture,1,2)) = '@D')
      #SET(%pOut,'Flt:Date')
      #RETURN
    #ENDIF
    #IF(UPPER(SLICE(%pPicture,1,2)) = '@T')
      #SET(%pOut,'Flt:Time')
      #RETURN
    #ENDIF
  #ENDIF
  #CASE(UPPER(%pType))
  #OF('DATE')
    #SET(%pOut,'Flt:Date')
  #OF('TIME')
    #SET(%pOut,'Flt:Time')
  #OF('BYTE')
    #SET(%pOut,'Flt:Number')
  #OF('SHORT') #OROF('USHORT') #OROF('LONG') #OROF('ULONG')
  #OROF('SREAL') #OROF('REAL') #OROF('DECIMAL') #OROF('PDECIMAL')
    #SET(%pOut,'Flt:Number')
  #ENDCASE
#!-----------------------------------------------------------------------------
#!  GROUP - the AddField calls. An explicit field list wins; whole files are
#!  the fallback; the procedure's %Primary is the fallback's fallback. #FIND,
#!  not #FIX, for the picked fields - #FIX only looks in the file that happens
#!  to be fixed, and silently dropped every field from any other file.
#GROUP(%bgfAddFields,%pObject,%pFile,%pFile2,%pFile3)
  #DECLARE(%bgfType)
  #DECLARE(%bgfLabel)
  #DECLARE(%bgfAny,LONG)
  #SET(%bgfAny,0)
  #FOR(%bgfPicked)
    #FIND(%Field,%bgfPickField)
    #IF(%Field)
      #CALL(%bgfEmitPicked,%pObject)
    #ENDIF
  #ENDFOR
  #IF(%bgfAny)
    #RETURN
  #ENDIF
  #IF(%pFile)
    #FIX(%File,%pFile)
    #FOR(%Field)
      #CALL(%bgfEmitField,%pObject)
    #ENDFOR
  #ENDIF
  #IF(%pFile2)
    #FIX(%File,%pFile2)
    #FOR(%Field)
      #CALL(%bgfEmitField,%pObject)
    #ENDFOR
  #ENDIF
  #IF(%pFile3)
    #FIX(%File,%pFile3)
    #FOR(%Field)
      #CALL(%bgfEmitField,%pObject)
    #ENDFOR
  #ENDIF
  #IF(~%bgfAny AND %Primary)
    #FIX(%File,%Primary)
    #FOR(%Field)
      #CALL(%bgfEmitField,%pObject)
    #ENDFOR
  #ENDIF
  #IF(~%bgfAny)
    ! BrowseGridLegFilter: no fields. The button's "File whose fields to offer"
    ! prompt is [%pFile] and the procedure's primary file is [%Primary] - both
    ! empty, so there was nothing to read. Set the prompt on the Filters button.
  #ENDIF
#!-----------------------------------------------------------------------------
#GROUP(%bgfEmitPicked,%pObject)
  #IF(%bgfPickLabel)
    #SET(%bgfLabel,CLIP(%bgfPickLabel))
  #ELSE
    #SET(%bgfLabel,CLIP(%FieldHeader))
    #IF(~%bgfLabel)
      #SET(%bgfLabel,CLIP(%FieldID))
    #ENDIF
  #ENDIF
  #IF(INSTRING('''',%bgfLabel,1,1))
    #SET(%bgfLabel,CLIP(%FieldID))
  #ENDIF
  #CALL(%bgfTypeOf,%FieldType,%FieldPicture,%bgfType)
  #SET(%bgfAny,1)
  %pObject.AddField('%Field','%bgfLabel',%bgfType,'%FieldPicture')
#!-----------------------------------------------------------------------------
#GROUP(%bgfEmitField,%pObject)
  #IF(UPPER(%FieldType) = 'GROUP' OR UPPER(%FieldType) = 'END' OR UPPER(%FieldType) = 'MEMO' OR UPPER(%FieldType) = 'BLOB')
    #RETURN
  #ENDIF
  #SET(%bgfLabel,CLIP(%FieldHeader))
  #IF(~%bgfLabel)
    #SET(%bgfLabel,CLIP(%FieldDescription))
  #ENDIF
  #IF(~%bgfLabel)
    #SET(%bgfLabel,CLIP(%FieldID))
  #ENDIF
  #IF(INSTRING('''',%bgfLabel,1,1))
    #SET(%bgfLabel,CLIP(%FieldID))
  #ENDIF
  #CALL(%bgfTypeOf,%FieldType,%FieldPicture,%bgfType)
  #SET(%bgfAny,1)
  %pObject.AddField('%Field','%bgfLabel',%bgfType,'%FieldPicture')
#!#############################################################################
#!  CONTROL TEMPLATE - BrowseGridLegFilter - the Filters button for a grid
#!#############################################################################
#CONTROL(BrowseGridLegFilter,'BrowseGrid Legacy - criteria filter bar for a grid'),MULTI,WINDOW,REQ(BrowseGridLegGlobal),DESCRIPTION('Filter bar on ' & %bfConnect)
  CONTROLS
    BUTTON('Filter - click here to filter this list'),AT(,,264,12),USE(?BGLFilters),LEFT,SKIP,TIP('Build a filter for this list'),#REQ
  END
#SHEET
  #TAB('&Filter')
    #BOXED('Which grid')
      #PROMPT('&Object name:',@s64),%bfObject,REQ,DEFAULT('Flt' & %ActiveTemplateInstance)
      #PROMPT('&Grid object this button filters:',@s64),%bfConnect,REQ,DEFAULT('Grid1')
      #DISPLAY('The Object name from the BrowseGridLeg extension on this same')
      #DISPLAY('procedure. A wrong name fails at compile time, complaining')
      #DISPLAY('about BGL:Express.')
    #ENDBOXED
    #BOXED('Fields to offer')
      #PROMPT('&File whose fields to offer:',FILE),%bfFile
      #PROMPT('Also offer fields from:',FILE),%bfFile2
      #PROMPT('...and from:',FILE),%bfFile3
      #DISPLAY('Blank = the procedure''s primary file. Every field of the named')
      #DISPLAY('files is offered, displayed or not - BINDABLE covers the whole')
      #DISPLAY('record either way.')
      #BUTTON('Offer exactly &these fields'),MULTI(%bgfPicked,%bgfPickField & '  ' & %bgfPickLabel),INLINE
        #PROMPT('&Field:',FIELD),%bgfPickField,REQ
        #PROMPT('&Label (blank = the dictionary heading):',@s40),%bgfPickLabel
      #ENDBUTTON
    #ENDBOXED
  #ENDTAB
  #TAB('&Options')
    #BOXED('Searching')
      #PROMPT('&Case sensitive text compares',CHECK),%bfCase,DEFAULT(0),AT(10)
      #DISPLAY('Off (the normal choice) wraps text compares in UPPER(), so')
      #DISPLAY('smith finds Smith and SMITH.')
    #ENDBOXED
    #BOXED('The window and the button')
      #PROMPT('&Window title (blank = "Filters"):',@s64),%bfTitle,DEFAULT('')
      #DISPLAY('The button is the whole filter UI: stretch it the width of the')
      #DISPLAY('grid. At rest it invites; filtered, its caption reads the')
      #DISPLAY('filter back ("Filter - Name contains mo") and a click offers')
      #DISPLAY('Clear, New filter and the saved filters in one menu.')
    #ENDBOXED
    #BOXED('Saved filters')
      #PROMPT('&Profile name (blank = this procedure):',@s64),%bfProfile,DEFAULT('')
      #PROMPT('&INI file (blank = the application''s own):',@s128),%bfIni,DEFAULT('')
      #DISPLAY('Saved filters are grouped under the profile, in the INI.')
    #ENDBOXED
  #ENDTAB
#ENDSHEET
#ATSTART
#DECLARE(%bfBtn)
#FOR(%Control),WHERE(%ControlInstance = %ActiveTemplateInstance)
  #IF(%ControlType = 'BUTTON')
    #SET(%bfBtn,%Control)
  #ENDIF
#ENDFOR
#ENDAT
#!
#AT(%DataSection)
%bfObject            MyFilterClass                            ! criteria filters for %bfConnect
BGFN%ActiveTemplateInstance FilterNameQueue                   ! saved-filter names, for the button's menu
BGFM%ActiveTemplateInstance CSTRING(2049)                     ! the menu string
BGFC%ActiveTemplateInstance LONG                              ! what the menu answered
BGFI%ActiveTemplateInstance LONG                              ! loop counter for the build
BGFA%ActiveTemplateInstance BYTE                              ! something changed - apply and show it
BGFB%ActiveTemplateInstance BYTE                              ! 1 = Clear leads the menu, shifting the rest
#ENDAT
#!
#AT(%AfterWindowOpening),WHERE(%bfBtn)
!  Tell the grid which button this is, so an insert - which clears every
!  narrowing to keep the new record visible - can put the caption to rest too.
  %bfConnect:FBtn = %bfBtn
#ENDAT
#!
#AT(%AcceptLoopBeforeFieldHandling),WHERE(%bfBtn)
  IF FIELD() = %bfBtn AND EVENT() = EVENT:Accepted
!  The field list is built on the first press rather than at window open, so
!  the button costs nothing on a window where nobody filters.
    IF ~%bfObject.FieldCount()
#INSERT(%bgfAddFields,%bfObject,%bfFile,%bfFile2,%bfFile3)
    END
#IF(%bfTitle)
    %bfObject.Title         = '%bfTitle'
#ENDIF
    %bfObject.CaseSensitive = %bfCase
#IF(%bfProfile)
    %bfObject.Profile       = '%bfProfile'
#ELSE
    %bfObject.Profile       = '%Procedure'
#ENDIF
#IF(%bfIni)
    %bfObject.IniFile       = '%bfIni'
#ENDIF
!  THE BUTTON IS THE WHOLE FILTER UI. At rest it invites; filtered it says
!  what the list is narrowed to and offers the ways out. A click never acts
!  directly - it always answers with a menu when there is anything to choose,
!  so a stray click on a full-width button cannot throw a filter away:
!      filter on:            Clear | New filter... | ----- | saved names
!      filter off, saved:            New filter... | ----- | saved names
!      filter off, nothing:  straight to the form - nothing to choose from
!  Picking a saved name loads and applies it in one click, so switching from
!  one saved filter to another never goes through Clear. The dash row is a
!  DISABLED item rather than a POPUP separator on purpose: a disabled item
!  consumes an index deterministically, so with base = 1 when Clear leads,
!  the saved name at menu position n is always list entry n - base - 2 -
!  where a separator's counting behaviour would have been an experiment. If
!  graying is ever not honoured, the dashes land in a dead index and nothing
!  happens.
    BGFA%ActiveTemplateInstance = 0
    BGFB%ActiveTemplateInstance = CHOOSE(%bfObject.CondCount() > 0,1,0)
    FREE(BGFN%ActiveTemplateInstance)
    %bfObject.SavedNames(BGFN%ActiveTemplateInstance)
    IF RECORDS(BGFN%ActiveTemplateInstance) OR BGFB%ActiveTemplateInstance
      IF BGFB%ActiveTemplateInstance
        BGFM%ActiveTemplateInstance = 'Clear|New filter...'
      ELSE
        BGFM%ActiveTemplateInstance = 'New filter...'
      END
      IF RECORDS(BGFN%ActiveTemplateInstance)
        BGFM%ActiveTemplateInstance = BGFM%ActiveTemplateInstance & '|~-----'
        LOOP BGFI%ActiveTemplateInstance = 1 TO RECORDS(BGFN%ActiveTemplateInstance)
          GET(BGFN%ActiveTemplateInstance,BGFI%ActiveTemplateInstance)
          BGFM%ActiveTemplateInstance = BGFM%ActiveTemplateInstance & '|' & CLIP(BGFN%ActiveTemplateInstance.FNName)
        END
      END
      BGFC%ActiveTemplateInstance = POPUP(BGFM%ActiveTemplateInstance)
      IF BGFB%ActiveTemplateInstance AND BGFC%ActiveTemplateInstance = 1
!  Clear - conditions and all, so the form reopens empty rather than
!  remembering what was just thrown away.
        %bfObject.ClearConds()
        BGFA%ActiveTemplateInstance = 1
      ELSIF BGFC%ActiveTemplateInstance = BGFB%ActiveTemplateInstance + 1
        IF %bfObject.Ask() THEN BGFA%ActiveTemplateInstance = 1.
      ELSIF BGFC%ActiveTemplateInstance > BGFB%ActiveTemplateInstance + 2
        GET(BGFN%ActiveTemplateInstance,BGFC%ActiveTemplateInstance - BGFB%ActiveTemplateInstance - 2)
        IF ~ERRORCODE()
          IF %bfObject.Load(BGFN%ActiveTemplateInstance.FNName) THEN BGFA%ActiveTemplateInstance = 1.
        END
      END
    ELSE
      IF %bfObject.Ask() THEN BGFA%ActiveTemplateInstance = 1.
    END
    IF BGFA%ActiveTemplateInstance
!  Apply whatever came back - built, loaded, or nothing at all from Clear -
!  and say so on the button itself: the caption IS the filter display now.
!  The tip carries the full sentence for when the button is narrower than it.
!  The rest caption here, the one in the grid's insert path, and the CONTROLS
!  declaration say the same words on purpose - change one, change all three.
      %bfConnect:Expr = %bfObject.Expression()
      DO BGL:Express:%bfConnect
      IF %bfObject.CondCount()
        %bfBtn{PROP:Text} = 'Filter - ' & CLIP(%bfObject.Summary()) & '  (click to change or clear)'
        %bfBtn{PROP:Tip}  = %bfObject.Summary()
      ELSE
        %bfBtn{PROP:Text} = 'Filter - click here to filter this list'
        %bfBtn{PROP:Tip}  = 'Build a filter for this list'
      END
    END
  END
#ENDAT
