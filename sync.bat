@echo off
setlocal
cd /d "%~dp0"
if "%MC_NAME%"=="" set "MC_NAME=%COMPUTERNAME%"
git config user.name >nul 2>&1 || git config user.name "%MC_NAME%"
git config user.email >nul 2>&1 || git config user.email "%MC_NAME%@minecraft.local"
if exist HOST.lock del HOST.lock
git add -A
git commit -q -m "World update from %MC_NAME%" >nul 2>&1
set TRIES=0
:push
git push -q origin HEAD:main
if not errorlevel 1 (
    echo World uploaded. Everyone gets your changes next time they play.
    goto done
)
set /a TRIES+=1
if %TRIES% GEQ 5 (
    echo UPLOAD FAILED after 5 tries. Check your internet, then double-click sync.bat to retry.
    goto done
)
echo Upload failed, retrying in 10 seconds... (%TRIES%/5)
timeout /t 10 /nobreak >nul
git fetch -q origin main
git merge -q origin/main -m "Merge" >nul 2>&1 || (git merge --abort >nul 2>&1)
goto push
:done
if not "%~1"=="nopause" pause
