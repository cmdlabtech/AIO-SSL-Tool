@echo off
REM =====================================
REM AIO SSL Tool - Windows Release Script
REM Creates versioned release builds
REM =====================================

setlocal enabledelayedexpansion

if "%~1"=="" (
    echo Usage: release.bat VERSION
    echo Example: release.bat 6.1.1
    exit /b 1
)

set VERSION=%~1
set VERSION_CLEAN=%VERSION:~0%

echo.
echo =====================================
echo  AIO SSL Tool - Windows Release
echo  Version: %VERSION%
echo =====================================
echo.

REM Validate version format (basic check)
echo %VERSION% | findstr /R "^[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*$" >nul
if errorlevel 1 (
    echo [ERROR] Invalid version format. Use X.Y.Z format
    echo Example: 6.1.1
    exit /b 1
)

REM Check if we're in the windows directory
if not exist aio_ssl_tool.py (
    echo [ERROR] Must run from windows directory
    exit /b 1
)

REM Build the executable
echo =====================================
echo  Step 1: Building executable...
echo =====================================
echo.

call build.bat
if errorlevel 1 (
    echo.
    echo [ERROR] Build failed
    exit /b 1
)

REM Create release directory structure
echo.
echo =====================================
echo  Step 2: Creating release package...
echo =====================================
echo.

set RELEASE_DIR=..\releases\Windows-v%VERSION%
set RELEASE_NAME=AIO-SSL-Tool-Windows-v%VERSION%.exe

if exist "%RELEASE_DIR%" (
    echo Cleaning existing release directory...
    rmdir /s /q "%RELEASE_DIR%"
)

mkdir "%RELEASE_DIR%"
if errorlevel 1 (
    echo [ERROR] Failed to create release directory
    exit /b 1
)

echo [OK] Release directory created: %RELEASE_DIR%

REM Copy executable with versioned name
echo.
echo Copying executable...
copy "dist\AIO-SSL-Tool-Windows.exe" "%RELEASE_DIR%\%RELEASE_NAME%"
if errorlevel 1 (
    echo [ERROR] Failed to copy executable
    exit /b 1
)

echo [OK] Executable copied: %RELEASE_NAME%

REM Create release notes
echo.
echo Creating release notes...

set NOTES_FILE=%RELEASE_DIR%\RELEASE_NOTES.md

(
    echo # AIO SSL Tool - Windows v%VERSION%
    echo.
    echo **Release Date:** %date%
    echo.
    echo ## Installation
    echo.
    echo Download and run `%RELEASE_NAME%`
    echo No installation required - this is a standalone executable.
    echo.
    echo ## Features
    echo.
    echo - Certificate chain building from Windows certificate store
    echo - CSR and private key generation ^(RSA/ECC^)
    echo - PFX/P12 file creation
    echo - Private key extraction from PFX files
    echo - Modern sidebar navigation interface
    echo.
    echo ## Requirements
    echo.
    echo - Windows 10 or later
    echo - No additional dependencies
    echo.
    echo ## Security
    echo.
    echo - Fully local processing - no network calls
    echo - AES-256 encryption for private keys
    echo - SHA-256 signature algorithms
    echo - NIST-compliant cryptographic standards
    echo.
    echo ## Changelog
    echo.
    echo See main CHANGELOG.md for full details.
    echo.
) > "%NOTES_FILE%"

echo [OK] Release notes created

REM Calculate file size
echo.
echo =====================================
echo  Release Summary
echo =====================================
echo.
echo Version: %VERSION%
echo File: %RELEASE_NAME%

for %%A in ("%RELEASE_DIR%\%RELEASE_NAME%") do (
    set size=%%~zA
    set /a sizeMB=!size! / 1048576
    echo Size: !sizeMB! MB
)

echo Location: %RELEASE_DIR%
echo.

REM Instructions
echo =====================================
echo  Next Steps
echo =====================================
echo.
echo 1. Test the executable:
echo    %RELEASE_DIR%\%RELEASE_NAME%
echo.
echo 2. Create GitHub Release:
echo    gh release create Windows-v%VERSION% "%RELEASE_DIR%\%RELEASE_NAME%" --title "Windows v%VERSION%"
echo.
echo 3. Update README.md download links
echo.
echo 4. Update appcast.xml if needed
echo.
echo =====================================
echo  Release Complete!
echo =====================================
echo.
