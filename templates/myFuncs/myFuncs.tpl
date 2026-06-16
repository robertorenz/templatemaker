#TEMPLATE(myFuncs,'myFuncs - Global Function Library v1.20'),FAMILY('ABC')
#!-----------------------------------------------------------------------------!
#!  myFuncs  -  (c) 2026 Reddin Assessments                                    !
#!                                                                             !
#!  A GLOBAL (APPLICATION-scope) extension that makes a growing library of      !
#!  utility FUNCTIONS callable from anywhere in the app, with no per-procedure  !
#!  setup and NO external source files.                                         !
#!                                                                             !
#!  How it works (the robust, self-contained pattern):                         !
#!    * #AT(%GlobalMap)        - adds each prototype, BARE, to the program's    !
#!                               global MAP. Bare (no MODULE wrapper) means      !
#!                               "defined in the program module", and it makes   !
#!                               the function callable from every procedure.    !
#!    * #AT(%ProgramProcedures)- writes each function BODY into the program     !
#!                               module itself. Prototype + body in the SAME    !
#!                               module is the simplest, always-valid Clarion    !
#!                               structure (exactly like a single-file program).!
#!                                                                             !
#!  This avoids the multi-module MEMBER()/MODULE() prototype-matching traps:    !
#!  a procedure DEFINED in module X must NOT be prototyped as MODULE('X') in     !
#!  that same module (that means "defined elsewhere") - which is why the        !
#!  earlier separate-.clw approach failed to compile.                          !
#!                                                                             !
#!  To add a function: add ONE prototype line under #AT(%GlobalMap) and ONE     !
#!  body under #AT(%ProgramProcedures). Nothing else to wire.                   !
#!                                                                             !
#!  Functions currently provided:                                             !
#!    weekNumber(<date>),LONG    - ISO-8601 (European) week number. Monday-start;!
#!                                 week 1 = the week of the year's first Thursday!
#!                                 (the week containing Jan 4). Date defaults to !
#!                                 today. Range 1..53; early-Jan dates can be     !
#!                                 wk 52/53 of the PRIOR year.                   !
#!    weekNumberUS(<date>),LONG  - US / North-American week number. Sunday-start; !
#!                                 week 1 = the week containing Jan 1, so Jan 1   !
#!                                 is ALWAYS week 1. Date defaults to today.      !
#!                                                                             !
#!  Corpus citations: %GlobalMap = "Inside the Global Map" (ABPROGRM.TPW:195);  !
#!  %ProgramProcedures = program-module procedure definitions, EXE targets      !
#!  (ABPROGRM.TPW:40). Weekday math: date %% 7 -> 0=Sun..6=Sat (ICSTD.CLW:355). !
#!                                                                             !
#!  Multi-DLL: the bodies are emitted only into EXE targets (%ProgramProcedures !
#!  is EXE-only). For a multi-DLL app where several DLLs need these functions,  !
#!  compile them into the shared/root target and export the names there.        !
#!-----------------------------------------------------------------------------!
#SYSTEM
  #EQUATE(%myFuncsTPLVersion,'1.20')
#!-----------------------------------------------------------------------------!
#EXTENSION(myFuncsGlobal,'myFuncs - Global Function Library (Global)'),APPLICATION,HLP('~myFuncs.htm')
#SHEET,HSCROLL
  #TAB('&General')
    #BOXED('About'),SECTION
      #DISPLAY('myFuncs - Global Function Library  v' & %myFuncsTPLVersion)
      #DISPLAY('Adds globally-callable utility functions to the application.')
    #ENDBOXED
    #PROMPT('&Disable this template',CHECK),%myFuncsDisable,DEFAULT(0),AT(10)
  #ENDTAB
  #TAB('&Functions')
    #BOXED('Included functions')
      #DISPLAY('weekNumber(<date>)    -  ISO-8601 / European week number (Mon start, wk1 = first Thursday)')
      #DISPLAY('weekNumberUS(<date>)  -  US week number (Sun start, Jan 1 always in week 1)')
      #DISPLAY('Both omit the date to use today.')
    #ENDBOXED
  #ENDTAB
#ENDSHEET
#!-----------------------------------------------------------------------------!
#!  PROTOTYPES - bare, inside the program's global MAP (callable app-wide).     !
#!-----------------------------------------------------------------------------!
#AT(%GlobalMap),WHERE(%myFuncsDisable=0),DESCRIPTION('myFuncs - global function prototypes')
#! SHORT prototype form (name(params),return) - has no column-1 label, so it
#! survives the indentation that %GlobalMap applies to embed content. The long
#! form (weekNumber PROCEDURE(...)) would need its label in column 1 and break.
weekNumber(LONG pDate=0),LONG    !ISO-8601 (European) week number; pDate omitted/0 = today
weekNumberUS(LONG pDate=0),LONG  !US week number (Sunday start, Jan 1 = week 1); pDate omitted/0 = today
#ENDAT
#!-----------------------------------------------------------------------------!
#!  BODIES - defined in the program module itself.                             !
#!-----------------------------------------------------------------------------!
#AT(%ProgramProcedures),WHERE(%myFuncsDisable=0),DESCRIPTION('myFuncs - global function bodies')
!=============================================================================
! weekNumber - ISO-8601 (European) week number of pDate (omitted/0 => today).
!   ISO weeks start Monday; week 1 is the week containing the year's first
!   Thursday. The Thursday of a date's week decides which year owns the week.
!   date MOD 7 gives 0=Sun..6=Sat (Clarion epoch: standard date 4 = Thu 01-Jan-1801).
!=============================================================================
weekNumber  PROCEDURE(LONG pDate=0)
loc:Date      LONG                                    ! the date we are working on
loc:M         LONG                                    ! date MOD 7  (0=Sun .. 6=Sat)
loc:ISODow    LONG                                    ! ISO weekday: Mon=1 .. Sun=7
loc:Thursday  LONG                                    ! the Thursday of loc:Date's week
loc:ISOYear   LONG                                    ! the year that owns this week
loc:Jan1      LONG                                    ! 1st January of loc:ISOYear
  CODE
  loc:Date = pDate
  IF ~loc:Date                                        ! no date passed -> use today
    loc:Date = TODAY()
  END
  loc:M      = loc:Date %% 7                           ! date MOD 7 -> 0=Sun,1=Mon,...,6=Sat
  loc:ISODow = CHOOSE(loc:M = 0, 7, loc:M)             ! Sunday(0) -> 7, else Mon..Sat = 1..6
  loc:Thursday = loc:Date + (4 - loc:ISODow)           ! move to Thursday of this ISO week
  loc:ISOYear  = YEAR(loc:Thursday)                    ! the Thursday decides the week's year
  loc:Jan1     = DATE(1, 1, loc:ISOYear)
  RETURN INT((loc:Thursday - loc:Jan1) / 7) + 1
!=============================================================================
! weekNumberUS - US / North-American week number of pDate (omitted/0 => today).
!   Weeks start SUNDAY; week 1 is the week containing January 1st, so Jan 1 is
!   always in week 1. We find the Sunday that starts pDate's week and the Sunday
!   that starts week 1 (the Sunday on/before Jan 1), then count 7-day blocks.
!   date MOD 7 gives days-since-Sunday (0=Sun..6=Sat); date minus that lands on
!   the week's Sunday.
!=============================================================================
weekNumberUS  PROCEDURE(LONG pDate=0)
loc:Date      LONG                                    ! the date we are working on
loc:Year      LONG                                    ! calendar year of loc:Date
loc:WeekSun   LONG                                    ! Sunday that starts loc:Date's week
loc:Jan1Sun   LONG                                    ! Sunday that starts week 1 (on/before Jan 1)
  CODE
  loc:Date = pDate
  IF ~loc:Date                                        ! no date passed -> use today
    loc:Date = TODAY()
  END
  loc:WeekSun = loc:Date - (loc:Date %% 7)             ! back up to this week's Sunday
  loc:Year    = YEAR(loc:Date)
  loc:Jan1Sun = DATE(1,1,loc:Year) - (DATE(1,1,loc:Year) %% 7)  ! Sunday on/before Jan 1
  RETURN INT((loc:WeekSun - loc:Jan1Sun) / 7) + 1
#ENDAT
