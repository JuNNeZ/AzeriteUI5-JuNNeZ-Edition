--[[

	The MIT License (MIT)

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

--[[
	Mythic+: a key timer with the +3 and +2 marks, an enemy forces bar, a card when
	the key ends, and the keystone slotted into the Font of Power by itself.

	Everything here is read the way Blizzard's own challenge block reads it
	(Blizzard_ScenarioObjectiveTracker.lua, ScenarioTimerMixin and
	ScenarioObjectiveTrackerChallengeModeMixin): the time from the world timer, the
	limit from the map, deaths from GetDeathCount, forces from the weighted scenario
	criterion. None of these calls documents a secret return, so this is ordinary
	arithmetic. The values are still checked with issecretvalue before any of it, so a
	future client that starts hiding them blanks a line instead of raising an error.

	Forever has the API files but no Mythic+ content, so this is Retail only.
]]
if (not ns.IsRetailContent) then return end

local ChallengeMode = C_ChallengeMode
if (not ChallengeMode or not ChallengeMode.GetActiveChallengeMapID or not GetWorldElapsedTime) then return end

local L = LibStub("AceLocale-3.0"):GetLocale((...))

local MythicPlus = ns:NewModule("MythicPlus", ns.MovableModulePrototype, "LibMoreEvents-1.0", "AceTimer-3.0")

-- Lua API
local math_floor = math.floor
local math_max = math.max
local math_min = math.min
local select = select
local string_format = string.format
local tonumber = tonumber
local type = type
local unpack = unpack

-- Addon API
local Colors = ns.Colors
local GetFont = ns.API.GetFont
local GetMedia = ns.API.GetMedia

-- The share of the time limit a key may take and still go up three or two levels.
local PLUS_THREE = .6
local PLUS_TWO = .8

local FRAME_WIDTH = 260
local BAR_WIDTH, BAR_HEIGHT = 220, 12
local UPDATE_INTERVAL = .25
local CARD_DURATION = 30

local defaults = { profile = ns:Merge({
	enabled = true,
	showTimer = true,
	showForces = true,
	showCompletionCard = true,
	autoSlotKeystone = true
}, ns.MovableModulePrototype.defaults) }

MythicPlus.GenerateDefaults = function(self)
	defaults.profile.savedPosition = {
		scale = ns.API.GetEffectiveScale(),
		[1] = "TOPRIGHT",
		[2] = -60 * ns.API.GetEffectiveScale(),
		[3] = -280 * ns.API.GetEffectiveScale()
	}
	return defaults
end

local IsSecret = function(value)
	return type(issecretvalue) == "function" and issecretvalue(value)
end

-- A plain number, or nil for anything else, secret values included.
local Number = function(value)
	if (IsSecret(value) or type(value) ~= "number") then return nil end
	return value
end

local FormatTime = function(seconds)
	seconds = math_max(0, math_floor(seconds))
	if (SecondsToClock) then
		return SecondsToClock(seconds, seconds >= 3600)
	end
	return string_format("%d:%02d", math_floor(seconds / 60), seconds % 60)
end

-- A bar in the mirror timer's dress: cast_bar over a cast_back casing, at the same
-- proportions as Layouts/Data/MirrorTimers.lua (a 111 x 12 bar in a 193 x 93 casing).
local CreateBar = function(parent)
	local bar = CreateFrame("StatusBar", nil, parent)
	bar:SetSize(BAR_WIDTH, BAR_HEIGHT)
	bar:SetStatusBarTexture(GetMedia("cast_bar"))
	bar:SetMinMaxValues(0, 1)
	bar:SetValue(0)

	local backdrop = bar:CreateTexture(nil, "BACKGROUND", nil, -6)
	backdrop:SetSize(BAR_WIDTH * 193 / 111, 93)
	backdrop:SetPoint("CENTER", 1, -2)
	backdrop:SetTexture(GetMedia("cast_back"))
	backdrop:SetVertexColor(unpack(Colors.ui))
	bar.backdrop = backdrop

	local label = bar:CreateFontString(nil, "OVERLAY", nil, 6)
	label:SetFontObject(GetFont(13, true))
	label:SetTextColor(unpack(Colors.offwhite))
	label:SetPoint("CENTER", 0, 0)
	bar.label = label

	return bar
end

-- A mark across the timer bar where one of the upgrade levels runs out.
local CreateMark = function(bar, fraction, text)
	local mark = bar:CreateTexture(nil, "OVERLAY", nil, 2)
	mark:SetColorTexture(unpack(Colors.title))
	mark:SetSize(2, BAR_HEIGHT + 4)
	mark:SetPoint("CENTER", bar, "LEFT", BAR_WIDTH * fraction, 0)

	local label = bar:CreateFontString(nil, "OVERLAY", nil, 6)
	label:SetFontObject(GetFont(11, true))
	label:SetTextColor(unpack(Colors.title))
	label:SetPoint("BOTTOM", mark, "TOP", 0, 1)
	label:SetText(text)

	mark.label = label
	return mark
end

MythicPlus.PrepareFrames = function(self)
	if (self.frame) then return end

	local frame = CreateFrame("Frame", ns.Prefix .. "MythicPlusTimer", UIParent)
	frame:SetSize(FRAME_WIDTH, 110)
	frame:SetFrameStrata("LOW")
	frame:Hide()

	local title = frame:CreateFontString(nil, "OVERLAY")
	title:SetFontObject(GetFont(15, true))
	title:SetTextColor(unpack(Colors.title))
	title:SetPoint("TOPLEFT", 0, 0)
	title:SetPoint("TOPRIGHT", -70, 0)
	title:SetJustifyH("LEFT")
	title:SetWordWrap(false)
	frame.title = title

	local deaths = frame:CreateFontString(nil, "OVERLAY")
	deaths:SetFontObject(GetFont(13, true))
	deaths:SetTextColor(unpack(Colors.offwhite))
	deaths:SetPoint("TOPRIGHT", 0, -1)
	deaths:SetJustifyH("RIGHT")
	frame.deaths = deaths

	local timer = CreateBar(frame)
	timer:SetPoint("TOP", frame, "TOP", 0, -36)
	timer.plusThree = CreateMark(timer, PLUS_THREE, "+3")
	timer.plusTwo = CreateMark(timer, PLUS_TWO, "+2")
	frame.timer = timer

	local nextLevel = frame:CreateFontString(nil, "OVERLAY")
	nextLevel:SetFontObject(GetFont(12, true))
	nextLevel:SetPoint("TOP", timer, "BOTTOM", 0, -6)
	frame.nextLevel = nextLevel

	local forces = CreateBar(frame)
	forces:SetPoint("TOP", timer, "BOTTOM", 0, -32)
	forces:SetStatusBarColor(unpack(Colors.normal))
	frame.forces = forces

	self.frame = frame
end

-- The completion card. It sits under the spot Blizzard's own banner uses, is not
-- movable, and goes away on a click or after CARD_DURATION seconds.
MythicPlus.PrepareCard = function(self)
	if (self.card) then return end

	local card = CreateFrame("Button", ns.Prefix .. "MythicPlusCard", UIParent, ns.BackdropTemplate)
	card:SetSize(340, 124)
	card:SetPoint("TOP", UIParent, "TOP", 0, -310)
	card:SetFrameStrata("MEDIUM")
	card:SetBackdrop({
		bgFile = [[Interface\Tooltips\UI-Tooltip-Background]],
		edgeFile = GetMedia("border-tooltip"),
		edgeSize = 24,
		insets = { left = 7, right = 7, top = 7, bottom = 7 }
	})
	card:SetBackdropColor(.05, .05, .05, .92)
	card:SetBackdropBorderColor(.35, .35, .35, .95)
	card:RegisterForClicks("AnyUp")
	card:SetScript("OnClick", function(button) button:Hide() end)
	card:Hide()

	local lines = {}
	local fonts = { 16, 14, 13, 13, 12 }
	for index, size in ipairs(fonts) do
		local line = card:CreateFontString(nil, "OVERLAY")
		line:SetFontObject(GetFont(size, true))
		line:SetJustifyH("CENTER")
		line:SetWordWrap(false)
		line:SetWidth(310)
		if (index == 1) then
			line:SetPoint("TOP", 0, -18)
		else
			line:SetPoint("TOP", lines[index - 1], "BOTTOM", 0, -6)
		end
		lines[index] = line
	end
	card.lines = lines

	self.card = card
end

-------------------------------------------------------------------------------
-- The running key
-------------------------------------------------------------------------------

-- The active key's world timer, the way ScenarioTimerMixin:CheckTimers finds it.
local FindChallengeTimer = function()
	if (not GetWorldElapsedTimers) then return end
	local timerType = Enum.WorldElapsedTimerTypes and Enum.WorldElapsedTimerTypes.ChallengeMode
	if (not timerType) then return end

	local timers = { GetWorldElapsedTimers() }
	for _, timerID in ipairs(timers) do
		local _, _, kind = GetWorldElapsedTime(timerID)
		if (kind == timerType) then
			return timerID
		end
	end
end

MythicPlus.CheckTimers = function(self)
	local timerID = FindChallengeTimer()
	local mapID = timerID and Number(ChallengeMode.GetActiveChallengeMapID())

	if (not mapID) then
		-- A finished key keeps its final time on screen until you leave.
		if (not self.completed) then
			self:Deactivate()
		end
		return
	end

	local name, _, timeLimit = ChallengeMode.GetMapUIInfo(mapID)
	local level = ChallengeMode.GetActiveKeystoneInfo and Number((ChallengeMode.GetActiveKeystoneInfo()))

	self.timerID = timerID
	self.timeLimit = Number(timeLimit)
	self.completed = nil
	self.frame.title:SetText(level and string_format("+%d  %s", level, name or "") or (name or ""))

	self:UpdateDeaths()
	self:UpdateForces()
	self:UpdateTime()
	self:UpdateVisibility()

	if (not self.ticker) then
		self.ticker = self:ScheduleRepeatingTimer("UpdateTime", UPDATE_INTERVAL)
	end
end

MythicPlus.Deactivate = function(self)
	self.timerID = nil
	self.timeLimit = nil
	self.completed = nil
	if (self.ticker) then
		self:CancelTimer(self.ticker)
		self.ticker = nil
	end
	self:UpdateVisibility()
end

MythicPlus.UpdateTime = function(self)
	if (not self.timerID or self.completed) then return end

	local timer = self.frame.timer
	local limit = self.timeLimit
	local elapsed = Number(select(2, GetWorldElapsedTime(self.timerID)))
	if (not elapsed or not limit or limit <= 0) then
		timer:SetValue(0)
		timer.label:SetText(elapsed and FormatTime(elapsed) or "")
		self.frame.nextLevel:SetText("")
		return
	end

	local color, nextText, nextColor
	if (elapsed < limit * PLUS_THREE) then
		color, nextText, nextColor = Colors.quest.green, "+3  " .. FormatTime(limit * PLUS_THREE - elapsed), Colors.quest.green
	elseif (elapsed < limit * PLUS_TWO) then
		color, nextText, nextColor = Colors.quest.yellow, "+2  " .. FormatTime(limit * PLUS_TWO - elapsed), Colors.quest.yellow
	elseif (elapsed < limit) then
		color, nextText, nextColor = Colors.quest.orange, "+1  " .. FormatTime(limit - elapsed), Colors.quest.orange
	else
		color, nextText, nextColor = Colors.quest.red, "-" .. FormatTime(elapsed - limit), Colors.quest.red
	end

	timer:SetStatusBarColor(unpack(color))
	timer:SetValue(math_min(1, elapsed / limit))
	timer.label:SetText(FormatTime(elapsed) .. " / " .. FormatTime(limit))
	self.frame.nextLevel:SetTextColor(unpack(nextColor))
	self.frame.nextLevel:SetText(nextText)
end

MythicPlus.UpdateDeaths = function(self)
	local deaths = self.frame.deaths
	local count, timeLost = ChallengeMode.GetDeathCount()
	count, timeLost = Number(count), Number(timeLost)
	if (not count or count <= 0) then
		deaths:SetText("")
		return
	end
	local text = CHALLENGE_MODE_DEATH_COUNT_TITLE and string_format(CHALLENGE_MODE_DEATH_COUNT_TITLE, count) or tostring(count)
	if (timeLost and timeLost > 0) then
		text = text .. " |cff888888(-" .. FormatTime(timeLost) .. ")|r"
	end
	deaths:SetText(text)
end

-- Enemy forces are the scenario step's weighted criterion. Its quantityString holds the
-- raw count with a percent sign after it, and totalQuantity the count needed; quantity
-- is the rounded percentage, used only when the string cannot be read.
local GetForces = function()
	if (not C_Scenario or not C_Scenario.GetStepInfo or not C_ScenarioInfo or not C_ScenarioInfo.GetCriteriaInfo) then return end

	local numCriteria = Number(select(3, C_Scenario.GetStepInfo()))
	if (not numCriteria) then return end

	for index = 1, numCriteria do
		local info = C_ScenarioInfo.GetCriteriaInfo(index)
		if (info and info.isWeightedProgress == true) then
			local total = Number(info.totalQuantity)
			local quantityString = info.quantityString
			local count = (not IsSecret(quantityString) and type(quantityString) == "string")
				and tonumber(quantityString:match("^%s*(%d+)")) or nil

			local fraction
			if (info.completed == true) then
				fraction = 1
			elseif (count and total and total > 0) then
				fraction = count / total
			elseif (Number(info.quantity)) then
				fraction = info.quantity / 100
			end
			local description = (not IsSecret(info.description)) and info.description or nil
			return fraction and math_min(1, fraction), description, count, total
		end
	end
end

MythicPlus.UpdateForces = function(self)
	local forces = self.frame.forces
	local fraction, description, count, total = GetForces()
	if (not fraction) then
		forces:SetValue(0)
		forces.label:SetText(description or "")
		return
	end
	forces:SetValue(fraction)
	forces:SetStatusBarColor(unpack(fraction >= 1 and Colors.quest.green or Colors.normal))

	local text = string_format("%s  %.1f%%", description or "", fraction * 100)
	if (count and total and fraction < 1) then
		text = text .. string_format(" |cff888888(%d/%d)|r", count, total)
	end
	forces.label:SetText(text)
end

MythicPlus.UpdateVisibility = function(self)
	local frame = self.frame
	if (not frame) then return end

	local db = self.db.profile
	local active = self.timerID and (db.showTimer or db.showForces)

	frame.title:SetShown(db.showTimer)
	frame.deaths:SetShown(db.showTimer)
	frame.timer:SetShown(db.showTimer)
	frame.nextLevel:SetShown(db.showTimer)
	frame.forces:SetShown(db.showForces)

	frame.forces:ClearAllPoints()
	if (db.showTimer) then
		frame.forces:SetPoint("TOP", frame.timer, "BOTTOM", 0, -32)
	else
		frame.forces:SetPoint("TOP", frame, "TOP", 0, -8)
	end

	frame:SetShown(active and true or false)
end

-------------------------------------------------------------------------------
-- The end of the key
-------------------------------------------------------------------------------

MythicPlus.ShowCompletionCard = function(self)
	if (not self.db.profile.showCompletionCard or not ChallengeMode.GetChallengeCompletionInfo) then return end

	local info = ChallengeMode.GetChallengeCompletionInfo()
	if (type(info) ~= "table" or info.practiceRun == true) then return end

	local mapID, level, time = Number(info.mapChallengeModeID), Number(info.level), Number(info.time)
	if (not mapID or not time) then return end

	self:PrepareCard()
	local card, lines = self.card, self.card.lines

	local name, _, timeLimit = ChallengeMode.GetMapUIInfo(mapID)
	local seconds = time / 1000
	timeLimit = Number(timeLimit)

	lines[1]:SetTextColor(unpack(Colors.title))
	lines[1]:SetText(level and string_format("+%d  %s", level, name or "") or (name or ""))

	local timeText = FormatTime(seconds)
	if (timeLimit) then
		timeText = timeText .. " |cff888888/ " .. FormatTime(timeLimit) .. "|r"
	end
	lines[2]:SetTextColor(unpack(Colors.offwhite))
	lines[2]:SetText(timeText)

	local upgrades = Number(info.keystoneUpgradeLevels)
	if (info.onTime == true) then
		lines[3]:SetTextColor(unpack(Colors.quest.green))
		if (upgrades and upgrades > 0 and CHALLENGE_MODE_COMPLETE_KEYSTONE_UPGRADED) then
			lines[3]:SetText(string_format(CHALLENGE_MODE_COMPLETE_KEYSTONE_UPGRADED, upgrades))
		else
			lines[3]:SetText(CHALLENGE_MODE_COMPLETE_BEAT_TIMER or "")
		end
	else
		lines[3]:SetTextColor(unpack(Colors.quest.red))
		lines[3]:SetText(CHALLENGE_MODE_COMPLETE_TIME_EXPIRED or "")
	end

	-- The rating line, as ChallengeModeCompleteBannerMixin:PlayBanner builds it.
	local old, new = Number(info.oldOverallDungeonScore), Number(info.newOverallDungeonScore)
	if (info.isEligibleForScore == true and old and new
		and CHALLENGE_COMPLETE_DUNGEON_SCORE and CHALLENGE_COMPLETE_DUNGEON_SCORE_FORMAT_TEXT) then
		local color = ChallengeMode.GetDungeonScoreRarityColor and ChallengeMode.GetDungeonScoreRarityColor(new)
		local score = CHALLENGE_COMPLETE_DUNGEON_SCORE_FORMAT_TEXT:format(new, new - old)
		if (color and color.WrapTextInColorCode) then
			score = color:WrapTextInColorCode(score)
		end
		lines[4]:SetTextColor(unpack(Colors.offwhite))
		lines[4]:SetText(CHALLENGE_COMPLETE_DUNGEON_SCORE:format(score))
	else
		lines[4]:SetText("")
	end

	if (info.isMapRecord == true) then
		lines[5]:SetTextColor(unpack(Colors.normal))
		lines[5]:SetText(L["New best time for this dungeon"])
	else
		lines[5]:SetText("")
	end

	card:Show()
	if (self.cardTimer) then
		self:CancelTimer(self.cardTimer)
	end
	self.cardTimer = self:ScheduleTimer(function()
		self.cardTimer = nil
		card:Hide()
	end, CARD_DURATION)
end

-------------------------------------------------------------------------------
-- The Font of Power
-------------------------------------------------------------------------------

-- Puts the keystone in the way dragging it there would (Blizzard_ChallengesUI.lua,
-- ChallengesKeystoneSlotMixin:OnReceiveDrag). The font cannot be opened in combat and
-- none of these calls are protected.
local FindKeystone = function()
	local container, item = C_Container, C_Item
	if (not container or not item or not item.IsItemKeystoneByID) then return end

	for bag = 0, NUM_BAG_SLOTS or 4 do
		for slot = 1, container.GetContainerNumSlots(bag) or 0 do
			local itemID = container.GetContainerItemID(bag, slot)
			if (type(itemID) == "number" and item.IsItemKeystoneByID(itemID)) then
				return bag, slot
			end
		end
	end
end

MythicPlus.SlotKeystone = function(self)
	if (not self.db.profile.autoSlotKeystone or not ChallengeMode.SlotKeystone) then return end
	if (InCombatLockdown() or CursorHasItem()) then return end
	if (ChallengeMode.HasSlottedKeystone and ChallengeMode.HasSlottedKeystone()) then return end

	local bag, slot = FindKeystone()
	if (not bag) then return end

	C_Container.PickupContainerItem(bag, slot)
	if (CursorHasItem()) then
		ChallengeMode.SlotKeystone()
	end
	-- Never leave the key on the cursor if the font turned it down.
	if (CursorHasItem()) then
		ClearCursor()
	end
end

-------------------------------------------------------------------------------
-- Module
-------------------------------------------------------------------------------

MythicPlus.OnEvent = function(self, event, ...)
	if (event == "CHALLENGE_MODE_KEYSTONE_RECEPTABLE_OPEN") then
		self:SlotKeystone()

	elseif (event == "CHALLENGE_MODE_DEATH_COUNT_UPDATED") then
		if (self.timerID) then self:UpdateDeaths() end

	elseif (event == "SCENARIO_CRITERIA_UPDATE" or event == "SCENARIO_POI_UPDATE") then
		if (self.timerID) then self:UpdateForces() end

	elseif (event == "CHALLENGE_MODE_COMPLETED") then
		if (self.timerID) then
			self:UpdateTime()
			self:UpdateForces()
			self.completed = true
		end
		self:ShowCompletionCard()

	elseif (event == "CHALLENGE_MODE_RESET" or event == "PLAYER_ENTERING_WORLD") then
		self.completed = nil
		self:CheckTimers()

	else
		-- CHALLENGE_MODE_START, WORLD_STATE_TIMER_START, WORLD_STATE_TIMER_STOP
		self:CheckTimers()
	end
end

MythicPlus.UpdateSettings = function(self)
	self:UpdateVisibility()
end

MythicPlus.OnEnable = function(self)
	self:PrepareFrames()
	self:CreateAnchor(L["Mythic+"])

	ns.MovableModulePrototype.OnEnable(self)

	for _, event in ipairs({
		"CHALLENGE_MODE_KEYSTONE_RECEPTABLE_OPEN",
		"CHALLENGE_MODE_START",
		"CHALLENGE_MODE_COMPLETED",
		"CHALLENGE_MODE_RESET",
		"CHALLENGE_MODE_DEATH_COUNT_UPDATED",
		"WORLD_STATE_TIMER_START",
		"WORLD_STATE_TIMER_STOP",
		"SCENARIO_CRITERIA_UPDATE",
		"SCENARIO_POI_UPDATE",
		"PLAYER_ENTERING_WORLD"
	}) do
		if (ns.API.IsEventAvailable(event)) then
			self:RegisterEvent(event, "OnEvent")
		end
	end

	self:CheckTimers()
end
