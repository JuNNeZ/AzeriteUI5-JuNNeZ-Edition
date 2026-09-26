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
-- Nameplates, 2 of 10: what a plate is: hostile or friendly, player or NPC, object, widgets only.
-- Loaded after Settings.lua; see Settings.lua for how these files share their locals.
local _, ns = ...

local NP = ns.NamePlatesPrivate
if (not NP) then return end

local strsplit = strsplit
local tostring = tostring

local IsSecretValue = NP.IsSecretValue
local IsSafeUnitToken = NP.IsSafeUnitToken
local IsPlayerForDisplay = NP.IsPlayerForDisplay

local GetGuidType = function(unit)
	if (type(unit) ~= "string" or IsSecretValue(unit) or unit == "") then
		return nil
	end
	local guid = UnitGUID(unit)
	if (type(guid) ~= "string" or IsSecretValue(guid) or guid == "") then
		return nil
	end
	local guidType = guid:match("^([^-]+)-")
	if (guidType and guidType ~= "") then
		return guidType
	end
	return nil
end

local GetGuidAndNpcID = function(unit)
	if (not IsSafeUnitToken(unit)) then
		return nil, nil
	end
	local guid = UnitGUID(unit)
	if (type(guid) ~= "string" or IsSecretValue(guid) or guid == "") then
		return nil, nil
	end
	local guidType = guid:match("^([^-]+)-")
	if (guidType == "Creature" or guidType == "Vehicle" or guidType == "Pet") then
		local _, _, _, _, _, npcID = strsplit("-", guid)
		return guid, npcID
	end
	return guid, nil
end

-- Hotfix exceptions from live diagnostics.
-- These are surgical guards to keep known interactable trainers visible
-- while suppressing known decorative object-like creature plates.
local AlwaysShowFriendlyNPCByID = {
	["229383"] = true -- Treni (Fishing Trainer)
}

local AlwaysHideObjectLikeNPCByID = {
	["223648"] = true, -- Betta (decorative object-like plate)
	["212708"] = true, -- Freysworn Cruton (decorative object-like plate)
	["191909"] = true  -- Tuskarr Beanbag (vehicle/object-like seat)
}

-- What a plate is: hostile or friendly, player or NPC, an object, widgets only. Every answer comes
-- from a guarded unit query and is written onto `plate`, which may be a scratch table. The key it
-- returns changes whenever any answer does.
local NamePlate_Classify = function(plate, unit)
	plate.nameplateShowsWidgetsOnly = ns.IsRetail and UnitNameplateShowsWidgetsOnly(unit)
	local canAttack = UnitCanAttack("player", unit)
	local canAssist = UnitCanAssist("player", unit)
	local isFriend = UnitIsFriend("player", unit)
	-- Players, and NPCs the game draws as players (follower companions): false on a secret answer.
	local isPlayerUnit = IsPlayerForDisplay(unit)
	local playerControlled = UnitPlayerControlled(unit)
	local reaction = UnitReaction("player", unit)
	local guidType = GetGuidType(unit)
	local _, npcID = GetGuidAndNpcID(unit)
	if (issecretvalue and issecretvalue(canAttack)) then
		canAttack = nil
	end
	if (issecretvalue and issecretvalue(canAssist)) then
		canAssist = nil
	end
	if (issecretvalue and issecretvalue(isFriend)) then
		isFriend = nil
	end
	if (issecretvalue and issecretvalue(playerControlled)) then
		playerControlled = false
	end
	if (issecretvalue and issecretvalue(reaction)) then
		reaction = nil
	end

	-- When canAttack/canAssist are secret (nil after guard), use UnitReaction as fallback.
	-- UnitReaction: 1=Hated..4=Neutral..8=Exalted; <= 4 means hostile/unfriendly.
	if (canAttack == nil and canAssist == nil and type(reaction) == "number") then
		if (reaction <= 4) then
			canAttack = true
		elseif (reaction >= 5) then
			canAssist = true
		end
	end
	if (isFriend == nil and type(reaction) == "number") then
		isFriend = reaction >= 5
	end

	plate.canAttack = (canAttack == true)
	plate.canAssist = (canAssist == true)
	plate.isPlayerUnit = isPlayerUnit and true or nil

	local guidLooksLikeObject = (guidType == "GameObject") or (guidType == "AreaTrigger")
	local passiveWorldObjectLike = ((canAttack == false) and (canAssist == false) and (not isPlayerUnit) and (not playerControlled))
	local isCompanionLikeGuidType = (guidType == "Pet") or (guidType == "Creature") or (guidType == "Vehicle")
	local forceShowFriendlyNPC = (type(npcID) == "string") and AlwaysShowFriendlyNPCByID[npcID] and true or false
	local forceHideObjectLikeNPC = (type(npcID) == "string") and AlwaysHideObjectLikeNPCByID[npcID] and true or false
	local suppressObjectLikeNPCByID = forceHideObjectLikeNPC and (not forceShowFriendlyNPC) and true or false
	plate.isObjectPlate = (guidLooksLikeObject or suppressObjectLikeNPCByID or (plate.nameplateShowsWidgetsOnly and passiveWorldObjectLike and (not isCompanionLikeGuidType)) or (passiveWorldObjectLike and guidType == nil)) and true or nil
	-- A friendly NPC as Blizzard's plates count one: friendly and not a player (NamePlateUnitFrameMixin
	-- IsFriend, IsPlayer). The name is older than that: until 2026-09-25 it took UnitCanAssist, which
	-- most vendors, trainers and quest givers answer false, and those were sized as friendly players.
	plate.isFriendlyAssistableNPC = (not plate.isObjectPlate) and (not isPlayerUnit) and (canAttack ~= true)
		and ((isFriend == true) or (canAssist == true) or forceShowFriendlyNPC) and (not playerControlled)
	-- A player's pet, totem or guardian, as Blizzard's plate asks (NamePlateUnitFrameMixin IsMinion). Not
	-- documented as secret on either client; a secret answer counts as no minion.
	local isMinion = UnitIsMinion and UnitIsMinion(unit)
	plate.isMinion = ((not IsSecretValue(isMinion)) and isMinion == true) and true or nil
	return table.concat({ tostring(plate.canAttack), tostring(plate.canAssist), tostring(plate.isPlayerUnit),
		tostring(plate.isObjectPlate), tostring(plate.isFriendlyAssistableNPC), tostring(plate.nameplateShowsWidgetsOnly),
		tostring(plate.isMinion) }, ",")
end

-- A unit can arrive before its answers do. One frame after a plate is added, look again: lay it out
-- a second time only if something it is classified by changed, or its name has since arrived.
-- (It used to be laid out twice unconditionally; nothing recorded why, so the check stays.)
local classifyProbe = {}
local NamePlate_NeedsSecondPass = function(self, unit)
	if (NamePlate_Classify(classifyProbe, unit) ~= self.__AzeriteUI_ClassKey) then
		return true
	end
	if (self.isObjectPlate or self.isPRD or not self.Name) then
		return false
	end
	local text = self.Name:GetText()
	local empty = (type(text) ~= "string") or (not issecretvalue(text) and text == "")
	return empty and type(UnitName(unit)) == "string"
end

NP.NamePlate_Classify = NamePlate_Classify
NP.NamePlate_NeedsSecondPass = NamePlate_NeedsSecondPass
