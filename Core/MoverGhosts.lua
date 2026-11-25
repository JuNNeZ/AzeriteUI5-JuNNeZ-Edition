--[[

	The MIT License (MIT)

	Copyright (c) 2026 Jonas "JuNNeZ" Andersen

--]]
-- Ghosts for /lock and Edit Mode: while the movers are shown, a mover whose
-- frame is empty right now (no target, no group, no cast, no timer) gets a
-- faint example of that frame's art, so its place can be judged before the
-- frame ever appears. Unit frames and the player castbar use the theme's own
-- art through the bar tests builder (Core/ThemeBarPreview.lua); every other
-- mover gets a plain placeholder.
--
-- A ghost is an insecure, mouse-disabled frame parented to the mover's overlay,
-- so it moves with a drag and hides with the movers. No real frame is shown,
-- hidden, re-parented or otherwise changed, and no unit value is read.
--
-- Each mover with a ghost has an eye button that hides or shows its ghost. The
-- choice is saved per profile in `moverGhostsHidden[key]`; `moverGhosts` turns
-- every ghost off (/lock -> Moving Frames).
local Addon, ns = ...

local L = LibStub("AceLocale-3.0"):GetLocale(Addon)

-- Lua API
local ipairs = ipairs
local math_floor = math.floor
local math_max = math.max
local math_min = math.min
local next = next
local pcall = pcall
local type = type

-- GLOBALS: CreateFrame, GameTooltip, InCombatLockdown, issecretvalue

local Ghosts = {}
ns.MoverGhosts = Ghosts

-- How often an open /lock or Edit Mode checks whether a frame became empty or
-- filled (a target picked, a group joined).
local REFRESH = .5
local GHOST_ALPHA = .65
local MAX_CELLS = 40

-- Movers with themed art: the bar tests layout to use, `grid` for a frame that
-- holds several units, `element` for a frame that is always shown and is only
-- empty when that element is (the player castbar outside a cast).
local UNIT_GHOSTS = {
	PlayerFrame = { kind = "playerHi" },
	PlayerFrameAlternate = { kind = "alternate" },
	PlayerFrameParty = { kind = "party" },
	TargetFrame = { kind = "targetHi" },
	ToTFrame = { kind = "tot" },
	FocusFrame = { kind = "focus" },
	PetFrame = { kind = "pet" },
	BossFrames = { kind = "boss", grid = true },
	ArenaFrames = { kind = "arena", grid = true },
	PartyFrames = { kind = "party", grid = true },
	RaidFrame5 = { kind = "raid5", grid = true },
	RaidFrame25 = { kind = "raid", grid = true },
	RaidFrame40 = { kind = "raid", grid = true },
	PlayerCastBarFrame = { kind = "cast", element = "Castbar" }
}
Ghosts.UnitGhosts = UNIT_GHOSTS

-- Every mover seen so far, and the ghost state kept for each.
local tracked = {}
local driver

local GetProfile = function()
	return ns.db and ns.db.profile
end

Ghosts.IsEnabled = function(self)
	local profile = GetProfile()
	return not (profile and profile.moverGhosts == false)
end

Ghosts.IsHidden = function(self, key)
	local profile = GetProfile()
	local hidden = profile and profile.moverGhostsHidden
	return key and type(hidden) == "table" and hidden[key] == true or false
end

Ghosts.SetHidden = function(self, key, hide)
	local profile = GetProfile()
	if (not key or not profile) then return end
	if (type(profile.moverGhostsHidden) ~= "table") then
		profile.moverGhostsHidden = {}
	end
	profile.moverGhostsHidden[key] = hide and true or nil
	self:RefreshAll()
end

-- Emptiness
--------------------------------------
local IsShownOnScreen = function(frame)
	if (not frame or type(frame.IsVisible) ~= "function") then return false end
	local ok, visible = pcall(frame.IsVisible, frame)
	if (not ok or (issecretvalue and issecretvalue(visible))) then return false end
	return visible and true or false
end

local GetChildList = function(frame)
	if (type(frame.GetChildren) ~= "function") then return end
	local ok, list = pcall(function() return { frame:GetChildren() } end)
	return ok and list or nil
end

-- 'true' when a unit button is on screen in frame: the frame itself for a single
-- unit frame; its `units`, `content` or child buttons for a group container.
local HasVisibleUnit
HasVisibleUnit = function(frame, depth)
	if (not IsShownOnScreen(frame)) then return false end
	if (type(frame.unit) == "string") then return true end
	if (depth >= 3) then return false end

	if (type(frame.units) == "table") then
		for _, unit in ipairs(frame.units) do
			if (HasVisibleUnit(unit, depth + 1)) then return true end
		end
		return false
	end
	if (frame.content and HasVisibleUnit(frame.content, depth + 1)) then return true end

	local children = GetChildList(frame)
	if (children) then
		for _, child in ipairs(children) do
			if (HasVisibleUnit(child, depth + 1)) then return true end
		end
	end
	return false
end

-- 'true' when a plain holder shows anything: a visible child frame or region.
local HasVisibleContent = function(frame)
	if (not IsShownOnScreen(frame)) then return false end
	local children = GetChildList(frame)
	if (children) then
		for _, child in ipairs(children) do
			if (IsShownOnScreen(child)) then return true end
		end
	end
	if (type(frame.GetRegions) == "function") then
		local ok, regions = pcall(function() return { frame:GetRegions() } end)
		if (ok) then
			for _, region in ipairs(regions) do
				if (IsShownOnScreen(region)) then return true end
			end
		end
	end
	return false
end

local GetModuleFrame = function(key)
	if (not key) then return end
	local ok, module = pcall(ns.GetModule, ns, key, true)
	local frame = ok and module and module.frame
	if (type(frame) ~= "table") then return end
	return frame
end

-- 'true' when the mover's frame shows nothing right now, so a ghost helps.
Ghosts.IsEmpty = function(self, key)
	local frame = GetModuleFrame(key)
	if (not frame) then return false end

	local spec = UNIT_GHOSTS[key]
	if (spec and spec.element) then
		return not IsShownOnScreen(frame[spec.element])
	elseif (spec) then
		return not HasVisibleUnit(frame, 0)
	end
	return not HasVisibleContent(frame)
end

-- Building
--------------------------------------
local SetEntryValues = function(entry)
	local builder = ns.ThemeBarPreview
	for _, bar in ipairs(entry.bars) do
		if (bar.SetValue) then bar:SetValue(entry.kind == "cast" and .6 or .75) end
	end
	if (entry.cast) then
		local color = entry.db.CastBarColor
		if (color) then entry.cast:SetStatusBarColor(color[1], color[2], color[3], color[4] or 1) end
		if (entry.cast.Shield) then entry.cast.Shield:Hide() end
		if (entry.cast.Backdrop) then entry.cast.Backdrop:Show() end
	end
	if (builder and builder.StyleEntry) then
		pcall(builder.StyleEntry, builder, entry)
	end
end

-- Several units laid out over the mover's area, as many as fit (party, raid, boss, arena).
local BuildGrid = function(container, kind, width, height)
	local builder = ns.ThemeBarPreview
	local first = builder:Create(kind, container)
	if (not first) then return end

	local cellWidth, cellHeight = first.owner:GetSize()
	if (not cellWidth or cellWidth <= 0 or cellHeight <= 0) then return end

	local columns = math_max(1, math_floor(width / cellWidth + .05))
	local rows = math_max(1, math_floor(height / cellHeight + .05))
	while (columns * rows > MAX_CELLS) do
		if (rows > columns) then rows = rows - 1 else columns = columns - 1 end
	end
	local stepX = columns > 1 and (width - cellWidth) / (columns - 1) or 0
	local stepY = rows > 1 and (height - cellHeight) / (rows - 1) or 0

	local entry = first
	for row = 1, rows do
		for column = 1, columns do
			if (not entry) then entry = builder:Create(kind, container) end
			if (not entry) then return end
			entry.owner:SetPoint("TOPLEFT", container, "TOPLEFT", (column - 1) * stepX, -(row - 1) * stepY)
			SetEntryValues(entry)
			entry = nil
		end
	end
	return true
end

-- A faint panel the size of the mover, for frames with no themed art.
local BuildPlaceholder = function(container)
	local fill = container:CreateTexture(nil, "BACKGROUND")
	fill:SetAllPoints(container)
	fill:SetColorTexture(0, 0, 0, .55)

	local r, g, b = .85, .7, .35
	local edges = {
		{ "TOPLEFT", "TOPRIGHT", nil, 1 },
		{ "BOTTOMLEFT", "BOTTOMRIGHT", nil, 1 },
		{ "TOPLEFT", "BOTTOMLEFT", 1, nil },
		{ "TOPRIGHT", "BOTTOMRIGHT", 1, nil }
	}
	for _, edge in ipairs(edges) do
		local line = container:CreateTexture(nil, "BORDER")
		line:SetColorTexture(r, g, b, .8)
		line:SetPoint(edge[1], container, edge[1])
		line:SetPoint(edge[2], container, edge[2])
		if (edge[3]) then line:SetWidth(edge[3]) else line:SetHeight(edge[4]) end
	end
	return true
end

local BuildGhost = function(state, anchor, key)
	local overlay = anchor.Overlay
	local frame = GetModuleFrame(key)

	local container = CreateFrame("Frame", nil, overlay)
	container:SetAllPoints(overlay)
	container:EnableMouse(false)
	container:SetIgnoreParentAlpha(true)
	container:SetAlpha(GHOST_ALPHA)
	-- The real frame's own stratum, so the mover box tints the ghost as it tints the frame.
	local ok, strata = pcall(function() return frame and frame:GetFrameStrata() end)
	container:SetFrameStrata(ok and strata or "MEDIUM")

	local spec = UNIT_GHOSTS[key]
	local builder = ns.ThemeBarPreview
	local built
	if (spec and builder and builder.Create) then
		if (spec.grid) then
			local width, height = overlay:GetSize()
			built = BuildGrid(container, spec.kind, width or 0, height or 0)
		else
			local entry = builder:Create(spec.kind, container)
			if (entry) then
				entry.owner:ClearAllPoints()
				entry.owner:SetAllPoints(container)
				SetEntryValues(entry)
				built = true
			end
		end
	end
	if (not built) then
		BuildPlaceholder(container)
	end

	container:Hide()
	state.ghost = container
	state.size = { overlay:GetSize() }
end

local Eye_OnEnter = function(self)
	if (not GameTooltip) then return end
	GameTooltip:SetOwner(self, "ANCHOR_TOP")
	GameTooltip:SetText(Ghosts:IsHidden(self.key) and L["Show this frame's preview"] or L["Hide this frame's preview"])
	GameTooltip:Show()
end

local Eye_OnLeave = function(self)
	if (GameTooltip and GameTooltip:IsOwned(self)) then GameTooltip:Hide() end
end

local Eye_OnClick = function(self)
	Ghosts:SetHidden(self.key, not Ghosts:IsHidden(self.key))
	Eye_OnEnter(self)
end

local CreateEye = function(state, anchor, key)
	local eye = CreateFrame("Button", nil, anchor.Overlay)
	eye:SetIgnoreParentScale(true)
	eye:SetIgnoreParentAlpha(true)
	eye:SetSize(20, 20)
	eye:SetPoint("TOPRIGHT", anchor.Overlay, "TOPRIGHT", -2, -2)
	eye:SetFrameLevel(anchor.Overlay:GetFrameLevel() + 10)
	eye:RegisterForClicks("LeftButtonUp")
	eye.key = key

	local icon = eye:CreateTexture(nil, "ARTWORK")
	icon:SetAllPoints(eye)
	icon:SetTexture(ns.API.GetMedia("group-finder-eye-green"))
	eye.Icon = icon

	eye:SetScript("OnEnter", Eye_OnEnter)
	eye:SetScript("OnLeave", Eye_OnLeave)
	eye:SetScript("OnClick", Eye_OnClick)
	eye:Hide()

	state.eye = eye
end

-- Updating
--------------------------------------
Ghosts.UpdateAnchor = function(self, anchor)
	local state = tracked[anchor]
	if (not state) then return end
	local key = state.key

	local show = anchor:IsShown() and self:IsEnabled() and self:IsEmpty(key)
	if (not show) then
		if (state.ghost) then state.ghost:Hide() end
		if (state.eye) then state.eye:Hide() end
		return
	end

	if (not state.eye) then CreateEye(state, anchor, key) end
	local hidden = self:IsHidden(key)
	state.eye:Show()
	state.eye.Icon:SetDesaturated(hidden)
	state.eye.Icon:SetAlpha(hidden and .45 or 1)

	if (hidden) then
		if (state.ghost) then state.ghost:Hide() end
		return
	end

	-- A group frame's size follows its settings; rebuild when it changed. Frames
	-- are only made out of combat, like the bar tests.
	local width, height = anchor.Overlay:GetSize()
	local size = state.size
	-- Frames cannot be freed: the old ghost is parked hidden and left to the
	-- client. That costs one frame set per size change of a grid mover.
	if (state.ghost and size and (math_min(width, size[1]) + .5 < math_max(width, size[1])
		or math_min(height, size[2]) + .5 < math_max(height, size[2]))) then
		state.ghost:Hide()
		state.ghost:SetParent(nil)
		state.ghost = nil
	end
	if (not state.ghost) then
		if (InCombatLockdown()) then return end
		BuildGhost(state, anchor, key)
	end
	state.ghost:Show()
end

Ghosts.RefreshAll = function(self)
	local anyShown
	for anchor in next, tracked do
		self:UpdateAnchor(anchor)
		if (anchor:IsShown()) then anyShown = true end
	end
	if (driver) then driver:SetShown(anyShown and true or false) end
end

local Driver_OnUpdate = function(self, elapsed)
	self.elapsed = (self.elapsed or 0) + elapsed
	if (self.elapsed < REFRESH) then return end
	self.elapsed = 0
	Ghosts:RefreshAll()
end

Ghosts.MFM_AnchorShown = function(self, _, anchor)
	if (not anchor or not anchor.Overlay or type(anchor.GetKey) ~= "function") then return end
	local key = anchor:GetKey()
	if (not key) then return end

	if (not tracked[anchor]) then
		tracked[anchor] = { key = key }
	end
	if (not driver) then
		driver = CreateFrame("Frame")
		driver:SetScript("OnUpdate", Driver_OnUpdate)
	end
	driver.elapsed = 0
	driver:Show()
	self:UpdateAnchor(anchor)
end

ns.RegisterCallback(Ghosts, "MFM_AnchorShown", "MFM_AnchorShown")
