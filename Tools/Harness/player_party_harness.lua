-- The player as a party frame (Components/UnitFrames/Units/PlayerParty.lua, FixLog 2026-10-17).
--
-- Loads the real module and the real party layout (Layouts/Data/PartyUnitFrames.lua) and drives
-- a recorded frame: it spawns once (the Retail/Forever start-up enables after creating), the
-- portrait switch shrinks the frame to its bar and moves the badges onto the bar and back,
-- nothing is laid out in combat until it ends, Legacy keeps its own layout, a profile with
-- another player frame on keeps this one off, and Color by Class reaches the health bar.
-- The style itself (Party.lua) is not run here; the panel and real-options harnesses cover the
-- option table, frame_panel_harness the one-at-a-time switches.
--
-- lua Tools/Harness/player_party_harness.lua .
local root = arg[1] or "."

local checks, failures = 0, 0
local function check(value, label, detail)
	checks = checks + 1
	if (not value) then
		failures = failures + 1
		print("FAIL: " .. label .. (detail ~= nil and ("  (" .. tostring(detail) .. ")") or ""))
	end
end

-- Regions that record what they are told.
local function Region(name, parent)
	local r = { name = name, parent = parent, shown = true, points = {} }
	function r:ClearAllPoints() self.points = {} end
	function r:SetPoint(...) self.points[#self.points + 1] = { ... } end
	function r:SetSize(w, h) self.w, self.h = w, h end
	function r:GetSize() return self.w or 0, self.h or 0 end
	function r:GetParent() return self.parent end
	function r:SetShown(shown) self.shown = shown and true or false end
	function r:Show() self.shown = true end
	function r:Hide() self.shown = false end
	return r
end

local combat = false
local spawns = 0
local legacyActive = false

local function NewFrame()
	local frame = Region("frame")
	frame.elements = { Portrait = true }
	frame.attributes = {}
	function frame:SetAttribute(k, v) self.attributes[k] = v end
	function frame:IsElementEnabled(e) return self.elements[e] and true or false end
	function frame:EnableElement(e) self.elements[e] = true end
	function frame:DisableElement(e) self.elements[e] = false end
	function frame:PostUpdate(event) self.postUpdated = event end
	frame.Health = Region("health", frame)
	frame.Health.forced = 0
	function frame.Health:ForceUpdate() self.forced = self.forced + 1 end
	local holder = Region("portraitHolder", frame)
	local ring = Region("portraitRing", frame)
	frame.Portrait = Region("portrait", holder)
	frame.Portrait.forced = 0
	function frame.Portrait:ForceUpdate() self.forced = self.forced + 1 end
	frame.Portrait.Border = Region("portraitBorder", ring)
	frame.holder, frame.ring = holder, ring
	frame.GroupRoleIndicator = Region("role", frame)
	frame.GroupRoleIndicator.Backdrop = Region("roleBackdrop", frame.GroupRoleIndicator)
	frame.GroupRoleIndicator.Icon = Region("roleIcon", frame.GroupRoleIndicator)
	for _, key in ipairs({ "LeaderIndicator", "AssistantIndicator", "RaidTargetIndicator", "ReadyCheckIndicator",
		"ResurrectIndicator", "SummonIndicator", "CombatFeedback" }) do
		frame[key] = Region(key, frame)
	end
	return frame
end

-- ns, as far as the module and the layout file use it.
local modules = {}
local config = {}
local events = {}
local function Merge(target, source)
	for k, v in pairs(source) do if (target[k] == nil) then target[k] = v end end
	return target
end
local ns = {
	Prefix = "Azerite",
	Colors = setmetatable({}, { __index = function() return { 1, 1, 1 } end }),
	API = {
		GetEffectiveScale = function() return 1 end,
		GetFont = function(size) return "font" .. tostring(size) end,
		GetMedia = function(name) return "media/" .. name end,
		TryCall = function(fn, ...) return pcall(fn, ...) end,
		SafeCall = function(_, fn, ...) return pcall(fn, ...) end
	},
	RegisterConfig = function(name, data) config[name] = data end,
	GetConfig = function(name) return config[name] end,
	Merge = function(_, target, source) return Merge(target, source) end,
	MovableModulePrototype = { defaults = { enabled = true }, OnEnable = function(self) self.movableEnabled = true end },
	UnitFrameModule = {},
	UnitFrame = {
		Spawn = function(unit, name)
			spawns = spawns + 1
			local frame = NewFrame()
			frame.unit, frame.globalName = unit, name
			return frame
		end
	},
	LegacyHUD = { IsActive = function() return legacyActive end },
	oUF = {
		RegisterStyle = function(_, name, fn) config.__style = { name = name, fn = fn } end,
		SetActiveStyle = function() end
	}
}
ns.GetModule = function(_, name) return modules[name] end
ns.NewModule = function(_, name, proto)
	local module = setmetatable({ name = name }, { __index = proto })
	function module:GetName() return self.name end
	function module:RegisterEvent(event, method) events[event .. ":" .. method] = true end
	function module:UnregisterEvent(event, method) events[event .. ":" .. method] = nil end
	function module:CreateAnchor(label) self.anchor = { label = label }; return self.anchor end
	function module:UpdateAnchor() self.anchorUpdates = (self.anchorUpdates or 0) + 1 end
	modules[name] = module
	return module
end

_G.UIParent = Region("UIParent")
_G.InCombatLockdown = function() return combat end
_G.RegisterAttributeDriver = function(frame, attribute, value) frame.attributes[attribute] = value end
_G.UnregisterAttributeDriver = function(frame, attribute) frame.attributes[attribute] = nil end
_G.UnregisterUnitWatch = function(frame) frame.unitWatch = false end

local function load(relative)
	local chunk = assert(loadfile(root .. "/" .. relative))
	return chunk("AzeriteUI5_JuNNeZ_Edition", ns)
end
load("Layouts/Data/PartyUnitFrames.lua")
local db = config.PartyFrames
check(type(db) == "table" and db.PlayerCompactSize and db.UnitSize, "the party layout loads with the compact keys")

-- The party module only lends its style.
modules.PartyFrames = { StylePlayer = function() end }
load("Components/UnitFrames/Units/PlayerParty.lua")
local mod = modules.PlayerFrameParty
check(mod ~= nil, "the module registers as PlayerFrameParty")

-- Start-up: another player frame on keeps this one off.
modules.PlayerFrame = { db = { profile = { enabled = true } } }
modules.PlayerFrameAlternate = { db = { profile = { enabled = false } } }
mod.db = { profile = Merge({ enabled = true, showPortrait = true, useClassColor = true }, {}) }
mod:PostInitialize()
check(mod.db.profile.enabled == false, "a profile with Player on keeps the party style off")
modules.PlayerFrame.db.profile.enabled = false
modules.PlayerFrameAlternate.db.profile.enabled = true
mod.db.profile.enabled = true
mod:PostInitialize()
check(mod.db.profile.enabled == false, "and so does one with Player Alternate on")
modules.PlayerFrameAlternate.db.profile.enabled = false
mod.db.profile.enabled = true
mod:PostInitialize()
check(mod.db.profile.enabled == true, "with both others off it stays on")

-- Spawned once, though the start-up creates before it enables.
mod:CreateUnitFrames()
mod:OnEnable()
check(spawns == 1, "the frame is spawned once", spawns)
check(config.__style and config.__style.name == "AzeritePlayerParty", "its own style name, which Legacy lists", config.__style and config.__style.name)
local frame = mod.frame
check(frame.unit == "player" and frame.unitWatch == false, "a player frame without a unit watch")
check(mod.anchor and mod.anchor.label == "PlayerFrame (Party)", "with its own mover")
frame:Enable()
check(frame.attributes.unit == "[vehicleui]vehicle; player", "it follows the vehicle like the other player frames", frame.attributes.unit)

-- Full look.
mod:Update()
check(frame.w == db.UnitSize[1] and frame.h == db.UnitSize[2], "with the portrait it is a party member's size", frame.h)
check(frame.holder.shown and frame.ring.shown and frame:IsElementEnabled("Portrait"), "and the portrait shows")
check(frame.Health.colorClass == true and frame.Health.colorHealth == true and frame.Health.forced > 0, "Color by Class reaches the health bar")
check(frame.GroupRoleIndicator.points[1][1] == db.GroupRolePosition[1], "the role plate hangs where the party layout puts it")

-- Portrait off: just the bar.
mod.db.profile.showPortrait = false
mod:Update()
check(frame.w == db.PlayerCompactSize[1] and frame.h == db.PlayerCompactSize[2], "without the portrait the frame shrinks to the bar", frame.h)
check(not frame.holder.shown and not frame.ring.shown, "the portrait, its ring and the threat glow behind it hide")
check(not frame:IsElementEnabled("Portrait"), "and the 3D portrait stops updating")
local rolePoint = frame.GroupRoleIndicator.points[1]
check(rolePoint and rolePoint[2] == frame.Health and rolePoint[1] == db.PlayerCompactGroupRolePosition[1],
	"the role plate moves beside the bar", rolePoint and rolePoint[1])
check(frame.GroupRoleIndicator.Icon.w == db.PlayerCompactGroupRoleIconSize[1], "at the compact size")
check(frame.LeaderIndicator.points[1][2] == frame.Health and frame.AssistantIndicator.points[1][2] == frame.Health,
	"leader and assistant sit on the bar")
check(frame.RaidTargetIndicator.points[1][2] == frame.Health, "and the raid marker")
check(frame.ReadyCheckIndicator.points[1][2] == frame.Health and frame.SummonIndicator.points[1][2] == frame.Health
	and frame.ResurrectIndicator.points[1][2] == frame.Health, "ready check, summon and resurrect sit on the bar")
check(frame.CombatFeedback.points[1][2] == frame.Health, "combat text floats over the bar, not the hidden portrait")
check(mod.anchorUpdates and mod.anchorUpdates > 0, "the mover follows the new size")

-- Back on: everything returns.
local forcedBefore = frame.Portrait.forced
mod.db.profile.showPortrait = true
mod:Update()
check(frame.h == db.UnitSize[2] and frame.holder.shown and frame:IsElementEnabled("Portrait"), "portrait on restores the full frame")
check(frame.Portrait.forced > forcedBefore, "and redraws the portrait")
check(frame.GroupRoleIndicator.points[1][2] ~= frame.Health, "the role plate goes back to the top")
check(frame.CombatFeedback.points[1][2] == frame.Portrait, "combat text goes back to the portrait")

-- In combat a unit button cannot be resized: wait for the end of combat.
combat = true
mod.db.profile.showPortrait = false
mod:Update()
check(frame.h == db.UnitSize[2], "in combat nothing is laid out")
check(events["PLAYER_REGEN_ENABLED:OnLayoutEvent"], "the layout waits for the end of combat")
combat = false
mod:OnLayoutEvent("PLAYER_REGEN_ENABLED")
check(frame.h == db.PlayerCompactSize[2], "and is applied when combat ends", frame.h)
check(not events["PLAYER_REGEN_ENABLED:OnLayoutEvent"], "then stops waiting")

-- Legacy draws its own casing from the party layout and hides the portrait itself.
legacyActive = true
mod:Update()
check(frame.h == db.UnitSize[2] and frame.holder.shown, "under Legacy the portrait switch leaves the layout alone")
legacyActive = false

-- Color by Class off.
mod.db.profile.useClassColor = false
mod:Update()
check(frame.Health.colorClass == false and frame.Health.colorHealth == true, "Color by Class off colours by health")

frame:Disable()
check(frame.attributes.unit == nil and not frame.shown and not frame:IsEnabled(), "off hides the frame and drops its unit driver")

print(string.format("Player party frame: %d checks, %d failures", checks, failures))
if (failures > 0) then error("player party harness failed", 0) end
