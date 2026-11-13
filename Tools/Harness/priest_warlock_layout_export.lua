-- Execute current layout tables for offline geometry projection; no WoW emulation.
local root, output = arg[1] or ".", assert(arg[2], "output path required")
local layouts = {}
local color = { 1, 1, 1, 1 }
setmetatable(color, { __index = function() return color end })
local palette = setmetatable({ ui = { 192/255, 192/255, 192/255 } }, { __index = function() return color end })
local ns = { Colors = palette, API = {
	GetFont = function() return nil end,
	GetMedia = function(name) return "Interface/Assets/"..name..".tga" end
} }
ns.RegisterConfig = function(name, data) layouts[name] = data end
ns.RegisterConfigVariant = function() end
for _, file in ipairs({ "PlayerUnitFrame", "TargetUnitFrame", "PlayerCastBar", "PetUnitFrame",
	"FocusUnitFrame", "ToTUnitFrame", "PartyUnitFrames", "RaidUnitFrames5", "RaidUnitFrames40",
	"ArenaEnemyUnitFrames", "BossUnitFrames", "MirrorTimers", "Minimap", "ActionButton", "PlayerClassPower" }) do
	assert(loadfile(root.."/Layouts/Data/"..file..".lua"))("AzeriteUI5_JuNNeZ_Edition", ns)
end
local export = assert(loadfile(root.."/Tools/Harness/liteplus_preview_export.lua"))()
export.Write(output, { original = layouts, geometryOnly = true, coloursArePlaceholders = true })
print("Exported current layout geometry; colours/fonts are offline placeholders")
