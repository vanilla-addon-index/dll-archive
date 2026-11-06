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

// Persistent debug log shared by all probe / tracing modules. Writes
// to `C:\Git\ClassicAPI\debug.log` so it can be read directly from
// the repo by tooling/agents — the file is gitignored. Used during
// offset-finding sessions, runtime tracing of unfamiliar code paths,
// post-mortem inspection, and anywhere `OutputDebugString` would be
// awkward to capture.
//
// Three writing primitives:
//   Append(label, content) — labeled block (good for snapshot diffs)
//   Printf(fmt, ...)       — one-line trace, no label
//   HexDump(label, ptr,
//           len, base)     — hex+ASCII dump of a memory range, SEH-
//                            wrapped so faulting reads don't crash
//                            the host process; `base` is the address
//                            shown in the offset column (defaults to
//                            the actual VA of `ptr`).
//
// And `Clear()` to truncate before a fresh session.

namespace Debug::Log {

// Truncates the debug log file. Safe to call before any writer.
void Clear();

// Appends a labeled block. Format:
//   === <label> ===
//   <content>
//   <blank line>
//
// Both args are nul-terminated C strings; either may be nullptr.
// `content` is written verbatim — caller controls layout.
void Append(const char *label, const char *content);

// Appends a single line (no label, no surrounding blank line).
// Auto-appends '\n' if `fmt` doesn't end with one. printf-style
// formatting; capped at ~2KB per call.
void Printf(const char *fmt, ...);

// Hex-dumps `len` bytes starting at `ptr`, formatted xxd-style with
// 16 bytes per row, both hex and ASCII columns. The offset column
// shows `base + i` — pass `base = (uintptr_t)ptr` to display real
// addresses, or `base = 0` to get pure relative offsets.
//
// SEH-wrapped: if the read faults partway through (page boundary,
// freed memory, etc.), the dump stops at the last successful row
// and notes the failed offset. Safe to call with any pointer.
void HexDump(const char *label, const void *ptr, int len, uintptr_t base);

// Convenience: HexDump with `base = (uintptr_t)ptr`.
void HexDump(const char *label, const void *ptr, int len);

} // namespace Debug::Log
