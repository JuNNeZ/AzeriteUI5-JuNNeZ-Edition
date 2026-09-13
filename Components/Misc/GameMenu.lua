--[[

	The MIT License (MIT)

	Copyright (c) 2026 Lars Norberg

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

local GameMenuSkin = ns:NewModule("GameMenuSkin", "AceHook-3.0")

local L = LibStub("AceLocale-3.0"):GetLocale((...))

-- GLOBALS: C_AddOns, C_Timer, GameMenuFrame, ReloadUI, StaticPopupDialogs, StaticPopup_Show, UnitName

-- Lua API
local ipairs = ipairs
local pairs = pairs
local string_format = string.format
local type = type
local unpack = unpack

-- Addon API
local GetFont = ns.API.GetFont
local GetMedia = ns.API.GetMedia
local IsAddOnEnabled = ns.API.IsAddOnEnabled
local UIHider = ns.Hider

local defaults = {
	-- Per character rather than per profile: the choice can turn another addon
	-- off, and addons are enabled and disabled per character.
	--   owner: nil or "azeriteui" styles the menu, "blizzard" leaves it alone,
	--          and "other" leaves it to the addon in `rival` while that is enabled.
	--   rival: folder name of the other addon the choice was made about.
	char = {}
}

local function IsGameMenuButton(button)
	if (not button or button:GetParent() ~= GameMenuFrame) then
		return false
	end
	if (button.GetObjectType and button:GetObjectType() ~= "Button") then
		return false
	end
	return (button.Left and button.Middle and button.Right and button.GetText) and true or false
end

local function SkinButton(button)
	if (not IsGameMenuButton(button) or button.__AzeriteUI_GameMenuSkinned) then
		return
	end
	button.__AzeriteUI_GameMenuSkinned = true

	if (button.Left) then button.Left:SetAlpha(0) end
	if (button.Middle) then button.Middle:SetAlpha(0) end
	if (button.Right) then button.Right:SetAlpha(0) end

	local backdrop = CreateFrame("Frame", nil, button, ns.BackdropTemplate)
	backdrop:SetPoint("TOPLEFT", button, "TOPLEFT", 0, 0)
	backdrop:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 0, 0)
	backdrop:SetFrameLevel(button:GetFrameLevel() - 1)
	backdrop:SetBackdrop({
		bgFile = [[Interface\Tooltips\UI-Tooltip-Background]],
		edgeFile = GetMedia("border-tooltip"),
		edgeSize = 16,
		insets = { left = 5, right = 5, top = 5, bottom = 5 }
	})
	backdrop:SetBackdropColor(.05, .05, .05, .92)
	backdrop:SetBackdropBorderColor(.35, .35, .35, .95)
	button.__AzeriteUI_GameMenuBackdrop = backdrop

	local text = button:GetFontString() or button.Text
	if (text) then
		text:SetFontObject(GetFont(14, true))
	end

	button:HookScript("OnEnter", function(self)
		local bg = self.__AzeriteUI_GameMenuBackdrop
		if (bg) then
			bg:SetBackdropBorderColor(unpack(ns.Colors.highlight))
		end
	end)
	button:HookScript("OnLeave", function(self)
		local bg = self.__AzeriteUI_GameMenuBackdrop
		if (bg) then
			bg:SetBackdropBorderColor(.35, .35, .35, .95)
		end
	end)
end

local function SkinFrame()
	if (not GameMenuFrame or GameMenuFrame:IsForbidden()) then
		return
	end

	if (not GameMenuFrame.__AzeriteUI_GameMenuArtStripped) then
		GameMenuFrame.__AzeriteUI_GameMenuArtStripped = true

		-- Remove legacy Blizzard frame regions that can survive NineSlice hiding.
		for _, region in ipairs({ GameMenuFrame:GetRegions() }) do
			if (region and region.GetObjectType and region:GetObjectType() == "Texture") then
				region:SetTexture(nil)
				region:SetAlpha(0)
				region:Hide()
			end
		end
	end

	if (GameMenuFrame.NineSlice and GameMenuFrame.NineSlice.GetParent and GameMenuFrame.NineSlice:GetParent() ~= UIHider) then
		GameMenuFrame.NineSlice:SetParent(UIHider)
	end
	if (GameMenuFrame.Border) then
		GameMenuFrame.Border:SetAlpha(0)
		GameMenuFrame.Border:Hide()
	end
	if (GameMenuFrame.Background) then
		GameMenuFrame.Background:SetAlpha(0)
		GameMenuFrame.Background:Hide()
	end
	if (GameMenuFrameHeader) then
		GameMenuFrameHeader:Hide()
	end

	if (not GameMenuFrame.__AzeriteUI_GameMenuBackdrop) then
		local frameBackdrop = CreateFrame("Frame", nil, GameMenuFrame, ns.BackdropTemplate)
		frameBackdrop:SetPoint("TOPLEFT", GameMenuFrame, "TOPLEFT", -8, 8)
		frameBackdrop:SetPoint("BOTTOMRIGHT", GameMenuFrame, "BOTTOMRIGHT", 8, -8)
		frameBackdrop:SetFrameLevel(GameMenuFrame:GetFrameLevel() - 1)
		frameBackdrop:SetBackdrop({
			bgFile = [[Interface\Tooltips\UI-Tooltip-Background]],
			edgeFile = GetMedia("border-tooltip"),
			edgeSize = 24,
			insets = { left = 7, right = 7, top = 7, bottom = 7 }
		})
		frameBackdrop:SetBackdropColor(.03, .03, .03, .95)
		frameBackdrop:SetBackdropBorderColor(.25, .25, .25, .95)
		GameMenuFrame.__AzeriteUI_GameMenuBackdrop = frameBackdrop
	end

	for _, child in ipairs({ GameMenuFrame:GetChildren() }) do
		if (child and child.IsShown and child:IsShown()) then
			SkinButton(child)
		end
	end
end

-- True when one of the menu's child frames carries the given key.
local function HasChildWithKey(key)
	for _, child in ipairs({ GameMenuFrame:GetChildren() }) do
		if (not (child.IsForbidden and child:IsForbidden()) and child[key]) then
			return true
		end
	end
	return false
end

-- Addons known to restyle the game menu, each paired with a check that its style
-- is really on the frame. Most of them style the menu only behind a setting of
-- their own, so an enabled addon is not a clash by itself. The markers are read
-- from each addon's source, see FixLog.md 2026-09-13.
-- Left out on purpose: ElvUI, KkthnxUI and TukUI, since Core/Conflicts.lua shuts
-- AzeriteUI down when one of those is enabled, and UnhaltedUnitFrames, which only
-- adds a button to the menu.
local RIVALS = {
	{ addon = "GW2_UI", IsStyling = function() return HasChildWithKey("gw2Styled") end },
	{ addon = "DiabolicUI3", IsStyling = function() return GameMenuFrame.diabolicSkinned and true or false end },
	{ addon = "FeelUI", IsStyling = function() return HasChildWithKey("BorderBackdrop") end },
	{ addon = "AddOnSkins", IsStyling = function() return GameMenuFrame.template ~= nil end },
	{ addon = "ConsolePort_Menu", IsStyling = function() return _G.ConsolePortMenu ~= nil end },
	-- A named CreateFont is registered as a global, and W2UI only creates this one
	-- inside its styling pass, after its own Game Menu module toggle is checked.
	{ addon = "W2UI", IsStyling = function() return _G.W2UIGameMenuNormalFont ~= nil end }
}

local function FindStylingRival()
	for _, rival in ipairs(RIVALS) do
		if (C_AddOns.IsAddOnLoaded(rival.addon) and rival.IsStyling()) then
			return rival.addon
		end
	end
end

-- The title from the addon's TOC, which is the name the player knows it by in
-- the addon list. Falls back to the folder name.
local function GetAddOnTitle(addon)
	local _, title = C_AddOns.GetAddOnInfo(addon)
	if (type(title) == "string" and title ~= "") then
		return title
	end
	return addon
end

GameMenuSkin.GetDefaults = function(self)
	return defaults
end

GameMenuSkin.UpdateSkin = function(self)
	SkinFrame()
end

-- Whether AzeriteUI should style the menu, going by this character's choice.
GameMenuSkin.ShouldSkin = function(self)
	local char = self.db.char
	if (char.owner == "blizzard") then
		return false
	end
	if (char.owner == "other" and char.rival and IsAddOnEnabled(char.rival)) then
		return false
	end
	return true
end

-- The other addon a style choice is about: the one caught styling the menu this
-- session, or the one this character already handed the menu to.
GameMenuSkin.GetRival = function(self)
	if (self.detectedRival) then
		return self.detectedRival
	end
	local char = self.db.char
	if (char.owner == "other" and char.rival and IsAddOnEnabled(char.rival)) then
		return char.rival
	end
end

GameMenuSkin.GetStyle = function(self)
	if (self:ShouldSkin()) then
		return "azeriteui"
	end
	return self.db.char.owner
end

GameMenuSkin.GetStyleChoices = function(self)
	local choices = {
		azeriteui = "AzeriteUI",
		blizzard = L["Blizzard"]
	}
	local rival = self:GetRival()
	if (rival) then
		choices.other = GetAddOnTitle(rival)
	end
	return choices
end

-- Saves the choice and reloads. The style strips Blizzard's art in ways that
-- cannot be put back mid session, and a disabled addon only unloads on reload.
-- Choosing AzeriteUI or Blizzard over a rival turns the rival off for this
-- character only, the same call Blizzard's addon list makes with one character
-- selected.
GameMenuSkin.ApplyStyle = function(self, owner, rival)
	local char = self.db.char
	char.owner = owner
	char.rival = rival

	if (rival and owner ~= "other") then
		C_AddOns.DisableAddOn(rival, UnitName("player"))
	end

	ReloadUI()
end

GameMenuSkin.ShowConflictPrompt = function(self, rival)
	if (not StaticPopupDialogs or not StaticPopup_Show) then
		return
	end

	local key = "AZERITEUI_GAME_MENU_CONFLICT"
	if (not StaticPopupDialogs[key]) then
		StaticPopupDialogs[key] = {
			text = "%s",
			button1 = "AzeriteUI",
			button3 = L["Blizzard"],
			button4 = L["Decide Later"],
			-- Four outcomes need Blizzard's per button callbacks. Without this flag
			-- StaticPopup_OnClick sends buttons two and four to the same OnCancel.
			selectCallbackByIndex = true,
			OnButton1 = function(dialog, data) GameMenuSkin:ApplyStyle("azeriteui", data) end,
			OnButton2 = function(dialog, data) GameMenuSkin:ApplyStyle("other", data) end,
			OnButton3 = function(dialog, data) GameMenuSkin:ApplyStyle("blizzard", data) end,
			OnButton4 = function(dialog, data) end,
			-- No OnCancel on purpose. Escape runs it, and this popup sits on top of a
			-- menu the player most likely just opened with Escape. Without one, Escape
			-- only closes the popup and nothing is chosen or disabled by accident.
			hideOnEscape = true,
			timeout = 0,
			whileDead = true,
			preferredIndex = 3
		}
	end

	-- The second button carries the other addon's name, so it is set on every show.
	local title = GetAddOnTitle(rival)
	StaticPopupDialogs[key].button2 = title

	local text = string_format(L["%s is restyling the game menu too, and the two styles clash. Which game menu do you want to keep?"], title)
		.. "|n|n" .. string_format(L["Picking AzeriteUI or Blizzard turns %s off for this character. The interface reloads to apply your choice."], title)

	StaticPopup_Show(key, text, nil, rival)
end

-- Called from the options page. Nothing changes until the player accepts the
-- reload, so backing out leaves the saved choice exactly as it was.
GameMenuSkin.PromptStyleChange = function(self, owner)
	if (owner == self:GetStyle()) then
		return
	end

	local rival = self:GetRival()
	if (owner == "other" and not rival) then
		return
	end

	if (not StaticPopupDialogs or not StaticPopup_Show) then
		return
	end

	local key = "AZERITEUI_GAME_MENU_STYLE_RELOAD"
	if (not StaticPopupDialogs[key]) then
		StaticPopupDialogs[key] = {
			text = "%s",
			button1 = L["Reload UI"],
			button2 = CANCEL or "Cancel",
			OnAccept = function(dialog, data) GameMenuSkin:ApplyStyle(data.owner, data.rival) end,
			timeout = 0,
			whileDead = true,
			hideOnEscape = true,
			preferredIndex = 3
		}
	end

	local text
	if (rival and owner ~= "other") then
		text = string_format(L["This turns %s off for this character and reloads the interface."], GetAddOnTitle(rival))
	else
		text = L["The game menu style changes when the interface reloads."]
	end

	StaticPopup_Show(key, text, nil, { owner = owner, rival = rival })
end

GameMenuSkin.CheckForRival = function(self)
	if (self.detectedRival) then
		return
	end

	local rival = FindStylingRival()
	if (not rival) then
		return
	end

	-- Remembered for the options page either way, but it is only a clash while
	-- our style is on the frame too. Asked at most once per session.
	self.detectedRival = rival
	if (self.skinning) then
		self:ShowConflictPrompt(rival)
	end
end

-- Other styles hook the same OnShow and InitButtons calls this module does, and
-- run in load order, so the check waits a frame for all of them to have run.
GameMenuSkin.QueueRivalCheck = function(self)
	if (self.detectedRival or self.rivalCheckQueued) then
		return
	end
	self.rivalCheckQueued = true
	C_Timer.After(0, function()
		self.rivalCheckQueued = nil
		self:CheckForRival()
	end)
end

GameMenuSkin.OnMenuShown = function(self)
	if (self.skinning) then
		self:UpdateSkin()
	end
	self:QueueRivalCheck()
end

GameMenuSkin.OnInitialize = function(self)
	self.db = ns.db:RegisterNamespace(self:GetName(), self:GetDefaults())

	-- Nothing here belongs in a shared profile string: it is per character, and it
	-- names addons the importing player may not even have installed.
	self:DisableSettingsExport()
end

GameMenuSkin.OnEnable = function(self)
	if (not GameMenuFrame) then
		return
	end

	-- Settled once per session, since the style cannot be taken back off the frame.
	self.skinning = self:ShouldSkin()

	-- Hooked even when not styling, so the options page can still name the addon
	-- that is.
	if (not self:IsHooked(GameMenuFrame, "OnShow")) then
		self:SecureHookScript(GameMenuFrame, "OnShow", "OnMenuShown")
	end

	if (not self.skinning) then
		return
	end

	if (type(GameMenuFrame_UpdateVisibleButtons) == "function" and not self:IsHooked("GameMenuFrame_UpdateVisibleButtons")) then
		self:SecureHook("GameMenuFrame_UpdateVisibleButtons", "UpdateSkin")
	end

	self:UpdateSkin()
end
