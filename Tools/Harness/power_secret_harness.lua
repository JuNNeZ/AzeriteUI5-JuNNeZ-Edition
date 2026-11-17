-- API.UpdatePower with secret power values (party mana in restricted content).
-- Loads the real Components/UnitFrames/Functions.lua against permissive stubs;
-- Models bar writes and alternate-player text/visibility, not WoW rendering or secrets.
-- Run: Tools/Run-Elune.ps1 -Script Tools/Harness/power_secret_harness.lua <addon root>
local root = arg[1] or '.'
local checks = 0
local function check(v, msg) assert(v, msg); checks = checks + 1 end

-- Anything the file touches at load time that this harness does not care about.
local Any
Any = setmetatable({}, { __index = function() return Any end, __call = function() return Any end })
setmetatable(_G, { __index = function(_, k) return Any end })

-- Secret values are tables flagged here; arithmetic or comparison on them raises.
local secretMeta = {
	__lt = function() error("compared a secret value") end,
	__le = function() error("compared a secret value") end,
	__add = function() error("arithmetic on a secret value") end,
	__sub = function() error("arithmetic on a secret value") end,
	__mul = function() error("arithmetic on a secret value") end,
	__div = function() error("arithmetic on a secret value") end,
}
local function secret(v) return setmetatable({ value = v }, secretMeta) end
issecretvalue = function(v) return getmetatable(v) == secretMeta end
local realType = type
type = function(v) if (issecretvalue(v)) then return "number" end return realType(v) end

local power = { cur = 0, max = 0, connected = true }
UnitPower = function() return power.cur end
UnitPowerMax = function() return power.max end
UnitPowerPercent = function() return secret(50) end
UnitHealthPercent = nil
UnitIsConnected = function() return power.connected end
UnitGUID = function() return "Player-1" end
GetTime = function() return 100 end -- the snap hold (SetStatusBarValuesCompat) does arithmetic on it
CurveConstants = nil

local ns = { oUF = { isRetail = true }, Colors = {}, API = {} }
ns.API.TryCall = function(fn, ...) return pcall(fn, ...) end
ns.API.SafeCall = function(_, fn, ...) return pcall(fn, ...) end
ns.API.IsSafeNumber = function(v) return realType(v) == "number" end
ns.API.DebugPrintf = function() end

local chunk = assert(loadfile(root .. "/Components/UnitFrames/Functions.lua"))
local ok, err = pcall(chunk, "AzeriteUI5_JuNNeZ_Edition", ns)
assert(ok, err)
local UpdatePower = assert(ns.API.UpdatePower, "API.UpdatePower")

local function newFrame()
	local bar = {}
	function bar:SetMinMaxValues(lo, hi) self.lo, self.hi = lo, hi end
	function bar:SetValue(v) self.v = v end
	function bar:GetStatusBarTexture() return nil end
	return { unit = "party1", Power = bar }
end

-- Readable values: unchanged behaviour.
local frame = newFrame()
power.cur, power.max = 120000, 250000
UpdatePower(frame, "ForceUpdate", "party1")
check(frame.Power.hi == 250000 and frame.Power.v == 120000, "readable mana: real range and value")

-- Secret current and max after a forced update (cached max cleared): both reach the bar.
local cur, max = secret(120000), secret(250000)
power.cur, power.max = cur, max
UpdatePower(frame, "ForceUpdate", "party1")
check(frame.Power.v == cur, "secret mana: value passed through")
check(frame.Power.hi == max, "secret max passed through, not the 0..100 fallback that drew a full bar")

-- Secret current, readable max: the readable max is used.
power.cur, power.max = secret(5000), 250000
UpdatePower(frame, "UNIT_POWER_FREQUENT", "party1")
check(frame.Power.hi == 250000, "secret mana with readable max keeps the real range")

-- A readable zero max still falls back as before (no division, no 0..0 range).
power.cur, power.max = 0, 0
UpdatePower(frame, "ForceUpdate", "party1")
check(frame.Power.hi == 100, "zero max keeps the cached fallback")

-- Exercise the real alternate visibility callback through the shared updater.
local function readSource(path)
	local file = assert(io.open(root .. "/" .. path, "rb"))
	local source = file:read("*a"):gsub("\r\n", "\n")
	file:close()
	return source
end
local alternateSource = readSource("Components/UnitFrames/Units/PlayerAlternate.lua")
local visibility = assert(alternateSource:match("local Power_UpdateVisibility = (function.-)\nend")) .. "\nend"
local dead = false
UnitIsDeadOrGhost = function() return dead end
local postUpdate = assert(loadstring("local HideSaiyaRattBlizzardAltPowerBar = function() end\nreturn " .. visibility))()
local function widget()
	return {
		Show = function(self) self.shown = true end,
		Hide = function(self) self.shown = false end
	}
end
frame = newFrame()
frame.Power.Show, frame.Power.Hide = widget().Show, widget().Hide
frame.Power.Value, frame.Power.Backdrop = widget(), widget()
frame.Power.Value.alpha = .35
frame.Power.PostUpdate = postUpdate
local function update(curValue, maxValue)
	power.cur, power.max = curValue, maxValue
	UpdatePower(frame, "UNIT_POWER_FREQUENT", "party1")
end
update(120000, 250000)
check(frame.Power.Value.shown, "alternate value survives shared text hiding")
update(5000, 250000)
check(frame.Power.Value.shown, "alternate value stays visible after spending mana")
update(0, 250000)
check(frame.Power.shown and frame.Power.Backdrop.shown and frame.Power.Value.shown, "zero mana keeps crystal and value visible")
update(secret(5000), secret(250000))
check(frame.Power.Value.shown, "restricted mana keeps value visible")
dead = true
update(0, 250000)
check(not frame.Power.shown and not frame.Power.Value.shown, "dead player retains hidden crystal and value")
dead = false
update(250000, 250000)
check(frame.Power.Value.shown, "value returns after resurrection")
check(frame.Power.Value.alpha == .35, "visibility refresh preserves the configured text alpha")
postUpdate(frame.Power, "party1", 0, 0, 0)
check(not frame.Power.Value.shown, "an explicitly absent resource hides the crystal")

local rangeRead = assert(alternateSource:match("local powerMin, powerMax = 0, 0.-\n\tend"))
local readRange = assert(loadstring("return function(power) " .. rangeRead .. "\nreturn powerMin, powerMax end"))()
local lo, hi = readRange({ GetMinMaxValues = function() return 0, 250000 end })
check(lo == 0 and hi == 250000, "texture refresh preserves both range returns")
lo, hi = readRange({})
check(lo == 0 and hi == 0, "missing range getter keeps a defensive empty range")

-- Load the whole tag file so the real frame-power context is exercised too.
local formatterFails, requestedPowerType = false, nil
AbbreviateNumbers = function(value)
	if formatterFails then error("formatter unavailable") end
	if issecretvalue(value) then return value end
	return tostring(value)
end
UnitPowerType = function() return 3 end
UnitPower = function(_, powerType) requestedPowerType = powerType; return power.cur end
ns.oUF.Tags = { Events = {}, Methods = {} }
ns.Colors, ns.Prefix = Any, "Test"
ns.API.AbbreviateNumber = tostring
Enum = { PowerType = { Mana = 0 } }
assert(loadfile(root .. "/Components/UnitFrames/Tags.lua"))("AzeriteUI5_JuNNeZ_Edition", ns)
local tag = assert(ns.oUF.Tags.Methods["Test:PlayerAlternatePower"], "dedicated alternate power tag")
_FRAME = { Power = { safeCur = 250000, displayType = 0 } }
power.cur = 5000
check(tag("player") == "5000", "live amount wins over stale bar cache")
check(requestedPowerType == 0, "tag uses the frame's displayed resource type")
power.cur = 0
check(tag("player") == "0", "tag renders zero")
power.cur = 120000
check(tag("player") == "120000", "tag follows regeneration")
power.cur = secret(5000)
check(tag("player") == power.cur, "restricted payload reaches display without arithmetic")
formatterFails = true
check(tag("player") == power.cur, "formatter failure preserves the raw display payload")
power.cur = 42
check(tag("player") == 42, "formatter failure also preserves readable values")
dead = true
check(tag("player") == nil, "dead player tag clears")
dead = false
AbbreviateNumbers = nil
assert(loadfile(root .. "/Components/UnitFrames/Tags.lua"))("AzeriteUI5_JuNNeZ_Edition", ns)
tag = ns.oUF.Tags.Methods["Test:PlayerAlternatePower"]
power.cur = 0
check(tag("player") == 0, "missing formatter preserves zero as a raw display value")
check(alternateSource:find('self:Tag(powerValue, prefix("[*:PlayerAlternatePower]"))', 1, true), "alternate crystal uses the dedicated tag")

print("Power secret and alternate player: " .. checks .. " checks passed (offline only).")
