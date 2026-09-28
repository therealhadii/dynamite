pragma Singleton

import Quickshell
import Quickshell.Io
import Quickshell.Services.SystemTray
import QtQuick

// System tray.
//
// Referencing SystemTray.items is what makes quickshell register as
// the StatusNotifierItem host, so this singleton existing is
// load-bearing — no application can place an icon until something
// asks for the list.

Singleton {
    id: root

    readonly property var items: SystemTray.items
    readonly property int count: items ? items.values.length : 0

    // The top of the tray, or null when it is empty.
    //
    // `SystemTray.items` is a keyed object, not an array, so the values
    // live under `.values` — and reaching into that shape from a pod is
    // how `items[0]` and `items.length` end up quietly undefined rather
    // than loudly wrong. Both were tried for the tray pod's resting
    // circle and the circle came out empty with no error anywhere,
    // because `undefined > 0` is false and `undefined[0]` is undefined
    // and neither of those throws.
    //
    // A tray is a priority order rather than a set: the host publishes
    // the icon with the highest `X-Hyprland-Pass` last, so the last
    // value is the one the user most wants at the front. This is that
    // value, and a pod that wants "the one to show" asks for it by name
    // rather than re-deriving the rule.
    readonly property var first:
        (items && items.values.length > 0)
            ? items.values[items.values.length - 1]
            : null

    readonly property bool anyAttention: {
        if (!items) return false;
        for (const i of items.values) {
            if (i.status === Status.NeedsAttention) return true;
        }
        return false;
    }

    IpcHandler {
        target: "tray"

        function count(): int { return root.count }

        function list(): string {
            if (root.count === 0) return "empty";
            return root.items.values.map(i =>
                i.id
                + (i.title !== "" ? "  " + i.title : "")
                + (i.hasMenu ? "  [menu]" : "")
                + (i.onlyMenu ? " only" : "")
                + (i.status === Status.NeedsAttention
                   ? "  [attention]" : "")
            ).join("\n");
        }

        // Activating from the command line is useful when an item has
        // no visible icon because its theme lookup failed.
        function activate(id: string): void {
            if (!root.items) return;
            for (const i of root.items.values) {
                if (i.id === id) { i.activate(); return; }
            }
        }
    }
}
