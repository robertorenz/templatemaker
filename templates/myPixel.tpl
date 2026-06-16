#TEMPLATE(myPixel,'myPixel - Per-Window Diagnostic Pixel v1.00'),FAMILY('ABC')
#!-----------------------------------------------------------------------------!
#!  myPixel  -  (c) 2026 Reddin Assessments                                    !
#!                                                                             !
#!  A GLOBAL (APPLICATION-scope) extension. With no per-procedure setup it     !
#!  drops a tiny visible REGION "pixel" in the top-left of EVERY procedure that !
#!  owns a window, tooltips it with proc/thread/binary info, and pops the same  !
#!  info on Ctrl+Shift+I.                                                       !
#!                                                                             !
#!  Mechanism / corpus citations:                                              !
#!    * APPLICATION-scope extension injecting into the per-procedure embed      !
#!      %WindowManagerMethodCodeSection: pattern proven by                      !
#!      anytext.tpl:450 / :458 (accessory) and EasyHtmlBrw.tpw:35.             !
#!    * EVENT:OpenWindow + EVENT:AlertKey are field-independent window events   !
#!      routed through WindowManager.TakeWindowEvent                            !
#!      (ABWINDOW.TPW:563 PRIORITY(2500); :1462 PRIORITY(7525)).               !
#!      We inject at PRIORITY(2000) - BELOW the framework's 2500 block - so our  !
#!      self-contained CASE EVENT() sits above the CYCLE/BREAK LOOP, never       !
#!      nesting inside the framework's own CASE (its CASE opens at 2500).        !
#!    * "Has a window" guard: WHERE(%Window) - idiom from wbproc.tpw:43.        !
#!    * REGION at runtime: CREATE(0,CREATE:region) - idash.clw:114;            !
#!      CREATE:region EQUATE(4) - EQUATES.CLW:249.                             !
#!    * PROP:Fill EQUATE(7C61H) - PROPERTY.CLW:83; PROP:Tip - PROPERTY.CLW:145.!
#!    * COLOR:Red EQUATE(00000FFH) - EQUATES.CLW:228.                          !
#!    * CtrlShiftI EQUATE(0349H) - KEYCODES.CLW:492.                           !
#!                                                                             !
#!  Multi-DLL: this template generates ONLY local procedure code (local data + !
#!  method-body statements). It declares NO globals and NO class instances, so  !
#!  there is nothing to mark EXTERNAL,DLL(dll_mode) and nothing to export via   !
#!  %DllExportList. No multi-DLL handling is required - confirmed by design.    !
#!-----------------------------------------------------------------------------!
#SYSTEM
  #EQUATE(%myPixelTPLVersion,'1.00')
#!-----------------------------------------------------------------------------!
#EXTENSION(myPixelGlobal,'myPixel - Diagnostic Pixel (Global)'),APPLICATION,HLP('~myPixel.htm')
#SHEET,HSCROLL
  #TAB('&General')
    #BOXED('About'),SECTION
      #DISPLAY('myPixel for Clarion  v' & %myPixelTPLVersion)
      #DISPLAY('Drops a diagnostic pixel on every window in the app.')
    #ENDBOXED
    #PROMPT('&Disable this template',CHECK),%myPixelDisable,DEFAULT(0),AT(10)
  #ENDTAB
  #TAB('&Pixel')
    #ENABLE(%myPixelDisable=0)
      #PROMPT('Pixel &fill color:',COLOR),%myPixelColor,DEFAULT(00000FFH)
      #PROMPT('Pixel &size (dialog units):',SPIN(@n3,1,40,1)),%myPixelSize,DEFAULT(4)
      #PROMPT('Enable &Ctrl+Shift+I info hotkey',CHECK),%myPixelHotKey,DEFAULT(1),AT(10)
    #ENDENABLE
  #ENDTAB
#ENDSHEET
#!-----------------------------------------------------------------------------!
#!  Build the literal binary description at GENERATE time.                      !
#!  %ProgramExtension is 'DLL' for a DLL target, 'EXE' otherwise.               !
#!-----------------------------------------------------------------------------!
#AT(%DataSection),WHERE(%myPixelDisable=0 AND %Window)
myPixel:Feq          LONG                                  ! myPixel: region control field equate
myPixel:Info         STRING(255)                           ! myPixel: tooltip / message text
#ENDAT
#!-----------------------------------------------------------------------------!
#!  All runtime behaviour: create the pixel on OpenWindow, alert the hotkey,    !
#!  and answer the AlertKey with a MESSAGE.                                     !
#!  Injected at PRIORITY(2000) - BELOW the framework's PRIORITY(2500) block.    !
#!  In ABWINDOW.TPW:563-612 the generated method opens its CYCLE/BREAK LOOP and  !
#!  its own "CASE EVENT()" statement (line 577) at priority 2500, with the OF    !
#!  clauses following at 3000+. Injecting at 2000 places our self-contained      !
#!  CASE EVENT()...END at the very TOP of the method, before that LOOP, so we    !
#!  never nest inside the framework CASE. We never RETURN, so control falls       !
#!  through into the framework's normal event handling untouched.                !
#!-----------------------------------------------------------------------------!
#AT(%WindowManagerMethodCodeSection,'TakeWindowEvent','(),BYTE'),PRIORITY(2000),WHERE(%myPixelDisable=0 AND %Window),DESCRIPTION('myPixel - diagnostic pixel handling')
  CASE EVENT()
  OF EVENT:OpenWindow
    myPixel:Info = 'Procedure: %Procedure' & |
                   '<13,10>Binary: %Application (%ProgramExtension)' & |
                   '<13,10>Thread: ' & THREAD()
    myPixel:Feq = CREATE(0,CREATE:region)
    IF myPixel:Feq
      SETPOSITION(myPixel:Feq,0,0,%myPixelSize,%myPixelSize)
      myPixel:Feq{PROP:Fill} = %myPixelColor
      myPixel:Feq{PROP:Tip}  = myPixel:Info
      UNHIDE(myPixel:Feq)
  #IF(%myPixelHotKey)
      ALERT(CtrlShiftI)
  #ENDIF
    END
  #IF(%myPixelHotKey)
  OF EVENT:AlertKey
    IF KEYCODE() = CtrlShiftI
      MESSAGE(myPixel:Info,'Procedure Information',ICON:Asterisk)
    END
  #ENDIF
  END
#ENDAT
