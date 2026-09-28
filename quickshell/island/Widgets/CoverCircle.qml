import QtQuick

// A remote image, cropped to a circle.
//
// **Why a `Canvas` and not a `Shape`.** The obvious way to draw a round
// picture is `QtQuick.Shapes` with an `ImageFill`, and it is forbidden in
// this shell: a `Shape` anywhere in the island's window turns that
// window's whole bounding rectangle opaque in the Wayland buffer, and
// `hypr/rules.lua` blurs `island-bar` unconditionally, so Hyprland dims
// a dark square behind the shape. Four fixes were measured and none
// help — `GeometryRenderer`, `layer.enabled` on the Shape, a higher
// `ignore_alpha`, and the Shape offscreen as a `visible: false` layer
// source composited by a `MultiEffect`. See `docs/NOTES.md`.
//
// The other two roads out are closed too. `clip: true` clips to the
// item's *bounding rectangle*, never to its shape, so an `Image` inside
// a round pod keeps all four of its corners — which is the bug this
// exists to fix. And a masking `ShaderEffect` needs a baked `.qsb` from
// `qsb`, which ships in qt6-shadertools-dev and is not a thing to
// assume; the squircle shader draws solid fills and cannot be reused.
//
// A `Canvas` rasterises with QPainter into its own texture and adds no
// `Shape` node, so alpha survives — which is why
// `packages/qml-squircle` ships one as its no-binary fallback. This is
// the same technique on a smaller job.
//
// **Why an `Image` feeds it, rather than a second loader canvas.** This
// file used to hold two canvases: one whose only job was
// `Canvas.loadImage`, never shown, and a second that painted by handing
// the first to `ctx.drawImage`. It never drew anything, in either
// direction of the argument:
//
//   - `drawImage(aCanvas)` paints *that canvas's own painted content*,
//     not the picture it happens to have loaded. The loader had no
//     `onPaint`, so it was blank, and the artwork was never there. The
//     measured result is a flat backdrop every time.
//   - The readiness test read `isImageLoaded` / `isImageError` as
//     *properties*. They are `Q_INVOKABLE` methods taking the url, so
//     reading them yields the function object — truthy however the
//     answer came back — and `ready` was false forever. That is why the
//     pod fell back to the player's app icon instead of the cover, and
//     why the log carried `Error: Insufficient arguments` from the
//     matching `unloadImage()` call, which wants a url too.
//
// A plain `Image` is the honest version of that loader: its `status` is
// a real, documented readiness signal, it downloads asynchronously off
// the UI thread, and `ctx.drawImage` accepts an `Image` element
// directly — measured, artwork and all. One item, one download, no
// polling, and no timeout to give up after: a slow CDN is slow, not
// broken.
//
// The cost is a repaint per track, at `size` square — 72px here, which
// is a texture upload so small it is not worth measuring.

Canvas {
    id: root

    // Where to load from. Setting it to "" releases the old image.
    property url source: ""

    // The colour behind the circle, which the canvas fills its own bounds
    // with. **This is not decoration — it is the mask.**
    //
    // A `Canvas` with a `FramebufferObject` composites its cleared pixels
    // as *opaque*, not transparent, whichever render strategy it uses
    // (both `Cooperative` and `Immediate` were measured). So the obvious
    // mask — clip the picture to a circle and let the rest be see-through
    // — cannot work: the 28px canvas painted a 28px black square with a
    // round cover in the middle of it, inside the pod's own circle, so
    // the clip succeeded and the clip's own frame undid it. The dark
    // region measured 28x28 where the pod's circle is 32x32.
    //
    // Filling instead of clearing makes the square the same colour as
    // whatever it sits on, so it stops being a square and becomes part of
    // the surface. Given the pod's own fill that is invisible, and the
    // gap between this canvas and the pod's edge still reads as the
    // frame.
    //
    // It also means the fill has to be the *real* fill, alpha and all,
    // rather than a flat black: a translucent island would show a black
    // square on a see-through pod, which is worse than the bug this
    // replaces. Hence taking it from `Pod.fill` rather than hardcoding.
    property color backdrop: "transparent"

    // True while the canvas is holding a picture, which is the only
    // thing a caller can act on: it falls back to an icon or a glyph
    // when this is false, because an empty circle and a failed load look
    // identical otherwise.
    //
    // **Sticky, and deliberately not `art.status`.** That status drops
    // back to `Loading` the moment a new track's url arrives, so reading
    // it would blank the cover for the length of every download — one
    // app-icon flash per track, which is a worse thing to look at than
    // the picture already in the circle. The canvas keeps the pixels it
    // last painted, so this stays true and the outgoing cover holds the
    // circle until the incoming one replaces it in a single repaint.
    // Only a url that arrives *without* a picture — an error, or a
    // player going quiet and clearing `artUrl` — takes it back down.
    property bool ready: false

    implicitWidth: 72
    implicitHeight: 72

    // The picture. Never shown on its own — it exists to be something
    // `drawImage` accepts, and `visible: false` keeps it off the compositor
    // entirely while the canvas does the drawing.
    //
    // Asynchronous, so a cover crossing the network never blocks a frame.
    // `sourceSize` unset deliberately: `drawImage` is asked for the
    // natural size below so the cover-fit can be measured, and the decode
    // is of album art (640px square), not a 3000px desktop icon.
    Image {
        id: art
        source: root.source
        asynchronous: true
        visible: false
        cache: true

        // Arrival and failure repaint; **`Loading` deliberately does
        // not** — see `ready` above. `art` drops the picture it was
        // holding as soon as `source` moves, but this canvas has its own
        // copy of the pixels, and repainting here would trade the last
        // cover for a bare disc for the whole of the download.
        onStatusChanged: {
            if (status === Image.Ready) {
                root.ready = true;
                painter.requestPaint();
            } else if (status === Image.Error || status === Image.Null) {
                // A url that will never arrive: back down to nothing, so
                // the caller's icon or glyph takes the circle over.
                root.ready = false;
                painter.requestPaint();
            }
        }
    }

    Canvas {
        id: painter
        anchors.fill: parent
        renderTarget: Canvas.FramebufferObject
        // `Cooperative`, the default, so the repaint is a texture upload
        // on the next frame rather than a synchronous raster. Once per
        // track at `size` square, which is nothing.
        renderStrategy: Canvas.Cooperative

        // A canvas paints once when it is created and never again unless
        // asked, and three things can change what it should show after
        // that: the picture arriving, the item being resized, and the item
        // becoming visible (the caller hides it until `ready`). All three
        // ask.
        onVisibleChanged: if (visible) requestPaint()
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()

        onPaint: {
            const ctx = getContext("2d");

            // A canvas paints the moment it is created, which is before
            // the pod has laid it out: `width` is still whatever the
            // binding resolved to with a `parent.width` of 0, and an arc
            // of radius 0 is an argument the context refuses outright.
            // `onWidthChanged` repaints when the real size lands.
            if (width < 1 || height < 1) return;

            ctx.reset();

            // Fill, not clear. See `backdrop` for why clearing does not
            // work here at all.
            ctx.fillStyle = root.backdrop;
            ctx.fillRect(0, 0, width, height);

            if (art.status !== Image.Ready) return;

            const iw = art.implicitWidth;
            const ih = art.implicitHeight;
            if (iw <= 0 || ih <= 0) return;

            // The circle. A clip rather than a stroke, so the edge is the
            // arc and not half a line lying on top of the picture.
            ctx.save();
            ctx.beginPath();
            ctx.arc(width / 2, height / 2, Math.min(width, height) / 2, 0, Math.PI * 2);
            ctx.closePath();
            ctx.clip();

            // Cover-fit: fill the circle and crop the overflow, which is
            // what artwork wants. Fitting would letterbox a square cover
            // into visible bands, which inside a circle reads as the
            // picture floating rather than filling it.
            const scale = Math.max(width / iw, height / ih);
            const dw = iw * scale;
            const dh = ih * scale;
            ctx.drawImage(art, (width - dw) / 2, (height - dh) / 2, dw, dh);

            ctx.restore();
        }
    }
}
