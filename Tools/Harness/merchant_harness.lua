-- Auto sell junk and auto repair (FixLog 2026-11-07). Loads the real Components/Misc/Containers.lua
-- and drives Containers:OnMerchantShow against stubbed merchant APIs: both off by default, nothing in
-- combat, junk before repair, guild funds only when allowed and enough (a -1 limit is "no limit"),
-- own money otherwise, a missing API leaves its step out. Offline only: whether
-- C_MerchantFrame.SellAllJunkItems works outside Blizzard's confirmation popup is a live check.
-- Run: lua.exe Tools/Harness/merchant_harness.lua <addon root>
local root = arg[1] or '.'
local checks, failures = 0, 0
local function check(v, msg, detail)
	checks = checks + 1
	if (not v) then
		failures = failures + 1
		print("FAIL: " .. msg .. (detail ~= nil and (" - " .. tostring(detail)) or ""))
	end
end

local W
local function Reset()
	W = {
		log = {}, combat = false, junk = 3, junkEnabled = true,
		canMerchantRepair = true, cost = 500, canRepair = true, money = 1000,
		inGuild = true, canGuild = true, limit = 1000, bank = 5000,
	}
end
Reset()
local function Log(s) W.log[#W.log + 1] = s end

C_Container = {}
C_MerchantFrame = {
	GetNumJunkItems = function() return W.junk end,
	IsSellAllJunkEnabled = function() return W.junkEnabled end,
	SellAllJunkItems = function() Log("sell") end,
}
InCombatLockdown = function() return W.combat end
CanMerchantRepair = function() return W.canMerchantRepair end
GetRepairAllCost = function() return W.cost, W.canRepair end
RepairAllItems = function(guild) Log(guild and "repair-guild" or "repair-own") end
GetMoney = function() return W.money end
IsInGuild = function() return W.inGuild end
CanGuildBankRepair = function() return W.canGuild end
GetGuildBankWithdrawMoney = function() return W.limit end
GetGuildBankMoney = function() return W.bank end
GetMoneyString = function(c) return c .. "c" end
-- Present at load so OnEnable registers LOOT_READY; the fast loot section replaces them.
GetNumLootItems = function() return 0 end
LootSlot = function() end

local timers = {}
C_Timer = { After = function(t, f) timers[#timers + 1] = f end }
local function FlushTimers()
	local list = timers
	timers = {}
	for _, f in ipairs(list) do f() end
end

local prints = {}
local Module
local ns = {
	MovableModulePrototype = { defaults = { profile = { enabled = true } } },
	Merge = function(_, a, b) for k, v in pairs(b) do if (a[k] == nil) then a[k] = v end end return a end,
	NewModule = function(_, name)
		Module = { events = {} }
		function Module:RegisterEvent(e, m) self.events[e] = m end
		function Module:UnregisterEvent(e, m) if (self.events[e] == m) then self.events[e] = nil end end
		function Module:HookScript() end
		return Module
	end,
	Print = function(_, s) prints[#prints + 1] = s end,
	API = { IsAddOnEnabled = function() return false end },
}
LibStub = function() return { GetLocale = function() return setmetatable({}, { __index = function(_, k) return k end }) end } end

local chunk = assert(loadfile(root .. "/Components/Misc/Containers.lua"))
chunk("AzeriteUI5_JuNNeZ_Edition", ns)
check(Module and type(Module.OnMerchantShow) == "function", "Containers exports OnMerchantShow")

local defaults = Module:GenerateDefaults().profile
check(defaults.autoSellJunk == false and defaults.autoRepair == false and defaults.autoRepairGuild == false,
	"all three are off by default")

local profile
local function Run(fields)
	profile = { autoSellJunk = false, autoRepair = false, autoRepairGuild = false }
	for k, v in pairs(fields or {}) do profile[k] = v end
	Module.db = { profile = profile }
	W.log = {}
	prints = {}
	Module:OnMerchantShow()
	return table.concat(W.log, ",")
end

-- OnEnable registers the event (AquireBagButtons runs against nil globals and returns early).
Module:OnEnable()
check(Module.events.MERCHANT_SHOW == "OnMerchantShow", "MERCHANT_SHOW registered")
check(Module.events.MERCHANT_CLOSED == "CancelPendingRepair", "MERCHANT_CLOSED cancels a waiting repair")

check(Run() == "", "defaults: nothing happens")
check(Run({ autoSellJunk = true }) == "sell", "sell junk")
check(prints[1] == "Sold %d junk items." or (prints[1] or ""):find("3"), "sale reported", prints[1])
W.junk = 0
check(Run({ autoSellJunk = true }) == "", "no junk: nothing sold")
Reset(); W.junkEnabled = false
check(Run({ autoSellJunk = true }) == "", "sell all junk disabled by the game: nothing sold")
Reset()

check(Run({ autoRepair = true }) == "repair-own", "repair with own money")
-- After a sale the repair waits for the money (PLAYER_MONEY) or REPAIR_WAIT.
timers = {}
check(Run({ autoSellJunk = true, autoRepair = true }) == "sell", "after a sale the repair waits")
check(Module.events.PLAYER_MONEY == "OnPendingRepairMoney" and #timers == 1, "waits on PLAYER_MONEY and a timer")
Module:OnPendingRepairMoney()
check(#W.log == 1, "PLAYER_MONEY without more money: still waiting")
W.money = W.money + 200
Module:OnPendingRepairMoney()
check(table.concat(W.log, ",") == "sell,repair-own", "the sale's money arrives: repair")
check(Module.events.PLAYER_MONEY == nil, "PLAYER_MONEY released after the repair")
FlushTimers()
check(table.concat(W.log, ",") == "sell,repair-own", "the timer after the repair does nothing")
Reset()

Run({ autoSellJunk = true, autoRepair = true })
FlushTimers()
check(table.concat(W.log, ",") == "sell,repair-own", "no money event: the timer repairs")
Reset()

Run({ autoSellJunk = true, autoRepair = true })
Module:CancelPendingRepair()
W.money = W.money + 200
Module:OnPendingRepairMoney()
FlushTimers()
check(table.concat(W.log, ",") == "sell" and Module.events.PLAYER_MONEY == nil, "merchant closed: no repair later")
Reset()

Run({ autoSellJunk = true, autoRepair = true })
W.combat = true
FlushTimers()
check(table.concat(W.log, ",") == "sell", "combat by the time the wait ends: no repair")
Reset()

W.money = 400 -- 500 to repair: only the sale makes it affordable
Run({ autoSellJunk = true, autoRepair = true })
W.money = 700
Module:OnPendingRepairMoney()
check(table.concat(W.log, ",") == "sell,repair-own", "the sale's gold pays for a repair it could not before")
Reset()

W.junk = 0
check(Run({ autoSellJunk = true, autoRepair = true }) == "repair-own", "nothing sold: repair at once")
Reset()
W.cost = 0
check(Run({ autoRepair = true }) == "", "nothing to repair")
Reset(); W.canRepair = false
check(Run({ autoRepair = true }) == "", "game says no repair")
Reset(); W.canMerchantRepair = false
check(Run({ autoRepair = true }) == "", "merchant cannot repair")
Reset(); W.money = 100
check(Run({ autoRepair = true }) == "" and #prints == 1, "too poor: no repair, one message")
Reset()

check(Run({ autoRepair = true, autoRepairGuild = true }) == "repair-guild", "guild funds used")
check(Run({ autoRepairGuild = true }) == "", "guild switch alone does nothing")
W.limit = 100
check(Run({ autoRepair = true, autoRepairGuild = true }) == "repair-own", "guild limit too low: own money")
W.limit = -1
check(Run({ autoRepair = true, autoRepairGuild = true }) == "repair-guild", "limit -1 (guild leader): bank money counts")
W.bank = 100
check(Run({ autoRepair = true, autoRepairGuild = true }) == "repair-own", "guild bank too poor: own money")
Reset(); W.canGuild = false
check(Run({ autoRepair = true, autoRepairGuild = true }) == "repair-own", "no guild repair right: own money")
Reset(); W.inGuild = false
check(Run({ autoRepair = true, autoRepairGuild = true }) == "repair-own", "not in a guild: own money")
Reset()

W.combat = true
check(Run({ autoSellJunk = true, autoRepair = true }) == "", "in combat: nothing")
W.combat = false

local savedSell = C_MerchantFrame.SellAllJunkItems
C_MerchantFrame.SellAllJunkItems = nil
check(Module.CanSellJunk() == false, "CanSellJunk false without the API")
check(Run({ autoSellJunk = true, autoRepair = true }) == "repair-own", "no sell API: repair still runs")
C_MerchantFrame.SellAllJunkItems = savedSell

local savedGuild = CanGuildBankRepair
CanGuildBankRepair = nil
check(Module.CanGuildRepair() == false, "CanGuildRepair false without the API")
check(Run({ autoRepair = true, autoRepairGuild = true }) == "repair-own", "no guild API: own money")
CanGuildBankRepair = savedGuild

local savedRepair = RepairAllItems
RepairAllItems = nil
check(Module.CanRepair() == false, "CanRepair false without the API")
check(Run({ autoSellJunk = true, autoRepair = true }) == "sell", "no repair API: junk still sold")
RepairAllItems = savedRepair

-- Fast loot (OnLootReady)
check(defaults.fastLoot == false, "fast loot is off by default")
check(Module.events.LOOT_READY == "OnLootReady", "LOOT_READY registered")
local L_ = { slots = 0, looted = {}, time = 100, cvar = true, held = false }
GetNumLootItems = function() return L_.slots end
LootSlot = function(i) L_.looted[#L_.looted + 1] = i end
GetTime = function() return L_.time end
C_CVar = { GetCVarBool = function(name) if (name == "autoLootDefault") then return L_.cvar end end }
IsModifiedClick = function(name) return name == "AUTOLOOTTOGGLE" and L_.held end
local function Loot(fields, autoLoot)
	Module.db = { profile = fields }
	L_.looted = {}
	L_.time = L_.time + 1
	Module:OnLootReady("LOOT_READY", autoLoot)
	return table.concat(L_.looted, ",")
end
L_.slots = 3
check(Loot({ fastLoot = false }, true) == "", "fast loot off: nothing taken")
check(Loot({ fastLoot = true }, true) == "3,2,1", "autoLoot true: every slot, last first")
check(Loot({ fastLoot = true }, false) == "", "autoLoot false: nothing taken")
check(Loot({ fastLoot = true }, nil) == "3,2,1", "no argument: CVar on")
L_.held = true
check(Loot({ fastLoot = true }, nil) == "", "no argument: CVar on, modifier held: by hand")
L_.cvar = false
check(Loot({ fastLoot = true }, nil) == "3,2,1", "no argument: CVar off, modifier held: auto")
L_.held = false
check(Loot({ fastLoot = true }, nil) == "", "no argument: CVar off: by hand")
L_.cvar = true
Loot({ fastLoot = true }, true)
L_.looted = {}
L_.time = L_.time + 0.1
Module:OnLootReady("LOOT_READY", true)
check(#L_.looted == 0, "a second LOOT_READY right after is ignored")
L_.slots = 0
check(Loot({ fastLoot = true }, true) == "", "empty loot window: nothing")

Module.db = nil
Module:OnMerchantShow()
Module:OnLootReady("LOOT_READY", true)
check(true, "no db: no error")

print(("Merchant: %d checks, %d failures (offline only)"):format(checks, failures))
if (failures > 0) then os.exit(1) end
