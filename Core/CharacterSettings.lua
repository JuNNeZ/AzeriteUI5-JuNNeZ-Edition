local _, ns = ...

-- Forever's regional names identify characters within a ruleset even when
-- GetRealmName() is hidden. Two characters can still share a name across rulesets.
local function GetRuleset()
	local rules = Enum and Enum.GameRule
	local active = C_GameRules and C_GameRules.IsGameRuleActive
	if not (rules and active) then return end
	local pvp = rules.PvPRuleset and active(rules.PvPRuleset)
	local rp = rules.RPRuleset and active(rules.RPRuleset)
	if pvp then return rp and "RPPvP" or "PvP" end
	if rp then return "RP" end
	if rules.HardcoreRuleset and active(rules.HardcoreRuleset) then return "HC" end
	return "PvE"
end

local function CopyMissing(target, source)
	for key, value in pairs(source) do
		if type(value) == "table" then
			if target[key] == nil then target[key] = {} end
			if type(target[key]) == "table" then CopyMissing(target[key], value) end
		elseif target[key] == nil then
			target[key] = value
		end
	end
end

local function CopyCharacter(database, characterKey, sources)
	local chars = database.char
	local result = {}
	if type(chars) ~= "table" then return result end
	for _, key in ipairs(sources) do
		if type(chars[key]) == "table" then CopyMissing(result, chars[key]) end
	end
	if next(result) then chars[characterKey] = result end
	return result
end

local function GetLegacyKeys(sv, prefix, realm, characterKey, aliases)
	local named, ambiguous, exact, blank
	local current = prefix .. realm
	local function Scan(section)
		if type(section) ~= "table" then return end
		for key in pairs(section) do
			if type(key) == "string" and key:sub(1, #prefix) == prefix then
				if key == prefix then
					blank = key
				else
					if named and named ~= key then ambiguous = true end
					named = key
					if key == current then exact = key end
				end
			end
		end
	end
	Scan(sv.profileKeys)
	Scan(sv.char)
	for _, namespace in pairs(sv.namespaces or {}) do
		if type(namespace) == "table" then Scan(namespace.char) end
	end

	local older = exact or (realm == "" and not ambiguous and named)
	local sources = {}
	local function Add(key)
		if key and (not aliases[key] or aliases[key] == characterKey) then
			sources[#sources + 1] = key
			aliases[key] = characterKey
		end
	end
	-- A blank key only identifies the old character if there is no competing
	-- realm entry. Prefer explicit values saved under the currently active key.
	local useBlank = not ambiguous and (not named or (older and (not aliases[older] or aliases[older] == characterKey)))
	if realm == "" and useBlank then Add(blank) end
	Add(older)
	if realm ~= "" and useBlank then Add(blank) end
	return sources
end

ns.GetCharacterSettingsKey = function(self, sv, defaultProfile)
	if not (self.IsForever and RegionalUniqueNamesEnabled and RegionalUniqueNamesEnabled()) then return end
	local name, surname = UnitName("player")
	local ruleset = GetRuleset()
	if not (name and name ~= "" and surname and surname ~= "" and ruleset) then return end
	local characterKey = "Forever:" .. ruleset .. ":" .. name .. " " .. surname
	if type(sv) ~= "table" then return characterKey end

	local profiles = sv.profileKeys or {}
	-- AceDB writes the association even when the character uses all defaults.
	-- After the first load, a reset must never revive historical settings.
	if profiles[characterKey] then return characterKey end

	local aliases = sv.foreverCharacterAliases or {}
	local sources = GetLegacyKeys(sv, name .. " - ", GetRealmName() or "", characterKey, aliases)
	if #sources == 0 then return characterKey end
	sv.foreverCharacterAliases = aliases

	local char = CopyCharacter(sv, characterKey, sources)
	for _, namespace in pairs(sv.namespaces or {}) do
		if type(namespace) == "table" then CopyCharacter(namespace, characterKey, sources) end
	end

	local profile
	for _, key in ipairs(sources) do
		local saved = sv.char and sv.char[key]
		local selected = type(saved) == "table" and saved.profile
		if type(selected) ~= "string" or selected == "" then
			-- AceDB writes the default association even on a new, empty key.
			selected = profiles[key]
			if selected == defaultProfile then selected = nil end
		end
		if type(selected) == "string" and selected ~= "" then
			profile = selected
			break
		end
	end
	char.profile = profile
	if profile then
		sv.char = sv.char or {}
		sv.char[characterKey] = char
		sv.profileKeys = profiles
		profiles[characterKey] = profile
	end
	return characterKey
end
