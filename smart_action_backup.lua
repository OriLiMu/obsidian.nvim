-- 备份原始的 smart_action 函数实现
-- 时间: 2024年执行修复前
-- 问题: 该函数没有正确处理带锚点的链接，导致二级链接被识别为"空链接"

local util = {}
local log = require "obsidian.log"

util.smart_action_original = function()
  -- follow link if possible
  if util.cursor_on_markdown_link(nil, nil, true) then
    local open, close, link_type = util.cursor_on_markdown_link(nil, nil, true)
    local link_location, link_name, link_type = util.parse_cursor_link()
    -- check here if the link is a web link
    if link_type == "URL" or string.match(link_location, "^https?://") then
      return "<cmd>ObsidianFollowLink<CR>"
    end

    -- 检查文件是否存在于 vault 中
    local client = require("obsidian").get_client()
    if client then
      local notes = { client:resolve_note(link_location) }
      if #notes > 0 then
        log.info "文件已存在，触发 ObsidianFollowLink"
        return "<cmd>ObsidianFollowLink<CR>"
      end
    end

    -- 如果文件不存在，且链接为空，则创建新文件
    log.info "检测到空链接，触发 ObsidianNew"
    return "<cmd>ObsidianNew<CR>"
  end

  -- toggle task if possible
  -- cycles through your custom UI checkboxes, default: [ ] [~] [>] [x]
  log.info "不在链接上，触发 ObsidianToggleCheckbox"
  return "<cmd>ObsidianToggleCheckbox<CR>"
end

return util 