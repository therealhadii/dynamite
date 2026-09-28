import QtQuick
import "root:/Services"

// A small heading that separates groups of rows.

Item {
    id: root

    // Rows worth a glance, and rows worth a visit. Most of what a
    // settings page holds is a number you set once, and thirty of
    // them in a column is a page nobody reads — so a row can mark
    // itself `advanced` and the window hides it until the switch in
    // its corner is on. `shown` is the row's own condition, kept
    // apart so that setting one does not quietly cancel the other.
    property bool advanced: false
    property bool shown: true

    visible: shown && (!advanced || Config.ui.advanced)
    property string text: ""

    // Name of the Config section this header covers. Set it and a
    // reset control appears; leave it empty for a plain heading.
    property string section: ""

    implicitWidth: parent ? parent.width : 400
    implicitHeight: 32

    Text {
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 6
        text: root.text
        // Dim and sentence-case, with no rule underneath: a header is
        // a signpost you scan past, and the old primary caps with a
        // hairline made every group shout before any row had spoken.
        color: Theme.textDim
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSizeSmall
        font.weight: Font.DemiBold
        font.letterSpacing: 0.6
        renderType: Text.NativeRendering
    }

    Text {
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 5

        visible: root.section !== ""
        text: confirming ? "Sure?" : "Reset"
        color: confirming ? Theme.error
            : (resetHover.containsMouse ? Theme.text : Theme.outline)
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSizeCaption
        font.weight: Font.DemiBold
        renderType: Text.NativeRendering

        // Two presses, because a reset is not undoable and the button
        // sits next to controls people are already clicking.
        property bool confirming: false

        Behavior on color { ColorAnimation { duration: 120 } }

        Timer {
            id: armed
            interval: 2500
            onTriggered: parent.confirming = false
        }

        MouseArea {
            id: resetHover
            anchors.fill: parent
            anchors.margins: -8
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor

            onClicked: {
                if (!parent.confirming) {
                    parent.confirming = true;
                    armed.restart();
                    return;
                }
                parent.confirming = false;
                armed.stop();
                Config.resetSection(root.section);
            }
        }
    }
}
