local util = require "obsidian.util"
local log = require "obsidian.log"
local Path = require "obsidian.path"

---@param client obsidian.Client
return function(client, data)
  ---@type obsidian.Note
  local note
  if data.args:len() > 0 then
    note = client:create_note { title = data.args, no_write = true }
  else
    -- Check for a note reference under the cursor
    local cursor_link, link_name, _ = util.parse_cursor_link()
    if cursor_link and link_name then
      note = client:create_note { title = link_name, no_write = true }
    else
      local title = util.input("Enter title or path (optional): ", { completion = "file" })
      if not title then
        log.warn "Aborted"
        return
      elseif title == "" then
        title = nil
      end
      note = client:create_note { title = title, no_write = true }
    end
  end

  -- Get all subdirectories under vault root recursively
  local vault_root = client:vault_root()
  local subdirs = {}
  local function scan_dir(dir)
    for entry in vim.fs.dir(tostring(dir)) do
      -- Skip .obsidian directory
      if entry ~= ".obsidian" then
        local full_path = dir / entry
        if vim.fn.isdirectory(tostring(full_path)) == 1 then
          local rel_path = tostring(full_path:relative_to(vault_root))
          table.insert(subdirs, rel_path)
          scan_dir(full_path) -- Recursively scan subdirectories
        end
      end
    end
  end
  scan_dir(vault_root)

  -- Use picker to select target directory
  local picker = client:picker()
  if not picker then
    log.err "No picker configured"
    return
  end

  picker:pick(subdirs, {
    prompt_title = "Select target directory",
    callback = function(selected_dir)
      if not selected_dir then
        log.warn "No directory selected, aborting"
        return
      end

      -- Create note in selected directory
      local target_dir = vault_root / selected_dir
      -- Use the title as the filename and ID, removing any digits at the start
      local clean_id = note.title or os.date "%Y%m%d%H%M%S"
      clean_id = clean_id:gsub("^%d+%-", "")
      local note_path = target_dir / Path.new(clean_id):with_suffix ".md"

      -- Check if file already exists
      if note_path:exists() then
        local relative_path = client:vault_relative_path(note_path) or tostring(note_path)
        log.warn("Note '%s' already exists. Creation cancelled.", relative_path)
        return
      end

      note.id = clean_id
      note.path = note_path
      note.aliases = {} -- Set empty aliases

      -- Open the note in a new buffer
      client:open_note(note, { sync = true })
      client:write_note_to_buffer(note)
    end,
  })
end
