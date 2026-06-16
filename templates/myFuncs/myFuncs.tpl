#TEMPLATE(myFuncs,'myFuncs - Global Function Library v1.00'),FAMILY('ABC')
#!-----------------------------------------------------------------------------!
#!  myFuncs  -  (c) 2026 Reddin Assessments                                    !
#!                                                                             !
#!  A GLOBAL (APPLICATION-scope) extension that makes a growing library of      !
#!  utility FUNCTIONS callable from anywhere in the app. It wires two shipped   !
#!  source files into the application:                                          !
#!    * myFuncs.inc - the prototypes, INCLUDEd inside the global MAP            !
#!    * myFuncs.clw - the function bodies, compiled into the project            !
#!                                                                             !
#!  Add the extension once (Global -> Extensions); every function then resolves !
#!  app-wide with no per-procedure setup. To grow the library, add a prototype  !
#!  to myFuncs.inc and a body to myFuncs.clw - this template needs no change.   !
#!                                                                             !
#!  Mechanism / corpus citations:                                              !
#!    * "Inside the Global Map" embed %GlobalMap (ABPROGRM.TPW:195); the        !
#!      include-functions-into-the-map pattern is proven by office.tpl:324.     !
#!    * Adding a source module for compilation via #PROJECT('x.clw') -          !
#!      NYS_CalendarPro.tpl:51.                                                 !
#!    * Empty MEMBER() module - ABWINDOW.CLW:1.                                 !
#!                                                                             !
#!  Functions currently provided:                                             !
#!    weekNumber(<date>),LONG  - ISO-8601 (European) week number; the date is   !
#!                               omittable and defaults to today.               !
#!                                                                             !
#!  Multi-DLL: prototypes live in the global MAP and the body is a normal       !
#!  compiled module, so the functions link like any program procedure. If the   !
#!  same functions are needed across several DLLs, compile myFuncs.clw into the !
#!  shared/root target and export the names there (standard cross-DLL handling).!
#!-----------------------------------------------------------------------------!
#SYSTEM
  #EQUATE(%myFuncsTPLVersion,'1.00')
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
      #DISPLAY('weekNumber(<date>)  -  ISO-8601 week number (date defaults to today)')
    #ENDBOXED
    #DISPLAY('Copy myFuncs.inc and myFuncs.clw into a folder on the app''s')
    #DISPLAY('redirection / source path so the compiler can find them.')
  #ENDTAB
#ENDSHEET
#!-----------------------------------------------------------------------------!
#!  Prototypes: include the prototype map fragment INSIDE the global MAP, so    !
#!  every function is callable from any procedure in the app.                   !
#!-----------------------------------------------------------------------------!
#AT(%GlobalMap),WHERE(%myFuncsDisable=0),DESCRIPTION('myFuncs - global function prototypes')
    MODULE('myFuncs.clw')
INCLUDE('myFuncs.inc'),ONCE
    END
#ENDAT
#!-----------------------------------------------------------------------------!
#!  Bodies: add the source module to the project so it is compiled and linked.  !
#!-----------------------------------------------------------------------------!
#AT(%CustomGlobalDeclarations),WHERE(%myFuncsDisable=0),DESCRIPTION('myFuncs - compile function module')
#PROJECT('myFuncs.clw')
#ENDAT
