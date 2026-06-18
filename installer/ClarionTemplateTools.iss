; ============================================================================
;  Clarion Template Tools - Inno Setup installer
;
;  Bundles:
;    * the Clarion Template Designer (self-contained .NET 9 WPF app)
;    * every template-authoring asset in this repo: templates, the
;      clarion-template skill, and the clarion-template-pro agent
;
;  Build it with:  installer\build-installer.ps1
;  (that script publishes the app into payload\app, then runs ISCC on this file)
; ============================================================================

#define AppName    "Clarion Template Tools"
#define AppVersion "1.5.0"
#define AppPublisher "Roberto Renz"
#define AppExe     "ClarionTplDesigner.exe"
#define ClarionTpl "C:\clarion12\accessory\template\win"

[Setup]
AppId={{8F3C1B9A-2D44-4E7C-9A1E-7C5B6E2F0A11}
AppName={#AppName}
AppVersion={#AppVersion}
AppPublisher={#AppPublisher}
DefaultDirName={autopf}\{#AppName}
DefaultGroupName={#AppName}
DisableProgramGroupPage=yes
OutputDir=Output
OutputBaseFilename=ClarionTemplateToolsSetup
Compression=lzma2/max
SolidCompression=yes
WizardStyle=modern
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
PrivilegesRequired=admin
PrivilegesRequiredOverridesAllowed=dialog
UninstallDisplayIcon={app}\{#AppExe}

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "Create a &desktop shortcut for the Template Designer"; GroupDescription: "Shortcuts:"
Name: "clarion";     Description: "Install the templates into your Clarion install ({#ClarionTpl})"; GroupDescription: "Template tooling:"; Check: ClarionExists
Name: "claude";      Description: "Install the clarion-template skill + clarion-template-pro agent into your ~\.claude folder"; GroupDescription: "Template tooling:"

[Files]
; --- the designer app (self-contained; no .NET runtime needed on the target) ---
Source: "payload\app\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

; --- a local, authoritative copy of every authoring asset ---
Source: "..\templates\*"; DestDir: "{app}\templates"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "..\agents\*";    DestDir: "{app}\agents";    Flags: ignoreversion recursesubdirs createallsubdirs
Source: "..\skills\*";    DestDir: "{app}\skills";    Flags: ignoreversion recursesubdirs createallsubdirs
Source: "..\README.md";   DestDir: "{app}"; Flags: ignoreversion
Source: "..\LICENSE";     DestDir: "{app}"; Flags: ignoreversion

; --- optional: drop the .tpl/.png straight into a detected Clarion install ---
Source: "..\templates\*.tpl";              DestDir: "{#ClarionTpl}"; Tasks: clarion; Check: ClarionExists; Flags: ignoreversion
Source: "..\templates\*.png";              DestDir: "{#ClarionTpl}"; Tasks: clarion; Check: ClarionExists; Flags: ignoreversion
Source: "..\templates\myFontChanger\*.tpl"; DestDir: "{#ClarionTpl}"; Tasks: clarion; Check: ClarionExists; Flags: ignoreversion
Source: "..\templates\myFuncs\*.tpl";       DestDir: "{#ClarionTpl}"; Tasks: clarion; Check: ClarionExists; Flags: ignoreversion
Source: "..\templates\myPie\*.tpl";         DestDir: "{#ClarionTpl}"; Tasks: clarion; Check: ClarionExists; Flags: ignoreversion

; --- optional: install the Claude skill + agent into the user's profile ---
Source: "..\skills\*"; DestDir: "{%USERPROFILE}\.claude\skills"; Tasks: claude; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "..\agents\*"; DestDir: "{%USERPROFILE}\.claude\agents"; Tasks: claude; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\Clarion Template Designer"; Filename: "{app}\{#AppExe}"
Name: "{group}\Templates folder";          Filename: "{app}\templates"
Name: "{group}\Read me";                   Filename: "{app}\README.md"
Name: "{autodesktop}\Clarion Template Designer"; Filename: "{app}\{#AppExe}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#AppExe}"; Description: "Launch the Template Designer now"; Flags: nowait postinstall skipifsilent

[Code]
function ClarionExists: Boolean;
begin
  Result := DirExists('{#ClarionTpl}');
end;
