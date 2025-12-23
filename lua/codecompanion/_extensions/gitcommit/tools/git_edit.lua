local GitTool = require("codecompanion._extensions.gitcommit.tools.git").GitTool
local validation = require("codecompanion._extensions.gitcommit.tools.validation")
local output_utils = require("codecompanion._extensions.gitcommit.tools.output")
local normalize_output = output_utils.normalize_output
local normalize_args = output_utils.normalize_args

---@class CodeCompanion.GitCommit.Tools.GitEdit: CodeCompanion.Tools.Tool
local GitEdit = {}

GitEdit.name = "git_edit"

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
  "rebase",
  "rebase_abort",
  "rebase_continue",
  "add_remote",
  "remove_remote",

  "rename_remote",
  "set_remote_url",
  "cherry_pick",
  "cherry_pick_abort",
  "cherry_pick_continue",
  "cherry_pick_skip",
  "revert",
  "create_tag",
  "delete_tag",
  "merge",
  "merge_abort",
  "merge_continue",
  "help",
}

local VALID_RESET_MODES = { "soft", "mixed", "hard" }
local TOOL_NAME = "gitEdit"

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
          enum = VALID_OPERATIONS,
          description = "The write-access Git operation to perform.",
        },
        files = {
          type = { "array", "null" },
          items = { type = "string" },
          description = "List of files to stage/unstage (can use '.' for all files)",
        },
        branch_name = {
          type = { "string", "null" },
          description = "Name of the branch",
        },
        checkout = {
          type = { "boolean", "null" },
          description = "Whether to checkout new branch",
        },
        target = {
          type = { "string", "null" },
          description = "Target branch or commit for checkout",
        },
        message = {
          type = { "string", "null" },
          description = "Message for stash or commit",
        },
        commit_message = {
          type = { "string", "null" },
          description = "Optional commit message. If not provided, will auto-generate Conventional Commit message.",
        },
        amend = {
          type = { "boolean", "null" },
          description = "Amend the last commit instead of creating a new one",
        },
        include_untracked = {
          type = { "boolean", "null" },
          description = "Include untracked files in stash",
        },
        stash_ref = {
          type = { "string", "null" },
          description = "Stash reference (e.g., stash@{0})",
        },
        commit_hash = {
          type = { "string", "null" },
          description = "Commit hash or reference for reset",
        },
        mode = {
          type = { "string", "null" },
          enum = { "soft", "mixed", "hard" },
          description = "Reset mode",
        },
        gitignore_rule = {
          type = { "string", "null" },
          description = "Rule to add or remove from .gitignore",
        },
        gitignore_rules = {
          type = { "array", "null" },
          items = { type = "string" },
          description = "Multiple rules to add or remove from .gitignore",
        },
        remote = {
          type = { "string", "null" },
          description = "The name of the remote (e.g., origin)",
        },
        branch = {
          type = { "string", "null" },
          description = "The name of the branch to push or merge",
        },
        base = {
          type = { "string", "null" },
          description = "Base branch for rebase",
        },
        onto = {
          type = { "string", "null" },
          description = "Branch to rebase onto",
        },
        interactive = {
          type = { "boolean", "null" },
          description = "Use interactive rebase",
        },
        force = {
          type = { "boolean", "null" },
          description = "Force push (DANGEROUS: overwrites remote history)",
        },
        set_upstream = {
          type = { "boolean", "null" },
          description = "Set the upstream branch for the current local branch",
        },
        tags = {
          type = { "boolean", "null" },
          description = "Push all tags",
        },
        single_tag_name = {
          type = { "string", "null" },
          description = "The name of a single tag to push",
        },
        cherry_pick_commit_hash = {
          type = { "string", "null" },
          description = "The commit hash to cherry-pick",
        },
        revert_commit_hash = {
          type = { "string", "null" },
          description = "The commit hash to revert",
        },
        tag_name = {
          type = { "string", "null" },
          description = "The name of the tag",
        },
        tag_message = {
          type = { "string", "null" },
          description = "An optional message for an annotated tag",
        },
        tag_commit_hash = {
          type = { "string", "null" },
          description = "An optional commit hash to tag",
        },
        remote_name = {
          type = { "string", "null" },
          description = "Name of the remote",
        },
        remote_url = {
          type = { "string", "null" },
          description = "URL of the remote repository",
        },
        new_remote_name = {
          type = { "string", "null" },
          description = "New name for the remote (used in rename_remote)",
        },
        prune = {
          type = { "boolean", "null" },
          description = "Remove remote-tracking references that no longer exist (for fetch)",
        },
        rebase_flag = {
          type = { "boolean", "null" },
          description = "Use rebase instead of merge (for pull)",
        },
      },
      required = {
        "operation",
        "files",
        "branch_name",
        "checkout",
        "target",
        "message",
        "commit_message",
        "amend",
        "include_untracked",
        "stash_ref",
        "commit_hash",
        "mode",
        "gitignore_rule",
        "gitignore_rules",
        "remote",
        "branch",
        "base",
        "onto",
        "interactive",
        "force",
        "set_upstream",
        "tags",
        "single_tag_name",
        "cherry_pick_commit_hash",
        "revert_commit_hash",
        "tag_name",
        "tag_message",
        "tag_commit_hash",
        "remote_name",
        "remote_url",
        "new_remote_name",
        "prune",
        "rebase_flag",
      },
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
- All parameters are passed at the top level (not nested).
- Pass null for unused optional parameters.
- For commits without a message, analyze staged changes and generate Conventional Commit format.

## AVAILABLE OPERATIONS
| Operation | Description | Parameters |
|-----------|-------------|------------|
| `stage` | Stage files for commit | files (required) |
| `unstage` | Unstage files | files (required) |
| `commit` | Commit staged changes | commit_message?, amend? |
| `create_branch` | Create new branch | branch_name (required), checkout? |
| `checkout` | Switch branch/commit | target (required) |
| `stash` | Stash changes | message?, include_untracked? |
| `apply_stash` | Apply stash | stash_ref? |
| `reset` | Reset to commit | commit_hash (required), mode? |
| `gitignore_add` | Add .gitignore rules | gitignore_rules (required) |
| `gitignore_remove` | Remove .gitignore rules | gitignore_rule (required) |
| `push` | Push to remote | remote?, branch?, set_upstream?, force?, tags?, single_tag_name? |
| `fetch` | Fetch from remote | remote?, branch?, prune? |
| `pull` | Pull from remote | remote?, branch?, rebase_flag? |
| `rebase` | Rebase current branch | base (required), onto?, interactive? |
| `rebase_abort` | Abort rebase | (none) |
| `rebase_continue` | Continue rebase | (none) |
| `add_remote` | Add new remote | remote_name (required), remote_url (required) |
| `remove_remote` | Remove remote | remote_name (required) |
| `rename_remote` | Rename remote | remote_name (required), new_remote_name (required) |
| `set_remote_url` | Change remote URL | remote_name (required), remote_url (required) |
| `cherry_pick` | Apply commit | cherry_pick_commit_hash (required) |
| `cherry_pick_abort` | Abort cherry-pick | (none) |
| `cherry_pick_continue` | Continue cherry-pick | (none) |
| `cherry_pick_skip` | Skip current commit | (none) |
| `revert` | Revert commit | revert_commit_hash (required) |
| `create_tag` | Create tag | tag_name (required), tag_message?, tag_commit_hash? |
| `delete_tag` | Delete tag | tag_name (required), remote? |
| `merge` | Merge branch | branch (required) |
| `merge_abort` | Abort merge | (none) |
| `merge_continue` | Continue merge | (none) |
| `help` | Show help | (none) |

## EXAMPLE CALLS
- Stage: `{ "operation": "stage", "files": ["file1.txt"], ... (other params as null) }`
- Commit: `{ "operation": "commit", "commit_message": "feat: add feature", ... }`
- Push: `{ "operation": "push", "remote": "origin", "branch": "main", ... }`

## SAFETY RESTRICTIONS
- Never use force push without explicit user confirmation.
- Always verify staged changes before committing.
- Warn users before destructive operations (reset --hard, delete).

## RESPONSE
- Only invoke this tool when modifying Git repository state.
- For commit messages, use Conventional Commit format: type(scope): description.]]

GitEdit.cmds = {
  function(self, args, input, output_handler)
    if args == nil or type(args) ~= "table" then
      return validation.format_error(TOOL_NAME, "Invalid arguments: expected object")
    end

    args = normalize_args(args) -- JSON null → vim.NIL (truthy) → nil

    local operation = args.operation
    local err = validation.require_enum(operation, "operation", VALID_OPERATIONS, TOOL_NAME)
    if err then
      return err
    end

    if operation == "help" then
      local help_text = [[
Available write-access Git operations:
• stage/unstage: Stage/unstage files (requires files parameter)
• commit: Commit staged changes (auto-generates AI message if no message provided)
• create_branch: Create new branch
• checkout: Switch branch/commit
• stash/apply_stash: Stash operations
• reset: Reset to specific commit
• gitignore_add/gitignore_remove: Manage .gitignore rules
• push: Push changes to remote (WARNING: force push is dangerous)
• fetch: Fetch from remote
• pull: Pull from remote
• rebase/rebase_abort/rebase_continue: Rebase operations
• add_remote/remove_remote/rename_remote/set_remote_url: Remote management
• cherry_pick/cherry_pick_abort/cherry_pick_continue/cherry_pick_skip: Cherry-pick operations
• revert: Revert a commit
• create_tag/delete_tag: Tag management
• merge/merge_abort/merge_continue: Merge operations
      ]]
      return { status = "success", data = help_text }
    end

    if operation == "push" then
      local param_err = validation.first_error({
        validation.optional_string(args.remote, "remote", TOOL_NAME),
        validation.optional_string(args.branch, "branch", TOOL_NAME),
        validation.optional_boolean(args.force, "force", TOOL_NAME),
        validation.optional_boolean(args.set_upstream, "set_upstream", TOOL_NAME),
        validation.optional_boolean(args.tags, "tags", TOOL_NAME),
        validation.optional_string(args.single_tag_name, "single_tag_name", TOOL_NAME),
      })
      if param_err then
        return param_err
      end
      local set_upstream = args.set_upstream
      if set_upstream == nil then
        set_upstream = true
      end
      return GitTool.push_async(
        args.remote,
        args.branch,
        args.force,
        set_upstream,
        args.tags,
        args.single_tag_name,
        output_handler
      )
    end

    local ok, result = pcall(function()
      local success, output
      local param_err

      if operation == "stage" then
        param_err = validation.require_array(args.files, "files", TOOL_NAME)
        if param_err then
          return param_err
        end
        success, output = GitTool.stage_files(args.files)
      elseif operation == "unstage" then
        param_err = validation.require_array(args.files, "files", TOOL_NAME)
        if param_err then
          return param_err
        end
        success, output = GitTool.unstage_files(args.files)
      elseif operation == "commit" then
        param_err = validation.first_error({
          validation.optional_string(args.commit_message, "commit_message", TOOL_NAME),
          validation.optional_string(args.message, "message", TOOL_NAME),
          validation.optional_boolean(args.amend, "amend", TOOL_NAME),
        })
        if param_err then
          return param_err
        end
        local commit_msg = args.commit_message or args.message
        if not commit_msg then
          local diff_success, diff_output = GitTool.get_diff(true)
          if not diff_success or not diff_output or vim.trim(diff_output) == "" then
            return {
              status = "error",
              data = "No staged changes found for commit. Please stage your changes first using the stage operation.",
            }
          end
          return {
            status = "success",
            data = "No commit message provided. Please use git_read with operation 'diff' and staged=true to see changes, then create an appropriate commit message.",
          }
        end
        success, output = GitTool.commit(commit_msg, args.amend)
      elseif operation == "create_branch" then
        param_err = validation.first_error({
          validation.require_string(args.branch_name, "branch_name", TOOL_NAME),
          validation.optional_boolean(args.checkout, "checkout", TOOL_NAME),
        })
        if param_err then
          return param_err
        end
        success, output = GitTool.create_branch(args.branch_name, args.checkout)
      elseif operation == "checkout" then
        param_err = validation.require_string(args.target, "target", TOOL_NAME)
        if param_err then
          return param_err
        end
        success, output = GitTool.checkout(args.target)
      elseif operation == "stash" then
        param_err = validation.first_error({
          validation.optional_string(args.message, "message", TOOL_NAME),
          validation.optional_boolean(args.include_untracked, "include_untracked", TOOL_NAME),
        })
        if param_err then
          return param_err
        end
        success, output = GitTool.stash(args.message, args.include_untracked)
      elseif operation == "apply_stash" then
        param_err = validation.optional_string(args.stash_ref, "stash_ref", TOOL_NAME)
        if param_err then
          return param_err
        end
        success, output = GitTool.apply_stash(args.stash_ref)
      elseif operation == "reset" then
        param_err = validation.first_error({
          validation.require_string(args.commit_hash, "commit_hash", TOOL_NAME),
          args.mode and validation.require_enum(args.mode, "mode", VALID_RESET_MODES, TOOL_NAME) or nil,
        })
        if param_err then
          return param_err
        end
        success, output = GitTool.reset(args.commit_hash, args.mode)
      elseif operation == "gitignore_add" then
        local rules = args.gitignore_rules or args.gitignore_rule
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
        local rules = args.gitignore_rules or args.gitignore_rule
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
        param_err = validation.require_string(args.cherry_pick_commit_hash, "cherry_pick_commit_hash", TOOL_NAME)
        if param_err then
          return param_err
        end
        success, output = GitTool.cherry_pick(args.cherry_pick_commit_hash)
      elseif operation == "cherry_pick_abort" then
        success, output = GitTool.cherry_pick_abort()
      elseif operation == "cherry_pick_continue" then
        success, output = GitTool.cherry_pick_continue()
      elseif operation == "cherry_pick_skip" then
        success, output = GitTool.cherry_pick_skip()
      elseif operation == "revert" then
        param_err = validation.require_string(args.revert_commit_hash, "revert_commit_hash", TOOL_NAME)
        if param_err then
          return param_err
        end
        success, output = GitTool.revert(args.revert_commit_hash)
      elseif operation == "create_tag" then
        param_err = validation.first_error({
          validation.require_string(args.tag_name, "tag_name", TOOL_NAME),
          validation.optional_string(args.tag_message, "tag_message", TOOL_NAME),
          validation.optional_string(args.tag_commit_hash, "tag_commit_hash", TOOL_NAME),
        })
        if param_err then
          return param_err
        end
        success, output = GitTool.create_tag(args.tag_name, args.tag_message, args.tag_commit_hash)
      elseif operation == "delete_tag" then
        param_err = validation.first_error({
          validation.require_string(args.tag_name, "tag_name", TOOL_NAME),
          validation.optional_string(args.remote, "remote", TOOL_NAME),
        })
        if param_err then
          return param_err
        end
        success, output = GitTool.delete_tag(args.tag_name, args.remote)
      elseif operation == "merge" then
        param_err = validation.require_string(args.branch, "branch", TOOL_NAME)
        if param_err then
          return param_err
        end
        success, output = GitTool.merge(args.branch)
      elseif operation == "merge_abort" then
        success, output = GitTool.merge_abort()
      elseif operation == "merge_continue" then
        success, output = GitTool.merge_continue()
      elseif operation == "fetch" then
        param_err = validation.first_error({
          validation.optional_string(args.remote, "remote", TOOL_NAME),
          validation.optional_string(args.branch, "branch", TOOL_NAME),
          validation.optional_boolean(args.prune, "prune", TOOL_NAME),
        })
        if param_err then
          return param_err
        end
        success, output = GitTool.fetch(args.remote, args.branch, args.prune)
      elseif operation == "pull" then
        param_err = validation.first_error({
          validation.optional_string(args.remote, "remote", TOOL_NAME),
          validation.optional_string(args.branch, "branch", TOOL_NAME),
          validation.optional_boolean(args.rebase_flag, "rebase_flag", TOOL_NAME),
        })
        if param_err then
          return param_err
        end
        success, output = GitTool.pull(args.remote, args.branch, args.rebase_flag)
      elseif operation == "rebase" then
        param_err = validation.first_error({
          validation.require_string(args.base, "base", TOOL_NAME),
          validation.optional_string(args.onto, "onto", TOOL_NAME),
          validation.optional_boolean(args.interactive, "interactive", TOOL_NAME),
        })
        if param_err then
          return param_err
        end
        success, output = GitTool.rebase(args.onto, args.base, args.interactive)
      elseif operation == "rebase_abort" then
        success, output = GitTool.rebase_abort()
      elseif operation == "rebase_continue" then
        success, output = GitTool.rebase_continue()
      elseif operation == "add_remote" then
        param_err = validation.first_error({
          validation.require_string(args.remote_name, "remote_name", TOOL_NAME),
          validation.require_string(args.remote_url, "remote_url", TOOL_NAME),
        })
        if param_err then
          return param_err
        end
        success, output = GitTool.add_remote(args.remote_name, args.remote_url)
      elseif operation == "remove_remote" then
        param_err = validation.require_string(args.remote_name, "remote_name", TOOL_NAME)
        if param_err then
          return param_err
        end
        success, output = GitTool.remove_remote(args.remote_name)
      elseif operation == "rename_remote" then
        param_err = validation.first_error({
          validation.require_string(args.remote_name, "remote_name", TOOL_NAME),
          validation.require_string(args.new_remote_name, "new_remote_name", TOOL_NAME),
        })
        if param_err then
          return param_err
        end
        success, output = GitTool.rename_remote(args.remote_name, args.new_remote_name)
      elseif operation == "set_remote_url" then
        param_err = validation.first_error({
          validation.require_string(args.remote_name, "remote_name", TOOL_NAME),
          validation.require_string(args.remote_url, "remote_url", TOOL_NAME),
        })
        if param_err then
          return param_err
        end
        success, output = GitTool.set_remote_url(args.remote_name, args.remote_url)
      else
        return validation.format_error(TOOL_NAME, "Unknown Git edit operation: " .. tostring(operation))
      end

      return { success = success, output = output }
    end)

    if not ok then
      local error_msg = "Git edit operation failed unexpectedly: " .. tostring(result)
      return { status = "error", data = error_msg }
    end

    if result.status then
      return result
    end

    local success, output = result.success, result.output

    if success then
      return { status = "success", data = output }
    else
      return { status = "error", data = output or "Git operation failed without specific error message" }
    end
  end,
}

GitEdit.handlers = {
  on_exit = function(self, tools) end,
}

GitEdit.output = {
  prompt = function(self, tools)
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

  success = function(self, tools, cmd, stdout)
    local chat = tools.chat
    local operation = self.args and self.args.operation or "unknown"
    local output = normalize_output(stdout)
    local user_msg = string.format("Git %s completed", operation)
    chat:add_tool_output(self, output, user_msg)
  end,

  error = function(self, tools, cmd, stderr, stdout)
    local chat = tools.chat
    local operation = self.args and self.args.operation or "unknown"
    local errors = normalize_output(stderr, "Unknown error")
    local user_msg = string.format("Git %s failed", operation)
    chat:add_tool_output(self, errors, user_msg)
  end,

  rejected = function(self, tools, cmd, opts)
    local operation = self.args and self.args.operation or "unknown"
    local message = string.format("User rejected the git %s operation", operation)
    opts = vim.tbl_extend("force", { message = message }, opts or {})
    local ok, helpers = pcall(require, "codecompanion.interactions.chat.tools.builtin.helpers")
    if ok and helpers and helpers.rejected then
      helpers.rejected(self, tools, cmd, opts)
    else
      tools.chat:add_tool_output(self, message)
    end
  end,
}

GitEdit.opts = {
  require_approval_before = function(self, tools)
    return true
  end,
  requires_approval = function(self, tools)
    return true
  end,
}

return GitEdit
