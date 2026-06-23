#TEMPLATE(myQRDraw,'myQRDraw - Draw a QR Code into a Window (offline, no internet) - v1.1'),FAMILY('ABC')
#!-----------------------------------------------------------------------------
#!  myQRDraw template set  -  OFFLINE QR codes drawn with BOX primitives.
#!
#!  Unlike templates/myQR (which fetches a PNG from api.qrserver.com via curl),
#!  this set ENCODES the QR symbol itself at run time and draws every module as
#!  a filled BOX into an IMAGE control - exactly like myPie draws a pie. No
#!  internet, no curl, no temp files.
#!
#!  myQRDrawGlobal (APPLICATION extension) - INCLUDEs the encoder CLASS
#!               (QRCodeClass, byte mode, versions 1-10, ECC L/M/Q/H, automatic
#!               version + mask) and declares one global instance, QRCodeObj.
#!               The encoder lives in QRCodeClass.inc / QRCodeClass.clw so it
#!               compiles in its own module - it does NOT fill the program's
#!               global procedure area. Add once, globally.
#!
#!  REQUIRED FILES: copy QRCodeClass.inc AND QRCodeClass.clw (shipped beside this
#!               .tpl) to a folder on the Clarion redirection path - the app
#!               folder or \clarion12\libsrc\win. Store them in ANSI (not UTF-8).
#!
#!  SINGLE-EXE *and* MULTI-DLL: the global extension declares the QRCodeObj
#!               instance correctly for the current target using ABC's standard
#!               %DefaultExternal / %ProgramExtension / %DefaultExport symbols -
#!               defined in a single-EXE or the root DLL, EXTERNAL (imported) in
#!               other DLLs/EXEs, and exported from the root DLL. The class is
#!               non-VIRTUAL with an unconditional LINK, so each target links its
#!               own copy of the methods and only the instance is shared/exported.
#!
#!  myQRDraw     (PROCEDURE extension) - dropped on a WINDOW. Encodes a value
#!               (literal or code-driven) and draws it into a chosen IMAGE
#!               control, redrawing on OpenWindow / resize. Exposes a
#!               myQRDrawRepaint ROUTINE so you can change the value at run time.
#!
#!  myQRDrawReport (PROCEDURE extension) - dropped on a REPORT. Draws the code
#!               into an IMAGE control in a band as each record prints. Reports
#!               do NOT use window events: drawing happens in the Before-Print
#!               embed with SETTARGET(Report) (the band's own target), not on
#!               OpenWindow. Use THIS extension on reports, myQRDraw on windows.
#!
#!  This is a line-for-line port of the C# reference encoder in
#!  designer/QrCodeCore (validated by decoding with ZXing). Its module output
#!  is pinned by GoldenMatrixTests: "HELLO WORLD" at ECC M -> the 21x21 symbol
#!  the Self-test option draws, so a phone scan that reads "HELLO WORLD" proves
#!  this port matches the tested encoder.
#!
#!  VERIFIED corpus facts (shared with myPie):
#!    BOX(x,y,w,h,fill)                      builtins.clw:467   - dialog units
#!    SETTARGET(window,?image)                                   - draw into IMAGE
#!    GETPOSITION(?image,x,y)                                    - control X,Y in window
#!    SETPENCOLOR(color) / BLANK / SETTARGET()
#!  Bit ops: BSHIFT(v,n) (+left/-right), BAND, BOR, BXOR.  Integer truncation:
#!  Clarion ROUNDS on assignment, so every truncating divide uses INT(); modulus
#!  is SELF.Modulo() (= a - INT(a/b)*b) so NO literal '%' appears in the code.
#!
#!  Issue #5 (myPie): SETTARGET(,?image) is WINDOW-relative, so we GETPOSITION
#!  the image and draw at its X,Y.
#!-----------------------------------------------------------------------------
#!#############################################################################
#!  GLOBAL EXTENSION - myQRDrawGlobal
#!#############################################################################
#EXTENSION(myQRDrawGlobal,'myQRDraw - Global Encoder + Helper (add once per application)'),APPLICATION
#SHEET
  #TAB('&General')
    #BOXED('myQRDraw')
      #DISPLAY('myQRDraw Global Encoder + Helper - Version 1.1')
      #DISPLAY('Includes the QRCodeClass encoder (external .inc/.clw) and')
      #DISPLAY('declares one instance, QRCodeObj. No internet / curl needed.')
      #DISPLAY('Add once at the Application (global) level. IMPORTANT: copy')
      #DISPLAY('QRCodeClass.inc + QRCodeClass.clw to the redirection path.')
    #ENDBOXED
    #BOXED('Options')
      #PROMPT('&Disable this template',CHECK),%myQRDrawDisable,DEFAULT(0),AT(10)
    #ENDBOXED
  #ENDTAB
#ENDSHEET
#!-----------------------------------------------------------------------------
#! The encoder is a CLASS in QRCodeClass.inc / QRCodeClass.clw, so its code
#! compiles in its OWN module (not the program's global procedure area) and its
#! working data lives in the class instance. INCLUDE the header, then declare one
#! global instance; the class's LINK attribute pulls QRCodeClass.CLW into the build.
#!
#! IMPORTANT: copy QRCodeClass.inc AND QRCodeClass.clw to a folder on the Clarion
#! redirection path (the app folder, or \clarion12\libsrc\win). They are ANSI.
#!-----------------------------------------------------------------------------
#AT(%AfterGlobalIncludes),WHERE(%myQRDrawDisable=0)
INCLUDE('QRCodeClass.INC'),ONCE
#ENDAT
#!
#! The encoder instance is GLOBAL DATA, so it must be multi-DLL aware (ABC's
#! %DefaultExternal / %DefaultExport / %ProgramExtension symbols - no extra
#! prompts): DEFINED in a single-EXE or the root DLL, declared EXTERNAL (imported)
#! in every other DLL/EXE that uses it, and EXPORTED from the root DLL so those
#! imports resolve. The class methods are non-VIRTUAL and the CLASS carries an
#! unconditional LINK, so each target links its own copy of QRCodeClass.CLW - the
#! methods never need exporting, only the shared instance does. (Pattern: the
#! shipped cleansdw.tpw / ABOOP.tpw multi-DLL global-data handling.)
#AT(%GlobalData),WHERE(%myQRDrawDisable=0)
  #IF(%DefaultExternal = 'None External')
QRCodeObj  QRCodeClass                                       ! defined here (single-EXE or the root DLL)
  #ELSE
QRCodeObj  QRCodeClass,EXTERNAL,DLL(dll_mode)                ! imported from the root DLL
  #ENDIF
#ENDAT
#!
#AT(%DLLExportList),WHERE(%myQRDrawDisable=0)
  #IF(%DefaultExternal = 'None External' AND %ProgramExtension='DLL' AND %DefaultExport)
$QRCodeObj  @?                                               ! export the shared instance from the root DLL
  #ENDIF
#ENDAT
#!#############################################################################
#!  PROCEDURE EXTENSION - myQRDraw
#!#############################################################################
#EXTENSION(myQRDraw,'myQRDraw - Draw a QR Code on this window'),PROCEDURE,REQ(myQRDrawGlobal)
#SHEET
  #TAB('&General')
    #BOXED('Options')
      #PROMPT('&Disable this template',CHECK),%myQRDrawDisableThis,DEFAULT(0),AT(10)
      #PROMPT('&Image control to draw into:',CONTROL),%myQRDrawImage,REQ
      #PROMPT('&Value:',@s255),%myQRDrawValue,DEFAULT('https://www.softvelocity.com')
      #PROMPT('Value is a &variable / expression (not literal text)',CHECK),%myQRDrawValueIsVar,DEFAULT(0),AT(10)
      #PROMPT('&Error correction level:',DROP('L - Low (most data)[1]|M - Medium[2]|Q - Quartile[3]|H - High (most robust)[4]')),%myQRDrawEcc,DEFAULT('2')
      #PROMPT('&Dark (foreground) color:',COLOR),%myQRDrawDark,DEFAULT(00000000H)
      #PROMPT('&Light (background) color:',COLOR),%myQRDrawLight,DEFAULT(00FFFFFFH)
      #PROMPT('&Quiet-zone modules (border):',SPIN(@n1,0,8,1)),%myQRDrawQuiet,DEFAULT(4)
      #PROMPT('Draw &self-test ("HELLO WORLD", ECC M)',CHECK),%myQRDrawSelfTest,DEFAULT(0),AT(10)
    #ENDBOXED
  #ENDTAB
  #TAB('&Instructions')
    #BOXED('How to use myQRDraw')
      #DISPLAY('1. Add the global "myQRDraw - Global Encoder + Helper"')
      #DISPLAY('   extension once at the Application level.')
      #DISPLAY('2. Add an IMAGE control to the window (an Image - a Region')
      #DISPLAY('   will not receive the drawing). Make it square-ish.')
      #DISPLAY('3. On the General tab, select that control in "Image control')
      #DISPLAY('   to draw into".')
      #DISPLAY('4. Type the Value. Leave "Value is a variable" UNticked for')
      #DISPLAY('   literal text (e.g. a URL); tick it to use a Clarion')
      #DISPLAY('   variable/expression (e.g. CUS:WebSite) drawn at run time.')
      #DISPLAY('   NOTE: if the literal text contains an apostrophe ('') use')
      #DISPLAY('   the "variable" path instead, or it will break the source.')
      #DISPLAY('5. Pick the ECC level, the Dark/Light colors and the')
      #DISPLAY('   quiet-zone width. Higher ECC = more robust, less capacity.')
      #DISPLAY('6. For a resizable window, set the Image to resize/anchor so')
      #DISPLAY('   the code follows the window.')
      #DISPLAY('7. Generate, compile, run - then scan with a phone.')
      #DISPLAY('')
      #DISPLAY('Self-test: tick it to draw "HELLO WORLD" at ECC M (a fixed')
      #DISPLAY('21x21 symbol). Scanning it must read "HELLO WORLD" - this')
      #DISPLAY('proves the offline encoder works on your machine.')
    #ENDBOXED
  #ENDTAB
  #TAB('&Runtime')
    #BOXED('Changing the value at run time')
      #DISPLAY('Tick "Value is a variable" and name a variable. Change it,')
      #DISPLAY('then repaint:')
      #DISPLAY('   MyWebVar = ''https://newsite.example''')
      #DISPLAY('   DO myQRDrawRepaint')
      #DISPLAY('The code re-encodes and redraws automatically.')
    #ENDBOXED
  #ENDTAB
#ENDSHEET
#!-----------------------------------------------------------------------------
#! Local data + repaint routine + the draw handler (mirrors myPie's pattern).
#!-----------------------------------------------------------------------------
#AT(%DataSection),WHERE(%myQRDrawDisableThis=0 AND %myQRDrawImage)
myQRDraw:Redraw      EQUATE(EVENT:User+114)                  ! private "repaint" event
myQRDraw:Value       CSTRING(512)                            ! the value to encode (headroom for version-10 capacity)
#ENDAT
#!
#AT(%ProcedureRoutines),WHERE(%myQRDrawDisableThis=0 AND %myQRDrawImage)
myQRDrawRepaint ROUTINE
  POST(myQRDraw:Redraw)
#ENDAT
#!
#AT(%WindowManagerMethodCodeSection,'TakeWindowEvent','(),BYTE'),PRIORITY(2000),WHERE(%myQRDrawDisableThis=0 AND %myQRDrawImage)
  CASE EVENT()
  OF EVENT:OpenWindow
    POST(myQRDraw:Redraw)                                     ! first draw, after the window opens
  OF EVENT:Sized
    POST(myQRDraw:Redraw)                                     ! redraw after the resize settles
  OF myQRDraw:Redraw
#IF(%myQRDrawSelfTest)
    myQRDraw:Value = 'HELLO WORLD'                            ! fixed, known-good 21x21 symbol
    QRCodeObj.Draw(%myQRDrawImage, myQRDraw:Value, 2, %myQRDrawDark, %myQRDrawLight, %myQRDrawQuiet)
#ELSE
#IF(%myQRDrawValueIsVar)
    myQRDraw:Value = %myQRDrawValue                           ! code-driven value
#ELSE
    myQRDraw:Value = '%myQRDrawValue'                         ! literal text
#ENDIF
    QRCodeObj.Draw(%myQRDrawImage, myQRDraw:Value, %myQRDrawEcc, %myQRDrawDark, %myQRDrawLight, %myQRDrawQuiet)
#ENDIF
  END
#ENDAT
#!#############################################################################
#!  PROCEDURE EXTENSION - myQRDrawReport  (for REPORT procedures)
#!#############################################################################
#!  Reports render bands through the print engine, not a window event loop, so
#!  this draws in the %BeforePrint embed (fires before each DETAIL band prints)
#!  with SETTARGET(%Report) - the report itself is the draw target, and the
#!  band/page is current. Put an IMAGE control in the band where you want the
#!  code (give it a USE/field-equate so GETPOSITION can find it). A code is
#!  drawn per printed record - point Value at a per-record field (literal or
#!  variable) for one-QR-per-row, e.g. an order/customer URL.
#!#############################################################################
#EXTENSION(myQRDrawReport,'myQRDraw - Draw a QR Code on this REPORT'),PROCEDURE,REQ(myQRDrawGlobal)
#SHEET
  #TAB('&General')
    #BOXED('Options')
      #PROMPT('&Disable this template',CHECK),%myQRDrawRptDisable,DEFAULT(0),AT(10)
      #! CONTROL lists WINDOW controls only; a report proc also has a progress window, so we must list
      #! the REPORT's controls instead - FROM(%ReportControl,...) (corpus: blobsrv.tpw:20). Yields the
      #! ?-prefixed field equate, same as a window CONTROL prompt, usable in GETPOSITION after SETTARGET(Report).
      #PROMPT('&Image control (in a report band) to draw into:',FROM(%ReportControl,%ReportControlType = 'IMAGE')),%myQRDrawRptImage,REQ,DEFAULT('')
      #PROMPT('&Value:',@s255),%myQRDrawRptValue,DEFAULT('https://www.softvelocity.com')
      #PROMPT('Value is a &variable / expression (not literal text)',CHECK),%myQRDrawRptValueIsVar,DEFAULT(0),AT(10)
      #PROMPT('&Error correction level:',DROP('L - Low (most data)[1]|M - Medium[2]|Q - Quartile[3]|H - High (most robust)[4]')),%myQRDrawRptEcc,DEFAULT('2')
      #PROMPT('&Dark (foreground) color:',COLOR),%myQRDrawRptDark,DEFAULT(00000000H)
      #PROMPT('&Light (background) color:',COLOR),%myQRDrawRptLight,DEFAULT(00FFFFFFH)
      #PROMPT('&Quiet-zone modules (border):',SPIN(@n1,0,8,1)),%myQRDrawRptQuiet,DEFAULT(4)
      #PROMPT('Draw &self-test ("HELLO WORLD", ECC M)',CHECK),%myQRDrawRptSelfTest,DEFAULT(0),AT(10)
    #ENDBOXED
  #ENDTAB
  #TAB('&Instructions')
    #BOXED('How to use myQRDrawReport')
      #DISPLAY('1. Add the global "myQRDraw - Global Encoder + Helper"')
      #DISPLAY('   extension once at the Application level.')
      #DISPLAY('2. In the Report formatter, drop an IMAGE control into the')
      #DISPLAY('   DETAIL band (or a band that prints per record) and give it')
      #DISPLAY('   a USE / field-equate so it can be selected below.')
      #DISPLAY('3. Add THIS extension (for reports). On a window, use the')
      #DISPLAY('   plain "myQRDraw" extension instead.')
      #DISPLAY('4. Pick the image control, set the Value (tick "variable" to')
      #DISPLAY('   use a per-record field like ORD:URL), ECC, colors, quiet.')
      #DISPLAY('5. Generate, compile, print/preview - one QR is drawn per')
      #DISPLAY('   record in the detail band. Scan to verify.')
      #DISPLAY('')
      #DISPLAY('Drawing uses SETTARGET(Report) in the Before-Print-Detail')
      #DISPLAY('embed. If the code lands in the wrong spot, ensure the image')
      #DISPLAY('is in the detail band; for page-level placement (one QR per')
      #DISPLAY('page) ask for the page-header variant.')
    #ENDBOXED
  #ENDTAB
#ENDSHEET
#!-----------------------------------------------------------------------------
#! Local value buffer (no repaint routine - reports have no event loop; the code
#! re-encodes from the current field value each time the detail band prints).
#!-----------------------------------------------------------------------------
#AT(%DataSection),WHERE(%myQRDrawRptDisable=0 AND %myQRDrawRptImage)
myQRDrawRpt:Value    CSTRING(512)                            ! the value to encode for this row
#ENDAT
#!-----------------------------------------------------------------------------
#! Draw before each detail band prints. SETTARGET(Report) makes the report the
#! graphics target; GETPOSITION finds the band image; QRPaint draws into it.
#!-----------------------------------------------------------------------------
#AT(%BeforePrint),WHERE(%myQRDrawRptDisable=0 AND %myQRDrawRptImage)
#IF(%myQRDrawRptSelfTest)
  myQRDrawRpt:Value = 'HELLO WORLD'                           ! fixed, known-good 21x21 symbol
  IF QRCodeObj.BuildMatrix(myQRDrawRpt:Value, 2)
    SETTARGET(%Report)
    QRCodeObj.Paint(%myQRDrawRptImage, %myQRDrawRptDark, %myQRDrawRptLight, %myQRDrawRptQuiet)
    SETTARGET()
  END
#ELSE
#IF(%myQRDrawRptValueIsVar)
  myQRDrawRpt:Value = %myQRDrawRptValue                       ! per-record value (e.g. ORD:URL)
#ELSE
  myQRDrawRpt:Value = '%myQRDrawRptValue'                     ! literal text
#ENDIF
  IF QRCodeObj.BuildMatrix(myQRDrawRpt:Value, %myQRDrawRptEcc)
    SETTARGET(%Report)                                       ! the report (band) is the draw target
    QRCodeObj.Paint(%myQRDrawRptImage, %myQRDrawRptDark, %myQRDrawRptLight, %myQRDrawRptQuiet)
    SETTARGET()                                              ! restore
  END
#ENDIF
#ENDAT
#!-----------------------------------------------------------------------------
#! End of myQRDraw template set
#!-----------------------------------------------------------------------------
