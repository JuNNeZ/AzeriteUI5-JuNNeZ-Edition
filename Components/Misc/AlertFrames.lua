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

local L = LibStub("AceLocale-3.0"):GetLocale((...))

local AlertFrames = ns:NewModule("AlertFrames", ns.MovableModulePrototype, "LibMoreEvents-1.0", "AceHook-3.0")
AlertFrames.lootRollRowGap = 5

-- GLOBALS: CreateFrame
-- GLOBALS: AlertFrame, GroupLootContainer, UIParent, TalkingHeadFrame
-- GLOBALS: UIPARENT_MANAGED_FRAME_POSITIONS
-- GLOBALS: C_LootHistory, C_Timer, Enum, GameTooltip, GetActiveLootRollIDs, GetLootRollItemLink, issecretvalue

-- Lua API
local ipairs = ipairs
local unpack = unpack

local points = {
	TOP = { "TOP", "BOTTOM", 0, -1 },
	TOPLEFT = { "TOP", "BOTTOM", 0, -1 },
	TOPRIGHT = { "TOP", "BOTTOM", 0, -1 },
	CENTER = { "BOTTOM", "TOP", 0, 1 },
	LEFT = { "BOTTOM", "TOP", 0, 1 },
	RIGHT = { "BOTTOM", "TOP", 0, 1 },
	BOTTOM = { "BOTTOM", "TOP", 0, 1 },
	BOTTOMLEFT = { "BOTTOM", "TOP", 0, 1 },
	BOTTOMRIGHT = { "BOTTOM", "TOP", 0, 1 },
}

local defaults = { profile = ns:Merge({
	useAutomaticGrowth = true,
	growUpwards = false,
	skinLootRolls = false,
	lootRollClassTheme = false,
	showLootRollChoices = false
}, ns.MovableModulePrototype.defaults) }

local rollStates = Enum and Enum.EncounterLootDropRollState
local rollButtons = rollStates and {
	NeedButton = { rollStates.NeedMainSpec, rollStates.NeedOffSpec },
	GreedButton = { rollStates.Greed },
	TransmogButton = { rollStates.Transmog },
	PassButton = { rollStates.Pass }
}
local alternateRollButton = { GreedButton = "TransmogButton", TransmogButton = "GreedButton" }
local rollBadges = {}
local IsSecret = issecretvalue or function() return false end

local IsReadable = function(value, valueType)
	return not IsSecret(value) and type(value) == valueType
end

AlertFrames.CanShowLootRollChoices = function()
	return rollButtons and C_LootHistory and C_LootHistory.GetAllEncounterInfos
		and C_LootHistory.GetSortedDropsForEncounter and C_LootHistory.GetLootHistoryTime
		and GetActiveLootRollIDs and GetLootRollItemLink
end

local UpdateRollBadge = function(frame, button, choice, alternate, alternateLabel)
	local badge = rollBadges[button]
	if (not badge and choice) then
		local count = button:CreateFontString(nil, "OVERLAY", nil, 7)
		-- Skinned cells draw a rim, so the count goes under the cell instead of
		-- on top of it (LootRollSkin.lua raises the cells to make room).
		local skinned = AlertFrames.IsLootRollSkinned and AlertFrames:IsLootRollSkinned(frame)
		if (skinned) then
			count:SetPoint("TOPRIGHT", button, "BOTTOMRIGHT", -2, 0)
		else
			count:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -1, 1)
		end
		count:SetFontObject(ns.API.GetFont(skinned and 11 or 12, true))
		count:SetTextColor(unpack(ns.Colors.highlight))
		badge = { count = count }
		rollBadges[button] = badge

		button:HookScript("OnEnter", function(self)
			if (not badge.names or IsSecret(frame.rollID) or badge.rollID ~= frame.rollID
				or not GameTooltip:IsOwned(self)) then return end
			for _, name in ipairs(badge.names) do
				GameTooltip:AddLine(name, 1, 1, 1)
			end
			if (badge.alternateNames and #badge.alternateNames > 0 and badge.alternateLabel) then
				GameTooltip:AddLine(badge.alternateLabel, unpack(ns.Colors.highlight))
				for _, name in ipairs(badge.alternateNames) do
					GameTooltip:AddLine(name, 1, 1, 1)
				end
			end
			if (#badge.names > 0 or badge.alternateNames and #badge.alternateNames > 0) then
				GameTooltip:Show()
			end
		end)
	end
	if (not badge) then return end

	badge.rollID = choice and frame.rollID
	badge.names = choice and choice.names
	badge.alternateNames = alternate and alternate.names
	badge.alternateLabel = alternateLabel
	if (choice) then
		badge.count:SetText(choice.count)
		badge.count:Show()
	else
		badge.count:Hide()
	end
end

local GetRollChoices = function(drop)
	if (not drop or not IsReadable(drop.rollInfos, "table")) then return end
	local choices, byState = {}, {}
	for key, states in pairs(rollButtons) do
		local choice = { count = 0, names = {} }
		choices[key] = choice
		for _, state in ipairs(states) do
			byState[state] = choice
		end
	end
	for _, roll in ipairs(drop.rollInfos) do
		if (not IsReadable(roll, "table") or not IsReadable(roll.state, "number")) then return end
		local choice = byState[roll.state]
		if (choice) then
			choice.count = choice.count + 1
			if (IsReadable(roll.playerName, "string") and roll.playerName ~= "") then
				choice.names[#choice.names + 1] = roll.playerName
			end
		end
	end
	return choices
end

AlertFrames.ApplyLootRollChoices = function(_, frame, choices)
	local buttons = frame.LootButtonContainer or frame
	for key in pairs(rollButtons) do
		local button = buttons[key]
		if (button) then
			local choice = choices and button:IsShown() and choices[key]
			-- Blizzard displays Greed or Transmog depending on the local player's eligibility.
			local alternateKey = alternateRollButton[key]
			local alternateButton = alternateKey and buttons[alternateKey]
			local alternate = choice and alternateButton and not alternateButton:IsShown() and choices[alternateKey]
			UpdateRollBadge(frame, button, choice, alternate, alternate and alternateButton.tooltipText)
		end
	end
end

local GetActiveDropsByLink = function(links)
	local dropsByLink = {}
	local now = C_LootHistory.GetLootHistoryTime()
	local encounters = C_LootHistory.GetAllEncounterInfos()
	if (not IsReadable(now, "number") or not IsReadable(encounters, "table")) then return dropsByLink end

	for _, encounter in ipairs(encounters) do
		if (not IsReadable(encounter, "table") or not IsReadable(encounter.encounterID, "number")) then return {} end
		local drops = C_LootHistory.GetSortedDropsForEncounter(encounter.encounterID)
		if (IsSecret(drops)) then return {} end
		for _, drop in ipairs(drops or {}) do
			if (not IsReadable(drop, "table") or not IsReadable(drop.itemHyperlink, "string")) then return {} end
			local link = drop.itemHyperlink
			if (links[link] == 1) then
				if (not IsReadable(drop.startTime, "number") or not IsReadable(drop.duration, "number")
					or IsSecret(drop.winner) or IsSecret(drop.allPassed)) then
					dropsByLink[link] = false
				elseif (not drop.winner and not drop.allPassed and now >= drop.startTime
					and now < drop.startTime + drop.duration) then
					-- History has no rollID. Any second live drop for this link makes the match ambiguous.
					dropsByLink[link] = dropsByLink[link] == nil and drop or false
				end
			end
		end
	end
	return dropsByLink
end

AlertFrames.RefreshLootRollChoices = function(self)
	local container = GroupLootContainer
	local frames = container.rollFrames
	local links, rollLinks = {}, {}
	local enabled = self.db.profile.showLootRollChoices and self:CanShowLootRollChoices()
	local haveVisibleRoll = enabled and container:IsVisible() and next(frames) ~= nil
	if (haveVisibleRoll) then
		local activeRolls = GetActiveLootRollIDs()
		if (IsReadable(activeRolls, "table")) then
			for _, rollID in ipairs(activeRolls) do
				if (not IsReadable(rollID, "number")) then
					links = {}
					break
				end
				local link = GetLootRollItemLink(rollID)
				if (not IsReadable(link, "string") or link == "") then
					links = {}
					break
				end
				rollLinks[rollID] = link
				links[link] = (links[link] or 0) + 1
			end
		end
	end
	local drops = next(links) and GetActiveDropsByLink(links) or {}
	for _, frame in pairs(frames) do
		local rollID = frame.rollID
		local drop = frame:IsShown() and IsReadable(rollID, "number") and drops[rollLinks[rollID]]
		self:ApplyLootRollChoices(frame, GetRollChoices(drop))
	end
end

AlertFrames.QueueLootRollRefresh = function(self)
	if (self.lootRollRefreshQueued or not self:CanShowLootRollChoices()
		or (not self.db.profile.showLootRollChoices and not next(rollBadges))) then return end
	self.lootRollRefreshQueued = true
	C_Timer.After(0, function()
		self.lootRollRefreshQueued = nil
		self:RefreshLootRollChoices()
	end)
end

-- Generate module defaults on the fly
-- to recalculate default values relying on
-- changing factors like user interface scale.
AlertFrames.GenerateDefaults = function(self)
	defaults.profile.savedPosition = {
		scale = ns.API.GetEffectiveScale(),
		[1] = "TOP",
		[2] = 0 * ns.API.GetEffectiveScale(),
		[3] = -40 * ns.API.GetEffectiveScale()
	}
	return defaults
end

local GetPoints = function()
	if (AlertFrames.db.profile.useAutomaticGrowth) then
		return unpack(points[AlertFrames.db.profile.savedPosition[1]])
	else
		return unpack(AlertFrames.db.profile.growUpwards and points.BOTTOM or points.TOP)
	end
end

AlertFrames.PlaceLootRollStack = function(self, stack)
	local point, relPoint, _, direction = GetPoints()
	stack:ClearAllPoints()
	stack:SetPoint(point, self.frame, relPoint, 0, ns.GetConfig("AlertFrames").AlertFramesPadding * direction)
	return point, relPoint, direction
end

local GroupLootContainer_PostUpdate = function(self)
	local config = ns.GetConfig("AlertFrames")
	local point, relPoint, x, y = GetPoints()

	local lastIdx = nil
	local compactHeight, compactRows, rows = 0, 0, 0
	local lastFrame
	local compactGap = AlertFrames.lootRollRowGap
	for i = 1, self.maxIndex do
		local frame = self.rollFrames[i]
		local prevFrame = self.rollFrames[i-1]
		if (frame) then
			local compact = AlertFrames:IsLootRollSkinned(frame)
			frame:ClearAllPoints()
			if (compact and lastFrame) then
				local gap = AlertFrames:IsLootRollSkinned(lastFrame) and compactGap or config.AlertFramesPadding
				frame:SetPoint(point, lastFrame, relPoint, 0, gap * y)
			elseif (prevFrame and prevFrame ~= frame) then
				frame:SetPoint(point, prevFrame, relPoint, 0, config.AlertFramesPadding * y)
			else
				frame:SetPoint(point, self, point, 0, 0)
			end
			if (compact) then
				compactRows = compactRows + 1
				compactHeight = compactHeight + frame:GetHeight()
			end
			rows = rows + 1
			lastFrame = frame
			lastIdx = i
		end
	end
	if (lastIdx) then
		self:SetHeight(compactRows == rows and compactHeight + (rows - 1) * compactGap or self.reservedSize * lastIdx)
		self:Show()
	else
		self:Hide()
	end
	AlertFrames:QueueLootRollRefresh()
	AlertFrames:UpdateLootRollLayoutPreviewVisibility()
end

local AlertSubSystem_AdjustAnchors = function(self, relativeAlert)
	local config = ns.GetConfig("AlertFrames")
	local point, relPoint, x, y = GetPoints()

	local alertFrame = self.alertFrame
	if (alertFrame and alertFrame:IsShown()) then
		alertFrame:ClearAllPoints()
		alertFrame:SetPoint(point, relativeAlert, relPoint, 0, config.AlertFramesPadding * y)
		return alertFrame
	end
	return relativeAlert
end

local AlertSubSystem_AdjustAnchorsNonAlert = function(self, relativeAlert)
	local config = ns.GetConfig("AlertFrames")
	local point, relPoint, x, y = GetPoints()

	local anchorFrame = self.anchorFrame

	if (anchorFrame and ns.WoW11 and anchorFrame == TalkingHeadFrame) then
		return relativeAlert
	end

	if (anchorFrame and anchorFrame:IsShown()) then
		anchorFrame:ClearAllPoints()
		anchorFrame:SetPoint(point, relativeAlert, relPoint, 0, config.AlertFramesPadding * y)
		return anchorFrame
	end
	return relativeAlert
end

local AlertSubSystem_AdjustQueuedAnchors = function(self, relativeAlert)
	local config = ns.GetConfig("AlertFrames")
	local point, relPoint, x, y = GetPoints()

	for alertFrame in self.alertFramePool:EnumerateActive() do
		alertFrame:ClearAllPoints()
		alertFrame:SetPoint(point, relativeAlert, relPoint, 0, config.AlertFramesPadding * y)
		relativeAlert = alertFrame
	end
	return relativeAlert
end

local AlertSubSystem_AdjustAllPositions = function()
	-- Blizzard calls each subsystem's AdjustAnchors from its own update path.
	-- Apply our spacing after that pass without replacing any native method.
	local relative = AlertFrame.baseAnchorFrame or AlertFrame
	for _, system in ipairs(AlertFrame.alertFrameSubSystems) do
		local frame
		if (system.alertFramePool) then
			frame = AlertSubSystem_AdjustQueuedAnchors(system, relative)
		elseif (system.anchorFrame) then
			frame = AlertSubSystem_AdjustAnchorsNonAlert(system, relative)
		else
			frame = AlertSubSystem_AdjustAnchors(system, relative)
		end
		if (frame ~= relative and (not frame.IsInDefaultPosition or frame:IsInDefaultPosition())) then
			relative = frame
		end
	end
end

local AlertFrame_PostUpdateAnchors = function()
	local AlertFrameHolder = _G[ns.Prefix.."AlertFrameHolder"]

	AlertFrameHolder:ClearAllPoints()
	AlertFrameHolder:SetPoint(unpack(AlertFrames.db.profile.savedPosition))

	AlertFrame:ClearAllPoints()
	AlertFrame:SetAllPoints(AlertFrameHolder)

	AlertSubSystem_AdjustAllPositions()
	AlertFrames:PlaceLootRollStack(GroupLootContainer)
	AlertFrames:UpdateLootRollLayoutPreviewPosition()

	if (GroupLootContainer:IsShown()) then
		GroupLootContainer_PostUpdate(GroupLootContainer)
	end
end

AlertFrames.PostUpdatePositionAndScale = function(self)
	AlertFrame_PostUpdateAnchors()
	self:QueueLootRollRefresh()
end

AlertFrames.PrepareFrames = function(self)

	local config = ns.GetConfig("AlertFrames")

	local frame = CreateFrame("Frame", ns.Prefix.."AlertFrameHolder", UIParent)
	frame:SetSize(unpack(config.AlertFramesSize))
	frame:SetPoint(unpack(AlertFrames.db.profile.savedPosition))

	self.frame = frame

	--if (not ns.IsRetail) then
	--	AlertFrame.ignoreFramePositionManager = true
	--	AlertFrame:SetParent(UIParent)
	--	AlertFrame:OnLoad()
	--end
	--AlertSubSystem_AdjustAllPositions()

	GroupLootContainer.ignoreFramePositionManager = true

	if (not ns.IsRetail) then
		UIPARENT_MANAGED_FRAME_POSITIONS["GroupLootContainer"] = nil
	end

	self:SecureHook(AlertFrame, "UpdateAnchors", AlertFrame_PostUpdateAnchors)
	self:SecureHook("GroupLootContainer_Update", GroupLootContainer_PostUpdate)
end

AlertFrames.OnEnable = function(self)
	self:PrepareFrames()
	self:PrepareLootRollSkin()
	self:CreateAnchor(L["Alerts"])
	self.anchor:SetScalable(false)
	self:PrepareLootRollLayoutPreview()

	ns.MovableModulePrototype.OnEnable(self)

	if (self:CanShowLootRollChoices()) then
		self:RegisterEvent("START_LOOT_ROLL", "QueueLootRollRefresh")
		self:RegisterEvent("LOOT_HISTORY_UPDATE_DROP", "QueueLootRollRefresh")
		self:RegisterEvent("LOOT_HISTORY_UPDATE_ENCOUNTER", "QueueLootRollRefresh")
		self:RegisterEvent("LOOT_HISTORY_CLEAR_HISTORY", "QueueLootRollRefresh")
	end
end
