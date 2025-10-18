# 光标行渲染修复功能文档

## 问题背景

在之前的实现中，当用户在编辑 markdown 文档时，光标所在行仍然显示渲染效果（如标题图标、缩进、表格边框等），这导致：

1. **编辑冲突**：渲染效果干扰用户的编辑体验
2. **光标位置错乱**：缩进和图标使得光标位置不直观
3. **响应延迟**：无法及时看到编辑结果

## 解决方案

### 核心策略

采用**智能跳过当前行 + 实时重渲染**的组合方案：

1. **跳过光标行**：检测光标位置，跳过该行的渲染
2. **实时响应**：光标移动时立即重新渲染
3. **智能防抖**：根据编辑状态调整响应速度

### 技术实现

#### 1. 光标位置检测
```lua
-- 获取当前光标位置
local current_line = 0
local ok, cursor = pcall(vim.api.nvim_win_get_cursor, 0)
if ok and cursor then
  current_line = cursor[1] - 1  -- 转换为 0-based
end
```

#### 2. 渲染跳过逻辑
```lua
-- 在标题渲染中
if self.config.skip_cursor_line and heading.line == current_line then
  -- 跳过当前光标行的渲染
  return
end

-- 在表格渲染中
if self.config.skip_cursor_line and row.line_num == current_line then
  -- 跳过当前光标行的渲染
  return
end
```

#### 3. 光标移动监听
```lua
vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI" }, {
  group = group,
  pattern = pattern,
  callback = function(ev)
    -- 延迟触发重新渲染
    require("obsidian.async").throttle(function()
      update_extmarks(ev.buf, ns_id, ui_opts)
    end, delay)()
  end,
})
```

## 配置选项

### 新增配置项

```lua
ui = {
  skip_cursor_line = true,     -- 启用跳过光标行功能
  cursor_render_delay = 50,     -- 光标移动延迟(ms)
  update_debounce = 200,        -- 文本变化延迟(ms)
  skip_cursor_content = false,  -- 光标行是否跳过所有渲染内容
  -- ... 其他配置
}
```

### 配置说明

| 选项 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `skip_cursor_line` | boolean | `true` | 是否跳过光标所在行的渲染 |
| `cursor_render_delay` | integer | `50` | 光标移动后的渲染延迟（毫秒） |
| `skip_cursor_content` | boolean | `false` | 光标行是否跳过所有渲染内容（true=全部跳过，false=保留缩进等基础渲染） |

### 自定义配置示例

```lua
-- 完全禁用跳过功能
ui = {
  skip_cursor_line = false,
  cursor_render_delay = 50,
}

-- 更快的响应速度
ui = {
  skip_cursor_line = true,
  cursor_render_delay = 20,  -- 20ms延迟
}

-- 更慢的响应速度（节省资源）
ui = {
  skip_cursor_line = true,
  cursor_render_delay = 100, -- 100ms延迟
}

-- 光标行完全跳过所有渲染（包括缩进）
ui = {
  skip_cursor_line = true,
  skip_cursor_content = true,  -- 完全跳过光标行的所有渲染
}
```

## 智能防抖机制

### 动态防抖时间

根据编辑模式自动调整防抖时间：

```lua
local function get_debounce_time()
  local mode = vim.api.nvim_get_mode().mode
  if mode == "i" or mode == "R" or mode == "c" then
    return math.min(ui_opts.update_debounce / 2, 100)  -- 编辑时最多100ms
  else
    return ui_opts.update_debounce
  end
end
```

### 防抖效果

- **编辑模式**：更短的防抖时间（最多100ms），响应更及时
- **浏览模式**：正常的防抖时间（200ms），减少性能影响

## 渲染行为

### 标题渲染

#### 光标在标题行时（`skip_cursor_content = false`）
- ❌ 不显示图标（如 󰲡、󰲣 等）
- ✅ 保持缩进效果（H2=2空格，H3=4空格，H4=6空格）
- ❌ 不显示背景色
- ❌ 不显示边框
- ✅ 保持标题文本的基本高亮
- ✅ 保持原始文本编辑状态

#### 光标在标题行时（`skip_cursor_content = true`）
- ❌ 不显示图标
- ❌ 不显示缩进
- ❌ 不显示背景色
- ❌ 不显示边框
- ❌ 不显示高亮
- ✅ 完全原始编辑状态

#### 光标移开标题行时
- ✅ 自动恢复图标显示
- ✅ 自动恢复缩进效果
- ✅ 自动恢复背景色
- ✅ 自动恢复边框

### 表格渲染

#### 光标在表格行时
- ❌ 不显示边框字符（│、─、┌、┐等）
- ❌ 不显示单元格填充
- ❌ 不显示对齐指示器
- ✅ 保持原始表格结构可编辑

#### 光标移开表格行时
- ✅ 自动恢复边框显示
- ✅ 自动恢复单元格格式
- ✅ 自动恢复对齐指示器

## 用户体验改进

### 编辑体验
1. **直观编辑**：光标所在行显示原始内容，编辑更直观
2. **位置准确**：光标位置与编辑位置完全匹配
3. **无干扰**：没有渲染效果干扰编辑过程
4. **保留缩进**：在 `skip_cursor_content = false` 时，保留缩进效果

### 视觉反馈
1. **即时响应**：光标移动后立即更新渲染状态
2. **平滑过渡**：防抖机制确保渲染不闪烁
3. **智能切换**：编辑和浏览模式使用不同的响应速度
4. **部分渲染**：光标行仍然保留基础的格式化效果

## 性能优化

### 资源节省
1. **减少渲染**：跳过当前行减少不必要的渲染计算
2. **智能防抖**：避免频繁的渲染更新
3. **按需重渲染**：只在光标移动时才触发更新

### 内存管理
1. **及时清理**：光标移动时自动清理旧的渲染
2. **命名空间隔离**：不同功能的渲染使用独立的命名空间
3. **缓存机制**：避免重复解析相同的元素

## 兼容性

### 向后兼容
- ✅ 所有现有功能保持不变
- ✅ 默认启用新功能
- ✅ 可通过配置完全禁用

### 多模式支持
- ✅ Normal 模式：正常渲染和跳过逻辑
- ✅ Insert 模式：智能跳过和快速响应
- ✅ Visual 模式：保持选中区域的渲染
- ✅ Command 模式：命令行不受影响

## 测试指南

### 基础测试
1. 打开包含标题的文档
2. 将光标移动到标题行
3. 观察渲染效果消失（但缩进保留）
4. 将光标移开标题行
5. 观察渲染效果恢复

### 高级测试
1. 在标题行中编辑内容
2. 快速移动光标
3. 测试不同防抖设置的效果
4. 验证性能影响

### 故障排除

#### 如果光标行仍然显示渲染
1. 检查配置：`skip_cursor_line = true`
2. 重启 Neovim 确保配置生效
3. 检查是否启用了正确的 UI 功能

#### 如果缩进效果消失
1. 检查配置：`skip_cursor_content = false`
2. 确认标题配置中启用了缩进功能
3. 检查 indent_levels 配置是否正确

#### 如果响应速度太慢
1. 减少 `cursor_render_delay` 值
2. 减少 `update_debounce` 值
3. 检查系统资源使用情况

#### 如果渲染效果混乱
1. 检查防抖时间设置
2. 确认没有冲突的插件
3. 重启 Neovim 清理状态

## 最佳实践

### 推荐配置
```lua
ui = {
  skip_cursor_line = true,      -- 启用跳过功能
  cursor_render_delay = 30,     -- 快速响应
  update_debounce = 150,        -- 适中防抖
  skip_cursor_content = false,  -- 保留缩进效果
  heading = {
    enabled = true,
    position = "overlay",       -- 推荐使用 overlay 模式
    indent = true,              -- 启用缩进
    indent_levels = {           -- 配置缩进级别
      [2] = 2,
      [3] = 4,
      [4] = 6,
    },
    -- ... 其他标题配置
  },
  -- ... 其他 UI 配置
}
```

### 使用建议
1. **保持默认配置**：默认设置已优化
2. **根据设备调整**：高性能设备可减少延迟
3. **监控性能**：如遇性能问题可增加延迟
4. **选择合适模式**：overlay 模式通常提供最佳编辑体验

## 技术细节

### 事件处理流程
1. 光标移动 → 触发 CursorMoved autocmd
2. 防抖延迟 → 执行渲染更新
3. 位置检测 → 跳过当前行渲染
4. 其他行 → 正常渲染显示

### 命名空间管理
- `obsidian_heading`: 标题渲染命名空间
- `obsidian_table`: 表格渲染命名空间
- `ObsidianUI`: 主要 UI 命名空间

### 异步处理
- 使用 `obsidian.async.throttle` 进行防抖
- 错误处理确保渲染稳定性
- 优先级设置确保正确的渲染顺序

## 更新日志

### v3.9.1
- ✅ 修复光标行缩进效果消失问题
- ✅ 实现智能部分渲染（保留缩进，跳过图标）
- ✅ 添加 `skip_cursor_content` 配置选项
- ✅ 完善不同位置模式的渲染逻辑
- ✅ 优化性能和响应速度

这个修复功能大大改善了 markdown 编辑体验，让用户能够更直观、更高效地编辑文档，同时保持了重要的视觉提示（如缩进）！