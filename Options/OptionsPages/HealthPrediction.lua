local _, ns = ...
local Options = ns:GetModule("Options")

function Options:GenerateHealthPredictionOptions()
	local module = ns:GetModule("UnitFrames", true)
	if (not module or not module.db) then return end
	local function Set(info, value)
		module.db.profile[info[#info]] = value
		ns.API.RefreshHealthPrediction()
	end
	local function Get(info)
		return module.db.profile[info[#info]] ~= false
	end
	local options = {
		name = "Incoming Heals and Absorbs",
		type = "group",
		order = 50,
		args = {
			description = {
				name = "Show prediction layers inside AzeriteUI health bars, including group frames and nameplates. Absorbs use diagonal stripes; healing absorbs use a dark red lattice. Requires the client's heal prediction calculator.",
				type = "description", order = 1, width = "full"
			},
			showIncomingHeals = {
				name = "Show Incoming Heals", desc = "Show incoming healing after current health.",
				type = "toggle", order = 10, width = "full", set = Set, get = Get
			},
			showDamageAbsorbs = {
				name = "Show Damage Absorbs", desc = "Show shields with diagonal stripes using the selected display mode.",
				type = "toggle", order = 20, width = "full", set = Set, get = Get
			},
			showOverhealIndicator = {
				name = "Show Overheal Indicator",
				desc = "Show a green end marker when pending incoming healing exceeds missing health. Requires Show Incoming Heals. This is a prediction, not a record of healing already wasted.",
				type = "toggle", order = 15, width = "full", set = Set,
				get = function() return module.db.profile.showOverhealIndicator == true end
			},
			absorbDisplayMode = {
				name = "Absorb Display Mode",
				desc = "Total shield shows the full amount from the bar's end, overlapping health when needed; a gap is possible at low health. Follow health starts after health and incoming heals, shows only what fits, and marks excess with an end stripe.",
				type = "select", order = 25, width = "full",
				values = { total = "Total shield", followHealth = "Follow health" },
				set = Set,
				get = function()
					return module.db.profile.absorbDisplayMode == "followHealth" and "followHealth" or "total"
				end
			},
			showHealAbsorbs = {
				name = "Show Healing Absorbs", desc = "Show healing absorption extending back into current health, after accounting for incoming healing.",
				type = "toggle", order = 30, width = "full", set = Set, get = Get
			}
		}
	}
	if (ns.OptionsKit and ns.OptionsKit.Defaults) then
		ns.OptionsKit.Defaults.Bind(options, "UnitFrames")
	end
	return options
end
