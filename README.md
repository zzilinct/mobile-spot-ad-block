# Spotify ad restart (Android, no root)

Android won't let one app close another. ADB can, and Termux can run ADB against its own phone over wireless debugging. This script watches Spotify's media session. When an ad plays, it force-stops Spotify, reopens it, and presses play. Spotify reopens on its last queue, so the same playlist continues.

## One-time setup

1. Install **Termux** and **Termux:Boot** from F-Droid. The Play Store versions are outdated.
2. In Termux: `pkg install android-tools termux-api`
3. Turn on Developer options (tap Build number 7 times), then **Wireless debugging** (you need to be on Wi-Fi).
4. Tap **Pair device with pairing code**. Use split screen or a notification so the pairing dialog stays open, then in Termux run:
   ```
   adb pair localhost:<pairing port> <code>
   adb connect localhost:<port shown on the Wireless debugging screen>
   adb tcpip 5555
   ```
   `adb tcpip 5555` keeps ADB open on port 5555 even after you leave Wi-Fi, until the phone reboots.
5. Copy `spotify-ad-restart.sh` to `~/` in Termux and run `chmod +x ~/spotify-ad-restart.sh`.

## Run

```
~/spotify-ad-restart.sh
```

## Auto-start

```
mkdir -p ~/.termux/boot
printf '#!/data/data/com.termux/files/usr/bin/sh\n~/spotify-ad-restart.sh &\n' > ~/.termux/boot/start
chmod +x ~/.termux/boot/start
```

The script idles until Spotify is running, then starts watching.

**After every reboot**, redo step 4 without the pairing: turn on Wireless debugging, run `adb connect` with the port shown, then `adb tcpip 5555`. Android shuts ADB down on reboot and only root avoids that.

## If ads aren't caught

Run `~/spotify-ad-restart.sh debug` and let an ad play. It prints what Spotify reports, for example `3 Advertisement, Spotify, `. If an ad looks different, set `AD_PATTERN` to a regex that matches it:

```
AD_PATTERN='^Advertisement|your pattern' ~/spotify-ad-restart.sh
```
