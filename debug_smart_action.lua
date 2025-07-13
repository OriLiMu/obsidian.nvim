-- 调试版本的 smart_action 函数
-- 包含详细的日志输出，用于排查二级链接跳转问题

local function smart_action_debug()
  local log = require "obsidian.log"
  local util = require "obsidian.util"
  
  log.info("=== smart_action_debug 开始 ===")
  
  -- 检查光标是否在链接上
  local is_on_link = util.cursor_on_markdown_link(nil, nil, true)
  log.info("光标是否在链接上: %s", is_on_link)
  
  if is_on_link then
    -- 解析链接
    local link_location, link_name, link_type = util.parse_cursor_link()
    log.info("解析结果:")
    log.info("  link_location: '%s'", link_location or "nil")
    log.info("  link_name: '%s'", link_name or "nil") 
    log.info("  link_type: '%s'", link_type or "nil")
    
    -- 检查是否为URL
    local is_url = link_type == "URL" or string.match(link_location or "", "^https?://")
    log.info("是否为URL链接: %s", is_url)
    
    if is_url then
      log.info("处理URL链接，触发 ObsidianFollowLink")
      return "<cmd>ObsidianFollowLink<CR>"
    end

    -- 分离锚点和块链接用于调试
    local file_location = link_location
    local anchor_link, block_link
    
    if file_location then
      file_location, block_link = util.strip_block_links(file_location)
      file_location, anchor_link = util.strip_anchor_links(file_location)
      
      log.info("链接分离结果:")
      log.info("  原始链接: '%s'", link_location)
      log.info("  文件位置: '%s'", file_location or "nil")
      log.info("  锚点链接: '%s'", anchor_link or "无")
      log.info("  块链接: '%s'", block_link or "无")
    end

    -- 检查文件是否存在（仅用于调试，不影响实际行为）
    local client = require("obsidian").get_client()
    if client and file_location then
      local notes = { client:resolve_note(file_location) }
      log.info("文件存在性检查:")
      log.info("  使用文件名 '%s' 查找到 %d 个笔记", file_location, #notes)
      for i, note in ipairs(notes) do
        log.info("    笔记 %d: %s", i, note.path)
      end
      
      if anchor_link and #notes > 0 then
        local note = notes[1]
        local anchor_match = note:resolve_anchor_link(anchor_link)
        if anchor_match then
          log.info("  锚点 '%s' 解析成功: %s (行号: %d)", 
                   anchor_link, anchor_match.header, anchor_match.line)
        else
          log.warn("  锚点 '%s' 解析失败", anchor_link)
          log.info("  标准化后的锚点: '%s'", util.standardize_anchor(anchor_link))
        end
      end
    end

    -- 对于所有非URL链接，都直接调用 ObsidianFollowLink
    log.info("触发 ObsidianFollowLink 处理链接跳转")
    return "<cmd>ObsidianFollowLink<CR>"
  end

  -- 不在链接上，触发复选框切换
  log.info("不在链接上，触发 ObsidianToggleCheckbox")
  return "<cmd>ObsidianToggleCheckbox<CR>"
end

-- 使用方法：
-- 1. 在 Neovim 中加载此文件：:luafile debug_smart_action.lua
-- 2. 临时替换键位映射：
--    vim.keymap.set("n", "<leader>d", smart_action_debug, { expr = true, desc = "Debug smart action" })
-- 3. 将光标放在问题链接上，按 <leader>d，查看详细日志
-- 4. 使用 :messages 查看完整的调试输出

return {
  smart_action_debug = smart_action_debug
} 