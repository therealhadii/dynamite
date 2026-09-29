import QtQuick
import QtQuick.Shapes

import "root:/Services"

// The control pod, right of the island.
//
// At rest, a network-status circle that opens Control Center. In split
// mode the same surface widens into the playback lobe: Wi-Fi gives way
// to an equalizer, and a click toggles playback.
//
// It used to open into the tray on hover — the click was the control
// centre and the hover was the tray, which sounded like a clean split of
// two gestures over two answers ("let me change something" and "what is
// running"). In practice pointing at the button was enough to widen it,
// so the shape moved sideways out from under the cursor before the press
// landed, and what you got was a row of icons you had not asked for. A
// control you have to aim at twice is not a control.
//
// And a circle is the wrong shape for a list, which is the argument the
// pods have always made about themselves: four icons and a "+n" is a
// bar, and a bar beside a round pill is the one arrangement the island
// does not own. That is why the tray sat behind a hover rather than at
// rest, and why removing the hover removes the tray with it — the two
// were never separable, only dressed up as separate gestures.
//
// In its docked mode this shares MediaPod's one-circle contract. Split
// mode is the deliberate exception: the same pod owns both widths, so
// the surface and its interaction morph instead of being replaced.

Pod {
    id: root

    side: "right"

    // Never absent. It has something to open whether or not anything is
    // running, so "collapses when it has nothing to say" does not apply —
    // a button with no button in it would be a different mistake.
    present: Config.island.showControl

    // The height, so the resting shape is a circle rather than a
    // capsule. `Pod` would clamp a smaller width up to the height
    // anyway; saying so here means the open state is the only thing that
    // ever widens, and there is no longer an open state that widens.
    restWidth: Config.island.idleHeight
    splitWidth: Config.island.splitLobe

    // Equal to `restWidth`, deliberately, for the same reason
    // MediaPod's is: it is the honest way to say "this pod is one size"
    // while living in a base class that has two.
    openWidth: Config.island.idleHeight

    // ── The network glyph ────────────────────────────────────
    //
    // Always on. It used to be the tune glyph — a settings icon, which
    // says where the button goes and nothing about what is true right
    // now. The wifi glyph says the second thing by itself: this is the
    // thing the panel is mostly about, and it is the same question the
    // arc below answers.
    //
    // `Network.icon` rather than a hardcoded wifi glyph: it is the wifi
    // glyph on a wireless link and the wired one on a cable, because
    // the arc is meaningless on a cable and the icon is the part that
    // has to say so.
    //
    // Dim at rest and lit under the pointer. A filled circle with a
    // glyph in it is also what a status light looks like, and what
    // separates the two is that this one answers a hand: it comes up
    // in colour when you point at it and gives way when you press it.

    Item {
        id: face

        anchors.fill: parent
        scale: button.pressed ? 0.88 : 1

        // The press itself: the pod's own circle going pale for as
        // long as the button is down. At rest this is exactly the
        // pod's shape — a pod is clamped square and `Theme.corner`
        // gives it the half-height — so it reads as the face of the
        // button sinking rather than as a second circle arriving.
        Rectangle {
            anchors.fill: parent
            radius: width / 2
            color: Qt.rgba(1, 1, 1, 0.14)
            opacity: button.pressed ? 1 : 0
            visible: opacity > 0.01

            Behavior on opacity { NumberAnimation { duration: Motion.fadeIn } }
        }

        // ── How far it reaches ────────────────────────────────
        //
        // The media pod's gauge with a different quantity in it. Where
        // that arc is a position inside a track, this one is the signal
        // the access point is handing you, out of the same hundred that
        // `nmcli` reports and the control centre's rows are scaled by —
        // so the ring and the Wi-Fi card in the panel are two readings
        // of one number rather than two systems for saying "good".
        //
        // It is the answer the glyph alone cannot give. A wifi icon
        // says you are on wifi; it does not say whether you are at the
        // far end of the house, which is the only wifi question worth
        // answering from across the room, and a percentage would be a
        // number to read rather than a shape to see.
        //
        // The poll behind it only runs while something holds it — see
        // `Network.watchers` — so the pod holds it for as long as it is
        // on screen. A gauge that only moves when the panel happens to
        // be open is a gauge that is wrong most of the time, and the
        // cost is one cached `nmcli` every five seconds with no rescan.

        Text {
            anchors.centerIn: parent

            text: Network.icon
            // Connected reads brighter than not, which is the state
            // when the arc cannot carry it: there is no ring on a
            // cable and none with the radio off, so the glyph is the
            // only thing left saying whether any of it is up.
            color: button.pressed || root.hovered || Network.connected
                   ? Theme.text : Theme.textDim
            font.family: Theme.fontIcons
            font.pixelSize: 19
            font.weight: Config.island.fontWeight
            renderType: Text.NativeRendering
            opacity: root.split ? 0 : 1
            visible: root.split || opacity > 0.01

            Behavior on color { ColorAnimation { duration: Motion.fadeIn } }
            Behavior on opacity { NumberAnimation { duration: Motion.fadeIn } }
        }

        Row {
            anchors.centerIn: parent
            spacing: 2
            opacity: root.split ? 1 : 0
            visible: root.split || opacity > 0.01

            Behavior on opacity { NumberAnimation { duration: Motion.fadeIn } }

            Repeater {
                model: 3

                Rectangle {
                    required property int index

                    width: 2
                    height: 8
                    radius: 1
                    anchors.verticalCenter: parent.verticalCenter
                    color: Player.playing ? Theme.primary : Theme.outline

                    SequentialAnimation on height {
                        running: root.split && Player.playing && root.visible
                        loops: Animation.Infinite

                        PauseAnimation { duration: index * 120 }
                        NumberAnimation {
                            to: 13; duration: 320
                            easing.type: Easing.InOutQuad
                        }
                        NumberAnimation {
                            to: 5; duration: 320
                            easing.type: Easing.InOutQuad
                        }
                    }
                }
            }
        }

        // Short, and quicker on the way down than the hover tier
        // elsewhere: a press is answered, not reported, and a button
        // that takes its time going in is a button you press twice.
        Behavior on scale {
            NumberAnimation {
                duration: Motion.fadeIn
                easing.type: Easing.BezierSpline
                easing.bezierCurve: button.pressed ? Motion.ease : Motion.arrive
            }
        }
    }

    Item {
        id: ring

        anchors.fill: parent

        readonly property real stroke: 2

        // Half the stroke in from the pod's edge, so the arc sits
        // inside the rim rather than doubling the hairline the pod
        // already draws around itself.
        readonly property real radius: width / 2 - 2

        // Only a live wireless link, and only while the radio is on.
        // On a cable the glyph says wired and there is no range to
        // draw; with the radio off there is nothing to measure, and
        // a zero arc there would read as "no signal" rather than as
        // "not asking".
        readonly property bool reaches:
            !root.split && Network.connType === "wifi" && Network.connected
            && Network.wifiEnabled

        property real sweep: 360 * Math.max(
            0, Math.min(1, Network.strength / 100))

        opacity: reaches ? 1 : 0
        visible: opacity > 0.01

        Behavior on opacity { NumberAnimation { duration: Motion.fadeIn } }

        // The number moves in steps, once a poll; the arc should
        // not. A gauge that eases to the next reading reads as a
        // signal drifting, which is what signal does.
        Behavior on sweep {
            NumberAnimation {
                duration: 700
                easing.type: Easing.InOutQuad
            }
        }

        Shape {
            anchors.fill: parent
            // The two reasons BatteryRing and the media pod give:
            // on the GPU path, and not asynchronous, because an arc
            // that resolves a frame late reads as a value that
            // changed its mind.
            preferredRendererType: Shape.CurveRenderer
            asynchronous: false

            // What the arc has not reached.
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

    // The poll the arc reads, held while this pod is on screen.
    //
    // `Network` polls only while something holds it — the control
    // centre and the settings pages both do, and neither is open when
    // you glance at this ring. So the pod holds it too, and lets go
    // when it goes away. One cached `nmcli` every five seconds with no
    // rescan, which is the same cost as having the panel open for a
    // moment, paid by something that is always on screen.
    //
    // A property of this file's own rather than `onPresentChanged`,
    // deliberately: `Pod` already handles that signal — it unpins a pod
    // that has emptied — and a second handler written in the document
    // that instantiates it is not something to count on running
    // alongside the base one, because it may replace it. `netLive`
    // raises a signal only this file can answer, so both handlers
    // exist and neither can shadow the other.
    //
    // The flag is what makes the two entry points safe together: the
    // change handler can fire on its own during construction and
    // `onCompleted` runs after it, and without the guard that is two
    // holds against one release — a poll that never stops.
    readonly property bool netLive: present
    property bool netHeld: false

    function watchNetwork(on) {
        if (on === netHeld) return;
        netHeld = on;
        if (on) Network.hold();
        else Network.release();
    }

    onNetLiveChanged: watchNetwork(netLive)
    Component.onCompleted: watchNetwork(netLive)
    Component.onDestruction: watchNetwork(false)

    // The click opens the control centre. Declared after `Pod`'s own,
    // and at the default z against its `z: -1`, so this is the one that
    // takes the press — `Pod`'s would pin the pod open instead, which
    // for a button is the wrong answer to a click.
    //
    // Unconditional, now that there is no open state to be gated on: a
    // click anywhere on the circle is the press, and it cannot land on
    // something else because there is nothing else in here.
    MouseArea {
        id: button
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            if (root.split) Player.toggle();
            else win.openControl();
        }
    }
}
