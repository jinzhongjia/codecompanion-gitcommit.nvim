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

-- =============================================================================
-- Git.setup and Git.get_config
-- =============================================================================

T["setup"] = new_set()

T["setup"]["sets default config when no opts provided"] = function()
  local result = child.lua([[
    local Git = require("codecompanion._extensions.gitcommit.git")
    Git.setup()
    local config = Git.get_config()
    return {
      has_exclude_files = type(config.exclude_files) == "table",
      use_commit_history = config.use_commit_history,
      commit_history_count = config.commit_history_count,
    }
  ]])
  h.eq(true, result.has_exclude_files)
  h.eq(true, result.use_commit_history)
  h.eq(10, result.commit_history_count)
end

T["setup"]["merges custom options"] = function()
  local result = child.lua([[
    local Git = require("codecompanion._extensions.gitcommit.git")
    Git.setup({
      exclude_files = { "*.log", "*.tmp" },
      commit_history_count = 20,
    })
    local config = Git.get_config()
    return {
      exclude_files = config.exclude_files,
      commit_history_count = config.commit_history_count,
    }
  ]])
  h.eq({ "*.log", "*.tmp" }, result.exclude_files)
  h.eq(20, result.commit_history_count)
end

T["setup"]["preserves defaults for unspecified options"] = function()
  local result = child.lua([[
    local Git = require("codecompanion._extensions.gitcommit.git")
    Git.setup({ commit_history_count = 5 })
    local config = Git.get_config()
    return config.use_commit_history
  ]])
  h.eq(true, result)
end

T["get_config"] = new_set()

T["get_config"]["returns deep copy"] = function()
  local result = child.lua([[
    local Git = require("codecompanion._extensions.gitcommit.git")
    Git.setup({ exclude_files = { "*.log" } })
    local config1 = Git.get_config()
    config1.exclude_files[1] = "modified"
    local config2 = Git.get_config()
    return config2.exclude_files[1]
  ]])
  h.eq("*.log", result)
end

-- =============================================================================
-- Git._should_exclude_file
-- =============================================================================

T["_should_exclude_file"] = new_set()

T["_should_exclude_file"]["returns false when no exclusions configured"] = function()
  local result = child.lua([[
    local Git = require("codecompanion._extensions.gitcommit.git")
    Git.setup({ exclude_files = {} })
    return Git._should_exclude_file("test.lua")
  ]])
  h.eq(false, result)
end

T["_should_exclude_file"]["matches simple extension pattern"] = function()
  local result = child.lua([[
    local Git = require("codecompanion._extensions.gitcommit.git")
    Git.setup({ exclude_files = { "*.log" } })
    return Git._should_exclude_file("debug.log")
  ]])
  h.eq(true, result)
end

T["_should_exclude_file"]["does not match non-matching extension"] = function()
  local result = child.lua([[
    local Git = require("codecompanion._extensions.gitcommit.git")
    Git.setup({ exclude_files = { "*.log" } })
    return Git._should_exclude_file("main.lua")
  ]])
  h.eq(false, result)
end

T["_should_exclude_file"]["matches directory pattern"] = function()
  local result = child.lua([[
    local Git = require("codecompanion._extensions.gitcommit.git")
    Git.setup({ exclude_files = { "node_modules/*" } })
    return Git._should_exclude_file("node_modules/package/index.js")
  ]])
  h.eq(true, result)
end

T["_should_exclude_file"]["matches exact filename"] = function()
  local result = child.lua([[
    local Git = require("codecompanion._extensions.gitcommit.git")
    Git.setup({ exclude_files = { "package-lock.json" } })
    return Git._should_exclude_file("package-lock.json")
  ]])
  h.eq(true, result)
end

T["_should_exclude_file"]["matches multiple patterns"] = function()
  local result = child.lua([[
    local Git = require("codecompanion._extensions.gitcommit.git")
    Git.setup({ exclude_files = { "*.log", "*.tmp", "dist/*" } })
    return {
      log = Git._should_exclude_file("error.log"),
      tmp = Git._should_exclude_file("cache.tmp"),
      dist = Git._should_exclude_file("dist/bundle.js"),
      lua = Git._should_exclude_file("main.lua"),
    }
  ]])
  h.eq(true, result.log)
  h.eq(true, result.tmp)
  h.eq(true, result.dist)
  h.eq(false, result.lua)
end

T["_should_exclude_file"]["matches double star pattern"] = function()
  local result = child.lua([[
    local Git = require("codecompanion._extensions.gitcommit.git")
    Git.setup({ exclude_files = { "**/*.min.js" } })
    return {
      root = Git._should_exclude_file("app.min.js"),
      nested = Git._should_exclude_file("src/lib/utils.min.js"),
      non_min = Git._should_exclude_file("src/app.js"),
    }
  ]])
  h.eq(true, result.root)
  h.eq(true, result.nested)
  h.eq(false, result.non_min)
end

-- =============================================================================
-- Git._filter_diff
-- =============================================================================

T["_filter_diff"] = new_set()

T["_filter_diff"]["returns original diff when no exclusions"] = function()
  local result = child.lua([=[
    local Git = require("codecompanion._extensions.gitcommit.git")
    Git.setup({ exclude_files = {} })
    local diff = [[
diff --git a/main.lua b/main.lua
index 123..456 789
--- a/main.lua
+++ b/main.lua
@@ -1,3 +1,4 @@
+local M = {}
 return M
]]
    return Git._filter_diff(diff) == diff
  ]=])
  h.eq(true, result)
end

T["_filter_diff"]["filters out excluded files"] = function()
  local result = child.lua([=[
    local Git = require("codecompanion._extensions.gitcommit.git")
    Git.setup({ exclude_files = { "*.log" } })
    local diff = [[
diff --git a/main.lua b/main.lua
--- a/main.lua
+++ b/main.lua
@@ -1 +1 @@
-old
+new
diff --git a/debug.log b/debug.log
--- a/debug.log
+++ b/debug.log
@@ -1 +1 @@
-log1
+log2
]]
    local filtered = Git._filter_diff(diff)
    return {
      has_main = filtered:find("main.lua") ~= nil,
      has_log = filtered:find("debug.log") ~= nil,
    }
  ]=])
  h.eq(true, result.has_main)
  h.eq(false, result.has_log)
end

T["_filter_diff"]["handles empty diff"] = function()
  local result = child.lua([[
    local Git = require("codecompanion._extensions.gitcommit.git")
    Git.setup({ exclude_files = { "*.log" } })
    return Git._filter_diff("")
  ]])
  h.eq("", result)
end

T["_filter_diff"]["filters multiple excluded patterns"] = function()
  local result = child.lua([=[
    local Git = require("codecompanion._extensions.gitcommit.git")
    Git.setup({ exclude_files = { "*.log", "*.min.js", "package-lock.json" } })
    local diff = [[
diff --git a/src/app.lua b/src/app.lua
--- a/src/app.lua
+++ b/src/app.lua
@@ -1 +1 @@
-a
+b
diff --git a/error.log b/error.log
--- a/error.log
+++ b/error.log
@@ -1 +1 @@
-x
+y
diff --git a/dist/bundle.min.js b/dist/bundle.min.js
--- a/dist/bundle.min.js
+++ b/dist/bundle.min.js
@@ -1 +1 @@
-old
+new
diff --git a/package-lock.json b/package-lock.json
--- a/package-lock.json
+++ b/package-lock.json
@@ -1 +1 @@
-{}
+{"a":1}
]]
    local filtered = Git._filter_diff(diff)
    return {
      has_app = filtered:find("app.lua") ~= nil,
      has_log = filtered:find("error.log") ~= nil,
      has_min = filtered:find("bundle.min.js") ~= nil,
      has_lock = filtered:find("package%-lock.json") ~= nil,
    }
  ]=])
  h.eq(true, result.has_app)
  h.eq(false, result.has_log)
  h.eq(false, result.has_min)
  h.eq(false, result.has_lock)
end

T["_filter_diff"]["preserves diff format"] = function()
  local result = child.lua([=[
    local Git = require("codecompanion._extensions.gitcommit.git")
    Git.setup({ exclude_files = { "*.log" } })
    local diff = [[
diff --git a/main.lua b/main.lua
index abc123..def456 100644
--- a/main.lua
+++ b/main.lua
@@ -1,5 +1,6 @@
 local M = {}
+M.version = "1.0"
 return M
]]
    local filtered = Git._filter_diff(diff)
    return {
      has_diff_header = filtered:find("diff %-%-git") ~= nil,
      has_index = filtered:find("index") ~= nil,
      has_hunk = filtered:find("@@") ~= nil,
      has_addition = filtered:find("%+M.version") ~= nil,
    }
  ]=])
  h.eq(true, result.has_diff_header)
  h.eq(true, result.has_index)
  h.eq(true, result.has_hunk)
  h.eq(true, result.has_addition)
end

T["_filter_diff"]["handles path with spaces"] = function()
  local result = child.lua([=[
    local Git = require("codecompanion._extensions.gitcommit.git")
    Git.setup({ exclude_files = {} })
    local diff = [[
diff --git a/path with spaces/file.lua b/path with spaces/file.lua
--- a/path with spaces/file.lua
+++ b/path with spaces/file.lua
@@ -1 +1 @@
-old
+new
]]
    local filtered = Git._filter_diff(diff)
    return filtered:find("path with spaces") ~= nil
  ]=])
  h.eq(true, result)
end

T["_filter_diff"]["returns empty when all files excluded"] = function()
  local result = child.lua([=[
    local Git = require("codecompanion._extensions.gitcommit.git")
    Git.setup({ exclude_files = { "*.log", "*.tmp" } })
    local diff = [[
diff --git a/error.log b/error.log
--- a/error.log
+++ b/error.log
@@ -1 +1 @@
-a
+b
diff --git a/cache.tmp b/cache.tmp
--- a/cache.tmp
+++ b/cache.tmp
@@ -1 +1 @@
-x
+y
]]
    local filtered = Git._filter_diff(diff)
    return vim.trim(filtered)
  ]=])
  h.eq("", result)
end

-- =============================================================================
-- Git.get_contextual_diff
-- =============================================================================

T["get_contextual_diff"] = new_set()

T["get_contextual_diff"]["returns staged diff when available"] = function()
  local result = child.lua([[
    local Git = require("codecompanion._extensions.gitcommit.git")
    Git.is_repository = function() return true end
    Git.is_amending = function() return false end
    Git._filter_diff = function(diff) return diff end
    vim.fn.system = function(cmd)
      if cmd == "git diff --no-ext-diff --staged" then
        return "diff content"
      end
      return ""
    end
    local diff, context = Git.get_contextual_diff()
    return { diff, context }
  ]])
  h.eq("diff content", result[1])
  h.eq("staged", result[2])
end

T["get_contextual_diff"]["returns amend with parent diff"] = function()
  local result = child.lua([[
    local Git = require("codecompanion._extensions.gitcommit.git")
    Git.is_repository = function() return true end
    Git.is_amending = function() return true end
    Git._filter_diff = function(diff) return diff end
    vim.fn.system = function(cmd)
      if cmd == "git diff --no-ext-diff --staged" then
        return ""
      end
      if cmd == "git diff --no-ext-diff HEAD~1" then
        return "amend parent diff"
      end
      return ""
    end
    local diff, context = Git.get_contextual_diff()
    return { diff, context }
  ]])
  h.eq("amend parent diff", result[1])
  h.eq("amend_with_parent", result[2])
end

T["get_contextual_diff"]["returns amend initial diff"] = function()
  local result = child.lua([[
    local Git = require("codecompanion._extensions.gitcommit.git")
    Git.is_repository = function() return true end
    Git.is_amending = function() return true end
    Git._filter_diff = function(diff) return diff end
    vim.fn.system = function(cmd)
      if cmd == "git diff --no-ext-diff --staged" then
        return ""
      end
      if cmd == "git diff --no-ext-diff HEAD~1" then
        return ""
      end
      if cmd == "git show --no-ext-diff --format= HEAD" then
        return "amend initial diff"
      end
      return ""
    end
    local diff, context = Git.get_contextual_diff()
    return { diff, context }
  ]])
  h.eq("amend initial diff", result[1])
  h.eq("amend_initial", result[2])
end

T["get_contextual_diff"]["returns unstaged diff when no staged"] = function()
  local result = child.lua([[
    local Git = require("codecompanion._extensions.gitcommit.git")
    Git.is_repository = function() return true end
    Git.is_amending = function() return false end
    Git._filter_diff = function(diff) return diff end
    vim.fn.system = function(cmd)
      if cmd == "git diff --no-ext-diff --staged" then
        return ""
      end
      if cmd == "git diff --no-ext-diff HEAD" then
        return "unstaged diff"
      end
      return ""
    end
    local diff, context = Git.get_contextual_diff()
    return { diff, context }
  ]])
  h.eq("unstaged diff", result[1])
  h.eq("unstaged_or_all_local", result[2])
end

T["get_contextual_diff"]["falls back to git diff when HEAD missing"] = function()
  local result = child.lua([[
    local Git = require("codecompanion._extensions.gitcommit.git")
    Git.is_repository = function() return true end
    Git.is_amending = function() return false end
    Git._filter_diff = function(diff) return diff end

    local orig = vim.fn.system
    local fail_cmd = (vim.fn.has("win32") == 1 or vim.fn.has("win64") == 1) and "cmd /c exit /b 1" or "false"
    local ok_cmd = (vim.fn.has("win32") == 1 or vim.fn.has("win64") == 1) and "cmd /c exit /b 0" or "true"

    vim.fn.system = function(cmd)
      if cmd == "git diff --no-ext-diff --staged" then
        orig(ok_cmd)
        return ""
      end
      if cmd == "git diff --no-ext-diff HEAD" then
        orig(fail_cmd)
        return ""
      end
      if cmd == "git diff --no-ext-diff" then
        orig(ok_cmd)
        return "unstaged diff"
      end
      return ""
    end

    local diff, context = Git.get_contextual_diff()
    return { diff, context }
  ]])
  h.eq("unstaged diff", result[1])
  h.eq("unstaged_or_all_local", result[2])
end

T["get_contextual_diff"]["returns no changes after filter"] = function()
  local result = child.lua([[
    local Git = require("codecompanion._extensions.gitcommit.git")
    Git.is_repository = function() return true end
    Git.is_amending = function() return false end
    Git._filter_diff = function() return "" end
    vim.fn.system = function(cmd)
      if cmd == "git diff --no-ext-diff --staged" then
        return "diff content"
      end
      return ""
    end
    local diff, context = Git.get_contextual_diff()
    return { diff, context }
  ]])
  h.eq(vim.NIL, result[1])
  h.eq("no_changes_after_filter", result[2])
end

T["get_contextual_diff"]["returns no changes"] = function()
  local result = child.lua([[
    local Git = require("codecompanion._extensions.gitcommit.git")
    Git.is_repository = function() return true end
    Git.is_amending = function() return false end
    Git._filter_diff = function(diff) return diff end
    vim.fn.system = function(_cmd)
      return ""
    end
    local diff, context = Git.get_contextual_diff()
    return { diff, context }
  ]])
  h.eq(vim.NIL, result[1])
  h.eq("no_changes", result[2])
end

T["get_contextual_diff"]["returns git operation failed on error"] = function()
  local result = child.lua([[
    local Git = require("codecompanion._extensions.gitcommit.git")
    Git.is_repository = function() return true end
    vim.fn.system = function()
      error("boom")
    end
    local diff, context = Git.get_contextual_diff()
    return { diff, context }
  ]])
  h.eq(vim.NIL, result[1])
  h.eq("git_operation_failed", result[2])
end

-- =============================================================================
-- Git.get_commit_history
-- =============================================================================

T["get_commit_history"] = new_set()

T["get_commit_history"]["returns nil when not in repo"] = function()
  local result = child.lua([[
    local Git = require("codecompanion._extensions.gitcommit.git")
    Git.is_repository = function() return false end
    return Git.get_commit_history(5)
  ]])
  h.eq(vim.NIL, result)
end

T["get_commit_history"]["returns trimmed commit messages"] = function()
  local result = child.lua([[
    local Git = require("codecompanion._extensions.gitcommit.git")
    Git.is_repository = function() return true end
    vim.fn.system = function(_cmd)
      return "feat: one\n\nfix: two\n   \n"
    end
    return Git.get_commit_history(5)
  ]])
  h.eq({ "feat: one", "fix: two" }, result)
end

-- =============================================================================
-- Git.is_repository cache
-- =============================================================================

T["is_repository_cache"] = new_set()

T["is_repository_cache"]["uses cached result within ttl"] = function()
  local result = child.lua([[
    package.loaded["codecompanion._extensions.gitcommit.git"] = nil
    local Git = require("codecompanion._extensions.gitcommit.git")

    local calls = 0
    vim.fn.getcwd = function() return "/tmp/repo" end
    vim.uv.now = function() return 1000 end
    vim.uv.fs_stat = function(path)
      if path:match("%.git$") then
        calls = calls + 1
        return {}
      end
      return nil
    end

    local first = Git.is_repository()
    local second = Git.is_repository()
    return { first = first, second = second, calls = calls }
  ]])
  h.eq(true, result.first)
  h.eq(true, result.second)
  h.eq(1, result.calls)
end

T["is_repository_cache"]["refreshes after ttl expiry"] = function()
  local result = child.lua([[
    package.loaded["codecompanion._extensions.gitcommit.git"] = nil
    local Git = require("codecompanion._extensions.gitcommit.git")

    local calls = 0
    local times = { 0, 2000 }
    local idx = 0
    vim.fn.getcwd = function() return "/tmp/repo" end
    vim.uv.now = function()
      idx = idx + 1
      return times[idx] or 3000
    end
    vim.uv.fs_stat = function(path)
      if path:match("%.git$") then
        calls = calls + 1
        return {}
      end
      return nil
    end

    local first = Git.is_repository()
    local second = Git.is_repository()
    return { first = first, second = second, calls = calls }
  ]])
  h.eq(true, result.first)
  h.eq(true, result.second)
  h.eq(2, result.calls)
end

T["is_repository_fallback"] = new_set()

T["is_repository_fallback"]["returns true when git rev-parse says true"] = function()
  local result = child.lua([[
    package.loaded["codecompanion._extensions.gitcommit.git"] = nil
    local Git = require("codecompanion._extensions.gitcommit.git")

    local orig_system = vim.fn.system
    vim.fn.getcwd = function() return "/tmp/no_repo" end
    vim.uv.fs_stat = function(_) return nil end
    vim.fn.system = function(_cmd)
      local ok_cmd = (vim.fn.has("win32") == 1 or vim.fn.has("win64") == 1)
        and "cmd /c exit /b 0"
        or "true"
      orig_system(ok_cmd)
      return "true"
    end

    local result = Git.is_repository()
    vim.fn.system = orig_system
    return result
  ]])
  h.eq(true, result)
end

T["is_repository_fallback"]["returns false when git rev-parse fails"] = function()
  local result = child.lua([[
    package.loaded["codecompanion._extensions.gitcommit.git"] = nil
    local Git = require("codecompanion._extensions.gitcommit.git")

    local orig_system = vim.fn.system
    vim.fn.getcwd = function() return "/tmp/no_repo" end
    vim.uv.fs_stat = function(_) return nil end
    vim.fn.system = function(_cmd)
      local fail_cmd = (vim.fn.has("win32") == 1 or vim.fn.has("win64") == 1)
        and "cmd /c exit /b 1"
        or "false"
      orig_system(fail_cmd)
      return "false"
    end

    local result = Git.is_repository()
    vim.fn.system = orig_system
    return result
  ]])
  h.eq(false, result)
end

-- =============================================================================
-- Git.get_staged_diff
-- =============================================================================

T["get_staged_diff"] = new_set()

T["get_staged_diff"]["returns staged diff when present"] = function()
  local result = child.lua([[
    local Git = require("codecompanion._extensions.gitcommit.git")
    Git.is_repository = function() return true end
    Git.is_amending = function() return false end
    Git._filter_diff = function(diff) return diff end
    vim.fn.system = function(cmd)
      if cmd == "git diff --no-ext-diff --staged" then
        return "staged diff"
      end
      return ""
    end
    return Git.get_staged_diff()
  ]])
  h.eq("staged diff", result)
end

T["get_staged_diff"]["returns amend diff when amending"] = function()
  local result = child.lua([[
    local Git = require("codecompanion._extensions.gitcommit.git")
    Git.is_repository = function() return true end
    Git.is_amending = function() return true end
    Git._filter_diff = function(diff) return diff end
    vim.fn.system = function(cmd)
      if cmd == "git diff --no-ext-diff --staged" then
        return ""
      end
      if cmd == "git diff --no-ext-diff HEAD~1" then
        return "amend diff"
      end
      return ""
    end
    return Git.get_staged_diff()
  ]])
  h.eq("amend diff", result)
end

T["get_staged_diff"]["returns nil when no changes"] = function()
  local result = child.lua([[
    local Git = require("codecompanion._extensions.gitcommit.git")
    Git.is_repository = function() return true end
    Git.is_amending = function() return false end
    vim.fn.system = function(_cmd)
      return ""
    end
    return Git.get_staged_diff()
  ]])
  h.eq(vim.NIL, result)
end

-- =============================================================================
-- Git.commit_changes
-- =============================================================================

T["commit_changes"] = new_set()

T["commit_changes"]["returns false when not in repo"] = function()
  local result = child.lua([[
    local Git = require("codecompanion._extensions.gitcommit.git")
    Git.is_repository = function() return false end
    return Git.commit_changes("feat: test")
  ]])
  h.eq(false, result)
end

T["commit_changes"]["returns false when no diff"] = function()
  local result = child.lua([[
    local Git = require("codecompanion._extensions.gitcommit.git")
    Git.is_repository = function() return true end
    Git.get_contextual_diff = function() return nil, "no_changes" end
    return Git.commit_changes("feat: test")
  ]])
  h.eq(false, result)
end

T["commit_changes"]["commits via system when diff present"] = function()
  local result = child.lua([[
    local Git = require("codecompanion._extensions.gitcommit.git")
    Git.is_repository = function() return true end
    Git.is_amending = function() return false end
    Git.get_contextual_diff = function() return "diff", "staged" end

    local called = nil
    vim.fn.system = function(cmd, input)
      called = { cmd = cmd, input = input }
      return ""
    end
    vim.notify = function() end

    local ok = Git.commit_changes("feat: test")
    return { ok = ok, called = called }
  ]])
  h.eq(true, result.ok)
  h.expect_match("git commit", result.called.cmd)
  h.eq("feat: test", result.called.input)
end

T["commit_changes"]["returns false on git operation failure"] = function()
  local result = child.lua([[
    local Git = require("codecompanion._extensions.gitcommit.git")
    Git.is_repository = function() return true end
    Git.get_contextual_diff = function() return nil, "git_operation_failed" end
    return Git.commit_changes("feat: test")
  ]])
  h.eq(false, result)
end

T["commit_changes"]["returns false when no changes after filter"] = function()
  local result = child.lua([[
    local Git = require("codecompanion._extensions.gitcommit.git")
    Git.is_repository = function() return true end
    Git.get_contextual_diff = function() return nil, "no_changes_after_filter" end
    return Git.commit_changes("feat: test")
  ]])
  h.eq(false, result)
end

T["is_repository_cache"]["invalidates when cwd changes"] = function()
  local result = child.lua([[
    package.loaded["codecompanion._extensions.gitcommit.git"] = nil
    local Git = require("codecompanion._extensions.gitcommit.git")

    local calls = 0
    local cwd = "/tmp/repo1"
    vim.fn.getcwd = function() return cwd end
    vim.uv.now = function() return 1000 end
    vim.uv.fs_stat = function(path)
      if path:match("%.git$") then
        calls = calls + 1
        return {}
      end
      return nil
    end

    local first = Git.is_repository()
    cwd = "/tmp/repo2"
    local second = Git.is_repository()
    return { first = first, second = second, calls = calls }
  ]])
  h.eq(true, result.first)
  h.eq(true, result.second)
  h.eq(2, result.calls)
end

return T
