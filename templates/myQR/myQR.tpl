#TEMPLATE(myQR,'myQR - Render a QR code into an IMAGE control - v1.00'),FAMILY('ABC')
#!-----------------------------------------------------------------------------------
#!  myQR
#!  Roberto Renz - 2026
#!
#!  A self-contained ABC PROCEDURE extension that renders a QR code into an IMAGE
#!  control on the window. The QR value can be a design-time literal (a quoted string)
#!  OR any Clarion variable/expression - it is emitted verbatim into generated code, so
#!  it is evaluated AT RUN TIME. With auto-refresh on, a window timer watches the value
#!  and reloads the QR whenever it changes. The developer can also force a redraw any
#!  time with  DO myQRRefresh.
#!
#!  HOW IT WORKS (no QR library needed): the QR PNG is fetched from the free public web
#!  service api.qrserver.com (the "goqr.me" API) and loaded into the IMAGE control. The
#!  download uses curl.exe, which ships with Windows 10/11 at %%SystemRoot%%\System32\
#!  curl.exe. curl is launched HIDDEN (no flashing console) and SYNCHRONOUSLY (we wait for
#!  it to finish) via CreateProcessA + WaitForSingleObject, so the PNG is on disk before
#!  the IMAGE control loads it. On older Windows without curl, install curl or switch the
#!  helper back to urlmon's URLDownloadToFile.
#!
#!  *** PRIVACY / INTERNET CAVEAT ***
#!  The QR value is sent over HTTPS to a THIRD-PARTY server (api.qrserver.com) every time
#!  the code is rendered, and an internet connection is REQUIRED. Do NOT encode secrets,
#!  passwords or personal data you are not willing to transmit to that service. See the
#!  Instructions tab. For an offline/private deployment, swap myQRLoad's URL for your own
#!  QR endpoint or a local QR library.
#!
#!  Self-contained: two helper procedures are defined IN the program module (short-form
#!  prototypes in %%GlobalMap, long-form bodies in %%ProgramProcedures). No external
#!  .inc/.clw required. EXE targets - the helper bodies live in the program module.
#!  MULTI-DLL CAVEAT (same as myPie / myFontChanger): %%ProgramProcedures and %%GlobalMap
#!  target the EXE/program module. In a multi-DLL app, host this extension's global helper
#!  in the program (EXE) app, or move the helper bodies/prototypes to the shared/root DLL
#!  target and export them, so every DLL that uses the extension can call them.
#!
#!  VERIFIED corpus facts (cited the way myPie.tpl cites its builtins):
#!    Load an image file into an IMAGE control at run time:  feq{PROP:Text} = filename
#!      Clarion's own ActiveImage class does exactly this:   ActiveImage.clw:593/597/599
#!      PROP:Text EQUATE(7C00H)                              property.clw:8
#!      (PROP:Picture (7353H, property.clw:563) is the LISTBOX column picture token, NOT
#!       the image-file property - do not use it here.)
#!    Window timer (poll):   0{PROP:Timer} = hundredths-of-a-second   (PROP:Timer, property.clw)
#!    Hidden+synchronous process launch (curl): CreateProcessA with CREATE_NO_WINDOW
#!      (08000000h) plus STARTF_USESHOWWINDOW (00000001h) + SW_HIDE (0) in STARTUPINFO,
#!      then WaitForSingleObject(hProcess,INFINITE), then CloseHandle(hThread)/(hProcess).
#!      Prototypes + the STARTUPINFO / PROCESS_INFORMATION GROUP field layouts are taken
#!      VERBATIM from CapeSoft OddJob (shipped in accessory\libsrc\win):
#!        CreateProcessA prototype  JobObjectApi.clw:134-136
#!        joPROCESS_INFORMATION     OddJobEq.inc:305-310
#!        joSTARTUPINFO             OddJobEq.inc:328-347
#!        SW_HIDE=0                 OddJobEq.inc:35
#!        STARTF_USESHOWWINDOW=1h   OddJobEq.inc:349
#!        CREATE_NO_WINDOW=8000000h OddJobEq.inc:390
#!      WaitForSingleObject / CloseHandle prototypes match windows.inc:38/63 and
#!      svapifnc.inc:219/273 (HANDLE=SIGNED, windows.inc:5).
#!-----------------------------------------------------------------------------------
#SYSTEM
  #EQUATE(%myQRTPLVersion,'1.00')
  #DECLARE(%myQREccLetter)                                 #! 1-letter ECC resolved at generate time
#!-----------------------------------------------------------------------------------
#EXTENSION(myQR,'myQR - QR code into an image control'),PROCEDURE
#SHEET,ADJUST
  #TAB('&General')
    #BOXED('About'),SECTION
      #DISPLAY('myQR for Clarion  v' & %myQRTPLVersion)
      #DISPLAY('Renders a QR code into an IMAGE control. Value can be a literal or a')
      #DISPLAY('variable/expression that you change in code; the image auto-refreshes.')
      #DISPLAY('PRIVACY: the value is sent over HTTPS to api.qrserver.com (see Instructions).')
    #ENDBOXED
    #BOXED('Options'),AT(,,250)
      #PROMPT('&Disable this template',CHECK),%myQRDisable,DEFAULT(0),AT(10)
      #PROMPT('&Image control:',CONTROL),%myQRImage,REQ,PROMPTAT(8),AT(96,,140)
      #PROMPT('&Value (literal or variable/expression):',@s255),%myQRValue,DEFAULT('https://www.softvelocity.com'),REQ,PROMPTAT(8),AT(96,,140)
      #PROMPT('&Size (pixels):',SPIN(@n4,40,1000,10)),%myQRSize,DEFAULT(200),PROMPTAT(8),AT(96,,50)
      #PROMPT('Error &correction:',DROP('Low (L)|Medium (M)|Quartile (Q)|High (H)')),%myQREcc,DEFAULT('Medium (M)'),PROMPTAT(8),AT(96,,90)
      #PROMPT('&Quiet zone (margin, 0-50):',SPIN(@n2,0,50,1)),%myQRMargin,DEFAULT(1),PROMPTAT(8),AT(96,,50)
      #PROMPT('Auto-&refresh when the value changes',CHECK),%myQRAuto,DEFAULT(1),AT(10)
      #PROMPT('Refresh &poll (1/100 sec, for auto-refresh):',SPIN(@n5,10,6000,10)),%myQRTimer,DEFAULT(50),PROMPTAT(8),AT(96,,50)
      #ENABLE(%myQRAuto)
        #DISPLAY('Auto-refresh uses the WINDOW timer (0{PROP:Timer}). If this procedure')
        #DISPLAY('already uses the window timer, turn auto-refresh OFF and call DO myQRRefresh.')
      #ENDENABLE
    #ENDBOXED
    #DISPLAY('Value: a QUOTED literal e.g. ''Hello'' for a fixed code, OR a variable/')
    #DISPLAY('expression e.g. Cus:Email or loc:URL to drive it from your code.')
  #ENDTAB
  #TAB('&Instructions')
    #BOXED('How to use myQR')
      #DISPLAY('SETUP (design time)')
      #DISPLAY('1. Add an IMAGE control to the window (Image, not Region) and size it.')
      #DISPLAY('2. Add this extension to the PROCEDURE (Extensions button).')
      #DISPLAY('3. On the General tab pick that control in "Image control", and set the')
      #DISPLAY('   Size, Error correction and Quiet zone.')
      #DISPLAY('4. Set the Value. TWO MODES:')
      #DISPLAY('     a) FIXED  - type a quoted literal, e.g.  ''https://example.com''')
      #DISPLAY('                 or  ''Hello World''  (with the quotes).')
      #DISPLAY('     b) DRIVEN - type a Clarion variable or expression with NO quotes,')
      #DISPLAY('                 e.g.  Cus:Email   or   loc:URL   or   ''ID:'' & CLIP(Cus:Id)')
      #DISPLAY('   The value is emitted into the code verbatim and read at RUN TIME.')
      #DISPLAY('5. Generate, build, run.')
      #DISPLAY('')
      #DISPLAY('REFRESH')
      #DISPLAY('- Auto-refresh ON: a window timer polls the value; when it changes the')
      #DISPLAY('   QR is reloaded automatically.')
      #DISPLAY('- Any time, force a redraw from your own embed code with:  DO myQRRefresh')
      #DISPLAY('- Auto-refresh OFF (or the value never changes): the code is rendered once')
      #DISPLAY('   at window open; call DO myQRRefresh yourself after you change the value.')
      #DISPLAY('')
      #DISPLAY('TIMER CAVEAT')
      #DISPLAY('- Auto-refresh sets the WINDOW timer (0{PROP:Timer}). If this procedure')
      #DISPLAY('   already uses the window timer for something else, turn auto-refresh OFF')
      #DISPLAY('   and drive the refresh manually with DO myQRRefresh.')
      #DISPLAY('')
      #DISPLAY('DOWNLOADER (curl.exe)')
      #DISPLAY('- The PNG is fetched with curl.exe, which ships with Windows 10/11 at')
      #DISPLAY('   %%SystemRoot%%\System32\curl.exe. curl is run HIDDEN (no flashing console')
      #DISPLAY('   window) and SYNCHRONOUSLY, so the image is ready before it is loaded.')
      #DISPLAY('- On OLDER Windows without curl, either install curl or switch the myQRLoad')
      #DISPLAY('   helper back to urlmon''s URLDownloadToFile.')
      #DISPLAY('')
      #DISPLAY('PRIVACY / INTERNET (READ THIS)')
      #DISPLAY('- The QR code is generated by the public web service api.qrserver.com.')
      #DISPLAY('   The VALUE is sent over HTTPS to that THIRD-PARTY server every render,')
      #DISPLAY('   and an internet connection is REQUIRED. Do not encode secrets/passwords')
      #DISPLAY('   or data you are unwilling to transmit. For offline/private use, edit the')
      #DISPLAY('   myQRLoad helper to point at your own QR endpoint or a local QR library.')
      #DISPLAY('- A small temp PNG (myQR_<feq>.png in the current directory) is written and')
      #DISPLAY('   loaded into the image; it is cleared before each re-download.')
    #ENDBOXED
  #ENDTAB
#ENDSHEET
#!-----------------------------------------------------------------------------------
#! Global MAP: ONLY the two short-form helper prototypes. Short form survives MAP
#! auto-indent (SKILL gotcha 1). The kernel32 prototypes (CreateProcessA /
#! WaitForSingleObject / CloseHandle) are NOT declared here on purpose - they live in
#! myQRLoad's OWN local MAP (see %%ProgramProcedures below). Keeping them local (a) keeps
#! the helper self-contained, and (b) avoids any duplicate-prototype clash with Clarion's
#! own WinApi declarations (windows.inc / svapifnc.inc) that the ABC runtime may pull into
#! the global MAP. Guarded so a disabled template emits nothing.
#!-----------------------------------------------------------------------------------
#AT(%GlobalMap),WHERE(%myQRDisable=0 AND %myQRImage),DESCRIPTION('myQR - helper prototypes')
myQRUrlEncode(STRING pText),STRING
myQRLoad(SIGNED pImageFeq, STRING pData, SIGNED pSize, STRING pEccLetter, SIGNED pMargin),BYTE
#ENDAT
#!-----------------------------------------------------------------------------------
#! Helper bodies, defined in the program module (%ProgramProcedures = DATA region, NOT
#! auto-indented, so written long-form at column 1; EXE-only embed). SKILL gotcha 1.
#! See the multi-DLL caveat in the banner for hosting these in a multi-DLL app.
#!-----------------------------------------------------------------------------------
#AT(%ProgramProcedures),WHERE(%myQRDisable=0 AND %myQRImage),DESCRIPTION('myQR - helper bodies')
#!
myQRUrlEncode PROCEDURE(STRING pText)
loc:In         CSTRING(1024)                              ! the value to encode
loc:Out        CSTRING(3072)                              ! room for worst-case %%XX expansion
loc:I          LONG
loc:C          BYTE                                       ! current character code
loc:Hex        STRING('0123456789ABCDEF')                 ! for the %%XX nibbles
  CODE
  !Percent-encode for a URL query. Unreserved chars pass through (RFC 3986:
  ! A-Z a-z 0-9 - _ . ~). A space becomes %%20. Everything else becomes %%XX.
  loc:In = CLIP(pText)
  LOOP loc:I = 1 TO LEN(loc:In)
    loc:C = VAL(loc:In[loc:I])
    CASE loc:C
    OF VAL('A') TO VAL('Z')                               ! unreserved: emit as-is
    OROF VAL('a') TO VAL('z')
    OROF VAL('0') TO VAL('9')
    OROF VAL('-') OROF VAL('_') OROF VAL('.') OROF VAL('~')
      loc:Out = loc:Out & loc:In[loc:I]
    OF VAL(' ')                                           ! space -> %%20
      loc:Out = loc:Out & '%%20'
    ELSE                                                  ! anything else -> %%XX
      loc:Out = loc:Out & '%%' & loc:Hex[ BAND(BSHIFT(loc:C,-4),0Fh) + 1 ] & loc:Hex[ BAND(loc:C,0Fh) + 1 ]
    END
  END
  RETURN loc:Out
#!
myQRLoad      PROCEDURE(SIGNED pImageFeq, STRING pData, SIGNED pSize, STRING pEccLetter, SIGNED pMargin)
loc:URL        CSTRING(4096)                              ! the full request URL
loc:File       CSTRING(File:MaxFilePath+1)                ! the per-image temp PNG
loc:Cmd        CSTRING(4352)                              ! full curl command line - CreateProcessA writes back into this, so size it big (url 4096 + curl flags + quotes)
loc:Ok         LONG                                       ! CreateProcessA return (0 = failed to launch)
loc:Dir        QUEUE,PRE(dir)                             ! DIRECTORY() target - standard ff_: layout
dir:Name         STRING(File:MaxFileName)
dir:ShortName    STRING(13)
dir:Date         LONG
dir:Time         LONG
dir:Size         LONG                                     ! file size in bytes - >0 means a real PNG
dir:Attrib       BYTE
               END
si             GROUP                                      ! STARTUPINFOA - field order/types per OddJobEq.inc:328-347
cb               ULONG                                    ! sizeof(STARTUPINFO)
lpReserved       LONG(0)
lpDesktop        LONG(0)
lpTitle          LONG(0)
dwX              ULONG
dwY              ULONG
dwXSize          ULONG
dwYSize          ULONG
dwXCountChars    ULONG
dwYCountChars    ULONG
dwFillAttribute  ULONG
dwFlags          ULONG                                    ! STARTF_USESHOWWINDOW bit goes here
wShowWindow      SHORT(0)                                 ! SW_HIDE = 0
cbReserved2      SHORT(0)
lpReserved2      LONG(0)
hStdInput        LONG
hStdOutput       LONG
hStdError        LONG
               END
pi             GROUP                                      ! PROCESS_INFORMATION - OddJobEq.inc:305-310
hProcess         LONG
hThread          LONG
dwProcessId      ULONG
dwThreadId       ULONG
               END
STARTF_USESHOWWINDOW EQUATE(00000001h)                   ! OddJobEq.inc:349
SW_HIDE              EQUATE(0)                             ! OddJobEq.inc:35
CREATE_NO_WINDOW    EQUATE(08000000h)                     ! OddJobEq.inc:390 - no console window for a console app
INFINITE            EQUATE(0FFFFFFFFh)                     ! WaitForSingleObject: wait with no timeout
  MAP
    !kernel32 prototypes - local to this helper. TYPE-ONLY parameters: a Clarion MAP
    !prototype takes parameter TYPES, not names. Named params make the compiler read the
    !name as an attribute ("Unknown attribute: lpProcessInformation"). Param order/types
    !per Win32 CreateProcessA (and CapeSoft OddJob JobObjectApi.clw:134); Wait/Close per
    !windows.inc:38/63 / svapifnc.inc:219/273. HANDLE = SIGNED (windows.inc:5).
    !CreateProcessA args, in order: lpApplicationName, lpCommandLine, lpProcessAttributes,
    !lpThreadAttributes, bInheritHandles, dwCreationFlags, lpEnvironment, lpCurrentDirectory,
    !lpStartupInfo, lpProcessInformation.
    MODULE('kernel32')
CreateProcessA(LONG,*CSTRING,LONG,LONG,LONG,ULONG,LONG,LONG,LONG,LONG),LONG,RAW,PASCAL,PROC
WaitForSingleObject(SIGNED,ULONG),LONG,PASCAL
CloseHandle(SIGNED),LONG,PASCAL,PROC
    END
  END
  CODE
  !Per-image temp file in the current directory, keyed by the control FEQ so two QR
  !images on one window never clash. PNG, because the service returns PNG.
  loc:File = '.\myQR_' & pImageFeq & '.png'
  !Build the request for the goqr.me API. size=SxS, margin (quiet zone), ecc=L|M|Q|H,
  !data = the URL-encoded value. https = the value travels over TLS (see privacy note).
  loc:URL = 'https://api.qrserver.com/v1/create-qr-code/?size=' & pSize & 'x' & pSize |
          & '&margin=' & pMargin |
          & '&ecc=' & CLIP(pEccLetter) |
          & '&data=' & CLIP(myQRUrlEncode(pData))
  !Release the image's hold on the temp file BEFORE re-downloading, or the download
  !cannot overwrite a locked file (feq{PROP:Text}='' clears the loaded picture -
  !ActiveImage.clw uses the same PROP:Text channel to set/clear an IMAGE file).
  pImageFeq{PROP:Text} = ''
  REMOVE(loc:File)                                        ! drop the stale PNG (ignore if absent)
  !Build the curl command line. -s silent, -L follow redirects, --max-time guards a hung
  !server, -o writes the PNG. CreateProcessA modifies lpCommandLine in place, so loc:Cmd
  !is a generously sized CSTRING (see its declaration). <34> is a literal double-quote (")
  !- Windows arg quoting uses double quotes, so paths/URLs are quoted with <34>, not <39>.
  loc:Cmd = 'curl -s -L --max-time 15 -o <34>' & CLIP(loc:File) & '<34> <34>' & CLIP(loc:URL) & '<34>'
  !Launch curl HIDDEN: SW_HIDE in wShowWindow + STARTF_USESHOWWINDOW so it is honoured,
  !and CREATE_NO_WINDOW so a console app gets no console at all. cb = sizeof(STARTUPINFO).
  si.cb         = SIZE(si)
  si.dwFlags    = STARTF_USESHOWWINDOW
  si.wShowWindow = SW_HIDE
  !appName=0 (parse from command line), inherit=0, env/dir=0. RAW passes the addresses of
  !loc:Cmd / si / pi. loc:Ok = 0 means curl could not even be launched (curl.exe missing).
  loc:Ok = CreateProcessA(0, loc:Cmd, 0, 0, 0, CREATE_NO_WINDOW, 0, 0, ADDRESS(si), ADDRESS(pi))
  IF loc:Ok
    !Synchronous: block until curl exits, then release the handles it handed back.
    WaitForSingleObject(pi.hProcess, INFINITE)
    CloseHandle(pi.hThread)
    CloseHandle(pi.hProcess)
  END
  !Trust the FILE, not the exit code: success = the PNG now exists and is non-empty.
  !DIRECTORY() lists the temp file and gives us its byte size; >0 bytes = a real PNG.
  FREE(loc:Dir)
  DIRECTORY(loc:Dir, loc:File, ff_:NORMAL)
  GET(loc:Dir, 1)
  IF EXISTS(loc:File) AND RECORDS(loc:Dir) AND dir:Size > 0
    pImageFeq{PROP:Text} = loc:File                        ! load the fresh QR into the image
    RETURN 1
  END
  RETURN 0                                                 ! curl missing / offline / service down
  !--- SIMPLE FALLBACK (console may FLASH; use only if you do not care about the flash) ---
  !  Replace the CreateProcessA block above with one line - RUN(...,1) runs and WAITS:
  !    RUN('curl -s -L -o <34>' & CLIP(loc:File) & '<34> <34>' & CLIP(loc:URL) & '<34>', 1)
  !----------------------------------------------------------------------------------------
#ENDAT
#!-----------------------------------------------------------------------------------
#! Local data for change detection. CSTRINGs so the captured value compares cleanly.
#!-----------------------------------------------------------------------------------
#AT(%DataSection),WHERE(%myQRDisable=0 AND %myQRImage),DESCRIPTION('myQR - local state')
myQR:Last            CSTRING(256)                          ! last value actually rendered
myQR:Cur             CSTRING(256)                          ! value read this pass
myQR:Ecc             STRING(1)                             ! 1-letter ECC (set at gen time)
#ENDAT
#!-----------------------------------------------------------------------------------
#! Refresh ROUTINE - "DO myQRRefresh" renders the CURRENT value into the image. Call it
#! yourself any time after you change the value (it also runs on open / on change). The
#! 1-letter ECC is resolved from the prompt at GENERATION time. The value expression is
#! emitted VERBATIM, so a literal stays a literal and a variable is read live.
#!-----------------------------------------------------------------------------------
#AT(%ProcedureRoutines),WHERE(%myQRDisable=0 AND %myQRImage),DESCRIPTION('myQR - refresh routine')
#CASE(%myQREcc)
#OF('Low (L)')
  #SET(%myQREccLetter,'L')
#OF('Quartile (Q)')
  #SET(%myQREccLetter,'Q')
#OF('High (H)')
  #SET(%myQREccLetter,'H')
#ELSE
  #SET(%myQREccLetter,'M')
#ENDCASE
myQRRefresh ROUTINE
  myQR:Ecc = '%myQREccLetter'                              ! error-correction level
  myQR:Cur = %myQRValue                                    ! the value (literal or variable/expression - verbatim)
  myQRLoad(%myQRImage, myQR:Cur, %myQRSize, myQR:Ecc, %myQRMargin)
  myQR:Last = myQR:Cur                                     ! remember what we just rendered
#ENDAT
#!-----------------------------------------------------------------------------------
#! Self-contained handler at the TOP of TakeWindowEvent (PRIORITY 2000, never RETURNs),
#! same idiom as myPie / myFontChanger / myBackground. On OpenWindow start the poll timer
#! (if auto-refresh is on) and render once. On EVENT:Timer, re-read the value and refresh
#! only when it actually changed (cheap compare, one network call only on a real change).
#!
#! %myQRImage is a CONTROL prompt and already yields the '?'-prefixed equate - pass it
#! straight through. %myQRValue is emitted VERBATIM (literal or live variable/expression).
#! TIMER CAVEAT: this sets 0{PROP:Timer}; if the procedure already uses the window timer,
#! turn auto-refresh OFF and call DO myQRRefresh manually instead.
#!-----------------------------------------------------------------------------------
#AT(%WindowManagerMethodCodeSection,'TakeWindowEvent','(),BYTE'),PRIORITY(2000),WHERE(%myQRDisable=0 AND %myQRImage),DESCRIPTION('myQR - open + auto-refresh poll')
  CASE EVENT()
  OF EVENT:OpenWindow
#IF(%myQRAuto)
    0{PROP:Timer} = %myQRTimer                             ! start the value-watch poll
#ENDIF
    DO myQRRefresh                                         ! first render
#IF(%myQRAuto)
  OF EVENT:Timer
    myQR:Cur = %myQRValue                                  ! read the live value (verbatim expression)
    IF myQR:Cur <> myQR:Last                               ! only hit the network when it changed
      DO myQRRefresh
    END
#ENDIF
  END
#ENDAT
#!-----------------------------------------------------------------------------------
#! End myQR
#!-----------------------------------------------------------------------------------
