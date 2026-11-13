-- Warlock: approved class concept, complete native-layout theme (WIP).
-- Native layouts, fills and saved anchors stay owned by the layout.
local _, ns = ...
local Engine, Data = ns.ThemeEngine, ns.WarlockThemeData
if (not Engine or not Data) then return end
local Theme = ns:NewModule("WarlockTheme", "AceConsole-3.0", "LibMoreEvents-1.0")
ns.WarlockTheme = Theme
Engine:Register(Theme, 100)
local path = Engine:MediaPath("Warlock")
local media = Data.media
Theme.Media = media
local fronts = { hp_cap_case = true, hp_mid_case = true, hp_low_case = true, hp_boss_case = true,
	cast_back = true, cast_back_spiked = true, cast_back_wooden = true }
local dips = Data.dips
local healthBars = setmetatable({}, { __mode = "k" })
local castBars = setmetatable({}, { __mode = "k" })
local healthSettings = Engine:NewEndcapSettings({ prefix = "warlock",
	choices = { ulthalesh = true, none = true }, default = "ulthalesh", clearDefault = true,
	defaultScale = 1.3, refresh = function() Theme:RefreshEndcaps() end })
healthSettings.Install(Theme)
local castSettings = Engine:NewEndcapSettings({ prefix = "warlockCast", name = "CastEndcap",
	choices = { thalkiel = true, none = true }, default = "thalkiel", clearDefault = true,
	refresh = function() Theme:RefreshEndcaps() end })
castSettings.Install(Theme)

Theme.IsActive = function(self)
	if (not ns.db or not ns.db.char or not ns.db.char.warlockPreview or not Engine:IsMainLayout()) then return false end
	for _, key in ipairs({ "Hunter", "Mage", "Paladin", "Druid", "Warrior", "Rogue", "Shaman", "DeathKnight", "Priest" }) do
		local theme = ns[key.."Theme"]
		if (theme and theme:IsActive()) then return false end
	end
	return true
end
Theme.ResolveMedia = function(self, name) if (self:IsActive() and media[name]) then return path(name) end end
Theme.ResolveOwnMedia = function(self, name) if (media[name]) then return path(name) end end
Theme.ResolvePath = function(self, original) return self:ResolveMedia(Engine.AssetName(original)) or original end
local CachedConfig = Engine:NewConfigCache(function(_, original)
	local config = Engine:CopyLayout(original)
	Engine:ReplaceMedia(config, {
		resolve = function(name) return Theme:ResolveMedia(name) end,
		-- The native grey keeps repeated button rims quieter than HUD fittings.
		keepTint = function(name) return name and name:match("^actionbutton%-border") ~= nil end
	})
	if (config.ClassPowerCaseColor) then
		config.ClassPowerCaseColor = { 1, 1, 1, config.ClassPowerCaseColor[4] or 1 }
	end
	return config
end)
Theme.GetConfig = function(self, name, original)
	if (not self:IsActive()) then return original end
	return CachedConfig(name, original)
end

local AssetName = function(texture)
	return type(texture) == "string" and
		(texture:match("[\\/]Warlock[\\/]([^\\/]+)%.tga$") or Engine.AssetName(texture)) or nil
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
local Rails = function(bar, name, flip, anchor, key)
	if (not anchor or not fronts[name]) then
		if (bar[key]) then bar[key]:Hide() end
		return
	end
	local frame = ArtFrame(bar, key, 1)
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
-- Measured WIP source bounds; no production/visual acceptance is implied.
local capTextEdges = Data.edges
local HealthEndcap = function(bar, flip)
	local frame = ArtFrame(bar, "WarlockEndcap", 4)
	local dx, dy = healthSettings.GetOffset()
	Engine:StyleAlignedHealthEndcap(frame, frame.Art, bar, path, healthSettings.GetKey(), dips,
		flip, healthSettings.GetScale(), dx, dy, capTextEdges)
end
Theme.StyleHealth = function(self, owner, db, flip)
	if (not self:IsActive() or not owner or not owner.Health or not db) then return end
	local bar, name = owner.Health, AssetName(db.HealthBackdropTexture)
	bar.ThemeTextOwner, bar.ThemeTextLayout = owner, db
	Rails(bar, name, flip, bar.Backdrop, "WarlockRails")
	local longCase = dips[name] and bar.Backdrop and bar:GetWidth() >= bar:GetHeight()*2
	bar.ThemeEndcapAssembly = longCase and { name = name, path = path, back = bar.Backdrop,
		front = bar.WarlockRails.Art, glow = name.."-glow", threat = bar.WarlockThreat, bareThreat = path(name.."-glow") } or nil
	if (not longCase) then
		Engine:PlaceHealthPercent(bar, flip, false)
		healthBars[bar] = nil
		if (bar.WarlockEndcap) then
			bar.WarlockEndcap.EndcapShown = false
			bar.WarlockEndcap:Hide()
			if (bar.WarlockEndcap.Threat) then bar.WarlockEndcap.Threat:Hide() end
		end
		return
	end
	healthBars[bar] = flip and true or false
	HealthEndcap(bar, flip)
end
Theme.StyleCastbar = function(self, cast)
	if (not self:IsActive() or not cast) then return end
	Rails(cast, "cast_back", false, cast.Backdrop, "WarlockRails")
	Rails(cast, "cast_back_spiked", false, cast.Shield, "WarlockShieldRails")
	-- Our foreground follows the native shield/backdrop choice; neither casing
	-- is cut away for the separate head, including None and protected casts.
	if (cast.Backdrop and cast.Shield and not cast.WarlockShieldHooked) then
		cast.WarlockShieldHooked = true
		hooksecurefunc(cast.Backdrop, "Show", function() cast.Shield:Hide() end)
		hooksecurefunc(cast.Backdrop, "Hide", function() cast.Shield:Show() end)
		hooksecurefunc(cast.Backdrop, "SetShown", function(_, shown) cast.Shield:SetShown(not shown) end)
	end
	if (cast.Backdrop and cast.Shield) then cast.Shield:SetShown(not cast.Backdrop:IsShown()) end
	castBars[cast] = true
	local frame = ArtFrame(cast, "WarlockCastHead", 3)
	frame:SetShown(castSettings.GetKey() ~= "none")
	if (castSettings.GetKey() == "none") then return end
	local slot = Engine.FittedCastSlot
	local size = slot.size*castSettings.GetScale()
	local dx, dy = castSettings.GetOffset()
	frame.Art:SetTexture(path("cast-head"))
	frame.Art:ClearAllPoints()
	frame.Art:SetSize(size, size)
	frame.Art:SetPoint("CENTER", cast, "LEFT", slot.x - dx, slot.y + dy)
end
Theme.RefreshEndcaps = function(self)
	if (not self:IsActive()) then return end
	for bar, flip in pairs(healthBars) do HealthEndcap(bar, flip) end
	for cast in pairs(castBars) do self:StyleCastbar(cast) end
	if (ns.ThemeBarPreview) then ns.ThemeBarPreview:Refresh() end
end
Theme.StyleThreat = function(self, owner, flip)
	if (not self:IsActive() or not owner or not owner.ThreatIndicator) then return end
	local textures = owner.ThreatIndicator.textures
	if (not textures) then return end
	local bar = owner.Health
	local native = textures.Health
	if (native and bar and bar.ThemeEndcapAssembly) then
		bar.WarlockThreat = native
		bar.ThemeEndcapAssembly.threat = native
		native:ClearAllPoints(); native:SetAllPoints(bar.Backdrop)
		native:SetTexCoord(flip and 1 or 0, flip and 0 or 1, 0, 1)
		Engine:SetEndcapTerminal(bar, false)
		local frame = bar.WarlockEndcap
		if (frame) then
			local key = healthSettings.GetKey()
			local art = "ornament-"..(key == "none" and "ulthalesh" or key).."-"..bar.ThemeEndcapAssembly.name.."-glow"
			Engine:StyleEndcapThreat(frame, frame.Art, native, path(art), flip)
		end
	end
end
Theme.StyleUtilityButton = function(self, button)
	if (not self:IsActive() or not button or not button.Texture or not button.Highlight) then return end
	button.Texture:SetTexture(path("config_button")); button.Texture:SetVertexColor(1, 1, 1)
	button.Highlight:SetTexture(path("config_button_bright")); button.Highlight:SetVertexColor(1, 1, 1)
end
-- The resource badge belongs to the crystal; the orb's liquid stays clear.
local ResourceBadge = function(element)
	if (not element) then return end
	local frame = element.WarlockBadge
	if (not Theme:IsActive() or not element.Case) then
		if (frame) then frame:Hide() end
		return
	end
	frame = ArtFrame(element, "WarlockBadge", 6)
	local holder = element.Case:GetParent()
	if (holder and holder.GetFrameLevel) then
		frame:SetFrameLevel(math.max(element:GetFrameLevel() + 6, holder:GetFrameLevel() + 1))
	end
	local slot = Engine.OrnamentSlots.ResourceBadge
	frame.Art:SetTexture(path("resource-badge"))
	frame.Art:ClearAllPoints()
	frame.Art:SetSize(slot.size, slot.size)
	frame.Art:SetPoint("CENTER", element.Case, "CENTER", 0, -element.Case:GetHeight()*slot.yFraction)
	frame:Show()
end
Theme.StyleCrystal = function(self, power) ResourceBadge(power) end
Theme.StyleOrb = function(self, orb)
	if (orb and orb.WarlockBadge) then orb.WarlockBadge:Hide() end
end
Theme.StyleCompass = function(self, compass)
	if (not self:IsActive() or not compass or not compass.north) then return end
	local art = compass.WarlockNorth
	if (not art) then
		art = compass:CreateTexture(nil, "OVERLAY")
		compass.WarlockNorth = art
	end
	art:SetTexture(path("minimap-north"))
	local size = Engine.OrnamentSlots.North.size
	art:SetSize(size, size)
	art:SetPoint("CENTER", compass.north, "CENTER", 0, 0)
	compass.north:SetAlpha(0)
end
Theme.Command = function(self, input)
	local command, option = (input or ""):lower():match("^%s*(%S*)%s*(%S*)%s*$")
	if (command == "status") then
		self:Print((self:IsActive() and "Warlock theme: on" or "Warlock theme: off").."; endcap: "..self:GetEndcap())
		return true
	end
	if (command == "preview" and ns.ThemeBarPreview) then ns.ThemeBarPreview:Show(); return true end
	if (command == "endcap" or command == "castendcap") then
		if (not ns.db or not ns.db.char) then return false end
		local settings = command == "endcap" and healthSettings or castSettings
		if (settings.SetKey(option)) then return true end
		self:Print("/azwarlock endcap [ulthalesh|none]; /azwarlock castendcap [thalkiel|none] (outside combat)")
		return false
	end
	if (command ~= "" and command ~= "on" and command ~= "off" and command ~= "toggle") then
		self:Print("/azwarlock [on|off|toggle|status|preview]; /azwarlock endcap <name>; /azwarlock castendcap <name>")
		return false
	end
	if (InCombatLockdown()) then self:Print("Change the Warlock theme outside combat."); return false end
	if (command == "off" and not self:IsActive()) then return true end
	local effects = ns.ThemeEffects
	if (not effects) then return false end
	local enabling = command == "on" or ((command == "" or command == "toggle") and not self:IsActive())
	return effects:SetTheme(enabling and "warlock" or "azerite")
end
Theme.OnInitialize = function(self) self:RegisterChatCommand("azwarlock", "Command") end
Theme.ProfileChanged = Engine.ProfileChanged
Theme.OnEnable = function(self)
	Engine:WatchProfile(self)
	if (self.loadedActive) then Engine:StyleOptionsKit(path("border-tooltip"), path("border-aura")) end
end
