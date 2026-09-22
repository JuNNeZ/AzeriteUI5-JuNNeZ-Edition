-- Forever combo points arrive as secret values, even out of combat. This drives the real oUF
-- ClassPower element, the real PlayerClassPower style/PostUpdate and the real layout data with a
-- strict secret stand-in: type() says "number", issecretvalue() says true, and any arithmetic,
-- ordering comparison, concatenation or indexing throws. No claim of live WoW execution: the
-- curve and StatusBar below model Blizzard's documented behavior, they are not the client.
-- lua Tools/Harness/combo_points_harness.lua .
local root = arg[1] or "."
local checks = 0
local function check(value, label)
	checks = checks + 1
	assert(value, label)
end
local function run(path, env, ...)
	local chunk = assert(loadfile(root .. "/" .. path))
	setfenv(chunk, env)
	return chunk(...)
end

-- Secret stand-in ------------------------------------------------------------
local hidden = setmetatable({}, { __mode = "k" })
local SecretMT = {}
for _, event in ipairs({ "__add", "__sub", "__mul", "__div", "__mod", "__pow", "__unm",
	"__concat", "__len", "__lt", "__le", "__eq", "__call", "__index", "__newindex" }) do
	SecretMT[event] = function() error("secret value used by addon code (" .. event .. ")", 2) end
end
local function secret(value)
	local proxy = setmetatable({}, SecretMT)
	hidden[proxy] = value
	return proxy
end
local function isSecret(value)
	return hidden[value] ~= nil
end
local function reveal(value)
	if isSecret(value) then return hidden[value] end
	return value
end

-- Widgets: only what the element and style touch, with real state -------------
local function Widget(kind)
	local w = { kind = kind, shown = true, alpha = 1, min = 0, max = 1, value = 0 }
	function w:Show() self.shown = true end
	function w:Hide() self.shown = false end
	function w:SetShown(show) self.shown = show and true or false end
	function w:IsShown() return self.shown end
	function w:SetAlpha(alpha)
		assert(type(alpha) == "number" or isSecret(alpha), "SetAlpha needs a number")
		self.alpha = alpha
	end
	function w:SetMinMaxValues(min, max) self.min, self.max = min, max end
	function w:GetMinMaxValues() return self.min, self.max end
	function w:SetValue(value)
		assert(value ~= nil, "SetValue needs a value")
		self.value = value
	end
	function w:GetValue() return self.value end
	function w:IsObjectType(objectType) return objectType == "StatusBar" and kind == "StatusBar" end
	function w:GetStatusBarTexture()
		self.texture = self.texture or Widget("Texture")
		return self.texture
	end
	function w:CreateTexture() return Widget("Texture") end
	function w:GetParent() return self.parent end
	function w:GetFrameLevel() return 1 end
	-- The drawn fill: a StatusBar clamps its value into [min, max].
	function w:Fill()
		local v, lo, hi = reveal(self.value), self.min, self.max
		if v <= lo then return 0 elseif v >= hi then return 1 end
		return (v - lo) / (hi - lo)
	end
	-- Unlisted setters are presentation only. Anything else stays nil: a catch-all would
	-- answer element.Override or __isEnabled with a function and skip the real update.
	return setmetatable(w, { __index = function(_, key)
		if type(key) == "string" and (key:match("^Set") or key:match("^Clear") or key:match("^Enable")
		or key:match("^Hook") or key:match("^RegisterFor")) then
			return function() end
		end
	end })
end

-- Client ---------------------------------------------------------------------
local count, max, plain = 0, secret(5), false
local function current()
	if plain then return count end
	return secret(count)
end
local env = setmetatable({}, { __index = _G })
env._G = env
env.type = function(value)
	if isSecret(value) then return "number" end
	return type(value)
end
env.issecretvalue = isSecret
env.Enum = { PowerType = { ComboPoints = 4, Energy = 3 }, LuaCurveType = { Linear = 0, Step = 1 } }
env.UnitClassBase = function() return "ROGUE" end
env.UnitIsUnit = function(a, b) return a == b end
env.UnitHasVehicleUI = function() return false end
env.UnitPowerType = function() return 3 end
env.UnitPower = function() return current() end
env.UnitPowerMax = function() return max end
env.GetComboPoints = function(unit, target)
	assert(unit == "player" and target == "target", "classic target-bound combo points")
	return current()
end
env.C_SpellBook = { IsSpellKnown = function() return true end }
env.C_CurveUtil = { CreateCurve = function()
	local curve = { points = {} }
	function curve:SetType(curveType) self.type = curveType end
	function curve:AddPoint(x, y)
		local last = self.points[#self.points]
		assert(not last or x > last[1], "curve points must be added in ascending order")
		self.points[#self.points + 1] = { x, y }
	end
	-- Step: snap to the last point at or below x. Player.lua's full-Mana crystal and
	-- Auras.lua's duration warning ship on the same reading of Blizzard's Step curve.
	function curve:Evaluate(x)
		assert(self.type == env.Enum.LuaCurveType.Step, "classpower curves are step curves")
		local y = self.points[1] and self.points[1][2] or 0
		for _, point in ipairs(self.points) do
			if x >= point[1] then y = point[2] end
		end
		return y
	end
	return curve
end }
env.UnitPowerPercent = function(unit, powerType, unmodified, curve)
	assert(unit == "player" and powerType == 4 and unmodified == false, "UnitPowerPercent arguments")
	-- The client computes the fraction in floating point; land just under the exact value so
	-- a threshold placed exactly on a whole count would be caught misreading it.
	return secret(curve:Evaluate((count / 5) * (1 - 1e-6)))
end
env.CreateFrame = function(kind, _, parent)
	local widget = Widget(kind)
	widget.parent = parent
	return widget
end
env.InCombatLockdown = function() return false end
env.UIParent = Widget("Frame")
env.hooksecurefunc = function() end
env.LibStub = function() return { GetLocale = function() return setmetatable({}, { __index = function(_, k) return k end }) end } end

-- Addon namespace and the frame the real style builds --------------------------
local ns, module, style, frame, cp
local function build(forever)
	local configs = {}
	module, style = {}, nil
	ns = { IsForever = forever, IsMainline = true, IsRetailContent = not forever, PlayerClass = "ROGUE",
		Prefix = "AzeriteUI_", Colors = setmetatable({}, { __index = function() return { 1, 1, 1 } end }),
		Noop = function() end, UnitFrameModule = {}, MovableModulePrototype = { defaults = {} } }
	ns.API = {
		GetMedia = function(name) return name end,
		GetFont = function() return {} end,
		IsAddOnEnabled = function() return false end,
		GetEffectiveScale = function() return 1 end,
		TryCall = pcall
	}
	ns.RegisterConfig = function(name, config) configs[name] = config end
	ns.GetConfig = function(name) return configs[name] end
	ns.Merge = function(_, a) return a end
	ns.NewModule = function() return module end
	ns.GetModule = function() return nil end
	ns.oUF = {
		AddElement = function(_, _, visibility, enable, disable)
			ns.__element = { visibility = visibility, enable = enable, disable = disable }
		end,
		RegisterStyle = function(_, _, func) style = func end,
		SetActiveStyle = function() end
	}
	ns.UnitFrame = { Spawn = function() return Widget("Frame") end }

	run("Layouts/Data/PlayerClassPower.lua", env, "AzeriteUI5_JuNNeZ_Edition", ns)
	run("Libs/oUF/elements/classpower.lua", env, "AzeriteUI5_JuNNeZ_Edition", ns)
	run("Components/UnitFrames/Units/PlayerClassPower.lua", env, "AzeriteUI5_JuNNeZ_Edition", ns)
	check(configs.PlayerClassPower and ns.__element, "real layout, element and module loaded")
	module.CreateUnitFrames(module)
	check(type(style) == "function", "real style registered")
	module.db = { profile = { showComboPoints = true, showFullOutOfCombat = false } }

	frame = Widget("Frame")
	frame.unit = "player"
	frame.events = {}
	frame.colors = { power = { COMBO_POINTS = { 1, .9, .3 } } }
	function frame:CreateBar(_, parent)
		local bar = Widget("StatusBar")
		bar.parent = parent
		return bar
	end
	function frame:RegisterEvent(event, func) self.events[event] = func end
	function frame:UnregisterEvent(event) self.events[event] = nil end
	style(frame, "player")
	cp = frame.ClassPower
	check(cp and cp.PostUpdate, "real PostUpdate attached")
	check(ns.__element.enable(frame, "player"), "element enables for the player")
	ns.__element.visibility(frame, "ForceUpdate", "player")
	check(frame.events.UNIT_POWER_FREQUENT, "power events registered")
end
build(true)

local function update()
	-- Same entry and payload the client uses for a combo point change.
	return frame.events.UNIT_POWER_FREQUENT(frame, "UNIT_POWER_FREQUENT", "player", "COMBO_POINTS")
end
local function combat(inCombat)
	local event = inCombat and "PLAYER_REGEN_DISABLED" or "PLAYER_REGEN_ENABLED"
	return frame.events[event](frame, event)
end
local function alphas()
	local out = {}
	for i = 1, 5 do out[i] = cp[i].shown and reveal(cp[i].alpha) or "hidden" end
	return table.concat(out, ",")
end
local function fills()
	local out = {}
	for i = 1, 5 do out[i] = cp[i]:Fill() end
	return table.concat(out, ",")
end

-- Out of combat, secret max falls back to 5, and nothing shows at zero.
update()
check(cp.__max == 5, "secret max falls back to five points")
check(cp:IsShown(), "secret count keeps the element up; alpha decides visibility")
check(alphas() == "0,0,0,0,0", "zero points invisible: " .. alphas())
check(not cp[6].shown, "only five points")

-- Stealth opener: one point.
count = 1
update()
check(fills() == "1,0,0,0,0", "one point filled by the client: " .. fills())
check(alphas() == "1,0.5,0.5,0.5,0.5", "filled point and empty sockets: " .. alphas())
check(isSecret(cp[1].value) and cp[3].min == 2 and cp[3].max == 3, "points clamp the secret themselves")

count = 3
update()
check(fills() == "1,1,1,0,0", "three points: " .. fills())
check(alphas() == "1,1,1,0.5,0.5", "three points alpha: " .. alphas())

-- A full set fades out of combat, as the numeric path does.
count = 5
update()
check(fills() == "1,1,1,1,1", "five points: " .. fills())
check(alphas() == "0,0,0,0,0", "full set fades out of combat: " .. alphas())

-- ...unless the player keeps it, and it always stays up in combat.
module.db.profile.showFullOutOfCombat = true
update()
check(alphas() == "1,1,1,1,1", "Show full out of combat keeps it: " .. alphas())
module.db.profile.showFullOutOfCombat = false
combat(true)
check(cp.inCombat, "real combat event reached the element")
check(alphas() == "1,1,1,1,1", "full set visible in combat: " .. alphas())

count = 4
update()
check(alphas() == "1,1,1,1,0.5", "four points in combat: " .. alphas())

-- Target switch (PLAYER_TARGET_CHANGED) is its own refresh path.
count = 0
check(frame.events.PLAYER_TARGET_CHANGED, "target change registered on Forever")
frame.events.PLAYER_TARGET_CHANGED(frame, "PLAYER_TARGET_CHANGED")
check(fills() == "0,0,0,0,0" and alphas() == "0,0,0,0,0", "target without points: " .. alphas())
combat(false)

-- Back to plain numbers: ranges are restored and the numeric path takes over.
-- (The element captured GetComboPoints at load, so the stub switches, not the global.)
plain, count, max = true, 2, 5
update()
check(cp[3].min == 0 and cp[3].max == 1, "point ranges restored")
check(fills() == "1,1,0,0,0", "plain count fills: " .. fills())
check(alphas() == "1,1,0.5,0.5,0.5", "plain count alpha: " .. alphas())
count = 0
update()
check(not cp:IsShown(), "plain zero still hides the element")

-- Without the curve API the display fails open rather than disappearing.
plain, count = false, 2
env.UnitPowerPercent = nil
update()
check(cp:IsShown() and alphas() == "1,1,1,1,1", "no curve API: points stay visible: " .. alphas())

-- Retail keeps its cached fallback: a secret count must not reach the points or PostUpdate.
env.UnitPowerPercent = function() error("Retail must not take the Forever curve path") end
plain, count, max = false, 3, 5
build(false)
update()
check(not isSecret(cp[1].value) and cp[3].min == 0 and cp[3].max == 1, "Retail points never take a secret")
check(not cp:IsShown(), "Retail secret count keeps the cached zero")

print("Combo points: " .. checks .. " checks passed")
