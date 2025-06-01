---@class CodeCompanion.GitCommit.Git
local Git = {}

---Check if current directory is inside a git repository
---@return boolean
function Git.is_repository()
  -- First check for .git directory in current and parent directories
  local function check_git_dir(path)
    local git_path = path .. "/.git"
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
  local cmd = "git rev-parse --is-inside-work-tree"
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
    return staged_diff
  end

  -- If no staged changes and we're in amend mode, get the last commit's changes
  if Git.is_amending() then
    local last_commit_diff = vim.fn.system("git diff --no-ext-diff HEAD~1")
    if vim.v.shell_error == 0 and vim.trim(last_commit_diff) ~= "" then
      return last_commit_diff
    end

    -- Fallback: if HEAD~1 doesn't exist (initial commit), show all files
    local show_diff = vim.fn.system("git show --no-ext-diff --format= HEAD")
    if vim.v.shell_error == 0 and vim.trim(show_diff) ~= "" then
      return show_diff
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

  -- Check for staged changes first
  local staged_diff = vim.fn.system("git diff --no-ext-diff --staged")
  if vim.v.shell_error == 0 and vim.trim(staged_diff) ~= "" then
    return staged_diff, "staged"
  end

  -- Check if we're amending
  if Git.is_amending() then
    -- Try to get the last commit's diff
    local last_commit_diff = vim.fn.system("git diff --no-ext-diff HEAD~1")
    if vim.v.shell_error == 0 and vim.trim(last_commit_diff) ~= "" then
      return last_commit_diff, "amend_with_parent"
    end

    -- Fallback for initial commit amend
    local show_diff = vim.fn.system("git show --no-ext-diff --format= HEAD")
    if vim.v.shell_error == 0 and vim.trim(show_diff) ~= "" then
      return show_diff, "amend_initial"
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
        vim.notify("No staged changes found. Please stage your changes first.", vim.log.levels.ERROR)
      end
    end
    return false
  end

  -- Create temporary file for commit message
  local temp_file = vim.fn.tempname()
  local file = io.open(temp_file, "w")
  if not file then
    vim.notify("Failed to create temporary file for commit message", vim.log.levels.ERROR)
    return false
  end

  file:write(message)
  file:close()

  -- Execute appropriate git commit command
  local cmd
  if Git.is_amending() then
    cmd = string.format("git commit --amend -F %s", vim.fn.shellescape(temp_file))
  else
    cmd = string.format("git commit -F %s", vim.fn.shellescape(temp_file))
  end

  local result = vim.fn.system(cmd)
  local exit_code = vim.v.shell_error

  -- Clean up temporary file
  os.remove(temp_file)

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
