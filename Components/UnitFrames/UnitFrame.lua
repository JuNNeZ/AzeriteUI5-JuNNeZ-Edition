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
local oUF = ns.oUF

local UnitFrameMod = ns:NewModule("UnitFrames", "LibMoreEvents-1.0")
local API = ns.API

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
	showIncomingHeals = true,
	showOverhealIndicator = false,
	showDamageAbsorbs = true,
	absorbDisplayMode = "total",
	showHealAbsorbs = true,
	colorCastSpellTextByState = false,
	auraTimerColors = true,
	showCombatFeedback = true,
	-- Engine-eased bars (Enum.StatusBarInterpolation), see ns.UnitFrame.SetSmoothingEnabled.
	smoothBars = true, -- health and power
	smoothCastbars = true, -- castbar pushback
	-- Group Indicators (GroupIndicators.lua): Sated and corner aura dots on party and raid frames.
	groupSated = false,
	groupCorners = false,
	groupCornerOnlyMine = true,
	groupCornerSize = 10,
	groupCornerSpellsTOPLEFT = "",
	groupCornerSpellsTOPRIGHT = "",
	groupCornerSpellsBOTTOMLEFT = "",
	groupCornerSpellsBOTTOMRIGHT = "",
	powerValueAlpha = 75,
	playerPowerValueAlpha = nil,
	targetPowerValueAlpha = nil,
	disableHealComm = nil -- TODO: purge it
}, ns.MovableModulePrototype.defaults) }

-- Engine-eased bars
---------------------------------------------------
-- Health and power are secret in combat, so no addon can animate them in Lua any more.
-- The engine can: SetValue and SetTimerDuration take an interpolation. A bar whose
-- style asks for it (DisableSmoothing(false)) is listed here and eases while its
-- switch is on; forced updates still snap (Functions.lua SetStatusBarValuesCompat).
local IMMEDIATE = (Enum and Enum.StatusBarInterpolation and Enum.StatusBarInterpolation.Immediate) or 0
local EASED = (Enum and Enum.StatusBarInterpolation and Enum.StatusBarInterpolation.ExponentialEaseOut) or 1
local SmoothBars = setmetatable({}, { __mode = "k" })

-- "bars" (health, power) or "castbars" (pushback).
local IsSmoothingEnabled = function(kind)
	local module = ns:GetModule("UnitFrames", true)
	local profile = module and module.db and module.db.profile
	if (kind == "castbars") then
		return not (profile and profile.smoothCastbars == false)
	end
	return not (profile and profile.smoothBars == false)
end

local ApplySmoothing = function(bar)
	local on = bar.__AzeriteUI_WantsSmoothing and IsSmoothingEnabled(bar.__AzeriteUI_SmoothKind) and true or false
	bar.smoothing = on and EASED or IMMEDIATE
	if (not on and bar.SetToTargetValue) then
		-- Finish any easing now, so turning it off shows the plain bar at once.
		API.TryCall(bar.SetToTargetValue, bar)
	end
	if (bar.__AzeriteUI_OnSmoothingChanged) then
		bar:__AzeriteUI_OnSmoothingChanged(on)
	end
end

-- DisableSmoothing(false[, kind]) on bars from CreateBar; SetBarSmoothing below for plain StatusBars.
local SetBarSmoothing = function(element, disabled, kind)
	element.__AzeriteUI_WantsSmoothing = (not disabled) and true or nil
	element.__AzeriteUI_SmoothKind = kind or element.__AzeriteUI_SmoothKind or "bars"
	if (element.__AzeriteUI_WantsSmoothing) then
		SmoothBars[element] = true
	else
		SmoothBars[element] = nil
	end
	ApplySmoothing(element)
end

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
	-- DisableSmoothing(false[, "castbars"]) lets the bar ease while its switch is on;
	-- DisableSmoothing(true) keeps it Immediate. Enum.StatusBarInterpolation only has
	-- Immediate = 0 and ExponentialEaseOut = 1 (there is no Linear member).
	bar.DisableSmoothing = bar.DisableSmoothing or SetBarSmoothing
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
	-- Tooltips > Hide in Combat. Returning here only skips Blizzard's handler; nothing of ours
	-- runs inside it, so it cannot taint it (upstream AzeriteUI has the same check).
	local tooltips = ns:GetModule("Tooltips", true)
	if (tooltips and tooltips:IsEnabled() and tooltips:ShouldHideInCombat("unitframes") and InCombatLockdown()) then
		return
	end
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
	-- `oUF-headerType` rather than `initialConfigFunction`: oUF sets the former on
	-- every header it spawns, while the latter only exists where the client can
	-- compile the snippet it holds. A module that drives its own unit buttons, such
	-- as Raid5, sets neither and is correctly not treated as a header child.
	return parent:GetAttribute("oUF-headerType") ~= nil
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

-- Whether native aura countdowns turn yellow, orange and red as they run out.
-- Read when a button is styled, so a change applies from the next reload.
ns.UnitFrame.ShouldColorAuraTimers = function()
	local module = ns:GetModule("UnitFrames", true)
	local profile = module and module.db and module.db.profile
	return not (profile and profile.auraTimerColors == false)
end

--- Whether eased bars are on: kind "bars" (health and power) or "castbars" (pushback).
ns.UnitFrame.IsSmoothingEnabled = function(kind)
	return IsSmoothingEnabled(kind)
end

--- Turns eased bars on or off at once, in or out of combat (only the interpolation
-- argument changes; nothing secure is touched). kind is "bars", "castbars" or nil for both.
ns.UnitFrame.SetSmoothingEnabled = function(kind, enabled)
	local module = ns:GetModule("UnitFrames", true)
	local profile = module and module.db and module.db.profile
	if (not profile) then return end
	if (kind == nil or kind == "bars") then profile.smoothBars = enabled and true or false end
	if (kind == nil or kind == "castbars") then profile.smoothCastbars = enabled and true or false end
	for bar in next, SmoothBars do
		if (kind == nil or bar.__AzeriteUI_SmoothKind == kind) then
			ApplySmoothing(bar)
		end
	end
end

--- Lets a plain StatusBar (not made by CreateBar, e.g. Target's power crystal) ease
-- under the same switch: wants true lists it, false keeps it Immediate. kind as above.
ns.UnitFrame.SetBarSmoothing = function(bar, wants, kind)
	if (not bar) then return end
	SetBarSmoothing(bar, not wants, kind)
end

-- Re-applies the saved switches to every listed bar (profile changes).
ns.UnitFrame.RefreshSmoothing = function()
	for bar in next, SmoothBars do
		ApplySmoothing(bar)
	end
end

-- Whether hits, heals and misses flash as text on the unit frames
-- (Libs/oUF_Plugins/oUF_CombatFeedback.lua asks on every event).
ns.UnitFrame.ShouldShowCombatFeedback = function()
	local module = ns:GetModule("UnitFrames", true)
	local profile = module and module.db and module.db.profile
	return not (profile and profile.showCombatFeedback == false)
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

-- Group frames register for clicks from their style function (right-click menus need
-- "AnyUp"). A secure header that spawns a child in combat (someone joins the raid
-- mid-fight) runs that style in lockdown, where RegisterForClicks is blocked
-- (ADDON_ACTION_BLOCKED, Raid25.lua). Such children are queued until combat ends;
-- left-click targeting works meanwhile, since buttons take LeftButtonUp by default.
local pendingClicks, clickQueueFrame = {}, nil

ns.UnitFrame.RegisterGroupClicks = function(self)
	if (not InCombatLockdown()) then
		self:RegisterForClicks("AnyUp")
		return
	end
	pendingClicks[self] = true
	if (not clickQueueFrame) then
		clickQueueFrame = CreateFrame("Frame")
		clickQueueFrame:SetScript("OnEvent", function(queue)
			if (InCombatLockdown()) then return end
			queue:UnregisterEvent("PLAYER_REGEN_ENABLED")
			for frame in next, pendingClicks do
				pendingClicks[frame] = nil
				frame:RegisterForClicks("AnyUp")
			end
		end)
	end
	clickQueueFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
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
	if (API.RefreshHealthPrediction) then API.RefreshHealthPrediction() end
	if (ns.GroupIndicators) then ns.GroupIndicators.Refresh() end
	local ApplyAuraSortSettings = function(frame, preSetPosition, sortFunction)
		if (not frame) then
			return
		end
		for _, key in next, { "Auras", "Buffs", "Debuffs" } do
			local auras = frame[key]
			if (auras) then
				auras.PreSetPosition = preSetPosition -- only in classic
				auras.SortAuras = sortFunction -- only in retail
				if (frame:IsElementEnabled("Auras") and auras.ForceUpdate) then
					auras:ForceUpdate()
				end
			end
		end
	end

	if (self.db.profile.disableAuraSorting) then

		-- Iterate through unitframes.
		if (ns.UnitFrames) then
			for frame in next,ns.UnitFrames do
				ApplyAuraSortSettings(frame, ns.AuraSorts.Alternate, ns.AuraSorts.AlternateFuncton)
			end
		end

		-- Iterate through nameplates.
		if (ns.NamePlates) then
			for frame in next,ns.NamePlates do
				ApplyAuraSortSettings(frame, ns.AuraSorts.Alternate, ns.AuraSorts.AlternateFuncton)
			end
		end
	else

		-- Iterate through unitframes.
		if (ns.UnitFrames) then
			for frame in next,ns.UnitFrames do
				ApplyAuraSortSettings(frame, ns.AuraSorts.Default, ns.AuraSorts.DefaultFunction)
			end
		end

		-- Iterate through nameplates.
		if (ns.NamePlates) then
			for frame in next,ns.NamePlates do
				ApplyAuraSortSettings(frame, ns.AuraSorts.Default, ns.AuraSorts.DefaultFunction)
			end
		end

	end

	-- Force update ClassPower elements to reflect customization changes
	local showFeedback = ns.UnitFrame.ShouldShowCombatFeedback()
	if (ns.UnitFrames) then
		for frame in next,ns.UnitFrames do
			-- Text already on screen fades by itself; switched off, it goes at once.
			if (not showFeedback and frame.CombatFeedback) then
				frame.CombatFeedback:Hide()
			end
			local classpower = frame.ClassPower
			if (classpower and frame:IsElementEnabled("ClassPower")) then
				classpower:ForceUpdate()
			end
			ns.UnitFrame.ApplyPowerValueAlpha(frame)
			local power = frame.Power
			if (power and power.ForceUpdate) then
				API.SafeCall("UnitFrame.Power.ForceUpdate", power.ForceUpdate, power)
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

-- /azsmooth [on|off] [bars|cast]: flip eased bars mid-fight for a side-by-side look.
local SmoothSlash = function(input)
	local words = {}
	for word in string.gmatch(string.lower(input or ""), "%S+") do words[#words + 1] = word end
	-- /azsmooth trace [unit|off]: one chat line per health/power write on that unit.
	if (words[1] == "trace") then
		local unit = words[2] or "target"
		if (unit == "off" or (API.SmoothTrace == unit and not words[2])) then
			API.SmoothTrace = nil
			ns:Print("Smooth bars trace: off.")
		else
			API.SmoothTrace = unit
			ns:Print(string.format("Smooth bars trace: %s. /azsmooth trace off to stop.", unit))
		end
		return
	end
	local state, kind
	for _, word in ipairs(words) do
		if (word == "on" or word == "off") then state = word end
		if (word == "bars" or word == "bar" or word == "health" or word == "power") then kind = "bars" end
		if (word == "cast" or word == "castbar" or word == "castbars") then kind = "castbars" end
	end
	local current = IsSmoothingEnabled(kind or "bars")
	local enabled
	if (state == "on") then enabled = true elseif (state == "off") then enabled = false else enabled = not current end
	ns.UnitFrame.SetSmoothingEnabled(kind, enabled)
	ns:Print(string.format("Smooth bars: health/power %s, castbar pushback %s.",
		IsSmoothingEnabled("bars") and "|cff00ff00on|r" or "|cffff4040off|r",
		IsSmoothingEnabled("castbars") and "|cff00ff00on|r" or "|cffff4040off|r"))
end

UnitFrameMod.OnInitialize = function(self)
	self.db = ns.db:RegisterNamespace("UnitFrames", defaults)
	self.db.RegisterCallback(self, "OnProfileChanged", function() ns.UnitFrame.RefreshSmoothing() end)
	self.db.RegisterCallback(self, "OnProfileCopied", function() ns.UnitFrame.RefreshSmoothing() end)
	self.db.RegisterCallback(self, "OnProfileReset", function() ns.UnitFrame.RefreshSmoothing() end)
	if (ns.RegisterChatCommand) then
		ns:RegisterChatCommand("azsmooth", SmoothSlash)
	end
end
