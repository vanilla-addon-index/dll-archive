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
#include "expansion/Level.h"

namespace Expansion::Constants {

namespace {

// Expansion-level enum values shipped by retail / Classic Era WoW. Addons
// backporting from later expansions often gate code on
// `LE_EXPANSION_LEVEL_CURRENT` or compare specific `LE_EXPANSION_*`
// constants — we ship the full table so those gates compile cleanly on
// 1.12 and resolve to the right branch (`< LE_EXPANSION_BURNING_CRUSADE`
// is always true here).
//
// Values match the canonical retail enum (`Enum.ExpansionLevel` in
// modern Lua). `LE_EXPANSION_LEVEL_CURRENT` is the live client's
// expansion — `LE_EXPANSION_CLASSIC` (0) for us, since we're 1.12.
struct ExpansionConstant {
    const char *name;
    int value;
};

constexpr ExpansionConstant kExpansionConstants[] = {
    {"LE_EXPANSION_CLASSIC",                0},
    {"LE_EXPANSION_BURNING_CRUSADE",        1},
    {"LE_EXPANSION_WRATH_OF_THE_LICH_KING", 2},
    {"LE_EXPANSION_CATACLYSM",              3},
    {"LE_EXPANSION_MISTS_OF_PANDARIA",      4},
    {"LE_EXPANSION_WARLORDS_OF_DRAENOR",    5},
    {"LE_EXPANSION_LEGION",                 6},
    {"LE_EXPANSION_BATTLE_FOR_AZEROTH",     7},
    {"LE_EXPANSION_SHADOWLANDS",            8},
    {"LE_EXPANSION_DRAGONFLIGHT",           9},
    {"LE_EXPANSION_WAR_WITHIN",             10},
    {"LE_EXPANSION_MIDNIGHT",               11},
    {"LE_EXPANSION_LEVEL_CURRENT",          Expansion::kCurrentExpansionLevel},
};

} // namespace

static void RegisterLuaFunctions() {
    void *L = Game::Lua::State();
    if (L == nullptr)
        return;
    for (const auto &c : kExpansionConstants) {
        Game::Lua::PushString(L, c.name);
        Game::Lua::PushNumber(L, static_cast<double>(c.value));
        Game::Lua::SetTable(L, Game::Lua::GLOBALS_INDEX);
    }
}

static const Game::ModuleAutoRegister _autoreg{&RegisterLuaFunctions};

} // namespace Expansion::Constants
