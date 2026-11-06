# Octo GlueXML

Custom login and character-select UI for [Octo](https://octowow.st). Overlays
a small subset of the stock glue files with three features; everything else in
`Interface/GlueXML/` is loaded unchanged from the base MPQs.

## Features

- **Saved-account login.** The login screen shows a scrollable list of
  previously-used accounts with their last-used timestamp. Clicking a row fills
  the account name and hides the password field; a login without a typed
  password logs in using the credential stored in the Windows Credential
  Manager. A "Change password" button reveals the field on demand when you
  need to update a saved credential.
- **Character reordering.** Hold on a character in the select screen for half
  a second to enter drag mode, then move it up or down. Order is saved
  per-realm and restored on the next login.

## ClassicAPI dependency

The saved-login and character-order features rely on Lua bindings exposed by
the ClassicAPI DLL, which is loaded alongside the client. Both features guard
their entry points with `type(fn) ~= "function"` checks so the UI still
functions when the DLL isn't present — you just lose persistence.

### Saved login — Windows Credential Manager

Passwords never live in Lua or in `WTF/`. They go straight from the password
field into the OS credential vault, and login submits are dispatched from C so
the plaintext never crosses back.

| Binding | Purpose |
|---|---|
| `SaveAccount(name, password)` | Writes a credential-vault entry. Called when the user types a password (either a first-time save or a "Change password" update). |
| `LoginWithSavedAccount(name)` | C-side dispatch of the login using the vault password for `name`. |
| `GetSavedAccounts()` | Returns `{ {name=…, lastUsed=epochSeconds}, … }` — `lastUsed` is the Windows `LastWritten` timestamp on the vault entry, auto-refreshed by `LoginWithSavedAccount`. |
| `DeleteAccount(name)` | Removes a vault entry (backs the "Remove account" button). |
| `GetSavedAccountName()` / `SetSavedAccountName(name)` | Persists just the *last-used* account name (via `SavedVariables`) so the same row is pre-selected on next launch. No password, no character map — those were dropped alongside the plaintext store. |

### Character sort order — per-realm WTF persistence

Persistence is keyed by character *name*, not by server-assigned charID. Slots
renumber every time a character is added or deleted, so name is the only
stable identifier.

| Binding | Purpose |
|---|---|
| `GetSavedCharacterOrder(realm)` | Reads a `\|`-separated name string for the current realm. |
| `SetSavedCharacterOrder(realm, names)` | Writes it back. |

On every `CHARACTER_LIST_UPDATE` the code loads the saved string, resolves
each name to the current charID, drops names the server no longer knows about
(deletions), appends any characters not in the saved list (creations), and
re-saves. That means the on-disk order self-cleans without a hook in the
delete path.

## Releases

Push a `v*` tag to trigger the
[mpq-packager](https://octowow.st/git/paste/mpq-packager) Gitea Action
(`.gitea/workflows/release.yml`), which packages this repo into a
`patch-Z.mpq` via StormLib according to `mpq.yaml`. `Z` sorts after Blizzard's
stock MPQs, so its files win on conflict. Only `.lua`, `.xml`, and `.toc`
files are placed in the MPQ — this README, workflow files, and build config
are excluded.
