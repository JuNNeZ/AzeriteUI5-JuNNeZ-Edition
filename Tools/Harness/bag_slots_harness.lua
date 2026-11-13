-- Offline bag-slot regression: Blizzard's cursor auto-expand hides bag buttons,
-- then BagsBar:Layout reanchors them to its own (hidden) backpack/expand button.
-- Fixture follows Blizzard_MainMenuBarBagButtons/Shared/{MainMenuBarBagManager,BagsBar}.lua.
-- Run: lua Tools/Harness/bag_slots_harness.lua [root] [Containers.lua override]
local root = arg[1] or "."
local source = arg[2] or root .. "/Components/Misc/Containers.lua"
local checks, failures = 0, 0
local function check(ok, label)
	checks = checks + 1
	if not ok then failures = failures + 1; print("FAIL: " .. label) end
end
local combat, writes, rival, w2ui = false, 0
local function write() writes = writes + 1 end
local function frame(parent)
	local f = { parent = parent, shown = false, strata = "MEDIUM", level = 4, hooks = {} }
	function f:GetParent() return self.parent end
	function f:SetParent(p) write(); self.parent = p end
	function f:GetPoint() return unpack(self.point or {}) end
	function f:SetPoint(...) write(); self.point = {...} end
	function f:ClearAllPoints() write(); self.point = nil end
	function f:SetSize(w, h) write(); self.width, self.height = w, h end
	function f:SetHeight(h) write(); self.height = h end
	function f:GetFrameStrata() return self.strata end
	function f:SetFrameStrata(s) write(); self.strata = s end
	function f:GetFrameLevel() return self.level end
	function f:SetFrameLevel(n) write(); self.level = n end
	function f:IsShown() return self.shown end
	function f:Show()
		write()
		local changed = not self.shown
		self.shown = true
		if changed and self.hooks.OnShow then self.hooks.OnShow(self) end
	end
	function f:Hide() write(); self.shown = false end
	return f
end
local Module
local ns = {
	MovableModulePrototype = { defaults = {} },
	Merge = function(_, a) return a end,
	API = {
		IsAddOnEnabled = function(name) return name == rival end,
		IsW2UIBagBarEnabled = function() return w2ui end,
	},
	NewModule = function()
		Module = { events = {} }
		function Module:RegisterEvent(e, fn) self.events[e] = fn end
		function Module:SecureHookScript(f, e, fn) f.hooks[e] = fn end
		function Module:HookScript(f, e, fn) f.hooks[e] = fn end -- old implementation
		function Module:SecureHook(f, method, fn)
			local original = f[method]
			f[method] = function(...) original(...); fn(...) end
		end
		return Module
	end,
}
LibStub = function() return { GetLocale = function() return {} end } end
C_Container = {}
InCombatLockdown = function() return combat end

local names = {"CharacterBag0Slot", "CharacterBag1Slot", "CharacterBag2Slot", "CharacterBag3Slot", "CharacterReagentBag0Slot"}
local function setup(classic, inCombat)
	combat, writes = inCombat or false, 0
	UIParent = frame()
	ContainerFrame1 = frame(UIParent)
	ContainerFrameCombinedBags = not classic and frame(UIParent) or nil
	BagsBar = frame(UIParent)
	for _, name in ipairs(names) do _G[name] = frame(BagsBar) end
	if classic then CharacterReagentBag0Slot = nil end
	KeyRingButton = classic and frame(BagsBar) or nil
	-- Blizzard Layout anchors every shown bag button to its native bar chain.
	function BagsBar:Layout()
		local previous = self
		for _, name in ipairs(names) do
			local slot = _G[name]
			if slot and slot:IsShown() then
				slot:ClearAllPoints()
				slot:SetPoint("RIGHT", previous, "LEFT", 0, 0)
				previous = slot
			end
		end
	end
	assert(loadfile(source))("AzeriteUI", ns)
	Module:AquireBagButtons()
end
local function expanded(value)
	-- OnExpandBarChanged calls SetBarExpanded before firing the Layout callback.
	for _, name in ipairs(names) do
		local slot = _G[name]
		if slot and name ~= "CharacterReagentBag0Slot" then
			if value then slot:Show() else slot:Hide() end
		end
	end
	BagsBar:Layout()
end
local function aligned(parent, label)
	local previous
	for _, name in ipairs(names) do
		local slot = _G[name]
		if slot then
			local point, relative, relativePoint, x, y = slot:GetPoint()
			check(slot:GetParent() == parent and slot:IsShown(), label .. ": " .. name .. " shown under bag window")
			check(relative == (previous or parent) and point == (previous and "RIGHT" or "TOPRIGHT")
				and relativePoint == (previous and "LEFT" or "BOTTOMRIGHT")
				and x == (previous and 0 or -6) and y == (previous and 0 or 4), label .. ": " .. name .. " anchor")
			previous = slot
		end
	end
end
setup(false, true)
check(writes == 0 and Module.bagSlotsPending, "initial acquisition in combat: no frame mutations")
combat = false
if Module.events.PLAYER_REGEN_ENABLED then Module.events.PLAYER_REGEN_ENABLED(Module) end
check(CharacterBag0Slot.width == 24, "deferred initialization sizes reagent-client slots")
setup()
ContainerFrame1:Show()
aligned(ContainerFrame1, "initial split")
expanded(true) -- pick up bag
expanded(false) -- drop bag, user expandBagBar CVar false
aligned(ContainerFrame1, "bag dropped with bar collapsed")
ContainerFrame1:Hide()
ContainerFrameCombinedBags:Show()
aligned(ContainerFrameCombinedBags, "combined")
expanded(false)
aligned(ContainerFrameCombinedBags, "combined bag swap")
BagsBar:Layout() -- Edit Mode can also run layout without a cursor change
aligned(ContainerFrameCombinedBags, "Edit Mode layout")
combat = true
local before = writes
-- Call the installed post-hook through Layout. Count only our writes after native work:
-- native Layout performs 10 writes for the five currently shown slots.
BagsBar:Layout()
check(writes - before == 10, "combat: no addon frame mutations")
check(Module.bagSlotsPending == true, "combat: repair pending")
combat = false
if Module.events.PLAYER_REGEN_ENABLED then Module.events.PLAYER_REGEN_ENABLED(Module) end
aligned(ContainerFrameCombinedBags, "combat replay")
check(not Module.bagSlotsPending, "combat replay clears pending")
ContainerFrameCombinedBags:Hide()
ContainerFrame1:Show()
aligned(ContainerFrame1, "return to split")
ContainerFrame1:Hide()
check(not ContainerFrame1:IsShown(), "closed window still controls visibility")
setup(true)
ContainerFrame1:Show()
expanded(false)
aligned(ContainerFrame1, "no combined/reagent")
check(KeyRingButton:GetParent() == ContainerFrame1 and KeyRingButton:IsShown(), "keyring follows backpack")
check(CharacterBag0Slot.width == 30, "no reagent uses 30px slots")
for _, addon in ipairs({"AdiBags", "ArkInventory", "Baganator", "Bagnon", "Bartender4", "BetterBags", "Combuctor", "W2UI_Bags"}) do
	rival = addon
	setup()
	check(writes == 0 and not next(Module.events), addon .. " retains bag ownership")
end
rival, w2ui = nil, true
setup()
check(writes == 0 and not next(Module.events), "W2UI bag bar retains ownership")
w2ui = false
print(string.format("bag_slots: %d checks, %d failures", checks, failures))
os.exit(failures == 0 and 0 or 1)
