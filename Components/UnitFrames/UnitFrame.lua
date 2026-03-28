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

local UnitFrameMod = ns:NewModule("UnitFrames", "LibMoreEvents-1.0")

local LibSpinBar = LibStub("LibSpinBar-1.0")
local LibOrb = LibStub("LibOrb-1.0")  -- Mana Orb System by Arahort

-- Lua API
local next = next


-- GLOBALS: UIParent
-- GLOBALS: InCombatLockdown, UnitFrame_OnEnter, UnitFrame_OnLeave

local defaults = { profile = ns:Merge({
	enabled = true,
	disableAuraSorting = false,
	showBlizzardRaidBar = false,
	colorCastSpellTextByState = false,
	powerValueAlpha = 75,
	playerPowerValueAlpha = nil,
	targetPowerValueAlpha = nil,
	disableHealComm = nil -- TODO: purge it
}, ns.MovableModulePrototype.defaults) }

-- UnitFrame Callbacks
---------------------------------------------------
local UnitFrame_CreateBar = function(self, name, parent, ...)
	local bar = CreateFrame("StatusBar", name, parent or self, ...)
	bar.smoothing = (Enum and Enum.StatusBarInterpolation and Enum.StatusBarInterpolation.Immediate) or 0
	bar.__AzeriteUI_Growth = bar.__AzeriteUI_Growth or "RIGHT"
	bar.__AzeriteUI_FlippedHorizontally = bar.__AzeriteUI_FlippedHorizontally or false
	local OrigSetOrientation = bar.SetOrientation

	-- Compatibility shim for legacy unitframe code paths that still call
	-- LibSmoothBar helpers while we run native oUF/statusbar rendering.
	bar.SetOrientation = function(element, orientation)
		local safeOrientation = orientation
		if (orientation == "LEFT" or orientation == "RIGHT") then
			safeOrientation = "HORIZONTAL"
			element.__AzeriteUI_Growth = orientation
			if (element.SetReverseFill) then
				element:SetReverseFill(orientation == "LEFT")
			end
		elseif (orientation == "UP" or orientation == "DOWN") then
			safeOrientation = "VERTICAL"
			element.__AzeriteUI_Growth = orientation
			if (element.SetReverseFill) then
				element:SetReverseFill(orientation == "DOWN")
			end
		elseif (orientation == "HORIZONTAL" or orientation == "VERTICAL") then
			safeOrientation = orientation
		else
			safeOrientation = "HORIZONTAL"
		end
		return OrigSetOrientation(element, safeOrientation)
	end
	bar.SetGrowth = bar.SetGrowth or function(element, growth)
		if (growth == "LEFT" or growth == "RIGHT" or growth == "UP" or growth == "DOWN") then
			element.__AzeriteUI_Growth = growth
			element:SetOrientation(growth)
		end
	end
	bar.GetGrowth = bar.GetGrowth or function(element)
		return element.__AzeriteUI_Growth or "RIGHT"
	end
	bar.DisableSmoothing = bar.DisableSmoothing or function(element, disabled)
		local immediate = (Enum and Enum.StatusBarInterpolation and Enum.StatusBarInterpolation.Immediate) or 0
		local linear = (Enum and Enum.StatusBarInterpolation and Enum.StatusBarInterpolation.Linear) or immediate
		element.smoothing = disabled and immediate or linear
	end
	bar.SetSparkMap = bar.SetSparkMap or function(element, map)
		element.sparkMap = map
	end
	bar.SetSparkTexture = bar.SetSparkTexture or function(element, path)
		element.sparkTexture = path
	end
	bar.SetTexCoord = bar.SetTexCoord or function(element, ...)
		local texture, extraTexture = element:GetStatusBarTexture()
		if (extraTexture) then
			return
		end
		if (texture and texture.SetTexCoord) then
			texture:SetTexCoord(...)
		end
	end
	bar.GetTexCoord = bar.GetTexCoord or function(element)
		local texture = element:GetStatusBarTexture()
		if (texture and texture.GetTexCoord) then
			return texture:GetTexCoord()
		end
		return 0, 1, 0, 1
	end
	bar.SetForceNative = bar.SetForceNative or function(element, forceNative)
		element.forceNative = forceNative and true or false
	end
	bar.SetFlippedHorizontally = bar.SetFlippedHorizontally or function(element, flipped)
		element.__AzeriteUI_FlippedHorizontally = flipped and true or false
		local texture, extraTexture = element:GetStatusBarTexture()
		if (extraTexture) then
			return
		end
		if (not texture or not texture.SetTexCoord) then
			return
		end
		if (flipped) then
			texture:SetTexCoord(1, 0, 0, 1)
		else
			texture:SetTexCoord(0, 1, 0, 1)
		end
	end
	bar.IsFlippedHorizontally = bar.IsFlippedHorizontally or function(element)
		return element.__AzeriteUI_FlippedHorizontally and true or false
	end
	bar.GetSecretPercent = bar.GetSecretPercent or function(element)
		local value = element.GetValue and element:GetValue()
		local minValue, maxValue = element.GetMinMaxValues and element:GetMinMaxValues()
		if (type(value) ~= "number" or type(minValue) ~= "number" or type(maxValue) ~= "number") then
			return nil
		end
		if ((issecretvalue and (issecretvalue(value) or issecretvalue(minValue) or issecretvalue(maxValue))) or maxValue <= minValue) then
			return nil
		end
		local percent = ((value - minValue) / (maxValue - minValue)) * 100
		if (percent < 0) then
			return 0
		elseif (percent > 100) then
			return 100
		end
		return percent
	end

	return bar
end

local UnitFrame_CreateRing = function(self, name, parent, ...)
	return LibSpinBar:CreateSpinBar(name, parent or self, ...)
end

local UnitFrame_CreateOrb = function(self, name, parent, ...)
	return LibOrb:CreateOrb(name, parent or self, ...)
end

local UnitFrame_OnEnter = function(self, ...)
	self.isMouseOver = true
	if (self.OnEnter) then
		self:OnEnter(...)
	end
	-- Tooltip interception disabled; always delegate to Blizzard handler.
	return _G.UnitFrame_OnEnter(self, ...)
end

local UnitFrame_OnLeave = function(self, ...)
	self.isMouseOver = nil
	if (self.OnLeave) then
		self:OnLeave(...)
	end
	return _G.UnitFrame_OnLeave(self, ...)
end

local UnitFrame_OnHide = function(self, ...)
	self.isMouseOver = nil
	if (self.OnHide) then
		self:OnHide(...)
	end
end

local IsSecureHeaderChild = function(frame)
	local parent = frame and frame.GetParent and frame:GetParent()
	if (not parent or not parent.GetAttribute) then
		return false
	end
	return parent:GetAttribute("initialConfigFunction") ~= nil
end

-- UnitFrame Prototype
---------------------------------------------------
oUF:RegisterMetaFunction("CreateBar", UnitFrame_CreateBar)
oUF:RegisterMetaFunction("CreateRing", UnitFrame_CreateRing)
oUF:RegisterMetaFunction("CreateOrb", UnitFrame_CreateOrb)

-- UnitFrame Module Defauts
local unitFrameDefaults = {
	enabled = true,
	scale = 1
}

ns.UnitFrames = {}
ns.UnitFrame = {}
ns.UnitFrame.defaults = unitFrameDefaults

ns.UnitFrame.ShouldColorCastSpellTextByState = function()
	local module = ns:GetModule("UnitFrames", true)
	local profile = module and module.db and module.db.profile
	return profile and profile.colorCastSpellTextByState == true or false
end

ns.UnitFrame.GetPowerValueAlpha = function(kind)
	local module = ns:GetModule("UnitFrames", true)
	local profile = module and module.db and module.db.profile
	local alphaPercent = nil
	if (kind == "player") then
		alphaPercent = profile and profile.playerPowerValueAlpha
	elseif (kind == "target") then
		alphaPercent = profile and profile.targetPowerValueAlpha
	end
	if (type(alphaPercent) ~= "number") then
		alphaPercent = profile and profile.powerValueAlpha
	end
	if (type(alphaPercent) ~= "number") then
		alphaPercent = 75
	end
	if (alphaPercent < 0) then
		alphaPercent = 0
	elseif (alphaPercent > 100) then
		alphaPercent = 100
	end
	return alphaPercent / 100
end

ns.UnitFrame.ApplyPowerValueAlpha = function(frame, kind)
	if (not frame) then
		return
	end
	local alpha = ns.UnitFrame.GetPowerValueAlpha(kind)
	if (frame.Power and frame.Power.Value and frame.Power.Value.SetAlpha) then
		frame.Power.Value:SetAlpha(alpha)
	end
	if (frame.Power and frame.Power.Percent and frame.Power.Percent.SetAlpha) then
		frame.Power.Percent:SetAlpha(alpha)
	end
	if (frame.ManaOrb and frame.ManaOrb.Value and frame.ManaOrb.Value.SetAlpha) then
		frame.ManaOrb.Value:SetAlpha(alpha)
	end
	if (frame.ManaOrb and frame.ManaOrb.Percent and frame.ManaOrb.Percent.SetAlpha) then
		frame.ManaOrb.Percent:SetAlpha(alpha)
	end
end

ns.UnitFrame.InitializeUnitFrame = function(self)

	self.isUnitFrame = true
	self.colors = ns.Colors

	if (not IsSecureHeaderChild(self)) then
		self:RegisterForClicks("AnyUp")
	end
	self:SetScript("OnEnter", UnitFrame_OnEnter)
	self:SetScript("OnLeave", UnitFrame_OnLeave)
	self:SetScript("OnHide", UnitFrame_OnHide)

end

ns.UnitFrame.Spawn = function(unit, overrideName, ...)
	local frame = oUF:Spawn(unit, overrideName)

	ns.UnitFrame.InitializeUnitFrame(frame)
	ns.UnitFrames[frame] = true

	return frame
end

local enableProxy = function(frame)
	local method = frame.OverrideEnable or frame.Enable
	method(frame)
end

local disableProxy = function(frame)
	local method = frame.OverrideDisable or frame.Disable
	method(frame)
end

-- Inherit from the default movable frame module prototype.
ns.UnitFrameModule = ns:Merge({
	OnEnabledEvent = function(self, event, ...)
		if (event == "PLAYER_REGEN_ENABLED") then
			if (InCombatLockdown()) then return end
			self:UnregisterEvent("PLAYER_REGEN_ENABLED", "OnConfigEvent")
			self:UpdateEnabled()
		end
	end,

	UpdateEnabled = function(self)
		if (InCombatLockdown()) then
			return self:RegisterEvent("PLAYER_REGEN_ENABLED", "OnEnabledEvent")
		end

		local unitframe, anchor = self:GetUnitFrameOrHeader(), self:GetAnchor()
		if (unitframe) then
			local config = self.db.profile
			if (config.enabled) then
				enableProxy(unitframe)

				if (anchor) then
					anchor:Enable()
				end
			else
				disableProxy(unitframe)

				if (anchor) then
					anchor:Disable()
				end
			end
		end

	end,

	UpdateSettings = function(self)
		self:UpdateEnabled()

		if (self.db.profile.enabled) then
			self:Update()
			self:UpdatePositionAndScale()
			self:UpdateAnchor()
		end
	end,

	Update = function(self)
		-- Placeholder. Update unitframe settings here.
	end,

	PostUpdatePositionAndScale = function(self)
		local config = self.db.profile.savedPosition
		if (not config) then return end

		local frame = self.frame

		-- Used by group frames
		local header = self.frame.content
		if (header) then
			header:SetScale(config.scale)
		end

		-- Used by boss frames
		if (frame.units) then
			for i,unitFrame in next,frame.units do
				if (not header or unitFrame:GetParent() ~= header) then
					unitFrame:SetScale(config.scale)
				end
			end
		end
	end,

	GetFrame = function(self)
		return self.frame
	end,

	GetUnitFrameOrHeader = function(self)
		return self.frame and self.frame.content or self.frame
	end,

	CreateAnchor = function(self, label, watchVariables, colorGroup)
		return ns.MovableModulePrototype.CreateAnchor(self, label, watchVariables, colorGroup or "unitframes")
	end

}, ns.MovableModulePrototype)

UnitFrameMod.UpdateSettings = function(self)

	if (self.db.profile.disableAuraSorting) then

		-- Iterate through unitframes.
		if (ns.UnitFrames) then
			for frame in next,ns.UnitFrames do
				local auras = frame.Auras
				if (auras) then
					auras.PreSetPosition = ns.AuraSorts.Alternate -- only in classic
					auras.SortAuras = ns.AuraSorts.AlternateFuncton -- only in retail
					if (frame:IsElementEnabled("Auras")) then
						auras:ForceUpdate()
					end
				end
			end
		end

		-- Iterate through nameplates.
		if (ns.NamePlates) then
			for frame in next,ns.NamePlates do
				local auras = frame.Auras
				if (auras) then
					auras.PreSetPosition = ns.AuraSorts.Alternate -- only in classic
					auras.SortAuras = ns.AuraSorts.AlternateFuncton -- only in retail
					if (frame:IsElementEnabled("Auras")) then
						auras:ForceUpdate()
					end
				end
			end
		end
	else

		-- Iterate through unitframes.
		if (ns.UnitFrames) then
			for frame in next,ns.UnitFrames do
				local auras = frame.Auras
				if (auras) then
					auras.PreSetPosition = ns.AuraSorts.Default -- only in classic
					auras.SortAuras = ns.AuraSorts.DefaultFunction -- only in retail
					if (frame:IsElementEnabled("Auras")) then
						auras:ForceUpdate()
					end
				end
			end
		end

		-- Iterate through nameplates.
		if (ns.NamePlates) then
			for frame in next,ns.NamePlates do
				local auras = frame.Auras
				if (auras) then
					auras.PreSetPosition = ns.AuraSorts.Default -- only in classic
					auras.SortAuras = ns.AuraSorts.DefaultFunction -- only in retail
					if (frame:IsElementEnabled("Auras")) then
						auras:ForceUpdate()
					end
				end
			end
		end

	end

	-- Force update ClassPower elements to reflect customization changes
	if (ns.UnitFrames) then
		for frame in next,ns.UnitFrames do
			local classpower = frame.ClassPower
			if (classpower and frame:IsElementEnabled("ClassPower")) then
				classpower:ForceUpdate()
			end
			ns.UnitFrame.ApplyPowerValueAlpha(frame)
			local power = frame.Power
			if (power and power.ForceUpdate) then
				pcall(power.ForceUpdate, power)
			end
		end
	end

	local RefreshCastbar = function(castbar)
		if (castbar and type(castbar.__AzeriteUI_InterruptRefreshCallback) == "function") then
			ns.API.UpdateInterruptCastBarRefresh(castbar, nil, "unitframes_settings")
		end
	end

	if (ns.UnitFrames) then
		for frame in next,ns.UnitFrames do
			RefreshCastbar(frame.Castbar)
		end
	end

	if (ns.NamePlates) then
		for frame in next,ns.NamePlates do
			RefreshCastbar(frame.Castbar)
		end
	end

end

UnitFrameMod.OnEnable = function(self)
	self:RegisterEvent("PLAYER_ENTERING_WORLD", "UpdateSettings")
end

UnitFrameMod.OnInitialize = function(self)
	self.db = ns.db:RegisterNamespace("UnitFrames", defaults)
end
