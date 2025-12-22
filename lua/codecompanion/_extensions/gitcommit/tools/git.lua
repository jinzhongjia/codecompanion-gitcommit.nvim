local Git = require("codecompanion._extensions.gitcommit.git")
local GitUtils = require("codecompanion._extensions.gitcommit.git_utils")
local Command = require("codecompanion._extensions.gitcommit.tools.command")

local CommandBuilder = Command.CommandBuilder
local CommandExecutor = Command.CommandExecutor

local M = {}

---@class CodeCompanion.GitCommit.Tools.Git
local GitTool = {
  name = "git_operations",
  description = "Execute git operations and commands",
}

local function get_gitignore_path()
  local success, output = CommandExecutor.run(CommandBuilder.repo_root())
  if not success then
    return nil
  end
  local git_dir = output:gsub("\n", "")
  if not git_dir or git_dir == "" then
    return nil
  end
  local sep = package.config:sub(1, 1)
  return git_dir .. sep .. ".gitignore"
end

function GitTool.get_gitignore()
  local path = get_gitignore_path()
  if not path then
    local msg = ".gitignore not found (not in a git repo)"
    local user_msg = "✗ " .. msg
    local llm_msg = "<gitIgnoreTool>fail: " .. msg .. "</gitIgnoreTool>"
    return false, msg, user_msg, llm_msg
  end
  local stat = vim.uv.fs_stat(path)
  if not stat then
    local msg = ""
    local user_msg = "ℹ .gitignore file does not exist (repository has no ignore rules)"
    local llm_msg = "<gitIgnoreTool>success: .gitignore is empty</gitIgnoreTool>"
    return true, msg, user_msg, llm_msg
  end
  local fd = vim.uv.fs_open(path, "r", 438)
  if not fd then
    local msg = "Failed to open .gitignore for reading"
    local user_msg = "✗ " .. msg
    local llm_msg = "<gitIgnoreTool>fail: " .. msg .. "</gitIgnoreTool>"
    return false, msg, user_msg, llm_msg
  end
  local data = vim.uv.fs_read(fd, stat.size, 0)
  vim.uv.fs_close(fd)
  local msg = data or ""
  local user_msg
  if data and vim.trim(data) ~= "" then
    user_msg = "✓ .gitignore content:\n\n```gitignore\n" .. data .. "\n```"
  else
    user_msg = "ℹ .gitignore exists but is empty"
  end
  local llm_msg = "<gitIgnoreTool>success:\n" .. (data or "(empty)") .. "</gitIgnoreTool>"
  return true, msg, user_msg, llm_msg
end

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

function GitTool.is_ignored(file)
  if not file or file == "" then
    local msg = "No file specified"
    local user_msg = "✗ " .. msg .. " for .gitignore check"
    local llm_msg = "<gitIgnoreCheckTool>fail: " .. msg .. "</gitIgnoreCheckTool>"
    return false, msg, user_msg, llm_msg
  end
  local cmd = CommandBuilder.check_ignore(file)
  local success, result = CommandExecutor.run_array(cmd)
  if not success then
    local msg = "File is not ignored or not in a git repo"
    local user_msg = string.format("ℹ File '%s' is NOT ignored by .gitignore", file)
    local llm_msg = "<gitIgnoreCheckTool>fail: " .. msg .. "</gitIgnoreCheckTool>"
    return false, msg, user_msg, llm_msg
  end
  local trimmed = vim.trim(result)
  local user_msg = string.format("✓ File '%s' IS ignored by .gitignore", file)
  local llm_msg = string.format("<gitIgnoreCheckTool>success: %s is ignored</gitIgnoreCheckTool>", file)
  return true, trimmed, user_msg, llm_msg
end

local function is_git_repo()
  return Git.is_repository()
end

local function format_git_response(tool_name, success, output, empty_msg)
  local user_msg, llm_msg
  local tag = "git" .. tool_name:gsub("^%l", string.upper) .. "Tool"

  if success then
    if output and vim.trim(output) ~= "" then
      local formatted_output = vim.trim(output)
      local icon = "✓"
      user_msg = string.format("%s Git %s executed successfully:\n\n```\n%s\n```", icon, tool_name, formatted_output)
      llm_msg = string.format("<%s>success:\n%s</%s>", tag, formatted_output, tag)
    else
      local icon = "ℹ"
      local empty_text = empty_msg or ("No " .. tool_name .. " data available")
      user_msg = string.format("%s Git %s: %s", icon, tool_name, empty_text)
      llm_msg = string.format("<%s>success: %s</%s>", tag, empty_text, tag)
    end
  else
    local icon = "✗"
    local error_text = output or "Unknown error occurred"
    user_msg = string.format("%s Git %s failed:\n%s", icon, tool_name, error_text)
    llm_msg = string.format("<%s>fail: %s</%s>", tag, error_text, tag)
  end

  return user_msg, llm_msg
end

function GitTool.get_status()
  if not is_git_repo() then
    return false,
      "Not in a git repository",
      "✗ Not in a git repository",
      "<gitStatusTool>fail: Not in a git repository</gitStatusTool>"
  end
  local cmd = CommandBuilder.status()
  local success, output = CommandExecutor.run(cmd)
  local user_msg, llm_msg = format_git_response("status", success, output, "no changes found")
  return success, output, user_msg, llm_msg
end

function GitTool.get_log(count, format)
  if not is_git_repo() then
    return false,
      "Not in a git repository",
      "✗ Not in a git repository",
      "<gitLogTool>fail: Not in a git repository</gitLogTool>"
  end
  local cmd = CommandBuilder.log(count, format)
  local success, output = CommandExecutor.run(cmd)
  local user_msg, llm_msg = format_git_response("log", success, output, "no commits found")
  return success, output, user_msg, llm_msg
end

function GitTool.get_diff(staged, file)
  if not is_git_repo() then
    return false,
      "Not in a git repository",
      "✗ Not in a git repository",
      "<gitDiffTool>fail: Not in a git repository</gitDiffTool>"
  end
  local cmd = CommandBuilder.diff(staged, file)
  local success, output = CommandExecutor.run(cmd)
  local diff_type = staged and "staged" or "unstaged"
  local empty_msg = "no " .. diff_type .. " changes found"
  local user_msg, llm_msg = format_git_response("diff", success, output, empty_msg)
  return success, output, user_msg, llm_msg
end

function GitTool.get_current_branch()
  if not is_git_repo() then
    return false,
      "Not in a git repository",
      "✗ Not in a git repository",
      "<gitBranchTool>fail: Not in a git repository</gitBranchTool>"
  end
  local cmd = CommandBuilder.current_branch()
  local success, output = CommandExecutor.run(cmd)
  local user_msg, llm_msg = format_git_response("branch", success, output, "no current branch (possibly detached HEAD)")
  return success, output, user_msg, llm_msg
end

function GitTool.get_branches(remote_only)
  if not is_git_repo() then
    return false,
      "Not in a git repository",
      "✗ Not in a git repository",
      "<gitBranchTool>fail: Not in a git repository</gitBranchTool>"
  end
  local cmd = CommandBuilder.branches(remote_only)
  local success, output = CommandExecutor.run(cmd)
  local branch_type = remote_only and "remote branches" or "branches"
  local empty_msg = "no " .. branch_type .. " found"
  local user_msg, llm_msg = format_git_response("branch", success, output, empty_msg)
  return success, output, user_msg, llm_msg
end

function GitTool.stage_files(files)
  if not is_git_repo() then
    return false, "Not in a git repository"
  end
  if type(files) == "string" then
    files = { files }
  end
  local cmd = CommandBuilder.stage(files)
  return CommandExecutor.run(cmd)
end

function GitTool.unstage_files(files)
  if not is_git_repo() then
    return false, "Not in a git repository"
  end
  if type(files) == "string" then
    files = { files }
  end
  local cmd = CommandBuilder.unstage(files)
  return CommandExecutor.run(cmd)
end

function GitTool.commit(message, amend)
  if not is_git_repo() then
    return false, "Not in a git repository"
  end
  if not message or vim.trim(message) == "" then
    return false, "Commit message is required"
  end
  local cmd = CommandBuilder.commit(message, amend)
  return CommandExecutor.run(cmd)
end

function GitTool.create_branch(branch_name, checkout)
  if not is_git_repo() then
    return false, "Not in a git repository"
  end
  local cmd = CommandBuilder.create_branch(branch_name, checkout)
  return CommandExecutor.run(cmd)
end

function GitTool.checkout(target)
  if not is_git_repo() then
    return false, "Not in a git repository"
  end
  local cmd = CommandBuilder.checkout(target)
  return CommandExecutor.run(cmd)
end

function GitTool.get_remotes()
  if not is_git_repo() then
    return false,
      "Not in a git repository",
      "✗ Not in a git repository",
      "<gitRemoteTool>fail: Not in a git repository</gitRemoteTool>"
  end
  local cmd = CommandBuilder.remotes()
  local success, output = CommandExecutor.run(cmd)
  local user_msg, llm_msg = format_git_response("remote", success, output)
  return success, output, user_msg, llm_msg
end

function GitTool.show_commit(commit_hash)
  if not is_git_repo() then
    return false,
      "Not in a git repository",
      "✗ Not in a git repository",
      "<gitShowTool>fail: Not in a git repository</gitShowTool>"
  end
  local cmd = CommandBuilder.show(commit_hash)
  local success, output = CommandExecutor.run(cmd)
  local user_msg, llm_msg = format_git_response("show", success, output)
  return success, output, user_msg, llm_msg
end

function GitTool.get_blame(file_path, line_start, line_end)
  if not is_git_repo() then
    return false,
      "Not in a git repository",
      "✗ Not in a git repository",
      "<gitBlameTool>fail: Not in a git repository</gitBlameTool>"
  end
  local cmd = CommandBuilder.blame(file_path, line_start, line_end)
  local success, output = CommandExecutor.run(cmd)
  local user_msg, llm_msg = format_git_response("blame", success, output)
  return success, output, user_msg, llm_msg
end

function GitTool.stash(message, include_untracked)
  if not is_git_repo() then
    return false, "Not in a git repository"
  end
  local cmd = CommandBuilder.stash(message, include_untracked)
  return CommandExecutor.run(cmd)
end

function GitTool.list_stashes()
  if not is_git_repo() then
    return false,
      "Not in a git repository",
      "✗ Not in a git repository",
      "<gitStashTool>fail: Not in a git repository</gitStashTool>"
  end
  local cmd = CommandBuilder.stash_list()
  local success, output = CommandExecutor.run(cmd)
  local user_msg, llm_msg = format_git_response("stash", success, output)
  return success, output, user_msg, llm_msg
end

function GitTool.apply_stash(stash_ref)
  if not is_git_repo() then
    return false, "Not in a git repository"
  end
  local cmd = CommandBuilder.stash_apply(stash_ref)
  return CommandExecutor.run(cmd)
end

function GitTool.reset(commit_hash, mode)
  if not is_git_repo() then
    return false, "Not in a git repository"
  end
  local cmd = CommandBuilder.reset(commit_hash, mode)
  return CommandExecutor.run(cmd)
end

function GitTool.diff_commits(commit1, commit2, file_path)
  if not is_git_repo() then
    return false,
      "Not in a git repository",
      "✗ Not in a git repository",
      "<gitDiff_commitsTool>fail: Not in a git repository</gitDiff_commitsTool>"
  end
  local cmd = CommandBuilder.diff_commits(commit1, commit2, file_path)
  local success, output = CommandExecutor.run(cmd)
  local user_msg, llm_msg = format_git_response("diff_commits", success, output)
  return success, output, user_msg, llm_msg
end

function GitTool.get_contributors(count)
  if not is_git_repo() then
    return false,
      "Not in a git repository",
      "✗ Not in a git repository",
      "<gitContributorsTool>fail: Not in a git repository</gitContributorsTool>"
  end
  count = count or 10
  local cmd = CommandBuilder.contributors()
  local success, output = CommandExecutor.run(cmd)
  if success and output then
    local lines = vim.split(output, "\n")
    local limited_lines = {}
    for i = 1, math.min(count, #lines) do
      if lines[i] and lines[i] ~= "" then
        table.insert(limited_lines, lines[i])
      end
    end
    output = table.concat(limited_lines, "\n")
  end
  local user_msg, llm_msg = format_git_response("contributors", success, output)
  return success, output, user_msg, llm_msg
end

function GitTool.search_commits(pattern, count)
  if not is_git_repo() then
    return false,
      "Not in a git repository",
      "✗ Not in a git repository",
      "<gitSearch_commitsTool>fail: Not in a git repository</gitSearch_commitsTool>"
  end
  local cmd = CommandBuilder.search_commits(pattern, count)
  local success, output = CommandExecutor.run(cmd)
  local user_msg, llm_msg = format_git_response("search_commits", success, output)
  return success, output, user_msg, llm_msg
end

function GitTool.push(remote, branch, force, set_upstream, tags, tag_name)
  if not is_git_repo() then
    return false, "Not in a git repository"
  end
  local cmd = CommandBuilder.push(remote, branch, force, set_upstream, tags, tag_name)
  return CommandExecutor.run(cmd)
end

function GitTool.push_async(remote, branch, force, set_upstream, tags, tag_name, on_exit)
  if not is_git_repo() then
    on_exit({ status = "error", data = "Not in a git repository" })
    return
  end
  local cmd = CommandBuilder.push_array(remote, branch, force, set_upstream, tags, tag_name)
  CommandExecutor.run_async(cmd, on_exit)
end

function GitTool.rebase(onto, base, interactive)
  if not is_git_repo() then
    return false, "Not in a git repository"
  end
  local cmd = CommandBuilder.rebase(onto, base, interactive)
  return CommandExecutor.run(cmd)
end

function GitTool.cherry_pick(commit_hash)
  if not commit_hash then
    return false, "Commit hash is required for cherry-pick"
  end
  if not is_git_repo() then
    return false, "Not in a git repository"
  end
  local cmd = CommandBuilder.cherry_pick(commit_hash)
  local output = vim.fn.system(cmd)
  local exit_code = vim.v.shell_error

  if exit_code == 0 then
    return true, output
  else
    if output:match("CONFLICT") or output:match("conflict") then
      return false,
        "Cherry-pick conflict detected. Please resolve the conflicts manually.\n"
          .. "Options:\n"
          .. "  • Use 'cherry_pick_continue' after resolving conflicts\n"
          .. "  • Use 'cherry_pick_abort' to cancel the cherry-pick\n"
          .. "  • Use 'cherry_pick_skip' to skip this commit"
    else
      return false, output
    end
  end
end

function GitTool.cherry_pick_abort()
  if not is_git_repo() then
    return false, "Not in a git repository"
  end
  local cmd = CommandBuilder.cherry_pick_abort()
  local output = vim.fn.system(cmd)
  local exit_code = vim.v.shell_error

  if exit_code == 0 then
    return true, "Cherry-pick aborted successfully"
  else
    if output:match("no cherry%-pick") or output:match("not in progress") then
      return false, "No cherry-pick in progress to abort"
    end
    return false, output
  end
end

function GitTool.cherry_pick_continue()
  if not is_git_repo() then
    return false, "Not in a git repository"
  end
  local cmd = CommandBuilder.cherry_pick_continue()
  local output = vim.fn.system(cmd)
  local exit_code = vim.v.shell_error

  if exit_code == 0 then
    return true, "Cherry-pick continued successfully"
  else
    if output:match("CONFLICT") or output:match("conflict") then
      return false, "Conflicts still exist. Please resolve all conflicts before continuing."
    elseif output:match("no cherry%-pick") or output:match("not in progress") then
      return false, "No cherry-pick in progress to continue"
    end
    return false, output
  end
end

function GitTool.cherry_pick_skip()
  if not is_git_repo() then
    return false, "Not in a git repository"
  end
  local cmd = CommandBuilder.cherry_pick_skip()
  local output = vim.fn.system(cmd)
  local exit_code = vim.v.shell_error

  if exit_code == 0 then
    return true, "Current commit skipped successfully"
  else
    if output:match("no cherry%-pick") or output:match("not in progress") then
      return false, "No cherry-pick in progress to skip"
    end
    return false, output
  end
end

function GitTool.revert(commit_hash)
  if not commit_hash then
    return false, "Commit hash is required for revert"
  end
  if not is_git_repo() then
    return false, "Not in a git repository"
  end
  local cmd = CommandBuilder.revert(commit_hash)
  return CommandExecutor.run(cmd)
end

function GitTool.get_tags()
  if not is_git_repo() then
    return false,
      "Not in a git repository",
      "✗ Not in a git repository",
      "<gitTagTool>fail: Not in a git repository</gitTagTool>"
  end
  local cmd = CommandBuilder.tags()
  local success, output = CommandExecutor.run(cmd)
  local user_msg, llm_msg = format_git_response("tag", success, output)
  return success, output, user_msg, llm_msg
end

function GitTool.create_tag(tag_name, message, commit_hash)
  if not tag_name then
    return false, "Tag name is required"
  end
  if not is_git_repo() then
    return false, "Not in a git repository"
  end
  local cmd = CommandBuilder.create_tag(tag_name, message, commit_hash)
  return CommandExecutor.run(cmd)
end

function GitTool.delete_tag(tag_name, remote)
  if not tag_name then
    return false, "Tag name is required for deletion"
  end
  if not is_git_repo() then
    return false, "Not in a git repository"
  end
  local cmd = CommandBuilder.delete_tag(tag_name, remote)
  return CommandExecutor.run(cmd)
end

function GitTool.merge(branch)
  if not branch or vim.trim(branch) == "" then
    return false, "Branch name is required for merge"
  end
  if not is_git_repo() then
    return false, "Not in a git repository"
  end
  local cmd = CommandBuilder.merge(branch)
  local output = vim.fn.system(cmd)
  local exit_code = vim.v.shell_error

  if exit_code == 0 then
    return true, output
  else
    if output:match("CONFLICT") or output:match("conflict") then
      return false,
        "Merge conflict detected. Please resolve the conflicts manually.\n"
          .. "Options:\n"
          .. "  • Use 'merge_continue' after resolving conflicts\n"
          .. "  • Use 'merge_abort' to cancel the merge"
    else
      return false, output
    end
  end
end

function GitTool.merge_abort()
  if not is_git_repo() then
    return false, "Not in a git repository"
  end
  local cmd = CommandBuilder.merge_abort()
  local output = vim.fn.system(cmd)
  local exit_code = vim.v.shell_error

  if exit_code == 0 then
    return true, "Merge aborted successfully"
  else
    if output:match("not merging") or output:match("no merge") then
      return false, "No merge in progress to abort"
    end
    return false, output
  end
end

function GitTool.merge_continue()
  if not is_git_repo() then
    return false, "Not in a git repository"
  end
  local cmd = CommandBuilder.merge_continue()
  local output = vim.fn.system(cmd)
  local exit_code = vim.v.shell_error

  if exit_code == 0 then
    return true, "Merge continued successfully"
  else
    if output:match("CONFLICT") or output:match("conflict") then
      return false, "Conflicts still exist. Please resolve all conflicts before continuing."
    elseif output:match("not merging") or output:match("no merge") then
      return false, "No merge in progress to continue"
    end
    return false, output
  end
end

function GitTool.get_conflict_status()
  if not is_git_repo() then
    local msg = "Not in a git repository"
    return false, msg, "✗ " .. msg, "<gitConflictStatus>fail: " .. msg .. "</gitConflictStatus>"
  end

  local cmd = CommandBuilder.conflict_status()
  local output = vim.fn.system(cmd)
  local exit_code = vim.v.shell_error

  if exit_code ~= 0 then
    local msg = "Failed to get conflict status"
    return false, msg, "✗ " .. msg, "<gitConflictStatus>fail: " .. msg .. "</gitConflictStatus>"
  end

  local trimmed = vim.trim(output)
  if trimmed == "" then
    local msg = "No conflicts found"
    return true, msg, "✓ " .. msg, "<gitConflictStatus>success: " .. msg .. "</gitConflictStatus>"
  end

  local files = {}
  for file in trimmed:gmatch("[^\r\n]+") do
    if file ~= "" then
      table.insert(files, file)
    end
  end

  local user_msg = string.format("⚠ %d file(s) with conflicts:\n", #files)
  for _, file in ipairs(files) do
    user_msg = user_msg .. "  • " .. file .. "\n"
  end

  local llm_msg =
    string.format("<gitConflictStatus>success: %d conflicted file(s):\n%s</gitConflictStatus>", #files, trimmed)

  return true, trimmed, user_msg, llm_msg
end

function GitTool.show_conflict(file_path)
  if not is_git_repo() then
    local msg = "Not in a git repository"
    return false, msg, "✗ " .. msg, "<gitConflictShow>fail: " .. msg .. "</gitConflictShow>"
  end

  if not file_path or vim.trim(file_path) == "" then
    local msg = "File path is required"
    return false, msg, "✗ " .. msg, "<gitConflictShow>fail: " .. msg .. "</gitConflictShow>"
  end

  local stat = vim.uv.fs_stat(file_path)
  if not stat then
    local msg = "File not found: " .. file_path
    return false, msg, "✗ " .. msg, "<gitConflictShow>fail: " .. msg .. "</gitConflictShow>"
  end

  local fd = vim.uv.fs_open(file_path, "r", 438)
  if not fd then
    local msg = "Failed to open file: " .. file_path
    return false, msg, "✗ " .. msg, "<gitConflictShow>fail: " .. msg .. "</gitConflictShow>"
  end

  local content = vim.uv.fs_read(fd, stat.size, 0)
  vim.uv.fs_close(fd)

  if not content then
    local msg = "Failed to read file: " .. file_path
    return false, msg, "✗ " .. msg, "<gitConflictShow>fail: " .. msg .. "</gitConflictShow>"
  end

  if not GitUtils.has_conflicts(content) then
    local msg = "No conflict markers found in: " .. file_path
    return true, msg, "✓ " .. msg, "<gitConflictShow>success: " .. msg .. "</gitConflictShow>"
  end

  local raw_conflicts = GitUtils.parse_conflicts(content)
  local conflicts = {}
  for i, block in ipairs(raw_conflicts) do
    table.insert(conflicts, string.format("--- Conflict #%d ---\n%s", i, block))
  end

  if #conflicts == 0 then
    local msg = "No conflict markers found in: " .. file_path
    return true, msg, "✓ " .. msg, "<gitConflictShow>success: " .. msg .. "</gitConflictShow>"
  end

  local conflict_output = table.concat(conflicts, "\n\n")
  local user_msg = string.format(
    "⚠ Found %d conflict(s) in %s:\n\n```\n%s\n```\n\nResolve conflicts manually, then use 'stage' followed by 'cherry_pick_continue' or 'merge_continue'.",
    #conflicts,
    file_path,
    conflict_output
  )

  local llm_msg = string.format(
    "<gitConflictShow>success: %d conflict(s) in %s:\n%s</gitConflictShow>",
    #conflicts,
    file_path,
    conflict_output
  )

  return true, conflict_output, user_msg, llm_msg
end

function GitTool.generate_release_notes(from_tag, to_tag, format)
  format = format or "markdown"

  local tags_cmd = CommandBuilder.tags_sorted()
  local success_tags, tags_output = CommandExecutor.run(tags_cmd)
  if not success_tags then
    local msg = "Failed to get git tags: " .. (tags_output or "unknown error")
    local user_msg = "✗ " .. msg
    local llm_msg = "<gitReleaseNotes>fail: " .. msg .. "</gitReleaseNotes>"
    return false, msg, user_msg, llm_msg
  end

  local tags = {}
  for tag in tags_output:gmatch("[^\r\n]+") do
    if tag ~= "" then
      table.insert(tags, tag)
    end
  end

  if #tags < 1 then
    local msg = "No tags found in repository"
    local user_msg = "ℹ " .. msg
    local llm_msg = "<gitReleaseNotes>fail: " .. msg .. "</gitReleaseNotes>"
    return false, msg, user_msg, llm_msg
  end

  if not to_tag then
    to_tag = tags[1]
  end

  if not from_tag then
    if #tags < 2 then
      local msg = "Cannot generate release notes: only one tag found. Please specify from_tag parameter."
      local user_msg = "ℹ " .. msg
      local llm_msg = "<gitReleaseNotes>fail: " .. msg .. "</gitReleaseNotes>"
      return false, msg, user_msg, llm_msg
    end
    from_tag = tags[2]
  end

  local commit_cmd = CommandBuilder.release_notes_log(from_tag, to_tag)
  local success_commits, commits_output = CommandExecutor.run(commit_cmd)

  if not success_commits then
    local msg = "Failed to get commits between "
      .. from_tag
      .. " and "
      .. to_tag
      .. ": "
      .. (commits_output or "unknown error")
    local user_msg = "✗ " .. msg
    local llm_msg = "<gitReleaseNotes>fail: " .. msg .. "</gitReleaseNotes>"
    return false, msg, user_msg, llm_msg
  end

  local commits = {}
  for line in commits_output:gmatch("[^\r\n]+") do
    local parts = vim.split(line, "\x01")
    if #parts == 4 then
      table.insert(commits, {
        hash = parts[1],
        subject = parts[2],
        author = parts[3],
        date = parts[4],
      })
    end
  end

  if #commits == 0 then
    local msg = "No commits found between " .. from_tag .. " and " .. to_tag
    local user_msg = "ℹ " .. msg
    local llm_msg = "<gitReleaseNotes>success: " .. msg .. "</gitReleaseNotes>"
    return true, msg, user_msg, llm_msg
  end

  local release_notes = ""
  local user_msg = ""
  local llm_msg = ""

  if format == "markdown" then
    local parts = { "# Release Notes: " .. from_tag .. " → " .. to_tag .. "\n\n" }
    table.insert(parts, "## Changes (" .. #commits .. " commits)\n\n")

    local features = {}
    local fixes = {}
    local others = {}

    for _, commit in ipairs(commits) do
      local type_match = commit.subject:match("^(%w+)%(.*%):") or commit.subject:match("^(%w+):")
      if type_match then
        if type_match == "feat" then
          table.insert(features, commit)
        elseif type_match == "fix" then
          table.insert(fixes, commit)
        else
          table.insert(others, commit)
        end
      else
        table.insert(others, commit)
      end
    end

    if #features > 0 then
      table.insert(parts, "### ✨ New Features\n\n")
      for _, commit in ipairs(features) do
        table.insert(parts, "- " .. commit.subject .. " (" .. commit.hash .. ")\n")
      end
      table.insert(parts, "\n")
    end

    if #fixes > 0 then
      table.insert(parts, "### 🐛 Bug Fixes\n\n")
      for _, commit in ipairs(fixes) do
        table.insert(parts, "- " .. commit.subject .. " (" .. commit.hash .. ")\n")
      end
      table.insert(parts, "\n")
    end

    if #others > 0 then
      table.insert(parts, "### 📝 Other Changes\n\n")
      for _, commit in ipairs(others) do
        table.insert(parts, "- " .. commit.subject .. " (" .. commit.hash .. ")\n")
      end
      table.insert(parts, "\n")
    end

    local contributors = {}
    for _, commit in ipairs(commits) do
      if not contributors[commit.author] then
        contributors[commit.author] = 0
      end
      contributors[commit.author] = contributors[commit.author] + 1
    end

    table.insert(parts, "### 👥 Contributors\n\n")
    local sorted_authors = {}
    for author in pairs(contributors) do
      table.insert(sorted_authors, author)
    end
    table.sort(sorted_authors, function(a, b)
      if contributors[a] == contributors[b] then
        return a < b
      end
      return contributors[a] > contributors[b]
    end)
    for _, author in ipairs(sorted_authors) do
      table.insert(parts, "- " .. author .. " (" .. contributors[author] .. " commits)\n")
    end
    release_notes = table.concat(parts)
  elseif format == "plain" then
    local parts = { "Release Notes: " .. from_tag .. " → " .. to_tag .. "\n" }
    table.insert(parts, "Changes (" .. #commits .. " commits):\n\n")
    for _, commit in ipairs(commits) do
      table.insert(parts, "- " .. commit.subject .. " (" .. commit.hash .. " by " .. commit.author .. ")\n")
    end
    release_notes = table.concat(parts)
  elseif format == "json" then
    local json_data = {
      from_tag = from_tag,
      to_tag = to_tag,
      total_commits = #commits,
      commits = commits,
    }
    release_notes = vim.fn.json_encode(json_data)
  else
    local msg = "Unsupported format: " .. format .. ". Supported formats: markdown, plain, json"
    user_msg = "✗ " .. msg
    llm_msg = "<gitReleaseNotes>fail: " .. msg .. "</gitReleaseNotes>"
    return false, msg, user_msg, llm_msg
  end

  user_msg = string.format(
    "✓ Generated release notes for %s → %s (%d commits)\n\n```%s\n%s\n```",
    from_tag,
    to_tag,
    #commits,
    format == "json" and "json" or format,
    release_notes
  )
  llm_msg = "<gitReleaseNotes>success: "
    .. from_tag
    .. " → "
    .. to_tag
    .. " ("
    .. #commits
    .. " commits)\n\n"
    .. release_notes
    .. "</gitReleaseNotes>"

  return true, release_notes, user_msg, llm_msg
end

function GitTool.add_remote(name, url)
  if not name or vim.trim(name) == "" then
    return false, "Remote name is required"
  end
  if not url or vim.trim(url) == "" then
    return false, "Remote URL is required"
  end
  if not is_git_repo() then
    return false, "Not in a git repository"
  end
  local cmd = CommandBuilder.add_remote(name, url)
  return CommandExecutor.run(cmd)
end

function GitTool.remove_remote(name)
  if not name or vim.trim(name) == "" then
    return false, "Remote name is required"
  end
  if not is_git_repo() then
    return false, "Not in a git repository"
  end
  local cmd = CommandBuilder.remove_remote(name)
  return CommandExecutor.run(cmd)
end

function GitTool.rename_remote(old_name, new_name)
  if not old_name or vim.trim(old_name) == "" then
    return false, "Current remote name is required"
  end
  if not new_name or vim.trim(new_name) == "" then
    return false, "New remote name is required"
  end
  if not is_git_repo() then
    return false, "Not in a git repository"
  end
  local cmd = CommandBuilder.rename_remote(old_name, new_name)
  return CommandExecutor.run(cmd)
end

function GitTool.set_remote_url(name, url)
  if not name or vim.trim(name) == "" then
    return false, "Remote name is required"
  end
  if not url or vim.trim(url) == "" then
    return false, "Remote URL is required"
  end
  if not is_git_repo() then
    return false, "Not in a git repository"
  end
  local cmd = CommandBuilder.set_remote_url(name, url)
  return CommandExecutor.run(cmd)
end

function GitTool.fetch(remote, branch, prune)
  if not is_git_repo() then
    return false, "Not in a git repository"
  end
  local cmd = CommandBuilder.fetch(remote, branch, prune)
  return CommandExecutor.run(cmd)
end

function GitTool.pull(remote, branch, rebase)
  if not is_git_repo() then
    return false, "Not in a git repository"
  end
  local cmd = CommandBuilder.pull(remote, branch, rebase)
  return CommandExecutor.run(cmd)
end

M.GitTool = GitTool
return M
