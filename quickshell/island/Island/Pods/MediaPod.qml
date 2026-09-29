import Quickshell
import QtQuick
import QtQuick.Shapes

import "root:/Services"
import "root:/Widgets"

// Now playing, left of the island.
//
// This is the workspace pod's old seat, and the thing that belongs in
// it. A workspace indicator answers "where am I", which the pill now
// says for itself the moment you move — see IdleMode. What the pill
// cannot say is *what is playing*, because at rest it holds the clock
// and one number, and the split that can answer it needs a
// press-and-hold to reach.
//
// **A circle at rest; a track capsule on deliberate split.** The
// ordinary docked row stays balanced, while a press-and-hold widens this
// same pod to identify the activity in place.
//
//   - The row is two circles and a pill. A 199px capsule beside a 34px
//     circle is not that, and it leaves the row lopsided with the clock
//     shoved off the middle — the one thing the pods are explicitly not
//     allowed to do.
//   - The track's name was never missing, it was one gesture away. The
//     split shows the cover and the name together, and the split is the
//     press-and-hold this shell was asked for. Hovering a circle is an
//     accident; pressing and holding is a decision, and a readout is
//     worth the second one.
//
// `openWidth` stays equal to `restWidth`, so hover and pinning do not
// widen the docked pod. `splitWidth` is reserved for the deliberate
// activity transition; the artwork stays in this pod as the title
// appears beside it. Hover still keeps smart-hiding from pulling the
// island out from under a pointer sitting on the cover.
//
// **The cover is the face, for the same reason it is in the split: a
// music service in a browser publishes no icon to find.** MPRIS reports
// the *browser*, so YouTube Music in Brave arrives as "Brave Origin"
// and asks for an icon called `origin`. Every player worth the name
// publishes `xesam:artUrl` instead — the track's own picture — and it
// needs no table of services and cannot fall out of date.
//
// At 34px across it is not legible the way a 640px JPEG is not legible
// at 34px. It is *recognisable*, and it is the only thing at the top of
// the screen that changes when the track does.

Pod {
    id: root

    side: "left"

    // There is nothing to show when nothing is playing, and a circle
    // sitting there saying so is the exact clutter the pods exist to
    // remove. `Player.available`, not `Player.playing`: a paused player
    // is still the thing you paused, and the control to unpause it is
    // the reason to keep the circle on screen.
    present: Config.island.showMedia && Player.available

    // The height, so the resting shape is a circle. `Pod` clamps a
    // pod's width to its height and `Theme.corner` is `h/2` at this
    // height, so the shape is round without anything here asking for a
    // radius.
    restWidth: Config.island.idleHeight

    // Equal to `restWidth`, deliberately. It is the honest way to say
    // "this pod is one size" while living in a base class that has two,
    // and it means hovering and pinning cost nothing instead of being
    // special-cased out of the width spring.
    openWidth: Config.island.idleHeight
    readonly property int coverEdge: 26
    splitWidth: Math.round(Theme.padRow + coverEdge + Theme.spacingSmall
        + Math.min(Math.max(splitTitleShort.implicitWidth,
                            splitTitleLong.implicitWidth) + 1, 128)
        + Theme.padRow)

    // ── The cover, in a circle ───────────────────────────────

    // **A round cover, and `Widgets/CoverCircle.qml` is why that is
    // possible at all.** It used to be a plain `Image` inset and
    // centred, on the theory that the pod's own circular clip would round
    // it — and `clip: true` in Qt Quick clips to the item's *bounding
    // rectangle*, never to its shape, so all four corners sat outside the
    // circle fully painted: a round thumbnail inside a square of
    // artwork, which is the thing that looked wrong in the first place.
    // The widget draws the circle itself, with a clip on a `Canvas`.
    //
    // Ten of 34, so five pixels of the pod's own surface show all the way
    // round as a frame. It was six, which put the artwork's edge exactly
    // under the progress ring: the cover touched the ring with nothing
    // between them, so the shape read as a picture crammed into the pill
    // rather than a picture sitting in it. The five are spent in three
    // bands, and the ring still lands in the same place — see below.

    // The face, which gives way when pressed — the control pod's answer,
    // so both circles sink the same distance under the same gesture.
    // The ring stays out of it, as it does over there: the gauge is not
    // part of the button.
    Item {
        id: face

        anchors.fill: parent
        scale: press.pressed ? 0.9 : 1

        Behavior on scale {
            NumberAnimation {
                duration: Motion.fadeIn
                easing.type: Easing.BezierSpline
                easing.bezierCurve: press.pressed ? Motion.ease : Motion.arrive
            }
        }

    CoverCircle {
        id: cover
        x: root.split ? Theme.padRow
                      : (Config.island.idleHeight - root.coverEdge) / 2
        anchors.verticalCenter: parent.verticalCenter
        width: root.coverEdge
        height: root.coverEdge
        visible: ready
        source: Player.artUrl
        // The pod's own fill, alpha and all — see `CoverCircle.backdrop`
        // for why the canvas cannot be left transparent.
        backdrop: root.fill

        Behavior on x {
            NumberAnimation {
                duration: root.split ? Motion.expand : Motion.collapse
                easing.type: root.split ? Easing.OutCubic : Easing.InCubic
            }
        }
    }

    // The app's own icon, for a player that publishes no cover at all.
    // Rare, and the `Brave Origin` → `origin` case is why — see the note
    // on `playerClass`.
    Image {
        id: appIcon
        width: 19
        height: 19
        sourceSize.width: 19
        sourceSize.height: 19
        visible: !cover.ready && status === Image.Ready
        source: root.playerClass !== ""
            ? Quickshell.iconPath(root.playerClass, true)
            : ""
        fillMode: Image.PreserveAspectFit
        asynchronous: true
        x: root.split ? Theme.padRow + (root.coverEdge - width) / 2
                  : (Config.island.idleHeight - width) / 2
        anchors.verticalCenter: parent.verticalCenter
    }

    // The backstop: a glyph that shows while the two Images above have
    // not answered, rather than an empty circle that reads as a failed
    // load. The same arrangement NotifyMode uses for a notification
    // with no icon.
    Text {
        visible: !root.iconReady
        text: Icons.music
        color: Theme.textDim
        font.family: Theme.fontIcons
        font.pixelSize: 15
        font.weight: Config.island.fontWeight
        renderType: Text.NativeRendering
        x: root.split ? Theme.padRow + (root.coverEdge - width) / 2
                      : (Config.island.idleHeight - width) / 2
        anchors.verticalCenter: parent.verticalCenter

        Behavior on x {
            NumberAnimation {
                duration: root.split ? Motion.expand : Motion.collapse
                easing.type: root.split ? Easing.OutCubic : Easing.InCubic
            }
        }

        Behavior on x {
            NumberAnimation {
                duration: root.split ? Motion.expand : Motion.collapse
                easing.type: root.split ? Easing.OutCubic : Easing.InCubic
            }
        }
    }

    Text {
        id: splitTitle
        x: Theme.padRow + root.coverEdge + Theme.spacingSmall
        width: Math.max(0, parent.width - x - Theme.padRow)
        anchors.verticalCenter: parent.verticalCenter
        text: Player.title
        color: Theme.text
        font.family: Theme.fontIsland
        font.pixelSize: Theme.fontSizeCaption
        font.weight: Font.DemiBold
        elide: Text.ElideRight
        renderType: Text.NativeRendering
        opacity: root.split ? 1 : 0
        visible: root.split || opacity > 0.01

        Behavior on opacity { NumberAnimation { duration: Motion.fadeIn } }
    }

    Text {
        id: splitTitleShort
        visible: false
        text: "Song Title"
        font.family: Theme.fontIsland
        font.pixelSize: Theme.fontSizeCaption
        font.weight: Font.DemiBold
    }

    Text {
        id: splitTitleLong
        visible: false
        text: "Song Title (feat. Someone)"
        font.family: Theme.fontIsland
        font.pixelSize: Theme.fontSizeCaption
        font.weight: Font.DemiBold
    }
    }

    // ── Where you are in the track ──────────────────────────
    //
    // On the rim, because at 34px the rim is the only part of the
    // circle that is not already spoken for: the middle is the cover,
    // and the band between the artwork's edge and the hairline outside
    // it is five pixels now. Two of them are bare pod between the cover
    // and the ring, two are the ring, and the last is left to the
    // hairline outside it — so the gauge reads as the pill's own rim
    // rather than as a picture with a gauge bolted to it.
    //
    // Shapes rather than Canvas, and the reason Widgets/BatteryRing
    // gives: the sweep is a plain number, so it can carry a Behavior
    // and the arc *runs* instead of stepping once a second with the
    // MPRIS poll.
    Item {
        id: ring

        anchors.fill: parent

        readonly property real stroke: 2

        // Half the stroke in from the pod's edge, which lands the ring
        // in the middle of that frame — two pixels clear of the artwork
        // it would otherwise sit on, and one clear of the hairline it
        // would double.
        readonly property real radius: width / 2 - 2

        // Clamped, because a live stream reports no length and a player
        // mid-seek can report a position past the end.
        property real sweep: 360 * Math.max(0, Math.min(1, Player.progress))

        opacity: Player.length > 0 && !root.split ? 1 : 0
        visible: opacity > 0.01

        Behavior on opacity { NumberAnimation { duration: Motion.fadeIn } }

        Behavior on sweep {
            // Linear, and a second long — one step per poll, so the
            // arc travels at the speed of the track rather than
            // easing into each new position like an arrival.
            NumberAnimation {
                duration: 1000
                easing.type: Easing.Linear
            }
        }

        Shape {
            anchors.fill: parent
            // The same two reasons BatteryRing keeps: on the GPU path,
            // and not asynchronous, because a ring that resolves a
            // frame late reads as a track that skipped.
            preferredRendererType: Shape.CurveRenderer
            asynchronous: false

            // What is left of the circle the arc has not reached yet.
            ShapePath {
                fillColor: "transparent"
                strokeColor: Qt.rgba(1, 1, 1, 0.14)
                strokeWidth: ring.stroke

                PathAngleArc {
                    centerX: ring.width / 2
                    centerY: ring.height / 2
                    radiusX: ring.radius
                    radiusY: ring.radius
                    startAngle: 0
                    sweepAngle: 360
                }
            }

            ShapePath {
                fillColor: "transparent"
                strokeColor: ring.sweep >= 1 ? Theme.primary : "transparent"
                strokeWidth: ring.stroke
                capStyle: ShapePath.RoundCap

                // From twelve o'clock, clockwise, like every other
                // gauge in the shell.
                PathAngleArc {
                    centerX: ring.width / 2
                    centerY: ring.height / 2
                    radiusX: ring.radius
                    radiusY: ring.radius
                    startAngle: -90
                    sweepAngle: ring.sweep
                }
            }
        }
    }

    // Clicking the cover opens the now-playing card under the row —
    // the track's own picture is the button for the track's own panel,
    // and it is the one press on this shape that does not ask you to
    // aim at a control. Play/pause moved with it: the card is where
    // the transport lives now, at a size where a transport is three
    // buttons rather than one glyph pressed by accident.
    //
    // Declared after `Pod`'s, and at the default z against `Pod`'s `z: -1`,
    // so this is the one that takes the click. The card's own
    // clearing — a pod that empties, or a media pod switched off —
    // lives with `mediaHost` in Island.qml, next to the panel it
    // belongs to.
    MouseArea {
        id: press
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: win.toggleMediaCard()
    }

    // ── Identity ─────────────────────────────────────────────

    // The freedesktop application id, which is what `iconPath` wants and
    // what `MprisPlayer.desktopEntry` is for. The last-segment guess off
    // the display name stays as the fallback; see SplitLobe.qml for why
    // it mangles "Brave Origin" into "origin".
    readonly property string playerClass: {
        if (Player.desktopEntry !== "") return Player.desktopEntry;

        const id = (Player.identity || "").trim();
        if (id === "") return "";
        const parts = id.split(/[.\s]+/).filter(s => s.length > 0);
        return parts.length === 0 ? "" : parts[parts.length - 1].toLowerCase();
    }

    // Whether anything resolved, which is the only way to tell "this
    // player has no art and no icon" from "it is still loading" from a
    // screenshot. Read by the `pods` IPC.
    //
    // The app icon counts. It is the answer for a player that publishes
    // no artwork at all, which is common enough: a browser with nothing
    // playing reports a title and nothing else, and a paused Spotify can
    // sit at `artUrl: (none)` between tracks.
    readonly property bool iconReady:
        cover.ready || appIcon.status === Image.Ready
}
