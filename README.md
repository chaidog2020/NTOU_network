## Note: This is final version of this repo, no more update will be released.

---

# NTOU_dormitory_network_helper

A Python/BAT script that automatically creates a `.bat` file on your Desktop for connecting to the NTOU dormitory PPPoE Internet service.

Make sure your computer is connected to the Ethernet port with a network cable. Otherwise, this script will not work.

**Although the account and password information is posted on the bulletin board, it is still recommended to keep your own account and password in a safe place.**

### Disclaimer

Please review the script and decide whether you trust it before running it. I am not responsible for any damage or issues that may occur on your computer. If you are not sure what the script does, do not use it.

## Setup

Place the Python/BAT script in a folder that you will not delete, then run the script from that folder.

Your saved account and password settings will be stored in the same folder.

## Option 1 - Initial Setup / Change Account

Enter your account and password here.

The account should include `@hinet.net` at the end (for 2026).

Running this option again will overwrite the previously saved account information.

## Option 2 - Connect Using Saved Settings

This option connects to the Internet automatically using the saved account and password.

## Option 3 - Generate BAT Only

This option generates a `.bat` file on your Desktop.

If you are disconnected from the Internet, you can run the `.bat` file to connect automatically.

## Option 4 - Install auto-connect BAT to Windows Startup

This option creates an auto-connect `.bat` file in your Windows Startup folder.

After you log in to Windows, the script will automatically try to connect to the dormitory PPPoE network.

The script will wait a few seconds before connecting, then retry several times if the connection is not ready yet.

Your username and password will be stored directly inside the Startup `.bat` file in plaintext.

If the automatic connection fails after all retry attempts, the terminal will remain open and display the path of the Startup `.bat` file.

You can delete that file at any time to disable automatic connection.

If you change your account or password using Option 1, the existing Startup `.bat` file will also be updated automatically.

**If your Startup `.bat` file does not work, please re-enter the correct account and password in Option 1, or check your `.json` file for errors.**

Hope you have a wonderful college life!

By chaidog2020

---

# NTOU_dormitory_network_helper 中文說明

這是一個 Python/BAT 腳本，可以自動在桌面產生 `.bat` 檔案，連接海大宿舍 PPPoE 有線網路。

使用前請確認你的電腦已經透過網路線連接到宿舍的網路孔，否則此腳本將無法正常運作。

**雖然帳號與密碼資訊會公布在公告欄上，但還是建議妥善保管自己的帳號與密碼。**

### 免責聲明

執行前請先自行確認腳本內容，並自行判斷是否信任此腳本。若你的電腦因這個腳本發生任何損壞或問題，本人概不負責。如果你不確定這個腳本在做什麼，請不要執行。

## 設定方式

請將 Python/BAT 腳本放到一個你不會刪除的資料夾中，然後從該資料夾執行腳本。

你儲存的帳號與密碼設定會存放在同一個資料夾中。

## 選項 1 - 初始設定 / 更改帳號

在這裡輸入你的帳號與密碼。

帳號後面需要加上 `@hinet.net` (2026的時候要)。

再次執行此選項會覆蓋先前儲存的帳號資訊。

## 選項 2 - 使用已儲存的設定連線

此選項會使用已儲存的帳號與密碼，自動連接到網際網路。

## 選項 3 - 只產生 BAT 檔案

此選項會在你的桌面產生一個 `.bat` 檔案。

如果你目前沒有網路連線，可以直接執行該 `.bat` 檔案來自動連線。

## 選項 4 - 將自動連線 BAT 安裝到 Windows 啟動資料夾

此選項會在你的 Windows 啟動資料夾中建立一個自動連線用的 `.bat` 檔案。

登入 Windows 後，腳本會自動嘗試連線到宿舍的 PPPoE 網路。

腳本會先等待幾秒再進行連線，如果網路尚未準備完成，則會再重試數次。

你的帳號與密碼會以明文形式直接儲存在 Startup 的 `.bat` 檔案中。

如果所有重試都失敗，終端機視窗會保持開啟，並顯示該 Startup `.bat` 檔案的路徑。

你可以隨時刪除該檔案，以停用自動連線功能。

如果你使用選項 1 更改帳號或密碼，現有的 Startup `.bat` 檔案也會自動更新。

**如果你的 Startup `.bat` 檔案無法正常運作，請在選項 1 中重新輸入正確的帳號與密碼，或檢查你的 `.json` 檔案是否有錯誤。**

祝你有個愉快的大學生活！(希望我也有)

By chaidog2020
