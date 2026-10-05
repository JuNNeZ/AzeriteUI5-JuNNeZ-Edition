-- Which theme is in use, and which effect plays inside the power crystal and
-- the mana orb. Every theme brings its own effects; Lite+ lets the player use
-- another theme's effects instead (the Mage crystal on AzeriteUI's own art is
-- the pack's "originalLite"). Switching themes reloads, as every theme
-- rebuilds the frame layouts; everything else is redrawn at once through the
-- player frame's own UpdateSettings.
local _, ns = ...
local Effects = {}
ns.ThemeEffects = Effects

-- In dropdown order.
local THEMES = { "azerite", "hunter", "paladin", "mage" }
local THEME_CRYSTAL = { azerite = "none", hunter = "none", paladin = "paladin", mage = "mage" }
local THEME_ORB = { azerite = "none", hunter = "hunter", paladin = "paladin", mage = "none" }
local CRYSTAL_EFFECTS = { "none", "paladin", "mage" }
local ORB_EFFECTS = { "none", "paladin", "hunter" }

local Contains = function(list, value)
	for _, entry in ipairs(list) do if (entry == value) then return true end end
	return false
end

local Char = function() return ns.db and ns.db.char end

local DevMode = function()
	return ns.db and ns.db.global and ns.db.global.enableDevelopmentMode and true or false
end

-- Themes draw only over the main AzeriteUI layout, never over SaiyaRatt or a
-- config variant; the theme modules check the same thing.
local MainLayout = function()
	if (ns.IsSaiyaRattProfile and ns:IsSaiyaRattProfile()) then return false end
	local variant = ns.GetActiveConfigVariant and ns:GetActiveConfigVariant()
	return not variant or variant == ""
end

--- True on the main AzeriteUI layout, the only one themes draw over.
Effects.IsMainLayout = function(self) return MainLayout() end

--- Theme keys the dropdown may offer. Paladin is a Development Mode preview.
Effects.GetThemes = function(self)
	local list = {}
	for _, key in ipairs(THEMES) do
		if (key ~= "paladin" or DevMode()) then list[#list + 1] = key end
	end
	return list
end

--- The theme in use: "azerite", "hunter", "paladin" or "mage".
Effects.GetTheme = function(self)
	local char = Char()
	if (not char or not MainLayout()) then return "azerite" end
	if (ns.HunterTheme and ns.HunterTheme:IsActive()) then return "hunter" end
	if (ns.MageTheme and ns.MageTheme:IsActive()) then return "mage" end
	if (ns.PaladinTheme and ns.PaladinTheme:IsActive()) then return "paladin" end
	return "azerite"
end

--- True when switching to this theme must rebuild the frame layouts.
Effects.NeedsReload = function(self, theme)
	for key, module in pairs({ hunter = ns.HunterTheme, paladin = ns.PaladinTheme, mage = ns.MageTheme }) do
		if ((module.loadedActive or false) ~= (theme == key)) then return true end
	end
	return false
end

Effects.IsLitePlus = function(self)
	local char = Char()
	return char and char.themeLitePlus == true or false
end

Effects.GetCrystalEffects = function(self) return CRYSTAL_EFFECTS end
Effects.GetOrbEffects = function(self) return ORB_EFFECTS end

--- The Lite+ choice: "theme" (the theme's own) or an effect key.
Effects.GetCrystalChoice = function(self)
	local choice = Char() and Char().themeCrystalEffect
	return Contains(CRYSTAL_EFFECTS, choice) and choice or "theme"
end

Effects.GetOrbChoice = function(self)
	local choice = Char() and Char().themeOrbEffect
	return Contains(ORB_EFFECTS, choice) and choice or "theme"
end

local Resolve = function(own, choice)
	local effect = own
	if (Effects:IsLitePlus() and choice ~= "theme") then effect = choice end
	-- The Paladin art is a Development Mode preview, its effects with it.
	if (effect == "paladin" and not DevMode()) then effect = "none" end
	return effect
end

--- The effect drawn in the power crystal: "none", "paladin" or "mage".
Effects.GetCrystalEffect = function(self)
	if (not Char() or not MainLayout()) then return "none" end
	return Resolve(THEME_CRYSTAL[self:GetTheme()], self:GetCrystalChoice())
end

--- The effect drawn in the mana orb: "none", "paladin" or "hunter".
Effects.GetOrbEffect = function(self)
	if (not Char() or not MainLayout()) then return "none" end
	return Resolve(THEME_ORB[self:GetTheme()], self:GetOrbChoice())
end

--- Redraws the player's crystal and orb. Safe outside combat only.
Effects.Refresh = function(self)
	if (InCombatLockdown()) then return false end
	for _, name in ipairs({ "PlayerFrame", "PlayerFrameAlternate" }) do
		local module = ns:GetModule(name, true)
		if (module and module:IsEnabled() and module.frame and module.UpdateSettings) then
			module:UpdateSettings()
		end
	end
	-- Mage endcaps can follow the crystal's school.
	if (ns.MageTheme) then ns.MageTheme:RefreshOrnaments() end
	if (ns.ThemeBarPreview) then ns.ThemeBarPreview:Refresh() end
	return true
end

--- Switches theme. Reloads only when the frame layouts must be rebuilt.
Effects.SetTheme = function(self, theme)
	local char = Char()
	if (not char or not Contains(self:GetThemes(), theme) or InCombatLockdown()) then return false end
	if (theme ~= "azerite" and not MainLayout()) then
		ns:Print("Select the main AzeriteUI theme before choosing another.")
		return false
	end
	char.hunterPreview = theme == "hunter"
	char.paladinPreview = theme == "paladin"
	char.magePreview = theme == "mage"
	if (self:NeedsReload(theme)) then
		ReloadUI()
		return true
	end
	return self:Refresh()
end

Effects.SetLitePlus = function(self, enabled)
	local char = Char()
	if (not char or InCombatLockdown()) then return false end
	char.themeLitePlus = enabled and true or nil
	return self:Refresh()
end

--- With litePlus true, also turns Lite+ on, in the same single redraw.
Effects.SetCrystalChoice = function(self, choice, litePlus)
	local char = Char()
	if (not char or InCombatLockdown()) then return false end
	if (choice ~= "theme" and not Contains(CRYSTAL_EFFECTS, choice)) then return false end
	char.themeCrystalEffect = choice ~= "theme" and choice or nil
	if (litePlus) then char.themeLitePlus = true end
	return self:Refresh()
end

Effects.SetOrbChoice = function(self, choice)
	local char = Char()
	if (not char or InCombatLockdown()) then return false end
	if (choice ~= "theme" and not Contains(ORB_EFFECTS, choice)) then return false end
	char.themeOrbEffect = choice ~= "theme" and choice or nil
	return self:Refresh()
end

-- Paladin and Hunter draw ornate health casings on frames of their own, up to
-- three levels above the health bar, and their ends reach the crystal and the
-- orb. Those themes' crystal and orb cases (the "caps") are lifted onto a frame
-- just above them, so the caps sit in front of the health bar. Only the case
-- textures move: fills, effects and value texts keep their native levels, and
-- every anchor and size stays as Player.lua set it. Theme switches reload, so
-- a lifted cap never needs putting back.
local CAP_LEVEL_ABOVE_HEALTH = 4

local CapsInFront = function()
	return (ns.HunterTheme and ns.HunterTheme:IsActive()) or (ns.PaladinTheme and ns.PaladinTheme:IsActive()) or false
end

local CapLevel = function(element)
	local owner = element.GetParent and element:GetParent()
	local health = owner and owner.Health
	return health and health:GetFrameLevel() + CAP_LEVEL_ABOVE_HEALTH
end

local LiftCap = function(element, texture)
	if (not texture or not CapsInFront()) then return end
	local level = CapLevel(element)
	if (not level) then return end
	-- The Mage crystal already lifts its case into a frame of its own.
	local mage = element.MageCrystalCaseFrame
	if (mage and mage:IsShown() and texture:GetParent() == mage) then
		mage:SetFrameLevel(level)
		return
	end
	local frame = element.ThemeCapFrame
	if (not frame) then
		frame = CreateFrame("Frame", nil, element)
		frame:SetAllPoints(element)
		frame:EnableMouse(false)
		element.ThemeCapFrame = frame
	end
	frame:SetFrameLevel(level)
	if (texture:GetParent() ~= frame) then texture:SetParent(frame) end
end

Effects.CapsInFront = function(self) return CapsInFront() end

--- Called by Player.lua (and PlayerAlternate.lua with allowMage false, as
--- the Mage crystal has only ever been drawn on the main player crystal).
Effects.StyleCrystal = function(self, power, texturePath, coords, casePath, allowMage)
	local effect = self:GetCrystalEffect()
	local mage = ns.MageCrystalPreview
	local useMage = effect == "mage" and allowMage ~= false and mage
	-- The Mage crystal brings its own case, so the Hunter case geometry
	-- stands aside for it, as it always has.
	if (not useMage and ns.HunterTheme) then ns.HunterTheme:StyleCrystal(power) end
	-- The Mage theme's school badge belongs to the main player crystal.
	if (ns.MageTheme and allowMage ~= false) then ns.MageTheme:StyleCrystal(power) end
	-- Mage tidies up after itself when it is not the effect.
	if (mage and allowMage ~= false) then mage:StyleCrystal(power, texturePath, coords, casePath) end
	local paladin = ns.PaladinTheme
	if (paladin) then
		if (effect == "paladin") then paladin:ApplyCrystalEffect(power, texturePath, coords)
		else paladin:ClearCrystalEffect(power) end
	end
	LiftCap(power, power.Case)
end

--- Called by Player.lua before it sets the orb's fill. True when an effect
--- has set the fill itself.
Effects.StyleOrb = function(self, orb)
	LiftCap(orb, orb.Case)
	local effect = self:GetOrbEffect()
	local paladin, hunter = ns.PaladinTheme, ns.HunterTheme
	if (paladin) then
		if (effect == "paladin") then return paladin:ApplyOrbEffect(orb) end
		paladin:ClearOrbEffect(orb)
	end
	if (effect == "hunter" and hunter) then return hunter:ApplyOrbEffect(orb) end
	return false
end
