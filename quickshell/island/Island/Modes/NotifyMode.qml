import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import QtQuick

import "root:/Services"
import "root:/Widgets"

// Transient notification popup. Takes the island over for a few
// seconds, then hands it back.
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

    // How far in the popup holds its contents. Tied to the radius
    // rather than flat, so the inset opens up with the corner it has
    // to clear — otherwise the icon tile and the reply field end up
    // inside the arc at any radius but the one this was measured at.
    // The multiplier keeps today's default landing on today's 16.
    readonly property int inset:
        Math.max(Theme.padCard, Math.round(Config.island.radius * 1.15))

    readonly property bool shown: island.isNotify

    opacity: shown ? 1 : 0
    visible: opacity > 0.01

    Behavior on opacity { ContentFade { revealing: root.shown } }

    readonly property var n: win.notice

    // Clicking the body dismisses, and this is where that lives.
    //
    // Declared FIRST — before the leading slot, the message, the reply
    // field and the action buttons — so it sits at the bottom of the
    // z-order and every control above it takes its own click without any
    // of them having to know this exists. Actions have their own buttons,
    // so the whole popup being one big button on top would make a stray
    // click run whatever the sender put first.
    //
    // It was declared last, on top, and carved itself away with a
    // `bottomMargin` computed from `replyBox.height` plus a hardcoded 32
    // for the action row. That arithmetic is a standing invitation: any
    // later change to either control's height puts the dismiss area under
    // a button, and the button silently stops working. A layering cannot
    // be miscomputed by an edit that does not know it exists.
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: win.dismissNotice()
    }

    // ── The leading slot ────────────────────────────────────
    //
    // It identifies the app, and it is ONE slot rather than an icon plus
    // a name line further down.
    //
    // iOS's island shows a bare app icon and no app name beside it,
    // because the icon already is the app's name. A third line of small
    // grey text under a two-line message is a large part of what made
    // this a 460x104 banner rather than an island. So the name is the
    // FALLBACK: a real icon takes the slot, and where one does not
    // resolve the name does the icon's job. Either way the column beside
    // it is a summary and at most two lines of body.
    readonly property string iconSource: {
        if (!n) return "";
        if (n.image) return n.image;
        if (n.appIcon) return Quickshell.iconPath(n.appIcon, true);
        return "";
    }

    readonly property bool hasIcon: iconSource !== ""
    readonly property string appName: (n && n.appName) ? n.appName : ""

    // 22 when it is an icon, which is the size the launcher's rows use
    // for the same job. A name gets 110 and no more: a long app name
    // should truncate, not eat the message.
    readonly property int leadingWidth: hasIcon
        ? Theme.iconSize
        : (appName !== "" ? Math.min(110, appNameText.implicitWidth)
                          : Theme.iconSize)

    // ── Height ──────────────────────────────────────────────
    //
    // From what is in it, the way the picker's and the notification
    // centre's are.
    //
    // It was `island.notifyHeight`: a flat 104 whatever the notification
    // said, plus two more fixed terms for actions and a reply. So a
    // one-line notification with nothing to act on got the same 104px
    // panel as a three-line one with four buttons. That proportion is a
    // banner, and a banner is the presentation the Dynamic Island
    // replaced.
    //
    // A summary and nothing else is 46px — the iPhone's compact
    // notification — and it grows only as the content does. With no
    // notification at all it is the resting pill, so the shape this
    // collapses into is the one it came from.
    readonly property int contentHeight: {
        if (!n) return Config.island.idleHeight;

        const pad = Theme.padCard * 2;
        const gap = Theme.spacingSmall;

        let h = pad + Math.max(Theme.iconSize, summaryText.implicitHeight);
        if (bodyText.text !== "") h += gap + bodyText.implicitHeight;
        if (canReply) h += Theme.spacingNormal + replyBox.height;
        if (actions.visible) h += Theme.spacingNormal + actions.height;
        return h;
    }

    // Whatever it turned out to be, positioned once, so the column has a
    // single edge to sit against.
    Item {
        id: leading
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        width: root.leadingWidth
        height: Math.max(Theme.iconSize, appNameText.implicitHeight)

        // Bare, with no tile behind it. The `surfaceHigh` card this
        // replaces was 46px of rounded rectangle wrapped around a 16px
        // glyph, and it read as a list row rather than as an app.
        Image {
            id: noticeImg
            visible: root.hasIcon
            width: Theme.iconSize
            height: Theme.iconSize
            source: root.iconSource
            fillMode: root.n && root.n.image
                ? Image.PreserveAspectCrop : Image.PreserveAspectFit
            sourceSize.width: Theme.iconSize
            sourceSize.height: Theme.iconSize
            asynchronous: true
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
        }

        Text {
            id: appNameText
            visible: !root.hasIcon && root.appName !== ""
            // No wrap, so implicitWidth is the natural width and this
            // is not a binding loop.
            width: Math.min(110, implicitWidth)
            text: root.appName
            color: Theme.textDim
            font.family: Theme.fontIsland
            font.pixelSize: Theme.fontSizeCaption
            font.weight: Font.DemiBold
            elide: Text.ElideRight
            renderType: Text.NativeRendering
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
        }

        // The bell, for a notification with neither an icon nor a name.
        // Rarer than it sounds, which is why it is the last resort and
        // not the first — and centred, because it is a glyph and not a
        // box.
        Text {
            anchors.centerIn: parent
            visible: !root.hasIcon && root.appName === ""
            text: Icons.bell
            color: root.n && root.n.critical
                ? Theme.error : Theme.textDim
            font.family: Theme.fontIcons
            font.pixelSize: Theme.iconSize
            renderType: Text.NativeRendering
        }
    }

    // The badge's width, or zero when it is not there.
    //
    // It has to be a number the message column can reserve, not just
    // something parked in the corner. The summary runs the full inner
    // width and starts at the top, which is exactly where the badge
    // sits, so a corner overlay is a collision waiting to happen: it
    // looked fine against a one-line summary and printed "three, 2" over
    // a two-line one. The badge takes its space out of the text instead.
    readonly property int queueWidth:
        (root.n !== null && Notifications.pendingCount > 0)
            ? Math.round(queueLabel.implicitWidth + Theme.spacingSmall * 2)
            : 0

    // How many more are waiting behind this one.
    //
    // Without it the queue is invisible, and an invisible queue reads as
    // a dropped notification: the one on screen goes, another appears,
    // and there is no way to tell whether that is the next one or the
    // last one. A number is the whole difference between "the shell is
    // showing me my messages one at a time" and "something is repeating".
    //
    // A count and not a stack of the next few. The count is the part
    // that answers the question — is there more, and how much — and a
    // stack of previews would be a second notification centre inside a
    // notification, which is the banner this file exists not to be.
    Item {
        anchors.right: parent.right
        anchors.top: parent.top
        width: queueLabel.implicitWidth + Theme.spacingSmall * 2
        height: queueLabel.implicitHeight + 2
        visible: root.n !== null && Notifications.pendingCount > 0

        Rectangle {
            anchors.fill: parent
            radius: height / 2
            color: Qt.rgba(1, 1, 1, 0.10)
        }

        Text {
            id: queueLabel
            anchors.centerIn: parent
            text: Notifications.pendingCount
            color: Theme.textDim
            font.family: Theme.fontIsland
            font.pixelSize: Theme.fontSizeMicro
            font.weight: Font.DemiBold
            renderType: Text.NativeRendering
        }
    }

    // Critical, marked where it can always be seen.
    //
    // It used to be marked by tinting the bell — and the bell is the
    // fallback for a notification with no icon and no app name, so the
    // tint was only ever visible for the notifications least likely to
    // be from an app that bothers to send an icon. A critical alert from
    // a real app, which is most of them, was drawn identically to a
    // chat message. The mark has to be a thing that is there regardless
    // of what the sender supplied, and the bar the notification centre
    // already uses is that thing.
    Rectangle {
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.margins: Theme.padRow
        width: 3
        radius: width / 2
        visible: root.n && root.n.critical
        color: Theme.error
    }

    // The message, and only the message.
    //
    // It used to run to three lines here — summary, body, and the app's
    // name again underneath. The name is in the leading slot now, where
    // it does the icon's job when there is no icon, so this is two lines
    // at most and the island is as tall as they need rather than as tall
    // as the worst case.
    Column {
        id: message
        anchors.left: leading.right
        anchors.leftMargin: Theme.gapBadge
        anchors.right: parent.right
        // The queue badge's space, so the summary's second line cannot
        // run under it. Zero when there is no badge, so this costs
        // nothing in the common case.
        anchors.rightMargin: root.queueWidth > 0
            ? root.queueWidth + Theme.spacingSmall : 0
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.spacingSmall

        Text {
            id: summaryText
            width: parent.width
            text: root.n ? root.n.summary : ""
            color: Theme.text
            font.family: Theme.fontIsland
            font.pixelSize: Theme.fontSizeNormal
            font.weight: Font.DemiBold
            // Two lines, not one. It was a single elided line, which is
            // the wrong trade for the one piece of text a sender
            // controls most: "Meeting moved to 3pm" and "Meeting moved
            // to 3pm — Room 4, bring the projector" are the same
            // notification, and the second is the one you needed. The
            // elide is still there for the genuinely unsummable, just at
            // two lines instead of one.
            wrapMode: Text.WordWrap
            maximumLineCount: 2
            elide: Text.ElideRight
            renderType: Text.NativeRendering
        }

        Text {
            id: bodyText
            width: parent.width
            text: root.n ? root.n.body : ""
            visible: text !== ""
            color: Theme.textDim
            font.family: Theme.fontIsland
            font.pixelSize: Theme.fontSizeSmall
            // Senders send markup whether or not it is advertised;
            // rendering it raw shows the tags.
            textFormat: Text.StyledText
            wrapMode: Text.WordWrap
            maximumLineCount: 2
            elide: Text.ElideRight
            renderType: Text.NativeRendering
        }
    }

    // Inline reply, for clients that advertise one. The field takes
    // the keyboard while it's up, which is why the popup's dismiss
    // timer is held off in Island.qml for as long as it has focus —
    // a reply box that vanishes mid-sentence is worse than no reply
    // box at all.
    Rectangle {
        id: replyBox
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: 30
        // This one *is* in the corner — it spans the full inner width
        // along the bottom, so its two bottom corners sit directly
        // inside the panel's. See Theme.inner: inset from a corner of
        // 22 by 16 leaves 6, and radiusNormal's 14 on a 30px-tall box
        // was very nearly a capsule tucked into a gentle corner.
        radius: Theme.inner(root.pill.radius, root.inset)
        visible: root.canReply

        color: replyField.activeFocus
            ? Qt.rgba(1, 1, 1, 0.10) : Qt.rgba(1, 1, 1, 0.06)
        border.width: 1
        border.color: replyField.activeFocus
            ? Theme.primary : Theme.outlineVariant

        Behavior on color { ColorAnimation { duration: Motion.fadeIn } }
        Behavior on border.color { ColorAnimation { duration: Motion.fadeIn } }

        TextInput {
            id: replyField
            anchors.fill: parent
            anchors.leftMargin: 11
            anchors.rightMargin: sendBtn.width + 16
            verticalAlignment: Text.AlignVCenter
            color: Theme.text
            font.family: Theme.fontIsland
            font.pixelSize: Theme.fontSizeSmall
            clip: true

            Keys.onEscapePressed: win.dismissNotice()
            onAccepted: root.send()

            Text {
                anchors.fill: parent
                verticalAlignment: Text.AlignVCenter
                visible: replyField.text === ""
                text: root.n ? (root.n.replyHint || "Reply") : "Reply"
                color: Theme.outline
                font: replyField.font
                renderType: Text.NativeRendering
            }
        }

        Text {
            id: sendBtn
            anchors.right: parent.right
            anchors.rightMargin: 11
            anchors.verticalCenter: parent.verticalCenter
            text: "Send"
            color: replyField.text === ""
                ? Theme.outline
                : (sendHover.containsMouse ? Theme.primary : Theme.text)
            font.family: Theme.fontIsland
            font.pixelSize: Theme.fontSizeSmall
            font.weight: Font.DemiBold
            renderType: Text.NativeRendering

            Behavior on color { ColorAnimation { duration: Motion.fadeIn } }

            MouseArea {
                id: sendHover
                anchors.fill: parent
                anchors.margins: -6
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.send()
            }
        }

        // Focus the field as soon as the popup carrying it appears,
        // so a reply is one keystroke away rather than a click first.
        Connections {
            target: root
            function onCanReplyChanged() {
                if (root.canReply) {
                    replyField.text = "";
                    replyField.forceActiveFocus();
                }
            }
        }
    }

    readonly property bool canReply:
        !!n && n.hasReply === true && island.isNotify

    // Island.qml holds the dismiss timer while this is true.
    Binding {
        target: win
        property: "replyFocused"
        value: root.canReply && replyField.activeFocus
        restoreMode: Binding.RestoreBindingOrValue
    }

    function send() {
        if (replyField.text.trim() === "") return;
        Notifications.reply(root.n, replyField.text);
        replyField.text = "";
        win.dismissNotice();
    }

    // Click runs the first action if there is one, and
    // dismisses either way — a notification you've
    // acted on shouldn't linger.
    Row {
        id: actions
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.bottomMargin: root.canReply ? replyBox.height + 6 : 0
        spacing: 6
        visible: root.n && root.n.actions.length > 0

        // The first action is the one the sender means, so it is
        // filled rather than merely filling on hover. Which action a
        // popup is for is worth knowing before you have moved the
        // pointer onto one of them.
        Repeater {
            model: root.n ? root.n.actions : []

            Button {
                required property var modelData
                required property int index

                implicitHeight: 26
                padding: Theme.padRow
                text: modelData
                kind: index === 0 ? "primary" : "plain"

                onClicked: {
                    Notifications.invoke(root.n, index);
                    win.dismissNotice();
                }
            }
        }
    }

    // Clicking the body dismisses — see `bodyClick` at the top of this
    // file, which is where that handler lives and why.
}
