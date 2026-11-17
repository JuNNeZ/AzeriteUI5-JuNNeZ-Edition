-- Real source slices: independent aura viewports, unit reuse and per-bar settings.
-- Offline stubs only; does not emulate Blizzard widgets, rendering or secure clicks.
-- Run: lua Tools/Harness/neil_frame_options_harness.lua <addon root>
local root = arg[1] or "."
local checks = 0
local function check(value, message)
	checks = checks + 1
	assert(value, message)
end
local function read(path)
	local file = assert(io.open(root .. "/" .. path, "rb"))
	local text = file:read("*a"):gsub("\r\n", "\n")
	file:close()
	return text
end
local function slice(text, first, last)
	local a = assert(text:find(first, 1, true), first)
	local b = assert(text:find(last, a, true), last)
	return text:sub(a, b - 1)
end
local function run(code, env)
	local chunk = assert(loadstring(code))
	setfenv(chunk, setmetatable(env, { __index = _G }))
	return chunk()
end
local function region(harmful)
	return {
		isHarmful = harmful,
		SetSize = function(self, w, h) self.w, self.h = w, h end,
		ClearAllPoints = function() end,
		SetPoint = function(self, ...) self.point = { ... } end,
		SetScale = function(self, scale) self.scale = scale end,
		IsShown = function() return true end,
		Configure = function(self, config) self.config = config end
	}
end
local party = read("Components/UnitFrames/Units/Party.lua")
local profile = { AuraSize = 30, partyAuraDebuffScale = 150, AurasMaxCols = 3 }
local config = { AuraSize = 30, AurasNumTotal = 6, AurasPosition = { "TOPLEFT", 0, -100 } }
local ns = { GetConfig = function() return config end, PlayerAuraContainers = { BuildGroupFrameConfig = function(o) return o end } }
local env = { ns = ns, GetPartyAuraProfile = function() return profile end,
	math_floor = math.floor, math_max = math.max, math_min = math.min, math_ceil = math.ceil }
local helpers = slice(party, "local GetPartyAuraSetting = function", "local CreateHealthColors = function")
local layout, position = run(helpers .. slice(party, "local ApplyPartyAuraLayout = function", "-- The game's own filter decides")
	.. "\nreturn ApplyPartyAuraLayout, PartyAura_SetPosition", env)
local frame = { Auras = region(), NativeAuras = region(), NativeDebuffs = region() }
layout(frame)
check(profile.partyAuraDebuffSize == 45, "old relative size migrated without changing appearance")
check(frame.NativeAuras.w == 98 and frame.NativeDebuffs.w == 143, "each viewport fits exactly three differently sized icons")
check(frame.NativeAuras.h == 64 and frame.NativeDebuffs.h == 94, "each viewport reserves its own two rows")
check(frame.NativeDebuffs.point[5] == -36, "debuff viewport starts six pixels after first buff row")
profile.partyAuraRowGap = 40
layout(frame)
check(frame.NativeDebuffs.point[5] == -70, "slider reserves extra room for wrapped buff rows")
profile.partyAuraRowGap = -5
layout(frame)
check(frame.NativeDebuffs.point[5] == -30, "negative saved gap clamps to zero")
profile.partyAuraRowGap = 999
layout(frame)
check(frame.NativeDebuffs.point[5] == -190, "oversized saved gap clamps to slider maximum")
profile.partyAuraRowGap = nil
profile.AuraSize = 18
layout(frame)
check(frame.NativeDebuffs.config.harmfulSize == 45, "changing buffs preserves migrated debuff size")
profile.partyAuraDebuffSize = 24
profile.AurasGrowthY = "UP"
profile.AurasGrowthX = "LEFT"
layout(frame)
check(frame.NativeAuras.config.size == 18 and frame.NativeDebuffs.w == 80, "independent debuff resize")
check(frame.NativeDebuffs.point[5] == 24, "upward growth separates viewports in the correct direction")
local auras = frame.Auras
auras[1], auras[2], auras[3] = region(false), region(true), region(false)
position(auras, 1, 3)
check(auras[1].w == 18 and auras[2].w == 24, "fallback uses independent actual dimensions")
check(auras[1].point[5] == 0 and auras[2].point[5] == 24, "fallback debuffs use a separate line with a border gap")
check(auras[3].point[4] == -22, "fallback left growth retains separate buff columns")
auras[1].isHarmful = true
position(auras, 1, 3)
check(auras[1].point[5] == 24 and auras[3].point[5] == 0, "same-count type replacement repositions correctly")
profile.partyAuraRowGap = 40
layout(frame)
position(auras, 1, 3)
check(auras[1].point[5] == 58, "fallback also applies the saved row gap")
auras[3].isHarmful = true
position(auras, 1, 3)
check(auras[1].point[5] == 0, "fallback with no buffs leaves no empty buff rows")
profile.partyAuraRowGap = nil

local containers = read("Components/UnitFrames/Auras/PlayerAuraContainers.lua")
ns.PlayerAuraContainers = {}
run(slice(containers, "local GROUP_HELPFUL_OWN =", "local GROUP_FRAME_CONFIG_FIELDS ="), { ns = ns })
local created = {}
ns.PlayerAuraContainers.CreateForGroupUnit = function(_, _, options) return options end
config.AurasSize = { 98, 64 }
run(slice(party, '\tif (ns.PlayerAuraContainers and ns.PlayerAuraContainers.CreateForGroupUnit) then', '\n\tApplyPartyAuraLayout(self)'),
	{ ns = ns, self = created, unit = "party1", db = config })
local groups = ns.PlayerAuraContainers.GroupFrameGroup
for _, key in ipairs(ns.PlayerAuraContainers.GroupFrameKeys) do
	check((created.NativeAuras.groupKeys[key] == true) ~= (created.NativeDebuffs.groupKeys[key] == true), "each category belongs to exactly one viewport: " .. key)
end
check(created.NativeDebuffs.groupKeys[groups.HarmfulOther] and not created.NativeAuras.groupKeys[groups.HarmfulOther], "non-dispellable debuffs cannot enter the buff viewport")
run(slice(containers, "ns.PlayerAuraContainers.UpdateGroupFrameUnit = function", "--[["), { ns = ns })
for _, display in ipairs({ frame.NativeAuras, frame.NativeDebuffs }) do
	display.SetDisplayUnit = function(self, unit)
		local changed = self.unit ~= unit
		self.unit = unit
		return changed
	end
	display.ForceUpdate = function(self) self.refreshed = true end
end
frame.unit = "party2"
ns.PlayerAuraContainers.UpdateGroupFrameUnit(frame, "RefreshUnit")
check(frame.NativeAuras.unit == "party2" and frame.NativeDebuffs.unit == "party2", "both aura types follow roster token reuse")
ns.PlayerAuraContainers.UpdateGroupFrameUnit(frame, "RefreshUnit")
check(frame.NativeAuras.refreshed and frame.NativeDebuffs.refreshed, "both aura types refresh on full update")

-- Toggle the actual party update path: hide the icon while retaining its glow.
local partyModule = {}
local glowUpdates = 0
local unit = { NativeAuras = {}, NativeDebuffs = {}, Auras = { ForceUpdate = function() end }, PriorityDebuff = {} }
unit.EnableElement = function(self, key) self[key .. "Enabled"] = true end
unit.DisableElement = function(self, key) self[key .. "Enabled"] = false end
unit.PriorityDebuff.Hide = function(self) self.hidden = true end
unit.RaidTargetIndicator = { Hide = function() end }
unit.SetAlpha = function() end
unit.UpdateAllElements = function() end
for _, display in ipairs({ unit.NativeAuras, unit.NativeDebuffs }) do
	display.SetDisplayEnabled = function(self, enabled) self.enabled = enabled end
	display.ForceUpdate = function() end
end
run(slice(party, "PartyFrameMod.UpdateUnits = function", "PartyFrameMod.Update = function"), {
	PartyFrameMod = partyModule, Units = { [unit] = true }, ApplyHealthColorMode = function() end,
	ApplyPartyAuraLayout = function() end, AuraHighlight_Update = function() glowUpdates = glowUpdates + 1 end,
	ns = { RangeFade = { Release = function() end } }
})
local driver = { frame = true, db = { profile = { showAuras = true, showPriorityDebuff = false } } }
partyModule.UpdateUnits(driver)
check(unit.PriorityDebuffEnabled == false and unit.PriorityDebuff.hidden and glowUpdates == 1, "icon off leaves independent dispel highlight update active")
check(unit.NativeAuras.enabled and unit.NativeDebuffs.enabled and not unit.AurasEnabled, "both native rows replace scanning together")
driver.db.profile.showAuras = false
driver.db.profile.showPriorityDebuff = true
partyModule.UpdateUnits(driver)
check(not unit.NativeAuras.enabled and not unit.NativeDebuffs.enabled and unit.PriorityDebuffEnabled, "rows hide together while portrait icon can remain enabled")

local combat = false
local actions = {}
local noop = function() end
local barsNS = { ActionBarProcHighlight = { UpdatePreview = noop, Apply = noop },
	ActionBarAssistedHighlight = { UpdatePreview = noop, Apply = noop }, ActionButton = { UpdateMouseoverCast = noop },
	GetModule = noop, Copy = function(_, original) local copy = {} for k, v in pairs(original) do copy[k] = v end return copy end }
local barsSource = read("Components/ActionBars/Elements/ActionBars.lua")
run(slice(barsSource, "ActionBarMod.UpdateSettings = function", "ActionBarMod.OnCVarUpdate = function"),
	{ ns = barsNS, ActionBarMod = actions, InCombatLockdown = function() return combat end })
local sharedHide = { macro = true, hotkey = false }
local module = { db = { profile = { hideElements = sharedHide } }, bars = {} }
for _, key in ipairs({ "UpdateEnabled", "UpdateBars", "UpdateBarButtonCounts", "UpdateBindings", "UpdatePositionAndScales", "UpdateAnchors", "UnregisterEvent" }) do module[key] = noop end
module.RegisterEvent = function(self, event) self.queued = event end
for i = 1, 2 do
	module.bars[i] = { config = {}, buttons = { { config = {}, UpdateConfig = function(self, value) self.applied = value end } } }
end
module.bars[1].config.showRangeIndicator = false
module.bars[1].config.showButtonCount = false
actions.UpdateSettings(module)
local one, two = module.bars[1].buttons[1].config, module.bars[2].buttons[1].config
check(one.outOfRangeColoring == "none" and two.outOfRangeColoring == "button", "range toggle affects only its own bar")
check(one.hideElements.count == true and two.hideElements.count == false, "count toggle affects only its own bar")
check(sharedHide.count == nil and one.hideElements ~= two.hideElements, "global count settings remain unmodified")
check(one.hideElements.macro and not one.hideElements.hotkey, "unrelated text preferences preserved")
module.bars[1].config.showRangeIndicator = true
module.bars[1].config.showButtonCount = true
actions.UpdateSettings(module)
check(one.outOfRangeColoring == "button" and not one.hideElements.count, "toggles restore range and count")
combat = true
module.bars[1].config.showRangeIndicator = false
actions.UpdateSettings(module)
check(module.queued == "PLAYER_REGEN_ENABLED" and one.outOfRangeColoring == "button", "combat changes defer before touching button configuration")
combat = false
actions.UpdateSettings(module, "PLAYER_REGEN_ENABLED")
check(one.outOfRangeColoring == "none", "deferred preference applies after combat")
print(("Neil frame options: %d checks, 0 failures"):format(checks))
