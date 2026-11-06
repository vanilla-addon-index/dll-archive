# LockPort client mod 1.2.1

Optional companion for LockPort 3.9.3. The addon works without it for manual summons.

## Install with VanillaFixes

1. Close WoW.
2. Back up the existing addon folder and dlls.txt.
3. Install this repository directly as Interface/AddOns/LockPort, with LockPort.toc at that folder's top level.
4. Copy LockPort.dll from the repository root beside VanillaFixes.exe.
5. Add one line containing LockPort.dll at the end of dlls.txt, after other client mods.
6. Launch through VanillaFixes. Join a party or raid on a warlock and enable Auto Summon.

Updating from addon 3.7.2, 3.7.3, or 3.7.4 needs only the addon folder and /reload.
Earlier DLL versions must be replaced, followed by a full client restart.
/lockport debug should report native=1.2.1.

## Compatibility and behavior

Built for the inspected 32-bit OctoWoW 1.18.1 WoW.exe and WoW_Modernized.exe
function signatures. This is not a universal build for all client versions.
It refuses unsupported executables and requires Lua-registration compatibility
provided by Nampower, SuperWoW, or ClassicAPI. Load LockPort after those mods.

The DLL resolves a canonical raid1..raid40 or party1..party4 unit to its GUID,
finds Ritual of Summoning in the spellbook, and invokes the client spellbook
function. It temporarily saves and clears the frame-script execution context
and depth around that call, then restores both. This follows the command context
pattern documented in [ClassicAPI 1.17.1](https://github.com/brues-code/ClassicAPI/blob/v1.17.1/src/Offsets.h).
It limits calls to the Lua thread and rate-limits requests. A successful return
means the call was submitted, not that a server summon or arrival succeeded.

The addon still requires helpers and target eligibility. Helpers click the
portal and the summoned player accepts. Auto Summon and availability
announcements reset on login/reload; leaving the group disables Auto Summon.

The user confirmed successful automatic summoning with 1.2.1 in-game.
Regression tests use mocked game APIs and do not cover every client/mod setup.

To uninstall, close WoW and remove LockPort.dll from dlls.txt. Do not hot-unload.

## Build and tests

Source: LockPort.c. Build from the repository root with an LLVM-MinGW i686 compiler:

    powershell -File native/build.ps1 -Compiler i686-w64-mingw32-clang.exe

Python addon tests require lupa with its lua51 module:

    python -m pip install lupa
    python tests/test_addon.py

Build the native harness as an x86 executable at image base 0x10000000 with ASLR disabled:

    i686-w64-mingw32-clang -O2 -Wall -Wextra -Werror -static-libgcc -Wl,--image-base,0x10000000 -Wl,--disable-dynamicbase tests/native_tests.c -o native_tests.exe
    native_tests.exe "path/to/WoW.exe" LockPort.dll

The first argument defaults to WoW.exe; the second defaults to LockPort.dll.
Run from the repository root. Tests check unsupported-host rejection, client
signatures, hook relocation/chaining, thread/unit/rate checks, GUID and spellbook
forwarding, and scoped context restoration. No server connection is made.

The binary uses Windows system libraries (UCRT and Kernel32).
SHA256SUMS.txt records its checksum. See CLASSICAPI-REVIEW.md for the API review.
