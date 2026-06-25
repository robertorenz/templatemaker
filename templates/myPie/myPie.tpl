#TEMPLATE(myPie,'myPie - Draw a Pie Chart into a Window - v1.3'),FAMILY('ABC')
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
#!  myPieControl (CONTROL template)       - drag a ready-made pie onto a window:
#!               it drops the IMAGE *and* wires the pie + legend in one go,
#!               fully self-contained (no global/procedure extension needed).
#!
#!  Self-contained: no external .inc/.clw.
#!
#!  VERIFIED corpus facts:
#!    PIE(x,y,w,h,*SIGNED[] slices,*LONG[] colors,depth,...)  builtins.clw:1402
#!    BOX(x,y,w,h,fill)                                       builtins.clw:467
#!    SHOW(x,y,str)  - draw text, dialog units                builtins.clw:1820
#!    SETTARGET(window,?image) - target the IMAGE control     builtins.clw:1791
#!    SETPENCOLOR(color)                                      builtins.clw:1764
#!
#!  Drawing model (matches myGauge v2.16): SETTARGET(%Window,?image) makes the
#!  IMAGE itself the target, so (0,0) is the image's top-left, the graphics
#!  belong to the control (they survive a WM_PAINT / resize), and BLANK clears
#!  ONLY this image. A window-omitted SETTARGET(,?image) draws on the window
#!  layer instead - its BLANK wipes the whole window (erasing other pies /
#!  controls) and the drawing is lost on the next repaint.
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
myPieDraw(WINDOW pWin,SIGNED pImageFeq,*SIGNED[] pSlices,*LONG[] pColors,SIGNED pPieW,SIGNED pPieH,SIGNED pDepth=0,LONG pBackColor=COLOR:White)
#ENDAT
#!-----------------------------------------------------------------------------
#! Helper body in the program module (%ProgramProcedures is NOT auto-indented,
#! so long form, label in column 1). Clears the whole control, then draws the
#! pie into the pPieW x pPieH area at the top-left. Re-reads the control size on
#! every call, so it is correct on open and after a resize. EXE-only region; for
#! multi-DLL move the body to the shared/root target.
#!-----------------------------------------------------------------------------
#AT(%ProgramProcedures),WHERE(%myPieDisable=0)
myPieDraw  PROCEDURE(WINDOW pWin,SIGNED pImageFeq,*SIGNED[] pSlices,*LONG[] pColors,SIGNED pPieW,SIGNED pPieH,SIGNED pDepth=0,LONG pBackColor=COLOR:White)
Indt  LONG                                                    ! pie inset so it isn't on the box edge
  CODE
  SETTARGET(pWin,pImageFeq)                                   ! the IMAGE is the target: 0,0 = its top-left, the
  BLANK                                                       !   drawing belongs to the image (survives WM_PAINT /
                                                              !   resize), and BLANK clears ONLY this image - a
                                                              !   window-omitted SETTARGET + BLANK wipes the window.
  IF pBackColor <> COLOR:None                                 ! COLOR:None = keep the image's own backdrop
    SETPENCOLOR(pBackColor)                                   ! paint the chosen background
    BOX(0,0,pImageFeq{PROP:Width},pImageFeq{PROP:Height},pBackColor)
  END
  SETPENCOLOR(COLOR:Black)                                    ! slice outlines
  Indt = pPieW * .02                                          ! small inset so the pie clears the box edge
  PIE(Indt,Indt,pPieW-Indt*2,pPieH-Indt*2,pSlices,pColors,pDepth)   ! the pie itself
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
  #TAB('&Instructions')
    #BOXED('How to use myPie')
      #DISPLAY('1. Add an IMAGE control to the window. It must be an Image -')
      #DISPLAY('   Clarion draws the chart into an Image control; a Region')
      #DISPLAY('   will not receive the drawing.')
      #DISPLAY('2. Size and move the Image control wherever you want it.')
      #DISPLAY('3. On the General tab, select that control in the')
      #DISPLAY('   "Image control to draw into" prompt.')
      #DISPLAY('4. Set the Background color, the 3D Depth, and the')
      #DISPLAY('   "Show legend" / "Show percentages" options.')
      #DISPLAY('5. On the Segments tab, add one slice per segment and give')
      #DISPLAY('   each a Label, a Value (relative size) and a Color.')
      #DISPLAY('   Add as many segments as you want.')
      #DISPLAY('6. For a resizable window, set the Image control to resize or')
      #DISPLAY('   anchor (window resizer) so the chart follows the window.')
      #DISPLAY('7. Generate, compile, run, and test.')
      #DISPLAY('')
      #DISPLAY('To change the data at run time, see the Runtime tab.')
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
    myPieDraw(%Window,%myPieImage,myPie:Slices,myPie:Colors,myPie:PieDim,myPie:PieDim,%myPieDepth,%myPieBackColor)
    #IF(%myPieShowLegend)
    myPie:Total = 0
    #FOR(%myPieSeg)
    myPie:Total = myPie:Total + myPie:Slices[%(INSTANCE(%myPieSeg))]
    #ENDFOR
    SETTARGET(%Window,%myPieImage)                            ! add the legend to the same image (0,0 = image corner)
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
#!#############################################################################
#!  CONTROL TEMPLATE - myPieControl  -  drag a ready-made pie chart onto a window
#!#############################################################################
#!  Drops an IMAGE control AND wires the pie + legend in one drag - self-
#!  contained, so NO myPieGlobal / myPie extension is needed. The draw is inlined
#!  per control instance (each pie owns its own data + private redraw event), and
#!  uses the 2-arg SETTARGET(%Window,?image) model so several pies on one window
#!  never erase each other. WINDOW + MULTI = many per window. The control's own
#!  IMAGE feq is captured in %myPieCtlImage via the proven #FOR(%Control),
#!  WHERE(%ControlInstance=%ActiveTemplateInstance) idiom (corpus CONTROL.TPW).
#!#############################################################################
#CONTROL(myPieControl,'myPie - Pie Chart (drag onto a window)'),WINDOW,MULTI,DESCRIPTION('Pie chart ' & %myPieCtlName),HLP('~myPie')
#! the pie canvas - one IMAGE; its feq auto-uniques on multi-drop and is captured below
  CONTROLS
    IMAGE,AT(,,140,120),USE(?Pie)
  END
#SHEET
  #TAB('&General')
    #BOXED('Pie')
      #PROMPT('&Disable this pie',CHECK),%myPieCtlDisable,DEFAULT(0),AT(10)
      #PROMPT('&Name (data prefix):',@s64),%myPieCtlName,REQ,DEFAULT('Pie' & %ActiveTemplateInstance)
    #ENDBOXED
    #BOXED('Look')
      #PROMPT('3D &Depth (0 = flat):',SPIN(@n3,0,60,1)),%myPieCtlDepth,DEFAULT(0)
      #PROMPT('&Background color:',COLOR),%myPieCtlBackColor,DEFAULT(0FFFFFFH)
      #PROMPT('Show &legend',CHECK),%myPieCtlShowLegend,DEFAULT(1),AT(10)
      #PROMPT('Show &percentages in legend',CHECK),%myPieCtlShowPct,DEFAULT(1),AT(10)
    #ENDBOXED
  #ENDTAB
  #TAB('&Segments')
    #DISPLAY('One slice per segment. Value is the RELATIVE size of the slice.')
    #BUTTON('Pie Segments'),MULTI(%myPieCtlSeg,%myPieCtlSegLabel & ' = ' & %myPieCtlSegValue),INLINE
      #PROMPT('&Label:',@s30),%myPieCtlSegLabel
      #PROMPT('&Value (relative size):',SPIN(@n7,1,1000000,1)),%myPieCtlSegValue,DEFAULT(1),REQ
      #PROMPT('&Color:',COLOR),%myPieCtlSegColor,DEFAULT(0008000H)
    #ENDBUTTON
  #ENDTAB
  #TAB('&Instructions')
    #BOXED('How to use myPie - Pie Chart')
      #DISPLAY('Drag this control onto a window - it drops the Image AND wires')
      #DISPLAY('the pie + legend. No global or procedure extension needed.')
      #DISPLAY('Size / move the control wherever you want the chart.')
      #DISPLAY('On the Segments tab, add one slice per segment (Label / Value /')
      #DISPLAY('Color). Drop several of these on one window if you like.')
      #DISPLAY('')
      #DISPLAY('Run time: change a value then repaint, e.g.')
      #DISPLAY('   Pie1:Slices[2] = 75 ;  DO Repaint:Pie1')
    #ENDBOXED
  #ENDTAB
#ENDSHEET
#!-----------------------------------------------------------------------------
#! Capture THIS instance's IMAGE field equate (auto-uniqued by AppGen on drop).
#ATSTART
  #DECLARE(%myPieCtlImage)
  #FOR(%Control),WHERE(%ControlInstance=%ActiveTemplateInstance)
    #SET(%myPieCtlImage,%Control)
  #ENDFOR
#ENDAT
#!-----------------------------------------------------------------------------
#! Per-instance data (DIM'd at gen time from the segment count; prefixed by the
#! Name so several pies on one window never collide). Only emit with >=1 segment.
#!-----------------------------------------------------------------------------
#AT(%DataSection),WHERE(%myPieCtlDisable=0 AND ITEMS(%myPieCtlSeg))
%myPieCtlName:Slices SIGNED,DIM(%(ITEMS(%myPieCtlSeg)))      ! relative slice sizes (change + DO Repaint:<Name>)
%myPieCtlName:Colors LONG,DIM(%(ITEMS(%myPieCtlSeg)))        ! one fill color per slice
%myPieCtlName:Total  LONG                                    ! sum of slices (for percentages)
%myPieCtlName:W      SIGNED                                  ! current image width
%myPieCtlName:H      SIGNED                                  ! current image height
%myPieCtlName:PieDim SIGNED                                  ! pie diameter
%myPieCtlName:Indt   SIGNED                                  ! pie inset
%myPieCtlName:LegX   SIGNED                                  ! legend left
%myPieCtlName:LegY   SIGNED                                  ! legend row y
%myPieCtlName:Pct    SIGNED                                  ! a slice percentage
%myPieCtlName:Depth  SIGNED                                  ! 3D depth      - live-adjustable (see myPiePanel)
%myPieCtlName:ShowLeg BYTE                                   ! show legend   - live-adjustable
%myPieCtlName:ShowPct BYTE                                   ! show percent  - live-adjustable
Redraw:%myPieCtlName EQUATE(EVENT:User+200+%ActiveTemplateInstance) ! private repaint event (unique per pie)
#ENDAT
#!-----------------------------------------------------------------------------
#! Repaint ROUTINE - "DO Repaint:<Name>" after changing the slice values.
#AT(%ProcedureRoutines),WHERE(%myPieCtlDisable=0 AND ITEMS(%myPieCtlSeg))
Repaint:%myPieCtlName ROUTINE
  POST(Redraw:%myPieCtlName)
#ENDAT
#!-----------------------------------------------------------------------------
#! Self-contained handler at the TOP of TakeWindowEvent (PRIORITY 2000). Drawing
#! is POSTed so it runs AFTER the window opens / the resizer settles. The pie
#! fills the left 55%% when a legend is shown, else the whole control.
#!-----------------------------------------------------------------------------
#AT(%WindowManagerMethodCodeSection,'TakeWindowEvent','(),BYTE'),PRIORITY(2000),WHERE(%myPieCtlDisable=0 AND ITEMS(%myPieCtlSeg))
  CASE EVENT()
  OF EVENT:OpenWindow
    %myPieCtlName:Depth   = %myPieCtlDepth                   ! seed the live-adjustable properties from the
    %myPieCtlName:ShowLeg = %myPieCtlShowLegend             !   design-time prompts (a myPiePanel can change
    %myPieCtlName:ShowPct = %myPieCtlShowPct                !   them at run time, then POST Redraw:<Name>)
    #FOR(%myPieCtlSeg)
    %myPieCtlName:Slices[%(INSTANCE(%myPieCtlSeg))] = %myPieCtlSegValue                 ! %myPieCtlSegLabel
    %myPieCtlName:Colors[%(INSTANCE(%myPieCtlSeg))] = %myPieCtlSegColor
    #ENDFOR
    POST(Redraw:%myPieCtlName)                               ! first draw, after the window opens
  OF EVENT:Sized
    POST(Redraw:%myPieCtlName)                               ! redraw after the resize settles
  OF Redraw:%myPieCtlName
    %myPieCtlName:W = %myPieCtlImage{PROP:Width}
    %myPieCtlName:H = %myPieCtlImage{PROP:Height}
    IF %myPieCtlName:ShowLeg
      %myPieCtlName:PieDim = %myPieCtlName:W * 55 / 100       ! pie gets the left 55pct, legend the rest
    ELSE
      %myPieCtlName:PieDim = %myPieCtlName:W
    END
    IF %myPieCtlName:H < %myPieCtlName:PieDim THEN %myPieCtlName:PieDim = %myPieCtlName:H.   ! keep it on-screen
    SETTARGET(%Window,%myPieCtlImage)                        ! the IMAGE is the target: 0,0 = its corner
    BLANK                                                    ! clears ONLY this image (no window-wide wipe)
    IF %myPieCtlBackColor <> COLOR:None
      SETPENCOLOR(%myPieCtlBackColor)
      BOX(0,0,%myPieCtlName:W,%myPieCtlName:H,%myPieCtlBackColor)
    END
    SETPENCOLOR(COLOR:Black)                                 ! slice outlines
    %myPieCtlName:Indt = %myPieCtlName:PieDim * 2 / 100      ! small inset so the pie clears the edge
    PIE(%myPieCtlName:Indt,%myPieCtlName:Indt,%myPieCtlName:PieDim - %myPieCtlName:Indt * 2,%myPieCtlName:PieDim - %myPieCtlName:Indt * 2,%myPieCtlName:Slices,%myPieCtlName:Colors,%myPieCtlName:Depth)
    IF %myPieCtlName:ShowLeg                                  ! legend (runtime-gated so a panel can toggle it)
    %myPieCtlName:Total = 0
    #FOR(%myPieCtlSeg)
    %myPieCtlName:Total = %myPieCtlName:Total + %myPieCtlName:Slices[%(INSTANCE(%myPieCtlSeg))]
    #ENDFOR
    %myPieCtlName:LegX = %myPieCtlName:PieDim + 8
    %myPieCtlName:LegY = 6
    #FOR(%myPieCtlSeg)
    SETPENCOLOR(%myPieCtlSegColor)
    BOX(%myPieCtlName:LegX,%myPieCtlName:LegY,9,8,%myPieCtlSegColor)             ! color swatch
    SETPENCOLOR(COLOR:Black)
    IF %myPieCtlName:ShowPct
    IF %myPieCtlName:Total
    %myPieCtlName:Pct = INT(%myPieCtlName:Slices[%(INSTANCE(%myPieCtlSeg))] * 100 / %myPieCtlName:Total + 0.5)
    ELSE
    %myPieCtlName:Pct = 0
    END
    SHOW(%myPieCtlName:LegX + 14,%myPieCtlName:LegY,'%myPieCtlSegLabel = ' & %myPieCtlName:Pct & '%%')
    ELSE
    SHOW(%myPieCtlName:LegX + 14,%myPieCtlName:LegY,'%myPieCtlSegLabel')
    END
    %myPieCtlName:LegY = %myPieCtlName:LegY + 13
    #ENDFOR
    END                                                      ! end IF ShowLeg
    SETTARGET()
  END
#ENDAT
#!#############################################################################
#!  CONTROL TEMPLATE - myPiePanel  -  a live "control panel" for a pie chart
#!#############################################################################
#!  Drops a small panel of inputs (a 3D-depth spinner, show-legend / show-
#!  percentages checkboxes, and a few slice-value spinners) that drive a pie
#!  put on the same window by myPieControl. Point it at the pie by its Name;
#!  whenever an input changes, it pushes the value into that pie's run-time data
#!  and POSTs the pie's redraw, so the chart updates live.
#!
#!  WINDOW (not MULTI): one panel per window, so its own controls can bind to
#!  fixed data labels (myPiePanel:...). The dropped controls hold their own
#!  values; the generated code copies them into <Pie>:Depth / :ShowLeg /
#!  :ShowPct / :Slices[] (which myPieControl exposes as run-time variables).
#!#############################################################################
#CONTROL(myPiePanel,'myPie - Pie Controls panel (drag onto a window)'),WINDOW,DESCRIPTION('Pie controls -> ' & %myPiePanelPie),HLP('~myPie')
  CONTROLS
    GROUP('Pie controls'),AT(2,2,108,156),BOXED,USE(?myPiePanelGroup)
      PROMPT('3D depth:'),AT(8,14,46,10),USE(?myPiePanelDepthP)
      SPIN(@n3),AT(58,12,48,12),RANGE(0,60),STEP(1),USE(myPiePanel:Depth)
      CHECK(' Show legend'),AT(8,28,98,10),USE(myPiePanel:ShowLeg)
      CHECK(' Show percentages'),AT(8,40,98,10),USE(myPiePanel:ShowPct)
      PROMPT('Slice 1:'),AT(8,56,46,10),USE(?myPiePanelS1P)
      SPIN(@n7),RANGE(0,9999999),STEP(1),AT(58,54,48,12),USE(myPiePanel:Slice1)
      PROMPT('Slice 2:'),AT(8,70,46,10),USE(?myPiePanelS2P)
      SPIN(@n7),RANGE(0,9999999),STEP(1),AT(58,68,48,12),USE(myPiePanel:Slice2)
      PROMPT('Slice 3:'),AT(8,84,46,10),USE(?myPiePanelS3P)
      SPIN(@n7),RANGE(0,9999999),STEP(1),AT(58,82,48,12),USE(myPiePanel:Slice3)
      PROMPT('Slice 4:'),AT(8,98,46,10),USE(?myPiePanelS4P)
      SPIN(@n7),RANGE(0,9999999),STEP(1),AT(58,96,48,12),USE(myPiePanel:Slice4)
      PROMPT('Slice 5:'),AT(8,112,46,10),USE(?myPiePanelS5P)
      SPIN(@n7),RANGE(0,9999999),STEP(1),AT(58,110,48,12),USE(myPiePanel:Slice5)
      PROMPT('Slice 6:'),AT(8,126,46,10),USE(?myPiePanelS6P)
      SPIN(@n7),RANGE(0,9999999),STEP(1),AT(58,124,48,12),USE(myPiePanel:Slice6)
    END
  END
#SHEET
  #TAB('&General')
    #BOXED('Target')
      #PROMPT('&Disable this panel',CHECK),%myPiePanelDisable,DEFAULT(0),AT(10)
      #PROMPT('&Pie to control (its Name):',@s64),%myPiePanelPie,REQ,DEFAULT('Pie1')
      #PROMPT('&Slice spinners to wire (0-6):',SPIN(@n1,0,6,1)),%myPiePanelSlices,DEFAULT(3)
    #ENDBOXED
    #DISPLAY('Point this at a myPie - Pie Chart control on the same window by its')
    #DISPLAY('Name. Wire 0-6 slice spinners; delete the unused Slice rows from the')
    #DISPLAY('panel in the Window Designer. Changing any input redraws the pie live.')
  #ENDTAB
#ENDSHEET
#!-----------------------------------------------------------------------------
#ATSTART
  #DECLARE(%myPiePanelI)
  #DECLARE(%myPiePanelFirst)
#ENDAT
#!-----------------------------------------------------------------------------
#! Panel-local data (fixed labels - the panel is one-per-window) + a private
#! "sync" event so we read the pie's values AFTER its OpenWindow has set them.
#AT(%DataSection),WHERE(%myPiePanelDisable=0)
myPiePanel:Depth   SIGNED                                    ! 3D depth shown in the panel
myPiePanel:ShowLeg BYTE                                      ! show-legend checkbox
myPiePanel:ShowPct BYTE                                      ! show-percentages checkbox
myPiePanel:Slice1  SIGNED                                    ! slice value spinners (wire 0-6)
myPiePanel:Slice2  SIGNED
myPiePanel:Slice3  SIGNED
myPiePanel:Slice4  SIGNED
myPiePanel:Slice5  SIGNED
myPiePanel:Slice6  SIGNED
myPiePanel:Sync    EQUATE(EVENT:User+199)                    ! deferred "load from the pie" event
#ENDAT
#!-----------------------------------------------------------------------------
#AT(%WindowManagerMethodCodeSection,'TakeWindowEvent','(),BYTE'),PRIORITY(2500),WHERE(%myPiePanelDisable=0)
  CASE EVENT()
  OF EVENT:OpenWindow
    POST(myPiePanel:Sync)                                    ! load after the pie's OpenWindow ran (POST defers it)
  OF myPiePanel:Sync
    myPiePanel:Depth   = %myPiePanelPie:Depth                ! seed the panel from the pie's current values
    myPiePanel:ShowLeg = %myPiePanelPie:ShowLeg
    myPiePanel:ShowPct = %myPiePanelPie:ShowPct
#SET(%myPiePanelI,1)
#LOOP,WHILE(%myPiePanelI <= %myPiePanelSlices)
    myPiePanel:Slice%myPiePanelI = %myPiePanelPie:Slices[%myPiePanelI]
#SET(%myPiePanelI,%myPiePanelI+1)
#ENDLOOP
    DISPLAY()                                                ! refresh the panel controls
  OF EVENT:Accepted                                          ! any panel input changed -> push to the pie + redraw
    CASE FIELD()
#SET(%myPiePanelFirst,1)
#FOR(%Control),WHERE(%ControlInstance=%ActiveTemplateInstance)
#IF(%myPiePanelFirst)
    OF %Control
#SET(%myPiePanelFirst,0)
#ELSE
    OROF %Control
#ENDIF
#ENDFOR
      %myPiePanelPie:Depth   = myPiePanel:Depth
      %myPiePanelPie:ShowLeg = myPiePanel:ShowLeg
      %myPiePanelPie:ShowPct = myPiePanel:ShowPct
#SET(%myPiePanelI,1)
#LOOP,WHILE(%myPiePanelI <= %myPiePanelSlices)
      %myPiePanelPie:Slices[%myPiePanelI] = myPiePanel:Slice%myPiePanelI
#SET(%myPiePanelI,%myPiePanelI+1)
#ENDLOOP
      POST(Redraw:%myPiePanelPie)                            ! the pie repaints with the new values
    END
  END
#ENDAT
#!-----------------------------------------------------------------------------
#! End of myPie template set
#!-----------------------------------------------------------------------------
