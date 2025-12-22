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

-- ============================================================================
-- validate() - Basic validation
-- ============================================================================

T["validate"] = new_set()

T["validate"]["returns valid for empty opts (all optional)"] = function()
  local result = child.lua([[
    local cv = require("codecompanion._extensions.gitcommit.config_validation")
    local result = cv.validate({})
    return { valid = result.valid, issue_count = #result.issues }
  ]])
  h.eq(true, result.valid)
  h.eq(0, result.issue_count)
end

T["validate"]["returns valid for correct types"] = function()
  local result = child.lua([[
    local cv = require("codecompanion._extensions.gitcommit.config_validation")
    local result = cv.validate({
      adapter = "openai",
      model = "gpt-4",
      languages = { "English", "Chinese" },
      exclude_files = { "*.log" },
      add_slash_command = true,
      gitcommit_select_count = 100,
      use_commit_history = true,
      commit_history_count = 10,
    })
    return { valid = result.valid, issue_count = #result.issues }
  ]])
  h.eq(true, result.valid)
  h.eq(0, result.issue_count)
end

T["validate"]["returns error for non-table opts"] = function()
  local result = child.lua([[
    local cv = require("codecompanion._extensions.gitcommit.config_validation")
    local result = cv.validate("not a table")
    return { valid = result.valid, field = result.issues[1].field, message = result.issues[1].message }
  ]])
  h.eq(false, result.valid)
  h.eq("opts", result.field)
  h.expect_match("expected table", result.message)
end

T["validate"]["returns warning for unknown fields"] = function()
  local result = child.lua([[
    local cv = require("codecompanion._extensions.gitcommit.config_validation")
    local result = cv.validate({ unknown_option = true })
    return {
      valid = result.valid,
      field = result.issues[1].field,
      severity = result.issues[1].severity,
      message = result.issues[1].message,
    }
  ]])
  -- Unknown fields produce warnings, not errors, so still valid
  h.eq(true, result.valid)
  h.eq("unknown_option", result.field)
  h.eq("warning", result.severity)
  h.expect_match("unknown configuration option", result.message)
end

-- ============================================================================
-- validate() - String type validation
-- ============================================================================

T["validate"]["string types"] = new_set()

T["validate"]["string types"]["accepts nil for optional string"] = function()
  local result = child.lua([[
    local cv = require("codecompanion._extensions.gitcommit.config_validation")
    local result = cv.validate({ adapter = nil })
    return result.valid
  ]])
  h.eq(true, result)
end

T["validate"]["string types"]["accepts valid string"] = function()
  local result = child.lua([[
    local cv = require("codecompanion._extensions.gitcommit.config_validation")
    local result = cv.validate({ adapter = "openai" })
    return result.valid
  ]])
  h.eq(true, result)
end

T["validate"]["string types"]["rejects number for string field"] = function()
  local result = child.lua([[
    local cv = require("codecompanion._extensions.gitcommit.config_validation")
    local result = cv.validate({ adapter = 123 })
    return {
      valid = result.valid,
      field = result.issues[1].field,
      message = result.issues[1].message,
    }
  ]])
  h.eq(false, result.valid)
  h.eq("adapter", result.field)
  h.expect_match("expected string", result.message)
  h.expect_match("got number", result.message)
end

T["validate"]["string types"]["rejects boolean for string field"] = function()
  local result = child.lua([[
    local cv = require("codecompanion._extensions.gitcommit.config_validation")
    local result = cv.validate({ model = true })
    return {
      valid = result.valid,
      field = result.issues[1].field,
      message = result.issues[1].message,
    }
  ]])
  h.eq(false, result.valid)
  h.eq("model", result.field)
  h.expect_match("expected string", result.message)
end

-- ============================================================================
-- validate() - Boolean type validation
-- ============================================================================

T["validate"]["boolean types"] = new_set()

T["validate"]["boolean types"]["accepts true"] = function()
  local result = child.lua([[
    local cv = require("codecompanion._extensions.gitcommit.config_validation")
    local result = cv.validate({ add_slash_command = true })
    return result.valid
  ]])
  h.eq(true, result)
end

T["validate"]["boolean types"]["accepts false"] = function()
  local result = child.lua([[
    local cv = require("codecompanion._extensions.gitcommit.config_validation")
    local result = cv.validate({ add_slash_command = false })
    return result.valid
  ]])
  h.eq(true, result)
end

T["validate"]["boolean types"]["accepts nil for optional boolean"] = function()
  local result = child.lua([[
    local cv = require("codecompanion._extensions.gitcommit.config_validation")
    local result = cv.validate({ enable_git_read = nil })
    return result.valid
  ]])
  h.eq(true, result)
end

T["validate"]["boolean types"]["rejects string for boolean field"] = function()
  local result = child.lua([[
    local cv = require("codecompanion._extensions.gitcommit.config_validation")
    local result = cv.validate({ add_git_tool = "yes" })
    return {
      valid = result.valid,
      field = result.issues[1].field,
      message = result.issues[1].message,
    }
  ]])
  h.eq(false, result.valid)
  h.eq("add_git_tool", result.field)
  h.expect_match("expected boolean", result.message)
end

T["validate"]["boolean types"]["rejects number for boolean field"] = function()
  local result = child.lua([[
    local cv = require("codecompanion._extensions.gitcommit.config_validation")
    local result = cv.validate({ enable_git_edit = 1 })
    return {
      valid = result.valid,
      field = result.issues[1].field,
    }
  ]])
  h.eq(false, result.valid)
  h.eq("enable_git_edit", result.field)
end

-- ============================================================================
-- validate() - Number type validation
-- ============================================================================

T["validate"]["number types"] = new_set()

T["validate"]["number types"]["accepts valid number"] = function()
  local result = child.lua([[
    local cv = require("codecompanion._extensions.gitcommit.config_validation")
    local result = cv.validate({ gitcommit_select_count = 50 })
    return result.valid
  ]])
  h.eq(true, result)
end

T["validate"]["number types"]["accepts zero"] = function()
  local result = child.lua([[
    local cv = require("codecompanion._extensions.gitcommit.config_validation")
    local result = cv.validate({ commit_history_count = 0 })
    return result.valid
  ]])
  h.eq(true, result)
end

T["validate"]["number types"]["accepts nil for optional number"] = function()
  local result = child.lua([[
    local cv = require("codecompanion._extensions.gitcommit.config_validation")
    local result = cv.validate({ gitcommit_select_count = nil })
    return result.valid
  ]])
  h.eq(true, result)
end

T["validate"]["number types"]["rejects string for number field"] = function()
  local result = child.lua([[
    local cv = require("codecompanion._extensions.gitcommit.config_validation")
    local result = cv.validate({ gitcommit_select_count = "100" })
    return {
      valid = result.valid,
      field = result.issues[1].field,
      message = result.issues[1].message,
    }
  ]])
  h.eq(false, result.valid)
  h.eq("gitcommit_select_count", result.field)
  h.expect_match("expected number", result.message)
end

-- ============================================================================
-- validate() - Array type validation
-- ============================================================================

T["validate"]["array types"] = new_set()

T["validate"]["array types"]["accepts valid string array"] = function()
  local result = child.lua([[
    local cv = require("codecompanion._extensions.gitcommit.config_validation")
    local result = cv.validate({ languages = { "English", "Chinese", "Japanese" } })
    return result.valid
  ]])
  h.eq(true, result)
end

T["validate"]["array types"]["accepts empty array"] = function()
  local result = child.lua([[
    local cv = require("codecompanion._extensions.gitcommit.config_validation")
    local result = cv.validate({ exclude_files = {} })
    return result.valid
  ]])
  h.eq(true, result)
end

T["validate"]["array types"]["rejects string for array field"] = function()
  local result = child.lua([[
    local cv = require("codecompanion._extensions.gitcommit.config_validation")
    local result = cv.validate({ languages = "English" })
    return {
      valid = result.valid,
      field = result.issues[1].field,
      message = result.issues[1].message,
    }
  ]])
  h.eq(false, result.valid)
  h.eq("languages", result.field)
  h.expect_match("expected array", result.message)
end

T["validate"]["array types"]["rejects number for array field"] = function()
  local result = child.lua([[
    local cv = require("codecompanion._extensions.gitcommit.config_validation")
    local result = cv.validate({ exclude_files = 123 })
    return {
      valid = result.valid,
      field = result.issues[1].field,
    }
  ]])
  h.eq(false, result.valid)
  h.eq("exclude_files", result.field)
end

T["validate"]["array types"]["rejects wrong item type in array"] = function()
  local result = child.lua([[
    local cv = require("codecompanion._extensions.gitcommit.config_validation")
    local result = cv.validate({ languages = { "English", 123, "Chinese" } })
    return {
      valid = result.valid,
      field = result.issues[1].field,
      message = result.issues[1].message,
    }
  ]])
  h.eq(false, result.valid)
  h.eq("languages[2]", result.field)
  h.expect_match("expected string", result.message)
  h.expect_match("got number", result.message)
end

T["validate"]["array types"]["reports all invalid items"] = function()
  local result = child.lua([[
    local cv = require("codecompanion._extensions.gitcommit.config_validation")
    local result = cv.validate({ languages = { 1, 2, 3 } })
    return { valid = result.valid, issue_count = #result.issues }
  ]])
  h.eq(false, result.valid)
  h.eq(3, result.issue_count)
end

-- ============================================================================
-- validate() - Nested table (buffer config) validation
-- ============================================================================

T["validate"]["nested table"] = new_set()

T["validate"]["nested table"]["accepts valid buffer config"] = function()
  local result = child.lua([[
    local cv = require("codecompanion._extensions.gitcommit.config_validation")
    local result = cv.validate({
      buffer = {
        enabled = true,
        keymap = "<leader>gc",
        auto_generate = false,
        auto_generate_delay = 300,
        skip_auto_generate_on_amend = true,
      }
    })
    return { valid = result.valid, issue_count = #result.issues }
  ]])
  h.eq(true, result.valid)
  h.eq(0, result.issue_count)
end

T["validate"]["nested table"]["accepts empty buffer config"] = function()
  local result = child.lua([[
    local cv = require("codecompanion._extensions.gitcommit.config_validation")
    local result = cv.validate({ buffer = {} })
    return result.valid
  ]])
  h.eq(true, result)
end

T["validate"]["nested table"]["accepts partial buffer config"] = function()
  local result = child.lua([[
    local cv = require("codecompanion._extensions.gitcommit.config_validation")
    local result = cv.validate({
      buffer = { enabled = true }
    })
    return result.valid
  ]])
  h.eq(true, result)
end

T["validate"]["nested table"]["rejects non-table buffer"] = function()
  local result = child.lua([[
    local cv = require("codecompanion._extensions.gitcommit.config_validation")
    local result = cv.validate({ buffer = "enabled" })
    return {
      valid = result.valid,
      field = result.issues[1].field,
      message = result.issues[1].message,
    }
  ]])
  h.eq(false, result.valid)
  h.eq("buffer", result.field)
  h.expect_match("expected table", result.message)
end

T["validate"]["nested table"]["validates nested field types"] = function()
  local result = child.lua([[
    local cv = require("codecompanion._extensions.gitcommit.config_validation")
    local result = cv.validate({
      buffer = { enabled = "yes" }
    })
    return {
      valid = result.valid,
      field = result.issues[1].field,
      message = result.issues[1].message,
    }
  ]])
  h.eq(false, result.valid)
  h.eq("buffer.enabled", result.field)
  h.expect_match("expected boolean", result.message)
end

T["validate"]["nested table"]["validates keymap type"] = function()
  local result = child.lua([[
    local cv = require("codecompanion._extensions.gitcommit.config_validation")
    local result = cv.validate({
      buffer = { keymap = 123 }
    })
    return {
      valid = result.valid,
      field = result.issues[1].field,
    }
  ]])
  h.eq(false, result.valid)
  h.eq("buffer.keymap", result.field)
end

T["validate"]["nested table"]["validates auto_generate_delay type"] = function()
  local result = child.lua([[
    local cv = require("codecompanion._extensions.gitcommit.config_validation")
    local result = cv.validate({
      buffer = { auto_generate_delay = "200" }
    })
    return {
      valid = result.valid,
      field = result.issues[1].field,
    }
  ]])
  h.eq(false, result.valid)
  h.eq("buffer.auto_generate_delay", result.field)
end

T["validate"]["nested table"]["warns about unknown nested fields"] = function()
  local result = child.lua([[
    local cv = require("codecompanion._extensions.gitcommit.config_validation")
    local result = cv.validate({
      buffer = { enabled = true, unknown_nested = "value" }
    })
    return {
      valid = result.valid,
      field = result.issues[1].field,
      severity = result.issues[1].severity,
    }
  ]])
  h.eq(true, result.valid) -- warnings don't invalidate
  h.eq("buffer.unknown_nested", result.field)
  h.eq("warning", result.severity)
end

T["validate"]["nested table"]["reports multiple nested errors"] = function()
  local result = child.lua([[
    local cv = require("codecompanion._extensions.gitcommit.config_validation")
    local result = cv.validate({
      buffer = {
        enabled = "yes",
        keymap = 123,
        auto_generate = "true",
      }
    })
    return { valid = result.valid, issue_count = #result.issues }
  ]])
  h.eq(false, result.valid)
  h.eq(3, result.issue_count)
end

-- ============================================================================
-- validate() - Multiple errors
-- ============================================================================

T["validate"]["multiple errors"] = new_set()

T["validate"]["multiple errors"]["collects all errors"] = function()
  local result = child.lua([[
    local cv = require("codecompanion._extensions.gitcommit.config_validation")
    local result = cv.validate({
      adapter = 123,
      model = true,
      languages = "English",
      add_slash_command = "yes",
    })
    return { valid = result.valid, issue_count = #result.issues }
  ]])
  h.eq(false, result.valid)
  h.eq(4, result.issue_count)
end

T["validate"]["multiple errors"]["mixes errors and warnings"] = function()
  local result = child.lua([[
    local cv = require("codecompanion._extensions.gitcommit.config_validation")
    local result = cv.validate({
      adapter = 123,           -- error
      unknown_field = true,    -- warning
    })
    local errors = 0
    local warnings = 0
    for _, issue in ipairs(result.issues) do
      if issue.severity == "error" then errors = errors + 1
      else warnings = warnings + 1 end
    end
    return { valid = result.valid, errors = errors, warnings = warnings }
  ]])
  h.eq(false, result.valid)
  h.eq(1, result.errors)
  h.eq(1, result.warnings)
end

-- ============================================================================
-- get_errors() and get_warnings()
-- ============================================================================

T["get_errors"] = new_set()

T["get_errors"]["returns only errors"] = function()
  local result = child.lua([[
    local cv = require("codecompanion._extensions.gitcommit.config_validation")
    local validation_result = cv.validate({
      adapter = 123,           -- error
      unknown_field = true,    -- warning
    })
    local errors = cv.get_errors(validation_result)
    return { count = #errors, field = errors[1].field }
  ]])
  h.eq(1, result.count)
  h.eq("adapter", result.field)
end

T["get_errors"]["returns empty for valid config"] = function()
  local result = child.lua([[
    local cv = require("codecompanion._extensions.gitcommit.config_validation")
    local validation_result = cv.validate({ adapter = "openai" })
    local errors = cv.get_errors(validation_result)
    return #errors
  ]])
  h.eq(0, result)
end

T["get_warnings"] = new_set()

T["get_warnings"]["returns only warnings"] = function()
  local result = child.lua([[
    local cv = require("codecompanion._extensions.gitcommit.config_validation")
    local validation_result = cv.validate({
      adapter = 123,           -- error
      unknown_field = true,    -- warning
    })
    local warnings = cv.get_warnings(validation_result)
    return { count = #warnings, field = warnings[1].field }
  ]])
  h.eq(1, result.count)
  h.eq("unknown_field", result.field)
end

T["get_warnings"]["returns empty when no warnings"] = function()
  local result = child.lua([[
    local cv = require("codecompanion._extensions.gitcommit.config_validation")
    local validation_result = cv.validate({ adapter = 123 })
    local warnings = cv.get_warnings(validation_result)
    return #warnings
  ]])
  h.eq(0, result)
end

-- ============================================================================
-- Custom schema validation
-- ============================================================================

T["custom schema"] = new_set()

T["custom schema"]["validates against custom schema"] = function()
  local result = child.lua([[
    local cv = require("codecompanion._extensions.gitcommit.config_validation")
    local custom_schema = {
      name = "string",
      count = { "number", "nil" },
    }
    local result = cv.validate({ name = "test", count = 5 }, custom_schema)
    return result.valid
  ]])
  h.eq(true, result)
end

T["custom schema"]["rejects invalid value with custom schema"] = function()
  local result = child.lua([[
    local cv = require("codecompanion._extensions.gitcommit.config_validation")
    local custom_schema = {
      name = "string",
    }
    local result = cv.validate({ name = 123 }, custom_schema)
    return { valid = result.valid, field = result.issues[1].field }
  ]])
  h.eq(false, result.valid)
  h.eq("name", result.field)
end

-- ============================================================================
-- Real-world config scenarios
-- ============================================================================

T["real-world scenarios"] = new_set()

T["real-world scenarios"]["validates typical user config"] = function()
  local result = child.lua([[
    local cv = require("codecompanion._extensions.gitcommit.config_validation")
    local result = cv.validate({
      adapter = "anthropic",
      model = "claude-3-5-sonnet-20241022",
      languages = { "English", "Chinese" },
      exclude_files = { "*.log", "node_modules/*", "dist/*" },
      buffer = {
        enabled = true,
        keymap = "<leader>gc",
        auto_generate = true,
        auto_generate_delay = 200,
      },
      add_slash_command = true,
      add_git_tool = true,
      enable_git_read = true,
      enable_git_edit = true,
      enable_git_bot = true,
      use_commit_history = true,
      commit_history_count = 15,
    })
    return { valid = result.valid, issue_count = #result.issues }
  ]])
  h.eq(true, result.valid)
  h.eq(0, result.issue_count)
end

T["real-world scenarios"]["detects common mistakes"] = function()
  local result = child.lua([[
    local cv = require("codecompanion._extensions.gitcommit.config_validation")
    -- Common mistakes: string instead of array, string instead of boolean
    local result = cv.validate({
      languages = "English",              -- should be array
      add_slash_command = "true",         -- should be boolean
      buffer = { enabled = 1 },           -- should be boolean
    })
    return { valid = result.valid, issue_count = #result.issues }
  ]])
  h.eq(false, result.valid)
  h.eq(3, result.issue_count)
end

T["real-world scenarios"]["warns about typos in option names"] = function()
  local result = child.lua([[
    local cv = require("codecompanion._extensions.gitcommit.config_validation")
    local result = cv.validate({
      adaptor = "openai",       -- typo: should be "adapter"
      languges = { "English" }, -- typo: should be "languages"
    })
    local warnings = cv.get_warnings(result)
    return {
      valid = result.valid,
      warning_count = #warnings,
      fields = { warnings[1].field, warnings[2].field },
    }
  ]])
  h.eq(true, result.valid) -- typos are warnings, config still "valid"
  h.eq(2, result.warning_count)
  -- Order may vary, just check both are present
  local fields = result.fields
  h.eq(true, fields[1] == "adaptor" or fields[2] == "adaptor")
  h.eq(true, fields[1] == "languges" or fields[2] == "languges")
end

return T
