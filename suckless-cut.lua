local config = {
	export_mode = "ffmpeg"
	--[[
		supported:

		- smoothie
		- ffmpeg

		cycle by pressing K
	]]
	,smoothie_path = "smoothie-rs"
	,ffmpeg_path = "ffmpeg"
	--[[

		defaults to checking in path

		Windows users: DO NOT FORGET TO ESCAPE \ BY DOUBLING THEM, i.e.:

		"D:\\This\\is\\OKAY\\smoothie-rs.exe"

		"D:\This\is NOT\OKAY\smoothie-rs.exe"

	]] --


	,cut_mode = 'trim'
	--[[

		supported:
		
		- trim: merge each file's own cut to a single file
		- split: each cut is exported in it's own file

		cycle by pressing k

	]] --
	,switch_above = 119

	,output_directory = ""
	--[[

		folder where videos get outputed, there's three possible settings:

		- an empty strings which means output in the same directory as the video
		- "." for working directory
		- "D:\\Videos\\", do not forget to duplicate back slashes \

	]] --

	,dur = 2500
	-- Duration of OSC (top left) messages, in milliseconds

	,verbose = false
	-- Off by default, can be toggled by pressing Ctrl+v
}
require "mp.options".read_options(config, "suckless-cut")
local mp = require 'mp'
local msg = require 'mp.msg'
local utils = require 'mp.utils'
local switchExportRan = false

mp.register_event("file-loaded", function()
	local container_fps = mp.get_property('container-fps')
	if container_fps == nil then return end
	local vid_fps = tonumber(container_fps)

	if vid_fps == 0 or switchExportRan then
		-- disabled by user / already ran
		return
	elseif config.switch_above > vid_fps then
		print("FPS is above trigger limit, switching export mode to smoothie")
		config.export_mode = "smoothie"
	end
	switchExportRan = true
end)

Osdwarn = false -- Used when user made too many trimming points
Trs = {}        -- Creates a fresh empty table, will be appended start/fin timecodes
Index = 1       -- Selects the trim 1, for it to be increased/decreased later

local function verb(...)
	local args = { ... }
	local text = ""

	for i, v in ipairs(args) do
		text = text .. tostring(v)
	end
	if config.verbose == true then
		print("VERB", text)
	end
end



local function notify(duration, ...)
	local args = { ... }
	local text = ""

	for i, v in ipairs(args) do
		text = text .. tostring(v)
	end

	if text == nil or text == "" then
		return
	end

	print("", text)
	mp.command(string.format("show-text \"%s\" %d 1", text, duration))
end



local function dump()
	local vals = {
		'container-fps', 'time-pos',
		'playback-time/full', 'stream-open-filename',
		'estimated-frame-number', 'duration'
	}
	for _, val in ipairs(vals) do
		print(val, ": ", mp.get_property(val))
	end
end; mp.add_key_binding("Ctrl+d", "dump", dump)



local function setindex(index)
	notify(config.dur, ("Setting index to [" .. index .. "]"))
	Index = index
end
mp.register_script_message('setindex', setindex)



local function round(int)
	return (math.floor(int * 100)) / 100
end

local function get_fn()
	local fn = utils.join_path(mp.get_property("working-directory", ""), (mp.get_property("path", "")))

	assert(io.open(fn, "r"), "\nFailed to get path " .. fn .. " insufficient permissions?")

	-- -- additional path checking
	-- if (io.open(fn, "r") == nil) then
	-- 	fn = utils.join_path(utils.getcwd(), fn)
	-- else
	-- 	print("Failed getting path " .. fn)
	-- end

	verb("PATH: " .. fn)

	return fn
end



local function get_basename(path)
	local _, basename = utils.split_path(path)
	assert(basename, "Failed to get basename from " .. path)
	return basename
end




local function selectindex()
	-- local fps = mp.get_property('container-fps')

	local menu = {
		type  = 'menu_type',
		title = 'Select an index to switch back to',
		items = {}
	}
	for i, cur in ipairs(Trs) do
		if cur['start'] or cur['end'] then
			menu['items'][i] = {}
			menu['items'][i]['title'] = (round(cur['start']) or '') .. ' - ' .. (round(cur['fin']) or '')
			menu['items'][i]['value'] = "script-message setindex " .. i
			menu['items'][i]['hint'] = get_basename(cur['path'])
		end
	end

	mp.commandv('script-message-to', 'uosc', 'open-menu', (utils.format_json(menu)))
end; mp.add_key_binding("Ctrl+t", "selectindex", selectindex)




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
		all_chapters[curr_chapter + 2] = {
			title = "",
			time = time_pos
		}
	end
	mp.set_property_native("chapter-list", all_chapters)
	--mp.set_property_number("chapter", curr_chapter+1)
	time_pos = nil
end; mp.add_key_binding("n", "createChapter", create_chapter)




local function deletechapters()
	mp.set_property_native("chapter-list", {})
end; mp.add_key_binding("Ctrl+D", "deletechapters", deletechapters)




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
	if #Trs < 2 and Trs[Index + 1] == nil then
		notify(config.dur, "You only have one starter index,\nstart making a second index before cycling through them.")
		return
	end

	if Trs[Index + 1] == nil then
		Index = 1 -- Looping through
		notify(config.dur, "[c] (Looping) Increased index back down to " .. Index)
	else
		Index = Index + 1
		notify(config.dur, "[C] Increased index to " .. Index)
	end
end; mp.add_key_binding("C", "increaseIndex", incrIndex)




local function decrIndex()
	if #Trs < 2 then
		notify(config.dur, "You only have one starter index,\nstart making a second index before cycling through them.")
		return
	end

	if Trs[Index - 1] == nil then
		Index = #Trs -- Looping through
		notify(config.dur, "[c] (Looping) Lowered index back up to " .. Index)
	else
		Index = Index - 1
		notify(config.dur, "[c] Lowered index to " .. Index)
	end
end; mp.add_key_binding("c", "decreaseIndex", decrIndex)




local function showPoints()
	if config.verbose then
		print(utils.format_json(Trs))
	end

	print("export mode: " .. config.export_mode)
	print("cut mode: " .. config.cut_mode)

	if #Trs == 0 then
		notify(config.dur,
			"cut mode: " .. config.cut_mode .. " | export mode: " .. config.export_mode .. "\nNo trimming points yet")
		return
	end

	msg = "cut mode: " .. config.cut_mode .. " | export mode: " .. config.export_mode .. "\n"
	if #Trs > 11 and Osdwarn == false then
		notify(config.dur, "You have too much trimming points\nfor it to fit on the OSD, check the console.")
		Osdwarn = true
		return
	end

	for ind, _ in ipairs(Trs) do
		if Trs[ind]['path'] ~= nil then
			msg = msg .. "\n" .. "[" .. ind .. "] " .. get_basename(Trs[ind]['path'])
		end
		if Trs[ind].start ~= nil then --/fps
			msg = msg .. " : " .. string.sub(string.format(Trs[ind].start), 1, 4)
		end
		if Trs[ind].fin ~= nil then --/fps
			msg = msg .. " - " .. string.sub(string.format(Trs[ind].fin), 1, 4)
		end
	end
	print(msg)
	mp.osd_message(msg, config.dur / 500) -- 2x longer than normal dur, divide by / 1000 for same length
end; mp.add_key_binding("Ctrl+p", "showPoints", showPoints)




local function getIndex()
	notify(config.dur, "[g] Selected index is " .. Index)
end; mp.add_key_binding("Ctrl+g", "getCurrentIndex", getIndex)


local function initIndex()
	if Trs[Index] == nil then
		Trs[Index] = {}
	end
end



local function start(sof)
	initIndex()
	local pos = mp.get_property_number('playback-time/full')
	local fn = get_fn()
	local curframe = "unfilled start"
	if sof == true then
		curframe = "0"
	else
		curframe = mp.get_property_number('time-pos')
	end

	if Trs[Index] == nil then Trs[Index] = {} end
	Trs[Index]['start'] = curframe
	Trs[Index]['path'] = fn

	notify(config.dur, "[g] Set start point of index [" .. Index .. "] at " .. round(pos))

	create_chapter(); reloadTrs()
end; mp.add_key_binding("g", "set-start", start)

local function sof()
	start(true)

	-- will probably remove the rest of this function later


	-- local fn = get_fn()
	-- notify(dur, "[G] Setting index " .. Index .. " to 00:00:00 (start of file)")
	-- if Trs[Index] == nil then Trs[Index] = {} end
	-- Trs[Index]['start'] = "0"
	-- Trs[Index]['path'] = fn
end; mp.add_key_binding("G", "set-sof", sof)


local function fin(eof)
	initIndex()
	local pos = mp.get_property_number('playback-time/full')
	local fn = get_fn()
	local curframe = "unfilled fin"
	if eof == true then
		curframe = string.format(mp.get_property('duration'))
	else
		curframe = mp.get_property_number('time-pos')
	end
	if Trs[Index] == nil then Trs[Index] = {} end
	Trs[Index]['fin'] = curframe

	if Trs[Index]['start'] == nil and Trs[Index - 1] and Trs[Index - 1]['start'] ~= nil then
		notify(config.dur, "[g] You need to set a start point first.")
		return nil
		-- Trs[Index-1]['fin'] = curframe
	end

	Trs[Index]['path'] = fn

	notify(config.dur, "[h] Set end point of index [" .. Index .. "] at " .. round(pos))

	if Trs[Index + 1] == nil then
		Trs[Index + 1] = {}
	end

	if Trs[Index + 1]['start'] == nil and Trs[Index + 1]['fin'] == nil then -- Only step up if it's the last index
		Index = Index +
			1                                                            -- Else it means the user has went back down on an older index
	end

	create_chapter(); reloadTrs()
end; mp.add_key_binding("h", "set-fin", fin)


local function eof()
	fin(true)

	-- same as sof

	-- local fn = get_fn()
	-- print("", utils.format_json(Trs))
	-- if Trs[Index]['start'] == nil then
	-- 	notify(dur, "[g] You need to set a start point first.")
	-- 	return
	-- end

	-- local framecount = mp.get_property('duration')
	-- notify(dur, "[H] Set end point of index [" .. Index .. "] to " .. framecount .. " (End of file)")
	-- Trs[Index]['fin'] = string.format(framecount)
	-- Trs[Index]['path'] = fn
end; mp.add_key_binding("H", "set-eof", eof)


---------------------------------------------------
-- the following functions are used by render() ---
---------------------------------------------------

local function sanitizeFilepath(filepath)
	local sanitized = filepath
    if package.config:sub(1,1) == '\\' then -- Check if the system is Windows
		sanitized = filepath:gsub("/", "\\")  -- Replace forward slashes with backslashes
    end
    return sanitized
end

local function checkTrs(tbl)
	-- Check if the table is empty
	if next(tbl) == nil then
		print("next is nil ")
		return false
	end

	-- Get the last element of the table
	local lastObject = tbl[#tbl]

	-- Check if the last object contains all required keys
	if lastObject.path and lastObject.fin and lastObject.start then
		print("contains all keys")
		return true
	else
		print("insuficient keys")
		print(utils.format_json(tbl[#tbl]))
		print(utils.format_json(tbl))
		return false
	end
end

local function appendSuffix(path, suffix)
	local basename = path:match("^.+[\\/](.+)$")
	if basename then
		local dotIndex = basename:find("%.")
		if dotIndex then
			local namePart = basename:sub(1, dotIndex - 1)
			local extension = basename:sub(dotIndex)
			return path:sub(1, -(#basename + 1)) .. namePart .. suffix .. extension
		else
			return path .. suffix
		end
	else
		error("Failed adding suffix '" .. suffix .. "' to video file path " .. path, 1)
	end
end

-- https://docs.python.org/3/library/tempfile.html#tempfile.gettempdir
local tempfolder = os.getenv("TEMP")
if utils.readdir(tempfolder) == nil then
	tempfolder = os.getenv("TMPDIR")
	if utils.readdir(tempfolder) == nil then
		if package.config:sub(1, 1) == '\\' then
			tempfolder = "C:\\Temp"
		else
			tempfolder = "/tmp"
		end
		if utils.readdir(tempfolder) == nil then
			error("failed to find temp folder")
		end
	end
end

local function table_to_args(args)
	for index, object in ipairs(args) do
		if string.find(object, "%s") then
			args[index] = '"' .. object .. '"'
		end
	end

	return table.concat(args, " ")
end

local function render()
	-- hides https://mpv.io/manual/master/#terminal-status-line
	mp.set_property_bool("quiet", true)

	Commands = {}
	if checkTrs(Trs) == false then
		Trs[#Trs] = nil
	end
	-- this fixed something at some point
	-- Trs[#Trs] = nil -- remove last object

	local ffi = require("ffi")
	ffi.cdef [[
		int system(const char *command);
	]]

	if config.cut_mode == 'split' then
		if config.export_mode == "smoothie" then
			for _, val in pairs(Trs) do
				Cmd = {
					args = {
						"-i", val['path'],
						"--override", "runtime;cut type;trim",
						"--stripaudio",
						"--override", "runtime;timecodes;" .. val['start'] .. '-' .. val['fin']
					}
				}
			end
			Commands[#Commands + 1] = Cmd
		elseif config.export_mode == 'ffmpeg' then
			for _, val in pairs(Trs) do
				local outPath = appendSuffix(
					val['path'],
					round(val['start']) .. '-' .. round(val['fin'])
				)
				Cmd = {
					args = {
						"-loglevel", "error",
						"-stats",
						"-i", val['path'],
						"-map", "0",
						"-ss", val['start'],
						"-to", val['fin'],
						"-c", "copy",
						outPath
					}
				}
				Commands[#Commands + 1] = Cmd
			end
		end
	elseif config.cut_mode == 'trim' then
		local unique = {}

		for _, value in pairs(Trs) do
			if not unique[value.path] then
				unique[value.path] = {}
			end
			unique[value.path][#unique[value.path] + 1] = { start = value['start'], fin = value['fin'] }
		end

		if config.export_mode == "smoothie" then
			for key, value in pairs(unique) do
				Cmd = {
					args = {
						"-i", key,
						"--override", "runtime;cut type;trim",
						"--stripaudio",
						"--override"
					}
				}
				local arg = "runtime;timecodes"
				for index, timecodes in ipairs(value) do
					-- print(index, utils.format_json(timecodes))

					arg = arg .. ';' .. timecodes['start'] .. '-' .. timecodes['fin']
				end
				arg = '"' .. arg .. '"'
				table.insert(Cmd.args, arg)
				Commands[#Commands + 1] = Cmd
			end
		elseif config.export_mode == "ffmpeg" then
			print("unique: " .. utils.format_json(unique))
			for in_path, cuts in pairs(unique) do
				local cutted_paths = {}
				for _, cut in pairs(cuts) do
					local outPath = sanitizeFilepath(utils.join_path(
						tempfolder,
						get_basename(in_path) .. '-' .. cut.start .. '-' .. cut.fin .. "-cut.mkv"
					))

					local args = table_to_args({
						"-loglevel", "error",
						"-stats",
						"-i", in_path,
						"-map", "0",
						"-ss", cut.start,
						"-to", cut.fin,
						"-c", "copy",
						outPath

					})
					cutted_paths[#cutted_paths + 1] = outPath
					verb("temp cut: " .. args)

					ffi.C.system(config.ffmpeg_path .. " " .. args)
				end

				local concat_path = utils.join_path(tempfolder, "slc-concat-temp.txt")
				local file = io.open(concat_path, "w")

				-- print("cutted paths: " .. utils.to_string(cutted_paths))

				if not file then
					error("Unable to open file '" .. concat_path .. "' for writing.")
				end

				for index, path in ipairs(cutted_paths) do
					verb("writing " .. index .. " line '" .. path .. "'")
					file:write("file '" .. path .. "'\n")
				end
				file:close()

				local args = table_to_args({
					"-hide_banner",
					"-loglevel", "error",
					"-stats",

					"-f", "concat",
					"-safe", "0",
					"-i", concat_path,
					"-c", "copy",

					"-default_mode", "infer_no_subs",
					"-ignore_unknown",
					"-strict", "experimental",

					appendSuffix(in_path, "-trim")
				})

				verb("final concat :" .. args)

				ffi.C.system(config.ffmpeg_path .. " " .. args)
			end
		else
			error("Unknown export mode '" .. config.export_mode .. "'")
		end
	end

	--[[
	if config.cut_mode == 'split' then
		for key, val in pairs(Trs) do
			if config.export_mode == 'smoothie' then
				verb('setting smoothie split args')

				Cmd = {
					args = {
						"-i", val['path'],
						"--override", "runtime;cut type;trim",
						"--stripaudio",
						"--override", "runtime;timecodes;" .. val['start'] .. '-' .. val['fin']
					}
				}
			elseif config.export_mode == 'ffmpeg' then
				verb('setting ffmpeg split args')
				local outPath = appendSuffix(
					val['path'],
					round(val['start']) .. '-' .. round(val['fin'])
				)
				Cmd = {
					args = {
						"-loglevel", "error",
						"-stats",
						"-i", val['path'],
						"-ss", val['start'],
						"-to", val['fin'],
						"-c", "copy",
						outPath
					}
				}
			end
			Commands[#Commands + 1] = Cmd
		end
	elseif config.cut_mode == 'trim' then
		local unique = {}

		for key, value in pairs(Trs) do
			if not unique[value.path] then
				unique[value.path] = {}
			end
			unique[value.path][#unique[value.path] + 1] = { start = value['start'], fin = value['fin'] }
		end

		for key, value in pairs(unique) do
			if config.export_mode == "smoothie" then
				Cmd = {
					args = {
						"-i", key,
						"--override", "runtime;cut type;trim",
						"--stripaudio",
						"--override"
					}
				}
				local arg = "runtime;timecodes"
				for index, timecodes in ipairs(value) do
					-- print(index, utils.format_json(timecodes))

					arg = arg .. ';' .. timecodes['start'] .. '-' .. timecodes['fin']
				end
				arg = '"' .. arg .. '"'
				table.insert(Cmd.args, arg)
				Commands[#Commands + 1] = Cmd
			else
				print("\27[31mffmpeg  yet\27[0m")
			end
		end
	end
	]]

	if not config.verbose then
		mp.set_property("vo", "null")
		mp.commandv('quit')
	end

	for _, Cmd in pairs(Commands) do
		local command = ''
		verb("what even is args: " .. utils.format_json(Cmd.args))

		for i, element in ipairs(Cmd.args) do
			if string.find(element, "%s") then
				Cmd.args[i] = '"' .. element .. '"'
			end
		end

		command = table.concat(Cmd.args, " ")

		if config.verbose == true and config.export_mode == "smoothie" then
			command = command .. ' --verbose'
			print('COMMAND: ' .. command)
		end

		-- -- another way
		-- mp.command_native({
		-- 	name = "subprocess",
		-- 	playback_only = false,
		-- 	capture_stdout = true,
		-- 	args = Cmd.args,
		-- 	detach = true
		-- })

		if config.export_mode == "smoothie" then
			ffi.C.system(config.smoothie_path .. " " .. command)

		elseif config.export_mode == "ffmpeg" and config.cut_mode == "split" then

			ffi.C.system(config.ffmpeg_path .. " " .. command)
		end


		-- print(utils.to_string(config.export_mode ~= "smoothie") .. " AND " .. utils.to_string(config.cut_mode ~= "trim"))
		-- if config.export_mode ~= "smoothie" and config.cut_mode ~= "trim" then
		-- 	print("we gud :3")
		-- 	if config.export_mode == "smoothie" then
		-- 		print("haha!")
		-- 		ffi.C.system(config.smoothie_path .. " " .. command)
		-- 	elseif config.export_mode == "ffmpeg" then
		-- 		ffi.C.system(config.ffmpeg_path .. " " .. command)
		-- 	else
		-- 		error("Unknown export mode \"" .. config.export_mode .. "\"")
		-- 	end
		-- end
	end

	if not config.verbose then
		mp.commandv('quit')
	end

	mp.set_property_bool("quiet", false)
end; mp.add_key_binding("Ctrl+r", "exportSLC", render)




local function cycleCutModes()
	if config.cut_mode == 'trim' then
		notify(config.dur, "[k] SPLIT MODE: Separating cuts into separate files")
		config.cut_mode = 'split'
	elseif config.cut_mode == 'split' then
		notify(config.dur, "[k] TRIM MODE: Joining each videos' cuts")
		config.cut_mode = 'trim'
	end
end; mp.add_key_binding("k", "toggleCutModes", cycleCutModes)

local function cycleExportModes()
	if config.export_mode == 'ffmpeg' then
		notify(config.dur, "[k] EXPORT MODE: smoothie")
		config.export_mode = 'smoothie'
	elseif config.export_mode == 'smoothie' then
		notify(config.dur, "[k] EXPORT MODE: ffmpeg")
		config.export_mode = 'ffmpeg'
	else
		notify(config.dur, "unknown export mode '" .. config.export_mode .. "' falling back to ffmpeg")
		config.export_mode = 'ffmpeg'
	end
end; mp.add_key_binding("K", "toggleExportModes", cycleExportModes)


local function toggleVerb()
	if config.verbose == true then
		notify(config.dur, "[Ctrl+v] toggled off Verbose")
		config.verbose = false
	elseif config.verbose == false then
		notify(config.dur, "[Ctrl+v] toggled on Verbose")
		config.verbose = true
	end
end; mp.add_key_binding("Ctrl+v", "toggleSLCverbose", toggleVerb)
