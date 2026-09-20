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

local VehicleExit = ns:NewModule("VehicleExit", ns.MovableModulePrototype, "LibMoreEvents-1.0", "AceHook-3.0")

-- GLOBALS: GameTooltip, GameTooltip_SetDefaultAnchor, Minimap, UIParent
-- GLOBALS: CreateFrame, InCombatLockdown, RegisterStateDriver
-- GLOBALS: UnitOnTaxi, IsMounted, IsPossessBarVisible, PetCanBeDismissed, PetDismiss, TaxiRequestEarlyLanding
-- GLOBALS: TAXI_CANCEL, TAXI_CANCEL_DESCRIPTION
-- GLOBALS: PET_DISMISS, NEWBIE_TOOLTIP_UNIT_PET_DISMISS
-- GLOBALS: BINDING_NAME_VEHICLEEXIT

-- Lua API
local unpack = unpack

-- Addon API
local Colors = ns.Colors

-- The minimap's own default placement, mirrored from Components/Misc/Minimap.lua:
-- 40 out from the lower right corner of the screen, and 198 wide. Only used to
-- work out where a detached button starts out, so drift here costs nothing more
-- than a first position the player is about to change anyway.
local MINIMAP_DEFAULT_INSET = 40
local MINIMAP_DEFAULT_SIZE = 198

local defaults = { profile = ns:Merge({
	useCustomPosition = false,
	customPositionInitialized = false
}, ns.MovableModulePrototype.defaults) }

-- Generate module defaults on the fly
-- to recalculate default values relying on
-- changing factors like user interface scale.
VehicleExit.GenerateDefaults = function(self)
	local config = ns.GetConfig("VehicleExitButton")
	local position = config and config.VehicleExitButtonPosition

	-- The default custom position is the one the button already has with an
	-- untouched minimap: in from the map's default corner to its center, then
	-- back out along the ring to the upper left.
	local ringX = (position and position[4]) or 0
	local ringY = (position and position[5]) or 0
	local inset = MINIMAP_DEFAULT_INSET + MINIMAP_DEFAULT_SIZE/2
	local scale = ns.API.GetEffectiveScale()

	defaults.profile.savedPosition = {
		scale = scale,
		[1] = "BOTTOMRIGHT",
		[2] = (ringX - inset) * scale,
		[3] = (ringY + inset) * scale
	}

	return defaults
end

local ExitButton_OnEnter = function(self)
	if (GameTooltip:IsForbidden()) then return end

	GameTooltip_SetDefaultAnchor(GameTooltip, self)

	if (UnitOnTaxi("player")) then
		GameTooltip:AddLine(TAXI_CANCEL)
		GameTooltip:AddLine(TAXI_CANCEL_DESCRIPTION, unpack(Colors.green))
	elseif (IsMounted()) then
		GameTooltip:AddLine(BINDING_NAME_DISMOUNT)
	elseif (IsPossessBarVisible() and PetCanBeDismissed()) then
		GameTooltip:AddLine(PET_DISMISS)
		GameTooltip:AddLine(NEWBIE_TOOLTIP_UNIT_PET_DISMISS, unpack(Colors.green))
	else
		GameTooltip:AddLine(BINDING_NAME_VEHICLEEXIT)
	end
	GameTooltip:Show()
end

local ExitButton_OnLeave = function(self)
	if (GameTooltip:IsForbidden()) then return end
	GameTooltip:Hide()
end

local ExitButton_PostClick = function(self, button)
	if (UnitOnTaxi("player") and (not InCombatLockdown())) then
		TaxiRequestEarlyLanding()
	elseif (IsPossessBarVisible() and PetCanBeDismissed()) then
		PetDismiss()
	end
end

-- The minimap attached position: the button rides the map ring at its upper
-- left and matches the map's scale. This is where it has always been, and
-- where it stays unless the player asks for a position of their own.
VehicleExit.UpdateAttachedPosition = function(self)
	if (not self.frame) then return end

	local config = ns.GetConfig("VehicleExitButton")
	local point, relFrame, relPoint, x, y = unpack(config.VehicleExitButtonPosition)

	self.frame:SetScale(Minimap:GetScale())
	self.frame:ClearAllPoints()
	self.frame:SetPoint(point, relFrame, relPoint, x, y)
end

-- Sends the position pass to the minimap ring for as long as the player has
-- not asked for a position of their own. Returning true stops the prototype
-- from applying the saved position on top of what we just set.
VehicleExit.PreUpdatePositionAndScale = function(self)
	if (self.db.profile.useCustomPosition) then return end

	self:UpdateAttachedPosition()

	return true
end

-- The mover anchor is only worth showing while the button has a position of
-- its own. Dragging it in attached mode would move nothing.
VehicleExit.PostUpdateAnchor = function(self)
	if (not self.anchor) then return end

	if (self.db.profile.useCustomPosition) then
		self.anchor:Enable()
	else
		self.anchor:Disable()
	end
end

-- Records where the button is right now, in the shape the frame mover saves
-- positions in. Handing the player a button that teleports across the screen
-- the moment they detach it would be a poor way to start a drag.
VehicleExit.SnapshotPosition = function(self)
	local config = self.db.profile.savedPosition
	if (not config or not self.frame) then return end

	-- No rect to measure yet, so leave the default in place.
	if (not self.frame:GetCenter()) then return end

	local point, x, y = ns.API.GetPosition(self.frame)
	if (not point) then return end

	-- GetPosition answers in the frame's own units, saved positions are kept
	-- in UIParent's. The frame's scale is what converts between the two.
	local scale = self.frame:GetScale()

	config.scale = scale
	config[1] = point
	config[2] = x * scale
	config[3] = y * scale
end

-- Called by the options menu. Attaching and detaching both change whether the
-- minimap's auto-hide has any business touching this button, so the minimap
-- module is told either way.
VehicleExit.SetUseCustomPosition = function(self, enable)
	local db = self.db.profile

	enable = enable and true or false
	if (db.useCustomPosition == enable) then return end

	-- On the first detach only. After that the saved position is the player's,
	-- and toggling the option off and back on has to hand it back unchanged.
	if (enable and not db.customPositionInitialized) then
		self:SnapshotPosition()
		db.customPositionInitialized = true
	end

	db.useCustomPosition = enable

	self:UpdateSettings()
end

VehicleExit.UpdateSettings = function(self)
	self:UpdatePositionAndScale()
	self:UpdateAnchor()

	local minimap = ns:GetModule("Minimap", true)
	if (minimap and minimap.UpdateVehicleExitButton) then
		minimap:UpdateVehicleExitButton()
	end
end

-- Combat and the frame mover are handled by the movable module prototype,
-- which owns PLAYER_ENTERING_WORLD and the two regen events. These two are
-- ours alone, and both mean the same thing: the position needs recalculating.
VehicleExit.OnEvent = function(self, event, ...)
	if (event == "UI_SCALE_CHANGED" or event == "DISPLAY_SIZE_CHANGED") then
		self:UpdatePositionAndScale()
	end
end

VehicleExit.OnEnable = function(self)

	local config = ns.GetConfig("VehicleExitButton")

	local button = CreateFrame("CheckButton", ns.Prefix.."VehicleExitButton", UIParent, "SecureActionButtonTemplate")
	button:SetFrameStrata("MEDIUM")
	button:SetFrameLevel(100)
	button:SetPoint(unpack(config.VehicleExitButtonPosition))
	button:SetSize(unpack(config.VehicleExitButtonSize))
	button:SetScript("OnEnter", ExitButton_OnEnter)
	button:SetScript("OnLeave", ExitButton_OnLeave)
	button:SetScript("PostClick", ExitButton_PostClick)
	button:SetAttribute("type", "macro")

	-- self.Button is what the minimap module looks this button up as, self.frame
	-- is what the movable module prototype positions. Same button.
	self.Button = button
	self.frame = button

	button:SetAttribute("macrotext", "/leavevehicle [@vehicle,exists,canexitvehicle]\n/dismount [mounted]")
	button:RegisterForClicks("AnyUp", "AnyDown")
	RegisterStateDriver(button, "visibility", "[@vehicle,exists,canexitvehicle][possessbar][mounted]show;hide")

	local texture = button:CreateTexture(nil, "ARTWORK", nil, 1)
	texture:SetPoint(unpack(config.VehicleExitButtonTexturePosition))
	texture:SetSize(unpack(config.VehicleExitButtonTextureSize))
	texture:SetTexture(config.VehicleExitButtonTexture)

	button.Texture = texture

	self:RegisterEvent("DISPLAY_SIZE_CHANGED", "OnEvent")
	self:RegisterEvent("UI_SCALE_CHANGED", "OnEvent")

	self:SecureHook(Minimap, "SetScale", "UpdatePositionAndScale")

	self:CreateAnchor(L["Dismount Button"])

	ns.MovableModulePrototype.OnEnable(self)
end
