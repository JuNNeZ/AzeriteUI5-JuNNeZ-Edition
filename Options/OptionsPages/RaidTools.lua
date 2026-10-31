-- MIT License. Copyright (c) 2026 Jonas "JuNNeZ" Andersen.
local Addon, ns = ...
local L = LibStub("AceLocale-3.0"):GetLocale(Addon)
local Options = ns:GetModule("Options")

Options.GenerateRaidToolsOptions = function(self)
	local module = ns:GetModule("RaidTools", true)
	if (not module or not module.db) then return end
	local group = {
		name = L["Raid / Party panel"], type = "group", order = 210,
		args = {
			enabled = {
				name = L["Enable"], type = "toggle", order = 1, width = "full",
				get = function() return module.db.profile.enabled end,
				set = function(_, value) module.db.profile.enabled = value; module:UpdateSettings() end
			},
			help = {
				name = L["Group overview, raid group filters, markers and leader tools. Move with /lock. Administrative actions are unavailable in combat."],
				type = "description", order = 2
			},
			collapsed = {
				name = L["Fold panel"], type = "toggle", order = 3, width = "full",
				get = function() return module.db.profile.collapsed end,
				set = function(_, value) module.db.profile.collapsed = value; module:UpdateSettings() end
			},
			preview = {
				name = L["Preview raid panel"], desc = L["Toggle a preview with inactive marker buttons. Also available with /azmarkers."],
				type = "execute", order = 4,
				disabled = function() return InCombatLockdown() or not module.db.profile.enabled end,
				func = function() module:TogglePreview() end
			}
		}
	}
	if (ns.OptionsKit and ns.OptionsKit.Defaults) then ns.OptionsKit.Defaults.Bind(group, "RaidTools") end
	return group
end

-- A separate module and mover; neither panel's visibility is changed by this switch.
Options.GenerateTargetMarkersLiteOptions = function(self)
    local module = ns:GetModule("TargetMarkersLite", true)
    if (not module or not module.db) then return end
    local group = {
        name = L["Target markers lite"], type = "group", order = 220,
        args = {
            enabled = {
                name = L["Enable"], type = "toggle", order = 1, width = "full",
                get = function() return module.db.profile.enabled end,
                set = function(_, value) module.db.profile.enabled = value; module:UpdateSettings() end
            },
            help = {
                name = L["A separate movable target-marker bar. Works with the full AzUI panel switched off. Use Show Blizzard Raid Bar on this page to keep or hide Blizzard's panel. Move with /lock."],
                type = "description", order = 2
            },
            layout = {
                name = L["Layout"], type = "select", order = 4, width = "full",
                values = { horizontal = L["Horizontal Layout"], vertical = L["Vertical Layout"], twoRows = L["Two rows"] },
                get = function() local _, layout = module:GetLayoutData(); return layout end,
                set = function(_, value)
                    if (value ~= "horizontal" and value ~= "vertical" and value ~= "twoRows") then return end
                    module.db.profile.layout = value; module:UpdateSettings()
                end
            },
            markerHelp = {
                name = L["Choose markers in display order. Hidden removes a slot; choosing a marker already in use swaps the two slots."],
                type = "description", order = 5
            },
            clearHelp = {
                name = L["Left-click: target marker. Right-click: clear. Shift: ground markers."] .. "\n"
                    .. L["Click: clear all target markers. Shift-click: clear all ground markers."],
                type = "description", order = 6
            },
            preview = {
                name = L["Preview"], desc = L["Preview the inactive lite bar with /azmarkerlite. Enable it first."],
                type = "execute", order = 3,
                disabled = function() return InCombatLockdown() or not module.db.profile.enabled end,
                func = function() module:TogglePreview() end
            }
        }
    }
    local markers = { [0] = L["Hidden"] }
    for index = 1, 8 do markers[index] = _G["RAID_TARGET_" .. index] or tostring(index) end
    for index = 1, 8 do
        local slot = index
        group.args["marker" .. slot] = {
            name = string.format(L["Marker slot %d"], slot), type = "select", order = 10+slot, width = "full",
            values = markers, sorting = { 0, 1, 2, 3, 4, 5, 6, 7, 8 },
            get = function() return module:GetMarkerSlots()[slot] end,
            set = function(_, value) module:SetMarkerSlot(slot, value) end
        }
    end
    if (ns.OptionsKit and ns.OptionsKit.Defaults) then ns.OptionsKit.Defaults.Bind(group, "TargetMarkersLite") end
    return group
end
