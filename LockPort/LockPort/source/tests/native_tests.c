#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <stdio.h>
#include <stdint.h>
#include <assert.h>
#include <string.h>
static unsigned char *client;
static const char *clientPath="WoW.exe";
static HMODULE WINAPI TestGetModuleHandleA(LPCSTR name) {
    return name ? GetModuleHandleA(name) : (HMODULE)client;
}
static DWORD WINAPI TestGetModuleFileNameA(HMODULE module, LPSTR dest, DWORD length) {
    if (module) return GetModuleFileNameA(module,dest,length);
    if(strlen(clientPath)+1>length)return 0;
    strcpy(dest,clientPath); return (DWORD)strlen(dest);
}
#define GetModuleHandleA TestGetModuleHandleA
#define GetModuleFileNameA TestGetModuleFileNameA
#include "../native/LockPort.c"
#undef GetModuleHandleA
#undef GetModuleFileNameA

static LuaFunction versionAPI, summonAPI;
static int registrations, originalCalls, executions, booleanValue, topRestores;
static const char *inputUnit;
static char versionValue[32];
static void __stdcall FakeOriginal(void) { originalCalls++; }
static void __fastcall FakeRegister(const char *name,LuaFunction fn) {
    if(!strcmp(name,"GetLockPortVersion"))versionAPI=fn;
    else if(!strcmp(name,"LockPortNativeSummon"))summonAPI=fn;
    else assert(0);
    registrations++;
}
static const char *__fastcall FakeToString(void *s,int index) { (void)s;assert(index==1);return inputUnit; }
static void __fastcall FakePushString(void *s,const char *text) { (void)s;strcpy(versionValue,text); }
static void __fastcall FakePushBoolean(void *s,int b) { (void)s;booleanValue=b; }
static int __fastcall FakeGetTop(void *s) { (void)s;return 1; }
static void __fastcall FakeSetTop(void *s,int top) { (void)s;assert(top==1);topRestores++; }
static uint64_t __fastcall FakeGuid(const char *unit) {
    assert(!strcmp(unit,"raid2") || !strcmp(unit,"party4"));
    return UINT64_C(0x1122334455667788);
}
static int32_t __fastcall FakeSlot(const char *spell, uint32_t *book) {
    assert(!strcmp(spell,"Ritual of Summoning"));
    *book=0;return 7;
}
static void __fastcall FakeBookCast(uint32_t slot,uint32_t book,uint64_t guid) {
    assert(slot==7&&book==0&&guid==UINT64_C(0x1122334455667788));
    // Model the real action gate: a frame-script context refuses the cast.
    if (*(uintptr_t *)0xCEEAC0 || *(uint32_t *)0xCEEAC4) return;
    executions++;
}
static void redirect(uintptr_t address, void *fn) { relativeJump((unsigned char *)address,fn); }
static void loadClient(void) {
    // Reserve only the handful of code regions used by these tests.
    // A full low-address image can overlap the test process's CRT heap.
    const uintptr_t regions[]={0x400000,0x420000,0x490000,0x4b0000,0x510000,0x6f0000,0x700000,0xce0000};
    for(unsigned i=0;i<sizeof(regions)/sizeof(regions[0]);i++)
        assert(VirtualAlloc((void *)regions[i],0x10000,
            MEM_COMMIT|MEM_RESERVE,PAGE_EXECUTE_READWRITE)==(void *)regions[i]);
    client=(unsigned char *)0x400000;
    FILE *f=fopen(clientPath,"rb");assert(f);
    fseek(f,0,SEEK_END);long size=ftell(f);rewind(f);
    unsigned char *raw=malloc((size_t)size);assert(raw);
    assert(fread(raw,1,(size_t)size,f)==(size_t)size);fclose(f);
    IMAGE_DOS_HEADER *dos=(IMAGE_DOS_HEADER *)raw;
    IMAGE_NT_HEADERS32 *nt=(IMAGE_NT_HEADERS32 *)(raw+dos->e_lfanew);
    memcpy(client,raw,nt->OptionalHeader.SizeOfHeaders);
    IMAGE_SECTION_HEADER *sections=IMAGE_FIRST_SECTION(nt);
    for(unsigned j=1;j<sizeof(regions)/sizeof(regions[0]);j++){
        DWORD rva=(DWORD)(regions[j]-0x400000);
        for(int i=0;i<nt->FileHeader.NumberOfSections;i++){
            IMAGE_SECTION_HEADER *s=sections+i;
            if(rva>=s->VirtualAddress && rva+0x10000<=s->VirtualAddress+s->SizeOfRawData)
                memcpy((void *)regions[j],raw+s->PointerToRawData+rva-s->VirtualAddress,0x10000);
        }
    }
    free(raw);
}
static void stubFunctions(void) {
    redirect(0x704120,(void *)(uintptr_t)&FakeRegister);
    redirect(0x6f3690,(void *)(uintptr_t)&FakeToString);
    redirect(0x6f3890,(void *)(uintptr_t)&FakePushString);
    redirect(0x6f39f0,(void *)(uintptr_t)&FakePushBoolean);
    redirect(0x6f3070,(void *)(uintptr_t)&FakeGetTop);
    redirect(0x6f3080,(void *)(uintptr_t)&FakeSetTop);
    redirect(0x515970,(void *)(uintptr_t)&FakeGuid);
    redirect(0x4b3950,(void *)(uintptr_t)&FakeSlot);
    redirect(0x4b3300,(void *)(uintptr_t)&FakeBookCast);
}
int main(int argc, char **argv) {
    if (argc > 1) clientPath = argv[1];
    loadClient();
    // The actual built DLL must reject this unrelated host executable.
    const char *dllPath = argc > 2 ? argv[2] : "LockPort.dll";
    assert(GetFileAttributesA(dllPath) != INVALID_FILE_ATTRIBUTES);
    HMODULE dll=LoadLibraryA(dllPath);
    DWORD loadError=GetLastError();
    assert(!dll && loadError==ERROR_DLL_INIT_FAILED);
    puts("PASS DLL rejects an unsupported host");
    assert(matchesClient());
    puts("PASS inspected client function signatures");
    assert(validUnit("raid1")&&validUnit("raid40")&&validUnit("party1")&&validUnit("party4"));
    const char *invalid[]={"player","party0","party5","party01","party1x","raid0","raid41","raid01","raid2x","raid2\");print(1)--","raid",NULL};
    for(unsigned i=0;i<sizeof(invalid)/sizeof(invalid[0]);i++)assert(!validUnit(invalid[i]));
    puts("PASS unit validation excludes non-group tokens and script input");
    // Exercise the real relocated prologue, replacing only its subsequent work.
    *(unsigned char *)0x706350=0xC3;
    *(unsigned char *)0x490256=0x5E; // original loader eventually restores esi
    redirect(0x490257,(void *)(uintptr_t)&FakeOriginal);
    stubFunctions();
    assert(!install());
    puts("PASS missing Lua-registration compatibility hook rejected");
    *(unsigned char *)0x42A320=0xC3; // supplied by existing client mods
    assert(install());
    ((LoadFunctionsFn)0x490250)();
    assert(originalCalls==1&&registrations==2&&versionAPI&&summonAPI);
    puts("PASS relocated loader trampoline and API registration");
    assert(versionAPI((void *)1)==1&&!strcmp(versionValue,"1.2.1"));
    *(uintptr_t *)0xCEEAC0=0x12345678;
    *(uint32_t *)0xCEEAC4=3;
    FakeBookCast(7,0,UINT64_C(0x1122334455667788));
    assert(executions==0);
    puts("PASS frame-script context reproduces the old silent cast refusal");
    inputUnit="raid2";assert(summonAPI((void *)1)==2&&booleanValue==1&&executions==1&&topRestores==0);
    assert(summonAPI((void *)1)==2&&booleanValue==0&&executions==1);
    assert(*(uintptr_t *)0xCEEAC0==0x12345678 && *(uint32_t *)0xCEEAC4==3);
    puts("PASS scoped command context permits cast and restores both values");
    puts("PASS native summon bridge, explicit spellbook slot and target GUID, and rate limit");
    hasAttempt=0; inputUnit="raid2x";summonAPI((void *)1);
    assert(booleanValue==0&&executions==1);
    inputUnit="raid2";luaThread=GetCurrentThreadId()+1;summonAPI((void *)1);
    assert(booleanValue==0&&executions==1);
    puts("PASS bad target and wrong game thread rejected");
    luaThread=GetCurrentThreadId();hasAttempt=0;inputUnit="party4";summonAPI((void *)1);
    assert(booleanValue==1&&executions==2);
    puts("PASS native party summon dispatch");
    // Exercise coexistence with an earlier mod's loader detour.
    DWORD old;VirtualProtect((void *)0x490250,6,PAGE_EXECUTE_READWRITE,&old);
    memcpy((void *)0x490250,signatures[0].bytes,6);
    redirect(0x490250,(void *)(uintptr_t)&FakeOriginal);
    assert(install());((LoadFunctionsFn)0x490250)();
    assert(originalCalls==2&&registrations==4);
    puts("PASS existing mod loader detour preserved");
    return 0;
}
