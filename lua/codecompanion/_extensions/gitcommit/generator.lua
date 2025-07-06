local codecompanion_client = require("codecompanion.http")
local codecompanion_config = require("codecompanion.config")
local codecompanion_adapter = require("codecompanion.adapters")
local codecompanion_schema = require("codecompanion.schema")

---@class CodeCompanion.GitCommit.Generator
local Generator = {}

--- @type string?
local _adapter = nil
--- @type string?
local _model = nil

local CONSTANTS = {
  STATUS_ERROR = "error",
  STATUS_SUCCESS = "success",
}

--- @param adapter string?  The adapter to use for generation
--- @param model string? The model of the adapter to use for generation
function Generator.setup(adapter, model)
  _adapter = adapter or codecompanion_config.strategies.chat.adapter
  _model = model or codecompanion_config.strategies.chat.model

  -- Validate adapter
  if not codecompanion_adapter.resolve(_adapter) then
    error("Invalid adapter specified: " .. tostring(_adapter))
  end
end

---Generate commit message using LLM
---
---@param diff string The git diff to analyze
---@param lang? string The language to generate the commit message in (optional)
---@param callback fun(result: string|nil, error: string|nil) Callback function
function Generator.generate_commit_message(diff, lang, callback)
  -- Setup adapter
  local adapter = codecompanion_adapter.resolve(_adapter)
  if not adapter then
    return callback(nil, "Failed to resolve adapter")
  end

  adapter.opts.stream = false
  adapter = adapter:map_schema_to_params(codecompanion_schema.get_default(adapter, { model = _model }))

  -- Create HTTP client
  local new_client = codecompanion_client.new({
    adapter = adapter,
  })

  -- Create prompt for LLM
  local prompt = Generator._create_prompt(diff, lang)

  local payload = {
    messages = adapter:map_roles({
      { role = "user", content = prompt },
    }),
  }

  -- Send request to LLM
  new_client:request(payload, {
    callback = function(err, data, adapter)
      Generator._handle_response(err, data, adapter, callback)
    end,
  }, {
    silent = true,
  })
end

---Create prompt for commit message generation
---@param diff string The git diff to include in prompt
---@param lang? string The generate language (optional, not used in this implementation)
---@return string prompt The formatted prompt
function Generator._create_prompt(diff, lang)
  return string.format(
    [[Generate Conventional Commit compliant messages

When to use:
• When analyzing git diffs for commit messages
• When standardizing commit format across projects  
• When ensuring consistent commit message patterns
• When generating structured commit documentation

Best practices:
• Must include required type (feat, fix, docs, style, refactor, perf, test, chore)
• Use lowercase for type, optional scope in parentheses
• Start description with imperative verb, keep under 50 characters
• Add body with bullet points for complex changes
• Ensure language matches specification: %s

Format: type(scope): description

Example:
feat(auth): add OAuth2 integration

- implement Google OAuth provider
- update user authentication flow
- add integration tests

Generate commit message for this diff:
```diff
%s
```]],
    lang or "English",
    diff
  )
end

---Handle LLM response
---@param err table|nil Error from request
---@param data table|nil Response data
---@param adapter table The adapter used
---@param callback fun(result: string|nil, error: string|nil) Callback function
function Generator._handle_response(err, data, adapter, callback)
  -- Handle request errors
  if err then
    local error_msg = "Error generating commit message: " .. (err.stderr or err.message or "Unknown error")
    return callback(nil, error_msg)
  end

  -- Check for empty or invalid data
  if not data then
    return callback(nil, "No response received from LLM")
  end

  -- Process successful response
  if data then
    local result = adapter.handlers.chat_output(adapter, data)
    if result and result.status then
      if result.status == CONSTANTS.STATUS_SUCCESS then
        local content = result.output and result.output.content
        if content and vim.trim(content) ~= "" then
          return callback(vim.trim(content), nil)
        else
          return callback(nil, "Generated content is empty")
        end
      elseif result.status == CONSTANTS.STATUS_ERROR then
        local error_msg = result.output or "Unknown error occurred"
        return callback(nil, error_msg)
      end
    end
  end

  return callback(nil, "No valid response received")
end

return Generator
