# Per-character session globals (vanilla 1.12.1)

The engine keeps the **active account / realm / character** in three statics
that the SavedVariables path-builder reads to format
`WTF\Account\<account>\<realm>\<character>\<file>`. If a DLL needs to write
per-character files outside the SavedVariables system (e.g. its own config),
these are the canonical sources — they match exactly what the engine uses
itself, so the file lands next to `AddOns.txt`, `bindings-cache.wtf`, etc.

| VA           | Layout                                            | Holds                                                                |
|--------------|---------------------------------------------------|----------------------------------------------------------------------|
| `0x00BE1C0C` | `*(char**)`                                        | Pointer to the active account name string                            |
| `0x00C28130` | `*(struct**)` — field at `+0x20` is `char *`       | Pointer to a session struct whose `+0x20` is the realm name          |
| `0x00C27D88` | inline `char[]` buffer                             | Active character name. First byte `'\0'` ⇒ no character logged in   |

```cpp
const char *Account()    { return *reinterpret_cast<const char *const *>(0x00BE1C0C); }
const char *Realm()      {
    auto *p = *reinterpret_cast<uint8_t **>(0x00C28130);
    return p ? *reinterpret_cast<const char *const *>(p + 0x20) : nullptr;
}
const char *Character()  {
    auto *p = reinterpret_cast<const char *>(0x00C27D88);
    return (p[0] == '\0') ? nullptr : p;
}
```

## Lifecycle

All three are zero/empty at process start. The engine populates them as the
player progresses through the boot sequence:

| Stage                  | Account | Realm | Character |
|------------------------|---------|-------|-----------|
| Process start          | empty   | empty | empty     |
| Login screen           | filled  | empty | empty     |
| Realm selected         | filled  | filled| empty     |
| Character entered world| filled  | filled| filled    |

By the time `ADDON_LOADED` fires for any addon, all three are populated. A
DLL doing per-character lazy initialisation can read them directly off the
first `Script_*` Lua call after login — no need to hook `PLAYER_LOGIN` or
intercept `FrameScript_SignalEvent2`.

The `0x00C27D88` buffer doubles as the "is a character active" flag — the
session-getter at `0x005A6DC0` returns `0x00C27D88` when its first byte is
non-zero, and `NULL` otherwise. So a single byte read at `0x00C27D88` is the
canonical "in world?" check.

## Where the engine itself reads these

The path-builder at `0x0051EBE0` (which writes `AddOns.txt` and other
per-character WTF files) reads exactly these three globals:

```asm
; inside the per-entry loop at ~0x0051ECC0:
mov  edi, [ebp-0x14]            ; this  ⇒ character name pointer (≈ 0x00C27D88)
push edi                        ; %s #3 → character
call <helper @ 0x005AB7D0>      ; reads  0x00C28130 → +0x20 → realm string
push eax                        ; %s #2 → realm
mov  eax, [0x00BE1C0C]
push eax                        ; %s #1 → account
push offset 'WTF\Account\%s\%s\%s\AddOns.txt'  ; format @ 0x00853948
```

So the format string's `%s, %s, %s` are `account, realm, character` in that
order — same order to use when building any custom path that should land in
the engine's per-character WTF directory.

## Cross-references

- Path-builder function: `0x0051EBE0`
- Realm-getter helper:   `0x005AB7D0` (caches struct ptr at `0x00C28130`)
- Active-session check:  `0x005A6DC0` (returns `0x00C27D88` or `NULL`)
- Format strings in `.data`:
  - `0x00853948` — `WTF\Account\%s\%s\%s\AddOns.txt`
  - `0x008539B0` — `WTF\Account\%s\%s\%s\SavedVariables\%s.lua`
  - `0x00853A10` — `WTF\Account\%s\%s\%s\SavedVariables` (directory only)
- *Not* this: `0x008826C8` is the saved-credentials buffer used by
  `Script_GetSavedAccountName` — that's a multi-line CVAR-style string of
  recently-logged accounts, not the active session's identity.
