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

namespace Item::Spell {

// Returns the spell ID for `itemID`'s on-use trigger (the slot in
// `ItemStats_C` with trigger code `ITEM_SPELLTRIGGER_ON_USE`), or 0
// if the item has no on-use spell or isn't yet in the local cache.
// Does NOT trigger a cache warmup — callers that want auto-warmup
// behavior should layer it on top.
//
// Used by `C_Item.GetItemSpell` and by `Item::Hearthstone`'s
// hearthstone detector (which OR's itemID == 6948 with on-use spell
// == 8690 so custom-server hearthstones with non-stock itemIDs but
// the same use-spell still register).
int OnUseSpellIDForItemID(uint32_t itemID);

// Walks a cached `ItemStats_C` record's 5 spell slots and returns the
// first ON_USE (trigger=0) spell ID, or 0 if none. Split out so callers
// that already hold the record (e.g. `Item::Usable`, which also reads the
// record's use requirements) don't peek the cache twice or re-derive the
// slot walk. `OnUseSpellIDForItemID` is the peek-by-itemID convenience
// wrapper over this.
int FindOnUseSpellIDInRecord(const uint8_t *record);

} // namespace Item::Spell
