-- AzeriteUI group loot styling for Blizzard's mouse and keyboard roll windows.
local _, ns = ...
local L = LibStub("AceLocale-3.0"):GetLocale((...))
local AlertFrames = ns:GetModule("AlertFrames")
local GetMedia, GetFont = ns.API.GetMedia, ns.API.GetFont
local Kit = ns.OptionsKit
local skinned = {}
local rollButtonSlots = { NeedButton = 2, GreedButton = 1, TransmogButton = 1, PassButton = 0 }
local rowWidth, rowHeight, rowGap = 320, 46, AlertFrames.lootRollRowGap

local function Place(region, point, relative, x, y)
	region:ClearAllPoints()
	region:SetPoint(point, relative, point, x, y)
end

local function CreateCasing(frame)
	local look = Kit.Look
	local rounded = look and look.IsRounded()
	local backdrop = rounded and look.CasingBackdrop or Kit.WindowCasing
	local fill = frame:CreateTexture(nil, "BACKGROUND", nil, -1)
	fill:SetAllPoints(frame)
	fill:SetColorTexture(1, 1, 1, 1)
	if (rounded) then look.RoundTexture(fill) end

	local casing = CreateFrame("Frame", nil, frame, ns.BackdropTemplate)
	-- Preserve the Options casing's inset relationship at a smaller edge size.
	local outset = Kit.WindowOutset
	local scale = .75
	casing:SetPoint("TOPLEFT", frame, "TOPLEFT", -outset.left * scale, outset.top * scale)
	casing:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", outset.right * scale, -outset.bottom * scale)
	casing:SetFrameLevel(frame:GetFrameLevel() + 2)
	local edge
	return function()
		local theme = AlertFrames.db.profile.lootRollClassTheme and ns.ThemeEngine and ns.ThemeEngine:GetActive()
		local classEdge = theme and theme.ResolveOwnMedia and theme:ResolveOwnMedia("border-tooltip")
		local current = classEdge or backdrop.edgeFile
		if (edge ~= current) then
			edge = current
			casing:SetBackdrop({ edgeFile = edge, edgeSize = backdrop.edgeSize * scale })
			casing:SetBackdropBorderColor(unpack(Kit.WindowCasingColor))
		end
		if (classEdge) then
			fill:SetVertexColor(.05, .05, .05, .95)
		else
			fill:SetVertexColor(Kit.GetSavedWindowColor())
		end
	end
end

local function SkinRollButton(button, frame, slot)
	Place(button, "RIGHT", frame, -8 - 36 * slot, 0)
	button:SetSize(32, 32)
	local backdrop = button:CreateTexture(nil, "BACKGROUND", nil, -8)
	backdrop:SetAllPoints(button)
	backdrop:SetColorTexture(.14, .14, .15, .9)
	local highlight = button:GetHighlightTexture()
	local function FitGlyph(texture)
		if (not texture) then return end
		Place(texture, "CENTER", button, 0, 0)
		texture:SetSize(20, 20)
	end
	FitGlyph(button:GetNormalTexture())
	FitGlyph(button:GetPushedTexture())
	FitGlyph(highlight)
	if (highlight) then highlight:SetAlpha(.65) end
end

local function RaiseTimer(frame)
	-- Blizzard lowers the timer during item setup on every use of the row.
	frame.Timer:SetFrameLevel(frame:GetFrameLevel() + 1)
end

local function SkinLootRoll(frame)
	if (skinned[frame] or frame:IsProtected()) then return end
	local buttons = frame.LootButtonContainer or frame
	local timer, name, icon = frame.Timer, frame.Name, frame.IconFrame
	if (not timer or not timer.Background or not name or not icon
		or not buttons.NeedButton or not buttons.GreedButton or not buttons.PassButton or not buttons.TransmogButton) then return end

	frame:SetSize(rowWidth, rowHeight)
	if (frame.Background) then frame.Background:SetAlpha(0) end
	if (frame.Border) then frame.Border:SetAlpha(0) end
	local refreshCasing = CreateCasing(frame)

	Place(icon, "LEFT", frame, 8, 0)
	Place(name, "TOPLEFT", frame, 51, -4)
	name:SetSize(145, 28)
	name:SetFontObject(GetFont(13, true))

	Place(timer, "BOTTOMLEFT", frame, 51, 9)
	timer:SetSize(145, 3)
	timer.Background:SetColorTexture(.16, .14, .12, .92)
	for key, slot in pairs(rollButtonSlots) do
		SkinRollButton(buttons[key], frame, slot)
	end
	local function Refresh()
		refreshCasing()
		local cast = ns.GetConfig("PlayerCastBar")
		timer:SetStatusBarTexture(cast.CastBarTexture)
		timer:SetStatusBarColor(unpack(cast.CastBarColor))
		RaiseTimer(frame)
	end
	skinned[frame] = refreshCasing
	Refresh()
	frame:HookScript("OnShow", Refresh)
end

AlertFrames.CanSkinLootRolls = function()
	return ns.BackdropTemplate and _G.GroupLootFrame1 ~= nil
end

AlertFrames.PrepareLootRollSkin = function(self)
	if (not self.db.profile.skinLootRolls or not self:CanSkinLootRolls()) then return end
	-- Forever's controller queue uses different, scroll-box-owned rows.
	for index = 1, 4 do
		local frame = _G["GroupLootFrame"..index]
		if (frame) then SkinLootRoll(frame) end
	end
end

AlertFrames.IsLootRollSkinned = function(_, frame)
	return skinned[frame] ~= nil
end

AlertFrames.UpdateLootRollSkinAppearance = function(self)
	for frame, refresh in pairs(skinned) do
		if (frame:IsVisible()) then refresh() end
	end
end

local samples = {
	{ name = "Shadowgem", icon = 134074, color = { .72, .52, 1 }, votes = {
		NeedButton = { "Simaru" }, GreedButton = { "Aelwyn", "Thoren", "Mira" }
	} },
	{ name = "Moonstone Band", icon = 133345, color = { .48, .80, .33 }, transmog = true, votes = {
		GreedButton = { "Mira", "Aelwyn" }, TransmogButton = { "Thoren" }, PassButton = { "Simaru" }
	} }
}

local function CreatePreviewButton(row, key, atlasType, label, vote)
	local button = CreateFrame("Button", nil, row)
	local atlas = "lootroll-toast-icon-"..atlasType
	button:SetNormalAtlas(atlas.."-up")
	button:SetPushedAtlas(atlas.."-down")
	button:SetHighlightAtlas(atlas.."-highlight")
	button.tooltipText = label
	row[key] = button
	if (not vote) then
		button:EnableMouse(false)
		return
	end
	button:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetText(label)
		GameTooltip:Show()
	end)
	button:SetScript("OnLeave", function(self)
		if (GameTooltip:IsOwned(self)) then GameTooltip:Hide() end
	end)
	button:SetScript("OnClick", function(self)
		vote(key)
		if (GameTooltip:IsOwned(self)) then GameTooltip:Hide() end
	end)
end

local function CreatePreviewRow(parent, sample, interactive)
	local row = CreateFrame("Frame", nil, parent)
	local icon = CreateFrame("Frame", nil, row)
	icon:SetSize(34, 34)
	local texture = icon:CreateTexture(nil, "ARTWORK")
	texture:SetAllPoints(icon)
	texture:SetTexture(sample.icon)
	row.IconFrame = icon
	row.Name = row:CreateFontString(nil, "ARTWORK")
	row.Name:SetJustifyH("LEFT")
	row.Timer = CreateFrame("StatusBar", nil, row)
	row.Timer:SetMinMaxValues(0, 30)
	row.Timer.Background = row.Timer:CreateTexture(nil, "BACKGROUND")
	row.Timer.Background:SetAllPoints(row.Timer)

	local choices, voted
	local function Vote(key)
		if (voted) then return end
		voted = true
		local choice = choices[key]
		choice.count = choice.count + 1
		choice.names[choice.count] = L["You (test roll)"]
		AlertFrames:ApplyLootRollChoices(row, choices)
	end
	local onVote = interactive and Vote
	CreatePreviewButton(row, "NeedButton", "need", NEED, onVote)
	CreatePreviewButton(row, "GreedButton", "greed", GREED, onVote)
	CreatePreviewButton(row, "TransmogButton", "transmog", TRANSMOGRIFICATION, onVote)
	CreatePreviewButton(row, "PassButton", "pass", PASS, onVote)
	row.GreedButton:SetShown(not sample.transmog)
	row.TransmogButton:SetShown(sample.transmog == true)
	SkinLootRoll(row)
	row.Name:SetText(sample.name)
	row.Name:SetTextColor(unpack(sample.color))
	return row, function()
		voted = nil
		choices = {}
		for key in pairs(rollButtonSlots) do
			local names = sample.votes[key] or {}
			choices[key] = { count = #names, names = { unpack(names) } }
		end
		AlertFrames:ApplyLootRollChoices(row, choices)
	end
end

local layoutPreview, layoutRows

AlertFrames.UpdateLootRollLayoutPreviewPosition = function(self)
	if (not layoutPreview) then return end
	local point, relativePoint, direction = self:PlaceLootRollStack(layoutPreview)
	for index, row in ipairs(layoutRows) do
		row:ClearAllPoints()
		if (index == 1) then
			row:SetPoint(point, layoutPreview, point)
		else
			row:SetPoint(point, layoutRows[index - 1], relativePoint, 0, rowGap * direction)
		end
	end
end

AlertFrames.UpdateLootRollLayoutPreviewVisibility = function(self)
	if (layoutPreview) then
		layoutPreview:SetShown(self.anchor:IsShown() and not GroupLootContainer:IsShown())
	end
end

AlertFrames.PrepareLootRollLayoutPreview = function(self)
	if (not self:CanSkinLootRolls() or not self:CanShowLootRollChoices()) then return end
	self.anchor:HookScript("OnShow", function()
		if (not layoutPreview) then
			layoutPreview = CreateFrame("Frame", nil, UIParent)
			layoutPreview:Hide()
			layoutPreview:SetSize(rowWidth, #samples * rowHeight + (#samples - 1) * rowGap)
			layoutPreview:SetFrameStrata("DIALOG")
			layoutRows = {}
			for index, sample in ipairs(samples) do
				local row, reset = CreatePreviewRow(layoutPreview, sample, false)
				reset()
				row.Timer:SetValue(26 - (index - 1) * 9)
				layoutRows[index] = row
			end
		end
		self:UpdateLootRollLayoutPreviewPosition()
		self:UpdateLootRollLayoutPreviewVisibility()
	end)
	self.anchor:HookScript("OnHide", function()
		self:UpdateLootRollLayoutPreviewVisibility()
	end)
end

local preview
AlertFrames.ToggleLootRollPreview = function(self)
	if (not self:CanSkinLootRolls() or not self:CanShowLootRollChoices()) then return end
	if (preview) then
		preview:SetShown(not preview:IsShown())
		return
	end
	preview = CreateFrame("Frame", nil, UIParent)
	preview:Hide()
	preview:SetSize(rowWidth + 16, 40 + #samples * (rowHeight + rowGap) - rowGap)
	preview:SetPoint("CENTER", UIParent, "CENTER", 0, 140)
	preview:SetFrameStrata("FULLSCREEN_DIALOG")
	preview:SetClampedToScreen(true)
	local title = preview:CreateFontString(nil, "OVERLAY")
	title:SetFontObject(GetFont(14, true))
	title:SetText(L["Preview loot rolls"])
	title:SetPoint("TOPLEFT", preview, "TOPLEFT", 12, -10)
	local close = CreateFrame("Button", nil, preview)
	close:SetSize(22, 22)
	close:SetNormalTexture(GetMedia("options-close"))
	close:SetHighlightTexture(GetMedia("options-close-bright"))
	for _, texture in ipairs({ close:GetNormalTexture(), close:GetHighlightTexture() }) do
		texture:SetTexCoord(.265625, .734375, .265625, .7421875)
	end
	close:SetScript("OnClick", function() preview:Hide() end)

	local rows, resets = {}, {}
	for index, sample in ipairs(samples) do
		local row, reset = CreatePreviewRow(preview, sample, true)
		row:SetPoint("TOP", preview, "TOP", 0, -32 - (index - 1) * (rowHeight + rowGap))
		rows[index], resets[index] = row, reset
	end
	close:SetPoint("CENTER", rows[1], "TOPRIGHT", 4, -1)
	close:SetFrameLevel(rows[1]:GetFrameLevel() + 3)
	local elapsed
	local function UpdateTimers()
		for index, row in ipairs(rows) do
			row.Timer:SetValue(30 - (elapsed + 9 * (index - 1)) % 30)
		end
	end
	preview:SetScript("OnShow", function()
		elapsed = 4
		for _, reset in ipairs(resets) do reset() end
		UpdateTimers()
	end)
	preview:SetScript("OnUpdate", function(_, delta)
		elapsed = elapsed + delta
		UpdateTimers()
	end)
	preview:Show()
end
