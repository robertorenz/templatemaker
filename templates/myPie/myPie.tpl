#TEMPLATE(myPie,'myPie - Draw a Pie Chart into a Window - v1.5'),FAMILY('ABC')
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
#CONTROL(myPieControl,'myPie - Pie Chart (drag onto a window)'),WINDOW,MULTI,DESCRIPTION('Pie chart'),HLP('~myPie')
#! the pie canvas - one IMAGE; its feq auto-uniques on multi-drop and is captured below
  CONTROLS
    IMAGE,AT(,,140,120),USE(?Pie)
  END
#SHEET
  #TAB('&General')
    #BOXED('Pie')
      #PROMPT('&Disable this pie',CHECK),%myPieCtlDisable,DEFAULT(0),AT(10)
      #DISPLAY('This pie''s data is keyed by its Image control. A "Pie Controls"')
      #DISPLAY('panel links to it by picking that Image (no names to keep in sync).')
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
      #DISPLAY('Color) - these SEED the runtime slice queue. Drop several of')
      #DISPLAY('these on one window if you like.')
      #DISPLAY('')
      #DISPLAY('The slices live in a runtime QUEUE (<Image>:Q) - unbounded count.')
      #DISPLAY('Drop a "Pie Controls" panel to edit slices in-cell at run time,')
      #DISPLAY('or change the queue yourself then repaint, e.g.')
      #DISPLAY('   <Image>:QValue = 75 ; PUT(<Image>:Q) ;  DO Repaint:<Image>')
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
#! key this pie's data off its IMAGE field-equate (strip '?' and any ':') so a
#! Pie Controls panel can derive the SAME prefix just by picking the Image
  #DECLARE(%myPieCtlKey)
  #DECLARE(%myPieCtlCp)
  #SET(%myPieCtlKey,SUB(%myPieCtlImage,2,250))
  #SET(%myPieCtlCp,INSTRING(':',%myPieCtlKey,1,1))
  #LOOP,WHILE(%myPieCtlCp)
    #SET(%myPieCtlKey,SUB(%myPieCtlKey,1,%myPieCtlCp-1) & '_' & SUB(%myPieCtlKey,%myPieCtlCp+1,250))
    #SET(%myPieCtlCp,INSTRING(':',%myPieCtlKey,1,1))
  #ENDLOOP
#ENDAT
#!-----------------------------------------------------------------------------
#! Per-instance data. The slice data is now a RUNTIME QUEUE (unbounded slice
#! count); the gen-time Segments prompts only SEED it. PIE() still needs plain
#! arrays, so we keep fixed DIM(64) working buffers and rebuild them from the
#! queue on every redraw. Data goes BEFORE the window (%DataSectionBeforeWindow)
#! so a myPiePanel's LIST,FROM(<this queue>) is legal (window controls cannot
#! forward-reference data declared after the window).
#!
#! The QUEUE MUST carry ,PRE() - VALIDATED: a queue with colon-bearing field
#! labels (e.g. <key>:QLabel) is only bare-accessible WITH ,PRE(); without it
#! every reference is "Unknown identifier" (pievalid2 standalone build).
#!-----------------------------------------------------------------------------
#AT(%DataSectionBeforeWindow),WHERE(%myPieCtlDisable=0 AND ITEMS(%myPieCtlSeg))
%myPieCtlKey:Q       QUEUE,PRE()                            ! one row per slice (unbounded; a myPiePanel edits it)
%myPieCtlKey:QLabel    STRING(64)                           ! slice label
%myPieCtlKey:QValue    LONG                                 ! slice value (relative size)
%myPieCtlKey:QColor    LONG                                 ! slice fill color
                     END
%myPieCtlKey:Slices SIGNED,DIM(64)                          ! PIE() slices buffer (rebuilt from :Q each redraw)
%myPieCtlKey:Colors LONG,DIM(64)                            ! PIE() colors buffer (rebuilt from :Q each redraw)
%myPieCtlKey:Total  LONG                                    ! sum of slices (for percentages)
%myPieCtlKey:N      LONG                                    ! active slice count (= RECORDS(:Q), capped at 64)
%myPieCtlKey:Ix     LONG                                    ! loop index
%myPieCtlKey:W      SIGNED                                  ! current image width
%myPieCtlKey:H      SIGNED                                  ! current image height
%myPieCtlKey:PieDim SIGNED                                  ! pie diameter
%myPieCtlKey:Indt   SIGNED                                  ! pie inset
%myPieCtlKey:LegX   SIGNED                                  ! legend left
%myPieCtlKey:LegY   SIGNED                                  ! legend row y
%myPieCtlKey:Pct    SIGNED                                  ! a slice percentage
%myPieCtlKey:Depth  SIGNED                                  ! 3D depth      - live-adjustable (see myPiePanel)
%myPieCtlKey:ShowLeg BYTE                                   ! show legend   - live-adjustable
%myPieCtlKey:ShowPct BYTE                                   ! show percent  - live-adjustable
Redraw:%myPieCtlKey EQUATE(EVENT:User+200+%ActiveTemplateInstance) ! private repaint event (unique per pie)
#ENDAT
#!-----------------------------------------------------------------------------
#! Repaint ROUTINE - "DO Repaint:<Name>" after changing the slice values.
#AT(%ProcedureRoutines),WHERE(%myPieCtlDisable=0 AND ITEMS(%myPieCtlSeg))
Repaint:%myPieCtlKey ROUTINE
  POST(Redraw:%myPieCtlKey)
#ENDAT
#!-----------------------------------------------------------------------------
#! Self-contained handler at the TOP of TakeWindowEvent (PRIORITY 2000). Drawing
#! is POSTed so it runs AFTER the window opens / the resizer settles. The pie
#! fills the left 55%% when a legend is shown, else the whole control.
#!-----------------------------------------------------------------------------
#AT(%WindowManagerMethodCodeSection,'TakeWindowEvent','(),BYTE'),PRIORITY(2000),WHERE(%myPieCtlDisable=0 AND ITEMS(%myPieCtlSeg))
  CASE EVENT()
  OF EVENT:OpenWindow
    %myPieCtlKey:Depth   = %myPieCtlDepth                   ! seed the live-adjustable properties from the
    %myPieCtlKey:ShowLeg = %myPieCtlShowLegend             !   design-time prompts (a myPiePanel can change
    %myPieCtlKey:ShowPct = %myPieCtlShowPct                !   them at run time, then POST Redraw:<Name>)
    FREE(%myPieCtlKey:Q)                                    ! seed the slice QUEUE from the gen-time Segments
    #FOR(%myPieCtlSeg)
    %myPieCtlKey:QLabel = '%myPieCtlSegLabel'
    %myPieCtlKey:QValue = %myPieCtlSegValue
    %myPieCtlKey:QColor = %myPieCtlSegColor
    ADD(%myPieCtlKey:Q)
    #ENDFOR
    POST(Redraw:%myPieCtlKey)                               ! first draw, after the window opens
  OF EVENT:Sized
    POST(Redraw:%myPieCtlKey)                               ! redraw after the resize settles
  OF Redraw:%myPieCtlKey
    CLEAR(%myPieCtlKey:Slices)                              ! rebuild PIE() buffers from the live queue:
    CLEAR(%myPieCtlKey:Colors)                              !   unused trailing slots stay 0 (a 0-value slice
    %myPieCtlKey:Total = 0                                  !   is a 0-degree wedge = invisible, so a fixed
    %myPieCtlKey:N = RECORDS(%myPieCtlKey:Q)                !   DIM(64) holds an "unbounded" slice count)
    IF %myPieCtlKey:N > 64 THEN %myPieCtlKey:N = 64.
    LOOP %myPieCtlKey:Ix = 1 TO %myPieCtlKey:N
      GET(%myPieCtlKey:Q,%myPieCtlKey:Ix)
      %myPieCtlKey:Slices[%myPieCtlKey:Ix] = %myPieCtlKey:QValue
      %myPieCtlKey:Colors[%myPieCtlKey:Ix] = %myPieCtlKey:QColor
      %myPieCtlKey:Total += %myPieCtlKey:QValue
    END
    %myPieCtlKey:W = %myPieCtlImage{PROP:Width}
    %myPieCtlKey:H = %myPieCtlImage{PROP:Height}
    IF %myPieCtlKey:ShowLeg
      %myPieCtlKey:PieDim = %myPieCtlKey:W * 55 / 100       ! pie gets the left 55pct, legend the rest
    ELSE
      %myPieCtlKey:PieDim = %myPieCtlKey:W
    END
    IF %myPieCtlKey:H < %myPieCtlKey:PieDim THEN %myPieCtlKey:PieDim = %myPieCtlKey:H.   ! keep it on-screen
    SETTARGET(%Window,%myPieCtlImage)                        ! the IMAGE is the target: 0,0 = its corner
    BLANK                                                    ! clears ONLY this image (no window-wide wipe)
    IF %myPieCtlBackColor <> COLOR:None
      SETPENCOLOR(%myPieCtlBackColor)
      BOX(0,0,%myPieCtlKey:W,%myPieCtlKey:H,%myPieCtlBackColor)
    END
    SETPENCOLOR(COLOR:Black)                                 ! slice outlines
    %myPieCtlKey:Indt = %myPieCtlKey:PieDim * 2 / 100      ! small inset so the pie clears the edge
    PIE(%myPieCtlKey:Indt,%myPieCtlKey:Indt,%myPieCtlKey:PieDim - %myPieCtlKey:Indt * 2,%myPieCtlKey:PieDim - %myPieCtlKey:Indt * 2,%myPieCtlKey:Slices,%myPieCtlKey:Colors,%myPieCtlKey:Depth)
    IF %myPieCtlKey:ShowLeg                                  ! legend (runtime-gated so a panel can toggle it)
      %myPieCtlKey:LegX = %myPieCtlKey:PieDim + 8
      %myPieCtlKey:LegY = 6
      LOOP %myPieCtlKey:Ix = 1 TO %myPieCtlKey:N            ! legend now walks the QUEUE at run time
        GET(%myPieCtlKey:Q,%myPieCtlKey:Ix)
        SETPENCOLOR(%myPieCtlKey:QColor)
        BOX(%myPieCtlKey:LegX,%myPieCtlKey:LegY,9,8,%myPieCtlKey:QColor)             ! color swatch
        SETPENCOLOR(COLOR:Black)
        IF %myPieCtlKey:ShowPct
          IF %myPieCtlKey:Total
            %myPieCtlKey:Pct = INT(%myPieCtlKey:QValue * 100 / %myPieCtlKey:Total + 0.5)
          ELSE
            %myPieCtlKey:Pct = 0
          END
          SHOW(%myPieCtlKey:LegX + 14,%myPieCtlKey:LegY,CLIP(%myPieCtlKey:QLabel) & ' = ' & %myPieCtlKey:Pct & '%%')
        ELSE
          SHOW(%myPieCtlKey:LegX + 14,%myPieCtlKey:LegY,CLIP(%myPieCtlKey:QLabel))
        END
        %myPieCtlKey:LegY = %myPieCtlKey:LegY + 13
      END
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
#!  WINDOW,MULTI: MANY panels per window, one per pie. The dropped controls all
#!  USE FIELD-EQUATES (no data variables) so AppGen auto-uniques each instance's
#!  feqs on drop and there are NO duplicate-label collisions. PROVEN FACT: a
#!  #CONTROL...CONTROLS block does NOT substitute %symbols in USE() (USE must be a
#!  literal feq label), so the on-window controls cannot be %-uniqued by us - we
#!  rely on AppGen's own feq auto-uniquing of multi-instance controls, and capture
#!  each instance's real feq in #ATSTART (the shipped SVUSortOrder.tpw idiom) to
#!  use in the generated handler code. The MODAL editor window (declared in
#!  #AT(%DataSection), which DOES substitute %symbols) and its USE vars ARE made
#!  instance-unique with %(%ActiveTemplateInstance).
#!  LAYOUT: in a CONTROLS block each control's AT(x,y) is RELATIVE TO THE PREVIOUS
#!  control (cumulative), NOT absolute - like the shipped FormVCRButtons / abfuzzy
#!  templates. Absolute coords make the drop SCATTER. The x,y below are deltas that
#!  land the controls at this tidy layout inside the 160x212 group (do NOT change
#!  them back to absolute): depth(8,14) entry(58,12) legend(8,30) pct(8,44)
#!  list(8,60) Add(8,170) Edit(58,170) Delete(108,170) hint(8,190).
#!  feq-only controls: a feq CHECK's `{PROP:Value}` is useless (never tracks the
#!  toggle, and SET doesn't drive the mark) - but `{PROP:Checked}` READS the real
#!  mark inside the check's own Accepted handler (proven). So on each click we just
#!  read PROP:Checked into the pie's flag (no flip = no inversion). Depth is an
#!  ENTRY(@n3) read via PROP:ScreenText (a feq SPIN doesn't retain its value).
#!#############################################################################
#CONTROL(myPiePanel,'myPie - Pie Controls panel (drag onto a window)'),WINDOW,MULTI,DESCRIPTION('Pie controls'),HLP('~myPie')
  CONTROLS
    GROUP('Pie controls'),USE(?myPiePanelGroup),AT(,,160,212),BOXED
      PROMPT('3D depth:'),AT(8,14,46,10),USE(?myPiePanelDepthP)
      ENTRY(@n3),AT(50,-2,50,12),USE(?myPiePanelDepth)
      CHECK(' Show legend'),AT(-50,18,144,10),USE(?myPiePanelShowLeg)
      CHECK(' Show percentages'),AT(0,16,144,10),USE(?myPiePanelShowPct)
      LIST,AT(0,16,144,104),USE(?myPiePanelList),VSCROLL,ALRT(MouseLeft2),FROM(''),FORMAT('66L(2)|M~Label~@s64@40R(2)|M~Value~@n-11@40R(2)|M~Color~@n-11@')
      BUTTON('&Add'),AT(0,110,44,14),USE(?myPiePanelAdd)
      BUTTON('&Edit'),AT(50,0,44,14),USE(?myPiePanelEdit)
      BUTTON('&Delete'),AT(50,0,44,14),USE(?myPiePanelDelete)
      PROMPT('Double-click a slice, or use the buttons.'),AT(-100,20,144,16),USE(?myPiePanelHint)
    END
  END
#SHEET
  #TAB('&General')
    #BOXED('Target')
      #PROMPT('&Disable this panel',CHECK),%myPiePanelDisable,DEFAULT(0),AT(10)
      #PROMPT('&Pie Image to control:',CONTROL),%myPiePanelImage,REQ
    #ENDBOXED
    #DISPLAY('PICK the IMAGE control of a myPie - Pie Chart on this window - the')
    #DISPLAY('panel binds to that pie by its Image. The slice list shows every')
    #DISPLAY('slice; Add / Edit / Delete (or double-click a row) edit them via a')
    #DISPLAY('small popup (Label / Value / Color). The 3D-depth spinner and the')
    #DISPLAY('legend / percentage checkboxes drive the pie too. Every change')
    #DISPLAY('redraws the pie live - the slice count is unbounded.')
  #ENDTAB
#ENDSHEET
#!-----------------------------------------------------------------------------
#ATSTART
#! derive the target pie's data prefix from the PICKED Image feq (strip '?' and
#! any ':') - identical rule to myPieControl, so the names match exactly
  #DECLARE(%myPiePanelPrefix)
  #DECLARE(%myPiePanelCp)
  #SET(%myPiePanelPrefix,SUB(%myPiePanelImage,2,250))
  #SET(%myPiePanelCp,INSTRING(':',%myPiePanelPrefix,1,1))
  #LOOP,WHILE(%myPiePanelCp)
    #SET(%myPiePanelPrefix,SUB(%myPiePanelPrefix,1,%myPiePanelCp-1) & '_' & SUB(%myPiePanelPrefix,%myPiePanelCp+1,250))
    #SET(%myPiePanelCp,INSTRING(':',%myPiePanelPrefix,1,1))
  #ENDLOOP
#! capture THIS instance's auto-uniqued control field-equates (shipped
#! SVUSortOrder.tpw idiom: match %ControlOriginal under this instance). The
#! generated handler code below uses these captured feq symbols so every panel
#! refers to ITS OWN controls - no fixed feq label is ever emitted.
  #DECLARE(%PanelDepthFeq)
  #DECLARE(%PanelLegFeq)
  #DECLARE(%PanelPctFeq)
  #DECLARE(%PanelListFeq)
  #DECLARE(%PanelAddFeq)
  #DECLARE(%PanelEditFeq)
  #DECLARE(%PanelDeleteFeq)
  #FOR(%Control),WHERE(%ControlInstance=%ActiveTemplateInstance)
    #IF(%ControlOriginal='?myPiePanelDepth')
      #SET(%PanelDepthFeq,%Control)
    #ENDIF
    #IF(%ControlOriginal='?myPiePanelShowLeg')
      #SET(%PanelLegFeq,%Control)
    #ENDIF
    #IF(%ControlOriginal='?myPiePanelShowPct')
      #SET(%PanelPctFeq,%Control)
    #ENDIF
    #IF(%ControlOriginal='?myPiePanelList')
      #SET(%PanelListFeq,%Control)
    #ENDIF
    #IF(%ControlOriginal='?myPiePanelAdd')
      #SET(%PanelAddFeq,%Control)
    #ENDIF
    #IF(%ControlOriginal='?myPiePanelEdit')
      #SET(%PanelEditFeq,%Control)
    #ENDIF
    #IF(%ControlOriginal='?myPiePanelDelete')
      #SET(%PanelDeleteFeq,%Control)
    #ENDIF
  #ENDFOR
#ENDAT
#!-----------------------------------------------------------------------------
#! MULTI panel: NO fixed data labels (a second drop would redeclare them ->
#! "duplicate label"). The on-window controls are all field-equates (captured in
#! #ATSTART), and the ONLY per-instance data is the deferred "sync" EQUATE and the
#! MODAL editor + its USE vars - both made instance-unique with
#! %(%ActiveTemplateInstance). #AT(%DataSection) DOES substitute %symbols (proven),
#! so %(%ActiveTemplateInstance) gives each panel its own labels.
#!
#! Sync base = EVENT:User+150+instance: stays clear of the pie's
#! Redraw = EVENT:User+200+instance, and of EVENT:User+101..199 used by the
#! procedure-extension myPie. The INCLUDEs are ,ONCE so many drops are safe.
#AT(%DataSection),WHERE(%myPiePanelDisable=0)
  INCLUDE('KEYCODES.CLW'),ONCE                               ! MouseLeft2 (double-click to edit)
  INCLUDE('EQUATES.CLW'),ONCE                                ! EVENT: / COLOR:
myPiePanel:Sync%(%ActiveTemplateInstance)   EQUATE(EVENT:User+150+%ActiveTemplateInstance) ! deferred "load from the pie" (unique per panel)
myPiePanel:EdLabel%(%ActiveTemplateInstance) STRING(64)      ! edited slice label   (instance-unique)
myPiePanel:EdValue%(%ActiveTemplateInstance) LONG            ! edited slice value   (instance-unique)
myPiePanel:EdColor%(%ActiveTemplateInstance) LONG            ! edited slice color   (instance-unique)
myPiePanel:EdOK%(%ActiveTemplateInstance)    BYTE            ! modal result 1=OK    (instance-unique)
myPiePanel:EditW%(%ActiveTemplateInstance)   WINDOW('Edit Slice'),AT(,,170,98),CENTER,GRAY,DOUBLE,SYSTEM,MODAL
                     PROMPT('&Label:'),AT(8,12,34,10),USE(?myPiePanelEdLblP%(%ActiveTemplateInstance))
                     ENTRY(@s64),AT(46,10,116,12),USE(myPiePanel:EdLabel%(%ActiveTemplateInstance))
                     PROMPT('&Value:'),AT(8,30,34,10),USE(?myPiePanelEdValP%(%ActiveTemplateInstance))
                     SPIN(@n7),AT(46,28,70,12),USE(myPiePanel:EdValue%(%ActiveTemplateInstance)),RANGE(0,32767),STEP(1)
                     PROMPT('&Color:'),AT(8,48,34,10),USE(?myPiePanelEdClrP%(%ActiveTemplateInstance))
                     BUTTON('&Pick...'),AT(46,46,54,12),USE(?myPiePanelEdColorBtn%(%ActiveTemplateInstance))
                     BUTTON('&OK'),AT(40,76,44,14),USE(?myPiePanelEdOK%(%ActiveTemplateInstance)),DEFAULT
                     BUTTON('&Cancel'),AT(92,76,44,14),USE(?myPiePanelEdCancel%(%ActiveTemplateInstance))
                   END
#ENDAT
#!-----------------------------------------------------------------------------
#AT(%WindowManagerMethodCodeSection,'TakeWindowEvent','(),BYTE'),PRIORITY(2000),WHERE(%myPiePanelDisable=0)
  CASE EVENT()
  OF EVENT:OpenWindow
    %PanelListFeq{PROP:From} = %myPiePanelPrefix:Q            ! point THIS panel's LIST at the pie's real slice
    POST(myPiePanel:Sync%(%ActiveTemplateInstance))          !   queue (CONTROLS used FROM(''), so rebind here),
  OF myPiePanel:Sync%(%ActiveTemplateInstance)               !   then defer the load to AFTER the pie seeded :Q
    %PanelDepthFeq{PROP:ScreenText} = %myPiePanelPrefix:Depth  ! seed the depth ENTRY from the pie (ScreenText).
    %PanelLegFeq{PROP:Checked} = %myPiePanelPrefix:ShowLeg   !   best-effort mark seed (CHECK marks read back via
    %PanelPctFeq{PROP:Checked} = %myPiePanelPrefix:ShowPct   !   PROP:Checked on click - that's authoritative)
    DISPLAY()                                                ! refresh the panel controls
  END
#ENDAT
#!-----------------------------------------------------------------------------
#! Control changes are FIELD events (TakeFieldEvent). The 3D-depth spinner + the
#! two checkboxes push their values into the pie on change. Add / Edit / Delete
#! (and a double-click on the list) edit the slice QUEUE via a modal popup; after
#! any change POST the pie's redraw so the chart updates live.
#AT(%WindowManagerMethodCodeSection,'TakeFieldEvent','(),BYTE'),PRIORITY(2000),WHERE(%myPiePanelDisable=0)
  CASE FIELD()
  OF %PanelDepthFeq                                          ! depth ENTRY -> read the typed value (this
    IF EVENT() = EVENT:Accepted                              !   instance's captured feq)
      %myPiePanelPrefix:Depth = %PanelDepthFeq{PROP:ScreenText}
      POST(Redraw:%myPiePanelPrefix)
    END
  OF %PanelLegFeq                                            ! legend CHECK: PROP:Checked reads the REAL mark in
    IF EVENT() = EVENT:Accepted                              !   the check's own Accepted (PROP:Value never does)
      %myPiePanelPrefix:ShowLeg = %PanelLegFeq{PROP:Checked} !   - so just read it; checked->shown, no inversion
      POST(Redraw:%myPiePanelPrefix)
    END
  OF %PanelPctFeq                                            ! percentages CHECK - read PROP:Checked the same way
    IF EVENT() = EVENT:Accepted
      %myPiePanelPrefix:ShowPct = %PanelPctFeq{PROP:Checked}
      POST(Redraw:%myPiePanelPrefix)
    END
  OF %PanelAddFeq                                            ! Add -> popup with defaults, then ADD a row
    IF EVENT() = EVENT:Accepted THEN DO myPiePanel:AddRtn%(%ActiveTemplateInstance).
  OF %PanelEditFeq                                           ! Edit -> popup pre-loaded from the selected row
    IF EVENT() = EVENT:Accepted THEN DO myPiePanel:EditRtn%(%ActiveTemplateInstance).
  OF %PanelListFeq                                           ! double-click a row -> same as Edit
    IF EVENT() = EVENT:AlertKey AND KEYCODE() = MouseLeft2 THEN DO myPiePanel:EditRtn%(%ActiveTemplateInstance).
  OF %PanelDeleteFeq                                         ! Delete -> remove the selected row
    IF EVENT() = EVENT:Accepted
      IF CHOICE(%PanelListFeq)
        GET(%myPiePanelPrefix:Q,CHOICE(%PanelListFeq))
        IF NOT ERRORCODE()
          DELETE(%myPiePanelPrefix:Q)
          DISPLAY(%PanelListFeq)
          POST(Redraw:%myPiePanelPrefix)
        END
      END
    END
  END
#ENDAT
#!-----------------------------------------------------------------------------
#! The slice-edit routines. DlgRtn opens the modal popup and sets EdOK; AddRtn /
#! EditRtn pre-load the Ed* fields, run the popup, and on OK write the queue +
#! redraw. The popup is a hand-opened modal (OPEN/ACCEPT/CLOSE) - plain, robust
#! Clarion, no EIP classes.
#! Per-instance routines: names carry %ActiveTemplateInstance, the modal window +
#! Ed* vars are the instance-unique labels declared in #AT(%DataSection), and the
#! LIST / queue are this panel's captured feq + the pie's derived prefix. Two
#! panels' routines never collide.
#AT(%ProcedureRoutines),WHERE(%myPiePanelDisable=0)
myPiePanel:DlgRtn%(%ActiveTemplateInstance) ROUTINE
  myPiePanel:EdOK%(%ActiveTemplateInstance) = 0
  OPEN(myPiePanel:EditW%(%ActiveTemplateInstance))
  ACCEPT
    CASE EVENT()
    OF EVENT:CloseWindow
      BREAK
    OF EVENT:Accepted
      CASE ACCEPTED()
      OF ?myPiePanelEdColorBtn%(%ActiveTemplateInstance)
        IF COLORDIALOG('Slice Color',myPiePanel:EdColor%(%ActiveTemplateInstance)) THEN DISPLAY.
      OF ?myPiePanelEdOK%(%ActiveTemplateInstance)
        myPiePanel:EdOK%(%ActiveTemplateInstance) = 1
        BREAK
      OF ?myPiePanelEdCancel%(%ActiveTemplateInstance)
        BREAK
      END
    END
  END
  CLOSE(myPiePanel:EditW%(%ActiveTemplateInstance))

myPiePanel:AddRtn%(%ActiveTemplateInstance) ROUTINE
  myPiePanel:EdLabel%(%ActiveTemplateInstance) = 'New'
  myPiePanel:EdValue%(%ActiveTemplateInstance) = 1
  myPiePanel:EdColor%(%ActiveTemplateInstance) = COLOR:Silver
  DO myPiePanel:DlgRtn%(%ActiveTemplateInstance)
  IF myPiePanel:EdOK%(%ActiveTemplateInstance)
    CLEAR(%myPiePanelPrefix:Q)
    %myPiePanelPrefix:QLabel = myPiePanel:EdLabel%(%ActiveTemplateInstance)
    %myPiePanelPrefix:QValue = myPiePanel:EdValue%(%ActiveTemplateInstance)
    %myPiePanelPrefix:QColor = myPiePanel:EdColor%(%ActiveTemplateInstance)
    ADD(%myPiePanelPrefix:Q,CHOICE(%PanelListFeq)+1)         ! add below the selection
    DISPLAY(%PanelListFeq)
    POST(Redraw:%myPiePanelPrefix)
  END

myPiePanel:EditRtn%(%ActiveTemplateInstance) ROUTINE
  IF NOT CHOICE(%PanelListFeq) THEN EXIT.
  GET(%myPiePanelPrefix:Q,CHOICE(%PanelListFeq))
  IF ERRORCODE() THEN EXIT.
  myPiePanel:EdLabel%(%ActiveTemplateInstance) = %myPiePanelPrefix:QLabel
  myPiePanel:EdValue%(%ActiveTemplateInstance) = %myPiePanelPrefix:QValue
  myPiePanel:EdColor%(%ActiveTemplateInstance) = %myPiePanelPrefix:QColor
  DO myPiePanel:DlgRtn%(%ActiveTemplateInstance)
  IF myPiePanel:EdOK%(%ActiveTemplateInstance)
    %myPiePanelPrefix:QLabel = myPiePanel:EdLabel%(%ActiveTemplateInstance)
    %myPiePanelPrefix:QValue = myPiePanel:EdValue%(%ActiveTemplateInstance)
    %myPiePanelPrefix:QColor = myPiePanel:EdColor%(%ActiveTemplateInstance)
    PUT(%myPiePanelPrefix:Q)
    DISPLAY(%PanelListFeq)
    POST(Redraw:%myPiePanelPrefix)
  END
#ENDAT
#!-----------------------------------------------------------------------------
#! End of myPie template set
#!-----------------------------------------------------------------------------
