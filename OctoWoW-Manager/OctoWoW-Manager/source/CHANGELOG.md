# Changelog

## 3.0.4 — 2026-11-22 (local custom build)

- Added DucielPerf v0.9.39 to Recommended Core. Apply removes the entries for weirdperformance, transmogfix, worldmarkers and Interact from the plugin load list and keeps the old files on disk.
- Recommended nampower now bundles brues-code build 99d8d36. The source picker still offers the GitHub release separately.
- Client Tweaks shows full plugin filenames at narrow widths and includes the name and description on hover.

### Client Tweaks and Custom Patches

- Use MarcelineVQ v0.7.0 as the sole source for the five WeirdUtils mods to avoid a launch crash seen with Dusk’s builds and DucielPerf. Removed the Custom Patches sidebar count.
- Made the recommended nampower the only DLL bundled from the Client Tweaks catalog. Other mods download on Apply. PerfBoost and no1600x1200 use the RetroCro archive.
- Added Latest (Dusk) and Original (MarcelineVQ v0.7.0) sources for the five WeirdUtils mods.
- Stacked the Client Tweaks panels, added descriptions to the mod rows, and moved patch switches to the left. Both pages share the same credits panel.

- Added installed DLL version labels, refreshed bundled Client Tweaks DLLs, and added AuctionQueryThrottle, Lexara112, and OctoLogin as optional upstream downloads.
- Switched the WeirdUtils update source to Dusk’s releases. SuperWoW now bundles the verified 2.2 DLL. Nampower Recommended remains the 4.6.1 99d8d36 Brues-Code build.
- Renamed Game Mods to Custom Patches and labeled the remote check Check Custom Patches Updates.

### Patch-O and Addons changes from November 6

- Moved Patch-O into Visual and removed the empty Client category.
- Compare direct-download MPQs against actual upstream file contents. Ignore HTTP revision/header differences and legacy receipt revisions when determining whether Patch-O needs an update. Unavailable or invalid downloads report an unavailable check rather than an update.
- Replaced the persistent Reinstall / Track button with a disabled Up to date state for current managed mods. Existing unmanaged mods show Track; Update is reserved for detected differences. Disable install actions until their initial check completes.
- Removed the Addons tab, its mounted page, background sidebar addon scan, and ZIP addon drag-and-drop handling. Plugin companion addons and existing addon files are preserved; use Git Addon Manager for addon management.
- Added regression coverage for restart checks, changing ETags with identical bytes, disabled patches, same-size content updates, HTTP errors, invalid MPQ downloads and Windows file locks.

Validation: 35 tests passed, including local HTTP/file-lock regressions. A read-only comparison of the installed Patch-O against the official download returned Up to date. No live game files were modified.

### Earlier additions from November 6

- Added Cross-Faction Res Fix, Automatically Clear WDB, Unlimited AddOn Script Memory and Bluemoon switches to Environment & Quality of Life. These new options default to off for existing and new settings.
- Kept the existing FoV calculator: its aspect-ratio formula already matches Modernization Tool.
- Detect SuperWoWhook.dll, disable and gray out Always Auto-Loot / Background Sounds, and skip their executable patches during Apply when the hook is present.
- Added a Game Mods catalog with separate Client, Visual and Audio groups. Includes official Patch-O, Darker Nights, Pretty Night Sky, Epoch Water, Fog Pushback, Pink Herbs, NoErrorSounds, FishPing and Warlock Muted Demons. Descriptions are also available on hover.
- Check Patch-O against https://dl.octowow.st/client/latest/Data/patch-O.mpq. Compare existing unmanaged MPQs by content; track managed updates by upstream revision / HTTP validators, with content-hash fallback when validators are unavailable.
- Added amber update arrows and manual checks for supported DLL sources and catalog mods; unavailable checks are identified explicitly. DLL arrows indicate that the latest upstream binary differs, including an unknown/custom local version; they do not claim that a custom local binary is older.
- Added matching standalone WeirdUtils release lookups from Codeberg. Missing individual release assets are reported as unavailable, never replaced with a differently named DLL. Latest downloads require valid Windows PE headers.
- Back up previous files when installing catalog mods, restore original loose sound files on disable, validate mod paths and downloads, and roll back failed file swaps. Catalog-controlled MPQs are hidden from the custom MPQ list to keep their state consistent.
- WDB clearing parks the former cache in a recovery directory and creates a Manager-owned blocker; switching it off removes only that owned empty blocker. Unlimited memory writes SET scriptMemory "0"; turning it off leaves the current value unchanged, matching Modernization Tool.

Validation: TypeScript / Vite production build; Rust offline unit tests; all nine catalog downloads installed and toggled off/on in temporary folders. No live game files were changed. In-game effects and visual UI inspection remain unverified (Windows UI automation stopped because it could not confidently determine the browser URL).
