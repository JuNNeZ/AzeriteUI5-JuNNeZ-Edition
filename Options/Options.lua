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
local Addon, ns = ...

local L = LibStub("AceLocale-3.0"):GetLocale((...))
local AceConfigDialog = LibStub("AceConfigDialog-3.0")
local AceConfigRegistry = LibStub("AceConfigRegistry-3.0")

-- GLOBALS: CONFIRM_RESET_SETTINGS, Settings, StaticPopupDialogs, StaticPopup_Show, ReloadUI

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
	edition:SetText(JUNNEZ_GREEN:WrapTextInColorCode(L["JuNNeZ Edition Settings"]))

	-- Version text
	local version = C_AddOns.GetAddOnMetadata(Addon, "Version") or ""
	local versionText = optionsFrame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	versionText:SetPoint("CENTER", optionsFrame, 0, 28)
	versionText:SetText(CREDITS_GRAY:WrapTextInColorCode(L["Version:"] .. " " .. version))

	-- Instruction text
	local instructions = optionsFrame:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
	instructions:SetPoint("CENTER", optionsFrame, 0, -5)
	instructions:SetText(WHITE_FONT_COLOR:WrapTextInColorCode(L["Open the full AzeriteUI settings menu with /az or the button below."]))

	-- "Open Options" button (centered, below midpoint)
	local template = "UIPanelDynamicResizeButtonTemplate"
	if not C_XMLUtil or not C_XMLUtil.GetTemplateInfo or not C_XMLUtil.GetTemplateInfo(template) then
		template = "UIPanelButtonTemplate"
	end
	local button = CreateFrame("Button", nil, optionsFrame, template)
	button:SetText(L["Open AzeriteUI Options"])
	if (template == "UIPanelDynamicResizeButtonTemplate" and DynamicResizeButton_Resize and button.padding) then
		DynamicResizeButton_Resize(button)
	else
		local fontString = button.Text or button:GetFontString()
		local textWidth = (fontString and fontString.GetUnboundedStringWidth and fontString:GetUnboundedStringWidth()) or 0
		button:SetSize(math.max(200, math.ceil(textWidth + 40)), math.max(button:GetHeight(), 22))
	end
	button:SetPoint("CENTER", optionsFrame, 0, -45)
	button:SetScale(2)
	button:SetScript("OnClick", function()
		Options:OpenOptionsMenu()
	end)

	-- Credits section (bottom area)
	local creditsHeader = optionsFrame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	creditsHeader:SetPoint("BOTTOM", optionsFrame, "BOTTOM", 0, 80)
	creditsHeader:SetText(AZERITE_BLUE:WrapTextInColorCode(L["Credits & Maintainers"]))

	local credits = optionsFrame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	credits:SetPoint("TOP", creditsHeader, "BOTTOM", 0, -4)
	credits:SetJustifyH("CENTER")
	credits:SetWidth(500)
	credits:SetText(
		JUNNEZ_GREEN:WrapTextInColorCode("JuNNeZ") .. CREDITS_GRAY:WrapTextInColorCode(" - " .. L["Maintainer & Updates"]) .. "\n" ..
		GOLDPAW_GOLD:WrapTextInColorCode("Lars Norberg (Goldpaw)") .. CREDITS_GRAY:WrapTextInColorCode(" - " .. L["Original Code"]) .. "\n" ..
		GOLDPAW_GOLD:WrapTextInColorCode("Daniel Troko") .. CREDITS_GRAY:WrapTextInColorCode(" - " .. L["Original Design"]) .. "\n" ..
		AZERITE_BLUE:WrapTextInColorCode("Arahort") .. CREDITS_GRAY:WrapTextInColorCode(" - " .. L["LibOrb System"]) .. "\n" ..
		AZERITE_BLUE:WrapTextInColorCode("Rui") .. CREDITS_GRAY:WrapTextInColorCode(" - " .. L["MapShrinker Integration & Nameplate Optimization"])
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
local ipairs = ipairs
local pairs = pairs
local string_format = string.format
local table_remove = table.remove
local table_sort = table.sort
local type = type

-- Scratch state for the profile page's export/import boxes. Deliberately not
-- stored in the database: these are transient clipboard contents, not settings.
local exportString, importString = "", ""
local importStatus -- nil, "malformed" or "newer"

-- Imported settings reach the modules immediately, but frames built at load
-- time will not restyle themselves, so ask for a reload rather than leaving
-- the interface in a half-applied state.
Options.PromptImportReload = function(self)
	local key = "AZERITEUI_SETTINGS_IMPORT_RELOAD"
	if (StaticPopupDialogs and not StaticPopupDialogs[key]) then
		StaticPopupDialogs[key] = {
			text = L["Imported settings need a reload of the interface to take effect."],
			button1 = L["Reload UI"],
			button2 = _G.CANCEL or "Cancel",
			OnAccept = function() ReloadUI() end,
			timeout = 0,
			whileDead = true,
			hideOnEscape = true,
			preferredIndex = 3
		}
	end
	if (StaticPopup_Show) then
		StaticPopup_Show(key)
	end
end

-- The profile controls used to sit at the root of the options table, which
-- meant AceConfigDialog drew them above every single page. They are a page of
-- their own now, so the root holds nothing but groups and the options window
-- can build its page list straight from it.
Options.GenerateProfileMenu = function(self)
	local profiles = {
		name = L["Profiles"],
		type = "group",
		order = -10000,
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
					local val = info.options.args.profiles.args.newprofileName.arg
					return (not val or val == "" or ns:ProfileExists(val))
				end,
				func = function(info)
					local layoutName = info.options.args.profiles.args.newprofileName.arg
					if (layoutName) then
						ns:SetProfile(layoutName)
						info.options.args.profiles.args.newprofileName.arg = ""
					end
				end
			},
			-- The options window's own appearance used to sit here, under a
			-- header on the profile page. It is not a profile setting and it is
			-- not a setting for the interface either, so it now has the Settings
			-- tab of the new panel to itself: Options/Kit/PanelOptions.lua.
			duplicate = {
				name = L["Duplicate"],
				desc = L["Create a new profile with the chosen name and copy the settings from the currently active one."],
				type = "execute",
				order = 9,
				disabled = function(info)
					local val = info.options.args.profiles.args.newprofileName.arg
					return (not val or val == "" or ns:ProfileExists(val))
				end,
				func = function(info)
					local layoutName = info.options.args.profiles.args.newprofileName.arg
					if (layoutName) then
						ns:DuplicateProfile(layoutName)
						info.options.args.profiles.args.newprofileName.arg = ""
					end
				end
			}
		}
	}

	local options = {
		type = "group",
		childGroups = "tree",
		args = {
			profiles = profiles
		}
	}

	-- The root holds groups only, so every page added afterwards orders above
	-- the profile page rather than around the controls that used to sit here.
	return options, 0
end

-- Export and import live on their own page at the end of the tree. They need
-- two multiline boxes to be usable at all, and that is more room than the
-- profile page can spare above the settings tree.
Options.GenerateSharingMenu = function(self)
	return {
		name = L["Export & Import"],
		type = "group",
		args = {
			exportHeader = {
				name = L["Export"],
				type = "header",
				order = 1
			},
			exportDescription = {
				name = L["Export the current settings profile to a string you can copy and share with other people."],
				type = "description", fontSize = "medium",
				order = 2
			},
			exportGenerate = {
				name = L["Generate Export String"],
				type = "execute",
				order = 3,
				func = function(info)
					exportString = ns:Export() or ""
				end
			},
			exportString = {
				name = L["Select the text below and copy it with Ctrl-C."],
				type = "input", multiline = 8, width = "full",
				order = 4,
				hidden = function(info) return exportString == "" end,
				get = function(info) return exportString end,
				-- Read-only in practice. Editing the box would only corrupt the string,
				-- so anything typed here is discarded and the generated value restored.
				set = function(info, val) end
			},
			space1 = {
				name = "", order = 5, type = "description"
			},
			importHeader = {
				name = L["Import"],
				type = "header",
				order = 6
			},
			importDescription = {
				name = L["Import settings from a string into the current options profile."],
				type = "description", fontSize = "medium",
				order = 7
			},
			importString = {
				name = L["Paste a settings string here, then press Accept."],
				type = "input", multiline = 8, width = "full",
				order = 8,
				get = function(info) return importString end,
				set = function(info, val)
					importString = val or ""
					importStatus = nil
					if (importString:gsub("%s+", "") ~= "") then
						local container, reason = ns:DecodeImport(importString)
						if (not container) then
							importStatus = reason
						end
					end
				end
			},
			importStatus = {
				name = function(info)
					if (importStatus == "newer") then
						return L["That settings string was created by a newer version of AzeriteUI."]
					end
					return L["That settings string could not be read. Make sure it was copied in full."]
				end,
				type = "description", fontSize = "medium",
				order = 9,
				hidden = function(info) return not importStatus end
			},
			importAccept = {
				name = _G.ACCEPT or "Accept",
				type = "execute",
				order = 10,
				confirm = function(info)
					return L["This overwrites the settings in the currently active profile. Continue?"]
				end,
				disabled = function(info)
					return importStatus ~= nil or importString:gsub("%s+", "") == ""
				end,
				func = function(info)
					local success = ns:Import(importString)
					if (success) then
						importString = ""
						importStatus = nil
						Options:PromptImportReload()
					end
				end
			}
		}
	}
end

-- The new panel is the normal way in. The previous skinned window remains at
-- `/az classic`, and stock AceConfigDialog remains the final `/az legacy`
-- fallback, so a fault in either custom surface never makes options unreachable.
local GetPanel = function()
	return ns.OptionsKit and ns.OptionsKit.Panel
end

local GetClassicWindow = function()
	return ns.OptionsKit and ns.OptionsKit.Window
end

Options.Refresh = function(self)
	if (AceConfigRegistry:GetOptionsTable(Addon)) then
		AceConfigRegistry:NotifyChange(Addon)
	end

	-- A custom container is not in AceConfigDialog.OpenFrames, so the registry
	-- notification above never reaches it. Feed the open page again by hand.
	local panel = GetPanel()
	if (panel and panel:IsShown()) then
		panel:Refresh()
	end

	local window = GetClassicWindow()
	if (window and window:IsShown()) then
		window:Refresh()
	end
end

-- The stock window has to be built from stock Ace3 parts only. Leaving our
-- widget types on the options table would drag any fault in them into the final
-- fallback meant to survive it, so they are handed back first.
Options.OpenStockOptionsMenu = function(self)
	if (not AceConfigRegistry:GetOptionsTable(Addon)) then return end

	local panel = GetPanel()
	if (panel) then
		panel:Close()
	end

	local window = GetClassicWindow()
	if (window) then
		window:Close()
		window:RemoveDialogControls()
	end

	AceConfigDialog:SetDefaultSize(Addon, 880, 720)
	AceConfigDialog:Open(Addon)
	return true
end

-- The panel that `/az` used before Phase 6 is intentionally retained for now.
-- If it cannot be built, fall through to the stock dialog above.
Options.OpenClassicOptionsMenu = function(self)
	if (not AceConfigRegistry:GetOptionsTable(Addon)) then return end

	local panel = GetPanel()
	if (panel) then
		panel:Close()
	end
	AceConfigDialog:Close(Addon)

	local window = GetClassicWindow()
	if (window and window:Open()) then return true end

	return self:OpenStockOptionsMenu()
end

Options.OpenOptionsMenu = function(self, input)
	if (not AceConfigRegistry:GetOptionsTable(Addon)) then return end

	if (input == "classic") then
		return self:OpenClassicOptionsMenu()
	end

	if (input == "legacy" or input == "stock") then
		return self:OpenStockOptionsMenu()
	end

	-- The controls on their own, with no option table behind them. Kept for
	-- judging how a control looks without hunting for one that uses it.
	if (input == "gallery") then
		local gallery = ns.OptionsKit and ns.OptionsKit.Gallery
		if (gallery) then
			return gallery:Toggle()
		end
		return
	end

	-- Bare `/az` is the new panel. `/az new` remains an alias for release notes,
	-- macros and anyone already using the preview command.
	AceConfigDialog:Close(Addon)

	local window = GetClassicWindow()
	if (window) then window:Close() end

	local panel = GetPanel()
	if (panel and panel:Toggle()) then return true end

	return self:OpenClassicOptionsMenu()
end

Options.ToggleOptionsMenu = function(self)
	local panel = GetPanel()
	if (panel and panel:IsShown()) then
		panel:Close()
		return
	end
	self:OpenOptionsMenu()
end

Options.CloseOptionsMenu = function(self)
	local panel = GetPanel()
	if (panel) then
		panel:Close()
	end

	local window = GetClassicWindow()
	if (window) then
		window:Close()
	end
	if (AceConfigRegistry:GetOptionsTable(Addon)) then
		AceConfigDialog:Close(Addon)
	end
end

-- `section` names the band a page sits under in the new panel's rail:
-- setup, frames, bars, world or interface. It is kept here rather than on the
-- options table because AceConfigRegistry validates that table, and an
-- unknown key in it would be a risk for no gain. Pages that name no section
-- fall to the end of the rail under a general heading.
Options.AddGroup = function(self, name, group, priority, section, moduleName)
	if (not self.objects) then
		self.objects = {}
	end
	if (not self.sections) then
		self.sections = {}
	end
	if (group) then
		self.objects[#self.objects + 1] = {
			name = name, group = group, priority = priority, moduleName = moduleName
		}
		self.sections[name] = section
	end
end

-- The rail section for a page, by the key it has in the options table.
Options.GetSection = function(self, name)
	return self.sections and self.sections[name]
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

			-- Only now does the group table exist to bind against.
			if (data.moduleName and ns.OptionsKit and ns.OptionsKit.Defaults) then
				ns.OptionsKit.Defaults.Bind(data.group, data.moduleName)
			end
		end
	end

	-- Placed last so the tree lists it below every settings page.
	order = order + 10
	local sharing = self:GenerateSharingMenu()
	sharing.order = order
	options.args.sharing = sharing

	-- The two pages this module builds itself.
	self.sections = self.sections or {}
	self.sections.profiles = "setup"
	self.sections.sharing = "setup"

	self.options = options

	-- Point every option AzeriteUI has a widget for at that widget, in one
	-- pass, so the five thousand lines of page definitions stay free of
	-- presentation detail. Anything naming a control of its own is untouched.
	local window = GetClassicWindow()
	if (window) then
		window:ApplyDialogControls(options)
	end

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
