-- Offline protocol/privacy checks. All transport calls are captured stubs.
local root = arg[1] or "."
dofile(root .. "/Libs/LibStub/LibStub.lua")
dofile(root .. "/Libs/AceSerializer-3.0/AceSerializer-3.0.lua")
local serializer = LibStub("AceSerializer-3.0")
local checks, clock, combat, inGuild, guild = 0, 1, false, true, "Test Guild"
local writes, timers, secret = {}, {}, {}
local function check(value, label) checks = checks+1; assert(value, label) end
issecretvalue = function(value) return value == secret end
GetNormalizedRealmName = function() return "TestRealm" end
GetTime = function() return clock end
GetGuildInfo = function() return guild end
IsInGuild = function() return inGuild end
InCombatLockdown = function() return combat end
UnitGUID = function() return "Player-Self" end
local roster = {}
for index, name in ipairs({ "Self", "Partner Person", "Alt Person" }) do
    local row = { name .. "-TestRealm", "Member", 2, 40, "Mage", "City", "Public", "OFFICER SECRET", true }
    row[17] = index == 1 and "Player-Self" or "Player-" .. index
    roster[index] = row
end
GetNumGuildMembers = function() return #roster end
GetGuildRosterInfo = function(index) return unpack(roster[index], 1, 17) end
C_Timer = { After = function(delay, callback) timers[#timers+1] = { delay = delay, callback = callback } end }
local registerResult = 0
Enum = { RegisterAddonMessagePrefixResult = { Success = 0, DuplicatePrefix = 1 } }
C_ChatInfo = { RegisterAddonMessagePrefix = function() return registerResult end, SendAddonMessage = function() error("use CTL") end }
ChatThrottleLib = { SendAddonMessage = function(_, priority, prefix, message, channel, target, queue, callback)
    check(priority == "BULK" and #message <= 255 and channel == "WHISPER", "bounded throttled whisper only")
    writes[#writes+1] = { prefix = prefix, message = message, target = target, callback = callback }
end }
local module = { DisableSettingsExport = function() end, RegisterEvent = function(self, event) self.registered = event end }
local ns = { NewModule = function() return module end, GetModule = function() return module end,
    db = { RegisterNamespace = function(_, _, defaults) return { profile = defaults.profile, global = defaults.global, RegisterCallback = function() end } end } }
for _, file in ipairs({ "GuildManager", "GuildManagerData", "GuildManagerSharing" }) do
    assert(loadfile(root .. "/Components/Misc/" .. file .. ".lua"))("Test", ns)
end
module:OnInitialize()
local shown, partner = true, "Partner Person-TestRealm"
module.sharingWindow = { IsShown = function() return shown end, partner = { GetText = function() return partner end } }
registerResult = 2; module:InitializeSharing()
check(not module.sharingRegistered, "prefix registration failure disables sharing")
registerResult = 0; module:InitializeSharing()
check(module.sharingRegistered and module.registered == "CHAT_MSG_ADDON", "native prefix and event registered")
check(not module:GetSharingContext("Self") and not module:GetSharingContext("Stranger"), "self and non-guild target rejected")
roster[2][9] = false
check(not module:GetSharingContext(partner), "offline partner rejected")
roster[2][9] = true
local context = assert(module:GetSharingContext(partner))
local key, alt = module:CharacterKey(partner), module:CharacterKey("Alt Person")
module:SaveIdentity(partner, "Local", "")
module:SaveIdentity("Alt Person", "", partner)
module.db.global.characters[key].privateNote = "PRIVATE SECRET"
module.db.global.characters[key].favorite = true
module:SaveIdentity("Outside", "NON GUILD SECRET", "")
local text, count = module:ExportGuildSharing(context)
check(text and count == 2 and not text:find("SECRET", 1, true) and not text:find("favorite", 1, true), "only public guild identities exported")
local public = assert(module:DecodeIdentityBackup(text))
check(public[alt].main == key and public[key].nickname == "Local", "main/alt graph retained")
module.db.global.characters[alt].main = module:CharacterKey("Outside")
text, count = module:ExportGuildSharing(context)
check(count == 1, "external-main chain excluded")
module.db.global.characters[alt].main = key
local function Encode(records)
    return "AZGUILD:1:" .. serializer:Serialize({ format = "AzGuild", version = 1, characters = records })
end
local records = { [key] = { name = key, nickname = "Incoming" }, [alt] = { name = alt, main = key } }
local incoming = { context = context, text = Encode(records) }
local preview = assert(module:PreviewGuildSharing(incoming))
check(preview.count == 2 and preview.conflicts == 1 and preview.records[key].privateNote == "PRIVATE SECRET"
    and preview.records[key].favorite, "preview counts public conflicts and preserves local metadata")
records[key].favorite = false; incoming.text = Encode(records)
check(not module:PreviewGuildSharing(incoming), "network favorites rejected even when false")
records[key].favorite = nil; records[key].privateNote = "Injected"; incoming.text = Encode(records)
check(not module:PreviewGuildSharing(incoming), "network private notes rejected")
records[key].privateNote = nil; records[alt].main = module:CharacterKey("Outside"); incoming.text = Encode(records)
check(not module:PreviewGuildSharing(incoming), "incoming external link rejected")
records[alt].main = key; incoming.text = Encode(records)
module.sharingIncoming = incoming
check(not module:ImportGuildSharing(incoming, preview.revision+1), "stale identity revision rejects import")
check(module:ImportGuildSharing(incoming, preview.revision), "explicit import succeeds")
check(module:Resolve(partner) == "Incoming" and module.db.global.characters[key].privateNote == "PRIVATE SECRET", "import replaces public identity only")
check(not module:ImportGuildSharing(incoming, module.identityRevision), "import single use")
check(module:UndoIdentity() and module:Resolve(partner) == "Local", "shared import participates in Undo")
local function Receive(message, sender, channel, prefix)
    module:OnGuildShareMessage("CHAT_MSG_ADDON", prefix or "AZGuildShare1", message, channel or "WHISPER", sender or partner)
end
Receive("R:1-1", "Stranger-TestRealm")
check(not module.sharingRequest, "unsolicited non-partner request ignored")
shown = false; Receive("R:1-1")
check(not module.sharingRequest, "closed window never accepts requests")
shown = true; Receive("R:1-1", nil, "GUILD")
check(not module.sharingRequest, "guild broadcast ignored")
Receive("R:1-1", nil, nil, secret)
check(not module.sharingRequest, "secret event payload ignored")
Receive("R:1-1")
check(module.sharingRequest ~= nil and #writes == 0, "request never automatically sends identities")
check(module:SendGuildSharing(), "sender explicitly starts transfer")
local sent = writes[#writes]
check(sent.message:match("^D:1%-1:1:") and not sent.message:find("SECRET", 1, true), "outgoing packet belongs to selected request")
module:CancelSharing(); sent.callback(nil, true)
check(not module.sharingSend, "canceled queued callback cannot resume sending")
check(module:RequestGuildSharing(partner), "receiver explicitly arms transfer")
local state = module.sharingReceive
local transfer = Encode(records)
local total = math.ceil(#transfer/200)
local function Packet(index, token, max)
    return "D:" .. (token or state.token) .. ":" .. index .. ":" .. (max or total) .. ":" .. transfer:sub((index-1)*200+1,index*200)
end
Receive(Packet(1, "wrong")); Receive("D:" .. state.token .. ":1:321:x")
check(state.received == 0, "wrong token and excessive total rejected")
Receive(Packet(1), "Alt Person-TestRealm")
check(state.received == 0, "another guild member cannot fill selected partner's buffer")
local before = module.identityRevision
for index = total, 1, -1 do Receive(Packet(index)); Receive(Packet(index)) end
check(module.sharingIncoming and not module.sharingReceive and module.identityRevision == before, "out-of-order duplicate packets assemble once without importing")
check(module:PreviewGuildSharing(module.sharingIncoming) ~= nil, "assembled packet validates with real serializer")
local old = module.sharingIncoming
clock = clock+301
check(not module:PreviewGuildSharing(old), "expired incoming preview cannot import")
module:CancelSharing(); clock = 1
module:RequestGuildSharing(partner); state = module.sharingReceive
roster[2][17] = "Player-Replacement"
Receive(Packet(1))
check(state.received == 0, "replaced partner GUID rejects packets")
roster[2][17] = "Player-2"
guild = "Other Guild"; Receive(Packet(1))
check(state.received == 0, "guild change rejects packets")
guild = "Test Guild"; combat = true
Receive(Packet(1)); check(state.received == 0 and not module:RequestGuildSharing(partner), "combat refuses send and receive")
combat = false; module:CancelSharing(); module:RequestGuildSharing(partner)
state = module.sharingReceive; local previousProfile = module.db.profile; module.db.profile = { enabled = true }
Receive(Packet(1)); check(state.received == 0, "profile change invalidates transfer context")
module.db.profile = previousProfile
module:CancelSharing(); module:RequestGuildSharing(partner)
state = module.sharingReceive; local latestTimer = timers[#timers]
latestTimer.callback(); check(not module.sharingReceive and module.sharingStatus:find("expired", 1, true), "timeout clears bounded buffer without retry")
module:CancelSharing(); Receive("R:3-1")
local first = #writes+1
check(module:SendGuildSharing(), "explicit retry can send a complete transfer")
local packets = {}
while module.sharingSend do
    local packet = writes[#writes]
    local payload = packet.message:match("^D:[%d%-]+:%d+:%d+:(.*)$")
    packets[#packets+1] = assert(payload)
    packet.callback(nil, true)
    check(timers[#timers].delay == .05, "only one next packet is scheduled after successful send")
    timers[#timers].callback()
end
check(#packets > 1 and #writes-first+1 == #packets and module:DecodeIdentityBackup(table.concat(packets)), "complete bounded sender stream round trips through real deserializer")
Receive("R:4-1"); check(module:SendGuildSharing(), "new transfer requires another request")
local number = #writes
writes[number].callback(nil, false)
check(not module.sharingSend and #writes == number, "native send failure stops without retry")
Receive("R:5-1"); module:SendGuildSharing()
number = #writes; writes[number].callback(nil, true)
combat = true; timers[#timers].callback()
check(not module.sharingSend and #writes == number, "combat between packets stops remaining send")
combat = false; module:OnEvent("PLAYER_REGEN_ENABLED")
check(#writes == number, "leaving combat never restarts transfer")
records[key].main = alt
incoming = { context = assert(module:GetSharingContext(partner)), text = Encode(records) }
check(not module:PreviewGuildSharing(incoming), "cyclic incoming graph rejected")
records[key].main = nil
module:CancelSharing(); module:RequestGuildSharing(partner)
local waiting = module.sharingReceive
module:OnEvent("PLAYER_REGEN_DISABLED")
check(not module.sharingReceive, "combat event discards receive buffer immediately")
check(waiting.parts and not next(waiting.parts), "canceled receive did not collect unsolicited data")
print(string.format("guild_sharing_harness: %d checks passed", checks))
