local Git = require("codecompanion._extensions.gitcommit.git")
local Generator = require("codecompanion._extensions.gitcommit.generator")
local UI = require("codecompanion._extensions.gitcommit.ui")
local Buffer = require("codecompanion._extensions.gitcommit.buffer")
local Langs = require("codecompanion._extensions.gitcommit.langs")

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
  },
}
