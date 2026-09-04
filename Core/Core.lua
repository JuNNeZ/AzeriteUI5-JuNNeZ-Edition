--[[

	The MIT License (MIT)

	Copyright (c) 2026 Lars Norberg

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

-- GLOBALS: CreateFrame, EnableAddOn, DisableAddOn, ReloadUI

local Addon, ns = ...

local LibDeflate = LibStub("LibDeflate")
--local LEMO = LibStub("LibEditModeOverride-1.0", true)

ns = LibStub("AceAddon-3.0"):NewAddon(ns, Addon, "LibMoreEvents-1.0", "AceConsole-3.0", "AceComm-3.0", "AceSerializer-3.0")
ns.callbacks = LibStub("CallbackHandler-1.0"):New(ns, nil, nil, false)
ns.Hider = CreateFrame("Frame"); ns.Hider:Hide()
ns.Noop = function() end

-- Compatibility alias:
-- external addons (for example AzUI_Color_Picker) may call AceAddon:GetAddon("AzeriteUI")
-- even when this edition is loaded under a different addon name.
do
	local AceAddon = LibStub("AceAddon-3.0", true)
	if (AceAddon and AceAddon.addons and Addon ~= "AzeriteUI") then
		local existing = AceAddon.addons["AzeriteUI"]
		if (existing == nil or existing == ns) then
			AceAddon.addons["AzeriteUI"] = ns
		end
	end
end

-- Increasing this number forces a full settings reset.
ns.SETTINGS_VERSION = 25 -- retail-only build, no client-dependent branching needed.

-- Tinkerers rejoyce!
_G[Addon] = ns

-- Keep legacy global name for XML/scripts and third-party compatibility.
-- The addon folder/project can be renamed, but many internal templates and
-- external integrations still reference the historic AzeriteUI global key.
_G["AzeriteUI"] = ns

-- Lua API
local next = next
local select = select
local tonumber = tonumber
local tostring = tostring
local type = type

local defaults = {
	char = {
		profile = ns.Prefix,
		showStartupMessage = true
	},
	global = {
		version = -1
	},
	profile = {
		autoLoadEditModeLayout = true,
		editModeLayout = ns.Prefix
	}
}

local SAIYARATT_PROFILE_KEY = "SaiyaRatt"
local BUILTIN_PROFILE_KEYS = {
	[ns.Prefix] = true,
	[SAIYARATT_PROFILE_KEY] = true
}

local GetSavedProfile = function(db, profileKey)
	local sv = db and db.sv
	local profiles = sv and sv.profiles
	return profiles and profiles[profileKey]
end

ns.exportableSettings, ns.exportableLayouts = {}, {}

-- Proxy method to avoid modules using the callback object directly
ns.Fire = function(self, name, ...)
	self.callbacks:Fire(name, ...)
end

ns.ResetSettings = function(self, noreload)
	self.db:ResetDB(self:GetDefaultProfile())
	self.db.global.version = ns.SETTINGS_VERSION
	if (not noreload) then
		ReloadUI()
	end
end

ns.ProfileExists = function(self, targetProfileKey)
	for _,profileKey in next,self:GetProfiles() do
		if (profileKey == targetProfileKey) then
			return true
		end
	end
end

ns.DuplicateProfile = function(self, newProfileKey, sourceProfileKey)
	if (not sourceProfileKey) then
		sourceProfileKey = self.db:GetCurrentProfile()
	end
	if (self:ProfileExists(newProfileKey) or not self:ProfileExists(sourceProfileKey)) then
		return
	end
	self.db:SetProfile(newProfileKey)
	self.db:CopyProfile(sourceProfileKey)
end

ns.CopyProfile = function(self, sourceProfileKey)
	local currentProfileKey = self.db:GetCurrentProfile()
	if (sourceProfileKey == currentProfileKey) then
		return
	end
	for _,profileKey in next,self:GetProfiles() do
		if (profileKey == sourceProfileKey) then
			self.db:CopyProfile(sourceProfileKey)
			return
		end
	end
end

ns.DeleteProfile = function(self, targetProfileKey)
	local currentProfileKey = self.db:GetCurrentProfile()
	if (targetProfileKey == "Default" or self:IsBuiltinProfile(targetProfileKey)) then
		return
	end
	for _,profileKey in next,self:GetProfiles() do
		if (profileKey == targetProfileKey) then
			if (profileKey == currentProfileKey) then
				self.db:SetProfile("Default")
			end
			self.db:DeleteProfile(targetProfileKey)
			return
		end
	end
end

ns.ResetProfile = function(self)
	self.db:ResetProfile()
	if (self:IsSaiyaRattProfile()) then
		self:ApplySaiyaRattPreset()
	end
end

ns.SetProfile = function(self, newProfileKey)
	local currentProfileKey = self.db:GetCurrentProfile()
	if (newProfileKey == currentProfileKey) then
		return
	end
	self.db:SetProfile(newProfileKey)
end

ns.GetProfile = function(self)
	return self.db:GetCurrentProfile()
end

ns.GetProfiles = function(self)
	local profiles = self.db:GetProfiles()
	return profiles
end

ns.GetDefaultProfile = function(self)
	return ns.Prefix
end

ns.IsBuiltinProfile = function(self, profileKey)
	profileKey = profileKey or self:GetProfile()
	return BUILTIN_PROFILE_KEYS[profileKey] and true or false
end

ns.GetActiveConfigVariant = function(self)
	local profileKey = self.db and self.db.GetCurrentProfile and self.db:GetCurrentProfile()
	if (profileKey == SAIYARATT_PROFILE_KEY) then
		return "SaiyaRatt"
	end
	local profile = self.db and self.db.profile
	local preset = profile and profile.stylePreset
	if (type(preset) == "string" and preset ~= "") then
		return preset
	end
end

ns.IsSaiyaRattProfile = function(self, profileKey)
	if (type(profileKey) == "string" and profileKey ~= "") then
		if (profileKey == SAIYARATT_PROFILE_KEY) then
			return true
		end
		local savedProfile = GetSavedProfile(self.db, profileKey)
		return type(savedProfile) == "table" and savedProfile.stylePreset == "SaiyaRatt"
	end
	return self:GetActiveConfigVariant() == "SaiyaRatt"
end

ns.SaiyaRattSlash = function(self)
	local currentProfile = self.db and self.db.GetCurrentProfile and self.db:GetCurrentProfile() or "unknown"
	local activeVariant = self.GetActiveConfigVariant and self:GetActiveConfigVariant() or "Azerite"
	local isSaiyaRatt = self.IsSaiyaRattProfile and self:IsSaiyaRattProfile()

	local messages = {
		"|cffff7b00SaiyaRatt Exposition engaged.|r",
		"|cffd8d8d8Mana crystal status:|r replaced with one unnecessarily dramatic bar.",
		"|cffd8d8d8Target crystal status:|r percent aggressively centered.",
		"|cffd8d8d8Threat glow status:|r hopefully visible only when the universe truly means it."
	}

	if (RaidNotice_AddMessage and RaidWarningFrame) then
		RaidNotice_AddMessage(RaidWarningFrame, "SaiyaRatt Exposition", ChatTypeInfo["RAID_WARNING"])
	end

	if (UIErrorsFrame and UIErrorsFrame.AddMessage) then
		UIErrorsFrame:AddMessage("Mana crystal converted. Excess delivered.", 1, .82, .2, 1)
	end

	for _,message in next,messages do
		print(message)
	end

	print("|cffd8d8d8Profile:|r", tostring(currentProfile), "|cffd8d8d8Variant:|r", tostring(activeVariant), "|cffd8d8d8SaiyaRatt:|r", isSaiyaRatt and "YES" or "NO")

	local playerAlt = self:GetModule("PlayerFrameAlternate", true)
	if (playerAlt and playerAlt.Update and playerAlt.frame) then
		playerAlt:Update()
	end

	local target = self:GetModule("TargetFrame", true)
	if (target and target.Update and target.frame) then
		target:Update()
	end
end

ns.ApplySaiyaRattPreset = function(self)
	if (not self.db or not self.db.profile) then
		return
	end

	self.db.profile.stylePreset = "SaiyaRatt"
	self.db.profile.autoLoadEditModeLayout = true
	self.db.profile.editModeLayout = ns.Prefix

	local PlayerFrame = self:GetModule("PlayerFrame", true)
	if (PlayerFrame and PlayerFrame.db and PlayerFrame.db.profile) then
		PlayerFrame.db.profile.enabled = false
	end

	local PlayerFrameAlternate = self:GetModule("PlayerFrameAlternate", true)
	if (PlayerFrameAlternate and PlayerFrameAlternate.db and PlayerFrameAlternate.db.profile) then
		PlayerFrameAlternate.db.profile.enabled = true
	end

	local Minimap = self:GetModule("Minimap", true)
	if (Minimap and Minimap.db and Minimap.db.profile) then
		Minimap.db.profile.theme = "Azerite"
	end
end

ns.EnsureBuiltinProfiles = function(self)
	if (not self.db) then
		return
	end

	local savedProfile = GetSavedProfile(self.db, SAIYARATT_PROFILE_KEY)
	if (type(savedProfile) == "table" and savedProfile.stylePreset == "SaiyaRatt") then
		return
	end

	local currentProfileKey = self.db:GetCurrentProfile()
	local charProfileKey = self.db.char.profile

	self.db:SetProfile(SAIYARATT_PROFILE_KEY)
	self:ApplySaiyaRattPreset()

	if (currentProfileKey and currentProfileKey ~= SAIYARATT_PROFILE_KEY) then
		self.db:SetProfile(currentProfileKey)
	end
	self.db.char.profile = charProfileKey or currentProfileKey or self:GetDefaultProfile()
end

-- Bump when the container shape below changes in a way older builds cannot
-- read. Profile contents are versioned separately by ns.SETTINGS_VERSION.
ns.EXPORT_VERSION = 1

-- Collects the modules that opted into export, optionally narrowed to the
-- names passed in. Returns a name-keyed set, or nil for "everything".
local GetExportModuleFilter = function(...)
	local numModules = select("#", ...)
	if (numModules < 1) then return end

	local moduleList = {}
	for i = 1, numModules do
		local name = select(i, ...)
		if (type(name) == "string") then
			moduleList[name] = true
		end
	end
	return moduleList
end

-- Serializes the current profile into a single printable string.
-- Pass module names to export only those, or nothing for the whole profile.
ns.Export = function(self, ...)
	local moduleList = GetExportModuleFilter(...)

	local container = {
		version = ns.EXPORT_VERSION,
		addon = ns.Prefix,
		settingsVersion = ns.SETTINGS_VERSION,
		profile = self.db and self.db.profile and ns:Copy(self.db.profile) or nil,
		modules = {}
	}

	-- Walk the live module list rather than the opt-in tables: export is opt
	-- out, and each module decides for itself via IsSettingsExportable and
	-- IsLayoutExportable. See Core/ModulePrototype.lua.
	for moduleName,module in self:IterateModules() do
		if (not moduleList or moduleList[moduleName]) then
			if (module.GetExportData) then
				local settings, layout = module:GetExportData()
				if (settings or layout) then
					container.modules[moduleName] = {
						settings = settings,
						layout = layout
					}
				end
			end
		end
	end

	if (not next(container.modules) and not container.profile) then return end

	local serialized = self:Serialize(container)
	local compressed = LibDeflate:CompressDeflate(serialized)

	return LibDeflate:EncodeForPrint(compressed)
end

-- Layout-only export, for sharing frame placement without settings.
ns.ExportLayouts = function(self, ...)
	local moduleList = GetExportModuleFilter(...)

	local container = {
		version = ns.EXPORT_VERSION,
		addon = ns.Prefix,
		settingsVersion = ns.SETTINGS_VERSION,
		modules = {}
	}

	for moduleName,module in self:IterateModules() do
		if (not moduleList or moduleList[moduleName]) then
			if (module.GetExportData) then
				local _, layout = module:GetExportData()
				if (layout) then
					container.modules[moduleName] = { layout = layout }
				end
			end
		end
	end

	if (not next(container.modules)) then return end

	local serialized = self:Serialize(container)
	local compressed = LibDeflate:CompressDeflate(serialized)

	return LibDeflate:EncodeForPrint(compressed)
end

-- Decodes an export string without applying it. Returns the container table,
-- or nil plus a reason string. Kept separate from Import so the options panel
-- can validate what was pasted before offering to apply it.
ns.DecodeImport = function(self, encoded)
	if (type(encoded) ~= "string") then
		return nil, "malformed"
	end

	-- Copy/paste routinely drags whitespace and newlines along with it.
	encoded = encoded:gsub("%s+", "")
	if (encoded == "") then
		return nil, "malformed"
	end

	local compressed = LibDeflate:DecodeForPrint(encoded)
	if (not compressed) then
		return nil, "malformed"
	end

	local serialized = LibDeflate:DecompressDeflate(compressed)
	if (not serialized) then
		return nil, "malformed"
	end

	local success, container = self:Deserialize(serialized)
	if (not success or type(container) ~= "table") then
		return nil, "malformed"
	end

	if (type(container.modules) ~= "table" and type(container.profile) ~= "table") then
		return nil, "malformed"
	end

	if (tonumber(container.version) and tonumber(container.version) > ns.EXPORT_VERSION) then
		return nil, "newer"
	end

	return container
end

-- Applies an export string onto the currently active profile.
-- Returns true plus the number of modules touched, or nil plus a reason.
ns.Import = function(self, encoded)
	local container, reason = self:DecodeImport(encoded)
	if (not container) then
		return nil, reason
	end

	-- The addon's own profile keys, merged the same defensive way the modules
	-- are: only keys the current build knows about are copied across.
	if (type(container.profile) == "table" and self.db and self.db.profile) then
		for key in next,defaults.profile do
			if (container.profile[key] ~= nil) then
				self.db.profile[key] = container.profile[key]
			end
		end
	end

	local imported = 0
	if (type(container.modules) == "table") then
		for moduleName,data in next,container.modules do
			if (type(data) == "table") then
				local module = self:GetModule(moduleName, true)
				if (module and module.ImportData) then
					if (module:ImportData(data.settings, data.layout)) then
						imported = imported + 1
					end
				end
			end
		end
	end

	return true, imported
end

ns.RefreshConfig = function(self, event, ...)
	if (event == "OnNewProfile") then
		--local db, profileKey = ...

	elseif (event == "OnProfileChanged") then
		local db, newProfileKey = ...

		db.char.profile = newProfileKey

	elseif (event == "OnProfileCopied") then
		--local db, sourceProfileKey = ...

	elseif (event == "OnProfileReset") then
		--local db = ...

	end
end

ns.OnEnable = function(self)
	self:EnsureBuiltinProfiles()
	self.db:SetProfile(self.db.char.profile)
end

ns.OnInitialize = function(self)
	self.db = LibStub("AceDB-3.0-GE"):New("AzeriteUI5_DB", defaults, self:GetDefaultProfile())

	if (self.db.global.version < ns.SETTINGS_VERSION) then
		self:ResetSettings(true)
	end

	self.db.RegisterCallback(self, "OnNewProfile", "RefreshConfig")
	self.db.RegisterCallback(self, "OnProfileChanged", "RefreshConfig")
	self.db.RegisterCallback(self, "OnProfileCopied", "RefreshConfig")
	self.db.RegisterCallback(self, "OnProfileReset", "RefreshConfig")

	self:RegisterChatCommand("resetsettings", function() self:ResetSettings() end)
	self:RegisterChatCommand("saiyaratt", function() self:SaiyaRattSlash() end)
end
