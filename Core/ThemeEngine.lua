--[[

	The MIT License (MIT)

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
local Addon, ns = ...

--[[
	The theme engine (Docs/Theme Engine Plan.md): one place the interface asks about
	themes, and the parts every theme shares.

	Unit frames, nameplates, the minimap, the micro menu and the layouts call the
	engine's hooks (StyleHealth, GetConfig, ResolveMedia, ...). The engine hands each
	call to the one theme in use, or answers as stock AzeriteUI when none is. Before
	this, PaladinTheme.lua was that switchboard, forwarding every hook to Hunter and
	Mage first; a fourth theme would have meant a fourth forwarding line in each.

	A theme registers itself with a priority (lower wins when two say they are active;
	Hunter, Mage, Paladin as before) and implements the hooks it needs. The shared
	parts live here: the layout copy, the media swap with its tint rule, the main-
	layout gate, endcap settings, the reload on profile change and the options window
	borders.

	Effects that one theme lends to another (Lite+: a Paladin crystal on a Mage
	interface) stay theme methods; Core/ThemeEffects.lua calls them directly.
]]

local Engine = {}
ns.ThemeEngine = Engine

-- Fixed ornament slots, in native layout units. New drop-in themes use these
-- shared boxes; material and artwork never choose a second layout.
Engine.OrnamentSlots = {
	Health = { size = 88, x = 14, y = 0, reference = 40 },
	CastHead = { size = 48, x = -26, y = 0 },
	ResourceBadge = { size = 32, yFraction = .06 },
	North = { size = 32 }
}

-- Fitted cast boots contain their own solid socket. Unlike the old detached
-- emblems, the socket overlaps the left termination. Paladin's established
-- slot/art pairing is retained; health uses the same slot as Paladin.
Engine.FittedCastSlot = { size = 48, x = -8, y = 0 }

--- Full-casing ornaments share the backdrop's measured dip, including mirrors.
--- Scale around that point so changing size cannot create a second lower tip.
Engine.PlaceAlignedHealthEndcap = function(self, art, backdrop, dip, flip, ratio, dx, dy)
	if (not art or not backdrop or not dip) then return false end
	local width, height = backdrop:GetWidth(), backdrop:GetHeight()
	local x = flip and 1-dip[1] or dip[1]
	art:ClearAllPoints()
	art:SetSize(width*ratio, height*ratio)
	art:SetPoint("TOPLEFT", backdrop, "TOPLEFT",
		(1-ratio)*x*width + (flip and -dx or dx), -(1-ratio)*dip[2]*height + dy)
	art:SetTexCoord(flip and 1 or 0, flip and 0 or 1, 0, 1)
	return true
end

--- Draw a measured full-casing cap while retaining the complete original dip.
Engine.StyleAlignedHealthEndcap = function(self, frame, art, bar, path, key, dips, flip, scale, dx, dy)
	local assembly = bar.ThemeEndcapAssembly
	local name = assembly and assembly.name:gsub("%-fitted$", "")
	local dip = name and dips[name]
	local enabled = key ~= "none" and dip ~= nil
	self:SetEndcapTerminal(bar, false)
	frame.EndcapShown = enabled
	frame:SetShown(enabled)
	if (frame.Threat) then frame.Threat:SetShown(enabled and frame.ThreatSource:IsShown()) end
	if (not enabled) then return end
	local texture = "ornament-"..key.."-"..name
	frame.EndcapTextureName = texture
	art:SetTexture(path(texture))
	self:PlaceAlignedHealthEndcap(art, bar.Backdrop, dip, flip, scale/1.3, dx, dy)
	if (frame.Threat) then
		frame.Threat:SetTexture(path(texture.."-glow"))
		frame.Threat:SetTexCoord(flip and 1 or 0, flip and 0 or 1, 0, 1)
	end
end

--- Select the mounting shoulder or complete bare terminal, including its halo.
--- The theme registers only its own decorative regions; fills stay untouched.
Engine.SetEndcapTerminal = function(self, bar, enabled)
	local assembly = bar.ThemeEndcapAssembly
	if (not assembly) then return end
	local name = assembly.name..(enabled and "-capped" or "")
	assembly.back:SetTexture(assembly.path(name))
	if (assembly.front) then assembly.front:SetTexture(assembly.path(name.."-over")) end
	if (assembly.threat) then
		assembly.threat:SetTexture(enabled and assembly.path(name.."-glow")
			or assembly.bareThreat or assembly.path(assembly.glow))
	end
end

Engine.SetCastEndcapTerminal = function(self, cast, path, enabled, front, shieldFront)
	local suffix = enabled and "-capped" or ""
	if (cast.Backdrop) then cast.Backdrop:SetTexture(path("cast_back"..suffix)) end
	if (cast.Shield) then cast.Shield:SetTexture(path("cast_back_spiked"..suffix)) end
	if (front) then front:SetTexture(path("cast_back"..suffix.."-over")) end
	if (shieldFront) then shieldFront:SetTexture(path("cast_back_spiked"..suffix.."-over")) end
end

--- A neutral boot halo follows only the addon's native threat texture. Place
--- it behind the complete assembly so no additive seam lights the health fill.
Engine.StyleEndcapThreat = function(self, frame, art, native, texture, flip)
	if (not frame or not native) then return end
	local glow = frame.Threat
	if (not glow) then
		glow = native:GetParent():CreateTexture(nil, "BACKGROUND", nil, -3)
		glow:SetAllPoints(art)
		glow:SetBlendMode("ADD")
		frame.Threat, frame.ThreatSource = glow, native
		local SetShown = function(shown) glow:SetShown(shown and frame.EndcapShown == true) end
		hooksecurefunc(native, "Show", function() SetShown(true) end)
		hooksecurefunc(native, "Hide", function() SetShown(false) end)
		hooksecurefunc(native, "SetShown", function(_, shown) SetShown(shown) end)
		hooksecurefunc(native, "SetAlpha", function(_, alpha) glow:SetAlpha(alpha) end)
		hooksecurefunc(native, "SetVertexColor", function(_, ...) glow:SetVertexColor(...) end)
	end
	glow:SetTexture(texture)
	glow:SetTexCoord(flip and 1 or 0, flip and 0 or 1, 0, 1)
	glow:SetVertexColor(native:GetVertexColor())
	glow:SetAlpha(native:GetAlpha())
	glow:SetShown(frame.EndcapShown == true and native:IsShown())
end

local themes = {}

--- Adds a theme. `priority` orders themes that are active at once; lower wins.
Engine.Register = function(self, theme, priority)
	theme.__enginePriority = priority or 100
	themes[#themes + 1] = theme
	table.sort(themes, function(a, b) return a.__enginePriority < b.__enginePriority end)
end

--- The theme in use, or nil for stock AzeriteUI.
Engine.GetActive = function(self)
	for _, theme in ipairs(themes) do
		if (theme:IsActive()) then return theme end
	end
end

Engine.GetThemes = function(self)
	return themes
end

-- One bag icon per selectable theme; Lite+ effects do not change its identity.
Engine.GetBagIcon = function(self)
	local key = ns.ThemeEffects and ns.ThemeEffects:GetTheme() or "azerite"
	local icons = { azerite = true, legacy = true, hunter = true, mage = true, paladin = true, druid = true }
	if (not icons[key]) then key = "azerite" end
	return "Interface\\AddOns\\" .. Addon .. "\\Assets\\ThemeBagIcons\\" .. key .. ".tga"
end

--- Uses the current reload API; older clients may expose the legacy global.
Engine.Reload = function(self)
	local reload = C_UI and C_UI.Reload or _G.ReloadUI
	if (type(reload) == "function") then reload(); return true end
	return false
end

--[[ Dispatch ]]--

-- Hook -> what stock AzeriteUI answers when no theme is active or the active theme
-- does not implement it. nil means "nothing to do".
local STOCK = {
	ResolveMedia = function(name) return nil end,
	ResolvePath = function(original) return original end,
	GetConfig = function(name, original) return original end,
	UseIceCrystal = function(requested) return requested end,
	GetPowerColor = function(token) return nil end,
	GetNameplateCastOffset = function(offset) return offset end,
	StyleHealth = false, StyleThreat = false, StyleCastbar = false, StyleNameplate = false,
	StyleUtilityButton = false, StylePet = false, StyleCompass = false
}
Engine.Hooks = STOCK

for hook, stock in pairs(STOCK) do
	Engine[hook] = function(self, ...)
		local theme = self:GetActive()
		local method = theme and theme[hook]
		if (type(method) == "function") then return method(theme, ...) end
		if (stock) then return stock(...) end
	end
end

--[[ Shared parts ]]--

--- Path to a file in Assets\<folder>, as a function of the file's name.
Engine.MediaPath = function(self, folder)
	return function(name) return "Interface\\AddOns\\" .. Addon .. "\\Assets\\" .. folder .. "\\" .. name .. ".tga" end
end

--- Themes dress the main layout only: not Legacy, SaiyaRatt or another layout variant.
Engine.IsMainLayout = function(self)
	if (ns.LegacyHUD and ns.LegacyHUD:IsActive()) then return false end
	if (ns.IsSaiyaRattProfile and ns:IsSaiyaRattProfile()) then return false end
	local variant = ns.GetActiveConfigVariant and ns:GetActiveConfigVariant()
	return not variant or variant == ""
end

local IsWidget = function(value)
	return type(value.GetObjectType) == "function" or type(value[0]) == "userdata"
end

--- Deep copy of a layout table. Layouts can hold real Font and Frame objects
--- (Minimap anchors); those keep their identity, since copying a widget's Lua
--- table loses its native wrapper and may walk the whole frame tree.
Engine.CopyLayout = function(self, source, seen)
	if (type(source) ~= "table" or IsWidget(source)) then return source end
	seen = seen or {}
	if (seen[source]) then return seen[source] end
	local result = {}
	seen[source] = result
	for key, value in pairs(source) do result[key] = self:CopyLayout(value, seen) end
	return result
end

local AssetName = function(value)
	return type(value) == "string" and value:match("[\\/]Assets[\\/]([^\\/]+)%.tga$") or nil
end
Engine.AssetName = AssetName

--- Replaces every media path in a layout table, and every table inside it, that
--- `options.resolve(name)` has a file for. A replaced texture's paired colour
--- (FooTexture/FooTexturePath -> FooColor) turns white with its alpha kept: theme
--- casings carry their own material colour. Assets `options.keepTint(name)` names
--- keep theirs (Hunter's neutral halos). `options.after(t)` runs on each table once
--- its own paths are done, for a theme's per-table adjustments.
Engine.ReplaceMedia = function(self, t, options, seen)
	seen = seen or {}
	if (seen[t] or IsWidget(t)) then return end
	seen[t] = true
	local resolve, keepTint = options.resolve, options.keepTint
	for key, value in pairs(t) do
		if (type(value) == "table") then
			self:ReplaceMedia(value, options, seen)
		elseif (type(value) == "string") then
			local name = AssetName(value)
			local replacement = name and resolve(name)
			if (replacement and replacement ~= value) then
				t[key] = replacement
				local prefix = type(key) == "string" and (key:match("^(.-)Texture$") or key:match("^(.-)TexturePath$"))
				local color = prefix and t[prefix .. "Color"]
				local kept = keepTint and keepTint(AssetName(replacement) or name)
				if (type(color) == "table" and not kept) then t[prefix .. "Color"] = { 1, 1, 1, color[4] or 1 } end
			end
		end
	end
	if (options.after) then options.after(t) end
end

--- A per-theme cache for themed layout copies: each source table is copied once.
--- `build(name, original)` makes the copy.
Engine.NewConfigCache = function(self, build)
	local cache = {}
	return function(name, original)
		if (cache[original]) then return cache[original] end
		local config = build(name, original)
		cache[original] = config
		return config
	end
end

--[[ Endcaps ]]--

local OFFSET_LIMIT = 60
Engine.EndcapOffsetLimit = OFFSET_LIMIT

local Clamp = function(value, low, high)
	value = tonumber(value)
	if (not value or value ~= value) then return nil end
	return math.max(low, math.min(high, value))
end

--- The endcap choice, size and nudge a theme stores per character, as
--- ns.db.char.<prefix>Endcap, <prefix>EndcapScale, <prefix>EndcapX/Y.
--- options: prefix, choices (key -> true; nil for size and nudge only), default,
--- clearDefault (store nil for the default instead of the key), defaultScale/X/Y,
--- placements (optional key -> { scale, x, y } defaults; saved values win),
--- refresh (called
--- after every change), name (the theme methods' infix, "Endcap" by default; a
--- cast bar set uses "CastEndcap": GetCastEndcapScale, SetCastEndcapOffset, ...).
Engine.NewEndcapSettings = function(self, options)
	local prefix, choices, default = options.prefix, options.choices, options.default
	local settings = {}
	local Char = function() return ns.db and ns.db.char end

	settings.GetKey = function()
		if (not choices) then return end
		local char = Char()
		local key = char and char[prefix .. "Endcap"] or default
		return choices[key] and key or default
	end
	local Defaults = function()
		local placement = options.placements and options.placements[settings.GetKey()]
		return placement and placement.scale or options.defaultScale or 1,
			placement and placement.x or options.defaultX or 0, placement and placement.y or options.defaultY or 0
	end
	settings.GetScale = function()
		local char = Char()
		local scale = tonumber(char and char[prefix .. "EndcapScale"])
		return (scale and scale >= .5 and scale <= 2) and scale or (Defaults())
	end
	settings.GetOffset = function()
		local char = Char()
		local _, x, y = Defaults()
		return Clamp(char and char[prefix .. "EndcapX"], -OFFSET_LIMIT, OFFSET_LIMIT) or x,
			Clamp(char and char[prefix .. "EndcapY"], -OFFSET_LIMIT, OFFSET_LIMIT) or y
	end
	local Changed = function()
		if (options.refresh) then options.refresh() end
		return true
	end
	settings.SetKey = function(key)
		if (not choices or not choices[key] or InCombatLockdown()) then return false end
		local stored = key
		if (options.clearDefault and key == default) then stored = nil end
		Char()[prefix .. "Endcap"] = stored
		return Changed()
	end
	settings.SetScale = function(scale)
		scale = tonumber(scale)
		if (not scale or scale < .5 or scale > 2 or InCombatLockdown()) then return false end
		Char()[prefix .. "EndcapScale"] = scale ~= (Defaults()) and scale or nil
		return Changed()
	end
	settings.SetOffset = function(x, y)
		if (InCombatLockdown()) then return false end
		local oldX, oldY = settings.GetOffset()
		x = Clamp(x, -OFFSET_LIMIT, OFFSET_LIMIT) or oldX
		y = Clamp(y, -OFFSET_LIMIT, OFFSET_LIMIT) or oldY
		local char = Char()
		local _, defaultX, defaultY = Defaults()
		char[prefix .. "EndcapX"] = x ~= defaultX and x or nil
		char[prefix .. "EndcapY"] = y ~= defaultY and y or nil
		return Changed()
	end
	settings.Reset = function()
		if (InCombatLockdown()) then return false end
		local char = Char()
		char[prefix .. "EndcapScale"], char[prefix .. "EndcapX"], char[prefix .. "EndcapY"] = nil, nil, nil
		return Changed()
	end

	--- The theme methods the Themes page and commands call, on `theme`.
	settings.Install = function(theme)
		local name = options.name or "Endcap"
		if (choices) then
			theme["Get" .. name .. "Choices"] = function() return choices end
			theme["Get" .. name] = function() return settings.GetKey() end
			theme["Set" .. name] = function(_, key) return settings.SetKey(key) end
		end
		theme["Get" .. name .. "Scale"] = function() return settings.GetScale() end
		theme["Get" .. name .. "Offset"] = function() return settings.GetOffset() end
		theme["Set" .. name .. "Scale"] = function(_, scale) return settings.SetScale(scale) end
		theme["Set" .. name .. "Offset"] = function(_, x, y) return settings.SetOffset(x, y) end
		theme["Reset" .. name .. "Placement"] = function() return settings.Reset() end
	end
	return settings
end

--[[ Lifecycle ]]--

--- A theme is chosen at load. A profile change that switches it on or off reloads,
--- once combat allows. Each theme sets `Theme.ProfileChanged = Engine.ProfileChanged`.
Engine.ProfileChanged = function(theme)
	if (theme.loadedActive ~= theme:IsActive()) then
		if (InCombatLockdown()) then
			theme:RegisterEvent("PLAYER_REGEN_ENABLED", "ProfileChanged")
		else
			theme:UnregisterEvent("PLAYER_REGEN_ENABLED", "ProfileChanged")
			Engine:Reload()
		end
	else
		theme:UnregisterEvent("PLAYER_REGEN_ENABLED", "ProfileChanged")
	end
end

--- Notes whether the theme loaded active and listens for profile changes.
--- Call from the theme's OnEnable.
Engine.WatchProfile = function(self, theme)
	theme.loadedActive = theme:IsActive()
	ns.db.RegisterCallback(theme, "OnProfileChanged", "ProfileChanged")
	ns.db.RegisterCallback(theme, "OnProfileCopied", "ProfileChanged")
	ns.db.RegisterCallback(theme, "OnProfileReset", "ProfileChanged")
end

--- The options window's borders in the active theme's metal (Options/Kit).
Engine.StyleOptionsKit = function(self, edgeFile, insetFile, roundedEdgeFile, roundedInsetFile)
	local kit = ns.OptionsKit
	if (not kit) then return end
	for _, key in ipairs({ "WindowBackdrop", "WindowCasing", "ButtonBackdrop" }) do
		if (kit[key]) then kit[key].edgeFile = edgeFile end
	end
	if (insetFile and kit.InsetBackdrop) then kit.InsetBackdrop.edgeFile = insetFile end
	if (roundedEdgeFile and kit.Look and kit.Look.CasingBackdrop) then kit.Look.CasingBackdrop.edgeFile = roundedEdgeFile end
	if (roundedInsetFile and kit.Look and kit.Look.InsetBackdrop) then kit.Look.InsetBackdrop.edgeFile = roundedInsetFile end
end
