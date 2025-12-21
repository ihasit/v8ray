@echo off
REM Post-build script for V8Ray (Windows)
REM This script runs after Flutter build to download Xray Core to the bundle directory

echo === V8Ray Post-Build Script ===

REM Get script directory
set SCRIPT_DIR=%~dp0
set PROJECT_ROOT=%SCRIPT_DIR%..

echo Project root: %PROJECT_ROOT%

REM Get build mode
set BUILD_MODE=%1
if "%BUILD_MODE%"=="" set BUILD_MODE=debug

echo Build mode: %BUILD_MODE%

REM Set bundle directory based on build mode
if "%BUILD_MODE%"=="release" (
    set BUNDLE_DIR=%PROJECT_ROOT%\app\build\windows\x64\runner\Release
) else (
    set BUNDLE_DIR=%PROJECT_ROOT%\app\build\windows\x64\runner\Debug
)

echo Bundle directory: %BUNDLE_DIR%

REM Create bin directory in bundle
set BIN_DIR=%BUNDLE_DIR%\bin
if not exist "%BIN_DIR%" (
    echo Creating bin directory: %BIN_DIR%
    mkdir "%BIN_DIR%"
)

REM Download Xray Core to build output directory
echo.
echo Step 1: Downloading Xray Core...
cd /d "%PROJECT_ROOT%\scripts"

REM Check if force update is requested
set FORCE_FLAG=
if "%2"=="--force-xray" (
    set FORCE_FLAG=--force
    echo Force update Xray Core enabled
)

dart download_xray.dart --build-mode %BUILD_MODE% %FORCE_FLAG%

if errorlevel 1 (
    echo Warning: Xray download via Dart script failed, trying alternative method...
    goto :try_alternative
)

goto :verify_xray

:try_alternative
REM Try to download xray using PowerShell if Dart script fails
echo.
echo Step 1b: Trying alternative download method...

REM Check if .xray_download_info exists
set INFO_FILE=%PROJECT_ROOT%\core\bin\.xray_download_info
if not exist "%INFO_FILE%" (
    echo Error: .xray_download_info not found. Please run cargo build first.
    exit /b 1
)

REM Parse download info using PowerShell
for /f "tokens=*" %%a in ('powershell -Command "(Get-Content '%INFO_FILE%' | ConvertFrom-Json).url"') do set XRAY_URL=%%a
for /f "tokens=*" %%a in ('powershell -Command "(Get-Content '%INFO_FILE%' | ConvertFrom-Json).binary_name"') do set XRAY_BINARY=%%a

echo Download URL: %XRAY_URL%
echo Binary name: %XRAY_BINARY%

REM Download and extract using PowerShell
set TEMP_ZIP=%BIN_DIR%\xray_temp.zip
echo Downloading to %TEMP_ZIP%...
powershell -Command "Invoke-WebRequest -Uri '%XRAY_URL%' -OutFile '%TEMP_ZIP%'"

if errorlevel 1 (
    echo Error: Failed to download Xray Core
    exit /b 1
)

echo Extracting Xray Core...
powershell -Command "Expand-Archive -Path '%TEMP_ZIP%' -DestinationPath '%BIN_DIR%' -Force"

if errorlevel 1 (
    echo Error: Failed to extract Xray Core
    del "%TEMP_ZIP%" 2>nul
    exit /b 1
)

REM Clean up temp file
del "%TEMP_ZIP%" 2>nul

:verify_xray
REM Verify Xray Core was downloaded
echo.
echo Step 2: Verifying Xray Core installation...

set XRAY_EXE=%BIN_DIR%\xray.exe
if exist "%XRAY_EXE%" (
    echo √ Xray Core found at: %XRAY_EXE%
) else (
    echo Warning: xray.exe not found at %XRAY_EXE%
    echo Checking for xray binary...
    dir "%BIN_DIR%" 2>nul
)

echo.
echo √ Post-build completed successfully
echo.
echo Bundle contents:
dir "%BUNDLE_DIR%" /b
echo.
echo Bin directory contents:
dir "%BIN_DIR%" /b 2>nul || echo (empty or does not exist)

