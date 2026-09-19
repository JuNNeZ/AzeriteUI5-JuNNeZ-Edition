local Addon, ns = ...

-- Forever (Camelot) shares Mainline's UI engine, but not Retail's content or
-- interface-number sequence. Prefer the selected TOC's explicit client marker.
local interface = select(4, GetBuildInfo())
local metadata = C_AddOns and C_AddOns.GetAddOnMetadata or GetAddOnMetadata
local mainline = WOW_PROJECT_MAINLINE ~= nil and WOW_PROJECT_ID == WOW_PROJECT_MAINLINE
local forever = (metadata and metadata(Addon, "X-AzeriteUI-Client") == "Forever")
	 or (mainline and interface >= 16000 and interface < 17000)

ns.Private.IsForever = forever and true or false
ns.Private.IsMainline = (mainline or forever) and true or false
ns.Private.IsRetailContent = mainline and not forever
-- Historical IsRetail/WoW10/WoW11 uses select modern frames, aura widgets and
-- bootstrap code. Keep their engine meaning; use IsRetailContent for gameplay.
ns.Private.IsRetail = ns.Private.IsMainline
ns.Private.WoW10 = ns.Private.IsMainline
ns.Private.WoW11 = ns.Private.IsMainline
ns.Private.HasSecretValues = type(issecretvalue) == "function"

-- Feature-level event probes, without registering an unavailable event first.
local API = ns.API or {}
ns.API = API
API.IsEventAvailable = function(event)
	return not (C_EventUtils and C_EventUtils.IsEventValid)
		or C_EventUtils.IsEventValid(event)
end
