local GitTool = require("codecompanion._extensions.gitcommit.tools.git").GitTool

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
            "create_branch",
            "checkout",
            "stash",
            "apply_stash",
            "reset",
            "gitignore_add",
            "gitignore_remove",            "push",            "rebase",            "help"          },          description = "The write-access Git operation to perform."        },        args = {          type = "object",          properties = {            files = {              type = "array",              items = { type = "string" },              description = "List of files to operate on"            },            branch_name = {              type = "string",              description = "Name of the branch"            },            checkout = {              type = "boolean",              description = "Whether to checkout new branch"            },            target = {              type = "string",              description = "Target branch or commit for checkout"            },            message = {              type = "string",              description = "Message for stash or commit"            },            include_untracked = {              type = "boolean",              description = "Include untracked files in stash"            },            stash_ref = {              type = "string",              description = "Stash reference (e.g., stash@{0})"            },            commit_hash = {              type = "string",              description = "Commit hash or reference for reset"            },            mode = {              type = "string",              enum = { "soft", "mixed", "hard" },              description = "Reset mode"            },            gitignore_rule = {              type = "string",              description = "Rule to add or remove from .gitignore"            },            gitignore_rules = {              type = "array",              items = { type = "string" },              description = "Multiple rules to add or remove from .gitignore"            },            remote = {              type = "string",              description = "The name of the remote to push to (e.g., origin)"            },            branch = {              type = "string",              description = "The name of the branch to push (defaults to current branch)"            },            force = {              type = "boolean",              description = "Force push (DANGEROUS: overwrites remote history)"            },            onto = {              type = "string",              description = "The branch to rebase onto"            },            base = {              type = "string",              description = "The upstream branch to rebase from"            },            interactive = {              type = "boolean",              description = "Perform an interactive rebase (DANGEROUS: opens an editor, not suitable for automated environments)"            }          },          additionalProperties = false        }      },      required = { "operation" },      additionalProperties = false    },    strict = true  }}GitEdit.system_prompt = [[## Git Edit Tool (`git_edit`)- You have access to a write-access Git tool.- You can perform operations like stage, unstage, create branches, and apply stashes.- Always check if you're in a Git repository before performing operations.- Use this tool to modify the repository state.## AVAILABLE OPERATIONS- `stage`: Stage files (args: files)- `unstage`: Unstage files (args: files)- `create_branch`: Create new branch (args: branch_name, checkout)- `checkout`: Switch branch/commit (args: target)- `stash`: Stash changes (args: message, include_untracked)- `apply_stash`: Apply stash (args: stash_ref)- `reset`: Reset to commit (args: commit_hash, mode)- `gitignore_add`: Add a rule to .gitignore- `gitignore_remove`: Remove a rule from .gitignore- `push`: Push changes to a remote repository (args: remote, branch, force)  WARNING: `force` push is dangerous and can overwrite remote history.- `rebase`: Rebase current branch onto another (args: onto, base, interactive)  WARNING: `interactive` rebase opens an editor and is not suitable for automated environments. It can also rewrite history.- `help`: Show available edit operations]]GitEdit.cmds = {  function(self, args, input)    local operation = args.operation    local op_args = args.args or {}    if operation == "help" then      local help_text = [[Available write-access Git operations:• stage/unstage: Stage/unstage files• create_branch: Create new branch• checkout: Switch branch/commit• stash/apply_stash: Stash operations• reset: Reset to specific commit• gitignore_add: Add rule to .gitignore• gitignore_remove: Remove rule from .gitignore• push: Push changes to a remote repository (WARNING: force push is dangerous)• rebase: Rebase current branch (WARNING: interactive rebase is dangerous)      ]]      return { status = "success", data = help_text }    end    local success, output    if operation == "stage" then      if not op_args.files or #op_args.files == 0 then        return { status = "error", data = "No files specified for staging" }      end      success, output = GitTool.stage_files(op_args.files)    elseif operation == "unstage" then      if not op_args.files or #op_args.files == 0 then        return { status = "error", data = "No files specified for unstaging" }      end      success, output = GitTool.unstage_files(op_args.files)    elseif operation == "create_branch" then      if not op_args.branch_name then        return { status = "error", data = "Branch name is required" }      end      success, output = GitTool.create_branch(op_args.branch_name, op_args.checkout)    elseif operation == "checkout" then      if not op_args.target then        return { status = "error", data = "Target branch or commit is required" }      end      success, output = GitTool.checkout(op_args.target)    elseif operation == "stash" then      success, output = GitTool.stash(op_args.message, op_args.include_untracked)    elseif operation == "apply_stash" then      success, output = GitTool.apply_stash(op_args.stash_ref)    elseif operation == "reset" then      if not op_args.commit_hash then        return { status = "error", data = "Commit hash is required for reset" }      end      success, output = GitTool.reset(op_args.commit_hash, op_args.mode)    elseif operation == "gitignore_add" then      local rules = op_args.gitignore_rules or op_args.gitignore_rule      if not rules then        return { status = "error", data = "No rule(s) specified for .gitignore add" }      end      success, output = GitTool.add_gitignore_rule(rules)    elseif operation == "gitignore_remove" then      local rules = op_args.gitignore_rules or op_args.gitignore_rule      if not rules then        return { status = "error", data = "No rule(s) specified for .gitignore remove" }      end      success, output = GitTool.remove_gitignore_rule(rules)    elseif operation == "push" then      success, output = GitTool.push(op_args.remote, op_args.branch, op_args.force)    elseif operation == "rebase" then      success, output = GitTool.rebase(op_args.onto, op_args.base, op_args.interactive)    else      return { status = "error", data = "Unknown Git edit operation: " .. operation }    end    if success then      return { status = "success", data = output }    else      return { status = "error", data = output }    end  end,}

GitEdit.handlers = {
  setup = function(self, agent)
    return true
  end,
  on_exit = function(self, agent) end,
}

GitEdit.output = {
  success = function(self, agent, cmd, stdout)
    local chat = agent.chat
    local operation = self.args.operation
    local user_msg = string.format("Git operation [%s] completed", operation)
    return chat:add_tool_output(self, stdout[1], user_msg)
  end,
  error = function(self, agent, cmd, stderr, stdout)
    local chat = agent.chat
    local error_msg = stderr[1] or "Git edit operation failed"
    local user_msg = "Git edit operation failed"
    return chat:add_tool_output(self, error_msg, user_msg)
  end,
}

GitEdit.opts = {
  requires_approval = function(self, agent)
    return true
  end,
}

return GitEdit
