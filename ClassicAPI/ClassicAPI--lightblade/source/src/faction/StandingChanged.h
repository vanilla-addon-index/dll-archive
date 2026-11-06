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

namespace Faction::StandingChanged {

// Hook for `FUN_REPUTATION_FIRE_NOTIFY` (0x0062C5F0) — the engine's
// per-rep-change notify dispatcher. Fires `FACTION_STANDING_CHANGED`
// custom event with `(factionID, newStanding)` payload, then forwards
// to the original so the engine's `CHAT_MSG_COMBAT_FACTION_CHANGE`
// chat event still fires normally.
//
// `__fastcall(ecx = factionID, edx = signedDelta)` — args go in
// registers, no stack args.
using FireNotify_t = void(__fastcall *)(int factionID, int delta);
extern FireNotify_t FireNotify_o;
void __fastcall FireNotify_h(int factionID, int delta);

// Snapshot of the currently-firing rep change, valid only during the
// call stack rooted at `FireNotify_h`. `C_Reputation.GetLastStandingChange`
// reads this — observers of the engine's CHAT_MSG_COMBAT_FACTION_CHANGE
// (fired by `FireNotify_o`) and of our own `FACTION_STANDING_CHANGED`
// (fired immediately after) see `valid == true`; everything outside
// that window sees `valid == false` and the Lua getter returns nil.
struct LastChange {
    bool valid;
    int factionID;
    int newStanding;
    int delta;
};

const LastChange &Last();

} // namespace Faction::StandingChanged
