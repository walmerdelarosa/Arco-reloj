; Instalador de Arco para Windows (Inno Setup 6).
; Se compila desde GitHub Actions (.github/workflows/release.yml) o con build_installer.bat.
; Requiere haber generado antes dist\ArcoReloj con PyInstaller.
;   iscc /DMyAppVersion=1.2.0 installer\ArcoReloj.iss

#ifndef MyAppVersion
  #define MyAppVersion "1.2.0"
#endif
#define MyAppName "Arco Reloj"
#define MyAppExe "ArcoReloj.exe"
#define MyRunKeyName "ArcoReloj"

[Setup]
AppId={{6E0B7C2A-4F51-4C7B-9C55-3A1E8D2B7F10}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppVerName={#MyAppName} {#MyAppVersion}
AppPublisher=Arco
DefaultDirName={localappdata}\Programs\ArcoReloj
DefaultGroupName={#MyAppName}
DisableProgramGroupPage=yes
; Instalación por usuario: no pide permisos de administrador.
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog
OutputDir=..\dist
OutputBaseFilename=ArcoReloj-{#MyAppVersion}-setup
SetupIconFile=..\icon.ico
UninstallDisplayIcon={app}\{#MyAppExe}
Compression=lzma2/max
SolidCompression=yes
WizardStyle=modern
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
CloseApplications=yes
RestartApplications=no

[Languages]
Name: "es"; MessagesFile: "compiler:Languages\Spanish.isl"
Name: "en"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "Crear un acceso directo en el escritorio"; GroupDescription: "Accesos directos:"
Name: "autostart"; Description: "Iniciar Arco al iniciar sesión en Windows"; GroupDescription: "Inicio:"

[Files]
Source: "..\dist\ArcoReloj\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExe}"
Name: "{group}\Desinstalar {#MyAppName}"; Filename: "{uninstallexe}"
Name: "{userdesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExe}"; Tasks: desktopicon

[Registry]
; Mismo valor que usa la casilla «Iniciar con Windows» de la app, así ambos quedan sincronizados.
Root: HKCU; Subkey: "Software\Microsoft\Windows\CurrentVersion\Run"; ValueType: string; ValueName: "{#MyRunKeyName}"; ValueData: """{app}\{#MyAppExe}"""; Tasks: autostart; Flags: uninsdeletevalue
Root: HKCU; Subkey: "Software\Microsoft\Windows\CurrentVersion\Run"; ValueName: "{#MyRunKeyName}"; Flags: uninsdeletevalue dontcreatekey

[Run]
Filename: "{app}\{#MyAppExe}"; Description: "Abrir Arco ahora"; Flags: nowait postinstall skipifsilent

[UninstallRun]
Filename: "{cmd}"; Parameters: "/C taskkill /IM {#MyAppExe} /F"; Flags: runhidden; RunOnceId: "KillArco"
