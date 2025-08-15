# CodeCompanion GitCommit 扩展

一个为 CodeCompanion 开发的 Neovim 插件扩展，用于生成遵循约定式提交规范的 AI 驱动 Git 提交信息，并提供全面的 Git 工作流集成。

> [!IMPORTANT]
> 从 CodeCompanion v17.5.0 开始，变量和工具必须用花括号包裹，例如 `@{git_read}` 或 `#{buffer}`

## ✨ 功能特性

- 🤖 **AI 提交信息生成** - 使用 CodeCompanion 的 LLM 适配器生成符合约定式提交规范的提交信息
- 🛠️ **Git 工具集成** - 在聊天中通过 `@{git_read}`（16 个读取操作）和 `@{git_edit}`（17 个写入操作）工具执行 Git 操作
- 🤖 **Git 助手** - 通过 `@{git_bot}` 提供智能 Git 工作流辅助，结合读写操作
- 🌍 **多语言支持** - 支持生成多种语言的提交信息
- 📝 **智能缓冲区集成** - 在 gitcommit 缓冲区中自动生成提交信息，支持可配置的快捷键
- 📋 **文件过滤** - 支持使用 glob 模式从差异分析中排除文件
- 📚 **提交历史上下文** - 使用最近的提交历史来保持一致的风格和模式
- 🔌 **编程 API** - 为外部集成和自定义工作流提供完整的 API
- ⚡ **异步操作** - 非阻塞的 Git 操作，具有适当的错误处理

## 📦 安装

将此扩展添加到你的 CodeCompanion 配置中：

```lua
require("codecompanion").setup({
  extensions = {
    gitcommit = {
      callback = "codecompanion._extensions.gitcommit",
      opts = {
        -- 基本配置
        adapter = "openai",                       -- LLM 适配器
        model = "gpt-4",                         -- 模型名称
        languages = { "English", "Chinese", "Japanese", "French" }, -- 支持的语言
        
        -- 文件过滤（可选）
        exclude_files = { 
          "*.pb.go", "*.min.js", "*.min.css", "package-lock.json",
          "yarn.lock", "*.log", "dist/*", "build/*", ".next/*",
          "node_modules/*", "vendor/*"
        },
        
        -- 缓冲区集成
        buffer = {
          enabled = true,                  -- 启用 gitcommit 缓冲区快捷键
          keymap = "<leader>gc",           -- 生成提交信息的快捷键
          auto_generate = true,            -- 进入缓冲区时自动生成
          auto_generate_delay = 200,       -- 自动生成延迟（毫秒）
          skip_auto_generate_on_amend = true, -- 在 git commit --amend 时跳过自动生成
        },
        
        -- 功能开关
        add_slash_command = true,          -- 添加 /gitcommit 斜杠命令
        add_git_tool = true,              -- 添加 @{git_read} 和 @{git_edit} 工具
        enable_git_read = true,           -- 启用只读 Git 操作
        enable_git_edit = true,           -- 启用写入 Git 操作  
        enable_git_bot = true,            -- 启用 @{git_bot} 工具组（需要同时启用读写）
        add_git_commands = true,          -- 添加 :CodeCompanionGitCommit 命令
        git_tool_auto_submit_errors = false,    -- 自动提交错误给 LLM
        git_tool_auto_submit_success = true,    -- 自动提交成功信息给 LLM
        gitcommit_select_count = 100,     -- /gitcommit 中显示的提交数量
        
        -- 提交历史上下文（可选）
        use_commit_history = true,         -- 启用提交历史上下文
        commit_history_count = 10,         -- 用于上下文的最近提交数量
      }
    }
  }
})
```

## 🚀 使用方法

### 命令

| 命令 | 描述 |
|---------|-------------|
| `:CodeCompanionGitCommit` | 生成 Git 提交信息 |
| `:CCGitCommit` | 生成 Git 提交信息（简短别名） |

### Git 工具操作

在 CodeCompanion 聊天中使用 Git 工具：

#### 📖 只读操作（`@{git_read}`）

```
@{git_read} status                              # 显示仓库状态
@{git_read} log --count 5                       # 显示最近 5 个提交
@{git_read} diff --staged                       # 显示暂存的更改
@{git_read} branch                              # 列出所有分支
@{git_read} contributors --count 10             # 显示前 10 个贡献者
@{git_read} tags                                # 列出所有标签
@{git_read} generate_release_notes              # 生成最新标签之间的发布说明
@{git_read} generate_release_notes --from_tag "v1.0.0" --to_tag "v1.1.0"  # 生成特定标签之间的发布说明
@{git_read} gitignore_get                       # 获取 .gitignore 内容
@{git_read} gitignore_check --gitignore_file "file.txt"  # 检查文件是否被忽略
@{git_read} show --commit_hash "abc123"         # 显示提交详情
@{git_read} blame --file_path "src/main.lua"   # 显示文件追溯信息
@{git_read} search_commits --pattern "fix:"    # 搜索包含 "fix:" 的提交
@{git_read} stash_list                          # 列出所有暂存
@{git_read} diff_commits --commit1 "abc123" --commit2 "def456"  # 比较两个提交
@{git_read} remotes                             # 显示远程仓库
@{git_read} help                                # 显示帮助信息
```

#### ✏️ 写入操作（`@{git_edit}`）

```
@{git_edit} stage --files ["src/main.lua", "README.md"]
@{git_edit} unstage --files ["src/main.lua"]
@{git_edit} commit --commit_message "feat(api): 添加新功能"
@{git_edit} commit                              # 自动生成 AI 提交信息
@{git_edit} create_branch --branch_name "feature/new-ui" --checkout true
@{git_edit} checkout --target "main"
@{git_edit} stash --message "进行中的工作" --include_untracked true
@{git_edit} apply_stash --stash_ref "stash@{0}"
@{git_edit} reset --commit_hash "abc123" --mode "soft"
@{git_edit} gitignore_add --gitignore_rules ["*.log", "temp/*"]
@{git_edit} gitignore_remove --gitignore_rule "*.tmp"
@{git_edit} push --remote "origin" --branch "main" --set_upstream true
@{git_edit} cherry_pick --cherry_pick_commit_hash "abc123"
@{git_edit} revert --revert_commit_hash "abc123"
@{git_edit} create_tag --tag_name "v1.0.0" --tag_message "发布 v1.0.0"
@{git_edit} delete_tag --tag_name "v0.9.0"
@{git_edit} merge --branch "feature/new-ui"
```

#### 🤖 Git 助手（`@{git_bot}`）

使用综合性的 Git 助手，结合读写操作：

```
@{git_bot} 请帮我创建新分支并推送当前更改
@{git_bot} 分析最近的提交历史并总结主要变化
@{git_bot} 帮我整理当前工作区状态
```

### 基本用法

**1. 生成提交信息：**
```
:CodeCompanionGitCommit
```

**2. GitCommit 缓冲区集成：**
- 运行 `git commit` 打开提交缓冲区
- 按 `<leader>gc` 生成提交信息（如果启用了自动生成则会自动生成）
- 编辑并保存以完成提交

**3. 基于聊天的 Git 工作流：**
```
@{git_read} status                              # 检查仓库状态
@{git_edit} stage --files ["file1.txt", "file2.txt"]  # 暂存文件
/gitcommit                                    # 选择提交并插入其内容作为参考
@{git_edit} commit --commit_message "feat(api): 添加新功能"  # 提交
@{git_edit} push --remote "origin" --branch "main"     # 推送更改
@{git_read} generate_release_notes              # 生成最新标签之间的发布说明
```

**4. 生成发布说明：**
```
@{git_read} generate_release_notes                    # 自动检测最新和前一个标签
@{git_read} generate_release_notes --from_tag "v1.0.0" --to_tag "v1.1.0"  # 指定标签
@{git_read} generate_release_notes --release_format "json"              # JSON 格式输出
```

## ⚙️ 配置选项

<details>
<summary>完整配置选项</summary>

```lua
opts = {
  adapter = "openai",                         -- LLM 适配器
  model = "gpt-4",                           -- 模型名称
  languages = { "English", "Chinese", "Japanese", "French" }, -- 支持的语言列表
  exclude_files = {                          -- 排除的文件模式
    "*.pb.go", "*.min.js", "*.min.css",
    "package-lock.json", "yarn.lock", "*.log",
    "dist/*", "build/*", ".next/*",
    "node_modules/*", "vendor/*"
  },
  add_slash_command = true,                  -- 添加 /gitcommit 命令
  add_git_tool = true,                      -- 添加 Git 工具
  enable_git_read = true,                   -- 启用只读 Git 操作
  enable_git_edit = true,                   -- 启用写入 Git 操作
  enable_git_bot = true,                    -- 启用 @{git_bot} 工具组（需要同时启用读写）
  add_git_commands = true,                  -- 添加 Git 命令
  gitcommit_select_count = 100,             -- /gitcommit 中显示的提交数
  git_tool_auto_submit_errors = false,      -- 自动提交错误给 LLM
  git_tool_auto_submit_success = true,      -- 自动提交成功信息给 LLM
  use_commit_history = true,                -- 启用提交历史上下文
  commit_history_count = 10,                -- 用于上下文的最近提交数量
  buffer = {
    enabled = true,                         -- 启用缓冲区集成
    keymap = "<leader>gc",                 -- 快捷键
    auto_generate = true,                  -- 自动生成
    auto_generate_delay = 200,             -- 生成延迟（毫秒）
    skip_auto_generate_on_amend = true,    -- 修订时跳过自动生成
  }
}
```

</details>

## 🔌 编程 API

该扩展为外部集成提供了全面的 API：

```lua
local gitcommit = require("codecompanion._extensions.gitcommit")

-- 以编程方式生成提交信息
gitcommit.exports.generate("Chinese", function(result, error)
  if result then
    print("生成的提交信息：", result)
  else
    print("错误：", error)
  end
end)

-- 检查是否在 git 仓库中
if gitcommit.exports.is_git_repo() then
  print("在 git 仓库中")
end

-- 获取 git 状态
local status = gitcommit.exports.git_tool.status()
print("Git 状态：", status)

-- 暂存文件
gitcommit.exports.git_tool.stage({"file1.txt", "file2.txt"})

-- 创建并切换分支
gitcommit.exports.git_tool.create_branch("feature/new-feature", true)

-- 生成特定标签之间的发布说明（包含所有参数）
local success, notes, user_msg, llm_msg = gitcommit.exports.git_tool.generate_release_notes("v1.0.0", "v1.1.0", "markdown")
if success then
  print("发布说明：", notes)
end

-- 生成发布说明（自动检测最新的两个标签）
local success, notes = gitcommit.exports.git_tool.generate_release_notes()
```

## 📚 文档

详细文档请查看：`:help codecompanion-gitcommit`

## 🔒 安全特性

- **只读操作**（`@{git_read}`）无需确认
- **修改操作**（`@{git_edit}`）需要用户确认
- **仓库验证**确保操作在有效的 Git 仓库中进行
- **全面的错误处理**提供有用的错误信息

## 📄 许可证

MIT 许可证