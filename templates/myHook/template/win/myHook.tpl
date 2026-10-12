#TEMPLATE(myHook,'myHook - Intercept MESSAGE, STOP, HALT and run-time errors - v1.0'),FAMILY('ABC')
#!-----------------------------------------------------------------------------
#!  myHook template set  -  takes the run-time library's own dialogs away from
#!  it and lets you decide what happens instead.
#!
#!  Clarion will hand its dialogs over to your code if you give it the address
#!  of a replacement procedure. There is one of these hooks per dialog:
#!
#!      SYSTEM{PROP:MessageHook}      every MESSAGE()
#!      SYSTEM{PROP:StopHook}         every STOP()
#!      SYSTEM{PROP:HaltHook}         every HALT()
#!      SYSTEM{PROP:AssertHook}       every failed ASSERT()
#!      SYSTEM{PROP:AssertHook2}      the same, with the assertion text
#!      SYSTEM{PROP:FatalErrorHook}   run-time errors
#!      SYSTEM{PROP:LastChanceHook}   GPFs and other unhandled exceptions
#!
#!  Those are the hooks the shipped WebBuilder layer uses to move a desktop
#!  MESSAGE onto a web page - see \clarion12\libsrc\win\WBHOOK.CLW, which is
#!  where the exact prototypes in MsgHookClass.clw come from. This template
#!  wraps all seven, adds a rule table and a log, and gives you somewhere to
#!  put your own code.
#!
#!  WHAT YOU CAN DO WITH ONE
#!      Show it as usual        behave exactly as if we were not here
#!      Ignore it               swallow it and carry on - no window at all
#!      Answer it               swallow it and press a button for the user
#!      Hand it to my procedure your code decides, per event or per rule
#!      Show it as a message    turn a STOP or a HALT into a plain MESSAGE
#!      Halt                    end the program
#!      Log it and swallow it   it goes to the file and nowhere else
#!
#!  ONE EXCEPTION: a HALT cannot be called off. The run-time library ends the
#!  program as soon as the hook returns, whichever action you pick - so for a
#!  HALT these options change what is said on the way out and what lands in the
#!  log, not whether it happens. A STOP really can be ignored.
#!
#!  THE RULES TAB is where it gets useful: test the message text - contains /
#!  starts with / is exactly / matches a * ? pattern - and give the ones that
#!  match their own treatment. Rules are checked in order, the first match
#!  wins, and anything that matches nothing falls back to the default action
#!  for its kind of event.
#!
#!  THE LOG is a plain text file, or CSV, or tab separated, appended to and
#!  closed again on every line - so threads can share it, several copies of
#!  the program can share it, and a line written immediately before a HALT is
#!  still on disk afterwards. Give it a size limit and it rolls over to a .bak
#!  on its own. Each line carries the date and time, the kind of event, the
#!  thread, the window that was on screen, the caption, the text (flattened to
#!  one line), what we did about it, and for an ASSERT the source file and line.
#!
#!  THE TEMPLATES
#!    myHookGlobal (APPLICATION) - the whole thing. Add it once. Everything is
#!                 configured here.
#!    myHookPause  (PROCEDURE)   - let this one procedure's messages through
#!                 untouched, then start intercepting again on the way out.
#!    myHookHere   (CODE)        - install, remove, suspend, resume, or write
#!                 your own line to the log, from any embed.
#!
#!  REQUIRED FILES: copy these (shipped beside this .tpl) to a folder on the
#!  Clarion redirection path (the app folder, or \clarion12\libsrc\win), ANSI:
#!      MsgHookClass.inc    MsgHookClass.clw
#!  MsgHookClass.clw is pulled into the build by its LINK attribute.
#!
#!  API (the object is global - call it from any embed):
#!    MsgHook.Install()                    start intercepting
#!    MsgHook.Remove()                     stop
#!    MsgHook.Suspend() / .Resume()        pause it on this thread only
#!    MsgHook.Write('anything you like')   your own line in the log
#!    MsgHook.Seen[Hook:Message]           how many have come through
#!    MsgHook.Changed[Hook:Message]        how many we interfered with
#!
#!  A NOTE ON PASSING THINGS THROUGH. To show a message the normal way the
#!  class has to lift its own hook first, or the RTL would call straight back
#!  into it. That gap is a few milliseconds and it is process wide, so a
#!  MESSAGE raised on another thread during it goes out un-intercepted. The
#!  RTL's own hook code does exactly the same thing. If that matters, answer
#!  rather than pass through.
#!-----------------------------------------------------------------------------
#SYSTEM
  #EQUATE(%myHookTPLVersion,'1.0')
#!#############################################################################
#!  GROUP - one prototype per distinct name, however many places use it.
#!#############################################################################
#GROUP(%mhProtoOnce,%pName)
#IF(%pName)
  #IF(INSTRING('|' & UPPER(%pName) & '|',%mhSeen,1,1) = 0)
    #SET(%mhSeen,%mhSeen & '|' & UPPER(%pName) & '|')
%pName()
  #ENDIF
#ENDIF
#!#############################################################################
#!  GLOBAL EXTENSION - myHookGlobal
#!#############################################################################
#EXTENSION(myHookGlobal,'myHook - Global message/stop/halt interceptor (add once)'),APPLICATION
#SHEET,HSCROLL
  #TAB('&General')
    #BOXED('About'),SECTION
      #DISPLAY('myHook  v' & %myHookTPLVersion)
      #DISPLAY('Intercepts MESSAGE, STOP, HALT, ASSERT, run-time errors and')
      #DISPLAY('GPFs before the run-time library gets to show them, and lets')
      #DISPLAY('you ignore them, answer them, log them, or hand them to your')
      #DISPLAY('own code.')
      #DISPLAY('')
      #DISPLAY('IMPORTANT: copy MsgHookClass.inc and MsgHookClass.clw to the')
      #DISPLAY('redirection path (the app folder, or \clarion12\libsrc\win).')
      #DISPLAY('Both files must be ANSI. MsgHookClass.clw links itself in.')
    #ENDBOXED
    #BOXED('Options')
      #PROMPT('&Disable this template',CHECK),%mhDisable,DEFAULT(0),AT(10)
      #PROMPT('&Object name:',@s40),%mhObject,DEFAULT('MsgHook'),REQ
      #PROMPT('Start intercepting:',DROP('As soon as the program starts[0]|Only when I call Install() myself[1]')),%mhWhen,DEFAULT('0')
      #DISPLAY('Nothing is intercepted until Install() runs. Pick the second')
      #DISPLAY('one if you want to set things up first, then switch it on from')
      #DISPLAY('an embed with the myHookHere code template.')
    #ENDBOXED
  #ENDTAB
  #TAB('&MESSAGE')
    #BOXED('Every MESSAGE()')
      #PROMPT('&Intercept MESSAGE',CHECK),%mhMsgOn,DEFAULT(0),AT(10)
      #ENABLE(%mhMsgOn)
        #PROMPT('&Do this with it:',DROP('Show it as usual[HookDo:Normal]|Ignore it - no window at all[HookDo:Ignore]|Answer it for the user[HookDo:Answer]|Hand it to my procedure[HookDo:Call]|Write it to the log and swallow it[HookDo:Log]')),%mhMsgAction,DEFAULT('HookDo:Normal')
        #BOXED('Answer with'),WHERE(%mhMsgAction='HookDo:Answer' OR %mhMsgAction='HookDo:Ignore' OR %mhMsgAction='HookDo:Log')
          #PROMPT('&Press this button:',DROP('Ok[BUTTON:Ok]|Yes[BUTTON:Yes]|No[BUTTON:No]|Abort[BUTTON:Abort]|Retry[BUTTON:Retry]|Ignore[BUTTON:Ignore]|Cancel[BUTTON:Cancel]')),%mhMsgAnswer,DEFAULT('BUTTON:Ok')
          #DISPLAY('The value MESSAGE() hands back to whoever called it. Leave')
          #DISPLAY('it on Ok unless the code behind the message tests it.')
        #ENDBOXED
        #BOXED('Your procedure'),WHERE(%mhMsgAction='HookDo:Call')
          #PROMPT('&Call this procedure:',@s64),%mhMsgProc
          #DISPLAY('No parameters. Read the object for everything about it -')
          #DISPLAY('MsgHook.Info.Text, .Caption, .Buttons, .Window, .Thread -')
          #DISPLAY('then set MsgHook.Info.Action to say what happens next, and')
          #DISPLAY('MsgHook.Info.Handled = 1 to stop it being shown at all.')
        #ENDBOXED
      #ENDENABLE
    #ENDBOXED
  #ENDTAB
  #TAB('&STOP and HALT')
    #BOXED('Every STOP()')
      #PROMPT('Intercept &STOP',CHECK),%mhStopOn,DEFAULT(0),AT(10)
      #ENABLE(%mhStopOn)
        #PROMPT('D&o this with it:',DROP('Show it as usual[HookDo:Normal]|Ignore it - carry on regardless[HookDo:Ignore]|Show it as a plain message[HookDo:Show]|Hand it to my procedure[HookDo:Call]|Halt the program[HookDo:Halt]|Write it to the log and carry on[HookDo:Log]')),%mhStopAction,DEFAULT('HookDo:Normal')
        #BOXED('Your procedure'),WHERE(%mhStopAction='HookDo:Call')
          #PROMPT('C&all this procedure:',@s64),%mhStopProc
        #ENDBOXED
        #DISPLAY('A STOP normally offers Abort or Ignore, and Abort ends the')
        #DISPLAY('program. Ignoring it here means the line after the STOP runs.')
      #ENDENABLE
    #ENDBOXED
    #BOXED('Every HALT()')
      #PROMPT('Intercept &HALT',CHECK),%mhHaltOn,DEFAULT(0),AT(10)
      #ENABLE(%mhHaltOn)
        #PROMPT('Do t&his with it:',DROP('Halt as usual, with its message[HookDo:Normal]|Halt, but say nothing[HookDo:Ignore]|Say something else, then halt[HookDo:Show]|Hand it to my procedure, then halt[HookDo:Call]|Write it to the log, then halt[HookDo:Log]')),%mhHaltAction,DEFAULT('HookDo:Log')
        #BOXED('Your procedure'),WHERE(%mhHaltAction='HookDo:Call')
          #PROMPT('Ca&ll this procedure:',@s64),%mhHaltProc
        #ENDBOXED
        #DISPLAY('A HALT cannot be called off - the run-time library ends the')
        #DISPLAY('program as soon as the hook returns, whichever of these you')
        #DISPLAY('pick. What you can do is see it coming, put it in the log,')
        #DISPLAY('change what it says on the way out, or say nothing at all.')
        #DISPLAY('')
        #DISPLAY('A STOP is different - that one really can be ignored.')
      #ENDENABLE
    #ENDBOXED
  #ENDTAB
  #TAB('&Errors')
    #BOXED('Failed ASSERT()')
      #PROMPT('Intercept &ASSERT',CHECK),%mhAssertOn,DEFAULT(0),AT(10)
      #ENABLE(%mhAssertOn)
        #PROMPT('Do this &with it:',DROP('Ask whether to continue, as usual[HookDo:Normal]|Ignore it - carry on[HookDo:Ignore]|Show it, then carry on[HookDo:Show]|Hand it to my procedure[HookDo:Call]|Halt the program[HookDo:Halt]|Write it to the log and carry on[HookDo:Log]')),%mhAssertAction,DEFAULT('HookDo:Log')
        #BOXED('Your procedure'),WHERE(%mhAssertAction='HookDo:Call')
          #PROMPT('Call t&his procedure:',@s64),%mhAssertProc
        #ENDBOXED
        #DISPLAY('The source file and line number come through as')
        #DISPLAY('MsgHook.Info.Module and MsgHook.Info.Line, and go in the log.')
      #ENDENABLE
    #ENDBOXED
    #BOXED('Run-time errors')
      #PROMPT('Intercept run-time &errors',CHECK),%mhFatalOn,DEFAULT(0),AT(10)
      #ENABLE(%mhFatalOn)
        #PROMPT('Do this wit&h it:',DROP('Show it and stop, as usual[HookDo:Normal]|Ignore it - carry on[HookDo:Ignore]|Show it, then carry on[HookDo:Show]|Hand it to my procedure[HookDo:Call]|Write it to the log and carry on[HookDo:Log]')),%mhFatalAction,DEFAULT('HookDo:Normal')
        #BOXED('Your procedure'),WHERE(%mhFatalAction='HookDo:Call')
          #PROMPT('Call th&is procedure:',@s64),%mhFatalProc
        #ENDBOXED
      #ENDENABLE
    #ENDBOXED
  #ENDTAB
  #TAB('G&PFs')
    #BOXED('GPFs and other unhandled exceptions')
      #PROMPT('Intercept &GPFs (LastChanceHook)',CHECK),%mhGpfOn,DEFAULT(0),AT(10)
      #ENABLE(%mhGpfOn)
        #PROMPT('Do this with &it:',DROP('Show it and kill the thread, as usual[HookDo:Normal]|Ignore it - let the thread carry on[HookDo:Ignore]|Show it, then kill the thread[HookDo:Show]|Hand it to my procedure[HookDo:Call]|Halt the program[HookDo:Halt]|Write it to the log and carry on[HookDo:Log]')),%mhGpfAction,DEFAULT('HookDo:Log')
        #BOXED('Your procedure'),WHERE(%mhGpfAction='HookDo:Call')
          #PROMPT('Call this p&rocedure:',@s64),%mhGpfProc
        #ENDBOXED
        #DISPLAY('The exception code and the address it blew up at arrive as')
        #DISPLAY('MsgHook.Info.Code and MsgHook.Info.Address. Carrying on after')
        #DISPLAY('one of these is a gamble - logging it is usually the point.')
        #DISPLAY('')
        #DISPLAY('Do not tick this if something else in the application already')
        #DISPLAY('owns SYSTEM{PROP:LastChanceHook} - a GPF reporter, say. There')
        #DISPLAY('is only one, and the last one set wins.')
      #ENDENABLE
    #ENDBOXED
  #ENDTAB
  #TAB('&Rules')
    #BOXED('Checked in order - the first one that matches wins')
      #BUTTON('Rules'),MULTI(%mhRule,%mhRuleEvent & '<9>' & %mhRuleMode & '<9>' & %mhRuleText & '<9>' & %mhRuleAction),INLINE,PROP(PROP:Hscroll),PROP(PROP:Format,'70L(1)|M~When~90L(1)|M~Test~150L(1)|M~The text~90L(1)|M~Then~')
        #PROMPT('&When it is:',DROP('Any of them[Hook:Any]|A MESSAGE[Hook:Message]|A STOP[Hook:Stop]|A HALT[Hook:Halt]|An ASSERT[Hook:Assert]|A run-time error[Hook:Fatal]|A GPF[Hook:Exception]')),%mhRuleEvent,DEFAULT('Hook:Any')
        #PROMPT('&Look at:',DROP('The text or the caption[HookIn:Either]|The message text[HookIn:Text]|The caption[HookIn:Caption]')),%mhRuleLook,DEFAULT('HookIn:Either')
        #PROMPT('&Test:',DROP('Anything at all[HookMatch:Any]|Contains[HookMatch:Contains]|Starts with[HookMatch:Starts]|Is exactly[HookMatch:Exact]|Matches, with * and ?[HookMatch:Wild]')),%mhRuleMode,DEFAULT('HookMatch:Contains')
        #PROMPT('&For this text:',@s128),%mhRuleText
        #DISPLAY('Not case sensitive. Do not use an apostrophe - it goes into')
        #DISPLAY('the generated source as a quoted string.')
        #PROMPT('Then &do this:',DROP('Show it as usual[HookDo:Normal]|Ignore it[HookDo:Ignore]|Answer it for the user[HookDo:Answer]|Hand it to my procedure[HookDo:Call]|Show it as a plain message[HookDo:Show]|Halt the program[HookDo:Halt]|Write it to the log and swallow it[HookDo:Log]')),%mhRuleAction,DEFAULT('HookDo:Ignore')
        #BOXED('Answer with'),WHERE(%mhRuleAction='HookDo:Answer')
          #PROMPT('&Press this button:',DROP('Ok[BUTTON:Ok]|Yes[BUTTON:Yes]|No[BUTTON:No]|Abort[BUTTON:Abort]|Retry[BUTTON:Retry]|Ignore[BUTTON:Ignore]|Cancel[BUTTON:Cancel]')),%mhRuleAnswer,DEFAULT('BUTTON:Ok')
        #ENDBOXED
        #BOXED('Your procedure'),WHERE(%mhRuleAction='HookDo:Call')
          #PROMPT('&Call this procedure:',@s64),%mhRuleProc
          #DISPLAY('No parameters. MsgHook.Info.Tag tells you which rule fired.')
        #ENDBOXED
        #BOXED('Say something else instead'),WHERE(%mhRuleAction='HookDo:Show' OR %mhRuleAction='HookDo:Normal')
          #PROMPT('&Replace the text with:',@s128),%mhRuleNew
          #DISPLAY('Leave it empty to keep the original wording.')
        #ENDBOXED
      #ENDBUTTON
    #ENDBOXED
    #BOXED('Notes')
      #DISPLAY('A rule only fires for an event you are intercepting on the')
      #DISPLAY('tabs above - the hook has to be in place before a rule can be')
      #DISPLAY('consulted.')
      #DISPLAY('')
      #DISPLAY('Anything that matches no rule gets the default action for its')
      #DISPLAY('kind of event.')
    #ENDBOXED
  #ENDTAB
  #TAB('&Log')
    #BOXED('The log file')
      #PROMPT('&Write a log',CHECK),%mhLogOn,DEFAULT(0),AT(10)
      #ENABLE(%mhLogOn)
        #PROMPT('&File:',@s255),%mhLogFile,DEFAULT('.\myHook.log')
        #PROMPT('That is:',DROP('A file name I typed[0]|A variable or an expression[1]')),%mhLogKind,DEFAULT('0')
        #DISPLAY('A typed name is quoted for you. Pick the second one to use a')
        #DISPLAY('global variable or something like CLIP(GLO:LogPath) & manifest')
        #DISPLAY('- it is written into the source exactly as you type it.')
        #PROMPT('F&ormat:',DROP('Readable text[HookLog:Text]|CSV, for a spreadsheet[HookLog:CSV]|Tab separated[HookLog:Tab]')),%mhLogFormat,DEFAULT('HookLog:Text')
        #PROMPT('Log &which ones:',DROP('Every one that comes through[HookLogged:All]|Only the ones we changed[HookLogged:Changed]')),%mhLogWhat,DEFAULT('HookLogged:All')
        #PROMPT('Put the date and &time in front',CHECK),%mhLogStamp,DEFAULT(1),AT(10)
        #PROMPT('Record the window that was on &screen',CHECK),%mhLogWindow,DEFAULT(1),AT(10)
        #PROMPT('&Roll over past (KB, 0 = let it grow):',@n7),%mhLogMax,DEFAULT(0)
        #DISPLAY('Past that size the file is renamed to .bak and a fresh one')
        #DISPLAY('started. Only the one .bak is kept.')
      #ENDENABLE
    #ENDBOXED
    #BOXED('What a line looks like')
      #DISPLAY('2026-07-27 14:32:06  [MESSAGE]  "Delete"  Delete this record?')
      #DISPLAY('   -> answered No  {thread 1, Update an Order}')
      #DISPLAY('')
      #DISPLAY('The file is opened for append and closed again on every line,')
      #DISPLAY('so threads can share it, two copies of the program can share')
      #DISPLAY('it, and a line written just before a HALT is still there.')
    #ENDBOXED
  #ENDTAB
  #TAB('&Advanced')
    #BOXED('Prototypes')
      #PROMPT('Add a &prototype for each procedure I named',CHECK),%mhProto,DEFAULT(0),AT(10)
      #DISPLAY('Leave this off if the procedures you named are the')
      #DISPLAY('application''s own - AppGen prototypes those already, and a')
      #DISPLAY('second prototype is a duplicate. Tick it only for procedures')
      #DISPLAY('that live in hand-written source. Each name is added once,')
      #DISPLAY('however many places use it.')
    #ENDBOXED
    #BOXED('Multi-DLL')
      #DISPLAY('The object is declared in whichever target owns it and')
      #DISPLAY('imported EXTERNAL by the others, so one set of rules and one')
      #DISPLAY('log covers the whole application. The class links its own copy')
      #DISPLAY('of MsgHookClass.clw into every target - only the shared')
      #DISPLAY('instance is exported.')
    #ENDBOXED
  #ENDTAB
#ENDSHEET
#!-----------------------------------------------------------------------------
#!  The class.
#!-----------------------------------------------------------------------------
#AT(%AfterGlobalIncludes),WHERE(%mhDisable=0),PRIORITY(4000),DESCRIPTION('myHook - class include')
INCLUDE('MsgHookClass.INC'),ONCE
#ENDAT
#!-----------------------------------------------------------------------------
#!  The object. The target that owns it gets the derived class, so TakeEvent
#!  can reach the procedures named on the tabs; every other target imports the
#!  one instance, and its virtual method still lands in the owner's code.
#!-----------------------------------------------------------------------------
#AT(%GlobalData),WHERE(%mhDisable=0),DESCRIPTION('myHook - the interceptor')
  #IF(%DefaultExternal = 'None External')
%mhObject   CLASS(MsgHookClass)                            ! the interceptor
TakeEvent     PROCEDURE(),DERIVED                          ! hands over to your procedures
            END
  #ELSE
%mhObject   MsgHookClass,EXTERNAL,DLL(dll_mode)            ! imported from the root DLL
  #ENDIF
#ENDAT
#!
#AT(%DLLExportList),WHERE(%mhDisable=0)
  #IF(%DefaultExternal = 'None External' AND %ProgramExtension='DLL' AND %DefaultExport)
$%mhObject  @?                                             ! export the shared instance
  #ENDIF
#ENDAT
#!-----------------------------------------------------------------------------
#!  Prototypes, but only for procedures that are not the application's own, and
#!  only once per name however many tabs and rules point at it.
#!-----------------------------------------------------------------------------
#AT(%GlobalMap),WHERE(%mhDisable=0 AND %mhProto=1),DESCRIPTION('myHook - handler prototypes')
  #IF(%DefaultExternal = 'None External')
    #IF(VAREXISTS(%mhSeen)=0)
      #DECLARE(%mhSeen)
    #ENDIF
    #SET(%mhSeen,'')
    #IF(%mhMsgOn AND %mhMsgAction='HookDo:Call')
      #INSERT(%mhProtoOnce,%mhMsgProc)
    #ENDIF
    #IF(%mhStopOn AND %mhStopAction='HookDo:Call')
      #INSERT(%mhProtoOnce,%mhStopProc)
    #ENDIF
    #IF(%mhHaltOn AND %mhHaltAction='HookDo:Call')
      #INSERT(%mhProtoOnce,%mhHaltProc)
    #ENDIF
    #IF(%mhAssertOn AND %mhAssertAction='HookDo:Call')
      #INSERT(%mhProtoOnce,%mhAssertProc)
    #ENDIF
    #IF(%mhFatalOn AND %mhFatalAction='HookDo:Call')
      #INSERT(%mhProtoOnce,%mhFatalProc)
    #ENDIF
    #IF(%mhGpfOn AND %mhGpfAction='HookDo:Call')
      #INSERT(%mhProtoOnce,%mhGpfProc)
    #ENDIF
    #FOR(%mhRule),WHERE(%mhRuleAction='HookDo:Call')
      #INSERT(%mhProtoOnce,%mhRuleProc)
    #ENDFOR
  #ENDIF
#ENDAT
#!-----------------------------------------------------------------------------
#!  Setting it up, at program start, in the target that owns the object.
#!-----------------------------------------------------------------------------
#AT(%ProgramSetup),PRIORITY(4000),WHERE(%mhDisable=0),DESCRIPTION('myHook - set up the interceptor')
  #IF(%DefaultExternal = 'None External')
!--- myHook: what happens to the run-time library's own dialogs ---------------
    #IF(%mhMsgOn)
      #IF(%mhMsgAnswer AND (%mhMsgAction='HookDo:Answer' OR %mhMsgAction='HookDo:Ignore' OR %mhMsgAction='HookDo:Log'))
%mhObject.SetEvent(Hook:Message,%mhMsgAction,%mhMsgAnswer)
      #ELSE
%mhObject.SetEvent(Hook:Message,%mhMsgAction)
      #ENDIF
    #ENDIF
    #IF(%mhStopOn)
%mhObject.SetEvent(Hook:Stop,%mhStopAction)
    #ENDIF
    #IF(%mhHaltOn)
%mhObject.SetEvent(Hook:Halt,%mhHaltAction)
    #ENDIF
    #IF(%mhAssertOn)
%mhObject.SetEvent(Hook:Assert,%mhAssertAction)
    #ENDIF
    #IF(%mhFatalOn)
%mhObject.SetEvent(Hook:Fatal,%mhFatalAction)
    #ENDIF
    #IF(%mhGpfOn)
%mhObject.SetEvent(Hook:Exception,%mhGpfAction)
    #ENDIF
    #IF(ITEMS(%mhRule))
!--- the rules, in the order they were entered - the first match wins ---------
      #IF(VAREXISTS(%mhAns)=0)
        #DECLARE(%mhAns)
      #ENDIF
      #FOR(%mhRule)
        #SET(%mhAns,'0')
        #IF(%mhRuleAction='HookDo:Answer' AND %mhRuleAnswer)
          #SET(%mhAns,%mhRuleAnswer)
        #ENDIF
        #IF(%mhRuleNew AND (%mhRuleAction='HookDo:Show' OR %mhRuleAction='HookDo:Normal'))
%mhObject.AddRule(%mhRuleEvent,'%mhRuleText',%mhRuleMode,%mhRuleAction,%mhAns,%mhRuleLook,'%mhRuleNew')
        #ELSE
%mhObject.AddRule(%mhRuleEvent,'%mhRuleText',%mhRuleMode,%mhRuleAction,%mhAns,%mhRuleLook)
        #ENDIF
      #ENDFOR
    #ENDIF
    #IF(%mhLogOn)
!--- the log -----------------------------------------------------------------
%mhObject.LogStamp  = %mhLogStamp
%mhObject.LogWindow = %mhLogWindow
      #IF(VAREXISTS(%mhCap)=0)
        #DECLARE(%mhCap)
      #ENDIF
      #IF(%mhLogMax)
        #SET(%mhCap,%mhLogMax & ' * 1024')
      #ELSE
        #SET(%mhCap,'0')
      #ENDIF
      #IF(%mhLogKind=1)
%mhObject.SetLog(%mhLogFile,%mhLogFormat,%mhLogWhat,%mhCap)
      #ELSE
%mhObject.SetLog('%mhLogFile',%mhLogFormat,%mhLogWhat,%mhCap)
      #ENDIF
    #ENDIF
    #IF(%mhWhen=0)
%mhObject.Install()                                        ! from here on we are listening
    #ELSE
!--- Install() is yours to call - drop in the myHookHere code template --------
    #ENDIF
  #ENDIF
#ENDAT
#!-----------------------------------------------------------------------------
#!  Off again on the way out. Destruct would do it too, but doing it here means
#!  anything the shutdown itself says still comes out the normal way.
#!-----------------------------------------------------------------------------
#AT(%ProgramEnd),WHERE(%mhDisable=0),DESCRIPTION('myHook - stop intercepting')
  #IF(%DefaultExternal = 'None External')
%mhObject.Remove()
  #ENDIF
#ENDAT
#!-----------------------------------------------------------------------------
#!  The hand-off to your procedures. Generated whether or not anything points
#!  at it - an empty one costs a CODE statement and keeps the derived class
#!  honest.
#!-----------------------------------------------------------------------------
#AT(%ProgramProcedures),WHERE(%mhDisable=0),DESCRIPTION('myHook - hand-off to your procedures')
  #IF(%DefaultExternal = 'None External')
!=============================================================================
! myHook - reached when an intercepted event is set to "hand it to my
! procedure". Everything about it is in SELF.Info:
!
!   SELF.Info.Event     Hook:Message / Hook:Stop / Hook:Halt / Hook:Assert /
!                       Hook:Fatal / Hook:Exception
!   SELF.Info.Text      what it says          SELF.Info.Caption   the title bar
!   SELF.Info.Buttons   the buttons offered   SELF.Info.Window    what was on screen
!   SELF.Info.Module    ASSERT source file    SELF.Info.Line      ASSERT line
!   SELF.Info.Code      halt code / error no  SELF.Info.Thread    the thread
!   SELF.Info.Tag       which rule fired, 0 if none
!
! Set SELF.Info.Action to change your mind, SELF.Info.Answer for the button to
! hand back, and SELF.Info.Handled = 1 to say it is dealt with and nothing more
! should be shown.
!=============================================================================
%mhObject.TakeEvent PROCEDURE()
  CODE
    #IF(VAREXISTS(%mhRuleNo)=0)
      #DECLARE(%mhRuleNo)
    #ENDIF
    #SET(%mhRuleNo,0)
    #FOR(%mhRule)
      #SET(%mhRuleNo,%mhRuleNo+1)
      #IF(%mhRuleAction='HookDo:Call' AND %mhRuleProc)
  IF SELF.Info.Tag = %mhRuleNo                             ! rule %mhRuleNo: %mhRuleText
    %mhRuleProc
    RETURN
  END
      #ENDIF
    #ENDFOR
    #IF(%mhMsgOn AND %mhMsgAction='HookDo:Call' AND %mhMsgProc)
  IF SELF.Info.Event = Hook:Message
    %mhMsgProc
    RETURN
  END
    #ENDIF
    #IF(%mhStopOn AND %mhStopAction='HookDo:Call' AND %mhStopProc)
  IF SELF.Info.Event = Hook:Stop
    %mhStopProc
    RETURN
  END
    #ENDIF
    #IF(%mhHaltOn AND %mhHaltAction='HookDo:Call' AND %mhHaltProc)
  IF SELF.Info.Event = Hook:Halt
    %mhHaltProc
    RETURN
  END
    #ENDIF
    #IF(%mhAssertOn AND %mhAssertAction='HookDo:Call' AND %mhAssertProc)
  IF SELF.Info.Event = Hook:Assert
    %mhAssertProc
    RETURN
  END
    #ENDIF
    #IF(%mhFatalOn AND %mhFatalAction='HookDo:Call' AND %mhFatalProc)
  IF SELF.Info.Event = Hook:Fatal
    %mhFatalProc
    RETURN
  END
    #ENDIF
    #IF(%mhGpfOn AND %mhGpfAction='HookDo:Call' AND %mhGpfProc)
  IF SELF.Info.Event = Hook:Exception
    %mhGpfProc
    RETURN
  END
    #ENDIF
  #EMBED(%myHookTakeEvent,'myHook - your own code, every intercepted event'),HIDE
  RETURN
  #ENDIF
#ENDAT
#!#############################################################################
#!  PROCEDURE EXTENSION - myHookPause
#!#############################################################################
#EXTENSION(myHookPause,'myHook - let this procedure be noisy (suspend interception)'),PROCEDURE
#SHEET
  #TAB('&General')
    #BOXED('myHook - suspend')
      #DISPLAY('While this procedure is open, MESSAGE, STOP and the rest come')
      #DISPLAY('out the normal way on this thread - the rules and the log sit')
      #DISPLAY('this one out. Interception starts again when it closes.')
      #DISPLAY('')
      #DISPLAY('Handy for a diagnostic window, or a procedure whose messages')
      #DISPLAY('you genuinely want the user to see.')
    #ENDBOXED
    #BOXED('Options')
      #PROMPT('&Disable this template',CHECK),%mhpDisable,DEFAULT(0),AT(10)
      #PROMPT('&Object name:',@s40),%mhpObject,DEFAULT('MsgHook'),REQ
      #DISPLAY('The same name as on the global extension.')
    #ENDBOXED
  #ENDTAB
#ENDSHEET
#!
#AT(%WindowManagerMethodCodeSection,'Init','(),BYTE'),PRIORITY(2000),WHERE(%mhpDisable=0),DESCRIPTION('myHook - suspend interception')
%mhpObject.Suspend()                                       ! this thread only
#ENDAT
#!
#AT(%WindowManagerMethodCodeSection,'Kill','(),BYTE'),PRIORITY(7500),WHERE(%mhpDisable=0),DESCRIPTION('myHook - resume interception')
%mhpObject.Resume()
#ENDAT
#!#############################################################################
#!  CODE TEMPLATE - myHookHere
#!#############################################################################
#CODE(myHookHere,'myHook - install, remove, suspend, resume or log from here')
#SHEET
  #TAB('&General')
    #BOXED('Do this here')
      #PROMPT('&Object name:',@s40),%mhcObject,DEFAULT('MsgHook'),REQ
      #PROMPT('&Action:',DROP('Start intercepting (Install)[0]|Stop intercepting (Remove)[1]|Suspend it on this thread[2]|Resume it on this thread[3]|Write my own line to the log[4]|Log how many have been seen[5]')),%mhcWhat,DEFAULT('0')
      #BOXED('The line'),WHERE(%mhcWhat=4)
        #PROMPT('&Text:',@s200),%mhcText
        #PROMPT('That is:',DROP('Text I typed[0]|A variable or an expression[1]')),%mhcKind,DEFAULT('0')
        #DISPLAY('A typed line is quoted for you. Pick the second one for')
        #DISPLAY('something like CLIP(GLO:User) & <39> signed on<39>.')
      #ENDBOXED
    #ENDBOXED
  #ENDTAB
#ENDSHEET
#CASE(%mhcWhat)
#OF('0')
%mhcObject.Install()
#OF('1')
%mhcObject.Remove()
#OF('2')
%mhcObject.Suspend()
#OF('3')
%mhcObject.Resume()
#OF('4')
  #IF(%mhcKind=1)
%mhcObject.Write(%mhcText)
  #ELSE
%mhcObject.Write('%mhcText')
  #ENDIF
#OF('5')
%mhcObject.Write('MESSAGE ' & %mhcObject.Seen[Hook:Message] & ' seen, ' & %mhcObject.Changed[Hook:Message] & ' changed' & |
                 '; STOP ' & %mhcObject.Seen[Hook:Stop] & '/' & %mhcObject.Changed[Hook:Stop] & |
                 '; HALT ' & %mhcObject.Seen[Hook:Halt] & '/' & %mhcObject.Changed[Hook:Halt] & |
                 '; ASSERT ' & %mhcObject.Seen[Hook:Assert] & '/' & %mhcObject.Changed[Hook:Assert] & |
                 '; ERROR ' & %mhcObject.Seen[Hook:Fatal] & '/' & %mhcObject.Changed[Hook:Fatal] & |
                 '; GPF ' & %mhcObject.Seen[Hook:Exception] & '/' & %mhcObject.Changed[Hook:Exception])
#ENDCASE
