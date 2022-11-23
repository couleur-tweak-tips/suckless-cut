local filter = 'preview.jpg'

local mp = require 'mp'
local utils = require 'mp.utils'

local function get_basename (path)

	local _, basename = utils.split_path(path)
	assert(basename, 'Failed to get basename from ' .. path)
	return basename

end

local function preview()
	local fp = utils.join_path(mp.get_property('working-directory', ''), (mp.get_property('path', '')))

	if fp ~= nil then
		if get_basename(fp) == filter then
			mp.commandv('loadfile', fp)
		end
	end

end

mp.add_periodic_timer(0.3, preview)
