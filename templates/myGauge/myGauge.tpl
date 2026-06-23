#TEMPLATE(myGauge,'myGauge - Analog gauges/dials on windows and reports - v1.0'),FAMILY('ABC')
#!-----------------------------------------------------------------------------
#!  myGauge template set  -  configurable analog gauges drawn with native
#!  Clarion graphics (ARC/ELLIPSE/LINE/POLYGON/SHOW). No external dependencies.
#!
#!  myGaugeGlobal (APPLICATION) - INCLUDEs GaugeClass. Add once, globally.
#!  myGauge       (PROCEDURE)   - draws a gauge into an IMAGE control on a WINDOW.
#!                Add it ONCE PER GAUGE (multiple gauges per window are fine - each
#!                instance gets its own object). Optional smooth needle animation.
#!  myGaugeReport (PROCEDURE)   - draws a gauge per record into an IMAGE control in
#!                a REPORT band.
#!
#!  REQUIRED FILES: copy GaugeClass.inc AND GaugeClass.clw (shipped beside this
#!  .tpl) to a folder on the Clarion redirection path (the app folder or
#!  \clarion12\libsrc\win). Store them in ANSI (not UTF-8).
#!
#!  API (the object is in the procedure's data - call it from any embed):
#!    Gauge1.SetValue(x)            ! instant; then Gauge1.Draw(?Img)
#!    Gauge1.AnimateTo(x)           ! eased; needs Animate ticked (window timer)
#!    Gauge1.AddZone(from,to,color) ! colored band
#!-----------------------------------------------------------------------------
#!#############################################################################
#!  GLOBAL EXTENSION - myGaugeGlobal
#!#############################################################################
#EXTENSION(myGaugeGlobal,'myGauge - Global (add once per application)'),APPLICATION
#SHEET
  #TAB('&General')
    #BOXED('myGauge')
      #DISPLAY('myGauge Global - Version 1.0')
      #DISPLAY('Adds the GaugeClass analog-gauge encoder/renderer.')
      #DISPLAY('Add once, at the Application (global) level. IMPORTANT: copy')
      #DISPLAY('GaugeClass.inc + GaugeClass.clw to the redirection path - ANSI.')
    #ENDBOXED
    #BOXED('Options')
      #PROMPT('&Disable this template',CHECK),%myGaugeDisable,DEFAULT(0),AT(10)
    #ENDBOXED
  #ENDTAB
#ENDSHEET
#!
#AT(%AfterGlobalIncludes),WHERE(%myGaugeDisable=0)
INCLUDE('GaugeClass.INC'),ONCE
#ENDAT
#!#############################################################################
#!  PROCEDURE EXTENSION - myGauge (WINDOW)  -  add once per gauge
#!#############################################################################
#EXTENSION(myGauge,'myGauge - Draw a gauge on this window'),PROCEDURE,REQ(myGaugeGlobal),DESCRIPTION(' [Gauge] ' & %myGaugeObject)
#SHEET
  #TAB('&General')
    #BOXED('Object &&  control')
      #PROMPT('&Disable this gauge',CHECK),%myGaugeDisableThis,DEFAULT(0),AT(10)
      #PROMPT('&Object name:',@s64),%myGaugeObject,REQ,DEFAULT('Gauge' & %ActiveTemplateInstance)
      #PROMPT('&Image control to draw into:',CONTROL),%myGaugeImage,REQ
    #ENDBOXED
    #BOXED('Shape')
      #PROMPT('Gauge &style:',DROP('180 - Semicircle[1]|270 - Speedometer[2]|360 - Full dial[3]|90 - Quarter[4]|45 - Narrow arc[5]|Custom angles[0]')),%myGaugeStyle,DEFAULT('2')
      #ENABLE(%myGaugeStyle='0')
        #PROMPT('Custom start angle (deg, 0=3 o''clock, CCW+):',@n7.1),%myGaugeStart,DEFAULT(225)
        #PROMPT('Custom sweep angle (deg, negative=clockwise):',@n7.1),%myGaugeSweep,DEFAULT(-270)
      #ENDENABLE
    #ENDBOXED
    #BOXED('Range &&  value')
      #PROMPT('&Minimum:',@n13.2),%myGaugeMin,DEFAULT(0)
      #PROMPT('Ma&ximum:',@n13.2),%myGaugeMax,DEFAULT(100),REQ
      #PROMPT('Value is a &variable / field (not a literal)',CHECK),%myGaugeValueIsVar,DEFAULT(0),AT(10)
      #ENABLE(%myGaugeValueIsVar=0)
        #PROMPT('Initial &value:',@n13.2),%myGaugeInitial,DEFAULT(0)
      #ENDENABLE
      #ENABLE(%myGaugeValueIsVar=1)
        #PROMPT('Value &field / expression:',@s255),%myGaugeValueField,DEFAULT('')
      #ENDENABLE
    #ENDBOXED
  #ENDTAB
  #TAB('&Ticks &&  text')
    #BOXED('Ticks')
      #PROMPT('&Major ticks (divisions):',SPIN(@n3,0,50,1)),%myGaugeMajor,DEFAULT(10)
      #PROMPT('M&inor ticks (between majors):',SPIN(@n3,0,20,1)),%myGaugeMinor,DEFAULT(0)
      #PROMPT('Show tick &labels',CHECK),%myGaugeShowLabels,DEFAULT(1),AT(10)
      #PROMPT('Label &decimals:',SPIN(@n2,0,4,1)),%myGaugeLabelDP,DEFAULT(0)
    #ENDBOXED
    #BOXED('Readout')
      #PROMPT('&Title text:',@s64),%myGaugeTitle,DEFAULT('')
      #PROMPT('&Units text:',@s32),%myGaugeUnits,DEFAULT('')
      #PROMPT('Show numeric &value',CHECK),%myGaugeShowValue,DEFAULT(1),AT(10)
      #PROMPT('Value de&cimals:',SPIN(@n2,0,4,1)),%myGaugeValueDP,DEFAULT(0)
    #ENDBOXED
  #ENDTAB
  #TAB('&Look')
    #BOXED('Needle')
      #PROMPT('Needle &style:',DROP('Triangle[1]|Line[0]')),%myGaugeNeedleStyle,DEFAULT('1')
      #PROMPT('Needle &width:',SPIN(@n2,1,20,1)),%myGaugeNeedleWidth,DEFAULT(5)
      #PROMPT('Needle &color:',COLOR),%myGaugeNeedleColor,DEFAULT(002B2B2BH)
    #ENDBOXED
    #BOXED('Face &&  colors')
      #PROMPT('Show &face circle',CHECK),%myGaugeShowFace,DEFAULT(0),AT(10)
      #PROMPT('Show &rim',CHECK),%myGaugeShowRim,DEFAULT(0),AT(10)
      #PROMPT('&Face color:',COLOR),%myGaugeFaceColor,DEFAULT(00FFFFFFH)
      #PROMPT('&Track (empty) color:',COLOR),%myGaugeTrackColor,DEFAULT(00DCDCDCH)
      #PROMPT('T&ick color:',COLOR),%myGaugeTickColor,DEFAULT(00808080H)
      #PROMPT('Te&xt color:',COLOR),%myGaugeTextColor,DEFAULT(002B2B2BH)
    #ENDBOXED
    #BOXED('Animation')
      #PROMPT('&Animate the needle (uses the window timer)',CHECK),%myGaugeAnimate,DEFAULT(0),AT(10)
      #PROMPT('Timer &interval (1/100 sec):',SPIN(@n4,1,500,1)),%myGaugeAnimSpeed,DEFAULT(4)
      #PROMPT('&Step per tick (%% of range):',@n5.1),%myGaugeStepPct,DEFAULT(6)
    #ENDBOXED
  #ENDTAB
  #TAB('&Zones')
    #DISPLAY('Colored bands over value ranges (e.g. green 0-60, amber 60-85, red 85-100).')
    #BUTTON('Color Zones'),MULTI(%myGaugeZone,%myGaugeZoneFrom & ' - ' & %myGaugeZoneTo),INLINE
      #PROMPT('&From value:',@n13.2),%myGaugeZoneFrom,DEFAULT(0)
      #PROMPT('&To value:',@n13.2),%myGaugeZoneTo,DEFAULT(0)
      #PROMPT('&Color:',COLOR),%myGaugeZoneColor,DEFAULT(00008000H)
    #ENDBUTTON
  #ENDTAB
#ENDSHEET
#!-----------------------------------------------------------------------------
#AT(%DataSection),WHERE(%myGaugeDisableThis=0 AND %myGaugeImage)
%myGaugeObject       GaugeClass                              ! one gauge object for this instance
#ENDAT
#!
#! PRIORITY(2000) puts this self-contained CASE EVENT() ABOVE the framework's own
#! LOOP/CASE scaffolding (registered at PRIORITY 2500) - same proven spot myQRDraw
#! and myPixel use. Using 2500 collides with the framework and duplicates CASE EVENT().
#AT(%WindowManagerMethodCodeSection,'TakeWindowEvent','(),BYTE'),PRIORITY(2000),WHERE(%myGaugeDisableThis=0 AND %myGaugeImage)
  CASE EVENT()
  OF EVENT:OpenWindow
    %myGaugeObject.SetRange(%myGaugeMin, %myGaugeMax)
#IF(%myGaugeStyle = '0')
    %myGaugeObject.SetSpan(%myGaugeStart, %myGaugeSweep)
#ELSE
    %myGaugeObject.Preset(%myGaugeStyle)
#ENDIF
    %myGaugeObject.MajorTicks = %myGaugeMajor
    %myGaugeObject.MinorTicks = %myGaugeMinor
    %myGaugeObject.ShowLabels = %myGaugeShowLabels
    %myGaugeObject.LabelDP = %myGaugeLabelDP
    %myGaugeObject.ShowValue = %myGaugeShowValue
    %myGaugeObject.ValueDP = %myGaugeValueDP
    %myGaugeObject.ShowFace = %myGaugeShowFace
    %myGaugeObject.ShowRim = %myGaugeShowRim
    %myGaugeObject.NeedleStyle = %myGaugeNeedleStyle
    %myGaugeObject.NeedleWidth = %myGaugeNeedleWidth
    %myGaugeObject.NeedleColor = %myGaugeNeedleColor
    %myGaugeObject.FaceColor = %myGaugeFaceColor
    %myGaugeObject.TrackColor = %myGaugeTrackColor
    %myGaugeObject.TickColor = %myGaugeTickColor
    %myGaugeObject.TextColor = %myGaugeTextColor
    %myGaugeObject.AnimStepPct = %myGaugeStepPct
    %myGaugeObject.Title = '%myGaugeTitle'
    %myGaugeObject.Units = '%myGaugeUnits'
#FOR(%myGaugeZone)
    %myGaugeObject.AddZone(%myGaugeZoneFrom, %myGaugeZoneTo, %myGaugeZoneColor)
#ENDFOR
#IF(%myGaugeValueIsVar)
    %myGaugeObject.SetValue(%myGaugeValueField)
#ELSE
    %myGaugeObject.SetValue(%myGaugeInitial)
#ENDIF
    %myGaugeObject.Draw(%myGaugeImage)
#IF(%myGaugeAnimate)
    0{PROP:Timer} = %myGaugeAnimSpeed
#ENDIF
  OF EVENT:Sized
    %myGaugeObject.Draw(%myGaugeImage)
#IF(%myGaugeAnimate)
  OF EVENT:Timer
#IF(%myGaugeValueIsVar)
    %myGaugeObject.AnimateTo(%myGaugeValueField)
#ENDIF
    %myGaugeObject.AnimStep()
#ENDIF
  END
#ENDAT
#!
#!  A per-instance refresh ROUTINE: re-read the value field (if any) and redraw.
#!  Call it (e.g. DO Refresh:Gauge1) after the value changes when NOT animating.
#AT(%ProcedureRoutines),WHERE(%myGaugeDisableThis=0 AND %myGaugeImage)
Refresh:%myGaugeObject ROUTINE
#IF(%myGaugeValueIsVar)
#IF(%myGaugeAnimate)
  %myGaugeObject.AnimateTo(%myGaugeValueField)                ! eased; the timer finishes the sweep
#ELSE
  %myGaugeObject.SetValue(%myGaugeValueField)                 ! instant
#ENDIF
#ENDIF
  %myGaugeObject.Draw(%myGaugeImage)
#ENDAT
#!#############################################################################
#!  PROCEDURE EXTENSION - myGaugeReport (REPORT)  -  per record
#!#############################################################################
#EXTENSION(myGaugeReport,'myGauge - Draw a gauge on this REPORT'),PROCEDURE,REQ(myGaugeGlobal),DESCRIPTION(' [Gauge] ' & %myGaugeRptObject)
#SHEET
  #TAB('&General')
    #BOXED('Object &&  control')
      #PROMPT('&Disable this gauge',CHECK),%myGaugeRptDisable,DEFAULT(0),AT(10)
      #PROMPT('&Object name:',@s64),%myGaugeRptObject,REQ,DEFAULT('RptGauge' & %ActiveTemplateInstance)
      #! a report needs FROM(%ReportControl,...) (corpus: blobsrv.tpw:20), not a window CONTROL prompt
      #PROMPT('&Image control (in a report band):',FROM(%ReportControl,%ReportControlType = 'IMAGE')),%myGaugeRptImage,REQ,DEFAULT('')
      #PROMPT('Gauge &style:',DROP('180 - Semicircle[1]|270 - Speedometer[2]|360 - Full dial[3]|90 - Quarter[4]|45 - Narrow arc[5]')),%myGaugeRptStyle,DEFAULT('2')
    #ENDBOXED
    #BOXED('Range &&  value')
      #PROMPT('&Minimum:',@n13.2),%myGaugeRptMin,DEFAULT(0)
      #PROMPT('Ma&ximum:',@n13.2),%myGaugeRptMax,DEFAULT(100),REQ
      #PROMPT('Value &field / expression (per record):',@s255),%myGaugeRptValueField,REQ,DEFAULT('')
      #PROMPT('&Major ticks:',SPIN(@n3,0,50,1)),%myGaugeRptMajor,DEFAULT(10)
      #PROMPT('Show tick &labels',CHECK),%myGaugeRptShowLabels,DEFAULT(1),AT(10)
      #PROMPT('Show numeric &value',CHECK),%myGaugeRptShowValue,DEFAULT(1),AT(10)
      #PROMPT('&Title text:',@s64),%myGaugeRptTitle,DEFAULT('')
      #PROMPT('&Units text:',@s32),%myGaugeRptUnits,DEFAULT('')
    #ENDBOXED
    #BOXED('Colors')
      #PROMPT('Needle &color:',COLOR),%myGaugeRptNeedleColor,DEFAULT(002B2B2BH)
      #PROMPT('T&rack color:',COLOR),%myGaugeRptTrackColor,DEFAULT(00DCDCDCH)
    #ENDBOXED
  #ENDTAB
  #TAB('&Zones')
    #BUTTON('Color Zones'),MULTI(%myGaugeRptZone,%myGaugeRptZoneFrom & ' - ' & %myGaugeRptZoneTo),INLINE
      #PROMPT('&From value:',@n13.2),%myGaugeRptZoneFrom,DEFAULT(0)
      #PROMPT('&To value:',@n13.2),%myGaugeRptZoneTo,DEFAULT(0)
      #PROMPT('&Color:',COLOR),%myGaugeRptZoneColor,DEFAULT(00008000H)
    #ENDBUTTON
  #ENDTAB
#ENDSHEET
#!-----------------------------------------------------------------------------
#AT(%DataSection),WHERE(%myGaugeRptDisable=0 AND %myGaugeRptImage)
%myGaugeRptObject    GaugeClass
#ENDAT
#!
#AT(%BeforePrint),WHERE(%myGaugeRptDisable=0 AND %myGaugeRptImage)
  %myGaugeRptObject.SetRange(%myGaugeRptMin, %myGaugeRptMax)
  %myGaugeRptObject.Preset(%myGaugeRptStyle)
  %myGaugeRptObject.MajorTicks = %myGaugeRptMajor
  %myGaugeRptObject.ShowLabels = %myGaugeRptShowLabels
  %myGaugeRptObject.ShowValue = %myGaugeRptShowValue
  %myGaugeRptObject.NeedleColor = %myGaugeRptNeedleColor
  %myGaugeRptObject.TrackColor = %myGaugeRptTrackColor
  %myGaugeRptObject.Title = '%myGaugeRptTitle'
  %myGaugeRptObject.Units = '%myGaugeRptUnits'
  %myGaugeRptObject.ClearZones()
#FOR(%myGaugeRptZone)
  %myGaugeRptObject.AddZone(%myGaugeRptZoneFrom, %myGaugeRptZoneTo, %myGaugeRptZoneColor)
#ENDFOR
  %myGaugeRptObject.SetValue(%myGaugeRptValueField)
  SETTARGET(%Report)                                         ! the report band is the draw target
  %myGaugeRptObject.Paint(%myGaugeRptImage)
  SETTARGET()
#ENDAT
#!-----------------------------------------------------------------------------
#! End of myGauge template set
#!-----------------------------------------------------------------------------
