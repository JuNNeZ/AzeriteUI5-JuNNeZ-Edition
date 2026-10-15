-- The shared large-raid body (Components/UnitFrames/Units/RaidLarge.lua), offline.
--
-- Loads RaidLarge.lua under permissive stubs and checks that it builds RaidFrame25 and
-- RaidFrame40 with their own defaults, secure header attributes, header sizes and button
-- placement (both grouped layouts and the generic one). Given the old Raid25.lua and
-- Raid40.lua (git show 9292b5f:Components/UnitFrames/Units/Raid25.lua, and Raid40.lua),
-- it also loads those and compares every one of those answers, so the merge is shown
-- to change nothing except the one intended fix: Raid40
-- now takes Raid25's maxColumns fallback. It cannot show secure headers in combat.
--
-- lua Tools/Harness/raid_merge_harness.lua . [old Raid25.lua] [old Raid40.lua]

local root = arg and arg[1] or "."
local old25, old40 = arg and arg[2], arg and arg[3]

local checks, failures = 0, 0
local function check(value, label, detail)
	checks = checks + 1
	if (not value) then
		failures = failures + 1
		print("FAIL: " .. label .. (detail ~= nil and ("  (" .. tostring(detail) .. ")") or ""))
	end
end

local function DeepEqual(a, b)
	if (type(a) ~= type(b)) then return false end
	if (type(a) ~= "table") then return a == b end
	for k, v in pairs(a) do if (not DeepEqual(v, b[k])) then return false end end
	for k in pairs(b) do if (a[k] == nil) then return false end end
	return true
end

local function Copy(t)
	if (type(t) ~= "table") then return t end
	local out = {}
	for k, v in pairs(t) do out[k] = Copy(v) end
	return out
end

-- A table that answers any field with a callable stub.
local Auto
local AutoMT = {
	__index = function(t, k) local v = Auto(); rawset(t, k, v); return v end,
	__call = function() return Auto() end
}
Auto = function() return setmetatable({}, AutoMT) end

_G.InCombatLockdown = function() return false end
_G.UnitInRaid = nil
_G.GetRaidRosterInfo = nil
_G.RAID = "Raid"
_G.CreateFrame = function() return Auto() end
_G.UIParent = Auto()
_G.hooksecurefunc = function() end

local function NewNamespace()
	local modules = {}
	local ns = setmetatable({
		Prefix = "AzeriteUI",
		oUF = Auto(),
		Colors = Auto(),
		UnitFrameModule = {},
		MovableModulePrototype = { defaults = { enabled = true } },
		API = setmetatable({
			GetEffectiveScale = function() return 1 end,
			GetMedia = function() return "" end,
			GetFont = function() return {} end
		}, AutoMT),
		GetConfig = function(name) if (name == "RaidFrames") then return { UnitSize = { 80, 40 } } end return Auto() end
	}, AutoMT)
	ns.Merge = function(self, target, source)
		for k, v in pairs(source) do if (target[k] == nil) then target[k] = Copy(v) end end
		return target
	end
	ns.NewModule = function(self, name)
		local module = setmetatable({ GetName = function() return name end }, AutoMT)
		modules[name] = module
		return module
	end
	return ns, modules
end

local function Load(path, ns)
	local chunk, err = loadfile(path)
	if (not chunk) then error("could not load " .. path .. ": " .. tostring(err)) end
	chunk("AzeriteUI5_JuNNeZ_Edition", ns)
end

-- Header children, raid1..raidN, recording where each button is put.
local function Buttons(count)
	local header = { name = "header", points = {} }
	local buttons = {}
	for i = 1, count do
		local button = { name = "raid" .. i, points = {} }
		button.GetAttribute = function(self, key) if (key == "unit") then return self.name end end
		button.GetName = function() return string.format("UnitButton%02d", i) end
		button.SetSize = function() end
		button.ClearAllPoints = function(self) self.points = {} end
		button.SetPoint = function(self, point, relative, relativePoint, x, y)
			self.points[#self.points + 1] = table.concat({ tostring(point), relative and relative.name or "nil",
				tostring(relativePoint), string.format("%.2f", x or 0), string.format("%.2f", y or 0) }, " ")
		end
		buttons[i] = button
	end
	header.GetAttribute = function(self, key)
		local index = tonumber(key:match("^child(%d+)$"))
		return index and buttons[index] or nil
	end
	header.GetNumChildren = function() return 0 end
	header.GetChildren = function() end
	header.SetSize = function(self, w, h) self.size = string.format("%.2f x %.2f", w, h) end
	return header, buttons
end

-- Everything one module answers for one profile.
local function Answers(module, profile, count)
	module.db = { profile = profile }
	local out = {}
	out.attributes = { module:GetHeaderAttributes() }
	out.headerSize = { module:GetHeaderSize() }
	out.sizes = {}
	for n = 0, 40 do out.sizes[n] = { module:GetCalculatedHeaderSize(n) } end
	local header, buttons = Buttons(count or 23)
	module.GetUnitFrameOrHeader = function() return header end
	module:ConfigureChildren()
	out.placed = {}
	for i, button in ipairs(buttons) do out.placed[i] = table.concat(button.points, " | ") end
	out.placedHeader = header.size
	return out
end

local function Variants(defaults)
	local base = Copy(defaults.profile)
	local generic = Copy(base)
	generic.point = "BOTTOM"
	local desc = Copy(base)
	desc.sortDir = "DESC"
	local noMax = Copy(base)
	noMax.maxColumns = nil
	return { default = base, generic = generic, desc = desc, noMax = noMax }
end

--------------------------------------------------------------------------
-- The shared file on its own.
--------------------------------------------------------------------------
local ns, modules = NewNamespace()
Load(root .. "/Components/UnitFrames/Units/RaidLarge.lua", ns)
local r25, r40 = modules.RaidFrame25, modules.RaidFrame40
check(r25 and r40, "RaidLarge.lua builds RaidFrame25 and RaidFrame40")

check(r25.layoutSpec.privateAuraSize == 16 and r40.layoutSpec.privateAuraSize == 14, "private aura size: 16 for 25, 14 for 40")
check(r25.layoutSpec.label == " (25)" and r40.layoutSpec.label == " (40)", "mover labels unchanged")
check(r25.layoutSpec.groupsAsColumns == true and r40.layoutSpec.groupsAsColumns == false, "25 lays groups as columns, 40 as rows")

local d25, d40 = r25:GenerateDefaults(), r40:GenerateDefaults()
check(d25 ~= d40 and d25.profile ~= d40.profile, "each module has its own defaults table")
check(d25.profile.useInRaid25 == true and d25.profile.useInRaid40 == false and d25.profile.point == "TOP"
	and d25.profile.maxColumns == 5 and d25.profile.columnAnchorPoint == "LEFT", "Raid25's own defaults")
check(d40.profile.useInRaid40 == true and d40.profile.useInRaid25 == false and d40.profile.point == "LEFT"
	and d40.profile.maxColumns == 8 and d40.profile.columnAnchorPoint == "TOP", "Raid40's own defaults")

local a25 = Answers(r25, Copy(d25.profile))
local a40 = Answers(r40, Copy(d40.profile))
check(a25.attributes[1] == "AzeriteUIRaid25" and a40.attributes[1] == "AzeriteUIRaid40", "secure header names unchanged")
-- Raid25 lays groups as columns, Raid40 as rows: raid6 (group 2, slot 1).
check(a25.placed[6]:match("^TOPLEFT header TOPLEFT 90%.00 %-0%.00$") ~= nil, "Raid25: group 2 is the next column", a25.placed[6])
check(a40.placed[6]:match("^TOPLEFT header TOPLEFT 0%.00 %-28%.00$") ~= nil, "Raid40: group 2 is the next row", a40.placed[6])

-- Raid40 with no maxColumns now falls back to its default (8), as Raid25 always did.
local noMax = Copy(d40.profile)
noMax.maxColumns = nil
noMax.point = "BOTTOM"
r40.db = { profile = noMax }
local w = r40:GetCalculatedHeaderSize(40)
noMax.maxColumns = 8
local w8 = r40:GetCalculatedHeaderSize(40)
check(w == w8, "Raid40 without maxColumns uses its default 8, not 1", tostring(w) .. " vs " .. tostring(w8))

--------------------------------------------------------------------------
-- Against the old files, when given.
--------------------------------------------------------------------------
local function Compare(oldPath, newModule, name)
	local oldNs, oldModules = NewNamespace()
	Load(oldPath, oldNs)
	local old = oldModules[name]
	check(old, "the old " .. name .. " loads")
	if (not old) then return end
	local oldDefaults, newDefaults = old:GenerateDefaults(), newModule:GenerateDefaults()
	check(DeepEqual(oldDefaults, newDefaults), name .. ": defaults identical")
	for variant, profile in pairs(Variants(oldDefaults)) do
		local before = Answers(old, Copy(profile))
		local after = Answers(newModule, Copy(profile))
		local intended = (variant == "noMax" and name == "RaidFrame40")
		local differs
		for i = 1, math.max(#before.attributes, #after.attributes) do
			if (not DeepEqual(before.attributes[i], after.attributes[i])) then
				differs = string.format("#%d %s vs %s", i, tostring(before.attributes[i]), tostring(after.attributes[i]))
				break
			end
		end
		check(not differs, name .. " " .. variant .. ": header attributes identical", differs)
		check(intended or DeepEqual(before.sizes, after.sizes), name .. " " .. variant .. ": header sizes identical")
		check(intended or DeepEqual(before.headerSize, after.headerSize), name .. " " .. variant .. ": header size identical")
		local same = DeepEqual(before.placed, after.placed) and before.placedHeader == after.placedHeader
		if (intended) then
			check(true, "")
		else
			check(same, name .. " " .. variant .. ": every button placed identically",
				(before.placed[6] or "") .. " vs " .. (after.placed[6] or ""))
		end
	end
end

if (old25 and old40) then
	Compare(old25, r25, "RaidFrame25")
	Compare(old40, r40, "RaidFrame40")
else
	print("(no old files given: the comparison with Raid25.lua/Raid40.lua was skipped)")
end

print(string.format("raid merge: %d checks, %d failures", checks, failures))
os.exit(failures == 0 and 0 or 1)
