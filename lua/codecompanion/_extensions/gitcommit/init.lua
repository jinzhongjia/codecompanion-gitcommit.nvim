local Git = require("codecompanion._extensions.gitcommit.git")
local Generator = require("codecompanion._extensions.gitcommit.generator")
local UI = require("codecompanion._extensions.gitcommit.ui")
local Buffer = require("codecompanion._extensions.gitcommit.buffer")

local M = {}

---Generate and display commit message using AI
function M.generate_commit_message()
	vim.notify("Generating commit message...", vim.log.levels.INFO)

	-- Check if we're in a git repository
	if not Git.is_repository() then
		vim.notify("Not in a git repository", vim.log.levels.ERROR)
		return
	end

	-- Get staged changes
	local diff = Git.get_staged_diff()
	if not diff then
		vim.notify("No staged changes found. Please stage your changes first.", vim.log.levels.ERROR)
		return
	end

	-- Generate commit message using LLM
	Generator.generate_commit_message(diff, function(result, error)
		if error then
			vim.notify("Failed to generate commit message: " .. error, vim.log.levels.ERROR)
			return
		end

		if result then
			-- Show interactive UI with commit options
			UI.show_commit_message(result, function(message)
				return Git.commit_changes(message)
			end)
		else
			vim.notify("Failed to generate commit message", vim.log.levels.ERROR)
		end
	end)
end

return {
	setup = function(opts)
		opts = opts or {}
		
		-- Setup buffer keymaps for gitcommit filetype
		if opts.buffer then
			Buffer.setup(opts.buffer)
		else
			-- Enable buffer keymaps by default
			Buffer.setup({})
		end

		-- Create user commands for git commit generation
		vim.api.nvim_create_user_command("CodeCompanionGitCommit", function()
			M.generate_commit_message()
		end, {
			desc = "Generate Git commit message using AI",
		})

		-- Create shorter alias command
		vim.api.nvim_create_user_command("CCGitCommit", function()
			M.generate_commit_message()
		end, {
			desc = "Generate Git commit message using AI (short alias)",
		})

		-- Add to CodeCompanion slash commands if requested
		if opts.add_slash_command then
			local slash_commands = require("codecompanion.config").strategies.chat.slash_commands
			slash_commands["gitcommit"] = {
				description = "Generate git commit message from staged changes",
				callback = function(chat)
					-- Check git repository status
					if not Git.is_repository() then
						chat:add_message({ role = "user", content = "Error: Not in a git repository" })
						return
					end

					-- Get staged changes
					local diff = Git.get_staged_diff()
					if not diff then
						chat:add_message({
							role = "user",
							content = "Error: No staged changes found. Please stage your changes first.",
						})
						return
					end

					-- Generate commit message
					Generator.generate_commit_message(diff, function(result, error)
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
		---Generate commit message programmatically (for external use)
		---@param callback fun(result: string|nil, error: string|nil)
		generate = function(callback)
			-- Check git repository status
			if not Git.is_repository() then
				return callback(nil, "Not in a git repository")
			end

			-- Get staged changes
			local diff = Git.get_staged_diff()
			if not diff then
				return callback(nil, "No staged changes found. Please stage your changes first.")
			end

			-- Generate commit message
			Generator.generate_commit_message(diff, callback)
		end,

		---Check if current directory is in a git repository
		is_git_repo = Git.is_repository,

		---Get staged changes diff
		get_staged_diff = Git.get_staged_diff,

		---Commit changes with provided message
		commit_changes = Git.commit_changes,
		
		---Get buffer configuration
		get_buffer_config = Buffer.get_config,
	},
}
