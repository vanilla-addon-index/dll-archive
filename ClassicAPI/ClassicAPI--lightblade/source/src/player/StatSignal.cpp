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

#include "player/StatSignal.h"

namespace Player::StatSignal {

namespace {
// Starts at 1 so a consumer whose cached epoch is default-0 always computes on
// its first query.
uint32_t g_epoch = 1;
} // namespace

void Notify() { ++g_epoch; }

uint32_t Epoch() { return g_epoch; }

} // namespace Player::StatSignal
