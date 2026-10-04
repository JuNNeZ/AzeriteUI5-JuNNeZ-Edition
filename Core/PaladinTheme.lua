-- Optional artwork preview. Saved per character, enabled only in development
-- mode, and rebuilt on reload. Gameplay colors/values stay with their owners.
local Addon, ns = ...
local Theme = ns:NewModule("PaladinTheme", "AceConsole-3.0", "LibMoreEvents-1.0")
ns.PaladinTheme = Theme

local path = function(name)
	return "Interface\\AddOns\\"..Addon.."\\Assets\\Paladin\\"..name..".tga"
end
-- Existing component hooks enter here. Delegate to Hunter and Mage before
-- Paladin gates so themes never stack; each owns its separate layout cache.
local cache = {}
local media = {
	["actionbutton-border"] = "action-ring",
	["minimap-border"] = "minimap-ring",
	["portrait_frame_hi"] = "portrait-case",
	["portrait_frame_lo"] = "portrait-case-low",
	["party_portrait_border"] = "party-case",
	["point_plate"] = "utility-plate",
	["icon_exit_flight"] = "vehicle-exit",
	["minimap-onebar-backdrop"] = "status-backdrop",
	["cast_back"] = "compact-case",
	["hp_critter_case"] = "critter-case",
	["nameplate_backdrop"] = "plate-case",
	["pw_crystal_case"] = "crystal-holder",
	["pw_crystal_case_low"] = "crystal-holder",
	["pw_crystal_case_glow"] = "crystal-holder-glow",
	["orb_case_hi"] = "orb-case",
	["orb_case_low"] = "orb-case",
	["orb_case_glow"] = "orb-case-glow",
	["border-tooltip"] = "utility-edge",
	["config_button"] = "utility-cog",
	["config_button_bright"] = "utility-cog"
}

Theme.IsActive = function(self)
	if (ns.HunterTheme and ns.HunterTheme:IsActive()) then return false end
	if (ns.MageTheme and ns.MageTheme:IsActive()) then return false end
	local db = ns.db
	if (not db or not db.global or not db.char or not db.global.enableDevelopmentMode or not db.char.paladinPreview) then return false end
	if (ns.IsSaiyaRattProfile and ns:IsSaiyaRattProfile()) then return false end
	local variant = ns.GetActiveConfigVariant and ns:GetActiveConfigVariant()
	return not variant or variant == ""
end

Theme.UseIceCrystal = function(self, requested)
	if (ns.HunterTheme and ns.HunterTheme:IsActive()) then return ns.HunterTheme:UseIceCrystal(requested) end
	if (ns.MageTheme and ns.MageTheme:IsActive()) then return ns.MageTheme:UseIceCrystal(requested) end
	return requested and not self:IsActive()
end

-- Called with the sanitized resource token from the player power renderer.
-- Preview-only mana styling takes precedence over saved crystal color modes.
Theme.GetPowerColor = function(self, token)
	if (ns.HunterTheme and ns.HunterTheme:IsActive()) then return ns.HunterTheme:GetPowerColor(token) end
	if (ns.MageTheme and ns.MageTheme:IsActive()) then return ns.MageTheme:GetPowerColor(token) end
	if (self:IsActive() and token == "MANA") then return { 1, .78, .28 } end
end

Theme.ResolveMedia = function(self, name)
	if (ns.HunterTheme and ns.HunterTheme:IsActive()) then return ns.HunterTheme:ResolveMedia(name) end
	if (ns.MageTheme and ns.MageTheme:IsActive()) then return ns.MageTheme:ResolveMedia(name) end
	if (self:IsActive() and media[name]) then return path(media[name]) end
end

-- Some skins store media at file-load time, before AceDB is initialized.
Theme.ResolvePath = function(self, original)
	if (ns.HunterTheme and ns.HunterTheme:IsActive()) then return ns.HunterTheme:ResolvePath(original) end
	if (ns.MageTheme and ns.MageTheme:IsActive()) then return ns.MageTheme:ResolvePath(original) end
	local name = type(original) == "string" and original:match("[\\/]Assets[\\/]([^\\/]+)%.tga$")
	return (name and self:ResolveMedia(name)) or original
end

local IsWidget = function(value)
	return type(value.GetObjectType) == "function" or type(value[0]) == "userdata"
end

-- Layouts can contain actual Font/Frame objects (for example Minimap anchors).
-- Preserve those identities; copying a WoW object's Lua table loses its native
-- wrapper and may recurse through the entire frame tree.
local function CopyLayout(source, seen)
	if (type(source) ~= "table" or IsWidget(source)) then return source end
	seen = seen or {}
	if (seen[source]) then return seen[source] end
	local result = {}
	seen[source] = result
	for key, value in pairs(source) do result[key] = CopyLayout(value, seen) end
	return result
end

local function Transform(t, seen)
	seen = seen or {}
	if (seen[t] or IsWidget(t)) then return end
	seen[t] = true
	for key, value in pairs(t) do
		if (type(value) == "table") then
			Transform(value, seen)
		elseif (type(value) == "string") then
			local name = value:match("[\\/]Assets[\\/]([^\\/]+)%.tga$")
			if (name and media[name]) then t[key] = path(media[name]) end
		end
	end
	-- Neutralize only material tints for remapped decorative textures.
	for key, value in pairs(t) do
		if (type(key) == "string" and type(value) == "string" and value:find("\\Assets\\Paladin\\", 1, true)) then
			local prefix = key:match("^(.-)Texture$") or key:match("^(.-)TexturePath$")
			local color = prefix and t[prefix.."Color"]
			if (type(color) == "table") then t[prefix.."Color"] = { 1, 1, 1, color[4] or 1 } end
		end
	end
	-- These are material tints, never class, reaction, threat or cast-state colors.
	for _, prefix in ipairs({ "ButtonBorder", "ExtraButtonBorder", "PortraitBorder", "PowerBarForeground", "ManaOrbForeground" }) do
		if (t[prefix.."Color"]) then t[prefix.."Color"] = { 1, 1, 1, 1 } end
	end
	if (t.ManaOrbForegroundTexture) then
		-- The lion casing replaces the old rim/plinth; keep the independent glass.
		t.ManaOrbRimColor = { 1, 1, 1, 0 }
		t.ManaOrbArtworkColor = { 1, 1, 1, 0 }
	end
end

-- Lazily copy resolved layouts: source tables and other profiles are untouched.
Theme.GetConfig = function(self, name, original)
	if (ns.HunterTheme and ns.HunterTheme:IsActive()) then return ns.HunterTheme:GetConfig(name, original) end
	if (ns.MageTheme and ns.MageTheme:IsActive()) then return ns.MageTheme:GetConfig(name, original) end
	if (not self:IsActive()) then return original end
	if (cache[original]) then return cache[original] end
	local config = CopyLayout(original)
	Transform(config)
	if (name == "PlayerFrame") then
		config.PowerOrbColors.MANA = { 1, .78, .28 }
		for _, tier in ipairs({ "Novice", "Hardened", "Seasoned" }) do
			config[tier].HealthBarSize[1] = 373
		end
		config.PowerBarColors.MANA = { 1, .78, .28 }
	elseif (name == "PlayerCastBar") then
		config.CastBarSize = { config.CastBarSize[1]*2.25, config.CastBarSize[2]*2.25 }
		config.CastBarTextPosition[3] = config.CastBarTextPosition[3]*2.25
	elseif (name == "PlayerFrameAlternate") then
		config.PowerBarColors.MANA = { 1, .78, .28 }
	elseif (name == "ToTFrame" or name == "FocusFrame") then
		config.HealthBackdropTexture = path("compact-case")
		config.HealthBackdropColor = { 1, 1, 1 }
	elseif (name == "PlayerClassPower" and ns.PlayerClass == "PALADIN") then
		config.ClassPowerCaseColor = { .55, .55, .55 }
		config.ClassPowerSlotColor = { .08, .07, .1, 1 }
		config.ClassPowerSlotOffset = 0
		local centers = { {88,164}, {57,126}, {44,84}, {57,42}, {88,4} }
		for i, point in ipairs(config.ClassPowerLayouts.ComboPoints) do
			local size = (i == 5 and 44 or 40)*1.56
			-- Widen the arc for larger seals; fill and case retain one pixel grid.
			point.Position = { "TOPLEFT", centers[i][1]-size/2, -centers[i][2]+size/2 }
			point.Size = { size, size }
			point.BackdropSize = { size, size }
			point.BackdropTexture = path("holy-case")
			point.Texture = path("holy-fill")
			point.PointRotation = 0
		end
	end
	if (name == "PlayerFrame" or name == "PlayerFrameAlternate" or name == "TargetFrame") then
		local target = name == "TargetFrame"
		config.HealthPercentagePosition = { target and "LEFT" or "RIGHT", target and 160 or -160, 4 }
		config.HealthPercentageJustifyH = target and "LEFT" or "RIGHT"
		config.CastBarValuePosition = { target and "LEFT" or "RIGHT", target and 160 or -160, 4 }
		config.CastBarTextSize = { 150, 37 }
		if (config.Critter) then
			config.Critter.HealthPercentagePosition = { "CENTER", 0, 0 }
			config.Critter.CastBarValuePosition = { "CENTER", 0, 0 }
		end
	end
	cache[original] = config
	return config
end

local NewCasing = function(bar)
	local frame = CreateFrame("Frame", nil, bar)
	frame:SetAllPoints(bar)
	frame:SetFrameLevel(bar:GetFrameLevel() + 3)
	frame:EnableMouse(false)
	frame.Art = frame:CreateTexture(nil, "ARTWORK")
	bar.PaladinCasing = frame
	return frame
end

-- Source pixels describe the opening, not a new health shape or value range.
-- The original statusbar/absorb/cast-overlay silhouette is retained underneath.
local FitCasing = function(bar, art, width, height, left, top, right, bottom, flip, fillTop, fillBottom)
	local w, h = bar:GetWidth(), bar:GetHeight()
	local paintedHeight = h*((fillBottom or 1)-(fillTop or 0))
	local x = flip and (width-right) or left
	art:ClearAllPoints()
	art:SetPoint("TOPLEFT", bar, "TOPLEFT", -x*w/(right-left), top*paintedHeight/(bottom-top)-h*(fillTop or 0))
	art:SetSize(width*w/(right-left), height*paintedHeight/(bottom-top))
	art:SetTexCoord(flip and 1 or 0, flip and 0 or 1, 0, 1)
end

-- Inset the opening into the opaque native fill, including its angled tips.
local HealthGeometry = function(bar, db)
	local w, h = bar:GetWidth(), bar:GetHeight()
	if (w < h*2) then return end -- critter: retain its original compact silhouette
	local texture = db and db.HealthBarTexture or ""
	if (texture:find("hp_lowmid_bar", 1, true)) then return "health-lowmid", 2043, 1786, 2/64, 52/64 end
	if (w/h > 12) then return "health-wide", 2671, 2414, 2/64, 48/64 end
	if (w < 200) then return "health-small", 1821, 1494, 1/32, 1 end
	if (math.abs(w/h - 385/37) < .05) then return "health-portrait", 2141, 1884, 3/128, 100/128 end
	return "health-case", 2011, 1754, 3/128, 100/128
end

Theme.StyleHealth = function(self, owner, db, flip)
	if (ns.HunterTheme and ns.HunterTheme:IsActive()) then return ns.HunterTheme:StyleHealth(owner, db, flip) end
	if (ns.MageTheme and ns.MageTheme:IsActive()) then return ns.MageTheme:StyleHealth(owner, db, flip) end
	if (not self:IsActive()) then return end
	local bar = owner.Health
	local material, width, right, fillTop, fillBottom = HealthGeometry(bar, db)
	bar.PaladinHealthGeometry = material and { material, width, right, fillTop, fillBottom } or nil
	bar.PaladinCompact = not material
	if (not material) then
		if (bar.PaladinCasing) then bar.PaladinCasing:SetShown(false) end
		if (bar.PaladinEmpty) then bar.PaladinEmpty:SetAlpha(0) end
		bar.Backdrop:SetAlpha(1)
		return
	end
	local frame = bar.PaladinCasing or NewCasing(bar)
	frame:SetShown(true)
	frame.Art:SetTexture(path(material))
	FitCasing(bar, frame.Art, width, 724, material == "health-small" and 82 or 62, 306, right, 436, flip, fillTop, fillBottom)
	-- The old casing includes a dark cavity. Supply that cavity on its own, so
	-- the generated transparent opening is readable when the bar is empty.
	local empty = bar.PaladinEmpty
	if (not empty) then
		empty = bar:CreateTexture(nil, "BACKGROUND", nil, -2)
		empty:SetAllPoints(bar)
		empty:SetVertexColor(.11, .12, .14, 1)
		bar.PaladinEmpty = empty
	end
	empty:SetTexture(db.HealthBarTexture)
	empty:SetAlpha(1)
	empty:SetTexCoord(flip and 1 or 0, flip and 0 or 1, 0, 1)
	bar.Backdrop:SetAlpha(0)
end

Theme.StyleThreat = function(self, owner, flip)
	if (ns.HunterTheme and ns.HunterTheme:IsActive()) then return ns.HunterTheme:StyleThreat(owner, flip) end
	if (ns.MageTheme and ns.MageTheme:IsActive()) then return ns.MageTheme:StyleThreat(owner, flip) end
	if (not self:IsActive()) then return end
	local threat = owner.ThreatIndicator
	local art = threat and threat.textures and threat.textures.Health
	local geometry = owner.Health.PaladinHealthGeometry
	local material, width, right, fillTop, fillBottom
	if (geometry) then material, width, right, fillTop, fillBottom = unpack(geometry) end
	if (art and material) then
		art:SetTexture(path(material == "health-case" and "health-glow" or material.."-glow"))
		FitCasing(owner.Health, art, width, 724, material == "health-small" and 82 or 62, 306, right, 436, flip, fillTop, fillBottom)
	end
end

Theme.StyleCastbar = function(self, cast)
	if (ns.HunterTheme and ns.HunterTheme:IsActive()) then return ns.HunterTheme:StyleCastbar(cast) end
	if (ns.MageTheme and ns.MageTheme:IsActive()) then return ns.MageTheme:StyleCastbar(cast) end
	if (not self:IsActive()) then return end
	local frame = cast.PaladinCasing or NewCasing(cast)
	frame.Art:SetTexture(path("lion-cast"))
	FitCasing(cast, frame.Art, 2018, 724, 342, 288, 1739, 421, false, 1/32, 1)
	-- The legacy shield is a bar-sized border, not a standalone icon.
	-- Cast_Update retains the existing protected-cast color cue.
	cast.Shield:SetAlpha(0)
	cast.Backdrop:SetAlpha(0)
	local empty = cast.PaladinEmpty or cast:CreateTexture(nil, "BACKGROUND")
	cast.PaladinEmpty = empty
	empty:SetAllPoints(cast)
	empty:SetTexture(ns.API.GetMedia("cast_bar"))
	empty:SetVertexColor(.06, .05, .09, .95)
end

Theme.StyleNameplate = function(self, owner)
	if (ns.HunterTheme and ns.HunterTheme:IsActive()) then return ns.HunterTheme:StyleNameplate(owner) end
	if (ns.MageTheme and ns.MageTheme:IsActive()) then return ns.MageTheme:StyleNameplate(owner) end
	if (not self:IsActive()) then return end
	for _, bar in ipairs({ owner.Health, owner.Castbar }) do
		-- Material replaces the original BACKGROUND texture at its original
		-- size and anchors. No foreground ornament may cover the live meter.
		bar.Backdrop:SetTexture(path("plate-case"))
	end
end

local AddLight = function(parent, anchor, name, maskPath, coords)
	local texture = parent:CreateTexture(nil, "ARTWORK", nil, 1)
	texture:SetAllPoints(anchor)
	texture:SetTexture(path(name))
	if (maskPath) then
		local mask = parent:CreateMaskTexture()
		mask:SetAllPoints(anchor)
		mask:SetTexture(maskPath, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
		if (coords) then mask:SetTexCoord(unpack(coords)) end
		texture:AddMaskTexture(mask)
		texture.Mask = mask
	end
	texture:SetAlpha(.55)
	return texture
end

local Pulse = function(texture)
	local group = texture:CreateAnimationGroup()
	for i, values in ipairs({ { .3, .65, 4 }, { .65, .3, 5 } }) do
		local alpha = group:CreateAnimation("Alpha")
		alpha:SetFromAlpha(values[1])
		alpha:SetToAlpha(values[2])
		alpha:SetDuration(values[3])
		alpha:SetOrder(i)
	end
	group:SetLooping("REPEAT")
	group:Play()
end

-- Holy light strength, 0 to 1 (0 hides it). Multiplies the pulse through the
-- light's own frame, so the animation keeps running untouched underneath.
local lights = setmetatable({}, { __mode = "k" })
local LightStrength = function()
	local value = tonumber(ns.db and ns.db.char and ns.db.char.paladinLight)
	if (not value or value ~= value) then return 1 end
	return math.max(0, math.min(1, value))
end
local ApplyLight = function(content)
	lights[content] = true
	local strength = LightStrength()
	content:SetAlpha(strength)
	content:SetShown(strength > 0)
end

Theme.GetLightStrength = function(self) return LightStrength() end

--- Applies live to the crystal and orb light.
Theme.SetLightStrength = function(self, value)
	value = tonumber(value)
	if (not value) then return false end
	value = math.max(0, math.min(1, value))
	ns.db.char.paladinLight = value ~= 1 and value or nil
	for content in pairs(lights) do ApplyLight(content) end
	return true
end

-- An effect that is switched off keeps its frames for reuse, hidden, and
-- drops out of the strength list so a strength change cannot show it again.
local HideLight = function(content)
	if (not content) then return end
	lights[content] = nil
	content:SetShown(false)
end

-- Crystal is already a native StatusBar. Anchor a clipping frame to its fill
-- texture, just as LibOrb does: no reading, branching or arithmetic on mana.
--- Crystal effect "paladin". Core/ThemeEffects.lua decides when; any theme
--- may use it (Lite+).
Theme.ApplyCrystalEffect = function(self, power, texturePath, coords)
	if (not power.PaladinLight) then
		local clip = CreateFrame("Frame", nil, power)
		clip:SetFrameLevel(power:GetFrameLevel() + 1)
		clip:SetClipsChildren(true)
		clip:SetPoint("BOTTOMLEFT", power, "BOTTOMLEFT")
		clip:SetPoint("BOTTOMRIGHT", power, "BOTTOMRIGHT")
		clip:SetPoint("TOP", power:GetStatusBarTexture(), "TOP")
		-- Textures must belong to a child of the clipping frame.
		local content = CreateFrame("Frame", nil, clip)
		content:SetAllPoints(power)
		content.Strands = AddLight(content, power, "light-strands", texturePath, coords)
		Pulse(content.Strands)
		power.PaladinLight = content
	end
	ApplyLight(power.PaladinLight)
	local mask = power.PaladinLight.Strands.Mask
	mask:SetTexture(texturePath, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
	mask:SetTexCoord(unpack(coords or { 0, 1, 0, 1 }))
end

Theme.ClearCrystalEffect = function(self, power) HideLight(power.PaladinLight) end

--- Orb effect "paladin". Clearing it leaves the fill texture to Player.lua,
--- which sets the layout's own straight after.
Theme.ApplyOrbEffect = function(self, orb)
	orb:SetStatusBarTexture(path("orb-light"), path("orb-light"))
	if (not orb.PaladinLight) then
		local content = CreateFrame("Frame", nil, orb:GetOverlay())
		content:SetAllPoints(orb)
		content:SetFrameLevel(orb:GetOverlay():GetFrameLevel() + 2)
		content.Strands = AddLight(content, orb, "orb-strands")
		Pulse(content.Strands)
		orb.PaladinLight = content
	end
	ApplyLight(orb.PaladinLight)
	return true
end

Theme.ClearOrbEffect = function(self, orb) HideLight(orb.PaladinLight) end

Theme.StyleUtilityButton = function(self, button)
	if (ns.HunterTheme and ns.HunterTheme:IsActive()) then return ns.HunterTheme:StyleUtilityButton(button) end
	if (ns.MageTheme and ns.MageTheme:IsActive()) then return ns.MageTheme:StyleUtilityButton(button) end
	if (not self:IsActive()) then return end
	-- Registered to the original cog canvas; retain its existing size/anchors.
	button.Texture:SetTexture(path("utility-cog"))
	button.Texture:SetVertexColor(1, 1, 1)
	button.Highlight:SetTexture(path("utility-cog"))
	button.Highlight:SetVertexColor(1, 1, 1)
	button.Highlight:SetBlendMode("ADD")
	button.Highlight:SetAlpha(.25)
end

Theme.Command = function(self, input)
	if (not ns.db.global.enableDevelopmentMode) then return end
	local arg = (input or ""):lower():match("^%s*(.-)%s*$")
	if (arg == "status") then
		self:Print(self:IsActive() and "Paladin preview: on." or "Paladin preview: off (requires the main theme and development mode).")
		return
	end
	if (arg ~= "" and arg ~= "on" and arg ~= "off" and arg ~= "toggle") then
		self:Print("/azpaladin [on|off|toggle|status]")
		return
	end
	if (InCombatLockdown()) then self:Print("Change the Paladin preview outside combat."); return end
	if (arg ~= "off" and ns.IsSaiyaRattProfile and ns:IsSaiyaRattProfile()) then
		self:Print("Select the main AzeriteUI profile before enabling the Paladin preview.")
		return
	end
	local enabled = arg == "on" or ((arg == "" or arg == "toggle") and not ns.db.char.paladinPreview)
	if (enabled) then ns.db.char.hunterPreview, ns.db.char.magePreview = false, false end -- explicit Paladin choice leaves Hunter and Mage
	ns.db.char.paladinPreview = enabled and true or false
	ReloadUI()
end

Theme.ProfileChanged = function(self)
	if (self.loadedActive ~= self:IsActive()) then
		if (InCombatLockdown()) then
			self:RegisterEvent("PLAYER_REGEN_ENABLED", "ProfileChanged")
		else
			self:UnregisterEvent("PLAYER_REGEN_ENABLED", "ProfileChanged")
			ReloadUI()
		end
	end
end

Theme.OnInitialize = function(self)
	if (ns.db.global.enableDevelopmentMode) then self:RegisterChatCommand("azpaladin", "Command") end
end

Theme.OnEnable = function(self)
	self.loadedActive = self:IsActive()
	if (self.loadedActive and ns.OptionsKit) then
		for _, key in ipairs({ "WindowBackdrop", "WindowCasing", "ButtonBackdrop" }) do
			ns.OptionsKit[key].edgeFile = path("utility-edge")
		end
	end
	ns.db.RegisterCallback(self, "OnProfileChanged", "ProfileChanged")
	ns.db.RegisterCallback(self, "OnProfileCopied", "ProfileChanged")
	ns.db.RegisterCallback(self, "OnProfileReset", "ProfileChanged")
end
