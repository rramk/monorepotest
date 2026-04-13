@echo off
rem ----------------------------------------------------------------
rem Write bootstrap.properties for Liberty variable substitution.
rem Called by the installer's deferred custom action after files are
rem laid down.  Liberty reads these key=value pairs at server start
rem and substitutes ${key} references in server.xml.
rem
rem Usage:  configure.bat <server-dir> <db-host> <db-port> <db-user> <db-password>
rem ----------------------------------------------------------------
set "SERVER_DIR=%~1"
(
echo db.serverName=%~2
echo db.portNumber=%~3
echo db.user=%~4
echo db.password=%~5
) > "%SERVER_DIR%\bootstrap.properties"
if errorlevel 1 (
    echo [configure] ERROR writing %SERVER_DIR%\bootstrap.properties
    exit /b 1
)
