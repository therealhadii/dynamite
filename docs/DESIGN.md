# How the island is built

The shape, the pods, the panel behind them, and the motion that moves
between. Split out of the README, which is the front door rather than
the drawings.

---

## The island

| Mode | Trigger | Shows |
|:--|:--|:--|
| `idle` | — | the clock; the transport while you point at it |
| `split` | press and hold | the island parts around its housing: the app on the left, the equaliser on the right |
| `expanded` | click | calendar, battery, toggles, sliders, media |
| `search` | `Super+R` | application launcher |
| `clipboard` | `Super+V` | clipboard history |
| `picker` | `Super+Shift+W/T` | wallpapers and palettes, as a grid. `Super+Shift+I` opens Settings instead: an icon theme is picked once and then left, and twenty near-identical folder icons is a list, not a grid |
| `session` | `Super+Shift+Q` | lock, log out, suspend, reboot, shut down |
| `centre` | `Super+N` | notification history |
| `notify` | on arrival | a notification, briefly, at its own height |
| `osd` | media keys | volume, brightness, mic |
| `auth` | on request | polkit authorization |

**At rest the pill holds a clock and nothing else**, and that is the
iPhone's answer as much as it is this one's. The Dynamic Island carries
no content at rest at all — 125pt of black around the camera housing —
and it widens only when something happens. This one cannot be empty,
because a desktop shell with no clock in it has given up the reason it
exists. So the clock stays and everything else goes.

**The clock is white and the accent means "something happened."** It
used to be `Theme.primary`, which made the island at rest the same
colour as the island reacting to a notification, a media key or a
workspace move — and the accent is derived from the wallpaper, so a
clock that changes hue with the desktop is a restless thing to keep in
the one place you look constantly.

The iPhone's island is black and white at rest and spends its colour on
events, and that is the rule here now. White is the resting state; the
accent is the workspace number, the split's lobes, the OSD. A calm
clock that flashes accent-coloured for a moment says two things at
once. A permanently orange clock said neither, because there was no
contrast between resting and reacting to compare it against.

**The tracking is 0.4px, not 1.2.** 1.2px on a 14px clock is 8.6% of
the em, which is a display setting used on a UI size. At that tracking
the colon drifts off its digits and `2:03 PM` reads as four separate
glyphs rather than as a time — obvious at 3x and not quite visible at
1x, which is the worst way for it to be wrong.

Tightening it took 7px off the clock's own footprint, which the pill
does not always pass on: the width is `max(island.idleWidth, content +
padding * 2)`, so whether the shape narrows is down to whether the
floor or the content was the larger term. On a stock `idleWidth` of 88
it was the content and the pill narrowed; raise the floor and the floor
decides, which is what `idleWidth` is for.

The iPhone's resting island is 3.4:1 and holds nothing at all, so it is
a target for the *shape* and not for the type — a pill with a clock in
it wants to be a little shorter than that, and the useful range is
3.0:1 to 3.4:1 depending on how much the user has said they want the
clock to have.

The **date** was the thing that had to go, and it was wrong on three
counts. The iPhone has no date in its island; the date lives on the
lock screen and in the control centre, both of which this shell has.
Ten characters of it beside five of clock is what made the pill 190px
wide, at 5.6:1 where the phone's is 3.4:1. And in a proportional face
it changed width with the day, the weekday and the month, so three
hidden `Text`s existed purely to measure the widest of them and keep
the shape still — a whole mechanism to stop a field that should not
have been on screen.

**The resting width is the content's, and the floor is a safety net.**
`collapsedWidth` is `max(idleWidth, max(clock, transport) + padding)`,
so the pill is built for whichever of its two faces is wider and
`idleWidth` — 88, below the content's 95 — only matters for a narrow
face.

That is not a detail, it is the hover behaviour. The clock and the
transport are two faces of one capsule and they cross-fade, so pointing
at the island cannot change its size — and it cannot, structurally: the
width is a function of four numbers and neither `clockSlot` nor
`transportSlot` reads `hovered`. Sizing the pill to whichever face is
showing would be the same mistake as before in a different place, and it
is worth saying so because the number is *right* in both readings. The
pill would measure 88 hovering and 95 not, and every geometry probe
would agree with itself.

**The width is no longer the iPhone's.** It was 116, which is their
125pt scaled to this 34px height, and that was the wrong thing to copy:
their resting island is *empty*. Put a small clock in a wide empty pill
and it stops reading as a hole in the screen and starts reading as a
clock adrift in a lot of black. Matching their emptiness here would mean
an island with no time in it. So the shape is sized to its contents —
95 x 34, 2.8:1 — and the phone's proportion is not the target.

**`topMargin` is 11**, which is theirs as a proportion: about 11pt above
a 36.7pt island is 0.30, and 11 over 34 is 0.32. At 8 the pill sat
closer to the edge than its own height in proportional terms, which is
what made it look stuck to the top of the screen rather than floating on
it.

The track **title** is absent for the same reason the date is: it is as
long as whoever named the track decided and it changes while you are
not looking. `island.pillTitle` puts it back.

Scrolling the collapsed pill moves one workspace either way. It can be
set to volume, or to nothing, in Settings → Island.

### The launcher

`Super+R`, and it is the one mode that is two surfaces: the pill is the
field, the shelf below it is the results. That is deliberate and it is
the reason the pill's height does not depend on the match count — a
field that grows as you type is a field that moves out from under your
hands, and a shape that moves while you are typing into it has lost the
one thing a field is for.

**The gap between them is 5px, not `podGap`'s 8.** Those two are one
object and the pods are not. At 8, with a shadow under each, the field
and the results read as two unrelated bars with a dark seam between
them — the shadow that is supposed to say "one thing floating above the
screen" was saying the opposite, because there were two of them. At 5
they read as a field and the menu under it.

**Four numbers, all of which were too big.** 560 wide, a 46px field,
40px rows, eight of them, at the small type size. 560 is the control
centre's width applied to a field holding one application name, and at
that width the single result looked like a card floating in a field.
Eight rows of 11px in 40px rows is eight rows of nothing.

It is now 460 wide, a 40px field, 36px rows, six of them, at the body
size — and the row's generic name stays small, which is what makes the
pair read as a title and a subtitle. Six rows is as many as anyone
reads before scrolling, and a shorter list is a list you do not scroll.

**A magnifier, not a chevron.** The field was prompted with `❯`, which
is a terminal's prompt glyph, in a field that is not a terminal. It is
the sort of thing that is defensible until you see the alternative
beside it. It sits in the same 22px icon column as the application
icons below it, boxed and centred, because the eye reads a column off
the middle of a run of icons and not off their left edges.

**The match count starts at two.** It showed every count including a
single `1` — a number at the right end of the field saying nothing a
glance could not already see. Two or more is the difference between
"that is it" and "keep typing", so that is where it begins.

**The selected row has a fill and no border.** It used to have both, at
white 0.13 and 0.18. On a black panel a 1px ring inside an already
lighter fill is two edges where one will do, and the ring is what made
a list of six look like a stack of cards rather than a list with a
position in it. The fill is what the eye tracks down the column.

### The clipboard

The launcher's twin — the same field over a shelf, and it was sized
like the launcher used to be. 620px, chosen when the launcher's was 560
and both were too big. It is 460 now, and it shares `searchGap` with
the launcher, which is the reason that number is its own: the two are
the same shape and the pods are a different one.

### The notification

**The shape is the notification, so the shape follows the
notification.** It used to be `island.notifyHeight` — a flat 104 —
plus `notifyActionHeight` and `notifyReplyHeight` as two more fixed
terms summed in the geometry table. So a one-line notification with
nothing to act on came out exactly as tall as a three-line one with
four buttons. 104x420 is a banner, and a banner is the presentation the
Dynamic Island replaced.

`NotifyMode.contentHeight` measures the real items instead, the way
`PickerMode.contentHeight` and `CentreMode.contentHeight` do. A summary
and nothing else is 42px, which is the iPhone's compact notification;
one line of body makes it 62 and two make it 76. The width is 420, and
it is the only notification setting left — the other three were dropped
rather than reset, because a key whose value nothing reads is worse
than a key that is gone.

**The leading slot identifies the app, and it is one slot.** iOS shows
a bare app icon and no app name beside it, because the icon already is
the app's name. A third line of small grey text under a two-line
message was a large part of what made this a banner: the popup was
icon, title, body, *app name* — three lines and two of them about the
same fact. So the name is the **fallback**. A real icon takes the slot;
where one does not resolve the name does the icon's job, at up to 110px
and elided, because a long app name should truncate rather than eat the
message. Either way the column beside it is a summary and at most two
lines of body.

The icon lost its tile on the way. It was 46px of `surfaceHigh`-coloured
rounded rectangle wrapped around a 16px glyph, which read as a list row
rather than as an app; iOS draws the icon and lets it sit on the
surface, so that is what it does now, at `iconSize`.

The action buttons and the inline reply field are unchanged and still
accounted for — they are in `contentHeight` off their real heights, and
a client that advertises either still gets room for it.

### The picker

**Its height follows its rows.** `island.pickerHeight` is the
arithmetic for two rows of 16:9, and it was applied whatever was in
the grid — so three wallpapers got a 720x340 panel with a 150px black
void under them. The shape was sized for the worst case and nothing ever
told it the case had changed.

`contentHeight` reads `cols` and `gap` off the picker itself rather
than off the grid, which is worth a note because the version that read
them off the grid was a real dependency cycle: `contentHeight` sizes
the panel, the panel gives the grid its height, and the grid's
`cellHeight` is bound in part to that height — so the measurement was
reaching into the thing it measured, and Qt reported "binding loop
detected for property cellHeight" once per start. Two integers,
declared on the parent, with the grid reading them back.

`PickerMode.contentHeight` is the same arithmetic with the row count
folded in, capped at the two rows the setting describes, because a
picker with forty wallpapers should scroll rather than become a
full-screen sheet. This is `CentreMode.contentHeight`'s arrangement
again, and the reason it is worth copying rather than inventing: a panel
whose content is a count the user controls has to be able to shrink.

## Type and icons

Two scales, and they used to be one pile of numbers.

**The type scale is a ladder, and it is complete.** There were three
rungs below `fontSizeSmall` and every one of them was written as
subtraction from it — thirty-four times across the shell. The sizes
were 8, 9 and 10, none of them was a name, and each use was somebody
having to remember what the subtraction meant. They are `fontSizeTiny`,
`fontSizeMicro` and `fontSizeCaption` now, at the same values.

**The icon scale is separate, and deliberately so.** An icon is a
drawing: the size that suits a glyph in a 36px list row is not the size
that suits one on a 90px tile. The island had 13, 16, 18, 20 and 22
written inline for "an icon" — five numbers, no names, and the same
bell drawn at 16 in the notification history and 20 in the notification
popup. `Theme.iconSizeRow`, `iconSizeBody`, `iconSize`, `iconSizeLarge`
and `iconSizeTile` hold the values that were already there, so this
moved no pixels; what it buys is rungs to choose from.

The two bells are left different on purpose. One is a row's leading icon
and one is a popup's, and a popup has ninety-odd pixels of height to
spend where a row has thirty-six. Unifying them would be tidier and
wrong.

### The split

Press and hold the pill and the island parts into two lobes either side
of a camera housing. It is the gesture the iPhone's island is known
for, and it was the one thing about that shape this shell did not have.

| | |
|:--|:--|
| left lobe | **now playing**: the cover and the name of the track, or the app's own icon when the player publishes no cover, or a music note when it publishes neither |
| housing | the pill itself, shrunk |
| right lobe | the equaliser — click to play/pause |

**The left lobe is a readout, and that is why it is not 56px.** It was
`island.splitLobe` wide and held a 16px app icon, which is a badge
rather than an answer: an equaliser says *that* something is playing, an
app icon says which program is responsible for saying so, and neither is
the answer to *what*. So the left lobe is now as wide as a now-playing
bar needs — cover, then the title — while the right stays at
`splitLobe`, because only one of them has anything to say.

**The cover comes first, and it is the only signal that survives a
browser.** A native app has an icon. A music service in a browser does
not: MPRIS reports the *browser*, so YouTube Music in Brave arrives as
`Identity: Brave Origin` and asks for an icon called `origin`, and web
Spotify is web Spotify — same browser, same answer. Every one of those
players publishes `xesam:artUrl` though, a real cover off the service's
own CDN, and it needs no table of services and cannot fall out of date.
It is also the *track's* picture rather than the app's, so it is the
more specific of the two.

**The cover is beside the name, not alone, and that ordering is the
whole correction.** Album art in the lobe on its own was tried and
removed: a 20px cover of a 640px JPEG is a postage stamp, almost no
cover is legible at that size, and it changes every few minutes so the
one recognisable thing in the shape was the one thing that kept moving.
Beside the name it is recognition rather than information, which is the
job it is actually good at. The iPhone can put a cover alone in a Live
Activity because its island is 160pt of black on a 400pt screen; this
one is a 34px-tall capsule.

**The title's width is sampled, not measured off the live title.** This
is the resting pill's four-digit-sample rule applied to a title, and for
the same reason: the shape must not move on its own. A title changes
every few minutes without anyone asking it to, so a lobe sized to the
live one would make the island breathe three or four times an hour — the
same fault the clock samples prevent, and a worse one, because a song
title is a far bigger jump than a digit. Two samples (a plain title, and
one with a feature credit) set a slot that the live title is elided
into, capped at 128px. Verified stable at 180px across four
consecutive tracks.

**The pill is the housing.** In this mode `geometry.split` gives the
pill a width of `island.splitGap` and a height of
`Theme.housing(idleHeight)`, and the two lobes anchor to its left and
right edges exactly as the pods anchor to the pill's. One surface, one
centre, one morph — the same trick the pods already use, and the reason
there is no second window and no second compositor layer for it.

**The housing is shorter than the lobes, and that is the whole trick.**
A housing as tall as they are fills the gap between them and the island
reads as one wide black bar with nothing split about it. A housing
noticeably shorter leaves two notches cut into the top and bottom edges,
and that silhouette is what the eye recognises. Nothing has to be drawn
in the gap: on a phone the camera is there, and here the notches are
wallpaper, which is honest about there being no camera. `Theme.housing`
is 0.65 of the pill's height rather than a setting, so the notch keeps
its proportion when the height slider moves.

**It is a media state, and deliberately so.** There is nothing to part
around if nothing is playing, so a hold with no track does nothing and a
click still opens the control centre. Opening two empty capsules would
be worse than not opening them — the pods already hold to "both collapse
to nothing when they have nothing to show", and a lobe that ignored
that would be the one shape in the shell arguing with the rule. It is
also the iOS rule: compact exists for a running activity.

**The hold and the click are already exclusive.** Qt stops emitting
`clicked()` once `pressAndHoldInterval` has passed, so the two gestures
cannot fight and the split suppresses nothing. The housing is the one
part of the split with nothing in it, which makes it the natural place
to click the split away — and the reason `split` is in `pillClick`'s
`enabled` list where every other panel mode is not.

**It is the lightest state a user asks for**, so it sits directly below
`expanded` in the mode resolution. Above it, a bind opening the control
centre while the island happened to be parted showed nothing at all.
`island split` and `island unsplit` are IPC functions for a Hyprland
bind, and they mirror the gesture's own conditions rather than setting
the flag blindly.

### The pods

**Two circles flanking the pill: now playing on the left, the control
centre on the right.** They never move the island's centre — they hang
off its edges and grow outwards, and an island that drifts when a tray
icon arrives is not an island.

| Pod | At rest | Open |
|:--|:--|:--|
| media | the cover, in a circle, with the track's position on the rim | the now-playing card, below the row |
| control | a tune glyph | the control centre, below the row |

**A circle, and that falls out of the pod rather than being asked for.**
`Pod` clamps a pod's width to its height, so a pod holding one thing is
already square and `Theme.corner` — which is `h/2` at this height —
spends the full half-height on it. Nothing declares a radius.

Both pods are one size: `openWidth` equals `restWidth`, so hovering and
pinning cost nothing instead of being special-cased out of the width
spring. It was not always so, and what broke first was the tray. It was
a pod then, and it opened on hover — so pointing at the button widened
it and the shape moved sideways out from under the cursor before the
press landed, and you got a row of icons you had not asked for. The
`+n` behind it was the other half of the same problem: four icons plus
a count is a bar, and a bar beside a round pill is the one arrangement
the island does not own. The tray is a card in the control centre now,
where there is room for all of it, and `trayRestMax` went with it — a
setting left describing a choice the shape no longer offers is worse
than a setting that is gone.

Neither pod opens on hover any more. The media pod takes every press
and puts the now-playing card under the row — see below — while the
cover and the track's name under a press-and-hold are still the
split's, because hovering a circle is an accident and pressing and
holding is a decision, and a readout is worth the second one. The
control pod takes every press and opens the centre; it lights under the
pointer and gives way under the press, which is the whole of its
affordance, since a filled circle with a glyph in it is also what a
status light looks like. The media pod collapses when there is no
player — the control pod does not, because it has something to open
whether or not anything is running.

**The control centre hangs below the row.** It used to *be* the pill:
the shape grew from a clock into a panel and took the clock with it, so
opening the controls cost you the time and pushed both pods off the
sides. It opens from the right pod now — right edge to right edge, so
it reads as coming out of the button that was pressed — and the row
above it does not move. The pill keeps the clock, the media pod keeps
its cover, and the button stays where you pressed it.

**The now-playing card hangs below the row the same way, and it is the
one thing the two panels do differently.** Pressing the media pod opens
`MediaCard` — the same card the control centre lays into its grid — at
344 x 140, centred on the pill rather than flush to the pod. The
control centre is flush because it is anchored to its button; this is
centred because the row is symmetric and a panel flush to one end of it
hangs out past the other by eighty pixels, which reads as a shelf that
slid. Centred, the overhang is equal both ways and the panel is the
row's own width made visible.

**The panel and the card are the same object**, which is the whole of
what makes it read as one thing: no tray and no second frame, because a
card on a tray on a panel is three edges for one object. The cover's
own gutter — `padCard` — is what puts it 12 in from the edge, and the
same number is its corner, so one radius governs how far in it sits and
how round it is. `MediaCard` is asked for the layout a grid cell never
gets (`inPanel`): the frame goes, the album and the source take a row
each, the column of words takes the top gutter the cover already has so
the title starts level with the artwork, the cover is let through at
full strength with half its wash — in a cell the wash keeps a
photograph from arguing with words printed over it, and beside the
words there are none — and the bar sits with the metadata it measures
with the stamps under it, over the transport. At 344 x 140 that is
`dense`, `timed` and `tall` at once, every line the card knows how to
say, and the cover comes out at 116 square: the reference card's 96 and
160 a fifth larger, proportions and all.

**The surface is glass, and that is the one place the island's black
gives ground.** Black is the pill's rule — a shape holding a clock reads
as a hole cut in the screen and samples nothing behind it, which is the
iPhone's own — but a panel you read for a minute is not that shape, and
an opaque fill shows nothing of the layer rule's blur however much blur
there is. So it takes `Config.island.opacity` capped at 0.62: the dial
can open it further for a busy wallpaper, it cannot close it. That is
what puts the light along the panel's edge and the wallpaper's colour
under the words.

It is not a mode, so the pill keeps its clock while it is up and the
press that opens it is the press that closes it. The two panels are
exclusive for the same reason: one is the row's answer to "change
something" and the other is its answer to "what is playing", and a card
under a control centre is a second panel nobody opened. Everything
else clears it where the cause is — a heavier mode taking the island
somewhere else, the pod emptying (a player that quits leaves no button
to press and nothing to click away with), the pill, the card's own
body, and the click-away surface every open mode arms. `island card`
is the IPC function for a Hyprland bind, and it mirrors the pod's own
conditions rather than setting the flag blindly.

#### The workspace pod that is not here any more

There were two. The left one was the workspace pod, and it is worth
recording what it was, because the thing that replaced it is a smaller
answer to a question the pod was answering badly.

It drew where you were in one of four styles on the Island page —
**dashes** (long for the current, short for occupied, a stub for empty),
**dots**, **numbers**, or **icons** (the app you last used on each
workspace, which is the only one that says what is *over there*, and
the widest). Point at it and every style became the same numbered
chips, clickable.

Three things were wrong with it, and none of them were the drawing.

**It was in the wrong place.** The pill holds the time, so the pill is
where you look, and the answer to "where am I" was sitting in a
separate capsule to the left of it — a place you had to know to look.
The number now appears in the middle of the pill, which is the same
place as everything else it has ever said.

**It was permanently on.** The pod's whole content was an answer to a
question that is only interesting in the moment after you move. For the
other 99% of the time it was forty pixels of dashes holding a slot open
next to the clock, and the island's one rule — that it widens only when
something happens — was broken by the thing bolted to its side.

**It had four answers and a gesture.** Four rest styles, a hover state
that turned all four into the same chips, a pinned state, a wheel
handler, and a click target per workspace, to communicate one integer.
The pill holds that integer for `island.workspaceFlashDuration` after
`activeId` changes and then has nothing to say again.

Its seat did not stay empty. The left circle is now the media pod — the
one question the pill *cannot* answer, since at rest it holds a clock
and a number and the split that could needs a press-and-hold to reach.
Trading "where am I, permanently" for "what is playing, always" was the
better half of the pair.

The trade is real and worth naming: **you can no longer see your
workspace list at a glance, and you can no longer click a workspace
without a keybind.** Scrolling the pill still moves one workspace
either way (`island.scrollAction`), the switcher still shows titles
across workspaces, and the overview still draws them. What is gone is
the always-on strip. If that turns out to be the part that was carrying
its weight, the pod is a file away and the two settings with it.

#### Why the number does not resize the pill

It could have been a mode, and then the geometry table would size the
pill to the number and it would collapse from "1:54 PM" to "3" and
spring back — three springs for one digit. Instead the number is a
cross-fade inside the clock's own footprint, so the shape never moves
and only the glyphs change.

That is also what the iPhone does. The island resizes for content it
has to *accommodate*; a single digit is not that, and a shape that
breathes on every workspace move is motion the user did not ask for.
The same `ContentFade` and the same timing as every other cross-fade in
the island, so it is not a special effect — it is the modes' own
transition, pointed at a different pair of labels.

Every other mode undocks them. The control centre, the launcher and a
notification each own the whole shape, and satellites orbiting a
search field are debris.

### The control centre

The panel is a grid, and what is on it is configuration rather than
code. Each control holds a rectangle in cells:

```
calendar:0,0,3,5;wifi:3,0,3,1;bluetooth:3,1,3,1;media:3,2,3,2
         │ │ │ │
         x y w h
```

A fifth field turns a control's words off — `wifi:3,0,3,1,0` is the
badge and nothing else, at any size. It is optional, so a layout
written without it means what it always did.

Settings → Control draws that grid at full size with the real cards
in it — the Wi-Fi card says which network, the month says which month
— and you drag them around. Corner to resize, `Aa` for words, `×` to
remove, and a palette underneath for everything not currently placed.
The column count is 4 to 8; **Tidy** repacks; **Undo** goes back. The
panel's height is whatever the layout reaches, so there is no height
to set and none to disagree with what is in it.

Controls change shape rather than scaling. A Wi-Fi card three cells
wide carries the network name and a chevron into the list; squeezed to
one — or with its words turned off — it is the badge alone and keeps
only the power toggle. A slider
wide enough for a label has one, and taller than it is wide it stands
up and fills from the bottom.

Wi-Fi, Bluetooth and Sound have lists behind their chevrons, drawn
over the grid inside the same panel — the shape does not change, the
grid steps aside, the list slides in, and the chevron comes back.
Clicking Wi-Fi used to open the Settings window on the Network page,
which is a strange answer to "what networks are around".

Album art in a media card is washed with the accent colour, so a card
belongs to the theme whatever the record label chose. That detail, the
lists-in-the-panel and the layout editor are all taken from
[saneAspect's Dynamite V3](https://www.youtube.com/watch?v=Ob98KFByTec).

### Motion

Every shape in the shell is on a spring, and a spring is described the
way Apple describes one: a **response**, which is its natural period
and reads as the speed of the thing, and a **bounce**, which is one
minus the damping fraction. That is the pair SwiftUI's
`Spring(duration:bounce:)` takes, so a figure read off Apple's
documentation means here what it means there.

| | Response | Bounce |
|:--|:--|:--|
| open | 240 ms | 0.15 — `.snappy`, about 0.6% overshoot |
| close | 190 ms | 0.05 |
| pod peek | 280 ms | 0.40 |
| content in | 40 ms lead, then 150 ms | — an easing, not a spring |
| content out | 90 ms, immediately | — |
| cross-fade | 90 ms in, 60 ms out | — an easing, and there is nothing to overshoot |

There were three tiers here and there are two. The third was **hover**,
180 ms against an open's 240, held for the compact pill on the grounds
that "a 6px lift given a full expansion's response feels slack". The
reasoning was sound for a 6px lift and did not survive the lift becoming
a 47% width change — and with hover no longer moving the shape at all
there is nothing left for the middle tier to distinguish. A tier that
exists to slow down a movement that no longer happens is a number
nobody can hear.

Hover is the last row instead: a plain cross-fade, at the durations the
shell already uses for anything that is not riding a shape. That is the
whole of what pointing at the island does now.

Those are the **snappy** tempo. The bounces are Apple's three exactly:
**smooth** is 0, **snappy** 0.15, **bouncy** 0.30. The responses are
not — SwiftUI's named springs all run at half a second, which is a
phone animation and reads as slow on a shell you drive with a pointer.
macOS's own chrome runs nearer a quarter second, and that is also
where the island already was: sampling [saneAspect's Dynamite
V3](https://www.youtube.com/watch?v=Ob98KFByTec) at 60fps — the
panel's height in one column of pixels, frame by frame — its control
centre opens in about 180 ms and overshoots by 1.4%. The two
references agree about the speed and differ only about how much
overshoot to spend on it, and Apple's answer is the smaller one.

**A spring, not a curve, because a curve cannot be interrupted.** An
easing is a function of one variable — how far through it is — so it
cannot know that the property was already moving when it started, or
how fast. Reverse a Qt `Behavior` mid-flight and it restarts from a
standstill at whatever value it had reached: brush the pill and leave
again, or open the control centre and shut it before it has arrived,
and there is a visible hitch at the turn. `Widgets/Spring.qml` carries
its velocity through the reversal instead. That continuity is most of
what makes motion feel attached to the pointer rather than played at
it, and it is why the springs are not Behaviors at all — a Behavior
owns a start and an end, and a spring has neither.

It is solved rather than stepped: the closed-form solution of the
damped oscillator, evaluated at each frame's own dt. So the motion is
identical at 60Hz and at 240Hz and a dropped frame costs a frame
rather than changing the curve. Qt ships a `SpringAnimation` and it is
not this one — it steps a fixed 16 ms Euler, which would run every
morph on a 120Hz panel at 62.5.

**Departures spring too, barely.** They used to be critically damped
on the argument that a spring on dismissal reads as the interface
arguing with you. macOS does not agree, and neither does this any
more; what it keeps from that argument is the size of the number.
Bounce on the way out is 0.05, because half of what the island
dismisses is collapsing to nothing and an overshoot past nothing is a
negative width. Every spring that can reach zero also carries a floor,
and clamps only what is read out — the oscillator keeps its true state
so it still settles from where it really is.

**Arriving is not only a fade.** A surface grows the last four percent
into place as it fades in, anchored at the top edge, which is the
edge it came out of. That is the macOS presentation everywhere from a
popover to Notification Centre, and it is the difference between
content appearing *over* the shape and content coming *out* of it. It
is applied to the panel modes as a group rather than to each of them,
which is also what makes it mean the right thing: going from the
launcher to the control centre is not an arrival, it is the same panel
showing something else, and it stays a plain cross-fade.

The content is choreographed against the shape rather than gated on
it. It used to wait until the pill had reached 97% of its final width
and only then fade in, which is why opening the control centre read as
a resize followed by a screen. Now the shape moves alone for 40 ms,
the content fades into it while it is still growing, and it is fully
in long before the shape settles. On the way out the content leaves
first: content still fading while the shape closes over it looks like
a mistake.

Fades stay easings, in both directions and everywhere. A cross-fade
has no velocity to carry and no overshoot to spend, and Apple eases
those too.

`Services/Motion.qml` holds the whole vocabulary and runs two engines
on purpose. The shapes get `Widgets/Spring.qml`. Everything small
enough that interrupting it is not a thing you can see — a toggle
knob, a row highlight, a button's press — gets a bezier spline sampled
from the same spring, which costs one curve rather than a physics step
per frame per control. Tempo is one control in Settings → Island;
response, bounce and the emerge scale are each their own slider a fold
below it, and **Reduce motion** drops the springs and the emerge while
keeping the cross-fades.

### Palette

The shell's colours are twenty-six Material role names —
`surface_container_high`, `on_surface_variant`, and so on — and
`Services/Theme.qml` is the only thing that reads them. Everything
else asks Theme. That indirection is what lets the roles be filled
from two completely different places without anything downstream
knowing which:

- **from the wallpaper**, by matugen, which derives a Material palette
  from the image;
- **from a preset**, by `bin/island-palette`, which fills the same
  templates from a table of twelve colours per theme.

Twelve, not twenty-six, because the rest is one shared mapping. A
preset says what its crust, base, three surfaces, overlay, text,
subtext, three accents and red are — under the names its own authors
use, so a gruvbox value looked up in gruvbox's documentation is
findable by the name it has there — and the mapping onto Material
happens once for all of them. Adding a theme is twelve hex values.

The ramp has to ascend, and the one step no theme names is
interpolated rather than invented: Material reads
`surface_container_*` as elevation, so a surface darker than the one
below it puts a card behind the thing it is sitting on.

**The accents are the quiet variants.** Every one of these palettes
has a loud set and a muted set, and `primary` here is not a swatch on
a page — it is the fill behind a selected row, the edge of whatever
the pointer is on, the active segment of a control. A colour chosen to
be noticed is the wrong one for something on screen all day. So
gruvbox is Gruvbox Material rather than the original's `#fb4934` and
`#b8bb26`, and Nord's accent is nord9 rather than the Frost cyan every
Nord preview leads with. Catppuccin is left as published: it is
high-value by design, and its accents are meant to carry dark text,
which is exactly how the shell uses them.

Under a preset the wallpaper had no say in the palette, so the two can
disagree. **Tint the wallpaper** washes the image toward the accent —
most of the way to grey, then back out in one hue, which leaves the
shapes and takes the argument away. A hue rotation would leave a blue
sky blue-ish and still wrong. It is a `MultiEffect` on the layer that
is already being drawn, enabled only while it is wanted, so the
ordinary case pays for no render target at all.

### Shape

One radius is set; everything else derives from it. `Theme.radiusSmall`,
`radiusNormal` and `radiusLarge` are 0.6x, 1x and 1.2x of the panel
radius, so the slider in Settings → Theme moves every corner in the
shell together rather than the two that happened to reference it.

Which of the three a shape gets is a question about what kind of thing
it is, not about how big it is — size is already in the answer, because
Qt clamps a radius to half the shorter side, so at a large setting a
28px button becomes a capsule while the panel behind it stays a rounded
rectangle:

| Token | What it is for |
|:--|:--|
| `radiusLarge` | a **card** — something that holds other things and sits on a surface: control-centre cards, a selected row in a list, overview and picker cards, an icon tile, a popup |
| `radiusNormal` | a **panel**, or a field you type into: the settings window and its sidebar, a segmented control, a password box |
| `radiusSmall` | a **chip** — a small control holding one word or one glyph: buttons, tabs, a thumbnail inside a card |

There is a fourth case and it is deliberately not a token: a shape whose
roundness is a fact about the shape rather than a preference. A toggle
knob, a slider handle, a workspace dash, the cap on a 3px tick — those
are `height / 2`, written where they are drawn. `radius: 1.5` beside
`width: 3` is the same number with the reason taken out of it, and it
stops being a capsule the moment somebody changes the 3.

The island's own corner is a function of its height, in two
regimes, and the join between them is the point:

```
h <= idleHeight:  corner = h / 2                              a capsule
h >  idleHeight:  corner = idleHeight/2 + (h - idleHeight) * 0.039
```

**At rest it is a capsule**, and that is a fact about the shape rather
than a preference: a pill's ends are semicircles. It is also the
iPhone's answer, and it is load-bearing — a stadium reads as a hole cut
in the screen and a rounded rectangle reads as a card sitting on it,
and neither translucency nor a shadow makes up the difference. The pods
are capsules for the same reason and at the same height, which is why
the three read as one object.

Above the resting height the radius opens up with the shape, so the
374px control centre is a rounded rectangle rather than a lozenge, and
it grows *out of the cap* rather than out of `island.radius`. Growing
it out of the radius is the mistake this replaced: `radius + h * 0.06`
put a discontinuity at `idleHeight`, answering 17 for a 34px pill only
by accident and 10 for a 35px one deliberately — a visible pop six
pixels into the hover morph. The slope of 0.039 is chosen so the
control centre lands where it always did, about 31px, which is the
corner its own cards are inset by.

The height is already spring-animated, so **the corner opens up as the
shape does**, for free.

### Presentation

Three settings, and they are the three the Dynamic Island does that a
frosted desktop panel does not. They live under `appearance` because
none of them is geometry — they are about how the shape sits on the
screen.

| | |
|:--|:--|
| **Black** | `#000`, in every palette and in light mode too, which is what the iPhone's is. Nothing of the wallpaper is sampled through it. This is the largest single reason the shell read as a good desktop island and not as a phone. |
| **No hairline** | A ring around the shape, and a second one two pixels inside it (`Widgets/Bezel.qml`). It was there to give a black surface a readable size — one hairline gives no scale and a pair does — and it is a real argument, which is why the settings window and the lock screen keep theirs. On the island it is off. |
| **A shadow** | Hyprland cannot supply one: `decoration.shadow` is for toplevels and a layer-shell surface gets nothing. So the island casts its own, and it is what says the shape is sitting *above* the screen rather than drawn on it. |

The shadow is `Widgets/Shadow.qml`: a stack of concentric rings, not a
blur. `MultiEffect` is the obvious route and cannot be used — see
`NOTES.md` for the four workarounds that were measured and failed
against a render target in this layer — and there is no cheap readback
of a `ShaderEffect`'s own coverage to convolve. The rings are outset by
`spread` and each is fainter than the last, on a power curve because a
linear one reads as a stack of rings if you look for it. The one thing
it has to get right is concentricity, which is `Theme.outer` — the
mirror of the `Theme.inner` rule the Bezel uses.

**The OSD and notifications used to be more translucent than the rest
of the island**, which was how those two modes were told apart from the
others: they arrive over whatever you were looking at rather than
because you asked. With the island opaque there is nothing left to tell
them apart that way, so `popupOpacity` ships equal to `opacity`.
Dropping it below 1.0 brings the distinction back.

---
