# Spotify ad skipper for Android (no root, Spotify unmodified)

Runs alongside the regular Spotify app, modelled on Spicetify's adblock where Android allows it:

| Spicetify (desktop) | This (Android) |
|---|---|
| Ad audio never plays | Media is muted within ~0.5s of an ad starting |
| Ad slots cleared, playback continues | Spotify is force-restarted once, which drops the ad, and resumes the same playlist. If the ad survives the restart, it stays muted until the ad ends, without restarting again. |
| No interruption | You're returned to the app you were using, and volume is restored when the next song starts |
| Banners and upgrade buttons hidden | Not possible: Android doesn't let an outside app hide parts of another app's screen |

Spicetify can do more because it patches the desktop app from inside. Android doesn't allow that without modifying Spotify itself.

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

## Ad detection

Android hides the exact ad flag from shell tools, so the script reads the track text, `Title, Artist, Album`. It's treated as an ad when the title is "Advertisement" in any of 15 languages (list taken from [SpotiFade](https://github.com/SkelosJS/spotifade-android)), or when the artist is `Spotify` or missing. It checks every 0.5s.

To see what Spotify reports, run `~/spotify-ad-restart.sh debug`. If an ad ever gets through, add a regex for it in the boot script:
```
AD_PATTERN='<pattern>' ~/spotify-ad-restart.sh &
```

## Limits

- Shizuku starts after boot only once the phone is on **Wi-Fi**. Until then the script waits and starts working as soon as Wi-Fi connects. After that it keeps working on mobile data until the next reboot.
