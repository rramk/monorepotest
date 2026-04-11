@echo off
setlocal EnableExtensions

rem ====================================================================
rem  Build the Liberty + JRE WiX v4 installer.
rem
rem  Prereqs:
rem    1. .NET SDK 6+ on PATH.
rem    2. WiX v4 tool installed globally:
rem         > dotnet tool install --global wix
rem    3. WiX v4 Util extension added globally (script auto-adds if missing):
rem         > wix extension add --global WixToolset.Util.wixext
rem    4. Liberty server package extracted into  staging\wlp
rem         > server package defaultServer --archive=liberty.zip --include=usr
rem         > unzip liberty.zip  (produces a top-level "wlp" folder)
rem    5. A private JRE extracted into           staging\jre
rem         (so that  staging\jre\bin\java.exe  exists)
rem
rem  Optional:
rem    set LIBERTY_SERVER_NAME=myServer   before running this script
rem    to override the server name passed to registerWinService.
rem ====================================================================

set "SCRIPT_DIR=%~dp0"
set "STAGING=%SCRIPT_DIR%staging"
set "BUILD=%SCRIPT_DIR%build"

if "%LIBERTY_SERVER_NAME%"=="" set "LIBERTY_SERVER_NAME=defaultServer"

if not exist "%STAGING%\wlp\bin\server.bat" (
    echo [ERROR] Liberty payload missing: %STAGING%\wlp\bin\server.bat not found.
    echo         Extract your "server package" archive so that wlp\ lives at that path.
    exit /b 1
)
if not exist "%STAGING%\jre\bin\java.exe" (
    echo [ERROR] JRE payload missing: %STAGING%\jre\bin\java.exe not found.
    exit /b 1
)

if not exist "%BUILD%" mkdir "%BUILD%"

rem -- Drop our server.env on top of the Liberty payload so Files harvests it.
if not exist "%STAGING%\wlp\etc" mkdir "%STAGING%\wlp\etc"
copy /Y "%SCRIPT_DIR%server.env" "%STAGING%\wlp\etc\server.env" >nul
if errorlevel 1 (
    echo [ERROR] Failed to stage server.env into %STAGING%\wlp\etc\server.env
    exit /b 1
)

rem -- Verify the wix tool is available.
wix --version >nul 2>&1
if errorlevel 1 (
    echo [ERROR] WiX v4 'wix' tool not found. Install with:
    echo         dotnet tool install --global wix
    exit /b 1
)

rem -- Ensure the Util extension is registered globally.
wix extension list --global 2>nul | findstr /C:"WixToolset.Util.wixext" >nul
if errorlevel 1 (
    echo [info] Adding WixToolset.Util.wixext globally...
    wix extension add --global WixToolset.Util.wixext || exit /b 1
)

echo [wix build] compiling and linking...
wix build ^
    -arch x64 ^
    -ext WixToolset.Util.wixext ^
    -bindpath "LibertySource=%STAGING%\wlp" ^
    -bindpath "JreSource=%STAGING%\jre" ^
    -d LibertyServerName=%LIBERTY_SERVER_NAME% ^
    -out "%BUILD%\LibertyServer.msi" ^
    "%SCRIPT_DIR%Package.wxs" || exit /b 1

echo.
echo [done]  %BUILD%\LibertyServer.msi
endlocal
