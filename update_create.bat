@echo off
setlocal enabledelayedexpansion

REM === CONFIGURATION ===
set "REPO_URL=https://github.com/Ruyox/MindlessCreation.git"
set "BRANCH=main"
set "SCRIPT_NAME=update_create.bat"

REM === INITIALIZE GIT IF NEEDED ===
if not exist ".git" (
    echo Initializing local git repo...
    git init
    git remote add origin %REPO_URL%
    git fetch origin %BRANCH%
    git checkout -b %BRANCH%
)

REM === SETUP GIT LFS ===
echo Setting up Git LFS...
git lfs install

REM Track large file types (adjust as needed)
git lfs track "*.zip"
git lfs track "*.exe"
git lfs track "*.iso"
git lfs track "*.7z"
git lfs track "*.jar"

REM Commit .gitattributes if needed
git add .gitattributes
git commit -m "Configure Git LFS" 2>nul

REM === STAGE CHANGED FILES (EXCLUDING THE SCRIPT ITSELF) ===
echo Staging changed files...
for %%F in (*) do (
    if /I not "%%~nxF"=="%SCRIPT_NAME%" (
        git add "%%F"
    )
)

REM Stage deletions too
git add -A

REM === ONLY COMMIT IF THERE ARE CHANGES ===
git diff --cached --quiet
if errorlevel 1 (
    set /p "commitmsg=Enter commit message: "
    if "!commitmsg!"=="" set "commitmsg=Update files"
    git commit -m "!commitmsg!"
    echo Force pushing local state to GitHub...
    git push origin %BRANCH% --force
) else (
    echo No changes to commit. Nothing uploaded.
)

echo Done.
pause
