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

// Turtle WoW custom healing auras. Aura 199
// (MOD_SPELL_HEALING_OF_ARMOR_PERCENT, "Ironclad") adds
// `Armor × amount / 100` to the player's spell healing bonus — not a stock
// vanilla aura index. Plugs into `Spell::HealingAura`'s resolver chain so
// the Turtle-specific aura semantic lives here, not in the stock
// GetSpellBonusHealing decoder. Gated on Turtle detection (the aura index
// is a generic slot number that could mean something else on another
// server).

#include "spell/HealingAura.h"
#include "turtle/Detect.h"

#include <cstdint>

namespace Turtle::HealingAura {

namespace {

constexpr int kAuraModHealingOfArmorPercent = 199; // × Armor (Ironclad)

long Resolve(int auraIndex, long amount, int32_t /*spirit*/, int32_t armor) {
    if (!Turtle::Detected() || auraIndex != kAuraModHealingOfArmorPercent)
        return 0;
    return static_cast<long>(armor) * amount / 100;
}

const Spell::HealingAura::AutoResolver _register{&Resolve};

} // namespace

} // namespace Turtle::HealingAura
