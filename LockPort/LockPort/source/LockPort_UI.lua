--[[
	LockPort UI - built from the stock 1.12 Blizzard art so it looks like part of the game:
	dialog border + header plate, gold GameFont text, class icons from the character
	creation sheet, UIPanelButtons, UICheckButtons and an InputBox.
]]

local LP = LockPort

local MAX_ROWS   = 10
local ROW_HEIGHT = 18
local FRAME_W    = 230
local INNER_W    = FRAME_W - 36

local CLASS_ICONS = "Interface\\Glues\\CharacterCreate\\UI-CharacterCreate-Classes"
local CLASS_COORDS = {
	WARRIOR = { 0, 0.25, 0, 0.25 },          MAGE    = { 0.25, 0.49609375, 0, 0.25 },
	ROGUE   = { 0.49609375, 0.7421875, 0, 0.25 }, DRUID = { 0.7421875, 0.98828125, 0, 0.25 },
	HUNTER  = { 0, 0.25, 0.25, 0.5 },        SHAMAN  = { 0.25, 0.49609375, 0.25, 0.5 },
	PRIEST  = { 0.49609375, 0.7421875, 0.25, 0.5 }, WARLOCK = { 0.7421875, 0.98828125, 0.25, 0.5 },
	PALADIN = { 0, 0.25, 0.5, 0.75 },
}

local DIALOG_BACKDROP = {
	bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
	edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
	tile = true, tileSize = 32, edgeSize = 32,
	insets = { left = 11, right = 12, top = 12, bottom = 11 },
}

---------------------------------------------------------------------------
-- Window styles: "classic" (Blizzard dialog art) or "pfui" (flat, dark, like
-- the original LockPort; uses pfUI's own skinning + font when pfUI is loaded).
-- Picked once when the UI is built, so switching needs a /reload.
---------------------------------------------------------------------------
local FLAT  = false
local PF    = nil
local FONT  = "Fonts\\ARIALN.TTF"
local WHITE = "Interface\\Buttons\\WHITE8X8"
local OLD_TITLE = "|cffb700b7L|cffff00ffo|cffff50ffc|cffff99ffk|cffffc4ffP|cffffffffort|r"
local FLAT_BACKDROP = {
	bgFile = WHITE, edgeFile = WHITE, tile = false, tileSize = 0, edgeSize = 1,
	insets = { left = 0, right = 0, top = 0, bottom = 0 },
}

local function SetupTheme()
	FLAT = (LockPortOptions.theme == "pfui")
	PF = pfUI and pfUI.api
	if FLAT and pfUI and type(pfUI.font_default) == "string" then FONT = pfUI.font_default end
end

local function Font(fs, size)
	if FLAT and fs then fs:SetFont(FONT, size) end
end

local function FlatBackdrop(f, alpha)
	f:SetBackdrop(FLAT_BACKDROP)
	f:SetBackdropColor(0, 0, 0, alpha or 0.75)
	f:SetBackdropBorderColor(0.2, 0.2, 0.2, 1)
end

-- divider / accent colour per style
local function AccentLine(tex)
	if FLAT then tex:SetTexture(1, 1, 1, 0.12) else tex:SetTexture(1, 0.82, 0, 0.25) end
end

local function SkinButton(b)
	if not FLAT then return end
	if PF and PF.SkinButton and pcall(PF.SkinButton, b) then return end
	b:SetNormalTexture("")
	b:SetPushedTexture("")
	b:SetHighlightTexture("")
	b:SetDisabledTexture("")
	FlatBackdrop(b, 0.6)
	local hl = b:CreateTexture(nil, "HIGHLIGHT")
	hl:SetTexture(1, 1, 1, 0.12)
	hl:SetPoint("TOPLEFT", b, "TOPLEFT", 1, -1)
	hl:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -1, 1)
end

local function SkinCheck(cb)
	if not FLAT then return end
	if PF and PF.SkinCheckbox then pcall(PF.SkinCheckbox, cb) end
end

local function SkinInput(eb)
	if not FLAT then return end
	local n = eb:GetName()
	for _, part in ipairs({ "Left", "Middle", "Right" }) do
		local t = getglobal(n .. part)
		if t then t:Hide() end
	end
	FlatBackdrop(eb, 0.5)
	if eb.SetTextInsets then eb:SetTextInsets(4, 4, 0, 0) end
	Font(eb, 11)
end

StaticPopupDialogs["LOCKPORT_RELOAD"] = {
	text = "LockPort: reload the UI now to apply the new window style?",
	button1 = "Reload",
	button2 = "Later",
	OnAccept = function() ReloadUI() end,
	timeout = 0, whileDead = 1, hideOnEscape = 1,
}

function LP:ToggleTheme()
	LockPortOptions.theme = (LockPortOptions.theme == "pfui") and "classic" or "pfui"
	self:Print("window style: " .. (LockPortOptions.theme == "pfui" and "pfUI" or "Classic") .. " - /reload to apply.")
	if self.RefreshOptionsUI then self:RefreshOptionsUI() end
	StaticPopup_Show("LOCKPORT_RELOAD")
end

local function ClassColor(class)
	local c = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
	if c then return c.r, c.g, c.b end
	return 1, 0.82, 0
end

local function MakeDialog(name, width, height, title)
	local f = CreateFrame("Frame", name, UIParent)
	f:SetWidth(width)
	f:SetHeight(height)
	f:SetFrameStrata("MEDIUM")
	if f.SetToplevel then f:SetToplevel(true) end
	if FLAT then FlatBackdrop(f, 0.8) else f:SetBackdrop(DIALOG_BACKDROP) end
	f:SetMovable(true)
	f:EnableMouse(true)
	if f.SetClampedToScreen then f:SetClampedToScreen(true) end
	f:RegisterForDrag("LeftButton")
	f:Hide()

	if FLAT then
		-- old-LockPort title bar: dark strip, gradient name
		local bar = f:CreateTexture(name .. "TitleBar", "BACKGROUND")
		bar:SetTexture(1, 1, 1, 0.06)
		bar:SetPoint("TOPLEFT", f, "TOPLEFT", 1, -1)
		bar:SetPoint("TOPRIGHT", f, "TOPRIGHT", -1, -1)
		bar:SetHeight(20)
		local text = f:CreateFontString(name .. "Title", "OVERLAY", "GameFontNormal")
		text:SetPoint("TOP", f, "TOP", 0, -5)
		Font(text, 14)
		local _, _, rest = string.find(title, "^LockPort%s*(.*)$")
		text:SetText(OLD_TITLE .. ((rest and rest ~= "") and (" |cffffffff" .. rest .. "|r") or ""))
		f.title = text

		local close = CreateFrame("Button", name .. "CloseButton", f, "UIPanelCloseButton")
		if not (PF and PF.SkinCloseButton and pcall(PF.SkinCloseButton, close, f, -3, -3)) then
			close:SetWidth(24)
			close:SetHeight(24)
			close:SetPoint("TOPRIGHT", f, "TOPRIGHT", 2, 2)
		end
		return f
	end

	local header = f:CreateTexture(name .. "Header", "ARTWORK")
	header:SetTexture("Interface\\DialogFrame\\UI-DialogBox-Header")
	header:SetWidth(width > 280 and 300 or 230)
	header:SetHeight(64)
	header:SetPoint("TOP", f, "TOP", 0, 12)

	local text = f:CreateFontString(name .. "Title", "OVERLAY", "GameFontNormal")
	text:SetPoint("TOP", header, "TOP", 0, -14)
	text:SetText(title)
	f.title = text

	local close = CreateFrame("Button", name .. "CloseButton", f, "UIPanelCloseButton")
	close:SetPoint("TOPRIGHT", f, "TOPRIGHT", -5, -5)
	return f
end

---------------------------------------------------------------------------
-- Request window
---------------------------------------------------------------------------
local function Row_OnEnter()
	local e = this.entry
	if not e then return end
	local info = e.info
	GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
	GameTooltip:AddLine(e.name, ClassColor(info.class))
	local line = info.classLocal or ""
	if info.zone and info.zone ~= "" then line = line .. "  -  " .. info.zone end
	if line ~= "" then GameTooltip:AddLine(line, 1, 1, 1) end
	local status, r, g, b = LP:RequestStatus(e)
	if status ~= "" then GameTooltip:AddLine(status, r, g, b) end
	local waited = math.floor((GetTime() - e.t) / 60)
	GameTooltip:AddLine("Waiting " .. (waited < 1 and "under a minute" or (waited .. " min")), 0.6, 0.6, 0.6)
	GameTooltip:AddLine(" ")
	GameTooltip:AddLine("Left-click: summon", 0.2, 1, 0.2)
	GameTooltip:AddLine("Ctrl+click: target", 0.8, 0.8, 0.8)
	GameTooltip:AddLine("Right-click: remove", 1, 0.3, 0.3)
	GameTooltip:Show()
end

local function Row_OnClick()
	local e = this.entry
	if not e then return end
	if arg1 == "RightButton" then
		LP:RemoveRequest(e.name, true)
	elseif IsControlKeyDown() then
		TargetUnit(e.info.unit)
	else
		LP:Summon(e.name)
	end
	GameTooltip:Hide()
end

local function CreateRow(parent, i)
	local row = CreateFrame("Button", "LockPortRow" .. i, parent)
	row:SetWidth(INNER_W)
	row:SetHeight(ROW_HEIGHT)
	row:SetPoint("TOPLEFT", parent, "TOPLEFT", 18, -46 - (i - 1) * ROW_HEIGHT)
	row:RegisterForClicks("LeftButtonUp", "RightButtonUp")

	if math.mod(i, 2) == 0 then
		local stripe = row:CreateTexture(nil, "BACKGROUND")
		stripe:SetAllPoints(row)
		stripe:SetTexture(1, 1, 1, 0.05)
	end

	local hl = row:CreateTexture(nil, "HIGHLIGHT")
	if FLAT then
		hl:SetTexture(1, 1, 1, 0.1)
	else
		hl:SetTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
		hl:SetBlendMode("ADD")
	end
	hl:SetAllPoints(row)

	local icon = row:CreateTexture(nil, "ARTWORK")
	icon:SetTexture(CLASS_ICONS)
	icon:SetWidth(14)
	icon:SetHeight(14)
	icon:SetPoint("LEFT", row, "LEFT", 3, 0)
	row.icon = icon

	local name = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	name:SetPoint("LEFT", icon, "RIGHT", 5, 0)
	name:SetWidth(92)
	name:SetHeight(ROW_HEIGHT)
	name:SetJustifyH("LEFT")
	Font(name, 12)
	row.name = name

	local status = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	status:SetPoint("RIGHT", row, "RIGHT", -3, 0)
	status:SetWidth(INNER_W - 118)
	status:SetHeight(ROW_HEIGHT)
	status:SetJustifyH("RIGHT")
	Font(status, 10)
	row.status = status

	row:SetScript("OnClick", Row_OnClick)
	row:SetScript("OnEnter", Row_OnEnter)
	row:SetScript("OnLeave", function() GameTooltip:Hide() end)
	row:Hide()
	return row
end

local function SavePosition(f)
	local point, _, relPoint, x, y = f:GetPoint()
	LockPortOptions.pos = { point = point, relPoint = relPoint, x = x, y = y }
end

local function RestorePosition(f)
	f:ClearAllPoints()
	local p = LockPortOptions.pos
	if p and p.point then
		f:SetPoint(p.point, UIParent, p.relPoint or p.point, p.x or 0, p.y or 0)
	else
		f:SetPoint("CENTER", UIParent, "CENTER", 0, 120)
	end
end

local function CreateGroupsFrame()
	local f = MakeDialog("LockPortGroupsFrame", 230, 336, "Raid Groups")
	f:SetParent(LockPortFrame)
	f:SetPoint("TOPLEFT", LockPortFrame, "TOPRIGHT", 6, 0)
	local tip = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	tip:SetPoint("TOPLEFT", f, "TOPLEFT", 18, -30)
	tip:SetWidth(194); tip:SetHeight(24)
	tip:SetText("Select your raid groups, then queue their players for summoning.")
	f.groups = {}
	for i = 1, 8 do
		local group = i
		local cb = CreateFrame("CheckButton", "LockPortGroupCheck" .. i, f, "UICheckButtonTemplate")
		cb:SetWidth(24); cb:SetHeight(24)
		cb:SetPoint("TOPLEFT", f, "TOPLEFT", 18, -56 - (i - 1) * 22)
		local label = cb:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		label:SetPoint("LEFT", cb, "RIGHT", 2, 0)
		cb.label = label
		cb:SetScript("OnClick", function() LP:ToggleSummonGroup(group) end)
		SkinCheck(cb)
		f.groups[i] = cb
	end
	local all = CreateFrame("Button", "LockPortGroupsAll", f, "UIPanelButtonTemplate")
	all:SetWidth(95); all:SetHeight(22)
	all:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 16, 46)
	all:SetText("All groups")
	all:SetScript("OnClick", function() LP:SetSummonGroups(nil) end)
	SkinButton(all)
	local none = CreateFrame("Button", "LockPortGroupsNone", f, "UIPanelButtonTemplate")
	none:SetWidth(95); none:SetHeight(22)
	none:SetPoint("LEFT", all, "RIGHT", 2, 0)
	none:SetText("None")
	none:SetScript("OnClick", function() LP:SetSummonGroups({}) end)
	SkinButton(none)
	local queue = CreateFrame("Button", "LockPortQueueGroups", f, "UIPanelButtonTemplate")
	queue:SetWidth(192); queue:SetHeight(22)
	queue:SetPoint("TOPLEFT", all, "BOTTOMLEFT", 0, -2)
	queue:SetText("Queue selected groups")
	queue:SetScript("OnClick", function() LP:QueueSelectedGroups() end)
	SkinButton(queue)
	f:SetScript("OnShow", function() LP:RefreshGroupsUI() end)
	return f
end

function LP:RefreshGroupsUI()
	local f = LockPortGroupsFrame
	if not f then return end
	if GetNumRaidMembers() == 0 then f:Hide(); return end
	local counts = {}
	for _, info in pairs(self:ScanRoster()) do
		if info.subgroup then counts[info.subgroup] = (counts[info.subgroup] or 0) + 1 end
	end
	local groups = LockPortOptions.summonGroups
	for i = 1, 8 do
		f.groups[i]:SetChecked((type(groups) ~= "table" or groups[i]) and 1 or nil)
		f.groups[i].label:SetText("Group " .. i .. " (" .. (counts[i] or 0) .. " players)")
	end
end

function LP:ToggleGroups()
	if GetNumRaidMembers() == 0 then return self:Print("Group summoning is available in raids.") end
	local f = LockPortGroupsFrame
	if not f then return end
	if f:IsVisible() then f:Hide() else f:Show(); self:RefreshGroupsUI() end
end

local function CreateMainFrame()
	-- fixed height for 10 rows, like the original LockPort
	local f = MakeDialog("LockPortFrame", FRAME_W, 46 + MAX_ROWS * ROW_HEIGHT + 104, "LockPort")
	f:SetScript("OnDragStart", function() if not LockPortOptions.locked then this:StartMoving() end end)
	f:SetScript("OnDragStop", function() this:StopMovingOrSizing(); SavePosition(this) end)
	f:SetScript("OnShow", function() PlaySound("igMainMenuOpen"); LP:RefreshList() end)
	f:SetScript("OnHide", function() PlaySound("igMainMenuClose") end)
	f:SetScript("OnUpdate", function()
		this.elapsed = (this.elapsed or 0) + arg1
		if this.elapsed > 0.5 then this.elapsed = 0; LP:RefreshList() end
	end)

	local sub = f:CreateFontString("LockPortFrameSubtitle", "OVERLAY", "GameFontNormalSmall")
	sub:SetPoint("TOPLEFT", f, "TOPLEFT", 20, -28)
	sub:SetText("Summon requests")
	sub:SetWidth(INNER_W - 4)
	sub:SetHeight(12)
	sub:SetJustifyH("LEFT")
	Font(sub, 11)
	f.subtitle = sub

	local count = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	count:SetPoint("TOPRIGHT", f, "TOPRIGHT", -20, -28)
	f.count = count

	local div = f:CreateTexture(nil, "ARTWORK")
	AccentLine(div)
	div:SetHeight(1)
	div:SetPoint("TOPLEFT", f, "TOPLEFT", 18, -42)
	div:SetPoint("TOPRIGHT", f, "TOPRIGHT", -18, -42)

	f.rows = {}
	for i = 1, MAX_ROWS do f.rows[i] = CreateRow(f, i) end

	local empty = f:CreateFontString(nil, "OVERLAY", "GameFontDisable")
	empty:SetPoint("TOP", f, "TOP", 0, -52)
	empty:SetText("No one needs a summon.")
	Font(empty, 12)
	f.empty = empty

	local more = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	more:SetPoint("TOPRIGHT", f.rows[MAX_ROWS], "BOTTOMRIGHT", -3, -1)
	f.more = more

	-- footer: shards + helpers
	local footer = CreateFrame("Frame", nil, f)
	footer:SetWidth(INNER_W)
	footer:SetHeight(20)
	footer:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 18, 66)
	f.footer = footer

	local fdiv = footer:CreateTexture(nil, "ARTWORK")
	AccentLine(fdiv)
	fdiv:SetHeight(1)
	fdiv:SetPoint("TOPLEFT", footer, "TOPLEFT", 0, 2)
	fdiv:SetPoint("TOPRIGHT", footer, "TOPRIGHT", 0, 2)

	local shardIcon = footer:CreateTexture(nil, "ARTWORK")
	shardIcon:SetTexture("Interface\\Icons\\INV_Misc_Gem_Amethyst_02")
	shardIcon:SetWidth(16)
	shardIcon:SetHeight(16)
	shardIcon:SetPoint("LEFT", footer, "LEFT", 2, -3)

	local shards = footer:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	shards:SetPoint("LEFT", shardIcon, "RIGHT", 4, 0)
	Font(shards, 10)
	f.shards = shards

	local helpers = footer:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	helpers:SetPoint("RIGHT", footer, "RIGHT", -2, -3)
	Font(helpers, 10)
	f.helpers = helpers

	-- buttons
	local summon = CreateFrame("Button", "LockPortSummonButton", f, "UIPanelButtonTemplate")
	summon:SetWidth(95)
	summon:SetHeight(22)
	summon:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 16, 40)
	summon:SetText("Summon")
	summon:SetScript("OnClick", function() LP:SummonNext() end)
	summon:SetScript("OnEnter", function()
		GameTooltip:SetOwner(this, "ANCHOR_TOP")
		GameTooltip:AddLine("Summon next in line")
		if LP.readyText then GameTooltip:AddLine(LP.readyText, 1, 0.82, 0) end
		GameTooltip:AddLine("Skips anyone offline, dead, in combat, inside an instance, being summoned by another warlock, or who failed 3 times in a row.", 1, 1, 1, 1)
		local key = GetBindingKey("LOCKPORT_SUMMON_NEXT")
		if key then GameTooltip:AddLine("Hotkey: " .. key, 0.6, 0.6, 0.6) end
		GameTooltip:Show()
	end)
	summon:SetScript("OnLeave", function() GameTooltip:Hide() end)
	f.summon = summon

	local chat = CreateFrame("Button", "LockPortChatToggle", f, "UIPanelButtonTemplate")
	chat:SetWidth(95)
	chat:SetHeight(22)
	chat:SetPoint("LEFT", summon, "RIGHT", 2, 0)
	chat:SetText("Chat: On")
	chat:SetScript("OnClick", function() LP:SetChatMuted(not LockPortOptions.chatMuted) end)
	chat:SetScript("OnEnter", function()
		GameTooltip:SetOwner(this, "ANCHOR_TOP")
		GameTooltip:AddLine("Outgoing chat")
		GameTooltip:AddLine("Turn off while travelling to mute all LockPort announcements and whispers. Requests and summoning still work. This setting is saved across reloads.", 1, 1, 1, 1)
		GameTooltip:Show()
	end)
	chat:SetScript("OnLeave", function() GameTooltip:Hide() end)
	SkinButton(chat)
	f.chatToggle = chat

	local add = CreateFrame("Button", "LockPortAddButton", f, "UIPanelButtonTemplate")
	add:SetWidth(95)
	add:SetHeight(22)
	add:SetPoint("TOPLEFT", summon, "BOTTOMLEFT", 0, -2)
	add:SetText("Add Target")
	add:SetScript("OnClick", function() LP:Slash("add") end)

	local opts = CreateFrame("Button", "LockPortOptionsButton", f, "UIPanelButtonTemplate")
	opts:SetWidth(95)
	opts:SetHeight(22)
	opts:SetPoint("LEFT", add, "RIGHT", 2, 0)
	opts:SetText("Options")
	opts:SetScript("OnClick", function() LP:ToggleOptions() end)

	-- Hidden entirely when the companion client DLL is absent.
	local auto = CreateFrame("Button", "LockPortRaidAutoSummon", f, "UIPanelButtonTemplate")
	auto:SetWidth(95)
	auto:SetHeight(22)
	auto:SetPoint("TOPLEFT", add, "BOTTOMLEFT", 0, -2)
	auto:SetText("Auto: Off")
	auto:SetScript("OnClick", function()
		LP:SetRaidAutoSummon(not LP.raidAutoSummon)
		LP:RefreshList()
	end)
	auto:SetScript("OnEnter", function()
		GameTooltip:SetOwner(this, "ANCHOR_TOP")
		GameTooltip:AddLine("Auto Summon")
		GameTooltip:AddLine("Automatically summons queued party or raid members when two helpers are nearby. Enables summons-available announcements. Turns off when you leave the group or reload.", 1, 1, 1, 1)
		GameTooltip:Show()
	end)
	auto:SetScript("OnLeave", function() GameTooltip:Hide() end)
	auto:Hide()
	SkinButton(auto)
	f.raidAuto = auto

	local groups = CreateFrame("Button", "LockPortGroupsButton", f, "UIPanelButtonTemplate")
	groups:SetWidth(95); groups:SetHeight(22)
	groups:SetPoint("LEFT", auto, "RIGHT", 2, 0)
	groups:SetText("Groups: All")
	groups:SetScript("OnClick", function() LP:ToggleGroups() end)
	groups:SetScript("OnEnter", function()
		GameTooltip:SetOwner(this, "ANCHOR_TOP")
		GameTooltip:AddLine("Group summoning")
		if GetNumRaidMembers() == 0 then GameTooltip:AddLine("Join a raid to select groups.", 1, 0.5, 0.1) end
		GameTooltip:AddLine("Selected raid groups: " .. LP:SummonGroupSummary(), 1, 0.82, 0)
		GameTooltip:AddLine("Select your groups and queue their players without a 123 request. Summon and Auto use your selection. Other warlocks should select their own groups.", 1, 1, 1, 1)
		GameTooltip:Show()
	end)
	groups:SetScript("OnLeave", function() GameTooltip:Hide() end)
	SkinButton(groups)
	groups:Hide()
	f.groupSummon = groups

	SkinButton(summon); SkinButton(add); SkinButton(opts)
	RestorePosition(f)
	return f
end

function LP:RefreshList()
	local f = LockPortFrame
	if not f or not LockPortOptions then return end
	if GetNumRaidMembers() == 0 and LockPortGroupsFrame then LockPortGroupsFrame:Hide() end
	if not self:IsWarlock() then f:Hide(); return end
	if not f:IsVisible() then return end

	f.chatToggle:SetText(LockPortOptions.chatMuted and "|cffff4040Chat: Off|r" or "Chat: On")
	local native = self:HasNativeMod()
	local raid = GetNumRaidMembers() > 0
	local extra = 26 -- Keep the Groups control visible even outside raids.
	f:SetHeight(46 + MAX_ROWS * ROW_HEIGHT + 104 + extra)
	f.summon:ClearAllPoints()
	f.summon:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 16, 40 + extra)
	f.footer:ClearAllPoints()
	f.footer:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 18, 66 + extra)
	if native then
		f.raidAuto:Show()
		f.raidAuto:SetText(self.raidAutoSummon and "|cff40ff40Auto: On|r" or "Auto: Off")
		if self:InGroup() then f.raidAuto:Enable() else f.raidAuto:Disable() end
	else
		f.raidAuto:Hide()
	end
	f.groupSummon:Show()
	if raid then
		local summary, count = self:SummonGroupSummary()
		f.groupSummon:SetText(count == 0 and "|cffff4040Groups: 0|r" or ("Groups: " .. (count == 8 and "All" or count)))
		f.groupSummon:Enable()
		self:RefreshGroupsUI()
	else
		f.groupSummon:SetText("Groups")
		f.groupSummon:Disable()
		if LockPortGroupsFrame then LockPortGroupsFrame:Hide() end
	end
	self:ScanRoster()
	local list = self:SortedRequests()
	local n = table.getn(list)
	local shown = n
	if shown > MAX_ROWS then shown = MAX_ROWS end

	for i = 1, MAX_ROWS do
		local row, e = f.rows[i], list[i]
		if e then
			row.entry = e
			local c = CLASS_COORDS[e.info.class or ""]
			if c then
				row.icon:SetTexCoord(c[1], c[2], c[3], c[4])
				row.icon:Show()
			else
				row.icon:Hide()
			end
			row.name:SetText(e.name)
			row.name:SetTextColor(ClassColor(e.info.class))
			local text, r, g, b = self:RequestStatus(e)
			row.status:SetText(text)
			row.status:SetTextColor(r, g, b)
			row:Show()
		else
			row.entry = nil
			row:Hide()
		end
	end

	if n == 0 then f.empty:Show() else f.empty:Hide() end
	if n > MAX_ROWS then f.more:SetText("+" .. (n - MAX_ROWS) .. " more") else f.more:SetText("") end
	f.count:SetText("")

	local shardCount = self:CountShards()
	f.shards:SetText(shardCount .. (shardCount == 1 and " Soul Shard" or " Soul Shards"))
	if shardCount == 0 then f.shards:SetTextColor(1, 0.25, 0.25) else f.shards:SetTextColor(1, 1, 1) end

	local helpers = self:InGroup() and self:CountHelpers(nil) or 0
	f.helpers:SetText("Helpers: " .. helpers .. "/2")
	if helpers >= 2 then f.helpers:SetTextColor(0.25, 1, 0.25) else f.helpers:SetTextColor(1, 0.5, 0.1) end

	if self.pending and not self.pending.done then f.summon:Disable() else f.summon:Enable() end

	-- status line: ready / why not
	local text = self.readyText
	if n > 0 and text then
		if self.isReady then
			f.subtitle:SetTextColor(0.25, 1, 0.25)
		elseif string.find(text, "^Summoning") then
			f.subtitle:SetTextColor(0.58, 0.51, 0.79)
		else
			f.subtitle:SetTextColor(1, 0.5, 0.1)
		end
		f.subtitle:SetText(text .. "  (" .. n .. ")")
	else
		if FLAT then f.subtitle:SetTextColor(0.85, 0.85, 0.85) else f.subtitle:SetTextColor(1, 0.82, 0) end
		f.subtitle:SetText("Summon requests (" .. n .. ")")
	end
	f.summon:SetText(self.isReady and "|cff40ff40Summon|r" or "Summon")
	-- UIPanelButton text/skin hooks can resize buttons; restore both columns
	-- after refreshing labels so each top button matches the one beneath it.
	f.summon:SetWidth(95)
	f.chatToggle:SetWidth(95)
	f.raidAuto:SetWidth(95)
	f.groupSummon:SetWidth(95)

end

---------------------------------------------------------------------------
-- Options window
---------------------------------------------------------------------------
local checks = {}

local function MakeCheck(parent, key, label, tip, x, y)
	local name = "LockPortCheck_" .. key
	local cb = CreateFrame("CheckButton", name, parent, "UICheckButtonTemplate")
	cb:SetWidth(24)
	cb:SetHeight(24)
	cb:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
	local text = getglobal(name .. "Text")
	if not text then
		text = cb:CreateFontString(name .. "Text", "OVERLAY")
		text:SetPoint("LEFT", cb, "RIGHT", 0, 1)
	end
	text:SetFontObject(GameFontHighlightSmall)
	Font(text, 11)
	text:SetText(label)
	cb.label = text
	cb.key = key
	cb.tip = tip
	cb:SetScript("OnClick", function()
		if this.key == "announceOpen" and LP.raidAutoSummon then this:SetChecked(1); return end
		LockPortOptions[this.key] = this:GetChecked() and true or false
		PlaySound(this:GetChecked() and "igMainMenuOptionCheckBoxOn" or "igMainMenuOptionCheckBoxOff")
		LP:RefreshList()
	end)
	cb:SetScript("OnEnter", function()
		GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
		GameTooltip:AddLine(this.label:GetText())
		GameTooltip:AddLine(this.tip, 1, 1, 1, 1)
		GameTooltip:Show()
	end)
	cb:SetScript("OnLeave", function() GameTooltip:Hide() end)
	SkinCheck(cb)
	checks[key] = cb
	return cb
end

local function MakeSection(parent, text, y)
	local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	fs:SetPoint("TOPLEFT", parent, "TOPLEFT", 20, y)
	fs:SetText(text)
	if FLAT then Font(fs, 12); fs:SetTextColor(0.58, 0.51, 0.79) end
	return fs
end

local function MakeInput(parent, name, key, width, x, y)
	local eb = CreateFrame("EditBox", name, parent, "InputBoxTemplate")
	eb:SetWidth(width)
	eb:SetHeight(20)
	eb:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
	eb:SetAutoFocus(false)
	eb:SetMaxLetters(255)
	eb.key = key
	eb:SetScript("OnEditFocusGained", function() this.focused = true end)
	eb:SetScript("OnEditFocusLost", function() this.focused = nil end)
	eb:SetScript("OnEnterPressed", function() this:ClearFocus() end)
	eb:SetScript("OnEscapePressed", function() this:ClearFocus() end)
	eb:SetScript("OnTextChanged", function()
		if LockPortOptions then LockPortOptions[this.key] = this:GetText() end
	end)
	SkinInput(eb)
	return eb
end

local function CreateOptionsFrame()
	local f = MakeDialog("LockPortOptionsFrame", 400, 612, "LockPort Options")
	f:SetFrameStrata("DIALOG")
	f:SetPoint("CENTER", UIParent, "CENTER", 0, 40)
	f:SetScript("OnDragStart", function() this:StartMoving() end)
	f:SetScript("OnDragStop", function() this:StopMovingOrSizing() end)
	f:SetScript("OnShow", function() PlaySound("igCharacterInfoOpen"); LP:RefreshOptionsUI() end)
	f:SetScript("OnHide", function() PlaySound("igCharacterInfoClose") end)
	table.insert(UISpecialFrames, "LockPortOptionsFrame")   -- Esc closes it

	local y = -32
	MakeSection(f, "When summoning", y)
	MakeCheck(f, "whisper", "Whisper the player you're summoning", "Sends \"Summoning you to <zone>\" to the target when the ritual starts.", 20, y - 16)
	MakeCheck(f, "zone", "Include zone in the /say message", "Adds the zone and subzone to the summon announcement.", 20, y - 38)
	MakeCheck(f, "shards", "Include Soul Shard count", "Adds \"[N shards left]\" to the summon announcement.", 20, y - 60)
	MakeCheck(f, "customMessage", "Use a custom /say message:", "Replaces the generated message. {name}, {zone} and {shards} are filled in for you.", 20, y - 82)
	local msg = MakeInput(f, "LockPortMessageBox", "message", 340, 30, y - 106)
	local hint = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	hint:SetPoint("TOPLEFT", msg, "BOTTOMLEFT", -4, -2)
	hint:SetText("Tokens: {name}  {zone}  {shards}")

	y = -170
	MakeSection(f, "Whispers & announcements", y)
	MakeCheck(f, "announceFail", "Tell the party/raid why a summon failed", "e.g. \"[LockPort] Can't summon Bob: Bob is in combat.\"", 20, y - 16)
	MakeCheck(f, "whisperFail", "Whisper the player why it failed", "Lets them know they're still on the list and what to fix.", 20, y - 38)
	MakeCheck(f, "whisperStatus", "Answer repeat 123s with a status whisper", "If someone types 123 while already here, or again while waiting, they're told why: already here, place in line, waiting on helpers, summoning someone else, etc. Only one LockPort warlock replies.", 20, y - 60)
	MakeCheck(f, "announceOpen", "Post \"summons are available\" every", "Posts \"[LockPort] Summons are available - type 123 to get summoned. (N in line)\" on a timer while you're in a group. Skipped while you're in combat; with several LockPort warlocks only one posts each round.", 20, y - 82)
	local every = MakeInput(f, "LockPortAnnounceEveryBox", "announceOpenEvery", 26, 262, y - 84)
	every:ClearAllPoints()
	every:SetPoint("LEFT", checks.announceOpen.label, "RIGHT", 10, 0)
	every:SetMaxLetters(2)
	local everyHint = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	everyHint:SetPoint("LEFT", every, "RIGHT", 6, 0)
	everyHint:SetText("min")
	Font(everyHint, 11)
	MakeCheck(f, "askHelpers", "Ask the raid for helpers when fewer than 2 are near", "Posts e.g. \"[LockPort] Need 1 more person at Blackrock Mountain to help summon - 3 players waiting.\" when someone is waiting (or your portal is up) and fewer than 2 group members are near you. At most every 2 minutes, not in combat, and only one LockPort warlock posts.", 20, y - 104)

	y = -306
	MakeSection(f, "Requests", y)
	MakeCheck(f, "sound", "Play a sound on new requests", "Plays a short sound when someone is added to the list.", 20, y - 16)
	MakeCheck(f, "readySound", "Chime when a summon is ready", "Plays the ready-check sound when the next player can be summoned: you're out of combat with shards and 2 helpers are near you.", 20, y - 38)
	local flash = MakeCheck(f, "flash", "Flash the taskbar when alt-tabbed", "Flashes on new requests and when a summon is ready. Needs the UnitXP SP3 client mod.", 20, y - 60)
	MakeCheck(f, "autoShow", "Open this window on new requests", "Pops the LockPort window up when someone asks for a summon.", 20, y - 82)
	MakeCheck(f, "autoRemove", "Remove players once they arrive", "Takes people off everyone's list when they're already standing near you.", 20, y - 104)
	MakeCheck(f, "locked", "Lock window position", "Stops the summon window from being dragged.", 20, y - 126)

	local trigLabel = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	trigLabel:SetPoint("TOPLEFT", f, "TOPLEFT", 24, y - 158)
	trigLabel:SetText("Request words:")
	Font(trigLabel, 11)
	local trig = MakeInput(f, "LockPortTriggerBox", "triggers", 170, 124, y - 153)
	trig:SetScript("OnEnter", function()
		GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
		GameTooltip:AddLine("Request words")
		GameTooltip:AddLine("Comma separated. A group member starting a message with one of these is added to the list. Default: 123", 1, 1, 1, 1)
		GameTooltip:Show()
	end)
	trig:SetScript("OnLeave", function() GameTooltip:Hide() end)

	-- Summon Next hotkey: click, then press a key (right-click clears)
	local keyLabel = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	keyLabel:SetPoint("TOPLEFT", f, "TOPLEFT", 24, y - 186)
	keyLabel:SetText("Summon Next key:")
	Font(keyLabel, 11)
	local bind = CreateFrame("Button", "LockPortBindButton", f, "UIPanelButtonTemplate")
	bind:SetWidth(120)
	bind:SetHeight(20)
	bind:SetPoint("LEFT", keyLabel, "RIGHT", 10, 0)
	bind:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	bind:SetScript("OnClick", function()
		if arg1 == "RightButton" then
			LP:ClearSummonKey()
		else
			this.waiting = true
			this:EnableKeyboard(true)
			this:SetText("Press a key...")
		end
	end)
	bind:SetScript("OnKeyDown", function() LP:CaptureSummonKey(this, arg1) end)
	bind:SetScript("OnHide", function() LP:StopKeyCapture(this) end)
	bind:SetScript("OnEnter", function()
		GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
		GameTooltip:AddLine("Summon Next hotkey")
		GameTooltip:AddLine("Click, then press the key (Shift/Ctrl/Alt combos work). Esc cancels, right-click clears it. Same as Key Bindings > LockPort.", 1, 1, 1, 1)
		GameTooltip:Show()
	end)
	bind:SetScript("OnLeave", function() GameTooltip:Hide() end)
	SkinButton(bind)
	f.bind = bind

	local styleLabel = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	styleLabel:SetPoint("TOPLEFT", f, "TOPLEFT", 24, y - 212)
	styleLabel:SetText("Window style:")
	Font(styleLabel, 11)
	local style = CreateFrame("Button", "LockPortStyleButton", f, "UIPanelButtonTemplate")
	style:SetWidth(90)
	style:SetHeight(20)
	style:SetPoint("LEFT", styleLabel, "RIGHT", 10, 0)
	style:SetScript("OnClick", function() LP:ToggleTheme() end)
	style:SetScript("OnEnter", function()
		GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
		GameTooltip:AddLine("Window style")
		GameTooltip:AddLine("Classic: Blizzard dialog look.\npfUI: flat dark look like the original LockPort (uses pfUI's skin when pfUI is installed).\nNeeds a /reload.", 1, 1, 1, 1)
		GameTooltip:Show()
	end)
	style:SetScript("OnLeave", function() GameTooltip:Hide() end)
	SkinButton(style)
	f.style = style

	local modsHeader = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	modsHeader:SetPoint("BOTTOM", f, "BOTTOM", 0, 52)
	modsHeader:SetText("Client mods")
	local mods = f:CreateFontString("LockPortModsText", "OVERLAY", "GameFontHighlightSmall")
	mods:SetPoint("TOP", modsHeader, "BOTTOM", 0, -4)
	mods:SetWidth(360)
	mods:SetHeight(32)
	mods:SetJustifyH("CENTER")
	f.mods = mods

	f.flash = flash
	return f
end

function LP:RefreshOptionsUI()
	local O = LockPortOptions
	local f = LockPortOptionsFrame
	if not O or not f then return end
	for key, cb in pairs(checks) do cb:SetChecked(O[key] and 1 or nil) end
	if not LockPortMessageBox.focused then LockPortMessageBox:SetText(O.message or "") end
	if not LockPortAnnounceEveryBox.focused then LockPortAnnounceEveryBox:SetText(O.announceOpenEvery or "3") end
	if not f.bind.waiting then f.bind:SetText(GetBindingKey("LOCKPORT_SUMMON_NEXT") or "Not bound") end
	if not LockPortTriggerBox.focused then LockPortTriggerBox:SetText(O.triggers or "123") end
	if self.mods.unitxp then
		f.flash:Enable()
		f.flash.label:SetTextColor(1, 1, 1)
	else
		f.flash:Disable()
		f.flash.label:SetTextColor(0.5, 0.5, 0.5)
	end
	f.mods:SetText(self:ModStatusText())
	f.style:SetText(O.theme == "pfui" and "pfUI" or "Classic")
end

---------------------------------------------------------------------------
-- Summon Next hotkey (stored as a normal WoW key binding)
---------------------------------------------------------------------------
local MODIFIER_KEYS = { LSHIFT = 1, RSHIFT = 1, LCTRL = 1, RCTRL = 1, LALT = 1, RALT = 1, UNKNOWN = 1 }

local function SaveKeyBindings()
	if GetCurrentBindingSet then SaveBindings(GetCurrentBindingSet()) else SaveBindings(1) end
end

function LP:StopKeyCapture(b)
	b.waiting = false
	b:EnableKeyboard(false)
	self:RefreshOptionsUI()
end

function LP:ClearSummonKey()
	local k1, k2 = GetBindingKey("LOCKPORT_SUMMON_NEXT")
	if k1 then SetBinding(k1) end
	if k2 then SetBinding(k2) end
	SaveKeyBindings()
	self:Print("Summon Next key cleared.")
	self:RefreshOptionsUI()
end

function LP:CaptureSummonKey(b, key)
	if not b.waiting or not key or MODIFIER_KEYS[key] then return end
	if key == "ESCAPE" then return self:StopKeyCapture(b) end
	local combo = (IsAltKeyDown() and "ALT-" or "") .. (IsControlKeyDown() and "CTRL-" or "") ..
	              (IsShiftKeyDown() and "SHIFT-" or "") .. key
	local old = GetBindingAction(combo)
	local k1, k2 = GetBindingKey("LOCKPORT_SUMMON_NEXT")
	if k1 then SetBinding(k1) end
	if k2 then SetBinding(k2) end
	SetBinding(combo, "LOCKPORT_SUMMON_NEXT")
	SaveKeyBindings()
	if old and old ~= "" and old ~= "LOCKPORT_SUMMON_NEXT" then
		self:Print(combo .. " was bound to " .. old .. " - it now summons the next player.")
	else
		self:Print("Summon Next is now on " .. combo .. ".")
	end
	self:StopKeyCapture(b)
end

function LP:CreateUI()
	if LockPortFrame then return end
	SetupTheme()
	CreateMainFrame()
	CreateGroupsFrame()
	CreateOptionsFrame()
end
