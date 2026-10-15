-- Engine-eased bars, offline: the switch, the list of bars, /azsmooth, and snapping.
--
-- Part 1 loads the real Components/UnitFrames/UnitFrame.lua and checks CreateBar's
-- DisableSmoothing: a bar that asks to ease gets ExponentialEaseOut while its switch
-- ("bars" or "castbars") is on and Immediate when it is off, turning a switch off
-- finishes the easing (SetToTargetValue) and tells the bar, a bar that asked for
-- Immediate never eases, and /azsmooth flips, sets and reports both switches.
--
-- Part 2 loads the real Components/UnitFrames/Functions.lua and drives API.UpdateHealth
-- and API.UpdatePower: a plain update writes with the bar's smoothing, a forced one
-- (ForceUpdate, roster change, another unit) writes Immediate.
--
-- It cannot show what the easing looks like. lua Tools/Harness/smooth_bars_harness.lua .

local root = arg and arg[1] or "."

local checks, failures = 0, 0
local function check(value, label, detail)
	checks = checks + 1
	if (not value) then
		failures = failures + 1
		print("FAIL: " .. label .. (detail ~= nil and ("  (" .. tostring(detail) .. ")") or ""))
	end
end

local IMMEDIATE, EASED = 0, 1
_G.Enum = { StatusBarInterpolation = { Immediate = IMMEDIATE, ExponentialEaseOut = EASED } }
_G.issecretvalue = function() return false end

-- Anything not given below answers with a callable stub.
local Auto
local AutoMT = {
	__index = function(t, k) local v = Auto(); rawset(t, k, v); return v end,
	__call = function() return Auto() end
}
Auto = function() return setmetatable({}, AutoMT) end

-- Status bars that record what they are told.
local function NewBar()
	local bar = { writes = {}, snapped = 0, min = 0, max = 100, value = 0 }
	bar.SetValue = function(self, value, interpolation)
		self.value = value
		self.writes[#self.writes + 1] = interpolation
	end
	bar.GetValue = function(self) return self.value end
	bar.SetMinMaxValues = function(self, lo, hi, interpolation) self.min, self.max, self.rangeInterpolation = lo, hi, interpolation end
	bar.GetMinMaxValues = function(self) return self.min, self.max end
	bar.SetToTargetValue = function(self) self.snapped = self.snapped + 1 end
	bar.SetOrientation = function() end
	bar.SetReverseFill = function() end
	bar.GetStatusBarTexture = function() return nil end
	bar.GetOrientation = function() return "HORIZONTAL" end
	-- Only methods a real StatusBar has: an addon field such as DisableSmoothing or
	-- Display must read nil, as in the game, or the code under test takes the stub's.
	for _, name in ipairs({ "SetAlpha", "Show", "Hide", "SetParent", "SetAllPoints", "SetFrameLevel",
		"SetStatusBarTexture", "SetPoint", "SetSize", "ClearAllPoints", "SetScript", "HookScript" }) do
		bar[name] = function() end
	end
	bar.IsShown = function() return true end
	bar.GetFrameLevel = function() return 1 end
	bar.GetParent = function() return nil end
	bar.GetStatusBarColor = function() return 1, 1, 1 end
	return bar
end
_G.CreateFrame = function() return NewBar() end

--------------------------------------------------------------------------
-- Part 1: UnitFrame.lua
--------------------------------------------------------------------------
local metas, slash, printed = {}, {}, {}
local profile
local ns = setmetatable({}, AutoMT)
ns.oUF = setmetatable({ RegisterMetaFunction = function(_, name, fn) metas[name] = fn end }, AutoMT)
ns.API = setmetatable({ TryCall = function(fn, ...) return pcall(fn, ...) end }, AutoMT)
ns.Merge = function(_, target, source)
	for k, v in pairs(source or {}) do if (target[k] == nil) then target[k] = v end end
	return target
end
ns.MovableModulePrototype = { defaults = {} }
local modules = {}
ns.NewModule = function(_, name)
	local module = setmetatable({ GetName = function() return name end }, AutoMT)
	modules[name] = module
	return module
end
ns.GetModule = function(_, name) return modules[name] end
ns.db = { RegisterNamespace = function(_, name, defaults)
	profile = {}
	for k, v in pairs(defaults.profile) do profile[k] = v end
	return { profile = profile, RegisterCallback = function() end }
end }
ns.RegisterChatCommand = function(_, command, fn) slash[command] = fn end
ns.Print = function(_, ...) printed[#printed + 1] = table.concat({ ... }, " ") end
_G.LibStub = function() return Auto() end

assert(loadfile(root .. "/Components/UnitFrames/UnitFrame.lua"))("AzeriteUI5_JuNNeZ_Edition", ns)
local module = modules.UnitFrames
module:OnInitialize()
check(profile.smoothBars == true and profile.smoothCastbars == true, "both switches default on")
check(type(slash.azsmooth) == "function", "/azsmooth is registered")

local CreateBar = metas.CreateBar
check(type(CreateBar) == "function", "CreateBar is registered")
local frame = {}
local health = CreateBar(frame)
check(health.smoothing == IMMEDIATE, "a new bar starts Immediate", health.smoothing)
health:DisableSmoothing(false)
check(health.smoothing == EASED, "a bar that asks to ease eases", health.smoothing)
local cast = CreateBar(frame)
cast:DisableSmoothing(false, "castbars")
check(cast.smoothing == EASED, "a castbar that asks to ease eases")
local preview = CreateBar(frame)
preview:DisableSmoothing(true)
check(preview.smoothing == IMMEDIATE, "a bar that asks for Immediate stays Immediate")

local told
health.__AzeriteUI_OnSmoothingChanged = function(_, on) told = on end
ns.UnitFrame.SetSmoothingEnabled("bars", false)
check(health.smoothing == IMMEDIATE and profile.smoothBars == false, "health/power switch off: the bar is Immediate and it is saved")
check(health.snapped == 1, "turning it off finishes the easing at once", health.snapped)
check(told == false, "and tells the bar")
check(cast.smoothing == EASED, "the castbar switch is separate")
ns.UnitFrame.SetSmoothingEnabled("castbars", false)
check(cast.smoothing == IMMEDIATE and profile.smoothCastbars == false, "castbar switch off")
ns.UnitFrame.SetSmoothingEnabled(nil, true)
check(health.smoothing == EASED and cast.smoothing == EASED and told == true, "both on again")
check(preview.smoothing == IMMEDIATE, "a bar that never asked is left alone")
preview:DisableSmoothing(true)
ns.UnitFrame.SetSmoothingEnabled(nil, true)
check(preview.smoothing == IMMEDIATE, "still")
-- A bar that later asks for Immediate leaves the list.
cast:DisableSmoothing(true)
ns.UnitFrame.SetSmoothingEnabled(nil, true)
check(cast.smoothing == IMMEDIATE, "a bar that stops asking stays Immediate")
cast:DisableSmoothing(false, "castbars")

slash.azsmooth("")
check(profile.smoothBars == false and profile.smoothCastbars == false, "/azsmooth flips both")
slash.azsmooth("on cast")
check(profile.smoothBars == false and profile.smoothCastbars == true, "/azsmooth on cast sets only castbars")
slash.azsmooth("on")
check(profile.smoothBars == true and profile.smoothCastbars == true, "/azsmooth on sets both")
check(printed[#printed] and printed[#printed]:find("health/power") ~= nil, "and reports the state", printed[#printed])

-- A profile change re-applies the saved switches.
profile.smoothBars = false
ns.UnitFrame.RefreshSmoothing()
check(health.smoothing == IMMEDIATE, "RefreshSmoothing applies a profile's switch")
profile.smoothBars = true
ns.UnitFrame.RefreshSmoothing()

--------------------------------------------------------------------------
-- Part 2: Functions.lua
--------------------------------------------------------------------------
local unitHealth, unitMax, guid = 50, 100, "Player-1"
_G.UnitHealth = function() return unitHealth end
_G.UnitHealthMax = function() return unitMax end
_G.UnitIsConnected = function() return true end
_G.UnitGUID = function() return guid end
_G.UnitGetTotalAbsorbs = function() return 0 end
_G.UnitPower = function() return unitHealth end
_G.UnitPowerMax = function() return unitMax end
_G.UnitHealthPercent = nil
_G.UnitPowerPercent = nil
_G.CreateUnitHealPredictionCalculator = nil
-- A clock the harness moves: each update below runs a second later than the last,
-- unless sameFrame holds it still (a snap holds for 0.15 s).
local clock, sameFrame = 100, false
_G.GetTime = function() return clock end

local fns = setmetatable({}, AutoMT)
fns.oUF = setmetatable({ isRetail = true }, AutoMT)
fns.API = setmetatable({}, AutoMT)
local loaded, err = pcall(function()
	assert(loadfile(root .. "/Components/UnitFrames/Functions.lua"))("AzeriteUI5_JuNNeZ_Edition", fns)
end)
check(loaded, "Functions.lua loads under stubs", err)
local API = fns.API
if (loaded and rawget(API, "UpdateHealth")) then
	API.TryCall = function(fn, ...) return pcall(fn, ...) end
	for _, name in ipairs({ "UpdateHealth", "UpdatePower" }) do
		local real = API[name]
		API[name] = function(...)
			if (not sameFrame) then clock = clock + 1 end
			return real(...)
		end
	end
	API.SafeCall = function(_, fn, ...) return pcall(fn, ...) end
	local function Unit()
		local bar = CreateBar({})
		bar:DisableSmoothing(false)
		bar.GetStatusBarTexture = function() return nil end
		return { unit = "party1", Health = bar, Power = bar }
	end
	local owner = Unit()
	local bar = owner.Health
	local ok, e = pcall(API.UpdateHealth, owner, "UNIT_HEALTH", "party1")
	check(ok, "UpdateHealth runs", e)
	-- The first update is a new GUID: it snaps.
	check(bar.writes[#bar.writes] == IMMEDIATE, "a frame's first update snaps", bar.writes[#bar.writes])
	unitHealth = 40
	pcall(API.UpdateHealth, owner, "UNIT_HEALTH", "party1")
	check(bar.writes[#bar.writes] == EASED, "a plain health change eases", bar.writes[#bar.writes])
	check(bar.__AzeriteUI_LastInterpolation == EASED, "and is remembered for shaped fills")
	-- SetMinMaxValues defaults to Immediate: given nothing, it snapped every glide (heals).
	check(bar.rangeInterpolation == EASED, "the range is set with the same easing, so it does not snap the glide", bar.rangeInterpolation)
	-- Player power and absorb events call ForceUpdate on every tick: on the same unit it eases.
	unitHealth = 35
	pcall(API.UpdateHealth, owner, "ForceUpdate", "party1")
	check(bar.writes[#bar.writes] == EASED, "ForceUpdate on the same unit eases", bar.writes[#bar.writes])
	pcall(API.UpdateHealth, owner, "UNIT_ABSORB_AMOUNT_CHANGED", "party1")
	check(bar.writes[#bar.writes] == EASED, "an absorb change eases")
	pcall(API.UpdateHealth, owner, "GROUP_ROSTER_UPDATE", "party1")
	check(bar.writes[#bar.writes] == IMMEDIATE, "a roster change snaps")
	check(bar.rangeInterpolation == IMMEDIATE, "and its range snaps with it")
	pcall(API.UpdateHealth, owner, "OnShow", "party1")
	check(bar.writes[#bar.writes] == IMMEDIATE, "OnShow snaps")
	pcall(API.UpdateHealth, owner, "RefreshUnit", "party1")
	check(bar.writes[#bar.writes] == IMMEDIATE, "RefreshUnit snaps")
	pcall(API.UpdateHealth, owner, "PLAYER_TARGET_CHANGED", "party1")
	check(bar.writes[#bar.writes] == IMMEDIATE, "a target change snaps")
	pcall(API.UpdateHealth, owner, "OnUpdate", "party1")
	check(bar.writes[#bar.writes] == IMMEDIATE, "oUF's eventless polling (ToT) snaps")
	-- A target change, then Target's PostUpdate ForceUpdate in the same frame: both snap.
	sameFrame = true
	pcall(API.UpdateHealth, owner, "PLAYER_TARGET_CHANGED", "party1")
	unitHealth = 0
	pcall(API.UpdateHealth, owner, "ForceUpdate", "party1")
	check(bar.writes[#bar.writes] == IMMEDIATE, "a ForceUpdate right after a target change snaps too (no 100% -> 0% glide)", bar.writes[#bar.writes])
	sameFrame = false
	unitHealth = 10
	pcall(API.UpdateHealth, owner, "UNIT_HEALTH", "party1")
	check(bar.writes[#bar.writes] == EASED, "a moment later, changes ease again", bar.writes[#bar.writes])
	guid = "Player-2"
	pcall(API.UpdateHealth, owner, "UNIT_HEALTH", "party1")
	check(bar.writes[#bar.writes] == IMMEDIATE, "another unit in the frame snaps")
	ns.UnitFrame.SetSmoothingEnabled("bars", false)
	unitHealth = 30
	pcall(API.UpdateHealth, owner, "UNIT_HEALTH", "party1")
	check(bar.writes[#bar.writes] == IMMEDIATE, "switch off: plain changes snap too")
	ns.UnitFrame.SetSmoothingEnabled("bars", true)

	-- /azsmooth trace: one line per write on the followed unit, nothing otherwise.
	local lines = {}
	local realPrint = print
	_G.print = function(text)
		if (type(text) == "string" and text:find("[azsmooth]", 1, true)) then lines[#lines + 1] = text else realPrint(text) end
	end
	-- In game UnitFrame.lua and Functions.lua share ns.API; here each has its own, so the
	-- slash is checked against UnitFrame.lua's and the trace itself against Functions.lua's.
	slash.azsmooth("trace party1")
	check(ns.API.SmoothTrace == "party1", "/azsmooth trace party1 follows party1", ns.API.SmoothTrace)
	API.SmoothTrace = "party1"
	unitHealth = 60
	pcall(API.UpdateHealth, owner, "UNIT_HEALTH", "party1")
	unitHealth = 55
	pcall(API.UpdateHealth, owner, "UNIT_HEALTH", "party1")
	check(#lines == 2 and lines[2]:find("eased") and lines[2]:find("down %-5"), "trace reports an eased write and its direction", lines[2])
	local before = #lines
	pcall(API.UpdateHealth, owner, "OnShow", "party1")
	check(#lines == before + 1 and lines[#lines]:find("snap") and lines[#lines]:find("%(event%)"), "and a snap with its reason", lines[#lines])
	slash.azsmooth("trace off")
	check(rawget(ns.API, "SmoothTrace") == nil, "/azsmooth trace off stops it")
	API.SmoothTrace = nil
	before = #lines
	pcall(API.UpdateHealth, owner, "UNIT_HEALTH", "party1")
	check(#lines == before, "trace off prints nothing")
	_G.print = realPrint

	if (rawget(API, "UpdatePower")) then
		local powerOwner = Unit()
		local power = powerOwner.Power
		local okP, eP = pcall(API.UpdatePower, powerOwner, "UNIT_POWER_FREQUENT", "party1")
		check(okP, "UpdatePower runs", eP)
		unitHealth = 20
		pcall(API.UpdatePower, powerOwner, "UNIT_POWER_FREQUENT", "party1")
		check(power.writes[#power.writes] == EASED, "a plain power change eases", power.writes[#power.writes])
		check(power.writes[1] == IMMEDIATE, "the first power value snaps", power.writes[1])
		unitHealth = 18
		pcall(API.UpdatePower, powerOwner, "ForceUpdate", "party1")
		check(power.writes[#power.writes] == EASED, "Player power's per-tick ForceUpdate eases", power.writes[#power.writes])
		guid = "Player-3"
		pcall(API.UpdatePower, powerOwner, "ForceUpdate", "party1")
		check(power.writes[#power.writes] == IMMEDIATE, "a new unit's power snaps")
	end
end

print(string.format("smooth bars: %d checks, %d failures", checks, failures))
os.exit(failures == 0 and 0 or 1)
