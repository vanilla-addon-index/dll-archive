<p align="center"><img src=".github/logo.png" alt="PandaConquest Companion logo" width="96"></p>

<h1 align="center">PandaConquest Companion</h1>

<p align="center"><b>The small Windows helper that keeps your PandaConquest war running.</b></p>

<p align="center">Built for the <b>OctoWoW 1.12.1</b> client. Required to play the conquest.</p>

> [!IMPORTANT]
> ## Install
>
> The companion goes with the **PandaConquest addon**. Install the addon first: [PandaConquest](https://github.com/Tom75VN/PandaConquest/releases/latest).
>
> **1. Download**
>
> 1. [Download the latest PandaConquest Companion](https://github.com/Tom75VN/PandaConquest-Companion/releases/latest) (`PandaConquest-Companion-x.y.z-win-x64.zip`).
>
> **2. Extract**
>
> 1. Extract the zip into your **`Wow-Octo` folder**, the one that holds `WoW.exe`.
> 2. You get a `PandaConquest-Companion` folder and `PandaConquestLauncher.dll` right next to `WoW.exe`.
>
> **3. Turn it on once**, either way:
>
> - in the **Octo launcher**, open the mods and tick `PandaConquestLauncher.dll`;
> - or run `PandaConquest-Companion\PandaConquest.Companion.exe` once. Windows SmartScreen may ask for confirmation the first time: choose **More info**, then **Run anyway**.
>
> **4. Play**
>
> 1. Start the game from the **Octo launcher**, with **nampower** and `PandaConquestLauncher.dll` ticked in its mods.
> 2. Log in with a character of level 5 or more, then open PandaConquest with `/pc`.
>
> From now on the companion starts and stops with the game by itself. No account to create, no installer, no window to manage.

## What it is for

PandaConquest is a war fought by many players over many play sessions. The companion is the part that lives **outside the game**, so your conquest does not start from scratch every time you log in.

| | |
|---|---|
| **Keeps your war going** | Your progress and your faction's war are there when you come back, not lost when the game closes |
| **Brings the latest news** | Each time the game starts, you get the current state of the war |
| **Needed to play** | Without it running, PandaConquest pauses the conquest and tells you why |
| **Nothing to manage** | It starts with the game, works in the background, and closes itself afterwards |

## How it works for you

1. You start the game from the Octo launcher: the companion starts with it, in the notification area (next to the clock), with no window.
2. A few seconds later, the latest state of the war reaches the game. **No `/reload` needed.**
3. You play as usual. The companion stays quiet.
4. When you close the game, the companion saves your progress, then closes by itself.

It finds your game accounts, realms and characters on its own. No sign-in, nothing to type.

## The notification-area icon

Right-click the icon next to the clock:

| Entry | What it does |
|---|---|
| **Characters** | Your characters and whether each one is up to date |
| **Refusals** | Anything that could not be accepted, and why |
| **Status…** | Open the status window (a double-click on the icon does the same) |
| **Sync now** | Update right away instead of waiting for the game to close |
| **Choose game folder…** | Point the companion to your `Wow-Octo` folder if it cannot find it |
| **Start with the game** | Tick or untick the automatic start |
| **Open data folder** | Open the companion's settings folder |
| **Quit** | Close the companion |

The icon changes when something needs your attention. Hover over it for a one-line summary.

## Updates

- When a new companion is required, it **downloads and installs itself** while you play. No restart, no `/reload`.
- Your very first update to a companion that can update itself is manual: download the new zip and extract it over the old folder.
- You are told when the addon needs an update too. Keep both up to date.

## If something is wrong

| You see | Do this |
|---|---|
| PandaConquest says the conquest is paused | Start the game from the Octo launcher with `PandaConquestLauncher.dll` ticked; or run `PandaConquest.Companion.exe` |
| No icon in the notification area | Click the small arrow next to the clock: Windows may hide it there |
| "Choose game folder" appears | Pick the `Wow-Octo` folder, the one with `WoW.exe` |
| A character shows "not synced" | Update the PandaConquest addon, then log in with that character once |
| SmartScreen warns you | **More info**, then **Run anyway**: the companion is not code-signed yet |

## Uninstall

1. Untick `PandaConquestLauncher.dll` in the Octo launcher's mods.
2. Quit the companion from its icon.
3. Delete the `PandaConquest-Companion` folder and `PandaConquestLauncher.dll`.

Without the companion, PandaConquest pauses the conquest.

## Good to know

- **Windows only for now**: Linux and macOS versions are planned.
- **OctoWoW only**: the companion works with the OctoWoW client.
- **Always launch from the Octo launcher** with nampower and `PandaConquestLauncher.dll` ticked.
- **Alpha**: PandaConquest is in early testing. Things may still change.

## Version

See the [releases](https://github.com/Tom75VN/PandaConquest-Companion/releases) for the latest version and what changed. Each release comes with its SHA-256 checksum.

## Acknowledgements

The companion is the other half of [PandaConquest](https://github.com/Tom75VN/PandaConquest).

World of Warcraft is a trademark of Blizzard Entertainment. This project is not affiliated with or endorsed by Blizzard Entertainment.
