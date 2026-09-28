import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick

import "root:/Services"
import "root:/Widgets"
import "root:/Settings/Pages"

PanelWindow {
    id: root

    property bool open: false

    // Theme colours are hex strings with no alpha. This re-emits one
    // with the alpha we want, so Hyprland's blur rule has something
    // translucent to blur through.
    function tint(c, a) {
        const col = Qt.color(c);
        return Qt.rgba(col.r, col.g, col.b, a);
    }

    // One settings window, on the monitor Hyprland considers focused
    // rather than whichever screen happens to be first in the list.
    screen: Screens.active

    visible: open

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "island-settings"

    // Needed for Escape to close and for typing in the search
    // field. OnDemand rather than Exclusive: this window is an app,
    // not a mode — clicking past it to the desktop must leave the
    // keyboard where it was, and only a click inside (the search
    // field, a dropdown) routes keys here.
    WlrLayershell.keyboardFocus: open
        ? WlrKeyboardFocus.OnDemand
        : WlrKeyboardFocus.None

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    color: "transparent"

    // Only the window itself takes input. The layer surface is
    // fullscreen and transparent, and without this every click
    // outside the panel would land on it instead of the desktop
    // behind it — a settings app you cannot click past is a mode,
    // and this one is not. `null` when shut, for the island's
    // reason: a region with nothing behind it is a dead rectangle.
    mask: Region {
        item: root.open ? panel : null
    }

    // One window, not two panels with a gap. The sidebar is
    // navigation and the pane is content, and a single surface with
    // a divider between them says exactly that — the gap used to
    // show the dimmed wallpaper through it, which reads as two
    // windows that happen to be near each other.
    Item {
        id: panel

        focus: root.open
        Keys.onEscapePressed: root.open = false

        anchors.centerIn: parent
        width: 990
        height: 680

        opacity: root.open ? 1 : 0
        scale: emerge.value

        // The island's own motion, so this window arrives the way
        // everything else does — a spring on the shape, an easing on
        // the fade. Reversing it halfway, which is what shutting a
        // window you only just opened is, carries the velocity
        // through instead of restarting. See Services/Motion.qml.
        readonly property int springResponse:
            root.open ? Motion.expandResponse : Motion.collapseResponse
        readonly property real springBounce:
            root.open ? Motion.arriveBounce : Motion.departBounce

        Spring {
            id: emerge
            shape: panel
            target: root.open ? 1 : Motion.emergeScale
        }

        Behavior on opacity {
            NumberAnimation {
                duration: root.open ? Motion.contentIn : Motion.contentOut
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Motion.ease
            }
        }

        // The window's own surface and edge, drawn once behind both
        // halves. Without the scrim there is no dim to lift it off
        // the desktop, so it casts its own shadow instead.
        Shadow { shape: panelBg; anchors.fill: panelBg; spread: 18 }

        Squircle {
            id: panelBg
            smoothing: Config.appearance.cornerSmoothing
            anchors.fill: parent
            radius: Theme.radiusNormal
            color: root.tint(Theme.surface, Config.appearance.panelOpacity)
            borderWidth: 1
            borderColor: root.tint(Theme.outline, 0.30)
        }

        // The island's second line — see Widgets/Bezel.qml. The
        // settings window is the largest rounded thing the shell
        // draws and so the one with the most corner to read, and
        // it was the only panel still drawn with a single stroke.
        // Two shells' worth of edge treatment is one shell too
        // many.
        Bezel { outer: Theme.radiusNormal }

        // Navigation ends here and content begins. Inset past the
        // outer corner's curve, so the line never touches the edge
        // it would visibly jar against.
        Rectangle {
            x: sidebar.width
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.topMargin: 16
            anchors.bottomMargin: 16
            width: 1
            color: Qt.rgba(1, 1, 1, 0.08)
        }

        Item {
            id: sidebar
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: 230

            Column {
                anchors.fill: parent
                anchors.margins: 14
                spacing: 4

                // Narrows the list below without leaving the page you
                // are on. Typing here never navigates by itself — the
                // window owns exclusive keyboard focus, so Escape still
                // closes it from anywhere, including this field.
                Rectangle {
                    width: sidebar.width - 28
                    height: 36
                    radius: Theme.radiusLarge
                    color: Theme.surfaceLow
                    border.width: 1
                    border.color: searchInput.activeFocus
                        ? Theme.primary : Theme.outlineVariant

                    Behavior on border.color {
                        ColorAnimation { duration: Motion.fadeIn }
                    }

                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: 34
                        anchors.verticalCenter: parent.verticalCenter
                        text: Icons.search
                        color: Theme.textDim
                        font.family: Theme.fontIcons
                        font.pixelSize: 13
                        renderType: Text.NativeRendering
                    }

                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: 56
                        anchors.right: parent.right
                        anchors.rightMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        visible: searchInput.text === ""
                        text: "Search Settings"
                        color: Theme.outline
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeSmall
                        elide: Text.ElideRight
                        renderType: Text.NativeRendering
                    }

                    TextInput {
                        id: searchInput
                        anchors.left: parent.left
                        anchors.leftMargin: 56
                        anchors.right: parent.right
                        anchors.rightMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.filter
                        onTextChanged: root.filter = text
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeSmall
                        renderType: Text.NativeRendering
                        cursorVisible: activeFocus
                    }
                }

                Item { width: 1; height: 8 }

                Repeater {
                    // Wallpaper and the theming half of Appearance
                    // are one subject and are now one page; Motion was
                    // five sliders about the island and lives under
                    // it; Session and the compositor half of
                    // Appearance are both "the system".
                    model: root.pages.filter(function(p) {
                        const q = root.filter.trim().toLowerCase();
                        return q === ""
                            || p.label.toLowerCase().indexOf(q) >= 0;
                    })

                    Rectangle {
                        required property var modelData
                        readonly property bool active: modelData.id === root.page

                        width: sidebar.width - 28
                        height: 40
                        radius: Theme.radiusLarge
                        color: active
                            ? Theme.surfaceHigh
                            : (navHover.containsMouse ? Theme.surfaceLow
                              : Theme.fade(Theme.surfaceLow))

                        Behavior on color { ColorAnimation { duration: Motion.fadeIn } }

                        // The icon in its own circle, so the glyph
                        // never sits on the row's edge: active pages
                        // wear the accent washed out, the rest a dim
                        // glyph on the row itself.
                        Rectangle {
                            id: navBadge
                            anchors.left: parent.left
                            anchors.leftMargin: 7
                            anchors.verticalCenter: parent.verticalCenter
                            width: 26
                            height: 26
                            radius: width / 2
                            color: parent.active
                                ? root.tint(Theme.primary, 0.16)
                                : Theme.fade(Theme.surfaceHigh)

                            Text {
                                anchors.centerIn: parent
                                text: parent.parent.modelData.glyph
                                color: parent.parent.active
                                    ? Theme.primary : Theme.textDim
                                font.family: Theme.fontIcons
                                font.pixelSize: 13
                                renderType: Text.NativeRendering

                                Behavior on color {
                                    ColorAnimation { duration: Motion.fadeIn }
                                }
                            }
                        }

                        Text {
                            anchors.left: navBadge.right
                            anchors.leftMargin: 10
                            anchors.right: parent.right
                            anchors.rightMargin: 10
                            anchors.verticalCenter: parent.verticalCenter
                            text: parent.modelData.label
                            color: parent.active ? Theme.text : Theme.textDim
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeNormal
                            font.weight: parent.active ? Font.Bold : Font.Medium
                            elide: Text.ElideRight
                            renderType: Text.NativeRendering

                            Behavior on color {
                                ColorAnimation { duration: Motion.fadeIn }
                            }
                        }

                        MouseArea {
                            id: navHover
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.page = parent.modelData.id;
                                root.filter = "";
                                searchInput.text = "";
                            }
                        }
                    }
                }
            }
        }

        Item {
            id: pane
            anchors.left: sidebar.right
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom
        }

        // The switch that decides how much of a page there is.
        //
        // In the pane's corner rather than at the foot of every page:
        // it is not a setting about the shell, it is how much of the
        // settings you want to be looking at, and the answer has to be
        // reachable without scrolling to the end of the thing it
        // shortens.
        Item {
            id: paneHead
            anchors.left: pane.left
            anchors.right: pane.right
            anchors.top: pane.top
            anchors.leftMargin: 26
            anchors.rightMargin: 26
            anchors.topMargin: 16
            height: 26

            // The window dismisses itself — there is no scrim to
            // click past any more, so the corner holds the way out
            // instead. Beside Advanced rather than above the page,
            // where a second pill would compete with it.
            Rectangle {
                anchors.right: advanced.left
                anchors.rightMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                width: 26
                height: 26
                radius: height / 2
                color: closeHover.containsMouse ? Theme.surfaceHigh
                                                : Theme.fade(Theme.surfaceHigh)
                border.width: 1
                border.color: Theme.outlineVariant

                Behavior on color { ColorAnimation { duration: Motion.fadeIn } }

                Text {
                    anchors.centerIn: parent
                    text: "×"
                    color: closeHover.containsMouse ? Theme.text : Theme.textDim
                    font.family: Theme.fontFamily
                    font.pixelSize: 14
                    renderType: Text.NativeRendering

                    Behavior on color { ColorAnimation { duration: Motion.fadeIn } }
                }

                MouseArea {
                    id: closeHover
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.open = false
                }
            }

            Rectangle {
                id: advanced
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter

                width: advLabel.implicitWidth + 35
                height: parent.height
                radius: height / 2

                color: Config.ui.advanced ? Theme.primary
                    : (advHover.containsMouse ? Theme.surfaceHigh
                                              : Theme.fade(Theme.surfaceHigh))
                border.width: 1
                border.color: Config.ui.advanced
                    ? Theme.primary : Theme.outlineVariant

                Behavior on color { ColorAnimation { duration: Motion.fadeIn } }
                Behavior on border.color {
                    ColorAnimation { duration: Motion.fadeIn }
                }

                Rectangle {
                    id: advDot
                    anchors.left: parent.left
                    anchors.leftMargin: 9
                    anchors.verticalCenter: parent.verticalCenter
                    width: 6
                    height: 6
                    radius: width / 2
                    color: Config.ui.advanced ? Theme.textOnPrimary
                                              : Theme.outline

                    Behavior on color { ColorAnimation { duration: Motion.fadeIn } }
                }

                Text {
                    id: advLabel
                    anchors.left: advDot.right
                    anchors.leftMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Advanced"
                    color: Config.ui.advanced ? Theme.textOnPrimary
                                              : Theme.textDim
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSmall
                    font.weight: Font.DemiBold
                    font.letterSpacing: 0.4
                    renderType: Text.NativeRendering

                    Behavior on color { ColorAnimation { duration: Motion.fadeIn } }
                }

                MouseArea {
                    id: advHover
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Config.ui.advanced = !Config.ui.advanced
                }
            }
        }

        Flickable {
            id: scroll
            anchors.left: pane.left
            anchors.right: pane.right
            anchors.bottom: pane.bottom
            anchors.top: paneHead.bottom
            anchors.leftMargin: 26
            anchors.rightMargin: 26
            anchors.bottomMargin: 26
            anchors.topMargin: 10

            contentWidth: width
            contentHeight: loader.item ? loader.item.implicitHeight : 0
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            Loader {
                id: loader
                width: scroll.width
                sourceComponent: {
                    switch (root.page) {
                        case "control": return controlPage;
                        case "appearance": return appearancePage;
                        case "input":   return inputPage;
                        case "system":  return systemPage;
                        case "network": return networkPage;
                        case "apps":    return appsPage;
                        default:        return islandPage;
                    }
                }

                // Fade between pages so switching doesn't snap.
                opacity: 1
                Behavior on opacity {
                    NumberAnimation { duration: Motion.fadeIn }
                }
            }
        }
    }

    readonly property var pages: [
        { id: "island",  label: "Bar & Island",   glyph: Icons.tabIsland },
        { id: "control", label: "Control Center", glyph: Icons.tabControl },
        { id: "appearance", label: "Appearance", glyph: Icons.tabAppearance },
        { id: "input",   label: "Input",   glyph: Icons.tabInput },
        { id: "system",  label: "System",  glyph: Icons.tabSystem },
        { id: "network", label: "Network", glyph: Icons.tabNetwork },
        { id: "apps",    label: "Apps",    glyph: Icons.tabApps }
    ]

    property string page: "island"

    // What the sidebar is filtering on. Empty means everything; the
    // Repeater below reads it, so typing narrows the list without
    // touching the page you are on.
    property string filter: ""

    // Old names still work: they are in muscle memory, in binds, and
    // in anything that scripted `settings page`.
    readonly property var aliases: ({
        theme:      "appearance",
        wallpaper:  "appearance",
        // Windows, gaps, shadows and blur moved off System when the
        // corner radius became one control; anyone who learned either
        // name for them still lands on the page that has them.
        windows:    "appearance",
        blur:       "appearance",
        motion:     "island",
        session:    "system",
        // What the control centre's own settings tile opens, and the
        // name anyone would guess for it.
        centre:     "control",
        tiles:      "control",
        // The page is about defaults, and "default" is what anyone
        // who has met another settings app would type.
        defaults:   "apps",
        handlers:   "apps"
    })

    onPageChanged: {
        // Back to the top. The Flickable outlives the page inside it,
        // so without this, arriving at a page lands you wherever you
        // happened to have scrolled the last one to — and on a short
        // page that is past the end of it, looking at nothing.
        scroll.contentY = 0;
        loader.opacity = 0;
        pageFade.restart();
        // A filter that hid the page you just arrived on would leave
        // the sidebar pointing at nothing, so navigating clears it.
        // Typing never navigates by itself, so this only fires on a
        // real arrival.
        if (root.filter !== "") {
            root.filter = "";
            searchInput.text = "";
        }
    }

    Timer {
        id: pageFade
        interval: 60
        onTriggered: loader.opacity = 1
    }

    Component { id: islandPage;  IslandPage  { width: scroll.width } }
    Component { id: controlPage; ControlPage { width: scroll.width } }
    Component { id: appearancePage; AppearancePage { width: scroll.width } }
    Component { id: inputPage;   InputPage   { width: scroll.width } }
    Component { id: systemPage;  SystemPage  { width: scroll.width } }
    Component { id: networkPage; NetworkPage { width: scroll.width } }
    Component { id: appsPage;    AppsPage    { width: scroll.width } }

    IpcHandler {
        target: "settings"

        function toggle(): void { root.open = !root.open }
        // `show` cannot be reached from the command line: qs's
        // own `ipc show` subcommand swallows the word before it
        // gets as far as the function name, and even `--` does not
        // help. `open` is the same thing under a name the CLI can
        // actually pass. Both are kept — `show` still works for
        // anything talking to the socket directly.
        function open(): void { root.open = true }
        function show(): void { root.open = true }
        function hide(): void { root.open = false }
        function page(name: string): void {
            root.page = root.aliases[name] || name;
            root.open = true;
        }
    }
}
