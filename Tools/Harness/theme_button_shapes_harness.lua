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
load("Core/ThemeEngine.lua")
load("Core/PaladinTheme.lua")
load("Core/HunterMedia.lua")
load("Core/HunterTheme.lua")
load("Core/MageTheme.lua")
load("Core/DruidTheme.lua")
load("Core/WarriorTheme.lua")
load("Core/RogueTheme.lua")
load("Core/ShamanTheme.lua")
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
	local folder = theme == "mage" and "Mage" or theme == "hunter" and "Hunter" or theme == "paladin" and "Paladin" or nil
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
-- Hex uses our original generated border on stock and intact class paintings.
for _, theme in ipairs({ "azerite", "hunter", "mage", "paladin", "druid", "warrior", "rogue", "shaman" }) do
	ns.db.char = {}
	if theme ~= "azerite" then ns.db.char[theme.."Preview"] = true end
	local active = ns.ThemeEngine:GetActive()
	check((active ~= nil) == (theme ~= "azerite"), "real theme selection: "..theme)
	for name, original in pairs(originals) do
		local base = ns.GetConfig(name)
		local shaped = ns.API.GetShapedButtonConfig(base, "hex")
		local extra = name == "ExtraActionButton"
		local prefix = extra and "ExtraButton" or "Button"
		local own = active and active:ResolveOwnMedia("portrait_frame_hi")
		local folder = own and own:match("[\\/]Assets[\\/]([^\\/]+)[\\/]portrait_frame_hi%.tga$")
		local expected = folder and asset("HexButtons\\"..folder.."\\border") or asset("actionbutton-border-hex")
		check(shaped[prefix.."BorderTexture"] == expected, "whole hex class painting: "..theme..name)
		check(shaped[extra and "ExtraButtonMask" or "ButtonMaskTexture"] == asset("actionbutton-mask-hex"), "hex cooldown and icon mask")
		check(shaped[prefix.."Size"] == base[prefix.."Size"], "hex keeps cells and layout")
		local scale = base[prefix.."Size"][1]/64
		check(shaped[prefix.."BorderSize"][1] == 96*scale and shaped[prefix.."IconSize"][1] == 50*scale, "hex frame unchanged; icon fits painted opening")
		local color, originalColor = shaped[prefix.."BorderColor"], base[prefix.."BorderColor"]
		check(color == originalColor, "hex uses native tint; no blanket reflection dimming")
		if (arg[2] == "export" and name == "ActionButton") then
			for _, shape in ipairs({"circle", "square", "rounded", "hex"}) do
				local cfg = ns.API.GetShapedButtonConfig(base, shape)
				local a, b = cfg.ButtonBorderColor, cfg.ButtonBackdropColor
				print(table.concat({"REVIEW", theme, shape, cfg.ButtonBorderTexture, cfg.ButtonBorderSize[1], a[1],a[2],a[3],
					cfg.ButtonMaskTexture, cfg.ButtonIconSize[1], cfg.ButtonBackdropTexture, cfg.ButtonBackdropSize[1], b[1],b[2],b[3]}, "|"))
			end
		end
		if extra then
			check(shaped.ExtraButtonCooldownSize[1] == shaped.ExtraButtonIconSize[1], "extra cooldown fits hex icon")
		else
			check(shaped.ButtonHighlightShape == "hex", "hex custom proc and assisted styles")
		end
		local f = assert(io.open(root.."/"..expected:match("Assets\\.*$"):gsub("\\", "/"), "rb")); f:close()
		check(original[prefix.."BorderTexture"] == asset("actionbutton-border"), "hex never mutates source layout")
	end
end
check(ns.API.IsButtonShape("hex") and not ns.API.IsButtonShape("bogus"), "shape validation")
-- Explicit dormant CD skins never borrow an active interface theme.
ns.db.char = { hunterPreview = true }
for _, name in ipairs({ "actionbutton-border-square", "actionbutton-border-square-rounded" }) do
	check(ns.MageTheme:ResolveOwnMedia(name) == asset(name, "Mage"), "dormant Mage own border")
	check(ns.HunterTheme:ResolveOwnMedia(name) == asset(name, "Hunter"), "Hunter own border")
	check(ns.PaladinTheme:ResolveOwnMedia(name) == asset(name, "Paladin"), "Paladin own border")
end
ns.LegacyHUD = { IsActive = function() return true end }
for name, base in pairs(originals) do
	for _, shape in ipairs({ "square", "rounded", "hex" }) do
		check(ns.API.GetShapedButtonConfig(base, shape) == base, "Legacy ignores shapes: " .. name)
	end
end
ns.LegacyHUD = nil
ns.variant = "SaiyaRatt"
check(ns.API.GetMedia("actionbutton-border-square") == asset("actionbutton-border-square"), "other variant retains shared art")
print("Theme button shapes: " .. checks .. " checks passed (offline only)")
