local client = require("codecompanion.http")
local codecompanion_config = require("codecompanion.config")
local codecompanion_adapter = require("codecompanion.adapters")

---@class CodeCompanion.GitCommit.Generator
local Generator = {}

local CONSTANTS = {
	STATUS_ERROR = "error",
	STATUS_SUCCESS = "success",
}

---Generate commit message using LLM
---@param diff string The git diff to analyze
---@param callback fun(result: string|nil, error: string|nil) Callback function
function Generator.generate_commit_message(diff, callback)
	-- Setup adapter
	local adapter = codecompanion_adapter.resolve(codecompanion_config.strategies.chat.adapter)
	if not adapter then
		return callback(nil, "Failed to resolve adapter")
	end

	adapter.opts.stream = false
	adapter = adapter:map_schema_to_params()

	-- Create HTTP client
	local new_client = client.new({
		adapter = adapter,
	})

	-- Create prompt for LLM
	local prompt = Generator._create_prompt(diff)

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
---@return string prompt The formatted prompt
function Generator._create_prompt(diff)
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

Based on the git diff provided below, generate a standardized commit message.

```diff
%s
```

]],
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