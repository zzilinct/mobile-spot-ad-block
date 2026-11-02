#!/data/data/com.termux/files/usr/bin/bash
# Restart Spotify on Android when an ad plays, then resume the same playlist. No root, no per-ad input.
# Runs in Termux; the watcher runs inside one long-lived Shizuku `rish` shell (see README for setup).
#   ./spotify-ad-restart.sh            run
#   ./spotify-ad-restart.sh debug      also print every track Spotify reports
#   ./spotify-ad-restart.sh selftest   check the ad matcher

RISH=${RISH:-$HOME/rish}
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

# Runs as the shell user via rish. mksh + toybox only.
read -r -d '' WATCHER <<SH
AD='$AD_PATTERN'
DEBUG='$([[ $1 == debug ]] && echo 1)'
now() {
  d=\$(dumpsys media_session | sed -n '/package=com.spotify.music/,/metadata:/p')
  st=\$(echo "\$d" | grep -o 'state=PlaybackState {state=[0-9]*' | head -1 | grep -o '[0-9]*\$')
  desc=\$(echo "\$d" | sed -n 's/.*metadata:.*description=//p' | head -1)
}
is_ad() { [ -n "\$desc" ] && echo "\$desc" | grep -Eiq "\$AD"; }
echo "watching Spotify"
last=
while :; do
  now
  [ -n "\$DEBUG" ] && [ "\$desc" != "\$last" ] && echo "track: \$st \$desc"
  last=\$desc
  if [ "\$st" = 3 ] && is_ad; then
    echo "\$(date +%T) ad: \$desc -> restarting"
    am force-stop com.spotify.music
    am start -n com.spotify.music/.MainActivity >/dev/null
    # Spotify reopens on its last queue (the playlist the ad interrupted). MEDIA_PLAY never pauses, so repeat it until music plays.
    i=0
    while [ \$i -lt 60 ]; do
      sleep 0.5; i=\$((i + 1))
      now
      [ "\$st" = 3 ] && ! is_ad && break
      [ \$((i % 2)) = 0 ] && input keyevent 126
    done
    echo "\$(date +%T) resumed: \$desc"
  fi
  sleep 0.5
done
SH

command -v termux-wake-lock >/dev/null && termux-wake-lock
# rish exits if Shizuku isn't running yet (after boot it starts once Wi-Fi is up) or dies; just retry.
while :; do
  "$RISH" -c "$WATCHER"
  sleep 10
done
