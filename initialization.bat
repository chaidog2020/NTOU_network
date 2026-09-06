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
echo 4. Install auto-connect BAT to Windows Startup
echo 5. Exit
echo.
set "CHOICE="
set /p "CHOICE=Select [1-5]: "

if "%CHOICE%"=="1" goto :INITIAL_SETUP
if "%CHOICE%"=="2" goto :CONNECT_SAVED
if "%CHOICE%"=="3" goto :GENERATE_ONLY
if "%CHOICE%"=="4" goto :INSTALL_STARTUP
if "%CHOICE%"=="5" goto :EXIT_APP

echo.
echo Invalid option. Please enter 1, 2, 3, 4, or 5.
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

"%PS_EXE%" -NoLogo -NoProfile -Command "if ($env:NTOU_USER_INPUT -is [string] -and $env:NTOU_USER_INPUT -match '^[A-Za-z0-9]+@hinet[.]net$') { exit 0 } else { exit 1 }"
if errorlevel 1 (
    echo.
    echo 帳號格式錯誤，如宿舍的規定帳號格式變成不是xxx@hinet.net，把source code的正則表達式刪掉就好。
    echo.
    goto :ASK_USERNAME
)

:ASK_PASSWORD
set "NTOU_PASS_INPUT="
set /p "NTOU_PASS_INPUT=Password: "

"%PS_EXE%" -NoLogo -NoProfile -Command "if ($env:NTOU_PASS_INPUT -is [string] -and $env:NTOU_PASS_INPUT -match '^[A-Za-z0-9]+$') { exit 0 } else { exit 1 }"
if errorlevel 1 (
    echo.
    echo 密碼格式錯誤，如宿舍規定的密碼格式改成含有特殊符號，把source code的正則表達式刪掉就好。
    echo.
    goto :ASK_PASSWORD
)

set "NTOU_CONFIG=%CONFIG_FILE%"

"%PS_EXE%" -NoLogo -NoProfile -Command "$ErrorActionPreference='Stop'; try { $obj=[PSCustomObject]@{username=$env:NTOU_USER_INPUT;password=$env:NTOU_PASS_INPUT}; $json=$obj | ConvertTo-Json; [IO.File]::WriteAllText($env:NTOU_CONFIG,$json,[Text.UTF8Encoding]::new($false)); exit 0 } catch { Write-Host ('Failed to save config: ' + $_.Exception.Message); exit 1 }"

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

"%PS_EXE%" -NoLogo -NoProfile -Command "$startup=[Environment]::GetFolderPath('Startup'); if([string]::IsNullOrWhiteSpace($startup)) { exit 1 }; $target=Join-Path $startup 'ntou_pppoe_startup.bat'; if(Test-Path -LiteralPath $target -PathType Leaf) { exit 0 } else { exit 1 }"
if not errorlevel 1 (
    echo.
    echo Existing Startup auto-connect detected. Updating credentials...
    call :GENERATE_STARTUP_BAT
)

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

"%PS_EXE%" -NoLogo -NoProfile -Command "$ErrorActionPreference='Stop'; try { if(-not (Test-Path -LiteralPath $env:NTOU_CONFIG -PathType Leaf)) { exit 10 }; if([IO.Path]::GetExtension($env:NTOU_CONFIG) -ine '.json') { exit 11 }; $c=Get-Content -Raw -LiteralPath $env:NTOU_CONFIG | ConvertFrom-Json; if($c.username -isnot [string] -or $c.username -notmatch '^[A-Za-z0-9]+@hinet[.]net$') { exit 20 }; if($c.password -isnot [string] -or $c.password -notmatch '^[A-Za-z0-9]+$') { exit 21 }; exit 0 } catch { exit 22 }"

if errorlevel 1 (
    echo.
    echo No valid saved configuration found.
    echo Please choose option 1 first or delete pppoe_config.json.
    pause
    goto :MENU
)

call :GENERATE_QUICK_BAT
echo.
pause
goto :MENU


:GENERATE_QUICK_BAT
set "NTOU_MAIN=%~f0"

"%PS_EXE%" -NoLogo -NoProfile -Command "$ErrorActionPreference='Stop'; try { $desktop=[Environment]::GetFolderPath('Desktop'); if([string]::IsNullOrWhiteSpace($desktop)) { Write-Host 'Failed to locate Desktop.'; exit 31 }; $target=Join-Path $desktop 'ntou_pppoe.bat'; $q=[char]34; $lines=@('@echo off','chcp 65001 >nul',('call ' + $q + $env:NTOU_MAIN + $q + ' --connect %*')); [IO.File]::WriteAllLines($target,$lines,[Text.UTF8Encoding]::new($false)); Write-Host ''; Write-Host ('Quick-connect BAT created on Desktop: ' + $target); exit 0 } catch { Write-Host ''; Write-Host ('Failed to create quick-connect BAT: ' + $_.Exception.Message); exit 31 }"

exit /b %ERRORLEVEL%


:INSTALL_STARTUP
set "NTOU_CONFIG=%CONFIG_FILE%"

"%PS_EXE%" -NoLogo -NoProfile -Command "$ErrorActionPreference='Stop'; try { if(-not (Test-Path -LiteralPath $env:NTOU_CONFIG -PathType Leaf)) { Write-Host 'No valid saved configuration found.'; exit 10 }; $c=Get-Content -Raw -LiteralPath $env:NTOU_CONFIG | ConvertFrom-Json; if($c.username -isnot [string] -or $c.username -notmatch '^[A-Za-z0-9]+@hinet[.]net$') { Write-Host 'Saved config JSON was rejected: invalid username format.'; exit 20 }; if($c.password -isnot [string] -or $c.password -notmatch '^[A-Za-z0-9]+$') { Write-Host 'Saved config JSON was rejected: invalid password format.'; exit 21 }; exit 0 } catch { Write-Host ('Saved config JSON was rejected: ' + $_.Exception.Message); exit 22 }"

if errorlevel 1 (
    echo.
    echo Please choose option 1 first or fix pppoe_config.json.
    pause
    goto :MENU
)

call :GENERATE_STARTUP_BAT
echo.
pause
goto :MENU


:GENERATE_STARTUP_BAT
set "NTOU_CONNECTION=%CONNECTION%"
set "NTOU_CONFIG=%CONFIG_FILE%"

"%PS_EXE%" -NoLogo -NoProfile -Command "$ErrorActionPreference='Stop'; try { $c=Get-Content -Raw -LiteralPath $env:NTOU_CONFIG | ConvertFrom-Json; $u=$c.username; $p=$c.password; $startup=[Environment]::GetFolderPath('Startup'); if([string]::IsNullOrWhiteSpace($startup)) { Write-Host 'Failed to locate Windows Startup folder.'; exit 40 }; if(-not (Test-Path -LiteralPath $startup -PathType Container)) { New-Item -ItemType Directory -Path $startup -Force | Out-Null }; $target=Join-Path $startup 'ntou_pppoe_startup.bat'; $q=[char]34; $connection=$env:NTOU_CONNECTION; $lines=@('@echo off','chcp 65001 >nul','setlocal DisableDelayedExpansion','title NTOU PPPoE Auto Connect','','set /a TRIES=0','set /a MAX_TRIES=6','',':RETRY',($q + '%SystemRoot%\System32\timeout.exe' + $q + ' /t 5 /nobreak >nul'),($q + '%SystemRoot%\System32\rasdial.exe' + $q + ' | ' + $q + '%SystemRoot%\System32\findstr.exe' + $q + ' /I /C:' + $q + $connection + $q + ' >nul 2>&1'),'if not errorlevel 1 exit /b 0','set /a TRIES+=1','',($q + '%SystemRoot%\System32\rasdial.exe' + $q + ' ' + $q + $connection + $q + ' ' + $q + $u + $q + ' ' + $q + $p + $q),'set "RC=%ERRORLEVEL%"','if "%RC%"=="0" exit /b 0','','if %TRIES% LSS %MAX_TRIES% goto :RETRY','','echo.','echo NTOU PPPoE auto-connect failed after %TRIES% attempts.','echo rasdial error code: %RC%','echo Startup BAT path:','echo     %~f0','echo.','echo Delete the BAT shown above if you want to disable this startup task.','echo.','pause','exit /b %RC%'); [IO.File]::WriteAllLines($target,$lines,[Text.UTF8Encoding]::new($false)); Write-Host ''; Write-Host 'Startup auto-connect installed/updated:'; Write-Host $target; Write-Host ''; Write-Host 'Username/password are stored directly inside this BAT.'; Write-Host 'To disable auto-connect later, delete the BAT above.'; exit 0 } catch { Write-Host ''; Write-Host ('Failed to create Startup BAT: ' + $_.Exception.Message); exit 40 }"

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
    echo JSON config file not found:
    echo %NTOU_CONFIG%
    exit /b 10
)

for %%F in ("%NTOU_CONFIG%") do (
    if /I not "%%~xF"==".json" (
        echo.
        echo Only .json config files are accepted.
        exit /b 11
    )
)

"%RASDIAL_EXE%" | "%SystemRoot%\System32\findstr.exe" /I /C:"%CONNECTION%" >nul 2>&1
if not errorlevel 1 (
    echo.
    echo ========================================
    echo   NTOU PPPoE Connection Helper
    echo ========================================
    echo Already connected.
    exit /b 0
)

set "NTOU_CONNECTION=%CONNECTION%"
set "NTOU_RASDIAL=%RASDIAL_EXE%"

"%PS_EXE%" -NoLogo -NoProfile -Command "$ErrorActionPreference='Stop'; try { $path=$env:NTOU_CONFIG; $c=Get-Content -Raw -LiteralPath $path | ConvertFrom-Json; $u=$c.username; $p=$c.password; if($u -isnot [string] -or $u -notmatch '^[A-Za-z0-9]+@hinet[.]net$') { Write-Host 'JSON rejected: invalid username format.'; exit 20 }; if($p -isnot [string] -or $p -notmatch '^[A-Za-z0-9]+$') { Write-Host 'JSON rejected: invalid password format.'; exit 21 }; Write-Host ''; Write-Host '========================================'; Write-Host '  NTOU PPPoE Connection Helper'; Write-Host '========================================'; Write-Host ('Connection : ' + $env:NTOU_CONNECTION); Write-Host ('Config     : ' + $path); Write-Host ('Username   : ' + $u); Write-Host 'Connecting...'; Write-Host ''; & $env:NTOU_RASDIAL $env:NTOU_CONNECTION $u $p; $rc=$LASTEXITCODE; Write-Host ''; if($rc -eq 0) { Write-Host 'Connected successfully.'; exit 0 }; if($rc -eq 651) { Write-Host 'PPPoE connection failed with error 651.'; Write-Host 'Username/password validation passed.'; Write-Host 'Error 651 usually points to the PPPoE profile, WAN Miniport,'; Write-Host '    Ethernet link, or Windows Remote Access service.'; exit 651 }; Write-Host ('Connection failed. rasdial error code: ' + $rc); exit $rc } catch { Write-Host ('JSON rejected or connection failed: ' + $_.Exception.Message); exit 22 }"

exit /b %ERRORLEVEL%


:EXIT_APP
echo.
echo There's nothing holding me back
exit /b 0
