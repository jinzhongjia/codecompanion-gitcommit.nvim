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

---Get git diff for staged changes
---@return string|nil diff The staged changes diff, nil if no changes or error
function Git.get_staged_diff()
  if not Git.is_repository() then
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

---Commit changes with the provided message
---@param message string The commit message
---@return boolean success True if commit was successful, false otherwise
function Git.commit_changes(message)
  if not Git.is_repository() then
    vim.notify("Not in a git repository", vim.log.levels.ERROR)
    return false
  end

  -- Check if there are staged changes
  local diff = Git.get_staged_diff()
  if not diff then
    vim.notify("No staged changes found. Please stage your changes first.", vim.log.levels.ERROR)
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

return Git
