local abc = require "obsidian.abc"
local obsidian = require "obsidian"
local util = require "obsidian.util"

-- 与 cmp 的关键词匹配保持同一套字符定义，避免 '-' 被截断。
local TERM_PATTERN_LUA = "([%w_%-]+)$"
local TERM_PATTERN_VIM = [[[-0-9A-Za-z_]\+]]

---@class cmp_obsidian_known_notes.Source : obsidian.ABC
---@field _request_id integer
local source = abc.new_class()

source.new = function()
  local self = source.init()
  self._request_id = 0
  return self
end

source.get_trigger_characters = function()
  -- 显式把 '-' 作为触发字符，保证输入如 'note-' 时会重新触发补全。
  return { "-" }
end

source.get_keyword_pattern = function()
  return TERM_PATTERN_VIM
end

---@param request table
---@return string|?, integer|?, integer|?
source.find_current_term = function(request)
  local before = request.context.cursor_before_line
  if before == nil or string.len(before) == 0 then
    return nil
  end

  local term = string.match(before, TERM_PATTERN_LUA)
  if term == nil then
    return nil
  end

  if string.len(term) == 0 or util.is_whitespace(term) then
    return nil
  end

  local cursor_col = request.context.cursor.col
  local insert_start = cursor_col - 1 - #term
  local insert_end = cursor_col - 1
  return term, insert_start, insert_end
end

---@param request table
---@param menu_label string
---@param insert_label string
---@param insert_start integer
---@param insert_end integer
---@return table
source.build_item = function(request, menu_label, insert_label, insert_start, insert_end)
  local new_text = string.format("[[%s]]", insert_label)
  return {
    label = string.format("[[%s]]", menu_label),
    kind = 18,
    sortText = menu_label,
    documentation = {
      kind = "markdown",
      value = string.format("`%s`", new_text),
    },
    textEdit = {
      newText = new_text,
      range = {
        start = {
          line = request.context.cursor.row - 1,
          character = insert_start,
        },
        ["end"] = {
          line = request.context.cursor.row - 1,
          character = insert_end,
        },
      },
    },
  }
end

---@param path string|?
---@return string|?
source.get_filename_stem = function(path)
  if type(path) ~= "string" or string.len(path) == 0 then
    return nil
  end

  local filename = vim.fs.basename(path)
  if filename == nil or string.len(filename) == 0 then
    return nil
  end

  local stem = vim.fn.fnamemodify(filename, ":r")
  if stem == nil or string.len(stem) == 0 then
    return nil
  end

  return stem
end

source.complete = function(self, request, callback)
  local bufnr = request.context.bufnr
  if vim.bo[bufnr].filetype ~= "markdown" then
    callback { isIncomplete = true }
    return
  end

  local client = assert(obsidian.get_client())
  local index = client.known_notes_index
  if index == nil or not index:is_enabled() then
    callback { isIncomplete = true }
    return
  end

  local search, insert_start, insert_end = source.find_current_term(request)
  if search == nil or insert_start == nil or insert_end == nil then
    callback { isIncomplete = true }
    return
  end

  if #search < index:min_chars() then
    callback { isIncomplete = true }
    return
  end

  self._request_id = self._request_id + 1
  local current_id = self._request_id
  vim.schedule(function()
    if current_id ~= self._request_id then
      callback { isIncomplete = true }
      return
    end

    local matches = index:query(search)
    local items = {}
    local alias_insert_filename = client.opts.completion.known_notes.alias_insert_filename
    for _, match in ipairs(matches) do
      local insert_label = match.label
      if alias_insert_filename and match.kind == "alias" then
        local stem = source.get_filename_stem(match.path)
        if stem ~= nil then
          insert_label = stem
        end
      end

      items[#items + 1] = source.build_item(request, match.label, insert_label, insert_start, insert_end)
    end

    if current_id ~= self._request_id then
      callback { isIncomplete = true }
      return
    end

    callback {
      items = items,
      isIncomplete = true,
    }
  end)
end

return source
