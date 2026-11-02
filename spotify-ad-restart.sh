#!/data/data/com.termux/files/usr/bin/bash
# Restart Spotify on Android when an ad plays, then resume the same playlist. No root, no per-ad input.
# Runs in Termux; privileged commands go through Shizuku's `rish` (see README for one-time setup).
#   ./spotify-ad-restart.sh            run
#   ./spotify-ad-restart.sh debug      print what Spotify reports each poll (use to tune AD_PATTERN)
#   ./spotify-ad-restart.sh selftest   check the ad matcher

PKG=com.spotify.music
RISH=${RISH:-$HOME/rish}
# Calibration knob: Spotify's media "description" is "Title, Artist, Album".
# Ads show up as "Advertisement, ..." or with Spotify itself / nobody as the artist.
AD_PATTERN=${AD_PATTERN:-'^Advertisement|^Spotify,|, Spotify(,|$)|^[^,]*, ,'}

is_ad() { [[ -n $1 ]] && grep -Eq "$AD_PATTERN" <<<"$1"; }

sh_() { "$RISH" -c "$*" 2>/dev/null; }

# Prints "<state> <description>" for Spotify's media session (3 = playing), or nothing if Spotify isn't running.
# One rish call per poll: each call starts a JVM, so keep them few.
spotify_session() {
  sh_ "pidof $PKG >/dev/null && dumpsys media_session" | awk -v pkg="package=$PKG" '
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

command -v termux-wake-lock >/dev/null && termux-wake-lock

# After a reboot Shizuku starts itself once Wi-Fi is up; wait for it instead of giving up.
until [[ $(sh_ echo ok) == ok ]]; do sleep 15; done
echo "$(date +%T) Shizuku ready, watching Spotify"

last=
while :; do
  cur=$(spotify_session)
  if [[ -z $cur ]]; then
    # Spotify not running, or Shizuku died (e.g. reboot without Wi-Fi). Back off, keep trying.
    sleep 5; continue
  fi
  [[ $1 == debug && $cur != "$last" ]] && echo "$cur"
  last=$cur
  if [[ $cur == 3\ * ]] && is_ad "${cur#3 }"; then
    echo "$(date +%T) ad: ${cur#3 } -> restarting"
    restart
  fi
  sleep 2
done
