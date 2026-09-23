-- In-memory mutations: never edits addon files or the working tree.
-- lua Tools/Harness/mutate_client.lua .
local root = arg[1] or "."
local originalLoadfile = loadfile
local cases = {
	{"client detection", "Core/Client.lua", "ns.Private.IsForever = forever and true or false", "ns.Private.IsForever = false"},
	{"modern engine", "Core/Client.lua", "ns.Private.IsRetail = ns.Private.IsMainline", "ns.Private.IsRetail = false"},
	{"API aliases", "Core/Compatibility.lua", "if (C_Spell and C_SpellBook and C_Reputation) then", "if (false) then"},
	{"secret tuple", "Core/Compatibility.lua", "local hasSecretValues = ns.HasSecretValues", "local hasSecretValues = false"},
	{"arena gate", "Components/UnitFrames/Units/Arena.lua", "if (ns.IsForever) then return end", ""},
	{"arena bootstrap", "WoW11/UnitFrames/ArenaFrames.lua", "not ns.WoW11 or ns.IsForever", "not ns.WoW11"},
	{"inspect gate", "Components/UnitFrames/GroupSpecCache.lua", "ticker or ns.IsForever or", "ticker or"},
	{"class resource gate", "Libs/oUF/elements/classpower.lua", "if(ns.IsForever and playerClass", "if(false and playerClass"},
	{"menu game rules", "Components/ActionBars/Elements/MicroMenu.lua", "and not disabled and not", "and not"},
	{"menu callbacks", "Components/ActionBars/Elements/MicroMenu.lua", "info.callback and info.callback()", "false"},
	{"event validation", "Libs/oUF/private.lua", "return C_EventUtils.IsEventValid(event)", "return true"},
	{"snippet probe", "Core/Client.lua", "\treturn ran\nend", "\treturn true\nend"},
	-- Without the pcall the error escapes and takes the rest of Core/Client.lua with
	-- it, which is exactly what happened on Forever 1.60.1.69913.
	{"snippet probe containment", "Core/Client.lua",
		'pcall(probe.SetAttribute, probe, "state-azsnippetprobe", "run")',
		'probe:SetAttribute("state-azsnippetprobe", "run")'},
	{"snippet probe scope", "Core/Client.lua",
		'if (not isAddOnLoaded("Blizzard_RestrictedAddOnEnvironment")) then return true end',
		'if (false) then return true end'},
	{"Forever probe bypass", "Core/Client.lua", "if (forever) then", "if (false) then"},
	{"numeric page driver", "Components/ActionBars/Prototypes/ActionBar.lua",
		"statedriver = BuildConditionalDriver(conditions, fallback, function(page) return page end)", ""},
	{"per-button action driver", "Components/ActionBars/Prototypes/ActionBar.lua",
		"\t\tself:UpdateActionDrivers()", ""},
	{"native visibility driver", "Components/ActionBars/Prototypes/ActionBar.lua",
		'API.RegisterVisibilityDriver(self, visdriver or "hide")', ""},
	{"non-paging bar guard", "Components/ActionBars/Prototypes/ActionBar.lua",
		"\tif (not conditions) then return end", ""},
	-- An entry whose native button Blizzard has gated must grey out, or it looks
	-- live and swallows the press - which is how Talents and Legacy read at level 1.
	{"micro menu gating", "Components/ActionBars/Elements/MicroMenu.lua",
		"local usable = IsNativeButtonUsable(button.ref)", "local usable = true"},
	-- Trusting a cache from another build would keep a stale "available" answer
	-- across the very patch that changed it.
	{"snippet cache build match", "Core/Client.lua",
		"cached.build == currentBuild and ", ""},
	-- Forever combo points are secret; each break below leaves them invisible or throws.
	{"secret point fill", "Libs/oUF/elements/classpower.lua",
		"element[i]:SetValue(cur)\n", "", "combo_points_harness.lua"},
	{"secret max fallback", "Libs/oUF/elements/classpower.lua",
		"(IsSecretValue and IsSecretValue(max)) or max <= 0",
		"(not (IsSecretValue and IsSecretValue(max)) and max <= 0)", "combo_points_harness.lua"},
	{"secret range restore", "Libs/oUF/elements/classpower.lua",
		"element[i]:SetMinMaxValues(0, 1)", "", "combo_points_harness.lua"},
	{"secret hide at zero", "Components/UnitFrames/Units/PlayerClassPower.lua",
		"hideAtZero and not isSecretCur and cur <= 0", "hideAtZero and cur <= 0", "combo_points_harness.lua"},
	{"secret point alpha", "Components/UnitFrames/Units/PlayerClassPower.lua",
		"elseif (isSecretCur) then", "elseif (false) then", "combo_points_harness.lua"},
	{"secret full fade option", "Components/UnitFrames/Units/PlayerClassPower.lua",
		"not element.inCombat and not showFullOutOfCombat)", "not element.inCombat)", "combo_points_harness.lua"},
	{"secret empty socket", "Components/UnitFrames/Units/PlayerClassPower.lua",
		"curve:AddPoint(.5 / max, .5)", "", "combo_points_harness.lua"},
	{"secret half-step threshold", "Components/UnitFrames/Units/PlayerClassPower.lua",
		"curve:AddPoint((index - .5) / max, 1)", "curve:AddPoint(index / max, 1)", "combo_points_harness.lua"},
	{"secret path Forever only", "Libs/oUF/elements/classpower.lua",
		"local isSecretCur = GetTargetComboPoints and (type(cur)", "local isSecretCur = (type(cur)",
		"combo_points_harness.lua"},
	-- Hide the Blizzard Tracker. The tracker is hidden by alpha, so anything that asserts
	-- the alpha instead of deriving it shows a tracker the player switched off.
	{"tracker alpha at prepare", "Components/Misc/TrackerWoW11.lua",
		"SetClampedToScreen(false)\n\tUpdateTrackerAlpha()",
		"SetClampedToScreen(false)\n\tObjectiveTrackerFrame:SetAlpha(.9)", "tracker_harness.lua"},
	{"tracker alpha on events", "Components/Misc/TrackerWoW11.lua",
		"event == \"SETTINGS_LOADED\") then\n\t\tself:UpdateSettings()",
		"event == \"SETTINGS_LOADED\") then\n\t\tself:UpdateSettings()\n\t\tObjectiveTrackerFrame:SetAlpha(.9)",
		"tracker_harness.lua"},
	{"tracker alpha re-derived on settings", "Components/Misc/TrackerWoW11.lua",
		"\tself:UpdateAutoHideDriver()\n\tUpdateTrackerAlpha()\nend", "\tself:UpdateAutoHideDriver()\nend",
		"tracker_harness.lua"},
	{"tracker hider OnHide", "Components/Misc/TrackerWoW11.lua",
		"SetScript(\"OnHide\", UpdateTrackerAlpha)", "SetScript(\"OnHide\", function() end)", "tracker_harness.lua"},
	-- The Retail break that shipped: the setting never reached the driver.
	{"tracker Retail driver folds the setting", "Components/Misc/TrackerWoW11.lua",
		"RegisterStateDriver(autoHider, \"vis\", driver)",
		"RegisterStateDriver(autoHider, \"vis\", GetAutoHideDriver())", "tracker_harness.lua"},
	{"tracker Forever driver folds the setting", "Components/Misc/TrackerWoW11.lua",
		"RegisterVisibilityDriver(autoHider, driver)",
		"RegisterVisibilityDriver(autoHider, GetAutoHideDriver())", "tracker_harness.lua"},
	{"tracker driver combat deferral", "Components/Misc/TrackerWoW11.lua",
		"\tif (InCombatLockdown()) then\n\t\tself:QueueCombatRefresh()\n\t\treturn false\n\tend\n\n\tlocal disabled",
		"\tlocal disabled", "tracker_harness.lua"},
	{"tracker combat refresh applies", "Components/Misc/TrackerWoW11.lua",
		"self:PrepareFrames()\n\t\t\tself:UpdateSettings()", "self:PrepareFrames()", "tracker_harness.lua"},
	{"tracker combat refresh unregisters", "Components/Misc/TrackerWoW11.lua",
		"self:UnregisterEvent(\"PLAYER_REGEN_ENABLED\", \"OnEvent\")", "", "tracker_harness.lua"},
	{"tracker snippet gate", "Components/Misc/TrackerWoW11.lua",
		"local hasSecureSnippets = ns.HasSecureSnippets ~= false", "local hasSecureSnippets = true",
		"tracker_harness.lua"},
	{"tracker Immersion open", "Components/Misc/TrackerWoW11.lua",
		" or (ImmersionFrame and ImmersionFrame:IsShown())", "", "tracker_harness.lua"},
	{"tracker Immersion close", "Components/Misc/TrackerWoW11.lua",
		"SecureHookScript(ImmersionFrame, \"OnHide\", UpdateTrackerAlpha)",
		"SecureHookScript(ImmersionFrame, \"OnHide\", function() ObjectiveTrackerFrame:SetAlpha(.9) end)",
		"tracker_harness.lua"},
	-- Locales. A missing key falls back to English; a moved specifier formats the wrong value,
	-- or raises, because Lua 5.1's string.format has no positional arguments.
	{"locale missing key", "Locale/deDE.lua",
		"L[\"Search settings\"] = \"Einstellungen durchsuchen\"", "", "locale_harness.lua"},
	{"locale specifier order", "Locale/deDE.lua",
		"\"%d von %d Einstellungen\"", "\"%s von %d Einstellungen\"", "locale_harness.lua"},
	{"locale duplicate key", "Locale/frFR.lua",
		"L[\"Not bound\"] = \"Non assigné\"",
		"L[\"Not bound\"] = \"Non assigné\"\nL[\"Not bound\"] = \"Non assigné\"", "locale_harness.lua"},
	{"locale empty value", "Locale/zhCN.lua", "= \"搜索设置\"", "= \"\"", "locale_harness.lua"},
	{"locale explanation width", "Locale/deDE.lua", "= \"Gilt für alle Aktionsleisten.\"",
		"= \"Gilt für jede einzelne Aktionsleiste, die AzeriteUI zeichnet, und für alle ihre Tasten.\"",
		"locale_harness.lua"},
	{"locale tab width", "Locale/ruRU.lua", "L[\"Options\"] = \"Параметры\"",
		"L[\"Options\"] = \"Параметры интерфейса\"", "locale_harness.lua"}
}
local function harnessFor(case)
	return root .. "/Tools/Harness/" .. (case[5] or "client_harness.lua")
end
assert(originalLoadfile(root .. "/Tools/Harness/client_harness.lua"))()
assert(originalLoadfile(root .. "/Tools/Harness/combo_points_harness.lua"))()
assert(originalLoadfile(root .. "/Tools/Harness/tracker_harness.lua"))()
assert(originalLoadfile(root .. "/Tools/Harness/locale_harness.lua"))()
for _, case in ipairs(cases) do
	local mutations = 0
	loadfile = function(path)
		if path:sub(-#case[2]) ~= case[2] then return originalLoadfile(path) end
		local file = assert(io.open(path, "r"))
		local source = file:read("*a")
		file:close()
		local first, last = source:find(case[3], 1, true)
		assert(first, "mutation target missing: " .. case[1])
		mutations = mutations + 1
		return loadstring(source:sub(1, first - 1) .. case[4] .. source:sub(last + 1), "@" .. path)
	end
	local ok, err = pcall(assert(originalLoadfile(harnessFor(case))))
	loadfile = originalLoadfile
	assert(mutations > 0, "mutation was not applied: " .. case[1])
	assert(not ok, "mutation survived: " .. case[1])
	print("Caught " .. case[1] .. ": " .. tostring(err))
end
print("Client mutations: " .. #cases .. " caught; no files modified")
