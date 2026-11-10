@echo off
REM Crea el instalador dist\ArcoReloj-<version>-setup.exe en tu propio equipo.
REM Necesita Inno Setup 6 (https://jrsoftware.org/isdl.php). Lo normal es dejar que
REM GitHub Actions lo haga al publicar una etiqueta vX.Y.Z (ver README).
cd /d "%~dp0"
call "%~dp0_preparar.bat"
if errorlevel 1 goto fail
set "PY=%~dp0.venv\Scripts\python.exe"
for /f "tokens=2 delims==" %%v in ('findstr /b "__version__" arco.py') do set "VER=%%~v"
set "VER=%VER: =%"
set "VER=%VER:"=%"
"%PY%" -m pip install pyinstaller || goto fail
set "EXTRA="
if exist google_oauth.json set "EXTRA=--add-data google_oauth.json;."
"%PY%" installer\version_info.py %VER% version_info.txt || goto fail
"%PY%" -m PyInstaller --noconfirm --clean --windowed --noupx --name ArcoReloj --icon icon.ico --version-file version_info.txt --add-data "qml;qml" --add-data "icon.ico;." %EXTRA% arco.py || goto fail
if exist build rmdir /s /q build

set "ISCC=%ProgramFiles(x86)%\Inno Setup 6\ISCC.exe"
if not exist "%ISCC%" set "ISCC=%ProgramFiles%\Inno Setup 6\ISCC.exe"
if not exist "%ISCC%" (
  echo [X] No se encontro Inno Setup 6. Instalalo con:  winget install -e --id JRSoftware.InnoSetup
  goto fail
)
"%ISCC%" "/DMyAppVersion=%VER%" installer\ArcoReloj.iss || goto fail
echo.
echo Listo: dist\ArcoReloj-%VER%-setup.exe
explorer "%~dp0dist"
pause
exit /b 0

:fail
echo.
echo Algo fallo. Copia el texto de arriba y envialo.
pause
exit /b 1
