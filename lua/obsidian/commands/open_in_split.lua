local util = require "obsidian.util"
local log = require "obsidian.log"

-- Store recently opened markdown files
local recent_files = {}
local max_recent_files = 5

-- Add file to recent files list
local function add_to_recent_files(file_path)
  -- Remove the file if it already exists in the list
  for i, path in ipairs(recent_files) do
    if path == file_path then
      table.remove(recent_files, i)
      break
    end
  end
  -- Add to the beginning of the list
  table.insert(recent_files, 1, file_path)
  -- Keep only the last max_recent_files
  while #recent_files > max_recent_files do
    table.remove(recent_files)
  end
end

-- Show recent files in a split window
local function show_recent_files()
  -- Calculate window width (30% of total)
  local total_width = vim.o.columns
  local width = math.floor(total_width * 0.3)

  -- Create a new buffer for recent files
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_option(buf, "buftype", "nofile")
  vim.api.nvim_buf_set_option(buf, "bufhidden", "wipe")
  vim.api.nvim_buf_set_option(buf, "swapfile", false)

  -- Create content for the buffer
  local lines = { "Recent Files:" }
  for _, file in ipairs(recent_files) do
    table.insert(lines, "- " .. vim.fn.fnamemodify(file, ":t"))
  end

  -- Set buffer content
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)

  -- Open the window on the right
  vim.api.nvim_command("botright vertical " .. width .. "vsplit")
  local win = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(win, buf)

  -- Set window options
  vim.api.nvim_win_set_option(win, "number", false)
  vim.api.nvim_win_set_option(win, "relativenumber", false)
  vim.api.nvim_win_set_option(win, "wrap", false)

  -- Make the window non-modifiable
  vim.api.nvim_buf_set_option(buf, "modifiable", false)

  -- Add keymap to close the window
  vim.api.nvim_buf_set_keymap(buf, "n", "q", ":close<CR>", { noremap = true, silent = true })
end

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

-- Setup function to create autocmd
local function setup()
  -- Create autocmd group
  local group = vim.api.nvim_create_augroup("ObsidianRecent", { clear = true })

  -- Create autocmd for markdown files
  vim.api.nvim_create_autocmd("BufEnter", {
    pattern = "*.md",
    group = group,
    callback = function()
      local file_path = vim.api.nvim_buf_get_name(0)
      add_to_recent_files(file_path)
      show_recent_files()
    end,
  })
end

return {
  open_in_split = open_in_split,
  setup = setup,
}
