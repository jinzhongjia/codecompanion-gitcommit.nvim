---@class CodeCompanion.GitCommit.Tools.Validation
local M = {}

local fmt = string.format

---Format error response for tool output
---@param tool_name string The tool name for XML tag
---@param error_msg string The error message
---@return table error_response Formatted error response
function M.format_error(tool_name, error_msg)
  return {
    status = "error",
    data = {
      output = error_msg,
      user_msg = "✗ " .. error_msg,
      llm_msg = fmt("<%sTool>fail: %s</%sTool>", tool_name, error_msg, tool_name),
    },
  }
end

---Validate that a value is a non-empty string
---@param value any The value to validate
---@param param_name string The parameter name for error messages
---@param tool_name string The tool name for error formatting
---@return table|nil error_response Returns error response if invalid, nil if valid
function M.require_string(value, param_name, tool_name)
  if value == nil then
    return M.format_error(tool_name, fmt("%s is required", param_name))
  end
  if type(value) ~= "string" then
    return M.format_error(tool_name, fmt("%s must be a string, got %s", param_name, type(value)))
  end
  if value == "" then
    return M.format_error(tool_name, fmt("%s cannot be empty", param_name))
  end
  return nil
end

---Validate that a value is an optional string (nil or valid string)
---@param value any The value to validate
---@param param_name string The parameter name for error messages
---@param tool_name string The tool name for error formatting
---@return table|nil error_response Returns error response if invalid, nil if valid
function M.optional_string(value, param_name, tool_name)
  if value == nil then
    return nil
  end
  if type(value) ~= "string" then
    return M.format_error(tool_name, fmt("%s must be a string, got %s", param_name, type(value)))
  end
  return nil
end

---Validate that a value is a non-empty array (table)
---@param value any The value to validate
---@param param_name string The parameter name for error messages
---@param tool_name string The tool name for error formatting
---@return table|nil error_response Returns error response if invalid, nil if valid
function M.require_array(value, param_name, tool_name)
  if value == nil then
    return M.format_error(tool_name, fmt("%s is required", param_name))
  end
  if type(value) ~= "table" then
    return M.format_error(tool_name, fmt("%s must be an array, got %s", param_name, type(value)))
  end
  if #value == 0 then
    return M.format_error(tool_name, fmt("%s cannot be empty", param_name))
  end
  return nil
end

---Validate that a value is an optional integer
---@param value any The value to validate
---@param param_name string The parameter name for error messages
---@param tool_name string The tool name for error formatting
---@param min? number Minimum value (optional)
---@param max? number Maximum value (optional)
---@return table|nil error_response Returns error response if invalid, nil if valid
function M.optional_integer(value, param_name, tool_name, min, max)
  if value == nil then
    return nil
  end
  if type(value) ~= "number" then
    return M.format_error(tool_name, fmt("%s must be a number, got %s", param_name, type(value)))
  end
  if value ~= math.floor(value) then
    return M.format_error(tool_name, fmt("%s must be an integer, got %s", param_name, value))
  end
  if min and value < min then
    return M.format_error(tool_name, fmt("%s must be at least %d, got %d", param_name, min, value))
  end
  if max and value > max then
    return M.format_error(tool_name, fmt("%s must be at most %d, got %d", param_name, max, value))
  end
  return nil
end

---Validate that a value is an optional boolean
---@param value any The value to validate
---@param param_name string The parameter name for error messages
---@param tool_name string The tool name for error formatting
---@return table|nil error_response Returns error response if invalid, nil if valid
function M.optional_boolean(value, param_name, tool_name)
  if value == nil then
    return nil
  end
  if type(value) ~= "boolean" then
    return M.format_error(tool_name, fmt("%s must be a boolean, got %s", param_name, type(value)))
  end
  return nil
end

---Validate that a value is one of the allowed values
---@param value any The value to validate
---@param param_name string The parameter name for error messages
---@param allowed table Array of allowed values
---@param tool_name string The tool name for error formatting
---@return table|nil error_response Returns error response if invalid, nil if valid
function M.require_enum(value, param_name, allowed, tool_name)
  if value == nil then
    return M.format_error(tool_name, fmt("%s is required", param_name))
  end
  for _, v in ipairs(allowed) do
    if value == v then
      return nil
    end
  end
  return M.format_error(
    tool_name,
    fmt("%s must be one of: %s, got '%s'", param_name, table.concat(allowed, ", "), tostring(value))
  )
end

---Validate that args is a table (not nil)
---@param args any The args to validate
---@param tool_name string The tool name for error formatting
---@return table|nil error_response Returns error response if invalid, nil if valid
function M.require_args(args, tool_name)
  if args == nil then
    return M.format_error(tool_name, "args parameter is required")
  end
  if type(args) ~= "table" then
    return M.format_error(tool_name, fmt("args must be an object, got %s", type(args)))
  end
  return nil
end

---Run multiple validations and return the first error
---@param validations table Array of validation results (nil or error table)
---@return table|nil error_response Returns first error or nil if all valid
function M.first_error(validations)
  for _, result in ipairs(validations) do
    if result then
      return result
    end
  end
  return nil
end

return M
