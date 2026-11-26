-- Presentation rules for the main options window. Keys are the untranslated
-- option paths. AceConfig consumers and the structural collectors share no filter.
local Addon, ns = ...
local Kit = ns.OptionsKit
local Config = Kit.Config
local Advanced = {}
Kit.Advanced = Advanced

-- A key can identify a row or an entire option group.
local rules = {
	["Themes"] = [[endcapScale endcapX endcapY resetEndcap castEndcapScale castEndcapX castEndcapY resetCastEndcap
		strength orbStrength particles speed Crystal Orb]],
	["Explorer Mode"] = [[explorermodedelayspacer explorerermodedelaydesc
		delayOnLogin delayOnReload delayOnZoning delayOnCombatEnd
		fadeWithLowHealth fadeThresholdHealth fadeThresholdHealthspacer
		fadeWithLowMana fadeThresholdMana fadeThresholdManaspacer fadeThresholdManaInForms fadeThresholdManaInFormsspacer
		fadeInGroups fadeInInstances fadeInMythicPlus fadeWithFriendlyTarget fadeWithHostileTarget
		fadeWithDeadTarget fadeWithFocusTarget fadeInVehicles]],
	["Unit Frames"] = [[castOverlayCustomColor castOverlayColor castOverlayOpacity smoothBars smoothCastbars absorbDisplayMode
		PowerValueFormat powerValueTextScale playerPowerValueAlpha targetPowerValueAlpha powerValueCombatDriven
		playerAuraUseStockBehavior playerAuraAlwaysBright playerAuraShowImportantAuras playerAuraShowRaidAuras
		playerAuraShowImportantStealable playerAuraShowShortCombatPlayerBuffs playerAuraShowNameplateAuras
		playerAuraShowShortBuffsInCombat playerAuraMaxDuration playerAuraShowLongUtilityBuffs playerAuraMaxShown
		playerAuraSeparateDebuffsMax AurasMaxCols AuraSize AurasSpacingX AurasSpacingY AurasGrowthX AurasGrowthY
		AurasInitialAnchor pvpIndicatorOffsetX pvpIndicatorOffsetY pvpIndicatorReset]],
	["Group Frames"] = [[useInParties useInRaid5 useInRaid10 useInRaid25 useInRaid40 sortBy sortDir
		useClassColors useBlizzardHealthColors useClassColorOnMouseoverOnly rangeIndicatorRange
		partyAuraUseStockBehavior partyAuraShowDispellableDebuffs partyAuraOnlyDispellableDebuffs
		partyAuraShowBossAndImportantDebuffs partyAuraShowOtherDebuffs partyAuraShowHelpfulExternals
		partyAuraShowHelpfulRaidBuffs partyAuraShowHelpfulShortBuffs AuraSize AurasMaxCols partyAuraDebuffSize
		partyAuraRowGap AurasGrowthX AurasGrowthY priorityDebuffScale groupCornerOnlyMine groupCornerSize
		suggestions groupCornerSpellsTOPLEFT groupCornerSpellsTOPRIGHT groupCornerSpellsBOTTOMLEFT
		groupCornerSpellsBOTTOMRIGHT markerHelp marker1 marker2 marker3 marker4 marker5 marker6 marker7 marker8]],
	["Nameplates"] = [[auraFilters fading contentSettings targetOnly otherFights instanceFriendly tank
		ownStackingBounds stackMotionSpeed castBarOffsetY platePosition threatColorPreset threatColorDescription
		friendlyScale friendlyNPCScale enemyScale friendlyTargetScale nameplateTargetScale raidTargetSize raidTargetNameOnlySize
		comboPointScale nameOnlyHealthThreshold friendlyNameOnlyFontScale friendlyNameOnlyTargetScale]],
	["Execute range"] = "executeLead colors",
	["Enemy Casts"] = "maxRows previewCasts width growUp",
	["Auras"] = "ignoreTarget anchorPoint anchorPointSpace growthX growthY growthSpace paddingX paddingY",
	["Action Bars"] = [[fadeFrom fadeAlone startAt padding breakpadding
		procHighlightColorSource procHighlightColor procHighlightThickness procHighlightOpacity
		assistedHighlightColorSource assistedHighlightColor assistedHighlightThickness assistedHighlightOpacity]],
	["Cooldown Manager"] = "readySound soundUnavailable",
	["Minimap"] = "dismountbutton",
	["Chat"] = "timeVisible timeFading timeClearing",
	["Bags"] = "sort insert space1 space2 autoRepairGuild lootRollClassTheme",
	["Tooltips"] = [[theme nameplateUnitTransparency hideActionBarTooltipsInCombat
		hideUnitFrameTooltipsInCombat showItemID showSpellID anchor anchorToCursor]],
	["GuildManager"] = [[nicknameLevels inactiveDays blizzardGuildKey toggleKey
		guildFormat groupFormat whisperFormat otherFormat]],
	["MythicPlus"] = "autoSlotKeystone"
}

for page, keys in pairs(rules) do
	local lookup = {}
	for key in keys:gmatch("%S+") do lookup[key] = true end
	rules[page] = lookup
end

Advanced.IsEnabled = function()
	return ns.db and ns.db.global and ns.db.global.optionsShowAdvanced == true or false
end

Advanced.IsAdvanced = function(options, path, option)
	local lookup = rules[path[1]]
	if (not lookup) then return false end
	local key = path[#path]
	if (path[1] == "Action Bars" and key == "reset"
		and (path[2] == "procHighlight" or path[2] == "assistedHighlight")) then return true end
	if (path[1] == "Themes" and option.type == "range" and path[2] == "druid"
		and (key == "crystal" or key == "orb")) then return true end
	if (path[1] == "Execute range" and key == "executeThreshold") then
		local modePath = { path[1], "threshold", "executeThresholdMode" }
		local mode = Config.GetGroup(options, modePath)
		return mode and Config.GetValue(mode, options, modePath, Addon) ~= "custom"
	end
	if (path[1] == "Nameplates" and (key == "editedNameContext" or key == "nameRulesDescription")) then
		-- Keep the scope readable if the name editor was left on an override.
		local modePath = { path[1], "general", "names", "editedNameContext" }
		local mode = Config.GetGroup(options, modePath)
		return mode and Config.GetValue(mode, options, modePath, Addon) == "default"
	end
	for index = 2, #path do
		if (lookup[path[index]]) then return true end
	end
	return false
end
