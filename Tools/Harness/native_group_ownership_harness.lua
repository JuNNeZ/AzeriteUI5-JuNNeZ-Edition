-- Actual group module lifecycle and native suppression callbacks, offline.
-- No native frame, SmartNavigation, restricted-click or combat emulation.
local root = arg[1] or "."
local checks, failures = 0, 0
local function check(value, label)
	checks = checks + 1
	if not value then failures = failures + 1; print("FAIL: " .. label) end
end
local function read(path)
	local file = assert(io.open(root .. "/" .. path, "rb"))
	local source = file:read("*a"):gsub("\r\n", "\n")
	file:close()
	return source
end
local function load(path, env, ns)
	local chunk = assert(loadstring(read(path), "@" .. path))
	setfenv(chunk, env)
	return chunk("AzeriteUI", ns)
end
local noop = function() end
local Auto
Auto = function()
	return setmetatable({}, { __index = function(self, key) local value = Auto(); rawset(self, key, value); return value end,
		__call = function() return Auto() end })
end
-- party: direct D-pad party targeting (GamepadUsePartyTargeting) at load.
local function Controller(world)
	return { IsActive = function() return world.native end,
		UsesNativePartyFrames = function() return world.native and not world.party end,
		UsesNativeRaidFrames = function() return world.native end }
end
local function NativeOwned(world, name)
	if name == "PartyFrames" then return world.native and not world.party end
	return world.native
end
local function lifecycle(native, party)
	local modules, profiles = {}, {}
	local world = { native = native, party = party, combat = false, frames = 0, mutations = 0 }
	local env = setmetatable({ _G = false, UIParent = {}, PARTY = "Party", RAID = "Raid",
		InCombatLockdown = function() return world.combat end,
		LibStub = function() return Auto() end,
		Enum = {}, CreateFrame = function() world.frames = world.frames + 1; error("unexpected custom frame startup") end,
		hooksecurefunc = function() world.mutations = world.mutations + 1 end
	}, { __index = _G })
	env._G = env
	local ns = { Prefix = "AzeriteUI", oUF = Auto(), API = Auto(), Colors = {}, WoW11 = true,
		NativeController = Controller(world),
		SpecIcons = { Bind = noop }, UnitFrames = {},
		MovableModulePrototype = { defaults = {}, OnEnable = noop,
			OnInitialize = function(self)
				profiles[self:GetName()] = profiles[self:GetName()] or { enabled = true, savedPosition = { "CENTER", 123, 456 } }
				self.db = { profile = profiles[self:GetName()] }
				self.initialized = (self.initialized or 0) + 1
			end,
			GetAnchor = function(self) return self.anchor end,
			UpdatePositionAndScale = noop, UpdateAnchor = noop }
	}
	function ns:Merge(target, source)
		for key, value in pairs(source or {}) do if target[key] == nil then target[key] = value end end
		return target
	end
	function ns:NewModule(name, prototype)
		local module = { events = {}, enabledState = true }
		if type(prototype) == "table" then self:Merge(module, prototype) end
		function module:GetName() return name end
		function module:SetEnabledState(value) self.enabledState = value end
		function module:IsEnabled() return self.enabledState end
		function module:Disable() self.enabledState = false end
		function module:Enable() self.enabledState = true; if self.OnEnable then self:OnEnable() end end
		function module:RegisterEvent(event, callback) self.events[event] = callback end
		function module:UnregisterEvent(event) self.events[event] = nil end
		function module:CreateAnchor() world.frames = world.frames + 1; error("unexpected group anchor") end
		function module:SecureHook() world.mutations = world.mutations + 1 end
		modules[name] = module
		return module
	end
	function ns:GetModule(name) return modules[name] end
	ns.GetConfig = function() return Auto() end
	ns.API.GetEffectiveScale = function() return 1 end
	load("Components/UnitFrames/UnitFrame.lua", env, ns)
	load("Components/UnitFrames/Units/Party.lua", env, ns)
	load("Components/UnitFrames/Units/Raid5.lua", env, ns)
	load("Components/UnitFrames/Units/RaidLarge.lua", env, ns)
	check(type(modules.PartyFrames.StylePlayer) == "function", "Party style remains available for PlayerParty")
	for _, name in ipairs({ "PartyFrames", "RaidFrame5", "RaidFrame25", "RaidFrame40" }) do
		local module = modules[name]
		check(type(module.IsNativeGroupFrame) == "function", name .. " has the shared native ownership predicate")
		module:OnInitialize()
		check(module.initialized == 1 and module.db.profile.enabled, name .. " retains initialized saved namespace")
		local owned = NativeOwned(world, name)
		check(module:IsEnabled() == not owned, name .. " runtime state follows group ownership")
		check(module:IsNativeGroupFrame() == owned, name .. " ownership predicate matches the session")
		check(module.db.profile.savedPosition[2] == 123 and module.db.profile.savedPosition[3] == 456,
			name .. " preserves saved layout")
		if owned then
			for _, method in ipairs({ "OnEnable", "CreateUnitFrames", "DisableBlizzard", "UpdateSettings", "UpdateEnabled" }) do
				local ok = pcall(module[method], module)
				check(ok and not module.frame, name .. " native session ignores " .. method)
			end
			world.combat = true
			module:UpdateSettings(); module:UpdateEnabled()
			check(module.events.PLAYER_REGEN_ENABLED == nil, name .. " no deferred custom startup in combat")
			world.combat = false
		end
	end
	check(world.frames == 0 and world.mutations == 0, "module definitions and native callbacks create no group frames/hooks")
	local player = ns:NewModule("PlayerFrameParty", ns.UnitFrameModule)
	player:OnInitialize()
	check(player:IsEnabled() and not (player.IsNativeGroupFrame and player:IsNativeGroupFrame()), "PlayerParty remains independent")
	for _, entry in ipairs({ {"PartyFrames", "PartyFrames.lua"}, {"RaidFrame5", "Raid5Frames.lua"},
		{"RaidFrame25", "Raid25Frames.lua"}, {"RaidFrame40", "Raid40Frames.lua"} }) do
		local module = modules[entry[1]]
		load("WoW11/UnitFrames/" .. entry[2], env, ns)
		module:OnInitialize()
		if NativeOwned(world, entry[1]) then
			local ok = pcall(module.DelayedEnable, module)
			check(ok and not module.frame and not module:IsEnabled(), entry[1] .. " delayed adapter retains native ownership")
			check(module.db.profile.enabled and module.db.profile.savedPosition[2] == 123, entry[1] .. " adapter preserves saved settings")
		end
	end
	return world, ns, modules
end

local function quarantine(native, party)
	local world = { native = native, party = party, mutations = 0, hooks = 0, inRaid = false, quarantined = {} }
	local ns = { NativeController = Controller(world) }
	function ns:GetModule(name)
		return { db = { profile = { enabled = name ~= "ArenaFrames", showBlizzardRaidBar = false } },
			UpdateHeader = function() world.mutations = world.mutations + 1 end }
	end
	local function frame(name)
		local result = { name = name, shown = true, alpha = 1, parent = "native", events = "native" }
		function result:GetName() return self.name end
		for _, method in ipairs({ "Show", "Hide", "SetAlpha", "SetParent", "UnregisterAllEvents" }) do
			result[method] = function(self, value) world.mutations = world.mutations + 1; self.changed = value or method end
		end
		function result:HookScript() world.hooks = world.hooks + 1 end
		return result
	end
	local nativeManager = frame("CompactRaidFrameManager")
	local env = setmetatable({ ns = ns, API = { SafeCall = function(_, fn, ...) return fn(...) end },
		UIParent = {}, InCombatLockdown = function() return world.combat end,
		IsInGroup = function() return true end, IsInRaid = function() return world.inRaid end,
		MAX_PARTY_MEMBERS = 4, MAX_RAID_MEMBERS = 40, MAX_ARENA_MEMBERS = 5,
		QuarantineFrame = function(f)
			world.mutations = world.mutations + 1
			local name = type(f) == "table" and f.GetName and f:GetName() or f
			if type(name) == "string" then world.quarantined[name] = true end
		end,
		PrepareCompactFrame = noop, IsArenaContextActive = function() return false end,
		quarantineHooked = {}, GetCompactRaidFilterGroupButtons = function() return nil end,
		GetRaidModule = function(name) return ns:GetModule(name) end,
		GetRaidModuleFrames = function() return nil, nil end,
		GetCompactRaidGroupFilter = function() return "1,2,3,4,5,6,7,8" end,
		GetCompactRaidHiddenMode = function() return false end,
		hooksecurefunc = function() world.hooks = world.hooks + 1 end,
		C_Timer = { After = function() error("native raid mirror must not schedule work") end }
	}, { __index = _G })
	env._G = { CompactRaidFrameManager = nativeManager, CompactPartyFrame = frame("CompactPartyFrame"),
		CompactRaidFrameContainer = frame("CompactRaidFrameContainer") }
	local source = read("Core/FixBlizzardBugs.lua")
	assert(loadstring(source, "@Core/FixBlizzardBugs.lua"))
	local parts = {
		assert(source:match("(local pendingRaidBarVisible = nil.-)%s*%-%- Export for options UI")),
		assert(source:match("(local function IsModuleEnabled.-)%s*local function NormalizeBoolean")),
		assert(source:match("(local function IsPartyContextActive.-)%s*local function ShouldQuarantineCompactFrame")),
		assert(source:match("(local function ApplyAzeriteRaidGroupFilter.-)%s*PrepareCompactFrame = function")),
		assert(source:match("(local function QuarantineCompactFrames.-)%s*local function QuarantineSpellBars"))
	}
	local chunk = assert(loadstring(table.concat(parts, "\n") .. "\n" .. [[
return function()
	SetBlizzardRaidBarVisible(false)
	ApplyAzeriteRaidGroupFilter()
	ApplyAzeriteRaidGroupVisibility()
	HookRaidManagerHiddenMode()
	QuarantineCompactFrames()
end
]]))
	setfenv(chunk, env)
	local exercise = chunk()
	local ok, err = pcall(exercise)
	check(ok, "native ownership quarantine callbacks execute: " .. tostring(err or ""))
	if native and party then
		-- Our party frames replace Blizzard's party frames; raid roots stay native.
		check(world.quarantined.PartyFrame and world.quarantined.CompactPartyFrame, "party targeting session suppresses only replaced party frames")
		check(not world.quarantined.CompactRaidFrameContainer and not nativeManager.changed, "raid container and raid manager untouched in a party")
		world.quarantined = {}
		world.inRaid, world.combat = true, true
		check(pcall(exercise) and not world.quarantined.CompactRaidFrameContainer and not nativeManager.changed,
			"raid navigation root and manager untouched in a raid")
		local raidFrames = false
		for name in pairs(world.quarantined) do if name:match("^CompactRaidFrame%d") then raidFrames = true end end
		check(not raidFrames, "native raid member frames never quarantined")
		world.combat = false
	elseif native then
		check(world.mutations == 0 and world.hooks == 0, "native party roots/raid manager receive no writes or hooks")
		world.inRaid, world.combat = true, true
		check(pcall(exercise) and world.mutations == 0, "native raid/combat ownership remains untouched")
		world.combat = false
		check(pcall(exercise) and world.mutations == 0, "native combat replay remains untouched")
	else
		check(world.mutations > 0, "non-native negative control still suppresses replaced group frames")
	end
	if native and arg[2] == "taint" then
		check(issecure(), "group ownership probe starts secure")
		securecall(function() debug.setstacktaint("AzeriteUI5_JuNNeZ_Edition"); exercise() end)
		check(issecure(), "caller restored after native group checks")
		check(issecurevariable(nativeManager, "shown") and issecurevariable(nativeManager, "parent"), "native manager state remains secure")
		check(issecurevariable(env._G.CompactPartyFrame, "events") and issecurevariable(env._G.CompactRaidFrameContainer, "shown"), "native group state remains secure")
		securecall(function() debug.setstacktaint("AzeriteUI5_JuNNeZ_Edition"); nativeManager.shown = tonumber("0") end)
		check(not issecurevariable(nativeManager, "shown"), "negative control detects native group-state contamination")
	end
end

lifecycle(true)
lifecycle(true, true)
lifecycle(false)
quarantine(true)
quarantine(true, true)
quarantine(false)

-- oUF's explicit legacy-party disable must also leave native roots untouched.
do
	local writes = 0
	local native = true
	local ns = { oUF = {}, NativeController = { IsActive = function() return native end } }
	local function frame()
		return { SetAllPoints = noop, Hide = function() writes = writes + 1 end, SetScript = noop, RegisterEvent = noop,
			SetParent = function() writes = writes + 1 end, UnregisterAllEvents = function() writes = writes + 1 end }
	end
	local env = setmetatable({ UIParent = {}, CreateFrame = frame, InCombatLockdown = function() return false end }, { __index = _G })
	env._G = env
	env.PartyFrame = frame()
	env.PartyFrame.PartyMemberFramePool = { EnumerateActive = function() return function() end end }
	table.wipe = table.wipe or function(t) for key in pairs(t) do t[key] = nil end end
	load("Libs/oUF/blizzard.lua", env, ns)
	writes = 0
	local ok = pcall(ns.oUF.DisableBlizzard, ns.oUF, "party")
	check(ok and writes == 0, "oUF legacy-party suppression skips native group owners")
end

-- With direct party targeting the party frames are ours, so oUF suppresses
-- Blizzard's party frames as it does outside native mode.
do
	local writes = 0
	local world = { native = true, party = true }
	local ns = { oUF = {}, NativeController = Controller(world) }
	local function frame()
		return { SetAllPoints = noop, Hide = function() writes = writes + 1 end, SetScript = noop, RegisterEvent = noop,
			SetParent = function() writes = writes + 1 end, UnregisterAllEvents = function() writes = writes + 1 end }
	end
	local env = setmetatable({ UIParent = {}, CreateFrame = frame, InCombatLockdown = function() return false end }, { __index = _G })
	env._G = env
	env.PartyFrame = frame()
	env.PartyFrame.PartyMemberFramePool = { EnumerateActive = function() return function() end end }
	load("Libs/oUF/blizzard.lua", env, ns)
	writes = 0
	local ok = pcall(ns.oUF.DisableBlizzard, ns.oUF, "party")
	check(ok and writes > 0, "party targeting session lets oUF replace Blizzard's party frames")
end

print(string.format("native_group_ownership: %d checks, %d failures", checks, failures))
if failures > 0 then os.exit(1) end
