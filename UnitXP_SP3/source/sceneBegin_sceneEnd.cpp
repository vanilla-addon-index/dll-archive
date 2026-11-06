// This file requires to be saved in UTF-8 BOM, as it includes Chinese strings

#include <sstream>

#include <Windows.h>
#include <intrin.h>
#include <d3d9.h>
#include <d3dx9.h>

#include "MinHook.h"

#include "sceneBegin_sceneEnd.h"
#include "utf8_to_utf16.h"
#include "Vanilla1121_functions.h"
#include "FPScap.h"

static ID3DXFont* scene_fallback = NULL;
static ID3DXFont* scene_fallbackBIG = NULL;
static ID3DXFont* scene_fallbackSmall = NULL;
static ID3DXFont* scene_fallbackHUGE = NULL;
static ID3DXFont* scene_selected = NULL;
static ID3DXFont* scene_selectedBIG = NULL;
static ID3DXFont* scene_selectedSmall = NULL;
static ID3DXFont* scene_selectedHUGE = NULL;
static ID3DXSprite* scene_sprite = NULL;
static bool scene_attemptFontsReset = false;
static std::list<worldText::Floating> floatingTexts{};
static std::unordered_map<uint64_t, worldText::CritsGroup> critsGroups{};
static std::list<worldText::Floating> smallFloatingTexts{};
static bool scene_checkIfD3D = false;
static std::string scene_disableReason{};

// Google Gemini suggests skipping rendering d3dx9 text after a successfull Reset().
// It suggests that the game might need a few frames to finish its GPU initialization.
// https://codeberg.org/konaka/UnitXP_SP3/issues/13 reports this solution works
static int scene_delayDetouredSceneEnd = 2;

// There is one player reporting even with Gemini's delaying render, the game still froze on loading screen on Windows 10 22H2 with DirectX 9
// His loading progress bar was stuck at a quite early stage ( less than 25% )
// We try delaying until PLAYER_ENTERING_WORLD
int scene_inWorld = 0;
bool scene_needUnload = false;

// It is observed that when using software cursor, sceneEnd() would be called twice per frame
// However as nampower is also hooking into sceneEnd(), so we can't check RET address
// So we hook into gxDevice_scenePresent() which is right before the presenting sceneEnd() to toogle a flag
static bool scene_isPresenting = false;

LPDIRECT3DDEVICE9 scene_lastDXdevice = NULL;
bool scene_needReloadFont = false;
bool scene_fontsOnLost = false;
bool scene_needRebuildSprite = false;
bool scene_spriteOnLost = false;
bool scene_isEnabled = false;
bool scene_hideEXPtext = false;
int scene_fontSize = 36;
// ChatGPT: Microsoft YaHei is an Unicode font and it exists even on English Windows Vista
const static std::string scene_fallbackFontName{ u8"Microsoft YaHei" };
std::string scene_userSelectedFontName{ scene_fallbackFontName };

D3DXCREATEFFONTW pD3DXCreateFontW = NULL;
D3DXCREATESPRITE pD3DXCreateSprite = NULL;
void scene_init() {
    HMODULE hDLL = NULL;
    for (int ver = 43; ver >= 24; --ver) {
        std::stringstream ss{};
        ss << "d3dx9_" << ver << ".dll";

        hDLL = LoadLibraryA(ss.str().c_str());
        if (hDLL != NULL) {
            break;
        }
    }
    if (hDLL == NULL) {
        scene_disableReason = u8"UnitXP_SP3 requires d3dx9_43.dll to support anti-aliased floating combat text. Please try installing DirectX End-User Runtimes.";
        return;
    }

    pD3DXCreateFontW = reinterpret_cast<D3DXCREATEFFONTW>(GetProcAddress(hDLL, "D3DXCreateFontW"));
    pD3DXCreateSprite = reinterpret_cast<D3DXCREATESPRITE>(GetProcAddress(hDLL, "D3DXCreateSprite"));

    if (pD3DXCreateFontW == NULL || pD3DXCreateSprite == NULL) {
        FreeLibrary(hDLL);
        scene_disableReason = u8"It seems d3dx9 is broken. Please try reinstalling DirectX End-User Runtimes.";
        return;
    }

    scene_isEnabled = true;
}

static bool scene_fontIsOutlineCapable(ID3DXFont* font) {
    return GetOutlineTextMetricsW(font->GetDC(), 0, NULL) != 0;
}

static void scene_fontPreload(ID3DXFont* font) {
    // Visiable ASCII by ChatGPT
    font->PreloadCharacters(0x20, 0x7e);

    // Chinese
    // ChatGPT says: Calling ID3DXFont::PreloadText on a string that contains characters the font cannot render is safe in the sense that the API itself does not document (and there are no common reports of) crashes or undefined memory corruption when characters are unsupported.
    font->PreloadTextW(utf8_to_utf16(u8"经验值：").c_str(), 4);
    font->PreloadTextW(utf8_to_utf16(u8"脱离进入战斗").c_str(), 6);
    font->PreloadTextW(utf8_to_utf16(u8"非荣誉击杀").c_str(), 5);
    font->PreloadTextW(utf8_to_utf16(u8"未命中").c_str(), 3);
    font->PreloadTextW(utf8_to_utf16(u8"闪避").c_str(), 2);
    font->PreloadTextW(utf8_to_utf16(u8"招架").c_str(), 2);
    font->PreloadTextW(utf8_to_utf16(u8"格挡").c_str(), 2);
    font->PreloadTextW(utf8_to_utf16(u8"吸收").c_str(), 2);
    font->PreloadTextW(utf8_to_utf16(u8"免疫").c_str(), 2);
}

static void scene_spriteOnLostDevice() {
    if (scene_sprite != NULL) {
        scene_sprite->OnLostDevice();
    }
    scene_spriteOnLost = true;
}

static bool scene_spriteOnResetDevice() {
    scene_delayDetouredSceneEnd = 2;

    if (scene_sprite != NULL) {
        if (false == SUCCEEDED(scene_sprite->OnResetDevice())) {
            return false;
        }
    }
    scene_spriteOnLost = false;
    return true;
}

void scene_unloadSprite() {
    if (scene_sprite != NULL) {
        scene_sprite->Release();
        scene_sprite = NULL;
    }
}

bool scene_rebuildSprite() {
    if (scene_isEnabled == false) {
        return false;
    }
    else {
        scene_unloadSprite();
    }

    {
        if (scene_sprite == NULL) {
            if (false == SUCCEEDED(pD3DXCreateSprite(scene_lastDXdevice, &scene_sprite))) {
                scene_isEnabled = false;
                scene_disableReason = u8"Failed to build d3dx sprite.";
                return false;
            }
        }
    }

    scene_delayDetouredSceneEnd = 2;
    scene_needRebuildSprite = false;
    return true;
}

static void scene_fontsOnLostDevice() {
    if (scene_fallback != NULL) {
        scene_fallback->OnLostDevice();
    }
    if (scene_fallbackBIG != NULL) {
        scene_fallbackBIG->OnLostDevice();
    }
    if (scene_fallbackSmall != NULL) {
        scene_fallbackSmall->OnLostDevice();
    }
    if (scene_fallbackHUGE != NULL) {
        scene_fallbackHUGE->OnLostDevice();
    }
    if (scene_selected != NULL) {
        scene_selected->OnLostDevice();
    }
    if (scene_selectedBIG != NULL) {
        scene_selectedBIG->OnLostDevice();
    }
    if (scene_selectedSmall != NULL) {
        scene_selectedSmall->OnLostDevice();
    }
    if (scene_selectedHUGE != NULL) {
        scene_selectedHUGE->OnLostDevice();
    }
    scene_fontsOnLost = true;
}

static bool scene_fontsOnResetDevice() {

    scene_delayDetouredSceneEnd = 2;

    if (scene_fallback != NULL) {
        if (false == SUCCEEDED(scene_fallback->OnResetDevice())) {
            return false;
        }
    }
    if (scene_fallbackBIG != NULL) {
        if (false == SUCCEEDED(scene_fallbackBIG->OnResetDevice())) {
            return false;
        }
    }
    if (scene_fallbackSmall != NULL) {
        if (false == SUCCEEDED(scene_fallbackSmall->OnResetDevice())) {
            return false;
        }
    }
    if (scene_fallbackHUGE != NULL) {
        if (false == SUCCEEDED(scene_fallbackHUGE->OnResetDevice())) {
            return false;
        }
    }
    if (scene_selected != NULL) {
        if (false == SUCCEEDED(scene_selected->OnResetDevice())) {
            return false;
        }
    }
    if (scene_selectedBIG != NULL) {
        if (false == SUCCEEDED(scene_selectedBIG->OnResetDevice())) {
            return false;
        }
    }
    if (scene_selectedSmall != NULL) {
        if (false == SUCCEEDED(scene_selectedSmall->OnResetDevice())) {
            return false;
        }
    }
    if (scene_selectedHUGE != NULL) {
        if (false == SUCCEEDED(scene_selectedHUGE->OnResetDevice())) {
            return false;
        }
    }
    scene_fontsOnLost = false;
    return true;
}

void scene_unloadFonts() {
    if (scene_fallback != NULL) {
        scene_fallback->Release();
        scene_fallback = NULL;
    }
    if (scene_fallbackBIG != NULL) {
        scene_fallbackBIG->Release();
        scene_fallbackBIG = NULL;
    }
    if (scene_fallbackSmall != NULL) {
        scene_fallbackSmall->Release();
        scene_fallbackSmall = NULL;
    }
    if (scene_fallbackHUGE != NULL) {
        scene_fallbackHUGE->Release();
        scene_fallbackHUGE = NULL;
    }
    if (scene_selected != NULL) {
        scene_selected->Release();
        scene_selected = NULL;
    }
    if (scene_selectedBIG != NULL) {
        scene_selectedBIG->Release();
        scene_selectedBIG = NULL;
    }
    if (scene_selectedSmall != NULL) {
        scene_selectedSmall->Release();
        scene_selectedSmall = NULL;
    }
    if (scene_selectedHUGE != NULL) {
        scene_selectedHUGE->Release();
        scene_selectedHUGE = NULL;
    }
}

static void scene_unload() {
    scene_unloadFonts();
    scene_unloadSprite();
    scene_needUnload = false;
    scene_lastDXdevice = NULL;
    scene_needRebuildSprite = false;
    scene_needReloadFont = false;
    scene_spriteOnLost = false;
    scene_fontsOnLost = false;
}

void scene_end() {
    scene_unload();
    scene_isEnabled = false;
}

bool scene_reloadFont() {
    if (scene_isEnabled == false) {
        return false;
    }
    else {
        scene_unloadFonts();
    }

    {
        if (scene_fallback == NULL) {
            if (false == SUCCEEDED(pD3DXCreateFontW(scene_lastDXdevice, scene_fontSize, 0, FW_SEMIBOLD, 1, false, DEFAULT_CHARSET, OUT_DEFAULT_PRECIS, PROOF_QUALITY, DEFAULT_PITCH | FF_DONTCARE, utf8_to_utf16(scene_fallbackFontName).c_str(), &scene_fallback))) {
                scene_fallback = NULL;
                scene_isEnabled = false;
                scene_disableReason = u8"Failed to load the fallback font. This is usually due to an imcomplete installation of the Windows operating system.";
                return false;
            }
            if (false == scene_fontIsOutlineCapable(scene_fallback)) {
                scene_unloadFonts();
                scene_isEnabled = false;
                scene_disableReason = u8"The fallback font is not outline-capable. This is usually due to an imcomplete installation of the Windows operating system.";
                return false;
            }
            scene_fontPreload(scene_fallback);
        }

        if (scene_fallbackBIG == NULL) {
            if (false == SUCCEEDED(pD3DXCreateFontW(scene_lastDXdevice, scene_fontSize + 15, 0, FW_BOLD, 1, false, DEFAULT_CHARSET, OUT_DEFAULT_PRECIS, PROOF_QUALITY, DEFAULT_PITCH | FF_DONTCARE, utf8_to_utf16(scene_fallbackFontName).c_str(), &scene_fallbackBIG))) {
                scene_fallbackBIG = NULL;
                return false;
            }
            scene_fontPreload(scene_fallbackBIG);
        }

        if (scene_fallbackSmall == NULL) {
            if (false == SUCCEEDED(pD3DXCreateFontW(scene_lastDXdevice, scene_fontSize - 4, 0, FW_SEMIBOLD, 1, false, DEFAULT_CHARSET, OUT_DEFAULT_PRECIS, PROOF_QUALITY, DEFAULT_PITCH | FF_DONTCARE, utf8_to_utf16(scene_fallbackFontName).c_str(), &scene_fallbackSmall))) {
                scene_fallbackSmall = NULL;
                return false;
            }
            scene_fontPreload(scene_fallbackSmall);
        }

        if (scene_fallbackHUGE == NULL) {
            if (false == SUCCEEDED(pD3DXCreateFontW(scene_lastDXdevice, scene_fontSize + 15, 0, FW_HEAVY, 1, false, DEFAULT_CHARSET, OUT_DEFAULT_PRECIS, PROOF_QUALITY, DEFAULT_PITCH | FF_DONTCARE, utf8_to_utf16(scene_fallbackFontName).c_str(), &scene_fallbackHUGE))) {
                scene_fallbackHUGE = NULL;
                return false;
            }
            scene_fontPreload(scene_fallbackHUGE);
        }
    }

    {
        if (scene_selected == NULL) {
            if (false == SUCCEEDED(pD3DXCreateFontW(scene_lastDXdevice, scene_fontSize, 0, FW_SEMIBOLD, 1, false, DEFAULT_CHARSET, OUT_DEFAULT_PRECIS, PROOF_QUALITY, DEFAULT_PITCH | FF_DONTCARE, utf8_to_utf16(scene_userSelectedFontName).c_str(), &scene_selected))) {
                scene_userSelectedFontName = scene_fallbackFontName;
                if (false == SUCCEEDED(pD3DXCreateFontW(scene_lastDXdevice, scene_fontSize, 0, FW_SEMIBOLD, 1, false, DEFAULT_CHARSET, OUT_DEFAULT_PRECIS, PROOF_QUALITY, DEFAULT_PITCH | FF_DONTCARE, utf8_to_utf16(scene_userSelectedFontName).c_str(), &scene_selected))) {
                    scene_selected = NULL;
                    return false;
                }
            }
            if (false == scene_fontIsOutlineCapable(scene_selected)) {
                scene_selected->Release();
                scene_selected = NULL;
                scene_userSelectedFontName = scene_fallbackFontName;
                if (false == SUCCEEDED(pD3DXCreateFontW(scene_lastDXdevice, scene_fontSize, 0, FW_SEMIBOLD, 1, false, DEFAULT_CHARSET, OUT_DEFAULT_PRECIS, PROOF_QUALITY, DEFAULT_PITCH | FF_DONTCARE, utf8_to_utf16(scene_userSelectedFontName).c_str(), &scene_selected))) {
                    scene_selected = NULL;
                    return false;
                }
            }
            scene_fontPreload(scene_selected);
            utf8_reloadRenderRanges(reinterpret_cast<void*>(scene_selected));
        }

        if (scene_selectedBIG == NULL) {
            if (false == SUCCEEDED(pD3DXCreateFontW(scene_lastDXdevice, scene_fontSize + 15, 0, FW_BOLD, 1, false, DEFAULT_CHARSET, OUT_DEFAULT_PRECIS, PROOF_QUALITY, DEFAULT_PITCH | FF_DONTCARE, utf8_to_utf16(scene_userSelectedFontName).c_str(), &scene_selectedBIG))) {
                scene_selectedBIG = NULL;
                return false;
            }
            scene_fontPreload(scene_selectedBIG);
        }

        if (scene_selectedSmall == NULL) {
            if (false == SUCCEEDED(pD3DXCreateFontW(scene_lastDXdevice, scene_fontSize - 4, 0, FW_SEMIBOLD, 1, false, DEFAULT_CHARSET, OUT_DEFAULT_PRECIS, PROOF_QUALITY, DEFAULT_PITCH | FF_DONTCARE, utf8_to_utf16(scene_userSelectedFontName).c_str(), &scene_selectedSmall))) {
                scene_selectedSmall = NULL;
                return false;
            }
            scene_fontPreload(scene_selectedSmall);
        }

        if (scene_selectedHUGE == NULL) {
            if (false == SUCCEEDED(pD3DXCreateFontW(scene_lastDXdevice, scene_fontSize + 15, 0, FW_HEAVY, 1, false, DEFAULT_CHARSET, OUT_DEFAULT_PRECIS, PROOF_QUALITY, DEFAULT_PITCH | FF_DONTCARE, utf8_to_utf16(scene_userSelectedFontName).c_str(), &scene_selectedHUGE))) {
                scene_selectedHUGE = NULL;
                return false;
            }
            scene_fontPreload(scene_selectedHUGE);
        }
    }
    scene_delayDetouredSceneEnd = 2;
    scene_needReloadFont = false;
    return true;
}

SCENEBEGIN p_sceneBegin = reinterpret_cast<SCENEBEGIN>(0x5a1680);
SCENEBEGIN p_original_sceneBegin = NULL;
void __fastcall detoured_sceneBegin(uint32_t CGxDevice, void* ignored, uint32_t unknown) {
    if (scene_isEnabled == false) {
        p_original_sceneBegin(CGxDevice, unknown);
        return;
    }

    if (scene_checkIfD3D == false) {
        static char tempBuffer[64] = {};

        int len = GetClassNameA(vanilla1121_gameWindow(), tempBuffer, 64);
        if (len == 0) {
            p_original_sceneBegin(CGxDevice, unknown);
            return;
        }

        std::string currentAPI{ tempBuffer };

        if (currentAPI.find(u8"D3d") == std::string::npos) {
            scene_isEnabled = false;
            p_original_sceneBegin(CGxDevice, unknown);
            std::stringstream ss{};
            ss << "UnitXP_SP3 supports only the \"direct3d\" renderer. Currently the game is using \"" << currentAPI << "\".";
            scene_disableReason = ss.str();
            return;
        }
        else {
            scene_checkIfD3D = true;
        }
    }

    LPDIRECT3DDEVICE9 gDevice = reinterpret_cast<LPDIRECT3DDEVICE9>(vanilla1121_d3dDevice(vanilla1121_gxDevice()));
    if (gDevice == NULL || (reinterpret_cast<uintptr_t>(gDevice) & 1) != 0) {
        p_original_sceneBegin(CGxDevice, unknown);
        return;
    }

    uintptr_t ret = reinterpret_cast<uintptr_t>(_ReturnAddress());
    retAddressCheck(ret);

    if (ret == 0x5a1a27) {
        // We are at right after IDirect3DDevice9::Present()
        if (scene_needUnload) {
            scene_unload();
        }

        if (gDevice == scene_lastDXdevice && gDevice->TestCooperativeLevel() == D3D_OK) {
            if (scene_needRebuildSprite || scene_needReloadFont) {
                if (scene_needRebuildSprite && scene_spriteOnLost == false) {
                    scene_rebuildSprite();
                }
                if (scene_needReloadFont && scene_fontsOnLost == false) {
                    scene_reloadFont();
                }
            }
        }
        p_original_sceneBegin(CGxDevice, unknown);
        return;
    }

    if (ret == 0x5a256d) {
        // We are in CGxDeviceD3d::IStateSetD3DDefaults()
        if (scene_spriteOnLost) {
            scene_spriteOnResetDevice();
        }
        if (scene_fontsOnLost) {
            scene_fontsOnResetDevice();
        }
        p_original_sceneBegin(CGxDevice, unknown);
        return;
    }

    p_original_sceneBegin(CGxDevice, unknown);
}

// DX9 DEVICE LOSS RULE by ChatGPT:
// OnLostDevice() is ONLY called when TestCooperativeLevel() == D3DERR_DEVICENOTRESET
// NEVER call it when DEVICELOST
// And
// ID3DXFont::OnResetDevice() must be called after IDirect3DDevice9::Reset(), and before any BeginScene().
RELEASED3DRESOURCES p_releaseD3dResources = reinterpret_cast<RELEASED3DRESOURCES>(0x599900);
RELEASED3DRESOURCES p_original_releaseD3dResources = NULL;
void __fastcall detoured_releaseD3dResources(uint32_t self, void* ignored, int flag) {
    // flag == 0 when d3dDevice->Reset()
    // flag == 1 when DestroyD3dDevice()
    if (flag == 0) {
        scene_fontsOnLostDevice();
        scene_spriteOnLostDevice();
    }
    else if (flag == 1) {
        scene_unload();
    }

    p_original_releaseD3dResources(self, flag);
}

ISCENEEND p_sceneEnd = reinterpret_cast<ISCENEEND>(0x5a17a0);
ISCENEEND p_original_sceneEnd = NULL;
void __fastcall detoured_sceneEnd(uint32_t CGxDevice, void* ignored) {
    if (scene_inWorld != 1) {
        p_original_sceneEnd(CGxDevice);
        return;
    }

    if (scene_isPresenting == false) {
        p_original_sceneEnd(CGxDevice);
        return;
    }
    else {
        scene_isPresenting = false;
    }

    if (scene_delayDetouredSceneEnd <= 0
        && *reinterpret_cast<uint32_t*>(CGxDevice + 0x3a38) != NULL
        && scene_isEnabled == true) {
        LPDIRECT3DDEVICE9 dxDevice = reinterpret_cast<LPDIRECT3DDEVICE9>(vanilla1121_d3dDevice(CGxDevice));
        if (dxDevice == NULL || (reinterpret_cast<uintptr_t>(dxDevice) & 1) != 0) {
            p_original_sceneEnd(CGxDevice);
            return;
        }
        if (dxDevice != scene_lastDXdevice) {
            scene_lastDXdevice = dxDevice;
            scene_needReloadFont = true;
            scene_needRebuildSprite = true;
            p_original_sceneEnd(CGxDevice);
            return;
        }

        if (scene_sprite == NULL) {
            scene_needRebuildSprite = true;
            p_original_sceneEnd(CGxDevice);
            return;
        }

        if (scene_spriteOnLost || scene_needRebuildSprite) {
            p_original_sceneEnd(CGxDevice);
            return;
        }

        if (scene_fallback == NULL || scene_fallbackBIG == NULL || scene_fallbackSmall == NULL || scene_fallbackHUGE == NULL
            || scene_selected == NULL || scene_selectedBIG == NULL || scene_selectedSmall == NULL || scene_selectedHUGE == NULL) {
            scene_needReloadFont = true;
            p_original_sceneEnd(CGxDevice);
            return;
        }

        if (scene_fontsOnLost || scene_needReloadFont) {
            p_original_sceneEnd(CGxDevice);
            return;
        }

        // First iteration does not draw but only update RECT for overlapping test
        for (auto it = critsGroups.begin(); it != critsGroups.end();) {
            int update = -1;
            if (it->second.m_serif) {
                update = it->second.update(scene_selected, scene_selectedBIG, scene_selectedHUGE, scene_sprite, scene_lastDXdevice);
            }
            else {
                update = it->second.update(scene_fallback, scene_fallbackBIG, scene_fallbackHUGE, scene_sprite, scene_lastDXdevice);
            }

            if (update == -1) {
                it = critsGroups.erase(it);
                continue;
            }
            it++;
        }

        scene_sprite->Begin(D3DXSPRITE_ALPHABLEND);
        {
            for (auto it = smallFloatingTexts.begin(); it != smallFloatingTexts.end();) {
                int update = -1;
                if (it->m_serif) {
                    update = it->update(scene_selectedSmall, scene_sprite, scene_lastDXdevice);
                }
                else {
                    update = it->update(scene_fallbackSmall, scene_sprite, scene_lastDXdevice);
                }

                if (update == -1) {
                    it = smallFloatingTexts.erase(it);
                    continue;
                }

                if (update > 0) {
                    for (auto jt = critsGroups.begin(); jt != critsGroups.end(); jt++) {
                        if (jt->second.intersect(it->m_rect)) {
                            update = 0;
                            break;
                        }
                    }
                }

                if (update > 0) {
                    it->draw();
                }
                it++;
            }


            for (auto it = floatingTexts.begin(); it != floatingTexts.end();) {
                int update = -1;
                if (it->m_serif) {
                    update = it->update(scene_selected, scene_sprite, scene_lastDXdevice);
                }
                else {
                    update = it->update(scene_fallback, scene_sprite, scene_lastDXdevice);
                }

                if (update == -1) {
                    it = floatingTexts.erase(it);
                    continue;
                }

                if (update > 0) {
                    for (auto jt = critsGroups.begin(); jt != critsGroups.end(); jt++) {
                        RECT r = {};
                        if (jt->second.intersect(it->m_rect)) {
                            update = 0;
                            break;
                        }
                    }
                }

                if (update > 0) {
                    it->draw();
                }
                it++;
            }


            for (auto it = critsGroups.begin(); it != critsGroups.end();) {
                int update = -1;
                if (it->second.m_serif) {
                    update = it->second.update(scene_selected, scene_selectedBIG, scene_selectedHUGE, scene_sprite, scene_lastDXdevice);
                }
                else {
                    update = it->second.update(scene_fallback, scene_fallbackBIG, scene_fallbackHUGE, scene_sprite, scene_lastDXdevice);
                }

                if (update == -1) {
                    it = critsGroups.erase(it);
                    continue;
                }
                if (update > 0) {
                    it->second.draw();
                }
                it++;
            }
        }
        scene_sprite->End();
    }

    if (scene_delayDetouredSceneEnd > 0) {
        --scene_delayDetouredSceneEnd;
    }

    p_original_sceneEnd(CGxDevice);

    FPScap();
}

static void sortAddNewFloatingText(worldText::Floating& newText, std::list<worldText::Floating>& list, std::list<worldText::Floating>& secondListToCheck) {
    int maxOverlapHeight = -1;
    for (auto it = list.begin(); it != list.end(); ++it) {
        RECT r = {};
        if (IntersectRect(&r, &newText.m_rect, &it->m_rect)) {
            int intersectHeight = r.bottom - r.top;
            if (intersectHeight > maxOverlapHeight) {
                maxOverlapHeight = intersectHeight;
            }
        }
    }

    if (maxOverlapHeight > 0) {
        for (auto it = list.begin(); it != list.end(); ++it) {
            it->fastForward(maxOverlapHeight);
        }
    }

    list.push_back(newText);

    maxOverlapHeight = -1;
    for (auto it = secondListToCheck.begin(); it != secondListToCheck.end(); ++it) {
        RECT r = {};
        if (IntersectRect(&r, &newText.m_rect, &it->m_rect)) {
            int intersectHeight = r.bottom - r.top;
            if (intersectHeight > maxOverlapHeight) {
                maxOverlapHeight = intersectHeight;
            }
        }
    }

    if (maxOverlapHeight > 0) {
        for (auto it = secondListToCheck.begin(); it != secondListToCheck.end(); ++it) {
            it->fastForward(maxOverlapHeight);
        }
    }
}

static std::unordered_map<int, std::string> worldTextHistory{};
CREATEWORLDTEXT p_createWorldText = reinterpret_cast<CREATEWORLDTEXT>(0x6c73f0);
CREATEWORLDTEXT p_original_createWorldText = NULL;
bool scene_useXP3combatText = false;
void __fastcall detoured_createWorldText(uint32_t self, void* ignored, int type, char const* text, uint32_t color, uint32_t unknown) {
    if (scene_hideEXPtext && type == 4) {
        return;
    }

    if (scene_inWorld != 1) {
        p_original_createWorldText(self, type, text, color, unknown);
        return;
    }

    if (false == scene_useXP3combatText) {
        p_original_createWorldText(self, type, text, color, unknown);
        return;
    }

    if (false == scene_isEnabled) {
        p_original_createWorldText(self, type, text, color, unknown);
        return;
    }

    if (scene_lastDXdevice == NULL || scene_sprite == NULL || scene_fallback == NULL || scene_fallbackBIG == NULL || scene_fallbackHUGE == NULL || scene_fallbackSmall == NULL
        || scene_selected == NULL || scene_selectedBIG == NULL || scene_selectedHUGE == NULL || scene_selectedSmall == NULL) {
        p_original_createWorldText(self, type, text, color, unknown);
        return;
    }

    uint64_t stickToGUID = *reinterpret_cast<uint64_t*>(self + 0x10);
    if (stickToGUID == 0) {
        stickToGUID = vanilla1121_unitGUID("player");
    }

    ID3DXFont* font = scene_fallback;
    ID3DXFont* fontBIG = scene_fallbackBIG;
    ID3DXFont* fontHUGE = scene_fallbackHUGE;
    bool serif = false;
    if (utf8_canBeRendered(utf8_to_utf16(text))) {
        font = scene_selected;
        fontBIG = scene_selectedBIG;
        fontHUGE = scene_selectedHUGE;
        serif = true;
    }

    int r = 255;
    int g = 255;
    int b = 255;
    if (color != 0 && (color & 1) == 0) {
        r = (color >> 8) & 0xff;
        g = (color >> 16) & 0xff;
        b = (color >> 24) & 0xff;
    }

    // type:
    // 0 attack/heal
    // 1 absorb
    // 2 crit
    // 3 dodge
    // 4 exp
    // 5 honor
    switch (type) {
    case 0:
    case 1:
    case 3:
    case 4:
    case 5:
    {
        if (type == 4) {
            r = 0xff;
            g = 0x33;
            b = 0xcc;
        }
        else if (type == 5) {
            r = 239;
            g = 191;
            b = 4;
        }

        worldText::Floating newText(text, stickToGUID, r, g, b, 255, worldText::up, font, scene_sprite, serif, scene_lastDXdevice);
        sortAddNewFloatingText(newText, floatingTexts, smallFloatingTexts);
        return;
    }
    case 2:
    {
        auto it = critsGroups.find(stickToGUID);
        if (it == critsGroups.end()) {
            worldText::CritsGroup newGroup(stickToGUID, font, fontBIG, fontHUGE, scene_sprite, serif, scene_lastDXdevice);
            it = critsGroups.insert({ stickToGUID, newGroup }).first;
        }

        it->second.add(text, r, g, b, 255);
        return;
    }
    default:
    {
        std::stringstream ss{};
        ss << type << " " << std::string(text);

        if (color != 0 && (color & 1) == 0) {
            uint32_t c = *reinterpret_cast<uint32_t*>(color);
            ss << " (" << c << ")";
        }
        uint64_t testGUID = *reinterpret_cast<uint64_t*>(self + 0x10);
        ss << "0x" << testGUID << " ";
        worldTextHistory.insert({ type, ss.str() });
        p_original_createWorldText(self, type, text, color, unknown);
        return;
    }
    }
}

void scene_addSmallFloatingText(std::string text, int r, int g, int b, int a, worldText::FLOATING_DIRECTION direction) {
    if (scene_inWorld != 1) {
        return;
    }
    if (scene_isEnabled == false) {
        return;
    }
    if (scene_lastDXdevice == NULL || scene_sprite == NULL || scene_fallback == NULL || scene_fallbackBIG == NULL || scene_fallbackHUGE == NULL || scene_fallbackSmall == NULL
        || scene_selected == NULL || scene_selectedBIG == NULL || scene_selectedHUGE == NULL || scene_selectedSmall == NULL) {
        return;
    }

    ID3DXFont* font = scene_fallbackSmall;
    bool serif = false;
    if (utf8_canBeRendered(utf8_to_utf16(text))) {
        font = scene_selectedSmall;
        serif = true;
    }

    worldText::Floating newText(text, vanilla1121_unitGUID("player"), r, g, b, a, direction, font, scene_sprite, serif, scene_lastDXdevice);
    sortAddNewFloatingText(newText, smallFloatingTexts, floatingTexts);
}

void scene_addCritText(std::string text, int r, int g, int b, int a) {
    if (scene_inWorld != 1) {
        return;
    }
    if (scene_isEnabled == false) {
        return;
    }
    if (scene_lastDXdevice == NULL || scene_sprite == NULL || scene_fallback == NULL || scene_fallbackBIG == NULL || scene_fallbackHUGE == NULL || scene_fallbackSmall == NULL
        || scene_selected == NULL || scene_selectedBIG == NULL || scene_selectedHUGE == NULL || scene_selectedSmall == NULL) {
        return;
    }

    ID3DXFont* font = scene_fallback;
    ID3DXFont* fontBIG = scene_fallbackBIG;
    ID3DXFont* fontHUGE = scene_fallbackHUGE;
    bool serif = false;
    if (utf8_canBeRendered(utf8_to_utf16(text))) {
        font = scene_selected;
        fontBIG = scene_selectedBIG;
        fontHUGE = scene_selectedHUGE;
        serif = true;
    }

    uint64_t player = vanilla1121_unitGUID("player");

    auto it = critsGroups.find(player);
    if (it == critsGroups.end()) {
        worldText::CritsGroup newGroup(player, font, fontBIG, fontHUGE, scene_sprite, serif, scene_lastDXdevice);
        it = critsGroups.insert({ player, newGroup }).first;
    }

    it->second.add(text, r, g, b, a);
}

void scene_onPlayerEnteringWorld() {
    scene_inWorld = 1;
}

void scene_onPlayerLeavingWorld() {
    scene_inWorld = 0;
    scene_needUnload = true;
}

GXDEVICESCENEPRESENT p_gxDevice_scenePresent = reinterpret_cast<GXDEVICESCENEPRESENT>(0x592430);
GXDEVICESCENEPRESENT p_original_gxDevice_scenePresent = NULL;
void __fastcall detoured_gxDevice_scenePresent(void* self, void* ignored, int unknown) {
    p_original_gxDevice_scenePresent(self, unknown);
    scene_isPresenting = true;
    return;
}

std::string scene_debugText() {
    std::stringstream ss{};

    if (worldTextHistory.size() > 0) {
        ss << "Unimplemented world text history:";
        for (auto& i : worldTextHistory) {
            ss << std::endl << i.second;
        }
    }

    if (scene_inWorld != 1) {
        ss << "Player is not in world (" << scene_inWorld << ")" << std::endl;
    }

    LPDIRECT3DDEVICE9 gDevice = reinterpret_cast<LPDIRECT3DDEVICE9>(vanilla1121_d3dDevice(vanilla1121_gxDevice()));

    ss << "Fonts and Sprite state: " << reinterpret_cast<uint32_t>(gDevice) << "=" << reinterpret_cast<uint32_t>(scene_lastDXdevice) << " " << scene_spriteOnLost << " " << scene_needRebuildSprite << " " << scene_fontsOnLost << " " << scene_needReloadFont << " " << scene_delayDetouredSceneEnd << std::endl;

    if (scene_disableReason.length() > 0) {
        ss << scene_disableReason << std::endl;
    }

    return ss.str();
}
