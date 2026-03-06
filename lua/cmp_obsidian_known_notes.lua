local abc = require "obsidian.abc"
local obsidian = require "obsidian"
local util = require "obsidian.util"

---@class cmp_obsidian_known_notes.Source : obsidian.ABC
---@field _request_id integer
local source = abc.new_class()

source.new = function()
  local self = source.init()
  self._request_id = 0
  return self
end

source.get_trigger_characters = function()
  return {}
end

source.get_keyword_pattern = function()
  return [=[[^[:space:]\[\]\(\){}<>"'`|,.;:!?/\\]\+]=]
end

---@param request table
---@return string|?, integer|?, integer|?
source.find_current_term = function(request)
  local before = request.context.cursor_before_line
  if before == nil or string.len(before) == 0 then
    return nil
  end

  local start_idx = string.find(before, "[^%s%[%]%(%){}<>'\"`|,.;:!?/\\]+$")
  if start_idx == nil then
    return nil
  end

  local term = string.sub(before, start_idx)
  if string.len(term) == 0 or util.is_whitespace(term) then
    return nil
  end

  local cursor_col = request.context.cursor.col
  local insert_start = cursor_col - 1 - #term
  local insert_end = cursor_col - 1
  return term, insert_start, insert_end
end

---@param request table
---@param label string
---@param insert_start integer
---@param insert_end integer
---@return table
source.build_item = function(request, label, insert_start, insert_end)
  local new_text = string.format("[[%s]]", label)
  return {
    label = new_text,
    kind = 18,
    sortText = label,
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
    for _, match in ipairs(matches) do
      items[#items + 1] = source.build_item(request, match.label, insert_start, insert_end)
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
