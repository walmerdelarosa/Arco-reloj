@echo off
REM Abre Arco. La primera vez prepara el entorno (puede tardar unos minutos).
cd /d "%~dp0"
call "%~dp0_preparar.bat"
if errorlevel 1 goto fail
start "" "%~dp0.venv\Scripts\pythonw.exe" "%~dp0arco.py" %*
exit /b 0

:fail
echo.
echo Algo fallo. Copia el texto de arriba y envialo.
pause
exit /b 1
