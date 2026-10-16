@echo off
REM xcnv / xconvert — launcher for the PowerShell version (Windows)
setlocal
set "HERE=%~dp0"

where pwsh >nul 2>&1
if %ERRORLEVEL%==0 (
    pwsh -NoProfile -ExecutionPolicy Bypass -File "%HERE%xcnv.ps1" %*
    exit /b %ERRORLEVEL%
)

where powershell >nul 2>&1
if %ERRORLEVEL%==0 (
    powershell -NoProfile -ExecutionPolicy Bypass -File "%HERE%xcnv.ps1" %*
    exit /b %ERRORLEVEL%
)

REM fallback: use the bash script if Git Bash / WSL bash is available
where bash >nul 2>&1
if %ERRORLEVEL%==0 (
    bash "%HERE%xcnv" %*
    exit /b %ERRORLEVEL%
)

echo Error: PowerShell or bash not found. Install PowerShell 7, or run xcnv.ps1 directly.
exit /b 1
