local codecompanion_client = require("codecompanion.http")
local codecompanion_config = require("codecompanion.config")
local codecompanion_adapter = require("codecompanion.adapters")
local codecompanion_schema = require("codecompanion.schema")

---@class CodeCompanion.GitCommit.Generator
local Generator = {}

--- @type string?
local _adapater = nil
--- @type string?
local _model = nil

local CONSTANTS = {
  STATUS_ERROR = "error",
  STATUS_SUCCESS = "success",
}

--- @param adapter string?  The adapter to use for generation
--- @param model string? The model of the adapter to use for generation
function Generator.setup(adapter, model)
  _adapater = adapter or codecompanion_config.strategies.chat.adapter
  _model = model or codecompanion_config.strategies.chat.model

  -- Validate adapter
  if not codecompanion_adapter.resolve(_adapater) then
    error("Invalid adapter specified: " .. tostring(_adapater))
  end
end

---Generate commit message using LLM
---
---@param diff string The git diff to analyze
---@param lang? string The language to generate the commit message in (optional)
---@param callback fun(result: string|nil, error: string|nil) Callback function
function Generator.generate_commit_message(diff, lang, callback)
  -- Setup adapter
  local adapter = codecompanion_adapter.resolve(_adapater)
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
    callback = function(err, data, _adapter)
      Generator._handle_response(err, data, _adapter, callback)
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
    [[You are an expert at following the Conventional Commit specification.

Please only return a commit message that strictly follows the Conventional Commit specification, without any additional text or explanations. The commit message should include:

1. Type (required): lowercase, e.g., feat, fix, docs, style, refactor, perf, test, chore
2. Scope (optional): in parentheses after type, e.g., feat(parser)
3. Description (required): space after colon, start with verb, be concise
4. Body (optional): use bullet points (-) to list specific changes

Example format:

feat(scope): add new feature

- implement X functionality
- update Y module
- add tests for Z

The message need follow this :

<type>(<scope>): <subject>
<BLANK LINE>
<body>
<BLANK LINE>
<footer>

Note: You need to answer in %s.

Based on the git diff provided below, generate a standardized commit message.

```diff
%s
```

]],
    lang or "English",
    diff
  )
end

---Handle LLM response
---@param err table|nil Error from request
---@param data table|nil Response data
---@param _adapter table The adapter used
---@param callback fun(result: string|nil, error: string|nil) Callback function
function Generator._handle_response(err, data, _adapter, callback)
  -- Handle request errors
  if err and err.stderr ~= "{}" then
    local error_msg = "Error generating commit message: " .. (err.stderr or "Unknown error")
    return callback(nil, error_msg)
  end

  -- Process successful response
  if data then
    local result = _adapter.handlers.chat_output(_adapter, data)
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
