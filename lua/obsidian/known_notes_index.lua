local abc = require "obsidian.abc"
local log = require "obsidian.log"
local Note = require "obsidian.note"
local Path = require "obsidian.path"
local util = require "obsidian.util"
local scan = require "plenary.scandir"
local AsyncExecutor = require("obsidian.async").AsyncExecutor

---@class obsidian.KnownNotesToken
---@field key_norm string
---@field label string
---@field kind "filename"|"alias"
---@field path string

---@class obsidian.KnownNotesEntry
---@field path string
---@field filename string
---@field aliases string[]

---@class obsidian.KnownNotesIndex : obsidian.ABC
---@field client obsidian.Client
---@field _opts obsidian.config.KnownNotesCompletionOpts
---@field _notes_root obsidian.Path|?
---@field _enabled boolean
---@field _ready boolean
---@field _building boolean
---@field _build_seq integer
---@field _entries_by_path table<string, obsidian.KnownNotesEntry>
---@field _tokens_by_path table<string, obsidian.KnownNotesToken[]>
---@field _tokens_sorted obsidian.KnownNotesToken[]
local KnownNotesIndex = abc.new_class()

local lower_bound = function(tokens, target)
  local left = 1
  local right = #tokens + 1
  while left < right do
    local mid = math.floor((left + right) / 2)
    if tokens[mid].key_norm < target then
      left = mid + 1
    else
      right = mid
    end
  end
  return left
end

KnownNotesIndex.new = function(client)
  local self = KnownNotesIndex.init()
  self.client = client
  self._enabled = false
  self._ready = false
  self._building = false
  self._build_seq = 0
  self._entries_by_path = {}
  self._tokens_by_path = {}
  self._tokens_sorted = {}
  self._opts = {
    min_chars = 2,
    notes_root = nil,
    case_sensitive = false,
  }
  self._notes_root = nil
  return self
end

KnownNotesIndex._clear = function(self)
  self._entries_by_path = {}
  self._tokens_by_path = {}
  self._tokens_sorted = {}
  self._ready = false
end

KnownNotesIndex._normalize_key = function(self, s)
  if self._opts.case_sensitive then
    return s
  else
    return string.lower(s)
  end
end

KnownNotesIndex._resolve_notes_root = function(self)
  local root = self._opts.notes_root
  if root == nil or string.len(root) == 0 then
    root = tostring(self.client:vault_root())
  end

  root = vim.fs.normalize(vim.fn.expand(root))
  local root_path = Path.new(root):resolve { strict = false }

  if not root_path:exists() or not root_path:is_dir() then
    log.warn("[known-notes] notes_root 不存在或不可用: %s，已禁用已知笔记补全", root_path)
    self._enabled = false
    self._notes_root = nil
    return
  end

  local readable = true
  local ok, res = pcall(vim.loop.fs_access, tostring(root_path), "R")
  if ok and res == false then
    readable = false
  end

  if not readable then
    log.warn("[known-notes] notes_root 不可读: %s，已禁用已知笔记补全", root_path)
    self._enabled = false
    self._notes_root = nil
    return
  end

  self._enabled = true
  self._notes_root = root_path
end

KnownNotesIndex._reload_opts = function(self)
  local known_notes_opts = self.client.opts.completion.known_notes
  self._opts = {
    min_chars = known_notes_opts.min_chars,
    notes_root = known_notes_opts.notes_root,
    case_sensitive = known_notes_opts.case_sensitive,
  }
  self:_resolve_notes_root()
end

KnownNotesIndex._set_entry = function(self, path, filename, aliases, defer_rebuild)
  local resolved_path = tostring(Path.new(path):resolve { strict = false })
  local aliases_uniq = {}
  for _, alias in ipairs(util.tbl_unique(aliases)) do
    if type(alias) == "string" and string.len(alias) > 0 then
      table.insert(aliases_uniq, alias)
    end
  end

  self._entries_by_path[resolved_path] = {
    path = resolved_path,
    filename = filename,
    aliases = aliases_uniq,
  }

  local tokens = {}
  local seen = {}

  if filename ~= nil and string.len(filename) > 0 then
    seen[self:_normalize_key(filename)] = true
    tokens[#tokens + 1] = {
      key_norm = self:_normalize_key(filename),
      label = filename,
      kind = "filename",
      path = resolved_path,
    }
  end

  for _, alias in ipairs(aliases_uniq) do
    local alias_key = self:_normalize_key(alias)
    if not seen[alias_key] then
      seen[alias_key] = true
      tokens[#tokens + 1] = {
        key_norm = alias_key,
        label = alias,
        kind = "alias",
        path = resolved_path,
      }
    end
  end

  self._tokens_by_path[resolved_path] = tokens

  if not defer_rebuild then
    self:_rebuild_sorted_tokens()
  end
end

KnownNotesIndex._remove_entry = function(self, path, defer_rebuild)
  local resolved_path = tostring(Path.new(path):resolve { strict = false })
  self._entries_by_path[resolved_path] = nil
  self._tokens_by_path[resolved_path] = nil
  if not defer_rebuild then
    self:_rebuild_sorted_tokens()
  end
end

KnownNotesIndex._rebuild_sorted_tokens = function(self)
  local merged = {}
  for _, tokens in pairs(self._tokens_by_path) do
    for _, token in ipairs(tokens) do
      merged[#merged + 1] = token
    end
  end

  table.sort(merged, function(a, b)
    if a.key_norm ~= b.key_norm then
      return a.key_norm < b.key_norm
    end
    if a.kind ~= b.kind then
      return a.kind == "filename"
    end
    if a.label ~= b.label then
      return a.label < b.label
    end
    return a.path < b.path
  end)

  self._tokens_sorted = merged
end

KnownNotesIndex._read_aliases = function(self, path)
  local aliases = {}
  if not path:is_file() then
    return aliases
  end

  local ok, note = pcall(Note.from_file, path, { max_lines = self.client.opts.search_max_lines })
  if ok and note and note.aliases then
    aliases = note.aliases
  end
  return aliases
end

KnownNotesIndex._index_path = function(self, path, defer_rebuild)
  local resolved = Path.new(path):resolve { strict = false }
  if not self:in_scope(resolved) then
    return
  end

  local filename = resolved.stem or ""
  local aliases = self:_read_aliases(resolved)
  self:_set_entry(resolved, filename, aliases, defer_rebuild)
end

KnownNotesIndex.start = function(self)
  self:_reload_opts()
  self:_clear()
  self._build_seq = self._build_seq + 1
  local current_build = self._build_seq

  if not self._enabled or self._notes_root == nil then
    self._building = false
    self._ready = false
    return
  end

  self._building = true

  local executor = AsyncExecutor.new(8)
  scan.scan_dir_async(tostring(self._notes_root), {
    hidden = true,
    add_dirs = false,
    respect_gitignore = false,
    search_pattern = ".*%.md",
    on_insert = function(entry)
      if current_build ~= self._build_seq then
        return
      end

      local entry_path = Path.new(entry):resolve { strict = false }
      if not self:in_scope(entry_path) then
        return
      end

      executor:submit(function(path, max_lines)
        local resolved = Path.new(path):resolve { strict = false }
        local filename = resolved.stem or ""
        local aliases = {}
        if resolved:is_file() then
          local ok, note = pcall(Note.from_file_async, resolved, { max_lines = max_lines })
          if ok and note and note.aliases then
            aliases = note.aliases
          end
        end
        return tostring(resolved), filename, aliases
      end, function(path, filename, aliases)
        if current_build ~= self._build_seq or path == nil then
          return
        end
        self:_set_entry(path, filename, aliases, true)
      end, tostring(entry_path), self.client.opts.search_max_lines)
    end,
    on_exit = function(_)
      if current_build ~= self._build_seq then
        return
      end
      executor:join_and_then(nil, function()
        if current_build ~= self._build_seq then
          return
        end
        self:_rebuild_sorted_tokens()
        self._building = false
        self._ready = true
      end)
    end,
  })
end

KnownNotesIndex.is_enabled = function(self)
  return self._enabled
end

KnownNotesIndex.is_ready = function(self)
  return self._ready
end

KnownNotesIndex.wait_until_ready = function(self, timeout)
  timeout = timeout or 5000
  return vim.wait(timeout, function()
    return not self._building
  end, 20)
end

KnownNotesIndex.min_chars = function(self)
  return self._opts.min_chars
end

KnownNotesIndex.notes_root = function(self)
  return self._notes_root
end

KnownNotesIndex.in_scope = function(self, path)
  if not self._enabled or self._notes_root == nil then
    return false
  end

  local resolved = Path.new(path):resolve { strict = false }
  if resolved.suffix ~= ".md" then
    return false
  end

  return self._notes_root == resolved:parent() or self._notes_root:is_parent_of(resolved)
end

KnownNotesIndex.on_note_new = function(self, path)
  if not self:in_scope(path) then
    return
  end
  local resolved = Path.new(path):resolve { strict = false }
  local filename = resolved.stem or ""
  self:_set_entry(resolved, filename, {}, false)
end

KnownNotesIndex.on_note_saved = function(self, path)
  self:_index_path(path, false)
end

KnownNotesIndex.on_note_deleted = function(self, path)
  if not self:in_scope(path) then
    return
  end
  self:_remove_entry(path, false)
end

---@param term string
---@return {label: string, kind: "filename"|"alias", path: string}[]
KnownNotesIndex.query = function(self, term)
  if not self._enabled or term == nil or string.len(term) == 0 then
    return {}
  end

  local query_key = self:_normalize_key(term)
  local start_idx = lower_bound(self._tokens_sorted, query_key)
  local results = {}
  local seen = {}

  for i = start_idx, #self._tokens_sorted do
    local token = self._tokens_sorted[i]
    if not vim.startswith(token.key_norm, query_key) then
      break
    end

    local dedup_key = self:_normalize_key(token.label)
    if not seen[dedup_key] then
      seen[dedup_key] = true
      results[#results + 1] = {
        label = token.label,
        kind = token.kind,
        path = token.path,
      }
    end
  end

  return results
end

return KnownNotesIndex
