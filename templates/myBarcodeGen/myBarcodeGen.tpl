#TEMPLATE(myBarcodeGen,'myBarcodeGen - Draw barcodes (1D + QR) into a Window/Report - v1.0'),FAMILY('ABC')
#!-----------------------------------------------------------------------------
#!  myBarcodeGen template set  -  OFFLINE barcodes drawn with BOX primitives.
#!
#!  Like myQRDraw, this ENCODES the symbol at run time and draws it with BOXes -
#!  no internet, no curl, no temp files. Supported symbologies:
#!     Code 39, Code 128 (auto B/C), Interleaved 2 of 5, EAN-13, UPC-A, QR Code.
#!  Linear (1D) codes are drawn via BarcodeClass; QR via QRCodeClass. Both are
#!  ports of ZXing-validated C# references (designer/BarcodeCore, QrCodeCore).
#!
#!  myBarcodeGenGlobal (APPLICATION) - INCLUDEs BarcodeClass + QRCodeClass and
#!               declares one instance of each (BarcodeObj, QRCodeObj), multi-DLL
#!               aware. Add once, globally.
#!  myBarcodeGen       (PROCEDURE)    - draws into an IMAGE control on a WINDOW.
#!  myBarcodeGenReport (PROCEDURE)    - draws per record into an IMAGE control in
#!               a REPORT band (Before-Print embed, SETTARGET(Report)).
#!
#!  REQUIRED FILES: copy BarcodeClass.inc/.clw AND QRCodeClass.inc/.clw to a
#!               folder on the Clarion redirection path (the app folder or
#!               \clarion12\libsrc\win). Store them in ANSI (not UTF-8).
#!-----------------------------------------------------------------------------
#!#############################################################################
#!  GLOBAL EXTENSION - myBarcodeGenGlobal
#!#############################################################################
#EXTENSION(myBarcodeGenGlobal,'myBarcodeGen - Global Encoders (add once per application)'),APPLICATION
#SHEET
  #TAB('&General')
    #BOXED('myBarcodeGen')
      #DISPLAY('myBarcodeGen Global Encoders - Version 1.0')
      #DISPLAY('Adds the BarcodeClass (1D) + QRCodeClass (QR) encoders and one')
      #DISPLAY('instance of each. No internet / curl - drawn with BOXes.')
      #DISPLAY('Add once at the Application (global) level. IMPORTANT: copy the')
      #DISPLAY('four class files (.inc/.clw) to the redirection path - ANSI.')
    #ENDBOXED
    #BOXED('Options')
      #PROMPT('&Disable this template',CHECK),%myBCDisable,DEFAULT(0),AT(10)
    #ENDBOXED
  #ENDTAB
#ENDSHEET
#!-----------------------------------------------------------------------------
#! Include both encoder classes and declare one global instance of each. The
#! instances are GLOBAL DATA, so they are multi-DLL aware (ABC's %DefaultExternal
#! / %DefaultExport / %ProgramExtension): defined in a single-EXE or the root DLL,
#! EXTERNAL elsewhere, exported from the root DLL. (Pattern: cleansdw.tpw.)
#!-----------------------------------------------------------------------------
#AT(%AfterGlobalIncludes),WHERE(%myBCDisable=0)
INCLUDE('BarcodeClass.INC'),ONCE
INCLUDE('QRCodeClass.INC'),ONCE
INCLUDE('DataMatrixClass.INC'),ONCE
INCLUDE('Pdf417Class.INC'),ONCE
#ENDAT
#!
#AT(%GlobalData),WHERE(%myBCDisable=0)
  #IF(%DefaultExternal = 'None External')
BarcodeObj    BarcodeClass
QRCodeObj     QRCodeClass
DataMatrixObj DataMatrixClass
Pdf417Obj     Pdf417Class
  #ELSE
BarcodeObj    BarcodeClass,EXTERNAL,DLL(dll_mode)
QRCodeObj     QRCodeClass,EXTERNAL,DLL(dll_mode)
DataMatrixObj DataMatrixClass,EXTERNAL,DLL(dll_mode)
Pdf417Obj     Pdf417Class,EXTERNAL,DLL(dll_mode)
  #ENDIF
#ENDAT
#!
#AT(%DLLExportList),WHERE(%myBCDisable=0)
  #IF(%DefaultExternal = 'None External' AND %ProgramExtension='DLL' AND %DefaultExport)
$BarcodeObj    @?
$QRCodeObj     @?
$DataMatrixObj @?
$Pdf417Obj     @?
  #ENDIF
#ENDAT
#!#############################################################################
#!  PROCEDURE EXTENSION - myBarcodeGen (WINDOW)
#!#############################################################################
#EXTENSION(myBarcodeGen,'myBarcodeGen - Draw a barcode on this window'),PROCEDURE,REQ(myBarcodeGenGlobal)
#SHEET
  #TAB('&General')
    #BOXED('Options')
      #PROMPT('&Disable this template',CHECK),%myBCDisableThis,DEFAULT(0),AT(10)
      #PROMPT('&Image control to draw into:',CONTROL),%myBCImage,REQ
      #PROMPT('&Barcode type:',DROP('Code 39[1]|Code 128[2]|Interleaved 2 of 5[3]|EAN-13[4]|UPC-A[5]|QR Code[6]|Data Matrix[7]|PDF417[8]')),%myBCType,DEFAULT('2')
      #PROMPT('&Value:',@s255),%myBCValue,DEFAULT('1234567890')
      #PROMPT('Value is a &variable / expression (not literal text)',CHECK),%myBCValueIsVar,DEFAULT(0),AT(10)
      #PROMPT('Show &human-readable text (1D only):',CHECK),%myBCShowText,DEFAULT(1),AT(10)
      #PROMPT('QR &error correction (QR only):',DROP('L - Low[1]|M - Medium[2]|Q - Quartile[3]|H - High[4]')),%myBCEcc,DEFAULT('2')
      #PROMPT('&Dark (foreground) color:',COLOR),%myBCDark,DEFAULT(00000000H)
      #PROMPT('&Light (background) color:',COLOR),%myBCLight,DEFAULT(00FFFFFFH)
      #PROMPT('&Quiet-zone modules (border):',SPIN(@n2,0,30,1)),%myBCQuiet,DEFAULT(10)
      #PROMPT('Draw &self-test sample for the chosen type',CHECK),%myBCSelfTest,DEFAULT(0),AT(10)
    #ENDBOXED
  #ENDTAB
  #TAB('&Instructions')
    #BOXED('How to use myBarcodeGen')
      #DISPLAY('1. Add the global "myBarcodeGen - Global Encoders" extension once.')
      #DISPLAY('2. Add an IMAGE control to the window (wide for 1D barcodes).')
      #DISPLAY('3. Pick the Image control and the Barcode type.')
      #DISPLAY('4. Set the Value (tick "variable" to use a field like INV:Code).')
      #DISPLAY('   ITF / EAN-13 / UPC-A take digits only (EAN-13 = 12-13 digits,')
      #DISPLAY('   UPC-A = 11-12). Code 128 auto-uses Code C for all-digit even data.')
      #DISPLAY('5. 1D codes draw full-height bars + optional text; QR draws a grid.')
      #DISPLAY('6. Generate, compile, run - then scan with a phone / scanner.')
      #DISPLAY('')
      #DISPLAY('Change the value at run time, then: DO myBarcodeGenRepaint')
    #ENDBOXED
  #ENDTAB
#ENDSHEET
#!-----------------------------------------------------------------------------
#AT(%DataSection),WHERE(%myBCDisableThis=0 AND %myBCImage)
myBC:Redraw          EQUATE(EVENT:User+115)                  ! private "repaint" event
myBC:Value           CSTRING(512)                            ! the value to encode this draw
#ENDAT
#!
#AT(%ProcedureRoutines),WHERE(%myBCDisableThis=0 AND %myBCImage)
myBarcodeGenRepaint ROUTINE
  POST(myBC:Redraw)
#ENDAT
#!
#AT(%WindowManagerMethodCodeSection,'TakeWindowEvent','(),BYTE'),PRIORITY(2000),WHERE(%myBCDisableThis=0 AND %myBCImage)
  CASE EVENT()
  OF EVENT:OpenWindow
    POST(myBC:Redraw)
  OF EVENT:Sized
    POST(myBC:Redraw)
  OF myBC:Redraw
#IF(%myBCSelfTest)
  #CASE(%myBCType)
  #OF('1')
    myBC:Value = 'CODE39'
  #OF('3')
    myBC:Value = '12345670'
  #OF('4')
    myBC:Value = '5901234123457'
  #OF('5')
    myBC:Value = '036000291452'
  #OF('6')
    myBC:Value = 'HELLO WORLD'
  #OF('7')
    myBC:Value = 'DataMatrix'
  #OF('8')
    myBC:Value = 'PDF417 sample'
  #ELSE
    myBC:Value = 'Code128-OK'
  #ENDCASE
#ELSE
  #IF(%myBCValueIsVar)
    myBC:Value = %myBCValue                                  ! code-driven value
  #ELSE
    myBC:Value = '%myBCValue'                                ! literal text
  #ENDIF
#ENDIF
#IF(%myBCType = '6')
    QRCodeObj.Draw(%myBCImage, myBC:Value, %myBCEcc, %myBCDark, %myBCLight, %myBCQuiet)
#ELSIF(%myBCType = '7')
    DataMatrixObj.Draw(%myBCImage, myBC:Value, %myBCDark, %myBCLight, %myBCQuiet)
#ELSIF(%myBCType = '8')
    Pdf417Obj.Draw(%myBCImage, myBC:Value, %myBCDark, %myBCLight, %myBCQuiet)
#ELSE
    BarcodeObj.Draw(%myBCImage, %myBCType, myBC:Value, %myBCDark, %myBCLight, %myBCQuiet, %myBCShowText)
#ENDIF
  END
#ENDAT
#!#############################################################################
#!  PROCEDURE EXTENSION - myBarcodeGenReport (REPORT)
#!#############################################################################
#EXTENSION(myBarcodeGenReport,'myBarcodeGen - Draw a barcode on this REPORT'),PROCEDURE,REQ(myBarcodeGenGlobal)
#SHEET
  #TAB('&General')
    #BOXED('Options')
      #PROMPT('&Disable this template',CHECK),%myBCRptDisable,DEFAULT(0),AT(10)
      #! CONTROL lists window controls; a report needs FROM(%ReportControl,...) (corpus: blobsrv.tpw:20)
      #PROMPT('&Image control (in a report band):',FROM(%ReportControl,%ReportControlType = 'IMAGE')),%myBCRptImage,REQ,DEFAULT('')
      #PROMPT('&Barcode type:',DROP('Code 39[1]|Code 128[2]|Interleaved 2 of 5[3]|EAN-13[4]|UPC-A[5]|QR Code[6]|Data Matrix[7]|PDF417[8]')),%myBCRptType,DEFAULT('2')
      #PROMPT('&Value:',@s255),%myBCRptValue,DEFAULT('1234567890')
      #PROMPT('Value is a &variable / expression (not literal text)',CHECK),%myBCRptValueIsVar,DEFAULT(0),AT(10)
      #PROMPT('Show &human-readable text (1D only):',CHECK),%myBCRptShowText,DEFAULT(1),AT(10)
      #PROMPT('QR &error correction (QR only):',DROP('L - Low[1]|M - Medium[2]|Q - Quartile[3]|H - High[4]')),%myBCRptEcc,DEFAULT('2')
      #PROMPT('&Dark (foreground) color:',COLOR),%myBCRptDark,DEFAULT(00000000H)
      #PROMPT('&Light (background) color:',COLOR),%myBCRptLight,DEFAULT(00FFFFFFH)
      #PROMPT('&Quiet-zone modules (border):',SPIN(@n2,0,30,1)),%myBCRptQuiet,DEFAULT(10)
    #ENDBOXED
  #ENDTAB
#ENDSHEET
#!-----------------------------------------------------------------------------
#AT(%DataSection),WHERE(%myBCRptDisable=0 AND %myBCRptImage)
myBCRpt:Value        CSTRING(512)                            ! the value to encode for this row
#ENDAT
#!
#AT(%BeforePrint),WHERE(%myBCRptDisable=0 AND %myBCRptImage)
#IF(%myBCRptValueIsVar)
  myBCRpt:Value = %myBCRptValue                              ! per-record value
#ELSE
  myBCRpt:Value = '%myBCRptValue'                            ! literal text
#ENDIF
  SETTARGET(%Report)                                         ! the report band is the draw target
#IF(%myBCRptType = '6')
  IF QRCodeObj.BuildMatrix(myBCRpt:Value, %myBCRptEcc)
    QRCodeObj.Paint(%myBCRptImage, %myBCRptDark, %myBCRptLight, %myBCRptQuiet)
  END
#ELSIF(%myBCRptType = '7')
  IF DataMatrixObj.Build(myBCRpt:Value)
    DataMatrixObj.Paint(%myBCRptImage, %myBCRptDark, %myBCRptLight, %myBCRptQuiet)
  END
#ELSIF(%myBCRptType = '8')
  IF Pdf417Obj.Build(myBCRpt:Value)
    Pdf417Obj.Paint(%myBCRptImage, %myBCRptDark, %myBCRptLight, %myBCRptQuiet)
  END
#ELSE
  IF BarcodeObj.Build(%myBCRptType, myBCRpt:Value)
    BarcodeObj.PaintBars(%myBCRptImage, %myBCRptDark, %myBCRptLight, %myBCRptQuiet, %myBCRptShowText)
  END
#ENDIF
  SETTARGET()
#ENDAT
#!-----------------------------------------------------------------------------
#! End of myBarcodeGen template set
#!-----------------------------------------------------------------------------
