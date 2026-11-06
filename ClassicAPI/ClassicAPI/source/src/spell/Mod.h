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

// `Spell::Mod` — the engine's SpellMod (talent / item) system, for the
// LOCAL PLAYER. Replicates `FUN_006e6b30` / `FUN_006e6bf0`: the player's
// flat and percent modifiers are accumulated into two tables indexed
// `[familyFlagBit][op]` (see `VAR_SPELLMOD_*` in Offsets.h). A spell's
// value for a given op is modified by summing, over the bits set in the
// spell's SpellFamilyFlags, the flat and percent entries, then applying
// `value = (value + flat) * (100 + pct) * 0.01`.
//
// This underlies many spell properties — radius, cast time, mana cost,
// duration, range, cooldown — each a distinct `op` (e.g.
// `Offsets::SPELLMOD_OP_RADIUS`). The op numbering is the engine's
// internal one; verify each against the binary before relying on it.
//
// Inherently local-player-only: the client tracks spell mods for the
// player alone, so there's no way to know another caster's talents.
namespace Spell::Mod {

// Returns `base` with the local player's modifiers for `op` applied to
// `spellRecord` (a `Spell.dbc` record pointer). Returns `base` unchanged
// when no modifier matches — wrong spell family, mods disabled on the
// spell, the player can't be resolved, or no relevant talent/item.
float Apply(const uint8_t *spellRecord, int op, float base);

} // namespace Spell::Mod
