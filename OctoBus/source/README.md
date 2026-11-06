# OctoBus

Arrival timers for the Horde zeppelins and boats, for the vanilla 1.12.1 client (tested on OctoWow / Turtle WoW).

Each row reads **start -> end**, for example `Orgrimmar -> Undercity`, with a live timer for the start: how long until it **leaves** if it is docked there, or how long until it **docks** there if it is away. Right-click a row to reverse it (`Undercity -> Orgrimmar`, timed at Undercity). For the Ratchet boat, seen from Orgrimmar, it shows when to **fly** to make the next sailing. Click a row to put a bell on it and get a chat message shortly before it arrives (or, for the Ratchet boat, shortly before you need to fly).

See the [changelog](CHANGELOG.md) for what changed in each version.

OctoBus needs one extra file, `ZepSense.dll`, which you install by hand in the game folder. Your launcher can install the addon but not the DLL. See [Install](#install).

## What you see

| Window element | Meaning |
|---|---|
| Green check | Transport is docked now. The timer counts down to departure ("leaves"). |
| Red X | Transport is away. The timer counts down to docking ("docks"). |
| No mark before a time | Seen since the server last restarted: accurate to a few seconds. |
| `~` before a time | An estimate: worked out from the server restart time, or never seen yet. |
| `?` before a time (orange) | The server restarted and this route has not been seen since, so the time may be off by up to 3 minutes. It goes away when you see it. |
| `departing` (yellow) | The transport is still at the dock past its scheduled time and is about to leave. |
| `fly now` (red) | Ratchet boat: it is time to leave Orgrimmar for this sailing. It shows for 10 seconds, then the row moves on to the next sailing you can still make. |
| `fly 4:55 sails 6:40` | Ratchet boat only: leave Orgrimmar in 4:55 to be on the Ratchet dock before it sails in 6:40. If you can no longer make a sailing, it shows the next one. |
| Place colours | Each place name has its own colour (Orgrimmar red, Undercity purple, Grom'gol green, and so on). A far end renamed with `/ob name` shows in white. |
| Row order | Soonest first: whatever docks, leaves or needs you to fly next is at the top. Rows move as the timers change. |
| Bell on a row | Alerts are on for that route (click a row to toggle). |
| Title | Click it to switch between the routes for where you are and all routes (`Transports - all`). |
| Footer | Only shown after a server restart, while a route in the window has not been seen since: `server restarted 20 min ago: ? = not seen since`. |
| Dots, bottom-right corner | Drag to make the window bigger or smaller. |
| Hover over a row | Cycle, stay at the dock, how the far end was measured, and what left- and right-click do. |

### Routes

| Route | Type | Ends (where it shows up) |
|---|---|---|
| Orgrimmar <-> Undercity | zeppelin | Orgrimmar / Durotar; Tirisfal Glades / Undercity |
| Orgrimmar <-> Grom'gol | zeppelin | Orgrimmar / Durotar; Stranglethorn Vale |
| Orgrimmar <-> Kargath | zeppelin | Orgrimmar / Durotar; Badlands |
| Orgrimmar <-> Thunder Bluff | zeppelin | Orgrimmar / Durotar; Mulgore / Thunder Bluff |
| Grom'gol <-> Undercity | zeppelin | Stranglethorn Vale; Tirisfal Glades / Undercity |
| Sparkwater <-> Revantusk | boat | Orgrimmar / Durotar; The Hinterlands (hide with `/ob boat`) |
| Ratchet <-> Booty Bay | boat | Ratchet; Stranglethorn Vale. Also shown in Orgrimmar / Durotar, for planning. |

Every route has built-in timings measured on rides (both ends, cycle and stay), which your copy keeps refining from what it sees. The far end of Grom'gol <-> Undercity is not measured yet; it is learned the first time you ride it from Grom'gol. You can rename the far end of a route with `/ob name`.

### Which routes are shown

- **Routes for where you are** (the default): only routes with an end in your zone, each reversed to start from your end. In Stranglethorn Vale, for example, you see `Grom'gol -> Orgrimmar`, `Grom'gol -> Undercity` and `Booty Bay -> Ratchet`. A right-click reverses a row until you change zone. A route whose transport is in view (for example while you ride it) is shown too. Somewhere with no routes, opening the window by hand shows the routes of the last place that had some.
- **All routes**: every route, in the direction you last set with right-click (kept between sessions).

Switch with a click on the window title, or `/ob all`.

## Requirements

1. **`ZepSense.dll`**, a small client DLL that exposes one Lua function, `ZepTransports()`, which returns the position of every zeppelin/boat the client currently has loaded. The addon cannot see transports without it. Without the DLL, every timer is set from the server's restart time and the built-in offsets, which is close (usually within 20 seconds, marked `~`), and becomes exact as soon as a DLL user shares the current times (see Shared timers below).
2. A client setup that loads DLLs listed in `dlls.txt`.

## Install

Installing takes two parts. The addon can be installed by your launcher; the DLL always has to be set up by hand.

### Part 1: the addon

- **With a launcher:** add this repository's git address (`https://github.com/Phridgey/OctoBus.git`).
- **By hand:** download this repository as a ZIP (green "Code" button, then "Download ZIP"), unzip it, rename the folder to `OctoBus` and put it in `Interface\AddOns\`. The folder must contain `OctoBus.toc` directly.

### Part 2: the DLL (manual, the launcher does not do this)

1. Download `ZepSense.dll` from the [Releases page](https://github.com/Phridgey/OctoBus/releases/latest).
2. Put it in the game folder, next to `WoW.exe`.
3. Open `dlls.txt` in the game folder and add a line `ZepSense.dll`.
4. Start the game fully (a `/reload` is not enough the first time the DLL is added).
5. Check it worked: open the window (`/ob` or the minimap icon). To confirm the DLL is loaded, type `/ob debug`. Watching a transport dock also removes the `~` from its time. There is nothing else to set up: the timers correct themselves each time you see a transport dock.

The DLL only reads transport positions that the client has already loaded; it does not send anything anywhere. Its source is `ZepSense_src/ZepSense_v5.c` (built with `i686-w64-mingw32-gcc -O2 -shared -static-libgcc -Wl,--kill-at -s`). As with any client DLL, use it at your own risk and check your server's rules.

Saved data lives in `WTF\...\SavedVariables\OctoBus.lua`.

## Using it

- **Minimap icon**: click to show/hide the window anywhere; drag to move it around the minimap edge.
- **Auto-show**: the window opens by itself at either end of any route (the zones in the table above), and while a tracked transport is in view, such as on a crossing. It hides elsewhere. The icon toggle always works manually. Add more auto-show places with `/ob allow <zone or sub-zone>` (capitals do not matter; `/ob where` shows the names), remove one with `/ob disallow <name>`, or turn the behaviour off with `/ob zone`.
- **Bells**: click a row to toggle a bell. Belled routes print a chat message `/ob alert` seconds (default 45) before the transport docks at the row's start, e.g. `Orgrimmar -> Undercity: docks at Orgrimmar in 0:45`. Nothing is printed to chat for routes without a bell.
- **Reverse a row**: right-click it.
- **Settings window**: `/ob options`, or right-click the minimap icon. Background opacity, window opacity, text size, text opacity, the gap between names and times, place colour vibrance, text outline (thin, thick or shadow), window size, lock, and which corner stays put as the list grows or shrinks, plus auto-show, which routes to show, and bell alerts. Changes apply at once.
- **Move and size the window**: drag it to move it; drag the dots in the bottom-right corner (or use `/ob scale`) to resize it. `/ob lock` locks position and size; `/ob resetpos` puts the window and icon back at their default place and size.

## How the timing works

Each route runs on a fixed cycle. Once the addon sees one transport arrive, it can predict every later arrival, even while the transport is out of view (transports are only sent to your client when they are near you, so they drop out of range for part of each trip).

- **Automatic calibration**: any arrival you watch near the towers calibrates that route. The first time takes two sightings, later refreshes take one. The cycle length is refined as more arrivals are seen, and the dock-time (how long a transport waits) is learned too.
- **`/ob calibrate`** (optional): watches every transport on purpose. Stand between the two towers where you can see the docks, do not `/reload`, and wait; rows are marked complete as each route is confirmed. A transport being out of view for a while is normal. If nothing at all has been seen after about 10 minutes, move closer to the towers. `/ob calibrate stop` cancels.
- Transports are not reported from deep inside the city (bank / auction house area), so calibrate near the towers.
- **Far ends are learned by riding.** When a transport stands still for 20 s away from its home dock, it is docked at the far end: the addon stores when it docked there (relative to its schedule) and how long it stayed. This needs the home end to have been seen earlier in the same session (for example, it leaving Orgrimmar with you on board), and the transport to be seen arriving. No recording is needed.
- **Server restarts.** A restart starts every transport's schedule over. When you log in, OctoBus quietly asks the server how long it has been up (`.server info`) and so knows exactly when it restarted. Each route docks a set number of seconds into its trip after a restart. These offsets are built in, so even without the DLL every route is set from the restart time at each login. They shift a little at each restart (seconds for most routes, minutes for some), so on their own they are a first guess, shown with `~`.
- **Shared timers.** Every copy of OctoBus joins a hidden chat channel (`OctoBusSync`; nothing from it shows in your chat). A copy with the DLL posts the docking times it has seen since the last restart, and every copy without the DLL takes them, so one DLL user online makes everyone's timers exact for the rest of that server run. Times are sent as seconds since the restart, so differences between players' PC clocks do not matter. Turn it off in the settings window ("Share timers with other OctoBus users"). Until that has been seen to hold across one restart, corrected routes keep the `?` mark. A sighting that jumps by more than drift can explain also counts as a restart.
- **Both ends keep the timers in sync.** Seeing a transport arrive at, or leave, either end of its route re-syncs that route. At the far end this uses the measured far-end timing; if the home end was already seen in the same session, a far-end arrival sharpens the far-end timing instead.
- **One odd sighting does not wipe a route's history.** A sighting that does not fit the schedule is set aside; the schedule only starts over (for example after a server restart) when a second sighting agrees with it.

### The Ratchet boat

The Ratchet boat cannot be seen from Orgrimmar, so its row is always an estimate (`~`) built from the last time you saw it at Ratchet, or from the built-in timing if you never have. The built-in timing was measured over several rides (cycle 363.95 s, 64 s at each dock, docks at Booty Bay 178.6 s after Ratchet). At Ratchet itself the row shows plain docks / leaves times instead of `fly`. Every time you are at Ratchet with the boat in view (the DLL is needed for this), your copy corrects its timing and refines the cycle, so predictions stay accurate for longer the more often you have been there. Nothing is shared between players: each copy only learns from what its own player sees.

`fly` is the boat's departure from Ratchet minus your travel time from Orgrimmar to the dock. Set your own with `/ob travel <seconds>` (default 175: enough for a slower mount, with some time to spare; time your own trip from take-off at the Orgrimmar flight master to standing on the boat).

## Commands

`/ob` (also `/transit` and `/zep`)

| Command | What it does |
|---|---|
| `/ob` | Show / hide the window (works anywhere) |
| `/ob options` | Settings window (also: right-click the minimap icon) |
| `/ob list` | Print all timers in chat |
| `/ob alert <sec>` | Bell alerts fire this many seconds before arrival (default 45, `0` = off) |
| `/ob chat`, `/ob sound`, `/ob flash` | Toggle that alert type (chat on by default; sound and screen flash off) |
| `/ob all` | Switch between routes for where you are and all routes (same as clicking the title) |
| `/ob zone` | Toggle "auto-show only at route ends" (off = always show) |
| `/ob allow <name>` | Also auto-show in this zone or sub-zone |
| `/ob disallow <name>` | Take a place off that list |
| `/ob allowclear` | Remove all the extra auto-show places |
| `/ob where` | Print your zone / sub-zone and whether the window auto-shows here |
| `/ob boat` | Show / hide the Sparkwater <-> Revantusk boat |
| `/ob shape square\|round\|auto` | Minimap icon placement. `auto` reads your minimap shape (tell it explicitly if you use a square minimap addon and the icon sits wrong) |
| `/ob travel <sec>` | Your travel time from Orgrimmar to the Ratchet dock, used for `fly` |
| `/ob scale <n>` | Window size, 0.6 to 2 (same as dragging the bottom-right corner) |
| `/ob lock` | Lock / unlock the window position and size |
| `/ob resetpos` | Put the window and icon back in their default spots and size |
| `/ob name <n> <text>` | Rename the far end of route number `n` (numbers from `/ob list`) |
| `/ob period <n> <sec>` | Set a route's cycle length by hand |
| `/ob calibrate` | Watch all transports on purpose (see above); `/ob calibrate stop` cancels |
| `/ob reset` | Forget everything learned and go back to built-in values |
| `/ob debug` | Print once whether the DLL is answering and the raw data it returns (prints only, records nothing) |
| `/ob debug on` / `off` | For working out new routes only; not needed in normal use. Records every transport the DLL reports to the saved file, which grows quickly, so always turn it off again. `REC` shows in the window while it runs. |

## Troubleshooting

- **Times keep their `~` even after you watch a transport dock**: the DLL is not loaded. Check that `ZepSense.dll` is in the game folder and listed in `dlls.txt`, then fully restart the game. `/ob debug` shows the state.
- **Times have a `~` and never confirm**: go to that end of the route and wait for an arrival, or at the Orgrimmar towers run `/ob calibrate`.
- **A route I want is missing from the window**: you are in the "where you are" view and not at either end of it. Click the title to see all routes.
- **`/ob` does nothing or prints a start-up error**: the addon reports its own load errors in chat; copy the message when reporting a bug.
- **Window did not auto-show**: use `/ob where` to see your zone and sub-zone names, then `/ob allow <name>` if you want it there.
- **Ratchet times look wrong**: it has probably been a long time, or there was a server restart, since you last saw it. Visit Ratchet with the window open and wait for the boat to dock.
- **Everything looks off after a big server change** (new route timings): `/ob reset`, then calibrate again.
