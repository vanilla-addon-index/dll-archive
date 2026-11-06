// This file is part of ClassicAPI.
//
// ClassicAPI is free software: you can redistribute it and/or modify it under the terms
// of the GNU General Public License as published by the Free Software Foundation, either
// version 3 of the License, or (at your option) any later version.
//
// ClassicAPI is distributed in the hope that it will be useful, but WITHOUT ANY
// WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR
// PURPOSE. See the GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License along with
// ClassicAPI. If not, see <https://www.gnu.org/licenses/>.

#pragma once

// Shared account-level settings file: `WTF\Account\<account>\ClassicAPI.txt`.
// Multiple modules persist scalar state here; each declares an
// `AutoRegister` at static-init time and the registry coordinates
// load/save so no module clobbers another's lines.
//
// Module shape:
//
//   namespace { // in MyModule.cpp
//   void Reset()                                  { /* defaults */ }
//   void Serialize(std::ostream &out)             { out << "MyKey=" << g_val << "\n"; }
//   bool Parse(const std::string &k, const std::string &v) {
//       if (k == "MyKey") { g_val = ...; return true; }
//       return false;
//   }
//   static const Settings::Account::AutoRegister
//       _section{&Reset, &Serialize, &Parse};
//   } // namespace
//
// Then call `Settings::Account::EnsureLoaded()` before reading state and
// `Settings::Account::Save()` after mutating it.
//
// The registry re-loads when the engine's `VAR_ACCOUNT_NAME_PTR` changes
// (autologin switch on the glue screen) — each section's `Reset` runs
// first, so stale state from the previous account is cleared before
// the new account's lines are parsed.

#include <iosfwd>
#include <string>

namespace Settings::Account {

// Each `AutoRegister` is both the consumer's declaration and the
// list node — mirrors `Game::ModuleAutoRegister`. Three callbacks:
//
//   `reset`     — restore the module's defaults (called before the file
//                 is read or re-read after an account change).
//   `serialize` — append the module's `key=value` lines to the output
//                 stream. Called for every Save; the registry writes a
//                 header comment then invokes each section in
//                 registration order.
//   `parse`     — consume one `key=value` pair. Return true if the
//                 module recognized the key (so the registry doesn't
//                 ask other sections about it). Return false to let
//                 the line fall through; the registry drops unmatched
//                 lines silently.
//
// Order across translation units is undefined (LIFO of static-init).
// Modules must not depend on each other's reset/parse side effects.
struct AutoRegister {
    using ResetFn = void (*)();
    using SerializeFn = void (*)(std::ostream &out);
    using ParseFn = bool (*)(const std::string &key, const std::string &value);

    AutoRegister(ResetFn reset, SerializeFn serialize, ParseFn parse);

    ResetFn reset;
    SerializeFn serialize;
    ParseFn parse;
    AutoRegister *next;
};

// Reads `ClassicAPI.txt` for the current account if not already loaded
// for it. Re-reads from scratch if the active account has changed since
// the last call. Returns true once the file has been processed (even
// if it didn't exist — first-run is a successful "loaded as empty").
// Returns false when no account name is set yet (pre-login).
bool EnsureLoaded();

// Re-serializes every registered section to disk atomically (.tmp +
// remove + rename). Returns false if no account is set, the file
// couldn't be opened, or the rename failed.
bool Save();

// `WTF\Account\<account>\ClassicAPI.txt`, or empty string when no
// account is set. Exposed for diagnostic / probe modules.
std::string Path();

} // namespace Settings::Account
