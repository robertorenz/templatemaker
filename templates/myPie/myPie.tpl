#TEMPLATE(myPie,'myPie - Draw a Pie Chart into a Window - v1.0'),FAMILY('ABC')
#!-----------------------------------------------------------------------------
#!  myPie template set
#!
#!  myPieGlobal  (APPLICATION extension) - adds a global helper procedure
#!               myPieDraw() to the program module that wraps the SETTARGET +
#!               PIE drawing into a single call. Add once, at the global level.
#!
#!  myPie        (PROCEDURE extension)    - dropped on a window procedure; builds
#!               the slice/color arrays at OpenWindow and calls the helper to
#!               render the pie into a chosen IMAGE control.
#!
#!  Self-contained: no external .inc/.clw. The helper is defined directly in the
#!  program module and prototyped (short form) in the global map - the proven
#!  single-file pattern (see anytext.tpl: AnyTextFreeCache).
#!
#!  VERIFIED corpus facts (cited inline below):
#!    PIE(...)       builtins.clw:1402  - slices=relative sizes, colors per slice
#!    SETTARGET(...) builtins.clw:1791  - band = IMAGE control field-equate
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
      #DISPLAY('Version 1.0')
      #DISPLAY('Adds the myPieDraw() helper to the program module.')
      #DISPLAY('Add this extension once, at the Application (global) level.')
    #ENDBOXED
    #BOXED('Options')
      #PROMPT('&Disable this template',CHECK),%myPieDisable,DEFAULT(0),AT(10)
    #ENDBOXED
  #ENDTAB
  #TAB('&About')
    #BOXED('About')
      #DISPLAY('myPieDraw(SIGNED pImageFeq, *SIGNED[] pSlices,')
      #DISPLAY('          *LONG[] pColors, SIGNED pDepth=0)')
      #DISPLAY('')
      #DISPLAY('Targets the given IMAGE control, draws a PIE filling the')
      #DISPLAY('control, then restores the previous draw target.')
    #ENDBOXED
  #ENDTAB
#ENDSHEET
#!-----------------------------------------------------------------------------
#! Short-form prototype in the global map. MAP embeds auto-indent emitted lines,
#! so a long-form "Label PROCEDURE(...)" would break (label must be in column 1).
#! The short form has no column requirement and survives indenting.
#! Proof: anytext.tpl:207 emits "AnyTextFreeCache()" into %GlobalMap.
#! The default (=0) makes pDepth omittable at the call site.
#!-----------------------------------------------------------------------------
#AT(%GlobalMap),WHERE(%myPieDisable=0)
myPieDraw(SIGNED pImageFeq,*SIGNED[] pSlices,*LONG[] pColors,SIGNED pDepth=0)
#ENDAT
#!-----------------------------------------------------------------------------
#! The helper body, emitted into the program module. %ProgramProcedures is a
#! DATA region and is NOT auto-indented, so write it long-form: label in column
#! 1, CODE and statements indented. The =0 default is kept in the body header
#! too (matches the short prototype - proven safe in myFuncs).
#! Proof of the long-form body pattern: anytext.tpl:198.
#!
#! Note: %ProgramProcedures is EXE-only. For a multi-DLL build the helper body
#! must live in (and be exported from) the shared/root target; this single-file
#! EXE pattern intentionally targets stand-alone executables.
#!-----------------------------------------------------------------------------
#AT(%ProgramProcedures),WHERE(%myPieDisable=0)
myPieDraw  PROCEDURE(SIGNED pImageFeq,*SIGNED[] pSlices,*LONG[] pColors,SIGNED pDepth=0)
  CODE
  SETTARGET(,pImageFeq)                                       ! draw into the IMAGE control
  PIE(0,0,pImageFeq{PROP:Width},pImageFeq{PROP:Height},pSlices,pColors,pDepth)
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
#! Local DIM'd arrays, sized at GENERATION TIME from the segment count.
#! %(expr) emits a computed value into an output line; ITEMS(%multi) is the
#! gen-time row count. Proof: StCMRI.tpw:743 RANGE(0,%(ITEMS(%FileToCheck))).
#! Only emit when there is at least one segment AND an image was chosen.
#!-----------------------------------------------------------------------------
#AT(%DataSection),WHERE(%myPieDisableThis=0 AND ITEMS(%myPieSeg) AND %myPieImage)
myPie:Slices         SIGNED,DIM(%(ITEMS(%myPieSeg)))         ! relative slice sizes
myPie:Colors         LONG,DIM(%(ITEMS(%myPieSeg)))           ! one fill color per slice
#ENDAT
#!-----------------------------------------------------------------------------
#! Self-contained handler injected at the TOP of TakeWindowEvent (PRIORITY 2000,
#! low = runs early). It never RETURNs, so it does not short the method. On
#! EVENT:OpenWindow it fills the arrays (one literal line per segment,
#! INSTANCE() = the 1-based row index) and calls the helper.
#!
#! %myPieImage is a CONTROL prompt and ALREADY yields the '?'-prefixed equate
#! (e.g. ?PieImage). Proof: ABCONTRL.TPW:208 emits DISPLAY(%UpdateFeq) ->
#! DISPLAY(?Ctrl). So pass %myPieImage straight through - do NOT add a '?'.
#!-----------------------------------------------------------------------------
#AT(%WindowManagerMethodCodeSection,'TakeWindowEvent','(),BYTE'),PRIORITY(2000),WHERE(%myPieDisableThis=0 AND ITEMS(%myPieSeg) AND %myPieImage)
  CASE EVENT()
  OF EVENT:OpenWindow
    #FOR(%myPieSeg)
    myPie:Slices[%(INSTANCE(%myPieSeg))] = %myPieSegValue                 ! %myPieSegLabel
    myPie:Colors[%(INSTANCE(%myPieSeg))] = %myPieSegColor
    #ENDFOR
    myPieDraw(%myPieImage,myPie:Slices,myPie:Colors,%myPieDepth)
  END
#ENDAT
#!-----------------------------------------------------------------------------
#! End of myPie template set
#!-----------------------------------------------------------------------------
