-- Cooldown Manager styling: Components/ActionBars/Elements/CooldownManager.lua against fake viewers
-- built the way Blizzard_CooldownViewer/CooldownViewer.xml builds them (an unnamed MaskTexture and
-- IconOverlay texture per item, a Cooldown, ChargeCount/Applications frames, a bar on Tracked Bars).
-- Covers: hooks and styling of items built before and after load, the three styles and their
-- art paths (circular follows the theme or its own skin; square styles stay AzeriteUI),
-- restoring everything when styling is turned off, the
-- keybind lookup (override first, secret values ignored, no rebuild in combat), the Explorer
-- Mode proxies against the viewer's own Edit Mode opacity, the proc glow and pandemic effect drawn
-- over the border (Blizzard parents both to the item, one level up), the rival addon stand-down, and that
-- nothing is written into Blizzard's frame tables.
-- Plain Lua 5.1. It does not render, and it cannot show taint; the in-game check is still owed.
-- lua Tools/Harness/cooldown_manager_harness.lua . [mutation]
local root = arg[1] or "."
local mutation = arg[2]
local checks, failures = 0, 0
local function check(value, label)
	checks = checks + 1
	if (not value) then
		failures = failures + 1
		print("FAIL: " .. label)
	end
end

-------------------------------------------------------------------------------
-- Widgets
-------------------------------------------------------------------------------
local writes = {} -- keys written into "Blizzard" tables after construction
local function Blizzard(t, label)
	-- Records every new key written after the object is sealed.
	local data = t
	local proxy = setmetatable({}, {
		__index = data,
		__newindex = function(_, k, v)
			if (rawget(data, "__sealed")) then writes[#writes + 1] = label .. "." .. tostring(k) end
			data[k] = v
		end
	})
	return proxy, data
end

local Region = {}
Region.__index = Region
function Region:GetObjectType() return self.kind end
function Region:SetTexture(path) self.texture, self.atlas = path, nil end
function Region:SetAtlas(atlas) self.atlas, self.texture = atlas, nil end
function Region:GetAtlas() return self.atlas end
function Region:SetAlpha(a) self.alpha = a end
function Region:SetVertexColor(...) self.color = { ... } end
function Region:ClearAllPoints() self.points = {} end
function Region:SetAllPoints(target) self.points = { all = target } end
function Region:SetPoint(...) self.points = self.points or {}; self.points[#self.points + 1] = { ... } end
function Region:SetSize(w, h) self.width, self.height = w, h end
function Region:Show() self.shown = true end
function Region:Hide() self.shown = false end
function Region:SetShown(v) self.shown = v and true or false end
function Region:IsShown() return self.shown end
function Region:AddMaskTexture(mask) self.masks = self.masks or {}; self.masks[mask] = true end
function Region:RemoveMaskTexture(mask) if self.masks then self.masks[mask] = nil end end
function Region:SetDrawLayer() end
-- Font strings
function Region:SetFontObject(font) self.fontObject = font end
function Region:GetFontObject() return self.fontObject end
function Region:GetFont() return self.fontPath, self.fontSize, self.fontFlags end
function Region:SetFont(p, s, f) self.fontPath, self.fontSize, self.fontFlags, self.fontObject = p, s, f, nil end
function Region:SetTextColor(r, g, b, a) self.textColor = { r, g, b, a } end
function Region:GetTextColor() local c = self.textColor or { 1, 1, 1, 1 }; return c[1], c[2], c[3], c[4] end
function Region:SetText(t)
	if self.kind == "FontString" then
		local font = self.fontObject
		assert(self.fontPath or type(font) == "string" or (font and font.configured), "FontString:SetText(): Font not set")
	end
	self.text = t
end
function Region:SetJustifyH() end
function Region:SetJustifyV() end

local function NewRegion(kind, fields)
	local r = setmetatable(fields or {}, Region)
	r.kind = kind
	r.shown = true
	return r
end

local Frame = setmetatable({}, { __index = Region })
Frame.__index = Frame
function Frame:GetRegions() return unpack(self.regions) end
function Frame:CreateTexture() local t = NewRegion("Texture"); self.regions[#self.regions + 1] = t; return t end
function Frame:CreateFontString() local t = NewRegion("FontString"); self.regions[#self.regions + 1] = t; return t end
function Frame:GetWidth() return self.width or 0 end
function Frame:SetFrameLevel(n) self.level = n end
function Frame:GetFrameLevel() return self.level or 1 end
function Frame:EnableMouse() end
function Frame:IsForbidden() return false end
function Frame:IsEnabled() return true end
-- Cooldown
function Frame:SetSwipeTexture(t) self.swipe = t end
function Frame:SetUseCircularEdge(v) self.circular = v end
function Frame:SetCountdownFont(name) self.countdownFont = name end
function Frame:GetCountdownFontString() return self.countdownString end
-- StatusBar
function Frame:SetStatusBarTexture(t) self.barTexture.texture, self.barTexture.atlas = t, nil end
function Frame:GetStatusBarTexture() return self.barTexture end
function Frame:SetStatusBarColor(r, g, b) self.barColor = { r, g, b } end

local function NewFrame(kind, fields)
	local f = setmetatable(fields or {}, Frame)
	f.kind = kind or "Frame"
	f.regions = f.regions or {}
	f.shown = true
	return f
end

-------------------------------------------------------------------------------
-- Blizzard's item frames (CooldownViewer.xml)
-------------------------------------------------------------------------------
local SIZES = { EssentialCooldownViewer = 50, UtilityCooldownViewer = 30, BuffIconCooldownViewer = 40 }

local function NewIconItem(viewerName)
	local size = SIZES[viewerName]
	local item = NewFrame("Frame", { width = size, level = 10 })
	local icon = NewRegion("Texture", { name = "Icon" })
	local mask = NewRegion("MaskTexture", { atlas = "UI-HUD-CoolDownManager-Mask" })
	local overlay = NewRegion("Texture", { atlas = "UI-HUD-CoolDownManager-IconOverlay" })
	item.regions = { icon, mask, overlay }
	item.Icon = icon
	if (viewerName ~= "BuffIconCooldownViewer") then
		item.OutOfRange = NewRegion("Texture", { atlas = "UI-CooldownManager-OORshadow" })
		item.regions[#item.regions + 1] = item.OutOfRange
		item.cooldownFont = viewerName == "EssentialCooldownViewer" and "GameFontHighlightHugeOutline" or "GameFontHighlightOutline"
		item.ChargeCount = NewFrame("Frame", { level = 11 })
		item.ChargeCount.Current = NewRegion("FontString", { fontObject = "NumberFontNormal" })
	else
		item.Applications = NewFrame("Frame", { level = 11 })
		item.Applications.Applications = NewRegion("FontString", { fontObject = "NumberFontNormal" })
		item.DebuffBorder = NewFrame("Frame", { level = 11 })
	end
	item.Cooldown = NewFrame("Cooldown", {
		level = 11, swipe = [[Interface\HUD\UI-HUD-CoolDownManager-Icon-Swipe]],
		countdownString = NewRegion("FontString", { fontPath = "Fonts\\FRIZQT__.TTF", fontSize = 20, fontFlags = "OUTLINE" })
	})
	item.GetCooldownInfo = function(self) return self.cooldownInfo end
	return item
end

local function NewBarItem()
	local item = NewFrame("Frame", { width = 220, level = 10 })
	local holder = NewFrame("Frame", { width = 30, level = 512 })
	local icon = NewRegion("Texture")
	local mask = NewRegion("MaskTexture", { atlas = "UI-HUD-CoolDownManager-Mask" })
	local overlay = NewRegion("Texture", { atlas = "UI-HUD-CoolDownManager-IconOverlay" })
	holder.regions = { icon, mask, overlay }
	holder.Icon = icon
	holder.Applications = NewRegion("FontString", { fontObject = "NumberFontNormalSmall" })
	item.Icon = holder
	item.DebuffBorder = NewFrame("Frame", { level = 520 })
	item.Bar = NewFrame("StatusBar", { level = 511, barTexture = NewRegion("Texture", { atlas = "UI-HUD-CoolDownManager-Bar" }) })
	item.Bar.BarBG = NewRegion("Texture", { atlas = "UI-HUD-CoolDownManager-Bar-BG" })
	item.Bar.Name = NewRegion("FontString", { fontObject = "NumberFontNormal" })
	item.Bar.Duration = NewRegion("FontString", { fontObject = "NumberFontNormal" })
	item.GetCooldownInfo = function(self) return self.cooldownInfo end
	return item
end

local function Data(item) return getmetatable(item).__index end

local function Seal(item)
	-- Only the item table itself is watched: that is the table Blizzard's mixin code owns.
	local proxy, data = Blizzard(item, "item")
	data.__sealed = true
	return proxy, data
end

local viewers = {}
local function NewViewer(name, count)
	local viewer = NewFrame("Frame", { opacity = 100 })
	local active = {}
	viewer.itemFramePool = { EnumerateActive = function() local i = 0; return function() i = i + 1; return active[i] end end }
	viewer.active = active
	viewer.OnAcquireItemFrame = function() end
	viewer.RefreshData = function() end
	viewer.AnchorPandemicStateFrame = function() end
	-- CooldownViewer.lua: pooled frame parented to the item, anchored, then stored on it.
	viewer.ShowPandemic = function(self, item)
		local frame = NewFrame("Frame", { level = item:GetFrameLevel() + 1 })
		self:AnchorPandemicStateFrame(frame, item)
		Data(item).PandemicIcon = frame
		return frame
	end
	viewer.UpdateSystemSettingOpacity = function(self) self:SetAlpha(self.opacity / 100) end
	viewer.GetSettingValue = function(self, setting) assert(setting == 7, "asks for the opacity setting"); return self.opacity end
	viewer.Acquire = function(self)
		local item = name == "BuffBarCooldownViewer" and NewBarItem() or NewIconItem(name)
		local proxy = Seal(item)
		active[#active + 1] = proxy
		self:OnAcquireItemFrame(proxy)
		return proxy
	end
	viewers[name] = viewer
	_G[name] = viewer
	for _ = 1, count do viewer:Acquire() end
	return viewer
end

-------------------------------------------------------------------------------
-- Client
-------------------------------------------------------------------------------
local inCombat = false
local timers = {}
_G.C_Timer = { After = function(_, fn) timers[#timers + 1] = fn end }
local function RunTimers() local list = timers; timers = {}; for _, fn in ipairs(list) do fn() end end
_G.InCombatLockdown = function() return inCombat end
_G.UIParent = NewFrame("Frame")
local frameLogAll = {}
_G.CreateFrame = function(kind, _, parent) local f = NewFrame(kind); f.parent = parent; frameLogAll[#frameLogAll + 1] = f; return f end
_G.Enum = { EditModeCooldownViewerSetting = { Opacity = 7 } }
local SECRET = setmetatable({}, { __tostring = function() return "secret" end })
_G.issecretvalue = function(v) return v == SECRET end
_G.hooksecurefunc = function(t, key, hook)
	local original = t[key]
	assert(type(original) == "function", "hooks an existing method: " .. key)
	t[key] = function(...) local a, b, c = original(...); hook(...); return a, b, c end
end

local enabledAddons = {}
-- Locale lookups answer with the key, as AceLocale does for enUS.
_G.LibStub = function() return { GetLocale = function() return setmetatable({}, { __index = function(_, k) return k end }) end } end
-- The conflict prompt (Core/API/Addons.lua) is recorded, not drawn; reloads are counted.
local prompts, reloads = {}, 0
_G.ReloadUI = function() reloads = reloads + 1 end
-- Character data outlives a Load(), as SavedVariables outlive a reload.
local charStore = {}
local events = {}
local modules = {}
-- Missing font sizes still produce Font objects in Core/API/Assets.lua, but
-- those objects have no face. Use the shipped inventory instead of inventing it.
local fontFile = assert(io.open(root .. "/FontStyles.xml", "rb"))
local fontSource = fontFile:read("*a"); fontFile:close()
local outlinedSizes = {}
for size in fontSource:gmatch('<FontFamily name="AzeriteFont(%d+)Outline"') do outlinedSizes[tonumber(size)] = true end
local fonts = setmetatable({}, { __index = function(t, k)
	local f = { GetName = function() return "AzeriteUIFont" .. k end, size = k, configured = outlinedSizes[k] }
	rawset(t, k, f)
	return f
end })

local ns = {
	Colors = {
		normal = { .9, .8, .5 }, ui = { .75, .75, .75 }, aura = { 1, .47, .11 }, offwhite = { .77, .77, .77 },
		quest = { gray = { .6, .6, .6 } }
	},
	ModulePrototype = { defaults = { enabled = true } },
	API = {
		GetFont = function(size) return fonts[size] end,
		-- The active theme answers here: the circular style asks, the square ones must not.
		GetMedia = function(name) return "THEMED:" .. name end,
		IsAddOnEnabled = function(name) return enabledAddons[name] and true or false end,
		ShowAddonConflictPrompt = function(opts) prompts[#prompts + 1] = opts end,
		IsEventAvailable = function() return true end
	},
	db = { RegisterNamespace = function(_, _, defaults)
		local profile = {}
		for k, v in pairs(defaults.profile) do profile[k] = v end
		return { profile = profile, char = charStore, RegisterCallback = function() end }
	end }
}
function ns:Merge(target, source)
	for k, v in pairs(source) do if target[k] == nil then target[k] = v end end
	return target
end
function ns:NewModule(name)
	local m = { name = name }
	function m:GetName() return name end
	function m:IsEnabled() return true end
	function m:GetDefaults() return self:GenerateDefaults() end
	function m:RegisterEvent(event, method) events[event] = method end
	modules[name] = m
	return m
end
function ns:GetModule(name) return modules[name] end

-- AzeriteUI's own action bars, as LibActionButton reports them.
local buttons = {}
local function Button(spellID, key) local b = { GetSpellId = function() return spellID end, GetHotkey = function() return key end }; buttons[#buttons + 1] = b; return b end
modules.ActionBars = { IsEnabled = function() return true end, bars = { { buttons = buttons } } }

local function Load()
	local path = root .. "/Components/ActionBars/Elements/CooldownManager.lua"
	local file = assert(io.open(path, "rb"))
	local source = file:read("*a"); file:close()
	local original = source
	if (mutation == "skin-ignored") then
		source = source:gsub("local StyleArt = function%(style, name, skin%)", "local StyleArt = function(style, name, skin) skin = \"theme\"")
	elseif (mutation == "skin-falls-to-theme") then
		source = source:gsub("theme:ResolveOwnMedia%(name%)%) or Art%(name%)", "theme:ResolveOwnMedia(name)) or GetMedia(name)")
	elseif (mutation == "circle-unthemed") then
		source = source:gsub("if %(not style.themed or skin == \"azerite\"%) then", "if (true) then")
	elseif (mutation == "themed-art") then
		source = source:gsub("local Art = function%(name%)", "local Art = function(name) do return ns.API.GetMedia(name) end")
	elseif (mutation == "no-revert") then
		source = source:gsub("if %(skin%) then RevertSkin%(skin%) end", "")
	elseif (mutation == "base-first") then
		source = source:gsub("return %(override and keyBySpell%[override%]%) or %(base and keyBySpell%[base%]%)", "return (base and keyBySpell[base]) or (override and keyBySpell[override])")
	elseif (mutation == "fade-ignores-opacity") then
		source = source:gsub("viewer:SetAlpha%(GetOpacity%(viewer%) %* alpha%)", "viewer:SetAlpha(alpha)")
	elseif (mutation == "rebuild-in-combat") then
		source = source:gsub("if %(InCombatLockdown%(%)%) then", "if (false) then")
	elseif (mutation == "glow-under") then
		source = source:gsub("LiftEffect%(skin, skin.item.SpellActivationAlert%)", "")
	elseif (mutation == "pandemic-under") then
		source = source:gsub("if %(skin and skin.applied%) then LiftEffect%(skin, frame%) end", "")
	elseif (mutation == "choice-ignored") then
		source = source:gsub('if %(choice ~= "both"%) then', "if (true) then")
	elseif (mutation == "always-ask") then
		source = source:gsub("if %(not choice%) then", "if (true) then")
	elseif (mutation == "keeps-answer") then
		source = source:gsub('if %(char.rival ~= rival%) then return end', "")
	elseif (mutation == "writes-blizzard") then
		source = source:gsub("skins%[item%] = skin\n", "skins[item] = skin\n\titem.__AzeriteUI = true\n")
	end
	assert(not mutation or source ~= original, "mutation did not apply: " .. tostring(mutation))
	local chunk = assert(loadstring(source, "@" .. path))
	chunk("AzeriteUI5_JuNNeZ_Edition", ns)
	local m = modules.CooldownManager
	m:OnInitialize()
	return m
end

local function Assets(name) return "Interface\\AddOns\\AzeriteUI5_JuNNeZ_Edition\\Assets\\" .. name .. ".tga" end
local function Mask(item) local holder = item.Icon.regions and item.Icon or item; return holder.regions[2] end

-------------------------------------------------------------------------------
-- Session
-------------------------------------------------------------------------------
NewViewer("EssentialCooldownViewer", 2)
NewViewer("UtilityCooldownViewer", 1)
NewViewer("BuffIconCooldownViewer", 1)
NewViewer("BuffBarCooldownViewer", 1)

Button(100, "1")
Button(200, "S-2")
Button(SECRET, "X")      -- a secret spell is never a key
Button(300, SECRET)      -- nor a secret key
Button(100, "9")         -- the first bar wins

local essential = viewers.EssentialCooldownViewer
-- Blizzard's own writes, so straight into the tables rather than through the watch.
Data(essential.active[1]).cooldownInfo = { spellID = 100 }
Data(essential.active[2]).cooldownInfo = { spellID = 999, overrideSpellID = 200 }

-- Blizzard's spell alert manager: the glow frame is created on first show, a child of the
-- item one level above it (ActionButtonSpellAlerts.lua GetAlertFrame).
_G.ActionButtonSpellAlertManager = {
	ShowAlert = function(_, button)
		local d = Data(button)
		d.SpellActivationAlert = d.SpellActivationAlert or NewFrame("Frame", { level = button:GetFrameLevel() + 1 })
	end
}
-- An item already glowing when the module loads.
ActionButtonSpellAlertManager:ShowAlert(essential.active[2])

local M = Load()
M:OnEnable()
check(fonts[11].configured and not fonts[10].configured, "font model matches shipped 11px and missing 10px outlined families")
for _, f in ipairs(viewers.UtilityCooldownViewer.active) do
	-- OnEnable has already written text to this label; the font-aware stub must allow it.
	check(Mask(f).texture == Assets("actionbutton-mask-square-rounded"), "Utility viewer styles successfully with configured key font")
end
check(events.UPDATE_BINDINGS and events.ACTIONBAR_SLOT_CHANGED and events.PLAYER_REGEN_ENABLED, "listens for bindings, bar slots and combat end")

-- Items built before the module loaded.
local item = essential.active[1]
local data = Data(item)
check(Mask(item).texture == Assets("actionbutton-mask-square-rounded"), "rounded is the default, on the existing items")
check(data.regions[3].alpha == 0, "Blizzard's icon overlay is hidden")
check(data.Cooldown.swipe == Assets("actionbutton-mask-square-rounded"), "the swipe takes the icon's shape")
check(data.Cooldown.countdownFont == "AzeriteUIFont18", "countdown in AzeriteUI's font at the essential size")
check(data.ChargeCount.Current.fontObject == fonts[15], "charges in AzeriteUI's font")
check(data.OutOfRange.masks and data.OutOfRange.masks[Mask(item)], "the out of range shade is masked to the icon")

-- The border and backdrop: AzeriteUI art, never the theme's, at 2.06 x a 50px icon.
local found
for _, r in ipairs(data.regions) do if r.texture == Assets("actionbutton-backdrop-square-rounded") then found = r end end
check(found and math.abs(found.width - 103) < .01, "backdrop at 2.06 x the icon, from Assets")
for _, r in ipairs(data.regions) do if r.texture and tostring(r.texture):find("THEMED", 1, true) then found = "themed" end end
check(found ~= "themed", "no class theme art on the square styles")

-- Items acquired later are styled by the hook.
local later = essential:Acquire()
check(Mask(later).texture == Assets("actionbutton-mask-square-rounded"), "a newly acquired item is styled")

-- The proc glow: over the border, under the counts, on items glowing before and after styling.
local function DecorOf(it)
	for _, f in ipairs(frameLogAll) do if f.parent == it and f.kind == "Frame" and f.regions[1] then return f end end
end
local glowing = Data(essential.active[2])
check(glowing.SpellActivationAlert.level > DecorOf(essential.active[2]).level, "a glow shown before styling is lifted over the border")
ActionButtonSpellAlertManager:ShowAlert(item)
check(data.SpellActivationAlert.level > DecorOf(item).level, "a glow shown after styling is lifted over the border")
check(data.ChargeCount.level > data.SpellActivationAlert.level, "charges stay over the glow")
local buffIcon = viewers.BuffIconCooldownViewer.active[1]
local pandemic = viewers.BuffIconCooldownViewer:ShowPandemic(buffIcon)
check(pandemic.level > DecorOf(buffIcon).level, "a pandemic effect is lifted over the border")
check(Data(buffIcon).Applications.level > pandemic.level, "stacks stay over the pandemic effect")
check(Data(buffIcon).Applications.level > DecorOf(buffIcon).level, "Tracked Buffs stacks are over the border (item has no ChargeCount)")
check(Data(buffIcon).DebuffBorder.level > DecorOf(buffIcon).level, "and its debuff border")

-- Tracked Bars.
local barItem = viewers.BuffBarCooldownViewer.active[1]
local barData = Data(barItem)
check(barData.Bar.barTexture.texture == Assets("cast_bar"), "tracked bars fill with cast_bar")
check(barData.Bar.BarBG.alpha == 0, "Blizzard's bar background is hidden")
check(barData.Bar.Name.fontObject == fonts[13], "bar names in AzeriteUI's font")
check(Mask(barItem).texture == Assets("actionbutton-mask-square-rounded"), "the bar's icon is styled too")

-- Keybinds, after the coalesced rebuild. Key font strings sit on decor frames, so every
-- frame the module creates from here on is logged.
RunTimers()
local frameLog = {}
local realCreate = _G.CreateFrame
_G.CreateFrame = function(kind, n, parent) local f = realCreate(kind, n, parent); frameLog[#frameLog + 1] = f; return f end

-- Turning the style off and on again.
M.db.profile.styleIcons = false
M:UpdateSettings()
check(Mask(item).atlas == "UI-HUD-CoolDownManager-Mask", "turning the style off puts Blizzard's mask back")
check(data.regions[3].alpha == 1, "and the icon overlay")
check(data.Cooldown.swipe == [[Interface\HUD\UI-HUD-CoolDownManager-Icon-Swipe]], "and the swipe")
check(data.Cooldown.countdownFont == "GameFontHighlightHugeOutline", "and the countdown font")
check(data.ChargeCount.Current.fontObject == "NumberFontNormal", "and the charge font")
check(not (data.OutOfRange.masks and data.OutOfRange.masks[Mask(item)]), "and the out of range shade's mask")
check(barData.Bar.barTexture.atlas == "UI-HUD-CoolDownManager-Bar" and barData.Bar.BarBG.alpha == 1, "and the bar")
check(data.SpellActivationAlert.level == data.level + 1, "and the glow's level")
check(pandemic.level == Data(buffIcon).level + 1, "and the pandemic effect's level")
local buffData = Data(viewers.BuffIconCooldownViewer.active[1])
check(buffData.Cooldown.countdownString.fontPath == "Fonts\\FRIZQT__.TTF", "a countdown without a named font gets its font back")

M.db.profile.styleIcons = true
M:UpdateSettings()
RunTimers()
check(Mask(item).texture == Assets("actionbutton-mask-square-rounded"), "and back on")

local fresh = essential:Acquire()
Data(fresh).cooldownInfo = { spellID = 100 }
M:UpdateKeybinds("EssentialCooldownViewer")
local decor = frameLog[#frameLog]
local keyString
for _, r in ipairs(decor.regions) do if r.kind == "FontString" then keyString = r end end
check(keyString and keyString.text == "1", "the key from the first bar holding the spell")

Data(fresh).cooldownInfo = { spellID = 100, overrideSpellID = 200 }
M:UpdateKeybinds("EssentialCooldownViewer")
check(keyString.text == "S-2", "the override spell's key comes first")

Data(fresh).cooldownInfo = { spellID = 300 }
M:UpdateKeybinds("EssentialCooldownViewer")
check(keyString.text == "", "a secret key shows nothing")

Data(fresh).cooldownInfo = { spellID = SECRET }
M:UpdateKeybinds("EssentialCooldownViewer")
check(keyString.text == "", "a secret spell shows nothing")

M.db.profile.showKeybinds = false
M:UpdateSettings()
Data(fresh).cooldownInfo = { spellID = 100 }
M:UpdateKeybinds("EssentialCooldownViewer")
check(keyString.text == "" and keyString.shown == false, "keybinds can be switched off")
M.db.profile.showKeybinds = true
M:UpdateSettings(); RunTimers()

-- No rebuild in combat: the old keys stay until it ends.
buttons[1] = { GetSpellId = function() return 100 end, GetHotkey = function() return "CHANGED" end }
inCombat = true
M:OnEvent("ACTIONBAR_SLOT_CHANGED")
RunTimers()
M:UpdateKeybinds("EssentialCooldownViewer")
check(keyString.text == "1", "keys are not rebuilt in combat")
inCombat = false
M:OnEvent("PLAYER_REGEN_ENABLED")
RunTimers()
check(keyString.text == "CHANGED", "and are rebuilt when combat ends")

-- Circular.
M.db.profile.iconStyle = "circular"
M:UpdateSettings()
check(Mask(item).texture == "THEMED:actionbutton-mask-circular", "circular mask, through the theme")
check(data.Cooldown.circular == true, "circular swipe edge")
check(data.Icon.width and math.abs(data.Icon.width - 36) < .01, "the circular icon is drawn at 72%")
-- Keep the border identity even if a mutation changes its texture.
local ring
for _, r in ipairs(decor.regions) do if r.kind == "Texture" then ring = r end end
assert(ring, "the item has a border texture")
check(ring.texture == "THEMED:actionbutton-border" and math.abs(ring.width - 36 * 134.295081967 / 44) < .01,
	"the theme's action bar ring at the action bar's proportion")

-- A skin of its own: overrides the interface theme for the Cooldown Manager alone.
local function Choices() return table.concat(M:GetSkinChoices(), ",") end
check(M:GetSkin() == "theme", "the skin follows the interface theme by default")
check(Choices() == "theme,azerite", "no theme module loaded: only the theme and AzeriteUI are offered")
local function Own(prefix, names)
	return { ResolveOwnMedia = function(_, name) if (names[name]) then return prefix .. names[name] end end }
end
modules.MageTheme = Own("MAGE:", { ["actionbutton-border"] = "actionbutton-border" })
modules.HunterTheme = Own("HUNTER:", { ["actionbutton-border"] = "actionbutton-border" })
modules.PaladinTheme = Own("PALADIN:", { ["actionbutton-border"] = "action-ring" })
check(Choices() == "theme,azerite,mage,hunter", "Mage and Hunter are offered; Paladin only in Development Mode")

M.db.profile.skin = "azerite"
M:UpdateSettings()
check(ring.texture == Assets("actionbutton-border") and Mask(item).texture == Assets("actionbutton-mask-circular"), "AzeriteUI skin: the stock ring and mask under any theme")
M.db.profile.skin = "mage"
M:UpdateSettings()
check(ring.texture == "MAGE:actionbutton-border", "Mage skin: the Mage ring, though Mage is not the interface theme")
check(Mask(item).texture == Assets("actionbutton-mask-circular"), "art the skin lacks falls back to AzeriteUI's, not the interface theme's")
M.db.profile.skin = "hunter"
M:UpdateSettings()
check(ring.texture == "HUNTER:actionbutton-border", "Hunter skin overrides the interface theme")
local hunterItem = essential:Acquire()
local hunterDecor = frameLog[#frameLog]
local hunterBorder
for _, r in ipairs(hunterDecor.regions) do if r.kind == "Texture" then hunterBorder = r end end
check(hunterBorder and hunterBorder.texture == "HUNTER:actionbutton-border"
	and Mask(hunterItem).texture == Assets("actionbutton-mask-circular"), "new pooled items use the selected skin")
M.db.profile.skin = "paladin"
M:UpdateSettings()
check(M:GetSkin() == "theme" and ring.texture == "THEMED:actionbutton-border", "a saved Paladin skin outside Development Mode follows the theme")
ns.db.global = { enableDevelopmentMode = true }
M:UpdateSettings()
check(Choices() == "theme,azerite,mage,hunter,paladin" and ring.texture == "PALADIN:action-ring", "Development Mode: the Paladin skin")
ns.db.global = nil
M.db.profile.skin = "nonsense"
M:UpdateSettings()
check(M:GetSkin() == "theme" and ring.texture == "THEMED:actionbutton-border", "an unknown saved skin follows the theme")
M.db.profile.skin = nil
M:UpdateSettings()
check(M:GetSkin() == "theme" and ring.texture == "THEMED:actionbutton-border", "profiles created before skin selection follow the theme")
local hunter = modules.HunterTheme
modules.HunterTheme = nil
M.db.profile.skin = "hunter"
M:UpdateSettings()
check(M:GetSkin() == "theme" and ring.texture == "THEMED:actionbutton-border", "a missing saved theme follows the interface theme")
modules.HunterTheme = hunter
M.db.profile.skin = "mage"

M.db.profile.iconStyle = "square"
M:UpdateSettings()
check(Mask(item).texture == Assets("actionbutton-mask-square") and data.Cooldown.circular == false, "square mask and edge")
check(ring.texture == Assets("actionbutton-border-square"), "the square styles stay AzeriteUI art under any skin (Mage chosen)")
M.db.profile.skin = "theme"
check(data.Icon.points and data.Icon.points.all == item, "the icon fills its frame again")

-- The real options page, including dynamic values/sorting and the live setter.
local generate
modules.Options = { AddGroup = function(_, _, fn) generate = fn end }
local originalLibStub, originalNames = _G.LibStub, _G.LOCALIZED_CLASS_NAMES_MALE
_G.LibStub = function() return { GetLocale = function()
	return setmetatable({}, { __index = function(_, key) return key end })
end } end
_G.LOCALIZED_CLASS_NAMES_MALE = { MAGE = "Mage", HUNTER = "Hunter", PALADIN = "Paladin" }
assert(loadfile(root .. "/Options/OptionsPages/CooldownManager.lua"))("AzeriteUI5_JuNNeZ_Edition", ns)
local options = assert(generate()).args
local skinOption = options.skin
check(table.concat(skinOption.sorting(), ",") == "theme,azerite,mage,hunter"
	and skinOption.values().mage == "Mage (WIP)" and not skinOption.values().paladin,
	"real dropdown lists available skins with WIP labels")
M.db.profile.iconStyle = "circular"
skinOption.set({ "skin" }, "hunter")
check(skinOption.get() == "hunter" and ring.texture == "HUNTER:actionbutton-border", "dropdown setter redraws immediately")
skinOption.set({ "skin" }, "theme")
check(ring.texture == "THEMED:actionbutton-border", "follow-theme restores interface art immediately")
ns.db.global = { enableDevelopmentMode = true }
check(skinOption.values().paladin == "Paladin (WIP)", "dropdown offers Paladin in Development Mode")
skinOption.set({ "skin" }, "paladin")
check(ring.texture == "PALADIN:action-ring", "dropdown applies Paladin's own ring")
for _, style in ipairs({ "square", "rounded" }) do
	M.db.profile.iconStyle = style
	for _, key in ipairs(M:GetSkinChoices()) do
		skinOption.set({ "skin" }, key)
		local suffix = style == "rounded" and "-rounded" or ""
		check(ring.texture == Assets("actionbutton-border-square" .. suffix), style .. " stays AzeriteUI under " .. key)
	end
end
M.db.profile.styleIcons = false
check(skinOption.disabled(), "skin dropdown disabled when styling is off")
M.db.profile.styleIcons = true
M.rival = "ArcUI"
check(skinOption.disabled(), "skin dropdown disabled under a rival")
M.rival, ns.db.global = nil, nil
check(not skinOption.disabled(), "skin dropdown enabled while AzeriteUI owns styling")
skinOption.set({ "skin" }, "theme")
_G.LibStub, _G.LOCALIZED_CLASS_NAMES_MALE = originalLibStub, originalNames

-- Explorer Mode: proxies, the viewer's own opacity, and its hook.
local proxies = M:GetFadeFrames()
check(#proxies == 4, "one fade proxy per viewer")
check(M:GetFadeFrames() == proxies, "proxies are made once")
essential.opacity = 80
proxies[1]:OnFadeAlphaChanged(.5)
check(math.abs((essential.alpha or 0) - .4) < 1e-6, "faded alpha is the Edit Mode opacity times the fade")
essential:UpdateSystemSettingOpacity()
check(math.abs(essential.alpha - .4) < 1e-6, "an Edit Mode opacity change keeps the fade")
proxies[1]:OnFadeAlphaChanged(1)
check(math.abs(essential.alpha - .8) < 1e-6, "back to the Edit Mode opacity at full")
essential.opacity = 60
essential:UpdateSystemSettingOpacity()
check(math.abs(essential.alpha - .6) < 1e-6, "and Edit Mode owns it again once unfaded")

-- Nothing written into Blizzard's item tables.
check(#writes == 0, "no keys written into Blizzard's item frames: " .. table.concat(writes, ", "))

-- A rival addon: nothing hooked, nothing faded.
for k in pairs(viewers) do _G[k] = nil end
viewers = {}
NewViewer("EssentialCooldownViewer", 1)
NewViewer("UtilityCooldownViewer", 0)
NewViewer("BuffIconCooldownViewer", 0)
NewViewer("BuffBarCooldownViewer", 0)
enabledAddons.ArcUI = true
modules.CooldownManager = nil
timers = {}
local R = Load()
R:OnEnable()
check(R:GetRival() == "ArcUI", "a rival addon is named")
check(Mask(viewers.EssentialCooldownViewer.active[1]).atlas == "UI-HUD-CoolDownManager-Mask", "and the Cooldown Manager is left alone")
check(#R:GetFadeFrames() == 0, "and not faded")

-- Unanswered: the player is asked, once, after login.
check(#prompts == 0, "the question waits for login to settle")
RunTimers()
check(#prompts == 1 and prompts[1].rival == "ArcUI" and prompts[1].key == "CooldownManager", "then asks which addon styles the Cooldown Manager")
check(prompts[1].feature == "Cooldown Manager", "naming the feature")

-- Answering with the other addon saves it per character and reloads nothing.
prompts[1].OnChoose("other")
check(charStore.owner == "other" and charStore.rival == "ArcUI", "the answer is saved for this character")
check(reloads == 0, "standing down needs no reload")

local function Session()
	for k in pairs(viewers) do _G[k] = nil end
	viewers = {}
	NewViewer("EssentialCooldownViewer", 1)
	NewViewer("UtilityCooldownViewer", 0)
	NewViewer("BuffIconCooldownViewer", 0)
	NewViewer("BuffBarCooldownViewer", 0)
	modules.CooldownManager = nil
	prompts, timers, reloads = {}, {}, 0
	local m = Load()
	m:OnEnable()
	RunTimers()
	return m
end

-- Answered "other": next login stands down without asking.
R = Session()
check(R:GetRival() == "ArcUI" and #prompts == 0, "an answered question is not asked again")

-- Answered "both": AzeriteUI styles alongside the other addon.
charStore.owner = "both"
R = Session()
check(R:GetRival() == nil and R:GetSharedWith() == "ArcUI", "both: styled alongside the other addon")
check(Mask(viewers.EssentialCooldownViewer.active[1]).atlas ~= "UI-HUD-CoolDownManager-Mask", "both: our mask is on the items")
check(#R:GetFadeFrames() > 0 and #prompts == 0, "both: faded with the rest, and not asked again")
R:PromptRivalChoice()
check(#prompts == 1 and prompts[1].rival == "ArcUI", "the options page can ask again")
prompts[1].OnChoose("other")
check(reloads == 1, "leaving both for the other addon reloads, since our hooks are on")

-- Picked AzeriteUI (the other addon was turned off) and the addon enabled again: ask again.
charStore.owner, charStore.rival = "azeriteui", "ArcUI"
R = Session()
check(R:GetRival() == "ArcUI" and #prompts == 1, "the addon back on after picking AzeriteUI: asked again")

-- An answer about another addon does not carry over.
charStore.owner, charStore.rival = "other", "ArcUI"
enabledAddons.ArcUI = nil
enabledAddons.BetterCooldownManager = true
R = Session()
check(R:GetRival() == "BetterCooldownManager" and #prompts == 1, "a different addon is asked about on its own")
enabledAddons.BetterCooldownManager = nil

-- CooldownManagerCentered only lays the rows out by default: styled, not asked.
enabledAddons.CooldownManagerCentered = true
R = Session()
check(R:GetRival() == nil and R:GetSharedWith() == nil and #prompts == 0, "CooldownManagerCentered is not a rival")
check(Mask(viewers.EssentialCooldownViewer.active[1]).atlas ~= "UI-HUD-CoolDownManager-Mask", "and the items are styled")
enabledAddons.CooldownManagerCentered = nil

print(string.format("Cooldown Manager: %d checks, %d failures", checks, failures))
if (failures > 0) then os.exit(1) end
