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
local _, ns = ...

local Compressor, Serializer = LibStub("LibDeflate"), LibStub("AceSerializer-3.0")

-- Lua API
local pairs = pairs
local type = type

local defaults = { enabled = true }

local Module =  { defaults = defaults }

ns.ModulePrototype = Module

Module.GetDefaults = function(self)
	if (self.GenerateDefaults) then
		return self:GenerateDefaults()
	end
	return self.defaults
end

-- GetDefaults returns the AceDB shaped wrapper, `{ profile = { ... } }`, since
-- that is what RegisterNamespace is handed. Everything that walks defaults
-- alongside `self.db.profile` needs the inner table, not the wrapper, or it
-- ends up treating "profile" as a settings key and nesting the whole tree.
-- The prototype's own placeholder default is unwrapped, hence the fallback.
Module.GetProfileDefaults = function(self)
	local defaults = self:GetDefaults()
	if (type(defaults) ~= "table") then return end
	if (type(defaults.profile) == "table") then
		return defaults.profile
	end
	return defaults
end

-- Modules that never belong in a shared profile string. These hold machine
-- local or session state rather than anything another player would want.
local neverExportable = {
	Debugging = true,
	Development = true,
	Experimental = true,
	Options = true
}

Module.EnableSettingsExport = function(self)
	ns.exportableSettings[self:GetName()] = true
end

Module.EnableLayoutExport = function(self)
	ns.exportableLayouts[self:GetName()] = true
end

Module.DisableSettingsExport = function(self)
	ns.exportableSettings[self:GetName()] = false
end

Module.DisableLayoutExport = function(self)
	ns.exportableLayouts[self:GetName()] = false
end

-- Export is opt out, not opt in. A profile string is expected to carry the
-- whole interface, so anything holding a settings profile takes part unless
-- it says otherwise. The Enable*/Disable* pair above still overrides this.
Module.IsSettingsExportable = function(self)
	local name = self:GetName()
	if (neverExportable[name]) then return false end
	if (ns.exportableSettings[name] ~= nil) then
		return ns.exportableSettings[name] and true or false
	end
	return (self.db and self.db.profile) and true or false
end

-- Layouts only mean something for modules that actually save a position.
Module.IsLayoutExportable = function(self)
	local name = self:GetName()
	if (neverExportable[name]) then return false end
	if (ns.exportableLayouts[name] ~= nil) then
		return ns.exportableLayouts[name] and true or false
	end
	if (not self.db or not self.db.profile) then return false end
	local defaults = self:GetProfileDefaults()
	return (defaults and type(defaults.savedPosition) == "table") and true or false
end

-- Returns this module's exportable data as plain tables, or nil when the
-- module has opted out. The addon level packs these into a single container
-- and encodes once; the per-module Export* methods below stay string based
-- for anything that wants one module on its own.
Module.GetExportData = function(self)
	local db = self.db and self.db.profile
	if (not db) then return end

	local defaults = self:GetProfileDefaults()
	if (not defaults) then return end

	local settings, layout

	if (self:IsSettingsExportable()) then
		settings = ns:PurgeKeys(ns:Merge(ns:Copy(db), defaults), "savedPosition")
	end

	if (self:IsLayoutExportable()) then
		layout = ns:PurgeOtherKeys(ns:Merge(ns:Copy(db), defaults), "savedPosition")
	end

	if (settings or layout) then
		return settings, layout
	end
end

Module.Export = function(self)
	return self:ExportSettings(), self:ExportLayouts()
end

Module.ExportLayouts = function(self)
	if (not self:IsLayoutExportable()) then return end

	local _, layout = self:GetExportData()
	if (not layout) then return end

	local serialized = Serializer:Serialize(layout)
	local compressed = Compressor:CompressDeflate(serialized)
	local encoded = Compressor:EncodeForPrint(compressed)

	return encoded
end

Module.ExportSettings = function(self)
	if (not self:IsSettingsExportable()) then return end

	local settings = self:GetExportData()
	if (not settings) then return end

	local serialized = Serializer:Serialize(settings)
	local compressed = Compressor:CompressDeflate(serialized)
	local encoded = Compressor:EncodeForPrint(compressed)

	return encoded
end

-- Applies decoded tables onto this module's profile. Both arguments are
-- optional; a string carrying only settings leaves positions alone, and one
-- carrying only layouts leaves everything else alone.
Module.ImportData = function(self, settings, layout)
	if (not self.db or not self.db.profile) then return end

	local imported

	if (settings and self:IsSettingsExportable()) then
		self:MergeSettings(nil, settings)
		imported = true
	end

	if (layout and self:IsLayoutExportable()) then
		self:MergeLayouts(nil, layout)
		imported = true
	end

	return imported
end

Module.Import = function(self, importString)
	if (type(importString) ~= "string") then return end

	local compressed = Compressor:DecodeForPrint(importString)
	if (not compressed) then return end

	local serialized = Compressor:DecompressDeflate(compressed)
	if (not serialized) then return end

	local success, data = Serializer:Deserialize(serialized)
	if (not success or type(data) ~= "table") then return end

	-- A single module string is ambiguous by itself, so route it by content:
	-- a table holding savedPosition is a layout, anything else is settings.
	if (data.savedPosition) then
		return self:ImportData(nil, data)
	end
	return self:ImportData(data, nil)
end

Module.MergeLayouts = function(self, target, source, fallback)
	local db = target or self.db.profile
	if (not db) then return end

	local defaults = fallback or self:GetProfileDefaults()
	if (not defaults) then return end

	-- An imported string is allowed to omit branches entirely, so every read
	-- from the source has to survive a missing table rather than index nil.
	if (type(source) ~= "table") then source = {} end

	-- Iterate default table
	-- to catch nilled out entries.
	for k in pairs(defaults) do

		-- Only merge layout data.
		if (k == "savedPosition") then

			local layoutTarget = db[k]
			local layoutSource = source[k]
			local layoutFallback = defaults[k]

			if (type(layoutTarget) ~= "table") then
				layoutTarget = {}
				db[k] = layoutTarget
			end
			if (type(layoutSource) ~= "table") then layoutSource = {} end
			if (type(layoutFallback) ~= "table") then layoutFallback = {} end

			for i in pairs(layoutFallback) do

				-- Import anything that's not nil.
				if (layoutSource[i] ~= nil) then
					layoutTarget[i] = layoutSource[i]
				else
					-- Fallback to defaults for
					-- entries that are nil in the source.
					layoutTarget[i] = layoutFallback[i]
				end
			end

		end
	end

	return db
end

Module.MergeSettings = function(self, target, source, fallback)
	local db = target or self.db.profile
	if (not db) then return end

	local defaults = fallback or self:GetProfileDefaults()
	if (not defaults) then return end

	-- See the note in MergeLayouts: an imported string may omit whole branches.
	if (type(source) ~= "table") then source = {} end

	-- Iterate default table
	-- to catch nilled out entries.
	for k in pairs(defaults) do

		-- Just ignore the layout tables in this method.
		if (k ~= "savedPosition") then

			-- Deep merge. The branch has to exist before recursing: a nil
			-- target makes the recursive call fall back to the module's whole
			-- profile and merge the subtable's defaults onto the top level.
			if (type(defaults[k]) == "table") then
				if (type(db[k]) ~= "table") then
					db[k] = {}
				end
				db[k] = self:MergeSettings(db[k], source[k], defaults[k])
			else
				-- Import anything that's not nil.
				if (source[k] ~= nil) then
					db[k] = source[k]
				else
					-- Fallback to defaults for
					-- entries that are nil in the source.
					db[k] = defaults[k]
				end
			end
		end

	end

	return db
end

ns:SetDefaultModulePrototype(ns.ModulePrototype)
