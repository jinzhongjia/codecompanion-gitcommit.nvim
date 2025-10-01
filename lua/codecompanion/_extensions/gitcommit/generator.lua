local codecompanion_adapter = require("codecompanion.adapters")
local codecompanion_schema = require("codecompanion.schema")

---@class CodeCompanion.GitCommit.Generator
local Generator = {}

--- @type string? Adapter name
local _adapter_name = nil
--- @type string? Model name
local _model_name = nil

local CONSTANTS = {
  STATUS_ERROR = "error",
  STATUS_SUCCESS = "success",
}

--- @param adapter string?  The adapter to use for generation
--- @param model string? The model of the adapter to use for generation
function Generator.setup(adapter, model)
  _adapter_name = adapter
  _model_name = model
end

---Create a client for both HTTP and ACP adapters
---@param adapter table The resolved adapter
---@return table|nil client The client instance
---@return string|nil error Error message if failed
local function create_client(adapter)
  if not adapter or not adapter.type then
    return nil, "Invalid adapter: missing type field"
  end

  if adapter.type == "http" then
    local HTTPClient = require("codecompanion.http")
    return HTTPClient.new({ adapter = adapter }), nil
  elseif adapter.type == "acp" then
    local ACPClient = require("codecompanion.acp")
    local client = ACPClient.new({ adapter = adapter })
    local ok = client:connect_and_initialize()
    if not ok then
      return nil, "Failed to connect and initialize ACP client"
    end
    return client, nil
  else
    return nil, "Unknown adapter type: " .. tostring(adapter.type)
  end
end

---Send request using HTTP client
---@param client table HTTP client
---@param adapter table Adapter instance
---@param payload table Request payload
---@param callback function Callback function
local function send_http_request(client, adapter, payload, callback)
  local accumulated = ""
  local has_error = false

  -- Prepare options for spinner events
  local request_opts = {
    adapter = {
      name = adapter.name or "unknown",
      formatted_name = adapter.formatted_name or adapter.name or "GitCommit",
      model = (adapter.schema and adapter.schema.model and adapter.schema.model.default) or "",
    },
    strategy = "gitcommit",
    silent = false,
  }

  -- Use async send to properly handle streaming responses
  client:send(
    payload,
    vim.tbl_extend("force", request_opts, {
      stream = true,
      on_chunk = function(chunk)
        if chunk and chunk ~= "" then
          -- Use adapter's chat_output handler to process the chunk
          local result = adapter.handlers.chat_output(adapter, chunk)
          if result and result.status == CONSTANTS.STATUS_SUCCESS then
            local content = result.output and result.output.content
            if content and content ~= "" then
              accumulated = accumulated .. content
            end
          end
        end
      end,
      on_done = function()
        if not has_error then
          if accumulated ~= "" then
            local cleaned = Generator._clean_commit_message(accumulated)
            callback(cleaned, nil)
          else
            callback(nil, "Generated content is empty")
          end
        end
      end,
      on_error = function(err)
        has_error = true
        local error_msg = "HTTP request failed: " .. (err.message or vim.inspect(err))
        callback(nil, error_msg)
      end,
    })
  )
end

---Send request using ACP client
---@param client table ACP client
---@param adapter table Adapter instance
---@param messages table Array of messages
---@param callback function Callback function
local function send_acp_request(client, adapter, messages, callback)
  local accumulated = ""
  local has_error = false

  -- Prepare options for spinner events
  local request_opts = {
    adapter = {
      name = adapter.name or "unknown",
      formatted_name = adapter.formatted_name or adapter.name or "GitCommit",
      type = "acp",
      model = nil,
    },
    strategy = "gitcommit",
    silent = false,
  }

  -- ACP expects messages to have _meta field
  -- Add it to make messages compatible with form_messages
  local formatted_messages = vim.tbl_map(function(msg)
    return vim.tbl_extend("force", msg, {
      _meta = {
        visible = true,
      },
    })
  end, messages)

  client
    :session_prompt(formatted_messages)
    :with_options(request_opts)
    :on_message_chunk(function(chunk)
      if chunk and chunk ~= "" then
        accumulated = accumulated .. chunk
      end
    end)
    :on_complete(function(stop_reason)
      if not has_error and accumulated ~= "" then
        -- ACP responses are plain text, wrap in expected format
        local cleaned = Generator._clean_commit_message(accumulated)
        callback(cleaned, nil)
      elseif not has_error then
        callback(nil, "ACP returned empty response")
      end
    end)
    :on_error(function(error)
      has_error = true
      callback(nil, "ACP error: " .. vim.inspect(error))
    end)
    :send()
end

---Clean commit message by removing markdown code blocks and extra formatting
---@param message string Raw message from LLM
---@return string cleaned_message The cleaned commit message
function Generator._clean_commit_message(message)
  local cleaned = vim.trim(message)

  -- Remove markdown code blocks (```...``` or ````...````)
  -- Match opening code fence with optional language identifier
  cleaned = cleaned:gsub("^```+%w*\n", "")
  -- Match closing code fence
  cleaned = cleaned:gsub("\n```+$", "")

  -- Trim again after removing code blocks
  cleaned = vim.trim(cleaned)

  return cleaned
end

---@param commit_history? string[] Array of recent commit messages for context (optional)
function Generator.generate_commit_message(diff, lang, commit_history, callback)
  -- 1. Resolve adapter
  local adapter = codecompanion_adapter.resolve(_adapter_name, {
    model = _model_name,
  })
  if not adapter then
    return callback(nil, "Failed to resolve adapter: " .. tostring(_adapter_name))
  end

  -- Validate adapter type
  if not adapter.type or (adapter.type ~= "http" and adapter.type ~= "acp") then
    return callback(nil, "Invalid or unsupported adapter type: " .. tostring(adapter.type))
  end

  -- 2. Create prompt
  local prompt = Generator._create_prompt(diff, lang, commit_history)

  -- 3. Prepare messages
  local messages = {
    { role = "user", content = prompt },
  }

  -- 4. Map schema for HTTP adapter (must be done before client creation)
  if adapter.type == "http" then
    local schema_opts = {}
    if _model_name then
      schema_opts.model = _model_name
    end
    adapter = adapter:map_schema_to_params(codecompanion_schema.get_default(adapter, schema_opts))
  end

  -- 5. Create client (after potential schema mapping for HTTP)
  local client, err = create_client(adapter)
  if not client then
    return callback(nil, err)
  end

  -- 6. Send request based on adapter type
  if adapter.type == "http" then
    -- Prepare HTTP payload
    local payload = {
      messages = adapter:map_roles(messages),
    }

    send_http_request(client, adapter, payload, callback)
  elseif adapter.type == "acp" then
    send_acp_request(client, adapter, messages, function(result, error)
      -- Disconnect after request completes
      pcall(function()
        client:disconnect()
      end)
      callback(result, error)
    end)
  end
end

---Create prompt for commit message generation
---@param diff string The git diff to include in prompt
---@param commit_history? string[] Recent commit messages for context (optional)
function Generator._create_prompt(diff, lang, commit_history)
  -- Build history context section
  local history_context = ""
  if commit_history and #commit_history > 0 then
    history_context = "\nRECENT COMMIT HISTORY (for style reference):\n"
    for i, commit_msg in ipairs(commit_history) do
      history_context = history_context .. string.format("%d. %s\n", i, commit_msg)
    end
    history_context = history_context
      .. "\nAnalyze commit history to understand project style, tone, and format patterns. Use this for consistency.\n"
  end

  return string.format(
    [[You are a commit message generator. Generate exactly ONE complete Conventional Commit message for the provided git diff.%s

CRITICAL FORMAT REQUIREMENTS:
1. MUST generate exactly ONE commit message, never multiple messages
2. MUST include a title line, followed by a blank line, then bullet point descriptions
3. MUST analyze ALL changes in the diff as a single logical unit
4. MUST respond with ONLY the commit message, no explanations, markdown code blocks, or extra text
5. DO NOT wrap the output in markdown code blocks (```) or any other formatting

MANDATORY FORMAT:
type(scope): brief description
<blank line>
- description point 1
- description point 2
- description point 3

Allowed types: feat, fix, docs, style, refactor, perf, test, chore
Language: %s

RULES:
 - Output the commit message directly without any markdown formatting or code blocks
 - The title (first line) must be followed by ONE blank line before the descriptions
 - Each description point must start with a dash (-)
 - If commit history is provided, follow the established patterns and style from recent commits

REQUIRED EXAMPLES:
feat(auth): add OAuth2 integration

- Implement OAuth2 authentication flow
- Add token refresh mechanism
- Update user session handling
fix(api): resolve data validation issues

- Fix null pointer exception in validator
- Add input sanitization
- Improve error messages
Generate ONE complete commit message for this diff:
```diff
%s
```

Return ONLY the commit message in the exact format shown above.]],
    history_context,
    lang or "English",
    diff
  )
end

return Generator
