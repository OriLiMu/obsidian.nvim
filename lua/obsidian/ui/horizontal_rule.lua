local util = require "obsidian.util"

---@class obsidian.ui.HorizontalRule
---@field client obsidian.Client
---@field config obsidian.Config
---@field ns_id integer
local HorizontalRule = {}

HorizontalRule.__index = HorizontalRule

---@param client obsidian.Client
---@param config obsidian.Config
---@return obsidian.ui.HorizontalRule
function HorizontalRule.new(client, config)
  local self = setmetatable({}, HorizontalRule)
  self.client = client
  self.config = config
  self.ns_id = vim.api.nvim_create_namespace("obsidian_horizontal_rule")
  return self
end

---@class obsidian.ui.horizontal_rule.Data
---@field line_num integer
---@field char string
---@field original_length integer
---@field highlight string

---@private
---@param bufnr integer
---@return obsidian.ui.horizontal_rule.Data[]
function HorizontalRule:_parse_horizontal_rules(bufnr)
  local rules = {}
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local in_frontmatter = false
  local frontmatter_end_line = -1

  -- Check for YAML frontmatter at the beginning of the file
  if #lines > 0 and string.match(lines[1], "^%s*%-%-%-") then
    in_frontmatter = true
    -- Find the end of frontmatter
    for i = 2, math.min(#lines, 20) do
      if string.match(lines[i], "^%s*%-%-%-") then
        frontmatter_end_line = i
        break
      end
    end
  end

  for line_num, line in ipairs(lines) do
    local lnum = line_num - 1 -- 0-based indexing

    -- Skip frontmatter section
    if in_frontmatter and lnum <= frontmatter_end_line then
      -- Check if this is the closing ---
      if lnum == frontmatter_end_line then
        in_frontmatter = false
      end
      goto continue
    end

    -- Match horizontal rules: 3 or more of the same character (-, *, _)
    -- Only match if the line contains only these characters and optional whitespace
    local match_char = string.match(line, "^%s*([%-%*%_])%1%1[%-%*%_]*%s*$")

    if match_char then
      -- Count the actual number of characters
      local stripped_line = string.gsub(line, "%s+", "")
      local count = #stripped_line

      local highlight = self:_get_highlight(match_char)

      table.insert(rules, {
        line_num = lnum,
        char = match_char,
        original_length = count,
        highlight = highlight,
      })
    end

    ::continue::
  end

  return rules
end

---@private
---@param char string
---@return string
function HorizontalRule:_get_highlight(char)
  local highlights = self.config.horizontal_rule.highlights
  if type(highlights) == "table" then
    return highlights[char] or "ObsidianHorizontalRule"
  else
    return "ObsidianHorizontalRule"
  end
end

---@private
---@param rule obsidian.ui.horizontal_rule.Data
function HorizontalRule:_render_rule(rule)
  local bufnr = vim.api.nvim_get_current_buf()
  local style = self.config.horizontal_rule.style or "full"
  local render_char = self.config.horizontal_rule.char or rule.char
  local width = self.config.horizontal_rule.width or vim.api.nvim_win_get_width(0)

  local rule_text = ""

  if style == "full" then
    -- Render across full window width
    rule_text = string.rep(render_char, width)
  elseif style == "original" then
    -- Keep original length
    rule_text = string.rep(render_char, rule.original_length)
  elseif style == "custom" then
    -- Use custom character with original length
    rule_text = string.rep(render_char, rule.original_length)
  elseif style == "block" then
    -- Fixed width (default 80)
    local block_width = self.config.horizontal_rule.block_width or 80
    rule_text = string.rep(render_char, math.min(block_width, width))
  end

  -- Apply padding if configured
  if self.config.horizontal_rule.padding then
    local padding = string.rep(" ", self.config.horizontal_rule.padding)
    rule_text = padding .. rule_text .. padding
  end

  -- Render using extmark overlay
  vim.api.nvim_buf_set_extmark(bufnr, self.ns_id, rule.line_num, 0, {
    virt_text = { { rule_text, rule.highlight } },
    virt_text_pos = "overlay",
  })
end

---@public
---@param bufnr integer
function HorizontalRule:render(bufnr)
  if not self.config.horizontal_rule.enabled then
    return
  end

  -- Get current cursor position
  local current_line = 0
  local ok, cursor = pcall(vim.api.nvim_win_get_cursor, 0)
  if ok and cursor then
    current_line = cursor[1] - 1 -- Convert to 0-based
  end

  -- Clear previous rendering
  self:clear(bufnr)

  -- Parse horizontal rules
  local rules = self:_parse_horizontal_rules(bufnr)

  -- Render each rule
  for _, rule in ipairs(rules) do
    -- Check if skip_cursor_line is enabled
    if not self.config.skip_cursor_line or rule.line_num ~= current_line then
      self:_render_rule(rule)
    end
  end
end

---@public
---@param bufnr integer
function HorizontalRule:clear(bufnr)
  vim.api.nvim_buf_clear_namespace(bufnr, self.ns_id, 0, -1)
end

return HorizontalRule
