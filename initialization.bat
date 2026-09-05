@echo off
chcp 65001 >nul
setlocal DisableDelayedExpansion
title NTOU PPPoE Connection Helper

set "CONNECTION=寬頻連線"
set "CONFIG_FILE=%~dp0pppoe_config.json"
set "PS_EXE=%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe"
set "RASDIAL_EXE=%SystemRoot%\System32\rasdial.exe"

if /I "%~1"=="--connect" goto :QUICK_CONNECT

goto :MENU


:MENU
cls
echo.
echo ========================================
echo   NTOU PPPoE Connection Helper
echo ========================================
echo 1. Initial setup / Change account
echo 2. Connect using saved settings
echo 3. Generate quick-connect BAT only
echo 4. Exit
echo.
set "CHOICE="
set /p "CHOICE=Select [1-4]: "

if "%CHOICE%"=="1" goto :INITIAL_SETUP
if "%CHOICE%"=="2" goto :CONNECT_SAVED
if "%CHOICE%"=="3" goto :GENERATE_ONLY
if "%CHOICE%"=="4" goto :EXIT_APP

echo.
echo Invalid option. Please enter 1, 2, 3, or 4.
pause
goto :MENU


:INITIAL_SETUP
cls
echo.
echo ========================================
echo   Initial PPPoE Setup
echo ========================================
echo Connection name: "%CONNECTION%"
echo.

:ASK_USERNAME
set "NTOU_USER_INPUT="
set /p "NTOU_USER_INPUT=Username (需完整輸入，例如 12345678@hinet.net): "

"%PS_EXE%" -NoLogo -NoProfile -ExecutionPolicy Bypass -Command "if ($env:NTOU_USER_INPUT -is [string] -and $env:NTOU_USER_INPUT -match '^[A-Za-z0-9]+@hinet[.]net$') { exit 0 } else { exit 1 }"
if errorlevel 1 (
    echo.
    echo 帳號格式錯誤，如宿舍的規定帳號格式變成不是xxx@hinet.net，開issue或dc找我。
    echo.
    goto :ASK_USERNAME
)

:ASK_PASSWORD
set "NTOU_PASS_INPUT="
set /p "NTOU_PASS_INPUT=Password: "

"%PS_EXE%" -NoLogo -NoProfile -ExecutionPolicy Bypass -Command "if ($env:NTOU_PASS_INPUT -is [string] -and $env:NTOU_PASS_INPUT -match '^[A-Za-z0-9]+$') { exit 0 } else { exit 1 }"
if errorlevel 1 (
    echo.
    echo 密碼格式錯誤，如宿舍規定的密碼格式改成含有特殊符號，開issue或dc找我。
    echo.
    goto :ASK_PASSWORD
)

set "NTOU_CONFIG=%CONFIG_FILE%"

"%PS_EXE%" -NoLogo -NoProfile -ExecutionPolicy Bypass -Command "$ErrorActionPreference='Stop'; try { $obj=[PSCustomObject]@{username=$env:NTOU_USER_INPUT;password=$env:NTOU_PASS_INPUT}; $json=$obj | ConvertTo-Json; [IO.File]::WriteAllText($env:NTOU_CONFIG,$json,[Text.UTF8Encoding]::new($false)); exit 0 } catch { Write-Host ('Failed to save config: ' + $_.Exception.Message); exit 1 }"

if errorlevel 1 (
    echo.
    echo Failed to save settings.
    pause
    goto :MENU
)

set "NTOU_USER_INPUT="
set "NTOU_PASS_INPUT="

echo.
echo Settings saved.
echo JSON config: %CONFIG_FILE%

call :GENERATE_QUICK_BAT
echo.
pause
goto :MENU


:CONNECT_SAVED
set "NTOU_CONFIG=%CONFIG_FILE%"
call :DO_CONNECT
echo.
pause
goto :MENU


:GENERATE_ONLY
set "NTOU_CONFIG=%CONFIG_FILE%"

"%PS_EXE%" -NoLogo -NoProfile -ExecutionPolicy Bypass -Command "$ErrorActionPreference='Stop'; try { if(-not (Test-Path -LiteralPath $env:NTOU_CONFIG -PathType Leaf)) { exit 10 }; if([IO.Path]::GetExtension($env:NTOU_CONFIG) -ine '.json') { exit 11 }; $c=Get-Content -Raw -LiteralPath $env:NTOU_CONFIG | ConvertFrom-Json; if($c.username -isnot [string] -or $c.username -notmatch '^[A-Za-z0-9]+@hinet[.]net$') { exit 20 }; if($c.password -isnot [string] -or $c.password -notmatch '^[A-Za-z0-9]+$') { exit 21 }; exit 0 } catch { exit 22 }"

if errorlevel 1 (
    echo.
    echo No valid saved configuration found.
    echo Please choose option 1 first or fix pppoe_config.json.
    pause
    goto :MENU
)

call :GENERATE_QUICK_BAT
echo.
pause
goto :MENU


:GENERATE_QUICK_BAT
set "NTOU_MAIN=%~f0"

"%PS_EXE%" -NoLogo -NoProfile -ExecutionPolicy Bypass -Command "$ErrorActionPreference='Stop'; try { $desktop=[Environment]::GetFolderPath('Desktop'); if([string]::IsNullOrWhiteSpace($desktop)) { Write-Host 'Failed to locate Desktop.'; exit 31 }; $target=Join-Path $desktop 'ntou_pppoe.bat'; $lines=@('@echo off','chcp 65001 >nul',('call \"' + $env:NTOU_MAIN + '\" --connect %%*')); [IO.File]::WriteAllLines($target,$lines,[Text.UTF8Encoding]::new($false)); Write-Host ''; Write-Host ('Quick-connect BAT created on Desktop: ' + $target); exit 0 } catch { Write-Host ''; Write-Host ('Failed to create quick-connect BAT: ' + $_.Exception.Message); exit 31 }"

exit /b %ERRORLEVEL%


:QUICK_CONNECT
set "NTOU_CONFIG=%CONFIG_FILE%"
call :DO_CONNECT
set "RC=%ERRORLEVEL%"

if "%RC%"=="0" (
    "%SystemRoot%\System32\timeout.exe" /t 2 /nobreak >nul
    exit /b 0
)

echo.
pause
exit /b %RC%


:DO_CONNECT
if not exist "%NTOU_CONFIG%" (
    echo.
    echo [!] JSON config file not found:
    echo     %NTOU_CONFIG%
    exit /b 10
)

for %%F in ("%NTOU_CONFIG%") do (
    if /I not "%%~xF"==".json" (
        echo.
        echo [!] Only .json config files are accepted.
        exit /b 11
    )
)

"%RASDIAL_EXE%" | "%SystemRoot%\System32\findstr.exe" /I /C:"%CONNECTION%" >nul 2>&1
if not errorlevel 1 (
    echo.
    echo ========================================
    echo   NTOU PPPoE Connection Helper
    echo ========================================
    echo [+] Already connected.
    exit /b 0
)

set "NTOU_CONNECTION=%CONNECTION%"
set "NTOU_RASDIAL=%RASDIAL_EXE%"

"%PS_EXE%" -NoLogo -NoProfile -ExecutionPolicy Bypass -Command "$ErrorActionPreference='Stop'; try { $path=$env:NTOU_CONFIG; $c=Get-Content -Raw -LiteralPath $path | ConvertFrom-Json; $u=$c.username; $p=$c.password; if($u -isnot [string] -or $u -notmatch '^[A-Za-z0-9]+@hinet[.]net$') { Write-Host '[!] JSON rejected: invalid username format.'; exit 20 }; if($p -isnot [string] -or $p -notmatch '^[A-Za-z0-9]+$') { Write-Host '[!] JSON rejected: invalid password format.'; exit 21 }; Write-Host ''; Write-Host '========================================'; Write-Host '  NTOU PPPoE Connection Helper'; Write-Host '========================================'; Write-Host ('[*] Connection : ' + $env:NTOU_CONNECTION); Write-Host ('[*] Config     : ' + $path); Write-Host ('[*] Username   : ' + $u); Write-Host '[*] Connecting...'; Write-Host ''; & $env:NTOU_RASDIAL $env:NTOU_CONNECTION $u $p; $rc=$LASTEXITCODE; Write-Host ''; if($rc -eq 0) { Write-Host '[+] Connected successfully.'; exit 0 }; if($rc -eq 651) { Write-Host '[!] PPPoE connection failed with error 651.'; Write-Host '[!] Username/password validation passed.'; Write-Host '[!] Error 651 usually points to the PPPoE profile, WAN Miniport,'; Write-Host '    Ethernet link, or Windows Remote Access service.'; exit 651 }; Write-Host ('[!] Connection failed. rasdial error code: ' + $rc); exit $rc } catch { Write-Host ('[!] JSON rejected or connection failed: ' + $_.Exception.Message); exit 22 }"

exit /b %ERRORLEVEL%


:EXIT_APP
echo.
echo 你的離去是成功，還是對失敗的不挽留?
echo 如果弄完了就可以關掉了，掰掰
exit /b 0
