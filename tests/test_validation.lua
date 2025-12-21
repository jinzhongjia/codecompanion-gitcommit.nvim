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

T["format_error"] = new_set()

T["format_error"]["returns correct structure"] = function()
  local result = child.lua([[
    local validation = require("codecompanion._extensions.gitcommit.tools.validation")
    local result = validation.format_error("myTool", "Something went wrong")
    return {
      status = result.status,
      output = result.data.output,
      user_msg = result.data.user_msg,
      llm_msg = result.data.llm_msg,
    }
  ]])
  h.eq("error", result.status)
  h.eq("Something went wrong", result.output)
  h.eq("✗ Something went wrong", result.user_msg)
  h.eq("<myToolTool>fail: Something went wrong</myToolTool>", result.llm_msg)
end

T["require_string"] = new_set()

T["require_string"]["returns nil for valid string"] = function()
  local result = child.lua([[
    local v = require("codecompanion._extensions.gitcommit.tools.validation")
    return v.require_string("hello", "param", "test") == nil
  ]])
  h.eq(true, result)
end

T["require_string"]["returns error for nil"] = function()
  local result = child.lua([[
    local v = require("codecompanion._extensions.gitcommit.tools.validation")
    local err = v.require_string(nil, "myParam", "test")
    return err.data.output
  ]])
  h.eq("myParam is required", result)
end

T["require_string"]["returns error for non-string type"] = function()
  local result = child.lua([[
    local v = require("codecompanion._extensions.gitcommit.tools.validation")
    local err = v.require_string(123, "myParam", "test")
    return err.data.output
  ]])
  h.eq("myParam must be a string, got number", result)
end

T["require_string"]["returns error for empty string"] = function()
  local result = child.lua([[
    local v = require("codecompanion._extensions.gitcommit.tools.validation")
    local err = v.require_string("", "myParam", "test")
    return err.data.output
  ]])
  h.eq("myParam cannot be empty", result)
end

T["optional_string"] = new_set()

T["optional_string"]["returns nil for nil value"] = function()
  local result = child.lua([[
    local v = require("codecompanion._extensions.gitcommit.tools.validation")
    return v.optional_string(nil, "param", "test") == nil
  ]])
  h.eq(true, result)
end

T["optional_string"]["returns error for non-string type"] = function()
  local result = child.lua([[
    local v = require("codecompanion._extensions.gitcommit.tools.validation")
    local err = v.optional_string(42, "myParam", "test")
    return err.data.output
  ]])
  h.eq("myParam must be a string, got number", result)
end

T["require_array"] = new_set()

T["require_array"]["returns nil for non-empty array"] = function()
  local result = child.lua([[
    local v = require("codecompanion._extensions.gitcommit.tools.validation")
    return v.require_array({"a", "b"}, "param", "test") == nil
  ]])
  h.eq(true, result)
end

T["require_array"]["returns error for nil"] = function()
  local result = child.lua([[
    local v = require("codecompanion._extensions.gitcommit.tools.validation")
    local err = v.require_array(nil, "myParam", "test")
    return err.data.output
  ]])
  h.eq("myParam is required", result)
end

T["require_array"]["returns error for empty array"] = function()
  local result = child.lua([[
    local v = require("codecompanion._extensions.gitcommit.tools.validation")
    local err = v.require_array({}, "myParam", "test")
    return err.data.output
  ]])
  h.eq("myParam cannot be empty", result)
end

T["optional_integer"] = new_set()

T["optional_integer"]["returns nil for nil value"] = function()
  local result = child.lua([[
    local v = require("codecompanion._extensions.gitcommit.tools.validation")
    return v.optional_integer(nil, "param", "test") == nil
  ]])
  h.eq(true, result)
end

T["optional_integer"]["returns nil for valid integer"] = function()
  local result = child.lua([[
    local v = require("codecompanion._extensions.gitcommit.tools.validation")
    return v.optional_integer(42, "param", "test") == nil
  ]])
  h.eq(true, result)
end

T["optional_integer"]["returns error for float"] = function()
  local result = child.lua([[
    local v = require("codecompanion._extensions.gitcommit.tools.validation")
    local err = v.optional_integer(3.14, "myParam", "test")
    return err.data.output
  ]])
  h.eq("myParam must be an integer, got 3.14", result)
end

T["optional_integer"]["returns error when below min"] = function()
  local result = child.lua([[
    local v = require("codecompanion._extensions.gitcommit.tools.validation")
    local err = v.optional_integer(0, "myParam", "test", 1, 10)
    return err.data.output
  ]])
  h.eq("myParam must be at least 1, got 0", result)
end

T["optional_integer"]["returns error when above max"] = function()
  local result = child.lua([[
    local v = require("codecompanion._extensions.gitcommit.tools.validation")
    local err = v.optional_integer(15, "myParam", "test", 1, 10)
    return err.data.output
  ]])
  h.eq("myParam must be at most 10, got 15", result)
end

T["optional_boolean"] = new_set()

T["optional_boolean"]["returns nil for nil value"] = function()
  local result = child.lua([[
    local v = require("codecompanion._extensions.gitcommit.tools.validation")
    return v.optional_boolean(nil, "param", "test") == nil
  ]])
  h.eq(true, result)
end

T["optional_boolean"]["returns error for non-boolean type"] = function()
  local result = child.lua([[
    local v = require("codecompanion._extensions.gitcommit.tools.validation")
    local err = v.optional_boolean("true", "myParam", "test")
    return err.data.output
  ]])
  h.eq("myParam must be a boolean, got string", result)
end

T["require_enum"] = new_set()

T["require_enum"]["returns nil for valid enum value"] = function()
  local result = child.lua([[
    local v = require("codecompanion._extensions.gitcommit.tools.validation")
    return v.require_enum("two", "param", {"one", "two", "three"}, "test") == nil
  ]])
  h.eq(true, result)
end

T["require_enum"]["returns error for nil"] = function()
  local result = child.lua([[
    local v = require("codecompanion._extensions.gitcommit.tools.validation")
    local err = v.require_enum(nil, "myParam", {"one", "two"}, "test")
    return err.data.output
  ]])
  h.eq("myParam is required", result)
end

T["require_enum"]["returns error for invalid value"] = function()
  local result = child.lua([[
    local v = require("codecompanion._extensions.gitcommit.tools.validation")
    local err = v.require_enum("four", "myParam", {"one", "two", "three"}, "test")
    return err.data.output
  ]])
  h.eq("myParam must be one of: one, two, three, got 'four'", result)
end

T["first_error"] = new_set()

T["first_error"]["returns nil when all validations pass"] = function()
  local result = child.lua([[
    local v = require("codecompanion._extensions.gitcommit.tools.validation")
    return v.first_error({nil, nil, nil}) == nil
  ]])
  h.eq(true, result)
end

T["first_error"]["returns first error"] = function()
  local result = child.lua([[
    local v = require("codecompanion._extensions.gitcommit.tools.validation")
    local err1 = v.format_error("test", "First error")
    local err2 = v.format_error("test", "Second error")
    local validations = {}
    validations[1] = nil
    validations[2] = err1
    validations[3] = err2
    local first = v.first_error(validations)
    if first and first.data then
      return first.data.output
    end
    return "no error found"
  ]])
  h.eq("First error", result)
end

T["first_error"]["handles sparse array with nil values"] = function()
  local result = child.lua([[
    local v = require("codecompanion._extensions.gitcommit.tools.validation")
    local err = v.format_error("test", "The error")
    local validations = {}
    validations[1] = nil
    validations[2] = nil
    validations[3] = err
    local first = v.first_error(validations)
    if first and first.data then
      return first.data.output
    end
    return "no error found"
  ]])
  h.eq("The error", result)
end

T["first_error"]["returns nil for empty array"] = function()
  local result = child.lua([[
    local v = require("codecompanion._extensions.gitcommit.tools.validation")
    return v.first_error({}) == nil
  ]])
  h.eq(true, result)
end

return T
