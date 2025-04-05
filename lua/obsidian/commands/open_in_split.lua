local util = require "obsidian.util"
local log = require "obsidian.log"

-- Open note in right split window
local function open_in_split()
  local client = require("obsidian").get_client()
  if not client then
    log.err "Failed to get Obsidian client"
    return
  end

  -- Check if cursor is on a markdown link
  if util.cursor_on_markdown_link(nil, nil, true) then
    local link_location, link_name, link_type = util.parse_cursor_link()
    log.info("link_location: %s, link_name: %s, link_type: %s", link_location, link_name, link_type)

    -- Check if file exists
    local notes = { client:resolve_note(link_location) }
    if #notes > 0 then
      -- Open note in right split
      client:open_note(notes[1], {
        open_strategy = "vsplit",
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
