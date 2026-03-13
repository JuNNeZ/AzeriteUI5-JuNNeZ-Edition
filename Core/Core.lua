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
ns.SETTINGS_VERSION = ns.WoW11 and 25 or 22 -- use client dependant settings version to avoid resets in unaffected builds.

-- Tinkerers rejoyce!
_G[Addon] = ns

-- Keep legacy global name for XML/scripts and third-party compatibility.
-- The addon folder/project can be renamed, but many internal templates and
-- external integrations still reference the historic AzeriteUI global key.
_G["AzeriteUI"] = ns

-- Lua API
local next = next
local select = select
local tostring = tostring

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

ns.Export = function(self, ...)

	-- Decide which modules to export.
	local numModules = select("#", ...)
	local moduleList

	if (numModules > 0) then
		moduleList = {}

		for i = 1, numModules do
			moduleList[(select(i, ...))] = true
		end
	end

	for moduleName in next,ns.exportableSettings do
		if (not moduleList or moduleList[moduleName]) then

			-- serialize, compress and encode
			local module = self:GetModule(moduleName, true)
			if (module) then
				local data
			end

			-- prefix and add to export table
		end
	end

	for moduleName in next,ns.exportableLayouts do
		if (not moduleList or moduleList[moduleName]) then

			-- serialize, compress and encode
			local module = self:GetModule(moduleName, true)
			if (module) then

			end

			-- prefix and add to export table
		end
	end

end

ns.ExportLayouts = function(self, ...)
	local modules = {}

end

ns.Import = function(self, encoded)

	local compressed = LibDeflate:DecodeForPrint(encoded)
	local serialized = LibDeflate:DecompressDeflate(compressed)
	local success, table = self:Deserialize(serialized)

	if (success) then


		local currentProfileKey = self.db:GetCurrentProfile()

	end

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
