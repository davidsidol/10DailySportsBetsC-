@echo off
REM ============================================================
REM  configure_iis.bat - Configure IIS site for Sports Betting
REM  Run as Administrator
REM ============================================================

SET SITE_NAME=SportsBetting
SET SITE_PORT=8090
SET SITE_PATH=C:\inetpub\sportsbetting
SET POOL_NAME=SportsBetting
SET APPCMD=%SystemRoot%\System32\inetsrv\appcmd.exe

echo === Configuring IIS for Sports Betting Dashboard ===
echo.

REM --- 1. Enable ASP feature ---
echo [1/6] Enabling ASP in IIS...
dism /online /enable-feature /featurename:IIS-ASP /all /NoRestart >nul 2>&1

REM --- 2. Create App Pool ---
echo [2/6] Creating Application Pool: %POOL_NAME%
%APPCMD% delete apppool "%POOL_NAME%" /commit:apphost >nul 2>&1
%APPCMD% add apppool /name:"%POOL_NAME%" /managedRuntimeVersion:"" /processModel.identityType:NetworkService

REM --- 3. Create the Website ---
echo [3/6] Creating IIS Site: %SITE_NAME% on port %SITE_PORT%
%APPCMD% delete site "%SITE_NAME%" /commit:apphost >nul 2>&1
%APPCMD% add site /name:"%SITE_NAME%" /physicalPath:"%SITE_PATH%" /bindings:"http/*:%SITE_PORT%:"
%APPCMD% set app "%SITE_NAME%/" /applicationPool:"%POOL_NAME%"

REM --- 4. Add index.asp as default document ---
echo [4/6] Setting default document to index.asp...
%APPCMD% set config "%SITE_NAME%" /section:defaultDocument /enabled:true /commit:apphost
%APPCMD% set config "%SITE_NAME%" /section:defaultDocument /+"files.[value='index.asp']" /commit:apphost

REM --- 5. Configure ASP settings ---
echo [5/6] Configuring ASP settings...
%APPCMD% set config "%SITE_NAME%" /section:asp /enableParentPaths:true /commit:apphost
%APPCMD% set config "%SITE_NAME%" /section:asp /scriptErrorSentToBrowser:true /commit:apphost

REM --- 6. Set directory permissions ---
echo [6/6] Setting directory permissions...
icacls "%SITE_PATH%" /grant "IIS_IUSRS:(OI)(CI)RX" /T /Q
icacls "%SITE_PATH%" /grant "IUSR:(OI)(CI)RX" /T /Q
icacls "%SITE_PATH%" /grant "NETWORK SERVICE:(OI)(CI)RX" /T /Q

echo.
echo === IIS Configuration Complete ===
echo Dashboard URL: http://localhost:%SITE_PORT%/
