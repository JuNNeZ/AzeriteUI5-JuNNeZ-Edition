-- Mythic+ and the Great Vault, offline.
--
-- Loads the real Components/Misc/MythicPlus.lua and Components/Misc/Info.lua against a
-- small fake client and drives them through a key: the timer and its +3/+2/+1 stages,
-- deaths, enemy forces, the end-of-run card, keystone slotting, and the vault counter.
-- The fake client answers the way Blizzard_ScenarioObjectiveTracker.lua and
-- Blizzard_ChallengesUI.lua read the same calls; it cannot say whether the real client
-- still answers that way, or how any of it looks.
--
-- lua Tools/Harness/mythicplus_harness.lua .
-- Mutations: the "mythicplus" entries in mutate_client.lua.
local root = arg[1] or "."
local checks, failures = 0, 0
local function check(value, label, detail)
	checks = checks + 1
	if (not value) then
		failures = failures + 1
		print("FAIL: " .. label .. (detail and (" - " .. tostring(detail)) or ""))
	end
end

-------------------------------------------------------------------------------
-- Widgets: remember what they were told, answer the rest with themselves.
-------------------------------------------------------------------------------
local widgetMT
local function Widget(kind)
	local w = setmetatable({ kind = kind, shown = true, scripts = {}, points = {} }, widgetMT)
	return w
end
local methods = {
	Show = function(self) self.shown = true end,
	Hide = function(self) self.shown = false end,
	SetShown = function(self, shown) self.shown = shown and true or false end,
	IsShown = function(self) return self.shown end,
	SetText = function(self, text) self.text = text end,
	SetFormattedText = function(self, fmt, ...) self.text = string.format(fmt, ...) end,
	GetText = function(self) return self.text or "" end,
	SetTextColor = function(self, r, g, b) self.color = { r, g, b } end,
	SetValue = function(self, value) self.value = value end,
	GetValue = function(self) return self.value end,
	SetStatusBarColor = function(self, r, g, b) self.barColor = { r, g, b } end,
	SetScript = function(self, name, fn) self.scripts[name] = fn end,
	SetPoint = function(self, ...) self.points[#self.points + 1] = { ... } end,
	ClearAllPoints = function(self) self.points = {} end,
	GetSize = function() return 260, 110 end,
	CreateFontString = function() return Widget("FontString") end,
	CreateTexture = function() return Widget("Texture") end
}
widgetMT = {
	__index = function(t, k)
		if (methods[k]) then return methods[k] end
		return function() return t end
	end
}

-------------------------------------------------------------------------------
-- The fake client
-------------------------------------------------------------------------------
local client
local function Reset()
	client = {
		timers = {},            -- timerID -> { elapsed, type }
		mapID = nil,
		maps = { [501] = { "The Stonevault", 501, 1800 } },
		level = 12,
		deaths = { 0, 0 },
		criteria = {},
		completion = nil,
		bags = {},              -- [bag][slot] = itemID
		keystones = { [180653] = true },
		cursor = nil,
		slotted = false,
		fontAccepts = true,
		combat = false,
		picked = nil,
		slotCalls = 0,
		cleared = 0,
		activities = {},
		vaultReady = false,
		secret = {}
	}
end
Reset()

local CHALLENGE_TIMER = 1

local env = setmetatable({}, { __index = _G })
env._G = env
env.issecretvalue = function(value) return client.secret[value] == true end
env.CreateFrame = function(kind) return Widget(kind) end
env.UIParent = Widget("Frame")
env.GameTooltip = Widget("GameTooltip")
env.GameTooltip.IsForbidden = function() return false end
env.GameTooltip.lines = {}
env.GameTooltip.AddLine = function(self, text) self.lines[#self.lines + 1] = text end
env.GameTooltip.AddDoubleLine = function(self, left, right) self.lines[#self.lines + 1] = left .. "|" .. right end
env.GameTooltip_SetDefaultAnchor = function(tooltip) tooltip.lines = {} end
env.InCombatLockdown = function() return client.combat end
env.CursorHasItem = function() return client.cursor ~= nil end
env.ClearCursor = function() client.cursor = nil; client.cleared = client.cleared + 1 end
env.NUM_BAG_SLOTS = 4
env.SecondsToClock = function(seconds)
	return string.format("%d:%02d", math.floor(seconds / 60), seconds % 60)
end
env.GetCurrentRegionName = function() return "EU" end
env.Enum = {
	WorldElapsedTimerTypes = { ChallengeMode = 1, ProvingGround = 2 },
	WeeklyRewardChestThresholdType = { Raid = 3, Activities = 1, RankedPvP = 2, World = 6 }
}
env.GetWorldElapsedTimers = function()
	local ids = {}
	for id in pairs(client.timers) do ids[#ids + 1] = id end
	return unpack(ids)
end
env.GetWorldElapsedTime = function(id)
	local t = client.timers[id]
	if (not t) then return 0, 0, 0 end
	return 0, t.elapsed, t.type
end
env.C_ChallengeMode = {
	GetActiveChallengeMapID = function() return client.mapID end,
	GetMapUIInfo = function(id) local m = client.maps[id]; if m then return m[1], m[2], m[3] end end,
	GetActiveKeystoneInfo = function() return client.level, {}, true end,
	GetDeathCount = function() return client.deaths[1], client.deaths[2] end,
	GetChallengeCompletionInfo = function() return client.completion end,
	GetDungeonScoreRarityColor = function() return { WrapTextInColorCode = function(_, s) return "<" .. s .. ">" end } end,
	HasSlottedKeystone = function() return client.slotted end,
	SlotKeystone = function()
		client.slotCalls = client.slotCalls + 1
		if (client.fontAccepts and client.cursor and client.keystones[client.cursor]) then
			client.cursor = nil
			client.slotted = true
		end
	end
}
env.C_Scenario = {
	GetStepInfo = function() return "Stage", "", #client.criteria end
}
env.C_ScenarioInfo = {
	GetCriteriaInfo = function(index) return client.criteria[index] end
}
env.C_Container = {
	GetContainerNumSlots = function(bag) return client.bags[bag] and 20 or 0 end,
	GetContainerItemID = function(bag, slot) return client.bags[bag] and client.bags[bag][slot] end,
	PickupContainerItem = function(bag, slot)
		client.picked = { bag, slot }
		client.cursor = client.bags[bag][slot]
	end
}
env.C_Item = {
	IsItemKeystoneByID = function(id) return client.keystones[id] == true end
}
env.C_WeeklyRewards = {
	GetActivities = function(kind) return client.activities[kind] or {} end,
	HasAvailableRewards = function() return client.vaultReady end
}
env.CHALLENGE_MODE_DEATH_COUNT_TITLE = "%d Deaths"
env.CHALLENGE_MODE_COMPLETE_BEAT_TIMER = "You beat the timer!"
env.CHALLENGE_MODE_COMPLETE_KEYSTONE_UPGRADED = "Keystone upgraded %d levels"
env.CHALLENGE_MODE_COMPLETE_TIME_EXPIRED = "Time expired"
env.CHALLENGE_COMPLETE_DUNGEON_SCORE = "Rating: %s"
env.CHALLENGE_COMPLETE_DUNGEON_SCORE_FORMAT_TEXT = "%d (+%d)"
env.RAIDS, env.DUNGEONS, env.WORLD, env.PVP = "Raids", "Dungeons", "World", "PvP"
for _, name in ipairs({ "TUTORIAL_TITLE30", "FPS_ABBR", "HOME", "WORLD", "INFO", "TIMEMANAGER_TITLE" }) do
	env[name] = env[name] or name
end

-- LibStub: the locale answers its own key.
env.LibStub = function()
	return { GetLocale = function() return setmetatable({}, { __index = function(_, k) return k end }) end }
end

-------------------------------------------------------------------------------
-- The addon namespace
-------------------------------------------------------------------------------
local function Color(r, g, b)
	return { r, g, b, colorCode = string.format("|cff%02x%02x%02x", r * 255, g * 255, b * 255) }
end

local modules
local function NewNamespace(retail)
	modules = {}
	local ns = {
		IsRetailContent = retail,
		Prefix = "Azerite",
		BackdropTemplate = "BackdropTemplate",
		Colors = {
			title = Color(1, .9, .5), offwhite = Color(.77, .77, .77), normal = Color(.9, .7, .15),
			highlight = Color(.98, .98, .98), ui = Color(.75, .75, .75),
			quest = { green = Color(.35, .79, .35), yellow = Color(1, .7, .15), orange = Color(1, .42, .1), red = Color(.8, .1, .1) },
			zone = {}
		},
		API = {
			GetFont = function() return "font" end,
			GetMedia = function(name) return name end,
			GetEffectiveScale = function() return 1 end,
			IsEventAvailable = function() return true end,
			GetLocalTime = function() return 12, 0, "PM" end,
			GetServerTime = function() return 12, 0, "PM" end
		},
		MovableModulePrototype = { defaults = {}, OnEnable = function() end },
		Merge = function(_, a) return a end,
		GetConfig = function()
			return setmetatable({}, { __index = function() return { "CENTER", 0, 0 } end })
		end
	}
	ns.NewModule = function(_, name)
		local module = {
			events = {},
			timers = {},
			RegisterEvent = function(self, event, handler) self.events[event] = handler end,
			ScheduleRepeatingTimer = function(self, method) self.timers[#self.timers + 1] = method; return #self.timers end,
			ScheduleTimer = function(self, fn) self.pending = fn; return "card" end,
			CancelTimer = function() end,
			CreateAnchor = function() end,
			GetName = function() return name end
		}
		modules[name] = module
		return module
	end
	ns.GetModule = function(_, name) return modules[name] end
	return ns
end

local function Load(relative, ns)
	local chunk = assert(loadfile(root .. "/" .. relative))
	setfenv(chunk, env)
	return chunk("AzeriteUI5_JuNNeZ_Edition", ns)
end

-------------------------------------------------------------------------------
-- Forever: nothing is created.
-------------------------------------------------------------------------------
do
	local ns = NewNamespace(false)
	Load("Components/Misc/MythicPlus.lua", ns)
	check(modules.MythicPlus == nil, "Forever creates no Mythic+ module")
end

-------------------------------------------------------------------------------
-- The key timer
-------------------------------------------------------------------------------
local ns = NewNamespace(true)
Load("Components/Misc/MythicPlus.lua", ns)
local M = assert(modules.MythicPlus, "the module exists on Retail")
local function Profile()
	return { enabled = true, showTimer = true, showForces = true, showCompletionCard = true, autoSlotKeystone = true, savedPosition = {} }
end
M.db = { profile = Profile() }
M:OnEnable()
local frame = M.frame

check(not frame.shown, "no key: the timer stays hidden")
for _, event in ipairs({ "CHALLENGE_MODE_START", "WORLD_STATE_TIMER_START", "WORLD_STATE_TIMER_STOP",
	"CHALLENGE_MODE_COMPLETED", "CHALLENGE_MODE_KEYSTONE_RECEPTABLE_OPEN", "SCENARIO_CRITERIA_UPDATE",
	"CHALLENGE_MODE_DEATH_COUNT_UPDATED", "PLAYER_ENTERING_WORLD" }) do
	check(M.events[event] == "OnEvent", "listens for " .. event)
end

local function Start(elapsed)
	client.timers[CHALLENGE_TIMER] = { elapsed = elapsed, type = 1 }
	client.mapID = 501
	M:OnEvent("CHALLENGE_MODE_START")
end
local function At(elapsed)
	client.timers[CHALLENGE_TIMER].elapsed = elapsed
	M:UpdateTime()
end
local function Same(a, b) return a and b and a[1] == b[1] and a[2] == b[2] and a[3] == b[3] end

Start(600)
check(frame.shown, "a running key shows the timer")
check(frame.title.text == "+12  The Stonevault", "title is level and dungeon", frame.title.text)
check(#M.timers == 1, "one repeating update while the key runs")
check(frame.timer.label.text == "10:00 / 30:00", "elapsed over the limit", frame.timer.label.text)
check(math.abs(frame.timer.value - 600 / 1800) < 1e-9, "the bar fills with the time used", frame.timer.value)
check(frame.nextLevel.text == "+3  8:00", "time left for +3 (60% of 30:00 is 18:00)", frame.nextLevel.text)
check(Same(frame.timer.barColor, ns.Colors.quest.green), "green while +3 is possible")

At(1200)
check(frame.nextLevel.text == "+2  4:00", "time left for +2 (80% of 30:00 is 24:00)", frame.nextLevel.text)
check(Same(frame.timer.barColor, ns.Colors.quest.yellow), "yellow once only +2 remains")

At(1080)
check(frame.nextLevel.text == "+2  6:00", "exactly on the +3 mark counts as past it", frame.nextLevel.text)

At(1500)
check(frame.nextLevel.text == "+1  5:00", "time left in time", frame.nextLevel.text)
check(Same(frame.timer.barColor, ns.Colors.quest.orange), "orange for +1")

At(1900)
check(frame.nextLevel.text == "-1:40", "over time counts up", frame.nextLevel.text)
check(frame.timer.value == 1, "an over-time bar stays full")
check(Same(frame.timer.barColor, ns.Colors.quest.red), "red over time")

-- A secret time blanks the countdown instead of doing arithmetic on it.
local secretElapsed = 1234.5
client.secret[secretElapsed] = true
At(secretElapsed)
check(frame.timer.value == 0 and frame.nextLevel.text == "", "a secret time is not used")
client.secret = {}
At(600)

-------------------------------------------------------------------------------
-- Deaths
-------------------------------------------------------------------------------
client.deaths = { 3, 15 }
M:OnEvent("CHALLENGE_MODE_DEATH_COUNT_UPDATED")
check(frame.deaths.text == "3 Deaths |cff888888(-0:15)|r", "deaths and the time they cost", frame.deaths.text)
client.deaths = { 0, 0 }
M:OnEvent("CHALLENGE_MODE_DEATH_COUNT_UPDATED")
check(frame.deaths.text == "", "no deaths, no text")

-------------------------------------------------------------------------------
-- Enemy forces
-------------------------------------------------------------------------------
client.criteria = {
	{ description = "Boss", isWeightedProgress = false, quantity = 0, totalQuantity = 1, quantityString = "" },
	{ description = "Enemy Forces", isWeightedProgress = true, quantity = 50, totalQuantity = 460, quantityString = "230%" }
}
M:OnEvent("SCENARIO_CRITERIA_UPDATE")
check(frame.forces.value == 0.5, "forces from the raw count over the total", frame.forces.value)
check(frame.forces.label.text == "Enemy Forces  50.0% |cff888888(230/460)|r", "forces text", frame.forces.label.text)

client.criteria[2].quantityString = "n/a"
client.criteria[2].quantity = 71
M:OnEvent("SCENARIO_CRITERIA_UPDATE")
check(frame.forces.value == 0.71, "an unreadable count falls back to the rounded percentage", frame.forces.value)

client.criteria[2].completed = true
M:OnEvent("SCENARIO_CRITERIA_UPDATE")
check(frame.forces.value == 1 and Same(frame.forces.barColor, ns.Colors.quest.green), "completed forces are full and green")
check(frame.forces.label.text == "Enemy Forces  100.0%", "no count once complete", frame.forces.label.text)
client.criteria[2].completed = nil

client.criteria[2].quantityString = "999%"
client.criteria[2].totalQuantity = 460
M:OnEvent("SCENARIO_CRITERIA_UPDATE")
check(frame.forces.value == 1, "overshooting the total caps at full")

-------------------------------------------------------------------------------
-- Settings
-------------------------------------------------------------------------------
M.db.profile.showTimer = false
M:UpdateSettings()
check(frame.shown and not frame.timer.shown and frame.forces.shown, "forces alone")
check(frame.forces.points[1] and frame.forces.points[1][2] == frame, "forces move to the top without the timer")
M.db.profile.showForces = false
M:UpdateSettings()
check(not frame.shown, "both off hides the frame")
M.db.profile = Profile()
M:UpdateSettings()
check(frame.shown and frame.timer.shown, "both back on")

-------------------------------------------------------------------------------
-- The end of the key
-------------------------------------------------------------------------------
client.completion = {
	mapChallengeModeID = 501, level = 12, time = 1500 * 1000, onTime = true, keystoneUpgradeLevels = 1,
	practiceRun = false, oldOverallDungeonScore = 2400, newOverallDungeonScore = 2431,
	isMapRecord = true, isEligibleForScore = true, members = {}
}
M:OnEvent("CHALLENGE_MODE_COMPLETED")
local card = M.card
check(card and card.shown, "a finished key shows the card")
check(card.lines[1].text == "+12  The Stonevault", "card title", card.lines[1].text)
check(card.lines[2].text == "25:00 |cff888888/ 30:00|r", "card time over the limit", card.lines[2].text)
check(card.lines[3].text == "Keystone upgraded 1 levels", "upgrade line uses Blizzard's string", card.lines[3].text)
check(card.lines[4].text == "Rating: <2431 (+31)>", "rating and gain, in the rarity colour", card.lines[4].text)
check(card.lines[5].text == "New best time for this dungeon", "record line", card.lines[5].text)
check(M.completed and frame.shown, "the timer freezes on the final time")

client.timers = {}
M:OnEvent("WORLD_STATE_TIMER_STOP")
check(frame.shown, "the finished timer stays until you leave")
M:OnEvent("PLAYER_ENTERING_WORLD")
check(not frame.shown and M.timerID == nil, "leaving the dungeon hides it")

card.scripts.OnClick(card)
check(not card.shown, "a click closes the card")

client.completion.onTime = false
client.completion.keystoneUpgradeLevels = 0
client.completion.isMapRecord = false
client.completion.isEligibleForScore = false
M:OnEvent("CHALLENGE_MODE_COMPLETED")
check(card.shown and card.lines[3].text == "Time expired", "over time says so", card.lines[3].text)
check(card.lines[4].text == "" and card.lines[5].text == "", "no rating or record lines when not earned")
M.pending()
check(not card.shown, "the card closes itself")

client.completion.practiceRun = true
M:OnEvent("CHALLENGE_MODE_COMPLETED")
check(not card.shown, "a practice run gets no card")
client.completion.practiceRun = false
M.db.profile.showCompletionCard = false
M:OnEvent("CHALLENGE_MODE_COMPLETED")
check(not card.shown, "the card can be turned off")
M.db.profile = Profile()

-------------------------------------------------------------------------------
-- The Font of Power
-------------------------------------------------------------------------------
local function Font()
	client.cursor, client.slotted, client.picked, client.slotCalls, client.cleared = nil, false, nil, 0, 0
end

Font()
client.bags = { [0] = { [1] = 12345 }, [2] = { [7] = 180653 } }
M:OnEvent("CHALLENGE_MODE_KEYSTONE_RECEPTABLE_OPEN")
check(client.picked and client.picked[1] == 2 and client.picked[2] == 7, "finds the keystone in the bags")
check(client.slotted and client.cursor == nil, "and slots it")

Font()
M.db.profile.autoSlotKeystone = false
M:OnEvent("CHALLENGE_MODE_KEYSTONE_RECEPTABLE_OPEN")
check(not client.picked, "the switch turns it off")
M.db.profile = Profile()

Font()
client.slotted = true
M:OnEvent("CHALLENGE_MODE_KEYSTONE_RECEPTABLE_OPEN")
check(not client.picked, "leaves an already slotted key alone")

Font()
client.cursor = 12345
M:OnEvent("CHALLENGE_MODE_KEYSTONE_RECEPTABLE_OPEN")
check(not client.picked and client.cursor == 12345, "never drops what is on the cursor")

Font()
client.combat = true
M:OnEvent("CHALLENGE_MODE_KEYSTONE_RECEPTABLE_OPEN")
check(not client.picked, "does nothing in combat")
client.combat = false

Font()
client.fontAccepts = false
M:OnEvent("CHALLENGE_MODE_KEYSTONE_RECEPTABLE_OPEN")
check(client.slotCalls == 1 and client.cleared == 1 and client.cursor == nil, "a refused key is not left on the cursor")
client.fontAccepts = true

Font()
client.bags = { [0] = { [1] = 12345 } }
M:OnEvent("CHALLENGE_MODE_KEYSTONE_RECEPTABLE_OPEN")
check(not client.picked and client.slotCalls == 0, "no keystone, nothing picked up")

-------------------------------------------------------------------------------
-- The Great Vault on the info bar
-------------------------------------------------------------------------------
do
	local infoNS = NewNamespace(true)
	Load("Components/Misc/Info.lua", infoNS)
	local Info = assert(modules.Info, "the Info module loads")
	Info.db = { profile = { enabled = true, enableGreatVault = true, useHalfClock = false, useServerTime = false } }
	Info:PrepareFrames()

	local function A(progress, threshold) return { progress = progress, threshold = threshold } end
	client.activities = {
		[3] = { A(2, 2), A(2, 4), A(2, 6) },
		[1] = { A(1, 1), A(1, 4), A(1, 8) },
		[6] = { A(0, 2), A(0, 4), A(0, 8) }
	}
	client.vaultReady = false
	Info:UpdateGreatVault()
	local vault = Info.vault
	check(vault.shown, "the vault counter shows")
	check(vault.text == "|cff888888Vault|r " .. infoNS.Colors.normal.colorCode .. "2/9|r", "unlocked slots over all slots", vault.text)

	Info.vaultFrame.scripts.OnEnter(Info.vaultFrame)
	local lines = env.GameTooltip.lines
	check(lines[1] == "Great Vault", "tooltip title", lines[1])
	check(lines[2] == "Raids|1/3  |cff8888882 more for the next slot|r", "raid row", lines[2])
	check(lines[3] == "Dungeons|1/3  |cff8888883 more for the next slot|r", "dungeon row", lines[3])
	check(lines[4] == "World|0/3  |cff8888882 more for the next slot|r", "world row", lines[4])
	check(#lines == 4, "no PvP row when the client has none", #lines)

	client.vaultReady = true
	Info:UpdateGreatVault()
	check(vault.text:find(infoNS.Colors.quest.green.colorCode, 1, true), "green when rewards wait")

	Info.db.profile.enableGreatVault = false
	Info:UpdateGreatVault()
	check(not vault.shown and not Info.vaultFrame.shown, "the switch hides it")

	Info.db.profile.enableGreatVault = true
	client.activities = {}
	Info:UpdateGreatVault()
	check(not vault.shown, "no vault data, no counter")
end

print(string.format("Mythic+: %d checks, %d failures", checks, failures))
if (failures > 0) then error("mythicplus_harness failed", 0) end
