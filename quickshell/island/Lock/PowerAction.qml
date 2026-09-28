import QtQuick

import "root:/Services"

// One word at the lock's lower left: Sleep, Restart, Shut Down — the
// three the macOS login window has always put there, and the three
// that answer the question a lock screen is otherwise silent about:
// can I leave this running.
//
// A word rather than a chip. These are the only things on the surface
// that are neither identity nor the way in, so they sit at the edge
// in the muted ink and hold no shape of their own; a row of buttons
// down there would out-shout the field in the middle.
//
// Press once to arm, twice to run. The lock screen is the one surface
// in the shell where the pointer can reach a shutdown without anything
// between it and the prompt, and the arm is what stands there: the
// word says so itself rather than the press having to be remembered,
// and it gives up on its own after five seconds.

Text {
    id: root

    // The Session action to run, and the word that names it.
    required property string action
    required property string label

    // The lock's ink, handed in rather than recomputed: the luminance
    // test that decides it belongs to the surface and not to this
    // file, and every dimmed thing down there is one colour.
    required property color ink

    property bool armed: false

    text: armed ? "Confirm " + label : label

    // The muted-to-full range is the same range the battery line and
    // the hint sit in, so the corner reads as one group of things
    // that are all secondary.
    color: armed ? Theme.error
        : Qt.rgba(ink.r, ink.g, ink.b, hover.containsMouse ? 0.95 : 0.62)

    font.family: Theme.fontFamily
    font.pixelSize: Theme.fontSizeNormal
    font.weight: Font.Medium
    verticalAlignment: Text.AlignVCenter
    height: 22
    renderType: Text.NativeRendering

    Behavior on color { ColorAnimation { duration: Motion.fadeIn } }

    Timer {
        id: disarm
        interval: 5000
        onTriggered: root.armed = false
    }

    // Out past the word on every side: a 13px line is not a target,
    // and a mis-press down here costs a confirmation at worst.
    MouseArea {
        id: hover
        anchors.fill: parent
        anchors.margins: -10

        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor

        onClicked: {
            if (root.armed) {
                disarm.stop();
                root.armed = false;
                Session.run(root.action);
            } else {
                root.armed = true;
                disarm.restart();
            }
        }
    }
}
