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

ns.ActionButtons = {}
ns.ActionButton = {}

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

	return button
end

