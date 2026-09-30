@echo off
rem LessonGame dedicated server from project sources (Godot editor binary).
rem Double-click to run the server with the settings from server.cfg in the project root.
setlocal
cd /d "%~dp0..\.."

set "GODOT=C:\Program Files\Godot_v4.6-stable_win64.exe\Godot_v4.6-stable_win64_console.exe"

if not exist "%GODOT%" (
	echo.
	echo   Godot console binary was not found:
	echo   %GODOT%
	echo   Fix the path in this file, or use a built game with run_server.bat.
	echo.
	pause
	exit /b 1
)

echo Starting LessonGame dedicated server from project sources...
echo Settings: server.cfg in the project root ^(created on first run with hints inside^).
echo Stop: Ctrl+C in this window.
echo.

"%GODOT%" --headless --path . -- --server
set "CODE=%ERRORLEVEL%"

echo.
echo Server stopped, code %CODE%.
pause
