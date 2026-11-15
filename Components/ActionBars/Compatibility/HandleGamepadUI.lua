local _, ns = ...

-- Forever 1.60.1.70938: Blizzard_GamepadActionBars owns its storage, binding
-- contexts and pet/stance overrides. This is a session-level handoff of ALL
-- action bars, including native keyboard/mouse bars when the UI style changes.
-- Never transfer protected frames or override bindings from an input callback.
-- See Blizzard_SharedXML/Mainline/InputUtil.lua and Blizzard_GamepadActionBars.
local Compatibility = ns:NewModule("GamepadUICompatibility", "LibMoreEvents-1.0")
ns.GamepadUICompatibility = Compatibility

Compatibility.defaults = { profile = { enabled = false } }

local active
local appliedSetting
local rivals = { "ConsolePort", "ConsolePort_Bar", "Bartender4" }

Compatibility.IsAvailable = function()
	return ns.IsForever == true
		and type(C_GamepadUI) == "table"
		and type(C_GamepadUI.GetFirstGamepadActionStorageSlotIndex) == "function"
		and type(C_GamepadUI.GetFirstGamepadPetActionStorageSlotIndex) == "function"
		and type(C_InputInterfaceStyle) == "table"
		and type(C_InputInterfaceStyle.GetCurrentStyle) == "function"
		and type(Enum) == "table"
		and type(Enum.InputDeviceInterfaceType) == "table"
		and Enum.InputDeviceInterfaceType.Gamepad ~= nil
end

Compatibility.GetConflict = function()
	for _, name in ipairs(rivals) do
		if (ns.API.IsAddOnEnabled(name)) then return name end
	end
end

Compatibility.IsActive = function()
	-- Before OnEnable this deliberately does not decide anything: the parent
	-- addon selects the character's profile after module OnInitialize callbacks.
	return active == true
end

Compatibility.IsReloadPending = function(self)
	return appliedSetting ~= nil and self.db ~= nil
		and (self.db.profile.enabled == true) ~= appliedSetting
end

Compatibility.IsGamepadMode = function(self)
	return self:IsAvailable()
		and C_InputInterfaceStyle.GetCurrentStyle() == Enum.InputDeviceInterfaceType.Gamepad
end

Compatibility.ObserveInterface = function(self, event, addon)
	if (event == "ADDON_LOADED" and addon ~= "Blizzard_GamepadActionBars") then return end
	-- Observation only, also safe during combat. The native frame can load later
	-- than us; its absence must not cause us to install permanent hiding hooks.
	self.gamepadMode = self:IsGamepadMode() and true or false
	self.nativeFrameReady = _G.GamepadMainActionBarFrame ~= nil
end

Compatibility.OnInitialize = function(self)
	self.db = ns.db:RegisterNamespace(self:GetName(), self:GetDefaults())
end

Compatibility.OnEnable = function(self)
	if (active == nil) then
		appliedSetting = self.db.profile.enabled == true
		active = appliedSetting and self:IsAvailable() and not self:GetConflict() or false
	end
	self:ObserveInterface()
	if (not self.observing and ns.IsForever) then
		self.observing = true
		self:RegisterEvent("ADDON_LOADED", "ObserveInterface")
		self:RegisterEvent("PLAYER_ENTERING_WORLD", "ObserveInterface")
		if (self:IsAvailable() and ns.API.IsEventAvailable("INPUT_DEVICE_INTERFACE_TRANSITION")) then
			self:RegisterEvent("INPUT_DEVICE_INTERFACE_TRANSITION", "ObserveInterface")
		end
	end
end
