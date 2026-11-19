-- Elune Lua 5.1 only. Isolate the native chat menu's font-size generator.
local root = arg[1] or "."
local function read(path)
	local file = assert(io.open(root .. "/" .. path, "rb"))
	local source = file:read("*a"):gsub("\r\n", "\n")
	file:close()
	return source
end

local source = read(".research/tmp/wow-ui-source-forever/Interface/AddOns/Blizzard_ChatFrameBase/Mainline/FloatingChatFrame.lua")
local fontHeights = assert(source:match("(CHAT_FONT_HEIGHTS = {%s*.-\n})"))
local radioLoop = assert(source:match("(for i = 1, #CHAT_FONT_HEIGHTS do.-\n%s*end)"))
local native = assert(loadstring(fontHeights .. "\nreturn function(fontSizeSubmenu)\n"
	.. "local IsSelected, SetSelected = function() end, function() end\n"
	.. radioLoop .. "\nend"))
local addon = assert(loadstring(read("Components/Misc/ChatFrames.lua")))

local function run(isForever)
	local module = { GetName = function() return "ChatFrames" end, RegisterChatCommand = function() end }
	local frameMethods = {}
	local globals = setmetatable({
		CreateFrame = function() return setmetatable({}, { __index = frameMethods }) end,
		FONT_SIZE_TEMPLATE = "%d",
		format = string.format,
	}, { __index = _G })
	local ns = {
		IsForever = isForever,
		API = { IsAddOnEnabled = function() return false end },
		NewModule = function() return module end,
		Merge = function(_, defaults) return defaults end,
		MovableModulePrototype = { defaults = {} },
		db = { RegisterNamespace = function() return {} end },
	}
	setfenv(native, globals)
	local addFontChoices = native()
	local heights = globals.CHAT_FONT_HEIGHTS
	local nativeCount, nativeFirst = #heights, heights[1]
	setfenv(addon, globals)
	addon("AzeriteUI5_JuNNeZ_Edition", ns)
	securecall(function()
		debug.setstacktaint("AzeriteUI5_JuNNeZ_Edition")
		module:OnInitialize()
	end)
	assert(issecure(), "initializer tainted the isolated caller")

	-- Menu.PopulateDescription invokes its generator inside a secure call.
	local count, first, insecure = 0, nil, false
	securecall(addFontChoices, {
		CreateRadio = function(_, _, _, _, height)
			count = count + 1
			first = first or height
			insecure = insecure or not issecure()
		end,
	})
	assert(issecure(), "generator taint escaped its protected call")
	if isForever then
		assert(not insecure, "Forever native font options were generated in tainted execution")
		assert(count == nativeCount and first == nativeFirst, "Forever native font choices changed")
	else
		assert(count == 9 and first == 12, "Retail lost the existing custom font choices")
		assert(insecure, "the positive control did not observe the addon write")
	end
end

run(true)
run(false)
print("native_chat_font_taint: Forever native font generator stays secure; Retail choices preserved")
