from pathlib import Path
import json
import subprocess
import ctypes
import sys

BASE_DIR = Path(__file__).resolve().parent
CONFIG_FILE = BASE_DIR / "pppoe_config.json"

CONNECTION_NAME = "寬頻連線"


def get_desktop_path():
    """取得目前 Windows 使用者真正的桌面路徑。"""
    if sys.platform == "win32":
        try:
            # CSIDL_DESKTOPDIRECTORY = 0x10
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


def load_config():

    if not CONFIG_FILE.exists():
        return None

    try:
        with CONFIG_FILE.open("r", encoding="utf-8") as f:
            data = json.load(f)

        if not data.get("username") or not data.get("password"):
            return None

        return data
    except (json.JSONDecodeError, OSError):
        return None


def save_config(username, password):

    data = {
        "username": username,
        "password": password,
    }

    with CONFIG_FILE.open("w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=2)

    return data


def escape_for_bat(value):
    
    return value.replace("%", "%%")


def generate_bat(config):

    username = escape_for_bat(config["username"])
    password = escape_for_bat(config["password"])

    bat_content = f"""@echo off
chcp 65001 >nul
title PPPoE Auto Connect

set "CONNECTION={CONNECTION_NAME}"
set "USERNAME={username}"
set "PASSWORD={password}"

echo.
echo ========================================
echo   PPPoE Connection Helper
echo ========================================
echo.
echo [*] Connection : %CONNECTION%
echo [*] Username   : %USERNAME%
echo.

rem Check whether this PPPoE connection is already active.
rasdial | findstr /I /C:"%CONNECTION%" >nul 2>&1
if not errorlevel 1 (
    echo [+] Already connected.
    timeout /t 2 /nobreak >nul
    exit /b 0
)

echo [*] Connecting...
echo.

rasdial "%CONNECTION%" "%USERNAME%" "%PASSWORD%"

if errorlevel 1 (
    echo.
    echo [!] Connection failed.
    echo [!] Please check:
    echo     - Ethernet cable
    echo     - PPPoE connection named "%CONNECTION%"
    echo     - Username / password
    echo.
    pause
    exit /b 1
)

echo.
echo [+] Connected successfully.
timeout /t 2 /nobreak >nul
exit /b 0
"""

    BAT_FILE.write_text(bat_content, encoding="utf-8-sig")
    return BAT_FILE


def initial_setup():

    print()
    print("=" * 40)
    print("  Initial PPPoE Setup")
    print("=" * 40)
    print(f'Connection name: "{CONNECTION_NAME}"')
    print()

    username = input("Username (後面要加@hinet.net，不然連不到): ").strip()
    if not username:
        print("[!] Username cannot be empty.")
        return

    password = input("Password: ")
    if not password:
        print("[!] Password cannot be empty.")
        return

    config = save_config(username, password)
    bat_path = generate_bat(config)

    print()
    print("[+] Settings saved.")
    print(f"[+] BAT created on Desktop: {bat_path}")
    print("[!] The password is stored locally in plaintext.")
    print("    Do not share pppoe_config.json or ntou_pppoe.bat.")


def connect_using_saved_config():

    config = load_config()

    if config is None:
        print()
        print("[!] No saved configuration found.")
        print("[!] Please choose option 1 first.")
        return

    bat_path = generate_bat(config)

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
            print("[+] PPPoE connection succeeded.")
        else:
            print(f"[!] PPPoE connection failed. Exit code: {result.returncode}")

    except OSError as e:
        print(f"[!] Failed to run BAT: {e}")


def generate_bat_only():

    config = load_config()

    if config is None:
        print()
        print("[!] No saved configuration found.")
        print("[!] Please choose option 1 first.")
        return

    bat_path = generate_bat(config)

    print()
    print(f"[+] BAT created on Desktop: {bat_path}")
    print(f'[+] It will use PPPoE connection "{CONNECTION_NAME}".')


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
            print("Bye.")
            break
        else:
            print()
            print("[!] Invalid option. Please enter 1, 2, 3, or 4.")


if __name__ == "__main__":
    try:
        show_menu()
    except KeyboardInterrupt:
        print()
        print("\nCancelled.")
        sys.exit(0)
