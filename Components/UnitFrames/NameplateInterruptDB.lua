local _, ns = ...

ns.NameplateInterruptDB = ns.NameplateInterruptDB or {}
local DB = ns.NameplateInterruptDB

local UnitGUID = UnitGUID

local IsSecretValue = function(value)
	return issecretvalue and issecretvalue(value)
end

local EnsureStore = function()
	if (not ns.db or not ns.db.global) then
		return nil
	end

	local global = ns.db.global
	global.nameplateInterruptSpells = global.nameplateInterruptSpells or {
		platerImported = false,
		platerImportedAt = 0,
		platerImportedCount = 0,
		interruptible = {},
		protected = {}
	}
	return global.nameplateInterruptSpells
end

local function NormalizeSpellID(spellID)
	if (IsSecretValue(spellID) or type(spellID) ~= "number" or spellID <= 0) then
		return nil
	end
	return spellID
end

DB.LearnInterruptibleSpell = function(spellID)
	spellID = NormalizeSpellID(spellID)
	if (not spellID) then
		return false
	end

	local store = EnsureStore()
	if (not store) then
		return false
	end

	store.interruptible[spellID] = true
	return true
end

DB.SeedFromPlater = function()
	local store = EnsureStore()
	if (not store or store.platerImported) then
		return 0
	end

	local platerDB = _G.PlaterDB
	local interruptableSpells = platerDB and platerDB.InterruptableSpells
	if (type(interruptableSpells) ~= "table") then
		return 0
	end

	local importedCount = 0
	for spellID, value in next, interruptableSpells do
		if (value) then
			spellID = NormalizeSpellID(spellID)
			if (spellID) then
				if (not store.interruptible[spellID]) then
					importedCount = importedCount + 1
				end
				store.interruptible[spellID] = true
			end
		end
	end

	store.platerImported = true
	store.platerImportedAt = time and time() or 0
	store.platerImportedCount = importedCount
	return importedCount
end

DB.HasOwnedSeedData = function()
	local store = EnsureStore()
	if (not store) then
		return false
	end
	return next(store.interruptible) ~= nil or next(store.protected) ~= nil
end

DB.GetSpellIDForCastbar = function(castbar)
	local spellID = NormalizeSpellID(castbar and castbar.spellID)
	if (spellID) then
		return spellID
	end

	local owner = castbar and castbar.__owner
	local unit = owner and owner.unit
	if (type(unit) == "string" and unit ~= "" and (not IsSecretValue(unit))) then
		if (UnitCastingInfo) then
			local castResult = { pcall(UnitCastingInfo, unit) }
			local okCast = castResult[1]
			local castSpellID = castResult[10]
			spellID = okCast and NormalizeSpellID(castSpellID) or nil
			if (spellID) then
				return spellID
			end
		end

		if (UnitChannelInfo) then
			local channelResult = { pcall(UnitChannelInfo, unit) }
			local okChannel = channelResult[1]
			local channelSpellID = channelResult[9]
			spellID = okChannel and NormalizeSpellID(channelSpellID) or nil
			if (spellID) then
				return spellID
			end
		end
	end

	local guid = owner and owner.guid
	if (type(guid) ~= "string" or guid == "" or IsSecretValue(guid)) then
		guid = UnitGUID and unit and UnitGUID(unit) or nil
	end

	return nil
end

DB.GetFallbackStateForCastbar = function(castbar)
	local store = EnsureStore()
	if (not store) then
		return nil, nil, nil
	end

	local spellID = DB.GetSpellIDForCastbar(castbar)
	if (not spellID) then
		return nil, nil, nil
	end

	if (store.protected[spellID]) then
		return "protected", spellID, "manual-protected"
	end

	if (store.interruptible[spellID]) then
		return "interruptible", spellID, "interruptible-db"
	end

	return nil, spellID, nil
end
