-- Masque skin registration harness (Components/ActionBars/Compatibility/MasqueSkins.lua).
--
-- 1. Loads the real file with no Masque: nothing registers and it waits for ADDON_LOADED;
--    an unrelated addon does nothing, Masque's ADDON_LOADED registers once.
-- 2. Loads it with Masque already present: registers at once, and a second Register()
--    adds nothing.
-- 3. Checks every skin: unique ID, a Shape Masque has art for, the layers we rely on
--    as tables, positive sizes, and every texture path pointing at a file on disk.
-- 4. Checks the sizes still match Core/API/Assets.lua BUTTON_SHAPES and the circle
--    layout, and that every theme folder with button borders is offered.
--
-- What it cannot cover: how the skins look on other addons' buttons, Masque's own
-- skinning code and its dropdown. Those are live checks.
--
-- Usage: lua.exe Tools/Harness/masque_skins_harness.lua [addon root]

local root = (arg and arg[1]) or "."
local ADDON = "AzeriteUI5_JuNNeZ_Edition"

local passed, failed = 0, 0
local function check(ok, label)
	if (ok) then
		passed = passed + 1
	else
		failed = failed + 1
		print("FAIL: " .. label)
	end
end

local function ReadFile(path)
	local fh = io.open(root .. "/" .. path, "rb")
	if (not fh) then return nil end
	local text = fh:read("*a")
	fh:close()
	return (text:gsub("\r\n", "\n"))
end

local function Exists(path)
	local fh = io.open(root .. "/" .. path, "rb")
	if (fh) then fh:close() return true end
	return false
end

-- Stubs ------------------------------------------------------------------------
local libs = {}
LibStub = setmetatable({}, { __call = function(_, major) return libs[major] end })

local frames = {}
CreateFrame = function()
	local f = { events = {} }
	function f:RegisterEvent(e) self.events[e] = true end
	function f:UnregisterEvent(e) self.events[e] = nil end
	function f:SetScript(_, fn) self.handler = fn end
	frames[#frames + 1] = f
	return f
end
C_AddOns = { GetAddOnMetadata = function(addon, key) return (addon == ADDON and key == "Version") and "test-version" or nil end }

local function NewMasque()
	local m = { skins = {}, order = {} }
	function m:AddSkin(id, data)
		if (self.skins[id]) then return end
		self.skins[id] = data
		self.order[#self.order + 1] = id
	end
	return m
end

local function Load()
	local ns = {}
	assert(loadfile(root .. "/Components/ActionBars/Compatibility/MasqueSkins.lua"))(ADDON, ns)
	return ns.ActionBarMasqueSkins
end

local function Fire(event, name)
	for _, f in ipairs(frames) do
		if (f.events[event] and f.handler) then f.handler(f, event, name) end
	end
end

-- 1. Deferred --------------------------------------------------------------------
libs.Masque = nil
frames = {}
local S = Load()
check(S ~= nil, "module exported as ns.ActionBarMasqueSkins")
check(#frames == 1 and frames[1].events.ADDON_LOADED, "waits for ADDON_LOADED without Masque")
local masque = NewMasque()
libs.Masque = masque
Fire("ADDON_LOADED", "Bartender4")
check(#masque.order == 0, "unrelated ADDON_LOADED registers nothing")
Fire("ADDON_LOADED", "Masque")
check(#masque.order == 44, "Masque's ADDON_LOADED registers 44 skins (got " .. #masque.order .. ")")
check(not frames[1].events.ADDON_LOADED, "stops listening after registering")

-- 2. Immediate --------------------------------------------------------------------
frames = {}
masque = NewMasque()
libs.Masque = masque
S = Load()
check(#frames == 0, "no watcher when Masque is already loaded")
check(#masque.order == 44, "registers at once when Masque is already loaded")
check(S.Register() == true and #masque.order == 44, "second Register adds nothing")

-- 3. Every skin -------------------------------------------------------------------
local SHAPES = { Circle = true, Square = true, Hexagon = true }
local LAYERS = { "Backdrop", "Icon", "Normal", "Border", "SpellHighlight", "Pushed", "Checked",
	"Highlight", "Flash", "Gloss", "Cooldown", "ChargeCooldown" }
local prefix = "Interface\\AddOns\\" .. ADDON .. "\\"
local function OnDisk(path, label)
	local ok = type(path) == "string" and path:sub(1, #prefix) == prefix
	check(ok, label .. ": path under our addon (" .. tostring(path) .. ")")
	if (ok) then
		local rel = path:sub(#prefix + 1):gsub("\\", "/")
		check(Exists(rel), label .. ": file exists " .. rel)
	end
end

local seen = {}
for _, id in ipairs(masque.order) do
	local skin = masque.skins[id]
	check(not seen[id], "unique skin ID " .. id)
	seen[id] = true
	check(id:match("^AzeriteUI") ~= nil, id .. ": ID sorts under AzeriteUI")
	check(SHAPES[skin.Shape], id .. ": Shape Masque has art for (" .. tostring(skin.Shape) .. ")")
	check(skin.API_VERSION == 120001, id .. ": API_VERSION set")
	check(skin.Version == "test-version", id .. ": version from TOC metadata")
	for _, layer in ipairs(LAYERS) do
		check(type(skin[layer]) == "table", id .. ": layer " .. layer .. " is a table")
	end
	check(skin.Gloss.Hide == true, id .. ": no gloss")
	for _, layer in ipairs(LAYERS) do
		local t = skin[layer]
		if (type(t) == "table" and layer ~= "Gloss") then
			check(type(t.Width) == "number" and t.Width > 0 and t.Width == t.Height, id .. ": " .. layer .. " square positive size")
			if (t.Texture) then OnDisk(t.Texture, id .. " " .. layer) end
		end
	end
	OnDisk(skin.Icon.Mask, id .. " Icon.Mask")
	OnDisk(skin.Normal.EmptyTexture, id .. " Normal.EmptyTexture")
	-- The icon-layer states keep the button shape: they use the icon's mask and size.
	for _, layer in ipairs({ "Pushed", "Checked", "Highlight", "Flash", "Cooldown", "ChargeCooldown" }) do
		check(skin[layer].Texture == skin.Icon.Mask and skin[layer].Width == skin.Icon.Width, id .. ": " .. layer .. " uses the icon mask")
	end
	check(skin.Normal.Width > skin.Icon.Width, id .. ": border larger than icon")
end
check(seen["AzeriteUI - Circle"] and seen["AzeriteUI - Hex"] and seen["AzeriteUI - Rounded"] and seen["AzeriteUI - Square"], "four stock skins")
check(seen["AzeriteUI Paladin - Hex"] and seen["AzeriteUI Death Knight - Circle"], "theme skins named Theme - Shape")
local hexBorder = masque.skins["AzeriteUI Paladin - Hex"].Normal.Texture
check(hexBorder:find("HexButtons\\Paladin\\border", 1, true) ~= nil, "Paladin hex uses the shared HexButtons painting")
local dkHex = masque.skins["AzeriteUI Death Knight - Hex"].Normal.Texture
check(dkHex:find("DeathKnight\\actionbutton-border-hex", 1, true) ~= nil, "Death Knight hex uses its own border")
check(masque.skins["AzeriteUI - Hex"].Shape == "Hexagon", "hex skin uses Masque's point-up Hexagon")

-- 4. Sizes and themes still match the source ---------------------------------------
local assets = ReadFile("Core/API/Assets.lua") or ""
local K = 36 / 64
local function near(a, b) return math.abs(a - b) < 1e-6 end
local expect = {
	hex = { id = "AzeriteUI - Hex" }, square = { id = "AzeriteUI - Square" }, rounded = { id = "AzeriteUI - Rounded" }
}
for key, e in pairs(expect) do
	local block = assets:match("\n\t" .. key .. " = (%b{})")
	check(block ~= nil, "BUTTON_SHAPES." .. key .. " found in Assets.lua")
	if (block) then
		local deco = tonumber(block:match("deco = ([%d%.]+)"))
		local icon = tonumber(block:match("icon = ([%d%.]+)")) or 60
		local glow = tonumber(block:match("glow = ([%d%.]+)")) or 117.5
		local skin = masque.skins[e.id]
		check(near(skin.Normal.Width, deco * K), key .. ": border size follows Assets.lua deco")
		check(near(skin.Icon.Width, icon * K), key .. ": icon size follows Assets.lua icon")
		check(near(skin.SpellHighlight.Width, glow * K), key .. ": glow size follows Assets.lua glow")
		for _, field in ipairs({ "mask", "backdrop", "border", "highlight" }) do
			local name = block:match(field .. ' = "([^"]+)"')
			check(name and skin and (skin.Icon.Mask .. skin.Backdrop.Texture .. skin.Normal.Texture .. skin.SpellHighlight.Texture):find(name, 1, true),
				key .. ": " .. field .. " texture matches Assets.lua")
		end
	end
end
local layout = ReadFile("Layouts/Data/ActionButton.lua") or ""
local circle = masque.skins["AzeriteUI - Circle"]
local cBorder = tonumber(layout:match("ButtonBorderSize = { ([%d%.]+)"))
local cIcon = tonumber(layout:match("ButtonIconSize = { ([%d%.]+)"))
check(cBorder and near(circle.Normal.Width, cBorder * K), "circle border size follows the layout")
check(cIcon and near(circle.Icon.Width, cIcon * K), "circle icon size follows the layout")

-- Every Assets/<Theme>/actionbutton-border.tga folder must be offered (Legacy excluded).
local offered = {}
for id in pairs(seen) do
	local theme = id:match("^AzeriteUI (.-) %- ")
	if (theme) then offered[(theme:gsub(" ", ""))] = true end
end
local listing = io.popen('dir /b /ad "' .. (root:gsub("/", "\\")) .. '\\Assets" 2>nul') or io.popen('ls -1 "' .. root .. '/Assets"')
if (listing) then
	for folder in listing:lines() do
		folder = folder:gsub("%s+$", "")
		if (folder ~= "Legacy" and Exists("Assets/" .. folder .. "/actionbutton-border.tga")) then
			check(offered[folder], "theme folder " .. folder .. " offered as Masque skins")
		end
	end
	listing:close()
end
check(not offered.Legacy, "Legacy art not offered")

print(string.format("masque_skins_harness: %d passed, %d failed", passed, failed))
os.exit(failed == 0 and 0 or 1)
