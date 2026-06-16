!=============================================================================!
!  myFuncs - global function library : PROTOTYPES (bare)                      !
!                                                                             !
!  These are BARE prototypes (no MODULE wrapper). They are used two ways:     !
!    * INCLUDEd directly in myFuncs.clw's own MAP  -> "defined in this module" !
!      so the procedure bodies below find their matching prototype.           !
!    * INCLUDEd by myFuncs.tpl INSIDE a MODULE('myFuncs.clw') block in the     !
!      program's global MAP -> "defined in myFuncs.clw" so every other module  !
!      can call them and the linker knows where to resolve them.              !
!                                                                             !
!  To add a function: add its prototype here AND its body in myFuncs.clw.     !
!=============================================================================!
weekNumber           PROCEDURE(LONG pDate=0),LONG  !ISO-8601 (European) week number; pDate omitted/0 = today
