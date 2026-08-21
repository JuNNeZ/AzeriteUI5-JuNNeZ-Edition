--[[

	The MIT License (MIT)

	Copyright (c) 2026 Lars Norberg

	Permission is hereby granted, free of charge, to any person obtaining a copy
	of this software and associated documentation files (the "Software"), to deal
	in the Software without restriction, including without limitation the rights
	to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
	copies of the Software, and to permit persons to whom the Software is
	furnished to do so, subject to the following conditions:

	The above copyright notice and this permission notice shall be included in all
	copies or substantial portions of the Software.

	THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
	IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
	FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
	AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
	LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
	OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
	SOFTWARE.

--]]
--[[

	Loud failure reporting for guarded calls.

	Policy: a pcall exists ONLY where the protected call can genuinely throw
	(secret-value operands, protected frames in combat, cross-version API shape
	probing). Everywhere such a guard is required, a failure must still be
	*visible* -- it is routed to the standard error handler so BugSack /
	BugGrabber / Blizzard's error frame picks it up with a traceback.

	Nothing in this addon should swallow an error silently. If you find yourself
	wanting a bare pcall with a discarded result, use API.SafeCall instead.

--]]
local _, ns = ...
local API = ns.API or {}
ns.API = API

local type = type
local pairs = pairs
local tostring = tostring
local string_format = string.format

-- Report the first few occurrences of a given failure site immediately, then
-- throttle to one report per interval carrying an occurrence count. Unbounded
-- reporting from a per-frame update path would drown the very signal we want.
local BURST_LIMIT = 3
local REPEAT_INTERVAL = 60

local sites = {}

local Now = function()
	return (GetTimePreciseSec and GetTimePreciseSec()) or GetTime() or 0
end

local Describe = function(err)
	if (issecretvalue and issecretvalue(err)) then
		return "<secret error value>"
	end
	if (type(err) == "string") then
		return err
	end
	return tostring(err)
end

--[[
	Report a guarded-call failure through the standard error handler.

	context : short stable string identifying the call site, eg "Health.SetValue"
	err     : the error value produced by the failed call
]]
API.ReportError = function(context, err)
	local key = (type(context) == "string" and context ~= "") and context or "unknown"

	local site = sites[key]
	if (not site) then
		site = { count = 0, reported = 0, lastReport = 0 }
		sites[key] = site
	end
	site.count = site.count + 1

	local now = Now()
	local shouldReport = false
	if (site.reported < BURST_LIMIT) then
		shouldReport = true
	elseif ((now - site.lastReport) >= REPEAT_INTERVAL) then
		shouldReport = true
	end

	if (not shouldReport) then
		return
	end

	site.reported = site.reported + 1
	site.lastReport = now

	local message
	if (site.count > 1) then
		message = string_format("AzeriteUI: guarded call failed at '%s' (occurrence %d): %s",
			key, site.count, Describe(err))
	else
		message = string_format("AzeriteUI: guarded call failed at '%s': %s",
			key, Describe(err))
	end

	local handler = geterrorhandler and geterrorhandler()
	if (handler) then
		handler(message)
		return
	end

	local chatFrame = DEFAULT_CHAT_FRAME
	if (chatFrame and chatFrame.AddMessage) then
		chatFrame:AddMessage(message)
	end
end

--[[
	Protected call that reports instead of swallowing.

	Returns success as the first value, followed by the call's results:
		local ok, a, b = API.SafeCall("Health.GetValue", frame.GetValue, frame)

	Success is returned explicitly rather than inferred from the results, so
	void functions and functions that legitimately return nil are unambiguous.

	Use ONLY where the call can genuinely throw -- secret-value operands,
	protected frames in combat, or cross-version API shape differences. If the
	call cannot throw, call it directly and let a real error surface with its
	own traceback.
]]
API.SafeCall = function(context, func, ...)
	if (type(func) ~= "function") then
		API.ReportError(context, "attempted to call a non-function value")
		return false
	end
	local ok, a, b, c, d, e, f, g, h = pcall(func, ...)
	if (ok) then
		return true, a, b, c, d, e, f, g, h
	end
	API.ReportError(context, a)
	return false
end

--[[
	As SafeCall, but returns all results packed in a table on success. Use where
	the guarded call returns more values than SafeCall carries.
]]
API.SafeCallPacked = function(context, func, ...)
	if (type(func) ~= "function") then
		API.ReportError(context, "attempted to call a non-function value")
		return false, nil
	end
	local results = { pcall(func, ...) }
	if (results[1]) then
		return true, results
	end
	API.ReportError(context, results[2])
	return false, nil
end

--[[
	Silent protected call. Returns success first, then the call's results.

	This is the ONLY sanctioned way to swallow an error, and it exists for one
	narrow case: deliberately probing several API signatures where a failure is
	an expected, handled branch rather than a fault. The caller must do
	something meaningful with the failure -- if the fallback is "give up
	quietly", use SafeCall so the failure is visible instead.
]]
API.TryCall = function(func, ...)
	if (type(func) ~= "function") then
		return false
	end
	return pcall(func, ...)
end

-- Diagnostic accessor: returns the recorded failure sites and their counts.
API.GetGuardedCallFailures = function()
	local out = {}
	for key, site in pairs(sites) do
		out[key] = site.count
	end
	return out
end
