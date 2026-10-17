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
-- The player as a party frame: /az -> Unit Frames -> Player (Party Style) ->
-- Use Party Frame as Player Frame (Gravehowl, Discord). The third player frame next to
-- Player and Player Alternate; only one of the three is on at a time (Options page).
-- The look is the party style itself (Party.lua PartyFrameMod.StylePlayer).
local _, ns = ...
local oUF = ns.oUF

local PlayerPartyMod = ns:NewModule("PlayerFrameParty", ns.UnitFrameModule, "LibMoreEvents-1.0")

local API = ns.API

-- Lua API
local ipairs = ipairs
local unpack = unpack

-- GLOBALS: InCombatLockdown, RegisterAttributeDriver, UnregisterAttributeDriver, UnregisterUnitWatch

local defaults = { profile = ns:Merge({
	enabled = false,
	showPortrait = true,
	useClassColor = true
}, ns.MovableModulePrototype.defaults) }

-- Generate module defaults on the fly
-- to recalculate default values relying on
-- changing factors like user interface scale.
PlayerPartyMod.GenerateDefaults = function(self)
	defaults.profile.savedPosition = {
		scale = ns.API.GetEffectiveScale(),
		[1] = "BOTTOM",
		[2] = 0,
		[3] = 270 * ns.API.GetEffectiveScale()
	}
	return defaults
end

-- Utility Functions
--------------------------------------------
local IsLegacy = function()
	return ns.LegacyHUD and ns.LegacyHUD.IsActive and ns.LegacyHUD:IsActive()
end

-- position is { point, relativePoint, x, y } against the health bar,
-- or a plain layout position against the region's parent when relativeTo is nil.
local Place = function(region, position, size, relativeTo)
	if (not region or not position) then return end
	region:ClearAllPoints()
	if (relativeTo) then
		region:SetPoint(position[1], relativeTo, position[2], position[3], position[4])
	else
		region:SetPoint(unpack(position))
	end
	if (size) then
		region:SetSize(unpack(size))
	end
end

-- Full party look, or (portrait off) only the bar with the badges moved onto it.
-- Size changes are protected on a unit button, so this only runs out of combat.
local ApplyLayout = function(frame, compact)
	local db = ns.GetConfig("PartyFrames")
	local health = frame.Health
	local bar = compact and health or nil

	frame:SetSize(unpack(compact and db.PlayerCompactSize or db.UnitSize))

	local role = frame.GroupRoleIndicator
	if (role) then
		Place(role, compact and db.PlayerCompactGroupRolePosition or db.GroupRolePosition,
			compact and db.PlayerCompactGroupRoleSize or db.GroupRoleSize, bar)
		if (role.Backdrop) then
			role.Backdrop:SetSize(unpack(compact and db.PlayerCompactGroupRoleBackdropSize or db.GroupRoleBackdropSize))
		end
		if (role.Icon) then
			role.Icon:SetSize(unpack(compact and db.PlayerCompactGroupRoleIconSize or db.GroupRoleIconSize))
		end
	end

	local leaderPosition = compact and db.PlayerCompactLeaderPosition or db.LeaderIndicatorPosition
	local leaderSize = compact and db.PlayerCompactLeaderSize or db.LeaderIndicatorSize
	Place(frame.LeaderIndicator, leaderPosition, leaderSize, bar)
	Place(frame.AssistantIndicator, leaderPosition, leaderSize, bar)

	Place(frame.RaidTargetIndicator, compact and db.PlayerCompactRaidTargetPosition or db.RaidTargetPosition,
		compact and db.PlayerCompactRaidTargetSize or db.RaidTargetSize, bar)

	if (compact) then
		Place(frame.ReadyCheckIndicator, db.PlayerCompactIconPosition, db.PlayerCompactIconSize, bar)
		Place(frame.ResurrectIndicator, db.PlayerCompactIconPosition, db.PlayerCompactIconSize, bar)
		Place(frame.SummonIndicator, db.PlayerCompactIconPosition, db.PlayerCompactIconSize, bar)
	else
		Place(frame.ReadyCheckIndicator, db.ReadyCheckPosition, db.ReadyCheckSize)
		Place(frame.ResurrectIndicator, db.ResurrectIndicatorPosition, db.ResurrectIndicatorSize)
		Place(frame.SummonIndicator, db.SummonIndicatorPosition, db.SummonIndicatorSize)
	end

	local feedback = frame.CombatFeedback
	if (feedback) then
		feedback:ClearAllPoints()
		if (compact) then
			local position = db.PlayerCompactCombatFeedbackPosition
			feedback:SetPoint(position[1], health, position[2], position[3], position[4])
		else
			local position = db.CombatFeedbackPosition
			feedback:SetPoint(position[1], frame[db.CombatFeedbackAnchorElement] or frame, unpack(position))
		end
	end

	-- The portrait, its plate, ring and the threat glow behind the ring live on two
	-- holder frames (Party.lua); hiding those takes the 3D model with them.
	local portrait = frame.Portrait
	if (portrait) then
		local holder = portrait:GetParent()
		local ring = portrait.Border and portrait.Border:GetParent()
		if (holder and holder ~= frame) then holder:SetShown(not compact) end
		if (ring and ring ~= frame) then ring:SetShown(not compact) end
		if (compact) then
			if (frame:IsElementEnabled("Portrait")) then frame:DisableElement("Portrait") end
		elseif (not frame:IsElementEnabled("Portrait")) then
			frame:EnableElement("Portrait")
			portrait:ForceUpdate()
		end
	end
end

-- Module API
--------------------------------------------
PlayerPartyMod.CreateUnitFrames = function(self)
	-- Retail and Forever enable this module from WoW11/UnitFrames/PlayerFrameParty.lua,
	-- which creates the frame and then calls Enable (OnEnable): spawn it once.
	if (self.frame) then return end

	local party = ns:GetModule("PartyFrames", true)
	if (not party or not party.StylePlayer) then return end

	local unit, name = "player", "PlayerParty"

	oUF:RegisterStyle(ns.Prefix..name, party.StylePlayer)
	oUF:SetActiveStyle(ns.Prefix..name)

	self.frame = ns.UnitFrame.Spawn(unit, ns.Prefix.."UnitFrame"..name)
	self.frame:SetSize(unpack(ns.GetConfig("PartyFrames").UnitSize))

	local enabled = true

	self.frame.Enable = function(self)
		enabled = true
		local ok = API.TryCall(RegisterAttributeDriver, self, "unit", "[vehicleui]vehicle; player")
		if (not ok) then
			API.SafeCall("PlayerParty.Enable.SetAttribute", self.SetAttribute, self, "unit", "player")
		end
		self:Show()
	end

	self.frame.Disable = function(self)
		enabled = false
		API.SafeCall("PlayerParty.Disable.UnregisterAttributeDriver", UnregisterAttributeDriver, self, "unit")
		self:Hide()
	end

	self.frame.IsEnabled = function(self)
		return enabled
	end

	UnregisterUnitWatch(self.frame)
	self.frame:SetAttribute("toggleForVehicle", false)
end

PlayerPartyMod.UpdateLayout = function(self)
	local frame = self.frame
	if (not frame) then return end
	if (InCombatLockdown()) then
		self.layoutPending = true
		return self:RegisterEvent("PLAYER_REGEN_ENABLED", "OnLayoutEvent")
	end
	self.layoutPending = nil
	-- Legacy draws its own compact casing from the party layout and hides the portrait.
	local compact = (not IsLegacy()) and (self.db.profile.showPortrait == false)
	ApplyLayout(frame, compact)
	self:UpdateAnchor()
end

PlayerPartyMod.OnLayoutEvent = function(self, event)
	if (event ~= "PLAYER_REGEN_ENABLED" or InCombatLockdown()) then return end
	self:UnregisterEvent("PLAYER_REGEN_ENABLED", "OnLayoutEvent")
	if (self.layoutPending) then
		self:UpdateLayout()
	end
end

PlayerPartyMod.Update = function(self)
	local frame = self.frame
	if (not frame) then return end

	local health = frame.Health
	health.colorClass = self.db.profile.useClassColor and true or false
	health.colorClassPet = false
	health.colorReaction = false
	health.colorHealth = true
	health:ForceUpdate()

	self:UpdateLayout()

	if (frame.PostUpdate) then
		frame:PostUpdate("Update")
	end
end

-- Only one player frame at a time. A profile with Player or Player Alternate on
-- keeps this one off (the options turn the others off when it is ticked).
PlayerPartyMod.PostInitialize = function(self)
	for _, name in ipairs({ "PlayerFrame", "PlayerFrameAlternate" }) do
		local other = ns:GetModule(name, true)
		if (other and other.db and other.db.profile and other.db.profile.enabled) then
			self.db.profile.enabled = false
			return
		end
	end
end

PlayerPartyMod.OnEnable = function(self)
	self:CreateUnitFrames()
	if (not self.frame) then return end
	self:CreateAnchor("PlayerFrame (Party)")

	ns.MovableModulePrototype.OnEnable(self)
end
