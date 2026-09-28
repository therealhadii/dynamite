import QtQuick

import "root:/Services"

// The top of a settings page: one card holding the page's icon, its
// name and one line saying what lives on it.
//
// Every page opens with one, so arriving anywhere in the window lands
// on the same shape — an icon to recognise, a title to confirm, a
// subtitle to say whether this is the page you meant before you have
// scrolled any of it.

Item {
    id: root

    property string glyph: ""
    property string title: ""
    property string subtitle: ""

    implicitWidth: parent ? parent.width : 400
    implicitHeight: 148

    Rectangle {
        anchors.fill: parent
        radius: Theme.radiusLarge
        color: Theme.surfaceLow

        Column {
            anchors.centerIn: parent
            width: parent.width - 48
            spacing: 6

            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                width: 44
                height: 44
                radius: width / 2
                // The accent, washed out to a badge: the glyph reads in
                // full primary against it, and the circle is the same
                // shape the sidebar wears, smaller.
                color: {
                    const c = Qt.color(Theme.primary);
                    return Qt.rgba(c.r, c.g, c.b, 0.14);
                }

                Text {
                    anchors.centerIn: parent
                    text: root.glyph
                    color: Theme.primary
                    font.family: Theme.fontIcons
                    font.pixelSize: 20
                    renderType: Text.NativeRendering
                }
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.title
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeLarge
                font.weight: Font.Bold
                renderType: Text.NativeRendering
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                width: Math.min(parent.width, implicitWidth)
                horizontalAlignment: Text.AlignHCenter
                text: root.subtitle
                visible: root.subtitle !== ""
                color: Theme.textDim
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSmall
                wrapMode: Text.WordWrap
                renderType: Text.NativeRendering
            }
        }
    }
}
