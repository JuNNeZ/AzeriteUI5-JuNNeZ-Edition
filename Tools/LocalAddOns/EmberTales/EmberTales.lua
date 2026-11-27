local _, ns = ...
local Performance = ns.Performance
local stories = ns.stories
local voices = ns.voices
local performance, db, window
local Advance
local rehearsalRuns, liveRuns = {}, {}
local DARNASSIAN_LANGUAGE_ID = 2
local COMMON_LANGUAGE_ID = 7
local FULL_HEIGHT = 521
local CAMP_OFFSET = 58
local NEXT_SPEECH = { script = "darnassian", darnassian = "default", default = "script" }
local NEXT_SPEECH_LABEL = { script = "Script", darnassian = "Darnassian", default = "Default" }
local PACES = {
	{ label = "Natural", rate = 1 },
	{ label = "Brisk", rate = 0.75 },
	{ label = "Leisurely", rate = 1.30 }
}

local function StorySection(story)
	if story.warcraft then
		return "Warcraft I–III"
	elseif story.familiar then
		return "Famous figures"
	elseif story.campfire then
		return "Campfire moments"
	elseif story.personal then
		return "Personal memories"
	elseif story.adventure then
		return "Road adventures"
	end
	return "Lore and legends"
end

local storySearchText = {}
for _, story in ipairs(stories) do
	local gameTag = story.warcraft and (" wc%d"):format(story.warcraft) or ""
	storySearchText[story.id] = (story.title .. " " .. story.note .. " " .. StorySection(story) .. gameTag):lower()
end

local function UpdatePickButton()
	local results = window.storyResults
	window.pickStory:SetEnabled(#results > 1 or (#results == 1 and results[1] ~= performance.story))
end

local function StoryEntries(results)
	local entries = {}
	local currentSection
	for _, story in ipairs(results) do
		local section = StorySection(story)
		if section ~= currentSection then
			entries[#entries + 1] = { label = section }
			currentSection = section
		end
		entries[#entries + 1] = { label = story.title, value = story }
	end
	if #entries == 0 then
		entries[1] = { label = "No matching stories" }
	end
	return entries
end

local function UpdateStoryResults()
	local results = {}
	local query = window.search:GetText():lower()
	for _, story in ipairs(stories) do
		local matches = not window.favouritesOnly or db.favourites[story.id] == true
		if matches then
			for term in query:gmatch("%S+") do
				if not storySearchText[story.id]:find(term, 1, true) then
					matches = false
					break
				end
			end
		end
		if matches then
			results[#results + 1] = story
		end
	end
	window.storyResults = results
	window.favouritesFilter:SetText(window.favouritesOnly and "Favourites only" or "All stories")
	window.storyPicker:Close()
	window.storyPicker:SetEntries(StoryEntries(results))
	UpdatePickButton()
end

local function Texture(parent, layer, r, g, b, a)
	local texture = parent:CreateTexture(nil, layer)
	texture:SetColorTexture(r, g, b, a)
	return texture
end

local function Text(parent, font, x, y, width)
	local text = parent:CreateFontString(nil, "OVERLAY", font)
	text:SetPoint("TOPLEFT", x, y)
	text:SetWidth(width)
	text:SetJustifyH("LEFT")
	text:SetJustifyV("TOP")
	text:SetWordWrap(true)
	return text
end

local function Button(parent, label, x, y, width, action)
	local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
	button:SetPoint("TOPLEFT", x, y)
	button:SetSize(width, 24)
	button:SetText(label)
	button:SetScript("OnClick", action)
	return button
end

local function CanSpeakDarnassian()
	return C_ChatInfo and C_ChatInfo.CanPlayerSpeakLanguage
		and C_ChatInfo.CanPlayerSpeakLanguage(DARNASSIAN_LANGUAGE_ID)
end

local function SetChatLanguage(option, editBox)
	local defaultBox = DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.editBox
	local chatBox = editBox or defaultBox
	if not chatBox or not chatBox.SetGameLanguage then
		print("Ember Tales: The chat language selector is unavailable.")
		return
	end
	if option == "" or option == "status" then
		print("Ember Tales: Chat language is " .. (chatBox.language or GetDefaultLanguage()) .. ".")
		return
	end

	local language, languageID
	if option == "default" then
		language, languageID = GetDefaultLanguage()
	elseif option == "darnassian" or option == "common" then
		local requestedID = option == "darnassian" and DARNASSIAN_LANGUAGE_ID or COMMON_LANGUAGE_ID
		for index = 1, GetNumLanguages() do
			local name, id = GetLanguageByIndex(index)
			if id == requestedID then
				language, languageID = name, id
				break
			end
		end
	else
		print("Ember Tales: Use /tale language darnassian, common, default, or status.")
		return
	end
	if not language or not languageID then
		print("Ember Tales: This character can't speak " .. option .. ".")
		return
	end

	chatBox:SetGameLanguage(language, languageID)
	-- Match Blizzard's main chat menu as well when using a different chat tab.
	if defaultBox and defaultBox ~= chatBox and defaultBox.SetGameLanguage then
		defaultBox:SetGameLanguage(language, languageID)
	end
	print("Ember Tales: Chat language set to " .. language .. ".")
end

local function FormatLine(kind, text, darnassian)
	local command = kind == "EMOTE" and "/emote " or "/say "
	return command .. (darnassian and "[Darnassian] " or "") .. text
end

local function UsesDarnassian(kind, scripted)
	if kind ~= "SAY" then
		return false
	end
	if window.nextSpeech == "script" then
		return scripted
	end
	return window.nextSpeech == "darnassian"
end

local function Deliver(kind, text, darnassian)
	if window.rehearsing then
		window.last:SetText("Rehearsed  " .. FormatLine(kind, text, darnassian))
		return true
	end
	local send = C_ChatInfo and C_ChatInfo.SendChatMessage or SendChatMessage
	if not send then
		window.feedback:SetText("Chat is unavailable on this client.")
		return false
	end
	-- On characters without Darnassian, tell the line in their default language.
	local languageID = darnassian and CanSpeakDarnassian() and DARNASSIAN_LANGUAGE_ID or nil
	send(text, kind, languageID)
	window.last:SetText("To nearby chat  " .. FormatLine(kind, text, languageID ~= nil))
	return true
end

local function DeliverNext(kind, text, scripted)
	return Deliver(kind, text, UsesDarnassian(kind, scripted))
end

local function SetSuggestion(text, darnassian)
	window.suggestedText = text
	window.suggestion:SetShown(text ~= nil)
	window.suggestionPreview:SetText(text and FormatLine("SAY", text, darnassian) or "")
end

local function RefreshChatHints()
	local listening = window:IsShown() and not window.rehearsing and db.chatHints == true
		and ns.HasChatCues(performance:GetReplies(), performance.usedReplies)
	if listening == window.listeningForChat then
		return
	end
	window.listeningForChat = listening
	if listening then
		window:RegisterEvent("CHAT_MSG_SAY")
	else
		window:UnregisterEvent("CHAT_MSG_SAY")
		SetSuggestion(nil)
	end
end

local function OnNearbySpeech(_, _, message, author, ...)
	local languageID = select(8, ...)
	local ownName = UnitName("player")
	if issecretvalue and (issecretvalue(message) or issecretvalue(author) or issecretvalue(ownName)
		or issecretvalue(languageID)) then
		return
	end
	if type(message) ~= "string" or type(author) ~= "string" or not ownName
		or author:match("^[^-]+") == ownName then
		return
	end
	if type(languageID) == "number" and languageID > 0 and C_ChatInfo and C_ChatInfo.CanPlayerSpeakLanguage
		and not C_ChatInfo.CanPlayerSpeakLanguage(languageID) then
		return
	end
	local text, darnassian = ns.SuggestChatReply(performance.voice, performance:GetReplies(), performance.usedReplies, message)
	if text then
		SetSuggestion(text, darnassian)
	end
end

local function UpdateClock()
	local line = performance:GetLine()
	local remaining = math.ceil(performance:Remaining(GetTime()))
	local ready = line ~= nil and not performance.pausedFor and remaining == 0
	local status
	if performance.pausedFor then
		status = "Paused  ·  %ds held"
	elseif remaining > 0 then
		status = "Reading pause  ·  %ds"
	elseif line then
		status = "Ready"
	elseif performance:CanChooseEnding() then
		status = "Waiting for your choice"
	else
		status = "Story complete"
	end
	if window.clockStatus ~= status or window.clockSeconds ~= remaining then
		window.clockStatus, window.clockSeconds = status, remaining
		window.clock:SetText(status:format(remaining))
	end
	if window.clockReady ~= ready then
		window.clockReady = ready
		window.next:SetEnabled(ready)
	end
	return remaining
end

local function StopClock()
	if window.clockRunning then
		window:SetScript("OnUpdate", nil)
		window.clockRunning = false
	end
end

local function TickClock(_, delta)
	window.clockElapsed = window.clockElapsed + delta
	if window.clockElapsed < 0.15 then
		return
	end
	window.clockElapsed = 0
	local remaining = UpdateClock()
	if window.rehearsing and window.autoPlaying and window.clockReady then
		if not window.scriptView:IsShown() and not window.draft:HasFocus() and not window.search:HasFocus()
			and not window.storyPicker:IsOpen() and not window.voicePicker:IsOpen() then
			Advance()
		end
	elseif remaining == 0 then
		StopClock()
	end
end

local function SyncClock()
	local remaining = UpdateClock()
	if window:IsShown() and not performance.pausedFor and (remaining > 0 or window.autoPlaying) then
		if not window.clockRunning then
			window.clockRunning, window.clockElapsed = true, 0
			window:SetScript("OnUpdate", TickClock)
		end
	else
		StopClock()
	end
end

local function Refresh()
	local story = performance.story
	local line = performance:GetLine()
	local choosingEnding = not line and performance:CanChooseEnding()
	local replies = performance:GetReplies()
	local aside = db.showAsides ~= false and performance:GetAside()
	local question = performance:GetQuestion()
	window.note:SetText(story.note)
	window.favourite:SetText(db.favourites[story.id] and "Remove favourite" or "Save favourite")
	UpdatePickButton()
	window.pace:SetText("Pace: " .. PACES[db.pace].label)
	if choosingEnding then
		window.position:SetText("A good place to stop")
		window.preview:SetText("Round off here, or tell the rest if the camp wants to hear it.")
	elseif line then
		local position = performance.position
		local count = #performance.lines
		if position <= count then
			window.position:SetText(("Next line  ·  %d / %d"):format(position, count))
		else
			local title = performance.ending == "short" and "Closing line" or "Extra chapter"
			window.position:SetText(("%s  ·  %d / %d"):format(title, position - count, #story.endings[performance.ending]))
		end
		local darnassian = UsesDarnassian(line[1], line.darnassian)
		window.preview:SetText(FormatLine(line[1], line[2], darnassian and (window.rehearsing or CanSpeakDarnassian())))
	else
		window.position:SetText("Last line reached")
		window.preview:SetText("You have reached the end of this story.")
	end
	window.roundOff:SetShown(choosingEnding)
	window.tellMore:SetShown(choosingEnding)
	window.pause:SetText(performance.pausedFor and "Resume" or "Pause")
	window.mode:SetText(window.rehearsing and "Mode: Rehearsal" or "Mode: Live chat")
	window.asideToggle:SetText(db.showAsides == false and "Personal asides: Off" or "Personal asides: On")
	window.chatHints:SetShown(not window.rehearsing)
	window.chatHints:SetText(db.chatHints == true and "Chat hints: On" or "Chat hints: Off")
	window.next:SetText(window.rehearsing and "Rehearse next" or "Send next")
	window.auto:SetShown(window.rehearsing)
	window.auto:SetText(window.autoPlaying and "Auto rehearsal: On" or "Auto rehearsal: Off")
	local canUseDarnassian = window.rehearsing or not not CanSpeakDarnassian()
	window.darnassian:SetEnabled(canUseDarnassian)
	local nextIsSpeech = line ~= nil and line[1] == "SAY"
	window.nextSpeechButton:SetShown(nextIsSpeech)
	window.nextSpeechButton:SetEnabled(canUseDarnassian)
	window.nextSpeechButton:SetText("Next speech: " .. NEXT_SPEECH_LABEL[window.nextSpeech])
	for index, button in ipairs(window.replies) do
		local reply = replies and replies[index]
		button:SetShown(reply ~= nil)
		button:SetEnabled(reply ~= nil and not performance.usedReplies[index])
		if reply then
			button:SetText(reply[1])
		end
	end
	window.aside:SetShown(not not aside)
	window.aside:SetEnabled(not performance.usedAside)
	window.ask:SetShown(question ~= nil)
	window.ask:SetEnabled(not performance.usedQuestion)
	window.replyLabel:SetText((replies or aside or question) and "Optional responses to the last line" or "Optional responses appear after some lines.")
	RefreshChatHints()
	SyncClock()
end

local function SelectStory(story, voice, restart)
	window.scriptView:Hide()
	voice = voice or db.voices[story.id]
	if voice ~= story.voice and not story.variants[voice] then
		voice = story.voice
	end
	-- The original voice uses the key saved by earlier versions.
	local key = voice == story.voice and story.id or story.id .. ":" .. voice
	db.story = story.id
	db.voices[story.id] = voice
	window.autoPlaying = false
	window.nextSpeech = "script"
	local runs = window.rehearsing and rehearsalRuns or liveRuns
	if restart then
		runs[key] = nil
		if not window.rehearsing then
			db.positions[key] = nil
			db.endings[key] = nil
		end
	end
	local previous = performance
	local now = GetTime()
	performance = runs[key]
	if not performance then
		local position = not window.rehearsing and db.positions[key]
		local ending = not window.rehearsing and db.endings[key]
		performance = Performance.New(story, position, voice, ending)
		runs[key] = performance
	end
	performance:SetPace(PACES[db.pace].rate, now)
	window.bookmark = key
	if previous and previous ~= performance and not previous.pausedFor and previous:Remaining(now) > 0 then
		previous:TogglePause(now)
	end
	window.last:SetText("")
	window.feedback:SetText("")
	SetSuggestion(nil)
	window.storyPicker:SetSelection(story, story.title)
	for _, item in ipairs(voices) do
		if item.id == voice then
			window.voicePicker:SetSelection(voice, item.label)
			window.context:SetText(story.title .. "  ·  " .. item.label)
			break
		end
	end
	Refresh()
end

Advance = function()
	window.feedback:SetText("")
	if performance:Next(GetTime(), DeliverNext) then
		window.nextSpeech = "script"
		SetSuggestion(nil)
		if not window.rehearsing then
			db.positions[window.bookmark] = performance.position
		end
		if not performance:GetLine() then
			window.autoPlaying = false
		end
	end
	Refresh()
end

local function ChooseEnding(ending)
	if performance:ChooseEnding(ending) and not window.rehearsing then
		db.endings[window.bookmark] = performance.ending
	end
	Refresh()
end

local function PickAnotherStory()
	local choices = {}
	for _, story in ipairs(window.storyResults) do
		if story ~= performance.story then
			choices[#choices + 1] = story
		end
	end
	if #choices > 0 then
		SelectStory(choices[math.random(#choices)])
	end
end

local function ApplyCampView()
	local compact = db.campView == true
	if compact then
		window.storyPicker:Close()
		window.voicePicker:Close()
		window.search:ClearFocus()
	end
	for _, control in ipairs(window.libraryControls) do
		control:SetShown(not compact)
	end
	window.context:SetShown(compact)
	window.campViewButton:SetText(compact and "Library" or "Camp view")
	window.stage:ClearAllPoints()
	window.stage:SetPoint("TOPLEFT", window, "TOPLEFT", 0, compact and CAMP_OFFSET or 0)
	window:SetHeight(compact and FULL_HEIGHT - CAMP_OFFSET or FULL_HEIGHT)
end

local function BuildWindow()
	window = CreateFrame("Frame", nil, UIParent)
	window.storyResults = stories
	window.favouritesOnly = false
	window.clockRunning = false
	window:SetSize(540, FULL_HEIGHT)
	window:SetPoint("CENTER")
	window:SetFrameStrata("DIALOG")
	window:SetClampedToScreen(true)
	window:EnableMouse(true)
	window:SetMovable(true)
	window:Hide()

	local edge = Texture(window, "BACKGROUND", 0.43, 0.27, 0.15, 1)
	edge:SetAllPoints()
	local background = Texture(window, "BORDER", 0.073, 0.055, 0.044, 0.99)
	background:SetPoint("TOPLEFT", 1, -1)
	background:SetPoint("BOTTOMRIGHT", -1, 1)
	local stage = CreateFrame("Frame", nil, window)
	stage:SetSize(540, FULL_HEIGHT)
	window.stage = stage
	local previewPlate = Texture(stage, "ARTWORK", 0.14, 0.095, 0.065, 1)
	previewPlate:SetPoint("TOPLEFT", 16, -122)
	previewPlate:SetSize(508, 110)

	local header = CreateFrame("Frame", nil, window)
	header:SetPoint("TOPLEFT")
	header:SetSize(500, 42)
	header:EnableMouse(true)
	header:RegisterForDrag("LeftButton")
	header:SetScript("OnDragStart", function() window:StartMoving() end)
	header:SetScript("OnDragStop", function() window:StopMovingOrSizing() end)
	local title = Text(header, "GameFontNormalLarge", 18, -13, 120)
	title:SetText("Ember Tales")
	window.campViewButton = Button(header, "", 143, -9, 108, function()
		db.campView = not db.campView
		if window.scriptView:IsShown() then
			window.scriptView:Hide()
		else
			ApplyCampView()
		end
	end)
	Button(header, "Read script", 257, -9, 100, function()
		if window.scriptView:IsShown() then
			window.scriptView:Hide()
			return
		end
		window.storyPicker:Close()
		window.voicePicker:Close()
		window.search:ClearFocus()
		window.draft:ClearFocus()
		local now = GetTime()
		if not performance.pausedFor and (window.autoPlaying or performance:Remaining(now) > 0) then
			performance:TogglePause(now)
			Refresh()
		end
		window:SetHeight(FULL_HEIGHT)
		window.scriptView:OpenScript(performance, db.showAsides ~= false)
	end)
	window.pickStory = Button(header, "Pick for me", 361, -9, 122, PickAnotherStory)

	local close = CreateFrame("Button", nil, window, "UIPanelCloseButton")
	close:SetPoint("TOPRIGHT", -3, -3)
	close:SetScript("OnClick", function() window:Hide() end)

	window.storyPicker = ns.CreatePicker(window, 16, -43, 264, function(story)
		SelectStory(story)
	end, function()
		window.voicePicker:Close()
	end)
	window.storyPicker:SetEntries(StoryEntries(window.storyResults))
	window.voicePicker = ns.CreatePicker(window, 288, -43, 236, function(voice)
		SelectStory(performance.story, voice)
	end, function()
		window.storyPicker:Close()
	end)
	local voiceEntries = { { label = "Point of view" } }
	for _, voice in ipairs(voices) do
		voiceEntries[#voiceEntries + 1] = { label = voice.label, value = voice.id }
	end
	window.voicePicker:SetEntries(voiceEntries)
	local findLabel = Text(window, "GameFontNormalSmall", 18, -84, 30)
	findLabel:SetText("Find")
	window.search = CreateFrame("EditBox", nil, window, "InputBoxTemplate")
	window.search:SetPoint("TOPLEFT", 54, -76)
	window.search:SetSize(224, 23)
	window.search:SetMaxBytes(80)
	window.search:SetAutoFocus(false)
	window.search:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
	window.search:SetScript("OnEnterPressed", function(self)
		self:ClearFocus()
		local results = window.storyResults or stories
		if #results == 1 then
			SelectStory(results[1])
		else
			window.storyPicker:Open()
		end
	end)
	window.favourite = Button(window, "", 288, -76, 120, function()
		local id = performance.story.id
		db.favourites[id] = not db.favourites[id] or nil
		if window.favouritesOnly then
			UpdateStoryResults()
		end
		Refresh()
	end)
	window.favouritesFilter = Button(window, "All stories", 414, -76, 110, function()
		window.favouritesOnly = not window.favouritesOnly
		UpdateStoryResults()
	end)
	window.search:SetScript("OnTextChanged", UpdateStoryResults)
	window.note = Text(window, "GameFontDisableSmall", 18, -102, 504)
	window.context = Text(stage, "GameFontNormal", 18, -102, 504)
	window.libraryControls = {
		window.storyPicker, window.voicePicker, findLabel, window.search,
		window.favourite, window.favouritesFilter, window.note, window.pickStory
	}
	window.position = Text(stage, "GameFontNormalSmall", 28, -134, 300)
	window.clock = Text(stage, "GameFontNormalSmall", 310, -134, 202)
	window.clock:SetJustifyH("RIGHT")
	window.preview = Text(stage, "GameFontHighlight", 28, -158, 484)
	window.preview:SetSpacing(4)
	window.roundOff = Button(stage, "Round off", 28, -196, 108, function() ChooseEnding("short") end)
	window.tellMore = Button(stage, "Tell more", 142, -196, 108, function() ChooseEnding("extended") end)

	window.next = Button(stage, "", 16, -242, 132, Advance)
	window.pause = Button(stage, "Pause", 154, -242, 88, function()
		performance:TogglePause(GetTime())
		Refresh()
	end)
	window.rehearsing = true
	window.mode = Button(stage, "", 248, -242, 140, function()
		window.rehearsing = not window.rehearsing
		SelectStory(performance.story)
	end)
	Button(stage, "Start over", 394, -242, 130, function()
		SelectStory(performance.story, performance.voice, true)
	end)
	window.asideToggle = Button(stage, "", 16, -272, 176, function()
		db.showAsides = db.showAsides == false
		Refresh()
	end)
	window.pace = Button(stage, "", 198, -272, 138, function()
		db.pace = db.pace % #PACES + 1
		performance:SetPace(PACES[db.pace].rate, GetTime())
		Refresh()
	end)
	window.chatHints = Button(stage, "", 342, -272, 182, function()
		db.chatHints = db.chatHints ~= true
		Refresh()
	end)
	window.auto = Button(stage, "", 342, -272, 182, function()
		window.autoPlaying = not window.autoPlaying and performance:GetLine() ~= nil
		Refresh()
	end)

	window.replyLabel = Text(stage, "GameFontNormalSmall", 18, -308, 324)
	window.ask = Button(stage, "Ask the camp", 364, -298, 160, function()
		window.feedback:SetText("")
		performance:Ask(GetTime(), Deliver)
		Refresh()
	end)
	window.ask:SetScript("OnEnter", function(self)
		local question = performance:GetQuestion()
		if question then
			GameTooltip:SetOwner(self, "ANCHOR_TOP")
			GameTooltip:AddLine(question, 1, 1, 1, true)
			GameTooltip:Show()
		end
	end)
	window.ask:SetScript("OnLeave", function() GameTooltip:Hide() end)
	window.ask:SetScript("OnHide", function(self)
		if GameTooltip:IsOwned(self) then
			GameTooltip:Hide()
		end
	end)
	window.replies = {}
	for index = 1, 2 do
		local replyIndex = index
		local replyButton = Button(stage, "", 16 + (index - 1) * 174, -324, 168, function()
			window.feedback:SetText("")
			if performance:Reply(replyIndex, GetTime(), Deliver) then
				SetSuggestion(nil)
			end
			Refresh()
		end)
		window.replies[index] = replyButton
		replyButton:SetScript("OnEnter", function(self)
			local replies = performance:GetReplies()
			local reply = replies and replies[replyIndex]
			if not reply then
				return
			end
			GameTooltip:SetOwner(self, "ANCHOR_TOP")
			GameTooltip:AddLine(FormatLine(reply[2], reply[3], reply.darnassian), 1, 1, 1, true)
			GameTooltip:Show()
		end)
		replyButton:SetScript("OnLeave", function() GameTooltip:Hide() end)
		replyButton:SetScript("OnHide", function(self)
			if GameTooltip:IsOwned(self) then
				GameTooltip:Hide()
			end
		end)
	end

	window.aside = Button(stage, "Personal aside", 364, -324, 160, function()
		performance:Aside(GetTime(), Deliver)
		Refresh()
	end)
	window.aside:SetScript("OnEnter", function(self)
		local aside = performance:GetAside()
		if aside then
			GameTooltip:SetOwner(self, "ANCHOR_TOP")
			GameTooltip:AddLine(FormatLine(aside[1], aside[2], aside.darnassian), 1, 1, 1, true)
			GameTooltip:Show()
		end
	end)
	window.aside:SetScript("OnLeave", function() GameTooltip:Hide() end)
	window.aside:SetScript("OnHide", function(self)
		if GameTooltip:IsOwned(self) then
			GameTooltip:Hide()
		end
	end)

	local draftLabel = Text(stage, "GameFontNormalSmall", 18, -359, 504)
	draftLabel:SetText("Your own interlude")
	window.nextSpeechButton = Button(stage, "", 342, -350, 182, function()
		window.nextSpeech = NEXT_SPEECH[window.nextSpeech]
		Refresh()
	end)
	window.nextSpeechButton:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_TOP")
		GameTooltip:AddLine("Choose the language of the next story line only.", 1, 1, 1, true)
		GameTooltip:AddLine("Script follows the story. Default uses your character's default language.", 0.8, 0.8, 0.8, true)
		GameTooltip:Show()
	end)
	window.nextSpeechButton:SetScript("OnLeave", function() GameTooltip:Hide() end)
	window.nextSpeechButton:SetScript("OnHide", function(self)
		if GameTooltip:IsOwned(self) then
			GameTooltip:Hide()
		end
	end)
	local draft = CreateFrame("EditBox", nil, stage, "InputBoxTemplate")
	draft:SetPoint("TOPLEFT", 23, -377)
	draft:SetSize(242, 24)
	draft:SetAutoFocus(false)
	draft:SetMaxBytes(240)
	draft:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
	draft:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
	window.draft = draft
	local function Insert(kind, darnassian)
		if darnassian and not window.rehearsing and not CanSpeakDarnassian() then
			window.feedback:SetText("This character can't speak Darnassian.")
			return
		end
		local text, errorMessage = Performance.CleanLine(draft:GetText())
		window.feedback:SetText(errorMessage or "")
		if text and performance:Insert(kind, text, GetTime(), Deliver, darnassian) then
			draft:SetText("")
			draft:ClearFocus()
			SetSuggestion(nil)
		end
		SyncClock()
	end
	Button(stage, "Say", 276, -377, 63, function() Insert("SAY") end)
	window.darnassian = Button(stage, "Darnassian", 345, -377, 100, function() Insert("SAY", true) end)
	Button(stage, "Emote", 451, -377, 73, function() Insert("EMOTE") end)
	window.feedback = Text(stage, "GameFontNormalSmall", 18, -409, 504)
	window.suggestion = Button(stage, "Use suggestion", 16, -430, 150, function()
		if not window.suggestedText then
			return
		end
		if draft:GetText():find("%S") then
			window.feedback:SetText("Clear your current draft before using a suggestion.")
			return
		end
		draft:SetText(window.suggestedText)
		draft:SetFocus()
		window.feedback:SetText("")
		SetSuggestion(nil)
	end)
	window.suggestionPreview = Text(stage, "GameFontHighlightSmall", 176, -432, 348)
	window.suggestionPreview:SetMaxLines(3)
	window.last = Text(stage, "GameFontDisableSmall", 18, -477, 504)
	window.last:SetMaxLines(3)
	window.scriptView = ns.CreateScriptPreview(window)
	window.scriptView:SetScript("OnHide", ApplyCampView)
	ApplyCampView()
	window:SetScript("OnEvent", OnNearbySpeech)

	window:SetScript("OnHide", function()
		window.scriptView:Hide()
		window.storyPicker:Close()
		window.voicePicker:Close()
		draft:ClearFocus()
		window.search:ClearFocus()
		window:StopMovingOrSizing()
		window.autoPlaying = false
		StopClock()
		window:UnregisterEvent("CHAT_MSG_SAY")
		window.listeningForChat = false
		SetSuggestion(nil)
		if not performance.pausedFor then
			performance:TogglePause(GetTime())
		end
	end)
	window:SetScript("OnShow", Refresh)
end

BINDING_HEADER_EMBERTALES = "Ember Tales"
BINDING_NAME_EMBERTALES_NEXT = "Tell next Ember Tales line"
function EmberTales_SendNext()
	if window and window:IsShown() and not window.scriptView:IsShown() and not window.draft:HasFocus()
		and not window.search:HasFocus()
		and not window.storyPicker:IsOpen() and not window.voicePicker:IsOpen() then
		Advance()
	end
end

SLASH_EMBERTALES1 = "/tale"
SLASH_EMBERTALES2 = "/embertales"
SlashCmdList.EMBERTALES = function(message, editBox)
	local command, option = (message or ""):lower():match("^%s*(%S*)%s*(.-)%s*$")
	if command == "language" then
		SetChatLanguage(option, editBox)
		return
	end
	if not window then
		if type(EmberTalesDB) ~= "table" then
			EmberTalesDB = {}
		end
		db = EmberTalesDB
		if type(db.positions) ~= "table" then
			db.positions = {}
		end
		if type(db.voices) ~= "table" then
			db.voices = {}
		end
		if type(db.endings) ~= "table" then
			db.endings = {}
		end
		if type(db.favourites) ~= "table" then
			db.favourites = {}
		end
		if type(db.pace) ~= "number" or not PACES[db.pace] then
			db.pace = 1
		end
		local selected = stories[1]
		for _, story in ipairs(stories) do
			if story.id == db.story then
				selected = story
				break
			end
		end
		BuildWindow()
		SelectStory(selected)
	end
	window:SetShown(not window:IsShown())
end
