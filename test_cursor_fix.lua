#!/usr/bin/env lua

-- 光标行渲染修复功能测试脚本

local function test_cursor_fix_feature()
  print("=== 光标行渲染修复功能测试 ===")

  -- 检查配置文件语法
  local function check_config()
    local file = io.open('/home/lizhe/.config/nvim/lua/plugins/obsidian.lua', 'r')
    if not file then
      print('❌ 无法读取配置文件')
      return false
    end
    local content = file:read('*all')
    file:close()

    -- 检查新增的配置项（如果用户添加了的话）
    local cursor_config_found = false
    if content:find("skip_cursor_line") or content:find("cursor_render_delay") then
      cursor_config_found = true
      print('✅ 发现用户自定义光标配置')
    else
      print('✅ 使用默认光标配置')
    end

    return true
  end

  check_config()

  -- 检查模块语法
  local modules = {
    'lua/obsidian/ui/heading.lua',
    'lua/obsidian/ui/table.lua',
    'lua/obsidian/ui.lua',
    'lua/obsidian/config.lua'
  }

  print("\n模块语法检查:")
  for _, module in ipairs(modules) do
    local cmd = "luac -p " .. module
    local result = os.execute(cmd)
    if result == 0 then
      print("✅ " .. module)
    else
      print("❌ " .. module)
      return false
    end
  end

  -- 检查测试文件
  local test_files = {
    '/home/lizhe/OriNote/notes/heading_test.md',
    '/home/lizhe/OriNote/notes/table_test.md'
  }

  print("\n测试文件检查:")
  for _, file in ipairs(test_files) do
    local f = io.open(file, 'r')
    if f then
      f:close()
      print("✅ " .. file)
    else
      print("❌ " .. file .. " (文件不存在)")
    end
  end

  print("\n=== 功能说明 ===")
  print("1. 光标所在行不再显示 markdown 渲染效果")
  print("2. 光标移动后，原所在行自动恢复正常渲染")
  print("3. 编辑状态下防抖时间更短，响应更及时")
  print("4. 可以通过配置控制这个功能")

  print("\n=== 测试步骤 ===")
  print("1. 重启 Neovim 以加载新功能")
  print("2. 打开包含标题的文档:")
  print("   nvim /home/lizhe/OriNote/notes/heading_test.md")
  print("3. 测试标题:")
  print("   - 将光标移动到标题行，观察渲染效果消失")
  print("   - 将光标移开，观察渲染效果恢复")
  print("4. 测试表格:")
  print("   - nvim /home/lizhe/OriNote/notes/table_test.md")
  print("   - 将光标移动到表格行，观察渲染效果消失")
  print("5. 测试编辑:")
  print("   - 在标题或表格行中编辑内容")
  print("   - 观察响应速度和渲染更新")

  print("\n=== 预期效果 ===")
  print("✅ 光标在标题行时：无图标、无缩进、无背景")
  print("✅ 光标在表格行时：无边框、无填充")
  print("✅ 光标移开后：正常渲染效果恢复")
  print("✅ 编辑时：快速响应，无渲染干扰")

  print("\n=== 配置选项 ===")
  print("如需自定义，可在配置中添加:")
  print([[
  ui = {
    skip_cursor_line = true,     -- 启用跳过光标行功能
    cursor_render_delay = 50,     -- 光标移动延迟(ms)
  }
  ]])

  return true
end

-- 运行测试
test_cursor_fix_feature()