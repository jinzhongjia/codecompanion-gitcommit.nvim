local Git = require("codecompanion._extensions.gitcommit.git")
local Generator = require("codecompanion._extensions.gitcommit.generator")
local UI = require("codecompanion._extensions.gitcommit.ui")
local Buffer = require("codecompanion._extensions.gitcommit.buffer")
local Langs = require("codecompanion._extensions.gitcommit.langs")
local GitRead = require("codecompanion._extensions.gitcommit.tools.git_read")
local GitEdit = require("codecompanion._extensions.gitcommit.tools.git_edit")
local Config = require("codecompanion._extensions.gitcommit.config")

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

local function setup_tools(opts)
  if not opts.add_git_tool then
    return
  end

  local codecompanion_config = require("codecompanion.config")
  if not (codecompanion_config.strategies and codecompanion_config.strategies.chat) then
    return
  end

  codecompanion_config.strategies.chat.tools = codecompanion_config.strategies.chat.tools or {}
  local chat_tools = codecompanion_config.strategies.chat.tools

  local git_read_enabled = opts.enable_git_read
  local git_edit_enabled = opts.enable_git_edit
  local git_bot_enabled = opts.enable_git_bot and git_read_enabled and git_edit_enabled

  if git_read_enabled then
    chat_tools["git_read"] = {
      description = "Read-only Git operations (status, log, diff, etc.)",
      callback = GitRead,
      opts = {
        auto_submit_errors = opts.git_tool_auto_submit_errors,
        auto_submit_success = opts.git_tool_auto_submit_success,
      },
    }
  end

  if git_edit_enabled then
    chat_tools["git_edit"] = {
      description = "Write-access Git operations (stage, unstage, branch, etc.)",
      callback = GitEdit,
      opts = {
        auto_submit_errors = opts.git_tool_auto_submit_errors,
        auto_submit_success = opts.git_tool_auto_submit_success,
      },
    }
  end

  if git_bot_enabled then
    chat_tools.groups = chat_tools.groups or {}
    chat_tools.groups["git_bot"] = {
      description = "A Git agent that can perform read and write operations.",
      system_prompt = "You are a Git assistant. You have access to the `git_read` and `git_edit` tools to manage the git repository.",
      tools = {
        "git_read",
        "git_edit",
      },
      opts = {
        collapse_tools = true,
      },
    }
  end
end

local function create_command(name, callback, desc)
  vim.api.nvim_create_user_command(name, callback, { desc = desc })
end

local function setup_commands(opts)
  create_command("CodeCompanionGitCommit", M.generate_commit_message, "Generate Git commit message using AI")
  create_command("CCGitCommit", M.generate_commit_message, "Generate Git commit message using AI (short alias)")

  if opts.add_git_commands then
    local chat_command = function()
      require("codecompanion").chat()
    end
    create_command("CodeCompanionGit", chat_command, "Open CodeCompanion chat for Git assistance")
    create_command("CCGit", chat_command, "Open CodeCompanion chat for Git assistance (short alias)")
  end
end

local function setup_slash_commands(opts)
  if not opts.add_slash_command then
    return
  end

  local slash_commands = require("codecompanion.config").strategies.chat.slash_commands
  local Job = require("plenary.job")

  local function get_commit_content(chat, choice)
    Job:new({
      command = "git",
      args = { "show", choice.hash },
      on_exit = function(j, rv)
        local content = table.concat(j:result(), "\n")
        if rv ~= 0 or not content or content == "" then
          chat:add_reference({ role = "user", content = "Error: Failed to get commit content." }, "git", "<git_error>")
        else
          chat:add_reference({
            role = "user",
            content = string.format("Selected commit (%s) full content:\n```\n%s\n```", choice.hash, content),
          }, "git", "<git_commit>")
        end
      end,
    }):start()
  end

  local function select_commit(chat, items)
    vim.ui.select(items, {
      prompt = "Select a commit to insert:",
      format_item = function(item)
        return item.label
      end,
    }, function(choice)
      if choice then
        get_commit_content(chat, choice)
      end
    end)
  end

  local function get_commit_list(chat, opts)
    Job:new({
      command = "git",
      args = { "log", "--oneline", "-n", tostring(opts.gitcommit_select_count) },
      on_exit = function(j, rv)
        if rv ~= 0 then
          return chat:add_reference({ role = "user", content = "Error: Failed to get git log" }, "git", "<git_error>")
        end
        local output = j:result()
        if not output or #output == 0 then
          return chat:add_reference({ role = "user", content = "No commits found." }, "git", "<git_error>")
        end
        local items = {}
        for _, line in ipairs(output) do
          local hash, msg = line:match("^(%w+)%s(.+)$")
          if hash and msg then
            table.insert(items, { label = hash .. " " .. msg, hash = hash })
          end
        end
        if #items == 0 then
          return chat:add_reference({ role = "user", content = "No commits found." }, "git", "<git_error>")
        end
        vim.schedule(function()
          select_commit(chat, items)
        end)
      end,
    }):start()
  end

  slash_commands["gitcommit"] = {
    description = "Select a commit and insert its full content (message + diff)",
    callback = function(chat)
      if not Git.is_repository() then
        return chat:add_reference({ role = "user", content = "Error: Not in a git repository" }, "git", "<git_error>")
      end
      get_commit_list(chat, opts)
    end,
    opts = {
      contains_code = true,
    },
  }
end

return {
  --- @param opts CodeCompanion.GitCommit.ExtensionOpts
  setup = function(opts)
    opts = vim.tbl_deep_extend("force", Config.default_opts, opts or {})

    Git.setup({ exclude_files = opts.exclude_files })
    Generator.setup(opts.adapter, opts.model)
    Buffer.setup(opts.buffer)
    Langs.setup(opts.languages)

    setup_tools(opts)
    setup_commands(opts)
    setup_slash_commands(opts)
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
