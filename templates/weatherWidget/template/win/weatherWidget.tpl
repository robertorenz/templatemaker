#TEMPLATE(weatherWidget,'weatherWidget - The weather, on a card at start-up - v1.0'),FAMILY('ABC')
#!-----------------------------------------------------------------------------
#!  weatherWidget
#!  Roberto Renz - 2026
#!
#!  Puts a weather card on the screen when your application starts: where the
#!  user is, what it is doing outside, what it feels like, and the next few
#!  days. It closes itself after n seconds, or waits to be closed.
#!
#!  THE TEMPLATES
#!    weatherWidget       (APPLICATION) - add it once. It declares the object,
#!                        fills it in from the prompts, and shows the card at
#!                        program start. THIS IS THE ONLY ONE YOU NEED.
#!    weatherWidgetHere   (CODE)        - show the card from any embed: a menu
#!                        item, a button, a hot key. Uses the same object and
#!                        the same settings.
#!
#!  WHERE THE WEATHER COMES FROM
#!    api.open-meteo.com - free, and no API key or registration of any kind.
#!    The place is either looked up from the machine's public IP (ipwho.is) or
#!    geocoded from a city name (Open-Meteo's own geocoder), and both answers
#!    are kept for a day so start-up normally costs ONE request.
#!    The download is curl.exe, which ships with Windows 10 and 11.
#!
#!  *** PRIVACY / INTERNET - TELL YOUR USERS ***
#!    Locating by IP sends the machine's public address to a third party.
#!    A city name is sent to Open-Meteo's geocoder. The coordinates are sent
#!    to Open-Meteo. Nothing else leaves the machine, and nothing personal is
#!    sent. See the Instructions tab.
#!
#!  REQUIRED FILES: copy these (shipped beside this .tpl) to a folder on the
#!  Clarion redirection path (the app folder, or the accessory libsrc), ANSI:
#!      MyWeatherClass.inc   MyWeatherClass.clw
#!  MyWeatherClass.clw is pulled into the build by its LINK attribute.
#!
#!  API (the object is global - call it from any embed):
#!    Weather.Ask()          fetch if needed, then show the card
#!    Weather.Fetch()        just get a reading (cache first)
#!    Weather.Refresh()      get a reading, ignoring the cache
#!    Weather.Temp / .Feels / .Humidity / .Wind / .WCode / .Place ...
#!    Weather.Describe(Weather.WCode)   the conditions, in words
#!-----------------------------------------------------------------------------
#SYSTEM
  #EQUATE(%weatherWidgetVersion,'1.0')
#!#############################################################################
#!  APPLICATION EXTENSION - weatherWidget
#!#############################################################################
#EXTENSION(weatherWidget,'weatherWidget - The weather at start-up (add once per application)'),APPLICATION,HLP('~weatherWidget.htm')
#SHEET,ADJUST
  #TAB('&General')
    #BOXED('About'),SECTION
      #DISPLAY('weatherWidget for Clarion  v' & %weatherWidgetVersion)
      #DISPLAY('A weather card when your program starts: the temperature now,')
      #DISPLAY('what it feels like, humidity, wind, rain, sunrise and sunset,')
      #DISPLAY('and up to seven days ahead. Everything on it is drawn - there')
      #DISPLAY('are no image files to ship.')
      #DISPLAY('')
      #DISPLAY('Copy MyWeatherClass.inc and MyWeatherClass.clw to the')
      #DISPLAY('redirection path (the app folder, or the accessory libsrc).')
      #DISPLAY('Both files must be ANSI. MyWeatherClass.clw links itself in.')
    #ENDBOXED
    #BOXED('Options'),AT(,,250)
      #PROMPT('&Disable this template',CHECK),%wwDisable,DEFAULT(0),AT(10)
      #PROMPT('&Object name:',@s64),%wwObject,REQ,DEFAULT('WeatherWidget')
      #PROMPT('Show the card &when the program starts',CHECK),%wwAtStartup,DEFAULT(1),AT(10)
      #ENABLE(%wwAtStartup)
        #DISPLAY('The card goes up before the frame opens, and the program')
        #DISPLAY('carries on the moment it closes.')
      #ENDENABLE
      #PROMPT('&Title (blank = "Weather" / "El tiempo"):',@s64),%wwTitle,DEFAULT('')
      #PROMPT('&Close it automatically after (seconds, 0 = wait for the user):',SPIN(@n3,0,300,1)),%wwAutoClose,DEFAULT(0),PROMPTAT(8),AT(196,,40)
    #ENDBOXED
  #ENDTAB
  #TAB('&Place')
    #BOXED('Where the weather is for')
      #PROMPT('&Find the place by:',DROP('The machine''s internet address[0]|A city name[1]|Latitude and longitude[2]')),%wwLocate,DEFAULT('0')
      #BOXED('By address'),WHERE(%wwLocate='0')
        #DISPLAY('ipwho.is is asked which city this machine appears to be in.')
        #DISPLAY('Free, no key. It is a rough answer - the right city, usually')
        #DISPLAY('not the right suburb - which is exactly right for weather.')
        #DISPLAY('The answer is kept for a day, so this costs one request per')
        #DISPLAY('day, not one per start-up.')
      #ENDBOXED
      #BOXED('By name'),WHERE(%wwLocate='1')
        #PROMPT('&City:',@s64),%wwCity,DEFAULT('')
        #DISPLAY('A place name Open-Meteo''s geocoder can find: Monterrey,')
        #DISPLAY('Cape Town, Bergen. Add a country if the name is ambiguous.')
        #DISPLAY('Also kept for a day.')
      #ENDBOXED
      #BOXED('By coordinate'),WHERE(%wwLocate='2')
        #PROMPT('&Latitude:',@s20),%wwLat,DEFAULT('25.6866')
        #PROMPT('L&ongitude:',@s20),%wwLon,DEFAULT('-100.3161')
        #DISPLAY('Decimal degrees, north and east positive. Nothing is looked')
        #DISPLAY('up - this is the one setting that needs no geocoding.')
        #DISPLAY('Either box may be a variable instead of a number, if the')
        #DISPLAY('coordinates come from your own data.')
      #ENDBOXED
    #ENDBOXED
  #ENDTAB
  #TAB('&Card')
    #BOXED('Units and language')
      #PROMPT('&Units:',DROP('Metric - C, km/h, mm[0]|Imperial - F, mph, in[1]')),%wwUnits,DEFAULT('0')
      #PROMPT('&Language:',DROP('English[1]|Espa<241>ol (Spanish)[2]')),%wwLanguage,DEFAULT('1')
    #ENDBOXED
    #BOXED('What is on it')
      #PROMPT('&Forecast days (0 = none):',SPIN(@n1,0,7,1)),%wwDays,DEFAULT(5),PROMPTAT(8),AT(140,,40)
      #PROMPT('What it &feels like',CHECK),%wwShowFeels,DEFAULT(1),AT(10)
      #PROMPT('&Humidity',CHECK),%wwShowHumidity,DEFAULT(1),AT(10)
      #PROMPT('&Wind',CHECK),%wwShowWind,DEFAULT(1),AT(10)
      #PROMPT('&Rain',CHECK),%wwShowPrecip,DEFAULT(1),AT(10)
      #PROMPT('&Sunrise and sunset',CHECK),%wwShowSun,DEFAULT(1),AT(10)
      #DISPLAY('The card is only as tall as what you leave on it: turn the')
      #DISPLAY('forecast off and it shrinks to the sky band and the readings.')
    #ENDBOXED
  #ENDTAB
  #TAB('&Network')
    #BOXED('Getting the weather')
      #PROMPT('&Give up after (seconds):',SPIN(@n3,1,60,1)),%wwTimeout,DEFAULT(6),PROMPTAT(8),AT(160,,40)
      #DISPLAY('How long any one download may take. This is what stops a dead')
      #DISPLAY('connection holding your program''s start-up up.')
      #PROMPT('Re-&use a reading younger than (minutes, 0 = always fetch):',SPIN(@n4,0,1440,5)),%wwCache,DEFAULT(30),PROMPTAT(8),AT(160,,40)
      #DISPLAY('A reading younger than this is taken from the INI and no')
      #DISPLAY('request is made at all - so restarting the program five times')
      #DISPLAY('in an hour does not mean five round trips.')
      #PROMPT('&Remember the last reading between runs',CHECK),%wwPersist,DEFAULT(1),AT(10)
    #ENDBOXED
    #BOXED('When there is no answer')
      #PROMPT('If the weather cannot be fetched:',DROP('Show nothing at all[0]|Show the last reading kept[1]|Show the card, with the fault on it[2]')),%wwOnFail,DEFAULT('1')
      #DISPLAY('"Show nothing" is the quiet one: a laptop with no connection')
      #DISPLAY('starts your program exactly as it always did, with no card and')
      #DISPLAY('no message.')
    #ENDBOXED
  #ENDTAB
  #TAB('&Class')
    #BOXED('Where the class lives')
      #DISPLAY('MyWeatherClass is filed under its own category, MYWEATHER, so')
      #DISPLAY('an application can decide where its code lives - and in a')
      #DISPLAY('multi-DLL suite one DLL can own it and export it while the')
      #DISPLAY('others import it.')
      #DISPLAY('')
      #DISPLAY('The default is right for almost everyone: leave it alone.')
    #ENDBOXED
    #BOXED('Override - place the class by hand')
      #INSERT(%AbcLibraryPrompts(ABC))
      #DISPLAY('')
      #DISPLAY('Linked in   - compile MyWeatherClass.clw into this app (and,')
      #DISPLAY('              if this app is a DLL, export the class from it).')
      #DISPLAY('External DLL- import the class from another DLL in the suite.')
      #DISPLAY('External LIB- link against a .LIB you built yourself.')
      #DISPLAY('None        - do neither; add the .clw to the project yourself.')
    #ENDBOXED
  #ENDTAB
  #TAB('&Instructions')
    #BOXED('How to use weatherWidget')
      #DISPLAY('SETUP')
      #DISPLAY('1. Copy MyWeatherClass.inc and MyWeatherClass.clw to a folder')
      #DISPLAY('   on the redirection path (the app folder, or the accessory')
      #DISPLAY('   libsrc). Both must be ANSI.')
      #DISPLAY('2. Add THIS extension to the application (Global Properties,')
      #DISPLAY('   Extensions, Insert) - once, not per procedure.')
      #DISPLAY('3. On the Place tab say how the place is worked out.')
      #DISPLAY('4. Generate, build, run. The card comes up at start-up.')
      #DISPLAY('')
      #DISPLAY('FROM YOUR OWN CODE')
      #DISPLAY('- The object is global. Anywhere in the application:')
      #DISPLAY('      WeatherWidget.Ask()        fetch if needed, show the card')
      #DISPLAY('      WeatherWidget.Refresh()    force a fresh reading')
      #DISPLAY('  and afterwards WeatherWidget.Temp, .Feels, .Humidity, .Wind,')
      #DISPLAY('  .Place, .Sunrise, .Sunset, .WCode, and')
      #DISPLAY('      WeatherWidget.Describe(WeatherWidget.WCode)')
      #DISPLAY('  which is the conditions in the chosen language.')
      #DISPLAY('- To hang it off a menu item or a button, put the code template')
      #DISPLAY('  "weatherWidget - Show the weather now" in its embed.')
      #ENDBOXED
    #ENDTAB
    #TAB('N&otes')
      #BOXED('Curl, privacy and start-up')
      #DISPLAY('CURL')
      #DISPLAY('- The download is curl.exe, which ships with Windows 10 and 11')
      #DISPLAY('  in %%SystemRoot%%\System32. It is run HIDDEN, so nothing')
      #DISPLAY('  flashes on screen. On an older Windows without curl the card')
      #DISPLAY('  reports "curl.exe was not found" and nothing else breaks.')
      #DISPLAY('')
      #DISPLAY('PRIVACY / INTERNET (READ THIS, AND TELL YOUR USERS)')
      #DISPLAY('- Locating by the machine''s address sends its PUBLIC IP to')
      #DISPLAY('  ipwho.is, a third party, and gets back a city.')
      #DISPLAY('- A city name is sent to Open-Meteo''s geocoder.')
      #DISPLAY('- The coordinates are sent to api.open-meteo.com.')
      #DISPLAY('- Nothing else leaves the machine. No account, no key, no')
      #DISPLAY('  personal data - but it IS an outbound connection at start-up,')
      #DISPLAY('  which some sites do not allow. If yours is one of them, pick')
      #DISPLAY('  "Latitude and longitude" so no lookup is made, or leave the')
      #DISPLAY('  template disabled.')
      #DISPLAY('- Open-Meteo asks for attribution; the card carries it.')
      #DISPLAY('')
      #DISPLAY('START-UP COST')
      #DISPLAY('- The fetch is synchronous: the program waits for it. Worst')
      #DISPLAY('  case is two downloads, so keep "give up after" short (6')
      #DISPLAY('  seconds is the default) and leave the cache on.')
    #ENDBOXED
  #ENDTAB
#ENDSHEET
#!-----------------------------------------------------------------------------
#! The class, and the object every procedure can reach.
#!-----------------------------------------------------------------------------
#AT(%AfterGlobalIncludes),WHERE(%wwDisable=0)
INCLUDE('MyWeatherClass.INC'),ONCE
#ENDAT
#!
#! Global DATA gets the multi-DLL treatment: defined in the app that owns the
#! data, EXTERNAL everywhere else (corpus: cleansdw.tpw:25 uses these same ABC
#! symbols; %MultiDLL / %RootDLL are NOT built-in).
#AT(%GlobalData),WHERE(%wwDisable=0)
  #IF(%DefaultExternal = 'None External')
%wwObject            MyWeatherClass
  #ELSE
%wwObject            MyWeatherClass,EXTERNAL,DLL(dll_mode)
  #ENDIF
#ENDAT
#!
#AT(%DLLExportList),WHERE(%wwDisable=0)
  #IF(%DefaultExternal = 'None External' AND %ProgramExtension='DLL' AND %DefaultExport)
  $%wwObject                                               @?
  #ENDIF
#ENDAT
#!-----------------------------------------------------------------------------
#!  MULTI-DLL. MyWeatherClass carries !ABCIncludeFile(MYWEATHER) on line 1, so
#!  the IDE's class registry files it under category MYWEATHER. Registering
#!  that category here hands the whole job to the shipped ABC machinery:
#!
#!    ABPROGRM.TPW:88  #CALL(%DefineCategoryPragmas) writes the project defines
#!                     _myWeatherLinkMode_ / _myWeatherDllMode_ that the
#!                     class's LINK() and DLL() attributes read.
#!    ABBLDEXP.TPW     while building the .EXP of a DLL, walks the registry and
#!                     emits VMT$ / TYPE$ / every non-private method - name
#!                     mangled by LINKNAME().
#!
#!  Which is why nothing here lists a mangled symbol: add a method to the class
#!  and the export list follows on the next generate.
#!
#!  NOTE FOR HAND-CODED PROJECTS (the demo hit this): without those two defines
#!  the DLL() attribute is NOT read as 0 - the class links as an import and the
#!  constructor jumps into nothing at start-up ("Exception ... Access
#!  Violation"). A generated application always has them. A hand-written
#!  .cwproj needs  _myWeatherDllMode_=>0  and  _myWeatherLinkMode_=>1  in its
#!  DefineConstants.
#!-----------------------------------------------------------------------------
#AT(%BeforeGenerateApplication),WHERE(%wwDisable=0)
  #CALL(%AddCategory(ABC),'MYWEATHER')
  #CALL(%SetCategoryLocationFromPrompts(ABC),'MYWEATHER','myWeather','')
#ENDAT
#!-----------------------------------------------------------------------------
#! Everything the developer chose, written into the object at program start,
#! and then - if they asked for it - the card.
#!
#! The settings are written even when the card is NOT shown at start-up, so a
#! later WeatherWidget.Ask() from an embed or from the code template finds the
#! object already configured.
#!
#! In a multi-DLL suite the object lives in the data DLL and is EXTERNAL here,
#! so only the app that OWNS the data should configure it - which is the app
#! this extension is in.
#!-----------------------------------------------------------------------------
#AT(%ProgramSetup),PRIORITY(7000),WHERE(%wwDisable=0),DESCRIPTION('weatherWidget - settings, and the start-up card')
  #IF(%DefaultExternal = 'None External')
%wwObject.Locate       = %wwLocate
    #IF(%wwLocate = '1')
%wwObject.City         = '%wwCity'
    #ELSIF(%wwLocate = '2')
%wwObject.Lat          = %wwLat                            ! emitted as written - a number, or your own variable
%wwObject.Lon          = %wwLon
    #ENDIF
%wwObject.Units        = %wwUnits
%wwObject.Language     = %wwLanguage
%wwObject.Days         = %wwDays
%wwObject.ShowFeels    = %wwShowFeels
%wwObject.ShowHumidity = %wwShowHumidity
%wwObject.ShowWind     = %wwShowWind
%wwObject.ShowPrecip   = %wwShowPrecip
%wwObject.ShowSun      = %wwShowSun
%wwObject.AutoClose    = %wwAutoClose
%wwObject.Timeout      = %wwTimeout
%wwObject.CacheMinutes = %wwCache
%wwObject.Persist      = %wwPersist
%wwObject.OnFail       = %wwOnFail
    #IF(%wwTitle)
%wwObject.Title        = '%wwTitle'
    #ENDIF
    #IF(%wwAtStartup)
%wwObject.Ask()                                            ! the card - the program waits for it
    #ENDIF
  #ELSE
! weatherWidget: the object lives in the data DLL, which is where it is
! configured and where the start-up card is shown.
  #ENDIF
#ENDAT
#!#############################################################################
#!  CODE TEMPLATE - weatherWidgetHere - the card, from any embed
#!#############################################################################
#CODE(weatherWidgetHere,'weatherWidget - Show the weather now'),HLP('~weatherWidget.htm')
#BOXED('Show the weather')
  #DISPLAY('Puts the same card up from wherever this embed is: a menu item, a')
  #DISPLAY('button, a hot key. It uses the object and the settings the')
  #DISPLAY('weatherWidget application extension already set up, so there is')
  #DISPLAY('nothing to configure twice.')
  #DISPLAY('')
  #PROMPT('&Object name:',@s64),%wwHereObject,REQ,DEFAULT('WeatherWidget')
  #PROMPT('&Get a fresh reading first (ignore the cache)',CHECK),%wwHereForce,DEFAULT(0),AT(10)
  #DISPLAY('')
  #DISPLAY('Ticked, this always goes to the network - which is what a')
  #DISPLAY('"Refresh" menu item should do. Unticked, a reading younger than')
  #DISPLAY('the cache setting is reused and no request is made.')
  #DISPLAY('')
  #DISPLAY('REQUIRES the weatherWidget application extension, which is what')
  #DISPLAY('declares the object.')
#ENDBOXED
#IF(%wwHereForce)
%wwHereObject.Refresh()                                    ! always hits the network
#ENDIF
%wwHereObject.Ask()
