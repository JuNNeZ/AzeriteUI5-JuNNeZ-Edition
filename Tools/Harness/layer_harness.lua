-- Forever layer on the info bar (FixLog 2026-11-07). Loads the real Components/Misc/Info.lua and drives
-- Info.LayerFromGUID, Info.ReadLayer and Info.UpdateZone: the zone UID field of a creature GUID, taken only
-- when two different creatures in a row agree, never from players, pets, companions, other phases, secret
-- answers, in combat or in an instance; forgotten on a loading screen or zone change; Forever only.
-- Offline only: whether every creature on a layer carries the same zone UID is a live check.
-- Run: lua.exe Tools/Harness/layer_harness.lua <addon root>
local root = arg[1] or '.'
local checks, failures = 0, 0
local function check(v, msg, detail)
	checks = checks + 1
	if (not v) then
		failures = failures + 1
		print("FAIL: " .. msg .. (detail ~= nil and (" - " .. tostring(detail)) or ""))
	end
end

local secretMeta = {}
local function secret(v) return setmetatable({ value = v }, secretMeta) end
issecretvalue = function(v) return getmetatable(v) == secretMeta end

FPS_ABBR, HOME, WORLD, TUTORIAL_TITLE30 = "FPS", "Home", "World", "Resting"
GetCurrentRegionName = function() return "EU" end

local W
local units
local function Reset()
	W = { combat = false, instance = false }
	units = {}
end
Reset()
InCombatLockdown = function() return W.combat end
IsInInstance = function() return W.instance end
UnitExists = function(u) return units[u] ~= nil end
UnitGUID = function(u) return units[u] and units[u].guid end
UnitIsPlayer = function(u) return units[u] and units[u].player or false end
UnitPlayerControlled = function(u) return units[u] and units[u].controlled or false end
UnitIsOtherPlayersPet = function(u) return units[u] and units[u].pet or false end
UnitIsBattlePetCompanion = function(u) return units[u] and units[u].companion or false end
UnitPhaseReason = function(u) return units[u] and units[u].phase end
GetMinimapZoneText = function() return "Elwynn Forest" end
C_PvP = { GetZonePVPInfo = function() return nil end }

local Module
local ns = {
	MovableModulePrototype = { defaults = { profile = {} } },
	Merge = function(_, a, b) for k, v in pairs(b) do if (a[k] == nil) then a[k] = v end end return a end,
	NewModule = function() Module = {} return Module end,
	Colors = { normal = { 1, 1, 1 }, zone = {} },
	API = { GetLocalTime = function() end, GetServerTime = function() end },
	IsRetailContent = false,
}
LibStub = function() return { GetLocale = function() return setmetatable({}, { __index = function(_, k) return k end }) end } end

local chunk = assert(loadfile(root .. "/Components/Misc/Info.lua"))
chunk("AzeriteUI5_JuNNeZ_Edition", ns)
check(Module and type(Module.ReadLayer) == "function", "Info exports ReadLayer")

local text = {}
Module.zoneName = {
	GetAlpha = function() return 1 end,
	SetTextColor = function() end,
	SetText = function(_, s) text.value = s end,
	SetFormattedText = function(_, f, ...) text.value = string.format(f, ...) end,
}
local profile = { enableLayer = true }
Module.db = { profile = profile }

local G = Module.LayerFromGUID
check(G("Creature-0-5250-0-4012-299-0000ABCDEF") == 4012, "zone UID read from a creature GUID")
check(G("Vehicle-0-5250-0-4012-299-0000ABCDEF") == nil, "only creature GUIDs")
check(G("Player-5250-0ABCDEF") == nil, "players give nothing")
check(G("Creature-0-5250-0-0-299-0000ABCDEF") == nil, "zone UID 0 gives nothing")
check(G(secret("Creature-0-5250-0-4012-299-0000ABCDEF")) == nil, "a secret GUID gives nothing")
check(G(nil) == nil, "nil gives nothing")

local function C(layer, spawn) return { guid = ("Creature-0-5250-0-%d-299-%s"):format(layer, spawn) } end
local function Read(unit, u)
	units[unit] = u
	Module:ReadLayer(unit)
end

Module:ForgetLayer()
check(text.value == "Elwynn Forest", "no layer known: zone name alone", text.value)
Read("mouseover", C(7, "A"))
check(Module.layer == nil, "one creature is not enough")
Read("mouseover", C(7, "A"))
check(Module.layer == nil, "the same creature twice is not enough")
Read("target", C(7, "B"))
check(Module.layer == 7, "two different creatures agree: layer 7")
check(text.value == "Elwynn Forest |cff888888Layer 7|r", "shown after the zone name", text.value)

Read("nameplate1", C(9, "C"))
check(Module.layer == 7, "one straggler does not move it")
Read("nameplate2", C(7, "D"))
Read("nameplate3", C(9, "E"))
check(Module.layer == 7, "a straggler, the current value, a straggler: still 7")
Read("nameplate4", C(9, "F"))
check(Module.layer == 9, "two in a row with the new value move it")

for _, case in ipairs({
	{ "a player", { player = true } }, { "a player-controlled unit", { controlled = true } },
	{ "another player's pet", { pet = true } }, { "a companion", { companion = true } },
	{ "a unit in another phase", { phase = 1 } }, { "a secret phase answer", { phase = secret(1) } },
	{ "a secret player answer", { player = secret(true) } },
}) do
	local a, b = C(3, "X1"), C(3, "X2")
	for k, v in pairs(case[2]) do a[k] = v; b[k] = v end
	Read("nameplate5", a); Read("nameplate6", b)
	check(Module.layer == 9, "skipped: " .. case[1])
end

W.combat = true
Read("nameplate7", C(4, "G")); Read("nameplate8", C(4, "H"))
check(Module.layer == 9, "not read in combat")
W.combat = false
W.instance = true
Read("nameplate7", C(4, "G")); Read("nameplate8", C(4, "H"))
check(Module.layer == 9, "not read in an instance")
Module:UpdateZone()
check(text.value == "Elwynn Forest", "not shown in an instance", text.value)
W.instance = false

Module:OnLayerEvent("ZONE_CHANGED_NEW_AREA")
check(Module.layer == nil and text.value == "Elwynn Forest", "a zone change forgets it")
Read("target", C(5, "I"))
Module:OnLayerEvent("PLAYER_ENTERING_WORLD")
Read("target", C(5, "J"))
check(Module.layer == nil, "a loading screen forgets a half-seen candidate too")

units.mouseover = C(6, "K"); Module:OnLayerEvent("UPDATE_MOUSEOVER_UNIT")
units.target = C(6, "L"); Module:OnLayerEvent("PLAYER_TARGET_CHANGED")
check(Module.layer == 6, "mouseover and target events feed it")
units.nameplate9 = C(8, "M"); Module:OnLayerEvent("NAME_PLATE_UNIT_ADDED", "nameplate9")
units.nameplate10 = C(8, "N"); Module:OnLayerEvent("NAME_PLATE_UNIT_ADDED", "nameplate10")
check(Module.layer == 8, "nameplate events feed it")

profile.enableLayer = false
Module:UpdateZone()
check(text.value == "Elwynn Forest", "switch off: not shown")
Read("nameplate11", C(2, "O")); Read("nameplate12", C(2, "P"))
check(Module.layer == 8, "switch off: not read")
profile.enableLayer = true

ns.IsRetailContent = true
Module:UpdateZone()
check(text.value == "Elwynn Forest", "Retail: never shown")
Read("nameplate11", C(2, "O")); Read("nameplate12", C(2, "P"))
check(Module.layer == 8, "Retail: never read")
ns.IsRetailContent = false

units = {}
Module:ReadLayer("nameplate13")
Module:ReadLayer(nil)
check(true, "missing units are ignored")

print(("Layer: %d checks, %d failures (offline only)"):format(checks, failures))
if (failures > 0) then os.exit(1) end
