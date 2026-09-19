@echo off
setlocal
cd /d "%~dp0"
set "PATH=%USERPROFILE%\.local\bin;%PATH%"
call setup.bat
if errorlevel 1 (
  echo.
  echo Setup failed. See messages above.
  pause
  exit /b 1
)
uv sync -q --inexact 2>nul
uv run python -m backtalk.main
if errorlevel 1 pause
