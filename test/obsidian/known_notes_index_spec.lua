local Path = require "obsidian.path"
local obsidian = require "obsidian"

local with_tmp_client = function(run, overrides)
  local dir = Path.temp { suffix = "-obsidian-known-notes" }
  dir:mkdir { parents = true }

  local opts = obsidian.config.ClientOpts.default()
  opts.workspaces = { { path = tostring(dir) } }
  opts.ui.enable = false

  if overrides then
    opts = vim.tbl_deep_extend("force", opts, overrides)
  end

  local client = obsidian.new(opts)
  local ok, err = pcall(run, client, dir)

  dir:rmtree()

  if not ok then
    error(err)
  end
end

local write_file = function(path, lines)
  local parent = assert(Path.new(path):parent())
  parent:mkdir { parents = true, exists_ok = true }
  vim.fn.writefile(lines, tostring(path))
end

local labels_from_results = function(results)
  local labels = {}
  for _, result in ipairs(results) do
    labels[#labels + 1] = result.label
  end
  table.sort(labels)
  return labels
end

describe("KnownNotesIndex", function()
  it("should match filenames and aliases by prefix", function()
    with_tmp_client(function(client, dir)
      write_file(dir / "How-to-eat-an-apple.md", { "# a" })
      write_file(dir / "How-to-learn-fast.md", { "# b" })
      write_file(dir / "note-ai.md", {
        "---",
        "aliases:",
        "  - Ai-Help-Learning",
        "---",
      })

      client.known_notes_index:start()
      assert.is_true(client.known_notes_index:wait_until_ready())

      local how_results = client.known_notes_index:query "how"
      assert.are_same({ "How-to-eat-an-apple", "How-to-learn-fast" }, labels_from_results(how_results))

      local alias_results = client.known_notes_index:query "ai-"
      assert.are_same({ "Ai-Help-Learning" }, labels_from_results(alias_results))
    end)
  end)

  it("should respect case_sensitive setting", function()
    with_tmp_client(function(client, dir)
      write_file(dir / "note-ai.md", {
        "---",
        "aliases:",
        "  - Ai-Help-Learning",
        "---",
      })

      client.opts.completion.known_notes.case_sensitive = true
      client.known_notes_index:start()
      assert.is_true(client.known_notes_index:wait_until_ready())

      assert.are_same({}, labels_from_results(client.known_notes_index:query "ai-"))
      assert.are_same({ "Ai-Help-Learning" }, labels_from_results(client.known_notes_index:query "Ai-"))
    end)
  end)

  it("should update entries incrementally on save and delete", function()
    with_tmp_client(function(client, dir)
      local file_path = dir / "New-Topic.md"
      write_file(file_path, { "# new" })
      client.known_notes_index:on_note_saved(file_path)
      assert.are_same({ "New-Topic" }, labels_from_results(client.known_notes_index:query "new"))

      write_file(file_path, {
        "---",
        "aliases:",
        "  - Fresh-Topic",
        "---",
      })
      client.known_notes_index:on_note_saved(file_path)
      assert.are_same({ "Fresh-Topic" }, labels_from_results(client.known_notes_index:query "fresh"))

      file_path:unlink()
      client.known_notes_index:on_note_deleted(file_path)
      assert.are_same({}, labels_from_results(client.known_notes_index:query "new"))
      assert.are_same({}, labels_from_results(client.known_notes_index:query "fresh"))
    end)
  end)

  it("should tolerate invalid frontmatter and keep filename searchable", function()
    with_tmp_client(function(client, dir)
      write_file(dir / "broken-frontmatter.md", {
        "---",
        "aliases: [broken",
        "---",
        "body",
      })

      client.known_notes_index:start()
      assert.is_true(client.known_notes_index:wait_until_ready())

      assert.are_same({ "broken-frontmatter" }, labels_from_results(client.known_notes_index:query "broken"))
    end)
  end)

  it("should disable known notes completion when notes_root is invalid", function()
    with_tmp_client(function(client)
      client.opts.completion.known_notes.notes_root = "/tmp/does-not-exist-known-notes"
      client.known_notes_index:start()
      assert.is_false(client.known_notes_index:is_enabled())
      assert.are_same({}, client.known_notes_index:query "any")
    end)
  end)
end)
