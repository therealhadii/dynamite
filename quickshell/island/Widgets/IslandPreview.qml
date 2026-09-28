import QtQuick
import "root:/Services"

// The island and its pods, drawn from the same settings the real ones
// read.
//
// Radius, opacity, padding, font size, pod gap and font weight were all
// sliders with a number beside them and no way to see the result
// without closing settings, looking up, and opening it again. This is
// the same two shapes on the same palette, so the number and the
// thing it controls are in one place.
//
// It sits on a strip of the current wallpaper because the pill's
// opacity only means anything against what is behind it.

Item {
    id: root

    // There used to be an `open` toggle here — click the preview and
    // the pod showed its tray at full size. It is gone with the tray:
    // both pods are one size now, and a preview that opened into
    // something the real pod does not have would be a picture of
    // something else. What is left is one state, which is the whole
    // point of the pods having one.

    implicitWidth: parent ? parent.width : 400
    implicitHeight: 104

    // The resting height, always — which is what the real pill does now
    // that hover is a cross-fade rather than a mode. Kept as a property
    // rather than inlined because the pill and the pod both read it, and
    // a second copy of `Config.island.idleHeight` in here is how the two
    // drifted apart last time.
    readonly property int shapeHeight: Config.island.idleHeight

    function tint(c) {
        const col = Qt.color(c);
        return Qt.rgba(col.r, col.g, col.b, Config.island.opacity);
    }

    // The same answer the shell gives, from the same two settings —
    // see Island/Island.qml's `pill.color`. A preview that quietly
    // disagreed with the thing it is previewing is worse than no
    // preview, and this is the page you reach for precisely when the
    // fill or the edge is not what you expected.
    //
    // At rest, which is the only state there is: the island's own split
    // picks `surfaceLowest` for `idle`, and `Pod.fill` picks the same
    // thing for a pod whatever it is doing.
    readonly property color shapeColor:
        Config.appearance.islandBlack
            ? Theme.islandSurface
            : tint(Theme.surfaceLowest)

    // The real thing's contract, so the preview springs exactly as the
    // island does. See Services/Motion.qml. These are the resting
    // values: with no open state left there is nothing to arrive from,
    // and the tier the island picks for a collapse is the only one this
    // preview can be in.
    readonly property int springResponse: Motion.collapseResponse
    readonly property real springBounce: Motion.departBounce

    Rectangle {
        id: backdrop
        anchors.fill: parent
        radius: Theme.radiusNormal
        color: Theme.surfaceLowest
        clip: true

        Image {
            anchors.fill: parent
            source: Wallpaper.current !== "" ? "file://" + Wallpaper.current : ""
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            // A wide crop of a wallpaper at 104px tall needs nothing
            // like the full decode.
            sourceSize.width: 900
            visible: status === Image.Ready
        }

        // The pill is translucent over whatever is behind it and the
        // compositor blurs that. There is no blur available inside a
        // settings window, so this stands in for it — without some
        // separation the preview reads as far busier than the real
        // thing.
        Rectangle {
            anchors.fill: parent
            color: Qt.rgba(0, 0, 0, 0.35)
        }

        // ── The island ───────────────────────────────────────

        // The real thing's shadow, at the real thing's strength, so
        // the slider on the page this preview sits on actually shows
        // something. A declared setting with nothing drawing it is the
        // bug docs/NOTES.md records as having lived in SliderRow for
        // years.
        //
        // Clipped by the backdrop, which is right — a shadow reaching
        // past the edge of the frame would be the preview's own.
        Shadow { shape: pill; anchors.fill: pill; spread: 10 }

        Rectangle {
            id: pill

            anchors.centerIn: parent

            width: pillWidth.value
            height: pillHeight.value

            Spring {
                id: pillWidth
                shape: root
                minimum: 0
                // The real expression — see Island.qml's
                // `collapsedWidth`. Nothing widens the pill: the resting
                // shape is the clock's own width, and that is the whole
                // of the resting state.
                target: Math.max(Config.island.idleWidth,
                                 contents.width
                                 + Config.island.padding * 2)
            }

            Spring {
                id: pillHeight
                shape: root
                minimum: 0
                target: root.shapeHeight
            }

            radius: Theme.corner(height)
            color: root.shapeColor
            border.width: Theme.islandEdge ? 1 : 0
            border.color: Theme.outlineVariant

            // The pill's, so the preview and the pill agree about
            // what an edge is as well as about what a corner is —
            // including about having neither.
            Bezel {
                outer: parent.radius
                visible: Theme.islandEdge
            }

            // No spring on radius, for the same reason the island
            // has none: the corner is a function of a height that is
            // already on a spring, so it arrives with the shape rather
            // than chasing it on a second clock.
            Behavior on color { ColorAnimation { duration: Motion.fadeIn } }

            // The clock and nothing else, because that is what the
            // resting pill holds — see Island/Modes/IdleMode.qml. The
            // preview drew a date beside this until the pill stopped
            // carrying one, which is what a preview is for: the two
            // have to be the same answer or the page is a picture of
            // something else.
            //
            // The three samples and the fixed width are the clock's own
            // arrangement, copied rather than shared. The real one is a
            // measured slot so the pill does not breathe once a minute;
            // a preview that measured differently from the thing it is
            // previewing would be showing a third width, which is worse
            // than showing the clock's natural one.
            Text {
                id: sample88; visible: false
                anchors.verticalCenter: parent.verticalCenter
                text: "88:88"
                font: contents.font
            }
            Text {
                id: sample00; visible: false
                anchors.verticalCenter: parent.verticalCenter
                text: "00:00"
                font: contents.font
            }
            Text {
                id: sample11; visible: false
                anchors.verticalCenter: parent.verticalCenter
                text: "11:11"
                font: contents.font
            }

            Text {
                id: sample12; visible: false
                anchors.verticalCenter: parent.verticalCenter
                text: "12:41 PM"
                font: contents.font
            }

            Text {
                id: contents
                anchors.verticalCenter: parent.verticalCenter
                // The widest clock reading, and only that: the resting
                // pill is the clock's width, because the faces that need
                // more room are on screen for a moment and take the pill
                // with them only while they are. Same arrangement as
                // IdleMode's `clockSlot`, which this mirrors.
                width: Math.max(sample88.implicitWidth,
                                sample00.implicitWidth,
                                sample11.implicitWidth,
                                sample12.implicitWidth) + 1
                horizontalAlignment: Text.AlignHCenter
                // `Clock.time`, not a format of its own. This preview
                // used to call `Qt.formatDateTime(Clock.now, "HH:mm")` —
                // its own pattern, hardcoded — so the settings page drew
                // a clock in a different format from the island the page
                // is about, and measured itself against a string nothing
                // else in the shell draws.
                text: Clock.time
                color: Theme.primary
                // The island's face, not the window's — see
                // Theme.fontIsland. They are the same by default and
                // stop being the same the moment somebody pins one,
                // which is exactly when a preview that guessed would
                // be lying.
                font.family: Theme.fontIsland
                font.pixelSize: Config.island.fontSize
                font.weight: Config.island.fontWeight
                font.letterSpacing: 1.2
                renderType: Text.NativeRendering
            }
        }

        // ── The control pod ──────────────────────────────────

        Rectangle {
            id: rightPod

            anchors.left: pill.right
            anchors.leftMargin: Config.island.podGap
            anchors.verticalCenter: pill.verticalCenter

            readonly property bool shown: Config.island.showControl

            width: rightPodWidth.value
            height: root.shapeHeight

            // A circle, holding one glyph — the real pod's own line, see
            // ControlPod.qml, which this mirrors. Asking for the height
            // outright is what makes it round, and `Theme.corner` is
            // `h/2` at this height so the corner spends all of it. It
            // never widens: there is no tray behind it to widen into.
            Spring {
                id: rightPodWidth
                shape: root
                minimum: 0
                target: rightPod.shown ? root.shapeHeight : 0
            }
            radius: Theme.corner(height)
            color: root.shapeColor
            border.width: shown && Theme.islandEdge ? 1 : 0
            border.color: Theme.outlineVariant
            opacity: shown ? 1 : 0

            Bezel {
                outer: parent.radius
                visible: Theme.islandEdge
            }
            clip: true

            Behavior on opacity { NumberAnimation { duration: Motion.fadeIn } }

            // The tune glyph. The same one ControlPod draws —
            // `Icons.tabControl`, which is `md-tune` and is also what
            // the settings page calls Control, so the pod and the page
            // it opens are named by the same mark.
            Text {
                anchors.centerIn: parent

                text: Icons.tabControl
                color: Theme.textDim
                font.family: Theme.fontIcons
                font.pixelSize: 19
                font.weight: Config.island.fontWeight
                renderType: Text.NativeRendering
            }
        }
    }

    // No click-to-open here any more. The preview used to toggle the
    // pod between its resting face and the tray, and with one state
    // left there is nothing for a click to say — the widget below was
    // a label reading "click to open" over a preview that would have
    // opened onto nothing.
}
