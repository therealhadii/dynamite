import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Effects

import "root:/Services"
import "root:/Widgets"

// The lock surface, one per screen.
//
// Laid out the way macOS lays one out, because that layout is right
// about two things: the clock belongs at the top where it is readable
// from across the room, and everything you have to touch belongs low,
// together, under your hands — a field in the centre of the screen is
// a field you look for.
//
// The middle is left empty on purpose. It is the only part of the
// wallpaper you get to see.
//
// What the corners are for is the other half of that layout, and it is
// the half most lockers leave out. The lower left holds the three
// things you can ask of a machine without knowing its password —
// Sleep, Restart, Shut Down — and the lower right holds the two
// answers it can give back: is it on a network, and how long has it
// got. Neither is a widget and neither is about getting in. They are
// the two questions a black screen can still answer, and they sit at
// the corners because that is where the eye goes when it has finished
// with the middle.
//
// Built out of the island's own material rather than a rectangle: a
// Squircle for the field and the Bezel's two concentric strokes, so
// the one surface the shell shows on a black screen is recognisably
// the same object as the pill.
//
// Still not a place for widgets. The avatar and the one line under the
// field are identity and diagnosis: who this machine thinks you are,
// and why the last password did not work.

WlSessionLock {
    id: lock

    locked: Lock.locked

    WlSessionLockSurface {
        id: surface
        color: Theme.background

        // This screen's wallpaper, which is the shared one unless
        // per-monitor wallpapers are on — the same question
        // Background/WallpaperLayer.qml asks, and the lock is per
        // screen too, so it gets the same answer.
        readonly property string mine:
            Wallpaper.pathFor(surface.screen ? surface.screen.name : "")

        // The lock is the one surface in the shell with no panel
        // behind it, so the palette has to reach it through the scrim
        // rather than through a fill. surfaceLowest is the darkest
        // thing the theme has, which is what a scrim wants.
        readonly property color scrim: Theme.surfaceLowest

        // The same luminance test Theme.text makes, against the scrim
        // instead of the surface. At the opacities this runs at the
        // scrim is most of what you are looking at, so it is the scrim
        // that decides whether white text or dark text survives on top
        // of it — a light palette used to get white on near-white.
        readonly property color ink: {
            const c = Qt.color(surface.scrim);
            const lum = 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b;
            return lum < 0.5 ? "#ffffff" : "#0b0b0d";
        }

        // Ink at some fraction of itself. Every dimmed thing here is
        // the same colour at a lower alpha rather than its own grey, so
        // one palette change moves all of them.
        function wash(a) {
            return Qt.rgba(surface.ink.r, surface.ink.g, surface.ink.b, a);
        }

        // The scrim at some fraction of itself, for the two gradients
        // that darken the top and the bottom edges. The same colour as
        // the flat scrim rather than black, because two different
        // darks over one wallpaper read as two overlays — which is
        // what they are, and what makes the seam between them show.
        function veil(a) {
            const c = Qt.color(surface.scrim);
            return Qt.rgba(c.r, c.g, c.b, a);
        }

        // What the clock casts. The opposite of the ink at a little
        // under full strength: white type wants a shadow and the
        // dark type of a light palette wants the same shape as a
        // halo, since the fault both are guarding against is the
        // same one — display type disappearing into a bright
        // patch of wallpaper.
        readonly property color shade: {
            const c = Qt.color(surface.ink);
            const lum = 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b;
            return lum < 0.5 ? Qt.rgba(0, 0, 0, 0.55)
                             : Qt.rgba(1, 1, 1, 0.45);
        }

        // One line under the field, and the order is the order of use:
        // what is stopping you, then what went wrong, then what you
        // could do instead.
        //
        // Caps Lock outranks the error it almost certainly caused —
        // "Incorrect password" is true and useless when the answer is
        // that the keyboard is shouting.
        readonly property string hint: {
            if (Lock.waiting)
                return "Try again in " + Lock.cooldown + "s";
            if (Lock.busy)
                return "Checking…";
            if (Lock.capsLock)
                return "Caps Lock is on";
            if (Lock.error)
                return Lock.message !== "" ? Lock.message : "Incorrect password";
            if (Lock.fingerprintArmed)
                return "Touch the reader or enter your password";
            return Lock.message;
        }

        readonly property bool hintIsFault:
            Lock.waiting || Lock.error || Lock.capsLock

        Image {
            id: shot
            anchors.fill: parent
            source: surface.mine !== "" ? "file://" + surface.mine : ""
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            sourceSize.width: surface.screen ? surface.screen.width : 0
            sourceSize.height: surface.screen ? surface.screen.height : 0

            // Drawn by the effect below unless there is no blur to
            // apply, in which case there is nothing for the effect to
            // do and the image may as well draw itself.
            visible: status === Image.Ready && Config.lock.blur <= 0
        }

        // Qt's Gaussian rather than Hyprland's dual Kawase, because the
        // compositor cannot blur this: a session lock surface is above
        // everything, and the wallpaper under it is an image we are
        // drawing ourselves. Static, so it costs one frame when the
        // lock engages and nothing after.
        MultiEffect {
            anchors.fill: parent
            source: shot
            visible: shot.status === Image.Ready && Config.lock.blur > 0

            autoPaddingEnabled: false
            blurEnabled: true
            blurMax: 64
            blur: Math.max(0, Math.min(1, Config.lock.blur))
        }

        // The wallpaper is there for recognition, not for looking at.
        Rectangle {
            anchors.fill: parent
            color: surface.scrim
            opacity: Math.max(0, Math.min(1, Config.lock.scrimOpacity))
        }

        // The two gradients the login window lives on. A flat scrim
        // darkens the middle exactly as much as the corners, and the
        // middle is the one part of the wallpaper worth seeing — so
        // the two places type actually sits, above and below, get the
        // extra pass and everything between them is left with the
        // flat dim alone.
        //
        // Static like the blur: two quads that never change and cost
        // nothing after the first frame.
        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            height: Math.round(parent.height * 0.40)

            gradient: Gradient {
                GradientStop { position: 0.00; color: surface.veil(0.50) }
                GradientStop { position: 1.00; color: surface.veil(0.00) }
            }
        }

        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: Math.round(parent.height * 0.42)

            gradient: Gradient {
                GradientStop { position: 0.00; color: surface.veil(0.00) }
                GradientStop { position: 1.00; color: surface.veil(0.60) }
            }
        }

        // Everything above the scrims arrives together, a beat after
        // the surface does. Without it the lock cuts in at full
        // strength, which on an idle timeout is the screen shouting at
        // you.
        //
        // It also holds the way out: `Lock.unlocking` is set the
        // moment a password lands and cleared when Services/Lock.qml
        // releases the session, so this fades and drifts back while
        // there is still a surface to draw it on. The scale is small
        // and outwards because that is the direction the content is
        // going — past the viewer, not away from them — and it is
        // the one gesture here that Reduce Motion takes away along
        // with the fade's travel.
        Item {
            id: content
            anchors.fill: parent

            property bool shown: false
            readonly property bool leaving: Lock.unlocking

            Component.onCompleted: shown = true

            opacity: shown && !leaving ? 1 : 0
            scale: leaving && !Motion.reduced ? 1.06 : 1

            Behavior on opacity {
                NumberAnimation {
                    duration: content.leaving ? 200 : Motion.contentIn
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: content.leaving
                        ? Motion.ease : Motion.reveal
                }
            }

            Behavior on scale {
                NumberAnimation {
                    duration: content.leaving ? 280 : Motion.contentIn
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: content.leaving
                        ? Motion.ease : Motion.reveal
                }
            }

            // ── The clock, high ──────────────────────────────
            //
            // Date above the time, both centred. A fraction of the
            // height rather than a margin, so it sits in the same place
            // on a laptop panel and on a 32-inch monitor.
            //
            // Sized to the type and not to the screen, with a margin
            // all round that is there only so the shadow has room to
            // fall: a MultiEffect draws inside its own item, and the
            // item is the type's box.
            Item {
                id: clockBlock
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top
                anchors.topMargin: Math.round(parent.height * 0.12)

                readonly property int shadowRoom: 64

                width: head.implicitWidth + shadowRoom
                height: head.implicitHeight + shadowRoom

                // A little way in from above, so the first thing the
                // eye meets is the date rather than a corner.
                transform: Translate {
                    y: content.shown || Motion.reduced ? 0 : -16

                    Behavior on y {
                        NumberAnimation {
                            duration: Motion.contentIn
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: Motion.reveal
                        }
                    }
                }

                Column {
                    id: head
                    anchors.centerIn: parent
                    spacing: 2

                    // Drawn by the effect below rather than by
                    // itself, which is the arrangement every
                    // MultiEffect in this file already uses — see the
                    // avatar's photograph underneath. Left visible it
                    // would be composited twice at whatever offset
                    // the effect's texture lands at, and text that is
                    // a pixel out of register is worse than text with
                    // no shadow.
                    visible: false

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: Clock.dateLong
                        color: surface.wash(0.72)
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeTitle
                        font.weight: Font.DemiBold
                        font.letterSpacing: 0.4
                        renderType: Text.NativeRendering
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: Clock.time
                        color: surface.ink
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeClock
                        font.weight: Font.Thin
                        font.letterSpacing: -2
                        renderType: Text.NativeRendering
                    }
                }

                // The cast, which is the reason this block is a box
                // around the type rather than the Column itself: the
                // effect draws inside its own rectangle, and this one
                // is sized to the type plus room for the shadow to
                // fall into.
                //
                // blurMax is left at its default of 32, which caps
                // this cast at about eleven pixels of spread — the
                // distance that lifts display type off a bright patch
                // of wallpaper, and not the distance that turns it
                // into a smudge behind itself.
                MultiEffect {
                    anchors.fill: parent
                    source: head

                    autoPaddingEnabled: false
                    shadowEnabled: true
                    shadowColor: surface.shade
                    shadowBlur: 0.35
                    shadowVerticalOffset: 4
                }
            }

            // ── Who, and the way in — low ────────────────────
            Column {
                id: foot
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: Math.round(parent.height * 0.17)
                spacing: Theme.spacingSmall

                transform: Translate {
                    y: content.shown || Motion.reduced ? 0 : 18

                    Behavior on y {
                        NumberAnimation {
                            duration: Motion.contentIn
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: Motion.reveal
                        }
                    }
                }

                // The avatar. A circle because a face is a circle
                // everywhere else on this machine — the one shape in
                // the shell that is not the island's, and deliberately
                // so: it is a photograph, not a surface.
                Item {
                    id: face
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 96
                    height: 96

                    Image {
                        id: faceImg
                        anchors.fill: parent
                        source: User.avatar !== "" ? "file://" + User.avatar : ""
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        sourceSize.width: 192
                        sourceSize.height: 192
                        visible: false
                    }

                    Item {
                        id: faceMask
                        anchors.fill: parent
                        layer.enabled: true
                        visible: false

                        Rectangle {
                            anchors.fill: parent
                            radius: width / 2
                        }
                    }

                    MultiEffect {
                        anchors.fill: parent
                        source: faceImg
                        visible: faceImg.status === Image.Ready
                        maskEnabled: true
                        maskSource: faceMask
                    }

                    // No picture set, which is the common case on a
                    // machine that was never through a desktop's
                    // first-run wizard. Initials rather than a stock
                    // silhouette: it is at least about you.
                    Rectangle {
                        anchors.fill: parent
                        radius: width / 2
                        visible: faceImg.status !== Image.Ready
                        color: surface.wash(0.12)
                        border.width: 1
                        border.color: surface.wash(0.22)

                        Text {
                            anchors.centerIn: parent
                            text: User.initials
                            color: surface.wash(0.8)
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeTitle
                            font.weight: Font.Light
                            font.letterSpacing: 1
                            renderType: Text.NativeRendering
                        }
                    }
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: User.name
                    color: surface.ink
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeLarge
                    font.weight: Font.DemiBold
                    renderType: Text.NativeRendering
                    topPadding: 4
                    bottomPadding: 10
                }

                // The field. A capsule because that is what the shape
                // is rather than what it was set to — see DESIGN.md on
                // the fourth case that is deliberately not a token —
                // and a Squircle because every other edge in the shell
                // is a superellipse and one arc among them shows.
                Item {
                    id: field
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 288
                    height: 42

                    readonly property real corner: height / 2

                    // A wrong password says so in words underneath. The
                    // shake is for the case where the words are not
                    // where you are looking, which on a lock screen is
                    // most of the time — you are watching what you type.
                    transform: Translate { id: nudge }

                    SequentialAnimation {
                        id: shake
                        NumberAnimation { target: nudge; property: "x"; to:  9; duration: 45 }
                        NumberAnimation { target: nudge; property: "x"; to: -7; duration: 60 }
                        NumberAnimation { target: nudge; property: "x"; to:  5; duration: 60 }
                        NumberAnimation { target: nudge; property: "x"; to:  0; duration: 55 }
                    }

                    Connections {
                        target: Lock
                        function onErrorChanged() {
                            if (Lock.error && !Motion.reduced) shake.restart();
                        }
                    }

                    Squircle {
                        anchors.fill: parent
                        radius: field.corner
                        smoothing: Config.appearance.cornerSmoothing
                        color: surface.wash(0.14)
                        borderWidth: 1
                        borderColor: Lock.error
                            ? Theme.error
                            : (input.activeFocus ? surface.wash(0.42)
                                                 : surface.wash(0.18))

                        Behavior on borderColor {
                            ColorAnimation { duration: Motion.fadeIn }
                        }
                    }

                    Bezel { outer: field.corner }

                    TextInput {
                        id: input
                        anchors.fill: parent

                        // Both margins clear the trailing slot, not
                        // just the one beside it: an inset on one side
                        // only would move the centre by half a glyph
                        // every time Caps Lock came on, and the slot
                        // grows its own contents whenever there is
                        // something to submit.
                        anchors.leftMargin: 14 + trailing.width
                        anchors.rightMargin: 14 + trailing.width

                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter

                        echoMode: TextInput.Password

                        // U+25CF, not the U+2022 bullet this started
                        // as. A bullet is punctuation, sized to sit in
                        // a line of prose, and at the size prose is set
                        // to it reads as grit in the field rather than
                        // as characters you typed. The black circle is
                        // a glyph whose whole job is to be a dot, so it
                        // fills the line it is on.
                        passwordCharacter: "●"

                        color: surface.ink
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeLarge

                        // The dots are round and identical, so nothing
                        // in their shape says where one ends. The gap
                        // has to.
                        font.letterSpacing: 3
                        renderType: Text.NativeRendering
                        enabled: !Lock.busy && !Lock.waiting && !Lock.unlocking
                        clip: true

                        text: Lock.entry
                        onTextChanged: Lock.entry = text
                        onAccepted: Lock.submit()

                        // The surface is created when the lock engages,
                        // so focus has to be taken then rather than at
                        // load.
                        Component.onCompleted: forceActiveFocus()

                        // Losing focus to the wait would leave the
                        // field dead after the count reached zero.
                        onEnabledChanged: if (enabled) forceActiveFocus()

                        Connections {
                            target: Lock
                            function onEntryChanged() {
                                if (input.text !== Lock.entry) input.text = Lock.entry;
                            }
                        }

                        Text {
                            anchors.fill: parent
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                            visible: input.text === "" && !Lock.busy
                            text: "Enter Password"
                            color: surface.wash(0.38)
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeNormal
                            renderType: Text.NativeRendering
                        }
                    }

                    // The right end of the field says one thing at a
                    // time, in this order: the keyboard is shouting,
                    // there is a reader listening, there is something
                    // to submit, or a password is being checked.
                    //
                    // The submit circle owns its own twenty-eight
                    // pixels whether it is showing or not. It fades
                    // rather than arriving, because a slot that grows
                    // when the first dot does shifts the dots with it —
                    // and the one moment the text must not move is the
                    // moment somebody is reading it back.
                    Item {
                        id: trailing
                        anchors.right: parent.right
                        anchors.rightMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        height: 28
                        width: indicator.width + slot.width

                        Item {
                            id: indicator
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            width: glyph.text !== "" ? glyph.implicitWidth : 0
                            height: parent.height

                            Text {
                                id: glyph
                                anchors.centerIn: parent
                                text: Lock.capsLock ? Icons.capsLock
                                    : (Lock.fingerprintArmed ? Icons.fingerprint : "")
                                color: Lock.capsLock ? Theme.error : Theme.primary
                                font.family: Theme.fontIcons
                                font.pixelSize: Theme.fontSizeNormal
                                renderType: Text.NativeRendering

                                // A reader gives no sign that it is
                                // listening, so the glyph has to. Slow
                                // enough to read as waiting rather than
                                // as something needing an answer.
                                SequentialAnimation on opacity {
                                    running: Lock.fingerprintArmed && !Lock.capsLock
                                        && !Motion.reduced
                                    loops: Animation.Infinite
                                    NumberAnimation { to: 1.0;  duration: 900; easing.type: Easing.InOutSine }
                                    NumberAnimation { to: 0.40; duration: 900; easing.type: Easing.InOutSine }
                                }
                            }
                        }

                        Item {
                            id: slot
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            width: 28
                            height: 28

                            readonly property bool armed:
                                input.text !== "" && !Lock.busy && !Lock.waiting

                            Rectangle {
                                anchors.fill: parent
                                radius: width / 2
                                color: surface.wash(0.18)
                                border.width: 1
                                border.color: surface.wash(0.30)
                                opacity: slot.armed ? 1 : 0

                                Behavior on opacity {
                                    NumberAnimation {
                                        duration: slot.armed ? Motion.fadeIn
                                                             : Motion.fadeOut
                                    }
                                }
                            }

                            Text {
                                anchors.centerIn: parent
                                text: "❯"
                                color: surface.ink
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSizeNormal
                                font.weight: Font.DemiBold
                                renderType: Text.NativeRendering
                                opacity: slot.armed ? 1 : 0

                                Behavior on opacity {
                                    NumberAnimation {
                                        duration: slot.armed ? Motion.fadeIn
                                                             : Motion.fadeOut
                                    }
                                }
                            }

                            // While the password is being checked the
                            // circle gives way to the one mark every
                            // login screen has agreed on since the
                            // first one: a light going round. The
                            // spokes do not move — only the lit part
                            // of them does, which is what makes it
                            // read as waiting rather than as a wheel
                            // about to start turning.
                            Item {
                                id: spinner
                                anchors.centerIn: parent
                                width: 20
                                height: 20
                                visible: Lock.busy && !Motion.reduced

                                property real sweep: 0

                                NumberAnimation on sweep {
                                    from: 0
                                    to: 360
                                    duration: 900
                                    loops: Animation.Infinite
                                    running: spinner.visible
                                }

                                Repeater {
                                    model: 8

                                    delegate: Rectangle {
                                        required property int index

                                        width: 2
                                        height: 6
                                        radius: 1
                                        x: (spinner.width - width) / 2
                                        y: 0
                                        color: surface.ink

                                        // Brightest where the sweep
                                        // is, falling away behind it
                                        // — so the gap between spokes
                                        // travels rather than the
                                        // spokes themselves.
                                        opacity: 0.22 + 0.78 * (0.5 + 0.5 * Math.cos(
                                            (index * 45 - spinner.sweep)
                                            * Math.PI / 180))

                                        transform: Rotation {
                                            origin.x: width / 2
                                            origin.y: spinner.height / 2
                                            angle: index * 45
                                        }
                                    }
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                enabled: slot.armed
                                cursorShape: Qt.PointingHandCursor
                                onClicked: Lock.submit()
                            }
                        }
                    }
                }

                // One line, one height, whatever it is saying. A status
                // that changes the height of the column moves the field
                // you are typing into.
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    height: 18
                    text: surface.hint
                    color: surface.hintIsFault ? Theme.error : surface.wash(0.55)
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSmall
                    renderType: Text.NativeRendering
                    topPadding: 4
                }
            }

            // ── What needs no password ───────────────────────
            //
            // Lower left, which is where the login window has always
            // put them. A word each, at the muted ink, sized off the
            // screen's own edge rather than off the column above —
            // they belong to the corner and not to the group in the
            // middle, and the gap between the two is what keeps the
            // arrangement from reading as one tall column of things.
            Row {
                anchors.left: parent.left
                anchors.bottom: parent.bottom
                anchors.leftMargin: 34
                anchors.bottomMargin: 32
                spacing: 26
                visible: Config.lock.showActions

                PowerAction { action: "suspend";  label: "Sleep";     ink: surface.ink }
                PowerAction { action: "reboot";   label: "Restart";   ink: surface.ink }
                PowerAction { action: "shutdown"; label: "Shut Down"; ink: surface.ink }
            }

            // ── What the machine has to say back ──────────────
            //
            // Lower right, the other corner, and the same muted ink:
            // two glyphs and a number that answer "will it last" and
            // "is it still on the network" without a password and
            // without a panel to open.
            Row {
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.rightMargin: 34
                anchors.bottomMargin: 32
                spacing: 16

                readonly property bool net:
                    Config.lock.showNetwork
                    && (Network.connType === "wifi"
                        || Network.connType === "ethernet")
                readonly property bool batt:
                    Config.lock.showBattery && Battery.present

                visible: net || batt

                Text {
                    visible: parent.net
                    height: 22
                    text: Network.icon
                    color: surface.wash(0.62)
                    font.family: Theme.fontIcons
                    font.pixelSize: Theme.fontSizeNormal
                    verticalAlignment: Text.AlignVCenter
                    renderType: Text.NativeRendering
                }

                Text {
                    visible: parent.batt
                    height: 22
                    text: Battery.icon + "  " + Battery.level + "%"
                    color: surface.wash(0.62)
                    font.family: Theme.fontIcons
                    font.pixelSize: Theme.fontSizeSmall
                    verticalAlignment: Text.AlignVCenter
                    renderType: Text.NativeRendering
                }
            }
        }
    }
}
