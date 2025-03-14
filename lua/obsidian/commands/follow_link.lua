---@param client obsidian.Client
return function(client, data)
  local opts = {}
  if data.args and string.len(data.args) > 0 then
    local args = vim.split(data.args, " ", { trimempty = true })
    if #args >= 1 then
      opts.open_strategy = args[1]
    end
    if #args >= 2 then
      -- in case of providing note_location, directly use it instead of parsing the link under the cursor
      local note_location = args[2]
      -- if note_location is not surrounded by [[]], add them
      if not note_location:match "^%[%[.*%]%]$" then
        note_location = "[[" .. note_location .. "]]"
      end
      client:follow_link_async(note_location, opts)
      return
    end
  end

  client:follow_link_async(nil, opts)
end
