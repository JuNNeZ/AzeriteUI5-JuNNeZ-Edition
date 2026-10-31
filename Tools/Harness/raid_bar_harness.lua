-- Show Blizzard Raid Bar off: a show from Blizzard's own code must not stick.
--
-- Runs the real functions out of Core/FixBlizzardBugs.lua. The manager stub fires
-- its OnShow hooks when shown, as CompactRaidFrameManager_UpdateShown's SetShown does.
--
-- Usage: lua raid_bar_harness.lua <addon root> [source override]

local root = arg[1]
local f = assert(io.open(arg[2] or (root .. "/Core/FixBlizzardBugs.lua")))
local core = f:read("*a")
f:close()

local failures, checks = 0, 0
local function check(ok, label)
	checks = checks + 1
	if (not ok) then
		failures = failures + 1
		print("FAIL: " .. label)
	end
end

local manager = { shown = false, hooks = {} }
function manager.SetParent() end
function manager.SetAlpha() end
function manager.Hide(self) self.shown = false end
function manager.Show(self)
	if (self.shown) then return end
	self.shown = true
	for _, hook in ipairs(self.hooks) do hook(self) end
end
function manager.HookScript(self, _, hook) table.insert(self.hooks, hook) end

local enabled, inCombat, inGroup = false, false, true
local env = setmetatable({
	_G = { CompactRaidFrameManager = manager },
	UIParent = {},
	InCombatLockdown = function() return inCombat end,
	IsInGroup = function() return inGroup end,
	IsInRaid = function() return false end,
	API = { SafeCall = function(_, func, ...) return func(...) end },
	ns = { GetModuleProfileValue = function() return enabled end },
	quarantineHooked = {},
	ScheduleAzeriteRaidPanelMirror = function() end,
	GetCompactRaidFilterGroupButtons = function() return nil end
}, { __index = _G })

local head = assert(core:match("(local pendingRaidBarVisible = nil.-)%s*%-%- Export for options UI"))
local hook = assert(core:match("(local function HookRaidManagerHiddenMode%(%).-)%s*PrepareCompactFrame = function"))
local chunk = assert(loadstring(head .. "\n" .. hook
	.. "\nreturn HookRaidManagerHiddenMode, SetBlizzardRaidBarVisible, function() return pendingRaidBarVisible end"))
setfenv(chunk, env)
local Hook, SetVisible, Pending = chunk()
Hook()

manager:Show()
check(not manager.shown, "option off: a show from Blizzard is undone")

enabled = true
manager:Show()
check(manager.shown, "option on: Blizzard's show stands")
manager:Hide()

inGroup = false
manager:Show()
check(manager.shown, "option on, solo: Edit Mode's preview show stands")
manager:Hide()
inGroup = true

enabled, inCombat = false, true
manager:Show()
check(manager.shown and Pending() == false, "option off in combat: no hide, queued instead")
inCombat = false
SetVisible(Pending())
check(not manager.shown and Pending() == nil, "the queued hide runs after combat")

print(string.format("Raid bar: %d checks, %d failures", checks, failures))
if (failures > 0) then os.exit(1) end
