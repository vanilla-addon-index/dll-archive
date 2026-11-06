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

namespace Item::RepairCost {

// Pushes the repair cost (in copper) for a resolved `CGItem *` and
// returns `1`. Null items / items not needing repair push `0` — we
// forward "no repair needed" rather than nothing, because the caller
// asked "what's the cost" and `0` is a meaningful answer.
int PushRepairCostForItem(void *L, const uint8_t *item);

} // namespace Item::RepairCost
