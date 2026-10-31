-- Shaman - Storm, Stone & Tides. Measured painted assets on native rectangles;
-- fills, prediction, hit areas and saved frame anchors stay owned by the layout.
local _, ns = ...
local Engine = ns.ThemeEngine
local Theme = ns:NewModule("ShamanTheme", "AceConsole-3.0", "LibMoreEvents-1.0")
ns.ShamanTheme = Theme
Engine:Register(Theme, 70)
local path = Engine:MediaPath("Shaman")
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
local fronts = { hp_cap_case = true, hp_mid_case = true, hp_low_case = true, hp_boss_case = true,
	hp_critter_case = true, hp_critter_case_hi = true, cast_back = true, cast_back_spiked = true, cast_back_wooden = true }
local dips = { hp_cap_case = {754/1024,187/256}, hp_mid_case = {757/1024,181/256},
	hp_low_case = {756.5/1024,181/256}, hp_boss_case = {872.5/1024,188/256} }
local healthBars = setmetatable({}, { __mode = "k" })
local castBars = setmetatable({}, { __mode = "k" })
local healthSettings = Engine:NewEndcapSettings({ prefix = "shaman",
	choices = { maelstrom = true, tides = true, lava = true, none = true }, default = "maelstrom", clearDefault = true,
	defaultScale = 1.3, refresh = function() Theme:RefreshEndcaps() end })
healthSettings.Install(Theme)
local castSettings = Engine:NewEndcapSettings({ prefix = "shamanCast", name = "CastEndcap",
	choices = { totem = true, none = true }, default = "totem", clearDefault = true,
	refresh = function() Theme:RefreshEndcaps() end })
castSettings.Install(Theme)

Theme.IsActive = function(self)
	if (not ns.db or not ns.db.char or not ns.db.char.shamanPreview or not Engine:IsMainLayout()) then return false end
	for _, key in ipairs({ "Hunter", "Mage", "Paladin", "Druid", "Warrior", "Rogue" }) do
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
		(texture:match("[\\/]Shaman[\\/]([^\\/]+)%.tga$") or Engine.AssetName(texture)) or nil
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
-- Leftmost painted bounds from the accepted four-tier exports, in source pixels.
-- Reserve the full mounting body, including its leather/rivets, for health text.
local capTextEdges = {
	maelstrom = { hp_cap_case = 699, hp_mid_case = 704, hp_low_case = 706, hp_boss_case = 818 },
	tides = { hp_cap_case = 692, hp_mid_case = 702, hp_low_case = 702, hp_boss_case = 813 },
	lava = { hp_cap_case = 692, hp_mid_case = 702, hp_low_case = 702, hp_boss_case = 813 }
}
local HealthEndcap = function(bar, flip)
	local frame = ArtFrame(bar, "ShamanEndcap", 4)
	local dx, dy = healthSettings.GetOffset()
	Engine:StyleAlignedHealthEndcap(frame, frame.Art, bar, path, healthSettings.GetKey(), dips,
		flip, healthSettings.GetScale(), dx, dy, capTextEdges)
end
Theme.StyleHealth = function(self, owner, db, flip)
	if (not self:IsActive() or not owner or not owner.Health or not db) then return end
	local bar, name = owner.Health, AssetName(db.HealthBackdropTexture)
	bar.ThemeTextOwner, bar.ThemeTextLayout = owner, db
	Rails(bar, name, flip, bar.Backdrop, "ShamanRails")
	local longCase = dips[name] and bar.Backdrop and bar:GetWidth() >= bar:GetHeight()*2
	bar.ThemeEndcapAssembly = longCase and { name = name, path = path, back = bar.Backdrop,
		front = bar.ShamanRails.Art, glow = name.."-glow", threat = bar.ShamanThreat, bareThreat = path(name.."-glow") } or nil
	if (not longCase) then
		Engine:PlaceHealthPercent(bar, flip, false)
		healthBars[bar] = nil
		if (bar.ShamanEndcap) then
			bar.ShamanEndcap.EndcapShown = false
			bar.ShamanEndcap:Hide()
			if (bar.ShamanEndcap.Threat) then bar.ShamanEndcap.Threat:Hide() end
		end
		return
	end
	healthBars[bar] = flip and true or false
	HealthEndcap(bar, flip)
end
Theme.StyleCastbar = function(self, cast)
	if (not self:IsActive() or not cast) then return end
	Rails(cast, "cast_back", false, cast.Backdrop, "ShamanRails")
	Rails(cast, "cast_back_spiked", false, cast.Shield, "ShamanShieldRails")
	-- Our foreground follows the native shield/backdrop choice; neither casing
	-- is cut away for the separate head, including None and protected casts.
	if (cast.Backdrop and cast.Shield and not cast.ShamanShieldHooked) then
		cast.ShamanShieldHooked = true
		hooksecurefunc(cast.Backdrop, "Show", function() cast.Shield:Hide() end)
		hooksecurefunc(cast.Backdrop, "Hide", function() cast.Shield:Show() end)
		hooksecurefunc(cast.Backdrop, "SetShown", function(_, shown) cast.Shield:SetShown(not shown) end)
	end
	if (cast.Backdrop and cast.Shield) then cast.Shield:SetShown(not cast.Backdrop:IsShown()) end
	castBars[cast] = true
	local frame = ArtFrame(cast, "ShamanCastHead", 3)
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
		bar.ShamanThreat = native
		bar.ThemeEndcapAssembly.threat = native
		native:ClearAllPoints(); native:SetAllPoints(bar.Backdrop)
		native:SetTexCoord(flip and 1 or 0, flip and 0 or 1, 0, 1)
		Engine:SetEndcapTerminal(bar, false)
		local frame = bar.ShamanEndcap
		if (frame) then
			local key = healthSettings.GetKey()
			local art = "ornament-"..(key == "none" and "maelstrom" or key).."-"..bar.ThemeEndcapAssembly.name.."-glow"
			Engine:StyleEndcapThreat(frame, frame.Art, native, path(art), flip)
		end
	end
	local power = owner.Power
	local case = power and power.Case and AssetName(power.Case:GetTexture())
	local shamanCrystal = case == "pw_crystal_case" or case == "pw_crystal_case_low"
	if (textures.PowerBackdrop) then textures.PowerBackdrop:SetAlpha(shamanCrystal and 0 or 1) end
	if (textures.PowerBar and shamanCrystal and power.Backdrop) then
		local back = power.Backdrop:GetTexture()
		local ice = type(back) == "string" and back:find("ice", 1, true)
		textures.PowerBar:SetTexture(path("crystal-assembly"..(case == "pw_crystal_case_low" and "-low" or "")..(ice and "-wrath" or "").."-glow"))
		textures.PowerBar:ClearAllPoints()
		textures.PowerBar:SetSize(power.Backdrop:GetWidth()*2, power.Backdrop:GetHeight()*2)
		textures.PowerBar:SetPoint("CENTER", power.Backdrop, "CENTER", 0, 0)
		textures.PowerBar:SetTexCoord(0, 1, 0, 1)
	end
	local orb = owner.ManaOrb
	if (textures.ManaOrb and orb and orb.Case) then
		local name = AssetName(orb.Case:GetTexture())
		if (name == "orb_case_hi" or name == "orb_case_low") then
			textures.ManaOrb:SetTexture(path(name.."-glow"))
			textures.ManaOrb:ClearAllPoints(); textures.ManaOrb:SetAllPoints(orb.Case)
		end
	end
	local portrait = owner.Portrait and owner.Portrait.Border
	if (textures.Portrait and portrait) then
		local name = AssetName(portrait:GetTexture())
		if (name == "portrait_frame_hi" or name == "portrait_frame_lo") then
			textures.Portrait:SetTexture(path(name.."-glow"))
			textures.Portrait:ClearAllPoints(); textures.Portrait:SetAllPoints(portrait)
		end
	end
end
Theme.StyleUtilityButton = function(self, button)
	if (not self:IsActive() or not button) then return end
	button.Texture:SetTexture(path("config_button")); button.Texture:SetVertexColor(1, 1, 1)
	button.Highlight:SetTexture(path("config_button_bright")); button.Highlight:SetVertexColor(1, 1, 1)
end
Theme.Command = function(self, input)
	local command, option = (input or ""):lower():match("^%s*(%S*)%s*(%S*)%s*$")
	if (command == "status") then
		self:Print((self:IsActive() and "Shaman theme: on" or "Shaman theme: off").."; endcap: "..self:GetEndcap())
		return true
	end
	if (command == "preview" and ns.ThemeBarPreview) then ns.ThemeBarPreview:Show(); return true end
	if (command == "endcap" or command == "castendcap") then
		if (not ns.db or not ns.db.char) then return false end
		local settings = command == "endcap" and healthSettings or castSettings
		if (settings.SetKey(option)) then return true end
		self:Print("/azshaman endcap [maelstrom|tides|lava|none]; /azshaman castendcap [totem|none] (outside combat)")
		return false
	end
	if (command ~= "" and command ~= "on" and command ~= "off" and command ~= "toggle") then
		self:Print("/azshaman [on|off|toggle|status|preview]; /azshaman endcap <name>; /azshaman castendcap <name>")
		return false
	end
	if (InCombatLockdown()) then self:Print("Change the Shaman theme outside combat."); return false end
	if (command == "off" and not self:IsActive()) then return true end
	local effects = ns.ThemeEffects
	if (not effects) then return false end
	local enabling = command == "on" or ((command == "" or command == "toggle") and not self:IsActive())
	return effects:SetTheme(enabling and "shaman" or "azerite")
end
Theme.OnInitialize = function(self) self:RegisterChatCommand("azshaman", "Command") end
Theme.ProfileChanged = Engine.ProfileChanged
Theme.OnEnable = function(self)
	Engine:WatchProfile(self)
	if (self.loadedActive) then Engine:StyleOptionsKit(path("border-tooltip"), path("border-aura")) end
end
