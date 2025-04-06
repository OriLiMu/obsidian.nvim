local M = {}

---@param client obsidian.Client
---@param _opts table
M.open_recent_files_window = function(client, _opts)
  client.recent_files.open_recent_files_window(client)
end

return M
