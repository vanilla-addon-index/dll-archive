# LockPort

Warlock summoning for World of Warcraft 1.12 / Turtle WoW 1.18.
This fork adds Auto Summon, raid-group assignments, and multi-warlock coordination.

**Addon:** 3.9.3 · **Optional client mod:** LockPort.dll 1.2.1

[Changelog](CHANGELOG.md)

**3.9.3:** Fixed invalid chat escape errors when joining a group.

## Installation

Download the installable ZIP, extract it, and copy the **LockPort** folder
into **Interface/AddOns**.
The installed files should look like this:

```text
Interface/AddOns/LockPort/
    LockPort.toc
    LockPort.lua
    LockPort_UI.lua
    Bindings.xml
```

The companion DLL goes into the folder where WoW.exe goes (Add it to the dlls.txt)

Manual summoning works without the companion DLL. For Auto Summon, follow the
[VanillaFixes installation instructions](native/README.md). Existing DLL 1.2.1
users do not need to replace it.

## Getting started

1. Join a party or raid on a warlock.
2. Group members request a summon by starting a say, yell, whisper, party, or
   raid message with **123**. Request words are configurable in Options.
3. Click **Summon**, a player's name, or your Summon Next hotkey.
4. Two helpers click the portal, and the summoned player accepts the prompt.

The window shows Soul Shards, nearby helpers, and each request's status.
Summon picks warlocks first, then the oldest eligible request. It skips players
who are offline, dead, in combat, blocked by an instance check, outside your
selected raid groups, or claimed by another warlock.

| Control | Action |
|---|---|
| Summon | Summon the next eligible player |
| Left-click a name | Summon that player |
| Ctrl+click a name | Target the player |
| Right-click a name | Remove the request |
| Add Target | Add your current target to the list |
| Chat: On/Off | Mute or restore all outgoing announcements and whispers |
| Options | Configure messages, sounds, hotkey, window style, and other settings |

Chat Off keeps requests, summoning, and hidden addon coordination working.
Its setting survives reloads. The window can be moved or locked; Classic and
pfUI styles are available in Options.

## Auto Summon

With compatible **LockPort.dll 1.2.1** installed, **Auto** appears below Add
Target. Enable it to process eligible requests without clicking or pressing a
hotkey. It waits for two nearby helpers, Soul Shards, and a ready target.
ClassicAPI supplies movement and active-cast checks when available.

Helpers still click the portal, and the target still accepts the summon.
Auto turns off when you leave the group or reload. Enabling it also enables
availability announcements; disabling it turns those announcements off.

## Group summoning

**Groups stays visible beside Auto and is greyed out until you join a raid.**
Group selection works for manual summoning without the companion DLL too.

1. Click **Groups** and select any of raid groups **1–8**.
2. Click **Queue selected groups** to add online, living players who are not
   already nearby. They do not need to type 123.
3. Use **Summon**, or enable **Auto** to process them automatically.

For raid skips, each warlock can select a different assignment, such as groups
1–2 for one and 3–4 for another. A warlock left on **All groups** can still
summon from any group. Queueing players does not enable Auto by itself.

The default is **All groups**, with All/None shortcuts in the picker. Selections
are saved per character and apply to manual and automatic summons using each
player's current raid group. Other requests remain visible as **Other group**.
Selections are ignored in parties and do not interrupt a ritual already started.

## Multiple warlocks

Updated Auto Summon users reserve targets, acknowledge each other's reservations,
and resolve conflicts before casting. Overlapping group assignments use the
same coordination. Failed or expired reservations allow another warlock to try.

Use **3.8.0 or later on every automatic caster**, and 3.9.0 or later for group
assignments. Older versions still share compatible summon lists and claims,
but simultaneous automatic casts with older versions can overlap. Complete
communication loss can also defeat coordination.

Multi-warlock coordination and group assignments have passed simulations;
live multi-client validation is still pending. See the [test report](tests/COORDINATION-REPORT.md).

## Messages and announcements

All outgoing chat starts with **[LockPort]**. Summon announcements and whispers
are sent after the ritual starts. Confirmed failures explain what prevented
the summon; an interrupted channel alone is treated as an uncertain result.
Status whispers explain repeat requests and queue position.

Options also control requests for nearby helpers and periodic
**Summons are available — type 123** announcements. Availability announcements
start off after login or reload, including when previously enabled manually.
Use **Chat: Off** to silence outgoing chat while travelling.

Raid instance checks use English zone names from the raid roster; that check
is unavailable in parties. Repeated failures are throttled to reduce spam.

## Commands

| Command | Action |
|---|---|
| `/lockport` | Show or hide the window |
| `/lockport next` | Summon the next eligible player |
| `/lockport add [name]` | Add a name or your current target |
| `/lockport remove <name>` | Remove a request |
| `/lockport clear` | Clear the list |
| `/lockport show` | Print the list |
| `/lockport options` | Open Options |
| `/lockport available` | Toggle availability announcements (`open` is an alias) |
| `/lockport message <text>` | Set a custom message; tokens: `{name}`, `{zone}`, `{shards}` |
| `/lockport message clear` | Reset the custom message |
| `/lockport mods` | Show detected client mods |
| `/lockport debug` | Show casting and coordination diagnostics |
| `/lockport style` | Switch Classic/pfUI style; requires reload |
| `/lockport reset` | Reset the window position |
| `/lockport help` | Show commands and setting toggles |

Bind **Summon Next** in Options or WoW's Key Bindings menu.

## Optional client mods

| Mod | Used for |
|---|---|
| LockPort.dll 1.2.1 | Native casting for Auto Summon |
| ClassicAPI | Movement, active-cast checks, and reliable chat payloads when available |
| SuperWoW | GUID-matched cast events, Evil Twin detection, and distance checks |
| Nampower | Additional server-confirmed spell-failure events |
| UnitXP SP3 | Precise distances and taskbar flashing |

The DLL targets the inspected **32-bit OctoWoW 1.18.1** client signatures and
requires Lua-registration support from Nampower, SuperWoW, or ClassicAPI. Load
LockPort.dll after those mods. See [client compatibility and build details](native/README.md).

## Credits and development

Originally written by **Gurky**, maintained by **Phaestas**, and extended in this
fork by **OEVG2**. Based on [Phaestas323/LockPort](https://github.com/Phaestas323/LockPort).

- [Changelog](CHANGELOG.md)
- [Coordination tests and known limits](tests/COORDINATION-REPORT.md)
- [ClassicAPI review](CLASSICAPI-REVIEW.md)
- [DLL source, build, and test instructions](native/README.md)
