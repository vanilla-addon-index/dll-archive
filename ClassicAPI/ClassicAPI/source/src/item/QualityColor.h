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

#include "Offsets.h"

#include <cstdint>

namespace Item::QualityColor {

// Returns the engine's `"|cffRRGGBB"` color-prefix string for the
// given item quality. Reads directly from the engine table at
// `Offsets::VAR_QUALITY_COLOR_TABLE` so we don't have to duplicate
// the hex palette across modules. Mirrors the engine's own fallback
// at `0x0052AD90`: quality > 6 returns white (index 1).
inline const char *Prefix(int quality) {
    auto *table = reinterpret_cast<const char *const *>(
        Offsets::VAR_QUALITY_COLOR_TABLE);
    if (quality < 0 || quality >= Offsets::QUALITY_COLOR_TABLE_SIZE)
        return table[1]; // white fallback, matches engine
    return table[quality];
}

// Returns just the 6-char hex (e.g. "9d9d9d"), pointing into the
// engine string past the `|cff` prefix. Useful for callers that
// build their own markup format and need the bare hex.
inline const char *Hex(int quality) {
    return Prefix(quality) + 4;
}

} // namespace Item::QualityColor
