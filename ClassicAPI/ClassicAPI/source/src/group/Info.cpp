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

#include "Game.h"
#include "Offsets.h"

#include <cstdint>

namespace Group::Info {

namespace {

bool InRaid() {
    return *reinterpret_cast<const int *>(
               static_cast<uintptr_t>(Offsets::VAR_RAID_MEMBER_COUNT)) > 0;
}

bool InParty() {
    auto *guids = reinterpret_cast<const uint64_t *>(
        static_cast<uintptr_t>(Offsets::VAR_PARTY_GUIDS));
    for (int i = 0; i < Offsets::PARTY_MAX_SLOTS; ++i) {
        if (guids[i] != 0)
            return true;
    }
    return false;
}

} // namespace

// `IsInRaid()` — true iff the local player is in a raid group.
// Modern signature takes an optional `groupType` (Home / Instance);
// vanilla has no LFG/LFD instance-group concept, so we accept and
// ignore the argument.
static int __fastcall Script_IsInRaid(void *L) {
    Game::Lua::PushBool(L, InRaid());
    return 1;
}

// `IsInGroup()` — true iff the local player is in a party OR a raid.
// Same `groupType` argument story as `IsInRaid`.
static int __fastcall Script_IsInGroup(void *L) {
    Game::Lua::PushBool(L, InRaid() || InParty());
    return 1;
}

static void RegisterLuaFunctions() {
    Game::Lua::RegisterGlobalFunction("IsInRaid", &Script_IsInRaid);
    Game::Lua::RegisterGlobalFunction("IsInGroup", &Script_IsInGroup);
}

static const Game::ModuleAutoRegister _autoreg{&RegisterLuaFunctions};

} // namespace Group::Info
