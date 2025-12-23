---@class CodeCompanion.GitCommit.Tools.Command
---Command building and execution utilities for git operations.
---Separates pure command generation (testable) from side-effectful execution.
---All command builders return arrays for cross-platform compatibility.

local M = {}

local GitUtils = require("codecompanion._extensions.gitcommit.git_utils")

local is_windows = GitUtils.is_windows

--------------------------------------------------------------------------------
-- CommandBuilder: Pure functions for generating git command arrays
-- These are easily testable without requiring a git repository
--------------------------------------------------------------------------------

---@class CodeCompanion.GitCommit.Tools.CommandBuilder
local CommandBuilder = {}

-- Log format mapping
CommandBuilder.LOG_FORMATS = {
  oneline = "--oneline",
  short = "--pretty=short",
  medium = "--pretty=medium",
  full = "--pretty=full",
  fuller = "--pretty=fuller",
  format = "--pretty=format",
}

-- Reset mode mapping
CommandBuilder.RESET_MODES = {
  soft = "--soft",
  mixed = "--mixed",
  hard = "--hard",
}

---Build git status command
---@return string[] command array
function CommandBuilder.status()
  return { "git", "status", "--porcelain" }
end

---Build git log command
---@param count? number Number of commits (default: 10)
---@param format? string Log format (default: "oneline")
---@return string[] command array
function CommandBuilder.log(count, format)
  count = count or 10
  format = format or "oneline"
  local format_option = CommandBuilder.LOG_FORMATS[format] or "--oneline"
  return { "git", "log", "-" .. count, format_option }
end

---Build git diff command
---@param staged? boolean Show staged changes
---@param file? string Specific file path
---@return string[] command array
function CommandBuilder.diff(staged, file)
  local cmd = { "git", "diff" }
  if staged then
    table.insert(cmd, "--cached")
  end
  if file then
    table.insert(cmd, "--")
    table.insert(cmd, file)
  end
  return cmd
end

---Build git branch command (show current)
---@return string[] command array
function CommandBuilder.current_branch()
  return { "git", "branch", "--show-current" }
end

---Build git branch list command
---@param remote_only? boolean Show only remote branches
---@return string[] command array
function CommandBuilder.branches(remote_only)
  if remote_only then
    return { "git", "branch", "-r" }
  else
    return { "git", "branch", "-a" }
  end
end

---Build git add command
---@param files string|string[] Files to stage
---@return string[] command array
function CommandBuilder.stage(files)
  if type(files) == "string" then
    files = { files }
  end
  local cmd = { "git", "add", "--" }
  for _, file in ipairs(files) do
    table.insert(cmd, file)
  end
  return cmd
end

---Build git reset (unstage) command
---@param files string|string[] Files to unstage
---@return string[] command array
function CommandBuilder.unstage(files)
  if type(files) == "string" then
    files = { files }
  end
  local cmd = { "git", "reset", "HEAD", "--" }
  for _, file in ipairs(files) do
    table.insert(cmd, file)
  end
  return cmd
end

---Build git commit command
---@param message string Commit message
---@param amend? boolean Amend the last commit
---@return string[] command array
function CommandBuilder.commit(message, amend)
  local cmd = { "git", "commit" }
  if amend then
    table.insert(cmd, "--amend")
  end
  table.insert(cmd, "-m")
  table.insert(cmd, message)
  return cmd
end

---Build git create branch command
---@param branch_name string Name of the new branch
---@param checkout? boolean Whether to checkout the new branch (default: true)
---@return string[] command array
function CommandBuilder.create_branch(branch_name, checkout)
  checkout = checkout ~= false
  if checkout then
    return { "git", "checkout", "-b", branch_name }
  else
    return { "git", "branch", branch_name }
  end
end

---Build git checkout command
---@param target string Branch name or commit hash
---@return string[] command array
function CommandBuilder.checkout(target)
  return { "git", "checkout", target }
end

---Build git remote command
---@return string[] command array
function CommandBuilder.remotes()
  return { "git", "remote", "-v" }
end

---Build git show command
---@param commit_hash? string Commit hash (default: HEAD)
---@return string[] command array
function CommandBuilder.show(commit_hash)
  commit_hash = commit_hash or "HEAD"
  return { "git", "show", commit_hash }
end

---Build git blame command
---@param file_path string Path to the file
---@param line_start? number Start line number
---@param line_end? number End line number
---@return string[] command array
function CommandBuilder.blame(file_path, line_start, line_end)
  local cmd = { "git", "blame" }
  if line_start and line_end then
    table.insert(cmd, "-L")
    table.insert(cmd, line_start .. "," .. line_end)
  elseif line_start then
    table.insert(cmd, "-L")
    table.insert(cmd, line_start .. ",+10")
  end
  table.insert(cmd, "--")
  table.insert(cmd, file_path)
  return cmd
end

---Build git stash command
---@param message? string Stash message
---@param include_untracked? boolean Include untracked files
---@return string[] command array
function CommandBuilder.stash(message, include_untracked)
  local cmd = { "git", "stash" }
  if include_untracked then
    table.insert(cmd, "-u")
  end
  if message then
    table.insert(cmd, "-m")
    table.insert(cmd, message)
  end
  return cmd
end

---Build git stash list command
---@return string[] command array
function CommandBuilder.stash_list()
  return { "git", "stash", "list" }
end

---Build git stash apply command
---@param stash_ref? string Stash reference (default: stash@{0})
---@return string[] command array
function CommandBuilder.stash_apply(stash_ref)
  stash_ref = stash_ref or "stash@{0}"
  return { "git", "stash", "apply", stash_ref }
end

---Build git reset command
---@param commit_hash string Commit hash or reference
---@param mode? string Reset mode (soft, mixed, hard)
---@return string[] command array
function CommandBuilder.reset(commit_hash, mode)
  mode = mode or "mixed"
  local mode_flag = CommandBuilder.RESET_MODES[mode] or "--mixed"
  return { "git", "reset", mode_flag, commit_hash }
end

---Build git diff between commits command
---@param commit1 string First commit
---@param commit2? string Second commit (default: HEAD)
---@param file_path? string Specific file path
---@return string[] command array
function CommandBuilder.diff_commits(commit1, commit2, file_path)
  commit2 = commit2 or "HEAD"
  local cmd = { "git", "diff", commit1, commit2 }
  if file_path then
    table.insert(cmd, "--")
    table.insert(cmd, file_path)
  end
  return cmd
end

---Build git shortlog (contributors) command
---@return string[] command array
function CommandBuilder.contributors()
  return { "git", "shortlog", "-sn" }
end

---Build git log search command
---@param pattern string Search pattern
---@param count? number Maximum number of results
---@return string[] command array
function CommandBuilder.search_commits(pattern, count)
  count = count or 20
  return { "git", "log", "--grep=" .. pattern, "--oneline", "-" .. count }
end

---Build git push command
---@param remote? string Remote name
---@param branch? string Branch name
---@param force? boolean Force push
---@param set_upstream? boolean Set upstream
---@param tags? boolean Push all tags
---@param tag_name? string Single tag to push
---@return string[] command array
function CommandBuilder.push(remote, branch, force, set_upstream, tags, tag_name)
  local cmd = { "git", "push" }
  if force then
    table.insert(cmd, "--force")
  end
  if set_upstream then
    table.insert(cmd, "--set-upstream")
  end

  -- Handle tag pushing - single tag takes priority over all tags
  if tag_name and vim.trim(tag_name) ~= "" then
    table.insert(cmd, remote or "origin")
    table.insert(cmd, tag_name)
  elseif tags then
    table.insert(cmd, remote or "origin")
    table.insert(cmd, "--tags")
  else
    if remote then
      table.insert(cmd, remote)
    end
    if branch then
      table.insert(cmd, branch)
    end
  end
  return cmd
end

---Build git rebase command
---@param onto? string Branch to rebase onto
---@param base? string Upstream branch
---@param interactive? boolean Interactive rebase
---@return string[] command array
function CommandBuilder.rebase(onto, base, interactive)
  local cmd = { "git", "rebase" }
  if interactive then
    table.insert(cmd, "--interactive")
  end
  if onto then
    table.insert(cmd, "--onto")
    table.insert(cmd, onto)
  end
  if base then
    table.insert(cmd, base)
  end
  return cmd
end

---Build git rebase continue command
---@return string[] command array
function CommandBuilder.rebase_continue()
  return { "git", "rebase", "--continue" }
end

---Build git rebase abort command
---@return string[] command array
function CommandBuilder.rebase_abort()
  return { "git", "rebase", "--abort" }
end

---Build git cherry-pick command
---@param commit_hash string Commit hash
---@return string[] command array
function CommandBuilder.cherry_pick(commit_hash)
  return { "git", "cherry-pick", "--no-edit", commit_hash }
end

---Build git cherry-pick abort command
---@return string[] command array
function CommandBuilder.cherry_pick_abort()
  return { "git", "cherry-pick", "--abort" }
end

---Build git cherry-pick continue command
---@return string[] command array
function CommandBuilder.cherry_pick_continue()
  return { "git", "cherry-pick", "--continue" }
end

---Build git cherry-pick skip command
---@return string[] command array
function CommandBuilder.cherry_pick_skip()
  return { "git", "cherry-pick", "--skip" }
end

---Build git revert command
---@param commit_hash string Commit hash
---@return string[] command array
function CommandBuilder.revert(commit_hash)
  return { "git", "revert", "--no-edit", commit_hash }
end

---Build git tag list command
---@return string[] command array
function CommandBuilder.tags()
  return { "git", "tag" }
end

---Build git tag sorted command
---@return string[] command array
function CommandBuilder.tags_sorted()
  return { "git", "tag", "--sort=-version:refname" }
end

---Build git create tag command
---@param tag_name string Tag name
---@param message? string Annotated tag message
---@param commit_hash? string Commit to tag
---@return string[] command array
function CommandBuilder.create_tag(tag_name, message, commit_hash)
  local cmd = { "git", "tag" }
  if message then
    table.insert(cmd, "-a")
    table.insert(cmd, tag_name)
    table.insert(cmd, "-m")
    table.insert(cmd, message)
  else
    table.insert(cmd, tag_name)
  end
  if commit_hash then
    table.insert(cmd, commit_hash)
  end
  return cmd
end

---Build git delete tag command
---@param tag_name string Tag name
---@param remote? string Remote to delete from
---@return string[] command array
function CommandBuilder.delete_tag(tag_name, remote)
  if remote then
    return { "git", "push", "--delete", remote, tag_name }
  else
    return { "git", "tag", "-d", tag_name }
  end
end

---Build git merge command
---@param branch string Branch to merge
---@return string[] command array
function CommandBuilder.merge(branch)
  return { "git", "merge", branch, "--no-edit" }
end

---Build git merge abort command
---@return string[] command array
function CommandBuilder.merge_abort()
  return { "git", "merge", "--abort" }
end

---Build git merge continue command
---@return string[] command array
function CommandBuilder.merge_continue()
  return { "git", "merge", "--continue" }
end

---Build git diff conflict status command
---@return string[] command array
function CommandBuilder.conflict_status()
  return { "git", "diff", "--name-only", "--diff-filter=U" }
end

---Build git log for release notes command
---@param from_tag string Starting tag
---@param to_tag string Ending tag
---@return string[] command array
function CommandBuilder.release_notes_log(from_tag, to_tag)
  local range = from_tag .. ".." .. to_tag
  return { "git", "log", "--pretty=format:%h\x01%s\x01%an\x01%ad", "--date=short", range }
end

---Build git remote add command
---@param name string Remote name
---@param url string Remote URL
---@return string[] command array
function CommandBuilder.add_remote(name, url)
  return { "git", "remote", "add", name, url }
end

---Build git remote remove command
---@param name string Remote name
---@return string[] command array
function CommandBuilder.remove_remote(name)
  return { "git", "remote", "remove", name }
end

---Build git remote rename command
---@param old_name string Current name
---@param new_name string New name
---@return string[] command array
function CommandBuilder.rename_remote(old_name, new_name)
  return { "git", "remote", "rename", old_name, new_name }
end

---Build git remote set-url command
---@param name string Remote name
---@param url string New URL
---@return string[] command array
function CommandBuilder.set_remote_url(name, url)
  return { "git", "remote", "set-url", name, url }
end

---Build git fetch command
---@param remote? string Remote name
---@param branch? string Branch name
---@param prune? boolean Prune deleted branches
---@return string[] command array
function CommandBuilder.fetch(remote, branch, prune)
  local cmd = { "git", "fetch" }
  if prune then
    table.insert(cmd, "--prune")
  end
  if remote then
    table.insert(cmd, remote)
    if branch then
      table.insert(cmd, branch)
    end
  else
    table.insert(cmd, "--all")
  end
  return cmd
end

---Build git pull command
---@param remote? string Remote name
---@param branch? string Branch name
---@param rebase? boolean Use rebase
---@return string[] command array
function CommandBuilder.pull(remote, branch, rebase)
  local cmd = { "git", "pull" }
  if rebase then
    table.insert(cmd, "--rebase")
  end
  if remote then
    table.insert(cmd, remote)
    if branch then
      table.insert(cmd, branch)
    end
  end
  return cmd
end

---Build git rev-parse command (check repo)
---@return string[] command array
function CommandBuilder.is_inside_work_tree()
  return { "git", "rev-parse", "--is-inside-work-tree" }
end

---Build git rev-parse --verify HEAD command
---@return string[] command array
function CommandBuilder.verify_head()
  return { "git", "rev-parse", "--verify", "HEAD" }
end

---Build git rev-parse git-dir command
---@return string[] command array
function CommandBuilder.git_dir()
  return { "git", "rev-parse", "--git-dir" }
end

---Build git rev-parse show-toplevel command
---@return string[] command array
function CommandBuilder.repo_root()
  return { "git", "rev-parse", "--show-toplevel" }
end

---Build git check-ignore command
---@param file string File to check
---@return string[] command array
function CommandBuilder.check_ignore(file)
  return { "git", "check-ignore", "--", file }
end

--------------------------------------------------------------------------------
-- CommandExecutor: Handles actual command execution with proper error handling
--------------------------------------------------------------------------------

---@class CodeCompanion.GitCommit.Tools.CommandExecutor
local CommandExecutor = {}

---Execute a git command (string or array)
---@param cmd string|string[] Command to execute
---@return boolean success
---@return string output
function CommandExecutor.run(cmd)
  local ok, output = pcall(vim.fn.system, cmd)
  if not ok then
    return false, "Command execution failed: " .. tostring(output)
  end

  local exit_code = vim.v.shell_error
  if exit_code ~= 0 then
    return false, output or "Git command failed"
  end

  return true, output or ""
end

---Execute a git command array (alias for run, kept for compatibility)
---@param cmd string[] Command array
---@return boolean success
---@return string output
function CommandExecutor.run_array(cmd)
  return CommandExecutor.run(cmd)
end

---Execute a git command asynchronously
---@param cmd string[] Command array
---@param on_exit function Callback function(result: {status: string, data: string})
function CommandExecutor.run_async(cmd, on_exit)
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

---Check if currently in a git repository
---@return boolean
function CommandExecutor.is_git_repo()
  local cmd = CommandBuilder.is_inside_work_tree()
  local ok, result = CommandExecutor.run(cmd)
  return ok and vim.trim(result) == "true"
end

---Execute a git command with repo check
---@param cmd string|string[] Command to execute
---@return boolean success
---@return string output
function CommandExecutor.run_in_repo(cmd)
  if not CommandExecutor.is_git_repo() then
    return false, "Not in a git repository"
  end
  return CommandExecutor.run(cmd)
end

M.CommandBuilder = CommandBuilder
M.CommandExecutor = CommandExecutor
M.is_windows = is_windows

return M
