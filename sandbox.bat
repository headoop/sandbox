@echo off
REM Entwicklungs-Sandbox: Starthilfe fuer die Eingabeaufforderung.
REM Reicht alle Argumente an sandbox.ps1 weiter.
setlocal
where pwsh >nul 2>nul
if %ERRORLEVEL% EQU 0 (
    pwsh -NoProfile -ExecutionPolicy Bypass -File "%~dp0sandbox.ps1" %*
) else (
    powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0sandbox.ps1" %*
)
endlocal & exit /b %ERRORLEVEL%
