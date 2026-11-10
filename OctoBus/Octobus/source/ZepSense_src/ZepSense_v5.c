/*
 * ZepSense.dll  -  stage 1 (READ-ONLY survey)
 *
 * Adds two Lua globals to the 1.12.1 client:
 *   ZepSenseVersion()  -> 1                  (proves the DLL loaded and registered)
 *   ZepDump()          -> total, others      (writes ZepDump.txt next to WoW.exe)
 *
 * ZepDump walks the same "visible objects" list the client keeps (the list ClassicAPI's
 * ClosestGameObjectPosition walks) but, unlike ClassicAPI, it does NOT throw away objects
 * whose GUID tag it doesn't recognise (transports / zeppelins / boats are among those).
 * It only READS. It never writes to game memory and installs no code patches.
 *
 * All client addresses and calling conventions below were taken from ClassicAPI.dll's own
 * working code (ClosestGameObjectPosition), not from memory:
 *   0x00B41414  object manager pointer (0 when not in world)
 *   0x00468380  EnumVisibleObjects    ecx=callback, edx=param
 *   0x00468460  GetObjectByGuid       ecx=typemask, edx=0, stack: guid_lo, guid_hi, 0 (callee pops)
 *   vtable+0x14 GetPosition           thiscall(obj, float out[3]) -> float*
 *   0x00704120  FrameScript_RegisterFunction  ecx=name, edx=func
 *   0x006F3810  lua_pushnumber        thiscall(L, double)
 *   0x00CEEF74  global Lua state
 */
#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <stdio.h>
#include <string.h>
#include <stdarg.h>
#include <time.h>

#define ADDR_LUASTATE   0x00CEEF74u
#define ADDR_OBJMGR     0x00B41414u
#define FN_ENUMVISIBLE  0x00468380u
#define FN_GETOBJECT    0x00468460u
#define FN_REGISTER     0x00704120u
#define FN_PUSHNUMBER   0x006F3810u
#define FN_PUSHSTRING   0x006F3890u

#define WM_ZEPSENSE_REGISTER (WM_APP + 0x5A)
#define WM_ZEPSENSE_TICK     (WM_APP + 0x5B)

typedef void (__attribute__((thiscall)) *PushNumber_t)(void *L, double n);
typedef const float *(__attribute__((thiscall)) *GetPos_t)(void *obj, float *out);
/* ClassicAPI calls this with ecx=L, edx=string, nothing on the stack */
typedef void (__attribute__((fastcall)) *PushString_t)(void *L, const char *str);

static WNDPROC g_oldProc = NULL;
static HWND    g_hwnd = NULL;
static int     g_registered = 0;

/* tiny append-only log next to WoW.exe so we can see which stage failed */
static void Log(const char *fmt, ...)
{
    char path[MAX_PATH];
    char *slash;
    FILE *f;
    va_list ap;
    GetModuleFileNameA(NULL, path, MAX_PATH);
    slash = strrchr(path, '\\');
    if (slash) slash[1] = 0; else path[0] = 0;
    strcat(path, "ZepSense.log");
    f = fopen(path, "a");
    if (!f) return;
    fprintf(f, "[%lu] ", (unsigned long)GetTickCount());
    va_start(ap, fmt);
    vfprintf(f, fmt, ap);
    va_end(ap);
    fputc('\n', f);
    fclose(f);
}

/* ---------- safe-ish memory helpers ---------- */
static int Readable(const void *p, unsigned n)
{
    return p && !IsBadReadPtr(p, n);
}

/* ---------- client calls ---------- */
static void EnumVisible(void *cb, void *param)
{
    unsigned a = FN_ENUMVISIBLE, c = (unsigned)cb, d = (unsigned)param;
    __asm__ volatile("call *%%eax" : "+a"(a), "+c"(c), "+d"(d) : : "memory", "cc");
}

static void *GetObjectByGuid(unsigned lo, unsigned hi, unsigned mask)
{
    unsigned a = FN_GETOBJECT, c = mask, d = 0;
    __asm__ volatile(
        "pushl $0\n\t"
        "pushl %[h]\n\t"
        "pushl %[l]\n\t"
        "call *%%eax"
        : "+a"(a), "+c"(c), "+d"(d)
        : [h] "r"(hi), [l] "r"(lo)
        : "memory", "cc");
    return (void *)a;
}

static void RegisterLua(const char *name, void *fn)
{
    unsigned a = FN_REGISTER, c = (unsigned)name, d = (unsigned)fn;
    __asm__ volatile("call *%%eax" : "+a"(a), "+c"(c), "+d"(d) : : "memory", "cc");
}

/* ---------- the survey ---------- */
#define MAX_TAGS 64
typedef struct {
    FILE *f;
    unsigned total;
    unsigned others;            /* objects whose tag is not player/creature/pet/item/gameobject */
    unsigned tagList[MAX_TAGS];
    unsigned tagCount[MAX_TAGS];
    int tagN;
    unsigned dumped;
} Survey;

static void BumpTag(Survey *s, unsigned tag)
{
    int i;
    for (i = 0; i < s->tagN; i++)
        if (s->tagList[i] == tag) { s->tagCount[i]++; return; }
    if (s->tagN < MAX_TAGS) {
        s->tagList[s->tagN] = tag;
        s->tagCount[s->tagN] = 1;
        s->tagN++;
    }
}

static int __attribute__((thiscall)) EnumCb(void *ctx, unsigned lo, unsigned hi)
{
    Survey *s = (Survey *)ctx;
    unsigned tag = hi >> 16;
    unsigned entry = ((lo >> 24) | (hi << 8)) & 0xFFFFFFu;

    s->total++;
    BumpTag(s, tag);

    /* Players (0x0000) and items (0x4000) have no entry; creatures 0xF130, pets 0xF140
       are the common units. We only resolve positions for everything else, which is
       where game objects (0xF110) and anything unusual (transports) live. */
    if (tag == 0x0000 || tag == 0x4000 || tag == 0xF130 || tag == 0xF140)
        return 1;

    if (tag != 0xF110) s->others++;

    {
        void *obj = GetObjectByGuid(lo, hi, 0x20);
        float buf[3] = {0, 0, 0};
        const float *pos = NULL;
        int viaMask = 0x20;

        if (!obj) { obj = GetObjectByGuid(lo, hi, 0xFFFFFFFFu); viaMask = -1; }

        if (Readable(obj, 8)) {
            void **vtbl = *(void ***)obj;
            if (Readable(vtbl, 0x18)) {
                void *fn = vtbl[5]; /* +0x14 */
                if ((unsigned)fn >= 0x00401000u && (unsigned)fn < 0x00900000u) {
                    pos = ((GetPos_t)fn)(obj, buf);
                    if (pos && pos != buf && Readable(pos, 12)) {
                        buf[0] = pos[0]; buf[1] = pos[1]; buf[2] = pos[2];
                    }
                }
            }
        }

        if (s->f) {
            fprintf(s->f, "guid=%08X%08X tag=%04X entry=%u  pos=%.1f, %.1f, %.1f  resolved=%s\n",
                    hi, lo, tag, entry, buf[0], buf[1], buf[2],
                    obj ? (viaMask == 0x20 ? "mask20" : "maskFF") : "no");
            s->dumped++;
        }
    }
    return 1;
}

/* ---------- transport scanner (stage 2) ---------- */
#define MAX_REC 64
typedef struct {
    unsigned lo, hi, tag, guidEntry, descEntry;
    float x, y, z;
} TRec;
static TRec g_recs[MAX_REC];
static int  g_nrec = 0;
static unsigned g_seenGuid[MAX_REC][2];
static int  g_nseen = 0;

static int IsTransportTag(unsigned tag)
{
    /* everything that is not player/item/game object/creature/pet. Includes F120 and 1FC0 */
    return !(tag == 0x0000 || tag == 0x4000 || tag == 0xF130 || tag == 0xF140 || tag == 0xF110);
}

static int __attribute__((thiscall)) TransCb(void *ctx, unsigned lo, unsigned hi)
{
    unsigned tag = hi >> 16;
    (void)ctx;
    if (!IsTransportTag(tag) || g_nrec >= MAX_REC) return 1;
    {
        TRec *r = &g_recs[g_nrec];
        void *obj = GetObjectByGuid(lo, hi, 0x20);
        float buf[3] = {0, 0, 0};
        const float *pos;
        if (!obj) obj = GetObjectByGuid(lo, hi, 0xFFFFFFFFu);
        r->lo = lo; r->hi = hi; r->tag = tag;
        r->guidEntry = ((lo >> 24) | (hi << 8)) & 0xFFFFFFu;
        r->descEntry = 0;
        if (Readable(obj, 12)) {
            void **vtbl = *(void ***)obj;
            void *desc = *(void **)((char *)obj + 8);
            if (Readable(desc, 16)) r->descEntry = ((unsigned *)desc)[3];
            if (Readable(vtbl, 0x18)) {
                void *fn = vtbl[5];
                if ((unsigned)fn >= 0x00401000u && (unsigned)fn < 0x00900000u) {
                    pos = ((GetPos_t)fn)(obj, buf);
                    if (pos && pos != buf && Readable(pos, 12)) { buf[0] = pos[0]; buf[1] = pos[1]; buf[2] = pos[2]; }
                }
            }
        }
        r->x = buf[0]; r->y = buf[1]; r->z = buf[2];
        g_nrec++;
    }
    return 1;
}

static int InWorld(void)
{
    return Readable((void *)ADDR_OBJMGR, 4) && *(unsigned *)ADDR_OBJMGR != 0;
}

static void ScanTransports(void)
{
    g_nrec = 0;
    if (!InWorld()) return;
    EnumVisible((void *)TransCb, NULL);
}

static void LogTransports(void)
{
    char path[MAX_PATH];
    char *slash;
    FILE *f;
    int i, j;
    time_t now = time(NULL);

    ScanTransports();
    if (g_nrec == 0) return;

    GetModuleFileNameA(NULL, path, MAX_PATH);
    slash = strrchr(path, '\\');
    if (slash) slash[1] = 0; else path[0] = 0;
    strcat(path, "ZepTransports.log");
    f = fopen(path, "a");
    if (!f) return;

    for (i = 0; i < g_nrec; i++) {
        TRec *r = &g_recs[i];
        int seen = 0;
        for (j = 0; j < g_nseen; j++)
            if (g_seenGuid[j][0] == r->lo && g_seenGuid[j][1] == r->hi) { seen = 1; break; }
        if (!seen && g_nseen < MAX_REC) {
            g_seenGuid[g_nseen][0] = r->lo; g_seenGuid[g_nseen][1] = r->hi; g_nseen++;
            /* first sight of this object: dump the start of its descriptor block once */
            fprintf(f, "# new transport guid=%08X%08X tag=%04X\n", r->hi, r->lo, r->tag);
        }
        fprintf(f, "%lu guid=%08X%08X tag=%04X gentry=%u dentry=%u pos=%.1f,%.1f,%.1f\n",
                (unsigned long)now, r->hi, r->lo, r->tag, r->guidEntry, r->descEntry, r->x, r->y, r->z);
    }
    fclose(f);
}

/* ---------- Lua handlers (called by the client's Lua on the main thread) ---------- */
static int __attribute__((thiscall)) LuaVersion(void *L)
{
    ((PushNumber_t)FN_PUSHNUMBER)(L, 5.0);
    return 1;
}

static int __attribute__((thiscall)) LuaZepDump(void *L)
{
    Survey s;
    char path[MAX_PATH];
    char *slash;
    int i;

    memset(&s, 0, sizeof(s));

    if (!Readable((void *)ADDR_OBJMGR, 4) || *(unsigned *)ADDR_OBJMGR == 0) {
        ((PushNumber_t)FN_PUSHNUMBER)(L, -1.0);   /* not in world */
        return 1;
    }

    GetModuleFileNameA(NULL, path, MAX_PATH);
    slash = strrchr(path, '\\');
    if (slash) slash[1] = 0; else path[0] = 0;
    strcat(path, "ZepDump.txt");
    s.f = fopen(path, "w");

    if (s.f) fprintf(s.f, "# ZepSense survey. 'tag' is the top 16 bits of the object GUID.\n"
                          "# Known tags: 0000 player, 4000 item, F110 game object, F130 creature, F140 pet.\n"
                          "# Anything else (e.g. F120) is what ClassicAPI's lookup silently skips.\n\n");

    EnumVisible((void *)EnumCb, &s);

    if (s.f) {
        fprintf(s.f, "\n# totals: %u objects visible, %u with an unusual tag\n# tag histogram:\n", s.total, s.others);
        for (i = 0; i < s.tagN; i++)
            fprintf(s.f, "#   %04X : %u\n", s.tagList[i], s.tagCount[i]);
        fclose(s.f);
    }

    ((PushNumber_t)FN_PUSHNUMBER)(L, (double)s.total);
    ((PushNumber_t)FN_PUSHNUMBER)(L, (double)s.others);
    return 2;
}

static int __attribute__((thiscall)) LuaZepTransports(void *L)
{
    static char out[8192];
    int i, n = 0;
    out[0] = 0;
    ScanTransports();
    for (i = 0; i < g_nrec && n < (int)sizeof(out) - 160; i++) {
        TRec *r = &g_recs[i];
        n += sprintf(out + n, "%08X%08X,%04X,%u,%u,%.1f,%.1f,%.1f;",
                     r->hi, r->lo, r->tag, r->guidEntry, r->descEntry, r->x, r->y, r->z);
    }
    ((PushString_t)FN_PUSHSTRING)(L, out);
    return 1;
}

/* ---------- registration on the main thread via the game window ---------- */
static LRESULT CALLBACK NewProc(HWND h, UINT m, WPARAM w, LPARAM l)
{
    if (m == WM_ZEPSENSE_REGISTER) {
        RegisterLua("ZepSenseVersion", (void *)LuaVersion);
        RegisterLua("ZepDump", (void *)LuaZepDump);
        RegisterLua("ZepTransports", (void *)LuaZepTransports);
        g_registered++;
        Log("REGISTERED ZepSenseVersion and ZepDump on main thread (time #%d)", g_registered);
        return 0;
    }
    if (m == WM_ZEPSENSE_TICK) {
        static DWORD lastLog = 0;
        static DWORD lastReg = 0;
        DWORD t = GetTickCount();
        /* /reload rebuilds the Lua environment without changing the state pointer or the
           in-world flag, which silently deletes our globals. Re-registering is cheap and
           harmless, so just do it every 2 seconds while in the world. */
        if (t - lastReg >= 2000) {
            lastReg = t;
            RegisterLua("ZepSenseVersion", (void *)LuaVersion);
            RegisterLua("ZepDump", (void *)LuaZepDump);
            RegisterLua("ZepTransports", (void *)LuaZepTransports);
            g_registered++;
            if (g_registered <= 3 || (g_registered % 100) == 0)
                Log("periodic re-registration #%d", g_registered);
        }
        if (t - lastLog >= 3000) { lastLog = t; LogTransports(); }
        return 0;
    }
    return CallWindowProcA(g_oldProc, h, m, w, l);
}

static int g_bestScore = 0;
static long g_bestArea = 0;

static BOOL CALLBACK FindWowWindow(HWND h, LPARAM lp)
{
    DWORD pid = 0;
    (void)lp;
    GetWindowThreadProcessId(h, &pid);
    if (pid == GetCurrentProcessId() && IsWindowVisible(h)) {
        char title[96], cls[96];
        RECT r;
        int score = 1;
        long area = 0;
        title[0] = 0; cls[0] = 0;
        GetWindowTextA(h, title, sizeof(title));
        GetClassNameA(h, cls, sizeof(cls));
        if (GetClientRect(h, &r)) area = (long)(r.right - r.left) * (long)(r.bottom - r.top);
        if (strncmp(cls, "GxWindowClass", 13) == 0) score = 3;
        else if (strstr(title, "Warcraft") || strstr(title, "Octo")) score = 2;
        Log("window candidate hwnd=%p class='%s' title='%s' area=%ld score=%d", (void *)h, cls, title, area, score);
        if (area > 0 && (score > g_bestScore || (score == g_bestScore && area > g_bestArea))) {
            g_bestScore = score;
            g_bestArea = area;
            g_hwnd = h;
        }
    }
    return TRUE;
}

static DWORD WINAPI InitThread(LPVOID unused)
{
    int i;
    (void)unused;
    Log("ZepSense attached, init thread running (pid %lu)", (unsigned long)GetCurrentProcessId());

    /* wait for the game window */
    for (i = 0; i < 240 && !g_hwnd; i++) {
        EnumWindows(FindWowWindow, 0);
        if (!g_hwnd) Sleep(500);
    }
    if (!g_hwnd) { Log("gave up: no game window found"); return 0; }
    Log("using window %p (score %d)", (void *)g_hwnd, g_bestScore);

    /* wait for the Lua state, then give the client's own UI setup time to finish */
    for (i = 0; i < 600; i++) {
        if (Readable((void *)ADDR_LUASTATE, 4) && *(unsigned *)ADDR_LUASTATE != 0) break;
        Sleep(500);
    }
    Log("lua state ptr = %08X (waited %d ticks)", Readable((void *)ADDR_LUASTATE, 4) ? *(unsigned *)ADDR_LUASTATE : 0u, i);
    Sleep(5000);

    g_oldProc = (WNDPROC)SetWindowLongA(g_hwnd, GWL_WNDPROC, (LONG)NewProc);
    Log("subclass result old proc = %p (err %lu)", (void *)g_oldProc, (unsigned long)GetLastError());
    if (!g_oldProc) return 0;

    /* The client builds a fresh Lua environment when the UI (re)loads, which wipes any
       globals registered earlier. So watch for the Lua state or the "in world" flag
       changing, wait for the UI to settle, and register again every time. */
    {
        unsigned lastState = 0;
        int lastWorld = -1;
        DWORD changedAt = 0;
        int pending = 0;
        for (;;) {
            unsigned st = 0;
            int world = 0;
            if (Readable((void *)ADDR_LUASTATE, 4)) st = *(unsigned *)ADDR_LUASTATE;
            if (Readable((void *)ADDR_OBJMGR, 4)) world = (*(unsigned *)ADDR_OBJMGR != 0);
            if (st != lastState || world != lastWorld) {
                Log("change detected: lua state %08X -> %08X, in world %d -> %d", lastState, st, lastWorld, world);
                lastState = st;
                lastWorld = world;
                changedAt = GetTickCount();
                pending = 1;
            }
            if (pending && st && (GetTickCount() - changedAt) > 6000) {
                BOOL ok = PostMessageA(g_hwnd, WM_ZEPSENSE_REGISTER, 0, 0);
                Log("posted register message ok=%d", (int)ok);
                pending = 0;
            }
            if (world && st && !pending) PostMessageA(g_hwnd, WM_ZEPSENSE_TICK, 0, 0);
            Sleep(500);
        }
    }
    return 0;
}

BOOL WINAPI DllMain(HINSTANCE inst, DWORD reason, LPVOID reserved)
{
    (void)reserved;
    if (reason == DLL_PROCESS_ATTACH) {
        HANDLE t;
        DisableThreadLibraryCalls(inst);
        t = CreateThread(NULL, 0, InitThread, NULL, 0, NULL);
        if (t) CloseHandle(t);
    }
    return TRUE;
}
