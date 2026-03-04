--[[

	The MIT License (MIT)

	Copyright (c) 2024 Lars Norberg

	Permission is hereby granted, free of charge, to any person obtaining a copy
	of this software and associated documentation files (the "Software"), to deal
	in the Software without restriction, including without limitation the rights
	to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
	copies of the Software, and to permit persons to whom the Software is
	furnished to do so, subject to the following conditions:

	The above copyright notice and this permission notice shall be included in all
	copies or substantial portions of the Software.

	THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
	IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
	FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
	AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
	LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
	OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
	SOFTWARE.

--]]
local _, ns = ...
local Debugging = ns:NewModule("Debugging", "LibMoreEvents-1.0", "AceConsole-3.0")

-- GLOBALS: EnableAddOn, GetAddOnInfo

-- Lua API
local next = next
local pairs = pairs
local print = print
local select = select
local string_format = string.format
local string_lower = string.lower
local table_insert = table.insert
local unpack = unpack
local PrintPlayerOrbDebug

local function IsDevMode()
	return (ns and (ns.IsDevelopment or (ns.db and ns.db.global and ns.db.global.enableDevelopmentMode)))
end

local function RefreshTargetDebugTestFrames()
	local targetMod = ns and ns.GetModule and ns:GetModule("TargetFrame", true)
	local frame = targetMod and targetMod.frame
	if (not frame) then
		return
	end
	frame.__AzeriteUI_HealthLabSignature = nil
	frame.__AzeriteUI_TargetGUID = nil
	if (frame.PostUpdate) then
		frame:PostUpdate()
	end
	if (frame.Health and frame.Health.ForceUpdate) then
		frame.Health:ForceUpdate()
	end
	if (frame.Castbar and frame.Castbar.ForceUpdate and frame.IsElementEnabled and frame:IsElementEnabled("Castbar")) then
		frame.Castbar:ForceUpdate()
	end
end

local function PrintTargetFillDebugStatus()
	print("|cff33ff99", "AzeriteUI target fill debug:")
	print("|cfff0f0f0  health:", "curve percent -> fake fill -> mirrored visible art")
	print("|cfff0f0f0  cast:", "live duration percent -> timer fallback -> unit-time fallback")
end

local ADDONS = {

	"Blizzard_AchievementUI",
	"Blizzard_AdventureMap",
	"Blizzard_AlliedRacesUI",
	"Blizzard_AnimaDiversionUI",
	"Blizzard_APIDocumentation",
	"Blizzard_ArchaeologyUI",
	"Blizzard_ArdenwealdGardening",
	"Blizzard_ArenaUI",
	"Blizzard_ArtifactUI",
	"Blizzard_AuctionHouseUI",
	"Blizzard_AuthChallengeUI",
	"Blizzard_AzeriteEssenceUI",
	"Blizzard_AzeriteRespecUI",
	"Blizzard_AzeriteUI",
	"Blizzard_BarbershopUI",
	"Blizzard_BattlefieldMap",
	"Blizzard_BehavioralMessaging",
	"Blizzard_BlackMarketUI",
	"Blizzard_BoostTutorial",
	"Blizzard_Calendar",
	"Blizzard_ChallengesUI",
	"Blizzard_Channels",
	"Blizzard_CharacterCreate",
	"Blizzard_CharacterCustomize",
	"Blizzard_ChromieTimeUI",
	"Blizzard_ClassTalentUI",
	"Blizzard_ClassTrial",
	"Blizzard_ClickBindingUI",
	"Blizzard_ClientSavedVariables",
	"Blizzard_Collections",
	"Blizzard_CombatLog",
	"Blizzard_CombatText",
	"Blizzard_Commentator",
	"Blizzard_Communities",
	"Blizzard_CompactRaidFrames",
	"Blizzard_Console",
	"Blizzard_Contribution",
	"Blizzard_CovenantCallings",
	"Blizzard_CovenantPreviewUI",
	"Blizzard_CovenantRenown",
	"Blizzard_CovenantSanctum",
	"Blizzard_CovenantToasts",
	"Blizzard_CUFProfiles",
	"Blizzard_DeathRecap",
	"Blizzard_DebugTools",
	"Blizzard_Deprecated",
	"Blizzard_EncounterJournal",
	"Blizzard_EventTrace",
	"Blizzard_ExpansionLandingPage",
	"Blizzard_FlightMap",
	"Blizzard_FrameEffects",
	"Blizzard_GarrisonTemplates",
	"Blizzard_GarrisonUI",
	"Blizzard_GenericTraitUI",
	"Blizzard_GMChatUI",
	"Blizzard_GuildBankUI",
	"Blizzard_GuildControlUI",
	"Blizzard_GuildUI",
	"Blizzard_HybridMinimap",
	"Blizzard_InspectUI",
	"Blizzard_IslandsPartyPoseUI",
	"Blizzard_IslandsQueueUI",
	"Blizzard_ItemInteractionUI",
	"Blizzard_ItemSocketingUI",
	"Blizzard_ItemUpgradeUI",
	"Blizzard_Kiosk",
	"Blizzard_LandingSoulbinds",
	"Blizzard_MacroUI",
	"Blizzard_MainlineSettings",
	"Blizzard_MajorFactions",
	"Blizzard_MapCanvas",
	"Blizzard_MawBuffs",
	"Blizzard_MoneyReceipt",
	"Blizzard_MovePad",
	"Blizzard_NamePlates",
	"Blizzard_NewPlayerExperience",
	"Blizzard_NewPlayerExperienceGuide",
	"Blizzard_ObjectiveTracker",
	"Blizzard_ObliterumUI",
	"Blizzard_OrderHallUI",
	"Blizzard_PartyPoseUI",
	"Blizzard_PetBattleUI",
	"Blizzard_PlayerChoice",
	"Blizzard_Professions",
	"Blizzard_ProfessionsCrafterOrders",
	"Blizzard_ProfessionsCustomerOrders",
	"Blizzard_PTRFeedback",
	"Blizzard_PTRFeedbackGlue",
	"Blizzard_PVPMatch",
	"Blizzard_PVPUI",
	"Blizzard_QuestNavigation",
	"Blizzard_RaidUI",
	"Blizzard_RuneforgeUI",
	"Blizzard_ScrappingMachineUI",
	"Blizzard_SecureTransferUI",
	"Blizzard_SelectorUI",
	"Blizzard_Settings",
	"Blizzard_SharedMapDataProviders",
	"Blizzard_SharedTalentUI",
	"Blizzard_SocialUI",
	"Blizzard_Soulbinds",
	"Blizzard_StoreUI",
	"Blizzard_SubscriptionInterstitialUI",
	"Blizzard_TalentUI",
	"Blizzard_TalkingHeadUI",
	"Blizzard_TimeManager",
	"Blizzard_TokenUI",
	"Blizzard_TorghastLevelPicker",
	"Blizzard_TrainerUI",
	"Blizzard_Tutorial",
	"Blizzard_TutorialTemplates",
	"Blizzard_UIFrameManager",
	"Blizzard_UIWidgets",
	"Blizzard_VoidStorageUI",
	"Blizzard_WarfrontsPartyPoseUI",
	"Blizzard_WeeklyRewards",
	"Blizzard_WorldMap",
	"Blizzard_WowTokenUI"

}

Debugging.EnableBlizzardAddOns = function(self)
	local disabled = {}
	for _,addon in next,ADDONS do
		local reason = select(5, GetAddOnInfo(addon))
		if (reason == "DISABLED") then
			EnableAddOn(addon)
			disabled[#disabled + 1] = addon
		end
	end
	local num = #disabled
	if (num == 0) then
		print("|cff33ff99", "No Blizzard addons were disabled.")
	else
		if (num > 1) then
			print("|cff33ff99", string_format("The following %d Blizzard addons were enabled:", #disabled))
		else
			print("|cff33ff99", "The following Blizzard addon was enabled:")
		end
		for _,addon in next,ADDONS do
			print(string_format("|cfff0f0f0%s|r", addon))
		end
		print("|cfff00a0aA /reload is required to apply changes!|r")
	end
end

Debugging.EnableScriptErrors = function(self)
	SetCVar("scriptErrors", 1)
end

Debugging.EnsureDebugCommands = function(self)
	if (self.__AzeriteUI_DebugCommandsRegistered) then
		return
	end
	self:RegisterChatCommand("azdebug", "DebugMenu")
	self:RegisterChatCommand("azdebugtarget", "TargetDebugMenu")
	self:RegisterChatCommand("azdebugkeys", "DebugKeysMenu")
	self:RegisterChatCommand("junnez", "SecretJuNNeZCommand")
	self:RegisterChatCommand("goldpaw", "SecretGoldpawCommand")
	self.__AzeriteUI_DebugCommandsRegistered = true
end

-- Secret JuNNeZ Command - Easter Egg
Debugging.SecretJuNNeZCommand = function(self)
	local playerFrame = ns:GetModule("PlayerFrame", true)
	local targetFrame = ns:GetModule("TargetFrame", true)
	
	-- Create Batman-style KAPOW zoom texture frame
	local centerFrame = CreateFrame("Frame", "JuNNeZCenterTexture", UIParent)
	centerFrame:SetSize(512, 512)
	centerFrame:SetPoint("CENTER")
	centerFrame:SetFrameLevel(250)
	centerFrame:SetScale(0.1)  -- Start tiny
	
	local texture = centerFrame:CreateTexture(nil, "OVERLAY")
	texture:SetAllPoints(centerFrame)
	texture:SetTexture("Interface\\AddOns\\AzeriteUI\\Assets\\JuNNeZKapow.tga")
	texture:SetAlpha(1.0)
	
	-- Batman KAPOW! Zoom in effect (0.1 -> 1.8 -> 1.0)
	for i = 1, 15 do
		C_Timer.After(i * 0.04, function()
			local scale = 0.1 + (i / 15) * 1.7  -- Zoom from 0.1 to 1.8
			centerFrame:SetScale(scale)
		end)
	end
	
	-- SNAP to normal size at peak with sound
	C_Timer.After(0.65, function()
		centerFrame:SetScale(1.0)
		if (SOUNDKIT and SOUNDKIT.UI_ACHIEVEMENT_EARNED) then
			C_Sound.PlaySound(SOUNDKIT.UI_ACHIEVEMENT_EARNED)
		end
	end)
	
	-- Hold for effect, then fade out
	C_Timer.After(2.5, function()
		for i = 1, 10 do
			C_Timer.After(i * 0.1, function()
				texture:SetAlpha(1.0 - (i / 10))
			end)
		end
	end)
	
	-- Celebratory messages
	local messages = {
		"|cff00ff00JUNNEZ EDITION ACTIVATED!!!|r",
		"|cffffaa00FEEL THE POWER OF CUSTOM CODE!!!|r",
		"|cffff00ffMAINTENANCE MODE: FULLY ENGAGED!!!|r",
		"|cff00ffffBUG FIXES FLOWING LIKE MANA!!!|r",
		"|cffff7700UPDATED AND MAINTAINED BY JUNNEZ!!!|r",
		"|cffff00ffCHAOS LEVEL: 9000!!!|r",
		"|cff00ffffTHIS IS NOT A DRILL!!!|r",
		"|cffff7700WATCH YOUR SANITY!!!|r"
	}
	
	for i, msg in ipairs(messages) do
		C_Timer.After((i-1) * 0.5, function()
			print(msg)
			C_Sound.PlaySound(SOUNDKIT.RAID_WARNING)
		end)
	end
	
	-- Rainbow color flash for player and target frames
	local colors = {
		{1, 0, 0}, -- Red
		{1, 0.5, 0}, -- Orange
		{1, 1, 0}, -- Yellow
		{0, 1, 0}, -- Green
		{0, 1, 1}, -- Cyan
		{0, 0, 1}, -- Blue
		{1, 0, 1}, -- Magenta
		{0.5, 0, 1}, -- Purple
		{1, 0.5, 0.5}, -- Pink
	}
	
	local flashFrames = {}
	if (playerFrame and playerFrame.frame) then
		table_insert(flashFrames, playerFrame.frame)
	end
	if (targetFrame and targetFrame.frame) then
		table_insert(flashFrames, targetFrame.frame)
	end
	
	-- Create flash animation
	for colorIndex, color in ipairs(colors) do
		C_Timer.After(colorIndex * 0.3, function()
			for _, frame in ipairs(flashFrames) do
				if (frame and frame.Health) then
					local health = frame.Health
					if (health.SetStatusBarColor) then
						health:SetStatusBarColor(unpack(color))
						C_Timer.After(0.15, function()
							if (frame.UpdateHealth) then
								pcall(frame.UpdateHealth, frame)
							end
						end)
					end
				end
			end
		end)
	end
	
	-- UI Scale bounce
	local originalScale = UIParent:GetScale()
	-- Store original health colors before animation
	local origPlayerColor = {1, 0, 0}
	local origTargetColor = {1, 0, 0}
	if (playerFrame and playerFrame.frame and playerFrame.frame.Health) then
		origPlayerColor = {playerFrame.frame.Health:GetStatusBarColor()}
	end
	if (targetFrame and targetFrame.frame and targetFrame.frame.Health) then
		origTargetColor = {targetFrame.frame.Health:GetStatusBarColor()}
	end
	
	for i = 1, 12 do
		C_Timer.After(i * 0.15, function()
			UIParent:SetScale(originalScale * (i % 2 == 0 and 1.03 or 0.97))
			if (i % 2 == 0) then
				C_Sound.PlaySound(SOUNDKIT.RAID_WARNING)
			end
		end)
	end
	C_Timer.After(3.0, function()
		UIParent:SetScale(originalScale)
		-- Restore original health colors AFTER all animations complete
		if (playerFrame and playerFrame.frame and playerFrame.frame.Health) then
			playerFrame.frame.Health:SetStatusBarColor(unpack(origPlayerColor))
			if (playerFrame.frame.UpdateHealth) then
				pcall(playerFrame.frame.UpdateHealth, playerFrame.frame)
			end
		end
		if (targetFrame and targetFrame.frame and targetFrame.frame.Health) then
			targetFrame.frame.Health:SetStatusBarColor(unpack(origTargetColor))
			if (targetFrame.frame.UpdateHealth) then
				pcall(targetFrame.frame.UpdateHealth, targetFrame.frame)
			end
		end
	end)
	
	-- Final message and cleanup
	C_Timer.After(5.0, function()
		local finalMsg = "|cff00ff00THANKS FOR USING THE JUNNEZ EDITION! CHAOS COMPLETE!!!|r"
		print(finalMsg)
		if (centerFrame and centerFrame:IsShown()) then
			centerFrame:Hide()
		end
	end)
	
	-- Frame destruction timer
end

-- Secret Goldpaw Command - Tribute to Original Creator
Debugging.SecretGoldpawCommand = function(self)
	local playerFrame = ns:GetModule("PlayerFrame", true)
	local targetFrame = ns:GetModule("TargetFrame", true)
	
	-- Create Goldpaw-style zoom texture frame (similar to /junnez)
	local centerFrame = CreateFrame("Frame", "GoldpawCenterTexture", UIParent)
	centerFrame:SetSize(512, 512)
	centerFrame:SetPoint("CENTER")
	centerFrame:SetFrameLevel(250)
	centerFrame:SetScale(0.1)  -- Start tiny
	
	local texture = centerFrame:CreateTexture(nil, "OVERLAY")
	texture:SetAllPoints(centerFrame)
	texture:SetTexture("Interface\\AddOns\\AzeriteUI\\Assets\\GoldpawKapow.tga")
	texture:SetAlpha(1.0)
	
	-- Goldpaw zoom in effect (0.1 -> 1.8 -> 1.0)
	for i = 1, 15 do
		C_Timer.After(i * 0.04, function()
			local scale = 0.1 + (i / 15) * 1.7  -- Zoom from 0.1 to 1.8
			centerFrame:SetScale(scale)
		end)
	end
	
	-- SNAP to normal size at peak with sound
	C_Timer.After(0.65, function()
		centerFrame:SetScale(1.0)
		if (SOUNDKIT and SOUNDKIT.UI_ACHIEVEMENT_EARNED) then
			C_Sound.PlaySound(SOUNDKIT.UI_ACHIEVEMENT_EARNED)
		end
	end)
	
	-- Hold for effect, then fade out
	C_Timer.After(2.5, function()
		for i = 1, 10 do
			C_Timer.After(i * 0.1, function()
				texture:SetAlpha(1.0 - (i / 10))
			end)
		end
	end)
	
	-- Tribute messages for the original creator
	local messages = {
		"|cffffcc00Goldpaw - Original Creator of AzeriteUI|r",
		"|cffffd700Master of UI design and Lua wizardry!|r",
		"|cfffff569Building beautiful interfaces since forever!|r",
		"|cffffaa00Thank you for this amazing foundation!|r",
		"|cffffff00The legend who started it all!|r"
	}
	
	for i, msg in ipairs(messages) do
		C_Timer.After((i-1) * 0.6, function()
			print(msg)
			C_Sound.PlaySound(SOUNDKIT.ACHIEVEMENT_MENU_OPEN)
		end)
	end
	
	-- Golden glow pulse for player and target frames
	local goldColors = {
		{1, 0.84, 0}, -- Pure Gold
		{1, 0.9, 0.3}, -- Light Gold
		{1, 0.84, 0}, -- Pure Gold
		{1, 0.75, 0}, -- Deep Gold
		{1, 0.84, 0}, -- Pure Gold
		{1, 1, 0.5}, -- Bright Gold
	}
	
	local flashFrames = {}
	if (playerFrame and playerFrame.frame) then
		table_insert(flashFrames, playerFrame.frame)
	end
	if (targetFrame and targetFrame.frame) then
		table_insert(flashFrames, targetFrame.frame)
	end
	
	-- Create golden pulse animation
	for colorIndex, color in ipairs(goldColors) do
		C_Timer.After(colorIndex * 0.4, function()
			for _, frame in ipairs(flashFrames) do
				if (frame and frame.Health) then
					local health = frame.Health
					if (health.SetStatusBarColor) then
						health:SetStatusBarColor(unpack(color))
						C_Timer.After(0.2, function()
							if (frame.UpdateHealth) then
								pcall(frame.UpdateHealth, frame)
							end
						end)
					end
				end
			end
			C_Sound.PlaySound(SOUNDKIT.UI_LEGENDARY_LOOT_TOAST)
		end)
	end
	
	-- Gentle UI glow (subtle scale pulse)
	local originalScale = UIParent:GetScale()
	-- Store original health colors before animation
	local origPlayerColor = {1, 0, 0}
	local origTargetColor = {1, 0, 0}
	if (playerFrame and playerFrame.frame and playerFrame.frame.Health) then
		origPlayerColor = {playerFrame.frame.Health:GetStatusBarColor()}
	end
	if (targetFrame and targetFrame.frame and targetFrame.frame.Health) then
		origTargetColor = {targetFrame.frame.Health:GetStatusBarColor()}
	end
	
	for i = 1, 4 do
		C_Timer.After(i * 0.3, function()
			local scaleMod = 1 + (math.sin(i * 1.5) * 0.01)
			UIParent:SetScale(originalScale * scaleMod)
		end)
	end
	
	-- FIXED: Restore colors and scale AFTER all animations complete (2.4 sec for colors)
	C_Timer.After(3.0, function()
		UIParent:SetScale(originalScale)
		-- Restore original health colors
		if (playerFrame and playerFrame.frame and playerFrame.frame.Health) then
			playerFrame.frame.Health:SetStatusBarColor(unpack(origPlayerColor))
			if (playerFrame.frame.UpdateHealth) then
				pcall(playerFrame.frame.UpdateHealth, playerFrame.frame)
			end
		end
		if (targetFrame and targetFrame.frame and targetFrame.frame.Health) then
			targetFrame.frame.Health:SetStatusBarColor(unpack(origTargetColor))
			if (targetFrame.frame.UpdateHealth) then
				pcall(targetFrame.frame.UpdateHealth, targetFrame.frame)
			end
		end
	end)
	
	-- Final tribute message
	C_Timer.After(3.5, function()
		print("|cffffd700Honoring Goldpaw - The Original Architect!|r")
		C_Sound.PlaySound(SOUNDKIT.RAID_WARNING)
		if (centerFrame and centerFrame:IsShown()) then
			centerFrame:Hide()
		end
	end)
end

Debugging.OnEvent = function(self, event, ...)
	self:EnableScriptErrors()
	self:EnsureDebugCommands()
end

Debugging.OnInitialize = function(self)
	self:EnsureDebugCommands()
	if (ns.db and ns.db.global) then
		ns.db.global.debugHealth = ns.db.global.debugHealth or false
		ns.db.global.debugHealthChat = ns.db.global.debugHealthChat or false
		ns.db.global.debugHealthPercent = ns.db.global.debugHealthPercent or false
		ns.db.global.debugBars = ns.db.global.debugBars or false
		ns.db.global.debugFixes = ns.db.global.debugFixes or false
		ns.db.global.debugAuras = ns.db.global.debugAuras or false
		ns.db.global.debugAurasFilter = ns.db.global.debugAurasFilter or ""
		ns.db.global.debugActionbars = ns.db.global.debugActionbars or false
		ns.db.global.debugActionbarsFilter = ns.db.global.debugActionbarsFilter or ""
		ns.db.global.debugCastbar = ns.db.global.debugCastbar or false
		ns.db.global.debugPower = ns.db.global.debugPower or false
		ns.db.global.debugPowerFilter = ns.db.global.debugPowerFilter or ""
		ns.db.global.debugKeysVerbose = ns.db.global.debugKeysVerbose or false
		ns.db.global.debugAssisted = ns.db.global.debugAssisted or false
		if (not ns.db.global.debugHealthFilter or ns.db.global.debugHealthFilter == "") then
			ns.db.global.debugHealthFilter = "Target."
		end
		ns.API.DEBUG_HEALTH = ns.db.global.debugHealth
		ns.API.DEBUG_HEALTH_CHAT = ns.db.global.debugHealthChat
		ns.API.DEBUG_HEALTH_FILTER = ns.db.global.debugHealthFilter
		ns.API.DEBUG_HEALTH_PCT = ns.db.global.debugHealthPercent
		ns.API.DEBUG_AURAS = ns.db.global.debugAuras
		ns.API.DEBUG_AURA_FILTER = ns.db.global.debugAurasFilter
		ns.API.DEBUG_ACTIONBARS = ns.db.global.debugActionbars
		ns.API.DEBUG_ACTIONBARS_FILTER = ns.db.global.debugActionbarsFilter
		ns.API.DEBUG_CASTBAR = ns.db.global.debugCastbar
		ns.API.DEBUG_POWER = ns.db.global.debugPower
		ns.API.DEBUG_POWER_FILTER = ns.db.global.debugPowerFilter
		_G.__AzeriteUI_DEBUG_BARS = ns.db.global.debugBars
		_G.__AzeriteUI_DEBUG_HEALTH_PCT = ns.db.global.debugHealthPercent
		_G.__AzeriteUI_DEBUG_AURAS = ns.db.global.debugAuras
		_G.__AzeriteUI_DEBUG_AURA_FILTER = ns.db.global.debugAurasFilter
		_G.__AzeriteUI_DEBUG_ACTIONBARS = ns.db.global.debugActionbars
		_G.__AzeriteUI_DEBUG_ACTIONBARS_FILTER = ns.db.global.debugActionbarsFilter
		_G.__AzeriteUI_DEBUG_CASTBAR = ns.db.global.debugCastbar
		_G.__AzeriteUI_DEBUG_POWER = ns.db.global.debugPower
		_G.__AzeriteUI_DEBUG_POWER_FILTER = ns.db.global.debugPowerFilter
		_G.__AzeriteUI_DEBUG_KEYS = ns.db.global.debugKeysVerbose
		-- Restore assisted combat debug state
		local LAB = LibStub("LibActionButton-1.0-GE", true)
		if LAB and LAB.SetAssistedCombatDebug then
			LAB.SetAssistedCombatDebug(ns.db.global.debugAssisted)
		end
	end
	if (ns.WoW10) then
		self:RegisterEvent("SETTINGS_LOADED", "OnEvent")
	end
	self:RegisterEvent("PLAYER_ENTERING_WORLD", "OnEvent")
	self:RegisterEvent("VARIABLES_LOADED", "OnEvent")
	self:EnableScriptErrors()
end

Debugging.ToggleHealthDebug = function(self)
	ns.API.DEBUG_HEALTH = not ns.API.DEBUG_HEALTH
	if (ns.db and ns.db.global) then
		ns.db.global.debugHealth = ns.API.DEBUG_HEALTH
	end
	local enabled = ns.API.DEBUG_HEALTH
	print("|cff33ff99", "AzeriteUI health debug:", enabled and "ON" or "OFF")

	local oUF = ns.oUF
	if (oUF and oUF.objects) then
		for _, obj in next, oUF.objects do
			local dbg = obj.HealthDebug
			if (dbg) then
				if (enabled) then dbg:Show() else dbg:Hide() end
			end
		end
	end
end

Debugging.ToggleHealthDebugChat = function(self)
	ns.API.DEBUG_HEALTH_CHAT = not ns.API.DEBUG_HEALTH_CHAT
	if (ns.db and ns.db.global) then
		ns.db.global.debugHealthChat = ns.API.DEBUG_HEALTH_CHAT
	end
	print("|cff33ff99", "AzeriteUI health debug chat:", ns.API.DEBUG_HEALTH_CHAT and "ON" or "OFF")
end

local function SafeCall(obj, method, ...)
	if (obj and obj[method]) then
		local ok, a, b, c, d = pcall(obj[method], obj, ...)
		if (ok) then
			return a, b, c, d
		end
	end
	return nil
end

local function IsSecretValue(value)
	return (issecretvalue and issecretvalue(value)) and true or false
end

local function SecretSafeText(value)
	if (IsSecretValue(value)) then
		return "<secret>"
	end
	local ok, text = pcall(tostring, value)
	if (ok and text ~= nil) then
		return text
	end
	return "<unprintable>"
end

local function SafePrint(...)
	local args = {}
	for i = 1, select("#", ...) do
		args[i] = SecretSafeText(select(i, ...))
	end
	print(unpack(args))
end

local function DumpUnitValue(label, value)
	SafePrint("|cfff0f0f0  " .. label .. ":", value, IsSecretValue(value) and "(secret)" or "(clean)")
end

local function ResolveUnitFrame(unit)
	if (IsSecretValue(unit) or type(unit) ~= "string" or unit == "") then
		return nil, nil
	end
	unit = unit:lower()
	if (unit == "target") then
		local mod = ns:GetModule("TargetFrame", true)
		return mod and mod.frame, "TargetFrame"
	end
	if (unit == "player") then
		local mod = ns:GetModule("PlayerFrame", true)
		return mod and mod.frame, "PlayerFrame"
	end
	if (unit == "targettarget" or unit == "tot") then
		local mod = ns:GetModule("ToTFrame", true)
		return mod and mod.frame, "ToTFrame"
	end
	return nil, nil
end

local function DumpElementSnapshot(element, label)
	if (not element) then
		SafePrint("|cfff0f0f0  " .. label .. ":", "missing")
		return
	end
	local value = SafeCall(element, "GetValue")
	local minValue, maxValue = SafeCall(element, "GetMinMaxValues")
	SafePrint("|cfff0f0f0  " .. label .. " safe:",
		"cur", element.safeCur,
		"min", element.safeMin,
		"max", element.safeMax,
		"pct", element.safePercent)
	SafePrint("|cfff0f0f0  " .. label .. " bar:",
		"value", value,
		"min", minValue,
		"max", maxValue,
		"mirrorPct", element.__AzeriteUI_MirrorPercent,
		"texPct", element.__AzeriteUI_TexturePercent)
end

local function SafeUnitBoolCall(func, ...)
	if (type(func) ~= "function") then
		return nil
	end
	local ok, value = pcall(func, ...)
	if (not ok or type(value) ~= "boolean") then
		return nil
	end
	return value
end

local function SafeUnitNumberCall(func, ...)
	if (type(func) ~= "function") then
		return nil
	end
	local ok, value = pcall(func, ...)
	if (not ok or type(value) ~= "number") then
		return nil
	end
	return value
end

local function DumpUnitSnapshot(unit)
	if (IsSecretValue(unit) or type(unit) ~= "string" or unit == "") then
		unit = "target"
	end
	SafePrint("|cff33ff99", "AzeriteUI unit snapshot:", unit)
	if (not UnitExists(unit)) then
		SafePrint("|cfff0f0f0  unit does not exist")
		return
	end

	DumpUnitValue("UnitGUID", UnitGUID(unit))
	SafePrint("|cfff0f0f0  targetInfo:",
		"isPlayer", SafeUnitBoolCall(UnitIsPlayer, unit),
		"playerControlled", SafeUnitBoolCall(UnitPlayerControlled, unit),
		"canAttack", SafeUnitBoolCall(UnitCanAttack, "player", unit),
		"canAssist", SafeUnitBoolCall(UnitCanAssist, "player", unit),
		"isEnemy", SafeUnitBoolCall(UnitIsEnemy, "player", unit),
		"isFriend", SafeUnitBoolCall(UnitIsFriend, "player", unit),
		"reaction", SafeUnitNumberCall(UnitReaction, unit, "player"),
		"tapDenied", SafeUnitBoolCall(UnitIsTapDenied, unit))

	DumpUnitValue("UnitHealth", UnitHealth(unit))
	DumpUnitValue("UnitHealthMax", UnitHealthMax(unit))
	if (UnitHealthPercent) then
		local percent = nil
		pcall(function()
			if (CurveConstants and CurveConstants.ScaleTo100) then
				percent = UnitHealthPercent(unit, true, CurveConstants.ScaleTo100)
			else
				percent = UnitHealthPercent(unit)
			end
		end)
		DumpUnitValue("UnitHealthPercent", percent)
	end

	local powerType = UnitPowerType(unit)
	DumpUnitValue("UnitPower", UnitPower(unit, powerType))
	DumpUnitValue("UnitPowerMax", UnitPowerMax(unit, powerType))
	if (UnitPowerPercent) then
		local powerPercent = nil
		pcall(function()
			if (CurveConstants and CurveConstants.ScaleTo100) then
				powerPercent = UnitPowerPercent(unit, powerType, true, CurveConstants.ScaleTo100)
			else
				powerPercent = UnitPowerPercent(unit, powerType)
			end
		end)
		DumpUnitValue("UnitPowerPercent", powerPercent)
	end

	local frame, frameName = ResolveUnitFrame(unit)
	if (frame and frame.unit == unit) then
		SafePrint("|cfff0f0f0  frame:", frameName, "bound")
		DumpElementSnapshot(frame.Health, "Health")
		DumpElementSnapshot(frame.Power, "Power")
	else
		SafePrint("|cfff0f0f0  frame:", frameName or "n/a", "not bound to unit token")
	end
end

local function DumpPoints(frame, indent)
	if (not frame) then
		return
	end
	local num = SafeCall(frame, "GetNumPoints") or 0
	for i = 1, num do
		local point, relTo, relPoint, x, y = SafeCall(frame, "GetPoint", i)
		local relName = relTo and SafeCall(relTo, "GetName") or tostring(relTo)
		SafePrint("|cfff0f0f0 " .. indent .. "point[" .. i .. "]:", point, relName, relPoint, x, y)
	end
end

local function GetCVarBoolSafe(name)
	if (type(name) ~= "string" or name == "") then
		return nil
	end
	if (C_CVar and C_CVar.GetCVarBool) then
		local ok, value = pcall(C_CVar.GetCVarBool, name)
		if (ok and type(value) == "boolean") then
			return value
		end
	end
	if (GetCVarBool) then
		local ok, value = pcall(GetCVarBool, name)
		if (ok and type(value) == "boolean") then
			return value
		end
	end
	return nil
end

local function GetCVarSafe(name)
	if (type(name) ~= "string" or name == "") then
		return nil
	end
	if (C_CVar and C_CVar.GetCVar) then
		local ok, value = pcall(C_CVar.GetCVar, name)
		if (ok and type(value) == "string") then
			return value
		end
	end
	if (GetCVar) then
		local ok, value = pcall(GetCVar, name)
		if (ok and type(value) == "string") then
			return value
		end
	end
	return nil
end

local function GetActionBarsModule()
	local module = ns:GetModule("ActionBars", true)
	if (module and module.db and module.db.profile) then
		return module
	end
	return nil
end

local function FindActionButtonByName(buttonName)
	if (type(buttonName) ~= "string" or buttonName == "") then
		return nil
	end
	local direct = _G[buttonName]
	if (direct) then
		return direct
	end
	local module = GetActionBarsModule()
	if (not module or not module.buttons) then
		return nil
	end
	for button in pairs(module.buttons) do
		if (button and button.GetName and button:GetName() == buttonName) then
			return button
		end
	end
	return nil
end

local function GetActionCooldownInfoSafe(actionID)
	if (type(actionID) ~= "number") then
		return nil
	end
	if (C_ActionBar and C_ActionBar.GetActionCooldown) then
		local ok, info = pcall(C_ActionBar.GetActionCooldown, actionID)
		if (ok and type(info) == "table") then
			return info
		end
	end
	if (GetActionCooldown) then
		local ok, start, duration, enabled, modRate = pcall(GetActionCooldown, actionID)
		if (ok) then
			return {
				startTime = start,
				duration = duration,
				isEnabled = enabled,
				modRate = modRate
			}
		end
	end
	return nil
end

local function GetActionChargeInfoSafe(actionID)
	if (type(actionID) ~= "number") then
		return nil
	end
	if (C_ActionBar and C_ActionBar.GetActionCharges) then
		local ok, info = pcall(C_ActionBar.GetActionCharges, actionID)
		if (ok and type(info) == "table") then
			return info
		end
	end
	if (GetActionCharges) then
		local ok, charges, maxCharges, startTime, duration, modRate = pcall(GetActionCharges, actionID)
		if (ok) then
			return {
				currentCharges = charges,
				maxCharges = maxCharges,
				cooldownStartTime = startTime,
				cooldownDuration = duration,
				chargeModRate = modRate
			}
		end
	end
	return nil
end

local function PrintDebugKeysHelp()
	print("|cff33ff99", "AzeriteUI /azdebugkeys commands:")
	print("|cfff0f0f0  /azdebugkeys status|r")
	print("|cfff0f0f0  /azdebugkeys bindings|r")
	print("|cfff0f0f0  /azdebugkeys cooldown [buttonName]|r")
	print("|cfff0f0f0  /azdebugkeys holdtest [spellID]|r")
	print("|cfff0f0f0  /azdebugkeys on|off|toggle|r  (verbose)")
	print("|cfff0f0f0  /azdebug keys <subcommand>|r  (same commands via /azdebug)")
end

local function PrintDebugKeysStatus()
	local module = GetActionBarsModule()
	local profile = module and module.db and module.db.profile or nil
	local commandMode = (profile and profile.UseCommandBindingsForHoldCast == true) and true or false
	local clickOnDown = (profile and profile.clickOnDown == true) and true or false
	local cvarKeyDown = GetCVarBoolSafe("ActionButtonUseKeyDown")
	local cvarPressHold = GetCVarBoolSafe("ActionButtonUseKeyHeldSpell")
	local cvarPressHoldRaw = GetCVarSafe("ActionButtonUseKeyHeldSpell")
	local holdApi = (C_Spell and C_Spell.IsPressHoldReleaseSpell) and "yes" or "no"
	local inCombat = (InCombatLockdown and InCombatLockdown()) and "true" or "false"
	local verbose = (ns.db and ns.db.global and ns.db.global.debugKeysVerbose) and "ON" or "OFF"

	print("|cff33ff99", "AzeriteUI key debug status:")
	print("|cfff0f0f0  inCombat:", inCombat)
	print("|cfff0f0f0  bindingMode:", commandMode and "command" or "click-fallback")
	print("|cfff0f0f0  profile.clickOnDown:", tostring(clickOnDown))
	print("|cfff0f0f0  CVar ActionButtonUseKeyDown:", tostring(cvarKeyDown))
	print("|cfff0f0f0  CVar ActionButtonUseKeyHeldSpell:", tostring(cvarPressHold), "raw:", tostring(cvarPressHoldRaw))
	print("|cfff0f0f0  C_Spell.IsPressHoldReleaseSpell:", holdApi)
	print("|cfff0f0f0  verbose:", verbose)

	if (module and module.bars) then
		for index, bar in pairs(module.bars) do
			local enabled = bar and bar.IsEnabled and bar:IsEnabled() and "true" or "false"
			local numButtons = (bar and bar.config and bar.config.numbuttons) or 0
			print("|cfff0f0f0  bar"..tostring(index)..": enabled", enabled, "buttons", tostring(numButtons))
		end
	end
end

local function PrintDebugKeyBindings()
	local module = GetActionBarsModule()
	if (not module or not module.bars) then
		print("|cff33ff99", "AzeriteUI /azdebugkeys:", "ActionBars module unavailable")
		return
	end
	print("|cff33ff99", "AzeriteUI key binding dump:")
	for barIndex, bar in pairs(module.bars) do
		if (bar and bar.buttons and bar.config and bar.config.numbuttons and bar.config.numbuttons > 0) then
			local modeCommand = bar.config.useCommandBindingsForHoldCast and true or false
			print("|cfff0f0f0  bar"..tostring(barIndex)..": mode", modeCommand and "command" or "click")
			for buttonIndex = 1, bar.config.numbuttons do
				local button = bar.buttons[buttonIndex]
				if (button) then
					local target = button.keyBoundTarget
					local key1, key2 = nil, nil
					if (type(target) == "string" and target ~= "") then
						key1, key2 = GetBindingKey(target)
					end
					local route = modeCommand and target or ("CLICK " .. tostring(button:GetName()) .. ":LeftButton")
					print("|cfff0f0f0    ", tostring(button:GetName()), "slot", tostring(button._state_action), "bind", tostring(target), "route", tostring(route), "keys", tostring(key1), tostring(key2))
				end
			end
		end
	end
end

local function PrintDebugKeyCooldown(buttonName)
	local button = FindActionButtonByName(buttonName)
	if (not button) then
		local module = GetActionBarsModule()
		if (module and module.bars and module.bars[1] and module.bars[1].buttons) then
			button = module.bars[1].buttons[1]
		end
	end
	if (not button) then
		print("|cff33ff99", "AzeriteUI /azdebugkeys cooldown:", "button not found")
		return
	end
	local actionID = button._state_action
	local actionType, actionToken, subType = nil, nil, nil
	if (type(actionID) == "number" and actionID > 0 and GetActionInfo) then
		actionType, actionToken, subType = GetActionInfo(actionID)
	end
	local cooldownInfo = (type(actionID) == "number" and actionID > 0) and GetActionCooldownInfoSafe(actionID) or nil
	local chargeInfo = (type(actionID) == "number" and actionID > 0) and GetActionChargeInfoSafe(actionID) or nil

	print("|cff33ff99", "AzeriteUI key cooldown debug:")
	print("|cfff0f0f0  button:", tostring(button:GetName()))
	print("|cfff0f0f0  actionID:", tostring(actionID), "actionType:", tostring(actionType), "token:", tostring(actionToken), "subType:", tostring(subType))
	print("|cfff0f0f0  attrs: useOnKeyDown", SecretSafeText(button:GetAttribute("useOnKeyDown")), "pressAndHoldAction", SecretSafeText(button:GetAttribute("pressAndHoldAction")), "typerelease", SecretSafeText(button:GetAttribute("typerelease")))

	if (cooldownInfo) then
		print("|cfff0f0f0  cooldown:", "start", SecretSafeText(cooldownInfo.startTime), "duration", SecretSafeText(cooldownInfo.duration), "modRate", SecretSafeText(cooldownInfo.modRate), "isEnabled", SecretSafeText(cooldownInfo.isEnabled))
	else
		print("|cfff0f0f0  cooldown:", "nil")
	end
	if (chargeInfo) then
		print("|cfff0f0f0  charges:", "cur", SecretSafeText(chargeInfo.currentCharges), "max", SecretSafeText(chargeInfo.maxCharges), "start", SecretSafeText(chargeInfo.cooldownStartTime), "duration", SecretSafeText(chargeInfo.cooldownDuration), "modRate", SecretSafeText(chargeInfo.chargeModRate))
	else
		print("|cfff0f0f0  charges:", "nil")
	end
end

local function PrintDebugHoldTest(spellIDText)
	if (not (C_Spell and C_Spell.IsPressHoldReleaseSpell)) then
		print("|cff33ff99", "AzeriteUI holdtest:", "C_Spell.IsPressHoldReleaseSpell unavailable")
		return
	end
	local spellID = tonumber(spellIDText or "")
	if (not spellID) then
		print("|cff33ff99", "AzeriteUI holdtest:", "spellID required")
		return
	end
	local ok, result = pcall(C_Spell.IsPressHoldReleaseSpell, spellID)
	print("|cff33ff99", "AzeriteUI holdtest:", "spellID", tostring(spellID), "ok", tostring(ok), "pressHold", SecretSafeText(result))
end

Debugging.DebugKeysMenu = function(self, input)
	if (not IsDevMode()) then
		print("|cff33ff99", "AzeriteUI /azdebugkeys:", "Dev mode is off; limited features may apply.")
	end
	local cmd, rest = (input or ""):match("^(%S+)%s*(.-)$")
	cmd = cmd and string_lower(cmd) or "status"

	if (cmd == "help" or cmd == "?") then
		return PrintDebugKeysHelp()
	end
	if (cmd == "status") then
		return PrintDebugKeysStatus()
	end
	if (cmd == "bindings") then
		return PrintDebugKeyBindings()
	end
	if (cmd == "cooldown") then
		local buttonName = rest and rest:match("^(%S+)") or nil
		return PrintDebugKeyCooldown(buttonName)
	end
	if (cmd == "holdtest") then
		local spellIDText = rest and rest:match("^(%S+)") or nil
		return PrintDebugHoldTest(spellIDText)
	end
	local mode = nil
	if (cmd == "on" or cmd == "off" or cmd == "toggle") then
		mode = cmd
	end
	if (mode) then
		local db = ns and ns.db and ns.db.global
		if (db) then
			local current = db.debugKeysVerbose and true or false
			if (mode == "toggle") then
				db.debugKeysVerbose = not current
			elseif (mode == "on") then
				db.debugKeysVerbose = true
			elseif (mode == "off") then
				db.debugKeysVerbose = false
			end
			_G.__AzeriteUI_DEBUG_KEYS = db.debugKeysVerbose and true or false
		end
		print("|cff33ff99", "AzeriteUI /azdebugkeys verbose:", (db and db.debugKeysVerbose) and "ON" or "OFF")
		return
	end
	PrintDebugKeysHelp()
end

local function DumpTexture(tex, label)
	if (not tex) then
		return
	end
	local name = label or SafeCall(tex, "GetName") or "(texture)"
	local path = SafeCall(tex, "GetTexture")
	local width, height = SafeCall(tex, "GetSize")
	local alpha = SafeCall(tex, "GetAlpha")
	local shown = SafeCall(tex, "IsShown")
	local layer, subLayer = SafeCall(tex, "GetDrawLayer")
	local blend = SafeCall(tex, "GetBlendMode")
	local r, g, b, a = SafeCall(tex, "GetVertexColor")
	local t1, t2, t3, t4 = SafeCall(tex, "GetTexCoord")
	local parent = SafeCall(tex, "GetParent")
	local parentName = parent and SafeCall(parent, "GetName") or nil
	SafePrint("|cfff0f0f0  texture:", name, "path:", path)
	SafePrint("|cfff0f0f0   size:", width, height, "alpha:", alpha, "shown:", shown, "layer:", layer, "sub:", subLayer, "blend:", blend)
	SafePrint("|cfff0f0f0   parent:", parentName, "vertex:", r, g, b, a)
	SafePrint("|cfff0f0f0   texcoord:", t1, t2, t3, t4)
	DumpPoints(tex, "   ")
end

local function DumpBar(bar, labelOverride)
	if (not bar) then
		return
	end
	local label = labelOverride or bar.__AzeriteUI_DebugLabel or "(bar)"
	local growth = SafeCall(bar, "GetGrowth")
	local orient = SafeCall(bar, "GetOrientation")
	local flipped = SafeCall(bar, "IsFlippedHorizontally")
	local reverse = SafeCall(bar, "GetReverseFill")
	local min, max = SafeCall(bar, "GetMinMaxValues")
	local value = SafeCall(bar, "GetValue")
	local r1, r2, r3, r4 = SafeCall(bar, "GetRealTexCoord")
	local secretPercent = SafeCall(bar, "GetSecretPercent")
	local debugData = SafeCall(bar, "GetDebugData")
	local width, height = SafeCall(bar, "GetSize")
	local alpha = SafeCall(bar, "GetAlpha")
	local shown = SafeCall(bar, "IsShown")
	local level = SafeCall(bar, "GetFrameLevel")
	local scale = SafeCall(bar, "GetScale")
	local effScale = SafeCall(bar, "GetEffectiveScale")
	local strata = SafeCall(bar, "GetFrameStrata")
	local parent = SafeCall(bar, "GetParent")
	local parentName = parent and SafeCall(parent, "GetName") or nil
	local tex = SafeCall(bar, "GetStatusBarTexture")
	local colorR, colorG, colorB, colorA = SafeCall(bar, "GetStatusBarColor")
	local expectedOrient = bar.__AzeriteUI_ExpectedOrientation
	local expectedFlip = bar.__AzeriteUI_ExpectedFlipped
	local expectedReverse = bar.__AzeriteUI_ExpectedReverseFill
	SafePrint("|cff33ff99", "AzeriteUI bar dump:", label)
	SafePrint("|cfff0f0f0  growth:", growth, "orientation:", orient, "flipped:", flipped, "reverse:", reverse)
	SafePrint("|cfff0f0f0  min/max/value:", min, max, value, "secretPercent:", secretPercent)
	SafePrint("|cfff0f0f0  texcoord:", r1, r2, r3, r4, "color:", colorR, colorG, colorB, colorA)
	SafePrint("|cfff0f0f0  size:", width, height, "alpha:", alpha, "shown:", shown, "level:", level, "parent:", parentName)
	SafePrint("|cfff0f0f0  scale:", scale, "effectiveScale:", effScale, "strata:", strata)
	SafePrint("|cfff0f0f0  flags:", "useBlizzard", bar.__AzeriteUI_UseBlizzard, "expectedOrient", expectedOrient, "expectedFlip", expectedFlip, "expectedReverse", expectedReverse)
	if (bar.__AzeriteUI_CastFakePath or bar.__AzeriteUI_FakeConfiguredAlpha ~= nil or bar.__AzeriteUI_FakeUseStatusBarAlpha ~= nil or bar.__AzeriteUI_FakeUseManualAlpha ~= nil) then
		SafePrint("|cfff0f0f0  castFake:",
			"path", bar.__AzeriteUI_CastFakePath,
			"percent", bar.__AzeriteUI_CastFakePercent,
			"source", bar.__AzeriteUI_CastCropSource,
			"explicit", bar.__AzeriteUI_CastLastExplicitPercent,
			"invert", bar.__AzeriteUI_FakeInvertPercent,
			"alphaCfg", bar.__AzeriteUI_FakeConfiguredAlpha,
			"useStatusAlpha", bar.__AzeriteUI_FakeUseStatusBarAlpha,
			"useManualAlpha", bar.__AzeriteUI_FakeUseManualAlpha,
			"manualAlpha", bar.__AzeriteUI_FakeAlpha)
	end
	if (bar.__AzeriteUI_TargetFakeSource) then
		SafePrint("|cfff0f0f0  healthFake:",
			"source", bar.__AzeriteUI_TargetFakeSource,
			"targetPctSource", bar.__AzeriteUI_TargetPercentSource,
			"invertPct", _G.__AzeriteUI_DEBUG_TARGET_HEALTH_FORCE_INVERT,
			"noInvertPct", _G.__AzeriteUI_DEBUG_TARGET_HEALTH_FORCE_NOINVERT,
			"rawCurSafe", bar.__AzeriteUI_RawCurSafe,
			"rawMaxSafe", bar.__AzeriteUI_RawMaxSafe)
	end
	DumpPoints(bar, "  ")
	DumpTexture(tex, label .. ".StatusBarTexture")
	DumpTexture(bar.FakeFill, label .. ".FakeFill")
	if (debugData) then
		SafePrint("|cfff0f0f0  lib:", "orient", debugData.barOrientation, "revFill", debugData.barBlizzardReverseFill, "revH", debugData.reversedH, "revV", debugData.reversedV, "proxy", debugData.proxyShown)
		if (debugData.proxyTexCoord) then
			SafePrint("|cfff0f0f0  proxy texcoord:", debugData.proxyTexCoord[1], debugData.proxyTexCoord[2], debugData.proxyTexCoord[3], debugData.proxyTexCoord[4])
		end
		if (debugData.proxySize) then
			SafePrint("|cfff0f0f0  proxy size:", debugData.proxySize[1], debugData.proxySize[2])
		end
	end
end

local function DumpArtTextures(container, label)
	if (not container) then
		return
	end
	DumpTexture(container.Backdrop, label .. ".Backdrop")
	DumpTexture(container.Case, label .. ".Case")
	DumpTexture(container.Shade, label .. ".Shade")
	DumpTexture(container.Border, label .. ".Border")
	DumpTexture(container.Overlay, label .. ".Overlay")
	DumpTexture(container.Gloss, label .. ".Gloss")
end

local function DumpUnitBars(frame, name)
	if (not frame) then
		SafePrint("|cff33ff99", "AzeriteUI bar dump:", name, "not found")
		return
	end
	SafePrint("|cff33ff99", "AzeriteUI bar dump:", name)
	SafePrint("|cfff0f0f0  unit:", frame.unit, "style:", frame.currentStyle)
	local fwidth, fheight = SafeCall(frame, "GetSize")
	local fscale = SafeCall(frame, "GetScale")
	local feff = SafeCall(frame, "GetEffectiveScale")
	local fstrata = SafeCall(frame, "GetFrameStrata")
	local flevel = SafeCall(frame, "GetFrameLevel")
	SafePrint("|cfff0f0f0  size:", fwidth, fheight, "scale:", fscale, "effectiveScale:", feff, "strata:", fstrata, "level:", flevel)
	DumpPoints(frame, "  ")
	if (name == "TargetFrame") then
		local cfg = ns.GetConfig("TargetFrame")
		if (cfg) then
			SafePrint("|cfff0f0f0  config:", "IsFlippedHorizontally", cfg.IsFlippedHorizontally)
			if (frame.currentStyle and cfg[frame.currentStyle]) then
				local styleCfg = cfg[frame.currentStyle]
				SafePrint("|cfff0f0f0  style:", frame.currentStyle, "HealthBarOrientation", styleCfg.HealthBarOrientation, "HealthBarTexture", styleCfg.HealthBarTexture)
			end
		end
	end
	DumpBar(frame.Health)
	DumpArtTextures(frame.Health, "Health")
	DumpBar(frame.Health and frame.Health.Preview)
	DumpBar(frame.Castbar)
	DumpBar(frame.HealthPrediction and frame.HealthPrediction.absorbBar, "Target.Absorb")
	DumpBar(frame.Power, "Target.Power")
	DumpArtTextures(frame.Power, "Power")
	DumpBar(frame.ManaOrb, "Player.ManaOrb")
	DumpArtTextures(frame.ManaOrb, "ManaOrb")
end

local function GetUnitFrameModules()
	local mods = {}
	mods[#mods + 1] = ns:GetModule("PlayerFrame", true)
	mods[#mods + 1] = ns:GetModule("TargetFrame", true)
	mods[#mods + 1] = ns:GetModule("ToTFrame", true)
	mods[#mods + 1] = ns:GetModule("PlayerFrameAlternate", true)
	return mods
end

local function PrintScaleStatus()
	local uiScale = SafeCall(UIParent, "GetScale")
	local desired = ns.API.GetEffectiveScale()
	print("|cff33ff99", "AzeriteUI scale status:")
	print("|cfff0f0f0  UIParent scale:", tostring(uiScale), "desired frame scale:", tostring(desired))
	for _, mod in next, GetUnitFrameModules() do
		if (mod and mod.frame) then
			local name = mod.GetName and mod:GetName() or "Unknown"
			local frameScale = SafeCall(mod.frame, "GetScale")
			local eff = SafeCall(mod.frame, "GetEffectiveScale")
			local saved = mod.db and mod.db.profile and mod.db.profile.savedPosition and mod.db.profile.savedPosition.scale or nil
			local anchor = mod.anchor
			local anchorDefault = anchor and anchor.GetDefaultScale and anchor:GetDefaultScale() or nil
			print("|cfff0f0f0  ", name .. ":", "frame", tostring(frameScale), "effective", tostring(eff), "saved", tostring(saved), "anchorDefault", tostring(anchorDefault))
		end
	end
end

local function ResetUnitFrameScales()
	local desired = ns.API.GetEffectiveScale()
	for _, mod in next, GetUnitFrameModules() do
		if (mod and mod.db and mod.db.profile and mod.db.profile.savedPosition) then
			mod.db.profile.savedPosition.scale = desired
			if (mod.UpdatePositionAndScale) then
				mod:UpdatePositionAndScale()
			end
			if (mod.UpdateAnchor) then
				mod:UpdateAnchor()
			end
		end
	end
	print("|cff33ff99", "AzeriteUI unitframe scales reset to:", tostring(desired))
end

local function GetPlayerPowerOffsetProfile()
	local mod = ns:GetModule("PlayerFrame", true)
	local profile = mod and mod.db and mod.db.profile
	if (not profile) then
		return nil, nil
	end
	profile.powerBarOffsetX = tonumber(profile.powerBarOffsetX) or 0
	profile.powerBarOffsetY = tonumber(profile.powerBarOffsetY) or 0
	profile.powerCaseOffsetX = tonumber(profile.powerCaseOffsetX) or 0
	profile.powerCaseOffsetY = tonumber(profile.powerCaseOffsetY) or 0
	return mod, profile
end

local function ApplyPlayerPowerOffsets()
	local mod = ns:GetModule("PlayerFrame", true)
	if (mod and mod.Update) then
		mod:Update()
		return true
	end
	return false
end

local function PrintPlayerPowerOffsets()
	local _, profile = GetPlayerPowerOffsetProfile()
	if (not profile) then
		print("|cff33ff99", "AzeriteUI power offsets:", "PlayerFrame module not available")
		return
	end
	print("|cff33ff99", "AzeriteUI player power offsets:")
	print("|cfff0f0f0  bar:", "x", tostring(profile.powerBarOffsetX), "y", tostring(profile.powerBarOffsetY))
	print("|cfff0f0f0  case:", "x", tostring(profile.powerCaseOffsetX), "y", tostring(profile.powerCaseOffsetY))
end

PrintPlayerOrbDebug = function()
	local mod = ns:GetModule("PlayerFrame", true)
	local frame = mod and mod.frame
	local orb = frame and frame.ManaOrb
	local crystal = frame and frame.Power
	if (not orb) then
		print("|cff33ff99", "AzeriteUI orb debug:", "Player ManaOrb unavailable")
		return
	end

	local tex1, tex2, tex3, tex4 = orb:GetStatusBarTexture()
	local lib = LibStub and LibStub("LibOrb-1.0", true)
	local data = lib and lib.orbs and lib.orbs[orb]
	local native = data and data.nativeStatusBar
	local nativeMin, nativeMax = nil, nil
	local orbText = nil
	if (native and native.GetMinMaxValues) then
		nativeMin, nativeMax = SafeCall(native, "GetMinMaxValues")
	end
	if (orb.Value and orb.Value.GetText) then
		orbText = SafeCall(orb.Value, "GetText")
	end

	print("|cff33ff99", "AzeriteUI player orb debug:")
	SafePrint("|cfff0f0f0  orb:", "shown", SafeCall(orb, "IsShown"), "width", SafeCall(orb, "GetWidth"), "height", SafeCall(orb, "GetHeight"), "alpha", SafeCall(orb, "GetAlpha"))
	SafePrint("|cfff0f0f0  text:", orbText)
	SafePrint("|cfff0f0f0  textures:",
		"t1", tex1 and SafeCall(tex1, "GetTexture"), tex1 and SafeCall(tex1, "IsShown"), tex1 and SafeCall(tex1, "GetAlpha"),
		"t2", tex2 and SafeCall(tex2, "GetTexture"), tex2 and SafeCall(tex2, "IsShown"), tex2 and SafeCall(tex2, "GetAlpha"),
		"t3", tex3 and SafeCall(tex3, "IsShown"), tex3 and SafeCall(tex3, "GetAlpha"),
		"t4", tex4 and SafeCall(tex4, "IsShown"), tex4 and SafeCall(tex4, "GetAlpha"))
	SafePrint("|cfff0f0f0  element:",
		"cur", orb.cur,
		"min", orb.min,
		"max", orb.max,
		"safeCur", orb.safeCur,
		"safeMin", orb.safeMin,
		"safeMax", orb.safeMax,
		"safePct", orb.safePercent)
	SafePrint("|cfff0f0f0  liborb:",
		"barValue", data and data.barValue,
		"barMin", data and data.barMin,
		"barMax", data and data.barMax,
		"barDisplayValue", data and data.barDisplayValue,
		"scrollShown", data and data.scrollframe and SafeCall(data.scrollframe, "IsShown"))
	SafePrint("|cfff0f0f0  native:",
		"value", native and SafeCall(native, "GetValue"),
		"min", nativeMin,
		"max", nativeMax)
	SafePrint("|cfff0f0f0  crystal:",
		"shown", crystal and SafeCall(crystal, "IsShown"),
		"cur", crystal and crystal.cur,
		"safeCur", crystal and crystal.safeCur,
		"safePct", crystal and crystal.safePercent,
		"mirrorPct", crystal and crystal.__AzeriteUI_MirrorPercent,
		"texturePct", crystal and crystal.__AzeriteUI_TexturePercent)
end


local function PrintDebugHelp()
	print("|cff33ff99", "AzeriteUI /azdebug commands:")
	print("|cfff0f0f0  /azdebug|r  (toggle menu)")
	print("|cfff0f0f0  /azdebug status|r")
	print("|cfff0f0f0  /azdebug health [on|off|toggle]|r")
	print("|cfff0f0f0  /azdebug health filter <text>|r  (example: Target.)")
	print("|cfff0f0f0  /azdebug healthchat [on|off|toggle]|r")
	print("|cfff0f0f0  /azdebug bars [on|off|toggle]|r")
	print("|cfff0f0f0  /azdebug fixes [on|off|toggle]|r")
	print("|cfff0f0f0  /azdebug assisted [on|off|toggle|status]|r")
	print("|cfff0f0f0  /azdebug dump target|r")
	print("|cfff0f0f0  /azdebug dump player|r")
	print("|cfff0f0f0  /azdebug dump tot|r")
	print("|cfff0f0f0  /azdebug dump all|r")
	print("|cfff0f0f0  /azdebug snapshot [unit]|r")
	print("|cfff0f0f0  /azdebug blizzard enable|r")
	print("|cfff0f0f0  /azdebug scale|r  (print scale status)")
	print("|cfff0f0f0  /azdebug scale reset|r")
	print("|cfff0f0f0  /azdebug power|r  (print bar/case offsets)")
	print("|cfff0f0f0  /azdebug power bar <x> <y>|r")
	print("|cfff0f0f0  /azdebug power case <x> <y>|r")
	print("|cfff0f0f0  /azdebug power nudge <bar|case> <dx> <dy>|r")
	print("|cfff0f0f0  /azdebug power reset|r")
	print("|cfff0f0f0  /azdebug orb dump|r")
	print("|cfff0f0f0  /azdebug target status|r")
	print("|cfff0f0f0  /azdebug target refresh|r")
	print("|cfff0f0f0  /azdebug keys <status|bindings|cooldown|holdtest>|r")
	print("|cfff0f0f0  /azdebugkeys status|bindings|cooldown|holdtest|on|off|toggle|r")
	print("|cfff0f0f0  /azdebugtarget|r  (toggle target debug menu)")
	print("|cfff0f0f0  /azdebugtarget status|r")
	print("|cfff0f0f0  /azdebugtarget dump|snapshot|refresh|secrettest|help|r")
	print("|cfff0f0f0  /azdebug scripterrors|r")
	print("|cfff0f0f0  /azdebug secrettest [unit]|r")
end

local function ParseOnOffToggle(token)
	if (not token or token == "") then
		return "toggle"
	end
	token = token:lower()
	if (token == "on" or token == "off" or token == "toggle") then
		return token
	end
	return nil
end

local function SetDebugFlag(flag, value)
	if (value == "toggle") then
		return not flag
	end
	if (value == "on") then
		return true
	end
	if (value == "off") then
		return false
	end
	return flag
end

local function UpdateDebugMenu(self)
	local frame = self.DebugFrame
	if (not frame) then
		return
	end
	local filter = ns.API.DEBUG_HEALTH_FILTER
	if (not filter or filter == "") then
		filter = "Target."
		ns.API.DEBUG_HEALTH_FILTER = filter
		if (ns.db and ns.db.global) then
			ns.db.global.debugHealthFilter = filter
		end
	end
	frame.HealthToggle:SetChecked(ns.API.DEBUG_HEALTH and true or false)
	frame.HealthChatToggle:SetChecked(ns.API.DEBUG_HEALTH_CHAT and true or false)
	frame.BarsToggle:SetChecked(_G.__AzeriteUI_DEBUG_BARS and true or false)
	frame.FixesToggle:SetChecked((ns.db and ns.db.global and ns.db.global.debugFixes) and true or false)
	frame.FilterEdit:SetText(filter)
end

Debugging.ToggleDebugMenu = function(self)
	local frame = self.DebugFrame
	local created = false
	if (not frame) then
		frame = CreateFrame("Frame", "AzeriteUI_DebugMenu", UIParent, "BasicFrameTemplateWithInset")
		frame:SetSize(460, 480)
		frame:SetPoint("CENTER", UIParent, "CENTER", 0, 140)
		frame:SetFrameStrata("DIALOG")
		frame:SetClampedToScreen(true)
		frame:SetMovable(true)
		frame:EnableMouse(true)
		frame:RegisterForDrag("LeftButton")
		frame:SetScript("OnDragStart", function(f) f:StartMoving() end)
		frame:SetScript("OnDragStop", function(f) f:StopMovingOrSizing() end)
		frame.TitleText:SetText("AzeriteUI Debug")

		local y = -32
		local function AddHeader(text)
			local label = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
			label:SetPoint("TOPLEFT", 12, y)
			label:SetText(text)
			y = y - 22
			return label
		end

		local function AddToggle(label, onClick, tooltip)
			local btn = CreateFrame("CheckButton", nil, frame, "UICheckButtonTemplate")
			btn:SetPoint("TOPLEFT", 12, y)
			btn.text:SetText(label)
			btn:SetScript("OnClick", onClick)
			if (tooltip) then
				btn:SetScript("OnEnter", function(self)
					GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
					GameTooltip:SetText(tooltip, 1, 1, 1)
					GameTooltip:Show()
				end)
				btn:SetScript("OnLeave", function() GameTooltip:Hide() end)
			end
			y = y - 24
			return btn
		end

		AddHeader("Toggles")

		   frame.HealthToggle = AddToggle("Health debug", function()
			   self:ToggleHealthDebug()
			   UpdateDebugMenu(self)
			   local pf = ns:GetModule("PlayerFrame", true)
			   if pf and pf.Update then pf:Update() end
			   local tf = ns:GetModule("TargetFrame", true)
			   if tf and tf.Update then tf:Update() end
		   end, "Show health debug overlay text on unitframes.")
		   frame.HealthChatToggle = AddToggle("Health debug chat", function()
			   self:ToggleHealthDebugChat()
			   UpdateDebugMenu(self)
			   local pf = ns:GetModule("PlayerFrame", true)
			   if pf and pf.Update then pf:Update() end
			   local tf = ns:GetModule("TargetFrame", true)
			   if tf and tf.Update then tf:Update() end
		   end, "Print health/statusbar debug output to chat.")
		   frame.BarsToggle = AddToggle("Statusbar/orb debug", function()
			   self:ToggleBarsDebug()
			   UpdateDebugMenu(self)
			   local pf = ns:GetModule("PlayerFrame", true)
			   if pf and pf.Update then pf:Update() end
			   local tf = ns:GetModule("TargetFrame", true)
			   if tf and tf.Update then tf:Update() end
		   end, "Enable LibSmoothBar/LibOrb debug output.")
		   frame.FixesToggle = AddToggle("FixBlizzardBugs debug", function()
			   self:ToggleFixesDebug()
			   UpdateDebugMenu(self)
			   local pf = ns:GetModule("PlayerFrame", true)
			   if pf and pf.Update then pf:Update() end
			   local tf = ns:GetModule("TargetFrame", true)
			   if tf and tf.Update then tf:Update() end
		   end, "Enable FixBlizzardBugs debug counters in chat.")

		y = y - 6

		AddHeader("Health Filter")
		local filterLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		filterLabel:SetPoint("TOPLEFT", 12, y - 4)
		filterLabel:SetText("Prefix filter:")

		frame.FilterEdit = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
		frame.FilterEdit:SetSize(200, 20)
		frame.FilterEdit:SetPoint("LEFT", filterLabel, "RIGHT", 8, 0)
		frame.FilterEdit:SetAutoFocus(false)
		local currentFilter = ns.API.DEBUG_HEALTH_FILTER
		if (not currentFilter or currentFilter == "") then
			currentFilter = "Target."
		end
		frame.FilterEdit:SetText(currentFilter)
		frame.FilterEdit:SetScript("OnEnterPressed", function(edit)
			local text = edit:GetText()
			if (not text or text == "") then
				text = "Target."
			end
			ns.API.DEBUG_HEALTH_FILTER = text
			if (ns.db and ns.db.global) then
				ns.db.global.debugHealthFilter = text
			end
			edit:ClearFocus()
		end)
		local filterApply = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
		filterApply:SetSize(70, 20)
		filterApply:SetPoint("LEFT", frame.FilterEdit, "RIGHT", 6, 0)
		filterApply:SetText("Set")
		filterApply:SetScript("OnClick", function()
			local text = frame.FilterEdit:GetText()
			if (not text or text == "") then
				text = "Target."
			end
			ns.API.DEBUG_HEALTH_FILTER = text
			if (ns.db and ns.db.global) then
				ns.db.global.debugHealthFilter = text
			end
			frame.FilterEdit:SetText(text)
		end)
		local filterReset = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
		filterReset:SetSize(70, 20)
		filterReset:SetPoint("LEFT", filterApply, "RIGHT", 6, 0)
		filterReset:SetText("Reset")
		filterReset:SetScript("OnClick", function()
			local text = "Target."
			ns.API.DEBUG_HEALTH_FILTER = text
			if (ns.db and ns.db.global) then
				ns.db.global.debugHealthFilter = text
			end
			frame.FilterEdit:SetText(text)
		end)
		y = y - 34

		AddHeader("Dumps")
		local dumpTarget = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
		dumpTarget:SetSize(130, 22)
		dumpTarget:SetPoint("TOPLEFT", 12, y)
		dumpTarget:SetText("Dump Target Bars")
		dumpTarget:SetScript("OnClick", function()
			local targetFrame = ns:GetModule("TargetFrame", true)
			DumpUnitBars(targetFrame and targetFrame.frame, "TargetFrame")
		end)

		local dumpPlayer = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
		dumpPlayer:SetSize(130, 22)
		dumpPlayer:SetPoint("LEFT", dumpTarget, "RIGHT", 12, 0)
		dumpPlayer:SetText("Dump Player Bars")
		dumpPlayer:SetScript("OnClick", function()
			local playerFrame = ns:GetModule("PlayerFrame", true)
			DumpUnitBars(playerFrame and playerFrame.frame, "PlayerFrame")
		end)
		local dumpToT = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
		dumpToT:SetSize(130, 22)
		dumpToT:SetPoint("LEFT", dumpPlayer, "RIGHT", 12, 0)
		dumpToT:SetText("Dump ToT Bars")
		dumpToT:SetScript("OnClick", function()
			local totFrame = ns:GetModule("ToTFrame", true)
			DumpUnitBars(totFrame and totFrame.frame, "ToTFrame")
		end)
		   y = y - 28

		   local dumpAll = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
		   dumpAll:SetSize(130, 22)
		   dumpAll:SetPoint("TOPLEFT", 12, y)
		   dumpAll:SetText("Dump All Bars")
		   dumpAll:SetScript("OnClick", function()
			   local targetFrame = ns:GetModule("TargetFrame", true)
			   local playerFrame = ns:GetModule("PlayerFrame", true)
			   local totFrame = ns:GetModule("ToTFrame", true)
			   DumpUnitBars(targetFrame and targetFrame.frame, "TargetFrame")
			   DumpUnitBars(playerFrame and playerFrame.frame, "PlayerFrame")
			   DumpUnitBars(totFrame and totFrame.frame, "ToTFrame")
		   end)

		   y = y - 32

		   -- Reattach movement modules for healthbar and castbar
		   local function ReattachMovementModules(unit)
			   local mod = ns:GetModule(unit, true)
			   if mod and mod.frame then
				   if mod.frame.Health and mod.frame.Health.AttachMovementModule then
					   mod.frame.Health:AttachMovementModule()
					   print("|cff33ff99", unit .. " Healthbar movement module reattached.")
				   end
				   if mod.frame.Castbar and mod.frame.Castbar.AttachMovementModule then
					   mod.frame.Castbar:AttachMovementModule()
					   print("|cff33ff99", unit .. " Castbar movement module reattached.")
				   end
			   else
				   print("|cff33ff99", unit .. " frame not found.")
			   end
		   end

		   local reattachPlayerBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
		   reattachPlayerBtn:SetSize(170, 22)
		   reattachPlayerBtn:SetPoint("TOPLEFT", 12, y)
		   reattachPlayerBtn:SetText("Reattach PlayerFrame Bars")
		   reattachPlayerBtn:SetScript("OnClick", function()
			   ReattachMovementModules("PlayerFrame")
		   end)

		   local reattachTargetBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
		   reattachTargetBtn:SetSize(170, 22)
		   reattachTargetBtn:SetPoint("LEFT", reattachPlayerBtn, "RIGHT", 12, 0)
		   reattachTargetBtn:SetText("Reattach TargetFrame Bars")
		   reattachTargetBtn:SetScript("OnClick", function()
			   ReattachMovementModules("TargetFrame")
		   end)

		   y = y - 28
		AddHeader("Utilities")
		local statusBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
		statusBtn:SetSize(130, 22)
		statusBtn:SetPoint("TOPLEFT", 12, y)
		statusBtn:SetText("Print Status")
		statusBtn:SetScript("OnClick", function()
			Debugging.DebugMenu(self, "status")
		end)
		local enableBlizz = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
		enableBlizz:SetSize(150, 22)
		enableBlizz:SetPoint("LEFT", statusBtn, "RIGHT", 12, 0)
		enableBlizz:SetText("Enable Blizzard AddOns")
		enableBlizz:SetScript("OnClick", function()
			self:EnableBlizzardAddOns()
		end)
		y = y - 28

		local helpBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
		helpBtn:SetSize(70, 22)
		helpBtn:SetPoint("TOPLEFT", 12, y)
		helpBtn:SetText("Help")
		helpBtn:SetScript("OnClick", function()
			PrintDebugHelp()
		end)
		local errorsBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
		errorsBtn:SetSize(140, 22)
		errorsBtn:SetPoint("LEFT", helpBtn, "RIGHT", 12, 0)
		errorsBtn:SetText("Enable Script Errors")
		errorsBtn:SetScript("OnClick", function()
			self:EnableScriptErrors()
			print("|cff33ff99", "AzeriteUI script errors:", "ENABLED (CVar scriptErrors=1)")
		end)
		y = y - 28

		local scaleStatus = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
		scaleStatus:SetSize(120, 22)
		scaleStatus:SetPoint("TOPLEFT", 12, y)
		scaleStatus:SetText("Scale Status")
		scaleStatus:SetScript("OnClick", function()
			PrintScaleStatus()
		end)
		local scaleReset = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
		scaleReset:SetSize(180, 22)
		scaleReset:SetPoint("LEFT", scaleStatus, "RIGHT", 12, 0)
		scaleReset:SetText("Reset UnitFrame Scales")
		scaleReset:SetScript("OnClick", function()
			ResetUnitFrameScales()
		end)
		y = y - 28

		local targetStatusBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
		targetStatusBtn:SetSize(170, 22)
		targetStatusBtn:SetPoint("TOPLEFT", 12, y)
		targetStatusBtn:SetText("Target Fill Status")
		targetStatusBtn:SetScript("OnClick", function()
			Debugging.DebugMenu(self, "target status")
		end)
		local targetResetBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
		targetResetBtn:SetSize(170, 22)
		targetResetBtn:SetPoint("LEFT", targetStatusBtn, "RIGHT", 12, 0)
		targetResetBtn:SetText("Refresh Target")
		targetResetBtn:SetScript("OnClick", function()
			Debugging.DebugMenu(self, "target refresh")
		end)
		y = y - 28
		local targetMenuBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
		targetMenuBtn:SetSize(170, 22)
		targetMenuBtn:SetPoint("TOPLEFT", 12, y)
		targetMenuBtn:SetText("Open Target Debug Menu")
		targetMenuBtn:SetScript("OnClick", function()
			self:ToggleTargetDebugMenu()
		end)
		y = y - 28

		local secretLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		secretLabel:SetPoint("TOPLEFT", 12, y - 4)
		secretLabel:SetText("Secret test unit:")
		frame.SecretEdit = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
		frame.SecretEdit:SetSize(120, 20)
		frame.SecretEdit:SetPoint("LEFT", secretLabel, "RIGHT", 8, 0)
		frame.SecretEdit:SetAutoFocus(false)
		frame.SecretEdit:SetText("player")
		local secretRun = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
		secretRun:SetSize(90, 20)
		secretRun:SetPoint("LEFT", frame.SecretEdit, "RIGHT", 6, 0)
		secretRun:SetText("Run")
		secretRun:SetScript("OnClick", function()
			local unit = frame.SecretEdit:GetText()
			self:SecretValueTest(unit)
		end)
		y = y - 24

		local close = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
		close:SetSize(80, 22)
		close:SetPoint("BOTTOMRIGHT", -12, 12)
		close:SetText("Close")
		close:SetScript("OnClick", function() frame:Hide() end)

		self.DebugFrame = frame
		created = true
	end

	if (created) then
		UpdateDebugMenu(self)
		frame:Show()
		return
	end

	if (frame:IsShown()) then
		frame:Hide()
	else
		UpdateDebugMenu(self)
		frame:Show()
	end
end

local function UpdateTargetDebugMenu(self)
	return
end

Debugging.ToggleTargetDebugMenu = function(self)
	local frame = self.TargetDebugFrame
	local created = false
	if (not frame) then
		frame = CreateFrame("Frame", "AzeriteUI_TargetDebugMenu", UIParent, "BasicFrameTemplateWithInset")
		frame:SetSize(520, 240)
		frame:SetPoint("CENTER", UIParent, "CENTER", 0, 40)
		frame:SetFrameStrata("DIALOG")
		frame:SetClampedToScreen(true)
		frame:SetMovable(true)
		frame:EnableMouse(true)
		frame:RegisterForDrag("LeftButton")
		frame:SetScript("OnDragStart", function(f) f:StartMoving() end)
		frame:SetScript("OnDragStop", function(f) f:StopMovingOrSizing() end)
		frame.TitleText:SetText("AzeriteUI Target Debug")
		local actionsY = -52
		local actionsHeader = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
		actionsHeader:SetPoint("TOPLEFT", 12, actionsY)
		actionsHeader:SetText("Actions")
		actionsY = actionsY - 26

		local statusBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
		statusBtn:SetSize(120, 22)
		statusBtn:SetPoint("TOPLEFT", 12, actionsY)
		statusBtn:SetText("Print Status")
		statusBtn:SetScript("OnClick", function()
			self:TargetDebugMenu("status")
		end)

		local refreshBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
		refreshBtn:SetSize(120, 22)
		refreshBtn:SetPoint("LEFT", statusBtn, "RIGHT", 8, 0)
		refreshBtn:SetText("Force Refresh")
		refreshBtn:SetScript("OnClick", function()
			RefreshTargetDebugTestFrames()
			print("|cff33ff99", "AzeriteUI target fill debug:", "target frame refreshed")
		end)

		local dumpBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
		dumpBtn:SetSize(120, 22)
		dumpBtn:SetPoint("LEFT", refreshBtn, "RIGHT", 8, 0)
		dumpBtn:SetText("Dump Target")
		dumpBtn:SetScript("OnClick", function()
			self:DebugMenu("dump target")
		end)

		local snapshotBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
		snapshotBtn:SetSize(120, 22)
		snapshotBtn:SetPoint("TOPLEFT", 12, actionsY - 28)
		snapshotBtn:SetText("Snapshot Target")
		snapshotBtn:SetScript("OnClick", function()
			self:DebugMenu("snapshot target")
		end)

		local secretBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
		secretBtn:SetSize(120, 22)
		secretBtn:SetPoint("LEFT", snapshotBtn, "RIGHT", 8, 0)
		secretBtn:SetText("Secret Test")
		secretBtn:SetScript("OnClick", function()
			self:SecretValueTest("target")
		end)

		local helpBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
		helpBtn:SetSize(120, 22)
		helpBtn:SetPoint("LEFT", secretBtn, "RIGHT", 8, 0)
		helpBtn:SetText("Print Help")
		helpBtn:SetScript("OnClick", function()
			self:TargetDebugMenu("help")
		end)

		local close = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
		close:SetSize(80, 22)
		close:SetPoint("BOTTOMRIGHT", -12, 12)
		close:SetText("Close")
		close:SetScript("OnClick", function() frame:Hide() end)

		self.TargetDebugFrame = frame
		created = true
	end

	if (created) then
		UpdateTargetDebugMenu(self)
		frame:Show()
		return
	end

	if (frame:IsShown()) then
		frame:Hide()
	else
		UpdateTargetDebugMenu(self)
		frame:Show()
	end
end

Debugging.TargetDebugMenu = function(self, input)
	if (not IsDevMode()) then
		print("|cff33ff99", "AzeriteUI /azdebugtarget:", "Dev mode is off; limited features may apply.")
	end
	if (not input or input == "") then
		return self:ToggleTargetDebugMenu()
	end
	local cmd, rest = input:match("^(%S+)%s*(.-)$")
	cmd = cmd and cmd:lower() or "status"
	if (cmd == "menu") then
		return self:ToggleTargetDebugMenu()
	end
	if (cmd == "help" or cmd == "?") then
		print("|cff33ff99", "AzeriteUI /azdebugtarget commands:")
		print("|cfff0f0f0  /azdebugtarget|r  (toggle menu)")
		print("|cfff0f0f0  /azdebugtarget status|r")
		print("|cfff0f0f0  /azdebugtarget dump|snapshot|refresh|secrettest|r")
		return
	end
	if (cmd == "status") then
		return PrintTargetFillDebugStatus()
	end
	if (cmd == "dump") then
		return self:DebugMenu("dump target")
	end
	if (cmd == "snapshot") then
		return self:DebugMenu("snapshot target")
	end
	if (cmd == "refresh") then
		RefreshTargetDebugTestFrames()
		print("|cff33ff99", "AzeriteUI target fill debug:", "target frame refreshed")
		return
	end
	if (cmd == "secrettest") then
		return self:SecretValueTest("target")
	end
	return self:TargetDebugMenu("help")
end

Debugging.DebugMenu = function(self, input)
	if (not IsDevMode()) then
		print("|cff33ff99", "AzeriteUI /azdebug:", "Dev mode is off; limited features may apply.")
	end
	if (not input or input == "") then
		return self:ToggleDebugMenu()
	end
	local cmd, rest = input:match("^(%S+)%s*(.-)$")
	cmd = cmd and cmd:lower() or "status"
	if (cmd == "menu") then
		return self:ToggleDebugMenu()
	end
	if (cmd == "help" or cmd == "?") then
		return PrintDebugHelp()
	end
	if (cmd == "status") then
		local filter = ns.API.DEBUG_HEALTH_FILTER
		if (not filter or filter == "") then
			filter = "Target."
		end
		print("|cff33ff99", "AzeriteUI debug status:")
		print("|cfff0f0f0  health:", ns.API.DEBUG_HEALTH and "ON" or "OFF", "filter:", filter)
		print("|cfff0f0f0  healthchat:", ns.API.DEBUG_HEALTH_CHAT and "ON" or "OFF")
		print("|cfff0f0f0  bars:", (_G.__AzeriteUI_DEBUG_BARS and "ON" or "OFF"))
		print("|cfff0f0f0  fixes:", (ns.db and ns.db.global and ns.db.global.debugFixes) and "ON" or "OFF")
		local LAB = LibStub("LibActionButton-1.0-GE", true)
		if LAB and LAB.GetAssistedCombatDebug then
			print("|cfff0f0f0  assisted:", LAB.GetAssistedCombatDebug() and "ON" or "OFF")
		end
		print("|cff33ff99", "AzeriteUI target fill debug:")
		PrintTargetFillDebugStatus()
		return
	end
	if (cmd == "health") then
		local sub, arg = rest:match("^(%S+)%s*(.-)$")
		sub = sub and sub:lower()
		if (sub == "filter") then
			if (arg and arg ~= "") then
				ns.API.DEBUG_HEALTH_FILTER = arg
				if (ns.db and ns.db.global) then
					ns.db.global.debugHealthFilter = arg
				end
				print("|cff33ff99", "AzeriteUI health debug filter:", arg)
			else
				print("|cff33ff99", "AzeriteUI health debug filter:", ns.API.DEBUG_HEALTH_FILTER or "Target.")
			end
			return
		end
		local mode = ParseOnOffToggle(sub)
		if (not mode) then
			return PrintDebugHelp()
		end
		ns.API.DEBUG_HEALTH = SetDebugFlag(ns.API.DEBUG_HEALTH, mode)
		if (ns.db and ns.db.global) then
			ns.db.global.debugHealth = ns.API.DEBUG_HEALTH
		end
		print("|cff33ff99", "AzeriteUI health debug:", ns.API.DEBUG_HEALTH and "ON" or "OFF")
		local oUF = ns.oUF
		if (oUF and oUF.objects) then
			for _, obj in next, oUF.objects do
				local dbg = obj.HealthDebug
				if (dbg) then
					if (ns.API.DEBUG_HEALTH) then dbg:Show() else dbg:Hide() end
				end
			end
		end
		return
	end
	if (cmd == "healthchat") then
		local mode = ParseOnOffToggle(rest)
		if (not mode) then
			return PrintDebugHelp()
		end
		ns.API.DEBUG_HEALTH_CHAT = SetDebugFlag(ns.API.DEBUG_HEALTH_CHAT, mode)
		if (ns.db and ns.db.global) then
			ns.db.global.debugHealthChat = ns.API.DEBUG_HEALTH_CHAT
		end
		print("|cff33ff99", "AzeriteUI health debug chat:", ns.API.DEBUG_HEALTH_CHAT and "ON" or "OFF")
		return
	end
	if (cmd == "bars") then
		local mode = ParseOnOffToggle(rest)
		if (not mode) then
			return PrintDebugHelp()
		end
		_G.__AzeriteUI_DEBUG_BARS = SetDebugFlag(_G.__AzeriteUI_DEBUG_BARS and true or false, mode)
		if (ns.db and ns.db.global) then
			ns.db.global.debugBars = _G.__AzeriteUI_DEBUG_BARS and true or false
		end
		print("|cff33ff99", "AzeriteUI statusbar/orb debug:", _G.__AzeriteUI_DEBUG_BARS and "ON" or "OFF")
		print("|cff33ff99", "Tip:", "Reproduce damage/retarget; logs will appear in chat.")
		return
	end
	if (cmd == "fixes") then
		local mode = ParseOnOffToggle(rest)
		if (not mode) then
			return PrintDebugHelp()
		end
		if (ns.db and ns.db.global) then
			ns.db.global.debugFixes = SetDebugFlag(ns.db.global.debugFixes, mode)
			print("|cff33ff99", "AzeriteUI FixBlizzardBugs debug:", ns.db.global.debugFixes and "ON" or "OFF")
		end
		return
	end
	if (cmd == "assisted") then
		local LAB = LibStub("LibActionButton-1.0-GE", true)
		if not LAB then
			print("|cffff0000[AzeriteUI]|r LibActionButton-1.0-GE not found")
			return
		end
		local sub = rest:match("^(%S+)")
		if sub and sub:lower() == "status" then
			local isAvailable, nextSpellID = LAB.GetAssistedCombatStatus()
			local debugEnabled = LAB.GetAssistedCombatDebug()
			print("|cff33ff99", "AzeriteUI Assisted Combat Status:")
			print("|cfff0f0f0  Debug:", debugEnabled and "ON" or "OFF")
			print("|cfff0f0f0  Available:", isAvailable and "YES" or "NO")
			print("|cfff0f0f0  Next spell ID:", nextSpellID or "none")
			if not isAvailable then
				local isAvailableResult, failureReason = C_AssistedCombat and C_AssistedCombat.IsAvailable and C_AssistedCombat.IsAvailable()
				if failureReason then
					print("|cfff0f0f0  Reason:", failureReason)
				end
			end
			return
		end
		local mode = ParseOnOffToggle(sub)
		if (not mode) then
			return PrintDebugHelp()
		end
		local newState = SetDebugFlag(LAB.GetAssistedCombatDebug(), mode)
		LAB.SetAssistedCombatDebug(newState)
		if (ns.db and ns.db.global) then
			ns.db.global.debugAssisted = newState
		end
		print("|cff33ff99", "AzeriteUI Assisted Combat debug:", newState and "ON" or "OFF")
		if newState then
			print("|cff33ff99", "Tip:", "Watch for assisted combat messages in chat.")
		end
		return
	end
	if (cmd == "target") then
		return self:TargetDebugMenu(rest)
	end
	if (cmd == "keys") then
		return self:DebugKeysMenu(rest)
	end
	if (cmd == "dump") then
		local sub = rest:match("^(%S+)")
		if (sub and sub:lower() == "target") then
			local targetFrame = ns:GetModule("TargetFrame", true)
			return DumpUnitBars(targetFrame and targetFrame.frame, "TargetFrame")
		end
		if (sub and sub:lower() == "player") then
			local playerFrame = ns:GetModule("PlayerFrame", true)
			return DumpUnitBars(playerFrame and playerFrame.frame, "PlayerFrame")
		end
		if (sub and (sub:lower() == "tot" or sub:lower() == "targetoftarget")) then
			local totFrame = ns:GetModule("ToTFrame", true)
			return DumpUnitBars(totFrame and totFrame.frame, "ToTFrame")
		end
		if (sub and sub:lower() == "all") then
			local targetFrame = ns:GetModule("TargetFrame", true)
			local playerFrame = ns:GetModule("PlayerFrame", true)
			local totFrame = ns:GetModule("ToTFrame", true)
			DumpUnitBars(targetFrame and targetFrame.frame, "TargetFrame")
			DumpUnitBars(playerFrame and playerFrame.frame, "PlayerFrame")
			return DumpUnitBars(totFrame and totFrame.frame, "ToTFrame")
		end
		return PrintDebugHelp()
	end
	if (cmd == "snapshot") then
		local unit = rest:match("^(%S+)")
		return DumpUnitSnapshot(unit)
	end
	if (cmd == "blizzard") then
		local sub = rest:match("^(%S+)")
		if (sub and sub:lower() == "enable") then
			return self:EnableBlizzardAddOns()
		end
		return PrintDebugHelp()
	end
	if (cmd == "scale") then
		local sub = rest:match("^(%S+)")
		if (sub and sub:lower() == "reset") then
			return ResetUnitFrameScales()
		end
		return PrintScaleStatus()
	end
	if (cmd == "power") then
		local sub, args = rest:match("^(%S+)%s*(.-)$")
		sub = sub and sub:lower() or ""

		local mod, profile = GetPlayerPowerOffsetProfile()
		if (not profile) then
			print("|cff33ff99", "AzeriteUI power offsets:", "PlayerFrame module not available")
			return
		end
		if (sub == "" or sub == "status") then
			return PrintPlayerPowerOffsets()
		end
		if (sub == "reset") then
			profile.powerBarOffsetX = 0
			profile.powerBarOffsetY = 0
			profile.powerCaseOffsetX = 0
			profile.powerCaseOffsetY = 0
			ApplyPlayerPowerOffsets()
			print("|cff33ff99", "AzeriteUI player power offsets reset.")
			return PrintPlayerPowerOffsets()
		end
		if (sub == "bar" or sub == "case") then
			local xText, yText = args:match("^([%-+]?[%d%.]+)%s+([%-+]?[%d%.]+)$")
			local x = tonumber(xText)
			local y = tonumber(yText)
			if (not x or not y) then
				return PrintDebugHelp()
			end
			if (sub == "bar") then
				profile.powerBarOffsetX = x
				profile.powerBarOffsetY = y
			else
				profile.powerCaseOffsetX = x
				profile.powerCaseOffsetY = y
			end
			ApplyPlayerPowerOffsets()
			return PrintPlayerPowerOffsets()
		end
		if (sub == "nudge") then
			local target, dxText, dyText = args:match("^(%S+)%s+([%-+]?[%d%.]+)%s+([%-+]?[%d%.]+)$")
			target = target and target:lower() or nil
			local dx = tonumber(dxText)
			local dy = tonumber(dyText)
			if ((target ~= "bar" and target ~= "case") or not dx or not dy) then
				return PrintDebugHelp()
			end
			if (target == "bar") then
				profile.powerBarOffsetX = profile.powerBarOffsetX + dx
				profile.powerBarOffsetY = profile.powerBarOffsetY + dy
			else
				profile.powerCaseOffsetX = profile.powerCaseOffsetX + dx
				profile.powerCaseOffsetY = profile.powerCaseOffsetY + dy
			end
			ApplyPlayerPowerOffsets()
			return PrintPlayerPowerOffsets()
		end
		if (mod) then
			PrintPlayerPowerOffsets()
		end
		return PrintDebugHelp()
	end
    if (cmd == "orb") then
        local sub = rest:match("^(%S+)")
        sub = sub and sub:lower() or "dump"
        if (sub == "dump" or sub == "status") then
            return PrintPlayerOrbDebug()
        end
        return PrintDebugHelp()
    end
	if (cmd == "scripterrors") then
		self:EnableScriptErrors()
		print("|cff33ff99", "AzeriteUI script errors:", "ENABLED (CVar scriptErrors=1)")
		return
	end
	if (cmd == "secrettest") then
		return self:SecretValueTest(rest)
	end

	PrintDebugHelp()
end

Debugging.ToggleBarsDebug = function(self)
	local current = _G.__AzeriteUI_DEBUG_BARS and true or false
	_G.__AzeriteUI_DEBUG_BARS = not current
	if (ns.db and ns.db.global) then
		ns.db.global.debugBars = _G.__AzeriteUI_DEBUG_BARS
	end
	print("|cff33ff99", "AzeriteUI statusbar/orb debug:", _G.__AzeriteUI_DEBUG_BARS and "ON" or "OFF")
	print("|cff33ff99", "Tip:", "Reproduce damage/retarget; logs will appear in chat.")
end

Debugging.ToggleFixesDebug = function(self)
	if (not IsDevMode()) then
		print("|cff33ff99", "AzeriteUI FixBlizzardBugs debug:", "Dev mode only")
		return
	end
	if (ns.db and ns.db.global) then
		ns.db.global.debugFixes = not ns.db.global.debugFixes
		print("|cff33ff99", "AzeriteUI FixBlizzardBugs debug:", ns.db.global.debugFixes and "ON" or "OFF")
	end
end

Debugging.SecretValueTest = function(self, input)
	if (not IsDevMode()) then
		print("|cff33ff99", "AzeriteUI secret test:", "Dev mode only")
		return
	end
	local unit = (type(input) == "string" and input ~= "" and input) or "target"
	if (not UnitExists(unit)) then
		print("|cff33ff99", "AzeriteUI secret test:", "unit unavailable:", tostring(unit))
		return
	end
	local health = UnitHealth and UnitHealth(unit)
	local maxHealth = UnitHealthMax and UnitHealthMax(unit)
	local powerType = UnitPowerType and select(1, UnitPowerType(unit)) or 0
	local power = UnitPower and UnitPower(unit, powerType)
	local maxPower = UnitPowerMax and UnitPowerMax(unit, powerType)
	print("|cff33ff99", "AzeriteUI secret test:", unit)
	print("|cfff0f0f0  health:", tostring(health), "max:", tostring(maxHealth), "secret:", tostring(issecretvalue and issecretvalue(health) or false))
	print("|cfff0f0f0  power:", tostring(power), "max:", tostring(maxPower), "type:", tostring(powerType), "secret:", tostring(issecretvalue and issecretvalue(power) or false))
end
