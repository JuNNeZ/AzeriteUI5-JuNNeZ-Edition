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
local oUF = ns.oUF

local CastBarMod = ns:NewModule("PlayerCastBarFrame", ns.UnitFrameModule, "LibMoreEvents-1.0")

-- GLOBALS: GetNetStats, OverlayPlayerCastingBarFrame, PlayerCastingBarFrame, PetCastingBarFrame

-- Lua API
local next = next
local select = select
local type = type
local unpack = unpack

-- Addon API
local Colors = ns.Colors
local GetFont = ns.API.GetFont
local IsAddOnEnabled = ns.API.IsAddOnEnabled

local defaults = { profile = ns:Merge({}, ns.MovableModulePrototype.defaults) }

-- Stop all Blizzard castbar animation groups to prevent interrupt/finish
-- effects from playing invisibly (or flashing before alpha hooks fire).
local function StopBlizzardCastbarAnims(frame)
	if (not frame or frame:IsForbidden()) then
		return
	end
	for _, key in next, {
		"InterruptShakeAnim", "InterruptGlowAnim", "InterruptSparkAnim",
		"HoldFadeOutAnim", "FadeOutAnim", "FlashAnim", "FlashLoopingAnim",
		"StandardFinish", "StandardGlow"
	} do
		local anim = frame[key]
		if (anim and type(anim.Stop) == "function") then
			pcall(anim.Stop, anim)
		end
	end
	-- Hide glow/flash child textures
	for _, key in next, { "InterruptGlow", "Flash", "Shine" } do
		local tex = frame[key]
		if (tex and type(tex.SetAlpha) == "function") then
			pcall(tex.SetAlpha, tex, 0)
		end
		if (tex and type(tex.Hide) == "function") then
			pcall(tex.Hide, tex)
		end
	end
end

local function ApplySuppressedBlizzardCastbarAlpha(frame)
	if (frame and not frame:IsForbidden() and frame.__AzeriteUI_Suppressed) then
		frame:SetAlpha(0)
		StopBlizzardCastbarAnims(frame)
	end
end

local function SuppressBlizzardCastbar(frame)
	if (not frame or frame:IsForbidden()) then
		return
	end
	frame.__AzeriteUI_Suppressed = true
	ApplySuppressedBlizzardCastbarAlpha(frame)
	if (not frame.__AzeriteUI_SuppressHooksAttached) then
		frame.__AzeriteUI_SuppressHooksAttached = true
		if (frame.HookScript) then
			frame:HookScript("OnShow", ApplySuppressedBlizzardCastbarAlpha)
		end
		if (type(frame.Show) == "function") then
			hooksecurefunc(frame, "Show", ApplySuppressedBlizzardCastbarAlpha)
		end
		if (type(frame.SetShown) == "function") then
			hooksecurefunc(frame, "SetShown", function(self, shown)
				if (shown) then
					ApplySuppressedBlizzardCastbarAlpha(self)
				end
			end)
		end
		-- Prevent Blizzard code or animations from overriding our alpha.
		local suppressingAlpha = false
		hooksecurefunc(frame, "SetAlpha", function(self, alpha)
			if (suppressingAlpha) then return end
			if (self.__AzeriteUI_Suppressed and alpha > 0) then
				suppressingAlpha = true
				self:SetAlpha(0)
				suppressingAlpha = false
			end
		end)
		for _, methodName in next, {
			"OnEvent",
			"FinishSpell",
			"HandleInterruptOrSpellFailed",
			"PlayFinishAnim",
			"PlayInterruptAnims"
		} do
			if (type(frame[methodName]) == "function") then
				hooksecurefunc(frame, methodName, ApplySuppressedBlizzardCastbarAlpha)
			end
		end
	end
end

local function RestoreBlizzardCastbar(frame, unit)
	if (not frame or frame:IsForbidden()) then
		return
	end
	frame.__AzeriteUI_Suppressed = nil
	pcall(frame.SetAlpha, frame, 1)
end

local function ShouldUseCustomCastbar(self)
	return self and self.db and self.db.profile and self.db.profile.enabled and true or false
end

local function ApplyBlizzardCastbarState(self, suppress)
	if (not ns.IsRetail) then
		return
	end
	if (OverlayPlayerCastingBarFrame and not OverlayPlayerCastingBarFrame:IsForbidden()) then
		if (suppress) then
			SuppressBlizzardCastbar(OverlayPlayerCastingBarFrame)
		else
			RestoreBlizzardCastbar(OverlayPlayerCastingBarFrame, "player")
		end
	end
	if (PlayerCastingBarFrame and not PlayerCastingBarFrame:IsForbidden()) then
		if (suppress) then
			SuppressBlizzardCastbar(PlayerCastingBarFrame)
		else
			RestoreBlizzardCastbar(PlayerCastingBarFrame, "player")
		end
	end
	if (PetCastingBarFrame and not PetCastingBarFrame:IsForbidden()) then
		if (suppress) then
			SuppressBlizzardCastbar(PetCastingBarFrame)
		else
			RestoreBlizzardCastbar(PetCastingBarFrame, "pet")
		end
	end
end

-- Generate module defaults on the fly
-- to recalculate default values relying on
-- changing factors like user interface scale.
CastBarMod.GenerateDefaults = function(self)
	defaults.profile.savedPosition = {
		scale = ns.API.GetEffectiveScale(),
		[1] = "BOTTOM",
		[2] = 0,
		[3] = (290 - 16/2) * ns.API.GetEffectiveScale()
	}
	return defaults
end

-- Element Callbacks
--------------------------------------------
local Cast_GetRemainingDuration = function(element, duration)
	if (type(duration) == "number") then
		if (element.casting and type(element.max) == "number") then
			return element.max - duration
		end
		return duration
	end
	if (type(duration) == "table" and duration.GetRemainingDuration) then
		local ok, remaining = pcall(duration.GetRemainingDuration, duration)
		if (ok and type(remaining) == "number") then
			return remaining
		end
	end
	return 0
end

local Cast_GetMaxDuration = function(element)
	if (type(element.max) == "number" and element.max > 0) then
		return element.max
	end
	if (element.GetTimerDuration) then
		local ok, durationObject = pcall(element.GetTimerDuration, element)
		if (ok and type(durationObject) == "table") then
			if (durationObject.GetTotalDuration) then
				local totalOk, total = pcall(durationObject.GetTotalDuration, durationObject)
				if (totalOk and type(total) == "number" and total > 0) then
					return total
				end
			end
			if (durationObject.GetRemainingDuration) then
				local remainingOk, remaining = pcall(durationObject.GetRemainingDuration, durationObject)
				if (remainingOk and type(remaining) == "number" and remaining > 0) then
					return remaining
				end
			end
		end
	end
	return nil
end

local Cast_CustomDelayText = function(element, duration)
	local remaining = Cast_GetRemainingDuration(element, duration)
	element.Time:SetFormattedText("%.1f", remaining)
	element.Delay:SetFormattedText("|cffff0000%s%.2f|r", element.casting and "+" or "-", element.delay)
end

local Cast_CustomTimeText = function(element, duration)
	local remaining = Cast_GetRemainingDuration(element, duration)
	element.Time:SetFormattedText("%.1f", remaining)
	element.Delay:SetText()
end

-- TODO: Interrupt/fail animation callbacks.
-- Commented out until we have a custom glow asset that fits
-- the AzeriteUI art style. The Blizzard atlas doesn't look
-- right at our castbar's scale/shape.
--[[
local Cast_PlayInterruptAnims = function(element)
	local glow = element.InterruptGlow
	if (glow) then
		glow:SetAlpha(1)
		glow:Show()
		local glowAnim = element.InterruptGlowAnim
		if (glowAnim) then
			glowAnim:Stop()
			glowAnim:Play()
		end
	end
	local shakeAnim = element.InterruptShakeAnim
	if (shakeAnim and tonumber(GetCVar("ShakeStrengthUI") or "0") > 0) then
		shakeAnim:Stop()
		shakeAnim:Play()
	end
end

local Cast_StopInterruptAnims = function(element)
	if (element.InterruptGlowAnim) then element.InterruptGlowAnim:Stop() end
	if (element.InterruptShakeAnim) then element.InterruptShakeAnim:Stop() end
	if (element.InterruptGlow) then
		element.InterruptGlow:SetAlpha(0)
		element.InterruptGlow:Hide()
	end
end

local Cast_PostCastInterrupted = function(element, unit, interruptedBy)
	element:SetStatusBarColor(unpack(Colors.red))
	element.Backdrop:Show()
	Cast_PlayInterruptAnims(element)
end

local Cast_PostCastFail = function(element, unit)
	element:SetStatusBarColor(unpack(Colors.red))
	element.Backdrop:Show()
	local glow = element.InterruptGlow
	if (glow) then
		glow:SetAlpha(1)
		glow:Show()
		local glowAnim = element.InterruptGlowAnim
		if (glowAnim) then
			glowAnim:Stop()
			glowAnim:Play()
		end
	end
end

local Cast_PostCastStart = function(element, unit)
	Cast_StopInterruptAnims(element)
	if (element.notInterruptible) then
		element.Backdrop:Hide()
		element:SetStatusBarColor(unpack(Colors.red))
	else
		element.Backdrop:Show()
		element:SetStatusBarColor(unpack(Colors.cast))
	end
	local durationMax = Cast_GetMaxDuration(element)
	if (not durationMax or durationMax <= 0) then
		element.SafeZone:Hide()
		return
	end
	local ratio = (select(4, GetNetStats()) / 1000) / durationMax
	if (ratio > 1) then ratio = 1 end
	if (ratio > .05) then
		local width, height = element:GetSize()
		element.SafeZone:SetSize(width * ratio, height)
		element.SafeZone:ClearAllPoints()
		if (element.channeling) then
			element.SafeZone:SetPoint("LEFT")
			element.SafeZone:SetTexCoord(0, ratio, 0, 1)
		else
			element.SafeZone:SetPoint("RIGHT")
			element.SafeZone:SetTexCoord(1-ratio, 1, 0, 1)
		end
		element.SafeZone:Show()
	else
		element.SafeZone:Hide()
	end
end
--]]

-- Update cast bar color and backdrop to indicate protected casts.
-- *Note that the shield icon works as an alternate backdrop here,
--  which is why we're hiding the regular backdrop on protected casts.
local Cast_Update = function(element, unit)
	if (element.notInterruptible) then
		element.Backdrop:Hide()
		element:SetStatusBarColor(unpack(Colors.red))
	else
		element.Backdrop:Show()
		element:SetStatusBarColor(unpack(Colors.cast))
	end

	-- Don't show mega tiny spell queue zones, it just looks cluttered.
	-- Also, fix the tex coords. OuF does it all wrong.
	local durationMax = Cast_GetMaxDuration(element)
	if (not durationMax or durationMax <= 0) then
		element.SafeZone:Hide()
		return
	end
	local ratio = (select(4, GetNetStats()) / 1000) / durationMax
	if (ratio > 1) then ratio = 1 end
	if (ratio > .05) then

		local width, height = element:GetSize()
		element.SafeZone:SetSize(width * ratio, height)
		element.SafeZone:ClearAllPoints()

		if (element.channeling) then
			element.SafeZone:SetPoint("LEFT")
			element.SafeZone:SetTexCoord(0, ratio, 0, 1)
		else
			element.SafeZone:SetPoint("RIGHT")
			element.SafeZone:SetTexCoord(1-ratio, 1, 0, 1)
		end

		element.SafeZone:Show()
	else
		element.SafeZone:Hide()
	end

end

-- Frame Script Handlers
--------------------------------------------
local style = function(self, unit)

	local db = ns.GetConfig("PlayerCastBar")

	self:SetSize(112 + 16, 11 + 16)

	-- Cast Bar
	--------------------------------------------
	local cast = self:CreateBar()
	cast:SetFrameStrata("MEDIUM")
	cast:SetPoint("CENTER")
	cast:SetSize(unpack(db.CastBarSize))
	cast:SetStatusBarTexture(db.CastBarTexture)
	cast:SetStatusBarColor(unpack(Colors.cast))
	cast:SetOrientation(db.CastBarOrientation)
	cast:SetSparkMap(db.CastBarSparkMap)
	cast:DisableSmoothing(true)
	cast.timeToHold = db.CastBarTimeToHoldFailed

	local castBackdrop = cast:CreateTexture(nil, "BORDER", nil, -2)
	castBackdrop:SetPoint(unpack(db.CastBarBackgroundPosition))
	castBackdrop:SetSize(unpack(db.CastBarBackgroundSize))
	castBackdrop:SetTexture(db.CastBarBackgroundTexture)
	castBackdrop:SetVertexColor(unpack(db.CastBarBackgroundColor))
	cast.Backdrop = castBackdrop

	local castShield = cast:CreateTexture(nil, "BORDER", nil, -1)
	castShield:SetPoint(unpack(db.CastBarShieldPosition))
	castShield:SetSize(unpack(db.CastBarShieldSize))
	castShield:SetTexture(db.CastBarShieldTexture)
	castShield:SetVertexColor(unpack(db.CastBarShieldColor))
	cast.Shield = castShield

	local castSafeZone = cast:CreateTexture(nil, "ARTWORK", nil, 0)
	castSafeZone:SetTexture(db.CastBarSpellQueueTexture)
	castSafeZone:SetVertexColor(unpack(db.CastBarSpellQueueColor))
	cast.SafeZone = castSafeZone

	local castText = cast:CreateFontString(nil, "OVERLAY", nil, 0)
	castText:SetPoint(unpack(db.CastBarTextPosition))
	castText:SetFontObject(db.CastBarTextFont)
	castText:SetTextColor(unpack(db.CastBarTextColor))
	castText:SetJustifyH(db.CastBarTextJustifyH)
	castText:SetJustifyV(db.CastBarTextJustifyV)
	cast.Text = castText

	local castTime = cast:CreateFontString(nil, "OVERLAY", nil, 0)
	castTime:SetPoint(unpack(db.CastBarValuePosition))
	castTime:SetFontObject(db.CastBarValueFont)
	castTime:SetTextColor(unpack(db.CastBarValueColor))
	castTime:SetJustifyH(db.CastBarValueJustifyH)
	castTime:SetJustifyV(db.CastBarValueJustifyV)
	cast.Time = castTime

	local castDelay = cast:CreateFontString(nil, "OVERLAY", nil, 0)
	castDelay:SetFontObject(GetFont(15,true))
	castDelay:SetTextColor(unpack(Colors.red))
	castDelay:SetPoint("LEFT", cast, "RIGHT", 20, 0)
	castDelay:SetJustifyV("MIDDLE")
	cast.Delay = castDelay

	-- TODO: Interrupt glow/shake animations.
	-- Commented out until we have a custom glow asset that fits
	-- the AzeriteUI art style. The Blizzard atlas doesn't look
	-- right at our castbar's scale/shape.
	--[[
	local interruptGlow = cast:CreateTexture(nil, "OVERLAY", nil, 7)
	interruptGlow:SetPoint("CENTER", cast, "CENTER", 0, 0)
	interruptGlow:SetSize(db.CastBarBackgroundSize[1] * 1.4, db.CastBarBackgroundSize[2] * 1.4)
	interruptGlow:SetBlendMode("ADD")
	interruptGlow:SetAlpha(0)
	interruptGlow:Hide()
	if (interruptGlow.SetAtlas) then
		local ok = pcall(interruptGlow.SetAtlas, interruptGlow, "cast_interrupt_outerglow")
		if (not ok) then
			interruptGlow:SetTexture(db.CastBarBackgroundTexture)
			interruptGlow:SetVertexColor(1, 0.2, 0.1, 1)
		end
	else
		interruptGlow:SetTexture(db.CastBarBackgroundTexture)
		interruptGlow:SetVertexColor(1, 0.2, 0.1, 1)
	end
	cast.InterruptGlow = interruptGlow

	local glowState = { active = false, elapsed = 0, duration = 1.0 }
	cast.InterruptGlowState = glowState
	cast.InterruptGlowAnim = {
		Play = function()
			glowState.active = true
			glowState.elapsed = 0
			interruptGlow:SetAlpha(1)
			interruptGlow:Show()
		end,
		Stop = function()
			glowState.active = false
			glowState.elapsed = 0
			interruptGlow:SetAlpha(0)
			interruptGlow:Hide()
		end,
	}
	cast:HookScript("OnUpdate", function(_, elapsed)
		if (not glowState.active) then return end
		glowState.elapsed = glowState.elapsed + elapsed
		local progress = glowState.elapsed / glowState.duration
		if (progress >= 1) then
			glowState.active = false
			interruptGlow:SetAlpha(0)
			interruptGlow:Hide()
		else
			interruptGlow:SetAlpha(1 - progress)
		end
	end)

	local shakeAnim = cast:CreateAnimationGroup()
	local shakeOffsets = {
		{ 0, 0, 0.1 },
		{ -1, 1, 0.05 },
		{ 1, -2, 0.05 },
		{ 1, 2, 0.05 },
		{ -1, -1, 0.05 },
	}
	for i, info in ipairs(shakeOffsets) do
		local trans = shakeAnim:CreateAnimation("Translation")
		trans:SetOffset(info[1], info[2])
		trans:SetDuration(info[3])
		trans:SetOrder(i)
		trans:SetSmoothing("NONE")
	end
	cast.InterruptShakeAnim = shakeAnim
	--]]

	cast.CustomDelayText = Cast_CustomDelayText
	cast.CustomTimeText = Cast_CustomTimeText
	cast.PostCastInterruptible = Cast_Update
	cast.PostCastStart = Cast_Update
	--cast.PostCastInterrupted = Cast_PostCastInterrupted -- TODO: needs custom glow asset
	--cast.PostCastFail = Cast_PostCastFail -- TODO: needs custom glow asset

	self.Castbar = cast

end

CastBarMod.CreateUnitFrames = function(self)

	local unit, name = "player", "PlayerCastBar"

	oUF:RegisterStyle(ns.Prefix..name, style)
	oUF:SetActiveStyle(ns.Prefix..name)

	self.frame = ns.UnitFrame.Spawn(unit, ns.Prefix.."UnitFrame"..name)
	self.frame:EnableMouse(false)
end

CastBarMod.UpdateVisibility = function(self, event, ...)
	if (not self.frame) then return end
	if (InCombatLockdown()) then
		self:RegisterEvent("PLAYER_REGEN_ENABLED", "UpdateVisibility")
		return
	end
	if (event == "PLAYER_REGEN_ENABLED") then
		self:UnregisterEvent("PLAYER_REGEN_ENABLED", "UpdateVisibility")
	end
	local shouldUseCustom = ShouldUseCustomCastbar(self)
	ApplyBlizzardCastbarState(self, shouldUseCustom)
	if (shouldUseCustom) then
		self.frame:Enable()
	else
		self.frame:Disable()
	end
end

CastBarMod.Update = function(self)
end

CastBarMod.OnEnable = function(self)

	self:CreateUnitFrames()
	self:CreateAnchor(HUD_EDIT_MODE_CAST_BAR_LABEL or SHOW_ARENA_ENEMY_CASTBAR_TEXT)

	self:RegisterEvent("CVAR_UPDATE", "UpdateVisibility")
	self:RegisterEvent("PLAYER_ENTERING_WORLD", "UpdateVisibility")
	self:UpdateVisibility("OnEnable")

	ns.MovableModulePrototype.OnEnable(self)
end

CastBarMod.OnInitialize = function(self)
	if (IsAddOnEnabled("Quartz")) then return self:Disable() end

	ns.MovableModulePrototype.OnInitialize(self)
end

CastBarMod.OnDisable = function(self)
	ApplyBlizzardCastbarState(self, false)
end
