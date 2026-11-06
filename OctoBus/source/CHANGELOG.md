# Changelog

## 1.3.6 (27 October 2026)

### Fixed
- After a server restart, the timers set from the restart offsets (a first guess) could be shown and shared as if they had been seen. Asking the server's uptime again can give a time one second earlier, which made every guess count as "seen since the restart"; the guesses were then passed to every other OctoBus user as sightings and blocked real shared times from replacing them. Guesses are now marked as such, are never shared, and give way to the first real sighting or shared time. Saved guesses from 1.3.5 are cleaned up at the next login.

## 1.3.5 (12 October 2026)

### New
- **Accurate without the DLL.** OctoBus now ships with each route's restart offset (how many seconds into its trip it docks, counted from the last server restart), measured on 12 October. At every login it asks the server how long it has been up and sets every route it has not seen since that restart from the restart time plus the offset. A brand new copy with no DLL and no sightings gets every timer right from the first login, and stays right after later restarts.

- **Settings window**: `/ob options`, or right-click the minimap icon. Background opacity, window opacity, text size, text opacity, the gap between names and times, place colour vibrance, text outline (thin, thick or shadow), window size, lock, which corner stays put as the list grows or shrinks, auto-show, which routes to show, and bell alerts. Changes apply at once.

- **Shared timers.** Copies with the DLL share the docking times they see over a hidden chat channel; copies without it use them, so one DLL user online keeps everyone exact. A copy that logs in asks for the current times. Can be turned off in the settings.

### Changed
- The "no DLL: estimates only" note is gone from the panel: without the DLL the timers are now accurate. `/ob debug` still shows whether the DLL is loaded.
- The footer no longer names the route with the oldest data (the restart correction makes it unnecessary). It only appears after a server restart, while a route in the window has not been seen since.
- New trip lengths, measured against the restart time over two long server runs (15 and 43 hours). The old ones drifted by up to 1.5 seconds an hour (Thunder Bluff), so DLL-free timers were up to a minute off late in a long run. Existing copies are updated once.
- Restart offsets updated to the latest server run. They turned out to shift at each restart, by 3-18 seconds for most routes and by minutes for Grom'gol and Ratchet, so they are now only a first guess until shared or seen.

### Fixed
- The 1.3.4 one-time repair of saved trip lengths never actually ran (it ran before the game loaded the saved data), so copies used before 1.3.4 kept wrong trip lengths and drifted by up to a minute, e.g. Grom'gol about 45 seconds slow after 11 hours.
- The settings window needed two right-clicks to open, and some checkboxes on a shared line (outline, sound) toggled their neighbour.
- Window size, look, lock, position and the minimap icon's spot were not restored after logging in: they were applied before the game had loaded the saved settings.

## 1.3.4 (12 October 2026)

### Fixed
- After a server restart, each route's trip length was re-measured from only the few trips seen since, throwing away days of measurement. Small errors in it added up to 30-60 seconds within a few hours. Trip lengths now carry across restarts: new trips are blended in, weighted by how many trips each measurement covers.
- Existing saved data is repaired once: trip lengths go back to the long-term values and the restart offsets are recomputed with them.

### Changed
- The built-in trip lengths are now the values measured over three days (400-900 trips per route), so a new copy starts accurate.

## 1.3.3 (12 October 2026)

### New
- **Server restarts are handled.** OctoBus asks the server how long it has been up (`.server info`, sent quietly when you log in; its reply is hidden) and so knows exactly when the server restarted. Routes not seen since a restart are marked with an orange `?`, and the footer says when the restart was.
- **Timers corrected from the restart time.** Each route docks a fixed number of seconds into its trip after a restart. OctoBus learns this once per route, and after a restart moves every route straight to the right time. Once this has been seen to hold across a restart, corrected routes lose the `?`.
- The marks now mean: no mark = seen since the last restart (accurate), `~` = an estimate, `?` = may be off after a restart. Before, `~` only meant "not seen since you logged in".

### Fixed
- A sighting up to about 1.5 minutes off the schedule was taken as normal and could bend the learned trip length. Only differences that drift can explain are used now (10 s plus half a second per hour since the last sighting).

## 1.3.2 (12 October 2026)

### New
- **Timers re-sync at the far end too.** Seeing a transport arrive at, or leave, Undercity, Grom'gol, Kargath, Thunder Bluff, Revantusk or Booty Bay now re-syncs that route, just like at Orgrimmar, Sparkwater and Ratchet. The row tooltip says where it was synced ("Synced at Undercity this session").
- The stay at the far end is now learned whenever you see a transport both arrive and leave there.

## 1.3.1 (10 October 2026)

### Changed
- Place colours are toned down (75% as bright), so they are easier on the eye.
- The window background is more see-through: 75% opaque instead of 92%.

## 1.3 (9 October 2026)

### New
- **Place names are colour coded**: Orgrimmar red, Undercity purple, Grom'gol green, Kargath orange-brown, Thunder Bluff tan, Sparkwater light blue, Revantusk teal, Ratchet gold and Booty Bay pink. A far end renamed with `/ob name` shows in white.
- **Rows are sorted by what happens soonest**: the next arrival, departure or time to fly is at the top. "Departing" and "fly now" rows go first, and rows with no timer go last.

### Fixed
- The Ratchet boat's "fly now" stayed up until the boat sailed, even when it was far too late to make it. It now shows for 10 seconds after your time to fly, then moves on to the next sailing you can still make.

## 1.2.1 (9 October 2026)

### Fixed
- A transport still at its dock after its scheduled departure showed "here now" in green. It now shows **departing** in yellow, since it is about to pull away.
- When it was time to fly for the Ratchet boat, the row jumped straight to the next sailing. It now stays on the current boat and shows **fly now** (counting down to when it sails) until that boat has left Ratchet, then moves on to the next one. A bell on that row now says "fly to Ratchet now".

## 1.2 (8 October 2026)

### New
- **Rows read "start -> end"**, for example `Orgrimmar -> Undercity`, and the timer is for the start. The separate "zeppelin" / "boat" label is gone from the rows (it is still in the tooltip).
- **Right-click a row to reverse it**, for example `Undercity -> Orgrimmar`, timed at Undercity.
- **Routes for where you are.** By default the window only shows routes with an end in your zone, each already reversed to start from your end. Click the window title (or `/ob all`) to switch to all routes. Somewhere with no routes, opening the window by hand shows the last place's routes.
- **New route: Grom'gol <-> Undercity zeppelin.** Its cycle is worked out from earlier sightings; its Undercity end is learned on the first ride from Grom'gol.
- **Both ends of every route are timed.** Built-in far-end timings measured on rides: Undercity, Grom'gol, Kargath, Thunder Bluff, Revantusk and Booty Bay.
- **Far ends are learned by riding**, with no recording needed: a transport that stands still for 20 s away from its home dock is treated as docked at the far end.
- **The window opens by itself at either end of any route**, and while a tracked transport is in view (for example during a crossing).
- Built-in cycle lengths now come from about 5 hours of sightings, so a new copy's first sightings line up with a long baseline.

### Fixed
- Far-end learning failed while `/ob debug on` was recording.
- The built-in baseline was ignored when the first thing seen in a session was a transport leaving rather than arriving.

### Changed
- `/ob name` renames the far end of a route.
- `/ob zone` now means "auto-show only at route ends".

## 1.1 (8 October 2026)

### New
- **Ratchet <-> Booty Bay boat**, shown in Orgrimmar as when to fly (`fly 4:55 sails 6:40`) to make the next sailing. `/ob travel <seconds>` sets your travel time to the Ratchet dock (default 175 s).
- **Resizable window**: drag the dots in the bottom-right corner, or `/ob scale <0.6 to 2>`.
- **Footer names the route with the oldest data** and how long ago it was seen.
- **`/ob disallow <name>`** removes a place from the auto-show list. Place names now match regardless of capitals or quotes.
- **`/ob debug on` / `off`** records transport positions for mapping new routes. `REC` shows in the window while it runs.

### Changed
- A single sighting that does not fit the schedule no longer resets a route's history; a second agreeing sighting is needed.
- The addon is at the top of the repository, so it installs correctly from a launcher's git address. The DLL is a separate download.

## 1.0 (8 October 2026)

- First release, as TurtleTransit, renamed OctoBus the same day: arrival timers for the Orgrimmar zeppelins and the Sparkwater boat, with bells, a minimap icon and automatic calibration from sightings.
