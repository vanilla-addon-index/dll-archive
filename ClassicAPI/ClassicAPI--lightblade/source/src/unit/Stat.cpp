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

namespace Unit::Stat {

namespace {

// Stat enum values from `Enum.UnitStat` (modern WoW). These match the
// `statIndex` argument to `UnitStat(unit, statIndex)` — 1..5 in the
// canonical display order (STR, AGI, STA, INT, SPI). Values are
// stable across every WoW expansion.
struct StatConstant {
    const char *name;
    int value;
};

constexpr StatConstant kStatConstants[] = {
    {"LE_UNIT_STAT_STRENGTH",  1},
    {"LE_UNIT_STAT_AGILITY",   2},
    {"LE_UNIT_STAT_STAMINA",   3},
    {"LE_UNIT_STAT_INTELLECT", 4},
    {"LE_UNIT_STAT_SPIRIT",    5},
};

} // namespace

static void RegisterLuaFunctions() {
    void *L = Game::Lua::State();
    if (L == nullptr)
        return;
    for (const auto &c : kStatConstants) {
        Game::Lua::PushString(L, c.name);
        Game::Lua::PushNumber(L, static_cast<double>(c.value));
        Game::Lua::SetTable(L, Game::Lua::GLOBALS_INDEX);
    }
}

static const Game::ModuleAutoRegister _autoreg{&RegisterLuaFunctions};

} // namespace Unit::Stat
