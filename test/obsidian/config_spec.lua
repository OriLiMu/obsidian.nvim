local config = require "obsidian.config"

describe("config.ClientOpts.default()", function()
  it("should disable ai translate by default", function()
    local opts = config.ClientOpts.default()
    assert.is_false(opts.ai_translate.enabled)
  end)

  it("should set known notes completion defaults", function()
    local opts = config.ClientOpts.default()
    assert.equals(2, opts.completion.known_notes.min_chars)
    assert.is_nil(opts.completion.known_notes.notes_root)
    assert.is_false(opts.completion.known_notes.case_sensitive)
    assert.is_true(opts.completion.known_notes.alias_insert_filename)
  end)
end)

describe("config.ClientOpts.normalize()", function()
  it("should normalize completion.known_notes.notes_root", function()
    local opts = config.ClientOpts.normalize {
      workspaces = { { path = "/tmp" } },
      completion = {
        known_notes = {
          notes_root = "/tmp/../tmp/test-notes",
        },
      },
    }

    assert.equals(vim.fs.normalize "/tmp/test-notes", opts.completion.known_notes.notes_root)
  end)

  it("should preserve completion.known_notes.alias_insert_filename", function()
    local opts = config.ClientOpts.normalize {
      workspaces = { { path = "/tmp" } },
      completion = {
        known_notes = {
          alias_insert_filename = false,
        },
      },
    }

    assert.is_false(opts.completion.known_notes.alias_insert_filename)
  end)
end)
