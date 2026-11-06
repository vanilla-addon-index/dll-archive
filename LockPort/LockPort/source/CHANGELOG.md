# Changelog

## 3.9.3

Fixed invalid chat escape errors from coordination messages when joining a group.

## 3.9.2

Keep Groups visible and greyed out until the player joins a raid.

## 3.9.1

Fixed the repository layout so fresh addon-manager installations appear as **LockPort**.

## 3.9.0

- Added the raid-group picker beside the renamed **Auto** button.
- Queue selected groups without requiring chat requests.
- Saved per-character group assignments filter manual and automatic summons.

## 3.8.0

- Added target reservations and acknowledgements for multiple automatic casters.
- Added independent-client simulations and older-version compatibility checks.
- Documented mixed-version and communication-loss limits.

## 3.7.8

Shortened the main action to **Summon** and restored equal button widths after label updates.

## 3.7.7

Matched the Chat and Summon button widths to Options and Add Target.

## 3.7.6

Added the persistent **Chat: On/Off** toggle to mute outgoing announcements and whispers.

## 3.7.5

Added optional ClassicAPI `GetCurrentChatEvent()` support with a legacy fallback.

## 3.7.4

Availability announcements now reset alongside Auto Summon after login/reload;
turning Auto off always clears the announcement option.

## 3.7.3

Added consistent **[LockPort]** prefixes to all outgoing player-facing chat.

## 3.7.2

Updated DLL 1.2.1 to preserve and restore the client command context around native casts.
Automatic summoning was confirmed working in-game with this DLL.

## Earlier updates in this fork

- Added optional Auto Summon with party and raid support.
- Avoided false failure announcements caused solely by an interrupted channel.
- Expanded Options and added ClassicAPI/LockPort detection.

DLL **1.2.1** remains compatible with addon versions 3.7.2 through 3.9.3.
