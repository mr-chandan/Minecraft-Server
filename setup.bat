@echo off
setlocal
title Minecraft Server - one time setup
set "REPO=https://github.com/mr-chandan/Minecraft-Server.git"
set "DIR=%USERPROFILE%\MinecraftServer"

echo.
echo This installs everything needed and downloads the shared world.
echo It only needs to run once. You will be asked to sign in to GitHub in your browser.
echo.

where git >nul 2>&1
if errorlevel 1 (
    echo Installing Git...
    winget install -e --id Git.Git --silent --accept-source-agreements --accept-package-agreements
    set "PATH=%PATH%;%ProgramFiles%\Git\cmd"
)
where java >nul 2>&1
if errorlevel 1 (
    echo Installing Java 21...
    winget install -e --id Microsoft.OpenJDK.21 --silent --accept-source-agreements --accept-package-agreements
)
where git >nul 2>&1
if errorlevel 1 (
    echo Git did not install. Restart your PC and run this file again.
    pause & exit /b 1
)

if exist "%DIR%\play.bat" (
    echo Already set up in %DIR%
) else (
    git config --global core.longpaths true
    echo Downloading the server and world, this can take a few minutes...
    git clone "%REPO%" "%DIR%"
    if errorlevel 1 (
        echo.
        echo Download failed. Make sure you were added to the GitHub repo and try again.
        pause & exit /b 1
    )
)

set "DESKTOP=%USERPROFILE%\Desktop"
for /f "usebackq delims=" %%d in (`powershell -NoProfile -Command "[Environment]::GetFolderPath('Desktop')"`) do set "DESKTOP=%%d"
> "%DESKTOP%\Play Minecraft.bat" (
    echo @echo off
    echo cd /d "%DIR%"
    echo call play.bat
)
echo.
echo ===== DONE =====
echo A "Play Minecraft" file is now on your Desktop. Double-click it whenever you want to play.
echo If Java or Git were just installed, restart your PC once before playing.
pause
