local _, ns = ...

local questionWords = { who = true, what = true, where = true, when = true, why = true, how = true,
	did = true, was = true, were = true, ["do"] = true, can = true }
local fallback = {
	memory = "I can tell you what I remember seeing. The rest I might have filled in over the years.",
	hearsay = "That's as it was told to me. I would have liked to ask that question myself.",
	inference = "There's a gap there, isn't there? I have a guess. I'd like to hear yours."
}
local pronouns = { he = true, his = true, him = true, she = true, them = true, you = true }

local function HasCue(words, choices, requireTopic)
	for _, choice in ipairs(choices) do
		if (not requireTopic or not pronouns[choice]) and words:find(" " .. choice .. " ", 1, true) then
			return true
		end
	end
	return false
end

function ns.HasChatCues(replies, usedReplies)
	for index, reply in ipairs(replies or {}) do
		if reply.cues and not usedReplies[index] then
			return true
		end
	end
	return false
end

function ns.SuggestChatReply(voice, replies, usedReplies, message)
	if not replies or #message > 240 or message:find("|", 1, true) then
		return
	end
	local words = " " .. message:lower():gsub("[^%w]+", " ") .. " "
	if not message:find("?", 1, true) and not questionWords[words:match("^%s*(%w+)")] then
		return
	end
	local onTopic
	for index, reply in ipairs(replies) do
		if reply.cues and not usedReplies[index] and HasCue(words, reply.cues[1]) then
			if HasCue(words, reply.cues[2]) then
				return reply[3], reply.darnassian
			end
			onTopic = onTopic or HasCue(words, reply.cues[1], true)
		end
	end
	if onTopic then
		return fallback[voice]
	end
end
