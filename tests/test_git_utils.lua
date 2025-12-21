local h = require("tests.helpers")
local new_set = MiniTest.new_set

local child = MiniTest.new_child_neovim()

local T = new_set({
  hooks = {
    pre_case = function()
      h.child_start(child)
    end,
    post_once = child.stop,
  },
})

T["trim"] = new_set()

T["trim"]["removes leading whitespace"] = function()
  local result = child.lua([[
    local GitUtils = require("codecompanion._extensions.gitcommit.git_utils")
    return GitUtils.trim("  hello")
  ]])
  h.eq("hello", result)
end

T["trim"]["removes trailing whitespace"] = function()
  local result = child.lua([[
    local GitUtils = require("codecompanion._extensions.gitcommit.git_utils")
    return GitUtils.trim("hello  ")
  ]])
  h.eq("hello", result)
end

T["trim"]["removes both leading and trailing whitespace"] = function()
  local result = child.lua([[
    local GitUtils = require("codecompanion._extensions.gitcommit.git_utils")
    return GitUtils.trim("  hello world  ")
  ]])
  h.eq("hello world", result)
end

T["trim"]["handles empty string"] = function()
  local result = child.lua([[
    local GitUtils = require("codecompanion._extensions.gitcommit.git_utils")
    return GitUtils.trim("")
  ]])
  h.eq("", result)
end

T["glob_to_lua_pattern"] = new_set()

T["glob_to_lua_pattern"]["converts simple extension pattern"] = function()
  local result = child.lua([[
    local GitUtils = require("codecompanion._extensions.gitcommit.git_utils")
    local pattern = GitUtils.glob_to_lua_pattern("*.lua")
    return ("test.lua"):match(pattern) ~= nil
  ]])
  h.eq(true, result)
end

T["glob_to_lua_pattern"]["does not match wrong extension"] = function()
  local result = child.lua([[
    local GitUtils = require("codecompanion._extensions.gitcommit.git_utils")
    local pattern = GitUtils.glob_to_lua_pattern("*.lua")
    return ("test.js"):match(pattern) ~= nil
  ]])
  h.eq(false, result)
end

T["glob_to_lua_pattern"]["handles double star pattern"] = function()
  local result = child.lua([[
    local GitUtils = require("codecompanion._extensions.gitcommit.git_utils")
    local pattern = GitUtils.glob_to_lua_pattern("**/*.js")
    return ("src/components/Button.js"):match(pattern) ~= nil
  ]])
  h.eq(true, result)
end

T["glob_to_lua_pattern"]["handles directory pattern"] = function()
  local result = child.lua([[
    local GitUtils = require("codecompanion._extensions.gitcommit.git_utils")
    local pattern = GitUtils.glob_to_lua_pattern("dist/*")
    return ("dist/bundle.js"):match(pattern) ~= nil
  ]])
  h.eq(true, result)
end

T["glob_to_lua_pattern"]["escapes special regex characters"] = function()
  local result = child.lua([[
    local GitUtils = require("codecompanion._extensions.gitcommit.git_utils")
    local pattern = GitUtils.glob_to_lua_pattern("*.min.js")
    return ("app.min.js"):match(pattern) ~= nil
  ]])
  h.eq(true, result)
end

T["glob_to_lua_pattern"]["escapes square brackets"] = function()
  local result = child.lua([[
    local GitUtils = require("codecompanion._extensions.gitcommit.git_utils")
    local pattern = GitUtils.glob_to_lua_pattern("test[1].lua")
    return ("test[1].lua"):match(pattern) ~= nil
  ]])
  h.eq(true, result)
end

T["glob_to_lua_pattern"]["escapes square brackets in complex pattern"] = function()
  local result = child.lua([[
    local GitUtils = require("codecompanion._extensions.gitcommit.git_utils")
    local pattern = GitUtils.glob_to_lua_pattern("files[0-9].txt")
    local matches_literal = ("files[0-9].txt"):match(pattern) ~= nil
    local no_match_digit = ("files5.txt"):match(pattern) == nil
    return matches_literal and no_match_digit
  ]])
  h.eq(true, result)
end

T["matches_glob"] = new_set()

T["matches_glob"]["matches simple file extension"] = function()
  local result = child.lua([[
    local GitUtils = require("codecompanion._extensions.gitcommit.git_utils")
    return GitUtils.matches_glob("test.lua", "*.lua")
  ]])
  h.eq(true, result)
end

T["matches_glob"]["matches file in subdirectory with basename pattern"] = function()
  local result = child.lua([[
    local GitUtils = require("codecompanion._extensions.gitcommit.git_utils")
    return GitUtils.matches_glob("src/test.lua", "*.lua")
  ]])
  h.eq(true, result)
end

T["matches_glob"]["matches deep nested path with double star"] = function()
  local result = child.lua([[
    local GitUtils = require("codecompanion._extensions.gitcommit.git_utils")
    return GitUtils.matches_glob("src/components/ui/Button.tsx", "**/*.tsx")
  ]])
  h.eq(true, result)
end

T["matches_glob"]["matches directory prefix"] = function()
  local result = child.lua([[
    local GitUtils = require("codecompanion._extensions.gitcommit.git_utils")
    return GitUtils.matches_glob("node_modules/lodash/index.js", "node_modules/*")
  ]])
  h.eq(true, result)
end

T["matches_glob"]["does not match unrelated path"] = function()
  local result = child.lua([[
    local GitUtils = require("codecompanion._extensions.gitcommit.git_utils")
    return GitUtils.matches_glob("src/main.lua", "*.js")
  ]])
  h.eq(false, result)
end

T["matches_glob"]["handles package-lock.json specifically"] = function()
  local result = child.lua([[
    local GitUtils = require("codecompanion._extensions.gitcommit.git_utils")
    return GitUtils.matches_glob("package-lock.json", "package-lock.json")
  ]])
  h.eq(true, result)
end

T["matches_glob"]["handles windows path separators"] = function()
  local result = child.lua([[
    local GitUtils = require("codecompanion._extensions.gitcommit.git_utils")
    return GitUtils.matches_glob("src\\test.lua", "*.lua")
  ]])
  h.eq(true, result)
end

T["should_exclude_file"] = new_set()

T["should_exclude_file"]["returns false when no patterns"] = function()
  local result = child.lua([[
    local GitUtils = require("codecompanion._extensions.gitcommit.git_utils")
    return GitUtils.should_exclude_file("test.lua", nil)
  ]])
  h.eq(false, result)
end

T["should_exclude_file"]["returns false when empty patterns"] = function()
  local result = child.lua([[
    local GitUtils = require("codecompanion._extensions.gitcommit.git_utils")
    return GitUtils.should_exclude_file("test.lua", {})
  ]])
  h.eq(false, result)
end

T["should_exclude_file"]["excludes matching file"] = function()
  local result = child.lua([[
    local GitUtils = require("codecompanion._extensions.gitcommit.git_utils")
    return GitUtils.should_exclude_file("package-lock.json", {"package-lock.json", "yarn.lock"})
  ]])
  h.eq(true, result)
end

T["should_exclude_file"]["excludes file matching extension pattern"] = function()
  local result = child.lua([[
    local GitUtils = require("codecompanion._extensions.gitcommit.git_utils")
    return GitUtils.should_exclude_file("app.min.js", {"*.min.js", "*.min.css"})
  ]])
  h.eq(true, result)
end

T["should_exclude_file"]["excludes file in excluded directory"] = function()
  local result = child.lua([[
    local GitUtils = require("codecompanion._extensions.gitcommit.git_utils")
    return GitUtils.should_exclude_file("node_modules/lodash/index.js", {"node_modules/*"})
  ]])
  h.eq(true, result)
end

T["should_exclude_file"]["does not exclude unmatched file"] = function()
  local result = child.lua([[
    local GitUtils = require("codecompanion._extensions.gitcommit.git_utils")
    return GitUtils.should_exclude_file("src/main.lua", {"*.js", "*.min.css", "node_modules/*"})
  ]])
  h.eq(false, result)
end

T["should_exclude_file"]["normalizes windows paths"] = function()
  local result = child.lua([[
    local GitUtils = require("codecompanion._extensions.gitcommit.git_utils")
    return GitUtils.should_exclude_file("src\\app.min.js", {"*.min.js"})
  ]])
  h.eq(true, result)
end

T["filter_diff"] = new_set()

T["filter_diff"]["returns original when no patterns"] = function()
  local result = child.lua([[
    local GitUtils = require("codecompanion._extensions.gitcommit.git_utils")
    local diff = "diff --git a/test.lua b/test.lua\n+hello"
    return GitUtils.filter_diff(diff, nil) == diff
  ]])
  h.eq(true, result)
end

T["filter_diff"]["returns original when empty patterns"] = function()
  local result = child.lua([[
    local GitUtils = require("codecompanion._extensions.gitcommit.git_utils")
    local diff = "diff --git a/test.lua b/test.lua\n+hello"
    return GitUtils.filter_diff(diff, {}) == diff
  ]])
  h.eq(true, result)
end

T["filter_diff"]["filters out excluded file"] = function()
  local result = child.lua([[
    local GitUtils = require("codecompanion._extensions.gitcommit.git_utils")
    local diff = "diff --git a/test.lua b/test.lua\n+hello\ndiff --git a/package-lock.json b/package-lock.json\n+lots of deps"
    local filtered = GitUtils.filter_diff(diff, {"package-lock.json"})
    return filtered:find("package%-lock") == nil and filtered:find("test%.lua") ~= nil
  ]])
  h.eq(true, result)
end

T["filter_diff"]["keeps non-excluded files"] = function()
  local result = child.lua([[
    local GitUtils = require("codecompanion._extensions.gitcommit.git_utils")
    local diff = "diff --git a/src/main.lua b/src/main.lua\n+code\ndiff --git a/src/utils.lua b/src/utils.lua\n+more code"
    local filtered = GitUtils.filter_diff(diff, {"*.js"})
    return filtered:find("main%.lua") ~= nil and filtered:find("utils%.lua") ~= nil
  ]])
  h.eq(true, result)
end

T["filter_diff"]["returns empty when all files excluded"] = function()
  local result = child.lua([[
    local GitUtils = require("codecompanion._extensions.gitcommit.git_utils")
    local diff = "diff --git a/package-lock.json b/package-lock.json\n+deps"
    local filtered = GitUtils.filter_diff(diff, {"package-lock.json"})
    return vim.trim(filtered) == ""
  ]])
  h.eq(true, result)
end

T["parse_conventional_commit"] = new_set()

T["parse_conventional_commit"]["parses feat type"] = function()
  local result = child.lua([[
    local GitUtils = require("codecompanion._extensions.gitcommit.git_utils")
    local valid, type_match = GitUtils.parse_conventional_commit("feat(api): add new endpoint")
    return valid and type_match == "feat"
  ]])
  h.eq(true, result)
end

T["parse_conventional_commit"]["parses fix type"] = function()
  local result = child.lua([[
    local GitUtils = require("codecompanion._extensions.gitcommit.git_utils")
    local valid, type_match = GitUtils.parse_conventional_commit("fix: resolve bug")
    return valid and type_match == "fix"
  ]])
  h.eq(true, result)
end

T["parse_conventional_commit"]["parses type with scope"] = function()
  local result = child.lua([[
    local GitUtils = require("codecompanion._extensions.gitcommit.git_utils")
    local valid, type_match = GitUtils.parse_conventional_commit("chore(deps): update dependencies")
    return valid and type_match == "chore"
  ]])
  h.eq(true, result)
end

T["parse_conventional_commit"]["returns false for non-conventional"] = function()
  local result = child.lua([[
    local GitUtils = require("codecompanion._extensions.gitcommit.git_utils")
    local valid, type_match = GitUtils.parse_conventional_commit("Update readme file")
    return not valid and type_match == nil
  ]])
  h.eq(true, result)
end

T["group_commits_by_type"] = new_set()

T["group_commits_by_type"]["groups features correctly"] = function()
  local result = child.lua([[
    local GitUtils = require("codecompanion._extensions.gitcommit.git_utils")
    local commits = {
      { subject = "feat(api): add endpoint" },
      { subject = "fix: bug fix" },
      { subject = "feat: another feature" },
    }
    local groups = GitUtils.group_commits_by_type(commits)
    return #groups.features == 2
  ]])
  h.eq(true, result)
end

T["group_commits_by_type"]["groups fixes correctly"] = function()
  local result = child.lua([[
    local GitUtils = require("codecompanion._extensions.gitcommit.git_utils")
    local commits = {
      { subject = "fix(ui): button color" },
      { subject = "fix: another fix" },
      { subject = "feat: feature" },
    }
    local groups = GitUtils.group_commits_by_type(commits)
    return #groups.fixes == 2
  ]])
  h.eq(true, result)
end

T["group_commits_by_type"]["groups others correctly"] = function()
  local result = child.lua([[
    local GitUtils = require("codecompanion._extensions.gitcommit.git_utils")
    local commits = {
      { subject = "chore: cleanup" },
      { subject = "docs: update readme" },
      { subject = "Update something" },
    }
    local groups = GitUtils.group_commits_by_type(commits)
    return #groups.others == 3 and #groups.features == 0 and #groups.fixes == 0
  ]])
  h.eq(true, result)
end

T["extract_diff_files"] = new_set()

T["extract_diff_files"]["extracts single file"] = function()
  local result = child.lua([[
    local GitUtils = require("codecompanion._extensions.gitcommit.git_utils")
    local diff = "diff --git a/test.lua b/test.lua\n+hello"
    local files = GitUtils.extract_diff_files(diff)
    return #files == 1 and files[1] == "test.lua"
  ]])
  h.eq(true, result)
end

T["extract_diff_files"]["extracts multiple files"] = function()
  local result = child.lua([[
    local GitUtils = require("codecompanion._extensions.gitcommit.git_utils")
    local diff = "diff --git a/src/main.lua b/src/main.lua\n+code\ndiff --git a/src/utils.lua b/src/utils.lua\n+more"
    local files = GitUtils.extract_diff_files(diff)
    return #files == 2
  ]])
  h.eq(true, result)
end

T["extract_diff_files"]["deduplicates files"] = function()
  local result = child.lua([[
    local GitUtils = require("codecompanion._extensions.gitcommit.git_utils")
    local diff = "diff --git a/test.lua b/test.lua\n+line1\ndiff --git a/test.lua b/test.lua\n+line2"
    local files = GitUtils.extract_diff_files(diff)
    return #files == 1
  ]])
  h.eq(true, result)
end

T["extract_diff_files"]["returns empty for no diff headers"] = function()
  local result = child.lua([[
    local GitUtils = require("codecompanion._extensions.gitcommit.git_utils")
    local diff = "+hello\n-world"
    local files = GitUtils.extract_diff_files(diff)
    return #files == 0
  ]])
  h.eq(true, result)
end

T["shell_quote_unix"] = new_set()

T["shell_quote_unix"]["quotes simple string"] = function()
  local result = child.lua([[
    local GitUtils = require("codecompanion._extensions.gitcommit.git_utils")
    return GitUtils.shell_quote_unix("hello")
  ]])
  h.eq("'hello'", result)
end

T["shell_quote_unix"]["escapes single quotes"] = function()
  local result = child.lua([[
    local GitUtils = require("codecompanion._extensions.gitcommit.git_utils")
    return GitUtils.shell_quote_unix("it's")
  ]])
  h.eq("'it'\\''s'", result)
end

T["shell_quote_unix"]["handles multiple single quotes"] = function()
  local result = child.lua([[
    local GitUtils = require("codecompanion._extensions.gitcommit.git_utils")
    return GitUtils.shell_quote_unix("'quoted'")
  ]])
  h.eq("''\\''quoted'\\'''", result)
end

T["shell_quote_unix"]["handles empty string"] = function()
  local result = child.lua([[
    local GitUtils = require("codecompanion._extensions.gitcommit.git_utils")
    return GitUtils.shell_quote_unix("")
  ]])
  h.eq("''", result)
end

T["shell_quote_unix"]["preserves double quotes"] = function()
  local result = child.lua([[
    local GitUtils = require("codecompanion._extensions.gitcommit.git_utils")
    return GitUtils.shell_quote_unix('say "hello"')
  ]])
  h.eq("'say \"hello\"'", result)
end

T["shell_quote_unix"]["handles spaces"] = function()
  local result = child.lua([[
    local GitUtils = require("codecompanion._extensions.gitcommit.git_utils")
    return GitUtils.shell_quote_unix("hello world")
  ]])
  h.eq("'hello world'", result)
end

T["shell_quote_unix"]["handles special characters"] = function()
  local result = child.lua([[
    local GitUtils = require("codecompanion._extensions.gitcommit.git_utils")
    return GitUtils.shell_quote_unix("$PATH && rm -rf /")
  ]])
  h.eq("'$PATH && rm -rf /'", result)
end

T["shell_quote_windows"] = new_set()

T["shell_quote_windows"]["quotes simple string"] = function()
  local result = child.lua([[
    local GitUtils = require("codecompanion._extensions.gitcommit.git_utils")
    return GitUtils.shell_quote_windows("hello")
  ]])
  h.eq('"hello"', result)
end

T["shell_quote_windows"]["escapes double quotes"] = function()
  local result = child.lua([[
    local GitUtils = require("codecompanion._extensions.gitcommit.git_utils")
    return GitUtils.shell_quote_windows('say "hello"')
  ]])
  h.eq('"say \\"hello\\""', result)
end

T["shell_quote_windows"]["handles multiple double quotes"] = function()
  local result = child.lua([[
    local GitUtils = require("codecompanion._extensions.gitcommit.git_utils")
    return GitUtils.shell_quote_windows('"quoted"')
  ]])
  h.eq('"\\"quoted\\""', result)
end

T["shell_quote_windows"]["handles empty string"] = function()
  local result = child.lua([[
    local GitUtils = require("codecompanion._extensions.gitcommit.git_utils")
    return GitUtils.shell_quote_windows("")
  ]])
  h.eq('""', result)
end

T["shell_quote_windows"]["preserves single quotes"] = function()
  local result = child.lua([[
    local GitUtils = require("codecompanion._extensions.gitcommit.git_utils")
    return GitUtils.shell_quote_windows("it's")
  ]])
  h.eq('"it\'s"', result)
end

T["shell_quote_windows"]["handles spaces"] = function()
  local result = child.lua([[
    local GitUtils = require("codecompanion._extensions.gitcommit.git_utils")
    return GitUtils.shell_quote_windows("hello world")
  ]])
  h.eq('"hello world"', result)
end

T["is_windows"] = new_set()

T["is_windows"]["returns boolean"] = function()
  local result = child.lua([[
    local GitUtils = require("codecompanion._extensions.gitcommit.git_utils")
    return type(GitUtils.is_windows()) == "boolean"
  ]])
  h.eq(true, result)
end

return T
