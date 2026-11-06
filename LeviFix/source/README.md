# LeviFix

Stops the **ERROR #132** crash that happens when a player near you starts levitating.

For **WoW 1.12.1, client build 5875** only.

---

## Do I need this?

**If you play through the OctoWoW launcher: no.** The launcher already applies this
same fix directly to `WoW.exe` every time it updates. There is nothing to install and
nothing to turn on.

**If you run the client yourself, without the launcher: yes.** Nothing else is
protecting you, and one priest levitating nearby can drop you out of the game.

---

## What it fixes

Every character animation has a number. Running is 0, walking 1, standing 2,
falling 35, and hovering is 137.

Your character model has around 150 animations. The things you *wear* (helm,
shoulders, cape, weapon) are separate small models, and the client keeps them in
sync by telling each one: *play the same animation number as your wearer.*

A helm does not have 150 animations. Most have exactly one. Its table is one entry
long.

Nobody checks whether the number fits the table. The helm is told "play number 137",
and the client counts 137 entries forward from a table that ended after one, landing
in memory belonging to something else entirely and reading whatever happens to be
there. That value is then used as a position. Usually it is obvious nonsense and gets
rejected. Sometimes it is a huge number, the client reads an address a gigabyte away
that does not exist, and Windows kills the game.

This is why the crash:

- hits **bystanders**, never the person who cast the spell, whose own model has all
  the animations,
- depends on what the levitating player is **wearing**,
- happens **sometimes** rather than every time,
- takes out **several people at once**, since everyone watching reads the same bad
  table.

LeviFix adds the missing check. When the animation number does not fit the table, it
returns exactly what the client itself returns for an empty table: first keyframe, no
blending. The attachment holds a frame. Nothing else changes, and nothing is visible
in game.

---

## Requirements

- WoW **1.12.1**, client build **5875**
- A `dlls.txt` loader: **VanillaFixes**

If you already use nampower, SuperWoW, UnitXP or transmogFix, you have VanillaFixes
already and `dlls.txt` exists.

---

## Install

1. Put `levifix.dll` in your WoW folder, next to `WoW.exe`.

2. Open `dlls.txt` in that same folder and add a line:

   ```
   levifix.dll
   ```

   If `dlls.txt` does not exist, create it with that single line in it.

3. Start the game through **`VanillaFixes.exe`**, not by running `WoW.exe` directly.
   Launching `WoW.exe` on its own loads no DLLs at all and the fix will not be active.

4. Restart the client completely. A `/reload` is not enough.

To turn it off again, put a `#` in front of the line in `dlls.txt`, or delete the DLL.

---

## Checking that it works

On startup LeviFix writes **`levifix.txt`** next to `WoW.exe`:

```
levifix=1
status=installed at 0x00713D50
prevented=0
worst_index=0
```

- **`status`**: `installed at ...` means the fix is active. Anything starting with
  `refused:` means it patched nothing; see Safety below.
- **`prevented`**: how many out-of-range lookups it has refused. Each one is a read
  that would otherwise have gone past the end of a table.
- **`worst_index`**: the largest out-of-range animation number seen so far. Expect
  **137** to appear after someone levitates near you.

The file is rewritten every few seconds while the count changes.

---

## Safety

Before patching anything, LeviFix compares the six bytes at the target address against
what it expects to find. If they differ (a different client build, a game update, or
another mod that got there first) **it patches nothing at all** and records the reason
in `levifix.txt`. It cannot corrupt a client it does not recognise.

It hooks exactly one function, changes six bytes **in memory only, never on disk**,
touches no game files, sends nothing anywhere, and has no effect on gameplay. The only
observable change is that an attached model can hold a single animation frame instead
of the game crashing.

It does **not** fix the underlying bug. That is in the client, and only the client
authors can fix it properly. It stops the crash at the last moment. If a different
crash appears, check `status` in `levifix.txt` first, and disable the DLL to rule it
out.

### Antivirus

`levifix.dll` is unsigned, and it modifies a running process in memory. Some scanners
flag that pattern heuristically. Verify the download against the checksum below before
using it.

---

## Verifying your download

```
SHA-256  4059caa60e92536efaa988612565b64389a5497dd0505728d7e0414215d3f3ef  levifix.dll
```

Windows:

```powershell
Get-FileHash levifix.dll -Algorithm SHA256
```

Linux / macOS:

```sh
sha256sum levifix.dll
```

If the hash does not match, do not use the file.

---

## Technical detail

- Faulting instruction: `0x00713DFF`, `mov ebx, [ecx+edx*4]`, inside `sub_00713D50`.
  That function receives an M2 animation track (confirmed by the
  `word [track+2] == 0xFFFF` global-sequence test at `0x713D96`) plus an animation
  index.
- It loads the track's entry count from `[track+4]`, tests it **only against zero**,
  and then indexes an 8-byte-stride range table at `[track+8]` with the animation
  index, without ever comparing the two. The only follow-up check is `start < end`,
  and both of those come from the same, possibly out-of-bounds entry, so two garbage
  values in ascending order pass it.
- The index arrives from the model instance's field `+0x9C`, which at `0x00714650` is
  copied verbatim from another model instance: an attachment inherits its wearer's
  animation index with no regard for its own animation count.
- Measured across one installation: of 4502 attachment models, 3837 have exactly one
  animation, and 305 have at least one animation track shorter than index 137. Of the
  1239 short tracks, reading at index 137 yields a value that passes the `start < end`
  check and is large enough to fault in about 17% of cases, which is why the crash is
  occasional rather than constant.
- The hook refuses the lookup and returns `{0, 0, 0.0f}`, matching the client's own
  degenerate-range path at `0x00713D7F`.

---

## Licence

MIT. See [LICENSE](LICENSE).
