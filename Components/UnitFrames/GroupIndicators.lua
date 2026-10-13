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
	Two small indicators on the party and raid frames, both off by default and set
	under /az -> Unit Frames -> Group Indicators.

	Sated. Bloodlust, Heroism, Time Warp and drums leave a debuff (Sated, Exhaustion,
	Temporal Displacement, ...) that stops another lust for ten minutes. A small icon
	with a swipe shows who has it. An aura container cannot pick these out: Blizzard
	skips spell filters for debuffs on friendly units (CanApplyIdentityCandidateFilters
	in Blizzard_AuraContainerUtil.lua). The debuffs are NeverSecret, though, so
	C_UnitAuras.GetUnitAuraBySpellID reads them directly, in combat too (/azdebug sated,
	live 2026-10-10).

	Corner dots. One native aura container per corner, filtered by the player's own
	spell list with includeSpellIDs, so Blizzard does the matching and no aura data
	passes through addon code. Spell filters work for buffs on friendly units, which
	is what a healer tracks. /azdebug auracost measured 160 of these containers (a
	40-player raid at four corners) with no frame time cost (live 2026-10-10); they
	are still only built for a frame the first time the option is on.

	Both attach through oUF's init callback, so the four group frame files only gain a
	style name in GROUP_STYLES below, and follow a header button to each new unit
	through the frame's PostUpdate, which oUF runs after every full update.
]]

local GroupIndicators = {}
ns.GroupIndicators = GroupIndicators

local GROUP_STYLES = {
	[ns.Prefix .. "Party"] = true,
	[ns.Prefix .. "Raid5"] = true,
	[ns.Prefix .. "Raid25"] = true,
	[ns.Prefix .. "Raid40"] = true
}

-- The lust debuffs, the same list /azdebug sated reads.
local LUST_DEBUFFS = { 57724, 57723, 80354, 95809, 264689, 390435 }

local CORNERS = { "TOPLEFT", "TOPRIGHT", "BOTTOMLEFT", "BOTTOMRIGHT" }
GroupIndicators.Corners = CORNERS

-- Starting points per class, filled in by "Use my class's suggestions". Only spell IDs
-- this addon already uses elsewhere (AuraCostProbe.lua); the player edits from here.
local CLASS_SUGGESTIONS = {
	DRUID = { TOPLEFT = "774" },                       -- Rejuvenation
	PRIEST = { TOPLEFT = "139", TOPRIGHT = "17", BOTTOMLEFT = "194384" }, -- Renew, Power Word: Shield, Atonement
	SHAMAN = { TOPLEFT = "61295" },                    -- Riptide
	MONK = { TOPLEFT = "119611" },                     -- Renewing Mist
	EVOKER = { TOPLEFT = "364343" },                   -- Echo
	PALADIN = { TOPLEFT = "53563" }                    -- Beacon of Light
}
GroupIndicators.ClassSuggestions = CLASS_SUGGESTIONS

local frames = {}
local IsSecret = function(value)
	return type(issecretvalue) == "function" and issecretvalue(value) or false
end

local GetProfile = function()
	local module = ns:GetModule("UnitFrames", true)
	return module and module.db and module.db.profile or {}
end

local SetMouseInputEnabled = function(frame, enabled)
	frame:EnableMouse(enabled)
	if (frame.SetMouseMotionEnabled) then frame:SetMouseMotionEnabled(enabled) end
	if (frame.SetMouseClickEnabled) then frame:SetMouseClickEnabled(enabled) end
end

--[[ Spell lists ]]--

-- "774, Renew; 61295" -> { [774] = true, [139] = true, [61295] = true }. Names go
-- through the client's own lookup; anything it does not know is dropped and reported
-- by GroupIndicators.ParseSpellList's second return.
GroupIndicators.ParseSpellList = function(text)
	local spells, unknown, count = {}, {}, 0
	if (type(text) ~= "string") then return spells, unknown, 0 end
	for word in text:gmatch("[^,;\n]+") do
		word = word:match("^%s*(.-)%s*$")
		if (word ~= "") then
			local spellID = tonumber(word)
			if (not spellID and C_Spell and C_Spell.GetSpellIDForSpellIdentifier) then
				local ok, id = pcall(C_Spell.GetSpellIDForSpellIdentifier, word)
				if (ok and not IsSecret(id) and type(id) == "number") then spellID = id end
			end
			if (spellID and spellID > 0 and spellID == math.floor(spellID)) then
				if (not spells[spellID]) then count = count + 1 end
				spells[spellID] = true
			else
				unknown[#unknown + 1] = word
			end
		end
	end
	return spells, unknown, count
end

--[[ Sated ]]--

local CreateSated = function(frame)
	local holder = frame.Health and frame.Health.Overlay or frame.Overlay or frame
	local sated = CreateFrame("Frame", nil, holder)
	SetMouseInputEnabled(sated, false)
	sated:SetFrameLevel(holder:GetFrameLevel() + 2)
	sated:Hide()

	local icon = sated:CreateTexture(nil, "ARTWORK", nil, 1)
	icon:SetAllPoints()
	icon:SetTexCoord(.1, .9, .1, .9)
	sated.Icon = icon

	local border = sated:CreateTexture(nil, "BACKGROUND", nil, -1)
	border:SetPoint("TOPLEFT", -1, 1)
	border:SetPoint("BOTTOMRIGHT", 1, -1)
	border:SetColorTexture(0, 0, 0, .85)

	local cooldown = CreateFrame("Cooldown", nil, sated, "CooldownFrameTemplate")
	SetMouseInputEnabled(cooldown, false)
	cooldown:SetAllPoints()
	cooldown:SetDrawEdge(false)
	cooldown:SetDrawBling(false)
	cooldown:SetReverse(true)
	cooldown:SetHideCountdownNumbers(true)
	sated.Cooldown = cooldown

	frame.SatedIndicator = sated
	return sated
end

-- Sits at the right end of the health bar, inside it, sized to the bar's height.
local LayoutSated = function(frame)
	local sated, health = frame.SatedIndicator, frame.Health
	if (not sated or not health) then return end
	local height = health:GetHeight()
	local size = math.max(10, math.min(18, (type(height) == "number" and height or 14) + 4))
	sated:ClearAllPoints()
	sated:SetPoint("RIGHT", health, "RIGHT", -2, 0)
	sated:SetSize(size, size)
end

-- The first lust debuff on the unit, read directly. nil when none, when the read
-- fails, or when the client hands back something secret.
local FindLustDebuff = function(unit)
	local read = C_UnitAuras and C_UnitAuras.GetUnitAuraBySpellID
	if (type(read) ~= "function" or not unit) then return end
	for _, spellID in ipairs(LUST_DEBUFFS) do
		local ok, aura = pcall(read, unit, spellID)
		if (ok and aura ~= nil and not IsSecret(aura)) then
			return aura, spellID
		end
	end
end

local UpdateSated = function(frame)
	local sated = frame.SatedIndicator
	if (not sated) then return end
	if (not GetProfile().groupSated) then
		sated:Hide()
		return
	end

	local aura, spellID = FindLustDebuff(frame.unit)
	if (not aura) then
		sated.auraInstanceID = nil
		sated:Hide()
		return
	end

	local instanceID = aura.auraInstanceID
	sated.auraInstanceID = (not IsSecret(instanceID)) and instanceID or nil
	local icon = aura.icon
	if (IsSecret(icon) or not icon) then
		icon = C_Spell and C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(spellID)
	end
	sated.Icon:SetTexture(icon)

	local duration, expires = aura.duration, aura.expirationTime
	if (not IsSecret(duration) and not IsSecret(expires) and type(duration) == "number"
		and type(expires) == "number" and duration > 0) then
		sated.Cooldown:SetCooldown(expires - duration, duration)
		sated.Cooldown:Show()
	else
		sated.Cooldown:Hide()
	end
	LayoutSated(frame)
	sated:Show()
end

-- Most UNIT_AURA events only refresh auras already there. Look again only when one
-- was added, when the one shown was removed, or on a full update.
-- In instances the payload's fields can be secret (the table itself is not);
-- a field we cannot read counts as "look again".
local SatedNeedsUpdate = function(frame, updateInfo)
	if (type(updateInfo) ~= "table") then return true end
	local isFullUpdate, added = updateInfo.isFullUpdate, updateInfo.addedAuras
	if (IsSecret(isFullUpdate) or isFullUpdate) then return true end
	if (IsSecret(added) or added) then return true end
	local shown = frame.SatedIndicator and frame.SatedIndicator.auraInstanceID
	local removed = updateInfo.removedAuraInstanceIDs
	if (IsSecret(removed)) then return true end
	if (shown and type(removed) == "table") then
		for _, id in ipairs(removed) do
			if (not IsSecret(id) and id == shown) then return true end
		end
	end
	return false
end

--[[ Corner dots ]]--

local CORNER_GROUP = "AzeriteGroupCorner"

local CanTouch = function(widget)
	if (not widget) then return false end
	local canBeAccessed = widget.CanBeAccessedInContext
	if (type(canBeAccessed) ~= "function") then return true end
	local ok, accessible = pcall(canBeAccessed, widget)
	return ok and not IsSecret(accessible) and accessible == true
end

local StyleDot = function(button, size)
	button:SetSize(size, size)
	SetMouseInputEnabled(button, false)

	local border = button:CreateTexture(nil, "BACKGROUND", nil, -1)
	border:SetPoint("TOPLEFT", -1, 1)
	border:SetPoint("BOTTOMRIGHT", 1, -1)
	border:SetColorTexture(0, 0, 0, .9)

	local icon = button:CreateTexture(nil, "ARTWORK", nil, 1)
	icon:SetAllPoints(button)
	icon:SetTexCoord(.15, .85, .15, .85)
	button.Icon = icon
	button:SetIcon(icon)

	-- A dark swipe that empties as the aura runs out; no numbers at this size.
	if (type(button.SetDurationCooldown) == "function") then
		local cooldown = CreateFrame("Cooldown", nil, button, "CooldownFrameTemplate")
		SetMouseInputEnabled(cooldown, false)
		cooldown:SetAllPoints(button)
		cooldown:SetDrawEdge(false)
		cooldown:SetDrawBling(false)
		cooldown:SetReverse(true)
		cooldown:SetHideCountdownNumbers(true)
		button.Cooldown = cooldown
		pcall(button.SetDurationCooldown, button, cooldown)
	end
end

local CreateCorner = function(frame, corner, size, filterString, spells, signature)
	local parent = frame.Health or frame
	local container = CreateFrame("AuraContainer", nil, parent,
		"CustomAuraContainerTemplate, DisableUntrustedLayoutScriptsTemplate")
	SetMouseInputEnabled(container, false)
	container:SetFrameLevel(parent:GetFrameLevel() + 4)
	container:SetSize(size, size)
	container:SetPoint(corner, parent, corner, 0, 0)
	container.__AzeriteUI_Size = size
	-- Stays disabled until it has a unit: an enabled container registers UNIT_AURA.
	container:SetEnabled(false)
	container:AddAuraGroup(CORNER_GROUP, filterString, {
		initializeFrame = function(button) StyleDot(button, container.__AzeriteUI_Size or size) end,
		candidateFilters = { includeSpellIDs = spells },
		maxFrameCount = 1,
		layout = { elementWidth = size, elementHeight = size, layoutIndex = 1 }
	})
	container.__AzeriteUI_Signature = signature
	return container
end

-- Templates the corners need. Without them the option does nothing.
GroupIndicators.CanBuildCorners = function()
	return C_XMLUtil and C_XMLUtil.GetTemplateInfo and C_XMLUtil.GetTemplateInfo("CustomAuraContainerTemplate") and true or false
end

local GetCornerConfig = function(profile)
	local spellsByCorner, signatures = {}, {}
	local onlyMine = profile.groupCornerOnlyMine ~= false
	for _, corner in ipairs(CORNERS) do
		local text = profile["groupCornerSpells" .. corner] or ""
		local spells, _, count = GroupIndicators.ParseSpellList(text)
		spellsByCorner[corner] = count > 0 and spells or nil
		local ids = {}
		for id in pairs(spells) do ids[#ids + 1] = id end
		table.sort(ids)
		signatures[corner] = table.concat(ids, ",") .. (onlyMine and "|mine" or "|all")
	end
	local size = tonumber(profile.groupCornerSize) or 10
	size = math.max(6, math.min(20, math.floor(size + .5)))
	return spellsByCorner, signatures, onlyMine and "HELPFUL|PLAYER" or "HELPFUL", size
end

local UpdateCorners = function(frame)
	local profile = GetProfile()
	local enabled = profile.groupCorners and GroupIndicators.CanBuildCorners()
	local corners = frame.CornerIndicators
	if (not enabled) then
		if (corners) then
			for _, container in pairs(corners) do container:SetEnabled(false); container:Hide() end
		end
		return
	end

	local spellsByCorner, signatures, filterString, size = GetCornerConfig(profile)
	local unit = frame.unit
	corners = corners or {}
	frame.CornerIndicators = corners
	for _, corner in ipairs(CORNERS) do
		local spells = spellsByCorner[corner]
		local container = corners[corner]
		if (spells and not container) then
			local ok, built = pcall(CreateCorner, frame, corner, size, filterString, spells, signatures[corner])
			if (ok and built) then
				container = built
				corners[corner] = container
			end
		end
		if (container) then
			if (spells and unit) then
				if (container.__AzeriteUI_Signature ~= signatures[corner]) then
					-- Rebuilds the group; only when the list or the source changed.
					container:SetAuraGroupFilterString(CORNER_GROUP, filterString)
					container:SetAuraGroupCandidateFilters(CORNER_GROUP, { includeSpellIDs = spells })
					container.__AzeriteUI_Signature = signatures[corner]
				end
				if (container.__AzeriteUI_Size ~= size) then
					container.__AzeriteUI_Size = size
					container:SetSize(size, size)
					container:SetAuraGroupLayout(CORNER_GROUP, { elementWidth = size, elementHeight = size, layoutIndex = 1 })
					for index = 1, container:GetAuraGroupFrameCount(CORNER_GROUP) do
						local button = container:GetAuraGroupFrame(CORNER_GROUP, index)
						if (CanTouch(button)) then button:SetSize(size, size) end
					end
				end
				if (container.__AzeriteUI_Unit ~= unit) then
					container.__AzeriteUI_Unit = unit
					container:SetUnit(unit)
				end
				container:SetEnabled(true)
				container:Show()
			else
				container:SetEnabled(false)
				container:Hide()
			end
		end
	end
end

--[[ Wiring ]]--

local Update = function(frame, event)
	UpdateSated(frame)
	UpdateCorners(frame)
end

local OnUnitAura = function(frame, event, unit, updateInfo)
	if (unit ~= frame.unit) then return end
	if (frame.SatedIndicator and GetProfile().groupSated and SatedNeedsUpdate(frame, updateInfo)) then
		UpdateSated(frame)
	end
end

local Initialize = function(frame)
	if (not GROUP_STYLES[frame.style] or frame.__AzeriteUI_GroupIndicators) then return end
	frame.__AzeriteUI_GroupIndicators = true
	frames[frame] = true

	CreateSated(frame)
	frame:RegisterEvent("UNIT_AURA", OnUnitAura)

	local postUpdate = frame.PostUpdate
	frame.PostUpdate = function(self, event, ...)
		if (postUpdate) then postUpdate(self, event, ...) end
		-- Full updates only: oUF passes an event, the style's own UNIT_AURA handler
		-- calls PostUpdate without one.
		if (event) then Update(self, event) end
	end
end

ns.oUF:RegisterInitCallback(Initialize)

-- Options call this after any change; existing frames update at once.
GroupIndicators.Refresh = function()
	for frame in pairs(frames) do
		Update(frame, "Refresh")
	end
end

-- For the harness.
GroupIndicators.Frames = frames
GroupIndicators.LustDebuffs = LUST_DEBUFFS
