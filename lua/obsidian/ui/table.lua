local util = require "obsidian.util"

---@class obsidian.ui.Table
---@field client obsidian.Client
---@field config obsidian.Config
---@field ns_id integer
local Table = {}

Table.__index = Table

---@param client obsidian.Client
---@param config obsidian.Config
---@return obsidian.ui.Table
function Table.new(client, config)
  local self = setmetatable({}, Table)
  self.client = client
  self.config = config
  self.ns_id = vim.api.nvim_create_namespace("obsidian_table")
  return self
end

---@class obsidian.ui.table.Data
---@field delim_row obsidian.ui.table.DelimRow
---@field rows obsidian.ui.table.Row[]

---@class obsidian.ui.table.DelimRow
---@field line_num integer
---@field cols obsidian.ui.table.DelimCol[]

---@class obsidian.ui.table.DelimCol
---@field width integer
---@field alignment obsidian.ui.table.Alignment

---@class obsidian.ui.table.Row
---@field line_num integer
---@field is_header boolean
---@field cols obsidian.ui.table.Col[]

---@class obsidian.ui.table.Col
---@field start_col integer
---@field end_col integer
---@field text string
---@field width integer

---@private
---@param bufnr integer
---@return obsidian.ui.table.Data|?
function Table:_parse_table(bufnr)
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)

  -- 查找表格边界
  local table_start = nil
  local delim_line = nil
  local table_end = nil

  for i, line in ipairs(lines) do
    if string.match(line, "^%s*|.*|%s*$") then
      if not table_start then
        table_start = i
      end
      if string.match(line, "^%s*|[-:]+|.*|%s*$") then
        delim_line = i
      end
      table_end = i
    elseif table_start then
      break
    end
  end

  if not table_start or not delim_line or not table_end then
    return nil
  end

  -- 解析分隔符行
  local delim_row = self:_parse_delim_row(lines[delim_line], delim_line - 1)
  if not delim_row then
    return nil
  end

  -- 解析表格行
  local rows = {}
  for i = table_start, table_end do
    if i ~= delim_line then
      local row = self:_parse_row(lines[i], i - 1, delim_row)
      if row then
        table.insert(rows, row)
      end
    end
  end

  if #rows == 0 then
    return nil
  end

  -- 计算列宽
  self:_calculate_column_widths(rows, delim_row)

  return {
    delim_row = delim_row,
    rows = rows,
  }
end

---@private
---@param line string
---@param line_num integer
---@return obsidian.ui.table.DelimRow|?
function Table:_parse_delim_row(line, line_num)
  local cells = {}
  local cols = {}

  -- 分割单元格
  for cell in string.gmatch(line, "([^|]+)") do
    if cell ~= "" then
      table.insert(cells, vim.trim(cell))
    end
  end

  -- 解析每列的宽度和对齐方式
  for i, cell in ipairs(cells) do
    local width = #cell
    local alignment = self:_parse_alignment(cell)

    table.insert(cols, {
      width = math.max(width, self.config.table.min_width),
      alignment = alignment,
    })
  end

  if #cols == 0 then
    return nil
  end

  return {
    line_num = line_num,
    cols = cols,
  }
end

---@private
---@param cell string
---@return obsidian.ui.table.Alignment
function Table:_parse_alignment(cell)
  if string.match(cell, "^%s*:-+%s*$") then
    return "left"
  elseif string.match(cell, "^%s*-+: %s*$") then
    return "right"
  elseif string.match(cell, "^%s*:-+: %s*$") then
    return "center"
  else
    return "default"
  end
end

---@private
---@param line string
---@param line_num integer
---@param delim_row obsidian.ui.table.DelimRow
---@return obsidian.ui.table.Row|?
function Table:_parse_row(line, line_num, delim_row)
  local cells = {}
  local cols = {}

  -- 分割单元格内容
  for cell in string.gmatch(line, "([^|]+)") do
    if cell ~= "" then
      table.insert(cells, vim.trim(cell))
    end
  end

  -- 如果列数不匹配，跳过此行
  if #cells ~= #delim_row.cols then
    return nil
  end

  -- 解析每列内容
  local start_col = 1
  for i, cell in ipairs(cells) do
    local text = vim.trim(cell)
    local width = self:_visual_width(text)

    table.insert(cols, {
      start_col = start_col,
      end_col = start_col + #cell,
      text = text,
      width = width,
    })
    start_col = start_col + #cell + 1
  end

  local is_header = (line_num < delim_row.line_num)

  return {
    line_num = line_num,
    is_header = is_header,
    cols = cols,
  }
end

---@private
---@param text string
---@return integer
function Table:_visual_width(text)
  -- 简单的视觉宽度计算（不考虑多字节字符）
  return #text
end

---@private
---@param rows obsidian.ui.table.Row[]
---@param delim_row obsidian.ui.table.DelimRow
function Table:_calculate_column_widths(rows, delim_row)
  -- 找出每列的最大宽度
  for _, row in ipairs(rows) do
    for i, col in ipairs(row.cols) do
      if delim_row.cols[i] then
        local current_width = delim_row.cols[i].width
        local content_width = col.width
        local padding = 2 * self.config.table.padding

        if self.config.table.cell == "padded" then
          content_width = content_width + padding
        elseif self.config.table.cell == "trimmed" then
          -- trimmed 模式会移除末尾空格
          local trimmed_text = col.text:gsub("%s+$", "")
          content_width = #trimmed_text
        end

        delim_row.cols[i].width = math.max(current_width, content_width, self.config.table.min_width)
      end
    end
  end
end

---@private
---@param delim_row obsidian.ui.table.DelimRow
function Table:_render_delimiter(delim_row)
  local border = self.config.table.border
  local indicator = self.config.table.alignment_indicator

  local parts = {}
  for i, col in ipairs(delim_row.cols) do
    local part = border[11]:rep(col.width)

    -- 添加对齐指示器
    if col.alignment ~= "default" and col.width >= 3 and indicator ~= "" then
      if col.alignment == "left" then
        part = indicator .. border[11]:rep(col.width - 1)
      elseif col.alignment == "right" then
        part = border[11]:rep(col.width - 1) .. indicator
      elseif col.alignment == "center" then
        part = indicator .. border[11]:rep(col.width - 2) .. indicator
      end
    end

    table.insert(parts, part)
  end

  local delimiter = border[4] .. table.concat(parts, border[5]) .. border[6]

  local bufnr = vim.api.nvim_get_current_buf()
  vim.api.nvim_buf_set_extmark(bufnr, self.ns_id, delim_row.line_num, 0, {
    virt_text = { { delimiter, self.config.table.head } },
    virt_text_pos = "overlay",
  })
end

---@private
---@param row obsidian.ui.table.Row
---@param delim_row obsidian.ui.table.DelimRow
function Table:_render_row(row, delim_row)
  local bufnr = vim.api.nvim_get_current_buf()
  local border = self.config.table.border
  local highlight = row.is_header and self.config.table.head or self.config.table.row

  if self.config.table.cell == "overlay" then
    -- 简单覆盖模式
    local rendered_text = row.text:gsub("|", border[10])
    vim.api.nvim_buf_set_extmark(bufnr, self.ns_id, row.line_num, 0, {
      virt_text = { { rendered_text, highlight } },
      virt_text_pos = "overlay",
    })
  elseif self.config.table.cell == "raw" then
    -- 只替换管道符
    local line = vim.api.nvim_buf_get_lines(bufnr, row.line_num, row.line_num + 1, false)[1]
    local _, count = string.gsub(line, "|", "")
    local pos = 1
    for i = 1, count do
      pos = string.find(line, "|", pos)
      if pos then
        vim.api.nvim_buf_set_extmark(bufnr, self.ns_id, row.line_num, pos - 1, {
          virt_text = { { border[10], highlight } },
          virt_text_pos = "overlay",
        })
        pos = pos + 1
      end
    end
  elseif self.config.table.cell == "padded" then
    -- 填充模式
    local parts = { border[10] }
    for i, col in ipairs(row.cols) do
      if delim_row.cols[i] then
        local content = col.text
        local target_width = delim_row.cols[i].width
        local padding = self.config.table.padding

        -- 添加左填充
        local left_pad = string.rep(" ", padding)
        content = left_pad .. content

        -- 添加右填充
        local right_pad = string.rep(" ", math.max(0, target_width - self:_visual_width(content)))
        content = content .. right_pad

        table.insert(parts, content)
        table.insert(parts, border[10])
      end
    end

    local rendered_line = table.concat(parts, "")
    vim.api.nvim_buf_set_extmark(bufnr, self.ns_id, row.line_num, 0, {
      virt_text = { { rendered_line, highlight } },
      virt_text_pos = "overlay",
    })
  end
end

---@private
---@param data obsidian.ui.table.Data
function Table:_render_border(data)
  if not self.config.table.border_enabled then
    return
  end

  local border = self.config.table.border
  local first_row = data.rows[1]
  local last_row = data.rows[#data.rows]

  if not first_row then
    return
  end

  -- 构建边框部分
  local parts = {}
  for _, col in ipairs(data.delim_row.cols) do
    table.insert(parts, border[11]:rep(col.width))
  end

  local bufnr = vim.api.nvim_get_current_buf()

  -- 顶部边框
  if first_row then
    local top_border = border[1] .. table.concat(parts, border[2]) .. border[3]
    vim.api.nvim_buf_set_extmark(bufnr, self.ns_id, first_row.line_num, 0, {
      virt_lines = { { { top_border, self.config.table.head } } },
      virt_lines_above = true,
    })
  end

  -- 底部边框
  if last_row and #data.rows > 1 then
    local bottom_border = border[7] .. table.concat(parts, border[8]) .. border[9]
    vim.api.nvim_buf_set_extmark(bufnr, self.ns_id, last_row.line_num, 0, {
      virt_lines = { { { bottom_border, self.config.table.row } } },
      virt_lines_above = false,
    })
  end
end

---@public
---@param bufnr integer
function Table:render(bufnr)
  if not self.config.table.enabled then
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

  -- 解析表格
  local data = self:_parse_table(bufnr)
  if not data then
    return
  end

  -- 渲染分隔符
  if not self.config.skip_cursor_line or data.delim_row.line_num ~= current_line then
    self:_render_delimiter(data.delim_row)
  end

  -- 渲染行
  for _, row in ipairs(data.rows) do
    -- 检查是否启用跳过光标行功能
    if not self.config.skip_cursor_line or row.line_num ~= current_line then
      self:_render_row(row, data.delim_row)
    end
  end

  -- 渲染边框（边框不受光标影响）
  self:_render_border(data)
end

---@public
---@param bufnr integer
function Table:clear(bufnr)
  vim.api.nvim_buf_clear_namespace(bufnr, self.ns_id, 0, -1)
end

return Table