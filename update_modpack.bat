@echo off
setlocal enabledelayedexpansion

REM ========== CONFIG ==========
set OWNER=Ruyox
set REPO=MindlessCreation
set BRANCH=main

REM Set to 1 to enable deletion of local files not present in repo.
set "REMOVE_OBSOLETE=1"

REM If REMOVE_OBSOLETE=1 and DRY_RUN=1 -> script will only print what would be deleted.
REM Set DRY_RUN=0 to allow actual deletions (only used when REMOVE_OBSOLETE=1).
set "DRY_RUN=0"

REM Optional: GitHub personal access token
set "GITHUB_TOKEN="

REM Normalized list (always created)
set "DESIRED_LIST=repo_files.txt"
REM Raw repo list (only written when DRY_RUN=1)
set "REPO_LIST=repo_files_raw.txt"
REM ==============================

REM ===== SAFETY CHECK =====
if /I "%CD:~0,10%"=="%SystemRoot%" (
  echo ===========================================================
  echo  ERROR: Script is running inside system root!
  echo  This would corrupt your windows installation.
  echo.
  echo  Please do NOT run this script as administrator.
  echo  Instead, run it normally from your mods folder.
  echo ===========================================================
  echo.
  pause
  exit /b 1
)
REM ========================

set "REPO_URL=https://api.github.com/repos/%OWNER%/%REPO%/git/trees/%BRANCH%?recursive=1"

echo Fetching file list from %OWNER%/%REPO%@%BRANCH% ...

if defined GITHUB_TOKEN (
  powershell -NoProfile -Command "Invoke-RestMethod -Headers @{Authorization='token %GITHUB_TOKEN%'} -Uri '%REPO_URL%' | ForEach-Object { $_.tree } | ForEach-Object { $_.path }" > "%DESIRED_LIST%.tmp"
) else (
  powershell -NoProfile -Command "Invoke-RestMethod -Uri '%REPO_URL%' | ForEach-Object { $_.tree } | ForEach-Object { $_.path }" > "%DESIRED_LIST%.tmp"
)

if not exist "%DESIRED_LIST%.tmp" (
  echo ERROR: Could not fetch file list. Exiting.
  exit /b 1
)

REM If DRY_RUN=1, also keep the raw list as repo_files.txt
if "%DRY_RUN%"=="1" (
  move /Y "%DESIRED_LIST%.tmp" "%REPO_LIST%" >nul
  copy /Y "%REPO_LIST%" "%DESIRED_LIST%.tmp" >nul
) else (
  if exist "%REPO_LIST%" del "%REPO_LIST%" >nul 2>&1
)

REM Clear previous desired list
if exist "%DESIRED_LIST%" del /F /Q "%DESIRED_LIST%" 2>nul

REM Process each repo path: normalize, download, and append to desired list
for /F "usebackq delims=" %%p in ("%DESIRED_LIST%.tmp") do (
  call :download "%%p"
)

del "%DESIRED_LIST%.tmp" >nul 2>&1

REM Optionally remove obsolete local files
if "%REMOVE_OBSOLETE%"=="1" (
  echo(
  echo [INFO] REMOVE_OBSOLETE=1 - scanning for local files not in "%DESIRED_LIST%" ...
  call :remove_obsolete
) else (
  echo(
  echo [INFO] REMOVE_OBSOLETE=0 - no deletions performed.
)

REM Delete normalized list only in real run
if "%DRY_RUN%"=="0" (
    if exist "%DESIRED_LIST%" (
		echo([INFO] Deleting normalized list: "%DESIRED_LIST%"
		attrib -R "%DESIRED_LIST%" >nul 2>&1
		del /F /Q "%DESIRED_LIST%" >nul 2>&1
	)
)

echo(
echo Completed.
exit /b 0

:download
set "REPO_PATH=%~1"
set "LOCAL_PATH=!REPO_PATH:/=\!"

echo !LOCAL_PATH!>> "%DESIRED_LIST%"

if exist "!LOCAL_PATH!" (
  echo Skipping existing: !LOCAL_PATH!
  exit /b 0
)

set "RAW_URL=https://media.githubusercontent.com/media/%OWNER%/%REPO%/%BRANCH%/%REPO_PATH%"
set "RAW_URL=!RAW_URL: =%%20!"

echo Downloading: !LOCAL_PATH! ...
curl --fail --create-dirs --location --output "!LOCAL_PATH!" "!RAW_URL!"
if errorlevel 1 (
  echo ERROR: Failed to download "!RAW_URL!"
  if exist "!LOCAL_PATH!" del /F /Q "!LOCAL_PATH!" >nul 2>&1
  exit /b 1
)

findstr /B /C:"version https://git-lfs.github.com/spec/v1" "!LOCAL_PATH!" >nul
if !errorlevel! == 0 (
  echo WARNING: !LOCAL_PATH! is a Git LFS pointer.
)
exit /b 0

:remove_obsolete
set "ROOT=%CD%"
set "SELF=%~nx0"

REM Only protect repo list if in DRY_RUN
if "%DRY_RUN%"=="1" (
  set "PROTECT_REPO=%REPO_LIST%"
) else (
  set "PROTECT_REPO="
)

for /R "%ROOT%" %%F in (*) do (
  set "FULL=%%~fF"
  set "REL=!FULL:%ROOT%\=!"

  if /I "!REL!"=="!SELF!" (
    echo [INFO] Skipping self: !REL!
  ) else if /I "!REL!"=="%DESIRED_LIST%" (
    echo [INFO] Skipping desired list: !REL!
  ) else if /I "!REL!"=="!PROTECT_REPO!" (
    echo [INFO] Skipping repo list: !REL!
  ) else (
    findstr /I /X /C:"!REL!" "%DESIRED_LIST%" >nul || (
      if "%DRY_RUN%"=="1" (
        echo [DRY-RUN] Would delete: !FULL!
      ) else (
        echo [INFO] Deleting obsolete file: !FULL!
        del /F /Q "!FULL!" >nul 2>&1
      )
    )
  )
)

for /F "delims=" %%D in ('dir /AD /B /S ^| sort /R') do (
  rd "%%D" 2>nul
)

pause
exit /b 0