import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import Quickshell.Widgets
import QtQuick

import "root:/Services"
import "root:/Island/Modes"
import "root:/Island/Pods"
import "root:/Widgets"
import "root:/Widgets/Control"

Variants {
    model: Quickshell.screens

    PanelWindow {
        id: root
        required property var modelData

        screen: modelData

        // One island per screen is right for the pill. It is wrong for
        // everything below that can only exist once — the IPC handlers,
        // the notification popup and the exclusive keyboard grab. Those
        // are gated on this, so they belong to the monitor you are
        // actually looking at and move with it. See Services/Screens.qml.
        readonly property bool primary:
            modelData && modelData.name === Screens.activeName

        // Qt scales the scene by ONE factor for the whole application
        // (Screens.baseScale), so on a mixed-DPI setup the island on a
        // differently-scaled monitor is drawn at the wrong size. This
        // is the correction for that screen, and exactly 1 whenever
        // every monitor shares a scale — so a uniform setup, including
        // every single-monitor one, is untouched.
        readonly property real uiScale: {
            if (!modelData || modelData.devicePixelRatio <= 0) return 1;
            const base = Screens.baseScale;
            return base > 0 ? modelData.devicePixelRatio / base : 1;
        }

        // The resting pill's height: the pods' height, plus the week
        // when the clock is carrying one. Everything that measures the
        // *pill* reads this — the exclusive zone, the window, the
        // geometry table, the control panel's y — and everything that
        // measures a pod keeps reading `idleHeight`, because a circle
        // that grew when the clock grew a second line would be the
        // strip changing a shape it is not part of.
        readonly property int restPillH:
            Config.island.idleHeight + idleMode.stripHeight

        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.namespace: "island-bar"
        // Only the collapsed height, and only in "always" mode. A zone
        // that tracked the pill would shove every window down each time
        // it expanded.
        // "always" reserves the strip so windows start below the
        // island. Only the collapsed height is ever reserved —
        // reserving the expanded height would shove every window on
        // screen down each time the pill opens.
        // The pill sits at topMargin and is idleHeight tall, so
        // topMargin + idleHeight is exactly what it takes to clear
        // it. This used to reserve a second margin underneath as
        // well — 50px rather than 42 — which bought a gap nothing
        // needed and charged every window on every workspace for it.
        //
        // Only the resting height is reserved, and that is now the only
        // height the pill has outside the panels. It used to overhang
        // this by six pixels on hover, on the reasoning that reserving
        // the hovered height means paying for it the rest of the time —
        // which was true, and which stopped mattering when hover stopped
        // changing the height. A reservation that is exactly the shape
        // above it is a reservation that never has to be argued about.
        exclusiveZone: Config.island.visibility === "always"
            ? (Config.island.topMargin + root.restPillH)
              * root.uiScale
            : 0

        // Only grab the keyboard while searching. Holding exclusive
        // focus the rest of the time would swallow every keystroke
        // meant for the focused app.
        WlrLayershell.keyboardFocus: {
            if (!root.primary) return WlrKeyboardFocus.None;

            if (searching || sessionOpen || centreOpen || picker !== ""
                || Polkit.active || clipOpen || switcherOpen
                || overviewOpen || root.expanded)
                return WlrKeyboardFocus.Exclusive;

            // A notification offering a reply has to be typeable. It
            // must not be an exclusive grab, though: popups arrive
            // unbidden, and taking the keyboard off whatever you were
            // typing in because a chat message landed is how a shell
            // earns a reputation for eating keystrokes. OnDemand hands
            // the keyboard over only once you click the popup.
            if (notice !== null && notice.hasReply)
                return WlrKeyboardFocus.OnDemand;

            return WlrKeyboardFocus.None;
        }

        property bool searching: false
        property bool sessionOpen: false
        property bool expanded: false

        // Started when the panel opens and not only when the pointer
        // leaves the pill: the usual way to open it is to press the
        // control pod, and from there the pointer can wander off
        // without ever crossing the pill — the pill's hover would never
        // change, so nothing would ever start the timer and the panel
        // would have no way of closing itself. Guarded by the delay,
        // which defaults to 0: closing on your own movement is opt-in.
        onExpandedChanged: {
            if (root.expanded && Config.island.collapseDelay > 0)
                collapseTimer.restart();
        }

        // The island parted around its housing. See
        // Island/SplitLobe.qml — it is a media state, so this is only
        // ever true with a track playing, and `island.mode` below is
        // what decides whether the mode is allowed to happen at all.
        property bool split: false

        // The now-playing card, open under the row. It is not a mode:
        // the pill keeps its clock while it is up, because a card
        // hanging below the row changes nothing about the shape above
        // it. See `mediaHost` for the panel and `toggleMediaCard` for
        // the press that opens it.
        //
        // Cleared rather than bounded — the three ways it can outlive
        // its reason are a heavier mode taking the island somewhere
        // else, the pod it hangs from going away, and a click anywhere
        // at all, and each of those has the clearing where the cause
        // is.
        property bool mediaOpen: false

        property string picker: ""          // "" | wallpaper | theme

        // True while the cursor is over either pod. The pods are
        // separate shapes but one object with the pill: hovering any
        // of the three lifts all of them, and keeps the island out
        // while you are reading one.
        readonly property bool podsHovered: leftPod.hovered || rightPod.hovered
        readonly property bool podsHeld:
            podsHovered || leftPod.pinned || rightPod.pinned

        // Touchpads deliver a burst of small deltas per gesture, so a
        // threshold and a cooldown turn one flick into one step rather
        // than four.
        property int scrollAccum: 0

        // ── Switcher and overview ────────────────────────────

        property bool switcherOpen: false
        property int switchIndex: 0
        property bool overviewOpen: false

        // The switcher renders and indexes this snapshot rather than
        // Wm.allWindows directly.
        //
        // Wm re-sorts allWindows by focus history on every compositor
        // event, and the refresh that openSwitcher kicks off is async —
        // so the list could be re-ordered underneath a gesture already
        // in progress, and the second Tab landed somewhere unrelated to
        // what the first one had selected.
        property var switchList: []

        readonly property var switchTarget:
            switchList.length > switchIndex ? switchList[switchIndex] : null

        // Windows opening and closing mid-gesture still have to show
        // up, but re-sorting is what breaks the selection. So the
        // opening order is kept, closed windows drop out, new ones
        // append — and the selected window is tracked by address, so
        // it only moves if it actually went away.
        function syncSwitchList() {
            if (!switcherOpen) return;

            const live = Wm.allWindows;
            const byAddr = {};
            for (const w of live) byAddr[w.address] = w;

            const selected = switchTarget ? switchTarget.address : "";

            const kept = switchList
                .filter(w => byAddr[w.address])
                .map(w => byAddr[w.address]);

            const known = {};
            for (const w of kept) known[w.address] = true;
            for (const w of live) if (!known[w.address]) kept.push(w);

            switchList = kept;

            const i = kept.findIndex(w => w.address === selected);
            switchIndex = i >= 0
                ? i
                : Math.min(switchIndex, Math.max(0, kept.length - 1));
        }

        Connections {
            target: Wm
            function onAllWindowsChanged() { root.syncSwitchList() }
        }

        function openSwitcher(step) {
            if (!switcherOpen) {
                switcherOpen = true;
                switchList = Wm.allWindows.slice();
                // Start on the previously focused window, which is what
                // a single Alt+Tab is asking for.
                switchIndex = switchList.length > 1 ? 1 : 0;
                // Anything that arrived since the last event is folded
                // in by syncSwitchList, which preserves the selection.
                Wm.refresh();
            } else {
                const n = switchList.length;
                if (n > 0) switchIndex = (switchIndex + step + n) % n;
            }
            // Commits itself once tabbing stops. Detecting the Alt
            // release would need a bind on the bare modifier, which
            // makes the compositor swallow every other Alt shortcut.
            switchCommit.restart();
        }

        Timer {
            id: switchCommit
            interval: Config.island.switcherCommitDelay
            onTriggered: root.activateSwitch()
        }

        function activateSwitch() {
            if (!switcherOpen) return;
            switchCommit.stop();
            const target = switchTarget;
            switcherOpen = false;
            if (target) {
                const addr = target.address;
                afterSurfaceDown(() => Wm.focusWindow(addr));
            }
        }

        function cancelSwitch() {
            switchCommit.stop();
            switcherOpen = false;
        }

        // Run something once this surface has actually released its
        // exclusive keyboard grab.
        //
        // NOT Qt.callLater — it runs before the event loop returns to
        // Wayland, so the dispatch reaches Hyprland while the island
        // still holds the grab, and the compositor restores focus over
        // the top of it. That is the whole of the Alt+Tab bug. It
        // appears to work across workspaces only because switching
        // workspace leaves the restore nothing to aim at.
        property var deferred: null

        function afterSurfaceDown(fn) {
            deferred = fn;
            surfaceDown.restart();
        }

        Timer {
            id: surfaceDown
            interval: 90
            onTriggered: {
                const fn = root.deferred;
                root.deferred = null;
                if (fn) fn();
            }
        }

        // Moving to the other monitor leaves whatever was open here
        // with no keyboard grab and no IPC handlers, so it would sit
        // there until clicked. Hand the shape back instead.
        onPrimaryChanged: {
            if (root.primary) return;
            searching = false;
            sessionOpen = false;
            centreOpen = false;
            clipOpen = false;
            overviewOpen = false;
            picker = "";
            expanded = false;
            notice = null;
            cancelSwitch();
        }

        function openOverview() {
            Wm.refresh();
            overviewOpen = true;
            searching = false;
            sessionOpen = false;
            centreOpen = false;
            clipOpen = false;
            picker = "";
            expanded = false;
        }

        function closeOverview() { overviewOpen = false }

        // Scrolling over the island moves one workspace. It replaces
        // the gesture that used to cycle the collapsed pill between
        // three faces — which was the wrong thing to spend the only
        // gesture the island has on, because two of those three faces
        // are pods now and the third is the pill itself.
        //
        // Up goes left, matching the dashes in the pod and SUPER+left.
        function scrollWorkspace(delta) {
            if (scrollCooldown.running) return;

            scrollAccum += delta;
            if (Math.abs(scrollAccum) < 120) return;

            const step = scrollAccum > 0 ? -1 : 1;
            scrollAccum = 0;
            scrollCooldown.restart();

            Wm.cycleWorkspace(step);
        }

        Timer {
            id: scrollCooldown
            interval: 220
        }

        // The filter, here rather than in ClipboardMode. The geometry
        // needs its length and the shelf's list needs its contents,
        // and it used to be computed in both places — two filters over
        // the same entries that were only ever equal by inspection.
        readonly property var clipFiltered: {
            const q = clipQuery.trim().toLowerCase();
            if (q === "") return Clipboard.entries;
            return Clipboard.entries.filter(
                e => e.preview.toLowerCase().includes(q));
        }

        readonly property int clipRows: clipFiltered.length

        property bool clipOpen: false
        property string clipQuery: ""
        property Item clipInput: null
        property Item clipList: null

        function openClipboard() {
            clipOpen = true;
            searching = false;
            sessionOpen = false;
            centreOpen = false;
            picker = "";
            expanded = false;
            clipQuery = "";
            Clipboard.refresh();
            if (clipInput) {
                clipInput.text = "";
                clipInput.forceActiveFocus();
            }
            if (clipList) clipList.currentIndex = 0;
        }

        function closeClipboard() {
            clipOpen = false;
            clipQuery = "";
        }

        function copySelected() {
            if (!clipList) return;
            // clipFiltered, not a third filter written out again here.
            // There were three — this one, the geometry's row count and
            // the mode's own — over the same entries, equal only by
            // inspection and only until one of them was edited.
            const e = clipFiltered[clipList.currentIndex];
            if (e) {
                Clipboard.copy(e.id);
                closeClipboard();
            }
        }

        property var notice: null
        property bool centreOpen: false

        // Set by NotifyMode while its inline reply field holds the
        // keyboard. A popup that disappears mid-sentence loses what
        // you typed, so every timer that would clear it defers.
        property bool replyFocused: false

        function openCentre() {
            centreOpen = true;
            picker = "";
            searching = false;
            sessionOpen = false;
            expanded = false;
            // Opening the centre is looking at the history, so anything
            // still queued has been seen by implication and would only
            // pop up over the list a moment later.
            Notifications.clearPending();
            notice = null;
        }

        // Marked on the way OUT, not on the way in.
        //
        // It was marked on open, which is defensible — you are looking at
        // the list — and useless, because `readAt` became newer than
        // every row before the first one was drawn. So the unread dot
        // could never be seen: not on the rows that were already there,
        // and not on the ones that arrived while you were reading them.
        // A mark that is invisible in the one state it exists for is not
        // a mark. Closing is the moment "you have seen these" becomes
        // true, so that is where it is stamped.
        function closeCentre() {
            centreOpen = false;
            Notifications.markRead();
        }

        // One notification goes away, and the next one comes up. Clicking
        // the body, sending a reply and letting the timer expire all mean
        // the same thing here, so they all land here and the queue is
        // drained one entry per gesture.
        function dismissNotice() {
            if (Notifications.advance() === null) {
                notice = null;
                noticeTimer.stop();
            }
        }

        // Everything goes away, queue included. This is the "I am done"
        // path — clicking away from the island — and it is deliberately
        // not `dismissNotice` repeated: three notifications arriving while
        // you were reading the first should not then walk across the
        // screen one after another because you clicked on the desktop.
        function dismissAllNotices() {
            Notifications.clearPending();
            notice = null;
            noticeTimer.stop();
        }

        function openPicker(kind) {
            picker = kind;
            searching = false;
            sessionOpen = false;
            expanded = false;
            if (kind === "wallpaper") Wallpaper.refresh();
        }

        function closePicker() { picker = "" }

        // The control centre is what "expanded" means. Clicking the
        // pill opens it; there's no separate mode to get lost in.
        function openControl() {
            searching = false;
            sessionOpen = false;
            root.expanded = true;
        }

        function closeControl() { root.expanded = false }

        // The media pod's press: a card or nothing. The control centre
        // is closed on the way in because the two panels would sit on
        // top of each other — they are the same gesture aimed at two
        // buttons on the same row, and only one of them can be down.
        function toggleMediaCard() {
            // Closing is unconditional: a card that could not be put
            // down because something arrived over it would be a card
            // that stuck.
            if (root.mediaOpen) {
                root.mediaOpen = false;
                return;
            }

            if (!island.media || !Config.island.showMedia) return;

            // A mode that owns the whole island is not the row's to
            // talk over — the card is an idle surface, so it opens
            // from rest, or from the control centre, which it takes
            // down with it for the reason above. A notification, the
            // launcher and a dialog all win, and `onModeChanged`
            // has already cleared the flag by then anyway.
            if (island.mode !== "idle" && !island.isControl) return;

            closeControl();
            root.mediaOpen = true;
        }

        property string armed: ""
        property int sessionIndex: 0

        function openSession() {
            sessionOpen = true;
            searching = false;
            root.expanded = false;
            armed = "";
            sessionIndex = 0;
        }

        function moveSession(delta) {
            const n = Session.actions.length;
            sessionIndex = (sessionIndex + delta + n) % n;
            // Moving off an armed action disarms it, so you can't
            // arrow onto shutdown and hit Enter by reflex.
            armed = "";
        }

        function activateSession() {
            const a = Session.actions[sessionIndex];
            if (a) runAction(a.id);
        }

        function closeSession() {
            sessionOpen = false;
            armed = "";
        }

        function runAction(id) {
            // Destructive actions want a second press. Anything else
            // runs straight away.
            if (Session.isDestructive(id) && armed !== id) {
                armed = id;
                armTimer.restart();
                return;
            }
            closeSession();
            Session.run(id);
        }

        // Held rather than looked up by id: these live inside the pill,
        // and inside a Variants delegate that nesting doesn't resolve
        // from functions declared out here.
        property Item searchInput: null
        property Item searchList: null

        function openSearch() {
            searching = true;
            root.expanded = false;
            Search.query = "";
            if (searchInput) {
                searchInput.text = "";
                searchInput.forceActiveFocus();
            }
            if (searchList) searchList.currentIndex = 0;
        }

        function closeSearch() {
            searching = false;
            Search.query = "";
            if (searchInput) searchInput.text = "";
        }

        function runSelected() {
            const i = searchList ? searchList.currentIndex : 0;
            const e = Search.results[i];
            if (e) {
                Search.launch(e);
                closeSearch();
            }
        }

        anchors {
            top: true
            left: true
            right: true
        }
        // Headroom for the largest state the pill can reach. The
        // surface never resizes — it's a fixed strip the pill morphs
        // inside — so this has to clear the tallest content plus its
        // margin, or the bottom edge gets clipped by the window.
        //
        //   control centre + media strip + top margin + slack
        //
        // Full screen height, always, and the measured strip is gone.
        // It was resized to full height only while a mode was open, so
        // that the click-away surface would have a region to live in —
        // an input region cannot reach outside its own surface. That
        // works, and it flashes: resizing a layer surface reconfigures
        // it, and doing that on the way out of a mode, underneath a
        // panel that is still fading, put a visible glitch on every
        // close. Two resizes per open/close cycle to save a surface that
        // was never expensive.
        //
        // It is not expensive because this shell already keeps a
        // full-screen surface — `island-wallpaper`, on the same
        // connection, every frame of every workspace. One more
        // transparent one costs a composite, and in exchange the island
        // never resizes and the click-away region is always available.
        //
        // The surface being full height does not make the island full
        // height: `mask` is what the pointer sees, and it is still the
        // island and its pods when nothing is open. Nothing is drawn
        // outside the pill either — the root is `color: "transparent"`.
        implicitHeight: root.modelData
            ? root.modelData.height
            : (Math.max(
                    ControlLayout.panelHeight,
                    // The now-playing card hangs below the row too,
                    // and further left than the control panel reaches
                    // — see `mediaHost`.
                    mediaHost.height,
                    Config.island.pickerHeight,
                    Config.island.centreHeight,
                    Config.island.authHeight,
                    Config.island.switcherHeight,
                    // Two surfaces and the gap between them
                    // now, not one panel: the bar, the pod
                    // gap, and a full shelf under it.
                    Config.island.searchFieldHeight
                      + Config.island.podGap
                      + Theme.spacingSmall * 2 + Theme.padCard * 2
                      + Config.island.clipMaxRows * Config.island.clipRowHeight,
                    Config.island.searchFieldHeight
                      + Config.island.podGap
                      + Theme.spacingSmall * 2 + Theme.padCard * 2
                      + Config.island.searchMaxRows * Config.island.searchRowHeight)
              // The control centre hangs *below* the resting row now
              // rather than replacing it, so the row and the gap
              // underneath it are part of what has to fit. See
              // `controlHost`.
              + root.restPillH
              + Config.island.podGap
              + Config.island.topMargin
              + 60) * root.uiScale
        color: "transparent"

        // The modes are handed `win`, not the singleton, and reach
        // for these dozens of times. Everything about how the shape
        // itself moves lives on `island` below, because it depends on
        // which way the shape is going.
        readonly property int fadeOut: Motion.fadeOut
        readonly property int fadeIn: Motion.fadeIn

        readonly property string visibilityMode: Config.island.visibility
        readonly property int revealZone:
            Config.island.revealZone * root.uiScale
        property bool demandsAttention: false

        // The whole object, pods included. Smart hiding asks whether a
        // window has reached the island, and a window that has reached
        // the control pod has reached the island — the pods are not a
        // separate thing to be overlapped separately.
        //
        // The split lobes are the same question asked of a different
        // shape, and they are exclusive with the pods by mode rather
        // than by arithmetic: the pods undock the moment the island
        // leaves idle, and the lobes exist only in a mode idle does not
        // have. Summing both would bulge the rect mid-morph, because
        // each is on a spring leaving and the other is arriving.
        readonly property real leftSpan:
            island.mode === "split"
                ? (leftLobe.shown
                    ? leftLobe.width + Config.island.splitGap : 0)
                : (leftPod.width > 0 ? leftPod.width + Config.island.podGap : 0)
        readonly property real rightSpan:
            island.mode === "split"
                ? (rightLobe.shown
                    ? rightLobe.width + Config.island.splitGap : 0)
                : (rightPod.width > 0 ? rightPod.width + Config.island.podGap : 0)

        readonly property rect islandRect: Qt.rect(
            (screen.width - pill.width * root.uiScale) / 2
                - leftSpan * root.uiScale,
            Config.island.topMargin * root.uiScale,
            (pill.width + leftSpan + rightSpan) * root.uiScale,
            pill.height * root.uiScale)

        readonly property bool overlapped: {
            const r = islandRect;
            for (const w of Wm.windows) {
                if (w.x < r.x + r.width && w.x + w.w > r.x
                    && w.y < r.y + r.height && w.y + w.h > r.y)
                    return true;
            }
            return false;
        }

        readonly property bool occluded: Wm.fullscreen || overlapped

        property bool hoverLatch: false

        Timer {
            id: unlatch
            interval: Config.island.hoverGrace
            onTriggered: root.hoverLatch = false
        }

        function touch(inside) {
            if (inside) {
                hoverLatch = true;
                unlatch.stop();
            } else {
                unlatch.restart();
            }
        }

        // Depends only on plain booleans. Referencing island.mode here
        // would be circular, since state reads `revealed`.
        readonly property bool revealed:
            visibilityMode !== "smart"
            || !occluded
            || demandsAttention
            || hoverLatch
            || podsHeld
            || root.expanded
            || root.split
            || searching
            || sessionOpen
            || picker !== ""
            || notice !== null
            || centreOpen
            || mediaHost.open

        // The pods sit outside the pill, and the pill's item is what
        // the mask was. Without a region of their own they would be
        // drawn and never clickable — and the gap between a pod and the
        // pill stays click-through, which is the point of not simply
        // widening the island's own rectangle to cover all three.
        //
        // The lobes need one each for the same reason, and the gap
        // between a lobe and the housing stays click-through so a click
        // beside the island is a click on whatever is behind it.
        mask: Region {
            item: root.revealed ? island : revealStrip
            Region { item: leftPod }
            Region { item: rightPod }
            // The panel, which now hangs outside the island's own rect
            // and would otherwise be drawn and unclickable — every
            // press in it would land on the click-away surface
            // underneath instead. Off when it is shut, for the same
            // reason `dismissCatcher` is: a region with nothing behind
            // it is a dead rectangle.
            Region { item: island.isControl ? controlHost : null }
            // The now-playing card, for the reason `controlHost` is
            // here: it hangs outside the island's own rect, and
            // without a region every press in it would land on the
            // click-away surface underneath — the transport would
            // close the panel instead of pausing the track. Off when
            // the panel is shut, for the same reason `dismissCatcher`
            // is: a region with nothing behind it is a dead rectangle.
            Region { item: mediaHost.open ? mediaHost : null }
            Region { item: leftLobe }
            Region { item: rightLobe }
            // The click-away surface, and only while a mode is open.
            // Listed last so the island's own regions are tested first;
            // it is a full-window rectangle, so anything that overlaps
            // it and is not listed above would be unreachable.
            //
            // `null` rather than an `enabled` flag: `Region` has no such
            // property, and a null item is how a region is switched off.
            Region { item: root.dismissArmed ? dismissCatcher : null }
        }

        property bool autoExpanded: false

        Connections {
            target: Player
            function onTrackChanged() {
                root.demandsAttention = true;
                if (Config.island.expandOnTrackChange) {
                    root.autoExpanded = true;
                    root.expanded = true;
                }
                attentionTimer.restart();
            }
        }

        // An armed action disarms itself if you hesitate, so a stray
        // click can't leave the shutdown button primed.
        Timer {
            id: armTimer
            interval: 3000
            onTriggered: root.armed = ""
        }

        Connections {
            target: Notifications
            function onArrived(entry) {
                // One popup, on the screen you are looking at. Without
                // this every monitor grows the same notification.
                if (!root.primary) return;
                root.notice = entry;

                // Coerced and floored. An undefined duration makes the
                // interval NaN, the timer never fires, and the popup
                // stays up forever — which pins the island in `notify`
                // and makes every other mode, smart hiding included,
                // look broken.
                const want = entry && entry.critical
                    ? Config.island.notifyCriticalDuration
                    : Config.island.notifyDuration;

                noticeTimer.interval = Math.max(1000, Number(want) || 5000);
                noticeTimer.restart();
            }
        }

        Timer {
            id: noticeTimer
            interval: 5000
            onTriggered: {
                if (root.replyFocused) {
                    // Come back once they've stopped typing rather
                    // than taking the half-written reply away.
                    noticeTimer.restart();
                    return;
                }
                // Advance rather than clear: if anything else arrived
                // while this was up it goes on screen now, with its own
                // duration, via the same path the first one took.
                if (Notifications.advance() === null)
                    root.notice = null;
            }
        }

        // A popup that outlives its timer holds the island hostage, so
        // this clears one that has been up far longer than any
        // configured duration regardless of why the timer missed.
        Timer {
            running: root.notice !== null
            interval: 30000
            onTriggered: {
                if (!root.replyFocused) root.notice = null;
            }
        }

        Timer {
            id: attentionTimer
            interval: Config.island.attentionDuration
            onTriggered: {
                root.demandsAttention = false;
                if (root.autoExpanded) {
                    root.expanded = false;
                    root.autoExpanded = false;
                }
            }
        }

        // ── Click outside to dismiss ───────────────────────────
        //
        // The mask above is shaped to the island and its pods on
        // purpose: a click beside the island is a click on whatever is
        // behind it, and an island that ate every click along the top
        // of the screen would be unusable. The cost of that decision is
        // that the island never receives an outside click at all — the
        // event could not arrive, rather than arriving and being
        // ignored. That is why every mode here had to be closed by
        // Escape, by clicking the thing again, or by moving the mouse
        // away and waiting out a timer.
        //
        // So the region is widened while a mode is open and narrowed
        // again when it closes. Collapsed, the strip behaves exactly as
        // before and clicks reach the desktop; open, the island owns the
        // screen and a click that misses it dismisses it. Nothing is
        // drawn over the desktop to achieve this — the surface is
        // transparent and the catcher is an input region, not a
        // rectangle of black.
        //
        // Polkit is deliberately not in `dismissArmed`. It is a system
        // authorisation dialog, and one of those ignoring your click is
        // behaving correctly; a mode you opened on purpose closing
        // because you moved the mouse is not.
        readonly property bool dismissArmed:
            root.expanded
            || root.split
            || mediaHost.open
            || searching
            || sessionOpen
            || clipOpen
            || centreOpen
            || overviewOpen
            || switcherOpen
            || picker !== ""
            || notice !== null

        // Every close, in one place. The modes are mutually exclusive by
        // construction — each `open*` clears the rest — so this does not
        // need to know which one was open; calling all of them is
        // idempotent and cannot leave two of them half-closed.
        //
        // `replyFocused` is respected: a notification whose inline reply
        // holds the keyboard must not vanish because the user clicked
        // near it while typing a reply.
        function dismissAll() {
            if (notice !== null && root.replyFocused) return;

            closeSearch();
            closeClipboard();
            closeCentre();
            closePicker();
            closeSession();
            closeOverview();
            closeControl();
            // Clicking away from the centre counts as having read it, or
            // the dots would all still be there next time.
            if (centreOpen) closeCentre();
            dismissAllNotices();
            cancelSwitch();
            root.mediaOpen = false;
            root.split = false;
        }

        // Collapse shortly after the cursor leaves. The grace period
        // stops a brush past the edge snapping it shut mid-interaction.
        Timer {
            id: collapseTimer
            interval: Config.island.collapseDelay
            onTriggered: {
                if (!root.expanded) return;

                // The panel is below the row now, so leaving the pill
                // is not leaving the island: the cursor is on the panel
                // for as long as it is being used, and on a pod when it
                // is being reached for. Re-armed rather than skipped —
                // a timer that gave up while the pointer happened to be
                // resting on a pod would never fire again, and the panel
                // would stay up until something else closed it.
                if (pillHover.hovered || controlHover.hovered
                    || leftPod.hovered || rightPod.hovered) {
                    if (Config.island.collapseDelay > 0) restart();
                    return;
                }

                if (!root.autoExpanded) root.expanded = false;
            }
        }

        // The dismiss surface. Fills the window, sits at the bottom of
        // the z-order because it is declared before the island's own
        // items, and is invisible — it exists to be an input region and
        // for nothing else. `hoverEnabled` stays off so it cannot
        // swallow the hover the pill's collapse timer watches, and it
        // takes only the left button: a right-click that lands on the
        // desktop is somebody's context menu, not a dismissal.
        Item {
            id: dismissCatcher
            anchors.fill: parent
            visible: root.dismissArmed

            MouseArea {
                anchors.fill: parent
                hoverEnabled: false
                acceptedButtons: Qt.LeftButton
                onClicked: root.dismissAll()
            }
        }

        Item {
            id: revealStrip
            anchors.top: parent.top
            anchors.horizontalCenter: parent.horizontalCenter
            width: 420 * root.uiScale
            height: root.revealZone

            MouseArea {
                id: revealArea
                anchors.fill: parent
                hoverEnabled: true
                onContainsMouseChanged: root.touch(containsMouse)
            }
        }

        Item {
            id: island

            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top

            width: pill.width
            // Never shorter than the resting pill, even when the pill is
            // not: in `split` the pill is the housing, which is
            // deliberately shorter than the lobes, so taking the pill's
            // height here would crop the island's rect above and below
            // the notches and leave smart hiding and the overlap test
            // both looking at the wrong shape.
            //
            // The max is a no-op in every other mode — idle and compact
            // are idleHeight tall already, and every panel is taller.
            height: Math.max(pill.height, Config.island.idleHeight)

            // A plain property, not QML's `state`. States exist to
            // batch PropertyChanges; everything here is a binding
            // instead, so the machinery bought nothing and cost a
            // binding-replacement bug on every transition.
            readonly property string mode: {
                if (Polkit.active) return "auth";
                if (Osd.active && !root.searching && !root.sessionOpen
                    && !root.centreOpen && root.picker === "")
                    return "osd";
                // A popup outranks everything except an interaction
                // already in progress — it's brief and it's news.
                // One with a reply field open outranks more than that:
                // it is holding text the user is in the middle of.
                if (root.notice !== null && !root.searching && !root.sessionOpen
                    && !root.centreOpen && root.picker === "")
                    return "notify";
                if (root.switcherOpen) return "switcher";
                if (root.overviewOpen) return "overview";
                if (root.clipOpen) return "clipboard";
                if (root.centreOpen) return "centre";
                if (root.picker !== "") return "picker";
                if (root.sessionOpen) return "session";
                if (root.searching) return "search";
                // Fullscreen wins over everything except an explicit
                // interaction — video and games shouldn't get a pill
                // hovering over them.
                if (Config.island.hideOnFullscreen && Wm.fullscreen
                    && !pillHover.hovered && !revealArea.containsMouse
                    && !root.podsHeld && !root.expanded)
                    return "hidden";
                if (!root.revealed) return "hidden";
                if (root.expanded) return "expanded";
                // The split — last of the states a user asks for, and
                // first of the states that are simply "the island".
                //
                // Below `expanded` and every panel above it, so a
                // deliberate "show me this" always beats it: the split
                // is a lighter state and should yield to anything
                // heavier. It was above them, which meant a bind opening
                // the control centre while the island happened to be
                // parted showed nothing at all.
                //
                // Below the fullscreen and occlusion checks on purpose,
                // exactly where `expanded` sits. Both are states the user
                // is looking at, and neither should be taken away by a
                // window arriving.
                //
                // Gated on a track: the lobes are a media state and there
                // is nothing to part around without one. So this can read
                // false while `root.split` is true — the track stopped
                // under it — and the island closes itself, which is what
                // a notification does when its timer runs out.
                if (root.split && Config.island.splitEnabled && island.media)
                    return "split";
                // There is no `compact` here any more.
                //
                // Hover used to return one, and returning it is what made
                // the pill grow: the mode carried a width and a height of
                // its own, so pointing at the island resized it. What
                // hover does now is nothing at all to the shape — the
                // transport cross-fades in over the clock, inside a pill
                // already sized to fit it. A pod still opens under the
                // cursor, but a pod opening is a pod's business and the
                // pill has no reason to move for it.
                return "idle";
            }

            // The card below the row belongs to the resting island, so
            // anything that takes the island somewhere else takes it
            // down rather than leaving it under a search, a
            // notification or a fullscreen window. It is cleared here
            // and not in each `open*` because *every* way the mode
            // moves passes through this one binding.
            onModeChanged: if (mode !== "idle") root.mediaOpen = false;

            anchors.topMargin: dock.value

            // Hidden parks the pill just off the top edge, the way a
            // menu bar leaves in fullscreen.
            //
            // Every other mode shares the resting margin exactly. It
            // used to be two pixels lower — "the shadow of the shape
            // having grown" — and the iPhone's island has no such
            // thing: its top edge is invariant across the whole morph,
            // from the 37pt pill to the full-height panel, and that
            // invariance is part of what makes it read as one object
            // changing size rather than one object being replaced. The
            // drop also meant the resting pill and the open panel
            // never shared an edge, so every open began with a
            // two-pixel discontinuity that had nothing to do with the
            // shape.
            Spring {
                id: dock
                shape: island
                target: (island.mode === "hidden"
                    ? -pill.height - 4
                    : Config.island.topMargin) * root.uiScale
            }

            opacity: mode === "hidden" ? 0 : 1

            Behavior on opacity {
                // A fade, not a shape: it has no velocity to carry and
                // no overshoot to spend, so it stays an easing. Apple
                // eases these too.
                NumberAnimation {
                    duration: island.morphTime
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Motion.ease
                }
            }

            // Leaving is not only a slide. The shape gives up the last
            // four percent of itself on the way out and takes it back
            // on the way in, so it reads as receding rather than as
            // being pushed. uiScale is the DPI correction and is a
            // different thing multiplied through the same property.
            scale: recede.value * root.uiScale
            transformOrigin: Item.Top

            Spring {
                id: recede
                shape: island
                target: island.mode === "hidden" ? Motion.emergeScale : 1
            }

            // Direction is what a curve cannot work out for itself, so
            // it is decided here and every spring on the pill reads it.
            // Opening springs; closing springs with most of the bounce
            // taken out.
            //
            // Two tiers, and there used to be three. The third was
            // `hover`, held for the compact pill: 180ms against an
            // expansion's 240, on the grounds that "a 6px lift given a
            // full expansion's response feels slack". That reasoning was
            // sound for a 6px lift and did not survive the lift becoming
            // a 47% width change, and with hover no longer moving the
            // shape there is nothing left for the middle tier to
            // distinguish. A tier that exists to slow down a movement
            // that no longer happens is a number nobody can hear.
            readonly property bool collapsing:
                mode === "idle" || mode === "hidden"

            readonly property int springResponse:
                collapsing ? Motion.collapseResponse : Motion.expandResponse

            readonly property real springBounce:
                collapsing ? Motion.departBounce : Motion.arriveBounce

            // What the fades above and inside the modes are given, so
            // a cross-fade lasts about as long as the shape it rides
            // on. Not a spring: see the note on Behavior on opacity.
            //
            // Idle is a resting state and nothing is morphing, so the
            // fade in and out of it is given the plain cross-fade
            // durations rather than a spring's settle time. Those are
            // close enough that this is a refinement rather than a
            // change — `Motion.collapse` is 218ms and `Motion.fadeOut`
            // is 60 — but the point is that a mode which is not
            // arriving should not be timed as though it were.
            readonly property int morphTime:
                mode === "idle" ? Motion.fadeOut
                                : (collapsing ? Motion.collapse
                                              : Motion.expand)

            readonly property bool media: Player.available && Player.title !== ""
            readonly property bool isExpanded: mode === "expanded"

            // The pill itself, not the group — so a pod being brushed
            // does not put the transport under a cursor two hundred
            // pixels away from it. There is no `compact` to separate
            // any more; the two used to be the same mode, and the media
            // transport appearing because a tray icon was touched is
            // what that mode was really for.
            readonly property bool pillHovered: pillHover.hovered

            readonly property bool isSearching: mode === "search"
            readonly property bool isSession: mode === "session"
            readonly property bool isPicker: mode === "picker"
            readonly property bool isNotify: mode === "notify"
            readonly property bool isCentre: mode === "centre"
            readonly property bool isOsd: mode === "osd"
            readonly property bool isAuth: mode === "auth"
            readonly property bool isClipboard: mode === "clipboard"
            readonly property bool isSwitcher: mode === "switcher"
            readonly property bool isOverview: mode === "overview"
            // Expanded and control are the same thing.
            readonly property bool isControl: mode === "expanded"
            readonly property bool isSplit: mode === "split"

            // Declared before the pill, so the expanding panel sweeps
            // over them on its way open rather than leaving them
            // sitting on top of it for the length of the fade.
            // Both pods are circles at rest, flanking the pill. There
            // were two here once and then one: the workspace pod went
            // when the pill learned to say the workspace number itself
            // (IdleMode), and this seat is now the media pod. Where it
            // answered "where am I", this answers "what is playing" —
            // which is the one thing the pill cannot, because at rest
            // the pill holds a clock and a number and the split that
            // could answer it needs a press-and-hold to reach.
            MediaPod {
                id: leftPod
                win: root; island: island; pill: pill
            }

            ControlPod {
                id: rightPod
                win: root; island: island; pill: pill
            }

            // Under the pill, and declared before it so it is behind
            // it. Hyprland gives a layer-shell surface no shadow —
            // decoration:shadow is for toplevels — and this is the one
            // shape in the shell that cannot do without one, because a
            // soft shadow is most of what separates "an object sitting
            // above the screen" from "a hole drawn in it".
            Shadow { shape: pill; anchors.fill: pill; spread: 10 }

            // The two halves of the split, declared either side of the
            // pill because in this mode the pill is the housing they
            // part around. See Island/SplitLobe.qml.
            SplitLobe {
                id: leftLobe
                win: root; island: island; pill: pill
                side: "left"; content: "track"
            }

            SplitLobe {
                id: rightLobe
                win: root; island: island; pill: pill
                side: "right"; content: "bars"
            }

            // An Item that paints itself with a child. Rectangle
            // cannot draw a superellipse corner and Shapes must not be
            // used in a blurred layer — see Widgets/Squircle.qml.
            //
            // `radius`, `color` and `borderColor` keep the names
            // Rectangle used: four other files read them off this id.
            Item {
                id: pill

                property color color
                property real radius
                property color borderColor

                anchors.left: parent.left

                // In split mode the pill is the housing, which is
                // shorter than the lobes, so it centres on the island's
                // band rather than hanging from its top edge. Anchors
                // are set and unset rather than a topMargin, because
                // two vertical anchors at once is a binding error.
                anchors.verticalCenter: island.mode === "split"
                    ? parent.verticalCenter
                    : undefined

                MouseArea {
                    id: pillClick
                    anchors.fill: parent

                    // Modes with their own interactive content take
                    // their own clicks entirely. `split` belongs here
                    // rather than out because the pill is the housing —
                    // the one part of the split with nothing in it — so
                    // it is the natural place to click the split away.
                    // The clock is still a button while the panel is
                    // open — the panel no longer covers it, so
                    // clicking it is now the obvious way to put the
                    // panel away again.
                    enabled: island.mode === "idle"
                             || island.mode === "hidden"
                             || island.mode === "split"
                             || island.mode === "expanded"

                    // Under a press and hold, Qt stops emitting clicked
                    // once the interval has passed, so a hold and a
                    // click are already exclusive and the split does
                    // not steal the other gestures on this shape.
                    pressAndHoldInterval: Config.island.splitHold

                    onClicked: {
                        if (island.mode === "split") {
                            root.split = false;
                            return;
                        }

                        // The card under the row, put away by the
                        // nearest thing to press — the same answer the
                        // control centre gives, which is why the two
                        // are one clause apart rather than a mode of
                        // their own.
                        if (root.mediaOpen) {
                            root.mediaOpen = false;
                            return;
                        }

                        // The clock does NOT open the control centre —
                        // the right-hand pod is the button for that, and
                        // the two were the same press, which meant
                        // reaching for the time opened a panel of
                        // toggles. While that panel is open the clock is
                        // still its close control: the panel sits under
                        // the pill rather than over it, so this is the
                        // nearest thing to press and it was already the
                        // documented way to put the panel away.
                        if (root.expanded) {
                            root.expanded = false;
                            root.autoExpanded = false;
                            collapseTimer.stop();
                            return;
                        }

                        // At rest, a press on the time turns the week
                        // under it on and off — the strip's other
                        // switch, on the shape it belongs to, so the
                        // setting and the thing it govern are one
                        // gesture apart instead of one window apart.
                        Config.island.weekStrip = !Config.island.weekStrip;
                    }

                    // The split. A media state: with nothing playing
                    // there is nothing to part around, so this ends there
                    // rather than opening two empty capsules.
                    onPressAndHold: {
                        if (!island.media) return;
                        if (root.expanded) root.expanded = false;
                        root.split = true;
                    }
                }

                // The resting width: the clock plus the padding either
                // side of it. `idleWidth` is a floor under that — 88, a
                // shade over the content's 83 — so it matters for a
                // narrow face and for anybody who wants the island wider
                // on purpose.
                //
                // `textSlot`, which is the clock's width plus whichever
                // transient face is currently up. That is what makes a
                // workspace label or a track title widen the pill for as
                // long as it is showing and no longer: the spring below
                // does the moving, and the resting shape is the clock
                // alone rather than a permanent slot for text that is
                // usually not there.
                //
                // There is nothing else in it, and that is the point.
                // This used to be `max(clock, transport)` so that
                // pointing at the pill could not resize it, which was
                // worth doing while there were two faces. With one there
                // is nothing to be wide enough for, and a shape measured
                // against content it is not showing is the same mistake
                // one level up.
                readonly property int collapsedWidth:
                    Math.max(Config.island.idleWidth,
                             idleMode.textSlot + Config.island.padding * 2,
                             // The week is wider than the clock, so it
                             // is a floor of its own: without it the
                             // strip measures past the shape that is
                             // supposed to hold it and gets cropped.
                             idleMode.stripWidth + Config.island.padding * 2)

                // One table, not two parallel switches. Adding a mode
                // means one entry here plus its content block — the
                // geometry no longer has to be kept in step across
                // separate width and height expressions.
                //
                // `hidden` and `idle` are the same entry, and there is no
                // `compact`: a mode here is a shape, and hover is not one
                // any more.
                readonly property var geometry: ({
                    hidden:   { w: collapsedWidth, h: root.restPillH },
                    idle:     { w: collapsedWidth, h: root.restPillH },
                    // As tall as the layout reaches — the grid knows
                    // its own row count, so there are no optional
                    // terms to keep in step.
                    //
                    // Coerce and default every term regardless: one
                    // undefined makes the sum NaN, which leaves the
                    // pill with no height, and with clip off the
                    // content then renders outside the shape.
                    // The control centre is not this shape any more —
                    // it opens under the row from the right pod, and
                    // the pill keeps its clock while it does. See
                    // `controlHost`. The entry stays so a mode nobody
                    // renames still has a size to fall back on.
                    expanded: { w: collapsedWidth, h: root.restPillH },
                    // The field and nothing else — results are on the
                    // shelf below, so this height does not depend on
                    // the match count and the pill does not move under
                    // the cursor while you type. spacingSmall rather
                    // than padCard: there is no first row here to buy
                    // clearance for, and padCard left a third of the
                    // bar as air.
                    search:   { w: Config.island.searchWidth,
                                h: Theme.spacingSmall * 2
                                   + Config.island.searchFieldHeight },
                    session:  { w: Config.island.sessionWidth, h: Config.island.sessionHeight },
                    // The picker's height is the MODE's, not the
                    // setting's — see PickerMode's `contentHeight`. It
                    // was `island.pickerHeight`, which is the arithmetic
                    // for two rows of 16:9 and was applied whatever was
                    // in the grid, so three wallpapers got a panel with a
                    // black void under them.
                    picker:   { w: Config.island.pickerWidth,
                                h: pickerMode.contentHeight },
                    // The notification's height is the MODE's, from what
                    // is in it — see NotifyMode's `contentHeight`. It was
                    // `island.notifyHeight`, a flat 104 plus two more
                    // fixed terms, so a one-line notification with
                    // nothing to act on and a three-line one with four
                    // buttons came out the same shape. That proportion
                    // is a banner, and a banner is the presentation the
                    // Dynamic Island replaced.
                    notify:   { w: Config.island.notifyWidth,
                                h: notifyMode.contentHeight },
                    // The camera housing, and nothing else. In this mode
                    // the pill IS the housing: it shrinks to the gap the
                    // two lobes part around, and gets shorter than them
                    // so the notches above and below it are what the eye
                    // reads as a split. It keeps its fill — the housing
                    // is black on a phone and black here — and it keeps
                    // the click that dismisses.
                    split:   { w: Config.island.splitGap,
                                h: Theme.housing(Config.island.idleHeight) },

                    // Not centreHeight — see CentreMode.contentHeight,
                    // which treats that setting as a ceiling and works
                    // out the rest from what is actually in the list.
                    centre:   { w: Config.island.centreWidth,
                                h: centreMode.contentHeight },
                    osd:      { w: Config.island.osdWidth,     h: Config.island.osdHeight },
                    auth:     { w: Config.island.authWidth,    h: Config.island.authHeight },
                    switcher: { w: Math.min(Config.island.switcherWidth,
                                            Math.max(260,
                                                     root.switchList.length
                                                     * (Config.island.switcherTile + 8) + 32)),
                                h: Config.island.switcherHeight },
                    overview: { w: Math.max(260,
                                            Wm.workspaces.length
                                            * (Config.island.overviewCard + 12) + 24),
                                h: Config.island.overviewCard * 0.68 + 36 },
                    // As above: the entries are on the shelf.
                    clipboard: { w: Config.island.clipWidth,
                                 h: Theme.spacingSmall * 2
                                    + Config.island.searchFieldHeight }
                })

                width:  pillWidth.value
                height: pillHeight.value

                // Theme colours carry no alpha, so it's applied here.
                // The island-bar layer rule blurs whatever shows
                // through — one surface, so every mode is blurred
                // equally and the only question is how much of it is
                // allowed to show.
                //
                // The two popups get their own answer: see
                // Config.island.popupOpacity.
                // Which is all moot while the island is black, because
                // an opaque fill shows nothing of the blur behind it
                // however much blur there is. See
                // Config.appearance.islandBlack.
                readonly property real fillOpacity:
                    Config.appearance.islandBlack
                        ? 1
                        : (island.mode === "osd" || island.mode === "notify"
                            ? Config.island.popupOpacity
                            : Config.island.opacity)

                function tint(c) {
                    const col = Qt.color(c);
                    return Qt.rgba(col.r, col.g, col.b, pill.fillOpacity);
                }

                // The control centre is one panel with cards on it,
                // not four cards floating where a panel used to be.
                // It went transparent when the cards each carried
                // their own surface, and the result was three boxes
                // over the wallpaper with nothing saying they were one
                // thing — the gaps read as holes rather than as gaps.
                // Now the panel is the surface and the cards sit on
                // it, which is also what lets the layout editor move
                // them around without leaving a shape behind.
                // Hover is a lift, not a recolour. The shape grows
                // and rises and that is the whole of the feedback —
                // a fill that changes as well is a second thing
                // happening for one event, and at pill size it reads
                // as the colour being wrong rather than as a
                // response. Compact keeps the resting fill.
                // Two fills, and the line between them is whether the
                // shape is still the pill or has become a panel.
                //
                // Resting, hovered, and the OSD are the pill: the OSD
                // is a volume bar that grew out of it for a second
                // and went away again, and lightening for that reads
                // as a different object arriving rather than as the
                // same one saying something. The control centre is
                // dark for its own reason — the cards are the
                // surfaces there and the panel behind them is not.
                //
                // Everything else is a panel you are reading or
                // typing into, and those take the container.
                //
                // And when the island is black — which it is by
                // default, because the Dynamic Island is #000 in
                // every mode and in every palette — none of that
                // applies. Black is black; there is no fill to choose
                // between. The mode split is left intact underneath,
                // so turning the black off restores it exactly.
                color: Config.appearance.islandBlack
                    ? Theme.islandSurface
                    : tint(island.mode === "idle"
                            || island.mode === "hidden"
                            || island.mode === "osd"
                            || island.mode === "expanded"
                        ? Theme.surfaceLowest
                        : Theme.surfaceContainer)

                // See Theme.corner: a capsule at rest, opening up as
                // the shape grows.
                radius: Theme.corner(height)

                // Clipping reveals content by the growing shape, which
                // is right for every mode whose content sits inside
                // the pill.
                //
                // Two honest limits. It clips to the bounding
                // rectangle rather than to the squircle, so anything
                // opaque that reaches a corner is cut square. At the
                // resting capsule nothing does — the content is a 14px
                // line in a 34px shape — and docs/NOTES.md has the
                // four things that were tried against it.
                //
                // And the control centre's cards deliberately extend
                // past the pill, so a growing clip rectangle sweeps
                // across their edges and cuts them frame by frame,
                // which is the flicker around the outline. That mode
                // is excluded.
                //
                // The exclusion used to be described here and not
                // written: the comment said "off for that mode" over a
                // bare `clip: true`, so the flicker it explained was
                // very much still happening.
                clip: island.mode !== "expanded"

                // The hairline, off by default. The iPhone's island
                // has no stroke at all — the shape is separated from
                // the wallpaper by being black and by its shadow, and
                // a ring around it is one more thing telling you this
                // is a window rather than a hole in the screen.
                //
                // See Config.appearance.islandEdge for the argument it
                // used to win on, and for why the settings window and
                // the lock screen still keep theirs.
                borderColor: Theme.islandEdge
                    ? Qt.rgba(
                        Qt.color(Theme.outlineVariant).r,
                        Qt.color(Theme.outlineVariant).g,
                        Qt.color(Theme.outlineVariant).b,
                        1)
                    : "transparent"

                // Declared before everything else so the fill is
                // underneath it, which is the job the Rectangle's own
                // background used to do.
                Squircle {
                    smoothing: Config.appearance.cornerSmoothing
                    anchors.fill: parent
                    radius: pill.radius
                    color: pill.color
                    borderWidth: Theme.islandEdge ? 1 : 0
                    borderColor: pill.borderColor
                }

                Behavior on borderColor {
                    // `win` is what the Modes/ components call this
                    // window, because Island.qml passes it to them as
                    // `win: root`. Inside Island.qml itself the id is
                    // `root`, so this threw a ReferenceError on every
                    // evaluation and the animation silently fell back
                    // to the 250ms default — the border snapped
                    // instead of fading, which is the flicker the
                    // comment above is about.
                    ColorAnimation { duration: root.fadeOut }
                }

                // Declared first, so it sits beneath the content. The
                // toggles and sliders above it get their clicks; this
                // only catches presses on empty pill.

                // Both axes on one spring, so the shape scales as a
                // shape rather than as two edges that happen to be
                // moving at the same time. Two springs, one set of
                // numbers: they are given the same response and the
                // same bounce, and they start together, so they stay
                // in step without having to be one object.
                //
                // A floor at zero because the corner is derived from
                // the height and a negative height is a corner drawn
                // inside out. The spring keeps its real state either
                // way — see Widgets/Spring.qml.
                Spring {
                    id: pillWidth
                    shape: island
                    minimum: 0
                    target: (pill.geometry[island.mode] || pill.geometry.idle).w
                }

                Spring {
                    id: pillHeight
                    shape: island
                    minimum: 0
                    target: (pill.geometry[island.mode] || pill.geometry.idle).h
                }
                // The pill's colour is deliberately not animated. In
                // the expanded state it goes transparent so the cards
                // read as separate surfaces, and fading a full-width
                // background in and out underneath a morph and a
                // content fade is three transitions at once.

                // The pill's own content, and the only mode that is
                // there at rest. It is outside the layer below for
                // exactly that reason: a clock cannot be presented,
                // because it never arrives.
                IdleMode    { id: idleMode; win: root; island: island; pill: pill }

                // Everything that is a panel, on one surface that
                // arrives as a panel does.
                //
                // A cross-fade alone reads as content appearing over
                // the shape. macOS presents a surface by growing it
                // the last few percent into place, anchored at the
                // edge it came from — a popover, Notification Centre,
                // a sheet — and that is what says it came out of the
                // pill rather than landing on it.
                //
                // Scaling here rather than inside each mode is also
                // what makes it mean the right thing. Going from the
                // launcher to the control centre is not an arrival,
                // it is the same panel showing something else, and it
                // stays a cross-fade: the scale only moves when there
                // is no panel on either side of the change.
                Item {
                    id: panelLayer
                    anchors.fill: parent

                    // Present only when there is a panel to present.
                    // `split` is excluded: the lobes arrive in their own
                    // right and are not a panel arriving out of the pill,
                    // so the emerge would be scaling content that has
                    // already gone. `compact` needs no mention — it does
                    // not exist, and nothing is emerging out of the pill
                    // on hover any more.
                    readonly property bool present: !island.collapsing
                        && island.mode !== "split"

                    scale: emerge.value
                    transformOrigin: Item.Top

                    Spring {
                        id: emerge
                        shape: island
                        target: panelLayer.present ? 1 : Motion.emergeScale
                    }

                    SearchMode  { win: root; island: island; pill: pill }
                    SessionMode { win: root; island: island; pill: pill }
                    PickerMode  { id: pickerMode; win: root; island: island; pill: pill }
                    NotifyMode  { id: notifyMode; win: root; island: island; pill: pill }
                    CentreMode  { id: centreMode; win: root; island: island; pill: pill }
                    OsdMode     { win: root; island: island; pill: pill }
                    AuthMode    { win: root; island: island; pill: pill }
                    ClipboardMode { win: root; island: island; pill: pill }
                    SwitcherMode  { win: root; island: island; pill: pill }
                    OverviewMode  { win: root; island: island; pill: pill }
                }

                // Declared after the modes, so the edge is drawn over
                // whatever they put against it — a list row scrolling
                // past, a card that reaches the margin. See
                // Widgets/Bezel.qml: the pill's outer hairline says
                // where it ends, and this second one says how round it
                // is, which is the number every shape inside is
                // measured against.
                //
                // Gated on the same setting as the hairline, and for
                // the same reason: on a black island a white ring at
                // 14% alpha, two pixels inside another one, is the
                // most conspicuous detail in the whole shell and the
                // furthest thing from the iPhone.
                Bezel {
                    outer: pill.radius
                    visible: Theme.islandEdge
                }

                // Scroll over the collapsed pill moves a workspace, or
                // volume, or nothing — island.scrollAction picks. While
                // an OSD is up it adjusts that value instead, which is
                // what the gesture already means in that moment.
                WheelHandler {
                    acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad

                    onWheel: function(event) {
                        const dy = event.angleDelta.y;

                        if (Osd.active) {
                            const step = dy > 0 ? 5 : -5;
                            if (Osd.kind === "brightness") {
                                Audio.setBrightness(
                                    Math.max(0, Math.min(100, Audio.brightness + step)));
                                Osd.show("brightness", Audio.brightness, false);
                            } else {
                                Audio.setVolume(
                                    Math.max(0, Math.min(100, Audio.volume + step)));
                                Osd.show("volume", Audio.volume, Audio.muted);
                            }
                            return;
                        }

                        if (island.mode !== "idle")
                            return;

                        const action = Config.island.scrollAction;

                        if (action === "workspace") {
                            root.scrollWorkspace(dy);
                        } else if (action === "volume") {
                            const step = dy > 0 ? Config.island.osdStep
                                                : -Config.island.osdStep;
                            Audio.setVolume(
                                Math.max(0, Math.min(100, Audio.volume + step)));
                            Osd.show("volume", Audio.volume, Audio.muted);
                        }
                    }
                }

                // A MouseArea, not a HoverHandler, declared last so it
                // sits above every control: a child MouseArea with
                // hoverEnabled consumes hover, so a HoverHandler went
                // unhovered over any day cell or tile and the collapse
                // timer fired as if the cursor had left.
                //
                // NoButton means it sees hover but never takes a click.
                MouseArea {
                    id: pillHover
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.NoButton
                    propagateComposedEvents: true

                    readonly property bool hovered: containsMouse

                    onContainsMouseChanged: {
                        root.touch(containsMouse);
                        if (containsMouse) collapseTimer.stop();
                        else if (root.expanded && Config.island.collapseDelay > 0)
                            collapseTimer.restart();
                    }
                }
            }

            // A second surface under the pill, for the modes that are
            // a field with a list beneath it: the pill holds the
            // field, this holds the rows. One shape for both made the
            // field stop reading as a field once it had results, and
            // moved the shape under the cursor on every keystroke.
            //
            // The gap is podGap — the number already governing space
            // around the pill, not a second one invented here.
            //
            // Its shadow, declared out here rather than inside it,
            // because the shelf clips its own rows as it collapses to
            // nothing and a clip takes the shadow with it. A shelf
            // hanging off the pill with a shadow under one and not the
            // other reads as a bug rather than as two surfaces.
            // ── The control centre, as a surface of its own ────
            //
            // It used to *be* the pill: the shape grew from a clock
            // into a panel and took the clock with it, so opening the
            // controls cost you the time and both pods vanished off
            // the sides. Everything about that was backwards. The
            // press lands on the right pod, so that is where it comes
            // from — the panel rises under that pod and runs left, and
            // the row above it does not move: the pill keeps the
            // clock, the media pod keeps its cover, and the button you
            // pressed stays where you pressed it.
            //
            // A separate shape rather than the pill repositioned,
            // because the two need different things from a spring: the
            // pill must not move at all here, and this must arrive
            // from a corner. See `panelLayer` inside the pill for the
            // presentation every *other* panel still gets.
            Item {
                id: controlHost

                readonly property bool open: island.isControl
                readonly property real gap: Config.island.podGap

                // The pill's numbers, restated: black on a black
                // island, and the tinted `surfaceLowest` when the
                // island is not. A panel that picked its own colour
                // would be a second surface in the palette rather than
                // the island continuing.
                readonly property real radius: Theme.corner(height)
                readonly property color fill: {
                    if (Config.appearance.islandBlack) return Theme.islandSurface;
                    const c = Qt.color(Theme.surfaceLowest);
                    return Qt.rgba(c.r, c.g, c.b, Config.island.opacity);
                }

                // Right edge to the control pod's right edge, so the
                // panel is anchored to the button that opened it — it
                // grows leftward out of that pod rather than landing
                // under the clock. The pod's *resting* geometry, not
                // its live `x`: on the way out the pod is already
                // tucking under the pill, and a panel that slides fifty
                // pixels sideways while it fades is two things moving
                // for one gesture.
                x: pill.width + gap
                   + (Config.island.showControl ? Config.island.idleHeight : 0)
                   - width
                y: island.height + gap

                width: Config.island.controlWidth
                height: ControlLayout.panelHeight

                opacity: open ? 1 : 0
                visible: opacity > 0.01

                // Up out of the pod's corner rather than out of this
                // item's own middle — the difference between a panel
                // that came from somewhere and one that landed.
                scale: hostEmerge.value
                transformOrigin: Item.TopRight

                Behavior on opacity { ContentFade { revealing: controlHost.open } }

                Spring {
                    id: hostEmerge
                    shape: island
                    target: controlHost.open ? 1 : Motion.emergeScale
                }

                // Inside, so it arrives and leaves with the panel: a
                // shadow that outlives the shape casting it reads as a
                // smudge on the wallpaper.
                Shadow { shape: hostSurface; anchors.fill: parent; spread: 10 }

                Squircle {
                    id: hostSurface
                    smoothing: Config.appearance.cornerSmoothing
                    anchors.fill: parent
                    radius: controlHost.radius
                    color: controlHost.fill
                    borderWidth: Theme.islandEdge ? 1 : 0
                    borderColor: Theme.islandEdge ? Theme.outlineVariant
                                                  : "transparent"
                }

                // The same id it had inside the pill, so the IPC
                // handler that sets a sub-page does not have to know
                // that anything moved.
                ControlMode { id: controlMode; win: root; island: island }

                // The pill's hover, restated for a shape the cursor
                // reaches without crossing the pill to get to. Without
                // it, pointing into the panel restarts the collapse
                // timer on the way in and the panel shuts while you
                // are using it. Same construction as `pillHover`: see
                // the note there for why it is declared last.
                MouseArea {
                    id: controlHover
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.NoButton
                    propagateComposedEvents: true

                    readonly property bool hovered: containsMouse

                    onContainsMouseChanged: {
                        root.touch(containsMouse);
                        if (containsMouse) collapseTimer.stop();
                        else if (root.expanded && Config.island.collapseDelay > 0)
                            collapseTimer.restart();
                    }
                }
            }

            // A pod that empties takes the card with it, which is the
            // one clearing `mediaHost` cannot do for itself: a player
            // that quits, or a media pod switched off in the settings,
            // leaves no button to press and nothing to click away
            // with, so the flag goes here rather than living on as a
            // card that reappears the next time something plays.
            //
            // A `Connections` rather than a handler on the pod
            // itself: `Pod` declares one on the same signal, and this
            // has to be a second listener rather than a replacement
            // for it.
            Connections {
                target: leftPod
                function onPresentChanged() {
                    if (!leftPod.present) root.mediaOpen = false;
                }
            }

            // The now-playing card, below the row — the control
            // centre's construction taken to the other side of the
            // pill: the row does not move, and a panel hangs under it
            // rather than a second shape opening beside it.
            //
            // What is inside is `Widgets/Control/MediaCard.qml`, the
            // same card the control centre lays into its grid — the
            // cover, the four lines, the two stamps over the scrubber
            // and the transport. There it is a cell the user arranges
            // and so it answers only what fits; here the cell is the
            // panel, and at 140 tall the card is `dense`, `timed` and
            // `tall` at once, which is every line it knows how to
            // say.
            Item {
                id: mediaHost

                // Gated on the player being there rather than on
                // `island.media`: a gap between tracks blanks the
                // title, and a card that faded out and back on every
                // track change would read as the panel closing. The
                // other two terms are what keeps the state honest —
                // a media pod switched off is a media card switched
                // off — and `mediaOpen` itself is cleared when the
                // pod empties (see the Connections above), so nothing
                // is left armed behind a panel that is not there.
                readonly property bool open:
                    root.mediaOpen && Player.available
                    && Config.island.showMedia

                readonly property real gap: Config.island.podGap

                // The pill's numbers, restated, and for the reason
                // `controlHost` gives: a panel that picked its own
                // colour would be a second surface in the palette
                // rather than the island continuing. The radius is
                // `corner` for the same reason as there — it is the
                // curve the cards inside are inset by, so the card's
                // own corner and this one stay concentric at `padCard`.
                readonly property real radius: Theme.corner(height)

                // How much of the panel stays. 0.62, and it is a
                // ceiling rather than the answer: `Config.island.opacity`
                // opens it further (a busy wallpaper behind a panel you
                // are reading is a legitimate thing to want more of),
                // but it cannot close it, because the island's black is
                // the *pill's* — a shape holding a clock in one line
                // reads as a hole cut in the screen and samples nothing
                // behind it, which is the iPhone's own rule. A panel
                // you read for a minute is the one surface here that is
                // not that, and what it gets from being translucent is
                // the light along its edge and the wallpaper's colour
                // under the words: an opaque fill shows nothing of the
                // blur however much blur there is. See
                // Config.island.opacity and Config.appearance.islandBlack.
                readonly property real glass: Math.min(0.62,
                                                       Config.island.opacity)

                readonly property color fill: {
                    const c = Qt.color(Config.appearance.islandBlack
                        ? Theme.islandSurface : Theme.surfaceLowest);
                    return Qt.rgba(c.r, c.g, c.b, mediaHost.glass);
                }

                // Centred under the pill rather than flush with the
                // pod that opened it, which is what `controlHost` does
                // on the other side and not what this wants: the row
                // is symmetric — pod, pill, pod — and a panel flush to
                // one end of it hangs out past the other by eighty
                // pixels and reads as a shelf that slid. Centred, the
                // overhang is equal both ways and the panel is the
                // row's own width made visible rather than an object
                // attached to one of its buttons.
                //
                // The pod is still where it comes from — it is what
                // opens it, and `mediaEmerge` grows the panel out of
                // its top-left corner.
                anchors.horizontalCenter: parent.horizontalCenter
                y: island.height + gap

                // 344 x 140 — the card and the panel are the same
                // object here, not one inside the other, so these are
                // the card's numbers: 140 less `padCard` each side is
                // a 116 square cover, and 344 across, minus the cover
                // and the two gutters, leaves 194 of column, which is
                // where a title stops being cut in the middle ("MIDDLE
                // OF THE NIGHT" rather than "MIDDLE OF THE NI…").
                //
                // Both off the reference this panel is a copy of: at
                // 275 x 117 that card gives 96 of cover and 160 of
                // column, and these are those two numbers a fifth
                // larger — same proportions, one more line of room.
                //
                // 140 is `dense` (112), `timed` (92) and `tall` (70)
                // at once, so every line the card knows how to say is
                // on screen, with the bar under the metadata and the
                // stamps under that.
                width: 344
                height: 140

                opacity: open ? 1 : 0
                visible: opacity > 0.01

                // Out of the corner nearest the pod — which is this
                // item's top-left, the pod being the shape just above
                // and left of it — rather than out of the middle: the
                // difference between a panel that came from somewhere
                // and one that landed.
                scale: mediaEmerge.value
                transformOrigin: Item.TopLeft

                Behavior on opacity { ContentFade { revealing: mediaHost.open } }

                Spring {
                    id: mediaEmerge
                    shape: island
                    target: mediaHost.open ? 1 : Motion.emergeScale
                }

                // Inside, so it arrives and leaves with the panel: a
                // shadow that outlives the shape casting it reads as a
                // smudge on the wallpaper. `radius` is read off the
                // host, so the rings cannot drift from the corner they
                // follow — see Widgets/Shadow.qml.
                Shadow { shape: mediaHost; anchors.fill: parent; spread: 10 }

                Squircle {
                    smoothing: Config.appearance.cornerSmoothing
                    anchors.fill: parent
                    radius: mediaHost.radius
                    color: mediaHost.fill
                    borderWidth: Theme.islandEdge ? 1 : 0
                    borderColor: Theme.islandEdge ? Theme.outlineVariant
                                                  : "transparent"
                }

                // The panel and the card are one object, so the card
                // fills it: no tray, no second frame, no hairline
                // inside a hairline. What is left is the glass, the
                // cover and the words, and `padCard` — the card's own
                // gutter — is what puts the cover 12 in from the edge
                // and the title level with it.
                MediaCard {
                    anchors.fill: parent

                    // The album and the source get a row each here,
                    // where the column has the height for them and the
                    // alternative is the hole between the metadata and
                    // the stamps that a three-row column leaves. In the
                    // control centre this card keeps its one line.
                    inPanel: true

                    // The card's body puts itself away, the way the
                    // pill puts away the control centre: the transport
                    // is the part you aim at, and everything else on
                    // the panel is the panel you dismiss by pressing
                    // it again.
                    onOpened: root.mediaOpen = false
                }

                // Hovering the card counts as being on the island, or
                // smart hiding could pull the strip out from under a
                // pointer reading the track off it. Same construction
                // as `controlHover`: `NoButton` and propagation, so
                // this takes the hover and leaves every click to the
                // card beneath it.
                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.NoButton
                    propagateComposedEvents: true

                    readonly property bool hovered: containsMouse

                    onContainsMouseChanged: root.touch(containsMouse)
                }
            }

            Shadow { shape: shelf; anchors.fill: shelf; spread: 10 }

            Item {
                id: shelf

                readonly property bool isSearch: island.mode === "search"
                readonly property bool isClip: island.mode === "clipboard"

                readonly property int rows: isSearch
                    ? Math.min(Search.results.length,
                               Config.island.searchMaxRows)
                    : (isClip ? Math.min(root.clipRows,
                                         Config.island.clipMaxRows) : 0)

                readonly property int rowHeight: isSearch
                    ? Config.island.searchRowHeight
                    : Config.island.clipRowHeight

                // The launcher with nothing typed has no shelf at all
                // — that is what "empty until you type" looks like
                // once the list is a surface rather than a region of
                // one. The clipboard keeps its shelf either way,
                // because it was opened deliberately and "No matches"
                // is an answer; see ClipList.qml.
                readonly property bool shown: isSearch ? rows > 0 : isClip

                anchors.horizontalCenter: pill.horizontalCenter
                anchors.top: pill.bottom
                // Tighter than the pods' gap, and deliberately a different
                // number. The field and the shelf beneath it are one
                // object — a field and its menu — and the pods are not. At
                // `podGap`'s 8, with a shadow under each, the pair read as
                // two unrelated bars with a dark seam between them; at
                // `searchGap` they read as one thing with a join in it.
                // Both the launcher and the clipboard use it, which is the
                // whole reason it is its own number.
                anchors.topMargin: (isSearch || isClip)
                    ? Config.island.searchGap
                    : Config.island.podGap

                // The pill's width, taken directly: it is already on a
                // spring, and chasing a spring with a second spring
                // puts a lag between two edges meant to be one line.
                width: pill.width
                height: shelfHeight.value

                // Taken from the pill rather than restated, so the two
                // surfaces cannot end up different colours in a mode
                // nobody thought to check.
                readonly property real radius: Theme.corner(height)
                clip: true

                // An Item rather than the Rectangle it was, and only
                // so the shadow can sit outside the clip: the rows are
                // cut frame by frame as this collapses to nothing, and
                // a clip takes a shadow with it. The background was
                // `color: "transparent"` and drew nothing, so nothing
                // is lost but the line — see the Shadow beside this
                // item in `island`.
                Squircle {
                    smoothing: Config.appearance.cornerSmoothing
                    anchors.fill: parent
                    radius: shelf.radius
                    color: pill.color
                    borderWidth: Theme.islandEdge ? 1 : 0
                    borderColor: pill.borderColor
                }

                opacity: shown ? 1 : 0
                visible: opacity > 0.01

                Spring {
                    id: shelfHeight
                    shape: island
                    minimum: 0
                    target: shelf.shown
                        ? Math.max(shelf.rows, 1) * shelf.rowHeight
                          + Theme.padCard * 2
                        : 0
                }

                Behavior on opacity { ContentFade { revealing: shelf.shown } }

                SearchList { win: root; island: island; shelf: shelf }
                ClipList   { win: root; island: island; shelf: shelf }
            }


        }

        function openSettings(page) {
            settingsProc.command = ["qs", "-c", "island", "ipc", "call",
                                    "settings", "page", page];
            settingsProc.running = true;
        }

        Process { id: settingsProc; running: false }

        IpcHandler {
            enabled: root.primary
            target: "island"

            function toggle(): void { root.expanded = !root.expanded }
            function expand(): void { root.expanded = true }
            function collapse(): void { root.expanded = false }

            // The split, as a bind. It mirrors the press and hold
            // exactly rather than setting the flag directly, so a bind
            // and a gesture cannot disagree about when the island is
            // allowed to part: no track, no split.
            //
            // Worth a bind of its own — it is the gesture the iPhone's
            // island is known for, and a shell driven from the keyboard
            // should not be the one place it is unreachable.
            function split(): void {
                if (!island.media) return;
                if (root.expanded) root.expanded = false;
                root.split = true;
            }
            function unsplit(): void { root.split = false }

            // The media pod's press, from the keyboard, for the same
            // reason the split has one: a shell driven without a
            // pointer should not be the one place a gesture is
            // unreachable.
            function card(): void { root.toggleMediaCard() }

            function setVisibility(mode: string): void {
                if (mode === "always" || mode === "smart")
                    Config.island.visibility = mode;
            }
            function search(): void { root.openSearch() }
            function attention(on: bool): void { root.demandsAttention = on }
            function state(): string { return island.mode }

            // Everything the collapse decision reads. A closing control
            // centre is one of: the hover flag dropping, the collapse
            // timer running, or expanded being cleared elsewhere.
            function hover(): string {
                return "expanded=" + root.expanded
                    + " split=" + root.split
                    + " autoExpanded=" + root.autoExpanded
                    + " pillHover=" + pillHover.containsMouse
                    + " revealArea=" + revealArea.containsMouse
                    + " latch=" + root.hoverLatch
                    + " revealed=" + root.revealed
                    + " collapseTimer=" + collapseTimer.running
                    + " collapseDelay=" + Config.island.collapseDelay
                    + " mode=" + island.mode;
            }

            // The split's four shapes, because a split that looks wrong
            // is a geometry question and not a guess: the housing, the
            // two lobes, and the gap they part around.
            function splitinfo(): string {
                return "mode=" + island.mode
                    + " flag=" + root.split
                    + " media=" + island.media
                    + " enabled=" + Config.island.splitEnabled
                    + " pillW=" + Math.round(pill.width)
                    + " pillH=" + Math.round(pill.height)
                    + " housingH=" + Theme.housing(Config.island.idleHeight)
                    + " gap=" + Config.island.splitGap
                    + "\nleftLobe  shown=" + leftLobe.shown
                    + " w=" + Math.round(leftLobe.width)
                    + " h=" + Math.round(leftLobe.height)
                    + " class='" + leftLobe.playerClass + "'"
                    + " iconReady=" + leftLobe.iconReady
                    + "\nrightLobe shown=" + rightLobe.shown
                    + " w=" + Math.round(rightLobe.width)
                    + " h=" + Math.round(rightLobe.height)
                    + "\nislandW=" + Math.round(island.width)
                    + " islandH=" + Math.round(island.height)
                    + " leftSpan=" + Math.round(root.leftSpan)
                    + " rightSpan=" + Math.round(root.rightSpan);
            }

            // Everything a pod's size and presence is derived from.
            // A pod that is not there is one of: switched off, empty,
            // or undocked because the island is in another mode.
            function pods(): string {
                return "media      present=" + leftPod.present
                    + " open=" + leftPod.open
                    + " pinned=" + leftPod.pinned
                    + " w=" + Math.round(leftPod.width)
                    + " (rest=" + Math.round(leftPod.restWidth)
                    + " open=" + Math.round(leftPod.openWidth) + ")"
                    + "  class='" + leftPod.playerClass + "'"
                    + " iconReady=" + leftPod.iconReady

                    + "\ncontrol    present=" + rightPod.present
                    + " open=" + rightPod.open
                    + " pinned=" + rightPod.pinned
                    + " w=" + Math.round(rightPod.width)
                    + " (rest=" + Math.round(rightPod.restWidth)
                    + " open=" + Math.round(rightPod.openWidth) + ")"
                    + "\nworkspace  n=" + Wm.activeId
                    + " docked=" + rightPod.docked
                    + " mode=" + island.mode;
            }

            // Every term the media strip's visibility reads, so a
            // missing strip does not need guessing at.
            function media(): string {
                return "available=" + Player.available
                    + " title='" + Player.title + "'"
                    + " identity='" + Player.identity + "'"
                    + " desktopEntry='" + Player.desktopEntry + "'"
                    + " artUrl='" + (Player.artUrl === "" ? "(none)"
                                                          : Player.artUrl) + "'"
                    + " islandMedia=" + island.media
                    + " isControl=" + island.isControl
                    + " cardOpen=" + root.mediaOpen
                    + " cardShown=" + mediaHost.open
                    + " mode=" + island.mode
                    + " pillH=" + Math.round(pill.height)
                    + " needH=" + Math.round(ControlLayout.panelHeight * 0.9)
                    + " controlH=" + ControlLayout.panelHeight
                    + " rows=" + ControlLayout.rows
                    // The panel is its own shape now, so where it sits
                    // is the term that answers "why is the panel not
                    // where I expect it" — not the pill's height, which
                    // stays at the resting height throughout.
                    + " panelX=" + Math.round(controlHost.x)
                    + " panelY=" + Math.round(controlHost.y);
            }

            function why(): string {
                const r = root.islandRect;
                return "mode=" + island.mode
                    + " visibility=" + root.visibilityMode
                    + " revealed=" + root.revealed
                    + " occluded=" + root.occluded
                    + " overlapped=" + root.overlapped
                    + " fullscreen=" + Wm.fullscreen
                    + " empty=" + Wm.empty
                    + " windows=" + Wm.windows.length
                    + " latch=" + root.hoverLatch
                    + " islandRect=" + Math.round(r.x) + "," + Math.round(r.y)
                    + " " + Math.round(r.width) + "x" + Math.round(r.height)
                    + " screen=" + root.screen.width + "x" + root.screen.height;
            }

            function windows(): string {
                if (Wm.windows.length === 0) return "none";
                return Wm.windows.map(w =>
                    w.x + "," + w.y + " " + w.w + "x" + w.h).join("  |  ");
            }
        }

        IpcHandler {
            enabled: root.primary
            target: "notifications-ui"

            function toggle(): void {
                if (root.centreOpen) root.closeCentre();
                else root.openCentre();
            }
            // `show` cannot be reached from the command line: qs's
            // own `ipc show` subcommand swallows the word before it
            // gets as far as the function name, and even `--` does not
            // help. `open` is the same thing under a name the CLI can
            // actually pass. Both are kept — `show` still works for
            // anything talking to the socket directly.
            function open(): void { root.openCentre() }
            function show(): void { root.openCentre() }
            function hide(): void { root.closeCentre() }
        }

        IpcHandler {
            enabled: root.primary
            target: "switcher"

            function next(): void { root.openSwitcher(1) }
            function previous(): void { root.openSwitcher(-1) }
            function confirm(): void { root.activateSwitch() }
            function cancel(): void { root.cancelSwitch() }
        }

        IpcHandler {
            enabled: root.primary
            target: "overview"

            function toggle(): void {
                if (root.overviewOpen) root.closeOverview();
                else root.openOverview();
            }
            function open(): void { root.openOverview() }
            function show(): void { root.openOverview() }
            function hide(): void { root.closeOverview() }
        }

        IpcHandler {
            enabled: root.primary
            target: "clipboard-ui"

            function toggle(): void {
                if (root.clipOpen) root.closeClipboard();
                else root.openClipboard();
            }
            function open(): void { root.openClipboard() }
            function show(): void { root.openClipboard() }
            function hide(): void { root.closeClipboard() }
        }

        IpcHandler {
            enabled: root.primary
            target: "picker"

            function toggle(kind: string): void {
                const k = kind === "" ? "wallpaper" : kind;
                if (root.picker === k) root.closePicker();
                else root.openPicker(k);
            }
            function wallpapers(): void { root.openPicker("wallpaper") }
            function palettes(): void { root.openPicker("theme") }

            // Not a picker any more. An icon theme is changed about
            // once and then left, a grid of twenty of them is worse
            // than a list, and previewing one means resolving icons
            // out of a theme that is not the current one — which is
            // real machinery for an annual decision. Settings does it
            // better and already did.
            function icons(): void { root.openSettings("appearance") }
            function hide(): void { root.closePicker() }
        }

        IpcHandler {
            enabled: root.primary
            target: "control"

            function toggle(): void {
                if (root.expanded) root.closeControl();
                else root.openControl();
            }
            function open(): void { root.openControl() }
            function show(): void { root.openControl() }
            function hide(): void { root.closeControl() }

            // Straight to a sub-page: "wifi", "bluetooth", "sound",
            // or "" for the grid. Worth a bind of its own — the point
            // of the network list living in the panel is that getting
            // to it is one gesture, and that should include a key.
            function page(name: string): void {
                root.openControl();
                // After the open, not during it. The panel forgets its
                // sub-page when it closes, and if the panel was shut
                // when this arrived, that forgetting happens on the
                // binding pass this call triggers — which would land
                // after the assignment and wipe it.
                Qt.callLater(function() { controlMode.page = name });
            }
        }

        IpcHandler {
            enabled: root.primary
            target: "session"

            function toggle(): void {
                if (root.sessionOpen) root.closeSession();
                else root.openSession();
            }
            function open(): void { root.openSession() }
            function show(): void { root.openSession() }
            function hide(): void { root.closeSession() }
            function run(action: string): void { Session.run(action) }
        }

        // SUPER+R and ALT+Space are bound to launcher toggle.
        IpcHandler {
            enabled: root.primary
            target: "launcher"

            function toggle(): void {
                if (root.searching) root.closeSearch();
                else root.openSearch();
            }
            function open(): void { root.openSearch() }
            function show(): void { root.openSearch() }
            function hide(): void { root.closeSearch() }

            // Open it with something already typed — `open` alone
            // gives an empty field, which only a keyboard can fill.
            // Used by a bind that searches the selection, and by
            // docs/RECORDING.md.
            //
            // Sets both: the TextInput holds the text, Search holds
            // the query, and onTextChanged only fires for a change the
            // field itself makes.
            function query(text: string): void {
                root.openSearch();
                if (root.searchInput) root.searchInput.text = text;
                Search.query = text;
            }
        }
    }
}
