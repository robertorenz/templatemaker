!=============================================================================!
!  myFuncs - global function library : PROTOTYPES                             !
!  This file is INCLUDEd inside the program's global MAP (by myFuncs.tpl) and  !
!  inside myFuncs.clw's own MAP, so every prototype is visible app-wide.       !
!  To add a function: add its prototype here AND its body in myFuncs.clw.      !
!=============================================================================!
    MODULE('myFuncs.clw')
weekNumber           PROCEDURE(LONG pDate=0),LONG  !ISO-8601 (European) week number; pDate omitted/0 = today
    END
