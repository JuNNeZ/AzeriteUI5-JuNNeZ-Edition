local _, ns = ...

local WIDTH, HEIGHT = 524, 468
local VIEW_HEIGHT = 358
local GOLD = "|cffffca75"
local MUTED = "|cffc4b19c"
local RESET = "|r"

local function Speech(line, kindIndex)
	local kind, text = line[kindIndex], line[kindIndex + 1]
	local command = kind == "EMOTE" and "/emote" or "/say"
	return command .. (line.darnassian and " [Darnassian] " or " ") .. text
end

local function AppendLines(text, lines, nextLine, showAsides)
	for index, line in ipairs(lines) do
		local marker = index == nextLine and GOLD .. "Next  " .. RESET or ""
		text[#text + 1] = ("%s%02d  %s"):format(marker, index, Speech(line, 1))
		if showAsides and line.aside then
			text[#text + 1] = MUTED .. "    Aside  " .. Speech(line.aside, 1) .. RESET
		end
		for _, reply in ipairs(line.replies or {}) do
			text[#text + 1] = MUTED .. "    " .. reply[1] .. "  " .. Speech(reply, 2) .. RESET
		end
		if line.question then
			text[#text + 1] = MUTED .. "    Ask the camp  /say " .. line.question .. RESET
		end
		text[#text + 1] = ""
	end
end

local function DelayTotal(lines, last)
	local seconds = 0
	for index = 1, last do
		local line = lines[index]
		seconds = seconds + ns.Performance.Delay(line[1], line[2])
	end
	return seconds
end

local function Duration(seconds)
	seconds = math.floor(seconds + 0.5)
	return ("%d:%02d"):format(math.floor(seconds / 60), seconds % 60)
end

function ns.BuildScriptPreview(performance, showAsides)
	local story = performance.story
	local position = performance.position
	local mainLength = #performance.lines
	local ending = story.endings
	local text = {}
	if story.perspectives then
		text[#text + 1] = GOLD .. "How he knows" .. RESET
		text[#text + 1] = story.perspectives[performance.voice]
		text[#text + 1] = ""
	end
	text[#text + 1] = GOLD .. "Main story" .. RESET
	text[#text + 1] = ""
	AppendLines(text, performance.lines, position, showAsides)
	text[#text + 1] = GOLD .. "Round off" .. RESET
	text[#text + 1] = ""
	AppendLines(text, ending.short, performance.ending == "short" and position - mainLength, showAsides)
	text[#text + 1] = GOLD .. "Tell more" .. RESET
	text[#text + 1] = ""
	AppendLines(text, ending.extended, performance.ending == "extended" and position - mainLength, showAsides)
	if #story.sources > 0 then
		text[#text + 1] = GOLD .. "Sources" .. RESET
		for _, source in ipairs(story.sources) do
			text[#text + 1] = source
		end
	end

	local mainPause = DelayTotal(performance.lines, mainLength)
	local shortPause = mainPause + DelayTotal(ending.short, #ending.short - 1)
	local extendedPause = mainPause + DelayTotal(ending.extended, #ending.extended - 1)
	return table.concat(text, "\n"),
		("Reading pauses  ·  Round off %s  ·  Tell more %s"):format(
			Duration(shortPause * performance.pace), Duration(extendedPause * performance.pace))
end

local function Button(parent, label, action)
	local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
	button:SetSize(85, 24)
	button:SetText(label)
	button:SetScript("OnClick", action)
	return button
end

function ns.CreateScriptPreview(parent)
	local panel = CreateFrame("Frame", nil, parent)
	panel:SetPoint("TOPLEFT", 8, -43)
	panel:SetSize(WIDTH, HEIGHT)
	panel:SetFrameLevel(parent:GetFrameLevel() + 12)
	panel:EnableMouse(true)
	panel:Hide()

	local background = panel:CreateTexture(nil, "BACKGROUND")
	background:SetAllPoints()
	background:SetColorTexture(0.083, 0.062, 0.050, 1)
	local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	title:SetPoint("TOPLEFT", 16, -13)
	local summary = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	summary:SetPoint("TOPLEFT", 16, -37)
	local close = Button(panel, "Back", function() panel:Hide() end)
	close:SetPoint("TOPRIGHT", -11, -9)

	local scroll = CreateFrame("ScrollFrame", nil, panel)
	scroll:SetPoint("TOPLEFT", 15, -59)
	scroll:SetSize(WIDTH - 30, VIEW_HEIGHT)
	scroll:EnableMouseWheel(true)
	local content = CreateFrame("Frame", nil, scroll)
	content:SetSize(WIDTH - 32, 1)
	scroll:SetScrollChild(content)
	local script = content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	script:SetPoint("TOPLEFT")
	script:SetWidth(WIDTH - 34)
	script:SetJustifyH("LEFT")
	script:SetJustifyV("TOP")
	script:SetWordWrap(true)
	script:SetSpacing(3)

	local offset, maximum = 0, 0
	local pageUp, pageDown
	local function ScrollTo(position)
		offset = math.max(0, math.min(maximum, position))
		scroll:SetVerticalScroll(offset)
		pageUp:SetEnabled(offset > 0)
		pageDown:SetEnabled(offset < maximum)
	end
	pageUp = Button(panel, "Page up", function() ScrollTo(offset - VIEW_HEIGHT + 35) end)
	pageUp:SetPoint("BOTTOMLEFT", 15, 12)
	pageDown = Button(panel, "Page down", function() ScrollTo(offset + VIEW_HEIGHT - 35) end)
	pageDown:SetPoint("BOTTOMRIGHT", -15, 12)
	scroll:SetScript("OnMouseWheel", function(_, delta) ScrollTo(offset - delta * 52) end)

	function panel:OpenScript(performance, showAsides)
		local fullText, estimate = ns.BuildScriptPreview(performance, showAsides)
		title:SetText(performance.story.title)
		summary:SetText(estimate)
		script:SetText(fullText)
		self:Show()
		local height = math.max(VIEW_HEIGHT, math.ceil(script:GetStringHeight()) + 4)
		content:SetHeight(height)
		maximum = height - VIEW_HEIGHT
		ScrollTo(0)
	end

	return panel
end
