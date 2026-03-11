--[[

	The MIT License (MIT)

	Copyright (c) 2026 Lars Norberg

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
local Addon, ns = ...

local configs = {}
local configVariants = {}
local resolvedConfigs = {}

ns.RegisterConfig = function(name, config)
	if (configs[name]) then return end
	configs[name] = config
end

ns.RegisterConfigVariant = function(preset, name, config)
	if (type(preset) ~= "string" or preset == "") then return end
	if (type(name) ~= "string" or name == "") then return end
	if (type(config) ~= "table") then return end
	if (not configVariants[preset]) then
		configVariants[preset] = {}
	end
	configVariants[preset][name] = config
	if (resolvedConfigs[preset]) then
		resolvedConfigs[preset][name] = nil
	end
end

ns.GetConfig = function(name)
	local config = configs[name]
	if (not config) then
		return
	end

	local preset = ns.GetActiveConfigVariant and ns:GetActiveConfigVariant()
	if (type(preset) ~= "string" or preset == "") then
		return config
	end

	local variants = configVariants[preset]
	local variant = variants and variants[name]
	if (not variant) then
		return config
	end

	if (not resolvedConfigs[preset]) then
		resolvedConfigs[preset] = {}
	end
	if (not resolvedConfigs[preset][name]) then
		resolvedConfigs[preset][name] = ns:Merge(ns:Copy(variant), config)
	end
	return resolvedConfigs[preset][name]
end

