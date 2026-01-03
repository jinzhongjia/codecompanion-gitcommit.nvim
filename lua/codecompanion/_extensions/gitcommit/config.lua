local M = {}

---@class CodeCompanion.GitCommit.ExtensionOpts
M.default_opts = {
  adapter = nil, -- Inherit from global config
  model = nil, -- Inherit from global config
  languages = { "English", "Chinese", "Japanese", "French" },
  prompt_template = [[You are a commit message generator. Produce exactly ONE Conventional Commit message for the provided git diff.

FORMAT:
type(scope): concise, imperative description of WHAT changed

Optional body (only if needed for non-obvious changes)

Allowed types: feat, fix, docs, style, refactor, perf, test, chore
Language: %{language} (type/scope stay in English)

CRITICAL RULES:
1. Output ONLY the commit message; no markdown, no quotes, no extra text
2. Subject is imperative, present tense, no trailing period
3. Be specific about WHAT changed; avoid WHY or impact
4. Avoid vague verbs: "update", "improve", "clarify", "adjust", "enhance", "fix issues"
   Prefer concrete verbs: "add", "remove", "rename", "move", "replace", "extract", "inline"
5. Scope is optional; include only if clearly implied by the diff
6. Subject <= 50 chars; body lines <= 72 chars
7. Add body only when the subject alone is not enough
8. If the diff introduces a breaking change, mark with "!" and add "BREAKING CHANGE:" in body
9. Do not invent issue references, ticket IDs, or files not in the diff
10. If the diff includes multiple unrelated changes, pick the single most important one
11. When body is present, reference concrete entities from the diff (module, file, function, setting)

DIFF (source of truth):
```diff
%{diff}
```
END DIFF
%{history_context}]],
  exclude_files = {
    "*.pb.go",
    "*.min.js",
    "*.min.css",
    "package-lock.json",
    "yarn.lock",
    "*.log",
    "dist/*",
    "build/*",
    ".next/*",
    "node_modules/*",
    "vendor/*",
  },
  buffer = {
    enabled = true,
    keymap = "<leader>gc",
    auto_generate = true,
    auto_generate_delay = 200,
    skip_auto_generate_on_amend = true, -- Skip auto-generation during git commit --amend
  },
  add_slash_command = true,
  add_git_tool = true,
  enable_git_read = true,
  enable_git_edit = true,
  enable_git_bot = true, -- Only enabled if both enable_git_read and enable_git_edit are true
  add_git_commands = true,
  git_tool_auto_submit_errors = false,
  git_tool_auto_submit_success = true,
  gitcommit_select_count = 100,
  -- History commit context configuration
  use_commit_history = true, -- Enable using commit history as context
  commit_history_count = 10, -- Number of recent commits to include as context
}

return M
