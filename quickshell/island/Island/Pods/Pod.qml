import QtQuick

import "root:/Services"
import "root:/Widgets"

// A satellite beside the island: a small capsule flanking the pill.
//
// There are two — now playing on the left, the control button on the
// right. There used to be one on the right and a workspace pod on the
// left that said where you were, and the pill says that itself now, so
// the side below is a generality rather than a choice. It is kept
// because the alternative is a pod that cannot be moved without
// rewriting what it means, and `side` is two lines.
//
// It never moves the island's centre. Rest/open widths handle the
// docked state; split mode adds one deliberate activity width. The pod
// itself stays mounted so its content can travel with the shape.
//
// Content is declared as ordinary children, and input areas are
// ordered by z rather than declaration so a pod can be subclassed.

Item {
    id: root

    required property var win      // the PanelWindow
    required property var island   // mode flags
    required property var pill     // the shape it hangs off

    // Which edge of the pill it attaches to.
    property string side: "left"   // "left" | "right"

    // False when there is nothing to show at all — no player, no
    // reason to be there. An empty capsule sitting there is clutter of
    // exactly the kind the pods exist to remove, so it collapses
    // instead.
    property bool present: true

    // Measured from the two content layers by whoever declares the
    // pod. Both are plain implicitWidths of layouts that do not
    // animate, so the pod's own morph has nothing to chase.
    property real restWidth: 32
    property real openWidth: 120
    property real splitWidth: restWidth

    // Click the pod's own background and it stays open. Hovering is a
    // look; this is for when you want it to hold still.
    property bool pinned: false

    readonly property bool hovered: hoverArea.containsMouse
    readonly property bool open: present && (hovered || pinned)
    readonly property bool split: island.mode === "split"

    // Pods belong to the collapsed island, and to the control centre —
    // which now opens *below* this row rather than replacing it, so the
    // two circles and the clock stay on screen while the panel is in
    // use. Every other mode is a panel that owns the whole shape, and
    // satellites orbiting a search field are debris. "hidden" is docked
    // too: the island slides up off the screen as one object and the
    // pods ride with it rather than fading out first and leaving it to
    // go alone.
    //
    // There is no `compact` to exclude. Hover used to be a mode and
    // this list had to name it, because hovering the pill lifted all
    // three shapes together — which meant the pod's height had two
    // values and this was where it chose between them. Hover is a
    // cross-fade inside a fixed pill now, so the pod's height is simply
    // the resting height and there is nothing to choose.
    readonly property bool docked:
        island.mode === "idle" || island.mode === "hidden"
        || island.mode === "expanded" || root.split

    readonly property bool shown: docked && present

    // ── How the shape moves ──────────────────────────────────
    //
    // Same contract as the island: the pod says where it is going and
    // every spring on it reads the answer. Opening under the cursor is
    // not a moment to be springy: a capsule that overshoots while you
    // are reaching for its content moves the content.
    //
    // There was a third tier here — a *peek*, the one moment a pod was
    // allowed to pop, for the instant what it shows changed. It went
    // with the tray that drove it: the two callers were a tray icon
    // arriving and an attention flag, and both pods are one size now
    // anyway, so a peek had no width to move. A motion tier for a
    // movement that cannot happen is a number nobody can hear.
    readonly property int springResponse:
        !shown ? Motion.collapseResponse
             : (split ? Motion.expandResponse
                   : (open ? Motion.hoverResponse
                        : Motion.collapseResponse))

    readonly property real springBounce:
         !shown ? Motion.departBounce
             : (split ? 0
                   : (open ? Motion.arriveBounce
                        : Motion.departBounce))

    // A pod that empties, or one the island has taken the screen back
    // from, must not stay held open at nothing.
    onPresentChanged: if (!present) pinned = false
    onDockedChanged: if (!docked) pinned = false

    // ── Geometry ─────────────────────────────────────────────
    //
    // Centred on the pill's edge, so the pod follows it and the pill
    // never has to know the pod exists. Only one of the two anchors is
    // ever set; the unused margin is harmless. Centred, not top-hung:
    // the week strip grows the pill taller than the pods, and a pod
    // hanging off the top edge reads as misaligned next to the lobes,
    // which centre themselves already.

    anchors.verticalCenter: pill.verticalCenter
    anchors.right: side === "left" ? pill.left : undefined
    anchors.left: side === "right" ? pill.right : undefined

    anchors.rightMargin: tuck.value
    anchors.leftMargin: tuck.value

    // Negative on the way out, so the pod slides under the pill's
    // edge as it goes rather than blinking off beside it. One spring
    // for both: only one of the two anchors is ever set.
    Spring {
        id: tuck
        shape: root
        target: root.shown
            ? (root.split ? 2 : Config.island.podGap)
            : -8
    }

    width: podWidth.value
    height: podHeight.value

    opacity: shown ? 1 : 0
    scale: podScale.value
    // Toward the pill, so a leaving pod collapses into the island
    // instead of shrinking into its own middle.
    transformOrigin: side === "left" ? Item.Right : Item.Left
    visible: opacity > 0.01

    // The same spring the pill is on, so the three shapes move as one
    // object. Collapsing to nothing is why departures keep so little
    // bounce, and why each of these has a floor: an overshoot at zero
    // is a negative width, and a negative width anchored to the
    // pill's edge draws over the pill.

    // Never narrower than it is tall. One workspace dot or one tray
    // icon measures about twenty-five pixels against a height of
    // thirty-four, and a capsule narrower than it is tall turns into a
    // lozenge standing on end beside a pill lying down — which is the
    // one shape the island does not own.
    //
    // At the floor it is square, so a pod with a single thing in it
    // comes out as a circle: the corner has the full half-height to
    // spend, and a dot in a circle is the same answer the pill gives
    // for a clock.
    //
    // Measured against the height's target rather than its current
    // value: a width that chased the height's spring would arrive
    // behind it, and the two are one shape.
    Spring {
        id: podWidth
        shape: root
        minimum: 0
        target: root.shown
            ? Math.max(podHeight.target,
                       root.split ? root.splitWidth
                       : root.open ? root.openWidth : root.restWidth)
            : 0
    }

    // The resting height, and the only one there is.
    //
    // It used to be a choice between this and `island.compactHeight`,
    // so that hovering either shape lifted all three together. With no
    // hover state there is nothing to lift to, and a pod at one height
    // is one number rather than a comparison made on every frame.
    Spring {
        id: podHeight
        shape: root
        minimum: 0
        target: Config.island.idleHeight
    }

    // How far it leans out of the way while it is absent.
    Spring {
        id: podScale
        shape: root
        minimum: 0
        target: root.shown ? 1 : Motion.absentScale
    }

    Behavior on opacity {
        ContentFade { revealing: root.shown }
    }

    // ── Surface ──────────────────────────────────────────────
    //
    // The pill's, exactly: same fill, same radius, same edge. A pod is
    // the island in a smaller shape, not a different widget.

    // The pill's, exactly — the same function against its own height,
    // so a pod at 34px and a pill at 34px are the same shape, and now
    // the same curve as well.
    readonly property real radius: Theme.corner(height)

    // The pill's, exactly — and a pod only exists while the island is
    // docked, so that is one colour rather than a choice. Hovering
    // lifts all three shapes and recolours none of them.
    readonly property color fill: {
        if (Config.appearance.islandBlack) return Theme.islandSurface;
        const c = Qt.color(Theme.surfaceLowest);
        return Qt.rgba(c.r, c.g, c.b, Config.island.opacity);
    }

    // A pod clips its content — a row wider than the pod is cut frame
    // by frame as the capsule closes, which is the point — and a clip
    // takes the shadow with it. So the surface and everything in it
    // live in `shell`, and only the shadow sits on the root where it
    // can reach past the edge.
    //
    // And a subclass's children go in here too, which is what the
    // alias below is for: `Item`'s default property is `data`, so
    // redirecting it means a pod declares its rows exactly as it always
    // has and they land inside the clipping container instead of beside
    // it. No change to ControlPod or MediaPod.
    default property alias content: shell.data

    // Three overlapping shadows merging into one soft band under all
    // three shapes is the right answer rather than a wrong one: it is
    // what says the pods and the pill are one object sitting on the
    // wallpaper rather than three that happen to be near each other.
    //
    // Pointed at the surface rather than at the pod, so it takes its
    // radius from the thing actually drawing the corner. The squircle
    // is declared below and ids resolve file-wide, so the order is not
    // a problem.
    Shadow { shape: surface; anchors.fill: shell; spread: 10 }

    Item {
        id: shell
        anchors.fill: parent
        clip: true

        // Declared first so it sits under everything, which is what
        // the Rectangle's own background used to do. See
        // Widgets/Squircle.qml for why a pod cannot simply be a
        // Rectangle any more.
        Squircle {
            id: surface
            smoothing: Config.appearance.cornerSmoothing
            anchors.fill: parent
            radius: root.radius
            color: root.fill
            borderWidth: Theme.islandEdge ? 1 : 0
            borderColor: Theme.outlineVariant
        }

        // The pill's second line too — a pod is the island in a
        // smaller shape, and half an edge is a shape it would not
        // share. Gated with the hairline; see
        // Config.appearance.islandEdge.
        Bezel {
            z: 49
            outer: root.radius
            visible: Theme.islandEdge
        }

        // Pinning is a state, so it says so rather than leaving you to
        // wonder why the pod stopped closing. Above the content and
        // below the hover area, and inert either way.
        Squircle {
            z: 50
            anchors.fill: parent
            radius: root.radius
            smoothing: Config.appearance.cornerSmoothing
            color: "transparent"
            borderWidth: 1
            borderColor: Theme.primary
            opacity: root.pinned ? 0.55 : 0
            visible: opacity > 0.01

            Behavior on opacity { NumberAnimation { duration: Motion.fadeIn } }
        }

        // ── Input ────────────────────────────────────────────
        //
        // Beneath the content, so whatever the pod holds gets its own
        // clicks and this only catches presses on the empty capsule
        // around them.
        MouseArea {
            z: -1
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: root.pinned = !root.pinned
        }

        // A MouseArea rather than a HoverHandler, and above everything
        // — the same reason Island.qml gives for the pill. A child
        // MouseArea with hoverEnabled consumes hover, so a handler
        // underneath one stops reporting the moment the cursor reaches
        // a tray icon, and the pod would close while you were pointing
        // at it.
        //
        // NoButton means it sees hover but never takes a click.
        MouseArea {
            id: hoverArea
            z: 100
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.NoButton
            propagateComposedEvents: true

            // Keeps smart hiding from pulling the island out from
            // under a pod you are reading.
            onContainsMouseChanged: win.touch(containsMouse)
        }
    }
}
