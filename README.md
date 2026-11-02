# Spotify ad restart (Android, no root)

Watches Spotify's media session. When an ad plays, it force-stops Spotify, reopens it, and presses play. Spotify reopens on its last queue, so the same playlist continues.

Android won't let one app close another without root. [Shizuku](https://shizuku.rikka.app/) gives apps ADB-level access, and it can restart itself after a reboot. Once set up, nothing needs a person: not per ad, and not after a reboot.

## One-time setup

1. Install **Termux**, **Termux:Boot** and **Termux:API** from F-Droid, and **Shizuku** from the Play Store or GitHub.
2. In Termux: `pkg install termux-api`
3. Developer options: turn on **Wireless debugging** and **Disable adb authorization timeout**. Without the second one, Android drops the pairing after 7 days.
4. In Shizuku: start it through **Wireless debugging** (pair once with the code), then turn on **Start on boot**. If asked to grant `WRITE_SECURE_SETTINGS`, follow Shizuku's prompt.
5. In Shizuku, tap **Use Shizuku in terminal apps**, then **Export files** to a folder. In Termux:
   ```
   termux-setup-storage
   cp <export folder>/rish <export folder>/rish_shizuku.dex ~/
   sed -i 's/PKG/com.termux/' ~/rish
   chmod +x ~/rish
   ```
   Make sure the edited `rish` line reads `RISH_APPLICATION_ID="com.termux"`. When Shizuku asks whether to allow Termux, choose **Allow all the time**.
6. Copy `spotify-ad-restart.sh` to `~/`, then:
   ```
   chmod +x ~/spotify-ad-restart.sh
   mkdir -p ~/.termux/boot
   printf '#!/data/data/com.termux/files/usr/bin/sh\n~/spotify-ad-restart.sh &\n' > ~/.termux/boot/start
   chmod +x ~/.termux/boot/start
   ```
7. Android settings, Apps: set **Termux** and **Shizuku** battery usage to **Unrestricted** so Android doesn't kill them in the background.
8. Reboot to check that it starts on its own, or run `~/spotify-ad-restart.sh` to start it now.

## Once: confirm what an ad looks like

Run `~/spotify-ad-restart.sh debug` and let an ad play. It prints what Spotify reports, for example `3 Advertisement, Spotify, `. If ads aren't being caught, put a regex that matches them in the boot script:
```
AD_PATTERN='^Advertisement|your pattern' ~/spotify-ad-restart.sh &
```

## Limits

- Shizuku starts after boot only once the phone is on **Wi-Fi**. Until then the script waits and starts working as soon as Wi-Fi connects. After that it keeps working on mobile data until the next reboot.
