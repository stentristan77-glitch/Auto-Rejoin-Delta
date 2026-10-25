# Roblox Rejoin

Android app that watches Roblox and, if it closes or crashes, reopens your private server link.

## Get the APK (free, no PC tools needed)

1. Make a free account on github.com and create a new repository (any name).
2. Upload everything in this folder (keep the folders, including `.github`).
3. Open the **Actions** tab. The "Build APK" job runs automatically (about 3-5 min).
   If it doesn't, click "Build APK" → "Run workflow".
4. Open the finished run, scroll to **Artifacts**, download `RobloxRejoin-apk`, unzip it.
5. Put `app-debug.apk` on your phone and open it (allow "install unknown apps").

Or: open the folder in Android Studio and press Run.

## Setup on the phone

1. Paste your private server link (Roblox → server → Share/Copy link).
2. Tap **Allow usage access** → find Roblox Rejoin → turn it on.
3. Tap **Allow display over other apps** → turn it on (needed so it can open Roblox from the background).
4. Tap **Turn off battery optimisation** → set Roblox Rejoin to "Don't optimise" / "Unrestricted".
5. Tap **Test link now** to check the link works, then **START watching**.
6. Open Roblox. From then on, if Roblox closes, it reopens after the delay you set.

Stop it from the notification's **Stop** button or the app.

## Notes

- It reopens Roblox whenever Roblox leaves the screen for longer than the delay (except when you're in the Rejoin app itself). Stop the watcher if you want to use other apps.
- It does nothing while the screen is off.
- It can't detect an in-game "Disconnected" screen, because Roblox is still open then.
- Xiaomi/Huawei/Oppo phones: also enable "Autostart" for the app or the system may kill it.
