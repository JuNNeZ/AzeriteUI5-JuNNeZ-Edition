-- Explorer Mode options: a switch is greyed out exactly when it cannot change anything.
--
-- Loads the real page (Options/OptionsPages/ExplorerMode.lua) and the real
-- CheckForForcedState (Core/ExplorerMode.lua). For every profile, a switch must be
-- disabled if and only if flipping it never changes whether the interface is kept
-- visible in the situations it is about. So the page and the module cannot drift.
--
--   During a Mythic+ key: a key is always inside an instance, but a key can be run
--   solo, so only "While in an instance" makes it moot, not "While in a group".
--   While having a dead target: moot while neither friendly nor hostile targets
--   keep the interface visible.
--
-- Usage: lua explorer_options_harness.lua <addon root> [page override] [module override]

local root = arg[1] or "."
local function read(path)
	local f = assert(io.open(path, "rb"))
	local text = f:read("*a")
	f:close()
	return text
end
local pageSource = read(arg[2] or (root .. "/Options/OptionsPages/ExplorerMode.lua"))
local coreSource = read(arg[3] or (root .. "/Core/ExplorerMode.lua"))

local failures, checks = 0, 0
local function check(ok, label)
	checks = checks + 1
	if (not ok) then
		failures = failures + 1
		print("FAIL: " .. label)
	end
end

-- The module: only CheckForForcedState is used, called on a plain state table.
local function LoadModule()
	local module = {}
	local ns = {
		NewModule = function() return module end,
		Merge = function(_, target) return target end,
		MovableModulePrototype = { defaults = {} }
	}
	local env = setmetatable({
		LibStub = function() return {} end,
		Enum = { PowerType = { Mana = 0 } },
		C_ActionBar = {},
		UnitClass = function() return "Warrior", "WARRIOR" end,
		UnitLevel = function() return 80 end
	}, { __index = _G })
	local chunk = assert(loadstring(coreSource, "@Core/ExplorerMode.lua"))
	setfenv(chunk, env)
	chunk("AzeriteUI5_JuNNeZ_Edition", ns)
	assert(type(module.CheckForForcedState) == "function", "CheckForForcedState not found")
	return module
end

-- The page: Options:AddGroup hands over the generator; the module is a stub profile.
local function LoadPage(profile, retailContent)
	local generator
	local explorer = { db = { profile = profile }, IsEnabled = function() return true end, UpdateSettings = function() end }
	local options = { AddGroup = function(_, _, func) generator = func end }
	local ns = {
		IsRetailContent = retailContent,
		GetModule = function(_, name)
			if (name == "Options") then return options end
			if (name == "ExplorerMode") then return explorer end
		end
	}
	local L = setmetatable({}, { __index = function(_, key) return key end })
	local env = setmetatable({
		LibStub = function() return { GetLocale = function() return L end } end,
		UnitClass = function() return "Warrior", "WARRIOR" end
	}, { __index = _G })
	local chunk = assert(loadstring(pageSource, "@Options/OptionsPages/ExplorerMode.lua"))
	setfenv(chunk, env)
	chunk("AzeriteUI5_JuNNeZ_Edition", ns)
	assert(type(generator) == "function", "the page did not register its options")
	return generator()
end

local function Resolve(option, key, field)
	local value = option[field]
	if (type(value) == "function") then
		return value({ key })
	end
	return value
end

local Module = LoadModule()

local function Forced(profile, state)
	local self = { db = { profile = profile } }
	for k, v in pairs(state) do self[k] = v end
	return Module.CheckForForcedState(self) and true or false
end

-- Whether flipping one stored value ever changes the outcome in the given situations.
local function CanAct(profile, key, states)
	for _, state in ipairs(states) do
		local a, b = {}, {}
		for k, v in pairs(profile) do a[k] = v; b[k] = v end
		a[key], b[key] = true, false
		if (Forced(a, state) ~= Forced(b, state)) then return true end
	end
	return false
end

local function Profile(values)
	-- Every exit condition off (true = let it fade) unless the case sets it.
	local profile = {
		enabled = true,
		fadeInCombat = true, fadeInGroups = true, fadeInInstances = true, fadeInMythicPlus = true,
		fadeWithFriendlyTarget = true, fadeWithHostileTarget = true, fadeWithDeadTarget = true,
		fadeWithFocusTarget = true, fadeInVehicles = true, fadeWithLowMana = true, fadeWithLowHealth = true
	}
	for k, v in pairs(values) do profile[k] = v end
	return profile
end

local function Label(values)
	local parts = {}
	for k, v in pairs(values) do parts[#parts + 1] = k .. "=" .. tostring(v) end
	table.sort(parts)
	return table.concat(parts, ",")
end

-- During a Mythic+ key: grouped or solo, always in an instance.
local keyStates = {
	{ inInstance = true, inMythicPlus = true, inGroup = true },
	{ inInstance = true, inMythicPlus = true, inGroup = nil }
}
for _, instances in ipairs({ true, false }) do
	for _, groups in ipairs({ true, false }) do
		for _, mythic in ipairs({ true, false }) do
			local values = { fadeInInstances = instances, fadeInGroups = groups, fadeInMythicPlus = mythic }
			local profile = Profile(values)
			local page = LoadPage(profile, true)
			local option = page.args.fadeInMythicPlus
			local disabled = Resolve(option, "fadeInMythicPlus", "disabled") and true or false
			local canAct = CanAct(profile, "fadeInMythicPlus", keyStates)
			check(disabled == not canAct, "Mythic+ switch greyed out exactly when it cannot act ("
				.. Label(values) .. ": disabled=" .. tostring(disabled) .. ", canAct=" .. tostring(canAct) .. ")")
			check(not Resolve(option, "fadeInMythicPlus", "hidden"), "Mythic+ switch shown on Retail (" .. Label(values) .. ")")
		end
	end
end

-- The two cases the maintainer named, spelled out.
do
	local ticked = LoadPage(Profile({ fadeInInstances = false }), true).args.fadeInMythicPlus
	check(Resolve(ticked, "fadeInMythicPlus", "disabled"), "\"While in an instance\" ticked greys out the Mythic+ switch")
	local groupOnly = LoadPage(Profile({ fadeInGroups = false }), true).args.fadeInMythicPlus
	check(not Resolve(groupOnly, "fadeInMythicPlus", "disabled"),
		"\"While in a group\" alone leaves the Mythic+ switch usable (a solo key is not grouped)")
	local neither = LoadPage(Profile({}), true).args.fadeInMythicPlus
	check(not Resolve(neither, "fadeInMythicPlus", "disabled"), "neither ticked leaves the Mythic+ switch usable")
end

-- Explorer Mode off greys out the switch whatever the instance setting.
do
	local page = LoadPage(Profile({ enabled = false, fadeInInstances = true }), true)
	check(Resolve(page.args.fadeInMythicPlus, "fadeInMythicPlus", "disabled"), "Explorer Mode off greys out the Mythic+ switch")
end

-- Forever has no keys: the switch stays hidden.
do
	for _, instances in ipairs({ true, false }) do
		local page = LoadPage(Profile({ fadeInInstances = instances }), false)
		check(Resolve(page.args.fadeInMythicPlus, "fadeInMythicPlus", "hidden"),
			"Mythic+ switch hidden without Retail content (fadeInInstances=" .. tostring(instances) .. ")")
	end
end

-- The dead target precedent, held to the same rule.
local deadStates = {
	{ hasTarget = true, hasDeadTarget = true, hasAttackableTarget = true },
	{ hasTarget = true, hasDeadTarget = true, hasAttackableTarget = false }
}
for _, friendly in ipairs({ true, false }) do
	for _, hostile in ipairs({ true, false }) do
		local values = { fadeWithFriendlyTarget = friendly, fadeWithHostileTarget = hostile }
		local profile = Profile(values)
		local option = LoadPage(profile, true).args.fadeWithDeadTarget
		local disabled = Resolve(option, "fadeWithDeadTarget", "disabled") and true or false
		local canAct = CanAct(profile, "fadeWithDeadTarget", deadStates)
		check(disabled == not canAct, "dead target switch greyed out exactly when it cannot act ("
			.. Label(values) .. ": disabled=" .. tostring(disabled) .. ", canAct=" .. tostring(canAct) .. ")")
	end
end

print(string.format("%d checks, %d failures", checks, failures))
os.exit(failures == 0 and 0 or 1)
