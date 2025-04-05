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
      -- Store current window and buffer info before split
      local original_win = vim.api.nvim_get_current_win()
      local original_buf = vim.api.nvim_win_get_buf(original_win)
      local original_name = vim.api.nvim_buf_get_name(original_buf)
      log.info("Original window ID: %d, buffer: %d, file: %s", original_win, original_buf, original_name)

      -- Create a new window first
      vim.cmd "vsplit"
      local new_win = vim.api.nvim_get_current_win()
      log.info("Created new window ID: %d", new_win)

      -- Open note in the new window
      client:open_note(notes[1], {
        open_strategy = "current",
      })
      log.info "Note opened in current window"

      -- Get the new buffer info after note is opened
      local new_buf = vim.api.nvim_win_get_buf(new_win)
      local new_name = vim.api.nvim_buf_get_name(new_buf)
      log.info("New window ID: %d, buffer: %d, file: %s", new_win, new_buf, new_name)

      -- Set the keymap if files are different
      if new_name ~= original_name then
        log.info("Different files detected, setting up 'q' keymap for window %d", new_win)
        vim.keymap.set("n", "q", function()
          log.info("'q' pressed, attempting to close window %d", new_win)
          -- Close the window
          if vim.api.nvim_win_is_valid(new_win) then
            vim.api.nvim_win_close(new_win, false)
            log.info "Window closed successfully"
          else
            log.warn("Window %d is no longer valid", new_win)
          end
        end, { buffer = new_buf, desc = "Close split window" })
        log.info("Keymap set successfully for buffer %d", new_buf)
      else
        log.warn "Same file detected in both windows, skipping keymap"
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
