--[[

	The MIT License (MIT)

	Copyright (c) 2026 Lars Norberg
	Copyright (c) 2026 Jonas "JuNNeZ" Andersen (JuNNeZ Edition modifications)

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
local API = ns.API
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
local math_floor = math.floor
local math_max = math.max
local math_min = math.min
local ipairs = ipairs
local next = next
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

-- GLOBALS: AuraContainerInbound, C_UnitAuras, CreateColor, CreateFrame, GetMouseFocus, hooksecurefunc
-- GLOBALS: GameTooltip, GameTooltipTextLeft1, GameTooltipStatusBar, UIParent
-- GLOBALS: UnitClass, UnitExists, UnitEffectiveLevel, UnitHealth, UnitHealthMax, UnitName, UnitRealmRelationship, UnitIsDeadOrGhost, UnitIsPlayer
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

local SafeNumberValue = function(value)
	if (IsSecretValue(value) or type(value) ~= "number") then
		return nil
	end
	return value
end

local SafeUnitExists = function(unit)
	if (not IsSafeUnitToken(unit)) then
		return false
	end

	local ok, exists = API.TryCall(UnitExists, unit)
	if (ok) then
		return SafeBooleanValue(exists) and true or false
	end

	return false
end

local ShouldUnitIdentityBeSecret = function(unit)
	if (not IsSafeUnitToken(unit)) then
		return true
	end
	if (not C_Secrets) or (type(C_Secrets.ShouldUnitIdentityBeSecret) ~= "function") then
		return false
	end

	local ok, isSecret = API.TryCall(C_Secrets.ShouldUnitIdentityBeSecret, unit)
	if (ok) then
		return SafeBooleanValue(isSecret) and true or false
	end

	return true
end

local SafeGetTooltipUnitToken = function(tooltip)
	if (not tooltip) or tooltip:IsForbidden() or (not tooltip.GetUnit) then
		return
	end

	local mouseover = SafeUnitExists("mouseover") and "mouseover" or nil
	local ok, _, unit = API.TryCall(tooltip.GetUnit, tooltip)
	if (ok and IsSafeUnitToken(unit) and SafeUnitExists(unit)) then
		return unit
	end

	local focus = GetMouseFocus and GetMouseFocus()
	local focusUnit = focus and focus.GetAttribute and focus:GetAttribute("unit")
	if (IsSafeUnitToken(focusUnit) and SafeUnitExists(focusUnit)) then
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
	local ok, plate = API.TryCall(C_NamePlate.GetNamePlateForUnit, unit)
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

-- Tooltips > Hide in Combat, for "actionbars" or "unitframes". Independent of the styling switch.
-- Read by the unit frames' OnEnter and the action bars' settings pass (LibActionButton's own
-- "nocombat" tooltip mode); the pet and stance bars read the profile themselves.
function Tooltips:ShouldHideInCombat(kind)
	local profile = self.db and self.db.profile
	if (not profile) or (not profile.hideInCombat) then
		return false
	end
	if (kind == "actionbars") then
		return profile.hideActionBarTooltipsInCombat and true or false
	elseif (kind == "unitframes") then
		return profile.hideUnitFrameTooltipsInCombat and true or false
	end
	return false
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
	if (bg.EnableMouse) then
		bg:EnableMouse(false)
	end
	if (bg.SetMouseClickEnabled) then
		bg:SetMouseClickEnabled(false)
	end
	if (bg.SetMouseMotionEnabled) then
		bg:SetMouseMotionEnabled(false)
	end
	API.SafeCall("Tooltips.Backdrop.SetFrameLevel", function() bg:SetFrameLevel(k:GetFrameLevel()) end)

	-- WoW12: BackdropTemplate callbacks can receive secret dimensions.
	if (bg.OnBackdropSizeChanged) then
		local originalOnBackdropSizeChanged = bg.OnBackdropSizeChanged
		bg.OnBackdropSizeChanged = function(self, ...)
			API.TryCall(originalOnBackdropSizeChanged, self, ...)
		end
	end
	if (bg.ApplyBackdrop) then
		local originalApplyBackdrop = bg.ApplyBackdrop
		bg.ApplyBackdrop = function(self, ...)
			API.TryCall(originalApplyBackdrop, self, ...)
		end
	end
	if (bg.SetupTextureCoordinates) then
		local originalSetupTextureCoordinates = bg.SetupTextureCoordinates
		bg.SetupTextureCoordinates = function(self, ...)
			API.TryCall(originalSetupTextureCoordinates, self, ...)
		end
	end

	-- Hook into tooltip framelevel changes.
	-- Might help with some of the conflicts experienced with Silverdragon and Raider.IO
	hooksecurefunc(k, "SetFrameLevel", function(self)
		API.SafeCall("Tooltips.Backdrop.SyncFrameLevel", function() bg:SetFrameLevel(self:GetFrameLevel()) end)
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

local HideStatusBarText = function(bar)
	local text = StatusBarText[bar]
	if (text) then
		text:Hide()
	end
end

-- Compare tooltips wear an "Equipped" tab that ShoppingTooltipTemplate tucks
-- 1px behind the tooltip's top edge. Our backdrop hangs above that edge, so the
-- tab is tucked behind our border instead, as high as the theme says.
-- Without a style it gets the template's own anchor back.
local PlaceCompareHeader = function(tooltip, backdropStyle)
	local header = tooltip and tooltip.CompareHeader
	if (not header) then
		return
	end
	header:ClearAllPoints()
	header:SetPoint("BOTTOMLEFT", tooltip, "TOPLEFT", 0, backdropStyle and backdropStyle.compareHeaderOffsetY or -1)
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
	PlaceCompareHeader(tooltip)
end

local ManagedTooltipState = setmetatable({}, { __mode = "k" })
local CompareLayoutHooked = setmetatable({}, { __mode = "k" })

-- What the compare hook and the aura tooltip style last did, for /azdebug tooltips.
local Trace = { joins = 0, compare = {}, held = {} }

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
	local ok = API.SafeCall("Tooltips.ApplyBackdropTheme", function()
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

	PlaceCompareHeader(tooltip, db)

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
	local ok = API.SafeCall("Tooltips.ApplyStatusBarTheme", function()
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
					API.SafeCall("Tooltips.Bar.OnShow.SetPoint", function()
						backdrop:SetPoint("BOTTOM", 0, backdrop.offsetBottom + backdrop.offsetBarBottom)
					end)
					-- Force an update to the bar's health value and color.
					API.SafeCall("Tooltips.OnValueChanged", Tooltips.OnValueChanged, Tooltips)
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
					API.SafeCall("Tooltips.Bar.OnHide.SetPoint", function()
						backdrop:SetPoint("BOTTOM", 0, backdrop.offsetBottom)
					end)
				end
			end
		end)
	end

	GetStatusBarText(bar, db.valuePosition, db.valueFont, db.valueColor)
	StatusBarThemeSignature[bar] = sig

end

-- Blizzard's native aura containers (the player buffs, and the player frame's and the plates'
-- aura rows) show their own AuraButtonTooltip. It is forbidden, hidden from addons and driven from
-- Blizzard's secure environment, so SharedTooltip_SetBackdropStyle never reaches us for it.
-- AuraContainerInbound is the one way in, the same on Retail and Forever. Blizzard never calls it
-- itself, so a style set here stays until this module or another addon changes it.
local GetAuraContainerInbound = function()
	local inbound = _G.AuraContainerInbound
	if (type(inbound) == "table" and type(inbound.SetTooltipBackdrop) == "function") then
		return inbound
	end
end

local ToColor = function(color)
	return CreateColor(color[1], color[2], color[3], color[4] or 1)
end

Tooltips.UpdateAuraTooltipTheme = function(self)
	-- Blizzard_AuraContainer can load after us; OnAddonLoaded comes back here when it does.
	local inbound = GetAuraContainerInbound()
	if (not inbound) then return end

	if (self:IsDisabled()) then
		-- Only our own style is undone; another addon's is not ours to reset.
		if (self._auraTooltipStyle and type(inbound.ResetTooltipStyle) == "function") then
			API.SafeCall("Tooltips.ResetAuraTooltipStyle", inbound.ResetTooltipStyle)
			Trace.aura = "reset to Blizzard's"
		end
		self._auraTooltipStyle = nil
		return
	end

	local themeData = self:GetTheme()
	local db = themeData and themeData.backdropStyle
	if (not db) or (self._auraTooltipStyle == db) then return end

	local ok = API.SafeCall("Tooltips.ApplyAuraTooltipTheme", inbound.SetTooltipBackdrop, {
		backdropInfo = db.backdrop,
		borderColor = ToColor(db.backdropBorderColor),
		centerColor = ToColor(db.backdropColor),
		-- Our backdrop's reach past the tooltip, as UpdateBackdropTheme anchors it.
		anchorOffsets = { left = db.offsetLeft, right = db.offsetRight, top = db.offsetTop, bottom = db.offsetBottom }
	})
	self._auraTooltipStyle = ok and db or nil
	Trace.aura = ok and ("styled, " .. tostring(self._cachedThemeKey)) or "styling failed, see BugSack"
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
	self:UpdateAuraTooltipTheme()
end

Tooltips.SetHealthValue = function(self, unit)
	if (self:IsDisabled()) then return end
	local safeUnit = IsSafeUnitToken(unit) and unit or nil
	local bar = GetTooltipStatusBar()
	if (not bar) then return end

	-- It could be a wall or gate that does not count as a unit,
	-- so we need to check for the existence as well as it's alive status.
	local unitExists = safeUnit and SafeUnitExists(safeUnit)
	local unitIsDead
	if (unitExists) then
		local okDead, dead = API.TryCall(UnitIsDeadOrGhost, safeUnit)
		unitIsDead = okDead and SafeBooleanValue(dead)
	end
	if (unitExists and unitIsDead) then
		if (bar:IsShown()) then
			bar:Hide()
		end
	else

		local msg, min, max

		if (safeUnit and unitExists) then
			local okHealth, min = API.TryCall(UnitHealth, safeUnit)
			local okMaxHealth, max = API.TryCall(UnitHealthMax, safeUnit)
			if (not okHealth) then min = nil end
			if (not okMaxHealth) then max = nil end
			-- Secret health cannot be printed. Hide the text rather than leave the last unit's numbers.
			if (IsSecretValue(min) or IsSecretValue(max)) then
				HideStatusBarText(bar)
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
			local okValue, min = API.TryCall(bar.GetValue, bar)
			local okRange, _, max = API.TryCall(bar.GetMinMaxValues, bar)
			if (not okValue) or (not okRange) then
				return
			end
			if (IsSecretValue(min) or IsSecretValue(max)) then
				HideStatusBarText(bar)
				return
			end
			if (type(min) ~= "number" or type(max) ~= "number" or max <= 0) then
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
	local color
	if (IsSafeUnitToken(unit)) then
		local okColor, unitColor = API.TryCall(GetUnitColor, unit)
		if (okColor) then
			color = unitColor
		end
	end
	if (color) then
		API.SafeCall("Tooltips.Bar.SetStatusBarColor", bar.SetStatusBarColor, bar, color[1], color[2], color[3])
	else
		local r, g, b = GameTooltipTextLeft1:GetTextColor()
		API.SafeCall("Tooltips.Bar.SetStatusBarColor.rgb", bar.SetStatusBarColor, bar, r, g, b)
	end
end

Tooltips.OnValueChanged = function(self)
	if (self:IsDisabled()) then return end
	if (not GameTooltip or not GameTooltip.StatusBar or not GameTooltip.StatusBar.GetParent) then return end
	local parent = GameTooltip.StatusBar:GetParent()
	local unit = SafeGetTooltipUnitToken(parent)

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
		API.SafeCall("Tooltips.Bar.Hide", bar.Hide, bar)
	end
end

local TooltipHasLineText

Tooltips.OnTooltipSetSpell = function(self, tooltip, data)
	if (self:IsDisabled()) then return end
	if (not self.db.profile.showSpellID) then return end

	if (not tooltip) or (tooltip:IsForbidden()) then return end

	local id = (data and data.id) or (tooltip.GetSpell and select(2, tooltip:GetSpell()))
	if (not id) then return end

	local idLine = string_format("|cFFCA3C3C%s|r %d", ID_LABEL, id)

	if (TooltipHasLineText(tooltip, idLine)) then
		return
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
		if (TooltipHasLineText(tooltip, itemID)) then
			return
		end
		tooltip:AddLine(" ")
		tooltip:AddLine(itemID)
		tooltip:Show()
	end

end

Tooltips.OnTooltipSetUnit = function(self, tooltip, data)
	if (self:IsDisabled()) then return end
	if (not tooltip) or (tooltip:IsForbidden()) then return end

	-- Unit post-calls run for every tooltip given unit data, not only GameTooltip.
	local nameLine = tooltip.TextLeft1
	if (not nameLine) then return end

	local unit = SafeGetTooltipUnitToken(tooltip)
	if (not unit) or ShouldUnitIdentityBeSecret(unit) then
		return
	end

	local okColor, color = API.TryCall(GetUnitColor, unit)
	if (not okColor) then
		color = nil
	end
	if (color) then

		local okName, unitName, unitRealm = API.TryCall(UnitName, unit)
		if (not okName) then
			return
		end
		-- Blizzard already drew a secret name; "Unknown" would only replace it.
		if (IsSecretValue(unitName)) then return end
		if (IsSecretValue(unitRealm)) then unitRealm = nil end
		unitName = unitName or _G.UNKNOWN
		local displayName = color.colorCode..unitName.."|r"
		local gray = Colors.quest.gray.colorCode
		local levelText

		local okPlayer, isPlayer = API.TryCall(UnitIsPlayer, unit)
		isPlayer = okPlayer and SafeBooleanValue(isPlayer)
		if (isPlayer) then
			if (unitRealm and unitRealm ~= "") then
				local okRelationship, relationship = API.TryCall(UnitRealmRelationship, unit)
				if (not okRelationship) then relationship = nil end
				if (IsSecretValue(relationship)) then
					relationship = nil
				end
				if (relationship == _G.LE_REALM_RELATION_COALESCED) then
					displayName = displayName ..gray.. _G.FOREIGN_SERVER_LABEL .."|r"

				elseif (relationship == _G.LE_REALM_RELATION_VIRTUAL) then
					displayName = displayName ..gray..  _G.INTERACTIVE_SERVER_LABEL .."|r"
				end
			end
			local okAFK, isAFK = API.TryCall(UnitIsAFK, unit)
			isAFK = okAFK and SafeBooleanValue(isAFK)
			if (isAFK) then
				displayName = displayName ..gray.. " <" .. _G.AFK ..">|r"
			end
		end

		if (levelText) then
			nameLine:SetText(levelText .. gray .. ": |r" .. displayName)
		else
			nameLine:SetText(displayName)
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

local HideCompareTooltips = function(tooltip)
	for _, compareTooltip in ipairs(GetCompareTooltips(tooltip)) do
		if (compareTooltip and compareTooltip.Hide) then
			compareTooltip:Hide()
		end
	end
end

local SuppressCompareTooltipWithoutModifier = function(compareTooltip)
	if (not compareTooltip) or compareTooltip:IsForbidden() then
		return
	end

	if (compareTooltip.SetAlpha) then
		compareTooltip:SetAlpha(0)
	end
	if (compareTooltip.Hide) then
		compareTooltip:Hide()
	end
	if (compareTooltip.SetAlpha) then
		compareTooltip:SetAlpha(1)
	end
end

local IsCompareModifierActive = function()
	if (type(IsModifiedClick) ~= "function") then
		return false
	end
	return IsModifiedClick("COMPAREITEMS") and true or false
end

local GetTooltipLinePrefix = function(tooltip)
	return tooltip and tooltip.GetName and tooltip:GetName()
end

TooltipHasLineText = function(tooltip, text)
	if (not tooltip) or tooltip:IsForbidden() or IsSecretValue(text) or (not text) then
		return false
	end

	local prefix = GetTooltipLinePrefix(tooltip)
	if (not prefix) then
		return false
	end

	for i = 1, (tooltip:NumLines() or 0) do
		local leftLine = _G[prefix .. "TextLeft" .. i]
		local rightLine = _G[prefix .. "TextRight" .. i]
		local leftText = leftLine and leftLine.GetText and leftLine:GetText()
		local rightText = rightLine and rightLine.GetText and rightLine:GetText()
		if ((not IsSecretValue(leftText) and leftText == text) or (not IsSecretValue(rightText) and rightText == text)) then
			return true
		end
	end

	return false
end

Tooltips.HookCompareTooltipLayoutUpdates = function(self, tooltip)
	if (not tooltip) or tooltip:IsForbidden() then return end
	if (CompareLayoutHooked[tooltip]) then return end

	-- OnShow: suppress compare tooltips that appear without modifier held.
	tooltip:HookScript("OnShow", function(compareTooltip)
		if (compareTooltip and compareTooltip:IsShown()) then
			if (not IsCompareModifierActive()) then
				SuppressCompareTooltipWithoutModifier(compareTooltip)
				return
			end
		end
	end)

	CompareLayoutHooked[tooltip] = true
end

Tooltips.OnCompareItemShow = function(self, tooltip)
	if (self:IsDisabled()) then return end
	if (not tooltip) or (tooltip:IsForbidden()) then return end
	-- Defer all frame mutations to the next frame so the SecureHook body
	-- stays read-only (prevents taint on Ctrl-click dress-up/preview).
	C_Timer.After(0, function()
		if (self:IsDisabled()) then return end
		if (not tooltip) or tooltip:IsForbidden() then return end
		if (not IsCompareModifierActive()) then
			for _, ct in ipairs(GetCompareTooltips(tooltip)) do
				if (ct and not ct:IsForbidden()) then
					SuppressCompareTooltipWithoutModifier(ct)
				end
			end
			HideCompareTooltips(tooltip)
			return
		end

		local compareTooltips = GetCompareTooltips(tooltip)
		for _, ct in ipairs(compareTooltips) do
			if (ct and not ct:IsForbidden()) then
				self:HookCompareTooltipLayoutUpdates(ct)
			end
		end

		local frameLevel = tooltip:GetFrameLevel()
		for i, compareTooltip in ipairs(compareTooltips) do
			if (compareTooltip and compareTooltip:IsShown() and (not compareTooltip:IsForbidden())) then
				if (compareTooltip:GetFrameLevel() <= frameLevel) then
					compareTooltip:SetFrameLevel(frameLevel + i)
				end
			end
		end

		-- Blizzard's TooltipComparisonManager handles compare tooltip
		-- positioning (side selection, screen-edge sliding, stacking).
		-- AzeriteUI does NOT reposition compare tooltips.  Previous
		-- attempts to override Blizzard's placement caused persistent
		-- jitter because two independent positioning systems fought over
		-- the same anchors with a mandatory 1-frame delay between them.
		-- The only adjustment is OnCompareTooltipSetPoint, inside Blizzard's calls.
	end)
end

-- TooltipComparisonManager:AnchorShoppingTooltips puts each compare tooltip's TOP on the tooltip it
-- compares against, then joins its side edge to its neighbour's, edge to edge. Our backdrops hang
-- outside their tooltips, so the borders overlapped.
-- Widening the joins after the manager returned (5.10.1, then the first cut of the tooltip audit)
-- set the offsets, and the client still drew the tooltips edge to edge: something anchors them
-- again after that, or the TOP anchor's centre wins over the join's offset (FixLog 2026-09-25).
-- So each join is made again from inside the SetPoint call that makes it, whoever calls it, with
-- the gap and, where the join can carry the height as well, without the TOP anchor. Nothing is
-- read back from the frame (its anchoring can be secret) and nothing waits for a later frame.
-- Blizzard still picks the side, the stacking and the screen-edge slide.
-- [point] = { relativePoint, which way the gap goes, the top-aligned point and relative point
-- that make the same join }
local CompareJoins = {
	LEFT = { "RIGHT", 1, "TOPLEFT", "TOPRIGHT" },
	RIGHT = { "LEFT", -1, "TOPRIGHT", "TOPLEFT" },
	TOPLEFT = { "TOPRIGHT", 1, "TOPLEFT", "TOPRIGHT" },
	TOPRIGHT = { "TOPLEFT", -1, "TOPRIGHT", "TOPLEFT" }
}

-- Every compare tooltip there is: GameTooltip's and ItemRefTooltip's.
local CompareTooltips = function()
	local list = {}
	for _, name in ipairs({ "ShoppingTooltip1", "ShoppingTooltip2", "ItemRefShoppingTooltip1", "ItemRefShoppingTooltip2" }) do
		local compareTooltip = _G[name]
		if (compareTooltip) and (not compareTooltip:IsForbidden()) then
			list[#list + 1] = compareTooltip
		end
	end
	return list
end

local CountAnswers = function(...)
	return select("#", ...), ...
end

-- How far our backdrop reaches past one side of a tooltip, in that tooltip's scale.
local GetBackdropOverhang = function(frame, side)
	local backdrop = frame and rawget(Backdrops, frame)
	if (not backdrop) or (not backdrop:IsShown()) then
		return 0
	end
	if (side == "LEFT") then
		return math_max(0, -(backdrop.offsetLeft or 0))
	end
	return math_max(0, backdrop.offsetRight or 0)
end

-- /azdebug tooltips: whether a join we made was still ours a frame later. Read only.
local JoinCheckPending = setmetatable({}, { __mode = "k" })
local CheckJoinHeld = function(compareTooltip, name, point, x)
	if (JoinCheckPending[compareTooltip]) or (not C_Timer) or (not C_Timer.After) then return end
	JoinCheckPending[compareTooltip] = true
	C_Timer.After(0, function()
		JoinCheckPending[compareTooltip] = nil
		local count, _, _, _, heldX = CountAnswers(compareTooltip:GetPointByName(point))
		if (count == 0) then
			Trace.held[name] = "gone a frame later"
		elseif (IsSecretValue(heldX)) then
			Trace.held[name] = "unknown, anchoring secret"
		elseif (math_abs(heldX - x) < .01) then
			Trace.held[name] = "held a frame later"
		else
			Trace.held[name] = string_format("moved to %.1f a frame later", heldX)
		end
	end)
end

-- One compare tooltip's join made again with room for both borders. Returns what it did.
local JoinCompareTooltip = function(self, compareTooltip, point, relativeTo)
	-- Both backdrops are built before they are measured: the first compare of a session
	-- can come before a sized tooltip let UpdateBackdropTheme build one.
	self:UpdateBackdropTheme(compareTooltip)
	self:UpdateBackdropTheme(relativeTo)
	local join = CompareJoins[point]
	local direction = join[2]
	local gap = GetBackdropOverhang(compareTooltip, direction > 0 and "LEFT" or "RIGHT")
	local reach = GetBackdropOverhang(relativeTo, direction > 0 and "RIGHT" or "LEFT")
	if (reach > 0) then
		-- The offset is in the compare tooltip's scale, the other backdrop in its own.
		local ownScale, otherScale = compareTooltip:GetEffectiveScale(), relativeTo:GetEffectiveScale()
		if (IsSecretValue(ownScale) or IsSecretValue(otherScale)) then
			return "secret scale, left edge to edge"
		end
		gap = gap + reach * otherScale / ownScale
	end
	if (gap <= 0) then
		return "no backdrop overhang"
	end
	-- The TOP anchor is on the manager's anchorFrame. A join to the other compare tooltip, or to
	-- that same frame, gives the same height, so it replaces TOP. A tooltip embedded in another
	-- (quest rewards) is joined to the outer one, and there TOP stays.
	local manager = _G.TooltipComparisonManager
	if (point == "TOPLEFT" or point == "TOPRIGHT") or (manager and manager.anchorFrame == relativeTo) then
		compareTooltip:ClearAllPoints()
		compareTooltip:SetPoint(join[3], relativeTo, join[4], direction * gap, 0)
		CheckJoinHeld(compareTooltip, compareTooltip:GetName() or "?", join[3], direction * gap)
		return string_format("%s join widened by %.1f, made as %s alone", point, gap, join[3])
	end
	compareTooltip:SetPoint(point, relativeTo, join[1], direction * gap, 0)
	CheckJoinHeld(compareTooltip, compareTooltip:GetName() or "?", point, direction * gap)
	return string_format("%s join widened by %.1f, TOP kept (embedded)", point, gap)
end

-- A post-hook on a compare tooltip's own SetPoint, so it runs inside every call that anchors it.
Tooltips.OnCompareTooltipSetPoint = function(self, compareTooltip, point, relativeTo, relativePoint, x, y)
	if (self:IsDisabled()) then return end
	if (IsSecretValue(point) or IsSecretValue(relativeTo) or IsSecretValue(relativePoint) or IsSecretValue(x) or IsSecretValue(y)) then
		return
	end
	-- Only a join as AnchorShoppingTooltips makes it: to a frame's opposite edge, with no offsets.
	-- Our own SetPoint below carries an offset, so it does not come back here.
	local join = (type(point) == "string") and CompareJoins[point]
	if (not join) or (type(relativeTo) ~= "table") or (relativePoint ~= join[1]) or (x and x ~= 0) or (y and y ~= 0) then
		return
	end
	if (compareTooltip:IsForbidden()) then return end
	local shown = compareTooltip:IsShown()
	if (IsSecretValue(shown) or not shown) then return end
	local ok, result = API.SafeCall("Tooltips.JoinCompareTooltip", JoinCompareTooltip, self, compareTooltip, point, relativeTo)
	Trace.joins = Trace.joins + 1
	Trace.compare[compareTooltip:GetName() or "?"] = ok and result or "failed, see BugSack"
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

	-- UnitAura exists only on Classic clients (Blizzard_Deprecated/Classic); Retail and Forever
	-- have the table form.
	local data = C_UnitAuras.GetAuraDataByIndex(unit, index, filter)
	if (not data) then return end
	local name, source, spellID = data.name, data.sourceUnit, data.spellId
	if (IsSecretValue(name)) then name = nil end
	if (IsSecretValue(source)) then source = nil end
	if (IsSecretValue(spellID)) then spellID = nil end
	if (not name) then return end
	if (not spellID) then return end

	if (source) then
		local _, class = UnitClass(source)
		if (IsSecretValue(class)) then class = nil end
		local color = Colors.class[class or "PRIEST"]
		local sourceName = UnitName(source)
		if (IsSecretValue(sourceName)) then sourceName = nil end
		local leftText = string_format("|cFFCA3C3C%s|r %s", ID_LABEL, spellID)
		local rightText = string_format("%s%s|r", color.colorCode, sourceName or UNKNOWN)
		if (TooltipHasLineText(tooltip, leftText) or TooltipHasLineText(tooltip, rightText)) then
			return
		end
		tooltip:AddLine(" ")
		tooltip:AddDoubleLine(leftText, rightText)
	else
		local spellLine = string_format("|cFFCA3C3C%s|r %s", ID_LABEL, spellID)
		if (TooltipHasLineText(tooltip, spellLine)) then
			return
		end
		tooltip:AddLine(" ")
		tooltip:AddLine(spellLine)
	end

	tooltip:Show()
end

-- SetUnitBuff and SetUnitDebuff imply HELPFUL and HARMFUL; their filter adds to it.
local WithAuraKind = function(filter, kind)
	if (IsSecretValue(filter)) then return end
	if (type(filter) ~= "string") or (filter == "") then return kind end
	if (string_find(filter, "HELPFUL", 1, true) or string_find(filter, "HARMFUL", 1, true)) then return filter end
	return kind .. "|" .. filter
end

Tooltips.SetUnitBuff = function(self, tooltip, unit, index, filter)
	filter = WithAuraKind(filter, "HELPFUL")
	if (filter) then self:SetUnitAura(tooltip, unit, index, filter) end
end

Tooltips.SetUnitDebuff = function(self, tooltip, unit, index, filter)
	filter = WithAuraKind(filter, "HARMFUL")
	if (filter) then self:SetUnitAura(tooltip, unit, index, filter) end
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
		if (IsSecretValue(class)) then class = nil end
		local color = Colors.class[class or "PRIEST"]
		local sourceName = UnitName(sourceUnit)
		if (IsSecretValue(sourceName)) then sourceName = nil end
		local leftText = string_format("|cFFCA3C3C%s|r %s", ID_LABEL, data.spellId)
		local rightText = string_format("%s%s|r", color.colorCode, sourceName or UNKNOWN)
		if (TooltipHasLineText(tooltip, leftText) or TooltipHasLineText(tooltip, rightText)) then
			return
		end
		tooltip:AddLine(" ")
	tooltip:AddDoubleLine(leftText, rightText)
	else
		local spellLine = string_format("|cFFCA3C3C%s|r %s", ID_LABEL, data.spellId)
		if (TooltipHasLineText(tooltip, spellLine)) then
			return
		end
		tooltip:AddLine(" ")
	tooltip:AddLine(spellLine)
	end

	tooltip:Show()
end


-- GameTooltip's scale is ours; its compare tooltips were left at their own, so they came out
-- bigger than the tooltip they compare against. Both are children of UIParent.
local MatchCompareScale = function(tooltip, scale)
	local compareTooltips = tooltip.shoppingTooltips
	if (type(compareTooltips) ~= "table") then return end
	for _, compareTooltip in ipairs(compareTooltips) do
		if (not compareTooltip:IsForbidden()) then
			compareTooltip:SetScale(scale)
		end
	end
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
	local ok = API.SafeCall("Tooltips.ApplySavedPosition", function()
		local scale = tonumber(config.scale) or 1
		if (scale <= 0) then
			scale = 1
		end
		local anchorPoint = (type(config[1]) == "string" and config[1]) or "BOTTOMRIGHT"

		if (self.db.profile.anchorToCursor) then

			tooltip:SetOwner(UIParent, "ANCHOR_CURSOR")
			tooltip:SetScale(scale)
			MatchCompareScale(tooltip, scale)

		else

			local x = string_find(anchorPoint, "LEFT") and 10 or string_find(anchorPoint, "RIGHT") and -10 or 0
			local y = string_find(anchorPoint, "TOP") and -18 or string_find(anchorPoint, "BOTTOM") and 18 or 0

			tooltip:SetOwner(parent or UIParent, "ANCHOR_NONE")
			tooltip:SetScale(scale)
			MatchCompareScale(tooltip, scale)
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
	for _, compareTooltip in ipairs(CompareTooltips()) do
		self:HookCompareTooltipLayoutUpdates(compareTooltip)
		if (not self:IsHooked(compareTooltip, "SetPoint")) then
			self:SecureHook(compareTooltip, "SetPoint", "OnCompareTooltipSetPoint")
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
				API.SafeCall("Tooltips.OnTooltipSetSpell", self.OnTooltipSetSpell, self, tooltip, ...)
			end)
			PostCallRegistered.Spell = true
		end
		if (self.db.profile.showItemID and Enum.TooltipDataType.Item and not PostCallRegistered.Item) then
			TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tooltip, ...)
				API.SafeCall("Tooltips.OnTooltipSetItem", self.OnTooltipSetItem, self, tooltip, ...)
			end)
			PostCallRegistered.Item = true
		end
		if (not PostCallRegistered.Unit and Enum.TooltipDataType.Unit) then
			TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit, function(tooltip, ...)
				API.SafeCall("Tooltips.OnTooltipSetUnit", self.OnTooltipSetUnit, self, tooltip, ...)
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
		if (not self:IsHooked(GameTooltip, "SetUnitBuff")) then self:SecureHook(GameTooltip, "SetUnitBuff", "SetUnitBuff") end
		if (not self:IsHooked(GameTooltip, "SetUnitDebuff")) then self:SecureHook(GameTooltip, "SetUnitDebuff", "SetUnitDebuff") end
		if (ns.WoW10) then
			if (not self:IsHooked(GameTooltip, "SetUnitBuffByAuraInstanceID")) then self:SecureHook(GameTooltip, "SetUnitBuffByAuraInstanceID", "SetUnitAuraInstanceID") end
			if (not self:IsHooked(GameTooltip, "SetUnitDebuffByAuraInstanceID")) then self:SecureHook(GameTooltip, "SetUnitDebuffByAuraInstanceID", "SetUnitAuraInstanceID") end
			-- Blizzard's plate auras and the cooldown viewer use this one.
			if (GameTooltip.SetUnitAuraByAuraInstanceID and not self:IsHooked(GameTooltip, "SetUnitAuraByAuraInstanceID")) then self:SecureHook(GameTooltip, "SetUnitAuraByAuraInstanceID", "SetUnitAuraInstanceID") end
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
	-- The action bars hand the combat switch to LibActionButton in their own settings pass, which
	-- waits out combat by itself. Run it when the answer changes, and at login only if it is on.
	local hideActionBars = self:ShouldHideInCombat("actionbars")
	if (hideActionBars ~= self._hideActionBarTooltips) and (hideActionBars or self._hideActionBarTooltips ~= nil) then
		local actionBars = ns:GetModule("ActionBars", true)
		if (actionBars and actionBars:IsEnabled() and actionBars.UpdateSettings) then
			actionBars:UpdateSettings()
		end
	end
	self._hideActionBarTooltips = hideActionBars

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
				-- Also forgets the style signature, so switching back on restyles in
				-- full instead of taking UpdateBackdropTheme's nothing-changed return.
				RestoreBlizzardTooltipBackdrop(tt)
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
			self:UpdateAuraTooltipTheme()
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
	elseif (addon == "Blizzard_AuraContainer") then
		self:UpdateAuraTooltipTheme()
	end
end

-- /azdebug tooltips: what the compare hook and the aura tooltip style last did.
Tooltips.PrintDiagnostics = function(self)
	local hooked = 0
	for _, compareTooltip in ipairs(CompareTooltips()) do
		if (self:IsHooked(compareTooltip, "SetPoint")) then hooked = hooked + 1 end
	end
	print("|cff33ff99AzeriteUI tooltips:|r", self:IsDisabled() and "styling off" or "styling on", "theme:", self.db and self.db.profile.theme)
	print("|cfff0f0f0  compare tooltips hooked:|r", hooked, "joins made:", Trace.joins)
	for _, name in ipairs({ "ShoppingTooltip1", "ShoppingTooltip2", "ItemRefShoppingTooltip1", "ItemRefShoppingTooltip2" }) do
		if (Trace.compare[name]) then
			print("|cfff0f0f0  " .. name .. ":|r", Trace.compare[name] .. ";", Trace.held[name] or "not checked yet")
		end
	end
	print("|cfff0f0f0  aura tooltip:|r", Trace.aura or (GetAuraContainerInbound() and "not styled" or "Blizzard_AuraContainer not loaded"))
end

	-- Try to unhook our hooks when disabling styling
	Tooltips.RemoveHooks = function(self)
		-- Global functions
		if (self:IsHooked("SharedTooltip_SetBackdropStyle")) then self:Unhook("SharedTooltip_SetBackdropStyle") end
		if (self:IsHooked("GameTooltip_UnitColor")) then self:Unhook("GameTooltip_UnitColor") end
		if (self:IsHooked("GameTooltip_ShowCompareItem")) then self:Unhook("GameTooltip_ShowCompareItem") end
		if (self:IsHooked("GameTooltip_SetDefaultAnchor")) then self:Unhook("GameTooltip_SetDefaultAnchor") end
		for _, compareTooltip in ipairs(CompareTooltips()) do
			if (self:IsHooked(compareTooltip, "SetPoint")) then self:Unhook(compareTooltip, "SetPoint") end
		end

		-- GameTooltip methods
		if (_G.GameTooltip) then
			local gtt = _G.GameTooltip
			if (self:IsHooked(gtt, "SetUnitAura")) then self:Unhook(gtt, "SetUnitAura") end
			if (self:IsHooked(gtt, "SetUnitBuff")) then self:Unhook(gtt, "SetUnitBuff") end
			if (self:IsHooked(gtt, "SetUnitDebuff")) then self:Unhook(gtt, "SetUnitDebuff") end
			if (ns.WoW10) then
				if (self:IsHooked(gtt, "SetUnitBuffByAuraInstanceID")) then self:Unhook(gtt, "SetUnitBuffByAuraInstanceID") end
				if (self:IsHooked(gtt, "SetUnitDebuffByAuraInstanceID")) then self:Unhook(gtt, "SetUnitDebuffByAuraInstanceID") end
				if (self:IsHooked(gtt, "SetUnitAuraByAuraInstanceID")) then self:Unhook(gtt, "SetUnitAuraByAuraInstanceID") end
			end
			-- Script hooks (use Unhook for scripts with AceHook)
			if (self:IsHooked(gtt, "OnTooltipCleared")) then self:Unhook(gtt, "OnTooltipCleared") end
			if (gtt.StatusBar and self:IsHooked(gtt.StatusBar, "OnValueChanged")) then self:Unhook(gtt.StatusBar, "OnValueChanged") end
		end
	end
