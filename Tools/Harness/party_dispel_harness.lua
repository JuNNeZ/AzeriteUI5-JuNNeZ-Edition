-- Party dispel glow and priority debuff with secret aura fields (FixLog 2026-10-16).
-- Loads the real Components/UnitFrames/Functions.lua (API.GetPlayerDispellableDebuff,
-- API.GetDebuffTypeColor) and Libs/oUF_Plugins/oUF_PriorityDebuff.lua against stubs
-- where secret values raise on comparison, arithmetic and concatenation.
-- Offline only: whether the game really keeps dispelName secret, and the dispel curve's
-- type IDs (1 Magic .. 4 Poison), are live checks.
-- Run: lua.exe Tools/Harness/party_dispel_harness.lua <addon root>
local root = arg[1] or '.'
local checks, failures = 0, 0
local function check(v, msg, detail)
	checks = checks + 1
	if (not v) then
		failures = failures + 1
		print("FAIL: " .. msg .. (detail ~= nil and (" - " .. tostring(detail)) or ""))
	end
end

local Any
Any = setmetatable({}, { __index = function() return Any end, __call = function() return Any end })
setmetatable(_G, { __index = function(_, k) return Any end })

local function raise(what) return function() error(what .. " a secret value", 2) end end
local secretMeta = {
	__lt = raise("compared"), __le = raise("compared"), __concat = raise("concatenated"),
	__add = raise("arithmetic on"), __sub = raise("arithmetic on"), __mul = raise("arithmetic on"),
	__div = raise("arithmetic on"), __len = raise("took the length of"),
}
local function secret(v) return setmetatable({ value = v }, secretMeta) end
issecretvalue = function(v) return getmetatable(v) == secretMeta end

-- The world: aura instances on party1, and which of them pass which filter.
local W = {}
local function Reset()
	W.auras, W.filters, W.filterCalls, W.colorCalls = {}, {}, {}, 0
end
Reset()
C_UnitAuras = {
	GetUnitAuraInstanceIDs = function(unit, filter)
		W.filterCalls[#W.filterCalls + 1] = filter
		return W.filters[filter] or {}
	end,
	GetAuraDataByAuraInstanceID = function(unit, id) return W.auras[id] end,
	GetAuraApplicationDisplayCount = function(unit, id) return secret("3") end,
	GetAuraDispelTypeColor = function(unit, id, curve)
		W.colorCalls = W.colorCalls + 1
		W.lastCurve = curve
		return { GetRGB = function() return secret(.2), secret(.6), secret(1) end }
	end,
}
local curvePoints
C_CurveUtil = { CreateColorCurve = function()
	curvePoints = {}
	return { SetType = function(self, t) self.type = t end, AddPoint = function(self, x, c) curvePoints[x] = c end }
end }
Enum = { LuaCurveType = { Linear = 0, Step = 1 } }
UnitCanAttack = function() return false end
UnitIsCharmed = function() return false end

local function color(r, g, b) return { r, g, b } end
local ns = { oUF = { isRetail = true }, API = {}, Colors = { debuff = {
	none = color(.8, 0, 0), Magic = color(.2, .6, 1), Curse = color(.8, 0, 1),
	Disease = color(.6, .4, 0), Poison = color(0, .6, 0) } } }
ns.API.TryCall = function(fn, ...) return pcall(fn, ...) end
ns.API.SafeCall = function(_, fn, ...) return pcall(fn, ...) end
ns.API.IsSafeNumber = function(v) return type(v) == "number" end
ns.API.DebugPrintf = function() end

assert(pcall(assert(loadfile(root .. "/Components/UnitFrames/Functions.lua")), "AzeriteUI5_JuNNeZ_Edition", ns))
local API = ns.API
check(type(API.GetPlayerDispellableDebuff) == "function" and type(API.GetDebuffTypeColor) == "function", "helpers exist")

--------------------------------------------------------------------------------
-- The helper
--------------------------------------------------------------------------------
do
	Reset()
	W.auras[11] = { auraInstanceID = 11, dispelName = "Poison" }
	W.auras[12] = { auraInstanceID = 12, dispelName = "Magic" }
	W.filters["HARMFUL|RAID"] = { 11, 12 }
	local id, data = API.GetPlayerDispellableDebuff("party1")
	check(W.filterCalls[1] == "HARMFUL|RAID", "the game's 'player can dispel' filter decides", W.filterCalls[1])
	check(id == 12, "readable types: Magic ranks above Poison", id)
	local r, g, b = API.GetDebuffTypeColor("party1", id, data)
	check(r == .2 and g == .6 and b == 1 and W.colorCalls == 0, "a readable type takes Colors.debuff, no curve")

	Reset()
	W.auras[11] = { auraInstanceID = 11, dispelName = secret("Poison") }
	W.auras[12] = { auraInstanceID = 12, dispelName = secret("Magic") }
	W.filters["HARMFUL|RAID"] = { 11, 12 }
	local okCall, sid, sdata = pcall(API.GetPlayerDispellableDebuff, "party1")
	check(okCall, "secret dispel names raise nothing", sid)
	check(sid == 11, "secret types: the first dispellable debuff", sid)
	local okColor, sr, sg, sb = pcall(API.GetDebuffTypeColor, "party1", sid, sdata)
	check(okColor and issecretvalue(sr) and issecretvalue(sb), "a secret type's colour comes from the game's curve, unread", sr)
	check(W.lastCurve and W.lastCurve.type == 1, "the curve steps (no blending between types)")
	check(curvePoints and curvePoints[1] and curvePoints[1].r == .2 and curvePoints[4] and curvePoints[4].g == .6,
		"curve points: 1 is Magic's colour, 4 is Poison's")

	Reset()
	check(API.GetPlayerDispellableDebuff("party1") == nil, "nothing dispellable: nil, so no glow")
end

--------------------------------------------------------------------------------
-- The priority debuff plugin
--------------------------------------------------------------------------------
local function LoadPlugin()
	local registered
	ns.oUF.AddElement = function(_, name, update, enable)
		registered = { update = update, enable = enable }
	end
	assert(pcall(assert(loadfile(root .. "/Libs/oUF_Plugins/oUF_PriorityDebuff.lua")), "AzeriteUI5_JuNNeZ_Edition", ns))
	local frame = { unit = "party1", events = {} }
	function frame:RegisterEvent(event, fn) self.events[event] = fn end
	local element = { shown = false, posts = {} }
	function element:Show() self.shown = true end
	function element:Hide() self.shown = false end
	function element:SetScript() end
	function element:SetMouseClickEnabled() end
	function element:SetMouseMotionEnabled() end
	element.icon = { SetTexture = function(self, t) self.texture = t end }
	element.count = { SetText = function(self, t) self.text = t end }
	element.PostUpdate = function(self, ...) self.posts[#self.posts + 1] = { ... } end
	frame.PriorityDebuff = element
	assert(registered.enable(frame, "party1"))
	local function Fire()
		local ok, err = pcall(frame.events.UNIT_AURA, frame, "UNIT_AURA", "party1")
		return ok, err
	end
	return frame, element, Fire
end

do
	local frame, element, Fire = LoadPlugin()

	-- Everything secret, one debuff the player can dispel.
	Reset()
	local icon = secret(136243)
	W.auras[21] = { auraInstanceID = 21, name = secret("Hex"), icon = icon, dispelName = secret("Curse"),
		spellId = secret(51514), isBossAura = secret(false) }
	W.filters["HARMFUL"] = { 21 }
	W.filters["HARMFUL|RAID"] = { 21 }
	local ok, err = Fire()
	check(ok, "a scan of secret auras raises nothing", err)
	check(element.shown, "a dispellable debuff with secret fields still shows the icon")
	check(element.icon.texture == icon, "its icon goes to the texture unread")
	check(issecretvalue(element.count.text), "its stack text comes from the game, unread")
	check(element.auraInstanceID == 21 and element.spellID == nil, "the tooltip gets the aura instance; no secret spellID kept")
	local post = element.posts[#element.posts]
	check(post and post[2] == true and post[6] == nil and post[12] == 21,
		"PostUpdate: shown, no secret debuffType, the aura instance for the colour")

	-- A readable boss debuff outranks the dispellable one.
	Reset()
	W.auras[21] = { auraInstanceID = 21, icon = 1, dispelName = "Magic", spellId = 1, isBossAura = false }
	W.auras[22] = { auraInstanceID = 22, icon = 2, dispelName = nil, spellId = 2, isBossAura = true }
	W.filters["HARMFUL"] = { 21, 22 }
	W.filters["HARMFUL|RAID"] = { 21 }
	Fire()
	check(element.auraInstanceID == 22, "a boss debuff ranks above a dispellable one", element.auraInstanceID)

	-- Nothing to show.
	Reset()
	Fire()
	check(not element.shown and element.auraInstanceID == nil, "no priority debuff: the icon hides")

	-- A debuff the player cannot dispel and that is no boss aura stays hidden.
	Reset()
	W.auras[23] = { auraInstanceID = 23, icon = 3, dispelName = "Magic", spellId = 3, isBossAura = false }
	W.filters["HARMFUL"] = { 23 }
	Fire()
	check(not element.shown, "a debuff the player cannot dispel does not show")
end

-- A client without instance queries keeps the index loop, which no longer stops at a
-- secret aura.
do
	local saved = C_UnitAuras
	C_UnitAuras = { GetAuraApplicationDisplayCount = saved.GetAuraApplicationDisplayCount }
	local list = {
		{ secret("Hidden"), 1, 1, secret("Magic"), 0, 0, nil, nil, nil, secret(9), nil, false },
		{ "Boss Thing", 2, 1, nil, 0, 0, nil, nil, nil, 77, nil, true },
	}
	UnitAura = function(unit, index) local a = list[index]; if (a) then return unpack(a, 1, 12) end end
	local _, element, Fire = LoadPlugin()
	local ok, err = Fire()
	check(ok, "the index loop raises nothing on a secret aura", err)
	check(element.shown and element.spellID == 77, "the index loop skips the secret aura and finds the boss debuff after it", element.spellID)
	C_UnitAuras = saved
	UnitAura = nil
end

print(string.format("Party dispel: %d checks, %d failures (offline only)", checks, failures))
if (failures > 0) then error("party dispel harness failed", 0) end
