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
	Copying a layout from one profile to another (Docs/Mover Anchoring Plan.md).

	A layout is every frame's saved position (`savedPosition`, or any key ending in
	`SavedPosition`, at any depth: action bars keep theirs per bar), the links between
	movers (`moverLinks`) and the master scale (`frameScale`), which is baked into every
	saved position and so has to travel with them. Nothing else is touched.

	Works on the raw SavedVariables tables (db.sv), the way Core.lua's profile reset does,
	so namespaces registered this session and those that are not (Legacy, other clients)
	are handled alike. The caller reloads afterwards. Pure table work; tested offline by
	Tools/Harness/layout_copy_harness.lua.
]]

local next = next
local type = type

local MAX_DEPTH = 4
local CORE_KEYS = { moverLinks = true, frameScale = true }

local IsPositionKey = function(key)
	return type(key) == "string" and (key == "savedPosition" or key:match("SavedPosition$") ~= nil)
end

local DeepCopy
DeepCopy = function(value)
	if (type(value) ~= "table") then return value end
	local out = {}
	for k, v in next, value do out[k] = DeepCopy(v) end
	return out
end

local HasPosition
HasPosition = function(t, depth)
	if (type(t) ~= "table" or depth > MAX_DEPTH) then return false end
	for k, v in next, t do
		if (IsPositionKey(k) and type(v) == "table") then return true end
		if (type(v) == "table" and HasPosition(v, depth + 1)) then return true end
	end
	return false
end

local ClearPositions
ClearPositions = function(t, depth)
	if (type(t) ~= "table" or depth > MAX_DEPTH) then return end
	for k, v in next, t do
		if (IsPositionKey(k)) then
			t[k] = nil
		elseif (type(v) == "table") then
			ClearPositions(v, depth + 1)
		end
	end
end

local CopyPositions
CopyPositions = function(source, target, depth)
	if (depth > MAX_DEPTH) then return end
	for k, v in next, source do
		if (IsPositionKey(k) and type(v) == "table") then
			target[k] = DeepCopy(v)
		elseif (type(v) == "table" and HasPosition(v, depth + 1)) then
			if (type(target[k]) ~= "table") then target[k] = {} end
			CopyPositions(v, target[k], depth + 1)
		end
	end
end

API.IsLayoutKey = IsPositionKey

--- Copies the layout of profile `source` over profile `target` in the raw saved tables.
-- sv is the AceDB SavedVariables table (db.sv). getLive(name) may return a registered
-- namespace's live profile table, so a namespace already in use is written in place.
-- Returns the number of namespaces that now hold positions from the source.
API.CopyLayout = function(sv, source, target, getLive)
	if (type(sv) ~= "table" or type(source) ~= "string" or type(target) ~= "string" or source == target) then return 0 end

	-- The core profile: links and master scale. A source without them means defaults.
	sv.profiles = type(sv.profiles) == "table" and sv.profiles or {}
	local coreSource = sv.profiles[source]
	local coreTarget = sv.profiles[target]
	if (type(coreTarget) ~= "table") then
		coreTarget = {}
		sv.profiles[target] = coreTarget
	end
	for key in next, CORE_KEYS do
		coreTarget[key] = DeepCopy(type(coreSource) == "table" and coreSource[key] or nil)
	end

	-- Every namespace: the target's positions go, the source's come in.
	local copied = 0
	local namespaces = sv.namespaces
	if (type(namespaces) ~= "table") then return copied end
	for name, data in next, namespaces do
		if (type(data) == "table") then
			local profiles = type(data.profiles) == "table" and data.profiles or nil
			local from = profiles and profiles[source]
			local to = profiles and profiles[target]
			if (type(to) ~= "table" and getLive) then
				local live = getLive(name)
				if (type(live) == "table") then to = live end
			end
			if (type(to) == "table") then ClearPositions(to, 1) end
			if (HasPosition(from, 1)) then
				if (type(to) ~= "table") then to = {} end
				data.profiles = profiles or {}
				data.profiles[target] = to
				CopyPositions(from, to, 1)
				copied = copied + 1
			end
		end
	end
	return copied
end
