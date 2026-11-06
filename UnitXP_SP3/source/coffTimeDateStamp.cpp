#include <cstdint>

#include <Windows.h>
#include <psapi.h>

#include "coffTimeDateStamp.h"

#pragma comment(lib, "psapi.lib")

double coffTimeDateStamp() {
    MODULEINFO info = {};
    BOOL r = GetModuleInformation(GetCurrentProcess(), moduleSelf, &info, sizeof info);
    if (r == FALSE) {
        return 0.0;
    }

    auto base = reinterpret_cast<uintptr_t>(info.lpBaseOfDll);

    /* Old implementation
    uint32_t peHeaderOffset = *reinterpret_cast<uint32_t*>(base + 0x3c);
        // TimeDateStamp of COFF header
    return *reinterpret_cast<uint32_t*>(base + peHeaderOffset + 0x8);
    */

    auto* dos = reinterpret_cast<IMAGE_DOS_HEADER*>(base);
    if (dos->e_magic != IMAGE_DOS_SIGNATURE) {
        return 0.0;
    }

    auto* nt = reinterpret_cast<IMAGE_NT_HEADERS*>(base + dos->e_lfanew);
    if (nt->Signature != IMAGE_NT_SIGNATURE) {
        return 0.0;
    }

    return static_cast<double>(nt->FileHeader.TimeDateStamp);
}
