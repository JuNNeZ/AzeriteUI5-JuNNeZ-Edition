-- Quest Item Button harness.
--
-- Loads the real Components/ActionBars/Elements/QuestItemData.lua and
-- QuestItemButton.lua against stubbed quest, item, map and binding APIs, and checks:
-- - which quest item the finder picks (tracked only, distance, priority, super
--   tracking, quest areas measured in yards, completed quests, empty bags);
-- - target items, and that a secret creature ID is ignored;
-- - that the click target and the icon change together, and only out of combat;
-- - the restricted attribute handler (run here as plain Lua against a fake frame
--   handle): shown with an item, hidden in a pet battle, the extra action key
--   borrowed only while the button has no key and no extra action is up;
-- - that ExtraQuestButton enabled makes the module stand down and ask.
--
-- What it cannot cover: the real restricted environment, taint, key dispatch,
-- rendering and Blizzard's quest data. Those are live checks.
--
-- Usage: lua.exe Tools/Harness/quest_item_button_harness.lua [addon root]

local root = (arg and arg[1]) or "."

local passed, failed = 0, 0
local function check(ok, label)
	if (ok) then
		passed = passed + 1
	else
		failed = failed + 1
		print("FAIL: " .. label)
	end
end

----------------------------------------------------------------
-- World state the stubs answer from
----------------------------------------------------------------
local W
local function reset()
	W = {
		combat = false,
		mapID = 100, x = .5, y = .5,
		bags = {},            -- itemID -> count
		quests = {},          -- list of { id, title, watched, worldWatch, hidden, localPOI, distSq, complete, item, showComplete, classification, worldQuest }
		superTracked = nil,
		target = nil,         -- creature ID or "secret"
		bindings = {},        -- action -> { key1, key2 }
		addons = {},
		timers = {},
		prompts = 0,
	}
end
reset()

table.wipe = table.wipe or function(t) for k in pairs(t) do t[k] = nil end return t end

local SECRET = setmetatable({}, { __tostring = function() return "secret" end })
function issecretvalue(v) return v == SECRET end
function InCombatLockdown() return W.combat end

local function questByID(id)
	for _, q in ipairs(W.quests) do if (q.id == id) then return q end end
end
local function link(id) return "|cffffffff|Hitem:" .. id .. "::::|h[Item " .. id .. "]|h|r" end

C_Item = {
	GetItemCount = function(item)
		local id = type(item) == "number" and item or tonumber(tostring(item):match("item:(%d+)"))
		return W.bags[id] or 0
	end,
	GetItemInfo = function(id) return "Item " .. id, link(id) end,
	GetItemInfoInstant = function(id) return id, "Quest", "Quest", "", "icon-" .. id end,
	GetItemCooldown = function() return 0, 0, true end,
	IsCurrentItem = function() return false end,
	ItemHasRange = function() return false end,
	IsItemInRange = function() return nil end,
}
C_Map = {
	GetBestMapForUnit = function() return W.mapID end,
	GetPlayerMapPosition = function() return { GetXY = function() return W.x, W.y end } end,
	-- Every map is a 1000 yard square on continent 1, offset by its ID.
	GetWorldPosFromMapPos = function(mapID, v)
		return 1, { GetXY = function() return mapID * 10000 + v.x * 1000, v.y * 1000 end }
	end,
}
function CreateVector2D(x, y) return { x = x, y = y } end
C_SuperTrack = { GetSuperTrackedQuestID = function() return W.superTracked end }
Enum = { QuestClassification = { BonusObjective = 4 } }
C_QuestLog = {
	GetNumWorldQuestWatches = function()
		local n = 0; for _, q in ipairs(W.quests) do if q.worldWatch then n = n + 1 end end; return n
	end,
	GetQuestIDForWorldQuestWatchIndex = function(i)
		local n = 0; for _, q in ipairs(W.quests) do if q.worldWatch then n = n + 1; if n == i then return q.id end end end
	end,
	GetNumQuestWatches = function()
		local n = 0; for _, q in ipairs(W.quests) do if q.watched then n = n + 1 end end; return n
	end,
	GetQuestIDForQuestWatchIndex = function(i)
		local n = 0; for _, q in ipairs(W.quests) do if q.watched then n = n + 1; if n == i then return q.id end end end
	end,
	GetNumQuestLogEntries = function() return #W.quests end,
	GetInfo = function(i)
		local q = W.quests[i]
		return q and { questID = q.id, isHeader = false, hasLocalPOI = q.localPOI ~= false, isHidden = q.hidden, questClassification = q.classification or 0 }
	end,
	GetDistanceSqToQuest = function(id) local q = questByID(id); return q and q.distSq end,
	GetLogIndexForQuestID = function(id) for i, q in ipairs(W.quests) do if q.id == id then return i end end end,
	IsComplete = function(id) local q = questByID(id); return q and q.complete or false end,
	IsOnMap = function(id) local q = questByID(id); return q and q.onMap or false end,
	IsWorldQuest = function(id) local q = questByID(id); return q and q.worldQuest or false end,
	GetTitleForQuestID = function(id) local q = questByID(id); return q and q.title end,
}
function GetQuestLogSpecialItemInfo(index)
	local q = W.quests[index]
	if (q and q.item) then return link(q.item), "icon", 1, q.showComplete end
end
function QuestHasPOIInfo(id) local q = questByID(id); return not (q and q.noPOI) end
C_QuestLog.GetQuestWatchType = function(id) local q = questByID(id); return q and q.watched and 0 or nil end
function UnitExists(unit) return unit == "target" and W.target ~= nil end
function UnitCreatureID() return W.target end
function UnitGUID() return nil end
function GetBindingKey(action)
	local b = W.bindings[action]
	if (b) then return b[1], b[2] end
end

C_Timer = {
	After = function(_, fn) W.timers[#W.timers + 1] = fn end,
	NewTicker = function(_, fn) local t = { fn = fn }; t.Cancel = function() t.cancelled = true end; return t end,
}
local function flush()
	local pending = W.timers; W.timers = {}
	for _, fn in ipairs(pending) do fn() end
end

----------------------------------------------------------------
-- Frames: enough for the button, and a restricted handle for the snippet
----------------------------------------------------------------
local stateDrivers = {}
local function newRegion()
	local r = { shown = true }
	function r:SetTexture(t) self.texture = t end
	function r:SetText(t) self.text = t end
	function r:SetTextColor(...) self.color = { ... } end
	local noop = function() end
	for _, m in ipairs({ "SetPoint", "SetSize", "SetMask", "SetAllPoints", "SetVertexColor", "SetJustifyH", "SetJustifyV",
		"SetFontObject", "SetShadowOffset", "SetShadowColor", "SetDrawLayer", "SetParent" }) do r[m] = noop end
	return r
end
local function newFrame(name)
	local f = newRegion()
	f.name, f.attributes, f.scripts, f.level, f.shown = name, {}, {}, 1, true
	f.overrides = {}
	function f:GetName() return self.name end
	function f:Show() self.shown = true end
	function f:Hide() self.shown = false end
	function f:IsShown() return self.shown end
	function f:GetFrameLevel() return self.level end
	function f:SetFrameLevel(l) self.level = l end
	function f:SetScript(k, fn) self.scripts[k] = fn end
	function f:GetAttribute(k) return self.attributes[k] end
	function f:SetChecked(v) self.checked = v end
	function f:CreateTexture() return newRegion() end
	function f:CreateFontString() return newRegion() end
	function f:Clear() self.cooldown = nil end
	function f:SetCooldown(s, d) self.cooldown = { s, d } end
	-- The restricted handle the snippet sees.
	local handle = {
		GetAttribute = function(_, k) return f.attributes[k] end,
		Show = function() f.shown = true end,
		Hide = function() f.shown = false end,
		ClearBindings = function() f.overrides = {} end,
		SetBindingClick = function(_, _, key) f.overrides[key] = true end,
	}
	function f:SetAttribute(k, v)
		-- State drivers are the game's own writes; anything else in combat is blocked live.
		if (W.combat and not k:find("^state%-")) then W.combatWrites = (W.combatWrites or 0) + 1 end
		self.attributes[k] = v
		local code = self.attributes._onattributechanged
		if (code and k ~= "_onattributechanged") then
			local fn = assert(loadstring("local self, name, value = ...\n" .. code))
			setfenv(fn, setmetatable({ GetBindingKey = GetBindingKey }, { __index = function(_, g) error("restricted env has no " .. g) end }))
			fn(handle, k, v)
		end
	end
	local noop = function() end
	for _, m in ipairs({ "SetFrameStrata", "SetClampedToScreen", "RegisterForClicks", "SetHighlightTexture", "SetCheckedTexture",
		"SetReverse", "SetSwipeTexture", "SetSwipeColor", "SetDrawSwipe", "SetBlingTexture", "SetDrawBling", "SetEdgeTexture",
		"SetDrawEdge", "SetHideCountdownNumbers" }) do f[m] = noop end
	return f
end
function CreateFrame(_, name) return newFrame(name) end
function RegisterStateDriver(frame, state, value) stateDrivers[state] = frame end
function UnregisterStateDriver() end
local function setState(state, value) stateDrivers[state]:SetAttribute("state-" .. state, value) end
UIParent = newFrame("UIParent")
GameTooltip = newFrame("GameTooltip")
function GameTooltip:IsForbidden() return false end

----------------------------------------------------------------
-- Addon namespace
----------------------------------------------------------------
local libs = {
	["AceLocale-3.0"] = { GetLocale = function() return setmetatable({}, { __index = function(_, k) return k end }) end },
}
LibStub = setmetatable({}, { __call = function(_, name) return libs[name] end })

local ns = { Prefix = "AzeriteUI", Colors = { red = { 1, 0, 0 }, highlight = { 1, 1, 1 }, normal = { 1, .8, 0 }, offwhite = { .8, .8, .8 } } }
function ns:Merge(a, b) for k, v in pairs(b) do if a[k] == nil then a[k] = v end end return a end
ns.MovableModulePrototype = { defaults = { enabled = true }, OnEnable = function() end }
ns.Widgets = { RegisterCooldown = function() end }
ns.GetConfig = function() return {} end
ns.API = {
	GetEffectiveScale = function() return 1 end,
	IsAddOnEnabled = function(name) return W.addons[name] end,
	IsEventAvailable = function() return true end,
	GetAddOnTitle = function(name) return name end,
	ShowAddonConflictPrompt = function() W.prompts = W.prompts + 1 end,
	GetShapedButtonConfig = function()
		return { ExtraButtonSize = { 64, 64 }, ExtraButtonIconPosition = { "CENTER" }, ExtraButtonIconSize = { 44, 44 },
			ExtraButtonCooldownSize = { 44, 44 }, ExtraButtonCooldownPosition = { "CENTER" }, ExtraButtonCooldownColor = { 0, 0, 0, .75 },
			ExtraButtonBorderPosition = { "CENTER" }, ExtraButtonBorderSize = { 134, 134 }, ExtraButtonBorderColor = { 1, 1, 1, 1 },
			ExtraButtonCooldownCountPosition = { "CENTER" }, ExtraButtonCooldownCountColor = { 1, 1, 1 },
			ExtraButtonCountPosition = { "BOTTOMRIGHT" }, ExtraButtonCountColor = { 1, 1, 1 },
			ExtraButtonBindPosition = { "TOPLEFT" }, ExtraButtonBindColor = { .5, .5, .5, .75 } }
	end,
}
local module
function ns:NewModule(name)
	module = { name = name, events = {} }
	function module:RegisterEvent(e) self.events[e] = true end
	function module:UnregisterEvent(e) self.events[e] = nil end
	function module:RegisterUnitEvent(e) self.events[e] = true end
	function module:CreateAnchor() self.anchor = true end
	function module:IsEnabled() return true end
	return module
end
function ns:GetModule() return nil end

assert(loadfile(root .. "/Components/ActionBars/Elements/QuestItemData.lua"))("AzeriteUI", ns)
assert(loadfile(root .. "/Components/ActionBars/Elements/QuestItemButton.lua"))("AzeriteUI", ns)

local Finder = ns.QuestItemFinder
local opts = function(o) o = o or {}; o.maxDistance = o.maxDistance or 1000; return o end

----------------------------------------------------------------
-- Finder
----------------------------------------------------------------
-- 1. Tracked only means tracked. An untracked log quest counts only when it is off.
reset()
W.bags[5001] = 1
W.quests = { { id = 1, item = 5001, distSq = 100 * 100 } }
check(Finder.GetClosestQuestItem(opts()) == link(5001), "untracked log quest counts with tracked only off")
check(Finder.GetClosestQuestItem(opts({ trackedOnly = true })) == nil, "untracked log quest ignored with tracked only on")
W.quests[1].watched = true
check(Finder.GetClosestQuestItem(opts({ trackedOnly = true })) == link(5001), "watched quest counts with tracked only on")
W.quests[1].watched = nil; W.quests[1].worldQuest = true
check(Finder.GetClosestQuestItem(opts({ trackedOnly = true })) == link(5001), "world quest counts with tracked only on")

-- 2. Nearest wins; beyond the maximum distance nothing.
reset()
W.bags[5001], W.bags[5002] = 1, 1
W.quests = { { id = 1, item = 5001, distSq = 400 * 400 }, { id = 2, item = 5002, distSq = 100 * 100 } }
local l, q = Finder.GetClosestQuestItem(opts())
check(l == link(5002) and q == 2, "nearest quest item wins")
check(Finder.GetClosestQuestItem(opts({ maxDistance = 50 })) == nil, "nothing beyond the maximum distance")
check(Finder.hasCandidates == true, "items in bags keep the distance poll alive")

-- 3. The super tracked quest wins at equal priority.
W.superTracked = 1
check(Finder.GetClosestQuestItem(opts()) == link(5001), "super tracked quest wins at equal priority")

-- 4. A priority item beats a nearer one (priorityItems[63508] = 1).
reset()
W.bags[63508], W.bags[5002] = 1, 1
W.quests = { { id = 1, item = 63508, distSq = 900 * 900 }, { id = 2, item = 5002, distSq = 10 * 10 } }
check(Finder.GetClosestQuestItem(opts()) == link(63508), "priority item beats a nearer one")

-- 5. Empty bags and completed quests.
reset()
W.quests = { { id = 1, item = 5001, distSq = 100 } }
check(Finder.GetClosestQuestItem(opts()) == nil and Finder.hasCandidates == false, "no item in bags, nothing and no poll")
W.bags[5001] = 1; W.quests[1].complete = true
check(Finder.GetClosestQuestItem(opts()) == nil, "completed quest hides its item")
W.quests[1].showComplete = true
check(Finder.GetClosestQuestItem(opts()) == link(5001), "completed quest keeps an item marked show when complete")

-- 6. Accurate areas are measured in yards and held to the maximum distance.
-- accurateQuestAreas[12484] = { 116, .1683, .4834 }; data item via questItems[12484] = 38149.
reset()
W.bags[38149] = 1
W.quests = { { id = 12484 } }
W.mapID, W.x, W.y = 116, .1683 + .1, .4834        -- 100 yards away on the stub map
check(Finder.GetClosestQuestItem(opts()) == link(38149), "accurate area within range counts")
check(Finder.GetClosestQuestItem(opts({ maxDistance = 50 })) == nil, "accurate area beyond range does not count")
check(math.abs(Finder.GetMapDistance(116, .2683, .4834, 116, .1683, .4834) - 100) < 1e-6, "map distance is linear yards")

-- 7. Zone only.
reset()
W.bags[5001] = 1
W.quests = { { id = 1, item = 5001, distSq = 100, onMap = false } }
check(Finder.GetClosestQuestItem(opts({ zoneOnly = true })) == nil, "zone only skips a quest off this map")
W.quests[1].onMap = true
check(Finder.GetClosestQuestItem(opts({ zoneOnly = true })) == link(5001), "zone only keeps a quest on this map")

-- 7b. A quest with no map position anywhere (Deeprun Rat Roundup, data item
-- questItems[6661] = 17117) still offers its item, behind every located quest.
reset()
W.bags[17117] = 1
W.quests = { { id = 6661, localPOI = false, noPOI = true } }
check(Finder.GetClosestQuestItem(opts()) == link(17117), "quest without a map position offers its item")
check(Finder.GetClosestQuestItem(opts({ trackedOnly = true })) == nil, "unlocated untracked quest ignored with tracked only on")
W.quests[1].watched = true
check(Finder.GetClosestQuestItem(opts({ trackedOnly = true })) == link(17117), "unlocated watched quest counts with tracked only on")
W.bags[5001] = 1
W.quests[2] = { id = 2, item = 5001, distSq = 900 * 900 }
check(Finder.GetClosestQuestItem(opts()) == link(5001), "a located quest beats one without a position")
W.quests = { { id = 6661, localPOI = false, noPOI = false } }
check(Finder.GetClosestQuestItem(opts()) == nil, "quest with a position elsewhere stays out")
W.target = 13016
check(Finder.GetTargetItem() == link(17117), "targeting a Deeprun Rat offers the flute")
W.target = nil

-- 8. Target items, and a secret creature ID.
reset()
W.bags[11804] = 1
W.target = 9999
check(Finder.GetTargetItem() == link(11804), "target item for a listed mob")
W.target = SECRET
check(Finder.GetTargetItem() == nil, "secret creature ID is ignored")

----------------------------------------------------------------
-- Module: button, combat, bindings, rival
----------------------------------------------------------------
reset()
module.db = { profile = { enabled = true, trackedOnly = false, zoneOnly = false, maxDistance = 1000, useExtraActionKey = true, showQuestInTooltip = true }, char = {} }
W.bindings.EXTRAACTIONBUTTON1 = { "Q" }
module:OnEnable()
local button = module.button
check(button ~= nil and module.anchor, "button and mover built")
flush()
setState("visible", "show"); setState("extrabar", "off")
check(button.shown == false, "no quest item, no button")

W.bags[5001] = 1
W.quests = { { id = 1, item = 5001, distSq = 100, title = "Burn the Huts" } }
module:OnEvent("QUEST_LOG_UPDATE"); flush()
check(button.attributes.item == "item:5001", "item attribute set")
check(button.Icon.texture == "icon-5001", "icon matches the item")
check(button.shown == true, "shown with an item")
check(button.overrides.Q == true, "borrows the extra action key")
check(button.HotKey.text == "Q", "hotkey shows the borrowed key")

setState("extrabar", "on")
check(button.overrides.Q == nil and button.shown == true, "extra action up: key handed back, button stays")
setState("extrabar", "off")
check(button.overrides.Q == true, "extra action gone: key borrowed again")

setState("visible", "hide")
check(button.shown == false and next(button.overrides) == nil, "pet battle hides it and drops the key")
setState("visible", "show")

-- Combat: a new item waits, then icon and click target change together.
W.combat = true
W.bags[5002] = 1
W.quests[2] = { id = 2, item = 5002, distSq = 1 }
module:OnEvent("QUEST_LOG_UPDATE"); flush()
check(button.attributes.item == "item:5001" and button.Icon.texture == "icon-5001", "nothing changes in combat")
module:OnEvent("UPDATE_BINDINGS"); module:OnKeyBoundEnabled(); module:OnKeyBoundDisabled(); flush()
check(not W.combatWrites, "no protected attribute writes in combat (bindings, keybind mode)")
W.combat = false
module:OnEvent("PLAYER_REGEN_ENABLED"); flush()
check(button.attributes.item == "item:5002" and button.Icon.texture == "icon-5002", "after combat icon and item change together")

-- Own key: no borrowing.
W.bindings["CLICK AzeriteUIQuestItemButton:LeftButton"] = { "F" }
module:OnEvent("UPDATE_BINDINGS")
check(button.attributes.usefallback == nil and next(button.overrides) == nil, "own key: extra action key not borrowed")
check(button.HotKey.text == "F", "hotkey shows the own key")

-- Disabled: empty and hidden.
module.db.profile.enabled = false
module:UpdateSettings(); flush()
check(button.attributes.item == nil and button.shown == false, "disabled: no item, hidden")

-- Binding mode shows the empty button with a placeholder.
module.db.profile.enabled = true
W.quests = {}
module:UpdateSettings(); flush()
module:OnKeyBoundEnabled()
check(button.shown == true and button.Icon.texture ~= nil, "keybind mode shows the button")
module:OnKeyBoundDisabled()
check(button.shown == false, "keybind mode off hides it again")

-- Rival: stand down and ask once.
reset()
W.addons.ExtraQuestButton = true
module.button, module.frame, module.anchor = nil, nil, nil
module.db.char = {}
module:OnEnable(); flush()
check(module.button == nil and module:IsStandingDown(), "ExtraQuestButton enabled: stands down")
check(W.prompts == 1, "and asks which to use")
module.db.char = { rival = "ExtraQuestButton", owner = "both" }
module:OnEnable(); flush()
check(module.button ~= nil and not module:IsStandingDown(), "both chosen: runs anyway")

print(string.format("quest_item_button_harness: %d passed, %d failed", passed, failed))
if (failed > 0) then os.exit(1) end
