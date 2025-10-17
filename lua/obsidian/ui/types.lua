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
---@field custom table<string, obsidian.ui.heading.CustomStyle>

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