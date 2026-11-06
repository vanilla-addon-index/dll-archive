#pragma once

#include <string>
#include <unordered_map>
#include <utility>

#include <Windows.h>
#include <d3dx9.h>

#include "performanceProfiling.h"

namespace worldText {
    extern const int animationFPS;
    extern double nameplateHeight;

    enum FLOATING_DIRECTION { up, down, arc };

    class Floating {
    public:
        Floating(std::string text, uint64_t stickToGUID, int r, int g, int b, int a, FLOATING_DIRECTION direction, ID3DXFont* font, ID3DXSprite* sprite, bool serif, LPDIRECT3DDEVICE9 device);

        // Return 1 = draw; 0 = invisible; -1 = end
        // As device might be lost during animation, we would update device
        int update(ID3DXFont* font, ID3DXSprite* sprite, LPDIRECT3DDEVICE9 device);
        void draw();
        void fastForward(int ffDistance);

        RECT m_rect;
        bool m_serif;
    private:
        std::string m_text;
        uint64_t m_stickToGUID;
        uint64_t m_playerGUID;
        int m_r;
        int m_g;
        int m_b;
        int m_a;
        LPDIRECT3DDEVICE9 m_device;
        ID3DXFont* m_font;
        ID3DXSprite* m_sprite;
        LARGE_INTEGER m_startTime;
        int m_width;
        int m_height;
        LARGE_INTEGER m_timingPrecision;
        double m_totalTime;
        double m_fadeOutTime;
        int m_floatingDistance;
        int m_shadowWeight;
        int m_offsetY;
        int m_offsetX;
        double m_arcRadius;
        int m_arcTowardsRight;
        double m_nameplatesOffset;
        FLOATING_DIRECTION m_direction;

        // The default copy constructor won't increase this, but we don't need it anyway.
        static uint64_t m_instanceCount;

        // Additional alpha blending
        double m_alpha;
    };

    class Crit {
    public:
        Crit(std::string text, uint64_t stickToGUID, int r, int g, int b, int a, ID3DXFont* fontNormal, ID3DXFont* fontBig, ID3DXFont* fontHuge, ID3DXSprite* sprite, bool serif, LPDIRECT3DDEVICE9 device);

        // Return 1 = draw; 0 = invisible; -1 = end
        // As device might be lost during animation, we would update device
        int update(ID3DXFont* fontNormal, ID3DXFont* fontBig, ID3DXFont* fontHuge, ID3DXSprite* sprite, LPDIRECT3DDEVICE9 device);

        void draw();
        void push(int toX, int toY);
        bool intersect(const RECT& rect) const;

        RECT m_rect;
        bool m_serif;
    private:
        std::string m_text;
        uint64_t m_stickToGUID;
        uint64_t m_playerGUID;
        int m_r;
        int m_g;
        int m_b;
        int m_a;

        // Additional alpha blending
        double m_alpha;
        double m_alpha_forHugeFont;
        ID3DXFont* m_fontNormal;
        ID3DXFont* m_fontBig;
        ID3DXFont* m_fontHuge;
        ID3DXFont* m_fontDraw;
        LPDIRECT3DDEVICE9 m_device;
        ID3DXSprite* m_sprite;
        LARGE_INTEGER m_startTime;
        LARGE_INTEGER m_timingPrecision;
        double m_totalTime;
        double m_fadeOutTime;
        double m_nameplatesOffset;
        int m_shadowWeight;
        int m_floatingDistance;
        int m_width;
        int m_height;
        DWORD m_drawFormat;
        int m_pushStartX;
        int m_pushStartY;
        int m_pushEndX;
        int m_pushEndY;
        LARGE_INTEGER m_pushStartTime;
    };

    class CritsGroup {
    public:
        CritsGroup(uint64_t stickToGUID, ID3DXFont* fontNormal, ID3DXFont* fontBig, ID3DXFont* fontHuge, ID3DXSprite* sprite, bool serif, LPDIRECT3DDEVICE9 device);

        // Return 1 = draw; 0 = invisible; -1 = end
        // As device might be lost during animation, we would update device
        int update(ID3DXFont* fontNormal, ID3DXFont* fontBig, ID3DXFont* fontHuge, ID3DXSprite* sprite, LPDIRECT3DDEVICE9 device);

        void draw();
        bool intersect(const RECT& rect) const;
        void add(std::string text, int r, int g, int b, int a);

        bool m_serif;
    private:
        uint64_t m_stickToGUID;
        ID3DXFont* m_fontNormal;
        ID3DXFont* m_fontBig;
        ID3DXFont* m_fontHuge;
        LPDIRECT3DDEVICE9 m_device;
        ID3DXSprite* m_sprite;
        std::unordered_map< std::string, std::pair<int, Crit> > m_crits; // pair = {update result, the Crit instance}
        int m_pushWidth;
        int m_pushHeight;
    };
}
