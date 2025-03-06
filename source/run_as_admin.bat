@echo off
REM Set UTF-8 encoding
chcp 65001 > nul

REM Name: run_as_admin.bat
REM Description: Run PowerShell script with administrator privileges
REM Author: Night Rain
REM Version: 1.0.5
REM Last Updated: 2024-03-05


REM Ensure running in script directory
cd /d "%~dp0"

REM Check and elevate administrator privileges if necessary
NET SESSION >nul 2>&1
if %ERRORLEVEL% neq 0 (
    echo 正在请求管理员权限...
    powershell -Command "Start-Process '%~dpnx0' -Verb RunAs"
    exit /b
)

echo 正在以管理员权限运行程序...
echo.

REM Run PowerShell script with elevated privileges
powershell -ExecutionPolicy Bypass -NoProfile -File "%~dp0set_process_priority.ps1"

echo [注意！]启动游戏后才能检测到反作弊进程

if %ERRORLEVEL% EQU 0 (
    echo.
    echo [成功] 已检测到进程并完成进程优先级和CPU亲和性设置
) else (
    echo.
    echo [警告] 部分设置可能未成功，详细信息请查看日志文件:只保留最近十次信息
)

echo.
echo 日志文件位置: %~dp0log.txt
echo.

REM Pause to show results
pause 