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

return T
