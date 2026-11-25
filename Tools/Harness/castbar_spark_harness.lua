-- Castbar spark harness (offline only).
-- Loads Components/UnitFrames/Functions.lua and checks API.CreateCastBarSpark: the spark is
-- created once, hidden until oUF shows it, and on Show rides the fill texture's growing edge
-- for every orientation/reverse-fill combination, sized from the bar.
-- Run: lua Tools/Harness/castbar_spark_harness.lua <addon root>

local root = arg[1] or "."
local checks, failures = 0, 0
local function check(ok, label)
	checks = checks + 1
	if (not ok) then
		failures = failures + 1
		print("FAIL: " .. label)
	end
end

-- Permissive stub: any method call or field access works and returns another stub.
local function stub()
	return setmetatable({}, { __index = function(t, k) return function() return stub() end end, __call = function() return stub() end })
end

local function texture()
	local t = { shown = false, points = {} }
	function t:SetTexture(path) self.path = path end
	function t:SetBlendMode() end
	function t:SetVertexColor() end
	function t:Show() self.shown = true end
	function t:Hide() self.shown = false end
	function t:IsShown() return self.shown end
	function t:ClearAllPoints() self.points = {} end
	function t:SetPoint(...) self.points[#self.points + 1] = { ... } end
	function t:SetSize(w, h) self.w, self.h = w, h end
	function t:SetRotation(r) self.rotation = r end
	return t
end

local function castbar(orientation, reverse, w, h)
	local bar = { orientation = orientation, reverse = reverse, w = w, h = h, fill = texture() }
	function bar:GetOrientation() return self.orientation end
	function bar:GetReverseFill() return self.reverse end
	function bar:GetSize() return self.w, self.h end
	function bar:GetStatusBarTexture() return self.fill end
	function bar:CreateTexture() local t = texture(); self.created = (self.created or 0) + 1; return t end
	return bar
end

local env = setmetatable({}, { __index = function(_, k)
	local v = _G[k]
	if (v ~= nil) then return v end
	return stub()
end })
env.hooksecurefunc = function(obj, method, fn)
	local orig = obj[method]
	obj[method] = function(self, ...)
		local r = orig(self, ...)
		fn(self, ...)
		return r
	end
end
env.issecretvalue = function() return false end
env.Enum = { PowerType = { Mana = 0 } }

local ns = { API = {}, Colors = {}, oUF = stub() }
local chunk = assert(loadfile(root .. "/Components/UnitFrames/Functions.lua"))
setfenv(chunk, env)
chunk("AzeriteTest", ns)

local Create = ns.API.CreateCastBarSpark
check(type(Create) == "function", "API.CreateCastBarSpark exists")

local cases = {
	{ "HORIZONTAL", false, "RIGHT" },
	{ "HORIZONTAL", true, "LEFT" },
	{ "VERTICAL", false, "TOP" },
	{ "VERTICAL", true, "BOTTOM" },
}
for _, case in ipairs(cases) do
	local bar = castbar(case[1], case[2], 200, 20)
	local spark = Create(bar)
	local label = case[1] .. (case[2] and " reversed" or "")
	check(bar.Spark == spark, label .. ": stored as the oUF .Spark")
	check(not spark.shown, label .. ": hidden until a cast shows it")
	check(spark.path == [[Interface\CastingBar\UI-CastingBar-Spark]], label .. ": Blizzard spark texture")
	spark:Show() -- what oUF's CastStart does
	local p = spark.points[1]
	check(spark.shown and #spark.points == 1, label .. ": one anchor after Show")
	check(p and p[1] == "CENTER" and p[2] == bar.fill and p[3] == case[3], label .. ": rides the fill's " .. case[3] .. " edge")
	if (case[1] == "VERTICAL") then
		check(spark.w == 198 and spark.h == 12, label .. ": sized across the bar")
	else
		check(spark.w == 12 and spark.h == 18, label .. ": sized to the bar height")
	end
end

-- Layout changes between casts are picked up on the next Show.
local bar = castbar("HORIZONTAL", false, 100, 10)
local spark = Create(bar)
spark:Show()
bar.reverse, bar.h = true, 30
spark:Hide(); spark:Show()
check(spark.points[1][3] == "LEFT" and spark.h == 28, "re-anchors and resizes on the next cast")

-- Never replaces a unit's own spark, never creates twice.
local own = castbar("HORIZONTAL", false, 100, 10)
own.Spark = texture()
check(Create(own) == own.Spark and not own.created, "keeps an existing spark")
check(Create(bar) == spark and bar.created == 1, "second call returns the same spark")

-- Tiny bars still get a visible spark.
local tiny = castbar("HORIZONTAL", false, 60, 4)
local tinySpark = Create(tiny)
tinySpark:Show()
check(tinySpark.h == 8, "minimum height on thin bars")

print(string.format("Castbar spark: %d checks, %d failures (offline only)", checks, failures))
if (failures > 0) then os.exit(1) end
