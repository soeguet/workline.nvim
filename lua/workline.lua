local M = {}

---@class ScratchBuffer
---@field disabled boolean or false
---@field visible? boolean
---@field id string
---@field time_diff? TimeDiff
---@field timestamp? osdate
---@field buf_content BufferContent

---@class BufferContent
---@field enabled? string -- something like // - [ ] enabled
---@field date? string -- something like // 2024-12-29, 21:41
---@field duration? string -- something like // 0h 9m
---@field notes string[]

---@class TimeDiff
---@field years? integer
---@field months? integer
---@field days? integer
---@field hours? integer
---@field minutes? integer
---@field seconds? integer

---@class RowsInfo
---@field date_row number
---@field cursor_row number
---@field diff_row number

---@class State
---@field buffer_nr? integer
---@field save_path string
---@field rows_info RowsInfo
---@field buffer_namespace? integer
---@field current_buffer_index integer
---@field default_buffer_content string[]
---@field content_buffers ScratchBuffer[]
---@field disabled_buffers ScratchBuffer[]
---@field visibile_buffers? ScratchBuffer[]

---@return string
M._generate_id = function()
	local id = os.date("%Y%m%d%H%M%S")
	---@cast id string
	return id
end

---@type State
M.state = {
	save_path = vim.fn.stdpath("data") .. "/custom_buffer_state.lua",
	current_buffer_index = 1,
	rows_info = {
		date_row = 6,
		cursor_row = 12,
		diff_row = 9,
		enabled_row = 3,
	},
	default_buffer_content = {
		"defaults are default",
	},
	disabled_buffers = {},
	content_buffers = {
		{
			id = M._generate_id(),
			timestamp = {
				day = 27,
				hour = 14,
				isdst = false,
				min = 3,
				month = 12,
				sec = 23,
				wday = 6,
				yday = 362,
				year = 2024,
			},
			disabled = false,
			buf_content = {

				notes = {
					"## this is the pre-set buffer",
					"if you see this, loading from the file failed!",
				},
			},
		},
		{
			id = M._generate_id(),
			timestamp = {
				day = 27,
				hour = 14,
				isdst = false,
				min = 4,
				month = 12,
				sec = 23,
				wday = 6,
				yday = 362,
				year = 2024,
			},
			disabled = false,
			buf_content = {
				notes = {
					"## 2this is the pre-set buffer2",
					"2if you see this, loading from the file failed!",
				},
			},
		},
	},
}

M._calculate_time_diff_duration = function()
	if M.state.current_buffer_index < 2 then
		return "00:00"
	end

	local index = M.state.current_buffer_index
	local t_c = M.state.content_buffers[index]
	-- don't want to go out of bounds here
	local t_l = M.state.content_buffers[math.max(index - 1, 1)]

	local time1 = {
		year = t_c.timestamp.year,
		month = t_c.timestamp.month,
		day = t_c.timestamp.day,
		hour = t_c.timestamp.hour,
		min = t_c.timestamp.min,
		sec = t_c.timestamp.sec,
	}
	local time2 = {
		year = t_l.timestamp.year,
		month = t_l.timestamp.month,
		day = t_l.timestamp.day,
		hour = t_l.timestamp.hour,
		min = t_l.timestamp.min,
		sec = t_l.timestamp.sec,
	}

	local timestamp1 = os.time(time1)
	local timestamp2 = os.time(time2)

	local diff = os.difftime(timestamp1, timestamp2)

	local days = math.floor(diff / (24 * 3600))
	local hours = math.floor((diff % (24 * 3600)) / 3600)
	local minutes = math.floor((diff % 3600) / 60)
	local seconds = diff % 60

	M.state.content_buffers[M.state.current_buffer_index].time_diff = {
		days = days,
		minutes = minutes,
		seconds = seconds,
		hours = hours,
	}

	return string.format("%dh %dm", hours, minutes)
end

---@param time osdate
---@return string
M._generate_date_string_from_ostime = function(time)
	return string.format("%02d-%02d-%02d, %02d:%02d", time.year, time.month, time.day, time.hour, time.min)
end

---@return osdate
M._generate_timestamp = function()
	local date = os.date("*t")
	---@cast date osdate
	return date
end

M._save_to_file = function(path, table)
	local file = io.open(path, "w")

	if file == nil then
		print("Could not open file for writing: " .. path)
		return
	else
		file:write(vim.inspect(table))
		file:close()
	end
end

M.load = function()
	local buffers, disabled_buffers = M._load_from_file()

	M.state.content_buffers = buffers or {}
	M.state.disabled_buffers = disabled_buffers or {}

	M.state.current_buffer_index = #M.state.content_buffers
end

---@return ScratchBuffer[] content_buffers, ScratchBuffer[] disabled_buffers
M._load_from_file = function()
	local file = io.open(M.state.save_path, "r")
	local data

	if not file then
		M._generate_simple_file()
		return M._load_from_file()
	else
		data = file:read("*a")
	end

	if not data or data == "" then
		vim.notify("RIP", 2)
		return M.state.content_buffers, M.state.disabled_buffers
	end

	file:close()

	local ok, result = pcall(function()
		return loadstring("return " .. data)()
	end)

	if not ok or not result then
		vim.notify("Failed to parse file content: " .. tostring(result), vim.log.levels.ERROR)
		return M.state.content_buffers, M.state.disabled_buffers
	end

	return result[1], result[2]
end

M.check_for_file = function()
	local file = io.open(M.state.save_path, "r")
	if file == nil then
		print("Could not open file for writing: " .. M.state.save_path)
		return
	else
		file:close()
	end
end

M._generate_buffer = function()
	local buffer = vim.api.nvim_create_buf(false, true)

	M.state.buffer_namespace = vim.api.nvim_create_namespace("workline_page_index")

	vim.api.nvim_set_option_value("filetype", "markdown", { buf = buffer })
	vim.api.nvim_set_option_value("buftype", "nowrite", { buf = buffer })
	vim.api.nvim_set_option_value("swapfile", false, { buf = buffer })
	vim.api.nvim_buf_set_lines(buffer, 0, -1, false, {})
	return buffer
end

M._generate_simple_file = function()
	local file = io.open(M.state.save_path, "w")
	if file then
		local tables_to_save = {
			M.state.content_buffers,
			{},
		}
		file:write(vim.inspect(tables_to_save))
		file:close()
	else
		vim.notify("something went wrong creating the file", 2, {})
	end
end

---@param buf_content_full ScratchBuffer
---@return string[]
M._create_new_buffer_content = function(buf_content_full)
	local content = {}

	table.insert(content, "")
	table.insert(content, "")

	if not buf_content_full.disabled then
		table.insert(content, "- [x] enabled")
	else
		table.insert(content, "- [ ] enabled")
	end

	table.insert(content, "")

	table.insert(content, "# date")
	if buf_content_full.buf_content.date then
		table.insert(content, buf_content_full.buf_content.date)
	else
		local time_string = M._generate_date_string_from_ostime(buf_content_full.timestamp)
		table.insert(content, time_string)
	end

	table.insert(content, "")

	table.insert(content, "# duration")
	-- TODO maybe change function signature to take an index?
	table.insert(content, M._calculate_time_diff_duration())

	table.insert(content, "")
	table.insert(content, "# note")

	if buf_content_full.buf_content.notes ~= nil then
		for _, note in ipairs(buf_content_full.buf_content.notes) do
			table.insert(content, note)
		end
	end

	return content
end

---@param buffer_index integer
M._generate_buffer_content_from_current_buffer_index = function(buffer_index)
	if #M.state.content_buffers == 0 then
		vim.notify("#custom_buffers == 0!", 2, {})
		return
	end

	local buffer = M.state.content_buffers[buffer_index]

	if buffer ~= nil then
		local content = M._create_new_buffer_content(buffer)
		vim.api.nvim_buf_set_lines(M.state.buffer_nr, 0, -1, false, content)
	else
		vim.notify("error in updating buffer with new content", 2, {})
	end
end

---@param buffer_index integer
M._generate_buffer_content_from_current_buffer_index_visible_only = function(buffer_index)
	if #M.state.content_buffers == 0 then
		vim.notify("#custom_buffers == 0!", 2, {})
		return
	end

	local buffer = M.state.visibile_buffers[buffer_index]

	if buffer ~= nil then
		vim.api.nvim_buf_set_lines(M.state.buffer_nr, 0, -1, false, buffer.buf_content)
	else
		vim.notify("error in updating buffer with new content", 2, {})
	end
end

M._save_changes_inmemory = function()
	---@type string[]
	local current_buffer_content = vim.api.nvim_buf_get_lines(M.state.buffer_nr, 0, -1, false) or {}
	---@type string[]
	local lines_to_be_saved = {}

	for i = #current_buffer_content, 1, -1 do
		-- we don't need whats above the note header for now
		if current_buffer_content[i] == "# note" then
			break
		end

		table.insert(lines_to_be_saved, 1, current_buffer_content[i])
	end

	M.state.content_buffers[M.state.current_buffer_index].buf_content.notes = lines_to_be_saved
end

M._save_all_to_file = function()
	local file = io.open(M.state.save_path, "w")

	if file == nil then
		print("Could not open file for writing: " .. M.state.save_path)
		return
	else
		local tables_to_save = {
			M.state.content_buffers,
			M.state.disabled_buffers,
		}
		file:write(vim.inspect(tables_to_save))
		file:close()
	end
end

M._deep_copy_table = function(random_table)
	local copy = {}
	for key, value in pairs(random_table) do
		if type(value) == "table" then
			copy[key] = M._deep_copy_table()
		else
			copy[key] = value
		end
	end
	return copy
end

M._generate_new_entry = function()
	local timestamp = M._generate_timestamp()
	local new_buf_content = M._deep_copy_table(M.state.default_buffer_content)

	table.remove(new_buf_content, M.state.rows_info.date_row)
	table.insert(
		new_buf_content,
		M.state.rows_info.date_row,
		string.format(
			"%02d-%02d-%02d, %02d:%02d",
			timestamp.year,
			timestamp.month,
			timestamp.day,
			timestamp.hour,
			timestamp.min
		)
	)

	---@type ScratchBuffer
	local new_scratch = {
		disabled = false,
		id = M._generate_id(),
		timestamp = timestamp,
		buf_content = new_buf_content,
	}

	-- insert a whole new entry! CAVE: no remove beforehand!
	table.insert(M.state.content_buffers, #M.state.content_buffers + 1, new_scratch)
end

M._move_disabled_buffers_to_disabled_array = function()
	local buffers = M.state.content_buffers
	for index = #buffers, 1, -1 do
		local buffer = buffers[index]
		if buffer.disabled then
			local disabled_buffer = table.remove(buffers, index)
			table.insert(M.state.disabled_buffers, disabled_buffer)
		end
	end
end

M._disable_custom_buffer = function()
	local current_index = M.state.current_buffer_index
	local current_content = M.state.content_buffers[current_index]

	current_content.disabled = true

	M._move_disabled_buffers_to_disabled_array()
	M.state.current_buffer_index = math.max(current_index - 1, 1)
	M._general_render_buffer()
end

M._remove_currently_displayed_entry = function()
	table.remove(M.state.content_buffers, M.state.current_buffer_index)
end

M._set_cursor_on_buffer_change = function(buf_nr)
	local buffer_max_lines = vim.api.nvim_buf_get_lines(buf_nr, 0, -1, false)
	-- TODO this feels like a hack
	vim.api.nvim_win_set_cursor(0, { math.min(M.state.rows_info.cursor_row, #buffer_max_lines), 0 })
end

---general render function for buffers which need to be drawn within the custom buffer
---@return nil
M._general_render_buffer = function()
	M._insert_diff_time()
	M._generate_buffer_content_from_current_buffer_index(M.state.current_buffer_index)
	M._generate_buffer_extmark()
	-- M._set_cursor_on_buffer_change()
end

---@param buffer integer
M._set_all_buffer_keymaps = function(buffer)
	vim.keymap.set("n", "q", function()
		M._save_changes_inmemory()
		M._save_all_to_file()
		vim.api.nvim_win_close(0, true)
	end, { buffer = buffer })

	vim.keymap.set("n", "Q", function()
		vim.api.nvim_win_close(0, true)
	end, { buffer = buffer })

	vim.keymap.set("n", "S", function()
		M._save_changes_inmemory()
		M._save_all_to_file()
	end, { buffer = buffer })

	vim.keymap.set("n", "<C-x>", function()
		M._disable_custom_buffer()
	end, { buffer = buffer })

	vim.keymap.set("n", "N", function()
		M._generate_new_entry()
		M.state.current_buffer_index = #M.state.content_buffers
		M._general_render_buffer()
	end, { buffer = buffer })

	vim.keymap.set("n", "X", function()
		vim.ui.input({ prompt = "Are you sure? (y/n): " }, function(input)
			if input == "y" then
				M._remove_currently_displayed_entry()

				-- check if index is now out-of-bounds
				M.state.current_buffer_index = math.min(M.state.current_buffer_index, #M.state.content_buffers)

				M._general_render_buffer()

				M._save_changes_inmemory()
				M._save_all_to_file()
			end
		end)
	end, { buffer = buffer })

	vim.keymap.set("n", "L", function()
		if math.min(M.state.current_buffer_index + 1, #M.state.content_buffers) ~= M.state.current_buffer_index then
			M.state.current_buffer_index = math.min(M.state.current_buffer_index + 1, #M.state.content_buffers)
			M._general_render_buffer()
		end
	end, { buffer = buffer })

	vim.keymap.set("n", "H", function()
		if math.max(M.state.current_buffer_index - 1, 1) ~= M.state.current_buffer_index then
			M.state.current_buffer_index = math.max(M.state.current_buffer_index - 1, 1)
			M._general_render_buffer()
		end
	end, { buffer = buffer })
end

M._generate_buffer_extmark = function()
	vim.api.nvim_buf_clear_namespace(M.state.buffer_nr, M.state.buffer_namespace, 0, -1)

	vim.api.nvim_buf_set_extmark(M.state.buffer_nr, M.state.buffer_namespace, 0, 0, {
		virt_text = {
			{ string.format("%d/%d Buffer", M.state.current_buffer_index, #M.state.content_buffers) },
		},
		virt_text_pos = "eol",
	})
end

M._insert_diff_time = function()
	local duration = M._calculate_time_diff_duration()
	local buffer = M.state.content_buffers[#M.state.content_buffers]
	buffer.buf_content.duration = duration
end

M._filter_content_today = function()
	local today = M._generate_timestamp()
	local vis_count = 0
	local visibile_buffers = {}

	for index, value in ipairs(M.state.content_buffers) do
		-- check for disabled buffers while at it
		if value.disabled then
			local entry = table.remove(M.state.content_buffers, index)
			table.insert(M.state.disabled_buffers, entry)
		else
			-- this is the actual check
			if
				value.timestamp.year == today.year
				and value.timestamp.month == today.month
				and value.timestamp.day == today.day
			then
				local vis = math.random(0, 100) > 50
				if vis then
					vis_count = vis_count + 1
				end

				table.insert(visibile_buffers, value)
			end
		end

		table.sort(visibile_buffers, M._sort_via_timestamp)

		M.state.visibile_buffers = visibile_buffers
	end

	vim.notify("total visible: " .. vis_count, 2, {})
end

---@param entryA osdate
---@param entryB osdate
M._sort_via_timestamp = function(entryA, entryB)
	local time1 = {
		year = entryA.year or 0,
		month = entryA.month or 0,
		day = entryA.day or 0,
		hour = entryA.hour or 0,
		min = entryA.min or 0,
		sec = entryA.sec or 0,
	}
	local time2 = {
		year = entryB.year or 0,
		month = entryB.month or 0,
		day = entryB.day or 0,
		hour = entryB.hour or 0,
		min = entryB.min or 0,
		sec = entryB.sec or 0,
	}

	return os.time(time1) < os.time(time2)
end

M.today = function()
	if M.state.buffer_nr == nil then
		M.state.buffer_nr = M._generate_buffer()
		M._set_all_buffer_keymaps(M.state.buffer_nr)
	end

	M._filter_content_today()

	M.state.current_buffer_index = #M.state.visibile_buffers
	M._generate_buffer_content_from_current_buffer_index_visible_only(M.state.current_buffer_index)
	M._generate_buffer_extmark()

	vim.api.nvim_open_win(M.state.buffer_nr, true, {
		relative = "editor",
		row = 3,
		col = 3,
		width = 50,
		height = 30,
		border = "single",
		style = "minimal",
	})

	M._set_cursor_on_buffer_change()
end

M.window = function()
	-- check if a dedicated buffer already exists or not
	if M.state.buffer_nr == nil then
		M.state.buffer_nr = M._generate_buffer()
		M._set_all_buffer_keymaps(M.state.buffer_nr)
	end

	M._move_disabled_buffers_to_disabled_array()
	M._general_render_buffer()

	vim.api.nvim_open_win(M.state.buffer_nr, true, {
		relative = "editor",
		row = 3,
		col = 3,
		width = 50,
		height = 30,
		border = "single",
		style = "minimal",
	})

	M._set_cursor_on_buffer_change(M.state.buffer_nr)
end

vim.keymap.set("n", "<leader>=", function()
	package.loaded["workline"] = nil
	vim.cmd("source %")
end)

vim.keymap.set("n", "<leader>0", function()
	require("workline").window()
end)

vim.keymap.set("n", "<leader>9", function()
	require("workline").today()
end)

M.load()

return M
