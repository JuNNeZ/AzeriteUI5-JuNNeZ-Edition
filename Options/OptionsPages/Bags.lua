--[[

	The MIT License (MIT)

	Copyright (c) 2026 Lars Norberg
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

local L = LibStub("AceLocale-3.0"):GetLocale((...))

local Options = ns:GetModule("Options")

local getmodule = function()
	local module = ns:GetModule("Containers", true)
	if (module and module:IsEnabled()) then
		return module
	end
end

local setter = function(info,val)
	getmodule().db.profile[info[#info]] = val
	getmodule():UpdateSettings()
end

local getter = function(info)
	return getmodule().db.profile[info[#info]]
end

local isdisabled = function(info)
	return info[#info] ~= "enabled" and not getmodule().db.profile.enabled
end

local GenerateOptions = function()
	if (not getmodule()) then return end

	local options = {
		name = L["Bag Settings"],
		type = "group",
		args = {}
	}

	if (C_Container.SetSortBagsRightToLeft) then
		options.args["sort"] = {
			name = L["Sort Direction"],
			desc = L["Choose in which direction items in your bags are sorted."],
			type = "select", style = "dropdown",
			order = 1,
			values = {
				["ltr"] = L["Left to Right"],
				["rtl"] = L["Right to Left"]
			},
			set = setter,
			get = getter
		}
		options.args.space1 = {
			name = "", order = 2, type = "description", hidden = isdisabled
		}

	end

	if (C_Container.SetInsertItemsLeftToRight) then
		options.args["insert"] = {
			name = L["Insert Point"],
			desc = L["Choose from which side new items are inserted into your bags."],
			type = "select", style = "dropdown",
			order = 3,
			values = {
				["rtl"] = L["Right to Left"],
				["ltr"] = L["Left to Right"]
			},
			set = setter,
			get = getter
		}
		options.args.space2 = {
			name = "", order = 4, type = "description", hidden = isdisabled
		}
	end

	-- Containers.lua, OnMerchantShow. Both off by default.
	local module = getmodule()
	if (module.CanSellJunk and module.CanSellJunk()) then
		options.args.autoSellJunk = {
			name = L["Sell junk automatically"],
			desc = L["When you open a merchant, sell every grey item in your bags, as Blizzard's own Sell All Junk button does, without asking."],
			order = 10,
			type = "toggle", width = "full",
			set = setter,
			get = getter
		}
	end
	if (module.CanRepair and module.CanRepair()) then
		options.args.autoRepair = {
			name = L["Repair automatically"],
			desc = L["When you open a merchant who can repair, repair all your gear."],
			order = 11,
			type = "toggle", width = "full",
			set = setter,
			get = getter
		}
		if (module.CanGuildRepair and module.CanGuildRepair()) then
			options.args.autoRepairGuild = {
				name = L["Use guild bank funds first"],
				desc = L["Pay for the repair from the guild bank when your guild allows it and has enough. Otherwise your own money is used."],
				order = 12,
				type = "toggle", width = "full",
				disabled = function() return not getmodule().db.profile.autoRepair end,
				set = setter,
				get = getter
			}
		end
	end

	-- Containers.lua, OnLootReady. Off by default.
	if (module.CanFastLoot and module.CanFastLoot()) then
		options.args.fastLoot = {
			name = L["Fast loot"],
			desc = L["Take everything the moment the loot window opens, whenever the game would auto loot. Hold your auto loot key to loot by hand as usual."],
			order = 20,
			type = "toggle", width = "full",
			set = setter,
			get = getter
		}
	end

	return options
end

Options:AddGroup(L["Bags"], GenerateOptions, -5000, "interface", "Containers")
