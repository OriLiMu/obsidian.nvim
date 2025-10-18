local util = require "obsidian.util"

---@class obsidian.ui.Heading
---@field client obsidian.Client
---@field config obsidian.Config
---@field ns_id integer
local Heading = {}

Heading.__index = Heading

---@param client obsidian.Client
---@param config obsidian.Config
---@return obsidian.ui.Heading
function Heading.new(client, config)
  local self = setmetatable({}, Heading)
  self.client = client
  self.config = config
  self.ns_id = vim.api.nvim_create_namespace("obsidian_heading")
  return self
end

---@class obsidian.ui.Heading.Data
---@field level integer
---@field line integer
---@field col integer
---@field end_col integer
---@field text string
---@field icon string
---@field highlight_fg string
---@field highlight_bg string
---@field indent integer

---@private
---@param bufnr integer
---@return obsidian.ui.Heading.Data[]
function Heading:_parse_headings(bufnr)
  local headings = {}
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)

  for line_num, line in ipairs(lines) do
    -- 匹配 ATX 标题格式 (# ## ### 等)
    local level, header_text = string.match(line, "^(#+)%s+(.+)$")
    if level and header_text then
      local heading_level = #level
      local icon = self:_get_icon(heading_level)
      local highlight_fg = self:_get_highlight_fg(heading_level)
      local highlight_bg = self:_get_highlight_bg(heading_level)
      local indent = self:_get_indent(heading_level)

      table.insert(headings, {
        level = heading_level,
        line = line_num - 1, -- 0-based indexing
        col = 0,
        end_col = #line,
        text = header_text,
        icon = icon,
        highlight_fg = highlight_fg,
        highlight_bg = highlight_bg,
        indent = indent,
      })
    end
  end

  return headings
end

---@private
---@param level integer
---@return string
function Heading:_get_icon(level)
  local icons = self.config.heading.icons
  if type(icons) == "function" then
    return icons({ level = level })
  elseif type(icons) == "table" then
    return icons[level] or ""
  else
    return ""
  end
end

---@private
---@param level integer
---@return string
function Heading:_get_highlight_fg(level)
  local highlights = self.config.heading.foregrounds
  if type(highlights) == "table" then
    return highlights[level] or ("ObsidianHeading" .. level)
  else
    return "ObsidianHeading" .. level
  end
end

---@private
---@param level integer
---@return string|nil
function Heading:_get_highlight_bg(level)
  if not self.config.heading.backgrounds then
    return nil
  end

  local highlights = self.config.heading.backgrounds
  if type(highlights) == "table" then
    return highlights[level] or ("ObsidianHeading" .. level .. "Bg")
  else
    return "ObsidianHeading" .. level .. "Bg"
  end
end

---@private
---@param level integer
---@return integer
function Heading:_get_indent(level)
  if not self.config.heading.indent then
    return 0
  end

  local indent_levels = self.config.heading.indent_levels
  if type(indent_levels) == "table" then
    return indent_levels[level] or 0
  else
    -- 默认缩进规则：H2=2, H3=4, H4=6
    if level == 2 then
      return 2
    elseif level == 3 then
      return 4
    elseif level == 4 then
      return 6
    else
      return 0
    end
  end
end

---@private
---@param heading obsidian.ui.Heading.Data
---@return integer
function Heading:_render_icon(heading)
  if not heading.icon or heading.icon == "" then
    return 0
  end

  local position = self.config.heading.position
  local highlight = {}

  if heading.highlight_fg then
    table.insert(highlight, heading.highlight_fg)
  end
  if heading.highlight_bg then
    table.insert(highlight, heading.highlight_bg)
  end

  if #highlight == 0 then
    return 0
  end

  local bufnr = vim.api.nvim_get_current_buf()
  local width = 0

  if position == "right" then
    -- 在行尾显示图标
    vim.api.nvim_buf_set_extmark(bufnr, self.ns_id, heading.line, 0, {
      priority = 1000,
      virt_text = { { heading.icon, highlight } },
      virt_text_pos = "eol",
    })
    width = vim.fn.strdisplaywidth(heading.icon) + 1
  elseif position == "inline" then
    -- 内联显示，替换 # 符号，考虑缩进
    local end_col = heading.level + 1
    local icon_text = heading.icon

    -- 如果有缩进，在图标前添加空格
    if heading.indent > 0 then
      icon_text = string.rep(" ", heading.indent) .. heading.icon
    end

    vim.api.nvim_buf_set_extmark(bufnr, self.ns_id, heading.line, 0, {
      end_col = end_col,
      virt_text = { { icon_text, highlight } },
      virt_text_pos = "inline",
      conceal = "",
    })
    width = vim.fn.strdisplaywidth(icon_text)
  elseif position == "overlay" then
    -- 覆盖显示，在左侧添加图标，考虑缩进
    local icon_text = heading.icon
    local base_width = heading.level

    -- 如果有缩进，在图标前添加空格
    if heading.indent > 0 then
      icon_text = string.rep(" ", heading.indent) .. heading.icon
      base_width = base_width + heading.indent
    end

    local padding = base_width - vim.fn.strdisplaywidth(heading.icon)
    if padding > 0 then
      local padding_text = string.rep(" ", padding)
      vim.api.nvim_buf_set_extmark(bufnr, self.ns_id, heading.line, 0, {
        virt_text = { { padding_text .. heading.icon, highlight } },
        virt_text_pos = "overlay",
      })
    else
      vim.api.nvim_buf_set_extmark(bufnr, self.ns_id, heading.line, 0, {
        end_col = heading.level + 1,
        virt_text = { { icon_text, highlight } },
        virt_text_pos = "inline",
        conceal = "",
      })
    end
    width = base_width + 1
  end

  return width
end

---@private
---@param heading obsidian.ui.Heading.Data
function Heading:_render_background(heading)
  if not heading.highlight_bg then
    return
  end

  local bufnr = vim.api.nvim_get_current_buf()
  local width = self.config.heading.width or "full"

  if width == "block" then
    -- 只渲染标题文本宽度的背景，考虑缩进
    local start_col = heading.indent > 0 and heading.indent or 0
    vim.api.nvim_buf_set_extmark(bufnr, self.ns_id, heading.line, start_col, {
      end_col = heading.end_col,
      hl_group = heading.highlight_bg,
      hl_eol = false,
    })
  else
    -- 渲染整行背景
    vim.api.nvim_buf_set_extmark(bufnr, self.ns_id, heading.line, 0, {
      end_col = 0,
      hl_group = heading.highlight_bg,
      hl_eol = true,
    })
  end
end

---@private
---@param heading obsidian.ui.Heading.Data
---@param above boolean
function Heading:_render_border(heading, above)
  if not self.config.heading.border then
    return
  end

  local bufnr = vim.api.nvim_get_current_buf()
  local border_char = above and self.config.heading.above or self.config.heading.below
  if not border_char or border_char == "" then
    return
  end

  local line_num = above and heading.line or heading.line + 1
  if line_num < 0 or line_num >= vim.api.nvim_buf_line_count(bufnr) then
    return
  end

  local width = self.config.heading.width or "full"
  local border_text = ""

  if width == "block" then
    border_text = string.rep(border_char, math.min(heading.end_col, vim.api.nvim_win_get_width(0)))
  else
    border_text = string.rep(border_char, vim.api.nvim_win_get_width(0))
  end

  local line_content = vim.api.nvim_buf_get_lines(bufnr, line_num, line_num + 1, false)[1] or ""

  if line_content == "" or line_content:match("^%s*$") then
    -- 使用空行或只包含空白字符的行
    vim.api.nvim_buf_set_extmark(bufnr, self.ns_id, line_num, 0, {
      virt_text = { { border_text, heading.highlight_fg or heading.highlight_bg } },
      virt_text_pos = "overlay",
    })
  else
    -- 使用虚拟行
    vim.api.nvim_buf_set_extmark(bufnr, self.ns_id, line_num, 0, {
      virt_lines = { { { border_text, heading.highlight_fg or heading.highlight_bg } } },
      virt_lines_above = above,
    })
  end
end

---@public
---@param bufnr integer
function Heading:render(bufnr)
  if not self.config.heading.enabled then
    return
  end

  -- 获取当前光标位置
  local current_line = 0
  local ok, cursor = pcall(vim.api.nvim_win_get_cursor, 0)
  if ok and cursor then
    current_line = cursor[1] - 1  -- 转换为 0-based
  end

  -- 清除之前的渲染
  self:clear(bufnr)

  -- 解析标题
  local headings = self:_parse_headings(bufnr)

  -- 渲染每个标题
  for _, heading in ipairs(headings) do
    local on_cursor_line = self.config.skip_cursor_line and heading.line == current_line

    -- 检查是否启用跳过光标行功能
    if not on_cursor_line then
      -- 不在光标行，正常渲染所有内容
      self:_render_heading_full(heading)
    elseif not self.config.skip_cursor_content then
      -- 在光标行，但只跳过图标，保留缩进等基础渲染
      self:_render_heading_partial(heading)
    end
    -- 如果 skip_cursor_content 为 true，则完全跳过渲染
  end
end

---@private
---@param text string
---@return obsidian.ui.heading.CustomStyle|?
function Heading:_get_custom_style(text)
  local custom_styles = self.config.heading.custom or {}
  for _, style in pairs(custom_styles) do
    if string.match(text, style.pattern) then
      return style
    end
  end
  return nil
end

---@public
---@param bufnr integer
function Heading:clear(bufnr)
  vim.api.nvim_buf_clear_namespace(bufnr, self.ns_id, 0, -1)
end

---@private
---@param heading obsidian.ui.Heading.Data
function Heading:_render_heading_full(heading)
  -- 检查自定义样式
  local custom_style = self:_get_custom_style(heading.text)
  if custom_style then
    if custom_style.icon then
      heading.icon = custom_style.icon
    end
    if custom_style.foreground then
      heading.highlight_fg = custom_style.foreground
    end
    if custom_style.background then
      heading.highlight_bg = custom_style.background
    end
  end

  -- 渲染背景
  self:_render_background(heading)

  -- 渲染图标（包含缩进）
  self:_render_icon(heading)

  -- 渲染边框
  self:_render_border(heading, true)  -- 上边框
  self:_render_border(heading, false) -- 下边框
end

---@private
---@param heading obsidian.ui.Heading.Data
function Heading:_render_heading_partial(heading)
  -- 只渲染缩进，不渲染图标，不渲染边框，不渲染背景
  -- 但是保持标题文本的基本高亮

  if heading.indent <= 0 then
    return
  end

  local bufnr = vim.api.nvim_get_current_buf()
  local position = self.config.heading.position

  if position == "inline" then
    -- 内联显示：在#符号后添加缩进空格，保持文本高亮
    local indent_text = string.rep(" ", heading.indent)
    vim.api.nvim_buf_set_extmark(bufnr, self.ns_id, heading.line, 0, {
      end_col = heading.level + 1,
      virt_text = { { indent_text, heading.highlight_fg or ("ObsidianHeading" .. heading.level) } },
      virt_text_pos = "inline",
      conceal = "",
    })
  elseif position == "overlay" then
    -- 覆盖显示：在行首添加缩进
    local indent_text = string.rep(" ", heading.indent)
    vim.api.nvim_buf_set_extmark(bufnr, self.ns_id, heading.line, 0, {
      virt_text = { { indent_text } },
      virt_text_pos = "overlay",
    })

    -- 同时为标题文本添加基本高亮（从#符号后开始到行尾）
    vim.api.nvim_buf_set_extmark(bufnr, self.ns_id, heading.line, heading.level + 1, {
      end_col = heading.end_col,
      hl_group = heading.highlight_fg or ("ObsidianHeading" .. heading.level),
      hl_eol = false,
    })
  elseif position == "right" then
    -- 右侧显示：仍然添加缩进效果
    local indent_text = string.rep(" ", heading.indent)
    vim.api.nvim_buf_set_extmark(bufnr, self.ns_id, heading.line, 0, {
      end_col = heading.level + 1,
      virt_text = { { indent_text, heading.highlight_fg or ("ObsidianHeading" .. heading.level) } },
      virt_text_pos = "inline",
      conceal = "",
    })

    -- 为标题文本添加高亮
    vim.api.nvim_buf_set_extmark(bufnr, self.ns_id, heading.line, heading.indent + heading.level + 1, {
      end_col = heading.end_col,
      hl_group = heading.highlight_fg or ("ObsidianHeading" .. heading.level),
      hl_eol = false,
    })
  end
end

return Heading