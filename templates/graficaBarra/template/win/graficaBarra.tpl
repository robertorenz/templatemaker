#TEMPLATE(graficaBarra,'graficaBarra - Charts on windows and reports - v2.1'),FAMILY('ABC')
#!-----------------------------------------------------------------------------
#!  graficaBarra template set - THIRTEEN chart types drawn with native Clarion
#!  graphics primitives (BOX / LINE / POLYGON / ELLIPSE / PIE / SHOW).
#!  No external dependencies, no DLL, no encoder.
#!
#!    Column          Bar (horizontal)   Stacked column   Stacked bar
#!    Stacked percent Line               Area             Stacked area
#!    Scatter         Pie                Pie 3D           Donut         Radar
#!
#!  graficaBarraGlobal (APPLICATION) - INCLUDEs GraficaBarraClass. Add once.
#!  graficaBarra       (PROCEDURE)   - draws a chart into an IMAGE control on a
#!                     WINDOW. Add once per chart (several per window is fine).
#!  graficaBarraReport (PROCEDURE)   - draws a chart into a REPORT band as
#!                     BOX/LINE/POLYGON/ELLIPSE/PIE VECTOR primitives - never a
#!                     bitmap - so a PDF export stays as small as possible. A
#!                     control in the band (IMAGE / BOX / REGION) is used ONLY
#!                     as the position and size placeholder; it is hidden at
#!                     print time. Add once per chart - SEVERAL CHARTS ON ONE
#!                     REPORT ARE FINE, and they follow the band down the page
#!                     as it repeats, each with its own data and its own scale.
#!
#!  REQUIRED FILES: copy GraficaBarraClass.inc AND GraficaBarraClass.clw
#!  (shipped beside this .tpl) to a folder on the Clarion redirection path
#!  (the app folder or \clarion12\libsrc\win). Store them in ANSI.
#!
#!  API (the object is in the procedure's data - call it from any embed):
#!    Graph1.ChartType = Chart:Donut
#!    Graph1.ClearAll() ; Graph1.AddBar('Ene', 120) ; Graph1.AddBar('Feb', 95)
#!    Graph1.AddSeries('Norte') ; Graph1.AddCat('Ene', 120, 80)  ! many series
#!    Graph1.SetRange(0, 200)          ! fixed scale (otherwise auto nice scale)
#!    DO Refresh:Graph1                ! window: reload the data + redraw
#!-----------------------------------------------------------------------------
#!  The three DROP prompts (chart type, legend spot, marker shape) are turned
#!  into Clarion EQUATE names by %gbSetEquates, and one data row's arguments by
#!  %gbSetValueArgs - both hand their answers back through *%reference
#!  parameters, so every symbol stays local to the section that asked.
#!#############################################################################
#!  GLOBAL EXTENSION - graficaBarraGlobal
#!#############################################################################
#EXTENSION(graficaBarraGlobal,'graficaBarra - Global (add once per application)'),APPLICATION
#SHEET
  #TAB('&General')
    #BOXED('graficaBarra')
      #DISPLAY('graficaBarra Global - Version 2.1')
      #DISPLAY('Adds the GraficaBarraClass chart renderer - 13 chart types,')
      #DISPLAY('on windows and on reports, drawn with native primitives.')
      #DISPLAY('Add once, at the Application (global) level. IMPORTANT: copy')
      #DISPLAY('GraficaBarraClass.inc + .clw to the redirection path - ANSI.')
    #ENDBOXED
    #BOXED('Options')
      #PROMPT('&Disable this template',CHECK),%gbDisable,DEFAULT(0),AT(10)
    #ENDBOXED
  #ENDTAB
#ENDSHEET
#!
#AT(%AfterGlobalIncludes),WHERE(%gbDisable=0)
INCLUDE('GraficaBarraClass.INC'),ONCE
#ENDAT
#!#############################################################################
#!  PROCEDURE EXTENSION - graficaBarra (WINDOW)  -  add once per chart
#!#############################################################################
#EXTENSION(graficaBarra,'graficaBarra - Draw a chart on this window'),PROCEDURE,MULTI,REQ(graficaBarraGlobal),DESCRIPTION('[' & %gbWType & '] ' & %gbWObject)
#SHEET
  #TAB('&General')
    #BOXED('Object &&  control')
      #PROMPT('&Disable this chart',CHECK),%gbWDisable,DEFAULT(0),AT(10)
      #PROMPT('&Object name:',@s64),%gbWObject,REQ,DEFAULT('Graph' & %ActiveTemplateInstance)
      #PROMPT('&Image control to draw into:',CONTROL),%gbWImage,REQ
      #PROMPT('&Title text:',@s64),%gbWTitle,DEFAULT('')
    #ENDBOXED
    #BOXED('Chart')
      #PROMPT('Chart &type:',DROP('Column|Bar (horizontal)|Stacked column|Stacked bar|Stacked percent|Line|Area|Stacked area|Scatter|Pie|Pie 3D|Donut|Radar')),%gbWType,DEFAULT('Column')
      #PROMPT('Number of &series:',SPIN(@n1,1,4,1)),%gbWNSeries,DEFAULT(1)
      #DISPLAY('One series = a color per bar / slice. Two or more = a color per')
      #DISPLAY('series, with a legend. Pie, Pie 3D and Donut always use series 1.')
    #ENDBOXED
    #BOXED('Value scale')
      #PROMPT('&Automatic scale (nice round maximum from the data)',CHECK),%gbWAutoScale,DEFAULT(1),AT(10)
      #ENABLE(%gbWAutoScale=0)
        #PROMPT('&Minimum:',@n13.2),%gbWMin,DEFAULT(0)
        #PROMPT('Ma&ximum:',@n13.2),%gbWMax,DEFAULT(100)
      #ENDENABLE
    #ENDBOXED
  #ENDTAB
  #TAB('&Look')
    #BOXED('Show')
      #PROMPT('Show &values',CHECK),%gbWShowValues,DEFAULT(1),AT(10)
      #PROMPT('Value &decimals:',SPIN(@n2,0,4,1)),%gbWValueDP,DEFAULT(0)
      #PROMPT('Values as a &percentage of the total',CHECK),%gbWPercent,DEFAULT(0),AT(10)
      #PROMPT('Show &labels',CHECK),%gbWShowLabels,DEFAULT(1),AT(10)
      #PROMPT('Show &scale (axis numbers)',CHECK),%gbWShowScale,DEFAULT(1),AT(10)
      #PROMPT('Scale d&ecimals:',SPIN(@n2,0,4,1)),%gbWScaleDP,DEFAULT(0)
      #PROMPT('Show &gridlines',CHECK),%gbWShowGrid,DEFAULT(1),AT(10)
      #PROMPT('Scale/grid di&visions:',SPIN(@n3,1,20,1)),%gbWGridDivs,DEFAULT(5)
      #PROMPT('Show the &axis and the zero line',CHECK),%gbWShowAxis,DEFAULT(1),AT(10)
    #ENDBOXED
    #BOXED('Legend')
      #PROMPT('Show a le&gend',CHECK),%gbWShowLegend,DEFAULT(1),AT(10)
      #ENABLE(%gbWShowLegend=1)
        #PROMPT('&Where:',DROP('Bottom|Right|Top')),%gbWLegendPos,DEFAULT('Bottom')
      #ENDENABLE
    #ENDBOXED
  #ENDTAB
  #TAB('Sha&pes')
    #BOXED('Bars, lines and markers')
      #PROMPT('Gap between bars (%% of a slot):',SPIN(@n3,0,90,5)),%gbWGapPct,DEFAULT(30)
      #PROMPT('Line &thickness:',SPIN(@n2,1,9,1)),%gbWLineWidth,DEFAULT(2)
      #PROMPT('S&mooth the line (rounded corners)',CHECK),%gbWSmooth,DEFAULT(0),AT(10)
      #PROMPT('Show mar&kers on lines and areas',CHECK),%gbWMarkers,DEFAULT(1),AT(10)
      #PROMPT('Marker s&hape:',DROP('Circle|Square|Diamond')),%gbWMarkerShape,DEFAULT('Circle')
      #PROMPT('Marker si&ze (0 = automatic):',SPIN(@n3,0,40,1)),%gbWMarkerSize,DEFAULT(0)
    #ENDBOXED
    #BOXED('Pie, Pie 3D, Donut')
      #PROMPT('First slice starts at (degrees clockwise):',SPIN(@n3,0,359,15)),%gbWStartAngle,DEFAULT(0)
      #PROMPT('3D depth (0 = automatic):',SPIN(@n3,0,99,1)),%gbWDepth3D,DEFAULT(0)
      #PROMPT('Donut hole (percent of the diameter):',SPIN(@n3,10,90,5)),%gbWDonutPct,DEFAULT(55)
      #PROMPT('Text in the middle of the donut:',@s32),%gbWDonutText,DEFAULT('')
    #ENDBOXED
  #ENDTAB
  #TAB('Te&xt && colors')
    #BOXED('Type')
      #DISPLAY('Blank / 0 = draw with whatever font the target is using.')
      #DISPLAY('A size also scales the layout, so labels keep their spacing.')
      #PROMPT('&Typeface (blank = the window''s):',@s32),%gbWFontName,DEFAULT('')
      #PROMPT('Si&ze (0 = the window''s):',SPIN(@n3,0,72,1)),%gbWFontSize,DEFAULT(0)
      #PROMPT('&Bold',CHECK),%gbWFontBold,DEFAULT(0),AT(10)
      #PROMPT('&Italic',CHECK),%gbWFontItalic,DEFAULT(0),AT(10)
    #ENDBOXED
    #BOXED('Colors')
      #PROMPT('Paint the &background',CHECK),%gbWUseBack,DEFAULT(0),AT(10)
      #ENABLE(%gbWUseBack=1)
        #PROMPT('Background &color:',COLOR),%gbWBackColor,DEFAULT(00FFFFFFH)
      #ENDENABLE
      #PROMPT('Paint the &plot area',CHECK),%gbWUsePlot,DEFAULT(0),AT(10)
      #ENABLE(%gbWUsePlot=1)
        #PROMPT('Plot area c&olor:',COLOR),%gbWPlotColor,DEFAULT(00FBFBFBH)
      #ENDENABLE
      #PROMPT('A&xis color:',COLOR),%gbWAxisColor,DEFAULT(002B2B2BH)
      #PROMPT('G&rid color:',COLOR),%gbWGridColor,DEFAULT(00E0E0E0H)
      #PROMPT('Te&xt color:',COLOR),%gbWTextColor,DEFAULT(002B2B2BH)
      #PROMPT('Outline the bars and slices',CHECK),%gbWUseBorder,DEFAULT(0),AT(10)
      #ENABLE(%gbWUseBorder=1)
        #PROMPT('Outline color:',COLOR),%gbWBorderColor,DEFAULT(00FFFFFFH)
      #ENDENABLE
    #ENDBOXED
  #ENDTAB
  #TAB('&Series 1-2')
    #DISPLAY('Only needed when "Number of series" on the General tab is 2 or more.')
    #DISPLAY('The name is what the legend shows. "Draw as" mixes shapes on the one')
    #DISPLAY('chart - sales on Bars, the trend on Line, over the same value axis.')
    #BOXED('Series 1')
      #PROMPT('&Name:',@s32),%gbWS1Name,DEFAULT('Series 1')
      #PROMPT('Automatic &color',CHECK),%gbWS1Auto,DEFAULT(1),AT(10)
      #ENABLE(%gbWS1Auto=0)
        #PROMPT('C&olor:',COLOR),%gbWS1Color,DEFAULT(00B6752EH)
      #ENDENABLE
      #ENABLE(%gbWNSeries>=2 AND (%gbWType='Column' OR %gbWType='Line' OR %gbWType='Scatter'))
        #PROMPT('&Draw as:',DROP('As the chart type|Bars|Line')),%gbWS1Plot,DEFAULT('As the chart type')
      #ENDENABLE
      #ENABLE(%gbWNSeries>=2)
        #PROMPT('&Values:',DROP('As the chart|Show them|Hide them')),%gbWS1Values,DEFAULT('As the chart')
      #ENDENABLE
    #ENDBOXED
    #ENABLE(%gbWNSeries>=2)
      #BOXED('Series 2')
        #PROMPT('N&ame:',@s32),%gbWS2Name,DEFAULT('Series 2')
        #PROMPT('A&utomatic color',CHECK),%gbWS2Auto,DEFAULT(1),AT(10)
        #ENABLE(%gbWS2Auto=0)
          #PROMPT('Co&lor:',COLOR),%gbWS2Color,DEFAULT(00A4A62CH)
        #ENDENABLE
        #ENABLE(%gbWNSeries>=2 AND (%gbWType='Column' OR %gbWType='Line' OR %gbWType='Scatter'))
          #PROMPT('D&raw as:',DROP('As the chart type|Bars|Line')),%gbWS2Plot,DEFAULT('As the chart type')
        #ENDENABLE
        #ENABLE(%gbWNSeries>=2)
          #PROMPT('V&alues:',DROP('As the chart|Show them|Hide them')),%gbWS2Values,DEFAULT('As the chart')
        #ENDENABLE
      #ENDBOXED
    #ENDENABLE
  #ENDTAB
  #TAB('Series &3-4')
    #ENABLE(%gbWNSeries>=3)
      #BOXED('Series 3')
        #PROMPT('Na&me:',@s32),%gbWS3Name,DEFAULT('Series 3')
        #PROMPT('Auto&matic color',CHECK),%gbWS3Auto,DEFAULT(1),AT(10)
        #ENABLE(%gbWS3Auto=0)
          #PROMPT('Col&or:',COLOR),%gbWS3Color,DEFAULT(003DA3E8H)
        #ENDENABLE
        #ENABLE(%gbWNSeries>=2 AND (%gbWType='Column' OR %gbWType='Line' OR %gbWType='Scatter'))
          #PROMPT('Dr&aw as:',DROP('As the chart type|Bars|Line')),%gbWS3Plot,DEFAULT('As the chart type')
        #ENDENABLE
        #ENABLE(%gbWNSeries>=2)
          #PROMPT('Va&lues:',DROP('As the chart|Show them|Hide them')),%gbWS3Values,DEFAULT('As the chart')
        #ENDENABLE
      #ENDBOXED
    #ENDENABLE
    #ENABLE(%gbWNSeries>=4)
      #BOXED('Series 4')
        #PROMPT('Nam&e:',@s32),%gbWS4Name,DEFAULT('Series 4')
        #PROMPT('Automati&c color',CHECK),%gbWS4Auto,DEFAULT(1),AT(10)
        #ENABLE(%gbWS4Auto=0)
          #PROMPT('Colo&r:',COLOR),%gbWS4Color,DEFAULT(00794E1FH)
        #ENDENABLE
        #ENABLE(%gbWNSeries>=2 AND (%gbWType='Column' OR %gbWType='Line' OR %gbWType='Scatter'))
          #PROMPT('Dra&w as:',DROP('As the chart type|Bars|Line')),%gbWS4Plot,DEFAULT('As the chart type')
        #ENDENABLE
        #ENABLE(%gbWNSeries>=2)
          #PROMPT('Val&ues:',DROP('As the chart|Show them|Hide them')),%gbWS4Values,DEFAULT('As the chart')
        #ENDENABLE
      #ENDBOXED
    #ENDENABLE
  #ENDTAB
  #TAB('&Data')
    #DISPLAY('One row per bar / point / slice, left to right. The value may be a')
    #DISPLAY('literal number OR any variable / field / expression - it is')
    #DISPLAY('re-read every time DO Refresh:<object> runs.')
    #DISPLAY('If the list is empty, sample data is drawn (self-test).')
    #BUTTON('Data'),MULTI(%gbWBar,%gbWBarLabel),INLINE
      #PROMPT('&Label:',@s32),%gbWBarLabel,DEFAULT('')
      #PROMPT('Value is a &variable / expression',CHECK),%gbWBarIsExpr,DEFAULT(0),AT(10)
      #ENABLE(%gbWBarIsExpr=0)
        #PROMPT('&Value:',@n13.2),%gbWBarValue,DEFAULT(0)
      #ENDENABLE
      #ENABLE(%gbWBarIsExpr=1)
        #PROMPT('Value &field / expression:',@s255),%gbWBarField,REQ,DEFAULT('')
      #ENDENABLE
      #ENABLE(%gbWNSeries>=2)
        #PROMPT('Series &2 value (number, field or expression):',@s255),%gbWBarV2,DEFAULT('0')
      #ENDENABLE
      #ENABLE(%gbWNSeries>=3)
        #PROMPT('Series &3 value (number, field or expression):',@s255),%gbWBarV3,DEFAULT('0')
      #ENDENABLE
      #ENABLE(%gbWNSeries>=4)
        #PROMPT('Series &4 value (number, field or expression):',@s255),%gbWBarV4,DEFAULT('0')
      #ENDENABLE
      #ENABLE(%gbWNSeries=1)
        #PROMPT('&Automatic color (professional palette)',CHECK),%gbWBarAutoColor,DEFAULT(1),AT(10)
        #ENABLE(%gbWBarAutoColor=0)
          #PROMPT('&Color:',COLOR),%gbWBarColor,DEFAULT(00B6752EH)
        #ENDENABLE
      #ENDENABLE
    #ENDBUTTON
  #ENDTAB
#ENDSHEET
#!-----------------------------------------------------------------------------
#AT(%DataSection),WHERE(%gbWDisable=0 AND %gbWImage)
%gbWObject           GraficaBarraClass                       ! one chart object for this instance
Redraw:%gbWObject    EQUATE(EVENT:User + 220 + %ActiveTemplateInstance) ! private "repaint" event (unique per chart)
#ENDAT
#!
#! PRIORITY(2000) puts this self-contained CASE EVENT() ABOVE the framework's own
#! LOOP/CASE scaffolding (registered at PRIORITY 2500) - same proven spot myGauge,
#! myQRDraw and myPixel use. Using 2500 collides and duplicates CASE EVENT().
#AT(%WindowManagerMethodCodeSection,'TakeWindowEvent','(),BYTE'),PRIORITY(2000),WHERE(%gbWDisable=0 AND %gbWImage)
  CASE EVENT()
  OF EVENT:OpenWindow
#INSERT(%gbWEmitConfig)
    POST(Redraw:%gbWObject)                                  ! first draw, after the window has opened
  OF EVENT:Sized
    POST(Redraw:%gbWObject)                                  ! redraw AFTER the resizer settles (fresh size)
  OF Redraw:%gbWObject
    DO Refresh:%gbWObject                                    ! reload the data, then draw it
  END
#ENDAT
#!
#!  Per-instance refresh ROUTINE: reload the data (re-evaluating any variable
#!  values) and redraw. Call it (e.g. DO Refresh:Graph1) after data changes.
#AT(%ProcedureRoutines),WHERE(%gbWDisable=0 AND %gbWImage)
Refresh:%gbWObject ROUTINE
#INSERT(%gbWEmitData)
    %gbWObject.Draw(%Window, %gbWImage)
#ENDAT
#!#############################################################################
#!  PROCEDURE EXTENSION - graficaBarraReport (REPORT)  -  vector primitives
#!#############################################################################
#!  Draws with BOX/LINE/POLYGON/ELLIPSE/PIE straight into the band under
#!  SETTARGET(Report) - the chart reaches the PDF as vector primitives, NOT a
#!  bitmap, so the file stays as small as possible. The placeholder control
#!  only supplies the position/size (GETPOSITION) and is hidden so it never
#!  prints itself.
#!#############################################################################
#EXTENSION(graficaBarraReport,'graficaBarra - Draw a chart on this REPORT'),PROCEDURE,MULTI,REQ(graficaBarraGlobal),DESCRIPTION('[' & %gbRType & '] ' & %gbRObject)
#SHEET
  #TAB('&General')
    #BOXED('Object &&  placeholder')
      #PROMPT('&Disable this chart',CHECK),%gbRDisable,DEFAULT(0),AT(10)
      #PROMPT('&Object name:',@s64),%gbRObject,REQ,DEFAULT('RptGraph' & %ActiveTemplateInstance)
      #! a report needs FROM(%ReportControl,...) (corpus: blobsrv.tpw:20)
      #PROMPT('&Placeholder control (in the band):',FROM(%ReportControl,%ReportControlType='IMAGE' OR %ReportControlType='BOX' OR %ReportControlType='REGION')),%gbRPlace,REQ,DEFAULT('')
      #! Graphics must be aimed at the BAND that holds the placeholder, or every
      #! chart on the report lands in whichever band happens to be printing.
      #! Blank = work it out from the report structure (indent level).
      #PROMPT('Ban&d to draw into (blank = the one holding the placeholder):',FROM(%ReportControl,%ReportControlType='DETAIL' OR %ReportControlType='HEADER' OR %ReportControlType='FOOTER' OR %ReportControlType='FORM')),%gbRBand,DEFAULT('')
      #PROMPT('&Hide the placeholder when printing',CHECK),%gbRHide,DEFAULT(1),AT(10)
      #! A band keeps every primitive ever drawn into it, so painting a second
      #! chart into the same placeholder lands ON TOP of the first unless the
      #! rectangle is wiped. ClearAll() only drops the data, never the ink.
      #PROMPT('&Erase the placeholder before drawing',CHECK),%gbRErase,DEFAULT(1),AT(10)
      #BOXED,WHERE(%gbRErase=0)
        #DISPLAY('Off: this chart draws on top of whatever is already in the band.')
      #ENDBOXED
      #PROMPT('&Title text:',@s64),%gbRTitle,DEFAULT('')
    #ENDBOXED
    #BOXED('Chart')
      #PROMPT('Chart &type:',DROP('Column|Bar (horizontal)|Stacked column|Stacked bar|Stacked percent|Line|Area|Stacked area|Scatter|Pie|Pie 3D|Donut|Radar')),%gbRType,DEFAULT('Column')
      #PROMPT('Number of &series:',SPIN(@n1,1,4,1)),%gbRNSeries,DEFAULT(1)
      #DISPLAY('The chart is redrawn for every band printed, so the values may')
      #DISPLAY('be fields from the record being printed or running totals.')
    #ENDBOXED
  #ENDTAB
  #TAB('Sca&le')
    #BOXED('Value scale')
      #PROMPT('&Automatic scale (nice round maximum from the data)',CHECK),%gbRAutoScale,DEFAULT(1),AT(10)
      #ENABLE(%gbRAutoScale=0)
        #PROMPT('&Minimum:',@n13.2),%gbRMin,DEFAULT(0)
        #PROMPT('Ma&ximum:',@n13.2),%gbRMax,DEFAULT(100)
      #ENDENABLE
    #ENDBOXED
    #BOXED('Text size on the report')
      #DISPLAY('The band has no font awareness, so the class assumes a 9pt font')
      #DISPLAY('on a THOUS report. Nudge these if your labels crowd or straggle.')
      #PROMPT('Character &width (0 = 62 thousandths):',SPIN(@n4,0,400,2)),%gbRTextW,DEFAULT(0)
      #PROMPT('Character h&eight (0 = 130 thousandths):',SPIN(@n4,0,400,5)),%gbRTextH,DEFAULT(0)
    #ENDBOXED
  #ENDTAB
  #TAB('&Look')
    #BOXED('Show')
      #PROMPT('Show &values',CHECK),%gbRShowValues,DEFAULT(1),AT(10)
      #PROMPT('Value &decimals:',SPIN(@n2,0,4,1)),%gbRValueDP,DEFAULT(0)
      #PROMPT('Values as a &percentage of the total',CHECK),%gbRPercent,DEFAULT(0),AT(10)
      #PROMPT('Show &labels',CHECK),%gbRShowLabels,DEFAULT(1),AT(10)
      #PROMPT('Show &scale (axis numbers)',CHECK),%gbRShowScale,DEFAULT(1),AT(10)
      #PROMPT('Scale d&ecimals:',SPIN(@n2,0,4,1)),%gbRScaleDP,DEFAULT(0)
      #PROMPT('Show &gridlines',CHECK),%gbRShowGrid,DEFAULT(1),AT(10)
      #PROMPT('Scale/grid di&visions:',SPIN(@n3,1,20,1)),%gbRGridDivs,DEFAULT(5)
      #PROMPT('Show the &axis and the zero line',CHECK),%gbRShowAxis,DEFAULT(1),AT(10)
    #ENDBOXED
    #BOXED('Legend')
      #PROMPT('Show a le&gend',CHECK),%gbRShowLegend,DEFAULT(1),AT(10)
      #ENABLE(%gbRShowLegend=1)
        #PROMPT('&Where:',DROP('Bottom|Right|Top')),%gbRLegendPos,DEFAULT('Bottom')
      #ENDENABLE
    #ENDBOXED
  #ENDTAB
  #TAB('Sha&pes')
    #BOXED('Bars, lines and markers')
      #PROMPT('Gap between bars (%% of a slot):',SPIN(@n3,0,90,5)),%gbRGapPct,DEFAULT(30)
      #PROMPT('Line &thickness:',SPIN(@n2,1,9,1)),%gbRLineWidth,DEFAULT(2)
      #PROMPT('S&mooth the line (rounded corners)',CHECK),%gbRSmooth,DEFAULT(0),AT(10)
      #PROMPT('Show mar&kers on lines and areas',CHECK),%gbRMarkers,DEFAULT(1),AT(10)
      #PROMPT('Marker s&hape:',DROP('Circle|Square|Diamond')),%gbRMarkerShape,DEFAULT('Circle')
      #PROMPT('Marker si&ze (0 = automatic):',SPIN(@n4,0,400,5)),%gbRMarkerSize,DEFAULT(0)
    #ENDBOXED
    #BOXED('Pie, Pie 3D, Donut')
      #PROMPT('First slice starts at (degrees clockwise):',SPIN(@n3,0,359,15)),%gbRStartAngle,DEFAULT(0)
      #PROMPT('3D depth (0 = automatic):',SPIN(@n4,0,900,10)),%gbRDepth3D,DEFAULT(0)
      #PROMPT('Donut hole (percent of the diameter):',SPIN(@n3,10,90,5)),%gbRDonutPct,DEFAULT(55)
      #PROMPT('Text in the middle of the donut:',@s32),%gbRDonutText,DEFAULT('')
    #ENDBOXED
  #ENDTAB
  #TAB('Te&xt && colors')
    #BOXED('Type')
      #DISPLAY('Blank / 0 = draw with whatever font the target is using.')
      #DISPLAY('A size also scales the layout, so labels keep their spacing.')
      #PROMPT('&Typeface (blank = the band''s):',@s32),%gbRFontName,DEFAULT('')
      #PROMPT('Si&ze (0 = the band''s):',SPIN(@n3,0,72,1)),%gbRFontSize,DEFAULT(0)
      #PROMPT('&Bold',CHECK),%gbRFontBold,DEFAULT(0),AT(10)
      #PROMPT('&Italic',CHECK),%gbRFontItalic,DEFAULT(0),AT(10)
    #ENDBOXED
    #BOXED('Colors')
      #PROMPT('Paint the &background',CHECK),%gbRUseBack,DEFAULT(0),AT(10)
      #ENABLE(%gbRUseBack=1)
        #PROMPT('Background &color:',COLOR),%gbRBackColor,DEFAULT(00FFFFFFH)
      #ENDENABLE
      #PROMPT('Paint the &plot area',CHECK),%gbRUsePlot,DEFAULT(0),AT(10)
      #ENABLE(%gbRUsePlot=1)
        #PROMPT('Plot area c&olor:',COLOR),%gbRPlotColor,DEFAULT(00FBFBFBH)
      #ENDENABLE
      #PROMPT('A&xis color:',COLOR),%gbRAxisColor,DEFAULT(002B2B2BH)
      #PROMPT('G&rid color:',COLOR),%gbRGridColor,DEFAULT(00E0E0E0H)
      #PROMPT('Te&xt color:',COLOR),%gbRTextColor,DEFAULT(002B2B2BH)
      #PROMPT('Outline the bars and slices',CHECK),%gbRUseBorder,DEFAULT(0),AT(10)
      #ENABLE(%gbRUseBorder=1)
        #PROMPT('Outline color:',COLOR),%gbRBorderColor,DEFAULT(00FFFFFFH)
      #ENDENABLE
    #ENDBOXED
  #ENDTAB
  #TAB('&Series 1-2')
    #DISPLAY('Only needed when "Number of series" on the General tab is 2 or more.')
    #DISPLAY('"Draw as" mixes shapes on the one chart - sales on Bars, the trend')
    #DISPLAY('on Line, over the same value axis. Column, Line and Scatter only.')
    #BOXED('Series 1')
      #PROMPT('&Name:',@s32),%gbRS1Name,DEFAULT('Series 1')
      #PROMPT('Automatic &color',CHECK),%gbRS1Auto,DEFAULT(1),AT(10)
      #ENABLE(%gbRS1Auto=0)
        #PROMPT('C&olor:',COLOR),%gbRS1Color,DEFAULT(00B6752EH)
      #ENDENABLE
      #ENABLE(%gbRNSeries>=2 AND (%gbRType='Column' OR %gbRType='Line' OR %gbRType='Scatter'))
        #PROMPT('&Draw as:',DROP('As the chart type|Bars|Line')),%gbRS1Plot,DEFAULT('As the chart type')
      #ENDENABLE
      #ENABLE(%gbRNSeries>=2)
        #PROMPT('&Values:',DROP('As the chart|Show them|Hide them')),%gbRS1Values,DEFAULT('As the chart')
      #ENDENABLE
    #ENDBOXED
    #ENABLE(%gbRNSeries>=2)
      #BOXED('Series 2')
        #PROMPT('N&ame:',@s32),%gbRS2Name,DEFAULT('Series 2')
        #PROMPT('A&utomatic color',CHECK),%gbRS2Auto,DEFAULT(1),AT(10)
        #ENABLE(%gbRS2Auto=0)
          #PROMPT('Co&lor:',COLOR),%gbRS2Color,DEFAULT(00A4A62CH)
        #ENDENABLE
        #ENABLE(%gbRNSeries>=2 AND (%gbRType='Column' OR %gbRType='Line' OR %gbRType='Scatter'))
          #PROMPT('D&raw as:',DROP('As the chart type|Bars|Line')),%gbRS2Plot,DEFAULT('As the chart type')
        #ENDENABLE
        #ENABLE(%gbRNSeries>=2)
          #PROMPT('V&alues:',DROP('As the chart|Show them|Hide them')),%gbRS2Values,DEFAULT('As the chart')
        #ENDENABLE
      #ENDBOXED
    #ENDENABLE
  #ENDTAB
  #TAB('Series &3-4')
    #ENABLE(%gbRNSeries>=3)
      #BOXED('Series 3')
        #PROMPT('Na&me:',@s32),%gbRS3Name,DEFAULT('Series 3')
        #PROMPT('Auto&matic color',CHECK),%gbRS3Auto,DEFAULT(1),AT(10)
        #ENABLE(%gbRS3Auto=0)
          #PROMPT('Col&or:',COLOR),%gbRS3Color,DEFAULT(003DA3E8H)
        #ENDENABLE
        #ENABLE(%gbRNSeries>=2 AND (%gbRType='Column' OR %gbRType='Line' OR %gbRType='Scatter'))
          #PROMPT('Dr&aw as:',DROP('As the chart type|Bars|Line')),%gbRS3Plot,DEFAULT('As the chart type')
        #ENDENABLE
        #ENABLE(%gbRNSeries>=2)
          #PROMPT('Va&lues:',DROP('As the chart|Show them|Hide them')),%gbRS3Values,DEFAULT('As the chart')
        #ENDENABLE
      #ENDBOXED
    #ENDENABLE
    #ENABLE(%gbRNSeries>=4)
      #BOXED('Series 4')
        #PROMPT('Nam&e:',@s32),%gbRS4Name,DEFAULT('Series 4')
        #PROMPT('Automati&c color',CHECK),%gbRS4Auto,DEFAULT(1),AT(10)
        #ENABLE(%gbRS4Auto=0)
          #PROMPT('Colo&r:',COLOR),%gbRS4Color,DEFAULT(00794E1FH)
        #ENDENABLE
        #ENABLE(%gbRNSeries>=2 AND (%gbRType='Column' OR %gbRType='Line' OR %gbRType='Scatter'))
          #PROMPT('Dra&w as:',DROP('As the chart type|Bars|Line')),%gbRS4Plot,DEFAULT('As the chart type')
        #ENDENABLE
        #ENABLE(%gbRNSeries>=2)
          #PROMPT('Val&ues:',DROP('As the chart|Show them|Hide them')),%gbRS4Values,DEFAULT('As the chart')
        #ENDENABLE
      #ENDBOXED
    #ENDENABLE
  #ENDTAB
  #TAB('&Data')
    #DISPLAY('One row per bar / point / slice. The value may be a literal number')
    #DISPLAY('OR any field / expression - it is evaluated for every band printed.')
    #DISPLAY('If the list is empty, sample data is drawn (self-test).')
    #BUTTON('Data'),MULTI(%gbRBar,%gbRBarLabel),INLINE
      #PROMPT('&Label:',@s32),%gbRBarLabel,DEFAULT('')
      #PROMPT('Value is a &variable / expression',CHECK),%gbRBarIsExpr,DEFAULT(1),AT(10)
      #ENABLE(%gbRBarIsExpr=0)
        #PROMPT('&Value:',@n13.2),%gbRBarValue,DEFAULT(0)
      #ENDENABLE
      #ENABLE(%gbRBarIsExpr=1)
        #PROMPT('Value &field / expression:',@s255),%gbRBarField,REQ,DEFAULT('')
      #ENDENABLE
      #ENABLE(%gbRNSeries>=2)
        #PROMPT('Series &2 value (number, field or expression):',@s255),%gbRBarV2,DEFAULT('0')
      #ENDENABLE
      #ENABLE(%gbRNSeries>=3)
        #PROMPT('Series &3 value (number, field or expression):',@s255),%gbRBarV3,DEFAULT('0')
      #ENDENABLE
      #ENABLE(%gbRNSeries>=4)
        #PROMPT('Series &4 value (number, field or expression):',@s255),%gbRBarV4,DEFAULT('0')
      #ENDENABLE
      #ENABLE(%gbRNSeries=1)
        #PROMPT('&Automatic color (professional palette)',CHECK),%gbRBarAutoColor,DEFAULT(1),AT(10)
        #ENABLE(%gbRBarAutoColor=0)
          #PROMPT('&Color:',COLOR),%gbRBarColor,DEFAULT(00B6752EH)
        #ENDENABLE
      #ENDENABLE
    #ENDBUTTON
  #ENDTAB
#ENDSHEET
#!-----------------------------------------------------------------------------
#AT(%DataSection),WHERE(%gbRDisable=0 AND %gbRPlace)
%gbRObject           GraficaBarraClass
#ENDAT
#!
#AT(%BeforePrint),WHERE(%gbRDisable=0 AND %gbRPlace)
#INSERT(%gbREmitAll)
#ENDAT
#!
#!  REPORT: settings + data, emitted together at %BeforePrint so the chart is
#!  rebuilt from the record being printed for every band.
#GROUP(%gbREmitAll)
#DECLARE(%TypeEq)
#DECLARE(%LegendEq)
#DECLARE(%MarkerEq)
#DECLARE(%Args)
#DECLARE(%Band)
#INSERT(%gbSetEquates,%gbRType,%gbRLegendPos,%gbRMarkerShape,%TypeEq,%LegendEq,%MarkerEq)
  %gbRObject.ChartType = %TypeEq
  %gbRObject.Title = '%gbRTitle'
  %gbRObject.ShowValues = %gbRShowValues
  %gbRObject.ValueDP = %gbRValueDP
  %gbRObject.Percent = %gbRPercent
  %gbRObject.ShowLabels = %gbRShowLabels
  %gbRObject.ShowScale = %gbRShowScale
  %gbRObject.ScaleDP = %gbRScaleDP
  %gbRObject.ShowGrid = %gbRShowGrid
  %gbRObject.GridDivs = %gbRGridDivs
  %gbRObject.ShowAxis = %gbRShowAxis
  %gbRObject.ShowLegend = %gbRShowLegend
  %gbRObject.LegendPos = %LegendEq
  %gbRObject.BarGapPct = %gbRGapPct
  %gbRObject.LineWidth = %gbRLineWidth
  %gbRObject.Smooth = %gbRSmooth
  %gbRObject.ShowMarkers = %gbRMarkers
  %gbRObject.MarkerShape = %MarkerEq
  %gbRObject.MarkerSize = %gbRMarkerSize
  %gbRObject.StartAngle = %gbRStartAngle
  %gbRObject.Depth3D = %gbRDepth3D
  %gbRObject.DonutPct = %gbRDonutPct
  %gbRObject.DonutText = '%gbRDonutText'
  %gbRObject.TextW = %gbRTextW
  %gbRObject.TextH = %gbRTextH
  %gbRObject.EraseFirst = %gbRErase                          ! 1 = wipe the placeholder's rectangle first
#IF(%gbRUseBack)
  %gbRObject.BackColor = %gbRBackColor
#ENDIF
#IF(%gbRUsePlot)
  %gbRObject.PlotColor = %gbRPlotColor
#ENDIF
  %gbRObject.AxisColor = %gbRAxisColor
  %gbRObject.GridColor = %gbRGridColor
  %gbRObject.TextColor = %gbRTextColor
#INSERT(%gbEmitFont,%gbRObject,%gbRFontName,%gbRFontSize,%gbRFontBold,%gbRFontItalic)
#IF(%gbRUseBorder)
  %gbRObject.BarBorderColor = %gbRBorderColor
#ENDIF
#IF(%gbRAutoScale=0)
  %gbRObject.SetRange(%gbRMin, %gbRMax)
#ENDIF
  %gbRObject.ClearAll()
#IF(ITEMS(%gbRBar)=0)
  %gbRObject.Demo()                                          ! no data defined - sample data (self-test)
#ELSIF(%gbRNSeries>1)
#IF(%gbRS1Auto=0)
  %gbRObject.AddSeries('%gbRS1Name', %gbRS1Color)
#ELSE
  %gbRObject.AddSeries('%gbRS1Name')
#ENDIF
#IF(%gbRS2Auto=0)
  %gbRObject.AddSeries('%gbRS2Name', %gbRS2Color)
#ELSE
  %gbRObject.AddSeries('%gbRS2Name')
#ENDIF
#IF(%gbRNSeries>=3)
#IF(%gbRS3Auto=0)
  %gbRObject.AddSeries('%gbRS3Name', %gbRS3Color)
#ELSE
  %gbRObject.AddSeries('%gbRS3Name')
#ENDIF
#ENDIF
#IF(%gbRNSeries>=4)
#IF(%gbRS4Auto=0)
  %gbRObject.AddSeries('%gbRS4Name', %gbRS4Color)
#ELSE
  %gbRObject.AddSeries('%gbRS4Name')
#ENDIF
#ENDIF
#INSERT(%gbEmitPlot,%gbRObject,1,%gbRS1Plot)
#INSERT(%gbEmitValues,%gbRObject,1,%gbRS1Values)
#INSERT(%gbEmitPlot,%gbRObject,2,%gbRS2Plot)
#INSERT(%gbEmitValues,%gbRObject,2,%gbRS2Values)
#IF(%gbRNSeries>=3)
#INSERT(%gbEmitPlot,%gbRObject,3,%gbRS3Plot)
#INSERT(%gbEmitValues,%gbRObject,3,%gbRS3Values)
#ENDIF
#IF(%gbRNSeries>=4)
#INSERT(%gbEmitPlot,%gbRObject,4,%gbRS4Plot)
#INSERT(%gbEmitValues,%gbRObject,4,%gbRS4Values)
#ENDIF
#FOR(%gbRBar)
#INSERT(%gbSetValueArgs,%gbRBarIsExpr,%gbRBarValue,%gbRBarField,%gbRNSeries,%gbRBarV2,%gbRBarV3,%gbRBarV4,%Args)
#IF(%Args)
  %gbRObject.AddCat('%gbRBarLabel', %Args)
#ENDIF
#ENDFOR
#ELSE
#FOR(%gbRBar)
#INSERT(%gbSetValueArgs,%gbRBarIsExpr,%gbRBarValue,%gbRBarField,1,'','','',%Args)
#IF(%Args)
#IF(%gbRBarAutoColor)
  %gbRObject.AddBar('%gbRBarLabel', %Args)
#ELSE
  %gbRObject.AddBar('%gbRBarLabel', %Args, %gbRBarColor)
#ENDIF
#ENDIF
#ENDFOR
#ENDIF
#IF(%gbRBand)
#SET(%Band,%gbRBand)
#ELSE
#INSERT(%gbRFindBand,%gbRPlace,%Band)
#ENDIF
#!  Aim at the band holding the placeholder, so several charts on one report
#!  each land in their own band instead of all piling into whichever band is
#!  printing at the time.
#IF(%Band)
  SETTARGET(%Report, %Band)
#ELSE
  ! graficaBarra: the band holding %gbRPlace has no field equate, so this chart
  ! cannot be aimed at it. That is fine for ONE chart on the report; if you have
  ! more than one they will all pile into whichever band is printing. Fix: give
  ! the band a USE(?SomeName) in the report formatter, or name it in the
  ! "Band to draw into" prompt.
  SETTARGET(%Report)
#ENDIF
  %gbRObject.Paint(%gbRPlace)                                ! vector primitives into the band
#IF(%gbRHide)
  %gbRPlace{PROP:Hide} = 1                                   ! placeholder only supplied the rectangle - never prints
#ENDIF
  SETTARGET()
#!#############################################################################
#!  GROUPS - shared code emitters
#!#############################################################################
#!  Turn the three DROP prompts into Clarion EQUATE names, once, so the
#!  generated source reads Chart:Donut rather than 11.
#GROUP(%gbSetEquates,%pType,%pLegend,%pMarker,*%pTypeEq,*%pLegendEq,*%pMarkerEq)
#CASE(%pType)
#OF('Bar (horizontal)')
  #SET(%pTypeEq,'Chart:Bar')
#OF('Stacked column')
  #SET(%pTypeEq,'Chart:StackedCol')
#OF('Stacked bar')
  #SET(%pTypeEq,'Chart:StackedBar')
#OF('Stacked percent')
  #SET(%pTypeEq,'Chart:Stacked100')
#OF('Line')
  #SET(%pTypeEq,'Chart:Line')
#OF('Area')
  #SET(%pTypeEq,'Chart:Area')
#OF('Stacked area')
  #SET(%pTypeEq,'Chart:StackedArea')
#OF('Scatter')
  #SET(%pTypeEq,'Chart:Scatter')
#OF('Pie')
  #SET(%pTypeEq,'Chart:Pie')
#OF('Pie 3D')
  #SET(%pTypeEq,'Chart:Pie3D')
#OF('Donut')
  #SET(%pTypeEq,'Chart:Donut')
#OF('Radar')
  #SET(%pTypeEq,'Chart:Radar')
#ELSE
  #SET(%pTypeEq,'Chart:Column')
#ENDCASE
#CASE(%pLegend)
#OF('Right')
  #SET(%pLegendEq,'Legend:Right')
#OF('Top')
  #SET(%pLegendEq,'Legend:Top')
#ELSE
  #SET(%pLegendEq,'Legend:Bottom')
#ENDCASE
#CASE(%pMarker)
#OF('Square')
  #SET(%pMarkerEq,'Marker:Square')
#OF('Diamond')
  #SET(%pMarkerEq,'Marker:Diamond')
#ELSE
  #SET(%pMarkerEq,'Marker:Circle')
#ENDCASE
#!
#!  Which band is the placeholder in? Report controls come out of
#!  %ReportControl in declaration order with %ReportControlIndent giving the
#!  nesting depth, so a control's band is simply the nearest thing DECLARED
#!  BEFORE IT AT A SHALLOWER INDENT. That is structural - it works for a
#!  DETAIL, a group HEADER or FOOTER, a FORM, or anything nested inside a
#!  BREAK, without having to know what the band types are called.
#!  Comes back blank if that band has no field equate of its own; the caller
#!  then falls back to a plain SETTARGET(report), which is v1 behaviour.
#GROUP(%gbRFindBand,%pCtl,*%pBand)
#DECLARE(%Ind)
#DECLARE(%Seen)
#SET(%pBand,'')
#SET(%Ind,0)
#FOR(%ReportControl)                   #! pass 1: how deep is the placeholder?
#IF(%ReportControl = %pCtl)
#SET(%Ind,%ReportControlIndent)
#BREAK
#ENDIF
#ENDFOR
#IF(%Ind < 1)
#RETURN
#ENDIF
#SET(%Seen,'')
#FOR(%ReportControl)                   #! pass 2: the last shallower thing before it
#IF(%ReportControl = %pCtl)
#SET(%pBand,%Seen)
#BREAK
#ENDIF
#IF(%ReportControlIndent < %Ind)
#SET(%Seen,%ReportControl)
#ENDIF
#ENDFOR
#!
#!  Build the value argument list for one data row into %Args. Series 1 is
#!  either the literal or the expression (as in v1); series 2..4 are always
#!  free text, so a number and a field name both work. %Args comes back
#!  empty when the row has nothing usable in it - the caller then skips it.
#!
#!  One series' shape, for a combo: bars for sales, a line for the trend.
#!  Nothing is emitted for 'As the chart type', so an application generated
#!  before this prompt existed generates exactly the code it did before.
#!  The indent is two literal spaces rather than a parameter: a value that
#!  opened the line would put the object name in column 1 if it ever came
#!  through empty, and column 1 is where Clarion reads a LABEL.
#!  The chart's own type. Nothing is emitted for blank / 0, so a chart that
#!  says nothing keeps drawing with the target's font exactly as before.
#GROUP(%gbEmitFont,%pObject,%pName,%pSize,%pBold,%pItalic)
#IF(%pName)
  %pObject.FontName = '%pName'
#ENDIF
#IF(%pSize)
  %pObject.FontSize = %pSize
#ENDIF
#IF(%pBold AND %pItalic)
  %pObject.FontStyle = FONT:bold + FONT:italic
#ELSIF(%pBold)
  %pObject.FontStyle = FONT:bold
#ELSIF(%pItalic)
  %pObject.FontStyle = FONT:regular + FONT:italic
#ENDIF
#!
#!  Whether ONE series prints its numbers. Nothing for 'As the chart', so a
#!  chart that says nothing keeps following ShowValues as it always did.
#GROUP(%gbEmitValues,%pObject,%pSeries,%pShow)
#IF(%pShow = 'Show them')
  %pObject.SetSeriesNumbers(%pSeries, Values:On)
#ELSIF(%pShow = 'Hide them')
  %pObject.SetSeriesNumbers(%pSeries, Values:Off)
#ENDIF
#!
#GROUP(%gbEmitPlot,%pObject,%pSeries,%pPlot)
#IF(%pPlot = 'Bars')
  %pObject.SetSeriesPlot(%pSeries, Plot:Bar)
#ELSIF(%pPlot = 'Line')
  %pObject.SetSeriesPlot(%pSeries, Plot:Line)
#ENDIF
#!
#GROUP(%gbSetValueArgs,%pIsExpr,%pValue,%pField,%pNSeries,%pV2,%pV3,%pV4,*%pArgs)
#IF(%pIsExpr)
#SET(%pArgs,CLIP(%pField))
#ELSE
#SET(%pArgs,%pValue)
#ENDIF
#IF(%pArgs='')
#RETURN
#ENDIF
#!  A blank series value means "nothing here" - pass a zero, never an empty
#!  argument (Obj.AddCat('X', 1, ) would not compile).
#IF(%pNSeries>=2)
#IF(CLIP(%pV2)='')
#SET(%pArgs,%pArgs & ', 0')
#ELSE
#SET(%pArgs,%pArgs & ', ' & CLIP(%pV2))
#ENDIF
#ENDIF
#IF(%pNSeries>=3)
#IF(CLIP(%pV3)='')
#SET(%pArgs,%pArgs & ', 0')
#ELSE
#SET(%pArgs,%pArgs & ', ' & CLIP(%pV3))
#ENDIF
#ENDIF
#IF(%pNSeries>=4)
#IF(CLIP(%pV4)='')
#SET(%pArgs,%pArgs & ', 0')
#ELSE
#SET(%pArgs,%pArgs & ', ' & CLIP(%pV4))
#ENDIF
#ENDIF
#!
#!  WINDOW: everything that only has to be set once, when the window opens.
#GROUP(%gbWEmitConfig)
#DECLARE(%TypeEq)
#DECLARE(%LegendEq)
#DECLARE(%MarkerEq)
#INSERT(%gbSetEquates,%gbWType,%gbWLegendPos,%gbWMarkerShape,%TypeEq,%LegendEq,%MarkerEq)
    %gbWObject.ChartType = %TypeEq
    %gbWObject.Title = '%gbWTitle'
    %gbWObject.ShowValues = %gbWShowValues
    %gbWObject.ValueDP = %gbWValueDP
    %gbWObject.Percent = %gbWPercent
    %gbWObject.ShowLabels = %gbWShowLabels
    %gbWObject.ShowScale = %gbWShowScale
    %gbWObject.ScaleDP = %gbWScaleDP
    %gbWObject.ShowGrid = %gbWShowGrid
    %gbWObject.GridDivs = %gbWGridDivs
    %gbWObject.ShowAxis = %gbWShowAxis
    %gbWObject.ShowLegend = %gbWShowLegend
    %gbWObject.LegendPos = %LegendEq
    %gbWObject.BarGapPct = %gbWGapPct
    %gbWObject.LineWidth = %gbWLineWidth
    %gbWObject.Smooth = %gbWSmooth
    %gbWObject.ShowMarkers = %gbWMarkers
    %gbWObject.MarkerShape = %MarkerEq
    %gbWObject.MarkerSize = %gbWMarkerSize
    %gbWObject.StartAngle = %gbWStartAngle
    %gbWObject.Depth3D = %gbWDepth3D
    %gbWObject.DonutPct = %gbWDonutPct
    %gbWObject.DonutText = '%gbWDonutText'
#IF(%gbWUseBack)
    %gbWObject.BackColor = %gbWBackColor
#ENDIF
#IF(%gbWUsePlot)
    %gbWObject.PlotColor = %gbWPlotColor
#ENDIF
    %gbWObject.AxisColor = %gbWAxisColor
    %gbWObject.GridColor = %gbWGridColor
    %gbWObject.TextColor = %gbWTextColor
#INSERT(%gbEmitFont,%gbWObject,%gbWFontName,%gbWFontSize,%gbWFontBold,%gbWFontItalic)
#IF(%gbWUseBorder)
    %gbWObject.BarBorderColor = %gbWBorderColor
#ENDIF
#IF(%gbWAutoScale=0)
    %gbWObject.SetRange(%gbWMin, %gbWMax)
#ENDIF
#!
#!  WINDOW: the data. Emitted twice - at OpenWindow and in Refresh:<object> -
#!  so any variable / expression value is re-read on every refresh.
#GROUP(%gbWEmitData)
#DECLARE(%Args)
    %gbWObject.ClearAll()
#IF(ITEMS(%gbWBar)=0)
    %gbWObject.Demo()                                        ! no data defined - sample data (self-test)
#ELSIF(%gbWNSeries>1)
#IF(%gbWS1Auto=0)
    %gbWObject.AddSeries('%gbWS1Name', %gbWS1Color)
#ELSE
    %gbWObject.AddSeries('%gbWS1Name')
#ENDIF
#IF(%gbWS2Auto=0)
    %gbWObject.AddSeries('%gbWS2Name', %gbWS2Color)
#ELSE
    %gbWObject.AddSeries('%gbWS2Name')
#ENDIF
#IF(%gbWNSeries>=3)
#IF(%gbWS3Auto=0)
    %gbWObject.AddSeries('%gbWS3Name', %gbWS3Color)
#ELSE
    %gbWObject.AddSeries('%gbWS3Name')
#ENDIF
#ENDIF
#IF(%gbWNSeries>=4)
#IF(%gbWS4Auto=0)
    %gbWObject.AddSeries('%gbWS4Name', %gbWS4Color)
#ELSE
    %gbWObject.AddSeries('%gbWS4Name')
#ENDIF
#ENDIF
#INSERT(%gbEmitPlot,%gbWObject,1,%gbWS1Plot)
#INSERT(%gbEmitValues,%gbWObject,1,%gbWS1Values)
#INSERT(%gbEmitPlot,%gbWObject,2,%gbWS2Plot)
#INSERT(%gbEmitValues,%gbWObject,2,%gbWS2Values)
#IF(%gbWNSeries>=3)
#INSERT(%gbEmitPlot,%gbWObject,3,%gbWS3Plot)
#INSERT(%gbEmitValues,%gbWObject,3,%gbWS3Values)
#ENDIF
#IF(%gbWNSeries>=4)
#INSERT(%gbEmitPlot,%gbWObject,4,%gbWS4Plot)
#INSERT(%gbEmitValues,%gbWObject,4,%gbWS4Values)
#ENDIF
#FOR(%gbWBar)
#INSERT(%gbSetValueArgs,%gbWBarIsExpr,%gbWBarValue,%gbWBarField,%gbWNSeries,%gbWBarV2,%gbWBarV3,%gbWBarV4,%Args)
#IF(%Args)
    %gbWObject.AddCat('%gbWBarLabel', %Args)
#ENDIF
#ENDFOR
#ELSE
#FOR(%gbWBar)
#INSERT(%gbSetValueArgs,%gbWBarIsExpr,%gbWBarValue,%gbWBarField,1,'','','',%Args)
#IF(%Args)
#IF(%gbWBarAutoColor)
    %gbWObject.AddBar('%gbWBarLabel', %Args)
#ELSE
    %gbWObject.AddBar('%gbWBarLabel', %Args, %gbWBarColor)
#ENDIF
#ENDIF
#ENDFOR
#ENDIF
#!-----------------------------------------------------------------------------
#! End of graficaBarra template set
#!-----------------------------------------------------------------------------
