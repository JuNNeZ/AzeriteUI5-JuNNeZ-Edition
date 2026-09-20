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

local MicroMenu = ns:NewModule("MicroMenu", "LibMoreEvents-1.0", "AceHook-3.0")

local L = LibStub("AceLocale-3.0"):GetLocale((...))

local Colors = ns.Colors
local GetFont = ns.API.GetFont
local GetMedia = ns.API.GetMedia

-- WoW API
-- GetCVarBool is deprecated in favour of C_CVar.GetCVarBool. Shadowed as a file
-- local so the call sites keep working whichever of the two the client exposes.
local GetCVarBool = (C_CVar and C_CVar.GetCVarBool) or GetCVarBool

-- Whether secure handler snippets compile on this client; see Core/Client.lua.
local hasSecureSnippets = ns.HasSecureSnippets ~= false

-- Matches the .75 second grace the restricted RegisterAutoHide is given below.
local MICROMENU_AUTOHIDE_DELAY = .75

local defaults = {
	profile = {
		-- The AzeriteUI cog wheel in the bottom right corner.
		enabled = true,
		-- Blizzard's own micro menu strip along the bottom of the screen.
		-- Off by default, which is the behavior every prior version shipped.
		showBlizzardMicroMenu = false
	}
}

MicroMenu.GetDefaults = function(self)
	return defaults
end

-- Read by Components/ActionBars/Compatibility/HideBlizzard.lua, which runs before
-- this module initializes, so both the module and its db may still be missing.
-- Default to hiding Blizzard's strip, matching every version before this option.
ns.ShouldShowBlizzardMicroMenu = function()
	local module = ns:GetModule("MicroMenu", true)
	local profile = module and module.db and module.db.profile
	return (profile and profile.showBlizzardMicroMenu) and true or false
end

MicroMenu.SpawnButtons = function(self)

	local labels = {
		CharacterMicroButton = CHARACTER_BUTTON,
		ProfessionMicroButton = TRADE_SKILLS,
		PlayerSpellsMicroButton = SPELLBOOK_ABILITIES_BUTTON,
		SpellbookMicroButton = SPELLBOOK_ABILITIES_BUTTON,
		TalentMicroButton = TALENTS,
		AchievementMicroButton = ACHIEVEMENT_BUTTON,
		QuestLogMicroButton = QUESTLOG_BUTTON,
		HousingMicroButton = HOUSING_DASHBOARD or HOUSING,
		QuickJoinToastButton = SOCIALS,
		GuildMicroButton = LOOKINGFORGUILD,
		LFDMicroButton = DUNGEONS_BUTTON,
		CollectionsMicroButton = COLLECTIONS,
		EJMicroButton = ADVENTURE_JOURNAL or ENCOUNTER_JOURNAL,
		StoreMicroButton = BLIZZARD_STORE,
		MainMenuMicroButton = MAINMENU_BUTTON
	}

	local buttons = {
		CharacterMicroButton,
		ProfessionMicroButton,
		SpellbookMicroButton or PlayerSpellsMicroButton,
		TalentMicroButton,
		LegacyMicroButton,
		AchievementMicroButton,
		QuestLogMicroButton,
		HousingMicroButton,
		QuickJoinToastButton,
		GuildMicroButton,
		LFDMicroButton,
		CollectionsMicroButton,
		EJMicroButton,
		StoreMicroButton,
		MainMenuMicroButton
	}

	-- Blizzard's list selects the client's buttons and excludes disabled game
	-- systems. Forever has Spellbook, Talent and Legacy buttons of its own.
	local nativeMenu = _G.MicroMenu
	if (nativeMenu and nativeMenu.GenerateButtonInfos) then
		buttons = {}
		for _, info in ipairs(nativeMenu:GenerateButtonInfos()) do
			local disabled = info.gameRule and (not C_GameRules or not C_GameRules.IsGameRuleActive
				or C_GameRules.IsGameRuleActive(info.gameRule))
			if (info.button and not disabled and not (info.callback and info.callback())) then
				if (info.button == GuildMicroButton and QuickJoinToastButton) then
					buttons[#buttons + 1] = QuickJoinToastButton
				end
				buttons[#buttons + 1] = info.button
			end
		end
	end

	self.buttons = {}

	local bar = CreateFrame("Frame", ns.Prefix.."MicroMenu", UIParent, "SecureHandlerStateTemplate")
	bar:SetFrameStrata("HIGH")
	bar:SetScale(ns.API.GetEffectiveScale())
	bar:Hide()

	self.bar = bar

	local backdrop = CreateFrame("Frame", nil, bar, ns.BackdropTemplate)
	backdrop:SetFrameLevel(bar:GetFrameLevel())
	backdrop:SetBackdrop({
		bgFile = [[Interface\Tooltips\UI-Tooltip-Background]],
		edgeSize = 32, edgeFile = GetMedia("border-tooltip"),
		tile = true,
		insets = { left = 8, right = 8, top = 16, bottom = 16 }
	})
	backdrop:SetBackdropColor(.05, .05, .05, .95)

	for i,microButton in next,buttons do
		if (microButton) then
			local button = CreateFrame("Button", nil, bar, "SecureActionButtonTemplate")
			button.ref = microButton

			button:RegisterForClicks("AnyUp", "AnyDown")

			-- MainMenuMicroButton is the one entry that cannot go through `/click`.
			-- Its own OnClick opens with `if (self:IsMouseOver())`, and the native
			-- button sits at zero alpha in the corner while the pointer is over this
			-- menu, so a forwarded click would silently do nothing. Everything else
			-- uses the macro route, which runs Blizzard's handler from a secure click
			-- and therefore does not taint the panel-show path.
			--
			-- CharacterMicroButton used to be special-cased here as well, calling
			-- ToggleCharacter("PaperDollFrame") from this insecure handler. That is
			-- exactly what CharacterMicroButtonMixin:OnClick already does, so the
			-- macro route is behaviour-identical - and the insecure call tainted
			-- ShowUIPanel, which made Blizzard's own TextStatusBar refuse to compare
			-- the player frame's secret health values (TextStatusBar.lua:110,
			-- "execution tainted by AzeriteUI5_JuNNeZ_Edition").
			if (microButton == MainMenuMicroButton) then
				button.nocombat = true
				button:SetScript("OnClick", function(self, button, down)
					if (InCombatLockdown()) then return end
					local castondown = GetCVarBool("ActionButtonUseKeyDown")
					if (castondown and not down) or (not castondown and down) then return end
					if (not GameMenuFrame:IsShown()) then
						if (not AreAllPanelsDisallowed or not AreAllPanelsDisallowed()) then
							if (SettingsPanel and SettingsPanel:IsShown()) then
								SettingsPanel:Close()
							end
							CloseMenus()
							CloseAllWindows()
							PlaySound(SOUNDKIT.IG_MAINMENU_OPEN)
							ShowUIPanel(GameMenuFrame)
						end
					else
						PlaySound(SOUNDKIT.IG_MAINMENU_QUIT)
						HideUIPanel(GameMenuFrame)
					end
				end)
			else
				button:SetAttribute("type", "macro")
				button:SetAttribute("click", "macro")
				button:SetAttribute("macrotext", "/click "..microButton:GetName())
				button:SetAttribute("pressAndHoldAction", true)
			end
			button:SetSize(200,30)
			button:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", 0, 0 + #self.buttons*32)

			local backdrop = button:CreateTexture(nil, "ARTWORK")
			backdrop:SetPoint("TOPLEFT", 1,-1)
			backdrop:SetPoint("BOTTOMRIGHT", -1,1)
			backdrop:SetColorTexture(1,1,1,.9)
			button.backdrop = backdrop

			local text = button:CreateFontString(nil, "OVERLAY")
			text:SetFontObject(GetFont(13,true))
			text:SetText(labels[microButton:GetName()] or microButton.tooltipText or microButton:GetName())
			text:SetJustifyH("CENTER")
			text:SetJustifyV("MIDDLE")
			text:SetPoint("CENTER")
			button.text = text

			button:SetScript("OnEnter", function(self)
				text:SetTextColor(unpack(Colors.highlight))
				backdrop:SetVertexColor(.25,.25,.25)
			end)

			button:SetScript("OnLeave", function(self)
				if (self:IsEnabled()) then
					text:SetTextColor(unpack(Colors.offwhite))
				else
					text:SetTextColor(unpack(Colors.gray))
				end
				backdrop:SetVertexColor(.1,.1,.1)
			end)

			button:GetScript("OnLeave")(button)

			self.buttons[#self.buttons + 1] = button
		end
	end

	if (not self.buttons[1]) then return end
	backdrop:SetPoint("RIGHT", self.buttons[1], "RIGHT", 10, 0)
	backdrop:SetPoint("BOTTOM", self.buttons[1], "BOTTOM", 0, -20)
	backdrop:SetPoint("LEFT", self.buttons[1], "LEFT", -10, 0)
	backdrop:SetPoint("TOP", self.buttons[#self.buttons], "TOP", 0, 18)

	local toggle = CreateFrame("CheckButton", ns.Prefix.."MicroMenuToggleButton", UIParent, "SecureHandlerClickTemplate")
	toggle:SetScale(ns.API.GetEffectiveScale())
	toggle:SetSize(48, 48)
	toggle:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -4 / ns.API.GetEffectiveScale(), 4 / ns.API.GetEffectiveScale())
	toggle:RegisterForClicks("AnyUp")
	toggle:SetFrameRef("Bar", bar)

	self.toggle = toggle

	bar:SetPoint("BOTTOMRIGHT", toggle, "TOPLEFT", 0, 0)
	bar:SetSize(200, 4 + 32*#self.buttons)

	if (hasSecureSnippets) then
		toggle:SetAttribute("_onclick", [[
			local bar = self:GetFrameRef("Bar");
			if (bar:IsShown()) then
				bar:Hide();
			else
				bar:Show();
			end
			bar:UnregisterAutoHide();
			if (bar:IsShown()) then
				bar:RegisterAutoHide(.75);
				bar:AddToAutoHide(self);
			end
		]])
	else
		-- `_onclick` and the RegisterAutoHide family are both restricted-environment
		-- only, so on a client that cannot build a closure the cog does nothing at all
		-- and raises on every press. The toggle is reproduced insecurely instead.
		--
		-- The menu bar is protected, so showing or hiding it is refused in combat.
		-- That costs nothing here: every entry in this menu that opens a panel is
		-- already disabled in combat, and the cog goes back to working the moment the
		-- fight ends.
		toggle:HookScript("OnClick", MicroMenu.OnToggleClickInsecure)
	end

	local texture = toggle:CreateTexture(nil, "ARTWORK", nil, 0)
	texture:SetSize(96, 96)
	texture:SetPoint("CENTER", 0, 0)
	texture:SetTexture(GetMedia("config_button"))
	texture:SetVertexColor(Colors.ui[1], Colors.ui[2], Colors.ui[3])

	-- config_button_bright is the lit twin of config_button: same 128x128 art, same
	-- geometry, brighter metal. It ships for this and nothing else, and the cog was
	-- the only AzeriteUI button with no mouseover feedback at all. Kept as a plain
	-- texture swap on the insecure side; the toggle is a SecureHandlerClickTemplate
	-- and nothing here touches an attribute, so this stays safe in combat.
	local highlight = toggle:CreateTexture(nil, "ARTWORK", nil, 1)
	highlight:SetSize(96, 96)
	highlight:SetPoint("CENTER", 0, 0)
	highlight:SetTexture(GetMedia("config_button_bright"))
	highlight:SetVertexColor(Colors.ui[1], Colors.ui[2], Colors.ui[3])
	highlight:Hide()

	toggle.Texture = texture
	toggle.Highlight = highlight

	toggle:HookScript("OnEnter", function(self) self.Highlight:Show() end)
	toggle:HookScript("OnLeave", function(self) self.Highlight:Hide() end)

	RegisterStateDriver(toggle, "visibility", "[petbattle]hide;show")
end

-- The insecure twin of the `_onclick` snippet above, used only where restricted
-- closures are unavailable. Hooked onto the toggle button, so it is handed the
-- button rather than the module and looks the module up itself.
MicroMenu.OnToggleClickInsecure = function()
	local module = ns:GetModule("MicroMenu", true)
	local bar = module and module.bar
	if (not bar) then return end
	if (InCombatLockdown()) then return end

	bar:SetShown(not bar:IsShown())

	if (bar:IsShown()) then
		module:StartAutoHideInsecure()
	else
		module:StopAutoHideInsecure()
	end
end

-- RegisterAutoHide/AddToAutoHide live in the restricted environment, so the grace
-- period is timed here instead. The menu closes once the pointer has been off both
-- the menu and the cog for the same .75 seconds Blizzard's version waits.
MicroMenu.StartAutoHideInsecure = function(self)
	local bar, toggle = self.bar, self.toggle
	if (not bar) then return end

	self.autoHideElapsed = 0

	bar:SetScript("OnUpdate", function(_, elapsed)
		if (bar:IsMouseOver() or (toggle and toggle:IsMouseOver())) then
			self.autoHideElapsed = 0
			return
		end

		self.autoHideElapsed = (self.autoHideElapsed or 0) + elapsed
		if (self.autoHideElapsed < MICROMENU_AUTOHIDE_DELAY) then return end

		self:StopAutoHideInsecure()

		-- The menu bar is protected, so a fight that starts while it is open keeps it
		-- open until the fight ends. Nothing is lost: its combat-unsafe entries are
		-- already disabled by UpdateButtons.
		if (not InCombatLockdown()) then
			bar:Hide()
		end
	end)
end

MicroMenu.StopAutoHideInsecure = function(self)
	if (not self.bar) then return end

	self.autoHideElapsed = 0
	self.bar:SetScript("OnUpdate", nil)
end

-- Blizzard disables a micro button for two different reasons, and only one of them
-- should stop this menu.
--
-- A per-feature gate disables the *button* while leaving the feature reachable:
-- Legacy below renown 1, Talents before the first talent point, Group Finder below
-- its level. Every micro button carries a `commandName` KeyValue naming its binding,
-- and those bindings call the toggle directly and never touch the button -
-- `Bindings_Camelot.xml` has `TOGGLELEGACYSYSTEM` running `ToggleLegacySystemUI()`
-- outright. That is why pressing the key opens Legacy while clicking the disabled
-- button cannot, and `/click` on a disabled Button is a no-op. Re-enabling the button
-- lets this menu do what the key already does.
--
-- `MICRO_BUTTONS_DISABLED` is the other reason: a full-screen frame is up and the
-- whole strip is off. That one is honoured, because the keybinds go with it.
--
-- Called from the UpdateMicroButtons hook and never from a click, so a later press
-- runs Blizzard's own OnClick with no AzeriteUI code anywhere in the chain. That is
-- what keeps it from tainting ShowUIPanel the way the old Character handler did.
local RestoreGatedNativeButton = function(microButton)
	if (not microButton) then return end
	if (_G.MICRO_BUTTONS_DISABLED) then return end
	if (type(microButton.commandName) ~= "string") then return end
	if (not microButton.IsEnabled) or (microButton:IsEnabled()) then return end
	if (microButton.IsShown and not microButton:IsShown()) then return end
	if (not microButton.Enable) then return end

	microButton:Enable()
end

-- Whether Blizzard's own micro button would do anything if it were clicked, after
-- the gate above has been lifted where it can be.
local IsNativeButtonUsable = function(microButton)
	if (not microButton) then return false end
	if (not microButton.IsEnabled) then return true end

	return microButton:IsEnabled() and true or false
end

MicroMenu.UpdateButtons = function(self)
	if (InCombatLockdown()) then return end
	for i,button in next,self.buttons do
		RestoreGatedNativeButton(button.ref)

		local usable = IsNativeButtonUsable(button.ref)

		if (button.nocombat and self.incombat) then
			usable = false
		end

		-- The entry carries Blizzard's answer, so a gated feature greys out here the
		-- same way it does on Blizzard's own strip instead of silently swallowing
		-- the click. MainMenu and the macro entries are otherwise always usable.
		if (usable) then
			button:Enable()
		else
			button:Disable()
		end

		if (usable and button:IsMouseOver()) then
			button:GetScript("OnEnter")(button)
		else
			button:GetScript("OnLeave")(button)
		end
	end
end

MicroMenu.UpdateScale = function(self)
	if (InCombatLockdown()) then
		self.updateneeded = true
		return
	end
	if (self.toggle) then
		self.toggle:SetScale(ns.API.GetEffectiveScale())
		self.toggle:ClearAllPoints()
		self.toggle:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -4 / ns.API.GetEffectiveScale(), 4 / ns.API.GetEffectiveScale())
	end
	if (self.bar) then
		self.bar:SetScale(ns.API.GetEffectiveScale())
	end
end

MicroMenu.OnEvent = function(self, event, ...)
	if (event == "PLAYER_ENTERING_WORLD") then
		self.incombat = nil
	elseif (event == "PLAYER_REGEN_DISABLED") then
		self.incombat = true
	elseif (event == "PLAYER_REGEN_ENABLED") then
		if (InCombatLockdown()) then return end
		if (self.updateneeded) then
			self.updateneeded = nil
			self:UpdateScale()
		end
		self.incombat = nil
	elseif (event == "UI_SCALE_CHANGED" or event == "DISPLAY_SIZE_CHANGED") then
		self:UpdateScale()
	end
	self:UpdateButtons()
end

-- Both toggles decide what gets built or quarantined at load: the cog wheel and
-- its popup are spawned once in OnEnable, and Blizzard's strip is suppressed with
-- hooksecurefunc wrappers that cannot be lifted again. Neither can be undone mid
-- session, so a changed toggle asks for a reload rather than pretending to apply.
MicroMenu.PromptReload = function(self)
	if (self.reloadPromptShown) then
		return
	end
	self.reloadPromptShown = true

	local key = "AZERITEUI_MICRO_MENU_RELOAD"
	if (StaticPopupDialogs and not StaticPopupDialogs[key]) then
		StaticPopupDialogs[key] = {
			text = L["The micro menu is built when the interface loads, so this change needs a reload to take effect."],
			button1 = L["Reload UI"],
			button2 = CANCEL or "Cancel",
			OnAccept = function() ReloadUI() end,
			timeout = 0,
			whileDead = true,
			hideOnEscape = true,
			preferredIndex = 3
		}
	end
	if (StaticPopup_Show) then
		StaticPopup_Show(key)
	end
end

MicroMenu.UpdateSettings = function(self)
	local profile = self.db and self.db.profile
	if (not profile) then
		return
	end

	-- Compare against the state this session was actually built with, so the
	-- normal settings pass at login cannot trigger the prompt.
	local state = (profile.enabled and 1 or 0) .. ":" .. (profile.showBlizzardMicroMenu and 1 or 0)
	if (self.__builtState == nil) then
		self.__builtState = state
		return
	end
	if (self.__builtState ~= state) then
		self:PromptReload()
	end
end

MicroMenu.OnInitialize = function(self)
	self.db = ns.db:RegisterNamespace(self:GetName(), self:GetDefaults())
end

MicroMenu.OnEnable = function(self)

	self:UpdateSettings()

	if (self.db and self.db.profile and not self.db.profile.enabled) then
		return
	end

	self:SpawnButtons()

	-- None of the events below fire when a micro button's *enabled* state changes -
	-- earning a talent point, gaining renown, reaching the Group Finder level. This
	-- is the one call Blizzard makes for all of them, so the greying in UpdateButtons
	-- stays in step with the strip it mirrors.
	if (type(_G.UpdateMicroButtons) == "function" and not self:IsHooked("UpdateMicroButtons")) then
		self:SecureHook("UpdateMicroButtons", function() self:UpdateButtons() end)
	end

	self:RegisterEvent("DISPLAY_SIZE_CHANGED", "OnEvent")
	self:RegisterEvent("PLAYER_ENTERING_WORLD", "OnEvent")
	self:RegisterEvent("PLAYER_REGEN_DISABLED", "OnEvent")
	self:RegisterEvent("PLAYER_REGEN_ENABLED", "OnEvent")
	self:RegisterEvent("UI_SCALE_CHANGED", "OnEvent")
end
