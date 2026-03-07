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

----------------------------------------------------------------
-- WoW 12+ Blizzard Bug Guards
-- Runs at FILE SCOPE — not inside any module OnInitialize.
-- This avoids being blocked by early-returns elsewhere.
----------------------------------------------------------------

-- Only matters when the forbidden-table system exists.
if (not canaccesstable) then return end

----------------------------------------------------------------
-- CastingBarFrame StopFinishAnims / UpdateShownState guards
----------------------------------------------------------------
-- Problem:
--   oUF (and AzeriteUI) hides PlayerCastingBarFrame via addon
--   code, which taints the frame. When Edit Mode re-shows it,
--   Blizzard's StopFinishAnims iterates StagePips / StagePoints /
--   StageTiers without canaccesstable checks, producing:
--     "attempted to iterate a forbidden table"
--   at CastingBarFrame.lua:722.
--
-- Fix:
--   Replace StopFinishAnims (and its caller UpdateShownState) with
--   versions that pcall the originals to swallow forbidden-table
--   errors. Completely safe — worst case is a visual stage-pip
--   animation not stopping, which is cosmetic.
----------------------------------------------------------------

-- Wrap an original StopFinishAnims so forbidden-table iteration
-- is caught by pcall instead of propagating to BugSack.
local function MakeSafeStopFinishAnims(origFunc)
	return function(self, ...)
		if (self and type(self) == "table" and not canaccesstable(self)) then
			return
		end
		local ok = pcall(origFunc, self, ...)
		-- Swallow errors silently; they're all "forbidden table" noise.
	end
end

-- Same pattern for UpdateShownState, which can also touch
-- forbidden fields when toggling the frame visible.
local function MakeSafeUpdateShownState(origFunc)
	return function(self, ...)
		if (self and type(self) == "table" and not canaccesstable(self)) then
			return
		end
		local ok = pcall(origFunc, self, ...)
	end
end

-- Guard GetTypeInfo, which can index forbidden Blizzard tables during
-- spec/talent transitions after castbar taint.
local SAFE_CASTBAR_TYPE_INFO = {
	showCastbar = true,
	showTradeSkills = true,
	showShield = false,
	showIcon = true
}

local function MakeSafeGetTypeInfo(origFunc)
	return function(self, ...)
		if (self and type(self) == "table" and not canaccesstable(self)) then
			return SAFE_CASTBAR_TYPE_INFO
		end
		local ok, info = pcall(origFunc, self, ...)
		if (ok and type(info) == "table" and (not canaccesstable or canaccesstable(info))) then
			if (self and type(self) == "table") then
				self.__AzUI_W12_LastTypeInfo = info
			end
			return info
		end
		if (self and type(self) == "table") then
			local cached = rawget(self, "__AzUI_W12_LastTypeInfo")
			if (type(cached) == "table" and (not canaccesstable or canaccesstable(cached))) then
				return cached
			end
		end
		return SAFE_CASTBAR_TYPE_INFO
	end
end

-- Guard a method on a mixin table (idempotent via flag name).
local function GuardMixin(mixin, method, wrapper, flag)
	if (not mixin or type(mixin[method]) ~= "function" or mixin[flag]) then
		return
	end
	mixin[flag] = true
	mixin[method] = wrapper(mixin[method])
end

-- Guard specific frame instances (they may have their OWN copies
-- of these methods set at creation time, separate from the mixin).
local function GuardFrame(frame)
	if (not frame or type(frame) ~= "table") then return end
	if (type(frame.StopFinishAnims) == "function"
		and not frame.__AzUI_W12_SFA) then
		frame.__AzUI_W12_SFA = true
		frame.StopFinishAnims = MakeSafeStopFinishAnims(frame.StopFinishAnims)
	end
	if (type(frame.UpdateShownState) == "function"
		and not frame.__AzUI_W12_USS) then
		frame.__AzUI_W12_USS = true
		frame.UpdateShownState = MakeSafeUpdateShownState(frame.UpdateShownState)
	end
	if (type(frame.GetTypeInfo) == "function"
		and not frame.__AzUI_W12_GTI) then
		frame.__AzUI_W12_GTI = true
		frame.GetTypeInfo = MakeSafeGetTypeInfo(frame.GetTypeInfo)
	end
end

-- Master apply (idempotent — safe to call many times).
local function ApplyGuards()
	-- Mixin prototypes (future frames inherit these)
	GuardMixin(_G.CastingBarMixin, "StopFinishAnims",
		MakeSafeStopFinishAnims, "__AzUI_W12_SFA_CBM")
	GuardMixin(_G.CastingBarFrameMixin, "StopFinishAnims",
		MakeSafeStopFinishAnims, "__AzUI_W12_SFA_CBFM")
	GuardMixin(_G.CastingBarMixin, "UpdateShownState",
		MakeSafeUpdateShownState, "__AzUI_W12_USS_CBM")
	GuardMixin(_G.CastingBarFrameMixin, "UpdateShownState",
		MakeSafeUpdateShownState, "__AzUI_W12_USS_CBFM")
	GuardMixin(_G.CastingBarMixin, "GetTypeInfo",
		MakeSafeGetTypeInfo, "__AzUI_W12_GTI_CBM")
	GuardMixin(_G.CastingBarFrameMixin, "GetTypeInfo",
		MakeSafeGetTypeInfo, "__AzUI_W12_GTI_CBFM")

	-- Living frame instances (already created before our patch).
	-- Mixin() copies methods at creation time, so patching the
	-- prototype alone won't fix frames that already exist.
	GuardFrame(_G.PlayerCastingBarFrame)
	GuardFrame(_G.OverlayPlayerCastingBarFrame)
	GuardFrame(_G.PetCastingBarFrame)

	-- Arena castbar instances — created by Blizzard_ArenaUI.
	-- CompactArenaFrame has memberUnitFrames, each with a castBar.
	if (_G.CompactArenaFrame and type(_G.CompactArenaFrame.memberUnitFrames) == "table") then
		for _, unitFrame in pairs(_G.CompactArenaFrame.memberUnitFrames) do
			if (unitFrame) then
				-- The castbar can live under various keys
				local castBar = unitFrame.castBar or unitFrame.CastBar
					or unitFrame.castbar or unitFrame.CastingBarFrame
				if (castBar) then
					GuardFrame(castBar)
				end
				-- Guard the unit frame itself in case it holds the methods
				GuardFrame(unitFrame)
			end
		end
	end

	-- Also try direct ArenaEnemyMatchFrame* castbars if they exist
	for i = 1, 5 do
		local name = "ArenaEnemyMatchFrame" .. i
		local frame = _G[name]
		if (frame) then
			local castBar = frame.castBar or frame.CastBar
				or frame.castbar or frame.CastingBarFrame
			if (castBar) then
				GuardFrame(castBar)
			end
		end
		-- Also try CompactArenaFrameMember* pattern
		local name2 = "CompactArenaFrameMember" .. i
		local frame2 = _G[name2]
		if (frame2) then
			local castBar2 = frame2.castBar or frame2.CastBar
				or frame2.castbar or frame2.CastingBarFrame
			if (castBar2) then
				GuardFrame(castBar2)
			end
			GuardFrame(frame2)
		end
	end
end

----------------------------------------------------------------
-- Apply immediately (works if Blizzard_UIPanels_Game is loaded)
----------------------------------------------------------------
ApplyGuards()

----------------------------------------------------------------
-- Deferred: catch demand-loaded Blizzard addons
----------------------------------------------------------------
local guardFrame = CreateFrame("Frame")
guardFrame:RegisterEvent("ADDON_LOADED")
guardFrame:RegisterEvent("PLAYER_LOGIN")
guardFrame:SetScript("OnEvent", function(self, event, addonName)
	if (event == "ADDON_LOADED") then
		if (addonName == "Blizzard_UIPanels_Game"
			or addonName == "Blizzard_EditMode"
			or addonName == "Blizzard_ArenaUI") then
			ApplyGuards()
			-- One-frame delay lets mixin copies propagate.
			if (C_Timer) then
				C_Timer.After(0, ApplyGuards)
			end
		end
	elseif (event == "PLAYER_LOGIN") then
		ApplyGuards()
		self:UnregisterEvent("PLAYER_LOGIN")
	end
end)

-- Belt-and-suspenders timers
if (C_Timer) then
	C_Timer.After(0, ApplyGuards)
	C_Timer.After(1, ApplyGuards)
	C_Timer.After(3, ApplyGuards)
end
