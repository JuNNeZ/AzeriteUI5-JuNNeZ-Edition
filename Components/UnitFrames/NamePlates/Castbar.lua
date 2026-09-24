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
-- Nameplates, 6 of 10: castbar colours and the per-plate interrupt watcher. Which interrupt the
-- player has, and whether it is ready, comes from Components/UnitFrames/Interrupts.lua.
-- Loaded after Elements.lua; see Settings.lua for how these files share their locals.
local _, ns = ...

local NP = ns.NamePlatesPrivate
if (not NP) then return end

local API = ns.API
local unpack = unpack
local Colors = ns.Colors

local IsSecretValue = NP.IsSecretValue
local NamePlate_PostUpdateHoverElements = NP.NamePlate_PostUpdateHoverElements

local NamePlate_ResetCastbarVisuals = function(element)
	if (not element) then
		return
	end

	local db = ns.GetConfig("NamePlates")
	local baseTextColor = db and db.CastBarNameColor or nil
	local baseBarColor = db and db.CastBarColor or nil

	if (element.Text and type(baseTextColor) == "table") then
		local r, g, b = unpack(baseTextColor)
		element.Text:SetTextColor(r, g, b, 1)
	end

	if (type(baseBarColor) == "table") then
		local r, g, b, a = unpack(baseBarColor)
		element:SetStatusBarColor(r, g, b, a or 1)
		local texture = element.GetStatusBarTexture and element:GetStatusBarTexture()
		if (texture and texture.SetVertexColor) then
			texture:SetVertexColor(r, g, b, a or 1)
		end
	end

end

local ShouldColorNameplateSpellTextByState = function()
	return ns.UnitFrame and ns.UnitFrame.ShouldColorCastSpellTextByState and ns.UnitFrame.ShouldColorCastSpellTextByState() or false
end

local NamePlate_SetCastbarColor = function(element, color)
	if (not element or type(color) ~= "table") then
		return
	end

	local r, g, b, a = unpack(color)
	element:SetStatusBarColor(r, g, b, a or 1)
	local texture = element.GetStatusBarTexture and element:GetStatusBarTexture()
	if (texture and texture.SetVertexColor) then
		texture:SetVertexColor(r, g, b, a or 1)
	end
end

local NamePlate_CreateColorObject = function(color)
	if (type(CreateColor) ~= "function" or type(color) ~= "table") then
		return nil
	end

	return CreateColor(color[1] or 1, color[2] or 1, color[3] or 1, color[4] or 1)
end

local NamePlate_GetLiveNotInterruptible = function(element)
	local owner = element and element.__owner
	local unit = owner and owner.unit
	if (type(unit) ~= "string" or unit == "") then
		return nil
	end

	if (element and element.casting and UnitCastingInfo) then
		local _, castResult = API.SafeCallPacked("NamePlates.UnitCastingInfo", UnitCastingInfo, unit)
		castResult = castResult or {}
		if (castResult[1]) then
			return castResult[9]
		end
	end

	if (element and element.channeling and UnitChannelInfo) then
		local _, channelResult = API.SafeCallPacked("NamePlates.UnitChannelInfo", UnitChannelInfo, unit)
		channelResult = channelResult or {}
		if (channelResult[1]) then
			return channelResult[8]
		end
	end

	return nil
end

local NamePlate_ApplyLiveInterruptTextureColor = function(element, liveNotInterruptible, protectedColor, nextColor)
	local texture = element and element.GetStatusBarTexture and element:GetStatusBarTexture()
	if (not texture or type(texture.SetVertexColorFromBoolean) ~= "function") then
		return false
	end

	if (liveNotInterruptible == nil) then
		return false
	end
	if ((not IsSecretValue(liveNotInterruptible)) and type(liveNotInterruptible) ~= "boolean") then
		return false
	end

	local protectedColorObject = NamePlate_CreateColorObject(protectedColor)
	local nextColorObject = NamePlate_CreateColorObject(nextColor)
	if (not protectedColorObject or not nextColorObject) then
		return false
	end

	texture:SetVertexColorFromBoolean(liveNotInterruptible, protectedColorObject, nextColorObject)
	return true
end

local NamePlate_ClearInterruptState = function(element)
	if (not element) then
		return
	end
	element.__AzeriteUI_NotInterruptible = nil
	element.__AzeriteUI_ProbedNotInterruptible = nil
	element.__AzeriteUI_InterruptCastState = nil
	element.__AzeriteUI_LastInterruptColorUpdate = nil
	element.__AzeriteUI_EventNotInterruptible = nil
end

local Castbar_RefreshInterruptVisuals
local NamePlate_UpdateInterruptWatcher

local NamePlate_HandleInterruptWatcherEvent = function(self, event, unit)
	local watchedUnit = self and self.__AzeriteUI_WatchedUnit
	if (type(unit) ~= "string" or unit ~= watchedUnit) then
		return
	end

	local element = self.__castbar
	if (not element) then
		return
	end

	if (event == "UNIT_SPELLCAST_NOT_INTERRUPTIBLE") then
		element.__AzeriteUI_EventNotInterruptible = true
	elseif (event == "UNIT_SPELLCAST_INTERRUPTIBLE") then
		element.__AzeriteUI_EventNotInterruptible = false
	elseif (event == "UNIT_SPELLCAST_START" or event == "UNIT_SPELLCAST_CHANNEL_START") then
		element.__AzeriteUI_EventNotInterruptible = nil
	elseif (event == "UNIT_SPELLCAST_STOP" or event == "UNIT_SPELLCAST_CHANNEL_STOP" or event == "UNIT_SPELLCAST_INTERRUPTED" or event == "UNIT_SPELLCAST_FAILED") then
		element.__AzeriteUI_EventNotInterruptible = nil
	end

	ns.API.UpdateInterruptCastBarRefresh(element, Castbar_RefreshInterruptVisuals, event)
end

local NamePlate_ClearInterruptWatcher = function(element)
	local watcher = element and element.InterruptWatcher
	if (not watcher) then
		return
	end

	watcher:UnregisterAllEvents()
	watcher.__AzeriteUI_WatchedUnit = nil
end

NamePlate_UpdateInterruptWatcher = function(element, unit)
	if (not element or type(unit) ~= "string" or unit == "" or not unit:match("^nameplate%d+$")) then
		NamePlate_ClearInterruptWatcher(element)
		return
	end

	local watcher = element.InterruptWatcher
	if (not watcher) then
		watcher = CreateFrame("Frame")
		watcher.__castbar = element
		watcher:SetScript("OnEvent", NamePlate_HandleInterruptWatcherEvent)
		element.InterruptWatcher = watcher
	end

	if (watcher.__AzeriteUI_WatchedUnit == unit) then
		return
	end

	watcher:UnregisterAllEvents()
	watcher:RegisterUnitEvent("UNIT_SPELLCAST_START", unit)
	watcher:RegisterUnitEvent("UNIT_SPELLCAST_STOP", unit)
	watcher:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_START", unit)
	watcher:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_STOP", unit)
	watcher:RegisterUnitEvent("UNIT_SPELLCAST_INTERRUPTIBLE", unit)
	watcher:RegisterUnitEvent("UNIT_SPELLCAST_NOT_INTERRUPTIBLE", unit)
	watcher:RegisterUnitEvent("UNIT_SPELLCAST_INTERRUPTED", unit)
	watcher:RegisterUnitEvent("UNIT_SPELLCAST_FAILED", unit)
	watcher.__AzeriteUI_WatchedUnit = unit
end

local NamePlate_GetRawNotInterruptible = function(element)
	local owner = element and element.__owner
	local unit = owner and owner.unit
	if (type(unit) ~= "string" or unit == "") then
		return nil, false
	end

	local rawNotInterruptible
	local sawSecretRaw = false
	if (UnitCastingInfo) then
		local _, castResult = API.SafeCallPacked("NamePlates.UnitCastingInfo", UnitCastingInfo, unit)
		castResult = castResult or {}
		local okCast = castResult[1]
		local castNotInterruptible = castResult[9]
		if (okCast and type(castNotInterruptible) == "boolean") then
			if (IsSecretValue(castNotInterruptible)) then
				sawSecretRaw = true
			else
				rawNotInterruptible = castNotInterruptible
			end
		end
	end

	if (rawNotInterruptible == nil and UnitChannelInfo) then
		local _, channelResult = API.SafeCallPacked("NamePlates.UnitChannelInfo", UnitChannelInfo, unit)
		channelResult = channelResult or {}
		local okChannel = channelResult[1]
		local channelNotInterruptible = channelResult[8]
		if (okChannel and type(channelNotInterruptible) == "boolean") then
			if (IsSecretValue(channelNotInterruptible)) then
				sawSecretRaw = true
			else
				rawNotInterruptible = channelNotInterruptible
			end
		end
	end

	if (type(rawNotInterruptible) == "boolean") then
		return rawNotInterruptible, sawSecretRaw
	end

	local castbarFlag = element and element.notInterruptible
	if ((not sawSecretRaw) and type(castbarFlag) == "boolean" and (not IsSecretValue(castbarFlag))) then
		return castbarFlag, false
	end

	return nil, sawSecretRaw
end

local NamePlate_GetBlizzardProtectedFallback = function(element)
	local owner = element and element.__owner
	local unit = owner and owner.unit
	if (type(unit) ~= "string" or unit == "" or not unit:match("^nameplate%d+$")) then
		return nil
	end
	if (not C_NamePlate or not C_NamePlate.GetNamePlateForUnit) then
		return nil
	end

	local okPlate, plate = API.TryCall(C_NamePlate.GetNamePlateForUnit, unit, issecurefunc and issecurefunc())
	local unitFrame = okPlate and plate and (plate.UnitFrame or plate.unitFrame)
	local blizzardCastbar = unitFrame and (unitFrame.castBar or unitFrame.CastBar or unitFrame.castbar or unitFrame.Castbar or unitFrame.CastingBarFrame)
	local active = blizzardCastbar and (blizzardCastbar.casting or blizzardCastbar.channeling or blizzardCastbar.empowering)
	if (not blizzardCastbar or not active) then
		return nil
	end

	local blizzardLocked = blizzardCastbar.notInterruptible
	if (type(blizzardLocked) == "boolean" and (not IsSecretValue(blizzardLocked)) and blizzardLocked) then
		return true
	end

	return nil
end

Castbar_RefreshInterruptVisuals = function(element)
	if (not element) then
		return
	end

	local db = ns.GetConfig("NamePlates")
	local baseBarColor = db and db.CastBarColor or nil
	local baseTextColor = db and db.CastBarNameColor or nil

	NamePlate_ResetCastbarVisuals(element)

	local color, state
	local rawNotInterruptible, hasSecretRaw = NamePlate_GetRawNotInterruptible(element)
	local eventNotInterruptible = element.__AzeriteUI_EventNotInterruptible
	local blizzardProtected = NamePlate_GetBlizzardProtectedFallback(element)
	local liveNotInterruptible = NamePlate_GetLiveNotInterruptible(element)
	local dbState = nil
	if ((eventNotInterruptible == nil and rawNotInterruptible == nil and blizzardProtected ~= true) or hasSecretRaw) and ns.NameplateInterruptDB and ns.NameplateInterruptDB.GetFallbackStateForCastbar then
		dbState = ns.NameplateInterruptDB.GetFallbackStateForCastbar(element)
	end

	-- The player's interrupt, from the resolver the target castbar asks too (Interrupts.lua).
	local interruptSpellID, interruptReady = ns.API.GetPrimaryInterrupt()
	if (interruptSpellID and interruptReady == false) then
		color = Colors.red
		state = "unavailable"
	elseif (interruptSpellID and interruptReady == true) then
		color = { 1, .82, 0, 1 }
		state = "primary-ready"
	else
		color = baseBarColor
		state = "base"
	end

	if (dbState == "protected" or eventNotInterruptible == true or rawNotInterruptible == true or blizzardProtected == true) then
		state = "locked"
	elseif (dbState == "interruptible" or eventNotInterruptible == false or (rawNotInterruptible == false and (not hasSecretRaw))) then
		-- Keep the active red/yellow/base state chosen above.
	end

	if (type(color) == "table") then
		NamePlate_SetCastbarColor(element, color)
	end

	if (state == "locked") then
		NamePlate_SetCastbarColor(element, Colors.gray)
	elseif (type(color) == "table") then
		NamePlate_ApplyLiveInterruptTextureColor(element, liveNotInterruptible, Colors.gray, color)
	end

	if (element.Text) then
		local textColor = baseTextColor
		if (ShouldColorNameplateSpellTextByState()) then
			if (state == "locked") then
				textColor = Colors.gray
			elseif (state == "unavailable") then
				textColor = Colors.red
			elseif (state == "primary-ready") then
				textColor = { 1, .82, 0, 1 }
			end
		end
		if (type(textColor) == "table") then
			element.Text:SetTextColor(textColor[1], textColor[2], textColor[3], textColor[4] or 1)
		end
	end
end

local Castbar_PostCastVisual = function(element, unit)
	element.__AzeriteUI_InterruptCastState = nil
	element.__AzeriteUI_LastInterruptColorUpdate = nil
	NamePlate_UpdateInterruptWatcher(element, unit or (element.__owner and element.__owner.unit))
	ns.API.UpdateInterruptCastBarRefresh(element, Castbar_RefreshInterruptVisuals, "nameplate_postcast")
	NamePlate_PostUpdateHoverElements(element.__owner)
end

local Castbar_PostCastUpdate = function(element, unit)
	NamePlate_UpdateInterruptWatcher(element, unit or (element.__owner and element.__owner.unit))
	ns.API.UpdateInterruptCastBarRefresh(element, Castbar_RefreshInterruptVisuals, "nameplate_update")
	NamePlate_PostUpdateHoverElements(element.__owner)
end

local Castbar_PostUpdate = function(element, unit)
	NamePlate_PostUpdateHoverElements(element.__owner)
end

local Castbar_PostStop = function(element, unit)
	ns.API.ClearInterruptCastBarRefresh(element)
	NamePlate_ClearInterruptState(element)
	NamePlate_ResetCastbarVisuals(element)
	NamePlate_PostUpdateHoverElements(element.__owner)
end

local Castbar_PostFail = function(element, _)
	ns.API.ClearInterruptCastBarRefresh(element)
	NamePlate_ClearInterruptState(element)
	local r, g, b = Colors.red[1], Colors.red[2], Colors.red[3]
	if (element.Text) then
		element.Text:SetTextColor(r, g, b, 1)
	end
	element:SetStatusBarColor(r, g, b, 1)
	local texture = element.GetStatusBarTexture and element:GetStatusBarTexture()
	if (texture and texture.SetVertexColor) then
		texture:SetVertexColor(r, g, b, 1)
	end
	NamePlate_PostUpdateHoverElements(element.__owner)
end

NP.NamePlate_ResetCastbarVisuals = NamePlate_ResetCastbarVisuals
NP.NamePlate_ClearInterruptState = NamePlate_ClearInterruptState
NP.NamePlate_UpdateInterruptWatcher = NamePlate_UpdateInterruptWatcher
NP.NamePlate_ClearInterruptWatcher = NamePlate_ClearInterruptWatcher
NP.Castbar_PostCastVisual = Castbar_PostCastVisual
NP.Castbar_PostCastUpdate = Castbar_PostCastUpdate
NP.Castbar_PostUpdate = Castbar_PostUpdate
NP.Castbar_PostStop = Castbar_PostStop
NP.Castbar_PostFail = Castbar_PostFail
