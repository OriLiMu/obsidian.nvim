local M = {}

---@param client obsidian.Client
---@param _opts table
M.toggle_recent_files = function(client, _opts)
  client.recent_files.toggle_recent_files_window(client)
end

return M
