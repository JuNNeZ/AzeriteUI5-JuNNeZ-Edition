local _, ns = ...
local L = LibStub("AceLocale-3.0"):GetLocale((...))
local Options = ns:GetModule("Options")

-- /az -> Unit Frames -> Group Indicators: Sated and corner aura dots on party and
-- raid frames (Components/UnitFrames/GroupIndicators.lua). Stored in the UnitFrames
-- profile, one key per control, so Reset and the changed markers work as elsewhere.
function Options:GenerateGroupIndicatorsOptions()
	local module = ns:GetModule("UnitFrames", true)
	local indicators = ns.GroupIndicators
	if (not module or not module.db or not indicators) then return end

	local function Refresh()
		indicators.Refresh()
	end
	local function Set(info, value)
		module.db.profile[info[#info]] = value
		Refresh()
	end
	local function Get(info)
		return module.db.profile[info[#info]]
	end
	local function CornersOff()
		return not module.db.profile.groupCorners
	end
	local function NoContainers()
		return not indicators.CanBuildCorners()
	end

	local options = {
		name = L["Group Indicators"],
		type = "group",
		order = 55,
		args = {
			description = {
				name = L["Small markers on party and raid frames. Both are off until you turn them on."],
				type = "description", order = 1, width = "full"
			},
			groupSated = {
				name = L["Show Sated"],
				desc = L["Shows a small icon on members who cannot benefit from Bloodlust, Heroism, Time Warp or drums again yet, with a swipe for the time left."],
				type = "toggle", order = 10, width = "full", set = Set, get = Get
			},
			cornerHeader = {
				name = L["Corner Dots"], type = "header", order = 20,
				hidden = NoContainers
			},
			cornerDescription = {
				name = L["A small icon in a corner of the health bar while one of the listed buffs is on that member. Type spell IDs or names, separated by commas. The game does the matching, so they keep working in combat."],
				type = "description", order = 21, width = "full",
				hidden = NoContainers
			},
			groupCorners = {
				name = L["Show Corner Dots"],
				type = "toggle", order = 22, width = "full", set = Set, get = Get,
				hidden = NoContainers
			},
			groupCornerOnlyMine = {
				name = L["Only Mine"],
				desc = L["Only show the listed buffs when you cast them."],
				type = "toggle", order = 23, width = "full", set = Set, get = Get,
				hidden = NoContainers, disabled = CornersOff
			},
			groupCornerSize = {
				name = L["Dot Size"],
				type = "range", order = 24, min = 6, max = 20, step = 1, width = "full",
				set = Set, get = Get,
				hidden = NoContainers, disabled = CornersOff
			},
			suggestions = {
				name = L["Use My Class's Suggestions"],
				desc = L["Fills the corners with common buffs for your class. Replaces what is there."],
				type = "execute", order = 25,
				hidden = function()
					if (NoContainers()) then return true end
					local _, class = UnitClass("player")
					return not indicators.ClassSuggestions[class]
				end,
				disabled = CornersOff,
				confirm = function() return L["Replace the corner spell lists with your class's suggestions?"] end,
				func = function()
					local _, class = UnitClass("player")
					local preset = indicators.ClassSuggestions[class] or {}
					for _, corner in ipairs(indicators.Corners) do
						module.db.profile["groupCornerSpells" .. corner] = preset[corner] or ""
					end
					Refresh()
				end
			}
		}
	}

	local cornerNames = {
		TOPLEFT = L["Top Left"], TOPRIGHT = L["Top Right"],
		BOTTOMLEFT = L["Bottom Left"], BOTTOMRIGHT = L["Bottom Right"]
	}
	for index, corner in ipairs(indicators.Corners) do
		options.args["groupCornerSpells" .. corner] = {
			name = cornerNames[corner],
			type = "input", order = 30 + index, width = "full",
			hidden = NoContainers, disabled = CornersOff,
			get = Get, set = Set,
			-- Names the client does not know are refused, so a typo is caught at once
			-- instead of a corner that silently never lights.
			validate = function(info, value)
				local _, unknown = indicators.ParseSpellList(value)
				if (#unknown > 0) then
					return string.format(L["Unknown spell: %s"], table.concat(unknown, ", "))
				end
				return true
			end
		}
	end

	if (ns.OptionsKit and ns.OptionsKit.Defaults) then
		ns.OptionsKit.Defaults.Bind(options, "UnitFrames")
	end
	return options
end
