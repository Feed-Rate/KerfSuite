[Setup]
AppName=KerfCut
AppVersion=1.0.1
AppPublisher=Feed Rate
DefaultDirName={autopf}\KerfCut
DisableProgramGroupPage=yes
OutputDir=Output
OutputBaseFilename=KerfCut_Setup_v1.0.1_beta
Compression=lzma
SolidCompression=yes
WizardStyle=modern

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
Source: "build\KerfCut\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\KerfCut"; Filename: "{app}\KerfCut.exe"
Name: "{autodesktop}\KerfCut"; Filename: "{app}\KerfCut.exe"; Tasks: desktopicon

[Run]
Filename: "{app}\KerfCut.exe"; Description: "{cm:LaunchProgram,KerfCut}"; Flags: nowait postinstall skipifsilent
