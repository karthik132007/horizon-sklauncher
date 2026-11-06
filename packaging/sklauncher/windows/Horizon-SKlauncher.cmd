@echo off
setlocal EnableExtensions DisableDelayedExpansion
if not defined LOCALAPPDATA set "LOCALAPPDATA=%USERPROFILE%\AppData\Local"
if not defined HORIZON_LAUNCHER_HOME set "HORIZON_LAUNCHER_HOME=%LOCALAPPDATA%\Horizon-SKlauncher\launcher"
if not defined HORIZON_HOME set "HORIZON_HOME=%LOCALAPPDATA%\Horizon-SKlauncher\game"
set "HORIZON_LAUNCHER_NO_SELF_UPDATE=1"
set "HORIZON_TELEMETRY_URL=off"
if not exist "%HORIZON_LAUNCHER_HOME%" mkdir "%HORIZON_LAUNCHER_HOME%"
if not exist "%HORIZON_HOME%" mkdir "%HORIZON_HOME%"
if not exist "%HORIZON_LAUNCHER_HOME%\settings.json" (
  > "%HORIZON_LAUNCHER_HOME%\settings.json" echo {"desktop_entry":false,"install_new_versions":false,"skip_opening":true,"mods_auto_update":false}
)
cd /d "%HORIZON_HOME%"
if "%~1"=="" (
  start "" "%~dp0horizon-launcher.exe"
  exit /b 0
)
"%~dp0horizon-launcher.exe" %*
exit /b %errorlevel%
