import QtQuick

import "root:/Services"

// Wi-Fi and Bluetooth: what it is, what it is attached to, and a way
// into the list.
//
// "Which network" is most of why anyone opens a control centre, so the
// card carries the answer. Two targets, and they look different: the
// badge is the power switch, the rest of the row is the way in.
//
// Squeezed to one cell it becomes the circle itself — no inner disc,
// no words, the whole card the switch — which is how the reference
// draws its lock and its moon: one shape, one fact, at a size you can
// hit without aiming.

Item {
    id: root

    property string glyph: ""
    property string name: ""
    property string sub: ""
    property bool on: false
    property bool busy: false

    // Whether the card is allowed words at all. Off, it is the circle
    // alone at any size — which is the whole point: somebody who knows
    // their own panel does not need it read back to them.
    property bool showText: true

    // False once the card is one cell wide, or once the words have
    // been turned off.
    // Roomy enough for words is a question about the column left over
    // after the badge, not about the card's aspect: a 72px card is
    // wider than it is tall and still leaves thirty pixels for a name,
    // which is how "Keep awake" ends up rendering as "K…".
    //
    // Forty rather than seventy because the panel is now six square
    // cells: a two-cell row is 106px and leaves forty-two for "Focus",
    // which is the shortest name in the catalogue and fits. Seventy
    // measured the wide panel this one replaced, and at that threshold
    // every two-cell row silently dropped to a bare glyph.
    readonly property bool roomy:
        showText && width - height > 40

    signal toggled()
    signal opened()

    Surface {
        anchors.fill: parent
        // Squezed to one cell the badge has no disc (see Badge) and
        // the card takes over the state: a circle that fills when what
        // it stands for is on. With words beside it the badge is the
        // answer and the card stays neutral — lighting both would say
        // the same thing twice.
        pill: true
        lit: !root.roomy && root.on
        hovered: rowHover.containsMouse
    }

    // A card that only changes colour under the pointer tells you it
    // is hoverable. Giving way under the press is what tells you it
    // was hit — and it is the one animation here that has to be
    // immediate, because it is answering an action rather than
    // reporting a state.
    scale: rowHover.pressed || badgeTap.pressed ? 0.97 : 1

    Behavior on scale {
        NumberAnimation {
            duration: Motion.hover
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Motion.arrive
        }
    }

    // Two answers, because there are two cards. With words, the row is
    // the way in and the badge beside it is the switch. Without them
    // there is no way in — a page of what you are attached to that you
    // reached by pressing a circle you could not read — so the whole
    // card becomes the switch instead, which is the larger and the
    // more obvious of the two targets.
    MouseArea {
        id: rowHover
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.roomy ? root.opened() : root.toggled()
    }

    // Positioned, not anchored. The badge sits against the left edge
    // when there is a label beside it and in the middle when there is
    // not, and the obvious way to write that — an anchor bound to
    // `undefined` for the case that does not apply — does not work:
    // assigning undefined to an anchor does not clear it, so the item
    // ends up anchored by both `left` and `horizontalCenter` at once,
    // and Qt quietly derives the width from the pair. The symptom is a
    // 30px circle rendering as a 108px capsule.
    Badge {
        id: badge

        readonly property int size:
            Math.max(20, Math.min(30, root.height - 18))

        width: size
        height: size

        x: root.roomy ? Theme.padCard
                      : Math.round((root.width - size) / 2)
        y: Math.round((root.height - size) / 2)

        glyph: root.glyph
        lit: root.on
        bare: !root.roomy

        MouseArea {
            id: badgeTap
            anchors.fill: parent
            // A 30px circle is a small target, and the row behind it
            // does something different — so it is widened past its
            // own edges rather than left exactly the size of the ink.
            anchors.margins: -5
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.toggled()
        }
    }

    Column {
        anchors.left: badge.right
        anchors.leftMargin: Theme.gapBadge
        anchors.right: chevron.left
        anchors.rightMargin: Theme.spacingSmall
        anchors.verticalCenter: parent.verticalCenter
        spacing: 1
        visible: root.roomy

        Text {
            width: parent.width
            text: root.name
            color: Theme.text
            font.family: Theme.fontIsland
            font.pixelSize: Theme.fontSizeSmall + 1
            font.weight: Font.Bold
            elide: Text.ElideRight
            renderType: Text.NativeRendering
        }

        Text {
            width: parent.width
            // "Scanning…" while a scan is running, because a list that
            // is about to change should say so rather than showing a
            // stale answer with no explanation.
            text: root.busy ? "Scanning…" : root.sub
            color: Theme.textDim
            font.family: Theme.fontIsland
            font.pixelSize: Theme.fontSizeCaption
            font.weight: Font.DemiBold
            elide: Text.ElideRight
            renderType: Text.NativeRendering
        }
    }

    Text {
        id: chevron
        anchors.right: parent.right
        anchors.rightMargin: Theme.padCard
        anchors.verticalCenter: parent.verticalCenter
        visible: root.roomy
        text: "›"
        color: rowHover.containsMouse ? Theme.text : Theme.outline
        font.family: Theme.fontIsland
        font.pixelSize: 15
        renderType: Text.NativeRendering

        Behavior on color { ColorAnimation { duration: Motion.fadeIn } }
    }
}
