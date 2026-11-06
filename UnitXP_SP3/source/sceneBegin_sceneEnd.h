#pragma once

#include <unordered_map>
#include <list>
#include <string>

#include <d3d9.h>

#include "worldText.h"

typedef HRESULT(WINAPI* D3DXCREATEFFONTW)(
    LPDIRECT3DDEVICE9       pDevice,
    INT                     Height,
    UINT                    Width,
    UINT                    Weight,
    UINT                    MipLevels,
    BOOL                    Italic,
    DWORD                   CharSet,
    DWORD                   OutputPrecision,
    DWORD                   Quality,
    DWORD                   PitchAndFamily,
    LPCWSTR                 pFaceName,
    LPD3DXFONT* ppFont);
typedef HRESULT(WINAPI* D3DXCREATESPRITE)(
    LPDIRECT3DDEVICE9   pDevice,
    LPD3DXSPRITE* ppSprite);

extern D3DXCREATEFFONTW pD3DXCreateFontW;
extern D3DXCREATESPRITE pD3DXCreateSprite;
extern bool scene_isEnabled;
extern bool scene_useXP3combatText;
extern bool scene_hideEXPtext;
extern int scene_fontSize;
extern LPDIRECT3DDEVICE9 scene_lastDXdevice;
extern std::string scene_userSelectedFontName;
// It seems d3d9 would crash if call reloadFont() between BeginScene() and EndScene(), so here is a bool switch to delay reloadFont() till Present() is done.
extern bool scene_needReloadFont;
extern bool scene_fontsOnLost;
extern bool scene_needRebuildSprite;
extern bool scene_spriteOnLost;
extern bool scene_needUnload;
extern int scene_inWorld;
void scene_init();
void scene_end();
void scene_unloadFonts();
void scene_unloadSprite();
bool scene_reloadFont();
bool scene_rebuildSprite();
void scene_addSmallFloatingText(std::string text, int r, int g, int b, int a, worldText::FLOATING_DIRECTION direction);
void scene_addCritText(std::string text, int r, int g, int b, int a);
std::string scene_debugText();

void scene_onPlayerEnteringWorld();
void scene_onPlayerLeavingWorld();

// The technique of hooking __thiscall function is from: https://tresp4sser.wordpress.com/2012/10/06/how-to-hook-thiscall-functions/
// -- Pointer is __thiscall with 1st param being THIS
// -- The detoured function is __fastcall with 1st param being THIS, and 2nd param being IGNORED

typedef void(__thiscall* SCENEBEGIN)(uint32_t, uint32_t);
extern SCENEBEGIN p_sceneBegin;
extern SCENEBEGIN p_original_sceneBegin;
void __fastcall detoured_sceneBegin(uint32_t CGxDevice, void* ignored, uint32_t unknown);

typedef void(__thiscall* ISCENEEND)(uint32_t);
extern ISCENEEND p_sceneEnd;
extern ISCENEEND p_original_sceneEnd;
void __fastcall detoured_sceneEnd(uint32_t CGxDevice, void* ignored);

typedef void(__thiscall* GXDEVICESCENEPRESENT)(void*, int);
extern GXDEVICESCENEPRESENT p_gxDevice_scenePresent;
extern GXDEVICESCENEPRESENT p_original_gxDevice_scenePresent;
void __fastcall detoured_gxDevice_scenePresent(void* self, void* ignored, int unknown);

typedef void(__thiscall* RELEASED3DRESOURCES)(uint32_t, int);
extern RELEASED3DRESOURCES p_releaseD3dResources;
extern RELEASED3DRESOURCES p_original_releaseD3dResources;
void __fastcall detoured_releaseD3dResources(uint32_t self, void* ignored, int flag);

typedef void(__thiscall* CREATEWORLDTEXT)(uint32_t, int, char const*, uint32_t, uint32_t);
extern CREATEWORLDTEXT p_createWorldText;
extern CREATEWORLDTEXT p_original_createWorldText;
void __fastcall detoured_createWorldText(uint32_t self, void* ignored, int type, char const* text, uint32_t color, uint32_t unknown);
