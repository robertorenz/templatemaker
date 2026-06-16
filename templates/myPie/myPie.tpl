#TEMPLATE(myPie,'myPie - Draw a Pie Chart into a Window - v1.2'),FAMILY('ABC')
#!-----------------------------------------------------------------------------
#!  myPie template set
#!
#!  myPieGlobal  (APPLICATION extension) - adds the global helper myPieDraw():
#!               targets an IMAGE control, clears it, and draws the PIE into a
#!               given area. One call, reusable from anywhere.
#!
#!  myPie        (PROCEDURE extension)    - dropped on a window procedure. Builds
#!               the slice/color arrays, draws the pie via the helper, and draws
#!               a legend (color swatch + label + percentage) beside it. Redraws
#!               on OpenWindow and on resize. Exposes a myPieRepaint ROUTINE so
#!               you can change the slice values at run time and repaint.
#!
#!  Self-contained: no external .inc/.clw.
#!
#!  VERIFIED corpus facts:
#!    PIE(x,y,w,h,*SIGNED[] slices,*LONG[] colors,depth,...)  builtins.clw:1402
#!    BOX(x,y,w,h,fill)                                       builtins.clw:467
#!    SHOW(x,y,str)  - draw text, dialog units                builtins.clw:1820
#!    SETTARGET(window,?image) - band = IMAGE control         builtins.clw:1791
#!    SETPENCOLOR(color)                                      builtins.clw:1764
#!-----------------------------------------------------------------------------
#!#############################################################################
#!  GLOBAL EXTENSION - myPieGlobal
#!#############################################################################
#EXTENSION(myPieGlobal,'myPie - Global Helper (add once per application)'),APPLICATION
#SHEET
  #TAB('&General')
    #BOXED('myPie')
      #DISPLAY('myPie Global Helper - Version 1.2')
      #DISPLAY('Adds the myPieDraw() helper to the program module.')
      #DISPLAY('Add this extension once, at the Application (global) level.')
    #ENDBOXED
    #BOXED('Options')
      #PROMPT('&Disable this template',CHECK),%myPieDisable,DEFAULT(0),AT(10)
    #ENDBOXED
  #ENDTAB
#ENDSHEET
#!-----------------------------------------------------------------------------
#! Short-form prototype in the global map (survives the auto-indent that long
#! form would not - anytext.tpl:207).
#!-----------------------------------------------------------------------------
#AT(%GlobalMap),WHERE(%myPieDisable=0)
myPieDraw(SIGNED pImageFeq,*SIGNED[] pSlices,*LONG[] pColors,SIGNED pPieW,SIGNED pPieH,SIGNED pDepth=0,LONG pBackColor=COLOR:White)
#ENDAT
#!-----------------------------------------------------------------------------
#! Helper body in the program module (%ProgramProcedures is NOT auto-indented,
#! so long form, label in column 1). Clears the whole control, then draws the
#! pie into the pPieW x pPieH area at the top-left. Re-reads the control size on
#! every call, so it is correct on open and after a resize. EXE-only region; for
#! multi-DLL move the body to the shared/root target.
#!-----------------------------------------------------------------------------
#AT(%ProgramProcedures),WHERE(%myPieDisable=0)
myPieDraw  PROCEDURE(SIGNED pImageFeq,*SIGNED[] pSlices,*LONG[] pColors,SIGNED pPieW,SIGNED pPieH,SIGNED pDepth=0,LONG pBackColor=COLOR:White)
  CODE
  SETTARGET(,pImageFeq)                                       ! draw into the IMAGE control
  SETPENCOLOR(pBackColor)                                     ! erase the old drawing (graphics persist)
  BOX(0,0,pImageFeq{PROP:Width},pImageFeq{PROP:Height},pBackColor)
  SETPENCOLOR(COLOR:Black)                                    ! slice outlines
  PIE(0,0,pPieW,pPieH,pSlices,pColors,pDepth)                 ! the pie itself
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
      #PROMPT('Show &legend',CHECK),%myPieShowLegend,DEFAULT(1),AT(10)
      #PROMPT('Show &percentages in legend',CHECK),%myPieShowPct,DEFAULT(1),AT(10)
    #ENDBOXED
  #ENDTAB
  #TAB('&Segments')
    #DISPLAY('Define each pie slice. Value is the RELATIVE size of the slice.')
    #BUTTON('Pie Segments'),MULTI(%myPieSeg,%myPieSegLabel & ' = ' & %myPieSegValue),INLINE
      #PROMPT('&Label:',@s30),%myPieSegLabel
      #PROMPT('&Value (relative size):',SPIN(@n7,1,1000000,1)),%myPieSegValue,DEFAULT(1),REQ
      #PROMPT('&Color:',COLOR),%myPieSegColor,DEFAULT(0008000H)
    #ENDBUTTON
  #ENDTAB
  #TAB('&Runtime')
    #BOXED('Changing the data at run time')
      #DISPLAY('Change a slice value then repaint, e.g.:')
      #DISPLAY('   myPie:Slices[2] = 75')
      #DISPLAY('   DO myPieRepaint')
      #DISPLAY('Percentages and the pie update automatically.')
    #ENDBOXED
  #ENDTAB
#ENDSHEET
#!-----------------------------------------------------------------------------
#! Local data. Arrays DIM'd at GEN TIME from the segment count (%(ITEMS(...))).
#! Only emit when there is at least one segment AND an image was chosen.
#!-----------------------------------------------------------------------------
#AT(%DataSection),WHERE(%myPieDisableThis=0 AND ITEMS(%myPieSeg) AND %myPieImage)
myPie:Redraw         EQUATE(EVENT:User+101)                  ! private "repaint" event
myPie:Slices         SIGNED,DIM(%(ITEMS(%myPieSeg)))         ! relative slice sizes (change at run time + DO myPieRepaint)
myPie:Colors         LONG,DIM(%(ITEMS(%myPieSeg)))           ! one fill color per slice
myPie:Total          LONG                                    ! sum of slices (for percentages)
myPie:W              SIGNED                                  ! current image width
myPie:H              SIGNED                                  ! current image height
myPie:PieDim         SIGNED                                  ! pie diameter
myPie:LegX           SIGNED                                  ! legend left
myPie:LegY           SIGNED                                  ! legend row y
myPie:Pct            SIGNED                                  ! a slice percentage
#ENDAT
#!-----------------------------------------------------------------------------
#! Repaint ROUTINE - call "DO myPieRepaint" after changing myPie:Slices[] to
#! redraw. It just POSTs the private event so the draw happens cleanly in the
#! event loop.
#!-----------------------------------------------------------------------------
#AT(%ProcedureRoutines),WHERE(%myPieDisableThis=0 AND ITEMS(%myPieSeg) AND %myPieImage)
myPieRepaint ROUTINE
  POST(myPie:Redraw)
#ENDAT
#!-----------------------------------------------------------------------------
#! Self-contained handler at the TOP of TakeWindowEvent (PRIORITY 2000, never
#! RETURNs). Drawing is driven by a POSTED event so it runs AFTER the window has
#! opened / the ABC resizer has resized the IMAGE control (reading PROP:Width at
#! the top of the method would otherwise be the OLD size). The pie fills the left
#! 55%% when a legend is shown, else the whole control. The legend is drawn here
#! because the labels are known at generation time; percentages are computed at
#! run time from the live slice values.
#!
#! %myPieImage is a CONTROL prompt and already yields the '?'-prefixed equate
#! (ABCONTRL.TPW:208) - pass it straight through.
#!-----------------------------------------------------------------------------
#AT(%WindowManagerMethodCodeSection,'TakeWindowEvent','(),BYTE'),PRIORITY(2000),WHERE(%myPieDisableThis=0 AND ITEMS(%myPieSeg) AND %myPieImage)
  CASE EVENT()
  OF EVENT:OpenWindow
    #FOR(%myPieSeg)
    myPie:Slices[%(INSTANCE(%myPieSeg))] = %myPieSegValue                 ! %myPieSegLabel
    myPie:Colors[%(INSTANCE(%myPieSeg))] = %myPieSegColor
    #ENDFOR
    POST(myPie:Redraw)                                        ! first draw, after the window opens
  OF EVENT:Sized
    POST(myPie:Redraw)                                        ! redraw after the resize settles
  OF myPie:Redraw
    myPie:W = %myPieImage{PROP:Width}
    myPie:H = %myPieImage{PROP:Height}
    #IF(%myPieShowLegend)
    myPie:PieDim = myPie:W * 55 / 100                         ! pie gets left 55pct, legend the rest
    #ELSE
    myPie:PieDim = myPie:W
    #ENDIF
    IF myPie:H < myPie:PieDim THEN myPie:PieDim = myPie:H.    ! keep the pie square / on-screen
    myPieDraw(%myPieImage,myPie:Slices,myPie:Colors,myPie:PieDim,myPie:PieDim,%myPieDepth,%myPieBackColor)
    #IF(%myPieShowLegend)
    myPie:Total = 0
    #FOR(%myPieSeg)
    myPie:Total = myPie:Total + myPie:Slices[%(INSTANCE(%myPieSeg))]
    #ENDFOR
    SETTARGET(,%myPieImage)                                   ! add the legend to the same image
    myPie:LegX = myPie:PieDim + 8
    myPie:LegY = 6
    #FOR(%myPieSeg)
    SETPENCOLOR(%myPieSegColor)
    BOX(myPie:LegX,myPie:LegY,9,8,%myPieSegColor)             ! color swatch
    SETPENCOLOR(COLOR:Black)
    #IF(%myPieShowPct)
    IF myPie:Total
    myPie:Pct = INT(myPie:Slices[%(INSTANCE(%myPieSeg))] * 100 / myPie:Total + 0.5)
    ELSE
    myPie:Pct = 0
    END
    SHOW(myPie:LegX + 14,myPie:LegY,'%myPieSegLabel = ' & myPie:Pct & '%%')
    #ELSE
    SHOW(myPie:LegX + 14,myPie:LegY,'%myPieSegLabel')
    #ENDIF
    myPie:LegY = myPie:LegY + 13
    #ENDFOR
    SETTARGET()
    #ENDIF
  END
#ENDAT
#!-----------------------------------------------------------------------------
#! End of myPie template set
#!-----------------------------------------------------------------------------
