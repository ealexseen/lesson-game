@echo off
rem LessonGame dedicated server (built game).
rem Double-click: this window shows the live server journal and Ctrl+C stops the server.
rem The game runs attached to this console, so closing the window stops it too.
setlocal
cd /d "%~dp0"

rem UTF-8: the game writes Russian text as UTF-8, cmd defaults to cp866
chcp 65001 > nul
title LessonGame dedicated server

if not exist "LessonGame.console.exe" (
	echo.
	echo   LessonGame.console.exe was not found next to this launcher.
	echo   Copy the launcher into the game folder ^(where LessonGame.exe lives^).
	echo   To run from the project sources use run_server_dev.bat instead.
	echo.
	pause
	exit /b 1
)

echo Starting LessonGame dedicated server...
echo Settings: server.cfg next to this file. Port is taken from that file.
echo The live journal is printed below; the same lines are saved to logs\.
echo Stop: Ctrl+C in this window ^(it stops the server too^).
echo.

rem /b keeps the game attached to this console window
start "" /b cmd /c ""%~dp0LessonGame.console.exe" --headless -- --server > nul 2>&1"

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0run_server.ps1"
set "CODE=%ERRORLEVEL%"

echo.
pause
exit /b %CODE%
