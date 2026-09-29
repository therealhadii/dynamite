pragma Singleton

import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import QtQuick

Singleton {
    id: root

    // ── Which player is "the" one ────────────────────────────
    //
    // It used to be the first player in the map that happened to be
    // playing, which is not a rule so much as whatever order the bus
    // enumerated in. It looked fine until a browser and a music player
    // were both running: a video in one window and a track in another,
    // and the island reported whichever the bus listed first. The split
    // then showed a YouTube video's title next to Spotify's controls,
    // which is not a now-playing indicator, it is a coin toss.
    //
    // So: rank them, on how much like a music player each one is
    // behaving. Nothing here is a list of applications, which is the
    // thing that would rot — no table of "these six are music players"
    // to fall out of date, and no guessing from a binary's name. Every
    // term is something a player chose to publish about the thing it is
    // playing:
    //
    //   playing        it is making sound now
    //   an artist      somebody is credited on the track
    //   an album       the track belongs to a release
    //   artwork        there is a picture of it
    //   a title        there is a title at all
    //
    // A dedicated player fills in all five. A browser's MediaSession
    // for a video fills in a title and artwork and sometimes an artist
    // (the uploader) and rarely an album, so it loses — and when a
    // browser really is the thing you are listening to, on YouTube
    // Music or SoundCloud, it fills in the same fields a dedicated
    // player does and it wins, which is the correct answer.
    //
    // Ties keep the bus's own order, so the choice is at least stable
    // between two equally plausible players rather than flickering as
    // the map is rebuilt.
    readonly property var ranked: {
        const all = Mpris.players.values;
        if (!all || all.length === 0) return [];

        const score = p => {
            let n = 0;
            if (p.playbackState === MprisPlaybackState.Playing) n += 2;
            if (p.trackTitle)  n += 1;
            if (p.trackArtist) n += 2;
            if (p.trackAlbum)  n += 2;
            if (p.trackArtUrl) n += 1;
            return n;
        };

        return all.slice().sort((a, b) => score(b) - score(a));
    }

    readonly property var active: ranked.length > 0 ? ranked[0] : null

    readonly property bool available: active !== null
    readonly property bool playing: active ? active.playbackState === MprisPlaybackState.Playing : false

    readonly property string title:  active && active.trackTitle  ? active.trackTitle  : ""
    readonly property string artist: active && active.trackArtist ? active.trackArtist : ""
    readonly property string album:  active && active.trackAlbum  ? active.trackAlbum  : ""
    readonly property string artUrl: active && active.trackArtUrl ? active.trackArtUrl : ""

    readonly property string identity: active && active.identity ? active.identity : ""

    // The freedesktop application id, which is the authoritative answer
    // to "which app is this" and the thing `iconPath` wants.
    //
    // Measured on the two shapes that matter here: Spotify's own player
    // reports `spotify`, and Firefox reports `firefox`. Compare that with
    // `identity`, which is a display name — Spotify's is "Spotify", a
    // browser's is "Brave Origin" or "Mozilla Firefox", and a native
    // player's can be anything including a D-Bus name.
    readonly property string desktopEntry:
        (active && active.desktopEntry ? active.desktopEntry : "")
            .replace(/\.desktop$/, "")
            .toLowerCase()

    readonly property real position: active ? active.position : 0
    readonly property real length:   active ? active.length : 0
    readonly property real progress: length > 0 ? position / length : 0

    readonly property bool canNext: active ? active.canGoNext : false
    readonly property bool canPrev: active ? active.canGoPrevious : false
    readonly property bool canToggle: active ? active.canTogglePlaying : false
    readonly property bool canSeek: active ? active.canSeek : false

    function toggle() { if (active && active.canTogglePlaying) active.togglePlaying() }
    function next()   { if (active && active.canGoNext)        active.next() }
    function prev()   { if (active && active.canGoPrevious)    active.previous() }
    function seek(seconds) {
        if (active && active.canSeek && active.length > 0)
            active.position = Math.max(0, Math.min(active.length, seconds));
    }

    signal trackChanged()

    property string _lastTitle: ""

    onTitleChanged: {
        if (title !== "" && title !== _lastTitle) {
            _lastTitle = title;
            root.trackChanged();
        }
    }

    // ── The pill's now-playing readout ────────────────────────
    //
    // True for a moment after a track starts, so the pill can name it.
    // The timer lives here for the reason it does in Wm: the only two
    // things that can start it are `title` and `playing` changing, and
    // this is where both of those happen. A singleton holding one
    // boolean and one timer would be a file and a name for nothing.
    property bool flashActive: false

    // Fired on a new track AND on playback starting, because those are
    // two different ways of saying the same thing and the user asked for
    // the reassurance in both cases: pressing play on a track that was
    // already loaded changes no title, and skipping to the next one
    // changes the title while nothing was technically "started" by them.
    // Both just restart the same timer, so an overlap is harmless.
    function flash() {
        // Nothing to name. A player with no title is publishing
        // something, and showing the pill's width changing around an
        // empty string is worse than showing nothing.
        if (!root.title) return;
        flashActive = true;
        flashHold.restart();
    }

    onTrackChanged: root.flash()
    onPlayingChanged: if (playing) root.flash()

    Timer {
        id: flashHold
        interval: Config.island.mediaFlashDuration
        onTriggered: root.flashActive = false
    }

    // MPRIS position doesn't tick on its own — it has to be polled
    // while something is playing. 1s is enough for a progress bar.
    Timer {
        running: root.playing && root.active !== null
        interval: 1000
        repeat: true
        onTriggered: {
            // The player can vanish between ticks — poking a dead
            // D-Bus name throws ServiceUnknown into the log.
            if (root.active && root.playing)
                root.active.positionChanged();
        }
    }

    IpcHandler {
        target: "player"

        function toggle(): void { root.toggle() }
        function next(): void   { root.next() }
        function previous(): void { root.prev() }
        function status(): string {
            return root.available
                ? (root.playing ? "playing: " : "paused: ") + root.title
                : "no player";
        }
    }
}
