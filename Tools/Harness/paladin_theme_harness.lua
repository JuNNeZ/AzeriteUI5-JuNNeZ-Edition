-- Offline contract tests: real theme, media resolver and layout tables.
-- Does not emulate rendering or claim live Retail/Forever coverage.
local root = arg[1] or "."
local checks, reloads, combat = 0, 0, false
local function check(value, label)
	checks = checks + 1
	assert(value, label)
end
local env = setmetatable({}, { __index = _G })
env._G = env
env.ITEM_QUALITY_COLORS = {}
env.Enum = { PowerType = { Mana = 0, HolyPower = 9 } }
env.RAID_CLASS_COLORS = { PALADIN = { r = .95, g = .5, b = .7 } }
env.CreateFont = function(name)
	return { name = name, SetJustifyH = function() end, GetObjectType = function() return "Font" end }
end
env.InCombatLockdown = function() return combat end
env.ReloadUI = function() reloads = reloads + 1 end
local ns = { API = {}, Prefix = "AzeriteTest" }
local function load(path)
	local chunk = assert(loadfile(root.."/"..path))
	setfenv(chunk, env)
	chunk("AzeriteUI5_JuNNeZ_Edition", ns)
end
function ns:NewModule()
	return {
		RegisterChatCommand = function(self, command) self.command = command end,
		RegisterEvent = function(self, event) self.event = event end,
		UnregisterEvent = function(self) self.event = nil end,
		Print = function(self, message) self.message = message end
	}
end
function ns:GetActiveConfigVariant() return self.variant end
function ns:IsSaiyaRattProfile() return self.variant == "SaiyaRatt" end
load("Core/Private.lua")
ns.Private.PlayerClass = "PALADIN"
load("Core/API/Tables.lua")
load("Core/Common/Colors.lua")
load("Core/API/Assets.lua")
load("Core/PaladinTheme.lua")
load("Core/Finalize.lua")
load("Layouts/Layouts.lua")
for _, file in ipairs({ "PlayerUnitFrame", "PlayerUnitFrameAlternate", "TargetUnitFrame",
	"BossUnitFrames", "PlayerClassPower", "PlayerCastBar", "NamePlates", "ActionButton",
	"PetActionButton", "StanceButton", "ExtraActionButton", "Tooltips", "FocusUnitFrame", "ToTUnitFrame",
	"PetUnitFrame", "PartyUnitFrames", "RaidUnitFrames5", "RaidUnitFrames40", "ArenaEnemyUnitFrames", "MirrorTimers", "StatusBars", "VehicleExitButton" }) do
	load("Layouts/Data/"..file..".lua")
end
local theme = ns.PaladinTheme
check(not theme:IsActive(), "no DB at file load")
local original = ns.GetConfig("PlayerFrame")
local originalAction = ns.GetConfig("ActionButton")
local originalPoints = ns.GetConfig("PlayerClassPower").ClassPowerLayouts.ComboPoints
local originalGroups = {}
for _, name in ipairs({ "PetFrame", "PartyFrames", "Raid5Frames", "RaidFrames", "ArenaFrames", "MirrorTimers" }) do originalGroups[name] = ns.GetConfig(name) end
local compactOriginals = { FocusFrame = ns.GetConfig("FocusFrame"), ToTFrame = ns.GetConfig("ToTFrame") }
ns.db = { global = {}, char = {}, RegisterCallback = function() end }
ns.db.char.paladinPreview = true
check(not theme:IsActive(), "saved request alone does not enable development art")
check(ns.GetConfig("PlayerFrame") == original, "dev-off returns original table")
theme:OnInitialize()
check(not theme.command, "hidden command unavailable outside dev mode")
ns.db.global.enableDevelopmentMode = true
theme:OnInitialize()
check(theme.command == "azpaladin", "secret command registered in dev mode")
check(theme:IsActive(), "main theme can enable preview")
check(not theme:UseIceCrystal(true), "Paladin preview overrides seasonal/ice art without saving a preference")
check(ns.GetConfig("PlayerFrameAlternate").PowerBarColors.MANA[1] == 1, "alternate player has holy mana")
for name, before in pairs(originalGroups) do
	local after = ns.GetConfig(name)
	local prefix = name == "MirrorTimers" and "MirrorTimer" or "Health"
	check(after[prefix.."BackdropTexture"]:find("compact-case",1,true), name.." simple casing coverage")
	check(after[prefix.."BarTexture"] == before[prefix.."BarTexture"], name.." semantic fill preserved")
	for i,v in ipairs(before[prefix.."BackdropSize"]) do check(after[prefix.."BackdropSize"][i] == v,name.." native casing dimensions") end
end
check(ns.GetConfig("PartyFrames").PortraitBorderTexture:find("party-case",1,true), "party portrait coverage")
check(ns.GetConfig("StatusBars").RingFrameBackdropTexture:find("status-backdrop",1,true), "status wheel casing coverage")
check(ns.GetConfig("VehicleExitButton").VehicleExitButtonTexture:find("vehicle-exit",1,true), "vehicle exit art coverage")
check(ns.Private == nil and ns.PlayerClass == "PALADIN", "real finalized namespace exposes class without Private")
for name, before in pairs(compactOriginals) do
	local after = ns.GetConfig(name)
	check(after.HealthBackdropTexture:find("compact-case", 1, true), name.." has new casing")
	for _, field in ipairs({ "HealthBarSize", "HealthBackdropSize", "HealthBackdropPosition", "TargetHighlightSize" }) do
		for i, value in ipairs(before[field]) do check(after[field][i] == value, name.." preserves "..field) end
	end
	check(after.HealthBarTexture == before.HealthBarTexture and after.TargetHighlightTexture == before.TargetHighlightTexture,
		name.." preserves fill and matching semantic highlight")
end
-- Exercise the actual color resolver, including the saved enhanced/class modes
-- that caused the reported blue crystal. Stub only its palette dependencies.
local file = assert(io.open(root.."/Components/UnitFrames/Units/Player.lua", "r"))
local source = file:read("*a"); file:close()
local resolverSource = assert(source:match("local ResolvePlayerPowerBaseColor = function.-\nend"))
local resolverChunk = assert(loadstring(resolverSource.."\nreturn ResolvePlayerPowerBaseColor"))
local default, enhanced, class = { .1, .2, .8 }, { .2, .4, 1 }, { .95, .5, .7 }
setfenv(resolverChunk, {
	ns = ns, Colors = { class = { PALADIN = class } }, playerClass = "PALADIN",
	POWER_CRYSTAL_ENHANCED_COLORS = { MANA = enhanced },
	ResolvePlayerPowerDefaultColor = function() return default end,
	ResolvePlayerPowerColorFromTable = function(t, token, fallback) return t[token] or fallback end
})
local resolve = resolverChunk()
-- The theme colour stands in for Default only; Enhanced and Class Color are the
-- player's explicit choice and win over it (FixLog 2026-10-03, orb step 7).
local expected = { default = "holy", enhanced = enhanced, new = enhanced, classColor = class, class = class }
for _, mode in ipairs({ "default", "enhanced", "new", "classColor", "class" }) do
	local profile = { crystalOrbColorMode = mode }
	local color = resolve({}, profile, "MANA")
	if (expected[mode] == "holy") then
		check(color[1] == 1 and color[2] == .78 and color[3] == .28, "holy mana replaces "..mode)
	else
		check(color == expected[mode], "the player's "..mode.." choice wins over holy mana")
	end
	check(profile.crystalOrbColorMode == mode, "saved mode is unchanged")
end
check(resolve({}, {}, "MANA")[2] == .78, "holy mana with no saved mode")
check(resolve({}, {}, "RAGE") == default, "non-mana power retains resolver")
ns.db.char.paladinPreview = false
check(resolve({}, {}, "MANA") == default, "off restores default mana")
check(resolve({}, { crystalOrbColorMode = "enhanced" }, "MANA") == enhanced, "off restores enhanced mana")
check(resolve({}, { crystalOrbColorMode = "classColor" }, "MANA") == class, "off restores class mana")
ns.db.char.paladinPreview = true
local themed = ns.GetConfig("PlayerFrame")
check(themed ~= original, "theme owns a copied layout")
for _, tier in ipairs({ "Novice", "Hardened", "Seasoned" }) do
	check(themed[tier].HealthBarSize[1] == 373 and original[tier].HealthBarSize[1] == 385, "player shortened without changing source layout")
end
check(ns.GetConfig("TargetFrame").Seasoned.HealthBarSize[1] == 385, "target width preserved")
check(ns.GetConfig("PlayerFrameAlternate").Seasoned.HealthBarSize[1] == 385, "portrait player width preserved")
check(themed.HealthValueFont == original.HealthValueFont, "native font object identity preserved")
local anchor = { GetObjectType = function() return "Frame" end }
anchor.circular = anchor
ns.RegisterConfig("NativeAnchor", { Position = { "CENTER", anchor } })
check(ns.GetConfig("NativeAnchor").Position[2] == anchor, "native frame anchors are not copied or traversed")
check(themed == ns.GetConfig("PlayerFrame"), "resolved copy reused")
check(themed.PowerOrbColors.MANA[1] == 1, "mana has runtime Holy Light color")
check(original.PowerOrbColors.MANA[1] ~= 1, "source palette unchanged")
check(themed.PowerOrbColors.RAGE[1] == original.PowerOrbColors.RAGE[1], "non-mana colors preserved")
check(themed.Seasoned.HealthBarTexture == original.Seasoned.HealthBarTexture, "health fill not gold art")
check(themed.Seasoned.HealthAbsorbColor[1] == original.Seasoned.HealthAbsorbColor[1], "absorb color retained")
check(themed.Seasoned.PowerBarTexture == original.Seasoned.PowerBarTexture, "Azerite crystal facets retained")
for _, name in ipairs({ "ActionButton", "PetActionButton", "StanceButton" }) do
	local config = ns.GetConfig(name)
	check(config.ButtonBorderTexture:find("Paladin", 1, true), name.." casing routed")
	check(not config.ButtonMaskTexture:find("Paladin", 1, true), name.." icon mask retained")
end
check(ns.GetConfig("ExtraActionButton").ExtraButtonBorderTexture:find("Paladin",1,true), "extra action art routed")
check(originalAction.ButtonBorderTexture:find("actionbutton%-border"), "original action art untouched")
local points = ns.GetConfig("PlayerClassPower").ClassPowerLayouts.ComboPoints
check(#points == 5 and points[5].Texture:find("holy-fill",1,true), "five holy seals")
for i, point in ipairs(points) do
	local centers = { {88,164}, {57,126}, {44,84}, {57,42}, {88,4} }
	check(math.abs(point.Position[2]+point.Size[1]/2-centers[i][1]) < .00001
		and math.abs(point.Position[3]-point.Size[2]/2+centers[i][2]) < .00001, "larger seals follow the widened arc")
	check(math.abs(point.Size[1]-(i == 5 and 44 or 40)*1.56) < .00001, "holy seals enlarged thirty percent over previous preview")
	check(point.BackdropTexture:find("holy-case",1,true) and point.PointRotation == 0, "upright sacred casing replaces round plate")
	check(point.Size[1] == point.BackdropSize[1] and point.Size[2] == point.BackdropSize[2], "holy fill and casing share the same pixel scale")
end
check(ns.GetConfig("PlayerClassPower").ClassPowerLayouts.Runes[1].Texture:find("point_rune",1,true), "runes untouched")
check(ns.GetConfig("TargetFrame").Seasoned.PortraitBorderTexture:find("Paladin",1,true), "target portrait casing")
check(ns.GetConfig("PlayerFrameAlternate").Seasoned.PortraitBorderTexture:find("Paladin",1,true), "alternate portrait casing")
check(theme:ResolvePath("Interface\\AddOns\\AzeriteUI5_JuNNeZ_Edition\\Assets\\minimap-border.tga"):find("Paladin",1,true), "late minimap resolution")
check(not ns.API.GetMedia("nameplate_bar"):find("Paladin",1,true), "nameplate gameplay fill untouched")
check(not ns.API.GetMedia("actionbutton-glow-white"):find("Paladin",1,true), "semantic highlight remains neutral")
ns.variant = "SaiyaRatt"
check(not theme:IsActive(), "SaiyaRatt excluded")
check(not ns.GetConfig("ActionButton").ButtonBorderTexture:find("Paladin",1,true), "SaiyaRatt does not inherit cached theme")
theme:Command("on")
check(reloads == 0, "SaiyaRatt enable request refused")
ns.variant = nil
combat = true
theme:Command("off")
check(reloads == 0 and ns.db.char.paladinPreview, "combat command changes nothing")
combat = false
theme:Command("off")
check(reloads == 1 and not ns.db.char.paladinPreview, "off saves and reloads")
check(ns.GetConfig("PlayerFrame") == original, "off returns pristine layout")
check(theme:UseIceCrystal(true), "off restores requested seasonal/ice art")
theme:Command("on")
check(reloads == 2 and theme:IsActive(), "on saves and reloads")
theme:Command("status")
check(reloads == 2, "status does not reload")

-- Strict scene graph: resource getters deliberately fail. Clipping must follow
-- native texture anchors without interrogating protected mana or dimensions.
local widgetCount = 0
local function widget(parent)
	widgetCount = widgetCount + 1
	local w = { parent = parent, points = {}, children = {}, shown = true, level = 2, width = 385, height = 40 }
	if parent then parent.children[#parent.children+1] = w end
	function w:SetAllPoints(anchor) self.allPoints = anchor end
	function w:SetPoint(point, ...) self.points[point] = { ... } end
	function w:ClearAllPoints() self.points = {} end
	function w:SetSize(x, y) self.width, self.height = x, y end
	function w:GetWidth() return self.width end
	function w:GetHeight() return self.height end
	function w:SetFrameLevel(v) self.level = v end
	function w:GetFrameLevel() return self.level end
	function w:EnableMouse(v) self.mouse = v end
	function w:SetTexture(value) self.texture = value end
	function w:SetTexCoord(...) self.coords = { ... } end
	function w:SetVertexColor(...) self.color = { ... } end
	function w:SetColorTexture(...) self.color = { ... } end
	function w:SetAlpha(value) self.alpha = value end
	function w:SetBlendMode(value) self.blendMode = value end
	function w:SetShown(value) self.shown = value end
	function w:SetClipsChildren(value) self.clips = value end
	function w:AddMaskTexture(mask) self.mask = mask end
	function w:CreateTexture() return widget(self) end
	function w:CreateMaskTexture() return widget(self) end
	function w:GetStatusBarTexture() self.fill = self.fill or widget(self); return self.fill end
	function w:SetStatusBarTexture(...) self.fillPaths = { ... } end
	function w:GetOverlay() self.clip = self.clip or widget(self); return self.clip end
	function w:GetValue() error("theme read resource value") end
	function w:GetMinMaxValues() error("theme read resource range") end
	function w:CreateAnimationGroup()
		local group = {}
		function group:CreateAnimation()
			return { SetFromAlpha = function() end, SetToAlpha = function() end,
				SetDuration = function() end, SetOrder = function() end }
		end
		function group:SetLooping() end
		function group:Play() end
		return group
	end
	return w
end
env.CreateFrame = function(_, _, parent) return widget(parent) end
local owner = widget()
local utility = widget()
utility.Texture, utility.Highlight = widget(utility), widget(utility)
utility.Texture:SetSize(96, 96); utility.Highlight:SetSize(96, 96)
local utilityCount = widgetCount
theme:StyleUtilityButton(utility)
check(widgetCount == utilityCount, "utility adds no ornament ring")
check(utility.Texture.width == 96 and utility.Highlight.height == 96, "original utility sizing retained")
check(utility.Texture.texture:find("utility-cog", 1, true), "utility uses registered cog")
owner.Health = widget(owner)
owner.Health.Backdrop = widget(owner)
theme:StyleHealth(owner, original.Seasoned, false)
check(owner.Health.Backdrop.alpha == 0, "old casing hidden")
check(owner.Health.PaladinCasing.Art.texture:find("health-case",1,true), "new health overlay")
check(owner.Health.PaladinCasing.level > owner.Health.level, "casing above fill")
check(math.abs(owner.Health.PaladinCasing.Art.height - 724*40*97/128/130) < .00001,
    "health casing follows 97/128 inset body height, not full bar rectangle")
check(owner.Health.PaladinCasing.Art.points.TOPLEFT[4] == 306*(40*97/128)/130-40*3/128,
    "health casing opening starts at the actual painted fill top")
local count = widgetCount
theme:StyleHealth(owner, original.Seasoned, true)
check(widgetCount == count, "health updates reuse frames")
check(owner.Health.PaladinCasing.Art.coords[1] == 1, "target casing mirrored")
owner.Health:SetSize(40,36)
theme:StyleHealth(owner, original.Seasoned, true)
check(not owner.Health.PaladinCasing.shown and owner.Health.Backdrop.alpha == 1, "critter uses its original silhouette, not a crushed blade")
owner.Health:SetSize(533,40)
theme:StyleHealth(owner, original.Seasoned, true)
check(owner.Health.PaladinCasing.shown and owner.Health.PaladinCasing.Art.texture:find("health-wide",1,true), "critter-to-boss transition restores wide blade")
owner.Health:SetSize(385,37)
theme:StyleHealth(owner, original.Seasoned, false)
check(owner.Health.PaladinCasing.Art.texture:find("health-portrait",1,true), "portrait layouts use matching 385x37 casing")
theme:StyleHealth(owner, { HealthBarTexture = "hp_lowmid_bar.tga" }, false)
check(owner.Health.PaladinCasing.Art.texture:find("health-lowmid",1,true), "novice and hardened fills have their own painted-height registration")
check(owner.Health.PaladinHealthGeometry[5] == 52/64, "lowmid painted body inset ends at 52/64")
local standalone = widget(owner)
standalone:SetSize(112,11)
standalone.Backdrop, standalone.Shield = widget(standalone), widget(standalone)
theme:StyleCastbar(standalone)
check(standalone.Shield.alpha == 0, "Paladin hides the legacy shield border artifact")
check(math.abs(standalone.PaladinCasing.Art.height-724*11*31/32/133)<.00001, "lion casing follows the native cast fill height")
check(standalone.PaladinEmpty.texture:find("cast_bar",1,true), "empty cast cavity uses the same pointed shape as the fill")
local castCount = widgetCount
theme:StyleCastbar(standalone)
check(widgetCount == castCount, "cast restyling reuses its casing and empty layer")
owner.Health:SetSize(112,11)
theme:StyleHealth(owner, { HealthBarTexture = "cast_bar.tga" }, true)
check(owner.Health.PaladinCasing.Art.texture:find("health-small",1,true), "boss meter has a cast-fill-sized blade casing")
local power = widget(owner)
theme:ApplyCrystalEffect(power, "original-crystal.tga", {0,1,0,1})
local content = power.PaladinLight
check(content.parent.clips, "crystal clips through native frame")
check(content.parent.points.TOP[1] == power:GetStatusBarTexture(), "fill texture drives clipping")
check(content.Strands.mask.texture == "original-crystal.tga", "original crystal silhouette masks strands")
check(not content.Strands.color, "white strands do not inherit a resource tint")
count = widgetCount
theme:ApplyCrystalEffect(power, "alternate-crystal.tga", {.1,.9,.1,.9})
check(widgetCount == count and content.Strands.mask.texture == "alternate-crystal.tga", "mask updates without new frames")
local orb = widget(owner)
check(theme:ApplyOrbEffect(orb) and orb.fillPaths[1]:find("orb-light",1,true), "orb uses theme texture")
check(orb.PaladinLight.parent == orb:GetOverlay(), "orb uses existing native clipping")
check(content.alpha == 1 and orb.PaladinLight.alpha == 1, "holy light defaults to full strength")
check(theme:SetLightStrength(.4) and content.alpha == .4 and orb.PaladinLight.alpha == .4, "light strength applies live to crystal and orb")
theme:SetLightStrength(0)
check(content.shown == false and orb.PaladinLight.shown == false and ns.db.char.paladinLight == 0, "zero strength hides the light")
theme:SetLightStrength(5)
check(theme:GetLightStrength() == 1 and ns.db.char.paladinLight == nil and content.shown, "strength clamps and full strength clears the setting")
theme:ClearCrystalEffect(power); theme:ClearOrbEffect(orb)
check(content.shown == false and orb.PaladinLight.shown == false, "cleared effects hide their light")
theme:SetLightStrength(.5)
check(content.shown == false and orb.PaladinLight.shown == false, "a strength change cannot bring back a cleared effect")
count = widgetCount; theme:ApplyCrystalEffect(power, "original-crystal.tga", {0,1,0,1}); theme:ApplyOrbEffect(orb)
check(widgetCount == count and content.shown and content.alpha == .5 and orb.PaladinLight.shown, "re-applied effects reuse their frames at the saved strength")
theme:SetLightStrength(1)
theme:ClearCrystalEffect(widget(owner)); theme:ClearOrbEffect(widget(owner))
check(true, "clearing an effect that was never drawn is harmless")
owner.Castbar = widget(owner)
owner.Castbar.Backdrop = widget(owner.Castbar)
owner.Castbar:SetSize(92, 24)
owner.Castbar.shown = false
theme:StyleNameplate(owner)
check(not owner.Castbar.shown, "theme never shows idle castbar")
check(not owner.Castbar.PaladinCasing and owner.Castbar.Backdrop.texture:find("plate-case",1,true), "nameplate material uses original background, without a foreground casing")
owner.isPRD = true
theme:StyleNameplate(owner)
check(not owner.Castbar.PaladinCasing, "no duplicate casing over personal health bar")
owner.isPRD = false
theme:StyleNameplate(owner)
check(owner.Castbar.Backdrop.texture:find("plate-case",1,true), "pooled plate material retained")
theme.loadedActive = true
ns.variant = "SaiyaRatt"
combat = true
theme:ProfileChanged()
check(theme.event == "PLAYER_REGEN_ENABLED" and reloads == 2, "profile boundary defers reload in combat")
combat = false
theme:ProfileChanged()
check(reloads == 3 and not theme.event, "profile boundary reloads out of combat")
print("Paladin theme: "..checks.." checks passed (offline only)")

-- Optional source-driven layout export for the offline assembly renderer.
if (arg[2]) then
	local function quote(s) return '"'..s:gsub('\\','\\\\'):gsub('"','\\"'):gsub('\n','\\n'):gsub('\r','\\r')..'"' end
	local function json(v)
		local kind = type(v)
		if (kind == "string") then return quote(v) end
		if (kind == "number" or kind == "boolean") then return tostring(v) end
		if (kind ~= "table" or v.GetObjectType) then return "null" end
		local out = {}
		if (#v > 0) then for i=1,#v do out[#out+1] = json(v[i]) end; return "["..table.concat(out,",").."]" end
		for k,x in pairs(v) do if type(k)=="string" and type(x)~="function" then out[#out+1]=quote(k)..":"..json(x) end end
		return "{"..table.concat(out,",").."}"
	end
	ns.variant = nil
	local result = {}
	for _, enabled in ipairs({ false,true }) do
		ns.db.char.paladinPreview = enabled
		local layouts = {}
		for _,name in ipairs({ "PlayerFrame","PlayerFrameAlternate","TargetFrame","BossFrames","PlayerCastBar","PlayerClassPower","ActionButton","NamePlates","FocusFrame","ToTFrame","PetFrame","PartyFrames","Raid5Frames","RaidFrames","ArenaFrames","MirrorTimers","StatusBars","VehicleExitButton" }) do layouts[name]=ns.GetConfig(name) end
		result[enabled and "paladin" or "original"] = layouts
	end
	local file=assert(io.open(arg[2],"w"));file:write(json(result));file:close()
end
