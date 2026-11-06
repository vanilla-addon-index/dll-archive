# Building MPQ Patches for WoW 1.12.1

Reference for packaging files (addons, FrameXML overrides, art) into an
MPQ patch archive that vanilla 1.12 picks up at boot. Captured because
the MPQEditor docs are sparse, the script syntax is non-obvious from
the GUI, and there's a 1.12 patch-MPQ naming constraint that's easy to
miss.

## When this matters

Useful when you want files to:

- **Auto-load before user addons** — engine reads MPQs in `<WoW>\Data\`
  early in boot, alongside FrameXML. Anything in
  `Interface\AddOns\<name>\` inside an MPQ enumerates just like a
  filesystem-resident addon, but loads earlier than addons living in
  `Interface\AddOns\` on disk.
- **Be tamper-resistant** — users can't accidentally disable an
  MPQ-resident addon from the in-game addon list (it's not in the
  filesystem `Interface\AddOns\` they can browse to).
- **Override engine UI** — drop `Interface\FrameXML\<name>.lua` /
  `Interface\FrameXML\<name>.xml` files to add or modify FrameXML.
  This is how the 3.3.5 reference for `/dump`, `/framestack`,
  `/etrace` lives in `ChatFrame.lua` — it could be replicated here
  via a small `Interface\FrameXML\AddedSlashCommands.xml` MPQ insert
  that calls `UIParentLoadAddOn` for backported tools.

Confirmed empirically (1.12.1):

| Test                                    | Result |
|-----------------------------------------|--------|
| Plain (non-Blizzard_-prefixed) addon in MPQ, auto-discovered | ✅ engine sees it via enum |
| Plain addon in MPQ, auto-loads on login | ✅ |
| `Blizzard_*` addon in MPQ, no `.toc.sig` | ❌ engine refuses (signature check is name-based, not location-based) |
| `Blizzard_*` addon on filesystem, no `.toc.sig` | ❌ same — refusal applies regardless of MPQ vs filesystem |

So MPQ residency is no help for `Blizzard_*` names — those need a
separate signature-bypass approach (see `mpq-test/HANDOFF.md` for the
hook target).

## Tooling

We use Ladik's **MPQ Editor** (`MPQEditor.exe`), which ships with a
MoPaQ 2000 script interpreter. Run with `/console <script>` to execute
a build script. CLI form is also supported but the script form is more
useful for repeatable builds.

```
MPQEditor.exe /console build.txt
```

Get help on individual commands with `help <command>` inside a script
or interactive console (e.g., `help add`).

## Filename constraint

Vanilla 1.12's MPQ loader **only accepts patch archives matching the
single-character `patch-X.mpq` form**. Names with multi-character
suffixes are silently rejected.

| Name                                   | Loads? |
|----------------------------------------|--------|
| `patch-Z.mpq`                          | ✅     |
| `patch-3.mpq`                          | ✅ (clashes with stock — avoid) |
| `patch-Z-myproject.mpq`                | ❌     |
| `patch-myproject.mpq`                  | ❌     |
| `myproject.mpq`                        | ❌     |

Use letters past Blizzard's stock range (Z, Y, X, W…) so your patch
sorts after their MPQs and overrides take precedence on conflict. The
exact ordering is alphabetical with later entries winning.

## Script syntax

Build scripts are plain text, one command per line. Quote any path
containing spaces. Important commands:

| Command | Form | Notes |
|---------|------|-------|
| `new`   | `new <mpq> [<maxFiles>]` | Create new archive. Default file limit is `0x1000`; set higher if you'll add lots of files. |
| `open`  | `open <mpq>` | Open an existing archive for modification. |
| `add`   | `add <mpq> <sourceFile> <archivePath> [/options]` | First arg is the MPQ — NOT implicit from a prior `open`. Source can include wildcards; with `/r` it walks subdirectories preserving structure. |
| `extract` | `extract <mpq> <mask> <destDir> [/fp]` | Extract files matching mask. `/fp` preserves full path. |
| `list`  | `list <mpq>` | Print archive contents. |
| `close` | `close` | Close currently open archive (auto-runs at script end). |

`add` flags worth knowing:

- `/r` — recurse subdirectories.
- `/auto` — pick compression by file type. Use this for mixed
  text/binary trees.
- `/c` — force compression.
- `/wave` — add as WAVE file (sound-specific).

## Working example

The script we used to build the test MPQ for empirical verification:

```text
new C:\Git\ClassicAPI\mpq-test\patch-Z.mpq 64
add C:\Git\ClassicAPI\mpq-test\patch-Z.mpq "C:\Git\ClassicAPI\mpq-test\Interface\*" "Interface" /r /auto
close
```

What it does:

1. Creates `patch-Z.mpq` with a 64-file capacity hint (small).
2. Walks `mpq-test\Interface\` recursively (`/r`), adds every file
   under it to the archive at the matching `Interface\...` path.
   `/auto` picks LZ compression for `.lua` / `.toc` and stores
   binaries uncompressed.
3. Closes the archive.

Run via:

```
"C:\WoW\MPQEditor.exe" /console "C:\Git\ClassicAPI\mpq-test\build.txt"
```

The fixture lives in `mpq-test/` for reference — it contains two stub
addons (`ClassicAPITest_Plain`, `Blizzard_ClassicAPITest`) used to
prove the enum-from-MPQ vs SIG-check claims in the table above.

## Pitfalls we hit

1. **`add` opens its first arg as an MPQ.** If you forget the MPQ
   path and pass `add <source> <target>`, MPQEditor tries to open
   `<source>` as an MPQ archive and fails with "Failed to open the MPQ
   ... An attempt was made to load a program with an incorrect
   format." Always: `add <mpq> <source> <target>`.

2. **`new` doesn't keep the MPQ "open" for subsequent commands.**
   Each `add` re-opens by name. Don't rely on implicit state
   carrying across commands.

3. **`patch-Z-foo.mpq` won't load.** Multi-character suffixes after
   `patch-` get rejected silently — no log entry, no error. If your
   addon doesn't appear, first thing to check is the MPQ filename.

4. **`Blizzard_*` addons go through SIG verification regardless of
   where the TOC lives.** Putting `Blizzard_DebugTools` inside an MPQ
   doesn't bypass the `.toc.sig` check. The signature gate is keyed
   on the name prefix, not the file's storage backend.

## Deploying

Drop the built MPQ into `<WoW root>\Data\` and launch normally:

```powershell
Copy-Item "C:\Git\ClassicAPI\mpq-test\patch-Z.mpq" "C:\WoW\Octo\Data\"
```

After login, verify the addon enumerates:

```
/dump GetAddOnInfo("YourAddOnName")
```

If it returns data, the engine sees it. If `nil`, check the MPQ name
constraint and the internal directory layout.

## See also

- `mpq-test/HANDOFF.md` — the addon SIG-bypass research that motivated
  this MPQ exploration. Includes the verifier function offset, hook
  approach, and risk analysis for a separate DLL project.
