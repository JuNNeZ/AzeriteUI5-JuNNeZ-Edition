-- Locale parity for the ten Locale/*.lua files.
-- Each file is loaded through a stub AceLocale that records every assignment, so keys are read
-- exactly as the client reads them. Matching keys with a pattern over the source is how two live
-- keys containing \n were once deleted from every locale (Docs/TODO.md item 6); this does not parse.
-- Checks: every locale holds exactly the enUS keys, once each; every value is a non-empty string;
-- every value carries the same format specifiers in the same order as its key, because Lua 5.1's
-- string.format has no positional arguments; preview explanations fit the options panel's footer,
-- and the two rail tabs fit their slots, in every language.
-- lua Tools/Harness/locale_harness.lua .
-- Mutations: the "locale" entries in mutate_client.lua.
local root = arg[1] or "."
local LOCALES = { "enUS", "deDE", "esES", "frFR", "itIT", "koKR", "ptBR", "ruRU", "zhCN", "zhTW" }
local checks, failures = 0, 0
local function check(value, label, detail)
	checks = checks + 1
	if (not value) then
		failures = failures + 1
		print("FAIL: " .. label .. (detail and detail ~= "" and (" - " .. detail) or ""))
	end
end

local function ReadFile(path)
	local file = assert(io.open(path, "rb"), "missing " .. path)
	local text = file:read("*a")
	file:close()
	return text
end

-- Loads one locale file the way AceLocale does, keeping every assignment in order.
local function Load(code)
	local values, order, duplicates = {}, {}, {}
	local L = setmetatable({}, {
		__newindex = function(_, key, value)
			if (values[key] ~= nil) then duplicates[#duplicates + 1] = key end
			values[key] = value
			order[#order + 1] = key
		end
	})
	local env = setmetatable({
		LibStub = function() return { NewLocale = function() return L end } end
	}, { __index = _G })
	local chunk = assert(loadfile(root .. "/Locale/" .. code .. ".lua"))
	setfenv(chunk, env)
	chunk("AzeriteUI5_JuNNeZ_Edition")
	return values, order, duplicates
end

-- No space flag: no key uses one, and prose such as "Taille % des" would read as "% d".
local function Specifiers(text)
	local list = {}
	for spec in text:gmatch("%%[-+#0]*%d*%.?%d*[%a%%]") do list[#list + 1] = spec end
	return table.concat(list, " ")
end

-- The panel harness's font model: 6.2 px a character. A character of three or more UTF-8 bytes
-- (Chinese, Korean, full-width punctuation) is counted as two.
local function Width(text)
	local units = 0
	for char in text:gmatch("[%z\1-\127\194-\244][\128-\191]*") do
		units = units + ((#char >= 3) and 2 or 1)
	end
	return units * 6.2
end

-- The footer and tab widths come from the panel's own constants.
local panel = ReadFile(root .. "/Options/Kit/Panel.lua")
local minW = tonumber(panel:match("local MIN_W, MIN_H = (%d+)"))
local inset = tonumber(panel:match("local FOOTER_INSET = (%d+)"))
local left, right = panel:match("local PREVIEW_LEFT, PREVIEW_RIGHT = (%-?%d+), (%-?%d+)")
local railW = tonumber(panel:match("local RAIL_W = (%d+)"))
check(minW and inset and left and railW, "the panel's size constants can be read from Panel.lua")
-- Panel.PreviewMinWidth, the formula in Panel.lua; 446 px at the time of writing.
local footerWidth = minW and ((minW - inset * 2) / 2 - tonumber(left) + tonumber(right)) or 0
-- Each tab is (RAIL_W - 10) / 2 wide; leave 4 px either side of its centred label.
local tabWidth = railW and ((railW - 10) / 2 - 8) or 0

-- Every explanation the preview policies can put in the footer.
local preview = ReadFile(root .. "/Options/Kit/Preview.lua")
local explanations, seen = {}, {}
for key in preview:gmatch('explain%s*=%s*L%["(.-)"%]') do
	if (not seen[key]) then seen[key] = true; explanations[#explanations + 1] = key end
end
for key in preview:gmatch('Plates%([^,]+,%s*L%["(.-)"%]%)') do
	if (not seen[key]) then seen[key] = true; explanations[#explanations + 1] = key end
end
check(#explanations >= 10, "the preview explanations can be read from Preview.lua", tostring(#explanations))

local enUS, enOrder, enDuplicates = Load("enUS")
check(#enDuplicates == 0, "enUS defines each key once", table.concat(enDuplicates, " | "))
local enCount, notTrue = 0, {}
for _, key in ipairs(enOrder) do
	enCount = enCount + 1
	if (enUS[key] ~= true) then notTrue[#notTrue + 1] = key end
end
check(#notTrue == 0, "every enUS value is true", table.concat(notTrue, " | "))
for _, key in ipairs(explanations) do
	check(enUS[key] ~= nil, "enUS defines the explanation: " .. key)
end

local counts = {}
for index = 2, #LOCALES do
	local code = LOCALES[index]
	local values, order, duplicates = Load(code)
	counts[#counts + 1] = code .. " " .. #order
	check(#duplicates == 0, code .. " defines each key once", table.concat(duplicates, " | "))

	local missing, extra, empty, mismatched = {}, {}, {}, {}
	for _, key in ipairs(enOrder) do
		if (values[key] == nil) then missing[#missing + 1] = key end
	end
	for _, key in ipairs(order) do
		local value = values[key]
		if (enUS[key] == nil) then
			extra[#extra + 1] = key
		elseif (type(value) ~= "string" or value == "") then
			empty[#empty + 1] = key
		elseif (Specifiers(key) ~= Specifiers(value)) then
			mismatched[#mismatched + 1] = string.format("%s [%s] vs [%s]", key, Specifiers(key), Specifiers(value))
		end
	end
	check(#missing == 0, code .. " has every enUS key", #missing .. " missing, first: " .. tostring(missing[1]))
	check(#extra == 0, code .. " has no key enUS lacks", table.concat(extra, " | "))
	check(#empty == 0, code .. " has a string for every key", table.concat(empty, " | "))
	check(#mismatched == 0, code .. " keeps every format specifier in order", table.concat(mismatched, " | "))

	local tooWide = {}
	for _, key in ipairs(explanations) do
		local value = values[key]
		if (type(value) == "string" and Width(value) > footerWidth) then
			tooWide[#tooWide + 1] = string.format("%s (%.0f px of %.0f)", key, Width(value), footerWidth)
		end
	end
	check(#tooWide == 0, code .. " explanations fit the footer at the smallest window", table.concat(tooWide, " | "))

	-- The rail's band headings are drawn in capitals on one line from 12 px in to 8 px short of
	-- the rail's edge (Panel.lua BuildRail); capitals are counted a tenth wider.
	local bandsBlock = panel:match("local SECTIONS = (%b{})") or ""
	for key in bandsBlock:gmatch('label = L%["(.-)"%]') do
		local value = values[key]
		check(type(value) == "string" and Width(value:upper()) * 1.1 <= railW - 20,
			code .. " band heading fits the rail: " .. key, tostring(value))
	end

	for _, key in ipairs({ "Options", "Settings" }) do
		local value = values[key]
		check(type(value) == "string" and Width(value) <= tabWidth,
			code .. " tab label fits its tab: " .. key, tostring(value))
	end
end

-- The code against enUS (Docs/Options Navigation Review - 2026-11-22.md, step 0b).
-- enUS is a silent default locale (NewLocale(..., true, true)): a key the code asks for and no
-- locale defines shows its own English text on every client, with nothing to say so. That is how
-- the Guild Manager crafting preview said Yes and No in English everywhere. Keys are read with
-- Lua's own string parser, so escapes such as \n compare as the locale files store them.
-- Page keys and links to pages are plain strings, never L[...]: a translated page key differs per
-- client, and every English path to it then missed the page off English clients (B1/B2).
local function LiteralKeys(text)
	local list, pos = {}, 1
	while true do
		local s, e, quote = text:find("%f[%w_]L%[%s*([\"'])", pos)
		if (not s) then break end
		local i = e + 1
		while (i <= #text) do
			local c = text:sub(i, i)
			if (c == "\\") then i = i + 2
			elseif (c == quote) then break
			else i = i + 1 end
		end
		if (text:match("^%s*%]", i + 1)) then
			local ok, key = pcall(assert(loadstring("return " .. text:sub(e, i))))
			if (ok and type(key) == "string") then list[#list + 1] = key end
		end
		pos = i + 1
	end
	return list
end

local PAGE_LINKS = {
	{ "Options:AddGroup%(%s*[^\"%s]", "AddGroup's page key" },
	{ "page%s*=%s*L%[", "a What's New page" },
	{ ":Open%(%s*L%[", "Panel:Open" },
	{ ":OpenSection%(%s*L%[", "Panel:OpenSection" },
	{ ":OpenSection%([^,\n]+,%s*{%s*L%[", "Panel:OpenSection path" },
	{ ":GoTo%(%s*{%s*L%[", "Panel:GoTo" },
	{ ":SelectPage%(%s*L%[", "Panel:SelectPage" }
}

-- The keys enUS knows: the ten files above, plus the topic files Locale.xml loads after them
-- (Details.lua, Halloween.lua), which call NewLocale once per language themselves.
local known = {}
for key in pairs(enUS) do known[key] = true end
local localeXml = ReadFile(root .. "/Locale/Locale.xml")
local isMain = {}
for _, code in ipairs(LOCALES) do isMain[code .. ".lua"] = true end
local topicFiles = 0
for file in localeXml:gmatch('<Script file="([^"]+)"') do
	if (not isMain[file]) then
		local recorder = setmetatable({}, { __newindex = function(_, key) known[key] = true end })
		local sink = setmetatable({}, { __newindex = function() end })
		local ace = { NewLocale = function(_, _, code) return (code == "enUS") and recorder or sink end }
		local chunk = assert(loadfile(root .. "/Locale/" .. file))
		setfenv(chunk, setmetatable({ LibStub = function() return ace end }, { __index = _G }))
		chunk("AzeriteUI5_JuNNeZ_Edition")
		topicFiles = topicFiles + 1
	end
end
check(topicFiles >= 2, "the topic locale files in Locale.xml load", topicFiles)

local listing = io.popen('git -C "' .. root .. '" ls-files --cached --others --exclude-standard -- "*.lua"')
local scanned, used, unknown, translatedPages = 0, 0, {}, {}
for file in (listing and listing:lines() or function() end) do
	if (not file:find("^Libs/") and not file:find("^Locale/") and not file:find("^Tools/")
		and not file:find("^%.research/") and not file:find("^Docs/")) then
		local handle = io.open(root .. "/" .. file, "rb")
		if (handle) then
			local text = handle:read("*a")
			handle:close()
			scanned = scanned + 1
			for _, key in ipairs(LiteralKeys(text)) do
				used = used + 1
				if (not known[key]) then unknown[#unknown + 1] = file .. ": " .. key:gsub("\n", "\\n") end
			end
			for _, rule in ipairs(PAGE_LINKS) do
				local at = text:find(rule[1])
				if (at) then
					local line = select(2, text:sub(1, at):gsub("\n", "")) + 1
					translatedPages[#translatedPages + 1] = string.format("%s:%d (%s)", file, line, rule[2])
				end
			end
		end
	end
end
if (listing) then listing:close() end
check(scanned > 100 and used > 1000, "the addon's code can be scanned for L[...]",
	string.format("%d files, %d uses", scanned, used))
check(#unknown == 0, "every L[...] the code uses exists in enUS", table.concat(unknown, " | "))
check(#translatedPages == 0, "page keys and links to pages are plain strings, not L[...]",
	table.concat(translatedPages, " | "))

print(string.format("Locales: %d checks, %d failures (enUS %d keys; %s)", checks, failures, enCount,
	table.concat(counts, ", ")))
-- Raised rather than os.exit, so mutate_client.lua can run this inside a pcall.
if (failures > 0) then error("locale harness failed", 0) end
