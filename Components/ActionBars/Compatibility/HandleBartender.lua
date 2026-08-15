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

if (not ns.API.IsAddOnEnabled("Bartender4")) then return end
if (ns.API.IsAddOnEnabled("ConsolePort_Bar")) then return end

local Bartender = ns:NewModule("Bartender", "LibMoreEvents-1.0")

-- Bartender owns the overlapping action-bar ecosystem when enabled. AzeriteUI's
-- independent encounter and minimap status modules intentionally remain active.
local AZERITE_ACTION_BAR_MODULES = {
	"BlizzardABDisabler",
	"ActionBars",
	"PetBar",
	"StanceBar",
	"MicroMenu",
	"ExtraActionButtons",
	"VehicleExit"
}

Bartender.YieldActionBarOwnership = function(self)
	for _, moduleName in ipairs(AZERITE_ACTION_BAR_MODULES) do
		local module = ns:GetModule(moduleName, true)
		if (module and module:IsEnabled()) then
			module:Disable()
		end
	end
end

Bartender.HandleBartender = function(self, event, addon)
	if (not _G.IsAddOnLoaded("Bartender4")) then
		return self:RegisterEvent("ADDON_LOADED", "HandleBartender")
	elseif (event == "ADDON_LOADED") then
		if (addon ~= "Bartender4") then return end
		self:UnregisterEvent("ADDON_LOADED", "HandleBartender")
	end

	ns.BartenderHandled = true

	ns:Fire("Bartender_Handled")
end

Bartender.OnInitialize = function(self)
	if (not ns.API.IsAddOnEnabled("Bartender4")) then return self:Disable() end
	if (ns.API.IsAddOnEnabled("ConsolePort_Bar")) then return self:Disable() end

	self:YieldActionBarOwnership()
	self:HandleBartender()
end
