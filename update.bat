@echo off
setlocal enabledelayedexpansion

set OWNER=Ruyox
set REPO=MindlessCreation
set BRANCH=main

set REPO_URL=https://api.github.com/repos/%OWNER%/%REPO%/git/trees/%BRANCH%?recursive=1

for /F "delims=" %%f in ('powershell -Command "Invoke-RestMethod -Uri '%REPO_URL%' | ForEach-Object { $_.tree } | ForEach-Object { $_.path }"') do (
    call :process "%%f"
)

goto :eof

:process
set "FILE=%~1"
set "URL=https://media.githubusercontent.com/media/%OWNER%/%REPO%/%BRANCH%/%FILE%"
set "URL=!URL: =%%20!"

if exist "%FILE%" (
    echo Skipping %FILE%
) else (
    echo Downloading %FILE% ...
    curl --create-dirs --output "%FILE%" "!URL!"
)
exit /b
