@echo off
setlocal EnableDelayedExpansion
cd /d "%~dp0"
set "PATH=%USERPROFILE%\.local\bin;%PATH%"

echo == backtalk setup ==

if not exist backtalk.json (
  copy /Y backtalk.json.example backtalk.json >nul
  echo -- created backtalk.json from the example
)

where claude >nul 2>&1
if errorlevel 1 (
  echo.
  echo !! Claude Code is not installed or not on PATH.
  echo    Install it first: https://claude.com/claude-code
  echo.
  exit /b 1
)

if not exist .venv\Scripts\python.exe (
  echo -- first install (downloads ~2GB once: packages + speech models)
  where uv >nul 2>&1
  if errorlevel 1 (
    echo -- installing uv
    powershell -NoProfile -ExecutionPolicy Bypass -Command "irm https://astral.sh/uv/install.ps1 | iex"
    set "PATH=%USERPROFILE%\.local\bin;%PATH%"
  )
  where espeak-ng >nul 2>&1
  if errorlevel 1 (
    echo -- installing espeak-ng
    winget install -e --id eSpeak-NG.eSpeak-NG --accept-package-agreements --accept-source-agreements
  )
  uv venv .venv
  uv pip install --python .venv\Scripts\python.exe -e .
  .venv\Scripts\python.exe -c "import warnings; warnings.filterwarnings('ignore'); from backtalk.ears import warm as w; from backtalk.mouth import warm as m; w(); m()"
) else (
  echo -- environment: already present
  uv sync -q --inexact 2>nul
)

echo == setup complete ==
exit /b 0
