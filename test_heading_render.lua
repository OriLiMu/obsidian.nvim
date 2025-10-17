#!/usr/bin/env lua

-- 标题渲染功能测试脚本
-- 使用方法: nvim --headless -c "luafile test_heading_render.lua"

local function test_heading_render()
  print("=== Obsidian.nvim 标题渲染功能测试 ===")

  -- 检查模块是否能正确加载
  local ok, Heading = pcall(require, "obsidian.ui.heading")
  if not ok then
    print("❌ 无法加载 heading 模块: " .. tostring(Heading))
    return false
  end
  print("✅ heading 模块加载成功")

  -- 检查类型定义
  local ok, Types = pcall(require, "obsidian.ui.types")
  if not ok then
    print("❌ 无法加载 types 模块: " .. tostring(Types))
    return false
  end
  print("✅ types 模块加载成功")

  -- 检查配置系统
  local ok, Config = pcall(require, "obsidian.config")
  if not ok then
    print("❌ 无法加载 config 模块: " .. tostring(Config))
    return false
  end
  print("✅ config 模块加载成功")

  -- 检查默认配置是否包含标题设置
  local default_config = Config.UIOpts.default()
  if not default_config.heading then
    print("❌ 默认配置中未找到 heading 设置")
    return false
  end
  print("✅ 默认配置包含 heading 设置")

  -- 检查标题配置的各个字段
  local required_fields = {
    "enabled", "icons", "position", "foregrounds",
    "backgrounds", "width", "border", "above", "below", "custom"
  }

  for _, field in ipairs(required_fields) do
    if default_config.heading[field] == nil then
      print("❌ 缺少必需的配置字段: " .. field)
      return false
    end
  end
  print("✅ 所有必需的配置字段都存在")

  -- 检查图标配置
  if type(default_config.heading.icons) ~= "table" or #default_config.heading.icons ~= 6 then
    print("❌ 图标配置不正确")
    return false
  end
  print("✅ 图标配置正确 (6个级别)")

  -- 检查高亮组配置
  if not default_config.hl_groups then
    print("❌ 高亮组配置不存在")
    return false
  end

  local heading_highlight_groups = {}
  for group_name, _ in pairs(default_config.hl_groups) do
    if string.match(group_name, "ObsidianHeading[1-6]") then
      table.insert(heading_highlight_groups, group_name)
    end
  end

  if #heading_highlight_groups < 6 then
    print("❌ 标题高亮组数量不足: " .. #heading_highlight_groups)
    return false
  end
  print("✅ 标题高亮组配置正确 (" .. #heading_highlight_groups .. " 个)")

  print("\n=== 测试完成 ===")
  print("✅ 所有基本测试通过")
  print("现在请在 Neovim 中打开测试文件:")
  print("  nvim /home/lizhe/OriNote/notes/heading_test.md")
  print("然后检查:")
  print("  1. 各级标题是否显示图标")
  print("  2. 背景色是否正确应用")
  print("  3. 没有Lua错误")

  return true
end

-- 运行测试
test_heading_render()