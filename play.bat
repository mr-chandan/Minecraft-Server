@echo off
setlocal EnableDelayedExpansion
cd /d "%~dp0"
title Minecraft Server
if "%MC_NAME%"=="" set "MC_NAME=%COMPUTERNAME%"
set "NAME=%MC_NAME%"

REM ================= 0. Make sure Git and Java exist =================
call :ensure_tools
if errorlevel 1 exit /b 1

git config user.name >nul 2>&1 || git config user.name "%NAME%"
git config user.email >nul 2>&1 || git config user.email "%NAME%@minecraft.local"

REM ================= 1. Get the latest world =================
echo.
echo ===== [1/4] Getting the latest world from GitHub =====
git fetch origin main
if errorlevel 1 (
    echo.
    echo Could not reach GitHub. Check your internet and try again.
    call :pause_exit 1
)

REM Save work from a session that crashed or was closed with the X.
set "CHANGES="
for /f "delims=" %%i in ('git status --porcelain') do set "CHANGES=1"
if defined CHANGES (
    echo Found unsynced changes from a previous session on this PC, saving them first...
    git add -A
    git commit -q -m "Recovered unsynced session on %NAME%"
)
git merge -q origin/main -m "Merge latest world" >nul 2>&1
if errorlevel 1 (
    echo Your copy and GitHub have diverged. Backing up your copy and taking GitHub's version.
    git merge --abort >nul 2>&1
    set "BK=%USERPROFILE%\MinecraftServer-backup-%RANDOM%"
    xcopy /e /i /q world "!BK!\world" >nul
    echo Backup saved to !BK!
    git reset -q --hard origin/main
)

REM ================= 2. Is someone already hosting? =================
echo.
echo ===== [2/4] Checking if someone is already hosting =====
:checklock
if exist HOST.lock (
    for /f "usebackq tokens=1,2 delims=|" %%a in ("HOST.lock") do (
        set "HOSTER=%%a"
        set "HOSTADDR=%%b"
    )
    if /i not "!HOSTER!"=="%NAME%" (
        echo.
        echo   !HOSTER! is already hosting the server.
        echo   Open Minecraft ^> Multiplayer ^> Direct Connect and join:
        echo.
        echo       !HOSTADDR!
        echo.
        echo   If !HOSTER! is NOT actually playing, ask them to run sync.bat.
        call :pause_exit 0
    )
)

call :ensure_address
if errorlevel 1 exit /b 1
set /p ADDRESS=<my-address.txt

>HOST.lock echo %NAME%^|%ADDRESS%
git add HOST.lock
git commit -q -m "%NAME% started hosting"
git push -q origin HEAD:main
if errorlevel 1 (
    echo Someone else just started hosting a moment ago, re-checking...
    git fetch -q origin main
    git reset -q --hard origin/main
    goto checklock
)

REM ================= 3. Run tunnel + server =================
echo.
echo ===== [3/4] Starting tunnel and server =====
call :ram
echo.
echo   Friends join at:   %ADDRESS%
echo   You join at:       localhost
echo   Server RAM:        !XMX!
echo.
echo   When you are done, type   stop   in this window and press Enter.
echo   Do NOT close the window with the X, or your progress will not be uploaded.
echo.
if "%MC_DRYRUN%"=="1" (
    echo [dry run] would start playit and java here
    echo dry-run-%RANDOM%>world\dryrun.txt
) else (
    start "playit tunnel" /min playit.exe
    java -Xms1G -Xmx!XMX! -jar server.jar nogui
    taskkill /f /im playit.exe >nul 2>&1
)

REM ================= 4. Upload =================
echo.
echo ===== [4/4] Uploading the world to GitHub =====
call sync.bat nopause
call :pause_exit 0

REM ---------------- helpers ----------------
:ensure_tools
where git >nul 2>&1
if errorlevel 1 (
    echo Git is not installed. Installing it now, this takes a minute...
    winget install -e --id Git.Git --silent --accept-source-agreements --accept-package-agreements
    set "PATH=%PATH%;%ProgramFiles%\Git\cmd"
    where git >nul 2>&1 || (echo Git install failed. Restart your PC and try again. & call :pause_exit 1)
)
where java >nul 2>&1
if errorlevel 1 (
    echo Java is not installed. Installing it now, this takes a minute...
    winget install -e --id Microsoft.OpenJDK.21 --silent --accept-source-agreements --accept-package-agreements
    for /d %%d in ("%ProgramFiles%\Microsoft\jdk-21*") do set "PATH=!PATH!;%%~d\bin"
    where java >nul 2>&1 || (echo Java install failed. Restart your PC and try again. & call :pause_exit 1)
)
if not exist playit.exe if not "%MC_DRYRUN%"=="1" (
    echo Downloading the playit tunnel...
    curl -L -s -o playit.exe https://github.com/playit-cloud/playit-agent/releases/latest/download/playit-windows-x86_64.exe
    if not exist playit.exe (echo Could not download playit. Check internet. & call :pause_exit 1)
)
exit /b 0

:ensure_address
if exist my-address.txt exit /b 0
if "%MC_DRYRUN%"=="1" (
    echo test.joinmc.link>my-address.txt
    exit /b 0
)
echo.
echo ===== ONE-TIME TUNNEL SETUP (only the first time you host) =====
echo.
echo   1. A playit window will open and show a link like https://playit.gg/claim/xxxx
echo   2. Open that link, sign in with Google, click "Add agent".
echo   3. On the playit website click "Create tunnel", choose "Minecraft Java", click Add.
echo   4. Copy the address it shows, something like  xxxx.joinmc.link
echo.
start "playit tunnel" playit.exe
set "ADDR="
set /p ADDR=Paste that address here and press Enter:
taskkill /f /im playit.exe >nul 2>&1
if "!ADDR!"=="" (echo No address entered. & call :pause_exit 1)
echo !ADDR!>my-address.txt
exit /b 0

:ram
set "XMX=2G"
for /f "skip=1 tokens=1" %%m in ('wmic computersystem get TotalPhysicalMemory 2^>nul') do if not "%%m"=="" set "TOTAL=%%m"
if defined TOTAL (
    set /a GB=!TOTAL:~0,-9! 2>nul
    if !GB! GEQ 16 set "XMX=6G"
    if !GB! LSS 16 set "XMX=4G"
    if !GB! LSS 8 set "XMX=2G"
    if !GB! LSS 4 set "XMX=1G"
)
exit /b 0

:pause_exit
if not "%MC_DRYRUN%"=="1" pause
exit %1
