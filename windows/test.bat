@echo off
REM =====================================
REM AIO SSL Tool - Windows Test Script
REM Quick test without building
REM =====================================

echo.
echo =====================================
echo  AIO SSL Tool - Test Mode
echo =====================================
echo.

REM Check Python
python --version >nul 2>&1
if errorlevel 1 (
    echo [ERROR] Python not found
    exit /b 1
)

echo [OK] Python found
echo.

REM Check dependencies
echo Checking dependencies...
pip show customtkinter >nul 2>&1
if errorlevel 1 (
    echo [WARNING] customtkinter not installed
    echo Installing dependencies...
    pip install -r requirements.txt
)

echo [OK] Dependencies ready
echo.

REM Run the application
echo =====================================
echo  Starting AIO SSL Tool...
echo =====================================
echo.

python aio_ssl_tool.py

if errorlevel 1 (
    echo.
    echo [ERROR] Application exited with error
    pause
    exit /b 1
)

echo.
echo =====================================
echo  Application closed
echo =====================================
