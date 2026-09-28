import QtQuick
import "root:/Services"
import "root:/Widgets"

// The pill: when it shows, what it shows, and what shape it is.
//
// The handful of settings anyone actually changes are up top; the
// pixel sizes that tune the shape once are behind a fold. A few keys
// are deliberately not in the window at all — still in settings.json
// and still editable by hand, just not charged to every reader of
// this page.
//
// Each setting lives on the page that draws the thing, and only
// there.

Column {
    id: page
    spacing: 8

    PageHeader {
        glyph: Icons.tabIsland
        title: "Bar & Island"
        subtitle: "Shape and size of the island, the pods, and the clock."
    }

    SectionHeader { text: "Preview"; section: "island" }

    IslandPreview { width: parent.width }

    SectionHeader { text: "Visibility" }

    Card {
    ChoiceRow {
        configKey: "island.visibility"
        label: "On screen"
        description: "Always reserves the strip — top margin plus island"
            + " height, so those two sliders are what make it cost less."
            + " Smart moves aside instead."
        current: Config.island.visibility
        options: [
            { value: "always", label: "Always" },
            { value: "smart",  label: "Smart" }
        ]
        onSelected: function(v) { Config.island.visibility = v }
    }

    ToggleRow {
        configKey: "island.hideOnFullscreen"
        label: "Hide when fullscreen"
        description: "Out of the way of video and games."
        checked: Config.island.hideOnFullscreen
        onToggled: function(v) { Config.island.hideOnFullscreen = v }
    }
    }

    SectionHeader { text: "Pods" }

    Card {
    ToggleRow {
        configKey: "island.showMedia"
        label: "Now playing pod"
        description: "Left of the island. The cover, or the player's icon. Collapses when nothing is playing."
        checked: Config.island.showMedia
        onToggled: function(v) { Config.island.showMedia = v }
    }

    ToggleRow {
        configKey: "island.showControl"
        label: "Control pod"
        description: "Right of the island. Click it for the control centre."
        checked: Config.island.showControl
        onToggled: function(v) { Config.island.showControl = v }
    }
    }

    SectionHeader { text: "Workspace" }

    Card {
    ChoiceRow {
        configKey: "island.scrollAction"
        label: "Scroll over the island"
        description: "An OSD on screen always takes the gesture instead."
        current: Config.island.scrollAction
        options: [
            { value: "workspace", label: "Workspace" },
            { value: "volume",    label: "Volume" },
            { value: "none",      label: "Nothing" }
        ]
        onSelected: function(v) { Config.island.scrollAction = v }
    }
    }

    SectionHeader { text: "Now playing" }

    Card {
    ToggleRow {
        configKey: "island.mediaFlash"
        label: "Name the track in the island"
        description: "The pill says what started playing, then goes back"
            + " to the clock. A confirmation that the keypress worked —"
            + " the full transport lives in the split and the control"
            + " centre, and this is not a second copy of it."
        checked: Config.island.mediaFlash
        onToggled: function(v) { Config.island.mediaFlash = v }
    }

    SliderRow {
        configKey: "island.mediaFlashDuration"
        advanced: true
        shown: Config.island.mediaFlash
        label: "Hold for"
        description: "How long the title stays up. A title is a phrase"
            + " that has to be read rather than recognised, so it"
            + " wants longer than a glance."
        from: 800; to: 6000; stepSize: 100; suffix: " ms"
        value: Config.island.mediaFlashDuration
        onMoved: function(v) { Config.island.mediaFlashDuration = v }
    }

    SliderRow {
        configKey: "island.mediaMaxWidth"
        advanced: true
        shown: Config.island.mediaFlash
        label: "Widen to at most"
        description: "The pill grows this far to fit a title and no"
            + " further; anything longer loses its tail. The width is"
            + " sampled, not measured from the track, so the pill does"
            + " not change size from one song to the next."
        from: 160; to: 480; stepSize: 10; suffix: " px"
        value: Config.island.mediaMaxWidth
        onMoved: function(v) { Config.island.mediaMaxWidth = v }
    }
    }

    SectionHeader { text: "Shape" }

    Card {
    ToggleRow {
        configKey: "island.splitEnabled"
        label: "Split on press and hold"
        description: "Parts the island into two lobes either side of the"
            + " camera housing — the gesture the iPhone's is known for."
            + " A media state: with nothing playing there is nothing to"
            + " part around, so a hold does nothing and a click still"
            + " opens the control centre."
        checked: Config.island.splitEnabled
        onToggled: function(v) { Config.island.splitEnabled = v }
    }

    SliderRow {
        configKey: "island.splitHold"
        advanced: true
        shown: Config.island.splitEnabled
        label: "Hold for"
        description: "How long the island is held before it parts. Under"
            + " about 400ms it stops feeling like a hold and starts"
            + " stealing the click."
        from: 200; to: 1200; stepSize: 20; suffix: " ms"
        value: Config.island.splitHold
        onMoved: function(v) { Config.island.splitHold = v }
    }

    SliderRow {
        configKey: "island.splitLobe"
        advanced: true
        shown: Config.island.splitEnabled
        label: "Lobe width"
        from: 34; to: 90; stepSize: 2; suffix: " px"
        value: Config.island.splitLobe
        onMoved: function(v) { Config.island.splitLobe = v }
    }

    SliderRow {
        configKey: "island.splitGap"
        advanced: true
        shown: Config.island.splitEnabled
        label: "Housing width"
        description: "The bar between the lobes. It is also shorter than"
            + " they are, and that is what makes the island read as"
            + " split rather than as one wide bar."
        from: 0; to: 60; stepSize: 2; suffix: " px"
        value: Config.island.splitGap
        onMoved: function(v) { Config.island.splitGap = v }
    }

    ChoiceRow {
        configKey: "appearance.islandBlack"
        label: "Fill"
        description: "Black is the iPhone's answer, and it is a large part"
            + " of why the island reads as a hole cut in the screen"
            + " rather than a frosted panel sitting on it. The palette"
            + " samples the wallpaper's own darkest surface instead."
        current: Config.appearance.islandBlack
        options: [
            { value: true,  label: "Black" },
            { value: false, label: "Palette" }
        ]
        onSelected: function(v) { Config.appearance.islandBlack = v }
    }

    SliderRow {
        configKey: "appearance.islandShadow"
        label: "Shadow"
        description: "How far the shape is lifted off the wallpaper."
            + " Hyprland cannot shadow a layer surface, so the island"
            + " casts its own. Zero turns it off entirely."
        from: 0; to: 1; stepSize: 0.05; decimals: 2
        value: Config.appearance.islandShadow
        onMoved: function(v) { Config.appearance.islandShadow = v }
    }

    ToggleRow {
        configKey: "appearance.islandEdge"
        label: "Hairline edge"
        description: "A ring around the island, and a second one two"
            + " pixels inside it. It gives a black shape a readable size"
            + " and it is the most conspicuous thing here that is not on"
            + " an iPhone."
        checked: Config.appearance.islandEdge
        onToggled: function(v) { Config.appearance.islandEdge = v }
    }

    SliderRow {
        configKey: "island.radius"
        label: "Corner radius"
        description: "The panel's corner. The resting pill ignores this"
            + " and is a capsule — a pill's ends are semicircles — and"
            + " the radius opens up out of that as the shape grows."
        from: 0; to: 24; stepSize: 1; suffix: " px"
        value: Config.island.radius
        onMoved: function(v) { Config.island.radius = v }
    }

    SliderRow {
        configKey: "island.opacity"
        label: "Opacity"
        description: "Below 1.0 the wallpaper shows through, blurred."
            + " Palette fill only — a black island is opaque whatever"
            + " this says."
        from: 0.5; to: 1.0; stepSize: 0.02; decimals: 2
        value: Config.island.opacity
        onMoved: function(v) { Config.island.opacity = v }
    }

    SliderRow {
        configKey: "island.popupOpacity"
        label: "Popup opacity"
        description: "The OSD and notifications, which arrive over what you"
            + " were looking at rather than because you asked. Lower than"
            + " the island so the blur behind them actually shows."
            + " Palette fill only, for the same reason."
        from: 0.3; to: 1.0; stepSize: 0.02; decimals: 2
        value: Config.island.popupOpacity
        onMoved: function(v) { Config.island.popupOpacity = v }
    }

    SliderRow {
        configKey: "island.padding"
        advanced: true
        label: "Padding"
        description: "Space inside the pill."
        from: 8; to: 40; stepSize: 1; suffix: " px"
        value: Config.island.padding
        onMoved: function(v) { Config.island.padding = v }
    }
    }

    SectionHeader { text: "Clock" }

    Card {
    ChoiceRow {
        configKey: "island.clock24h"
        label: "Hour format"
        description: "The pill, the lock screen and the control centre's"
            + " clock card all follow this, because Clock.qml owns the"
            + " format and nothing else draws a time."
        current: Config.island.clock24h
        options: [
            { value: true,  label: "24-hour" },
            { value: false, label: "12-hour" }
        ]
        onSelected: function(v) { Config.island.clock24h = v }
    }

    ToggleRow {
        configKey: "island.weekStrip"
        label: "Week under the clock"
        description: "Five days either side of today, today spelled out"
            + " and in the accent. The pill grows a second line for it"
            + " and the pods stay their circles."
        checked: Config.island.weekStrip
        onToggled: function(v) { Config.island.weekStrip = v }
    }

    SliderRow {
        configKey: "island.fontSize"
        advanced: true
        label: "Font size"
        from: 9; to: 20; stepSize: 1; suffix: " px"
        value: Config.island.fontSize
        onMoved: function(v) { Config.island.fontSize = v }
    }
    }

    Disclosure {
        width: parent.width
        advanced: true
        text: "Geometry"
        hint: "widths and margins"

        Card {
        SliderRow {
            configKey: "island.topMargin"
            label: "Top margin"
            description: "Above the pill — and, in Always, the first half"
                + " of what every window gives up."
            from: 0; to: 40; stepSize: 1; suffix: " px"
            value: Config.island.topMargin
            onMoved: function(v) { Config.island.topMargin = v }
        }

        SliderRow {
            configKey: "island.idleHeight"
            label: "Island height"
            description: "At rest. The other half: in Always the strip"
                + " reserved is this plus the top margin, and nothing"
                + " else moves it."
            from: 24; to: 56; stepSize: 1; suffix: " px"
            value: Config.island.idleHeight
            onMoved: function(v) { Config.island.idleHeight = v }
        }

        SliderRow {
            configKey: "island.podGap"
            label: "Pod gap"
            description: "Space between a pod and the pill."
            from: 0; to: 24; stepSize: 1; suffix: " px"
            value: Config.island.podGap
            onMoved: function(v) { Config.island.podGap = v }
        }

        SliderRow {
            configKey: "island.idleWidth"
            label: "Minimum width"
            description: "A floor, not the width. The pill is the clock"
                + " and the transport plus the padding either side, and"
                + " this only matters if that comes out narrower — raise"
                + " it to make the island wider on purpose."
            from: 60; to: 240; stepSize: 2; suffix: " px"
            value: Config.island.idleWidth
            onMoved: function(v) { Config.island.idleWidth = v }
        }

        SliderRow {
            configKey: "island.searchWidth"
            label: "Launcher width"
            from: 380; to: 900; stepSize: 10; suffix: " px"
            value: Config.island.searchWidth
            onMoved: function(v) { Config.island.searchWidth = v }
        }

        SliderRow {
            configKey: "island.searchMaxRows"
            label: "Launcher results"
            description: "How many matches it grows to show."
            from: 3; to: 14; stepSize: 1
            value: Config.island.searchMaxRows
            onMoved: function(v) { Config.island.searchMaxRows = v }
        }

        SliderRow {
            configKey: "island.clipMaxRows"
            label: "Clipboard rows"
            from: 3; to: 16; stepSize: 1
            value: Config.island.clipMaxRows
            onMoved: function(v) { Config.island.clipMaxRows = v }
        }
        }

    }

    Disclosure {
        width: parent.width
        advanced: true
        text: "Timing"
        hint: "hover, collapse, notifications"

        Card {
        SliderRow {
            configKey: "island.hoverGrace"
            label: "Hover grace"
            description: "How long it stays out after the cursor leaves."
            from: 0; to: 1200; stepSize: 50; suffix: " ms"
            value: Config.island.hoverGrace
            onMoved: function(v) { Config.island.hoverGrace = v }
        }

        SliderRow {
            configKey: "island.collapseDelay"
            label: "Collapse delay"
            description: "0 keeps the control centre open until you click"
                + " again."
            from: 0; to: 2000; stepSize: 50; suffix: " ms"
            value: Config.island.collapseDelay
            onMoved: function(v) { Config.island.collapseDelay = v }
        }

        SliderRow {
            configKey: "island.revealZone"
            label: "Reveal zone"
            description: "The strip at the top edge that brings it back."
            from: 4; to: 40; stepSize: 1; suffix: " px"
            value: Config.island.revealZone
            onMoved: function(v) { Config.island.revealZone = v }
        }

        SliderRow {
            configKey: "island.notifyDuration"
            label: "Notification time"
            from: 1000; to: 15000; stepSize: 500; suffix: " ms"
            value: Config.island.notifyDuration
            onMoved: function(v) { Config.island.notifyDuration = v }
        }
        }

    }

    Disclosure {
        width: parent.width
        text: "Media"
        hint: "2 settings"

        Card {
        ToggleRow {
            configKey: "island.expandOnTrackChange"
            label: "Expand on track change"
            description: "Briefly open the island when a new song starts."
            checked: Config.island.expandOnTrackChange
            onToggled: function(v) { Config.island.expandOnTrackChange = v }
        }

        SliderRow {
            configKey: "island.attentionDuration"
            label: "Attention duration"
            from: 500; to: 6000; stepSize: 250; suffix: " ms"
            value: Config.island.attentionDuration
            onMoved: function(v) { Config.island.attentionDuration = v }
        }
        }
    }

    SectionHeader { text: "Motion" }

    Card {
        ChoiceRow {
            label: "Tempo"
            // Twelve numbers, three answers — Apple's three, because the
            // bounce in each is Apple's figure for it. Tempo writes all
            // twelve; the rows below are the ones you can feel without a
            // stopwatch, and the rest are settings.json only. Moving any
            // of them puts this row on "Custom", which is how you can
            // tell from here that one has been moved.
            description: "Apple's three springs. Snappy is the shipped one;"
                + " smooth takes the overshoot out and bouncy spends more of it."
            current: Motion.tempo
            options: Motion.tempo === "custom"
                ? [{ value: "smooth", label: "Smooth" },
                   { value: "snappy", label: "Snappy" },
                   { value: "bouncy", label: "Bouncy" },
                   { value: "custom", label: "Custom" }]
                : [{ value: "smooth", label: "Smooth" },
                   { value: "snappy", label: "Snappy" },
                   { value: "bouncy", label: "Bouncy" }]
            // "custom" is not a tempo you can pick, only one you can be
            // in, so setTempo ignores it rather than this having to.
            onSelected: function(v) { Motion.setTempo(v) }
        }

        ToggleRow {
            configKey: "motion.reduceMotion"
            label: "Reduce motion"
            description: "Drops the springs and the morphs, keeps the cross-fades."
            checked: Config.motion.reduceMotion
            onToggled: function(v) { Config.motion.reduceMotion = v }
        }

        SliderRow {
            configKey: "motion.expandResponse"
            advanced: true
            label: "Open"
            description: "The spring's period, which reads as its speed."
                + " Not a duration: the shape is where you are looking"
                + " well before it stops."
            from: 120; to: 700; stepSize: 10; suffix: " ms"
            value: Config.motion.expandResponse
            onMoved: function(v) { Config.motion.expandResponse = v }
        }

        SliderRow {
            configKey: "motion.collapseResponse"
            advanced: true
            label: "Close"
            description: "Shorter than opening, the way a dismissal is."
            from: 100; to: 500; stepSize: 10; suffix: " ms"
            value: Config.motion.collapseResponse
            onMoved: function(v) { Config.motion.collapseResponse = v }
        }

        SliderRow {
            configKey: "motion.arriveBounce"
            advanced: true
            label: "Bounce"
            description: "One minus the damping fraction, as Apple counts it."
                + " 0 settles without overshoot, 0.15 is a lift you feel,"
                + " 0.3 is one you watch."
            from: 0; to: 0.5; stepSize: 0.05; decimals: 2
            value: Config.motion.arriveBounce
            onMoved: function(v) { Config.motion.arriveBounce = v }
        }

        SliderRow {
            configKey: "motion.emergeScale"
            advanced: true
            label: "Emerge from"
            description: "How small a surface starts before it grows into"
                + " place. 1.0 is a plain cross-fade."
            from: 0.85; to: 1.0; stepSize: 0.01; decimals: 2
            value: Config.motion.emergeScale
            onMoved: function(v) { Config.motion.emergeScale = v }
        }
    }
}
