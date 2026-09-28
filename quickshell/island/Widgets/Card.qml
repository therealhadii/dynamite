import QtQuick

import "root:/Services"

// One rounded panel holding a group of rows, with a hairline between
// each two of them.
//
// The reference settings group their rows this way: a section is one
// surface, and the dividers say where one row ends and the next
// begins, so a page of thirty controls reads as a handful of groups
// rather than thirty separate floats. Rows declare themselves as
// ordinary children and land in the column; the dividers place
// themselves between whatever is in there.
//
// Wrap one section's rows — ChoiceRow, ToggleRow, SliderRow,
// SelectRow — and nothing else: previews, grids, flows and the
// control canvas are surfaces of their own, not rows.

Item {
    id: root

    default property alias content: col.data

    implicitWidth: parent ? parent.width : 400
    implicitHeight: col.implicitHeight + 28

    Rectangle {
        anchors.fill: parent
        radius: Theme.radiusLarge
        color: Theme.surfaceLow
    }

    Column {
        id: col
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.leftMargin: 16
        anchors.rightMargin: 16
        anchors.topMargin: 14
        spacing: 2
    }

    // One divider per gap between children, drawn at the first
    // child's bottom edge. The delegates land on the root, not in
    // the column, so `col.children` holds only the rows. A divider
    // beside a hidden row hides with it — the row still keeps its
    // height in the column, which is the positioner's doing and not
    // this card's to fix.
    Repeater {
        model: Math.max(0, col.children.length - 1)

        Rectangle {
            width: root.width - 32
            x: 16
            height: 1
            color: Qt.rgba(1, 1, 1, 0.06)
            y: col.y + col.children[index].y
                + col.children[index].height + 1
            visible: col.children[index].visible
                && col.children[index + 1].visible
        }
    }
}
