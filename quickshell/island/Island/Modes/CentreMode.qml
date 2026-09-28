import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import QtQuick

import "root:/Services"
import "root:/Widgets"

// Notification history, with per-item dismiss and clear all.
//
// QML ids do not resolve across files, so the surfaces this needs are
// passed in rather than looked up.

Item {
    id: root

    required property var win      // the PanelWindow
    required property var island   // mode flags and media state
    required property var pill     // the shape, for geometry gates
    anchors.fill: parent
    anchors.margins: inset

    // The popup's number, for the same reason — see NotifyMode. The
    // centre is the taller of the two and so has the rounder corner,
    // which makes it the one where a constant inset shows first.
    readonly property int inset:
        Math.max(Theme.padCard, Math.round(Config.island.radius * 1.15))

    readonly property bool shown: island.isCentre

    // "now", "4m", "3h", "2d" — and nothing beyond that.
    //
    // The centre is a list you scroll, not an archive you audit, so the
    // question a time answers is "is this from just now or from this
    // morning", and a coarse bucket answers it. A clock time would be
    // more precise and less useful: "14:32" on a row you have not looked
    // at yet says less about whether it matters than "4m" does.
    //
    // `tick` is bumped by a timer so these labels can be re-evaluated,
    // because a row's text is fixed the moment it is built and "now"
    // would otherwise still say "now" an hour later. It is read HERE, in
    // the function, rather than appended to the text at the call site:
    // a binding only re-evaluates when a property it read changes, and
    // `root.ago(t) + root.tick` reads it too — it also puts the number
    // in the string, which is how the labels came to read "now1".
    // ScriptModel compares on `id`, so bumping this re-evaluates the
    // bindings without rebuilding the list.
    property int tick: 0

    function ago(t) {
        if (!t) return "";
        const _ = root.tick;   // the dependency; deliberately unused
        const s = Math.floor((Date.now() - t) / 1000);
        if (s < 45) return "now";
        const m = Math.floor(s / 60);
        if (m < 60) return m + "m";
        const h = Math.floor(m / 60);
        if (h < 24) return h + "h";
        return Math.floor(h / 24) + "d";
    }

    Timer {
        interval: 30000
        running: root.shown
        repeat: true
        onTriggered: root.tick = root.tick + 1
    }

    // Island.qml sizes the centre from these rather than from a stored
    // height, which could only ever disagree with what is in the panel
    // — a notification list is empty most of the time.
    //
    // The three metrics are the layout's, declared here so the
    // arithmetic and the anchors cannot drift apart.
    readonly property int headerHeight: 30
    readonly property int headerGap: 8
    readonly property int rowGap: 6

    // Room for "Nothing to catch up on" and the air it needs. Empty is
    // a state worth showing properly rather than a state to be sized
    // out of existence — a centre that collapsed to its header would
    // read as broken rather than as quiet.
    readonly property int emptyHeight: 80

    readonly property int contentHeight: {
        const n = Notifications.count;
        const body = n === 0
            ? emptyHeight
            : n * Config.island.centreRowHeight + (n - 1) * rowGap;
        // centreHeight is the ceiling, not the height: past it the
        // list scrolls, which is what a list is for.
        return Math.min(Config.island.centreHeight,
                        inset * 2 + headerHeight + headerGap + body);
    }

    opacity: shown ? 1 : 0
    visible: opacity > 0.01

    Behavior on opacity { ContentFade { revealing: root.shown } }

    Item {
        id: centreHeader
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: root.headerHeight

        Text {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: Notifications.count > 0
                ? Notifications.count + (Notifications.count === 1
                    ? " notification" : " notifications")
                : "Notifications"
            color: Theme.primary
            font.family: Theme.fontIsland
            font.pixelSize: Theme.fontSizeNormal
            font.weight: Font.Bold
            font.letterSpacing: 1.2
            renderType: Text.NativeRendering
        }

        Button {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            visible: Notifications.count > 0
            implicitHeight: 24
            text: "Clear"
            onClicked: Notifications.clear()
        }

        Rectangle {
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            height: 1
            color: Theme.outlineVariant
        }
    }

    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: centreHeader.bottom
        anchors.topMargin: root.headerGap
            + (root.emptyHeight - implicitHeight) / 2
        visible: Notifications.count === 0
        text: "Nothing to catch up on"
        color: Theme.outline
        font.family: Theme.fontIsland
        font.pixelSize: Theme.fontSizeSmall
        font.weight: Font.DemiBold
        renderType: Text.NativeRendering
    }

    ListView {
        id: centreList
        anchors.top: centreHeader.bottom
        anchors.topMargin: root.headerGap
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        clip: true
        spacing: root.rowGap
        model: ScriptModel {
            // Notifications are plain objects rebuilt on every change,
            // so identity comparison would see them all as new. The id
            // is what actually distinguishes them.
            objectProp: "id"
            values: Notifications.history
        }
        delegate: Rectangle {
            required property var modelData

            width: centreList.width
            height: Config.island.centreRowHeight
            // Concentric with the panel — see Theme.inner. These rows
            // run the full inner width and the list reaches the
            // bottom, so the first and last of them sit in the panel's
            // corners; a 440px panel is round to 40 and an inset of 16
            // leaves 24. radiusLarge said 17, and seven pixels of
            // disagreement read as two panels rather than one.
            radius: Theme.inner(root.pill.radius, root.inset)
            color: rowHover.containsMouse
                ? Qt.rgba(1, 1, 1, 0.07) : Qt.rgba(1, 1, 1, 0.04)

            Behavior on color { ColorAnimation { duration: Motion.fadeIn } }

            // Critical keeps a mark in history, not
            // just in the popup that already went by.
            Rectangle {
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                anchors.margins: Theme.padRow
                width: 3
                radius: width / 2
                visible: modelData.critical
                color: Theme.error
            }

            Rectangle {
                id: rowIconBox
                anchors.left: parent.left
                anchors.leftMargin: 18
                anchors.verticalCenter: parent.verticalCenter
                width: 38
                height: 38
                // The popup's tile, same ratio — see NotifyMode.
                radius: width * 0.225
                color: Theme.surfaceHigh
                clip: true

                Image {
                    id: rowImg
                    anchors.fill: parent
                    anchors.margins: modelData.image ? 0 : 9
                    source: modelData.image
                        ? modelData.image
                        : (modelData.appIcon
                           ? Quickshell.iconPath(modelData.appIcon, true) : "")
                    fillMode: modelData.image
                        ? Image.PreserveAspectCrop : Image.PreserveAspectFit
                    asynchronous: true
                    visible: status === Image.Ready
                }

                Text {
                    anchors.centerIn: parent
                    visible: !rowImg.visible
                    text: Icons.bell
                    color: Theme.outline
                    font.family: Theme.fontIcons
                    font.pixelSize: Theme.iconSize
                    font.weight: Font.DemiBold
                    renderType: Text.NativeRendering
                }
            }

            Column {
                anchors.left: rowIconBox.right
                anchors.leftMargin: 12
                anchors.right: rowDismiss.left
                anchors.rightMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2

                Text {
                    width: parent.width
                    text: modelData.summary
                    color: Theme.text
                    font.family: Theme.fontIsland
                    font.pixelSize: Theme.fontSizeSmall
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                    renderType: Text.NativeRendering
                }

                Text {
                    width: parent.width
                    text: modelData.body
                    visible: text !== ""
                    color: Theme.textDim
                    font.family: Theme.fontIsland
                    font.pixelSize: Theme.fontSizeCaption
                    font.weight: Font.DemiBold
                    textFormat: Text.StyledText
                    wrapMode: Text.WordWrap
                    maximumLineCount: 2
                    elide: Text.ElideRight
                    renderType: Text.NativeRendering
                }

                // The bottom line: who it was from, and when.
                //
                // The time was on the entry the whole time and drawn
                // nowhere. It is the other half of what a notification
                // list is for — "what did I miss" is a question about
                // time as much as about app — and it was the cheapest
                // thing in the file to add, which is a poor excuse for
                // having not added it.
                Item {
                    width: parent.width
                    height: Math.max(appLabel.implicitHeight,
                                     metaRow.implicitHeight)

                    Text {
                        id: appLabel
                        anchors.left: parent.left
                        anchors.right: metaRow.left
                        anchors.rightMargin: Theme.spacingSmall
                        anchors.verticalCenter: parent.verticalCenter
                        text: modelData.appName
                        color: Theme.outline
                        font.family: Theme.fontIsland
                        font.pixelSize: Theme.fontSizeMicro
                        font.weight: Font.DemiBold
                        elide: Text.ElideRight
                        renderType: Text.NativeRendering
                    }

                    // The unread dot and the time, together and
                    // right-aligned, so neither can land on the other.
                    //
                    // The dot was first put at the row's left edge,
                    // which is where the critical bar already is — so on
                    // a critical notification the two marks were drawn on
                    // top of each other and the one underneath was
                    // invisible. Sharing a right-aligned cluster with
                    // the time gives the dot a place of its own that is
                    // defined by the content beside it rather than by a
                    // coordinate two features have to agree on.
                    Row {
                        id: metaRow
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Theme.spacingSmall

                        // Unread. `unread` was a count the shell kept
                        // and nothing ever showed, so "3 notifications"
                        // and "3 unread" were the same screen.
                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 6
                            height: 6
                            radius: width / 2
                            visible: Notifications.isUnread(modelData)
                            color: Theme.primary
                        }

                        Text {
                            id: timeLabel
                            anchors.verticalCenter: parent.verticalCenter
                            text: root.ago(modelData.time)
                            color: Theme.outline
                            font.family: Theme.fontIsland
                            font.pixelSize: Theme.fontSizeMicro
                            font.weight: Font.DemiBold
                            renderType: Text.NativeRendering
                        }
                    }
                }
            }

            Text {
                id: rowDismiss
                anchors.right: parent.right
                anchors.rightMargin: 14
                anchors.verticalCenter: parent.verticalCenter
                text: "\u00d7"
                color: dismissHover.containsMouse
                    ? Theme.text : Theme.outline
                font.family: Theme.fontIsland
                font.pixelSize: Theme.iconSize
                font.weight: Config.island.fontWeight
                renderType: Text.NativeRendering

                MouseArea {
                    id: dismissHover
                    anchors.fill: parent
                    anchors.margins: -8
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Notifications.dismiss(modelData)
                }
            }

            MouseArea {
                id: rowHover
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: modelData.actions.length > 0
                    ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: {
                    if (modelData.actions.length > 0)
                        Notifications.invoke(modelData, 0);
                    Notifications.dismiss(modelData);
                }
            }
        }
    }

    Item {
        anchors.fill: parent
        focus: island.isCentre
        Keys.onEscapePressed: win.closeCentre()
    }
}
