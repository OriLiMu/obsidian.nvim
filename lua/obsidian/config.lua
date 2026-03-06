local log = require "obsidian.log"
local util = require "obsidian.util"

local config = {}

---@class obsidian.config.AITranslateOpts
---@field enabled boolean Whether to enable auto-translate aliases
---@field api_url string API endpoint URL
---@field api_key string API key for authentication
---@field model string Model to use for translation
---@field timeout integer Request timeout in milliseconds

---@class obsidian.config.ClientOpts
---@field dir string|?
---@field workspaces obsidian.workspace.WorkspaceSpec[]|?
---@field log_level integer
---@field notes_subdir string|?
---@field templates obsidian.config.TemplateOpts
---@field new_notes_location obsidian.config.NewNotesLocation
---@field note_id_func (fun(title: string|?): string)|?
---@field note_path_func (fun(spec: { id: string, dir: obsidian.Path, title: string|? }): string|obsidian.Path)|?
---@field wiki_link_func (fun(opts: {path: string, label: string, id: string|?}): string)
---@field markdown_link_func (fun(opts: {path: string, label: string, id: string|?}): string)
---@field preferred_link_style obsidian.config.LinkStyle
---@field follow_url_func fun(url: string)|?
---@field follow_img_func fun(img: string)|?
---@field note_frontmatter_func (fun(note: obsidian.Note): table)|?
---@field disable_frontmatter (fun(fname: string?): boolean)|boolean|?
---@field completion obsidian.config.CompletionOpts
---@field mappings obsidian.config.MappingOpts
---@field picker obsidian.config.PickerOpts
---@field daily_notes obsidian.config.DailyNotesOpts
---@field use_advanced_uri boolean|?
---@field open_app_foreground boolean|?
---@field sort_by obsidian.config.SortBy|?
---@field sort_reversed boolean|?
---@field search_max_lines integer
---@field open_notes_in obsidian.config.OpenStrategy
---@field ui obsidian.config.UIOpts | table<string, any>
---@field attachments obsidian.config.AttachmentsOpts
---@field callbacks obsidian.config.CallbackConfig
---@field recent_files obsidian.config.RecentFilesOpts
---@field ai_translate obsidian.config.AITranslateOpts
config.ClientOpts = {}

--- Get defaults.
---
---@return obsidian.config.ClientOpts
config.ClientOpts.default = function()
  return {
    dir = nil,
    workspaces = {},
    log_level = vim.log.levels.INFO,
    notes_subdir = nil,
    new_notes_location = config.NewNotesLocation.current_dir,
    templates = config.TemplateOpts.default(),
    note_id_func = nil,
    wiki_link_func = util.wiki_link_id_prefix,
    markdown_link_func = util.markdown_link,
    preferred_link_style = config.LinkStyle.wiki,
    follow_url_func = nil,
    note_frontmatter_func = nil,
    disable_frontmatter = false,
    completion = config.CompletionOpts.default(),
    mappings = config.MappingOpts.default(),
    picker = config.PickerOpts.default(),
    daily_notes = config.DailyNotesOpts.default(),
    use_advanced_uri = nil,
    open_app_foreground = false,
    sort_by = "modified",
    sort_reversed = true,
    search_max_lines = 1000,
    open_notes_in = "current",
    ui = config.UIOpts.default(),
    attachments = config.AttachmentsOpts.default(),
    callbacks = config.CallbackConfig.default(),
    recent_files = config.RecentFilesOpts.default(),
    ai_translate = {
      enabled = false,
      api_url = "https://open.bigmodel.cn/api/coding/paas/v4/chat/completions",
      api_key = "",
      model = "glm-4.5-flash",
      timeout = 10000,
    },
  }
end

local tbl_override = function(defaults, overrides)
  local out = vim.tbl_extend("force", defaults, overrides)
  for k, v in pairs(out) do
    if v == vim.NIL then
      out[k] = nil
    end
  end
  return out
end

--- Normalize options.
---
---@param opts table<string, any>
---@param defaults obsidian.config.ClientOpts|?
---
---@return obsidian.config.ClientOpts
config.ClientOpts.normalize = function(opts, defaults)
  if not defaults then
    defaults = config.ClientOpts.default()
  end

  -------------------------------------------------------------------------------------
  -- Rename old fields for backwards compatibility and warn about deprecated fields. --
  -------------------------------------------------------------------------------------

  if opts.ui and opts.ui.tick then
    opts.ui.update_debounce = opts.ui.tick
    opts.ui.tick = nil
  end

  if not opts.picker then
    opts.picker = {}
    if opts.finder then
      opts.picker.name = opts.finder
      opts.finder = nil
    end
    if opts.finder_mappings then
      opts.picker.note_mappings = opts.finder_mappings
      opts.finder_mappings = nil
    end
    if opts.picker.mappings and not opts.picker.note_mappings then
      opts.picker.note_mappings = opts.picker.mappings
      opts.picker.mappings = nil
    end
  end

  if opts.wiki_link_func == nil and opts.completion ~= nil then
    local warn = false

    if opts.completion.prepend_note_id then
      opts.wiki_link_func = util.wiki_link_id_prefix
      opts.completion.prepend_note_id = nil
      warn = true
    elseif opts.completion.prepend_note_path then
      opts.wiki_link_func = util.wiki_link_path_prefix
      opts.completion.prepend_note_path = nil
      warn = true
    elseif opts.completion.use_path_only then
      opts.wiki_link_func = util.wiki_link_path_only
      opts.completion.use_path_only = nil
      warn = true
    end

    if warn then
      log.warn_once(
        "The config options 'completion.prepend_note_id', 'completion.prepend_note_path', and 'completion.use_path_only' "
          .. "are deprecated. Please use 'wiki_link_func' instead.\n"
          .. "See https://github.com/epwalsh/obsidian.nvim/pull/406"
      )
    end
  end

  if opts.wiki_link_func == "prepend_note_id" then
    opts.wiki_link_func = util.wiki_link_id_prefix
  elseif opts.wiki_link_func == "prepend_note_path" then
    opts.wiki_link_func = util.wiki_link_path_prefix
  elseif opts.wiki_link_func == "use_path_only" then
    opts.wiki_link_func = util.wiki_link_path_only
  elseif opts.wiki_link_func == "use_alias_only" then
    opts.wiki_link_func = util.wiki_link_alias_only
  elseif type(opts.wiki_link_func) == "string" then
    error(string.format("invalid option '%s' for 'wiki_link_func'", opts.wiki_link_func))
  end

  if opts.completion ~= nil and opts.completion.preferred_link_style ~= nil then
    opts.preferred_link_style = opts.completion.preferred_link_style
    opts.completion.preferred_link_style = nil
    log.warn_once(
      "The config option 'completion.preferred_link_style' is deprecated, please use the top-level "
        .. "'preferred_link_style' instead."
    )
  end

  if opts.completion ~= nil and opts.completion.new_notes_location ~= nil then
    opts.new_notes_location = opts.completion.new_notes_location
    opts.completion.new_notes_location = nil
    log.warn_once(
      "The config option 'completion.new_notes_location' is deprecated, please use the top-level "
        .. "'new_notes_location' instead."
    )
  end

  if opts.detect_cwd ~= nil then
    opts.detect_cwd = nil
    log.warn_once(
      "The 'detect_cwd' field is deprecated and no longer has any affect.\n"
        .. "See https://github.com/epwalsh/obsidian.nvim/pull/366 for more details."
    )
  end

  if opts.overwrite_mappings ~= nil then
    log.warn_once "The 'overwrite_mappings' config option is deprecated and no longer has any affect."
    opts.overwrite_mappings = nil
  end

  if opts.backlinks ~= nil then
    log.warn_once "The 'backlinks' config option is deprecated and no longer has any affect."
    opts.backlinks = nil
  end

  if opts.tags ~= nil then
    log.warn_once "The 'tags' config option is deprecated and no longer has any affect."
    opts.tags = nil
  end

  if opts.ui and opts.ui.checkboxes then
    -- Add a default 'order' for backwards compat.
    for i, char in ipairs { " ", "x" } do
      if opts.ui.checkboxes[char] and not opts.ui.checkboxes[char].order then
        opts.ui.checkboxes[char].order = i
      end
    end
  end

  if opts.templates and opts.templates.subdir then
    opts.templates.folder = opts.templates.subdir
    opts.templates.subdir = nil
  end

  if opts.image_name_func then
    if opts.attachments == nil then
      opts.attachments = {}
    end
    opts.attachments.img_name_func = opts.image_name_func
    opts.image_name_func = nil
  end

  --------------------------
  -- Merge with defaults. --
  --------------------------

  ---@type obsidian.config.ClientOpts
  opts = tbl_override(defaults, opts)

  opts.completion = tbl_override(defaults.completion, opts.completion)
  opts.completion.known_notes = tbl_override(defaults.completion.known_notes, opts.completion.known_notes)
  if opts.completion.known_notes.notes_root ~= nil then
    opts.completion.known_notes.notes_root = vim.fs.normalize(vim.fn.expand(opts.completion.known_notes.notes_root))
  end
  opts.mappings = opts.mappings and opts.mappings or defaults.mappings
  opts.picker = tbl_override(defaults.picker, opts.picker)
  opts.daily_notes = tbl_override(defaults.daily_notes, opts.daily_notes)
  opts.templates = tbl_override(defaults.templates, opts.templates)
  opts.ui = tbl_override(defaults.ui, opts.ui)
  opts.attachments = tbl_override(defaults.attachments, opts.attachments)

  ---------------
  -- Validate. --
  ---------------

  if opts.sort_by ~= nil and not vim.tbl_contains(vim.tbl_values(config.SortBy), opts.sort_by) then
    error("Invalid 'sort_by' option '" .. opts.sort_by .. "' in obsidian.nvim config.")
  end

  if not util.tbl_is_array(opts.workspaces) then
    error "Invalid obsidian.nvim config, the 'config.workspaces' should be an array/list."
  end

  -- Convert dir to workspace format.
  if opts.dir ~= nil then
    table.insert(opts.workspaces, 1, { path = opts.dir })
  end

  return opts
end

---@enum obsidian.config.OpenStrategy
config.OpenStrategy = {
  current = "current",
  vsplit = "vsplit",
  hsplit = "hsplit",
}

---@enum obsidian.config.SortBy
config.SortBy = {
  path = "path",
  modified = "modified",
  accessed = "accessed",
  created = "created",
}

---@enum obsidian.config.NewNotesLocation
config.NewNotesLocation = {
  current_dir = "current_dir",
  notes_subdir = "notes_subdir",
}

---@enum obsidian.config.LinkStyle
config.LinkStyle = {
  wiki = "wiki",
  markdown = "markdown",
}

---@class obsidian.config.CompletionOpts
---
---@field nvim_cmp boolean
---@field min_chars integer
---@field known_notes obsidian.config.KnownNotesCompletionOpts
config.CompletionOpts = {}

---@class obsidian.config.KnownNotesCompletionOpts
---
---@field min_chars integer
---@field notes_root string|?
---@field case_sensitive boolean
config.KnownNotesCompletionOpts = {}

---@return obsidian.config.KnownNotesCompletionOpts
config.KnownNotesCompletionOpts.default = function()
  return {
    min_chars = 2,
    notes_root = nil,
    case_sensitive = false,
  }
end

--- Get defaults.
---
---@return obsidian.config.CompletionOpts
config.CompletionOpts.default = function()
  local has_nvim_cmp, _ = pcall(require, "cmp")
  return {
    nvim_cmp = has_nvim_cmp,
    min_chars = 2,
    known_notes = config.KnownNotesCompletionOpts.default(),
  }
end

---@class obsidian.config.MappingOpts
config.MappingOpts = {}

---Get defaults.
---@return obsidian.config.MappingOpts
config.MappingOpts.default = function()
  local mappings = require "obsidian.mappings"

  return {
    ["gf"] = mappings.gf_passthrough(),
    ["<leader>ch"] = mappings.toggle_checkbox(),
    ["<cr>"] = mappings.smart_action(),
  }
end

---@class obsidian.config.PickerNoteMappingOpts
---
---@field new string|?
---@field insert_link string|?
config.PickerNoteMappingOpts = {}

---Get defaults.
---@return obsidian.config.PickerNoteMappingOpts
config.PickerNoteMappingOpts.default = function()
  return {
    new = "<C-x>",
    insert_link = "<C-l>",
  }
end

---@class obsidian.config.PickerTagMappingOpts
---
---@field tag_note string|?
---@field insert_tag string|?
config.PickerTagMappingOpts = {}

---@return obsidian.config.PickerTagMappingOpts
config.PickerTagMappingOpts.default = function()
  return {
    tag_note = "<C-x>",
    insert_tag = "<C-l>",
  }
end

---@enum obsidian.config.Picker
config.Picker = {
  telescope = "telescope.nvim",
  fzf_lua = "fzf-lua",
  mini = "mini.pick",
}

---@class obsidian.config.PickerOpts
---
---@field name obsidian.config.Picker|?
---@field note_mappings obsidian.config.PickerNoteMappingOpts
---@field tag_mappings obsidian.config.PickerTagMappingOpts
config.PickerOpts = {}

--- Get the defaults.
---
---@return obsidian.config.PickerOpts
config.PickerOpts.default = function()
  return {
    name = nil,
    note_mappings = config.PickerNoteMappingOpts.default(),
    tag_mappings = config.PickerTagMappingOpts.default(),
  }
end

---@class obsidian.config.DailyNotesOpts
---
---@field folder string|?
---@field date_format string|?
---@field alias_format string|?
---@field template string|?
---@field default_tags string[]|?
config.DailyNotesOpts = {}

--- Get defaults.
---
---@return obsidian.config.DailyNotesOpts
config.DailyNotesOpts.default = function()
  return {
    folder = nil,
    date_format = nil,
    alias_format = nil,
    default_tags = { "daily-notes" },
  }
end

---@class obsidian.config.TemplateOpts
---
---@field folder string|obsidian.Path|?
---@field date_format string|?
---@field time_format string|?
---@field substitutions table<string, function|string>|?
config.TemplateOpts = {}

--- Get defaults.
---
---@return obsidian.config.TemplateOpts
config.TemplateOpts.default = function()
  return {
    folder = nil,
    date_format = nil,
    time_format = nil,
    substitutions = {},
  }
end

---@class obsidian.config.UIOpts
---
---@field enable boolean
---@field update_debounce integer
---@field max_file_length integer|?
---@field skip_cursor_line boolean
---@field cursor_render_delay integer
---@field skip_cursor_content boolean
---@field checkboxes table<string, obsidian.config.CheckboxSpec>
---@field bullets obsidian.config.UICharSpec|?
---@field external_link_icon obsidian.config.UICharSpec
---@field reference_text obsidian.config.UIStyleSpec
---@field highlight_text obsidian.config.UIStyleSpec
---@field tags obsidian.config.UIStyleSpec
---@field block_ids obsidian.config.UIStyleSpec
---@field heading obsidian.config.HeadingOpts
---@field table obsidian.config.TableOpts
---@field horizontal_rule obsidian.config.HorizontalRuleOpts
---@field hl_groups table<string, table>
config.UIOpts = {}

---@class obsidian.config.UICharSpec
---
---@field char string
---@field hl_group string

---@class obsidian.config.CheckboxSpec : obsidian.config.UICharSpec
---
---@field char string
---@field hl_group string
---@field order integer

---@class obsidian.config.UIStyleSpec
---
---@field hl_group string

---@class obsidian.config.HeadingOpts
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

---@class obsidian.config.TableOpts
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

---@class obsidian.config.HorizontalRuleOpts
---@field enabled boolean
---@field char string
---@field style "full"|"original"|"custom"|"block"
---@field width integer
---@field block_width integer
---@field padding integer|?
---@field highlights table<string, string>

---@return obsidian.config.UIOpts
config.UIOpts.default = function()
  return {
    enable = true,
    update_debounce = 200,
    max_file_length = 5000,
    skip_cursor_line = true,  -- 跳过光标所在行的渲染
    cursor_render_delay = 50,   -- 光标移动后的渲染延迟(ms)
    skip_cursor_content = false, -- 光标行是否跳过所有渲染内容（true=全部跳过，false=保留缩进等基础渲染）
    checkboxes = {
      [" "] = { order = 1, char = "󰄱", hl_group = "ObsidianTodo" },
      ["~"] = { order = 2, char = "󰰱", hl_group = "ObsidianTilde" },
      ["!"] = { order = 3, char = "", hl_group = "ObsidianImportant" },
      [">"] = { order = 4, char = "", hl_group = "ObsidianRightArrow" },
      ["x"] = { order = 5, char = "", hl_group = "ObsidianDone" },
    },
    bullets = { char = "•", hl_group = "ObsidianBullet" },
    external_link_icon = { char = "", hl_group = "ObsidianExtLinkIcon" },
    reference_text = { hl_group = "ObsidianRefText" },
    highlight_text = { hl_group = "ObsidianHighlightText" },
    tags = { hl_group = "ObsidianTag" },
    block_ids = { hl_group = "ObsidianBlockID" },
    heading = {
      enabled = false,
      icons = { "󰲡 ", "󰲣 ", "󰲥 ", "󰲧 ", "󰲩 ", "󰲫 " },
      position = "overlay",
      foregrounds = true,
      backgrounds = true,
      width = "full",
      border = false,
      above = "▄",
      below = "▀",
      indent = false,
      indent_levels = {},
      custom = {},
    },
    table = {
      enabled = false,
      border = {
        '┌', '┬', '┐',
        '├', '┼', '┤',
        '└', '┴', '┘',
        '│', '─',
      },
      border_enabled = true,
      cell = 'padded',
      padding = 1,
      min_width = 3,
      alignment_indicator = '━',
      head = 'ObsidianTableHead',
      row = 'ObsidianTableRow',
      filler = 'ObsidianTableFill',
    },
    horizontal_rule = {
      enabled = false,
      char = "─",
      style = "full",
      width = 80,
      block_width = 80,
      padding = nil,
      highlights = {
        ["-"] = "ObsidianHorizontalRule",
        ["*"] = "ObsidianHorizontalRule",
        ["_"] = "ObsidianHorizontalRule",
      },
    },
    hl_groups = {
      ObsidianTodo = { bold = true, fg = "#f78c6c" },
      ObsidianDone = { bold = true, fg = "#89ddff" },
      ObsidianRightArrow = { bold = true, fg = "#f78c6c" },
      ObsidianTilde = { bold = true, fg = "#ff5370" },
      ObsidianImportant = { bold = true, fg = "#d73128" },
      ObsidianBullet = { bold = true, fg = "#89ddff" },
      ObsidianRefText = { underline = true, fg = "#c792ea" },
      ObsidianExtLinkIcon = { fg = "#c792ea" },
      ObsidianTag = { italic = true, fg = "#89ddff" },
      ObsidianBlockID = { italic = true, fg = "#89ddff" },
      ObsidianHighlightText = { bg = "#75662e" },
      -- Heading highlight groups
      ObsidianHeading1 = { bold = true, fg = "#f7768e" },
      ObsidianHeading2 = { bold = true, fg = "#9ece6a" },
      ObsidianHeading3 = { bold = true, fg = "#7aa2f7" },
      ObsidianHeading4 = { bold = true, fg = "#bb9af7" },
      ObsidianHeading5 = { bold = true, fg = "#e0af68" },
      ObsidianHeading6 = { bold = true, fg = "#7dcfff" },
      -- Heading background highlight groups
      ObsidianHeading1Bg = { bg = "#f7768e20" },
      ObsidianHeading2Bg = { bg = "#9ece6a20" },
      ObsidianHeading3Bg = { bg = "#7aa2f720" },
      ObsidianHeading4Bg = { bg = "#bb9af720" },
      ObsidianHeading5Bg = { bg = "#e0af6820" },
      ObsidianHeading6Bg = { bg = "#7dcfff20" },
      -- Table highlight groups
      ObsidianTableHead = { bold = true, fg = "#7dcfff" },
      ObsidianTableRow = { fg = "#c0caf5" },
      ObsidianTableFill = { fg = "#414868" },
      -- Horizontal rule highlight groups
      ObsidianHorizontalRule = { fg = "#565f89" },
    },
  }
end

---@class obsidian.config.AttachmentsOpts
---
---@field img_folder string Default folder to save images to, relative to the vault root.
---@field img_name_func (fun(): string)|?
---@field img_text_func fun(client: obsidian.Client, path: obsidian.Path): string
---@field confirm_img_paste boolean Whether to confirm the paste or not. Defaults to true.
config.AttachmentsOpts = {}

---@return obsidian.config.AttachmentsOpts
config.AttachmentsOpts.default = function()
  return {
    img_folder = "assets/imgs",
    ---@param client obsidian.Client
    ---@param path obsidian.Path the absolute path to the image file
    ---@return string
    img_text_func = function(client, path)
      path = client:vault_relative_path(path) or path
      return string.format("![%s](%s)", path.name, path)
    end,
    confirm_img_paste = true,
  }
end

---@class obsidian.config.CallbackConfig
---
---@field post_setup fun(client: obsidian.Client)|? Runs right after the `obsidian.Client` is initialized.
---@field enter_note fun(client: obsidian.Client, note: obsidian.Note)|? Runs when entering a note buffer.
---@field leave_note fun(client: obsidian.Client, note: obsidian.Note)|? Runs when leaving a note buffer.
---@field pre_write_note fun(client: obsidian.Client, note: obsidian.Note)|? Runs right before writing a note buffer.
---@field post_set_workspace fun(client: obsidian.Client, workspace: obsidian.Workspace)|? Runs anytime the workspace is set/changed.
config.CallbackConfig = {}

---@return obsidian.config.CallbackConfig
config.CallbackConfig.default = function()
  return {}
end

---@class obsidian.config.RecentFilesOpts
---@field enabled boolean 是否启用最近文件功能
---@field auto_open boolean 是否自动打开侧边栏
---@field width string 侧边栏宽度，例如 "30%"
---@field max_files integer 显示的最大文件数量
config.RecentFilesOpts = {}

---@return obsidian.config.RecentFilesOpts
config.RecentFilesOpts.default = function()
  return {
    enabled = true,
    auto_open = false,
    width = "30%",
    max_files = 5,
  }
end

return config
