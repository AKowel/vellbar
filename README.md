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

## The honest bit about icons

Vellbar **cannot show you other apps' menu bar icons**, and neither can anything
else without Screen Recording permission.

Modern macOS renders every status item — third-party ones included — inside the
ControlCenter process. Ask the window list who owns them and it says
"ControlCenter" for all of them. There is no API to read another app's status
item image. That is exactly why Bartender and Ice ask for Screen Recording:
capturing pixels is the only way to see the icons, and it is fragile across
macOS releases.

Vellbar takes the cheaper route. It reads ControlCenter's Accessibility tree,
where items usually carry a title or description naming their owner. That needs
only Accessibility, which is a far smaller ask than recording your screen.
Where a name isn't available the item still appears, just unnamed.

**Hiding works with no permissions at all.** Accessibility only improves the
list.

## Requirements

macOS 14 or later. Accessibility optional.

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
