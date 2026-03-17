@echo off
REM ============================================================
REM  fix_iis_auth.bat - Fix IIS app pool identity and SQL access
REM  Run as Administrator
REM ============================================================
SET APPCMD=%SystemRoot%\System32\inetsrv\appcmd.exe
SET POOL_NAME=SportsBetting

echo [1/3] Switching app pool to LocalSystem identity...
%APPCMD% set apppool "%POOL_NAME%" /processModel.identityType:LocalSystem

echo [2/3] Restarting app pool...
%APPCMD% stop apppool "%POOL_NAME%" >nul 2>&1
%APPCMD% start apppool "%POOL_NAME%"

echo [3/3] Resetting IIS...
iisreset /noforce

echo.
echo Done. App pool now runs as LocalSystem.
echo Next: run fix_sql_logins.sql in SSMS or via sqlcmd
