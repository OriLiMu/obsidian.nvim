local toggle_checkbox = require("obsidian.util").toggle_checkbox

---@param client obsidian.Client
return function(client)
  local log = require "obsidian.log"
  log.info "=== ObsidianToggleCheckbox 命令开始执行 ==="

  local checkboxes = vim.tbl_keys(client.opts.ui.checkboxes)
  log.info("原始复选框键: %s", vim.inspect(checkboxes))

  -- If checkboxes is empty, use default values
  if #checkboxes == 0 then
    log.info "复选框配置为空，使用默认值"
    checkboxes = { " ", "~", "!", ">", "x" }
  end

  table.sort(checkboxes, function(a, b)
    return (client.opts.ui.checkboxes[a] and client.opts.ui.checkboxes[a].order or 1000)
      < (client.opts.ui.checkboxes[b] and client.opts.ui.checkboxes[b].order or 1000)
  end)

  -- Simple sort by order if using default checkboxes
  if #vim.tbl_keys(client.opts.ui.checkboxes) == 0 then
    -- Default order: " ", "~", "!", ">", "x"
    local default_order = { [" "] = 1, ["~"] = 2, ["!"] = 3, [">"] = 4, ["x"] = 5 }
    table.sort(checkboxes, function(a, b)
      return (default_order[a] or 1000) < (default_order[b] or 1000)
    end)
  end

  log.info("排序后复选框键: %s", vim.inspect(checkboxes))

  log.info "调用 toggle_checkbox 函数"
  toggle_checkbox(checkboxes)

  log.info "=== ObsidianToggleCheckbox 命令执行完毕 ==="
end
