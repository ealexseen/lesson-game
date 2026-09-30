@echo off
rem LessonGame server journal in a separate window.
rem The server window can freeze its repainting (a click inside it pauses cmd),
rem so this window always shows what the server actually logged.
setlocal
cd /d "%~dp0"

rem UTF-8: the game writes Russian text as UTF-8, cmd defaults to cp866
chcp 65001 > nul
title LessonGame server journal

set "FOLDER=logs"
if not exist "%FOLDER%\server-*.log" (
	if exist "..\..\logs\server-*.log" set "FOLDER=..\..\logs"
)

if not exist "%FOLDER%\server-*.log" (
	echo.
	echo   No journal yet: start the server first ^(run_server.bat^).
	echo   The file appears as logs\server-YYYY-MM-DD.log next to the game.
	echo.
	pause
	exit /b 1
)

echo Watching %FOLDER%\server-*.log
echo Stop: Ctrl+C in this window ^(the server keeps running^).
echo.

powershell -NoProfile -ExecutionPolicy Bypass -Command ^
	"$f = Get-ChildItem '%FOLDER%\server-*.log' | Sort-Object LastWriteTime | Select-Object -Last 1; Write-Host ('Journal: ' + $f.FullName); Get-Content -LiteralPath $f.FullName -Encoding UTF8 -Wait"

echo.
pause
