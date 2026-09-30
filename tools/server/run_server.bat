@echo off
rem LessonGame dedicated server (built game).
rem Put this launcher next to LessonGame.console.exe, edit server.cfg, double-click.
rem The window stays open so you can read the log. Ctrl+C or closing it stops the server.
setlocal
cd /d "%~dp0"

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
echo Settings: server.cfg next to this file ^(hints are inside^).
echo Stop: Ctrl+C in this window.
echo.

LessonGame.console.exe --headless -- --server
set "CODE=%ERRORLEVEL%"

echo.
echo Server stopped, code %CODE%.
pause
