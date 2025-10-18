---@class obsidian.ui.heading.Config
---@field enabled boolean
---@field icons obsidian.ui.heading.Icons
---@field position obsidian.ui.heading.Position
---@field foregrounds string[]|boolean
---@field backgrounds string[]|boolean
---@field width obsidian.ui.heading.Width
---@field border boolean
---@field above string
---@field below string
---@field indent boolean
---@field indent_levels table<integer, integer>|boolean
---@field custom table<string, obsidian.ui.heading.CustomStyle>

---@class obsidian.ui.table.Config
---@field enabled boolean
---@field border string[]
---@field border_enabled boolean
---@field cell obsidian.ui.table.Cell
---@field padding integer
---@field min_width integer
---@field alignment_indicator string
---@field head string
---@field row string
---@field filler string

---@alias obsidian.ui.table.Cell
---| "overlay"
---| "raw"
---| "padded"
---| "trimmed"

---@enum obsidian.ui.table.Alignment
local Alignment = {
  left = 'left',
  right = 'right',
  center = 'center',
  default = 'default',
}

---@class obsidian.ui.heading.CustomStyle
---@field pattern string
---@field icon? string
---@field foreground? string
---@field background? string

---@alias obsidian.ui.heading.Icons
---| string[]
---| fun(ctx: { level: integer }): string

---@alias obsidian.ui.heading.Position
---| "overlay"
---| "inline"
---| "right"

---@alias obsidian.ui.heading.Width
---| "full"
---| "block"