
local encodingargs = {
	H264_CPU = "-c:v libx264 ...",
    H265_CPU = "-c:v libx265 .."
}

local dur = 2500
	-- Duration of OSC (top left) messages, in milliseconds

local verbose = false
local mode = 'trim'
	-- defaults, feel free to change them to whatever you need

local mp = require 'mp'
local msg = require 'mp.msg'
local utils = require 'mp.utils'

Osdwarn = false -- Used when user made too many trimming points
Trs = {} -- Creates a fresh empty table, will be appended start/fin timecodes
Index = 1 -- Selects the trim 1, for it to be increased/decreased later

local function verb(...)
	local args = {...}
	local text = ""

	for i, v in ipairs(args) do
	text = text .. tostring(v)
	end
	if verbose == true then
		print("VERB", text)
	end
end



local function notify(duration, ...)
	local args = {...}
	local text = ""

	for i, v in ipairs(args) do
	text = text .. tostring(v)
	end

	if text == nil then
		return
	end

	print("", text)
	mp.command(string.format("show-text \"%s\" %d 1", text, duration))
end



local function dump()
	local vals = {
		'container-fps','time-pos',
		'playback-time/full', 'stream-open-filename',
		'estimated-frame-number', 'duration'
	}
	for _, val in ipairs(vals) do
		print(val, ": ", mp.get_property(val))
	end
end;mp.add_key_binding("Ctrl+d", "dump", dump)



local function setindex (index)
	notify(dur, ("Setting index to [" .. index .. "]"))
	Index = index
end
mp.register_script_message('setindex', setindex)



local function round(int)
	return (math.floor(int * 100))/100
end

local function get_fn()

	local fn  = utils.join_path(mp.get_property("working-directory", ""), (mp.get_property("path", "")))

	assert(io.open(fn, "r"), "\nFailed to get path " .. fn .. " insufficient permissions?")

	return fn

end



local function get_basename (path)

	local _, basename = utils.split_path(path)
	assert(basename, "Failed to get basename from " .. path)
	return basename

end




local function selectindex ()
	-- local fps = mp.get_property('container-fps')

	local menu = {
		type  = 'menu_type',
		title = 'Select an index to switch back to',
		items = {}
	}
	for i, cur in ipairs(Trs) do
	if cur['start'] or cur['end'] then
		menu['items'][i] = {}					     --/fps                                --/fps
		menu['items'][i]['title'] = (round(cur['start']) or '') .. ' - ' .. (round(cur['fin']) or '')
		menu['items'][i]['value'] = "script-message setindex " .. i
		menu['items'][i]['hint'] = get_basename(cur['path'])
	end
	end

	mp.commandv('script-message-to', 'uosc', 'open-menu', (utils.format_json(menu)))

end;mp.add_key_binding("Ctrl+t", "selectindex", selectindex)




local function create_chapter(time_pos)
	if not time_pos then
		time_pos = mp.get_property_number("time-pos")
	end
	verb("Creating chapter at ", time_pos)
	local time_pos_osd = mp.get_property_osd("playback-time/full")
	local curr_chapter = mp.get_property_number("chapter")
	local chapter_count = mp.get_property_number("chapter-list/count")
	local all_chapters = mp.get_property_native("chapter-list")

	if chapter_count == 0 then
		all_chapters[1] = {
			title = "",
			time = time_pos
		}
		curr_chapter = 0
	else
		for i = chapter_count, curr_chapter + 2, -1 do
			all_chapters[i + 1] = all_chapters[i]
		end
		all_chapters[curr_chapter+2] = {
			title = "",
			time = time_pos
		}
	end
	mp.set_property_native("chapter-list", all_chapters)
	--mp.set_property_number("chapter", curr_chapter+1)
	time_pos = nil

end;mp.add_key_binding("n", "createChapter", create_chapter)




local function deletechapters()
	mp.set_property_native("chapter-list", {})

end;mp.add_key_binding("Ctrl+D", "deletechapters", deletechapters)




local function reloadTrs()
	-- rebuilds chapters from Trs

	mp.set_property_native("chapter-list", {})
		-- Delete all chapters
	
	for i, val in pairs(Trs) do
		if val['path'] == get_fn() then

			if Trs[i]['start'] then
				create_chapter(Trs[i]['start'])
			else
				verb("not creating start chapter for index ", i)

			end

			if Trs[i]['fin'] then
				create_chapter(Trs[i]['fin'])
			else
				verb("Not creating fin chapter for index ", i)
			end
		end
	end
end;
	mp.add_key_binding("R", "reloadTrs", reloadTrs)
	mp.register_event("file-loaded", reloadTrs)




local function incrIndex()

	if #Trs < 2 and Trs[Index+1] == nil then
		notify(dur, "You only have one starter index,\nstart making a second index before cycling through them.")
		return
	end

	if Trs[Index+1] == nil then
		Index = 1 -- Looping through
		notify(dur, "[c] (Looping) Increased index back down to ".. Index)
	else
		Index = Index + 1
		notify(dur, "[C] Increased index to ".. Index)
	end
end;mp.add_key_binding("C", "increaseIndex", incrIndex)




local function decrIndex()
	if #Trs < 2 then
		notify(dur, "You only have one starter index,\nstart making a second index before cycling through them.")
		return
	end

	if Trs[Index - 1] == nil then
		Index = #Trs -- Looping through
		notify(dur, "[c] (Looping) Lowered index back up to ".. Index)
	else
		Index = Index - 1
		notify(dur, "[c] Lowered index to ".. Index)
	end
end;mp.add_key_binding("c", "decreaseIndex", decrIndex)




local function showPoints()

	if verbose then
		print(utils.format_json(Trs))		
	end

	if #Trs == 0 then
		notify(dur, "No trimming points yet")
		return
	end

	msg = "Trimming points:"
	if #Trs > 11 and Osdwarn == false	then
		notify(dur, "You have too much trimming points\nfor it to fit on the OSD, check the console.")
		Osdwarn = true
		return
	end

	for ind, _ in ipairs(Trs) do
		if Trs[ind]['path'] ~= nil then
			msg = msg .. "\n" .. "[" .. ind .. "] " .. get_basename(Trs[ind]['path'])
		end
		if Trs[ind].start ~= nil then							       --/fps
			msg = msg .. " : " .. string.sub(string.format(Trs[ind].start), 1, 4)
		end
		if Trs[ind].fin ~= nil then								     --/fps
			msg = msg .. " - " .. string.sub(string.format(Trs[ind].fin), 1, 4)
		end
	end
	print(msg)
	mp.osd_message(msg, dur/500) -- 2x longer than normal dur, divide by / 1000 for same length
end;mp.add_key_binding("Ctrl+p", "showPoints", showPoints)




local function getIndex()
	notify(dur, "[g] Selected index is ".. Index)
end;mp.add_key_binding("Ctrl+g", "getCurrentIndex", getIndex)

local function start()
	local pos = mp.get_property_number('playback-time/full')
	local fn = get_fn()
	local curframe = mp.get_property_number('time-pos')

	if Trs[Index] == nil then Trs[Index] = {} end
	Trs[Index]['start'] = curframe
	Trs[Index]['path'] = fn

	notify(dur, "[g] Set start point of index ["..Index.."] at ".. round(pos))

	create_chapter();reloadTrs()

end;mp.add_key_binding("g", "set-start", start)




local function sof()
	notify(dur, "[S] Setting index " .. Index .. " to 00:00:00 (start of file)")
	if Trs[Index] == nil then Trs[Index] = {} end
	Trs[Index]['start'] = 0
end;mp.add_key_binding("G", "set-sof", sof)




local function fin()

	local pos = mp.get_property_number('playback-time/full')
	local fn = get_fn()
	local curframe = mp.get_property_number('time-pos')
	if Trs[Index] == nil then Trs[Index] = {} end
	Trs[Index]['fin'] = curframe

	if (io.open(fn, "r") == nil) then
		fn = utils.join_path(utils.getcwd(), fn)
	end

	if Trs[Index]['start'] == nil and Trs[Index-1]['start'] ~= nil then
		notify(dur, "[g] You need to set a start point first.")
		return nil
		-- Trs[Index-1]['fin'] = curframe
	end

	Trs[Index]['path'] = fn

	notify(dur, "[h] Set end point of index ["..Index.."] at ".. round(pos))

	if Trs[Index + 1] == nil then
		Trs[Index + 1] = {}
	end

	if Trs[Index + 1]['start'] == nil and Trs[Index + 1]['fin'] == nil then -- Only step up if it's the last index
		Index = Index + 1													 -- Else it means the user has went back down on an older index
	end

	create_chapter();reloadTrs()

end;mp.add_key_binding("h", "set-fin", fin)




local function eof()

	if Trs[Index]['start'] == nil then
		notify(dur, "[g] You need to set a start point first.")
		return
	end

	local framecount = mp.get_property('duration')
	notify(dur, "[H] Set end point of index ["..Index.."] to ".. framecount .. " (End of file)")
	Trs[Index]['fin'] = framecount
end;mp.add_key_binding("H", "set-eof", eof)




local function render()
	Trs[#Trs] = nil -- beautiful syntax to remove last object
	Cmd = {args={'sm','-json', utils.format_json(Trs)}}
	if mode == 'split' then table.insert(Cmd.args,'-split')
	elseif mode == 'trim' then table.insert(Cmd.args,'-trim')
	else print('UKNOWN MODE: ' .. mode) end
	if verbose == true then
		table.insert(Cmd.args,'-verbose')
		local command = ''
		for _, k in pairs(Cmd.args) do -- awful for loop to join array to string
			command = command .. k .. ' '
		end
		print('COMMAND: ' .. command)
	end
	utils.subprocess_detached(Cmd)
	mp.commandv('quit')
end;mp.add_key_binding("Ctrl+r", "exportSLC", render)




local function cycleModes()
	if mode == 'trim' then
		notify(dur, "[k] SPLIT MODE: Separating cuts into separate files")
		mode = 'split'
	elseif mode == 'split' then
		notify(dur, "[k] TRIM MODE: Joining each videos' cuts")
		mode = 'trim'
	end
end;mp.add_key_binding("k", "toggleSLCexportModes", cycleModes)




local function toggleVerb()
	if verbose == true then
		notify(dur, "[Ctrl+v] toggled off Verbose")
		verbose = false
	elseif verbose == false then
		notify(dur, "[Ctrl+v] toggled on Verbose")
		verbose = true
	end
end;mp.add_key_binding("Ctrl+v", "toggleSLCverbose", toggleVerb)
