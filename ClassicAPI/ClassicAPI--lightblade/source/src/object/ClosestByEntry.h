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

#include "guid/Guid.h"

#include <cstdint>

// Shared "nearest visible object of a given template entry" scan, backing
// both `ClosestUnitPosition` (creatures) and `ClosestGameObjectPosition`
// (game objects). Vanilla packs the template entry into GUID bits 24-47
// for the world-object types, so the only per-caller differences are the
// GUID type prefix and the object-manager type mask.
namespace Object::ClosestByEntry {

struct Result {
    bool found;
    float x, y;   // world position of the nearest match
    float distSq; // squared center-to-center distance from the player
};

// Nearest CURRENTLY-VISIBLE object whose GUID is of `guidType` (Creature /
// GameObject / …) and encodes template `entry` (GUID bits 24-47),
// relative to the local player. `typeMask` is the `ClntObjMgrObjectPtr`
// filter used to resolve the GUID (`TYPEMASK_UNIT` / `TYPEMASK_GAMEOBJECT`).
// Returns `{found=false}` for entry 0, pre-world, on a player-position
// miss, or when nothing matches.
Result Find(uint32_t typeMask, Guid::Type guidType, uint32_t entry);

} // namespace Object::ClosestByEntry
