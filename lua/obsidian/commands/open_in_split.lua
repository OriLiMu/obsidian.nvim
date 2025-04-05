local util = require "obsidian.util"
local log = require "obsidian.log"

-- Open note in right split window
local function open_in_split(client)
  -- Check if cursor is on a markdown link
  if util.cursor_on_markdown_link(nil, nil, true) then
    local link_location, link_name, link_type = util.parse_cursor_link()
    log.info("link_location: %s, link_name: %s, link_type: %s", link_location, link_name, link_type)

    -- Check if file exists
    local notes = { client:resolve_note(link_location) }
    if #notes > 0 then
      -- Open note in right split
      local current_win = vim.api.nvim_get_current_win()
      client:open_note(notes[1], {
        open_strategy = "vsplit",
      })
      -- Get the newly created window
      local new_win = vim.api.nvim_get_current_win()
      -- Only set the keymap if we're in a different window
      if new_win ~= current_win then
        -- Set local keymap for this buffer
        vim.keymap.set("n", "q", function()
          -- Close the window
          vim.api.nvim_win_close(new_win, false)
        end, { buffer = true, desc = "Close split window" })
      end
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
