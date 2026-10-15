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
local API = ns.API or {}
ns.API = API

--[[
	Anchoring one /lock mover to another (Docs/Mover Anchoring Plan.md).

	Every mover is saved as SetPoint(point, UIParent, point, x, y). A link says "put my
	`point` at the target's `relativePoint`, plus x, y". The manager keeps saving plain
	UIParent positions; these helpers turn a link into one, and a position back into a
	link's offset. Pure arithmetic on numbers the caller passes in, in UIParent units
	from its bottom left, so it can be tested without a client
	(Tools/Harness/mover_anchoring_harness.lua).
]]

local next = next
local tonumber = tonumber
local type = type

-- Where on a frame each anchor point sits, as fractions of width and height.
local FRACTIONS = {
	TOPLEFT = { 0, 1 }, TOP = { .5, 1 }, TOPRIGHT = { 1, 1 },
	LEFT = { 0, .5 }, CENTER = { .5, .5 }, RIGHT = { 1, .5 },
	BOTTOMLEFT = { 0, 0 }, BOTTOM = { .5, 0 }, BOTTOMRIGHT = { 1, 0 }
}

API.ANCHOR_POINTS = { "TOPLEFT", "TOP", "TOPRIGHT", "LEFT", "CENTER", "RIGHT", "BOTTOMLEFT", "BOTTOM", "BOTTOMRIGHT" }

API.IsAnchorPoint = function(point)
	return FRACTIONS[point] and true or false
end

--- The bottom left corner of a frame placed with SetPoint(point, UIParent, point, x, y).
-- Returns left, bottom, or nil for anything that is not a number or a known point.
API.RectFromPoint = function(point, x, y, width, height, uiWidth, uiHeight)
	local f = FRACTIONS[point]
	if (not f or type(x) ~= "number" or type(y) ~= "number" or type(width) ~= "number" or type(height) ~= "number"
		or type(uiWidth) ~= "number" or type(uiHeight) ~= "number") then return end
	return uiWidth * f[1] + x - width * f[1], uiHeight * f[2] + y - height * f[2]
end

--- The x, y that place a frame whose bottom left is left, bottom with SetPoint(point, UIParent, point, x, y).
API.PointFromRect = function(point, left, bottom, width, height, uiWidth, uiHeight)
	local f = FRACTIONS[point]
	if (not f or type(left) ~= "number" or type(bottom) ~= "number" or type(width) ~= "number" or type(height) ~= "number"
		or type(uiWidth) ~= "number" or type(uiHeight) ~= "number") then return end
	return left + width * f[1] - uiWidth * f[1], bottom + height * f[2] - uiHeight * f[2]
end

--- The follower's bottom left under a link, given the target's rect (left, bottom, width, height).
API.LinkedRect = function(link, targetLeft, targetBottom, targetWidth, targetHeight, width, height)
	if (type(link) ~= "table") then return end
	local p, rp = FRACTIONS[link.point], FRACTIONS[link.relativePoint]
	if (not p or not rp or type(targetLeft) ~= "number" or type(targetBottom) ~= "number"
		or type(targetWidth) ~= "number" or type(targetHeight) ~= "number"
		or type(width) ~= "number" or type(height) ~= "number") then return end
	local x, y = tonumber(link.x) or 0, tonumber(link.y) or 0
	return targetLeft + targetWidth * rp[1] + x - width * p[1], targetBottom + targetHeight * rp[2] + y - height * p[2]
end

--- The offset a link needs so the follower stays exactly where it is now.
API.LinkOffset = function(point, relativePoint, targetLeft, targetBottom, targetWidth, targetHeight, left, bottom, width, height)
	local p, rp = FRACTIONS[point], FRACTIONS[relativePoint]
	if (not p or not rp or type(targetLeft) ~= "number" or type(targetBottom) ~= "number"
		or type(targetWidth) ~= "number" or type(targetHeight) ~= "number" or type(left) ~= "number"
		or type(bottom) ~= "number" or type(width) ~= "number" or type(height) ~= "number") then return end
	return left + width * p[1] - (targetLeft + targetWidth * rp[1]), bottom + height * p[2] - (targetBottom + targetHeight * rp[2])
end

--- True if linking follower to target would make a loop (target already follows follower,
-- directly or down a chain), or follower and target are the same.
API.WouldLinkCycle = function(links, follower, target)
	if (follower == nil or target == nil) then return true end
	if (follower == target) then return true end
	if (type(links) ~= "table") then return false end
	local key, steps = target, 0
	while (key ~= nil and steps < 256) do
		if (key == follower) then return true end
		local link = links[key]
		key = type(link) == "table" and link.target or nil
		steps = steps + 1
	end
	return steps >= 256
end

--- How many links lie between a follower and the first mover that follows nothing.
-- Applying links in rising depth moves every target before its followers.
API.LinkDepth = function(links, key)
	local depth, steps = 0, 0
	local link = type(links) == "table" and links[key]
	while (type(link) == "table" and link.target ~= nil and steps < 256) do
		depth = depth + 1
		steps = steps + 1
		link = links[link.target]
	end
	return depth
end

--- The keys of every mover that follows key, directly or down a chain, nearest first.
API.LinkFollowers = function(links, key)
	local out, seen, queue, head = {}, { [key] = true }, { key }, 1
	if (type(links) ~= "table") then return out end
	while (queue[head] ~= nil) do
		local current = queue[head]
		head = head + 1
		for follower, link in next, links do
			if (type(link) == "table" and link.target == current and not seen[follower]) then
				seen[follower] = true
				out[#out + 1] = follower
				queue[#queue + 1] = follower
			end
		end
	end
	return out
end
