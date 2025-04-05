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
      -- Store current window ID before split
      local original_win = vim.api.nvim_get_current_win()
      log.info("Original window ID: %d", original_win)

      -- Create a new window first
      vim.cmd "vsplit"
      local new_win = vim.api.nvim_get_current_win()
      log.info("Created new window ID: %d", new_win)

      -- Open note in the new window
      client:open_note(notes[1], {
        open_strategy = "current",
      })
      log.info "Note opened in current window"

      -- Set the keymap if windows are different
      if new_win ~= original_win then
        log.info("Different windows detected, setting up 'q' keymap for window %d", new_win)

        -- Get the current buffer after opening the note
        local new_buf = vim.api.nvim_get_current_buf()
        log.info("Setting keymap for buffer %d in window %d", new_buf, new_win)

        -- Create a command to close the window
        local cmd_name = "ObsidianCloseSplit" .. new_win
        vim.api.nvim_create_user_command(cmd_name, function()
          log.info("Command executed for window %d", new_win)
          if vim.api.nvim_win_is_valid(new_win) then
            vim.api.nvim_win_close(new_win, false)
            log.info("Window %d closed successfully", new_win)
          else
            log.warn("Window %d is no longer valid", new_win)
          end
        end, {})

        -- Set the keymap to execute the command
        local opts = {
          noremap = true,
          silent = true,
          nowait = true,
        }
        vim.api.nvim_buf_set_keymap(new_buf, "n", "q", string.format("<cmd>%s<CR>", cmd_name), opts)
        log.info("Keymap set to execute command: %s", cmd_name)

        -- Verify the keymap was set
        local maps = vim.api.nvim_buf_get_keymap(new_buf, "n")
        local found = false
        for _, map in ipairs(maps) do
          if map.lhs == "q" then
            found = true
            log.info("Found keymap: lhs=%s, rhs=%s", map.lhs, map.rhs)
            break
          end
        end
        log.info("Keymap verification - found: %s", found)

        if found then
          log.info("Keymap set successfully for buffer %d", new_buf)
        else
          log.warn("Failed to set keymap for buffer %d", new_buf)
        end
      else
        log.warn "Same window detected, skipping keymap"
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
