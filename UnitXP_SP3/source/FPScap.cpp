#pragma comment(lib, "winmm.lib")

#include <Windows.h>
#include <timeapi.h>
#include <d3d9.h>

#include <string>
#include <sstream>

#include "FPScap.h"
#include "performanceProfiling.h"
#include "Vanilla1121_functions.h"
#include "sceneBegin_sceneEnd.h"
#include "utf8_to_utf16.h"

typedef LONG(NTAPI* NTDELAYEXECUTION)(BOOLEAN Alertable, PLARGE_INTEGER DelayInterval);
static NTDELAYEXECUTION NtDelayExecution = NULL;

LARGE_INTEGER targetFrameInterval = {};
LARGE_INTEGER backgroundFrameInterval = {};

static LARGE_INTEGER nextFrameTime = {};
static int fpsMethod = 0; // 1 for NtDelayExecution()
static LARGE_INTEGER fpsSpinning = {};
static LARGE_INTEGER fpsResolutionUnit = {}; // Same as timerPrecision but in CPU ticks.
static MMRESULT timerPrecisionSet = TIMERR_NOCANDO;
static const UINT timerPrecision = 1u;

void FPScap() {
    // It is reported that unlimited FPS would make the game load faster
    // so we delay limiter till PLAYER_ENTERING_WORLD
    if (scene_inWorld != 1) {
        return;
    }

    bool inForeground = vanilla1121_gameInForeground();

    if (inForeground) {
        if (targetFrameInterval.QuadPart < 1) {
            return;
        }
    }
    else {
        if (backgroundFrameInterval.QuadPart < 1) {
            return;
        }
    }

    LARGE_INTEGER now = {};
    QueryPerformanceCounter(&now);

    LARGE_INTEGER sleep = {};
    sleep.QuadPart = nextFrameTime.QuadPart - now.QuadPart;

    // In case spinning time is shorter, we might miss the timing
    if (fpsResolutionUnit.QuadPart > fpsSpinning.QuadPart) {
        sleep.QuadPart -= fpsResolutionUnit.QuadPart;
    }

    if (sleep.QuadPart > fpsSpinning.QuadPart) {
        sleep.QuadPart -= fpsSpinning.QuadPart;
        sleep.QuadPart *= 10000000;
        sleep.QuadPart /= getPerformanceCounterFrequency().QuadPart;
        sleep.QuadPart = -sleep.QuadPart; // Negative values indicate relative time

        if (fpsMethod == 1) {
            NtDelayExecution(FALSE, &sleep);
        }
    }

    // Spinning for the tail
    QueryPerformanceCounter(&now);
    while (now.QuadPart < nextFrameTime.QuadPart) {
        if (inForeground) {
            YieldProcessor();
        }
        else {
            // For background, we try to give our time slice to others
            if (0 == SwitchToThread()) {
                YieldProcessor();
            }
        }
        QueryPerformanceCounter(&now);
    }

    // From https://github.com/doitsujin/dxvk/blob/4799558d322f67d1ff8f2c3958ff03e776b65bc6/src/util/util_fps_limiter.cpp#L51
    if (inForeground) {
        nextFrameTime.QuadPart = (now.QuadPart < nextFrameTime.QuadPart + targetFrameInterval.QuadPart)
            ? nextFrameTime.QuadPart + targetFrameInterval.QuadPart
            : now.QuadPart + targetFrameInterval.QuadPart;
    }
    else {
        nextFrameTime.QuadPart = (now.QuadPart < nextFrameTime.QuadPart + backgroundFrameInterval.QuadPart)
            ? nextFrameTime.QuadPart + backgroundFrameInterval.QuadPart
            : now.QuadPart + backgroundFrameInterval.QuadPart;
    }
}

void initFPScap() {
    targetFrameInterval.QuadPart = 0;
    backgroundFrameInterval.QuadPart = 0;
    nextFrameTime.QuadPart = 0;
    fpsSpinning.QuadPart = getPerformanceCounterFrequency().QuadPart / 250; // Some Linux default to 250 for CONFIG_HZ

    HMODULE ntdll = GetModuleHandleW(L"ntdll.dll");
    if (ntdll) {
        NtDelayExecution = reinterpret_cast<NTDELAYEXECUTION>(GetProcAddress(ntdll, "NtDelayExecution"));
        if (NtDelayExecution == NULL) {
            // Fallback to spinning
            fpsMethod = 0;
            return;
        }
    }
    else {
        // Fallback to spinning
        fpsMethod = 0;
        return;
    }

    fpsMethod = 1;

    timerPrecisionSet = timeBeginPeriod(timerPrecision);

    if (timerPrecisionSet == TIMERR_NOERROR) {
        fpsResolutionUnit.QuadPart = getPerformanceCounterFrequency().QuadPart / (1000 / timerPrecision);
    }
    else {
        fpsResolutionUnit.QuadPart = getPerformanceCounterFrequency().QuadPart / 64;
    }

    return;
}

void endFPScap() {
    if (timerPrecisionSet == TIMERR_NOERROR) {
        timeEndPeriod(timerPrecision);
    }
}

std::string debugFPScap() {
    std::stringstream ss{};
    ss << "FPS cap timing method: ";
    if (fpsMethod == 1) {
        ss << "NtDelayExecution() with tail spinning";
    }
    else {
        ss << "spinning";
    }

    return ss.str();
}
