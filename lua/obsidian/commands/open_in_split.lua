local util = require "obsidian.util"
local log = require "obsidian.log"

-- Open note in right split window
local function open_in_split(client)
  if util.cursor_on_markdown_link(nil, nil, true) then
    local link_location = util.parse_cursor_link()
    local notes = { client:resolve_note(link_location) }

    if #notes > 0 then
      -- Create a new window first
      vim.cmd "vsplit"
      -- Open note in the new window
      client:open_note(notes[1], {
        open_strategy = "current",
      })
    else
      vim.notify("Note not found: " .. (link_location or "empty link"), vim.log.levels.WARN)
    end
  else
    vim.notify("Cursor is not on a note link", vim.log.levels.WARN)
  end
end

return {
  open_in_split = open_in_split,
}
