-- Nameplates: Phase 0 of Docs/Nameplates Overhaul Plan.md. A characterization harness.
--
-- It pins what the nameplate module (Components/UnitFrames/NamePlates/, one file until Phase 4) does,
-- so the staged refactor can prove it changed nothing it did not mean to. It loads the real module
-- in UnitFrames.xml's order, the real layout data
-- (Layouts/Layouts.lua, Layouts/Data/NamePlates.lua), the real colours, protected-call helpers,
-- scale and interrupt database, and drives them through a scripted session: ten plates of every
-- kind, targeting, soft targets, focus, mouseover, combat, auras, casts, settings and CVars.
--
-- Three kinds of output:
--   named checks   the behaviours the plan says must survive (object plates, name-only players,
--                  widget plates, castbar colours, the PRD ...). These say what is intended.
--   golden         every plate's visible state after every step, compared with
--                  Tools/Harness/nameplate_golden.txt. Only plates whose state changed at a step
--                  are written, so the file reads as a story. A deliberate behaviour change shows
--                  up as a reviewed diff and is re-recorded with --record.
--   metrics        widget calls and plates touched per step, the measure for Phase 3. Printed,
--                  and compared with nameplate_metrics.txt only when --metrics is passed.
--
-- Why not Tools/Harness/stubs.lua: that world answers the same for every unit, keeps combat off
-- and makes unknown C_* namespaces permissive. Nameplates need per-unit answers, combat that
-- toggles, and a loud nil for anything not modelled. Frames here answer nil for unknown methods,
-- as the game does, so a call to something unmodelled fails rather than passing quietly.
--
-- What it cannot see: rendering, taint, the real oUF elements (Health, Castbar, Auras are faked
-- at the point the module hooks them), and the order WoW delivers one event to several frames
-- (fixed here: driver, module, plain frames, plates, each in creation order). The native aura
-- container the plates draw auras with on Retail is faked too, as its unit, its on/off state and
-- its inputs; the real PlayerAuraContainers.lua drives it. Which auras it shows is the client's.
--
-- lua Tools/Harness/nameplate_harness.lua .              run checks, compare golden
-- lua Tools/Harness/nameplate_harness.lua . --record     rewrite the golden file
-- lua Tools/Harness/nameplate_harness.lua . --metrics    also compare metrics
-- lua Tools/Harness/nameplate_harness.lua . --record-metrics
-- Mutations: the "nameplate" entries in mutate_client.lua.

-- Everything this harness defines lives in its own environment rather than _G: mutate_client.lua
-- runs every harness in one Lua state, and a CreateFrame or C_Spell left behind here changed the
-- next harness's answers (its mutations were "caught" for the wrong reason). Reads fall through
-- to the real globals; every file loaded below runs in this environment too.
local E = setmetatable({}, { __index = _G })
setfenv(1, E)

local root = arg[1] or "."
local flags = {}
for i = 2, #arg do flags[arg[i]] = true end
local GOLDEN = root .. "/Tools/Harness/nameplate_golden.txt"
local METRICS = root .. "/Tools/Harness/nameplate_metrics.txt"

local checks, failures = 0, 0
local function check(value, label, detail)
	checks = checks + 1
	if (not value) then
		failures = failures + 1
		print("FAIL: " .. label .. (detail and (" - " .. tostring(detail)) or ""))
	end
end

local function round(v)
	if (type(v) ~= "number") then return tostring(v) end
	local s = string.format("%.3f", v)
	s = s:gsub("0+$", ""):gsub("%.$", "")
	if (s == "-0") then s = "0" end
	return s
end

--------------------------------------------------------------------------------
-- The world
--------------------------------------------------------------------------------
local W = {
	combat = false, time = 100, instance = { false, "none" },
	-- The nameplate CVars Retail 12.1 has, at the values the tests start from: the names in both clones'
	-- Blizzard_SettingsDefinitions_Frame/Nameplates.lua and the CVar registry. Nothing else exists, so a
	-- write to anything else is one the client would refuse (W.unknownCVarWrites).
	cvars = {
		nameplateShowAll = "1", nameplateShowEnemies = "1", nameplateShowFriendlyPlayers = "1",
		nameplateShowFriendlyNpcs = "1", nameplateSize = "2",
		nameplateShowDebuffsOnFriendly = "1", nameplateOtherAtBase = "0",
		nameplateMaxDistance = "60", nameplatePlayerMaxDistance = "60",
		nameplateMaxScale = "1", nameplateMinScale = "0.8", nameplateSelectedScale = "1.2", nameplateSimplifiedScale = "0.3",
		nameplateMaxScaleDistance = "10", nameplateMinScaleDistance = "10",
		nameplateMaxAlpha = "1", nameplateMinAlpha = "0.6", nameplateSelectedAlpha = "1",
		nameplateMaxAlphaDistance = "40", nameplateMinAlphaDistance = "10", nameplateOccludedAlphaMult = "0.4",
		nameplateTargetBehindMaxDistance = "0.1",
		nameplateShowOnlyNameForFriendlyPlayerUnits = "0", nameplateUseClassColorForFriendlyPlayerUnitNames = "0"
	},
	cvarWrites = {}, unknownCVarWrites = {}, reloads = 0, errors = {}, auraContainers = {},
	units = {}, alias = {}, plates = {}, cooldowns = {},
	calls = 0, touched = {}, callsByPlate = {}, methodsByPlate = {},
	nextFrame = {}, timers = {},
	frames = {}, ouf = {}, driver = nil, module = nil
}

-- A secret stand-in: comparison, arithmetic and concatenation raise; == answers false.
local SECRET = setmetatable({}, { __tostring = function() return "<secret>" end })
-- A secret number that still carries its value, as UnitHealthPercent hands one out: type() says
-- "number" as it does in the client, widgets take it, and addon arithmetic or comparison raises.
-- Reveal() is for the harness's own checks only.
local SecretNumber = {}
local function RaiseSecret() error("attempt to use a secret number in addon code", 2) end
for _, event in ipairs({ "__lt", "__le", "__add", "__sub", "__mul", "__div", "__mod", "__pow", "__unm", "__concat" }) do
	SecretNumber[event] = RaiseSecret
end
SecretNumber.__tostring = function(s) return "<secret " .. tostring(s.value) .. ">" end
local function SecretValue(value) return setmetatable({ value = value }, SecretNumber) end
local function IsSecretNumber(v) return getmetatable(v) == SecretNumber end
local function Reveal(v) if (IsSecretNumber(v)) then return v.value end return v end
local rawtype = type
function type(v) if (IsSecretNumber(v)) then return "number" end return rawtype(v) end
function issecretvalue(v) return v == SECRET or IsSecretNumber(v) end
function issecure() return false end

local function resolve(token)
	if (type(token) ~= "string") then return nil end
	local seen = 0
	while (W.alias[token] and seen < 5) do token = W.alias[token]; seen = seen + 1 end
	return W.units[token]
end

local function field(token, key)
	local rec = resolve(token)
	if (not rec) then return nil end
	if (rec.secret and rec.secret[key]) then return SECRET end
	return rec[key]
end

function UnitExists(u) return resolve(u) ~= nil end
function UnitIsUnit(a, b)
	local ra, rb = resolve(a), resolve(b)
	return (ra ~= nil and ra == rb) and true or false
end
function UnitName(u) return field(u, "name") end
function UnitGUID(u) return field(u, "guid") end
function UnitCanAttack(_, u) return field(u, "canAttack") or false end
function UnitCanAssist(_, u) return field(u, "canAssist") or false end
function UnitIsFriend(_, u) return field(u, "isFriend") or false end
function UnitReaction(a, b)
	local u = (a == "player") and b or a
	return field(u, "reaction")
end
function UnitIsPlayer(u) return field(u, "isPlayer") or false end
function UnitTreatAsPlayerForDisplay(u) return field(u, "treatAsPlayer") or false end
function UnitPlayerControlled(u) return field(u, "playerControlled") or false end
function UnitIsTrivial(u) return field(u, "trivial") or false end
function UnitClassification(u) return field(u, "classification") or "normal" end
function UnitCreatureType(u) return field(u, "creatureType") end
function UnitEffectiveLevel(u) return field(u, "level") or 80 end
function UnitIsDead(u) return field(u, "dead") or false end
function UnitIsConnected(u) local v = field(u, "connected"); if (v == nil) then return true end return v end
function UnitIsTapDenied(u) return field(u, "tapDenied") or false end
function UnitClass(u)
	local rec = resolve(u)
	if (not rec) then return nil end
	return rec.className or "Warrior", rec.class or "WARRIOR", rec.classID or 1
end
-- oUF asks with one token (threatindicator.lua:58), the module with two ("player", unit). A unit with
-- `threatBy` answers per group member (the combat filter's question), "secret" standing for a secret.
function UnitThreatSituation(a, b)
	local rec = b and resolve(b)
	if (rec and rec.threatBy) then
		local status = rec.threatBy[a]
		if (status == "secret") then return SECRET end
		return status
	end
	return field(b or a, "threat")
end
function UnitAffectingCombat(u) return field(u, "affectingCombat") or false end
-- The share of health left (`healthPercent`, full when unset), always secret. With a curve, the curve
-- is evaluated with that share as its input, inside the client, and the result is secret too.
function UnitHealthPercent(u, usePredicted, curve)
	W.healthPercentAsked = { unit = u, usePredicted = usePredicted }
	local percent = field(u, "healthPercent") or 1
	return SecretValue(curve and curve:Evaluate(percent) or percent)
end
function IsInRaid() return W.raid and true or false end
function IsInGroup() return (W.party or W.raid) and true or false end
function GetNumSubgroupMembers() return W.party or 0 end
function GetNumGroupMembers() return W.raid or 0 end
function UnitNameplateShowsWidgetsOnly(u) return field(u, "widgetsOnly") or false end
function UnitGetTotalAbsorbs() return 0 end
function UnitCastingInfo(u)
	local c = field(u, "casting")
	if (not c) then return nil end
	return c.name, c.name, 136243, 0, 1000, false, 1, c.notInterruptible, c.spellID, 1
end
function UnitChannelInfo(u)
	local c = field(u, "channeling")
	if (not c) then return nil end
	return c.name, c.name, 136243, 0, 1000, false, c.notInterruptible, c.spellID, false, 0
end

function InCombatLockdown() return W.combat end
function IsInInstance() return W.instance[1], W.instance[2] end
function GetTime() return W.time end
function LoadAddOn() end
function strsplit(sep, s)
	local out, pattern = {}, "([^" .. sep .. "]*)"
	for piece in (s .. sep):gmatch(pattern .. sep) do out[#out + 1] = piece end
	return unpack(out)
end
function CreateColor(r, g, b, a) return { r = r, g = g, b = b, a = a, rgba = { r, g, b, a } } end
function geterrorhandler() return function(msg) W.errors[#W.errors + 1] = msg end end

-- Bitfield CVars, as C_CVar.GetCVarBitfield / SetCVarBitfield see them: a bit per index.
W.bitfields = { nameplateStackingTypes = { [1] = true, [2] = false } }
W.cvars.nameplateStackingTypes = "stub" -- present: the client has Blizzard's stacking option
W.bitfieldWrites = {}
C_CVar = {
	GetCVarBitfield = function(name, index)
		local bits = W.bitfields[name]
		if (not bits) then return nil end
		return bits[index] == true
	end,
	SetCVarBitfield = function(name, index, value)
		assert(type(value) == "boolean", "SetCVarBitfield takes a boolean")
		W.bitfields[name] = W.bitfields[name] or {}
		W.bitfields[name][index] = value
		W.bitfieldWrites[#W.bitfieldWrites + 1] = name .. "[" .. index .. "]=" .. tostring(value)
		return true
	end,
	GetCVar = function(name) return W.cvars[name] end,
	GetCVarBool = function(name)
		local v = W.cvars[name]
		if (v == nil) then return nil end
		return v == "1"
	end,
	-- A CVar the client does not have is refused, as the client refuses it.
	SetCVar = function(name, value)
		if (W.cvars[name] == nil) then
			W.unknownCVarWrites[#W.unknownCVarWrites + 1] = name
			return false
		end
		W.cvars[name] = tostring(value)
		W.cvarWrites[#W.cvarWrites + 1] = name .. "=" .. tostring(value)
		return true
	end
}
C_UI = { Reload = function() W.reloads = W.reloads + 1 end }
C_ChallengeMode = { IsChallengeModeActive = function() return W.keyActive and true or false end }
C_Timer = { After = function(_, fn) W.nextFrame[#W.nextFrame + 1] = fn end }
C_NamePlate = { GetNamePlateForUnit = function(unit)
	local rec = resolve(unit)
	for token, plate in pairs(W.plates) do
		if (resolve(token) == rec and rec ~= nil and plate.__active) then return plate end
	end
	return nil
end }
C_Spell = { GetSpellCooldown = function(id)
	local cd = W.cooldowns[id]
	return { startTime = cd and cd.start or 0, duration = cd and cd.duration or 0, isEnabled = true, modRate = 1 }
end }
C_SpellBook = { IsSpellKnown = function() return true end }
C_UnitAuras = { GetPlayerAuraBySpellID = function() return nil end }
PlayerUtil = { GetCurrentSpecID = function() return 71 end }
Enum = { SpellBookSpellBank = { Player = 0, Pet = 1 }, PowerType = {}, NamePlateStackType = { None = 0, Enemy = 1, Friendly = 2 },
	LuaCurveType = { Linear = 0, Step = 1 } }
-- Step curves only, the kind the module makes: the value of the last point at or below the input.
W.curvesMade = 0
C_CurveUtil = { CreateCurve = function()
	W.curvesMade = W.curvesMade + 1
	local curve = { points = {} }
	function curve:SetType(kind) self.kind = kind end
	function curve:AddPoint(x, y)
		assert(rawtype(x) == "number" and rawtype(y) == "number", "AddPoint takes two plain numbers")
		self.points[#self.points + 1] = { x, y }
		table.sort(self.points, function(a, b) return a[1] < b[1] end)
	end
	function curve:Evaluate(x)
		assert(self.kind == Enum.LuaCurveType.Step, "only step curves are modelled")
		local y = self.points[1] and self.points[1][2]
		for _, point in ipairs(self.points) do if (point[1] <= x) then y = point[2] end end
		return y
	end
	return curve
end }
RAID_CLASS_COLORS = {
	WARRIOR = { r = .78, g = .61, b = .43 }, PRIEST = { r = 1, g = 1, b = 1 }, MAGE = { r = .25, g = .78, b = .92 }
}
ITEM_QUALITY_COLORS = { [0] = { r = .6, g = .6, b = .6 }, [1] = { r = 1, g = 1, b = 1 } }

--------------------------------------------------------------------------------
-- Frames
--------------------------------------------------------------------------------
local Region = {}
Region.__index = Region
local nextID = 0

local function count(self, name)
	W.calls = W.calls + 1
	local plate = self.__plate
	if (plate) then
		W.touched[plate] = true
		W.callsByPlate[plate] = (W.callsByPlate[plate] or 0) + 1
		if (self == plate) then
			local methods = W.methodsByPlate[plate] or {}
			methods[name] = (methods[name] or 0) + 1
			W.methodsByPlate[plate] = methods
		end
	end
end

local function NewRegion(kind, path, parent)
	nextID = nextID + 1
	local r = setmetatable({
		__kind = kind, __path = path, __id = nextID, __parentRegion = parent,
		__shown = true, __alpha = 1, __ignore = false, __scale = 1, __points = {}, __scripts = {},
		__level = parent and (parent.__level or 0) + 1 or 0, __events = {}, __unitEvents = {},
		__plate = parent and parent.__plate or nil
	}, Region)
	W.frames[#W.frames + 1] = r
	return r
end

local function fire(self, script, ...)
	local fn = self.__scripts[script]
	if (fn) then fn(self, ...) end
end

function Region:Show() count(self, "Show"); if (not self.__shown) then self.__shown = true; fire(self, "OnShow") end end
function Region:Hide() count(self, "Hide"); if (self.__shown) then self.__shown = false; fire(self, "OnHide") end end
function Region:SetShown(v) if (v) then self:Show() else self:Hide() end end
function Region:IsShown() return self.__shown end
function Region:IsVisible() return self.__shown end
function Region:SetAlpha(a) count(self, "SetAlpha"); self.__alpha = a end
function Region:GetAlpha() return self.__alpha end
function Region:SetIgnoreParentAlpha(v)
	count(self, "SetIgnoreParentAlpha")
	assert(type(v) == "boolean", "SetIgnoreParentAlpha takes a boolean on " .. self.__path)
	self.__ignore = v
end
function Region:SetPoint(point, a, b, c, d)
	count(self, "SetPoint")
	local rel, relPoint, x, y
	if (type(a) == "table") then rel, relPoint, x, y = a, b, c, d
	elseif (type(a) == "string") then rel, relPoint, x, y = nil, a, b, c
	else rel, relPoint, x, y = nil, point, a, b end
	self.__points[#self.__points + 1] = { point, rel, relPoint, x or 0, y or 0 }
end
function Region:ClearAllPoints() count(self, "ClearAllPoints"); self.__points = {} end
function Region:SetAllPoints(rel) count(self, "SetAllPoints"); self.__points = { { "ALL", rel } } end
function Region:SetSize(w, h) count(self, "SetSize"); self.__w, self.__h = w, h end
function Region:SetWidth(w) count(self, "SetWidth"); self.__w = w end
function Region:SetHeight(h) count(self, "SetHeight"); self.__h = h end
function Region:GetSize() return self.__w or 0, self.__h or 0 end
function Region:GetWidth() return self.__w or 0 end
function Region:GetHeight() return self.__h or 0 end
function Region:SetScale(s) count(self, "SetScale"); self.__scale = s end
function Region:GetScale() return self.__scale end
function Region:GetEffectiveScale() return self.__scale end
function Region:SetFrameLevel(l) count(self, "SetFrameLevel"); self.__level = l end
function Region:GetFrameLevel() return self.__level end
function Region:SetParent(p) count(self, "SetParent"); self.__parentRegion = p end
function Region:GetParent() return self.__parentRegion end
function Region:SetScript(name, fn) self.__scripts[name] = fn end
function Region:GetScript(name) return self.__scripts[name] end
function Region:HookScript(name, fn)
	local old = self.__scripts[name]
	self.__scripts[name] = function(...) if (old) then old(...) end fn(...) end
end
function Region:IsForbidden() return false end
function Region:GetName() return self.__name end
function Region:EnableMouse() end
function Region:SetClipsChildren(v) self.__clips = v end
-- Textures and fontstrings
function Region:SetTexture(t) count(self, "SetTexture"); self.__texture = t end
function Region:GetTexture() return self.__texture end
function Region:SetTexCoord(...) count(self, "SetTexCoord"); self.__texcoord = { ... } end
function Region:GetTexCoord() local t = self.__texcoord or { 0, 1, 0, 1 }; return t[1], t[2], t[3], t[4] end
function Region:SetVertexColor(r, g, b, a) count(self, "SetVertexColor"); self.__vertex = { r, g, b, a } end
function Region:SetVertexColorFromBoolean(v, yes, no)
	count(self, "SetVertexColorFromBoolean")
	self.__fromBoolean = { v, yes and yes.rgba, no and no.rgba }
end
function Region:SetText(t) count(self, "SetText"); self.__text = t end
function Region:GetText() return self.__text end
function Region:SetTextColor(r, g, b, a) count(self, "SetTextColor"); self.__textColor = { r, g, b, a } end
function Region:SetFontObject(f) count(self, "SetFontObject"); self.__font = f end
function Region:GetFont()
	local f = self.__font
	return "font", f and f.size or 12, f and f.outline and "OUTLINE" or ""
end
function Region:SetJustifyH(v) self.__justifyH = v end
function Region:SetJustifyV(v) self.__justifyV = v end
function Region:SetWordWrap(v) self.__wordWrap = v end
function Region:CreateTexture(_, layer)
	count(self, "CreateTexture")
	return NewRegion("Texture", self.__path .. ".tex" .. (nextID + 1), self)
end
function Region:CreateFontString(_, layer)
	count(self, "CreateFontString")
	return NewRegion("FontString", self.__path .. ".fs" .. (nextID + 1), self)
end
function Region:CreateMaskTexture() return NewRegion("MaskTexture", self.__path .. ".mask", self) end
-- Status bars (the addon's own CreateBar bars and plain StatusBars)
function Region:SetStatusBarTexture(t)
	count(self, "SetStatusBarTexture")
	self.__barTexture = t
	self.__statusTexture = self.__statusTexture or NewRegion("Texture", self.__path .. ".bar", self)
	self.__statusTexture.__texture = t
end
function Region:GetStatusBarTexture()
	self.__statusTexture = self.__statusTexture or NewRegion("Texture", self.__path .. ".bar", self)
	return self.__statusTexture
end
function Region:SetStatusBarColor(r, g, b, a) count(self, "SetStatusBarColor"); self.__barColor = { r, g, b, a } end
function Region:SetOrientation(o) count(self, "SetOrientation"); self.__orientation = o end
function Region:SetReverseFill(v) count(self, "SetReverseFill"); self.__reverse = v end
function Region:GetReverseFill() return self.__reverse and true or false end
function Region:SetFlippedHorizontally(v) count(self, "SetFlippedHorizontally"); self.__flipped = v end
function Region:IsFlippedHorizontally() return self.__flipped end
function Region:SetSparkMap(m) count(self, "SetSparkMap"); self.__spark = m end
function Region:SetSparkTexture(t) self.__sparkTexture = t end
function Region:SetForceNative(v) self.__native = v end
function Region:DisableSmoothing(v) self.__noSmooth = v end
function Region:SetValue(v) count(self, "SetValue"); self.__value = v end
function Region:GetValue() return self.__value or 0 end
function Region:SetMinMaxValues(a, b) self.__min, self.__max = a, b end
function Region:GetMinMaxValues() return self.__min or 0, self.__max or 1 end
function Region:GetGrowth() return self.__orientation end
-- Plain frames: WoW's own event API
function Region:RegisterEvent(event) self.__events[event] = true end
function Region:RegisterUnitEvent(event, ...) self.__unitEvents[event] = { ... } end
function Region:UnregisterAllEvents() self.__events = {}; self.__unitEvents = {} end

--------------------------------------------------------------------------------
-- Blizzard's aura container, as PlayerAuraContainers.lua drives it on the plates
--------------------------------------------------------------------------------
-- Retail draws nameplate auras through it (CreateForNamePlate), because a Lua scan of C_UnitAuras
-- comes back empty in combat. It fills itself engine side, so what is kept here is what the addon
-- can know: the unit it was pointed at, whether it is enabled, and how often it was told to read its
-- unit again (UpdateAllAuras). Its inputs are checked the way Blizzard_CustomAuraContainer.lua
-- checks them, plus unknown keys, so a misspelt filter fails here rather than quietly in the game.
AuraContainerSortMethod = { Default = 0, BigDefensive = 1, UnitFrameDebuff = 2, ImportantOnly = 3, Expiration = 4,
	ExpirationOnly = 5, Name = 6, NameOnly = 7, AuraInstanceIDOnly = 8 }
AuraContainerSortDirection = { Normal = 0, Reverse = 1 }
AnchorUtil = { FlowDirection = { Left = -1, Right = 1, Up = 1, Down = -1 } }
C_XMLUtil = { GetTemplateInfo = function(name)
	if (name == "CustomAuraContainerTemplate" and not W.noAuraContainer) then return { type = "AuraContainer" } end
end }
-- AuraUtil.AuraFilters and IsValidFilterString, Blizzard_FrameXMLUtil/AuraUtil.lua (12.1.0).
local AURA_FILTER_TOKENS = {}
for _, token in ipairs({ "HELPFUL", "HARMFUL", "PLAYER", "RAID", "CANCELABLE", "INCLUDE_NAME_PLATE_ONLY", "MAW",
	"EXTERNAL_DEFENSIVE", "CROWD_CONTROL", "RAID_IN_COMBAT", "RAID_PLAYER_DISPELLABLE", "BIG_DEFENSIVE", "IMPORTANT",
	"DISPELLABLE" }) do
	AURA_FILTER_TOKENS[token] = true
end
AuraUtil = { IsValidFilterString = function(filterString)
	for component in (filterString .. "|"):gmatch("([^| ]*)[| ]") do
		local negated = component:sub(1, 1) == "!"
		if (negated) then component = component:sub(2) end
		if (negated and component == "") then return false end
		if (component ~= "" and not AURA_FILTER_TOKENS[component]) then return false end
	end
	return true
end }
function Mixin(object, ...)
	for i = 1, select("#", ...) do
		for k, v in pairs((select(i, ...))) do object[k] = v end
	end
	return object
end
function CreateFromMixins(...) return Mixin({}, ...) end

local function Set(...)
	local t = {}
	for i = 1, select("#", ...) do t[select(i, ...)] = true end
	return t
end
local GROUP_OPTIONS = Set("templateNames", "initializeFrame", "candidateFilters", "maxFrameCount", "sortMethod",
	"sortDirection", "layout")
local LAYOUT_OPTIONS = Set("elementSpacing", "lineSpacing", "groupSpacing", "groupLineSpacing", "forceNewLine",
	"elementWidth", "elementHeight", "layoutIndex")
local CANDIDATE_TABLES = Set("includeSpellIDs", "excludeSpellIDs", "includeDispelTypes", "excludeDispelTypes")
local CANDIDATE_BOOLEANS = Set("isFromPlayerOrPlayerPet", "isRoleAura", "isPriorityAura", "isStealable",
	"nameplateShowAll", "nameplateShowPersonal", "canApplyAura", "isBossAura", "isBossOrRoleAura")
local function IsEnumValue(enum, value)
	for _, v in pairs(enum) do if (v == value) then return true end end
	return false
end

local AuraContainer = setmetatable({}, { __index = Region })
AuraContainer.__index = AuraContainer
function AuraContainer:SetUnit(unit)
	assert(type(unit) == "string", "SetUnit takes a unit token")
	if (unit ~= self.__unit) then
		self.__unit = unit
		self.__rebuilds = self.__rebuilds + 1
	end
end
function AuraContainer:SetEnabled(enabled)
	if (enabled ~= self.__on) then
		self.__on = enabled
		self.__rebuilds = self.__rebuilds + 1
	end
end
function AuraContainer:UpdateAllAuras() self.__rebuilds = self.__rebuilds + 1 end
function AuraContainer:SetFlowLayoutAnchorPoint(point) assert(type(point) == "string", "anchor point") end
function AuraContainer:SetFlowLayoutGrowthDirection(h, v) assert(type(h) == "number" and type(v) == "number", "growth") end
function AuraContainer:SetFlowLayoutMaximumLineSize(size) assert(type(size) == "number" and size >= 0, "line size") end
local function CheckMaxFrameCount(maxCount)
	assert(maxCount == math.huge or (type(maxCount) == "number" and maxCount >= 0 and maxCount == math.floor(maxCount)),
		"maxFrameCount")
end
local function CheckCandidateFilters(filters)
	for k, v in pairs(filters or {}) do
		if (CANDIDATE_TABLES[k]) then assert(type(v) == "table", k)
		elseif (CANDIDATE_BOOLEANS[k]) then assert(type(v) == "boolean", k)
		elseif (k == "maxDuration") then assert(type(v) == "number" and v >= 0, k)
		else error("unknown candidate filter " .. tostring(k)) end
	end
end
local function RequireGroup(container, key)
	local group = container.__groups[key]
	assert(group, "aura group '" .. tostring(key) .. "' was not found with this key")
	return group
end
function AuraContainer:AddAuraGroup(key, filterString, options)
	assert(type(key) == "string" and key ~= "", "groupKey must be a non-empty string")
	assert(not self.__groups[key], "aura group '" .. key .. "' already exists")
	assert(AuraUtil.IsValidFilterString(filterString), "invalid filter string " .. tostring(filterString))
	for k in pairs(options) do assert(GROUP_OPTIONS[k], "unknown group option " .. tostring(k)) end
	assert(type(options.initializeFrame) == "function", "initializeFrame")
	assert(IsEnumValue(AuraContainerSortMethod, options.sortMethod), "sortMethod")
	assert(IsEnumValue(AuraContainerSortDirection, options.sortDirection), "sortDirection")
	CheckMaxFrameCount(options.maxFrameCount)
	CheckCandidateFilters(options.candidateFilters)
	for k, v in pairs(options.layout or {}) do
		assert(LAYOUT_OPTIONS[k], "unknown layout option " .. tostring(k))
		assert(type(v) == "number" or (k == "forceNewLine" and type(v) == "boolean"), k)
	end
	self.__groups[key] = { filter = filterString, candidateFilters = options.candidateFilters, maxFrameCount = options.maxFrameCount }
	self.__groupOrder[#self.__groupOrder + 1] = key
end
-- The three setters a configuration pass uses. The first and last compare before they act; the
-- candidate filters rebuild the container on every call (Blizzard_CustomAuraContainer.lua).
function AuraContainer:SetAuraGroupFilterString(key, filterString)
	local group = RequireGroup(self, key)
	assert(AuraUtil.IsValidFilterString(filterString), "invalid filter string " .. tostring(filterString))
	if (group.filter ~= filterString) then
		group.filter = filterString
		self.__rebuilds = self.__rebuilds + 1
	end
end
function AuraContainer:SetAuraGroupCandidateFilters(key, filters)
	local group = RequireGroup(self, key)
	CheckCandidateFilters(filters)
	group.candidateFilters = filters
	self.__rebuilds = self.__rebuilds + 1
end
function AuraContainer:SetAuraGroupMaxFrameCount(key, maxCount)
	local group = RequireGroup(self, key)
	CheckMaxFrameCount(maxCount)
	group.maxFrameCount = maxCount
end

function CreateFrame(kind, name, parent, template)
	local r = NewRegion(kind or "Frame", name or ((parent and parent.__path or "UIParent") .. "." .. (kind or "Frame") .. (nextID + 1)), parent)
	r.__name = name
	if (kind == "AuraContainer") then
		setmetatable(r, AuraContainer)
		r.__rebuilds, r.__groups, r.__groupOrder = 0, {}, {}
		W.auraContainers[#W.auraContainers + 1] = r
	end
	return r
end

UIParent = NewRegion("Frame", "UIParent")
UIParent.__plate = nil

function hooksecurefunc(obj, method, fn)
	if (type(obj) == "string") then obj, method, fn = E, obj, method end
	local old = obj[method]
	obj[method] = function(...) local r = { old(...) }; fn(...); return unpack(r) end
end

--------------------------------------------------------------------------------
-- oUF, as the nameplate driver in Libs/oUF/ouf.lua:1000-1070 uses it
--------------------------------------------------------------------------------
local ELEMENTS = { "Health", "Power", "Castbar", "Auras", "RaidTargetIndicator", "HealthPrediction", "ThreatIndicator" }
local Plate = setmetatable({}, { __index = Region })
Plate.__index = Plate

function Plate:RegisterEvent(event, fn, unitless)
	self.__oufEvents[event] = { fn = fn, unitless = unitless }
end
function Plate:EnableElement(name)
	count(self, "EnableElement")
	local element = self[name]
	if (not element) then return end
	self.__enabled[name] = true
	element.__owner = self
	element.ForceUpdate = function(el) count(self, "ForceUpdate"); self:UpdateElement(name) end
	-- What each real Enable does to visibility: castbar.lua:728 hides, auras shows, the raid
	-- marker and threat glow wait for their first update.
	if (name == "Castbar") then element:Hide()
	elseif (name == "Auras") then element:Show() end
end
function Plate:DisableElement(name)
	count(self, "DisableElement")
	local element = self[name]
	if (not element or not self.__enabled[name]) then return end
	self.__enabled[name] = nil
	if (element.Hide) then element:Hide() end
end
function Plate:IsElementEnabled(name) return self.__enabled[name] and true or false end
function Plate:CreateBar(name, parent)
	count(self, "CreateBar")
	return NewRegion("StatusBar", self.__path .. ".bar" .. (nextID + 1), parent or self)
end
function Plate:Tag(fs, tag)
	fs.__tag = tag
	fs.UpdateTag = function(this)
		local unit = self.unit
		if (tag:find("Name")) then
			local name = unit and UnitName(unit)
			this:SetText(type(name) == "string" and name or "")
		else
			this:SetText(unit and "100%" or "")
		end
	end
end
-- A faithful subset: each fake element does what its real Update does to what the module reads.
function Plate:UpdateElement(name, event)
	if (not self.__enabled[name]) then return end
	local unit = self.unit
	local rec = resolve(unit)
	if (name == "Health" and self.Health.UpdateColor) then
		self.Health.UpdateColor(self, event, unit)
	elseif (name == "Auras") then
		local n = rec and rec.auras or 0
		self.Auras.sortedBuffs, self.Auras.sortedDebuffs = {}, {}
		for i = 1, n do self.Auras.sortedDebuffs[i] = i end
		if (self.Auras.PostUpdate) then self.Auras:PostUpdate(unit) end
	elseif (name == "RaidTargetIndicator") then
		self.RaidTargetIndicator:SetShown(rec and rec.raidTarget ~= nil) -- raidtargetindicator.lua:43-48
	elseif (name == "ThreatIndicator") then
		local status = UnitThreatSituation(unit)
		self.ThreatIndicator:SetShown(type(status) == "number" and status > 0) -- threatindicator.lua:63-72
	elseif (name == "Castbar") then
		-- CastStart (castbar.lua:240-364): a running cast is set up and shown; none clears the
		-- flags and hides the bar, which is what brings back a bar whose cast ended while hidden.
		local bar, cast = self.Castbar, rec and rec.casting
		if (cast) then
			bar.casting, bar.notInterruptible, bar.spellID = true, cast.notInterruptible, cast.spellID
			bar.Text:SetText(cast.name)
			if (bar.PostCastStart) then bar.PostCastStart(bar, unit) end
			bar:Show()
		else
			bar.casting, bar.channeling, bar.notInterruptible, bar.spellID = nil, nil, nil, nil
			bar:Hide()
		end
	end
end
function Plate:UpdateAllElements(event)
	count(self, "UpdateAllElements")
	if (not self.unit or not UnitExists(self.unit)) then return end
	for _, name in ipairs(ELEMENTS) do self:UpdateElement(name, event) end
	if (self.PostUpdate) then self:PostUpdate(event) end
end

local style
local ns_oUF = {
	RegisterStyle = function(_, name, fn) style = fn end,
	SetActiveStyle = function() end,
	RegisterInitCallback = function() end,
	SpawnNamePlates = function(_, prefix)
		local driver = { cvars = {} }
		function driver:SetAddedCallback(fn) self.added = fn end
		function driver:SetRemovedCallback(fn) self.removed = fn end
		function driver:SetTargetCallback(fn) self.targetCb = fn end
		function driver:SetSize(w, h) self.plateWidth, self.plateHeight = w, h end
		function driver:SetCVars(values)
			for k, v in pairs(values) do self.cvars[k] = v; C_CVar.SetCVar(k, v) end
		end
		W.driver = driver
		return driver
	end
}

-- Blizzard's own nameplate for a unit token, with the pieces the module and oUF reach for.
local function NewBlizzardPlate(token)
	local plate = NewRegion("Frame", "NamePlate[" .. token .. "]", UIParent)
	local UF = NewRegion("Button", plate.__path .. ".UnitFrame", plate)
	UF.healthBar = NewRegion("StatusBar", UF.__path .. ".healthBar", UF)
	UF.name = NewRegion("FontString", UF.__path .. ".name", UF)
	UF.RaidTargetFrame = NewRegion("Frame", UF.__path .. ".RaidTargetFrame", UF)
	UF.ClassificationFrame = NewRegion("Frame", UF.__path .. ".ClassificationFrame", UF)
	UF.PlayerLevelDiffFrame = NewRegion("Frame", UF.__path .. ".PlayerLevelDiffFrame", UF)
	UF.WidgetContainer = NewRegion("Frame", UF.__path .. ".WidgetContainer", UF)
	UF.WidgetContainer.numWidgetsShowing = 0
	UF.WidgetContainer.widgetFrames = {}
	UF.SoftTargetFrame = NewRegion("Frame", UF.__path .. ".SoftTargetFrame", UF)
	plate.UnitFrame = UF
	plate.__active = false
	return plate
end

local plateOrder = {}
local function Driver(event, unit)
	local driver = W.driver
	if (event == "PLAYER_TARGET_CHANGED") then
		local nameplate = C_NamePlate.GetNamePlateForUnit("target")
		if (not nameplate or not nameplate.unitFrame) then return end
		if (driver.targetCb) then driver.targetCb(nameplate.unitFrame, event, "target") end
		nameplate.unitFrame:UpdateAllElements(event)
	elseif (event == "NAME_PLATE_UNIT_ADDED") then
		local nameplate = W.plates[unit]
		nameplate.__active = true
		if (not nameplate.unitFrame) then
			local f = NewRegion("Button", "Plate" .. (#plateOrder + 1), nameplate)
			setmetatable(f, Plate)
			f.__plate = f
			f.__oufEvents, f.__enabled = {}, {}
			f.isNamePlate = true
			f.unit = unit
			f.blizzPlate = nameplate
			nameplate.unitFrame = f
			plateOrder[#plateOrder + 1] = f
			f.__index = #plateOrder
			style(f, unit)
			for _, name in ipairs(ELEMENTS) do
				if (f[name]) then f:EnableElement(name) end
			end
		else
			nameplate.unitFrame.unit = unit
		end
		local f = nameplate.unitFrame
		local UF = nameplate.UnitFrame
		UF.WidgetContainer:SetParent(f); UF.WidgetContainer:SetIgnoreParentAlpha(true)
		f.WidgetContainer = UF.WidgetContainer
		UF.SoftTargetFrame:SetParent(f); UF.SoftTargetFrame:SetIgnoreParentAlpha(true)
		f.SoftTargetFrame = UF.SoftTargetFrame
		if (driver.added) then driver.added(f, event, unit) end
		f:UpdateAllElements(event)
	elseif (event == "NAME_PLATE_UNIT_REMOVED") then
		local nameplate = W.plates[unit]
		local f = nameplate and nameplate.unitFrame
		if (not f) then return end
		if (driver.removed) then driver.removed(f, event, unit) end
		nameplate.__active = false
		fire(f, "OnHide")
		f.unit = nil
	end
end

-- One event to everyone registered for it, in a fixed order.
local function Fire(event, ...)
	if (event == "NAME_PLATE_UNIT_ADDED" or event == "NAME_PLATE_UNIT_REMOVED" or event == "PLAYER_TARGET_CHANGED") then
		Driver(event, ...)
	end
	local module = W.module
	if (module and module.__events[event]) then
		local handler = module.__events[event]
		if (type(handler) == "string") then module[handler](module, event, ...) else handler(module, event, ...) end
	end
	local unit = ...
	for i = 1, #W.frames do
		local f = W.frames[i]
		if (getmetatable(f) == Region and (f.__events[event] or (f.__unitEvents[event] and (function()
			for _, u in ipairs(f.__unitEvents[event]) do if (u == unit) then return true end end
		end)()))) then
			fire(f, "OnEvent", event, ...)
		end
	end
	for _, f in ipairs(plateOrder) do
		local reg = f.__oufEvents[event]
		if (reg and f.blizzPlate.__active and (reg.unitless or unit == f.unit)) then
			reg.fn(f, event, ...)
		end
	end
end

local function Flush()
	while (#W.nextFrame > 0) do
		local queue = W.nextFrame
		W.nextFrame = {}
		for _, fn in ipairs(queue) do fn() end
	end
end

-- One pass of every repeating timer still scheduled (a cancelled one is left as false).
local function Tick()
	for _, fn in ipairs(W.timers) do if (fn) then fn() end end
end
local function RunningTimers()
	local n = 0
	for _, fn in ipairs(W.timers) do if (fn) then n = n + 1 end end
	return n
end

--------------------------------------------------------------------------------
-- The addon namespace
--------------------------------------------------------------------------------
local ns = { Private = {}, API = {}, Prefix = "AzeriteUI5_JuNNeZ_Edition", IsRetail = true, IsForever = false }
setmetatable(ns, { __index = ns.Private })
ns.oUF = ns_oUF
ns.Noop = function() end
ns.MovableModulePrototype = { defaults = {} }
ns.db = { global = { enableDevelopmentMode = false }, RegisterNamespace = function(_, name, defaults)
	local profile = {}
	for k, v in pairs(defaults.profile) do profile[k] = v end
	W.profile = profile
	return { profile = profile }
end }
ns.AuraFilters = { NameplateAuraFilter = function() return true end }
ns.AuraStyles = { CreateSmallButton = function() end, NameplatePostUpdateButton = function() end }
ns.AuraSorts = { Default = function() end, DefaultFunction = function() end, Alternate = function() end, AlternateFuncton = function() end }
ns.UnitFrame = { ShouldColorCastSpellTextByState = function() return W.colorSpellText and true or false end }
local unitFramesModule = { db = { global = { disableAuraSorting = false } } }
ns.GetModule = function(_, name) return name == "UnitFrames" and unitFramesModule or nil end
ns.NewModule = function(_, name)
	local m = { __events = {}, __enabled = true, __name = name }
	function m:RegisterEvent(event, handler) self.__events[event] = handler or event end
	function m:UnregisterEvent(event) self.__events[event] = nil end
	function m:ScheduleRepeatingTimer(fn) W.timers[#W.timers + 1] = fn; return #W.timers end
	function m:CancelTimer(handle) if (handle) then W.timers[handle] = false end end
	function m:IsEnabled() return self.__enabled end
	function m:Disable() self.__enabled = false end
	W.module = m
	return m
end
-- Functions.lua's API, reduced to the semantics the module relies on (Functions.lua:823-852).
ns.API.IsAddOnEnabled = function(name) return W.addons and W.addons[name] or false end
ns.API.UpdateHealth = function() end
ns.API.UpdatePower = function() end
ns.API.BindStatusBarValueMirror = function() end
ns.API.AttachScriptSafe = function(frame, script, fn) frame:HookScript(script, fn) end
ns.API.UpdateInterruptCastBarRefresh = function(castbar, cb, reason)
	if (not castbar) then return nil end
	if (type(cb) == "function") then castbar.__AzeriteUI_InterruptRefreshCallback = cb end
	local callback = castbar.__AzeriteUI_InterruptRefreshCallback
	if (type(callback) == "function") then callback(castbar, reason) end
	return castbar.__AzeriteUI_InterruptCastState
end
ns.API.ClearInterruptCastBarRefresh = function(castbar)
	if (not castbar) then return end
	castbar.__AzeriteUI_InterruptRefreshCallback = nil
	castbar.__AzeriteUI_LastInterruptColorUpdate = nil
	castbar.__AzeriteUI_InterruptCastState = nil
end
ns.API.GetMedia = function(name, kind) return "Assets\\" .. name .. "." .. (kind or "tga") end
ns.API.GetFont = function(size, outline) return { size = size, outline = outline and true or false } end
ns.API.IsSafeBool = function(value) return type(value) == "boolean" and not issecretvalue(value) end -- SecretValues.lua:71

local function load(relative)
	local chunk = assert(loadfile(root .. "/" .. relative))
	setfenv(chunk, E)
	chunk("AzeriteUI5_JuNNeZ_Edition", ns)
end

load("Core/API/Tables.lua")
load("Core/API/ProtectedCall.lua")
load("Core/API/Scale.lua")
load("Core/Common/Colors.lua")
load("Layouts/Layouts.lua")
load("Layouts/Data/NamePlates.lua")
load("Components/UnitFrames/NameplateInterruptDB.lua")
-- The real one: the player's interrupt, which the target castbar asks as well (Phase 5).
load("Components/UnitFrames/Interrupts.lua")
-- The real one: the player's execute threshold, which the execute marker reads (Phase 8).
load("Components/UnitFrames/ExecuteRange.lua")
-- The real one: the plates build their native aura displays through it (CreateForNamePlate).
load("Components/UnitFrames/Auras/PlayerAuraContainers.lua")
-- The module's files, in the order UnitFrames.xml loads them, so the harness also proves that order.
do
	local xml = assert(io.open(root .. "/Components/UnitFrames/UnitFrames.xml", "rb")):read("*a")
	local loaded = 0
	for file in xml:gmatch('<Script file="NamePlates\\([%w_]+%.lua)"/>') do
		load("Components/UnitFrames/NamePlates/" .. file)
		loaded = loaded + 1
	end
	check(loaded > 0, "UnitFrames.xml lists the nameplate files")
end
local M = W.module
check(M ~= nil, "the module was created")

--------------------------------------------------------------------------------
-- Snapshots
--------------------------------------------------------------------------------
-- Anchors are named by what they are, not by creation order, so adding a region elsewhere does
-- not rewrite every line of the golden file.
local KEYS = { "Health", "Castbar", "Name", "Auras", "RaidTargetIndicator", "Overlay", "Power", "TargetHighlight" }
local function relName(r)
	if (not r) then return "-" end
	local plate = r.__plate
	if (plate) then
		if (r == plate) then return "Plate" end
		for _, k in ipairs(KEYS) do if (plate[k] == r) then return k end end
		if (plate.Health and r == plate.Health.Overlay) then return "Health.Overlay" end
		if (plate.Health and r == plate.Health.__statusTexture) then return "Health.bar" end
	end
	for _, f in ipairs(plateOrder) do if (f.blizzPlate == r) then return "BlizzPlate" end end
	return r.__kind
end
local function pt(r)
	local p = r and r.__points and r.__points[1]
	if (not p) then return "-" end
	if (p[1] == "ALL") then return "ALL:" .. relName(p[2]) end
	return string.format("%s>%s:%s(%s,%s)", tostring(p[1]), relName(p[2]), tostring(p[3]), round(p[4]), round(p[5]))
end
local function col(c)
	if (not c) then return "-" end
	return string.format("%s,%s,%s", round(c[1]), round(c[2]), round(c[3]))
end
local function vis(r)
	if (not r) then return "none" end
	return (r.__shown and "shown" or "hidden") .. "@" .. round(r.__alpha)
end

local function Snapshot(f)
	local out = {}
	local function add(s) out[#out + 1] = "  " .. s end
	local rec = resolve(f.unit)
	add(string.format("unit=%s obj=%s npc=%s prd=%s widgetsOnly=%s canAttack=%s",
		tostring(f.unit), tostring(f.isObjectPlate), tostring(f.isFriendlyAssistableNPC), tostring(f.isPRD),
		tostring(f.nameplateShowsWidgetsOnly), tostring(f.canAttack)))
	-- As booleans: nil and false mean the same to the module, and which one a flag holds depends on
	-- the order handlers ran in, which is not behaviour.
	local function flag(v) return tostring(v and true or false) end
	add(string.format("state target=%s soft=%s focus=%s mouse=%s combat=%s",
		flag(f.isTarget), flag(f.isSoftTarget), flag(f.isFocus), flag(f.isMouseOver), flag(f.inCombat)))
	add(string.format("frame %s ignore=%s scale=%s", vis(f), tostring(f.__ignore), round(f.__scale)))
	add(string.format("name %s text=%q color=%s pt=%s scale=%s", vis(f.Name), tostring(f.Name.__text),
		col(f.Name.__textColor), pt(f.Name), round(f.Name.__scale)))
	add(string.format("health %s color=%s orient=%s tex=%s pt=%s; bar %s; backdrop %s", vis(f.Health),
		col(f.Health.__barColor), tostring(f.Health.__orientation), f.Health.__texcoord and table.concat({
			round(f.Health.__texcoord[1]), round(f.Health.__texcoord[2]) }, ",") or "-", pt(f.Health),
		vis(f.Health.__statusTexture), vis(f.Health.Backdrop)))
	add(string.format("value %s pt=%s", vis(f.Health.Value), pt(f.Health.Value)))
	add(string.format("cast %s color=%s tex=%s text=%s pt=%s", vis(f.Castbar), col(f.Castbar.__barColor),
		col(f.Castbar.__statusTexture and f.Castbar.__statusTexture.__vertex), col(f.Castbar.Text.__textColor), pt(f.Castbar)))
	if (f.Castbar.__statusTexture and f.Castbar.__statusTexture.__fromBoolean) then
		local fb = f.Castbar.__statusTexture.__fromBoolean
		add(string.format("cast fromBoolean=%s yes=%s no=%s", tostring(fb[1]), col(fb[2]), col(fb[3])))
	end
	add(string.format("badge %s tex=%s; highlight %s color=%s; threat %s", vis(f.Classification),
		tostring(f.Classification.__texture), vis(f.TargetHighlight), col(f.TargetHighlight.__vertex), vis(f.ThreatIndicator)))
	add(string.format("raid enabled=%s %s size=%s pt=%s; auras enabled=%s %s pt=%s", tostring(f.__enabled.RaidTargetIndicator),
		vis(f.RaidTargetIndicator), round(f.RaidTargetIndicator.__w), pt(f.RaidTargetIndicator),
		tostring(f.__enabled.Auras), vis(f.Auras), pt(f.Auras)))
	local native = f.NativeAuras
	add("native auras " .. (native and string.format("%s unit=%s enabled=%s pt=%s", vis(native),
		tostring(native.container.__unit), tostring(native.container.__on), pt(native)) or "none"))
	add(string.format("power %s; prediction %s", vis(f.Power), vis(f.HealthPrediction)))
	-- Only once a plate has built one, so the steps before the marker was switched on are untouched.
	local marker = f.ExecuteMarker
	if (marker) then
		local function evis(r)
			local alpha = issecretvalue(r.__alpha) and ("secret:" .. round(Reveal(r.__alpha))) or round(r.__alpha)
			return (r.__shown and "shown" or "hidden") .. "@" .. alpha
		end
		local tc = marker.Zone.__texcoord or {}
		add(string.format("execute line %s pt=%s; zone %s w=%s tex=%s,%s pt=%s", evis(marker.Line), pt(marker.Line),
			evis(marker.Zone), round(marker.Zone.__w), round(tc[1]), round(tc[2]), pt(marker.Zone)))
	end
	local soft, widgets = f.SoftTargetFrame, f.WidgetContainer
	add(string.format("softTarget parent=%s ignore=%s alpha=%s pt=%s; widgets %s ignore=%s",
		soft and relName(soft.__parentRegion) or "-", tostring(soft and soft.__ignore),
		round(soft and soft.__alpha), pt(soft), vis(widgets), tostring(widgets and widgets.__ignore)))
	return table.concat(out, "\n")
end

-- An idle castbar: nothing cast, nothing held. oUF's castbar OnUpdate hides one on the next frame
-- (castbar.lua:658-663), so one still shown when a step ends is on screen for that frame.
local function IdleCastbarShown(f)
	local bar = f.Castbar
	return (bar and bar.__shown and not (bar.casting or bar.channeling) and (bar.holdTime or 0) <= 0) and true or false
end

-- The frame after each step: oUF's castbar OnUpdate hides an idle bar.
local function FrameBoundary()
	for _, f in ipairs(plateOrder) do
		if (IdleCastbarShown(f)) then f.Castbar:Hide() end
		if (f.Castbar) then f.Castbar.__harnessCastEnded = nil end
	end
end

-- Steps that ended with an idle castbar on screen. The module's own layout pass showed one on every
-- mouseover, target change and full update (FixLog 2026-09-25). A cast that just ended is oUF's:
-- CastStop leaves the bar up for its OnUpdate to hide, and StopCast marks it.
local idleCastbarSteps = {}

local golden, metrics = {}, {}
local previous = {}
local function Step(name)
	for _, f in ipairs(plateOrder) do
		if (IdleCastbarShown(f) and not f.Castbar.__harnessCastEnded) then
			idleCastbarSteps[#idleCastbarSteps + 1] = name .. " (Plate" .. f.__index .. ")"
		end
	end
	FrameBoundary()
	local changed = {}
	for _, f in ipairs(plateOrder) do
		local s = Snapshot(f)
		if (previous[f] ~= s) then
			changed[#changed + 1] = "Plate" .. f.__index .. " (" .. (f.__label or "?") .. ")\n" .. s
			previous[f] = s
		end
	end
	local extra = {}
	if (#W.cvarWrites > 0) then
		local last, names = {}, {}
		for _, write in ipairs(W.cvarWrites) do
			local k, v = write:match("^([^=]+)=(.*)$")
			if (last[k] == nil) then names[#names + 1] = k end
			last[k] = v
		end
		table.sort(names)
		local parts = {}
		for _, k in ipairs(names) do parts[#parts + 1] = k .. "=" .. last[k] end
		extra[#extra + 1] = "  cvars " .. table.concat(parts, " ")
	end
	if (W.reloads > 0) then extra[#extra + 1] = "  reloads " .. W.reloads end
	golden[#golden + 1] = "== " .. name
	for _, e in ipairs(extra) do golden[#golden + 1] = e end
	for _, c in ipairs(changed) do golden[#golden + 1] = c end
	local touched = 0
	for _ in pairs(W.touched) do touched = touched + 1 end
	metrics[#metrics + 1] = string.format("%-42s calls=%-5d plates=%d", name, W.calls, touched)
	W.calls, W.touched, W.callsByPlate, W.methodsByPlate, W.cvarWrites, W.reloads = 0, {}, {}, {}, {}, 0
end

-- Within the current step, before Step() resets the counters: plates touched, and how often one
-- plate frame had a method called on it. SetScale is called once per layout of a plate.
local function Touched()
	local n = 0
	for _ in pairs(W.touched) do n = n + 1 end
	return n
end
local function Calls(f, method)
	local methods = W.methodsByPlate[f]
	return methods and methods[method] or 0
end

--------------------------------------------------------------------------------
-- The session
--------------------------------------------------------------------------------
local function Unit(token, rec)
	rec.token = token
	W.units[token] = rec
	W.plates[token] = NewBlizzardPlate(token)
	return rec
end
local function creature(npc) return "Creature-0-1-2-3-" .. npc .. "-0000ABCDEF" end

W.units.player = { token = "player", name = "Tester", guid = "Player-1-0001", isPlayer = true, canAssist = true,
	isFriend = true, reaction = 5, playerControlled = true, class = "WARRIOR", classID = 1 }
Unit("nameplate1", { name = "Voidbound Ritualist", guid = creature(1001), canAttack = true, reaction = 2, classification = "elite", threat = 0 })
Unit("nameplate2", { name = "Umbral Stalker", guid = creature(1002), canAttack = true, reaction = 2, raidTarget = 8 })
Unit("nameplate3", { name = "Wandering Boar", guid = creature(1003), canAttack = true, reaction = 4, classification = "rare" })
Unit("nameplate4", { name = "Treni", guid = creature(229383), canAssist = true, isFriend = true, reaction = 5 })
Unit("nameplate5", { name = "Aelwyn", guid = "Player-1-0005", isPlayer = true, canAssist = true, isFriend = true,
	reaction = 5, playerControlled = true, class = "PRIEST", className = "Priest", classID = 5 })
Unit("nameplate6", { name = "Copper Vein", guid = "GameObject-0-1-2-3-1731-0000ABCDEF" })
Unit("nameplate7", { name = "Siege Engine", guid = creature(1007), widgetsOnly = true })
W.alias.nameplate8 = "player"
W.plates.nameplate8 = NewBlizzardPlate("nameplate8")
Unit("nameplate9", { name = "Masked Assassin", guid = creature(1009), canAttack = true, reaction = 2,
	secret = { canAttack = true, reaction = true, canAssist = true } })
Unit("nameplate10", { name = "Betta", guid = creature(223648), reaction = 5 })
local labels = { "hostile elite", "hostile", "neutral rare", "friendly NPC", "friendly player", "object",
	"widget-only", "personal resource", "secret hostile", "decorative NPC", "late arrival" }

M:OnInitialize()
M:OnEnable()
Fire("PLAYER_ENTERING_WORLD", true, false)
check(RunningTimers() == 0, "nothing polls while nothing is hovered (C2)", RunningTimers())
Step("login")

for i = 1, 10 do Fire("NAME_PLATE_UNIT_ADDED", "nameplate" .. i) end
for i, f in ipairs(plateOrder) do f.__label = labels[i] end
local P = plateOrder
Step("add ten plates")
Flush()
Step("next frame after adding")

-- One aura kind off before any container exists, so the first one is built without it.
W.profile.auraOwnBuffs = false

W.alias.target = "nameplate1"
Fire("PLAYER_TARGET_CHANGED")
check(Calls(P[1], "SetScale") == 1, "a new target's plate is laid out once (A3)", Calls(P[1], "SetScale"))
check(Touched() <= 2, "a target change touches only the plates whose state changed (C1)", Touched())
check(P[1].Name.__shown and P[1].Health.Value.__shown, "a newly targeted plate shows its name and health text (A9)")
-- Auras only on the target is the default. Its plate builds a native container the first time and
-- shows it on its unit; the scanning element, which Retail leaves empty in combat, stays off.
local function NativeOn(f)
	local native = f.NativeAuras
	return (native and native.__shown and native.container.__on == true and native.container.__unit == f.unit) and true or false
end
local function NativeOff(f)
	local native = f.NativeAuras
	return (not native) or (not native.__shown and native.container.__on == false)
end
check(NativeOn(P[1]), "the target's auras are drawn by a native container on its unit")
check(not P[1].__enabled.Auras, "the scanning element stays off where a native container draws")
check(#W.auraContainers == 1, "only a plate with auras to show builds a container", #W.auraContainers)
-- The kinds, as groups of that container.
local function Group(f, key)
	local native = f.NativeAuras
	return native and native.container.__groups[key]
end
local function Shows(f, key)
	local group = Group(f, key)
	return (group and group.maxFrameCount and group.maxFrameCount > 0) and true or false
end
do
	local groups = W.auraContainers[1] and W.auraContainers[1].__groupOrder or {}
	check(table.concat(groups, ",") == "AzeritePlateCrowdControl,AzeritePlateHarmfulOwn,AzeritePlateHarmfulOthers,"
		.. "AzeritePlateHelpfulDispellable,AzeritePlateHelpfulImportant",
		"a container holds the kinds switched on, crowd control first, and builds none that is off", table.concat(groups, ","))
	-- Disjoint: each group leaves out what an earlier one already shows.
	local own, others, important = Group(P[1], "AzeritePlateHarmfulOwn"), Group(P[1], "AzeritePlateHarmfulOthers"),
		Group(P[1], "AzeritePlateHelpfulImportant")
	check(own and own.filter == "HARMFUL|PLAYER|INCLUDE_NAME_PLATE_ONLY|!CROWD_CONTROL"
		and others and others.filter == "HARMFUL|INCLUDE_NAME_PLATE_ONLY|!PLAYER|!CROWD_CONTROL"
		and others.candidateFilters.nameplateShowAll == true
		and important and important.filter == "HELPFUL|IMPORTANT|!RAID_PLAYER_DISPELLABLE",
		"the kinds are disjoint: your debuffs and others' leave crowd control out, important buffs leave dispellable ones out",
		own and own.filter)
	check(own and own.candidateFilters.nameplateShowPersonal == nil, "your debuffs are all shown, not only Blizzard's pick")
end
Step("target the elite")

W.alias.softenemy = "nameplate2"
Fire("PLAYER_SOFT_ENEMY_CHANGED")
Tick()
Step("soft-target the hostile")

W.alias.softenemy = nil
W.alias.softinteract = "nameplate6"
Fire("PLAYER_SOFT_ENEMY_CHANGED")
Fire("PLAYER_SOFT_INTERACT_CHANGED")
Tick()
Step("soft-target the ore vein")

W.alias.focus = "nameplate3"
Fire("PLAYER_FOCUS_CHANGED")
check(Touched() == 1, "a focus change touches only the plate whose state changed (C1)", Touched())
Step("focus the boar")

W.alias.target = nil
Fire("PLAYER_TARGET_CHANGED")
check(not P[1].Name.__shown and not P[1].Health.Value.__shown, "a plate that stops being the target hides them again (A9)")
check(P[1].NativeAuras and NativeOff(P[1]), "a plate that stops being the target turns its aura container off")
Step("clear the target")
W.alias.target = "nameplate1"
Fire("PLAYER_TARGET_CHANGED")
Step("target the elite again")

W.alias.mouseover = "nameplate2"
Fire("UPDATE_MOUSEOVER_UNIT")
check(P[2].isMouseOver and RunningTimers() == 1, "hovering a plate marks it and starts the short poll", RunningTimers())
check(not P[2].Castbar.__shown, "hovering a plate that casts nothing shows no castbar, not even for a frame (FixLog 2026-09-25)")
Step("hover the hostile")
W.alias.mouseover = nil
Tick()
check(not P[2].isMouseOver and RunningTimers() == 0, "the poll notices the cursor leaving, and stops", RunningTimers())
Step("stop hovering")

W.combat = true
Fire("PLAYER_REGEN_DISABLED")
-- What the player saw: auras present before the pull, gone once it started. The scan behind that is
-- the client's; what the module owes is not to switch the container off itself.
check(NativeOn(P[1]), "entering combat leaves the target's native auras on")
Step("enter combat")

-- The raid marker keeps one place beside the health bar, whatever the name and the auras do. It
-- used to climb one row per row of auras (A4), which the native container makes impossible: its
-- size is secret, and in combat the addon cannot count the auras.
local function Beside(f)
	local p = f.RaidTargetIndicator.__points[1]
	return (p and p[1] == "RIGHT" and p[2] == f.Health and p[3] == "LEFT") and true or false
end
W.units.nameplate1.auras = 2
P[1]:UpdateAllElements("UNIT_AURA")
Step("elite gets two auras")
W.units.nameplate1.auras = 4
P[1]:UpdateAllElements("UNIT_AURA")
Step("elite gets four auras")
check(Beside(P[1]) and Beside(P[2]), "raid markers sit beside the health bar, whatever the names and auras do")
check(P[2].RaidTargetIndicator.__w == 28 and P[2].RaidTargetIndicator.__h == 28, "a raid marker is 28 by default",
	P[2].RaidTargetIndicator.__w)

-- Casts: the fake castbar element sets what oUF sets, then calls the module's callbacks.
local function Cast(f, spell, notInterruptible)
	local rec = resolve(f.unit)
	rec.casting = { name = spell, notInterruptible = notInterruptible, spellID = 9000 + f.__index }
	f.Castbar.casting = true
	f.Castbar.notInterruptible = notInterruptible
	f.Castbar.spellID = rec.casting.spellID
	f.Castbar:Show()
	f.Castbar.Text:SetText(spell)
	f.Castbar.PostCastStart(f.Castbar, f.unit)
end
local function StopCast(f, failed)
	resolve(f.unit).casting = nil
	f.Castbar.casting = nil
	-- A failed cast is held on screen for timeToHold (castbar.lua:457); a finished one is not.
	f.Castbar.holdTime = failed and (f.Castbar.timeToHold or 0) or 0
	f.Castbar.__harnessCastEnded = not failed
	if (failed) then f.Castbar.PostCastFail(f.Castbar, f.unit) else f.Castbar.PostCastStop(f.Castbar, f.unit) end
end

Cast(P[1], "Shadow Bolt", false)
Step("elite casts, interrupt ready")
Cast(P[2], "Dark Ward", true)
Step("hostile casts, cannot be interrupted")
W.cooldowns[6552] = { start = W.time - 2, duration = 15 }
P[1].Castbar.PostCastUpdate(P[1].Castbar, P[1].unit)
Step("interrupt on cooldown mid-cast")
W.cooldowns[6552] = nil
StopCast(P[1], true)
Step("elite's cast fails")
StopCast(P[2], false)
Step("hostile's cast ends")

-- A cast turns uninterruptible before the castbar has been told how to refresh itself (A5): the
-- watcher has to refresh with its own function rather than a stored one.
W.units.nameplate2.casting = { name = "Warding Chant", notInterruptible = true, spellID = 9102 }
P[2].Castbar.casting = true
P[2].Castbar.notInterruptible = true
P[2].Castbar:Show()
Fire("UNIT_SPELLCAST_NOT_INTERRUPTIBLE", "nameplate2")
Step("a cast turns uninterruptible before its castbar knows how to refresh")
check(col(P[2].Castbar.__barColor) == col(ns.Colors.gray), "the interrupt watcher refreshes the castbar itself",
	col(P[2].Castbar.__barColor))
StopCast(P[2], false)
Step("that cast ends")

W.combat = false
Fire("PLAYER_REGEN_ENABLED")
Step("leave combat")

W.profile.hideFriendlyPlayerHealthBar = true
M:UpdateSettings()
Step("names only for friendly players")
check(not P[5].Health.__shown and P[5].Name.__shown, "name-only players show a name and no health bar")
do
	local anchor = P[5].Name.__points[1]
	check(anchor and anchor[1] == "BOTTOM" and anchor[2] == P[5].blizzPlate,
		"name-only names sit on the bottom edge of Blizzard's plate")
end
check(P[5].Name.__scale == W.profile.friendlyNameOnlyFontScale, "name-only names use the name size setting")
do
	local anchor = P[5].RaidTargetIndicator.__points[1]
	check(anchor and anchor[1] == "BOTTOM" and anchor[2] == P[5].Name and anchor[3] == "TOP",
		"a name-only player's raid marker sits above the name, not beside a hidden bar")
end

W.profile.showBlizzardWidgets = true
P[7].WidgetContainer.numWidgetsShowing = 1
M:UpdateSettings()
Step("show Blizzard widgets")

W.profile.showNameAlways = true
M:UpdateSettings()
Step("always show names")

-- Auras on every plate from here on, so recycled and reused frames below carry containers too.
W.profile.showAurasOnTargetOnly = false
M:UpdateSettings()
Step("auras on every plate")
check(NativeOn(P[2]) and NativeOn(P[3]) and NativeOn(P[9]), "with auras on every plate, hostile plates show native auras")
check(not P[6].NativeAuras and not P[8].NativeAuras and not P[10].NativeAuras,
	"object plates and the personal resource display build no aura container")
check(not (P[5].NativeAuras and P[5].NativeAuras.__shown), "a name-only player shows no auras")
do
	local scanning = {}
	for i, f in ipairs(P) do if (f.__enabled.Auras) then scanning[#scanning + 1] = i end end
	check(#scanning == 0, "no plate draws auras with the scanning element while the client has a container",
		table.concat(scanning, ","))
end

-- The Aura filters settings, applied to containers already built.
W.profile.auraOwnBuffs = true
W.profile.auraCrowdControl = false
W.profile.auraOwnDebuffsBlizzardOnly = true
M:UpdateSettings()
Step("aura filters changed")
do
	local own, ownBuffs = Group(P[1], "AzeritePlateHarmfulOwn"), Group(P[1], "AzeritePlateHelpfulOwn")
	check(ownBuffs and Shows(P[1], "AzeritePlateHelpfulOwn")
		and ownBuffs.filter == "HELPFUL|PLAYER|!RAID_PLAYER_DISPELLABLE|!IMPORTANT"
		and ownBuffs.candidateFilters.maxDuration == 30,
		"a kind switched on later is added to a container that was built without it")
	check(not Shows(P[1], "AzeritePlateCrowdControl"), "a kind switched off shows nothing")
	check(own and own.filter == "HARMFUL|PLAYER|INCLUDE_NAME_PLATE_ONLY" and own.candidateFilters.nameplateShowPersonal == true,
		"with crowd control off your debuffs take it back, and Blizzard's pick narrows them", own and own.filter)
end

W.profile.raidTargetSize = 40
M:UpdateSettings()
Step("bigger target markers")
check(P[2].RaidTargetIndicator.__w == 40 and P[2].RaidTargetIndicator.__h == 40 and Beside(P[2]),
	"the target marker size setting resizes the markers and leaves them in place", P[2].RaidTargetIndicator.__w)
W.profile.raidTargetSize = 500
M:UpdateSettings()
check(P[2].RaidTargetIndicator.__w == 64, "a target marker size out of range is held to 64", P[2].RaidTargetIndicator.__w)
W.profile.raidTargetSize = 28
M:UpdateSettings()
Step("target markers back to their default size")

W.cvars.nameplateShowEnemies = "0"
Fire("CVAR_UPDATE", "nameplateShowEnemies")
Step("enemy plates switched off in the game")
W.cvars.nameplateShowEnemies = "1"
Fire("CVAR_UPDATE", "nameplateShowEnemies")
Step("enemy plates back")

-- A plate hidden mid-cast and shown again. The layout pass no longer shows an idle castbar, so a
-- cast has to come back through oUF: shown if it still runs, gone if it ended meanwhile. oUF's
-- CastStop skips a hidden bar (castbar.lua:448), so that bar still says casting when it returns.
Cast(P[2], "Shadow Mend", false)
W.cvars.nameplateShowEnemies = "0"
Fire("CVAR_UPDATE", "nameplateShowEnemies")
check(not P[2].Castbar.__shown, "a hidden plate hides its cast")
W.cvars.nameplateShowEnemies = "1"
Fire("CVAR_UPDATE", "nameplateShowEnemies")
check(P[2].Castbar.__shown and P[2].Castbar.casting, "a plate shown again mid-cast shows the cast again")
Step("enemy plates hidden and back during a cast")
W.cvars.nameplateShowEnemies = "0"
Fire("CVAR_UPDATE", "nameplateShowEnemies")
resolve(P[2].unit).casting = nil
W.cvars.nameplateShowEnemies = "1"
Fire("CVAR_UPDATE", "nameplateShowEnemies")
check(not P[2].Castbar.__shown and not P[2].Castbar.casting,
	"a cast that ended while its plate was hidden is not shown when the plate comes back")
Step("enemy plates hidden and back while the cast ends")

W.instance = { true, "party" }
Fire("PLAYER_ENTERING_WORLD", false, false)
check(Touched() == 0, "a zone change writes CVars and lays out no plate", Touched())
Step("zone into a dungeon")
W.instance = { true, "arena" }
Fire("PLAYER_ENTERING_WORLD", false, false)
Step("zone into an arena")
W.instance = { false, "none" }
Fire("PLAYER_ENTERING_WORLD", false, false)
Step("back to the open world")
check(W.cvars.nameplateMinAlpha == "0.4" and W.cvars.nameplateOccludedAlphaMult == "0.15",
	"open world alpha CVars are applied on the way back out")

local rebuildsBefore = P[2].NativeAuras and P[2].NativeAuras.container.__rebuilds or 0
Fire("NAME_PLATE_UNIT_REMOVED", "nameplate2")
Step("hostile plate removed")
Fire("NAME_PLATE_UNIT_ADDED", "nameplate2")
Flush()
-- The token comes back the same, so nothing but the plate asking makes the container read it again.
check(NativeOn(P[2]) and P[2].NativeAuras.container.__rebuilds > rebuildsBefore,
	"a recycled plate's container reads its unit again")
Step("hostile plate recycled")

-- A setting changed while a plate is off screen, where the refresh of the plates on screen cannot
-- reach it. Its own cycle, so the re-read above cannot be mistaken for this.
Fire("NAME_PLATE_UNIT_REMOVED", "nameplate3")
W.profile.auraImportantBuffs = false
M:UpdateSettings()
check(Shows(P[3], "AzeritePlateHelpfulImportant") and not Shows(P[2], "AzeritePlateHelpfulImportant"),
	"a settings change reaches the plates on screen, and a plate off screen keeps what it had")
Fire("NAME_PLATE_UNIT_ADDED", "nameplate3")
Flush()
check(not Shows(P[3], "AzeritePlateHelpfulImportant"), "a plate back on screen catches up with aura filters changed meanwhile")
Step("the boar's plate back after the aura filters changed")

W.profile.hideFriendlyPlayerHealthBar = false
M:UpdateSettings()
Step("names only switched off again")
check(P[5].Health.__shown and P[5].Health.__alpha == 1, "switching name-only off brings the health bar back")
do
	local anchor = P[5].Name.__points[1]
	check(anchor and anchor[1] == "TOP" and anchor[2] == nil, "switching name-only off puts the name back on its own anchor")
end
check(P[5].Name.__scale == 1, "switching name-only off puts the name back at its normal size")

-- A pooled frame changes jobs: the personal resource display's frame shown for a hostile, then back.
Fire("NAME_PLATE_UNIT_REMOVED", "nameplate8")
W.alias.nameplate8 = nil
W.units.nameplate8 = { token = "nameplate8", name = "Frenzied Gnoll", guid = creature(1008), canAttack = true, reaction = 2 }
Fire("NAME_PLATE_UNIT_ADDED", "nameplate8")
Flush()
check(NativeOn(P[8]), "the personal resource frame shows auras once it is reused for a hostile")
Step("personal resource frame reused for a hostile")
Fire("NAME_PLATE_UNIT_REMOVED", "nameplate8")
W.units.nameplate8 = nil
W.alias.nameplate8 = "player"
Fire("NAME_PLATE_UNIT_ADDED", "nameplate8")
Flush()
check(P[8].NativeAuras and NativeOff(P[8]), "the frame back on the personal resource display turns its auras off")
Step("the frame back on the personal resource display")

W.alias.focus = nil
Fire("PLAYER_FOCUS_CHANGED")
Step("clear the focus")

-- A unit that is not ready on the frame its plate appears: no hostility and no name yet. The next
-- frame has both, and the deferred pass after adding a plate has to notice. This plate also stands
-- for a client without the aura container, which keeps the scanning element.
W.noAuraContainer = true
Unit("nameplate11", { guid = creature(1011) })
Fire("NAME_PLATE_UNIT_ADDED", "nameplate11")
P[11].__label = labels[11]
Step("a plate appears before its unit is ready")
W.units.nameplate11.name = "Late Arrival"
W.units.nameplate11.canAttack = true
W.units.nameplate11.reaction = 2
Flush()
Step("the unit is ready one frame later")
check(P[11].canAttack == true, "the deferred pass re-classifies a plate whose unit was not ready")
check(P[11].Name.__text == "Late Arrival", "the deferred pass fills in a name that was not ready")
check(P[11].__enabled.Auras and not P[11].NativeAuras, "without an aura container a plate falls back to the scanning element")
W.noAuraContainer = false

-- A reload taken in combat inside a dungeon, then combat ending.
W.combat = true
W.instance = { true, "party" }
Fire("PLAYER_ENTERING_WORLD", false, true)
Step("reload in combat inside a dungeon")
W.combat = false
Fire("PLAYER_REGEN_ENABLED")
Step("combat ends after that reload")
check(W.cvars.nameplateMinAlpha == "0.75" and W.cvars.nameplateOccludedAlphaMult == "0.45",
	"the dungeon's alpha CVars are in place once combat ends")

-- The cursor going straight from one plate to another: the event moves the hover, and the poll
-- that runs meanwhile stops once nothing is under the cursor.
W.alias.mouseover = "nameplate3"
Fire("UPDATE_MOUSEOVER_UNIT")
Step("hover the boar")
W.alias.mouseover = "nameplate1"
Fire("UPDATE_MOUSEOVER_UNIT")
check(P[1].isMouseOver and not P[3].isMouseOver, "the hover follows the cursor straight onto another plate")
Step("the cursor moves straight onto the elite")
W.alias.mouseover = nil
Tick()
check(not P[1].isMouseOver and RunningTimers() == 0, "leaving the last plate clears the hover and stops the poll")
Step("the cursor leaves")

-- Content settings (Phase 6): each kind of content its own faintness and distance, applied through
-- the driver's CVars. The defaults are the old per-zone values, which the zone steps above pin.
do
	local contentSettings = W.profile.contentSettings
	local saved = {}
	for contentType, settings in pairs(contentSettings) do
		saved[contentType] = { minAlpha = settings.minAlpha, occludedAlpha = settings.occludedAlpha, maxDistance = settings.maxDistance }
	end
	local function Alpha() return W.cvars.nameplateMinAlpha, W.cvars.nameplateOccludedAlphaMult, W.cvars.nameplateMaxDistance end

	W.instance = { true, "party" }
	Fire("PLAYER_ENTERING_WORLD", false, false)
	contentSettings.dungeon.minAlpha, contentSettings.dungeon.maxDistance = .6, 50
	M:UpdateSettings()
	local minAlpha, occluded, distance = Alpha()
	check(minAlpha == "0.6" and occluded == "0.45" and distance == "50", "a dungeon's own settings apply in a dungeon", minAlpha)
	check(M:GetEditedContent() == "dungeon", "the options open on the content the player is in", M:GetEditedContent())

	contentSettings.mythicplus.minAlpha = .9
	W.keyActive = true
	Fire("CHALLENGE_MODE_START")
	minAlpha, occluded, distance = Alpha()
	check(minAlpha == "0.9" and distance == "40", "a key starting switches to Mythic+ settings without a loading screen", minAlpha)
	W.keyActive = false
	Fire("CHALLENGE_MODE_COMPLETED")
	check(Alpha() == "0.6", "and a key ending switches back to the dungeon's", (Alpha()))

	W.instance = { true, "raid" }
	Fire("PLAYER_ENTERING_WORLD", false, false)
	minAlpha, occluded = Alpha()
	check(minAlpha == "0.75" and occluded == "0.45", "a raid keeps the old instance values by default", minAlpha)
	W.instance = { true, "scenario" }
	Fire("PLAYER_ENTERING_WORLD", false, false)
	check(Alpha() == "0.6", "a scenario or delve counts as a dungeon, as every non-PvP instance did", (Alpha()))

	-- Edited through the options' own calls, for the kind picked, not the one the player is in.
	M:SetEditedContent("battleground")
	M:SetContentValue("occludedAlpha", .2)
	check(contentSettings.battleground.occludedAlpha == .2 and select(2, Alpha()) == "0.45",
		"editing another kind of content stores it and leaves the current one alone")
	check(M:GetContentValue("occludedAlpha") == .2, "the options read back the kind being edited")
	M:SetEditedContent(nil)

	-- Changed in combat, the CVars wait for it to end, like every driver CVar.
	W.combat = true
	Fire("PLAYER_REGEN_DISABLED")
	contentSettings.dungeon.minAlpha = .3
	M:UpdateSettings()
	check(Alpha() == "0.6", "a content setting changed in combat waits", (Alpha()))
	W.combat = false
	Fire("PLAYER_REGEN_ENABLED")
	check(Alpha() == "0.3", "and applies when combat ends", (Alpha()))

	for contentType, settings in pairs(saved) do
		for key, value in pairs(settings) do contentSettings[contentType][key] = value end
	end
	W.instance = { false, "none" }
	Fire("PLAYER_ENTERING_WORLD", false, false)
	check(Alpha() == "0.4", "back in the open world with its old values")
end
Step("content settings")

-- The one distance of before becomes every content's (migration 11).
do
	local savedDB, savedRegister = M.db, ns.db.RegisterNamespace
	local fresh
	ns.db.RegisterNamespace = function(_, _, defaults)
		fresh = {}
		for k, v in pairs(defaults.profile) do fresh[k] = v end
		fresh.contentSettings = {}
		for contentType, settings in pairs(defaults.profile.contentSettings) do
			fresh.contentSettings[contentType] = { minAlpha = settings.minAlpha, occludedAlpha = settings.occludedAlpha, maxDistance = settings.maxDistance }
		end
		fresh.maxDistance, fresh.nameplateScaleModelVersion = 55, 10
		return { profile = fresh }
	end
	M:OnInitialize()
	check(fresh.nameplateScaleModelVersion == 11 and fresh.contentSettings.world.maxDistance == 55
		and fresh.contentSettings.arena.maxDistance == 55, "a distance set before content settings carries over to every kind")
	ns.db.RegisterNamespace, M.db = savedRegister, savedDB
end

-- The combat filter (Phase 7): enemies in combat with no one in the group fade, never the target,
-- focus, mouseover or soft target. Off by default, and nothing runs then.
do
	check(RunningTimers() == 0, "the combat filter runs nothing while it is off", RunningTimers())
	local elite, hostile, boar = W.units.nameplate1, W.units.nameplate2, W.units.nameplate3
	-- The elite is the target; the hostile and the elite fight someone else; the boar fights you.
	elite.affectingCombat, elite.threatBy = true, {}
	hostile.affectingCombat, hostile.threatBy = true, {}
	boar.affectingCombat, boar.threatBy = true, { player = 1 }
	W.profile.combatFilter = true
	M:UpdateSettings()
	Step("combat filter on")
	check(RunningTimers() == 1, "switched on, the combat filter checks on a timer", RunningTimers())
	check(P[2].__alpha == .35, "an enemy fighting someone outside the group fades", P[2].__alpha)
	check(P[3].__alpha == 1, "an enemy fighting you does not", P[3].__alpha)
	check(P[1].__alpha == 1, "the target never fades, whoever it fights", P[1].__alpha)

	W.alias.mouseover = "nameplate2"
	Fire("UPDATE_MOUSEOVER_UNIT")
	check(P[2].__alpha == 1, "the plate under the cursor never fades", P[2].__alpha)
	W.alias.mouseover = nil
	Tick()
	check(P[2].__alpha == .35, "and fades again when the cursor leaves", P[2].__alpha)

	-- A party member on its threat table: fighting your group.
	W.party = 1
	W.units.party1 = { token = "party1", name = "Friend", guid = "Player-1-0100", isPlayer = true, reaction = 5 }
	hostile.threatBy = { party1 = 0 }
	Tick()
	check(P[2].__alpha == 1, "an enemy on a party member's threat table does not fade", P[2].__alpha)
	hostile.threatBy = { player = "secret" }
	Tick()
	check(P[2].__alpha == 1, "a secret threat answer counts as fighting you", P[2].__alpha)
	hostile.threatBy = {}
	hostile.affectingCombat = false
	Tick()
	check(P[2].__alpha == 1, "an enemy out of combat is left to the content's alpha", P[2].__alpha)
	hostile.affectingCombat = true
	Tick()

	W.profile.combatFilterAlpha = .5
	M:UpdateSettings()
	check(P[2].__alpha == .5, "the faded alpha setting applies", P[2].__alpha)
	-- A UIParent fade is mirrored onto the plates through the same rule.
	UIParent:SetAlpha(.5)
	check(P[2].__alpha == .25 and P[3].__alpha == .5, "a UIParent fade multiplies with the combat fade", P[2].__alpha)
	-- The decorative NPC's plate is hidden (an object nobody is pointing at); the mirror used to show it.
	check(P[10].__alpha == 0, "a hidden plate stays hidden when UIParent's alpha changes", P[10].__alpha)
	UIParent:SetAlpha(1)

	W.profile.combatFilter = false
	M:UpdateSettings()
	check(RunningTimers() == 0 and P[2].__alpha == 1, "switched off, the timer stops and the fade is gone", RunningTimers())
	elite.affectingCombat, elite.threatBy = nil, nil
	hostile.affectingCombat, hostile.threatBy = nil, nil
	boar.affectingCombat, boar.threatBy = nil, nil
	W.party, W.units.party1 = nil, nil
end
Step("combat filter off")

-- The interrupt resolver (Interrupts.lua), which the target castbar and every plate ask (Phase 5).
do
	local function Interrupt() return ns.API.GetPrimaryInterrupt() end
	local spellID, ready = Interrupt()
	check(spellID == 6552 and ready == true, "a Warrior's interrupt is Pummel, ready with nothing on cooldown", spellID)

	-- In combat the cooldown is secret; the cast seen through UNIT_SPELLCAST_SUCCEEDED takes over.
	W.cooldowns[6552] = { start = SECRET, duration = SECRET }
	Fire("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-1", 6552)
	spellID, ready = Interrupt()
	check(ready == false, "with the cooldown secret, a Pummel just cast is out", tostring(ready))
	W.time = W.time + 16
	spellID, ready = Interrupt()
	check(ready == true, "and back after its cooldown", tostring(ready))
	W.time = W.time - 16

	-- The duration object answers in combat and comes before everything else.
	C_Spell.GetSpellCooldownDuration = function(id, ignoreGCD)
		W.durationAsked = { id, ignoreGCD }
		return { IsZero = function() return W.durationZero end }
	end
	W.durationZero = false
	spellID, ready = Interrupt()
	check(ready == false and W.durationAsked and W.durationAsked[2] == true,
		"the cooldown's duration object decides first, the global cooldown left out", tostring(ready))
	W.durationZero = true
	Fire("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-2", 6552)
	spellID, ready = Interrupt()
	check(ready == true, "and a duration object that answers outranks the estimate", tostring(ready))
	C_Spell.GetSpellCooldownDuration = nil
	W.cooldowns[6552] = nil

	-- Another class: the list is read again when spells change.
	local player = W.units.player
	player.class, player.classID = "WARLOCK", 9
	Fire("SPELLS_CHANGED")
	spellID = Interrupt()
	check(spellID == 119910, "the sacrificed Spell Lock does not count without Grimoire of Sacrifice", spellID)
	local savedAuras = C_UnitAuras
	C_UnitAuras = { GetPlayerAuraBySpellID = function(id) return id == 196099 and {} or nil end }
	spellID = Interrupt()
	check(spellID == 132409, "and counts while it is up", spellID)
	C_UnitAuras = savedAuras
	-- The Felhunter casts its own Spell Lock: a pet's cast counts.
	local savedKnown = C_SpellBook.IsSpellKnown
	C_SpellBook.IsSpellKnown = function(id, bank) return id == 19647 and bank == Enum.SpellBookSpellBank.Pet end
	Fire("SPELLS_CHANGED")
	W.cooldowns[19647] = { start = SECRET, duration = SECRET }
	Fire("UNIT_SPELLCAST_SUCCEEDED", "pet", "Cast-3", 19647)
	spellID, ready = Interrupt()
	check(spellID == 19647 and ready == false, "a pet's interrupt is found in its spellbook, and its cast is seen", spellID)
	W.cooldowns[19647] = nil
	C_SpellBook.IsSpellKnown = savedKnown

	-- Forever: ranked spells, the highest known one.
	ns.IsForever = true
	player.class, player.classID = "SHAMAN", 7
	Fire("SPELLS_CHANGED")
	spellID = Interrupt()
	check(spellID == 10414, "on Forever a Shaman's interrupt is Earth Shock, highest rank first", spellID)
	player.class, player.classID = "PRIEST", 5
	Fire("SPELLS_CHANGED")
	C_SpellBook.IsSpellKnown = function() return false end
	Fire("SPELLS_CHANGED")
	spellID, ready = Interrupt()
	check(spellID == nil and ready == nil, "a player without an interrupt gets none, and no readiness", spellID)
	C_SpellBook.IsSpellKnown = savedKnown
	ns.IsForever = false
	player.class, player.classID = "WARRIOR", 1
	Fire("SPELLS_CHANGED")
	check(Interrupt() == 6552, "back to the Warrior")
end
Step("the interrupt resolver asked")

-- Blizzard's stacking option, passed through: read and written, never set by AzeriteUI itself.
check(#W.bitfieldWrites == 0, "AzeriteUI never writes the stacking setting on its own", W.bitfieldWrites[1])
check(M:IsStackingSupported() and M:GetStacking("enemy") == true and M:GetStacking("friendly") == false,
	"the stacking options read the game's own setting")
M:SetStacking("friendly", true)
check(W.bitfields.nameplateStackingTypes[2] == true and W.bitfieldWrites[1] == "nameplateStackingTypes[2]=true",
	"switching friendly stacking writes that bit and no other", W.bitfieldWrites[1])
W.combat = true
Fire("PLAYER_REGEN_DISABLED")
M:SetStacking("enemy", false)
check(W.bitfields.nameplateStackingTypes[1] == true and M:GetStacking("enemy") == false,
	"a stacking change in combat waits, and the option shows what was chosen")
W.combat = false
Fire("PLAYER_REGEN_ENABLED")
check(W.bitfields.nameplateStackingTypes[1] == false, "the stacking change is made when combat ends")
Step("stacking passed through")
do
	local saved = W.cvars.nameplateStackingTypes
	W.cvars.nameplateStackingTypes = nil
	check(not M:IsStackingSupported() and M:GetStacking("enemy") == nil, "a client without the setting offers no stacking option")
	W.cvars.nameplateStackingTypes = saved
end

-- The execute marker (Phase 8): a line across enemy health bars at the player's execute threshold,
-- and the range below it tinted once the enemy is inside it. Off by default, and nothing is built.
do
	local BAR_WIDTH, TEX_LEFT, TEX_RIGHT = 92, 14/256, 242/256
	local function near(a, b) return rawtype(a) == "number" and math.abs(a - b) < 1e-6 end
	-- What is on screen, from the widgets, not from the module's own flag.
	local function Shown(f)
		local marker = f.ExecuteMarker
		return (marker and marker.Line.__shown and marker.Zone.__shown) and true or false
	end
	local function Hidden(f)
		local marker = f.ExecuteMarker
		return (not marker) or (not marker.Line.__shown and not marker.Zone.__shown)
	end
	local function LineX(f)
		local p = f.ExecuteMarker and f.ExecuteMarker.Line.__points[1]
		return p and p[4], p
	end
	local function Tint(f) return Reveal(f.ExecuteMarker.Zone.__alpha) end
	local function Health(f, percent)
		resolve(f.unit).healthPercent = percent
		f.Health.PostUpdate(f.Health, f.unit)
	end
	local built = {}
	for i, f in ipairs(P) do if (f.ExecuteMarker) then built[#built + 1] = i end end
	check(#built == 0, "the execute marker builds nothing while it is off", table.concat(built, ","))

	W.profile.executeMarker = true
	M:UpdateSettings()
	Step("execute marker on")
	check(Shown(P[1]) and Shown(P[2]) and Shown(P[3]) and Shown(P[11]), "enemy plates show the execute marker")
	do
		local none = {}
		for _, i in ipairs({ 4, 5, 6, 7, 8, 9, 10 }) do if (P[i].ExecuteMarker) then none[#none + 1] = i end end
		check(#none == 0, "friendly, object, widget-only, personal and secret-hostility plates build no marker",
			table.concat(none, ","))
	end
	do
		local x, p = LineX(P[1])
		check(p and p[1] == "CENTER" and p[2] == P[1].Health and p[3] == "LEFT" and near(x, BAR_WIDTH * .2),
			"a Warrior's line sits a fifth of the bar's width in from its empty end", x)
		local zone = P[1].ExecuteMarker.Zone
		check(near(zone.__w, BAR_WIDTH * .2) and zone.__points[1][1] == "TOPLEFT" and zone.__points[2][1] == "BOTTOMLEFT",
			"the tinted range runs from the bar's empty end to the line", zone.__w)
		local tc = zone.__texcoord
		check(zone.__texture == P[1].Health.__barTexture and tc and near(tc[1], TEX_LEFT)
			and near(tc[2], TEX_LEFT + (TEX_RIGHT - TEX_LEFT) * .2),
			"the tint is the bar's own art cropped to the same share, so it has the bar's shape", tc and tc[2])
	end
	check(Tint(P[1]) == 0, "at full health the range is not tinted", Tint(P[1]))
	check(W.healthPercentAsked and W.healthPercentAsked.usePredicted == false,
		"the tint asks for health as it is, not with incoming heals")

	Health(P[1], .15)
	check(Tint(P[1]) == 1 and issecretvalue(P[1].ExecuteMarker.Zone.__alpha),
		"below the threshold the range is tinted, by the client's secret answer passed straight through", Tint(P[1]))
	Health(P[1], .2)
	check(Tint(P[1]) == 0, "at the threshold itself the enemy is not inside yet", Tint(P[1]))
	Health(P[1], .15)
	Step("the elite drops below a fifth of its health")

	-- Set by hand, for a talent that moves the threshold.
	W.profile.executeThreshold = .35
	M:UpdateSettings()
	check(near(LineX(P[1]), BAR_WIDTH * .35) and near(P[1].ExecuteMarker.Zone.__w, BAR_WIDTH * .35),
		"a threshold set by hand moves the line and the range", (LineX(P[1])))
	Health(P[2], .3)
	check(Tint(P[2]) == 1, "and the tint follows it", Tint(P[2]))
	W.profile.executeThreshold = .9
	M:UpdateSettings()
	check(near(LineX(P[1]), BAR_WIDTH * .5), "a threshold set by hand is held to half the bar", (LineX(P[1])))
	W.profile.executeThreshold = 0
	M:UpdateSettings()
	check(near(LineX(P[1]), BAR_WIDTH * .2), "set back to automatic, the class's threshold returns", (LineX(P[1])))
	check(W.curvesMade == 3, "one curve per threshold, made once and kept", W.curvesMade)
	Step("threshold set by hand, then automatic again")

	-- The class decides, when spells change; only the markers follow, the plates are not laid out.
	local player = W.units.player
	player.class = "MAGE"
	Fire("SPELLS_CHANGED")
	check(Hidden(P[1]), "a class without an execute loses the marker")
	check(Calls(P[1], "SetScale") == 0, "a threshold change touches the markers, not the plates' layout", Calls(P[1], "SetScale"))
	player.class = "MONK"
	Fire("SPELLS_CHANGED")
	check(Shown(P[1]) and near(LineX(P[1]), BAR_WIDTH * .15), "a Monk's line sits at 15%", (LineX(P[1])))
	player.class = "DEATHKNIGHT"
	local savedKnown = C_SpellBook.IsSpellKnown
	C_SpellBook.IsSpellKnown = function(id) return id ~= 343294 end
	Fire("SPELLS_CHANGED")
	check(Hidden(P[1]), "a Death Knight without Soul Reaper has no execute")
	C_SpellBook.IsSpellKnown = savedKnown
	Fire("SPELLS_CHANGED")
	check(Shown(P[1]) and near(LineX(P[1]), BAR_WIDTH * .35), "and one with it has 35%", (LineX(P[1])))
	player.class = "WARRIOR"
	Fire("SPELLS_CHANGED")
	check(near(LineX(P[1]), BAR_WIDTH * .2), "back to the Warrior's fifth", (LineX(P[1])))
	Step("the class decides the threshold")

	-- A bar that fills from the right has its empty end on the left, so the marker mirrors. No plate
	-- bar is reversed today; this pins the rule for when one is.
	P[2].Health:SetReverseFill(true)
	M.executeThresholdCallback()
	do
		local x, p = LineX(P[2])
		local zone = P[2].ExecuteMarker.Zone
		local tc = zone.__texcoord
		check(p and p[3] == "RIGHT" and near(x, -BAR_WIDTH * .2) and zone.__points[1][1] == "TOPRIGHT"
			and tc and near(tc[1], TEX_RIGHT - (TEX_RIGHT - TEX_LEFT) * .2) and near(tc[2], TEX_RIGHT),
			"on a bar that fills from the right the line and the range mirror", x)
	end
	P[2].Health:SetReverseFill(false)
	M.executeThresholdCallback()

	-- A client without curves: the line still shows, the range never tints.
	local savedCurves = C_CurveUtil
	C_CurveUtil = nil
	W.profile.executeThreshold = .4
	M:UpdateSettings()
	check(Shown(P[1]) and Tint(P[1]) == 0, "without curves the line stays and the range is never tinted", Tint(P[1]))
	C_CurveUtil = savedCurves
	W.profile.executeThreshold = 0
	M:UpdateSettings()

	-- A marked plate reused for a friendly unit.
	Fire("NAME_PLATE_UNIT_REMOVED", "nameplate11")
	local late = W.units.nameplate11
	late.canAttack, late.canAssist, late.isFriend, late.reaction = false, true, true, 5
	Fire("NAME_PLATE_UNIT_ADDED", "nameplate11")
	Flush()
	check(P[11].ExecuteMarker and Hidden(P[11]), "a marked plate reused for a friendly unit hides its marker")
	Step("a marked plate reused for a friendly unit")

	W.profile.executeMarker = false
	M:UpdateSettings()
	local left = {}
	for i, f in ipairs(P) do if (not Hidden(f)) then left[#left + 1] = i end end
	check(#left == 0, "switched off, every marker is hidden", table.concat(left, ","))
	local alphaBefore = P[1].ExecuteMarker.Zone.__alpha
	Health(P[1], .1)
	check(P[1].ExecuteMarker.Zone.__alpha == alphaBefore, "a hidden marker ignores health updates")
	Step("execute marker off")
end

-- Friendly NPCs and the game's settings the plates follow (FixLog 2026-09-25). A friendly NPC is what
-- Blizzard's own plates call one: friendly and not a player. Most vendors, trainers and quest givers
-- cannot be assisted, and asking UnitCanAssist alone had them sized as friendly players.
do
	local function near(a, b) return rawtype(a) == "number" and rawtype(b) == "number" and math.abs(a - b) < 1e-6 end
	local function Breakdown(f) return M:GetDebugPlateScaleBreakdown(f) end
	local function Hidden(f) return f.__alpha == 0 and f.__AzeriteUI_AlphaHidden == true end
	local savedSoftInteract = W.alias.softinteract

	Unit("nameplate12", { name = "Innkeeper Allison", guid = creature(6740), isFriend = true, reaction = 5 })
	Unit("nameplate13", { name = "Brann Bronzebeard", guid = creature(206017), isFriend = true, canAssist = true,
		reaction = 5, treatAsPlayer = true, className = "Warrior", class = "WARRIOR", classID = 1 })
	Fire("NAME_PLATE_UNIT_ADDED", "nameplate12")
	Fire("NAME_PLATE_UNIT_ADDED", "nameplate13")
	Flush()
	P[12].__label, P[13].__label = "vendor", "follower"
	Step("a vendor and a follower companion appear")
	check(P[12].isFriendlyAssistableNPC == true, "a friendly NPC that cannot be assisted is a friendly NPC")
	check(not P[13].isFriendlyAssistableNPC and P[13].isPlayerUnit == true,
		"a companion the game draws as a player counts as a player, as Blizzard's plates count it")

	local defaultNPCScale, defaultFriendlyScale = W.profile.friendlyNPCScale, W.profile.friendlyScale
	W.profile.friendlyNPCScale, W.profile.friendlyScale = .5, 1.2
	M:UpdateSettings()
	check(near(Breakdown(P[12]).relationScale, .5) and near(Breakdown(P[4]).relationScale, .5),
		"Friendly NPC size sizes the vendor and the trainer", Breakdown(P[12]).relationScale)
	check(near(Breakdown(P[5]).relationScale, 1.2) and near(Breakdown(P[13]).relationScale, 1.2),
		"Friendly/player size sizes friendly players and the companion", Breakdown(P[13]).relationScale)
	check(near(P[12].__scale, P[4].__scale) and near(P[12].__scale * 1.2, P[5].__scale * .5),
		"and the plates are drawn at those sizes", P[12].__scale)
	W.profile.friendlyNPCScale, W.profile.friendlyScale = defaultNPCScale, defaultFriendlyScale
	M:UpdateSettings()
	check(near(P[12].__scale, P[5].__scale), "by default a friendly NPC is drawn at the friendly player size", P[12].__scale)
	Step("friendly NPCs sized by their own setting")

	W.profile.hideFriendlyPlayerHealthBar = true
	M:UpdateSettings()
	check(not P[13].Health.__shown and P[13].Name.__shown, "names only for friendly players covers a companion drawn as one")
	check(P[12].Health.__shown, "and leaves a friendly NPC its health bar")
	W.profile.hideFriendlyPlayerHealthBar = false
	M:UpdateSettings()
	Step("names only, the companion included")

	-- The game's visibility settings by the names Retail 12.1 has, the event naming them as it does.
	W.cvars.nameplateShowFriendlyNpcs = "0"
	Fire("CVAR_UPDATE", "nameplateShowFriendlyNpcs")
	check(Hidden(P[12]) and Hidden(P[4]), "friendly NPC plates switched off in the game are hidden at once")
	check(not Hidden(P[5]) and not Hidden(P[13]), "and friendly players are left alone")
	Step("friendly NPC plates switched off in the game")
	W.alias.softinteract = "nameplate12"
	Fire("PLAYER_SOFT_INTERACT_CHANGED")
	check(not Hidden(P[12]), "a friendly NPC the engine keeps a plate for as a soft target still shows")
	W.alias.softinteract = savedSoftInteract
	Fire("PLAYER_SOFT_INTERACT_CHANGED")
	check(Hidden(P[12]), "and is hidden again once it is not")
	-- The soft target brings the vendor back through the layout pass alone (OnSelectionChanged),
	-- with no oUF update, so a cast it was hidden in only comes back if that pass asks oUF.
	Cast(P[12], "Brewing", false)
	Fire("CVAR_UPDATE", "nameplateShowFriendlyNpcs")
	check(Hidden(P[12]) and not P[12].Castbar.__shown, "a plate hidden mid-cast hides the cast")
	W.alias.softinteract = "nameplate12"
	Fire("PLAYER_SOFT_INTERACT_CHANGED")
	check(P[12].Castbar.__shown and P[12].Castbar.casting,
		"a plate the layout pass alone brings back mid-cast shows the cast again")
	W.alias.softinteract = savedSoftInteract
	Fire("PLAYER_SOFT_INTERACT_CHANGED")
	resolve(P[12].unit).casting = nil
	W.units.nameplate4.widgetsOnly = true
	Fire("UNIT_FACTION", "nameplate4")
	check(not Hidden(P[4]), "a friendly NPC given a plate for its widgets still shows")
	W.units.nameplate4.widgetsOnly = nil
	Fire("UNIT_FACTION", "nameplate4")
	W.cvars.nameplateShowFriendlyNpcs = "1"
	Fire("CVAR_UPDATE", "nameplateShowFriendlyNpcs")
	check(not Hidden(P[12]) and not Hidden(P[4]), "switched back on, they return")
	check(not P[12].Castbar.__shown and not P[12].Castbar.casting, "without the cast that ended while they were hidden")
	W.cvars.nameplateShowFriendlyPlayers = "0"
	Fire("CVAR_UPDATE", "nameplateShowFriendlyPlayers")
	check(Hidden(P[5]) and Hidden(P[13]) and not Hidden(P[12]),
		"friendly player plates switched off hide the players and the companion, not the NPCs")
	W.cvars.nameplateShowFriendlyPlayers = "1"
	Fire("CVAR_UPDATE", "nameplateShowFriendlyPlayers")
	-- A client that still has the old names: the plates follow those.
	W.cvars.nameplateShowFriendlyPlayers, W.cvars.nameplateShowFriendlyNpcs = nil, nil
	W.cvars.nameplateShowFriends, W.cvars.nameplateShowFriendlyNPCs = "1", "0"
	Fire("CVAR_UPDATE", "nameplateShowFriendlyNPCs")
	check(Hidden(P[12]) and not Hidden(P[5]), "on a client with the old names, the plates follow those")
	W.cvars.nameplateShowFriends, W.cvars.nameplateShowFriendlyNPCs = "0", "1"
	Fire("CVAR_UPDATE", "nameplateShowFriends")
	check(Hidden(P[5]) and not Hidden(P[12]), "friendly players included")
	W.cvars.nameplateShowFriends, W.cvars.nameplateShowFriendlyNPCs = nil, nil
	W.cvars.nameplateShowFriendlyPlayers, W.cvars.nameplateShowFriendlyNpcs = "1", "1"
	Fire("CVAR_UPDATE", "nameplateShowFriendlyNpcs")
	check(not Hidden(P[12]), "back on the new names")
	Step("the game's visibility settings followed")

	-- The same settings passed through the options page, as stacking is.
	check(M:IsShownSettingSupported("friendlyNPCs") and M:GetShownSetting("friendlyNPCs") == true
		and M:GetShownSetting("showAll") == true, "the options read the game's visibility settings")
	M:SetShownSetting("friendlyNPCs", false)
	check(W.cvars.nameplateShowFriendlyNpcs == "0", "and write them by the client's own name", W.cvars.nameplateShowFriendlyNpcs)
	W.combat = true
	Fire("PLAYER_REGEN_DISABLED")
	M:SetShownSetting("friendlyNPCs", true)
	check(W.cvars.nameplateShowFriendlyNpcs == "0" and M:GetShownSetting("friendlyNPCs") == true,
		"a visibility change in combat waits, and the option shows what was chosen")
	W.combat = false
	Fire("PLAYER_REGEN_ENABLED")
	check(W.cvars.nameplateShowFriendlyNpcs == "1", "and is made when combat ends", W.cvars.nameplateShowFriendlyNpcs)
	Fire("CVAR_UPDATE", "nameplateShowFriendlyNpcs")
	do
		local saved = W.cvars.nameplateShowAll
		W.cvars.nameplateShowAll = nil
		check(not M:IsShownSettingSupported("showAll") and M:GetShownSetting("showAll") == nil,
			"a setting the client does not have is not offered")
		W.cvars.nameplateShowAll = saved
	end
	Step("the visibility settings passed through")

	-- Friendly plates only for your target (FixLog 2026-09-26, Tim's request). Neither client has such a
	-- setting: with friendly NPC plates off, a hard target gets no plate, only its name in the world. So
	-- the game's setting stays on, every plate is made, and only the target's and soft target's are drawn.
	check(not M:GetFriendlyTargetOnly("friendlyNPCs") and not M:GetFriendlyTargetOnly("friendlyPlayers"),
		"friendly plates only for your target is off by default")
	local savedTarget = W.alias.target
	W.cvars.nameplateShowFriendlyNpcs = "0"
	Fire("CVAR_UPDATE", "nameplateShowFriendlyNpcs")
	M:SetFriendlyTargetOnly("friendlyNPCs", true)
	check(W.cvars.nameplateShowFriendlyNpcs == "1",
		"turning it on for NPCs turns on the game's friendly NPC plates, which it needs", W.cvars.nameplateShowFriendlyNpcs)
	Fire("CVAR_UPDATE", "nameplateShowFriendlyNpcs")
	check(M:GetFriendlyTargetOnly("friendlyNPCs") and W.profile.friendlyNPCsTargetOnly == true, "and it is saved")
	check(Hidden(P[12]) and Hidden(P[4]), "friendly NPCs that are not your target are hidden")
	check(not Hidden(P[5]) and not Hidden(P[13]) and not Hidden(P[1]) and not Hidden(P[2]),
		"friendly players and enemies are left alone")
	W.alias.target = "nameplate12"
	Fire("PLAYER_TARGET_CHANGED")
	check(not Hidden(P[12]) and P[12].Name.__shown and P[12].Health.__shown,
		"the friendly NPC you target shows its Azerite plate")
	check(Hidden(P[4]), "the other friendly NPC stays hidden")
	W.alias.target = "nameplate4"
	Fire("PLAYER_TARGET_CHANGED")
	check(Hidden(P[12]) and not Hidden(P[4]), "a new target: the old NPC's plate hides and the new one's shows")
	W.alias.target = nil
	Fire("PLAYER_TARGET_CHANGED")
	check(Hidden(P[4]) and Hidden(P[12]), "with no target, no friendly NPC plate shows")
	W.alias.mouseover = "nameplate12"
	Fire("UPDATE_MOUSEOVER_UNIT")
	check(Hidden(P[12]), "hovering a friendly NPC does not show its plate")
	W.alias.mouseover = nil
	Tick()
	W.alias.softinteract = "nameplate12"
	Fire("PLAYER_SOFT_INTERACT_CHANGED")
	check(not Hidden(P[12]), "the NPC your interact key would use shows")
	W.alias.softinteract = savedSoftInteract
	Fire("PLAYER_SOFT_INTERACT_CHANGED")
	check(Hidden(P[12]), "and hides again once it would not")
	W.units.nameplate4.widgetsOnly = true
	Fire("UNIT_FACTION", "nameplate4")
	check(not Hidden(P[4]), "a friendly NPC shown for its widgets still shows")
	W.units.nameplate4.widgetsOnly = nil
	Fire("UNIT_FACTION", "nameplate4")

	M:SetFriendlyTargetOnly("friendlyPlayers", true)
	check(Hidden(P[5]) and Hidden(P[13]), "friendly players only for your target hides the players and the companion")
	check(not Hidden(P[1]) and not Hidden(P[2]), "and leaves enemies alone")
	W.alias.target = "nameplate5"
	Fire("PLAYER_TARGET_CHANGED")
	check(not Hidden(P[5]) and P[5].Name.__shown and Hidden(P[13]), "and shows the one you target")

	-- Off again: every plate is back, and the game's setting is left as it is.
	M:SetFriendlyTargetOnly("friendlyNPCs", false)
	M:SetFriendlyTargetOnly("friendlyPlayers", false)
	check(not Hidden(P[12]) and not Hidden(P[4]) and not Hidden(P[13]) and not Hidden(P[5]),
		"turned off, every friendly plate is back")
	check(W.cvars.nameplateShowFriendlyNpcs == "1", "and the game's setting stays on", W.cvars.nameplateShowFriendlyNpcs)
	W.alias.target = savedTarget
	Fire("PLAYER_TARGET_CHANGED")
	Step("friendly plates only for your target")

	-- Use Blizzard overall scale follows the game's Nameplate Size, Medium being AzeriteUI's 100%.
	W.profile.useBlizzardGlobalScale = true
	W.cvars.nameplateSize = "3"
	Fire("CVAR_UPDATE", "nameplateSize")
	check(near(Breakdown(P[2]).overallScale, 2 * 1.25), "Use Blizzard overall scale follows the game's Nameplate Size",
		Breakdown(P[2]).overallScale)
	check(near(P[2].__scale, Breakdown(P[2]).computedScale), "and the plates are redrawn when it changes", P[2].__scale)
	NamePlateConstants = { NAME_PLATE_SCALES = { [3] = { horizontal = 1.3 } } }
	Fire("CVAR_UPDATE", "nameplateSize")
	check(near(Breakdown(P[2]).overallScale, 2 * 1.3), "Blizzard's own table of sizes is read once it is loaded",
		Breakdown(P[2]).overallScale)
	NamePlateConstants = nil
	W.cvars.nameplateSize = "2"
	Fire("CVAR_UPDATE", "nameplateSize")
	check(near(Breakdown(P[2]).overallScale, 2), "at Medium the plates are at 100%", Breakdown(P[2]).overallScale)
	W.profile.useBlizzardGlobalScale = false
	M:UpdateSettings()
	Step("the game's Nameplate Size followed")

	-- Blizzard's driver sets its own plate size when its options change; ours is put back after it.
	local size = ns.GetConfig("NamePlates").Size
	W.driver.plateWidth, W.driver.plateHeight = 230, 60
	Fire("CVAR_UPDATE", "nameplateStyle")
	Flush()
	check(W.driver.plateWidth == size[1] and W.driver.plateHeight == size[2],
		"after Blizzard's driver resizes the plates, AzeriteUI's size is put back", W.driver.plateWidth)
	W.driver.plateWidth = 230
	Fire("DISPLAY_SIZE_CHANGED")
	Flush()
	check(W.driver.plateWidth == size[1], "and after the display changes size", W.driver.plateWidth)
	W.driver.plateWidth = 230
	W.combat = true
	Fire("PLAYER_REGEN_DISABLED")
	Fire("CVAR_UPDATE", "nameplateSize")
	Flush()
	check(W.driver.plateWidth == 230, "in combat that waits", W.driver.plateWidth)
	W.combat = false
	Fire("PLAYER_REGEN_ENABLED")
	check(W.driver.plateWidth == size[1], "and is done when combat ends", W.driver.plateWidth)

	-- The driver's own CVars.
	check(W.cvars.nameplatePlayerMaxDistance == W.cvars.nameplateMaxDistance,
		"other players' plates reach as far as Maximum distance says", W.cvars.nameplatePlayerMaxDistance)
	check(W.cvars.nameplateSimplifiedScale == "1", "the game does not shrink the plates it simplifies",
		W.cvars.nameplateSimplifiedScale)
	W.instance = { true, "pvp" }
	Fire("PLAYER_ENTERING_WORLD", false, false)
	check(W.cvars.nameplateMaxDistance == "60" and W.cvars.nameplatePlayerMaxDistance == "60",
		"in a battleground plates reach 60 yards by default, other players' included", W.cvars.nameplatePlayerMaxDistance)
	W.instance = { false, "none" }
	Fire("PLAYER_ENTERING_WORLD", false, false)
	W.profile.platePosition = "feet"
	M:UpdateSettings()
	check(W.cvars.nameplateOtherAtBase == "2", "Position at the feet is the game's nameplateOtherAtBase 2",
		W.cvars.nameplateOtherAtBase)
	W.profile.platePosition = "head"
	M:UpdateSettings()
	check(W.cvars.nameplateOtherAtBase == "0", "and over the head is 0", W.cvars.nameplateOtherAtBase)
	Step("the driver's size and CVars")
end

-- Plays nice (Phase 9): another nameplate addon enabled, the module stands down at login and keeps
-- the addon's name for the options page. Run against a copy of the profile, then put back.
do
	check(M.conflictingAddOn == nil, "with no other nameplate addon, nothing is named as a conflict", M.conflictingAddOn)
	local savedDB, savedRegister, savedEnabled = M.db, ns.db.RegisterNamespace, M.__enabled
	ns.db.RegisterNamespace = function(_, _, defaults)
		local fresh = {}
		for k, v in pairs(defaults.profile) do fresh[k] = v end
		return { profile = fresh }
	end
	W.addons = { Platynator = true }
	local writes, reloads = #W.cvarWrites, W.reloads
	M:OnInitialize()
	check(M.conflictingAddOn == "Platynator" and not M:IsEnabled(), "with Platynator enabled, AzeriteUI's nameplates stand down and say why",
		M.conflictingAddOn)
	check(#W.cvarWrites == writes, "standing down, AzeriteUI writes no nameplate CVar at login", W.cvarWrites[writes + 1])
	M.db.profile.scale = 3
	M:UpdateSettings()
	check(W.reloads == reloads, "a setting changed while standing down does not reload the interface", W.reloads - reloads)
	check(#W.cvarWrites == writes, "nor writes a CVar", W.cvarWrites[writes + 1])
	W.addons = nil
	M.conflictingAddOn = nil
	ns.db.RegisterNamespace, M.db, M.__enabled = savedRegister, savedDB, savedEnabled
end

W.profile.enabled = false
M:UpdateSettings()
Step("switch nameplates off")

--------------------------------------------------------------------------------
-- What the plan says must survive
--------------------------------------------------------------------------------
local function first(f) return f.__points[1] end

-- Captured at their steps above would be better; these read the final state, so each check names
-- the state it depends on.
check(P[6].isObjectPlate == true, "an ore vein is an object plate")
check(P[10].isObjectPlate == true, "a listed decorative NPC is an object plate")
check(P[4].isFriendlyAssistableNPC == true, "a listed trainer is a friendly NPC")
check(P[8].isPRD == true, "the player's own plate is the personal resource display")
check(P[9].canAttack == false and P[9].canAssist == false, "a plate whose hostility is secret is not assumed hostile or friendly")
check(P[6].Name.__shown and not P[6].Health.__shown, "a soft-targeted object shows its name and no health bar")
check(P[6].SoftTargetFrame.__alpha == 1 and P[6].SoftTargetFrame.__ignore == true,
	"a soft-targeted object keeps Blizzard's interact icon visible")
check(P[7].WidgetContainer.__shown, "a widget-only plate keeps its widgets when widgets are shown")
check(P[1].TargetHighlight.__shown, "the target's plate is outlined")
check(P[1].__scale > P[2].__scale, "the target's plate is larger than another hostile's")
check(not P[8].__enabled.RaidTargetIndicator and not P[8].__enabled.Auras and NativeOff(P[8]),
	"the PRD has no raid marker and no auras")

-- The golden steps carry the castbar colours; these pin the four states by name.
local function stepText(name)
	for i, line in ipairs(golden) do
		if (line == "== " .. name) then
			local block = {}
			for j = i + 1, #golden do
				if (golden[j]:sub(1, 3) == "== ") then break end
				block[#block + 1] = golden[j]
			end
			return table.concat(block, "\n")
		end
	end
	return ""
end
check(stepText("elite casts, interrupt ready"):find("cast shown@1 color=1,0.82,0", 1, true),
	"a cast you can interrupt now is yellow")
check(stepText("hostile casts, cannot be interrupted"):find("tex=0.5,0.5,0.5", 1, true) or
	stepText("hostile casts, cannot be interrupted"):find("tex=" .. col(ns.Colors.gray), 1, true),
	"a cast that cannot be interrupted is grey")
check(stepText("interrupt on cooldown mid-cast"):find("color=" .. col(ns.Colors.red), 1, true),
	"a cast while your interrupt is on cooldown is red")
check(stepText("elite's cast fails"):find("color=" .. col(ns.Colors.red), 1, true), "a failed cast is red")
check(stepText("switch nameplates off"):find("reloads 1", 1, true), "switching nameplates off reloads the interface")
check(#idleCastbarSteps == 0, "no step leaves an idle castbar on screen, not even for the frame before oUF hides it",
	string.format("%d, first: %s", #idleCastbarSteps, tostring(idleCastbarSteps[1])))
check(#W.errors == 0, "no guarded call reported an error", W.errors[1])
check(#W.unknownCVarWrites == 0, "no CVar the client does not have is ever written", W.unknownCVarWrites[1])

--------------------------------------------------------------------------------
-- Golden and metrics
--------------------------------------------------------------------------------
local function readFile(path)
	local f = io.open(path, "rb")
	if (not f) then return nil end
	local s = f:read("*a")
	f:close()
	return s
end
local function writeFile(path, s)
	local f = assert(io.open(path, "wb"))
	f:write(s)
	f:close()
end
local function compare(label, path, text)
	local expected = readFile(path)
	if (not expected) then
		check(false, label .. " file exists", path .. " (run with --record)")
		return
	end
	expected = expected:gsub("\r\n", "\n")
	if (expected == text) then
		check(true, label)
		return
	end
	local a, b = {}, {}
	for line in (expected .. "\n"):gmatch("(.-)\n") do a[#a + 1] = line end
	for line in (text .. "\n"):gmatch("(.-)\n") do b[#b + 1] = line end
	local step = "?"
	for i = 1, math.max(#a, #b) do
		if ((a[i] or ""):sub(1, 3) == "== ") then step = a[i] end
		if (a[i] ~= b[i]) then
			check(false, label .. " matches", string.format("first difference at line %d (%s)\n  expected: %s\n  actual:   %s",
				i, step, tostring(a[i]), tostring(b[i])))
			return
		end
	end
end

local goldenText = table.concat(golden, "\n") .. "\n"
local metricsText = table.concat(metrics, "\n") .. "\n"
if (flags["--record"]) then
	writeFile(GOLDEN, goldenText)
	print("recorded " .. GOLDEN)
else
	compare("golden", GOLDEN, goldenText)
end
if (flags["--record-metrics"]) then
	writeFile(METRICS, metricsText)
	print("recorded " .. METRICS)
elseif (flags["--metrics"]) then
	compare("metrics", METRICS, metricsText)
end
if (flags["--show-metrics"]) then io.write(metricsText) end

print(string.format("Nameplates: %d checks, %d failures", checks, failures))
-- Raised rather than os.exit, so mutate_client.lua can run this inside a pcall.
if (failures > 0) then error("nameplate harness failed", 0) end
