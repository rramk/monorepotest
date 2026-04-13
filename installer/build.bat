@echo off
setlocal EnableExtensions

rem ====================================================================
rem  Build the Liberty + JRE WiX v3 installer.
rem
rem  Prereqs:
rem    1. WiX v3 toolset on PATH (candle.exe, light.exe, heat.exe).
rem    2. Liberty server package extracted into  staging\wlp
rem         > server package defaultServer --archive=liberty.zip --include=usr
rem         > unzip liberty.zip  (produces a top-level "wlp" folder)
rem    3. A private JRE extracted into           staging\jre
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

rem -- Drop our server.env on top of the Liberty payload so heat harvests it.
rem    Extracted zips often carry the read-only attribute, which causes
rem    copy /Y to fail silently.  Strip it first.
if not exist "%STAGING%\wlp\etc" mkdir "%STAGING%\wlp\etc"
if exist "%STAGING%\wlp\etc\server.env" attrib -R "%STAGING%\wlp\etc\server.env"
copy /Y "%SCRIPT_DIR%server.env" "%STAGING%\wlp\etc\server.env" >nul
if errorlevel 1 (
    echo [ERROR] Failed to stage server.env into %STAGING%\wlp\etc\server.env
    exit /b 1
)
rem -- Verify our JAVA_HOME line actually landed in the staged copy.
findstr /C:"JAVA_HOME" "%STAGING%\wlp\etc\server.env" >nul
if errorlevel 1 (
    echo [ERROR] server.env was staged but does not contain JAVA_HOME.
    exit /b 1
)

echo [heat]  harvesting Liberty tree...
heat dir "%STAGING%\wlp" ^
    -cg LibertyComponents ^
    -dr LIBERTYDIR ^
    -var var.LibertySource ^
    -gg -g1 -scom -sreg -srd -sfrag -ke -svb6 ^
    -nologo ^
    -out "%BUILD%\Liberty.wxs" || exit /b 1

echo [heat]  harvesting JRE tree...
heat dir "%STAGING%\jre" ^
    -cg JreComponents ^
    -dr JREDIR ^
    -var var.JreSource ^
    -gg -g1 -scom -sreg -srd -sfrag -ke -svb6 ^
    -nologo ^
    -out "%BUILD%\Jre.wxs" || exit /b 1

echo [candle] compiling...
candle -nologo -arch x64 ^
    -dLibertySource="%STAGING%\wlp" ^
    -dJreSource="%STAGING%\jre" ^
    -dLibertyServerName="%LIBERTY_SERVER_NAME%" ^
    -ext WixUtilExtension ^
    -out "%BUILD%\\" ^
    "%SCRIPT_DIR%Product.wxs" ^
    "%BUILD%\Liberty.wxs" ^
    "%BUILD%\Jre.wxs" || exit /b 1

echo [light]  linking...
light -nologo ^
    -ext WixUtilExtension ^
    -ext WixUIExtension ^
    -sice:ICE60 ^
    -b "%STAGING%\wlp" ^
    -b "%STAGING%\jre" ^
    -b "%SCRIPT_DIR%" ^
    -out "%BUILD%\LibertyServer.msi" ^
    "%BUILD%\Product.wixobj" ^
    "%BUILD%\Liberty.wixobj" ^
    "%BUILD%\Jre.wixobj" || exit /b 1

echo.
echo [done]  %BUILD%\LibertyServer.msi
endlocal
