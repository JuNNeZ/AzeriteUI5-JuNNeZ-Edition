local addonName, ns = ...

-- Observers only propose a change. The prompt's explicit Yes is the only
-- entry point that saves ownership, writes the native style and reloads.
local InputStyle = ns:NewModule("InputStyle", "LibMoreEvents-1.0")
ns.InputStyle = InputStyle
local L = LibStub("AceLocale-3.0"):GetLocale(addonName)
InputStyle.defaults = { profile = { enabled = true, suspended = false }, char = {} }
local CVAR = "InputDeviceInterfaceStyle"
local EVENTS = { "GAME_PAD_CONNECTED", "GAME_PAD_DISCONNECTED", "GAME_PAD_CONFIGS_CHANGED",
	"GAME_PAD_ACTIVE_CHANGED", "INPUT_DEVICE_INTERFACE_TRANSITION", "CVAR_UPDATE", "PLAYER_ENTERING_WORLD",
	"PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED", "ADDON_LOADED", "ADDON_ACTION_BLOCKED", "ADDON_ACTION_FORBIDDEN" }
local MOVEMENT = { "MOVEFORWARD", "MOVEBACKWARD", "STRAFELEFT", "STRAFERIGHT", "TURNLEFT", "TURNRIGHT" }

local function Public(value)
	if (type(issecretvalue) == "function") then
		local ok, secret = pcall(issecretvalue, value)
		if (not ok or secret) then return end
	end
	return value, true
end
local function Field(object, key)
	object = Public(object)
	if (type(object) ~= "table") then return end
	local ok, value = pcall(function() return object[key] end)
	if (ok) then return Public(value) end
end
local function Read(fn, ...)
	fn = Public(fn)
	if (type(fn) ~= "function") then return end
	local ok, value = pcall(fn, ...)
	if (ok) then return Public(value) end
end
local function Now()
	local value = Read(GetTime)
	return type(value) == "number" and value or 0
end
local function EnumValue(style)
	return Field(Field(Enum, "InputDeviceInterfaceType"), style == "gamepad" and "Gamepad" or "Mkb")
end
local function Style(value)
	value = Public(value)
	if (type(value) == "string") then value = tonumber(value) end
	if (type(value) ~= "number") then return end
	if (value == EnumValue("mnk")) then return "mnk" end
	if (value == EnumValue("gamepad")) then return "gamepad" end
end
local function ConfiguredStyle() return Style(Read(Field(C_CVar, "GetCVar") or GetCVar, CVAR)) end
local function Setter() return Field(C_CVar, "SetCVar") or SetCVar end
local function OutOfCombat() return Read(InCombatLockdown) == false end
local function Owner(target) return target == "gamepad" end
local function Coordinator() return ns.GamepadUICompatibility end
local function SavedOwner() return Coordinator().db.profile.enabled == true end
local function Inventory()
	local ids = Read(Field(C_GamePad, "GetAllDeviceIDs"))
	if (type(ids) ~= "table") then return end
	local count = Read(function() return #ids end)
	if (type(count) ~= "number" or count < 0 or count > 64 or count % 1 ~= 0) then return end
	for index = 1, count do
		if (type(Field(ids, index)) ~= "number") then return end
	end
	-- These are logical IDs, not physical-device counts. Unavailable raw state
	-- is not absence, and the active-device ID can remain stale after unplugging.
	return ids, count > 0
end
local function Presence() local _, present = Inventory(); return present end
local function MovementMagnitude(ids)
	if (not ids) then return end
	local maximum
	for _, id in ipairs(ids) do
		local mapped = Read(Field(C_GamePad, "GetDeviceMappedState"), id)
		local count, sticks = Field(mapped, "stickCount"), Field(mapped, "sticks")
		if (type(count) == "number" and count >= 0 and count <= 16 and count % 1 == 0 and type(sticks) == "table") then
			for index = 1, count do
				-- The config API is zero-based; state.sticks is a Lua array.
				if (Read(Field(C_GamePad, "StickIndexToConfigName"), index - 1) == "Movement") then
					local length = Field(Field(sticks, index), "len")
					if (type(length) == "number" and length == length and length >= 0 and length < math.huge) then
						maximum = math.max(maximum or 0, length)
					end
				end
			end
		end
	end
	return maximum
end
local function KeyDown(key) return Read(IsKeyDown, key, true) end
local function KeyboardMovement()
	local modifiers = {}
	for _, modifier in ipairs({ "CTRL", "ALT", "SHIFT" }) do
		local left, right = KeyDown("L" .. modifier), KeyDown("R" .. modifier)
		if (type(left) ~= "boolean" or type(right) ~= "boolean") then return end
		modifiers[modifier] = left or right
	end
	for _, command in ipairs(MOVEMENT) do
		-- Keep every binding return; a generic first-result API wrapper loses
		-- the second movement binding. Unbound WASD keys are not movement.
		local keys = Read(function() return { GetBindingKey(command) } end)
		if (type(keys) ~= "table") then return end
		if (type(keys) == "table") then
			for index = 1, math.min(#keys, 8) do
				local key = Field(keys, index)
				if (type(key) == "string") then
					key = key:upper()
					local required = {}
					for _ = 1, 3 do
						local prefix = key:match("^(%u+)%-")
						if (prefix ~= "CTRL" and prefix ~= "ALT" and prefix ~= "SHIFT") then break end
						required[prefix], key = true, key:sub(#prefix + 2)
					end
					local match = true
					for modifier, down in pairs(modifiers) do
						if (down ~= (required[modifier] == true)) then match = false end
					end
					if (match and not key:find("^PAD") and not key:find("^BUTTON") and not key:find("^MOUSEWHEEL")
						and KeyDown(key) == true) then return true end
				end
			end
		end
	end
	return false
end

InputStyle.GetCurrentStyle = function() return Style(Read(Field(C_InputInterfaceStyle, "GetCurrentStyle"))) end
InputStyle.IsAvailable = function(self)
	return ns.IsForever == true and Coordinator() ~= nil and Coordinator():IsAvailable()
		and type(EnumValue("mnk")) == "number" and type(EnumValue("gamepad")) == "number"
		and EnumValue("mnk") ~= EnumValue("gamepad") and self:GetCurrentStyle() ~= nil and ConfiguredStyle() ~= nil
		and type(Setter()) == "function" and type(Field(C_GamePad, "GetAllDeviceIDs")) == "function"
		and type(Field(C_GamePad, "GetDeviceMappedState")) == "function"
		and type(Field(C_GamePad, "StickIndexToConfigName")) == "function"
		and type(GetBindingKey) == "function" and type(IsKeyDown) == "function"
		and type(IsPlayerMoving) == "function" and type(GetCurrentKeyBoardFocus) == "function"
		and type(Field(C_Timer, "NewTicker")) == "function"
end
InputStyle.IsEnabledSetting = function(self) return self.db ~= nil and self.db.profile.enabled == true end
local function RefreshConflict(self, force)
	local now = Now()
	if (not force and self.conflictValid and now >= self.conflictCheckedAt and now - self.conflictCheckedAt < 1) then
		return self.conflict
	end
	-- IsAddOnEnabled scans the installed addon list. Share one snapshot between
	-- the 10 Hz observer and UI getters; explicit actions always refresh it.
	local conflict
	if (Read(ns.API.IsAddOnEnabled, "GamePadReadySet") == true
		or Read(Field(C_AddOns, "IsAddOnLoaded") or IsAddOnLoaded, "GamePadReadySet") == true) then
		conflict = "GamePadReadySet"
	elseif (Coordinator()) then
		conflict = Coordinator():GetConflict()
	end
	self.conflict, self.conflictCheckedAt, self.conflictValid = conflict, now, true
	return conflict
end
InputStyle.GetConflict = function(self)
	return RefreshConflict(self)
end
local function Gate(self)
	if (not self:IsEnabledSetting()) then return "disabled" end
	if (not self:IsAvailable()) then return "unavailable" end
	if (not self.ready or not Coordinator().db) then return "ownership" end
	if (self.profileName ~= ns.db:GetCurrentProfile()) then return "ownership" end
	if (self:GetConflict()) then return "conflict" end
end
local function Satisfied(self, target)
	return self:GetCurrentStyle() == target and Coordinator():IsActive() == Owner(target)
end
InputStyle.GetPendingStyle = function(self)
	if (self.reloadIssued) then return self.pendingTarget end
	local actual, configured = self:GetCurrentStyle(), ConfiguredStyle()
	if (actual and configured and (actual ~= configured or Coordinator():IsReloadPending())) then return configured end
end
local function Eligible(self)
	return not self.reloadIssued and not Gate(self) and not self:GetPendingStyle() and not self.failed and not self.db.profile.suspended
end
local function Relevant(self)
	if (self.reason == "disconnect") then return Presence() == false end
	return self.candidate == "mnk" or Presence() == true
end
InputStyle.GetSuggestedStyle = function(self)
	if (Eligible(self) and self.stable and self.candidate and self.candidateProfile == ns.db:GetCurrentProfile()
		and not Satisfied(self, self.candidate) and Relevant(self)) then
		return self.candidate
	end
end
InputStyle.GetState = function(self)
	local gate = Gate(self)
	if (gate) then return gate end
	if (self:GetPendingStyle()) then return "pendingReload" end
	if (self.failed) then return "failed" end
	if (self.db.profile.suspended) then return "suspended" end
	if (not OutOfCombat()) then return "combat" end
	if (self.candidate and not self.stable) then return "stabilizing" end
	if (self:GetSuggestedStyle()) then return "suggested" end
	return "observing"
end
local function Cancel(self)
	if (self.candidate) then self.candidateGeneration = (self.candidateGeneration or 0) + 1 end
	self.candidate, self.reason, self.stable, self.candidateSince, self.candidateProfile = nil, nil, nil, nil, nil
end
local function Baseline(self)
	self.observedStyle, self.observedCVar, self.observedOwner = self:GetCurrentStyle(), ConfiguredStyle(), SavedOwner()
end
local function Suspend(self, failed)
	Cancel(self)
	self.db.profile.suspended = true
	self.failed = failed == true or self.failed
end
local function Notify(self)
	local state, suggested, pending = self:GetState(), self:GetSuggestedStyle(), self:GetPendingStyle()
	local signature = state .. ":" .. (self:GetCurrentStyle() or "?") .. ":" .. (suggested or "")
		.. ":" .. (pending or "") .. ":" .. tostring(self.errorText or "") .. ":" .. tostring(self.pendingDismissed)
		.. ":" .. tostring(OutOfCombat()) .. ":" .. tostring(self.applying) .. ":" .. tostring(self.retryTarget)
		.. ":" .. tostring(self.reloadIssued) .. ":" .. tostring(self.candidateGeneration)
	if (signature == self.signature) then return end
	self.signature = signature
	local prompt = ns.InputStylePrompt
	if (not Gate(self) and OutOfCombat() and not self.applying and not self.reloadIssued and prompt) then
		if (suggested) then
			local generation, profile = self.candidateGeneration, self.candidateProfile
			prompt.Show(suggested, function()
				if (self.candidateGeneration ~= generation or ns.db:GetCurrentProfile() ~= profile
					or self:GetSuggestedStyle() ~= suggested) then return false end
				return self:ApplySuggested()
			end, function() self:Dismiss() end)
		elseif (pending and self.pendingTarget and not self.pendingDismissed) then
			local request = self.db.char.request
			prompt.Show(pending, function()
				if (self.db.char.request ~= request or request.profile ~= ns.db:GetCurrentProfile()
					or self:GetPendingStyle() ~= pending) then return false end
				return self:ReloadPending()
			end, function() self:Dismiss() end, self.errorText)
		elseif (self.failed and self.retryTarget) then
			local target, request = self.retryTarget, self.db.char.request
			prompt.Show(target, function()
				if (self.retryTarget ~= target or self.db.char.request ~= request or request.profile ~= ns.db:GetCurrentProfile()
					or not OutOfCombat() or Gate(self) or self:GetPendingStyle()) then return false end
				self.db.profile.suspended, self.failed = false, nil
				self.candidate, self.reason, self.stable = target, "retry", true
				self.candidateProfile = ns.db:GetCurrentProfile()
				return self:ApplySuggested()
			end, function() self:Dismiss() end, self.errorText)
		else prompt.Hide() end
	elseif (prompt) then prompt.Hide() end
	if (ns.Fire) then ns:Fire("OptionsNeedRefresh") end
end
local function Observe(self)
	local actual, configured, owner = self:GetCurrentStyle(), ConfiguredStyle(), SavedOwner()
	local changed = (actual and self.observedStyle and actual ~= self.observedStyle)
		or (configured and self.observedCVar and configured ~= self.observedCVar) or owner ~= self.observedOwner
	if (changed and self:IsEnabledSetting() and not self.applying) then
		local expected = self.pendingTarget and configured == self.pendingTarget and owner == Owner(self.pendingTarget)
		if (not expected) then
			Suspend(self)
			self.retryTarget, self.pendingTarget, self.errorText = nil, nil, nil
		end
		Cancel(self)
	end
	self.observedStyle, self.observedCVar, self.observedOwner = actual, configured, owner
end
local function Candidate(self, target, reason, now)
	if (not target or Satisfied(self, target) or (self.cooldownUntil or 0) > now
		or (reason == "disconnect" and self.dismissedDisconnect) or (reason ~= "disconnect" and self.blocked[target])) then
		Cancel(self); return
	end
	if (self.candidate ~= target or self.reason ~= reason) then
		self.candidateGeneration = (self.candidateGeneration or 0) + 1
		self.candidate, self.reason, self.candidateSince, self.stable = target, reason, now, false
		self.candidateProfile = ns.db:GetCurrentProfile()
	end
	self.stable = OutOfCombat() and now - self.candidateSince >= (reason == "disconnect" and 1.5 or .3)
end
InputStyle.SampleInput = function(self)
	if (not self.ready or self.applying) then return end
	Observe(self)
	if (not Eligible(self)) then Cancel(self); Notify(self); return end
	local now = Now()
	local ids, present = Inventory()
	if (present ~= self.present) then
		if (present == false and self.lastKnownPresent == true) then self.lostDevices = true end
		if (present == true) then self.lostDevices, self.dismissedDisconnect = nil, nil end
		Cancel(self)
	end
	self.present = present
	if (present ~= nil) then self.lastKnownPresent = present end
	local magnitude = MovementMagnitude(ids)
	if (magnitude) then
		self.stickActive = magnitude >= (self.stickActive and .2 or .35)
	elseif (present == false) then self.stickActive = false else self.stickActive = nil end
	local keyboard = KeyboardMovement()
	if (self.stickActive == false) then self.blocked.gamepad = nil end
	if (keyboard == false) then self.blocked.mnk = nil end
	local focus, focusKnown = Read(GetCurrentKeyBoardFocus)
	local keyboardMoving = keyboard and focusKnown == true and focus == nil
	local gamepadMoving = present == true and self.stickActive == true and Read(IsPlayerMoving) == true
	-- Stable prompts survive neutral/mouse navigation, but fresh movement can
	-- replace them. Physical bound keys take priority over mapped-stick noise.
	if (keyboardMoving) then Candidate(self, "mnk", "keyboard", now)
	elseif (self.lostDevices and present == false) then Candidate(self, "mnk", "disconnect", now)
	elseif (gamepadMoving) then Candidate(self, "gamepad", "gamepad", now)
	elseif (self.stable and OutOfCombat()) then
		if (not Relevant(self)) then Cancel(self) end
	else Cancel(self) end
	Notify(self)
end
InputStyle.Dismiss = function(self)
	local target = self.candidate or self.pendingTarget or self.retryTarget
	self.blocked = self.blocked or {}
	if (target) then self.blocked[target] = true end
	if (self.reason == "disconnect") then self.dismissedDisconnect = true end
	self.cooldownUntil, self.pendingDismissed = Now() + 5, true
	self.retryTarget, self.errorText = nil, nil
	Cancel(self)
	Notify(self)
end
InputStyle.CanApply = function(self) return OutOfCombat() and self:GetSuggestedStyle() ~= nil end
local function AttemptReload(self)
	RefreshConflict(self, true)
	if (self.reloadIssued or not OutOfCombat() or Gate(self)) then Notify(self); return false end
	self.blockedAction, self.applying = nil, "reload"
	local ok = pcall(ReloadUI)
	self.applying = nil
	if (not ok or self.blockedAction) then
		self.db.char.request.status = "failed"
		self.errorText = L["Your selection will take effect after /reload outside combat."]
		Suspend(self, true)
	else
		self.reloadIssued = true
	end
	Notify(self)
	return ok and not self.blockedAction
end
InputStyle.ApplySuggested = function(self)
	RefreshConflict(self, true)
	if (not self:CanApply()) then Notify(self); return false end
	local target = self:GetSuggestedStyle()
	if (not target) then return false end
	local request = { target = target, profile = ns.db:GetCurrentProfile(), previousOwnership = SavedOwner(),
		status = "requested", workflowVersion = 2 }
	local generation, ownerProfile = self.generation, Coordinator().db.profile
	self.db.char.request = request
	self.pendingTarget, self.retryTarget, self.pendingDismissed, self.errorText = target, nil, nil, nil
	self.applying, self.blockedAction = "setter", nil
	Cancel(self)
	ownerProfile.enabled = Owner(target)
	-- Save ownership before a setter that may itself initiate a native reload.
	local ok = true
	if (ConfiguredStyle() ~= target) then ok = pcall(Setter(), CVAR, EnumValue(target)) end
	self.applying = nil
	if (self.generation ~= generation or ns.db:GetCurrentProfile() ~= request.profile) then
		-- A callback selected/reset another profile during the setter. Keep its
		-- settings intact and never reload on behalf of the superseded request.
		if (ConfiguredStyle() ~= target) then ownerProfile.enabled = request.previousOwnership end
		request.status = "unconfirmed"
		return false
	end
	if (ConfiguredStyle() ~= target) then
		ownerProfile.enabled = request.previousOwnership
		request.status = "failed"
		self.pendingTarget, self.retryTarget = nil, target
		self.errorText = L["The style change was not confirmed. No automatic retry will occur."]
		Suspend(self, true)
		Baseline(self); Notify(self)
		return false
	end
	Baseline(self)
	if (not ok or self.blockedAction) then
		request.status = "failed"
		self.errorText = L["The style change was not confirmed. No automatic retry will occur."]
		Suspend(self, true); Notify(self)
		return false
	end
	request.status = "requested"
	return AttemptReload(self)
end
InputStyle.CanReload = function(self)
	return not self.reloadIssued and not Gate(self) and OutOfCombat() and self:GetPendingStyle() ~= nil and type(ReloadUI) == "function"
end
InputStyle.ReloadPending = function(self)
	RefreshConflict(self, true)
	if (not self:CanReload()) then Notify(self); return false end
	local target = self:GetPendingStyle()
	local request = self.db.char.request
	if (not request or request.target ~= target or request.profile ~= ns.db:GetCurrentProfile()) then
		request = { target = target, profile = ns.db:GetCurrentProfile(), previousOwnership = SavedOwner(), workflowVersion = 2 }
		self.db.char.request = request
	end
	-- Explicit retry preserves the saved pair and never re-writes the CVar.
	self.pendingTarget, self.pendingDismissed, self.errorText = target, nil, nil
	request.status = "requested"
	Coordinator().db.profile.enabled = Owner(target)
	Baseline(self)
	return AttemptReload(self)
end
InputStyle.SetEnabled = function(self, enabled)
	self.db.profile.enabled, self.db.profile.workflowVersion = enabled == true, 2
	self:UpdateSettings()
end
InputStyle.Resume = function(self)
	self.db.profile.suspended, self.failed = false, nil
	if (self.db.char.request and self.db.char.request.status == "failed") then self.db.char.request.status = "acknowledged" end
	self:UpdateSettings()
end
InputStyle.UpdateSettings = function(self, event)
	self.conflictValid = false
	Cancel(self)
	self.generation = (self.generation or 0) + 1
	if (self.ticker) then pcall(function() self.ticker:Cancel() end); self.ticker = nil end
	self.applying, self.failed, self.pendingTarget, self.retryTarget, self.errorText = nil, nil, nil, nil, nil
	self.blocked, self.stickActive, self.lostDevices, self.dismissedDisconnect = {}, nil, nil, nil
	self.cooldownUntil, self.pendingDismissed = nil, nil
	if (not self.ready) then return end
	self.profileName = ns.db:GetCurrentProfile()
	local profile, request = self.db.profile, self.db.char.request
	if (type(profile.workflowVersion) ~= "number" or profile.workflowVersion < 2) then
		profile.enabled, profile.suspended, profile.workflowVersion = true, false, 2
		if (request and request.profile == ns.db:GetCurrentProfile()) then self.db.char.request = nil end
	elseif ((event == "OnProfileReset" or event == "OnProfileCopied") and request and request.profile == ns.db:GetCurrentProfile()) then
		self.db.char.request = nil
	end
	Baseline(self)
	self.present = Presence()
	self.lastKnownPresent = self.present
	if (self:IsEnabledSetting() and self:IsAvailable()) then
		local generation = self.generation
		self.ticker = C_Timer.NewTicker(.1, function()
			if (self.ready and self.generation == generation) then self:SampleInput() end
		end)
	end
	Notify(self)
end
InputStyle.OnEvent = function(self, event, argument)
	if (event == "ADDON_LOADED") then self.conflictValid = false end
	if (event == "ADDON_ACTION_BLOCKED" or event == "ADDON_ACTION_FORBIDDEN") then
		if (self.applying and Public(argument) == addonName) then
			self.blockedAction = true
			self.db.char.request.status = "failed"
		end
		return
	end
	if (self.applying) then return end
	if (event == "PLAYER_REGEN_DISABLED") then self.stable = false end
	if (event == "CVAR_UPDATE") then
		argument = Public(argument)
		if (type(argument) ~= "string" or argument:lower() ~= CVAR:lower()) then return end
	end
	self:SampleInput()
end
InputStyle.OnInitialize = function(self)
	self.db = ns.db:RegisterNamespace(self:GetName(), self:GetDefaults())
	self:DisableSettingsExport()
	ns.db.RegisterCallback(self, "OnProfileChanged", "UpdateSettings")
	ns.db.RegisterCallback(self, "OnProfileCopied", "UpdateSettings")
	ns.db.RegisterCallback(self, "OnProfileReset", "UpdateSettings")
end
InputStyle.OnEnable = function(self)
	self.ready = true
	self:UpdateSettings()
	local request = self.db.char.request
	if (type(request) == "table" and request.profile == ns.db:GetCurrentProfile()) then
		if (request.status == "requested" or request.status == "failed") then
			if (request.target == ConfiguredStyle() and Satisfied(self, request.target) and SavedOwner() == Owner(request.target)) then
				request.status = "applied"
				self.db.profile.suspended = false
			else
				request.status = "unconfirmed"
				self.db.profile.suspended = true
			end
		end
	end
	if (ns.IsForever == true and not self.observing) then
		self.observing = true
		for _, event in ipairs(EVENTS) do
			if (ns.API.IsEventAvailable(event)) then self:RegisterEvent(event, "OnEvent") end
		end
	end
	Notify(self)
end
InputStyle.OnDisable = function(self)
	self.ready = false
	self:UpdateSettings()
	self.observing = false
	for _, event in ipairs(EVENTS) do self:UnregisterEvent(event, "OnEvent") end
	Notify(self)
end
