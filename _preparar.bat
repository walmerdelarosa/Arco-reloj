@echo off
REM Prepara un entorno aislado (.venv) con una version de Python compatible con PySide6 (3.10-3.14).
REM Lo usan iniciar.bat y build_windows.bat; no hace falta ejecutarlo directamente.
cd /d "%~dp0"
set "VENV=%~dp0.venv"

if exist "%VENV%\Scripts\python.exe" (
  "%VENV%\Scripts\python.exe" -c "import PySide6" >nul 2>&1 && exit /b 0
)

where py >nul 2>&1
if errorlevel 1 (
  echo [X] No se encontro el lanzador "py" de Python.
  echo     Instala Python 3.13 desde https://www.python.org/downloads/windows/
  exit /b 1
)

echo Buscando Python compatible con PySide6 (3.10 a 3.14)...
set "PYV="
for %%v in (3.13 3.12 3.14 3.11 3.10) do (
  if not defined PYV (
    py -%%v -c "import sys" >nul 2>&1 && set "PYV=%%v"
  )
)

if not defined PYV (
  echo No hay Python 3.10-3.14 instalado ^(PySide6 aun no admite 3.15^).
  echo Instalando Python 3.13 junto a tu version actual...
  py install 3.13
  if errorlevel 1 winget install -e --id Python.Python.3.13 --accept-package-agreements --accept-source-agreements
  py -3.13 -c "import sys" >nul 2>&1 && set "PYV=3.13"
)

if not defined PYV (
  echo [X] No se pudo instalar Python 3.13 automaticamente.
  echo     Descargalo de https://www.python.org/downloads/windows/ y vuelve a intentarlo.
  exit /b 1
)

echo Usando Python %PYV%
if exist "%VENV%" rmdir /s /q "%VENV%"
py -%PYV% -m venv "%VENV%" || exit /b 1
"%VENV%\Scripts\python.exe" -m pip install --upgrade pip
"%VENV%\Scripts\python.exe" -m pip install -r requirements.txt || exit /b 1
exit /b 0
