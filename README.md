# SimpleNotch

The MacBook notch as a small, always-there workspace: media controls, a file shelf, clipboard history, window snapping, a Pomodoro with a cartoon tomato, an English ↔ Russian translator, and birthday countdowns.

Requires macOS 15 or newer.

## Features

- **Home**: now-playing controls with visualizer, plus Calendar and Reminders
- **Shelf**: drop files onto the notch and pick them up later
- **Clipboard**: the last 50 copies, with pinning; `⌘⇧V` opens it, picking an item pastes it
- **Focus**: Pomodoro (25/5/15, editable) and a simple timer, with progress shown on the closed notch
- **Translate**: offline English ↔ Russian via Apple's Translation framework; `⌃⌥T` translates the selection
- **Birthdays**: countdowns to the people you care about
- **Window snapping**: drag a window to the notch and drop it on a layout, or use `⌃⌥` shortcuts

## Building

Open `boringNotch.xcodeproj` in Xcode 26 or newer and run the `boringNotch` scheme.

## Credits and license

SimpleNotch is built on [boring.notch](https://github.com/TheBoredTeam/boring.notch) by TheBoredTeam and its contributors, and borrows ideas from [Cyclop](https://github.com/akalikbergenov/cyclop) by akalikbergenov (MIT).

Like boring.notch, SimpleNotch is licensed under the [GNU GPL v3](LICENSE). Third-party licenses are listed in [THIRD_PARTY_LICENSES](THIRD_PARTY_LICENSES).
