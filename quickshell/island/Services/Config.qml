pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    readonly property alias island: adapter.island
    readonly property alias wallpaper: adapter.wallpaper
    readonly property alias motion: adapter.motion
    readonly property alias appearance: adapter.appearance
    readonly property alias input: adapter.input
    readonly property alias idle: adapter.idle
    readonly property alias lock: adapter.lock
    readonly property alias audio: adapter.audio
    readonly property alias apps: adapter.apps
    readonly property alias ui: adapter.ui

    // Force a write. Most changes save automatically via
    // onAdapterUpdated, but this is here for explicit saves.
    // Bump when a key changes meaning rather than merely appearing.
    // New keys need no migration — the merge on load handles those.
    readonly property int currentVersion: 14

    // Set once the startup merge has run, so the file watcher's reload
    // doesn't start writing in a loop.
    property bool merged: false

    // True only while the adapter is being filled in from disk. See
    // `onAdapterUpdated`.
    property bool populating: false

    // Run the migration if what the adapter holds is behind the shell.
    //
    // Called from `onLoaded` AND from `onAdapterUpdated`; see the note on
    // the second one for why it needs both. The decision is one question
    // — is the version behind — and answering it in one place is what
    // stops the two call sites from disagreeing about it.
    //
    // `merged` is set but deliberately NOT consulted. It guards the
    // default-write for an absent file, and using it to also gate the
    // migration is what let a half-applied one look permanent.
    function migrateIfBehind() {
        if (adapter.version >= root.currentVersion) return;
        root.merged = true;
        root.migrate(adapter.version);
    }

    function migrate(from) {
        // Mostly nothing carries over: the old values have no meaning
        // under the new keys. Dropped keys leave the file on the next
        // write, since JsonAdapter writes only what it declares.
        //
        //   1 -> 2  faces gone; tray and workspaces are pods now
        //   2 -> 3  motion is a spring: duration/overshoot replaced
        //   3 -> 4  controlHeight gone; the panel is a layout
        //   4 -> 5  the spring is solved rather than sampled, so it
        //           is described by response and bounce. A duration
        //           and a damping fraction cannot be carried over:
        //           the old numbers were a curve's length and this
        //           one has none.
        //  13 -> 14 the right circle is a button, and the tray is a hover.
        //
        //     RENAMED, which is a drop and an add rather than a move:
        //
        //       island.showTray  ->  island.showControl
        //
        //     The pod was the tray, permanently, and it was the wrong
        //     shape for the job: a circle is a good home for one glyph
        //     and a poor one for a list, so a tray at rest had to be a
        //     capsule with a "+n" on the end, and a bar beside a round
        //     pill is the one arrangement the island does not own.
        //
        //     Now the click is the control centre and the hover is the
        //     tray. Nothing is lost — the icons are one gesture away,
        //     which is where the "+n" was pointing anyway — and the
        //     resting shape is a circle that says what it is for.
        //
        //  12 -> 13 both pods are circles, and the left one is media.
        //
        //     DROPPED, not reset:
        //
        //       island.trayRestMax   4
        //
        //     It bounded how many tray icons the pod showed at rest, and
        //     a rest state of four icons plus a "+2" is a capsule, not a
        //     circle. A circle holds one icon; the rest arrive when the
        //     pod opens, which is where the count was pointing anyway.
        //     Resetting it to 1 would leave a setting that describes a
        //     choice the shape no longer offers.
        //
        //     Added, with its shipped value:
        //
        //       island.showMedia   true
        //
        //     The left seat, which held the workspace pod until 11 -> 12
        //     and was empty after it, now holds now-playing: the cover,
        //     or the player's own icon, or a note. The pill cannot
        //     answer that question — at rest it holds a clock and a
        //     number, and the split that could needs a press-and-hold to
        //     reach.
        //
        //  11 -> 12 the workspace pod is gone and the pill says it.
        //
        //     Two keys are DROPPED, not reset:
        //
        //       island.showWorkspaces   true
        //       island.workspaceStyle   "dashes"
        //
        //     There was a capsule to the left of the pill whose whole
        //     job was to say where you were. It is in the pill now, in
        //     the middle of the thing it is about, and only for a
        //     moment after you move — so the answer arrives where you
        //     are already looking rather than somewhere you had to know
        //     to look.
        //
        //     Both keys are dropped rather than migrated to `false`,
        //     because `false` would be a setting that hides nothing:
        //     there is no pod left to switch off.
        //
        //     Added, with its shipped value:
        //
        //       island.workspaceFlashDuration  1200
        //
        //   10 -> 11 the notification is the shape, not a banner.
        //
        //     Three keys are DROPPED, not reset:
        //
        //       island.notifyHeight           104
        //       island.notifyActionHeight      36
        //       island.notifyReplyHeight       38
        //
        //     They were three fixed numbers summed in the geometry
        //     table, so a one-line notification with nothing to act on
        //     came out exactly as tall as a three-line one with four
        //     buttons — 104px either way, which is a banner, and a
        //     banner is the presentation the Dynamic Island replaced.
        //     The height is NotifyMode's `contentHeight` now, measured off
        //     the real items: 46px for a summary and nothing else, which
        //     is the iPhone's compact notification.
        //
        //     island.notifyWidth  460 -> 420 is reset rather than
        //     dropped, for the reason the launcher's was.
        //
        //   9 -> 10 the clipboard is the launcher's twin and is resized
        //           to match, and the pill's track title goes.
        //
        //     island.clipWidth  620 -> 460. The same disease the launcher
        //       had, one file over: the same field-over-a-shelf shape at
        //       a width chosen to match a launcher that was itself too
        //       wide. A clipboard entry is a line of text.
        //
        //     island.pillTitle  DROPPED. It put the track's title in the
        //       resting pill, and the resting pill is now a clock and
        //       nothing else — there is no transport for the title to sit
        //       beside, and a title is as long as whoever named the track
        //       decided. Nothing read it any more, which makes this the
        //       "a declared property is not a drawn one" case that
        //       docs/NOTES.md records as having lived in SliderRow for
        //       years: a settings toggle for a setting nothing drew.
        //       Dropped keys leave the file on the next write.
        //
        //   8 -> 9  the launcher is rebuilt at a sane size.
        //
        //     Four keys are RESET, which is not the rule for a changed
        //     default — it is the rule for a size that was wrong:
        //
        //       island.searchWidth         560 -> 460
        //       island.searchFieldHeight   46  -> 40
        //       island.searchRowHeight     40  -> 36
        //       island.searchMaxRows        8  -> 6
        //
        //     560 was the control centre's width, applied to a field
        //     holding one application name, and at that width the single
        //     result in it looked like a card floating in a field. Eight
        //     rows of 11px type in 40px rows is eight rows of nothing.
        //     These are stored values rather than shipped defaults, and
        //     a stored value is somebody's choice only if the choice was
        //     ever available — so they are reset once, and the sliders
        //     are there afterwards.
        //
        //   7 -> 8  the resting pill is sized to its contents, and hover
        //           stops being a shape at all.
        //
        //     Two keys are DROPPED rather than reset. Dropped keys leave
        //     the file on the next write, since JsonAdapter writes only
        //     what it declares:
        //
        //       island.compactWidth   200
        //       island.compactHeight  40
        //
        //     They sized the hover state, and there is no hover state.
        //     Hover was the pill growing 47% wider and 6px taller and
        //     gaining three buttons, for a pointer passing over — the one
        //     movement in the shell that could not be explained by
        //     looking at it. It is a cross-fade now: the clock becomes
        //     the transport, in the same shape. So there is no width or
        //     height left for these to describe, and inventing values
        //     for them in a migration would be worse than dropping them.
        //
        //     island.idleWidth  is NOT reset to a number. It is a floor
        //     and the content is the clock plus padding, so 152 — a
        //     number that described a pill holding a clock and a date —
        //     is the user's to change now. The stored value stands and
        //     the reset dot appears on the slider, which is the rule for
        //     a default that changed. Lower it and the content takes
        //     over on the next frame.
        //
        //     island.topMargin  the same: 8 -> 11 is a proportion
        //     argument, not a stale consequence, so the stored 8 stands.
        //
        //   6 -> 7  the date leaves the resting pill, and the resting
        //           pill's width follows it down. Two keys:
        //
        //     island.idleWidth  152 -> 116. Normally a changed default
        //       is left to the user — the README says a new default
        //       needs the file deleted — because a size somebody set
        //       deliberately should survive. This one is different
        //       because 152 was not chosen, it was the width the pill
        //       happened to need while the resting row was a clock AND
        //       a date, and the date is gone. Leaving it would mean
        //       shipping a 152px pill with a clock in the middle of
        //       it: a shape the redesign never intended, and one whose
        //       only purpose was to hold text that is no longer there.
        //       It is a slider on the Island page, so it is one drag
        //       back either way.
        //
        //     island.fontSize  NOT reset. 13 -> 14 is a genuine
        //       default change, not a stale consequence, so it behaves
        //       like every other default: the stored 13 stands and the
        //       reset dot appears on the slider. That is the rule the
        //       other keys here are the exception to.
        //
        //   5 -> 6  the island is the iPhone's rather than a frosted
        //           desktop panel. Four keys are RESET rather than
        //           dropped, because each one was a deliberate
        //           decision about how the shell presents and every
        //           one of them is now the wrong decision — but none
        //           of them is gone, so nobody loses a setting:
        //
        //     island.opacity / popupOpacity  were 0.85 and 0.62, so
        //       the wallpaper showed through a compositor blur behind
        //       the shape. The Dynamic Island is #000 and samples
        //       nothing behind it at all. Reset to 1: the sliders
        //       still work, and somebody who liked the frost has it
        //       back in one drag.
        //
        //     appearance.fontIsland  was pinned to JetBrains Mono
        //       because a proportional clock changes width as the
        //       digits change. Cleared to "" rather than repointed,
        //       so it follows `fontFamily` — and keeps following it
        //       when a different face is picked later. IdleMode
        //       reserves the widest case instead, which is what the
        //       pin was standing in for.
        //
        //     The 2px drop on open was in code rather than in a
        //     setting, so there is nothing to migrate for it.
        //
        // The new keys (appearance.islandBlack, .islandEdge,
        // .islandShadow) need nothing: the merge keeps a declared
        // default for any key the file omits.
        //
        // The next one goes here:
        //
        //   if (from < 8) { adapter.island.foo = adapter.island.oldFoo }
        if (from < 6) {
            adapter.island.opacity = 1.0;
            adapter.island.popupOpacity = 1.0;
            adapter.appearance.fontIsland = "";
        }
        if (from < 7) {
            adapter.island.idleWidth = 116;
        }
        if (from < 9) {
            adapter.island.searchWidth = 460;
            adapter.island.searchFieldHeight = 40;
            adapter.island.searchRowHeight = 36;
            adapter.island.searchMaxRows = 6;
        }
        if (from < 10) {
            adapter.island.clipWidth = 460;
        }
        if (from < 11) {
            adapter.island.notifyWidth = 420;
        }
        adapter.version = currentVersion;

        // Through `commit`, not `persist` — see the note on that timer.
        // This runs from inside the `loaded` signal a reload raises, and
        // writing from in there drops one of the shell's own queued
        // operations every time a running shell migrates a settings file
        // somebody edited. The values are set either way; only the write's
        // timing moves.
        commit.restart();
    }

    // Reset needs the shipped values, but JsonAdapter holds only the
    // live ones once settings.json has been read over them.
    //
    // Rather than duplicating every default — which would drift from
    // the declarations below — they are snapshotted at startup, in
    // Component.onCompleted before settings.json is read over them.
    property var defaults: ({})

    Component.onCompleted: {
        // Order matters. The snapshot has to happen before the forced
        // read below, or it captures the stored values and "Reset"
        // resets to whatever the user already had.
        for (const name of sections) {
            const src = adapter[name];
            if (!src) continue;
            const copy = {};
            for (const key of Object.keys(src)) {
                if (typeof src[key] !== "function") copy[key] = src[key];
            }
            defaults[name] = copy;
        }

        // Forces settings.json in synchronously. The return value is
        // discarded — the call is made purely for its timing, because
        // `preload` and `blockLoading` both leave the read async until
        // an explicit text()/data().
        //
        // Do not remove. Without it the first frames evaluate against
        // the declared defaults, and values that escape early cannot
        // be followed by a later change — the layer-shell exclusive
        // zone being the one that stuck.
        file.text();
    }

    readonly property var sections:
        ["island", "motion", "appearance", "input", "idle", "lock",
         "wallpaper", "audio", "apps", "ui"]

    // "island.hoverGrace" -> the shipped value, or undefined if the
    // path isn't one we declare.
    function defaultFor(path) {
        if (!path) return undefined;
        const parts = path.split(".");
        if (parts.length !== 2) return undefined;
        const section = defaults[parts[0]];
        return section ? section[parts[1]] : undefined;
    }

    // Three keys because three different things read them: the pill
    // (island.radius), every panel and card (appearance.panelRadius),
    // and Hyprland (appearance.windowRounding, another process).
    //
    // appearance.radiusLink moves them together and the settings page
    // collapses to one slider. They stay separate underneath, which is
    // what lets the link be turned off.
    readonly property var radii: [
        "island.radius", "appearance.panelRadius", "appearance.windowRounding"
    ]

    function setRadius(v) {
        const r = Math.round(v);
        adapter.appearance.panelRadius = r;
        if (!adapter.appearance.radiusLink) return;
        adapter.island.radius = r;
        adapter.appearance.windowRounding = r;
    }

    function setRadiusLink(on) {
        adapter.appearance.radiusLink = on;
        // Linking has to pick a winner among three numbers that may
        // already disagree, and it is the one the single slider was
        // showing while unlinked — anything else changes the value
        // under a control the user is looking at.
        if (on) setRadius(adapter.appearance.panelRadius);
    }

    function resetOne(path) {
        const parts = path.split(".");
        if (parts.length !== 2) return;
        const live = adapter[parts[0]];
        const shipped = defaults[parts[0]];
        if (!live || !shipped) return;
        if (shipped[parts[1]] === undefined) return;
        live[parts[1]] = shipped[parts[1]];
    }

    function resetKey(path) {
        // Reverting one radius while the three are linked has to
        // revert all three, or the dot silently breaks the link it is
        // sitting next to. All three ship at 8, so this lands level.
        if (adapter.appearance.radiusLink && radii.indexOf(path) !== -1)
            for (const key of radii) resetOne(key);
        else
            resetOne(path);

        persist();
    }

    function resetSection(name) {
        const live = adapter[name];
        const shipped = defaults[name];
        if (!live || !shipped) return;

        // Machine-specific keys are left alone: resetting Appearance
        // should not throw away an icon theme the user picked,
        // resetting Wallpaper should not point at a directory that
        // may not exist, and resetting Apps should not name a
        // terminal that is not installed here.
        const keep = ["iconTheme", "cursorTheme", "gtkTheme", "directory",
                      "terminal"];

        for (const key of Object.keys(shipped)) {
            if (keep.indexOf(key) !== -1) continue;
            if (typeof shipped[key] === "function") continue;
            live[key] = shipped[key];
        }
        persist();
    }

    function resetAll() {
        for (const name of sections) resetSection(name);
    }

    // One write per burst of changes, and no reload of our own work.
    //
    // A write per property plus a reload per file change is lossy for
    // anything setting several keys at once (a Tempo writes eleven): a
    // reload landing mid-burst puts the adapter back to what was on
    // disk. The zero-interval timer is not a delay — it fires on the
    // next turn of the event loop, after the burst has landed and
    // before anything observes the file. Keep it.
    //
    // `settle` is started HERE and not only in `onSaved`, and that is
    // the fix for the flag this sets.
    //
    // `saving` guards `onFileChanged` against reloading our own write,
    // and it was cleared by `onSaved` alone. But `saved` fires only
    // when a write actually changes the file, so a `writeAdapter()`
    // with nothing to write never fired it and left `saving` stuck
    // true. From that moment EVERY later change to settings.json —
    // from the user, from a sync tool, from a migration being tested —
    // was discarded in `onFileChanged` as "our own write returning".
    // Silently, with nothing in the log.
    //
    // It read as a broken migration: editing the config to move a
    // version forward appeared to stamp `version` and leave every
    // value the migration was meant to change, and the symptom only
    // cleared when something else happened to reload the file. Three
    // identical external edits in a row were all dropped; the fourth
    // went through, because by then something had reloaded and
    // re-armed the write.
    //
    // Starting the timer here makes the flag's lifetime a property of
    // the write being queued rather than of a signal that may never
    // arrive.
    function persist() {
        file.saving = true;
        file.writeAdapter();
        settle.restart();
    }

    Timer {
        id: flush
        interval: 0
        onTriggered: root.persist()
    }

    Timer {
        id: settle
        interval: 150
        onTriggered: file.saving = false
    }

    // Clears `populating` once the load's burst of updates is over. A
    // timer rather than a flag set inside `onLoaded`, because the burst
    // arrives over several turns and this is the same "not a delay, the
    // next turn" idiom `flush` already uses.
    Timer {
        id: armed
        interval: 0
        onTriggered: root.populating = false
    }

    // A write issued from inside a load, held back until that load has
    // finished settling.
    //
    // Both callers of this timer write from inside a read: `onLoadFailed`
    // from inside the preload, and `migrate` from inside the `loaded`
    // that a reload raises. A `writeAdapter()` issued from either — and a
    // zero-interval timer is barely different from issuing it directly,
    // since the read is still being torn down on the next turn — collides
    // with it. Quickshell drops one queued operation and logs "got
    // operation finished from dropped operation".
    //
    // Nothing is lost: the write lands a moment later either way. But it
    // is a warning on every fresh install and on every migration of a
    // running shell, which is not a good enough reason to leave it, and
    // a warning that is always there is a warning nobody reads.
    //
    // 80ms is not a tuned number. It is longer than a load takes and
    // short enough that neither a first run nor a migration feels
    // different from any other write.
    Timer {
        id: commit
        interval: 80
        onTriggered: root.persist()
    }

    function save() {
        persist();
    }

    function reload() {
        file.reload();
    }

    FileView {
        id: file
        path: Paths.settings

        // Create it with the defaults below if it doesn't exist.
        preload: true
        printErrors: false

        // Makes the text() call in Component.onCompleted a blocking
        // read rather than a no-op. See the comment there.
        blockLoading: true

        watchChanges: true

        // True from the moment a write is queued until the change it
        // makes on disk has finished coming back around to us.
        property bool saving: false

        onFileChanged: {
            // Our own write, returning. Reloading here is what used to
            // destroy data — see `persist` below.
            if (file.saving) return;
            reload();
        }

        // `saved` fires when the write lands, and restarts the timer
        // that `persist` already started, so the flag outlives the
        // write rather than merely being queued alongside it. It is
        // not the only thing clearing the flag — see `persist` for why
        // it cannot be.
        //
        // The cost of the window is that a change somebody else makes
        // to settings.json within it is not picked up until the next
        // one, which is a trade worth making against losing a setting
        // the user just made.
        onSaved: settle.restart()

        // ONE handler for this signal, doing both of the two things it
        // has to do. It used to be only the debounced write, and a
        // second `onAdapterUpdated` added for the migration check is a
        // "property value set multiple times" error in QML — the two
        // have to live together.
        //
        // The order is the point. `migrateIfBehind` first, because it may
        // change the adapter; `flush` second, so the write it queues
        // covers whatever the migration just did rather than a frame of
        // it.
        //
        // The `populating` guard is the other half. Reading a file fills
        // the adapter in and fires this signal several times, and none of
        // those is a change anybody made — so flushing on them writes the
        // file straight back out. Harmless when it parsed. Not harmless
        // when it did not: the adapter then holds whatever survived, and
        // for a file truncated part-way through somebody's write the
        // surviving keys are real settings about to be joined by defaults
        // for the missing ones. That turns a recoverable file into a
        // lossy one, silently, in exactly the window a crash or a full
        // disk leaves a file in.
        //
        // So a load is not a change, and only a change flushes. Nothing
        // is lost by keeping quiet for the length of the burst: `migrate`
        // calls `persist()` itself rather than leaning on this, which is
        // the right way round anyway — a migration's write should not
        // depend on a debounce it does not control.
        //
        // Why the migration is checked HERE as well as on `onLoaded`:
        // Quickshell reloads the whole config when the QML changes on
        // disk, so editing Config.qml while the shell is running — which
        // is how a migration gets tested at all — re-enters this file with
        // the FILE still at the old version. If anything in that path
        // re-applies the adapter after `onLoaded` has stamped `version`,
        // the values go back to the file's and the stamp stays. The
        // result is a settings.json claiming the current version and
        // holding every value the migration was supposed to change — and
        // because the version matches, `migrate` is never called again.
        // Observed on searchWidth twice and on idleWidth once, and each
        // time it read as the migration simply being broken.
        //
        // Re-checking on the signal that says "the adapter's contents
        // just changed" is the fix that does not depend on knowing which
        // of those it was. `migrate` assigns rather than increments, so
        // running it twice costs a write and changes nothing.
        onAdapterUpdated: {
            root.migrateIfBehind();
            if (!root.populating) flush.restart();
        }

        onLoaded: {
            root.populating = true;
            armed.restart();
            root.migrateIfBehind();
        }

        // Only ENOENT may create a file. Everything else leaves it be.
        //
        // The comment this replaces said "genuinely absent" and assumed
        // `loadFailed` meant absent. It does not — the signal fires for
        // every way a load can fail, and a settings.json being rewritten
        // in place is the commonest of them. An editor that truncates
        // then writes, a sync tool copying over the top, a shell script
        // doing the same: each leaves a window where the file is empty or
        // half an object, which is a `loadFailed`, and this handler
        // answered that by writing the shipped defaults straight over
        // the user's configuration.
        //
        // That is not a lost migration, it is a lost settings file, and
        // it is silent — no signal, no log line, and the shell comes up
        // looking healthy on values the user never chose. It also
        // masqueraded as the migration bug, which is part of why that
        // one was so hard to pin down.
        //
        // `error` is a bare errno, and only one of them means the file
        // is not there. Measured against this shell rather than
        // assumed, because the distinction is the entire fix:
        //
        //     2  ENOENT   absent          -> create it
        //     3  EACCES   exists, no read -> leave it
        //     4  EISDIR   a directory     -> leave it
        //
        // A file that parses badly does not arrive here at all — the
        // FileView reads it fine and the JsonAdapter is what objects, so
        // the dangerous case is one step downstream of this handler and
        // is not reachable from it.
        //
        // Anything unrecognised resolves to doing nothing. Overwriting a
        // settings.json that exists is unrecoverable and quiet, so the
        // cost of being wrong has to land on the side of leaving the
        // user's file alone.
        onLoadFailed: function(error) {
            root.merged = true;

            if (error !== 2) {
                console.warn("Config: could not read", Paths.settings,
                             "(errno " + error + ") — leaving it as it is.",
                             "Repair or remove it to have defaults written.");
                return;
            }

            console.warn("Config: no settings file at", Paths.settings,
                         "— writing defaults.");

            commit.restart();
        }

        JsonAdapter {
            id: adapter

            // What a settings.json with no version key is taken to be
            // at, and therefore what a fresh install is stamped with.
            //
            // Kept equal to `currentVersion` on purpose. It was 4 while
            // currentVersion was 5, which meant a brand new file was
            // written as version 4 and then migrated on the next start
            // — a no-op, since a fresh file already holds the shipped
            // values, but a no-op that runs the whole migration path
            // to arrive at a state it was already in. Set this to
            // currentVersion whenever that moves.
            property int version: 14

            property JsonObject island: JsonObject {
                // "always" — on screen at all times, with the strip
                //            reserved so windows start below it
                // "smart"  — hidden until a window reaches the strip
                //            it sits in, then out of the way
                //
                // What "always" costs is topMargin + idleHeight, so
                // both of those are how you make it cost less; the
                // two sliders are on the Island page next to each
                // other for that reason.
                property string visibility: "always"

                // How long the island stays revealed after the cursor
                // leaves. Without a grace period hover and geometry
                // fight each other: the pill moves out from under the
                // cursor, hover drops, the pill hides, hover returns.
                property int hoverGrace: 600

                // Height in px of the hover strip at the top edge
                // that brings the island back once hidden.
                property int revealZone: 12

                // Hide while a window is fullscreen.
                property bool hideOnFullscreen: true

                // Collapse this long after the cursor leaves. 0 keeps
                // it open until clicked again.
                // 0 disables closing on hover-out, which is the
                // default: the control centre holds a calendar and
                // sliders whose own hover areas make the pill's hover
                // state unreliable, and a panel that closes because
                // the pointer grazed the wrong pixel is worse than one
                // you dismiss deliberately. Escape or a second click
                // on the pill closes it.
                property int collapseDelay: 0

                // How long a track change pops the island open.
                property int attentionDuration: 2500

                // ── The split ──────────────────────────────────
                //
                // Press and hold the pill and the island parts into two
                // lobes either side of the housing, which is what the
                // iPhone's does and the one behaviour of it that is
                // missing here. See docs/DESIGN.md.
                //
                // A media state, like iOS's: there is nothing to part
                // around if nothing is playing, so with no track the
                // hold does nothing and a click still opens the control
                // centre.
                //
                // 480ms. Apple's long press is about half a second and
                // a tenth; going under it turns the gesture into a
                // click you did not mean, and this one shares a button
                // with "open the control centre".
                property int splitHold: 480

                // The housing: how wide the gap between the lobes is.
                // How much SHORTER than they are is not a setting — it is
                // a function of the pill's height, and it lives in
                // Theme.housing beside Theme.corner, which is where every
                // other derived number in the shell lives.
                property int splitGap: 26

                // Each lobe. One number for both, so the pair is
                // symmetric — there is no camera here to justify an
                // asymmetry, and on a desktop a lopsided split reads as
                // a mistake rather than as a sensor housing.
                //
                // 56 against a 34px lobe height is 1.65:1, which is the
                // proportion the iPhone's lobes are. Narrower and the
                // corner (half the height, because a lobe is a capsule)
                // eats the straight edges and the lobe reads as a
                // circle, which is a dot rather than a half of anything.
                property int splitLobe: 56

                // Off entirely, for anyone who would rather the pill
                // were only a thing you click.
                property bool splitEnabled: true

                // 24-hour or 12-hour, for the pill, the lock screen and
                // the control centre's clock card alike. `true` is 24.
                //
                // A bool rather than a string, because that is what
                // this is: two states, and every other two-state thing
                // in the shell is a bool. `Clock.qml` owns the formats
                // and nothing else formats a time.
                property bool clock24h: true

                // Expand automatically when a new track starts.
                property bool expandOnTrackChange: false

                // Collapsed pill geometry.
                //
                // The resting pill is the clock and nothing else, and
                // its width is the clock plus `padding` either side.
                // `idleWidth` is a floor under that, not a target: set
                // it below the content and the content wins, which is
                // the normal case. 88 is just under a 14px clock's 42px
                // plus the 40 of padding, so the shipped pill is 88 x
                // 34 — 2.6:1.
                //
                // It used to be 116, which is the iPhone's *empty*
                // island scaled to this height, and that was the wrong
                // thing to copy: their resting island has nothing in it.
                // Put a small clock in a wide empty pill and it stops
                // reading as a hole in the screen and starts reading as
                // a small clock adrift in a lot of black. Matching their
                // emptiness would mean an island with no time in it,
                // which for a desktop shell is giving up the reason it
                // exists. So: the shape is sized to its contents.
                property int idleWidth: 88
                property int idleHeight: 34

                // The week under the clock: five days centred on today,
                // letters over numbers, today spelled out and in the
                // accent. It is the resting pill's second line, and it
                // is the only reason the pill is ever taller than the
                // pods — `idleHeight` stays what the circles are
                // measured against, and the strip is added on top of it
                // by the geometry table in Island.qml.
                //
                // Off means the pill is the clock again at exactly
                // `idleHeight`, which is the shape this shell shipped
                // with.
                property bool weekStrip: true

                // How far above the screen's edge the island sits. 11
                // is the iPhone's, as a proportion: about 11pt above a
                // 36.7pt island is 0.30, and 11 over 34 is 0.32. At 8 it
                // sat closer to the edge than the island is tall in
                // proportion terms, which is what made it look stuck to
                // the top of the screen rather than floating on it.
                property int topMargin: 11

                // There is no compact geometry, and there is no compact
                // mode. Hover used to be one: the pill grew 47% wider
                // and 6px taller and gained three buttons, for a pointer
                // passing over. It was the one movement in the shell
                // that could not be explained by looking at it, which is
                // the definition of the wrong animation. Hover is now a
                // cross-fade — the clock becomes the transport, in the
                // same shape — and every size change the pill makes is
                // either a panel or the split. `compactWidth` and
                // `compactHeight` went with it; see the migration note.

                // Pill typography. The clock is what you read at a
                // glance, so it gets its own size rather than
                // inheriting the generic small one.
                // Horizontal breathing room inside the pill. The
                // collapsed widths below are minimums; the pill grows
                // past them when content needs it, so this padding
                // always holds.
                property int padding: 20

                // 14 on the default 34px pill is 0.41 of the height,
                // which is the iPhone's ratio — about 15pt of type in
                // a 36.7pt island — and it is a large part of why the
                // text there reads as being *in* the shape rather than
                // printed on top of it. 13 was 0.38 and sat small.
                //
                // SemiBold rather than Bold for the same reason:
                // Apple's island labels are semibold, and at this size
                // full bold closes the counters up.
                property int fontSize: 14
                property int fontWeight: 600

                // ── Pods ──────────────────────────────────────
                //
                // Two circles flanking the pill: now playing on the
                // left, the control centre on the right. Both are
                // separate shapes rather than more content crammed into
                // the pill, so a glance at the top of the screen answers
                // "what is playing" and there is a target for changing
                // something without aiming at the pill.
                //
                // The left seat has held two things. It was the
                // workspace pod, answering "where am I" with forty
                // pixels of dashes; the pill says that itself now, in
                // the middle of the thing it is about and only when you
                // move, so the seat was given to the question the pill
                // *cannot* answer.
                property bool showMedia: true

                // The right circle: a button, and the click opens the
                // control centre. See ControlPod.qml for why it no
                // longer carries the tray behind a hover.
                property bool showControl: true

                // Space between a pod and the pill. Small enough that
                // the pair read as one object, wide enough that they
                // are two shapes and not a broken one.
                property int podGap: 8

                // Whether the pill names the track when one starts, and
                // for how long.
                //
                // A confirmation, not a control. The answer to "did that
                // work" is whether sound is coming out, and a title is
                // the cheapest available evidence of it — the sound
                // itself cannot be put on screen. What this is not is a
                // media widget: the split's right lobe and the control
                // centre both carry the full transport with artwork and a
                // scrubber, and this borrows the pill for a couple of
                // seconds to say one thing about it.
                property bool mediaFlash: true

                // How long the pill holds the title, in ms.
                //
                // Long, because a title is a phrase and has to be read
                // rather than recognised — a figure can be glanced at
                // and a line of text cannot. Long enough to finish the
                // sentence, short enough to be gone before you look up
                // a second time.
                property int mediaFlashDuration: 2500

                // The most the pill may grow to fit a title, in px.
                //
                // A ceiling, not a measurement — see the sampling note in
                // IdleMode. Track titles have no upper bound ("Bohemian
                // Rhapsody (Remastered 2011) [4K Remastered Audio]" is a
                // real one), so past this the title is elided. It is well
                // under half a 1440-wide screen on purpose: past about a
                // third of it the shape stops reading as a notification
                // and starts reading as a window.
                property int mediaMaxWidth: 260

                // `podPeek` and `podPeekDuration` were here, and went
                // with the tray that drove them. A pod peeked for a
                // moment when what it showed changed, which meant a tray
                // icon arriving, and both pods are one size now — so
                // there was no width for a peek to move. A setting left
                // describing a choice the shape no longer offers is
                // worse than a setting that is gone; see 12 -> 13 for
                // the same argument about `trayRestMax`.

                // Icons the tray pod showed at rest, and the "+n" for
                // the ones it held back. Both are gone: a circle at rest
                // holds one icon, and everything it was holding arrives
                // when the pod opens, which is where the "+n" was trying
                // to send you anyway. See the 12 -> 13 migration.

                // What a scroll over the collapsed pill does.
                // "workspace" — move one workspace either way
                // "volume"    — adjust volume and show the OSD
                // "none"      — nothing
                // While an OSD is up the gesture always adjusts that
                // value instead, whatever this says.
                property string scrollAction: "workspace"

                // Below 1.0 the wallpaper shows through and the
                // island-bar layer rule blurs it. At 1.0 the pill is
                // solid and the blur costs nothing but does nothing.
                //
                // 1.0 is the shipped value and it is the iPhone's: the
                // Dynamic Island is opaque black and samples nothing
                // behind it. That is most of why it reads as a hole
                // cut in the screen rather than a frosted widget
                // floating on it. The slider stays, because a desktop
                // island over a busy wallpaper is a legitimate thing
                // to want and this is not the only wallpaper.
                property real opacity: 1.0

                // The OSD and notification popups, which used to be
                // more translucent than the rest of the island on
                // purpose: they are the two modes that arrive over
                // whatever you were looking at rather than because you
                // asked, so they should sit over it rather than stamp
                // on it.
                //
                // That argument was an argument about translucency
                // being how those two are told apart from the rest,
                // and with the island opaque there is nothing left to
                // tell them apart that way — the OSD arriving is
                // already its own thing. So it ships equal to
                // `opacity`. Drop it below 1.0 and the distinction
                // comes straight back.
                property real popupOpacity: 1.0

                // The panel's corner. The resting pill ignores this and
                // is a capsule; see Theme.corner.
                property int radius: 8

                // `topMargin` lives with the pill's geometry above,
                // where the reasoning about floating rather than being
                // stuck to the edge belongs next to the shape it
                // positions.
                // ── Search / launcher ──────────────────────────
                //
                // Four numbers, and all four were too big. The launcher
                // is a field and a short list of application names; it
                // was built at the width of a control centre.
                //
                // 460 fits the longest thing it ever holds — an app name
                // and its generic name, on one line, at the body size —
                // with room to spare, and stops being a banner. 560 was
                // wide enough that the one result in it looked like a
                // card floating in a field.
                property int searchWidth: 460

                // 40, and the query at the large size. The field used to
                // be 46 with eighteen pixels of air above and below the
                // text, which reads as a strip that happens to contain
                // text rather than as something you type into.
                property int searchFieldHeight: 40

                // 36, at the body size rather than the small one. 40 rows
                // of 11px type is eight rows of nothing; 36 rows of 13px
                // is six rows of something, and six is as many as anyone
                // reads before scrolling.
                property int searchRowHeight: 36
                property int searchMaxRows: 6

                // The gap between the field and the results. Less than
                // `podGap`, because those two are one object and the
                // pods are not: at 8 with a shadow under each, the pair
                // read as two unrelated bars with a dark seam between
                // them. At 5 they read as a field and the menu under it.
                property int searchGap: 5

                // Power menu, also drawn inside the island.
                // Picker strip: wallpapers, palettes and icon sets.
                // Three wallpapers across at their real 16:9, two
                // rows deep. A strip of small cards fits in less, and
                // was what the picker used to be — but a wallpaper
                // cropped to a square tells you almost nothing about
                // the wallpaper.
                // Two rows have to actually fit, so the height is
                // the arithmetic rather than a round number:
                //   14 top + 26 tabs + 12 gap + 2 rows + 14 bottom,
                // where a row is (cell - gap) * 9/16 + gap and a cell
                // is a third of the width less the side margins.
                property int pickerWidth: 720
                property int pickerHeight: 340

                property int sessionWidth: 460
                property int sessionHeight: 128

                // Control centre. Only the width is a number now: the
                // height is whatever the layout below reaches, so a
                // panel can never be shorter than the controls in it.
                //
                // The width is six square cells — 6 * cell + 5 * gap +
                // 2 * pad at the defaults — and it is that, rather than
                // any particular number, which is the design: a
                // one-cell control is 48 across and 48 tall, so its
                // capsule is a circle, the way the reference's lock and
                // moon are. Anything wider and the corner buttons turn
                // into lozenges.
                property int controlWidth: 374

                // The grid the controls sit on. See
                // Services/ControlLayout.qml for what the layout
                // string means; the editor on the Control Centre
                // settings page is what normally writes it.
                property int controlColumns: 6
                property int controlCell: 48
                property int controlGap: 10
                property int controlPad: 18

                // The tray is here rather than in the right-hand pod,
                // and on its own row rather than squeezed into one of
                // the existing cells: it is a list, and a list is
                // wide. See TrayCard.qml.
                //
                // Two toggle rows, then Sound, Display and the
                // notification list — the rhythm the reference shell
                // uses, and the reason there is no calendar card here
                // any more: a month grid is the one thing in this panel
                // that cannot be glanced at. The week strip on the
                // resting pill already answers "what day is it".
                property string controlLayout: "wifi:0,0,3,1"
                    + ";dnd:3,0,2,1"
                    + ";lock:5,0,1,1"
                    + ";bluetooth:0,1,3,1"
                    + ";tray:3,1,2,1"
                    + ";battery:5,1,1,1,0"
                    + ";sound:0,2,6,1"
                    + ";display:0,3,6,1"
                    + ";notifications:0,4,6,3"

                // How much of the accent is washed over album art, so
                // a media card belongs to the theme whatever the
                // record label chose. 0 leaves the artwork alone.
                property real artTint: 0.28

                // Quick toggles with no daemon behind them yet. Kept
                // here so the tiles have somewhere to persist, and so
                // a notification server can read `dnd` when it lands.
                // Nudge for control-centre glyphs. The metrics-based
                // correction handles most icon fonts; this is here for
                // the ones it doesn't, so it's a slider rather than a
                // recompile.
                property int tileIconOffset: 0

                // Notification popup and history panel.
                //
                // The width, and nothing else. The height is
                // NotifyMode's `contentHeight` — it used to be
                // `notifyHeight`, `notifyActionHeight` and
                // `notifyReplyHeight` here, three fixed numbers summed in
                // the geometry table, which made a one-line notification
                // with nothing to act on exactly as tall as a three-line
                // one with four buttons. See the 10 -> 11 note.
                property int notifyWidth: 420
                property int notifyDuration: 5000
                property int notifyCriticalDuration: 12000
                property int centreWidth: 480

                // A ceiling, not a height. The centre is as tall as
                // the notifications in it — see
                // Modes/CentreMode.qml's contentHeight — and this is
                // where it stops growing and starts scrolling, which
                // at the shipped row height is four of them.
                //
                // No migration: the stored number carries over intact
                // and still means something true about the panel. It
                // governs fewer cases than it used to, which is not
                // the kind of change that can invalidate a value
                // somebody already chose.
                property int centreHeight: 440
                property int centreRowHeight: 88

                // How long after the last Tab the switcher commits.
                // Long enough to keep tabbing, short enough not to
                // feel like a wait once you have chosen.
                property int switcherCommitDelay: 650

                property int switcherWidth: 900
                property int switcherHeight: 176
                property int switcherTile: 84
                property int overviewCard: 220

                // Clipboard, and it is the launcher's twin — the same
                // field-over-a-shelf shape, so it gets the same width.
                // 620 was chosen when the launcher's was 560 and both were
                // too big; a clipboard entry is a line of text, and the
                // longest one anybody keeps is not 620px of it.
                property int clipWidth: 460
                property int clipRowHeight: 40
                property int clipMaxRows: 9

                property int authWidth: 460
                property int authHeight: 176

                property int osdWidth: 300
                property int osdHeight: 56
                property int osdDuration: 1600
                property int osdStep: 5

                // A file under /etc/pam.d. "login" exists everywhere;
                // a dedicated one would let a fingerprint reader work
                // here without enabling it for tty logins too.
                property string pamConfig: "login"

                property bool dnd: false
            }

            // Everything here is read through Services/Motion.qml,
            // which turns it into easing curves. The comments there
            // explain the model; these are the dials.
            property JsonObject motion: JsonObject {
                // These are the `snappy` tempo in Services/Motion.qml,
                // spelled out. The tempo tables are the place to argue
                // about them; this is only what a fresh install gets.
                //
                // A response is the spring's natural period, in
                // milliseconds, and reads as the speed of the thing.
                // It is not a duration: a spring has no end, only a
                // settle, and the shape is already where you are
                // looking well before it stops.
                property int expandResponse: 240
                property int collapseResponse: 190
                property int hoverResponse: 180
                property int popResponse: 280

                // Bounce, as Apple defines it: one minus the damping
                // fraction. 0 settles without overshoot, 0.15 is a
                // lift you feel, 0.3 is one you watch, 0.5 is a toy.
                //
                // Departures spring too, but barely. Half of what the
                // island dismisses is collapsing to nothing, and an
                // overshoot past nothing is a negative width.
                property real arriveBounce: 0.15
                property real departBounce: 0.05
                property real popBounce: 0.40

                // The content follows the shape rather than waiting
                // for it: it starts `contentLead` into the morph and
                // is fully in long before the shape has settled. On
                // the way out it leaves first, and faster.
                property int contentLead: 40
                property int contentInDuration: 150
                property int contentOutDuration: 90

                // Cross-fades that are not part of a morph: a colour
                // changing, an indicator appearing.
                property int fadeIn: 90
                property int fadeOut: 60

                // How small a surface starts before it grows into
                // place, so it reads as emerging from the shape it
                // came out of rather than being laid over it. 1.0 is
                // a plain cross-fade.
                property real emergeScale: 0.96

                // Takes the springs and the shape morphs away and
                // leaves the cross-fades, which are not a vestibular
                // trigger.
                property bool reduceMotion: false
            }

            property JsonObject appearance: JsonObject {
                // Where the colours come from.
                //
                //   "wallpaper"  matugen derives a Material palette
                //                from the image. wallpaper.scheme says
                //                how far it may stray from it.
                //   "preset"     a palette somebody else designed,
                //                used unchanged. See bin/island-palette.
                //
                // Both fill the same templates in matugen/templates/,
                // so the shell, GTK, Qt, KDE and the window borders
                // follow either one without knowing which it was.
                property string colorSource: "wallpaper"

                // Which one, under "preset". The names are
                // bin/island-palette's, which is also what the
                // settings page lists — it asks the script rather
                // than keeping a second copy of the list.
                property string preset: "catppuccin-mocha"

                // Wash the wallpaper toward the preset, so a
                // Catppuccin photograph under a Gruvbox shell stops
                // looking like two desktops at once.
                //
                // Only ever applies under "preset". Under "wallpaper"
                // the palette came out of the image, and tinting the
                // image toward it would be arguing with its own
                // answer.
                property bool tintWallpaper: true

                // Shell panels
                property real panelOpacity: 0.85
                property int panelRadius: 8
                // How far the desktop dims behind the settings window.
                // Blur alone doesn't separate a panel from a busy
                // wallpaper; a little scrim does.
                property real panelScrim: 0.0

                // The three fonts the shell draws with, all on the
                // Appearance page.
                //
                // fontIcons is the only one that is not a free choice:
                // the shell's icons are codepoints rather than images,
                // so it has to be a font that carries them. Keeping it
                // separate is what lets fontFamily be any face at all
                // — an interface drawn entirely in a monospace patch
                // is the cost of tying the two together.
                property string fontFamily: "Adwaita Sans"
                property string fontMono: "JetBrainsMono Nerd Font Mono"
                property string fontIcons: "JetBrainsMono Nerd Font"

                // The pill draws a clock, and a clock in a
                // proportional face changes width as the digits change
                // — so the shape at rest would breathe every minute.
                //
                // It used to be pinned to JetBrains Mono for that
                // reason, which is a real problem solved with a
                // typeface that is the reason the pill reads as a
                // terminal readout. The iPhone's is SF Pro: rounded,
                // proportional, humanist. So this now follows
                // `fontFamily` and the width is pinned where the
                // problem actually is — IdleMode measures the clock
                // against the widest string it will ever hold, so the
                // row is the same width at 11:11 as at 08:08.
                //
                // Empty means "follow the shell font", which is the
                // shipped answer. Set it to a family to pin it, and
                // the mono is still the right answer for anybody who
                // wants the clock not to move at all.
                property string fontIsland: ""

                // Whether the three corner radii move as one. See the
                // `radii` block above; the settings page shows one
                // slider while this is on and three while it is off.
                property bool radiusLink: true

                // ── The island's own presentation ──────────────
                //
                // Three, and they are the three the Dynamic Island
                // does that a frosted desktop panel does not. They
                // live under appearance rather than under island
                // because none of them is about the pill's geometry —
                // they are about how the shape sits on the screen.

                // Pure black, in every palette and in light mode too,
                // because that is what the iPhone's is: #000, always.
                // The alternative is the palette's surfaceLowest, which
                // is what the island was before and is a perfectly
                // good desktop shell — just not this one.
                property bool islandBlack: true

                // The hairline. A 1px outlineVariant ring plus a
                // second 1px white-at-14% ring two pixels inside it
                // (Widgets/Bezel.qml) — a doubled edge on every
                // surface in the island, including the pods.
                //
                // It was there to give the shape scale: one hairline
                // separates a surface from the wallpaper but gives no
                // size, and a pair has a width the eye can read a
                // radius off. That is a real argument, and it is why
                // the settings window and the lock screen keep theirs.
                // On a black island it is the most visible thing here
                // that is not on an iPhone, so it is off by default and
                // still one toggle away.
                property bool islandEdge: false

                // How far the shape is lifted off the wallpaper.
                //
                // A soft shadow under the island is a large part of what
                // makes it read as a physical object sitting above the
                // screen rather than a hole drawn in it, and Hyprland
                // cannot supply one: decoration:shadow is for toplevels
                // and a layer-shell surface gets nothing. So the island
                // casts its own — see Widgets/Shadow.qml.
                //
                // 0.7 is tight and dark, which is what the iPhone's is.
                // It was 0.55, and at that strength a black shape on a
                // dark wallpaper has no visible edge at all — the
                // shadow is the only thing separating the island from
                // the desktop behind it, so being able to see it is the
                // whole point. It is a contact shadow, not a drop: ten
                // pixels of spread, and the value is about the dark
                // edge where it meets the shape.
                property real islandShadow: 0.7

                // How square a corner is, as the exponent of the
                // superellipse it is drawn from. 2 is a circular arc
                // — what Qt's Rectangle draws — and 4 is roughly the
                // corner macOS draws.
                //
                // One number for the compositor and the shell both. It
                // goes to Hyprland as decoration:rounding_power for
                // windows, and packages/qml-squircle draws the shell's
                // own surfaces from it, so a window corner and a panel
                // corner are the same curve.
                property real cornerSmoothing: 4.0

                // Applied to GTK, Qt and the shell together.
                property string iconTheme: "Adwaita"
                property string cursorTheme: "Bibata-Modern-Ice"
                property int cursorSize: 24
                property string gtkTheme: "adw-gtk3"

                // Hyprland — applied live with hyprctl keyword
                property int blurSize: 8
                property int blurPasses: 3
                // Hyprland's blur cache. Off, a blurred surface is
                // recomputed every frame whether or not anything
                // behind it moved.
                property bool blurOptimize: true
                property real blurBrightness: 0.85
                property real blurContrast: 0.9
                property int gapsIn: 4
                property int gapsOut: 8
                property int borderSize: 1
                property int windowRounding: 8
                property real inactiveOpacity: 0.94
                property bool shadows: true
            }

            // Mouse and touchpad are configured per device, not
            // globally: every input option except force_no_accel can go
            // in an hl.device() block, so the two need not share a
            // sensitivity or an acceleration profile.
            property JsonObject input: JsonObject {
                // "adaptive" accelerates with speed; "flat" is 1:1.
                // Adaptive is libinput's own default and what every
                // other desktop hands you, so a pointer moved here
                // behaves the way the same hand expects it to
                // everywhere else. Flat is a gaming preference, not a
                // desktop one, and it was the wrong shipped default.
                property string mouseAccel: "adaptive"
                property real mouseSensitivity: 0.8
                property bool naturalScrollMouse: false

                property bool touchpadEnabled: true
                property string touchpadAccel: "adaptive"
                property real touchpadSensitivity: 0.8
                property bool tapToClick: true
                property bool naturalScroll: true
                property bool dragLock: true
                property bool disableWhileTyping: true
                // 1.0 is libinput's own scroll distance. 0.6 was a
                // thumb on the scale: it made every list in every
                // application slower than the touchpad's driver says
                // two fingers mean.
                property real scrollFactor: 1.0

                property int repeatRate: 25
                property int repeatDelay: 600
            }

            // Timeouts in seconds. Services/Idle.qml turns these into
            // hypridle.conf, so this is the only place they live.
            property JsonObject idle: JsonObject {
                property bool enabled: true
                property int dimTimeout: 240
                property int dimLevel: 10          // percent
                property int lockTimeout: 300
                property int screenOffTimeout: 360
                property int suspendTimeout: 1800
            }

            // The lock surface. Separate from `idle`, which decides
            // WHEN the screen locks — these are what it looks like and
            // how it behaves once it has.
            property JsonObject lock: JsonObject {
                // How much of the wallpaper survives behind the lock.
                // The scrim is the palette's darkest surface rather
                // than black, so the lock belongs to the same theme as
                // the rest of the shell instead of being the one
                // surface that ignores it.
                property real scrimOpacity: 0.60

                // Qt's Gaussian over the wallpaper, 0 to 1.
                //
                // Deliberately not appearance.blurSize. That one is
                // Hyprland resampling whatever sits behind a panel;
                // this is one full-screen image blurred in our own
                // scene graph, and it is static — it costs a frame
                // when the lock engages and nothing after. Sharing a
                // number would tie two unrelated costs together.
                property real blur: 0.50

                // Wrong passwords before the field stops taking them,
                // and for how long. 0 attempts turns the wait off.
                //
                // Deliberately small. This is a delay that costs a
                // stranger their patience, not a lockout that costs
                // you your session — anyone holding the keyboard can
                // already reach a TTY, so a long one only ever
                // punishes the person who mistyped.
                property int attemptsBeforeDelay: 5
                property int delaySeconds: 30

                // The battery at the foot's right edge, where there
                // is one to report. Worth having on a laptop, noise
                // on a desktop, and Battery.present already hides it
                // where there is nothing to say.
                property bool showBattery: true

                // The Wi-Fi or wired glyph beside it. The same edge
                // the login window puts a machine's own state on, and
                // the one question a locked screen can answer without
                // a password: is this machine still on the network.
                property bool showNetwork: true

                // Sleep, Restart and Shut Down at the foot's left
                // edge. Off for anyone who would rather a locked
                // screen could not be asked to switch the machine
                // off — the field in the middle is the only control
                // this surface strictly needs.
                property bool showActions: true
            }

            property JsonObject wallpaper: JsonObject {
                property string directory: Quickshell.env("HOME") + "/Pictures/Wallpapers"
                property int crossfadeDuration: 450

                // How a wallpaper-derived palette is read. The five
                // worth offering are listed in Services/Theming.qml,
                // which is what both the settings page and the picker
                // show; matugen accepts the other four too if one is
                // written here by hand.
                //
                // tonal-spot is Material's own default, and matugen's.
                property string scheme: "scheme-tonal-spot"

                // Cycle wallpapers on a timer. 0 disables.
                property int rotateMinutes: 0

                // Give each monitor its own wallpaper. The palette
                // still comes from one of them — the focused one —
                // because there is one GTK theme and one set of
                // window borders to drive.
                property bool perMonitor: false
            }

            // How the volume the shell shows relates to the volume
            // PipeWire applies. See Services/Audio.qml, which is
            // where the two scales are spelled out.
            property JsonObject audio: JsonObject {
                // "system"     — the scale wpctl, pactl and
                //                pavucontrol all use, so the numbers
                //                agree with every other tool
                // "perceptual" — remapped so half way along the
                //                slider sounds half as loud, at the
                //                cost of that agreement
                property string volumeCurve: "system"
            }

            // Default applications.
            //
            // Only the terminal lives here. Everything else on the
            // Apps page is a MIME handler, and those belong to the
            // desktop rather than to this shell — they go in
            // mimeapps.list, where every other application can read
            // them. A terminal emulator is the handler of no type at
            // all, so there is nowhere else for the choice to go.
            property JsonObject apps: JsonObject {
                // A desktop entry id, such as "kitty.desktop". Empty
                // means the one hypr/env.lua ships with.
                property string terminal: ""
            }

            // How the settings window is being looked at, rather than
            // anything about the shell. It lives in the file because
            // the answer should survive closing the window — somebody
            // who has turned the numbers on is not asking to be shown
            // the short version again tomorrow.
            property JsonObject ui: JsonObject {
                // Most of what is in Settings is a number you set once
                // and never think about again, and a page that opens
                // with thirty of them is a page nobody reads. Off,
                // every row marked `advanced` is hidden.
                property bool advanced: false
            }
        }
    }
}
