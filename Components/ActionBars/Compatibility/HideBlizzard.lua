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

-- Blizzard's Edit Mode selection overlay ignores its parent's alpha and mouse state, so a
-- bar we fade to nothing can still be highlighted and dragged in Edit Mode. The overlay
-- is a plain child frame (not protected, not in the system registry), so hiding it from a
-- post-hook leaves registration, saved layouts and Blizzard's own selection logic alone.
local selectionHooked = setmetatable({}, { __mode = "k" })
local hidingSelection = setmetatable({}, { __mode = "k" })
ns.HideEditModeSelection = function(frame)
	local selection = frame and frame.Selection
	if (not selection or type(selection.Hide) ~= "function") then return end
	if (selectionHooked[selection]) then return end
	selectionHooked[selection] = true
	hooksecurefunc(selection, "Show", function(self)
		if (hidingSelection[self]) then return end
		hidingSelection[self] = true
		self:Hide()
		hidingSelection[self] = nil
	end)
	if (selection:IsShown()) then selection:Hide() end
end

-- Blizzard frames AzeriteUI replaces or hides outside the action bars. The module name
-- (when set) must be enabled, otherwise the player still needs Blizzard's overlay.
local EDIT_MODE_REPLACED = {
	{ "PersonalResourceDisplayFrame" },
	{ "MainStatusTrackingBarContainer" },
	{ "SecondaryStatusTrackingBarContainer" },
	{ "CompactArenaFrame" },
	{ "CompactRaidFrameContainer" },
	{ "BuffFrame", "Auras" },
	{ "DebuffFrame", "Auras" },
	{ "MinimapCluster", "Minimap" },
	{ "MainMenuBarVehicleLeaveButton", "VehicleExit" },
	-- PlayerCastBar.lua fades Blizzard's cast bar by alpha only; its overlay ignores that.
	{ "PlayerCastingBarFrame", "PlayerCastBarFrame" },
	-- Seen on Forever with /azdebug editmode (FixLog 2026-10-10); the same systems exist on Retail.
	{ "PartyFrame", "PartyFrames", "RaidFrame5" },
	{ "ExtraAbilityContainer", "ExtraActionButtons" },
	{ "EncounterBar", "EncounterBar" },
	{ "DurabilityFrame", "Durability" },
	-- Only while AzeriteUI places tooltips (Tooltips -> Enable Anchoring); otherwise
	-- Blizzard's container is where they go, and Edit Mode is how to move it.
	{ "GameTooltipDefaultContainer", "Tooltips", when = function(module)
		local profile = module.db and module.db.profile
		return profile and profile.anchor ~= false and not profile.disableAzeriteUITooltips
	end },
	-- The minimap skin takes the queue eye, unless Bartender's queue bar owns it (Minimap.lua).
	{ "QueueStatusButton", "Minimap", when = function()
		return not ns.API.IsAddOnEnabled("Bartender4")
	end }
}

-- An entry applies when it names no module, or any one of its modules is enabled and
-- its own condition (if it has one) agrees.
local isReplaced = function(entry)
	if (not entry[2]) then return true end
	for i = 2, #entry do
		local module = ns:GetModule(entry[i], true)
		if (module and module:IsEnabled()) then
			return not entry.when or entry.when(module) and true or false
		end
	end
	return false
end

ns.HideReplacedEditModeSelections = function()
	for _, entry in ipairs(EDIT_MODE_REPLACED) do
		if (isReplaced(entry)) then
			ns.HideEditModeSelection(_G[entry[1]])
		end
	end
end

-- Edit Mode's side panel also lists a "show this frame" checkbox for each of these. Ticking
-- one force-shows Blizzard's copy of a frame AzeriteUI replaces. LayoutSettings re-shows
-- the boxes whenever the panel is rebuilt, so hide them from a post-hook; writing
-- checkButton.shouldHide instead would put addon-written state in Blizzard's layout path.
local EDIT_MODE_CHECKBOXES = { "ArenaFrames", "RaidFrames", "PartyFrames", "PersonalResourceDisplay", "VehicleLeaveButton" }
local checkboxesHooked = false

local hideReplacedCheckboxes = function()
	local manager = _G.EditModeManagerFrame
	local container = manager and manager.AccountSettings and manager.AccountSettings.SettingsContainer
	if (not container) then return end
	for _, key in ipairs(EDIT_MODE_CHECKBOXES) do
		local checkBox = container[key]
		if (checkBox and checkBox.Hide) then checkBox:Hide() end
	end
end

ns.HideReplacedEditModeCheckboxes = function()
	local manager = _G.EditModeManagerFrame
	local settings = manager and manager.AccountSettings
	if (not settings or type(settings.LayoutSettings) ~= "function") then return end
	if (not checkboxesHooked) then
		checkboxesHooked = true
		hooksecurefunc(settings, "LayoutSettings", hideReplacedCheckboxes)
	end
	hideReplacedCheckboxes()
end

-- Hiding a checkbox does not untick it: a box left ticked in an earlier session still
-- force-shows Blizzard's party, raid, arena and personal resource previews when Edit Mode
-- opens. Fade those previews to nothing for as long as Edit Mode is active. Alpha is not
-- protected state, and nothing here calls into or writes to Blizzard's Edit Mode tables.
-- Entries: frame name, then the modules (any one enabled) that replace it; none = always.
local EDIT_MODE_PREVIEWS = {
	{ "PersonalResourceDisplayFrame" },
	{ "CompactArenaFrame", "ArenaFrames" },
	{ "CompactRaidFrameContainer", "RaidFrame5", "RaidFrame25", "RaidFrame40" },
	{ "PartyFrame", "PartyFrames", "RaidFrame5" },
	{ "CompactPartyFrame", "PartyFrames", "RaidFrame5" }
}
local previewAlpha = setmetatable({}, { __mode = "k" })
local previewHooked = setmetatable({}, { __mode = "k" })
local settingPreviewAlpha = false
local editModeActive = false
local previewHooksInstalled = false

local setPreviewAlpha = function(frame, alpha)
	settingPreviewAlpha = true
	frame:SetAlpha(alpha)
	settingPreviewAlpha = false
end

local isPreviewReplaced = function(entry)
	if (#entry == 1) then return true end
	for i = 2, #entry do
		local module = ns:GetModule(entry[i], true)
		if (module and module:IsEnabled()) then return true end
	end
	return false
end

-- The arena members' debuff, CC remover, cast bar and diminish tray are created with
-- ignoreParentAlpha, so fading CompactArenaFrame leaves them drawn. Fade them directly.
local ARENA_MEMBER_CHILDREN = { "DebuffFrame", "CcRemoverFrame", "CastingBarFrame", "SpellDiminishStatusTray" }

local fadeFrame = function(frame)
	if (previewAlpha[frame] == nil) then
		previewAlpha[frame] = frame:GetAlpha()
	end
	if (not previewHooked[frame]) then
		previewHooked[frame] = true
		hooksecurefunc(frame, "SetAlpha", function(self)
			if (editModeActive and not settingPreviewAlpha and previewAlpha[self] ~= nil) then
				setPreviewAlpha(self, 0)
			end
		end)
	end
	setPreviewAlpha(frame, 0)
end

local restoreFrame = function(frame)
	if (previewAlpha[frame] == nil) then return end
	local alpha = previewAlpha[frame]
	previewAlpha[frame] = nil
	setPreviewAlpha(frame, alpha)
end

local applyEditModePreviews = function()
	-- Modules may have enabled since login, so re-check the overlays each time.
	if (editModeActive) then ns.HideReplacedEditModeSelections() end
	local apply = editModeActive and fadeFrame or restoreFrame
	for _, entry in ipairs(EDIT_MODE_PREVIEWS) do
		local frame = _G[entry[1]]
		if (frame and frame.SetAlpha and isPreviewReplaced(entry)) then
			apply(frame)
			if (entry[1] == "CompactArenaFrame" and type(frame.memberUnitFrames) == "table") then
				for _, member in ipairs(frame.memberUnitFrames) do
					for _, key in ipairs(ARENA_MEMBER_CHILDREN) do
						local child = member[key]
						if (child and child.SetAlpha) then apply(child) end
					end
				end
			end
		end
	end
end
ns.HideReplacedEditModePreviews = function()
	local manager = _G.EditModeManagerFrame
	if (not manager or previewHooksInstalled) then return end
	if (type(manager.EnterEditMode) ~= "function" or type(manager.ExitEditMode) ~= "function") then return end
	previewHooksInstalled = true
	hooksecurefunc(manager, "EnterEditMode", function() editModeActive = true; applyEditModePreviews() end)
	hooksecurefunc(manager, "ExitEditMode", function() editModeActive = false; applyEditModePreviews() end)
	-- Ticking a box mid-session builds the preview afterwards, so catch it on the way.
	hooksecurefunc(manager.AccountSettings or manager, "LayoutSettings", function()
		if (editModeActive) then applyEditModePreviews() end
	end)
end

-- /azdebug editmode: read-only report on what Edit Mode is showing, so a leftover preview can be named.
ns.PrintEditModeDiagnostics = function()
	local out = function(...) print("|cff33ff99AzeriteUI /azdebug editmode:|r", ...) end
	local manager = _G.EditModeManagerFrame
	out("Edit Mode open:", tostring(manager and manager:IsShown() or false), "| our active flag:", tostring(editModeActive), "| hooks:", tostring(previewHooksInstalled))
	-- Group frames fade with range, so their alpha can be secret; a secret in the line
	-- turns the whole printed line into "???".
	local safe = function(value)
		if (issecretvalue and issecretvalue(value)) then return nil end
		return value
	end
	local describe = function(frame)
		if (not frame or not frame.IsShown) then return "missing" end
		local parent = frame.GetParent and frame:GetParent()
		local name = parent and parent.GetName and safe(parent:GetName()) or "?"
		local sel = frame.Selection
		local alpha = safe(frame:GetAlpha())
		return ("shown=%s visible=%s alpha=%s parent=%s selection=%s"):format(
			tostring(safe(frame:IsShown())), tostring(safe(frame.IsVisible and frame:IsVisible())),
			alpha and ("%.2f"):format(alpha) or "secret", name,
			sel and tostring(safe(sel:IsShown())) or "none")
	end
	for _, entry in ipairs(EDIT_MODE_PREVIEWS) do
		out(entry[1], isPreviewReplaced(entry) and "(we fade)" or "(left alone)", describe(_G[entry[1]]))
	end
	local arena = _G.CompactArenaFrame
	for i, member in ipairs(arena and arena.memberUnitFrames or {}) do
		for _, key in ipairs(ARENA_MEMBER_CHILDREN) do
			if (member[key] and member[key]:IsShown()) then out("arena member" .. i, key, describe(member[key])) end
		end
	end
	out("MainMenuBarVehicleLeaveButton", describe(_G.MainMenuBarVehicleLeaveButton))
	for _, entry in ipairs(EDIT_MODE_REPLACED) do
		out("overlay", entry[1], describe(_G[entry[1]]))
	end
	local container = manager and manager.AccountSettings and manager.AccountSettings.SettingsContainer
	if (container) then
		for _, key in ipairs(EDIT_MODE_CHECKBOXES) do
			local box = container[key]
			out("checkbox", key, box and ("shown=" .. tostring(box:IsShown())) or "missing")
		end
	end
	for i = 1, 5 do
		local member = _G["CompactPartyFrameMember" .. i]
		if (member and member:IsShown()) then
			out("CompactPartyFrameMember" .. i, describe(member), "ignoreParentAlpha=" .. tostring(safe(member.GetIgnoreParentAlpha and member:GetIgnoreParentAlpha())))
		end
	end

	-- Every Edit Mode system whose selection overlay is on screen right now, so a client
	-- with systems the lists above do not name (Forever) can be read in one go. Read
	-- only: the registry is walked, never written, and no Blizzard method is called
	-- beyond plain getters, each through pcall.
	local systems = manager and manager.registeredSystemFrames
	if (type(systems) ~= "table") then
		out("systems: registry not readable on this client")
		return
	end
	local visible = 0
	for index, frame in ipairs(systems) do
		local selection = type(frame) == "table" and frame.Selection
		local okShown, isVisible = false, false
		if (selection and selection.IsVisible) then
			okShown, isVisible = pcall(selection.IsVisible, selection)
		end
		if (okShown and isVisible) then
			visible = visible + 1
			local okName, systemName = pcall(function() return frame:GetSystemName() end)
			local frameName = frame.GetName and frame:GetName() or ("#" .. index)
			out("visible selection:", tostring(okName and systemName or frame.system), frameName,
				describe(frame), "| we hook it:", tostring(selectionHooked[selection] and true or false))
		end
	end
	out("systems:", #systems, "| with a visible selection:", visible,
		(manager:IsShown() and "" or "(open Edit Mode first; selections only show while it is open)"))
end
if (ns.API.IsAddOnEnabled("ConsolePort_Bar")) then return end

local BlizzardABDisabler = ns:NewModule("BlizzardABDisabler", "LibMoreEvents-1.0", "AceHook-3.0")
local quarantinedFrames = setmetatable({}, { __mode = "k" })
local hiddenBagControls = setmetatable({}, { __mode = "k" })
local applyingAlpha = setmetatable({}, { __mode = "k" })
local applyingMouse = setmetatable({}, { __mode = "k" })
local applyingVisibility = setmetatable({}, { __mode = "k" })
local deferredMouseFrames = setmetatable({}, { __mode = "k" })

local HIDDEN_FRAME_NAMES = {
	"MainMenuBar",
	"MainActionBar",
	"MultiBarBottomLeft",
	"MultiBarBottomRight",
	"MultiBarLeft",
	"MultiBarRight",
	"MultiBar5",
	"MultiBar6",
	"MultiBar7",
	"BagsBar",
	"StanceBar",
	"PossessActionBar",
	"MultiCastActionBarFrame",
	"PetActionBar",
	"StatusTrackingBarManager",
	"OverrideActionBar"
}

-- Forever's shaman totem bar has no AzeriteUI replacement. There it is its own Edit
-- Mode system parented to UIParent (Blizzard_ActionBar/Shared/MultiCastActionBarFrame.xml,
-- loaded for camelot, wrath and cata) with its own "Show Totem Action Bar" setting,
-- and it only shows while the player has multi-cast totem spells. Leave it to
-- Blizzard instead of fading it to nothing.
if (ns.IsForever) then
	for i = #HIDDEN_FRAME_NAMES, 1, -1 do
		if (HIDDEN_FRAME_NAMES[i] == "MultiCastActionBarFrame") then
			table.remove(HIDDEN_FRAME_NAMES, i)
		end
	end
end

-- Kept apart from HIDDEN_FRAME_NAMES so the micro menu can be left alone when the
-- player asks for Blizzard's own strip back. MicroButtonAndBagsBar carries the bag
-- controls too, but those are suppressed separately by suppressNamedBagControls.
local MICRO_MENU_FRAME_NAMES = {
	"MicroMenu",
	"MicroMenuContainer",
	"MicroButtonAndBagsBar"
}

-- Quarantining the container alone would make these invisible, since alpha is
-- inherited, but not deaf: an unlisted button keeps its mouse input and can still
-- swallow a click from behind AzeriteUI's own menu. Every button the client can put
-- on the strip therefore needs its own entry. Missing names are skipped, so the
-- Forever-only four at the end cost nothing on Retail.
local MICRO_BUTTON_NAMES = {
	"CharacterMicroButton",
	"ProfessionMicroButton",
	"PlayerSpellsMicroButton",
	"QuestLogMicroButton",
	"HousingMicroButton",
	"QuickJoinToastButton",
	"GuildMicroButton",
	"LFDMicroButton",
	"AchievementMicroButton",
	"EJMicroButton",
	"CollectionsMicroButton",
	"MainMenuMicroButton",
	"StoreMicroButton",
	-- Blizzard_MicroMenu/Camelot/MicroMenuContainerOverrides.lua
	"SpellbookMicroButton",
	"TalentMicroButton",
	"LegacyMicroButton",
	"HelpMicroButton"
}

local BAG_BUTTON_NAMES = {
	"MainMenuBarBackpackButton",
	"BagBarExpandToggle"
}

local BLIZZARD_ACTION_BAR_ADDONS = {
	Blizzard_ActionBar = true,
	Blizzard_MainMenuBarBagButtons = true,
	Blizzard_MicroMenu = true,
	Blizzard_NewPlayerExperience = true
}

local disableMouseInput = function(frame)
	if (not frame or applyingMouse[frame]) then return end

	-- EnableMouse and friends are protected on a protected frame while in combat,
	-- and these run as hooks, so Blizzard touching mouse state mid-fight would drag
	-- us straight into ADDON_ACTION_BLOCKED. Defer to the combat drop instead; the
	-- frame is already at alpha zero, so the only cost is that an invisible Blizzard
	-- button could catch a click until the fight ends.
	if (InCombatLockdown() and frame.IsProtected and frame:IsProtected()) then
		deferredMouseFrames[frame] = true
		return
	end

	applyingMouse[frame] = true
	if (frame.EnableMouse) then frame:EnableMouse(false) end
	if (frame.SetMouseClickEnabled) then frame:SetMouseClickEnabled(false) end
	if (frame.SetMouseMotionEnabled) then frame:SetMouseMotionEnabled(false) end
	applyingMouse[frame] = nil
end

-- Re-run whatever combat lockdown made us skip.
local flushDeferredMouseFrames = function()
	if (InCombatLockdown()) then return end
	for frame in next, deferredMouseFrames do
		deferredMouseFrames[frame] = nil
		disableMouseInput(frame)
	end
end

local quarantineFrame = function(frame)
	if (not frame) then return end

	frame:SetAlpha(0)
	disableMouseInput(frame)
	ns.HideEditModeSelection(frame)

	if (not quarantinedFrames[frame]) then
		quarantinedFrames[frame] = true
		hooksecurefunc(frame, "SetAlpha", function(self)
			if (applyingAlpha[self]) then return end
			applyingAlpha[self] = true
			self:SetAlpha(0)
			applyingAlpha[self] = nil
		end)
		for _, method in ipairs({ "EnableMouse", "SetMouseClickEnabled", "SetMouseMotionEnabled" }) do
			if (frame[method]) then
				hooksecurefunc(frame, method, disableMouseInput)
			end
		end
	end
end

local quarantineNamedFrames = function(frameNames)
	for _, frameName in ipairs(frameNames) do
		quarantineFrame(_G[frameName])
	end
end

local suppressBagControl = function(frame)
	if (not frame) then return end

	quarantineFrame(frame)
	if (not InCombatLockdown()) then
		frame:Hide()
	end

	if (hiddenBagControls[frame]) then return end
	hiddenBagControls[frame] = true
	for _, method in ipairs({ "Show", "SetShown" }) do
		hooksecurefunc(frame, method, function(self, shown)
			if (applyingVisibility[self] or shown == false or InCombatLockdown()) then return end
			applyingVisibility[self] = true
			self:Hide()
			applyingVisibility[self] = nil
		end)
	end
end

local suppressNamedBagControls = function()
	for _, frameName in ipairs(BAG_BUTTON_NAMES) do
		-- Bartender reparents the native backpack button into its own bag bar.
		-- Leave that shared button untouched when Bartender owns the bar.
		if (frameName ~= "MainMenuBarBackpackButton" or not ns.API.IsAddOnEnabled("Bartender4")) then
			suppressBagControl(_G[frameName])
		end
	end
end

BlizzardABDisabler.NPE_LoadUI = function(self)
	local Tutorials = _G.Tutorials
	if not (Tutorials and Tutorials.AddSpellToActionBar) then return end

	-- Action Bar drag tutorials
	Tutorials.AddSpellToActionBar:Disable()
	Tutorials.AddClassSpellToActionBar:Disable()

	-- these tutorials rely on finding valid action bar buttons, and error otherwise
	Tutorials.Intro_CombatTactics:Disable()

	-- enable spell pushing because the drag tutorial is turned off
	Tutorials.AutoPushSpellWatcher:Complete()
end

BlizzardABDisabler.HideBlizzard = function(self)

	quarantineNamedFrames(HIDDEN_FRAME_NAMES)

	-- In TWW 11.0+, hide the gryphons (EndCaps) on MainActionBar
	-- On Forever each gryphon is its own Edit Mode system
	-- (Blizzard_ActionBar/Camelot/MainMenuBarEndCaps.xml, EditModeMainActionBarEndCap*SystemTemplate),
	-- with its own selection overlay that the main bar's does not cover.
	local MainActionBar = _G.MainActionBar
	if (MainActionBar and MainActionBar.EndCaps) then
		if (MainActionBar.EndCaps.LeftEndCap) then
			MainActionBar.EndCaps.LeftEndCap:Hide()
			ns.HideEditModeSelection(MainActionBar.EndCaps.LeftEndCap)
		end
		if (MainActionBar.EndCaps.RightEndCap) then
			MainActionBar.EndCaps.RightEndCap:Hide()
			ns.HideEditModeSelection(MainActionBar.EndCaps.RightEndCap)
		end
	end

	-- Keep Blizzard's secure buttons and event machinery alive, but make the
	-- invisible buttons unable to intercept the AzeriteUI bars.
	for i=1,12 do
		quarantineFrame(_G["ActionButton" .. i])
		quarantineFrame(_G["MultiBarBottomLeftButton" .. i])
		quarantineFrame(_G["MultiBarBottomRightButton" .. i])
		quarantineFrame(_G["MultiBarRightButton" .. i])
		quarantineFrame(_G["MultiBarLeftButton" .. i])
		quarantineFrame(_G["MultiBar5Button" .. i])
		quarantineFrame(_G["MultiBar6Button" .. i])
		quarantineFrame(_G["MultiBar7Button" .. i])
	end

	-- Retail's stance, micro-menu and bag buttons can render independently of
	-- their layout containers. Quarantine the actual click targets as well.
	for i=1,10 do
		quarantineFrame(_G["StanceButton" .. i])
		quarantineFrame(_G["PetActionButton" .. i])
	end
	for i=1,2 do
		quarantineFrame(_G["PossessButton" .. i])
	end
	-- Leaving these alone is what gives the player Blizzard's bottom micro menu back.
	-- The AzeriteUI cog wheel keeps working either way: its buttons are proxies that
	-- run "/click <MicroButtonName>" rather than reparented Blizzard buttons.
	if (not (ns.ShouldShowBlizzardMicroMenu and ns.ShouldShowBlizzardMicroMenu())) then
		quarantineNamedFrames(MICRO_MENU_FRAME_NAMES)
		quarantineNamedFrames(MICRO_BUTTON_NAMES)
	end
	suppressNamedBagControls()

	if C_AddOns.IsAddOnLoaded("Blizzard_NewPlayerExperience") then
		self:NPE_LoadUI()
	elseif _G.NPE_LoadUI ~= nil and not self.npeHooked then
		self:SecureHook("NPE_LoadUI")
		self.npeHooked = true
	end

	if (not self.microAlertHooked and _G.MainMenuMicroButton_ShowAlert) then
		local HideAlerts = function()
			local HelpTip = _G.HelpTip
			if (HelpTip) then
				HelpTip:HideAllSystem("MicroButtons")
			end
		end
		_G.hooksecurefunc("MainMenuMicroButton_ShowAlert", HideAlerts)
		self.microAlertHooked = true
	end

end

BlizzardABDisabler.QueueHideBlizzard = function(self)
	if (self.hideBlizzardQueued) then return end
	self.hideBlizzardQueued = true
	C_Timer.After(0, function()
		self.hideBlizzardQueued = nil
		if (self:IsEnabled()) then
			self:HideBlizzard()
		end
	end)
end

BlizzardABDisabler.OnBlizzardUIReady = function(self, event, addon)
	ns.HideReplacedEditModeSelections()
	ns.HideReplacedEditModeCheckboxes()
	ns.HideReplacedEditModePreviews()
	if (event == "ADDON_LOADED" and not BLIZZARD_ACTION_BAR_ADDONS[addon]) then
		return
	end
	self:HideBlizzard()
	self:QueueHideBlizzard()
end

BlizzardABDisabler.OnInitialize = function(self)
	if (ns.API.IsAddOnEnabled("ConsolePort_Bar")) then return self:Disable() end
end

BlizzardABDisabler.OnCombatEnd = function(self)
	flushDeferredMouseFrames()
end

BlizzardABDisabler.OnEnable = function(self)
	ns.HideReplacedEditModeSelections()
	ns.HideReplacedEditModeCheckboxes()
	ns.HideReplacedEditModePreviews()
	self:HideBlizzard()
	self:RegisterEvent("PLAYER_ENTERING_WORLD", "OnBlizzardUIReady")
	self:RegisterEvent("ADDON_LOADED", "OnBlizzardUIReady")
	self:RegisterEvent("PLAYER_REGEN_ENABLED", "OnCombatEnd")
	ns.RegisterCallback(self, "Bartender_Handled", "OnBlizzardUIReady")
end
