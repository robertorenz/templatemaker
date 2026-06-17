#TEMPLATE(myFontChanger,'myFontChanger - per-list font picker - v1.00'),FAMILY('ABC')
#!-----------------------------------------------------------------------------------
#!  myFontChanger
#!  Roberto Renz - 2026
#!
#!  A single, self-contained APPLICATION-scope ABC extension that:
#!    1. Applies a global default font to every browse/LIST control at window open.
#!    2. Lets the user right-click any LIST at run time to pick a font (Windows font
#!       dialog) for THAT list only.
#!    3. Stores each per-list choice in an INI file (keyed by procedure + control NAME)
#!       and re-applies it on reopen. A stored per-list font overrides the default.
#!
#!  Self-contained: two helper procedures are defined IN the program module
#!  (short-form prototype in %GlobalMap, long-form body in %ProgramProcedures).
#!  No external .inc/.clw required. EXE targets.
#!-----------------------------------------------------------------------------------
#EXTENSION(myFontChanger,'myFontChanger - global per-list font picker'),APPLICATION
#SHEET,ADJUST
  #TAB('&General')
    #BOXED('myFontChanger'),AT(,,250)
      #PROMPT('&Disable this template',CHECK),%mfcDisable,DEFAULT(0),AT(10)
      #PROMPT('Default font &name:',@s64),%mfcDefName,DEFAULT(''),PROMPTAT(8),AT(92,,150)
      #PROMPT('Default font &size:',SPIN(@n3,0,72,1)),%mfcDefSize,DEFAULT(0),PROMPTAT(8),AT(92,,40)
      #PROMPT('&INI file name:',@s255),%mfcIni,DEFAULT('.\myFontChanger.INI'),REQ,PROMPTAT(8),AT(92,,150)
      #DISPLAY('Name blank = keep each list current font;  Size 0 = keep current size.')
    #ENDBOXED
    #DISPLAY('See the Instructions tab for run-time usage (right-click menu, Ctrl+Plus/Minus).')
  #ENDTAB
  #TAB('&Instructions')
    #BOXED('How to use myFontChanger')
      #DISPLAY('SETUP (design time)')
      #DISPLAY('1. Add this extension ONCE, at the Global / Application level.')
      #DISPLAY('2. On the General tab set the default font Name and Size (used by')
      #DISPLAY('   every browse/list) and the INI file name.')
      #DISPLAY('3. Generate and build the application.')
      #DISPLAY('')
      #DISPLAY('AT RUN TIME')
      #DISPLAY('- Every browse/list opens in the default font.')
      #DISPLAY('- Right-click a list for a popup menu:')
      #DISPLAY('     Change Font...         opens the Windows font dialog')
      #DISPLAY('     Reset to Default Font  reverts that list to the default')
      #DISPLAY('- Click into a list, then press Ctrl+Plus / Ctrl+Minus to grow or')
      #DISPLAY('   shrink that list font by 1 point.')
      #DISPLAY('')
      #DISPLAY('STORAGE')
      #DISPLAY('- Each list is saved in its OWN INI section named Procedure_Control')
      #DISPLAY('   (e.g. BrowseClients_?List:2), with Name/Size/Color/Style entries.')
      #DISPLAY('- On reopen the stored font is re-applied; a per-list font overrides')
      #DISPLAY('   the global default. Reset deletes that list section.')
    #ENDBOXED
  #ENDTAB
#ENDSHEET
#!-----------------------------------------------------------------------------------
#! Global MAP prototypes (SHORT FORM - survives MAP auto-indent; SKILL gotcha 1).
#!-----------------------------------------------------------------------------------
#AT(%GlobalMap),WHERE(%mfcDisable=0),DESCRIPTION('myFontChanger - helper prototypes')
myFontApply(SIGNED pFeq, STRING pKey, STRING pIni, STRING pDefName, SIGNED pDefSize)
myFontChange(SIGNED pFeq, STRING pKey, STRING pIni, STRING pDefName, SIGNED pDefSize)
myFontBump(SIGNED pFeq, STRING pKey, STRING pIni, SIGNED pDelta)
#ENDAT
#!-----------------------------------------------------------------------------------
#! Helper bodies, defined in the program module (%ProgramProcedures = DATA region,
#! NOT auto-indented, so written long-form at column 1; EXE-only embed). SKILL.
#!-----------------------------------------------------------------------------------
#AT(%ProgramProcedures),WHERE(%mfcDisable=0),DESCRIPTION('myFontChanger - helper bodies')
#!
myFontApply  PROCEDURE(SIGNED pFeq, STRING pKey, STRING pIni, STRING pDefName, SIGNED pDefSize)
loc:Name       CSTRING(65)
loc:Size       LONG
loc:Color      LONG
loc:Style      LONG
  CODE
  loc:Name  = GETINI(CLIP(pKey), 'Name', '', pIni)         ! each browse has its OWN [section]
  IF loc:Name
    !A stored per-list font exists - it overrides the global default.
    loc:Size  = GETINI(CLIP(pKey), 'Size',  0, pIni)
    loc:Color = GETINI(CLIP(pKey), 'Color', COLOR:None, pIni)
    loc:Style = GETINI(CLIP(pKey), 'Style', -1, pIni)
    SETFONT(pFeq, loc:Name, loc:Size, loc:Color, loc:Style)
  ELSIF pDefName
    !No stored font - apply the global default (name + size only).
    SETFONT(pFeq, CLIP(pDefName), pDefSize)
  END
  RETURN
#!
myFontChange  PROCEDURE(SIGNED pFeq, STRING pKey, STRING pIni, STRING pDefName, SIGNED pDefSize)
loc:Name       CSTRING(65)
loc:Size       LONG
loc:Color      LONG
loc:Style      LONG
loc:Choice     SIGNED
  CODE
  !Right-click popup menu. POPUP() shows at the mouse and returns the item number
  !(0 = nothing chosen). No separator so the items number 1, 2 cleanly.
  loc:Choice = POPUP('Change Font...|Reset to Default Font')
  CASE loc:Choice
  OF 1                                             !--- Change Font... ---
    !Seed the dialog with the control<39>s current font.
    loc:Name  = pFeq{PROP:FontName}
    loc:Size  = pFeq{PROP:FontSize}
    loc:Color = pFeq{PROP:FontColor}
    loc:Style = pFeq{PROP:FontStyle}
    IF FONTDIALOG('Choose List Font', loc:Name, loc:Size, loc:Color, loc:Style)
      SETFONT(pFeq, loc:Name, loc:Size, loc:Color, loc:Style)
      !Save into THIS browse<39>s own INI section, named after pKey.
      PUTINI(CLIP(pKey), 'Name',  CLIP(loc:Name), pIni)
      PUTINI(CLIP(pKey), 'Size',  loc:Size,  pIni)
      PUTINI(CLIP(pKey), 'Color', loc:Color, pIni)
      PUTINI(CLIP(pKey), 'Style', loc:Style, pIni)
    END
  OF 2                                             !--- Reset to Default Font ---
    PUTINI(CLIP(pKey),,,pIni)                       !delete this browse<39>s whole section
    myFontApply(pFeq, pKey, pIni, pDefName, pDefSize) !revert to the global default font
  END
  RETURN
#!
myFontBump  PROCEDURE(SIGNED pFeq, STRING pKey, STRING pIni, SIGNED pDelta)
loc:Size  LONG
  CODE
  !Ctrl+mouse-wheel: nudge the list font size by pDelta (+1/-1), clamp, and save.
  loc:Size = pFeq{PROP:FontSize} + pDelta
  IF loc:Size < 4                                   !sensible floor
    loc:Size = 4
  ELSIF loc:Size > 72                               !sensible ceiling
    loc:Size = 72
  END
  pFeq{PROP:FontSize} = loc:Size                    !apply just the size
  !Store the FULL current font so myFontApply re-applies it on reopen
  !(it keys off the Name entry being present).
  PUTINI(CLIP(pKey), 'Name',  pFeq{PROP:FontName},  pIni)
  PUTINI(CLIP(pKey), 'Size',  loc:Size,             pIni)
  PUTINI(CLIP(pKey), 'Color', pFeq{PROP:FontColor}, pIni)
  PUTINI(CLIP(pKey), 'Style', pFeq{PROP:FontStyle}, pIni)
  RETURN
#ENDAT
#!-----------------------------------------------------------------------------------
#! TakeWindowEvent: TakeWindowEvent runs only when FIELD()=0 (ABWINDOW.clw:720).
#! On EVENT:OpenWindow apply fonts to every LIST and ARM the alerts: right-click
#! (idx 250; ABC's browse uses 249, so no collision) plus Ctrl-Plus / Ctrl-Minus
#! (idx 251/252). Keyboard alerts MUST be armed for EVENT:AlertKey to fire.
#! Self-contained CASE at PRIORITY 2000 (above framework CASE at 2500); never RETURN.
#!-----------------------------------------------------------------------------------
#AT(%WindowManagerMethodCodeSection,'TakeWindowEvent','(),BYTE'),PRIORITY(2000),WHERE(%mfcDisable=0 AND %Window),DESCRIPTION('myFontChanger - apply fonts + arm keys')
  CASE EVENT()
  OF EVENT:OpenWindow
#FOR(%Control),WHERE(%ControlType='LIST')
    myFontApply(%Control, '%Procedure' & '_' & '%Control', '%mfcIni', '%mfcDefName', %mfcDefSize)
    %Control{PROP:Alrt,250} = MouseRightUp
    %Control{PROP:Alrt,251} = CtrlPlus
    %Control{PROP:Alrt,252} = CtrlMinus
#ENDFOR
  END
#ENDAT
#!-----------------------------------------------------------------------------------
#! TakeFieldEvent: list events arrive here with FIELD()=the list (ABWINDOW.clw:720).
#! All triggers are ARMED keys -> EVENT:AlertKey (same mechanism as the right-click,
#! which works): MouseRightUp -> font menu; Ctrl-Plus -> +1; Ctrl-Minus -> -1.
#! Self-contained CASE at PRIORITY 2000 (above framework CASE at ABWINDOW.TPW:724
#! PRIORITY 2500); never RETURN (alerted keys are not passed to default handling).
#!-----------------------------------------------------------------------------------
#AT(%WindowManagerMethodCodeSection,'TakeFieldEvent','(),BYTE'),PRIORITY(2000),WHERE(%mfcDisable=0 AND %Window),DESCRIPTION('myFontChanger - right-click + Ctrl-Plus/Minus')
  CASE FIELD()
#FOR(%Control),WHERE(%ControlType='LIST')
  OF %Control
    IF EVENT() = EVENT:AlertKey
      CASE KEYCODE()
      OF MouseRightUp
        myFontChange(%Control, '%Procedure' & '_' & '%Control', '%mfcIni', '%mfcDefName', %mfcDefSize)
      OF CtrlPlus
        myFontBump(%Control, '%Procedure' & '_' & '%Control', '%mfcIni', 1)
      OF CtrlMinus
        myFontBump(%Control, '%Procedure' & '_' & '%Control', '%mfcIni', -1)
      END
    END
#ENDFOR
  END
#ENDAT
#!-----------------------------------------------------------------------------------
#! INI key per browse = '%Procedure' & '_' & '%Control', built by DIRECT symbol
#! substitution in the output line (e.g. 'BrowseClients' & '_' & '?List:2'). This is
#! the reliable approach: a #GROUP called inline as %(%group()) does NOT inherit the
#! #FOR loop's %Control/%Procedure, so it returned an empty key (sections [] / :Name).
#! The '?' from %Control is kept - it is a valid, unique, regeneration-stable INI
#! section name. So each browse gets its own [Procedure_?Control] section.
#!-----------------------------------------------------------------------------------
#! End myFontChanger
#!-----------------------------------------------------------------------------------
