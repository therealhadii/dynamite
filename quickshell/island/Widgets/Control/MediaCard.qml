import Quickshell.Widgets
import QtQuick

import "root:/Services"

// Now playing, as a card: art on the left, what it is on the right.
//
// Album art is whatever colour the label chose and the shell is
// whatever colour the wallpaper is, so the art gets a wash of the
// accent to bring it into the theme. `island.artTint` is that dial.
//
// The art is a thumbnail rather than the card's background, which is
// the change this file exists to make. As a background it fought the
// text for every pixel: the scrim has to be heavy enough to make a
// photograph readable under a title, and heavy enough for that is
// heavy enough to have thrown the photograph away. As a square beside
// the words it is the one thing on the card nobody has to read — the
// cover names the track from the corner of your eye, and the words
// are there for when it does not.
//
// What the right-hand column carries is measured from the cell it is
// in, because this card is a grid cell and the grid is the user's to
// arrange: at two rows it holds the title, a scrubber and the
// transport; at three it adds the artist, the album and the two
// stamps. Nothing is elided away by a fixed design the cell cannot
// hold. `inPanel` is the one layout choice that is not the cell's to
// make: it gives the column the gutter the cover has and the source a
// row of its own, and it belongs to the card whose cell is a panel
// rather than a grid.

Item {
    id: root

    // See ConnRow: the words are optional, per control. With them off
    // the card is the artwork and the transport, which at two cells is
    // a better-looking thing than a title elided to five characters.
    property bool showText: true

    // Laid out for a panel rather than for a grid cell — which is a
    // different object, not a bigger one, and the differences are all
    // of a piece: a card you are *reading* for a minute rather than a
    // card that has to fit where the grid put it.
    //
    //   - the frame goes, because the panel behind it is the surface
    //     and a card on a tray on a panel is three edges for one
    //     object. The words sit on the glass directly.
    //   - the album and the source take a row each instead of sharing
    //     one, and the column of words gets the top gutter the cover
    //     already has — so the title starts level with the artwork
    //     instead of a row above it, which is what a cell with
    //     `padCard` below it and none above looks like.
    //   - the cover is let through at full strength with half the
    //     wash. In a cell the wash is what keeps a photograph from
    //     arguing with words printed over it; beside the words there
    //     are none, and at this size a washed cover is the one thing
    //     on the card nobody can read.
    //
    // Off for the grid, and not only for its sake: `dense` is 112
    // because 48 of metadata and 64 of scrubber is 112, and a gutter
    // on top of that is content a cell the height it already is
    // cannot hold.
    property bool inPanel: false

    // Roomy enough for the artist line and the transport together.
    readonly property bool tall: height >= 70
    readonly property bool roomy: width >= 150
    // The rows that only fit a comfortable cell: the album and source
    // under the artist, and the two stamps under the scrubber.
    readonly property bool dense: height >= 112
    readonly property bool timed: height >= 92

    signal opened()

    // Seconds to a stamp somebody reads rather than a number they do
    // arithmetic on: "2:06" and "-2:58", not 126 and 178.
    function stamp(sec) {
        if (!isFinite(sec) || sec < 0) sec = 0;
        const s = Math.floor(sec);
        return Math.floor(s / 60) + ":" + String(s % 60).padStart(2, "0");
    }

    // The card's own surface, and in a cell it is all there is. In a
    // panel it is nothing: the host behind it is the surface, and a
    // second one would put a box inside a box with a hairline round
    // each. See `inPanel`.
    ClippingRectangle {
        id: frame
        anchors.fill: parent
        radius: Theme.radiusLarge
        color: root.inPanel ? "transparent" : Theme.surfaceHigh
    }

    // Outside the clip. A 1px stroke drawn inside a rounded clip loses
    // its outer half to the clip and reads as a half-pixel smudge that
    // varies around the curve.
    //
    // Nothing to stroke in a panel: the edge there belongs to the
    // host, and this one a pixel inside it is the second border the
    // panel card does without.
    Rectangle {
        anchors.fill: parent
        color: "transparent"
        radius: frame.radius
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.10)
        visible: !root.inPanel
    }

    // The cover, as a square beside the words — or as the whole card
    // when there are no words to stand beside.
    ClippingRectangle {
        id: artBox
        // `padCard` in a panel, so the cover's own corner is the same
        // number as its inset from the edge — one radius governs how
        // far in it sits and how round it is, and it comes out
        // concentric with the panel's. `Theme.corner(width)` is the
        // cell's answer and is far too round for it there: a cover
        // that soft reads as a lozenge beside a title.
        radius: root.inPanel ? Theme.padCard
             : root.showText ? Theme.corner(width) : frame.radius
        color: Theme.surfaceHigh

        anchors.top: parent.top
        anchors.left: parent.left
        anchors.margins: root.showText ? Theme.padCard : 0
        // Square when it is a thumbnail: the cover is a square object
        // and a rectangle of it is a crop nobody asked for.
        width: root.showText ? height : parent.width
        height: root.showText
            ? (root.inPanel ? 90 : parent.height - Theme.padCard * 2)
            : parent.height

        Image {
            id: art
            anchors.fill: parent
            source: Player.artUrl
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: true
            visible: status === Image.Ready || opacity > 0.01
            opacity: status === Image.Ready ? 1 : 0
            Behavior on opacity {
                NumberAnimation { duration: Motion.fadeIn }
            }
            // The art is a background, so it is held back from full
            // strength before anything is laid over it. A tint over a
            // fully bright photograph has to be heavy enough to be
            // muddy before it reads as a tint at all.
            //
            // In a panel there is nothing laid over it: the words are
            // beside it, so the hold-back has nothing to buy and only
            // costs the cover its contrast.
            opacity: root.inPanel ? 1 : 0.62
        }

        // The wash. Over the art, inside its square.
        Rectangle {
            anchors.fill: parent
            color: Theme.primary
            opacity: art.visible
                ? (root.inPanel
                    ? Math.min(0.16, Config.island.artTint * 0.5)
                    : Config.island.artTint)
                : 0.10

            Behavior on opacity { NumberAnimation { duration: Motion.fadeIn } }
        }

        // Text legibility, which is a separate question from theming
        // and gets a separate rectangle — and only when words are over
        // the art, which is now only in the wordless card.
        Rectangle {
            anchors.fill: parent
            visible: !root.showText
            gradient: Gradient {
                GradientStop { position: 0.0; color: Qt.rgba(0, 0, 0, 0.30) }
                GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.62) }
            }
        }
    }

    // The column of words, and everything that hangs under it. It is
    // the whole card in the wordless variant, which is how the
    // transport gets to sit on the cover without a second copy of
    // itself existing for one layout.
    Item {
        id: right

        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.left: root.showText ? artBox.right : parent.left
        anchors.right: parent.right
        anchors.leftMargin: root.showText ? 10 : 0
        anchors.rightMargin: root.showText ? Theme.padCard : 0

        Column {
            id: lines
            visible: root.showText
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            // The cover's gutter, so the two columns start together.
            // Zero in a cell, where `dense` is measured without it —
            // see `inPanel`.
            anchors.topMargin: root.inPanel ? Theme.padCard : 0
            spacing: 1

            Text {
                width: parent.width
                text: Player.title !== "" ? Player.title : "Nothing playing"
                color: "#ffffff"
                font.family: Theme.fontIsland
                font.pixelSize: Theme.fontSizeSmall + 3
                font.weight: Font.Bold
                elide: Text.ElideRight
                renderType: Text.NativeRendering
            }

            Text {
                width: parent.width
                visible: root.tall && Player.artist !== ""
                text: Player.artist
                color: Qt.rgba(1, 1, 1, 0.78)
                font.family: Theme.fontIsland
                font.pixelSize: Theme.fontSizeCaption
                font.weight: Font.DemiBold
                elide: Text.ElideRight
                renderType: Text.NativeRendering
            }

            // Album and source on one line rather than two: they are
            // the metadata under the metadata, and two more rows of it
            // would push the scrubber out of a cell the grid is not
            // going to make taller on their account.
            Text {
                width: parent.width
                visible: root.dense && !root.inPanel
                         && (Player.album !== "" || Player.identity !== "")
                text: {
                    const bits = [];
                    if (Player.album !== "") bits.push(Player.album);
                    if (Player.identity !== "") bits.push(Player.identity);
                    return bits.join("  ·  ");
                }
                color: Qt.rgba(1, 1, 1, 0.52)
                font.family: Theme.fontIsland
                font.pixelSize: Theme.fontSizeCaption - 1
                font.weight: Font.DemiBold
                elide: Text.ElideRight
                renderType: Text.NativeRendering
            }

            // The same two, one each, for a card with the room for
            // them. The source sits under the album at a lower strength
            // rather than beside it: it is the stamp on the metadata,
            // not more of it, and at the end of a line it read as part
            // of a title that had not finished.
            Text {
                width: parent.width
                visible: root.dense && root.inPanel && Player.album !== ""
                text: Player.album
                color: Qt.rgba(1, 1, 1, 0.52)
                font.family: Theme.fontIsland
                font.pixelSize: Theme.fontSizeCaption - 1
                font.weight: Font.DemiBold
                elide: Text.ElideRight
                renderType: Text.NativeRendering
            }

            Text {
                width: parent.width
                visible: root.dense && root.inPanel && Player.identity !== ""
                text: Player.identity
                color: Qt.rgba(1, 1, 1, 0.38)
                font.family: Theme.fontIsland
                font.pixelSize: Theme.fontSizeCaption - 1
                font.weight: Font.DemiBold
                elide: Text.ElideRight
                renderType: Text.NativeRendering
            }
        }

        // Transport. Centred under the words, because it is the one
        // thing on the card you aim at without reading first — and in
        // the wordless card, centred on the cover for the same reason.
        Row {
            id: transport
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: root.showText
                ? Theme.padCard
                : Math.max(0, (root.height - height) / 2)
            spacing: root.roomy ? 14 : 8

            Repeater {
                model: [
                    // The glyphs come from Icons, never typed here:
                    // a private-use character written straight into a
                    // source file does not survive most editing paths
                    // and lands as an empty string, which draws three
                    // buttons with nothing in them.
                    { glyph: Icons.mediaPrev, act: "prev" },
                    { glyph: "",              act: "play" },
                    { glyph: Icons.mediaNext, act: "next" }
                ]

                Item {
                    required property var modelData
                    readonly property bool isPlay: modelData.act === "play"
                    // Whether the player can answer this button at all.
                    // A transport whose labels sit at full strength and
                    // do nothing when pressed is a broken control, not
                    // a quiet one.
                    readonly property bool live:
                        modelData.act === "play" ? Player.canToggle
                        : modelData.act === "prev" ? Player.canPrev
                                                   : Player.canNext

                    width: isPlay ? 30 : 20
                    height: 30
                    anchors.verticalCenter: parent.verticalCenter

                    Rectangle {
                        anchors.fill: parent
                        radius: width / 2
                        visible: parent.isPlay
                        color: Qt.rgba(1, 1, 1, !parent.live ? 0.08
                            : tapped.containsMouse ? 0.32 : 0.22)

                        Behavior on color { ColorAnimation { duration: Motion.fadeIn } }
                    }

                    Text {
                        anchors.centerIn: parent
                        text: parent.isPlay
                            ? (Player.playing ? Icons.mediaPause
                                              : Icons.mediaPlay)
                            : parent.modelData.glyph
                        color: Qt.rgba(1, 1, 1, !parent.live ? 0.26
                            : tapped.containsMouse ? 1 : 0.85)
                        font.family: Theme.fontIcons
                        font.pixelSize: parent.isPlay ? 14 : 12
                        renderType: Text.NativeRendering
                    }

                    MouseArea {
                        id: tapped
                        anchors.fill: parent
                        anchors.margins: -3
                        hoverEnabled: true
                        enabled: parent.live
                        cursorShape: enabled
                            ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onClicked: {
                            switch (parent.modelData.act) {
                                case "prev": Player.prev(); break;
                                case "next": Player.next(); break;
                                default:     Player.toggle();
                            }
                        }
                    }
                }
            }
        }

        // How far through. The visual line stays slim; a taller target
        // below it makes seeking comfortable without changing the layout.
        //
        // Above the stamps rather than under them, and the reason is
        // reading order: the bar is the fifth line of what the card
        // tells you — title, artist, album, source, how far through —
        // and the two stamps under it are the ends of that same line.
        // Under the stamps the bar would be a rule dividing the
        // metadata from its own numbers.
        Rectangle {
            id: progress

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: times.top
            anchors.bottomMargin: 5
            height: 4
            radius: height / 2
            color: Qt.rgba(1, 1, 1, seekMouse.containsMouse ? 0.34 : 0.22)
            visible: root.showText && root.tall
                     && Player.available && Player.length > 0

            Rectangle {
                // Never narrower than it is tall, so the near-start of a
                // track is a cap rather than a sliver.
                width: Math.max(parent.height, parent.width
                    * Math.max(0, Math.min(1, Player.progress)))
                height: parent.height
                radius: parent.radius
                color: Theme.primary
            }
        }

        Item {
            anchors.left: progress.left
            anchors.right: progress.right
            anchors.verticalCenter: progress.verticalCenter
            height: 14
            visible: progress.visible && Player.canSeek

            MouseArea {
                id: seekMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor

                function seekAt(x) {
                    if (width <= 0) return;
                    Player.seek(Player.length * Math.max(0, Math.min(1, x / width)));
                }

                onPressed: mouse => seekAt(mouse.x)
                onPositionChanged: mouse => {
                    if (pressed) seekAt(mouse.x);
                }
            }
        }

        // The two ends of the scrubber: where you are, and what is
        // left. Both are the reason the bar reads as anything at all —
        // a filled line on a black card says "some", and 2:06 of 4:55
        // says where.
        //
        // Directly under the bar they measure, and over the transport:
        // the group below the metadata is the bar, the numbers on it,
        // and the buttons that move it.
        //
        // The height is `childrenRect` rather than a child's
        // `implicitHeight`: this Item's binding is evaluated while its
        // children do not exist yet, and asking an id by name at that
        // moment is a ReferenceError rather than a value to correct.
        Item {
            id: times
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: transport.top
            anchors.bottomMargin: 6
            height: childrenRect.height
            visible: root.timed && progress.visible

            Text {
                anchors.left: parent.left
                text: root.stamp(Player.position)
                color: Qt.rgba(1, 1, 1, 0.55)
                font.family: Theme.fontIsland
                font.pixelSize: Theme.fontSizeCaption - 1
                font.weight: Font.DemiBold
                renderType: Text.NativeRendering
            }

            Text {
                anchors.right: parent.right
                text: "-" + root.stamp(Player.length - Player.position)
                color: Qt.rgba(1, 1, 1, 0.55)
                font.family: Theme.fontIsland
                font.pixelSize: Theme.fontSizeCaption - 1
                font.weight: Font.DemiBold
                renderType: Text.NativeRendering
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        // Under the transport, which is declared above it. This is
        // only for the rest of the card.
        z: -1
        cursorShape: Qt.PointingHandCursor
        onClicked: root.opened()
    }
}
