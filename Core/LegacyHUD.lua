-- Compact GoldpawUI / AzeriteUI 3.x HUD. This is an explicitly selected
-- alternative layout, not a drop-in class skin. Selection is per character;
-- its module namespaces keep the main layout's saved settings untouched.
local Addon, ns = ...
local HUD = ns:NewModule("LegacyHUD", "AceConsole-3.0", "LibMoreEvents-1.0")
ns.LegacyHUD = HUD
local baseDefaults, cache = {}, {}
local Reload = function()
	if (C_UI and C_UI.Reload) then C_UI.Reload() elseif (ReloadUI) then ReloadUI() end
end
local WHITE = [[Interface\Buttons\WHITE8X8]]
local media = function(name) return "Interface\\AddOns\\"..Addon.."\\Assets\\Legacy\\"..name..".tga" end

-- Coordinates and apertures from schematic-unitframes-legacy.lua, 3.2.569-RC.
local units = {
	PlayerFrame = { 316, 86, 300, 58, 12 },
	TargetFrame = { 316, 86, 300, 58, 12 },
	PetFrame = { 158, 51, 142, 27, 8 },
	ToTFrame = { 158, 51, 142, 27, 8 },
	FocusFrame = { 158, 51, 142, 27, 8 },
	PartyFrames = { 198, 55, 182, 31, 8 },
	BossFrames = { 198, 55, 182, 31, 8 },
	ArenaFrames = { 198, 55, 182, 31, 8 },
	Raid5Frames = { 198, 55, 182, 31, 8 },
	RaidFrames = { 76, 46, 60, 24, 6 }
}
local positions = {
	PlayerFrame = { "BOTTOMRIGHT", -210, 250 },
	TargetFrame = { "BOTTOMLEFT", 210, 250 },
	PetFrame = { "BOTTOMRIGHT", -210, 195 },
	ToTFrame = { "BOTTOMLEFT", 210, 195 },
	FocusFrame = { "BOTTOMRIGHT", -368, 195 },
	PlayerCastBarFrame = { "BOTTOM", 0, 230 },
	PlayerClassPowerFrame = { "BOTTOM", 0, 274 },
	PartyFrames = { "TOPLEFT", 56, -64 },
	RaidFrame5 = { "TOPLEFT", 56, -64 },
	RaidFrame25 = { "TOPLEFT", 56, -64 },
	RaidFrame40 = { "TOPLEFT", 56, -64 },
	BossFrames = { "TOPRIGHT", -56, -390 },
	ArenaFrames = { "TOPRIGHT", -56, -390 },
	PetBar = { "BOTTOM", 0, 116 },
	StanceBar = { "BOTTOM", 0, 154 },
	-- From the 3.x Legacy layout variations, measured from the screen corner
	-- (corner = true). The minimap sits 16px inside its anchor, so its map edge
	-- lands at the original (-60, -70); info text and widgets centre under it.
	Minimap = { "TOPRIGHT", -44, -54, corner = true },
	-- The modern buff row would sit under the map; it grows left from beside it.
	Auras = { "TOPRIGHT", -300, -40, corner = true },
	Info = { "TOPRIGHT", -29, -304, corner = true },
	UIWidgetBelowMinimap = { "TOPRIGHT", -95, -350, corner = true },
	Tooltips = { "BOTTOMRIGHT", -54, 66, corner = true },
	-- 3.x placed these by their centre; converted with their 94x75 / 128x128 anchors.
	Durability = { "BOTTOMRIGHT", -313, 152.5, corner = true },
	VehicleSeat = { "BOTTOMRIGHT", -66, 16, corner = true }
}

HUD.IsActive = function(self)
	if (not ns.db or not ns.db.char or ns.db.char.legacyHUD ~= true) then return false end
	local variant = ns.GetActiveConfigVariant and ns:GetActiveConfigVariant()
	return not variant or variant == ""
end

local function Copy(value, seen)
	if (type(value) ~= "table" or value.GetObjectType or type(value[0]) == "userdata") then return value end
	seen = seen or {}; if (seen[value]) then return seen[value] end
	local result = {}; seen[value] = result
	for k, v in pairs(value) do result[k] = Copy(v, seen) end
	return result
end

local function Position(point, mapScale)
	local scale = ns.API.GetEffectiveScale() * (mapScale or 1)
	local anchor, x, y = unpack(point)
	-- Old UICenter is the bottom-centre of the screen. The movable manager
	-- stores coordinates relative to the same point on UIParent instead.
	if (point.corner) then x = x * scale
	elseif (anchor == "BOTTOMRIGHT") then x = -UIParent:GetWidth() / 2 + x * scale
	elseif (anchor == "BOTTOMLEFT") then x = UIParent:GetWidth() / 2 + x * scale
	else x = x * scale end
	return { anchor, x, y * scale, scale = scale }
end

--- Alternative defaults, copied so GenerateDefaults never modifies Azerite.
HUD.GetDefaults = function(self, name, original)
	if (not self:IsActive() or (not positions[name] and name ~= "ActionBars")) then return original end
	baseDefaults[name] = original
	local defaults = Copy(original)
	local profile = defaults.profile
	if (positions[name]) then
		-- The minimap module stores its position in map scale (1 on modern clients).
		local minimap = name == "Minimap" and ns.GetModule and ns:GetModule("Minimap", true)
		profile.savedPosition = Position(positions[name], minimap and minimap.GetScale and minimap:GetScale() or nil)
	end
	if (name == "PetBar" or name == "StanceBar") then
		profile.layout, profile.padding, profile.breakpadding, profile.breakpoint = "grid", -2, -2, 12
	end
	if (name == "PlayerFrame") then
		profile.useClassColor = true
		profile.powerBarBaseOffsetX, profile.powerBarBaseOffsetY = 0, 0
		profile.powerOrbMode = "legacyCrystal"
		profile.debuffsSavedPosition = Position({ "BOTTOMRIGHT", -210, 340 })
		profile.secondaryManaSavedPosition = Position({ "BOTTOMRIGHT", -210, 235 })
	elseif (name == "PartyFrames" or name == "RaidFrame5") then
		profile.point, profile.columnAnchorPoint = "TOP", "LEFT"
		profile.xOffset, profile.yOffset, profile.columnSpacing = 0, -58, 4
	elseif (name == "RaidFrame25" or name == "RaidFrame40") then
		profile.point, profile.columnAnchorPoint = "TOP", "LEFT"
		profile.xOffset, profile.yOffset, profile.columnSpacing = 0, -4, 4
	elseif (name == "ActionBars") then
		for id, bar in ipairs(profile.bars) do
			bar.layout, bar.padding, bar.breakpadding = "grid", -2, -2
			bar.growth, bar.growthHorizontal, bar.growthVertical = "horizontal", "RIGHT", "UP"
			bar.breakpoint = id <= 2 and 12 or 4
			bar.enableBarFading = false
			bar.enabled = id == 1
			-- Bars 5-8 are off by default; they get their own spots so enabling
			-- them does not pile them on top of bar 1.
			local x, y = 2, 25
			if (id == 2) then y = 77
			elseif (id == 3) then x = 430
			elseif (id == 4) then x = -430
			elseif (id == 5) then x, y = -430, 77
			elseif (id == 6) then x, y = 430, 77
			elseif (id == 7) then x, y = -430, 129
			elseif (id == 8) then x, y = 430, 129 end
			bar.savedPosition = Position({ "BOTTOM", x, y })
		end
	end
	return defaults
end

--- Registers an isolated profile namespace; gameplay choices seed it once.
HUD.RegisterNamespace = function(self, name, defaults)
	if (not self:IsActive() or not baseDefaults[name]) then return ns.db:RegisterNamespace(name, defaults) end
	local original = ns.db:GetNamespace(name, true) or ns.db:RegisterNamespace(name, baseDefaults[name])
	local db = ns.db:RegisterNamespace("LegacyHUD_"..name, defaults)
	local Seed = function()
		if (db.profile.legacyHUDSchema == 1) then return end
		-- A namespace that was never saved has no profiles table yet.
		local profiles = original.sv and original.sv.profiles
		local saved = profiles and profiles[ns.db:GetCurrentProfile()]
		local copy = Copy(saved or {})
		-- Layout values belong exclusively to Legacy's defaults. Gameplay
		-- options (aura filters, text choices, visibility) carry over once.
		for key, value in pairs(copy) do
			if (type(key) == "string" and key ~= "savedPosition" and key ~= "bars" and not key:find("SavedPosition")
				and not key:find("Offset") and not key:find("Scale") and not key:find("AnchorFrame")
				and key ~= "point" and key ~= "columnAnchorPoint" and key ~= "columnSpacing"
				and key ~= "xOffset" and key ~= "yOffset" and key ~= "powerOrbMode"
				and key ~= "layout" and key ~= "padding" and key ~= "breakpadding" and key ~= "breakpoint") then
				db.profile[key] = value
			end
		end
		db.profile.legacyHUDSchema = 1
	end
	Seed()
	db.RegisterCallback(self, "OnProfileChanged", Seed)
	db.RegisterCallback(self, "OnProfileCopied", Seed)
	db.RegisterCallback(self, "OnProfileReset", Seed)
	return db
end

local function Bars(config, spec)
	local _, _, width, height, powerHeight = unpack(spec)
	config.HealthBarSize, config.HealthBarPosition = { width, height }, { "TOPLEFT", 8, -8 }
	config.HealthBarTexture, config.HealthBarOrientation = media("statusbar-power"), "RIGHT"
	config.HealthBarSparkMap = {}
	config.HealthBackdropSize, config.HealthBackdropPosition = { width, height }, { "CENTER", 0, 0 }
	config.HealthBackdropTexture, config.HealthBackdropColor = media("statusbar-dark"), { .1, .1, .1, 1 }
	config.PowerBarSize, config.PowerBackdropSize = { width, powerHeight }, { width, powerHeight }
	config.PowerBarPosition, config.PowerBackdropPosition = { "BOTTOMLEFT", 8, 8 }, { "CENTER", 0, 0 }
	config.PowerBarTexture, config.PowerBarTextureWrath = media("statusbar-power"), media("statusbar-power")
	config.PowerBackdropTexture, config.PowerBackdropTextureWrath = media("statusbar-dark"), media("statusbar-dark")
	config.PowerBackdropColor, config.PowerBarAlpha = { .1, .1, .1, 1 }, 1
	config.PowerBarTexCoord, config.PowerBarOrientation, config.PowerBarSparkMap = { 0, 1, 0, 1 }, "RIGHT", {}
	config.PowerBarForegroundTexture, config.PowerBarForegroundColor = media("statusbar-normal-overlay"), { 1, 1, 1, 1 }
	config.PowerBarForegroundSize, config.PowerBarForegroundPosition = { width, powerHeight }, { "CENTER", 0, 0 }
	for key in pairs(config) do
		if (type(key) == "string" and (key:find("ThreatTexture") or key:find("PortraitBorderTexture"))) then config[key] = "" end
	end
end

--- Config conversion is cached per original table; class skins never see it.
HUD.GetConfig = function(self, name, original)
	if (not self:IsActive()) then return original end
	if (cache[original]) then return cache[original] end
	local spec = units[name]
	local button = name == "ActionButton" or name == "PetActionButton" or name == "StanceButton" or name == "ExtraActionButton"
	if (not spec and not button and name ~= "PlayerCastBar" and name ~= "PlayerClassPower") then return original end
	local config = Copy(original)
	if (spec) then
		Bars(config, spec)
		for _, key in ipairs({ "Novice", "Hardened", "Seasoned", "Boss", "Critter" }) do
			if (config[key]) then Bars(config[key], spec) end
		end
		if (config.UnitSize) then config.UnitSize = { spec[1], spec[2] }
		else config.Size = { spec[1], spec[2] } end
		config.HitRectInsets = { -4, -4, -4, -4 }
		config.IsFlippedHorizontally, config.UseHealthSpark = false, false
		config.HealthValuePosition, config.HealthValueJustifyH = { "RIGHT", -10, 0 }, "RIGHT"
		config.HealthPercentagePosition = { "LEFT", 10, 0 }
		config.HealthValueFont, config.HealthPercentageFont = ns.API.GetFont(spec[1] > 200 and 16 or 11, true), ns.API.GetFont(11, true)
		config.PowerValuePosition, config.PowerValueFont = { "CENTER", 0, 0 }, ns.API.GetFont(11, true)
		config.PowerValueColor = { 1, 1, 1, .85 }
		config.NamePosition, config.NameJustifyH, config.NameSize = { "TOPLEFT", 12, -10 }, "LEFT", { spec[3] - 20, 18 }
		config.NameFont = ns.API.GetFont(spec[1] > 200 and 16 or 11, true)
		config.PortraitAlpha = 0
		if (config.Seasonal) then
			config.Seasonal.WinterVeilPowerTexture, config.Seasonal.WinterVeilManaTexture = "", ""
		end
		config.PortraitBackgroundTexture, config.PortraitShadeTexture, config.PortraitBorderTexture = "", "", ""
		config.TargetHighlightTexture = ""
		config.ClassificationSize, config.PvPIndicatorSize, config.TargetIndicatorSize = { 30, 30 }, { 30, 30 }, { 32, 16 }
		config.ClassificationPosition, config.PvPIndicatorPosition = { "BOTTOMRIGHT", 24, -8 }, { "BOTTOMRIGHT", 24, -8 }
		config.TargetIndicatorPosition, config.RaidTargetPosition = { "TOP", 0, 20 }, { "TOPRIGHT", -8, 24 }
		config.CombatIndicatorSize, config.CombatIndicatorPosition = { 32, 32 }, { "BOTTOMLEFT", -24, -4 }
		if (name == "PlayerFrame") then
			-- 3.x crossed swords: the top-right cell of state-grid, centred on the
			-- frame. StyleUnit crops the cell; Love Festival keeps the same icon.
			config.CombatIndicatorSize, config.CombatIndicatorPosition = { 64, 64 }, { "CENTER", 0, 9 }
			config.CombatIndicatorTexture, config.CombatIndicatorColor = media("state-grid"), { 1, 1, 1 }
			if (config.Seasonal) then
				config.Seasonal.LoveFestivalCombatIndicatorSize = config.CombatIndicatorSize
				config.Seasonal.LoveFestivalCombatIndicatorPosition = config.CombatIndicatorPosition
				config.Seasonal.LoveFestivalCombatIndicatorTexture = config.CombatIndicatorTexture
				config.Seasonal.LoveFestivalCombatIndicatorColor = config.CombatIndicatorColor
			end
		end
		config.CastBarTextPosition, config.CastBarValuePosition = { "LEFT", 10, 0 }, { "RIGHT", -10, 0 }
		config.CastBarTextSize = { spec[3] - 60, spec[4] }
		if (config.AurasPosition) then
			config.AurasPosition = name == "PlayerFrame" and { "BOTTOMLEFT", 8, spec[2] + 4 } or { "TOPLEFT", 8, -spec[2] - 4 }
			config.AurasSize, config.AurasSizeBoss = { spec[3], 76 }, { spec[3], 76 }
			config.AurasNumTotalBoss = config.AurasNumTotal
		end
	elseif (button) then
		local size = name == "ExtraActionButton" and 56 or name == "ActionButton" and 54 or 42
		config.ButtonSize, config.ButtonHitRects = { size, size }, { 0, 0, 0, 0 }
		config.ButtonMaskTexture = media("actionbutton-mask-square-rounded")
		config.ButtonIconSize, config.ButtonIconPosition = { size - 10, size - 10 }, { "CENTER", 0, 0 }
		config.ButtonBackdropSize, config.ButtonBackdropPosition = { size - 10, size - 10 }, { "CENTER", 0, 0 }
		config.ButtonBackdropTexture, config.ButtonBackdropColor = WHITE, { 0, 0, 0, .75 }
		config.ButtonBorderTexture = ""
		config.ButtonBorderSize, config.ButtonBorderPosition = { size, size }, { "CENTER", 0, 0 }
		config.ButtonSpellHighlightSize, config.ButtonSpellHighlightPosition = { size, size }, { "CENTER", 0, 0 }
		config.ButtonSpellHighlightTexture, config.ButtonAssistedHighlightTexture = media("actionbutton-spellhighlight-square-rounded"), media("actionbutton-spellhighlight-square-rounded")
		config.ButtonKeybindPosition, config.ButtonKeybindJustifyH, config.ButtonKeybindFont = { "TOPLEFT", 6, -6 }, "LEFT", ns.API.GetFont(13, true)
		config.ButtonCountPosition, config.ButtonCountFont = { "BOTTOMRIGHT", -6, 6 }, ns.API.GetFont(14, true)
		if (name == "ExtraActionButton") then
			config.ExtraButtonSize, config.ExtraButtonMask = config.ButtonSize, config.ButtonMaskTexture
			config.ExtraButtonIconSize, config.ExtraButtonCooldownSize = config.ButtonIconSize, config.ButtonIconSize
			config.ExtraButtonBorderTexture = ""
			config.ExtraButtonBindPosition, config.ExtraButtonCountPosition = config.ButtonKeybindPosition, config.ButtonCountPosition
		end
	elseif (name == "PlayerCastBar") then
		config.CastBarSize, config.CastBarTexture = { 224, 26 }, media("statusbar-power")
		config.CastBarBackgroundSize, config.CastBarBackgroundPosition = { 224, 26 }, { "CENTER", 0, 0 }
		config.CastBarBackgroundTexture, config.CastBarBackgroundColor = media("statusbar-dark"), { .1, .1, .1, 1 }
		config.CastBarShieldTexture, config.CastBarSpellQueueTexture = "", media("statusbar-power")
		config.CastBarTextPosition, config.CastBarValuePosition = { "LEFT", 16, 0 }, { "RIGHT", -16, 0 }
		config.CastBarTextJustifyH, config.CastBarValueJustifyH = "LEFT", "RIGHT"
		config.CastBarSparkMap = {}
	elseif (name == "PlayerClassPower") then
		config.ClassPowerFrameSize, config.ClassPowerPointOrientation = { 224, 18 }, "RIGHT"
		for _, layout in pairs(config.ClassPowerLayouts) do
			local count = #layout
			for i, point in ipairs(layout) do
				local width = (224 - (count - 1) * 2) / count
				point.Position, point.Size, point.BackdropSize = { "TOPLEFT", (i - 1) * (width + 2), 0 }, { width, 18 }, { width, 18 }
				point.Texture, point.BackdropTexture = media("statusbar-power"), media("statusbar-dark")
				point.PointRotation, point.Rotation, point.Orientation = 0, nil, "RIGHT"
			end
		end
	end
	cache[original] = config
	return config
end

local function Border(parent, large, offset, edgeSize)
	local border = CreateFrame("Frame", nil, parent, "BackdropTemplate")
	border:EnableMouse(false)
	border:SetFrameLevel(parent:GetFrameLevel() + 10)
	border:SetPoint("TOPLEFT", -offset, offset)
	border:SetPoint("BOTTOMRIGHT", offset, -offset)
	border:SetBackdrop({ edgeFile = media(large and "tooltip_border_hex" or "tooltip_border_hex_small"), edgeSize = edgeSize or (large and 32 or 24) })
	border:SetBackdropBorderColor(unpack(ns.Colors.ui))
	return border
end

-- Unit casings as 3.x placed them: player/target hex at 3px out, the small
-- frames' hex_small 32 at 15px out, raid's hex_small 24 at 11px out.
local function UnitBorder(frame)
	local width = frame:GetWidth()
	if (width > 200) then return Border(frame, true, 3) end
	if (width < 100) then return Border(frame, false, 11, 24) end
	return Border(frame, false, 15, 32)
end

--- Called after an action/pet/stance/extra button's normal style has finished.
HUD.StyleButton = function(self, button)
	if (not self:IsActive() or button.LegacyBorder) then return end
	local border = Border(button.OverlayFrame or button.overlay or button, false, 9)
	button.LegacyBorder = border
	if (button.CustomAssistedHighlight) then button.CustomAssistedHighlight:SetDesaturated(true) end
	-- The original casing lights up while hovered. Colour only: no state is read.
	if (button.HookScript) then
		button:HookScript("OnEnter", function() border:SetBackdropBorderColor(unpack(ns.Colors.highlight)) end)
		button:HookScript("OnLeave", function() border:SetBackdropBorderColor(unpack(ns.Colors.ui)) end)
	end
	-- Follow our own border only. Blizzard's template Border is the hidden
	-- equipped-item ring, so pet/stance/extra casings never showed with it.
	local source = button.IconBorder or button.iconBorder
	if (source) then
		border:SetShown(source:IsShown())
		hooksecurefunc(source, "Show", function() border:Show() end)
		hooksecurefunc(source, "Hide", function() border:Hide() end)
	end
end

--- Finishes native unit styles; oUF keeps updating health/power/casts/auras.
HUD.StyleUnit = function(self, frame)
	if (not self:IsActive() or not frame.Health or frame.isNamePlate or frame.LegacyBorder) then return end
	local styles = { Player = true, Target = true, Pet = true, ToT = true, Focus = true, Party = true, Raid5 = true, Raid25 = true, Raid40 = true, Boss = true, Arena = true }
	local style = type(frame.style) == "string" and frame.style:sub(#ns.Prefix + 1)
	if (not styles[style]) then return end
	frame.LegacyBorder = UnitBorder(frame)
	local overlay = frame.Health:CreateTexture(nil, "OVERLAY", nil, -1)
	-- Shade the native bar without changing its clipped fill or reading a value.
	overlay:SetAllPoints(frame.Health)
	overlay:SetTexture(media("statusbar-normal-overlay"))
	if (frame.Portrait) then
		frame.Portrait:SetAlpha(0)
		if (frame.Portrait.Bg) then frame.Portrait.Bg:SetAlpha(0) end
		if (frame.Portrait.Shade) then frame.Portrait.Shade:SetAlpha(0) end
		if (frame.Portrait.Border) then frame.Portrait.Border:SetAlpha(0) end
		-- A 3D model ignores frame alpha (the alpha fix drives SetModelAlpha
		-- from the frame's alpha), and Target/Arena keep their 2D fallback in a
		-- sibling of the model. Hiding the holder takes model, fallback and Bg.
		local holder = frame.Portrait.GetParent and frame.Portrait:GetParent()
		if (holder and holder ~= frame) then holder:Hide() end
	end
	if (not frame.Name and frame.Tag) then
		local name = (frame.Overlay or frame):CreateFontString(nil, "OVERLAY")
		name:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -10)
		name:SetFontObject(ns.API.GetFont(frame:GetWidth() > 200 and 16 or 11, true))
		name:SetTextColor(unpack(ns.Colors.highlight))
		name:SetJustifyH("LEFT")
		frame:Tag(name, "["..ns.Prefix..":Name(20,nil,nil,nil)]")
		frame.Name = name
	end
	-- Target/ToT/Focus/Boss draw their name on the frame itself. Legacy puts it
	-- over the health bar, a child frame that would cover it; lift it above.
	if (frame.Name and frame.Overlay and frame.Name.GetParent and frame.Name:GetParent() == frame) then
		frame.Name:SetParent(frame.Overlay)
	end
	if (frame.Name and frame.Name.SetWidth) then frame.Name:SetWidth(frame:GetWidth() - 24) end
	if (style == "Player" and frame.CombatIndicator and frame.CombatIndicator.SetTexCoord) then
		frame.CombatIndicator:SetTexCoord(.5, 1, 0, .5)
	end
	local highlight = frame.TargetHighlight
	if (highlight) then
		local border = UnitBorder(frame)
		border:SetShown(highlight:IsShown())
		hooksecurefunc(highlight, "Show", function() border:Show() end)
		hooksecurefunc(highlight, "Hide", function() border:Hide() end)
		hooksecurefunc(highlight, "SetVertexColor", function(_, r, g, b)
			if (not issecretvalue or (not issecretvalue(r) and not issecretvalue(g) and not issecretvalue(b))) then border:SetBackdropBorderColor(r, g, b, 1) end
		end)
		frame.LegacyHighlight = border
	end
	local threat = frame.ThreatIndicator
	if (threat) then
		local border = UnitBorder(frame)
		border:Hide()
		hooksecurefunc(threat, "Show", function() border:Show() end)
		hooksecurefunc(threat, "Hide", function() border:Hide() end)
		local previous = threat.PostUpdate
		threat.PostUpdate = function(element, unit, status, r, g, b)
			if (previous) then previous(element, unit, status, r, g, b) end
			if (not issecretvalue or (not issecretvalue(r) and not issecretvalue(g) and not issecretvalue(b))) then
				if (type(r) == "number" and type(g) == "number" and type(b) == "number") then border:SetBackdropBorderColor(r, g, b, 1) end
			end
		end
		frame.LegacyThreat = border
	end
	if (not frame.Power) then
		local power = frame:CreateBar()
		power:SetPoint("BOTTOMLEFT", 8, 8)
		power:SetSize(frame:GetWidth() - 16, 8)
		power:SetStatusBarTexture(media("statusbar-power"))
		power:SetOrientation("RIGHT")
		power.colorPower, power.frequentUpdates = true, true
		power.Override = ns.API.UpdatePower
		local back = power:CreateTexture(nil, "BACKGROUND")
		back:SetAllPoints(power); back:SetTexture(media("statusbar-dark")); back:SetVertexColor(.1, .1, .1, 1)
		frame.Power = power
		frame:EnableElement("Power")
	elseif (frame.Power.SetOrientation) then
		frame.Power:SetOrientation("HORIZONTAL")
	end
	if (frame.ManaOrb) then frame.ManaOrb:SetAlpha(0); frame.ManaOrb:EnableMouse(false) end
end

HUD.Command = function(self, input)
	local command = (input or ""):lower():match("^%s*(.-)%s*$")
	if (command == "status") then self:Print(self:IsActive() and "HUD: Legacy." or "HUD: Azerite."); return end
	if (command == "" or command == "toggle") then command = self:IsActive() and "azerite" or "legacy" end
	if (command ~= "legacy" and command ~= "azerite") then self:Print("/go [legacy|azerite|toggle|status]"); return false end
	if (InCombatLockdown()) then self:Print("Change the HUD outside combat."); return false end
	if (command == "legacy") then
		local variant = ns.GetActiveConfigVariant and ns:GetActiveConfigVariant()
		if (variant and variant ~= "") then self:Print("Select the main AzeriteUI profile before enabling Legacy."); return false end
	end
	local enabled = command == "legacy"
	local char = ns.db and ns.db.char
	if (not char) then return false end
	local changed = (char.legacyHUD == true) ~= enabled or (not enabled and (char.hunterPreview or char.magePreview or char.paladinPreview))
	char.legacyHUD = enabled
	char.hunterPreview, char.magePreview, char.paladinPreview = false, false, false
	if (changed) then Reload() end
	return true
end

--- Media requested at runtime by minimap and proc styling.
HUD.ResolveMedia = function(self, name)
	if (not self:IsActive() or type(name) ~= "string") then return end
	if (name == "minimap-border") then return media("minimap-border-legacy") end
	if (name == "border-aura") then return media("aura_border") end
	if (name:match("^actionbutton%-proc%-")) then return media("actionbutton-spellhighlight-square-rounded") end
end

--- Re-applied by the player/target tier refresh, after their native layouts.
HUD.RefreshUnit = function(self, frame)
	if (not self:IsActive() or not frame.Health or frame.isNamePlate) then return end
	self:StyleUnit(frame)
	if (not frame.LegacyBorder) then return end
	local health = frame.Health
	if (health.Backdrop) then
		health.Backdrop:ClearAllPoints()
		health.Backdrop:SetAllPoints(health)
	end
	local power = frame.Power
	if (power) then
		power:ClearAllPoints()
		power:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 8, 8)
		local width = frame:GetWidth() - 16
		local height = frame:GetWidth() > 200 and 12 or frame:GetWidth() < 100 and 6 or 8
		power:SetSize(width, height)
		power:SetOrientation("HORIZONTAL")
		if (power.SetReverseFill) then power:SetReverseFill(false) end
		power.__AzeriteUI_PowerFakeOrientation = "RIGHT"
		power.__AzeriteUI_PowerFakeWidth, power.__AzeriteUI_PowerFakeHeight = width, height
		power:SetFrameLevel(frame:GetFrameLevel() + 2)
		if (power.Backdrop) then
			power.Backdrop:ClearAllPoints(); power.Backdrop:SetAllPoints(power)
			-- Target keeps its backdrop on its own frame, levelled once to the bar's
			-- original level (+5). Lowering the bar put the dark backdrop over the fill.
			local holder = power.Backdrop.GetParent and power.Backdrop:GetParent()
			if (holder and holder ~= power and holder ~= frame and holder.SetFrameLevel) then holder:SetFrameLevel(power:GetFrameLevel() - 1) end
		end
		if (power.Case) then power.Case:ClearAllPoints(); power.Case:SetAllPoints(power) end
		if (power.Spark) then power.Spark:SetAlpha(0) end
	end
	if (frame.ManaOrb) then frame.ManaOrb:SetAlpha(0); frame.ManaOrb:EnableMouse(false) end
end

HUD.ProfileChanged = function(self)
	if (self.loadedActive ~= self:IsActive()) then
		if (InCombatLockdown()) then self:RegisterEvent("PLAYER_REGEN_ENABLED", "ProfileChanged")
		else self:UnregisterEvent("PLAYER_REGEN_ENABLED", "ProfileChanged"); Reload() end
	else self:UnregisterEvent("PLAYER_REGEN_ENABLED", "ProfileChanged") end
end

HUD.OnInitialize = function(self) self:RegisterChatCommand("go", "Command") end
HUD.OnEnable = function(self)
	self.loadedActive = self:IsActive()
	ns.db.RegisterCallback(self, "OnProfileChanged", "ProfileChanged")
	ns.db.RegisterCallback(self, "OnProfileCopied", "ProfileChanged")
	ns.db.RegisterCallback(self, "OnProfileReset", "ProfileChanged")
end

-- Runs after native styles/elements, including secure group-header children.
ns.oUF:RegisterInitCallback(function(frame)
	if (not HUD:IsActive() or frame.isNamePlate) then return end
	if (frame.style == ns.Prefix.."PlayerCastBar" and frame.Castbar) then
		frame.Castbar.LegacyBorder = Border(frame.Castbar, false, 23, 32)
		-- 3.x had no shield casing. Protected casts and channels (fishing) hid
		-- the backdrop and showed the shield region poking out of the casing.
		frame.Castbar.KeepBackdrop = true
		if (frame.Castbar.Shield) then frame.Castbar.Shield:SetAlpha(0) end
	elseif (frame.style == ns.Prefix.."PlayerClassPower") then
		for _, element in ipairs({ frame.ClassPower or false, frame.Runes or false, frame.Stagger or false }) do
			if (element) then element.LegacyBorder = Border(element, false, 23, 32) end
		end
	else HUD:RefreshUnit(frame) end
end)
