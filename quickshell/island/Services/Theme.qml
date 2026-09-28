pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    property var palette: ({})

    readonly property string background:       palette.background       ?? "#0e0e11"
    readonly property string fgOnBackground:     palette.onBackground     ?? "#e4e4e8"

    readonly property string surface:          palette.surface          ?? "#0e0e11"
    readonly property string surfaceLowest:    palette.surfaceLowest    ?? "#08080a"
    readonly property string surfaceLow:       palette.surfaceLow       ?? "#141418"
    readonly property string surfaceContainer: palette.surfaceContainer ?? "#1a1a1f"
    readonly property string surfaceHigh:      palette.surfaceHigh      ?? "#24242a"
    readonly property string surfaceHighest:   palette.surfaceHighest   ?? "#2e2e35"
    readonly property string text: {
        const c = Qt.color(palette.surface ?? "#0e0e11");
        const lum = 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b;
        return lum < 0.5 ? "#ffffff" : "#0b0b0d";
    }
    readonly property string textDim: palette.onSurfaceVariant ?? "#c2c2ca"

    readonly property string primary:          palette.primary          ?? "#e8e8ec"
    readonly property string textOnPrimary:        palette.onPrimary        ?? "#111114"
    readonly property string secondary:        palette.secondary        ?? "#b8b8c0"
    readonly property string tertiary:         palette.tertiary         ?? "#9a9aa4"
    readonly property string error:            palette.error            ?? "#ffb4ab"
    readonly property string textOnError:          palette.onError          ?? "#690005"
    readonly property string outline:          palette.outline          ?? "#55555e"
    readonly property string outlineVariant:   palette.outlineVariant   ?? "#2a2a30"

    // The lit half of an edge — see Widgets/Bezel.qml, which draws it.
    // Deliberately not a palette entry: it is a highlight rather than
    // a hue, and matugen has no opinion about how much light lands on
    // a corner. A wash also survives a light palette, where an
    // outlineVariant scaled down would go muddy rather than bright.
    // Bright enough to clear the fill by about thirty levels, which is
    // what it takes for the gap between it and the outer hairline to
    // register as a gap rather than as antialiasing.
    readonly property color bezel: Qt.rgba(1, 1, 1, 0.14)

    // ── The island's own surface ─────────────────────────────
    //
    // Three answers, gathered here so the pill, the pods, the shelf
    // and the settings preview cannot each decide them separately.
    // See Config.appearance.islandBlack / islandEdge / islandShadow
    // for why each one is a decision.

    // #000, in every palette and in light mode too, because that is
    // what the iPhone's is. Not surfaceLowest: that is a dark grey
    // that happens to sit near the bottom of a Material ramp, and on
    // a light palette it is a light grey, which is a pale card and
    // not a hole in the screen.
    readonly property color islandSurface: "#000000"

    // Whether the doubled hairline is drawn. Off by default — see
    // Config.appearance.islandEdge for the argument it lost.
    readonly property bool islandEdge: Config.appearance.islandEdge

    // The shadow's strength, 0 to 1. 0 draws nothing at all rather
    // than a transparent stack, so the cost is not paid for a
    // setting that is off.
    readonly property real islandShadow: Math.max(
        0, Math.min(1, Config.appearance.islandShadow))

    // Set on the Appearance page. The shipped names are the fallback
    // rather than the default, and they are doing real work: a font
    // that gets uninstalled after it was picked leaves the key
    // pointing at a family fontconfig cannot resolve, and a shell
    // silently drawing in Qt's default sans — with every icon a box,
    // because that font has none of them — is a much harder thing to
    // diagnose than a shell that went back to what it came with.
    readonly property string fontFamily:
        Config.appearance.fontFamily || "JetBrainsMono Nerd Font"
    readonly property string fontMono:
        Config.appearance.fontMono || "JetBrainsMono Nerd Font Mono"

    // Icons only. Every glyph in Services/Icons.qml is a codepoint in
    // this font, so anything drawing one asks for it by name instead
    // of inheriting fontFamily — which is what frees fontFamily to be
    // a proportional face.
    readonly property string fontIcons:
        Config.appearance.fontIcons || "JetBrainsMono Nerd Font"

    // The pill and what it holds. Proportional by default, because the
    // iPhone's is — SF Pro, rounded and humanist — and a monospace
    // clock is the strongest single thing telling you this is a
    // terminal readout rather than a phone. Empty in settings means
    // "follow fontFamily"; see Config.appearance.fontIsland for how
    // the width stays still without the pin.
    readonly property string fontIsland:
        Config.appearance.fontIsland || Config.appearance.fontFamily
        || "Adwaita Sans"

    // ── Type scale ──────────────────────────────────────────
    //
    // A ladder, and a complete one. There were three rungs below
    // `fontSizeSmall` and every one of them was written as subtraction
    // from it — thirty-four times across the shell — which is the same
    // failure this project keeps catching elsewhere: two different
    // numbers for the same gap. The sizes were 8, 9 and 10, none of them
    // was a name, and each use was somebody having to remember what the
    // subtraction meant.
    //
    // The values are unchanged. What changed is that each is now a rung
    // you pick by what it is for.
    readonly property int fontSizeTiny:    8  // an index number, a count
    readonly property int fontSizeMicro:   9  // the smallest running text
    readonly property int fontSizeCaption: 10  // a hint, a generic name
    readonly property int fontSizeSmall:  11  // a row's secondary line
    readonly property int fontSizeNormal: 13
    readonly property int fontSizeLarge:  16
    readonly property int fontSizeTitle:  22

    // ── Icon sizes ──────────────────────────────────────────
    //
    // Not the type scale, and deliberately beside it rather than inside
    // it: an icon is a drawing, and the size that suits a glyph in a
    // 36px list row is not the size that suits one on a 90px tile. These
    // are named by what they sit in.
    //
    // They exist because the island had 13, 16, 18, 20 and 22 written
    // inline for "an icon" — five numbers, no names, and the same bell
    // drawn at 16 in the notification history and 20 in the notification
    // popup. Each token holds the value that was already there, so this
    // moves no pixels; what it buys is that the next person has rungs to
    // choose from instead of a number to guess at.
    //
    // Which rung a given glyph wants is still a judgement, and the two
    // bells are the clearest case. They are left different on purpose:
    // one is a row's leading icon and one is a popup's, and a popup has
    // ninety-odd pixels of height to spend where a row has thirty-six.
    readonly property int iconSizeRow:   13  // a glyph in a 36px list row
    readonly property int iconSizeBody:  16  // a glyph beside body text
    readonly property int iconSize:      18  // a glyph in a panel — the default
    readonly property int iconSizeLarge: 20  // a popup's leading icon
    readonly property int iconSizeTile:  22  // a glyph on a 90px tile

    // The lock screen clock: display type, not text at any of the four
    // sizes above. Large enough to read from across the room, which is
    // the whole job of a clock nobody is sitting in front of.
    readonly property int fontSizeClock:  104

    // All derived from the one radius the user sets. Pick by what the
    // thing IS, not its size — Qt clamps to half the shorter side, so
    // a small control becomes a capsule on its own.
    //
    //   radiusLarge   a card: holds other things, sits on a surface
    //   radiusNormal  a panel, or a field you type into
    //   radiusSmall   a chip: one word or one glyph
    //
    // A shape in a container's corner uses none of them — see `inner`.
    // A shape that is round as a fact rather than a preference (knob,
    // slider handle, dash) is `height / 2` where it is drawn.
    readonly property int radiusSmall:
        Math.round(Config.appearance.panelRadius * 0.6)
    readonly property int radiusNormal: Config.appearance.panelRadius
    readonly property int radiusLarge:
        Math.round(Config.appearance.panelRadius * 1.2)

    readonly property int spacingSmall:  6
    readonly property int spacingNormal: 12
    readonly property int spacingLarge:  20

    // Two kinds of edge: a card sitting on the panel holds its
    // contents in by `padCard`; a row already inset by its container
    // needs less, `padRow`. Named rather than written per file, where
    // they drifted between 7 and 12 — invisible on one card, very
    // visible down a column of them.
    readonly property int padCard: 12
    readonly property int padRow:  10

    // Badge to the words beside it. Its own number: it is a gap
    // between two things rather than a margin against an edge, and
    // they should not have to change together.
    readonly property int gapBadge: 10

    // The icon column in a list row, and the box the field's caret
    // sits in above it.
    //
    // It lived in SearchMode as a local, "read by the row delegate and
    // by the field's glyph box so the two cannot drift" — which held
    // only while both were in one file. The field and the list are two
    // surfaces now, in two files, so the one number that keeps their
    // left edges on the same column has to be somewhere they both
    // already look.
    readonly property int iconRow: 22

    // The same colour, at zero alpha.
    //
    // `"transparent"` is #00000000 — black that merely happens to be
    // invisible — so a ColorAnimation between a fill and
    // `"transparent"` drags its RGB down to black on the way out and
    // back up from black on the way in. Half way through a hover fade
    // the row is darker than the surface it sits on, which is a black
    // flash under the cursor.
    //
    // It survived for as long as it did because it is invisible on a
    // palette whose surfaces are already near black — a wallpaper
    // derived one usually is. Any lighter surface shows it, which is
    // what the named presets are: Nord's #343a48 dips to #1f232b on
    // its way in.
    //
    // Fading a colour to its own zero-alpha keeps the hue and moves
    // only the alpha, which is what "fade out" was always supposed to
    // mean.
    function fade(c) {
        const col = Qt.color(c);
        return Qt.rgba(col.r, col.g, col.b, 0);
    }

    // The corner a shape of this height should have. Two regimes, and
    // the join between them is the whole point.
    //
    // **At and below the resting height the shape is a capsule.** The
    // corner is half the height, and that is a fact about the shape
    // rather than a preference — a pill's ends are semicircles. It is
    // also the iPhone's answer, and it is load-bearing: a stadium
    // reads as a hole cut in the screen and a rounded rectangle reads
    // as a card sitting on it, and no amount of blur or shadow makes
    // up the difference. The pill and both pods are capsules at rest
    // because of this line.
    //
    // **Above it, the radius opens up with the shape**, so a 374px
    // control-centre panel is a rounded rectangle rather than a
    // lozenge.
    //
    // It grows out of the cap rather than out of `Config.island.radius`.
    // Growing it out of the radius instead is the mistake this replaced:
    // it put a discontinuity at idleHeight, because `radius + h * 0.06`
    // answers 17 for a 34px pill only by accident and 10 for a 35px one
    // deliberately. The pill was a 17-cornered capsule at rest and a
    // 10-cornered rounded rectangle six pixels into the hover morph —
    // a visible pop, and one the comments here claimed was not there
    // ("34px -> 16 (a capsule)"; it was 10, and 16 was never half of
    // 34 either).
    //
    // The slope is 0.039. It is chosen so the control centre lands
    // where it already did — about 31px on 374, which is the same
    // corner the cards inside it are inset by — and the function is
    // continuous through every mode between: 34 -> 17, 40 -> 17.2,
    // 58 -> 17.9, 104 -> 19.9, 176 -> 24.1, 374 -> 31.8.
    function corner(h) {
        const rest = Config.island.idleHeight;
        if (h <= rest) return h / 2;
        return Math.min(h / 2, rest / 2 + (h - rest) * 0.039);
    }

    // The radius a shape outset by `pad` needs to stay concentric with
    // a corner of `outer`. The mirror of `inner`, and needed by the
    // same argument: a shadow ring drawn at the same radius as the
    // shape it belongs to has a gap down the straights and
    // `pad * 1.41` through the corner, which on a soft edge reads as
    // the shadow being the wrong shape.
    function outer(outer, pad) {
        return outer + pad;
    }

    // How much shorter than the island the camera housing is while the
    // island is split. See Island/SplitLobe.qml.
    //
    // This is the whole trick, and it is one number. A housing as tall
    // as the lobes either side of it fills the gap between them, and the
    // island reads as one wide black bar with nothing split about it. A
    // housing noticeably shorter leaves two notches cut into the top and
    // bottom edges, and that silhouette is what the eye recognises as a
    // Dynamic Island parted around its camera — without anything having
    // to be drawn in the gap, which on a desktop is wallpaper and has
    // nothing to draw.
    //
    // 0.65 of the pill's height. Deep enough to read at a glance, shallow
    // enough that the housing still looks like part of one object rather
    // than like a bar laid across it. A function of the height rather
    // than a setting, so the notch keeps its proportion when the pill's
    // height slider moves.
    function housing(h) {
        return Math.round(h * 0.65);
    }

    // The radius a shape inset by `pad` needs to stay concentric with
    // a corner of `outer`. The rule is the subtraction and nothing
    // else: inner = outer - pad. Matching the outer radius instead
    // leaves a gap of `pad` down the straights but `pad * 1.41`
    // through the corner, which reads as the inner shape sliding out
    // diagonally.
    //
    // Clamped at zero: a shape further from the edge than the corner
    // is round is genuinely square there.
    function inner(outer, pad) {
        return Math.max(0, outer - pad);
    }

    // Durations and easings used to live here too. Motion is a spring
    // now and the whole vocabulary is in Services/Motion.qml, which is
    // where anything animating should look — these were four constants
    // describing a model the shell no longer uses.

    FileView {
        id: colorFile
        path: Paths.colors

        watchChanges: true
        onFileChanged: reload()

        onLoaded: {
            try {
                root.palette = JSON.parse(colorFile.text());
                console.log("[Theme] loaded", Object.keys(root.palette).length, "colors");
            } catch (e) {
                console.warn("[Theme] colors.json is not valid JSON —", e);
            }
        }

        onLoadFailed: {
            console.log("[Theme] no colors.json yet, using fallbacks");
        }
    }
}
