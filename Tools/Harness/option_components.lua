-- Loads the real component modules that an option page builds from directly, for the
-- option harnesses (panel, real_options, config_diff). Without them a page that
-- returns nil when its module is missing is silently left out of every check.
-- Usage: dofile(".../option_components.lua")(load, ns)
--   load(relative) loads an addon file with (Addon, ns); ns is the harness namespace.
return function(load, ns)
	ns.Prefix = ns.Prefix or "AzeriteUI"
	ns.oUF = ns.oUF or { RegisterInitCallback = function() end }

	-- Marker toolbar defaults must be real, or Group Frames silently omits the section.
	ns.MovableModulePrototype = ns.MovableModulePrototype or { defaults = {} }
	ns.API.GetEffectiveScale = ns.API.GetEffectiveScale or function() return 1 end
	load("Components/Misc/RaidTools.lua")
	load("Components/Misc/RaidToolsActions.lua")
	local raidTools = ns:GetModule("RaidTools", true)
	if (raidTools) then
		raidTools.db = raidTools:GenerateDefaults()
		raidTools.GetProfileDefaults = function(self) return self:GenerateDefaults().profile end
	end

	load("Components/Misc/TargetMarkersLite.lua")
	local lite = ns:GetModule("TargetMarkersLite", true)
	if (lite) then
		lite.db = lite:GenerateDefaults()
		lite.GetProfileDefaults = function(self) return self:GenerateDefaults().profile end
	end

	-- Group Indicators page: corner list, class suggestions, spell parser.
	load("Components/UnitFrames/GroupIndicators.lua")

	-- Aura Sounds page: shown where the client has AddAuraSound and its trigger enum.
	_G.Enum = _G.Enum or {}
	_G.Enum.UnitAuraSoundTrigger = _G.Enum.UnitAuraSoundTrigger or { Added = 0, ApplicationsIncreased = 1, Removed = 2 }
	_G.C_UnitAuras = _G.C_UnitAuras or {}
	_G.C_UnitAuras.AddAuraSound = _G.C_UnitAuras.AddAuraSound or function() return 1 end
	_G.C_UnitAuras.RemoveAuraSound = _G.C_UnitAuras.RemoveAuraSound or function() end
	load("Components/Auras/AuraSounds.lua")
	local sounds = ns:GetModule("AuraSounds")
	if (sounds and not rawget(sounds, "db")) then
		local profile = {}
		for key, value in pairs(sounds.defaults.profile) do profile[key] = value end
		sounds.db = { profile = profile }
		sounds.registered = {}
	end
end
