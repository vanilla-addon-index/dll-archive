#define _USE_MATH_DEFINES
#include <cmath>
#include <random>

#include <Windows.h>

#include "worldText.h"
#include "Vanilla1121_functions.h"
#include "utf8_to_utf16.h"
#include "inSight.h"
#include "distanceBetween.h"

const int worldText::animationFPS = 180;
uint64_t worldText::Floating::m_instanceCount = 0;
double worldText::nameplateHeight = 55.0f;

worldText::Floating::Floating(std::string text, uint64_t stickToGUID, int r, int g, int b, int a, FLOATING_DIRECTION direction, ID3DXFont* font, ID3DXSprite* sprite, bool serif, LPDIRECT3DDEVICE9 device) {
    m_text = text;
    m_stickToGUID = stickToGUID;
    m_playerGUID = vanilla1121_unitGUID("player");
    m_serif = serif;
    m_r = r;
    m_g = g;
    m_b = b;
    m_a = a;
    m_alpha = 1.0;
    m_direction = direction;
    m_instanceCount++;
    m_arcTowardsRight = m_instanceCount % 2 == 0 ? 1 : -1;

    QueryPerformanceCounter(&m_startTime);

    SetRect(&m_rect, 0, 0, 1, 1);
    m_height = font->DrawTextW(NULL, utf8_to_utf16(text).c_str(), -1, &m_rect, DT_LEFT | DT_CALCRECT, D3DCOLOR_XRGB(r, g, b));
    m_width = m_rect.right;

    m_timingPrecision.QuadPart = getPerformanceCounterFrequency().QuadPart / animationFPS;
    m_totalTime = 1.9;
    m_fadeOutTime = 1.3;
    m_shadowWeight = 2;
    m_offsetY = 0;
    m_offsetX = 0;

    float useScale = std::stof(vanilla1121_getCVar("useUiScale"));
    float uiScale = 1.0f;
    if (useScale > 0.0f) {
        uiScale = std::stof(vanilla1121_getCVar("uiScale"));
    }

    RECT winSize = vanilla1121_gameClientRect();

    m_arcRadius = 150.0 / 768.0 / uiScale * (winSize.bottom - winSize.top);
    m_nameplatesOffset = nameplateHeight / 768.0f / uiScale * (winSize.bottom - winSize.top);

    m_floatingDistance = static_cast<int>((609.0 - 384.0) / 768.0 / uiScale * (winSize.bottom - winSize.top));
    m_floatingDistance /= 2;
    if (m_playerGUID == m_stickToGUID) {
        m_floatingDistance = static_cast<int>(m_floatingDistance * 1.5);
    }

    update(font, sprite, device);
}

int worldText::Floating::update(ID3DXFont* font, ID3DXSprite* sprite, LPDIRECT3DDEVICE9 device) {
    m_font = font;
    m_device = device;
    m_sprite = sprite;

    LARGE_INTEGER now = {};
    QueryPerformanceCounter(&now);

    if (now.QuadPart - m_startTime.QuadPart > m_totalTime * getPerformanceCounterFrequency().QuadPart) {
        return -1;
    }

    uint32_t stickTo = vanilla1121_getVisiableObject(m_stickToGUID);
    if (stickTo == 0) {
        return 0;
    }
    if (vanilla1121_objectType(stickTo) != OBJECT_TYPE_Player && vanilla1121_objectType(stickTo) != OBJECT_TYPE_Unit) {
        return 0;
    }

    C3Vector pos = vanilla1121_unitPosition(stickTo);
    float h = vanilla1121_unitCollisionBoxHeight(stickTo);
    if (m_stickToGUID != m_playerGUID) {
        h = std::fmin(4.0f, h);
        pos.z += h;
    }
    else {
        pos.z += h / 5.0f;
    }

    C3Vector p = vanilla1121_worldToScreen(pos);
    if (p.x < 0.0f || p.y < 0.0f) {
        return 0;
    }

    if (m_stickToGUID != m_playerGUID) {
        C3Vector camPos = vanilla1121_getCameraPosition(vanilla1121_getCamera());
        C3Vector playerPos = vanilla1121_unitPosition(vanilla1121_getVisiableObject(m_playerGUID));
        C3Vector targetPos = vanilla1121_unitPosition(vanilla1121_getVisiableObject(m_stickToGUID));

        float perspectiveOffset = static_cast<float>(m_nameplatesOffset * UnitXP_distanceBetween(camPos, playerPos) / UnitXP_distanceBetween(camPos, targetPos));
        p.y -= perspectiveOffset;
    }

    double elapsed = static_cast<double>((now.QuadPart - m_startTime.QuadPart) / m_timingPrecision.QuadPart);
    double totalFrameCount = m_totalTime * animationFPS;
    double step = elapsed / totalFrameCount;


    switch (m_direction) {
    case down:
    {
        SetRect(&m_rect, static_cast<int>(p.x) - m_width / 2 + m_offsetX, static_cast<int>(p.y) - m_height + m_offsetY + static_cast<int>(step * m_floatingDistance), static_cast<int>(p.x) + m_width / 2 + m_offsetX, static_cast<int>(p.y) + m_offsetY + static_cast<int>(step * m_floatingDistance));
        break;
    }
    case arc:
    {

        int arcX = static_cast<int>(m_arcTowardsRight * (m_arcRadius * cos(M_PI_2 * step) - m_arcRadius));
        int arcY = static_cast<int>(m_arcRadius * sin(M_PI_2 * step));

        SetRect(&m_rect, static_cast<int>(p.x) - m_width / 2 + m_offsetX + arcX, static_cast<int>(p.y) - m_height + m_offsetY - arcY, static_cast<int>(p.x) + m_width / 2 + m_offsetX + arcX, static_cast<int>(p.y) + m_offsetY - arcY);
        break;
    }
    default:
    {
        SetRect(&m_rect, static_cast<int>(p.x) - m_width / 2 + m_offsetX, static_cast<int>(p.y) - m_height + m_offsetY - static_cast<int>(step * m_floatingDistance), static_cast<int>(p.x) + m_width / 2 + m_offsetX, static_cast<int>(p.y) + m_offsetY - static_cast<int>(step * m_floatingDistance));
    }
    }

    double fadeOut = m_fadeOutTime * animationFPS;
    if (elapsed > fadeOut) {
        m_alpha = 1.0 - (elapsed - fadeOut) / (totalFrameCount - fadeOut);
        m_alpha = std::fmax(0.0, m_alpha);
    }
    else {
        m_alpha = 1.0;
    }

    // We test inSight so late that even the unit is out of sight, its m_rect get updated
    if (0 >= camera_inSight(reinterpret_cast<void*>(stickTo))) {
        return 0;
    }

    return 1;
}

void worldText::Floating::draw() {
    RECT shadowRect = {};
    CopyRect(&shadowRect, &m_rect);
    shadowRect.left += m_shadowWeight;
    shadowRect.right += m_shadowWeight;

    if (m_playerGUID == m_stickToGUID) {
        shadowRect.top += m_shadowWeight;
        shadowRect.bottom += m_shadowWeight;
    }
    else {
        shadowRect.left += m_shadowWeight;
        shadowRect.right += m_shadowWeight;
        shadowRect.top -= m_shadowWeight;
        shadowRect.bottom -= m_shadowWeight;
    }

    m_font->DrawTextW(m_sprite, utf8_to_utf16(m_text).c_str(), -1, &shadowRect, DT_LEFT, D3DCOLOR_ARGB(static_cast<int>(200 * m_alpha), 0, 0, 0));
    m_font->DrawTextW(m_sprite, utf8_to_utf16(m_text).c_str(), -1, &m_rect, DT_LEFT, D3DCOLOR_ARGB(static_cast<int>(m_a * m_alpha), m_r, m_g, m_b));
}

void worldText::Floating::fastForward(int ffDistance) {
    m_startTime.QuadPart -= static_cast<LONGLONG>((static_cast<double>(ffDistance) / static_cast<double>(m_floatingDistance)) * m_totalTime * animationFPS) * m_timingPrecision.QuadPart;
}

worldText::Crit::Crit(std::string text, uint64_t stickToGUID, int r, int g, int b, int a, ID3DXFont* fontNormal, ID3DXFont* fontBig, ID3DXFont* fontHuge, ID3DXSprite* sprite, bool serif, LPDIRECT3DDEVICE9 device) {
    m_text = text;
    m_serif = serif;
    m_stickToGUID = stickToGUID;
    m_playerGUID = vanilla1121_unitGUID("player");
    m_totalTime = 2.2;
    m_fadeOutTime = 1.6;
    m_r = r;
    m_g = g;
    m_b = b;
    m_a = a;
    m_alpha = 1.0;
    m_alpha_forHugeFont = 0.0;
    m_timingPrecision.QuadPart = getPerformanceCounterFrequency().QuadPart / animationFPS;
    m_drawFormat = DT_LEFT;
    m_pushStartX = 0;
    m_pushStartY = 0;
    m_pushEndX = 0;
    m_pushEndY = 0;
    m_pushStartTime = {};

    QueryPerformanceCounter(&m_startTime);

    SetRect(&m_rect, 0, 0, 1, 1);
    m_height = fontHuge->DrawTextW(NULL, utf8_to_utf16(text).c_str(), -1, &m_rect, DT_LEFT | DT_CALCRECT, D3DCOLOR_XRGB(r, g, b));
    m_width = m_rect.right;

    m_shadowWeight = 2;
    m_fontDraw = m_fontNormal;

    float useScale = std::stof(vanilla1121_getCVar("useUiScale"));
    float uiScale = 1.0f;
    if (useScale > 0.0f) {
        uiScale = std::stof(vanilla1121_getCVar("uiScale"));
    }

    RECT winSize = vanilla1121_gameClientRect();

    m_nameplatesOffset = nameplateHeight / 768.0f / uiScale * (winSize.bottom - winSize.top);

    // Original
    m_floatingDistance = static_cast<int>((609.0 - 384.0) / 768.0 / uiScale * (winSize.bottom - winSize.top));

    // Adjusted
    m_floatingDistance /= 2;
    if (m_playerGUID == m_stickToGUID) {
        m_floatingDistance = static_cast<int>(m_floatingDistance * 1.5);
    }

    update(fontNormal, fontBig, fontHuge, sprite, device);
}

int worldText::Crit::update(ID3DXFont* fontNormal, ID3DXFont* fontBig, ID3DXFont* fontHuge, ID3DXSprite* sprite, LPDIRECT3DDEVICE9 device) {
    m_fontNormal = fontNormal;
    m_fontBig = fontBig;
    m_fontHuge = fontHuge;
    m_device = device;
    m_sprite = sprite;

    LARGE_INTEGER now = {};
    QueryPerformanceCounter(&now);

    if (now.QuadPart - m_startTime.QuadPart > m_totalTime * getPerformanceCounterFrequency().QuadPart) {
        return -1;
    }

    uint32_t stickTo = vanilla1121_getVisiableObject(m_stickToGUID);
    if (stickTo == 0) {
        return 0;
    }
    if (vanilla1121_objectType(stickTo) != OBJECT_TYPE_Player && vanilla1121_objectType(stickTo) != OBJECT_TYPE_Unit) {
        return 0;
    }

    C3Vector pos = vanilla1121_unitPosition(stickTo);
    float h = vanilla1121_unitCollisionBoxHeight(stickTo);
    if (m_stickToGUID != m_playerGUID) {
        h = std::fmin(4.0f, h);
        pos.z += h;
    }
    else {
        pos.z += h / 2.0f;
    }

    C3Vector screenPos = vanilla1121_worldToScreen(pos);
    if (screenPos.x < 0.0f || screenPos.y < 0.0f) {
        return 0;
    }

    if (m_stickToGUID != m_playerGUID) {
        C3Vector camPos = vanilla1121_getCameraPosition(vanilla1121_getCamera());
        C3Vector playerPos = vanilla1121_unitPosition(vanilla1121_getVisiableObject(m_playerGUID));
        C3Vector targetPos = vanilla1121_unitPosition(vanilla1121_getVisiableObject(m_stickToGUID));

        float perspectiveOffset = static_cast<float>(m_nameplatesOffset * UnitXP_distanceBetween(camPos, playerPos) / UnitXP_distanceBetween(camPos, targetPos));
        screenPos.y -= perspectiveOffset;
    }

    // fade in fade out
    {
        double elapsed = static_cast<double>((now.QuadPart - m_startTime.QuadPart) / m_timingPrecision.QuadPart);
        double totalFrameCount = m_totalTime * animationFPS;

        if (elapsed < 0.2 * animationFPS) {
            m_fontDraw = m_fontNormal;
            m_drawFormat = DT_CENTER | DT_VCENTER;
            m_alpha_forHugeFont = 0.0;
            m_alpha = elapsed / (0.2 * animationFPS);
            m_alpha = std::fmax(0.0, m_alpha);
            m_alpha = std::fmin(1.0, m_alpha);
        }
        /*else if (elapsed < 0.4 * animationFPS) {
            m_fontDraw = m_fontBig;
            m_drawFormat = DT_LEFT;
            m_alpha = 1.0;
            m_alpha_forHugeFont = 1.0 - (elapsed - 0.2 * animationFPS) / (0.2 * animationFPS);
            m_alpha_forHugeFont = std::fmax(0.0, m_alpha_forHugeFont);
            m_alpha_forHugeFont = std::fmin(1.0, m_alpha_forHugeFont);
        }*/
        else {
            m_fontDraw = m_fontBig;
            m_drawFormat = DT_LEFT;
            m_alpha_forHugeFont = 0.0;

            double fadeOut = m_fadeOutTime * animationFPS;
            if (elapsed > fadeOut) {
                m_alpha = 1.0 - (elapsed - fadeOut) / (totalFrameCount - fadeOut);
                m_alpha = std::fmax(0.0, m_alpha);
                m_alpha = std::fmin(1.0, m_alpha);
            }
            else {
                m_alpha = 1.0;
            }
        }
    }

    // shake
    int shakeX = 0;
    int shakeY = 0;
    {
        double elapsed = static_cast<double>((now.QuadPart - m_startTime.QuadPart) / m_timingPrecision.QuadPart);
        double totalFrameCount = 0.3 * animationFPS;
        if (elapsed < totalFrameCount) {
            double shakePower = std::exp(-2.0 * elapsed / totalFrameCount);
            double waveX = std::cos(M_PI * 2.0 * elapsed / totalFrameCount);
            double waveY = std::sin(M_PI * 2.0 * elapsed / totalFrameCount * 3.0);
            double height = m_rect.bottom - m_rect.top;
            shakeX = static_cast<int>(shakePower * waveX * height / 6);
            shakeY = static_cast<int>(shakePower * waveY * height / 6);
        }
    }

    // push animation
    double push = 0.0;
    {
        double elapsed = static_cast<double>((now.QuadPart - m_pushStartTime.QuadPart) / m_timingPrecision.QuadPart);
        double totalFrameCount = 0.3 * animationFPS;

        push = std::fmin(1.0, elapsed / totalFrameCount);
    }

    SetRect(&m_rect,
        static_cast<int>(screenPos.x) - m_width / 2 + static_cast<int>(push * (m_pushEndX - m_pushStartX)) + shakeX,
        static_cast<int>(screenPos.y) - m_height + static_cast<int>(push * (m_pushEndY - m_pushStartY)) + shakeY,
        static_cast<int>(screenPos.x) + m_width / 2 + static_cast<int>(push * (m_pushEndX - m_pushStartX)) + shakeX,
        static_cast<int>(screenPos.y) + static_cast<int>(push * (m_pushEndY - m_pushStartY)) + shakeY);

    // We test inSight so late that even the unit is out of sight, its m_rect get updated
    if (0 >= camera_inSight(reinterpret_cast<void*>(stickTo))) {
        return 0;
    }

    return 1;
}

void worldText::Crit::push(int toX, int toY) {
    m_pushEndX = toX;
    m_pushEndY = toY;
    QueryPerformanceCounter(&m_pushStartTime);
}

bool worldText::Crit::intersect(const RECT& rect) const {
    RECT tmp = {};
    if (IntersectRect(&tmp, &m_rect, &rect) != 0) {
        return true;
    }
    else {
        return false;
    }
}

void worldText::Crit::draw() {
    RECT shadowRect = {};
    CopyRect(&shadowRect, &m_rect);
    shadowRect.left += m_shadowWeight;
    shadowRect.right += m_shadowWeight;

    if (m_stickToGUID == m_playerGUID) {
        shadowRect.top += m_shadowWeight;
        shadowRect.bottom += m_shadowWeight;
    }
    else {
        shadowRect.left += m_shadowWeight;
        shadowRect.right += m_shadowWeight;
        shadowRect.top -= m_shadowWeight;
        shadowRect.bottom -= m_shadowWeight;
    }

    m_fontDraw->DrawTextW(m_sprite, utf8_to_utf16(m_text).c_str(), -1, &shadowRect, m_drawFormat, D3DCOLOR_ARGB(static_cast<int>(200 * m_alpha), 0, 0, 0));
    m_fontDraw->DrawTextW(m_sprite, utf8_to_utf16(m_text).c_str(), -1, &m_rect, m_drawFormat, D3DCOLOR_ARGB(static_cast<int>(m_a * m_alpha), m_r, m_g, m_b));

    /*if (m_alpha_forHugeFont > 0.0) {
        m_fontHuge->DrawTextW(m_sprite, utf8_to_utf16(m_text).c_str(), -1, &shadowRect, m_drawFormat, D3DCOLOR_ARGB(static_cast<int>(200 * m_alpha_forHugeFont), 0, 0, 0));
        m_fontHuge->DrawTextW(m_sprite, utf8_to_utf16(m_text).c_str(), -1, &m_rect, m_drawFormat, D3DCOLOR_ARGB(static_cast<int>(m_a * m_alpha_forHugeFont), m_r, m_g, m_b));
    }*/
}

worldText::CritsGroup::CritsGroup(uint64_t stickToGUID, ID3DXFont* fontNormal, ID3DXFont* fontBig, ID3DXFont* fontHuge, ID3DXSprite* sprite, bool serif, LPDIRECT3DDEVICE9 device)
    : m_crits{} {
    m_stickToGUID = stickToGUID;
    m_fontBig = fontBig;
    m_fontHuge = fontHuge;
    m_fontNormal = fontNormal;
    m_device = device;
    m_sprite = sprite;
    m_serif = serif;

    RECT rectTemp = {};
    SetRect(&rectTemp, 0, 0, 1, 1);
    m_pushHeight = fontBig->DrawTextW(NULL, utf8_to_utf16("88888").c_str(), -1, &rectTemp, DT_LEFT | DT_CALCRECT, D3DCOLOR_XRGB(200, 200, 200));
    m_pushWidth = rectTemp.right;
}

int worldText::CritsGroup::update(ID3DXFont* fontNormal, ID3DXFont* fontBig, ID3DXFont* fontHuge, ID3DXSprite* sprite, LPDIRECT3DDEVICE9 device) {
    m_fontBig = fontBig;
    m_fontHuge = fontHuge;
    m_fontNormal = fontNormal;
    m_device = device;
    m_sprite = sprite;

    bool end = true;
    for (auto it = m_crits.begin(); it != m_crits.end();) {
        int result = it->second.second.update(m_fontNormal, m_fontBig, m_fontHuge, m_sprite, m_device);
        if (result >= 0) {
            end = false;
            it->second.first = result;
            ++it;
        }
        else {
            it = m_crits.erase(it);
        }
    }

    if (end) {
        return -1;
    }
    else {
        return 1;
    }
}

bool worldText::CritsGroup::intersect(const RECT& rect) const {
    for (auto it = m_crits.begin(); it != m_crits.end(); ++it) {
        if (it->second.first == 1 && it->second.second.intersect(rect) == true) {
            return true;
        }
    }
    return false;
}

void worldText::CritsGroup::draw() {
    for (auto it = m_crits.begin(); it != m_crits.end(); ++it) {
        if (it->second.first == 1) {
            it->second.second.draw();
        }
    }
}

void worldText::CritsGroup::add(std::string text, int r, int g, int b, int a) {
    Crit newCrit(text, m_stickToGUID, r, g, b, a, m_fontNormal, m_fontBig, m_fontHuge, m_sprite, m_serif, m_device);

    if (m_crits.find("center") == m_crits.end()) {
        m_crits.insert_or_assign("center", std::make_pair(1, newCrit));
    }
    else if (m_crits.find("left") == m_crits.end() && m_crits.find("right") == m_crits.end()) {
        std::uniform_int_distribution dist{ 0,1 };
        if (dist(rnd) == 0) {
            m_crits.insert_or_assign("left", m_crits.find("center")->second);
            m_crits.insert_or_assign("center", std::make_pair(1, newCrit));

            m_crits.find("left")->second.second.push(-m_pushWidth, 0);
        }
        else {
            m_crits.insert_or_assign("right", m_crits.find("center")->second);
            m_crits.insert_or_assign("center", std::make_pair(1, newCrit));

            m_crits.find("right")->second.second.push(m_pushWidth, 0);
        }
    }
    else if (m_crits.find("left") == m_crits.end()) {
        m_crits.insert_or_assign("left", m_crits.find("center")->second);
        m_crits.insert_or_assign("center", std::make_pair(1, newCrit));

        m_crits.find("left")->second.second.push(-m_pushWidth, 0);
    }
    else if (m_crits.find("right") == m_crits.end()) {
        m_crits.insert_or_assign("right", m_crits.find("center")->second);
        m_crits.insert_or_assign("center", std::make_pair(1, newCrit));

        m_crits.find("right")->second.second.push(m_pushWidth, 0);
    }
    else if (m_crits.find("leftTop") == m_crits.end() && m_crits.find("rightTop") == m_crits.end()) {
        std::uniform_int_distribution dist{ 0,1 };
        if (dist(rnd) == 0) {
            m_crits.insert_or_assign("leftTop", m_crits.find("center")->second);
            m_crits.insert_or_assign("center", std::make_pair(1, newCrit));

            m_crits.find("leftTop")->second.second.push(-m_pushWidth, -m_pushHeight);
        }
        else {
            m_crits.insert_or_assign("rightTop", m_crits.find("center")->second);
            m_crits.insert_or_assign("center", std::make_pair(1, newCrit));

            m_crits.find("rightTop")->second.second.push(m_pushWidth, -m_pushHeight);
        }
    }
    else if (m_crits.find("leftTop") == m_crits.end()) {
        m_crits.insert_or_assign("leftTop", m_crits.find("center")->second);
        m_crits.insert_or_assign("center", std::make_pair(1, newCrit));

        m_crits.find("leftTop")->second.second.push(-m_pushWidth, -m_pushHeight);
    }
    else if (m_crits.find("rightTop") == m_crits.end()) {
        m_crits.insert_or_assign("rightTop", m_crits.find("center")->second);
        m_crits.insert_or_assign("center", std::make_pair(1, newCrit));

        m_crits.find("rightTop")->second.second.push(m_pushWidth, -m_pushHeight);
    }
    else if (m_crits.find("leftBottom") == m_crits.end() && m_crits.find("rightBottom") == m_crits.end()) {
        std::uniform_int_distribution dist{ 0,1 };
        if (dist(rnd) == 0) {
            m_crits.insert_or_assign("leftBottom", m_crits.find("center")->second);
            m_crits.insert_or_assign("center", std::make_pair(1, newCrit));

            m_crits.find("leftBottom")->second.second.push(-m_pushWidth, m_pushHeight);
        }
        else {
            m_crits.insert_or_assign("rightBottom", m_crits.find("center")->second);
            m_crits.insert_or_assign("center", std::make_pair(1, newCrit));

            m_crits.find("rightBottom")->second.second.push(m_pushWidth, m_pushHeight);
        }
    }
    else if (m_crits.find("leftBottom") == m_crits.end()) {
        m_crits.insert_or_assign("leftBottom", m_crits.find("center")->second);
        m_crits.insert_or_assign("center", std::make_pair(1, newCrit));

        m_crits.find("leftBottom")->second.second.push(-m_pushWidth, m_pushHeight);
    }
    else if (m_crits.find("rightBottom") == m_crits.end()) {
        m_crits.insert_or_assign("rightBottom", m_crits.find("center")->second);
        m_crits.insert_or_assign("center", std::make_pair(1, newCrit));

        m_crits.find("rightBottom")->second.second.push(m_pushWidth, m_pushHeight);
    }
    else {
        m_crits.insert_or_assign("center", std::make_pair(1, newCrit));
    }
}
