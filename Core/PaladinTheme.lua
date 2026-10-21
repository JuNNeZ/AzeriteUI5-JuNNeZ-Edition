-- Ashbringer / Silver Hand: native-sized casings and separate ornaments.
-- Functional fills, masks, geometry, fonts and saved anchors remain shared.
local Addon, ns = ...
local Engine = ns.ThemeEngine
local Theme = ns:NewModule("PaladinTheme", "AceConsole-3.0", "LibMoreEvents-1.0")
ns.PaladinTheme = Theme
Engine:Register(Theme, 30)
local path = Engine:MediaPath("Paladin")
local media = {}
for _, name in ipairs({
	"hp_cap_case", "hp_mid_case", "hp_low_case", "hp_boss_case", "hp_critter_case", "hp_critter_case_hi",
	"cast_back", "cast_back_spiked", "cast_back_wooden", "nameplate_backdrop",
	"pw_crystal_case", "pw_crystal_case_low", "orb_case_hi", "orb_case_low", "orb-border",
	"portrait_frame_hi", "portrait_frame_lo", "party_portrait_border", "actionbutton-border",
	"actionbutton-border-square", "actionbutton-border-square-rounded",
	"minimap-border", "minimap-onebar-backdrop", "minimap-twobars-backdrop", "point_plate",
	"config_button", "config_button_bright", "icon_exit_flight", "options-box",
	"border-tooltip", "border-aura", "better-blizzard-border-small-alternate",
	"options-casing-round", "options-well-round"
}) do media[name] = true end
Theme.Media = media
local over = { hp_cap_case = true, hp_mid_case = true, hp_low_case = true, hp_boss_case = true,
	cast_back = true, cast_back_spiked = true, cast_back_wooden = true }
local healthBars = setmetatable({}, { __mode = "k" })
local castBars = setmetatable({}, { __mode = "k" })
local castSlot = Engine.OrnamentSlots.CastHead
local healthDips = { hp_cap_case = {757.5/1024,187/256}, hp_mid_case = {757.5/1024,190/256},
	hp_low_case = {757.5/1024,190/256}, hp_boss_case = {876/1024,185/256} }
local healthSettings = Engine:NewEndcapSettings({ prefix = "paladin", choices = { ashbringer = true, silverhand = true, argent = true, none = true },
	default = "ashbringer", clearDefault = true, defaultScale = 1.3,
	-- Maintainer's screenshot (Ashbringer) and SavedVariables (Silver Hand).
	placements = { ashbringer = { scale = 1.70, y = -17 }, silverhand = { scale = 1.65, y = -17 } },
	refresh = function() Theme:RefreshOrnaments() end })
healthSettings.Install(Theme)
local castSettings = Engine:NewEndcapSettings({ prefix = "paladinCast", name = "CastEndcap",
	choices = { libram = true, none = true }, default = "libram", clearDefault = true,
	refresh = function() Theme:RefreshOrnaments() end })
castSettings.Install(Theme)

Theme.IsActive = function(self)
	if (ns.HunterTheme and ns.HunterTheme:IsActive()) then return false end
	if (ns.MageTheme and ns.MageTheme:IsActive()) then return false end
	local db = ns.db
	-- Public for testing since 5.27.1, like Hunter and Mage (marked WIP on the Themes page).
	return db and db.char and db.char.paladinPreview and Engine:IsMainLayout() or false
end
-- Existing palettes stay native; Light is an explicit, opt-in mana source.
local LIGHT_POWER_COLOR = { 1, .84, .35 }
Theme.GetLightPowerColor = function(self, token)
	if (self:IsActive() and token == "MANA") then return LIGHT_POWER_COLOR end
end
Theme.UseIceCrystal = function(self, requested)
	local player = ns.GetModule and ns:GetModule("PlayerFrame", true)
	local profile = player and player.db and player.db.profile
	-- The ice artwork has baked blue pigment. An explicit Light colour uses
	-- the neutral faceted surface; the saved ice/seasonal preference is kept.
	if (profile and profile.crystalOrbColorMode == "light" and self:IsActive()) then return false end
	return requested
end
Theme.GetPowerColor = function(self, token) end
Theme.ResolveMedia = function(self, name)
	if (self:IsActive() and media[name]) then return path(name) end
end
Theme.ResolveOwnMedia = function(self, name) if (media[name]) then return path(name) end end
Theme.ResolvePath = function(self, original)
	local name = Engine.AssetName(original)
	return (name and self:ResolveMedia(name)) or original
end
local replaceOptions = { resolve = function(name) return Theme:ResolveMedia(name) end }
local CachedConfig = Engine:NewConfigCache(function(name, original)
	local config = Engine:CopyLayout(original)
	Engine:ReplaceMedia(config, replaceOptions)
	-- One material tint for the newly painted class-power plates; activation,
	-- glyphs, per-resource colours and every point's original geometry are kept.
	if (name == "PlayerClassPower") then config.ClassPowerCaseColor = { 1, 1, 1 } end
	return config
end)
Theme.GetConfig = function(self, name, original)
	if (not self:IsActive()) then return original end
	return CachedConfig(name, original)
end

local ArtFrame = function(bar, key, level, layer)
	local frame = bar[key]
	if (not frame) then
		frame = CreateFrame("Frame", nil, bar)
		frame:SetAllPoints(bar)
		frame:EnableMouse(false)
		frame.Art = frame:CreateTexture(nil, layer or "ARTWORK")
		bar[key] = frame
	end
	frame:SetFrameLevel(bar:GetFrameLevel() + level)
	return frame
end
-- Front rails follow the actual native backdrop rectangle, including user
-- scaling. No texture fit coordinates, new bar size or layout offsets.
local CasingOver = function(bar, nativePath, flip)
	local name = type(nativePath) == "string" and nativePath:match("[\\/]Paladin[\\/]([^\\/]+)%.tga$")
	if (not name or not over[name] or not bar.Backdrop) then
		if (bar.PaladinRails) then bar.PaladinRails:SetShown(false) end
		return
	end
	local frame = ArtFrame(bar, "PaladinRails", 1)
	frame.Art:SetTexture(path(name.."-over"))
	frame.Art:SetAllPoints(bar.Backdrop)
	frame.Art:SetTexCoord(flip and 1 or 0, flip and 0 or 1, 0, 1)
	frame:SetShown(true)
end
local HealthEndcap = function(bar, flip)
	-- Opaque endcap is a front attachment: fill/prediction remain underneath.
	local frame = ArtFrame(bar, "PaladinOrnaments", 4, "OVERLAY")
	healthBars[bar] = flip and true or false
	local dx, dy = healthSettings.GetOffset()
	Engine:StyleAlignedHealthEndcap(frame, frame.Art, bar, path, healthSettings.GetKey(),
		healthDips, flip, healthSettings.GetScale(), dx, dy)
end
Theme.StyleHealth = function(self, owner, db, flip)
	if (not self:IsActive() or not owner or not owner.Health or not db) then return end
	local bar = owner.Health
	bar.PaladinCaseName = type(db.HealthBackdropTexture) == "string"
		and db.HealthBackdropTexture:match("[\\/]Paladin[\\/]([^\\/]+)%.tga$")
	bar.PaladinPortraitCaseName = type(db.PortraitBorderTexture) == "string"
		and db.PortraitBorderTexture:match("[\\/]Paladin[\\/]([^\\/]+)%.tga$")
	CasingOver(bar, db.HealthBackdropTexture, flip)
	local name = bar.PaladinCaseName
	bar.ThemeEndcapAssembly = healthDips[name] and bar.Backdrop
		and { name = name, path = path, back = bar.Backdrop, front = bar.PaladinRails and bar.PaladinRails.Art,
			bareThreat = path(name.."-glow"), glow = name.."-glow", threat = bar.PaladinThreat } or nil
	-- Compact/group/boss meters and critters have no weapon ornament.
	local compact = (type(db.HealthBarTexture) == "string" and db.HealthBarTexture:find("cast_bar", 1, true))
		or bar:GetWidth() < bar:GetHeight()*2
	if (compact) then
		healthBars[bar] = nil
		if (bar.PaladinOrnaments) then
			bar.PaladinOrnaments:SetShown(false)
			if (bar.PaladinOrnaments.Threat) then bar.PaladinOrnaments.Threat:Hide() end
		end
		return
	end
	HealthEndcap(bar, flip)
end
Theme.StyleThreat = function(self, owner, flip)
	if (not self:IsActive() or not owner) then return end
	local frame = owner.Health and owner.Health.PaladinOrnaments
	local indicator = owner.ThreatIndicator
	local native = indicator and indicator.textures and indicator.textures.Health
	local bar = owner.Health
	local name = bar and bar.PaladinCaseName
	if (native and bar and bar.Backdrop and name and name:match("^hp_.*_case$") and over[name]) then
		-- The native threat anchors use older padding. Follow the actual art
		-- rectangle and its final silhouette, without reading any threat value.
		native:ClearAllPoints()
		native:SetAllPoints(bar.Backdrop)
		bar.PaladinThreat = native
		native:SetTexture(path(name.."-glow"))
		if (bar.ThemeEndcapAssembly) then bar.ThemeEndcapAssembly.threat = native end
		native:SetTexCoord(flip and 1 or 0, flip and 0 or 1, 0, 1)
	end
	local portraitGlow = indicator and indicator.textures and indicator.textures.Portrait
	local portrait = owner.Portrait and owner.Portrait.Border
	local portraitName = bar and bar.PaladinPortraitCaseName
	if (portraitGlow and portrait and (portraitName == "portrait_frame_hi" or portraitName == "portrait_frame_lo")) then
		portraitGlow:ClearAllPoints()
		portraitGlow:SetAllPoints(portrait)
		portraitGlow:SetTexture(path(portraitName.."-glow"))
	end
	if (not frame or not native or healthBars[bar] == nil) then return end
	local glow = frame.Threat
	if (not glow) then
		-- Keep the halo behind the entire health assembly, not above its fill
		-- inside the foreground endcap frame. That avoids a lit internal seam.
		glow = (native:GetParent() or frame):CreateTexture(nil, "BACKGROUND", nil, -3)
		glow:SetAllPoints(frame.Art)
		glow:SetBlendMode("ADD")
		frame.Threat, frame.ThreatSource = glow, native
		local SetShown = function(shown)
			if (healthSettings.GetKey() == "none" or healthBars[bar] == nil) then glow:Hide() else glow:SetShown(shown) end
		end
		hooksecurefunc(native, "Show", function() SetShown(true) end)
		hooksecurefunc(native, "Hide", function() SetShown(false) end)
		hooksecurefunc(native, "SetShown", function(_, shown) SetShown(shown) end)
		hooksecurefunc(native, "SetAlpha", function(_, alpha) glow:SetAlpha(alpha) end)
		hooksecurefunc(native, "SetVertexColor", function(_, ...) glow:SetVertexColor(...) end)
	end
	local key = healthSettings.GetKey()
	glow:SetTexture(path("ornament-"..(key == "none" and "ashbringer" or key).."-"..name.."-glow"))
	glow:SetTexCoord(flip and 1 or 0, flip and 0 or 1, 0, 1)
	-- Already-active threat needs its colour immediately, before the next hook.
	-- Widget channels are forwarded directly, never compared or calculated.
	glow:SetVertexColor(native:GetVertexColor())
	glow:SetAlpha(native:GetAlpha())
	if (healthSettings.GetKey() == "none") then glow:Hide() else glow:SetShown(native:IsShown()) end
end
local CastHead = function(cast)
	local frame = ArtFrame(cast, "PaladinCastHead", 3)
	castBars[cast] = true
	local enabled = castSettings.GetKey() ~= "none"
	frame:SetShown(enabled)
	if (not enabled) then return end
	local dx, dy = castSettings.GetOffset()
	local size = castSlot.size*castSettings.GetScale()
	frame.Art:SetTexture(path("cast-head-libram"))
	frame.Art:ClearAllPoints()
	frame.Art:SetSize(size, size)
	frame.Art:SetPoint("CENTER", cast, "LEFT", castSlot.x - dx, castSlot.y + dy)
	frame:SetShown(true)
end
Theme.StyleCastbar = function(self, cast)
	if (not self:IsActive() or not cast) then return end
	-- Match the standalone player's existing casing; native shield/protected
	-- cast cue is retained. The front lip tracks its native backdrop visibility.
	CasingOver(cast, path("cast_back"), false)
	local shieldRails
	if (cast.Shield) then
		shieldRails = ArtFrame(cast, "PaladinShieldRails", 1)
		shieldRails.Art:SetTexture(path("cast_back_spiked-over"))
		shieldRails.Art:SetAllPoints(cast.Shield)
	end
	-- PlayerCastBar's native callback already toggles Backdrop for protection.
	-- oUF's shield toggle is currently disabled; keep our shield paired with
	-- that existing switch, without reading notInterruptible unit values.
	for _, pair in ipairs({ { cast.Backdrop, cast.PaladinRails }, { cast.Shield, shieldRails } }) do
		local texture, frame = pair[1], pair[2]
		if (texture and frame) then
			if (not frame.visibilityHooked) then
				frame.visibilityHooked = true
				local SetShown = function(shown)
					frame:SetShown(shown)
					if (texture == cast.Backdrop and cast.Shield) then cast.Shield:SetShown(not shown) end
				end
				hooksecurefunc(texture, "Show", function() SetShown(true) end)
				hooksecurefunc(texture, "Hide", function() SetShown(false) end)
				hooksecurefunc(texture, "SetShown", function(_, shown) SetShown(shown) end)
			end
			frame:SetShown(texture:IsShown())
		end
	end
	if (cast.Shield and cast.Backdrop) then cast.Shield:SetShown(not cast.Backdrop:IsShown()) end
	CastHead(cast)
end
Theme.StyleNameplate = function(self, owner)
	if (not self:IsActive()) then return end
	for _, bar in ipairs({ owner.Health, owner.Castbar }) do
		if (bar and bar.Backdrop) then
			bar.Backdrop:SetTexture(path("nameplate_backdrop"))
			bar.Backdrop:SetVertexColor(1, 1, 1)
		end
	end
end
Theme.StyleUtilityButton = function(self, button)
	if (not self:IsActive()) then return end
	button.Texture:SetTexture(path("config_button")); button.Texture:SetVertexColor(1, 1, 1)
	button.Highlight:SetTexture(path("config_button_bright")); button.Highlight:SetVertexColor(1, 1, 1)
end
-- A quiet silver/gold backing at the native compass north anchor. The native
-- N font string, compass rotation and radius are retained.
Theme.StyleCompass = function(self, compass)
	if (not self:IsActive() or not compass or not compass.north) then return end
	local art = compass.PaladinNorth
	if (not art) then
		art = compass:CreateTexture(nil, "BACKGROUND")
		compass.PaladinNorth = art
	end
	art:SetTexture(path("minimap-north"))
	art:SetSize(Engine.OrnamentSlots.North.size, Engine.OrnamentSlots.North.size)
	art:SetPoint("CENTER", compass.north, "CENTER", 0, 0)
end
--- Reapplies the shared ornament slots after a live placement change.
Theme.RefreshOrnaments = function(self)
	if (not self:IsActive()) then return end
	for bar, flip in pairs(healthBars) do HealthEndcap(bar, flip) end
	for cast in pairs(castBars) do CastHead(cast) end
	if (ns.ThemeBarPreview) then ns.ThemeBarPreview:Refresh() end
end

local AddLight = function(parent, anchor, name, maskPath, coords, materialPath)
	local texture = parent:CreateTexture(nil, "ARTWORK", nil, 1)
	texture:SetAllPoints(anchor)
	texture:SetTexture(materialPath or path(name))
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

local Pulse = function(texture, low, high)
	low, high = low or .3, high or .65
	local group = texture:CreateAnimationGroup()
	for i, values in ipairs({ { low, high, 4 }, { high, low, 5 } }) do
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
-- Foreground light spheres have their own 48-second drift, independent of the
-- 32-second waves. Their positions use only our fixed frame dimensions/time;
-- the native mask and fill clip bound them without inspecting mana.
local UpdateLightSpheres = function(content, elapsed)
	content.SphereTime = ((content.SphereTime or 0) + elapsed)%48
	local phase = content.SphereTime*math.pi*2/48
	local anchor = content.LightAnchor
	local width, height = anchor:GetWidth(), anchor:GetHeight()
	local unit = math.min(width, height)
	for i, art in ipairs(content.Spheres) do
		local seed = i*2.399963
		local x = .5 + .26*math.sin(phase+seed) + .08*math.sin(2*phase-seed)
		local y = .5 + .30*math.cos(phase+seed*.7) + .08*math.sin(2*phase+seed)
		local pulse = .5 + .5*math.sin(phase*(6+i)+seed)
		local size = unit*(.055+.01*(i%3))*(.85+.3*pulse)
		art:ClearAllPoints()
		art:SetPoint("CENTER", anchor, "BOTTOMLEFT", x*width, y*height)
		art:SetSize(size, size)
		art:SetAlpha(.32+.38*pulse*pulse)
	end
end
-- One 8x8 sheet for every specialization, shared by crystal and orb. Like the
-- Mage flow, two permanently bound samples crossfade; only local time and UVs
-- change during playback. Half-texel insets keep neighbouring cells out.
local LightCoords = function(texture, index)
	local x, y = index%8, math.floor(index/8)
	texture:SetTexCoord((x*128 + .5)/1024, ((x+1)*128 - .5)/1024,
		(y*128 + .5)/1024, ((y+1)*128 - .5)/1024)
end
local UpdateLight = function(content, elapsed)
	content.Time = ((content.Time or 0) + elapsed)%32
	local phase = content.Time*2
	local index = math.floor(phase)
	if (content.Index ~= index) then
		content.Index = index
		LightCoords(content.Flow, index)
		LightCoords(content.FlowNext, (index+1)%64)
	end
	local blend = phase-index
	content.Flow:SetAlpha(.65*(1-blend))
	content.FlowNext:SetAlpha(.65*blend)
	UpdateLightSpheres(content, elapsed)
end
local AddFlow = function(content, anchor, maskPath)
	local mask = content:CreateMaskTexture()
	mask:SetAllPoints(anchor)
	mask:SetTexture(maskPath, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
	content.FlowMask = mask
	for _, key in ipairs({ "Flow", "FlowNext" }) do
		local art = content:CreateTexture(nil, "ARTWORK", nil, 2)
		art:SetAllPoints(anchor)
		art:SetTexture(path("holy-energy"))
		art:SetBlendMode("ADD")
		art:AddMaskTexture(mask)
		content[key] = art
	end
	-- Separate additive foreground sprites: no particles are baked into the
	-- waves. All six share the current native/ice/circular silhouette mask.
	content.LightAnchor, content.Spheres = anchor, {}
	for i = 1, 6 do
		local art = content:CreateTexture(nil, "ARTWORK", nil, 3)
		art:SetTexture(path("holy-sphere"))
		art:SetBlendMode("ADD")
		art:SetVertexColor(1, .84, .35)
		art:AddMaskTexture(mask)
		content.Spheres[i] = art
	end
	UpdateLight(content, 0)
end
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
	content:SetScript("OnUpdate", strength > 0 and UpdateLight or nil)
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
	content:SetScript("OnUpdate", nil)
	content:SetShown(false)
end

-- Crystal is already a native StatusBar. Anchor a clipping frame to its fill
-- texture, just as LibOrb does: no reading, branching or arithmetic on mana.
--- Crystal effect "paladin". Core/ThemeEffects.lua decides when; any theme
--- may use it (Lite+).
Theme.ApplyCrystalEffect = function(self, power, texturePath, coords)
	if (not power.PaladinLight) then
		local clip = CreateFrame("Frame", nil, power)
		clip:EnableMouse(false)
		clip:SetFrameLevel(power:GetFrameLevel() + 1)
		clip:SetClipsChildren(true)
		clip:SetPoint("BOTTOMLEFT", power, "BOTTOMLEFT")
		clip:SetPoint("BOTTOMRIGHT", power, "BOTTOMRIGHT")
		clip:SetPoint("TOP", power:GetStatusBarTexture(), "TOP")
		-- Textures must belong to a child of the clipping frame.
		local content = CreateFrame("Frame", nil, clip)
		content:EnableMouse(false)
		content:SetAllPoints(power)
		content.Strands = AddLight(content, power, nil, texturePath, nil, texturePath)
		-- Reuse the native faceted surface at low opacity. Broad light ribbons
		-- wash across its planes and make the crystal look rounded.
		Pulse(content.Strands, .04, .10)
		AddFlow(content, power, texturePath)
		power.PaladinLight = content
	end
	ApplyLight(power.PaladinLight)
	local facets = power.PaladinLight.Strands
	facets:SetTexture(texturePath)
	-- Native StatusBar rendering uses this texture's full canvas. Legacy crop
	-- metadata would enlarge only the light and misalign its facet planes.
	facets:SetTexCoord(0, 1, 0, 1)
	local mask = facets.Mask
	mask:SetTexture(texturePath, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
	mask:SetTexCoord(0, 1, 0, 1)
	power.PaladinLight.FlowMask:SetTexture(texturePath, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
	power.PaladinLight.FlowMask:SetTexCoord(0, 1, 0, 1)
end

Theme.ClearCrystalEffect = function(self, power) HideLight(power.PaladinLight) end

-- Complete concept holder: its transparent cavity reveals the native crystal.
-- Keep the uncut clamps and silver rail above the fill at the existing rectangle.
Theme.StyleCrystal = function(self, power, casePath, useMage)
	if (power and power.PaladinCradleBack) then power.PaladinCradleBack:Hide() end
	local case = power and power.Case
	local name = type(casePath) == "string" and casePath:match("[\\/]Paladin[\\/]([^\\/]+)%.tga$")
	if (not self:IsActive() or useMage or not case
		or (name ~= "pw_crystal_case" and name ~= "pw_crystal_case_low")) then
		return
	end
	case:SetTexture(path(name))
end

--- Orb effect "paladin". Clearing it leaves the fill texture to Player.lua,
--- which sets the layout's own straight after.
Theme.ApplyOrbEffect = function(self, orb)
	orb:SetStatusBarTexture(path("orb-light"), path("orb-light"))
	if (not orb.PaladinLight) then
		local content = CreateFrame("Frame", nil, orb:GetOverlay())
		content:EnableMouse(false)
		content:SetAllPoints(orb)
		-- Leave the next level for the shared slosh edge, below native glass.
		content:SetFrameLevel(orb:GetOverlay():GetFrameLevel() + 1)
		content.Strands = AddLight(content, orb, "orb-strands")
		Pulse(content.Strands)
		-- GetOverlay is LibOrb's native fill clip; the shared round fill alpha
		-- additionally bounds the sheet to the orb silhouette at every level.
		AddFlow(content, orb, "Interface\\AddOns\\"..Addon.."\\Assets\\orb2.tga")
		orb.PaladinLight = content
	end
	ApplyLight(orb.PaladinLight)
	return true
end

Theme.ClearOrbEffect = function(self, orb) HideLight(orb.PaladinLight) end

Theme.Command = function(self, input)
	local arg = (input or ""):lower():match("^%s*(.-)%s*$")
	if (arg == "preview" and ns.ThemeBarPreview) then ns.ThemeBarPreview:Show(); return end
	if (arg == "status") then
		self:Print(self:IsActive() and "Paladin preview: on." or "Paladin preview: off (requires the main theme).")
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
	if (enabled) then ns.db.char.legacyHUD = false; ns.db.char.hunterPreview, ns.db.char.magePreview = false, false end -- explicit Paladin choice leaves Hunter and Mage
	ns.db.char.paladinPreview = enabled and true or false
	Engine:Reload()
end

Theme.OnInitialize = function(self)
	self:RegisterChatCommand("azpaladin", "Command")
end

Theme.ProfileChanged = Engine.ProfileChanged

Theme.OnEnable = function(self)
	-- Chosen at load; a profile switching it on or off reloads (ThemeEngine.lua).
	Engine:WatchProfile(self)
	if (self.loadedActive) then
		Engine:StyleOptionsKit(path("border-tooltip"), path("border-aura"), path("options-casing-round"), path("options-well-round"))
	end
end
