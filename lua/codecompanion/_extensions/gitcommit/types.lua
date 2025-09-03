---@field enabled boolean Enable buffer-specific keymap for git commit
---@field keymap string Keymap for generating commit message in git commit buffer
---@field auto_generate? boolean Automatically generate commit message on entering gitcommit buffer

---@field skip_auto_generate_on_amend? boolean Skip auto-generation during git commit --amend operations

---@field buffer? CodeCompanion.GitCommit.ExtensionOpts.Buffer Enable buffer-specific keymap for git commit
---@field adapter? string? The adapter to use for generation
---@field model? string? The model of the adapter to use for generation
---@field languages? string[] List of languages to use for generation
---@field exclude_files? string[] List of file patterns to exclude from diff (supports glob patterns like "*.pb.go")
---@field add_git_tool? boolean Add git_bot tool to CodeCompanion chat (default: true)
---@field add_git_commands? boolean Add CodeCompanionGit commands (default: true)
---@field git_tool_auto_submit_errors? boolean Auto-submit git tool errors to LLM (default: false)
---@field git_tool_auto_submit_success? boolean Auto-submit git tool success to LLM (default: false)

---@class CodeCompanion.GitCommit.Exports
---@field generate fun(callback: fun(result: string|nil, error: string|nil)): nil
---@field is_git_repo fun(): boolean
---@field get_staged_diff fun(): string|nil
---@field commit_changes fun(message: string): boolean
---@field git_tool CodeCompanion.GitCommit.GitTool.Exports

---@class CodeCompanion.GitCommit.GitTool.Exports
---@field status fun(): boolean, string -- Get git status
---@field log fun(count?: number, format?: string): boolean, string -- Get git log
---@field diff fun(staged?: boolean, file?: string): boolean, string -- Get git diff
---@field current_branch fun(): boolean, string -- Get current branch name
---@field branches fun(remote_only?: boolean): boolean, string -- Get all branches
---@field stage fun(files: string|table): boolean, string -- Stage files
---@field unstage fun(files: string|table): boolean, string -- Unstage files
---@field create_branch fun(branch_name: string, checkout?: boolean): boolean, string -- Create new branch
---@field checkout fun(target: string): boolean, string -- Checkout branch or commit
---@field remotes fun(): boolean, string -- Get remotes
---@field show fun(commit_hash?: string): boolean, string -- Show commit details
---@field blame fun(file_path: string, line_start?: number, line_end?: number): boolean, string -- Get blame for file
---@field stash fun(message?: string, include_untracked?: boolean): boolean, string -- Stash changes
---@field stash_list fun(): boolean, string -- List stashes
---@field apply_stash fun(stash_ref?: string): boolean, string -- Apply stash
---@field reset fun(commit_hash: string, mode?: string): boolean, string -- Reset to commit
---@field diff_commits fun(commit1: string, commit2?: string, file_path?: string): boolean, string -- Compare commits
---@field contributors fun(count?: number): boolean, string -- Get top contributors
---@field search_commits fun(pattern: string, count?: number): boolean, string -- Search commits by message
---@field merge fun(branch: string): boolean, string -- Merge a branch
---@field push fun(remote?: string, branch?: string, force?: boolean, set_upstream?: boolean, tags?: boolean, tag_name?: string): boolean, string -- Push changes to remote
---@field generate_release_notes fun(from_tag?: string, to_tag?: string, format?: string): boolean, string -- Generate release notes

---@class CodeCompanion.GitCommit.Git
---@field is_repository fun(): boolean -- Check if current directory is inside a git repository
---@field get_staged_diff fun(): string|nil -- Get git diff for staged changes
---@field commit_changes fun(message: string): boolean -- Commit changes with the provided message
---@field get_commit_history fun(count?: number): string[]|nil -- Get recent commit messages for context
---@field get_config fun(): table -- Get current configuration

---@class CodeCompanion.GitCommit.Generator
---@field generate_commit_message fun(diff: string, lang: string?, commit_history: string[]?, callback: fun(result: string|nil, error: string|nil)): nil -- Generate commit message using LLM

---@class CodeCompanion.GitCommit.UI
---@field show_commit_message fun(message: string, on_commit: fun(message: string): boolean): nil -- Show commit message in a floating window with interactive options

---@class CodeCompanion.GitCommit
---@field generate_commit_message fun(): nil -- Generate and display commit message using AI
