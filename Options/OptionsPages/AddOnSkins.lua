--[[

	The MIT License (MIT)

	Copyright (c) 2026 Jonas "JuNNeZ" Andersen

--]]
-- AddOn Skins: AzeriteUI's looks for other addons' windows, in one place.
--
-- Details, Zygor and Total RP 3 sat on the Themes page, which is about class
-- art, and Masque's switch sits with the action bars it hands over. This page
-- holds the first three and points at the fourth
-- (Docs/Options Navigation Review - 2026-11-22.md, step 4). Settings and saved
-- values are unchanged: each switch still drives the same module.
local _, ns = ...

local L = LibStub("AceLocale-3.0"):GetLocale((...))

local Options = ns:GetModule("Options")

-- GLOBALS: InCombatLockdown, ZygorGuidesViewer, TRP3_MainFrame

-- Components/Misc/Details.lua registers the skin in Details' own selector; this
-- switch applies it to every Details window, or gives each one its old skin back.
local GenerateDetails = function(order)
	local Skin = ns:GetModule("DetailsSkin", true)
	if (not Skin or not Skin.SetApplied) then return end
	local toggle = {
		name = L["Use the AzeriteUI skin on Details windows"],
		desc = L["Gives every Details window the AzeriteUI Forged (Preview) skin through Details' own skin selector. Turning it off gives each window back the skin it had before."],
		order = 1, type = "toggle", width = "full",
		disabled = function() return InCombatLockdown() or not Skin.IsAvailable() end,
		-- ChangeSkin resets a window's appearance to the preset (Details' own behaviour).
		confirm = function() return L["Details resets a window's appearance settings when its skin changes. Window positions and meter data are kept. Continue?"] end,
		get = function() return Skin.IsApplied() end,
		set = function(_, value) Skin:SetApplied(value) end
	}
	local config = ns.OptionsKit and ns.OptionsKit.Config
	if (config and config.SetDisabledDesc) then
		-- Only the missing addon needs saying; combat greys the whole page.
		config.SetDisabledDesc(toggle, function()
			if (not Skin.IsAvailable()) then return L["Requires the Details! Damage Meter addon."] end
		end)
	end
	return { name = "Details", order = order, type = "group", inline = true, args = { apply = toggle } }
end

-- Per-character choices; the character database may not exist yet.
local Char = function() return ns.db and ns.db.char or {} end

local GenerateOptions = function()
	local options = {
		name = L["AddOn Skins"],
		type = "group",
		disabled = InCombatLockdown,
		args = {
			description = {
				name = L["AzeriteUI's look for other addons' windows."],
				order = 1, type = "description", fontSize = "medium"
			},
			details = GenerateDetails(10),
			zygor = {
				name = "Zygor", order = 20, type = "group", inline = true,
				-- Listed only with Zygor loaded; it used to show, greyed, without it.
				hidden = function() return type(ZygorGuidesViewer) ~= "table" end,
				args = { skin = {
					name = L["Skin"], type = "select", order = 1,
					values = { default = L["Default"], Forged = "Forged", Glass = "Glass", ["Field-Journal"] = "Field Journal" },
					sorting = { "default", "Forged", "Glass", "Field-Journal" },
					disabled = function() return InCombatLockdown() or not (type(ZygorGuidesViewer) == "table" and ZygorGuidesViewer.Frame) end,
					get = function() return Char().zygorSkin or "default" end,
					set = function(_, choice) ns:GetModule("ZygorSkin"):SetChoice(choice) end
				} }
			},
			totalRP3 = {
				name = "Total RP 3", order = 30, type = "group", inline = true,
				hidden = function() return not TRP3_MainFrame end,
				args = { skin = {
					name = L["Skin"], type = "toggle", order = 1,
					disabled = InCombatLockdown,
					get = function() return Char().totalRP3Skin == true end,
					set = function(_, enabled) ns:GetModule("TRP3Skin"):SetEnabled(enabled) end
				} }
			},
			-- The switch stays with the buttons it hands over (OptionsPages/ActionBars.lua).
			masque = {
				name = "Masque", order = 40, type = "group", inline = true,
				hidden = function() return not (ns.ActionBarMasque and ns.ActionBarMasque.IsAvailable()) end,
				args = { open = {
					name = L["Masque's switch is under Action Bars"], type = "execute", order = 1,
					func = function()
						local panel = ns.OptionsKit and ns.OptionsKit.Panel
						if (panel and panel.GoTo) then panel:GoTo({ "Action Bars", "masque" }) end
					end
				} }
			}
		}
	}
	return options
end

Options:AddGroup("AddOn Skins", GenerateOptions, -2500, "interface")
