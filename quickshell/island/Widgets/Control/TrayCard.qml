import QtQuick

import "root:/Services"
import "root:/Widgets"

// System tray apps, in the panel.
//
// The tray used to live in the right-hand pod, behind a hover, and the
// hover is what put it here: pointing at the button that opens the
// control centre widened the pod into a row of icons before the press
// landed, so the gesture for "change something" kept arriving somewhere
// else. The tray is the same answer to a different question — "what is
// running" is a glance, not a decision — and a control centre already
// holds the answers to every other glance of that kind.
//
// So it is a card like any other: it can be dragged anywhere on the
// grid, resized, and removed by somebody who does not run tray
// applications. It is the one card with no words of its own. The
// artwork already says which app it is, and "Tray" set in bold beside
// a single 24px icon was the loudest thing on the panel while having
// the least to say — the word was four times the size of the only
// thing in the card worth looking at. So the icons take the middle of
// the card and the type is left out of it entirely.
//
// No whole-card click. The icons are the controls, and a card that
// also fired when you pressed the gap between two of them would be a
// second target with no visible edge.

Item {
    id: root

    // The window a menu is displayed against — see Widgets/TrayIcon.
    required property var win

    // False in the layout editor, where everything is drawn but inert.
    property bool live: true

    readonly property int count: Tray.count
    readonly property int iconSize: Math.max(18, Math.min(24, height - 18))

    // `Tray.count` is read on purpose, before the array itself. The
    // row is `items.values`, but an icon arriving is the `countChanged`
    // the tray pod used to watch, and naming it here is what makes this
    // binding re-evaluate — and the Repeater rebuild — when one does.
    // Without it the array is the same array and nothing moves.
    readonly property var icons: {
        const n = Tray.count;
        return (Tray.items && n > 0) ? Tray.items.values : [];
    }

    // Cards do not clip by default and a row of icons is the first
    // thing in the panel that can be wider than its cell.
    clip: true

    Surface {
        anchors.fill: parent
    }

    // The same answer NotesCard gives, and for the same reason: an
    // empty tray is a state worth stating rather than a card that
    // looks broken.
    Text {
        anchors.centerIn: parent
        visible: root.count === 0
        text: "Nothing in the tray"
        color: Theme.textDim
        font.family: Theme.fontIsland
        font.pixelSize: Theme.fontSizeSmall
        font.weight: Font.DemiBold
        renderType: Text.NativeRendering
    }

    // Centred, and clamped to the card rather than to the space a
    // label used to leave beside it. Fewer icons than the card can
    // hold and they sit in the middle like a dock; more, and the
    // window narrows to a centred strip that is cut evenly at both
    // ends rather than losing everything past the right edge.
    Item {
        id: slot

        anchors.verticalCenter: parent.verticalCenter
        width: Math.min(row.width,
                        Math.max(0, root.width - 2 * Theme.padCard))
        x: Math.round((root.width - width) / 2)
        height: root.iconSize

        // A Row rather than a Flow: past the last icon that fits, the
        // honest shape is a row cut off at the edge, not a second row
        // clipped to nothing by a one-cell card.
        clip: true

        Row {
            id: row
            height: parent.height
            spacing: 8

            Repeater {
                model: root.icons

                TrayIcon {
                    required property var modelData

                    item: modelData
                    win: root.win
                    size: root.iconSize

                    // The editor draws this card with everything inert,
                    // so a click starts a drag rather than opening a
                    // menu over the settings window.
                    enabled: root.live
                }
            }
        }
    }
}
