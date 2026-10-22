#ifndef AppVersion
  #define AppVersion "0.1.0"
#endif

#ifndef SourceDir
  #define SourceDir "..\..\build\windows\x64\runner\Release"
#endif

#ifndef DatasetToolsDir
  #define DatasetToolsDir "..\..\build\dataset_tools\signbridge_dataset_assets"
#endif

[Setup]
AppId={{7D96E2B8-7FAE-4F32-AEF8-2B4C3056E395}
AppName=SignBridge
AppVersion={#AppVersion}
AppPublisher=SignBridge
DefaultDirName={localappdata}\Programs\SignBridge
DefaultGroupName=SignBridge
DisableProgramGroupPage=yes
PrivilegesRequired=lowest
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
SetupIconFile=..\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\signbridge.exe
OutputDir=..\..\build\installer
OutputBaseFilename=SignBridge-Setup-{#AppVersion}-Windows-x64
WizardStyle=modern
Compression=lzma2
SolidCompression=yes
Uninstallable=yes

[Tasks]
Name: "desktopicon"; Description: "Create a desktop shortcut"; GroupDescription: "Additional shortcuts:"; Flags: checkedonce

[Files]
Source: "{#SourceDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "{#DatasetToolsDir}\*"; DestDir: "{app}\dataset_tools"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\SignBridge"; Filename: "{app}\signbridge.exe"; WorkingDir: "{app}"
Name: "{autodesktop}\SignBridge"; Filename: "{app}\signbridge.exe"; WorkingDir: "{app}"; Tasks: desktopicon

[Run]
Filename: "{app}\signbridge.exe"; Description: "Launch SignBridge"; Flags: nowait postinstall skipifsilent
