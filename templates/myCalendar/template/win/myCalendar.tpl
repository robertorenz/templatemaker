#TEMPLATE(myCalendar,'myCalendar - Pop-up date picker beside any date field - v1.1'),FAMILY('ABC')
#!-----------------------------------------------------------------------------
#!  myCalendar template set  -  puts a small calendar button beside a date entry
#!  field. Press it and a modal calendar opens on whatever the field already
#!  holds; press Accept and the date goes back into the field.
#!
#!  One button can fill in TWO fields: set it to "a from-and-to range" and the
#!  user drags across the days to sweep out a period. The first field gets the
#!  from date, the second the to date.
#!
#!  HOW MUCH IS ON SCREEN
#!      One month      the classic picker
#!      Two months     side by side, or one above the other
#!      Three months   ditto - handy for a quarter
#!      Six months     3 x 2, or 2 x 3
#!      Full year      12 months, 4 x 3 or 3 x 4
#!  The user can change the view in the window itself, and can flip the
#!  stacking between ACROSS and DOWN. Both choices are remembered.
#!
#!  NAVIGATION: << previous year, < previous month, a month drop and a year
#!  spin, > next month, >> next year, and Today.
#!
#!  OPTIONS: week numbers (ISO-8601), first day of the week, today ringed,
#!  weekends blocked, earliest / latest date allowed, English or Spanish.
#!
#!  THEME (v1.1): the global extension can point the calendar at a CapeSoft
#!  Makeover style file (.STY); the pop-up then takes the theme's colours.
#!
#!  THE TEMPLATES
#!    myCalendarGlobal (APPLICATION) - the application-wide defaults: language,
#!                     first day of the week, the opening view. Add it once.
#!    myCalendarButton (CONTROL)     - THE EASY PATH: drag it next to a date
#!                     entry, point it at that entry, done. MULTI - one per
#!                     field (or per from/to pair).
#!    myCalendarHere   (CODE)        - open the calendar from any embed, for an
#!                     existing button, a menu item or a hot key.
#!
#!  REQUIRED FILES: copy these (shipped beside this .tpl) to a folder on the
#!  Clarion redirection path (the app folder, or \clarion12\libsrc\win), ANSI:
#!      MyCalendarClass.inc   MyCalendarClass.clw   cal16.ico
#!  MyCalendarClass.clw is pulled into the build by its LINK attribute. cal16.ico
#!  is the little calendar on the button; Clarion compiles an ICON() into the
#!  executable's own resources, so it is needed at BUILD time only - there is
#!  nothing extra to ship with the finished program.
#!
#!  API (the object lives in the procedure's data - call it from any embed):
#!    Cal1.AskFor(ORD:DueDate)        one date, in and out
#!    Cal1.AskRange(LOC:From,LOC:To)  a from/to pair, drag-selected
#!    Cal1.Ask()                      just ask; read Cal1.Date1 / Cal1.Date2
#!-----------------------------------------------------------------------------
#!#############################################################################
#!  GLOBAL EXTENSION - myCalendarGlobal
#!#############################################################################
#EXTENSION(myCalendarGlobal,'myCalendar - Global (add once per application)'),APPLICATION
#SHEET
  #TAB('&General')
    #BOXED('myCalendar')
      #DISPLAY('myCalendar Global - Version 1.1')
      #DISPLAY('Makes MyCalendarClass available to every procedure in the app,')
      #DISPLAY('and holds the defaults every calendar button starts from.')
      #DISPLAY('')
      #DISPLAY('IMPORTANT: copy MyCalendarClass.inc and MyCalendarClass.clw to the')
      #DISPLAY('redirection path (the app folder, or \clarion12\libsrc\win).')
      #DISPLAY('Both files must be ANSI. MyCalendarClass.clw links itself in.')
      #DISPLAY('cal16.ico (the button icon) goes there too - build time only.')
      #DISPLAY('')
      #DISPLAY('This extension is OPTIONAL - the calendar button control')
      #DISPLAY('template pulls the class in on its own. Add it if you want the')
      #DISPLAY('application-wide defaults, or to call the class from code.')
    #ENDBOXED
    #BOXED('Options')
      #PROMPT('&Disable this template',CHECK),%mdgDisable,DEFAULT(0),AT(10)
    #ENDBOXED
  #ENDTAB
  #TAB('&Defaults')
    #BOXED('Language')
      #PROMPT('Calendar &language:',DROP('English[1]|Español (Spanish)[2]')),%mdgLanguage,DEFAULT('1')
      #DISPLAY('The language every calendar in this application opens in: the')
      #DISPLAY('month names, the day headings, the view list and the buttons.')
      #DISPLAY('Each calendar button can override this on its own tab.')
    #ENDBOXED
    #BOXED('The week')
      #PROMPT('&First day of the week:',DROP('Sunday[0]|Monday[1]')),%mdgFirstDay,DEFAULT('0')
      #PROMPT('Show &week numbers (ISO-8601)',CHECK),%mdgWeekNo,DEFAULT(0),AT(10)
    #ENDBOXED
    #BOXED('How much is on screen')
      #PROMPT('&View:',DROP('One month[1]|Two months[2]|Three months[3]|Six months[6]|Full year[12]')),%mdgView,DEFAULT('1')
      #PROMPT('&Stack the months:',DROP('Across (side by side)[0]|Down (one under the other)[1]')),%mdgOrient,DEFAULT('0')
      #DISPLAY('Where the calendar opens. The user can change both from the')
      #DISPLAY('window, and the choice is remembered per profile.')
    #ENDBOXED
  #ENDTAB
  #TAB('&Theme')
    #BOXED('Follow a CapeSoft Makeover theme')
      #PROMPT('Style &file (an expression; blank = no theme):',@s255),%mdgStyleFile,DEFAULT('')
      #PROMPT('Style &set (blank = Basic3):',@s32),%mdgStyleSet,DEFAULT('')
      #PROMPT('&Band section (blank = none):',@s64),%mdgBandSection,DEFAULT('')
      #DISPLAY('The style file is an EXPRESSION, evaluated every time a')
      #DISPLAY('calendar opens, so a theme the user switches at runtime is')
      #DISPLAY('followed. A fixed file: ''Themes\Blue.STY'' (quoted). The style')
      #DISPLAY('the app saved: GETINI(''Settings'',''Style'','''',''.\MyApp.INI'')')
      #DISPLAY('')
      #DISPLAY('Colours come from [<<set> Window], else [<<set> Default]:')
      #DISPLAY('ListColor / ListFontColor (the days), GridColor, BackgroundColor,')
      #DISPLAY('TextFontColor, InactiveTabFontColor (weekends), FlatButtons,')
      #DISPLAY('ButtonFontColor. The band section, if named, gives the top band')
      #DISPLAY('BgColor / BgColorEnd / FontColor, and the accent (month names,')
      #DISPLAY('the picked day) from its BarStartColor; without one the accent')
      #DISPLAY('is the optional AccentFontColor key. Colours are #RRGGBB.')
    #ENDBOXED
  #ENDTAB
#ENDSHEET
#!
#AT(%AfterGlobalIncludes),WHERE(%mdgDisable=0)
INCLUDE('MyCalendarClass.INC'),ONCE
#ENDAT
#!
#! The application-wide defaults, as real globals the per-window code reads.
#! Control templates default to these, and may override them per button.
#AT(%GlobalData),WHERE(%mdgDisable=0)
#IF(%mdgLanguage)
myCalendarLanguage   BYTE(%mdgLanguage)                   ! 1 = English, 2 = Espanol
#ELSE
myCalendarLanguage   BYTE(1)                              ! 1 = English, 2 = Espanol
#ENDIF
#IF(%mdgFirstDay)
myCalendarFirstDay   BYTE(%mdgFirstDay)                   ! 0 = Sunday, 1 = Monday
#ELSE
myCalendarFirstDay   BYTE(0)                              ! 0 = Sunday, 1 = Monday
#ENDIF
#IF(%mdgView)
myCalendarView       BYTE(%mdgView)                       ! months on screen: 1 2 3 6 12
#ELSE
myCalendarView       BYTE(1)                              ! months on screen: 1 2 3 6 12
#ENDIF
#IF(%mdgOrient)
myCalendarOrient     BYTE(%mdgOrient)                     ! 0 = across, 1 = down
#ELSE
myCalendarOrient     BYTE(0)                              ! 0 = across, 1 = down
#ENDIF
myCalendarWeekNo     BYTE(%mdgWeekNo)                     ! show the week-number gutter
#ENDAT
#!#############################################################################
#!  CONTROL TEMPLATE - myCalendarButton  -  a calendar beside a date field
#!#############################################################################
#!  Drops a small button and wires the whole calendar to it. The target field's
#!  USE variable is read at generate time out of the control's own USE attribute
#!  - EXTRACT(%ControlStatement,'USE',1), the same call the shipped ABDROPS.TPW
#!  makes - so there is nothing to type and nothing to keep in sync.
#!
#!  The button's own field equate is captured with the shipped
#!  #FOR(%Control),WHERE(%ControlInstance=%ActiveTemplateInstance) idiom
#!  (corpus: CONTROL.TPW:107) so MULTI drops keep working.
#!#############################################################################
#CONTROL(myCalendarButton,'myCalendar - Calendar button beside a date field'),WINDOW,MULTI,REQ(myCalendarGlobal),DESCRIPTION('Calendar for ' & %mdField),HLP('~myCalendar.htm')
  CONTROLS
    BUTTON(''),AT(,,14,12),USE(?CalBtn),ICON('cal16.ico'),TIP('Open the calendar')
  END
#SHEET
  #TAB('&General')
    #BOXED('Object')
      #PROMPT('&Disable this calendar',CHECK),%mdDisable,DEFAULT(0),AT(10)
      #PROMPT('&Object name:',@s64),%mdObject,REQ,DEFAULT('Cal' & %ActiveTemplateInstance)
    #ENDBOXED
    #BOXED('What the user picks')
      #PROMPT('&Pick:',DROP('One date[0]|A from-and-to range (drag across the days)[1]')),%mdRange,DEFAULT('0')
      #BOXED('One date'),WHERE(%mdRange='0')
        #PROMPT('&Date field to fill in:',CONTROL),%mdField,REQ
        #DISPLAY('The date ENTRY this button sits beside. The calendar opens on')
        #DISPLAY('whatever the field holds, and Accept puts the date back.')
      #ENDBOXED
      #BOXED('A range'),WHERE(%mdRange='1')
        #PROMPT('&From date field:',CONTROL),%mdField
        #PROMPT('&To date field:',CONTROL),%mdField2
        #DISPLAY('One button, two fields. The user drags across the days - over')
        #DISPLAY('as many months as are on screen - and Accept writes the first')
        #DISPLAY('day into the FROM field and the last into the TO field.')
        #DISPLAY('Every press starts a fresh range: pressing on a day clears')
        #DISPLAY('whatever was marked and anchors there. Sweep either way.')
      #ENDBOXED
      #PROMPT('&Window title (blank = the localised name):',@s64),%mdTitle,DEFAULT('')
    #ENDBOXED
  #ENDTAB
  #TAB('&View')
    #BOXED('How much is on screen')
      #PROMPT('&Months:',DROP('Use the application setting[0]|One month[1]|Two months[2]|Three months[3]|Six months[6]|Full year[12]')),%mdMonths,DEFAULT('0')
      #PROMPT('&Stack them:',DROP('Use the application setting[9]|Across (side by side)[0]|Down (one under the other)[1]')),%mdOrient,DEFAULT('9')
      #DISPLAY('Two and three months can go either way: across for a wide, short')
      #DISPLAY('window, down for a tall, narrow one. Six goes 3x2 or 2x3, and a')
      #DISPLAY('full year 4x3 or 3x4. The user can change both in the window,')
      #DISPLAY('and the choice comes back next time (see the Remember tab).')
    #ENDBOXED
    #BOXED('The week')
      #PROMPT('&First day of the week:',DROP('Use the application setting[9]|Sunday[0]|Monday[1]')),%mdFirstDay,DEFAULT('9')
      #PROMPT('Show &week numbers:',DROP('Use the application setting[9]|No[0]|Yes[1]')),%mdWeekNo,DEFAULT('9')
      #PROMPT('&Ring today''s date',CHECK),%mdToday,DEFAULT(1),AT(10)
    #ENDBOXED
    #BOXED('Language')
      #PROMPT('&Language:',DROP('Use the application setting[0]|English[1]|Español (Spanish)[2]')),%mdLang,DEFAULT('0')
      #DISPLAY('The application setting lives on the myCalendar - Global')
      #DISPLAY('extension, and is what every calendar uses unless you say here.')
    #ENDBOXED
  #ENDTAB
  #TAB('&Limits')
    #BOXED('Which days may be picked')
      #PROMPT('&Weekends cannot be picked',CHECK),%mdNoWeekends,DEFAULT(0),AT(10)
      #DISPLAY('Saturdays and Sundays are drawn greyed and ignore the mouse.')
      #DISPLAY('')
      #PROMPT('&Earliest date allowed (blank = no limit):',@s64),%mdMin,DEFAULT('')
      #PROMPT('&Latest date allowed (blank = no limit):',@s64),%mdMax,DEFAULT('')
      #DISPLAY('Anything the compiler will take: TODAY(), TODAY()+30,')
      #DISPLAY('DATE(1,1,2020) or a variable such as ORD:OrderDate.')
      #DISPLAY('')
      #PROMPT('Date &picture (how dates read in the footer):',@s16),%mdPic,DEFAULT('@d17')
    #ENDBOXED
  #ENDTAB
  #TAB('&Remember')
    #BOXED('Remember the last session')
      #PROMPT('Remember the &view and options between runs',CHECK),%mdPersist,DEFAULT(1),AT(10)
      #DISPLAY('Saves how many months were on screen, whether they were stacked')
      #DISPLAY('across or down, the first day of the week, the week-number')
      #DISPLAY('gutter and the today ring - and restores them the next time the')
      #DISPLAY('program runs. Each profile has its own saved settings.')
      #ENABLE(%mdPersist)
        #PROMPT('&Profile name (blank = this procedure):',@s64),%mdProfile,DEFAULT('')
        #PROMPT('&INI file (blank = the application''s own .INI):',@s128),%mdIni,DEFAULT('')
      #ENDENABLE
    #ENDBOXED
  #ENDTAB
#ENDSHEET
#!-----------------------------------------------------------------------------
#ATSTART
  #DECLARE(%mdBtn)
  #FOR(%Control),WHERE(%ControlInstance=%ActiveTemplateInstance)
    #SET(%mdBtn,%Control)
  #ENDFOR
  #DECLARE(%mdVar)
  #FOR(%Control),WHERE(%Control=%mdField)
    #SET(%mdVar,EXTRACT(%ControlStatement,'USE',1))
  #ENDFOR
  #DECLARE(%mdVar2)
  #FOR(%Control),WHERE(%Control=%mdField2)
    #SET(%mdVar2,EXTRACT(%ControlStatement,'USE',1))
  #ENDFOR
  #!  A range needs both fields; one date needs one. %mdReady says we can emit.
  #DECLARE(%mdReady)
  #SET(%mdReady,0)
  #IF(%mdRange='1')
    #IF(%mdVar AND %mdVar2)
      #SET(%mdReady,1)
    #ENDIF
  #ELSE
    #IF(%mdVar)
      #SET(%mdReady,1)
    #ENDIF
  #ENDIF
#ENDAT
#!
#! Self-contained: pull in the class (,ONCE = safe alongside the global extension).
#AT(%CustomGlobalDeclarations),WHERE(%mdDisable=0)
INCLUDE('MyCalendarClass.INC'),ONCE
#ENDAT
#!
#AT(%DataSection),WHERE(%mdDisable=0 AND %mdReady)
#IF(%mdRange='1')
%mdObject            MyCalendarClass                        ! calendar for %mdField .. %mdField2
#ELSE
%mdObject            MyCalendarClass                        ! calendar for %mdField
#ENDIF
#ENDAT
#!
#AT(%ControlEventHandling,%mdBtn,'Accepted'),WHERE(%mdDisable=0 AND %mdReady)
#IF(%mdTitle)
  %mdObject.Title       = '%mdTitle'
#ENDIF
#IF(%mdMonths AND %mdMonths <> '0')
  %mdObject.Months      = %mdMonths                        ! this button overrides
#ELSE
  %mdObject.Months      = myCalendarView                   ! whatever the global says
#ENDIF
#IF(%mdOrient <> '9')
  %mdObject.Orient      = %mdOrient
#ELSE
  %mdObject.Orient      = myCalendarOrient
#ENDIF
#IF(%mdFirstDay <> '9')
  %mdObject.FirstDay    = %mdFirstDay
#ELSE
  %mdObject.FirstDay    = myCalendarFirstDay
#ENDIF
#IF(%mdWeekNo <> '9')
  %mdObject.ShowWeekNo  = %mdWeekNo
#ELSE
  %mdObject.ShowWeekNo  = myCalendarWeekNo
#ENDIF
#IF(%mdLang AND %mdLang <> '0')
  %mdObject.Language    = %mdLang                          ! this button overrides
#ELSE
  %mdObject.Language    = myCalendarLanguage               ! whatever the global says
#ENDIF
  %mdObject.ShowToday   = %mdToday
  %mdObject.NoWeekends  = %mdNoWeekends
#IF(%mdMin)
  %mdObject.MinDate     = %mdMin
#ENDIF
#IF(%mdMax)
  %mdObject.MaxDate     = %mdMax
#ENDIF
#IF(%mdPic)
  %mdObject.DatePicture = '%mdPic'
#ENDIF
#IF(%mdPersist)
  %mdObject.Persist     = 1                                ! remember the view
#IF(%mdProfile)
  %mdObject.Profile     = '%mdProfile'
#ELSE
  %mdObject.Profile     = '%Procedure'
#ENDIF
#IF(%mdIni)
  %mdObject.IniFile     = '%mdIni'
#ENDIF
#ENDIF
#! The theme lives in the global extension: another scope, so #CONTEXT to reach
#! it (precedent: BrowseGrid.tpl; CRTABCRPT.TPW:66). VAREXISTS = no global.
#DECLARE(%mdStyleU)
#DECLARE(%mdStyleSetU)
#DECLARE(%mdBandU)
#CONTEXT(%Application)
  #IF(VAREXISTS(%mdgStyleFile))
    #SET(%mdStyleU,%mdgStyleFile)
    #SET(%mdStyleSetU,%mdgStyleSet)
    #SET(%mdBandU,%mdgBandSection)
  #ENDIF
#ENDCONTEXT
#IF(%mdStyleU)
  %mdObject.StyleFile   = %mdStyleU                  ! follow the Makeover theme
#IF(%mdStyleSetU)
  %mdObject.StyleSet    = '%mdStyleSetU'
#ENDIF
#IF(%mdBandU)
  %mdObject.BandSection = '%mdBandU'
#ENDIF
#ENDIF
#EMBED(%myCalendarBeforeOpen,'myCalendar - before the calendar opens'),%ActiveTemplateInstance,HIDE
#IF(%mdRange='1')
  IF %mdObject.AskRange(%mdVar,%mdVar2)                    ! seeds from both fields, writes both back
    DISPLAY(%mdField)
    DISPLAY(%mdField2)
#ELSE
  IF %mdObject.AskFor(%mdVar)                              ! seeds from the field, writes it back
    DISPLAY(%mdField)
#ENDIF
#EMBED(%myCalendarAfterAccept,'myCalendar - after the date was accepted'),%ActiveTemplateInstance,HIDE
  END
#ENDAT
#!#############################################################################
#!  CODE TEMPLATE - myCalendarHere  -  open the calendar from any embed
#!#############################################################################
#!  ,PROCEDURE lets a #CODE template own procedure-scope #AT sections (corpus:
#!  ABPOPUP.TPW:1), which is how it declares its own object in %DataSection.
#!#############################################################################
#CODE(myCalendarHere,'myCalendar - Open the calendar and return a date'),MULTI,PROCEDURE,REQ(myCalendarGlobal),DESCRIPTION('Calendar into ' & %mnTarget),HLP('~myCalendar.htm')
#SHEET
  #TAB('&General')
    #BOXED('Object')
      #PROMPT('&Object name:',@s64),%mnObject,REQ,DEFAULT('Cal' & %ActiveTemplateInstance)
    #ENDBOXED
    #BOXED('Where the date goes')
      #PROMPT('&Pick:',DROP('One date[0]|A from-and-to range (drag across the days)[1]')),%mnRange,DEFAULT('0')
      #PROMPT('&Variable / field to fill in:',@s128),%mnTarget,REQ
      #DISPLAY('Any DATE (or LONG) variable or file field, e.g. ORD:DueDate or')
      #DISPLAY('LOC:StartDate. It seeds the calendar and receives the answer.')
      #BOXED('A range'),WHERE(%mnRange='1')
        #PROMPT('&Second variable (the TO date):',@s128),%mnTarget2
      #ENDBOXED
      #PROMPT('&Refresh this control afterwards:',CONTROL),%mnRefresh
      #PROMPT('&Window title (blank = the localised name):',@s64),%mnTitle,DEFAULT('')
    #ENDBOXED
  #ENDTAB
  #TAB('&View')
    #BOXED('How much is on screen')
      #PROMPT('&Months:',DROP('Use the application setting[0]|One month[1]|Two months[2]|Three months[3]|Six months[6]|Full year[12]')),%mnMonths,DEFAULT('0')
      #PROMPT('&Stack them:',DROP('Use the application setting[9]|Across[0]|Down[1]')),%mnOrient,DEFAULT('9')
      #PROMPT('&First day of the week:',DROP('Use the application setting[9]|Sunday[0]|Monday[1]')),%mnFirstDay,DEFAULT('9')
      #PROMPT('Show &week numbers:',DROP('Use the application setting[9]|No[0]|Yes[1]')),%mnWeekNo,DEFAULT('9')
      #PROMPT('&Ring today''s date',CHECK),%mnToday,DEFAULT(1),AT(10)
      #PROMPT('&Language:',DROP('Use the application setting[0]|English[1]|Español (Spanish)[2]')),%mnLang,DEFAULT('0')
    #ENDBOXED
  #ENDTAB
  #TAB('&Limits')
    #BOXED('Which days may be picked')
      #PROMPT('&Weekends cannot be picked',CHECK),%mnNoWeekends,DEFAULT(0),AT(10)
      #PROMPT('&Earliest date allowed (blank = no limit):',@s64),%mnMin,DEFAULT('')
      #PROMPT('&Latest date allowed (blank = no limit):',@s64),%mnMax,DEFAULT('')
      #PROMPT('Remember the &view between runs',CHECK),%mnPersist,DEFAULT(1),AT(10)
      #ENABLE(%mnPersist)
        #PROMPT('&Profile name (blank = this procedure):',@s64),%mnProfile,DEFAULT('')
      #ENDENABLE
    #ENDBOXED
  #ENDTAB
#ENDSHEET
#!-----------------------------------------------------------------------------
#AT(%CustomGlobalDeclarations)
INCLUDE('MyCalendarClass.INC'),ONCE
#ENDAT
#!
#AT(%DataSection),WHERE(%mnTarget)
%mnObject            MyCalendarClass                        ! calendar into %mnTarget
#ENDAT
#!
#! ...and the code template's own output, right where it was dropped:
#IF(%mnTarget AND (%mnRange='0' OR %mnTarget2))
#IF(%mnTitle)
%mnObject.Title       = '%mnTitle'
#ENDIF
#IF(%mnMonths AND %mnMonths <> '0')
%mnObject.Months      = %mnMonths
#ELSE
%mnObject.Months      = myCalendarView
#ENDIF
#IF(%mnOrient <> '9')
%mnObject.Orient      = %mnOrient
#ELSE
%mnObject.Orient      = myCalendarOrient
#ENDIF
#IF(%mnFirstDay <> '9')
%mnObject.FirstDay    = %mnFirstDay
#ELSE
%mnObject.FirstDay    = myCalendarFirstDay
#ENDIF
#IF(%mnWeekNo <> '9')
%mnObject.ShowWeekNo  = %mnWeekNo
#ELSE
%mnObject.ShowWeekNo  = myCalendarWeekNo
#ENDIF
#IF(%mnLang AND %mnLang <> '0')
%mnObject.Language    = %mnLang
#ELSE
%mnObject.Language    = myCalendarLanguage
#ENDIF
%mnObject.ShowToday   = %mnToday
%mnObject.NoWeekends  = %mnNoWeekends
#IF(%mnMin)
%mnObject.MinDate     = %mnMin
#ENDIF
#IF(%mnMax)
%mnObject.MaxDate     = %mnMax
#ENDIF
#IF(%mnPersist)
%mnObject.Persist     = 1
#IF(%mnProfile)
%mnObject.Profile     = '%mnProfile'
#ELSE
%mnObject.Profile     = '%Procedure'
#ENDIF
#ENDIF
#! The theme lives in the global extension: another scope, so #CONTEXT to reach
#! it (precedent: BrowseGrid.tpl; CRTABCRPT.TPW:66). VAREXISTS = no global.
#DECLARE(%mnStyleU)
#DECLARE(%mnStyleSetU)
#DECLARE(%mnBandU)
#CONTEXT(%Application)
  #IF(VAREXISTS(%mdgStyleFile))
    #SET(%mnStyleU,%mdgStyleFile)
    #SET(%mnStyleSetU,%mdgStyleSet)
    #SET(%mnBandU,%mdgBandSection)
  #ENDIF
#ENDCONTEXT
#IF(%mnStyleU)
%mnObject.StyleFile   = %mnStyleU                  ! follow the Makeover theme
#IF(%mnStyleSetU)
%mnObject.StyleSet    = '%mnStyleSetU'
#ENDIF
#IF(%mnBandU)
%mnObject.BandSection = '%mnBandU'
#ENDIF
#ENDIF
#IF(%mnRange='1')
IF %mnObject.AskRange(%mnTarget,%mnTarget2)
#ELSE
IF %mnObject.AskFor(%mnTarget)
#ENDIF
#IF(%mnRefresh)
  DISPLAY(%mnRefresh)
#ENDIF
END
#ELSE
! myCalendar: fill in the target variable(s) in the code template's prompts.
#ENDIF
#!-----------------------------------------------------------------------------
#! End of myCalendar template set
#!-----------------------------------------------------------------------------
