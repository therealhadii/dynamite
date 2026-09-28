pragma Singleton

import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications
import QtQuick

Singleton {
    id: root

    // [{ id, summary, body, appName, appIcon, image, urgency,
    //    time, actions, hasReply, replyHint }]
    //
    // Plain copies, with no reference to the Notification object —
    // see liveFor() for why.
    property var history: []
    property int maxHistory: 60

    // The most recent arrival, for the island's popup.
    property var latest: null

    // Arrivals that came in while something else was on screen, oldest
    // first. `latest` was the only slot there was, so a second
    // notification arriving during the first one's five seconds simply
    // overwrote it — you were shown the newest and lost the one you had
    // not finished reading, which is the one you actually needed to see.
    // Two arriving together was the worst case: you got the second and
    // the first was gone before it had ever been drawn.
    //
    // A queue rather than a stack, deliberately. The newest is the one
    // most likely to still be relevant, so it goes first and the rest
    // wait their turn — and each is presented in arrival order, so
    // nothing gets reordered behind your back.
    property var pending: []

    readonly property int pendingCount: pending.length

    signal arrived(var entry)

    // Show this one, or queue it if the island is busy.
    function present(entry) {
        if (!entry) return;
        if (root.latest !== null) {
            root.pending = root.pending.concat([entry]);
            return;
        }
        root.latest = entry;
        root.arrived(entry);
    }

    // Called when the current popup goes away. Returns the next entry to
    // show, or null when the queue is empty and the island should go back
    // to resting.
    //
    // Emitting `arrived` rather than making every caller reassign `notice`
    // is the point: the timer lives with the island and has to restart for
    // the next entry with that entry's own duration, so there is one place
    // that decides "this is being shown now" and it is the same place for
    // the first arrival and the fifth.
    function advance() {
        if (root.pending.length === 0) {
            root.latest = null;
            return null;
        }
        const next = root.pending[0];
        root.pending = root.pending.slice(1);
        root.latest = next;
        root.arrived(next);
        return next;
    }

    // Drop the backlog without showing any of it. For "dismiss", which
    // means the user is done rather than "show me the next one".
    function clearPending() {
        for (const e of root.pending) root.release(e);
        root.pending = [];
    }

    readonly property int count: history.length
    readonly property bool hasUnread: unread > 0
    property int unread: 0

    function markRead() { unread = 0; root.readAt = Date.now() }

    // When the centre was last opened, so a row can tell whether it is
    // one you have not looked at.
    //
    // A timestamp rather than a per-entry flag on purpose. The flag
    // version is wrong the moment a notification arrives while the
    // centre is already open — it would be born read or born unread
    // depending on which half of the code set it, and there is no way to
    // clear one without walking the whole list. "Newer than the last
    // time I looked" needs no bookkeeping and cannot drift.
    property double readAt: 0

    function isUnread(entry) {
        return !!entry && entry.time > root.readAt;
    }

    // The live Notification for a history entry, or null once the
    // sender has closed it.
    //
    // History stores plain copies and looks the object up by id. Do
    // not hold the QObject: Notification is Retainable and is
    // destroyed once onNotification returns, after which the JS
    // wrapper stays truthy and every read comes back undefined — so it
    // fails as a TypeError at the call site, nowhere near the cause.
    function liveFor(id) {
        const tracked = server.trackedNotifications;
        if (!tracked || !tracked.values) return null;
        for (const n of tracked.values) {
            if (n && n.id === id) return n;
        }
        return null;
    }

    function isLive(entry) { return !!entry && liveFor(entry.id) !== null }

    function release(entry) {
        if (!entry) return;
        const n = liveFor(entry.id);
        if (n) {
            try { n.tracked = false } catch (e) { /* already gone */ }
        }
    }

    function dismiss(entry) {
        if (!entry) return;
        release(entry);
        history = history.filter(e => e.id !== entry.id);
        // A queued entry can be dismissed from the centre before it is
        // ever shown, so it has to come out of the queue as well — or it
        // would surface later as a popup for a notification the user has
        // already thrown away.
        if (pending.length > 0)
            pending = pending.filter(e => e.id !== entry.id);
        if (latest && latest.id === entry.id) latest = null;
    }

    function clear() {
        for (const e of history) release(e);
        clearPending();
        history = [];
        latest = null;
        unread = 0;
    }

    function invoke(entry, index) {
        const n = liveFor(entry ? entry.id : -1);
        if (!n) return;
        try {
            const a = n.actions[index];
            if (a) a.invoke();
        } catch (e) { /* the sender went away mid-click */ }
    }

    // Chat clients that advertise a reply expect the text back over
    // the same notification rather than through an action.
    function reply(entry, text) {
        if (!text) return false;
        const n = liveFor(entry ? entry.id : -1);
        if (!n) return false;
        try {
            n.sendInlineReply(text);
            return true;
        } catch (e) {
            // The sender closed the conversation, or went away
            // entirely, between the popup appearing and Enter.
            console.warn("[Notifications] inline reply failed:", e);
            return false;
        }
    }

    function urgencyName(u) {
        if (u === NotificationUrgency.Critical) return "critical";
        if (u === NotificationUrgency.Low) return "low";
        return "normal";
    }

    NotificationServer {
        id: server

        // Advertised capabilities. Off by default in Quickshell, and
        // a client that isn't told images are supported won't send
        // one — so these have to be opted into.
        imageSupported: true
        actionsSupported: true
        bodySupported: true
        bodyMarkupSupported: true
        persistenceSupported: true
        keepOnReload: true
        // Clients only offer a reply box when the daemon says it can
        // take one, so this has to be on before any notification
        // arrives carrying hasInlineReply.
        inlineReplySupported: true

        onNotification: function(n) {
            // Carried over from a reload — already in history.
            if (n.lastGeneration) return;

            // The server discards a notification as soon as this
            // handler returns unless it is asked to keep it. Nothing
            // did, so trackedNotifications was always empty and every
            // reach back to the sender — an action invoked from
            // history, an inline reply — had nothing to reach.
            n.tracked = true;

            const entry = {
                id: n.id,
                summary: n.summary,
                body: n.body,
                appName: n.appName,
                appIcon: n.appIcon,
                image: n.image,
                urgency: root.urgencyName(n.urgency),
                critical: n.urgency === NotificationUrgency.Critical,
                time: Date.now(),
                actions: n.actions.map(a => a.text),
                hasReply: n.hasInlineReply,
                replyHint: n.inlineReplyPlaceholder || "Reply"
            };

            const next = [entry, ...root.history];
            // Anything falling off the end still holds a lock, and a
            // lock nothing will ever release is a leak.
            for (const old of next.slice(root.maxHistory)) root.release(old);

            root.history = next.slice(0, root.maxHistory);
            root.unread += 1;

            // Focus mode records but doesn't interrupt. Critical
            // notifications ignore it — that's what critical means.
            //
            // Queued, not overwritten — see `pending`.
            if (!Config.island.dnd || entry.critical)
                root.present(entry);
        }
    }

    IpcHandler {
        target: "notifications"

        function count(): int { return root.history.length }
        function clear(): void { root.clear() }

        // Whether the most recent notification offered a reply box,
        // and a way to exercise it without a pointer. Chat clients
        // are the only thing that sets this, so it is otherwise
        // awkward to test that the D-Bus side works.
        function replyState(): string {
            const e = root.history[0];
            if (!e) return "no notifications";
            return e.appName + ": hasReply=" + (e.hasReply === true)
                 + " placeholder='" + (e.replyHint || "") + "'"
                 + " stillLive=" + root.isLive(e);
        }

        function invoke(index: int): string {
            const e = root.history[0];
            if (!e) return "no notifications";
            if (!root.isLive(e)) return "the sender has closed it";
            if (index < 0 || index >= e.actions.length)
                return "no action " + index + " (has " + e.actions.length + ")";
            root.invoke(e, index);
            return "invoked '" + e.actions[index] + "'";
        }

        function reply(text: string): string {
            const e = root.history[0];
            if (!e) return "no notifications";
            if (e.hasReply !== true) return "that notification takes no reply";
            return root.reply(e, text) ? "sent" : "failed";
        }
        function last(): string {
            const e = root.history[0];
            return e ? e.appName + ": " + e.summary : "none";
        }

        // Which entry the popup is showing right now, and how many are
        // queued behind it.
        //
        // The queue's whole behaviour is a question of ordering over
        // time, and ordering over time is exactly what you cannot check
        // by looking at a screen once. Without this the only way to test
        // that notifications drain in the order they arrived is to watch
        // the desktop for half a minute, which needs it unlocked and
        // needs a person.
        function shown(): string {
            const l = root.latest;
            return (l ? l.appName + ": " + l.summary : "nothing")
                 + "  (+" + root.pending.length + " queued)";
        }
    }
}
