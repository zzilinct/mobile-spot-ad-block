#!/data/data/com.termux/files/usr/bin/bash
# Third-party Spotify ad skipper for Android: no root, Spotify itself is not modified.
# On an ad: mute media at once, force-restart Spotify (which drops the ad), resume the same playlist,
# put you back in the app you were using, and unmute when a song plays.
# The watcher runs inside one long-lived Shizuku `rish` shell (see README for setup).
#   ./spotify-ad-restart.sh            run
#   ./spotify-ad-restart.sh debug      also print every track Spotify reports
#   ./spotify-ad-restart.sh selftest   check the ad matcher

RISH=${RISH:-$HOME/rish}
VOL_FILE=$HOME/.spotify-ad-volume   # music volume saved while muted, so it survives a crash
# dumpsys shows Spotify's track as "Title, Artist, Album". Ads use a localized "Advertisement" title
# (list from SpotiFade) or Spotify itself / no one as the artist.
# ponytail: text match only. The exact flags (METADATA_KEY_ADVERTISEMENT, spotify:ad media id) aren't
# visible from a shell; reading them needs a NotificationListener app.
AD_PATTERN=${AD_PATTERN:-'^(advertisement|advertentie|annonce|anuncio|anúncio|werbung|pubblicità|reklam|reklama|reklame|mainos|spotify ad|广告|広告|광고)(,|$)|^[^,]*, (spotify|null|)(,|$)'}

is_ad() { grep -Eiq "$AD_PATTERN" <<<"$1"; }

if [[ $1 == selftest ]]; then
  is_ad "Advertisement, Spotify, " && is_ad "Werbung, Some Brand, null" && is_ad "Big Brand, Spotify, null" \
    && is_ad "Big Brand, null, null" && ! is_ad "One More Time, Daft Punk, Discovery" \
    && ! is_ad "Annonce Moi, Some Artist, Album" && ! is_ad "" && echo ok || { echo FAIL; exit 1; }
  exit
fi

# Runs as the shell user via rish (mksh + toybox). Prints "AD <track>" / "SONG <track>" events.
read -r -d '' WATCHER <<SH
AD='$AD_PATTERN'
DEBUG='$([[ $1 == debug ]] && echo 1)'
SP=com.spotify.music
now() {
  d=\$(dumpsys media_session | sed -n "/package=\$SP/,/metadata:/p")
  st=\$(echo "\$d" | grep -o 'state=PlaybackState {state=[0-9]*' | head -1 | grep -o '[0-9]*\$')
  desc=\$(echo "\$d" | sed -n 's/.*metadata:.*description=//p' | head -1)
}
is_ad() { [ -n "\$desc" ] && echo "\$desc" | grep -Eiq "\$AD"; }
fg_pkg() { dumpsys activity activities | grep -m1 -E 'topResumedActivity|mResumedActivity' | grep -o '[A-Za-z0-9_.]*/' | head -1 | tr -d /; }
restart() {
  fg=\$(fg_pkg)
  am force-stop \$SP
  am start -n \$SP/.MainActivity >/dev/null
  # Spotify reopens on its last queue (the playlist the ad interrupted). MEDIA_PLAY never pauses, so repeat it.
  i=0
  while [ \$i -lt 60 ]; do
    sleep 0.5; i=\$((i + 1))
    now
    [ "\$st" = 3 ] && break   # playing: a song, or the ad again (then we stay muted until it ends)
    [ \$((i % 2)) = 0 ] && input keyevent 126
  done
  # Put the user back where they were. Launcher intent brings the existing task forward; home screen has none.
  if [ -n "\$fg" ] && [ "\$fg" != \$SP ]; then
    monkey -p "\$fg" -c android.intent.category.LAUNCHER 1 >/dev/null 2>&1 || input keyevent 3
  fi
}
echo "READY"
inad= last=
while :; do
  now
  [ -n "\$DEBUG" ] && [ "\$desc" != "\$last" ] && echo "TRACK \$st \$desc"
  last=\$desc
  if [ "\$st" = 3 ]; then
    if is_ad; then
      # Restart once per ad break; if the ad survives the restart, just wait it out muted.
      [ -z "\$inad" ] && inad=1 && echo "AD \$desc" && restart
    elif [ -n "\$inad" ]; then
      inad= ; echo "SONG \$desc"
    fi
  fi
  sleep 0.5
done
SH

music_volume() { termux-volume | tr -d ' \n' | grep -o '"stream":"music","volume":[0-9]*' | grep -o '[0-9]*$'; }
mute() {
  [[ -s $VOL_FILE ]] && return
  v=$(music_volume); [[ ${v:-0} -gt 0 ]] || return
  echo "$v" > "$VOL_FILE"; termux-volume music 0
}
unmute() { [[ -s $VOL_FILE ]] && termux-volume music "$(cat "$VOL_FILE")" && rm -f "$VOL_FILE"; }

command -v termux-wake-lock >/dev/null && termux-wake-lock
trap 'unmute; exit' INT TERM
unmute   # restore volume left muted by a crash/reboot mid-ad

# rish exits if Shizuku isn't running yet (after boot it starts once Wi-Fi is up) or dies; just retry.
while :; do
  "$RISH" -c "$WATCHER" | while read -r ev rest; do
    case $ev in
      AD) mute ;;   # the watcher keeps running meanwhile; the pipe buffers its events
      SONG) unmute ;;
    esac
    echo "$(date +%T) $ev $rest"
  done
  unmute
  sleep 10
done
