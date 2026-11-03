@echo off
REM Igual que iniciar.bat, pero con consola visible para ver errores.
cd /d "%~dp0"
call "%~dp0_preparar.bat"
if errorlevel 1 goto end
"%~dp0.venv\Scripts\python.exe" "%~dp0arco.py" %*
:end
echo.
pause
