#!/usr/bin/env lua

-- 标题缩进功能测试脚本

local function test_indent_feature()
  print("=== 标题缩进功能测试 ===")

  -- 检查模块是否能正确加载
  local ok, Heading = pcall(require, "obsidian.ui.heading")
  if not ok then
    print("❌ 无法加载 heading 模块: " .. tostring(Heading))
    return false
  end
  print("✅ heading 模块加载成功")

  -- 模拟配置
  local test_config = {
    heading = {
      enabled = true,
      indent = true,
      indent_levels = {
        [2] = 2, -- H2 缩进2个空格
        [3] = 4, -- H3 缩进4个空格
        [4] = 6, -- H4 缩进6个空格
      }
    }
  }

  -- 创建标题渲染器实例
  local renderer = Heading.new(nil, test_config)

  -- 测试缩进计算
  local test_cases = {
    { level = 1, expected = 0, description = "H1 无缩进" },
    { level = 2, expected = 2, description = "H2 缩进2个空格" },
    { level = 3, expected = 4, description = "H3 缩进4个空格" },
    { level = 4, expected = 6, description = "H4 缩进6个空格" },
    { level = 5, expected = 0, description = "H5 无缩进" },
    { level = 6, expected = 0, description = "H6 无缩进" },
  }

  print("\n缩进计算测试:")
  local all_passed = true
  for _, test_case in ipairs(test_cases) do
    local result = renderer:_get_indent(test_case.level)
    if result == test_case.expected then
      print("✅ " .. test_case.description .. ": " .. result)
    else
      print("❌ " .. test_case.description .. ": 期望 " .. test_case.expected .. ", 实际 " .. result)
      all_passed = false
    end
  end

  -- 测试禁用缩进的情况
  local disabled_config = {
    heading = {
      enabled = true,
      indent = false
    }
  }

  local disabled_renderer = Heading.new(nil, disabled_config)
  local disabled_result = disabled_renderer:_get_indent(2)

  if disabled_result == 0 then
    print("✅ 禁用缩进时返回0: " .. disabled_result)
  else
    print("❌ 禁用缩进时应该返回0, 实际: " .. disabled_result)
    all_passed = false
  end

  -- 测试自定义缩进配置
  local custom_config = {
    heading = {
      enabled = true,
      indent = true,
      indent_levels = {
        [1] = 1,
        [2] = 3,
        [3] = 5,
        [4] = 7,
        [5] = 9,
        [6] = 11,
      }
    }
  }

  local custom_renderer = Heading.new(nil, custom_config)
  print("\n自定义缩进测试:")
  for level = 1, 6 do
    local expected = 2 * level - 1
    local result = custom_renderer:_get_indent(level)
    if result == expected then
      print("✅ H" .. level .. " 自定义缩进: " .. result)
    else
      print("❌ H" .. level .. " 自定义缩进: 期望 " .. expected .. ", 实际 " .. result)
      all_passed = false
    end
  end

  if all_passed then
    print("\n✅ 所有缩进测试通过!")
  else
    print("\n❌ 部分测试失败")
  end

  return all_passed
end

-- 运行测试
test_indent_feature()