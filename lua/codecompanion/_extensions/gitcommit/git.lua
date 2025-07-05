---@class CodeCompanion.GitCommit.Git
local Git = {}

-- Store configuration
local config = {}

---Setup Git module with configuration
---@param opts? table Configuration options
function Git.setup(opts)
  config = vim.tbl_deep_extend("force", {
    exclude_files = {},
  }, opts or {})
end

---Filter diff content to exclude specified file patterns
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

  -- 如果所有涉及的文件都被排除，则返回原始 diff
  if #all_files > 0 and #excluded_files == #all_files then
    return diff_content
  end

  return table.concat(filtered_lines, "\n")
end

---Check if file should be excluded based on patterns
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

---Check if current directory is inside a git repository
---@return boolean
function Git.is_repository()
  -- First check for .git directory in current and parent directories
  local function check_git_dir(path)
    local sep = package.config:sub(1, 1)
    local git_path = path .. sep .. ".git"
    local stat = vim.uv.fs_stat(git_path)
    return stat ~= nil
  end

  -- Search from current directory upwards
  local current_dir = vim.fn.getcwd()
  while current_dir do
    if check_git_dir(current_dir) then
      return true
    end

    -- Move to parent directory
    local parent = vim.fn.fnamemodify(current_dir, ":h")
    if parent == current_dir then
      -- Reached root directory
      break
    end
    current_dir = parent
  end

  -- Fallback to git command if filesystem check fails
  local redirect = (vim.loop.os_uname().sysname == "Windows_NT") and " 2>nul" or " 2>/dev/null"
  local cmd = "git rev-parse --is-inside-work-tree" .. redirect
  local result = vim.fn.system(cmd)
  return vim.v.shell_error == 0 and vim.trim(result) == "true"
end

---Check if currently in git commit --amend state
---@return boolean
function Git.is_amending()
  if not Git.is_repository() then
    return false
  end

  -- Check if COMMIT_EDITMSG exists and we're in a rebase/merge state
  local git_dir = vim.fn.system("git rev-parse --git-dir"):gsub("\n", "")
  if vim.v.shell_error ~= 0 then
    return false
  end

  -- Check for COMMIT_EDITMSG file which indicates we're editing a commit
  local commit_editmsg = git_dir .. "/COMMIT_EDITMSG"
  local stat = vim.uv.fs_stat(commit_editmsg)
  if not stat then
    return false
  end

  -- Additional check: see if we have HEAD commit (not initial commit)
  local head_check = vim.fn.system("git rev-parse --verify HEAD")
  return vim.v.shell_error == 0
end

---Get git diff for staged changes or last commit (for amend)
---@return string|nil diff The changes diff, nil if no changes or error
function Git.get_staged_diff()
  if not Git.is_repository() then
    return nil
  end

  -- First try to get staged changes
  local staged_diff = vim.fn.system("git diff --no-ext-diff --staged")
  if vim.v.shell_error == 0 and vim.trim(staged_diff) ~= "" then
    return Git._filter_diff(staged_diff)
  end

  -- If no staged changes and we're in amend mode, get the last commit's changes
  if Git.is_amending() then
    local last_commit_diff = vim.fn.system("git diff --no-ext-diff HEAD~1")
    if vim.v.shell_error == 0 and vim.trim(last_commit_diff) ~= "" then
      return Git._filter_diff(last_commit_diff)
    end

    -- Fallback: if HEAD~1 doesn't exist (initial commit), show all files
    local show_diff = vim.fn.system("git show --no-ext-diff --format= HEAD")
    if vim.v.shell_error == 0 and vim.trim(show_diff) ~= "" then
      return Git._filter_diff(show_diff)
    end
  end

  return nil
end

---Get contextual diff based on current git state
---@return string|nil diff The relevant diff, nil if no changes
---@return string context The context of what diff represents
function Git.get_contextual_diff()
  if not Git.is_repository() then
    return nil, "not_in_repo"
  end

  local function trim(s)
    return (s:gsub("^%s*(.-)%s*$", "%1"))
  end

  -- Check for staged changes first
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
end

---Commit changes with the provided message
---@param message string The commit message
---@return boolean success True if commit was successful, false otherwise
function Git.commit_changes(message)
  if not Git.is_repository() then
    vim.notify("Not in a git repository", vim.log.levels.ERROR)
    return false
  end

  -- Check if there are changes to commit
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
    end
    return false
  end

  -- Pass commit message directly through stdin without temporary files
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
end

return Git
