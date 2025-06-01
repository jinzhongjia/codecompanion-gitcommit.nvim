local client = require("codecompanion.http")
local codecompanion_config = require("codecompanion.config")
local codecompanion_adapter = require("codecompanion.adapters")

local CONSTANTS = {
	STATUS_ERROR = "error",
	STATUS_SUCCESS = "success",
}

local M = {}

---Check if we're in a git repository
---@return boolean
local function is_git_repo()
	-- 首先检查当前目录及父目录是否存在 .git 文件夹
	local function check_git_dir(path)
		local git_path = path .. "/.git"
		local stat = vim.uv.fs_stat(git_path)
		return stat ~= nil
	end

	-- 从当前目录开始向上查找
	local current_dir = vim.fn.getcwd()
	while current_dir do
		if check_git_dir(current_dir) then
			return true
		end

		-- 向上一级目录
		local parent = vim.fn.fnamemodify(current_dir, ":h")
		if parent == current_dir then
			-- 已经到达根目录
			break
		end
		current_dir = parent
	end

	-- 如果文件系统检查失败，则使用 git 命令作为备用方案
	local cmd = "git rev-parse --is-inside-work-tree"
	local result = vim.fn.system(cmd)
	return vim.v.shell_error == 0 and vim.trim(result) == "true"
end

---Get staged changes diff
---@return string|nil
local function get_staged_diff()
	if not is_git_repo() then
		return nil
	end

	local diff = vim.fn.system("git diff --no-ext-diff --staged")
	if vim.v.shell_error ~= 0 then
		return nil
	end

	if vim.trim(diff) == "" then
		return nil
	end

	return diff
end

---Generate git commit message using LLM
---@param callback fun(title: string|nil, error: string|nil)
local function generate_gitcommit(callback)
	-- Check if we're in a git repo
	if not is_git_repo() then
		return callback(nil, "Not in a git repository")
	end

	-- Get staged changes
	local diff = get_staged_diff()
	if not diff then
		return callback(nil, "No staged changes found. Please stage your changes first.")
	end

	-- Setup adapter
	local adapter = codecompanion_adapter.resolve(codecompanion_config.strategies.chat.adapter)
	if not adapter then
		return callback(nil, "Failed to resolve adapter")
	end

	adapter.opts.stream = false
	adapter = adapter:map_schema_to_params()

	--- @type CodeCompanion.Client
	local new_client = client.new({
		adapter = adapter,
	})

	local prompt = string.format(
		[[You are an expert at following the Conventional Commit specification.

Please only return a commit message that strictly follows the Conventional Commit specification, without any additional text or explanations. The commit message should include:

1. Type (required): lowercase, e.g., feat, fix, docs, style, refactor, perf, test, chore
2. Scope (optional): in parentheses after type, e.g., feat(parser)
3. Description (required): space after colon, start with verb, be concise
4. Body (optional): use bullet points (-) to list specific changes

Example format:
feat(scope): add new feature
- implement X functionality
- update Y module
- add tests for Z

Based on the git diff provided below, generate a standardized commit message.

```diff
%s
```

]],
		diff
	)

	local payload = {
		messages = adapter:map_roles({
			{ role = "user", content = prompt },
		}),
	}

	new_client:request(payload, {
		callback = function(err, data, _adapter)
			---@diagnostic disable-next-line: undefined-field
			if err and err.stderr ~= "{}" then
				---@diagnostic disable-next-line: undefined-field
				local error_msg = "Error generating commit message: " .. (err.stderr or "Unknown error")
				return callback(nil, error_msg)
			end

			if data then
				local result = _adapter.handlers.chat_output(_adapter, data)
				if result and result.status then
					if result.status == CONSTANTS.STATUS_SUCCESS then
						local content = result.output and result.output.content
						if content and vim.trim(content) ~= "" then
							return callback(vim.trim(content), nil)
						else
							return callback(nil, "Generated content is empty")
						end
					elseif result.status == CONSTANTS.STATUS_ERROR then
						local error_msg = result.output or "Unknown error occurred"
						return callback(nil, error_msg)
					end
				end
			end

			return callback(nil, "No valid response received")
		end,
	}, {
		silent = true,
	})
end

---Copy text to system clipboard
---@param text string
local function copy_to_clipboard(text)
	vim.fn.setreg("+", text)
	if vim.fn.has("clipboard") == 1 then
		vim.fn.setreg("*", text)
	end
end
---Commit changes with the given message
---@param message string
local function commit_changes(message)
	if not is_git_repo() then
		vim.notify("Not in a git repository", vim.log.levels.ERROR)
		return false
	end

	-- Check if there are staged changes
	local diff = get_staged_diff()
	if not diff then
		vim.notify("No staged changes found. Please stage your changes first.", vim.log.levels.ERROR)
		return false
	end

	-- Create a temporary file for the commit message
	local temp_file = vim.fn.tempname()
	local file = io.open(temp_file, "w")
	if not file then
		vim.notify("Failed to create temporary file for commit message", vim.log.levels.ERROR)
		return false
	end

	file:write(message)
	file:close()

	-- Execute git commit
	local cmd = string.format("git commit -F %s", vim.fn.shellescape(temp_file))
	local result = vim.fn.system(cmd)
	local exit_code = vim.v.shell_error

	-- Clean up temporary file
	os.remove(temp_file)

	if exit_code == 0 then
		vim.notify("Successfully committed changes!", vim.log.levels.INFO)
		return true
	else
		local error_msg = vim.trim(result)
		if error_msg == "" then
			error_msg = "Unknown error occurred during commit"
		end
		vim.notify("Failed to commit: " .. error_msg, vim.log.levels.ERROR)
		return false
	end
end

---Show commit message in a floating window with options
---@param message string
local function show_commit_message(message)
	local lines = vim.split(message, "\n")
	local width = math.max(
		60,
		math.min(100, math.max(unpack(vim.tbl_map(function(line)
			return #line
		end, lines))) + 4)
	)
	local height = math.min(20, #lines + 6)

	local buf = vim.api.nvim_create_buf(false, true)

	-- Create window
	local win = vim.api.nvim_open_win(buf, true, {
		relative = "editor",
		width = width,
		height = height,
		col = (vim.o.columns - width) / 2,
		row = (vim.o.lines - height) / 2,
		style = "minimal",
		border = "rounded",
		title = " Generated Commit Message ",
		title_pos = "center",
	})

	-- Set content
	vim.api.nvim_set_option_value("modifiable", true, { buf = buf })
	local content = vim.list_extend({ "Generated commit message:", "" }, lines)
	table.insert(content, "")
	table.insert(content, "")
	table.insert(content, "Actions:")
	table.insert(content, "  [c] Copy to clipboard")
	table.insert(content, "  [s] Submit (commit changes)")
	table.insert(content, "  [Enter] Copy and close")
	table.insert(content, "  [q/Esc] Close")
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, content)
	vim.api.nvim_set_option_value("modifiable", false, { buf = buf })

	-- Set up keymaps
	local opts = { buffer = buf, nowait = true, silent = true }
	vim.keymap.set("n", "q", function()
		vim.api.nvim_win_close(win, true)
	end, opts)
	vim.keymap.set("n", "<Esc>", function()
		vim.api.nvim_win_close(win, true)
	end, opts)

	vim.keymap.set("n", "c", function()
		copy_to_clipboard(message)
		vim.notify("Commit message copied to clipboard", vim.log.levels.INFO)
	end, opts)

	vim.keymap.set("n", "s", function()
		local success = commit_changes(message)
		if success then
			vim.api.nvim_win_close(win, true)
		end
	end, opts)

	vim.keymap.set("n", "<CR>", function()
		copy_to_clipboard(message)
		vim.notify("Commit message copied to clipboard", vim.log.levels.INFO)
		vim.api.nvim_win_close(win, true)
	end, opts)
end

---Main function to generate and display commit message
function M.generate_commit_message()
	vim.notify("Generating commit message...", vim.log.levels.INFO)

	generate_gitcommit(function(result, error)
		if error then
			vim.notify("Failed to generate commit message: " .. error, vim.log.levels.ERROR)
			return
		end

		if result then
			show_commit_message(result)
		else
			vim.notify("Failed to generate commit message", vim.log.levels.ERROR)
		end
	end)
end

---@type CodeCompanion.Extension
return {
	setup = function(opts)
		opts = opts or {}

		-- Create user command
		vim.api.nvim_create_user_command("CodeCompanionGitCommit", function()
			M.generate_commit_message()
		end, {
			desc = "Generate Git commit message using AI",
		})

		-- Shorter alias
		vim.api.nvim_create_user_command("CCGitCommit", function()
			M.generate_commit_message()
		end, {
			desc = "Generate Git commit message using AI (short alias)",
		})

		-- Optional: Add to CodeCompanion slash commands if enabled
		if opts.add_slash_command then
			local slash_commands = require("codecompanion.config").strategies.chat.slash_commands
			slash_commands["gitcommit"] = {
				description = "Generate git commit message from staged changes",
				callback = function(chat)
					generate_gitcommit(function(result, error)
						if error then
							chat:add_message({ role = "user", content = "Error: " .. error })
						else
							chat:add_message({
								role = "user",
								content = "Generated commit message:\n```\n" .. result .. "\n```",
							})
						end
					end)
				end,
				opts = {
					contains_code = false,
				},
			}
		end
	end,

	exports = {
		---Generate commit message programmatically
		---@param callback fun(result: string|nil, error: string|nil)
		generate = function(callback)
			generate_gitcommit(callback)
		end,

		---Check if in git repository
		---@return boolean
		is_git_repo = is_git_repo,

		---Get staged diff
		---@return string|nil
		get_staged_diff = get_staged_diff,
	},
}
