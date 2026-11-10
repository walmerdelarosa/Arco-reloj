; Instalador de Arco para Windows (Inno Setup 6).
; Se compila desde GitHub Actions (.github/workflows/release.yml) o con build_installer.bat.
; Requiere haber generado antes dist\ArcoReloj con PyInstaller.
; iscc /DMyAppVersion=1.4.0 installer\ArcoReloj.iss
;
; Firma de código (opcional): si se compila con /DSIGN y /Sarcosign=..., Inno firma el
; instalador y el desinstalador con ese comando (ver installer\sign.ps1 y docs\code-signing.es.md).

#ifndef MyAppVersion
  #define MyAppVersion "1.4.0"
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
AppPublisherURL=https://github.com/walmerdelarosa/Arco-reloj
VersionInfoVersion={#MyAppVersion}
VersionInfoProductName={#MyAppName}
VersionInfoDescription={#MyAppName} Setup
VersionInfoCompany=Arco
; {autopf}: «Archivos de programa» si se instala para todos los usuarios, o
; %LOCALAPPDATA%\Programs si se instala solo para el usuario actual. Antes se usaba siempre
; {localappdata}, y al instalar «para todos» los archivos quedaban en el perfil del administrador:
; los demás usuarios veían el acceso directo sin icono y la app no abría.
DefaultDirName={autopf}\ArcoReloj
; No reutilizar la carpeta de una instalación anterior «para todos» hecha con la 1.3 o antes
; (estaba en el perfil del administrador). Para instalaciones por usuario la ruta es la misma.
UsePreviousAppDir=no
DefaultGroupName={#MyAppName}
DisableProgramGroupPage=yes
; Por defecto, instalación por usuario (sin permisos de administrador). El diálogo permite
; elegir «para todos los usuarios», que instala en Archivos de programa.
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog commandline
UsedUserAreasWarning=no
OutputDir=..\dist
OutputBaseFilename=ArcoReloj-{#MyAppVersion}-setup
SetupIconFile=..\icon.ico
UninstallDisplayIcon={app}\{#MyAppExe}
Compression=lzma2/max
SolidCompression=yes
WizardStyle=modern
ShowLanguageDialog=auto
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
CloseApplications=yes
RestartApplications=no
#ifdef SIGN
SignTool=arcosign
SignedUninstaller=yes
#endif

[Languages]
Name: "en"; MessagesFile: "compiler:Default.isl"
Name: "es"; MessagesFile: "compiler:Languages\Spanish.isl"

[CustomMessages]
es.DesktopIcon=Crear un acceso directo en el escritorio
en.DesktopIcon=Create a desktop shortcut
es.Shortcuts=Accesos directos:
en.Shortcuts=Shortcuts:
es.AutoStart=Iniciar Arco al iniciar sesión en Windows
en.AutoStart=Start Arco when I sign in to Windows
es.StartupGroup=Inicio:
en.StartupGroup=Startup:
es.OpenNow=Abrir Arco ahora
en.OpenNow=Open Arco now
es.Uninstall=Desinstalar Arco Reloj
en.Uninstall=Uninstall Arco Clock

[Tasks]
Name: "desktopicon"; Description: "{cm:DesktopIcon}"; GroupDescription: "{cm:Shortcuts}"
Name: "autostart"; Description: "{cm:AutoStart}"; GroupDescription: "{cm:StartupGroup}"

[Files]
Source: "..\dist\ArcoReloj\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExe}"
Name: "{group}\{cm:Uninstall}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExe}"; Tasks: desktopicon

[Registry]
; HKA = HKCU si se instala para el usuario actual, HKLM si se instala para todos (así arranca
; al iniciar sesión cualquier usuario). La casilla «Iniciar con Windows» de la app lee ambos.
Root: HKA; Subkey: "Software\Microsoft\Windows\CurrentVersion\Run"; ValueType: string; ValueName: "{#MyRunKeyName}"; ValueData: """{app}\{#MyAppExe}"""; Tasks: autostart; Flags: uninsdeletevalue
Root: HKA; Subkey: "Software\Microsoft\Windows\CurrentVersion\Run"; ValueName: "{#MyRunKeyName}"; Flags: uninsdeletevalue dontcreatekey
; Valor que crea la propia app (siempre por usuario).
Root: HKCU; Subkey: "Software\Microsoft\Windows\CurrentVersion\Run"; ValueName: "{#MyRunKeyName}"; Flags: uninsdeletevalue dontcreatekey

[Run]
Filename: "{app}\{#MyAppExe}"; Description: "{cm:OpenNow}"; Flags: nowait postinstall skipifsilent

[UninstallRun]
Filename: "{cmd}"; Parameters: "/C taskkill /IM {#MyAppExe} /F"; Flags: runhidden; RunOnceId: "KillArco"
