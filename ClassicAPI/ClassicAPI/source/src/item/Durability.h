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

namespace Item::Durability {

// Reads `(current, max)` durability off a resolved `CGItem *` and pushes
// both as numbers, returning `2`. Returns `0` (pushes nothing) when the
// item is missing, the descriptor is null, or max is zero (consumables
// / rings / etc. — items with no durability concept). Caller can
// `return PushDurabilityForItem(L, item);` to forward the count
// directly.
int PushDurabilityForItem(void *L, const uint8_t *item);

} // namespace Item::Durability
