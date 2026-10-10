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
	Snapping for the /lock movers, after Blizzard's Edit Mode magnetism
	(Blizzard_EditMode/Shared/EditModeUtil.lua, EditModeMagnetismManager): a frame
	being dragged snaps when one of its edges or its centre comes within 8 screen
	pixels of a line, the lines being the screen's edges and centre, the Edit Mode
	grid while it is shown, and the edges and centres of other frames. Only frame
	rectangles are read; nothing of Blizzard's is written.

	Pure arithmetic on numbers the caller passes in, one axis at a time, so it can be
	tested without a client (Tools/Harness/snapping_harness.lua).
]]

local math_abs = math.abs
local math_floor = math.floor
local type = type

-- EditModeMagnetismManager.magnetismRange, in screen pixels.
API.SNAP_RANGE = 8

-- The smallest move that puts the frame's start edge, centre or end edge on one of
-- the target lines, if any is within range. Returns the move and the line, or nil.
-- start and size are along one axis (left and width, or bottom and height).
API.FindSnap = function(start, size, targets, range)
	if (type(start) ~= "number" or type(size) ~= "number" or type(targets) ~= "table") then return end
	if (type(range) ~= "number" or range <= 0) then return end

	local bestDelta, bestLine
	for index = 1, #targets do
		local line = targets[index]
		for step = 0, 2 do
			local delta = line - (start + size * step / 2)
			if (math_abs(delta) <= range and (not bestDelta or math_abs(delta) < math_abs(bestDelta))) then
				bestDelta, bestLine = delta, line
			end
		end
	end
	return bestDelta, bestLine
end

-- Adds the lines of a grid centred on center, spacing apart, across extent, the way
-- EditModeGridMixin:UpdateGrid lays its lines out. Returns the table it was given.
API.AddGridLines = function(targets, center, extent, spacing)
	if (type(spacing) ~= "number" or spacing <= 0 or type(extent) ~= "number") then return targets end
	targets[#targets + 1] = center
	for step = 1, math_floor((extent / spacing) / 2) do
		targets[#targets + 1] = center + step * spacing
		targets[#targets + 1] = center - step * spacing
	end
	return targets
end
