-- API.UpdatePower with secret power values (party mana in restricted content).
-- Loads the real Components/UnitFrames/Functions.lua against permissive stubs;
-- only the bar writes are inspected. Run: lua.exe Tools/Harness/power_secret_harness.lua <addon root>
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

-- Alternate player: exercise its real visibility callback inside UpdatePower,
-- including the shared HidePowerTexts call that used to undo Value:Show().
local function readSource(path)
	local file = assert(io.open(root .. "/" .. path))
	local source = file:read("*a")
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
check(frame.Power.shown and frame.Power.Value.shown, "zero mana keeps crystal and value visible")
update(secret(5000), secret(250000))
check(frame.Power.Value.shown, "restricted mana keeps value visible")
dead = true
update(0, 250000)
check(not frame.Power.Value.shown, "dead player retains hidden value")
dead = false
update(250000, 250000)
check(frame.Power.Value.shown, "value returns after resurrection")
postUpdate(frame.Power, "party1", 0, 0, 0)
check(not frame.Power.Value.shown, "no resource hides the crystal")

local rangeRead = assert(alternateSource:match("local powerMin, powerMax = 0, 0.-\n\tend"))
local readRange = assert(loadstring("return function(power) " .. rangeRead .. "\nreturn powerMin, powerMax end"))()
local lo, hi = readRange({ GetMinMaxValues = function() return 0, 250000 end })
check(lo == 0 and hi == 250000, "texture refresh preserves both range returns")

-- Exercise the actual dedicated tag with a stale bar cache and live API values.
local tagSource = readSource("Components/UnitFrames/Tags.lua")
local tagBody = assert(tagSource:match('Methods%[prefix%("%*:PlayerAlternatePower"%)%] = (function.-)\nend')) .. "\nend"
local tagFrame = { Power = { safeCur = 250000, displayType = 0 } }
local formatterFails = false
local formatter = function(value)
	if formatterFails then error("formatter unavailable") end
	if issecretvalue(value) then return value end
	return tostring(value)
end
local tag = assert(loadstring("local API, AbbreviateNumbers, GetFramePowerContext, _FRAME = ...\nreturn " .. tagBody))(
	ns.API, formatter, function(f) return f.Power, f.Power.displayType end, tagFrame)
power.cur = 5000
check(tag("party1") == "5000", "live amount wins over stale bar cache")
power.cur = 0
check(tag("party1") == "0", "tag renders zero")
power.cur = 120000
check(tag("party1") == "120000", "tag follows regeneration")
power.cur = secret(5000)
check(tag("party1") == power.cur, "secret payload reaches display without arithmetic")
formatterFails = true
check(tag("party1") == power.cur, "formatter failure preserves raw display payload")
check(alternateSource:find('self:Tag(powerValue, prefix("[*:PlayerAlternatePower]"))', 1, true), "alternate crystal uses dedicated tag")

print("Power secret and alternate player: " .. checks .. " checks passed (offline only).")
