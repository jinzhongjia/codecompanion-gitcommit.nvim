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
    [[You are a commit message generator. Generate exactly ONE complete Conventional Commit message for the provided git diff.

CRITICAL FORMAT REQUIREMENTS:
1. MUST generate exactly ONE commit message, never multiple messages
2. MUST include a title line and at least one bullet point description
3. MUST analyze ALL changes in the diff as a single logical unit
4. MUST respond with ONLY the commit message, no explanations or extra text

MANDATORY FORMAT:
type(scope): brief description

- detailed description point 1
- detailed description point 2 (if needed)
- detailed description point 3 (if needed)

Types: feat, fix, docs, style, refactor, perf, test, chore
Language: %s

RULES:
- Title: Use imperative mood ("add" not "added"), keep under 50 characters
- Body: At least ONE bullet point describing the changes
- For large diffs: Focus on the most significant changes, group related changes
- Choose the primary type that best represents the overall change
- Even with extensive changes, generate only ONE unified commit message

REQUIRED EXAMPLES:
feat(auth): add OAuth2 integration

- implement Google OAuth provider
- update user authentication flow
- add integration tests

fix(api): resolve data validation issues

- fix null pointer exceptions in user data
- improve input validation for API endpoints

Generate ONE complete commit message for this diff:
```diff
%s
```

Return ONLY the commit message in the exact format shown above.]],
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
