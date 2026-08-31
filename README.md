# Vellbar

Hide menu bar clutter on macOS. Free, no account, no telemetry.

Part of [Vellforge](https://vellforge.com).

## What it does

Vellbar adds two icons to your menu bar: a **chevron** and a **divider**.

Hold ⌘ and drag the divider to wherever hiding should begin. Everything to its
left disappears when you collapse; everything to its right always stays on show.
Click the chevron to collapse or expand, right-click it for the menu.

The menu lists what's up there and can click any item for you, even while it's
hidden.

## Permissions, and what each one buys

**Hiding works with no permissions at all.** The two below only add to it.

| Permission | What it gets you |
| --- | --- |
| Screen Recording | The real icons in the list |
| Accessibility | Clicking an item from the list to open it |

### Why showing icons needs Screen Recording

Modern macOS renders every status item — third-party ones included — inside the
ControlCenter process. Ask the window list who owns them and it answers
"ControlCenter" for all of them, and there is no API anywhere to read another
app's status item image.

Photographing the menu bar is the only route. That is why Bartender and Ice ask
for the same thing. Vellbar captures **one strip of the menu bar**, crops each
icon out of it, never writes an image to disk and never sends one anywhere.

Icons are cached, which matters: a hidden item has been pushed off the screen
and cannot be photographed, so Vellbar captures while the bar is expanded and
shows the cached icon when it isn't.

macOS only applies a new Screen Recording grant after the app restarts — the
setup window offers to relaunch for you.

## Requirements

macOS 14 or later. Both permissions optional.

## Building

```
swift build
swift test
./Scripts/bundle.sh            # assembles build/Vellbar.app
./Scripts/bundle.sh --release  # universal binary
swift Scripts/make-icon.swift  # regenerates the icon
```

## How it hides things

There is no API to hide another app's status item. What you *can* do is make
your own item enormously wide — items lay out right to left, so a very wide one
shoves everything to its left off the edge of the screen. Crude, but it is what
Hidden Bar and Dozer do, it needs no permissions, and unlike pixel-capture it
cannot break on a macOS update.

## Prior art

[Bartender](https://www.macbartender.com/) (paid) and
[Ice](https://github.com/jordanbaird/Ice) (free, open source) both do far more,
using Screen Recording to redraw the menu bar properly. If you want real icons
in a real dropdown, use Ice. Vellbar is for people who would rather not grant
screen capture to hide a few icons.

## Licence

MIT. See [LICENSE](LICENSE).
