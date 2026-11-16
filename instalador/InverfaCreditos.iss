#define AppName "Inverfa Creditos"
#define AppVersion "1.0.0"
#define Fuente "..\build\windows\x64\runner\Release"

[Setup]
AppId={{B7E2A6D4-3C51-4E8A-9F0B-5D2C7A1E9C34}
AppName={#AppName}
AppVersion={#AppVersion}
AppPublisher=Comercial Inverfa
DefaultDirName={autopf}\Inverfa Creditos
DefaultGroupName={#AppName}
DisableProgramGroupPage=yes
OutputDir=..\build\instalador
OutputBaseFilename=Instalador_InverfaCreditos_{#AppVersion}
SetupIconFile=..\windows\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\InverfaCreditos.exe
Compression=lzma2
SolidCompression=yes
PrivilegesRequired=admin
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
CloseApplications=force
WizardStyle=modern

[Languages]
Name: "es"; MessagesFile: "compiler:Languages\Spanish.isl"

[Tasks]
Name: "desktopicon"; Description: "Crear acceso directo en el escritorio"; GroupDescription: "Accesos directos:"

[Files]
Source: "{#Fuente}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\{#AppName}"; Filename: "{app}\InverfaCreditos.exe"
Name: "{autodesktop}\{#AppName}"; Filename: "{app}\InverfaCreditos.exe"; Tasks: desktopicon

[Run]
Filename: "{sys}\sc.exe"; Parameters: "config ""MSSQL$SQLEXPRESS"" start= auto"; Flags: runhidden waituntilterminated; StatusMsg: "Configurando SQL Server..."
Filename: "{sys}\sc.exe"; Parameters: "start ""MSSQL$SQLEXPRESS"""; Flags: runhidden waituntilterminated
Filename: "{app}\InverfaCreditos.exe"; Description: "Abrir {#AppName}"; Flags: nowait postinstall skipifsilent

[Code]
function PrepareToInstall(var NeedsRestart: Boolean): String;
var
  Res: Integer;
begin
  Exec(ExpandConstant('{sys}\taskkill.exe'), '/F /IM "InverfaCreditos.exe"', '', SW_HIDE, ewWaitUntilTerminated, Res);
  Result := '';
end;
