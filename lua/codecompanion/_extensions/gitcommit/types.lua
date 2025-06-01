---@meta

---@class CodeCompanion.GitCommit.Extension
---@field setup fun(opts: CodeCompanion.GitCommit.ExtensionOpts): nil
---@field exports CodeCompanion.GitCommit.Exports

---@class CodeCompanion.GitCommit.ExtensionOpts
---@field add_slash_command? boolean Add /gitcommit slash command to chat buffer

---@class CodeCompanion.GitCommit.Exports
---@field generate fun(callback: fun(result: string|nil, error: string|nil)): nil
---@field is_git_repo fun(): boolean
---@field get_staged_diff fun(): string|nil
---@field commit_changes fun(message: string): boolean

---@class CodeCompanion.GitCommit.Git
---@field is_repository fun(): boolean -- Check if current directory is inside a git repository
---@field get_staged_diff fun(): string|nil -- Get git diff for staged changes
---@field commit_changes fun(message: string): boolean -- Commit changes with the provided message

---@class CodeCompanion.GitCommit.Generator
---@field generate_commit_message fun(diff: string, callback: fun(result: string|nil, error: string|nil)): nil -- Generate commit message using LLM

---@class CodeCompanion.GitCommit.UI
---@field show_commit_message fun(message: string, on_commit: fun(message: string): boolean): nil -- Show commit message in a floating window with interactive options

---@class CodeCompanion.GitCommit
---@field generate_commit_message fun(): nil -- Generate and display commit message using AI
