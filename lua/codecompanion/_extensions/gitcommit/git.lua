local GitUtils = require("codecompanion._extensions.gitcommit.git_utils")

---@class CodeCompanion.GitCommit.Git
local Git = {}

local config = {}

---@param opts? table Configuration options
function Git.setup(opts)
  config = vim.tbl_deep_extend("force", {
    exclude_files = {},
    use_commit_history = true,
    commit_history_count = 10,
  }, opts or {})
end

---@param diff_content string The original diff content
---@return string filtered_diff The filtered diff content
function Git._filter_diff(diff_content)
  return GitUtils.filter_diff(diff_content, config.exclude_files)
end

---@param filepath string The file path to check
---@return boolean should_exclude True if file should be excluded
function Git._should_exclude_file(filepath)
  return GitUtils.should_exclude_file(filepath, config.exclude_files)
end

function Git.is_repository()
  local function check_git_dir(path)
    local sep = package.config:sub(1, 1)
    local git_path = path .. sep .. ".git"
    local stat = vim.uv.fs_stat(git_path)
    return stat ~= nil
  end

  local current_dir = vim.fn.getcwd()
  while current_dir do
    if check_git_dir(current_dir) then
      return true
    end

    local parent = vim.fn.fnamemodify(current_dir, ":h")
    if parent == current_dir then
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
  local ok, result = pcall(function()
    if not Git.is_repository() then
      return false
    end

    local git_dir = vim.trim(vim.fn.system("git rev-parse --git-dir"))
    if vim.v.shell_error ~= 0 then
      return false
    end

    local path_sep = package.config:sub(1, 1)
    local commit_editmsg = git_dir .. path_sep .. "COMMIT_EDITMSG"
    local stat = vim.uv.fs_stat(commit_editmsg)
    if not stat then
      return false
    end

    local redirect = (vim.uv.os_uname().sysname == "Windows_NT") and " 2>nul" or " 2>/dev/null"
    vim.fn.system("git rev-parse --verify HEAD" .. redirect)
    if vim.v.shell_error ~= 0 then
      return false
    end

    local fd = vim.uv.fs_open(commit_editmsg, "r", 438)
    if not fd then
      return false
    end

    local content = vim.uv.fs_read(fd, stat.size, 0)
    vim.uv.fs_close(fd)

    if not content then
      return false
    end

    local lines = vim.split(content, "\n")
    local has_existing_message = false
    for _, line in ipairs(lines) do
      local trimmed = vim.trim(line)
      if trimmed ~= "" and not trimmed:match("^#") then
        has_existing_message = true
        break
      end
    end

    return has_existing_message
  end)

  return ok and result or false
end

function Git.get_staged_diff()
  local ok, result = pcall(function()
    if not Git.is_repository() then
      return nil
    end

    local staged_diff = vim.fn.system("git diff --no-ext-diff --staged")
    if vim.v.shell_error == 0 and vim.trim(staged_diff) ~= "" then
      return Git._filter_diff(staged_diff)
    end

    if Git.is_amending() then
      local last_commit_diff = vim.fn.system("git diff --no-ext-diff HEAD~1")
      if vim.v.shell_error == 0 and vim.trim(last_commit_diff) ~= "" then
        return Git._filter_diff(last_commit_diff)
      end

      local show_diff = vim.fn.system("git show --no-ext-diff --format= HEAD")
      if vim.v.shell_error == 0 and vim.trim(show_diff) ~= "" then
        return Git._filter_diff(show_diff)
      end
    end

    return nil
  end)

  return ok and result or nil
end

---@return string|nil diff The diff content or nil if no changes
---@return string|nil context The context describing the diff type
function Git.get_contextual_diff()
  local ok, result = pcall(function()
    if not Git.is_repository() then
      return nil, "not_in_repo"
    end

    local staged_diff = vim.fn.system("git diff --no-ext-diff --staged")
    if vim.v.shell_error == 0 and GitUtils.trim(staged_diff) ~= "" then
      local filtered_diff = Git._filter_diff(staged_diff)
      if GitUtils.trim(filtered_diff) ~= "" then
        return filtered_diff, "staged"
      else
        return nil, "no_changes_after_filter"
      end
    end

    if Git.is_amending() then
      local last_commit_diff = vim.fn.system("git diff --no-ext-diff HEAD~1")
      if vim.v.shell_error == 0 and GitUtils.trim(last_commit_diff) ~= "" then
        local filtered_diff = Git._filter_diff(last_commit_diff)
        if GitUtils.trim(filtered_diff) ~= "" then
          return filtered_diff, "amend_with_parent"
        end
      end

      local show_diff = vim.fn.system("git show --no-ext-diff --format= HEAD")
      if vim.v.shell_error == 0 and GitUtils.trim(show_diff) ~= "" then
        local filtered_diff = Git._filter_diff(show_diff)
        if GitUtils.trim(filtered_diff) ~= "" then
          return filtered_diff, "amend_initial"
        end
      end
    end

    local all_local_diff = vim.fn.system("git diff --no-ext-diff HEAD")
    if vim.v.shell_error == 0 and GitUtils.trim(all_local_diff) ~= "" then
      local filtered_diff = Git._filter_diff(all_local_diff)
      if GitUtils.trim(filtered_diff) ~= "" then
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
  local ok, success = pcall(function()
    if not Git.is_repository() then
      vim.notify("Not in a git repository", vim.log.levels.ERROR)
      return false
    end

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

---@param count? number Number of recent commits to retrieve (default: 10)
---@return string[]|nil commit_messages Array of commit messages or nil on error
function Git.get_commit_history(count)
  count = count or 10

  local ok, result = pcall(function()
    if not Git.is_repository() then
      return nil
    end

    local cmd = string.format("git log --pretty=format:%%s --no-merges -%d", count)
    local output = vim.fn.system(cmd)

    if vim.v.shell_error ~= 0 then
      return nil
    end

    local lines = vim.split(output, "\n")
    local commit_messages = {}

    for _, line in ipairs(lines) do
      local trimmed = GitUtils.trim(line)
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

---@return table config Current configuration
function Git.get_config()
  return vim.deepcopy(config)
end

return Git
