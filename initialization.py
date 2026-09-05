from pathlib import Path
import ctypes
import json
import re
import subprocess
import sys

BASE_DIR = Path(__file__).resolve().parent
CONFIG_FILE = BASE_DIR / "pppoe_config.json"

CONNECTION_NAME = "寬頻連線"

# 如果之後這份python壞了，可以先檢查這裡，因為我的正則表達式規定帳號要以@hinet.net結尾，並且只能有純英文/數字
USERNAME_RE = re.compile(r"^[A-Za-z0-9]+@hinet\.net$")
PASSWORD_RE = re.compile(r"^[A-Za-z0-9]+$")


def get_desktop_path():
    if sys.platform == "win32":
        try:
            buf = ctypes.create_unicode_buffer(260)
            result = ctypes.windll.shell32.SHGetFolderPathW(
                None, 0x10, None, 0, buf
            )
            if result == 0 and buf.value:
                return Path(buf.value)
        except Exception:
            pass

    return Path.home() / "Desktop"


BAT_FILE = get_desktop_path() / "ntou_pppoe.bat"


def validate_username(username):
    return isinstance(username, str) and USERNAME_RE.fullmatch(username) is not None


def validate_password(password):
    return isinstance(password, str) and PASSWORD_RE.fullmatch(password) is not None


def validate_config_data(data):
    if not isinstance(data, dict):
        return False, "JSON root must be an object."

    username = data.get("username")
    password = data.get("password")

    if not validate_username(username):
        return (
            False,
            "帳號格式錯誤，如宿舍的規定帳號格式變成不是xxx@hinet.net，開issue或dc找我。"
        )

    if not validate_password(password):
        return (
            False,
            "密碼格式錯誤，如宿舍規定的密碼格式改成含有特殊符號，開issue或dc找我。"
        )

    return True, None


def load_config():
    if not CONFIG_FILE.exists():
        return None

    try:
        with CONFIG_FILE.open("r", encoding="utf-8") as f:
            data = json.load(f)
    except (json.JSONDecodeError, OSError) as e:
        print(f"Failed to read config JSON: {e}")
        return None

    valid, reason = validate_config_data(data)
    if not valid:
        print(f"Saved config JSON was rejected: {reason}")
        return None

    return data


def save_config(username, password):
    data = {
        "username": username,
        "password": password,
    }

    valid, reason = validate_config_data(data)
    if not valid:
        raise ValueError(reason)

    with CONFIG_FILE.open("w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=2)

    return data


def escape_bat_value(value):
    return str(value).replace("%", "%%")


def generate_bat():
    default_config = escape_bat_value(CONFIG_FILE)

    bat_content = f'''@echo off
chcp 65001 >nul
setlocal DisableDelayedExpansion
title NTOU PPPoE Connection Helper

set "CONNECTION={CONNECTION_NAME}"
set "NTOU_CONNECTION={CONNECTION_NAME}"
set "DEFAULT_CONFIG={default_config}"

rem ------------------------------------------------------------
rem Config selection
rem Double-click: use the default pppoe_config.json
rem Drag a .json file onto this BAT: validate and use that file
rem ------------------------------------------------------------
if "%~1"=="" (
    set "CONFIG=%DEFAULT_CONFIG%"
) else (
    set "CONFIG=%~1"
)

if not exist "%CONFIG%" (
    echo.
    echo [!] JSON config file not found:
    echo     %CONFIG%
    echo.
    pause
    exit /b 10
)

for %%F in ("%CONFIG%") do (
    if /I not "%%~xF"==".json" (
        echo.
        echo [!] Only .json config files are accepted.
        echo.
        pause
        exit /b 11
    )
)

set "NTOU_CONFIG=%CONFIG%"

echo.
echo ========================================
echo   NTOU PPPoE Connection Helper
echo ========================================
echo.
echo [*] Connection : %CONNECTION%
echo [*] Config     : %CONFIG%
echo.

rem Check whether this PPPoE connection is already active.
"%SystemRoot%\\System32\\rasdial.exe" | "%SystemRoot%\\System32\\findstr.exe" /I /C:"%CONNECTION%" >nul 2>&1
if not errorlevel 1 (
    echo [+] Already connected.
    "%SystemRoot%\\System32\\timeout.exe" /t 2 /nobreak >nul
    exit /b 0
)

echo [*] Reading and validating JSON...
echo.

rem Security rules:
rem   Username: local part = A-Z / a-z / 0-9 only, exact suffix = @hinet.net
rem   Password: A-Z / a-z / 0-9 only
rem Credentials are passed directly from PowerShell to rasdial.
rem They are NOT expanded as BAT commands.
"%SystemRoot%\\System32\\WindowsPowerShell\\v1.0\\powershell.exe" -NoLogo -NoProfile -Command "$ErrorActionPreference='Stop'; try {{ $c=Get-Content -Raw -LiteralPath $env:NTOU_CONFIG | ConvertFrom-Json; $u=$c.username; $p=$c.password; if($u -isnot [string] -or $u -notmatch '^[A-Za-z0-9]+@hinet[.]net$') {{ Write-Host '[!] JSON rejected: invalid username format.'; exit 20 }}; if($p -isnot [string] -or $p -notmatch '^[A-Za-z0-9]+$') {{ Write-Host '[!] JSON rejected: invalid password format.'; exit 21 }}; Write-Host ('[*] Username   : ' + $u); Write-Host '[*] Connecting...'; Write-Host ''; & ($env:SystemRoot + '\\System32\\rasdial.exe') $env:NTOU_CONNECTION $u $p; exit $LASTEXITCODE }} catch {{ Write-Host ('[!] JSON rejected: ' + $_.Exception.Message); exit 22 }}"

set "RC=%ERRORLEVEL%"

if "%RC%"=="0" (
    echo.
    echo [+] Connected successfully.
    "%SystemRoot%\\System32\\timeout.exe" /t 2 /nobreak >nul
    exit /b 0
)

if "%RC%"=="20" (
    echo.
    echo [!] Username validation failed.
    echo [!] Required format: letters/numbers + @hinet.net
    pause
    exit /b 20
)

if "%RC%"=="21" (
    echo.
    echo [!] Password validation failed.
    echo [!] Password may contain only English letters and numbers.
    pause
    exit /b 21
)

if "%RC%"=="22" (
    echo.
    echo [!] Invalid or unreadable JSON file.
    pause
    exit /b 22
)

echo.
if "%RC%"=="651" (
    echo [!] PPPoE connection failed with error 651.
    echo [!] Username/password validation passed.
    echo [!] Error 651 usually points to the PPPoE profile, WAN Miniport,
    echo     Ethernet link, or Windows Remote Access service.
) else (
    echo [!] Connection failed. rasdial error code: %RC%
)
echo.
pause
exit /b %RC%
'''

    # Important: write WITHOUT UTF-8 BOM.
    # A BOM can make cmd.exe fail to parse the first "@echo off" correctly.
    BAT_FILE.write_text(bat_content, encoding="utf-8")
    return BAT_FILE


def input_username():
    while True:
        username = input(
            "Username (需完整輸入，例如 12345678@hinet.net，詳見宿舍網路說明，帳密通常在電梯對面的公布欄): "
        ).strip()

        if validate_username(username):
            return username

        print(
            "帳號格式錯誤，如宿舍的規定帳號格式變成不是xxx@hinet.net，開issue或dc找我。"
        )


def input_password():
    while True:
        password = input("Password: ")

        if validate_password(password):
            return password

        print("密碼格式錯誤，如宿舍規定的密碼格式改成含有特殊符號，開issue或dc找我。")


def initial_setup():
    print()
    print("=" * 40)
    print("  Initial PPPoE Setup")
    print("=" * 40)
    print(f'Connection name: "{CONNECTION_NAME}"')
    print()

    username = input_username()
    password = input_password()

    save_config(username, password)
    bat_path = generate_bat()

    print()
    print("Settings saved.")
    print(f"JSON config: {CONFIG_FILE}")
    print(f"BAT created on Desktop: {bat_path}")


def connect_using_saved_config():
    config = load_config()

    if config is None:
        print()
        print("No valid saved configuration found.")
        print("Please choose option 1 first.")
        return

    bat_path = generate_bat()

    print()
    print("=" * 40)
    print("  Connecting")
    print("=" * 40)
    print(f'Connection: {CONNECTION_NAME}')
    print(f'Username  : {config["username"]}')
    print()

    try:
        result = subprocess.run(
            ["cmd.exe", "/c", str(bat_path)],
            check=False,
        )

        print()
        if result.returncode == 0:
            print("PPPoE connection succeeded.")
        else:
            print(f"PPPoE connection failed. Exit code: {result.returncode}")

    except OSError as e:
        print(f"Failed to run BAT: {e}")


def generate_bat_only():
    config = load_config()

    if config is None:
        print()
        print("No valid saved configuration found.")
        print("Please choose option 1 first.")
        return

    bat_path = generate_bat()

    print()
    print(f"BAT created on Desktop: {bat_path}")
    print(f'It will use PPPoE connection "{CONNECTION_NAME}".')
    print(f"Default JSON config: {CONFIG_FILE}")


def show_menu():
    while True:
        print()
        print("=" * 40)
        print("  PPPoE Connection Helper")
        print("=" * 40)
        print("1. Initial setup / Change account")
        print("2. Connect using saved settings")
        print("3. Generate BAT only")
        print("4. Exit")
        print()

        choice = input("Select [1-4]: ").strip()

        if choice == "1":
            initial_setup()
        elif choice == "2":
            connect_using_saved_config()
        elif choice == "3":
            generate_bat_only()
        elif choice == "4":
            print()
            print("你的離去是成功，還是對失敗的不挽留?")
            print("如果弄完了就可以關掉了，掰掰")
            break
        else:
            print()
            print("Invalid option. Please enter 1, 2, 3, or 4.")


if __name__ == "__main__":
    try:
        show_menu()
    except KeyboardInterrupt:
        print()
        print("\nCancelled.")
        sys.exit(0)
