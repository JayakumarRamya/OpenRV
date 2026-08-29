; ---------------------------------------------------------------------------
;  Pixrock RV - Inno Setup installer
;
;  Build with:
;    iscc Pixrock_Installer.iss
;
;  Override the payload directory (e.g. an artifact downloaded from CI):
;    iscc /DMyAppSourceDir="D:\path\to\install" Pixrock_Installer.iss
;
;  Asset paths below are relative to this .iss file, so the installer builds
;  from a clean checkout without depending on anyone's Downloads folder.
; ---------------------------------------------------------------------------

#define MyAppName      "Pixrock RV"
#define MyAppVersion   "1.2.0"
#define MyAppPublisher "Pixrock"
#define MyAppURL       "https://github.com/AcademySoftwareFoundation/OpenRV"
#define MyAppExeName   "rv.exe"

; Payload directory. Override with /DMyAppSourceDir=... on the command line.
#ifndef MyAppSourceDir
  #define MyAppSourceDir "C:\Users\Artist\Downloads\openrv-windows-Release"
#endif

; Installer output. Deliberately on D: -- C: runs close to full on the
; build workstation and a solid-compressed payload needs headroom.
#ifndef MyOutputDir
  #define MyOutputDir "D:\Pixrock_Installer_Output"
#endif

[Setup]
AppId={{A1B2C3D4-E5F6-7890-ABCD-EF1234567890}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}
AppUpdatesURL={#MyAppURL}
UninstallDisplayIcon={app}\bin\{#MyAppExeName}

DefaultDirName={autopf64}\Pixrock RV
DefaultGroupName={#MyAppName}

OutputDir={#MyOutputDir}
OutputBaseFilename=Pixrock_RV_Setup_v{#MyAppVersion}

Compression=lzma2
SolidCompression=yes

WizardStyle=modern
SetupIconFile=pixrock.ico
WizardImageFile=wizard_banner.bmp
WizardSmallImageFile=wizard_small.bmp

MinVersion=10.0
DisableProgramGroupPage=no
DisableDirPage=no
PrivilegesRequired=admin
ArchitecturesInstallIn64BitMode=x64compatible

; OpenRV is Apache-2.0. Shipping the licence text is a condition of
; redistribution, so it is presented during install rather than buried.
LicenseFile={#MyAppSourceDir}\LICENSE

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "Create a &Desktop shortcut"; GroupDescription: "Additional icons:"; Flags: unchecked
Name: "tuneprefs";   Description: "Tune playback settings for this machine (recommended)"; GroupDescription: "Performance:"
Name: "addtopath";   Description: "Add Pixrock RV to the system &PATH"; GroupDescription: "Integration:"

[Files]
Source: "{#MyAppSourceDir}\bin\*";          DestDir: "{app}\bin";          Flags: ignoreversion recursesubdirs createallsubdirs
Source: "{#MyAppSourceDir}\lib\*";          DestDir: "{app}\lib";          Flags: ignoreversion recursesubdirs createallsubdirs
Source: "{#MyAppSourceDir}\plugins\*";      DestDir: "{app}\plugins";      Flags: ignoreversion recursesubdirs createallsubdirs skipifsourcedoesntexist
Source: "{#MyAppSourceDir}\PlugIns\*";      DestDir: "{app}\PlugIns";      Flags: ignoreversion recursesubdirs createallsubdirs skipifsourcedoesntexist
Source: "{#MyAppSourceDir}\Additional\*";   DestDir: "{app}\Additional";   Flags: ignoreversion recursesubdirs createallsubdirs skipifsourcedoesntexist
Source: "{#MyAppSourceDir}\DLLs\*";         DestDir: "{app}\DLLs";         Flags: ignoreversion recursesubdirs createallsubdirs skipifsourcedoesntexist
Source: "{#MyAppSourceDir}\etc\*";          DestDir: "{app}\etc";          Flags: ignoreversion recursesubdirs createallsubdirs skipifsourcedoesntexist
Source: "{#MyAppSourceDir}\include\*";      DestDir: "{app}\include";      Flags: ignoreversion recursesubdirs createallsubdirs skipifsourcedoesntexist
Source: "{#MyAppSourceDir}\optimize\*";     DestDir: "{app}\optimize";     Flags: ignoreversion recursesubdirs createallsubdirs skipifsourcedoesntexist
Source: "{#MyAppSourceDir}\resources\*";    DestDir: "{app}\resources";    Flags: ignoreversion recursesubdirs createallsubdirs skipifsourcedoesntexist
Source: "{#MyAppSourceDir}\scripts\*";      DestDir: "{app}\scripts";      Flags: ignoreversion recursesubdirs createallsubdirs skipifsourcedoesntexist
Source: "{#MyAppSourceDir}\translations\*"; DestDir: "{app}\translations"; Flags: ignoreversion recursesubdirs createallsubdirs skipifsourcedoesntexist
Source: "{#MyAppSourceDir}\LICENSE";        DestDir: "{app}";              Flags: ignoreversion skipifsourcedoesntexist
Source: "pixrock.ico";                      DestDir: "{app}";              Flags: ignoreversion

[Icons]
; IconFilename is set explicitly so shortcuts show Pixrock branding even when
; the payload was produced by a build that still has the stock icon compiled
; into rv.exe. Once CI rebuilds with src/bin/apps/rv/RV.ico replaced, the
; executable itself carries it too and this simply agrees with it.
Name: "{group}\{#MyAppName}";           Filename: "{app}\bin\{#MyAppExeName}"; IconFilename: "{app}\pixrock.ico"
Name: "{group}\Uninstall {#MyAppName}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\{#MyAppName}";     Filename: "{app}\bin\{#MyAppExeName}"; IconFilename: "{app}\pixrock.ico"; Tasks: desktopicon

[Run]
; Tuning runs before the optional launch so the new preferences are already on
; disk when RV starts and reads them.
Filename: "powershell.exe"; \
  Parameters: "-ExecutionPolicy Bypass -NoProfile -File ""{app}\optimize\Install-PixrockPrefs.ps1"""; \
  WorkingDir: "{app}\optimize"; \
  StatusMsg: "Tuning playback settings for this machine..."; \
  Flags: runhidden waituntilterminated; \
  Tasks: tuneprefs

Filename: "{app}\bin\{#MyAppExeName}"; Description: "Launch {#MyAppName} now"; Flags: nowait postinstall skipifsilent

[Registry]
Root: HKLM; Subkey: "SYSTEM\CurrentControlSet\Control\Session Manager\Environment"; \
  ValueType: expandsz; ValueName: "Path"; ValueData: "{olddata};{app}\bin"; \
  Tasks: addtopath; Check: NeedsAddPath(ExpandConstant('{app}\bin'))

; Only .rv is claimed by default. Grabbing .exr and .mov unconditionally, as
; the previous script did, steals them from Nuke, Photoshop and the system
; player -- a surprise on a shared workstation. Leave those to the user.
Root: HKCR; Subkey: ".rv";                        ValueType: string; ValueName: ""; ValueData: "Pixrock.RVFile"; Flags: uninsdeletevalue
Root: HKCR; Subkey: "Pixrock.RVFile";             ValueType: string; ValueName: ""; ValueData: "Pixrock RV Session"; Flags: uninsdeletekey
Root: HKCR; Subkey: "Pixrock.RVFile\DefaultIcon"; ValueType: string; ValueName: ""; ValueData: "{app}\bin\{#MyAppExeName},0"
Root: HKCR; Subkey: "Pixrock.RVFile\shell\open\command"; ValueType: string; ValueName: ""; ValueData: """{app}\bin\{#MyAppExeName}"" ""%1"""

[Code]

function NeedsAddPath(Param: string): boolean;
var
  OrigPath: string;
begin
  if not RegQueryStringValue(HKEY_LOCAL_MACHINE,
    'SYSTEM\CurrentControlSet\Control\Session Manager\Environment',
    'Path', OrigPath) then
  begin
    Result := True;
    exit;
  end;
  Result := Pos(';' + Param + ';', ';' + OrigPath + ';') = 0;
end;

// Post-install: wire the Nuke -> RV launcher into the user's .nuke folder.
procedure CurStepChanged(CurStep: TSetupStep);
var
  NukeDir, SrcFile, DstFile, MenuPy, ImportLine : string;
  MenuLines                                     : TArrayOfString;
  AlreadyExists                                 : Boolean;
  i                                             : Integer;
begin
  if CurStep <> ssPostInstall then
    exit;

  NukeDir    := GetEnv('USERPROFILE') + '\.nuke';
  SrcFile    := ExpandConstant('{app}') + '\Additional\nukeToRV\rv_launcher.py';
  DstFile    := NukeDir + '\rv_launcher.py';
  MenuPy     := NukeDir + '\menu.py';
  ImportLine := 'import rv_launcher';

  // Nothing to wire up if this build did not ship the launcher.
  if not FileExists(SrcFile) then
    exit;

  if not DirExists(NukeDir) then
    CreateDir(NukeDir);

  CopyFile(SrcFile, DstFile, False);

  if not FileExists(MenuPy) then
  begin
    SaveStringsToFile(MenuPy, [ImportLine], False);
    exit;
  end;

  LoadStringsFromFile(MenuPy, MenuLines);
  AlreadyExists := False;
  for i := 0 to GetArrayLength(MenuLines) - 1 do
  begin
    if Pos(ImportLine, MenuLines[i]) > 0 then
    begin
      AlreadyExists := True;
      Break;
    end;
  end;

  // Append rather than rewrite: menu.py is the user's file and usually
  // already contains their own studio setup.
  if not AlreadyExists then
    SaveStringsToFile(MenuPy, [ImportLine], True);
end;
