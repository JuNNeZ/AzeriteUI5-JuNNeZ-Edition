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
load("Core/ThemeEngine.lua")
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
check(not theme:IsActive(), "off until chosen")
check(ns.GetConfig("PlayerFrame") == original, "off returns original table")
theme:OnInitialize()
check(theme.command == "azpaladin", "command registered without Development Mode (public since 5.27.1)")
ns.db.char.paladinPreview = true
check(theme:IsActive(), "choosing it enables the theme without Development Mode")
local casings = 0
for name in pairs(theme.Media) do
	casings = casings + 1
	check(theme:ResolveOwnMedia(name):find("\\Paladin\\"..name..".tga", 1, true), "native filename resolves: "..name)
	local file = io.open(root.."/Assets/Paladin/"..name..".tga", "rb")
	check(file ~= nil, "native casing installed: "..name)
	if (file) then file:close() end
end
check(casings == 34, "native casing, shaped-border and Rounded-window variants covered")
ns.OptionsKit = { WindowBackdrop = {}, WindowCasing = {}, ButtonBackdrop = {}, InsetBackdrop = {},
	Look = { CasingBackdrop = {}, InsetBackdrop = {} } }
theme:OnEnable()
check(ns.OptionsKit.WindowCasing.edgeFile:find("border-tooltip", 1, true), "Classic window receives approved tooltip material")
check(ns.OptionsKit.Look.CasingBackdrop.edgeFile:find("options-casing-round", 1, true), "Rounded window receives native rounded material")
check(ns.OptionsKit.Look.InsetBackdrop.edgeFile:find("options-well-round", 1, true), "Rounded well receives native rounded material")
check(theme:UseIceCrystal(true), "player seasonal/ice preference preserved")
check(ns.GetConfig("PlayerFrameAlternate").PowerBarColors.MANA[1] == original.PowerBarColors.MANA[1], "alternate player keeps native mana")
for name, before in pairs(originalGroups) do
	local after = ns.GetConfig(name)
	local prefix = name == "MirrorTimers" and "MirrorTimer" or "Health"
	check(after[prefix.."BackdropTexture"]:find("cast_back",1,true), name.." simple casing coverage")
	check(after[prefix.."BarTexture"] == before[prefix.."BarTexture"], name.." semantic fill preserved")
	for i,v in ipairs(before[prefix.."BackdropSize"]) do check(after[prefix.."BackdropSize"][i] == v,name.." native casing dimensions") end
end
check(ns.GetConfig("PartyFrames").PortraitBorderTexture:find("party_portrait_border",1,true), "party portrait coverage")
check(ns.GetConfig("StatusBars").RingFrameBackdropTexture:find("minimap-onebar-backdrop",1,true), "status wheel casing coverage")
check(ns.GetConfig("VehicleExitButton").VehicleExitButtonTexture:find("icon_exit_flight",1,true), "vehicle exit art coverage")
check(ns.Private == nil and ns.PlayerClass == "PALADIN", "real finalized namespace exposes class without Private")
for name, before in pairs(compactOriginals) do
	local after = ns.GetConfig(name)
	check(after.HealthBackdropTexture:find("cast_back", 1, true), name.." has new casing")
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
-- The drop-in rebuild preserves every player's native/saved resource palette.
local expected = { default = default, enhanced = enhanced, new = enhanced, classColor = class, class = class }
for _, mode in ipairs({ "default", "enhanced", "new", "classColor", "class" }) do
	local profile = { crystalOrbColorMode = mode }
	local color = resolve({}, profile, "MANA")
	check(color == expected[mode], "the player's "..mode.." resource palette is unchanged")
	check(profile.crystalOrbColorMode == mode, "saved mode is unchanged")
end
check(resolve({}, {}, "MANA") == default, "native mana with no saved mode")
check(resolve({}, {}, "RAGE") == default, "non-mana power retains resolver")
local lightColor = theme:GetLightPowerColor("MANA")
check(lightColor and lightColor[1] == 1 and lightColor[2] == .84 and lightColor[3] == .35,
    "Paladin Light uses the approved warm golden palette")
check(resolve({}, { crystalOrbColorMode = "light" }, "MANA") == lightColor,
    "explicit Light choice colours the crystal gold")
check(resolve({}, { crystalOrbColorMode = "light" }, "RAGE") == default,
    "Light choice keeps non-mana resource colours")
-- Exercise the real orb callback too: it has a distinct Default mana palette.
local orbProfile = { crystalOrbColorMode = "light", useWrathCrystal = true }
local colorModule = { db = { profile = orbProfile } }
local orbDefault = { .3, .4, .9 }
local orbConfig = { PowerOrbColors = { MANA = orbDefault } }
local orbColorChunk = assert(loadstring(assert(source:match("local UpdateManaOrbColor = function.-\nend")).."\nreturn UpdateManaOrbColor"))
setfenv(orbColorChunk, {
    ns = setmetatable({ GetConfig = function() return orbConfig end }, { __index = ns }),
    PlayerFrameMod = colorModule, POWER_TYPE_TOKENS = { [0] = "MANA" },
    POWER_CRYSTAL_TOKEN_ALIASES = {}, ResolvePlayerPowerBaseColor = resolve,
    type = type
})
local updateOrbColor = orbColorChunk()
local colorOrb = { displayType = 0, SetStatusBarColor = function(self, r, g, b) self.color = {r,g,b} end }
updateOrbColor(colorOrb)
check(colorOrb.color[1] == lightColor[1] and colorOrb.color[2] == lightColor[2] and colorOrb.color[3] == lightColor[3],
    "orb and crystal use the identical Light colour")
local savedGetModule = ns.GetModule
ns.GetModule = function(_, name) if name == "PlayerFrame" then return colorModule end end
check(not theme:UseIceCrystal(true) and orbProfile.useWrathCrystal,
    "Light uses neutral crystal without erasing the saved ice preference")
orbProfile.crystalOrbColorMode = "classColor"
check(theme:UseIceCrystal(true), "another colour restores saved ice appearance")
orbProfile.crystalOrbColorMode = "light"
ns.db.char.paladinPreview = false
check(not theme:GetLightPowerColor("MANA") and resolve({}, { crystalOrbColorMode = "light" }, "MANA") == default,
    "stored Light choice is dormant outside the Paladin theme")
updateOrbColor(colorOrb)
check(colorOrb.color[1] == orbDefault[1] and colorOrb.color[2] == orbDefault[2] and colorOrb.color[3] == orbDefault[3],
    "dormant Light restores the orb's own Default mana palette")
check(theme:UseIceCrystal(true), "leaving Paladin restores saved ice appearance")
ns.GetModule = savedGetModule
check(resolve({}, {}, "MANA") == default, "off restores default mana")
check(resolve({}, { crystalOrbColorMode = "enhanced" }, "MANA") == enhanced, "off restores enhanced mana")
check(resolve({}, { crystalOrbColorMode = "classColor" }, "MANA") == class, "off restores class mana")
ns.db.char.paladinPreview = true
local themed = ns.GetConfig("PlayerFrame")
check(themed ~= original, "theme owns a copied layout")
for _, tier in ipairs({ "Novice", "Hardened", "Seasoned" }) do
	check(themed[tier].HealthBarSize[1] == original[tier].HealthBarSize[1], "player health width is native")
end
check(ns.GetConfig("TargetFrame").Seasoned.HealthBarSize[1] == 385, "target width preserved")
check(ns.GetConfig("PlayerFrameAlternate").Seasoned.HealthBarSize[1] == 385, "portrait player width preserved")
check(themed.HealthValueFont == original.HealthValueFont, "native font object identity preserved")
local anchor = { GetObjectType = function() return "Frame" end }
anchor.circular = anchor
ns.RegisterConfig("NativeAnchor", { Position = { "CENTER", anchor } })
check(ns.GetConfig("NativeAnchor").Position[2] == anchor, "native frame anchors are not copied or traversed")
check(themed == ns.GetConfig("PlayerFrame"), "resolved copy reused")
check(themed.PowerOrbColors.MANA[1] == original.PowerOrbColors.MANA[1], "native mana colour retained")
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
check(#points == 5, "five native Holy Power points")
for i, point in ipairs(points) do
	for _, field in ipairs({ "Position", "Size", "BackdropSize" }) do
		for k, value in ipairs(originalPoints[i][field]) do
			check(point[field][k] == value, "Holy Power native geometry "..i.." "..field)
		end
	end
	check(point.Texture == originalPoints[i].Texture and point.PointRotation == originalPoints[i].PointRotation,
		"Holy Power activation glyph and rotation unchanged")
	check(i == 5 and point.BackdropTexture == originalPoints[i].BackdropTexture
		or i < 5 and point.BackdropTexture:find("point_plate", 1, true), "Silver Hand plate; native diamond finisher")
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

-- Every non-colour numeric field in all real layouts must remain identical.
local function compare(a, b, where, seen)
	seen = seen or {}
	if type(a) ~= "table" or a.GetObjectType or seen[a] then return end
	seen[a] = true
	for key, value in pairs(a) do
		local path = where.."."..tostring(key)
		if type(value) == "table" then compare(value, b[key], path, seen)
		elseif type(value) == "number" and not path:find("Color", 1, true) then
			check(b[key] == value, "native numeric layout: "..path)
		end
	end
end
ns.db.char.paladinPreview = false
local nativeLayouts = {}
for _, key in ipairs({ "PlayerFrame", "PlayerFrameAlternate", "TargetFrame", "PlayerCastBar", "PlayerClassPower", "NamePlates",
	"ActionButton", "ExtraActionButton", "PetFrame", "PartyFrames", "Raid5Frames", "RaidFrames", "ArenaFrames", "FocusFrame", "ToTFrame", "MirrorTimers", "Tooltips" }) do
	nativeLayouts[key] = ns.GetConfig(key)
end
ns.db.char.paladinPreview = true
for key, layout in pairs(nativeLayouts) do compare(layout, ns.GetConfig(key), key) end

-- Strict scene graph: resource getters deliberately fail. Clipping must follow
-- native texture anchors without interrogating protected mana or dimensions.
local widgetCount = 0
local function widget(parent)
	widgetCount = widgetCount + 1
	local w = { parent = parent, points = {}, children = {}, shown = true, level = 2, width = 385, height = 40 }
	if parent then parent.children[#parent.children+1] = w end
	function w:SetAllPoints(anchor) self.allPoints = anchor end
	function w:SetScript(key, fn) self.scripts = self.scripts or {}; self.scripts[key] = fn end
	function w:SetPoint(point, ...) self.points[point] = { ... } end
	function w:ClearAllPoints() self.points = {} end
	function w:SetSize(x, y) self.width, self.height = x, y end
	function w:SetHeight(v) self.height=v end
	function w:GetWidth() return self.width end
	function w:GetHeight() return self.height end
	function w:SetFrameLevel(v) self.level = v end
	function w:GetFrameLevel() return self.level end
	function w:GetParent() return self.parent end
	function w:SetParent(v) self.parent = v end
	function w:EnableMouse(v) self.mouse = v end
	function w:SetTexture(value) self.texture = value end
	function w:GetTexture() return self.texture end
	function w:IsShown() return self.shown end
	function w:IsVisible() return self.shown end
	function w:RegisterEvent(event) self.events=self.events or {};self.events[event]=true end
	function w:UnregisterAllEvents() self.events={} end
	function w:Show() self.shown = true end
	function w:Hide() self.shown = false end
	function w:SetTexCoord(...) self.coords = { ... } end
	function w:SetVertexColor(...) self.color = { ... } end
	function w:GetVertexColor() return unpack(self.color or { 1, 1, 1, 1 }) end
	function w:SetColorTexture(...) self.color = { ... } end
	function w:SetAlpha(value) self.alpha = value end
	function w:GetAlpha() return self.alpha or 1 end
	function w:SetBlendMode(value) self.blendMode = value end
	function w:SetShown(value) self.shown = value end
	function w:SetClipsChildren(value) self.clips = value end
	function w:AddMaskTexture(mask) self.mask = mask end
	function w:CreateTexture(_, layer, _, sublevel) local child = widget(self); child.layer, child.sublevel = layer, sublevel; return child end
	function w:CreateMaskTexture() return widget(self) end
	function w:GetStatusBarTexture() self.fill = self.fill or widget(self); return self.fill end
	function w:SetStatusBarTexture(...) self.fillPaths = { ... } end
	function w:GetOverlay() self.clip = self.clip or widget(self); return self.clip end
	function w:GetValue() error("theme read resource value") end
	function w:GetMinMaxValues() error("theme read resource range") end
	function w:CreateAnimationGroup()
		local group = { animations = {} }
		self.animationGroup = group
		function group:CreateAnimation()
			local animation = { SetFromAlpha = function(self, v) self.from = v end,
				SetToAlpha = function(self, v) self.to = v end,
				SetDuration = function() end, SetOrder = function() end }
			self.animations[#self.animations + 1] = animation
			return animation
		end
		function group:SetLooping() end
		function group:Play() end
		return group
	end
	return w
end
env.hooksecurefunc = function(object, method, callback)
	local previous = object[method]
	object[method] = function(self, ...)
		local value = previous(self, ...)
		callback(self, ...)
		return value
	end
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
check(utility.Texture.texture:find("config_button", 1, true), "utility uses registered cog")
local compass = widget()
compass.north = widget(compass)
theme:StyleCompass(compass)
check(compass.north.alpha == nil and compass.PaladinNorth.points.CENTER[1] == compass.north,
	"native compass N and anchor retained")
owner.Health = widget(owner)
owner.Health.Backdrop = widget(owner)
local nativeBackdrop = owner.Health.Backdrop
nativeBackdrop:SetSize(716, 210)
theme:StyleHealth(owner, themed.Seasoned, false)
check(owner.Health.Backdrop == nativeBackdrop and nativeBackdrop.alpha == nil, "native casing remains present")
check(owner.Health.PaladinRails.Art.texture:find("hp_cap_case-over", 1, true), "separate complete foreground rails")
check(owner.Health.PaladinRails.Art.allPoints == nativeBackdrop, "front rails follow actual native backdrop")
check(owner.Health.PaladinOrnaments.Art.texture:find("ornament-ashbringer", 1, true), "separate Ashbringer ornament")
check(owner.Health.PaladinOrnaments.Art.width == nativeBackdrop.width*theme:GetEndcapScale()/1.3,
	"aligned ornament follows actual casing scale")
check(owner.Health.PaladinOrnaments.level > owner.Health.level + 3,
	"relic stays above native healing and absorb prediction frames")
check(theme:GetEndcapScale() == 1.7 and select(2, theme:GetEndcapOffset()) == -17, "maintainer's live Ashbringer defaults")
check(theme:SetEndcapScale(1) and theme:GetEndcapScale() == 1,
	"explicit 100 percent remains distinct from measured default")
theme:ResetEndcapPlacement()
check(theme:GetEndcapScale() == 1.7 and select(2, theme:GetEndcapOffset()) == -17, "reset restores live relic size and offset")
check(owner.Health.PaladinOrnaments.level > owner.Health.PaladinRails.level
	and owner.Health.PaladinOrnaments.Art.layer == "OVERLAY", "endcap covers termination above rails and native fill")
check(not owner.Health.PaladinEmpty, "no substitute health empty surface")
local count = widgetCount
theme:StyleHealth(owner, themed.Seasoned, true)
check(widgetCount == count, "health restyle reuses frames")
check(owner.Health.PaladinRails.Art.coords[1] == 1, "target rails mirrored")
check(owner.Health.PaladinOrnaments.Art.points.TOPLEFT[1] == nativeBackdrop and owner.Health.PaladinOrnaments.Art.coords[1]==1,
	"target relic and casing mirror together")
check(owner.Health.width == 385 and owner.Health.height == 40, "health frame size unchanged")
local threat = widget(owner)
threat:SetVertexColor(.1, .8, .2, .6)
owner.ThreatIndicator = { textures = { Health = threat }, isShown = true }
theme:StyleThreat(owner, true)
check(threat.allPoints == nativeBackdrop and threat.texture:find("hp_cap_case-glow",1,true),
	"health threat uses final casing silhouette at the actual backdrop")
check(threat.coords[1] == 1, "target health threat mirrors with casing")
check(owner.Health.PaladinOrnaments.Threat.parent == threat.parent,
	"endcap halo stays behind the whole casing/fill assembly, avoiding a lit internal seam")
check(owner.Health.PaladinOrnaments.Threat.color[2] == .8, "already-active threat colour synced immediately")
threat:SetVertexColor(.9, .2, .1, .7)
check(owner.Health.PaladinOrnaments.Threat.color[1] == .9, "native colour post-hook forwarded")
threat:SetAlpha(.35)
check(owner.Health.PaladinOrnaments.Threat.alpha == .35, "native threat alpha follows the endcap")
theme:SetEndcapOffset(2,1)
check(owner.Health.PaladinOrnaments.Threat.alpha == .35, "ornament placement cannot reset native threat alpha")
theme:ResetEndcapPlacement()
threat:SetShown(false)
check(not owner.Health.PaladinOrnaments.Threat.shown, "SetShown cannot leave a stale endcap outline")
threat:SetShown(true)
local portraitThreat = widget(owner)
local border = widget(owner)
owner.Portrait = { Border = border }
owner.ThreatIndicator.textures.Portrait = portraitThreat
local targetConfig = ns.GetConfig("TargetFrame")
theme:StyleHealth(owner,targetConfig.Seasoned,true)
theme:StyleThreat(owner,true)
check(portraitThreat.allPoints == border and portraitThreat.texture:find("portrait_frame_hi-glow",1,true),
	"portrait threat follows the actual border rather than old model-centre padding")
theme:StyleHealth(owner,targetConfig.Novice,true)
theme:StyleThreat(owner,true)
check(portraitThreat.texture:find("portrait_frame_lo-glow",1,true), "low portrait uses its own outline")
check(portraitThreat.color == nil, "portrait threat semantic colour is not overwritten")
threat:Hide()
check(not owner.Health.PaladinOrnaments.Threat.shown, "native threat hide forwarded")
threat:Show()
check(owner.Health.PaladinOrnaments.Threat.shown, "native threat show forwarded")
check(theme:SetEndcap("none") and not owner.Health.PaladinOrnaments.shown, "none hides relic and its child threat")
threat:Show()
check(not owner.Health.PaladinOrnaments.Threat.shown, "native threat cannot resurrect a disabled endcap halo")
check(nativeBackdrop.texture:find(owner.Health.PaladinCaseName..".tga",1,true)
    and owner.Health.PaladinRails.Art.texture:find(owner.Health.PaladinCaseName.."-over.tga",1,true)
    and threat.texture:find(owner.Health.PaladinCaseName.."-glow.tga",1,true), "None restores complete bare casing, dip and matching threat")
check(theme:SetEndcap("ashbringer") and owner.Health.PaladinOrnaments.shown, "Ashbringer returns without reload")
check(not nativeBackdrop.texture:find("-capped.tga",1,true)
    and not owner.Health.PaladinRails.Art.texture:find("-capped-over.tga",1,true)
    and not threat.texture:find("-capped-glow.tga",1,true), "enabled relic keeps complete original dip and matching threat")
check(theme:SetEndcap("silverhand") and owner.Health.PaladinOrnaments.Art.texture:find("ornament-silverhand-",1,true),"Silver Hand live choice")
check(theme:SetEndcap("argent") and owner.Health.PaladinOrnaments.Threat.texture:find("ornament-argent-",1,true),"Argent live choice updates halo")
theme:SetEndcap("ashbringer")
owner.Health:SetSize(40,36)
theme:StyleHealth(owner, { HealthBackdropTexture = theme:ResolveOwnMedia("hp_critter_case") }, true)
check(not owner.Health.PaladinOrnaments.shown and not owner.Health.PaladinRails.shown, "critter has no blade ornament or misplaced long rails")
check(not owner.Health.PaladinOrnaments.Threat.shown, "critter transition clears the separate endcap halo")
threat:Show()
check(not owner.Health.PaladinOrnaments.Threat.shown, "compact threat events cannot resurrect the old relic halo")
owner.Health:SetSize(533,40)
theme:StyleHealth(owner, { HealthBackdropTexture = theme:ResolveOwnMedia("hp_boss_case") }, true)
check(owner.Health.PaladinRails.Art.texture:find("hp_boss_case-over", 1, true), "boss casing foreground keeps complete native variant")
owner.Health:SetSize(385,37)
theme:StyleHealth(owner, themed.Seasoned, false)
check(owner.Health.PaladinRails.Art.allPoints == nativeBackdrop, "alternate player casing uses native backdrop rectangle")
local standalone = widget(owner)
standalone:SetSize(112,11)
standalone.Backdrop, standalone.Shield = widget(standalone), widget(standalone)
standalone.Shield:Hide()
theme:StyleCastbar(standalone)
check(standalone.Shield.alpha == nil, "native protected cast shield retained")
check(standalone.width == 112 and standalone.height == 11, "cast meter is native sized")
check(standalone.PaladinRails.Art.allPoints == standalone.Backdrop, "cast foreground follows native backdrop")
check(standalone.PaladinShieldRails.Art.allPoints == standalone.Shield
    and standalone.PaladinShieldRails.Art.texture:find("cast_back_spiked-over",1,true), "protected front uses its own painted spike and Shield rectangle")
check(not standalone.PaladinShieldRails.shown, "ordinary cast starts without protected front")
check(standalone.PaladinCastHead.Art.texture:find("cast-head-libram", 1, true), "standalone libram cast head")
check(standalone.PaladinCastHead.Art.points.CENTER[2] == "LEFT", "libram on cast left only")
check(theme:SetCastEndcap("none") and not standalone.PaladinCastHead.shown,
	"cast endcap can hide independently of health")
check(owner.Health.PaladinOrnaments.shown and standalone.PaladinRails.shown,
	"hiding libram preserves health relic and ordinary cast casing")
combat = true
check(not theme:SetCastEndcap("libram") and not standalone.PaladinCastHead.shown,
	"combat cannot change cast endcap choice")
combat = false
check(theme:SetCastEndcap("libram") and standalone.PaladinCastHead.shown,
	"cast endcap returns without reload")
local castCount = widgetCount
theme:StyleCastbar(standalone)
check(widgetCount == castCount, "cast restyle reuses frames")
standalone.Backdrop:Hide()
standalone.Shield:Show()
check(standalone.PaladinShieldRails.shown, "protected cast shows painted spike front with shield")
check(not standalone.PaladinRails.shown, "protected cast hides ordinary front lip with native backdrop")
standalone.Backdrop:Show()
standalone.Shield:Hide()
check(not standalone.PaladinShieldRails.shown, "ordinary cast clears protected spike front")
check(standalone.PaladinRails.shown, "ordinary front lip returns with backdrop")
standalone.Backdrop:SetShown(false)
standalone.Shield:SetShown(true)
theme:StyleCastbar(standalone)
check(not standalone.PaladinRails.shown, "restyle during protected cast does not resurrect ordinary rails")
check(standalone.PaladinShieldRails.shown, "restyle during protected cast preserves matching spike front")
standalone.Shield:SetShown(false)
check(not standalone.PaladinShieldRails.shown, "SetShown false clears the protected front")
standalone.Backdrop:SetShown(true)
check(theme:SetCastEndcapScale(1.5) and standalone.PaladinCastHead.Art.width == 72, "live cast size changes ornament only")
check(standalone.width == 112, "live cast ornament never scales meter")

-- Exercise the actual player's callback as well as direct widget transitions.
-- Duration/net-stat stubs keep the unrelated latency-zone work out of this test.
do
    local file = assert(io.open(root.."/Components/UnitFrames/Units/PlayerCastBar.lua","r"))
    local source = file:read("*a"); file:close()
    local first = assert(source:find("local Cast_Update = function",1,true))
    local last = assert(source:find("-- Frame Script Handlers",first,true))
    local chunk = assert(loadstring("local Colors, Cast_GetMaxDuration, GetNetStats = ...\n"
        ..source:sub(first,last-1).."\nreturn Cast_Update"))
    setfenv(chunk,env)
    local update = chunk(ns.Colors,function() return 1 end,function() return 0,0,0,0 end)
    standalone.SafeZone = widget(standalone)
    standalone.SetStatusBarColor = function(self,...) self.castColor = {...} end
    standalone.notInterruptible = false; update(standalone,"player")
    check(standalone.PaladinRails.shown and not standalone.Shield.shown and not standalone.PaladinShieldRails.shown,
        "real ordinary cast callback clears protected spike and its old shadow")
    standalone.notInterruptible = true; update(standalone,"player")
    check(not standalone.PaladinRails.shown and standalone.Shield.shown and standalone.PaladinShieldRails.shown,
        "real protected cast callback switches backdrop and matching spike front")
    theme:SetCastEndcap("none")
    check(standalone.PaladinShieldRails.shown and not standalone.PaladinCastHead.shown,
        "protected spike remains when optional libram is disabled")
    theme:SetCastEndcap("libram")
    standalone.notInterruptible = false; update(standalone,"player")
    check(standalone.PaladinRails.shown and not standalone.PaladinShieldRails.shown,
        "real callback restores ordinary rails after a protected cast")
end

theme:ResetCastEndcapPlacement()
owner.Health:SetSize(112,11)
theme:StyleHealth(owner, { HealthBarTexture = "cast_bar.tga", HealthBackdropTexture = theme:ResolveOwnMedia("cast_back") }, true)
check(not owner.Health.PaladinOrnaments.shown, "compact/group meter has no health ornament")
local power = widget(owner)
power.Case = widget(power)
power.Case:SetSize(198,98)
local casePoint = { "BOTTOM",7,-23 }
power.Case:SetPoint(unpack(casePoint))
local beforeHolder = widgetCount
theme:StyleCrystal(power,theme:ResolveOwnMedia("pw_crystal_case"),false)
check(not power.PaladinCradleBack and widgetCount == beforeHolder,
	"complete concept holder needs no duplicate backing or extra frames")
check(power.Case.width == 198 and power.Case.height == 98,
	"concept holder follows native casing size")
check(power.Case.texture:find("pw_crystal_case.tga",1,true),"complete concept holder replaces raised case")
theme:StyleCrystal(power,theme:ResolveOwnMedia("pw_crystal_case_low"),false)
check(power.Case.texture:find("pw_crystal_case_low.tga",1,true),"low tier selects its uniformly fitted holder")
ns.db.char.paladinCrystalCase, ns.db.char.paladinCrystalCaseRevision = 5, nil
theme:StyleCrystal(power,theme:ResolveOwnMedia("pw_crystal_case_low"),false)
check(power.Case.texture:find("pw_crystal_case_low.tga",1,true), "obsolete saved candidate cannot select retired casing")
check(theme.CycleCrystalCase == nil and theme.SetCrystalCase == nil, "retired cycling API removed")
local beforeMage = power.Case.texture
theme:StyleCrystal(power,theme:ResolveOwnMedia("pw_crystal_case"),true)
check(power.Case.texture == beforeMage,"Mage Lite+ casing is not replaced")
ns.db.char.paladinPreview = false
theme:StyleCrystal(power,theme:ResolveOwnMedia("pw_crystal_case"),false)
check(power.Case.texture == beforeMage,"inactive Paladin does not replace the casing")
ns.db.char.paladinPreview = true
load("Core/ThemeEffects.lua")
ns.ThemeEffects:StyleCrystal(power,"original-crystal.tga",{0,1,0,1},theme:ResolveOwnMedia("pw_crystal_case"),false)
check(power.Case.parent == power.ThemeCapFrame and power.ThemeCapFrame.level > power.level,
	"real effects path lifts complete concept holder above native fill")
check(power.Case.points.BOTTOM[1] == casePoint[2] and power.Case.points.BOTTOM[2] == casePoint[3],
	"case anchors survive layering")
theme:ApplyCrystalEffect(power, "original-crystal.tga", {0,1,0,1})
local content = power.PaladinLight
check(content.parent.clips, "crystal clips through native frame")
check(content.parent.points.TOP[1] == power:GetStatusBarTexture(), "fill texture drives clipping")
check(content.Strands.mask.texture == "original-crystal.tga", "original crystal silhouette masks strands")
check(not content.Strands.color, "facet light does not inherit a second resource tint")
check(content.Strands.texture == "original-crystal.tga", "light uses faceted material instead of curved ribbons")
check(content.Strands.animationGroup.animations[1].from == .04
    and content.Strands.animationGroup.animations[1].to == .10, "crystal pulse preserves facet contrast")
count = widgetCount
theme:ApplyCrystalEffect(power, "alternate-crystal.tga", {.1,.9,.1,.9})
check(widgetCount == count and content.Strands.mask.texture == "alternate-crystal.tga", "mask updates without new frames")
check(content.Strands.texture == "alternate-crystal.tga", "facet material follows native and ice swaps")
check(content.Strands.coords[1] == 0 and content.Strands.coords[2] == 1
    and content.Strands.mask.coords[1] == 0 and content.Strands.mask.coords[2] == 1,
    "legacy crop cannot enlarge the light or misalign native facets")
local orb = widget(owner)
check(theme:ApplyOrbEffect(orb) and orb.fillPaths[1]:find("orb-light",1,true), "orb uses theme texture")
check(orb.PaladinLight.parent == orb:GetOverlay(), "orb uses existing native clipping")
local orbContent = orb.PaladinLight
do
	-- Real Paladin drawing + real slosh dispatch: keep the single light player
	-- and all six sphere sprites while the troughs cover its upper edge.
	load("Core/MoonwellSlosh.lua")
	orb.displayType=0
	orb:SetSize(103,103)
	function orb:GetStatusBarColor() return 1,.84,.35 end
	function orb:SetStatusBarColor(...) self.color={...} end
	local glassFrame=widget(orb);glassFrame:SetFrameLevel(orb:GetFrameLevel()+4)
	orb.Glass=widget(glassFrame)
	local priorTime=orbContent.Time
	check(ns.ThemeEffects:StyleOrb(orb,true) and orb.fillPaths[1]:find("orb-light",1,true),
		"Flowing mana preserves actual Paladin fill")
	local slosh=orb.MoonwellSlosh
	check(orb.PaladinLight==orbContent and orbContent.shown and #orbContent.Spheres==6,
		"Flowing mana retains one live Paladin player and its six spheres")
	check(orbContent.Time==priorTime and orbContent.level<slosh.level and slosh.level<glassFrame.level,
		"Paladin paint below slosh troughs, native glass above, phase retained")
	local sphereX=orbContent.Spheres[1].points.CENTER[3]
	orbContent.scripts.OnUpdate(orbContent,.5);slosh.scripts.OnUpdate(slosh,.5)
	check(orbContent.Time~=priorTime and orbContent.Spheres[1].points.CENTER[3]~=sphereX and slosh.Time>0,
		"actual Paladin waves and spheres keep moving with slosh")
	local allocated=widgetCount
	ns.ThemeEffects:StyleOrb(orb,false);ns.ThemeEffects:StyleOrb(orb,true)
	check(widgetCount==allocated and orb.PaladinLight==orbContent,
		"flow toggle reuses Paladin and slosh without per-column light copies")
	ns.ThemeEffects:StyleOrb(orb,false)
	check(not slosh.Enabled and orbContent.shown and orb.fillPaths[1]:find("orb-light",1,true),
		"flow off removes only surface deformation, preserves Paladin paint")
end
check(content.Flow.texture:find("holy-energy.tga", 1, true)
    and content.Flow.texture == orbContent.Flow.texture
    and content.FlowNext.texture == content.Flow.texture, "crystal and orb share one permanently bound sheet")
check(content.Flow.mask == content.FlowMask and content.FlowNext.mask == content.FlowMask
    and content.FlowMask.texture == "alternate-crystal.tga", "both flow samples follow native/ice crystal silhouette")
check(orbContent.FlowMask.texture:find("Assets\\orb2.tga", 1, true)
    and orbContent.Flow.mask == orbContent.FlowMask and orbContent.FlowNext.mask == orbContent.FlowMask,
    "orb flow has the shared circular mask inside its fill clip")
check(content.Flow.blendMode == "ADD" and orbContent.Flow.blendMode == "ADD", "black atlas adds golden light")
check(content.mouse == false and orbContent.mouse == false, "effect children never capture mouse input")
local update = content.scripts.OnUpdate
check(type(update) == "function" and update == orbContent.scripts.OnUpdate, "both resources use the same time-only player")
for i = 0, 63 do
    content.Time, content.Index = i/2, nil
    update(content, 0)
    local uv, nextUV = content.Flow.coords, content.FlowNext.coords
    check(uv[1] == ((i%8)*128+.5)/1024 and uv[3] == (math.floor(i/8)*128+.5)/1024,
        "atlas cell "..i.." row/column and half-texel inset")
    check(nextUV[1] >= 0 and nextUV[2] <= 1 and nextUV[3] >= 0 and nextUV[4] <= 1,
        "following sample remains inside sheet at cell "..i)
end
content.Time, content.Index = 63/2, nil
update(content, 1/4)
check(content.Index == 63 and content.FlowNext.coords[1] == .5/1024,
    "last frame crossfades directly to first frame")
check(math.abs(content.Flow.alpha-.325) < 1e-9 and math.abs(content.FlowNext.alpha-.325) < 1e-9,
    "crossfade conserves brightness at midpoint")
update(content, 1/4)
check(content.Time == 0 and content.Index == 0, "loop boundary returns to first cell without swapping files")
check(#content.Spheres == 6 and #orbContent.Spheres == 6, "both resources have six independent light spheres")
for _, light in ipairs({ content, orbContent }) do
    for _, sphere in ipairs(light.Spheres) do
        check(sphere.mask == light.FlowMask and sphere.sublevel > light.Flow.sublevel,
            "sphere foreground shares silhouette and draws above waves")
        check(sphere.texture:find("holy-sphere.tga", 1, true) and sphere.blendMode == "ADD",
            "separate sphere sprite has additive emission")
    end
end
local sphere = content.Spheres[1]
local oldX, oldAlpha = sphere.points.CENTER[3], sphere.alpha
local sphereTime = content.SphereTime
update(content, 1)
check(content.Time == 1 and content.Index == 2, "waves play at a slow 32-second loop")
check(sphere.points.CENTER[3] ~= oldX and sphere.alpha ~= oldAlpha,
    "foreground spheres drift and pulse independently")
content.Time = 31.75
update(content, .25)
check(content.Time == 0 and content.SphereTime == (sphereTime+1.25)%48,
    "wave wrap does not reset sphere motion")
local smoothX, smoothY = sphere.points.CENTER[3], sphere.points.CENTER[4]
update(content, 1/60)
check(math.abs(sphere.points.CENTER[3]-smoothX) < 2 and math.abs(sphere.points.CENTER[4]-smoothY) < 2,
    "sphere motion stays continuous across the wave loop")
local startX, startY, startAlpha = sphere.points.CENTER[3], sphere.points.CENTER[4], sphere.alpha
update(content, 48)
check(math.abs(sphere.points.CENTER[3]-startX) < 1e-8
    and math.abs(sphere.points.CENTER[4]-startY) < 1e-8 and math.abs(sphere.alpha-startAlpha) < 1e-8,
    "sphere paths and pulses have a continuous 48-second period")
update(content, .3)
local phaseBefore = content.Time
local spherePhaseBefore = content.SphereTime
count = widgetCount
theme:ApplyCrystalEffect(power, "original-crystal.tga", {0,1,0,1}); theme:ApplyOrbEffect(orb)
check(content.Time == phaseBefore and widgetCount == count, "resource restyle preserves animation phase and allocates nothing")
check(content.SphereTime == spherePhaseBefore, "resource restyle retains independent sphere phase")
check(content.FlowMask.texture == "original-crystal.tga", "flow mask refreshes on live crystal material change")
check(content.alpha == 1 and orb.PaladinLight.alpha == 1, "holy light defaults to full strength")
check(theme:SetLightStrength(.4) and content.alpha == .4 and orb.PaladinLight.alpha == .4, "light strength applies live to crystal and orb")
theme:SetLightStrength(0)
check(content.shown == false and orb.PaladinLight.shown == false and ns.db.char.paladinLight == 0, "zero strength hides the light")
check(not content.scripts.OnUpdate and not orbContent.scripts.OnUpdate, "zero strength stops both animation callbacks")
theme:SetLightStrength(5)
check(theme:GetLightStrength() == 1 and ns.db.char.paladinLight == nil and content.shown, "strength clamps and full strength clears the setting")
theme:ClearCrystalEffect(power); theme:ClearOrbEffect(orb)
check(content.shown == false and orb.PaladinLight.shown == false, "cleared effects hide their light")
check(not content.scripts.OnUpdate and not orbContent.scripts.OnUpdate, "effect switching stops both animation callbacks")
theme:SetLightStrength(.5)
check(content.shown == false and orb.PaladinLight.shown == false, "a strength change cannot bring back a cleared effect")
count = widgetCount; theme:ApplyCrystalEffect(power, "original-crystal.tga", {0,1,0,1}); theme:ApplyOrbEffect(orb)
check(widgetCount == count and content.shown and content.alpha == .5 and orb.PaladinLight.shown, "re-applied effects reuse their frames at the saved strength")
check(content.scripts.OnUpdate == update and orbContent.scripts.OnUpdate == update
    and content.Time == phaseBefore, "re-enabling resumes shared playback at retained phase")
check(content.SphereTime == spherePhaseBefore, "re-enabling preserves the foreground sphere phase")
theme:SetLightStrength(1)
theme:ClearCrystalEffect(widget(owner)); theme:ClearOrbEffect(widget(owner))
check(true, "clearing an effect that was never drawn is harmless")
owner.Castbar = widget(owner)
owner.Castbar.Backdrop = widget(owner.Castbar)
owner.Castbar:SetSize(92, 24)
owner.Castbar.shown = false
theme:StyleNameplate(owner)
check(not owner.Castbar.shown, "theme never shows idle castbar")
check(not owner.Castbar.PaladinCasing and owner.Castbar.Backdrop.texture:find("nameplate_backdrop",1,true), "nameplate material uses original background, without a foreground casing")
owner.isPRD = true
theme:StyleNameplate(owner)
check(not owner.Castbar.PaladinCasing, "no duplicate casing over personal health bar")
owner.isPRD = false
theme:StyleNameplate(owner)
check(owner.Castbar.Backdrop.texture:find("nameplate_backdrop",1,true), "pooled plate material retained")
theme.loadedActive = true
ns.variant = "SaiyaRatt"
combat = true
theme:ProfileChanged()
check(theme.event == "PLAYER_REGEN_ENABLED" and reloads == 2, "profile boundary defers reload in combat")
combat = false
theme:ProfileChanged()
check(reloads == 3 and not theme.event, "profile boundary reloads out of combat")
-- Execute the real boss style with the real stock and Paladin layouts.
-- Native geometry is not emulated here; this catches initialization overriding
-- LEFT before the shaped prediction renderer reads GetReverseFill().
do
    local savedNewModule, savedOUF, savedUnitFrame = ns.NewModule, ns.oUF, ns.UnitFrame
    local savedPrototype = ns.MovableModulePrototype
    local savedFillCoords = ns.API.GetReversedHorizontalFillTexCoords
    local bossModule, bossStyle
    ns.NewModule = function() bossModule = {}; return bossModule end
    ns.MovableModulePrototype = { defaults = {} }
    ns.API.GetReversedHorizontalFillTexCoords = function() return 1, 0, 0, 1 end
    ns.oUF = { RegisterStyle = function(_, _, fn) bossStyle = fn end, SetActiveStyle = function() end }
    local function bossWidget(parent)
        local w = widget(parent)
        for _, method in ipairs({ "SetHitRectInsets", "SetFontObject", "SetTextColor", "SetJustifyH",
            "SetJustifyV", "Tag", "RegisterEvent", "SetSparkMap", "SetSparkTexture", "SetForceNative",
            "SetFlippedHorizontally", "SetStatusBarColor" }) do w[method] = function() end end
        function w:SetOrientation(value)
            self.orientation = value
            if value == "LEFT" or value == "RIGHT" then self.reverse = value == "LEFT" end
        end
        function w:SetReverseFill(value) self.reverse = value end
        function w:GetReverseFill() return self.reverse or false end
        function w:DisableSmoothing(disabled) self.smoothingDisabled = disabled end
        function w:CreateBar(_, parent) return bossWidget(parent or self) end
        function w:CreateFontString() return bossWidget(self) end
        return w
    end
    env.CreateFrame = function(_, _, parent) return bossWidget(parent) end
    env.MAX_BOSS_FRAMES = 1
    ns.UnitFrame = { Spawn = function(unit)
        local frame = bossWidget(); bossStyle(frame, unit); return frame
    end }
    load("Components/UnitFrames/Units/Boss.lua")
    for _, enabled in ipairs({ false, true }) do
        ns.db.char.paladinPreview = enabled
        bossModule.frame = nil -- CreateUnitFrames builds once per module
        bossModule:CreateUnitFrames()
        local frame = bossModule.frame.units[1]
        check(frame.Health:GetReverseFill(), "boss health fills from right on "..tostring(enabled))
        check(frame.Health.Preview:GetReverseFill(), "boss preview follows health on "..tostring(enabled))
        check(frame.Castbar:GetReverseFill(), "boss cast overlay matches health on "..tostring(enabled))
        check(not frame.Health.smoothingDisabled and frame.Health.Preview.smoothingDisabled,
            "boss health still eases and hidden preview stays immediate")
    end
    ns.NewModule, ns.oUF, ns.UnitFrame = savedNewModule, savedOUF, savedUnitFrame
    ns.MovableModulePrototype = savedPrototype
    ns.API.GetReversedHorizontalFillTexCoords = savedFillCoords
end
-- Click the real Themes page execute option, including changing name and gates.
do
    ns.variant = nil
    ns.db.char.paladinPreview = true
    ns.db.char.paladinCrystalCase = 1
    local generator
    local options = { AddGroup = function(_, _, fn) generator = fn end }
    local savedModule, savedStub = ns.GetModule, env.LibStub
    ns.GetModule = function(_, name) if name == "Options" then return options end end
    env.LibStub = function() return { GetLocale = function()
        return setmetatable({}, { __index = function(_, key) return key end })
    end } end
    load("Options/OptionsPages/Themes.lua")
    local page = generator()
    check(page.args.paladin.args.crystalCase == nil, "obsolete crystal cycle button removed")
    local castChoice = page.args.paladin.args.castEndcap
    check(not castChoice.hidden() and castChoice.values.none, "real page exposes cast none choice")
    castChoice.set(nil, "none")
    check(castChoice.get() == "none" and not standalone.PaladinCastHead.shown,
        "real cast dropdown hides tracked libram")
    castChoice.set(nil, "libram")
    check(standalone.PaladinCastHead.shown, "real cast dropdown restores tracked libram")
    ns.db.char.paladinPreview = false
    -- Public Lite+: choose through the real option callbacks, then draw the
    -- real Paladin module on a stock resource. No Development Mode or theme.
    ns.db.global.enableDevelopmentMode = false
    local crystalOption, orbOption = page.args.effects.args.crystal, page.args.effects.args.orb
    check(crystalOption.values().paladin and orbOption.values().paladin,
        "both Lite+ lists offer approved Light without Development Mode")
    check(page.args.theme.values().paladin, "the full Paladin theme is offered without Development Mode")
    local beforeLite = reloads
    page.args.litePlus.set(nil, true)
    crystalOption.set(nil, "paladin"); orbOption.set(nil, "paladin")
    check(not page.args.effects.hidden() and not page.args.paladin.hidden(),
        "public Lite+ shows effects and Holy light strength")
    check(castChoice.hidden() and page.args.paladin.args.endcap.hidden(),
        "Lite+ does not expose another theme's casing or ornament controls")
    local litePower, liteOrb = widget(owner), widget(owner)
    litePower.Case, liteOrb.Case = widget(litePower), widget(liteOrb)
    litePower.Case:SetTexture("stock-crystal-case.tga")
    liteOrb.Case:SetTexture("stock-orb-case.tga")
    local function styleLite()
        ns.ThemeEffects:StyleCrystal(litePower, "stock-crystal-fill.tga", {0,1,0,1}, "stock-crystal-case.tga")
        return ns.ThemeEffects:StyleOrb(liteOrb)
    end
    check(styleLite() and litePower.PaladinLight.shown and liteOrb.PaladinLight.shown,
        "real public Lite+ renders Light in crystal and orb")
    check(#litePower.PaladinLight.Spheres == 6 and #liteOrb.PaladinLight.Spheres == 6,
        "public Lite+ contains both waves and six foreground spheres")
    check(litePower.Case.texture == "stock-crystal-case.tga" and liteOrb.Case.texture == "stock-orb-case.tga",
        "Lite+ preserves the selected theme's casings")
    local strengthOption = page.args.paladin.args.light
    strengthOption.set(nil, .35)
    check(litePower.PaladinLight.alpha == .35 and liteOrb.PaladinLight.alpha == .35,
        "real Lite+ light control scales both resources")
    crystalOption.set(nil, "none"); orbOption.set(nil, "none")
    styleLite()
    check(not litePower.PaladinLight.shown and not liteOrb.PaladinLight.shown
        and not litePower.PaladinLight.scripts.OnUpdate and not liteOrb.PaladinLight.scripts.OnUpdate,
        "Lite+ none clears waves and sphere callbacks on both resources")
    crystalOption.set(nil, "mage"); orbOption.set(nil, "hunter"); styleLite()
    check(not litePower.PaladinLight.shown and not liteOrb.PaladinLight.shown,
        "other Lite+ effects keep Paladin Light cleared")
    crystalOption.set(nil, "paladin"); orbOption.set(nil, "paladin"); styleLite()
    check(litePower.PaladinLight.shown and liteOrb.PaladinLight.shown,
        "public Light resumes after switching back from other effects")
    page.args.litePlus.set(nil, false); styleLite()
    check(not litePower.PaladinLight.shown and not liteOrb.PaladinLight.shown,
        "Lite+ off restores stock effects and clears both Light layers")
    check(reloads == beforeLite, "public Lite+ and strength changes never reload")
    ns.db.char.themeLitePlus, ns.db.char.themeCrystalEffect, ns.db.char.themeOrbEffect = nil, nil, nil
    theme:SetLightStrength(1)
    ns.db.global.enableDevelopmentMode = true
    ns.db.char.paladinPreview = true
    ns.GetModule, env.LibStub = savedModule, savedStub
end
theme:SetEndcap("silverhand"); theme:ResetEndcapPlacement()
check(theme:GetEndcapScale()==1.65 and theme:GetEndcapOffset()==0 and select(2,theme:GetEndcapOffset())==-17,"SavedVariables Silver Hand defaults")
theme:SetEndcap("argent"); theme:ResetEndcapPlacement()
check(theme:GetEndcapScale()==1.3 and select(2,theme:GetEndcapOffset())==0,"unmeasured Argent defaults retained")
-- The percentage clears the painted relic at its live default size (1.7), both directions.
for _,flip in ipairs({false,true}) do
	local side=flip and "LEFT" or "RIGHT"
	local textOwner=widget();textOwner.width=flip and 550 or 560
	local textBar=widget(textOwner);textOwner.Health=textBar;textBar.Backdrop=widget(textOwner);textBar.Backdrop:SetSize(716,188)
	textBar.Percent=widget(textBar);textBar.Percent.LayoutPoint={side,flip and 27 or -27,4}
	local textDB={HealthBackdropTexture=theme:ResolveOwnMedia("hp_cap_case"),HealthBarTexture="hp_cap_bar.tga",
		HealthBarPosition=flip and {"TOPRIGHT",-140,-66} or {"BOTTOMLEFT",148,27},
		HealthBackdropPosition=flip and {"TOPRIGHT",23.5,8.5} or {"BOTTOMLEFT",-17,-48}}
	theme:SetEndcap("ashbringer");theme:ResetEndcapPlacement();theme:StyleHealth(textOwner,textDB,flip)
	local p=textBar.Percent.points[side]
	local dip=757.5/1024
	local frac=dip+1.7/1.3*(711/1024-dip)
	local capEdge=(flip and -142.5 or -17)+(flip and 1-frac or frac)*716
	check(p and p[1]==textBar and p[4]==4,"Paladin percent keeps its anchor frame and baseline")
	check(math.abs(math.abs((flip and 25 or 148+385)+p[3]-capEdge)-8)<1e-8,"Paladin percent sits eight units clear of the relic")
	theme:SetEndcap("none")
	check(textBar.Percent.points[side][3]==(flip and 27 or -27),"Paladin None restores the layout percent position")
	theme:SetEndcap("ashbringer");textDB.HealthBarTexture="cast_bar.tga";theme:StyleHealth(textOwner,textDB,flip)
	check(textBar.Percent.points[side][3]==(flip and 27 or -27),"Paladin compact bar restores the layout percent position")
end
theme:SetEndcap("ashbringer");theme:ResetEndcapPlacement()
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
