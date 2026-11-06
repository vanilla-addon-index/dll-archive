--[[
  OctoBus
  -------
  Arrival timers for the Horde zeppelins and boats: Orgrimmar to Undercity, Grom'gol, Kargath
  and Thunder Bluff, Grom'gol to Undercity, Sparkwater to Revantusk, and Ratchet to Booty Bay.
  Each row reads "start -> end" and times the transport at the start; right-click reverses
  it. The window shows the routes for where you are (click its title for all of them) and
  opens by itself at either end of any route. A small minimap icon shows / hides it.

  HOW IT WORKS
  Needs ZepSense.dll (listed in dlls.txt). The DLL adds one function to the client,
  ZepTransports(), which returns the position of every zeppelin/boat the client has loaded.
  This addon polls it, watches each transport arrive at / leave its dock, and keeps a
  schedule: every route runs on a fixed cycle length, so one observed arrival predicts all
  later ones, even while the transport is out of sight.

  A "~" in front of a time means that time is still an estimate from stored data and has not
  been confirmed by seeing the transport dock this session. After the transport is seen
  docking (or leaving), the "~" disappears.

  Click a row to put a bell on it: you then get a chat message before that transport arrives.

  SLASH COMMANDS  (/ob, also /transit and /zep)
    /ob                     show / hide the window (works anywhere)
    /ob options             settings window (also: right-click the minimap icon)
    /ob list                print all timers in chat
    /ob alert <sec>         bell alerts fire this many seconds before arrival (default 45)
    /ob sound|chat|flash    toggle that alert type
    /ob zone                toggle "auto-show only at route ends" (off = always show)
    /ob all                 all routes / only routes for where you are (or click the title)
    /ob boat                show / hide the Sparkwater Port boat
    /ob scale <n>           window size, 0.6 to 2 (or drag the dots in the bottom-right corner)
    /ob shape square|round|auto   minimap icon placement (auto looks at your minimap)
    /ob where               print your zone / sub-zone and whether the window auto-shows
    /ob allow <name>        also auto-show in this zone or sub-zone
    /ob disallow <name>     take a place off that list
    /ob name <n> <text>     rename the far end of route number n (from /ob list)
    /ob period <n> <sec>    set a route's cycle length by hand
    /ob calibrate           optional: watch every transport on purpose (stand between the towers).
                            Not required: any arrival you see near the towers calibrates automatically.
    /ob reset               forget everything learned (back to built-in values)
    /ob travel <sec>        Ratchet boat: your travel time from Orgrimmar to the Ratchet dock
    /ob debug               show what the DLL is returning
    /ob debug on|off        record every transport the DLL reports to the saved file
]]

-- Stage 1: runs as soon as this file loads, so /ob always answers, even if the real
-- start-up below fails. If it fails, /ob prints the error message.
local OB_STAGE = "file loaded, start-up not finished"
SLASH_OCTOBUS1 = "/ob"
SLASH_OCTOBUS2 = "/transit"
SLASH_OCTOBUS3 = "/zep"
SlashCmdList["OCTOBUS"] = function(msg)
  DEFAULT_CHAT_FRAME:AddMessage("|cff33ffccOctoBus:|r not running. " .. tostring(OB_STAGE))
end

local OB_OK, OB_ERR = pcall(function ()

  local gfind = string.gmatch or string.gfind

  ------------------------------------------------------------------------
  -- Routes. x,y = where the transport stands while docked (measured in-game).
  -- period/anchor are starting values measured from a 25 minute log; anchor is the
  -- time() of one observed arrival. Real observations replace them automatically.
  ------------------------------------------------------------------------
  -- Zones (or sub-zones) of each end, for the "where you are" view: homeZ = the home end,
  -- awayZ = the far end, planZ = places where the route is shown for planning (Ratchet from
  -- Orgrimmar, as "fly").
  local ORG = { "Orgrimmar", "Durotar" }
  local ROUTES = {
    -- Built-in starting values from Phridgey's sightings on 8 Oct 2026: cycle measured over
    -- ~5 h (origin = first sighting, anchor = latest), stay at the dock, and where measured
    -- on a ride, the far end (flipOffset = seconds after docking here that it docks there).
    -- A new copy refines all of this from its own sightings.
    -- period = trip length, measured against the restart time over two server runs of
    -- 15-43 hours (13-14 Oct 2026). bootPhase = seconds into each trip at which it docks
    -- here, counted from the server's restart, as measured in the run that began 14 Oct
    -- 2026. It shifts by seconds (or, for some routes, minutes) at each restart, so it is
    -- only a first guess; shared sightings (below) correct it.
    { entry = 164871, homeZ = ORG, awayZ = { "Tirisfal Glades", "Undercity" },
      name = "Undercity", kind = "zeppelin", x = 1318.1, y = -4658.0,
      period = 356.2806, bootPhase = 220.3, dwell = 64.0, origin = 1791471571.34, anchor = 1791489385.64,
      flipFrom = "Undercity", flipTo = "Orgrimmar", flipOffset = 191.1, flipDwell = 64.0 },
    { entry = 175080, homeZ = ORG, awayZ = { "Stranglethorn Vale" },
      name = "Grom'gol", kind = "zeppelin", x = 1360.8, y = -4631.3,
      period = 303.4592, bootPhase = 227.8, dwell = 64.1, origin = 1791471600.26, anchor = 1791489504.28,
      flipFrom = "Grom'gol", flipTo = "Orgrimmar", flipOffset = 138.2, flipDwell = 64.1 },
    { entry = 190552, homeZ = ORG, awayZ = { "Badlands" },
      name = "Kargath", kind = "zeppelin", x = 1206.1, y = -4158.7,
      period = 374.0474, bootPhase = 235.3, dwell = 63.9, origin = 1791471857.57, anchor = 1791489438.99,
      flipFrom = "Kargath", flipTo = "Orgrimmar", flipOffset = 198.0, flipDwell = 64.2 },
    { entry = 190549, homeZ = ORG, awayZ = { "Mulgore", "Thunder Bluff" },
      name = "Thunder Bluff", kind = "zeppelin", x = 1125.4, y = -4135.0,
      period = 566.7573, bootPhase = 350.5, dwell = 64.2, origin = 1791472003.14, anchor = 1791490140.28,
      flipFrom = "Thunder Bluff", flipTo = "Orgrimmar", flipOffset = 275.8, flipDwell = 64.0 },
    { entry = 190550, homeZ = ORG, awayZ = { "The Hinterlands" },
      name = "Sparkwater", kind = "boat", x = 876.1, y = -5204.1, boat = true,
      period = 245.0314, bootPhase = 187.5, dwell = 44.1, origin = 1791471573.69, anchor = 1791489460.91,
      flipFrom = "Revantusk", flipTo = "Sparkwater", flipOffset = 123.2, flipDwell = 44.0 },
    -- Grom'gol <-> Undercity zeppelin, timed at the Grom'gol dock (the only end measured).
    -- Seen leaving Grom'gol 1791480459.89 and arriving 1791486390.25: 18 cycles of 333.02 s
    -- (assuming the usual 64 s stay); an earlier glimpse docked fits too. The Undercity end
    -- is learned on the first ride from Grom'gol.
    { entry = 176495, homeZ = { "Stranglethorn Vale" }, awayZ = { "Tirisfal Glades", "Undercity" },
      name = "Undercity", kind = "zeppelin", x = -12406.9, y = 211.8,
      period = 333.0015, bootPhase = 69.0, dwell = 64.0, origin = 1791480395.89, anchor = 1791486390.25,
      flipFrom = "Undercity", flipTo = "Grom'gol" },
    -- Ratchet -> Booty Bay boat, timed at the Ratchet dock. Never visible from Orgrimmar, so
    -- the row shows when to fly out ("fly") rather than when it docks. Ratchet arrivals
    -- 1791479926.67 .. 1791490117.34 are 28 cycles apart (363.95 s). Booty Bay end seen on
    -- two days' rides: docks 178.6 s after Ratchet, stays 64.2 s.
    { entry = 20808, homeZ = { "Ratchet" }, awayZ = { "Stranglethorn Vale" }, planZ = ORG,
      name = "Ratchet", kind = "boat", x = -1005.6, y = -3841.6, far = true,
      period = 364.0298, bootPhase = 51.8, dwell = 63.7, origin = 1791479926.67, anchor = 1791490117.34,
      flipFrom = "Booty Bay", flipTo = "Ratchet", flipOffset = 178.6, flipDwell = 64.2 },
  }

  -- Right-click on a row reverses it: times for the far end (flipFrom, going to flipTo). Where the other end was never measured (flipOffset unset), it is assumed to
  -- dock halfway through the cycle and to stay as long as at this end: a rough estimate.
  local DOCK_RADIUS = 2.0

  ------------------------------------------------------------------------
  -- Saved data
  ------------------------------------------------------------------------
  -- The game loads saved variables AFTER an addon's files have run (replacing the global),
  -- so the saved table is looked up on every access and its defaults are filled in
  -- whenever it changes.
  local G = getfenv(0)
  local dbRef = nil
  local function Ensure()
    local t = G.OctoBusDB
    if type(t) ~= "table" then
      t = {}
      G.OctoBusDB = t
    end
    if t ~= dbRef then
      dbRef = t
      t.anchor = t.anchor or {}
      t.period = t.period or {}
      t.names = t.names or {}
      t.bell = t.bell or {}
      t.origin = t.origin or {}
      t.dwell = t.dwell or {}
      t.lastObs = t.lastObs or {}
      t.flip = t.flip or {}
      t.farOff = t.farOff or {}
      t.farDwell = t.farDwell or {}
      t.cfg = t.cfg or {}
      local c = t.cfg
      if c.alert == nil then c.alert = 45 end
      if c.chat == nil then c.chat = true end
      if c.sound == nil then c.sound = false end
      if c.flash == nil then c.flash = false end
      if c.zoneOnly == nil then c.zoneOnly = true end
      c.allow = c.allow or {}
      if c.hideBoat == nil then c.hideBoat = false end
      if c.locked == nil then c.locked = false end
      if c.travel == nil then c.travel = 175 end
      t.pending = t.pending or {}
      t.seenAt = t.seenAt or {}
      t.bootPhase = t.bootPhase or {}
      t.bootPhaseBoot = t.bootPhaseBoot or {}
      t.corrected = t.corrected or {}
      t.pW0 = t.pW0 or {}
      t.pP0 = t.pP0 or {}
      t.pK = t.pK or {}
      t.src = t.src or {}
      if c.share == nil then c.share = true end
      if c.ver ~= 2 then   -- v2: alerts are opt-in per route (bell) and chat-only by default
        c.ver = 2
        c.chat = true
        c.sound = false
        c.flash = false
      end
    end
    return t
  end
  local DB = setmetatable({}, {
    __index = function(_, k) return Ensure()[k] end,
    __newindex = function(_, k, v) Ensure()[k] = v end,
  })
  local CFG = setmetatable({}, {
    __index = function(_, k) return Ensure().cfg[k] end,
    __newindex = function(_, k, v) Ensure().cfg[k] = v end,
  })
  Ensure()

  -- One-time repair (1.3.4): restarts used to re-measure trip lengths from only a few
  -- trips, throwing away days of evidence. Restore the long-term values (built in now),
  -- count them as 700 trips of evidence, and recompute the restart offsets with them.
  -- Runs once the saved data is loaded (VARIABLES_LOADED below): this file runs before
  -- that, so a repair here alone would only touch a temporary empty table.
  local function Repair134()
    if DB.fix134 then return end
    for i = 1, table.getn(ROUTES) do
      local r = ROUTES[i]
      local e = r.entry
      if r.period then
        DB.period[e] = r.period
        DB.pP0[e] = r.period
        DB.pW0[e] = 700
        if DB.origin[e] and DB.anchor[e] then
          DB.pK[e] = math.floor((DB.anchor[e] - DB.origin[e]) / r.period + 0.5)
        end
        if DB.boot and DB.anchor[e] and DB.anchor[e] > DB.boot then
          local c = math.mod(DB.anchor[e] - DB.boot, r.period)
          if c < 0 then c = c + r.period end
          DB.bootPhase[e] = c
          DB.bootPhaseBoot[e] = DB.boot
        end
      end
    end
    DB.fix134 = true
  end

  -- One-time update (1.3.6): new trip lengths measured against the restart time over two
  -- long server runs; offsets learned with the old lengths are dropped.
  local function Repair136()
    if DB.fix136 then return end
    for i = 1, table.getn(ROUTES) do
      local r = ROUTES[i]
      local e = r.entry
      DB.period[e] = r.period
      DB.pP0[e] = r.period
      DB.pW0[e] = 700
      if DB.origin[e] and DB.anchor[e] then
        DB.pK[e] = math.floor((DB.anchor[e] - DB.origin[e]) / r.period + 0.5)
      end
      DB.bootPhase[e] = nil
      DB.bootPhaseBoot[e] = nil
    end
    DB.fix136 = true
  end

  local function Say(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cff33ffccOctoBus:|r " .. msg)
  end

  local function FormatTime(s)
    s = math.floor(s + 0.5)
    if s < 0 then s = 0 end
    return string.format("%d:%02d", math.floor(s / 60), math.mod(s, 60))
  end

  -- Rows read "start -> end". flipTo is the home end (Orgrimmar, Sparkwater, Ratchet),
  -- flipFrom the far end; /ob name renames the far end.
  local function Away(r) return DB.names[r.entry] or r.flipFrom end
  local function RouteName(r) return r.flipTo .. " -> " .. Away(r) end
  local function Period(r)    return DB.period[r.entry] or r.period end
  local function Anchor(r)    return DB.anchor[r.entry] or r.anchor end
  local function Watched(r)   return DB.bell[r.entry] == true end
  -- Names are compared without capitals, quotes or outer spaces.
  local function Norm(n)
    n = string.lower(n or "")
    n = string.gsub(n, "[\"']", "")
    n = string.gsub(n, "^%s+", "")
    n = string.gsub(n, "%s+$", "")
    return n
  end

  local seenState = {}   -- entry -> { atDock = bool, arrivedAt = epoch or nil }

  -- Where the player is. LOC.z / LOC.sz = current zone / sub-zone; LOC.mz / LOC.msz = the
  -- place the "where you are" view is built for: the current one, or the last place that
  -- had routes (CFG.hub) when you are somewhere without any.
  local LOC = { z = "", sz = "", mz = "", msz = "", key = nil }
  local manualFlip = {}  -- right-clicks in the "where you are" view; cleared on zone change
  local function InListAt(t, z, sz)
    if not t then return false end
    for i = 1, table.getn(t) do
      local a = Norm(t[i])
      if a == z or a == sz then return true end
    end
    return false
  end
  local function AtHome(r) return InListAt(r.homeZ, LOC.mz, LOC.msz) end
  local function AtAway(r) return InListAt(r.awayZ, LOC.mz, LOC.msz) end
  local function AtPlan(r) return InListAt(r.planZ, LOC.mz, LOC.msz) end
  local function UpdateLoc()
    local z, sz = Norm(GetZoneText()), Norm(GetSubZoneText())
    if z ~= LOC.key then LOC.key = z; manualFlip = {} end
    LOC.z, LOC.sz = z, sz
    local any = false
    for i = 1, table.getn(ROUTES) do
      local r = ROUTES[i]
      if InListAt(r.homeZ, z, sz) or InListAt(r.awayZ, z, sz) or InListAt(r.planZ, z, sz) then any = true end
    end
    if any then
      LOC.mz, LOC.msz = z, sz
      CFG.hub = { z = z, sz = sz }
    elseif CFG.hub then
      LOC.mz, LOC.msz = CFG.hub.z, CFG.hub.sz
    else
      LOC.mz, LOC.msz = z, sz
    end
  end

  -- Shown rows: "all routes" (CFG.full) or only the ones for where you are (either end,
  -- a planning place, or the transport in view, e.g. while riding it).
  local function Visible(r)
    if r.boat and CFG.hideBoat then return false end
    if CFG.full then return true end
    return AtHome(r) or AtAway(r) or AtPlan(r) or seenState[r.entry] ~= nil
  end

  -- confirmed[entry] = true once the transport has been SEEN docking/leaving at its home end
  -- this session, or "far" when it was synced from a sighting at the far end
  local confirmed = {}

  ------------------------------------------------------------------------
  -- Clock: epoch seconds with sub-second precision. time() only ticks whole seconds,
  -- so remember the largest (time() - GetTime()) seen: that converges on the true offset.
  ------------------------------------------------------------------------
  local clockC = nil
  local function EpochNow()
    local g = GetTime()
    local c = time() - g
    if (not clockC) or c > clockC then clockC = c end
    return g + clockC
  end

  local function Dwell(r) return DB.dwell[r.entry] or r.dwell end

  -- returns "docked", secondsUntilDeparture   or   "wait", secondsUntilArrival
  -- Reversed? "All routes": as set with right-click (kept). "Where you are": starts from
  -- your end automatically; a right-click reverses it until you change zone.
  local function Flipped(r)
    if not r.flipFrom then return false end
    if CFG.full then return DB.flip[r.entry] == true end
    local auto = AtAway(r) and not AtHome(r) and not AtPlan(r)
    if manualFlip[r.entry] then return not auto end
    return auto
  end
  local function FlipName(r) return Away(r) .. " -> " .. r.flipTo end
  local function ShownName(r) if Flipped(r) then return FlipName(r) end return RouteName(r) end
  local function StartName(r) if Flipped(r) then return Away(r) end return r.flipTo end
  local RowName = ShownName

  -- Each place has its own colour in the rows; renamed or unknown places stay white.
  -- These are the full colours; the vibrance setting (CFG.vibrance, default 75%) darkens them.
  local PLACE_COLOR = {
    ["orgrimmar"] = "ff5544", ["undercity"] = "b48cff", ["gromgol"] = "66dd55",
    ["kargath"] = "e09a55", ["thunder bluff"] = "e8cc77", ["sparkwater"] = "44ccff",
    ["revantusk"] = "33bba0", ["revantusk village"] = "33bba0", ["ratchet"] = "ffdd33",
    ["booty bay"] = "ff88cc",
  }
  local paintCache, paintAt = {}, nil
  local function Paint(n)
    local base = PLACE_COLOR[Norm(n)]
    if not base then return "|cffffffff" .. n .. "|r" end
    local v = CFG.vibrance or 0.75
    if v ~= paintAt then paintCache = {} paintAt = v end
    local hex = paintCache[base]
    if not hex then
      local function ch(i) return math.floor(tonumber(string.sub(base, i, i + 1), 16) * v + 0.5) end
      hex = string.format("%02x%02x%02x", ch(1), ch(3), ch(5))
      paintCache[base] = hex
    end
    return "|cff" .. hex .. n .. "|r"
  end
  local function ColoredName(r)
    local a, b = r.flipTo, Away(r)
    if Flipped(r) then a, b = b, a end
    return Paint(a) .. " |cff777777->|r " .. Paint(b)
  end

  -- Far end timing: learned on a ride (DB.farOff / DB.farDwell), else built in, else the
  -- rough "halfway through the cycle, same stay" assumption. FarKnown = not a guess.
  local function FarKnown(r) return (DB.farOff[r.entry] or r.flipOffset) ~= nil end
  local function FarOff(r, P) return DB.farOff[r.entry] or r.flipOffset or P / 2 end
  local function FarDwell(r) return DB.farDwell[r.entry] or r.flipDwell or Dwell(r) end

  -- otherEnd = true: the same schedule seen from the far end of the route
  local function Predict(r, otherEnd)
    local a, P = Anchor(r), Period(r)
    if not a or not P or P <= 0 then return nil end
    local d = Dwell(r)
    if otherEnd then
      a = a + FarOff(r, P)
      d = FarDwell(r)
    end
    local e = EpochNow() - a
    local ph = math.mod(e, P)
    if ph < 0 then ph = ph + P end
    if ph < d then return "docked", d - ph end
    return "wait", P - ph
  end

  ------------------------------------------------------------------------
  -- Calibration. /ob calibrate: stay somewhere you can see the docks (between the two
  -- towers). Every route needs one fresh arrival (two the very first time, because a
  -- cycle length needs two arrivals to measure). Each new arrival is compared with the
  -- oldest trusted one (the "origin"): the gap divided by the whole number of cycles in
  -- it gives the cycle length, and the longer the gap, the more exact it gets.
  ------------------------------------------------------------------------
  local cal = nil        -- nil = not calibrating

  -- Every arrival that refines a cycle length counts as a calibration for that route,
  -- whether you ran /ob calibrate or just walked past the towers.
  local function FormatSpan(sec)
    if sec < 3600 then return string.format("%d min", math.floor(sec / 60 + 0.5)) end
    if sec < 86400 then return string.format("%.0f h", sec / 3600) end
    return string.format("%.1f days", sec / 86400)
  end

  local function CalFinish(complete)
    if not cal then return end
    Say(complete and "calibration complete." or "calibration stopped.")
    for i = 1, table.getn(ROUTES) do
      local r = ROUTES[i]
      if cal.need[r.entry] then
        local oldP = cal.oldP[r.entry]
        local done = (cal.got[r.entry] or 0) >= cal.need[r.entry]
        Say("  " .. RouteName(r) .. ": cycle " .. string.format("%.2f", Period(r)) .. "s" ..
          (oldP and (math.abs(oldP - Period(r)) > 0.005 and ("  (was " .. string.format("%.2f", oldP) .. ")") or "  (unchanged)") or "") ..
          (done and "" or "   - not seen, still using the old value"))
      end
    end
    cal = nil
  end

  local function CalObs(r, rebased)
    if not cal or not cal.need[r.entry] then return end
    local e = r.entry
    if rebased then
      cal.need[e] = (cal.got[e] or 0) + 1      -- the old baseline did not fit: measure again
      return
    end
    cal.got[e] = (cal.got[e] or 0) + 1
    local all = true
    for k, n in pairs(cal.need) do
      if (cal.got[k] or 0) < n then all = false end
    end
    if all then CalFinish(true) end
  end

  local function CalStart()
    cal = { need = {}, got = {}, oldP = {}, t0 = GetTime() }
    local n = 0
    for i = 1, table.getn(ROUTES) do
      local r = ROUTES[i]
      if Visible(r) and not r.far then
        cal.need[r.entry] = DB.origin[r.entry] and 1 or 2
        cal.oldP[r.entry] = Period(r)
        n = n + 1
      end
    end
    return n
  end

  local function CalCount()
    local done, total = 0, 0
    if not cal then return 0, 0 end
    for k, n in pairs(cal.need) do
      total = total + 1
      if (cal.got[k] or 0) >= n then done = done + 1 end
    end
    return done, total
  end

  ------------------------------------------------------------------------
  -- Watching the DLL
  ------------------------------------------------------------------------
  local dllOk = false
  local lastGood = 0

  -- Server uptime. ".server info" tells how long the server has been up, so the restart
  -- time is known exactly (DB.boot). Transports on this core run on server time, so each
  -- route docks a fixed number of seconds into its cycle after a restart (DB.bootPhase).
  -- Once that has been seen to hold across a restart (DB.bootTheory), every route is
  -- corrected straight after a restart, before any of them is seen.
  local uptimeAsked, uptimeHideUntil = 0, 0
  local function QueryUptime()
    if GetTime() - uptimeAsked < 120 then return end
    uptimeAsked = GetTime()
    uptimeHideUntil = GetTime() + 8
    SendChatMessage(".server info", "SAY")
  end

  local function LearnPhase(r, anchor)
    if not DB.boot or anchor < DB.boot then return end
    local P = Period(r)
    if not P or P <= 0 then return end
    local e = r.entry
    local c = math.mod(anchor - DB.boot, P)
    if c < 0 then c = c + P end
    local old = DB.bootPhase[e]
    if old then
      local d = c - old
      if d > P / 2 then d = d - P elseif d < -P / 2 then d = d + P end
      if math.abs(d) < 5 then
        -- the same offset after a different restart: the theory holds
        if DB.bootPhaseBoot[e] and math.abs(DB.bootPhaseBoot[e] - DB.boot) > 300 then DB.bootTheory = true end
        c = math.mod(old + d * 0.5 + P, P)
      end
    end
    DB.bootPhase[e] = c
    DB.bootPhaseBoot[e] = DB.boot
  end

  local function Phase(r) return DB.bootPhase[r.entry] or r.bootPhase end

  local function OnBoot(boot)
    local old = DB.boot or DB.bootPrev
    -- the uptime answer is whole seconds, so the same restart can come out a second
    -- earlier or later on another ask: keep the first value, or every timer set from it
    -- would suddenly count as "seen since the restart"
    if DB.boot and math.abs(boot - DB.boot) <= 5 then boot = DB.boot end
    DB.boot = boot
    DB.bootPrev = nil
    local restarted = old and math.abs(boot - old) > 300
    if restarted then
      -- the server restarted at 'boot': every route seen before then is off
      DB.restartAt = boot
      DB.restartRoute = "server uptime"
    elseif DB.restartAt and DB.restartAt > boot then
      -- same server run: a restart noticed earlier from a jump happened at 'boot'
      DB.restartAt = boot
    end
    -- every route not seen since this restart is put at restart time + its offset (learned,
    -- or built in), also on a new copy's very first login
    for i = 1, table.getn(ROUTES) do
      local r = ROUTES[i]
      local e = r.entry
      local P = Period(r)
      local c = Phase(r)
      -- seenAt within a few seconds of the restart was set by the restart itself (nobody
      -- is logged in that early), not by a sighting. A "shared" time that is exactly the
      -- old offset again is someone's guess that 1.3.5 passed on as a sighting.
      local guessed = DB.src[e] == "shared" and DB.anchor[e] and DB.bootPhaseBoot[e] ~= boot and c
        and math.abs(DB.anchor[e] - boot - c) < 2
      if c and P and P > 0 and ((DB.seenAt[e] or 0) <= boot + 5 or guessed) then
        DB.anchor[e] = boot + c
        if not DB.origin[e] or DB.origin[e] < boot then
          -- the stored schedule is from an earlier server run: start this run's
          -- measurement here, keeping the trip length and the evidence behind it
          DB.pW0[e] = (DB.pW0[e] or 700) + (DB.pK[e] or 0)
          DB.pP0[e] = P
          DB.pK[e] = 0
          DB.origin[e] = DB.anchor[e]
          DB.pending[e] = nil
          DB.lastObs[e] = nil
        end
        DB.corrected[e] = boot
        -- a guess, not a sighting: never shared, and a real sighting or shared time replaces it
        DB.src[e] = "guess"
        if restarted and DB.bootTheory then DB.seenAt[e] = boot end   -- "~" instead of "?"
      end
    end
    -- learn offsets from routes already seen since this restart
    for i = 1, table.getn(ROUTES) do
      local r = ROUTES[i]
      local e = r.entry
      if (DB.seenAt[e] or 0) > boot + 5 and DB.anchor[e] and DB.src[e] ~= "guess" then LearnPhase(r, DB.anchor[e]) end
    end
  end

  -- "Server uptime: 7 Hours 39 Minutes 39 Seconds" -> seconds
  local function ParseUptime(msg)
    local _, _, rest = string.find(msg or "", "^Server uptime: (.+)$")
    if not rest then return nil end
    local total, any = 0, false
    for n, unit in gfind(rest, "(%d+) (%a+)") do
      n = tonumber(n)
      unit = string.lower(unit)
      any = true
      if string.find(unit, "^day") then total = total + n * 86400
      elseif string.find(unit, "^hour") then total = total + n * 3600
      elseif string.find(unit, "^min") then total = total + n * 60
      elseif string.find(unit, "^sec") then total = total + n end
    end
    if any then return total end
    return nil
  end

  do
    local f = CreateFrame("Frame")
    local askAt = nil
    f:RegisterEvent("PLAYER_ENTERING_WORLD")
    f:RegisterEvent("CHAT_MSG_SYSTEM")
    f:SetScript("OnEvent", function()
      if event == "PLAYER_ENTERING_WORLD" then
        askAt = GetTime() + 4
      else
        local up = ParseUptime(arg1)
        if up then OnBoot(time() - up) end
      end
    end)
    f:SetScript("OnUpdate", function()
      if askAt and GetTime() >= askAt then
        askAt = nil
        QueryUptime()
      end
    end)
    -- hide the reply to our own query (a ".server info" you type yourself still shows)
    local origChat = ChatFrame_OnEvent
    ChatFrame_OnEvent = function(ev)
      if ev == "CHAT_MSG_SYSTEM" and GetTime() < uptimeHideUntil and arg1 and
          (string.find(arg1, "^Players online") or string.find(arg1, "^Server uptime") or string.find(arg1, "^Server Time")) then
        return
      end
      return origChat(ev)
    end
  end

  -- Server restart detection. A sighting that moves a route's schedule by far more than
  -- drift can explain (10 s + 0.5 s per hour since it was last seen) means the server
  -- restarted: every transport's schedule starts over. Routes not seen since are flagged
  -- until they are seen again. newAnchor = the home arrival time this sighting implies.
  local ShareSighting   -- set further down (sharing with other OctoBus users)
  local function NoteSighting(r, newAnchor)
    local e = r.entry
    local P = Period(r)
    local old = DB.anchor[e]
    local lastT = DB.seenAt[e] or DB.lastObs[e]
    if old and P and P > 0 and lastT then
      local d = math.mod(newAnchor - old, P)
      if d < 0 then d = d + P end
      if d > P / 2 then d = d - P end
      if math.abs(d) > 10 + 0.5 * (time() - lastT) / 3600 then
        if DB.boot and lastT < DB.boot then
          -- explained by the restart we already know about (last seen before it)
          if not DB.restartAt or DB.restartAt > DB.boot then DB.restartAt = DB.boot end
        else
          -- a restart we did not know about: mark it now and ask for the uptime
          DB.restartAt = time()
          DB.restartRoute = RouteName(r)
          if DB.boot then   -- that server run is over
            DB.bootPrev = DB.boot
            DB.boot = nil
          end
          QueryUptime()
        end
      end
    end
    DB.seenAt[e] = time()
    DB.corrected[e] = nil
    LearnPhase(r, newAnchor)
    -- sighting log for measuring drift over long server runs (route, home arrival time
    -- this sighting implies, time seen, server start); the last 3000 are kept
    if type(DB.slog) ~= "table" then DB.slog = {} end
    table.insert(DB.slog, e .. "," .. string.format("%.2f", newAnchor) .. "," .. time() .. "," .. (DB.boot or 0))
    if table.getn(DB.slog) > 3000 then table.remove(DB.slog, 1) end
    DB.src[e] = "dll"
    if ShareSighting then ShareSighting() end
  end

  local function Stale(r)
    return DB.restartAt ~= nil and (DB.seenAt[r.entry] or 0) < DB.restartAt
  end

  -- mark in front of a time: "" = seen since the current server restart (accurate),
  -- "~" = an estimate (corrected from the restart time, or never seen), "?" = not seen
  -- since a restart and not corrected (may be off by minutes)
  local function Mark(r)
    if Stale(r) then return "|cffffaa33?|r" end
    local e = r.entry
    if DB.corrected[e] or not DB.seenAt[e] then return "|cff888888~|r" end
    if Flipped(r) and not FarKnown(r) then return "|cff888888~|r" end
    return ""
  end

  local function OnArrive(r, t)
    local e = r.entry
    if not DB.origin[e] and r.origin then DB.origin[e] = r.origin end
    local P = Period(r)
    local pstate, psecs = Predict(r)
    local origin = DB.origin[e]
    local rebased = false
    if origin then
      local delta = t - origin
      local k = math.floor(delta / P + 0.5)
      local resid = delta - k * P
      -- fits the long-term schedule if within what drift can explain since the last
      -- fitting sighting; anything more is a restart (or a bad sighting)
      local tol = 0.25 * P
      if DB.lastObs[e] then tol = math.min(tol, 10 + 0.5 * (time() - DB.lastObs[e]) / 3600) end
      if k >= 1 and math.abs(resid) < tol then
        -- trip length = all evidence weighted by trips covered: earlier server runs
        -- (pP0 over pW0 trips) plus this run (delta over k trips)
        local W0 = DB.pW0[e] or 700   -- the built-in trip length: ~700 trips measured
        local P0 = DB.pP0[e] or P
        DB.period[e] = (P0 * W0 + delta) / (W0 + k)
        DB.pK[e] = k
        DB.lastObs[e] = time()
        DB.pending[e] = nil
      else
        -- Does not fit the baseline. One odd sighting is not enough to throw a long
        -- baseline away: keep it aside, and only start over when a second sighting
        -- agrees with it (schedule really jumped, e.g. a server restart).
        local pd = DB.pending[e]
        local fits = false
        if pd then
          local d2 = t - pd
          local k2 = math.floor(d2 / P + 0.5)
          fits = k2 >= 1 and math.abs(d2 - k2 * P) < 15
        end
        if fits then
          -- a new server run: keep the trip length and how much evidence is behind it
          DB.pW0[e] = (DB.pW0[e] or 700) + (DB.pK[e] or 0)
          DB.pP0[e] = Period(r)
          DB.pK[e] = 0
          DB.origin[e] = pd
          DB.pending[e] = nil
          DB.lastObs[e] = time()
          rebased = true
        else
          DB.pending[e] = t
        end
      end
    else
      DB.origin[e] = t
    end
    -- how far off was the schedule?
    if pstate and not confirmed[e] and CFG.chat and Watched(r) then
      local off
      if pstate == "docked" then off = Dwell(r) - psecs else off = -psecs end
      if pstate == "wait" and psecs < P / 2 then off = psecs end
      if math.abs(off) > 20 then
        Say(RouteName(r) .. ": schedule re-synced from what I just saw (was off by about " ..
          string.format("%d", math.floor(math.abs(off) + 0.5)) .. "s).")
      end
    end
    NoteSighting(r, t)
    DB.anchor[e] = t
    confirmed[e] = true
    CalObs(r, rebased)
  end

  local function OnDepart(r, t, st)
    local e = r.entry
    if st.arrivedAt then
      local d = t - st.arrivedAt
      if d > 20 and d < 150 then
        DB.dwell[e] = DB.dwell[e] and (DB.dwell[e] * 0.6 + d * 0.4) or d
      end
    else
      -- never saw it arrive, but it leaves 'dwell' seconds after arriving
      if not DB.origin[e] and r.origin then DB.origin[e] = r.origin end
      NoteSighting(r, t - Dwell(r))
      DB.anchor[e] = t - Dwell(r)
      if not DB.origin[e] then
        DB.origin[e] = t - Dwell(r)
        CalObs(r, false)
      end
    end
    confirmed[e] = true
  end

  ------------------------------------------------------------------------
  -- Recorder (/ob debug on): writes every transport position the DLL reports into
  -- OctoBusDB.rec, one line per sample, so a trip can be analysed afterwards. A sample is
  -- kept when the transport moved more than half a yard, or every 5 s while it stands
  -- still. Zone changes and flight-path start / end are logged too. The game writes the
  -- saved file on logout or /reload.
  ------------------------------------------------------------------------
  local REC_MAX = 40000
  local recOn = false
  local recLast = {}
  local function RecLine(txt)
    local log = DB.rec
    if type(log) ~= "table" then log = {}; DB.rec = log end
    if table.getn(log) >= REC_MAX then return end
    table.insert(log, txt)
  end
  local function Record(now, gid, ge, de, x, y, z)
    local L = recLast[gid]
    if L then
      local dx, dy = x - L.x, y - L.y
      if dx * dx + dy * dy < 0.25 and (now - L.t) < 5 then return end
    end
    recLast[gid] = { x = x, y = y, t = now }
    RecLine(string.format("%.2f T %s %s %d %.2f %.2f %.2f", now, gid, ge, de, x, y, z))
  end
  local recZone, recTaxi = nil, nil
  local function RecordPlayer(now)
    local zn = (GetRealZoneText() or "") .. "/" .. (GetSubZoneText() or "")
    if zn ~= recZone then
      recZone = zn
      RecLine(string.format("%.2f Z %s", now, zn))
    end
    local tx = UnitOnTaxi("player") and true or false
    if tx ~= recTaxi then
      recTaxi = tx
      RecLine(string.format("%.2f F %s", now, tx and "start" or "end"))
    end
  end

  ------------------------------------------------------------------------
  -- Far-end learning. A tracked transport that stands still for 20 s somewhere other than
  -- its home dock is docked at the far end. Its arrival there (when it first came within
  -- DOCK_RADIUS of where it stopped) is stored as seconds into the cycle, and its stay is
  -- stored when it leaves. Only learned when the home-end schedule was confirmed this
  -- session, so the offset is measured against a fresh schedule. Nothing is printed.
  ------------------------------------------------------------------------
  local FAR_STILL = 20
  local farW = {}        -- entry -> { hist = {{t,x,y}...}, sx, sy, st, arr }
  local function FarWatch(r, now, x, y, atDock)
    local e = r.entry
    if not r.flipFrom or atDock or (x == 0 and y == 0) then farW[e] = nil; return end
    local w = farW[e]
    if not w then w = { hist = {} }; farW[e] = w end
    -- keep only samples where it moved, so the approach is still in the history after
    -- 20 s standing still (polling is 10 per second while recording)
    local hn = table.getn(w.hist)
    local last = w.hist[hn]
    if not last or math.abs(last[2] - x) >= 0.05 or math.abs(last[3] - y) >= 0.05 then
      table.insert(w.hist, { now, x, y })
      if hn + 1 > 120 then table.remove(w.hist, 1) end
    end
    if w.sx and math.abs(x - w.sx) < 0.3 and math.abs(y - w.sy) < 0.3 then
      if not w.arr and (now - w.st) >= FAR_STILL then
        -- docked: arrival = first recent sample within DOCK_RADIUS of the stop point
        local arr, approached = w.st, false
        for i = table.getn(w.hist), 1, -1 do
          local h = w.hist[i]
          local dx, dy = h[2] - w.sx, h[3] - w.sy
          if math.sqrt(dx * dx + dy * dy) > DOCK_RADIUS then approached = true; break end
          arr = h[1]
        end
        w.arr = arr
        w.approached = approached
        local P = Period(r)
        -- Re-sync from the far end: the transport docks here farOff seconds after its
        -- home arrival, so its schedule is arrival - farOff. Only when the home end was
        -- not seen this session (a home sighting is more direct and wins).
        if approached and confirmed[e] ~= true and FarKnown(r) and P and P > 0 then
          NoteSighting(r, arr - FarOff(r, P))
          DB.anchor[e] = arr - FarOff(r, P)
          confirmed[e] = "far"
        end
        -- only when it was seen coming in (not already docked when it came into view)
        if approached and confirmed[e] == true and P and P > 0 then
          local off = math.mod(arr - Anchor(r), P)
          if off < 0 then off = off + P end
          local old = DB.farOff[e]
          if old and math.abs(old - off) < 20 then off = old * 0.5 + off * 0.5 end
          DB.farOff[e] = off
          w.learn = true
        end
      end
      return
    end
    if w.arr and w.sx then
      local dx, dy = x - w.sx, y - w.sy
      if math.sqrt(dx * dx + dy * dy) <= DOCK_RADIUS then return end   -- still easing out
      local d = now - w.arr
      -- the stay only needs this end's own arrival and departure, so it is learned
      -- whenever both were seen, wherever the schedule came from
      if w.approached and d > 20 and d < 150 then
        local old = DB.farDwell[e]
        DB.farDwell[e] = old and (old * 0.6 + d * 0.4) or d
      end
      -- never saw it dock here, but saw it leave: schedule = departure - stay - farOff
      local P = Period(r)
      if not w.approached and confirmed[e] ~= true and FarKnown(r) and P and P > 0 then
        NoteSighting(r, now - FarDwell(r) - FarOff(r, P))
        DB.anchor[e] = now - FarDwell(r) - FarOff(r, P)
        confirmed[e] = "far"
      end
      w.arr = nil
      w.learn = nil
      w.approached = nil
    end
    w.sx, w.sy, w.st = x, y, now
  end

  local function Poll()
    if type(ZepTransports) ~= "function" then dllOk = false; return end
    local ok, str = pcall(ZepTransports)
    if not ok or type(str) ~= "string" then dllOk = false; return end
    dllOk = true
    lastGood = GetTime()
    local now = EpochNow()
    if recOn then RecordPlayer(now) end
    local present = {}
    for rec in gfind(str, "([^;]+);") do
      local _, _, gid, tag, ge, de, x, y, z = string.find(rec, "^(%x+),(%x+),(%d+),(%d+),(%-?[%d%.]+),(%-?[%d%.]+),(%-?[%d%.]+)")
      de = tonumber(de)
      x = tonumber(x)
      y = tonumber(y)
      if de and x and y then
        if recOn then Record(now, gid, ge, de, x, y, tonumber(z) or 0) end
        for i = 1, table.getn(ROUTES) do
          local r = ROUTES[i]
          if r.entry == de and r.x then
            present[de] = true
            local dx, dy = x - r.x, y - r.y
            local atDock = (math.sqrt(dx * dx + dy * dy) <= DOCK_RADIUS)
            FarWatch(r, now, x, y, atDock)
            local st = seenState[de]
            if not st then
              seenState[de] = { atDock = atDock }
              if cal then cal.seenAny = true end
            else
              if atDock and not st.atDock then
                st.atDock = true
                st.arrivedAt = now
                OnArrive(r, now)
              elseif (not atDock) and st.atDock then
                st.atDock = false
                OnDepart(r, now, st)
                st.arrivedAt = nil
              end
            end
          end
        end
      end
    end
    -- forget transports that left view so the next sighting starts clean
    for i = 1, table.getn(ROUTES) do
      local e = ROUTES[i].entry
      if seenState[e] and not present[e] then seenState[e] = nil end
      if not present[e] then farW[e] = nil end
    end
  end

  ------------------------------------------------------------------------
  -- Frames
  ------------------------------------------------------------------------
  local font = STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
  local anchorTo = Minimap

  -- flat dark panel with a thin border
  local function CreateBackdrop(f)
    f:SetBackdrop({
      bgFile = "Interface\\Buttons\\WHITE8X8",
      edgeFile = "Interface\\Buttons\\WHITE8X8",
      tile = false, tileSize = 0, edgeSize = 1,
      insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    f:SetBackdropColor(0.02, 0.02, 0.02, 0.75)
    f:SetBackdropBorderColor(0.22, 0.22, 0.22, 1)
  end

  -- square or round minimap? "auto" looks at the minimap: the stock UI keeps it inside
  -- MinimapCluster; a replacement UI that moves it elsewhere is assumed to have made it square.
  local function MinimapIsSquare()
    if CFG.shape == "square" then return true end
    if CFG.shape == "round" then return false end
    if GetMinimapShape then return GetMinimapShape() == "SQUARE" end
    return Minimap:GetParent() ~= MinimapCluster
  end

  local ICON_HERE = "Interface\\Buttons\\UI-CheckBox-Check"
  local ICON_AWAY = "Interface\\Buttons\\UI-GroupLoot-Pass-Up"

  -- minimap icon: click = show / hide the window, drag = move it around the minimap edge
  local btn = CreateFrame("Button", "OctoBusButton", Minimap)
  btn:SetFrameStrata("MEDIUM")
  btn:SetFrameLevel(Minimap:GetFrameLevel() + 8)
  btn:SetWidth(31)
  btn:SetHeight(31)
  btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  btn:RegisterForDrag("LeftButton")
  btn.icon = btn:CreateTexture(nil, "ARTWORK")
  btn.icon:SetWidth(20)
  btn.icon:SetHeight(20)
  btn.icon:SetPoint("TOPLEFT", btn, "TOPLEFT", 7, -5)
  btn.icon:SetTexture("Interface\\Icons\\INV_Misc_Map_01")
  btn.border = btn:CreateTexture(nil, "OVERLAY")
  btn.border:SetWidth(53)
  btn.border:SetHeight(53)
  btn.border:SetPoint("TOPLEFT", btn, "TOPLEFT", 0, 0)
  btn.border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
  btn:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

  local function PlaceButton()
    local a = CFG.angle or (math.pi * 1.25)   -- default: bottom-left
    local dx, dy = math.cos(a), math.sin(a)
    local w = (anchorTo:GetWidth() or 140) / 2
    local h = (anchorTo:GetHeight() or 140) / 2
    local x, y
    if MinimapIsSquare() then
      -- square minimap: run the icon along the outside of the edge
      local m = math.max(math.abs(dx), math.abs(dy))
      x, y = dx / m * (w + 2), dy / m * (h + 2)
    else
      x, y = dx * (w + 5), dy * (h + 5)
    end
    btn:ClearAllPoints()
    btn:SetPoint("CENTER", anchorTo, "CENTER", x, y)
  end
  PlaceButton()

  btn:SetScript("OnDragStart", function() this.dragging = true end)
  btn:SetScript("OnDragStop", function() this.dragging = false end)
  btn:SetScript("OnUpdate", function()
    if not this.dragging then return end
    local cx, cy = GetCursorPosition()
    local sc = anchorTo:GetEffectiveScale()
    local mx, my = anchorTo:GetCenter()
    if not mx or not my then return end
    CFG.angle = math.atan2(cy / sc - my, cx / sc - mx)
    PlaceButton()
  end)

  -- the timer window
  -- sizes at text size 100%; ApplyLook scales them with the text size setting
  local textScale = CFG.textScale or 1
  local WIDTH = math.floor(280 * textScale * (CFG.widthScale or 1) + 0.5)
  local ROW_H = math.floor(18 * textScale + 0.5)
  local TOP = math.floor(22 * textScale + 0.5)

  local panel = CreateFrame("Frame", "OctoBusPanel", UIParent)
  panel:SetFrameStrata("MEDIUM")
  panel:SetWidth(WIDTH)
  panel:SetHeight(100)
  panel:SetClampedToScreen(true)
  panel:SetScale(CFG.scale or 1)
  panel:SetMovable(true)
  panel:EnableMouse(true)
  CreateBackdrop(panel)

  panel.title = panel:CreateFontString(nil, "OVERLAY")
  panel.title:SetFont(font, 10, "OUTLINE")
  panel.title:SetPoint("TOPLEFT", panel, "TOPLEFT", 8, -6)
  panel.title:SetText("|cff33ffccTransports|r")

  panel.status = panel:CreateFontString(nil, "OVERLAY")
  panel.status:SetFont(font, 9, "OUTLINE")
  panel.status:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -8, -7)
  panel.status:SetTextColor(0.6, 0.6, 0.6)

  panel.foot = panel:CreateFontString(nil, "OVERLAY")
  panel.foot:SetFont(font, 9, "OUTLINE")
  panel.foot:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 8, 4)
  panel.foot:SetJustifyH("LEFT")

  -- The window is pinned by one corner (CFG.anchor, set in the settings window; default
  -- bottom-left), so when the list gets longer or shorter the other edges move.
  local function SavePos()
    local a = CFG.anchor or "BOTTOMLEFT"
    local x = string.find(a, "RIGHT") and panel:GetRight() or panel:GetLeft()
    local y = string.find(a, "TOP") and panel:GetTop() or panel:GetBottom()
    if x and y then
      CFG.pos = { x = x, y = y, a = a }
      panel:ClearAllPoints()
      panel:SetPoint(a, UIParent, "BOTTOMLEFT", x, y)
    end
  end

  local function StartDrag()
    if CFG.locked then return end
    panel:StartMoving()
  end
  local function StopDrag()
    panel:StopMovingOrSizing()
    SavePos()
  end
  panel:RegisterForDrag("LeftButton")
  panel:SetScript("OnDragStart", StartDrag)
  panel:SetScript("OnDragStop", StopDrag)

  -- click the title: switch between all routes and routes for where you are
  local titleBtn = CreateFrame("Button", nil, panel)
  titleBtn:SetPoint("TOPLEFT", panel, "TOPLEFT", 4, -2)
  titleBtn:SetWidth(150)
  titleBtn:SetHeight(16)
  titleBtn:RegisterForClicks("LeftButtonUp")
  titleBtn:RegisterForDrag("LeftButton")
  titleBtn:SetScript("OnDragStart", StartDrag)
  titleBtn:SetScript("OnDragStop", StopDrag)
  titleBtn:SetScript("OnClick", function() CFG.full = not CFG.full end)
  titleBtn:SetScript("OnEnter", function()
    GameTooltip:SetOwner(this, "ANCHOR_TOP")
    GameTooltip:AddLine(CFG.full and "Showing all routes" or "Showing routes for where you are", 1, 1, 1)
    GameTooltip:AddLine("Click: " .. (CFG.full and "only routes for where you are" or "all routes") .. "  (/ob all)", 0.2, 1, 0.8)
    GameTooltip:Show()
  end)
  titleBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

  -- Resize grip, bottom-right: drag to scale the whole window (0.6x to 2x). The top-left
  -- corner stays where it is. Hidden while the window is locked.
  local SCALE_MIN, SCALE_MAX = 0.6, 2.0
  local grip = CreateFrame("Frame", nil, panel)
  grip:SetWidth(14)
  grip:SetHeight(14)
  grip:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -1, 1)
  grip:SetFrameLevel(panel:GetFrameLevel() + 10)
  grip:EnableMouse(true)
  grip.dots = {}
  local DOTS = { {3, 3}, {7, 3}, {11, 3}, {3, 7}, {7, 7}, {3, 11} }
  for i = 1, table.getn(DOTS) do
    local d = grip:CreateTexture(nil, "OVERLAY")
    d:SetTexture("Interface\\Buttons\\WHITE8X8")
    d:SetWidth(2)
    d:SetHeight(2)
    d:SetPoint("BOTTOMRIGHT", grip, "BOTTOMRIGHT", -DOTS[i][1] + 1, DOTS[i][2] - 1)
    d:SetVertexColor(0.5, 0.5, 0.5, 0.9)
    grip.dots[i] = d
  end
  local function GripColor(c)
    for i = 1, table.getn(grip.dots) do grip.dots[i]:SetVertexColor(c, c, c, 0.9) end
  end

  -- set a new scale, keeping the window's top-left corner on the same screen spot
  local function ApplyScale(sc)
    if sc < SCALE_MIN then sc = SCALE_MIN end
    if sc > SCALE_MAX then sc = SCALE_MAX end
    local oldEff = panel:GetEffectiveScale()
    local l, t = panel:GetLeft(), panel:GetTop()
    panel:SetScale(sc)
    CFG.scale = sc
    if l and t then
      local newEff = panel:GetEffectiveScale()
      panel:ClearAllPoints()
      panel:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", l * oldEff / newEff, t * oldEff / newEff)
      SavePos()
    end
  end

  grip:SetScript("OnEnter", function() GripColor(1) end)
  grip:SetScript("OnLeave", function() if not this.sizing then GripColor(0.5) end end)
  grip:SetScript("OnMouseDown", function()
    if CFG.locked then return end
    this.sizing = true
  end)
  grip:SetScript("OnMouseUp", function()
    this.sizing = false
    GripColor(MouseIsOver and MouseIsOver(this) and 1 or 0.5)
    SavePos()
  end)
  grip:SetScript("OnUpdate", function()
    if not this.sizing then return end
    local cx = GetCursorPosition()           -- screen pixels
    local l = panel:GetLeft()
    if not l then return end
    local leftPx = l * panel:GetEffectiveScale()
    local wantEff = (cx - leftPx) / WIDTH     -- window right edge follows the cursor
    local parentEff = UIParent:GetEffectiveScale()
    if wantEff > 0 and parentEff > 0 then ApplyScale(wantEff / parentEff) end
  end)

  if CFG.locked then grip:Hide() end

  local rows = {}

  -- text outline: "thin" (default), "thick", or "shadow" (thin outline plus a drop shadow)
  local function StyleText(fs, size)
    local o = CFG.outline or "thin"
    fs:SetFont(font, size, o == "thick" and "THICKOUTLINE" or "OUTLINE")
    if o == "shadow" then
      fs:SetShadowColor(0, 0, 0, 1)
      fs:SetShadowOffset(1.5, -1.5)
    else
      fs:SetShadowOffset(0, 0)
    end
  end

  local function PlaceRow(row, i)
    row:SetHeight(ROW_H)
    row:ClearAllPoints()
    row:SetPoint("TOPLEFT", panel, "TOPLEFT", 4, -(TOP + (i - 1) * ROW_H))
    row:SetPoint("RIGHT", panel, "RIGHT", -4, 0)
    local fs = math.floor(10 * textScale + 0.5)
    if row.name then
      StyleText(row.name, fs)
      StyleText(row.time, fs)
      row.name:SetAlpha(CFG.textAlpha or 1)
      row.time:SetAlpha(CFG.textAlpha or 1)
      row.icon:SetAlpha(CFG.alpha or 1)
      row.bell:SetAlpha(CFG.alpha or 1)
      row.bg:SetAlpha(CFG.alpha or 1)
    end
  end

  local function CreateRow(i)
    local row = CreateFrame("Button", nil, panel)
    row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    row:RegisterForDrag("LeftButton")
    row:SetScript("OnDragStart", StartDrag)
    row:SetScript("OnDragStop", StopDrag)

    row.bg = row:CreateTexture(nil, "BACKGROUND")
    row.bg:SetAllPoints(row)
    row.bg:SetTexture("Interface\\Buttons\\WHITE8X8")
    row.bg:SetVertexColor(0, 0, 0, 0)

    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetWidth(14)
    row.icon:SetHeight(14)
    row.icon:SetPoint("LEFT", row, "LEFT", 2, 0)

    row.name = row:CreateFontString(nil, "OVERLAY")
    row.name:SetFont(font, 10, "OUTLINE")
    row.name:SetPoint("LEFT", row.icon, "RIGHT", 4, 0)
    row.name:SetJustifyH("LEFT")


    row.time = row:CreateFontString(nil, "OVERLAY")
    row.time:SetFont(font, 10, "OUTLINE")
    row.time:SetPoint("RIGHT", row, "RIGHT", -20, 0)
    row.time:SetJustifyH("RIGHT")

    row.bell = row:CreateTexture(nil, "OVERLAY")
    row.bell:SetWidth(13)
    row.bell:SetHeight(13)
    row.bell:SetPoint("RIGHT", row, "RIGHT", -3, 0)
    row.bell:SetTexture("Interface\\Icons\\INV_Misc_Bell_01")
    row.bell:Hide()

    row:SetScript("OnClick", function()
      local r = this.route
      if not r then return end
      if arg1 == "RightButton" then
        if r.flipFrom then
          if CFG.full then DB.flip[r.entry] = (not Flipped(r)) or nil
          else manualFlip[r.entry] = (not manualFlip[r.entry]) or nil end
          local f = this:GetScript("OnEnter")
          if f and MouseIsOver and MouseIsOver(this) then GameTooltip:Hide(); f() end
        end
        return
      end
      DB.bell[r.entry] = (not Watched(r)) or nil
      if Watched(r) then this.bell:Show() else this.bell:Hide() end
    end)
    row:SetScript("OnEnter", function()
      local r = this.route
      if not r then return end
      GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
      GameTooltip:AddLine(ShownName(r) .. " " .. r.kind, 1, 1, 1)
      GameTooltip:AddLine((Period(r) and ("Cycle " .. string.format("%.1f", Period(r)) .. "s, ") or "Cycle not measured, ") .. "stays " .. string.format("%.0f", Dwell(r)) .. "s   (object " .. r.entry .. ")", 0.7, 0.7, 0.7)
      if DB.origin[r.entry] and DB.anchor[r.entry] then
        local span = DB.anchor[r.entry] - DB.origin[r.entry]
        if span > 60 then
          GameTooltip:AddLine("Cycle measured over " .. (span >= 86400 and string.format("%.1f days", span / 86400) or string.format("%.0f min", span / 60)) .. " of observations.", 0.7, 0.7, 0.7)
        end
      end
      if Flipped(r) then
        GameTooltip:AddLine("Times are for " .. Away(r) .. ": when it docks there and leaves for " .. r.flipTo .. ".", 0.7, 0.7, 0.7)
        if FarKnown(r) then
          GameTooltip:AddLine(Away(r) .. " end measured on a ride: docks there " .. string.format("%.0f", FarOff(r, Period(r))) .. "s into the cycle, stays " .. string.format("%.0f", FarDwell(r)) .. "s.", 0.7, 0.7, 0.7)
        else
          GameTooltip:AddLine(Away(r) .. " end not measured: assumed to dock halfway through the cycle, so treat it as rough. Ride it once (window open) to measure it.", 1, 0.6, 0.2)
        end
        GameTooltip:AddLine("Click: " .. (Watched(r) and "remove the bell (no chat alert)" or "add a bell: chat message " .. CFG.alert .. "s before it arrives at " .. Away(r)), 0.2, 1, 0.8)
      elseif r.far then
        local lo = DB.lastObs[r.entry] or DB.anchor[r.entry] or r.anchor
        if r.periodGuess and not DB.period[r.entry] then
          GameTooltip:AddLine("Cycle is a rough estimate until the boat is seen docking at Ratchet once more.", 1, 0.6, 0.2)
        end
        GameTooltip:AddLine("fly = when to leave Orgrimmar, sails = when it leaves the Ratchet dock.", 0.7, 0.7, 0.7)
        GameTooltip:AddLine("Travel time to the dock: " .. CFG.travel .. "s (/ob travel <sec>).", 0.7, 0.7, 0.7)
        if lo then
          GameTooltip:AddLine("Last seen at Ratchet " .. FormatSpan(time() - lo) .. " ago. Always an estimate from Orgrimmar.", 0.7, 0.7, 0.7)
        else
          GameTooltip:AddLine("Not measured yet: ride it with /ob debug on.", 1, 0.6, 0.2)
        end
        GameTooltip:AddLine("Click: " .. (Watched(r) and "remove the bell (no chat alert)" or "add a bell: chat message " .. CFG.alert .. "s before you need to fly"), 0.2, 1, 0.8)
      else
      local e = r.entry
      local how
      if Stale(r) then how = "Not seen since the server restarted (?)."
      elseif DB.corrected[e] then how = "Corrected from the server restart time, not seen since (~)."
      elseif not DB.seenAt[e] then how = "Never seen: built-in estimate (~)."
      else how = "Seen since the server restarted" .. (confirmed[e] == "far" and (", synced at " .. Away(r)) or "") ..
        ", " .. FormatSpan(time() - DB.seenAt[e]) .. " ago: accurate." end
      GameTooltip:AddLine(how, 0.7, 0.7, 0.7)
      GameTooltip:AddLine("Click: " .. (Watched(r) and "remove the bell (no chat alert)" or "add a bell: chat message " .. CFG.alert .. "s before it arrives"), 0.2, 1, 0.8)
      end
      if Stale(r) then
        GameTooltip:AddLine("The server restarted " .. FormatSpan(time() - DB.restartAt) .. " ago (" ..
          (DB.restartRoute == "server uptime" and "from the server uptime" or ("noticed at " .. tostring(DB.restartRoute))) ..
          "). Not seen since, so this time may be off by up to 3 min.", 1, 0.67, 0.2, 1)
      end
      if r.flipFrom then
        GameTooltip:AddLine("Right-click: reverse to " .. (Flipped(r) and RouteName(r) or FlipName(r)), 0.2, 1, 0.8)
      end
      GameTooltip:Show()
    end)
    row:SetScript("OnLeave", function() GameTooltip:Hide() end)
    PlaceRow(row, i)
    rows[i] = row
    return row
  end

  -- Appearance (set from the settings window, /ob options): background opacity, window
  -- opacity and text size. Text size scales the fonts and the row height and width with them.
  local function ApplyLook()
    -- window opacity fades everything but the text, which has its own opacity
    local wa = CFG.alpha or 1
    local bg = CFG.bgAlpha or 0.75
    panel:SetAlpha(1)
    panel:SetBackdropColor(0.02, 0.02, 0.02, bg * wa)
    panel:SetBackdropBorderColor(0.22, 0.22, 0.22, math.min(1, bg + 0.25) * wa)
    grip:SetAlpha(wa)
    textScale = CFG.textScale or 1
    WIDTH = math.floor(280 * textScale * (CFG.widthScale or 1) + 0.5)
    ROW_H = math.floor(18 * textScale + 0.5)
    TOP = math.floor(22 * textScale + 0.5)
    panel:SetWidth(WIDTH)
    StyleText(panel.title, math.floor(10 * textScale + 0.5))
    StyleText(panel.status, math.floor(9 * textScale + 0.5))
    StyleText(panel.foot, math.floor(9 * textScale + 0.5))
    for i = 1, table.getn(rows) do PlaceRow(rows[i], i) end
    local ta = CFG.textAlpha or 1
    panel.title:SetAlpha(ta)
    panel.status:SetAlpha(ta)
    panel.foot:SetAlpha(ta)
  end
  ApplyLook()

  -- returns state ("docked" / "wait" / nil), seconds (may be nil if unknown)
  local function Status(r)
    if Flipped(r) then return Predict(r, true) end
    local ps, psecs = Predict(r)
    local live = seenState[r.entry]
    if live then
      if live.atDock then
        if ps == "docked" then return "docked", psecs end
        -- Still at the dock after its scheduled departure: it is about to pull away.
        return "departing", nil
      else
        if ps == "wait" then return "wait", psecs end
        return "wait", nil
      end
    end
    return ps, psecs
  end

  -- far routes (Ratchet): seconds until the next sailing you can still make, and until
  -- you have to leave. Sailing = departure from the dock.
  local function FlyBy(r)
    local state, secs = Predict(r)
    if not state then return nil end
    local sail = secs
    if state == "wait" then sail = secs + Dwell(r) end
    -- Once the time to fly has passed, keep showing "fly now" for 10 s (about the
    -- slack in the travel time) instead of jumping straight to the next sailing. After
    -- that this boat can no longer be made, so move on to the next one.
    local fly = sail - CFG.travel
    if fly < -10 then
      sail = sail + Period(r)
      fly = sail - CFG.travel
    end
    return fly, sail
  end

  local function RowText(r)
    if r.far and not seenState[r.entry] and not Flipped(r) and not AtHome(r) then
      local fly, sail = FlyBy(r)
      if not fly then return RowName(r), nil, nil, "|cff888888not measured yet|r" end
      local mark = Mark(r)
      if fly <= 0 then
        return RowName(r), "fly", 0, mark .. "|cffff5555fly now|r |cff777777sails " .. FormatTime(sail) .. "|r"
      end
      local color = "|cffffffff"
      if CFG.alert > 0 and fly <= CFG.alert then color = "|cffffaa33" end
      return RowName(r), "fly", fly, mark .. "|cffaaaaaafly|r " .. color .. FormatTime(fly) ..
        "|r |cff777777sails " .. FormatTime(sail) .. "|r"
    end
    local state, secs = Status(r)
    local est = Mark(r)
    local nm = RowName(r)
    if state == "docked" then
      if secs then
        return nm, state, secs, est .. "|cff55ff55leaves|r |cffffffff" .. FormatTime(secs) .. "|r"
      end
      return nm, state, nil, "|cff55ff55here now|r"
    elseif state == "departing" then
      return nm, state, nil, "|cffffd200departing|r"
    elseif state == "wait" then
      if secs then
        local color = "|cffffffff"
        if CFG.alert > 0 and secs <= CFG.alert then color = "|cffffaa33" end
        return nm, state, secs, est .. "|cffaaaaaadocks|r " .. color .. FormatTime(secs) .. "|r"
      end
      return nm, state, nil, "|cffaaaaaaarriving...|r"
    end
    return nm, state, nil, "|cff888888--|r"
  end

  -- Rows are sorted by what happens soonest: the next arrival, departure or time to fly.
  local function Refresh()
    local list = {}
    for i = 1, table.getn(ROUTES) do
      local r = ROUTES[i]
      if Visible(r) then
        local _, state, secs, txt = RowText(r)
        local key = secs or 100000
        if state == "departing" or (state == "fly" and secs <= 0) then key = 0 end
        table.insert(list, { r = r, state = state, secs = secs, txt = txt, key = key, i = i })
      end
    end
    table.sort(list, function(x, y)
      if x.key ~= y.key then return x.key < y.key end
      return x.i < y.i
    end)
    local n = 0
    for k = 1, table.getn(list) do
      local e = list[k]
      local r, state, secs, txt = e.r, e.state, e.secs, e.txt
      do
        n = n + 1
        local row = rows[n] or CreateRow(n)
        row:Show()
        row.route = r
        local nm = ColoredName(r)
        if cal and cal.need[r.entry] then
          if (cal.got[r.entry] or 0) >= cal.need[r.entry] then
            nm = "|cff55ff55+|r " .. nm
          else
            nm = "|cffffaa33-|r " .. nm
          end
        end
        row.name:SetText(nm)
        row.time:SetText(txt)
        if Watched(r) then row.bell:Show() else row.bell:Hide() end
        if state == "docked" then
          row.icon:SetTexture(ICON_HERE)
          row.icon:SetVertexColor(0.3, 1, 0.3)
          row.bg:SetVertexColor(0.1, 0.5, 0.1, 0.35)
        elseif state == "departing" then
          row.icon:SetTexture(ICON_HERE)
          row.icon:SetVertexColor(1, 0.82, 0)
          row.bg:SetVertexColor(0.5, 0.4, 0, 0.3)
        else
          row.icon:SetTexture(ICON_AWAY)
          if secs and CFG.alert > 0 and secs <= CFG.alert then
            row.icon:SetVertexColor(1, 0.7, 0.2)
          else
            row.icon:SetVertexColor(0.6, 0.6, 0.6)
          end
          row.bg:SetVertexColor(0, 0, 0, 0)
        end
      end
    end
    for i = n + 1, table.getn(rows) do rows[i]:Hide() end
    -- width: the chosen width, but never so narrow that a name runs into its time
    local need = 0
    for i = 1, n do
      local w = (rows[i].name:GetStringWidth() or 0) + (rows[i].time:GetStringWidth() or 0)
      if w > need then need = w end
    end
    need = math.floor(need + 4 + 2 + 14 + 4 + 20 + 12 * textScale + 4)
    panel:SetWidth(need > WIDTH and need or WIDTH)
    panel:SetHeight(TOP + n * ROW_H + ((cal or (panel.foot:GetText() or "") ~= "") and math.floor(18 * textScale + 0.5) or 10))
    panel.title:SetText("|cff33ffccTransports|r" .. (CFG.full and " |cff777777- all|r" or ""))
    if recOn then
      panel.status:SetText("|cffff4444REC|r " .. (type(DB.rec) == "table" and table.getn(DB.rec) or 0))
    else
      panel.status:SetText("")
    end
    if cal then
      local d, t = CalCount()
      local inView = 0
      for i = 1, table.getn(ROUTES) do
        if seenState[ROUTES[i].entry] then inView = inView + 1 end
      end
      if inView > 0 then cal.seenAny = true end
      if inView > 0 then
        panel.foot:SetText("|cffffaa33calibrating " .. d .. "/" .. t .. ": " .. inView .. " in view, stay put|r")
      elseif (not cal.seenAny) and (GetTime() - cal.t0) > 600 then
        -- transports are out of range for part of every cycle, so "none in view" alone
        -- means nothing; only after 10 minutes without a single sighting is it a hint
        panel.foot:SetText("|cffff5555calibrating " .. d .. "/" .. t .. ": nothing seen in 10 min, move closer to the towers|r")
      else
        panel.foot:SetText("|cffffaa33calibrating " .. d .. "/" .. t .. ": waiting for arrivals|r")
      end
    else
      -- the footer only appears after a server restart, while a shown route is unseen since
      local txt = ""
      for i = 1, table.getn(ROUTES) do
        if Visible(ROUTES[i]) and Stale(ROUTES[i]) then
          txt = "|cffffaa33server restarted " .. FormatSpan(time() - DB.restartAt) .. " ago: ? = not seen since|r"
          break
        end
      end
      panel.foot:SetText(txt)
    end
  end

  local function PlacePanel()
    panel:ClearAllPoints()
    if CFG.pos then
      panel:SetPoint(CFG.pos.a or "BOTTOMLEFT", UIParent, "BOTTOMLEFT", CFG.pos.x, CFG.pos.y)
    else
      panel:SetPoint("TOPRIGHT", anchorTo, "BOTTOMRIGHT", 0, -8)
    end
  end

  -- Auto-show: in any zone or sub-zone at either end of a route (or a planning place),
  -- in a place added with /ob allow, or while a tracked transport is in view.
  local function InOrg()
    UpdateLoc()
    if not CFG.zoneOnly then return true end
    local z, sz = LOC.z, LOC.sz
    for i = 1, table.getn(CFG.allow) do
      local a = Norm(CFG.allow[i])
      if a ~= "" and (z == a or sz == a) then return true end
    end
    for i = 1, table.getn(ROUTES) do
      local r = ROUTES[i]
      if InListAt(r.homeZ, z, sz) or InListAt(r.awayZ, z, sz) or InListAt(r.planZ, z, sz) or seenState[r.entry] then return true end
    end
    return false
  end

  -- override: nil = automatic, "show" = forced open anywhere, "hide" = forced closed.
  -- Crossing into or out of the auto-show area puts it back to automatic.
  local override = nil
  local lastArea = nil

  local function ApplyVisibility()
    local area = InOrg()
    if area ~= lastArea then
      lastArea = area
      override = nil
    end
    local want
    if override == "show" then want = true
    elseif override == "hide" then want = false
    else want = area end
    if want then
      if not panel:IsShown() then
        PlacePanel()
        Refresh()
        panel:Show()
      end
      btn.icon:SetVertexColor(1, 1, 1)
    else
      if panel:IsShown() then panel:Hide() end
      btn.icon:SetVertexColor(0.55, 0.55, 0.55)
    end
  end

  local function ToggleShown()
    if panel:IsShown() then override = "hide" else override = "show" end
    ApplyVisibility()
  end

  btn:SetScript("OnClick", function()
    if arg1 == "RightButton" then OctoBus_Options() else ToggleShown() end
  end)
  btn:SetScript("OnEnter", function()
    GameTooltip:SetOwner(this, "ANCHOR_LEFT")
    GameTooltip:AddLine("Transports", 0.2, 1, 0.8)
    GameTooltip:AddLine("Click: " .. (panel:IsShown() and "hide" or "show") .. " the window (works anywhere)", 1, 1, 1)
    GameTooltip:AddLine("Right-click: settings", 1, 1, 1)
    GameTooltip:AddLine("Opens by itself at either end of any route.", 0.7, 0.7, 0.7)
    GameTooltip:AddLine("Drag: move this icon around the minimap", 0.7, 0.7, 0.7)
    GameTooltip:Show()
  end)
  btn:SetScript("OnLeave", function() GameTooltip:Hide() end)

  ------------------------------------------------------------------------
  -- Update loop
  ------------------------------------------------------------------------
  local alerted = {}
  local flashUntil = 0
  local pollT, uiT = 0, 0

  local function RunAlerts()
        for i = 1, table.getn(ROUTES) do
      local r = ROUTES[i]
      if Visible(r) and r.far and not Flipped(r) then
        local fly = FlyBy(r)
        if fly and Watched(r) and CFG.alert > 0 and fly <= CFG.alert then
          local stamp = math.floor(EpochNow() + fly + 0.5)
          if alerted[r.entry] ~= stamp then
            alerted[r.entry] = stamp
            if CFG.chat then Say(RouteName(r) .. (fly <= 0 and ": fly to Ratchet now." or (": fly to Ratchet in " .. FormatTime(fly) .. "."))) end
            if CFG.sound then PlaySound("RaidWarning") end
            if CFG.flash then flashUntil = GetTime() + 8 end
          end
        end
      elseif Visible(r) then
        local state, secs = Status(r)
        if state == "wait" and secs then
          if Watched(r) then
            if CFG.alert > 0 and secs <= CFG.alert then
              local stamp = math.floor(EpochNow() + secs + 0.5)
              if alerted[r.entry] ~= stamp then
                alerted[r.entry] = stamp
                if CFG.chat then
                  Say(ShownName(r) .. ": docks at " .. StartName(r) .. " in " .. FormatTime(secs) .. ".")
                end
                if CFG.sound then PlaySound("RaidWarning") end
                if CFG.flash then flashUntil = GetTime() + 8 end
              end
            end
          end
        end
      end
    end
  end

  local driver = CreateFrame("Frame")
  driver:SetScript("OnUpdate", function()
    local now = GetTime()
    if now < flashUntil then
      btn:SetAlpha(0.55 + 0.45 * math.abs(math.sin(now * 5)))
    else
      btn:SetAlpha(1)
    end
    EpochNow()
    if cal and (now - cal.t0) > 1500 then CalFinish(false) end
    pollT = pollT + arg1
    if pollT >= ((cal or recOn) and 0.1 or 0.5) then
      pollT = 0
      Poll()
    end
    uiT = uiT + arg1
    if uiT >= 0.25 then
      uiT = 0
      ApplyVisibility()
      RunAlerts()
      if panel:IsShown() then Refresh() end
    end
  end)

  ApplyVisibility()

  ------------------------------------------------------------------------
  -- Slash commands
  ------------------------------------------------------------------------
  local function Words(msg)
    local t = {}
    for w in gfind(msg or "", "%S+") do table.insert(t, w) end
    return t
  end

  local function Toggle(name, key)
    CFG[key] = not CFG[key]
    Say(name .. " " .. (CFG[key] and "on" or "off") .. ".")
  end

  local function NthRoute(n)
    n = tonumber(n)
    if not n then return nil end
    local c = 0
    for i = 1, table.getn(ROUTES) do
      c = c + 1
      if c == n then return ROUTES[i] end
    end
    return nil
  end

  SlashCmdList["OCTOBUS"] = function(msg)
    msg = msg or ""
    local w = Words(msg)
    local cmd = string.lower(w[1] or "")

    if cmd == "" then
      ToggleShown()

    elseif cmd == "list" then
      for i = 1, table.getn(ROUTES) do
        local r = ROUTES[i]
        local a, _, _, b = RowText(r)
        Say(i .. ". " .. a .. "   " .. b .. (Period(r) and ("   (cycle " .. string.format("%.1f", Period(r)) .. "s)") or ""))
      end

    elseif cmd == "alert" then
      local s = tonumber(w[2])
      if s and s >= 0 then
        CFG.alert = s
        Say("alerts " .. (s == 0 and "off" or (s .. " seconds before arrival")) .. ".")
      else
        Say("usage: /ob alert <seconds>   (0 = off)")
      end

    elseif cmd == "sound" then Toggle("sound alert", "sound")
    elseif cmd == "chat"  then Toggle("chat alert", "chat")
    elseif cmd == "flash" then Toggle("minimap icon flash", "flash")
    elseif cmd == "zone"  then Toggle("auto-show only at route ends (off = always show)", "zoneOnly")
    elseif cmd == "where" then
      Say("zone: \"" .. (GetZoneText() or "") .. "\"  sub-zone: \"" .. (GetSubZoneText() or "") .. "\"  auto-shows here: " .. tostring(InOrg()))
    elseif cmd == "allow" then
      local nm = ""
      for i = 2, table.getn(w) do nm = nm .. (i > 2 and " " or "") .. w[i] end
      if nm == "" then
        Say("usage: /ob allow <zone or sub-zone name>   (see /ob where). Current extras: " .. table.concat(CFG.allow, ", "))
      else
        nm = string.gsub(string.gsub(string.gsub(nm, "[\"']", ""), "^%s+", ""), "%s+$", "")
        local dup = false
        for i = 1, table.getn(CFG.allow) do
          if Norm(CFG.allow[i]) == Norm(nm) then dup = true end
        end
        if dup then
          Say("\"" .. nm .. "\" is already on the list.")
        else
          table.insert(CFG.allow, nm)
          Say("added \"" .. nm .. "\" to the places where the window opens by itself.")
        end
      end
    elseif cmd == "disallow" then
      local nm = ""
      for i = 2, table.getn(w) do nm = nm .. (i > 2 and " " or "") .. w[i] end
      local keep, gone = {}, 0
      for i = 1, table.getn(CFG.allow) do
        if Norm(CFG.allow[i]) == Norm(nm) then gone = gone + 1 else table.insert(keep, CFG.allow[i]) end
      end
      CFG.allow = keep
      if gone > 0 then
        Say("removed \"" .. nm .. "\". Still on the list: " .. (table.getn(keep) > 0 and table.concat(keep, ", ") or "nothing"))
      else
        Say("\"" .. nm .. "\" is not on the list. On the list: " .. (table.getn(keep) > 0 and table.concat(keep, ", ") or "nothing"))
      end

    elseif cmd == "allowclear" then
      CFG.allow = {}
      Say("extra places cleared (route ends still open the window).")
    elseif cmd == "shape" then
      local v = string.lower(w[2] or "")
      if v == "square" or v == "round" then
        CFG.shape = v
      elseif v == "auto" then
        CFG.shape = nil
      else
        Say("usage: /ob shape square|round|auto   (now: " .. (CFG.shape or "auto") .. ", looks " .. (MinimapIsSquare() and "square" or "round") .. ")")
        return
      end
      PlaceButton()
      Say("minimap icon placement: " .. (CFG.shape or "auto") .. ".")
    elseif cmd == "all" then
      CFG.full = not CFG.full
      Say(CFG.full and "showing all routes." or "showing routes for where you are.")
    elseif cmd == "boat"  then
      CFG.hideBoat = not CFG.hideBoat
      Say("Sparkwater Port boat " .. (CFG.hideBoat and "hidden" or "shown") .. ".")
    elseif cmd == "options" or cmd == "config" or cmd == "settings" then
      OctoBus_Options()

    elseif cmd == "lock" then
      Toggle("window locked", "locked")
      if CFG.locked then grip:Hide() else grip:Show() end
    elseif cmd == "scale" then
      local v = tonumber(w[2])
      if v then
        ApplyScale(v)
        Say("window scale " .. string.format("%.2f", CFG.scale) .. ".")
      else
        Say("usage: /ob scale <0.6 to 2>   (now " .. string.format("%.2f", CFG.scale or 1) .. "; or drag the dots in the bottom-right corner)")
      end
    elseif cmd == "resetpos" then
      CFG.pos = nil
      CFG.scale = nil
      panel:SetScale(1)
      CFG.angle = nil
      PlaceButton()
      override = nil
      panel:Hide()
      ApplyVisibility()
      Say("window and minimap icon moved back to their default spots, auto mode restored.")

    elseif cmd == "name" then
      local r = NthRoute(w[2])
      local text = ""
      for i = 3, table.getn(w) do text = text .. (i > 3 and " " or "") .. w[i] end
      if r and text ~= "" then
        DB.names[r.entry] = text
        Say("route " .. w[2] .. " is now called: " .. RouteName(r))
      else
        Say("usage: /ob name <number from /ob list> <new place name>   (renames the far end; the home end stays)")
      end

    elseif cmd == "period" then
      local r = NthRoute(w[2])
      local s = tonumber(w[3])
      if r and s and s > 30 then
        DB.period[r.entry] = s
        Say(RouteName(r) .. ": cycle set to " .. s .. "s.")
      else
        Say("usage: /ob period <number from /ob list> <seconds>")
      end

    elseif cmd == "calibrate" or cmd == "cal" then
      if w[2] == "stop" or w[2] == "cancel" then
        if cal then CalFinish(false) else Say("not calibrating.") end
      elseif not dllOk then
        Say("calibration needs ZepSense.dll answering (see /ob debug).")
      else
        local n = CalStart()
        override = "show"
        ApplyVisibility()
        Say("calibrating " .. n .. " transports. Stand where you can see the docks (between the two towers), do not /reload, and wait.")
        Say("each transport needs " .. "1 fresh arrival (2 the first time). Rows turn + when done. /ob calibrate stop cancels.")
        local seen = 0
        for i = 1, table.getn(ROUTES) do
          if seenState[ROUTES[i].entry] then seen = seen + 1 end
        end
        if seen == 0 then
          Say("none of them are in view this second. That is normal: each transport is out of range for part of its trip. If the footer still says nothing has been seen after about 10 minutes, move closer to the towers.")
        end
      end

    elseif cmd == "reset" then
      DB.anchor = {}
      DB.period = {}
      DB.origin = {}
      DB.dwell = {}
      DB.farOff = {}
      DB.farDwell = {}
      DB.lastCal = nil
      DB.lastObs = {}
      DB.pending = {}
      DB.seenAt = {}
      DB.restartAt = nil
      DB.restartRoute = nil
      DB.boot = nil
      DB.bootPhase = {}
      DB.bootPhaseBoot = {}
      DB.bootTheory = nil
      DB.corrected = {}
      DB.pW0 = {}
      DB.pP0 = {}
      DB.pK = {}
      cal = nil
      confirmed = {}
      seenState = {}
      Say("learned data cleared; using built-in values until each zeppelin is seen again.")

    elseif cmd == "travel" then
      local s = tonumber(w[2])
      if s and s >= 0 then
        CFG.travel = s
        Say("travel time from Orgrimmar to the Ratchet dock: " .. s .. "s.")
      else
        Say("usage: /ob travel <seconds>   (now " .. CFG.travel .. "s)")
      end

    elseif cmd == "debug" and (string.lower(w[2] or "") == "on" or string.lower(w[2] or "") == "off") then
      if string.lower(w[2]) == "on" then
        DB.rec = {}
        recLast = {}
        recZone, recTaxi = nil, nil
        recOn = true
        override = "show"
        ApplyVisibility()
        Say("recording every transport the DLL reports. /ob debug off to stop; log out or /reload to save it.")
      else
        recOn = false
        local n = type(DB.rec) == "table" and table.getn(DB.rec) or 0
        Say("recording stopped: " .. n .. " lines. Log out or /reload to write them to the saved file.")
      end

    elseif cmd == "debug" then
      Say("DLL function present: " .. tostring(type(ZepTransports) == "function") ..
        ", answering: " .. tostring(dllOk))
      if type(ZepTransports) == "function" then
        local ok, str = pcall(ZepTransports)
        str = tostring(str)
        Say("raw (" .. string.len(str) .. " chars): " .. string.sub(str, 1, 180))
      end
      if recOn then Say("recording: on, " .. table.getn(DB.rec) .. " lines so far.") end

    else
      Say("/ob (window on/off)  |  options  |  list  |  alert <s>  |  all|sound|chat|flash|zone|boat|lock  |  scale <n>  |  where  |  shape <square|round|auto>  |  allow|disallow <name>  |  resetpos  |  name <n> <text>  |  period <n> <s>  |  travel <s>  |  calibrate  |  reset  |  debug [on|off]")
    end
  end

  -- This file runs before the game loads the saved settings, so everything set up above
  -- used the defaults. Once they are loaded, apply them: size, look, lock, icon and
  -- window position.
  do
    local f = CreateFrame("Frame")
    f:RegisterEvent("VARIABLES_LOADED")
    f:SetScript("OnEvent", function()
      Repair134()
      Repair136()
      DB.rec = nil   -- an old /ob debug recording is not kept between sessions (it can be large)
      panel:SetScale(CFG.scale or 1)
      ApplyLook()
      if CFG.locked then grip:Hide() else grip:Show() end
      PlaceButton()
      PlacePanel()
    end)
  end

  ------------------------------------------------------------------------
  -- Shared sightings. Every OctoBus joins a hidden chat channel. A copy with the DLL
  -- posts the docking times it has seen in this server run; copies without it take them
  -- and are exact too, instead of relying on the restart offsets (which shift by seconds
  -- or minutes at each restart). Times are sent as seconds since the server restart, so
  -- differences between players' PC clocks do not matter. Nothing shows in chat.
  -- Message: "OB1 S <entry>:<seconds since restart> ..." (sightings), "OB1 R" (request).
  ------------------------------------------------------------------------
  do
    local CHANNEL = "OctoBusSync"
    local byEntry = {}
    for i = 1, table.getn(ROUTES) do byEntry[ROUTES[i].entry] = ROUTES[i] end
    local lastSent, replyAt, joinAt, asked = 0, nil, nil, false

    local function ChannelId()
      local id = GetChannelName(CHANNEL)
      if id and id > 0 then return id end
      return nil
    end
    local function IsOurs(name)
      return name and string.find(string.lower(name), string.lower(CHANNEL), 1, true) ~= nil
    end

    -- this run's docking times, as seconds since the restart; own = only DLL sightings
    local function Payload(own)
      if not DB.boot then return nil end
      local parts = {}
      for i = 1, table.getn(ROUTES) do
        local e = ROUTES[i].entry
        local a = DB.anchor[e]
        if a and a > DB.boot and (DB.seenAt[e] or 0) > DB.boot + 5 and (DB.src[e] == "dll" or (not own and DB.src[e] == "shared")) then
          table.insert(parts, e .. ":" .. string.format("%.1f", a - DB.boot))
        end
      end
      if table.getn(parts) == 0 then return nil end
      return "OB1 S " .. table.concat(parts, " ")
    end

    local function Send(msg)
      local id = ChannelId()
      if id and msg and CFG.share then SendChatMessage(msg, "CHANNEL", nil, id) end
    end

    -- own sighting: post at most once a minute
    ShareSighting = function()
      if GetTime() - lastSent < 60 then return end
      local msg = Payload(true)
      if msg then lastSent = GetTime() Send(msg) end
    end

    local function Take(e, rel)
      local r = byEntry[e]
      if not r or not DB.boot or not CFG.share then return end
      if rel < 0 or rel > time() - DB.boot + 600 then return end
      -- our own DLL sighting in this run wins
      if DB.src[e] == "dll" and (DB.seenAt[e] or 0) > DB.boot + 5 then return end
      -- a time that is just the restart offset again is someone's guess passed on as a
      -- sighting (OctoBus 1.3.5 did that): ignore it
      local c = DB.bootPhaseBoot[e] ~= DB.boot and Phase(r)
      if c and math.abs(rel - c) < 2 then return end
      local a = DB.boot + rel
      if DB.src[e] == "shared" and DB.anchor[e] and math.abs(DB.anchor[e] - a) < 0.5 then return end
      local P = Period(r)
      DB.anchor[e] = a
      if not DB.origin[e] or DB.origin[e] < DB.boot then
        DB.pW0[e] = (DB.pW0[e] or 700) + (DB.pK[e] or 0)
        DB.pP0[e] = P
        DB.pK[e] = 0
        DB.origin[e] = a
        DB.pending[e] = nil
        DB.lastObs[e] = nil
      end
      DB.seenAt[e] = time()
      DB.corrected[e] = nil
      DB.src[e] = "shared"
    end

    local f = CreateFrame("Frame")
    f:RegisterEvent("PLAYER_ENTERING_WORLD")
    f:RegisterEvent("CHAT_MSG_CHANNEL")
    f:SetScript("OnEvent", function()
      if event == "PLAYER_ENTERING_WORLD" then
        if not joinAt and not ChannelId() then joinAt = GetTime() + 8 end
        return
      end
      if not IsOurs(arg9) and not IsOurs(arg4) then return end
      if arg2 == UnitName("player") then return end
      local msg = arg1 or ""
      if string.sub(msg, 1, 6) == "OB1 S " then
        for e, rel in gfind(msg, "(%d+):([%d%.]+)") do Take(tonumber(e), tonumber(rel)) end
        replyAt = nil   -- someone else answered
      elseif msg == "OB1 R" then
        if Payload(false) then replyAt = GetTime() + 2 + math.random() * 6 end
      end
    end)
    f:SetScript("OnUpdate", function()
      local now = GetTime()
      if joinAt and now >= joinAt then
        joinAt = nil
        if CFG.share then JoinChannelByName(CHANNEL) end
        for i = 1, (NUM_CHAT_WINDOWS or 7) do
          local cf = getglobal("ChatFrame" .. i)
          if cf and ChatFrame_RemoveChannel then pcall(ChatFrame_RemoveChannel, cf, CHANNEL) end
        end
      end
      -- once the restart time is known, ask for this run's sightings
      if not asked and DB.boot and ChannelId() then
        asked = true
        Send("OB1 R")
      end
      if replyAt and now >= replyAt then
        replyAt = nil
        Send(Payload(false))
      end
      -- copies with the DLL repeat what they have seen every 5 minutes
      if dllOk and now - lastSent > 300 then
        local msg = Payload(true)
        if msg then lastSent = now Send(msg) end
      end
    end)

    -- keep the channel and its join / leave notices out of every chat window
    local prevChat = ChatFrame_OnEvent
    ChatFrame_OnEvent = function(ev)
      if (ev == "CHAT_MSG_CHANNEL" or ev == "CHAT_MSG_CHANNEL_NOTICE" or ev == "CHAT_MSG_CHANNEL_JOIN" or ev == "CHAT_MSG_CHANNEL_LEAVE")
          and (IsOurs(arg9) or IsOurs(arg4)) then
        return
      end
      return prevChat(ev)
    end
  end

  -- for the settings window (OctoBusOptions.lua)
  OctoBus = {
    cfg = CFG,
    ApplyLook = function() ApplyLook() Refresh() end,
    Refresh = function() Refresh() end,
    Show = function() override = "show" ApplyVisibility() end,
    SetAnchor = function(a)
      CFG.anchor = a
      if panel:GetLeft() then SavePos() end   -- keeps the window where it is, pinned by the new corner
    end,
    SetScale = function(v) ApplyScale(v) end,
    scaleMin = SCALE_MIN,
    scaleMax = SCALE_MAX,
    SetLocked = function(v)
      CFG.locked = v and true or false
      if CFG.locked then grip:Hide() else grip:Show() end
    end,
  }

end)
if not OB_OK then
  OB_STAGE = "start-up error: " .. tostring(OB_ERR)
  DEFAULT_CHAT_FRAME:AddMessage("|cff33ffccOctoBus:|r |cffff5555" .. OB_STAGE .. "|r")
end
