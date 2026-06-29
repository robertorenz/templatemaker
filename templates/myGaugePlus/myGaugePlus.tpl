#TEMPLATE(myGaugePlus,'myGaugePlus - Antialiased (GDI+) gauges/dials on windows - v1.0'),FAMILY('ABC')
#!-----------------------------------------------------------------------------
#!  myGaugePlus template set  -  configurable ANTIALIASED analog gauges drawn
#!  with GDI+ (via GaugePlusClass / AaCanvasClass / gpcanvas.c). Smooth arcs,
#!  glossy radial-gradient face, antialiased needle and crisp text. Renders to a
#!  PNG in %TEMP% and points the IMAGE at it - so the art survives repaints and
#!  prints. No external dependency: gdiplus.dll ships with Windows.
#!
#!  This is the antialiased GDI+ sibling of the native-graphics myGauge set.
#!
#!  myGaugePlusGlobal (APPLICATION) - INCLUDEs GaugePlusClass. Add once, globally.
#!  myGaugePlus       (PROCEDURE)   - draws a gauge into an IMAGE control on a
#!                WINDOW. Add it ONCE PER GAUGE (multiple gauges per window are
#!                fine - each instance gets its own object). Optional animation.
#!  myGaugePlusControl(CONTROL)     - the EASY path: drag this onto a window and
#!                it drops a ready-made IMAGE with the gauge already wired up.
#!                Fully self-contained (it INCLUDEs the class itself).
#!
#!  REQUIRED FILES: copy these (shipped beside this .tpl) to a folder on the
#!  Clarion redirection path (the app folder or \clarion12\libsrc\win), ALL ANSI:
#!      GaugePlusClass.inc   GaugePlusClass.clw
#!      AaCanvasClass.inc    AaCanvasClass.clw
#!      gpcanvas.c
#!  You only INCLUDE GaugePlusClass.INC - it INCLUDEs AaCanvasClass.INC for you.
#!  gpcanvas.c is compiled AUTOMATICALLY (a PRAGMA inside AaCanvasClass.clw) - no
#!  manual project step is needed. gdiplus.dll ships with Windows, so there is no
#!  redistributable to deploy.
#!
#!  API (the object is in the procedure's data - call it from any embed):
#!    Gauge1.SetValue(x)            ! instant; then Gauge1.Draw(Window, ?Img)
#!    Gauge1.AnimateTo(x)           ! eased; needs Animate ticked (window timer)
#!    Gauge1.AddZone(from,to,color) ! colored band
#!-----------------------------------------------------------------------------
#!#############################################################################
#!  GLOBAL EXTENSION - myGaugePlusGlobal
#!#############################################################################
#EXTENSION(myGaugePlusGlobal,'myGaugePlus - Global (add once per application)'),APPLICATION
#SHEET
  #TAB('&General')
    #BOXED('myGaugePlus')
      #DISPLAY('myGaugePlus Global - Version 1.0')
      #DISPLAY('Adds the GaugePlusClass antialiased (GDI+) gauge renderer.')
      #DISPLAY('Add once, at the Application (global) level. IMPORTANT: copy')
      #DISPLAY('GaugePlusClass.inc/.clw, AaCanvasClass.inc/.clw and gpcanvas.c')
      #DISPLAY('to the redirection path - all ANSI. gpcanvas.c compiles itself.')
    #ENDBOXED
    #BOXED('Options')
      #PROMPT('&Disable this template',CHECK),%myGPDisable,DEFAULT(0),AT(10)
    #ENDBOXED
  #ENDTAB
#ENDSHEET
#!
#AT(%AfterGlobalIncludes),WHERE(%myGPDisable=0)
INCLUDE('GaugePlusClass.INC'),ONCE
#ENDAT
#!#############################################################################
#!  PROCEDURE EXTENSION - myGaugePlus (WINDOW)  -  add once per gauge
#!#############################################################################
#EXTENSION(myGaugePlus,'myGaugePlus - Draw an antialiased gauge on this window'),PROCEDURE,REQ(myGaugePlusGlobal),DESCRIPTION(' [Gauge+] ' & %myGPObject)
#SHEET
  #TAB('&General')
    #BOXED('Object &&  control')
      #PROMPT('&Disable this gauge',CHECK),%myGPDisableThis,DEFAULT(0),AT(10)
      #PROMPT('&Object name:',@s64),%myGPObject,REQ,DEFAULT('Gauge' & %ActiveTemplateInstance)
      #PROMPT('&Image control to draw into:',CONTROL),%myGPImage,REQ
    #ENDBOXED
    #BOXED('Shape')
      #PROMPT('Gauge &style:',DROP('180 - Semicircle[1]|270 - Speedometer[2]|360 - Full dial[3]|90 - Quarter[4]|45 - Narrow arc[5]|Custom angles[0]')),%myGPStyle,DEFAULT('2')
      #ENABLE(%myGPStyle='0')
        #PROMPT('Custom start angle (deg, 0=3 o''clock, CCW+):',@n7.1),%myGPStart,DEFAULT(225)
        #PROMPT('Custom sweep angle (deg, negative=clockwise):',@n7.1),%myGPSweep,DEFAULT(-270)
      #ENDENABLE
    #ENDBOXED
    #BOXED('Range &&  value')
      #PROMPT('&Minimum:',@n13.2),%myGPMin,DEFAULT(0)
      #PROMPT('Ma&ximum:',@n13.2),%myGPMax,DEFAULT(100),REQ
      #PROMPT('Value is a &variable / field (not a literal)',CHECK),%myGPValueIsVar,DEFAULT(0),AT(10)
      #ENABLE(%myGPValueIsVar=0)
        #PROMPT('Initial &value:',@n13.2),%myGPInitial,DEFAULT(0)
      #ENDENABLE
      #ENABLE(%myGPValueIsVar=1)
        #PROMPT('Value &field / expression:',@s255),%myGPValueField,DEFAULT('')
      #ENDENABLE
    #ENDBOXED
  #ENDTAB
  #TAB('&Ticks &&  text')
    #BOXED('Ticks')
      #PROMPT('&Major ticks (divisions):',SPIN(@n3,0,50,1)),%myGPMajor,DEFAULT(10)
      #PROMPT('M&inor ticks (between majors):',SPIN(@n3,0,20,1)),%myGPMinor,DEFAULT(0)
      #PROMPT('Show tick &labels',CHECK),%myGPShowLabels,DEFAULT(1),AT(10)
      #PROMPT('Label &decimals:',SPIN(@n2,0,4,1)),%myGPLabelDP,DEFAULT(0)
    #ENDBOXED
    #BOXED('Readout')
      #PROMPT('&Title text:',@s64),%myGPTitle,DEFAULT('')
      #PROMPT('&Units text:',@s32),%myGPUnits,DEFAULT('')
      #PROMPT('Show numeric &value',CHECK),%myGPShowValue,DEFAULT(1),AT(10)
      #PROMPT('Value de&cimals:',SPIN(@n2,0,4,1)),%myGPValueDP,DEFAULT(0)
    #ENDBOXED
  #ENDTAB
  #TAB('&Look')
    #BOXED('Needle')
      #PROMPT('Needle &style:',DROP('Triangle[1]|Line[0]')),%myGPNeedleStyle,DEFAULT('1')
      #PROMPT('Needle &width:',SPIN(@n2,1,20,1)),%myGPNeedleWidth,DEFAULT(5)
      #PROMPT('Needle &color:',COLOR),%myGPNeedleColor,DEFAULT(002B2B2BH)
    #ENDBOXED
    #BOXED('Face &&  colors')
      #PROMPT('&Value / accent color:',COLOR),%myGPValueColor,DEFAULT(00C86E28H)
      #PROMPT('&Face centre color:',COLOR),%myGPFaceColor,DEFAULT(00FAFAFAH)
      #PROMPT('Face &rim color:',COLOR),%myGPFaceEdge,DEFAULT(00D4D4D4H)
      #PROMPT('&Track (empty) color:',COLOR),%myGPTrackColor,DEFAULT(00E2E2E2H)
      #PROMPT('T&ick color:',COLOR),%myGPTickColor,DEFAULT(00909090H)
      #PROMPT('Te&xt color:',COLOR),%myGPTextColor,DEFAULT(003A3A3AH)
      #PROMPT('Show &gloss highlight',CHECK),%myGPShowGloss,DEFAULT(1),AT(10)
      #PROMPT('Show ri&m',CHECK),%myGPShowRim,DEFAULT(1),AT(10)
      #PROMPT('Show value &arc fill',CHECK),%myGPShowValueArc,DEFAULT(1),AT(10)
    #ENDBOXED
    #BOXED('Animation')
      #PROMPT('&Animate the needle (uses the window timer)',CHECK),%myGPAnimate,DEFAULT(0),AT(10)
      #PROMPT('Timer &interval (1/100 sec):',SPIN(@n4,1,500,1)),%myGPAnimSpeed,DEFAULT(4)
      #PROMPT('&Step per tick (%% of range):',@n5.1),%myGPStepPct,DEFAULT(6)
    #ENDBOXED
  #ENDTAB
  #TAB('&Zones')
    #DISPLAY('Colored bands over value ranges (e.g. green 0-60, amber 60-85, red 85-100).')
    #BUTTON('Color Zones'),MULTI(%myGPZone,%myGPZoneFrom & ' - ' & %myGPZoneTo),INLINE
      #PROMPT('&From value:',@n13.2),%myGPZoneFrom,DEFAULT(0)
      #PROMPT('&To value:',@n13.2),%myGPZoneTo,DEFAULT(0)
      #PROMPT('&Color:',COLOR),%myGPZoneColor,DEFAULT(00008000H)
    #ENDBUTTON
  #ENDTAB
#ENDSHEET
#!-----------------------------------------------------------------------------
#AT(%DataSection),WHERE(%myGPDisableThis=0 AND %myGPImage)
%myGPObject          GaugePlusClass                          ! one gauge object for this instance
Redraw:%myGPObject   EQUATE(EVENT:User + 200 + %ActiveTemplateInstance) ! private "repaint" event (unique per gauge)
#ENDAT
#!
#! PRIORITY(2000) puts this self-contained CASE EVENT() ABOVE the framework's own
#! LOOP/CASE scaffolding (registered at PRIORITY 2500) - same proven spot myGauge,
#! myQRDraw and myPixel use. Using 2500 collides with the framework.
#AT(%WindowManagerMethodCodeSection,'TakeWindowEvent','(),BYTE'),PRIORITY(2000),WHERE(%myGPDisableThis=0 AND %myGPImage)
  CASE EVENT()
  OF EVENT:OpenWindow
    %myGPObject.SetRange(%myGPMin, %myGPMax)
#IF(%myGPStyle = '0')
    %myGPObject.SetSpan(%myGPStart, %myGPSweep)
#ELSE
    %myGPObject.Preset(%myGPStyle)
#ENDIF
    %myGPObject.MajorTicks = %myGPMajor
    %myGPObject.MinorTicks = %myGPMinor
    %myGPObject.ShowLabels = %myGPShowLabels
    %myGPObject.LabelDP = %myGPLabelDP
    %myGPObject.ShowValue = %myGPShowValue
    %myGPObject.ValueDP = %myGPValueDP
    %myGPObject.NeedleStyle = %myGPNeedleStyle
    %myGPObject.NeedleWidth = %myGPNeedleWidth
    %myGPObject.NeedleColor = %myGPNeedleColor
    %myGPObject.ValueColor = %myGPValueColor
    %myGPObject.FaceColor = %myGPFaceColor
    %myGPObject.FaceEdge = %myGPFaceEdge
    %myGPObject.TrackColor = %myGPTrackColor
    %myGPObject.TickColor = %myGPTickColor
    %myGPObject.TextColor = %myGPTextColor
    %myGPObject.ShowGloss = %myGPShowGloss
    %myGPObject.ShowRim = %myGPShowRim
    %myGPObject.ShowValueArc = %myGPShowValueArc
    %myGPObject.AnimStepPct = %myGPStepPct
    %myGPObject.Title = '%myGPTitle'
    %myGPObject.Units = '%myGPUnits'
#FOR(%myGPZone)
    %myGPObject.AddZone(%myGPZoneFrom, %myGPZoneTo, %myGPZoneColor)
#ENDFOR
#IF(%myGPValueIsVar)
    %myGPObject.SetValue(%myGPValueField)
#ELSE
    %myGPObject.SetValue(%myGPInitial)
#ENDIF
    POST(Redraw:%myGPObject)                                 ! first draw, after the window has opened
#IF(%myGPAnimate)
    0{PROP:Timer} = %myGPAnimSpeed
#ENDIF
  OF EVENT:Sized
    POST(Redraw:%myGPObject)                                 ! redraw AFTER the resizer settles (fresh size)
  OF Redraw:%myGPObject
    %myGPObject.Draw(%Window, %myGPImage)
#IF(%myGPAnimate)
  OF EVENT:Timer
#IF(%myGPValueIsVar)
    %myGPObject.AnimateTo(%myGPValueField)
#ENDIF
    IF %myGPObject.AnimStep()                                ! eased a step? repaint at the new needle position
      %myGPObject.Draw(%Window, %myGPImage)
    END
#ENDIF
  END
#ENDAT
#!
#!  A per-instance refresh ROUTINE: re-read the value field (if any) and redraw.
#!  Call it (e.g. DO Refresh:Gauge1) after the value changes when NOT animating.
#AT(%ProcedureRoutines),WHERE(%myGPDisableThis=0 AND %myGPImage)
Refresh:%myGPObject ROUTINE
#IF(%myGPValueIsVar)
#IF(%myGPAnimate)
  %myGPObject.AnimateTo(%myGPValueField)                     ! eased; the timer finishes the sweep
#ELSE
  %myGPObject.SetValue(%myGPValueField)                      ! instant
#ENDIF
#ENDIF
  %myGPObject.Draw(%Window, %myGPImage)
#ENDAT
#!#############################################################################
#!  CONTROL TEMPLATE - myGaugePlusControl  -  drag a ready-made gauge onto a window
#!#############################################################################
#!  Drops an IMAGE control AND wires the gauge to it in one drag. Self-contained:
#!  it emits INCLUDE('GaugePlusClass.INC'),ONCE at %CustomGlobalDeclarations - the
#!  per-MODULE compile-global embed (corpus: ABDROPS.TPW:65 - a control template
#!  writing a global declaration). The myGaugePlusGlobal extension uses the GLOBAL
#!  %AfterGlobalIncludes instead; the two scopes differ but ,ONCE keys on the
#!  filename across the whole compile, so the class is pulled in exactly once even
#!  with both present. So the user does NOT need the myGaugePlusGlobal extension here.
#!  WINDOW + MULTI = many per window.
#!  The control's own field equate is captured in %myGPCtlImage via the proven
#!  #FOR(%Control),WHERE(%ControlInstance=%ActiveTemplateInstance) idiom
#!  (corpus: CONTROL.TPW:107, CloseButton) - so it tracks AppGen's auto-uniqued feq.
#!#############################################################################
#CONTROL(myGaugePlusControl,'myGaugePlus - Antialiased Gauge (drag onto a window)'),WINDOW,MULTI,DESCRIPTION('Antialiased gauge ' & %myGPCtlObject),HLP('~myGaugePlus.htm')
#! the gauge canvas - one IMAGE; its feq auto-uniques on multi-drop and is captured below
  CONTROLS
    IMAGE,AT(,,120,120),USE(?Gauge)
  END
#SHEET
  #TAB('&General')
    #BOXED('Object')
      #PROMPT('&Disable this gauge',CHECK),%myGPCtlDisable,DEFAULT(0),AT(10)
      #PROMPT('&Object name:',@s64),%myGPCtlObject,REQ,DEFAULT('Gauge' & %ActiveTemplateInstance)
    #ENDBOXED
    #BOXED('Shape')
      #PROMPT('Gauge &style:',DROP('180 - Semicircle[1]|270 - Speedometer[2]|360 - Full dial[3]|90 - Quarter[4]|45 - Narrow arc[5]|Custom angles[0]')),%myGPCtlStyle,DEFAULT('2')
      #ENABLE(%myGPCtlStyle='0')
        #PROMPT('Custom start angle (deg, 0=3 o''clock, CCW+):',@n7.1),%myGPCtlStart,DEFAULT(225)
        #PROMPT('Custom sweep angle (deg, negative=clockwise):',@n7.1),%myGPCtlSweep,DEFAULT(-270)
      #ENDENABLE
    #ENDBOXED
    #BOXED('Range &&  value')
      #PROMPT('&Minimum:',@n13.2),%myGPCtlMin,DEFAULT(0)
      #PROMPT('Ma&ximum:',@n13.2),%myGPCtlMax,DEFAULT(100),REQ
      #PROMPT('Value is a &variable / field (not a literal)',CHECK),%myGPCtlValueIsVar,DEFAULT(0),AT(10)
      #ENABLE(%myGPCtlValueIsVar=0)
        #PROMPT('Initial &value:',@n13.2),%myGPCtlInitial,DEFAULT(0)
      #ENDENABLE
      #ENABLE(%myGPCtlValueIsVar=1)
        #PROMPT('Value &field / expression:',@s255),%myGPCtlValueField,DEFAULT('')
      #ENDENABLE
    #ENDBOXED
  #ENDTAB
  #TAB('&Ticks &&  text')
    #BOXED('Ticks')
      #PROMPT('&Major ticks (divisions):',SPIN(@n3,0,50,1)),%myGPCtlMajor,DEFAULT(10)
      #PROMPT('M&inor ticks (between majors):',SPIN(@n3,0,20,1)),%myGPCtlMinor,DEFAULT(0)
      #PROMPT('Show tick &labels',CHECK),%myGPCtlShowLabels,DEFAULT(1),AT(10)
      #PROMPT('Label &decimals:',SPIN(@n2,0,4,1)),%myGPCtlLabelDP,DEFAULT(0)
    #ENDBOXED
    #BOXED('Readout')
      #PROMPT('&Title text:',@s64),%myGPCtlTitle,DEFAULT('')
      #PROMPT('&Units text:',@s32),%myGPCtlUnits,DEFAULT('')
      #PROMPT('Show numeric &value',CHECK),%myGPCtlShowValue,DEFAULT(1),AT(10)
      #PROMPT('Value de&cimals:',SPIN(@n2,0,4,1)),%myGPCtlValueDP,DEFAULT(0)
    #ENDBOXED
  #ENDTAB
  #TAB('&Look')
    #BOXED('Needle')
      #PROMPT('Needle &style:',DROP('Triangle[1]|Line[0]')),%myGPCtlNeedleStyle,DEFAULT('1')
      #PROMPT('Needle &width:',SPIN(@n2,1,20,1)),%myGPCtlNeedleWidth,DEFAULT(5)
      #PROMPT('Needle &color:',COLOR),%myGPCtlNeedleColor,DEFAULT(002B2B2BH)
    #ENDBOXED
    #BOXED('Face &&  colors')
      #PROMPT('&Value / accent color:',COLOR),%myGPCtlValueColor,DEFAULT(00C86E28H)
      #PROMPT('&Face centre color:',COLOR),%myGPCtlFaceColor,DEFAULT(00FAFAFAH)
      #PROMPT('Face &rim color:',COLOR),%myGPCtlFaceEdge,DEFAULT(00D4D4D4H)
      #PROMPT('&Track (empty) color:',COLOR),%myGPCtlTrackColor,DEFAULT(00E2E2E2H)
      #PROMPT('T&ick color:',COLOR),%myGPCtlTickColor,DEFAULT(00909090H)
      #PROMPT('Te&xt color:',COLOR),%myGPCtlTextColor,DEFAULT(003A3A3AH)
      #PROMPT('Show &gloss highlight',CHECK),%myGPCtlShowGloss,DEFAULT(1),AT(10)
      #PROMPT('Show ri&m',CHECK),%myGPCtlShowRim,DEFAULT(1),AT(10)
      #PROMPT('Show value &arc fill',CHECK),%myGPCtlShowValueArc,DEFAULT(1),AT(10)
    #ENDBOXED
    #BOXED('Animation')
      #PROMPT('&Animate the needle (uses the window timer)',CHECK),%myGPCtlAnimate,DEFAULT(0),AT(10)
      #PROMPT('Timer &interval (1/100 sec):',SPIN(@n4,1,500,1)),%myGPCtlAnimSpeed,DEFAULT(4)
      #PROMPT('&Step per tick (%% of range):',@n5.1),%myGPCtlStepPct,DEFAULT(6)
    #ENDBOXED
  #ENDTAB
  #TAB('&Zones')
    #DISPLAY('Colored bands over value ranges (e.g. green 0-60, amber 60-85, red 85-100).')
    #BUTTON('Color Zones'),MULTI(%myGPCtlZone,%myGPCtlZoneFrom & ' - ' & %myGPCtlZoneTo),INLINE
      #PROMPT('&From value:',@n13.2),%myGPCtlZoneFrom,DEFAULT(0)
      #PROMPT('&To value:',@n13.2),%myGPCtlZoneTo,DEFAULT(0)
      #PROMPT('&Color:',COLOR),%myGPCtlZoneColor,DEFAULT(00008000H)
    #ENDBUTTON
  #ENDTAB
#ENDSHEET
#!-----------------------------------------------------------------------------
#! Capture THIS instance's IMAGE field equate (auto-uniqued by AppGen on drop)
#ATSTART
  #DECLARE(%myGPCtlImage)
  #FOR(%Control),WHERE(%ControlInstance=%ActiveTemplateInstance)
    #SET(%myGPCtlImage,%Control)
  #ENDFOR
#ENDAT
#!
#! Self-contained: pull in the class globally (ONCE = safe if the global extension
#! or another gauge control is also present).
#AT(%CustomGlobalDeclarations),WHERE(%myGPCtlDisable=0)
INCLUDE('GaugePlusClass.INC'),ONCE
#ENDAT
#!
#AT(%DataSection),WHERE(%myGPCtlDisable=0)
%myGPCtlObject          GaugePlusClass                          ! one gauge object for this control
Redraw:%myGPCtlObject   EQUATE(EVENT:User + 200 + %ActiveTemplateInstance) ! private "repaint" event (unique per gauge)
#ENDAT
#!
#AT(%WindowManagerMethodCodeSection,'TakeWindowEvent','(),BYTE'),PRIORITY(2000),WHERE(%myGPCtlDisable=0)
  CASE EVENT()
  OF EVENT:OpenWindow
    %myGPCtlObject.SetRange(%myGPCtlMin, %myGPCtlMax)
#IF(%myGPCtlStyle = '0')
    %myGPCtlObject.SetSpan(%myGPCtlStart, %myGPCtlSweep)
#ELSE
    %myGPCtlObject.Preset(%myGPCtlStyle)
#ENDIF
    %myGPCtlObject.MajorTicks = %myGPCtlMajor
    %myGPCtlObject.MinorTicks = %myGPCtlMinor
    %myGPCtlObject.ShowLabels = %myGPCtlShowLabels
    %myGPCtlObject.LabelDP = %myGPCtlLabelDP
    %myGPCtlObject.ShowValue = %myGPCtlShowValue
    %myGPCtlObject.ValueDP = %myGPCtlValueDP
    %myGPCtlObject.NeedleStyle = %myGPCtlNeedleStyle
    %myGPCtlObject.NeedleWidth = %myGPCtlNeedleWidth
    %myGPCtlObject.NeedleColor = %myGPCtlNeedleColor
    %myGPCtlObject.ValueColor = %myGPCtlValueColor
    %myGPCtlObject.FaceColor = %myGPCtlFaceColor
    %myGPCtlObject.FaceEdge = %myGPCtlFaceEdge
    %myGPCtlObject.TrackColor = %myGPCtlTrackColor
    %myGPCtlObject.TickColor = %myGPCtlTickColor
    %myGPCtlObject.TextColor = %myGPCtlTextColor
    %myGPCtlObject.ShowGloss = %myGPCtlShowGloss
    %myGPCtlObject.ShowRim = %myGPCtlShowRim
    %myGPCtlObject.ShowValueArc = %myGPCtlShowValueArc
    %myGPCtlObject.AnimStepPct = %myGPCtlStepPct
    %myGPCtlObject.Title = '%myGPCtlTitle'
    %myGPCtlObject.Units = '%myGPCtlUnits'
#FOR(%myGPCtlZone)
    %myGPCtlObject.AddZone(%myGPCtlZoneFrom, %myGPCtlZoneTo, %myGPCtlZoneColor)
#ENDFOR
#IF(%myGPCtlValueIsVar)
    %myGPCtlObject.SetValue(%myGPCtlValueField)
#ELSE
    %myGPCtlObject.SetValue(%myGPCtlInitial)
#ENDIF
    POST(Redraw:%myGPCtlObject)                              ! first draw, after the window has opened
#IF(%myGPCtlAnimate)
    0{PROP:Timer} = %myGPCtlAnimSpeed
#ENDIF
  OF EVENT:Sized
    POST(Redraw:%myGPCtlObject)                              ! redraw AFTER the resizer settles (fresh size)
  OF Redraw:%myGPCtlObject
    %myGPCtlObject.Draw(%Window, %myGPCtlImage)
#IF(%myGPCtlAnimate)
  OF EVENT:Timer
#IF(%myGPCtlValueIsVar)
    %myGPCtlObject.AnimateTo(%myGPCtlValueField)
#ENDIF
    IF %myGPCtlObject.AnimStep()                             ! eased a step? repaint at the new needle position
      %myGPCtlObject.Draw(%Window, %myGPCtlImage)
    END
#ENDIF
  END
#ENDAT
#!
#! Per-control refresh ROUTINE: re-read the value field (if any) and redraw.
#! Call it (e.g. DO Refresh:Gauge1) after the value changes when NOT animating.
#AT(%ProcedureRoutines),WHERE(%myGPCtlDisable=0)
Refresh:%myGPCtlObject ROUTINE
#IF(%myGPCtlValueIsVar)
#IF(%myGPCtlAnimate)
  %myGPCtlObject.AnimateTo(%myGPCtlValueField)                ! eased; the timer finishes the sweep
#ELSE
  %myGPCtlObject.SetValue(%myGPCtlValueField)                 ! instant
#ENDIF
#ENDIF
  %myGPCtlObject.Draw(%Window, %myGPCtlImage)
#ENDAT
#!-----------------------------------------------------------------------------
#! End of myGaugePlus template set
#!-----------------------------------------------------------------------------
