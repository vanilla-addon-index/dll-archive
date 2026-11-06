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

namespace Item::TradePlayerID {

// `GetTradePlayerItemID(slot)` — itemID companion to
// `GetTradePlayerItemLink`. Slots 1..7 (vanilla's 6 tradeable slots
// plus the non-tradeable extra slot). nil for empty / OOR / when no
// trade window is open.
static int __fastcall Script_GetTradePlayerItemID(void *L) {
    if (!Game::Lua::IsNumber(L, 1)) {
        Game::Lua::Error(L, "Usage: GetTradePlayerItemID(slot)");
        return 0;
    }
    const int slot = static_cast<int>(Game::Lua::ToNumber(L, 1)) - 1;
    if (slot < 0 || slot >= Offsets::TRADE_MAX_SLOTS)
        return 0;

    auto *array = reinterpret_cast<const uint32_t *>(Offsets::VAR_TRADE_PLAYER_SLOTS);
    const int itemID = static_cast<int>(array[slot]);
    if (itemID == 0)
        return 0;

    Game::Lua::PushNumber(L, static_cast<double>(itemID));
    return 1;
}

static void RegisterLuaFunctions() {
    Game::Lua::RegisterGlobalFunction("GetTradePlayerItemID", &Script_GetTradePlayerItemID);
}

static const Game::ModuleAutoRegister _autoreg{&RegisterLuaFunctions};

} // namespace Item::TradePlayerID
