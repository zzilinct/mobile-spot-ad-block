"""Restart Spotify (Windows desktop) when an ad starts, then resume the same playlist.

Run:        pythonw spotify_ad_restart.py
Autostart:  python spotify_ad_restart.py --install   (idles until Spotify runs)
Self-test:  python spotify_ad_restart.py --selftest
"""
import os
import subprocess
import sys
import time

PAUSED_TITLES = {"Spotify", "Spotify Free", "Spotify Premium"}
VK_MEDIA_PLAY_PAUSE = 0xB3


def looks_like_ad(title):
    # Songs are always "Artist - Track"; paused shows "Spotify Free"; ads show
    # "Advertisement" or the advertiser's name.
    # ponytail: title heuristic, an ad titled exactly "Spotify" looks paused and is missed.
    return bool(title) and title not in PAUSED_TITLES and " - " not in title


def spotify_title():
    """Title of Spotify's main window, or None if Spotify isn't running."""
    import ctypes
    from ctypes import wintypes

    out = subprocess.run(
        ["tasklist", "/fo", "csv", "/nh", "/fi", "imagename eq Spotify.exe"],
        capture_output=True, text=True, creationflags=0x08000000,  # no console flash
    ).stdout
    pids = {int(line.split('","')[1]) for line in out.splitlines() if line.startswith('"Spotify.exe"')}
    if not pids:
        return None

    user32 = ctypes.windll.user32
    found = []

    @ctypes.WINFUNCTYPE(wintypes.BOOL, wintypes.HWND, wintypes.LPARAM)
    def check(hwnd, _):
        pid = wintypes.DWORD()
        user32.GetWindowThreadProcessId(hwnd, ctypes.byref(pid))
        if pid.value in pids:
            cls, title = ctypes.create_unicode_buffer(256), ctypes.create_unicode_buffer(512)
            user32.GetClassNameW(hwnd, cls, 256)
            user32.GetWindowTextW(hwnd, title, 512)
            if cls.value.startswith("Chrome_WidgetWin") and title.value:
                found.append(title.value)
        return True

    user32.EnumWindows(check, 0)
    return found[0] if found else ""  # "" = still starting up


def playback_api():
    """Optional Spotify Web API client, used only to learn which playlist is playing."""
    if not os.environ.get("SPOTIPY_CLIENT_ID"):
        return None
    import spotipy
    from spotipy.oauth2 import SpotifyPKCE

    return spotipy.Spotify(auth_manager=SpotifyPKCE(
        scope="user-read-playback-state",
        redirect_uri=os.environ.get("SPOTIPY_REDIRECT_URI", "http://127.0.0.1:8888/callback"),
        cache_path=os.path.join(os.path.dirname(os.path.abspath(__file__)), ".spotify_token"),
    ))


def current_context(api):
    try:
        pb = api.current_playback() if api else None
        return pb["context"]["uri"] if pb and pb.get("context") else None
    except Exception as e:  # network hiccup: keep the last known playlist
        print("API error:", e)
        return None


def press_play():
    import ctypes
    kb = ctypes.windll.user32.keybd_event
    kb(VK_MEDIA_PLAY_PAUSE, 0, 0, 0)
    kb(VK_MEDIA_PLAY_PAUSE, 0, 2, 0)


def restart(context):
    subprocess.run(["taskkill", "/F", "/IM", "Spotify.exe"], capture_output=True, creationflags=0x08000000)
    while spotify_title() is not None:
        time.sleep(0.3)
    # The URI reopens the playlist; Spotify also restores its own queue, so play continues it.
    os.startfile(context or "spotify:")
    deadline = time.time() + 30
    while time.time() < deadline:
        time.sleep(2)
        title = spotify_title()
        if title and " - " in title:
            return  # playing again
        if title in PAUSED_TITLES:
            press_play()
    print("Spotify did not resume within 30s")


def main():
    api = playback_api()
    context, last = None, None
    while True:
        title = spotify_title()
        if title != last:
            last = title
            if looks_like_ad(title):
                print("Ad detected:", title, "-> restarting into", context)
                restart(context)
                last = None
            elif title and " - " in title:
                context = current_context(api) or context
        time.sleep(1)


def install():
    startup = os.path.join(os.environ["APPDATA"], r"Microsoft\Windows\Start Menu\Programs\Startup")
    pythonw = os.path.join(os.path.dirname(sys.executable), "pythonw.exe")
    bat = os.path.join(startup, "spotify_ad_restart.bat")
    with open(bat, "w") as f:
        f.write(f'@start "" "{pythonw}" "{os.path.abspath(__file__)}"\n')
    print("Installed:", bat)


def selftest():
    assert looks_like_ad("Advertisement")
    assert looks_like_ad("Some Brand")
    assert not looks_like_ad("Daft Punk - One More Time")
    assert not looks_like_ad("Spotify Free")
    assert not looks_like_ad("")
    assert not looks_like_ad(None)
    print("ok")


if __name__ == "__main__":
    {"--install": install, "--selftest": selftest}.get(sys.argv[1] if len(sys.argv) > 1 else "", main)()
