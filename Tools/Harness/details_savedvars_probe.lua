-- Offline, read-only probe. Evaluates only the SavedVariables data in an empty
-- environment, then prints an appearance whitelist (no actors or combat history).
local environment = {}
local chunk = assert(loadfile(assert(arg[1], "SavedVariables file required")))
setfenv(chunk, environment)
chunk()
local database = environment._detalhes_database or environment._detalhes_global or {}
local function values(instance)
	local row = instance.row_info or {}
	for _, key in ipairs({"skin", "window_scale", "bg_alpha", "titlebar_height"}) do
		print(key .. "=" .. tostring(instance[key]))
	end
	for _, key in ipairs({"height", "no_icon", "texture", "texture_file", "texture_custom", "texture_background", "overlay_texture", "textL_show_number"}) do
		print("row." .. key .. "=" .. tostring(row[key]))
	end
end
for index, instance in ipairs(database.tabela_instancias or {}) do
	print("window=" .. index)
	values(instance)
end
for _, profile in pairs(database.__profiles or {}) do
	for index, instance in ipairs(profile.instances or {}) do
		if (type(instance.skin) == "string" and instance.skin:find("AzeriteUI", 1, true)) then
			print("AzeriteUI profile window=" .. index)
			values(instance)
		end
	end
end
