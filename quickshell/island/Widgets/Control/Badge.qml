import QtQuick

import "root:/Services"

// A round glyph, filled when whatever it stands for is on.
//
// This is the piece that makes a row of controls scannable: the state
// is a filled circle you can see from the far side of the screen, and
// the label underneath is there for the detail. It is also the whole
// of a control that has been squeezed down to one cell, which is why
// it knows how to size its own glyph rather than taking one.

Item {
    id: root

    property string glyph: ""
    property bool lit: false
    property color litColor: Theme.primary

    // No disc of its own.
    //
    // At one cell the badge is not a badge any more — there is nothing
    // beside it — and the card it sits in is then the same shape it
    // would have drawn, so the two circles would be one fact drawn
    // twice, the smaller one a hair's width inside the larger. In that
    // case the state is carried by the card lighting up instead, and
    // all this has left to do is set the glyph.
    property bool bare: false

    implicitWidth: 30
    implicitHeight: 30

    Rectangle {
        anchors.fill: parent
        visible: !root.bare
        radius: width / 2
        color: root.lit ? root.litColor : Qt.rgba(1, 1, 1, 0.09)

        Behavior on color { ColorAnimation { duration: Motion.fadeIn } }
    }

    // anchors.centerIn centres a text's LINE BOX rather than its ink,
    // and an icon font's ink sits near the baseline. Widgets/Tile.qml
    // works the offset out from the metrics and explains it at
    // length; the same correction applies here, against the same
    // configurable nudge.
    FontMetrics {
        id: fm
        font: icon.font
    }

    Text {
        id: icon
        anchors.centerIn: parent
        anchors.verticalCenterOffset:
            Math.round((fm.ascent - fm.descent) / 2 - font.pixelSize * 0.36)
            + Config.island.tileIconOffset

        text: root.glyph
        color: root.lit ? Theme.textOnPrimary : Theme.text
        font.family: Theme.fontIcons
        font.pixelSize: Math.round(root.height * 0.46)
        renderType: Text.NativeRendering

        Behavior on color { ColorAnimation { duration: Motion.fadeIn } }
    }
}
