#TEMPLATE(myPie,'myPie - Draw a Pie Chart into a Window - v1.1'),FAMILY('ABC')
#!-----------------------------------------------------------------------------
#!  myPie template set
#!
#!  myPieGlobal  (APPLICATION extension) - adds a global helper procedure
#!               myPieDraw() to the program module that clears the IMAGE control
#!               and draws the PIE into it, in a single call.
#!
#!  myPie        (PROCEDURE extension)    - dropped on a window procedure; builds
#!               the slice/color arrays and (re)draws the pie into a chosen IMAGE
#!               control on OpenWindow AND whenever the window is resized.
#!
#!  Self-contained: no external .inc/.clw. The helper is defined directly in the
#!  program module and prototyped (short form) in the global map - the proven
#!  single-file pattern (see anytext.tpl: AnyTextFreeCache).
#!
#!  VERIFIED corpus facts (cited inline below):
#!    PIE(...)        builtins.clw:1402  - slices=relative sizes, colors per slice
#!    BOX(...)        builtins.clw:467   - filled rectangle (used to clear)
#!    SETTARGET(...)  builtins.clw:1791  - band = IMAGE control field-equate
#!    SETPENCOLOR(..) builtins.clw:1764
#!    svgraph.clw:2548 draws into a control via settarget(window, locField)
#!-----------------------------------------------------------------------------
#!#############################################################################
#!  GLOBAL EXTENSION - myPieGlobal
#!#############################################################################
#EXTENSION(myPieGlobal,'myPie - Global Helper (add once per application)'),APPLICATION
#SHEET
  #TAB('&General')
    #BOXED('myPie')
      #DISPLAY('myPie Global Helper')
      #DISPLAY('Version 1.1')
      #DISPLAY('Adds the myPieDraw() helper to the program module.')
      #DISPLAY('Add this extension once, at the Application (global) level.')
    #ENDBOXED
    #BOXED('Options')
      #PROMPT('&Disable this template',CHECK),%myPieDisable,DEFAULT(0),AT(10)
    #ENDBOXED
  #ENDTAB
  #TAB('&About')
    #BOXED('About')
      #DISPLAY('myPieDraw(SIGNED pImageFeq, *SIGNED[] pSlices, *LONG[] pColors,')
      #DISPLAY('          SIGNED pDepth=0, LONG pBackColor=COLOR:White)')
      #DISPLAY('')
      #DISPLAY('Targets the IMAGE control, clears it with pBackColor, draws a')
      #DISPLAY('PIE filling the control, then restores the previous draw target.')
      #DISPLAY('Re-reads the control size on every call, so it fits after a resize.')
    #ENDBOXED
  #ENDTAB
#ENDSHEET
#!-----------------------------------------------------------------------------
#! Short-form prototype in the global map. MAP embeds auto-indent emitted lines,
#! so a long-form "Label PROCEDURE(...)" would break (label must be in column 1).
#! The short form has no column requirement and survives indenting.
#! Proof: anytext.tpl:207 emits "AnyTextFreeCache()" into %GlobalMap.
#!-----------------------------------------------------------------------------
#AT(%GlobalMap),WHERE(%myPieDisable=0)
myPieDraw(SIGNED pImageFeq,*SIGNED[] pSlices,*LONG[] pColors,SIGNED pDepth=0,LONG pBackColor=COLOR:White)
#ENDAT
#!-----------------------------------------------------------------------------
#! The helper body, in the program module. %ProgramProcedures is a DATA region
#! and is NOT auto-indented, so write it long-form: label in column 1, CODE and
#! statements indented. It re-reads PROP:Width/Height each call, clears the old
#! drawing (a filled BOX - image graphics persist, so we must erase first), then
#! draws the pie. That makes the SAME call correct on open and after a resize.
#!
#! Note: %ProgramProcedures is EXE-only. For a multi-DLL build the helper body
#! must live in (and be exported from) the shared/root target.
#!-----------------------------------------------------------------------------
#AT(%ProgramProcedures),WHERE(%myPieDisable=0)
myPieDraw  PROCEDURE(SIGNED pImageFeq,*SIGNED[] pSlices,*LONG[] pColors,SIGNED pDepth=0,LONG pBackColor=COLOR:White)
loc:W  SIGNED
loc:H  SIGNED
  CODE
  SETTARGET(,pImageFeq)                                       ! draw into the IMAGE control
  loc:W = pImageFeq{PROP:Width}                               ! current control size (changes on resize)
  loc:H = pImageFeq{PROP:Height}
  SETPENCOLOR(pBackColor)                                     ! erase: fill the whole control with the
  BOX(0,0,loc:W,loc:H,pBackColor)                             !   background (image graphics persist)
  SETPENCOLOR(COLOR:Black)                                    ! slice outlines
  PIE(0,0,loc:W,loc:H,pSlices,pColors,pDepth)                 ! draw the pie filling the control
  SETTARGET()                                                 ! restore previous target
#ENDAT
#!#############################################################################
#!  PROCEDURE EXTENSION - myPie
#!#############################################################################
#EXTENSION(myPie,'myPie - Draw a Pie Chart on this window'),PROCEDURE,REQ(myPieGlobal)
#SHEET
  #TAB('&General')
    #BOXED('Options')
      #PROMPT('&Disable this template',CHECK),%myPieDisableThis,DEFAULT(0),AT(10)
      #PROMPT('&Image control to draw into:',CONTROL),%myPieImage,REQ
      #PROMPT('3D &Depth (0 = flat):',SPIN(@n3,0,60,1)),%myPieDepth,DEFAULT(0)
      #PROMPT('&Background color:',COLOR),%myPieBackColor,DEFAULT(0FFFFFFH)
    #ENDBOXED
  #ENDTAB
  #TAB('&Segments')
    #DISPLAY('Define each pie slice. Value is the RELATIVE size of the slice.')
    #DISPLAY('(The sum of all values is treated as 100 percent.)')
    #BUTTON('Pie Segments'),MULTI(%myPieSeg,%myPieSegLabel & ' = ' & %myPieSegValue),INLINE
      #PROMPT('&Label:',@s30),%myPieSegLabel
      #PROMPT('&Value (relative size):',SPIN(@n7,1,1000000,1)),%myPieSegValue,DEFAULT(1),REQ
      #PROMPT('&Color:',COLOR),%myPieSegColor,DEFAULT(0008000H)
    #ENDBUTTON
  #ENDTAB
#ENDSHEET
#!-----------------------------------------------------------------------------
#! Local data: a private redraw event, plus the slice/color arrays DIM'd at
#! GENERATION TIME from the segment count. %(expr) emits a computed value;
#! ITEMS(%multi) is the gen-time row count (StCMRI.tpw:743).
#! Only emit when there is at least one segment AND an image was chosen.
#!-----------------------------------------------------------------------------
#AT(%DataSection),WHERE(%myPieDisableThis=0 AND ITEMS(%myPieSeg) AND %myPieImage)
myPie:Redraw         EQUATE(EVENT:User+101)                  ! private "redraw the pie" event
myPie:Slices         SIGNED,DIM(%(ITEMS(%myPieSeg)))         ! relative slice sizes
myPie:Colors         LONG,DIM(%(ITEMS(%myPieSeg)))           ! one fill color per slice
#ENDAT
#!-----------------------------------------------------------------------------
#! Self-contained handler at the TOP of TakeWindowEvent (PRIORITY 2000). It never
#! RETURNs. Drawing is driven by a POSTED private event (myPie:Redraw) so it runs
#! AFTER the window has finished opening / the ABC resizer has finished moving the
#! IMAGE control - otherwise PROP:Width would still be the old size. We POST on
#! OpenWindow (initial draw) and on Sized (resize), and do the actual draw when
#! the posted event comes back. The arrays are filled once, on OpenWindow.
#!
#! %myPieImage is a CONTROL prompt and ALREADY yields the '?'-prefixed equate
#! (ABCONTRL.TPW:208). Pass it straight through - do NOT add a '?'.
#!-----------------------------------------------------------------------------
#AT(%WindowManagerMethodCodeSection,'TakeWindowEvent','(),BYTE'),PRIORITY(2000),WHERE(%myPieDisableThis=0 AND ITEMS(%myPieSeg) AND %myPieImage)
  CASE EVENT()
  OF EVENT:OpenWindow
    #FOR(%myPieSeg)
    myPie:Slices[%(INSTANCE(%myPieSeg))] = %myPieSegValue                 ! %myPieSegLabel
    myPie:Colors[%(INSTANCE(%myPieSeg))] = %myPieSegColor
    #ENDFOR
    POST(myPie:Redraw)                                        ! draw after the window finishes opening
  OF EVENT:Sized
    POST(myPie:Redraw)                                        ! redraw after the resize settles
  OF myPie:Redraw
    myPieDraw(%myPieImage,myPie:Slices,myPie:Colors,%myPieDepth,%myPieBackColor)
  END
#ENDAT
#!-----------------------------------------------------------------------------
#! End of myPie template set
#!-----------------------------------------------------------------------------
