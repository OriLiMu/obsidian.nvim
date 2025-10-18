#!/usr/bin/env lua

-- 表格渲染功能测试脚本

local function test_table_module()
  print("=== 表格渲染功能测试 ===")

  -- 检查模块是否能正确加载
  local ok, Table = pcall(require, "obsidian.ui.table")
  if not ok then
    print("❌ 无法加载 table 模块: " .. tostring(Table))
    return false
  end
  print("✅ table 模块加载成功")

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

  -- 检查默认配置是否包含表格设置
  local default_config = Config.UIOpts.default()
  if not default_config.table then
    print("❌ 默认配置中未找到 table 设置")
    return false
  end
  print("✅ 默认配置包含 table 设置")

  -- 检查表格配置的各个字段
  local required_fields = {
    "enabled", "border", "border_enabled", "cell", "padding",
    "min_width", "alignment_indicator", "head", "row", "filler"
  }

  for _, field in ipairs(required_fields) do
    if default_config.table[field] == nil then
      print("❌ 缺少必需的配置字段: " .. field)
      return false
    end
  end
  print("✅ 所有必需的配置字段都存在")

  -- 检查边框配置
  if type(default_config.table.border) ~= "table" or #default_config.table.border ~= 11 then
    print("❌ 边框配置不正确")
    return false
  end
  print("✅ 边框配置正确 (11个字符)")

  -- 检查高亮组配置
  if not default_config.hl_groups then
    print("❌ 高亮组配置不存在")
    return false
  end

  local table_highlight_groups = {}
  for group_name, _ in pairs(default_config.hl_groups) do
    if string.match(group_name, "ObsidianTable") then
      table.insert(table_highlight_groups, group_name)
    end
  end

  if #table_highlight_groups < 3 then
    print("❌ 表格高亮组数量不足: " .. #table_highlight_groups)
    return false
  end
  print("✅ 表格高亮组配置正确 (" .. #table_highlight_groups .. " 个)")

  -- 测试表格解析功能
  local mock_config = {
    table = {
      enabled = true,
      border = {
        '┌', '┬', '┐',
        '├', '┼', '┤',
        '└', '┴', '┘',
        '│', '─',
      },
      border_enabled = true,
      cell = 'padded',
      padding = 1,
      min_width = 3,
      alignment_indicator = '━',
      head = 'ObsidianTableHead',
      row = 'ObsidianTableRow',
      filler = 'ObsidianTableFill',
    }
  }

  -- 创建表格渲染器实例
  local table_renderer = Table.new(nil, mock_config)
  if not table_renderer then
    print("❌ 无法创建表格渲染器")
    return false
  end
  print("✅ 表格渲染器创建成功")

  print("\n=== 测试完成 ===")
  print("✅ 所有基本测试通过")
  print("现在请在 Neovim 中打开测试文件:")
  print("  nvim /home/lizhe/OriNote/notes/table_test.md")
  print("然后检查:")
  print("  1. 表格是否显示边框")
  print("  2. 单元格是否正确对齐")
  print("  3. 分隔符行是否显示对齐指示器")
  print("  4. 表格高亮是否正确应用")

  return true
end

-- 运行测试
test_table_module()