local M = {}

---@class ScratchBuffer
---@field active boolean
---@field id string
---@field timestamp? osdate
---@field buf_content string[]

---@class State
---@field buffer_nr? integer
---@field save_path string
---@field buffer_namespace? integer
---@field current_buffer_index integer
---@field default_buffer_content string[]
---@field custom_buffers ScratchBuffer[]

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
	default_buffer_content = {
		"",
		"",
		"# date",
		"",
		"",
		"# date",
		"",
		"",
		"# date",
		"",
		"",
		"# date",
		"",
		"",
	},
	custom_buffers = {
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
			active = true,
			buf_content = {
				"",
				"",
				"# this is the pre-set buffer",
				"if you see this, loading from the file failed!",
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
			active = true,
			buf_content = {
				"",
				"",
				"# 2this is the pre-set buffer2",
				"2if you see this, loading from the file failed!",
			},
		},
	},
}

---@return osdate
M._generate_timestamp = function()
	local date = os.date("*t")
	---@cast date osdate
	return date
end

M.write = function()
	local current_buffer_content = vim.api.nvim_buf_get_lines(M.state.custom_buffers.buf_nr, 0, -1, false)
	M.state.custom_buffers.buf_content = current_buffer_content

	M._save_to_file(M.state.save_path, M.state.custom_buffers.buf_content)
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
	local custom_file_content = M._load_from_file()
	M.state.custom_buffers = custom_file_content
	M.state.current_buffer_index = #M.state.custom_buffers
end

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
		return M.state.custom_buffers
	end

	file:close()
	vim.notify("data", data)

	local ok, result = pcall(function()
		return loadstring("return " .. data)()
	end)

	if not ok or not result then
		vim.notify("Failed to parse file content: " .. tostring(result), vim.log.levels.ERROR)
		return M.state.custom_buffers
	end
	vim.notify("result", result)

	return result
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
	-- Scratch-Buffer erstellen
	local buffer = vim.api.nvim_create_buf(false, true) -- unlisted und ohne Datei

	M.state.buffer_namespace = vim.api.nvim_create_namespace("workline_page_index")

	-- Optionale Einstellungen für den Scratch-Buffer
	vim.api.nvim_set_option_value("filetype", "markdown", { buf = buffer })
	vim.api.nvim_set_option_value("buftype", "nowrite", { buf = buffer })
	vim.api.nvim_set_option_value("swapfile", false, { buf = buffer })
	vim.api.nvim_buf_set_lines(buffer, 0, -1, false, {})
	return buffer
end

-- -@param index integer
-- M._generate_buffer_content_from_buffer_object = function(index)
-- 	---@type ScratchBuffer
-- 	local content = M.state.custom_buffers[index]
--
-- 	if content == nil then
-- 		vim.notify("Buffer does not exist", 2, {})
-- 		return
-- 	end
--
-- 	vim.api.nvim_buf_set_lines(M.state.buffer_nr, 0, -1, false, content.buf_content)
-- end

M._generate_simple_file = function()
	local file = io.open(M.state.save_path, "w")
	if file then
		file:write(vim.inspect(M.state.custom_buffers))
		file:close()
	else
		vim.notify("something went wrong creating the file", 2, {})
	end
end

---@param buffer_index integer
M._generate_buffer_content_from_current_buffer_index = function(buffer_index)
	if #M.state.custom_buffers == 0 then
		vim.notify("#custom_buffers == 0!", 2, {})
		return
	end

	local buffer = M.state.custom_buffers[buffer_index]

	if buffer ~= nil then
		vim.api.nvim_buf_set_lines(M.state.buffer_nr, 0, -1, false, buffer.buf_content)
	else
		vim.notify("error in updating buffer with new content", 2, {})
	end
end

M._save_changes_inmemory = function()
	---@type string[]
	local current_buffer_content = vim.api.nvim_buf_get_lines(M.state.buffer_nr, 0, -1, false) or {}

	M.state.custom_buffers[M.state.current_buffer_index].buf_content = current_buffer_content
end

M._save_all_to_file = function()
	local file = io.open(M.state.save_path, "w")

	if file == nil then
		print("Could not open file for writing: " .. M.state.save_path)
		return
	else
		file:write(vim.inspect(M.state.custom_buffers))
		file:close()
	end
end

M._generate_new_entry = function()
	local timestamp = M._generate_timestamp()
	local new_buf_content = M.state.default_buffer_content

	table.insert(
		new_buf_content,
		4,
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
		active = true,
		id = M._generate_id(),
		timestamp = timestamp,
		buf_content = new_buf_content,
	}

	table.insert(M.state.custom_buffers, #M.state.custom_buffers + 1, new_scratch)
end

M._remove_entry = function()
	table.remove(M.state.custom_buffers, M.state.current_buffer_index)
end

M._set_cursor_on_buffer_change = function()
	vim.api.nvim_win_set_cursor(0, { 4, 0 })
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

	vim.keymap.set("n", "N", function()
		M._generate_new_entry()
		M.state.current_buffer_index = #M.state.custom_buffers
		M._generate_buffer_content_from_current_buffer_index(M.state.current_buffer_index)
		M._generate_buffer_extmark()
	end, { buffer = buffer })

	vim.keymap.set("n", "X", function()
		vim.ui.input({ prompt = "Are you sure? (y/n): " }, function(input)
			if input == "y" then
				M._remove_entry()

				-- check if index is now out-of-bounds
				M.state.current_buffer_index = math.min(M.state.current_buffer_index, #M.state.custom_buffers)
				-- M._generate_buffer_content_from_buffer_object(M.state.current_buffer_index)
				M._generate_buffer_content_from_current_buffer_index(M.state.current_buffer_index)
				M._generate_buffer_extmark()
				M._set_cursor_on_buffer_change()

				M._save_changes_inmemory()
				M._save_all_to_file()
			end
		end)
	end, { buffer = buffer })

	vim.keymap.set("n", "L", function()
		M.state.current_buffer_index = math.min(M.state.current_buffer_index + 1, #M.state.custom_buffers)
		M._generate_buffer_content_from_current_buffer_index(M.state.current_buffer_index)
		M._generate_buffer_extmark()
	end, { buffer = buffer })

	vim.keymap.set("n", "H", function()
		M.state.current_buffer_index = math.max(M.state.current_buffer_index - 1, 1)
		M._generate_buffer_content_from_current_buffer_index(M.state.current_buffer_index)
		M._generate_buffer_extmark()
	end, { buffer = buffer })
end

M._generate_buffer_extmark = function()
	vim.api.nvim_buf_clear_namespace(M.state.buffer_nr, M.state.buffer_namespace, 0, -1)

	-- Setze den virtuellen Text in der letzten Zeile
	vim.api.nvim_buf_set_extmark(M.state.buffer_nr, M.state.buffer_namespace, 0, 0, {
		virt_text = {
			{ string.format("%d/%d Buffer", M.state.current_buffer_index, #M.state.custom_buffers) },
		},
		virt_text_pos = "eol", -- Text am Ende der Zeile anzeigen
	})
end

M.window = function()
	if M.state.buffer_nr == nil then
		M.state.buffer_nr = M._generate_buffer()
		M._set_all_buffer_keymaps(M.state.buffer_nr)
	end

	-- M._generate_buffer_content_from_buffer_object(M.state.current_buffer_index)
	M._generate_buffer_content_from_current_buffer_index(M.state.current_buffer_index)
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
end

vim.keymap.set("n", "<leader>0", "<CMD>lua require('workline').window()<CR>")

M.load()

return M

-- vim.api.nvim_create_autocmd("VimEnter", {
-- 	callback = function()
-- 		print("VimEnter")
-- 	 M.state.custom_buffers.buf_content = M._load_from_file(state.save_path)
-- 	end,
-- })
--
-- vim.api.nvim_create_autocmd("VimLeave", {
-- 	callback = function()
-- 		print("VimLeave")
-- 		M._save_to_file(state.save_path, M.state.custom_buffers.buf_content)
-- 	end,
-- })
