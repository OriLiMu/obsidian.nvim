local M = {}

---@param client obsidian.Client
---@param _opts table
M.close_recent_files = function(client, _opts)
  client.recent_files.close_recent_files_window()
end

return M
