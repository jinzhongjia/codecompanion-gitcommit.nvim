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
    local msg = ".gitignore not found (not in a git repo)"
    local user_msg = msg
    local llm_msg = "<gitIgnoreTool>fail: " .. msg .. "</gitIgnoreTool>"
    return false, msg, user_msg, llm_msg
  end
  local stat = vim.uv.fs_stat(path)
  if not stat then
    local msg = "" -- treat as empty if not exists
    local user_msg = ".gitignore is empty"
    local llm_msg = "<gitIgnoreTool>success: .gitignore is empty</gitIgnoreTool>"
    return true, msg, user_msg, llm_msg
  end
  local fd = vim.uv.fs_open(path, "r", 438)
  if not fd then
    local msg = "Failed to open .gitignore for reading"
    local user_msg = msg
    local llm_msg = "<gitIgnoreTool>fail: " .. msg .. "</gitIgnoreTool>"
    return false, msg, user_msg, llm_msg
  end
  local data = vim.uv.fs_read(fd, stat.size, 0)
  vim.uv.fs_close(fd)
  local msg = data or ""
  local user_msg = ".gitignore content:\n" .. (data or "(empty)")
  local llm_msg = "<gitIgnoreTool>success:\n" .. (data or "(empty)") .. "</gitIgnoreTool>"
  return true, msg, user_msg, llm_msg
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
    local msg = "No file specified"
    local user_msg = msg
    local llm_msg = "<gitIgnoreCheckTool>fail: " .. msg .. "</gitIgnoreCheckTool>"
    return false, msg, user_msg, llm_msg
  end
  local ok, result = pcall(function()
    return vim.fn.system({ "git", "check-ignore", file })
  end)
  if not ok or vim.v.shell_error ~= 0 then
    local msg = "File is not ignored or not in a git repo"
    local user_msg = msg
    local llm_msg = "<gitIgnoreCheckTool>fail: " .. msg .. "</gitIgnoreCheckTool>"
    return false, msg, user_msg, llm_msg
  end
  local trimmed = vim.trim(result)
  local user_msg = string.format("File '%s' is ignored by .gitignore", file)
  local llm_msg = string.format("<gitIgnoreCheckTool>success: %s is ignored</gitIgnoreCheckTool>", file)
  return true, trimmed, user_msg, llm_msg
end

local function is_git_repo()
  -- Use Neovim built-in vim.fn.system instead of io.popen
  local ok, result = pcall(function()
    local cmd = "git rev-parse --is-inside-work-tree"
    local output = vim.fn.system(cmd)
    return vim.v.shell_error == 0 and output:match("true") ~= nil
  end)
  return ok and result or false
end

local function execute_git_command(cmd)
  local ok, success, output = pcall(function()
    if not is_git_repo() then
      return false, "Not in a git repository"
    end

    local cmd_output = vim.fn.system(cmd)
    local exit_code = vim.v.shell_error

    if exit_code ~= 0 or (cmd_output and cmd_output:match("fatal: ")) then
      return false, cmd_output or "Git command failed"
    end
    return true, cmd_output or ""
  end)

  if not ok then
    return false, "Git command execution failed: " .. tostring(success)
  end

  return success, output
end

-- Helper function to format git tool responses consistently
local function format_git_response(tool_name, success, output, empty_msg)
  local user_msg, llm_msg
  local tag = "git" .. tool_name:gsub("^%l", string.upper) .. "Tool"

  if success then
    if output and vim.trim(output) ~= "" then
      local msg = string.format("git %s tool execute successfully\n```\n%s\n```", tool_name, output)
      user_msg = msg
      llm_msg = string.format("<%s>%s</%s>", tag, msg, tag)
    else
      user_msg =
        string.format("git %s tool execute successfully%s", tool_name, empty_msg and (" - " .. empty_msg) or "")
      llm_msg = string.format("<%s>success%s</%s>", tag, empty_msg and (": " .. empty_msg) or "", tag)
    end
  else
    user_msg = string.format("git %s tool execute failed: %s", tool_name, output or "unknown error")
    llm_msg = string.format("<%s>fail: %s</%s>", tag, output or "unknown error", tag)
  end

  return user_msg, llm_msg
end

function GitTool.get_status()
  local success, output = execute_git_command("git status --porcelain")
  local user_msg, llm_msg = format_git_response("status", success, output, "no changes found")
  return success, output, user_msg, llm_msg
end

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
  local user_msg, llm_msg = format_git_response("log", success, output, "no commits found")
  return success, output, user_msg, llm_msg
end

function GitTool.get_diff(staged, file)
  local cmd = "git diff"
  if staged then
    cmd = cmd .. " --cached"
  end
  if file then
    cmd = cmd .. " " .. vim.fn.shellescape(file)
  end
  local success, output = execute_git_command(cmd)
  local diff_type = staged and "staged" or "unstaged"
  local empty_msg = "no " .. diff_type .. " changes found"
  local user_msg, llm_msg = format_git_response("diff", success, output, empty_msg)
  return success, output, user_msg, llm_msg
end

---Get current branch name
---@return boolean success, string branch_name

function GitTool.get_current_branch()
  local success, output = execute_git_command("git branch --show-current")
  local user_msg, llm_msg = format_git_response("branch", success, output, "no current branch (possibly detached HEAD)")
  return success, output, user_msg, llm_msg
end

---Get all branches (local and remote)
---@param remote_only? boolean Show only remote branches
---@return boolean success, string output, string user_msg, string llm_msg
function GitTool.get_branches(remote_only)
  local cmd = remote_only and "git branch -r" or "git branch -a"
  local success, output = execute_git_command(cmd)
  local branch_type = remote_only and "remote branches" or "branches"
  local empty_msg = "no " .. branch_type .. " found"
  local user_msg, llm_msg = format_git_response("branch", success, output, empty_msg)
  return success, output, user_msg, llm_msg
end

function GitTool.stage_files(files)
  local ok, success, output = pcall(function()
    if type(files) == "string" then
      files = { files }
    end

    local escaped_files = {}
    for _, file in ipairs(files) do
      table.insert(escaped_files, vim.fn.shellescape(file))
    end

    local cmd = "git add " .. table.concat(escaped_files, " ")
    return execute_git_command(cmd)
  end)

  if not ok then
    return false, "Failed to stage files: " .. tostring(success)
  end

  return success, output
end

function GitTool.unstage_files(files)
  local ok, success, output = pcall(function()
    if type(files) == "string" then
      files = { files }
    end

    local escaped_files = {}
    for _, file in ipairs(files) do
      table.insert(escaped_files, vim.fn.shellescape(file))
    end

    local cmd = "git reset HEAD " .. table.concat(escaped_files, " ")
    return execute_git_command(cmd)
  end)

  if not ok then
    return false, "Failed to unstage files: " .. tostring(success)
  end

  return success, output
end
---Commit staged changes
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
  local user_msg, llm_msg = format_git_response("remote", success, output)
  return success, output, user_msg, llm_msg
end

---Show commit details
---@param commit_hash? string Commit hash (default: HEAD)
---@return boolean success, string output, string user_msg, string llm_msg
function GitTool.show_commit(commit_hash)
  commit_hash = commit_hash or "HEAD"
  local cmd = "git show " .. vim.fn.shellescape(commit_hash)
  local success, output = execute_git_command(cmd)
  local user_msg, llm_msg = format_git_response("show", success, output)
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
  local user_msg, llm_msg = format_git_response("blame", success, output)
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
  local user_msg, llm_msg = format_git_response("stash", success, output)
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
  local user_msg, llm_msg = format_git_response("diff_commits", success, output)
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
  local user_msg, llm_msg = format_git_response("contributors", success, output)
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
  local user_msg, llm_msg = format_git_response("search_commits", success, output)
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
  local user_msg, llm_msg = format_git_response("tag", success, output)
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
