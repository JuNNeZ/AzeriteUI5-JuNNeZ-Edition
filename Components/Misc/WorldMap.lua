--[[

	The MIT License (MIT)

	Copyright (c) 2024 Lars Norberg

--]]
local _, ns = ...

-- Integrated from Rui's RUEM retail patch set, adapted to the current branch.
if (not ns.IsRetail) then return end

local WorldMapMod = ns:NewModule("WorldMap", "LibMoreEvents-1.0", "AceHook-3.0")
local defaults = { profile = {
	enabled = true
} }

-- Lua API
local ipairs = ipairs
local pairs = pairs
local select = select
local string_format = string.format
local string_gsub = string.gsub

-- WoW API
local CreateFrame = CreateFrame
local GetBestMapForUnit = C_Map and C_Map.GetBestMapForUnit
local GetPlayerMapPosition = C_Map and C_Map.GetPlayerMapPosition
local InCombatLockdown = InCombatLockdown

-- AzeriteUI API
local GetMedia = ns.API.GetMedia
local UIHider = ns.Hider

-- Localization
local L = {
	Player = PLAYER,
	Mouse = MOUSE_LABEL
}

local IsWorldMapEnabled = function()
	return WorldMapMod and WorldMapMod.db and WorldMapMod.db.profile and WorldMapMod.db.profile.enabled
end

local GetFormattedCoordinates = function(x, y)
	return string_gsub(string_format("|cfff0f0f0%.2f|r", x * 100), "%.(.+)", "|cffa0a0a0.%1|r"),
		string_gsub(string_format("|cfff0f0f0%.2f|r", y * 100), "%.(.+)", "|cffa0a0a0.%1|r")
end

local CalculateScale = function()
	local min, max = 0.65, 0.95
	local uiMin, uiMax = 0.65, 1.15
	local uiScale = UIParent:GetEffectiveScale()
	if (uiScale < uiMin) then
		return min
	elseif (uiScale > uiMax) then
		return max
	else
		return ((uiScale - uiMin) / (uiMax - uiMin)) * (max - min) + min
	end
end

local Coords_OnUpdate = function(self, elapsed)
	self.elapsed = self.elapsed + elapsed
	if (self.elapsed < .02) then
		return
	end

	local pX, pY, cX, cY
	local mapID = GetBestMapForUnit("player")
	if (mapID) then
		local pos = GetPlayerMapPosition(mapID, "player")
		if (pos) then
			pX, pY = pos:GetXY()
		end
	end
	if (WorldMapFrame.ScrollContainer:IsMouseOver()) then
		cX, cY = WorldMapFrame.ScrollContainer:GetNormalizedCursorPosition()
	end

	if (pX and pY and pX > 0 and pY > 0) then
		self.Player:SetFormattedText("%s:|r   %s, %s", L.Player, GetFormattedCoordinates(pX, pY))
	else
		self.Player:SetText(" ")
	end
	if (cX and cY and cX > 0 and cY > 0 and cX < 100 and cY < 100) then
		self.Cursor:SetFormattedText("%s:|r   %s, %s", L.Mouse, GetFormattedCoordinates(cX, cY))
	else
		self.Cursor:SetText(" ")
	end

	self.elapsed = 0
end

local ApplyStyledMaximizedState = function()
	WorldMapFrame:SetParent(UIParent)
	WorldMapFrame:SetScale(1)
	if (not InCombatLockdown()) then
		if (WorldMapFrame:GetAttribute("UIPanelLayout-area") ~= "center") then
			SetUIPanelAttribute(WorldMapFrame, "area", "center")
		end
		if (WorldMapFrame:GetAttribute("UIPanelLayout-allowOtherPanels") ~= true) then
			SetUIPanelAttribute(WorldMapFrame, "allowOtherPanels", true)
		end
	end
	WorldMapFrame:OnFrameSizeChanged()
	WorldMapFrame.NavBar:Hide()
	WorldMapFrame.BorderFrame:SetAlpha(0)
	WorldMapFrameBg:Hide()
	WorldMapFrameCloseButton:ClearAllPoints()
	WorldMapFrameCloseButton:SetPoint("TOPLEFT", 4, -70)
	WorldMapFrame.AzeriteBackdrop:Show()
	WorldMapFrame.AzeriteBorder:Show()
	WorldMapFrame.AzeriteCoords:Show()
end

local ApplyStyledMinimizedState = function()
	if (not WorldMapFrame:IsMaximized()) then
		WorldMapFrame:ClearAllPoints()
		WorldMapFrame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 16, -94)
		WorldMapFrame.NavBar:Show()
		WorldMapFrame.BorderFrame:SetAlpha(1)
		WorldMapFrameBg:Show()
		WorldMapFrameCloseButton:ClearAllPoints()
		WorldMapFrameCloseButton:SetPoint("TOPRIGHT", 5, 5)
		WorldMapFrame.AzeriteBackdrop:Hide()
		WorldMapFrame.AzeriteBorder:Hide()
		WorldMapFrame.AzeriteCoords:Hide()
	end
end

local WorldMapFrame_SyncState = function()
	if (not IsWorldMapEnabled()) then
		return
	end
	if (WorldMapFrame:IsMaximized()) then
		WorldMapFrame:ClearAllPoints()
		WorldMapFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 30)
	end
end

local WorldMapFrame_UpdateMaximizedSize = function()
	if (not IsWorldMapEnabled()) then
		return
	end
	local width, height = WorldMapFrame:GetSize()
	local scale = CalculateScale()
	local magicNumber = (1 - scale) * 100
	WorldMapFrame:SetSize((width * scale) - (magicNumber + 2), (height * scale) - 2)
end

local WorldMapFrame_Maximize = function()
	if (not IsWorldMapEnabled()) then
		return
	end
	ApplyStyledMaximizedState()
end

local WorldMapFrame_Minimize = function()
	if (not IsWorldMapEnabled()) then
		return
	end
	ApplyStyledMinimizedState()
end

local StoreOverlayFrameState = function(self, button)
	if (not button or self.overlayState[button]) then
		return
	end
	local state = {}
	if (button.Icon) then
		state.borderAlpha = button.Border and button.Border.GetAlpha and button.Border:GetAlpha() or nil
		state.backgroundAlpha = button.Background and button.Background.GetAlpha and button.Background:GetAlpha() or nil
	else
		state.regions = {}
		for i = 1, button:GetNumRegions() do
			local region = select(i, button:GetRegions())
			if (region and region.GetObjectType and region:GetObjectType() == "Texture") then
				state.regions[#state.regions + 1] = {
					region = region,
					texture = region.GetTexture and region:GetTexture() or nil
				}
			end
		end
		if (button.Button) then
			state.buttonShown = button.Button:IsShown()
		end
		if (button.Text) then
			state.textShown = button.Text:IsShown()
		end
	end
	self.overlayState[button] = state
end

local ApplyOverlayFrameState = function(self, enabled)
	if (not WorldMapFrame or not WorldMapFrame.overlayFrames) then
		return
	end
	for _, button in pairs(WorldMapFrame.overlayFrames) do
		if (type(button) == "table" and button.Icon) then
			StoreOverlayFrameState(self, button)
			local state = self.overlayState[button]
			if (enabled) then
				if (button.Border) then button.Border:SetAlpha(0) end
				if (button.Background) then button.Background:SetAlpha(0) end
			elseif (state) then
				if (button.Border and state.borderAlpha ~= nil) then button.Border:SetAlpha(state.borderAlpha) end
				if (button.Background and state.backgroundAlpha ~= nil) then button.Background:SetAlpha(state.backgroundAlpha) end
			end
		elseif (type(button) == "table") then
			StoreOverlayFrameState(self, button)
			local state = self.overlayState[button]
			if (enabled) then
				if (state and state.regions) then
					for _, regionState in ipairs(state.regions) do
						if (regionState.region) then
							regionState.region:SetTexture(nil)
						end
					end
				end
				if (button.Button) then button.Button:Hide() end
				if (button.Text) then button.Text:Hide() end
			elseif (state) then
				if (state.regions) then
					for _, regionState in ipairs(state.regions) do
						if (regionState.region) then
							regionState.region:SetTexture(regionState.texture)
						end
					end
				end
				if (button.Button and state.buttonShown) then button.Button:Show() end
				if (button.Text and state.textShown) then button.Text:Show() end
			end
		end
	end
end

local RestoreBlizzardState = function(self)
	if (not self.Styled) then
		return
	end
	if (self.originalBlackoutTexture and WorldMapFrame.BlackoutFrame and WorldMapFrame.BlackoutFrame.Blackout) then
		WorldMapFrame.BlackoutFrame.Blackout:SetTexture(self.originalBlackoutTexture)
	end
	if (WorldMapFrame.BlackoutFrame) then
		WorldMapFrame.BlackoutFrame:EnableMouse(true)
	end
	if (not InCombatLockdown()) then
		WorldMapFrame:EnableMouse(true)
	end
	if (WorldMapFrame.BorderFrame) then
		WorldMapFrame.BorderFrame:SetAlpha(1)
	end
	if (WorldMapFrame.NavBar) then
		WorldMapFrame.NavBar:Show()
	end
	if (WorldMapFrameBg) then
		WorldMapFrameBg:Show()
	end
	if (WorldMapFrameCloseButton) then
		WorldMapFrameCloseButton:ClearAllPoints()
		WorldMapFrameCloseButton:SetPoint("TOPRIGHT", 5, 5)
	end
	if (WorldMapFrame.AzeriteBackdrop) then WorldMapFrame.AzeriteBackdrop:Hide() end
	if (WorldMapFrame.AzeriteBorder) then WorldMapFrame.AzeriteBorder:Hide() end
	if (WorldMapFrame.AzeriteCoords) then WorldMapFrame.AzeriteCoords:Hide() end
	if (self.originalMinimizeButtonParent and WorldMapFrame.BorderFrame and WorldMapFrame.BorderFrame.MaximizeMinimizeFrame) then
		WorldMapFrame.BorderFrame.MaximizeMinimizeFrame.MinimizeButton:SetParent(self.originalMinimizeButtonParent)
	end
	if (WorldMapFrameButton and self.originalFrameButtonParent) then
		WorldMapFrameButton:SetParent(self.originalFrameButtonParent)
		WorldMapFrameButton:Show()
	end
	ApplyOverlayFrameState(self, false)
	if (WorldMapFrame.UpdateMaximizedSize) then
		WorldMapFrame:UpdateMaximizedSize()
	end
	if (WorldMapFrame.SynchronizeDisplayState) then
		WorldMapFrame:SynchronizeDisplayState()
	end
	if (not WorldMapFrame:IsMaximized()) then
		WorldMapFrame:ClearAllPoints()
	end
end

WorldMapMod.UpdateSettings = function(self)
	if (not self.Styled or not self.db or not self.db.profile) then
		return
	end
	if (self.db.profile.enabled) then
		if (not InCombatLockdown()) then
			WorldMapFrame:EnableMouse(false)
			SetCVar("miniWorldMap", 0)
		end
		if (WorldMapFrame.BlackoutFrame) then
			WorldMapFrame.BlackoutFrame:EnableMouse(false)
		end
		if (WorldMapFrame.BlackoutFrame and WorldMapFrame.BlackoutFrame.Blackout) then
			WorldMapFrame.BlackoutFrame.Blackout:SetTexture(nil)
		end
		if (self.originalMinimizeButtonParent and WorldMapFrame.BorderFrame and WorldMapFrame.BorderFrame.MaximizeMinimizeFrame) then
			WorldMapFrame.BorderFrame.MaximizeMinimizeFrame.MinimizeButton:SetParent(UIHider)
		end
		if (WorldMapFrameButton) then
			WorldMapFrameButton:SetParent(UIHider)
			WorldMapFrameButton:Hide()
		end
		ApplyOverlayFrameState(self, true)
		if (WorldMapFrame:IsMaximized()) then
			WorldMapFrame_UpdateMaximizedSize()
			ApplyStyledMaximizedState()
		else
			ApplyStyledMinimizedState()
		end
	else
		RestoreBlizzardState(self)
	end
end

WorldMapMod.SetUpMap = function(self)
	if (self.Styled) then
		return
	end

	local backdrop = CreateFrame("Frame", nil, WorldMapFrame, BackdropTemplateMixin and "BackdropTemplate")
	backdrop:Hide()
	backdrop:SetFrameLevel(WorldMapFrame:GetFrameLevel())
	backdrop:SetPoint("TOP", 0, 25 - 66)
	backdrop:SetPoint("LEFT", -25, 0)
	backdrop:SetPoint("BOTTOM", 0, -25)
	backdrop:SetPoint("RIGHT", 25, 0)
	backdrop:SetBackdrop({
		bgFile = [[Interface\Tooltips\UI-Tooltip-Background]],
		insets = { left = 25, right = 25, top = 25, bottom = 25 }
	})
	backdrop:SetBackdropColor(0, 0, 0, .95)
	WorldMapFrame.AzeriteBackdrop = backdrop

	local border = CreateFrame("Frame", nil, WorldMapFrame, BackdropTemplateMixin and "BackdropTemplate")
	border:Hide()
	border:SetFrameLevel(WorldMapFrame:GetFrameLevel() + 10)
	border:SetAllPoints(backdrop)
	border:SetBackdrop({ edgeSize = 32, edgeFile = GetMedia("better-blizzard-border-small-alternate") })
	border:SetBackdropBorderColor(.35, .35, .35, 1)
	WorldMapFrame.AzeriteBorder = border

	local coords = CreateFrame("Frame", nil, WorldMapFrame)
	coords:SetFrameStrata(WorldMapFrame.BorderFrame:GetFrameStrata())
	coords:SetFrameLevel(WorldMapFrame.BorderFrame:GetFrameLevel() + 10)
	coords.elapsed = 0
	WorldMapFrame.AzeriteCoords = coords

	local player = coords:CreateFontString()
	player:SetFontObject(NumberFont_Shadow_Med)
	player:SetFont(player:GetFont(), 14, "THINOUTLINE")
	player:SetShadowColor(0, 0, 0, 0)
	player:SetTextColor(255/255, 234/255, 137/255)
	player:SetAlpha(.85)
	player:SetDrawLayer("OVERLAY")
	player:SetJustifyH("LEFT")
	player:SetJustifyV("BOTTOM")
	player:SetPoint("BOTTOMLEFT", border, "TOPLEFT", 32, -16)
	coords.Player = player

	local cursor = coords:CreateFontString()
	cursor:SetFontObject(NumberFont_Shadow_Med)
	cursor:SetFont(cursor:GetFont(), 14, "THINOUTLINE")
	cursor:SetShadowColor(0, 0, 0, 0)
	cursor:SetTextColor(255/255, 234/255, 137/255)
	cursor:SetAlpha(.85)
	cursor:SetDrawLayer("OVERLAY")
	cursor:SetJustifyH("RIGHT")
	cursor:SetJustifyV("BOTTOM")
	cursor:SetPoint("BOTTOMRIGHT", border, "TOPRIGHT", -32, -16)
	coords.Cursor = cursor

	coords:SetScript("OnUpdate", Coords_OnUpdate)
	self.originalBlackoutTexture = WorldMapFrame.BlackoutFrame and WorldMapFrame.BlackoutFrame.Blackout and WorldMapFrame.BlackoutFrame.Blackout:GetTexture() or nil
	self.originalMinimizeButtonParent = WorldMapFrame.BorderFrame and WorldMapFrame.BorderFrame.MaximizeMinimizeFrame and WorldMapFrame.BorderFrame.MaximizeMinimizeFrame.MinimizeButton:GetParent() or nil
	self.originalFrameButtonParent = WorldMapFrameButton and WorldMapFrameButton:GetParent() or nil
	self.overlayState = self.overlayState or {}

	self:SecureHook(WorldMapFrame, "Maximize", WorldMapFrame_Maximize)
	self:SecureHook(WorldMapFrame, "Minimize", WorldMapFrame_Minimize)
	self:SecureHook(WorldMapFrame, "SynchronizeDisplayState", WorldMapFrame_SyncState)
	self:SecureHook(WorldMapFrame, "UpdateMaximizedSize", WorldMapFrame_UpdateMaximizedSize)

	self.Styled = true
	self:UpdateSettings()
end

WorldMapMod.OnEvent = function(self, event, ...)
	if (event == "ADDON_LOADED") then
		local addon = ...
		if (addon == "Blizzard_WorldMap") then
			self:SetUpMap()
			self:UnregisterEvent("ADDON_LOADED")
		end
	elseif (event == "PLAYER_ENTERING_WORLD") then
		if (IsWorldMapEnabled() and not InCombatLockdown()) then
			SetCVar("miniWorldMap", 0)
		end
	end
end

WorldMapMod.OnInitialize = function(self)
	self.db = ns.db:RegisterNamespace("WorldMap", defaults)
end

WorldMapMod.OnEnable = function(self)
	local IsLoaded = C_AddOns and C_AddOns.IsAddOnLoaded or IsAddOnLoaded
	if (IsLoaded("Blizzard_WorldMap")) then
		self:SetUpMap()
	else
		self:RegisterEvent("ADDON_LOADED", "OnEvent")
	end
	self:RegisterEvent("PLAYER_ENTERING_WORLD", "OnEvent")
end
