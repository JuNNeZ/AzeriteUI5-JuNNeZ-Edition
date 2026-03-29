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

-- GLOBALS: LoadAddOn, ChannelFrame

local FixBlizzardBugs = ns:NewModule("FixBlizzardBugs")

-- Workaround for https://worldofwarcraft.blizzard.com/en-gb/news/24030413/hotfixes-november-16-2023
if (ns.WoW10 and ns.ClientBuild >= 52188) then

	local InCombatLockdown = _G.InCombatLockdown

	if (false and issecurevariable("IsItemInRange")) then
		local IsItemInRange = _G.IsItemInRange
		_G.IsItemInRange = function(...)
			return InCombatLockdown() and true or IsItemInRange(...)
		end
	end

	if (false and issecurevariable("UnitInRange")) then
		local UnitInRange = _G.UnitInRange
		_G.UnitInRange = function(...)
			return InCombatLockdown() and true or UnitInRange(...)
		end
	end

end

-- WoW 12 note:
-- The old emergency full-disable research block that used to live here was removed.
-- Current live WoW 12 behavior lives in Core/FixBlizzardBugsWow12.lua, while this file
-- stays passive on WoW 12 via the early return in OnInitialize().


local function ApplyWoW12TooltipMoneyGuards()
	if (_G.SetTooltipMoney and not _G.__AzeriteUI_WoW12_SetTooltipMoneySafeWrapped) then
		_G.__AzeriteUI_WoW12_SetTooltipMoneySafeWrapped = true
		local original = _G.SetTooltipMoney
		_G.SetTooltipMoney = function(frame, money, ...)
			if (issecretvalue and issecretvalue(money)) then
				return
			end
			local ok = pcall(original, frame, money, ...)
			if (ok) then
				return
			end
			local moneyFrame = frame and frame.TooltipMoneyFrame
			if (moneyFrame and moneyFrame.Hide) then
				moneyFrame:Hide()
			end
		end
	end

	if (_G.MoneyFrame_Update and not _G.__AzeriteUI_WoW12_MoneyFrameUpdateSafeWrapped) then
		_G.__AzeriteUI_WoW12_MoneyFrameUpdateSafeWrapped = true
		local original = _G.MoneyFrame_Update
		_G.MoneyFrame_Update = function(frame, money, ...)
			if (issecretvalue and (issecretvalue(money) or issecretvalue(frame))) then
				if (frame and frame.Hide) then
					frame:Hide()
				end
				return
			end
			local ok = pcall(original, frame, money, ...)
			if (ok) then
				return
			end
			if (frame and frame.Hide) then
				frame:Hide()
			end
		end
	end
end

local function IsPassiveWoW12FixEnvironment()
	return (issecretvalue or canaccesstable or (ns.ClientVersion and ns.ClientVersion >= 120000)) and true or false
end

local function ApplyPlaterNamePlateAbsorbCleanup()
	if (not (ns and ns.API and ns.API.IsAddOnEnabled and ns.API.IsAddOnEnabled("Plater"))) then
		return
	end
	if (_G.__AzeriteUI_PlaterAbsorbCleanupInitialized) then
		return
	end
	_G.__AzeriteUI_PlaterAbsorbCleanupInitialized = true

	local function HideObject(object)
		if (not object) then
			return
		end
		if (object.SetAlpha) then
			pcall(object.SetAlpha, object, 0)
		end
		if (object.Hide) then
			pcall(object.Hide, object)
		end
		if (object.UnregisterAllEvents) then
			pcall(object.UnregisterAllEvents, object)
		end
	end

	local function LockHiddenOnShow(object)
		if (not object or object.__AzeriteUI_PlaterAbsorbHideHooked or not object.HookScript) then
			return
		end
		object.__AzeriteUI_PlaterAbsorbHideHooked = true
		object:HookScript("OnShow", function(self)
			HideObject(self)
		end)
	end

	local function HideNamedChildren(frame)
		if (not frame) then
			return
		end
		for _, key in ipairs({
			"AbsorbBar",
			"absorbBar",
			"TotalAbsorbBar",
			"totalAbsorbBar",
			"HealAbsorbBar",
			"healAbsorbBar",
			"ShieldBar",
			"shieldBar"
		}) do
			local child = frame[key]
			if (child) then
				HideObject(child)
				LockHiddenOnShow(child)
				HideObject(child.barTexture)
				HideObject(child.BarTexture)
				HideObject(child.border)
				HideObject(child.Border)
			end
		end
	end

	local function HideAbsorbChildrenByName(frame)
		if (not frame or not frame.GetNumChildren) then
			return
		end
		for i = 1, frame:GetNumChildren() do
			local child = select(i, frame:GetChildren())
			local childName = child and child.GetName and child:GetName()
			if (type(childName) == "string"
				and (string.find(childName, "Absorb", 1, true)
					or string.find(childName, "Shield", 1, true))) then
				HideObject(child)
				LockHiddenOnShow(child)
				HideObject(child.barTexture)
				HideObject(child.BarTexture)
				HideObject(child.border)
				HideObject(child.Border)
			end
		end
	end

	local function HidePlaterAbsorbVisualsForPlate(plate)
		if (not plate or not C_NamePlate or not C_NamePlate.GetNamePlateForUnit) then
			return
		end

		local unitFrame = plate.UnitFrame or plate.unitFrame
		if (not unitFrame) then
			return
		end

		local plateName = plate.GetName and plate:GetName() or ""
		local frameName = unitFrame.GetName and unitFrame:GetName() or ""
		if ((type(plateName) ~= "string" or not string.find(plateName, "Plater", 1, true))
			and (type(frameName) ~= "string" or not string.find(frameName, "Plater", 1, true))) then
			return
		end

		HideNamedChildren(unitFrame)
		HideAbsorbChildrenByName(unitFrame)

		local healthBar = unitFrame.healthBar or unitFrame.HealthBar or unitFrame.healthbar
		if (healthBar) then
			HideNamedChildren(healthBar)
			HideAbsorbChildrenByName(healthBar)
		end
	end

	local cleanupFrame = CreateFrame("Frame")
	cleanupFrame:RegisterEvent("NAME_PLATE_UNIT_ADDED")
	cleanupFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
	cleanupFrame:RegisterEvent("ADDON_LOADED")
	cleanupFrame:SetScript("OnEvent", function(_, event, arg1)
		if (event == "ADDON_LOADED" and arg1 ~= "Plater") then
			return
		end
		if (event == "NAME_PLATE_UNIT_ADDED") then
			local unit = arg1
			if (type(unit) ~= "string") then
				return
			end
			local ok, plate = pcall(C_NamePlate.GetNamePlateForUnit, unit)
			if (ok and plate) then
				HidePlaterAbsorbVisualsForPlate(plate)
				if (C_Timer) then
					C_Timer.After(0, function() HidePlaterAbsorbVisualsForPlate(plate) end)
					C_Timer.After(.1, function() HidePlaterAbsorbVisualsForPlate(plate) end)
				end
			end
			return
		end
		if (C_NamePlate and C_NamePlate.GetNamePlates) then
			for _, plate in pairs(C_NamePlate.GetNamePlates()) do
				HidePlaterAbsorbVisualsForPlate(plate)
			end
		end
	end)
end


FixBlizzardBugs.OnInitialize = function(self)

	-- Don't call this prior to our own addon loading,
	-- or it'll completely mess up the loading order.
	local LoadAddOnFunc = (C_AddOns and C_AddOns.LoadAddOn) or LoadAddOn
	if (LoadAddOnFunc) then
		pcall(LoadAddOnFunc, "Blizzard_Channels")
	end

	-- Kill off the non-stop voice chat error 17 on retail.
	-- This only occurs in linux, but we can't check for that.
	if (ChannelFrame and ChannelFrame.UnregisterEvent) then
		ChannelFrame:UnregisterEvent("VOICE_CHAT_ERROR")
	end

	-- WoW 12+: keep this module passive to avoid tainting Blizzard secure flows.
	-- Follow the UnhaltedUnitFrames approach: avoid Blizzard function rewrites.
	-- Note: ns.ClientBuild is the build number (~58135), NOT the TOC version.
	-- ns.ClientVersion is the interface/TOC number (120000+ for WoW 12).
	if (IsPassiveWoW12FixEnvironment()) then
		ApplyPlaterNamePlateAbsorbCleanup()
		-- IMPORTANT: keep WoW12 passive here.
		-- Replacing SetTooltipMoney/MoneyFrame_Update taints Blizzard money widgets,
		-- which can propagate into protected confirmation flows such as item upgrades.
		-- If a tooltip-money crash needs another pass later, solve it with a local hook
		-- on the specific Blizzard widget instead of rewriting the shared globals.
		-- IMPORTANT: Do NOT replace BackdropMixin.SetupTextureCoordinates here.
		-- Replacing mixin methods with addon functions taints every frame that
		-- uses BackdropMixin, which spreads "tainted by AzeriteUI" to Edit Mode
		-- systems (EncounterWarnings, CompactUnitFrame, SecureUtil, etc.).
		-- The tooltip backdrop error is cosmetic; the taint cascade is not.
		-- CastingBarFrame StopFinishAnims guard is handled by FixBlizzardBugsWow12.lua.
		-- Everything below this return is the legacy pre-WoW12 path and does not
		-- execute once the secret-value / forbidden-table environment is present.
		return
	end

	-- Legacy pre-WoW12 path intentionally commented out.
	-- The live WoW 12 path returns above and uses:
	-- * `ApplyPlaterNamePlateAbsorbCleanup()`
	-- * `Core/FixBlizzardBugsWow12.lua`
	--
	-- If pre-WoW12 support needs to be restored later, recover it from git history
	-- instead of mixing inactive legacy guards back into the live WoW 12 audit path.

end
