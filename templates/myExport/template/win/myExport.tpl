#TEMPLATE(myExport,'myExport - Export any browse or list to CSV / TSV / XML / JSON / Excel / PDF / Print - v1.4'),FAMILY('ABC')
#!-----------------------------------------------------------------------------
#!  myExport template set  -  puts an "Export..." button on any browse or list.
#!
#!  Press it and a modal dialog asks for the FORMAT and for the FOLDER + FILE
#!  NAME (with a real Save-As browser), then writes the file - or, for Print,
#!  sends it straight to the printer instead:
#!
#!      CSV             comma separated, the machine's code page
#!      CSV (UTF-8)     comma separated, UTF-8 with a BOM - accents survive Excel
#!      TSV             tab separated
#!      XML             UTF-8, one element per column
#!      JSON            UTF-8, an array of objects; numeric columns stay numbers
#!      Excel .xlsx     a REAL OOXML workbook - frozen heading row, auto-filter,
#!                      on-screen column widths, numbers as numbers
#!      HTML            a styled table, ready to print or paste
#!      PDF             a real, paginated PDF - hand-built, nothing embedded
#!      Print           straight to a Windows printer - no file at all
#!
#!  NO external program is needed for the Excel or PDF formats, and Print needs
#!  no REPORT structure. An .xlsx is a ZIP of XML parts and a PDF is a set of
#!  objects + a cross-reference table - ExportClass builds both by hand. Print
#!  is plain GDI (CreateDC on the target printer, then StartDoc/StartPage/
#!  TextOut) - deliberately with no Win32 struct involved, so there is nothing
#!  whose binary layout has to be guessed. There is no interactive Print
#!  dialog; set Exporter1.PrinterName to target a specific printer, or leave
#!  it blank for the Windows default.
#!  So there is no helper .exe, no Python, no COM automation, no Office or
#!  Acrobat installation and nothing extra to deploy.
#!
#!  It exports EXACTLY WHAT THE USER SEES. At run time it reads the LIST's own
#!  FORMAT (PROPLIST:Exists / FieldNo / Header / Picture) and pulls the values
#!  with WHAT(Queue,FieldNo) - so re-ordered, resized or hidden columns, and any
#!  column pictures, all carry across without you configuring a thing. PDF and
#!  Print lay columns out proportionally to those same on-screen widths and
#!  paginate automatically, repeating the heading row on every page.
#!
#!  THE TEMPLATES
#!    myExportGlobal (APPLICATION) - INCLUDEs ExportClass and decides where its
#!                   code lives. Add once per app; REQUIRED in a multi-DLL suite.
#!    myExportButton (CONTROL)     - THE EASY PATH: drag onto a browse window and
#!                   it drops a ready-wired Export button. Multiple per window.
#!                   Self-contained; the global extension is optional in an EXE.
#!    myExportHere   (CODE)        - already have a button, menu item or toolbar
#!                   entry? Drop this code template into its Accepted embed.
#!
#!  MULTI-DLL: add myExportGlobal to every app in the suite. The app that owns
#!  the data compiles the class in and exports it from its .EXP; the others
#!  import it. Nothing to configure - it follows each app's External setting.
#!  See the Multi-DLL tab, and the note above the category registration below.
#!
#!  REQUIRED FILES: copy these (shipped beside this .tpl) to a folder on the
#!  Clarion redirection path (the app folder or \clarion12\libsrc\win), ANSI:
#!      ExportClass.inc     ExportClass.clw
#!  ExportClass.clw is pulled into the build automatically by its LINK attribute.
#!
#!  API (the object lives in the procedure's data - call it from any embed):
#!    Exporter1.Ask()          modal format + file name dialog. 1 = go ahead
#!    Exporter1.ExportQueue()  write every record in the queue
#!    Exporter1.Run()          Ask + ExportQueue
#!    Exporter1.StartFile() / .AddRow() / .EndFile()   drive the rows yourself
#!    Exporter1.PrintOut()     every record, straight to the printer, no dialog
#!    Exporter1.PreviewOut()   every record, to a temp PDF, opened in your PDF viewer
#!    Exporter1.PageSetup()    small dialog for orientation / paper / margins
#!-----------------------------------------------------------------------------
#!#############################################################################
#!  GLOBAL EXTENSION - myExportGlobal
#!#############################################################################
#EXTENSION(myExportGlobal,'myExport - Global (add once per application)'),APPLICATION
#SHEET
  #TAB('&General')
    #BOXED('myExport')
      #DISPLAY('myExport Global - Version 1.4')
      #DISPLAY('Makes ExportClass available to every procedure in the app.')
      #DISPLAY('')
      #DISPLAY('IMPORTANT: copy ExportClass.inc and ExportClass.clw to the')
      #DISPLAY('redirection path (the app folder, or \clarion12\libsrc\win).')
      #DISPLAY('Both files must be ANSI. ExportClass.clw links itself in.')
      #DISPLAY('')
      #DISPLAY('This extension is OPTIONAL in a single-EXE application - the')
      #DISPLAY('Export button control template pulls the class in on its own.')
      #DISPLAY('Add it if you want to call the class from hand-written code in')
      #DISPLAY('procedures with no button.')
      #DISPLAY('')
      #DISPLAY('In a MULTI-DLL application it is REQUIRED, in every app of the')
      #DISPLAY('suite - see the Multi-DLL tab.')
    #ENDBOXED
    #BOXED('Options')
      #PROMPT('&Disable this template',CHECK),%xgDisable,DEFAULT(0),AT(10)
    #ENDBOXED
    #BOXED('Language')
      #PROMPT('Export &language:',DROP('English[1]|Español (Spanish)[2]')),%xgLanguage,DEFAULT('1')
      #DISPLAY('The application-wide default. It becomes the global variable')
      #DISPLAY('myExportLanguage, which a button or code template picks up when')
      #DISPLAY('its own Language prompt is set to "Use the application setting".')
      #DISPLAY('')
      #DISPLAY('Every word of the dialog, the Save-As box and the messages comes')
      #DISPLAY('from ExportClass.Txt() - override that one method in a derived')
      #DISPLAY('class to add a third language.')
    #ENDBOXED
  #ENDTAB
  #TAB('&Multi-DLL')
    #BOXED('Where ExportClass lives')
      #DISPLAY('Out of the box myExport follows this application''s own')
      #DISPLAY('External setting, which is already what a multi-DLL suite')
      #DISPLAY('wants:')
      #DISPLAY('')
      #DISPLAY('  the app that owns the data (External: None) compiles')
      #DISPLAY('  ExportClass.clw in and exports the whole class from its')
      #DISPLAY('  own .EXP, and every app set to External: DLL imports it')
      #DISPLAY('  from there instead of compiling its own copy.')
      #DISPLAY('')
      #DISPLAY('So one copy of the class serves the whole suite, and no app')
      #DISPLAY('but the owner carries its code.')
      #DISPLAY('')
      #DISPLAY('This has to be decided per APPLICATION, which is why the')
      #DISPLAY('button and code templates cannot do it: add this extension')
      #DISPLAY('to every app in the suite and leave the box below alone.')
    #ENDBOXED
  #ENDTAB
  #TAB('Cl&ass')
    #BOXED('Override - place the class by hand')
      #INSERT(%AbcLibraryPrompts(ABC))
      #DISPLAY('')
      #DISPLAY('Linked in   - compile ExportClass.clw into this app (and, if')
      #DISPLAY('              this app is a DLL, export the class from it).')
      #DISPLAY('External DLL- import the class from another DLL in the suite.')
      #DISPLAY('External LIB- link against a .LIB you built yourself.')
      #DISPLAY('None        - do neither; you add the .clw to the project.')
    #ENDBOXED
    #BOXED('If the class is missing from the generated .EXP')
      #DISPLAY('The export list is built from the IDE''s class registry. If')
      #DISPLAY('ExportClass is not in it yet, press "Refresh Application')
      #DISPLAY('Builder Class Information" on the Global Properties Classes')
      #DISPLAY('tab (or close and re-open the application) and generate again.')
    #ENDBOXED
  #ENDTAB
#ENDSHEET
#!
#AT(%AfterGlobalIncludes),WHERE(%xgDisable=0)
INCLUDE('ExportClass.INC'),ONCE
#ENDAT
#!
#! The application-wide language, as a real global that a button or code
#! template reads when its own Language prompt says "use the application
#! setting". It is global DATA, so it gets the multi-DLL treatment: defined in
#! the app that owns the data, EXTERNAL everywhere else, exported from the
#! owner (corpus: cleansdw.tpw:25 uses these same ABC symbols).
#AT(%GlobalData),WHERE(%xgDisable=0)
  #IF(%DefaultExternal = 'None External')
myExportLanguage     BYTE(%xgLanguage)                     ! 1 = English, 2 = Espanol
  #ELSE
myExportLanguage     BYTE,EXTERNAL,DLL(dll_mode)           ! it lives in the data DLL
  #ENDIF
#ENDAT
#!
#AT(%DLLExportList),WHERE(%xgDisable=0)
  #IF(%DefaultExternal = 'None External' AND %ProgramExtension='DLL' AND %DefaultExport)
  $myExportLanguage                                        @?
  #ENDIF
#ENDAT
#!-----------------------------------------------------------------------------
#!  MULTI-DLL. ExportClass carries the tag !ABCIncludeFile(MYEXPORT) on line 1,
#!  so the IDE's class registry files it under category MYEXPORT. Registering
#!  that category here hands the whole job to the shipped ABC machinery:
#!
#!    ABPROGRM.TPW:88  #CALL(%DefineCategoryPragmas) writes the project defines
#!                     _myExportLinkMode_ / _myExportDllMode_ that the class's
#!                     LINK() and DLL() attributes read.
#!    ABBLDEXP.TPW     while building the .EXP of a DLL, walks the registry and
#!                     emits VMT$ / TYPE$ / every non-private method of every
#!                     link-mode category class - name-mangled by LINKNAME().
#!
#!  That last part is why nothing here lists a mangled symbol: add a method to
#!  ExportClass and the export list follows on the next generate.
#!
#!  Corpus precedent for a third-party class registering its own category:
#!  svgraph.tpl:38, qcenter.tpw:98, abmail.tpl:310.
#!-----------------------------------------------------------------------------
#AT(%BeforeGenerateApplication),WHERE(%xgDisable=0)
  #CALL(%AddCategory(ABC),'MYEXPORT')
  #CALL(%SetCategoryLocationFromPrompts(ABC),'MYEXPORT','myExport','')
#ENDAT
#!#############################################################################
#!  CONTROL TEMPLATE - myExportButton  -  drag an Export button onto a browse
#!#############################################################################
#!  Drops a BUTTON and wires the whole export to it in one drag. Self-contained:
#!  it emits INCLUDE('ExportClass.INC'),ONCE at %CustomGlobalDeclarations - the
#!  per-MODULE compile-global embed (corpus: ABDROPS.TPW:65, a control template
#!  writing a global declaration). ,ONCE keys on the filename across the whole
#!  compile, so the class is pulled in exactly once even when the global
#!  extension is present too.
#!
#!  The button's own field equate is captured in %xbBtn with the shipped
#!  #FOR(%Control),WHERE(%ControlInstance=%ActiveTemplateInstance) idiom
#!  (corpus: CONTROL.TPW:107, CloseButton) so it tracks AppGen's auto-uniqued
#!  feq and MULTI drops keep working.
#!
#!  The QUEUE is read out of the LIST's own FROM() attribute at generate time -
#!  EXTRACT(%ControlStatement,'FROM',1), the same call the shipped BrowseBox
#!  makes at ABBROWSE.TPW:825. So it just works for an ABC BrowseBox
#!  (FROM(Queue:Browse)) and for any hand-coded LIST, with nothing to type.
#!
#!  The export code is emitted INLINE in the button's Accepted handler rather
#!  than as a ROUTINE: %ControlEventHandling lands inside ThisWindow's methods,
#!  and no shipped template calls a procedure ROUTINE from there.
#!#############################################################################
#CONTROL(myExportButton,'myExport - Export button for a browse/list (drag onto a window)'),WINDOW,MULTI,DESCRIPTION('Export ' & %xbList & ' to a file'),HLP('~myExport.htm')
  CONTROLS
    BUTTON('&Export...'),AT(,,54,14),USE(?ExportBtn),TIP('Export this list to a file')
  END
#SHEET
  #TAB('&General')
    #BOXED('Object')
      #PROMPT('&Disable this button',CHECK),%xbDisable,DEFAULT(0),AT(10)
      #PROMPT('&Object name:',@s64),%xbObject,REQ,DEFAULT('Exporter' & %ActiveTemplateInstance)
      #DISPLAY('')
      #DISPLAY('Multi-DLL: where the class itself lives is an application-wide')
      #DISPLAY('decision, so it is made by the myExportGlobal extension. Add')
      #DISPLAY('that to every app in the suite; nothing to set here.')
    #ENDBOXED
    #BOXED('What to export')
      #PROMPT('&List control to export:',CONTROL),%xbList,REQ
      #PROMPT('&Records:',DROP('Every record in the browse - walks the view[1]|Only the rows currently loaded in the list queue[0]')),%xbScope,DEFAULT('1')
      #ENABLE(%xbScope='1')
        #PROMPT('&Browse object:',@s64),%xbBrowse,DEFAULT('BRW1')
        #DISPLAY('The ABC BrowseBox object that fills the list - BRW1, BRW2...')
        #DISPLAY('(see the BrowseBox extension''s Classes tab if you are unsure).')
      #ENDENABLE
      #DISPLAY('')
      #PROMPT('&Queue (blank = read it from the list''s FROM):',@s64),%xbQueueOver,DEFAULT('')
      #DISPLAY('Only fill this in when the list is bound with PROP:From at run')
      #DISPLAY('time, so there is no FROM() in the window for us to read.')
    #ENDBOXED
  #ENDTAB
  #TAB('&Formats')
    #BOXED('Offer these formats in the export dialog')
      #PROMPT('&CSV - comma separated',CHECK),%xbCSV,DEFAULT(1),AT(10)
      #PROMPT('CSV - comma separated, &UTF-8 (accents survive Excel)',CHECK),%xbCSVU,DEFAULT(1),AT(10)
      #PROMPT('&TSV - tab separated',CHECK),%xbTSV,DEFAULT(1),AT(10)
      #PROMPT('&XML document',CHECK),%xbXML,DEFAULT(1),AT(10)
      #PROMPT('&JSON document',CHECK),%xbJSON,DEFAULT(1),AT(10)
      #PROMPT('&Excel workbook (.xlsx)',CHECK),%xbXLSX,DEFAULT(1),AT(10)
      #PROMPT('&HTML table',CHECK),%xbHTML,DEFAULT(1),AT(10)
      #PROMPT('PD&F document',CHECK),%xbPDF,DEFAULT(1),AT(10)
      #PROMPT('Pri&nt (straight to a Windows printer)',CHECK),%xbPrint,DEFAULT(1),AT(10)
    #ENDBOXED
  #ENDTAB
  #TAB('A&bout formats')
    #BOXED('About the Excel format')
      #DISPLAY('The .xlsx is written here, in Clarion - a real OOXML workbook')
      #DISPLAY('with a frozen heading row, an auto-filter, the on-screen column')
      #DISPLAY('widths and numbers stored as numbers. No Excel, no COM, no')
      #DISPLAY('helper program, nothing extra to deploy.')
      #DISPLAY('')
      #DISPLAY('Its parts are STORED (an uncompressed but perfectly valid ZIP).')
      #DISPLAY('For a smaller file on very large exports, set _ExportDeflate_')
      #DISPLAY('to 1 at the top of ExportClass.inc and put CompressClass.inc /')
      #DISPLAY('.clw (the myCompress template) on the redirection path.')
    #ENDBOXED
    #BOXED('About PDF and Print')
      #DISPLAY('Both are hand-built too: PDF is a set of objects and a cross-')
      #DISPLAY('reference table (Helvetica/Helvetica-Bold - the standard PDF')
      #DISPLAY('fonts, so nothing is embedded); Print is plain GDI, straight to')
      #DISPLAY('a printer (CreateDC, StartDoc/StartPage/TextOut). Neither needs')
      #DISPLAY('a REPORT structure, Acrobat, or anything else installed.')
      #DISPLAY('')
      #DISPLAY('Picking Print in the dialog hides "Save to" (there is no file)')
      #DISPLAY('and relabels the button "Print" - there is no printer-choice')
      #DISPLAY('dialog; it prints to Exporter1.PrinterName, or the Windows')
      #DISPLAY('default printer when that is left blank.')
      #DISPLAY('')
      #DISPLAY('Use the Page setup tab to set PDF''s page size/orientation and')
      #DISPLAY('the margins both formats use.')
    #ENDBOXED
  #ENDTAB
  #TAB('&Page setup')
    #BOXED('PDF page (Print follows the printer''s own driver instead)')
      #PROMPT('&Orientation:',DROP('Portrait[1]|Landscape[2]')),%xbOrient,DEFAULT('2')
      #PROMPT('&Paper size:',DROP('Letter[1]|A4[2]')),%xbPaper,DEFAULT('1')
    #ENDBOXED
    #BOXED('Margins, in inches (both PDF and Print)')
      #PROMPT('&Left:',@n5.2),%xbMarginL,DEFAULT('0.50')
      #PROMPT('&Top:',@n5.2),%xbMarginT,DEFAULT('0.50')
      #PROMPT('&Right:',@n5.2),%xbMarginR,DEFAULT('0.50')
      #PROMPT('&Bottom:',@n5.2),%xbMarginB,DEFAULT('0.50')
    #ENDBOXED
    #BOXED('Type')
      #PROMPT('&Font face (blank = Arial/Helvetica):',@s32),%xbFontFace,DEFAULT('')
      #PROMPT('Bod&y size (points):',@n3),%xbFontSize,DEFAULT('9')
      #PROMPT('Titl&e size (points):',@n3),%xbTitleSize,DEFAULT('14')
    #ENDBOXED
  #ENDTAB
  #TAB('&Options')
    #BOXED('Content')
      #PROMPT('&Title (sheet name, XML root, HTML heading):',@s64),%xbTitle,DEFAULT(%Procedure)
      #PROMPT('XML &row element:',@s32),%xbRowTag,DEFAULT('Row')
      #PROMPT('CSV &separator:',@s1),%xbDelim,DEFAULT(',')
      #PROMPT('Include the column &headings',CHECK),%xbHeaders,DEFAULT(1),AT(10)
      #PROMPT('Apply each column''s &picture',CHECK),%xbPictures,DEFAULT(1),AT(10)
      #PROMPT('Start with &visible columns only (hidden and icon columns un-ticked)',CHECK),%xbVisible,DEFAULT(1),AT(10)
    #ENDBOXED
    #BOXED('Columns')
      #PROMPT('Let the user &choose, rename and re-picture the columns',CHECK),%xbColumnUI,DEFAULT(1),AT(10)
      #DISPLAY('On: the export dialog lists every column with a tick box, and')
      #DISPLAY('the user can rename one or give it a different picture.')
      #DISPLAY('Off: the dialog is just format + file name, and the columns go')
      #DISPLAY('out exactly as the list shows them.')
    #ENDBOXED
    #BOXED('Afterwards')
      #PROMPT('&Open the file in its default program',CHECK),%xbOpenAfter,DEFAULT(1),AT(10)
      #PROMPT('Show the "N rows exported" &confirmation',CHECK),%xbConfirm,DEFAULT(1),AT(10)
    #ENDBOXED
    #BOXED('Starting folder')
      #PROMPT('&Suggest this folder (blank = the current directory):',@s128),%xbFolder,DEFAULT('')
      #DISPLAY('Only a suggestion - the user still picks the folder and name.')
    #ENDBOXED
  #ENDTAB
  #TAB('Remem&ber')
    #BOXED('Language')
      #PROMPT('&Language:',DROP('English[1]|Español (Spanish)[2]|Use the application setting[0]')),%xbLang,DEFAULT('1')
      #DISPLAY('The dialog, the Save-As box and every message follow this.')
      #DISPLAY('')
      #DISPLAY('"Use the application setting" reads the global myExportLanguage,')
      #DISPLAY('so it needs the myExport - Global extension on the application.')
      #DISPLAY('The other two choices need nothing but this button.')
    #ENDBOXED
    #BOXED('Remember the last export')
      #PROMPT('Remember the &user''s choices between runs',CHECK),%xbPersist,DEFAULT(1),AT(10)
      #DISPLAY('Saves the format, the folder, the three tick boxes and the whole')
      #DISPLAY('column list (which are on, renames, pictures) when an export')
      #DISPLAY('succeeds, and restores them the next time the dialog opens.')
      #ENABLE(%xbPersist)
        #PROMPT('&Profile name (blank = this procedure):',@s64),%xbProfile,DEFAULT('')
        #PROMPT('I&NI file (blank = the application''s own .INI):',@s128),%xbIniFile,DEFAULT('')
        #DISPLAY('Each profile remembers its own settings, so two browses never')
        #DISPLAY('overwrite each other.')
      #ENDENABLE
    #ENDBOXED
  #ENDTAB
#ENDSHEET
#!-----------------------------------------------------------------------------
#ATSTART
  #DECLARE(%xbBtn)
  #FOR(%Control),WHERE(%ControlInstance=%ActiveTemplateInstance)
    #SET(%xbBtn,%Control)
  #ENDFOR
  #DECLARE(%xbQueue)
  #SET(%xbQueue,%xbQueueOver)
  #IF(~%xbQueue)
    #FOR(%Control),WHERE(%Control=%xbList)
      #SET(%xbQueue,EXTRACT(%ControlStatement,'FROM',1))
    #ENDFOR
  #ENDIF
  #DECLARE(%xbMask)
  #SET(%xbMask,0)
  #IF(%xbCSV)
    #SET(%xbMask,%xbMask+1)
  #ENDIF
  #IF(%xbCSVU)
    #SET(%xbMask,%xbMask+2)
  #ENDIF
  #IF(%xbTSV)
    #SET(%xbMask,%xbMask+4)
  #ENDIF
  #IF(%xbXML)
    #SET(%xbMask,%xbMask+8)
  #ENDIF
  #IF(%xbJSON)
    #SET(%xbMask,%xbMask+16)
  #ENDIF
  #IF(%xbXLSX)
    #SET(%xbMask,%xbMask+32)
  #ENDIF
  #IF(%xbHTML)
    #SET(%xbMask,%xbMask+64)
  #ENDIF
  #IF(%xbPrint)
    #SET(%xbMask,%xbMask+128)
  #ENDIF
  #IF(%xbPDF)
    #SET(%xbMask,%xbMask+256)
  #ENDIF
  #IF(%xbMask=0)
    #SET(%xbMask,511)
  #ENDIF
#ENDAT
#!
#! Self-contained: pull in the class (,ONCE = safe alongside the global extension).
#AT(%CustomGlobalDeclarations),WHERE(%xbDisable=0)
INCLUDE('ExportClass.INC'),ONCE
#ENDAT
#!
#AT(%DataSection),WHERE(%xbDisable=0 AND %xbList AND %xbQueue)
%xbObject            ExportClass                          ! exports %xbList to a file
#ENDAT
#!
#! Everything is set up at click time, not at open time, so a column the user
#! re-ordered, resized or hid since the window opened is honoured.
#AT(%ControlEventHandling,%xbBtn,'Accepted'),WHERE(%xbDisable=0 AND %xbList AND %xbQueue)
  %xbObject.Init(%xbList,%xbQueue)                         ! re-reads the list's live layout
  %xbObject.Title        = '%xbTitle'
#IF(%xbRowTag)
  %xbObject.RowTag       = '%xbRowTag'
#ENDIF
#IF(%xbDelim)
  %xbObject.Delim        = '%xbDelim'
#ENDIF
#IF(%xbLang AND %xbLang <> '0')
  %xbObject.Language     = %xbLang                         ! this button's own choice
#ELSE
  %xbObject.Language     = myExportLanguage                ! whatever the global says
#ENDIF
  %xbObject.Headers      = %xbHeaders
  %xbObject.Pictures     = %xbPictures
  %xbObject.VisibleOnly  = %xbVisible
  %xbObject.AllowColumns = %xbColumnUI
  %xbObject.OpenWhenDone = %xbOpenAfter
  %xbObject.Confirm      = %xbConfirm
  %xbObject.Allow        = %xbMask
#IF(%xbFontFace)
  %xbObject.FontFace     = '%xbFontFace'
#ENDIF
  %xbObject.FontSize     = %xbFontSize
  %xbObject.TitleSize    = %xbTitleSize
  %xbObject.PageOrient   = %xbOrient
  %xbObject.PagePaper    = %xbPaper
  %xbObject.MarginLeft   = %xbMarginL * 1440
  %xbObject.MarginTop    = %xbMarginT * 1440
  %xbObject.MarginRight  = %xbMarginR * 1440
  %xbObject.MarginBottom = %xbMarginB * 1440
#IF(%xbPersist)
  %xbObject.Persist      = 1                               ! restore/save the choices between runs
#IF(%xbProfile)
  %xbObject.Profile      = '%xbProfile'
#ELSE
  %xbObject.Profile      = '%Procedure'
#ENDIF
#IF(%xbIniFile)
  %xbObject.IniFile      = '%xbIniFile'
#ENDIF
#ENDIF
#IF(%xbFolder)
  IF ~%xbObject.FileName                                   ! only the first time
    %xbObject.FileName = CLIP('%xbFolder') & '\' & %xbObject.SuggestName()
  END
#ENDIF
#EMBED(%myExportBeforeAsk,'myExport - before the export dialog opens'),%ActiveTemplateInstance,HIDE
  IF %xbObject.Ask()                                       ! format + folder + file name
#IF(%xbScope='1')
    IF %xbObject.StartFile()
      %xbBrowse.Reset()                                    ! the top of the current sort order
      LOOP
        IF %xbBrowse.Next() THEN BREAK .                   ! Level:Notify = end of the view
        %xbBrowse.SetQueueRecord()                         ! view record -> the queue buffer
        %xbObject.AddRow()
      END
      %xbObject.EndFile()
      %xbBrowse.ResetSort(1)                               ! refill the browse we just walked
      %xbBrowse.UpdateWindow()
    END
#ELSE
    %xbObject.ExportQueue()
#ENDIF
#EMBED(%myExportAfterExport,'myExport - after the file has been written'),%ActiveTemplateInstance,HIDE
  END
#ENDAT
#!#############################################################################
#!  CODE TEMPLATE - myExportHere  -  export from an existing button/menu/toolbar
#!#############################################################################
#!  Same engine, dropped wherever you want it: a menu item's Accepted embed, an
#!  existing button, a toolbar entry, a hot key. ,PROCEDURE lets a #CODE template
#!  own procedure-scope #AT sections (corpus: ABPOPUP.TPW:1, DisplayPopupMenu),
#!  which is how it declares its own object in %DataSection.
#!#############################################################################
#CODE(myExportHere,'myExport - Export a list to a file (CSV/TSV/XML/JSON/Excel)'),MULTI,PROCEDURE,DESCRIPTION('Export ' & %xcList & ' to a file'),HLP('~myExport.htm')
#SHEET
  #TAB('&General')
    #BOXED('Object')
      #PROMPT('&Object name:',@s64),%xcObject,REQ,DEFAULT('Exporter' & %ActiveTemplateInstance)
    #ENDBOXED
    #BOXED('What this does when it runs')
      #PROMPT('&Action:',DROP('Show the export dialog (format + file name)[1]|Print immediately - no dialog, no file[2]|Preview (PDF) immediately - no dialog, opens in your PDF viewer[3]')),%xcAction,DEFAULT('1')
      #DISPLAY('Print/Preview immediately only exports the rows currently loaded')
      #DISPLAY('in the list''s queue (on-screen) - there is no dialog to pick')
      #DISPLAY('"every record in the browse" from. For that, use "Show the')
      #DISPLAY('export dialog" instead, or call %xcObject.PrintOut() / .PreviewOut()')
      #DISPLAY('from your own code after walking the browse yourself into')
      #DISPLAY('StartFile()/AddRow()/EndFile().')
    #ENDBOXED
    #BOXED('What to export')
      #PROMPT('&List control to export:',CONTROL),%xcList,REQ
      #ENABLE(%xcAction='1')
        #PROMPT('&Records:',DROP('Every record in the browse - walks the view[1]|Only the rows currently loaded in the list queue[0]')),%xcScope,DEFAULT('1')
      #ENDENABLE
      #ENABLE(%xcAction='1' AND %xcScope='1')
        #PROMPT('&Browse object:',@s64),%xcBrowse,DEFAULT('BRW1')
      #ENDENABLE
      #PROMPT('&Queue (blank = read it from the list''s FROM):',@s64),%xcQueueOver,DEFAULT('')
    #ENDBOXED
  #ENDTAB
  #TAB('&Formats')
    #BOXED('Offer these formats in the export dialog')
      #PROMPT('&CSV - comma separated',CHECK),%xcCSV,DEFAULT(1),AT(10)
      #PROMPT('CSV - comma separated, &UTF-8',CHECK),%xcCSVU,DEFAULT(1),AT(10)
      #PROMPT('&TSV - tab separated',CHECK),%xcTSV,DEFAULT(1),AT(10)
      #PROMPT('&XML document',CHECK),%xcXML,DEFAULT(1),AT(10)
      #PROMPT('&JSON document',CHECK),%xcJSON,DEFAULT(1),AT(10)
      #PROMPT('&Excel workbook (.xlsx)',CHECK),%xcXLSX,DEFAULT(1),AT(10)
      #PROMPT('&HTML table',CHECK),%xcHTML,DEFAULT(1),AT(10)
      #PROMPT('PD&F document',CHECK),%xcPDF,DEFAULT(1),AT(10)
      #PROMPT('Pri&nt (straight to a Windows printer)',CHECK),%xcPrint,DEFAULT(1),AT(10)
    #ENDBOXED
  #ENDTAB
  #TAB('&Page setup')
    #BOXED('PDF page (Print follows the printer''s own driver instead)')
      #PROMPT('&Orientation:',DROP('Portrait[1]|Landscape[2]')),%xcOrient,DEFAULT('2')
      #PROMPT('&Paper size:',DROP('Letter[1]|A4[2]')),%xcPaper,DEFAULT('1')
    #ENDBOXED
    #BOXED('Margins, in inches (both PDF and Print)')
      #PROMPT('&Left:',@n5.2),%xcMarginL,DEFAULT('0.50')
      #PROMPT('&Top:',@n5.2),%xcMarginT,DEFAULT('0.50')
      #PROMPT('&Right:',@n5.2),%xcMarginR,DEFAULT('0.50')
      #PROMPT('&Bottom:',@n5.2),%xcMarginB,DEFAULT('0.50')
    #ENDBOXED
    #BOXED('Type')
      #PROMPT('&Font face (blank = Arial/Helvetica):',@s32),%xcFontFace,DEFAULT('')
      #PROMPT('Bod&y size (points):',@n3),%xcFontSize,DEFAULT('9')
      #PROMPT('Titl&e size (points):',@n3),%xcTitleSize,DEFAULT('14')
    #ENDBOXED
  #ENDTAB
  #TAB('&Options')
    #BOXED('Content')
      #PROMPT('&Title (sheet name, XML root, HTML heading):',@s64),%xcTitle,DEFAULT(%Procedure)
      #PROMPT('XML &row element:',@s32),%xcRowTag,DEFAULT('Row')
      #PROMPT('CSV &separator:',@s1),%xcDelim,DEFAULT(',')
      #PROMPT('Include the column &headings',CHECK),%xcHeaders,DEFAULT(1),AT(10)
      #PROMPT('Apply each column''s &picture',CHECK),%xcPictures,DEFAULT(1),AT(10)
      #PROMPT('Start with &visible columns only',CHECK),%xcVisible,DEFAULT(1),AT(10)
      #PROMPT('Let the user &choose, rename and re-picture the columns',CHECK),%xcColumnUI,DEFAULT(1),AT(10)
    #ENDBOXED
    #BOXED('Afterwards')
      #PROMPT('&Open the file in its default program',CHECK),%xcOpenAfter,DEFAULT(1),AT(10)
      #PROMPT('Show the "N rows exported" &confirmation',CHECK),%xcConfirm,DEFAULT(1),AT(10)
      #PROMPT('&Suggest this folder (blank = the current directory):',@s128),%xcFolder,DEFAULT('')
      #PROMPT('Remember the &user''s choices between runs',CHECK),%xcPersist,DEFAULT(1),AT(10)
      #ENABLE(%xcPersist)
        #PROMPT('&Profile name (blank = this procedure):',@s64),%xcProfile,DEFAULT('')
      #ENDENABLE
    #ENDBOXED
    #BOXED('Language')
      #PROMPT('&Language:',DROP('English[1]|Español (Spanish)[2]|Use the application setting[0]')),%xcLang,DEFAULT('1')
      #DISPLAY('"Use the application setting" reads the global myExportLanguage,')
      #DISPLAY('so it needs the myExport - Global extension on the application.')
    #ENDBOXED
  #ENDTAB
#ENDSHEET
#!-----------------------------------------------------------------------------
#ATSTART
  #DECLARE(%xcQueue)
  #SET(%xcQueue,%xcQueueOver)
  #IF(~%xcQueue)
    #FOR(%Control),WHERE(%Control=%xcList)
      #SET(%xcQueue,EXTRACT(%ControlStatement,'FROM',1))
    #ENDFOR
  #ENDIF
  #DECLARE(%xcMask)
  #SET(%xcMask,0)
  #IF(%xcCSV)
    #SET(%xcMask,%xcMask+1)
  #ENDIF
  #IF(%xcCSVU)
    #SET(%xcMask,%xcMask+2)
  #ENDIF
  #IF(%xcTSV)
    #SET(%xcMask,%xcMask+4)
  #ENDIF
  #IF(%xcXML)
    #SET(%xcMask,%xcMask+8)
  #ENDIF
  #IF(%xcJSON)
    #SET(%xcMask,%xcMask+16)
  #ENDIF
  #IF(%xcXLSX)
    #SET(%xcMask,%xcMask+32)
  #ENDIF
  #IF(%xcHTML)
    #SET(%xcMask,%xcMask+64)
  #ENDIF
  #IF(%xcPrint)
    #SET(%xcMask,%xcMask+128)
  #ENDIF
  #IF(%xcPDF)
    #SET(%xcMask,%xcMask+256)
  #ENDIF
  #IF(%xcMask=0)
    #SET(%xcMask,511)
  #ENDIF
#ENDAT
#!
#AT(%CustomGlobalDeclarations)
INCLUDE('ExportClass.INC'),ONCE
#ENDAT
#!
#AT(%DataSection),WHERE(%xcList AND %xcQueue)
%xcObject            ExportClass                          ! exports %xcList to a file
#ENDAT
#!
#! ...and the code template's own output, right where it was dropped:
#IF(%xcList AND %xcQueue)
%xcObject.Init(%xcList,%xcQueue)
%xcObject.Title        = '%xcTitle'
#IF(%xcRowTag)
%xcObject.RowTag       = '%xcRowTag'
#ENDIF
#IF(%xcDelim)
%xcObject.Delim        = '%xcDelim'
#ENDIF
#IF(%xcLang AND %xcLang <> '0')
%xcObject.Language     = %xcLang
#ELSE
%xcObject.Language     = myExportLanguage
#ENDIF
%xcObject.Headers      = %xcHeaders
%xcObject.Pictures     = %xcPictures
%xcObject.VisibleOnly  = %xcVisible
%xcObject.AllowColumns = %xcColumnUI
%xcObject.OpenWhenDone = %xcOpenAfter
%xcObject.Confirm      = %xcConfirm
%xcObject.Allow        = %xcMask
#IF(%xcFontFace)
%xcObject.FontFace     = '%xcFontFace'
#ENDIF
%xcObject.FontSize     = %xcFontSize
%xcObject.TitleSize    = %xcTitleSize
%xcObject.PageOrient   = %xcOrient
%xcObject.PagePaper    = %xcPaper
%xcObject.MarginLeft   = %xcMarginL * 1440
%xcObject.MarginTop    = %xcMarginT * 1440
%xcObject.MarginRight  = %xcMarginR * 1440
%xcObject.MarginBottom = %xcMarginB * 1440
#IF(%xcPersist)
%xcObject.Persist      = 1
#IF(%xcProfile)
%xcObject.Profile      = '%xcProfile'
#ELSE
%xcObject.Profile      = '%Procedure'
#ENDIF
#ENDIF
#IF(%xcFolder)
IF ~%xcObject.FileName
  %xcObject.FileName = CLIP('%xcFolder') & '\' & %xcObject.SuggestName()
END
#ENDIF
#IF(%xcAction='1')
IF %xcObject.Ask()
#IF(%xcScope='1')
  IF %xcObject.StartFile()
    %xcBrowse.Reset()
    LOOP
      IF %xcBrowse.Next() THEN BREAK .
      %xcBrowse.SetQueueRecord()
      %xcObject.AddRow()
    END
    %xcObject.EndFile()
    %xcBrowse.ResetSort(1)
    %xcBrowse.UpdateWindow()
  END
#ELSE
  %xcObject.ExportQueue()
#ENDIF
END
#ELSE
  #IF(%xcAction='2')
!  StartFile()/EndFile() already show a message on failure (Confirm above),
!  and PrintOut() only ever prints the rows currently in the queue.
%xcObject.PrintOut()
  #ELSE
!  Same as PrintOut() above, but writes a temp PDF and opens it instead of
!  sending it to the printer - see ExportClass.PreviewOut().
%xcObject.PreviewOut()
  #ENDIF
#ENDIF
#ELSE
! myExport: pick a List control in the code template's prompts, and give it a
! Queue if the list has no FROM() attribute for the template to read.
#ENDIF
#!-----------------------------------------------------------------------------
#! End of myExport template set
#!-----------------------------------------------------------------------------
