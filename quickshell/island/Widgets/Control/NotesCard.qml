import QtQuick

import "root:/Services"

// Recent notifications, in the panel.
//
// The island already shows a notification as it arrives and keeps a
// history panel of its own. What was missing was the middle case: you
// were away from the desk for ten minutes, you open the control
// centre, and you want to know whether anything happened. So this is
// deliberately not the history panel — no actions, no replies — it is
// an answer to "did I miss anything", and clicking the card opens the
// place where you can do something about it.
//
// Two things are still offered here, because both are answers to the
// glance rather than decisions taken on it: "Clear all" when the list
// is one you have already read, and a cross on a row you have read and
// want gone. Every row is its own inset card with a round initial on
// the left, which is what makes a column of them scannable — a pip and
// a name do not separate as well as a face does once there are three.
//
// `live` is false in the layout editor, where the cards are drawn but
// inert: there, the cross would clear a real notification you never
// saw.

Item {
    id: root

    signal opened()

    property bool live: true

    Surface {
        anchors.fill: parent
        hovered: hover.containsMouse
    }

    MouseArea {
        id: hover
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.opened()
    }

    Text {
        id: title
        anchors.left: parent.left
        anchors.leftMargin: Theme.padCard
        anchors.top: parent.top
        anchors.topMargin: 10
        text: "Notifications"
        color: Theme.text
        font.family: Theme.fontIsland
        font.pixelSize: Theme.fontSizeSmall
        font.weight: Font.Bold
        font.letterSpacing: 0.4
        renderType: Text.NativeRendering
    }

    Text {
        id: clearAll
        anchors.right: parent.right
        anchors.rightMargin: Theme.padCard
        anchors.verticalCenter: title.verticalCenter
        visible: Notifications.count > 0
        text: "Clear all"
        color: clearTap.containsMouse ? Theme.text : Theme.textDim
        font.family: Theme.fontIsland
        font.pixelSize: Theme.fontSizeCaption
        font.weight: Font.DemiBold
        renderType: Text.NativeRendering

        Behavior on color { ColorAnimation { duration: Motion.fadeIn } }

        // Its own target, small, and declared inside the label rather
        // than beside it: this Text sits over the card's own click,
        // and an area that did not consume the press would clear the
        // list and open the page behind it in one release.
        MouseArea {
            id: clearTap
            anchors.fill: parent
            anchors.margins: -6
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                if (!root.live) return;
                Notifications.clear();
            }
        }
    }

    Text {
        anchors.left: parent.left
        anchors.leftMargin: Theme.padCard
        anchors.top: title.bottom
        anchors.topMargin: 6
        visible: Notifications.count === 0
        text: "Nothing waiting"
        color: Theme.textDim
        font.family: Theme.fontIsland
        font.pixelSize: Theme.fontSizeSmall
        font.weight: Font.DemiBold
        renderType: Text.NativeRendering
    }

    Column {
        id: list
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: Theme.padCard
        anchors.rightMargin: Theme.padCard
        anchors.top: title.bottom
        anchors.topMargin: 6
        spacing: 6
        clip: true

        // However many fit. The card is resizable, so the count is a
        // measurement rather than a constant — and one clipped half-row
        // at the bottom would say "there is more" more honestly than a
        // gap, but it would also be the only clipped thing in the
        // panel.
        //
        // Fifty rather than a bare row height because the row is a
        // card now and cards are separated rather than stacked: 44 of
        // row, 6 of gap.
        readonly property int fits:
            Math.max(0, Math.floor((root.height - 30) / 50))

        Repeater {
            model: Notifications.history.slice(0, list.fits)

            Item {
                required property var modelData
                width: list.width
                height: 44

                // The row's own surface, a shade above the card's. It
                // is what turns a column of lines into a column of
                // things — the reference's list is cards inside the
                // card, and the difference is the only reason the eye
                // can count them without reading.
                Rectangle {
                    anchors.fill: parent
                    radius: 14
                    color: Qt.rgba(1, 1, 1, 0.05)
                }

                // A round initial rather than a pip: the one part of a
                // notification you recognise before you read any of it.
                Rectangle {
                    id: avatar
                    anchors.left: parent.left
                    anchors.leftMargin: 7
                    anchors.verticalCenter: parent.verticalCenter
                    width: 28
                    height: 28
                    radius: width / 2
                    color: {
                        const c = Qt.color(Theme.primary);
                        return Qt.rgba(c.r, c.g, c.b,
                            modelData.critical ? 0.30 : 0.16);
                    }

                    Text {
                        anchors.centerIn: parent
                        text: (modelData.appName || "?").charAt(0)
                              .toUpperCase()
                        color: modelData.critical ? Theme.error
                                                  : Theme.primary
                        font.family: Theme.fontIsland
                        font.pixelSize: 13
                        font.weight: Font.Bold
                        renderType: Text.NativeRendering
                    }
                }

                // Three lines when there are three to give, two when
                // there are not: the app, what it said, and what it was
                // about. The middle one is the only one in bold
                // because it is the only one that is the message.
                Column {
                    anchors.left: avatar.right
                    anchors.leftMargin: 9
                    anchors.right: cross.left
                    anchors.rightMargin: 9
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 1

                    Text {
                        width: parent.width
                        text: modelData.appName || ""
                        color: Theme.textDim
                        font.family: Theme.fontIsland
                        font.pixelSize: Theme.fontSizeCaption
                        font.weight: Font.DemiBold
                        elide: Text.ElideRight
                        renderType: Text.NativeRendering
                    }

                    Text {
                        width: parent.width
                        text: modelData.summary || ""
                        color: Theme.text
                        font.family: Theme.fontIsland
                        font.pixelSize: Theme.fontSizeSmall
                        font.weight: Font.Bold
                        elide: Text.ElideRight
                        renderType: Text.NativeRendering
                    }

                    Text {
                        width: parent.width
                        visible: (modelData.body || "") !== ""
                        text: modelData.body || ""
                        color: Theme.textDim
                        font.family: Theme.fontIsland
                        font.pixelSize: Theme.fontSizeCaption
                        font.weight: Font.DemiBold
                        elide: Text.ElideRight
                        renderType: Text.NativeRendering
                    }
                }

                Text {
                    id: cross
                    anchors.right: parent.right
                    anchors.rightMargin: 9
                    anchors.verticalCenter: parent.verticalCenter
                    text: "×"
                    color: crossTap.containsMouse ? Theme.text
                                                  : Theme.outline
                    font.family: Theme.fontIsland
                    font.pixelSize: 15
                    renderType: Text.NativeRendering

                    Behavior on color { ColorAnimation { duration: Motion.fadeIn } }

                    MouseArea {
                        id: crossTap
                        anchors.fill: parent
                        anchors.margins: -8
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (!root.live) return;
                            Notifications.dismiss(modelData);
                        }
                    }
                }
            }
        }
    }
}
