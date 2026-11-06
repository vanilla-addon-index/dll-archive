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

#include <cstdint>

namespace Item::Openable {

// Pushes two values for the openable check on a player-owned item
// (`isOpenable, canOpen`), returning 2. The two semantics:
//
//   `isOpenable` — bool. The item type carries the openable flag
//     (`ItemStats.Flags & 0x4` — clams, sacks, lockboxes, etc.).
//   `canOpen`    — bool. The player can right-click this specific
//     instance and trigger the open action right now. True for
//     openable items with no lock (`LockID == 0`) or whose instance
//     has been unlocked (`ITEM_FIELD_FLAGS & 0x4` — set after a
//     rogue picks the lock, a key is used, etc.). False for fresh
//     lockboxes a non-rogue is looking at.
//
// `cgItem` may be null (empty slot), in which case nothing is pushed
// and 0 is returned (Lua sees nil for both returns). Uncached itemID
// also returns 0 plus a background cache warm.
int PushIsItemOpenable(void *L, const uint8_t *cgItem);

} // namespace Item::Openable
