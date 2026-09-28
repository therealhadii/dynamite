import Quickshell
import Quickshell.Widgets
import QtQuick

import "root:/Services"
import "root:/Widgets"

// The launcher's results, on the shelf below the pill — a surface of
// its own, so the field stays a field and the list is a list.
//
// The shelf is passed in for its radius rather than the pill's: these
// cards are inset from the shelf's corner, and concentricity is
// measured against the corner a shape is actually inside.

Item {
    id: root

    required property var win      // the PanelWindow
    required property var island   // mode flags
    required property var shelf    // the surface this sits on

    anchors.fill: parent

    readonly property bool shown: island.isSearching

    opacity: shown ? 1 : 0
    visible: opacity > 0.01

    Behavior on opacity { ContentFade { revealing: root.shown } }

    ListView {
        id: results
        Component.onCompleted: win.searchList = results

        anchors.fill: parent

        // padCard at the top as well as the bottom now. It used to sit
        // directly under the field's rule inside one panel; on a surface
        // of its own the first card needs the same inset from the top
        // edge that the last one keeps from the bottom, or the list looks
        // like it is falling out of the shelf.
        anchors.topMargin: Theme.padCard

        // The list ends where the cards do, not at the panel floor, so
        // a half-scrolled row leaves the clip before the corner starts
        // curving in past it. Without the margin a square-cornered card
        // gets sliced inside a 36px corner while scrolling.
        //
        // Island.qml adds the same padCard to the panel height, so the
        // sum still comes out at rows x rowHeight exactly.
        anchors.bottomMargin: Theme.padCard

        model: ScriptModel {

            values: Search.results

        }
        clip: true
        currentIndex: 0
        highlightMoveDuration: 110
        highlightRangeMode: ListView.ApplyRange
        preferredHighlightBegin: Config.island.searchRowHeight
        preferredHighlightEnd: height - Config.island.searchRowHeight

        // A selected row is a card inside the panel, not a band across
        // it: a full-bleed highlight gets sliced square by the clip at
        // either end of the list.
        //
        // Not Surface, which is always in one of two states. A list
        // needs a third — an unselected row must be nothing at all, or
        // eight stacked washes read as texture. The alphas are
        // Surface's, moved one rung down.
        delegate: Item {
            id: row

            required property var modelData
            required property int index

            readonly property bool active: index === results.currentIndex

            width: results.width
            height: Config.island.searchRowHeight

            Rectangle {
                id: card
                anchors.fill: parent
                anchors.leftMargin: Theme.padCard
                anchors.rightMargin: Theme.padCard
                // Half the gap each, so two neighbouring cards are
                // spacingSmall apart and the first one clears the rule
                // above it by the same amount.
                anchors.topMargin: Theme.spacingSmall / 2
                anchors.bottomMargin: Theme.spacingSmall / 2

                // Concentric with the panel rather than a token of
                // its own — see Theme.inner. A card twelve pixels
                // inside a corner of 36 is round to 24, and nothing
                // else; radiusLarge said 17 and was wrong by seven
                // pixels at the bottom of every list, which is where
                // the eye checks. It follows the panel as the list
                // grows, because the panel's corner does: one result
                // is a nearly square card under a nearly square
                // corner, eight is a round one under a round one.
                radius: Theme.inner(root.shelf.radius, Theme.padCard)

                color: row.active
                    ? Qt.rgba(1, 1, 1, 0.10)
                    : (tap.containsMouse ? Qt.rgba(1, 1, 1, 0.06) : "transparent")

                // No border on the selected row, which used to carry one
                // at white 0.18. On a black panel a 1px ring inside an
                // already-lighter fill is two edges where one will do,
                // and the ring is what made a list of six read as a stack
                // of cards rather than as a list with a position in it.
                // The fill alone carries the selection, and the fill is
                // what the eye tracks down the column.
                border.width: 0
                border.color: "transparent"

                // Hover says the row is hoverable; only the press says
                // it was hit. Worth having even though the panel is
                // about to close over it — the confirmation lands
                // before the window goes, which is the difference
                // between launching something and hoping you did.
                scale: tap.pressed ? 0.97 : 1

                Behavior on color { ColorAnimation { duration: Motion.fadeIn } }
                Behavior on border.color { ColorAnimation { duration: Motion.fadeIn } }

                Behavior on scale {
                    NumberAnimation {
                        duration: Motion.hover
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: Motion.arrive
                    }
                }

                IconImage {
                    id: rowIcon
                    anchors.left: parent.left
                    anchors.leftMargin: Theme.padRow
                    anchors.verticalCenter: parent.verticalCenter
                    implicitSize: Theme.iconRow
                    source: Quickshell.iconPath(row.modelData.icon,
                                                "application-x-executable")
                }

                Text {
                    anchors.left: rowIcon.right
                    anchors.leftMargin: Theme.gapBadge
                    anchors.right: rowGeneric.left
                    anchors.rightMargin: Theme.spacingSmall
                    anchors.verticalCenter: parent.verticalCenter
                    text: row.modelData.name
                    color: row.active ? Theme.primary : Theme.text
                    font.family: Theme.fontIsland
                    // The body size, not the small one. This is the name
                    // of the thing you are about to launch, it is the
                    // only text in the row that matters, and at 11px in a
                    // 36px row it was a caption under an icon rather than
                    // a list entry. The generic name beside it stays
                    // small, which is what makes the pair a title and a
                    // subtitle.
                    font.pixelSize: Theme.fontSizeNormal
                    font.weight: Config.island.fontWeight
                    elide: Text.ElideRight
                    renderType: Text.NativeRendering

                    Behavior on color { ColorAnimation { duration: Motion.fadeIn } }
                }

                Text {
                    id: rowGeneric
                    anchors.right: parent.right
                    anchors.rightMargin: Theme.padRow
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.min(implicitWidth, 150)
                    horizontalAlignment: Text.AlignRight
                    text: row.modelData.genericName || ""
                    color: Theme.outline
                    font.family: Theme.fontIsland
                    font.pixelSize: Theme.fontSizeCaption
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                    renderType: Text.NativeRendering
                }

                MouseArea {
                    id: tap
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        results.currentIndex = row.index;
                        win.runSelected();
                    }
                }
            }
        }
    }
}
