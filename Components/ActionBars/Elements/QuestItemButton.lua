--[[

	The MIT License (MIT)

	Copyright (c) 2026 Jonas "JuNNeZ" Andersen (JuNNeZ Edition)

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

	Quest Item Button: one movable button, styled as our extra action button,
	that holds the usable item of the nearest quest. The selection rules and the
	quest item tables (QuestItemData.lua) are sampled from p3lim's quest item
	button addon. Changed from it:
	- no HereBeDragons: quest areas measure through C_Map world positions, and the
	  maximum distance applies to them too (the source took a square root of an
	  already linear distance, so every listed area counted as close by);
	- "tracked quests only" means tracked quests (the source's switch did the
	  opposite and added the whole quest log);
	- the item, its icon and the click target change together, after combat,
	  so the button never shows one item and uses another;
	- events are gathered into one scan, and the two second timer only runs
	  while a quest item is in the bags at all;
	- a Blizzard extra action button only takes the shared key back, it does not
	  hide this button; keys follow ActionButtonUseKeyDown;
	- /kb, Quick Keybind Mode and gamepad glyphs, as on our bars, and the quest
	  the item belongs to in the tooltip.

--]]
local Addon, ns = ...

local L = LibStub("AceLocale-3.0"):GetLocale(Addon)

local QuestItem = ns:NewModule("QuestItemButton", ns.MovableModulePrototype, "LibMoreEvents-1.0", "AceHook-3.0")

-- GLOBALS: C_Item, C_Map, C_QuestLog, C_SuperTrack, C_Secrets, C_UnitAuras, C_Timer
-- GLOBALS: CreateFrame, CreateVector2D, GameTooltip, GameTooltip_SetDefaultAnchor
-- GLOBALS: GetBindingKey, GetQuestLogSpecialItemInfo, InCombatLockdown, QuestHasPOIInfo
-- GLOBALS: RegisterStateDriver, UnregisterStateDriver, UIParent, UnitCreatureID, UnitExists, UnitGUID

-- Lua API
local math_sqrt = math.sqrt
local next = next
local string_match = string.match
local tonumber = tonumber
local type = type
local unpack = unpack
local wipe = table.wipe

local RIVAL = "ExtraQuestButton"
local SCAN_DELAY = .1
local TICK = 2
local RANGE_TICK = .2
local PLACEHOLDER_ICON = [[Interface\Icons\INV_Misc_QuestionMark]]

local defaults = { profile = ns:Merge({
	enabled = true,
	trackedOnly = false,
	zoneOnly = false,
	maxDistance = 1000,
	useExtraActionKey = true,
	showQuestInTooltip = true
}, ns.MovableModulePrototype.defaults) }

QuestItem.GenerateDefaults = function(self)
	local scale = ns.API.GetEffectiveScale()
	-- Right of the screen centre, above the bars, clear of the extra action button.
	defaults.profile.savedPosition = { scale = scale, "BOTTOM", 230 * scale, 250 * scale }
	return defaults
end

-- Readers
--------------------------------------------
local IsSecret = function(value)
	return issecretvalue and issecretvalue(value) or false
end

local ReadNumber = function(value)
	if (type(value) ~= "number" or IsSecret(value)) then return end
	return value
end

local GetItemIDFromLink = function(link)
	if (type(link) ~= "string" or IsSecret(link)) then return end
	return tonumber(string_match(link, "item:(%d+)"))
end

local GetItemCount = function(item)
	if (not item or not C_Item or not C_Item.GetItemCount) then return 0 end
	return ReadNumber(C_Item.GetItemCount(item)) or 0
end

-- Item links for items we own. Unknown links are asked for once and picked up on
-- the next scan, which ITEM_DATA_LOAD_RESULT asks for.
local GetItemLinkFromID = function(itemID)
	if (not itemID or GetItemCount(itemID) == 0) then return end
	local _, link = C_Item.GetItemInfo(itemID)
	if (not link and C_Item.RequestLoadItemDataByID) then
		C_Item.RequestLoadItemDataByID(itemID)
	end
	return link
end

-- Quest selection (exposed as ns.QuestItemFinder for the harness)
--------------------------------------------
local Finder = {}
ns.QuestItemFinder = Finder

local byPriority, seen = {}, {}

-- Straight line yards between two points on maps of the same continent.
Finder.GetMapDistance = function(mapID, x, y, areaMapID, areaX, areaY)
	if (not C_Map or not C_Map.GetWorldPosFromMapPos or not CreateVector2D) then return end
	if (not mapID or not x or not y) then return end
	local c1, p1 = C_Map.GetWorldPosFromMapPos(mapID, CreateVector2D(x, y))
	local c2, p2 = C_Map.GetWorldPosFromMapPos(areaMapID, CreateVector2D(areaX, areaY))
	if (not c1 or not p1 or not p2 or c1 ~= c2) then return end
	local x1, y1 = p1:GetXY()
	local x2, y2 = p2:GetXY()
	local dx, dy = x1 - x2, y1 - y2
	return math_sqrt(dx*dx + dy*dy)
end

local MatchesMapList = function(area, mapID)
	local kind = type(area)
	if (kind == "boolean") then return area end
	if (kind == "number") then return area == mapID end
	if (kind == "table") then
		for _, id in next, area do
			if (id == mapID) then return true end
		end
	end
	return false
end

-- Yards to the quest, or nil when it is farther than maxDistance or unknown.
Finder.GetQuestDistance = function(data, questID, maxDistance, mapID, x, y)
	local distanceSq = C_QuestLog.GetDistanceSqToQuest and ReadNumber((C_QuestLog.GetDistanceSqToQuest(questID)))
	if (distanceSq) then
		local distance = math_sqrt(distanceSq)
		if (distance <= maxDistance) then return distance end
	end

	local area = data.accurateQuestAreas[questID]
	if (area) then
		local distance = Finder.GetMapDistance(mapID, x, y, area[1], area[2], area[3])
		if (distance and distance <= maxDistance) then return distance end
	end

	-- Areas without coordinates sort behind every measured distance.
	area = data.inaccurateQuestAreas[questID]
	if (area ~= nil) then
		if (type(area) == "boolean") then
			if (area) then return maxDistance - 1 end
		elseif (MatchesMapList(area, mapID)) then
			return maxDistance - 2
		end
	end
end

Finder.IsQuestOnMap = function(data, questID, mapID)
	if (C_QuestLog.IsOnMap and C_QuestLog.IsOnMap(questID)) then return true end
	local area = data.accurateQuestAreas[questID]
	if (area and area[1] == mapID) then return true end
	area = data.inaccurateQuestAreas[questID]
	return area ~= nil and MatchesMapList(area, mapID) or false
end

-- The quest's own item, or one from the tables, if it may be used right now.
Finder.GetValidItem = function(data, questID, mapID, link, itemID)
	local showWhenComplete
	if (not link) then
		local index = C_QuestLog.GetLogIndexForQuestID and C_QuestLog.GetLogIndexForQuestID(questID)
		if (not index or not GetQuestLogSpecialItemInfo) then return end
		local _
		link, _, _, showWhenComplete = GetQuestLogSpecialItemInfo(index)
		itemID = GetItemIDFromLink(link)
		if (not itemID) then return end
	end

	if (C_QuestLog.IsComplete and C_QuestLog.IsComplete(questID)) then
		local replacement = data.noCompleteItems[itemID]
		if (replacement) then
			if (type(replacement) ~= "number") then return end
			itemID = replacement
			link = GetItemLinkFromID(itemID)
			if (not link) then return end
		end
		local completeItem = data.completeItems[itemID]
		if (not showWhenComplete and not completeItem) then return end
		if (type(completeItem) == "number" and completeItem ~= mapID) then return end
	end

	if (GetItemCount(link) == 0 or data.itemBlacklist[itemID]) then return end

	return link, itemID
end

local Consider = function(data, questID, distance, mapID, link, itemID)
	link, itemID = Finder.GetValidItem(data, questID, mapID, link, itemID)
	if (not link) then return end

	-- An item in the bags for a quest is reason enough to keep checking distance.
	Finder.hasCandidates = true

	local priority = data.priorityItems[itemID]
	if (not distance and priority == nil) then return end
	priority = priority or 0

	local current = byPriority[priority]
	if (not current) then
		byPriority[priority] = { link, distance, questID }
	elseif (distance and (not current[2] or distance < current[2])) then
		current[1], current[2], current[3] = link, distance, questID
	end
end

local ConsiderDataItems = function(data, questID, distance, mapID)
	local entry = data.questItems[questID]
	if (not entry) then return end

	-- Technoscrying: the goggles are not needed while their aura is up.
	if (entry == 202247 and C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID
		and not (C_Secrets and C_Secrets.ShouldAurasBeSecret and C_Secrets.ShouldAurasBeSecret())) then
		if (C_UnitAuras.GetPlayerAuraBySpellID(409668) or C_UnitAuras.GetPlayerAuraBySpellID(414539)) then
			return
		end
	end

	if (type(entry) == "table") then
		for _, itemID in next, entry do
			local link = GetItemLinkFromID(itemID)
			if (link) then Consider(data, questID, distance, mapID, link, itemID) end
		end
	else
		local link = GetItemLinkFromID(entry)
		if (link) then Consider(data, questID, distance, mapID, link, entry) end
	end
end

-- unlocated: the quest has no map position anywhere (Deeprun Tram, old indoor
-- quests). Its item then sorts behind every quest with a position or an area.
local Process = function(data, questID, opts, mapID, x, y, superTracked, unlocated)
	if (not questID or seen[questID]) then return end
	seen[questID] = true

	if (opts.zoneOnly and not Finder.IsQuestOnMap(data, questID, mapID)) then return end

	local distance = Finder.GetQuestDistance(data, questID, opts.maxDistance, mapID, x, y)
	if (not distance and unlocated) then distance = opts.maxDistance end
	-- The quest the player follows on the map wins among items of equal priority.
	if (distance and questID == superTracked) then distance = -1 end

	Consider(data, questID, distance, mapID)
	ConsiderDataItems(data, questID, distance, mapID)
end

--- Returns itemLink, questID of the item to show, or nil.
--- opts: { maxDistance = yards, zoneOnly = bool, trackedOnly = bool }
--- Sets Finder.hasCandidates when any quest item is in the bags at all.
Finder.GetClosestQuestItem = function(opts, data)
	data = data or ns.QuestItemData
	wipe(seen)
	wipe(byPriority)
	Finder.hasCandidates = false
	if (not data or not C_QuestLog) then return end

	local mapID = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
	mapID = ReadNumber(mapID)
	local x, y
	if (mapID and C_Map.GetPlayerMapPosition) then
		local position = C_Map.GetPlayerMapPosition(mapID, "player")
		if (position) then x, y = position:GetXY() end
		x, y = ReadNumber(x), ReadNumber(y)
	end

	local superTracked = C_SuperTrack and C_SuperTrack.GetSuperTrackedQuestID and ReadNumber(C_SuperTrack.GetSuperTrackedQuestID())

	if (C_QuestLog.GetNumWorldQuestWatches) then
		for index = 1, C_QuestLog.GetNumWorldQuestWatches() do
			Process(data, C_QuestLog.GetQuestIDForWorldQuestWatchIndex(index), opts, mapID, x, y, superTracked)
		end
	end

	if (C_QuestLog.GetNumQuestWatches) then
		for index = 1, C_QuestLog.GetNumQuestWatches() do
			local questID = C_QuestLog.GetQuestIDForQuestWatchIndex(index)
			if (questID and (not QuestHasPOIInfo or QuestHasPOIInfo(questID))) then
				Process(data, questID, opts, mapID, x, y, superTracked)
			end
		end
	end

	-- World quests and bonus objectives are tracked by being there. Every other
	-- quest with something on the local map counts unless tracked only is on.
	local bonus = Enum and Enum.QuestClassification and Enum.QuestClassification.BonusObjective
	local unlocatedQuests
	for index = 1, C_QuestLog.GetNumQuestLogEntries() do
		local info = C_QuestLog.GetInfo(index)
		if (info and not info.isHeader and info.hasLocalPOI) then
			local questID = info.questID
			local areaTracked = (C_QuestLog.IsWorldQuest and C_QuestLog.IsWorldQuest(questID))
				or (bonus and info.questClassification == bonus)
			if (areaTracked or (not opts.trackedOnly and not info.isHidden)) then
				Process(data, questID, opts, mapID, x, y, superTracked)
			end
		elseif (info and not info.isHeader and not info.isHidden and info.questID
			and QuestHasPOIInfo and not QuestHasPOIInfo(info.questID)) then
			-- No position anywhere: handled last, so located quests win ties.
			if (not opts.trackedOnly or (C_QuestLog.GetQuestWatchType and C_QuestLog.GetQuestWatchType(info.questID))) then
				unlocatedQuests = unlocatedQuests or {}
				unlocatedQuests[#unlocatedQuests + 1] = info.questID
			end
		end
	end
	if (unlocatedQuests) then
		for _, questID in next, unlocatedQuests do
			Process(data, questID, opts, mapID, x, y, superTracked, true)
		end
	end

	local best, link, questID
	for priority, entry in next, byPriority do
		if (not best or priority > best) then
			best, link, questID = priority, entry[1], entry[3]
		end
	end
	return link, questID
end

-- Target items: some quest items are used on one kind of mob.
Finder.GetTargetItem = function(data)
	data = data or ns.QuestItemData
	if (not data or not UnitExists("target")) then return end
	local npcID
	if (UnitCreatureID) then
		npcID = ReadNumber(UnitCreatureID("target"))
	else
		local guid = UnitGUID("target")
		if (type(guid) == "string" and not IsSecret(guid)) then
			npcID = tonumber(string_match(guid, "^%a+%-%d+%-%d+%-%d+%-%d+%-(%d+)"))
		end
	end
	local itemID = npcID and data.targetItems[npcID]
	if (itemID) then return GetItemLinkFromID(itemID) end
end

-- Button
--------------------------------------------
-- Runs in the restricted environment: shows the button while it has an item (or
-- is forced on for binding), and lends it the extra action key while no extra
-- action bar wants that key. In combat this is the only thing that changes.
local ATTRIBUTE_HANDLER = [[
	if name ~= "item" and name ~= "forceshow" and name ~= "usefallback" and name ~= "state-visible" and name ~= "state-extrabar" then return end
	local item = self:GetAttribute("item")
	local visible = self:GetAttribute("state-visible") ~= "hide"
	if (item and visible) or self:GetAttribute("forceshow") then
		self:Show()
	else
		self:Hide()
	end
	self:ClearBindings()
	if item and visible and self:GetAttribute("usefallback") and self:GetAttribute("state-extrabar") ~= "on" then
		local key1, key2 = GetBindingKey("EXTRAACTIONBUTTON1")
		if key1 then self:SetBindingClick(true, key1, self, "LeftButton") end
		if key2 then self:SetBindingClick(true, key2, self, "LeftButton") end
	end
]]

local Button_OnEnter = function(self)
	local KeyBound = LibStub("LibKeyBound-1.0", true)
	if (KeyBound and KeyBound:IsShown()) then
		KeyBound:Set(self)
		return
	end
	if (GameTooltip:IsForbidden() or not self.itemLink) then return end
	GameTooltip_SetDefaultAnchor(GameTooltip, self)
	GameTooltip:SetHyperlink(self.itemLink)
	if (self.questID and QuestItem.db.profile.showQuestInTooltip and C_QuestLog.GetTitleForQuestID) then
		local title = C_QuestLog.GetTitleForQuestID(self.questID)
		if (type(title) == "string" and not IsSecret(title)) then
			GameTooltip:AddLine(" ")
			GameTooltip:AddLine(string.format(L["Quest: %s"], title), unpack(ns.Colors.offwhite or ns.Colors.normal))
		end
	end
	GameTooltip:Show()
end

local Button_OnLeave = function(self)
	if (GameTooltip:IsForbidden()) then return end
	GameTooltip:Hide()
end

local Button_UpdateChecked = function(self)
	local current = self.itemLink and C_Item.IsCurrentItem and C_Item.IsCurrentItem(self.itemLink)
	if (IsSecret(current)) then current = false end
	self:SetChecked(current and true or false)
end

-- Out of range turns the key red. C_Item.IsItemInRange is restricted in combat,
-- so the colour then holds what it last was.
local Button_OnUpdate = function(self, elapsed)
	self.rangeElapsed = (self.rangeElapsed or 0) + elapsed
	if (self.rangeElapsed < RANGE_TICK) then return end
	self.rangeElapsed = 0
	if (InCombatLockdown() or not self.itemLink) then return end
	local inRange = C_Item.IsItemInRange(self.itemLink, "target")
	if (IsSecret(inRange)) then inRange = nil end
	local color = (inRange == false) and ns.Colors.red or self.hotkeyColor
	self.HotKey:SetTextColor(color[1], color[2], color[3], color[4] or 1)
end

-- LibKeyBound targets. The default binder binds "CLICK <name>:LeftButton".
local Button_GetActionName = function(self) return L["Quest Item Button"] end
local Button_GetHotkey = function(self) return QuestItem:GetHotkeyText() end

QuestItem.GetClickBinding = function(self)
	return "CLICK "..self.button:GetName()..":LeftButton"
end

-- Our own key first, then the extra action key we borrow, as on the bars: a
-- keyboard key as it is, a gamepad key as its glyph.
QuestItem.GetHotkeyText = function(self)
	local LAB = LibStub("LibActionButton-1.0-GE", true)
	local pick = (LAB and LAB.PickHotkey) or function(key) return key end
	local key = pick(GetBindingKey(self:GetClickBinding()))
	if (not key and self.db.profile.useExtraActionKey) then
		key = pick(GetBindingKey("EXTRAACTIONBUTTON1"))
	end
	if (not key) then return "" end
	if (LAB and LAB.IsGamePadKey and LAB.IsGamePadKey(key) and LAB.GetHotkeyText) then
		return LAB.GetHotkeyText(key)
	end
	return key
end

QuestItem.CreateButton = function(self)
	if (self.button) then return self.button end

	local bars = ns:GetModule("ActionBars", true)
	local shape = bars and bars.db and bars.db.profile and bars.db.profile.extraButtonShape
	local db = ns.API.GetShapedButtonConfig(ns.GetConfig("ExtraActionButton"), shape)
	local mask = db.ExtraButtonMask

	local button = CreateFrame("CheckButton", ns.Prefix.."QuestItemButton", UIParent, "SecureActionButtonTemplate, SecureHandlerStateTemplate, SecureHandlerAttributeTemplate")
	button:Hide()
	button:SetSize(unpack(db.ExtraButtonSize))
	button:SetFrameStrata("MEDIUM")
	button:SetFrameLevel(10)
	button:SetClampedToScreen(true)
	button:SetAttribute("type", "item")
	-- SecureActionButton acts on one of the two, following ActionButtonUseKeyDown.
	button:RegisterForClicks("AnyUp", "AnyDown")
	button:SetScript("OnEnter", Button_OnEnter)
	button:SetScript("OnLeave", Button_OnLeave)
	button:SetScript("PostClick", Button_UpdateChecked)
	button.GetActionName = Button_GetActionName
	button.GetHotkey = Button_GetHotkey

	local icon = button:CreateTexture(nil, "BACKGROUND", nil, 1)
	icon:SetPoint(unpack(db.ExtraButtonIconPosition))
	icon:SetSize(unpack(db.ExtraButtonIconSize))
	icon:SetMask(mask)
	button.Icon = icon

	local highlight = button:CreateTexture(nil, "BACKGROUND", nil, 2)
	highlight:SetAllPoints(icon)
	highlight:SetTexture(mask)
	highlight:SetVertexColor(1, 1, 1, .1)
	button:SetHighlightTexture(highlight)

	local checked = button:CreateTexture(nil, "BACKGROUND", nil, 3)
	checked:SetAllPoints(icon)
	checked:SetTexture(mask)
	checked:SetVertexColor(ns.Colors.highlight[1], ns.Colors.highlight[2], ns.Colors.highlight[3], .25)
	button:SetCheckedTexture(checked)

	local cooldown = CreateFrame("Cooldown", nil, button, "CooldownFrameTemplate")
	cooldown:SetFrameLevel(button:GetFrameLevel() + 1)
	cooldown:SetSize(unpack(db.ExtraButtonCooldownSize))
	cooldown:SetPoint(unpack(db.ExtraButtonCooldownPosition))
	cooldown:SetReverse(false)
	cooldown:SetSwipeTexture(mask)
	cooldown:SetSwipeColor(unpack(db.ExtraButtonCooldownColor))
	cooldown:SetDrawSwipe(true)
	cooldown:SetBlingTexture("", 0, 0, 0, 0)
	cooldown:SetDrawBling(false)
	cooldown:SetEdgeTexture("")
	cooldown:SetDrawEdge(false)
	cooldown:SetHideCountdownNumbers(true)
	button.Cooldown = cooldown

	local overlay = CreateFrame("Frame", nil, button)
	overlay:SetFrameLevel(button:GetFrameLevel() + 3)
	overlay:SetAllPoints()
	button.overlay = overlay

	local border = overlay:CreateTexture(nil, "BORDER", nil, 1)
	border:SetPoint(unpack(db.ExtraButtonBorderPosition))
	border:SetSize(unpack(db.ExtraButtonBorderSize))
	border:SetTexture(db.ExtraButtonBorderTexture)
	border:SetVertexColor(unpack(db.ExtraButtonBorderColor))
	button.iconBorder = border

	local cooldownCount = overlay:CreateFontString(nil, "OVERLAY", nil, 1)
	cooldownCount:SetPoint(unpack(db.ExtraButtonCooldownCountPosition))
	cooldownCount:SetJustifyH(db.ExtraButtonCooldownCountJustifyH)
	cooldownCount:SetJustifyV(db.ExtraButtonCooldownCountJustifyV)
	cooldownCount:SetFontObject(db.ExtraButtonCooldownCountFont)
	cooldownCount:SetTextColor(unpack(db.ExtraButtonCooldownCountColor))
	button.cooldownCount = cooldownCount
	ns.Widgets.RegisterCooldown(cooldown, cooldownCount)

	local count = overlay:CreateFontString(nil, "OVERLAY", nil, 1)
	count:SetPoint(unpack(db.ExtraButtonCountPosition))
	count:SetJustifyH(db.ExtraButtonCountJustifyH)
	count:SetJustifyV(db.ExtraButtonCountJustifyV)
	count:SetFontObject(db.ExtraButtonCountFont)
	count:SetTextColor(unpack(db.ExtraButtonCountColor))
	button.Count = count

	local hotkey = overlay:CreateFontString(nil, "OVERLAY", nil, 1)
	hotkey:SetPoint(unpack(db.ExtraButtonBindPosition))
	hotkey:SetFontObject(db.ExtraButtonBindFont)
	hotkey:SetJustifyH(db.ExtraButtonBindJustifyH)
	hotkey:SetJustifyV(db.ExtraButtonBindJustifyV)
	hotkey:SetShadowOffset(0, 0)
	hotkey:SetShadowColor(0, 0, 0, 1)
	hotkey:SetTextColor(unpack(db.ExtraButtonBindColor))
	button.HotKey = hotkey
	button.hotkeyColor = db.ExtraButtonBindColor

	button:SetAttribute("_onattributechanged", ATTRIBUTE_HANDLER)
	RegisterStateDriver(button, "visible", "[petbattle] hide; show")
	RegisterStateDriver(button, "extrabar", "[extrabar] on; off")

	if (ns.LegacyHUD) then ns.LegacyHUD:StyleButton(button) end

	self.button = button
	self.frame = button
	return button
end

-- Display
--------------------------------------------
QuestItem.UpdateCount = function(self)
	local button = self.button
	if (not button) then return end
	local count = self.itemLink and GetItemCount(self.itemLink) or 0
	button.Count:SetText(count > 1 and count or "")
end

QuestItem.UpdateCooldown = function(self)
	local button = self.button
	if (not button) then return end
	local itemID = self.itemLink and GetItemIDFromLink(self.itemLink)
	if (not itemID) then
		button.Cooldown:Clear()
		return
	end
	local start, duration = C_Item.GetItemCooldown(itemID)
	if (IsSecret(start) or IsSecret(duration)) then
		-- The widget takes what we may not read.
		button.Cooldown:SetCooldown(start, duration)
	elseif (duration and duration > 0) then
		button.Cooldown:SetCooldown(start, duration)
	else
		button.Cooldown:Clear()
	end
end

QuestItem.UpdateHotkey = function(self)
	if (not self.button) then return end
	self.button.HotKey:SetText(self:GetHotkeyText())
	local c = self.button.hotkeyColor
	self.button.HotKey:SetTextColor(c[1], c[2], c[3], c[4] or 1)
end

QuestItem.UpdateRangeWatch = function(self)
	local button = self.button
	if (not button) then return end
	local watch = self.itemLink and C_Item.ItemHasRange and C_Item.ItemHasRange(self.itemLink) and UnitExists("target")
	if (IsSecret(watch)) then watch = false end
	button:SetScript("OnUpdate", watch and Button_OnUpdate or nil)
	if (not watch) then self:UpdateHotkey() end
end

-- The click target and what the button shows change together, out of combat.
QuestItem.ApplyItem = function(self)
	local button = self.button
	if (not button) then return end
	if (InCombatLockdown()) then
		self.applyPending = true
		return
	end
	self.applyPending = nil

	local link = self.pendingLink
	local itemID = link and GetItemIDFromLink(link)
	self.itemLink = itemID and link or nil
	self.questID = itemID and self.pendingQuestID or nil

	local enabled = self.db.profile.enabled
	button:SetAttribute("usefallback", (enabled and self.db.profile.useExtraActionKey and not GetBindingKey(self:GetClickBinding())) and true or nil)
	button:SetAttribute("forceshow", (enabled and self.forceShow) and true or nil)
	button:SetAttribute("item", (enabled and itemID) and ("item:"..itemID) or nil)

	if (self.itemLink) then
		local _, _, _, _, texture = C_Item.GetItemInfoInstant(itemID)
		button.Icon:SetTexture(texture)
	else
		button.Icon:SetTexture(self.forceShow and PLACEHOLDER_ICON or nil)
	end

	self:UpdateCount()
	self:UpdateCooldown()
	self:UpdateHotkey()
	self:UpdateRangeWatch()
	Button_UpdateChecked(button)
end

-- Scanning
--------------------------------------------
QuestItem.Scan = function(self)
	self.scanQueued = nil
	if (not self.button) then return end

	-- Nothing the scan finds can reach the button before combat ends.
	if (InCombatLockdown()) then
		self.scanAfterCombat = true
		return
	end
	self.scanAfterCombat = nil

	local profile = self.db.profile
	local link, questID
	if (profile.enabled) then
		link = Finder.GetTargetItem()
		if (not link) then
			link, questID = Finder.GetClosestQuestItem({
				maxDistance = profile.maxDistance or 1000,
				zoneOnly = profile.zoneOnly,
				trackedOnly = profile.trackedOnly
			})
		end
	else
		Finder.hasCandidates = false
	end

	self:UpdateTicker(profile.enabled and (Finder.hasCandidates or link) and true or false)

	if (link == self.itemLink and questID == self.questID and not self.applyPending) then
		self:UpdateCount()
		return
	end
	self.pendingLink, self.pendingQuestID = link, questID
	self:ApplyItem()
end

-- Bursts of quest and bag events come in together; one scan answers them all.
QuestItem.RequestScan = function(self)
	if (self.scanQueued) then return end
	self.scanQueued = true
	C_Timer.After(SCAN_DELAY, function() self:Scan() end)
end

-- Distance changes without events, so it is polled, but only while there is an
-- item worth showing at some distance.
QuestItem.UpdateTicker = function(self, run)
	if (run and not self.ticker) then
		self.ticker = C_Timer.NewTicker(TICK, function() self:RequestScan() end)
	elseif (not run and self.ticker) then
		self.ticker:Cancel()
		self.ticker = nil
	end
end

QuestItem.OnEvent = function(self, event, ...)
	if (event == "BAG_UPDATE_COOLDOWN") then
		return self:UpdateCooldown()
	elseif (event == "CURRENT_SPELL_CAST_CHANGED" or event == "ACTIONBAR_UPDATE_STATE") then
		if (self.button) then Button_UpdateChecked(self.button) end
		return
	elseif (event == "UPDATE_BINDINGS" or event == "GAME_PAD_ACTIVE_CHANGED") then
		if (event == "GAME_PAD_ACTIVE_CHANGED") then
			local LAB = LibStub("LibActionButton-1.0-GE", true)
			if (LAB and LAB.SetGamePadActive) then LAB.SetGamePadActive((...)) end
		end
		self.applyPending = true
		return self:ApplyItem()
	elseif (event == "PLAYER_TARGET_CHANGED") then
		self:UpdateRangeWatch()
	elseif (event == "PLAYER_REGEN_ENABLED") then
		if (self.applyPending) then self:ApplyItem() end
		if (not self.scanAfterCombat) then return end
	elseif (event == "UNIT_AURA" and InCombatLockdown()) then
		-- Auras churn in combat and only matter to the scan after it.
		self.scanAfterCombat = true
		return
	end
	self:RequestScan()
end

-- Binding modes: the button must be there to be hovered.
QuestItem.SetForceShow = function(self, show)
	self.forceShow = show and true or nil
	self.applyPending = true
	self:ApplyItem()
end

QuestItem.OnKeyBoundEnabled = function(self) self:SetForceShow(true) end
QuestItem.OnKeyBoundDisabled = function(self) self:SetForceShow(false) end

-- Settings
--------------------------------------------
QuestItem.UpdateSettings = function(self)
	if (not self.button) then return end
	self.applyPending = true
	self:RequestScan()
	self:ApplyItem()
end

-- ExtraQuestButton binds the same extra action key; only one should hold it.
QuestItem.GetRivalChoice = function(self)
	local char = self.db.char
	if (char.rival == RIVAL and (char.owner == "other" or char.owner == "both")) then
		return char.owner
	end
end

QuestItem.HasRival = function(self)
	return ns.API.IsAddOnEnabled(RIVAL) and true or false
end

QuestItem.IsStandingDown = function(self)
	return self.standingDown and true or false
end

QuestItem.PromptRivalChoice = function(self)
	if (not self:HasRival()) then return end
	ns.API.ShowAddonConflictPrompt({
		key = "QuestItemButton",
		feature = L["Quest Item Button"],
		rival = RIVAL,
		OnChoose = function(choice)
			self.db.char.owner = choice
			self.db.char.rival = RIVAL
		end
	})
end

QuestItem.OnEnable = function(self)
	if (self:HasRival() and self:GetRivalChoice() ~= "both") then
		self.standingDown = true
		if (not self:GetRivalChoice()) then
			C_Timer.After(5, function() self:PromptRivalChoice() end)
		end
		return
	end
	self.standingDown = nil

	if (InCombatLockdown()) then
		-- Secure frames are built out of combat; try again when it ends.
		self:RegisterEvent("PLAYER_REGEN_ENABLED", "OnEnable")
		return
	end
	self:UnregisterEvent("PLAYER_REGEN_ENABLED", "OnEnable")
	if (self.button) then return end

	self:CreateButton()
	self:CreateAnchor(L["Quest Item Button"])

	for _, event in next, {
		"PLAYER_ENTERING_WORLD", "QUEST_LOG_UPDATE", "QUEST_POI_UPDATE", "QUEST_WATCH_LIST_CHANGED",
		"ZONE_CHANGED", "ZONE_CHANGED_NEW_AREA", "PLAYER_INSIDE_QUEST_BLOB_STATE_CHANGED",
		"WAYPOINT_UPDATE", "SUPER_TRACKING_CHANGED", "BAG_UPDATE_DELAYED", "BAG_UPDATE_COOLDOWN",
		"ITEM_DATA_LOAD_RESULT", "PLAYER_TARGET_CHANGED", "PLAYER_REGEN_ENABLED",
		"UPDATE_BINDINGS", "CURRENT_SPELL_CAST_CHANGED", "ACTIONBAR_UPDATE_STATE", "GAME_PAD_ACTIVE_CHANGED"
	} do
		if (ns.API.IsEventAvailable(event)) then
			self:RegisterEvent(event, "OnEvent")
		end
	end
	self:RegisterUnitEvent("UNIT_AURA", "OnEvent", "player")

	local KeyBound = LibStub("LibKeyBound-1.0", true)
	if (KeyBound and KeyBound.RegisterCallback) then
		KeyBound.RegisterCallback(self, "LIBKEYBOUND_ENABLED", "OnKeyBoundEnabled")
		KeyBound.RegisterCallback(self, "LIBKEYBOUND_DISABLED", "OnKeyBoundDisabled")
	end

	ns.MovableModulePrototype.OnEnable(self)
	self:UpdateSettings()
end
