@echo off
REM ============================================================
REM  build.bat - Build SportsBettingFetcher
REM  VS 2022 Community + vcpkg
REM ============================================================

SET VCPKG=C:\vcpkg
SET VCPKG_INC=%VCPKG%\installed\x64-windows\include
SET VCPKG_LIB=%VCPKG%\installed\x64-windows\lib
SET VSENV="C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Auxiliary\Build\vcvars64.bat"

echo [1/3] Initializing MSVC environment...
CALL %VSENV%
IF ERRORLEVEL 1 (
    echo ERROR: Could not initialize MSVC environment from %VSENV%
    exit /b 1
)

echo [2/3] Compiling main.cpp...
cl.exe /EHsc /O2 /std:c++17 ^
    /I"%VCPKG_INC%" ^
    main.cpp ^
    /link ^
    /LIBPATH:"%VCPKG_LIB%" ^
    libcurl.lib zlib.lib ^
    odbc32.lib odbccp32.lib ^
    Ws2_32.lib Wldap32.lib Crypt32.lib ^
    legacy_stdio_definitions.lib ^
    /OUT:SportsBettingFetcher.exe

IF ERRORLEVEL 1 (
    echo.
    echo BUILD FAILED - check errors above
    exit /b 1
)

echo [3/3] Build complete!
echo.
echo Output: C:\SportsBettingApp\SportsBettingFetcher.exe
echo.
echo Next steps:
echo   1. Edit main.cpp - set ODDS_API_KEY and verify DB_CONN_STR
echo   2. Run setup.sql in SSMS to create the database
echo   3. Run .\register_task.bat (as Admin) to schedule daily execution
echo   4. Run .\configure_iis.bat (as Admin) to set up the IIS site
