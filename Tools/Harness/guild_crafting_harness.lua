-- Offline crafting contracts. No client or real guild queries are operated.
local root = arg[1] or "."
dofile(root .. "/Libs/LibStub/LibStub.lua")
dofile(root .. "/Libs/AceSerializer-3.0/AceSerializer-3.0.lua")
local serializer = LibStub("AceSerializer-3.0")
local secret, checks, combat, inGuild = {}, 0, false, true
local guild, actor, now = "Guild", "Player-Self", 1794744000
local function check(value, label) checks = checks+1; assert(value, label) end
issecretvalue = function(value) return value == secret end
InCombatLockdown = function() return combat end
IsInGuild = function() return inGuild end
GetGuildInfo = function() return guild end
GetNormalizedRealmName = function() return "TestRealm" end
UnitGUID = function() return actor end
UnitFullName = function() return "Main Person", "TestRealm" end
time = function() return now end
local function Row(name, guid, online)
    local row = { name .. "-TestRealm", "Member", 1, 60, "Mage", "Town", "Public", "OFFICER SECRET", online }
    row[17] = guid; return row
end
local roster = { Row("Main Person", actor, true), Row("Alt Person", "Player-Other", false) }
GetNumGuildMembers = function() return #roster end
GetGuildRosterInfo = function(index) return unpack(roster[index], 1, 17) end
local timers, queries = {}, {}
C_Timer = { After = function(_, callback) timers[#timers+1] = callback end }
local ready, linked, guildSkill, memberSkill = true, false, false, false
local profession, ids = { professionID = 171, professionName = "Alchemy" }, { 1, 2, 3 }
local recipes = { [1] = { name = "Healing Potion", learned = true }, [2] = { name = "Unknown Elixir", learned = false },
    [3] = { name = "Mana Potion", learned = true } }
C_TradeSkillUI = {
    IsTradeSkillReady = function() return ready end, IsTradeSkillLinked = function() return linked end,
    IsTradeSkillGuild = function() return guildSkill end, IsTradeSkillGuildMember = function() return memberSkill end,
    GetBaseProfessionInfo = function() return profession end, GetAllRecipeIDs = function() return ids end,
    GetRecipeInfo = function(id) return recipes[id] end,
    GetRecipeItemLink = function(id) return "|cffffffff|Hitem:" .. (1000+id) .. ":0|h[Crafted Item " .. id .. "]|h|r" end }
local queryProfession, queryID, queryCount = 171, 1, 1
C_GuildInfo = { QueryGuildMembersForRecipe = function(pid, id) queries[#queries+1] = {pid, id}; return id end }
GetGuildRecipeInfoPostQuery = function() return queryProfession, queryID, queryCount end
GetGuildRecipeMember = function() return "Alt Person", "Alt Person-TestRealm", "MAGE", true end
local module = { DisableSettingsExport = function() end }
local ns = { NewModule = function() return module end, GetModule = function() return module end,
    db = { RegisterNamespace = function(_, _, defaults) return { profile = defaults.profile, global = defaults.global, RegisterCallback = function() end } end } }
for _, file in ipairs({ "GuildManager", "GuildManagerData", "GuildManagerCrafting" }) do
    assert(loadfile(root .. "/Components/Misc/" .. file .. ".lua"))("Test", ns)
end
module:OnInitialize(); module:ReadRoster()
local own, other = module:CharacterKey("Main Person"), module:CharacterKey("Alt Person")
check(module:ScanOwnCrafting(), "own ready profession scanned")
local saved = module.db.global.crafting[own][171]
check(saved.source == "own" and saved.snapshot.recipes[1] and not saved.snapshot.recipes[2], "only learned recipes stored with local source")
check(saved.snapshot.recipes[1].itemID == 1001 and saved.snapshot.recipes[1].itemName == "Crafted Item 1", "crafted item ID and plain label read without storing markup")
local count = 0; for _ in pairs(saved.snapshot.recipes) do count = count+1 end
check(count == 2 and saved.snapshot.scanned == now, "scan records count and timestamp")
linked = true; check(not module:ScanOwnCrafting(), "linked profession cannot be attributed to player")
linked = false; guildSkill = true; check(not module:ScanOwnCrafting(), "guild profession cannot be attributed to player")
guildSkill = false; memberSkill = true; check(not module:ScanOwnCrafting(), "inspected guild member cannot be attributed to player")
memberSkill = false; ready = false; check(not module:ScanOwnCrafting(), "incomplete profession rejected")
ready = secret; check(not module:ScanOwnCrafting(), "secret readiness rejected")
ready = true; recipes[3] = nil; check(not module:ScanOwnCrafting(), "partial recipe cache rejects whole scan")
check(module.db.global.crafting[own][171] == saved, "failed scan retains prior snapshot")
recipes[3] = { name = "Mana Potion", learned = true }
combat = true; check(not module:ScanOwnCrafting() and #queries == 0, "combat prevents scan without native queries")
combat = false
local allIDs = C_TradeSkillUI.GetAllRecipeIDs; C_TradeSkillUI.GetAllRecipeIDs = nil
check(not module:ScanOwnCrafting(), "unsupported API disables scan")
C_TradeSkillUI.GetAllRecipeIDs = allIDs
module:SaveIdentity("Main Person", "Junnez", "")
check(#module:GetCraftingRows("junnez", false) == 2 and #module:GetCraftingRows("1001", false) == 1, "nickname and item-ID search")
check(#module:GetCraftingRows("alchemy", false) == 2 and #module:GetCraftingRows("unknown elixir", false) == 0, "profession search excludes unlearned recipes")
local row = module:GetCraftingRows("healing", false)[1]
local exported = assert(module:ExportCrafting(row))
check(not exported:find("SECRET", 1, true) and not exported:find("Junnez", 1, true) and not exported:find("nickname", 1, true), "export contains recipes without identity/private/guild notes")
actor = "Player-Other"; check(not module:ExportCrafting(row), "only current character can export own scanned list")
actor = "Player-Self"
local function Encode(input) return "AZCRAFT:1:" .. serializer:Serialize(input) end
local input = { owner = other, guid = "Player-Other", professionID = 171, profession = "Alchemy", scanned = now,
    recipes = { [1] = { name = "Healing Potion", itemID = 1001, itemName = "Healing Drink" } } }
local text = Encode(input)
local preview = assert(module:PreviewCraftingImport(text))
check(preview.name == "Alt Person-TestRealm" and preview.count == 1 and not preview.replacing, "import preview checks current guild character/GUID")
input.privateNote = "Injected"; check(not module:PreviewCraftingImport(Encode(input)), "unknown snapshot fields rejected")
input.privateNote = nil; input.recipes[1].extra = true; check(not module:PreviewCraftingImport(Encode(input)), "unknown recipe fields rejected")
input.recipes[1].extra = nil; input.recipes[1].name = "|Hitem:1|hX|h"; check(not module:PreviewCraftingImport(Encode(input)), "recipe markup rejected")
input.recipes[1].name = "Healing Potion"; input.guid = "Wrong GUID"; check(not module:PreviewCraftingImport(Encode(input)), "guild GUID mismatch rejected")
input.guid = "Player-Other"; input.scanned = now+301; check(not module:PreviewCraftingImport(Encode(input)), "future reported scan rejected")
input.scanned = now; input.owner = "outsider-testrealm"; check(not module:PreviewCraftingImport(Encode(input)), "non-guild owner rejected")
input.owner = other
check(not module:PreviewCraftingImport("AZCRAFT:1:" .. string.rep("^T", 10000)), "deep payload rejected before deserializer")
check(not module:PreviewCraftingImport("AZCRAFT:1:" .. string.rep("x", 500001)), "oversized payload rejected")
check(not module:ImportCrafting(Encode({}), preview), "changed unreviewed text cannot import")
guild = "Different Guild"; check(not module:ImportCrafting(text, preview), "guild switch rejects old confirmation")
guild = "Guild"; combat = true; check(not module:ImportCrafting(text, preview), "combat confirmation never imports")
combat = false
check(module:ImportCrafting(text, preview), "explicit reviewed import succeeds")
check(not module:ImportCrafting(text, preview), "revision makes import confirmation single-use")
check(module.db.global.crafting[other][171].source == "import", "manual import never claims verified ownership")
check(#module:GetCraftingRows("", false) == 3 and #module:GetCraftingRows("", true) == 2, "offline imported crafter remains searchable and online filter works")
check(module:UndoCrafting() and not module.db.global.crafting[other], "crafting Undo restores previous storage")
check(not module:ImportCrafting(text, preview), "Undo also invalidates stale preview")
check(module:QueryCrafting(row) and #queries == 1 and queries[1][1] == 171, "explicit selected recipe queries native guild data")
queryID = 3; module:OnCraftingQuery(); check(module.craftingPending and not module.craftingResults, "unrelated recipe response ignored")
queryID = 1; module:OnCraftingQuery()
check(not module.craftingPending and #module.craftingResults.rows == 1, "matching native response accepted")
local native = module:GetCraftingRows("healing", false)
check(#native == 2 and native[2].owner == other and native[2].source == "blizzard" and not native[2].member.online,
    "native result resolves actual guild member and roster online status")
check(not module.db.global.crafting[other], "native responses remain transient rather than claiming permanent recipe knowledge")
module:CancelCraftingQuery(); module:QueryCrafting(row); timers[#timers]()
check(not module.craftingPending and module.craftingStatus:find("unknown", 1, true), "timeout reports unknown without retry")
module:QueryCrafting(row); queryCount = 0; module:OnCraftingQuery()
check(#module.craftingResults.rows == 0 and module.craftingStatus:find("unavailable", 1, true), "empty native result does not claim nobody knows recipe")
module:QueryCrafting(row); combat = true; module:OnCraftingQuery()
check(module.craftingPending ~= nil, "no native result getters consumed during combat")
module:OnEvent("PLAYER_REGEN_DISABLED"); check(not module.craftingPending and not module.craftingResults, "combat cancels transient native query")
combat = false
roster[1][17] = "Replacement"; module:ReadRoster()
check(#module:GetCraftingRows("", false) == 0, "same-name different-GUID character cannot inherit recipe snapshot")
roster[1][17] = "Player-Self"; module:ReadRoster()
check(module.db.global.characters[own].nickname == "Junnez", "crafting operations preserve nickname database")
ids = { [1] = 1, [3] = 3 }
check(not module:ScanOwnCrafting(), "sparse recipe ID cache cannot overwrite snapshot")
ids = { 1, 2, 3 }
recipes[1].learned = secret
check(not module:ScanOwnCrafting(), "secret learned flag cannot become knowledge")
recipes[1].learned = true
local baseInfo = C_TradeSkillUI.GetBaseProfessionInfo
local calls = 0
C_TradeSkillUI.GetBaseProfessionInfo = function()
    calls = calls+1
    return calls == 1 and profession or { professionID = 164, professionName = "Blacksmithing" }
end
check(not module:ScanOwnCrafting(), "profession change during scan rejects atomic commit")
C_TradeSkillUI.GetBaseProfessionInfo = baseInfo
local many = {}; for index = 1, 3001 do many[index] = { name = "Bounded Recipe" } end
input.recipes = many
check(not module:ValidateCrafting(input), "per-profession recipe limit rejects oversized schema")
input.recipes = { [1] = { name = "Changed Name" }, [4] = { name = "New Recipe" } }
input.owner, input.guid = own, "Player-Self"
local difference = assert(module:PreviewCraftingImport(Encode(input)))
check(difference.added == 1 and difference.changed == 1 and difference.removed == 1, "review reports added, changed and removed recipe records")
check(not module:StoreCrafting(input, "verified-by-peer"), "unrecognized provenance cannot be stored")
print(string.format("Guild crafting: %d checks passed", checks))
