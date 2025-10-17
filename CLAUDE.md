# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 项目概述

obsidian.nvim 是一个用 Lua 编写的 Neovim 插件，用于在 Neovim 中编写和导航 Obsidian vault。该项目包含约 16,000 行 Lua 代码，目前版本为 3.9.0。

## 开发工作流程

### 常用命令

```bash
# 完整开发流程
make all          # 运行 style + lint + test
make test         # 运行测试套件
make lint         # luacheck 代码检查
make style        # StyLua 代码格式化检查
make api-docs     # 生成 API 文档
make version      # 显示当前版本
```

### 测试
- 测试文件位于 `test/obsidian/` 目录
- 使用 Plenary.nvim 测试框架
- 通过 `test/minimal_init.vim` 提供隔离的测试环境
- 运行单个测试：`nvim --headless -u test/minimal_init.vim -c "PlenaryBustedFile test/obsidian/client_test.lua"`

### 代码质量工具
- **StyLua**: 代码格式化（2空格缩进，120字符行宽）
- **luacheck**: 代码静态分析
- **类型注解**: 使用 Lua 类型注解提高代码质量

## 项目架构

### 核心模块

1. **Client** (`lua/obsidian/client.lua`): 主客户端类，管理整个插件生命周期
2. **Note** (`lua/obsidian/note.lua`): 笔记数据结构，处理 frontmatter 和链接
3. **Workspace** (`lua/obsidian/workspace.lua`): 工作区管理，支持多工作区切换
4. **Config** (`lua/obsidian/config.lua`): 配置管理，支持工作区级配置覆盖

### 模块化设计

使用 `setmetatable` 实现懒加载模块系统，避免不必要的加载开销：

```lua
-- 入口文件 lua/obsidian.lua 中的模块加载器
local obsidian = setmetatable({}, {
  __index = function(t, k)
    local require_path = module_lookups[k]
    local mod = require(require_path)
    t[k] = mod  -- 缓存已加载模块
    return mod
  end,
})
```

### 异步架构

大量使用 `plenary.async` 实现异步操作，确保 UI 响应性：
- 文件 I/O 操作
- 搜索和索引
- 外部命令调用

### 命令系统

30+ 个命令位于 `lua/obsidian/commands/` 目录，按功能分类：
- **笔记操作**: new, open, search, quickswitch
- **链接管理**: link, follow_link, backlinks
- **日期笔记**: today, yesterday, tomorrow, dailies
- **模板系统**: template, new_from_template
- **界面功能**: toc, recent_files, paste_img

## 依赖管理

### 必需依赖
- **plenary.nvim**: 异步操作、测试框架、工具函数

### 可选依赖
- **nvim-cmp**: 代码补全
- **telescope.nvim**: 选择器界面
- **nvim-treesitter**: 语法高亮

### 系统依赖
- **ripgrep**: 搜索功能
- **xclip/wl-clipboard**: 剪贴板操作（Linux）

## 开发注意事项

### 代码风格
- 所有注释必须使用英文（来自 .cursor/rules/englishcomment.mdc）
- 修改代码时尽可能减少更改范围（来自 .cursor/rules/lessmodify.mdc）
- 不要修改文档文件除非明确要求（来自 .cursor/rules/notchangedoc.mdc）

### 重要文件路径
- **入口文件**: `lua/obsidian.lua`
- **主客户端**: `lua/obsidian/client.lua`
- **配置管理**: `lua/obsidian/config.lua`
- **工具函数**: `lua/obsidian/util.lua`
- **测试目录**: `test/obsidian/`
- **文档**: `doc/`

### 工作区概念
obsidian.nvim 引入了比 Obsidian vault 更灵活的工作区概念：
- 支持子目录工作区
- 动态工作区路径（函数定义）
- 工作区级配置覆盖

### 回调系统
提供完整的生命周期回调钩子：
- `post_setup`: 插件设置完成后
- `enter_note`: 进入笔记缓冲区时
- `leave_note`: 离开笔记缓冲区时
- `pre_write_note`: 写入笔记前
- `post_set_workspace`: 工作区设置/更改后

### 类型安全
虽然使用 Lua，但大量使用类型注解：
```lua
---@class obsidian.Client : obsidian.ABC
---@field current_workspace obsidian.Workspace
---@field dir obsidian.Path
```

# 测试流程
- 测试流程需要添加足够多的debug信息. 这样你自己可以找到问题
