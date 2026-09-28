import Quickshell
import QtQuick

import "root:/Services"
import "root:/Widgets"

// One half of the split island.
//
//     SplitLobe { side: "left";  content: "track" }
//     SplitLobe { side: "right"; content: "bars" }
//
// **What this is.** Press and hold the pill and the island parts into
// two lobes either side of the camera housing — the gesture the
// iPhone's Dynamic Island has and this one did not. The left lobe says
// *what* is playing — the cover and the name of it — and the right says
// *that* it is.
//
// **Why it is not a Pod.** `Island/Pods/Pod.qml` is the same silhouette
// for the opposite job: a satellite that is always there, answers
// hover, can be pinned, peeks at you when its contents change, and
// collapses to nothing when it has nothing to say. A lobe is none of
// those. It exists only while the island is split, it is never
// hovered, and it has exactly one click. Building it out of Pod would
// have meant inheriting a hover machine and a pin state in order to
// leave both switched off — and Pod's `docked` contract is the very
// thing a lobe inverts, since a Pod undocks when the island leaves
// idle and a lobe only exists in a mode idle does not have.
//
// **Why the gap shows the wallpaper.** On the phone the housing is
// black, so the split reads as two lobes with black between them. Here
// there is no camera, so the housing is a real but much shorter bar
// and the notches above and below it are wallpaper — see
// `Theme.housing`, which is the whole trick. The pill itself is that
// bar: in split mode the pill shrinks to the housing's width and
// height and the lobes anchor to its two edges exactly as the pods
// anchor to the pill's. One surface, one centre, one morph.

Item {
    id: root

    required property var win      // the PanelWindow
    required property var island   // mode flags
    required property var pill     // the housing, in split mode

    // Which edge of the housing it attaches to. "left" is the app
    // icon, "right" is the equaliser.
    property string side: "left"

    // "track" | "bars". A string rather than a bool because a third kind
    // of content is a plausible extension and `content: "album"` reads
    // better at the call site than a second flag.
    property string content: "track"

    // A media state, like iOS's: there is nothing to part around if
    // nothing is playing, so a hold with no track does nothing rather
    // than opening two empty capsules. `island.media` is the same
    // signal the resting pill's equaliser reads, so the split cannot
    // appear for a player that has stopped answering.
    readonly property bool shown:
        Config.island.splitEnabled
        && island.mode === "split"
        && island.media

    // ── The readout's measurements ────────────────────────────
    //
    // A now-playing readout, so the track's name has somewhere to be.
    // It is the one piece of the split that can identify what is
    // playing: an equaliser says *that* something is and an app icon
    // says which program is responsible for saying so, and neither of
    // those is the answer to "what is this".
    //
    // Is there a title to show, and how much room does one get.
    readonly property bool titleVisible:
        content === "track" && Player.title !== ""

    // **A stable width, sampled, not the live title.** This is the
    // resting pill's digit-sample rule applied to a title, and for the
    // same reason: the shape must not move on its own.
    //
    // A title changes every few minutes without anyone asking it to, so
    // a lobe sized to the live one would make the island breathe three
    // or four times an hour — the same fault the four clock samples
    // exist to prevent, and a worse one, because a song title is a far
    // bigger jump than a digit. Two of them: a plain title, and one with
    // a feature credit, which is the shape most long titles take.
    //
    // Capped, because the samples are a floor on legibility and not a
    // promise about anybody's music.
    readonly property int titleSlot: Math.round(Math.min(
        Math.max(titleShort.implicitWidth, titleLong.implicitWidth) + 1,
        128))

    readonly property int coverEdge: 26

    // ── How the shape moves ──────────────────────────────────
    //
    // The same contract the island and the pods have: this says which
    // way it is going and every spring on it reads the answer. A Spring
    // takes `shape` and reads `springResponse` and `springBounce` off
    // it, so an object that does not declare the pair gets
    // `undefined` for both and every spring on it warns once per
    // re-evaluation — which is the whole of what the warnings on
    // Spring.qml's lines 54 and 55 turned out to be.
    //
    // There is no peek and no hover tier here, unlike Pod.qml: a lobe
    // either exists or it does not. So the two tiers are the same two
    // the island itself picks between, and picking them here rather
    // than reading `island.springResponse` is deliberate — the values
    // are identical by construction, and a lobe that read the island's
    // would silently change tempo if the island ever gained a third
    // tier.
    readonly property int springResponse:
        shown ? Motion.expandResponse : Motion.collapseResponse

    readonly property real springBounce:
        shown ? Motion.arriveBounce : Motion.departBounce

    // ── Geometry ─────────────────────────────────────────────
    //
    // Anchored to the housing's edges, not to the island's, and to its
    // vertical centre rather than its top: the housing is shorter than
    // the lobes (that is the point of it) so an item following its top
    // edge would sit high and the pair would look like it was climbing.
    anchors.verticalCenter: pill.verticalCenter
    anchors.right: side === "left" ? pill.left : undefined
    anchors.left: side === "right" ? pill.right : undefined

    // Two pixels off the housing. Flush would be more literal and reads
    // worse: the housing's own rounded end and the lobe's rounded end
    // would touch, and two arcs meeting at a point read as one outline
    // with a kink in it rather than as two objects.
    anchors.rightMargin: tuck.value
    anchors.leftMargin: tuck.value

    Spring {
        id: tuck
        shape: root
        target: root.shown ? 2 : -8
    }

    width: lobeWidth.value
    height: lobeHeight.value

    // The pill's height, always. A lobe is never taller or shorter than
    // the resting pill — the split is a change in the island's WIDTH,
    // not in its height, and letting the height move would make the
    // island look like it was also growing.
    Spring {
        id: lobeHeight
        shape: root
        minimum: 0
        target: root.shown ? Config.island.idleHeight : 0
    }

    // The left lobe is as wide as a now-playing readout needs and the
    // right is the fixed `splitLobe`, because only one of them has
    // anything to say.
    //
    // The readout is cover, then the name. The name is what identifies
    // the track — an icon cannot, and neither can an equaliser — and it
    // is the reason this lobe is not a 56px capsule any more.
    readonly property int trackWidth: Math.round(
        Theme.padRow + coverEdge
        + (titleVisible ? Theme.spacingSmall + titleSlot : 0)
        + Theme.padRow)

    Spring {
        id: lobeWidth
        shape: root
        minimum: 0
        target: !root.shown ? 0
              : root.content === "track" ? root.trackWidth
              : Config.island.splitLobe
    }

    opacity: shown ? 1 : 0
    // Toward the housing, so a leaving lobe collapses into the island
    // rather than shrinking into its own middle. The same rule and the
    // same transformOrigin value as Pod.qml.
    scale: lobeScale.value
    transformOrigin: side === "left" ? Item.Right : Item.Left
    visible: opacity > 0.01

    Spring {
        id: lobeScale
        shape: root
        minimum: 0
        target: root.shown ? 1 : Motion.absentScale
    }

    Behavior on opacity { ContentFade { revealing: root.shown } }

    // ── Surface ──────────────────────────────────────────────
    //
    // The pill's, exactly. A lobe is the island in a smaller shape and
    // nothing about it should say otherwise — same fill, same corner
    // function against its own height, same edge, same shadow.
    readonly property real radius: Theme.corner(height)

    readonly property color fill: {
        if (Config.appearance.islandBlack) return Theme.islandSurface;
        const c = Qt.color(Theme.surfaceLowest);
        return Qt.rgba(c.r, c.g, c.b, Config.island.opacity);
    }

    Shadow { shape: surface; anchors.fill: parent; spread: 10 }

    Squircle {
        id: surface
        smoothing: Config.appearance.cornerSmoothing
        anchors.fill: parent
        radius: root.radius
        color: root.fill
        borderWidth: Theme.islandEdge ? 1 : 0
        borderColor: Theme.outlineVariant
    }

    Bezel {
        z: 49
        outer: root.radius
        visible: Theme.islandEdge
    }

    // ── Content ──────────────────────────────────────────────

    Item {
        anchors.fill: parent

        // The app's own icon where one can be found, and a music note
        // where one cannot — the same arrangement NotifyMode uses for a
        // notification with no icon, deliberately: an Image that reports
        // itself not-ready and a glyph underneath it, rather than an
        // empty space that reads as a failed load.
        //
        // Album art was tried here in between and removed. It is the
        // more informative of the two and it does resolve for every
        // player worth the name, but a 20px cover of a 640px JPEG is a
        // postage stamp: at that size almost no cover is legible, it
        // turns into a coloured blur, and it changes every few minutes
        // so the one recognisable thing in the shape is the one thing
        // that keeps moving. The iPhone can put a cover in a Live
        // Activity because its island is 160pt of black on a 400pt
        // screen; this one is a 44px capsule on a 34px-tall pill.
        //
        // `width`/`height` and not `implicitSize`, which is IconImage's
        // property and not Image's — a plain Image has no implicit size
        // to set. `sourceSize` as well, so a 3000px desktop icon is
        // decoded at 16 rather than scaled down from its own resolution
        // into a 44px capsule.
        // ── The cover, or the app, or a note ─────────────────
        //
        // The cover comes first because it is the one that identifies
        // the *track*, and because it is the only one of the three that
        // a music service in a browser can supply: MPRIS reports the
        // browser, so YouTube Music in Brave arrives as "Brave Origin"
        // and the app icon is a browser. Every one of those players
        // publishes `xesam:artUrl` — a real cover off the service's own
        // CDN — and it needs no table of services and cannot fall out
        // of date.
        //
        // Album art was tried here on its own, at this size, with no
        // name beside it, and it was wrong: a 20px cover of a 640px
        // JPEG is a postage stamp, most covers are illegible at that
        // size, and it changes every few minutes so the one
        // recognisable thing in the shape was the one thing that kept
        // moving. Beside the name it is recognition rather than
        // information, which is the job it is actually good at.
        Image {
            id: cover
            width: root.coverEdge
            height: root.coverEdge
            sourceSize.width: 64
            sourceSize.height: 64
            visible: root.content === "track" && status === Image.Ready
            source: Player.artUrl
            fillMode: Image.PreserveAspectFit
            asynchronous: true
            cache: true
            anchors.left: parent.left
            anchors.leftMargin: Theme.padRow
            anchors.verticalCenter: parent.verticalCenter
        }

        Image {
            id: art
            width: 18
            height: 18
            sourceSize.width: 18
            sourceSize.height: 18
            visible: root.content === "track"
                     && status === Image.Ready
                     && !root.coverReady
            source: root.playerClass !== ""
                ? Quickshell.iconPath(root.playerClass, true)
                : ""
            fillMode: Image.PreserveAspectFit
            asynchronous: true
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
        }

        Text {
            id: note
            anchors.centerIn: parent
            visible: root.content === "track" && !root.iconReady
            text: Icons.music
            color: Theme.textDim
            font.family: Theme.fontIcons
            font.pixelSize: 14
            font.weight: Config.island.fontWeight
            renderType: Text.NativeRendering
        }

        // The name. Elided into the sampled slot, and never wider than
        // it, so a long title loses its tail rather than the island's
        // symmetry.
        Text {
            id: title
            visible: root.titleVisible
            anchors.left: cover.visible ? cover.right : parent.left
            anchors.leftMargin: cover.visible ? Theme.spacingSmall
                                               : Theme.padRow
            anchors.right: parent.right
            anchors.rightMargin: Theme.padRow
            anchors.verticalCenter: parent.verticalCenter
            text: Player.title
            color: Theme.text
            font.family: Theme.fontIsland
            font.pixelSize: Theme.fontSizeCaption
            font.weight: Font.DemiBold
            elide: Text.ElideRight
            renderType: Text.NativeRendering
        }

        // The samples. Off screen, carrying the title's own font, and
        // the reason the lobe is as wide as it is — see `titleSlot`.
        Text {
            id: titleShort
            visible: false
            text: "Song Title"
            font: title.font
        }
        Text {
            id: titleLong
            visible: false
            text: "Song Title (feat. Someone)"
            font: title.font
        }

        // The equaliser, and the same one the resting pill uses. It is
        // duplicated rather than shared because IdleMode's is a delegate
        // list with a transport slot hanging off it and this is three
        // bars in a 44px capsule; the alternative is a component whose
        // only job is to be configured two ways.
        Row {
            anchors.centerIn: parent
            visible: root.content === "bars"
            spacing: 2

            Repeater {
                model: 3

                Rectangle {
                    required property int index

                    width: 2
                    height: 9
                    radius: width / 2
                    anchors.verticalCenter: parent.verticalCenter
                    color: Player.playing ? Theme.primary : Theme.outline

                    Behavior on color { ColorAnimation { duration: Motion.fadeIn } }

                    SequentialAnimation on height {
                        running: Player.playing && root.shown
                                 && root.visible
                        loops: Animation.Infinite

                        PauseAnimation { duration: index * 120 }
                        NumberAnimation {
                            to: 14; duration: 320
                            easing.type: Easing.InOutQuad
                        }
                        NumberAnimation {
                            to: 5; duration: 320
                            easing.type: Easing.InOutQuad
                        }
                    }
                }
            }
        }
    }

    // ── Input ────────────────────────────────────────────────
    //
    // One click each, and the two do different things, because two
    // things that did the same thing would be worse than one that does:
    //
    //   the icon  opens the control centre, which is where this
    //             shell's media card lives
    //   the bars   toggle playback, which is the gesture the bars
    //             themselves are asking for
    //
    // Deliberately last and above the content, for the same reason the
    // pill's hover MouseArea is: a child MouseArea with hoverEnabled
    // consumes hover.
    MouseArea {
        id: click
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton
        // Only the bars are a control. The icon opens a panel, which is
        // worth the pointer saying so.
        cursorShape: root.content === "bars"
            ? Qt.PointingHandCursor : Qt.ArrowCursor

        onClicked: {
            if (root.content === "bars") Player.toggle();
            else root.win.openControl();
        }
    }

    // Whether anything resolved, which is the only way to tell "this
    // player has no art, no icon and no name" from "it is still loading"
    // from a screenshot. Read by the `splitinfo` IPC.
    readonly property bool iconReady:
        coverReady || art.status === Image.Ready

    readonly property bool coverReady: cover.status === Image.Ready

    // A desktop class to ask `Quickshell.iconPath` about.
    //
    // `Player.desktopEntry` first, and that is not a refinement, it is
    // the correct answer: MPRIS carries a `DesktopEntry` property
    // precisely so a consumer can identify the application, and
    // `iconPath` consumes exactly that vocabulary. Measured — Spotify's
    // own player reports `spotify`, and there is a `spotify.desktop` on
    // disk to match it.
    //
    // The old version guessed from `identity`, which is a *display
    // name*, and it mangled the two shapes that matter:
    //
    //   Mozilla Firefox   ->  firefox    right, by luck: last word
    //   Brave Origin      ->  origin     wrong: the browser's product
    //                                   name, and `origin` is not an
    //                                   application anything ships
    //
    // The last-segment rule still stands as a fallback, because plenty
    // of players leave `DesktopEntry` empty and the note underneath is
    // a worse answer than a guess that sometimes lands. It is a guess
    // and deliberately so: the alternative is asking the user which
    // icon belongs to which player, which is real machinery for a
    // cosmetic detail. `iconReady` is what tells the cases apart from
    // outside.
    readonly property string playerClass: {
        if (Player.desktopEntry !== "") return Player.desktopEntry;

        const id = (Player.identity || "").trim();
        if (id === "") return "";
        const parts = id.split(/[.\s]+/).filter(s => s.length > 0);
        return parts.length === 0 ? "" : parts[parts.length - 1].toLowerCase();
    }
}
