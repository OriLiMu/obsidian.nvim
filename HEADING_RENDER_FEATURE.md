# 标题渲染功能

本文档描述了从 render-markdown.nvim 移植到 obsidian.nvim 的标题渲染功能。

## 功能特性

- **标题图标显示**：支持 H1-H6 不同级别的标题图标
- **背景高亮**：为标题行提供背景色高亮
- **边框装饰**：支持在标题上下添加装饰性边框
- **位置控制**：图标可以在左侧、内联或右侧显示
- **自定义样式**：支持基于标题内容的自定义样式
- **宽度控制**：支持块宽度或全宽度背景

## 配置选项

在你的 obsidian.nvim 配置中启用标题渲染功能：

```lua
require("obsidian").setup({
  ui = {
    heading = {
      enabled = true,                    -- 启用标题渲染
      icons = { "󰲡 ", "󰲣 ", "󰲥 ", "󰲧 ", "󰲩 ", "󰲫 " },  -- H1-H6 图标
      position = "overlay",              -- 图标位置："overlay" | "inline" | "right"
      foregrounds = true,                -- 启用前景色高亮
      backgrounds = true,                -- 启用背景色高亮
      width = "full",                    -- 背景宽度："full" | "block"
      border = false,                    -- 边框装饰
      above = "▄",                       -- 上边框字符
      below = "▀",                       -- 下边框字符
      custom = {},                       -- 自定义样式配置
    },
  },
})
```

### 配置选项详解

#### `enabled`
- **类型**: `boolean`
- **默认值**: `false`
- **描述**: 是否启用标题渲染功能

#### `icons`
- **类型**: `string[]` 或 `function`
- **默认值**: `{ "󰲡 ", "󰲣 ", "󰲥 ", "󰲧 ", "󰲩 ", "󰲫 " }`
- **描述**: H1-H6 标题的图标，可以是一个数组或函数

如果是函数，接收参数 `{ level = integer }`，返回图标字符串。

#### `position`
- **类型**: `string`
- **默认值**: `"overlay"`
- **可选值**: `"overlay"`, `"inline"`, `"right"`
- **描述**: 图标显示位置
  - `overlay`: 覆盖显示，在左侧添加图标
  - `inline`: 内联显示，替换 # 符号
  - `right`: 在行尾显示图标

#### `foregrounds`
- **类型**: `string[]` 或 `boolean`
- **默认值**: `true`
- **描述**: 前景色高亮配置，`true` 使用默认高亮组

#### `backgrounds`
- **类型**: `string[]` 或 `boolean`
- **默认值**: `true`
- **描述**: 背景色高亮配置，`true` 使用默认高亮组

#### `width`
- **类型**: `string`
- **默认值**: `"full"`
- **可选值**: `"full"`, `"block"`
- **描述**: 背景宽度
  - `full`: 整行背景
  - `block`: 仅标题文本宽度背景

#### `border`
- **类型**: `boolean`
- **默认值**: `false`
- **描述**: 是否在标题上下添加边框

#### `above` / `below`
- **类型**: `string`
- **默认值**: `"▄"` / `"▀"`
- **描述**: 上下边框的字符

#### `custom`
- **类型**: `table<string, CustomStyle>`
- **默认值**: `{}`
- **描述**: 自定义样式配置

```lua
custom = {
  ["重要"] = {
    pattern = "重要",
    icon = "❗",
    foreground = "ObsidianImportant",
    background = "ObsidianImportantBg"
  }
}
```

## 默认高亮组

插件定义了以下高亮组：

### 前景色高亮组
- `ObsidianHeading1` - H1 标题前景色
- `ObsidianHeading2` - H2 标题前景色
- `ObsidianHeading3` - H3 标题前景色
- `ObsidianHeading4` - H4 标题前景色
- `ObsidianHeading5` - H5 标题前景色
- `ObsidianHeading6` - H6 标题前景色

### 背景色高亮组
- `ObsidianHeading1Bg` - H1 标题背景色
- `ObsidianHeading2Bg` - H2 标题背景色
- `ObsidianHeading3Bg` - H3 标题背景色
- `ObsidianHeading4Bg` - H4 标题背景色
- `ObsidianHeading5Bg` - H5 标题背景色
- `ObsidianHeading6Bg` - H6 标题背景色

## 使用示例

### 基础配置
```lua
require("obsidian").setup({
  ui = {
    heading = {
      enabled = true,
      icons = { "🔹", "🔸", "🔹", "🔸", "🔹", "🔸" },
      position = "inline",
    },
  },
})
```

### 完整配置
```lua
require("obsidian").setup({
  ui = {
    heading = {
      enabled = true,
      icons = { "󰲡 ", "󰲣 ", "󰲥 ", "󰲧 ", "󰲩 ", "󰲫 " },
      position = "overlay",
      foregrounds = {
        "MyHeading1",
        "MyHeading2",
        "MyHeading3",
        "MyHeading4",
        "MyHeading5",
        "MyHeading6"
      },
      backgrounds = {
        "MyHeading1Bg",
        "MyHeading2Bg",
        "MyHeading3Bg",
        "MyHeading4Bg",
        "MyHeading5Bg",
        "MyHeading6Bg"
      },
      width = "block",
      border = true,
      above = "═",
      below = "═",
      custom = {
        ["TODO"] = {
          pattern = "TODO",
          icon = "📝",
          foreground = "TodoFg",
          background = "TodoBg"
        }
      }
    },
  },
})
```

### 函数式图标配置
```lua
require("obsidian").setup({
  ui = {
    heading = {
      enabled = true,
      icons = function(ctx)
        -- 根据嵌套深度返回不同的图标
        local depth = ctx.sections and ctx.sections[ctx.level] or 0
        return string.rep("  ", depth) .. "📍 "
      end,
    },
  },
})
```

## 技术实现

标题渲染功能通过以下方式实现：

1. **模块结构**:
   - `obsidian.ui.heading`: 标题渲染器
   - `obsidian.ui.types`: 类型定义
   - `obsidian.config`: 配置选项

2. **集成方式**:
   - 通过 `update_extmarks` 函数集成到现有 UI 系统
   - 使用 Neovim 的 extmark API 实现视觉效果
   - 在 `BufEnter`, `TextChanged` 等 autocmd 中自动更新

3. **性能优化**:
   - 与现有的防抖机制集成
   - 只在 Markdown 文件中启用
   - 支持文件长度限制

## 兼容性

- 与现有的 TOC 功能完全兼容
- 不影响链接解析和其他 obsidian.nvim 功能
- 支持所有标准的 ATX 格式标题 (# ## ### 等)
- 自动跳过代码块中的标题

## 故障排除

### 标题没有显示
1. 确保 `enabled = true`
2. 检查文件是否为 `.md` 扩展名
3. 确保 `conceallevel` 设置为 1 或 2

### 图标显示异常
1. 检查终端是否支持 Unicode 字符
2. 确保 Nerd Font 已正确安装
3. 尝试更换其他图标

### 背景色不显示
1. 确保 `backgrounds = true`
2. 检查终端是否支持背景色
3. 确认高亮组已正确定义