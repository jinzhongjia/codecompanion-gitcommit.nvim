local GitTool = require("codecompanion._extensions.gitcommit.tools.git").GitTool

---@class CodeCompanion.GitCommit.Tools.GitBot
local GitBot = {}

-- Tool configuration for CodeCompanion
GitBot.name = "git_bot"
GitBot.description = "Advanced Git operations and assistance tool"

-- OpenAI compatible schema for function calling
GitBot.schema = {
  type = "function",
  ["function"] = {
    name = "git_bot",
    description = "Execute various Git operations and provide Git assistance",
    parameters = {
      type = "object",
      properties = {
        operation = {
          type = "string",
          enum = {
            "status", "log", "diff", "branch", "stage", "unstage", 
            "create_branch", "checkout", "remotes", "show", "blame", 
            "stash", "stash_list", "apply_stash", "reset", "diff_commits",
            "contributors", "search_commits", "help"
          },
          description = "The Git operation to perform",
        },
        args = {
          type = "object",
          properties = {
            files = {
              type = "array",
              items = { type = "string" },
              description = "List of files to operate on",
            },
            count = {
              type = "integer",
              description = "Number of items to show (for log, contributors, etc.)",
            },
            format = {
              type = "string",
              description = "Format for log output (oneline, short, full, etc.)",
            },
            staged = {
              type = "boolean",
              description = "Whether to show staged changes for diff",
            },
            branch_name = {
              type = "string",
              description = "Name of the branch",
            },
            commit_hash = {
              type = "string",
              description = "Commit hash or reference",
            },
            target = {
              type = "string",
              description = "Target branch or commit for checkout",
            },
            file_path = {
              type = "string",
              description = "Path to a specific file",
            },
            line_start = {
              type = "integer",
              description = "Start line number for blame",
            },
            line_end = {
              type = "integer",
              description = "End line number for blame",
            },
            message = {
              type = "string",
              description = "Message for stash or commit",
            },
            include_untracked = {
              type = "boolean",
              description = "Include untracked files in stash",
            },
            mode = {
              type = "string",
              enum = { "soft", "mixed", "hard" },
              description = "Reset mode",
            },
            pattern = {
              type = "string",
              description = "Search pattern for commits",
            },
            commit1 = {
              type = "string",
              description = "First commit for diff",
            },
            commit2 = {
              type = "string",
              description = "Second commit for diff",
            },
            checkout = {
              type = "boolean",
              description = "Whether to checkout new branch",
            },
            remote_only = {
              type = "boolean",
              description = "Show only remote branches",
            },
            stash_ref = {
              type = "string",
              description = "Stash reference (e.g., stash@{0})",
            }
          },
          additionalProperties = false,
        }
      },
      required = { "operation" },
      additionalProperties = false,
    },
    strict = true,
  },
}

-- System prompt for the LLM
GitBot.system_prompt = [[## Git Bot Tool (`git_bot`)

## CONTEXT
- You have access to a comprehensive Git operations tool within CodeCompanion.
- You can perform various Git operations like status, diff, log, branch management, stashing, and more.
- Always check if you're in a Git repository before performing operations.

## OBJECTIVE
- Help users with Git operations through natural language commands
- Provide helpful information about repository state
- Assist with branch management and file operations
- Execute Git commands safely with proper error handling

## AVAILABLE OPERATIONS
- `status`: Show repository status
- `log`: Show commit history (args: count, format)
- `diff`: Show differences (args: staged, file_path)
- `branch`: List branches (args: remote_only)
- `stage`: Stage files (args: files)
- `unstage`: Unstage files (args: files)
- `create_branch`: Create new branch (args: branch_name, checkout)
- `checkout`: Switch branch/commit (args: target)
- `remotes`: Show remote repositories
- `show`: Show commit details (args: commit_hash)
- `blame`: Show file blame information (args: file_path, line_start, line_end)
- `stash`: Stash changes (args: message, include_untracked)
- `stash_list`: List stashes
- `apply_stash`: Apply stash (args: stash_ref)
- `reset`: Reset to commit (args: commit_hash, mode)
- `diff_commits`: Compare commits (args: commit1, commit2, file_path)
- `contributors`: Show top contributors (args: count)
- `search_commits`: Search commits by message (args: pattern, count)
- `help`: Show available operations

## RESPONSE FORMAT
- Always provide clear, helpful output
- Include context about what the operation does
- Show relevant Git command information when helpful
- Format output for easy reading
]]

-- Command functions for the tool
GitBot.cmds = {
  function(self, args, input)
    local operation = args.operation
    local op_args = args.args or {}
    
    -- Handle help operation
    if operation == "help" then
      local help_text = [[
Available Git operations:
• status - Show repository status
• log - Show commit history
• diff - Show file differences  
• branch - List branches
• stage/unstage - Stage/unstage files
• create_branch - Create new branch
• checkout - Switch branch/commit
• remotes - Show remote repositories
• show - Show commit details
• blame - Show file blame info
• stash/stash_list/apply_stash - Stash operations
• reset - Reset to specific commit
• diff_commits - Compare commits
• contributors - Show contributors
• search_commits - Search commit messages
      ]]
      return { status = "success", data = help_text }
    end
    
    local success, output
    
    -- Execute the requested Git operation
    if operation == "status" then
      success, output = GitTool.get_status()
      
    elseif operation == "log" then
      success, output = GitTool.get_log(op_args.count, op_args.format)
      
    elseif operation == "diff" then
      success, output = GitTool.get_diff(op_args.staged, op_args.file_path)
      
    elseif operation == "branch" then
      success, output = GitTool.get_branches(op_args.remote_only)
      
    elseif operation == "stage" then
      if not op_args.files or #op_args.files == 0 then
        return { status = "error", data = "No files specified for staging" }
      end
      success, output = GitTool.stage_files(op_args.files)
      
    elseif operation == "unstage" then
      if not op_args.files or #op_args.files == 0 then
        return { status = "error", data = "No files specified for unstaging" }
      end
      success, output = GitTool.unstage_files(op_args.files)
      
    elseif operation == "create_branch" then
      if not op_args.branch_name then
        return { status = "error", data = "Branch name is required" }
      end
      success, output = GitTool.create_branch(op_args.branch_name, op_args.checkout)
      
    elseif operation == "checkout" then
      if not op_args.target then
        return { status = "error", data = "Target branch or commit is required" }
      end
      success, output = GitTool.checkout(op_args.target)
      
    elseif operation == "remotes" then
      success, output = GitTool.get_remotes()
      
    elseif operation == "show" then
      success, output = GitTool.show_commit(op_args.commit_hash)
      
    elseif operation == "blame" then
      if not op_args.file_path then
        return { status = "error", data = "File path is required for blame" }
      end
      success, output = GitTool.get_blame(op_args.file_path, op_args.line_start, op_args.line_end)
      
    elseif operation == "stash" then
      success, output = GitTool.stash(op_args.message, op_args.include_untracked)
      
    elseif operation == "stash_list" then
      success, output = GitTool.list_stashes()
      
    elseif operation == "apply_stash" then
      success, output = GitTool.apply_stash(op_args.stash_ref)
      
    elseif operation == "reset" then
      if not op_args.commit_hash then
        return { status = "error", data = "Commit hash is required for reset" }
      end
      success, output = GitTool.reset(op_args.commit_hash, op_args.mode)
      
    elseif operation == "diff_commits" then
      if not op_args.commit1 then
        return { status = "error", data = "First commit is required for comparison" }
      end
      success, output = GitTool.diff_commits(op_args.commit1, op_args.commit2, op_args.file_path)
      
    elseif operation == "contributors" then
      success, output = GitTool.get_contributors(op_args.count)
      
    elseif operation == "search_commits" then
      if not op_args.pattern then
        return { status = "error", data = "Search pattern is required" }
      end
      success, output = GitTool.search_commits(op_args.pattern, op_args.count)
      
    else
      return { status = "error", data = "Unknown Git operation: " .. operation }
    end
    
    if success then
      return { status = "success", data = output }
    else
      return { status = "error", data = output }
    end
  end
}

-- Handlers for setup and cleanup
GitBot.handlers = {
  setup = function(self, agent)
    -- Optional setup logic
    return true
  end,
  
  on_exit = function(self, agent)
    -- Optional cleanup logic
  end,
}

-- Output handlers
GitBot.output = {
  success = function(self, agent, cmd, stdout)
    local chat = agent.chat
    local operation = self.args.operation
    local result = stdout[1]
    
    -- Format the output based on operation type
    local formatted_output
    if operation == "status" then
      formatted_output = "📊 **Git Status:**\n```\n" .. result .. "\n```"
    elseif operation == "log" then
      formatted_output = "📜 **Git Log:**\n```\n" .. result .. "\n```"
    elseif operation == "diff" then
      formatted_output = "🔍 **Git Diff:**\n```diff\n" .. result .. "\n```"
    elseif operation == "branch" then
      formatted_output = "🌿 **Git Branches:**\n```\n" .. result .. "\n```"
    elseif operation == "blame" then
      formatted_output = "👤 **Git Blame:**\n```\n" .. result .. "\n```"
    else
      formatted_output = "✅ **Git " .. operation .. ":**\n```\n" .. result .. "\n```"
    end
    
    return chat:add_tool_output(self, result, formatted_output)
  end,
  
  error = function(self, agent, cmd, stderr, stdout)
    local chat = agent.chat
    local error_msg = stderr[1] or "Unknown Git error occurred"
    local formatted_error = "❌ **Git Error:**\n```\n" .. error_msg .. "\n```"
    
    return chat:add_tool_output(self, error_msg, formatted_error)
  end,
}

-- Optional: No approval required for read-only operations
GitBot.opts = {
  requires_approval = function(self, agent)
    local safe_operations = {
      "status", "log", "diff", "branch", "remotes", "show", 
      "blame", "stash_list", "contributors", "search_commits", "help"
    }
    
    local operation = self.args.operation
    return not vim.tbl_contains(safe_operations, operation)
  end
}

return GitBot