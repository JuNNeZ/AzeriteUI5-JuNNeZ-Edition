--[[

	The MIT License (MIT)

	Copyright (c) 2026 Jonas "JuNNeZ" Andersen

--]]
-- Turning an AceConfig option table into rows.
--
-- Config.lua reads the table, Controls.lua draws the widgets, and this is what
-- joins them: it walks a page in draw order, builds a control for each option,
-- binds the control's value to the option's get and set, and stacks the results
-- down a scrolling column.
--
-- One level of nesting is flattened deliberately. AceConfigDialog would render a
-- page's sub-groups as a row of tabs; the roadmap artifact instead runs them down
-- one page as titled sections, which is why `childGroups = "tab"` is ignored here
-- and a sub-group becomes a heading followed by its rows. The real table is only
-- two deep, so one level covers all of it.
local Addon, ns = ...

local Kit = ns.OptionsKit
local Config = Kit.Config
local Controls = Kit.Controls
if (not Config or not Controls) then return end

-- Lua API
local ipairs, pairs = ipairs, pairs
local table_sort = table.sort
local max = math.max
local pcall = pcall
local string_format = string.format
local string_match = string.match
local tonumber, tostring, type = tonumber, tostring, type

local L = LibStub("AceLocale-3.0"):GetLocale(Addon)

local Renderer = {}
Kit.Renderer = Renderer

local APP = Addon

--------------------------------------------------------------------------
-- Helpers
--------------------------------------------------------------------------
local Copy = function(path)
	local out = {}
	for i = 1, #path do out[i] = path[i] end
	return out
end

local AsString = function(value, fallback)
	if (type(value) == "string") then return value end
	if (type(value) == "number") then return tostring(value) end
	return fallback
end

-- An option is inline when it asks to be drawn in place rather than as a page
-- of its own. We flatten those the same way we flatten everything else.
local IsInline = function(option)
	return (option.dialogInline or option.guiInline or option.inline) and true or false
end

-- Whether this option's choices read better as a strip of buttons than as a
-- dropdown. Controls owns the rule; the renderer only has to ask.
local WantsStrip = function(option, options, path)
	local values = Config.GetValues(option, options, path, APP)
	return Controls.WantsSegmented(values), values
end

--------------------------------------------------------------------------
-- Binding
--------------------------------------------------------------------------
-- Everything a control needs in order to speak for one option.
--
-- `SetValue` on a control is deliberately silent unless a person moved it, so
-- writing a value in here can never turn round and write it back out again.
-- A gem on anything that differs from its default, and one click to put that
-- one setting back. `IsModified` answers nil when the default is unknown,
-- which must not be read as "unchanged": no binding means no gem.
local MarkModified = function(control, options, path, current)
	local Defaults = Kit.Defaults
	if (not Defaults) then return end

	local modified = Defaults.IsModified(options, path, current)
	if (modified == nil) then
		control:SetOnRevert(nil)
		control:SetModified(false)
		return
	end

	control:SetModified(modified)
end

-- The same, for one key of a multiselect: the default is the key's own entry
-- in the setting's default table, and an absent table means no gem rather than
-- a guess.
local MarkMultiModified = function(control, options, path, multi, current)
	local Defaults = Kit.Defaults
	local default = Defaults and Defaults.Get(options, path)

	if (type(default) ~= "table") then
		control:SetOnRevert(nil)
		control:SetModified(false)
		return
	end

	control:SetModified((default[multi] and true or false) ~= (current and true or false))
end

-- A change is previewed before the page rebuilds and releases the control that
-- made it. Unbound settings (profiles and the panel's own appearance) simply
-- return false from Preview.Request and leave no trace.
local PreviewChange = function(options, path, label)
	local Preview = Kit.Preview
	if (Preview) then Preview:Request(options, path, label) end
end

-- Tells whoever owns the page which setting just changed, so counts kept
-- elsewhere (the rail's gems, the header's tally) can be brought up to date
-- for that setting's own page. The path is the setting's real one, which is
-- what lets a view gathered from several pages report it correctly.
local NotifyChanged = function(page, path)
	if (type(page.OnChanged) == "function") then
		pcall(page.OnChanged, page, path)
	end
end

--------------------------------------------------------------------------
-- Writing
--------------------------------------------------------------------------
-- One write, held until combat ends when it has to be. Kit.Combat owns the
-- rule and the queue; the renderer only asks, and reads back what is waiting so
-- a control can go on showing the value that was chosen.
--
-- `value` is what the control should show until the write happens. An execute
-- action has none, which is what `hasValue` distinguishes from a pending false.
local Write = function(options, path, label, value, hasValue, apply, extra)
	local Combat = Kit.Combat
	if (Combat and Combat:ShouldQueue(options)) then
		return Combat:Queue(path, label, value, hasValue, apply, extra)
	end

	apply()
	return false
end

-- The change waiting on this setting, if any.
local Held = function(path, extra)
	local Combat = Kit.Combat
	return (Combat and Combat:Peek(path, extra)) or nil
end

--------------------------------------------------------------------------
-- Refusing, and asking first
--------------------------------------------------------------------------
-- An option table can carry `validate` and `confirm`, and until Phase 11 this
-- panel read neither. `Config` has resolved both since Phase 1; nothing called
-- them. That is not cosmetic on the two pages most certain to be visited:
-- Delete Profile deleted, Reset reset, and Import overwrote the active profile,
-- each on a single click with nothing asked.
--
-- Both follow `AceConfigDialog-3.0.lua:700-830` rather than an idea of what
-- they ought to mean. In particular a *string* `confirm` or `validate` is the
-- name of a method on the option's handler, not the text to show; the text
-- comes from what that method returns. Config resolves that part already.
--
-- Ace3's own wording for a refusal that gave no reason: the setting's name,
-- then what it wanted.
local Reason = function(option, label)
	label = label or ""

	if (type(option.usage) == "string") then
		return label .. ": " .. option.usage
	end
	if (type(option.pattern) == "string") then
		return string_format(L["%s: expected %s"], label, option.pattern)
	end
	return string_format(L["%s: invalid value"], label)
end

-- Nothing, or the reason this value cannot be used. An execute never reaches
-- here: Ace3 does not validate one, because there is no value to validate.
local Refusal = function(option, options, path, label, value)
	if (option.type == "input" and type(option.pattern) == "string") then
		if (type(value) ~= "string" or not string_match(value, option.pattern)) then
			return Reason(option, label)
		end
	end

	if (option.validate == nil) then return end

	local ok, result = pcall(Config.Validate, option, options, path, APP, value)

	-- A validate that could not be resolved is a refusal, not a pass. Ace3
	-- errors outright here; throwing out of a click in this window would be
	-- worse than refusing the value and saying so on the row.
	if (not ok) then return Reason(option, label) end

	if (type(result) == "string") then return result end
	if (not result) then return Reason(option, label) end
end

-- The question to ask before a change, or nothing.
local Question = function(option, options, path, label, value)
	if (option.confirm == nil) then return end

	local ok, result = pcall(Config.GetConfirm, option, options, path, APP, value)

	-- Same direction as above, for the same reason: not being able to work out
	-- whether to ask is not permission to go ahead without asking.
	if (not ok) then
		return string_format(L["Are you sure you want to change %s?"], label or "")
	end

	if (type(result) == "string") then return result end
	if (not result) then return end

	-- `confirm = true` carries no words, so Ace3 builds them from the setting's
	-- own name and description, unless the option spells them out.
	if (type(option.confirmText) == "string") then return option.confirmText end

	local desc = Config.GetDesc(option, options, path, APP)
	if (type(desc) == "string" and desc ~= "") then
		return (label or "") .. " - " .. desc
	end
	return string_format(L["Are you sure you want to change %s?"], label or "")
end

-- Putting one setting back is a write like any other, so in combat it waits
-- like any other. What is held is the default value, so the row shows what it
-- is going back to rather than the value still sitting in the profile.
local RevertOne = function(options, path, label, page, multi)
	local Defaults = Kit.Defaults
	if (not Defaults) then return end

	local default = Defaults.Get(options, path)

	-- One key of a multiselect goes back to its own key's default, inside the
	-- setting's default table, not to the whole table.
	if (multi ~= nil) then
		if (type(default) ~= "table") then return end

		local want = default[multi] and true or false
		local group = Config.GetGroup(options, path)
		if (type(group) ~= "table") then return end

		local Apply = function() Config.SetValue(group, options, path, APP, multi, want) end

		local Combat = Kit.Combat
		if (Combat and Combat:ShouldQueue(options)) then
			Combat:Queue(path, label, want, true, Apply, multi)
		else
			Apply()
		end

		PreviewChange(options, path, label)
		NotifyChanged(page, path)
		page:Refresh()
		return
	end

	local Combat = Kit.Combat
	if (Combat and Combat:ShouldQueue(options)) then
		if (default == nil) then return end

		Combat:Queue(path, label, default, true, function()
			Defaults.Revert(options, path)
		end)

	elseif (not Defaults.Revert(options, path)) then
		return
	end

	PreviewChange(options, path, label)
	NotifyChanged(page, path)
	page:Refresh()
end

-- One change, from a control somebody has just used. Everything that writes a
-- setting goes through here, in this order:
--
--   refuse it          - `validate` said no, so the row says why and nothing is
--                        written, not even queued
--   ask first          - `confirm` said so, and the answer decides
--   write or hold it   - Kit.Combat decides which
--   preview and report - the glow, the gems, the counts, the page
--
-- Asking is not synchronous: the popup answers later, which is why the write
-- lives in the callback and a cancel refreshes the page. A control has already
-- drawn the value you clicked by the time the question appears, and the refresh
-- is what puts it back.
local Commit = function(control, option, options, path, label, page, value, hasValue, apply, preview, extra)
	if (hasValue) then
		local refusal = Refusal(option, options, path, label, value)
		if (refusal) then
			control:SetError(refusal)
			page:Layout()
			return false
		end
	end
	control:SetError(nil)

	local Finish = function()
		Write(options, path, label, value, hasValue, apply, extra)
		if (preview) then PreviewChange(options, path, label) end
		NotifyChanged(page, path)
		page:Refresh()
	end

	local question = Question(option, options, path, label, value)
	if (question) then
		Kit.Confirm(question, Finish, function() page:Refresh() end)
		return false
	end

	Finish()
	return true
end

-- `entry` is the row this control is being bound for, which for a multiselect
-- is one of several sharing an option and a path. Its own value key travels as
-- `multi`: an extra argument to get and set, part of the queue's key, and the
-- label the row is drawn with.
local Bind = function(control, option, options, path, page, entry)
	local bound = Copy(path)
	local multi = entry and entry.multi

	local label = (entry and entry.label)
		or AsString(Config.GetName(option, options, path, APP), "")

	control:SetLabel(label)

	-- The artifact puts the description under the label as a plain line rather
	-- than inside a tooltip nobody hovers to find.
	local desc = Config.GetDesc(option, options, path, APP)
	control:SetHelp(AsString(desc, nil))

	local disabled = Config.IsDisabled(option, options, bound, APP)
	control:SetDisabled(disabled and true or false)

	-- The row's kind, not the option's: one multiselect is drawn as a run of
	-- toggles, and each of those rows is a toggle however the option describes
	-- itself.
	local kind = (entry and entry.kind) or option.type

	-- What this setting has waiting for combat to end, if anything. Read once:
	-- the control shows the held value, and the gem goes on reading the profile,
	-- because nothing has been written there yet.
	local held = Held(bound, multi)
	control:SetPending(held and true or false)

	if (kind == "execute") then
		control:SetText(AsString(Config.GetName(option, options, path, APP), ""))
		-- No preview: an action is not one setting and has no frame of its own.
		-- It is still reported, because an action held for combat has to reach
		-- the footer's count, and one that ran may have changed any number of
		-- settings on this page.
		control:SetCallback(function()
			Commit(control, option, options, bound, label, page, nil, false, function()
				Config.Execute(option, options, bound, APP)
			end, false)
		end)
		return
	end

	if (kind == "toggle") then
		local value = Config.GetValue(option, options, bound, APP, multi) and true or false

		if (multi ~= nil) then
			-- One key of a multiselect. Its default lives inside the setting's
			-- own default table, under the same key.
			MarkMultiModified(control, options, bound, multi, value)
		else
			MarkModified(control, options, bound, value)
		end

		if (held and held.hasValue) then value = held.value and true or false end
		control:SetValue(value)

		control:SetOnRevert(function(self)
			RevertOne(options, bound, label, page, multi)
		end)
		control:SetCallback(function(self, newValue)
			newValue = newValue and true or false
			Commit(control, option, options, bound, label, page, newValue, true, function()
				if (multi ~= nil) then
					Config.SetValue(option, options, bound, APP, multi, newValue)
				else
					Config.SetValue(option, options, bound, APP, newValue)
				end
			end, true, multi)
		end)
		return
	end

	if (kind == "range") then
		-- Coerced, because a bound is read straight off the table rather than
		-- through Config, and an option carrying something that is not a number
		-- should narrow the slider rather than blank the whole row.
		local lo = tonumber(option.softMin or option.min) or 0
		local hi = tonumber(option.softMax or option.max) or 100
		local step = tonumber(option.bigStep or option.step) or 0

		control:SetSliderValues(lo, hi, step)
		control:SetIsPercent(option.isPercent and true or false)

		-- Ours, not Ace3's, and only the panel's own settings table uses it: a
		-- setting that moves the slider while it is being dragged has to be
		-- written once, on release. See Controls.SetCommitOnRelease.
		if (control.SetCommitOnRelease) then
			control:SetCommitOnRelease(option.commitOnRelease and true or false)
		end

		local value = Config.GetValue(option, options, bound, APP)
		MarkModified(control, options, bound, value)

		if (held and held.hasValue) then value = held.value end
		control:SetValue(type(value) == "number" and value or lo)

		control:SetOnRevert(function(self)
			RevertOne(options, bound, label, page)
		end)

		control:SetCallback(function(self, newValue)
			Commit(control, option, options, bound, label, page, newValue, true, function()
				Config.SetValue(option, options, bound, APP, newValue)
			end, true)
		end)
		return
	end

	if (kind == "select") then
		local values = Config.GetValues(option, options, path, APP)
		local sorting = Config.GetMember("sorting", option, options, path, APP)

		control:SetList(type(values) == "table" and values or {}, sorting)

		local value = Config.GetValue(option, options, bound, APP)
		if (type(values) == "table" and values[value] == nil) then value = nil end
		MarkModified(control, options, bound, value)

		if (held and held.hasValue) then value = held.value end
		control:SetValue(value)

		control:SetOnRevert(function(self)
			RevertOne(options, bound, label, page)
		end)

		control:SetCallback(function(self, newValue)
			Commit(control, option, options, bound, label, page, newValue, true, function()
				Config.SetValue(option, options, bound, APP, newValue)
			end, true)
		end)
		return
	end

	if (kind == "color") then
		control:SetHasAlpha(option.hasAlpha and true or false)

		local r, g, b, a = Config.GetValue(option, options, bound, APP)
		MarkModified(control, options, bound, { r, g, b, a })

		if (held and held.hasValue and type(held.value) == "table") then
			r, g, b, a = held.value[1], held.value[2], held.value[3], held.value[4]
		end
		control:SetValue(r, g, b, a)

		control:SetOnRevert(function(self)
			RevertOne(options, bound, label, page)
		end)

		-- Four values in, one table held: the queue has to be able to show the
		-- colour again while it waits, and a colour is not one number.
		control:SetCallback(function(self, nr, ng, nb, na)
			Commit(control, option, options, bound, label, page, { nr, ng, nb, na }, true, function()
				Config.SetValue(option, options, bound, APP, nr, ng, nb, na)
			end, true)
		end)
		return
	end

	if (kind == "keybinding") then
		local value = Config.GetValue(option, options, bound, APP)
		MarkModified(control, options, bound, value)

		if (held and held.hasValue) then value = held.value end
		control:SetValue(type(value) == "string" and value or nil)

		control:SetOnRevert(function(self)
			RevertOne(options, bound, label, page)
		end)

		control:SetCallback(function(self, binding)
			Commit(control, option, options, bound, label, page, binding, true, function()
				Config.SetValue(option, options, bound, APP, binding)
			end, true)
		end)
		return
	end

	if (kind == "input") then
		if (control.multiline and control.SetNumLines) then
			control:SetNumLines(tonumber(option.multiline) or 4)
		end

		local text = Config.GetValue(option, options, bound, APP)
		if (held and held.hasValue) then text = held.value end
		control:SetValue(AsString(text, ""))

		control:SetCallback(function(self, newText)
			Commit(control, option, options, bound, label, page, newText, true, function()
				Config.SetValue(option, options, bound, APP, newText)
			end, true)
		end)
		return
	end
end

--------------------------------------------------------------------------
-- Rendering
--------------------------------------------------------------------------
-- Builds the flat list of things to draw for one page: descriptions and
-- headings as they come, sub-groups flattened into a heading plus their rows.
local Collect
Collect = function(group, options, path, out, depth)
	Config.ForEachChild(group, options, path, APP, function(key, option, childPath)
		local kind = option.type

		if (kind == "group") then
			-- Only one level is flattened. Anything deeper would run the page on
			-- forever, and the real table never goes there.
			if (depth == 0 or IsInline(option)) then
				-- A sub-group is a place you might want to jump to. The `header`
				-- entries inside one are punctuation within it, not destinations:
				-- Action Bars has twelve of the former and thirty-two of the two
				-- combined, and a rail listing all thirty-two helps nobody.
				out[#out + 1] = {
					kind = "header",
					major = true,
					label = AsString(Config.GetName(option, options, childPath, APP), key)
				}
				Collect(option, options, childPath, out, depth + 1)
			end
			return
		end

		if (kind == "header") then
			out[#out + 1] = {
				kind = "header",
				label = AsString(Config.GetName(option, options, childPath, APP), "")
			}
			return
		end

		if (kind == "description") then
			out[#out + 1] = {
				kind = "description",
				label = AsString(Config.GetName(option, options, childPath, APP), "")
			}
			return
		end

		-- A multiselect is not one control but a list of toggles over one
		-- `values` table, each reading and writing with its own key as an extra
		-- argument. Config.GetValue has passed extras through since Phase 1 for
		-- exactly this. The setting's own name becomes the heading above them,
		-- because otherwise the toggles arrive with nothing to say what they
		-- are a choice of.
		if (kind == "multiselect") then
			local values = Config.GetValues(option, options, childPath, APP)
			if (type(values) ~= "table") then return end

			local keys = {}
			for valueKey in pairs(values) do keys[#keys + 1] = valueKey end
			table_sort(keys, function(a, b)
				return tostring(values[a]) < tostring(values[b])
			end)

			local name = AsString(Config.GetName(option, options, childPath, APP), key)
			if (name ~= "") then
				out[#out + 1] = { kind = "header", label = name }
			end

			for _, valueKey in ipairs(keys) do
				out[#out + 1] = {
					kind = "toggle",
					option = option,
					path = Copy(childPath),
					multi = valueKey,
					label = AsString(values[valueKey], tostring(valueKey))
				}
			end
			return
		end

		if (kind == "toggle" or kind == "range" or kind == "select"
			or kind == "input" or kind == "execute"
			or kind == "color" or kind == "keybinding") then

			if (kind == "select" and option.style == "radio") then return end

			out[#out + 1] = {
				kind = kind,
				option = option,
				path = Copy(childPath)
			}
			return
		end

		-- A type with no control of ours - `color`, `keybinding`, `multiselect`.
		-- The real table has none of them today, which is exactly what makes
		-- this dangerous: add a colour picker to a page and it would simply not
		-- be there, with nothing to say so and nothing to error.
		--
		-- So it says so. A line on the page naming the setting and the type it
		-- wants is worth more than a silent gap, and it is how whoever adds the
		-- first one finds out they have to draw it.
		out[#out + 1] = {
			kind = "description",
			unsupported = kind,
			label = string_format(L["%s - this setting needs a %s control, which this panel cannot draw yet."],
				AsString(Config.GetName(option, options, childPath, APP), key), kind)
		}
	end)
end

Renderer.Collect = function(self, group, options, path)
	local out = {}
	-- A key with no group behind it (a view such as Quick Start) has no rows
	-- of its own to collect.
	if (type(group) ~= "table") then return out end
	Collect(group, options, path or {}, out, 0)
	return out
end

--------------------------------------------------------------------------
-- A page
--------------------------------------------------------------------------
-- Owns a scroll child, the controls inside it, and the job of refreshing them
-- when a value changes somewhere else in the table.
Renderer.CreatePage = function(self, content)
	local page = { content = content, controls = {}, pool = {} }

	-- Controls are kept and reused between pages rather than rebuilt, because a
	-- page of sixty rows is a lot of frames to make twice.
	local Acquire = function(kind, wantsStrip)
		-- Strips and dropdowns are both `select`, so they pool separately.
		local poolKey = kind
		if (kind == "select") then
			poolKey = wantsStrip and "segmented" or "select"
		elseif (kind == "input" and wantsStrip) then
			-- `wantsStrip` carries "this one is multiline" for an input.
			poolKey = "multiline"
		end
		local pool = page.pool[poolKey]
		if (not pool) then
			pool = {}
			page.pool[poolKey] = pool
		end

		local control = table.remove(pool)
		if (not control) then
			if (kind == "select") then
				control = wantsStrip and Controls.CreateSegmented(content)
					or Controls.CreateDropdown(content)
			elseif (kind == "input" and wantsStrip) then
				control = Controls.CreateMultiline(content)
			else
				control = Controls.Create(content, kind)
			end
		end
		return control
	end

	local Release = function(control)
		control.frame:Hide()
		control.major = nil
		control:SetCallback(nil)
		control:SetOnRevert(nil)
		control:SetModified(false)
		control:SetPending(false)

		local key = control.segmented and "segmented" or control.kind
		page.pool[key] = page.pool[key] or {}
		page.pool[key][#page.pool[key] + 1] = control
	end

	page.Clear = function(self)
		for i = #self.controls, 1, -1 do
			Release(self.controls[i])
			self.controls[i] = nil
		end
	end

	-- Where each section starts, so the rail can offer to jump to one. A page
	-- of a hundred and fifty settings is a long way to scroll blind.
	page.Layout = function(self)
		self.sections = self.sections or {}
		for i = #self.sections, 1, -1 do self.sections[i] = nil end

		-- Every control that wraps text is measured against this before it is
		-- placed. Without it a row is asked how tall it is while its own width
		-- is still unknown, and answers as though nothing wrapped.
		local width = content:GetWidth() or 0
		self.width = width

		-- What went where, so a page can be checked for rows drawn on top of one
		-- another the way the rail already is.
		self.layout = self.layout or {}
		for i = #self.layout, 1, -1 do self.layout[i] = nil end

		local offset = 0
		for i, control in ipairs(self.controls) do
			if (control.kind == "header" and control.major) then
				self.sections[#self.sections + 1] = {
					label = control.GetLabel and control:GetLabel() or control.label:GetText(),
					offset = offset
				}
			end

			if (control.Measure) then control:Measure(width) end
			local height = control:GetHeight()

			control.frame:ClearAllPoints()
			control.frame:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -offset)
			control.frame:SetPoint("TOPRIGHT", content, "TOPRIGHT", 0, -offset)
			control.frame:SetHeight(height)
			control.frame:Show()

			self.layout[#self.layout + 1] = {
				kind = control.kind,
				label = control.labelText,
				offset = offset,
				height = height,
				textHeight = control.textHeight or control.helpHeight
			}

			offset = offset + height
		end
		content:SetHeight(max(1, offset))
		return offset
	end

	-- Re-reads every visible control from the table. A setting that enables
	-- another one has to be able to grey it out the moment it changes.
	page.Refresh = function(self)
		if (self.collect) then
			self:ShowList(self.options, self.collect)
			return
		end
		if (not self.options or not self.path) then return end
		self:Show(self.options, self.path)
	end

	page.Show = function(self, options, path)
		self.options, self.path, self.collect = options, path, nil

		local group = Config.GetGroup(options, path)
		if (not group) then
			self:Clear()
			self:Layout()
			return 0
		end

		return self:Render(options, Renderer:Collect(group, options, path))
	end

	-- Draws rows gathered elsewhere, from settings that may sit on different
	-- pages. Each row carries its own real path, so binding works as it does on
	-- the setting's own page. `collect` is kept and asked again on every
	-- refresh, which is how a view that filters by value drops a row the moment
	-- it stops qualifying. A collector that fails says so on the page.
	page.ShowList = function(self, options, collect)
		self.options, self.path, self.collect = options, nil, collect

		local ok, entries = pcall(collect)
		if (not ok or type(entries) ~= "table") then
			entries = { { kind = "description", label = tostring(entries) } }
		end
		return self:Render(options, entries)
	end

	page.Render = function(self, options, entries)
		self:Clear()

		for i, entry in ipairs(entries) do
			local control

			if (entry.kind == "header") then
				control = Acquire("header")
				control:SetLabel(entry.label)
				control.major = entry.major and true or false

			elseif (entry.kind == "description") then
				control = Acquire("description")
				control:SetLabel(entry.label)

			else
				-- For a select this asks for a strip; for an input it asks for
				-- the multiline shape. Both are "the other kind of this type".
				local wantsStrip
				if (entry.kind == "select") then
					wantsStrip = WantsStrip(entry.option, options, entry.path)
				elseif (entry.kind == "input") then
					wantsStrip = entry.option.multiline and true or false
				end

				control = Acquire(entry.kind, wantsStrip)

				-- A control out of the pool may have been built as a dropdown
				-- when this option wants a strip, or the other way round.
				if (entry.kind == "select"
					and (control.segmented and true or false) ~= (wantsStrip and true or false)) then
					control = wantsStrip and Controls.CreateSegmented(content)
						or Controls.CreateDropdown(content)
				elseif (entry.kind == "input"
					and (control.multiline and true or false) ~= (wantsStrip and true or false)) then
					control = wantsStrip and Controls.CreateMultiline(content)
						or Controls.CreateInput(content)
				end

				local ok, err = pcall(Bind, control, entry.option, options, entry.path, self, entry)
				if (not ok) then
					control:SetLabel(entry.kind .. " (failed)")
					control:SetHelp(tostring(err))
				end
			end

			self.controls[#self.controls + 1] = control
		end

		return self:Layout()
	end

	page.Restyle = function(self)
		for i, control in ipairs(self.controls) do
			control:Restyle()
		end
	end

	page.GetControls = function(self)
		return self.controls
	end

	page.GetSections = function(self)
		return self.sections or {}
	end

	return page
end
