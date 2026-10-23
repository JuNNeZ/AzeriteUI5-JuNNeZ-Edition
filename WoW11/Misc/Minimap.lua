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

if (not ns.WoW11) then return end

local MinimapMod = ns:GetModule("Minimap", true)
if (not MinimapMod) then return end

MinimapMod:SetEnabledState(false)

MinimapMod.OnInitialize = function(self)
	self:RegisterEvent("PLAYER_ENTERING_WORLD", "DelayedEnable")
end

MinimapMod.DelayedEnable = function(self)
	self:UnregisterEvent("PLAYER_ENTERING_WORLD", "DelayedEnable")

	-- Initialize the database
	-- Same path as the movable module prototype, so Legacy gets its own minimap
	-- namespace and corner default instead of writing the main profile.
	self.db = ns.LegacyHUD and ns.LegacyHUD:RegisterNamespace(self:GetName(), self:GetDefaults())
		or ns.db:RegisterNamespace(self:GetName(), self:GetDefaults())
	self.db.RegisterCallback(self, "OnProfileChanged", "OnRefreshConfig")
	self.db.RegisterCallback(self, "OnProfileCopied", "OnRefreshConfig")
	self.db.RegisterCallback(self, "OnProfileReset", "OnRefreshConfig")

	-- If minimap customization is disabled, don't enable the module
	if (not self.db.profile.enabled) then 
		return
	end

	self:Enable()

	-- Manually enable the XP bars,
	-- in case they were unable to previously load
	-- because of the delayed Minimap module start.
	local PlayerStatusBars = ns:GetModule("PlayerStatusBars", true)
	if (PlayerStatusBars and not PlayerStatusBars:IsEnabled()) then
		PlayerStatusBars:Enable()
	end
end

-- The object tables come from Components/Misc/Minimap.lua alone. A copy here replaced them on both clients
-- (this file loads later) and dropped the Bartender4 queue-eye guard and MicroMenuContainer (FixLog 2026-10-23).
