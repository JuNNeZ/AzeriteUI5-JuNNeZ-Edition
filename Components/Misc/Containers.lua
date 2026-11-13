--[[

	The MIT License (MIT)

	Copyright (c) 2026 Lars Norberg
	Copyright (c) 2026 Jonas "JuNNeZ" Andersen (JuNNeZ Edition modifications)

	Permission is hereby granted, free of charge, to any person obtaining a copy
	of this software and associated documentation files (the "Software"), to deal
	in the Software without restriction, including without limitation the rights
	to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
	copies of the Software, and to permit persons to whom the Software is
	furnished to do so, subject to the following conditions:

	The above copyright notice and this permission notice shall be included in all
	copies or substantial portions of the Software.

	THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
	IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
	FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
	AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
	LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
	OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
	SOFTWARE.

--]]
local _, ns = ...

if (not C_Container) then return print("C_Container not found") end

local Containers = ns:NewModule("Containers", ns.MovableModulePrototype, "LibMoreEvents-1.0", "AceHook-3.0")

local L = LibStub("AceLocale-3.0"):GetLocale((...))

local defaults = { profile = ns:Merge({
	sort = "rtl",
	insert = "ltr",
	-- At a merchant (MERCHANT_SHOW). Off by default; bag addons usually do this already.
	autoSellJunk = false,
	autoRepair = false,
	autoRepairGuild = false,
	-- Take everything the moment the loot window opens, when the game would auto loot anyway.
	fastLoot = false
}, ns.MovableModulePrototype.defaults) }

-- Generate module defaults on the fly
-- to recalculate default values relying on
-- changing factors like user interface scale.
Containers.GenerateDefaults = function(self)
	return defaults
end

Containers.AquireBagButtons = function(self)

	-- Don't interfere with known bag addons. Baganator (834) and BetterBags hide
	-- Blizzard's backpack frames, so moving the bag slots into them only hides the
	-- slots with them; neither addon uses those slots for its own window.
	-- W2UI_Bags hides Blizzard's container frames the same way.
	for _,addon in next,{ "AdiBags", "ArkInventory", "Baganator", "Bagnon", "Bartender4", "BetterBags", "Combuctor", "W2UI_Bags" } do
		if (ns.API.IsAddOnEnabled(addon)) then return end
	end

	-- W2UI's Bag Buttons module keeps these slots on BagsBar as its own bag bar.
	if (ns.API.IsW2UIBagBarEnabled and ns.API.IsW2UIBagBarEnabled()) then return end

	-- Attempt to hook the bag bar to the bags
	-- Retrieve the first slot button and the backpack
	local firstSlot = CharacterBag0Slot
	local backpack = ContainerFrame1
	local combined = ContainerFrameCombinedBags -- Retail
	local reagentSlot = CharacterReagentBag0Slot -- Retail
	local keyring = KeyRingButton -- Classic, Wrath
	local slots = {
		"CharacterBag0Slot",
		"CharacterBag1Slot",
		"CharacterBag2Slot",
		"CharacterBag3Slot",
		"CharacterReagentBag0Slot" -- >= 10.0.0
	}

	-- Try to avoid the potential error with anima deposit animations.
	-- Just give it a simplified version of the default position it is given,
	-- it will be replaced by UpdateContainerFrameAnchors() later on anyway.
	if (backpack and not backpack:GetPoint() and not InCombatLockdown()) then
		backpack:SetPoint("BOTTOMRIGHT", backpack:GetParent(), "BOTTOMRIGHT", -14, 93 )
	end

	if (not firstSlot or not backpack) then return end

	local slotSize = reagentSlot and 24 or 30

	local updating, initialized
	local UpdateBagSlots = function()
		if (updating) then return end
		-- Native bag buttons can be protected. Replay after combat instead of
		-- changing their parent, anchors or shown state while locked down.
		if (InCombatLockdown()) then
			self.bagSlotsPending = true
			return
		end
		self.bagSlotsPending = nil
		updating = true
		if (not initialized) then
			for _, slotName in ipairs(slots) do
				local slot = _G[slotName]
				if (slot) then
					slot:SetSize(slotSize, slotSize)
					local tex = _G[slotName.."NormalTexture"]
					if (tex) then
						tex:SetTexture("")
						tex:SetAlpha(0)
					end
				end
			end
			initialized = true
		end
		local parent = combined and combined:IsShown() and combined or backpack
		local previous
		for _, slotName in ipairs(slots) do
			local slot = _G[slotName]
			if (slot) then
				if (slot:GetParent() ~= parent) then slot:SetParent(parent) end
				slot:SetFrameStrata(parent:GetFrameStrata())
				slot:SetFrameLevel(parent:GetFrameLevel())
				slot:ClearAllPoints()
				if (previous) then
					slot:SetPoint("RIGHT", previous, "LEFT", 0, 0)
				else
					slot:SetPoint("TOPRIGHT", parent, "BOTTOMRIGHT", -6, 4)
				end
				-- MainMenuBarBagManager collapses these on CURSOR_CHANGED when
				-- a bag is dropped. Their new parent owns visibility now.
				slot:Show()
				previous = slot
			end
		end
		if (keyring) then
			if (keyring:GetParent() ~= parent) then keyring:SetParent(parent) end
			keyring:SetHeight(slotSize)
			keyring:SetFrameStrata(parent:GetFrameStrata())
			keyring:SetFrameLevel(parent:GetFrameLevel())
			keyring:ClearAllPoints()
			keyring:SetPoint("RIGHT", previous, "LEFT", 0, 0)
			keyring:Show()
		end
		updating = nil
	end

	-- Do not wrap Blizzard's original OnShow: it also runs native bag navigation.
	self:SecureHookScript(backpack, "OnShow", UpdateBagSlots)
	if (combined) then
		self:SecureHookScript(combined, "OnShow", UpdateBagSlots)
	end
	-- BagsBar:Layout rewrites every slot anchor after cursor/expand changes and
	-- Edit Mode updates, even though the buttons no longer belong to that bar.
	if (BagsBar and type(BagsBar.Layout) == "function") then
		self:SecureHook(BagsBar, "Layout", UpdateBagSlots)
	end
	self:RegisterEvent("PLAYER_REGEN_ENABLED", function()
		if (self.bagSlotsPending) then UpdateBagSlots() end
	end)
	UpdateBagSlots()
end

Containers.UpdateSettings = function(self)
	if (C_Container.SetSortBagsRightToLeft) then
		if (self.db.profile.sort == "rtl") then
			C_Container.SetSortBagsRightToLeft(true)
		elseif (self.db.profile.sort == "ltr") then
			C_Container.SetSortBagsRightToLeft(false)
		end
	end
	if (C_Container.SetInsertItemsLeftToRight) then
		if (self.db.profile.insert == "ltr") then
			C_Container.SetInsertItemsLeftToRight(true)
		elseif (self.db.profile.insert == "rtl") then
			C_Container.SetInsertItemsLeftToRight(false)
		end
	end
end

-- Merchant
--------------------------------------------
-- Sell junk and repair when a merchant opens, both off by default. Each press is the one Blizzard's
-- own merchant buttons make (Blizzard_UIPanels_Game/Mainline/MerchantFrame.lua, which Forever uses
-- too): C_MerchantFrame.SellAllJunkItems without its confirmation popup, RepairAllItems(true) for the
-- guild bank and RepairAllItems() for your own money. Nothing here runs in combat or touches the
-- merchant frame; a missing API leaves its step out.

-- Exposed for the options page: hide a switch the client cannot do.
Containers.CanSellJunk = function()
	return C_MerchantFrame and type(C_MerchantFrame.SellAllJunkItems) == "function" and true or false
end

Containers.CanRepair = function()
	return type(RepairAllItems) == "function" and type(GetRepairAllCost) == "function"
		and type(CanMerchantRepair) == "function"
end

Containers.CanGuildRepair = function()
	return Containers.CanRepair() and type(CanGuildBankRepair) == "function"
		and type(GetGuildBankWithdrawMoney) == "function" and type(GetGuildBankMoney) == "function"
end

local FormatMoney = function(copper)
	if (type(GetMoneyString) == "function") then
		return GetMoneyString(copper, true)
	end
	return tostring(copper)
end

-- How much the guild bank lets you spend: the smaller of your withdraw limit and the bank's money.
-- A limit of -1 is the guild leader's "no limit", as in Blizzard's repair tooltip.
local GetGuildRepairFunds = function()
	if (type(IsInGuild) == "function" and not IsInGuild()) then
		return 0
	end
	if (not CanGuildBankRepair()) then
		return 0
	end
	local limit, bank = GetGuildBankWithdrawMoney(), GetGuildBankMoney()
	if (type(limit) ~= "number" or type(bank) ~= "number") then
		return 0
	end
	if (limit == -1) then
		return bank
	end
	return math.min(limit, bank)
end

Containers.SellJunk = function(self)
	if (not Containers.CanSellJunk()) then
		return
	end
	local count = type(C_MerchantFrame.GetNumJunkItems) == "function" and C_MerchantFrame.GetNumJunkItems()
	if (type(count) == "number" and count <= 0) then
		return
	end
	if (type(C_MerchantFrame.IsSellAllJunkEnabled) == "function" and not C_MerchantFrame.IsSellAllJunkEnabled()) then
		return
	end
	C_MerchantFrame.SellAllJunkItems()
	if (type(count) == "number") then
		ns:Print(string.format(L["Sold %d junk items."], count))
	end
	return true
end

Containers.Repair = function(self)
	if (not Containers.CanRepair() or not CanMerchantRepair()) then
		return
	end
	local cost, canRepair = GetRepairAllCost()
	if (not canRepair or type(cost) ~= "number" or cost <= 0) then
		return
	end
	if (self.db.profile.autoRepairGuild and Containers.CanGuildRepair() and GetGuildRepairFunds() >= cost) then
		RepairAllItems(true)
		ns:Print(string.format(L["Repaired for %s from the guild bank."], FormatMoney(cost)))
		return
	end
	if (type(GetMoney) == "function" and GetMoney() >= cost) then
		RepairAllItems()
		ns:Print(string.format(L["Repaired for %s."], FormatMoney(cost)))
	else
		ns:Print(string.format(L["Not enough money to repair (%s)."], FormatMoney(cost)))
	end
end

Containers.OnMerchantShow = function(self)
	if (InCombatLockdown()) then
		return
	end
	local profile = self.db and self.db.profile
	if (not profile) then
		return
	end
	self:CancelPendingRepair()
	-- Junk first: its gold can pay for the repair. The sale's money reaches GetMoney a moment later
	-- (server round trip), so after a sale the repair waits for PLAYER_MONEY, at most REPAIR_WAIT
	-- seconds, as Wowdee's automation does (FixLog 2026-11-07).
	local sold = profile.autoSellJunk and self:SellJunk()
	if (not profile.autoRepair) then
		return
	end
	if (not sold or type(GetMoney) ~= "function" or not C_Timer) then
		return self:Repair()
	end
	local token = {}
	self.pendingRepair = token
	self.pendingRepairPurse = GetMoney()
	self:RegisterEvent("PLAYER_MONEY", "OnPendingRepairMoney")
	C_Timer.After(Containers.REPAIR_WAIT, function()
		if (self.pendingRepair == token) then
			self:RunPendingRepair()
		end
	end)
end

Containers.REPAIR_WAIT = 1.5

Containers.CancelPendingRepair = function(self)
	if (self.pendingRepair) then
		self.pendingRepair, self.pendingRepairPurse = nil, nil
		self:UnregisterEvent("PLAYER_MONEY", "OnPendingRepairMoney")
	end
end

Containers.RunPendingRepair = function(self)
	if (not self.pendingRepair) then
		return
	end
	self:CancelPendingRepair()
	-- MERCHANT_CLOSED cancels it; Repair asks CanMerchantRepair again in case a close was missed.
	if (InCombatLockdown()) then
		return
	end
	self:Repair()
end

Containers.OnPendingRepairMoney = function(self)
	local purse = self.pendingRepairPurse
	if (purse and GetMoney() > purse) then
		self:RunPendingRepair()
	end
end

-- Fast loot
--------------------------------------------
-- On LOOT_READY, take every slot at once instead of waiting for the loot window's own pace. Only when
-- the game would auto loot anyway: LOOT_READY's autoLoot argument, or when a client leaves it out,
-- the autoLootDefault CVar turned around while the AUTOLOOTTOGGLE modifier is held (the game's own
-- rule). Last slot first, so taking one does not shift the rest. A second LOOT_READY for the same
-- window within FAST_LOOT_REPEAT seconds is ignored. Off by default. From Wowdee's Automation.lua
-- (MIT; FixLog 2026-11-07).
Containers.FAST_LOOT_REPEAT = 0.3

Containers.CanFastLoot = function()
	return type(GetNumLootItems) == "function" and type(LootSlot) == "function"
end

Containers.WouldAutoLoot = function(autoLoot)
	if (autoLoot ~= nil) then
		return autoLoot and true or false
	end
	local cvar = C_CVar and C_CVar.GetCVarBool and C_CVar.GetCVarBool("autoLootDefault")
	if (cvar == nil and type(GetCVarBool) == "function") then
		cvar = GetCVarBool("autoLootDefault")
	end
	local held = type(IsModifiedClick) == "function" and IsModifiedClick("AUTOLOOTTOGGLE")
	if (held) then
		return not cvar
	end
	return cvar and true or false
end

Containers.OnLootReady = function(self, event, autoLoot)
	local profile = self.db and self.db.profile
	if (not profile or not profile.fastLoot or not Containers.CanFastLoot()) then
		return
	end
	if (not Containers.WouldAutoLoot(autoLoot)) then
		return
	end
	local now = GetTime()
	if (self.lastFastLoot and now - self.lastFastLoot < Containers.FAST_LOOT_REPEAT) then
		return
	end
	self.lastFastLoot = now
	for slot = GetNumLootItems(), 1, -1 do
		LootSlot(slot)
	end
end

Containers.OnEnable = function(self)
	self:AquireBagButtons()
	self:RegisterEvent("MERCHANT_SHOW", "OnMerchantShow")
	self:RegisterEvent("MERCHANT_CLOSED", "CancelPendingRepair")
	if (Containers.CanFastLoot()) then
		self:RegisterEvent("LOOT_READY", "OnLootReady")
	end
end
