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
            "commit",
            "create_branch",
            "checkout",
            "stash",
            "apply_stash",
            "reset",
            "gitignore_add",
            "gitignore_remove",
            "push",
            "rebase",
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
            tags = {
              type = "boolean",
              description = "Push all tags",
            },
            single_tag_name = {
              type = "string",
              description = "The name of a single tag to push",
            },
            onto = {
              type = "string",
              description = "The branch to rebase onto",
            },
            base = {
              type = "string",
              description = "The upstream branch to rebase from",
            },
            interactive = {
              type = "boolean",
              description = "Perform an interactive rebase (DANGEROUS: opens an editor, not suitable for automated environments)",
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

GitEdit.system_prompt = [[Execute write-access Git repository operations

When to use:
• When staging or unstaging file changes
• When creating or switching between branches
• When managing stashes and repository state
• When performing safe repository modifications

Best practices:
• Must verify Git repository before operations
• Always specify files parameter for stage/unstage operations
• Use '.' to stage all modified files or specific file paths
• For commit operations, if no commit_message provided, automatically generate AI message
• Auto-generation analyzes staged changes and creates Conventional Commit compliant messages
• Use format: type(scope): description with lowercase type and imperative verb description
• Include body with bullet points for complex changes, keep description under 50 characters
• Avoid force push operations that rewrite history
• Ensure file paths and branch names are valid

Available operations: stage, unstage, commit, create_branch, checkout, stash, apply_stash, reset, gitignore_add, gitignore_remove, push, rebase, cherry_pick, revert, create_tag, delete_tag, merge, help]]

GitEdit.cmds = {
  function(self, args, input)
    local operation = args.operation
    local op_args = args.args or {}

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
• rebase: Rebase current branch (WARNING: interactive rebase is dangerous)
• cherry_pick: Apply changes from existing commits
• revert: Revert a commit
• create_tag: Create a new tag
• delete_tag: Delete a tag
• merge: Merge a branch into the current branch (requires branch parameter)
      ]]
      return { status = "success", data = help_text }
    end

    local success, output

    if operation == "stage" then
      if not op_args.files or #op_args.files == 0 then
        return { status = "error", data = "No files specified for staging" }
      end
      success, output = GitTool.stage_files(op_args.files)
    elseif operation == "unstage" then
      if not op_args.files or #op_args.files == 0 then
        return { status = "error", data = "No files specified for unstaging" }
      end
      success, output = GitTool.unstage_files(op_args.files)
    elseif operation == "commit" then
      local message = op_args.commit_message or op_args.message
      if not message then
        -- Check if there are staged changes
        local diff_success, diff_output = GitTool.get_diff(true) -- staged changes
        if not diff_success or not diff_output or vim.trim(diff_output) == "" then
          return { status = "error", data = "No staged changes found for commit. Please stage your changes first using the stage operation." }
        end
        
        -- Return success with instruction for AI to use the diff tool
        return {
          status = "success",
          data = "No commit message provided. I need to generate a Conventional Commit compliant message. Please use the `@git_read diff --staged` tool to see the changes and then create an appropriate commit message.",
        }
      end
      success, output = GitTool.commit(message, op_args.amend)
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
    elseif operation == "stash" then
      success, output = GitTool.stash(op_args.message, op_args.include_untracked)
    elseif operation == "apply_stash" then
      success, output = GitTool.apply_stash(op_args.stash_ref)
    elseif operation == "reset" then
      if not op_args.commit_hash then
        return { status = "error", data = "Commit hash is required for reset" }
      end
      success, output = GitTool.reset(op_args.commit_hash, op_args.mode)
    elseif operation == "gitignore_add" then
      local rules = op_args.gitignore_rules or op_args.gitignore_rule
      if not rules then
        return { status = "error", data = "No rule(s) specified for .gitignore add" }
      end
      success, output = GitTool.add_gitignore_rule(rules)
    elseif operation == "gitignore_remove" then
      local rules = op_args.gitignore_rules or op_args.gitignore_rule
      if not rules then
        return { status = "error", data = "No rule(s) specified for .gitignore remove" }
      end
      success, output = GitTool.remove_gitignore_rule(rules)
    elseif operation == "push" then
      success, output = GitTool.push(op_args.remote, op_args.branch, op_args.force, op_args.tags, op_args.tag_name)
    elseif operation == "rebase" then
      success, output = GitTool.rebase(op_args.onto, op_args.base, op_args.interactive)
    elseif operation == "cherry_pick" then
      if not op_args.cherry_pick_commit_hash then
        return { status = "error", data = "Commit hash is required for cherry-pick" }
      end
      success, output = GitTool.cherry_pick(op_args.cherry_pick_commit_hash)
    elseif operation == "revert" then
      if not op_args.revert_commit_hash then
        return { status = "error", data = "Commit hash is required for revert" }
      end
      success, output = GitTool.revert(op_args.revert_commit_hash)
    elseif operation == "create_tag" then
      if not op_args.tag_name then
        return { status = "error", data = "Tag name is required" }
      end
      success, output = GitTool.create_tag(op_args.tag_name, op_args.tag_message, op_args.tag_commit_hash)
    elseif operation == "delete_tag" then
      if not op_args.tag_name then
        return { status = "error", data = "Tag name is required for deletion" }
      end
      success, output = GitTool.delete_tag(op_args.tag_name, op_args.remote)
    elseif operation == "merge" then
      if not op_args.branch then
        return { status = "error", data = "Branch to merge is required" }
      end
      success, output = GitTool.merge(op_args.branch)
    else
      return { status = "error", data = "Unknown Git edit operation: " .. operation }
    end

    if success then
      return { status = "success", data = output }
    else
      return { status = "error", data = output }
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
  success = function(self, agent, cmd, stdout)
    local operation = self.args.operation
    -- For push operations, remain completely silent on success.
    if operation == "push" then
      return
    end

    local chat = agent.chat
    local user_msg = string.format("Git edit operation [%s] executed successfully", operation)
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
