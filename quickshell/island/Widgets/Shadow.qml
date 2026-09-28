import QtQuick

import "root:/Services"

// A soft shadow cast by a shape onto whatever is behind it.
//
//     Squircle { anchors.fill: parent; ... }
//     Shadow   { shape: thatSquircle; spread: 10; strength: 0.55 }
//
// Draw it BEFORE the shape, as a sibling — it is not a child of the
// thing it belongs to, and it is not an effect on it.
//
// Why the shell needs one at all: Hyprland cannot give it. A
// layer-shell surface is composited by the compositor and gets no
// decoration, so `decoration.shadow` — which is the shadow on every
// window on the desktop — does not reach the island. And the island is
// the one shape that most needs it: a soft shadow under a surface is
// most of what tells you it is sitting *above* the screen rather than
// drawn on it, which is the whole difference between the iPhone's
// island and a rounded rectangle.
//
// It is a stack of concentric rings rather than a blur, and that is
// not a compromise:
//
//   - `MultiEffect` would be the obvious route and cannot be used. See
//     docs/NOTES.md: a render target in this layer's window is what
//     made Hyprland dim an opaque rectangle behind every rounded
//     surface, and four workarounds for it are recorded there as
//     having failed. A shadow is not worth a second trip through that
//     argument.
//
//   - A blur of the shape's own alpha is not available either:
//     Squircle is a ShaderEffect writing premultiplied colour straight
//     into the scene graph, and there is no cheap readback of just
//     its coverage to convolve.
//
// So: N rings, each one drawn as a border of the shape outset by a
// little more than the last, each fainter. The bands are disjoint —
// ring i covers the annulus from i*step out to (i-1)*step — so they
// composite as a gradient rather than accumulating into a wall, and
// the falloff is a power curve because a linear one reads as a stack
// of rings if you look for it.
//
// The one thing that does need care is concentricity: a ring drawn at
// the same radius as the shape has a gap down the straights and
// pad * 1.41 through the corner, which on a soft edge is visible as
// the shadow being the wrong shape. Hence Theme.outer, the mirror of
// the Theme.inner rule the Bezel uses.

Item {
    id: root

    // The shape whose corner this follows. `radius` is read off it, so
    // the shadow cannot drift from the thing casting it — the same
    // reason Bezel takes `outer` passed in rather than reading
    // `parent.radius`.
    property Item shape: null

    // How far the shadow reaches, in px. Ten is what the iPhone's is:
    // this is a contact shadow, not a drop, and the point is the dark
    // edge where it meets the shape.
    property real spread: 10

    // 0 to 1. Multiplied into the innermost ring, which is the
    // darkest; the rest fall away from it.
    property real strength: Theme.islandShadow

    // How many bands the falloff is cut into. Five at a 10px spread is
    // a 2px step, which is below what a 60Hz frame can show moving and
    // above what leaves a gap. More is smoother and costs a quad each.
    property int rings: 5

    // The falloff's shape. 2.2 is a touch darker at the contact than
    // the quadratic it replaces, which is what stops the shadow
    // looking detached from the shape at the setting that ships.
    property real falloff: 2.2

    // True while there is anything to draw. Off means nothing is
    // instantiated, so a shadow set to zero costs nothing rather than
    // costing a transparent stack.
    readonly property bool casting: shape !== null && strength > 0.001

    // The geometry is the caller's, not `parent`'s. Every use wants it
    // to match the thing casting rather than whatever this happens to
    // be a child of, and for the pill that is the same thing only
    // because the island item is sized from it:
    //
    //     Shadow { shape: pill;  anchors.fill: pill  }
    //     Shadow { shape: shelf; anchors.fill: shelf }
    //
    // Not filled from `parent` on purpose, then. Anchoring to a
    // sibling is ordinary and this is the one case where a parent-
    // relative default would have been right by coincidence and wrong
    // the moment the shelf moved out from under the pill.
    //
    // The rings themselves reach `spread` outside that, which is fine:
    // nothing here clips, the panel window's implicitHeight leaves 60px
    // of slack under the tallest mode, and the shadow's own pixels are
    // outside the island's input Region so they are click-through —
    // which is right, since a shadow is not something you point at.
    visible: casting

    Repeater {
        model: root.casting ? root.rings : 0

        Squircle {
            // Declared rather than assumed — see the same note in
            // Island/Modes/IdleMode.qml. `index` is the only thing
            // standing between this delegate and a NaN border.
            required property int index

            readonly property real step: root.spread / root.rings
            readonly property real outset: (index + 1) * step
            readonly property real fall:
                Math.pow(1 - index / root.rings, root.falloff)

            smoothing: Config.appearance.cornerSmoothing

            // The rule is the mirror of Theme.inner: outward by the
            // same pad the shape is outset by. See the note at the top
            // of the file — a ring at the shape's own radius is the
            // wrong shape through the corner.
            anchors.margins: -outset
            radius: root.shape ? Theme.outer(root.shape.radius, outset) : 0

            // A ring and nothing else. The shader clips the fill to
            // the inside of the border, so a transparent fill is
            // genuinely absent rather than a transparent wash over
            // every pixel underneath.
            color: "transparent"
            borderWidth: step
            borderColor: Qt.rgba(0, 0, 0, root.strength * fall * 0.5)
        }
    }
}
