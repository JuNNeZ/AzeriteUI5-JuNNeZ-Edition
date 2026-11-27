local _, ns = ...

local Performance = {}
Performance.__index = Performance
ns.Performance = Performance

function Performance.New(story, position, voice, ending)
	voice = voice or story.voice
	local lines = voice == story.voice and story.lines or story.variants[voice]
	local endingLines = story.endings[ending]
	local lastPosition = #lines + (endingLines and #endingLines or 0) + 1
	if type(position) ~= "number" or position % 1 ~= 0 or position < 1 or position > lastPosition then
		position = 1
	end
	return setmetatable({
		story = story, voice = voice, lines = lines, position = position, readyAt = 0, usedReplies = {},
		ending = endingLines and position > #lines and ending or nil, pace = 1
	}, Performance)
end

function Performance:CanChooseEnding()
	return self.position == #self.lines + 1
end

function Performance:ChooseEnding(ending)
	if not self:CanChooseEnding() or not self.story.endings[ending] then
		return false
	end
	self.ending = ending
	return true
end

function Performance:GetLine(position)
	position = position or self.position
	if position <= #self.lines then
		return self.lines[position]
	end
	local ending = self.story.endings[self.ending]
	return ending and ending[position - #self.lines]
end

function Performance.CleanLine(text)
	text = text:gsub("%s+", " "):match("^%s*(.-)%s*$")
	if text == "" then
		return nil, "Enter a line first."
	end
	if #text > 240 then
		return nil, "Keep the line within 240 bytes."
	end
	if text:find("[|%c]") then
		return nil, "Use plain text."
	end
	return text
end

function Performance.Delay(kind, text)
	local _, words = text:gsub("%S+", "")
	if kind == "EMOTE" then
		return math.min(8, 2 + words * 0.16)
	end
	local _, pauses = text:gsub("[.!?]", "")
	return math.min(22, 2.2 + words * 0.30 + pauses * 0.45)
end

function Performance:Remaining(now)
	return self.pausedFor or math.max(0, self.readyAt - now)
end

function Performance:SetPace(pace, now)
	if self.pace == pace then
		return
	end
	local remaining = self:Remaining(now) * pace / self.pace
	self.pace = pace
	if self.pausedFor then
		self.pausedFor = remaining
	else
		self.readyAt = now + remaining
	end
end

function Performance:TogglePause(now)
	if self.pausedFor then
		self.readyAt = now + self.pausedFor
		self.pausedFor = nil
	else
		self.pausedFor = self:Remaining(now)
	end
end

function Performance:WaitAfter(kind, text, now)
	local delay = Performance.Delay(kind, text) * self.pace
	if self.pausedFor then
		self.pausedFor = math.max(self.pausedFor, delay)
	else
		self.readyAt = now + math.max(self:Remaining(now), delay)
	end
end

function Performance:Next(now, deliver)
	local line = self:GetLine()
	if not line or self.pausedFor or self:Remaining(now) > 0 then
		return false
	end
	if not deliver(line[1], line[2], line.darnassian) then
		return false
	end
	self.position = self.position + 1
	self.usedReplies = {}
	self.usedAside = nil
	self.usedQuestion = nil
	self:WaitAfter(line[1], line[2], now)
	return true
end

function Performance:GetReplies()
	local last = self:GetLine(self.position - 1)
	return last and last.replies
end

function Performance:GetAside()
	local last = self:GetLine(self.position - 1)
	return last and last.aside
end

function Performance:GetQuestion()
	local last = self:GetLine(self.position - 1)
	return last and last.question
end

function Performance:Insert(kind, text, now, deliver, darnassian)
	if not deliver(kind, text, darnassian) then
		return false
	end
	self:WaitAfter(kind, text, now)
	return true
end

function Performance:Reply(index, now, deliver)
	local replies = self:GetReplies()
	local reply = replies and replies[index]
	if not reply or self.usedReplies[index] then
		return false
	end
	if self:Insert(reply[2], reply[3], now, deliver, reply.darnassian) then
		self.usedReplies[index] = true
		return true
	end
	return false
end

function Performance:Aside(now, deliver)
	local aside = self:GetAside()
	if aside and not self.usedAside and self:Insert(aside[1], aside[2], now, deliver, aside.darnassian) then
		self.usedAside = true
		return true
	end
	return false
end

function Performance:Ask(now, deliver)
	local question = self:GetQuestion()
	if not question or self.usedQuestion or not self:Insert("SAY", question, now, deliver) then
		return false
	end
	self.usedQuestion = true
	if not self.pausedFor then
		self:TogglePause(now)
	end
	return true
end
