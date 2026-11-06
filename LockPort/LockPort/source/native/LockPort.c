// LockPort companion client mod, API 1.2.1.
// Build: zig cc -target x86-windows-gnu -shared -O2 LockPort.c -o LockPort.dll
// Designed for the inspected OctoWoW 1.18.1 x86 executable layout.
// No background game thread: Lua APIs run only on the game's Lua thread.
#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>

typedef void (__stdcall *LoadFunctionsFn)(void);
typedef int (__fastcall *LuaFunction)(void *);
typedef void (__fastcall *RegisterFn)(const char *, LuaFunction);
typedef const char *(__fastcall *ToStringFn)(void *, int);
typedef void (__fastcall *PushStringFn)(void *, const char *);
typedef void (__fastcall *PushBooleanFn)(void *, int);
typedef int (__fastcall *GetTopFn)(void *);
typedef void (__fastcall *SetTopFn)(void *, int);
typedef int32_t (__fastcall *SpellSlotFn)(const char *, uint32_t *);
typedef uint64_t (__fastcall *UnitGuidFn)(const char *);
typedef void (__fastcall *BookCastFn)(uint32_t, uint32_t, uint64_t);

static LoadFunctionsFn originalLoad;
static void *trampoline;
static DWORD luaThread;
static DWORD lastAttempt;
static int hasAttempt;
static unsigned char saved[6];
static SIZE_T patchLength;

static int __fastcall Version(void *state) {
    ((PushStringFn)0x006F3890)(state, "1.2.1");
    return 1;
}
static int validUnit(const char *s) {
    if (!s) return 0;
    int limit;
    if (strncmp(s, "raid", 4) == 0) { s += 4; limit = 40; }
    else if (strncmp(s, "party", 5) == 0) { s += 5; limit = 4; }
    else return 0;
    if (*s < '1' || *s > '9') return 0;
    int number = *s++ - '0';
    if (*s >= '0' && *s <= '9') number = number * 10 + *s++ - '0';
    return *s == 0 && number >= 1 && number <= limit;
}
static int result(void *state, int attempted, const char *reason) {
    ((PushBooleanFn)0x006F39F0)(state, attempted);
    ((PushStringFn)0x006F3890)(state, reason);
    return 2;
}
static int __fastcall Summon(void *state) {
    DWORD now = GetTickCount();
    const char *unit = ((ToStringFn)0x006F3690)(state, 1);
    if (GetCurrentThreadId() != luaThread) return result(state, 0, "wrong thread");
    if (!validUnit(unit)) return result(state, 0, "invalid group unit");
    if (hasAttempt && (DWORD)(now - lastAttempt) < 2000)
        return result(state, 0, "native rate limit");
    // Resolve an explicit target and the actual spellbook entry. No Lua
    // string execution, hardware-input simulation, or target-dependent cast.
    uint64_t guid = ((UnitGuidFn)0x00515970)(unit);
    if (!guid) return result(state, 0, "unit unavailable");
    uint32_t book = 0;
    int32_t slot = ((SpellSlotFn)0x004B3950)("Ritual of Summoning", &book);
    if (slot < 0 || slot >= 1024 || book != 0)
        return result(state, 0, "ritual not in spellbook");
    lastAttempt = now;
    hasAttempt = 1;
    // The action gate (0x494A50, kind 2) refuses casts from restricted
    // frame scripts such as OnUpdate, including native calls made by Lua.
    // Mirror command-dispatch context scoping: save, clear for this one
    // engine call, and restore immediately. No persistent gate patch.
    volatile uintptr_t *context = (volatile uintptr_t *)0x00CEEAC0;
    volatile uint32_t *depth = (volatile uint32_t *)0x00CEEAC4;
    uintptr_t savedContext = *context;
    uint32_t savedDepth = *depth;
    *context = 0;
    *depth = 0;
    ((BookCastFn)0x004B3300)((uint32_t)slot, book, guid);
    *context = savedContext;
    *depth = savedDepth;
    return result(state, 1, "spellbook request sent");
}
static void __stdcall LoadHook(void) {
    originalLoad();
    luaThread = GetCurrentThreadId();
    // Pin the module before giving Lua pointers into its code.
    HMODULE pinned = NULL;
    GetModuleHandleExA(GET_MODULE_HANDLE_EX_FLAG_FROM_ADDRESS |
        GET_MODULE_HANDLE_EX_FLAG_PIN, (LPCSTR)(uintptr_t)&Version, &pinned);
    ((RegisterFn)0x00704120)("GetLockPortVersion", Version);
    ((RegisterFn)0x00704120)("LockPortNativeSummon", Summon);
}
typedef struct { DWORD rva; unsigned char bytes[16]; } Signature;
static const Signature signatures[] = {
    {0x90250,{0x56,0xe8,0xfa,0x60,0x27,0x00,0xe8,0x45,0x66,0x0a,0x00,0xe8,0x90,0xf0,0x05,0x00}},
    {0xb3950,{0x55,0x8b,0xec,0x81,0xec,0x04,0x06,0x00,0x00,0x56,0x57,0x68,0x00,0x04,0x00,0x00}},
    {0xb3300,{0x55,0x8b,0xec,0x83,0xec,0x20,0x53,0x56,0x8b,0xf2,0x57,0x89,0x75,0xf8,0x8b,0xd9}},
    {0x115970,{0x55,0x8b,0xec,0x51,0x56,0x68,0x90,0x00,0x00,0x00,0x8b,0xf1,0xe8,0xcf,0x2b,0xf5}},
    {0x304120,{0x56,0x57,0x8b,0xf9,0xe8,0xa7,0xff,0xff,0xff,0x8b,0xf0,0x6a,0x00,0x8b,0xce,0xe8}},
    {0x304cd0,{0x56,0x6a,0x00,0x8b,0xf1,0x52,0x56,0xe8,0x14,0x5a,0xf4,0xff,0x8b,0xd0,0x8b,0xce}},
    {0x2f3690,{0x56,0x57,0x8b,0xf9,0xe8,0x77,0xfd,0xff,0xff,0x8b,0xf0,0x85,0xf6,0x75,0x03,0x5f}},
    {0x2f3890,{0x85,0xd2,0x56,0x8b,0xf1,0x75,0x06,0x5e,0xe9,0x53,0xff,0xff,0xff,0x57,0x83,0xc9}},
    {0x2f39f0,{0x8b,0x41,0x08,0xc7,0x00,0x01,0x00,0x00,0x00,0x56,0x8b,0xf2,0x8b,0x15,0xc0,0xea}},
    {0x2f3070,{0x8b,0x41,0x08,0x2b,0x41,0x0c,0xc1,0xf8,0x04,0xc3,0x90,0x90,0x90,0x90,0x90,0x90}},
    {0x2f3080,{0x85,0xd2,0x8b,0x41,0x08,0x7c,0x38,0x56,0x8b,0x71,0x0c,0xc1,0xe2,0x04,0x03,0xf2}}
};
static int fileOffset(const unsigned char *image, DWORD rva, DWORD *offset) {
    const IMAGE_DOS_HEADER *dos = (const IMAGE_DOS_HEADER *)image;
    const IMAGE_NT_HEADERS32 *nt = (const IMAGE_NT_HEADERS32 *)(image + dos->e_lfanew);
    const IMAGE_SECTION_HEADER *sections = IMAGE_FIRST_SECTION(nt);
    for (unsigned int i = 0; i < nt->FileHeader.NumberOfSections; ++i) {
        const IMAGE_SECTION_HEADER *s = sections + i;
        if (rva >= s->VirtualAddress && rva + 16 <= s->VirtualAddress + s->SizeOfRawData) {
            *offset = s->PointerToRawData + rva - s->VirtualAddress;
            return 1;
        }
    }
    return 0;
}
static int matchesClient(void) {
    unsigned char *base = (unsigned char *)GetModuleHandleA(NULL);
    if ((uintptr_t)base != 0x00400000) return 0;
    IMAGE_DOS_HEADER *dos = (IMAGE_DOS_HEADER *)base;
    if (dos->e_magic != IMAGE_DOS_SIGNATURE || dos->e_lfanew <= 0 || dos->e_lfanew > 4096) return 0;
    IMAGE_NT_HEADERS32 *nt = (IMAGE_NT_HEADERS32 *)(base + dos->e_lfanew);
    if (nt->Signature != IMAGE_NT_SIGNATURE || nt->FileHeader.Machine != IMAGE_FILE_MACHINE_I386 ||
        nt->OptionalHeader.Magic != IMAGE_NT_OPTIONAL_HDR32_MAGIC ||
        nt->OptionalHeader.SizeOfImage < 0x00900000) return 0;
    char filename[MAX_PATH];
    if (!GetModuleFileNameA(NULL, filename, MAX_PATH) || strlen(filename) >= MAX_PATH - 1) return 0;
    HANDLE file = CreateFileA(filename, GENERIC_READ, FILE_SHARE_READ | FILE_SHARE_WRITE |
        FILE_SHARE_DELETE, NULL, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, NULL);
    if (file == INVALID_HANDLE_VALUE) return 0;
    int ok = 1;
    for (SIZE_T i = 0; i < sizeof(signatures) / sizeof(signatures[0]); ++i) {
        DWORD offset = 0, count = 0;
        unsigned char bytes[16];
        if (!fileOffset(base, signatures[i].rva, &offset) ||
            SetFilePointer(file, offset, NULL, FILE_BEGIN) == INVALID_SET_FILE_POINTER ||
            !ReadFile(file, bytes, sizeof(bytes), &count, NULL) ||
            count != sizeof(bytes) || memcmp(bytes, signatures[i].bytes, sizeof(bytes))) {
            ok = 0;
            break;
        }
    }
    CloseHandle(file);
    return ok;
}
static void relativeJump(unsigned char *at, const void *destination) {
    at[0] = 0xE9;
    int32_t displacement = (int32_t)((uintptr_t)destination - (uintptr_t)at - 5);
    memcpy(at + 1, &displacement, 4);
}
static int install(void) {
    if (!matchesClient()) return 0;
    // These clients require a registration compatibility hook for Lua functions
    // living in a DLL. Nampower, SuperWoW, and ClassicAPI provide it.
    // Do not alter this shared engine check or interfere with their hooks.
    unsigned char registrationSupport = *(unsigned char *)0x0042A320;
    if (registrationSupport != 0xE9 && registrationSupport != 0xC3) return 0;
    unsigned char *target = (unsigned char *)0x00490250;
    // Preserve an existing loader detour (Nampower/SuperWoW load order).
    if (target[0] == 0xE9) {
        int32_t displacement;
        memcpy(&displacement, target + 1, 4);
        unsigned char *previous = target + 5 + displacement;
        MEMORY_BASIC_INFORMATION info;
        if (!VirtualQuery(previous, &info, sizeof(info)) || info.State != MEM_COMMIT ||
            !(info.Protect & (PAGE_EXECUTE | PAGE_EXECUTE_READ | PAGE_EXECUTE_READWRITE | PAGE_EXECUTE_WRITECOPY))) return 0;
        originalLoad = (LoadFunctionsFn)previous;
        patchLength = 5;
    } else {
        if (memcmp(target, signatures[0].bytes, 6)) return 0;
        // Two whole instructions: push esi; call rel32. Relocate that call.
        trampoline = VirtualAlloc(NULL, 16, MEM_COMMIT | MEM_RESERVE, PAGE_READWRITE);
        if (!trampoline) return 0;
        unsigned char *t = (unsigned char *)trampoline;
        memcpy(t, target, 6);
        int32_t displacement;
        memcpy(&displacement, target + 2, 4);
        uintptr_t callTarget = (uintptr_t)target + 6 + displacement;
        displacement = (int32_t)(callTarget - (uintptr_t)t - 6);
        memcpy(t + 2, &displacement, 4);
        relativeJump(t + 6, target + 6);
        DWORD old;
        if (!VirtualProtect(t, 16, PAGE_EXECUTE_READ, &old)) {
            VirtualFree(t, 0, MEM_RELEASE); trampoline = NULL; return 0;
        }
        FlushInstructionCache(GetCurrentProcess(), t, 16);
        originalLoad = (LoadFunctionsFn)t;
        patchLength = 6;
    }
    DWORD old;
    if (!VirtualProtect(target, patchLength, PAGE_EXECUTE_READWRITE, &old)) return 0;
    memcpy(saved, target, patchLength);
    relativeJump(target, (void *)(uintptr_t)&LoadHook);
    if (patchLength == 6) target[5] = 0x90;
    DWORD ignored;
    VirtualProtect(target, patchLength, old, &ignored);
    FlushInstructionCache(GetCurrentProcess(), target, patchLength);
    return 1;
}
BOOL WINAPI DllMain(HINSTANCE module, DWORD reason, LPVOID reserved) {
    (void)reserved;
    if (reason == DLL_PROCESS_ATTACH) {
        DisableThreadLibraryCalls(module);
        if (!install()) {
            OutputDebugStringA("LockPort.dll: unsupported client or loader hook; no changes made.\n");
            return FALSE;
        }
    }
    // This plugin has process lifetime. Do not hot-unload/reload it.
    return TRUE;
}
