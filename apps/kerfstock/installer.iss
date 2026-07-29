#define MyAppName "KerfStock"
#define MyAppVersion "1.0.1-beta.1"
#define MyAppPublisher "Feed Rate / SynonTech"
#define MyAppExeName "kerfstock.exe"

[Setup]
AppId={{B30D13C7-47C1-4ED6-A7BA-46D17E86931A}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
DefaultDirName={autopf}\KerfStock
DefaultGroupName=KerfStock
DisableProgramGroupPage=yes
OutputDir=dist
OutputBaseFilename=KerfStock_Setup_v{#MyAppVersion}
SetupIconFile=windows\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\{#MyAppExeName}
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
Compression=lzma2
SolidCompression=yes
WizardStyle=modern

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
Source: "build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\KerfStock"; Filename: "{app}\{#MyAppExeName}"
Name: "{autodesktop}\KerfStock"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,KerfStock}"; Flags: nowait postinstall skipifsilent
