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

local L = LibStub("AceLocale-3.0"):GetLocale((...))
local AceConfigDialog = LibStub("AceConfigDialog-3.0")
local AceConfigRegistry = LibStub("AceConfigRegistry-3.0")

-- GLOBALS: CONFIRM_RESET_SETTINGS, Settings

local Options = ns:NewModule("Options", "LibMoreEvents-1.0", "AceConsole-3.0", "AceHook-3.0")

-- Register with Blizzard Settings API using canvas layout (Platynator pattern)
Options.InitializeSettingsPanel = function(self)
	if self.settingsPanelInitialized then return end
	if not _G.Settings or not _G.Settings.RegisterCanvasLayoutCategory then return end
	self.settingsPanelInitialized = true

	-- AzeriteUI brand colors (from TOC title)
	local AZERITE_BLUE = CreateColorFromHexString("ff4488bb")
	local AZERITE_WHITE = CreateColorFromHexString("fffafafa")
	local JUNNEZ_GREEN = CreateColorFromHexString("ff00ff00")
	local CREDITS_GRAY = CreateColorFromHexString("ff999999")
	local GOLDPAW_GOLD = CreateColorFromHexString("ffffcc00")

	-- Create a bare frame to hold the panel content
	local optionsFrame = CreateFrame("Frame")

	-- Addon icon (centered, top area)
	local icon = optionsFrame:CreateTexture(nil, "ARTWORK")
	icon:SetSize(64, 64)
	icon:SetPoint("CENTER", optionsFrame, 0, 120)
	icon:SetTexture(ns.API.GetMedia("power-crystal-ice-icon"))

	-- Addon name header (big, styled like TOC title)
	local header = optionsFrame:CreateFontString(nil, "ARTWORK", "GameFontNormalHuge3")
	header:SetScale(2.5)
	header:SetPoint("CENTER", optionsFrame, 0, 32)
	header:SetText(AZERITE_BLUE:WrapTextInColorCode("Azerite") .. AZERITE_WHITE:WrapTextInColorCode("UI"))

	-- Edition tag
	local edition = optionsFrame:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
	edition:SetPoint("CENTER", optionsFrame, 0, 48)
	edition:SetText(JUNNEZ_GREEN:WrapTextInColorCode("JuNNeZ Edition Settings"))

	-- Version text
	local version = C_AddOns.GetAddOnMetadata(Addon, "Version") or ""
	local versionText = optionsFrame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	versionText:SetPoint("CENTER", optionsFrame, 0, 28)
	versionText:SetText(CREDITS_GRAY:WrapTextInColorCode("Version: " .. version))

	-- Instruction text
	local instructions = optionsFrame:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
	instructions:SetPoint("CENTER", optionsFrame, 0, -5)
	instructions:SetText(WHITE_FONT_COLOR:WrapTextInColorCode("Open the full AzeriteUI settings menu with /az or the button below."))

	-- "Open Options" button (centered, below midpoint)
	local template = "SharedButtonLargeTemplate"
	if not C_XMLUtil or not C_XMLUtil.GetTemplateInfo or not C_XMLUtil.GetTemplateInfo(template) then
		template = "UIPanelDynamicResizeButtonTemplate"
	end
	local button = CreateFrame("Button", nil, optionsFrame, template)
	button:SetText("Open AzeriteUI Options")
	DynamicResizeButton_Resize(button)
	button:SetPoint("CENTER", optionsFrame, 0, -45)
	button:SetScale(2)
	button:SetScript("OnClick", function()
		if AceConfigRegistry:GetOptionsTable(Addon) then
			AceConfigDialog:SetDefaultSize(Addon, 880, 720)
			AceConfigDialog:Open(Addon)
		end
	end)

	-- Credits section (bottom area)
	local creditsHeader = optionsFrame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	creditsHeader:SetPoint("BOTTOM", optionsFrame, "BOTTOM", 0, 80)
	creditsHeader:SetText(AZERITE_BLUE:WrapTextInColorCode("Credits & Maintainers"))

	local credits = optionsFrame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	credits:SetPoint("TOP", creditsHeader, "BOTTOM", 0, -4)
	credits:SetJustifyH("CENTER")
	credits:SetWidth(500)
	credits:SetText(
		JUNNEZ_GREEN:WrapTextInColorCode("JuNNeZ") .. CREDITS_GRAY:WrapTextInColorCode(" - Maintainer & Updates") .. "\n" ..
		GOLDPAW_GOLD:WrapTextInColorCode("Lars Norberg (Goldpaw)") .. CREDITS_GRAY:WrapTextInColorCode(" - Original Code") .. "\n" ..
		GOLDPAW_GOLD:WrapTextInColorCode("Daniel Troko") .. CREDITS_GRAY:WrapTextInColorCode(" - Original Design") .. "\n" ..
		AZERITE_BLUE:WrapTextInColorCode("Arahort") .. CREDITS_GRAY:WrapTextInColorCode(" - LibOrb System") .. "\n" ..
		AZERITE_BLUE:WrapTextInColorCode("Rui") .. CREDITS_GRAY:WrapTextInColorCode(" - MapShrinker Integration & Nameplate Optimization")
	)

	-- Required callbacks for Settings canvas frames
	optionsFrame.OnCommit = function() end
	optionsFrame.OnDefault = function() end
	optionsFrame.OnRefresh = function() end

	-- Register using canvas layout (exact Platynator pattern)
	local category = _G.Settings.RegisterCanvasLayoutCategory(optionsFrame, Addon)
	category.ID = Addon
	_G.Settings.RegisterAddOnCategory(category)

	self.settingsCategory = category
end


-- Lua API
local math_max = math.max
local next = next
local ipairs = ipairs
local pairs = pairs
local string_format = string.format
local table_remove = table.remove
local table_sort = table.sort
local type = type

Options.GenerateProfileMenu = function(self)
	local options = {
		type = "group",
		childGroups = "tree",
		args = {
			profiles = {
				name = L["Settings Profile"],
				desc = L["Choose your settings profile. This choice affects all settings including frame placement."],
				type = "select",
				style = "dropdown",
				order = 0,
				values = function(info)
					local values = {}
					for i,profileKey in ipairs(ns:GetProfiles()) do
						values[profileKey] = profileKey
					end
					return values
				end,
				set = function(info, val)
					ns:SetProfile(val)
				end,
				get = function(info)
					return ns:GetProfile()
				end
			},
			space1 = {
				name = "", order = 1, type = "description"
			},
			reset = {
				name = L["Reset"],
				type = "execute",
				order = 2,
				confirm = function(info)
					return _G.CONFIRM_RESET_SETTINGS
				end,
				func = function(info)
					ns:ResetProfile(ns:GetProfile())
				end
			},
			delete = {
				name = L["Delete"],
				type = "execute",
				order = 3,
				confirm = function(info)
					return string_format(L["Are you sure you want to delete the preset '%s'? This cannot be undone."], ns:GetProfile())
				end,
				disabled = function(info)
					return ns:IsBuiltinProfile(ns:GetProfile())
				end,
				func = function(info)
					ns:DeleteProfile(ns:GetProfile())
				end
			},
			space2 = {
				name = "", order = 4, type = "description"
			},
			newprofileheader = {
				name = L["Create New Profile"],
				desc = L["Create a new settings profile."],
				type = "header",
				order = 5
			},
			newprofileName = {
				name = L["Name of new profile:"],
				type = "input",
				order = 6,
				arg = "", -- store the name here
				validate = function(info,val)
					if (not val or val == "") then
						return L["The new profile needs a name."]
					end
					if (ns:ProfileExists(val)) then
						return L["Profile already exists."]
					end
					return true
				end,
				get = function(info)
					return info.option.arg
				end,
				set = function(info,val)
					info.option.arg = val
				end
			},
			space3 = {
				name = "", order = 7, type = "description"
			},
			create = {
				name = L["Create"],
				desc = L["Create a new profile with the chosen name."],
				type = "execute",
				order = 8,
				disabled = function(info)
					local val = info.options.args.newprofileName.arg
					return (not val or val == "" or ns:ProfileExists(val))
				end,
				func = function(info)
					local layoutName = info.options.args.newprofileName.arg
					if (layoutName) then
						ns:SetProfile(layoutName)
						info.options.args.newprofileName.arg = ""
					end
				end
			},
			duplicate = {
				name = L["Duplicate"],
				desc = L["Create a new profile with the chosen name and copy the settings from the currently active one."],
				type = "execute",
				order = 9,
				disabled = function(info)
					local val = info.options.args.newprofileName.arg
					return (not val or val == "" or ns:ProfileExists(val))
				end,
				func = function(info)
					local layoutName = info.options.args.newprofileName.arg
					if (layoutName) then
						ns:DuplicateProfile(layoutName)
						info.options.args.newprofileName.arg = ""
					end
				end
			}
		}
	}
	if (ns.IsDevelopment and ns.db.global.enableDevelopmentMode) then
		options.args.space4 = {
			name = "", order = 10, type = "description"
		}
		options.args.export = {
			name = "Export",
			desc = "Expert the current settings profile to a string you can copy and share with other people.",
			type = "execute",
			order = 11,
			disabled = function(info) return true end,
			func = function(info) end
		}
		options.args.import = {
			name = "Import",
			desc = "Import settings from a string into the current options profile.",
			type = "execute",
			order = 12,
			disabled = function(info) return true end,
			func = function(info) end
		}
		options.args.space5 = {
			name = "", order = 13, type = "description"
		}
	end

	local order = 0
	for i,arg in next,options.args do
		order = math_max(order, arg.order or 0)
	end
	order = order + 10
	return options, order
end

Options.Refresh = function(self)
	if (AceConfigRegistry:GetOptionsTable(Addon)) then
		AceConfigRegistry:NotifyChange(Addon)
	end
end

Options.OpenOptionsMenu = function(self)
	if (AceConfigRegistry:GetOptionsTable(Addon)) then
		AceConfigDialog:SetDefaultSize(Addon, 880, 720)
		AceConfigDialog:Open(Addon)
	end
end

Options.AddGroup = function(self, name, group, priority)
	if (not self.objects) then
		self.objects = {}
	end
	if (group) then
		self.objects[#self.objects + 1] = { name = name, group = group, priority = priority }
	end
end

Options.GenerateOptionsMenu = function(self)
	if (not self.objects) then return end

	-- Generate the menus, remove empty objects.
	for i = #self.objects,1,-1 do
		local data = self.objects[i]
		if (type(data.group) == "function") then
			data.group = data.group()
			if (not data.group) then
				table_remove(self.objects, i)
			end
		end
	end

	-- Sort groups by priority, then localized name.
	table_sort(self.objects, function(a,b)
		if ((a.priority or 0) == (b.priority or 0)) then
			return a.group.name < b.group.name
		else
			return (a.priority or 0) < (b.priority or 0)
		end
	end)

	-- Generate the options table.
	local options, orderoffset = self:GenerateProfileMenu()

	local order = orderoffset
	for i,data in ipairs(self.objects) do
		if (data.group) then
			order = order + 10
			data.group.order = order
			data.group.childGroups = data.group.childGroups or "tab"
			options.args[data.name] = data.group
		end
	end

	self.options = options

	AceConfigRegistry:RegisterOptionsTable(Addon, options)
end

Options.GetOptionsObject = function(self)
	return self.options
end

Options.OnEvent = function(self, event, ...)
	if (event == "PLAYER_ENTERING_WORLD") then
		local isInitialLogin, isReloadingUi = ...
		if (isInitialLogin or isReloadingUi) then
			self:GenerateOptionsMenu()
			self:UnregisterEvent("PLAYER_ENTERING_WORLD", "OnEvent")
		end
		if (ns.IsRetail) and (EditModeManagerFrame and EditModeManagerFrame.accountSettings ~= nil) then
			self:Refresh()
		end

	elseif (event == "PLAYER_TALENT_UPDATE") then
		self:Refresh()
	end
end

Options.OnEnable = function(self)
	self:RegisterChatCommand("az", "OpenOptionsMenu")
	self:RegisterChatCommand("azerite", "OpenOptionsMenu")
	self:RegisterEvent("PLAYER_ENTERING_WORLD", "OnEvent")
	self:RegisterEvent("PLAYER_TALENT_UPDATE", "OnEvent")
	ns.RegisterCallback(self, "OptionsNeedRefresh", "Refresh")
	self:InitializeSettingsPanel()
end
