# Spotify ad restart (Windows desktop)

Watches the Spotify desktop window title. When an ad starts, it kills Spotify, reopens it on the playlist you were listening to, and presses play.

iOS and Android don't let one app close another, so this is desktop only.

## Setup

1. Install Python 3 from python.org.
2. `python spotify_ad_restart.py --install` adds the script to Windows startup. It waits in the background and starts working when you open Spotify.
3. Start it now without logging out: `pythonw spotify_ad_restart.py`

## Remembering the playlist

By default it relies on Spotify reopening its last queue, which is normally the same playlist. To record the exact playlist and reopen it directly:

1. `pip install spotipy`
2. Create an app at https://developer.spotify.com/dashboard and add the redirect URI `http://127.0.0.1:8888/callback`.
3. Set the user environment variable `SPOTIPY_CLIENT_ID` to the app's client ID.
4. Run `python spotify_ad_restart.py` once in a console and approve the login in your browser. The token is saved next to the script.

## Limitations

- Ads are detected from the window title. Songs show `Artist - Track`; an ad shows `Advertisement` or the advertiser's name. An ad titled just `Spotify` looks the same as paused and won't be caught.
- Podcast episodes without ` - ` in their title look like ads. Stop the script while listening to podcasts.
