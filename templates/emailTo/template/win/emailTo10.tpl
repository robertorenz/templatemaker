#TEMPLATE(emailTo,'emailTo - Send e-mail from Clarion and manage the account: SMTP/TLS, OAuth2 and nine provider APIs - v1.12 (2026-08-24 22:45) - Clarion 10 (480) layout'),FAMILY('ABC')
#!
#!  Set by emailTo - Provider API when the application carries it, and read by
#!  every template that writes a call to that object. A control template on a
#!  window cannot see another extension's prompts, and without this it writes
#!  MailApi.Supports(...) into an application that never declared MailApi.
#SYSTEM
#DECLARE(%ETApiHere)
#DECLARE(%ETApiWanted),MULTI,UNIQUE
#!-----------------------------------------------------------------------------
#!  emailTo template set  -  send e-mail from a Clarion application, four ways,
#!  with no third-party DLL, no .NET and no OpenSSL to deploy.
#!
#!      SMTP          plain / STARTTLS / implicit TLS, on any server, signing
#!                    in with AUTH LOGIN, AUTH PLAIN or OAuth2 (XOAUTH2).
#!      Gmail API     one https POST to gmail.googleapis.com.
#!      MS Graph      one https POST to graph.microsoft.com - the only route
#!                    many locked-down Microsoft 365 tenants still allow.
#!      API key       SendGrid / Mailgun / Resend / Brevo / Postmark /
#!                    Mailjet / SparkPost / MailerSend.
#!
#!  AND IT ASKS THEM QUESTIONS TOO.  Sending is half of what a mail provider
#!  does.  EmailApiClass drives the other half through the SAME account and
#!  ONE set of methods, whichever of the eight you signed up with:
#!
#!      who is blocked, and WHY .... GetSuppressions()  address, kind, reason
#!      unblock one, or all ........ DeleteSuppression() DeleteAllSuppressions()
#!      statistics per day ......... GetStats()
#!      what happened to a message . GetEvents()
#!      contacts and lists ......... GetContacts() GetLists() AddContact()
#!      campaigns .................. GetCampaigns() AddCampaign() SendCampaign()
#!      templates, senders, domains and webhooks
#!
#!  Every answer arrives in the same normalised queue whoever sent it, and
#!  Manage() is a ready-made window over the lot.
#!
#!  HOW IT IS BUILT.  Everything is pure Clarion except one bundled C file,
#!  emailc.c, which is compiled into your .EXE by Clarion's own C compiler
#!  through PRAGMA('compile(emailc.c)'). That file exists because Clarion
#!  cannot do four things for itself: TCP sockets, the SCHANNEL TLS handshake,
#!  WinHTTP, and DPAPI. MIME, base64, quoted-printable, the SMTP conversation,
#!  OAuth2 with PKCE, JSON and every provider preset are Clarion source you can
#!  read and step through. Nothing is bound at link time to a DLL you have to
#!  ship: ws2_32, secur32, winhttp and crypt32 are all part of Windows and are
#!  loaded at run time, so a machine missing one gives a clean error message
#!  instead of failing to start.
#!
#!  THE TEMPLATES
#!    emailToGlobal   (APPLICATION) - REQUIRED once per app. Declares the mail
#!                    object, sets the account defaults, and - if you nominate
#!                    one - generates the code that reads and writes your own
#!                    settings TABLE.
#!    emailToButton   (CONTROL)     - drag onto any window for a ready-wired
#!                    "E-mail..." button.
#!    emailToSend     (CODE)        - send from any embed: your own button, a
#!                    menu item, the end of a report, a batch process.
#!    emailToCompose  (CODE)        - open the write-and-send window.
#!    emailToSetup    (CODE)        - open the account setup window, where the
#!                    end user types the server or presses "Sign in..." to run
#!                    the OAuth2 consent flow in their browser.
#!
#!  REQUIRED FILES: copy these (shipped beside this .tpl) to a folder on the
#!  Clarion redirection path (the app folder, or \clarion12\libsrc\win), ANSI:
#!      EmailNetClass.inc   EmailNetClass.clw
#!      EmailMsgClass.inc   EmailMsgClass.clw
#!      EmailToClass.inc    EmailToClass.clw
#!      EmailJsonClass.inc  EmailJsonClass.clw
#!      EmailApiClass.inc   EmailApiClass.clw
#!      emailc.c
#!  The .clw files pull themselves into the build through their LINK attribute,
#!  and EmailNetClass.clw pulls in emailc.c through its PRAGMA.
#!
#!  API (the object is global - call it from any embed in any procedure):
#!    Mailer.SendSimple(to, subject, body [, attachment])   1 = sent
#!    Mailer.Send(Mailer.Msg)      after composing Mailer.Msg yourself
#!    Mailer.Compose()             the write-and-send window
#!    Mailer.Setup()               the account setup window
#!    Mailer.TestAccount()         connect + sign in + hang up, sends nothing
#!    Mailer.LastErrorText         why the last call said no
#!
#!  API (the second object, when the Provider API tab is switched on):
#!    MailApi.GetSuppressions()    fills MailApi.SuppQ - who is blocked and why
#!    MailApi.DeleteSuppression(address, kind)      let one back in
#!    MailApi.DeleteAllSuppressions(kind)           let them all back in
#!    MailApi.IsBlocked(address)   1 = do not bother sending
#!    MailApi.Manage()             the whole management window
#!    MailApi.Supports(op)         0 = this provider does not offer it
#!-----------------------------------------------------------------------------
#!#############################################################################
#!  GLOBAL EXTENSION - emailToGlobal
#!#############################################################################
#EXTENSION(emailToGlobal,'emailTo - Global (add once per application)'),APPLICATION,HLP('~emailTo.htm')
#SHEET
  #TAB('&General')
    #BOXED('emailTo')
      #DISPLAY('emailTo v1.12 - built 2026-08-24 22:45 Global extension - add  [480]')
      #DISPLAY('once per application. Makes the mail object available to every')
      #DISPLAY('procedure in the app.')
      #DISPLAY('')
      #DISPLAY('IMPORTANT: copy these files to the redirection path (the app')
      #DISPLAY('folder, or \clarion12\libsrc\win). All must be ANSI:')
      #DISPLAY('    EmailNetClass.inc / .clw     EmailMsgClass.inc / .clw')
      #DISPLAY('    EmailToClass.inc  / .clw     EmailJsonClass.inc / .clw')
      #DISPLAY('    EmailApiClass.inc / .clw     emailc.c')
      #DISPLAY('')
      #DISPLAY('emailc.c is compiled into your EXE by Clarion''s own C')
      #DISPLAY('compiler. There is no DLL to ship and nothing to register.')
    #ENDBOXED
    #BOXED('Options')
      #PROMPT('&Disable this template',CHECK),%ETgDisable,DEFAULT(0),AT(10)
      #PROMPT('&Object name:',@s64),%ETgObject,REQ,DEFAULT('Mailer')
      #PROMPT('&Language:',DROP('English[1]|Espa' & CHR(241) & 'ol (Spanish)[2]')),%ETgLanguage,DEFAULT('1')
      #PROMPT('&Keep a conversation log',CHECK),%ETgTrace,DEFAULT(1),AT(10)
      #DISPLAY('The log is what the Setup window shows on its Log tab.')
      #DISPLAY('Passwords and tokens are masked before they reach it.')
    #ENDBOXED
  #ENDTAB
  #TAB('Up&grade')
    #BOXED('Upgraded from v1.03? The API moved out of here')
      #DISPLAY('v1.03 put the Provider API on a tab of THIS extension. It is now')
      #DISPLAY('an extension of its own - "emailTo - Provider API" - so that')
      #DISPLAY('adding it never disturbs an application that does not want it,')
      #DISPLAY('and so that an app built before v1.03 keeps generating')
      #DISPLAY('without being touched at all.')
      #DISPLAY('')
      #DISPLAY('If you had it switched on here: Global Properties > Extensions')
      #DISPLAY('> Insert > "emailTo - Provider API", and put the object name')
      #DISPLAY('back. Anything this tab used to store is ignored.')
    #ENDBOXED
  #ENDTAB
  #TAB('&Account')
    #BOXED('Where these settings come from')
      #DISPLAY('These are the DEFAULTS the object starts with. If you')
      #DISPLAY('nominate a settings table on the Table tab, whatever it holds')
      #DISPLAY('overrides them at start-up, and the Setup window writes')
      #DISPLAY('changes back. With no table, they are the defaults and the')
      #DISPLAY('Setup window saves to an INI file beside the EXE.')
    #ENDBOXED
    #BOXED('Account')
      #PROMPT('&Provider:',DROP('Other (SMTP)[0]|Gmail[1]|Outlook.com / Hotmail[2]|Microsoft 365[3]|Yahoo Mail[4]|iCloud Mail[5]|Zoho Mail[6]|Amazon SES[7]|SendGrid[8]|Mailgun[9]|Resend[10]|Brevo[11]|Postmark[12]|Mailjet[13]|SparkPost[14]|MailerSend[15]')),%ETgProvider,DEFAULT('0')
      #PROMPT('Send &using:',DROP('SMTP server[1]|Gmail API (https)[2]|Microsoft Graph (https)[3]|Provider API key (https)[4]')),%ETgTransport,DEFAULT('1')
      #PROMPT('&From address:',@s255),%ETgFromAddr,DEFAULT('')
      #PROMPT('From &name:',@s128),%ETgFromName,DEFAULT('')
      #PROMPT('&Reply to:',@s255),%ETgReplyTo,DEFAULT('')
    #ENDBOXED
    #BOXED('SMTP server')
      #PROMPT('&Server:',@s128),%ETgHost,DEFAULT('')
      #PROMPT('&Port:',@n5),%ETgPort,DEFAULT(587)
      #PROMPT('Se&curity:',DROP('None - plain, port 25[0]|STARTTLS - port 587[1]|TLS / SSL - port 465[2]')),%ETgSecurity,DEFAULT('1')
      #PROMPT('Sign in &with:',DROP('Nothing[0]|Password (AUTH LOGIN)[1]|Password (AUTH PLAIN)[2]|OAuth2 token (XOAUTH2)[3]')),%ETgAuth,DEFAULT('1')
      #PROMPT('&User name:',@s255),%ETgUser,DEFAULT('')
      #PROMPT('Pass&word:',@s255),%ETgPassword,DEFAULT('')
      #DISPLAY('A password typed here is COMPILED IN. For anything you')
      #DISPLAY('would not publish, leave it blank and let the Setup window')
      #DISPLAY('store it - that path encrypts it with DPAPI for the Windows')
      #DISPLAY('user.')
    #ENDBOXED
  #ENDTAB
  #TAB('&Sign-in')
    #BOXED('OAuth2 - Gmail, Outlook.com and Microsoft 365')
      #DISPLAY('Register a DESKTOP application with the provider and paste its')
      #DISPLAY('Client ID here. A desktop client ID is not a secret: emailTo uses')
      #DISPLAY('the PKCE flow, so nothing confidential is in your EXE.')
      #DISPLAY('')
      #DISPLAY('  Google     console.cloud.google.com > Credentials >')
      #DISPLAY('             OAuth client ID > Desktop app')
      #DISPLAY('  Microsoft  portal.azure.com > App registrations > New >')
      #DISPLAY('             Public client, redirect http://localhost')
      #DISPLAY('')
      #DISPLAY('Both must allow the loopback redirect')
      #DISPLAY('http://127.0.0.1:<port>/ which is what a desktop app')
      #DISPLAY('registration gives you.')
      #PROMPT('Client &ID:',@s255),%ETgClientId,DEFAULT('')
      #PROMPT('Client &secret:',@s255),%ETgClientSecret,DEFAULT('')
      #DISPLAY('(leave the secret blank for Microsoft, and for Google desktop')
      #DISPLAY(' clients that were not issued one)')
      #PROMPT('&Tenant:',@s128),%ETgTenant,DEFAULT('common')
      #DISPLAY('Microsoft only: common, organizations, or your tenant GUID.')
    #ENDBOXED
    #BOXED('API key services')
      #PROMPT('API &key:',@s255),%ETgApiKey,DEFAULT('')
      #PROMPT('API &domain:',@s128),%ETgApiDomain,DEFAULT('')
      #DISPLAY('The domain is Mailgun only - the domain you send from. For')
      #DISPLAY('Mailjet, put the PUBLIC key in User name (Account tab) and')
      #DISPLAY('the PRIVATE key here.')
    #ENDBOXED
  #ENDTAB
  #TAB('&Table')
    #BOXED('Keep the account in one of your own tables')
      #DISPLAY('Nominate a table and emailTo generates the code that reads it')
      #DISPLAY('at start-up and writes it back when the Setup window saves.')
      #DISPLAY('Leave the table blank to use an INI file beside the EXE.')
      #DISPLAY('')
      #DISPLAY('EmailTables.txt (shipped beside this template) has a')
      #DISPLAY('ready-made structure you can paste straight into your')
      #DISPLAY('dictionary.')
      #PROMPT('Settings &table:',FILE),%ETgFile
      #ENABLE(%ETgFile)
        #PROMPT('&Key to find the account by:',KEY(%ETgFile)),%ETgKey,REQ
        #PROMPT('&Account to load at start-up:',@s64),%ETgLoadName,DEFAULT('default')
        #DISPLAY('The value put in the Account name column before the GET.')
        #DISPLAY('Blank means: load the first record in the table.')
        #PROMPT('Create the row if it is &missing',CHECK),%ETgCreateRow,DEFAULT(1),AT(10)
      #ENDENABLE
    #ENDBOXED
    #ENABLE(%ETgFile)
      #BOXED('Columns - the account itself')
        #PROMPT('Account &name:',FIELD(%ETgFile)),%ETgColName,REQ
        #PROMPT('&Provider:',FIELD(%ETgFile)),%ETgColProvider
        #PROMPT('&Transport:',FIELD(%ETgFile)),%ETgColTransport
        #PROMPT('&Host:',FIELD(%ETgFile)),%ETgColHost
        #PROMPT('P&ort:',FIELD(%ETgFile)),%ETgColPort
        #PROMPT('&Security:',FIELD(%ETgFile)),%ETgColSecurity
        #PROMPT('&Auth mode:',FIELD(%ETgFile)),%ETgColAuth
      #ENDBOXED
    #ENDENABLE
  #ENDTAB
  #TAB('Ta&ble columns')
    #ENABLE(%ETgFile)
      #BOXED('Columns - credentials and addresses')
        #PROMPT('&User name:',FIELD(%ETgFile)),%ETgColUser
        #PROMPT('&Password:',FIELD(%ETgFile)),%ETgColPassword
        #PROMPT('&From address:',FIELD(%ETgFile)),%ETgColFromAddr
        #PROMPT('From &name:',FIELD(%ETgFile)),%ETgColFromName
        #PROMPT('&Reply to:',FIELD(%ETgFile)),%ETgColReplyTo
      #ENDBOXED
    #ENDENABLE
  #ENDTAB
  #TAB('Table col&umns 2')
    #ENABLE(%ETgFile)
      #BOXED('Columns - OAuth2 and API keys')
        #PROMPT('Client &ID:',FIELD(%ETgFile)),%ETgColClientId
        #PROMPT('Client &secret:',FIELD(%ETgFile)),%ETgColSecret
        #PROMPT('&Tenant:',FIELD(%ETgFile)),%ETgColTenant
        #PROMPT('Re&fresh token:',FIELD(%ETgFile)),%ETgColRefresh
        #PROMPT('API &key:',FIELD(%ETgFile)),%ETgColApiKey
        #PROMPT('API &domain:',FIELD(%ETgFile)),%ETgColApiDomain
        #DISPLAY('')
        #DISPLAY('A column named ApiKey2, ApiRegion or ApiBase is filled too,')
        #DISPLAY('by NAME - no prompt, nothing to map. They are what the')
        #DISPLAY('Provider API extension reads: Postmark''s account token, the')
        #DISPLAY('European endpoints, and a host of your own.')
        #DISPLAY('')
        #DISPLAY('Password, client secret, refresh token and API key are stored')
        #DISPLAY('through Seal(): DPAPI encrypts them for the current Windows')
        #DISPLAY('user, then base64 makes the result safe for a text column.')
        #DISPLAY('Make those columns at least 400 characters, and the refresh')
        #DISPLAY('token column 2000. A row copied to another machine is')
        #DISPLAY('useless.')
      #ENDBOXED
    #ENDENABLE
    #BOXED('')
      #DISPLAY('Every column is optional except the account name. A column')
      #DISPLAY('you leave blank simply keeps whatever the Account tab set.')
    #ENDBOXED
  #ENDTAB
  #TAB('&Multi-DLL')
    #BOXED('Where the classes live')
      #DISPLAY('Out of the box emailTo follows this application''s own External')
      #DISPLAY('setting, which is already what a multi-DLL suite wants:')
      #DISPLAY('')
      #DISPLAY('  the app that owns the data (External: None) compiles the')
      #DISPLAY('  three classes in, exports them from its own .EXP and owns')
      #DISPLAY('  the mail object; every app set to External: DLL imports')
      #DISPLAY('  them instead of compiling its own copy.')
      #DISPLAY('')
      #DISPLAY('Add this extension to EVERY app in the suite and leave the box')
      #DISPLAY('below alone.')
      #DISPLAY('')
      #DISPLAY('emailc.c is compiled only into the app that owns the classes,')
      #DISPLAY('because the PRAGMA lives in EmailNetClass.clw.')
    #ENDBOXED
  #ENDTAB
  #TAB('Cl&asses')
    #BOXED('Override - place the classes by hand')
      #INSERT(%AbcLibraryPrompts(ABC))
      #DISPLAY('')
      #DISPLAY('Linked in    - compile the classes into this app (and, if this')
      #DISPLAY('               app is a DLL, export them from it).')
      #DISPLAY('External DLL - import them from another DLL in the suite.')
      #DISPLAY('External LIB - link against a .LIB you built yourself.')
      #DISPLAY('None         - do neither; you add the .clw files yourself.')
    #ENDBOXED
    #BOXED('If the classes are missing from the generated .EXP')
      #DISPLAY('The export list is built from the IDE''s class registry. If')
      #DISPLAY('EmailToClass is not in it yet, press "Refresh Application Builder')
      #DISPLAY('Class Information" on the Global Properties Classes tab (or')
      #DISPLAY('close and re-open the application) and generate again.')
    #ENDBOXED
  #ENDTAB
#ENDSHEET
#!
#!--- the three includes -------------------------------------------------------
#!
#!--- tell the application which of your tables we touch -----------------------
#!  Access:<table> only exists for a table the application knows it uses, and
#!  what makes ABPROGRM declare one is not #ADD(%UsedFile) - that fills a list
#!  nobody reads on its own - but #FIX(%File) followed by
#!  #SET(%CacheFileUsed, %True).  Miss it and every Access: line the template
#!  writes comes back as "Unknown procedure label", on a line the developer
#!  never typed.  (Corpus: wbguard.tpw:113 does exactly this for its own
#!  security table.)
#AT(%CustomGlobalDeclarations),WHERE(%ETgDisable=0)
  #INSERT(%ETyRelate,%ETgFile)
#ENDAT
#!
#!  %BeforeFileDeclarations, because that is the DATA embed immediately in
#!  front of %GenerateFileDeclarations. Registering at %ProgramSetup - a CODE
#!  embed - is too late: the declarations have already been written by then,
#!  and the File Declaration region comes out empty.
#AT(%BeforeFileDeclarations),WHERE(%ETgDisable=0)
  #INSERT(%ETyUseFile,%ETgFile)
#ENDAT
#!
#AT(%AfterGlobalIncludes),WHERE(%ETgDisable=0)
INCLUDE('EmailToClass.INC'),ONCE                           #! pulls in EmailNetClass + EmailMsgClass
#ENDAT
#!
#!  The one place that knows BOTH facts. A window generates before the global
#!  module does, so a button cannot ask, at the moment it writes the call,
#!  whether anything will declare the object it is calling. It records what it
#!  needs instead, and this - the last thing in the global module, in the one
#!  extension every emailTo application carries - answers for the whole app.
#AT(%AfterGlobalIncludes),PRIORITY(9000),WHERE(%ETgDisable=0)
  #IF(NOT %ETApiHere)
    #FOR(%ETApiWanted)
      #ERROR('emailTo (' & %ETApiWanted & ') calls the provider-API object, and nothing in this application declares it. Add the ''emailTo - Provider API'' extension: Global Properties, Extensions, Insert.')
    #ENDFOR
  #ENDIF
#!  Start the next application in this AppGen session with no stale names in
#!  hand. %ETApiHere is deliberately NOT cleared: sections further down the
#!  global module still read it, and a stale one only costs the diagnostic.
  #FREE(%ETApiWanted)
#ENDAT
#!
#!--- the global object ---------------------------------------------------------
#!  When a settings table is nominated the object is DERIVED, so LoadAccount and
#!  SaveAccount read and write that table instead of the built-in INI. The
#!  derived instance is declared only in the app that owns it; the other apps in
#!  a suite import it as the base type and still reach the derived methods,
#!  because both are VIRTUAL and dispatch through the object's own VMT.
#AT(%GlobalData),WHERE(%ETgDisable=0)
  #IF(%DefaultExternal = 'None External')
    #IF(%ETgFile)
%ETgObject             CLASS(EmailToClass)                 #<! the mail object, reading %ETgFile
LoadAccount              PROCEDURE(<STRING pName>),BYTE,PROC,DERIVED
SaveAccount              PROCEDURE(),BYTE,PROC,DERIVED
ListAccounts             PROCEDURE(),LONG,PROC,DERIVED
DeleteAccount            PROCEDURE(STRING pName),BYTE,PROC,DERIVED
                       END
    #ELSE
%ETgObject             EmailToClass                        #<! the mail object
    #ENDIF
emailToLanguage        BYTE(%ETgLanguage)                  #<! 1 = English, 2 = Espanol
  #ELSE
%ETgObject             EmailToClass,EXTERNAL,DLL(dll_mode) #<! it lives in the data DLL
emailToLanguage        BYTE,EXTERNAL,DLL(dll_mode)
  #ENDIF
#ENDAT
#!
#AT(%DLLExportList),WHERE(%ETgDisable=0)
  #IF(%DefaultExternal = 'None External' AND %ProgramExtension='DLL' AND %DefaultExport)
  $%ETgObject                                              @?
  $emailToLanguage                                         @?
  #ENDIF
#ENDAT
#!
#!--- start-up: seed the account, then let the store override it ---------------
#AT(%ProgramSetup),WHERE(%ETgDisable=0 AND %DefaultExternal = 'None External'),PRIORITY(8000)
  %ETgObject.Init()
  %ETgObject.Language = emailToLanguage
  #IF(%ETgTrace)
  %ETgObject.Trace = 1
  #ENDIF
  #IF(%ETgProvider <> '0')
  %ETgObject.SetProvider(%ETgProvider)                     ! host, port, security and auth for the provider
  #ENDIF
  %ETgObject.Acc.Transport = %ETgTransport
  #IF(%ETgHost)
  %ETgObject.Acc.Host      = '%ETgHost'
  #ENDIF
  #IF(%ETgPort)
  %ETgObject.Acc.Port      = %ETgPort
  #ENDIF
  %ETgObject.Acc.Security  = %ETgSecurity
  %ETgObject.Acc.AuthMode  = %ETgAuth
  #IF(%ETgUser)
  %ETgObject.Acc.UserName  = '%ETgUser'
  #ENDIF
  #IF(%ETgPassword)
  %ETgObject.Acc.Password  = '%ETgPassword'
  #ENDIF
  #IF(%ETgFromAddr)
  %ETgObject.Acc.FromAddr  = '%ETgFromAddr'
  #ENDIF
  #IF(%ETgFromName)
  %ETgObject.Acc.FromName  = '%ETgFromName'
  #ENDIF
  #IF(%ETgReplyTo)
  %ETgObject.Acc.ReplyTo   = '%ETgReplyTo'
  #ENDIF
  #IF(%ETgClientId)
  %ETgObject.Acc.ClientId  = '%ETgClientId'
  #ENDIF
  #IF(%ETgClientSecret)
  %ETgObject.Acc.ClientSecret = '%ETgClientSecret'
  #ENDIF
  #IF(%ETgTenant)
  %ETgObject.Acc.TenantId  = '%ETgTenant'
  #ENDIF
  #IF(%ETgApiKey)
  %ETgObject.Acc.ApiKey    = '%ETgApiKey'
  #ENDIF
  #IF(%ETgApiDomain)
  %ETgObject.Acc.ApiDomain = '%ETgApiDomain'
  #ENDIF
  #IF(%ETgFile)
  !  The account named on the extension is where a fresh installation starts;
  !  after that, whichever one was last chosen in the setup window wins, so a
  !  program switched to a second provider comes back up on it.
  %ETgObject.LoadAccount(%ETgObject.PreferredAccount('%ETgLoadName'))
  #ELSE
  %ETgObject.LoadAccount(%ETgObject.PreferredAccount())    ! the INI beside the EXE, if there is one
  #ENDIF
#ENDAT
#!
#!--- the generated table binding ----------------------------------------------
#AT(%ProgramProcedures),WHERE(%ETgDisable=0 AND %ETgFile AND %DefaultExternal = 'None External')

!-----------------------------------------------------------------------------
!  %ETgObject.LoadAccount / .SaveAccount - generated by the emailTo template
!  from the Table tab. They replace the class's built-in INI store with
!  %ETgFile, so the account lives in your data with your own backup and
!  security around it.
!
!  The four secrets go through Seal() / Unseal(): DPAPI encrypts them for the
!  current Windows user and base64 makes the result safe for a text column, so
!  a row copied off this machine cannot be read anywhere else.
!-----------------------------------------------------------------------------
%ETgObject.LoadAccount PROCEDURE(<STRING pName>)
  CODE
  IF NOT OMITTED(pName) AND CLIP(pName)
    SELF.Acc.Name = CLIP(pName)
  END
  Access:%ETgFile.Open()
  Access:%ETgFile.UseFile()
  CLEAR(%ETgFile:Record)
  %ETgColName = SELF.Acc.Name
  #IF(%ETgLoadName)
  GET(%ETgFile, %ETgKey)
  #ELSE
  SET(%ETgFile)
  NEXT(%ETgFile)
  #ENDIF
  IF ERRORCODE()
    Access:%ETgFile.Close()
    RETURN 0                                               ! nothing stored yet - keep the defaults
  END
  SELF.Acc.Name         = %ETgColName
  #IF(%ETgColProvider)
  SELF.Acc.Provider     = %ETgColProvider
  #ENDIF
  #IF(%ETgColTransport)
  IF %ETgColTransport THEN SELF.Acc.Transport = %ETgColTransport.
  #ENDIF
  #IF(%ETgColHost)
  IF CLIP(%ETgColHost) THEN SELF.Acc.Host = CLIP(%ETgColHost).
  #ENDIF
  #IF(%ETgColPort)
  IF %ETgColPort THEN SELF.Acc.Port = %ETgColPort.
  #ENDIF
  #IF(%ETgColSecurity)
  SELF.Acc.Security     = %ETgColSecurity
  #ENDIF
  #IF(%ETgColAuth)
  SELF.Acc.AuthMode     = %ETgColAuth
  #ENDIF
  #IF(%ETgColUser)
  SELF.Acc.UserName     = CLIP(%ETgColUser)
  #ENDIF
  #IF(%ETgColPassword)
  SELF.Acc.Password     = SELF.Unseal(%ETgColPassword)
  #ENDIF
  #IF(%ETgColFromAddr)
  IF CLIP(%ETgColFromAddr) THEN SELF.Acc.FromAddr = CLIP(%ETgColFromAddr).
  #ENDIF
  #IF(%ETgColFromName)
  SELF.Acc.FromName     = CLIP(%ETgColFromName)
  #ENDIF
  #IF(%ETgColReplyTo)
  SELF.Acc.ReplyTo      = CLIP(%ETgColReplyTo)
  #ENDIF
  #IF(%ETgColClientId)
  IF CLIP(%ETgColClientId) THEN SELF.Acc.ClientId = CLIP(%ETgColClientId).
  #ENDIF
  #IF(%ETgColSecret)
  SELF.Acc.ClientSecret = SELF.Unseal(%ETgColSecret)
  #ENDIF
  #IF(%ETgColTenant)
  IF CLIP(%ETgColTenant) THEN SELF.Acc.TenantId = CLIP(%ETgColTenant).
  #ENDIF
  #IF(%ETgColRefresh)
  SELF.Acc.RefreshToken = SELF.Unseal(%ETgColRefresh)
  #ENDIF
  #IF(%ETgColApiKey)
  IF CLIP(%ETgColApiKey) THEN SELF.Acc.ApiKey = SELF.Unseal(%ETgColApiKey).
  #ENDIF
  #IF(%ETgColApiDomain)
  IF CLIP(%ETgColApiDomain) THEN SELF.Acc.ApiDomain = CLIP(%ETgColApiDomain).
  #ENDIF
#INSERT(%ETgExtraCols,'load')
  !  An access token is short-lived; the refresh token buys a new one.
  SELF.Acc.AccessToken  = ''
  SELF.Acc.TokenExpDate = 0
  Access:%ETgFile.Close()
  RETURN 1

%ETgObject.SaveAccount PROCEDURE()
ETFound  BYTE
  CODE
  Access:%ETgFile.Open()
  Access:%ETgFile.UseFile()
  CLEAR(%ETgFile:Record)
  %ETgColName = SELF.Acc.Name
  GET(%ETgFile, %ETgKey)
  ETFound = CHOOSE(ERRORCODE() = 0, 1, 0)
  IF NOT ETFound
  #IF(%ETgCreateRow)
    CLEAR(%ETgFile:Record)
    %ETgColName = SELF.Acc.Name
  #ELSE
    Access:%ETgFile.Close()
    RETURN 0                                               ! not allowed to create the row
  #ENDIF
  END
  #IF(%ETgColProvider)
  %ETgColProvider     = SELF.Acc.Provider
  #ENDIF
  #IF(%ETgColTransport)
  %ETgColTransport    = SELF.Acc.Transport
  #ENDIF
  #IF(%ETgColHost)
  %ETgColHost         = CLIP(SELF.Acc.Host)
  #ENDIF
  #IF(%ETgColPort)
  %ETgColPort         = SELF.Acc.Port
  #ENDIF
  #IF(%ETgColSecurity)
  %ETgColSecurity     = SELF.Acc.Security
  #ENDIF
  #IF(%ETgColAuth)
  %ETgColAuth         = SELF.Acc.AuthMode
  #ENDIF
  #IF(%ETgColUser)
  %ETgColUser         = CLIP(SELF.Acc.UserName)
  #ENDIF
  #IF(%ETgColPassword)
  %ETgColPassword     = SELF.Seal(SELF.Acc.Password)
  #ENDIF
  #IF(%ETgColFromAddr)
  %ETgColFromAddr     = CLIP(SELF.Acc.FromAddr)
  #ENDIF
  #IF(%ETgColFromName)
  %ETgColFromName     = CLIP(SELF.Acc.FromName)
  #ENDIF
  #IF(%ETgColReplyTo)
  %ETgColReplyTo      = CLIP(SELF.Acc.ReplyTo)
  #ENDIF
  #IF(%ETgColClientId)
  %ETgColClientId     = CLIP(SELF.Acc.ClientId)
  #ENDIF
  #IF(%ETgColSecret)
  %ETgColSecret       = SELF.Seal(SELF.Acc.ClientSecret)
  #ENDIF
  #IF(%ETgColTenant)
  %ETgColTenant       = CLIP(SELF.Acc.TenantId)
  #ENDIF
  #IF(%ETgColRefresh)
  %ETgColRefresh      = SELF.Seal(SELF.Acc.RefreshToken)
  #ENDIF
  #IF(%ETgColApiKey)
  %ETgColApiKey       = SELF.Seal(SELF.Acc.ApiKey)
  #ENDIF
  #IF(%ETgColApiDomain)
  %ETgColApiDomain    = CLIP(SELF.Acc.ApiDomain)
  #ENDIF
#INSERT(%ETgExtraCols,'save')
  IF ETFound
    PUT(%ETgFile)
  ELSE
    ADD(%ETgFile)
  END
  IF ERRORCODE()
    Access:%ETgFile.Close()
    RETURN 0
  END
  Access:%ETgFile.Close()
  RETURN 1

!-----------------------------------------------------------------------------
!  %ETgObject.ListAccounts / .DeleteAccount - generated by the emailTo template
!
!  The base class keeps its accounts in INI sections and can enumerate them
!  from an index it maintains. This store is a table, and only code that knows
!  the table can walk it - so both are replaced here. Without this the account
!  picker would come up empty in exactly the applications that have a table.
!-----------------------------------------------------------------------------
%ETgObject.ListAccounts PROCEDURE()
  CODE
  FREE(SELF.AccountQ)
  Access:%ETgFile.Open()
  Access:%ETgFile.UseFile()
  SET(%ETgKey)
  LOOP
    NEXT(%ETgFile)
    IF ERRORCODE() THEN BREAK.
    CLEAR(SELF.AccountQ)
    SELF.AccountQ.Name     = %ETgColName
  #IF(%ETgColProvider)
    SELF.AccountQ.Provider = %ETgColProvider
  #ENDIF
    SELF.AccountQ.ProviderText = SELF.ProviderName(SELF.AccountQ.Provider)
  #IF(%ETgColFromAddr)
    SELF.AccountQ.FromAddr = %ETgColFromAddr
  #ENDIF
    ADD(SELF.AccountQ)
  END
  Access:%ETgFile.Close()
  RETURN RECORDS(SELF.AccountQ)

%ETgObject.DeleteAccount PROCEDURE(STRING pName)
  CODE
  IF NOT CLIP(pName) THEN RETURN 0.
  Access:%ETgFile.Open()
  Access:%ETgFile.UseFile()
  CLEAR(%ETgFile:Record)
  %ETgColName = CLIP(pName)
  GET(%ETgFile, %ETgKey)
  IF ERRORCODE()
    Access:%ETgFile.Close()
    RETURN 0
  END
  Relate:%ETgFile.Delete(0)
  Access:%ETgFile.Close()
  RETURN 1
#ENDAT
#!
#!-----------------------------------------------------------------------------
#!  MULTI-DLL. The three class files carry the tag !ABCIncludeFile(EMAILTO) on
#!  line 1, so the IDE's class registry files them under category EMAILTO.
#!  Registering that category here hands the whole job to the shipped ABC
#!  machinery:
#!
#!    ABPROGRM.TPW  #CALL(%DefineCategoryPragmas) writes the project defines
#!                  _emailToLinkMode_ / _emailToDllMode_ that the classes'
#!                  LINK() and DLL() attributes read.
#!    ABBLDEXP.TPW  while building the .EXP of a DLL, walks the registry and
#!                  emits VMT$ / TYPE$ / every non-private method of every
#!                  link-mode category class, name-mangled by LINKNAME().
#!
#!  That is why nothing here lists a mangled symbol: add a method to a class
#!  and the export list follows on the next generate.
#!
#!  Corpus precedent for a third-party class registering its own category:
#!  svgraph.tpl:38, qcenter.tpw:98, abmail.tpl:310.
#!-----------------------------------------------------------------------------
#AT(%BeforeGenerateApplication),WHERE(%ETgDisable=0)
  #CALL(%AddCategory(ABC),'EMAILTO')
  #CALL(%SetCategoryLocationFromPrompts(ABC),'EMAILTO','emailTo','')
#ENDAT
#!
#!#############################################################################
#!  APPLICATION EXTENSION - emailToProviderApi
#!#############################################################################
#!  The management half: who is blocked and why, statistics, activity,
#!  contacts, lists, campaigns, templates, senders, domains, webhooks.
#!
#!  A SEPARATE extension, not a tab on emailTo - Global, and the reason is
#!  upgrades. An application stores the set of prompts it was built with, and
#!  AppGen does not backfill one added later: generation stops with "Unknown
#!  Variable" on a symbol the developer never typed. An application that does
#!  not add THIS extension never names these symbols, so an older app keeps
#!  generating exactly as it did. v1.03 learned that the hard way.
#!
#!  It needs emailTo - Global: the account, and the HTTPS layer, both belong
#!  to the mail object this one borrows.
#!#############################################################################
#EXTENSION(emailToProviderApi,'emailTo - Provider API (blocked, statistics, campaigns)'),APPLICATION,HLP('~emailTo.htm')
#SHEET
  #TAB('&General')
    #BOXED('Asking the provider questions')
      #DISPLAY('emailTo v1.12 - built 2026-08-24 22:45 Add this ONCE per  [480]')
      #DISPLAY('application, alongside emailTo - Global.')
      #DISPLAY('')
      #DISPLAY('The same key that sends the mail can also answer for the')
      #DISPLAY('account: who is blocked and why, statistics, contacts,')
      #DISPLAY('campaigns, templates, senders, domains and webhooks.')
      #DISPLAY('')
      #DISPLAY('Nine providers answer: SendGrid, Brevo, Mailgun, Postmark,')
      #DISPLAY('Mailjet, Resend, SparkPost, MailerSend and Amazon SES. Each')
      #DISPLAY('offers a different subset, and Supports() says which - the')
      #DISPLAY('window greys out whatever a provider genuinely cannot do.')
      #PROMPT('&Disable this template',CHECK),%ETqDisable,DEFAULT(0),AT(10)
      #PROMPT('&Object name:',@s64),%ETqObject,REQ,DEFAULT('MailApi')
      #PROMPT('&Mail object name:',@s64),%ETqMailObject,REQ,DEFAULT('Mailer')
      #DISPLAY('The object emailTo - Global declared. This one borrows its')
      #DISPLAY('account and its HTTPS layer, so there is no second copy of a')
      #DISPLAY('credential anywhere in the program.')
    #ENDBOXED
    #BOXED('How much to ask for')
      #PROMPT('&Rows per request:',@n5),%ETqPageSize,DEFAULT(100)
      #DISPLAY('How many rows to ask for at a time. The class keeps asking')
      #DISPLAY('until the provider runs out, so this is only the page size.')
      #PROMPT('&Stop after this many rows:',@n7),%ETqMaxRows,DEFAULT(5000)
      #DISPLAY('A guard against a block list with a hundred thousand rows in')
      #DISPLAY('it. Zero means no limit.')
    #ENDBOXED
  #ENDTAB
  #TAB('&Endpoint')
    #BOXED('The second credential, the region, and the base address')
      #DISPLAY('All three are optional, and all three can come from your')
      #DISPLAY('settings table instead - name a column ApiKey2, ApiRegion or')
      #DISPLAY('ApiBase and emailTo - Global fills it, by name.')
      #PROMPT('Second &key:',@s255),%ETqKey2,DEFAULT('')
      #DISPLAY('Postmark: its senders and domains endpoints want the')
      #DISPLAY('ACCOUNT token, not the server token. Amazon SES: the AWS')
      #DISPLAY('ACCESS KEY ID goes here and the secret in the API key, which')
      #DISPLAY('leaves User name and Password free for the quite separate')
      #DISPLAY('SMTP credentials SES also issues. Blank for everybody else.')
      #PROMPT('Re&gion:',@s32),%ETqRegion,DEFAULT('')
      #DISPLAY('Put eu here for a Mailgun or SparkPost account created in')
      #DISPLAY('Europe. Those are separate services with their own data - at')
      #DISPLAY('the default endpoint a European account looks empty, not')
      #DISPLAY('wrong. For Amazon SES this is the AWS REGION and it is part')
      #DISPLAY('of the signature: eu-west-1, us-east-2, and so on. Blank means')
      #DISPLAY('us-east-1 for SES, the default endpoint for the rest.')
      #PROMPT('&Base address:',@s128),%ETqBase,DEFAULT('')
      #DISPLAY('Replaces the host - and the scheme, if you give one. For a')
      #DISPLAY('private relay, or for pointing a test build at a stand-in. Blank is')
      #DISPLAY('what you want in production.')
    #ENDBOXED
  #ENDTAB
#ENDSHEET
#!
#!  Advertise the object to the templates that call it. A control template
#!  on a window cannot see this extension's prompts, and without this it
#!  cheerfully writes MailApi.Supports(...) into an application that never
#!  declared MailApi - eight compiler errors on generated code the developer
#!  never typed. Set here and never cleared: a stale TRUE only costs the
#!  diagnostic, while a stale FALSE would stop a working application dead.
#!
#AT(%AfterGlobalIncludes),PRIORITY(100),WHERE(%ETqDisable=0)
#SET(%ETApiHere,%ETqObject)                                #! tell the other templates it exists
INCLUDE('EmailApiClass.INC'),ONCE                          #! pulls in all four of the others
#ENDAT
#!
#AT(%GlobalData),WHERE(%ETqDisable=0)
  #IF(%DefaultExternal = 'None External')
%ETqObject             EmailApiClass                       #<! the management object
  #ELSE
%ETqObject             EmailApiClass,EXTERNAL,DLL(dll_mode) #<! it lives in the data DLL
  #ENDIF
#ENDAT
#!
#AT(%DLLExportList),WHERE(%ETqDisable=0)
  #IF(%DefaultExternal = 'None External' AND %ProgramExtension='DLL' AND %DefaultExport)
  $%ETqObject                                              @?
  #ENDIF
#ENDAT
#!
#!  After emailTo - Global has set the account up (it runs at 8000), so that
#!  whatever the settings table holds is already in place.
#AT(%ProgramSetup),WHERE(%ETqDisable=0 AND %DefaultExternal = 'None External'),PRIORITY(8500)
  #IF(%ETqKey2)
  %ETqMailObject.Acc.ApiKey2   = '%ETqKey2'
  #ENDIF
  #IF(%ETqRegion)
  %ETqMailObject.Acc.ApiRegion = '%ETqRegion'
  #ENDIF
  #IF(%ETqBase)
  %ETqMailObject.Acc.ApiBase   = '%ETqBase'
  #ENDIF
  !  Borrows the account and the HTTPS layer, so there is no second copy of
  !  the key anywhere.
  %ETqObject.Init(%ETqMailObject)
  #IF(%ETqPageSize)
  %ETqObject.PageSize = %ETqPageSize
  #ENDIF
  %ETqObject.MaxRows  = %ETqMaxRows
#ENDAT
#!#############################################################################
#!  APPLICATION EXTENSION - emailToSync
#!#############################################################################
#!  Bringing the provider's answers down into tables of your own.
#!
#!  This is a SEPARATE extension, not another tab on emailTo - Global, and the
#!  reason is upgrades. An application stores the set of prompts it was built
#!  with; a prompt added to an extension it already carries is simply not
#!  there, and generation stops with "Unknown Variable" on a symbol the
#!  developer never typed. An application that does not add THIS extension
#!  never names these symbols, so an existing app keeps generating exactly as
#!  it did before.
#!
#!  It needs emailTo - Global, with its Provider API tab switched on: the
#!  account and the answers both come from that object.
#!#############################################################################
#EXTENSION(emailToSync,'emailTo - Sync provider data into your tables (add once per application)'),APPLICATION,HLP('~emailTo.htm')
#SHEET
  #TAB('&General')
    #BOXED('emailTo - Sync')
      #DISPLAY('emailTo v1.12 - built 2026-08-24 22:45 Add this ONCE per  [480]')
      #DISPLAY('application, alongside emailTo - Global.')
      #DISPLAY('')
      #DISPLAY('It needs the Global extension''s "Provider API" tab switched on')
      #DISPLAY('- that is where the object it reads through is declared.')
      #PROMPT('&Disable this template',CHECK),%ETyDisable,DEFAULT(0),AT(10)
      #PROMPT('&Sync object name:',@s64),%ETyObject,REQ,DEFAULT('MailSync')
      #PROMPT('&API object name:',@s64),%ETyApiObject,REQ,DEFAULT('MailApi')
      #DISPLAY('The object emailTo - Global declared on its Provider API tab.')
    #ENDBOXED
  #ENDTAB
  #TAB('S&ync tables')
    #BOXED('Keeping what the provider knows')
      #DISPLAY('The management window asks the provider live and keeps')
      #DISPLAY('nothing. Nominate tables here and the same answers are also')
      #DISPLAY('written into your own data - so you can put a browse on the')
      #DISPLAY('blocked list, join it to your customers, or report on last')
      #DISPLAY('month''s opens without going near the network.')
      #DISPLAY('')
      #DISPLAY('emailToTables.dctx (shipped beside this template) is a ready-')
      #DISPLAY('made dictionary holding all six, plus the account table:')
      #DISPLAY('    Dictionary Editor > File > Import, and pick the DCTX/XML')
      #DISPLAY('    entry - NOT the TXD one, which is Report Writer''s format')
      #DISPLAY('    and is refused with "This TXD file is a Report Writer')
      #DISPLAY('    only format".')
      #PROMPT('&Keep the data in tables',CHECK),%ETyOn,DEFAULT(0),AT(10)
      #ENABLE(%ETyOn)
        #DISPLAY('')
        #DISPLAY('Columns are matched BY NAME against the shipped')
        #DISPLAY('dictionary, so a table imported from it needs nothing else. A')
        #DISPLAY('column with any other name is simply left alone.')
        #PROMPT('Stamp &provider and date',CHECK),%ETyStamp,DEFAULT(1),AT(10)
        #DISPLAY('Fills Provider and SyncedOn, if the table has them. Leave this')
        #DISPLAY('on unless one table serves exactly one account.')
      #ENDENABLE
    #ENDBOXED
  #ENDTAB
  #TAB('Sync tables &2')
    #ENABLE(%ETyOn)
      #BOXED('Blocked addresses - who the provider refuses, and why')
        #PROMPT('&Table:',FILE),%ETyBlockedFile
        #ENABLE(%ETyBlockedFile)
          #PROMPT('&Key:',KEY(%ETyBlockedFile)),%ETyBlockedKey,REQ
          #DISPLAY('The key that identifies one row. In the shipped dictionary that')
          #DISPLAY('is MailBlocked.ByAddress (provider + address + kind).')
        #ENDENABLE
        #DISPLAY('Columns: Address, Kind, KindName, Reason, Code,')
        #DISPLAY('BlockedOn, BlockedAt, Ref, Sender.')
      #ENDBOXED
      #BOXED('Statistics - one row per day')
        #PROMPT('T&able:',FILE),%ETyStatFile
        #ENABLE(%ETyStatFile)
          #PROMPT('K&ey:',KEY(%ETyStatFile)),%ETyStatKey,REQ
          #PROMPT('How many &days back:',@n5),%ETyStatDays,DEFAULT(30)
        #ENDENABLE
        #DISPLAY('Columns: StatDate, Requests, Delivered, Opens, UniqueOpens,')
        #DISPLAY('Clicks, UniqueClicks, HardBounces, SoftBounces, Blocks,')
        #DISPLAY('SpamReports, Unsubscribed, Invalid.')
      #ENDBOXED
    #ENDENABLE
  #ENDTAB
  #TAB('Sync tables &3')
    #ENABLE(%ETyOn)
      #BOXED('Activity - what happened to each message')
        #PROMPT('&Table:',FILE),%ETyEventFile
        #ENABLE(%ETyEventFile)
          #PROMPT('&Key:',KEY(%ETyEventFile)),%ETyEventKey,REQ
          #PROMPT('How many &days back:',@n5),%ETyEventDays,DEFAULT(7)
        #ENDENABLE
        #DISPLAY('Columns: EventDate, EventTime, Address, EventName,')
        #DISPLAY('Reason, Subject, MessageId, Link. This is much the biggest')
        #DISPLAY('table - a busy sender makes thousands of rows a day.')
      #ENDBOXED
      #BOXED('Contacts')
        #PROMPT('Ta&ble:',FILE),%ETyContactFile
        #ENABLE(%ETyContactFile)
          #PROMPT('Ke&y:',KEY(%ETyContactFile)),%ETyContactKey,REQ
        #ENDENABLE
        #DISPLAY('Columns: ContactId, Address, Name, Blocked, Unsubscribed,')
        #DISPLAY('CreatedOn, ListIds.')
      #ENDBOXED
      #BOXED('Lists')
        #PROMPT('Tab&le:',FILE),%ETyListFile
        #ENABLE(%ETyListFile)
          #PROMPT('Ky:',KEY(%ETyListFile)),%ETyListKey,REQ
        #ENDENABLE
        #DISPLAY('Columns: ListId, Name, Members, Blocked, FolderId.')
      #ENDBOXED
      #BOXED('Campaigns')
        #PROMPT('Table:',FILE),%ETyCampFile
        #ENABLE(%ETyCampFile)
          #PROMPT('Key:',KEY(%ETyCampFile)),%ETyCampKey,REQ
        #ENDENABLE
        #DISPLAY('Columns: CampaignId, Name, Subject, Status, SendDate,')
        #DISPLAY('SendTime, Recipients, Opens, Clicks.')
      #ENDBOXED
    #ENDENABLE
  #ENDTAB
#ENDSHEET
#!
#AT(%CustomGlobalDeclarations),WHERE(%ETyDisable=0)
INCLUDE('EmailApiClass.INC'),ONCE
  #INSERT(%ETyRelate,%ETyBlockedFile)
  #INSERT(%ETyRelate,%ETyStatFile)
  #INSERT(%ETyRelate,%ETyEventFile)
  #INSERT(%ETyRelate,%ETyContactFile)
  #INSERT(%ETyRelate,%ETyListFile)
  #INSERT(%ETyRelate,%ETyCampFile)
#ENDAT
#!
#AT(%BeforeFileDeclarations),WHERE(%ETyDisable=0)
  #INSERT(%ETyUseFile,%ETyBlockedFile)
  #INSERT(%ETyUseFile,%ETyStatFile)
  #INSERT(%ETyUseFile,%ETyEventFile)
  #INSERT(%ETyUseFile,%ETyContactFile)
  #INSERT(%ETyUseFile,%ETyListFile)
  #INSERT(%ETyUseFile,%ETyCampFile)
#ENDAT
#!
#!  A small object of its own rather than a method on the API object: that way
#!  emailTo - Global needs no new prompt, and an application without this
#!  extension is untouched.
#AT(%GlobalData),WHERE(%ETyDisable=0)
  #IF(%DefaultExternal = 'None External')
%ETyObject             CLASS                               #<! the table sync
Run                      PROCEDURE(BYTE pSilent=0),LONG,PROC #<! answers the rows written
                       END
  #ELSE
%ETyObject             CLASS,EXTERNAL,DLL(dll_mode)        #<! it lives in the data DLL
Run                      PROCEDURE(BYTE pSilent=0),LONG,PROC
                       END
  #ENDIF
#ENDAT
#!
#AT(%DLLExportList),WHERE(%ETyDisable=0)
  #IF(%DefaultExternal = 'None External' AND %ProgramExtension='DLL' AND %DefaultExport)
  $%ETyObject                                              @?
  #ENDIF
#ENDAT
#!--- the generated table sync -------------------------------------------------
#AT(%ProgramProcedures),WHERE(%ETyDisable=0 AND %DefaultExternal = 'None External')
  #ADD(%ETApiWanted,'the Sync extension')             #! checked once the global module generates

!-----------------------------------------------------------------------------
!  %ETyObject.Run - generated by the emailTo - Sync extension from the
!  tables nominated on its tabs.
!
!  It asks the provider the same questions the Manage window asks, and writes
!  the answers into the tables you nominated. Each row is looked up by its key
!  first, so running it twice changes nothing: a row that is already there is
!  updated, a new one is added. That is what makes it safe on a timer.
!
!  Columns are matched BY NAME against the shipped dictionary
!  (emailToTables.dctx). A column named something else is left alone, so extra
!  columns of your own - a flag, a note, a link to your customer row - survive
!  every sync.
!-----------------------------------------------------------------------------
%ETyObject.Run PROCEDURE(BYTE pSilent)
ETyRows   LONG                                             ! rows written, all tables
ETyAdded  LONG                                             ! how many of those were new
ETyN      LONG
ETyi      LONG
ETyBad    BYTE
  CODE
  ETyRows  = 0
  ETyAdded = 0
  ETyBad   = 0
  #IF(%ETyBlockedFile)
  DO ETySyncBlocked
  #ENDIF
  #IF(%ETyStatFile)
  DO ETySyncStats
  #ENDIF
  #IF(%ETyEventFile)
  DO ETySyncEvents
  #ENDIF
  #IF(%ETyContactFile)
  DO ETySyncContacts
  #ENDIF
  #IF(%ETyListFile)
  DO ETySyncLists
  #ENDIF
  #IF(%ETyCampFile)
  DO ETySyncCampaigns
  #ENDIF
  IF NOT pSilent
    IF ETyBad AND NOT ETyRows
      %ETyApiObject.ShowError()
    ELSE
      MESSAGE(ETyRows & ' rows brought down, ' & ETyAdded & ' of them new.' & |
              CHOOSE(ETyBad = 0, '', '<13,10><13,10>Something was refused: ' & |
                     CLIP(%ETyApiObject.LastErrorText)), |
              %ETyApiObject.Txt(ETATxt:Manage), CHOOSE(ETyBad = 0, ICON:Asterisk, ICON:Exclamation))
    END
  END
  RETURN ETyRows
#!
#INSERT(%ETyOneTable,'Blocked',%ETyBlockedFile,%ETyBlockedKey,'SuppQ')
#INSERT(%ETyOneTable,'Stats',%ETyStatFile,%ETyStatKey,'StatQ')
#INSERT(%ETyOneTable,'Events',%ETyEventFile,%ETyEventKey,'EventQ')
#INSERT(%ETyOneTable,'Contacts',%ETyContactFile,%ETyContactKey,'ContactQ')
#INSERT(%ETyOneTable,'Lists',%ETyListFile,%ETyListKey,'ListQ')
#INSERT(%ETyOneTable,'Campaigns',%ETyCampFile,%ETyCampKey,'CampaignQ')
#ENDAT
#!
#!-----------------------------------------------------------------------------
#!  The three account columns v1.03 added, matched by NAME instead of by three
#!  more prompts on a tab that is already full. Name a column ApiKey2,
#!  ApiRegion or ApiBase and it is filled; call it something else and nothing
#!  happens. ApiKey2 is a credential, so it goes through Seal / Unseal like
#!  the others.
#!-----------------------------------------------------------------------------
#GROUP(%ETgExtraCols,%pWay)
#IF(NOT %ETgFile)
  #RETURN
#ENDIF
#FOR(%File),WHERE(%File = %ETgFile)
  #FOR(%Field),WHERE(%FieldID <> '')
    #CASE(UPPER(%FieldID))
    #OF('APIKEY2')
      #IF(%pWay = 'load')
  IF CLIP(%Field) THEN SELF.Acc.ApiKey2 = SELF.Unseal(%Field).
      #ELSE
  %Field = SELF.Seal(SELF.Acc.ApiKey2)
      #ENDIF
    #OF('APIREGION')
      #IF(%pWay = 'load')
  IF CLIP(%Field) THEN SELF.Acc.ApiRegion = CLIP(%Field).
      #ELSE
  %Field = CLIP(SELF.Acc.ApiRegion)
      #ENDIF
    #OF('APIBASE')
      #IF(%pWay = 'load')
  IF CLIP(%Field) THEN SELF.Acc.ApiBase = CLIP(%Field).
      #ELSE
  %Field = CLIP(SELF.Acc.ApiBase)
      #ENDIF
    #ENDCASE
  #ENDFOR
#ENDFOR
#!
#GROUP(%ETyRelate,%pFile)
#IF(NOT %pFile)
  #RETURN
#ENDIF
#ADD(%UsedFile, %pFile)
#INSERT(%AddRelatedFiles(ABC),%UsedFile,%pFile)
#!
#GROUP(%ETyUseFile,%pFile)
#IF(NOT %pFile)
  #RETURN
#ENDIF
#ADD(%UsedFile, %pFile)
#FIX(%File, %pFile)
#ASSERT(%File = %pFile, 'emailTo: cannot fix on the table %pFile - is it still in the dictionary?')
#SET(%CacheFileUsed, %True)
#!
#!-----------------------------------------------------------------------------
#!  One dataset: fetch it, then walk the queue writing each row.  The mapping
#!  routine is emitted once and called from all three places that need it -
#!  a failed GET leaves the record buffer undefined, so the fields have to be
#!  laid down again after it whichever way the lookup went.
#!-----------------------------------------------------------------------------
#GROUP(%ETyOneTable,%pWhat,%pFile,%pKey,%pQueue)
#IF(NOT %pFile)
  #RETURN
#ENDIF

ETySync%pWhat ROUTINE
  #CASE(%pWhat)
  #OF('Blocked')
  ETyN = %ETyApiObject.GetSuppressions(ETSup:All)
  #OF('Stats')
  ETyN = %ETyApiObject.GetStats(TODAY() - %ETyStatDays, TODAY())
  #OF('Events')
  ETyN = %ETyApiObject.GetEvents(TODAY() - %ETyEventDays, TODAY())
  #OF('Contacts')
  ETyN = %ETyApiObject.GetContacts()
  #OF('Lists')
  ETyN = %ETyApiObject.GetLists()
  #OF('Campaigns')
  ETyN = %ETyApiObject.GetCampaigns()
  #ENDCASE
  IF ETyN < 0
    ETyBad = 1                                             ! the reason is in LastErrorText
    EXIT
  END
  Access:%pFile.Open()
  Access:%pFile.UseFile()
  LOOP ETyi = 1 TO RECORDS(%ETyApiObject.%pQueue)
    GET(%ETyApiObject.%pQueue, ETyi)
    CLEAR(%pFile:Record)
    DO ETyMap%pWhat
    GET(%pFile, %pKey)
    IF ERRORCODE()
      CLEAR(%pFile:Record)
      DO ETyMap%pWhat
      ADD(%pFile)
      IF NOT ERRORCODE()
        ETyAdded += 1
        ETyRows  += 1
      END
    ELSE
      DO ETyMap%pWhat
      PUT(%pFile)
      IF NOT ERRORCODE() THEN ETyRows += 1.
    END
  END
  Access:%pFile.Close()

ETyMap%pWhat ROUTINE
#FOR(%File),WHERE(%File = %pFile)
  #FOR(%Field),WHERE(%FieldID <> '')
    #INSERT(%ETyOneColumn,%pWhat,%pQueue)
  #ENDFOR
#ENDFOR
#!
#!-----------------------------------------------------------------------------
#!  One column.  Matched by NAME, so the shipped dictionary needs no mapping
#!  and anything else you keep in the table is untouched.
#!-----------------------------------------------------------------------------
#GROUP(%ETyOneColumn,%pWhat,%pQueue)
#DECLARE(%ETyCol)
#SET(%ETyCol,UPPER(%FieldID))
#IF(%ETyStamp AND %ETyCol = 'PROVIDER')
  %Field = %ETyApiObject.Mailer.Acc.Provider
  #RETURN
#ENDIF
#IF(%ETyStamp AND %ETyCol = 'SYNCEDON')
  %Field = TODAY()
  #RETURN
#ENDIF
#CASE(%pWhat)
#OF('Blocked')
  #CASE(%ETyCol)
  #OF('ADDRESS')
  %Field = %ETyApiObject.%pQueue.Address
  #OF('KIND')
  %Field = %ETyApiObject.%pQueue.Kind
  #OF('KINDNAME')
  %Field = %ETyApiObject.%pQueue.KindName
  #OF('REASON')
  %Field = %ETyApiObject.%pQueue.Reason
  #OF('CODE')
  %Field = %ETyApiObject.%pQueue.Code
  #OF('BLOCKEDON')
  %Field = %ETyApiObject.%pQueue.WhenDate
  #OF('BLOCKEDAT')
  %Field = %ETyApiObject.%pQueue.WhenTime
  #OF('REF')
  %Field = %ETyApiObject.%pQueue.Id
  #OF('SENDER')
  %Field = %ETyApiObject.%pQueue.Sender
  #ENDCASE
#OF('Stats')
  #CASE(%ETyCol)
  #OF('STATDATE')
  %Field = %ETyApiObject.%pQueue.WhenDate
  #OF('REQUESTS')
  %Field = %ETyApiObject.%pQueue.Requests
  #OF('DELIVERED')
  %Field = %ETyApiObject.%pQueue.Delivered
  #OF('OPENS')
  %Field = %ETyApiObject.%pQueue.Opens
  #OF('UNIQUEOPENS')
  %Field = %ETyApiObject.%pQueue.UniqueOpens
  #OF('CLICKS')
  %Field = %ETyApiObject.%pQueue.Clicks
  #OF('UNIQUECLICKS')
  %Field = %ETyApiObject.%pQueue.UniqueClicks
  #OF('HARDBOUNCES')
  %Field = %ETyApiObject.%pQueue.HardBounces
  #OF('SOFTBOUNCES')
  %Field = %ETyApiObject.%pQueue.SoftBounces
  #OF('BLOCKS')
  %Field = %ETyApiObject.%pQueue.Blocks
  #OF('SPAMREPORTS')
  %Field = %ETyApiObject.%pQueue.SpamReports
  #OF('UNSUBSCRIBED')
  %Field = %ETyApiObject.%pQueue.Unsubscribed
  #OF('INVALID')
  %Field = %ETyApiObject.%pQueue.Invalid
  #ENDCASE
#OF('Events')
  #CASE(%ETyCol)
  #OF('EVENTDATE')
  %Field = %ETyApiObject.%pQueue.WhenDate
  #OF('EVENTTIME')
  %Field = %ETyApiObject.%pQueue.WhenTime
  #OF('ADDRESS')
  %Field = %ETyApiObject.%pQueue.Address
  #OF('EVENTNAME')
  %Field = %ETyApiObject.%pQueue.EventName
  #OF('REASON')
  %Field = %ETyApiObject.%pQueue.Reason
  #OF('SUBJECT')
  %Field = %ETyApiObject.%pQueue.Subject
  #OF('MESSAGEID')
  %Field = %ETyApiObject.%pQueue.MessageId
  #OF('LINK')
  %Field = %ETyApiObject.%pQueue.Link
  #ENDCASE
#OF('Contacts')
  #CASE(%ETyCol)
  #OF('CONTACTID')
  %Field = %ETyApiObject.%pQueue.Id
  #OF('ADDRESS')
  %Field = %ETyApiObject.%pQueue.Address
  #OF('NAME')
  %Field = %ETyApiObject.%pQueue.Name
  #OF('BLOCKED')
  %Field = %ETyApiObject.%pQueue.Blocked
  #OF('UNSUBSCRIBED')
  %Field = %ETyApiObject.%pQueue.Unsubscribed
  #OF('CREATEDON')
  %Field = %ETyApiObject.%pQueue.WhenDate
  #OF('LISTIDS')
  %Field = %ETyApiObject.%pQueue.ListIds
  #ENDCASE
#OF('Lists')
  #CASE(%ETyCol)
  #OF('LISTID')
  %Field = %ETyApiObject.%pQueue.Id
  #OF('NAME')
  %Field = %ETyApiObject.%pQueue.Name
  #OF('MEMBERS')
  %Field = %ETyApiObject.%pQueue.Members
  #OF('BLOCKED')
  %Field = %ETyApiObject.%pQueue.Blocked
  #OF('FOLDERID')
  %Field = %ETyApiObject.%pQueue.FolderId
  #ENDCASE
#OF('Campaigns')
  #CASE(%ETyCol)
  #OF('CAMPAIGNID')
  %Field = %ETyApiObject.%pQueue.Id
  #OF('NAME')
  %Field = %ETyApiObject.%pQueue.Name
  #OF('SUBJECT')
  %Field = %ETyApiObject.%pQueue.Subject
  #OF('STATUS')
  %Field = %ETyApiObject.%pQueue.Status
  #OF('SENDDATE')
  %Field = %ETyApiObject.%pQueue.WhenDate
  #OF('SENDTIME')
  %Field = %ETyApiObject.%pQueue.WhenTime
  #OF('RECIPIENTS')
  %Field = %ETyApiObject.%pQueue.Recipients
  #OF('OPENS')
  %Field = %ETyApiObject.%pQueue.Opens
  #OF('CLICKS')
  %Field = %ETyApiObject.%pQueue.Clicks
  #ENDCASE
#ENDCASE
#!#############################################################################
#!  CONTROL TEMPLATE - emailToButton
#!#############################################################################
#!  Drag onto any window and it drops a wired "E-mail..." button. What the
#!  button does is a prompt: open the compose window, or send a message you
#!  described here without asking. Both routes go through the same global
#!  object, so the account, the log and the error text are shared.
#!#############################################################################
#CONTROL(emailToButton,'emailTo - E-mail button (drag onto a window)'),WINDOW,MULTI,DESCRIPTION('E-mail button - ' & CHOOSE(%ETbAction='3','opens ACCOUNT SETUP',CHOOSE(%ETbAction='2','SENDS straight away','opens the COMPOSE window'))),HLP('~emailTo.htm')
  CONTROLS
    BUTTON('&E-mail...'),AT(,,54,14),USE(?EmailBtn),TIP('Send this by e-mail')
  END
#SHEET
  #TAB('&General')
    #BOXED('Button')
      #DISPLAY('emailTo v1.12 - built 2026-08-24 22:45  [480]')
      #PROMPT('&Disable this button',CHECK),%ETbDisable,DEFAULT(0),AT(10)
      #PROMPT('Mail &object name:',@s64),%ETbObject,REQ,DEFAULT('Mailer')
      #DISPLAY('The object the emailToGlobal extension declared. Add that')
      #DISPLAY('extension to this application if you have not already.')
    #ENDBOXED
    #BOXED('What this button does')
      #PROMPT('&Action:',DROP('Open the compose window[1]|Send straight away, no window[2]|Open the account setup window[3]')),%ETbAction,DEFAULT('1')
      #DISPLAY('')
      #DISPLAY('Compose window - the Message tab only PRE-FILLS what')
      #DISPLAY('opens. Send straight away - the Message tab IS the message.')
      #DISPLAY('Account setup - the Message tab does not apply (greyed).')
      #DISPLAY('')
      #DISPLAY('All three start life labelled "E-mail..." - rename the button in')
      #DISPLAY('the window designer so two of them tell each other apart.')
    #ENDBOXED
    #ENABLE(%ETbAction='2')
      #BOXED('After it runs (send straight away only)')
        #PROMPT('Tell the user it &worked',CHECK),%ETbSayOk,DEFAULT(1),AT(10)
        #PROMPT('Show the &error if it failed',CHECK),%ETbSayError,DEFAULT(1),AT(10)
      #ENDBOXED
    #ENDENABLE
  #ENDTAB
  #TAB('&Account')
    #BOXED('The sender address and password are NOT set here')
      #DISPLAY('This button only says WHAT to do. Who the mail comes')
      #DISPLAY('FROM - the server, the sender address, the user name, the')
      #DISPLAY('password, the OAuth2 client - belongs to the whole')
      #DISPLAY('application, not to one button, so it is set in ONE place:')
      #DISPLAY('')
      #DISPLAY('   Application - Global Properties - Extensions')
      #DISPLAY('      - "emailTo - Global" - Account tab')
      #DISPLAY('')
      #DISPLAY('Add that extension once per application. Every button and')
      #DISPLAY('every embed in the app then shares that one account.')
    #ENDBOXED
    #BOXED('Letting the end user change it')
      #DISPLAY('Give them a button with Action = "Open the account setup')
      #DISPLAY('window". What they save there overrides the Account tab -')
      #DISPLAY('into your settings table if you nominated one on the global')
      #DISPLAY('extension''s Table tab, otherwise into an INI beside the EXE.')
    #ENDBOXED
  #ENDTAB
  #TAB('&Message')
    #BOXED('')
      #DISPLAY('This tab is only who the mail goes TO and what it says. Who it')
      #DISPLAY('comes FROM is on the Account tab, not here. Greyed out')
      #DISPLAY('below means this button''s Action sends nothing.')
    #ENDBOXED
    #ENABLE(%ETbAction<>'3')
    #BOXED('Who it goes to')
      #PROMPT('&To:',@s255),%ETbTo,DEFAULT('')
      #PROMPT('&Cc:',@s255),%ETbCc,DEFAULT('')
      #DISPLAY('Type addresses, separated by ; or , - or name a variable or a')
      #DISPLAY('field to take them from at run time (see below).')
      #PROMPT('To from a &variable:',FIELD),%ETbToVar
    #ENDBOXED
    #BOXED('What it says')
      #PROMPT('&Subject:',@s255),%ETbSubject,DEFAULT('')
      #PROMPT('Subject from a v&ariable:',FIELD),%ETbSubjectVar
      #PROMPT('&Body:',@s255),%ETbBody,DEFAULT('')
      #PROMPT('Body from a va&riable:',FIELD),%ETbBodyVar
      #PROMPT('Body is &HTML',CHECK),%ETbHtml,DEFAULT(0),AT(10)
    #ENDBOXED
    #BOXED('Attachment')
      #PROMPT('&File name:',@s255),%ETbAttach,DEFAULT('')
      #PROMPT('File name from a variab&le:',FIELD),%ETbAttachVar
    #ENDBOXED
    #ENDENABLE
  #ENDTAB
#ENDSHEET
#!
#!  The class has to be visible to THIS module even when the global extension
#!  is on a different one; ,ONCE keys on the file name across the whole compile
#!  so it is still pulled in exactly once. (Corpus: ABDROPS.TPW:65.)
#AT(%CustomGlobalDeclarations),WHERE(%ETbDisable=0)
INCLUDE('EmailToClass.INC'),ONCE
#ENDAT
#!
#!  Capture THIS instance's real field equate before anything else runs: AppGen
#!  uniques the USE() when the button is dropped more than once (?EmailBtn,
#!  ?EmailBtn:2, ...), so the event handler has to be attached to whatever this
#!  instance actually got.  #ATSTART + the shipped #FOR(%Control) idiom is how
#!  every MULTI control template does it (corpus: CONTROL.TPW:107, CloseButton).
#ATSTART
  #DECLARE(%ETbBtn)
  #FOR(%Control),WHERE(%ControlInstance=%ActiveTemplateInstance)
    #SET(%ETbBtn,%Control)
  #ENDFOR
  #!  Each of the four values is either a variable the user named or a literal
  #!  they typed.  Resolving that HERE, into one symbol each, keeps the emitted
  #!  call on a single line - Clarion has no free line continuation, so an
  #!  argument list split across output lines simply does not compile.
  #DECLARE(%ETbToExpr)
  #DECLARE(%ETbSubjExpr)
  #DECLARE(%ETbBodyExpr)
  #DECLARE(%ETbAttachExpr)
  #IF(%ETbToVar)
    #SET(%ETbToExpr,%ETbToVar)
  #ELSE
    #SET(%ETbToExpr,'''' & %ETbTo & '''')
  #ENDIF
  #IF(%ETbSubjectVar)
    #SET(%ETbSubjExpr,%ETbSubjectVar)
  #ELSE
    #SET(%ETbSubjExpr,'''' & %ETbSubject & '''')
  #ENDIF
  #IF(%ETbBodyVar)
    #SET(%ETbBodyExpr,%ETbBodyVar)
  #ELSE
    #SET(%ETbBodyExpr,'''' & %ETbBody & '''')
  #ENDIF
  #IF(%ETbAttachVar)
    #SET(%ETbAttachExpr,%ETbAttachVar)
  #ELSE
    #SET(%ETbAttachExpr,'''' & %ETbAttach & '''')
  #ENDIF
#ENDAT
#!
#AT(%ControlEventHandling,%ETbBtn,'Accepted'),WHERE(%ETbDisable=0)
  #CASE(%ETbAction)
  #OF('3')
  %ETbObject.Setup()
  #OF('1')
    #IF(%ETbToVar OR %ETbTo OR %ETbSubject OR %ETbSubjectVar OR %ETbBody OR %ETbBodyVar OR %ETbAttach OR %ETbAttachVar)
  %ETbObject.Compose(%ETbToExpr, %ETbSubjExpr, %ETbBodyExpr, %ETbAttachExpr)
    #ELSE
  %ETbObject.Compose()
    #ENDIF
  #ELSE
  #INSERT(%ETbBuildMessage)
  IF %ETbObject.Send(%ETbObject.Msg)
    #IF(%ETbSayOk)
    MESSAGE(%ETbObject.Txt(ETTxt:Sent), %ETbObject.Txt(ETTxt:Compose), ICON:Asterisk)
    #ENDIF
    #IF(NOT %ETbSayOk)
    !  nothing to report - the send succeeded quietly
    #ENDIF
  ELSE
    #IF(%ETbSayError)
    %ETbObject.ShowError()
    #ENDIF
    #IF(NOT %ETbSayError)
    !  the failure is in %ETbObject.LastErrorText for your own handling
    #ENDIF
  END
  #ENDCASE
#ENDAT
#!
#!--- the message builder, shared by the button and the code template --------
#GROUP(%ETbBuildMessage)
  %ETbObject.Msg.ClearAll()
  #IF(%ETbToVar)
  %ETbObject.Msg.AddList(%ETbToVar, ETAddr:To)
  #ELSE
  %ETbObject.Msg.AddList('%ETbTo', ETAddr:To)
  #ENDIF
  #IF(%ETbCc)
  %ETbObject.Msg.AddList('%ETbCc', ETAddr:Cc)
  #ENDIF
  #IF(%ETbSubjectVar)
  %ETbObject.Msg.SetSubject(%ETbSubjectVar)
  #ELSE
  %ETbObject.Msg.SetSubject('%ETbSubject')
  #ENDIF
  #IF(%ETbHtml)
    #IF(%ETbBodyVar)
  %ETbObject.Msg.SetHtml(%ETbBodyVar)
    #ELSE
  %ETbObject.Msg.SetHtml('%ETbBody')
    #ENDIF
  #ELSE
    #IF(%ETbBodyVar)
  %ETbObject.Msg.SetText(%ETbBodyVar)
    #ELSE
  %ETbObject.Msg.SetText('%ETbBody')
    #ENDIF
  #ENDIF
  #IF(%ETbAttachVar)
  IF CLIP(%ETbAttachVar) THEN %ETbObject.Msg.Attach(%ETbAttachVar).
  #ENDIF
  #IF(%ETbAttach AND NOT %ETbAttachVar)
  %ETbObject.Msg.Attach('%ETbAttach')
  #ENDIF
#!#############################################################################
#!  CODE TEMPLATE - emailToSend  -  send from any embed
#!#############################################################################
#CODE(emailToSend,'emailTo - Send an e-mail here'),HLP('~emailTo.htm')
#SHEET
  #TAB('&Message')
    #BOXED('Object')
      #DISPLAY('emailTo v1.12 - built 2026-08-24 22:45  [480]')
      #PROMPT('Mail &object name:',@s64),%ETcObject,REQ,DEFAULT('Mailer')
      #DISPLAY('')
      #DISPLAY('The sender address, server and password are NOT set here.')
      #DISPLAY('They are on the "emailTo - Global" extension, Account tab')
      #DISPLAY('(Application - Global Properties - Extensions), set once for the')
      #DISPLAY('whole application.')
    #ENDBOXED
    #BOXED('Who it goes to')
      #PROMPT('&To:',@s255),%ETcTo,DEFAULT('')
      #PROMPT('...or from this &variable:',FIELD),%ETcToVar
      #PROMPT('&Cc:',@s255),%ETcCc,DEFAULT('')
      #PROMPT('&Bcc:',@s255),%ETcBcc,DEFAULT('')
    #ENDBOXED
    #BOXED('What it says')
      #PROMPT('&Subject:',@s255),%ETcSubject,DEFAULT('')
      #PROMPT('...or from this varia&ble:',FIELD),%ETcSubjectVar
      #PROMPT('B&ody:',@s255),%ETcBody,DEFAULT('')
      #PROMPT('...or from this varia&ble:',FIELD),%ETcBodyVar
      #PROMPT('The body is &HTML',CHECK),%ETcHtml,DEFAULT(0),AT(10)
    #ENDBOXED
  #ENDTAB
  #TAB('&Attachment && result')
    #BOXED('Attachment')
      #PROMPT('&File name:',@s255),%ETcAttach,DEFAULT('')
      #PROMPT('...or from this &variable:',FIELD),%ETcAttachVar
      #DISPLAY('')
      #DISPLAY('This is the usual way to e-mail a report: write the PDF, then')
      #DISPLAY('drop this template after it and point the file name here.')
    #ENDBOXED
    #BOXED('What to do with the result')
      #PROMPT('Put the &result (1 = sent) in:',FIELD),%ETcResult
      #PROMPT('Tell the user it &worked',CHECK),%ETcSayOk,DEFAULT(0),AT(10)
      #PROMPT('Show the &error if it failed',CHECK),%ETcSayError,DEFAULT(1),AT(10)
      #DISPLAY('')
      #DISPLAY('Whatever you choose, the reason is always left in')
      #DISPLAY('<object>.LastErrorText for your own code to use.')
    #ENDBOXED
  #ENDTAB
#ENDSHEET
  %ETcObject.Msg.ClearAll()
#IF(%ETcToVar)
  %ETcObject.Msg.AddList(%ETcToVar, ETAddr:To)
#ELSE
  %ETcObject.Msg.AddList('%ETcTo', ETAddr:To)
#ENDIF
#IF(%ETcCc)
  %ETcObject.Msg.AddList('%ETcCc', ETAddr:Cc)
#ENDIF
#IF(%ETcBcc)
  %ETcObject.Msg.AddList('%ETcBcc', ETAddr:Bcc)
#ENDIF
#IF(%ETcSubjectVar)
  %ETcObject.Msg.SetSubject(%ETcSubjectVar)
#ELSE
  %ETcObject.Msg.SetSubject('%ETcSubject')
#ENDIF
#IF(%ETcHtml)
  #IF(%ETcBodyVar)
  %ETcObject.Msg.SetHtml(%ETcBodyVar)
  #ELSE
  %ETcObject.Msg.SetHtml('%ETcBody')
  #ENDIF
#ELSE
  #IF(%ETcBodyVar)
  %ETcObject.Msg.SetText(%ETcBodyVar)
  #ELSE
  %ETcObject.Msg.SetText('%ETcBody')
  #ENDIF
#ENDIF
#IF(%ETcAttachVar)
  IF CLIP(%ETcAttachVar) THEN %ETcObject.Msg.Attach(%ETcAttachVar).
#ENDIF
#IF(%ETcAttach AND NOT %ETcAttachVar)
  %ETcObject.Msg.Attach('%ETcAttach')
#ENDIF
#IF(%ETcResult)
  %ETcResult = %ETcObject.Send(%ETcObject.Msg)
  IF NOT %ETcResult
  #IF(%ETcSayError)
    %ETcObject.ShowError()
  #ELSE
    !  the reason is in %ETcObject.LastErrorText
  #ENDIF
  #IF(%ETcSayOk)
  ELSE
    MESSAGE(%ETcObject.Txt(ETTxt:Sent), %ETcObject.Txt(ETTxt:Compose), ICON:Asterisk)
  #ENDIF
  END
#ELSE
  IF %ETcObject.Send(%ETcObject.Msg)
  #IF(%ETcSayOk)
    MESSAGE(%ETcObject.Txt(ETTxt:Sent), %ETcObject.Txt(ETTxt:Compose), ICON:Asterisk)
  #ELSE
    !  sent
  #ENDIF
  ELSE
  #IF(%ETcSayError)
    %ETcObject.ShowError()
  #ELSE
    !  the reason is in %ETcObject.LastErrorText
  #ENDIF
  END
#ENDIF
#!#############################################################################
#!  CODE TEMPLATE - emailToCompose
#!#############################################################################
#CODE(emailToCompose,'emailTo - Open the compose window here'),HLP('~emailTo.htm')
#SHEET
  #TAB('&General')
    #BOXED('Object')
      #DISPLAY('emailTo v1.12 - built 2026-08-24 22:45  [480]')
      #PROMPT('Mail &object name:',@s64),%ETmObject,REQ,DEFAULT('Mailer')
      #DISPLAY('')
      #DISPLAY('The sender address, server and password are NOT set here.')
      #DISPLAY('They are on the "emailTo - Global" extension, Account tab')
      #DISPLAY('(Application - Global Properties - Extensions), set once for the')
      #DISPLAY('whole application.')
    #ENDBOXED
    #BOXED('Pre-fill the window (all optional)')
      #PROMPT('&To:',@s255),%ETmTo,DEFAULT('')
      #PROMPT('...or from this &variable:',FIELD),%ETmToVar
      #PROMPT('&Subject:',@s255),%ETmSubject,DEFAULT('')
      #PROMPT('...or from this v&ariable:',FIELD),%ETmSubjectVar
      #PROMPT('&Body:',@s255),%ETmBody,DEFAULT('')
      #PROMPT('&Attach this file:',@s255),%ETmAttach,DEFAULT('')
      #PROMPT('...or from this varia&ble:',FIELD),%ETmAttachVar
    #ENDBOXED
    #BOXED('Result')
      #PROMPT('Put the &result (1 = sent) in:',FIELD),%ETmResult
    #ENDBOXED
  #ENDTAB
#ENDSHEET
#!  Resolve each argument into one symbol first, then emit the call on a
#!  single line - see the note in the button template above.
#DECLARE(%ETmToExpr)
#DECLARE(%ETmSubjExpr)
#DECLARE(%ETmAttachExpr)
#IF(%ETmToVar)
  #SET(%ETmToExpr,%ETmToVar)
#ELSE
  #SET(%ETmToExpr,'''' & %ETmTo & '''')
#ENDIF
#IF(%ETmSubjectVar)
  #SET(%ETmSubjExpr,%ETmSubjectVar)
#ELSE
  #SET(%ETmSubjExpr,'''' & %ETmSubject & '''')
#ENDIF
#IF(%ETmAttachVar)
  #SET(%ETmAttachExpr,%ETmAttachVar)
#ELSE
  #SET(%ETmAttachExpr,'''' & %ETmAttach & '''')
#ENDIF
#IF(%ETmResult)
  %ETmResult = %ETmObject.Compose(%ETmToExpr, %ETmSubjExpr, '%ETmBody', %ETmAttachExpr)
#ELSE
  %ETmObject.Compose(%ETmToExpr, %ETmSubjExpr, '%ETmBody', %ETmAttachExpr)
#ENDIF
#!#############################################################################
#!  CODE TEMPLATE - emailToSetup
#!#############################################################################
#CODE(emailToSetup,'emailTo - Open the mail account setup window here'),HLP('~emailTo.htm')
#SHEET
  #TAB('&General')
    #BOXED('Object')
      #DISPLAY('emailTo v1.12 - built 2026-08-24 22:45  [480]')
      #PROMPT('Mail &object name:',@s64),%ETsObject,REQ,DEFAULT('Mailer')
      #DISPLAY('')
      #DISPLAY('This is where the END USER sets the account. The values it')
      #DISPLAY('starts from are the ones you put on the "emailTo - Global"')
      #DISPLAY('extension, Account tab.')
    #ENDBOXED
    #BOXED('What it does')
      #DISPLAY('Opens the account window: provider, server, port, security,')
      #DISPLAY('user name and password - plus a "Sign in..." button that runs')
      #DISPLAY('the OAuth2 consent flow in the user''s own browser, a "Test')
      #DISPLAY('account" button that connects and signs in without sending')
      #DISPLAY('anything, and a Log tab showing the whole conversation.')
      #DISPLAY('')
      #DISPLAY('Saving calls SaveAccount(), which writes to the settings table')
      #DISPLAY('you nominated in the global extension, or to the INI file.')
      #PROMPT('Put the &result (1 = saved) in:',FIELD),%ETsResult
    #ENDBOXED
  #ENDTAB
#ENDSHEET
#IF(%ETsResult)
  %ETsResult = %ETsObject.Setup()
#ELSE
  %ETsObject.Setup()
#ENDIF
#!#############################################################################
#!  CONTROL TEMPLATE - emailToApiButton
#!#############################################################################
#!  Drag onto any window for a wired "Mail account..." button. It opens the
#!  management window - blocked addresses and why, statistics, activity,
#!  contacts, lists, campaigns, templates, senders, domains, webhooks - on
#!  whichever tab you name. A tab this provider cannot answer is greyed out
#!  rather than empty, so the button is safe to put on a window whoever the
#!  end user signed up with.
#!#############################################################################
#CONTROL(emailToApiButton,'emailTo - Mail account button (blocked, stats, campaigns)'),WINDOW,MULTI,DESCRIPTION('Mail account button - opens on ' & CHOOSE(%ETaTab='2','BLOCKED ADDRESSES',CHOOSE(%ETaTab='7','CAMPAIGNS','tab ' & %ETaTab))),HLP('~emailTo.htm')
  CONTROLS
    BUTTON('&Mail account...'),AT(,,62,14),USE(?EmailApiBtn),TIP('Blocked addresses, statistics and campaigns')
  END
#SHEET
  #TAB('&General')
    #BOXED('Button')
      #DISPLAY('emailTo v1.12 - built 2026-08-24 22:45  [480]')
      #PROMPT('&Disable this button',CHECK),%ETaDisable,DEFAULT(0),AT(10)
      #PROMPT('&API object name:',@s64),%ETaObject,REQ,DEFAULT('MailApi')
      #DISPLAY('The object the emailToGlobal extension declared on its')
      #DISPLAY('Provider API tab. Switch that on if you have not already.')
    #ENDBOXED
    #BOXED('Which tab it opens on')
      #PROMPT('&Open on:',DROP('Account[1]|Blocked addresses[2]|Statistics[3]|Activity[4]|Contacts[5]|Lists[6]|Campaigns[7]|Templates[8]|Senders and domains[9]|Webhooks[10]')),%ETaTab,DEFAULT('2')
      #DISPLAY('')
      #DISPLAY('If this provider cannot answer that one, the window opens on')
      #DISPLAY('the first tab it CAN answer instead of showing an empty list.')
    #ENDBOXED
    #BOXED('Only show the button when it will work')
      #PROMPT('&Hide it if there is no API',CHECK),%ETaHide,DEFAULT(1),AT(10)
      #DISPLAY('An account sending over plain SMTP - a company Exchange')
      #DISPLAY('server, Gmail with an app password - has no management API')
      #DISPLAY('at all. With this ticked the button disappears for those')
      #DISPLAY('accounts instead of opening a window with every tab greyed')
      #DISPLAY('out.')
    #ENDBOXED
  #ENDTAB
#ENDSHEET
#!
#AT(%CustomGlobalDeclarations),WHERE(%ETaDisable=0)
INCLUDE('EmailApiClass.INC'),ONCE
#ENDAT
#!
#!  Capture THIS instance's field equate: AppGen uniques the USE() when the
#!  button is dropped more than once (?EmailApiBtn, ?EmailApiBtn:2, ...).
#ATSTART
  #DECLARE(%ETaBtn)
  #FOR(%Control),WHERE(%ControlInstance=%ActiveTemplateInstance)
    #SET(%ETaBtn,%Control)
  #ENDFOR
#ENDAT
#!
#AT(%WindowManagerMethodCodeSection,'Init','(),BYTE'),PRIORITY(8500),WHERE(%ETaDisable=0 AND %ETaHide)
  !  Nothing to manage unless this account talks to a provider API.
  IF NOT %ETaObject.Supports(ETOp:Suppressions) AND NOT %ETaObject.Supports(ETOp:Stats) |
     AND NOT %ETaObject.Supports(ETOp:Account)
    HIDE(%ETaBtn)
  END
#ENDAT
#!
#AT(%ControlEventHandling,%ETaBtn,'Accepted'),WHERE(%ETaDisable=0)
  #ADD(%ETApiWanted,%Procedure)                            #! checked once the global module generates
  %ETaObject.Manage(%ETaTab)
#ENDAT
#!#############################################################################
#!  CONTROL TEMPLATE - emailToSyncButton
#!#############################################################################
#!  Drag onto any window for a wired "Sync mail data" button. It calls the
#!  Run method the emailTo - Sync extension generated, which brings the
#!  provider's answers down into the tables nominated there.
#!
#!  Running it twice changes nothing: every row is looked up by its key first,
#!  so a row already there is updated rather than duplicated. That is what
#!  makes it safe on a button anybody can press twice.
#!#############################################################################
#CONTROL(emailToSyncButton,'emailTo - Sync mail data into your tables (drag onto a window)'),WINDOW,MULTI,DESCRIPTION('Sync mail data - ' & CHOOSE(%ETzSilent='1','quietly','reports what it did')),HLP('~emailTo.htm')
  CONTROLS
    BUTTON('&Sync mail data'),AT(,,68,14),USE(?EmailSyncBtn),TIP('Bring the blocked list, statistics and campaigns down into your tables')
  END
#SHEET
  #TAB('&General')
    #BOXED('Button')
      #DISPLAY('emailTo v1.12 - built 2026-08-24 22:45  [480]')
      #PROMPT('&Disable this button',CHECK),%ETzDisable,DEFAULT(0),AT(10)
      #PROMPT('&Sync object name:',@s64),%ETzObject,REQ,DEFAULT('MailSync')
      #DISPLAY('The object the "emailTo - Sync provider data into your tables"')
      #DISPLAY('extension declared. Add that extension to this application if')
      #DISPLAY('you have not already.')
    #ENDBOXED
    #BOXED('What it does')
      #DISPLAY('Calls <object>.Run(), which the emailTo - Sync extension')
      #DISPLAY('generated from the tables nominated there.')
      #PROMPT('&Quietly - no message',CHECK),%ETzSilent,DEFAULT(0),AT(10)
      #DISPLAY('Left off, it reports how many rows came down and how many')
      #DISPLAY('were new. Turn it on for a button that runs on a timer.')
      #PROMPT('Put the &row count in:',FIELD),%ETzResult
    #ENDBOXED
    #BOXED('Refreshing what is on the window')
      #PROMPT('Reset the &browse afterwards',CHECK),%ETzReset,DEFAULT(1),AT(10)
      #DISPLAY('Calls BRW1.ResetFromFile() so a browse of the synced table')
      #DISPLAY('shows the new rows without the user closing the window.')
      #PROMPT('Bro&wse object:',@s64),%ETzBrowse,DEFAULT('BRW1')
    #ENDBOXED
  #ENDTAB
#ENDSHEET
#!
#AT(%CustomGlobalDeclarations),WHERE(%ETzDisable=0)
INCLUDE('EmailApiClass.INC'),ONCE
#ENDAT
#!
#ATSTART
  #DECLARE(%ETzBtn)
  #FOR(%Control),WHERE(%ControlInstance=%ActiveTemplateInstance)
    #SET(%ETzBtn,%Control)
  #ENDFOR
#ENDAT
#!
#AT(%ControlEventHandling,%ETzBtn,'Accepted'),WHERE(%ETzDisable=0)
  SETCURSOR(CURSOR:Wait)
  #IF(%ETzResult)
  %ETzResult = %ETzObject.Run(%ETzSilent)
  #ELSE
  %ETzObject.Run(%ETzSilent)
  #ENDIF
  SETCURSOR()
  #IF(%ETzReset AND %ETzBrowse)
  %ETzBrowse.ResetFromFile()                               ! show what just arrived
  %ETzBrowse.ResetQueue(1)
  #ENDIF
#ENDAT
#!#############################################################################
#!  CODE TEMPLATE - emailToApi
#!#############################################################################
#!  One provider-API operation, from any embed. The point of this template is
#!  that the SAME prompts generate working code for eight different providers -
#!  the class is what knows the difference.
#!#############################################################################
#CODE(emailToApi,'emailTo - Ask the provider (blocked, stats, campaigns) here'),HLP('~emailTo.htm')
#SHEET
  #TAB('&What to do')
    #BOXED('Object')
      #DISPLAY('emailTo v1.12 - built 2026-08-24 22:45  [480]')
      #PROMPT('&API object name:',@s64),%ETpObject,REQ,DEFAULT('MailApi')
    #ENDBOXED
    #BOXED('Operation')
      #PROMPT('&Do this:',DROP('Load the blocked addresses[1]|Unblock ONE address[2]|Unblock EVERY address[3]|Block an address[4]|Is this address blocked?[5]|Load the statistics[6]|Load the activity[7]|Load the contacts[8]|Load the lists[9]|Load the campaigns[10]|Send a campaign[11]|Export the blocked list to CSV[12]|Open the management window[13]|Sync it all into my tables[14]')),%ETpOp,DEFAULT('1')
      #ENABLE(%ETpOp='1' OR %ETpOp='2' OR %ETpOp='3' OR %ETpOp='4' OR %ETpOp='12')
        #PROMPT('W&hich list:',DROP('Everything[0]|Bounces[1]|Blocked[2]|Spam reports[3]|Unsubscribed[4]|Invalid[5]')),%ETpKind,DEFAULT('0')
        #DISPLAY('A provider that keeps one list for all of them answers the same')
        #DISPLAY('rows whichever you pick, labelled with what they are.')
      #ENDENABLE
    #ENDBOXED
    #BOXED('The address, id or file name it works on')
      #PROMPT('&Value:',@s255),%ETpArg,DEFAULT('')
      #PROMPT('...or from this &variable:',FIELD),%ETpArgVar
      #DISPLAY('')
      #DISPLAY('Unblock / Block / Is blocked - an e-mail address. Send a')
      #DISPLAY('campaign - the campaign id. Export - the file to write.')
      #DISPLAY('Everything else - not used.')
      #DISPLAY('')
      #DISPLAY('"Sync it all into my tables" calls MailSync.Run(), so it needs')
      #DISPLAY('the "emailTo - Sync provider data into your tables" extension')
      #DISPLAY('on this application, with its tables nominated.')
    #ENDBOXED
  #ENDTAB
  #TAB('&Result')
    #BOXED('What to do with the answer')
      #PROMPT('Put the &result in:',FIELD),%ETpResult
      #DISPLAY('')
      #DISPLAY('For a "Load" the result is the NUMBER of rows, or -1 if the')
      #DISPLAY('provider said no. For everything else, 1 means it worked.')
      #DISPLAY('')
      #DISPLAY('The rows themselves land in the object queues, which are')
      #DISPLAY('the same shape whoever the provider is:')
      #DISPLAY('    <object>.SuppQ      Address, Kind, KindName, Reason,')
      #DISPLAY('                        Code, WhenDate, WhenTime, Sender')
      #DISPLAY('    <object>.StatQ      WhenDate, Requests, Delivered, Opens,')
      #DISPLAY('                        Clicks, HardBounces, SpamReports...')
      #DISPLAY('    <object>.EventQ     WhenDate, Address, EventName, Reason')
      #DISPLAY('    <object>.ContactQ   <object>.ListQ   <object>.CampaignQ')
    #ENDBOXED
    #BOXED('If it fails')
      #PROMPT('&Show the error',CHECK),%ETpSayError,DEFAULT(1),AT(10)
      #DISPLAY('Either way the reason is left in <object>.LastErrorText, and the')
      #DISPLAY('address it called in <object>.LastUrl.')
    #ENDBOXED
    #BOXED('Before you call it')
      #DISPLAY('<object>.Supports(ETOp:Suppressions) is 0 when this provider')
      #DISPLAY('has no such endpoint - worth testing if your end users choose')
      #DISPLAY('their own provider.')
    #ENDBOXED
  #ENDTAB
#ENDSHEET
#ADD(%ETApiWanted,%Procedure)                              #! checked once the global module generates
#!  Resolve the argument into one symbol, so the emitted call fits on one line.
#DECLARE(%ETpArgExpr)
#IF(%ETpArgVar)
  #SET(%ETpArgExpr,%ETpArgVar)
#ELSE
  #SET(%ETpArgExpr,'''' & %ETpArg & '''')
#ENDIF
#DECLARE(%ETpCall)
#CASE(%ETpOp)
#OF('1')
  #SET(%ETpCall,%ETpObject & '.GetSuppressions(' & %ETpKind & ')')
#OF('2')
  #SET(%ETpCall,%ETpObject & '.DeleteSuppression(' & %ETpArgExpr & ', ' & %ETpKind & ')')
#OF('3')
  #SET(%ETpCall,%ETpObject & '.DeleteAllSuppressions(' & %ETpKind & ')')
#OF('4')
  #SET(%ETpCall,%ETpObject & '.AddSuppression(' & %ETpArgExpr & ', ' & %ETpKind & ')')
#OF('5')
  #SET(%ETpCall,%ETpObject & '.IsBlocked(' & %ETpArgExpr & ')')
#OF('6')
  #SET(%ETpCall,%ETpObject & '.GetStats(TODAY() - 30, TODAY())')
#OF('7')
  #SET(%ETpCall,%ETpObject & '.GetEvents(TODAY() - 7, TODAY())')
#OF('8')
  #SET(%ETpCall,%ETpObject & '.GetContacts()')
#OF('9')
  #SET(%ETpCall,%ETpObject & '.GetLists()')
#OF('10')
  #SET(%ETpCall,%ETpObject & '.GetCampaigns()')
#OF('11')
  #SET(%ETpCall,%ETpObject & '.SendCampaign(' & %ETpArgExpr & ')')
#OF('12')
  #SET(%ETpCall,%ETpObject & '.ExportSuppressions(' & %ETpArgExpr & ')')
#OF('14')
  #!  the sync is its own object, declared by the emailTo - Sync extension
  #SET(%ETpCall,'MailSync.Run()')
#ELSE
  #SET(%ETpCall,%ETpObject & '.Manage()')
#ENDCASE
#IF(%ETpOp='12')
  #!  Export writes whatever is loaded, so load it first if nothing is.
  IF NOT RECORDS(%ETpObject.SuppQ) THEN %ETpObject.GetSuppressions(%ETpKind).
#ENDIF
#IF(%ETpResult)
  %ETpResult = %ETpCall
#ELSE
  %ETpCall
#ENDIF
#IF(%ETpSayError AND %ETpOp<>'5' AND %ETpOp<>'13' AND %ETpOp<>'14')
  !  Every call leaves its verdict in LastError, so one test covers the lot -
  !  and "no rows" is not an error, which testing the answer would get wrong.
  IF %ETpObject.LastError
    %ETpObject.ShowError()
  END
#ENDIF
