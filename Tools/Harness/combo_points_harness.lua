-- Forever combo points arrive as secret values, even out of combat. This drives the real oUF
-- ClassPower element, the real PlayerClassPower style/PostUpdate and the real layout data with a
-- strict secret stand-in: type() says "number", issecretvalue() says true, and any arithmetic,
-- ordering comparison, concatenation or indexing throws. No claim of live WoW execution: the
-- StatusBar and mask textures below model Blizzard's documented behavior, they are not the client.
-- The masks follow EllesmereUI's Forever combo gate (EUI_UnitFrames_ForeverExtras.lua, UF_ComboGate):
-- a mask the gate's size riding its fill's right edge covers the art only while the gate is full.
-- FixLog 2026-11-13: points follow the target's count even when the player's power disagrees.
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
local noMasks = false
local function Widget(kind)
	local w = { kind = kind, shown = true, alpha = 1, min = 0, max = 1, value = 0, masks = {}, w = 0, h = 0 }
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
		self.texture.owner = self
		return self.texture
	end
	function w:CreateTexture() return Widget("Texture") end
	function w:SetSize(width, height) self.w, self.h = width, height end
	function w:GetSize() return self.w, self.h end
	function w:SetPoint(point, relativeTo, relativePoint) self.anchor = { point, relativeTo, relativePoint } end
	function w:SetTexture(file) self.file = file end
	function w:GetTexture() return self.file end
	function w:SetRotation(rotation) self.rotation = rotation end
	function w:GetRotation() return self.rotation or 0 end
	function w:SetVertexColor(r, g, b, a) self.color = { r, g, b, a } end
	function w:GetVertexColor() return unpack(self.color or { 1, 1, 1, 1 }) end
	function w:SetDrawLayer(layer, sublevel) self.layer, self.sublevel = layer, sublevel end
	function w:GetDrawLayer() return self.layer or "ARTWORK", self.sublevel or 0 end
	function w:AddMaskTexture(mask)
		assert(mask.kind == "MaskTexture", "AddMaskTexture needs a mask")
		self.masks[mask] = true
	end
	function w:RemoveMaskTexture(mask) self.masks[mask] = nil end
	if (not noMasks) then
		function w:CreateMaskTexture() return Widget("MaskTexture") end
	end
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
-- The player's power can lag or disagree with the target's count; nil means it agrees.
local playerCount, targetExists = nil, true
local function wrap(value)
	if plain then return value end
	return secret(value)
end
local function current()
	return wrap(count)
end
local function playerPower()
	return wrap(playerCount or count)
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
env.UnitPower = function() return playerPower() end
env.UnitExists = function(unit)
	if unit == "target" then return targetExists end
	return true
end
env.UnitPowerMax = function() return max end
env.GetComboPoints = function(unit, target)
	assert(unit == "player" and target == "target", "classic target-bound combo points")
	-- The client keeps no points without a target.
	if not targetExists then return wrap(0) end
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
	return secret(curve:Evaluate(((playerCount or count) / 5) * (1 - 1e-6)))
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
local ns, module, style, frame, cp, configs
local function build(forever)
	configs = {}
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
-- A mask is open when its gate is full (mask on the fill's right edge) or, for an inverse
-- mask (left edge on the fill's right edge), when the gate is empty. Counts are whole, so a
-- half-full gate means a wrong range.
local function maskOpen(mask)
	local fill = mask.anchor and mask.anchor[2]
	local gate = fill and fill.owner
	assert(gate and gate.kind == "StatusBar", "mask rides a gate's fill")
	assert(mask.w == gate.w and mask.h == gate.h and gate.w > 0, "mask is the gate's size")
	local f = gate:Fill()
	assert(f == 0 or f == 1, "gate half full")
	if mask.anchor[1] == "RIGHT" and mask.anchor[3] == "RIGHT" then return f == 1 end
	if mask.anchor[1] == "LEFT" and mask.anchor[3] == "RIGHT" then return f == 0 end
	error("unknown mask anchor")
end
local function drawn(region)
	if not region or not region.shown then return 0 end
	for mask in pairs(region.masks) do
		if not maskOpen(mask) then return 0 end
	end
	return reveal(region.alpha)
end
-- What each point shows: its alpha times its brightest visible case (the half-alpha socket
-- or the full-alpha copy over a filled point).
local function alphas()
	local out = {}
	for i = 1, 5 do
		local point = cp[i]
		local gates = point.__AzeriteUI_Gates
		local case = math.max(drawn(point.case), drawn(gates and gates.litCase))
		out[i] = point.shown and (reveal(point.alpha) * case) or "hidden"
	end
	return table.concat(out, ",")
end
-- The fill as drawn: the client's clamp, then the point's masks.
local function drawnFills()
	local out = {}
	for i = 1, 5 do
		local fill = cp[i]:GetStatusBarTexture()
		out[i] = (drawn(fill) > 0) and cp[i]:Fill() or 0
	end
	return table.concat(out, ",")
end
local function slotAlphas()
	local out = {}
	for i = 1, 5 do
		out[i] = cp[i].shown and reveal(cp[i].alpha) * drawn(cp[i].slot) or 0
	end
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
check(slotAlphas() == "0,0,0,0,0", "zero points hide slot backings: " .. slotAlphas())
check(not cp[6].shown, "only five points")

-- Stealth opener: one point.
count = 1
update()
check(fills() == "1,0,0,0,0", "one point filled by the client: " .. fills())
check(alphas() == "1,0.5,0.5,0.5,0.5", "filled point and empty sockets: " .. alphas())
check(slotAlphas() == "0.5,0.5,0.5,0.5,0.5", "secret sockets retain half-alpha backings: " .. slotAlphas())
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
check(slotAlphas() == "0,0,0,0,0", "full set hides slot backings out of combat: " .. slotAlphas())

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

-- Target-bound (FixLog 2026-11-13): the player's power may lag the target's count, and the
-- points follow the target. Out of combat, secret counts.
plain = false
count, playerCount = 3, 0
update()
check(fills() == "1,1,1,0,0", "target's three points fill: " .. fills())
check(alphas() == "1,1,1,0.5,0.5", "player power lagging at zero: " .. alphas())
local gates = cp[1].__AzeriteUI_Gates
check(gates and gates.any.w >= cp[1].case.w and gates.any.h >= cp[1].case.h
	and gates.lit.w >= cp[1].w + 2 * (configs.PlayerClassPower.ClassPowerSlotOffset or 0),
	"gates cover the point's art")
count, playerCount = 2, 5
update()
check(alphas() == "1,1,0.5,0.5,0.5", "player power ahead at five, target two, no fade: " .. alphas())
count, playerCount = 5, 1
update()
check(alphas() == "0,0,0,0,0" and drawnFills() == "0,0,0,0,0",
	"target's full set fades out of combat, fill too: " .. alphas() .. " / " .. drawnFills())
combat(true)
count, playerCount = 4, 0
update()
check(alphas() == "1,1,1,1,0.5" and drawnFills() == "1,1,1,1,0", "four in combat, player at zero: " .. alphas())
-- Points moved to a new target: the target change refreshes, and the count read is the target's.
count, playerCount = 1, 4
frame.events.PLAYER_TARGET_CHANGED(frame, "PLAYER_TARGET_CHANGED")
check(alphas() == "1,0.5,0.5,0.5,0.5", "new target's one point: " .. alphas())
-- No target: nothing lit, whatever the player's power says.
targetExists, playerCount = false, 3
frame.events.PLAYER_TARGET_CHANGED(frame, "PLAYER_TARGET_CHANGED")
check(fills() == "0,0,0,0,0", "no target fills nothing: " .. fills())
check(not cp:IsShown(), "no target hides the element")
targetExists, playerCount = true, nil
combat(false)

-- Plain again: the masks and the bright copy step aside for the numeric path.
plain, count, max = true, 3, 5
update()
check(not next(cp[1].case.masks) and not next(cp[1]:GetStatusBarTexture().masks)
	and reveal(cp[1].case.alpha) == 1 and not cp[1].__AzeriteUI_Gates.litCase.shown,
	"plain count clears the gates")
check(alphas() == "1,1,1,0.5,0.5", "plain count after secret: " .. alphas())
check(not next(cp[1].slot.masks) and slotAlphas() == "1,1,1,0.5,0.5", "plain count restores slot backing opacity")

-- First secret update on a fresh element (/reload with a target holding points): no style has
-- been laid out yet, so the gates must be sized after the layout, not from the unsized points.
plain, count, max, playerCount = false, 3, secret(5), 0
-- build() enables the element, and its ForceUpdate is that first update: check before any other.
build(true)
local fresh = true
for i = 1, 3 do
	local point, g = cp[i], cp[i].__AzeriteUI_Gates
	local offset = configs.PlayerClassPower.ClassPowerSlotOffset or 0
	fresh = fresh and g and point.case.w > 0
		and g.any.w >= point.case.w and g.any.h >= point.case.h
		and g.lit.w >= point.w + 2 * offset and g.open.w >= point.case.w
		and g.litCase.file ~= nil and g.litCase.file == point.case.file
		and g.litCase.w == point.case.w and g.litCase.h == point.case.h
end
check(fresh, "first secret update: gates and bright copy match the laid-out art")
check(alphas() == "1,1,1,0.5,0.5", "first secret update shows three points: " .. alphas())
playerCount = nil

-- Without mask support the display fails open rather than disappearing.
noMasks = true
build(true)
plain, count, max = false, 2, secret(5)
update()
check(cp:IsShown() and alphas() == "1,1,1,1,1", "no mask API: points stay visible: " .. alphas())
noMasks = false

-- Retail keeps its cached fallback: a secret count must not reach the points or PostUpdate.
env.UnitPowerPercent = function() error("Retail must not take the Forever curve path") end
env.GetComboPoints = function() error("Retail combo points are the player's power") end
plain, count, max = false, 3, 5
build(false)
update()
check(not isSecret(cp[1].value) and cp[3].min == 0 and cp[3].max == 1, "Retail points never take a secret")
check(not cp:IsShown(), "Retail secret count keeps the cached zero")
check(cp[1].__AzeriteUI_Gates == nil, "Retail builds no gates")
-- Retail combo points are the player's: no target does not clear them.
plain, count, targetExists = true, 2, false
update()
check(cp:IsShown() and fills() == "1,1,0,0,0" and alphas() == "1,1,0.5,0.5,0.5",
	"Retail plain points ignore the target: " .. alphas())
targetExists = true

print("Combo points: " .. checks .. " checks passed")
