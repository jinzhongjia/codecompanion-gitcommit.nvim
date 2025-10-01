local Git = require("codecompanion._extensions.gitcommit.git")
local Generator = require("codecompanion._extensions.gitcommit.generator")
local UI = require("codecompanion._extensions.gitcommit.ui")
local Buffer = require("codecompanion._extensions.gitcommit.buffer")
local Langs = require("codecompanion._extensions.gitcommit.langs")
local GitRead = require("codecompanion._extensions.gitcommit.tools.git_read")
local GitEdit = require("codecompanion._extensions.gitcommit.tools.git_edit")
local Config = require("codecompanion._extensions.gitcommit.config")

local M = {}

---Generate commit message using AI
function M.generate_commit_message()
  -- Check git repository
  if not Git.is_repository() then
    vim.notify("Not in a git repository", vim.log.levels.ERROR)
    return
  end

  -- Get changes for commit
  local diff, context = Git.get_contextual_diff()
  if not diff then
    local msg
    if context == "no_changes" then
      msg = Git.is_amending() and "No changes to amend" or "No staged changes found. Please stage your changes first."
    else
      msg = "Failed to get git changes"
    end
    vim.notify(msg, vim.log.levels.ERROR)
    return
  end

  Langs.select_lang(function(lang)
    -- Check if user cancelled language selection
    if lang == nil then
      return
    end

    vim.notify("Generating commit message...", vim.log.levels.INFO)

    -- Get commit history for context
    local commit_history = nil
    local git_config = Git.get_config()
    if git_config.use_commit_history then
      commit_history = Git.get_commit_history(git_config.commit_history_count)
    end

    -- Generate commit message
    Generator.generate_commit_message(diff, lang, commit_history, function(result, error)
      if error then
        vim.notify("Failed to generate commit message: " .. error, vim.log.levels.ERROR)
        return
      end

      if result then
        -- Show commit UI
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

  -- Add AI Release Notes tool (always available if git_read is enabled)
  if git_read_enabled then
    local AIReleaseNotes = require("codecompanion._extensions.gitcommit.tools.ai_release_notes")
    chat_tools["ai_release_notes"] = {
      description = "Generate AI-powered release notes from commit history",
      callback = AIReleaseNotes,
      opts = {
        auto_submit_errors = opts.git_tool_auto_submit_errors,
        auto_submit_success = false, -- Don't auto-submit, let AI process the prompt
      },
    }
  end

  if git_bot_enabled then
    chat_tools.groups = chat_tools.groups or {}
    chat_tools.groups["git_bot"] = {
      description = "A Git agent that can perform read and write operations.",
      system_prompt = [[You are a Git workflow specialist with expert-level knowledge of version control best practices and Git operations.

CORE RESPONSIBILITIES:
• Analyze repository state and provide comprehensive Git assistance
• Execute safe and efficient Git operations through available tools
• Guide users through complex Git workflows and troubleshooting
• Maintain repository integrity and prevent data loss

WORKFLOW APPROACH:
1. Always start with git_read to understand the current repository state
2. Analyze the situation before suggesting or executing operations
3. Explain the impact of operations before execution
4. Use git_edit only after confirming the intended changes

SAFETY PROTOCOLS:
• Never execute destructive operations (reset --hard, force push) without explicit confirmation
• Always check current branch and uncommitted changes before operations
• Warn about potential conflicts or issues before they occur
• Preserve user's work by suggesting stash or backup when appropriate

BEST PRACTICES:
• Follow conventional commits and branching strategies
• Provide clear explanations of Git concepts when needed
• Suggest appropriate Git workflows based on project type
• Help maintain clean and meaningful commit history

When responding:
- Be concise but thorough in explanations
- Use git_read first to assess the situation
- Propose operations step-by-step
- Confirm understanding before using git_edit]],
      tools = {
        "git_read",
        "git_edit",
        "ai_release_notes",
      },
      opts = {
        collapse_tools = true,
      },
    }
  end
end

local function setup_commands()
  vim.api.nvim_create_user_command(
    "CodeCompanionGitCommit",
    M.generate_commit_message,
    { desc = "Generate Git commit message using AI" }
  )
  vim.api.nvim_create_user_command(
    "CCGitCommit",
    M.generate_commit_message,
    { desc = "Generate Git commit message using AI (short alias)" }
  )
end

local function setup_slash_commands(opts)
  if not opts.add_slash_command then
    return
  end

  local slash_commands = require("codecompanion.config").strategies.chat.slash_commands

  local function get_commit_content(chat, choice)
    local stdout = vim.uv.new_pipe(false)
    local stderr = vim.uv.new_pipe(false)
    local output = ""
    local error_output = ""

    local handle = vim.uv.spawn("git", {
      args = { "show", choice.hash },
      stdio = { nil, stdout, stderr },
    }, function(code, signal)
      vim.schedule(function()
        stdout:close()
        stderr:close()
        if code == 0 then
          chat:add_context({
            role = "user",
            content = string.format("Selected commit (%s) full content:\n```\n%s\n```", choice.hash, output),
          }, "git", "<git_commit>")
        else
          chat:add_context(
            { role = "user", content = "Error: Failed to get commit content.\n" .. error_output },
            "git",
            "<git_error>"
          )
        end
      end)
    end)

    vim.uv.read_start(stdout, function(err, data)
      if err then
        return
      end
      if data then
        output = output .. data
      end
    end)

    vim.uv.read_start(stderr, function(err, data)
      if err then
        return
      end
      if data then
        error_output = error_output .. data
      end
    end)
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
    local stdout = vim.uv.new_pipe(false)
    local stderr = vim.uv.new_pipe(false)
    local output = ""
    local error_output = ""

    local handle = vim.uv.spawn("git", {
      args = { "log", "--oneline", "-n", tostring(opts.gitcommit_select_count) },
      stdio = { nil, stdout, stderr },
    }, function(code, signal)
      vim.schedule(function()
        stdout:close()
        stderr:close()
        if code == 0 then
          local lines = vim.split(output, "\n")
          local items = {}
          for _, line in ipairs(lines) do
            local hash, msg = line:match("^(%w+)%s(.+)$")
            if hash and msg then
              table.insert(items, { label = hash .. " " .. msg, hash = hash })
            end
          end
          if #items == 0 then
            return chat:add_context({ role = "user", content = "Error: No commits found." }, "git", "<git_error>")
          end
          select_commit(chat, items)
        else
          chat:add_context(
            { role = "user", content = "Error: Failed to get git log\n" .. error_output },
            "git",
            "<git_error>"
          )
        end
      end)
    end)

    vim.uv.read_start(stdout, function(err, data)
      if err then
        return
      end
      if data then
        output = output .. data
      end
    end)

    vim.uv.read_start(stderr, function(err, data)
      if err then
        return
      end
      if data then
        error_output = error_output .. data
      end
    end)
  end

  slash_commands["gitcommit"] = {
    description = "Select a commit and insert its full content (message + diff)",
    callback = function(chat)
      if not Git.is_repository() then
        return chat:add_context({ role = "user", content = "Error: Not in a git repository" }, "git", "<git_error>")
      end
      get_commit_list(chat, opts)
    end,
    opts = {
      contains_code = true,
    },
  }
end

return
--- @class CodeCompanion.Extension
{
  --- @param opts CodeCompanion.GitCommit.ExtensionOpts
  setup = function(opts)
    opts = vim.tbl_deep_extend("force", Config.default_opts, opts or {})

    Git.setup({
      exclude_files = opts.exclude_files,
      use_commit_history = opts.use_commit_history,
      commit_history_count = opts.commit_history_count,
    })
    Generator.setup(opts.adapter, opts.model)
    Buffer.setup(opts.buffer)
    Langs.setup(opts.languages)

    setup_tools(opts)
    setup_commands()
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

      -- Get commit history if enabled
      local commit_history = nil
      local git_config = Git.get_config and Git.get_config() or {}
      if git_config.use_commit_history then
        commit_history = Git.get_commit_history(git_config.commit_history_count)
      end

      -- Generate commit message
      Generator.generate_commit_message(diff, lang, commit_history, callback)
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

      ---Merge a branch
      ---@param branch string The branch to merge
      merge = function(branch)
        local GitTool = require("codecompanion._extensions.gitcommit.tools.git").GitTool
        return GitTool.merge(branch)
      end,

      ---Push changes to remote repository
      ---@param remote? string The remote to push to (e.g., origin)
      ---@param branch? string The branch to push (defaults to current branch)
      ---@param force? boolean Force push (DANGEROUS)
      ---@param set_upstream? boolean Set upstream branch (default: true for auto-linking)
      ---@param tags? boolean Push all tags
      ---@param tag_name? string Single tag to push
      push = function(remote, branch, force, set_upstream, tags, tag_name)
        local GitTool = require("codecompanion._extensions.gitcommit.tools.git").GitTool
        return GitTool.push(remote, branch, force, set_upstream, tags, tag_name)
      end,

      ---Generate release notes between tags
      ---@param from_tag? string Starting tag (if not provided, uses second latest tag)
      ---@param to_tag? string Ending tag (if not provided, uses latest tag)
      ---@param format? string Format for release notes (markdown, plain, json)
      ---@return boolean success
      ---@return string output
      ---@return string user_msg
      ---@return string llm_msg
      generate_release_notes = function(from_tag, to_tag, format)
        local GitTool = require("codecompanion._extensions.gitcommit.tools.git").GitTool
        return GitTool.generate_release_notes(from_tag, to_tag, format)
      end,
    },
  },
}
