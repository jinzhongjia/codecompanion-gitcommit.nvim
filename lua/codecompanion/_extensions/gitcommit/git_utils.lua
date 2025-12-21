---@class CodeCompanion.GitCommit.GitUtils
---Pure utility functions for git operations.
---These are testable without requiring a git repository.

local M = {}

---Trim whitespace from string
---@param s string The string to trim
---@return string trimmed_string
function M.trim(s)
  return (s:gsub("^%s*(.-)%s*$", "%1"))
end

---Convert a glob pattern to a Lua pattern
---Handles: * (any non-slash), ** (any including slash), ? (single char), escapes special chars
---@param glob string The glob pattern (e.g., "*.lua", "**/*.js", "dist/*")
---@return string lua_pattern The converted Lua pattern
function M.glob_to_lua_pattern(glob)
  local escaped = glob
  escaped = escaped:gsub("%%", "%%%%")
  escaped = escaped:gsub("%.", "%%%.")
  escaped = escaped:gsub("%-", "%%%-")
  escaped = escaped:gsub("%^", "%%%^")
  escaped = escaped:gsub("%$", "%%%$")
  escaped = escaped:gsub("%(", "%%%(")
  escaped = escaped:gsub("%)", "%%%)")
  escaped = escaped:gsub("%+", "%%%+")

  local placeholder = "\001DOUBLESTAR\001"
  escaped = escaped:gsub("%*%*", placeholder)
  escaped = escaped:gsub("%*", "[^/]*")
  escaped = escaped:gsub("%?", "[^/]")
  escaped = escaped:gsub(placeholder, ".*")

  if escaped:sub(1, 1) == "/" then
    escaped = "^" .. escaped:sub(2)
  end

  escaped = escaped .. "$"

  return escaped
end

---Check if filepath matches a glob pattern (handles basename matching for patterns without /)
---@param filepath string The file path to check
---@param pattern string The glob pattern
---@return boolean matches True if filepath matches
function M.matches_glob(filepath, pattern)
  local lua_pattern = M.glob_to_lua_pattern(pattern)

  if filepath:match(lua_pattern) then
    return true
  end

  if not pattern:match("/") then
    local basename = filepath:match("[^/]+$") or filepath
    if basename:match(lua_pattern) then
      return true
    end
  end

  if pattern:match("/%*$") then
    local dir_prefix = pattern:gsub("/%*$", "/")
    if filepath:sub(1, #dir_prefix) == dir_prefix then
      return true
    end
  end

  return false
end

---Check if file should be excluded by patterns
---@param filepath string The file path to check
---@param exclude_patterns string[]|nil List of glob patterns to exclude
---@return boolean should_exclude True if file should be excluded
function M.should_exclude_file(filepath, exclude_patterns)
  if not exclude_patterns or #exclude_patterns == 0 then
    return false
  end

  local normalized_path = filepath:gsub("\\", "/")

  for _, pattern in ipairs(exclude_patterns) do
    if M.matches_glob(normalized_path, pattern) then
      return true
    end
  end

  return false
end

---Filter diff content to exclude file patterns
---@param diff_content string The original diff content
---@param exclude_patterns string[]|nil List of glob patterns to exclude
---@return string filtered_diff The filtered diff content
function M.filter_diff(diff_content, exclude_patterns)
  if not exclude_patterns or #exclude_patterns == 0 then
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
      skip_current_file = M.should_exclude_file(current_file, exclude_patterns)
      if skip_current_file then
        table.insert(excluded_files, current_file)
      end
    end

    local plus_file = line:match("^%+%+%+ b/(.*)")
    local minus_file = line:match("^%-%-%-a/(.*)")
    if plus_file then
      current_file = plus_file
      table.insert(all_files, current_file)
      skip_current_file = M.should_exclude_file(current_file, exclude_patterns)
      if skip_current_file then
        table.insert(excluded_files, current_file)
      end
    elseif minus_file then
      current_file = minus_file
      table.insert(all_files, current_file)
      skip_current_file = M.should_exclude_file(current_file, exclude_patterns)
      if skip_current_file then
        table.insert(excluded_files, current_file)
      end
    end

    if not skip_current_file then
      table.insert(filtered_lines, line)
    end
  end

  if #all_files > 0 and #excluded_files >= #all_files then
    return diff_content
  end

  return table.concat(filtered_lines, "\n")
end

---Parse commit line from git log output
---@param line string Git log output line (format: hash subject)
---@return table|nil commit Parsed commit {hash, subject} or nil
function M.parse_commit_line(line)
  local trimmed = M.trim(line)
  if trimmed == "" then
    return nil
  end
  local hash, subject = trimmed:match("^(%S+)%s+(.*)$")
  if hash and subject then
    return { hash = hash, subject = subject }
  end
  return nil
end

---Extract file paths from diff header lines
---@param diff_content string The diff content
---@return string[] files List of file paths mentioned in diff
function M.extract_diff_files(diff_content)
  local files = {}
  local seen = {}

  for line in diff_content:gmatch("[^\r\n]+") do
    local file_match = line:match("^diff %-%-git a/(.*) b/")
    if file_match and not seen[file_match] then
      table.insert(files, file_match)
      seen[file_match] = true
    end
  end

  return files
end

---Validate conventional commit message format
---@param message string The commit message
---@return boolean valid True if message follows conventional commits
---@return string|nil type The commit type (feat, fix, etc.) or nil if invalid
function M.parse_conventional_commit(message)
  local type_match = message:match("^(%w+)%(.*%):") or message:match("^(%w+):")
  if type_match then
    return true, type_match
  end
  return false, nil
end

---Group commits by conventional commit type
---@param commits table[] Array of commits with subject field
---@return table groups Table with keys: features, fixes, others
function M.group_commits_by_type(commits)
  local features = {}
  local fixes = {}
  local others = {}

  for _, commit in ipairs(commits) do
    local _, type_match = M.parse_conventional_commit(commit.subject or "")
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

  return {
    features = features,
    fixes = fixes,
    others = others,
  }
end

---Check if running on Windows
---@return boolean
function M.is_windows()
  return vim.loop.os_uname().sysname == "Windows_NT"
end

---Quote a string for shell command (cross-platform)
---@param str string The string to quote
---@param force_windows? boolean Force Windows quoting style (for testing)
---@return string quoted The quoted string
function M.shell_quote(str, force_windows)
  local is_win = force_windows or M.is_windows()
  if is_win then
    return '"' .. str:gsub('"', '\\"') .. '"'
  else
    return "'" .. str:gsub("'", "'\\''") .. "'"
  end
end

---Quote a string for Unix shell
---@param str string The string to quote
---@return string quoted The quoted string
function M.shell_quote_unix(str)
  return "'" .. str:gsub("'", "'\\''") .. "'"
end

---Quote a string for Windows CMD
---@param str string The string to quote
---@return string quoted The quoted string
function M.shell_quote_windows(str)
  return '"' .. str:gsub('"', '\\"') .. '"'
end

---Clean commit message by removing markdown code blocks and extra formatting
---@param message string Raw message from LLM
---@return string cleaned_message The cleaned commit message
function M.clean_commit_message(message)
  local cleaned = vim.trim(message)
  cleaned = cleaned:gsub("^```+%w*\n?", "")
  cleaned = cleaned:gsub("\n?```+$", "")
  cleaned = vim.trim(cleaned)
  return cleaned
end

---Build commit message prompt with optional history context
---@param diff string The git diff content
---@param lang string The target language for the commit message
---@param commit_history? string[] Recent commit messages for context
---@return string prompt The formatted prompt
function M.build_commit_prompt(diff, lang, commit_history)
  local history_context = ""
  if commit_history and #commit_history > 0 then
    history_context = "\nRECENT COMMIT HISTORY (for style reference):\n"
    for i, commit_msg in ipairs(commit_history) do
      history_context = history_context .. string.format("%d. %s\n", i, commit_msg)
    end
    history_context = history_context
      .. "\nAnalyze commit history to understand project style, tone, and format patterns. Use this for consistency.\n"
  end

  return string.format(
    [[You are a commit message generator. Generate exactly ONE Conventional Commit message for the provided git diff.%s

FORMAT:
type(scope): specific description of WHAT changed

[Optional body - only for non-obvious changes]

Allowed types: feat, fix, docs, style, refactor, perf, test, chore
Language: %s

CRITICAL RULES:
1. Respond with ONLY the commit message - no markdown blocks, no explanations
2. Description must state WHAT was done, not WHY or the effect
3. AVOID vague verbs: "update", "improve", "clarify", "adjust", "enhance", "fix issues"
   USE specific verbs: "add", "remove", "rename", "move", "replace", "extract", "inline"
4. Subject line under 50 chars, body lines under 72 chars
5. Body is OPTIONAL - omit if subject is self-explanatory

DIFF:
%s]],
    history_context,
    lang or "English",
    diff
  )
end

return M
