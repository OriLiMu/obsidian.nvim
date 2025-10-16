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

  -- Directly create note using the path determined by parse_title_id_path
  -- The logic now automatically:
  -- - Creates in current directory if inside vault
  -- - Creates in vault_root/Ori if outside vault

  -- Check if file already exists
  if note.path:exists() then
    local relative_path = client:vault_relative_path(note.path) or tostring(note.path)
    log.warn("Note '%s' already exists. Creation cancelled.", relative_path)
    return
  end

  -- Reset aliases since we're creating a fresh note
  note.aliases = {}

  -- Open the note in a new buffer
  client:open_note(note, { sync = true })
  client:write_note_to_buffer(note)
end
