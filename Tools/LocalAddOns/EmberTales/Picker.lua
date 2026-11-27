local _, ns = ...

local ROW_HEIGHT = 22
local MAX_ROWS = 11

local function SmallButton(parent, text, width, action)
	local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
	button:SetSize(width, 22)
	button:SetText(text)
	button:SetScript("OnClick", action)
	return button
end

function ns.CreatePicker(parent, x, y, width, onSelect, onOpen)
	local picker = SmallButton(parent, "", width, function(self)
		if self:IsOpen() then
			self:Close()
		else
			self:Open()
		end
	end)
	picker:SetPoint("TOPLEFT", x, y)
	picker.entries, picker.rows = {}, {}
	picker.offset = 0

	-- Keep the rows and their click handlers private to Ember Tales.
	local panel = CreateFrame("Frame", nil, parent)
	panel:SetPoint("TOPLEFT", picker, "BOTTOMLEFT", 0, -2)
	panel:SetFrameLevel(parent:GetFrameLevel() + 8)
	panel:SetClampedToScreen(true)
	panel:EnableMouse(true)
	panel:EnableMouseWheel(true)
	panel:Hide()
	picker.panel = panel
	local background = panel:CreateTexture(nil, "BACKGROUND")
	background:SetAllPoints()
	background:SetColorTexture(0.10, 0.075, 0.055, 0.99)

	for index = 1, MAX_ROWS do
		local row = SmallButton(panel, "", width - 12, function(self)
			local entry = self.entry
			if entry and entry.value ~= nil then
				picker:Close()
				onSelect(entry.value)
			end
		end)
		row:SetPoint("TOPLEFT", 6, -6 - (index - 1) * ROW_HEIGHT)
		row.heading = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
		row.heading:SetPoint("LEFT", row, "LEFT", 8, 0)
		picker.rows[index] = row
	end

	local function Scroll(step)
		picker.offset = math.max(0, math.min(#picker.entries - MAX_ROWS, picker.offset + step))
		picker:Draw()
	end
	panel:SetScript("OnMouseWheel", function(_, delta) Scroll(delta > 0 and -1 or 1) end)
	local back = SmallButton(panel, "Up", 68, function() Scroll(-MAX_ROWS) end)
	back:SetPoint("BOTTOMLEFT", 6, 6)
	local forward = SmallButton(panel, "Down", 68, function() Scroll(MAX_ROWS) end)
	forward:SetPoint("BOTTOMRIGHT", -6, 6)
	local range = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	range:SetPoint("BOTTOM", 0, 10)

	function picker:Draw()
		local visibleRows = math.min(#self.entries, MAX_ROWS)
		for index, row in ipairs(self.rows) do
			local entry = index <= visibleRows and self.entries[self.offset + index] or nil
			row.entry = entry
			local isChoice = entry and entry.value ~= nil
			row:SetShown(isChoice == true)
			row.heading:SetShown(entry ~= nil and not isChoice)
			if isChoice then
				row:SetText(entry.label)
				row:SetEnabled(entry.value ~= self.selected)
			elseif entry then
				row.heading:SetText(entry.label)
			end
		end
		local scrollable = #self.entries > MAX_ROWS
		back:SetShown(scrollable)
		forward:SetShown(scrollable)
		range:SetShown(scrollable)
		if scrollable then
			back:SetEnabled(self.offset > 0)
			forward:SetEnabled(self.offset + visibleRows < #self.entries)
			range:SetText(("%d–%d / %d"):format(self.offset + 1, self.offset + visibleRows, #self.entries))
		end
		panel:SetSize(width, 12 + visibleRows * ROW_HEIGHT + (scrollable and 28 or 0))
	end

	function picker:SetEntries(entries)
		self.entries = entries
		self.offset = 0
		if self:IsOpen() then
			self:Draw()
		end
	end

	function picker:SetSelection(value, label)
		self.selected = value
		self:SetText(label .. "  v")
		if self:IsOpen() then
			self:Draw()
		end
	end

	function picker:IsOpen()
		return panel:IsShown()
	end

	function picker:Close()
		panel:Hide()
	end

	function picker:Open()
		onOpen()
		self:Draw()
		panel:Show()
	end

	return picker
end
