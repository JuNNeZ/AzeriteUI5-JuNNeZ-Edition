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
local Addon, ns = ...

-- Lua API
local string_find = string.find
local string_match = string.match
local string_split = string.split
local tonumber = tonumber

-- GLOBALS: GetBuildInfo, GetRealmName, UnitClass, UnitNameUnmodified

-- Addon version
------------------------------------------------------
-- Read from toc metadata so it always matches the installed version.
local version = C_AddOns and C_AddOns.GetAddOnMetadata(Addon, "Version") or GetAddOnMetadata(Addon, "Version") or "5.3.60-JuNNeZ"
if (version:find("project%-version")) then
	version = "Development"
end
ns.Private.Version = version
ns.Private.IsDevelopment = version == "Development"
ns.Private.IsAlpha = string_find(version, "%-Alpha$")
ns.Private.IsBeta =string_find(version, "%-Beta$")
ns.Private.IsRC = string_find(version, "%-RC$")
ns.Private.IsRelease = string_find(version, "%-Release$")

-- WoW client version
------------------------------------------------------
local patch, build, date, version = GetBuildInfo()
local major, minor, micro = string_split(".", patch)

ns.Private.ClientVersion = version
ns.Private.ClientDate = date
ns.Private.ClientPatch = patch
ns.Private.ClientMajor = tonumber(major)
ns.Private.ClientMinor = tonumber(minor)
ns.Private.ClientMicro = tonumber(micro)
ns.Private.ClientBuild = tonumber(build)

-- Simple flags for client version checks (retail-only build)
ns.Private.IsRetail = true
ns.Private.WoW10 = true
ns.Private.WoW11 = true

-- Developer Mode constants
------------------------------------------------------
ns.Private.IsInTestMode = false
ns.Private.IsVerboseMode = IsShiftKeyDown()

-- Prefix for frame names
------------------------------------------------------
ns.Private.Prefix = string_match(Addon, "^(.*)UI") or Addon

-- Player constants
------------------------------------------------------
local _,playerClass = UnitClass("player")
ns.Private.PlayerClass = playerClass
ns.Private.PlayerRealm = GetRealmName()
ns.Private.PlayerName = UnitNameUnmodified("player")
