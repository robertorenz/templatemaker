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
#DECLARE(%mfcKey)
#SHEET,ADJUST
  #TAB('&General')
    #BOXED('myFontChanger')
      #PROMPT('&Disable this template',CHECK),%mfcDisable,DEFAULT(0),AT(10)
      #PROMPT('Default font &name (blank = leave control font):',@s64),%mfcDefName,DEFAULT(''),AT(10)
      #PROMPT('Default font &size (0 = leave control size):',SPIN(@n3,0,72,1)),%mfcDefSize,DEFAULT(0),AT(10)
      #PROMPT('&INI file name:',@s255),%mfcIni,DEFAULT('.\myFontChanger.INI'),REQ,AT(10)
    #ENDBOXED
    #DISPLAY('')
    #DISPLAY('Right-click a browse/list at run time for a popup menu:')
    #DISPLAY('   Change Font...        - pick a font for that list')
    #DISPLAY('   Reset to Default Font - revert it to the global default')
    #DISPLAY('Each list is saved in its OWN INI section and re-applied on reopen.')
  #ENDTAB
#ENDSHEET
#!-----------------------------------------------------------------------------------
#! Helper #GROUP: strip the leading '?' from %Control to build a regeneration-stable
#! INI key. Cited pattern: reference/patterns.md P6 / SKILL StripQFromControl.
#!-----------------------------------------------------------------------------------
#GROUP(%mfcStripQ)
  #IF(SUB(%Control,1,1)='?')
    #RETURN(SUB(%Control,2,LEN(CLIP(%Control))))
  #ELSE
    #RETURN(%Control)
  #ENDIF
#!-----------------------------------------------------------------------------------
#! Global MAP prototypes (SHORT FORM - survives MAP auto-indent; SKILL gotcha 1).
#!-----------------------------------------------------------------------------------
#AT(%GlobalMap),WHERE(%mfcDisable=0),DESCRIPTION('myFontChanger - helper prototypes')
myFontApply(SIGNED pFeq, STRING pKey, STRING pIni, STRING pDefName, SIGNED pDefSize)
myFontChange(SIGNED pFeq, STRING pKey, STRING pIni, STRING pDefName, SIGNED pDefSize)
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
#ENDAT
#!-----------------------------------------------------------------------------------
#! TakeWindowEvent: TakeWindowEvent runs only when FIELD()=0 (ABWINDOW.clw:720).
#! On EVENT:OpenWindow apply fonts to every LIST and arm a right-click alert (idx 250;
#! ABC's own browse uses 249 = MouseRightIndex, so 250 does not collide).
#! Self-contained CASE at PRIORITY 2000 (above framework CASE at 2500); never RETURN.
#!-----------------------------------------------------------------------------------
#AT(%WindowManagerMethodCodeSection,'TakeWindowEvent','(),BYTE'),PRIORITY(2000),WHERE(%mfcDisable=0 AND %Window),DESCRIPTION('myFontChanger - apply fonts + arm right-click')
  CASE EVENT()
  OF EVENT:OpenWindow
#FOR(%Control),WHERE(%ControlType='LIST')
    #SET(%mfcKey,%Procedure & '_' & %mfcStripQ())
    myFontApply(%Control, '%mfcKey', '%mfcIni', '%mfcDefName', %mfcDefSize)
    %Control{PROP:Alrt,250} = MouseRightUp
#ENDFOR
  END
#ENDAT
#!-----------------------------------------------------------------------------------
#! TakeFieldEvent: a list right-click arrives here with FIELD()=the list
#! (ABWINDOW.clw:720). Self-contained CASE at PRIORITY 2000 (above framework CASE at
#! ABWINDOW.TPW:724 PRIORITY 2500); never RETURN.
#!-----------------------------------------------------------------------------------
#AT(%WindowManagerMethodCodeSection,'TakeFieldEvent','(),BYTE'),PRIORITY(2000),WHERE(%mfcDisable=0 AND %Window),DESCRIPTION('myFontChanger - right-click font picker')
  CASE EVENT()
  OF EVENT:AlertKey
    IF KEYCODE() = MouseRightUp
      CASE FIELD()
#FOR(%Control),WHERE(%ControlType='LIST')
    #SET(%mfcKey,%Procedure & '_' & %mfcStripQ())
      OF %Control
        myFontChange(%Control, '%mfcKey', '%mfcIni', '%mfcDefName', %mfcDefSize)
#ENDFOR
      END
    END
  END
#ENDAT
#!-----------------------------------------------------------------------------------
#! End myFontChanger
#!-----------------------------------------------------------------------------------
