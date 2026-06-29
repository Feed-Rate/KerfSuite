[Setup]
AppName=KerfCut
AppVersion=1.0.0
AppPublisher=Feed Rate
DefaultDirName={autopf}\KerfCut
DisableProgramGroupPage=yes
OutputBaseFilename=KerfCut_Setup_v1.0.0
Compression=lzma
SolidCompression=yes
WizardStyle=modern

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
Source: "build\main.dist\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\KerfCut"; Filename: "{app}\main.exe"
Name: "{autodesktop}\KerfCut"; Filename: "{app}\main.exe"; Tasks: desktopicon

[Run]
Filename: "{app}\main.exe"; Description: "{cm:LaunchProgram,KerfCut}"; Flags: nowait postinstall skipifsilent
