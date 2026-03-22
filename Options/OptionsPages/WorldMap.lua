--[[

	The MIT License (MIT)

	Copyright (c) 2026

--]]
local _, ns = ...

local L = LibStub("AceLocale-3.0"):GetLocale((...))
local Options = ns:GetModule("Options")

local getmodule = function()
	return ns:GetModule("WorldMap", true)
end

local isdisabled = function(info)
	return info[#info] ~= "enabled" and not getmodule().db.profile.enabled
end

local GenerateOptions = function()
	if (not getmodule()) then return end

	local options = {
		name = WORLD_MAP,
		type = "group",
		args = {
			enabled = {
				name = L["Enable"],
				desc = L["Toggle AzeriteUI's integrated world map styling and coordinates."],
				order = 1,
				type = "toggle",
				width = "full",
				set = function(info, val)
					getmodule().db.profile.enabled = val
					getmodule():UpdateSettings()
				end,
				get = function(info)
					return getmodule().db.profile.enabled
				end
			},
			credit = {
				name = L["Integration and retail version by Rui"],
				order = 100,
				type = "description",
				width = "full"
			},
			description = {
				name = L["When enabled, the world map uses the integrated Rui-style clean border, shrink-on-maximize behavior, and player/cursor coordinates."],
				order = 2,
				type = "description",
				hidden = isdisabled
			}
		}
	}

	return options
end

Options:AddGroup(WORLD_MAP, GenerateOptions, -2900)
