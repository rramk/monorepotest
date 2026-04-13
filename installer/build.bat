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
rem  Optional (set before running):
rem    LIBERTY_SERVER_NAME  - server name (default: defaultServer)
rem    SIGN_CERT_THUMBPRINT - SHA-1 thumbprint of a code-signing cert
rem                           in the Windows certificate store
rem    SIGN_PFX_PATH        - path to a .pfx code-signing certificate
rem    SIGN_PFX_PASSWORD    - password for the .pfx file
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

rem ====================================================================
rem  Stage installer-managed files into the Liberty payload so heat
rem  harvests them as regular components.
rem  Extracted zips often carry the read-only attribute, which causes
rem  copy /Y to fail silently.  Strip it first on every target.
rem ====================================================================

rem -- server.env  (sets JAVA_HOME to the bundled JRE)
if not exist "%STAGING%\wlp\etc" mkdir "%STAGING%\wlp\etc"
if exist "%STAGING%\wlp\etc\server.env" attrib -R "%STAGING%\wlp\etc\server.env"
copy /Y "%SCRIPT_DIR%server.env" "%STAGING%\wlp\etc\server.env" >nul
if errorlevel 1 (
    echo [ERROR] Failed to stage server.env
    exit /b 1
)
findstr /C:"JAVA_HOME" "%STAGING%\wlp\etc\server.env" >nul
if errorlevel 1 (
    echo [ERROR] server.env was staged but does not contain JAVA_HOME.
    exit /b 1
)

rem -- configure.bat  (writes bootstrap.properties at install time)
if exist "%STAGING%\wlp\etc\configure.bat" attrib -R "%STAGING%\wlp\etc\configure.bat"
copy /Y "%SCRIPT_DIR%configure.bat" "%STAGING%\wlp\etc\configure.bat" >nul
if errorlevel 1 (
    echo [ERROR] Failed to stage configure.bat
    exit /b 1
)

rem -- server.xml  (Liberty server configuration with ${variable} refs)
set "SERVER_DIR=%STAGING%\wlp\usr\servers\%LIBERTY_SERVER_NAME%"
if not exist "%SERVER_DIR%" mkdir "%SERVER_DIR%"
if exist "%SERVER_DIR%\server.xml" attrib -R "%SERVER_DIR%\server.xml"
copy /Y "%SCRIPT_DIR%server.xml" "%SERVER_DIR%\server.xml" >nul
if errorlevel 1 (
    echo [ERROR] Failed to stage server.xml
    exit /b 1
)

rem ====================================================================
rem  Harvest, compile, link
rem ====================================================================

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

rem ====================================================================
rem  Code signing (optional)
rem
rem  Uses signtool.exe from the Windows SDK.  Set one of the following
rem  environment variables before running this script:
rem
rem    SIGN_CERT_THUMBPRINT  - SHA-1 thumbprint of a certificate in the
rem                            local machine or current-user cert store.
rem    SIGN_PFX_PATH         - path to a .pfx (PKCS #12) file.
rem                            Also set SIGN_PFX_PASSWORD if encrypted.
rem
rem  The timestamp server below (DigiCert) is a placeholder; replace it
rem  with whatever your CA provides.
rem ====================================================================
if defined SIGN_CERT_THUMBPRINT (
    echo [sign]  signing MSI with cert thumbprint %SIGN_CERT_THUMBPRINT%...
    signtool sign ^
        /sha1 %SIGN_CERT_THUMBPRINT% ^
        /fd sha256 ^
        /tr http://timestamp.digicert.com /td sha256 ^
        /d "$(var.ProductName)" ^
        "%BUILD%\LibertyServer.msi" || exit /b 1
    echo [sign]  verifying signature...
    signtool verify /pa "%BUILD%\LibertyServer.msi" || exit /b 1
) else if defined SIGN_PFX_PATH (
    echo [sign]  signing MSI with PFX %SIGN_PFX_PATH%...
    signtool sign ^
        /f "%SIGN_PFX_PATH%" ^
        /p "%SIGN_PFX_PASSWORD%" ^
        /fd sha256 ^
        /tr http://timestamp.digicert.com /td sha256 ^
        /d "$(var.ProductName)" ^
        "%BUILD%\LibertyServer.msi" || exit /b 1
    echo [sign]  verifying signature...
    signtool verify /pa "%BUILD%\LibertyServer.msi" || exit /b 1
) else (
    echo [sign]  SKIPPED - set SIGN_CERT_THUMBPRINT or SIGN_PFX_PATH to enable.
)

echo.
echo [done]  %BUILD%\LibertyServer.msi
endlocal
