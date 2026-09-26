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

-- Restricted execution, i.e. whether secure handler snippets compile and run.
--
-- Both clients build restricted closures in Lua, in
-- Blizzard_RestrictedAddOnEnvironment. `mainline` is a game-type *family* covering
-- both Retail's `standard` and Forever's `camelot` - Blizzard_Minimap.toc proves it
-- by writing `[AllowLoadGameType mainline] [ExcludeLoadGameType camelot]` - so the
-- difference between the two clients is not which files load, but in which order.
--
-- Retail: Blizzard_EnvironmentCleanup_Mainline.toc carries
-- `## OptionalDeps: Blizzard_RestrictedAddOnEnvironment`, which orders the cleanup
-- pass after it. RestrictedExecution.lua captures `loadstring_untainted` first, and
-- cleanup nils the global afterwards, harmlessly.
--
-- Forever: the two TOCs were merged and the optional dependency became
-- `## Dep: Blizzard_RestrictedAddOnEnvironment [AllowLoadGameType classic, standard]`,
-- which `camelot` does not match, even though the restricted environment itself was
-- given `AllowLoadGameType: classic, standard, camelot`. Nothing orders the two, and
-- cleanup has `LoadFirst: 1`, so it wins: `loadstring_untainted` is nil'd before
-- RestrictedExecution.lua:22 captures it, and every snippet body then dies at
-- RestrictedExecution.lua:79 with "attempt to call a nil value". No addon can repair
-- that; the capture happens before any addon loads.
--
-- The global is therefore nil on both clients by the time this runs, and cannot be
-- tested. On Forever, running a snippet always reports the same Blizzard error before
-- the addon can recover, so select the fallback from the client marker instead.

-- Feature-level event probes, without registering an unavailable event first.
local API = ns.API or {}
ns.API = API
API.IsEventAvailable = function(event)
	return not (C_EventUtils and C_EventUtils.IsEventValid)
		or C_EventUtils.IsEventValid(event)
end

-- Assigned up front, and deliberately last in the file, because an abort here must
-- never take the rest of this file with it. An earlier version ran the probe above
-- this point, threw, and left both `HasSecureSnippets` and `IsEventAvailable`
-- undefined - which silently switched every fallback back off and broke three action
-- bar modules later in the session.
ns.Private.HasSecureSnippets = true

local ProbeSecureSnippets = function()
	local isAddOnLoaded = (C_AddOns and C_AddOns.IsAddOnLoaded) or IsAddOnLoaded
	if (type(isAddOnLoaded) ~= "function") then return true end

		-- The guard is for a client that keeps restricted execution in the binary,
		-- where there is nothing to test and the snippet path is by definition available.
	if (not isAddOnLoaded("Blizzard_RestrictedAddOnEnvironment")) then return true end

	local probe = CreateFrame("Frame", nil, nil, "SecureHandlerStateTemplate")
	probe:Hide()

	local ran = false
	probe.AzeriteUI_SecureSnippetProbe = function() ran = true end
	probe:SetAttribute("_onstate-azsnippetprobe", [[ self:CallMethod("AzeriteUI_SecureSnippetProbe") ]])

	-- Measured on Forever 1.60.1.69913. `pcall` stops the error propagating, so this
	-- function returns and the rest of the file runs - but it does **not** keep the
	-- error out of BugSack. WoW's C dispatcher hands a script-handler error to the
	-- error handler first and unwinds afterwards, and BugGrabber replaces
	-- `seterrorhandler` with a guard so a third-party swap is ignored in both
	-- directions. One BugSack entry per probe is therefore unavoidable; the cache
	-- below is what keeps it from being one per login.
	pcall(probe.SetAttribute, probe, "state-azsnippetprobe", "run")

	return ran
end

-- Probe answers are remembered per client build. Forever builds before 70009 are
-- deliberately not probed: their load order is known broken, and the probe would only
-- put Blizzard's error in BugSack. Forever 1.60.1.70009 fixed it - its
-- Blizzard_EnvironmentCleanup.toc now carries a plain
-- `## OptionalDep: Blizzard_RestrictedAddOnEnvironment`, the ordering Retail has always
-- had - so from that build on Forever is probed and cached exactly like Retail.
--
-- Read raw, because AceDB has not been built yet at this point in the load.
-- Core/FixBlizzardBugs.lua writes the result back at PLAYER_LOGIN.
local FOREVER_FIRST_FIXED_BUILD = 70009
local currentBuild = tostring(select(2, GetBuildInfo()))
local cached = type(AzeriteUI5_DB) == "table"
	and type(AzeriteUI5_DB.global) == "table"
	and AzeriteUI5_DB.global.secureSnippets
local knownBrokenForever = forever and (tonumber(currentBuild) or 0) < FOREVER_FIRST_FIXED_BUILD

if (knownBrokenForever) then
	ns.Private.HasSecureSnippets = false
	ns.Private.SecureSnippetsKnownUnavailable = true
	ns.Private.SecureSnippetsFromCache = false
elseif (type(cached) == "table" and cached.build == currentBuild and type(cached.available) == "boolean") then
	ns.Private.HasSecureSnippets = cached.available
	ns.Private.SecureSnippetsFromCache = true
else
	ns.Private.HasSecureSnippets = ProbeSecureSnippets() and true or false
	ns.Private.SecureSnippetsFromCache = false
end

-- Handed to FixBlizzardBugs to persist, and to /azdebug secure to report.
ns.Private.SecureSnippetsBuild = currentBuild
