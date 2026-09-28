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

    // Laid out for a panel rather than for a grid cell. Two
    // differences, both of them paid for out of having the height to
    // spend: the album and the source take a row each instead of
    // sharing one, and the column of words gets the top gutter the
    // cover already has — so the title starts level with the artwork
    // instead of a row above it, which is what a cell with `padCard`
    // below it and none above looks like.
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

    ClippingRectangle {
        id: frame
        anchors.fill: parent
        radius: Theme.radiusLarge
        color: Theme.surfaceHigh
    }

    // Outside the clip. A 1px stroke drawn inside a rounded clip loses
    // its outer half to the clip and reads as a half-pixel smudge that
    // varies around the curve.
    Rectangle {
        anchors.fill: parent
        color: "transparent"
        radius: frame.radius
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.10)
    }

    // The cover, as a square beside the words — or as the whole card
    // when there are no words to stand beside.
    ClippingRectangle {
        id: artBox
        radius: root.showText ? Theme.corner(width) : frame.radius
        color: Theme.surfaceHigh

        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.margins: root.showText ? Theme.padCard : 0
        // Square when it is a thumbnail: the cover is a square object
        // and a rectangle of it is a crop nobody asked for.
        width: root.showText ? height : parent.width

        Image {
            id: art
            anchors.fill: parent
            source: Player.artUrl
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: true
            visible: status === Image.Ready
            // The art is a background, so it is held back from full
            // strength before anything is laid over it. A tint over a
            // fully bright photograph has to be heavy enough to be
            // muddy before it reads as a tint at all.
            opacity: 0.62
        }

        // The wash. Over the art, inside its square.
        Rectangle {
            anchors.fill: parent
            color: Theme.primary
            opacity: art.visible ? Config.island.artTint : 0.10

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
                font.pixelSize: Theme.fontSizeSmall + 1
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

                    width: isPlay ? 26 : 18
                    height: 26
                    anchors.verticalCenter: parent.verticalCenter

                    Rectangle {
                        anchors.fill: parent
                        radius: width / 2
                        visible: parent.isPlay
                        color: Qt.rgba(1, 1, 1, !parent.live ? 0.08
                            : tapped.containsMouse ? 0.28 : 0.18)

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
                        font.pixelSize: parent.isPlay ? 12 : 11
                        renderType: Text.NativeRendering
                    }

                    MouseArea {
                        id: tapped
                        anchors.fill: parent
                        anchors.margins: -3
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
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

        // How far through. A line rather than a scrubber: at this size
        // a draggable track would be four pixels of target, and the
        // strip along the panel's floor already has a real one.
        Rectangle {
            id: progress

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: transport.top
            anchors.bottomMargin: 7
            height: 3
            radius: height / 2
            color: Qt.rgba(1, 1, 1, 0.22)
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

        // The two ends of the scrubber: where you are, and what is
        // left. Both are the reason the bar reads as anything at all —
        // a filled line on a black card says "some", and 2:06 of 4:55
        // says where.
        //
        // The height is `childrenRect` rather than a child's
        // `implicitHeight`: this Item's binding is evaluated while its
        // children do not exist yet, and asking an id by name at that
        // moment is a ReferenceError rather than a value to correct.
        Item {
            id: times
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: progress.top
            anchors.bottomMargin: 3
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
