--[[
	LockPort - easy warlock summoning for World of Warcraft 1.12 / Turtle WoW 1.18
	Originally written by Gurky, maintained by Phaestas.
	v3: classic UI, failure announcements, optional client-mod support
	    (SuperWoW, Nampower, UnitXP SP3 are all optional).

	Written for the Lua 5.0 runtime of the 1.12 client:
	no '#', no '%' operator, no select(), no string.match.
]]

LockPort = {}
local LP = LockPort

LP.SPELL        = "Ritual of Summoning"
LP.SHARD_ID     = 6265      -- Soul Shard
LP.EVILTWIN_ID  = 23445     -- Evil Twin (Dimensional Ripper / Ultrasafe Transporter)
LP.EVILTWIN_TEX = "spell_shadow_charm"
LP.NEARBY_YARDS = 30

-- Addon message prefixes. RSAdd / RSRemove / lp are kept so v3 still syncs
-- with older LockPort versions in the same raid.
local PREFIX_ADD     = "RSAdd"
local PREFIX_REMOVE  = "RSRemove"
local PREFIX_VERSION = "lp"
local PREFIX_WHISPER = "LPWhisper"   -- "<kind>:<name>" claim so only one warlock replies

local CHAT_TAG = "|cff9482c9LockPort|r: "
local ANNOUNCE_TAG = "[LockPort] "
local REPO_URL = "https://github.com/Phaestas323/LockPort"

LP.requests = {}   -- { {name=, t=}, ... } in request order
LP.roster   = {}
LP.mods     = {}
LP.users    = {}   -- names seen sending LockPort addon messages
LP.claims   = {}   -- "<kind>:<name>" -> time a status whisper went out
LP.whisperQueue = {}

local DEFAULTS = {
	whisper       = true,   -- whisper the target "Summoning you..."
	zone          = true,   -- include zone in the /say message
	shards        = true,   -- include shard count in the /say message
	sound         = true,   -- sound on a new request
	message       = "",     -- custom /say message
	customMessage = false,
	announceFail  = true,   -- tell the party/raid why a summon failed
	whisperFail   = true,   -- whisper the target why their summon failed
	whisperStatus = true,   -- reply to "123" when already here / already on the list
	announceOpen  = false,  -- post "summons are open - type 123" every few minutes
	announceOpenEvery = "3", -- minutes between those posts
	readySound    = true,   -- chime when a summon becomes possible
	askHelpers    = true,   -- ask the raid for portal clickers when fewer than 2 are near
	flash         = true,   -- flash the taskbar on a new request (UnitXP SP3)
	autoRemove    = true,   -- drop people from the list once they're standing next to you
	autoShow      = true,   -- pop the window open on a new request
	locked        = false,  -- lock window position
	theme         = "classic", -- window style: "classic" or "pfui"
	triggers      = "123",  -- comma separated request words
}

-- Failure reasons: what the group sees, and what the summonee is whispered.
local REASONS = {
	offline   = { group = "%s is offline" },
	dead      = { group = "%s is dead",                       whisper = "you're dead. Release or get a res and type 123 again" },
	combat    = { group = "%s is in combat",                  whisper = "you're in combat. Drop combat and I'll try again" },
	eviltwin  = { group = "%s has Evil Twin (must die or walk)", whisper = "you have the Evil Twin debuff. You'll need to die or walk" },
	mecombat  = { group = "I'm in combat",                    whisper = "I'm in combat. You're still on the list" },
	noshards  = { group = "I'm out of Soul Shards",           whisper = "I'm out of Soul Shards" },
	instance  = { group = "%s is inside %s",                  whisper = "you're inside %s - zone out first. You're still on the list" },
	interrupt = { group = "the ritual was interrupted",       whisper = "the ritual was interrupted. You're still on the list" },
	nostart   = { group = "the ritual didn't start",          whisper = "the ritual didn't start. You're still on the list" },
}

---------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------
function LP:Print(msg)
	DEFAULT_CHAT_FRAME:AddMessage(CHAT_TAG .. msg)
end

local function OnOff(v)
	if v then return "|cff40ff40on|r" end
	return "|cffff4040off|r"
end
LP.OnOff = OnOff

local function Trim(s)
	s = string.gsub(s or "", "^%s+", "")
	s = string.gsub(s, "%s+$", "")
	return s
end

local function EscapeRepl(s)
	return (string.gsub(s or "", "%%", "%%%%"))
end

function LP:IsWarlock()
	local _, class = UnitClass("player")
	return class == "WARLOCK"
end

function LP:InGroup()
	return GetNumRaidMembers() > 0 or GetNumPartyMembers() > 0
end

function LP:GroupChannel()
	if GetNumRaidMembers() > 0 then return "RAID" end
	if GetNumPartyMembers() > 0 then return "PARTY" end
	return nil
end

function LP:SendAddon(prefix, msg)
	local chan = self:GroupChannel()
	if chan then SendAddonMessage(prefix, msg, chan) end
end

---------------------------------------------------------------------------
-- Optional client mods
---------------------------------------------------------------------------
function LP:DetectMods()
	local m = self.mods
	-- SuperWoW: GUIDs from UnitExists, UNIT_CASTEVENT, SpellInfo, UnitPosition
	m.superwow = (SUPERWOW_VERSION ~= nil) or (SpellInfo ~= nil and UnitPosition ~= nil)
	-- UnitXP SP3: true yard distances + taskbar flash
	m.unitxp = false
	if UnitXP then
		local ok, d = pcall(UnitXP, "distanceBetween", "player", "player")
		m.unitxp = ok and (d == nil or type(d) == "number")
	end
	-- Nampower: SPELL_FAILED_SELF / SPELL_CAST_EVENT
	m.nampower = (GetNampowerVersion ~= nil) or (QueueSpellByName ~= nil) or (GetSpellIdForName ~= nil)
end

function LP:ModStatusText()
	local function s(label, on) return label .. ": " .. (on and "|cff40ff40yes|r" or "|cff808080no|r") end
	local m = self.mods
	return s("SuperWoW", m.superwow) .. "   " .. s("Nampower", m.nampower) .. "   " ..
	       s("UnitXP SP3", m.unitxp)
end

function LP:PrintMods()
	local m = self.mods
	self:Print("client mods detected:")
	DEFAULT_CHAT_FRAME:AddMessage("  SuperWoW: " .. OnOff(m.superwow) .. "  |cffaaaaaa- exact cast start/fail tracking for the ritual, Evil Twin by spell id, yard distances|r")
	DEFAULT_CHAT_FRAME:AddMessage("  Nampower: " .. OnOff(m.nampower) .. "  |cffaaaaaa- server-confirmed spell failure events|r")
	DEFAULT_CHAT_FRAME:AddMessage("  UnitXP SP3: " .. OnOff(m.unitxp) .. "  |cffaaaaaa- precise distance (\"already here\" check), taskbar flash on new requests|r")
end

function LP:MyGUID()
	if not self.mods.superwow then return nil end
	local _, guid = UnitExists("player")
	return guid
end

-- Is this spell id our ritual? (needs SuperWoW's SpellInfo; otherwise assume yes)
function LP:IsRitualId(id)
	if not id then return true end
	if SpellInfo then
		local name = SpellInfo(id)
		if name then return name == self.SPELL end
	end
	return true
end

---------------------------------------------------------------------------
-- Distance
---------------------------------------------------------------------------
function LP:Distance(unit)
	if self.mods.unitxp then
		local ok, d = pcall(UnitXP, "distanceBetween", "player", unit)
		if ok and type(d) == "number" then return d end
	end
	if self.mods.superwow and UnitPosition then
		local x1, y1, z1 = UnitPosition("player")
		local x2, y2, z2 = UnitPosition(unit)
		if x1 and x2 then
			local dx, dy, dz = x1 - x2, y1 - y2, (z1 or 0) - (z2 or 0)
			return math.sqrt(dx * dx + dy * dy + dz * dz)
		end
	end
	return nil
end

function LP:IsNearby(unit)
	if not UnitIsVisible(unit) then return false end
	local d = self:Distance(unit)
	if d then return d <= self.NEARBY_YARDS end
	return CheckInteractDistance(unit, 4) and true or false   -- ~28 yards
end

-- Group members (other than me and the summonee) close enough to click the portal.
function LP:CountHelpers(exclude)
	local n = 0
	local raid = GetNumRaidMembers()
	if raid > 0 then
		for i = 1, raid do
			local u = "raid" .. i
			local name = UnitName(u)
			if name and name ~= UnitName("player") and name ~= exclude
			   and UnitIsConnected(u) and not UnitIsDeadOrGhost(u) and self:IsNearby(u) then
				n = n + 1
			end
		end
	else
		for i = 1, GetNumPartyMembers() do
			local u = "party" .. i
			local name = UnitName(u)
			if name and name ~= exclude and UnitIsConnected(u) and not UnitIsDeadOrGhost(u) and self:IsNearby(u) then
				n = n + 1
			end
		end
	end
	return n
end

---------------------------------------------------------------------------
-- Roster / spellbook / bags
---------------------------------------------------------------------------
function LP:ScanRoster()
	local roster = {}
	local raid = GetNumRaidMembers()
	if raid > 0 then
		for i = 1, raid do
			local name, _, _, _, classLocal, class, zone, online, dead = GetRaidRosterInfo(i)
			if name then
				roster[name] = { unit = "raid" .. i, class = class, classLocal = classLocal,
				                 zone = zone, online = online, dead = dead }
			end
		end
	else
		for i = 1, GetNumPartyMembers() do
			local u = "party" .. i
			local name = UnitName(u)
			if name then
				local classLocal, class = UnitClass(u)
				roster[name] = { unit = u, class = class, classLocal = classLocal,
				                 online = UnitIsConnected(u), dead = UnitIsDeadOrGhost(u) }
			end
		end
	end
	self.roster = roster
	return roster
end

function LP:KnowsRitual()
	if self.knowsRitual ~= nil then return self.knowsRitual end
	local i = 1
	while true do
		local name = GetSpellName(i, BOOKTYPE_SPELL)
		if not name then break end
		if name == self.SPELL then
			self.knowsRitual = true
			return true
		end
		i = i + 1
	end
	self.knowsRitual = false
	return false
end

function LP:CountShards()
	local total = 0
	local pattern = "item:" .. self.SHARD_ID .. ":"
	for bag = 0, 4 do
		local slots = GetContainerNumSlots(bag) or 0
		for slot = 1, slots do
			local link = GetContainerItemLink(bag, slot)
			if link and string.find(link, pattern, 1, true) then
				local _, count = GetContainerItemInfo(bag, slot)
				total = total + math.abs(count or 1)
			end
		end
	end
	return total
end

function LP:HasEvilTwin(unit)
	for i = 1, 16 do
		local tex, _, _, id = UnitDebuff(unit, i)
		if not tex then break end
		if id == self.EVILTWIN_ID then return true end
		if string.find(string.lower(tex), self.EVILTWIN_TEX, 1, true) then return true end
	end
	return false
end

---------------------------------------------------------------------------
-- Instances: a player inside a dungeon/raid/battleground you're not in can't
-- be summoned out. Zone names come from the raid roster (raids only; 1.12
-- doesn't share zones for 5-man parties). English zone names.
---------------------------------------------------------------------------
LP.INSTANCES = {}
for _, z in ipairs({
	-- dungeons
	"Ragefire Chasm", "Wailing Caverns", "The Deadmines", "Shadowfang Keep", "Blackfathom Deeps",
	"The Stockade", "Gnomeregan", "Razorfen Kraul", "Scarlet Monastery", "Razorfen Downs", "Uldaman",
	"Zul'Farrak", "Maraudon", "The Temple of Atal'Hakkar", "Sunken Temple", "Blackrock Depths",
	"Blackrock Spire", "Dire Maul", "Stratholme", "Scholomance",
	-- raids
	"Molten Core", "Onyxia's Lair", "Blackwing Lair", "Zul'Gurub", "Ruins of Ahn'Qiraj",
	"Ahn'Qiraj", "Temple of Ahn'Qiraj", "Naxxramas",
	-- battlegrounds
	"Warsong Gulch", "Arathi Basin", "Alterac Valley",
	-- Turtle WoW
	"Crescent Grove", "Karazhan Crypt", "Stormwind Vault", "Gilneas City", "Hateforge Quarry",
	"The Black Morass", "Black Morass", "Dragonmaw Retreat", "Stormwrought Ruins",
	"Emerald Sanctum", "Lower Karazhan Halls", "Upper Karazhan Halls", "Tower of Karazhan",
}) do LP.INSTANCES[z] = true end

-- Returns the instance name if the player is inside an instance I'm not in.
function LP:InstanceBlock(info)
	local z = info and info.zone
	if not z or z == "" or z == GetRealZoneText() then return nil end
	if self.INSTANCES[z] then return z end
	return nil
end

---------------------------------------------------------------------------
-- Request list
---------------------------------------------------------------------------
function LP:FindRequest(name)
	for i, r in ipairs(self.requests) do
		if r.name == name then return i end
	end
	return nil
end

-- Returns true if the name was newly added.
function LP:AddRequest(name, broadcast)
	if not name or name == "" or name == UnitName("player") then return false end
	if broadcast then self:SendAddon(PREFIX_ADD, name) end
	if not self:IsWarlock() then return false end
	if self:FindRequest(name) then return false end
	if not self:ScanRoster()[name] then return false end
	table.insert(self.requests, { name = name, t = GetTime() })
	self:OnNewRequest(name)
	self:UpdateUI()
	return true
end

function LP:RemoveRequest(name, broadcast)
	if broadcast then self:SendAddon(PREFIX_REMOVE, name) end
	local i = self:FindRequest(name)
	if i then
		table.remove(self.requests, i)
		self:UpdateUI()
	end
end

function LP:ClearRequests()
	for i = table.getn(self.requests), 1, -1 do
		self:RemoveRequest(self.requests[i].name, true)
	end
end

function LP:OnNewRequest(name)
	local O = LockPortOptions
	if O.sound then
		PlaySoundFile("Sound\\Creature\\Necromancer\\NecromancerReady1.wav")
	end
	if O.flash and self.mods.unitxp then
		pcall(UnitXP, "notify", "taskbarIcon")
	end
	if O.autoShow and LockPortFrame and not LockPortFrame:IsVisible() then
		LockPortFrame:Show()
	end
end

-- Drop names that left the group; auto-remove people who already arrived.
function LP:PruneRequests()
	local roster = self:ScanRoster()
	local O = LockPortOptions
	for i = table.getn(self.requests), 1, -1 do
		local r = self.requests[i]
		local info = roster[r.name]
		if not info then
			table.remove(self.requests, i)
		elseif O.autoRemove and not (self.pending and self.pending.name == r.name)
		       and GetTime() - r.t > 5 and info.online and self:IsNearby(info.unit) then
			self:Print(r.name .. " is already here - removed from the list.")
			self:RemoveRequest(r.name, true)
		end
	end
end

-- Sorted view for the UI: warlocks first (they help click), then oldest request first.
function LP:SortedRequests()
	local roster = self.roster
	local list = {}
	for i, r in ipairs(self.requests) do
		local info = roster[r.name]
		if info then
			table.insert(list, { name = r.name, t = r.t, info = info, lock = (info.class == "WARLOCK") })
		end
	end
	table.sort(list, function(a, b)
		if a.lock ~= b.lock then return a.lock end
		return a.t < b.t
	end)
	return list
end

-- Status for one row: text, r, g, b
function LP:RequestStatus(entry)
	local info, u = entry.info, entry.info.unit
	if self.pending and self.pending.name == entry.name and not self.pending.done then
		return "Summoning...", 0.58, 0.51, 0.79
	end
	if not UnitIsConnected(u) then return "Offline", 0.5, 0.5, 0.5 end
	if UnitIsDeadOrGhost(u) then return "Dead", 1, 0.25, 0.25 end
	if UnitAffectingCombat(u) then return "In combat", 1, 0.5, 0.1 end
	if UnitIsVisible(u) then
		local d = self:Distance(u)
		if d then
			if d <= self.NEARBY_YARDS then return "Here", 0.25, 1, 0.25 end
			return string.format("%d yd", d), 0.85, 0.85, 0.85
		end
		if CheckInteractDistance(u, 4) then return "Here", 0.25, 1, 0.25 end
	end
	if info.zone and info.zone ~= "" then
		if info.zone == GetRealZoneText() then return "Same zone", 0.85, 0.85, 0.85 end
		if self:InstanceBlock(info) then return info.zone, 1, 0.5, 0.1 end
		return info.zone, 0.85, 0.85, 0.85
	end
	return "", 1, 1, 1
end

---------------------------------------------------------------------------
-- Failure reporting
---------------------------------------------------------------------------
function LP:Fail(name, key, rawText, extra, quiet)
	local O = LockPortOptions
	local reason = REASONS[key]
	local groupText, whisperText
	if reason then
		groupText = string.format(reason.group, name, extra or "")
		whisperText = reason.whisper and string.format(reason.whisper, extra or "")
	else
		-- server / client error text, e.g. "Target is in combat", "You must be standing to do that"
		groupText = rawText or "unknown error"
		whisperText = rawText
	end

	self:Print("|cffff4040can't summon " .. name .. ":|r " .. groupText)
	if quiet then return end

	-- don't spam the same failure for the same person
	local now = GetTime()
	local k = name .. "\001" .. groupText
	if self.lastFailKey == k and now - (self.lastFailTime or 0) < 10 then return end
	self.lastFailKey, self.lastFailTime = k, now

	local chan = self:GroupChannel()
	if O.announceFail and chan then
		SendChatMessage(ANNOUNCE_TAG .. "Can't summon " .. name .. ": " .. groupText .. ".", chan)
	end
	if O.whisperFail and whisperText and key ~= "offline" and name ~= UnitName("player") then
		SendChatMessage(ANNOUNCE_TAG .. "Couldn't summon you: " .. whisperText .. ".", "WHISPER", nil, name)
	end
end

---------------------------------------------------------------------------
-- Summoning
---------------------------------------------------------------------------
function LP:SummonNext()
	local e = self:NextCandidate()
	if e then return self:Summon(e.name) end
	if self.requests[1] then
		self:Print("nobody on the list can be summoned right now (offline, dead, in combat, in an instance, or being summoned by another warlock).")
	else
		self:Print("nobody is waiting for a summon.")
	end
end

function LP:Summon(name)
	if not self:IsWarlock() then return self:Print("only warlocks can summon.") end
	if self.pending and not self.pending.done then
		return self:Print("already summoning " .. self.pending.name .. ".")
	end
	if not self:KnowsRitual() then return self:Print("you don't know " .. self.SPELL .. " yet.") end

	local info = self:ScanRoster()[name]
	if not info then
		self:Print(name .. " is no longer in your group - removed.")
		return self:RemoveRequest(name, true)
	end
	local unit = info.unit

	-- target-side checks
	local problem, extra = self:TargetProblem(info)
	if problem == "eviltwin" then
		self:Fail(name, "eviltwin")
		return self:RemoveRequest(name, true)
	elseif problem == "here" then
		self:Print(name .. " is already here - removed from the list.")
		return self:RemoveRequest(name, true)
	elseif problem then
		return self:Fail(name, problem, nil, extra)
	end
	-- my side
	if UnitAffectingCombat("player") then return self:Fail(name, "mecombat") end
	if self:CountShards() < 1 then return self:Fail(name, "noshards") end

	local helpers = self:CountHelpers(name)
	if helpers < 2 then
		self:Print("|cffffd200heads up:|r only " .. helpers .. " group member(s) nearby to click the portal (2 needed).")
	end

	-- The ritual summons the warlock's target, so keep it targeted until the portal completes.
	self.pending = { name = name, unit = unit, t = GetTime() }
	self:SendAddon(PREFIX_WHISPER, "summon:" .. name)   -- other warlocks' Summon Next skips this player for a bit
	TargetUnit(unit)
	CastSpellByName(self.SPELL)
	self:UpdateUI()
end

-- Why this player can't be summoned right now: nil, or a REASONS key (+ extra).
-- "here" means they're already next to me.
function LP:TargetProblem(info)
	local u = info.unit
	if not UnitIsConnected(u) then return "offline" end
	if UnitIsDeadOrGhost(u) then return "dead" end
	if UnitAffectingCombat(u) then return "combat" end
	local inst = self:InstanceBlock(info)
	if inst then return "instance", inst end
	if UnitIsVisible(u) and self:HasEvilTwin(u) then return "eviltwin" end
	if self:IsNearby(u) then return "here" end
	return nil
end

---------------------------------------------------------------------------
-- Picking who's next. Summon Next skips anyone who can't be summoned right
-- now, anyone another warlock just started summoning ("summon:<name>" claim),
-- and anyone who failed 3 times in a row (for a minute).
---------------------------------------------------------------------------
LP.failCount = {}
LP.skipUntil = {}

function LP:NoteResult(name, ok)
	if ok then
		self.failCount[name] = nil
		self.skipUntil[name] = nil
		return
	end
	self.failCount[name] = (self.failCount[name] or 0) + 1
	if self.failCount[name] >= 3 then
		self.failCount[name] = nil
		self.skipUntil[name] = GetTime() + 60
		self:Print(name .. " failed 3 times in a row - Summon Next skips them for a minute.")
	end
end

-- First player who can be summoned right now (or nil).
function LP:NextCandidate()
	local now = GetTime()
	self:ScanRoster()
	for _, e in ipairs(self:SortedRequests()) do
		local claimT = self.claims["summon:" .. e.name]
		local claimed = claimT and now - claimT < 20
		local skipped = self.skipUntil[e.name] and now < self.skipUntil[e.name]
		if not claimed and not skipped and not self:TargetProblem(e.info) then
			return e
		end
	end
	return nil
end

-- What the Summon button would do right now: ready (bool), text for the window.
function LP:ReadyState()
	local p = self.pending
	if p and not p.done then return false, "Summoning " .. p.name .. "..." end
	if not self.requests[1] then return false, nil end
	if UnitIsDeadOrGhost("player") then return false, "You're dead" end
	if UnitAffectingCombat("player") then return false, "You're in combat" end
	if self:CountShards() < 1 then return false, "No Soul Shards" end
	local e = self:NextCandidate()
	if not e then return false, "Nobody can be summoned yet" end
	local h = self:CountHelpers(e.name)
	if h < 2 then return false, "Waiting for helpers (" .. h .. "/2)" end
	return true, "Ready: " .. e.name
end

-- Chime (and flash the taskbar) when a summon becomes possible.
function LP:CheckReady()
	local ready, text = self:ReadyState()
	self.readyText = text
	if ready and not self.wasReady and self:IsWarlock() then
		local O = LockPortOptions
		if O.readySound then PlaySound("ReadyCheck") end
		if O.flash and self.mods.unitxp then pcall(UnitXP, "notify", "taskbarIcon") end
	end
	self.wasReady = ready
	self.isReady = ready
end

---------------------------------------------------------------------------
-- Not enough helpers: ask the group to come click the portal.
-- Fires when someone is waiting (or a ritual is up) and fewer than 2 group
-- members are near you for ~8 s. At most every 2 min, never in combat, and
-- only one LockPort warlock posts (a "help" claim resets the others' timers).
---------------------------------------------------------------------------
function LP:WhereText()
	local where = GetZoneText() or ""
	local sub = GetSubZoneText()
	if sub and sub ~= "" and sub ~= where then where = where .. " - " .. sub end
	return where
end

function LP:HelperCall(now)
	local O = LockPortOptions
	if not O.askHelpers or not self:IsWarlock() then self.helpShortSince = nil; return end
	local chan = self:GroupChannel()
	if not chan then self.helpShortSince = nil; return end

	local p = self.pending
	local channelling = p and not p.done and p.started
	local forName
	if channelling then
		forName = p.name
	else
		if UnitIsDeadOrGhost("player") or UnitAffectingCombat("player") or self:CountShards() < 1 then
			self.helpShortSince = nil
			return
		end
		local e = self:NextCandidate()
		if not e then self.helpShortSince = nil; return end
		forName = e.name
	end

	local h = self:CountHelpers(forName)
	if h >= 2 then self.helpShortSince = nil; return end
	self.helpShortSince = self.helpShortSince or now
	if now - self.helpShortSince < 8 then return end
	if UnitAffectingCombat("player") then return end
	if now < (self.nextHelpAt or 0) then return end
	local claimT = self.claims["help"]
	if claimT and now - claimT < 115 then
		self.nextHelpAt = claimT + 120
		return
	end

	local need = 2 - h
	local who = (need == 1) and "1 more person" or (need .. " more people")
	local msg
	if channelling then
		msg = ANNOUNCE_TAG .. "Need " .. who .. " at " .. self:WhereText() .. " to click the summoning portal for " .. forName .. "!"
	else
		local waiting = table.getn(self.requests)
		msg = ANNOUNCE_TAG .. "Need " .. who .. " at " .. self:WhereText() .. " to help summon - " ..
		      waiting .. (waiting == 1 and " player" or " players") .. " waiting."
	end
	SendChatMessage(msg, chan)
	self:SendAddon(PREFIX_WHISPER, "help")
	self.nextHelpAt = now + 120
end

---------------------------------------------------------------------------
-- "Summons are open - type 123" to the party/raid every N minutes (option).
-- Skipped in combat; with several LockPort warlocks only one posts per round.
---------------------------------------------------------------------------
function LP:TriggerWord()
	local _, _, w = string.find(LockPortOptions.triggers or "123", "^%s*([^,]+)")
	w = Trim(w or "")
	if w == "" then w = "123" end
	return w
end

function LP:OpenAnnounce(now, force)
	local O = LockPortOptions
	if not O.announceOpen and not force then return end
	if not self:IsWarlock() then return end
	local chan = self:GroupChannel()
	if not chan then return end
	local every = tonumber(O.announceOpenEvery) or 3
	if every < 1 then every = 1 end
	local period = every * 60
	if not force and now < (self.nextAnnounceAt or 0) then return end
	if UnitAffectingCombat("player") then return end
	local claimT = self.claims["announce"]
	if not force and claimT and now - claimT < period - 5 then
		self.nextAnnounceAt = claimT + period
		return
	end
	local n = table.getn(self.requests)
	local msg = ANNOUNCE_TAG .. "Summons are open - type " .. self:TriggerWord() .. " to get summoned."
	if n > 0 then msg = msg .. " (" .. n .. " in line)" end
	SendChatMessage(msg, chan)
	self:SendAddon(PREFIX_WHISPER, "announce")
	self.nextAnnounceAt = now + period
end

-- The ritual really started: announce and take the name off everyone's list.
function LP:OnRitualStarted()
	local p = self.pending
	if not p or p.started then return end
	p.started = true
	p.failed = nil
	local O = LockPortOptions
	local name = p.name
	local shards = self:CountShards() - 1
	if shards < 0 then shards = 0 end

	local where = self:WhereText()

	local msg
	if O.customMessage and O.message and O.message ~= "" then
		msg = O.message
		msg = string.gsub(msg, "{name}", EscapeRepl(name))
		msg = string.gsub(msg, "{zone}", EscapeRepl(where))
		msg = string.gsub(msg, "{shards}", shards)
	else
		msg = "Summoning " .. name
		if O.zone then msg = msg .. " to " .. where end
		if O.shards then msg = msg .. " [" .. shards .. " shards left]" end
		msg = msg .. ", please click the portal!"
	end
	SendChatMessage(msg, "SAY")

	if O.whisper then
		local w = "Summoning you"
		if O.zone then w = w .. " to " .. where end
		SendChatMessage(w .. ". Accept when the prompt shows up!", "WHISPER", nil, name)
	end

	self:RemoveRequest(name, true)
	self:UpdateUI()
end

function LP:FinishPending()
	local p = self.pending
	if not p or p.done then return end
	p.done = true
	if p.started and not p.interrupted then
		self.watch = { name = p.name, unit = p.unit, t = GetTime() }
		self:Print("ritual for " .. p.name .. " complete - waiting for them to accept.")
	elseif p.started and p.interrupted then
		-- put them back on everyone's list
		self:AddRequest(p.name, true)
		self:Fail(p.name, "interrupt")
	else
		if p.err then self:Fail(p.name, nil, p.err) else self:Fail(p.name, "nostart") end
	end
	self:NoteResult(p.name, p.started and not p.interrupted)
	self:UpdateUI()
end

-- Called every frame from the event frame.
function LP:OnUpdate(elapsed)
	local now = GetTime()
	if self.whisperQueue[1] then self:ProcessWhisperQueue(now) end
	local p = self.pending
	if p and not p.done then
		if not p.started then
			if p.failed and now - p.failT >= (p.hardFail and 0.25 or 0.5) then
				self:FinishPending()
			elseif now - p.t > 4 then
				self:FinishPending()
			end
		else
			if p.stopT and now - p.stopT >= 0.4 then
				self:FinishPending()
			elseif p.interrupted and now - p.intT >= 0.6 then
				self:FinishPending()
			end
		end
	end

	self.tick = (self.tick or 0) + elapsed
	if self.tick < 1 then return end
	self.tick = 0

	-- did the last summoned player arrive?
	local w = self.watch
	if w then
		if now - w.t > 180 then
			self.watch = nil
		elseif UnitName(w.unit) == w.name and self:IsNearby(w.unit) then
			self:Print("|cff40ff40" .. w.name .. " has arrived.|r")
			self.watch = nil
		end
	end
	if table.getn(self.requests) > 0 then
		self:PruneRequests()
	end
	self:OpenAnnounce(now)
	self:CheckReady()
	self:HelperCall(now)
	self:UpdateUI()
end

---------------------------------------------------------------------------
-- Status whispers ("you're already here", "you're #3 in line...")
--
-- Every LockPort warlock in the group sees the same "123", so replies are
-- coordinated: the warlock summoning that player answers at once, the others
-- wait a staggered delay (alphabetical among known LockPort warlocks) and
-- drop their reply if someone else's LPWhisper claim arrives first.
---------------------------------------------------------------------------
function LP:OnTrigger(name, info, event)
	if name == UnitName("player") then return end
	if not self:IsWarlock() then
		-- non-warlocks with LockPort just relay the request
		self:SendAddon(PREFIX_ADD, name)
		return
	end

	-- already standing next to me
	if info.online and self:IsNearby(info.unit) then
		if self:FindRequest(name) then self:RemoveRequest(name, true) end
		self:QueueWhisper(name, "here", self:HereText(info.unit))
		return
	end

	local p = self.pending
	if self:FindRequest(name) or (p and not p.done and p.name == name) then
		-- repeat request: tell them why they're still waiting
		self:SendAddon(PREFIX_ADD, name)
		self:QueueWhisper(name, "status", self:StatusText(name, info))
		return
	end

	local w = self.watch
	local recent = w and w.name == name and GetTime() - w.t < 120
	if self:AddRequest(name, true) then
		if recent then
			self:QueueWhisper(name, "status", "I cast your summon " .. math.floor(GetTime() - w.t) ..
				"s ago - accept the prompt if you still see it. I put you back on the list in case it expired.")
			self.watch = nil
		elseif event == "CHAT_MSG_WHISPER" then
			local pos = self:QueuePosition(name)
			SendChatMessage(ANNOUNCE_TAG .. "You're on the summon list" .. (pos and (" (#" .. pos .. ")") or "") .. ".", "WHISPER", nil, name)
		end
	end
end

function LP:QueuePosition(name)
	self:ScanRoster()
	for i, e in ipairs(self:SortedRequests()) do
		if e.name == name then return i end
	end
	return nil
end

function LP:HereText(unit)
	local d = self:Distance(unit)
	if d then
		return "You're already here (" .. math.floor(d) .. " yd from me) - no summon needed."
	end
	return "You're already standing next to me - no summon needed."
end

function LP:StatusText(name, info)
	local u = info.unit
	local p = self.pending
	if p and not p.done and p.name == name then
		if not p.started then return "Casting your summon right now - accept the prompt when it shows up." end
		local h = self:CountHelpers(name)
		if h >= 2 then
			return "Summoning you now - the portal is up, waiting for 2 people to click it. Accept the prompt when it shows up."
		end
		return "Summoning you now - waiting for helpers to click the portal (" .. h .. "/2 near me). Accept the prompt when it shows up."
	end

	local pos = self:QueuePosition(name)
	local line = pos and ("You're #" .. pos .. " in line") or "You're on the list"
	if UnitIsDeadOrGhost(u) then return line .. ", but you're dead - release or get a res first." end
	if UnitAffectingCombat(u) then return line .. ", but you're in combat - drop combat first." end
	local inst = self:InstanceBlock(info)
	if inst then return line .. ", but you're inside " .. inst .. " - zone out first." end
	if p and not p.done then return line .. " - I'm summoning " .. p.name .. " right now." end
	if UnitAffectingCombat("player") then return line .. " - I'm in combat, I'll summon you right after." end
	if self:CountShards() < 1 then return line .. " - I'm out of Soul Shards." end
	local h = self:CountHelpers(name)
	if h < 2 then
		return line .. " - waiting on helpers: I need 2 people near me to click the portal (" .. h .. " here)."
	end
	if pos and pos > 1 then
		return line .. " - " .. (pos - 1) .. " ahead of you."
	end
	return line .. " - you're next!"
end

function LP:ResponderDelay(name)
	local p = self.pending
	if p and not p.done and p.name == name then return 0 end
	local me = UnitName("player")
	local locks, seenMe = {}, false
	for n, info in pairs(self.roster) do
		if info.class == "WARLOCK" and info.online and (n == me or self.users[n]) then
			table.insert(locks, n)
			if n == me then seenMe = true end
		end
	end
	if not seenMe then table.insert(locks, me) end
	table.sort(locks)
	for i, n in ipairs(locks) do
		if n == me then return 0.4 + (i - 1) * 1.0 end
	end
	return 0.4
end

function LP:QueueWhisper(name, kind, text)
	if not LockPortOptions.whisperStatus then return end
	local key = kind .. ":" .. name
	local now = GetTime()
	if self.claims[key] and now - self.claims[key] < 12 then return end
	for _, q in ipairs(self.whisperQueue) do
		if q.key == key then return end
	end
	table.insert(self.whisperQueue, { key = key, name = name, text = text, at = now + self:ResponderDelay(name) })
end

function LP:ProcessWhisperQueue(now)
	local q = self.whisperQueue
	for i = table.getn(q), 1, -1 do
		local w = q[i]
		if self.claims[w.key] and now - self.claims[w.key] < 12 then
			table.remove(q, i)
		elseif now >= w.at then
			table.remove(q, i)
			self.claims[w.key] = now
			self:SendAddon(PREFIX_WHISPER, w.key)
			SendChatMessage(ANNOUNCE_TAG .. w.text, "WHISPER", nil, w.name)
		end
	end
end

---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------
function LP:MatchesTrigger(msg)
	msg = string.lower(Trim(msg))
	local triggers = LockPortOptions and LockPortOptions.triggers or DEFAULTS.triggers
	for word in string.gfind(triggers, "[^,]+") do
		word = string.lower(Trim(word))
		if word ~= "" then
			local len = string.len(word)
			if string.sub(msg, 1, len) == word then
				local nextc = string.sub(msg, len + 1, len + 1)
				if nextc == "" or not string.find(nextc, "%w") then return true end
			end
		end
	end
	return false
end

local CHAT_EVENTS = {
	CHAT_MSG_SAY = true, CHAT_MSG_YELL = true, CHAT_MSG_WHISPER = true,
	CHAT_MSG_PARTY = true, CHAT_MSG_RAID = true, CHAT_MSG_RAID_LEADER = true,
}

function LP:OnEvent(event)
	if event == "VARIABLES_LOADED" then return self:Initialize() end
	if not LockPortOptions then return end
	if CHAT_EVENTS[event] then
		if arg1 and arg2 and self:MatchesTrigger(arg1) then
			local info = self:ScanRoster()[arg2]
			if info then self:OnTrigger(arg2, info, event) end
		end

	elseif event == "CHAT_MSG_ADDON" then
		if arg1 == PREFIX_ADD or arg1 == PREFIX_REMOVE or arg1 == PREFIX_VERSION or arg1 == PREFIX_WHISPER then
			if arg4 then self.users[arg4] = true end
		end
		if arg1 == PREFIX_ADD then
			-- another warlock added someone who is standing next to me: they don't need a summon
			local info = self:ScanRoster()[arg2]
			if self:IsWarlock() and LockPortOptions.autoRemove and info and info.online and self:IsNearby(info.unit) then
				self:SendAddon(PREFIX_REMOVE, arg2)
			else
				self:AddRequest(arg2, false)
			end
		elseif arg1 == PREFIX_REMOVE then
			self:RemoveRequest(arg2, false)
		elseif arg1 == PREFIX_VERSION then
			self:OnVersionMessage(arg2)
		elseif arg1 == PREFIX_WHISPER then
			-- another LockPort warlock already answered / is summoning this player
			if arg4 ~= UnitName("player") then self.claims[arg2] = GetTime() end
		end

	-- cast tracking (works on a plain client) --------------------------------
	elseif event == "UI_ERROR_MESSAGE" then
		local p = self.pending
		if p and not p.done and not p.started and GetTime() - p.t < 4 then
			p.err = arg1
			if not p.failed then p.failed, p.failT = true, GetTime() end
		end
	elseif event == "SPELLCAST_START" then
		if arg1 == self.SPELL then self:OnRitualStarted() end
	elseif event == "SPELLCAST_CHANNEL_START" then
		local p = self.pending
		if p and not p.done and not p.started and GetTime() - p.t < 4 then self:OnRitualStarted() end
	elseif event == "SPELLCAST_FAILED" or event == "SPELLCAST_INTERRUPTED" then
		local p = self.pending
		if p and not p.done then
			if p.started then
				p.interrupted, p.intT = true, GetTime()
			else
				p.failed, p.failT, p.hardFail = true, GetTime(), true
			end
		end
	elseif event == "SPELLCAST_CHANNEL_STOP" then
		local p = self.pending
		if p and not p.done and p.started then p.stopT = GetTime() end

	-- SuperWoW: exact, GUID-matched cast events ---------------------------------
	elseif event == "UNIT_CASTEVENT" then
		local p = self.pending
		if p and not p.done and arg1 == self:MyGUID() and self:IsRitualId(arg4) then
			if arg3 == "START" or arg3 == "CHANNEL" then
				self:OnRitualStarted()
			elseif arg3 == "FAIL" then
				if p.started then p.interrupted, p.intT = true, GetTime()
				else p.failed, p.failT, p.hardFail = true, GetTime(), true end
			end
		end

	-- Nampower: server-confirmed failures ------------------------------------
	elseif event == "SPELL_FAILED_SELF" then
		local p = self.pending
		if p and not p.done and self:IsRitualId(arg1) then
			if p.started then p.interrupted, p.intT = true, GetTime()
			else p.failed, p.failT, p.hardFail = true, GetTime(), true end
		end

	elseif event == "RAID_ROSTER_UPDATE" or event == "PARTY_MEMBERS_CHANGED" then
		self:PruneRequests()
		self:UpdateUI()
		self:OnGroupChanged()
	elseif event == "SPELLS_CHANGED" or event == "LEARNED_SPELL_IN_TAB" then
		self.knowsRitual = nil
	elseif event == "BAG_UPDATE" then
		if LockPortFrame and LockPortFrame:IsVisible() then self:UpdateUI() end
	elseif event == "PLAYER_ENTERING_WORLD" then
		self:SendVersion(true)
	end
end

function LP:Initialize()
	if type(LockPortOptions) ~= "table" then LockPortOptions = {} end
	local O = LockPortOptions
	-- v2 saved a message without the toggle
	if O.customMessage == nil and O.message and O.message ~= "" then O.customMessage = true end
	for k, v in pairs(DEFAULTS) do
		if O[k] == nil then O[k] = v end
	end
	self:DetectMods()
	local ev = self.eventFrame
	if self.mods.superwow then ev:RegisterEvent("UNIT_CASTEVENT") end
	if self.mods.nampower then ev:RegisterEvent("SPELL_FAILED_SELF") end
	if self.CreateUI then self:CreateUI() end
	self:Print("v" .. tostring(GetAddOnMetadata("LockPort", "Version")) .. " loaded. Type |cffffd200/lockport|r to open, |cffffd200/lockport help|r for commands.")
end

---------------------------------------------------------------------------
-- Version check (compatible with v2's "lp" VERSION:<number> messages)
---------------------------------------------------------------------------
local function VersionNumber(v)
	local _, _, a, b, c = string.find(tostring(v or ""), "(%d+)%.(%d+)%.?(%d*)")
	return (tonumber(a) or 0) * 10000 + (tonumber(b) or 0) * 100 + (tonumber(c) or 0)
end

function LP:SendVersion(login)
	local v = "VERSION:" .. VersionNumber(GetAddOnMetadata("LockPort", "Version"))
	self:SendAddon(PREFIX_VERSION, v)
	if login and IsInGuild() then SendAddonMessage(PREFIX_VERSION, v, "GUILD") end
end

function LP:OnGroupChanged()
	local size = GetNumRaidMembers()
	if size == 0 then size = GetNumPartyMembers() end
	if size > (self.groupSize or 0) then self:SendVersion(false) end
	self.groupSize = size
end

function LP:OnVersionMessage(msg)
	local _, _, kind, num = string.find(msg or "", "^(%a+):(%d+)")
	if kind ~= "VERSION" then return end
	local remote = tonumber(num) or 0
	if remote > VersionNumber(GetAddOnMetadata("LockPort", "Version")) and not self.updateShown then
		self.updateShown = true
		self:Print("a newer version is available: " .. REPO_URL)
	end
end

---------------------------------------------------------------------------
-- Slash commands
---------------------------------------------------------------------------
local TOGGLES = {
	zone = "zone info in /say", whisper = "whisper the target", shards = "shard count in /say",
	sound = "sound on new request", announce = "announce failures to group",
	flash = "taskbar flash", autoremove = "auto-remove arrived players", lock = "window lock",
	status = "status whispers (already here / place in line)",
	helpers = "ask the raid for portal helpers",
}
local TOGGLE_KEYS = { announce = "announceFail", autoremove = "autoRemove", lock = "locked", status = "whisperStatus", helpers = "askHelpers" }

function LP:Slash(msg)
	msg = Trim(msg)
	local _, _, cmd, rest = string.find(msg, "^(%S*)%s*(.-)$")
	cmd = string.lower(cmd or "")
	local O = LockPortOptions

	if cmd == "" or cmd == "toggle" then
		self:Toggle()
	elseif cmd == "help" then
		self:Print("commands:")
		local lines = {
			"|cffffd200/lockport|r - show / hide the window",
			"|cffffd200/lockport next|r - summon the next person in line",
			"|cffffd200/lockport open|r - toggle the \"summons are open\" raid posts",
			"|cffffd200/lockport add [name]|r - add a name (or your target)",
			"|cffffd200/lockport remove <name>|r, |cffffd200clear|r - edit the list",
			"|cffffd200/lockport show|r - print the list",
			"|cffffd200/lockport options|r - open the options window",
			"|cffffd200/lockport message <text>|r or |cffffd200message clear|r - custom /say ({name} {zone} {shards})",
			"|cffffd200/lockport zone, whisper, shards, sound, announce, status, helpers, flash, autoremove, lock|r - toggles",
			"|cffffd200/lockport mods|r - which client mods LockPort is using",
			"|cffffd200/lockport style|r - switch window style (Classic / pfUI)",
			"|cffffd200/lockport reset|r - reset the window position",
		}
		for _, l in ipairs(lines) do DEFAULT_CHAT_FRAME:AddMessage("  " .. l) end
	elseif cmd == "next" or cmd == "summon" then
		if rest ~= "" then self:Summon(rest) else self:SummonNext() end
	elseif cmd == "add" then
		local name = rest
		if name == "" then name = UnitName("target") end
		if not name then return self:Print("target someone or use /lockport add <name>.") end
		if not self:ScanRoster()[name] then return self:Print(name .. " isn't in your group.") end
		if not self:AddRequest(name, true) then self:Print(name .. " is already on the list.") end
	elseif cmd == "remove" then
		self:RemoveRequest(rest, true)
	elseif cmd == "clear" then
		self:ClearRequests()
		self:Print("summon list cleared.")
	elseif cmd == "show" then
		if not self.requests[1] then return self:Print("the list is empty.") end
		for i, r in ipairs(self.requests) do DEFAULT_CHAT_FRAME:AddMessage("  " .. i .. ". " .. r.name) end
	elseif cmd == "options" or cmd == "settings" or cmd == "config" then
		self:ToggleOptions()
	elseif cmd == "message" then
		if string.lower(rest) == "clear" then rest = "" end
		O.message = rest
		O.customMessage = rest ~= ""
		self:Print("custom /say message " .. (rest ~= "" and ("set: " .. rest) or "cleared."))
		self:RefreshOptions()
	elseif cmd == "style" or cmd == "theme" then
		self:ToggleTheme()
	elseif cmd == "open" then
		O.announceOpen = not O.announceOpen
		self:Print("\"summons are open\" announcements: " .. OnOff(O.announceOpen))
		if O.announceOpen then self:OpenAnnounce(GetTime(), true) end
		self:RefreshOptions()
	elseif cmd == "mods" then
		self:PrintMods()
	elseif cmd == "reset" then
		O.pos = nil
		if LockPortFrame then
			LockPortFrame:ClearAllPoints()
			LockPortFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
		end
	elseif TOGGLES[cmd] then
		local key = TOGGLE_KEYS[cmd] or cmd
		O[key] = not O[key]
		self:Print(TOGGLES[cmd] .. ": " .. OnOff(O[key]))
		self:RefreshOptions()
	else
		self:Print("unknown command. Type /lockport help.")
	end
end

---------------------------------------------------------------------------
-- UI hooks (implemented in LockPort_UI.lua)
---------------------------------------------------------------------------
function LP:UpdateUI() if self.RefreshList then self:RefreshList() end end
function LP:RefreshOptions() if self.RefreshOptionsUI then self:RefreshOptionsUI() end end
function LP:Toggle()
	if not LockPortFrame then return end
	if LockPortFrame:IsVisible() then LockPortFrame:Hide() else LockPortFrame:Show() end
end
function LP:ToggleOptions()
	if not LockPortOptionsFrame then return end
	if LockPortOptionsFrame:IsVisible() then LockPortOptionsFrame:Hide() else LockPortOptionsFrame:Show() end
end

-- Key bindings (Bindings.xml)
BINDING_HEADER_LOCKPORT = "LockPort"
BINDING_NAME_LOCKPORT_SUMMON_NEXT = "Summon next in line"
BINDING_NAME_LOCKPORT_TOGGLE = "Show / hide window"

---------------------------------------------------------------------------
-- Boot
---------------------------------------------------------------------------
local ev = CreateFrame("Frame", "LockPortEventFrame")  -- not parented to UIParent so Alt+Z doesn't stop it
LP.eventFrame = ev
local EVENTS = {
	"VARIABLES_LOADED", "PLAYER_ENTERING_WORLD", "CHAT_MSG_ADDON",
	"CHAT_MSG_SAY", "CHAT_MSG_YELL", "CHAT_MSG_WHISPER",
	"CHAT_MSG_PARTY", "CHAT_MSG_RAID", "CHAT_MSG_RAID_LEADER",
	"UI_ERROR_MESSAGE", "SPELLCAST_START", "SPELLCAST_CHANNEL_START", "SPELLCAST_CHANNEL_STOP",
	"SPELLCAST_FAILED", "SPELLCAST_INTERRUPTED",
	"RAID_ROSTER_UPDATE", "PARTY_MEMBERS_CHANGED", "SPELLS_CHANGED", "LEARNED_SPELL_IN_TAB", "BAG_UPDATE",
}
for _, e in ipairs(EVENTS) do ev:RegisterEvent(e) end
ev:SetScript("OnEvent", function() LP:OnEvent(event) end)
ev:SetScript("OnUpdate", function() LP:OnUpdate(arg1 or 0) end)

SLASH_LOCKPORT1 = "/lockport"
SLASH_LOCKPORT2 = "/gurky"
SlashCmdList["LOCKPORT"] = function(msg) LP:Slash(msg) end
