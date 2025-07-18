---@class CodeCompanion.GitCommit.Git
local Git = {}

-- Store configuration
local config = {}

function Git.setup(opts)
  config = vim.tbl_deep_extend("force", {
    exclude_files = {},
    use_commit_history = true,
    commit_history_count = 10,
  }, opts or {})
end

-- Trim whitespace from string
---@param s string The string to trim
---@return string trimmed_string
local function trim(s)
  return (s:gsub("^%s*(.-)%s*$", "%1"))
end

---Filter diff content to exclude file patterns
---@param diff_content string The original diff content
---@return string filtered_diff The filtered diff content
function Git._filter_diff(diff_content)
  if not config.exclude_files or #config.exclude_files == 0 then
    return diff_content
  end

  local lines = vim.split(diff_content, "\n")
  local filtered_lines = {}
  local all_files = {}
  local excluded_files = {}
  local current_file = nil
  local skip_current_file = false

  for _, line in ipairs(lines) do
    local file_match = line:match("^diff %-%-git a/(.*) b/")
    if file_match then
      current_file = file_match
      table.insert(all_files, current_file)
      skip_current_file = Git._should_exclude_file(current_file)
      if skip_current_file then
        table.insert(excluded_files, current_file)
      end
    end

    local plus_file = line:match("^%+%+%+ b/(.*)")
    local minus_file = line:match("^%-%-%-a/(.*)")
    if plus_file then
      current_file = plus_file
      table.insert(all_files, current_file)
      skip_current_file = Git._should_exclude_file(current_file)
      if skip_current_file then
        table.insert(excluded_files, current_file)
      end
    elseif minus_file then
      current_file = minus_file
      table.insert(all_files, current_file)
      skip_current_file = Git._should_exclude_file(current_file)
      if skip_current_file then
        table.insert(excluded_files, current_file)
      end
    end

    if not skip_current_file then
      table.insert(filtered_lines, line)
    end
  end

  -- If all files are excluded, return original diff to avoid empty output
  if #all_files > 0 and #excluded_files >= #all_files then
    return diff_content
  end

  return table.concat(filtered_lines, "\n")
end

---Check if file should be excluded by patterns
---@param filepath string The file path to check
---@return boolean should_exclude True if file should be excluded
function Git._should_exclude_file(filepath)
  if not config.exclude_files then
    return false
  end

  for _, pattern in ipairs(config.exclude_files) do
    -- Convert glob pattern to Lua pattern
    local lua_pattern = pattern:gsub("%*", ".*"):gsub("?", ".")
    if filepath:match(lua_pattern) then
      return true
    end
  end

  return false
end

function Git.is_repository()
  -- Check for .git directory in current and parent directories
  local function check_git_dir(path)
    local sep = package.config:sub(1, 1)
    local git_path = path .. sep .. ".git"
    local stat = vim.uv.fs_stat(git_path)
    return stat ~= nil
  end

  -- Search from current directory up
  local current_dir = vim.fn.getcwd()
  while current_dir do
    if check_git_dir(current_dir) then
      return true
    end

    -- Move to parent
    local parent = vim.fn.fnamemodify(current_dir, ":h")
    if parent == current_dir then
      -- Reached root
      break
    end
    current_dir = parent
  end

  local redirect = (vim.loop.os_uname().sysname == "Windows_NT") and " 2>nul" or " 2>/dev/null"
  local cmd = "git rev-parse --is-inside-work-tree" .. redirect
  local result = vim.fn.system(cmd)
  return vim.v.shell_error == 0 and vim.trim(result) == "true"
end

function Git.is_amending()
  -- Safe git operations
  local ok, result = pcall(function()
    if not Git.is_repository() then
      return false
    end

    -- Check for amend scenario by examining COMMIT_EDITMSG
    -- During amend, git pre-populates COMMIT_EDITMSG with previous commit
    local git_dir = vim.trim(vim.fn.system("git rev-parse --git-dir"))
    if vim.v.shell_error ~= 0 then
      return false
    end

    -- Use platform-appropriate separator
    local path_sep = package.config:sub(1, 1)
    local commit_editmsg = git_dir .. path_sep .. "COMMIT_EDITMSG"
    local stat = vim.uv.fs_stat(commit_editmsg)
    if not stat then
      return false
    end

    -- Verify HEAD commit exists (not initial commit)
    local redirect = (vim.uv.os_uname().sysname == "Windows_NT") and " 2>nul" or " 2>/dev/null"
    vim.fn.system("git rev-parse --verify HEAD" .. redirect)
    if vim.v.shell_error ~= 0 then
      return false
    end

    -- Read COMMIT_EDITMSG content
    -- During amend, git pre-populates this file with previous commit
    local fd = vim.uv.fs_open(commit_editmsg, "r", 438)
    if not fd then
      return false
    end

    local content = vim.uv.fs_read(fd, stat.size, 0)
    vim.uv.fs_close(fd)

    if not content then
      return false
    end

    -- Check for non-comment content in COMMIT_EDITMSG
    -- During amend, this indicates editing existing commit
    local lines = vim.split(content, "\n")
    local has_existing_message = false
    for _, line in ipairs(lines) do
      local trimmed = vim.trim(line)
      -- Skip empty lines and comments (starting with #)
      if trimmed ~= "" and not trimmed:match("^#") then
        has_existing_message = true
        break
      end
    end

    -- If COMMIT_EDITMSG has content and HEAD exists, likely amend
    return has_existing_message
  end)

  return ok and result or false
end

function Git.get_staged_diff()
  -- Safe git operations
  local ok, result = pcall(function()
    if not Git.is_repository() then
      return nil
    end

    -- Try to get staged changes
    local staged_diff = vim.fn.system("git diff --no-ext-diff --staged")
    if vim.v.shell_error == 0 and vim.trim(staged_diff) ~= "" then
      return Git._filter_diff(staged_diff)
    end

    -- If no staged changes and in amend mode, get last commit changes
    if Git.is_amending() then
      local last_commit_diff = vim.fn.system("git diff --no-ext-diff HEAD~1")
      if vim.v.shell_error == 0 and vim.trim(last_commit_diff) ~= "" then
        return Git._filter_diff(last_commit_diff)
      end

      -- Fallback for initial commit: show all files
      local show_diff = vim.fn.system("git show --no-ext-diff --format= HEAD")
      if vim.v.shell_error == 0 and vim.trim(show_diff) ~= "" then
        return Git._filter_diff(show_diff)
      end
    end

    return nil
  end)

  return ok and result or nil
end

---Get contextual diff based on current git state
---@return string|nil diff The diff content or nil if no changes
---@return string|nil context The context describing the diff type
function Git.get_contextual_diff()
  -- Safe git operations
  local ok, result = pcall(function()
    if not Git.is_repository() then
      return nil, "not_in_repo"
    end

    -- Check for staged changes
    local staged_diff = vim.fn.system("git diff --no-ext-diff --staged")
    if vim.v.shell_error == 0 and trim(staged_diff) ~= "" then
      local filtered_diff = Git._filter_diff(staged_diff)
      if trim(filtered_diff) ~= "" then
        return filtered_diff, "staged"
      else
        return nil, "no_changes_after_filter"
      end
    end

    -- Check if we're amending
    if Git.is_amending() then
      local last_commit_diff = vim.fn.system("git diff --no-ext-diff HEAD~1")
      if vim.v.shell_error == 0 and trim(last_commit_diff) ~= "" then
        local filtered_diff = Git._filter_diff(last_commit_diff)
        if trim(filtered_diff) ~= "" then
          return filtered_diff, "amend_with_parent"
        end
      end

      -- Fallback for initial commit: show all files
      local show_diff = vim.fn.system("git show --no-ext-diff --format= HEAD")
      if vim.v.shell_error == 0 and trim(show_diff) ~= "" then
        local filtered_diff = Git._filter_diff(show_diff)
        if trim(filtered_diff) ~= "" then
          return filtered_diff, "amend_initial"
        end
      end
    end

    local all_local_diff = vim.fn.system("git diff --no-ext-diff HEAD")
    if vim.v.shell_error == 0 and trim(all_local_diff) ~= "" then
      local filtered_diff = Git._filter_diff(all_local_diff)
      if trim(filtered_diff) ~= "" then
        return filtered_diff, "unstaged_or_all_local"
      else
        return nil, "no_changes_after_filter"
      end
    end

    return nil, "no_changes"
  end)

  if not ok then
    return nil, "git_operation_failed"
  end

  return result
end

function Git.commit_changes(message)
  -- Safe git operations
  local ok, success = pcall(function()
    if not Git.is_repository() then
      vim.notify("Not in a git repository", vim.log.levels.ERROR)
      return false
    end

    -- Check for changes to commit
    local diff, context = Git.get_contextual_diff()
    if not diff then
      if context == "no_changes" then
        if Git.is_amending() then
          vim.notify("No changes to amend. The commit already exists.", vim.log.levels.WARN)
        else
          vim.notify(
            "No changes found to commit. Please stage your changes or ensure there are unstaged changes in your working directory.",
            vim.log.levels.ERROR
          )
        end
      elseif context == "git_operation_failed" then
        vim.notify("Git operation failed. Please check your git repository.", vim.log.levels.ERROR)
      end
      return false
    end

    -- Pass commit message via stdin
    local cmd
    if Git.is_amending() then
      cmd = "git commit --amend -F -"
    else
      cmd = "git commit -F -"
    end

    local result = vim.fn.system(cmd, message)
    local exit_code = vim.v.shell_error

    if exit_code == 0 then
      local action = Git.is_amending() and "amended" or "committed"
      vim.notify(string.format("Successfully %s changes!", action), vim.log.levels.INFO)
      return true
    else
      local error_msg = vim.trim(result)
      if error_msg == "" then
        error_msg = "Unknown error occurred during commit"
      end
      vim.notify("Failed to commit: " .. error_msg, vim.log.levels.ERROR)
      return false
    end
  end)

  if not ok then
    vim.notify("Git commit operation failed unexpectedly", vim.log.levels.ERROR)
    return false
  end

  return success
end

---Get recent commit messages for context
---@param count? number Number of recent commits to retrieve (default: 10)
---@return string[]|nil commit_messages Array of commit messages or nil on error
function Git.get_commit_history(count)
  count = count or 10

  -- Safe git operations
  local ok, result = pcall(function()
    if not Git.is_repository() then
      return nil
    end

    -- Get recent commit messages with git log
    -- Use --pretty=format to get just commit messages
    local cmd = string.format("git log --pretty=format:%%s --no-merges -%d", count)
    local output = vim.fn.system(cmd)

    if vim.v.shell_error ~= 0 then
      return nil
    end

    -- Split output into lines and filter empty lines
    local lines = vim.split(output, "\n")
    local commit_messages = {}

    for _, line in ipairs(lines) do
      local trimmed = trim(line)
      if trimmed ~= "" then
        table.insert(commit_messages, trimmed)
      end
    end

    return commit_messages
  end)

  if not ok then
    return nil
  end

  return result
end

---Get current configuration
---@return table config Current configuration
function Git.get_config()
  return vim.deepcopy(config)
end

return Git
