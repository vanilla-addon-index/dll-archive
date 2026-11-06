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

// A pull-based "the local player's stat inputs changed" signal. `Notify()` is
// called from the aura and equipment hooks whenever the player gains/loses an
// aura or swaps gear — the state that feeds derived stats like
// `GetSpellBonusHealing` (flat +healing, plus the Spirit/Armor talent
// conversions that scale with those descriptor fields).
//
// Unlike Tick::WorldTick (push / per-frame callback), this is a monotonic
// epoch that consumers POLL: a lazy cache recomputes only when `Epoch()`
// differs from the value it last computed at, so a per-frame query is O(1)
// between real changes and never does work on idle frames.
namespace Player::StatSignal {

// Bump the epoch — called from the aura / equipment hooks on a
// player-affecting change.
void Notify();

// Current epoch; increments on each `Notify()`. A consumer caches the value it
// last recomputed at and recomputes only when this differs.
uint32_t Epoch();

} // namespace Player::StatSignal
