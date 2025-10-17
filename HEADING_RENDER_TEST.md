# 标题渲染功能测试指南

## 测试环境准备

### 1. 配置更新
已更新您的 obsidian.nvim 配置，包含以下标题渲染设置：

```lua
heading = {
  enabled = true,
  icons = { "󰲡 ", "󰲣 ", "󰲥 ", "󰲧 ", "󰲩 ", "󰲫 " },
  position = "overlay",
  foregrounds = true,
  backgrounds = true,
  width = "full",
  border = false,
  above = "▄",
  below = "▀",
  custom = {},
},
```

### 2. 测试文件
创建了测试文件：`/home/lizhe/OriNote/notes/heading_test.md`

包含 6 个级别的标题和各种测试场景。

## 测试步骤

### 步骤 1: 重启 Neovim
```bash
# 完全退出 Neovim 后重新打开
nvim
```

### 步骤 2: 打开测试文件
```vim
:e /home/lizhe/OriNote/notes/heading_test.md
```

### 步骤 3: 检查基本功能
手动验证以下内容：

1. **图标显示**：
   - H1 标题应该显示 `󰲡` 图标
   - H2 标题应该显示 `󰲣` 图标
   - H3 标题应该显示 `󰲥` 图标
   - H4 标题应该显示 `󰲧` 图标
   - H5 标题应该显示 `󰲩` 图标
   - H6 标题应该显示 `󰲫` 图标

2. **背景色**：
   - 每个标题级别应该有不同的背景色
   - 背景应该覆盖整行

3. **位置设置**：
   - 图标应该以 overlay 方式显示（覆盖原始的 # 符号）

### 步骤 4: 运行验证脚本
在 Neovim 中运行：
```vim
:luafile /home/lizhe/.local/share/nvim/lazy/obsidian.nvim/verify_rendering.lua
```

检查输出结果，确认：
- ✅ obsidian 客户端已加载
- ✅ 标题渲染功能已启用
- ✅ 配置正确显示
- ✅ 高亮组已定义
- ✅ extmark 已创建

### 步骤 5: 测试交互功能
1. **编辑测试**：
   - 修改标题内容，观察是否实时更新
   - 添加新标题，观察是否自动渲染
   - 删除标题，观察渲染是否消失

2. **移动测试**：
   - 在标题间移动光标
   - 观察渲染效果是否保持一致

3. **代码块测试**：
   - 确认代码块内的标题不会被渲染

## 预期效果

### 成功的渲染效果
- 所有 6 个级别的标题都应该有对应的图标
- 标题行应该有背景色高亮
- 代码块内的标题应该保持原样
- 编辑时应该实时更新

### 图标对应关系
```
# 一级标题     → 󰲡 一级标题
## 二级标题    → 󰲣 二级标题
### 三级标题   → 󰲥 三级标题
#### 四级标题  → 󰲧 四级标题
##### 五级标题 → 󰲩 五级标题
###### 六级标题 → 󰲫 六级标题
```

## 故障排除

### 如果标题没有渲染
1. 检查 conceallevel 设置：
   ```vim
   :set conceallevel?
   ```
   应该是 1 或 2

2. 检查 obsidian 是否正确加载：
   ```vim
   :lua print(require('obsidian').get_client() and 'OK' or 'FAIL')
   ```

3. 检查配置是否正确：
   ```vim
   :lua print(vim.inspect(require('obsidian').get_client().opts.ui.heading))
   ```

### 如果图标显示异常
1. 确认使用了支持 Nerd Font 的字体
2. 检查终端是否支持 Unicode 字符

### 如果有 Lua 错误
1. 检查错误消息的具体内容
2. 确认所有模块文件存在且语法正确
3. 重启 Neovim

## 高级测试

### 自定义样式测试
可以添加自定义样式来测试：

```lua
custom = {
  ["重要"] = {
    pattern = "重要",
    icon = "❗",
    foreground = "ErrorMsg",
    background = "WarningMsg"
  }
}
```

### 不同位置测试
可以修改 `position` 设置测试：
- `"inline"` - 内联显示
- `"right"` - 右侧显示
- `"overlay"` - 覆盖显示（默认）

### 边框测试
启用边框：
```lua
border = true,
```

## 测试脚本说明

### test_heading_render.lua
- 基础模块加载测试
- 配置完整性检查
- 语法验证

### verify_rendering.lua
- 运行时状态检查
- 高亮组状态验证
- extmark 数量统计
- 交互式验证指导

运行任一脚本来验证功能状态。