local toggle_checkbox = require("obsidian.util").toggle_checkbox

---@param client obsidian.Client
return function(client)
  -- Only use empty and x states
  toggle_checkbox { " ", "x" }
end
