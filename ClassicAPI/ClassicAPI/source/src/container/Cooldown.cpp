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

// `C_Container.GetItemCooldown(itemID)` — modern signature only
// accepts a numeric itemID (per Blizzard's docs: "will not accept
// an itemlink or name"). We reuse the same `Item::Cooldown::PushCooldown`
// helper as the global `GetItemCooldown` (declared in [[item/Cooldown.h]])
// and rely on `Item::Arg::Resolve` to extract a numeric ID from the
// number / link forms; the name-fallback branch is implicitly skipped
// because `Arg::Resolve` already produces `0` for name input.

#include "Game.h"
#include "item/Arg.h"
#include "item/Cooldown.h"

namespace Container::Cooldown {

namespace {

int __fastcall Script_C_Container_GetItemCooldown(void *L) {
    Item::Arg::Resolved r = Item::Arg::Resolve(L, 1);
    Item::Cooldown::PushCooldown(L, r.itemID);
    return 3;
}

void RegisterLuaFunctions() {
    Game::Lua::RegisterTableFunction("C_Container", "GetItemCooldown",
                                     &Script_C_Container_GetItemCooldown);
}

const Game::ModuleAutoRegister _autoreg{&RegisterLuaFunctions};

} // namespace

} // namespace Container::Cooldown
