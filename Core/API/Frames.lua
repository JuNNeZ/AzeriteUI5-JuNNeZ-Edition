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
local API = ns.API or {}
ns.API = API

-- Lua API
local CreateFrame = CreateFrame
local type = type

local CreateFrameUnscaled = function(...)
	local frame = CreateFrame(...)
	frame:SetIgnoreParentScale(true)
	return frame
end

local IsHouseEditorActive = function()
	local isActive = C_HouseEditor and C_HouseEditor.IsHouseEditorActive
	if (not isActive) then
		return false
	end
	local ok, active = API.TryCall(isActive)
	return ok and active == true
end

local IsSecret = function(value)
	return (type(issecretvalue) == "function") and issecretvalue(value) and true or false
end

-- Returns a level that addon logic may compare, or nil when it is missing or secret.
local GetSafeLevel = function(level)
	if (type(level) ~= "number") or IsSecret(level) then
		return nil
	end
	return level
end

-- A positive, comparable cap, or nil. Forever sets the global MAX_PLAYER_LEVEL to 0
-- (Blizzard_UIPanels_Game/Vanilla/ReputationFrame.lua), so zero never counts.
local GetSafeCap = function(func)
	local ok, value = API.TryCall(func)
	value = ok and GetSafeLevel(value)
	return (value and value > 0) and value or nil
end

-- The level cap that ends the player's levelling, on any client. Blizzard's own
-- GameRulesUtil.GetEffectiveMaxLevelForPlayer is preferred (identical on Retail and
-- Forever 1.60.1); the fallbacks repeat its min(expansion cap, player cap).
-- Returns nil when the client cannot say.
local GetEffectiveMaxLevel = function()
	local cap = GetSafeCap(GameRulesUtil and GameRulesUtil.GetEffectiveMaxLevelForPlayer)
	if (cap) then
		return cap
	end
	local expansionCap = GetSafeCap(GetMaxLevelForPlayerExpansion)
	local playerCap = GetSafeCap(GetMaxPlayerLevel)
	if (expansionCap and playerCap) then
		return math.min(expansionCap, playerCap)
	end
	cap = expansionCap or playerCap
	if (cap) then
		return cap
	end
	cap = GetSafeLevel(MAX_PLAYER_LEVEL)
	return (cap and cap > 0) and cap or nil
end

local IsLevelAtEffectiveMaxLevel = function(level)
	level = GetSafeLevel(level)
	local cap = GetEffectiveMaxLevel()
	if (not level) or (not cap) then
		return false
	end
	return level >= cap
end

local IsPlayerAtEffectiveMaxLevel = function()
	return IsLevelAtEffectiveMaxLevel(UnitLevel("player"))
end

-- The unit frame skin tier for a level: "Novice" below 10, "Seasoned" at the cap,
-- for "??" (level below 1) or with experience switched off, "Hardened" otherwise
-- and whenever the level is missing or secret. Never compares a secret value.
local GetLevelTier = function(level, xpDisabled)
	if (xpDisabled == true) then
		return "Seasoned"
	end
	level = GetSafeLevel(level)
	if (not level) then
		return "Hardened"
	end
	if (level < 1) or IsLevelAtEffectiveMaxLevel(level) then
		return "Seasoned"
	end
	return (level < 10) and "Novice" or "Hardened"
end

-- Creature type 8 is Critter in the client's CreatureType table on every flavor.
-- UnitCreatureType returns (localized name, id); the name alone fails on any
-- non-English client, so the id is checked first; the English name and the
-- client's own name for type 8 (C_CreatureInfo) cover a client without the id.
local CREATURE_TYPE_CRITTER = 8
local critterTypeName

local GetCritterTypeName = function()
	if (critterTypeName == nil) then
		critterTypeName = false
		local getInfo = C_CreatureInfo and C_CreatureInfo.GetCreatureTypeInfo
		local ok, info = API.TryCall(getInfo, CREATURE_TYPE_CRITTER)
		local name = ok and type(info) == "table" and info.name
		if (type(name) == "string") and (not IsSecret(name)) and (name ~= "") then
			critterTypeName = name
		end
	end
	return critterTypeName or nil
end

-- True when the unit's creature type is Critter, in any client language.
local IsUnitCritterType = function(unit)
	local ok, name, id = API.TryCall(UnitCreatureType, unit)
	if (not ok) then
		return false
	end
	if (type(id) == "number") and (not IsSecret(id)) and (id == CREATURE_TYPE_CRITTER) then
		return true
	end
	if (type(name) ~= "string") or IsSecret(name) then
		return false
	end
	return (name == "Critter") or (name == GetCritterTypeName())
end

-- A player's Mythic+ rating this season and the colour the game gives that score,
-- or nil when there is none to show (no rating, not a player, an older client).
-- C_PlayerInfo.GetPlayerMythicPlusRatingSummary documents no secret return, but the
-- score is still checked, so a client that starts hiding it shows nothing instead
-- of raising. The unit token is passed as given; callers hand in plain tokens.
local GetMythicPlusRating = function(unit)
	local playerInfo = C_PlayerInfo
	if (type(unit) ~= "string" or IsSecret(unit)) then return end
	if (not playerInfo or type(playerInfo.GetPlayerMythicPlusRatingSummary) ~= "function") then return end

	local ok, summary = pcall(playerInfo.GetPlayerMythicPlusRatingSummary, unit)
	if (not ok or type(summary) ~= "table" or IsSecret(summary)) then return end

	local score = summary.currentSeasonScore
	if (IsSecret(score) or type(score) ~= "number" or score <= 0) then return end

	local color
	local challengeMode = C_ChallengeMode
	if (challengeMode and type(challengeMode.GetDungeonScoreRarityColor) == "function") then
		local okColor, result = pcall(challengeMode.GetDungeonScoreRarityColor, score)
		if (okColor and type(result) == "table" and not IsSecret(result)) then
			color = result
		end
	end
	return score, color
end

-- Global API
---------------------------------------------------------
API.CreateFrameUnscaled = CreateFrameUnscaled
API.GetMythicPlusRating = GetMythicPlusRating
API.IsHouseEditorActive = IsHouseEditorActive
API.IsPlayerAtEffectiveMaxLevel = IsPlayerAtEffectiveMaxLevel
API.IsLevelAtEffectiveMaxLevel = IsLevelAtEffectiveMaxLevel
API.GetSafeLevel = GetSafeLevel
API.GetEffectiveMaxLevel = GetEffectiveMaxLevel
API.GetLevelTier = GetLevelTier
API.IsUnitCritterType = IsUnitCritterType
