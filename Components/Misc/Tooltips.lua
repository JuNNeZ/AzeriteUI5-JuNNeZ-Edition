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

local L = LibStub("AceLocale-3.0"):GetLocale((...))
local ID_LABEL = L and L["ID"] or "ID"

local Tooltips = ns:NewModule("Tooltips", ns.MovableModulePrototype, "LibMoreEvents-1.0", "AceHook-3.0")
-- Internal registration guards
local PostCallRegistered = {}
-- Theme/feature caches
Tooltips._cachedThemeKey = nil
Tooltips._cachedThemeData = nil
Tooltips._consolePortActive = nil
Tooltips._stylingActive = nil
Tooltips._originalHighlightSystem = nil
Tooltips._originalClearHighlight = nil

function Tooltips:GetTheme()
	local key = self.db and self.db.profile and self.db.profile.theme or "Classic"
	if key ~= self._cachedThemeKey then
		local cfgRoot = ns.GetConfig and ns.GetConfig("Tooltips")
		local themes = cfgRoot and cfgRoot.themes
		self._cachedThemeData = themes and themes[key] or nil
		self._cachedThemeKey = key
	end
	return self._cachedThemeData
end

-- Lua API
local _G = _G
local math_abs = math.abs
local math_max = math.max
local ipairs = ipairs
local next = next
local pcall = pcall
local rawget = rawget
local rawset = rawset
local select = select
local setmetatable = setmetatable
local string_find = string.find
local string_format = string.format
local string_match = string.match
local tonumber = tonumber
local unpack = unpack
local GetTime = GetTime

-- GLOBALS: C_UnitAuras, CreateFrame, GetMouseFocus, hooksecurefunc
-- GLOBALS: GameTooltip, GameTooltipTextLeft1, GameTooltipStatusBar, UIParent
-- GLOBALS: UnitAura, UnitClass, UnitExists, UnitEffectiveLevel, UnitHealth, UnitHealthMax, UnitName, UnitRealmRelationship, UnitIsDeadOrGhost, UnitIsPlayer
-- GLOBALS: LE_REALM_RELATION_COALESCED, LE_REALM_RELATION_VIRTUAL, FOREIGN_SERVER_LABEL, INTERACTIVE_SERVER_LABEL
-- GLOGALS: NarciGameTooltip

-- Addon API
local Colors = ns.Colors
local AbbreviateNumber = ns.API.AbbreviateNumber
local AbbreviateNumberBalanced = ns.API.AbbreviateNumberBalanced
local GetFont = ns.API.GetFont
local GetMedia = ns.API.GetMedia
local GetUnitColor = ns.API.GetUnitColor
local UIHider = ns.Hider

local IsSafeUnitToken = function(unit)
	if (type(unit) ~= "string") then
		return
	end
	if (type(issecretvalue) == "function") and issecretvalue(unit) then
		return
	end
	return true
end

local IsSecretValue = function(value)
	return (type(issecretvalue) == "function") and issecretvalue(value)
end

local SafeBooleanValue = function(value)
	if (IsSecretValue(value)) then
		return nil
	end
	return value and true or false
end

local SafeGetTooltipUnitToken = function(tooltip)
	if (not tooltip) or tooltip:IsForbidden() or (not tooltip.GetUnit) then
		return
	end

	local mouseover = SafeBooleanValue(UnitExists("mouseover")) and "mouseover" or nil
	local _, unit = tooltip:GetUnit()
	if (IsSafeUnitToken(unit) and SafeBooleanValue(UnitExists(unit))) then
		return unit
	end

	local focus = GetMouseFocus and GetMouseFocus()
	local focusUnit = focus and focus.GetAttribute and focus:GetAttribute("unit")
	if (IsSafeUnitToken(focusUnit) and SafeBooleanValue(UnitExists(focusUnit))) then
		return focusUnit
	end

	return mouseover
end

local SafeGetNamePlateForUnit = function(unit)
	if (not IsSafeUnitToken(unit)) then
		return
	end
	if (not C_NamePlate) or (not C_NamePlate.GetNamePlateForUnit) then
		return
	end
	local ok, plate = pcall(C_NamePlate.GetNamePlateForUnit, unit)
	if (ok) then
		return plate
	end
end

function Tooltips:UpdateConsolePortState()
	local active = false
	if (ns.API and ns.API.IsAddOnEnabled) then
		if (ns.API.IsAddOnEnabled("ConsolePort") or ns.API.IsAddOnEnabled("ConsolePort_Bar")) then
			active = true
		end
	end
	if (self._consolePortActive ~= active) then
		self._consolePortActive = active
		return true
	end
end

function Tooltips:IsConsolePortActive()
	if (self._consolePortActive == nil) then
		self:UpdateConsolePortState()
	end
	return self._consolePortActive
end

function Tooltips:IsDisabled()
	return self.db and self.db.profile and self.db.profile.disableAzeriteUITooltips
end

function Tooltips:EnsureHighlightCache()
	if (self._originalHighlightSystem and self._originalClearHighlight) then
		return
	end
	if (GameTooltipDefaultContainer) then
		self._originalHighlightSystem = self._originalHighlightSystem or GameTooltipDefaultContainer.HighlightSystem
		self._originalClearHighlight = self._originalClearHighlight or GameTooltipDefaultContainer.ClearHighlight
	end
end

function Tooltips:RestoreHighlightState()
	if (not GameTooltipDefaultContainer) then
		return
	end
	if (self._originalHighlightSystem) then
		GameTooltipDefaultContainer.HighlightSystem = self._originalHighlightSystem
	end
	if (self._originalClearHighlight) then
		GameTooltipDefaultContainer.ClearHighlight = self._originalClearHighlight
	end
end

function Tooltips:ApplyHighlightOverride()
	if (not GameTooltipDefaultContainer) then
		return
	end
	self:EnsureHighlightCache()
	self:RestoreHighlightState()
end

-- Detect unit tooltips anchored to nameplates (Retail/Cata only)
function Tooltips:IsNameplateUnitTooltip(tooltip)
	if (not tooltip) or tooltip:IsForbidden() then return false end
	local unit = SafeGetTooltipUnitToken(tooltip)
	if (not unit) then return false end
	local plate = SafeGetNamePlateForUnit(unit)
	return plate and true or false
end

local Backdrops = setmetatable({}, { __index = function(t,k)
	local bg = CreateFrame("Frame", nil, k, ns.BackdropTemplate)
	bg:SetPoint("TOPLEFT", k, "TOPLEFT", 0, 0)
	bg:SetPoint("BOTTOMRIGHT", k, "BOTTOMRIGHT", 0, 0)
	pcall(function() bg:SetFrameLevel(k:GetFrameLevel()) end)

	-- WoW12: BackdropTemplate callbacks can receive secret dimensions.
	if (bg.OnBackdropSizeChanged) then
		local originalOnBackdropSizeChanged = bg.OnBackdropSizeChanged
		bg.OnBackdropSizeChanged = function(self, ...)
			pcall(originalOnBackdropSizeChanged, self, ...)
		end
	end
	if (bg.ApplyBackdrop) then
		local originalApplyBackdrop = bg.ApplyBackdrop
		bg.ApplyBackdrop = function(self, ...)
			pcall(originalApplyBackdrop, self, ...)
		end
	end
	if (bg.SetupTextureCoordinates) then
		local originalSetupTextureCoordinates = bg.SetupTextureCoordinates
		bg.SetupTextureCoordinates = function(self, ...)
			pcall(originalSetupTextureCoordinates, self, ...)
		end
	end

	-- Hook into tooltip framelevel changes.
	-- Might help with some of the conflicts experienced with Silverdragon and Raider.IO
	hooksecurefunc(k, "SetFrameLevel", function(self)
		pcall(function() bg:SetFrameLevel(self:GetFrameLevel()) end)
	end)
	rawset(t,k,bg)
	return bg
end })

local TooltipBackdropSignature = setmetatable({}, { __mode = "k" })
local TooltipBackdropLastUpdate = setmetatable({}, { __mode = "k" })
local StatusBarThemeSignature = setmetatable({}, { __mode = "k" })
local StatusBarText = setmetatable({}, { __mode = "k" })

local GetTooltipStatusBar = function()
	if (GameTooltipStatusBar) then
		return GameTooltipStatusBar
	end
	if (GameTooltip and GameTooltip.StatusBar) then
		return GameTooltip.StatusBar
	end
end

local GetStatusBarText = function(bar, valuePosition, valueFont, valueColor)
	if (not bar) then return end
	local text = StatusBarText[bar]
	if (not text) then
		text = bar:CreateFontString(nil, "OVERLAY")
		StatusBarText[bar] = text
	end
	if (valuePosition) then text:SetPoint(unpack(valuePosition)) end
	if (valueFont) then text:SetFontObject(valueFont) end
	if (valueColor) then text:SetTextColor(unpack(valueColor)) end
	return text
end

local RestoreBlizzardTooltipBackdrop = function(tooltip)
	if (not tooltip) or tooltip:IsForbidden() then
		return
	end
	local secretBackdrop = rawget(Backdrops, tooltip)
	if (secretBackdrop and secretBackdrop.Hide) then
		secretBackdrop:Hide()
	end
	TooltipBackdropSignature[tooltip] = nil
	TooltipBackdropLastUpdate[tooltip] = nil
	tooltip:EnableDrawLayer("BACKGROUND")
	tooltip:EnableDrawLayer("BORDER")
	if (tooltip.NineSlice and tooltip.NineSlice.GetParent and tooltip.NineSlice:GetParent() == UIHider) then
		tooltip.NineSlice:SetParent(tooltip)
		tooltip.NineSlice:SetAlpha(1)
	end
end

local ManagedTooltipState = setmetatable({}, { __mode = "k" })
local CompareLayoutHooked = setmetatable({}, { __mode = "k" })
local CompareRelayoutQueued = false
local CompareTooltipWrapState = setmetatable({}, { __mode = "k" })
local CompareTooltipLineWidthState = setmetatable({}, { __mode = "k" })

local IsManagedTooltip = function(tooltip)
	if (not tooltip) or (tooltip.IsForbidden and tooltip:IsForbidden()) then
		return false
	end

	local cached = ManagedTooltipState[tooltip]
	if (cached ~= nil) then
		return cached
	end

	local managed = tooltip == _G.GameTooltip
		or tooltip == _G.ShoppingTooltip1
		or tooltip == _G.ShoppingTooltip2
		or tooltip == _G.ItemRefTooltip
		or tooltip == _G.ItemRefShoppingTooltip1
		or tooltip == _G.ItemRefShoppingTooltip2
		or tooltip == _G.EmbeddedItemTooltip
		or tooltip == _G.FriendsTooltip
		or tooltip == _G.WarCampaignTooltip
		or tooltip == _G.ReputationParagonTooltip
		or tooltip == _G.QuickKeybindTooltip
		or tooltip == _G.GameNoHeaderTooltip
		or tooltip == _G.GameSmallHeaderTooltip
		or tooltip == (_G.QuestScrollFrame and _G.QuestScrollFrame.StoryTooltip)
		or tooltip == (_G.QuestScrollFrame and _G.QuestScrollFrame.CampaignTooltip)
		or tooltip == _G.NarciGameTooltip

	if (not managed and tooltip.GetName) then
		local tooltipName = tooltip:GetName()
		if (tooltipName and (
			string_match(tooltipName, "^DropDownList%d+")
			or string_match(tooltipName, "^L_DropDownList%d+")
			or string_match(tooltipName, "MenuBackdrop$")
			or string_match(tooltipName, "Backdrop$") and string_find(tooltipName, "DropDown")
		)) then
			managed = false
		elseif (tooltipName and string_match(tooltipName, "^UIWidgetBaseItemEmbeddedTooltip%d+$")) then
			managed = true
		end
	end

	ManagedTooltipState[tooltip] = managed and true or false
	return managed
end


local defaults = { profile = ns:Merge({
	theme = "Classic",
	showItemID = false,
	showSpellID = false,
	showGuildName = false,
	-- New: allow users to completely disable AzeriteUI tooltip styling
	disableAzeriteUITooltips = false,
	-- Optional: make unit tooltips transparent when anchored to nameplates
	nameplateUnitTransparency = false,
	anchor = true,
	anchorToCursor = false,
	hideInCombat = false,
	hideActionBarTooltipsInCombat = true,
	hideUnitFrameTooltipsInCombat = true
}, ns.MovableModulePrototype.defaults) }

-- Generate module defaults on the fly
-- to recalculate default values relying on
-- changing factors like user interface scale.
Tooltips.GenerateDefaults = function(self)
	defaults.profile.savedPosition = {
		scale = ns.API.GetEffectiveScale(),
		[1] = "BOTTOMRIGHT",
		[2] = -319 * ns.API.GetEffectiveScale(),
		[3] = 166 * ns.API.GetEffectiveScale()
	}
	return defaults
end

Tooltips.UpdateBackdropTheme = function(self, tooltip)
	if (self:IsDisabled()) then return end
	if (not tooltip) or (tooltip.IsEmbedded) or (tooltip:IsForbidden()) then return end
	if (not IsManagedTooltip(tooltip)) then return end
	-- WoW12: use safe geometry helper to get a clean (non-secret) width.
	-- Skip styling if the tooltip has zero size (e.g. not yet laid out).
	local width = ns.GetSafeWidth and ns.GetSafeWidth(tooltip) or (tooltip.GetWidth and tooltip:GetWidth() or 0)
	if issecretvalue and issecretvalue(width) then
		width = 0
	end
	if (width <= 0) then
		return
	end

	-- Build a simple signature so we can skip redundant work (vendor/item tooltips spam updates).
	local themeKey = self.db and self.db.profile and self.db.profile.theme or "?"
	local isPlate = false
	local wantsTransparency = false
	if (self.db and self.db.profile.nameplateUnitTransparency and not self:IsConsolePortActive()) then
		isPlate = self:IsNameplateUnitTooltip(tooltip)
		wantsTransparency = isPlate
	end
	local signature = themeKey .. ':' .. (wantsTransparency and 'T' or 'N')

	local backdropFrame = rawget(Backdrops, tooltip)
	if (TooltipBackdropSignature[tooltip] == signature and backdropFrame) then
		-- Ensure Blizzard's own visuals stay hidden even if another addon reattached them.
		if (tooltip.NineSlice and tooltip.NineSlice.GetParent and tooltip.NineSlice:GetParent() ~= UIHider) then
			tooltip.NineSlice:SetParent(UIHider)
		end
		if (not backdropFrame:IsShown()) then
			backdropFrame:Show()
		end

		-- While merchant windows are open Blizzard will spam SharedTooltip_SetBackdropStyle();
		-- if nothing changed there's no need to keep doing work here.
		if (MerchantFrame and MerchantFrame:IsShown()) then
			return
		end

		local now = GetTime()
		if (TooltipBackdropLastUpdate[tooltip] and (now - TooltipBackdropLastUpdate[tooltip]) < .02) then
			return
		end
		TooltipBackdropLastUpdate[tooltip] = now
		return
	end
	TooltipBackdropLastUpdate[tooltip] = GetTime()

	-- Only do this once.
	if (not backdropFrame) then
		tooltip:DisableDrawLayer("BACKGROUND")
		tooltip:DisableDrawLayer("BORDER")

		-- Don't want or need the extra padding here,
		-- as our current borders do not require them.
		if (NarciGameTooltip and tooltip == NarciGameTooltip) then

			-- Note that the WorldMap uses this to fit extra embedded stuff in,
			-- so we can't randomly just remove it from all tooltips, or stuff will break.
			-- Currently the only one we know of that needs tweaking, is the aforementioned.
			if (tooltip.SetPadding) then
				tooltip:SetPadding(0, 0, 0, 0)

				if (not self:IsHooked(tooltip, "SetPadding")) then
					-- Use a local copy to avoid hook looping.
					local setPadding = tooltip.SetPadding

					self:SecureHook(tooltip, "SetPadding", function(self, ...)
						--local padding = 0
						--for i = 1, select("#", ...) do
						--	padding = padding + tonumber((select(i, ...))) or 0
						--end
						--if (padding < .1) then
						--	return
						--end
						setPadding(self, 0, 0, 0, 0)
					end)
				end
			end
		end

		-- Glorious 9.1.5 crap
		-- They decided to move the entire backdrop into its own hashed frame.
		-- We like this, because it makes it easier to kill. Kill. Kill. Kill. Kill.
		if (tooltip.NineSlice) then
			tooltip.NineSlice:SetParent(UIHider)
		end

		-- Textures in the combat pet tooltips
		for _,texName in ipairs({
			"BorderTopLeft",
			"BorderTopRight",
			"BorderBottomRight",
			"BorderBottomLeft",
			"BorderTop",
			"BorderRight",
			"BorderBottom",
			"BorderLeft",
			"Background"
		}) do
			local region = tooltip[texName]
			if (region) then
				region:SetTexture(nil)
				local drawLayer = region:GetDrawLayer()
				if (drawLayer) then
					tooltip:DisableDrawLayer(drawLayer)
				end
			end
		end

		-- Region names sourced from SharedXML\NineSlice.lua
		-- *Majority of this, if not all, was moved into frame.NineSlice in 9.1.5
		for _,pieceName in ipairs({
			"TopLeftCorner",
			"TopRightCorner",
			"BottomLeftCorner",
			"BottomRightCorner",
			"TopEdge",
			"BottomEdge",
			"LeftEdge",
			"RightEdge",
			"Center"
		}) do
			local region = tooltip[pieceName]
			if (region) then
				region:SetTexture(nil)
				local drawLayer = region:GetDrawLayer()
				if (drawLayer) then
					tooltip:DisableDrawLayer(drawLayer)
				end
			end
		end
	end

	local themeData = self:GetTheme()
	if (not themeData or not themeData.backdropStyle) then return end
	local db = themeData.backdropStyle

	-- Store some values locally for faster updates.
	local backdrop = Backdrops[tooltip]
	backdrop.offsetLeft = db.offsetLeft
	backdrop.offsetRight = db.offsetRight
	backdrop.offsetTop = db.offsetTop
	backdrop.offsetBottom = db.offsetBottom
	backdrop.offsetBar = db.offsetBar
	backdrop.offsetBarBottom = db.offsetBarBottom

	-- Ensure Blizzard visuals are suppressed even after a disable/enable cycle.
	tooltip:DisableDrawLayer("BACKGROUND")
	tooltip:DisableDrawLayer("BORDER")
	if (tooltip.NineSlice and tooltip.NineSlice.GetParent and tooltip.NineSlice:GetParent() ~= UIHider) then
		tooltip.NineSlice:SetParent(UIHider)
	end

	-- Setup the backdrop theme.
	local ok = pcall(function()
		backdrop:SetBackdrop(nil)
		backdrop:SetBackdrop(db.backdrop)
		backdrop:ClearAllPoints()
		backdrop:SetPoint("LEFT", backdrop.offsetLeft, 0)
		backdrop:SetPoint("RIGHT", backdrop.offsetRight, 0)
		backdrop:SetPoint("TOP", 0, backdrop.offsetTop)
		backdrop:SetPoint("BOTTOM", 0, backdrop.offsetBottom)
		backdrop:SetBackdropColor(unpack(db.backdropColor))
		backdrop:SetBackdropBorderColor(unpack(db.backdropBorderColor))
	end)
	if (not ok) then
		RestoreBlizzardTooltipBackdrop(tooltip)
		return
	end

	-- Make sure our backdrop is visible after a previous disable restored Blizzard skin
	if (not backdrop:IsShown()) then
		backdrop:Show()
	end

	-- Optional: nameplate-only transparency for unit tooltips (skip when ConsolePort is active)
	if (wantsTransparency and isPlate) then
		local r, g, b = db.backdropColor[1], db.backdropColor[2], db.backdropColor[3]
		local br, bg, bb = db.backdropBorderColor[1], db.backdropBorderColor[2], db.backdropBorderColor[3]
		backdrop:SetBackdropColor(r or 0, g or 0, b or 0, 0)
		backdrop:SetBackdropBorderColor(br or 0, bg or 0, bb or 0, 0)
	end

	TooltipBackdropSignature[tooltip] = signature

end

Tooltips.UpdateStatusBarTheme = function(self)
	if (self:IsDisabled()) then return end

	local themeData = self:GetTheme()
	if (not themeData or not themeData.barStyle) then return end
	local db = themeData.barStyle
	local bar = GetTooltipStatusBar()
	if (not bar) then return end
	local sig = (self._cachedThemeKey or '?') .. ':' .. (db.texture or '?') .. ':' .. (db.height or '?') .. ':' .. (db.offsetLeft or 0) .. ':' .. (db.offsetRight or 0)
	if (StatusBarThemeSignature[bar] == sig) then return end
	local texture = (type(db.texture) == "string" and db.texture ~= "") and db.texture or "Interface/TargetingFrame/UI-StatusBar"
	local ok = pcall(function()
		bar:SetStatusBarTexture(texture)
		bar:ClearAllPoints()
		bar:SetPoint("BOTTOMLEFT", bar:GetParent(), "BOTTOMLEFT", db.offsetLeft, db.offsetBottom)
		bar:SetPoint("BOTTOMRIGHT", bar:GetParent(), "BOTTOMRIGHT", -db.offsetRight, db.offsetBottom)
		bar:SetHeight(db.height)
	end)
	if (not ok) then
		StatusBarThemeSignature[bar] = nil
		return
	end

	if (not self:IsHooked(bar, "OnShow")) then
		bar:HookScript("OnShow", function(self)
			local tooltip = self:GetParent()
			if (tooltip) then
				local backdrop = rawget(Backdrops, tooltip)
				if (backdrop) then
					pcall(function()
						backdrop:SetPoint("BOTTOM", 0, backdrop.offsetBottom + backdrop.offsetBarBottom)
					end)
					pcall(Tooltips.OnValueChanged, Tooltips) -- Force an update to the bar's health value and color.
				end
			end
		end)
	end

	if (not self:IsHooked(bar, "OnHide")) then
		bar:HookScript("OnHide", function(self)
			local tooltip = self:GetParent()
			if (tooltip) then
				local backdrop = rawget(Backdrops, tooltip)
				if (backdrop) then
					pcall(function()
						backdrop:SetPoint("BOTTOM", 0, backdrop.offsetBottom)
					end)
				end
			end
		end)
	end

	GetStatusBarText(bar, db.valuePosition, db.valueFont, db.valueColor)
	StatusBarThemeSignature[bar] = sig

end

Tooltips.UpdateTooltipThemes = function(self, event, ...)
	if (self:IsDisabled()) then return end
	if (event == "PLAYER_ENTERING_WORLD") then
		self:UnregisterEvent("PLAYER_ENTERING_WORLD", "UpdateTooltipThemes")
	end

	for _,tooltip in next,{
		_G.ItemRefTooltip,
		_G.ItemRefShoppingTooltip1,
		_G.ItemRefShoppingTooltip2,
		_G.FriendsTooltip,
		_G.WarCampaignTooltip,
		_G.EmbeddedItemTooltip,
		_G.ReputationParagonTooltip,
		_G.GameTooltip,
		_G.ShoppingTooltip1,
		_G.ShoppingTooltip2,
		_G.QuickKeybindTooltip,
		_G.QuestScrollFrame and _G.QuestScrollFrame.StoryTooltip,
		_G.QuestScrollFrame and _G.QuestScrollFrame.CampaignTooltip,
		_G.NarciGameTooltip
	} do
		self:UpdateBackdropTheme(tooltip)
	end

	self:UpdateStatusBarTheme()
end

Tooltips.SetHealthValue = function(self, unit)
	if (self:IsDisabled()) then return end
	local safeUnit = IsSafeUnitToken(unit) and unit or nil
	local bar = GetTooltipStatusBar()
	if (not bar) then return end

	-- It could be a wall or gate that does not count as a unit,
	-- so we need to check for the existence as well as it's alive status.
	local unitExists = safeUnit and SafeBooleanValue(UnitExists(safeUnit))
	local unitIsDead = unitExists and SafeBooleanValue(UnitIsDeadOrGhost(safeUnit))
	if (unitExists and unitIsDead) then
		if (bar:IsShown()) then
			bar:Hide()
		end
	else

		local msg, min, max

		if (safeUnit and unitExists) then
			local min, max = UnitHealth(safeUnit), UnitHealthMax(safeUnit)
			-- Check if values are secret before comparison
			if (IsSecretValue(min) or IsSecretValue(max)) then
				-- Can't display secret values
				return
			end
			if (type(min) == "number" and type(max) == "number") then
				if (min == max) then
					msg = string_format("%s", AbbreviateNumberBalanced(min))
				else
					msg = string_format("%s / %s", AbbreviateNumber(min), AbbreviateNumber(max))
				end
			end
		else
			local min,_,max = bar:GetValue(), bar:GetMinMaxValues()
			-- Check if values are secret
			if (IsSecretValue(min) or IsSecretValue(max)) then
				return
			end
			if (max > 100) then
				if (min == max) then
					msg = string_format("%s", AbbreviateNumberBalanced(min))
				else
					msg = string_format("%s / %s", AbbreviateNumber(min), AbbreviateNumber(max))
				end
			else
				msg = string_format("%.0f%%", min/max*100)
			end
			--msg = NOT_APPLICABLE
		end

		local text = GetStatusBarText(bar)
		if (not text) then return end
		text:SetText(msg)

		if (not text:IsShown()) then
			text:Show()
		end

		if (not bar:IsShown()) then
			bar:Show()
		end
	end
end

Tooltips.SetStatusBarColor = function(self, unit)
	if (self:IsDisabled()) then return end
	local bar = GetTooltipStatusBar()
	if (not bar) then return end
	local color = IsSafeUnitToken(unit) and GetUnitColor(unit)
	if (color) then
		pcall(bar.SetStatusBarColor, bar, color[1], color[2], color[3])
	else
		local r, g, b = GameTooltipTextLeft1:GetTextColor()
		pcall(bar.SetStatusBarColor, bar, r, g, b)
	end
end

Tooltips.OnValueChanged = function(self)
	if (self:IsDisabled()) then return end
	if (not GameTooltip or not GameTooltip.StatusBar or not GameTooltip.StatusBar.GetParent) then return end
	local unit
	local parent = GameTooltip.StatusBar:GetParent()
	if (parent and parent.GetUnit) then
		unit = select(2, parent:GetUnit())
	end

	if (not unit) then
		-- Removed in 11.0.0.
		local GMF = GetMouseFocus and GetMouseFocus()
		if (GMF and GMF.GetAttribute and GMF:GetAttribute("unit")) then
			unit = GMF:GetAttribute("unit")
		end
	end

	if (not IsSafeUnitToken(unit)) then
		unit = nil
	end

	--if (not unit) then
	--	if (GameTooltip.StatusBar:IsShown()) then
	--		GameTooltip.StatusBar:Hide()
	--	end
	--	return
	--end

	self:SetHealthValue(unit)
	self:SetStatusBarColor(unit)
end

Tooltips.OnTooltipCleared = function(self, tooltip)
	if (self:IsDisabled()) then return end
	if (not tooltip) or (tooltip:IsForbidden()) then return end
	local bar = GetTooltipStatusBar()
	if (bar and bar:IsShown()) then
		pcall(bar.Hide, bar)
	end
end

Tooltips.OnTooltipSetSpell = function(self, tooltip, data)
	if (self:IsDisabled()) then return end
	if (not self.db.profile.showSpellID) then return end

	if (not tooltip) or (tooltip:IsForbidden()) then return end

	local id = (data and data.id) or (tooltip.GetSpell and select(2, tooltip:GetSpell()))
	if (not id) then return end

	local idLine = string_format("|cFFCA3C3C%s|r %d", ID_LABEL, id)

	-- talent tooltips gets set twice, so let's avoid double ids
	for i = 3, tooltip:NumLines() do
		local line = _G[string_format("GameTooltipTextLeft%d", i)]
		local text = line and line:GetText()
		if (text and string_find(text, idLine)) then
			return
		end
	end

	tooltip:AddLine(" ")
	tooltip:AddLine(idLine)
	tooltip:Show()
end

Tooltips.OnTooltipSetItem = function(self, tooltip, data)
	if (self:IsDisabled()) then return end
	if (not self.db.profile.showItemID) then return end

	if (not tooltip) or (tooltip:IsForbidden()) then return end

	local itemID

	if (tooltip.GetItem) then -- Some tooltips don't have this func. Example - compare tooltip
		local _, link = tooltip:GetItem()
		if (link) then
			itemID = string_format("|cFFCA3C3C%s|r %s", ID_LABEL, (data and data.id) or string_match(link, ":(%w+)"))
		end
	else
		local id = data and data.id
		if (id) then
			itemID = string_format("|cFFCA3C3C%s|r %s", ID_LABEL, id)
		end
	end

	if (itemID) then
		tooltip:AddLine(" ")
		tooltip:AddLine(itemID)
		tooltip:Show()
	end

end

Tooltips.OnTooltipSetUnit = function(self, tooltip, data)
	if (self:IsDisabled()) then return end
	if (not tooltip) or (tooltip:IsForbidden()) then return end

	local unit
	if (tooltip.GetUnit) then
		_, unit = tooltip:GetUnit()
	end
	if not unit then
		local GMF = GetMouseFocus and GetMouseFocus()
		local focusUnit = GMF and GMF.GetAttribute and GMF:GetAttribute("unit")
		if focusUnit then unit = focusUnit end
		if (not IsSafeUnitToken(unit)) then
			return
		end
		local unitExists = SafeBooleanValue(UnitExists(unit))
		if (not unitExists) then
			return
		end
	end

	local color = GetUnitColor(unit)
	if (color) then

		local unitName, unitRealm = UnitName(unit)
		if (IsSecretValue(unitName)) then unitName = nil end
		if (IsSecretValue(unitRealm)) then unitRealm = nil end
		unitName = unitName or _G.UNKNOWN
		local displayName = color.colorCode..unitName.."|r"
		local gray = Colors.quest.gray.colorCode
		local levelText

		local isPlayer = UnitIsPlayer(unit)
		isPlayer = SafeBooleanValue(isPlayer)
		if (isPlayer) then
			if (unitRealm and unitRealm ~= "") then
				local relationship = UnitRealmRelationship(unit)
				if (IsSecretValue(relationship)) then
					relationship = nil
				end
				if (relationship == _G.LE_REALM_RELATION_COALESCED) then
					displayName = displayName ..gray.. _G.FOREIGN_SERVER_LABEL .."|r"

				elseif (relationship == _G.LE_REALM_RELATION_VIRTUAL) then
					displayName = displayName ..gray..  _G.INTERACTIVE_SERVER_LABEL .."|r"
				end
			end
			local isAFK = UnitIsAFK(unit)
			isAFK = SafeBooleanValue(isAFK)
			if (isAFK) then
				displayName = displayName ..gray.. " <" .. _G.AFK ..">|r"
			end
		end

		if (levelText) then
			_G.GameTooltipTextLeft1:SetText(levelText .. gray .. ": |r" .. displayName)
		else
			_G.GameTooltipTextLeft1:SetText(displayName)
		end

	end

end

local GetCompareTooltips = function(tooltip)
	if (tooltip == _G.ItemRefTooltip) then
		return {
			_G.ItemRefShoppingTooltip1,
			_G.ItemRefShoppingTooltip2
		}
	end

	return {
		_G.ShoppingTooltip1,
		_G.ShoppingTooltip2
	}
end

local GetSafeFrameCenterX = function(frame)
	if (not frame) or (frame.IsForbidden and frame:IsForbidden()) or (not frame.GetCenter) then
		return nil
	end

	local ok, centerX = pcall(frame.GetCenter, frame)
	if (not ok) or (type(centerX) ~= "number") or IsSecretValue(centerX) then
		return nil
	end

	return centerX
end

local GetCompareTooltipGap = function(self)
	local themeData = self:GetTheme()
	local backdropStyle = themeData and themeData.backdropStyle
	if (not backdropStyle) then
		return 8
	end

	local edgePadding = math_max(
		math_abs(tonumber(backdropStyle.offsetLeft) or 0),
		math_abs(tonumber(backdropStyle.offsetRight) or 0)
	)
	local backdropInsets = backdropStyle.backdrop and backdropStyle.backdrop.insets
	local insetPadding = 0
	if (type(backdropInsets) == "table") then
		insetPadding = math_max(
			tonumber(backdropInsets.left) or 0,
			tonumber(backdropInsets.right) or 0
		)
	end

	return math_max(8, edgePadding + insetPadding)
end

local AnchorCompareTooltip = function(compareTooltip, anchorTooltip, side, gap)
	compareTooltip:ClearAllPoints()
	if (side == "LEFT") then
		compareTooltip:SetPoint("TOPRIGHT", anchorTooltip, "TOPLEFT", -gap, 0)
	else
		compareTooltip:SetPoint("TOPLEFT", anchorTooltip, "TOPRIGHT", gap, 0)
	end
end

local BuildVisibleCompareTooltipList = function(tooltip)
	local compareTooltips = {}
	for _, compareTooltip in ipairs(GetCompareTooltips(tooltip)) do
		if (compareTooltip and compareTooltip ~= tooltip and compareTooltip:IsShown() and (not compareTooltip:IsForbidden())) then
			compareTooltips[#compareTooltips + 1] = compareTooltip
		end
	end
	return compareTooltips
end

local AnchorCompareTooltipStack = function(compareTooltips, anchorTooltip, side, gap)
	local currentAnchor = anchorTooltip
	for _, compareTooltip in ipairs(compareTooltips) do
		AnchorCompareTooltip(compareTooltip, currentAnchor, side, gap)
		currentAnchor = compareTooltip
	end
end

local GetTooltipLinePrefix = function(tooltip)
	return tooltip and tooltip.GetName and tooltip:GetName()
end

local SetTooltipLineWrapWidth = function(line, width)
	if (not line) then
		return
	end
	local originalWidth = CompareTooltipLineWidthState[line]
	if (originalWidth == nil and line.GetWidth) then
		originalWidth = line:GetWidth()
		CompareTooltipLineWidthState[line] = originalWidth
	end
	if (line.SetWidth) then
		line:SetWidth(width or originalWidth or 0)
	end
	if (line.SetWordWrap) then
		line:SetWordWrap(width and true or false)
	end
	if (line.SetNonSpaceWrap) then
		line:SetNonSpaceWrap(false)
	end
	if (line.SetMaxLines) then
		line:SetMaxLines(0)
	end
end

local ApplyCompareTooltipWrapWidth = function(tooltip, width)
	if (not tooltip) or tooltip:IsForbidden() then
		return
	end

	local safeWidth = (type(width) == "number" and width > 0) and width or nil
	local prefix = GetTooltipLinePrefix(tooltip)
	if (not prefix) then
		return
	end

	local state = CompareTooltipWrapState[tooltip]
	if (state == safeWidth) then
		return
	end

	for i = 1, (tooltip:NumLines() or 0) do
		SetTooltipLineWrapWidth(_G[prefix .. "TextLeft" .. i], safeWidth)
		SetTooltipLineWrapWidth(_G[prefix .. "TextRight" .. i], safeWidth and math.floor(safeWidth * .45) or nil)
	end

	CompareTooltipWrapState[tooltip] = safeWidth
	tooltip:Show()
	if (tooltip.SetMinimumWidth) then
		tooltip:SetMinimumWidth(1)
	end
end

local GetSafeFrameEdge = function(frame, methodName, cacheKey)
	if (not frame) or (frame.IsForbidden and frame:IsForbidden()) then
		return nil
	end
	if (ns.GetSafeGeometryValue) then
		return ns.GetSafeGeometryValue(frame, methodName, cacheKey, nil)
	end
	local method = frame[methodName]
	if (type(method) ~= "function") then
		return nil
	end
	local ok, value = pcall(method, frame)
	if (not ok or IsSecretValue(value) or type(value) ~= "number") then
		return nil
	end
	return value
end

local GetCompareTooltipAvailableWidth = function(anchorTooltip, side, gap)
	local screenWidth = ns.GetSafeWidth and ns.GetSafeWidth(UIParent)
	if (type(screenWidth) ~= "number" or screenWidth <= 0) then
		return nil
	end

	local margin = gap + 12
	if (side == "LEFT") then
		local leftEdge = GetSafeFrameEdge(anchorTooltip, "GetLeft", "left")
		if (type(leftEdge) ~= "number") then
			return nil
		end
		return math_max(220, leftEdge - margin)
	else
		local rightEdge = GetSafeFrameEdge(anchorTooltip, "GetRight", "right")
		if (type(rightEdge) ~= "number") then
			return nil
		end
		return math_max(220, screenWidth - rightEdge - margin)
	end
end

local PrepareCompareTooltipWidths = function(compareTooltips, anchorTooltip, side, gap)
	local availableWidth = GetCompareTooltipAvailableWidth(anchorTooltip, side, gap)
	if (type(availableWidth) ~= "number") then
		for _, compareTooltip in ipairs(compareTooltips) do
			ApplyCompareTooltipWrapWidth(compareTooltip, nil)
		end
		return
	end

	for _, compareTooltip in ipairs(compareTooltips) do
		local currentWidth = ns.GetSafeWidth and ns.GetSafeWidth(compareTooltip)
		if (type(currentWidth) == "number" and currentWidth > availableWidth) then
			ApplyCompareTooltipWrapWidth(compareTooltip, availableWidth)
		else
			ApplyCompareTooltipWrapWidth(compareTooltip, nil)
		end
	end
end

local IsCompareTooltipStackOnScreen = function(compareTooltips)
	local maxRight = ns.GetSafeWidth and ns.GetSafeWidth(UIParent)
	if (type(maxRight) ~= "number" or maxRight <= 0) then
		return true
	end

	for _, compareTooltip in ipairs(compareTooltips) do
		local left
		local right

		if (ns.GetSafeGeometryValue) then
			left = ns.GetSafeGeometryValue(compareTooltip, "GetLeft", "left", nil)
			right = ns.GetSafeGeometryValue(compareTooltip, "GetRight", "right", nil)
		else
			left = compareTooltip.GetLeft and compareTooltip:GetLeft()
			right = compareTooltip.GetRight and compareTooltip:GetRight()
			if (IsSecretValue(left)) then left = nil end
			if (IsSecretValue(right)) then right = nil end
		end

		if (type(left) ~= "number" or type(right) ~= "number") then
			return true
		end
		if (left < 0 or right > maxRight) then
			return false
		end
	end

	return true
end

Tooltips.LayoutCompareTooltips = function(self, tooltip)
	if (self:IsDisabled()) then return end
	if (not tooltip) or tooltip:IsForbidden() or (not tooltip:IsShown()) then return end

	local primaryCenterX = GetSafeFrameCenterX(tooltip)
	local screenCenterX = GetSafeFrameCenterX(UIParent)
	local gap = GetCompareTooltipGap(self)
	local compareTooltips = BuildVisibleCompareTooltipList(tooltip)
	if (#compareTooltips == 0) then
		return
	end

	local preferredSide
	if (primaryCenterX and screenCenterX) then
		preferredSide = (primaryCenterX > screenCenterX) and "LEFT" or "RIGHT"
	else
		preferredSide = "RIGHT"
	end

	PrepareCompareTooltipWidths(compareTooltips, tooltip, preferredSide, gap)
	AnchorCompareTooltipStack(compareTooltips, tooltip, preferredSide, gap)
	if (not IsCompareTooltipStackOnScreen(compareTooltips)) then
		local fallbackSide = (preferredSide == "LEFT") and "RIGHT" or "LEFT"
		PrepareCompareTooltipWidths(compareTooltips, tooltip, fallbackSide, gap)
		AnchorCompareTooltipStack(compareTooltips, tooltip, fallbackSide, gap)
	end
end

Tooltips.QueueCompareTooltipRelayout = function(self)
	if (CompareRelayoutQueued) then return end
	CompareRelayoutQueued = true

	C_Timer.After(0, function()
		CompareRelayoutQueued = false

		if (_G.GameTooltip and _G.GameTooltip:IsShown() and (not _G.GameTooltip:IsForbidden())) then
			self:LayoutCompareTooltips(_G.GameTooltip)
		end

		if (_G.ItemRefTooltip and _G.ItemRefTooltip:IsShown() and (not _G.ItemRefTooltip:IsForbidden())) then
			self:LayoutCompareTooltips(_G.ItemRefTooltip)
		end
	end)
end

Tooltips.HookCompareTooltipLayoutUpdates = function(self, tooltip)
	if (not tooltip) or tooltip:IsForbidden() then return end
	if (CompareLayoutHooked[tooltip]) then return end

	tooltip:HookScript("OnShow", function(compareTooltip)
		if (compareTooltip and compareTooltip:IsShown()) then
			Tooltips:QueueCompareTooltipRelayout()
		end
	end)

	tooltip:HookScript("OnSizeChanged", function(compareTooltip)
		if (compareTooltip and compareTooltip:IsShown()) then
			Tooltips:QueueCompareTooltipRelayout()
		end
	end)

	CompareLayoutHooked[tooltip] = true
end

Tooltips.OnCompareItemShow = function(self, tooltip)
	if (self:IsDisabled()) then return end
	if (not tooltip) or (tooltip:IsForbidden()) then return end
	local compareTooltips = GetCompareTooltips(tooltip)
	local frameLevel = tooltip:GetFrameLevel()
	for _, compareTooltip in ipairs(compareTooltips) do
		if (compareTooltip and (not compareTooltip:IsForbidden())) then
			self:HookCompareTooltipLayoutUpdates(compareTooltip)
		end
	end
	for i, compareTooltip in ipairs(compareTooltips) do
		if (compareTooltip and compareTooltip:IsShown() and (not compareTooltip:IsForbidden())) then
			if (compareTooltip:GetFrameLevel() <= frameLevel) then
				compareTooltip:SetFrameLevel(frameLevel + i)
			end
		end
	end
	self:LayoutCompareTooltips(tooltip)
	self:QueueCompareTooltipRelayout()
end

Tooltips.SetUnitAura = function(self, tooltip, unit, index, filter)
	if (self:IsDisabled()) then return end
	if (not self.db.profile.showSpellID) then return end

	if (not tooltip) or (tooltip:IsForbidden()) then return end
	if (not IsSafeUnitToken(unit)) then return end

	if (C_Secrets and C_Secrets.ShouldUnitAuraIndexBeSecret) then
		local isAuraSecret = SafeBooleanValue(C_Secrets.ShouldUnitAuraIndexBeSecret(unit, index, filter))
		if (isAuraSecret) then
			return
		end
	end

	local name, _, _, _, _, _, source, _, _, spellID = UnitAura(unit, index, filter)
	if (IsSecretValue(name)) then name = nil end
	if (IsSecretValue(source)) then source = nil end
	if (IsSecretValue(spellID)) then spellID = nil end
	if (not name) then return end
	if (not spellID) then return end

	if (source) then
		local _, class = UnitClass(source)
		local color = Colors.class[class or "PRIEST"]
		local sourceName = UnitName(source)
		if (IsSecretValue(sourceName)) then sourceName = nil end
		tooltip:AddLine(" ")
	tooltip:AddDoubleLine(string_format("|cFFCA3C3C%s|r %s", ID_LABEL, spellID), string_format("%s%s|r", color.colorCode, sourceName or UNKNOWN))
	else
		tooltip:AddLine(" ")
	tooltip:AddLine(string_format("|cFFCA3C3C%s|r %s", ID_LABEL, spellID))
	end

	tooltip:Show()
end

Tooltips.SetUnitAuraInstanceID = function(self, tooltip, unit, auraInstanceID)
	if (self:IsDisabled()) then return end
	if (not self.db.profile.showSpellID) then return end
	if (not IsSafeUnitToken(unit)) then return end

	if (C_Secrets and C_Secrets.ShouldUnitAuraInstanceBeSecret) then
		local isAuraSecret = SafeBooleanValue(C_Secrets.ShouldUnitAuraInstanceBeSecret(unit, auraInstanceID))
		if (isAuraSecret) then
			return
		end
	end

	local data = C_UnitAuras.GetAuraDataByAuraInstanceID(unit, auraInstanceID)
	if (not data) then return end
	if (IsSecretValue(data.name) or (not data.name)) then return end
	if (IsSecretValue(data.spellId) or (not data.spellId)) then return end

	local sourceUnit = data.sourceUnit
	if (IsSecretValue(sourceUnit)) then
		sourceUnit = nil
	end

	if (sourceUnit) then
		local _, class = UnitClass(sourceUnit)
		local color = Colors.class[class or "PRIEST"]
		local sourceName = UnitName(sourceUnit)
		if (IsSecretValue(sourceName)) then sourceName = nil end
		tooltip:AddLine(" ")
	tooltip:AddDoubleLine(string_format("|cFFCA3C3C%s|r %s", ID_LABEL, data.spellId), string_format("%s%s|r", color.colorCode, sourceName or UNKNOWN))
	else
		tooltip:AddLine(" ")
	tooltip:AddLine(string_format("|cFFCA3C3C%s|r %s", ID_LABEL, data.spellId))
	end

	tooltip:Show()
end


Tooltips.SetDefaultAnchor = function(self, tooltip, parent)
	if (self:IsDisabled()) then return end
	if (self:IsConsolePortActive()) then return end -- Let ConsolePort manage tooltip anchors
	if (not tooltip) or (tooltip:IsForbidden()) then return end
	if (not self.db.profile.anchor) then return end
	if (parent and type(parent.IsForbidden) == "function" and parent:IsForbidden()) then return end
	if (parent and parent.owningMap) then return end -- MapCanvas pool pins (nil-named) always carry owningMap
	if (parent and parent.GetName) then
		local parentName = parent:GetName()
		if (parentName and (string_find(parentName, "MapCanvas") or string_find(parentName, "WorldMap") or string_find(parentName, "AreaPOI"))) then
			return
		end
	end

	local config = self.db.profile.savedPosition
	local ok = pcall(function()
		local scale = tonumber(config.scale) or 1
		if (scale <= 0) then
			scale = 1
		end
		local anchorPoint = (type(config[1]) == "string" and config[1]) or "BOTTOMRIGHT"

		if (self.db.profile.anchorToCursor) then

			tooltip:SetOwner(UIParent, "ANCHOR_CURSOR")
			tooltip:SetScale(scale)

		else

			local x = string_find(anchorPoint, "LEFT") and 10 or string_find(anchorPoint, "RIGHT") and -10 or 0
			local y = string_find(anchorPoint, "TOP") and -18 or string_find(anchorPoint, "BOTTOM") and 18 or 0

			tooltip:SetOwner(parent or UIParent, "ANCHOR_NONE")
			tooltip:SetScale(scale)
			tooltip:ClearAllPoints()
			tooltip:SetPoint(anchorPoint, UIParent, anchorPoint, ((config[2] or 0) + x)/scale, ((config[3] or 0) + y)/scale)
		end
	end)
	if (not ok) then
		return
	end

end

Tooltips.SetHooks = function(self)
	if (self:IsDisabled()) then return end

	if (not self:IsHooked("SharedTooltip_SetBackdropStyle")) then
		self:SecureHook("SharedTooltip_SetBackdropStyle", "UpdateBackdropTheme")
	end
	if (not self:IsHooked("GameTooltip_UnitColor")) then
		self:SecureHook("GameTooltip_UnitColor", "SetStatusBarColor")
	end
	if (not self:IsHooked("GameTooltip_ShowCompareItem")) then
		self:SecureHook("GameTooltip_ShowCompareItem", "OnCompareItemShow")
	end
	for _, compareTooltip in ipairs({
		_G.ShoppingTooltip1,
		_G.ShoppingTooltip2,
		_G.ItemRefShoppingTooltip1,
		_G.ItemRefShoppingTooltip2
	}) do
		if (compareTooltip) then
			self:HookCompareTooltipLayoutUpdates(compareTooltip)
		end
	end
	-- Don't override tooltip anchoring when ConsolePort is active
	if (not self:IsConsolePortActive()) then
		if (not self:IsHooked("GameTooltip_SetDefaultAnchor")) then
			self:SecureHook("GameTooltip_SetDefaultAnchor", "SetDefaultAnchor")
		end
	end

	if (TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum and Enum.TooltipDataType) then
		if (self.db.profile.showSpellID and Enum.TooltipDataType.Spell and not PostCallRegistered.Spell) then
			TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Spell, function(tooltip, ...)
				pcall(self.OnTooltipSetSpell, self, tooltip, ...)
			end)
			PostCallRegistered.Spell = true
		end
		if (self.db.profile.showItemID and Enum.TooltipDataType.Item and not PostCallRegistered.Item) then
			TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tooltip, ...)
				pcall(self.OnTooltipSetItem, self, tooltip, ...)
			end)
			PostCallRegistered.Item = true
		end
		if (not PostCallRegistered.Unit and Enum.TooltipDataType.Unit) then
			TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit, function(tooltip, ...)
				pcall(self.OnTooltipSetUnit, self, tooltip, ...)
			end)
			PostCallRegistered.Unit = true
		end
	else
		if (GameTooltip) then
			if (self.db.profile.showSpellID and not self:IsHooked(GameTooltip, "OnTooltipSetSpell")) then
				self:SecureHookScript(GameTooltip, "OnTooltipSetSpell", "OnTooltipSetSpell")
			end
			if (self.db.profile.showItemID and not self:IsHooked(GameTooltip, "OnTooltipSetItem")) then
				self:SecureHookScript(GameTooltip, "OnTooltipSetItem", "OnTooltipSetItem")
			end
			if (not self:IsHooked(GameTooltip, "OnTooltipSetUnit")) then self:SecureHookScript(GameTooltip, "OnTooltipSetUnit", "OnTooltipSetUnit") end
		end
	end

	if (GameTooltip) then
		if (not self:IsHooked(GameTooltip, "SetUnitAura")) then self:SecureHook(GameTooltip, "SetUnitAura", "SetUnitAura") end
		if (not self:IsHooked(GameTooltip, "SetUnitBuff")) then self:SecureHook(GameTooltip, "SetUnitBuff", "SetUnitAura") end
		if (not self:IsHooked(GameTooltip, "SetUnitDebuff")) then self:SecureHook(GameTooltip, "SetUnitDebuff", "SetUnitAura") end
		if (ns.WoW10) then
			if (not self:IsHooked(GameTooltip, "SetUnitBuffByAuraInstanceID")) then self:SecureHook(GameTooltip, "SetUnitBuffByAuraInstanceID", "SetUnitAuraInstanceID") end
			if (not self:IsHooked(GameTooltip, "SetUnitDebuffByAuraInstanceID")) then self:SecureHook(GameTooltip, "SetUnitDebuffByAuraInstanceID", "SetUnitAuraInstanceID") end
		end
		if (not self:IsHooked(GameTooltip, "OnTooltipCleared")) then self:SecureHookScript(GameTooltip, "OnTooltipCleared", "OnTooltipCleared") end
		if (GameTooltip.StatusBar and not self:IsHooked(GameTooltip.StatusBar, "OnValueChanged")) then self:SecureHookScript(GameTooltip.StatusBar, "OnValueChanged", "OnValueChanged") end
	end

end

Tooltips.UpdateAnchor = function(self)
	local config = self.db.profile.savedPosition

	self.anchor:SetSize(250, 120)
	self.anchor:SetScale(config.scale)
	self.anchor:ClearAllPoints()
	self.anchor:SetPoint(config[1], UIParent, config[1], config[2], config[3])
end

Tooltips.UpdateSettings = function(self)
	local disabled = self:IsDisabled()
	if (disabled) then
		if (self._stylingActive ~= false) then
			if (self.RemoveHooks) then self:RemoveHooks() end

			for _,tt in next,{
				_G.GameTooltip,
				_G.ShoppingTooltip1,
				_G.ShoppingTooltip2,
				_G.ItemRefTooltip,
				_G.ItemRefShoppingTooltip1,
				_G.ItemRefShoppingTooltip2,
				_G.FriendsTooltip,
				_G.WarCampaignTooltip,
				_G.EmbeddedItemTooltip,
				_G.ReputationParagonTooltip,
				_G.QuickKeybindTooltip,
				_G.QuestScrollFrame and _G.QuestScrollFrame.StoryTooltip,
				_G.QuestScrollFrame and _G.QuestScrollFrame.CampaignTooltip,
				_G.NarciGameTooltip
			} do
				if (tt and not tt:IsForbidden()) then
					if (tt.NineSlice and tt.NineSlice.GetParent and tt.NineSlice:GetParent() == UIHider) then
						tt.NineSlice:SetParent(tt)
						tt.NineSlice:SetAlpha(1)
					end
					tt:EnableDrawLayer("BACKGROUND")
					tt:EnableDrawLayer("BORDER")
					local backdrop = rawget(Backdrops, tt)
					if (backdrop) then backdrop:Hide() end
				end
			end

			local gtt = _G.GameTooltip
			local bar = _G.GameTooltipStatusBar
			if (gtt and bar) then
				bar:ClearAllPoints()
				bar:SetPoint("TOPLEFT", gtt, "BOTTOMLEFT", 0, 0)
				bar:SetPoint("TOPRIGHT", gtt, "BOTTOMRIGHT", 0, 0)
				bar:SetHeight(8)
				bar:SetStatusBarTexture("Interface/TargetingFrame/UI-StatusBar")
				local text = StatusBarText[bar]
				if (text) then text:Hide() end
			end

			self:RestoreHighlightState()
			self._stylingActive = false
		end
		return
	end

	if (ns.WoW10) then
		self:ApplyHighlightOverride()
	end

	self._stylingActive = true
	self:SetHooks()
	self:UpdateTooltipThemes()
end

Tooltips.PostUpdatePositionAndScale = function(self)
	if (self:IsDisabled()) then return end
	GameTooltip:SetScale(self.db.profile.savedPosition.scale * ns.API.GetEffectiveScale())
end

Tooltips.OnEnable = function(self)
	self:EnsureHighlightCache()
	self:UpdateConsolePortState()

	self:CreateAnchor(L["Tooltips"])

	self:RegisterEvent("PLAYER_ENTERING_WORLD", "UpdateTooltipThemes")
	self:RegisterEvent("ADDON_LOADED", "OnAddonLoaded")

	self:UpdateSettings()

	ns.MovableModulePrototype.OnEnable(self)
end

Tooltips.OnAddonLoaded = function(self, event, addon)
	if (addon == "ConsolePort" or addon == "ConsolePort_Bar") then
		if (self:UpdateConsolePortState()) then
			self:UpdateSettings()
		end
	end
end

	-- Try to unhook our hooks when disabling styling
	Tooltips.RemoveHooks = function(self)
		-- Global functions
		if (self:IsHooked("SharedTooltip_SetBackdropStyle")) then self:Unhook("SharedTooltip_SetBackdropStyle") end
		if (self:IsHooked("GameTooltip_UnitColor")) then self:Unhook("GameTooltip_UnitColor") end
		if (self:IsHooked("GameTooltip_ShowCompareItem")) then self:Unhook("GameTooltip_ShowCompareItem") end
		if (self:IsHooked("GameTooltip_SetDefaultAnchor")) then self:Unhook("GameTooltip_SetDefaultAnchor") end

		-- GameTooltip methods
		if (_G.GameTooltip) then
			local gtt = _G.GameTooltip
			if (self:IsHooked(gtt, "SetUnitAura")) then self:Unhook(gtt, "SetUnitAura") end
			if (self:IsHooked(gtt, "SetUnitBuff")) then self:Unhook(gtt, "SetUnitBuff") end
			if (self:IsHooked(gtt, "SetUnitDebuff")) then self:Unhook(gtt, "SetUnitDebuff") end
			if (ns.WoW10) then
				if (self:IsHooked(gtt, "SetUnitBuffByAuraInstanceID")) then self:Unhook(gtt, "SetUnitBuffByAuraInstanceID") end
				if (self:IsHooked(gtt, "SetUnitDebuffByAuraInstanceID")) then self:Unhook(gtt, "SetUnitDebuffByAuraInstanceID") end
			end
			-- Script hooks (use Unhook for scripts with AceHook)
			if (self:IsHooked(gtt, "OnTooltipCleared")) then self:Unhook(gtt, "OnTooltipCleared") end
			if (gtt.StatusBar and self:IsHooked(gtt.StatusBar, "OnValueChanged")) then self:Unhook(gtt.StatusBar, "OnValueChanged") end
		end
	end
