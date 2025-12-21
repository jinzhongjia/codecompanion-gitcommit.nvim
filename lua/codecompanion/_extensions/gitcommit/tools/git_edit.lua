local GitTool = require("codecompanion._extensions.gitcommit.tools.git").GitTool
local validation = require("codecompanion._extensions.gitcommit.tools.validation")

---@class CodeCompanion.GitCommit.Tools.GitEdit
local GitEdit = {}

GitEdit.name = "git_edit"
GitEdit.description = "Tool for write-access Git operations like stage, unstage, branch creation, etc."

GitEdit.schema = {
  type = "function",
  ["function"] = {
    name = "git_edit",
    description = "Execute various write-access Git operations.",
    parameters = {
      type = "object",
      properties = {
        operation = {
          type = "string",
          enum = {
            "stage",
            "unstage",
            "commit",
            "create_branch",
            "checkout",
            "stash",
            "apply_stash",
            "reset",
            "gitignore_add",
            "gitignore_remove",
            "push",
            "fetch",
            "pull",
            "add_remote",
            "remove_remote",
            "rename_remote",
            "set_remote_url",
            "cherry_pick",
            "revert",
            "create_tag",
            "delete_tag",
            "merge",
            "help",
          },
          description = "The write-access Git operation to perform.",
        },
        args = {
          type = "object",
          properties = {
            files = {
              type = "array",
              items = { type = "string" },
              description = "Required: List of files to stage/unstage (can use '.' for all files)",
            },
            branch_name = {
              type = "string",
              description = "Name of the branch",
            },
            checkout = {
              type = "boolean",
              description = "Whether to checkout new branch",
            },
            target = {
              type = "string",
              description = "Target branch or commit for checkout",
            },
            message = {
              type = "string",
              description = "Message for stash or commit",
            },
            commit_message = {
              type = "string",
              description = "Optional commit message for the commit operation. If not provided, will automatically analyze staged diff and generate Conventional Commit compliant message using format: type(scope): description with types: feat,fix,docs,style,refactor,perf,test,chore.",
            },
            amend = {
              type = "boolean",
              description = "Amend the last commit instead of creating a new one",
            },
            include_untracked = {
              type = "boolean",
              description = "Include untracked files in stash",
            },
            stash_ref = {
              type = "string",
              description = "Stash reference (e.g., stash@{0})",
            },
            commit_hash = {
              type = "string",
              description = "Commit hash or reference for reset",
            },
            mode = {
              type = "string",
              enum = { "soft", "mixed", "hard" },
              description = "Reset mode",
            },
            gitignore_rule = {
              type = "string",
              description = "Rule to add or remove from .gitignore",
            },
            gitignore_rules = {
              type = "array",
              items = { type = "string" },
              description = "Multiple rules to add or remove from .gitignore",
            },
            remote = {
              type = "string",
              description = "The name of the remote to push to (e.g., origin)",
            },
            branch = {
              type = "string",
              description = "The name of the branch to push or merge",
            },
            force = {
              type = "boolean",
              description = "Force push (DANGEROUS: overwrites remote history)",
            },
            set_upstream = {
              type = "boolean",
              description = "Set the upstream branch for the current local branch",
            },
            tags = {
              type = "boolean",
              description = "Push all tags",
            },
            single_tag_name = {
              type = "string",
              description = "The name of a single tag to push",
            },
            cherry_pick_commit_hash = {
              type = "string",
              description = "The commit hash to cherry-pick",
            },
            revert_commit_hash = {
              type = "string",
              description = "The commit hash to revert",
            },
            tag_name = {
              type = "string",
              description = "The name of the tag",
            },
            tag_message = {
              type = "string",
              description = "An optional message for an annotated tag",
            },
            tag_commit_hash = {
              type = "string",
              description = "An optional commit hash to tag",
            },
            remote_name = {
              type = "string",
              description = "Name of the remote",
            },
            remote_url = {
              type = "string",
              description = "URL of the remote repository",
            },
            new_remote_name = {
              type = "string",
              description = "New name for the remote (used in rename_remote)",
            },
            prune = {
              type = "boolean",
              description = "Remove remote-tracking references that no longer exist (for fetch)",
            },
            rebase = {
              type = "boolean",
              description = "Use rebase instead of merge (for pull)",
            },
          },
          additionalProperties = false,
        },
      },
      required = { "operation" },
      additionalProperties = false,
    },
    strict = true,
  },
}

GitEdit.system_prompt = [[# Git Edit Tool (`git_edit`)

## CONTEXT
- You have access to a write-access Git tool running within CodeCompanion, in Neovim.
- Use this tool to modify repository state: staging, committing, branching, etc.
- These operations can modify the repository, so use them carefully.

## OBJECTIVE
- Follow the tool's schema strictly.
- Use the appropriate operation for the task.
- For commits without a message, analyze staged changes and generate Conventional Commit format.

## AVAILABLE OPERATIONS
| Operation | Description | Required Args |
|-----------|-------------|---------------|
| `stage` | Stage files for commit | files (required) |
| `unstage` | Unstage files | files (required) |
| `commit` | Commit staged changes | commit_message? (auto-generates if empty) |
| `create_branch` | Create new branch | branch_name (required), checkout? |
| `checkout` | Switch branch/commit | target (required) |
| `stash` | Stash changes | message?, include_untracked? |
| `apply_stash` | Apply stash | stash_ref? |
| `reset` | Reset to commit | commit_hash (required), mode? |
| `gitignore_add` | Add .gitignore rules | gitignore_rules (required) |
| `gitignore_remove` | Remove .gitignore rules | gitignore_rule (required) |
| `push` | Push to remote | remote?, branch?, set_upstream?, tags?, single_tag_name? |
| `fetch` | Fetch from remote | remote?, branch?, prune? |
| `pull` | Pull from remote | remote?, branch?, rebase? |
| `add_remote` | Add new remote | remote_name (required), remote_url (required) |
| `remove_remote` | Remove remote | remote_name (required) |
| `rename_remote` | Rename remote | remote_name (required), new_remote_name (required) |
| `set_remote_url` | Change remote URL | remote_name (required), remote_url (required) |
| `cherry_pick` | Apply commit | cherry_pick_commit_hash (required) |
| `revert` | Revert commit | revert_commit_hash (required) |
| `create_tag` | Create tag | tag_name (required), tag_message? |
| `delete_tag` | Delete tag | tag_name (required) |
| `merge` | Merge branch | branch (required) |
| `help` | Show help | - |

## PUSH OPERATION NOTES
- To push a single tag: use `single_tag_name` parameter (remote defaults to "origin")
- To push all tags: use `tags: true` parameter
- Do NOT use `single_tag_name` as the `branch` parameter

## SAFETY RESTRICTIONS
- Never use force push without explicit user confirmation.
- Always verify staged changes before committing.
- Warn users before destructive operations (reset --hard, delete).

## RESPONSE
- Only invoke this tool when modifying Git repository state.
- For commit messages, use Conventional Commit format: type(scope): description.]]

local TOOL_NAME = "gitEdit"
local VALID_OPERATIONS = {
  "stage",
  "unstage",
  "commit",
  "create_branch",
  "checkout",
  "stash",
  "apply_stash",
  "reset",
  "gitignore_add",
  "gitignore_remove",
  "push",
  "fetch",
  "pull",
  "add_remote",
  "remove_remote",
  "rename_remote",
  "set_remote_url",
  "cherry_pick",
  "revert",
  "create_tag",
  "delete_tag",
  "merge",
  "help",
}
local VALID_RESET_MODES = { "soft", "mixed", "hard" }

GitEdit.cmds = {
  function(self, args, input, output_handler)
    if args == nil or type(args) ~= "table" then
      return validation.format_error(TOOL_NAME, "Invalid arguments: expected object")
    end

    local operation = args.operation
    local err = validation.require_enum(operation, "operation", VALID_OPERATIONS, TOOL_NAME)
    if err then
      return err
    end

    local op_args = args.args
    if op_args ~= nil and type(op_args) ~= "table" then
      return validation.format_error(TOOL_NAME, "args must be an object")
    end
    op_args = op_args or {}

    if operation == "help" then
      local help_text = [[
Available write-access Git operations:
• stage/unstage: Stage/unstage files (requires files parameter)
• commit: Commit staged changes (automatically generates AI message from staged diff if no message provided)
• create_branch: Create new branch
• checkout: Switch branch/commit
• stash/apply_stash: Stash operations
• reset: Reset to specific commit
• gitignore_add: Add rule to .gitignore
• gitignore_remove: Remove rule from .gitignore
• push: Push changes to a remote repository (WARNING: force push is dangerous)
• fetch: Fetch from remote (prune option available)
• pull: Pull from remote (rebase option available)
• add_remote: Add a new remote repository
• remove_remote: Remove a remote repository
• rename_remote: Rename a remote repository
• set_remote_url: Change URL of a remote repository
• cherry_pick: Apply changes from existing commits
• revert: Revert a commit
• create_tag: Create a new tag
• delete_tag: Delete a tag
• merge: Merge a branch into the current branch (requires branch parameter)
      ]]
      return { status = "success", data = help_text }
    end

    if operation == "push" then
      local param_err = validation.first_error({
        validation.optional_string(op_args.remote, "remote", TOOL_NAME),
        validation.optional_string(op_args.branch, "branch", TOOL_NAME),
        validation.optional_boolean(op_args.force, "force", TOOL_NAME),
        validation.optional_boolean(op_args.set_upstream, "set_upstream", TOOL_NAME),
        validation.optional_boolean(op_args.tags, "tags", TOOL_NAME),
        validation.optional_string(op_args.single_tag_name, "single_tag_name", TOOL_NAME),
      })
      if param_err then
        return param_err
      end
      -- If set_upstream is not explicitly specified, default to true for automatic remote tracking
      if op_args.set_upstream == nil then
        op_args.set_upstream = true
      end
      return GitTool.push_async(
        op_args.remote,
        op_args.branch,
        op_args.force,
        op_args.set_upstream,
        op_args.tags,
        op_args.single_tag_name,
        output_handler
      )
    end

    -- Safely execute operations through pcall to ensure there's always a response
    local ok, result = pcall(function()
      local success, output
      local param_err

      if operation == "stage" then
        param_err = validation.require_array(op_args.files, "files", TOOL_NAME)
        if param_err then
          return param_err
        end
        success, output = GitTool.stage_files(op_args.files)
      elseif operation == "unstage" then
        param_err = validation.require_array(op_args.files, "files", TOOL_NAME)
        if param_err then
          return param_err
        end
        success, output = GitTool.unstage_files(op_args.files)
      elseif operation == "commit" then
        param_err = validation.first_error({
          validation.optional_string(op_args.commit_message, "commit_message", TOOL_NAME),
          validation.optional_string(op_args.message, "message", TOOL_NAME),
          validation.optional_boolean(op_args.amend, "amend", TOOL_NAME),
        })
        if param_err then
          return param_err
        end
        local message = op_args.commit_message or op_args.message
        if not message then
          -- Check if there are staged changes
          local diff_success, diff_output = GitTool.get_diff(true) -- staged changes
          if not diff_success or not diff_output or vim.trim(diff_output) == "" then
            return {
              status = "error",
              data = "No staged changes found for commit. Please stage your changes first using the stage operation.",
            }
          end

          -- Return success with instruction for AI to use the diff tool
          return {
            status = "success",
            data = "No commit message provided. I need to generate a Conventional Commit compliant message. Please use the `@{git_read} diff --staged` tool to see the changes and then create an appropriate commit message.",
          }
        end
        success, output = GitTool.commit(message, op_args.amend)
      elseif operation == "create_branch" then
        param_err = validation.first_error({
          validation.require_string(op_args.branch_name, "branch_name", TOOL_NAME),
          validation.optional_boolean(op_args.checkout, "checkout", TOOL_NAME),
        })
        if param_err then
          return param_err
        end
        success, output = GitTool.create_branch(op_args.branch_name, op_args.checkout)
      elseif operation == "checkout" then
        param_err = validation.require_string(op_args.target, "target", TOOL_NAME)
        if param_err then
          return param_err
        end
        success, output = GitTool.checkout(op_args.target)
      elseif operation == "stash" then
        param_err = validation.first_error({
          validation.optional_string(op_args.message, "message", TOOL_NAME),
          validation.optional_boolean(op_args.include_untracked, "include_untracked", TOOL_NAME),
        })
        if param_err then
          return param_err
        end
        success, output = GitTool.stash(op_args.message, op_args.include_untracked)
      elseif operation == "apply_stash" then
        param_err = validation.optional_string(op_args.stash_ref, "stash_ref", TOOL_NAME)
        if param_err then
          return param_err
        end
        success, output = GitTool.apply_stash(op_args.stash_ref)
      elseif operation == "reset" then
        param_err = validation.first_error({
          validation.require_string(op_args.commit_hash, "commit_hash", TOOL_NAME),
          op_args.mode and validation.require_enum(op_args.mode, "mode", VALID_RESET_MODES, TOOL_NAME) or nil,
        })
        if param_err then
          return param_err
        end
        success, output = GitTool.reset(op_args.commit_hash, op_args.mode)
      elseif operation == "gitignore_add" then
        local rules = op_args.gitignore_rules or op_args.gitignore_rule
        if rules == nil then
          return validation.format_error(TOOL_NAME, "gitignore_rules or gitignore_rule is required")
        end
        if type(rules) ~= "table" and type(rules) ~= "string" then
          return validation.format_error(
            TOOL_NAME,
            "gitignore_rules must be an array or gitignore_rule must be a string"
          )
        end
        success, output = GitTool.add_gitignore_rule(rules)
      elseif operation == "gitignore_remove" then
        local rules = op_args.gitignore_rules or op_args.gitignore_rule
        if rules == nil then
          return validation.format_error(TOOL_NAME, "gitignore_rules or gitignore_rule is required")
        end
        if type(rules) ~= "table" and type(rules) ~= "string" then
          return validation.format_error(
            TOOL_NAME,
            "gitignore_rules must be an array or gitignore_rule must be a string"
          )
        end
        success, output = GitTool.remove_gitignore_rule(rules)
      elseif operation == "cherry_pick" then
        param_err = validation.require_string(op_args.cherry_pick_commit_hash, "cherry_pick_commit_hash", TOOL_NAME)
        if param_err then
          return param_err
        end
        success, output = GitTool.cherry_pick(op_args.cherry_pick_commit_hash)
      elseif operation == "revert" then
        param_err = validation.require_string(op_args.revert_commit_hash, "revert_commit_hash", TOOL_NAME)
        if param_err then
          return param_err
        end
        success, output = GitTool.revert(op_args.revert_commit_hash)
      elseif operation == "create_tag" then
        param_err = validation.first_error({
          validation.require_string(op_args.tag_name, "tag_name", TOOL_NAME),
          validation.optional_string(op_args.tag_message, "tag_message", TOOL_NAME),
          validation.optional_string(op_args.tag_commit_hash, "tag_commit_hash", TOOL_NAME),
        })
        if param_err then
          return param_err
        end
        success, output = GitTool.create_tag(op_args.tag_name, op_args.tag_message, op_args.tag_commit_hash)
      elseif operation == "delete_tag" then
        param_err = validation.first_error({
          validation.require_string(op_args.tag_name, "tag_name", TOOL_NAME),
          validation.optional_string(op_args.remote, "remote", TOOL_NAME),
        })
        if param_err then
          return param_err
        end
        success, output = GitTool.delete_tag(op_args.tag_name, op_args.remote)
      elseif operation == "merge" then
        param_err = validation.require_string(op_args.branch, "branch", TOOL_NAME)
        if param_err then
          return param_err
        end
        success, output = GitTool.merge(op_args.branch)
      elseif operation == "fetch" then
        param_err = validation.first_error({
          validation.optional_string(op_args.remote, "remote", TOOL_NAME),
          validation.optional_string(op_args.branch, "branch", TOOL_NAME),
          validation.optional_boolean(op_args.prune, "prune", TOOL_NAME),
        })
        if param_err then
          return param_err
        end
        success, output = GitTool.fetch(op_args.remote, op_args.branch, op_args.prune)
      elseif operation == "pull" then
        param_err = validation.first_error({
          validation.optional_string(op_args.remote, "remote", TOOL_NAME),
          validation.optional_string(op_args.branch, "branch", TOOL_NAME),
          validation.optional_boolean(op_args.rebase, "rebase", TOOL_NAME),
        })
        if param_err then
          return param_err
        end
        success, output = GitTool.pull(op_args.remote, op_args.branch, op_args.rebase)
      elseif operation == "add_remote" then
        param_err = validation.first_error({
          validation.require_string(op_args.remote_name, "remote_name", TOOL_NAME),
          validation.require_string(op_args.remote_url, "remote_url", TOOL_NAME),
        })
        if param_err then
          return param_err
        end
        success, output = GitTool.add_remote(op_args.remote_name, op_args.remote_url)
      elseif operation == "remove_remote" then
        param_err = validation.require_string(op_args.remote_name, "remote_name", TOOL_NAME)
        if param_err then
          return param_err
        end
        success, output = GitTool.remove_remote(op_args.remote_name)
      elseif operation == "rename_remote" then
        param_err = validation.first_error({
          validation.require_string(op_args.remote_name, "remote_name", TOOL_NAME),
          validation.require_string(op_args.new_remote_name, "new_remote_name", TOOL_NAME),
        })
        if param_err then
          return param_err
        end
        success, output = GitTool.rename_remote(op_args.remote_name, op_args.new_remote_name)
      elseif operation == "set_remote_url" then
        param_err = validation.first_error({
          validation.require_string(op_args.remote_name, "remote_name", TOOL_NAME),
          validation.require_string(op_args.remote_url, "remote_url", TOOL_NAME),
        })
        if param_err then
          return param_err
        end
        success, output = GitTool.set_remote_url(op_args.remote_name, op_args.remote_url)
      else
        return validation.format_error(TOOL_NAME, "Unknown Git edit operation: " .. tostring(operation))
      end

      return { success = success, output = output }
    end)

    -- Handle unexpected execution errors
    if not ok then
      local error_msg = "Git edit operation failed unexpectedly: " .. tostring(result)
      return { status = "error", data = error_msg }
    end

    -- Check if this is an early return case
    if result.status then
      return result
    end

    local success, output = result.success, result.output

    -- Ensure proper response even if operation fails
    if success then
      return { status = "success", data = output }
    else
      return { status = "error", data = output or "Git operation failed without specific error message" }
    end
  end,
}

GitEdit.handlers = {
  setup = function(self, agent)
    return true
  end,
  on_exit = function(self, agent) end,
}

GitEdit.output = {
  prompt = function(self, _tools)
    local operation = self.args and self.args.operation or "unknown"
    local details = ""
    if operation == "stage" or operation == "unstage" then
      local files = self.args.args and self.args.args.files
      if files then
        details = string.format(" (%s)", type(files) == "table" and table.concat(files, ", ") or files)
      end
    elseif operation == "commit" then
      local msg = self.args.args and self.args.args.commit_message
      details = msg and string.format(" with message: %s", msg:sub(1, 50)) or " (auto-generate message)"
    elseif operation == "create_branch" then
      local branch = self.args.args and self.args.args.branch_name
      details = branch and string.format(": %s", branch) or ""
    end
    return string.format("Execute git %s%s?", operation, details)
  end,

  success = function(self, agent, _cmd, stdout)
    local chat = agent.chat
    local operation = self.args.operation
    local user_msg = string.format("Git edit operation [%s] executed successfully", operation)
    return chat:add_tool_output(self, stdout[1], user_msg)
  end,

  error = function(self, agent, _cmd, stderr, stdout)
    local chat = agent.chat
    local operation = self.args.operation
    local error_msg = stderr and stderr[1] or ("Git edit operation [%s] failed"):format(operation)
    local user_msg = string.format("Git edit operation [%s] failed", operation)
    return chat:add_tool_output(self, error_msg, user_msg)
  end,

  rejected = function(self, tools, _cmd, _opts)
    local chat = tools.chat
    local operation = self.args and self.args.operation or "unknown"
    local message = string.format("User rejected the git %s operation", operation)
    return chat:add_tool_output(self, message, message)
  end,
}

GitEdit.opts = {
  -- v18+ uses require_approval_before
  require_approval_before = function(self, agent)
    return true
  end,
  -- COMPAT(v17): Remove when dropping v17 support
  requires_approval = function(self, agent)
    return true
  end,
}

return GitEdit
