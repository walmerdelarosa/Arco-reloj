@echo off
REM Crea dist\ArcoReloj\ArcoReloj.exe usando el entorno compatible (.venv).
cd /d "%~dp0"
call "%~dp0_preparar.bat"
if errorlevel 1 goto fail
set "PY=%~dp0.venv\Scripts\python.exe"
"%PY%" -m pip install pyinstaller || goto fail
set "EXTRA="
if exist google_oauth.json set "EXTRA=--add-data google_oauth.json;."
"%PY%" -m PyInstaller --noconfirm --clean --windowed --name ArcoReloj --icon icon.ico --add-data "qml;qml" --add-data "icon.ico;." %EXTRA% arco.py || goto fail
REM La carpeta build\ es temporal y su .exe NO funciona: se borra para evitar confusiones.
if exist build rmdir /s /q build
echo.
echo Listo. Abre:  dist\ArcoReloj\ArcoReloj.exe
echo (Para moverla, copia la carpeta dist\ArcoReloj completa, no solo el .exe)
explorer "%~dp0dist\ArcoReloj"
pause
exit /b 0

:fail
echo.
echo Algo fallo. Copia el texto de arriba y envialo.
pause
exit /b 1
