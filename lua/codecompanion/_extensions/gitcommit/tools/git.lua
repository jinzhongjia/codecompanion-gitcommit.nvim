local M = {}

---Git tool for CodeCompanion GitCommit extension
---Provides git operations like status, diff, log, branch management etc.
---@class CodeCompanion.GitCommit.Tools.Git
local GitTool = {
  name = "git_operations",
  description = "Execute git operations and commands",
}

--- Get the path to the .gitignore file in the current git repo root
local function get_gitignore_path()
  local git_dir = vim.fn.system("git rev-parse --show-toplevel"):gsub("\n", "")
  if vim.v.shell_error ~= 0 or not git_dir or git_dir == "" then
    return nil
  end
  local sep = package.config:sub(1, 1)
  return git_dir .. sep .. ".gitignore"
end

--- Read .gitignore content
function GitTool.get_gitignore()
  local path = get_gitignore_path()
  if not path then
    return false, ".gitignore not found (not in a git repo)"
  end
  local stat = vim.uv.fs_stat(path)
  if not stat then
    return true, "" -- treat as empty if not exists
  end
  local fd = vim.uv.fs_open(path, "r", 438)
  if not fd then
    return false, "Failed to open .gitignore for reading"
  end
  local data = vim.uv.fs_read(fd, stat.size, 0)
  vim.uv.fs_close(fd)
  return true, data or ""
end

--- Add rule(s) to .gitignore (no duplicates)
function GitTool.add_gitignore_rule(rule)
  local path = get_gitignore_path()
  if not path then
    return false, ".gitignore not found (not in a git repo)"
  end
  local rules = type(rule) == "table" and rule or { rule }
  local stat = vim.uv.fs_stat(path)
  local lines = {}
  if stat then
    local fd = vim.uv.fs_open(path, "r", 438)
    if fd then
      local data = vim.uv.fs_read(fd, stat.size, 0)
      vim.uv.fs_close(fd)
      if data then
        for line in data:gmatch("([^\r\n]+)") do
          table.insert(lines, line)
        end
      end
    end
  end
  local set = {}
  for _, l in ipairs(lines) do
    set[l] = true
  end
  local added = {}
  for _, r in ipairs(rules) do
    if not set[r] then
      table.insert(lines, r)
      set[r] = true
      table.insert(added, r)
    end
  end
  local fdw = vim.uv.fs_open(path, "w", 420)
  if not fdw then
    return false, "Failed to open .gitignore for writing"
  end
  vim.uv.fs_write(fdw, table.concat(lines, "\n") .. "\n", 0)
  vim.uv.fs_close(fdw)
  if #added == 0 then
    return true, "No new rule added (already present)"
  end
  return true, "Added rule(s): " .. table.concat(added, ", ")
end

--- Remove rule(s) from .gitignore
function GitTool.remove_gitignore_rule(rule)
  local path = get_gitignore_path()
  if not path then
    return false, ".gitignore not found (not in a git repo)"
  end
  local rules = type(rule) == "table" and rule or { rule }
  local stat = vim.uv.fs_stat(path)
  if not stat then
    return false, ".gitignore does not exist"
  end
  local fd = vim.uv.fs_open(path, "r", 438)
  if not fd then
    return false, "Failed to open .gitignore for reading"
  end
  local data = vim.uv.fs_read(fd, stat.size, 0)
  vim.uv.fs_close(fd)
  if not data then
    return false, "Failed to read .gitignore"
  end
  local lines = {}
  local removed = {}
  local rule_set = {}
  for _, r in ipairs(rules) do
    rule_set[r] = true
  end
  for line in data:gmatch("([^\r\n]+)") do
    if rule_set[line] then
      table.insert(removed, line)
    else
      table.insert(lines, line)
    end
  end
  local fdw = vim.uv.fs_open(path, "w", 420)
  if not fdw then
    return false, "Failed to open .gitignore for writing"
  end
  vim.uv.fs_write(fdw, table.concat(lines, "\n") .. "\n", 0)
  vim.uv.fs_close(fdw)
  if #removed == 0 then
    return true, "No rule removed (not present)"
  end
  return true, "Removed rule(s): " .. table.concat(removed, ", ")
end

--- Check if a file is ignored by .gitignore
function GitTool.is_ignored(file)
  if not file or file == "" then
    return false, "No file specified"
  end
  local ok, result = pcall(function()
    return vim.fn.system({ "git", "check-ignore", file })
  end)
  if not ok or vim.v.shell_error ~= 0 then
    return false, "File is not ignored or not in a git repo"
  end
  return true, vim.trim(result)
end

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
---@return boolean success, string output, string user_msg, string llm_msg
function GitTool.get_status()
  local success, output = execute_git_command("git status --porcelain")
  local user_msg, llm_msg
  if success then
    if output and vim.trim(output) ~= "" then
      local msg = "git status tool execute successfully\n```\n" .. output .. "\n```"
      user_msg = msg
      llm_msg = "<gitStatusTool>" .. msg .. "</gitStatusTool>"
    else
      user_msg = "git status tool execute successfully"
      llm_msg = "<gitStatusTool>success</gitStatusTool>"
    end
  else
    user_msg = "git status tool execute failed"
    llm_msg = "<gitStatusTool>fail: " .. (output or "unknown error") .. "</gitStatusTool>"
  end
  return success, output, user_msg, llm_msg
end

---Get git log with specified format and count
---@param count? number Number of commits to show (default: 10)
---@param format? string Log format (default: oneline)
---@return boolean success, string output, string user_msg, string llm_msg
function GitTool.get_log(count, format)
  count = count or 10
  format = format or "oneline"
  local format_map = {
    oneline = "--oneline",
    short = "--pretty=short",
    medium = "--pretty=medium",
    full = "--pretty=full",
    fuller = "--pretty=fuller",
    format = "--pretty=format",
  }
  local format_option = format_map[format] or "--oneline"
  local cmd = string.format("git log -%d %s", count, format_option)
  local success, output = execute_git_command(cmd)
  local user_msg, llm_msg
  if success then
    if output and vim.trim(output) ~= "" then
      local msg = "git log tool execute successfully\n```\n" .. output .. "\n```"
      user_msg = msg
      llm_msg = "<gitLogTool>" .. msg .. "</gitLogTool>"
    else
      user_msg = "git log tool execute successfully"
      llm_msg = "<gitLogTool>success</gitLogTool>"
    end
  else
    user_msg = "git log tool execute failed"
    llm_msg = "<gitLogTool>fail: " .. (output or "unknown error") .. "</gitLogTool>"
  end
  return success, output, user_msg, llm_msg
end

---Get git diff for staged or unstaged changes
---@param staged? boolean Whether to get staged changes (default: false)
---@param file? string Specific file to diff (optional)
---@return boolean success, string output, string user_msg, string llm_msg
function GitTool.get_diff(staged, file)
  local cmd = "git diff"
  if staged then
    cmd = cmd .. " --cached"
  end
  if file then
    cmd = cmd .. " " .. vim.fn.shellescape(file)
  end
  local success, output = execute_git_command(cmd)
  local user_msg, llm_msg
  if success then
    if output and vim.trim(output) ~= "" then
      local msg = "git diff tool execute successfully\n```\n" .. output .. "\n```"
      user_msg = msg
      llm_msg = "<gitDiffTool>" .. msg .. "</gitDiffTool>"
    else
      user_msg = "git diff tool execute successfully"
      llm_msg = "<gitDiffTool>success</gitDiffTool>"
    end
  else
    user_msg = "git diff tool execute failed"
    llm_msg = "<gitDiffTool>fail: " .. (output or "unknown error") .. "</gitDiffTool>"
  end
  return success, output, user_msg, llm_msg
end

---Get current branch name
---@return boolean success, string branch_name

function GitTool.get_current_branch()
  local success, output = execute_git_command("git branch --show-current")
  local user_msg, llm_msg
  if success then
    if output and vim.trim(output) ~= "" then
      local msg = "git branch tool execute successfully\n```\n" .. output .. "\n```"
      user_msg = msg
      llm_msg = "<gitBranchTool>" .. msg .. "</gitBranchTool>"
    else
      user_msg = "git branch tool execute successfully"
      llm_msg = "<gitBranchTool>success</gitBranchTool>"
    end
  else
    user_msg = "git branch tool execute failed"
    llm_msg = "<gitBranchTool>fail: " .. (output or "unknown error") .. "</gitBranchTool>"
  end
  return success, output, user_msg, llm_msg
end

---Get all branches (local and remote)
---@param remote_only? boolean Show only remote branches
---@return boolean success, string output, string user_msg, string llm_msg
function GitTool.get_branches(remote_only)
  local cmd = remote_only and "git branch -r" or "git branch -a"
  local success, output = execute_git_command(cmd)
  local user_msg, llm_msg
  if success then
    if output and vim.trim(output) ~= "" then
      local msg = "git branch tool execute successfully\n```\n" .. output .. "\n```"
      user_msg = msg
      llm_msg = "<gitBranchTool>" .. msg .. "</gitBranchTool>"
    else
      user_msg = "git branch tool execute successfully"
      llm_msg = "<gitBranchTool>success</gitBranchTool>"
    end
  else
    user_msg = "git branch tool execute failed"
    llm_msg = "<gitBranchTool>fail: " .. (output or "unknown error") .. "</gitBranchTool>"
  end
  return success, output, user_msg, llm_msg
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

---Commit staged changes
---@param message string Commit message
---@param amend? boolean Whether to amend the last commit (default: false)
---@return boolean success, string output
function GitTool.commit(message, amend)
  if not message or vim.trim(message) == "" then
    return false, "Commit message is required"
  end

  local cmd = "git commit"
  if amend then
    cmd = cmd .. " --amend"
  end
  cmd = cmd .. " -m " .. vim.fn.shellescape(message)

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
---@return boolean success, string output, string user_msg, string llm_msg
function GitTool.get_remotes()
  local success, output = execute_git_command("git remote -v")
  local user_msg, llm_msg
  if success then
    if output and vim.trim(output) ~= "" then
      local msg = "git remote tool execute successfully\n```\n" .. output .. "\n```"
      user_msg = msg
      llm_msg = "<gitRemoteTool>" .. msg .. "</gitRemoteTool>"
    else
      user_msg = "git remote tool execute successfully"
      llm_msg = "<gitRemoteTool>success</gitRemoteTool>"
    end
  else
    user_msg = "git remote tool execute failed"
    llm_msg = "<gitRemoteTool>fail: " .. (output or "unknown error") .. "</gitRemoteTool>"
  end
  return success, output, user_msg, llm_msg
end

---Show commit details
---@param commit_hash? string Commit hash (default: HEAD)
---@return boolean success, string output, string user_msg, string llm_msg
function GitTool.show_commit(commit_hash)
  commit_hash = commit_hash or "HEAD"
  local cmd = "git show " .. vim.fn.shellescape(commit_hash)
  local success, output = execute_git_command(cmd)
  local user_msg, llm_msg
  if success then
    if output and vim.trim(output) ~= "" then
      local msg = "git show tool execute successfully\n```\n" .. output .. "\n```"
      user_msg = msg
      llm_msg = "<gitShowTool>" .. msg .. "</gitShowTool>"
    else
      user_msg = "git show tool execute successfully"
      llm_msg = "<gitShowTool>success</gitShowTool>"
    end
  else
    user_msg = "git show tool execute failed"
    llm_msg = "<gitShowTool>fail: " .. (output or "unknown error") .. "</gitShowTool>"
  end
  return success, output, user_msg, llm_msg
end

---Get blame information for a file
---@param file_path string Path to the file
---@param line_start? number Start line number
---@param line_end? number End line number
---@return boolean success, string output, string user_msg, string llm_msg
function GitTool.get_blame(file_path, line_start, line_end)
  local cmd = "git blame " .. vim.fn.shellescape(file_path)
  if line_start and line_end then
    cmd = cmd .. " -L " .. line_start .. "," .. line_end
  elseif line_start then
    cmd = cmd .. " -L " .. line_start .. ",+10"
  end
  local success, output = execute_git_command(cmd)
  local user_msg, llm_msg
  if success then
    if output and vim.trim(output) ~= "" then
      local msg = "git blame tool execute successfully\n```\n" .. output .. "\n```"
      user_msg = msg
      llm_msg = "<gitBlameTool>" .. msg .. "</gitBlameTool>"
    else
      user_msg = "git blame tool execute successfully"
      llm_msg = "<gitBlameTool>success</gitBlameTool>"
    end
  else
    user_msg = "git blame tool execute failed"
    llm_msg = "<gitBlameTool>fail: " .. (output or "unknown error") .. "</gitBlameTool>"
  end
  return success, output, user_msg, llm_msg
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
---@return boolean success, string output, string user_msg, string llm_msg
function GitTool.list_stashes()
  local success, output = execute_git_command("git stash list")
  local user_msg, llm_msg
  if success then
    if output and vim.trim(output) ~= "" then
      local msg = "git stash tool execute successfully\n```\n" .. output .. "\n```"
      user_msg = msg
      llm_msg = "<gitStashTool>" .. msg .. "</gitStashTool>"
    else
      user_msg = "git stash tool execute successfully"
      llm_msg = "<gitStashTool>success</gitStashTool>"
    end
  else
    user_msg = "git stash tool execute failed"
    llm_msg = "<gitStashTool>fail: " .. (output or "unknown error") .. "</gitStashTool>"
  end
  return success, output, user_msg, llm_msg
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
---@return boolean success, string output, string user_msg, string llm_msg
function GitTool.diff_commits(commit1, commit2, file_path)
  commit2 = commit2 or "HEAD"
  local cmd = string.format("git diff %s %s", vim.fn.shellescape(commit1), vim.fn.shellescape(commit2))
  if file_path then
    cmd = cmd .. " -- " .. vim.fn.shellescape(file_path)
  end
  local success, output = execute_git_command(cmd)
  local user_msg, llm_msg
  if success then
    if output and vim.trim(output) ~= "" then
      local msg = "git diff_commits tool execute successfully\n```\n" .. output .. "\n```"
      user_msg = msg
      llm_msg = "<gitDiffCommitsTool>" .. msg .. "</gitDiffCommitsTool>"
    else
      user_msg = "git diff_commits tool execute successfully"
      llm_msg = "<gitDiffCommitsTool>success</gitDiffCommitsTool>"
    end
  else
    user_msg = "git diff_commits tool execute failed"
    llm_msg = "<gitDiffCommitsTool>fail: " .. (output or "unknown error") .. "</gitDiffCommitsTool>"
  end
  return success, output, user_msg, llm_msg
end

---Get contributors/authors
---@param count? number Number of top contributors to show
---@return boolean success, string output, string user_msg, string llm_msg
function GitTool.get_contributors(count)
  count = count or 10
  local head_cmd
  if vim.loop.os_uname().sysname == "Windows_NT" then
    head_cmd = string.format("git shortlog -sn | Select-Object -First %d", count)
  else
    head_cmd = string.format("git shortlog -sn | head -%d", count)
  end
  local success, output = execute_git_command(head_cmd)
  local user_msg, llm_msg
  if success then
    if output and vim.trim(output) ~= "" then
      local msg = "git contributors tool execute successfully\n```\n" .. output .. "\n```"
      user_msg = msg
      llm_msg = "<gitContributorsTool>" .. msg .. "</gitContributorsTool>"
    else
      user_msg = "git contributors tool execute successfully"
      llm_msg = "<gitContributorsTool>success</gitContributorsTool>"
    end
  else
    user_msg = "git contributors tool execute failed"
    llm_msg = "<gitContributorsTool>fail: " .. (output or "unknown error") .. "</gitContributorsTool>"
  end
  return success, output, user_msg, llm_msg
end

---Search commits by message
---@param pattern string Search pattern
---@param count? number Maximum number of results
---@return boolean success, string output, string user_msg, string llm_msg
function GitTool.search_commits(pattern, count)
  count = count or 20
  local cmd = string.format("git log --grep=%s --oneline -%d", vim.fn.shellescape(pattern), count)
  local success, output = execute_git_command(cmd)
  local user_msg, llm_msg
  if success then
    if output and vim.trim(output) ~= "" then
      local msg = "git search_commits tool execute successfully\n```\n" .. output .. "\n```"
      user_msg = msg
      llm_msg = "<gitSearchCommitsTool>" .. msg .. "</gitSearchCommitsTool>"
    else
      user_msg = "git search_commits tool execute successfully"
      llm_msg = "<gitSearchCommitsTool>success</gitSearchCommitsTool>"
    end
  else
    user_msg = "git search_commits tool execute failed"
    llm_msg = "<gitSearchCommitsTool>fail: " .. (output or "unknown error") .. "</gitSearchCommitsTool>"
  end
  return success, output, user_msg, llm_msg
end

---Push changes to a remote repository
---@param remote? string The name of the remote to push to (e.g., origin)
---@param branch? string The name of the branch to push (defaults to current branch)
---@param force? boolean Force push (DANGEROUS: overwrites remote history)
---@param tags? boolean Push all tags
---@param tag_name? string The name of a single tag to push
---@return boolean success, string output
function GitTool.push(remote, branch, force, tags, tag_name)
  local cmd = "git push"
  if force then
    cmd = cmd .. " --force"
  end
  if remote then
    cmd = cmd .. " " .. vim.fn.shellescape(remote)
  end
  if branch then
    cmd = cmd .. " " .. vim.fn.shellescape(branch)
  end
  if tags then
    cmd = cmd .. " --tags"
  end
  if tag_name then
    cmd = cmd .. " " .. vim.fn.shellescape(tag_name)
  end
  return execute_git_command(cmd)
end

---Push changes to a remote repository asynchronously
---@param remote? string The name of the remote to push to (e.g., origin)
---@param branch? string The name of the branch to push (defaults to current branch)
---@param force? boolean Force push (DANGEROUS: overwrites remote history)
---@param set_upstream? boolean Set the upstream branch
---@param tags? boolean Push all tags
---@param tag_name? string The name of a single tag to push
---@param on_exit function The callback function to execute on completion
function GitTool.push_async(remote, branch, force, set_upstream, tags, tag_name, on_exit)
  local cmd = { "git", "push" }
  if force then
    table.insert(cmd, "--force")
  end
  if set_upstream then
    table.insert(cmd, "--set-upstream")
  end
  if tags then
    table.insert(cmd, "--tags")
  end
  if tag_name then
    table.insert(cmd, "tag")
    table.insert(cmd, tag_name)
  end
  if remote then
    table.insert(cmd, remote)
  end
  if branch then
    table.insert(cmd, branch)
  end

  local stdout_lines = {}
  local stderr_lines = {}

  vim.fn.jobstart(cmd, {
    on_stdout = function(_, data)
      if data then
        for _, line in ipairs(data) do
          if line ~= "" then
            table.insert(stdout_lines, line)
          end
        end
      end
    end,
    on_stderr = function(_, data)
      if data then
        for _, line in ipairs(data) do
          if line ~= "" then
            table.insert(stderr_lines, line)
          end
        end
      end
    end,
    on_exit = function(_, code)
      if code == 0 then
        on_exit({ status = "success", data = table.concat(stdout_lines, "\n") })
      else
        on_exit({ status = "error", data = table.concat(stderr_lines, "\n") })
      end
    end,
  })
end

---Perform a git rebase operation

---@param onto? string The branch to rebase onto
---@param base? string The upstream branch to rebase from
---@param interactive? boolean Whether to perform an interactive rebase (DANGEROUS: opens an editor, not suitable for automated environments)
---@return boolean success, string output
function GitTool.rebase(onto, base, interactive)
  local cmd = "git rebase"
  if interactive then
    cmd = cmd .. " --interactive"
  end
  if onto then
    cmd = cmd .. " --onto " .. vim.fn.shellescape(onto)
  end
  if base then
    cmd = cmd .. " " .. vim.fn.shellescape(base)
  end
  return execute_git_command(cmd)
end

---Apply the changes introduced by some existing commits
---@param commit_hash string The commit hash to cherry-pick
---@return boolean success, string output
function GitTool.cherry_pick(commit_hash)
  if not commit_hash then
    return false, "Commit hash is required for cherry-pick"
  end
  local cmd = "git cherry-pick --no-edit " .. vim.fn.shellescape(commit_hash)
  return execute_git_command(cmd)
end

---Revert a commit
---@param commit_hash string The commit hash to revert
---@return boolean success, string output
function GitTool.revert(commit_hash)
  if not commit_hash then
    return false, "Commit hash is required for revert"
  end
  local cmd = "git revert --no-edit " .. vim.fn.shellescape(commit_hash)
  return execute_git_command(cmd)
end

---Get all tags
---@return boolean success, string output, string user_msg, string llm_msg
function GitTool.get_tags()
  local success, output = execute_git_command("git tag")
  local user_msg, llm_msg
  if success then
    if output and vim.trim(output) ~= "" then
      local msg = "git tag tool execute successfully\n```\n" .. output .. "\n```"
      user_msg = msg
      llm_msg = "<gitTagTool>" .. msg .. "</gitTagTool>"
    else
      user_msg = "git tag tool execute successfully"
      llm_msg = "<gitTagTool>success</gitTagTool>"
    end
  else
    user_msg = "git tag tool execute failed"
    llm_msg = "<gitTagTool>fail: " .. (output or "unknown error") .. "</gitTagTool>"
  end
  return success, output, user_msg, llm_msg
end

---Create a new tag
---@param tag_name string The name of the tag
---@param message? string An optional message for an annotated tag
---@param commit_hash? string An optional commit hash to tag
---@return boolean success, string output
function GitTool.create_tag(tag_name, message, commit_hash)
  if not tag_name then
    return false, "Tag name is required"
  end
  local cmd = "git tag "
  if message then
    cmd = cmd .. "-a " .. vim.fn.shellescape(tag_name) .. " -m " .. vim.fn.shellescape(message)
  else
    cmd = cmd .. vim.fn.shellescape(tag_name)
  end
  if commit_hash then
    cmd = cmd .. " " .. vim.fn.shellescape(commit_hash)
  end
  return execute_git_command(cmd)
end

---Delete a tag
---@param tag_name string The name of the tag to delete
---@param remote? string The name of the remote to delete from
---@return boolean success, string output
function GitTool.delete_tag(tag_name, remote)
  if not tag_name then
    return false, "Tag name is required for deletion"
  end
  local cmd
  if remote then
    cmd = "git push --delete " .. vim.fn.shellescape(remote) .. " " .. vim.fn.shellescape(tag_name)
  else
    cmd = "git tag -d " .. vim.fn.shellescape(tag_name)
  end
  return execute_git_command(cmd)
end

---Merge a branch into the current branch
---@param branch string The name of the branch to merge
---@return boolean success, string output
function GitTool.merge(branch)
  if not branch or vim.trim(branch) == "" then
    return false, "Branch name is required for merge"
  end

  if not is_git_repo() then
    return false, "Not in a git repository"
  end

  local cmd = "git merge " .. vim.fn.shellescape(branch) .. " --no-edit"
  local output = vim.fn.system(cmd)
  local exit_code = vim.v.shell_error

  if exit_code == 0 then
    return true, output
  else
    if output:match("CONFLICT") then
      return false,
        "Merge conflict detected. Please resolve the conflicts manually. You can use 'git merge --abort' to cancel."
    else
      return false, output
    end
  end
end

M.GitTool = GitTool
return M
