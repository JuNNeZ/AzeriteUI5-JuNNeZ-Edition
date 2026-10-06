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
local API = ns.API or {}
ns.API = API

-- Lua API
local string_lower = string.lower

-- GLOBALS: UnitName, GetAddOnEnableState, GetAddOnInfo, GetNumAddOns

local PLAYER_NAME = UnitName("player")

-- Proxy for the Blizzard method, which also includes the 'enabled' flag.
local GetAddOnInfo = function(index)
	local name, title, notes, loadable, reason, security = _G.GetAddOnInfo(index)
	local enabled = not(_G.GetAddOnEnableState(PLAYER_NAME, index) == 0)
	return name, title, notes, enabled, loadable, reason, security
end

-- Check if an addon exists	in the addon listing
local IsAddOnAvailable = function(target)
	local target = string_lower(target)
	for i = 1,_G.GetNumAddOns() do
		local name = GetAddOnInfo(i)
		if (string_lower(name) == target) then
			return true
		end
	end
end

-- Check if an addon is enabled	in the addon listing
-- *Making this available as a generic library method.
local IsAddOnEnabled = function(target)
	local target = string_lower(target)
	for i = 1,_G.GetNumAddOns() do
		local name, _, _, enabled, loadable = GetAddOnInfo(i)
		if (string_lower(name) == target) then
			if (enabled and loadable) then
				return true
			end
		end
	end
end

-- Check if an addon exists in the addon listing and loadable on demand
local IsAddOnLoadable = function(target, ignoreLoD)
	local target = string_lower(target)
	for i = 1,_G.GetNumAddOns() do
		local name, _, _, _, loadable = GetAddOnInfo(i)
		if (string_lower(name) == target) then
			if (loadable or ignoreLoD) then
				return true
			end
		end
	end
end

-- The title from the addon's TOC, which is the name the player knows it by in
-- the addon list. Falls back to the folder name.
local GetAddOnTitle = function(addon)
	local _, title = _G.C_AddOns.GetAddOnInfo(addon)
	if (type(title) == "string" and title ~= "") then
		return title
	end
	return addon
end

-- Asks which addon should own a feature when another enabled addon is proven to
-- clash with AzeriteUI's version of it. Only for real clashes, read from the other
-- addon's source; an addon that merely adds to the same frame is not one.
--   opts.key      unique suffix for the popup
--   opts.feature  localized name of the feature, for the question
--   opts.rival    folder name of the other addon
--   opts.OnChoose function(choice), choice is "azeriteui", "other" or "both".
--                 Called before anything else happens, so the caller can save it.
-- "azeriteui" turns the rival off for this character, the same call Blizzard's
-- addon list makes with one character selected, and reloads. "both" reloads too.
-- "other" reloads nothing; the caller applies it. Decide Later calls nothing.
local ShowAddonConflictPrompt = function(opts)
	if (not StaticPopupDialogs or not StaticPopup_Show) then
		return
	end
	if (type(opts) ~= "table" or type(opts.rival) ~= "string" or type(opts.key) ~= "string") then
		return
	end

	local L = LibStub("AceLocale-3.0"):GetLocale(Addon)
	local key = "AZERITEUI_ADDON_CONFLICT_"..string.upper(opts.key)
	local choose = function(data, choice)
		if (type(data) ~= "table") then return end
		if (type(data.OnChoose) == "function") then
			data.OnChoose(choice)
		end
		if (choice == "azeriteui") then
			_G.C_AddOns.DisableAddOn(data.rival, UnitName("player"))
			ReloadUI()
		elseif (choice == "both") then
			ReloadUI()
		end
	end

	if (not StaticPopupDialogs[key]) then
		StaticPopupDialogs[key] = {
			text = "%s",
			button1 = "AzeriteUI",
			button3 = L["Both (unsupported)"],
			button4 = L["Decide Later"],
			-- Four outcomes need Blizzard's per button callbacks. Without this flag
			-- StaticPopup_OnClick sends buttons two and four to the same OnCancel.
			selectCallbackByIndex = true,
			OnButton1 = function(dialog, data) choose(data, "azeriteui") end,
			OnButton2 = function(dialog, data) choose(data, "other") end,
			OnButton3 = function(dialog, data) choose(data, "both") end,
			OnButton4 = function(dialog, data) end,
			-- No OnCancel, so Escape only closes the popup and decides nothing.
			hideOnEscape = true,
			timeout = 0,
			whileDead = true,
			preferredIndex = 3
		}
	end

	-- The second button carries the other addon's name, so it is set on every show.
	local title = GetAddOnTitle(opts.rival)
	StaticPopupDialogs[key].button2 = title

	local text = string.format(L["%s and AzeriteUI both restyle the same part of the interface, and the two do not work together: %s. Which one do you want to use?"], title, opts.feature or "")
		.. "|n|n" .. string.format(L["Picking AzeriteUI turns %s off for this character and reloads the interface. Both keeps the two running, which is not supported."], title)

	StaticPopup_Show(key, text, nil, { rival = opts.rival, OnChoose = opts.OnChoose })
end

-- Global API
---------------------------------------------------------
API.GetAddOnInfo = GetAddOnInfo
API.GetAddOnTitle = GetAddOnTitle
API.ShowAddonConflictPrompt = ShowAddonConflictPrompt
API.IsAddOnLoadable = IsAddOnLoadable
API.IsAddOnEnabled = IsAddOnEnabled
API.IsAddOnAvailable = IsAddOnAvailable
