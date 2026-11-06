-- Serialize actual recording-widget state, not a second animation model.
local Export = {}
local function json(value)
	local kind = type(value)
	if kind == "string" then return '"'..value:gsub('\\','\\\\'):gsub('"','\\"'):gsub('\n','\\n'):gsub('\r','\\r')..'"' end
	if kind == "number" or kind == "boolean" then return tostring(value) end
	if kind ~= "table" then return "null" end
	local entries = {}
	if #value > 0 then
		for _, item in ipairs(value) do entries[#entries+1] = json(item) end
		return "["..table.concat(entries,",").."]"
	end
	for key, item in pairs(value) do entries[#entries+1] = json(key)..":"..json(item) end
	return "{"..table.concat(entries,",").."}"
end
function Export.Write(path, data)
	local file = assert(io.open(path,"w"));file:write(json(data));file:close()
end
function Export.Layer(art, width, height)
	local rect = {0,0,1,1}
	if not (art.anchor or art.allPoints) then
		local point = art.points and art.points[#art.points]
		if not point and art.points and art.points.CENTER then point={"CENTER",unpack(art.points.CENTER)} end
		if point and point[1] == "CENTER" then
			local w,h = (art.width or 0)/width,(art.height or 0)/height
			rect = {point[4]/width-w/2, 1-point[5]/height-h/2, w,h}
		end
	end
	return {path=art.path or art.texture, coords=art.coords or {0,1,0,1},
		color=art.color or {1,1,1}, alpha=art.shown==false and 0 or art.alpha or 1,
		blend=art.blend or art.blendMode or "BLEND", rect=rect}
end
function Export.Frame(frame, width, height)
	local layers = {}
	for _, key in ipairs({"Body","Pattern","Flow","FlowNext"}) do
		if frame[key] then layers[#layers+1] = Export.Layer(frame[key],width,height) end
	end
	for _, art in ipairs(frame.Layers or {}) do layers[#layers+1] = Export.Layer(art,width,height) end
	for _, art in ipairs(frame.Motes or {}) do layers[#layers+1] = Export.Layer(art,width,height) end
	for _, ember in ipairs(frame.Embers or {}) do
		for _, key in ipairs({"Glow","Core"}) do layers[#layers+1] = Export.Layer(ember[key],width,height) end
	end
	return {time=frame.Time or 0,alpha=frame.alpha or 1,layers=layers}
end
return Export
