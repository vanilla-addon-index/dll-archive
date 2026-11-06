--[[
  OctoBus settings window: /ob options, or right-click the minimap icon.
  Changes apply at once and are saved with the rest of OctoBus's settings.
]]

local font = STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
local W = 300
local frame, controls = nil, {}
local loading = false

local function Backdrop(f)
  f:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8X8",
    edgeFile = "Interface\\Buttons\\WHITE8X8",
    tile = false, tileSize = 0, edgeSize = 1,
    insets = { left = 1, right = 1, top = 1, bottom = 1 },
  })
  f:SetBackdropColor(0.02, 0.02, 0.02, 0.92)
  f:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)
end

local function Heading(text, y)
  local fs = frame:CreateFontString(nil, "OVERLAY")
  fs:SetFont(font, 11, "OUTLINE")
  fs:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, y)
  fs:SetText("|cff33ffcc" .. text .. "|r")
end

local sliderCount = 0
-- get() returns the setting's current value; set(v) applies it; fmt(v) is the label text
local function Slider(label, y, lo, hi, step, get, set, fmt)
  sliderCount = sliderCount + 1
  local name = "OctoBusOptionsSlider" .. sliderCount
  local s = CreateFrame("Slider", name, frame, "OptionsSliderTemplate")
  s:SetPoint("TOPLEFT", frame, "TOPLEFT", 18, y)
  s:SetWidth(W - 36)
  s:SetMinMaxValues(lo, hi)
  s:SetValueStep(step)
  getglobal(name .. "Low"):SetText("")
  getglobal(name .. "High"):SetText("")
  local text = getglobal(name .. "Text")
  text:SetFont(font, 10)
  s.Update = function()
    loading = true
    s:SetValue(get())
    loading = false
    text:SetText(label .. ": |cffffffff" .. fmt(get()) .. "|r")
  end
  s:SetScript("OnValueChanged", function()
    if loading then return end
    local v = math.floor(this:GetValue() / step + 0.5) * step
    set(v)
    text:SetText(label .. ": |cffffffff" .. fmt(v) .. "|r")
  end)
  table.insert(controls, s)
  return s
end

local checkCount = 0
local function Check(label, x, y, get, set)
  checkCount = checkCount + 1
  local name = "OctoBusOptionsCheck" .. checkCount
  local c = CreateFrame("CheckButton", name, frame, "OptionsCheckButtonTemplate")
  c:SetWidth(24)
  c:SetHeight(24)
  c:SetPoint("TOPLEFT", frame, "TOPLEFT", x, y)
  local text = getglobal(name .. "Text")
  text:SetFont(font, 10)
  text:SetText(label)
  -- the template makes the box clickable 100 px to its right, which reaches over the
  -- next box on the same line: limit the click area to the box and its own label
  c:SetHitRectInsets(0, -((text:GetStringWidth() or 0) + 6), 0, 0)
  c.Update = function() c:SetChecked(get() and 1 or nil) end
  c:SetScript("OnClick", function() set(this:GetChecked() and true or false) end)
  table.insert(controls, c)
  return c
end

local function pct(v) return math.floor(v * 100 + 0.5) .. "%" end

local function Build()
  local OB = OctoBus
  local C = OB.cfg
  frame = CreateFrame("Frame", "OctoBusOptions", UIParent)
  frame:SetWidth(W)
  frame:SetHeight(700)
  frame:SetPoint("CENTER", UIParent, "CENTER", 0, 60)
  frame:SetFrameStrata("DIALOG")
  frame:SetClampedToScreen(true)
  frame:SetMovable(true)
  frame:EnableMouse(true)
  frame:RegisterForDrag("LeftButton")
  frame:SetScript("OnDragStart", function() this:StartMoving() end)
  frame:SetScript("OnDragStop", function() this:StopMovingOrSizing() end)
  Backdrop(frame)
  table.insert(UISpecialFrames, "OctoBusOptions")   -- Escape closes it

  local title = frame:CreateFontString(nil, "OVERLAY")
  title:SetFont(font, 12, "OUTLINE")
  title:SetPoint("TOP", frame, "TOP", 0, -10)
  title:SetText("|cff33ffccOcto|rBus settings")

  local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
  close:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 2, 2)
  close:SetFrameLevel(frame:GetFrameLevel() + 5)
  close:SetScript("OnClick", function() frame:Hide() end)

  local function look(key) return function(v) C[key] = v OB.ApplyLook() end end

  Heading("Window", -34)
  Slider("Background opacity", -64, 0, 1, 0.05, function() return C.bgAlpha or 0.75 end, look("bgAlpha"), pct)
  Slider("Window opacity (all but text)", -102, 0.2, 1, 0.05, function() return C.alpha or 1 end, look("alpha"), pct)
  Slider("Text size", -140, 0.7, 1.5, 0.05, function() return C.textScale or 1 end, look("textScale"), pct)
  Slider("Text opacity", -178, 0, 1, 0.05, function() return C.textAlpha or 1 end, look("textAlpha"), pct)
  Slider("Gap between names and times", -216, 0.6, 1.6, 0.05, function() return C.widthScale or 1 end, look("widthScale"), pct)
  Slider("Place colour vibrance", -254, 0.2, 1, 0.05, function() return C.vibrance or 0.75 end, look("vibrance"), pct)
  local outl = frame:CreateFontString(nil, "OVERLAY")
  outl:SetFont(font, 10)
  outl:SetPoint("TOPLEFT", frame, "TOPLEFT", 18, -284)
  outl:SetText("Text outline:")
  outl:SetTextColor(1, 0.82, 0)
  local OUTLINES = { { "thin", "Thin", 96 }, { "thick", "Thick", 156 }, { "shadow", "Shadow", 222 } }
  for i = 1, table.getn(OUTLINES) do
    local key = OUTLINES[i][1]
    Check(OUTLINES[i][2], OUTLINES[i][3], -278, function() return (C.outline or "thin") == key end,
      function()
        C.outline = key
        OB.ApplyLook()
        for j = 1, table.getn(controls) do controls[j].Update() end
      end)
  end
  Slider("Window size", -316, OB.scaleMin, OB.scaleMax, 0.05, function() return C.scale or 1 end,
    function(v) OB.SetScale(v) end, pct)
  Check("Lock position and size", 14, -342, function() return C.locked end, function(v) OB.SetLocked(v) end)

  -- which corner stays in place when the list gets longer or shorter
  local corner = frame:CreateFontString(nil, "OVERLAY")
  corner:SetFont(font, 10)
  corner:SetPoint("TOPLEFT", frame, "TOPLEFT", 18, -372)
  corner:SetText("Corner that stays put as the list grows or shrinks:")
  corner:SetTextColor(1, 0.82, 0)
  local CORNERS = {
    { "TOPLEFT", "Top left", 14, -386 }, { "TOPRIGHT", "Top right", 150, -386 },
    { "BOTTOMLEFT", "Bottom left", 14, -410 }, { "BOTTOMRIGHT", "Bottom right", 150, -410 },
  }
  for i = 1, table.getn(CORNERS) do
    local a = CORNERS[i][1]
    Check(CORNERS[i][2], CORNERS[i][3], CORNERS[i][4], function() return (C.anchor or "BOTTOMLEFT") == a end,
      function()
        OB.SetAnchor(a)
        for j = 1, table.getn(controls) do controls[j].Update() end   -- one corner at a time
      end)
  end

  Heading("Routes", -440)
  Check("Open by itself only at route ends", 14, -458, function() return C.zoneOnly end,
    function(v) C.zoneOnly = v end)
  Check("Show all routes (not just for where you are)", 14, -482, function() return C.full end,
    function(v) C.full = v OB.Refresh() end)
  Check("Show the Sparkwater Port boat", 14, -506, function() return not C.hideBoat end,
    function(v) C.hideBoat = not v OB.Refresh() end)
  Check("Share timers with other OctoBus users", 14, -530, function() return C.share end,
    function(v)
      C.share = v
      if v then JoinChannelByName("OctoBusSync") else LeaveChannelByName("OctoBusSync") end
    end)

  Heading("Alerts (click a row to put a bell on it)", -562)
  Slider("Warn before arrival", -592, 10, 120, 5, function() return C.alert or 45 end,
    function(v) C.alert = v end, function(v) return math.floor(v + 0.5) .. " s" end)
  Check("Chat message", 14, -614, function() return C.chat end, function(v) C.chat = v end)
  Check("Sound", 120, -614, function() return C.sound end, function(v) C.sound = v end)
  Check("Flash the minimap icon", 14, -638, function() return C.flash end, function(v) C.flash = v end)

  local reset = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
  reset:SetWidth(150)
  reset:SetHeight(20)
  reset:SetPoint("BOTTOM", frame, "BOTTOM", 0, 12)
  reset:SetText("Reset window look")
  reset:SetScript("OnClick", function()
    C.bgAlpha, C.alpha, C.textScale, C.textAlpha, C.widthScale, C.vibrance, C.outline = nil, nil, nil, nil, nil, nil, nil
    OB.SetScale(1)
    OB.ApplyLook()
    for i = 1, table.getn(controls) do controls[i].Update() end
  end)
end

function OctoBus_Options()
  if not OctoBus then
    DEFAULT_CHAT_FRAME:AddMessage("|cff33ffccOctoBus:|r not running, so its settings are unavailable.")
    return
  end
  if not frame then
    Build()
    frame:Hide()   -- a new frame starts out shown; without this the first click hid it
  end
  if frame:IsShown() then frame:Hide() return end
  for i = 1, table.getn(controls) do controls[i].Update() end
  OctoBus.Show()   -- show the timer window so changes can be seen
  frame:Show()
end
