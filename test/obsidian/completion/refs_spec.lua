local completion = require "obsidian.completion.refs"

describe("completion.refs.can_complete()", function()
  it("should allow completion for wiki anchor links before anchor text", function()
    local ok, search, _, _, ref_type = completion.can_complete {
      context = {
        cursor_before_line = "[[note-a#",
        cursor_after_line = "]]",
        cursor = { col = 9 },
      },
    }

    assert.is_true(ok)
    assert.equals("note-a#", search)
    assert.equals(completion.RefType.Wiki, ref_type)
  end)

  it("should allow completion for wiki anchor links with cjk text", function()
    local ok, search, _, _, ref_type = completion.can_complete {
      context = {
        cursor_before_line = "[[148_排序链表#第",
        cursor_after_line = "]]",
        cursor = { col = 13 },
      },
    }

    assert.is_true(ok)
    assert.equals("148_排序链表#第", search)
    assert.equals(completion.RefType.Wiki, ref_type)
  end)
end)

describe("completion.refs.get_trigger_characters()", function()
  it("should include hash for anchor completions", function()
    assert.are_same({ "[", "#" }, completion.get_trigger_characters())
  end)
end)
