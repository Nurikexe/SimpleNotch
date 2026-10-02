# SimpleNotch

A macOS app that turns the MacBook notch into a small, always-there workspace: media, files, clipboard, focus timers, translation and birthdays.

## Language

### The notch

**Notch**:
The black shape at the top centre of the screen that SimpleNotch draws over (or in place of) the hardware notch.
_Avoid_: Island, panel, bar

**Closed notch**:
The notch at rest, roughly the size of the hardware notch; may show small live indicators on either side.
_Avoid_: Collapsed, minimised

**Wings**:
The two small areas on either side of the hardware notch, in the closed notch, used for live indicators. While a Focus session or Timer runs, they show focus progress; otherwise (including during breaks) they show media.
_Avoid_: Sides, ears

**Progress line**:
A thin line along the bottom edge of the closed notch showing how much of the current Pomodoro interval or Timer has elapsed.

**Open notch**:
The notch expanded downwards, showing one tab's content.
_Avoid_: Expanded panel, popover

**Sneak peek**:
A brief widening of the closed notch to announce a change (e.g. a new track) without opening it.

**Tab**:
One of the six sections of the open notch: Home, Shelf, Clipboard, Focus, Translate, Birthdays.
_Avoid_: Page, view, mode

### Features

**Home**:
The tab showing the media player alongside Calendar and Reminders.

**Focus**:
The tab holding both the Pomodoro and the Timer; only one of them is shown at a time.
_Avoid_: Productivity, timers tab

**Pomodoro**:
A repeating cycle of work and break intervals for focused work.

**Focus session**:
The work interval of a Pomodoro (25 minutes by default).
_Avoid_: Pomodoro (for a single interval), work block

**Short break** / **Long break**:
The rest intervals of a Pomodoro; a Long break (15 min) replaces the Short break (5 min) after every fourth Focus session. All durations are user-editable.

**Tomato**:
The cartoon mascot of the Pomodoro, whose expressions and motions reflect the Pomodoro's state (running, paused, on break, finished).
_Avoid_: Icon, avatar

**Daily tally**:
The count of Focus sessions completed today, shown as a row of small tomatoes; it resets at midnight. No longer-term history is kept.

**Timer**:
A single countdown from a duration the user sets, with no cycle.
_Avoid_: Countdown (reserved for Birthdays)

**Shelf**:
A holding area inside the notch for files dropped onto it, kept until the user drags them out or removes them. It holds references to the original files, not copies: a moved file is followed, a deleted one drops off the Shelf.
_Avoid_: Tray, stash, drop zone

**Clipboard history**:
The most recent 50 Clips, kept across restarts, newest first.

**Clip**:
One thing that was copied: text, a link, an image, or a reference to a file. Content marked private or transient by its source (e.g. a password manager) never becomes a Clip.
_Avoid_: Entry, item, copy

**Pinned clip**:
A Clip the user has pinned so it is never pushed out of the Clipboard history.
_Avoid_: Snippet, favourite

**Translate**:
The tab that translates between English and Russian offline, choosing the direction from the script of the input (Cyrillic → English, otherwise → Russian) unless the user flips it.
_Avoid_: Translator, dictionary

**Birthday**:
A person the user is tracking: a name, a day and month, and optionally a birth year and an emoji. Entered by hand only.
_Avoid_: Contact, event, person

**Countdown**:
The number of days until a Birthday's next occurrence; zero means it is today.
_Avoid_: Timer (that is a Focus tab concept)

**Download indicator**:
A live display in the notch of an in-progress browser download.

### Window snapping

**Snap**:
Moving and resizing a window so it fills a Layout exactly.
_Avoid_: Tile, arrange

**Layout**:
A named target region of the screen a window can be snapped to, such as Left half or Top-right quarter.
_Avoid_: Template, zone, position

**Snap grid**:
The set of Layouts the notch opens to show while a window is being dragged to it; dropping the window on a Layout snaps it there.
_Avoid_: Snap menu, layout picker
