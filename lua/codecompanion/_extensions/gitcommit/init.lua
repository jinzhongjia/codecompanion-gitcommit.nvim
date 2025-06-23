local Git = require("codecompanion._extensions.gitcommit.git")
local Generator = require("codecompanion._extensions.gitcommit.generator")
local UI = require("codecompanion._extensions.gitcommit.ui")
local Buffer = require("codecompanion._extensions.gitcommit.buffer")
local Langs = require("codecompanion._extensions.gitcommit.langs")
local GitBot = require("codecompanion._extensions.gitcommit.tools.git_bot")

local M = {}

---Generate and display commit message using AI
function M.generate_commit_message()
  vim.notify("Generating commit message...", vim.log.levels.INFO)

  -- Check if we're in a git repository
  if not Git.is_repository() then
    vim.notify("Not in a git repository", vim.log.levels.ERROR)
    return
  end

  -- Get relevant changes (staged or amend)
  local diff, context = Git.get_contextual_diff()
  if not diff then
    local msg = context == "no_changes"
        and (Git.is_amending() and "No changes to amend" or "No staged changes found. Please stage your changes first.")
      or "Failed to get git changes"
    vim.notify(msg, vim.log.levels.ERROR)
    return
  end

  Langs.select_lang(function(lang)
    -- Generate commit message using LLM
    Generator.generate_commit_message(diff, lang, function(result, error)
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
  end)
end

return {
  --- @param opts CodeCompanion.GitCommit.ExtensionOpts
  setup = function(opts)
    opts = opts or {}

    -- Setup Git module with file exclusion configuration
    Git.setup({
      exclude_files = opts.exclude_files,
    })

    -- Setup generator with adapter and model configuration
    Generator.setup(opts.adapter, opts.model)

    -- Setup buffer keymaps for gitcommit filetype
    if opts.buffer then
      Buffer.setup(opts.buffer)
    else
      -- Enable buffer keymaps by default
      Buffer.setup()
    end

    Langs.setup(opts.languages)

    -- Add git_bot tool to CodeCompanion tools if enabled
    if opts.add_git_tool ~= false then
      local codecompanion_config = require("codecompanion.config")
      if codecompanion_config.strategies and codecompanion_config.strategies.chat then
        -- Add git_bot tool to chat tools
        codecompanion_config.strategies.chat.tools = codecompanion_config.strategies.chat.tools or {}
        codecompanion_config.strategies.chat.tools["git_bot"] = {
          description = "Advanced Git operations and assistance",
          callback = GitBot,
          opts = {
            auto_submit_errors = opts.git_tool_auto_submit_errors or false,
            auto_submit_success = opts.git_tool_auto_submit_success or false,
          },
        }
      end
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

    -- Add command for interactive git operations
    if opts.add_git_commands ~= false then
      vim.api.nvim_create_user_command("CodeCompanionGit", function()
        -- Open chat buffer with git_bot tool pre-loaded
        local chat = require("codecompanion").chat()
        if chat then
          -- Add git_bot tool to the chat
          vim.schedule(function()
            local chat_buffer = vim.api.nvim_get_current_buf()
            if vim.api.nvim_buf_is_valid(chat_buffer) then
              -- Insert @git_bot at the cursor position
              local cursor = vim.api.nvim_win_get_cursor(0)
              local line = cursor[1] - 1
              local col = cursor[2]
              local current_line = vim.api.nvim_buf_get_lines(chat_buffer, line, line + 1, false)[1] or ""
              local new_line = current_line:sub(1, col) .. "@git_bot " .. current_line:sub(col + 1)
              vim.api.nvim_buf_set_lines(chat_buffer, line, line + 1, false, { new_line })
              vim.api.nvim_win_set_cursor(0, { line + 1, col + 9 })
            end
          end)
        end
      end, {
        desc = "Open CodeCompanion chat with Git assistance",
      })

      -- Add shorter alias
      vim.api.nvim_create_user_command("CCGit", function()
        vim.cmd("CodeCompanionGit")
      end, {
        desc = "Open CodeCompanion chat with Git assistance (short alias)",
      })
    end
    -- Add to CodeCompanion slash commands if requested
    if opts.add_slash_command then
      local slash_commands = require("codecompanion.config").strategies.chat.slash_commands
      slash_commands["gitcommit"] = {
        description = "Generate git commit message from staged changes",
        callback = function(chat)
          -- Check git repository status
          if not Git.is_repository() then
            chat:add_reference({ role = "user", content = "Error: Not in a git repository" }, "git", "<git_error>")
            return
          end

          -- Get staged changes
          local diff = Git.get_staged_diff()
          if not diff then
            chat:add_reference({
              role = "user",
              content = "Error: No staged changes found. Please stage your changes first.",
            }, "git", "<git_error>")
            return
          end

          Langs.select_lang(function(lang)
            -- Generate commit message
            Generator.generate_commit_message(diff, lang, function(result, error)
              if error then
                chat:add_reference({ role = "user", content = "Error: " .. error }, "git", "<git_error>")
              else
                chat:add_reference({
                  role = "user",
                  content = "Generated commit message:\n```\n" .. result .. "\n```",
                }, "git", "<git_commit>")
              end
            end)
          end)
        end,
        opts = {
          contains_code = true,
        },
      }
    end
  end,

  exports = {
    ---Generate commit message programmatically (for external use)
    ---@param lang string|nil Language to generate commit message in (optional)
    ---@param callback fun(result: string|nil, error: string|nil)
    generate = function(lang, callback)
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
      Generator.generate_commit_message(diff, lang, callback)
    end,

    ---Check if current directory is in a git repository
    is_git_repo = Git.is_repository,

    ---Get staged changes diff
    get_staged_diff = Git.get_staged_diff,

    ---Commit changes with provided message
    commit_changes = Git.commit_changes,

    ---Get buffer configuration
    get_buffer_config = Buffer.get_config,

    ---Access to git tool functions
    git_tool = {
      ---Get git status
      status = function()
        local GitTool = require("codecompanion._extensions.gitcommit.tools.git").GitTool
        return GitTool.get_status()
      end,
      
      ---Get git log
      ---@param count? number Number of commits
      ---@param format? string Log format
      log = function(count, format)
        local GitTool = require("codecompanion._extensions.gitcommit.tools.git").GitTool
        return GitTool.get_log(count, format)
      end,
      
      ---Get git diff
      ---@param staged? boolean Show staged changes
      ---@param file? string Specific file
      diff = function(staged, file)
        local GitTool = require("codecompanion._extensions.gitcommit.tools.git").GitTool
        return GitTool.get_diff(staged, file)
      end,
      
      ---Get current branch
      current_branch = function()
        local GitTool = require("codecompanion._extensions.gitcommit.tools.git").GitTool
        return GitTool.get_current_branch()
      end,
      
      ---Get all branches
      ---@param remote_only? boolean Show only remote branches
      branches = function(remote_only)
        local GitTool = require("codecompanion._extensions.gitcommit.tools.git").GitTool
        return GitTool.get_branches(remote_only)
      end,
      
      ---Stage files
      ---@param files string|table Files to stage
      stage = function(files)
        local GitTool = require("codecompanion._extensions.gitcommit.tools.git").GitTool
        return GitTool.stage_files(files)
      end,
      
      ---Unstage files
      ---@param files string|table Files to unstage
      unstage = function(files)
        local GitTool = require("codecompanion._extensions.gitcommit.tools.git").GitTool
        return GitTool.unstage_files(files)
      end,
      
      ---Create new branch
      ---@param branch_name string Name of new branch
      ---@param checkout? boolean Whether to checkout
      create_branch = function(branch_name, checkout)
        local GitTool = require("codecompanion._extensions.gitcommit.tools.git").GitTool
        return GitTool.create_branch(branch_name, checkout)
      end,
      
      ---Checkout branch or commit
      ---@param target string Branch or commit to checkout
      checkout = function(target)
        local GitTool = require("codecompanion._extensions.gitcommit.tools.git").GitTool
        return GitTool.checkout(target)
      end,
      
      ---Get remotes
      remotes = function()
        local GitTool = require("codecompanion._extensions.gitcommit.tools.git").GitTool
        return GitTool.get_remotes()
      end,
      
      ---Show commit details
      ---@param commit_hash? string Commit hash
      show = function(commit_hash)
        local GitTool = require("codecompanion._extensions.gitcommit.tools.git").GitTool
        return GitTool.show_commit(commit_hash)
      end,
      
      ---Get blame for file
      ---@param file_path string File path
      ---@param line_start? number Start line
      ---@param line_end? number End line  
      blame = function(file_path, line_start, line_end)
        local GitTool = require("codecompanion._extensions.gitcommit.tools.git").GitTool
        return GitTool.get_blame(file_path, line_start, line_end)
      end,
      
      ---Stash changes
      ---@param message? string Stash message
      ---@param include_untracked? boolean Include untracked files
      stash = function(message, include_untracked)
        local GitTool = require("codecompanion._extensions.gitcommit.tools.git").GitTool
        return GitTool.stash(message, include_untracked)
      end,
      
      ---List stashes
      stash_list = function()
        local GitTool = require("codecompanion._extensions.gitcommit.tools.git").GitTool
        return GitTool.list_stashes()
      end,
      
      ---Apply stash
      ---@param stash_ref? string Stash reference
      apply_stash = function(stash_ref)
        local GitTool = require("codecompanion._extensions.gitcommit.tools.git").GitTool
        return GitTool.apply_stash(stash_ref)
      end,
      
      ---Reset to commit
      ---@param commit_hash string Commit hash
      ---@param mode? string Reset mode (soft, mixed, hard)
      reset = function(commit_hash, mode)
        local GitTool = require("codecompanion._extensions.gitcommit.tools.git").GitTool
        return GitTool.reset(commit_hash, mode)
      end,
      
      ---Compare commits
      ---@param commit1 string First commit
      ---@param commit2? string Second commit
      ---@param file_path? string Specific file
      diff_commits = function(commit1, commit2, file_path)
        local GitTool = require("codecompanion._extensions.gitcommit.tools.git").GitTool
        return GitTool.diff_commits(commit1, commit2, file_path)
      end,
      
      ---Get top contributors
      ---@param count? number Number of contributors
      contributors = function(count)
        local GitTool = require("codecompanion._extensions.gitcommit.tools.git").GitTool
        return GitTool.get_contributors(count)
      end,
      
      ---Search commits by message
      ---@param pattern string Search pattern
      ---@param count? number Max results
      search_commits = function(pattern, count)
        local GitTool = require("codecompanion._extensions.gitcommit.tools.git").GitTool
        return GitTool.search_commits(pattern, count)
      end,
    },
  },
}
