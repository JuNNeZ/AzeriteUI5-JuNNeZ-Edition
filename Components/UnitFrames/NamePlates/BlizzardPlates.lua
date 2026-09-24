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
-- Nameplates, 8 of 10: fading Blizzard's own plate under ours.
-- Loaded after Layout.lua; see Settings.lua for how these files share their locals.
local _, ns = ...

local NP = ns.NamePlatesPrivate
if (not NP) then return end

local API = ns.API

local NamePlatesMod = NP.NamePlatesMod

NamePlatesMod.HookNamePlates = function(self)
	-- WoW 12 and Forever both run with secret values, where the only safe thing to do to a Blizzard
	-- plate is fade it. The invasive branch that unregistered, reparented and hooked Blizzard's
	-- plates for pre-secret clients could not run on either and went in the 2026-09 overhaul.
	local hookedBlizzardUFs = self.hookedBlizzardNamePlateUFs
	if (not hookedBlizzardUFs) then
		hookedBlizzardUFs = {}
		self.hookedBlizzardNamePlateUFs = hookedBlizzardUFs
	end

	local issecurefunc = issecure or function() return false end

	-- Child frames on Blizzard nameplates that may use SetIgnoreParentAlpha
	-- and therefore remain visible even when the UnitFrame is alpha 0.
	local blizzPlateHideKeys = {
		"RaidTargetFrame", "ClassificationFrame",
		"PlayerLevelDiffFrame",
	}

	local function HideBlizzardNamePlateVisual(unit)
		if (not C_NamePlate or not C_NamePlate.GetNamePlateForUnit or not unit) then
			return
		end

		local plate = C_NamePlate.GetNamePlateForUnit(unit, issecurefunc())
		if (not plate or not plate.UnitFrame or plate.UnitFrame:IsForbidden()) then
			return
		end

		local UF = plate.UnitFrame
		local health = UF.healthBar or UF.healthbar or UF.HealthBar
			or (UF.HealthBarsContainer and UF.HealthBarsContainer.healthBar)
		if (health and health.SetAlpha) then
			API.SafeCall("NamePlates.blizzPlate.health.SetAlpha", health.SetAlpha, health, 0)
		end

		if (UF.SetAlpha) then
			API.SafeCall("NamePlates.blizzPlate.UF.SetAlpha", UF.SetAlpha, UF, 0)
		end

		-- Explicitly hide child frames that may have SetIgnoreParentAlpha(true),
		-- which would make them visible even when the UnitFrame is alpha 0.
		for _, key in ipairs(blizzPlateHideKeys) do
			local child = UF[key]
			if (child and child.SetAlpha) then
				API.SafeCall("NamePlates.blizzPlate.child.SetAlpha", child.SetAlpha, child, 0)
				if (child.Hide) then
					API.SafeCall("NamePlates.blizzPlate.child.Hide", child.Hide, child)
				end
			end
		end

		if (not hookedBlizzardUFs[UF]) then
			hookedBlizzardUFs[UF] = true
			local locked = false

			if (UF.HookScript) then
				UF:HookScript("OnShow", function(frame)
					if (locked or frame:IsForbidden()) then
						return
					end
					locked = true
					frame:SetAlpha(0)
					-- Re-hide child frames that ignore parent alpha
					for _, key in ipairs(blizzPlateHideKeys) do
						local child = frame[key]
						if (child and child.Hide) then
							API.SafeCall("NamePlates.OnShow.child.Hide", child.Hide, child)
						end
					end
					locked = false
				end)
			end

			hooksecurefunc(UF, "SetAlpha", function(frame, alpha)
				if (locked or frame:IsForbidden() or alpha == 0) then
					return
				end
				locked = true
				frame:SetAlpha(0)
				locked = false
			end)
		end
	end

	self.HideBlizzardNamePlateVisual = HideBlizzardNamePlateVisual
end
