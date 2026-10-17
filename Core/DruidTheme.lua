-- Roots beneath the Moon. Native layouts/fills stay unchanged; effects lend
-- their material to other themes through Lite+ without lending the root cap.
local Addon, ns = ...
local Engine = ns.ThemeEngine
local Theme = ns:NewModule("DruidTheme", "LibMoreEvents-1.0")
ns.DruidTheme = Theme
Engine:Register(Theme, 40)
local path = Engine:MediaPath("Druid")
local media = {}
for _, name in ipairs({
	"hp_cap_case", "hp_mid_case", "hp_low_case", "hp_boss_case", "hp_critter_case", "hp_critter_case_hi",
	"cast_back", "cast_back_spiked", "cast_back_wooden", "pw_crystal_case", "pw_crystal_case_low",
	"orb_case_hi", "orb_case_low", "orb-border", "portrait_frame_hi", "portrait_frame_lo",
	"party_portrait_border", "actionbutton-border", "actionbutton-border-square", "actionbutton-border-square-rounded",
	"minimap-border", "point_plate", "config_button", "config_button_bright", "icon_exit_flight",
	"border-tooltip", "border-aura", "better-blizzard-border-small-alternate"
}) do media[name] = true end
Theme.Media = media
local healthBars = setmetatable({}, { __mode = "k" })
local castBars = setmetatable({}, { __mode = "k" })
local healthDips = { hp_cap_case = {750/1024,187/256}, hp_mid_case = {758.5/1024,181/256},
	hp_low_case = {758.5/1024,181/256}, hp_boss_case = {869/1024,188/256} }
local healthSettings = Engine:NewEndcapSettings({ prefix = "druid", choices = { antler = true, bear = true, owl = true, none = true },
	default = "antler", clearDefault = true,
	defaultScale = 1.3,
	refresh = function() Theme:RefreshEndcaps() end })
healthSettings.Install(Theme)
local castSettings = Engine:NewEndcapSettings({ prefix = "druidCast", name = "CastEndcap",
	choices = { moon = true, none = true }, default = "moon", clearDefault = true,
	refresh = function() Theme:RefreshEndcaps() end })
castSettings.Install(Theme)

Theme.IsActive = function(self)
	if (not ns.db or not ns.db.char or not ns.db.char.druidPreview or not Engine:IsMainLayout()) then return false end
	for _, theme in pairs({ hunter = ns.HunterTheme, mage = ns.MageTheme, paladin = ns.PaladinTheme }) do
		if (theme:IsActive()) then return false end
	end
	return true
end
Theme.ResolveMedia = function(self, name) if (self:IsActive() and media[name]) then return path(name) end end
Theme.ResolveOwnMedia = function(self, name) if (media[name]) then return path(name) end end
Theme.ResolvePath = function(self, original) return self:ResolveMedia(Engine.AssetName(original)) or original end
local CachedConfig = Engine:NewConfigCache(function(_, original)
	local config = Engine:CopyLayout(original)
	Engine:ReplaceMedia(config, { resolve = function(name) return Theme:ResolveMedia(name) end })
	return config
end)
Theme.GetConfig = function(self, name, original)
	if (not self:IsActive()) then return original end
	return CachedConfig(name, original)
end

local ArtFrame = function(owner, key, level)
	local frame = owner[key]
	if (not frame) then
		frame = CreateFrame("Frame", nil, owner)
		frame:SetAllPoints(owner)
		frame:EnableMouse(false)
		frame.Art = frame:CreateTexture(nil, "ARTWORK")
		owner[key] = frame
	end
	frame:SetFrameLevel(owner:GetFrameLevel() + level)
	return frame
end
local Rails = function(bar, texture, flip, anchor)
	local name = type(texture) == "string" and texture:match("[\\/]Druid[\\/]([^\\/]+)%.tga$")
	if (not name or not media[name] or not anchor) then return end
	local frame = ArtFrame(bar, anchor == bar.Shield and "DruidShieldRails" or "DruidRails", 1)
	frame.Art:SetTexture(path(name.."-over"))
	frame.Art:SetAllPoints(anchor)
	frame.Art:SetTexCoord(flip and 1 or 0, flip and 0 or 1, 0, 1)
	frame:SetShown(anchor:IsShown())
	if (not frame.visibilityHooked) then
		frame.visibilityHooked = true
		hooksecurefunc(anchor, "Show", function() frame:Show() end)
		hooksecurefunc(anchor, "Hide", function() frame:Hide() end)
		hooksecurefunc(anchor, "SetShown", function(_, shown) frame:SetShown(shown) end)
	end
end
local HealthEndcap = function(bar, flip)
	local assembly = bar.ThemeEndcapAssembly
	local name = assembly and assembly.name
	local enabled = healthSettings.GetKey() ~= "none" and healthDips[name] ~= nil
	-- Both states use the same complete casing; the cap covers its existing dip.
	Engine:SetEndcapTerminal(bar, false)
	local frame = ArtFrame(bar, "DruidEndcap", 4)
	frame.EndcapShown = enabled
	frame:SetShown(enabled)
	if (frame.Threat) then frame.Threat:SetShown(enabled and frame.ThreatSource:IsShown()) end
	if (not enabled) then return end
	local dx, dy = healthSettings.GetOffset()
	local art = "ornament-"..healthSettings.GetKey().."-"..name
	frame.Art:SetTexture(path(art))
	Engine:PlaceAlignedHealthEndcap(frame.Art, bar.Backdrop, healthDips[name], flip,
		healthSettings.GetScale()/1.3, dx, dy)
	if (frame.Threat) then
		frame.Threat:SetTexture(path(art.."-glow"))
		frame.Threat:SetTexCoord(flip and 1 or 0, flip and 0 or 1, 0, 1)
	end
end
Theme.StyleHealth = function(self, owner, db, flip)
	if (not self:IsActive() or not owner.Health or not db) then return end
	local bar = owner.Health
	Rails(bar, db.HealthBackdropTexture, flip, bar.Backdrop)
	local compact = type(db.HealthBarTexture) ~= "string" or db.HealthBarTexture:find("cast_bar", 1, true)
		or bar:GetWidth() < bar:GetHeight()*2
	bar.ThemeEndcapAssembly = nil
	if (compact) then
		healthBars[bar] = nil
		if (bar.DruidEndcap) then bar.DruidEndcap:Hide() end
		if (bar.DruidEndcap) then bar.DruidEndcap.EndcapShown = false end
		if (bar.DruidEndcap and bar.DruidEndcap.Threat) then bar.DruidEndcap.Threat:Hide() end
		return
	end
	local name = type(db.HealthBackdropTexture) == "string" and
		(db.HealthBackdropTexture:match("[\\/]Druid[\\/]([^\\/]+)%.tga$") or Engine.AssetName(db.HealthBackdropTexture))
	if (name and media[name] and bar.Backdrop) then
		bar.ThemeEndcapAssembly = { name = name, path = path, back = bar.Backdrop,
			front = bar.DruidRails and bar.DruidRails.Art, glow = name.."-glow", threat = bar.DruidThreat,
			bareThreat = path(name.."-glow") }
	end
	healthBars[bar] = flip and true or false
	HealthEndcap(bar, flip)
end
Theme.StyleCastbar = function(self, cast)
	if (not self:IsActive()) then return end
	Rails(cast, path("cast_back"), false, cast.Backdrop)
	if (cast.Shield) then Rails(cast, path("cast_back_spiked"), false, cast.Shield) end
	if (cast.Backdrop and cast.Shield and not cast.DruidShieldHooked) then
		cast.DruidShieldHooked = true
		hooksecurefunc(cast.Backdrop, "Show", function() cast.Shield:Hide() end)
		hooksecurefunc(cast.Backdrop, "Hide", function() cast.Shield:Show() end)
		hooksecurefunc(cast.Backdrop, "SetShown", function(_, shown) cast.Shield:SetShown(not shown) end)
	end
	if (cast.Backdrop and cast.Shield) then cast.Shield:SetShown(not cast.Backdrop:IsShown()) end
	castBars[cast] = true
	Engine:SetCastEndcapTerminal(cast, path, castSettings.GetKey() ~= "none",
		cast.DruidRails and cast.DruidRails.Art, cast.DruidShieldRails and cast.DruidShieldRails.Art)
	local slot = Engine.FittedCastSlot
	local frame = ArtFrame(cast, "DruidCastHead", 3)
	frame:SetShown(castSettings.GetKey() ~= "none")
	if (castSettings.GetKey() == "none") then return end
	local dx, dy = castSettings.GetOffset()
	frame.Art:SetTexture(path("cast-head-fitted"))
	frame.Art:ClearAllPoints()
	frame.Art:SetSize(slot.size*castSettings.GetScale(), slot.size*castSettings.GetScale())
	frame.Art:SetPoint("CENTER", cast, "LEFT", slot.x - dx, slot.y + dy)
	if (not frame.Light) then frame.Light = frame:CreateTexture(nil, "OVERLAY") end
	frame.Light:SetAllPoints(frame.Art)
	frame.Light:SetTexture(path("cast-head-fitted-light"))
	frame.Light:SetVertexColor(.59, .75, 1)
	frame.Light:SetBlendMode("ADD")
end
Theme.RefreshEndcaps = function(self)
	if (not self:IsActive()) then return end
	for bar, flip in pairs(healthBars) do HealthEndcap(bar, flip) end
	for cast in pairs(castBars) do self:StyleCastbar(cast) end
	if (ns.ThemeBarPreview) then ns.ThemeBarPreview:Refresh() end
end
Theme.StyleCrystal = function(self, power, useMage)
	if (not self:IsActive() or useMage) then
		if (power.DruidRootFront) then
			power.DruidRootFront:Hide(); power.DruidRootBack:Hide()
			power.Case:SetAlpha(1)
		end
		return
	end
	if (not power.Case) then return end
	if (not power.DruidRootBack) then
		power.DruidRootBack = power:CreateTexture(nil, "BACKGROUND", nil, -1)
		power.DruidRootBack:SetTexture(path("crystal-roots-back"))
		power.DruidRootBack:SetAllPoints(power)
	end
	local frame = ArtFrame(power, "DruidRootFront", 2)
	local owner = power:GetParent()
	if (owner and owner.Health) then frame:SetFrameLevel(math.max(frame:GetFrameLevel(), owner.Health:GetFrameLevel()+5)) end
	frame.Art:SetAllPoints(power)
	frame.Art:SetTexture(path("crystal-roots-front"))
	power.Case:SetAlpha(0)
	power.DruidRootBack:Show(); frame:Show()
end
Theme.StyleUtilityButton = function(self, button)
	if (not self:IsActive()) then return end
	button.Texture:SetTexture(path("config_button")); button.Texture:SetVertexColor(1, 1, 1)
	button.Highlight:SetTexture(path("config_button_bright")); button.Highlight:SetVertexColor(1, 1, 1)
end
Theme.StyleCompass = function(self, compass)
	if (not self:IsActive() or not compass or not compass.north) then return end
	local art = compass.DruidNorth
	if (not art) then art = compass:CreateTexture(nil, "BACKGROUND"); compass.DruidNorth = art end
	art:SetTexture(path("minimap-north"))
	art:SetSize(Engine.OrnamentSlots.North.size, Engine.OrnamentSlots.North.size)
	art:SetPoint("CENTER", compass.north, "CENTER", 0, 0)
end
Theme.StyleThreat = function(self, owner, flip)
	if (not self:IsActive() or not owner.ThreatIndicator) then return end
	local textures = owner.ThreatIndicator.textures
	if (not textures) then return end
	local power = owner.Power
	if (textures.PowerBar and power and ns.ThemeEffects:GetCrystalEffect() ~= "mage") then
		textures.PowerBar:SetTexture(path("crystal-assembly-glow"))
		textures.PowerBar:ClearAllPoints(); textures.PowerBar:SetAllPoints(power)
		if (textures.PowerBackdrop) then textures.PowerBackdrop:SetAlpha(0) end
	end
	local portrait = owner.Portrait and owner.Portrait.Border
	if (textures.Portrait and portrait) then
		local name = portrait:GetTexture()
		name = type(name) == "string" and name:match("[\\/]Druid[\\/](portrait_frame_[^\\/]+)%.tga$")
		if (name) then
			textures.Portrait:SetTexture(path(name.."-glow"))
			textures.Portrait:ClearAllPoints(); textures.Portrait:SetAllPoints(portrait)
		end
	end
	local frame = owner.Health and owner.Health.DruidEndcap
	local native = textures.Health
	if (native and owner.Health.ThemeEndcapAssembly) then
		local bar = owner.Health
		bar.DruidThreat = native
		bar.DruidBareThreat = path(bar.ThemeEndcapAssembly.name.."-glow")
		bar.ThemeEndcapAssembly.threat = native
		bar.ThemeEndcapAssembly.bareThreat = bar.DruidBareThreat
		native:ClearAllPoints(); native:SetAllPoints(bar.Backdrop)
		native:SetTexCoord(flip and 1 or 0, flip and 0 or 1, 0, 1)
		Engine:SetEndcapTerminal(bar, false)
	end
	if (not frame or not native or not owner.Health.ThemeEndcapAssembly) then return end
	local key = healthSettings.GetKey()
	local art = "ornament-"..(key == "none" and "antler" or key).."-"..owner.Health.ThemeEndcapAssembly.name
	Engine:StyleEndcapThreat(frame, frame.Art, native, path(art.."-glow"), flip)
end

-- Effect animation uses elapsed time only. The engine owns the resource clip;
-- no value/min/max/percent is queried, compared or calculated here.
local active = setmetatable({}, { __mode = "k" })
local Strength = function(kind)
	local value = ns.db and ns.db.char and tonumber(ns.db.char["druid"..kind.."Strength"])
	if (not value or value ~= value) then return 1 end
	return math.max(0, math.min(1, value))
end
Theme.GetEffectStrength = function(self, kind) return Strength(kind) end
Theme.SetEffectStrength = function(self, kind, value)
	value = tonumber(value)
	if ((kind ~= "Crystal" and kind ~= "Orb") or not value or value ~= value or InCombatLockdown()) then return false end
	value = math.max(0, math.min(1, value))
	ns.db.char["druid"..kind.."Strength"] = value ~= 1 and value or nil
	return ns.ThemeEffects:Refresh()
end
local Update = function(frame, elapsed)
	frame.Time = ((frame.Time or 0) + elapsed)%24
	local phase = frame.Time*math.pi/12
	for i, art in ipairs(frame.Wisps) do
		local x = .04 + .03*math.sin(phase+i*2)
		local y = .04 + .03*math.cos(phase+i*2)
		art:SetTexCoord(x, x+.90, y, y+.90)
		art:SetAlpha(.22 + .12*math.sin(phase+i*math.pi))
	end
end
local Flow = function(frame, anchor, maskPath, kind)
	local mask = frame:CreateMaskTexture()
	mask:SetAllPoints(anchor)
	mask:SetTexture(maskPath, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
	frame.Mask, frame.Wisps, frame.Kind = mask, {}, kind
	for i = 1, 2 do
		local art = frame:CreateTexture(nil, "ARTWORK", nil, i)
		art:SetAllPoints(anchor)
		art:SetTexture(path(kind == "Orb" and "orb-moonwell" or "dreamlight"))
		art:SetBlendMode("ADD")
		art:SetVertexColor(unpack(i == 1 and { .65, .82, 1 } or { .28, .8, .48 }))
		art:AddMaskTexture(mask)
		frame.Wisps[i] = art
	end
end
local Show = function(frame)
	active[frame] = true
	if (frame.Clip) then frame.Clip:Show() end
	frame:SetAlpha(Strength(frame.Kind))
	frame:Show()
	frame:SetScript("OnUpdate", Update)
	Update(frame, 0)
end
local Hide = function(frame)
	if (not frame) then return end
	active[frame] = nil
	frame:SetScript("OnUpdate", nil)
	frame:Hide()
	if (frame.Clip) then frame.Clip:Hide() end
end
Theme.ClearCrystalEffect = function(self, power) Hide(power.DruidDreamlight) end
Theme.ClearOrbEffect = function(self, orb) Hide(orb.DruidMoonwell) end
Theme.ApplyCrystalEffect = function(self, power, texturePath)
	if (Strength("Crystal") == 0) then self:ClearCrystalEffect(power); return end
	local frame = power.DruidDreamlight
	if (not frame) then
		local clip = CreateFrame("Frame", nil, power)
		clip:EnableMouse(false); clip:SetClipsChildren(true)
		clip:SetFrameLevel(power:GetFrameLevel()+1)
		clip:SetPoint("BOTTOMLEFT", power, "BOTTOMLEFT")
		clip:SetPoint("BOTTOMRIGHT", power, "BOTTOMRIGHT")
		clip:SetPoint("TOP", power:GetStatusBarTexture(), "TOP")
		frame = CreateFrame("Frame", nil, clip)
		frame:EnableMouse(false); frame:SetAllPoints(power); frame.Clip = clip
		Flow(frame, power, texturePath, "Crystal")
		power.DruidDreamlight = frame
	end
	frame.Mask:SetTexture(texturePath, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
	Show(frame)
end
Theme.ApplyOrbEffect = function(self, orb)
	if (Strength("Orb") == 0) then self:ClearOrbEffect(orb); return false end
	-- Same native LibOrb material route as Hunter's hexagons. Its two existing
	-- rotating/crossfading fill layers now carry the water, not the stock orb.
	orb:SetStatusBarTexture(path("orb-moonwell"), path("orb-moonwell"))
	local frame = orb.DruidMoonwell
	if (not frame) then
		frame = CreateFrame("Frame", nil, orb:GetOverlay())
		frame:EnableMouse(false); frame:SetAllPoints(orb)
		Flow(frame, orb, "Interface\\AddOns\\"..Addon.."\\Assets\\orb2.tga", "Orb")
		orb.DruidMoonwell = frame
	end
	Show(frame)
	return true
end
Theme.ProfileChanged = Engine.ProfileChanged
Theme.OnEnable = function(self)
	Engine:WatchProfile(self)
	if (self.loadedActive) then Engine:StyleOptionsKit(path("border-tooltip"), path("border-aura")) end
end
