local M = {}

---Git tool for CodeCompanion GitCommit extension
---Provides git operations like status, diff, log, branch management etc.
---@class CodeCompanion.GitCommit.Tools.Git
local GitTool = {
  name = "git_operations",
  description = "Execute git operations and commands",
}

---Check if we're in a git repository
---@return boolean
local function is_git_repo()
  -- 使用 Neovim 内置 vim.fn.system 代替 io.popen
  local cmd = "git rev-parse --is-inside-work-tree"
  local result = vim.fn.system(cmd)
  return vim.v.shell_error == 0 and result:match("true") ~= nil
end

---Execute git command safely
---@param cmd string The git command to execute
---@return boolean success, string output
local function execute_git_command(cmd)
  if not is_git_repo() then
    return false, "Not in a git repository"
  end

  local output = vim.fn.system(cmd)
  local exit_code = vim.v.shell_error

  if exit_code ~= 0 or (output and output:match("fatal: ")) then
    return false, output
  end
  return true, output or ""
end

---Get git status
---@return boolean success, string output
function GitTool.get_status()
  return execute_git_command("git status --porcelain")
end

---Get git log with specified format and count
---@param count? number Number of commits to show (default: 10)
---@param format? string Log format (default: oneline)
---@return boolean success, string output
function GitTool.get_log(count, format)
  count = count or 10
  format = format or "oneline"

  local cmd = string.format("git log -%d --%s", count, format)
  return execute_git_command(cmd)
end

---Get git diff for staged or unstaged changes
---@param staged? boolean Whether to get staged changes (default: false)
---@param file? string Specific file to diff (optional)
---@return boolean success, string output
function GitTool.get_diff(staged, file)
  local cmd = "git diff"

  if staged then
    cmd = cmd .. " --cached"
  end

  if file then
    cmd = cmd .. " " .. vim.fn.shellescape(file)
  end

  return execute_git_command(cmd)
end

---Get current branch name
---@return boolean success, string branch_name
function GitTool.get_current_branch()
  return execute_git_command("git branch --show-current")
end

---Get all branches (local and remote)
---@param remote_only? boolean Show only remote branches
---@return boolean success, string output
function GitTool.get_branches(remote_only)
  local cmd = remote_only and "git branch -r" or "git branch -a"
  return execute_git_command(cmd)
end

---Stage files
---@param files string|table Files to stage, can be string or table of strings
---@return boolean success, string output
function GitTool.stage_files(files)
  if type(files) == "string" then
    files = { files }
  end

  local escaped_files = {}
  for _, file in ipairs(files) do
    table.insert(escaped_files, vim.fn.shellescape(file))
  end

  local cmd = "git add " .. table.concat(escaped_files, " ")
  return execute_git_command(cmd)
end

---Unstage files
---@param files string|table Files to unstage, can be string or table of strings
---@return boolean success, string output
function GitTool.unstage_files(files)
  if type(files) == "string" then
    files = { files }
  end

  local escaped_files = {}
  for _, file in ipairs(files) do
    table.insert(escaped_files, vim.fn.shellescape(file))
  end

  local cmd = "git reset HEAD " .. table.concat(escaped_files, " ")
  return execute_git_command(cmd)
end

---Create a new branch
---@param branch_name string Name of the new branch
---@param checkout? boolean Whether to checkout the new branch (default: true)
---@return boolean success, string output
function GitTool.create_branch(branch_name, checkout)
  checkout = checkout ~= false -- default to true

  local cmd = checkout and "git checkout -b " or "git branch "
  cmd = cmd .. vim.fn.shellescape(branch_name)

  return execute_git_command(cmd)
end

---Checkout branch or commit
---@param target string Branch name or commit hash
---@return boolean success, string output
function GitTool.checkout(target)
  local cmd = "git checkout " .. vim.fn.shellescape(target)
  return execute_git_command(cmd)
end

---Get remote information
---@return boolean success, string output
function GitTool.get_remotes()
  return execute_git_command("git remote -v")
end

---Show commit details
---@param commit_hash? string Commit hash (default: HEAD)
---@return boolean success, string output
function GitTool.show_commit(commit_hash)
  commit_hash = commit_hash or "HEAD"
  local cmd = "git show " .. vim.fn.shellescape(commit_hash)
  return execute_git_command(cmd)
end

---Get blame information for a file
---@param file_path string Path to the file
---@param line_start? number Start line number
---@param line_end? number End line number
---@return boolean success, string output
function GitTool.get_blame(file_path, line_start, line_end)
  local cmd = "git blame " .. vim.fn.shellescape(file_path)

  if line_start and line_end then
    cmd = cmd .. " -L " .. line_start .. "," .. line_end
  elseif line_start then
    cmd = cmd .. " -L " .. line_start .. ",+10"
  end

  return execute_git_command(cmd)
end

---Stash changes
---@param message? string Stash message
---@param include_untracked? boolean Include untracked files
---@return boolean success, string output
function GitTool.stash(message, include_untracked)
  local cmd = "git stash"

  if include_untracked then
    cmd = cmd .. " -u"
  end

  if message then
    cmd = cmd .. " -m " .. vim.fn.shellescape(message)
  end

  return execute_git_command(cmd)
end

---List stashes
---@return boolean success, string output
function GitTool.list_stashes()
  return execute_git_command("git stash list")
end

---Apply stash
---@param stash_ref? string Stash reference (default: stash@{0})
---@return boolean success, string output
function GitTool.apply_stash(stash_ref)
  stash_ref = stash_ref or "stash@{0}"
  local cmd = "git stash apply " .. vim.fn.shellescape(stash_ref)
  return execute_git_command(cmd)
end

---Reset to a specific commit
---@param commit_hash string Commit hash or reference
---@param mode? string Reset mode (soft, mixed, hard)
---@return boolean success, string output
function GitTool.reset(commit_hash, mode)
  mode = mode or "mixed"
  local cmd = string.format("git reset --%s %s", mode, vim.fn.shellescape(commit_hash))
  return execute_git_command(cmd)
end

---Get file changes between commits
---@param commit1 string First commit
---@param commit2? string Second commit (default: HEAD)
---@param file_path? string Specific file path
---@return boolean success, string output
function GitTool.diff_commits(commit1, commit2, file_path)
  commit2 = commit2 or "HEAD"

  local cmd = string.format("git diff %s %s", vim.fn.shellescape(commit1), vim.fn.shellescape(commit2))

  if file_path then
    cmd = cmd .. " -- " .. vim.fn.shellescape(file_path)
  end

  return execute_git_command(cmd)
end

---Get contributors/authors
---@param count? number Number of top contributors to show
---@return boolean success, string output
function GitTool.get_contributors(count)
  count = count or 10
  local head_cmd
  if vim.loop.os_uname().sysname == "Windows_NT" then
    -- Use PowerShell for head equivalent
    head_cmd = string.format("git shortlog -sn | Select-Object -First %d", count)
  else
    head_cmd = string.format("git shortlog -sn | head -%d", count)
  end
  return execute_git_command(head_cmd)
end

---Search commits by message
---@param pattern string Search pattern
---@param count? number Maximum number of results
---@return boolean success, string output
function GitTool.search_commits(pattern, count)
  count = count or 20
  local cmd = string.format("git log --grep=%s --oneline -%d", vim.fn.shellescape(pattern), count)
  return execute_git_command(cmd)
end

M.GitTool = GitTool
return M
