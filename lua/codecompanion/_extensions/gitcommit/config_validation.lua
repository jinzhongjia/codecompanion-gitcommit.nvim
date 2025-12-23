---@class CodeCompanion.GitCommit.ConfigValidation
local M = {}

local fmt = string.format

---@class ConfigValidationIssue
---@field field string The field path (e.g., "buffer.enabled")
---@field message string The error message
---@field severity "error"|"warning" Issue severity

---@class ConfigValidationResult
---@field valid boolean Whether config is valid
---@field issues ConfigValidationIssue[] List of validation issues

---@alias ConfigTypeSpec string|string[]|fun(value: any): boolean, string?

---Config field type specifications
---Format: { field_name = type_spec } where type_spec can be:
---  - "string", "boolean", "number", "table", "function"
---  - { "string", "nil" } for optional string
---  - { type = "array", items = "string" } for string array
---  - { type = "table", fields = { ... } } for nested table
---  - function(value) -> boolean, error_msg for custom validation
---@type table<string, ConfigTypeSpec|table>
M.schema = {
  adapter = { "string", "nil" },
  model = { "string", "nil" },
  languages = { type = "array", items = "string" },
  exclude_files = { type = "array", items = "string" },
  buffer = {
    type = "table",
    fields = {
      enabled = { "boolean", "nil" },
      keymap = { "string", "nil" },
      auto_generate = { "boolean", "nil" },
      auto_generate_delay = { "number", "nil" },
      window_stability_delay = { "number", "nil" },
      skip_auto_generate_on_amend = { "boolean", "nil" },
    },
  },
  add_slash_command = { "boolean", "nil" },
  add_git_tool = { "boolean", "nil" },
  enable_git_read = { "boolean", "nil" },
  enable_git_edit = { "boolean", "nil" },
  enable_git_bot = { "boolean", "nil" },
  add_git_commands = { "boolean", "nil" },
  git_tool_auto_submit_errors = { "boolean", "nil" },
  git_tool_auto_submit_success = { "boolean", "nil" },
  gitcommit_select_count = { "number", "nil" },
  use_commit_history = { "boolean", "nil" },
  commit_history_count = { "number", "nil" },
}

---Check if value matches a simple type
---@param value any
---@param expected_type string
---@return boolean
local function is_type(value, expected_type)
  if expected_type == "nil" then
    return value == nil
  end
  return type(value) == expected_type
end

---Check if value matches any of the allowed types
---@param value any
---@param allowed_types string[]
---@return boolean
local function matches_types(value, allowed_types)
  for _, t in ipairs(allowed_types) do
    if is_type(value, t) then
      return true
    end
  end
  return false
end

---Format type list for error messages
---@param types string[]
---@return string
local function format_types(types)
  if #types == 1 then
    return types[1]
  end
  local filtered = {}
  for _, t in ipairs(types) do
    if t ~= "nil" then
      table.insert(filtered, t)
    end
  end
  if #filtered == 1 then
    return filtered[1] .. " (optional)"
  end
  return table.concat(filtered, " or ") .. " (optional)"
end

---Validate a single field
---@param value any The value to validate
---@param spec ConfigTypeSpec|table The type specification
---@param field_path string The field path for error messages
---@param issues ConfigValidationIssue[] Issues collector
local function validate_field(value, spec, field_path, issues)
  -- Handle nil values
  if value == nil then
    return -- nil is handled by type checking below
  end

  -- Handle simple type string
  if type(spec) == "string" then
    if not is_type(value, spec) then
      table.insert(issues, {
        field = field_path,
        message = fmt("expected %s, got %s", spec, type(value)),
        severity = "error",
      })
    end
    return
  end

  -- Handle array of allowed types (e.g., { "string", "nil" })
  if type(spec) == "table" and spec[1] ~= nil then
    if not matches_types(value, spec) then
      table.insert(issues, {
        field = field_path,
        message = fmt("expected %s, got %s", format_types(spec), type(value)),
        severity = "error",
      })
    end
    return
  end

  -- Handle complex type specifications
  if type(spec) == "table" and spec.type then
    if spec.type == "array" then
      -- Validate array type
      if type(value) ~= "table" then
        table.insert(issues, {
          field = field_path,
          message = fmt("expected array, got %s", type(value)),
          severity = "error",
        })
        return
      end
      -- Validate array items
      if spec.items then
        for i, item in ipairs(value) do
          if not is_type(item, spec.items) then
            table.insert(issues, {
              field = fmt("%s[%d]", field_path, i),
              message = fmt("expected %s, got %s", spec.items, type(item)),
              severity = "error",
            })
          end
        end
      end
      return
    end

    if spec.type == "table" then
      -- Validate nested table
      if type(value) ~= "table" then
        table.insert(issues, {
          field = field_path,
          message = fmt("expected table, got %s", type(value)),
          severity = "error",
        })
        return
      end
      -- Validate nested fields
      if spec.fields then
        for nested_field, nested_spec in pairs(spec.fields) do
          validate_field(value[nested_field], nested_spec, field_path .. "." .. nested_field, issues)
        end
        -- Warn about unknown fields in nested table
        for key in pairs(value) do
          if not spec.fields[key] then
            table.insert(issues, {
              field = field_path .. "." .. key,
              message = "unknown configuration option",
              severity = "warning",
            })
          end
        end
      end
      return
    end
  end

  -- Handle custom validation function
  if type(spec) == "function" then
    local valid, err = spec(value)
    if not valid then
      table.insert(issues, {
        field = field_path,
        message = err or "invalid value",
        severity = "error",
      })
    end
    return
  end
end

---Validate configuration options
---@param opts table User-provided configuration options
---@param schema? table<string, ConfigTypeSpec|table> Schema to validate against (defaults to M.schema)
---@return ConfigValidationResult
function M.validate(opts, schema)
  schema = schema or M.schema
  local issues = {}

  if type(opts) ~= "table" then
    return {
      valid = false,
      issues = {
        {
          field = "opts",
          message = fmt("expected table, got %s", type(opts)),
          severity = "error",
        },
      },
    }
  end

  -- Validate known fields
  for field, spec in pairs(schema) do
    validate_field(opts[field], spec, field, issues)
  end

  -- Warn about unknown top-level fields
  for key in pairs(opts) do
    if not schema[key] then
      table.insert(issues, {
        field = key,
        message = "unknown configuration option",
        severity = "warning",
      })
    end
  end

  -- Determine overall validity (only errors make it invalid, warnings are ok)
  local valid = true
  for _, issue in ipairs(issues) do
    if issue.severity == "error" then
      valid = false
      break
    end
  end

  return {
    valid = valid,
    issues = issues,
  }
end

---Report validation issues to user via vim.notify
---@param result ConfigValidationResult
---@param prefix? string Prefix for messages (default: "codecompanion-gitcommit")
function M.report(result, prefix)
  prefix = prefix or "codecompanion-gitcommit"

  if #result.issues == 0 then
    return
  end

  for _, issue in ipairs(result.issues) do
    local level = issue.severity == "error" and vim.log.levels.ERROR or vim.log.levels.WARN
    local msg = fmt("[%s] config.%s: %s", prefix, issue.field, issue.message)
    vim.notify(msg, level)
  end
end

---Validate and report issues (convenience function)
---@param opts table User-provided configuration options
---@param prefix? string Prefix for messages
---@return boolean valid Whether config is valid
function M.validate_and_report(opts, prefix)
  local result = M.validate(opts)
  M.report(result, prefix)
  return result.valid
end

---Get only errors from validation result
---@param result ConfigValidationResult
---@return ConfigValidationIssue[]
function M.get_errors(result)
  local errors = {}
  for _, issue in ipairs(result.issues) do
    if issue.severity == "error" then
      table.insert(errors, issue)
    end
  end
  return errors
end

---Get only warnings from validation result
---@param result ConfigValidationResult
---@return ConfigValidationIssue[]
function M.get_warnings(result)
  local warnings = {}
  for _, issue in ipairs(result.issues) do
    if issue.severity == "warning" then
      table.insert(warnings, issue)
    end
  end
  return warnings
end

return M
