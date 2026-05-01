@echo off
setlocal enabledelayedexpansion

if "%~1"=="" (
    echo Usage: release.bat ^<version^>
    echo Example: release.bat 0.1.0
    exit /b 1
)

set "VERSION=%~1"
set "TAG=v%VERSION%"
set "SOURCE=%~dp0..\\"

echo === Releasing TerribleLuraHelper %VERSION% ===

rem D-08: push the CURRENT branch (not hardcoded main) so releases work from milestone/* branches.
for /f "tokens=* USEBACKQ" %%b in (`git -C "%SOURCE%" rev-parse --abbrev-ref HEAD`) do set "BRANCH=%%b"
if "!BRANCH!"=="" (
    echo ERROR: could not determine current branch.
    exit /b 1
)

git -C "%SOURCE%" tag -a "%TAG%" -m "Release %VERSION%"
if errorlevel 1 (
    echo ERROR: Tag creation failed.
    exit /b 1
)

git -C "%SOURCE%" push origin !BRANCH! "%TAG%"
if errorlevel 1 (
    echo ERROR: Push failed.
    exit /b 1
)

echo === Released %TAG% from branch !BRANCH! — GitHub Actions will handle packaging ===
