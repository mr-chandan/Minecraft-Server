@echo off
REM Run from a temp copy so pulling a newer play.bat cannot corrupt this running script.
if /i not "%~dp0"=="%TEMP%\" (
    copy /y "%~f0" "%TEMP%\mc-play.bat" >nul
    set "MC_DIR=%~dp0"
    "%TEMP%\mc-play.bat"
    exit /b
)
setlocal EnableDelayedExpansion
cd /d "%MC_DIR%"
title Minecraft Server
if "%MC_NAME%"=="" set "MC_NAME=%COMPUTERNAME%"
set "NAME=%MC_NAME%"

REM ================= 0. Make sure Git and Java exist =================
set "PLAYIT=%ProgramFiles%\playit_gg\bin\playit.exe"
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
    "%PLAYIT%" start >nul 2>&1
    java -Xms1G -Xmx!XMX! -jar server.jar nogui
    "%PLAYIT%" stop >nul 2>&1
)

REM ================= 4. Upload =================
echo.
echo ===== [4/4] Uploading the world to GitHub =====
call "%MC_DIR%sync.bat" nopause
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
if not exist "%PLAYIT%" if not "%MC_DRYRUN%"=="1" (
    echo Installing the playit tunnel app, this takes a minute. Click Yes if Windows asks...
    winget install -e --id DevelopedMethods.playit --silent --accept-source-agreements --accept-package-agreements
    if not exist "%PLAYIT%" (echo playit install failed. Restart your PC and try again. & call :pause_exit 1)
)
exit /b 0

:ensure_address
if "%MC_DRYRUN%"=="1" (
    if not exist my-address.txt echo test.joinmc.link>my-address.txt
    exit /b 0
)
call :ensure_linked
call :ensure_tunnel
if exist my-address.txt exit /b 0
echo.
echo   Copy your tunnel address from the playit website. It is shown at the top of the tunnel page.
echo.
set "ADDR="
set /p ADDR=Paste the address here and press Enter:
if "!ADDR!"=="" (echo No address entered. & call :pause_exit 1)
echo !ADDR!>my-address.txt
exit /b 0

REM Link this PC to a playit account. Skipped when already linked.
:ensure_linked
"%PLAYIT%" start >nul 2>&1
timeout /t 2 /nobreak >nul
"%PLAYIT%" status 2>nul | findstr /c:"Secret configured: true" >nul
if not errorlevel 1 exit /b 0
echo.
echo ===== ONE-TIME SETUP: link this PC to playit (first time only) =====
echo.
echo   Your browser will open playit.gg in a moment.
echo   Sign in with Google, then click the Approve button.
echo   This window continues by itself once you have approved.
echo.
set "SETUPLOG=%TEMP%\playit-setup.txt"
del "%SETUPLOG%" >nul 2>&1
start "playit setup" /min cmd /c ""%PLAYIT%" setup > "%SETUPLOG%" 2>&1"
set "URL="
for /l %%i in (1,1,30) do (
    if not defined URL (
        timeout /t 1 /nobreak >nul
        if exist "%SETUPLOG%" for /f "tokens=*" %%u in ('findstr /b /i "https://playit.gg/claim" "%SETUPLOG%"') do set "URL=%%u"
    )
)
if defined URL (
    start "" "!URL!"
    echo   If the browser did not open, go to:  !URL!
) else (
    echo Could not get the sign-in link. Restart your PC and try again.
    call :pause_exit 1
)
set "LINKED="
for /l %%i in (1,1,120) do (
    if not defined LINKED (
        timeout /t 5 /nobreak >nul
        "%PLAYIT%" status 2>nul | findstr /c:"Secret configured: true" >nul && set "LINKED=1"
    )
)
if not defined LINKED (
    echo Timed out waiting for approval. Run Play Minecraft again.
    call :pause_exit 1
)
echo   Linked.
timeout /t 5 /nobreak >nul
exit /b 0

REM Make sure at least one tunnel is attached to this PC.
:ensure_tunnel
call :tunnel_count
if not "!TCOUNT!"=="0" exit /b 0
echo.
echo ===== ONE-TIME SETUP: create your tunnel =====
echo.
echo   This PC has no tunnel yet. Your browser will open the playit tunnels page.
echo     1. Click "Create tunnel" (or "Add tunnel").
echo     2. Choose "Minecraft Java". Make sure the agent is THIS PC. Click Add.
echo     3. Come back here and press a key.
echo.
del my-address.txt >nul 2>&1
start "" "https://playit.gg/account/tunnels"
pause
"%PLAYIT%" stop >nul 2>&1
"%PLAYIT%" start >nul 2>&1
timeout /t 8 /nobreak >nul
goto ensure_tunnel

:tunnel_count
set "TCOUNT=x"
for /f "usebackq delims=" %%c in (`powershell -NoProfile -Command "$m = (Select-String -Path ($env:ProgramData + '\playit_gg\logs\playitd.log') -Pattern ' tunnel_count=(\d+)'); if ($m) { @($m)[-1].Matches[0].Groups[1].Value } else { 'x' }"`) do set "TCOUNT=%%c"
exit /b 0

:ram
set "XMX=2G"
set "GB="
for /f "usebackq delims=" %%m in (`powershell -NoProfile -Command "[math]::Floor((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory/1GB)"`) do set "GB=%%m"
if defined GB (
    if !GB! GEQ 16 set "XMX=6G"
    if !GB! LSS 16 set "XMX=4G"
    if !GB! LSS 8 set "XMX=2G"
    if !GB! LSS 4 set "XMX=1G"
)
exit /b 0

:pause_exit
if not "%MC_DRYRUN%"=="1" pause
exit %1
