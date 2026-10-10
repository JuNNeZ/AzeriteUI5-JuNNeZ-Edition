-- Real media dispatch and layout copies, without WoW rendering.
-- lua Tools/Harness/theme_button_shapes_harness.lua .
local root = arg[1] or "."
local checks = 0
local function check(v, label) assert(v, label); checks = checks + 1 end
local env = setmetatable({}, { __index = _G })
env._G = env
env.CreateFont = function() return { SetJustifyH = function() end, GetObjectType = function() return "Font" end } end
local ns = { API = {}, Prefix = "ShapeTest" }
function ns:NewModule() return {} end
function ns:GetActiveConfigVariant() return self.variant end
function ns:IsSaiyaRattProfile() return self.variant == "SaiyaRatt" end
local function load(path)
	local chunk = assert(loadfile(root .. "/" .. path)); setfenv(chunk, env)
	chunk("AzeriteUI5_JuNNeZ_Edition", ns)
end
load("Core/API/Assets.lua")
load("Core/PaladinTheme.lua")
load("Core/HunterMedia.lua")
load("Core/HunterTheme.lua")
load("Core/MageTheme.lua")
ns.Colors = { ui = { .75,.75,.75 }, quest = { gray = {.6,.6,.6} }, normal = {.9,.8,.5}, highlight = {.9,.8,.5} }
load("Layouts/Layouts.lua")
for _, name in ipairs({ "ActionButton", "PetActionButton", "StanceButton", "ExtraActionButton" }) do
	load("Layouts/Data/" .. name .. ".lua")
end
local function asset(name, theme)
	return "Interface\\AddOns\\AzeriteUI5_JuNNeZ_Edition\\Assets\\" .. (theme and theme .. "\\" or "") .. name .. ".tga"
end
local originals = {}
for _, name in ipairs({ "ActionButton", "PetActionButton", "StanceButton", "ExtraActionButton" }) do originals[name] = ns.GetConfig(name) end
ns.db = { global = { enableDevelopmentMode = true }, char = {} }
for _, theme in ipairs({ "azerite", "mage", "hunter", "paladin" }) do
	ns.db.char = { magePreview = theme == "mage", hunterPreview = theme == "hunter", paladinPreview = theme == "paladin" }
	local folder = theme == "mage" and "Mage" or theme == "hunter" and "Hunter" or nil
	for name, original in pairs(originals) do
		local base = ns.GetConfig(name)
		for _, shape in ipairs({ "square", "rounded" }) do
			local suffix = shape == "rounded" and "-rounded" or ""
			local shaped = ns.API.GetShapedButtonConfig(base, shape)
			local extra = name == "ExtraActionButton"
			local prefix = extra and "ExtraButton" or "Button"
			check(shaped ~= base, theme .. name .. shape .. " copies config")
			check(shaped[prefix .. "BorderTexture"] == asset("actionbutton-border-square" .. suffix, folder), theme .. name .. shape .. " themed border")
			local maskKey = extra and "ExtraButtonMask" or "ButtonMaskTexture"
			check(shaped[maskKey] == asset("actionbutton-mask-square" .. suffix), theme .. name .. shape .. " shared mask")
			local cell = original[prefix .. "Size"][1]
			check(shaped[prefix .. "Size"] == base[prefix .. "Size"], "cell unchanged")
			check(math.abs(shaped[prefix .. "BorderSize"][1] - (shape == "rounded" and 93.1 or 96.3)*cell/64) < .0001, "shared border size")
			check(shaped[prefix .. "IconSize"][1] == 60*cell/64, "shared icon size")
			check(original[prefix .. "BorderTexture"] == asset("actionbutton-border"), "original layout untouched")
			if not extra then
				check(shaped.ButtonBackdropTexture == asset("actionbutton-backdrop-square" .. suffix), "shared backdrop")
				check(shaped.ButtonSpellHighlightTexture == asset("actionbutton-spellhighlight-square" .. suffix), "shared highlight")
			end
			local disk = assert(io.open(root .. "/" .. shaped[prefix .. "BorderTexture"]:match("Assets\\.*$"):gsub("\\", "/"), "rb"))
			disk:close(); check(true, "resolved border shipped")
		end
		check(ns.API.GetShapedButtonConfig(base, "circle") == base, "circle keeps theme config")
	end
end
-- Explicit dormant CD skins never borrow an active interface theme.
ns.db.char = { hunterPreview = true }
for _, name in ipairs({ "actionbutton-border-square", "actionbutton-border-square-rounded" }) do
	check(ns.MageTheme:ResolveOwnMedia(name) == asset(name, "Mage"), "dormant Mage own border")
	check(ns.HunterTheme:ResolveOwnMedia(name) == asset(name, "Hunter"), "Hunter own border")
	check(ns.PaladinTheme:ResolveOwnMedia(name) == nil, "Paladin fallback")
end
ns.LegacyHUD = { IsActive = function() return true end }
for name, base in pairs(originals) do
	for _, shape in ipairs({ "square", "rounded" }) do
		check(ns.API.GetShapedButtonConfig(base, shape) == base, "Legacy ignores shapes: " .. name)
	end
end
ns.LegacyHUD = nil
ns.variant = "SaiyaRatt"
check(ns.API.GetMedia("actionbutton-border-square") == asset("actionbutton-border-square"), "other variant retains shared art")
print("Theme button shapes: " .. checks .. " checks passed (offline only)")
