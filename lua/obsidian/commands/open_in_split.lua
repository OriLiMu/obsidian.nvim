local util = require "obsidian.util"
local log = require "obsidian.log"

-- Open note in right split window
local function open_in_split(client)
  log.info "Starting open_in_split function"
  -- Check if cursor is on a markdown link
  log.info "Checking if cursor is on markdown link"
  if util.cursor_on_markdown_link(nil, nil, true) then
    local link_location, link_name, link_type = util.parse_cursor_link()
    log.info("Link found - location: %s, name: %s, type: %s", link_location, link_name, link_type)

    -- Check if file exists
    log.info("Resolving note: %s", link_location)
    local notes = { client:resolve_note(link_location) }
    log.info("Number of notes found: %d", #notes)

    if #notes > 0 then
      -- Open note in right split
      local current_win = vim.api.nvim_get_current_win()
      log.info("Current window ID: %d", current_win)

      client:open_note(notes[1], {
        open_strategy = "vsplit",
      })
      log.info "Note opened in vsplit"

      -- Get the newly created window
      local new_win = vim.api.nvim_get_current_win()
      log.info("New window ID: %d", new_win)

      -- Only set the keymap if we're in a different window
      if new_win ~= current_win then
        log.info("Setting up 'q' keymap for window %d", new_win)
        -- Set local keymap for this buffer
        local current_buf = vim.api.nvim_get_current_buf()
        vim.keymap.set("n", "q", function()
          log.info("'q' pressed, attempting to close window %d", new_win)
          -- Close the window
          if vim.api.nvim_win_is_valid(new_win) then
            vim.api.nvim_win_close(new_win, false)
            log.info "Window closed successfully"
          else
            log.warn("Window %d is no longer valid", new_win)
          end
        end, { buffer = current_buf, desc = "Close split window" })
        log.info("Keymap set successfully for buffer %d", current_buf)
      else
        log.warn "New window is same as current window, skipping keymap"
      end
    else
      log.warn("Note not found: %s", link_location or "empty link")
      vim.notify("Note not found: " .. (link_location or "empty link"), vim.log.levels.WARN)
    end
  else
    log.warn "Cursor is not on a note link"
    vim.notify("Cursor is not on a note link", vim.log.levels.WARN)
  end
  log.info "Finished open_in_split function"
end

return {
  open_in_split = open_in_split,
}
