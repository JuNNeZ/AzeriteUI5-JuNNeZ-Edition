-- Exercise the real XP sampler, tooltip rows and Forever flight state machine.
local root = arg[1] or "."
local checks, failures = 0, 0
local function check(ok, label)
	checks = checks + 1
	if (not ok) then
		failures = failures + 1
		print("FAIL: "..label)
	end
end

local modules, timers, hooks = {}, {}, {}
local minimap = { db = { profile = { showXPStats = false } } }
modules.Minimap = minimap
local locale = setmetatable({}, { __index = function(_, key) return key end })
local secret = {}
local now, level, xp, maximum, onTaxi = 0, 12, 950, 1000, false
local ns = {
	IsForever = true,
	Colors = {},
	API = { AbbreviateNumber = tostring, GetEffectiveScale = function() return 1 end },
	MovableModulePrototype = { defaults = {} },
	Merge = function(_, defaults) return defaults end,
	GetModule = function(_, name) return modules[name] end
}
function ns:NewModule(name)
	local module = { events = {} }
	modules[name] = module
	function module:IsEnabled() return true end
	function module:RegisterEvent(event, method) self.events[event] = method end
	function module:UnregisterEvent(event) self.events[event] = nil end
	return module
end
local env = setmetatable({
	LibStub = function()
		return { GetLocale = function() return locale end }
	end,
	GetTime = function() return now end,
	UnitLevel = function() return level end,
	UnitXP = function() return xp end,
	UnitXPMax = function() return maximum end,
	issecretvalue = function(value) return value == secret end,
	C_Timer = { After = function(_, callback) timers[#timers + 1] = callback end },
	SecondsToTime = function(seconds) return tostring(seconds) end,
	SecondsToClock = function(seconds) return ("%d:%02d"):format(math.floor(seconds / 60), seconds % 60) end,
	GetCurrentRegionName = function() return "EU" end,
	TUTORIAL_TITLE30 = "Resting", FPS_ABBR = "fps", HOME = "Home", WORLD = "World",
	UnitOnTaxi = function() return onTaxi end,
	GetTaxiMapID = function() return 1411 end,
	Enum = { FlightPathState = { Current = 0, Reachable = 1, Unreachable = 2 } },
	C_TaxiMap = { GetAllTaxiNodes = function()
		return {
			{ nodeID = 24, state = 0 },
			{ nodeID = 25, state = 1, slotIndex = 3, name = "Crossroads" },
			{ nodeID = 26, state = 2, slotIndex = 4, name = "Unreachable" },
			{ nodeID = secret, state = 1, slotIndex = 5, name = "Unreadable" }
		}
	end },
	TakeTaxiNode = function() end,
	TaxiRequestEarlyLanding = function() end,
	hooksecurefunc = function(name, hook)
		assert(not hooks[name], "duplicate secure hook: "..name)
		hooks[name] = hook
	end
}, { __index = _G })
local function loadModule(path)
	local chunk = assert(loadfile(root.."/"..path))
	setfenv(chunk, env)
	chunk("AzeriteUI", ns)
end
loadModule("Components/ActionBars/Elements/StatusBars.lua")
loadModule("Components/Misc/Info.lua")

local bars = modules.PlayerStatusBars
local lines = {}
local tooltip = { AddDoubleLine = function(_, key, value) lines[key] = value end }
bars:UpdateXPStats()
check(not bars.xpStats, "XP statistics are opt-in")
minimap.db.profile.showXPStats = true
bars:UpdateXPStats()
check(bars.xpStats.gained == 0, "existing XP establishes the baseline")
now, xp = 30, 0
bars:UpdateXPStats()
check(bars.xpStats.xp == 950, "temporary XP rollover retains the previous baseline")
level, xp, maximum = 13, 100, 1300
bars:QueueXPStats()
bars:QueueXPStats()
check(#timers == 1, "XP and level events coalesce into one sample")
timers[1]()
check(bars.xpStats.gained == 150, "level-up includes the tail of the previous XP bar")
bars:AddXPStats(tooltip)
check(next(lines) == nil, "the tooltip waits at least one minute")
now = 60
bars:AddXPStats(tooltip)
check(lines["Session XP per hour"] == "9000" and lines["Estimated time to next level"] == "480",
	"tooltip shows measured XP per hour and estimated time")
xp = secret
bars:UpdateXPStats()
check(bars.xpStats.xp == 100, "unreadable XP leaves the last good sample intact")
minimap.db.profile = { showXPStats = true }
level, xp = 13, 140
bars:UpdateXPStats()
check(bars.xpStats.gained == 0 and bars.xpStats.xp == 140, "profile changes start a fresh measurement")
minimap.db.profile.showXPStats = false
bars:UpdateXPStats()
check(not bars.xpStats, "disabling the setting clears the measurement")

local info = modules.Info
info.db = info:GenerateDefaults()
info.flightText = {
	SetFormattedText = function(self, format, ...) self.text = format:format(...) end,
	Show = function(self) self.shown = true end,
	Hide = function(self) self.shown = false end
}
check(info.db.profile.showFlightTimer == false, "flight timer is off by default")
info:SyncFlightTimer()
check(not info.flightTimerActive and not next(hooks), "disabled timer registers no hooks")
info.db.profile.showFlightTimer = true
ns.IsForever = false
info:SyncFlightTimer()
check(not info.flightTimerActive, "Retail skips the Forever timer")
ns.IsForever = true
info:SyncFlightTimer()
check(info.events.TAXIMAP_OPENED == "ReadTaxiMap" and info.events.TAXIMAP_CLOSED == "NoteTaxiMapClosed",
	"Forever tracks the native map lifecycle")
local function Depart(at)
	now, onTaxi = at, false
	info:ReadTaxiMap()
	info:NoteTaxiMapClosed()
	hooks.TakeTaxiNode(4)
	hooks.TakeTaxiNode(5)
	check(not info.pendingFlight, "ignores unreachable and unreadable nodes")
	hooks.TakeTaxiNode(3)
	info:UpdateFlightTimer()
	check(not info.flightText.shown, "selection alone does not start the timer")
	now, onTaxi = at + 1, true
	info:UpdateFlightTimer()
end
Depart(100)
check(info.flightText.text == "0:00  Crossroads", "first flight displays elapsed time and destination")
now, onTaxi = 161, false
info:UpdateFlightTimer()
check(info.db.char.flightTimes["24:25"] == 60 and not info.flightText.shown, "landing saves the route and hides the timer")
Depart(200)
check(info.flightText.text == "~1:00 left  Crossroads", "same route uses its saved duration")
now, onTaxi = 211, secret
info:UpdateFlightTimer()
check(info.flight and info.flightText.shown, "unreadable taxi state does not finish a flight")
hooks.TaxiRequestEarlyLanding()
now, onTaxi = 221, false
info:UpdateFlightTimer()
check(info.db.char.flightTimes["24:25"] == 60, "early landing cannot overwrite the route duration")
now = 300
info:ReadTaxiMap()
hooks.TakeTaxiNode(3)
now = 310
info:UpdateFlightTimer()
check(not info.pendingFlight and not info.flightText.shown, "denied or expired selection cannot start a timer")
now, onTaxi = 400, true
info:UpdateFlightTimer()
check(info.flightText.text == "0:00  Flight", "joining a flight already in progress shows elapsed time without a route")
info.db.profile.showFlightTimer = false
info:SyncFlightTimer()
check(not next(info.events) and not info.flightText.shown and not info.flight,
	"disabling the timer releases events, flight state and display")
info.db.profile.showFlightTimer = true
info:SyncFlightTimer()
check(info.flightTimerActive, "re-enabling reuses the existing secure hooks")
print(("Travel QoL: %d checks, %d failures (offline only)"):format(checks, failures))
os.exit(failures == 0 and 0 or 1)
