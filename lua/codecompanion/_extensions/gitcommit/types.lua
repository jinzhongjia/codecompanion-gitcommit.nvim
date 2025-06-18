---@meta

---@class CodeCompanion.GitCommit.Extension
---@field setup fun(opts: CodeCompanion.GitCommit.ExtensionOpts): nil
---@field exports CodeCompanion.GitCommit.Exports

---@class CodeCompanion.GitCommit.ExtensionOpts.Buffer
---@field enabled boolean Enable buffer-specific keymap for git commit
---@field keymap string Keymap for generating commit message in git commit buffer
---@field auto_generate? boolean Automatically generate commit message on entering gitcommit buffer
---@field auto_generate_delay? number Delay in ms before auto-generating to avoid race conditions

---@class CodeCompanion.GitCommit.ExtensionOpts
---@field add_slash_command? boolean Add /gitcommit slash command to chat buffer
---@field buffer? CodeCompanion.GitCommit.ExtensionOpts.Buffer Enable buffer-specific keymap for git commit
---@field adapter? string? The adapter to use for generation
---@field model? string? The model of the adapter to use for generation
---@field languages? string[] List of languages to use for generation
---@field exclude_files? string[] List of file patterns to exclude from diff (supports glob patterns like "*.pb.go")

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
---@field generate_commit_message fun(diff: string,lang: string?, callback: fun(result: string|nil, error: string|nil)): nil -- Generate commit message using LLM

---@class CodeCompanion.GitCommit.UI
---@field show_commit_message fun(message: string, on_commit: fun(message: string): boolean): nil -- Show commit message in a floating window with interactive options

---@class CodeCompanion.GitCommit
---@field generate_commit_message fun(): nil -- Generate and display commit message using AI
