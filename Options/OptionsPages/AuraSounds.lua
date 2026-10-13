local _, ns = ...
local L = LibStub("AceLocale-3.0"):GetLocale((...))
local Options = ns:GetModule("Options")

-- /az -> Aura Sounds (Components/Auras/AuraSounds.lua), its own page in the Auras band. Six slots,
-- each a spell, a unit, when to play and which sound. Retail 12.1 only: the section
-- is left out where the client has no C_UnitAuras.AddAuraSound.
function Options:GenerateAuraSoundsOptions()
	local module = ns:GetModule("AuraSounds", true)
	if (not module or not module.db or not module.IsAvailable or not module:IsAvailable()) then return end

	local function Set(info, value)
		module.db.profile[info[#info]] = value
		module:UpdateSettings()
	end
	local function Get(info)
		return module.db.profile[info[#info]]
	end
	local function Off()
		return not module.db.profile.enabled
	end

	local units = { player = L["Player"], target = L["Target"], focus = L["Focus"] }
	local triggers = {
		added = L["When it is gained"],
		stacks = L["When it gains a stack"],
		removed = L["When it fades"]
	}

	local options = {
		name = L["Aura Sounds"],
		type = "group",
		args = {
			description = {
				name = L["Play a sound when an aura is gained, stacks up or fades. The game plays it, so it works in combat, raids and keys. Changes made during a fight apply when it ends."],
				type = "description", order = 1, width = "full"
			},
			enabled = {
				name = L["Enable Aura Sounds"],
				type = "toggle", order = 2, width = "full", set = Set, get = Get
			},
			noSounds = {
				name = L["Only \"None\" is listed? Sounds come from addons such as DBM, BigWigs, WeakAuras or a SharedMedia pack."],
				type = "description", order = 3, width = "full",
				hidden = function()
					for key in pairs(module:GetSoundChoices()) do
						if (key ~= "None") then return true end
					end
					return false
				end
			}
		}
	}

	-- The slots are plain headers inside Aura Sounds, not inline groups: the options
	-- panel lists every sub-group in its section rail, and six "Sound N" entries
	-- there sat level with Player and Target instead of under Aura Sounds.
	for slot = 1, module.Slots do
		local prefix = "sound" .. slot
		local order = 10 * slot
		local args = options.args
		args["slot" .. slot] = {
			name = string.format(L["Sound %d"], slot),
			type = "header", order = order
		}
		-- Fills the Spell field below; typing there still works.
		args[prefix .. "Preset"] = {
			name = L["Common auras"],
			desc = L["Pick an aura, or type your own in Spell."],
			type = "select", order = order + .5, width = 1.2, disabled = Off,
			values = function()
				local values = {}
				for _, preset in ipairs(module.Presets) do
					local id = tonumber(preset.spells)
					values[preset.key] = id and module.SpellName(id) or preset.name
				end
				values.lust = L["Bloodlust / Heroism / Time Warp"]
				values.sated = L["Bloodlust ready again (Sated fades)"]
				return values
			end,
			sorting = function()
				local sorting = {}
				for _, preset in ipairs(module.Presets) do sorting[#sorting + 1] = preset.key end
				return sorting
			end,
			get = function()
				local preset = module:GetPreset(module.db.profile[prefix .. "Spell"])
				return preset and preset.key
			end,
			set = function(_, key)
				for _, preset in ipairs(module.Presets) do
					if (preset.key == key) then
						module.db.profile[prefix .. "Spell"] = preset.spells
						if (preset.trigger) then module.db.profile[prefix .. "Trigger"] = preset.trigger end
						module:UpdateSettings()
						return
					end
				end
			end
		}
		args[prefix .. "Spell"] = {
			name = L["Spell"],
			desc = L["A spell name or ID, or several separated by commas. AzeriteUI looks up the aura each one gives, which is not always the spell's own ID."],
			type = "input", order = order + 1, width = 1.2, get = Get, set = Set, disabled = Off,
			validate = function(info, value)
				if (value:match("^%s*$")) then return true end
				local _, unknown = module:ResolveAuras(value)
				if (#unknown == 0) then return true end
				return string.format(L["Unknown spell: %s"], table.concat(unknown, ", "))
			end
		}
		args[prefix .. "Unit"] = {
			name = L["Unit"], type = "select", order = order + 2, width = .7,
			values = units, get = Get, set = Set, disabled = Off
		}
		args[prefix .. "Trigger"] = {
			name = L["When"], type = "select", order = order + 3, width = 1,
			values = triggers, get = Get, set = Set, disabled = Off
		}
		args[prefix .. "Sound"] = {
			name = L["Sound"], type = "select", order = order + 4, width = 1.2,
			values = function() return module:GetSoundChoices() end,
			get = Get, set = Set, disabled = Off
		}
		args[prefix .. "Preview"] = {
			name = L["Test"], type = "execute", order = order + 5, width = .5,
			func = function() module:PreviewSlot(slot) end, disabled = Off
		}
		-- What the game answered for this slot, so a sound that never plays can be explained.
		args[prefix .. "Status"] = {
			type = "description", order = order + 6, width = "full",
			name = function() return module:GetSlotStatus(slot, L) end
		}
	end

	if (ns.OptionsKit and ns.OptionsKit.Defaults) then
		ns.OptionsKit.Defaults.Bind(options, "AuraSounds")
	end
	return options
end

Options:AddGroup(L["Aura Sounds"], function() return Options:GenerateAuraSoundsOptions() end, -5900, "auras", "AuraSounds")
