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

// Turtle WoW custom bag families. Turtle added four cooking/gathering bag
// families as `ItemBagFamily.dbc` rows 10–13 (Meat, Fish, Leather,
// Mining) — beyond retail vanilla, which stops at Keys (9). Turtle's own
// bags normally carry `m_bagFamily` directly, so this mapping is a safety
// net for any custom container shipped with an empty field; it plugs into
// the stock `Item::BagFamily` resolver chain rather than polluting the
// stock table with non-vanilla data.
//
// Subclass → raw family ID cross-referenced by name between
// ItemSubClass.dbc (class 1, Container) and ItemBagFamily.dbc. NOTE: the
// resulting bitmasks (`1 << (id-1)`) land on `0x200`–`0x1000`, which
// collide with retail's Gem/Mining bag bits — see docs/API.md's
// GetItemFamily family table for the caveat. The values stay
// self-consistent within Turtle (a Meat Bag and the meat it holds both
// report `0x200`).
//
// This file is the home for Turtle-only custom content that layers onto a
// stock engine surface; add further custom-data modules alongside it.

#include "item/BagFamily.h"
#include "turtle/Detect.h"

#include <cstdint>

namespace Turtle::BagFamily {

namespace {

// Turtle custom Container-class subclasses → `ItemBagFamily.dbc` raw IDs.
// Stock subclasses (Soul/Herb/Enchanting/Engineering) are handled by
// `Item::BagFamily`'s own table and never reach here. Gated on Turtle
// detection so the custom mapping can't misfire on a stock client (where
// these subclasses don't exist as containers anyway).
uint32_t Resolve(uint32_t itemClass, uint32_t subclass) {
    if (!Turtle::Detected() || itemClass != Item::BagFamily::kItemClassContainer)
        return 0;
    switch (subclass) {
    case 6:  return 13;  // Mining Bag         → Mining Supplies
    case 7:  return 12;  // Leatherworking Bag → Leather
    case 8:  return 10;  // Meat Bag           → Meat
    case 9:  return 11;  // Fish Bag           → Fish
    default: return 0;
    }
}

const Item::BagFamily::AutoResolver _register{&Resolve};

} // namespace

} // namespace Turtle::BagFamily
