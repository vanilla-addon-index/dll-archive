#include "weather.h"

WEATHER_SETTYPE p_weather_setType = reinterpret_cast<WEATHER_SETTYPE>(0x67baf0);
WEATHER_SETTYPE p_original_weather_setType = NULL;

bool weather_noRain = false;
bool weather_noSnow = false;
bool weather_noSandstorm = false;

void __fastcall detoured_weather_setType(void* self, void* ignored, int type, float intensity, bool unknown) {
    if (weather_noRain && type == 1) {
        p_original_weather_setType(self, 0, intensity, unknown);
    }
    else if (weather_noSnow && type == 2) {
        p_original_weather_setType(self, 0, intensity, unknown);
    }
    else if (weather_noSandstorm && type == 3) {
        p_original_weather_setType(self, 0, intensity, unknown);
    }
    else {
        p_original_weather_setType(self, type, intensity, unknown);
    }
}
