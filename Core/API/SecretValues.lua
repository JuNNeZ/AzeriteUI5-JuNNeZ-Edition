--[[

	The MIT License (MIT)

	Copyright (c) 2024 Lars Norberg

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

local type = type
local pairs = pairs
local tostring = tostring

local function IsSecret(value)
	return issecretvalue and issecretvalue(value) or false
end

-- Expose helper for other modules
API.IsSecret = IsSecret

API.SafeNumber = function(value, cache, key, fallback)
	if (type(value) == "number" and not IsSecret(value)) then
		if (cache and key) then
			cache[key] = value
		end
		return value
	end
	if (IsSecret(value)) then
		if (cache and key and type(cache[key]) == "number") then
			return cache[key]
		end
		return fallback
	end
	return value
end

API.SafeBool = function(value, cache, key, fallback)
	if (type(value) == "boolean" and not IsSecret(value)) then
		if (cache and key) then
			cache[key] = value
		end
		return value
	end
	if (IsSecret(value)) then
		if (cache and key and type(cache[key]) == "boolean") then
			return cache[key]
		end
		return fallback
	end
	return value
end

API.SafeString = function(value, cache, key, fallback)
	if (type(value) == "string" and not IsSecret(value)) then
		if (cache and key) then
			cache[key] = value
		end
		return value
	end
	if (IsSecret(value)) then
		if (cache and key and type(cache[key]) == "string") then
			return cache[key]
		end
		return fallback or ""
	end
	return value
end

API.SanitizeTableNumbers = function(tbl, cache, prefix, depth)
	if (type(tbl) ~= "table") then
		return
	end
	if (depth and depth > 3) then
		return
	end
	if (canaccesstable and not canaccesstable(tbl)) then
		return
	end
	local nextDepth = (depth or 0) + 1
	for k, v in pairs(tbl) do
		local key = (prefix or "tbl") .. "." .. tostring(k)
		if (IsSecret(v)) then
			local cached = cache and cache[key]
			if (type(cached) == "number") then
				tbl[k] = cached
			else
				tbl[k] = 0
			end
		elseif (type(v) == "number") then
			if (cache) then
				cache[key] = v
			end
		elseif (type(v) == "table") then
			API.SanitizeTableNumbers(v, cache, key, nextDepth)
		end
	end
end
