#!/usr/bin/env lua

-- 标题渲染验证脚本
-- 在 Neovim 中运行以验证渲染效果

local function verify_heading_rendering()
  print("=== 标题渲染验证 ===")

  -- 检查当前缓冲区是否是 markdown 文件
  local ft = vim.bo.filetype
  if ft ~= "markdown" then
    print("❌ 当前文件不是 markdown 文件: " .. ft)
    return false
  end
  print("✅ 当前文件类型: " .. ft)

  -- 检查 obsidian 客户端
  local ok, obsidian = pcall(require, "obsidian")
  if not ok then
    print("❌ 无法加载 obsidian 模块")
    return false
  end

  local client = obsidian.get_client()
  if not client then
    print("❌ obsidian 客户端未初始化")
    return false
  end
  print("✅ obsidian 客户端已加载")

  -- 检查配置
  local config = client.opts
  if not config or not config.ui or not config.ui.heading then
    print("❌ 标题渲染配置未找到")
    return false
  end

  local heading_config = config.ui.heading
  if not heading_config.enabled then
    print("❌ 标题渲染功能未启用")
    return false
  end
  print("✅ 标题渲染功能已启用")

  print("图标配置:")
  for i, icon in ipairs(heading_config.icons) do
    print("  H" .. i .. ": '" .. icon .. "'")
  end

  print("位置: " .. heading_config.position)
  print("前景色: " .. tostring(heading_config.foregrounds))
  print("背景色: " .. tostring(heading_config.backgrounds))
  print("宽度: " .. heading_config.width)
  print("边框: " .. tostring(heading_config.border))

  -- 检查表格配置
  if config.ui.table then
    local table_config = config.ui.table
    print("\n=== 表格配置 ===")
    print("✅ 表格配置存在")
    print("启用状态: " .. tostring(table_config.enabled))
    print("边框启用: " .. tostring(table_config.border_enabled))
    print("单元格样式: " .. table_config.cell)
    print("填充: " .. table_config.padding)
    print("最小宽度: " .. table_config.min_width)
    print("对齐指示器: " .. table_config.alignment_indicator)
  else
    print("\n❌ 表格配置不存在")
  end
  print("缩进: " .. tostring(heading_config.indent))

  if heading_config.indent then
    print("缩进配置:")
    for level, indent in pairs(heading_config.indent_levels) do
      print("  H" .. level .. ": " .. indent .. " 个空格")
    end
  end

  -- 检查高亮组
  local function check_highlight_group(group_name)
    local ok, hl_def = pcall(vim.api.nvim_get_hl, 0, group_name, {})
    if ok and next(hl_def) then
      return true
    end
    return false
  end

  print("\n高亮组状态:")
  local highlight_groups = {
    "ObsidianHeading1", "ObsidianHeading2", "ObsidianHeading3",
    "ObsidianHeading4", "ObsidianHeading5", "ObsidianHeading6",
    "ObsidianHeading1Bg", "ObsidianHeading2Bg", "ObsidianHeading3Bg",
    "ObsidianHeading4Bg", "ObsidianHeading5Bg", "ObsidianHeading6Bg",
    "ObsidianTableHead", "ObsidianTableRow", "ObsidianTableFill"
  }

  local working_highlights = 0
  for _, group in ipairs(highlight_groups) do
    if check_highlight_group(group) then
      print("  ✅ " .. group)
      working_highlights = working_highlights + 1
    else
      print("  ❌ " .. group)
    end
  end

  print("可用高亮组: " .. working_highlights .. "/" .. #highlight_groups)

  -- 检查 extmark
  local bufnr = vim.api.nvim_get_current_buf()
  local ns_id = vim.api.nvim_create_namespace("obsidian_heading")
  local extmarks = vim.api.nvim_buf_get_extmarks(bufnr, ns_id, 0, -1, { details = true })

  print("\n标题 extmark 状态:")
  if #extmarks == 0 then
    print("  ⚠️  未找到标题 extmark (可能需要等待渲染完成)")
    print("     尝试手动触发渲染: :lua require('obsidian.ui').update(client.opts.ui)")
  else
    print("  ✅ 找到 " .. #extmarks .. " 个 extmark")
    for i, mark in ipairs(extmarks) do
      if i <= 5 then -- 只显示前5个
        local line = mark[2]
        local details = mark[4]
        print("    行 " .. line .. ": " .. (details.virt_text or "无虚拟文本"))
      end
    end
    if #extmarks > 5 then
      print("    ... 还有 " .. (#extmarks - 5) .. " 个 extmark")
    end
  end

  -- 检查表格 extmark
  local table_ns_id = vim.api.nvim_create_namespace("obsidian_table")
  local table_extmarks = vim.api.nvim_buf_get_extmarks(bufnr, table_ns_id, 0, -1, { details = true })

  print("\n表格 extmark 状态:")
  if #table_extmarks == 0 then
    print("  ⚠️  未找到表格 extmark (可能需要等待渲染完成)")
    print("     尝试手动触发渲染: :lua require('obsidian.ui').update(client.opts.ui)")
  else
    print("  ✅ 找到 " .. #table_extmarks .. " 个表格 extmark")
    for i, mark in ipairs(table_extmarks) do
      if i <= 3 then -- 只显示前3个
        local line = mark[2]
        local details = mark[4]
        print("    行 " .. line .. ": " .. (details.virt_text and details.virt_text[1][1] or "虚拟文本"))
      end
    end
    if #table_extmarks > 3 then
      print("    ... 还有 " .. (#table_extmarks - 3) .. " 个表格 extmark")
    end
  end

  print("\n=== 手动验证步骤 ===")
  print("1. 检查各级标题前是否有图标:")
  for i, icon in ipairs(heading_config.icons) do
    local indent_info = ""
    if heading_config.indent and heading_config.indent_levels[i] then
      indent_info = " (缩进 " .. heading_config.indent_levels[i] .. " 空格)"
    end
    print("   H" .. i .. ": 应显示 '" .. icon .. "'" .. indent_info)
  end
  print("2. 检查标题是否有背景色")
  print("3. 验证缩进效果:")
  if heading_config.indent then
    for level, indent in pairs(heading_config.indent_levels) do
      print("   H" .. level .. ": 应缩进 " .. indent .. " 个空格")
    end
  else
    print("   缩进功能未启用")
  end
  print("4. 在标题间移动光标，观察是否正确渲染")
  print("5. 修改标题内容，观察是否实时更新")
  print("6. 验证表格渲染:")
  if config.ui.table and config.ui.table.enabled then
    print("   - 表格边框是否正确显示")
    print("   - 单元格内容是否正确对齐")
    print("   - 分隔符行是否显示对齐指示器")
    print("   - 表格高亮是否正确应用")
  else
    print("   - 表格功能未启用")
  end

  return true
end

-- 运行验证
verify_heading_rendering()