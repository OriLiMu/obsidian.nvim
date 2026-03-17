local Path = require "obsidian.path"
local obsidian = require "obsidian"

---@param run fun(client: obsidian.Client, dir: obsidian.Path)
local with_tmp_client = function(run)
  local dir = Path.temp { suffix = "-obsidian-resolve-note" }
  dir:mkdir { parents = true }

  local opts = obsidian.config.ClientOpts.default()
  opts.workspaces = { { path = tostring(dir) } }
  opts.ui.enable = false

  local client = obsidian.new(opts)
  local ok, err = pcall(run, client, dir)

  dir:rmtree()

  if not ok then
    error(err)
  end
end

---@param path string|obsidian.Path
---@param lines string[]
local write_file = function(path, lines)
  local parent = assert(Path.new(path):parent())
  parent:mkdir { parents = true, exist_ok = true }
  vim.fn.writefile(lines, tostring(path))
end

describe("Client:resolve_note()", function()
  it("should ignore the first heading 1 while keeping id, alias, and filename searchable", function()
    with_tmp_client(function(client, dir)
      local note_path = dir / "topic-file.md"
      write_file(note_path, {
        "---",
        "id: note-id",
        "aliases:",
        "  - note-alias",
        "---",
        "",
        "# First Heading",
        "",
        "Body text",
      })

      local title_matches = { client:resolve_note("First Heading", { timeout = 1000 }) }
      local id_matches = { client:resolve_note("note-id", { timeout = 1000 }) }
      local alias_matches = { client:resolve_note("note-alias", { timeout = 1000 }) }
      local filename_matches = { client:resolve_note("topic-file", { timeout = 1000 }) }

      assert.same({}, title_matches)
      assert.equals(1, #id_matches)
      assert.equals(1, #alias_matches)
      assert.equals(1, #filename_matches)
      assert.equals(note_path, id_matches[1].path)
      assert.equals(note_path, alias_matches[1].path)
      assert.equals(note_path, filename_matches[1].path)
    end)
  end)
end)
