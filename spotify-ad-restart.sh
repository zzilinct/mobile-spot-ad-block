#!/data/data/com.termux/files/usr/bin/bash
# Restart Spotify on Android when an ad plays, then resume the same playlist.
# Runs in Termux and talks to the phone itself over ADB (see README for one-time setup).
#   ./spotify-ad-restart.sh            run
#   ./spotify-ad-restart.sh debug      print what Spotify reports each poll (use to tune AD_PATTERN)
#   ./spotify-ad-restart.sh selftest   check the ad matcher

PKG=com.spotify.music
ADB_ADDR=${ADB_ADDR:-localhost:5555}
# Calibration knob: Spotify's media "description" is "Title, Artist, Album".
# Ads show up as "Advertisement, ..." or with Spotify itself / nobody as the artist.
AD_PATTERN=${AD_PATTERN:-'^Advertisement|^Spotify,|, Spotify(,|$)|^[^,]*, ,'}

is_ad() { [[ -n $1 ]] && grep -Eq "$AD_PATTERN" <<<"$1"; }

sh_() { adb -s "$ADB_ADDR" shell "$@" 2>/dev/null; }

# Prints "<state> <description>" for Spotify's media session (state 3 = playing, 2 = paused).
spotify_session() {
  sh_ dumpsys media_session | awk -v pkg="package=$PKG" '
    index($0, pkg) { s = 1 }
    s && /state=PlaybackState/ { match($0, /state=[0-9]+/); st = substr($0, RSTART + 6, RLENGTH - 6) }
    s && /metadata:/ { sub(/.*description=/, ""); print st " " $0; exit }'
}

restart() {
  sh_ am force-stop "$PKG"
  sleep 1
  # Spotify reopens on the last queue, which is the playlist the ad interrupted.
  sh_ monkey -p "$PKG" -c android.intent.category.LAUNCHER 1 >/dev/null
  for _ in $(seq 15); do
    sleep 2
    [[ $(spotify_session) == 3\ * ]] && return
    sh_ input keyevent 126   # KEYCODE_MEDIA_PLAY
  done
  echo "Spotify did not resume within 30s"
}

selftest() {
  is_ad "Advertisement, Spotify, " || exit 1
  is_ad "Big Brand, Spotify, " || exit 1
  is_ad "Big Brand, , " || exit 1
  ! is_ad "One More Time, Daft Punk, Discovery" || exit 1
  ! is_ad "" || exit 1
  echo ok
}

[[ $1 == selftest ]] && selftest && exit

adb connect "$ADB_ADDR" >/dev/null || { echo "ADB not reachable at $ADB_ADDR, see README"; exit 1; }
command -v termux-wake-lock >/dev/null && termux-wake-lock

last=
while :; do
  if [[ -z $(sh_ pidof "$PKG") ]]; then sleep 10; continue; fi   # idle until Spotify runs
  cur=$(spotify_session)
  [[ $1 == debug && $cur != "$last" ]] && echo "$cur"
  last=$cur
  if [[ $cur == 3\ * ]] && is_ad "${cur#3 }"; then
    echo "$(date +%T) ad: ${cur#3 } -> restarting"
    restart
  fi
  sleep 2
done
