-- Target cast fallback geometry and authoritative interrupt colour, offline only.
-- Runs real helper bodies from Target.lua/Functions.lua and the real option entry.
-- Lua 5.1: Tools/Run-Elune.ps1 -Script Tools/Harness/target_castbar_harness.lua . [mutation]
-- The widget model checks ownership/geometry and cache transitions, not WoW rendering.
local root, mutation = arg[1] or ".", arg[2]
local checks, failures = 0, 0
local function check(value, label)
	checks = checks + 1
	if not value then failures = failures + 1; print("FAIL: " .. label) end
end
local function read(path)
	local f = assert(io.open(root .. "/" .. path, "rb"))
	local text = f:read("*a"); f:close(); return text
end
local function slice(text, first, last)
	local a = assert(text:find(first, 1, true), first)
	local b = assert(text:find(last, a + #first, true), last)
	return text:sub(a, b - 1)
end
local target = read("Components/UnitFrames/Units/Target.lua")
local mutations = {
	["cached-flag"] = { "notInterruptible = GetTargetCurrentNotInterruptible(element)", "notInterruptible = element.notInterruptible" },
	["wrong-channel-index"] = { "results[channel and 8 or 9]", "results[9]" },
	["fallback-full-width"] = { "fakeFill:SetAllPoints(texture)", "fakeFill:SetAllPoints(cast)" },
}
if mutation then
	local pair = assert(mutations[mutation], "unknown mutation")
	local a, b = target:find(pair[1], 1, true); assert(a, "mutation target missing")
	target = target:sub(1, a - 1) .. pair[2] .. target:sub(b + 1)
end
local secrets = setmetatable({}, { __mode = "k" })
local function forbidden() error("secret inspected", 2) end
local secretMT = { __lt = forbidden, __le = forbidden, __add = forbidden, __sub = forbidden,
	__mul = forbidden, __div = forbidden, __concat = forbidden, __tostring = forbidden }
local function secret(kind) local v = setmetatable({}, secretMT); secrets[v] = kind; return v end
local env = setmetatable({}, { __index = _G })
env.type = function(v) return secrets[v] or type(v) end
env.issecretvalue = function(v) return secrets[v] ~= nil end
env.IsSecretValue = env.issecretvalue
local API = {
	TryCall = function(fn, ...) return pcall(fn, ...) end,
	IsSafeNumber = function(v) return not env.issecretvalue(v) and type(v) == "number" end,
}
env.API = API
env.IsSafeNumber = API.IsSafeNumber
local world = { flag = false, ready = 1, queryCalls = 0, legacyProbes = 0 }
local modules = { TargetFrame = { db = { profile = { colorCastBarByInterruptState = true } } } }
env.TargetFrameMod = modules.TargetFrame
local base = { .3, .5, .7, .8 }
env.Colors = { gray = { .5, .5, .5 }, red = { 1, 0, 0 } }
env.EmitInterruptDebug = function() end
env.GetPrimaryInterruptReadyState = function() return world.ready, 123 end
env.IsCastMarkedNotInterruptible = function(cast)
	world.legacyProbes = world.legacyProbes + 1
	return cast.notInterruptible
end
env.UnitCanAttack = function() return true end
API.SafeUnitIsUnit = function(a, b) return a == b end
API.SafeCallPacked = function(_, fn, ...)
	local results = { pcall(fn, ...) }
	if not results[1] then world.queryErrors = (world.queryErrors or 0) + 1; return false end
	return true, results
end
env.UnitCastingInfo = function(unit)
	world.queryCalls = world.queryCalls + 1; world.queryKind, world.unit = "cast", unit
	if world.queryFails then error("API unavailable") end
	return "Spell", "Spell", 1, 0, 1000, false, "guid", world.flag, 123
end
env.UnitChannelInfo = function(unit)
	world.queryCalls = world.queryCalls + 1; world.queryKind, world.unit = "channel", unit
	return "Channel", "Channel", 1, 0, 1000, false, world.flag, 123, false
end
local created = 0
local function Region()
	local r = { shown = true }
	function r:SetAllPoints(other) self.anchor = other; self.anchorWrites = (self.anchorWrites or 0) + 1 end
	function r:ClearAllPoints() self.anchor = nil end
	function r:SetTexCoord(...) self.coords = { ... } end
	function r:SetAlpha(value) self.alpha = value end
	function r:Show() self.shown = true end
	function r:Hide() self.shown = false end
	function r:SetWidth() error("fallback must let the native bar size its region") end
	function r:GetWidth()
		if self.driver then return self.driver.parent.width * self.driver.value end
		return self.anchor:GetWidth()
	end
	return r
end
env.CreateFrame = function(kind, name, parent)
	assert(kind == "StatusBar" and name == nil and parent, "owned unnamed StatusBar")
	created = created + 1
	local bar = { parent = parent, texture = Region() }
	bar.texture.driver = bar
	function bar:SetAllPoints(anchor) self.anchor = anchor end
	function bar:SetStatusBarTexture(texture) self.texturePath = texture end
	function bar:GetStatusBarTexture() return self.texture end
	function bar:SetMinMaxValues(low, high) self.low, self.high = low, high end
	function bar:SetOrientation(value) self.orientation = value end
	function bar:SetReverseFill(value) self.reverse = value end
	function bar:SetValue(value) self.value = value end
	return bar
end
env.GetTargetBarGrowth = function(cast) return cast.growth end
env.ApplyTargetNativeCastVertexColor = function(cast) cast.nativeColorCalls = (cast.nativeColorCalls or 0) + 1 end
env.ApplyTargetFakeCastVertexColor = function(cast) cast.fakeColorCalls = (cast.fakeColorCalls or 0) + 1 end
env.ns = { API = API, UnitFrame = { ShouldColorCastSpellTextByState = function() return false end } }
local function compile(text)
	local chunk = assert(loadstring(text, "=target castbar helpers"))
	setfenv(chunk, env); return chunk()
end
compile(slice(read("Components/UnitFrames/Functions.lua"), "local InterruptVisualColors =", "local InterruptCastBarRefreshFrame ="))
local T = compile("local GetTargetCastVisualGrowth = GetTargetBarGrowth\n"
	.. slice(target, "local GetTargetCastCropDriver = function", "local ApplyTargetFakeCastVertexColor\n")
	.. slice(target, "local ApplyTargetOverlayCastFill = function", "local IsTargetCastBarInterruptColorEnabled = function")
	.. slice(target, "local IsTargetCastBarInterruptColorEnabled = function", "GetTargetCastVisualGrowth = function")
	.. slice(target, "local ShouldColorTargetCastBarByInterruptState = function", "local Cast_PostCastInterruptible = function")
	.. "\nreturn { Driver = GetTargetCastCropDriver, Fill = ApplyTargetSimpleCastFakeFillByPercent,"
	.. " Overlay = ApplyTargetOverlayCastFill, Refresh = Cast_RefreshInterruptVisuals, ReadFlag = GetTargetCurrentNotInterruptible }\n")
-- The text switch is a separate unchanged feature; only the bar colour is under test.
env.ShouldColorTargetSpellTextByState = function() return false end

local function Cast()
	local cast = { width = 300, growth = "LEFT", casting = true, notInterruptible = true,
		__owner = { unit = "target", canAttack = true }, color = base, FakeFill = Region(), native = Region(), Text = { color = base } }
	function cast:GetWidth() return self.width end
	function cast:GetStatusBarTexture() return self.native end
	function cast:SetStatusBarColor(...) self.colorApplied = { ... } end
	function cast.Text:SetTextColor(...) self.colorApplied = { ... } end
	return cast
end
local cast = Cast()
local driver = T.Driver(cast)
check(created == 1 and T.Driver(cast) == driver, "one reusable owned geometry driver")
check(driver.low == 0 and driver.high == 1 and driver.anchor == cast, "driver range and viewport")
check(driver.texture.alpha == 0 and driver.orientation == "HORIZONTAL", "driver is invisible native horizontal geometry")
for _, growth in ipairs({ "LEFT", "RIGHT" }) do
	cast.growth = growth
	for _, value in ipairs({ .25, .5, 1 }) do
		check(T.Fill(cast, value), growth .. " fallback accepts readable progress")
		check(cast.FakeFill.anchor == driver.texture and driver.reverse == (growth == "LEFT"), growth .. " inherits correctly directed native region")
		check(cast.FakeFill:GetWidth() == 300 * value, growth .. " native region has expected visible width")
		check(cast.FakeFill.coords[1] == (growth == "LEFT" and value or 1)
			and cast.FakeFill.coords[2] == (growth == "LEFT" and 0 or 1 - value), growth .. " cropped painting retains its scale")
	end
end
cast.width = 420
T.Fill(cast, .5)
check(cast.FakeFill:GetWidth() == 210 and created == 1, "resize follows native anchors without recreating driver")
T.Fill(cast, 0)
check(not cast.FakeFill.shown, "empty fallback hides the painting")
T.Fill(cast, 2)
check(driver.value == 1 and cast.FakeFill.shown, "progress above full clamps")
check(T.Fill(cast, secret("number")) == false, "secret fallback rejected without geometry or arithmetic")
check(T.Fill(cast, "invalid") == false, "invalid fallback rejected")
local noDriver = Cast()
check(T.Fill(noDriver, .5) == false and created == 1, "fallback never creates frames during updates")
T.Fill(cast, nil)
check(cast.FakeFill.anchor == cast and cast.__AzeriteUI_FakeFillFollowsTexture == nil, "idle restores whole viewport and invalidates cache")
cast.growth = "LEFT"
local duration = { GetElapsedPercent = function() return .3 end }
check(T.Overlay(cast, duration) and cast.FakeFill.anchor == cast.native, "native timer overlay can resume after fallback")
T.Fill(cast, .4)
check(cast.FakeFill.anchor == driver.texture, "fallback reanchors after native timer overlay")
local writes = cast.FakeFill.anchorWrites
T.Fill(cast, .6)
check(cast.FakeFill.anchorWrites == writes, "same fallback driver avoids repeated anchor mutations")
duration.GetElapsedPercent = function() return secret("number") end
check(T.Overlay(cast, duration) and env.issecretvalue(cast.FakeFill.coords[1]), "normal timer overlay still forwards secret crop untouched")

-- Actual shared resolver plus target refresh. Cached status deliberately contradicts raw status.
cast = Cast()
world.flag, world.ready = false, 1
T.Refresh(cast)
check(cast.__AzeriteUI_InterruptCastState == "primary-ready" and cast.colorApplied[1] == 1 and cast.colorApplied[2] == .82,
	"fresh interruptible cast overrides stale protected cache and uses readiness yellow")
check(world.legacyProbes == 0 and world.queryKind == "cast" and world.unit == "target", "target bypasses legacy cache and reads current cast")
world.ready = 0
T.Refresh(cast)
check(cast.__AzeriteUI_InterruptCastState == "unavailable" and cast.colorApplied[2] == 0, "interrupt cooldown uses existing unavailable red")
world.flag, cast.notInterruptible = true, false
T.Refresh(cast)
check(cast.__AzeriteUI_InterruptCastState == "locked" and cast.colorApplied[1] == .5, "fresh protected cast overrides stale interruptible cache")
for _, flag in ipairs({ secret("boolean"), "invalid" }) do
	world.flag = flag
	T.Refresh(cast)
	check(cast.__AzeriteUI_InterruptCastState == "base" and cast.colorApplied[1] == base[1], "unknown raw status stays base despite cached false")
end
world.flag = nil
T.Refresh(cast)
check(cast.__AzeriteUI_InterruptCastState == "base", "missing current cast flag stays base")
world.flag, cast.casting, cast.channeling = true, nil, true
T.Refresh(cast)
check(world.queryKind == "channel" and cast.__AzeriteUI_InterruptCastState == "locked", "channel uses its correct raw flag index")
cast.channeling, cast.empowering = nil, true
T.Refresh(cast)
check(world.queryKind == "channel" and cast.__AzeriteUI_InterruptCastState == "locked", "empowered channel uses channel raw flag")
cast.empowering, cast.casting = nil, true
world.queryFails = true
T.Refresh(cast)
check(cast.__AzeriteUI_InterruptCastState == "base" and world.queryErrors == 1, "query failure is reported and neutral")
world.queryFails = nil
local query = env.UnitCastingInfo
env.UnitCastingInfo = nil
T.Refresh(cast)
check(cast.__AzeriteUI_InterruptCastState == "base", "missing API keeps base colour")
env.UnitCastingInfo = query
modules.TargetFrame.db.profile.colorCastBarByInterruptState = false
local before = world.queryCalls
T.Refresh(cast)
check(cast.__AzeriteUI_InterruptCastState == "base" and world.queryCalls == before, "switch off restores base without polling")
modules.TargetFrame.db.profile.colorCastBarByInterruptState = true
cast.casting = nil
T.Refresh(cast)
check(cast.__AzeriteUI_InterruptCastState == "base", "finished cast restores base")
cast.casting, cast.__owner.canAttack, world.flag = true, false, true
env.UnitCanAttack = function() return false end
T.Refresh(cast)
check(cast.__AzeriteUI_InterruptCastState == "base", "friendly cast is not interrupt coloured")
env.UnitCanAttack = function() return true end
cast.__owner.canAttack, cast.notInterruptible = true, true
before = world.legacyProbes
check(API.GetInterruptCastVisualState(cast) == "locked" and world.legacyProbes > before, "existing callers retain legacy resolver semantics")
check(API.GetInterruptCastVisualState(cast, secret("boolean")) == "base", "shared optional argument rejects secrets")
check(API.GetInterruptCastVisualState(cast, "bad") == "base", "shared optional argument rejects invalid types")

-- Compile the exact option entry, preserving its existing getters and disabled rules.
local options = read("Options/OptionsPages/UnitFrames.lua")
local enabled, showCast = true, true
env.L = setmetatable({}, { __index = function(_, k) return k end })
env.isdisabled = function() return not enabled end
env.getoption = function(_, key) assert(key == "showCastbar"); return showCast end
env.setter, env.getter = function() end, function() end
local option = compile("local suboptions = { args = {} }\n"
	.. slice(options, "\t\tsuboptions.args.colorCastBarByInterruptState = {", "\t\tsuboptions.args.textHeader = {")
	.. "\nreturn suboptions.args.colorCastBarByInterruptState")
check(option.hidden({}) == false and option.disabled({}) == false, "target tint control visible and enabled with castbar")
showCast = false
check(option.hidden({}) == false and option.disabled({}) == true, "castbar off disables control")
enabled = false
check(option.hidden({}) == true and option.disabled({}) == true, "disabled target module hides control")

print(("Target castbar: %d checks, %d failures%s (offline widgets only)"):format(checks, failures,
	mutation and ("; mutation " .. mutation) or ""))
if failures > 0 then os.exit(1) end
