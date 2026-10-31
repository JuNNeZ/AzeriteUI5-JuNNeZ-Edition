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
local THEMES = { "azerite", "legacy", "hunter", "paladin", "mage" }
local THEME_CRYSTAL = { azerite = "none", hunter = "none", paladin = "paladin", mage = "mage", druid = "druid", warrior = "none", rogue = "none", shaman = "none" }
local THEME_ORB = { azerite = "none", hunter = "hunter", paladin = "paladin", mage = "none", druid = "druid", warrior = "none", rogue = "none", shaman = "none" }
local CRYSTAL_EFFECTS = { "none", "paladin", "mage", "druid", "moonvein", "dreamsap", "wildheart" }
local ORB_EFFECTS = { "none", "paladin", "hunter", "druid", "moonwell" }

local Contains = function(list, value)
	for _, entry in ipairs(list) do if (entry == value) then return true end end
	return false
end

local Char = function() return ns.db and ns.db.char end

-- Themes draw only over the main AzeriteUI layout, never over SaiyaRatt or a
-- config variant; the theme modules check the same thing.
local MainLayout = function()
	if (ns.IsSaiyaRattProfile and ns:IsSaiyaRattProfile()) then return false end
	local variant = ns.GetActiveConfigVariant and ns:GetActiveConfigVariant()
	return not variant or variant == ""
end

--- True on the main AzeriteUI layout, the only one themes draw over.
Effects.IsMainLayout = function(self) return MainLayout() end

--- Theme keys the dropdown may offer.
Effects.GetThemes = function(self)
	local list = {}
	for _, key in ipairs(THEMES) do list[#list + 1] = key end
	if (ns.DruidTheme) then list[#list + 1] = "druid" end
	if (ns.WarriorTheme) then list[#list + 1] = "warrior" end
	if (ns.RogueTheme) then list[#list + 1] = "rogue" end
	if (ns.ShamanTheme) then list[#list + 1] = "shaman" end
	-- Legacy needs its module; it writes the same switch /go does (Core/LegacyHUD.lua).
	if (not ns.LegacyHUD) then
		for index, key in ipairs(list) do
			if (key == "legacy") then table.remove(list, index); break end
		end
	end
	return list
end

--- The theme in use: AzeriteUI, Legacy or an installed class theme.
Effects.GetTheme = function(self)
	local char = Char()
	if (not char or not MainLayout()) then return "azerite" end
	if (ns.LegacyHUD and ns.LegacyHUD:IsActive()) then return "legacy" end
	if (ns.HunterTheme and ns.HunterTheme:IsActive()) then return "hunter" end
	if (ns.MageTheme and ns.MageTheme:IsActive()) then return "mage" end
	if (ns.PaladinTheme and ns.PaladinTheme:IsActive()) then return "paladin" end
	if (ns.DruidTheme and ns.DruidTheme:IsActive()) then return "druid" end
	if (ns.WarriorTheme and ns.WarriorTheme:IsActive()) then return "warrior" end
	if (ns.RogueTheme and ns.RogueTheme:IsActive()) then return "rogue" end
	if (ns.ShamanTheme and ns.ShamanTheme:IsActive()) then return "shaman" end
	return "azerite"
end

--- True when switching to this theme must rebuild the frame layouts.
Effects.NeedsReload = function(self, theme)
	if (ns.LegacyHUD and (ns.LegacyHUD.loadedActive or false) ~= (theme == "legacy")) then return true end
	for key, module in pairs({ hunter = ns.HunterTheme, paladin = ns.PaladinTheme, mage = ns.MageTheme }) do
		if ((module.loadedActive or false) ~= (theme == key)) then return true end
	end
	if (ns.DruidTheme and (ns.DruidTheme.loadedActive or false) ~= (theme == "druid")) then return true end
	if (ns.WarriorTheme and (ns.WarriorTheme.loadedActive or false) ~= (theme == "warrior")) then return true end
	if (ns.RogueTheme and (ns.RogueTheme.loadedActive or false) ~= (theme == "rogue")) then return true end
	if (ns.ShamanTheme and (ns.ShamanTheme.loadedActive or false) ~= (theme == "shaman")) then return true end
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
	return effect
end

--- The effect drawn in the power crystal, including optional Lite+ materials.
Effects.GetCrystalEffect = function(self)
	if (ns.LegacyHUD and ns.LegacyHUD:IsActive()) then return "none" end
	if (not Char() or not MainLayout()) then return "none" end
	return Resolve(THEME_CRYSTAL[self:GetTheme()], self:GetCrystalChoice())
end

--- The effect drawn in the mana orb: "none", "paladin", "hunter", "druid" or "moonwell".
Effects.GetOrbEffect = function(self)
	if (ns.LegacyHUD and ns.LegacyHUD:IsActive()) then return "none" end
	if (not Char() or not MainLayout()) then return "none" end
	return Resolve(THEME_ORB[self:GetTheme()], self:GetOrbChoice())
end

-- Gate on the orb's actual displayed resource, not class or colour aliases.
-- Unknown/secret display types never acquire the generic mana override.
Effects.ShouldFlowMana = function(self, orb, enabled)
	if (enabled ~= true or not orb) then return false end
	local powerType = orb.displayType
	if (issecretvalue and issecretvalue(powerType)) then return false end
	return type(powerType) == "number" and powerType == 0
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
	char.legacyHUD = theme == "legacy"
	char.hunterPreview = theme == "hunter"
	char.paladinPreview = theme == "paladin"
	char.magePreview = theme == "mage"
	char.druidPreview = theme == "druid"
	char.warriorPreview = theme == "warrior"
	char.roguePreview = theme == "rogue"
	char.shamanPreview = theme == "shaman"
	if (self:NeedsReload(theme)) then
		local reload = C_UI and C_UI.Reload or _G.ReloadUI
		if (type(reload) == "function") then reload() end
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
	return (ns.HunterTheme and ns.HunterTheme:IsActive()) or (ns.PaladinTheme and ns.PaladinTheme:IsActive())
		or (ns.DruidTheme and ns.DruidTheme:IsActive())
		or (ns.WarriorTheme and ns.WarriorTheme:IsActive())
		or (ns.RogueTheme and ns.RogueTheme:IsActive())
		or (ns.ShamanTheme and ns.ShamanTheme:IsActive()) or false
end

local CapLevel = function(element)
	local owner = element.GetParent and element:GetParent()
	local health = owner and owner.Health
	return health and health:GetFrameLevel() + CAP_LEVEL_ABOVE_HEALTH
end

local KeepCapLevel = function(element, texture, frame)
	if (frame.ThemeCapLevelSync) then frame.ThemeCapLevelSync(); return end
	local owner = element:GetParent()
	local sync = function()
		if (not CapsInFront() or texture:GetParent() ~= frame) then return end
		local level = CapLevel(element)
		if (not level or frame:GetFrameLevel() == level) then return end
		-- These decorative frames can inherit protection from their unit frame.
		if (InCombatLockdown()) then frame:RegisterEvent("PLAYER_REGEN_ENABLED"); return end
		frame:SetFrameLevel(level)
	end
	frame.ThemeCapLevelSync = sync
	frame:SetScript("OnEvent", function(_, event)
		if (event == "PLAYER_REGEN_ENABLED") then
			frame:UnregisterEvent(event)
			sync()
		end
	end)
	-- FixedFrameLevel alone did not survive the live resource-level updates.
	-- Reconcile after explicit changes; owner changes also propagate to Health.
	for _, source in ipairs({ element, owner.Health, owner }) do
		hooksecurefunc(source, "SetFrameLevel", sync)
	end
	if (ns.ShamanTheme and ns.ShamanTheme:IsActive()) then
		-- Live Shaman: native propagation leaves cap=4 / health=7 / rails=8
		-- without invoking any hooked Lua setter. Reconcile the visible case
		-- after that propagation too; hidden resource parents stop OnUpdate.
		local elapsedSinceCheck = 0
		frame:SetScript("OnUpdate", function(_, elapsed)
			elapsedSinceCheck = elapsedSinceCheck + elapsed
			if (elapsedSinceCheck < .1) then return end
			elapsedSinceCheck = 0
			if (InCombatLockdown()) then return end
			sync()
		end)
	end
	sync()
end

local LiftCap = function(element, texture)
	if (not texture or not CapsInFront()) then return end
	local level = CapLevel(element)
	if (not level) then return end
	-- The Mage crystal already lifts its case into a frame of its own.
	local mage = element.MageCrystalCaseFrame
	if (mage and mage:IsShown() and texture:GetParent() == mage) then
		if (mage.SetFixedFrameLevel) then mage:SetFixedFrameLevel(true) end
		mage:SetFrameLevel(level)
		KeepCapLevel(element, texture, mage)
		return
	end
	local frame = element.ThemeCapFrame
	if (not frame) then
		frame = CreateFrame("Frame", nil, element)
		frame:SetAllPoints(element)
		frame:EnableMouse(false)
		element.ThemeCapFrame = frame
	end
	-- Player visibility updates lower the power/orb parents after styling.
	-- Keep their decorative cases at the health-relative foreground level.
	if (frame.SetFixedFrameLevel) then frame:SetFixedFrameLevel(true) end
	frame:SetFrameLevel(level)
	if (texture:GetParent() ~= frame) then texture:SetParent(frame) end
	KeepCapLevel(element, texture, frame)
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
		if (paladin.StyleCrystal) then paladin:StyleCrystal(power, casePath, useMage) end
	end
	local druid = ns.DruidTheme
	if (druid) then
		if (effect == "druid") then druid:ApplyCrystalEffect(power, texturePath)
		else druid:ClearCrystalEffect(power) end
		druid:StyleCrystal(power, useMage)
	end
	local wildheart = ns.WildheartCrystal
	if (wildheart) then
		if (effect == "wildheart" or effect == "moonvein" or effect == "dreamsap") then wildheart:Apply(power, texturePath, effect)
		else wildheart:Clear(power) end
	end
	local rogue = ns.RogueTheme
	if (rogue and rogue.StyleCrystal) then rogue:StyleCrystal(power, casePath, useMage, texturePath) end
	LiftCap(power, power.Case)
end

--- Called by Player.lua before it sets the orb's fill. True when an effect
--- has set the fill itself.
Effects.StyleOrb = function(self, orb, flowingMana)
	LiftCap(orb, orb.Case)
	local effect = self:GetOrbEffect()
	local flowing = self:ShouldFlowMana(orb, flowingMana)
	orb.__AzeriteUI_FlowingMana = flowing
	local slosh = ns.MoonwellSlosh
	if (slosh and effect ~= "moonwell" and not flowing) then slosh:Clear(orb) end
	local druid = ns.DruidTheme
	if (druid) then
		if (effect ~= "druid") then druid:ClearOrbEffect(orb) end
	end
	local paladin, hunter = ns.PaladinTheme, ns.HunterTheme
	local claimed = false
	if (paladin) then
		if (effect == "paladin") then claimed = paladin:ApplyOrbEffect(orb)
		else paladin:ClearOrbEffect(orb) end
	end
	if (effect == "moonwell" and slosh) then return slosh:ApplyMoonwell(orb, flowing) end
	if (effect == "druid" and druid) then claimed = druid:ApplyOrbEffect(orb) end
	if (effect == "hunter" and hunter) then claimed = hunter:ApplyOrbEffect(orb) end
	-- Shape the selected painting's edge, including its own overlays. When no
	-- theme claims the fill, Player.lua still installs the chosen native material.
	if (flowing and slosh) then slosh:Apply(orb, true) end
	return claimed
end
