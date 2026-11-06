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

// Suppress vanilla 1.12.1's "Your game interface files are corrupt"
// fatal error so the engine accepts the in-memory file modifications
// ClassicAPI makes via the file-read hook:
//
//   - `src/bindings/Inject.cpp` splices into FrameXML's `Bindings.xml`
//   - `src/addons/Embedded.cpp` surfaces the embedded `!!!ClassicAPI`
//     addon
//
// Both diverge from what's on disk, so the cumulative hashes the
// engine computes against `Interface\FrameXML.sig` (global) and each
// addon entry's stored signature (per-addon) no longer match. The
// engine calls `FUN_00401560(10)` and tears down the process.
//
// We hook `FUN_00401560` (the fatal-error dispatcher) and drop calls
// with code `10`. Other codes pass through to the original handler
// unmolested — we don't want to mask legitimate fatal conditions
// (login failures, connection drops, etc., which use other codes).
//
// Modded clients (Octo + TLS-bootloader, SuperWoW-style) usually
// neutralize the integrity checks at startup; the engine never
// reaches `FUN_00401560(10)` there and our hook is a harmless no-op.

#include "Game.h"
#include "Offsets.h"

namespace Security::FrameXMLBypass {

namespace {

using FatalError_t = void(__fastcall *)(unsigned code);
FatalError_t FatalError_o = nullptr;

void __fastcall FatalError_h(unsigned code) {
    if (code == 10)
        return;
    FatalError_o(code);
}

const Game::HookAutoRegister _hookreg{
    Offsets::FUN_FATAL_ERROR,
    reinterpret_cast<void *>(&FatalError_h),
    reinterpret_cast<void **>(&FatalError_o)};

} // namespace

} // namespace Security::FrameXMLBypass
