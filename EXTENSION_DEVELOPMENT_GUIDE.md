# CodeCompanion Extension Development Guide

This comprehensive guide covers everything you need to know about creating extensions for CodeCompanion.nvim, including feature integration, best practices, and complete examples.

## Table of Contents

1. [Overview](#overview)
2. [Extension Architecture](#extension-architecture)
3. [Basic Extension Structure](#basic-extension-structure)
4. [Feature Integration](#feature-integration)
5. [Complete Examples](#complete-examples)
6. [Distribution & Installation](#distribution--installation)
7. [Best Practices](#best-practices)
8. [API Reference](#api-reference)

## Overview

CodeCompanion extensions allow you to extend the functionality of the plugin by adding custom actions, slash commands, tools, variables, keymaps, and more. Extensions can be distributed as separate plugins or defined locally in your configuration.

### What Extensions Can Do

- Add custom keymaps to chat buffers
- Create new slash commands (e.g., `/custom`)
- Add new tools for agent workflows
- Define custom variables (e.g., `#custom_var`)
- Integrate with external services
- Extend the action palette
- Add custom UI components
- Hook into chat events and workflows

## Extension Architecture

Extensions in CodeCompanion follow a simple but powerful architecture:

```lua
---@class CodeCompanion.Extension
---@field setup fun(opts: table): any Function called when extension is loaded
---@field exports? table Optional table of functions exposed via codecompanion.extensions.name
local Extension = {}

function Extension.setup(opts)
  -- Initialize extension with configuration
end

Extension.exports = {
  -- Functions accessible via require("codecompanion").extensions.extension_name
}

return Extension
```

The extension system uses a module loader that resolves extensions from:
1. Runtime path: `codecompanion._extensions.extension_name`
2. Local callbacks in configuration
3. Direct module paths

## Basic Extension Structure

### Plugin Distribution Structure

```
your-extension/
├── lua/
│   └── codecompanion/
│       └── _extensions/
│           └── your_extension/
│               └── init.lua  -- Main extension file
├── README.md
└── doc/
    └── your_extension.txt    -- Optional documentation
```

### Minimal Extension Template

```lua
---@class CodeCompanion.Extension.YourExtension
local Extension = {}

---Setup the extension
---@param opts table Configuration options passed from setup
function Extension.setup(opts)
  -- Merge user options with defaults
  local config = vim.tbl_deep_extend("force", {
    -- Default configuration
    default_option = "value",
    keymap = "gx",
  }, opts or {})
  
  -- Initialize your extension here
  -- Add keymaps, commands, etc.
end

-- Optional: Expose functions to other plugins/users
Extension.exports = {
  get_status = function()
    return "Extension is running"
  end,
  
  custom_action = function()
    vim.notify("Custom action executed!")
  end,
}

return Extension
```

## Feature Integration

### Adding Chat Keymaps

Extensions can add custom keymaps to chat buffers:

```lua
function Extension.setup(opts)
  local config = require("codecompanion.config")
  local chat_keymaps = config.strategies.chat.keymaps
  
  -- Add a new keymap
  chat_keymaps.custom_action = {
    modes = {
      n = opts.keymap or "gx", -- Normal mode keymap
      i = "<C-x>",             -- Insert mode keymap
    },
    description = "Execute custom action",
    callback = function(chat)
      -- Access to the current chat object
      vim.notify("Custom action for chat: " .. chat.id)
      
      -- You can:
      -- - Manipulate chat messages: chat.messages
      -- - Access chat context: chat.context
      -- - Get current adapter: chat.adapter
      -- - Trigger submissions: chat:submit()
      -- - Access UI methods: chat.ui:method()
    end,
    
    -- Optional: Conditional display
    condition = function()
      return vim.fn.has("nvim-0.10") == 1
    end,
    
    -- Optional: Hide from help/options
    hide = false,
  }
end
```

### Creating Slash Commands

Add custom slash commands that users can type in chat:

```lua
function Extension.setup(opts)
  local config = require("codecompanion.config")
  local slash_commands = config.strategies.chat.slash_commands
  
  slash_commands.custom = {
    description = "Execute custom slash command",
    opts = {
      contains_code = false,
      user_prompt = false,
    },
    callback = "path.to.your.slash_command", -- or function
  }
end

-- In your slash command module (path/to/your/slash_command.lua):
local SlashCommand = {}

function SlashCommand.new(args)
  return setmetatable({
    Chat = args.Chat,
    config = args.config,
    context = args.context,
  }, { __index = SlashCommand })
end

function SlashCommand:execute()
  -- Implementation
  local chat = self.Chat
  
  -- Add content to chat
  chat:add_message({
    role = "user",
    content = "Custom slash command output"
  })
  
  -- Trigger chat submission
  chat:submit()
end

return SlashCommand
```

### Adding Tools for Agents

Create tools that can be used in agent workflows:

```lua
function Extension.setup(opts)
  local config = require("codecompanion.config")
  local tools = config.strategies.chat.tools
  
  -- Add individual tool
  tools.custom_tool = {
    callback = "strategies.chat.agents.tools.custom_tool",
    description = "Custom tool for agent workflows",
    parameters = {
      type = "object",
      properties = {
        action = {
          type = "string",
          description = "Action to perform",
        },
      },
      required = { "action" },
    },
    opts = {
      requires_approval = false,
    },
  }
  
  -- Add tool group
  tools.groups.custom_group = {
    description = "Custom tool group",
    tools = { "custom_tool", "another_tool" },
    opts = {
      collapse_tools = true,
    },
  }
end

-- Tool implementation (strategies/chat/agents/tools/custom_tool.lua):
local log = require("codecompanion.utils.log")

local TOOL_NAME = "custom_tool"

local Tool = {}

function Tool.new(args)
  return setmetatable({
    name = TOOL_NAME,
    cmds = args.cmds or {},
  }, { __index = Tool })
end

function Tool:execute(action)
  log:debug("Executing custom tool with action: %s", action)
  
  -- Perform your custom action
  local result = "Tool executed successfully with action: " .. action
  
  return {
    status = "success",
    output = result,
  }
end

return Tool
```

### Creating Custom Variables

Add variables that can be used in chat with `#variable_name`:

```lua
function Extension.setup(opts)
  local config = require("codecompanion.config")
  local variables = config.strategies.chat.variables
  
  variables.custom_var = {
    callback = "strategies.chat.variables.custom_var",
    description = "Custom variable description",
    opts = {
      placement = "replace", -- or "before", "after"
    },
  }
end

-- Variable implementation (strategies/chat/variables/custom_var.lua):
local Variable = {}

function Variable.new(args)
  return setmetatable({
    Chat = args.Chat,
    config = args.config,
    context = args.context,
  }, { __index = Variable })
end

function Variable:execute()
  -- Return the variable content
  return {
    status = "success",
    output = "Custom variable content: " .. os.date(),
  }
end

return Variable
```

### Extending Action Palette

Add custom actions to the action palette:

```lua
function Extension.setup(opts)
  local actions = require("codecompanion.actions")
  
  -- Register new action
  actions.register({
    name = "Custom Action",
    strategy = "chat",
    description = "Perform custom action",
    opts = {
      placement = "new",
      type = "action",
    },
    prompts = {
      {
        role = "system",
        content = "You are a helpful assistant for custom tasks.",
      },
      {
        role = "user",
        content = function(context)
          return "Perform custom action on: " .. context.filetype
        end,
      },
    },
  })
end
```

### Event Handling and Hooks

Extensions can hook into various chat events:

```lua
function Extension.setup(opts)
  local config = require("codecompanion.config")
  
  -- Hook into chat events
  vim.api.nvim_create_autocmd("User", {
    pattern = "CodeCompanionChatAdapter",
    callback = function(event)
      local data = event.data
      vim.notify("Adapter changed to: " .. data.adapter.name)
    end,
  })
  
  vim.api.nvim_create_autocmd("User", {
    pattern = "CodeCompanionChatModel", 
    callback = function(event)
      local data = event.data
      vim.notify("Model changed to: " .. data.model)
    end,
  })
end
```

## Complete Examples

### Example 1: Chat History Extension

```lua
---@class CodeCompanion.Extension.History
local Extension = {}

local history_file = vim.fn.stdpath("data") .. "/codecompanion_history.json"

local function load_history()
  local file = io.open(history_file, "r")
  if not file then return {} end
  
  local content = file:read("*all")
  file:close()
  
  local ok, data = pcall(vim.json.decode, content)
  return ok and data or {}
end

local function save_history(history)
  local file = io.open(history_file, "w")
  if not file then return end
  
  file:write(vim.json.encode(history))
  file:close()
end

function Extension.setup(opts)
  local config = vim.tbl_deep_extend("force", {
    max_history = 50,
    keymap = "gh",
    auto_save = true,
  }, opts or {})
  
  local codecompanion_config = require("codecompanion.config")
  local chat_keymaps = codecompanion_config.strategies.chat.keymaps
  
  -- Add keymap to open history
  chat_keymaps.open_history = {
    modes = { n = config.keymap },
    description = "Open chat history",
    callback = function(chat)
      local history = load_history()
      
      if vim.tbl_isempty(history) then
        vim.notify("No chat history found", vim.log.levels.INFO)
        return
      end
      
      vim.ui.select(history, {
        prompt = "Select chat from history:",
        format_item = function(item)
          return string.format("%s - %s", item.date, item.title)
        end,
      }, function(selected)
        if selected then
          -- Restore chat from history
          chat:load_from_history(selected)
        end
      end)
    end,
  }
  
  -- Auto-save chats if enabled
  if config.auto_save then
    vim.api.nvim_create_autocmd("User", {
      pattern = "CodeCompanionChatSaved",
      callback = function(event)
        local history = load_history()
        
        table.insert(history, 1, {
          id = event.data.chat.id,
          title = event.data.chat.title or "Untitled Chat",
          date = os.date("%Y-%m-%d %H:%M"),
          messages = event.data.chat.messages,
          adapter = event.data.chat.adapter.name,
        })
        
        -- Keep only max_history entries
        if #history > config.max_history then
          history = vim.list_slice(history, 1, config.max_history)
        end
        
        save_history(history)
      end,
    })
  end
end

Extension.exports = {
  get_history = load_history,
  save_history = save_history,
  clear_history = function()
    save_history({})
    vim.notify("Chat history cleared", vim.log.levels.INFO)
  end,
}

return Extension
```

### Example 2: Code Review Extension

```lua
---@class CodeCompanion.Extension.CodeReview
local Extension = {}

function Extension.setup(opts)
  local config = vim.tbl_deep_extend("force", {
    keymap = "gr",
    review_style = "detailed", -- "detailed" or "quick"
  }, opts or {})
  
  local codecompanion_config = require("codecompanion.config")
  local chat_keymaps = codecompanion_config.strategies.chat.keymaps
  local actions = require("codecompanion.actions")
  
  -- Add review keymap
  chat_keymaps.code_review = {
    modes = { n = config.keymap },
    description = "Start code review",
    callback = function(chat)
      -- Get selected text or current buffer
      local mode = vim.fn.mode()
      local content = ""
      
      if mode:match("^[vV]") then
        -- Visual selection
        local start_pos = vim.fn.getpos("v")
        local end_pos = vim.fn.getpos(".")
        content = table.concat(
          vim.api.nvim_buf_get_text(
            0, start_pos[2]-1, start_pos[3]-1, 
            end_pos[2]-1, end_pos[3], {}
          ), "\n"
        )
      else
        -- Entire buffer
        content = table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), "\n")
      end
      
      local review_prompt = config.review_style == "detailed" and
        "Please provide a detailed code review including:\n" ..
        "1. Code quality and best practices\n" ..
        "2. Potential bugs or issues\n" ..
        "3. Performance considerations\n" ..
        "4. Suggestions for improvement\n\n" ..
        "Code to review:\n```\n" .. content .. "\n```"
      or
        "Please provide a quick code review with key issues and suggestions:\n```\n" .. content .. "\n```"
      
      chat:add_message({
        role = "user",
        content = review_prompt,
      })
      
      chat:submit()
    end,
  }
  
  -- Register action for action palette
  actions.register({
    name = "Code Review",
    strategy = "chat",
    description = "Get AI code review for selected code",
    opts = {
      placement = "new",
      type = "action",
    },
    prompts = {
      {
        role = "system",
        content = "You are an expert code reviewer. Provide constructive, actionable feedback.",
      },
      {
        role = "user",
        content = function(context)
          local selection = context.selection or ""
          return "Please review this code:\n```" .. context.filetype .. "\n" .. selection .. "\n```"
        end,
      },
    },
  })
end

Extension.exports = {
  review_buffer = function(bufnr)
    local lines = vim.api.nvim_buf_get_lines(bufnr or 0, 0, -1, false)
    return "Review request for buffer content:\n```\n" .. table.concat(lines, "\n") .. "\n```"
  end,
}

return Extension
```

### Example 3: External Service Integration

```lua
---@class CodeCompanion.Extension.JiraIntegration
local Extension = {}

local curl = require("plenary.curl")

local function make_jira_request(endpoint, method, data)
  local base_url = vim.env.JIRA_BASE_URL
  local token = vim.env.JIRA_API_TOKEN
  
  if not base_url or not token then
    error("JIRA_BASE_URL and JIRA_API_TOKEN environment variables must be set")
  end
  
  local response = curl.request({
    url = base_url .. endpoint,
    method = method or "GET",
    headers = {
      ["Authorization"] = "Bearer " .. token,
      ["Content-Type"] = "application/json",
    },
    body = data and vim.json.encode(data) or nil,
  })
  
  if response.status ~= 200 then
    error("JIRA API request failed: " .. response.status)
  end
  
  return vim.json.decode(response.body)
end

function Extension.setup(opts)
  local config = vim.tbl_deep_extend("force", {
    keymap = "gj",
    project_key = nil,
  }, opts or {})
  
  local codecompanion_config = require("codecompanion.config")
  local chat_keymaps = codecompanion_config.strategies.chat.keymaps
  local slash_commands = codecompanion_config.strategies.chat.slash_commands
  
  -- Add JIRA keymap
  chat_keymaps.jira_search = {
    modes = { n = config.keymap },
    description = "Search JIRA issues",
    callback = function(chat)
      vim.ui.input({ prompt = "Enter JIRA search query: " }, function(query)
        if not query then return end
        
        local issues = make_jira_request("/search?jql=" .. vim.uri_encode(query))
        
        if #issues.issues == 0 then
          vim.notify("No JIRA issues found", vim.log.levels.INFO)
          return
        end
        
        vim.ui.select(issues.issues, {
          prompt = "Select JIRA issue:",
          format_item = function(issue)
            return string.format("%s: %s", issue.key, issue.fields.summary)
          end,
        }, function(selected)
          if selected then
            local issue_info = string.format(
              "JIRA Issue: %s\nSummary: %s\nDescription: %s\nStatus: %s",
              selected.key,
              selected.fields.summary,
              selected.fields.description or "No description",
              selected.fields.status.name
            )
            
            chat:add_message({
              role = "user", 
              content = "Please help me with this JIRA issue:\n\n" .. issue_info,
            })
            
            chat:submit()
          end
        end)
      end)
    end,
  }
  
  -- Add JIRA slash command
  slash_commands.jira = {
    description = "Fetch JIRA issue information",
    opts = {
      contains_code = false,
      user_prompt = false,
    },
    callback = function(chat)
      return require("codecompanion._extensions.jira_integration.slash_command").new({
        Chat = chat,
        config = config,
      })
    end,
  }
end

Extension.exports = {
  search_issues = function(query)
    return make_jira_request("/search?jql=" .. vim.uri_encode(query))
  end,
  
  get_issue = function(issue_key)
    return make_jira_request("/issue/" .. issue_key)
  end,
  
  create_issue = function(project_key, summary, description)
    return make_jira_request("/issue", "POST", {
      fields = {
        project = { key = project_key },
        summary = summary,
        description = description,
        issuetype = { name = "Task" },
      },
    })
  end,
}

return Extension
```

## Distribution & Installation

### As a Plugin

1. Create a plugin repository with the proper structure
2. Users install via their plugin manager:

```lua
-- Using lazy.nvim
{
  "olimorris/codecompanion.nvim",
  dependencies = {
    "your-username/codecompanion-extension-name.nvim"
  }
}

-- Configure the extension
require("codecompanion").setup({
  extensions = {
    extension_name = {
      enabled = true,
      opts = {
        option1 = "value1",
        option2 = "value2",
      }
    }
  }
})
```

### Local Configuration

For simpler extensions or personal use:

```lua
require("codecompanion").setup({
  extensions = {
    my_extension = {
      enabled = true,
      opts = { keymap = "gx" },
      callback = function()
        return {
          setup = function(opts)
            -- Extension implementation
          end,
          exports = {
            -- Exported functions
          }
        }
      end
    }
  }
})
```

### Dynamic Registration

Register extensions at runtime:

```lua
require("codecompanion").register_extension("my_extension", {
  callback = {
    setup = function(opts)
      -- Implementation
    end,
    exports = {}
  }
})
```

## Best Practices

### 1. Configuration Management

```lua
function Extension.setup(opts)
  -- Always provide defaults and merge properly
  local config = vim.tbl_deep_extend("force", {
    enabled = true,
    keymap = "gx",
    timeout = 5000,
  }, opts or {})
  
  -- Validate configuration
  if not config.enabled then
    return
  end
  
  if type(config.keymap) ~= "string" then
    error("Extension keymap must be a string")
  end
end
```

### 2. Error Handling

```lua
function Extension.setup(opts)
  local ok, result = pcall(function()
    -- Extension initialization
  end)
  
  if not ok then
    vim.notify("Extension failed to initialize: " .. result, vim.log.levels.ERROR)
    return
  end
end

-- In callbacks
chat_keymaps.action = {
  callback = function(chat)
    local ok, err = pcall(function()
      -- Action implementation
    end)
    
    if not ok then
      vim.notify("Action failed: " .. err, vim.log.levels.ERROR)
    end
  end,
}
```

### 3. Namespace Management

```lua
-- Prefix your extension functions/variables
local my_extension_state = {}

local function my_extension_helper()
  -- Implementation
end

-- Use unique names for keymaps/commands
chat_keymaps.my_extension_action = {
  -- Implementation
}
```

### 4. Documentation

```lua
---@class CodeCompanion.Extension.MyExtension
---@field setup fun(opts: MyExtensionOpts): nil
---@field exports MyExtensionExports

---@class MyExtensionOpts
---@field enabled? boolean Enable the extension (default: true)
---@field keymap? string Keymap for main action (default: "gx") 
---@field timeout? number Timeout in milliseconds (default: 5000)

---@class MyExtensionExports  
---@field get_status fun(): string Get extension status
---@field custom_action fun(): nil Execute custom action
```

### 5. Testing

```lua
-- In your extension tests
describe("MyExtension", function()
  local extension = require("codecompanion._extensions.my_extension")
  
  it("should setup correctly", function()
    local config = { keymap = "gx" }
    assert.has_no.errors(function()
      extension.setup(config)
    end)
  end)
  
  it("should export functions", function()
    assert.is_not_nil(extension.exports.get_status)
    assert.equals("function", type(extension.exports.get_status))
  end)
end)
```

## API Reference

### Core APIs

#### Chat Object
```lua
chat.id              -- Unique chat identifier
chat.bufnr           -- Chat buffer number
chat.messages        -- Array of chat messages
chat.adapter         -- Current adapter object
chat.context         -- Chat context information
chat.ui              -- UI management object
chat.references      -- Reference management
chat.watchers        -- File watchers

-- Methods
chat:submit()        -- Submit current chat
chat:regenerate()    -- Regenerate last response
chat:clear()         -- Clear chat history
chat:close()         -- Close chat buffer
chat:stop()          -- Stop current request
chat:add_message(msg) -- Add message to chat
```

#### Configuration Access
```lua
local config = require("codecompanion.config")

-- Chat configuration
config.strategies.chat.keymaps      -- Chat keymaps
config.strategies.chat.slash_commands -- Slash commands
config.strategies.chat.tools        -- Tools configuration
config.strategies.chat.variables    -- Variables configuration

-- Adapter configuration
config.adapters                     -- Available adapters
```

#### Utility Functions
```lua
local util = require("codecompanion.utils")
local log = require("codecompanion.utils.log")
local ui = require("codecompanion.utils.ui")

util.notify(message, level)         -- Show notification
log:debug(message, ...)             -- Debug logging
log:info(message, ...)              -- Info logging
log:error(message, ...)             -- Error logging
ui.create_float(content, opts)      -- Create floating window
```

### Event System

CodeCompanion fires various events that extensions can listen to:

```lua
-- Available events
"CodeCompanionChatAdapter"          -- Adapter changed
"CodeCompanionChatModel"            -- Model changed
"CodeCompanionChatSaved"            -- Chat saved
"CodeCompanionChatLoaded"           -- Chat loaded
"CodeCompanionChatSubmitted"        -- Chat submitted
"CodeCompanionChatResponse"         -- Response received
```

### Extension Manager

```lua
local extensions = require("codecompanion._extensions")

-- Load extension
extensions.load_extension(name, schema)

-- Register extension directly
extensions.register_extension(name, extension)

-- Access extension exports
extensions.manager.extension_name.function_name()
```

This guide provides a comprehensive foundation for creating powerful CodeCompanion extensions. Start with simple examples and gradually build more complex functionality as needed.