local root = "Tools/LocalAddOns/EmberTales/"
local ns = {}
assert(loadfile(root .. "Stories.lua"))("EmberTales", ns)
assert(loadfile(root .. "StoryVoices.lua"))("EmberTales", ns)
assert(loadfile(root .. "Adventures.lua"))("EmberTales", ns)
assert(loadfile(root .. "PersonalStories.lua"))("EmberTales", ns)
assert(loadfile(root .. "CampfireStories.lua"))("EmberTales", ns)
assert(loadfile(root .. "FamiliarFigures.lua"))("EmberTales", ns)
assert(loadfile(root .. "WarcraftStories.lua"))("EmberTales", ns)
assert(loadfile(root .. "Endings.lua"))("EmberTales", ns)
assert(loadfile(root .. "Performance.lua"))("EmberTales", ns)
assert(loadfile(root .. "ChatHints.lua"))("EmberTales", ns)
assert(loadfile(root .. "Picker.lua"))("EmberTales", ns)
assert(loadfile(root .. "ScriptPreview.lua"))("EmberTales", ns)

local Performance = ns.Performance
assert(#ns.stories == 40 and #ns.voices == 3)
local function CheckLines(lines)
	for _, line in ipairs(lines) do
		assert(line[1] == "SAY" or line[1] == "EMOTE")
		assert(Performance.CleanLine(line[2]) == line[2])
		if line.question then
			assert(Performance.CleanLine(line.question) == line.question)
		end
		assert(#(line.replies or {}) <= 2)
		if line.aside then
			assert(Performance.CleanLine(line.aside[2]) == line.aside[2])
		end
		for _, reply in ipairs(line.replies or {}) do
			assert(reply[2] == "SAY" or reply[2] == "EMOTE")
			assert(Performance.CleanLine(reply[3]) == reply[3])
			if reply.cues then
				assert(#reply.cues[1] > 0 and #reply.cues[2] > 0)
			end
		end
	end
end

local adventureCount, storyIDs = 0, {}
local famousCount = 0
local warcraftCounts = { 0, 0, 0 }
local shortest, longest = math.huge, 0
for _, story in ipairs(ns.stories) do
	assert(not storyIDs[story.id])
	storyIDs[story.id] = true
	if story.adventure then
		assert(story.voice == "memory")
		adventureCount = adventureCount + 1
	end
	assert(story.personal or story.campfire or #story.sources > 0)
	if story.familiar then famousCount = famousCount + 1 end
	if story.warcraft then warcraftCounts[story.warcraft] = warcraftCounts[story.warcraft] + 1 end
	assert(#story.endings.short == 1 and #story.endings.extended == 4)
	CheckLines(story.endings.short)
	CheckLines(story.endings.extended)
	local scripts = {}
	for _, voice in ipairs(ns.voices) do
		local lines = Performance.New(story, 1, voice.id).lines
		assert(#lines >= 4 and not scripts[lines])
		scripts[lines] = true
		CheckLines(lines)
		if story.familiar or story.warcraft then
			assert(story.perspectives[voice.id] and lines[#lines].question)
			assert(lines[#lines].replies[1][1] == "How do you know?")
			local pauseSeconds = 0
			for _, line in ipairs(lines) do pauseSeconds = pauseSeconds + Performance.Delay(line[1], line[2]) end
			shortest = math.min(shortest, pauseSeconds)
			longest = math.max(longest, pauseSeconds)
		end
		for _, choice in ipairs({ "short", "extended" }) do
			local ending = Performance.New(story, #lines + 1, voice.id)
			assert(ending:CanChooseEnding() and not ending:GetLine())
			assert(ending:ChooseEnding(choice))
			for index, line in ipairs(story.endings[choice]) do
				assert(ending:GetLine() == line)
				assert(ending:Next(index * 30, function() return true end))
			end
			assert(not ending:CanChooseEnding() and not ending:GetLine())
			assert(not ending:ChooseEnding("extended"))
			local restored = Performance.New(story, ending.position, voice.id, choice)
			assert(restored.position == ending.position and not restored:GetLine())
		end
	end
end
assert(adventureCount == 9)
assert(famousCount == 7 and shortest >= 45 and longest <= 65)
assert(warcraftCounts[1] == 2 and warcraftCounts[2] == 3 and warcraftCounts[3] == 4)
assert(Performance.CleanLine("   one\n  line ") == "one line")
assert(not Performance.CleanLine("  "))
assert(not Performance.CleanLine("word |Hlink"))
assert(not Performance.CleanLine(string.rep("é", 121)))
assert(Performance.Delay("SAY", ns.stories[1].lines[2][2]) > Performance.Delay("EMOTE", ns.stories[1].lines[1][2]))

local sent = {}
local function Deliver(kind, text)
	sent[#sent + 1] = { kind, text }
	return true
end
local function Refuse()
	return false
end

local story = ns.stories[1]
local review = Performance.New(story, 3)
local previewText, naturalEstimate = ns.BuildScriptPreview(review, true)
assert(previewText:find("03  /say", 1, true) and previewText:find("Next", 1, true))
assert(previewText:find("[Darnassian]", 1, true) and previewText:find("Round off", 1, true))
assert(previewText:find("Tell more", 1, true) and previewText:find("Aside", 1, true))
review:SetPace(0.75, 0)
local withoutAsides, briskEstimate = ns.BuildScriptPreview(review, false)
assert(not withoutAsides:find("Aside", 1, true) and briskEstimate ~= naturalEstimate)
local performance = Performance.New(story, 0)
local paced = Performance.New(story, 1)
paced:WaitAfter("SAY", "One short test line.", 10)
local naturalDelay = paced:Remaining(10)
paced:SetPace(0.75, 10)
assert(math.abs(paced:Remaining(10) - naturalDelay * 0.75) < 0.001)
paced:TogglePause(10)
paced:SetPace(1.30, 50)
assert(math.abs(paced:Remaining(50) - naturalDelay * 1.30) < 0.001)
assert(paced:Remaining(50) == paced:Remaining(100))
assert(not performance:Next(1, Refuse) and performance.position == 1)
assert(performance:Next(1, Deliver) and performance.position == 2 and sent[1][1] == "EMOTE")
assert(not performance:Next(2, Deliver) and #sent == 1)
assert(performance:Next(30, Deliver) and performance.position == 3)
assert(performance:Next(60, Deliver) and performance.position == 4 and #sent == 3)
performance:TogglePause(61)
local held = performance:Remaining(61)
assert(held > 0 and performance:Remaining(100) == held)
assert(not performance:Next(100, Deliver))
assert(not performance:Reply(1, 100, Refuse))
assert(performance:Reply(1, 100, Deliver))
assert(not performance:Reply(1, 100, Deliver))
assert(sent[4][2]:find("Gorak", 1, true) and performance.position == 4)
assert(performance:Insert("EMOTE", "takes another sip.", 101, Deliver))
assert(sent[5][1] == "EMOTE" and performance.position == 4)
local resumeDelay = performance:Remaining(101)
assert(resumeDelay >= held)
performance:TogglePause(102)
assert(not performance:Next(102, Deliver))
assert(performance:Next(103 + resumeDelay, Deliver) and sent[6][2] == story.lines[4][2])
assert(not performance:GetReplies() and not performance:Reply(1, 200, Deliver))

local bookmarked = Performance.New(story, #story.lines)
assert(bookmarked:Next(1, Deliver))
assert(not bookmarked:Next(60, Deliver))
assert(Performance.New(story, bookmarked.position):CanChooseEnding())
assert(not bookmarked:ChooseEnding("invalid"))
-- Exercise the actual slash command and button handlers with a fake clock and chat.
local widgets = {}
local widgetMethods = {}
function widgetMethods:SetScript(event, handler) self[event] = handler end
function widgetMethods:SetText(value)
	local changed = self.text ~= value
	self.text = value
	local handler = rawget(self, "OnTextChanged")
	if changed and handler then handler(self, true) end
end
function widgetMethods:GetText() return rawget(self, "text") or "" end
function widgetMethods:GetStringHeight()
	local _, newlines = self:GetText():gsub("\n", "")
	return (newlines + 1) * 18
end
function widgetMethods:SetVerticalScroll(offset) self.verticalScroll = offset end
function widgetMethods:SetSize(width, height) self.width, self.height = width, height end
function widgetMethods:SetHeight(height) self.height = height end
function widgetMethods:SetPoint(...) self.point = { ... } end
function widgetMethods:SetMaxBytes(limit) self.byteLimit = limit end
function widgetMethods:SetEnabled(enabled) self.enabled = not not enabled end
function widgetMethods:IsEnabled() return self.enabled end
function widgetMethods:IsShown() return self.shown end
function widgetMethods:HasFocus() return self.focused == true end
function widgetMethods:ClearFocus() self.focused = false end
function widgetMethods:SetFocus() self.focused = true end
function widgetMethods:RegisterEvent(event)
	self.events[event] = true
end
function widgetMethods:UnregisterEvent(event)
	self.events[event] = nil
end
function widgetMethods:GetFrameLevel() return 1 end
function widgetMethods:SetShown(shown)
	if self.shown == shown then
		return
	end
	self.shown = shown
	local handler = shown and self.OnShow or not shown and self.OnHide
	if handler then
		handler(self)
	end
end
function widgetMethods:Hide() self:SetShown(false) end
function widgetMethods:Show() self:SetShown(true) end
local function NewWidget(kind)
	local widget = setmetatable({ kind = kind, shown = true, enabled = true, events = {} }, {
		__index = function(_, key)
			return widgetMethods[key] or function() end
		end
	})
	widgets[#widgets + 1] = widget
	return widget
end
widgetMethods.CreateTexture = function() return NewWidget("Texture") end
widgetMethods.CreateFontString = function() return NewWidget("FontString") end
function CreateFrame(kind, _, parent, template)
	assert(kind ~= "DropdownButton" and template ~= "WowStyle1DropdownTemplate")
	local widget = NewWidget(kind)
	widget.parent = parent
	return widget
end
local time = 1
function GetTime() return time end
local public = {}
local speaksDarnassian = true
C_ChatInfo = {
	CanPlayerSpeakLanguage = function(languageID)
		return languageID == 7 or (languageID == 2 and speaksDarnassian)
	end,
	SendChatMessage = function(message, kind, languageID)
		public[#public + 1] = { kind, message, languageID }
	end
}
SlashCmdList = {}
GameTooltip = { IsOwned = function() return false end, Hide = function() end }
assert(loadfile(root .. "EmberTales.lua"))("EmberTales", ns)
SlashCmdList.EMBERTALES()
local frame = widgets[1]
local function Find(kind, label)
	for _, widget in ipairs(widgets) do
		if widget.kind == kind and (not label or widget.text == label) then
			return widget
		end
	end
	error("Missing " .. kind .. " " .. (label or ""))
end
local function FindEditBox(limit)
	for _, widget in ipairs(widgets) do
		if widget.kind == "EditBox" and widget.byteLimit == limit then
			return widget
		end
	end
	error("Missing edit box")
end
local function Click(label)
	local button = Find("Button", label)
	assert(button.enabled and button.shown, label .. " is not clickable")
	button:OnClick()
end
local function Tick(seconds)
	time = time + seconds
	local update = rawget(frame, "OnUpdate")
	if update then update(frame, 0.2) end
end
local function FindPicker()
	for _, widget in ipairs(widgets) do
		if rawget(widget, "Open") and rawget(widget, "entries") then
			return widget
		end
	end
	error("Missing story picker")
end
local function Choice(picker, label)
	local section
	for _, entry in ipairs(picker.entries) do
		if not entry.value then
			section = entry.label
		elseif entry.label == label then
			return entry, section
		end
	end
end
local function Pick(label)
	for _, picker in ipairs(widgets) do
		if rawget(picker, "Open") and rawget(picker, "entries") then
			local choice = Choice(picker, label)
			if choice then
				if picker.selected == choice.value then
					return
				end
				picker:Open()
				while picker.offset > 0 do
					picker.panel:OnMouseWheel(1)
				end
				for _ = 1, #picker.entries do
					for _, row in ipairs(picker.rows) do
						if row:IsShown() and row.entry == choice then
							assert(row.enabled)
							row:OnClick()
							assert(picker.selected == choice.value and not picker:IsOpen())
							return
						end
					end
					picker.panel:OnMouseWheel(-1)
				end
				error("Choice cannot be scrolled into view: " .. label)
			end
		end
	end
	error("Missing dropdown choice " .. label)
end

Click("Rehearse next")
assert(#public == 0 and not EmberTalesDB.positions.hyjal)
Click("Mode: Rehearsal")
Click("Send next")
assert(public[1][2] == story.lines[1][2] and EmberTalesDB.positions.hyjal == 2)
assert(not Find("Button", "Send next").enabled)
Tick(30)
Click("Send next")
Tick(30)
Click("Send next")
assert(public[2][2]:find("shan'do", 1, true) and public[2][3] == nil)
Click("Pause")
Tick(60)
assert(#public == 3 and not Find("Button", "Send next").enabled)
Click("The orc's name")
assert(public[4][2]:find("Gorak", 1, true) and EmberTalesDB.positions.hyjal == 4)
local draft = FindEditBox(240)
draft:SetText("passes the cup to the traveller.")
Click("Emote")
assert(public[5][1] == "EMOTE" and draft:GetText() == "" and EmberTalesDB.positions.hyjal == 4)
Click("Resume")
SlashCmdList.EMBERTALES()
assert(not frame:IsShown())
time = time + 60
SlashCmdList.EMBERTALES()
assert(not Find("Button", "Send next").enabled)
Click("Resume")
Tick(30)
Click("Send next")
assert(public[6][2] == story.lines[4][2] and EmberTalesDB.positions.hyjal == 5)
draft:SetText("Ishnu-alah.")
Click("Darnassian")
assert(public[7][2] == "Ishnu-alah." and public[7][3] == 2 and EmberTalesDB.positions.hyjal == 5)
Tick(30)
Click("Send next")
Tick(30)
assert(Find("FontString", "/say [Darnassian] Elune-adore."))
Click("Send next")
assert(public[9][2] == "Elune-adore." and public[9][3] == 2)
Tick(30)
Click("Send next")
assert(public[10][3] == nil)

Pick("The City Under the Ruins")
for _ = 1, #ns.stories[3].lines do
	Click("Send next")
	Tick(30)
end
Click("A quiet farewell")
assert(public[18][2] == "Ande'thoras-ethil." and public[18][3] == 2)

speaksDarnassian = false
Pick("When Hyjal Burned")
assert(not Find("Button", "Darnassian").enabled)
Click("Start over")
for _ = 1, 6 do
	Click("Send next")
	Tick(30)
end
assert(public[24][2] == "Elune-adore." and public[24][3] == nil)
Click("Mode: Live chat")
Click("Start over")
assert(EmberTalesDB.positions.hyjal == 7)
draft:SetText("Elune-adore.")
Click("Darnassian")
assert(#public == 24 and Find("FontString", "Rehearsed  /say [Darnassian] Elune-adore."))

-- Switching the voice creates a separate script and bookmark. The original
-- hearsay script retains the unfinished Hyjal position from the earlier run.
Pick("I was there")
Click("Mode: Rehearsal")
EmberTales_SendNext()
assert(EmberTalesDB.positions["hyjal:memory"] == 2 and EmberTalesDB.positions.hyjal == 7)
assert(public[25][2] == story.variants.memory[1][2])
EmberTales_SendNext()
Tick(60)
assert(#public == 25, "Live chat advanced on a timer or bypassed the reading pause")
Pick("I heard a tale")
assert(Find("FontString", "Next line  ·  7 / 7"))
Pick("The Schoolmaster's Name")
Pick("I put it together")
Click("Mode: Live chat")
Click("Auto rehearsal: Off")
draft.focused = true
Tick(30)
assert(Find("FontString", "Next line  ·  1 / 4"))
draft:ClearFocus()
local storyPicker = FindPicker()
storyPicker:Open()
Tick(30)
assert(Find("FontString", "Next line  ·  1 / 4"))
storyPicker:Close()
Tick(1)
assert(Find("FontString", "Next line  ·  2 / 4"))
Tick(1)
assert(Find("FontString", "Next line  ·  2 / 4"))
Click("Pause")
Tick(60)
assert(Find("FontString", "Next line  ·  2 / 4"))
Click("Resume")
for _ = 1, 3 do
	Tick(30)
end
assert(Find("Button", "Auto rehearsal: Off") and Find("FontString", "A good place to stop") and #public == 25)
Tick(60)
assert(Find("Button", "Tell more").shown and not Find("Button", "Rehearse next").enabled)
Click("Round off")
assert(Find("FontString", "Closing line  ·  1 / 1"))
Click("Auto rehearsal: Off")
Tick(30)
assert(Find("FontString", "Last line reached") and #public == 25 and not Find("Button", "Tell more").shown)
Click("Start over")
Click("Auto rehearsal: Off")
SlashCmdList.EMBERTALES()
EmberTales_SendNext()
SlashCmdList.EMBERTALES()
assert(Find("Button", "Auto rehearsal: Off") and #public == 25)
assert(select(2, Choice(storyPicker, "When Hyjal Burned")) == "Lore and legends")
for _, title in ipairs({ "Twelve Intact Scalps", "The King in a Barrel", "Supper for Jitters", "All That for a Nap" }) do
	local entry, section = Choice(storyPicker, title)
	assert(section == "Road adventures")
	Pick(title)
	assert(storyPicker.selected == entry.value)
end
Pick("Twelve Intact Scalps")
assert(Find("FontString", "Next line  ·  1 / 7"))
assert(EmberTalesDB.voices.bear_nappy == "memory")
Click("Mode: Rehearsal")
Click("Send next")
Pick("I heard a tale")
Click("Send next")
assert(EmberTalesDB.positions.bear_nappy == 2 and EmberTalesDB.positions["bear_nappy:hearsay"] == 2)

Pick("The Red Scarves")
local westfall = ns.stories[2]
for _ = 1, #westfall.lines do
	Click("Send next")
	Tick(30)
end
local beforeChoice = #public
EmberTales_SendNext()
assert(#public == beforeChoice and Find("FontString", "Waiting for your choice"))
Click("Pause")
Click("Tell more")
assert(#public == beforeChoice and not Find("Button", "Send next").enabled)
assert(EmberTalesDB.endings.westfall == "extended")
Click("Resume")
Click("Send next")
assert(public[#public][2] == westfall.endings.extended[1][2])

-- Reload the UI against the saved per-character state and continue the branch.
widgets = {}
assert(loadfile(root .. "EmberTales.lua"))("EmberTales", ns)
SlashCmdList.EMBERTALES()
frame = widgets[1]
Click("Mode: Rehearsal")
assert(Find("FontString", "Extra chapter  ·  2 / 4"))
Click("Send next")
assert(public[#public][2] == westfall.endings.extended[2][2])
Click("Start over")
assert(not EmberTalesDB.endings.westfall and not EmberTalesDB.positions.westfall)

local function SetGameLanguage(self, language, languageID)
	self.language, self.languageID = language, languageID
end
local mainBox = { SetGameLanguage = SetGameLanguage, language = "Common", languageID = 7 }
local otherBox = { SetGameLanguage = SetGameLanguage, language = "Common", languageID = 7 }
DEFAULT_CHAT_FRAME = { editBox = mainBox }
function GetDefaultLanguage() return "Common", 7 end
function GetNumLanguages() return speaksDarnassian and 2 or 1 end
function GetLanguageByIndex(index)
	if index == 1 then return "Common", 7 end
	-- A localized client still matches the numeric Darnassian ID.
	if index == 2 and speaksDarnassian then return "Darnassisch", 2 end
end
local originalPrint = print
local feedback
print = function(message) feedback = message end
local sentCount = #public
local widgetCount = #widgets
local wasShown = frame:IsShown()
speaksDarnassian = true
SlashCmdList.EMBERTALES(" LANGUAGE Darnassian ", otherBox)
assert(otherBox.language == "Darnassisch" and otherBox.languageID == 2 and mainBox.languageID == 2)
SlashCmdList.EMBERTALES("language", otherBox)
assert(feedback:find("Darnassisch", 1, true))
SlashCmdList.EMBERTALES("language common", otherBox)
assert(otherBox.languageID == 7 and mainBox.languageID == 7)
SlashCmdList.EMBERTALES("language darnassian")
assert(mainBox.languageID == 2 and otherBox.languageID == 7)
SlashCmdList.EMBERTALES("language default", otherBox)
assert(mainBox.languageID == 7 and otherBox.languageID == 7)
speaksDarnassian = false
SlashCmdList.EMBERTALES("language darnassian", otherBox)
assert(feedback:find("can't speak", 1, true) and mainBox.languageID == 7 and otherBox.languageID == 7)
SlashCmdList.EMBERTALES("language unknown", otherBox)
assert(feedback:find("Use /tale language", 1, true))
assert(#public == sentCount and #widgets == widgetCount and frame:IsShown() == wasShown)
speaksDarnassian = true
SlashCmdList.EMBERTALES("language darnassian", mainBox)
print = originalPrint

Pick("When Hyjal Burned")
Click("Start over")
assert(not Find("Button", "Next speech: Script").shown)
Click("Send next")
Tick(30)
Click("Next speech: Script")
assert(Find("FontString", "/say [Darnassian] " .. story.lines[2][2]))
Click("Pause")
FindEditBox(240):SetText("A quick aside in my usual speech.")
Click("Say")
assert(public[#public][3] == nil and Find("Button", "Next speech: Darnassian").shown)
Click("Resume")
Tick(30)
Click("Send next")
assert(public[#public][2] == story.lines[2][2] and public[#public][3] == 2)
assert(Find("Button", "Next speech: Script").shown)
Tick(30)
Click("Send next")
assert(public[#public][2] == story.lines[3][2] and public[#public][3] == nil)
for _ = 4, 5 do
	Tick(30)
	Click("Send next")
end
Click("Next speech: Script")
Click("Next speech: Darnassian")
assert(Find("FontString", "/say Elune-adore."))
Click("A word for the fallen")
assert(public[#public][2]:find("road home", 1, true) and public[#public][3] == 2)
Tick(30)
Click("Send next")
assert(public[#public][2] == "Elune-adore." and public[#public][3] == nil)
assert(Find("Button", "Next speech: Script").shown and mainBox.languageID == 2)

-- Personal comments and chat suggestions never move the main story cursor.
Click("Start over")
for _ = 1, 3 do
	Click("Send next")
	Tick(30)
end
local currentPosition = EmberTalesDB.positions.hyjal
assert(Find("Button", "Personal aside").shown and not frame.events.CHAT_MSG_SAY)
Click("Personal asides: On")
assert(not Find("Button", "Personal aside").shown)
Click("Personal asides: Off")
Click("Personal aside")
assert(public[#public][2]:find("who was buried", 1, true))
assert(EmberTalesDB.positions.hyjal == currentPosition and not Find("Button", "Personal aside").enabled)
local beforeHints = #public
Click("Chat hints: Off")
assert(frame.events.CHAT_MSG_SAY)
function UnitName() return "Storydruid" end
local secret = {}
function issecretvalue(value) return value == secret end
local function NearbySay(message, author, languageID)
	if frame.events and frame.events.CHAT_MSG_SAY then
		frame:OnEvent("CHAT_MSG_SAY", message, author, "", "", "", "", 0, 0, "", languageID)
	end
end
local orcQuestion = "What was the orc named?"
NearbySay(orcQuestion, "Storydruid-OwnRealm")
NearbySay(secret, "Listener-OtherRealm")
NearbySay(orcQuestion, secret)
NearbySay(orcQuestion, "Listener-OtherRealm", 8)
NearbySay("Do you want pizza?", "Listener-OtherRealm")
assert(not Find("Button", "Use suggestion").shown)
NearbySay("Why was the orc there?", "Listener-OtherRealm")
assert(Find("Button", "Use suggestion").shown)
NearbySay(orcQuestion, "Listener-OtherRealm")
assert(#public == beforeHints and EmberTalesDB.positions.hyjal == currentPosition)
draft = FindEditBox(240)
draft:SetText("An unfinished draft.")
Click("Use suggestion")
assert(draft:GetText() == "An unfinished draft.")
draft:SetText("")
Click("Use suggestion")
assert(draft:GetText():find("Gorak", 1, true) and draft:HasFocus() and #public == beforeHints)
Click("Say")
assert(public[#public][2]:find("Gorak", 1, true) and EmberTalesDB.positions.hyjal == currentPosition)
NearbySay(orcQuestion, "Listener-OtherRealm")
Click("Chat hints: On")
assert(not frame.events.CHAT_MSG_SAY and not Find("Button", "Use suggestion").shown)
Click("Chat hints: Off")
NearbySay(orcQuestion, "Listener-OtherRealm")
SlashCmdList.EMBERTALES()
assert(not frame.events.CHAT_MSG_SAY and not Find("Button", "Use suggestion").shown)
SlashCmdList.EMBERTALES()
Click("Mode: Live chat")
assert(not frame.events.CHAT_MSG_SAY)
Pick("The Tree I Couldn't Hear")
assert(select(2, Choice(FindPicker(), "The Tree I Couldn't Hear")) == "Personal memories")
Pick("My Shan'do's Bad Knee")
Pick("The Bear Who Let Me Wait")
assert(EmberTalesDB.voices.bear_lesson == "memory")
for _, title in ipairs({ "The Cat Above the Door", "The Patient Who Said No", "The Seed in My Boot" }) do
	Pick(title)
	assert(select(2, Choice(FindPicker(), title)) == "Personal memories")
end
Pick("The Cat Above the Door")
Click("Mode: Rehearsal")
Click("Send next")
Tick(30)
Click("Send next")
assert(Find("Button", "Personal aside").shown and frame.events.CHAT_MSG_SAY)
local beforeQuestion = #public
NearbySay("How did you get down from the rafters?", "Listener-OtherRealm", 7)
Click("Use suggestion")
assert(FindEditBox(240):GetText():find("basket", 1, true))
assert(#public == beforeQuestion and EmberTalesDB.positions.cat_rafters == 3)

local search = FindEditBox(80)
storyPicker = FindPicker()
search:SetText("Nighthaven door")
assert(Choice(storyPicker, "The Cat Above the Door") and not Choice(storyPicker, "The Red Scarves"))
search:OnEnterPressed()
assert(EmberTalesDB.story == "cat_rafters")
Click("Save favourite")
Click("All stories")
search:SetText("Westfall")
assert(#storyPicker.entries == 1 and storyPicker.entries[1].label == "No matching stories")
search:SetText("")
assert(Choice(storyPicker, "The Cat Above the Door") and not Choice(storyPicker, "The Red Scarves"))
Click("Remove favourite")
assert(#storyPicker.entries == 1 and not EmberTalesDB.favourites.cat_rafters)
Click("Favourites only")
assert(Choice(storyPicker, "The Red Scarves"))
Click("Save favourite")

assert(rawget(frame, "OnUpdate"))
Click("Pace: Natural")
assert(EmberTalesDB.pace == 2 and Find("Button", "Pace: Brisk"))
Click("Pause")
assert(not rawget(frame, "OnUpdate"))
Click("Pace: Brisk")
assert(EmberTalesDB.pace == 3 and not rawget(frame, "OnUpdate"))
Click("Resume")
assert(rawget(frame, "OnUpdate"))
Tick(45)
assert(not rawget(frame, "OnUpdate") and Find("Button", "Send next").enabled)
SlashCmdList.EMBERTALES()
assert(not rawget(frame, "OnUpdate"))

widgets = {}
assert(loadfile(root .. "EmberTales.lua"))("EmberTales", ns)
SlashCmdList.EMBERTALES()
assert(Find("Button", "Remove favourite").shown and Find("Button", "Pace: Leisurely").shown)
search = FindEditBox(80)
storyPicker = FindPicker()
local sentBeforePick = #public
search:SetText("Riverglades gas")
assert(select(2, Choice(storyPicker, "Eight Vials of the Future")) == "Road adventures")
Click("Pick for me")
assert(EmberTalesDB.story == "marsh_gas" and not Find("Button", "Pick for me").enabled)
search:SetText("no such tale")
assert(not Find("Button", "Pick for me").enabled)
search:SetText("")
Pick("The Price of a Pie")
Pick("Five Minutes to Anvilmar")
assert(select(2, Choice(storyPicker, "The Rain in the Tin Cup")) == "Campfire moments")
Pick("The Other Side of the Fire")
Click("Save favourite")
Click("All stories")
Click("Pick for me")
assert(EmberTalesDB.story == "cat_rafters" and EmberTalesDB.positions.cat_rafters == 3)
assert(#public == sentBeforePick)
storyPicker:Open()
SlashCmdList.EMBERTALES()
assert(not storyPicker:IsOpen())
SlashCmdList.EMBERTALES()
Click("Favourites only")
Pick("A Nest in the Branches")
Pick("A Furbolg's Reflection")
assert(select(2, Choice(storyPicker, "A Light Along the Shore")) == "Campfire moments")
Pick("When Hyjal Burned")
Click("Start over")
Click("Auto rehearsal: Off")
Click("Read script")
local viewer, scrollFrame
for _, widget in ipairs(widgets) do
	if rawget(widget, "OpenScript") then viewer = widget end
	if widget.kind == "ScrollFrame" then scrollFrame = widget end
end
assert(viewer:IsShown() and scrollFrame.verticalScroll == 0 and not rawget(widgets[1], "OnUpdate"))
Click("Page down")
assert(scrollFrame.verticalScroll > 0)
Click("Page up")
assert(scrollFrame.verticalScroll == 0)
EmberTales_SendNext()
assert(#public == sentBeforePick and Find("FontString", "Next line  ·  1 / 7"))
Click("Back")
assert(not viewer:IsShown() and Find("Button", "Resume").shown)
Click("Resume")
frame = widgets[1]
Tick(30)
assert(Find("FontString", "Next line  ·  2 / 7") and #public == sentBeforePick)
for _, title in ipairs({ "The Ring I Brought Tyrande", "The Portrait Behind the Moons",
	"The Night Illidan Walked Free", "When the Prince Came Home" }) do
	assert(select(2, Choice(storyPicker, title)) == "Famous figures")
end
Pick("The Ring I Brought Tyrande")
local tyrande = storyPicker.selected
local manuscript = ns.BuildScriptPreview(Performance.New(tyrande, 1, "memory"), true)
assert(manuscript:find("How he knows", 1, true) and manuscript:find("Firsthand if", 1, true))
assert(manuscript:find("Sources", 1, true) and manuscript:find(tyrande.sources[1], 1, true))
assert(manuscript:find("Ask the camp", 1, true))
Click("Mode: Rehearsal")
if not EmberTalesDB.chatHints then Click("Chat hints: Off") end
for _ = 1, #tyrande.lines do
	Click("Send next")
	Tick(30)
end
local questionCount = #public
local tyPosition = EmberTalesDB.positions.tyrande_ring
Click("Ask the camp")
assert(#public == questionCount + 1 and public[#public][2] == tyrande.lines[#tyrande.lines].question)
assert(EmberTalesDB.positions.tyrande_ring == tyPosition and not Find("Button", "Ask the camp").enabled)
assert(Find("Button", "Resume").shown and frame.events.CHAT_MSG_SAY)
NearbySay("How do you know?", "Listener-OtherRealm", 7)
assert(Find("Button", "Use suggestion").shown)
Click("Tell more")
assert(not Find("Button", "Send next").enabled and #public == questionCount + 1)
Click("Resume")
Tick(30)
Click("Send next")
assert(public[#public][2] == tyrande.endings.extended[1][2])
for _, title in ipairs({ "The Road Both Camps Took", "The Stone Magni Asked For", "What Cairne Sent After the Horn" }) do
	assert(select(2, Choice(storyPicker, title)) == "Famous figures")
end
local stagedDraft = FindEditBox(240)
local stagedNext = Find("Button", "Send next")
assert(stagedDraft.parent == stagedNext.parent)
local stage = stagedDraft.parent
stagedDraft:SetText("An unsent thought at the fire.")
local stagedPosition, stagedCount = EmberTalesDB.positions.tyrande_ring, #public
Click("Camp view")
assert(frame.height == 463 and stage.point[5] == 58)
assert(not FindEditBox(80).shown and not storyPicker.shown and not Find("Button", "Pick for me").shown)
assert(stagedDraft:GetText() == "An unsent thought at the fire." and stagedNext.shown)
assert(Find("FontString", "The Ring I Brought Tyrande  ·  I was there").shown)
Click("Read script")
assert(frame.height == 521 and viewer:IsShown())
Click("Back")
assert(frame.height == 463 and not viewer:IsShown())
assert(EmberTalesDB.positions.tyrande_ring == stagedPosition and #public == stagedCount)
Click("Library")
assert(frame.height == 521 and stage.point[5] == 0 and storyPicker.shown and FindEditBox(80).shown)
assert(stagedDraft:GetText() == "An unsent thought at the fire.")
Click("Camp view")
widgets = {}
assert(loadfile(root .. "EmberTales.lua"))("EmberTales", ns)
SlashCmdList.EMBERTALES()
assert(widgets[1].height == 463 and Find("Button", "Library").shown and not FindPicker().shown)
frame = widgets[1]
Click("Library")
local warcraftSearch = FindEditBox(80)
storyPicker = FindPicker()
warcraftSearch:SetText("WC1")
assert(select(2, Choice(storyPicker, "The Last Delivery to Karazhan")) == "Warcraft I–III" and #storyPicker.entries == 3)
assert(Choice(storyPicker, "A Name for the Next Boat"))
warcraftSearch:SetText("wc2")
assert(Choice(storyPicker, "The Banner at Blackrock") and #storyPicker.entries == 4)
assert(Choice(storyPicker, "Alleria and the Far Bank") and Choice(storyPicker, "Khadgar's Name in Stone"))
warcraftSearch:SetText("WC3")
assert(Choice(storyPicker, "A Light in the Barrow") and Choice(storyPicker, "The Grove After Cenarius"))
assert(not Choice(storyPicker, "The Banner at Blackrock") and #storyPicker.entries == 5)
assert(Choice(storyPicker, "The Day Rexxar Brought Baine Home"))
Pick("What They Called Rexxar")
local rexxar = storyPicker.selected
assert(EmberTalesDB.voices.rexxar_theramore == "hearsay")
local rexManuscript = ns.BuildScriptPreview(Performance.New(rexxar, 1, "hearsay"), true)
assert(rexManuscript:find("Misha", 1, true) and rexManuscript:find(rexxar.sources[1], 1, true))
Click("Mode: Rehearsal")
if not EmberTalesDB.chatHints then Click("Chat hints: Off") end
for _ = 1, #rexxar.lines do
	Click("Send next")
	Tick(30)
end
local beforeMisha = #public
NearbySay("What was the bear called?", "Listener-OtherRealm", 7)
Click("Use suggestion")
assert(FindEditBox(240):GetText():find("Misha", 1, true) and #public == beforeMisha)
FindEditBox(240):SetText("")
Pick("The Day Rexxar Brought Baine Home")
local baineStory = storyPicker.selected
local baineManuscript = ns.BuildScriptPreview(Performance.New(baineStory, 1, "hearsay"), true)
assert(baineManuscript:find("Bovan Windtotem", 1, true) and baineManuscript:find(baineStory.sources[1], 1, true))
for _ = 1, #baineStory.lines do
	Click("Send next")
	Tick(30)
end
local beforeBaine = #public
NearbySay("How do you know about Baine?", "Listener-OtherRealm", 7)
Click("Use suggestion")
assert(FindEditBox(240):GetText():find("Moonglade", 1, true) and #public == beforeBaine)
print(("Ember Tales: 120 scripts, Warcraft I–III filters, Rexxar chat hints, Camp view and playback passed. First stops: %.1f–%.1fs."):format(shortest, longest))
