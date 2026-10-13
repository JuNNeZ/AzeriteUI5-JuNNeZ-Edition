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
local L = LibStub("AceLocale-3.0"):GetLocale((...))
local Options = ns:GetModule("Options")

-- /az -> Execute range: every execute marker setting on one page. The marker has two
-- switches, one per surface (NamePlates.executeMarker, TargetFrame.executeMarker); the
-- threshold, the lead and the colours are shared and live in the NamePlates profile,
-- which Components/UnitFrames/NamePlates/Settings.lua resolves for both. One profile key
-- holds the threshold: 0 follows the class, anything else was set by hand.

local THRESHOLD_MIN, THRESHOLD_MAX, THRESHOLD_FALLBACK = .05, .5, .2

-- The class's execute threshold (Components/UnitFrames/ExecuteRange.lua), or 20% for a class
-- without one, which is where a threshold set by hand starts.
local GetAutomaticThreshold = function()
	local threshold = ns.API.GetExecuteThreshold and ns.API.GetExecuteThreshold() or 0
	if (type(threshold) ~= "number" or threshold < THRESHOLD_MIN) then
		return THRESHOLD_FALLBACK
	end
	return threshold
end

function Options:GenerateExecuteRangeOptions()
	local plates = ns:GetModule("NamePlates", true)
	if (not plates or not plates.db) then return end
	local target = ns:GetModule("TargetFrame", true)

	local PlatesEnabled = function()
		return plates.db.profile.enabled and not plates.conflictingAddOn and true or false
	end
	local TargetAvailable = function()
		return target and target.db and type(target.IsExecuteMarkerAvailable) == "function"
			and target:IsExecuteMarkerAvailable() and true or false
	end
	local PlatesOn = function()
		return PlatesEnabled() and plates.db.profile.executeMarker and true or false
	end
	local TargetOn = function()
		return TargetAvailable() and target.db.profile.enabled ~= false
			and target.db.profile.executeMarker and true or false
	end
	-- The shared settings matter once the marker shows anywhere.
	local SharedOff = function()
		return not PlatesOn() and not TargetOn()
	end

	-- Shared and nameplate settings. NamePlates:UpdateSettings also refreshes the target's marker.
	local Set = function(info, value)
		plates.db.profile[info[#info]] = value
		plates:UpdateSettings()
	end
	local Get = function(info)
		return plates.db.profile[info[#info]]
	end
	local SetThreshold = function(value)
		plates.db.profile.executeThreshold = value
		plates:UpdateSettings()
	end
	local IsByHand = function()
		local value = plates.db.profile.executeThreshold
		return type(value) == "number" and value > 0
	end

	local options = {
		name = L["Execute range"],
		type = "group",
		args = {
			description = {
				name = L["A line across enemy health bars at your execute threshold. Once an enemy's health falls below it, the part of the bar below the line is tinted."]
					.. " " .. L["Turn it on for nameplates, the target frame or both. The threshold, the lead and the colours apply to both."],
				order = 1, type = "description", fontSize = "medium"
			},
			nameplates = {
				name = L["Nameplates"], order = 2, type = "group", inline = true,
				args = {
					executeMarker = {
						name = L["Show the execute marker"],
						order = 1, type = "toggle", width = "full",
						disabled = function() return not PlatesEnabled() end,
						set = Set, get = Get
					},
					platesOff = {
						name = L["AzeriteUI's nameplates are switched off, or another nameplate addon has them."],
						order = 2, type = "description",
						hidden = PlatesEnabled
					},
					executeCombatOnly = {
						name = L["Only enemies you are fighting"],
						desc = L["Show the marker only on enemies that have you or your pet on their threat list, not on every enemy plate in sight."],
						order = 3, type = "toggle", width = "full",
						disabled = function() return not PlatesOn() end,
						set = Set, get = Get
					}
				}
			},
			target = {
				name = L["Target"], order = 3, type = "group", inline = true,
				hidden = function() return not target or not target.db end,
				args = {
					executeMarker = {
						name = L["Show the execute marker"],
						order = 1, type = "toggle", width = "full",
						disabled = function() return not TargetAvailable() or target.db.profile.enabled == false end,
						set = function(_, value)
							target.db.profile.executeMarker = value
							if (target.UpdateExecuteMarker) then target:UpdateExecuteMarker() end
						end,
						get = function() return target.db.profile.executeMarker end
					},
					unavailable = {
						name = L["This client lacks the health curve APIs required for the target execute marker."],
						order = 2, type = "description",
						hidden = TargetAvailable
					}
				}
			},
			threshold = {
				name = L["Threshold"], order = 4, type = "group", inline = true,
				args = {
					executeThresholdMode = {
						name = L["Threshold"],
						desc = L["Automatic follows your class and specialization, and classes without an execute get no marker. Set it by hand where a talent moves it, as Massacre does."],
						order = 1, type = "select", width = "full",
						values = function() return { auto = L["Automatic"], custom = L["By hand"] } end,
						sorting = function() return { "auto", "custom" } end,
						disabled = SharedOff,
						set = function(_, value) SetThreshold(value == "custom" and GetAutomaticThreshold() or 0) end,
						get = function() return IsByHand() and "custom" or "auto" end
					},
					executeThreshold = {
						name = L["Threshold by hand"],
						desc = L["Where the marker sits when the threshold is set by hand."],
						order = 2, type = "range", width = "full",
						min = THRESHOLD_MIN, max = THRESHOLD_MAX, step = .01, isPercent = true,
						disabled = function() return SharedOff() or not IsByHand() end,
						set = function(_, value) SetThreshold(value) end,
						-- While automatic, the class's threshold, which is where By hand starts from.
						get = function() return IsByHand() and plates.db.profile.executeThreshold or GetAutomaticThreshold() end
					},
					executeLead = {
						name = L["Show from above the threshold"],
						desc = L["The line appears only once the enemy's health is this close to your execute, for example 5% before it. 0% shows it all the time. Also on the target frame."],
						order = 3, type = "range", width = "full",
						-- Dragging stops every 5%; typed values still take whole percents.
						min = 0, max = .2, step = .01, bigStep = .05, isPercent = true,
						disabled = SharedOff,
						set = Set, get = Get
					}
				}
			},
			colors = {
				name = L["Colors"], order = 5, type = "group", inline = true,
				args = {
					executeCustomColors = {
						name = L["Own colours"],
						desc = L["Colour the line and the tint yourself. Also on the target frame."],
						order = 1, type = "toggle", width = "full",
						disabled = SharedOff,
						set = Set, get = Get
					},
					executeLineColor = {
						name = L["Line colour"],
						order = 2, type = "color", hasAlpha = true,
						disabled = function() return SharedOff() or not plates.db.profile.executeCustomColors end,
						get = function(info) return unpack(Get(info) or { 1, 1, 1, .85 }) end,
						-- A new table each time, which is how the plates notice the change.
						set = function(info, r, g, b, a) Set(info, { r, g, b, a }) end
					},
					executeZoneColor = {
						name = L["Tint colour"],
						order = 3, type = "color", hasAlpha = true,
						disabled = function() return SharedOff() or not plates.db.profile.executeCustomColors end,
						get = function(info) return unpack(Get(info) or { 1, .15, .05, .35 }) end,
						set = function(info, r, g, b, a) Set(info, { r, g, b, a }) end
					}
				}
			}
		}
	}

	local Defaults = ns.OptionsKit and ns.OptionsKit.Defaults
	if (Defaults) then
		Defaults.Bind(options, "NamePlates")
		Defaults.Bind(options.args.target, "TargetFrame")
	end
	return options
end

Options:AddGroup(L["Execute range"], function() return Options:GenerateExecuteRangeOptions() end, -6950, "frames", "NamePlates")
