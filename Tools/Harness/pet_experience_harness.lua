-- Forever hunter pet XP bar (FixLog 2026-10-20). Extracts the real PetExperience_Update
-- from Components/UnitFrames/Units/Pet.lua: shown only for a hunter pet that can still
-- level (XP needed > 0, Blizzard's rule), hidden when switched off, for other pets and
-- without the API; secret XP is handed to the bar without being compared or capped.
-- Offline only: the bar's spot under each theme's pet casing is a live check.
-- Run: lua.exe Tools/Harness/pet_experience_harness.lua <addon root>
local root = arg[1] or "."
local file = assert(io.open(root .. "/Components/UnitFrames/Units/Pet.lua", "rb"))
local source = file:read("*a"):gsub("\r\n", "\n"); file:close()
local checks, failures = 0, 0
local function check(v, msg)
	checks = checks + 1
	if (not v) then failures = failures + 1; print("FAIL: " .. msg) end
end

local secretMeta = {}
for _, m in ipairs({ "__lt", "__le", "__add", "__sub", "__mul", "__div", "__concat", "__unm" }) do
	secretMeta[m] = function() error("secret value used in Lua logic", 2) end
end
local function secret(v) return setmetatable({ value = v }, secretMeta) end

local W = { hasUI = true, hunter = true, cur = 300, max = 1000 }
local profile = { showPetExperience = true }
local env = setmetatable({
	issecretvalue = function(v) return getmetatable(v) == secretMeta end,
	HasPetUI = function() return W.hasUI, W.hunter end,
	GetPetExperience = function() return W.cur, W.max end,
	PetFrameMod = { db = { profile = profile } },
}, { __index = _G })
local body = assert(source:match("(local PetExperience_Update = function.-\nend)\n"), "PetExperience_Update found")
local chunk = assert(loadstring(body .. "\nreturn PetExperience_Update"))
setfenv(chunk, env)
local Update = chunk()

local function Bar()
	local b = {}
	function b:Show() self.shown = true end
	function b:Hide() self.shown = false end
	function b:SetMinMaxValues(a, z) self.min, self.max = a, z end
	function b:SetValue(v) self.value = v end
	return b
end
local frame = { PetExperience = Bar() }

Update(frame)
check(frame.PetExperience.shown == true and frame.PetExperience.max == 1000 and frame.PetExperience.value == 300, "levelling pet: shown 300/1000")

W.max = 0; Update(frame)
check(frame.PetExperience.shown == false, "pet at cap (XP needed 0): hidden")

W.max, W.cur = 1000, 1200; Update(frame)
check(frame.PetExperience.value == 1000, "overflow capped to the max")

W.hunter = false; Update(frame)
check(frame.PetExperience.shown == false, "warlock demon / no hunter pet: hidden")
W.hunter = true

W.hasUI = false; Update(frame)
check(frame.PetExperience.shown == false, "no pet: hidden")
W.hasUI = true

profile.showPetExperience = false; Update(frame)
check(frame.PetExperience.shown == false, "switched off: hidden")
profile.showPetExperience = true

W.cur, W.max = secret(10), secret(20)
local ok, err = pcall(Update, frame)
check(ok, "secret XP raises nothing: " .. tostring(err))
check(frame.PetExperience.shown == true and frame.PetExperience.value == W.cur and frame.PetExperience.max == W.max, "secret XP handed to the bar as is")

check(pcall(Update, {}) , "a frame without the bar is a no-op")

print(("Pet experience: %d checks, %d failures (offline only)"):format(checks, failures))
os.exit(failures == 0 and 0 or 1)
