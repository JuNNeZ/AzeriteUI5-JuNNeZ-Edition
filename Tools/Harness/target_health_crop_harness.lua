-- Target health's shaped fill, offline: the crop helper (SetTargetHealthCrop), its eased
-- follow, the percent sources' scale and the spark on the helper's edge.
-- Lua 5.1: lua Tools/Harness/target_health_crop_harness.lua . [mutation]
--
-- It runs the real source: the block of Components/UnitFrames/Units/Target.lua from
-- GetTargetBarGrowth up to SyncTargetHealthVisualState is cut out and compiled against
-- stubs. The stubs only record what they are told; the engine's easing is played by
-- hand (`driver.interpolated`). It cannot show how the easing looks in the client.
local root = arg[1] or "."
local mutation = arg[2]
local checks, failures = 0, 0
local function check(value, label, detail)
	checks = checks + 1
	if (not value) then
		failures = failures + 1
		print("FAIL: " .. label .. (detail ~= nil and ("  (" .. tostring(detail) .. ")") or ""))
	end
end

-- Each must fail on its own (the old behaviour this harness was written against).
local mutations = {
	["one-second-follow"] = { "local FollowTargetHealthCrop = function(driver)",
		"local FollowTargetHealthCrop = function(driver, elapsed) driver.t = (driver.t or 0) + elapsed;"
		.. " if (driver.t > 1) then driver.following = nil; driver:SetScript('OnUpdate', nil); return end" },
	["mirror-0-100"] = { "percent = mirrorPercent / 100", "percent = mirrorPercent" },
	["spark-at-end"] = { "if (cropTexture) then", "if (false) then" },
	["no-snap-on-redraw"] = { "and GetTime and health.__AzeriteUI_LastWriteTime == GetTime()", "" },
}

local f = assert(io.open(root .. "/Components/UnitFrames/Units/Target.lua", "rb"))
local s = f:read("*a"); f:close()
if (mutation) then
	local m = assert(mutations[mutation], "unknown mutation")
	local a, b = s:find(m[1], 1, true)
	assert(a, "mutation text not found: " .. mutation)
	s = s:sub(1, a - 1) .. m[2] .. s:sub(b + 1)
end
local first = assert(s:find("local GetTargetBarGrowth = function", 1, true), "slice start")
local last = assert(s:find("local SyncTargetHealthVisualState = function", 1, true), "slice end")
local slice = s:sub(first, last - 1) .. [[
return {
	UpdateTargetBarSpark = UpdateTargetBarSpark,
	GetTargetHealthCropDriver = GetTargetHealthCropDriver,
	FromBar = UpdateTargetHealthFakeFillFromBar,
}]]

-- Stubs --------------------------------------------------------------------
local IMMEDIATE, EASED = 0, 1
local SECRET = 0.123456 -- stands for a secret number: issecretvalue says so, nothing else
local clock = 100
local unitHealth, unitMax, apiPercent, curveAnswer = 50, 100, nil, 1
local curveCalls = 0

local function NewRegion()
	local r = { points = {}, alpha = 1, shown = false }
	function r:ClearAllPoints() self.points = {}; self.allPoints = nil end
	function r:SetAllPoints(target) self.allPoints = target end
	function r:SetPoint(...) self.points[#self.points + 1] = { ... } end
	function r:SetTexCoord(...) self.coords = { ... } end
	function r:SetVertexColor() end
	function r:SetAlpha(a) self.alpha = a end
	function r:Show() self.shown = true end
	function r:Hide() self.shown = false end
	function r:SetSize() end
	return r
end

local function NewStatusBar()
	local bar = { value = 1, interpolated = 1, orientation = "HORIZONTAL", reverse = false, scripts = {} }
	bar.texture = NewRegion()
	function bar:SetAllPoints() end
	function bar:SetStatusBarTexture() end
	function bar:GetStatusBarTexture() return self.texture end
	function bar:SetMinMaxValues() end
	function bar:SetValue(v, interpolation)
		self.value, self.lastInterpolation = v, interpolation
		if (interpolation ~= EASED) then self.interpolated = v end
	end
	function bar:GetInterpolatedValue() return self.interpolated end
	function bar:SetToTargetValue() self.interpolated = self.value end
	function bar:SetOrientation(o) self.orientation = o end
	function bar:SetReverseFill(r) self.reverse = r end
	function bar:SetScript(name, fn) self.scripts[name] = fn end
	return bar
end

local env = setmetatable({}, { __index = _G })
env.Enum = {
	StatusBarInterpolation = { Immediate = IMMEDIATE, ExponentialEaseOut = EASED },
	LuaCurveType = { Step = 1 },
}
env.issecretvalue = function(v) return v == SECRET end
env.math_max = math.max
env.GetTime = function() return clock end
env.CreateFrame = function() return NewStatusBar() end
env.UnitHealth = function() return unitHealth end
env.UnitHealthMax = function() return unitMax end
env.CurveConstants = { ZeroToOne = "ZeroToOne" }
env.UnitHealthPercent = function(_, _, curve)
	if (curve == "ZeroToOne") then return apiPercent end
	curveCalls = curveCalls + 1
	return curveAnswer
end
env.C_CurveUtil = { CreateCurve = function()
	local c = { points = {} }
	function c:SetType(t) self.type = t end
	function c:AddPoint(x, y) self.points[#self.points + 1] = { x, y } end
	return c
end }
env.API = {
	TryCall = function(fn, ...) if (type(fn) ~= "function") then return false end return pcall(fn, ...) end,
	SafeCall = function(_, fn, ...) return pcall(fn, ...) end,
	IsSafeNumber = function(v) return type(v) == "number" and v ~= SECRET end,
}
env.ns = { GetConfig = function() return { UseHealthSpark = true } end }
env.print = function() end

local chunk = assert(loadstring(slice, "=Target.lua slice"))
setfenv(chunk, env)
local T = chunk()

-- A target health bar as the style leaves it: reversed, with a FakeFill and a spark.
local health = {
	unit = "target", orientation = "HORIZONTAL", reverse = true, value = 50, max = 100,
	__owner = { unit = "target" },
}
function health:GetOrientation() return self.orientation end
function health:GetReverseFill() return self.reverse end
function health:GetValue() return self.value end
function health:GetMinMaxValues() return 0, self.max end
function health:GetStatusBarColor() return 1, 0, 0 end
function health:IsShown() return true end
function health:GetWidth() return 300 end
function health:GetHeight() return 20 end
health.FakeFill = NewRegion()
health.Spark = NewRegion()
health.Spark.requiresConfigKey = "UseHealthSpark"

local driver = T.GetTargetHealthCropDriver(health)
local fill = health.FakeFill
local function write(interpolation, now)
	health.__AzeriteUI_LastInterpolation = interpolation
	health.__AzeriteUI_LastWriteTime = now or clock
end

-- 1. A snapped write: helper and crop jump together, reversed, nothing follows.
write(IMMEDIATE)
unitHealth = 50
T.FromBar(health)
check(fill.allPoints == driver.texture, "the fill is anchored to the helper's texture (its width)")
check(driver.reverse == true and driver.orientation == "HORIZONTAL", "the helper fills the same way as the reversed health bar")
check(driver.value == .5 and driver.lastInterpolation == IMMEDIATE, "a snap sets the helper at once", driver.value)
check(fill.coords and fill.coords[1] == .5 and fill.coords[2] == 0, "and crops (0.5, 0): the right half of the mirrored art", fill.coords and fill.coords[1])
check(driver.scripts.OnUpdate == nil and not driver.following, "nothing follows after a snap")

-- 2. An eased write: the crop follows the helper's interpolated value, for as long as it glides.
clock = clock + 1
write(EASED)
unitHealth = 20
T.FromBar(health)
check(driver.value == .2 and driver.lastInterpolation == EASED, "an eased write eases the helper", driver.lastInterpolation)
check(driver.following and type(driver.scripts.OnUpdate) == "function", "and the crop follows it")
check(fill.coords[1] == .5, "starting where the glide starts", fill.coords[1])
driver.interpolated = .35
driver.scripts.OnUpdate(driver, .5)
check(fill.coords[1] == .35, "mid-glide the crop is the interpolated value", fill.coords[1])
-- The engine's curve may run past a second; the follow must not give up and jump.
local function tick(dt) if (driver.scripts.OnUpdate) then driver.scripts.OnUpdate(driver, dt) end end
tick(.6)
driver.interpolated = .21
tick(.6)
check(driver.following and fill.coords[1] == .21, "it still follows after more than a second", fill.coords[1])
-- A second eased write while following keeps the one follower.
local follower = driver.scripts.OnUpdate
T.FromBar(health)
check(driver.scripts.OnUpdate == follower, "another eased write keeps the same follower")

-- 3. A redraw with no write this frame (texture or tier refresh) snaps and stops following.
clock = clock + 1
T.FromBar(health)
check(driver.lastInterpolation == IMMEDIATE and not driver.following and driver.scripts.OnUpdate == nil,
	"a redraw without a write snaps and stops following", driver.lastInterpolation)

-- 4. Turning easing off mid-glide finishes the crop at once.
write(EASED)
unitHealth = 60
T.FromBar(health)
check(driver.following, "(gliding again)")
health:__AzeriteUI_OnSmoothingChanged(false)
check(not driver.following and driver.scripts.OnUpdate == nil and fill.coords[1] == .6, "switching off ends the glide at its target", fill.coords[1])

-- 5. Scale: every source reaches the helper as 0..1.
clock = clock + 1
write(IMMEDIATE)
unitHealth, health.value = SECRET, SECRET
health.__AzeriteUI_MirrorPercent = .8 -- 0.8 %, mirrors are 0..100
T.FromBar(health)
check(math.abs(driver.value - .008) < 1e-9, "a 0.8% mirror crops 0.008, not 80%", driver.value)
health.__AzeriteUI_MirrorPercent = 100
T.FromBar(health)
check(driver.value == 1, "a full mirror crops 1", driver.value)
health.__AzeriteUI_MirrorPercent = nil
health.__AzeriteUI_TexturePercent = 40
T.FromBar(health)
check(math.abs(driver.value - .4) < 1e-9, "a texture percent is 0..100 too", driver.value)
health.__AzeriteUI_TexturePercent = nil
apiPercent = SECRET
T.FromBar(health)
check(driver.value == SECRET and fill.coords[1] == SECRET, "a secret percent goes to the helper and crop untouched")

-- 6. The spark rides the helper's moving edge, hidden at full and empty.
local spark = health.Spark
local function anchor() local p = spark.points[#spark.points]; return p and p[2], p and p[3] end
unitHealth, unitMax, health.value = 50, 100, 50
write(IMMEDIATE)
T.FromBar(health)
local to, point = anchor()
check(to == driver.texture and point == "LEFT", "the spark sits on the helper's left edge (reversed bar)", point)
check(spark.shown and spark.alpha == 1, "and shows between empty and full", spark.alpha)
unitHealth = 100
T.FromBar(health)
check(spark.alpha == 0, "hidden at full", spark.alpha)
unitHealth = 0
T.FromBar(health)
check(spark.alpha == 0, "hidden when empty", spark.alpha)
-- Secret: the step curve decides, and its answer goes straight to SetAlpha.
unitHealth, health.value = SECRET, SECRET
apiPercent = SECRET
curveAnswer, curveCalls = SECRET, 0
T.FromBar(health)
check(curveCalls > 0 and spark.alpha == SECRET, "with secret health the curve's answer is the spark's alpha", spark.alpha)
to = anchor()
check(to == driver.texture, "and the spark still rides the edge")

print(string.format("target health crop: %d checks, %d failures%s", checks, failures, mutation and (" (mutation " .. mutation .. ")") or ""))
os.exit(failures == 0 and 0 or 1)
