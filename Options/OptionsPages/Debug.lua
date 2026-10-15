-- Maintainer controls use the same rows, sections and theme as /az.
-- Scratch input is session-only. Opening/closing the page never starts/stops tests.
local Addon, ns = ...
local L = LibStub("AceLocale-3.0"):GetLocale(Addon)
local Options = ns:GetModule("Options")
local Kit = ns.OptionsKit
local spell = ns.IsForever and "" or "6940"
local preset = "manual"
local inputs = { nameplate = "auto", snapshot = "target", secret = "player", button = "", hold = "" }
local function Debug() return ns:GetModule("Debugging", true) end
-- The tools are a load-on-demand companion (Core/DebugLoader.lua). Actions load it the
-- first time one is used; showing this page never does.
local function LoadDebug()
	if (ns.LoadDebugTools) then return (ns.LoadDebugTools()) end
	return Debug()
end
local function Dev() return ns.db and ns.db.global and ns.db.global.enableDevelopmentMode and true or false end
local function OOC()
	if (type(issecretvalue) ~= "function" or type(InCombatLockdown) ~= "function") then return false end
	local combat = InCombatLockdown()
	return not issecretvalue(combat) and combat == false
end
local function Capable()
	return C_Spell and type(C_Spell.GetSpellCooldownDuration) == "function" and type(issecretvalue) == "function"
end
-- Preview and inspect drive the Cooldown Manager's ready alerts; without them
-- the buttons would do nothing, so they are hidden.
local function HasReadyAlerts()
	local module = ns:GetModule("CooldownManager", true)
	return module and type(module.DebugReadyAlerts) == "function" or false
end
local function ValidID(value)
	local id = tonumber(value)
	return id and id > 0 and id < math.huge and id % 1 == 0
end
local function Command(value)
	local debug = Dev() and LoadDebug()
	if (Dev() and debug) then debug:DebugMenu(value) end
end
local function Probe(value)
	-- Stopping needs no load: nothing can be running before the tools are loaded.
	local debug
	if (value == "off") then debug = Debug() elseif (Dev()) then debug = LoadDebug() end
	if (debug and (value == "off" or Dev())) then debug:CooldownReadyProbe(value) end
end
local function Immediate(option)
	if (Kit and Kit.Combat) then Kit.Combat:AllowImmediate(option) end
	return option
end
local function Action(label, order, command, disabled)
	return { name = L[label], type = "execute", order = order, desc = "/azdebug " .. command,
		disabled = disabled or function() return not Dev() end, func = function() Command(command) end }
end
local function Input(label, order, key)
	return Immediate({ name = L[label], type = "input", order = order,
		get = function() return inputs[key] end, set = function(_, value) inputs[key] = value end })
end
local function DynamicAction(label, order, prefix, key)
	local option = Action(label, order, prefix)
	option.func = function()
		local value = inputs[key]
		if (prefix == "nameplates" and value:lower() == "auto") then value = "" end
		Command(prefix .. " " .. value)
	end
	return option
end
local function Toggle(label, order, command, get)
	return { name = L[label], type = "toggle", order = order, get = get,
		disabled = function() return not Dev() end,
		set = function(_, value) Command(command .. (value and " on" or " off")) end }
end

-- Refresh only while this page is visible and only when owned probe/dev/combat
-- state changes. No frame or timer exists until the page is first rendered.
local watcher
local function Watch()
	if (watcher or not Kit.Panel or not Kit.Panel:IsShown() or Kit.Panel.selected ~= L["Debug tools"]) then return end
	watcher = CreateFrame("Frame", nil, Kit.Panel and Kit.Panel.frame)
	local elapsed, last = 0
	watcher:SetScript("OnUpdate", function(_, dt)
		local panel = Kit.Panel
		if (not panel or not panel:IsShown() or panel.selected ~= L["Debug tools"] or panel.tab ~= "options") then return end
		elapsed = elapsed + dt
		if (elapsed < .2) then return end
		elapsed = 0
		local debug = Debug()
		local active, id = false, nil
		if (debug) then active, id = debug:GetCooldownProbeState() end
		local state = tostring(Dev()) .. tostring(OOC()) .. tostring(Capable() and true or false) .. tostring(active) .. tostring(id)
		if (state ~= last) then last = state; panel.page:Refresh() end
	end)
end
-- Smooth bars preview: two copies of the player's health bar (the max-level art,
-- hp_cap_bar in hp_cap_case) taking the same hits and heals, one eased and one snapping,
-- so the difference can be judged without a fight. Plain StatusBars, nothing secret,
-- nothing secure; built on first use and stopped while hidden.
local smoothPreview
local PREVIEW_SCALE = .6
local PREVIEW_STEPS = { 100, 38, 52, 12, 90, 70, 100, 5, 100, 82, 76, 100 }
local function SmoothPreviewRow(parent, text, y)
	local GetMedia = ns.API.GetMedia
	local row = CreateFrame("Frame", nil, parent)
	row:SetSize(716 * PREVIEW_SCALE, 188 * PREVIEW_SCALE)
	row:SetPoint("TOP", parent, "TOP", 0, y)
	local label = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	label:SetPoint("TOPLEFT", row, "TOPLEFT", 8, -2)
	label:SetText(text)
	local bar = CreateFrame("StatusBar", nil, row)
	bar:SetSize(385 * PREVIEW_SCALE, 40 * PREVIEW_SCALE)
	-- Where the player frame puts the bar inside its case: (148, 27) against (-17, -48).
	bar:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", (148 + 17) * PREVIEW_SCALE, (27 + 48) * PREVIEW_SCALE)
	bar:SetStatusBarTexture(GetMedia("hp_cap_bar"))
	local health = ns.Colors and ns.Colors.health
	if (health) then bar:SetStatusBarColor(health[1], health[2], health[3]) end
	bar:SetMinMaxValues(0, 100)
	bar:SetValue(100)
	local case = row:CreateTexture(nil, "BACKGROUND", nil, 1)
	case:SetAllPoints(row)
	case:SetTexture(GetMedia("hp_cap_case"))
	local ui = ns.Colors and ns.Colors.ui
	if (ui) then case:SetVertexColor(ui[1], ui[2], ui[3]) end
	local value = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	value:SetPoint("RIGHT", bar, "RIGHT", -8, 0)
	row.bar, row.value = bar, value
	return row
end

local function ToggleSmoothPreview()
	if (smoothPreview) then
		smoothPreview:SetShown(not smoothPreview:IsShown())
		return
	end
	local frame = CreateFrame("Frame", ns.Prefix .. "SmoothBarsPreview", UIParent, ns.BackdropTemplate)
	frame:SetSize(716 * PREVIEW_SCALE + 40, 188 * PREVIEW_SCALE * 2 + 90)
	frame:SetPoint("CENTER", UIParent, "CENTER", 0, 120)
	frame:SetFrameStrata("DIALOG")
	frame:SetClampedToScreen(true)
	frame:EnableMouse(true)
	frame:SetMovable(true)
	frame:RegisterForDrag("LeftButton")
	frame:SetScript("OnDragStart", frame.StartMoving)
	frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
	if (Kit and Kit.WindowFill) then
		frame:SetBackdrop(Kit.WindowFill)
		local c = Kit.WindowColor or {}
		frame:SetBackdropColor(c[1] or .05, c[2] or .04, c[3] or .03, 1)
		local outset = Kit.WindowOutset
		local casing = CreateFrame("Frame", nil, frame, ns.BackdropTemplate)
		casing:SetPoint("TOPLEFT", frame, "TOPLEFT", -outset.left, outset.top)
		casing:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", outset.right, -outset.bottom)
		casing:SetBackdrop(Kit.WindowCasing)
		casing:SetFrameLevel(frame:GetFrameLevel() + 20)
		casing:EnableMouse(false)
	end
	UISpecialFrames[#UISpecialFrames + 1] = frame:GetName()
	local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	title:SetPoint("TOP", frame, "TOP", 0, -14)
	title:SetText(L["Smooth bars preview"])
	local note = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	note:SetPoint("TOP", title, "BOTTOM", 0, -4)
	note:SetText(L["Both bars get the same hits and heals, big and small, every 1.4 seconds."])
	local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
	close:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -2, -2)
	local eased = SmoothPreviewRow(frame, L["Eased"], -46)
	local snaps = SmoothPreviewRow(frame, L["Snaps"], -46 - 188 * PREVIEW_SCALE)
	local EASED = (Enum and Enum.StatusBarInterpolation and Enum.StatusBarInterpolation.ExponentialEaseOut) or 1
	local IMMEDIATE = (Enum and Enum.StatusBarInterpolation and Enum.StatusBarInterpolation.Immediate) or 0
	local step, ticker = 0, nil
	local function Next()
		step = step % #PREVIEW_STEPS + 1
		local v = PREVIEW_STEPS[step]
		pcall(eased.bar.SetValue, eased.bar, v, EASED)
		pcall(snaps.bar.SetValue, snaps.bar, v, IMMEDIATE)
		eased.value:SetFormattedText("%d%%", v)
		snaps.value:SetFormattedText("%d%%", v)
	end
	frame:SetScript("OnShow", function()
		if (not ticker and C_Timer and C_Timer.NewTicker) then ticker = C_Timer.NewTicker(1.4, Next) end
	end)
	frame:SetScript("OnHide", function()
		if (ticker) then ticker:Cancel(); ticker = nil end
	end)
	smoothPreview = frame
	frame:Hide()
	frame:Show()
end

local function GenerateOptions()
	local cooldown = { type = "group", name = L["Cooldown tests"], order = 1, args = {} }
	local a = cooldown.args
	a.instructions = { type = "description", order = 1, name = function()
		Watch()
		return L["Select a spell on your active action bar and start out of combat. Cast normally and wait for the real icon to recover. Restart after bar or talent changes; closing this window leaves the test running."]
	end }
	a.hint = { type = "description", order = 2, name = function()
		return not Dev() and L["Enable Development Mode to use these tests."]
			or not Capable() and L["This client lacks the APIs required for the cooldown probe."]
			or ns.IsForever and L["Retail presets are disabled on Forever. Enter a spell ID verified on this client. Preview and inspect require out of combat."]
			or L["Preview and inspect require out of combat. Presets only select an ID; cast the learned spell yourself."]
	end }
	a.output = { type = "description", order = 2.5, name = L["Output is written to _DebugLog -> AzeriteUI when available; otherwise to chat."] }
	a.preset = Immediate({ type = "select", name = L["Paladin preset"], order = 3,
		values = { manual = L["Manual spell ID"], ["6940"] = L["Blessing of Sacrifice"], ["403876"] = L["Divine Protection"], ["20271"] = L["Judgment"] },
		sorting = { "manual", "6940", "403876", "20271" },
		disabled = function() return not Dev() or ns.IsForever end,
		get = function() return preset end,
		set = function(_, value)
			if (not Dev() or ns.IsForever) then return end
			preset = value
			if (value ~= "manual") then spell = value end
		end })
	a.spell = Immediate({ type = "input", name = L["Spell ID"], order = 4,
		get = function() return spell end, set = function(_, value) spell = value; preset = "manual" end })
	a.state = { type = "description", order = 5, name = function()
		local debug = Debug()
		local active, id = false, nil
		if (debug) then active, id = debug:GetCooldownProbeState() end
		-- A probe can be active before its spell ID is known; %d would raise on nil.
		return (active and type(id) == "number") and string.format(L["Test running: spell %d"], id) or L["Test stopped"]
	end }
	a.start = Immediate({ type = "execute", name = L["Start / restart"], order = 6,
		disabled = function() return not Dev() or not Capable() or not ValidID(spell) end,
		func = function() if (Capable() and ValidID(spell)) then Probe(spell) end end })
	a.status = Immediate({ type = "execute", name = L["Print status"], order = 7,
		disabled = function() return not Dev() end, func = function() Probe("status") end })
	a.stop = Immediate({ type = "execute", name = L["Stop test"], order = 8, func = function() Probe("off") end })
	a.preview = Immediate({ type = "execute", name = L["Preview flash"], order = 9,
		hidden = function() return not HasReadyAlerts() end,
		disabled = function() return not Dev() or not OOC() end,
		func = function() if (OOC()) then Probe("preview") end end })
	a.inspect = Immediate({ type = "execute", name = L["Inspect icons"], order = 10,
		hidden = function() return not HasReadyAlerts() end,
		disabled = function() return not Dev() or not OOC() end,
		func = function() if (OOC()) then Probe("inspect") end end })
	a.result = { type = "description", order = 11, name = L["Compare the source rows in _DebugLog (AzeriteUI), including action-slot and resolved-spell timers. A valid timer is shown during the real cooldown and hidden at recovery; a GCD-only change is not a pass."] }

	local health = { type = "group", name = L["Health and unit frames"], order = 2, args = {
		health = Toggle("Health debug", 1, "health", function() return ns.API.DEBUG_HEALTH and true or false end),
		chat = Toggle("Health debug chat", 2, "healthchat", function() return ns.API.DEBUG_HEALTH_CHAT and true or false end),
		bars = Toggle("Statusbar/orb debug", 3, "bars", function() return _G.__AzeriteUI_DEBUG_BARS and true or false end),
		fixes = Toggle("Blizzard fixes debug", 4, "fixes", function() return ns.db.global.debugFixes and true or false end),
		filter = { type = "input", name = L["Health filter prefix"], order = 5, disabled = function() return not Dev() end,
			get = function() return ns.API.DEBUG_HEALTH_FILTER or "Target." end,
			set = function(_, value) Command("health filter " .. (value ~= "" and value or "Target.")) end },
		reset = Action("Reset filter", 6, "health filter Target."),
		dumpTarget = Action("Dump target bars", 10, "dump target"), dumpPlayer = Action("Dump player bars", 11, "dump player"),
		dumpToT = Action("Dump ToT bars", 12, "dump tot"), dumpAll = Action("Dump all bars", 13, "dump all"),
		nameplate = Input("Nameplate unit", 20, "nameplate"), cast = DynamicAction("Inspect nameplate cast", 21, "nameplates", "nameplate"),
		scale = DynamicAction("Inspect nameplate scale", 22, "scale nameplates", "nameplate"),
		allPlates = Action("All nameplates", 23, "nameplates"), autoScale = Action("Auto nameplate scale", 24, "scale nameplates auto"),
		unit = Input("Snapshot unit", 25, "snapshot"), snapshot = DynamicAction("Snapshot", 26, "snapshot", "snapshot"),
		targetMenu = { type = "execute", name = L["Target debug menu"], order = 27, disabled = function() return not Dev() end,
			func = function() local debug = Dev() and LoadDebug(); if (debug) then debug:ToggleTargetDebugMenu() end end },
		repairHint = { type = "description", name = L["Repairs reattach movement handles. Frame changes wait until combat ends."], order = 30 }
	} }
	for i, unit in ipairs({ "PlayerFrame", "TargetFrame" }) do
		local label = i == 1 and "Reattach player bars" or "Reattach target bars"
		health.args[unit] = { type = "execute", name = L[label], order = 30 + i,
			disabled = function() return not Dev() end, func = function()
				local debug = Dev() and LoadDebug(); if (debug) then debug:ReattachDebugBars(unit) end
			end }
	end
	local keys = { type = "group", name = L["Keybindings"], order = 3, args = {
		verbose = Toggle("Verbose", 1, "keys", function() return ns.db.global.debugKeysVerbose and true or false end),
		status = Action("Print status", 2, "keys status"), bindings = Action("Bindings", 3, "keys bindings"),
		button = Input("Button name", 4, "button"), cooldown = DynamicAction("Inspect button cooldown", 5, "keys cooldown", "button"),
		spell = Input("Spell ID", 6, "hold"), hold = DynamicAction("Hold test", 7, "keys holdtest", "hold")
	} }
	local raid = { type = "group", name = L["Raid utility bar"], order = 4, args = {
		hint = { type = "description", order = 1, name = L["Solo force-show is a temporary debug override. The normal raid bar setting stays on the Unit Frames page. Reload if Blizzard already hid the bar." ] },
		on = Action("Force on", 2, "raidbar on"), off = Action("Force off", 3, "raidbar off"),
		toggle = Action("Toggle", 4, "raidbar toggle"), status = Action("Print status", 5, "raidbar status")
	} }
	local utilities = { type = "group", name = L["Utilities"], order = 5, args = {
		status = Action("Print status", 1, "status"), help = Action("Help", 2, "help"),
		blizzard = Action("Enable Blizzard addons", 3, "blizzard enable"), errors = Action("Enable script errors", 4, "scripterrors"),
		scale = Action("Scale status", 5, "scale"), reset = Action("Reset unit frame scales", 6, "scale reset"),
		unit = Input("Secret test unit", 7, "secret"), secret = DynamicAction("Run secret test", 8, "secrettest", "secret")
	} }
	-- Eased bars, switched while you fight (UnitFrame.lua). Not tied to Development Mode:
	-- these are the same two player settings as on the Unit Frames page.
	local function SmoothState(kind)
		return ns.UnitFrame and ns.UnitFrame.IsSmoothingEnabled(kind) and "|cff00ff00ON|r" or "|cffff4040OFF|r"
	end
	local function SetSmooth(kind, enabled)
		if (ns.UnitFrame) then ns.UnitFrame.SetSmoothingEnabled(kind, enabled) end
	end
	local smooth = { type = "group", name = L["Smooth bars"], order = 6, args = {
		hint = { type = "description", order = 1, name = L["Switch eased bars while you fight to compare them side by side. The same two settings as on the Unit Frames page; /azsmooth [on|off] [bars|cast] does it from chat."] },
		state = { type = "description", order = 2, fontSize = "medium", name = function()
			return string.format(L["Health and power: %s   Castbar pushback: %s"], SmoothState("bars"), SmoothState("castbars"))
		end },
		bars = Immediate({ type = "toggle", order = 3, width = "full", name = L["Smooth health and power"],
			get = function() return ns.UnitFrame and ns.UnitFrame.IsSmoothingEnabled("bars") end,
			set = function(_, value) SetSmooth("bars", value) end }),
		cast = Immediate({ type = "toggle", order = 4, width = "full", name = L["Smooth castbar pushback"],
			get = function() return ns.UnitFrame and ns.UnitFrame.IsSmoothingEnabled("castbars") end,
			set = function(_, value) SetSmooth("castbars", value) end }),
		allOn = Immediate({ type = "execute", order = 5, name = L["All on"], func = function() SetSmooth(nil, true) end }),
		allOff = Immediate({ type = "execute", order = 6, name = L["All off"], func = function() SetSmooth(nil, false) end }),
		flip = Immediate({ type = "execute", order = 7, name = L["Flip both"], desc = "/azsmooth",
			func = function()
				local on = ns.UnitFrame and ns.UnitFrame.IsSmoothingEnabled("bars")
				SetSmooth(nil, not on)
			end }),
		preview = Immediate({ type = "execute", order = 8, name = L["Toggle preview"],
			desc = L["Both bars get the same hits and heals, big and small, every 1.4 seconds."],
			func = function() ToggleSmoothPreview() end })
	} }
	return { name = L["Debug tools"], type = "group", desc = L["Maintainer tests and diagnostics. Select a section in the sidebar; nothing starts automatically."],
		args = { cooldown = cooldown, health = health, keys = keys, raid = raid, utilities = utilities, smooth = smooth } }
end
Options:AddGroup(L["Debug tools"], GenerateOptions, -2900, "other")
