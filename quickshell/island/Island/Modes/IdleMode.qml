import QtQuick

import "root:/Services"
import "root:/Widgets"

// The collapsed pill: the clock, and whatever just happened.
//
// **One face, one shape, and hover does nothing.** The pill held three
// things at various points in its life — a clock, a date, a media
// visualiser — and then a transport that appeared when you pointed at
// it. The last of those is gone because hovering a shape should not
// change what the shape says. It was redundant anyway: the split's right
// lobe toggles playback, and the control centre carries a full media
// card with artwork and a scrubber.
//
// What is left is the clock, which is there because a desktop shell with
// no clock in its island has given up the reason it exists. The iPhone's
// carries nothing at rest — 125pt of black around a camera housing —
// and it widens only when something happens. Copying their *emptiness*
// here would mean an island with no time in it, so the shape is sized
// to what it holds instead, and the split is how this shell says
// something without being asked.
//
// Sized to the faces rather than being a target, and there is only one
// face now, so the width is the clock plus the padding either side and
// `island.idleWidth` is a floor under it. See Island.qml's
// `collapsedWidth`.
//
// ── Why there is no workspace label ─────────────────────────────
//
// There was one: switching workspace swapped the clock for
// "Workspace 3", in the same face and the same accent, for 1.2s, and
// the pill widened to fit the word.
//
// It is gone because it answered a question the gesture had already
// asked. You pressed the key, you can see where you landed, and the
// cost of saying it again anyway was a clock that went missing on
// every switch — a confirmation nobody requested, arriving whether or
// not it was wanted.
//
// What stays is the track title, which is the transient face worth
// having: it reports something you did not just ask for. That is the
// whole of `textSlot` now — the clock, and a title when one arrives.

Item {
    id: root

    required property var win
    required property var island
    required property var pill

    // Sized to the text, and this is load-bearing rather than tidiness.
    // See the note in git history: this was a `Row` once, and a Row is a
    // positioner that takes its size from its children while an `Item`
    // is 0x0 — so `anchors.centerIn` centred an empty box and the clock
    // hung off to the right of the pill's centre. The pill measured a
    // correct width the whole time, because the pill sizes itself from
    // `textSlot` and never asks this item anything.
    //
    // The box is still only the clock's box, even though the week hangs
    // under it: the strip is a child that reaches below this item, not
    // part of its height, so every face that centres in here centres
    // where it always did. What moves is where *this* sits — up by half
    // the strip, so the clock over the week stays centred in the pill
    // as a pair however tall the week measures.
    width: root.textSlot
    height: timeText.implicitHeight
    anchors.centerIn: parent
    anchors.verticalCenterOffset: -root.stripHeight / 2

    // ── The week ───────────────────────────────────────────────
    //
    // Five days either side of today: the day's letter over its date,
    // the middle one spelled out and in the accent, the rest dim. It is
    // the resting pill's reason to have a second line, and it is the
    // only content in the shell that adds to `idleHeight` rather than
    // living inside it — Island.qml's geometry table reads `stripHeight`
    // and grows the resting pill by exactly this much, while the pods
    // keep their circles at `idleHeight` and centre against the pair.
    //
    // `week` is built once for all five cells rather than once per cell:
    // five independent reads of `Clock.now` straddle midnight now and
    // then, and a row where four cells say Saturday and one says Sunday
    // is a row that is wrong in the one place it is trying to be sure.
    readonly property int stripGap: 2
    readonly property bool stripShown: Config.island.weekStrip

    readonly property var week: {
        const base = new Date(Clock.now.getFullYear(),
                              Clock.now.getMonth(),
                              Clock.now.getDate());
        const out = [];
        for (let i = -2; i <= 2; i++) {
            const d = new Date(base);
            d.setDate(base.getDate() + i);
            out.push(d);
        }
        return out;
    }

    // Up in `expanded` too, which is the reason the panel moved out
    // from under the pill: the pill keeps its clock while the controls
    // are open instead of becoming the panel and losing the only thing
    // it shows at rest.
    readonly property bool shown: island.mode === "idle"
                                  || island.mode === "expanded"

    // Whether a transient face is up. Driven by the services rather than
    // by a timer here, so that a track starting while another mode has
    // the island still expires on its own instead of leaving a stale
    // flag waiting to fire when the pill comes back.
    //
    // Two faces used to share this box — the workspace label and the
    // track title, one winning over the other. The label is gone (see
    // the top of this file), so the union is one member and there is
    // nothing left to arbitrate.
    readonly property bool mediaFlashing:
        Config.island.mediaFlash && Player.flashActive
        && island.mode === "idle" && Player.title !== ""

    readonly property bool flashing: root.mediaFlashing

    opacity: shown ? 1 : 0
    visible: opacity > 0.01

    Behavior on opacity { ContentFade { revealing: root.shown } }

    // ── The clock ───────────────────────────────────────────

    // Measured, not declared. A clock's characters have different
    // advances in a proportional face, so an `implicitWidth` here would
    // change as the digits changed and the pill would breathe once a
    // minute.
    //
    // Three digit samples, because which digit is widest is a property of
    // the face and not something to assume: 0 and 8 are the widest in
    // nearly every sans and 1 is the narrowest, so the max of all three
    // covers the faces where that is not true.
    //
    // Plus one 12-hour sample, which is a different SHAPE and not a
    // different set of digits: "12:41 PM" is two digits, a colon, a space
    // and two capitals, and at 12-hour it is wider than any 24-hour
    // reading. It is measured ALWAYS, not only when the setting is
    // 12-hour, so that toggling the setting cannot resize the pill — the
    // slot is sized for the widest reading either format can produce.
    //
    // A face with genuinely proportional figures defeats all of these,
    // and the honest fix for that one is to pick a different face.
    //
    // `font` is a grouped property, so the samples carry the clock's own
    // font wholesale and cannot drift from it.
    readonly property int clockSlot: Math.round(
        Math.max(w88.implicitWidth, w00.implicitWidth, w11.implicitWidth,
                 w12.implicitWidth)
        + 1)

    // **Sampled, not the live title** — SplitLobe's rule, for its
    // reason. A title changes every few minutes without anyone asking
    // it to, so a width taken from the live one would make the pill
    // breathe on every track change: out to this title's width, back
    // to the clock's, out again. The pill already moves once per flash,
    // which is enough. Two samples, being the two shapes most titles
    // take — a plain one, and one with a feature credit.
    //
    // Capped, because the samples are a floor on legibility and not a
    // promise about anybody's music. The cap is what
    // `Config.island.mediaMaxWidth` is for, and it is why the slot can
    // be narrower than the title actually being shown: the real title
    // is elided into it rather than the pill growing without limit.
    readonly property int mediaSlot: Math.round(Math.min(
        Math.max(mediaShort.implicitWidth, mediaLong.implicitWidth) + 1,
        Config.island.mediaMaxWidth))

    // The box every face is centred in, and the number Island.qml sizes
    // the pill from.
    //
    // The resting pill is the CLOCK's width and nothing else, so a face
    // that only appears sometimes does not leave a permanent hole in the
    // middle of the shape. It used to be the widest of them all, always,
    // on the argument that a pill which resizes is a pill which breathes
    // — and that was true of the idea and wrong for the result: a clock
    // floating in forty pixels of nothing either side of it, permanently,
    // to make room for a title that is on screen for two and a half
    // seconds. A permanently empty pill is worse than a briefly moving
    // one, and the movement here is one widen and one return on an
    // event the user just caused, which is the cheapest possible moment
    // to spend a spring.
    //
    // So the transient face contributes its slot only while it is up, and
    // the width spring in Island.qml does the rest. The clock is the floor
    // because it is the only face that is always true.
    readonly property int textSlot:
        Math.max(clockSlot,
                 root.mediaFlashing ? root.mediaSlot : 0)

    Text {
        id: w88; visible: false; text: "88:88"
        font: timeText.font
    }
    Text {
        id: w00; visible: false; text: "00:00"
        font: timeText.font
    }
    Text {
        id: w11; visible: false; text: "11:11"
        font: timeText.font
    }
    Text {
        id: w12; visible: false; text: "12:41 PM"
        font: timeText.font
    }
    Text {
        id: mediaShort; visible: false; text: "Song Title"
        font: timeText.font
    }
    Text {
        id: mediaLong; visible: false; text: "Song Title (feat. Someone)"
        font: timeText.font
    }

    Text {
        id: timeText
        anchors.centerIn: parent
        width: root.textSlot
        horizontalAlignment: Text.AlignHCenter
        text: Clock.time
        // The accent, which is the wallpaper's own colour by way of
        // matugen. It was `Theme.text` for one commit — on the argument
        // that a clock which changes hue with your desktop is a restless
        // thing to keep in the one place you look constantly, and that
        // white at rest would leave the accent free to mean "something
        // happened".
        //
        // That was a rule invented to justify a change nobody asked for.
        // The accent matching the desktop is the *point* of deriving the
        // accent from the desktop, and the island is the one surface
        // that sits on every wallpaper you will ever see, so it is where
        // that colour is worth having. A themed clock is the best thing
        // about the shape and there is no version of the argument above
        // that survives being told the clock is meant to look like that.
        color: Theme.primary
        // The face, set here and read by everything else in this file —
        // the four width samples and the title sample. `font` is a
        // grouped property, so a binding to it carries family, size,
        // weight and letterSpacing together and cannot drift from what
        // is actually on screen. It was tried the other way round, as a
        // `readonly property font` built in a binding, and QML will not
        // build one that way.
        font.family: Theme.fontIsland
        font.pixelSize: Config.island.fontSize
        font.weight: Config.island.fontWeight
        // Was 1.2, which is 8.6% of the em and a display setting being
        // used on a 14px UI clock. At that tracking the colon drifts off
        // its digits and "2:03 PM" reads as four separate glyphs rather
        // than as a time — obvious at 3x and not quite visible at 1x,
        // which is the worst way for it to be wrong.
        font.letterSpacing: 0.4
        renderType: Text.NativeRendering

        // Out while the number is up, rather than underneath it. The
        // two are the same colour and nearly the same size, so fading
        // both at once reads as a flicker in the middle of the pill
        // instead of as one thing becoming another.
        opacity: root.flashing ? 0 : 1
        Behavior on opacity { ContentFade { revealing: !root.flashing } }
    }

    // ── The now-playing line ─────────────────────────────────
    //
    // What is playing, for as long as it is worth saying — which is
    // less long than it is worth reading, hence the config key.
    //
    // The icon rather than the word "playing". Both cost about the same
    // width, but a note is read pre-lexically while a word has to be
    // read, and this is competing for the half-second your eye spends
    // crossing the top of the screen on its way to something else. It
    // is also the only thing on the pill that says what KIND of thing
    // happened: a bare title beside a clock could be a window title,
    // and the note in front of it is what says that this one is music.
    //
    // Icon and title are two Texts rather than one with a family list
    // because the glyph is a private-use codepoint out of
    // `Theme.fontIcons` while the text is out of `Theme.fontIsland`.
    // Asking one Text to fall back between two families for a single
    // character is something Qt usually does, and "usually" is not good
    // enough for the one character that says what the line is.
    Row {
        id: mediaRow
        anchors.centerIn: parent
        width: root.textSlot
        spacing: Theme.spacingSmall

        opacity: root.mediaFlashing ? 1 : 0
        Behavior on opacity { ContentFade { revealing: root.mediaFlashing } }

        Text {
            id: mediaIcon
            anchors.verticalCenter: parent.verticalCenter
            text: Icons.music
            color: Theme.primary
            font.family: Theme.fontIcons
            font.pixelSize: Config.island.fontSize
            renderType: Text.NativeRendering
        }

        Text {
            id: mediaText
            anchors.verticalCenter: parent.verticalCenter
            // The title is elided into the sampled slot rather than the
            // slot being measured from the title — see `mediaSlot`. A
            // long title loses its tail, which is the right way round:
            // the tail of a track name is the part least likely to be
            // what identifies it.
            width: Math.max(0, root.textSlot
                           - mediaIcon.width - mediaRow.spacing)
            elide: Text.ElideRight
            text: Player.title
            color: Theme.primary
            font: timeText.font
        }
    }

    // The strip itself. A `Row` of five, each cell a column of the
    // letter over the date, measured here and read from Island.qml —
    // nothing else in the shell needs to know how tall a week is.
    //
    // The middle cell is today: spelled out where the others are single
    // letters, in the accent where the others are dim. Both are the
    // same decision the clock makes — the accent is what the wallpaper
    // already said, so today being mint is the row agreeing with the
    // desktop rather than adding a colour to it.
    Row {
        id: strip
        anchors.top: parent.bottom
        anchors.topMargin: root.stripGap
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: 5
        visible: root.stripShown

        Repeater {
            model: root.week

            delegate: Column {
                id: cell

                required property var modelData

                readonly property bool isToday:
                    Qt.formatDateTime(modelData, "yyyy-MM-dd")
                    === Clock.todayKey
                readonly property string dayName:
                    Qt.formatDateTime(modelData, "ddd")

                spacing: 1

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    // Today spelled out, the rest to one letter: the
                    // row is read at a glance and "SAT" is the only
                    // word in it worth the four characters, because it
                    // is the only one being answered for.
                    text: cell.isToday
                        ? cell.dayName.toUpperCase()
                        : cell.dayName.slice(0, 1).toUpperCase()
                    color: cell.isToday ? Theme.text
                                        : Qt.rgba(1, 1, 1, 0.42)
                    font.family: Theme.fontIsland
                    font.pixelSize: 8
                    font.weight: Font.DemiBold
                    renderType: Text.NativeRendering
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Qt.formatDateTime(cell.modelData, "d")
                    color: cell.isToday ? Theme.primary : Theme.textDim
                    font.family: Theme.fontIsland
                    font.pixelSize: 11
                    font.weight: cell.isToday ? Font.Bold : Font.DemiBold
                    renderType: Text.NativeRendering
                }
            }
        }
    }

    // Declared under the strip rather than over it because they read
    // it: a binding that asks an id declared further down the file what
    // it measures runs while that id does not exist yet, and the first
    // evaluation comes back as a ReferenceError rather than as a zero
    // to be corrected. Island.qml reads these two for the resting
    // pill's height and floor.
    readonly property int stripHeight:
        root.stripShown ? strip.implicitHeight + root.stripGap : 0
    readonly property int stripWidth:
        root.stripShown ? strip.implicitWidth : 0
}
