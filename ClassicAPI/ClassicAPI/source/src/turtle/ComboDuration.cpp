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

// Turtle WoW reworked Rip — known combo-finisher durations for a spell
// whose client DBC row is missing. All six Rip ranks point at
// SpellDuration row 87, which Turtle added on the SERVER only
// ({8000, 0, 18000} — live data shows 10/12/14/16/18s at 1..5 CP, i.e.
// 8s + 2s per combo point); the client patch never shipped the row (the
// client table jumps 86 → 105), so the index dangles. Verified the only
// dangling duration index in the entire client Spell.dbc.
//
// This supplies the values through `Aura::ComboDuration`'s dangling-row
// resolver so the Turtle-specific data lives here, not in the stock
// module. Unlike the other `src/turtle/` modules it does NOT gate on
// `Turtle::Detected()`: the activation gate is the dangling-row condition
// in `Aura::ComboDuration` (a client-data bug unique to this Rip), which
// is the deliberate design — gate on the bug, not the realm. On a stock
// client Rip resolves to a valid row and this resolver is never consulted;
// if Turtle ever ships the missing client row, the DBC takes over and this
// goes dormant automatically.

#include "aura/ComboDuration.h"

#include <cstdint>

namespace Turtle::ComboDuration {

namespace {

struct Known {
    uint32_t spellId;
    int32_t baseMs;
    int32_t maxMs;
};

constexpr Known kRip[] = {
    {1079, 8000, 18000}, {9492, 8000, 18000}, {9493, 8000, 18000},
    {9752, 8000, 18000}, {9894, 8000, 18000}, {9896, 8000, 18000},
};

bool Resolve(uint32_t spellId, int32_t *baseMs, int32_t *maxMs) {
    for (const auto &k : kRip) {
        if (k.spellId == spellId) {
            *baseMs = k.baseMs;
            *maxMs = k.maxMs;
            return true;
        }
    }
    return false;
}

const Aura::ComboDuration::AutoDanglingResolver _register{&Resolve};

} // namespace

} // namespace Turtle::ComboDuration
