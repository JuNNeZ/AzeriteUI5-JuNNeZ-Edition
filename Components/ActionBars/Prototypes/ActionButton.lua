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

local LAB = LibStub("LibActionButton-1.0-GE")

-- Lua API
local tonumber = tonumber
local tostring = tostring

-- GLOBALS: GetActionInfo, Mixin, PingableType_ActionButtonMixin

ns.ActionButtons = {}
ns.ActionButton = {}

-- Action button pings
------------------------------------------------------------
-- Retail 12.1 made action buttons ping receivers, so pinging a spell announces
-- it and its cooldown to the group.
--
-- LibActionButton builds every button from "ActionButtonTemplate,
-- SecureActionButtonTemplate" (LibActionButton-1.0-GE.lua:325), and on 12.1
-- ActionButtonTemplate inherits PingableActionButtonTemplate. So the buttons
-- already arrive with PingableType_ActionButtonMixin and a statically true
-- "ping-receiver" attribute - what they do not arrive with is a working
-- GetActionButtonInfo. Blizzard's fallback, BaseActionButtonInfoMixin, returns
-- nil, which makes GetIsPingable false and the client answer "can't ping this".
--
-- So the job here is not to opt the buttons in. It is to supply the one method
-- that translates LibActionButton's action model, and to keep the receiver
-- attribute honest for empty slots. Everything else stays Blizzard's, including
-- which action types are pingable.
--
-- Feature gated on the mixin itself. The API was reshaped in 12.1 - the older
-- one used an IsPingable field with GetContextualPingType/GetTargetPingGUID -
-- so presence of the mixin, not a client build number, is what decides.
local CanPingActionButtons = (PingableType_ActionButtonMixin and Mixin) and true or false

-- Translate a LibActionButton action into the table Blizzard's mixin reads.
-- Only id and actionType are consumed by it; isUsable/notEnoughMana are part of
-- Blizzard's own shape but nothing in the ping path looks at them, so they are
-- left out rather than sourced from an API that may not exist on every build.
local GetActionButtonInfo = function(self)
	local kind, action = self:GetAction()
	if (not kind) or (kind == "empty") or (action == nil) then
		return nil
	end

	-- A real action bar slot. Blizzard decides pingability from the action
	-- type here, which is what keeps macros and pet actions out.
	if (kind == "action") then
		local actionType, id, subType = GetActionInfo(action)
		if (not id) then return nil end
		return { id = id, actionType = actionType, subType = subType }
	end

	if (kind == "spell") then
		return { id = tonumber(action), actionType = "spell" }
	end

	if (kind == "item") then
		-- LibActionButton stores these as "item:12345".
		local itemID = tonumber(tostring(action):match("item:(%d+)")) or tonumber(action)
		if (not itemID) then return nil end
		return { id = itemID, actionType = "item" }
	end

	return nil
end

-- Empty slots clear the attribute again so pings pass through them to the
-- world, matching Blizzard. Without that an empty button is found as a ping
-- receiver, reports itself unpingable, and the ping fails outright.
--
-- Same logic as Blizzard's own UpdatePingAttributes, with the write guarded on
-- an actual change. This runs off every button update, and these are secure
-- buttons: repeating a SetAttribute that changes nothing is pure taint surface
-- for no benefit.
local UpdatePingAttributes = function(button)
	if (not CanPingActionButtons) or (not button) or (not button.HasAction) then
		return
	end

	local hasAction = button:HasAction() and true or false
	if (button.__AzeriteUI_PingReceiver == hasAction) then
		return
	end
	button.__AzeriteUI_PingReceiver = hasAction

	if (hasAction) then
		button:SetAttribute("ping-receiver", true)
	elseif (button.ClearAttribute) then
		button:ClearAttribute("ping-receiver")
	else
		button:SetAttribute("ping-receiver", nil)
	end
end

local EnablePings = function(button)
	if (not CanPingActionButtons) or (not button) then
		return
	end

	-- Deliberately not guarded on button.GetIsPingable. The template already
	-- provides it, so guarding on it skipped every button and left Blizzard's
	-- nil-returning GetActionButtonInfo in place - which is precisely what made
	-- the first attempt report "can't ping this" on every button. The Mixin is
	-- kept for the case where a future template stops carrying it, and is a
	-- no-op assignment of identical methods when it already does.
	Mixin(button, PingableType_ActionButtonMixin)
	button.GetActionButtonInfo = GetActionButtonInfo
	button.UpdatePingAttributes = UpdatePingAttributes

	-- Seed the cache from the attribute the template already set, so an empty
	-- button gets its first clear rather than being skipped as unchanged.
	button.__AzeriteUI_PingReceiver = nil

	UpdatePingAttributes(button)
end

if (CanPingActionButtons) then
	-- Fires whenever a button's contents are rebuilt, which covers page swaps,
	-- dragging an ability on or off, and state changes on the bar.
	LAB.RegisterCallback(ns.ActionButton, "OnButtonUpdate", function(_, button)
		if (ns.ActionButtons[button]) then
			UpdatePingAttributes(button)
		end
	end)
end

local GetMouseoverCastEnabled = function()
	if (not ns.IsRetail) then
		return false
	end
	if (C_CVar and C_CVar.GetCVarBool) then
		return C_CVar.GetCVarBool("enableMouseoverCast")
	end
	if (GetCVarBool) then
		return GetCVarBool("enableMouseoverCast")
	end
	return false
end

ns.ActionButton.UpdateMouseoverCast = function(button)
	if (not button) or (not button.SetAttribute) then
		return
	end
	button:SetAttribute("checkmouseovercast", GetMouseoverCastEnabled() or nil)
end

ns.ActionButton.Create = function(id, name, header, buttonConfig)

	local button = LAB:CreateButton(id, name, header, buttonConfig)

	-- WoW 12: Do NOT replace the secure OnEnter/OnLeave scripts with
	-- insecure wrappers. Calling secure tooltip code from addon context
	-- taints action values, crashing Blizzard MoneyFrame arithmetic.
	-- LAB's default handlers are sufficient.
	ns.ActionButton.UpdateMouseoverCast(button)

	ns.ActionButtons[button] = true

	EnablePings(button)

	return button
end

