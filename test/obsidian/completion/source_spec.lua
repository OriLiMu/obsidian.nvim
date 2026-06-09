local obsidian = require "obsidian"

describe("cmp_obsidian source", function()
  it("should provide filter text for cjk note anchors", function()
    obsidian.setup {
      workspaces = {
        { name = "test", path = vim.fn.getcwd() .. "/test/fixtures/notes" },
      },
      completion = {
        nvim_cmp = false,
        min_chars = 1,
      },
    }

    local source = require("cmp_obsidian").new()
    local result
    local done = false

    source:complete({
      context = {
        cursor_before_line = "[[排序链表#第",
        cursor_after_line = "]]",
        cursor = { row = 1, col = 8 },
      },
    }, function(res)
      result = res
      done = true
    end)

    assert.is_true(vim.wait(1000, function()
      return done
    end))
    assert.is_not_nil(result)
    assert.is_true(#(result.items or {}) > 0)

    local matched = false
    local wrapped_matched = false
    for _, item in ipairs(result.items) do
      if
        item.filterText
        and item.filterText:find("排序链表", 1, true)
        and item.filterText:find("第三天总结思路", 1, true)
      then
        matched = true
      end

      if item.filterText and item.filterText:find("[[148_排序链表#第三天总结思路]]", 1, true) then
        wrapped_matched = true
      end
    end

    assert.is_true(matched)
    assert.is_true(wrapped_matched)
  end)

  it("should insert wiki anchor links with note id instead of aliases", function()
    obsidian.setup {
      workspaces = {
        { name = "test", path = vim.fn.getcwd() .. "/test/fixtures/notes" },
      },
      completion = {
        nvim_cmp = false,
        min_chars = 1,
      },
    }

    local source = require("cmp_obsidian").new()
    local result
    local done = false

    source:complete({
      context = {
        cursor_before_line = "[[排序链表#第",
        cursor_after_line = "]]",
        cursor = { row = 1, col = 8 },
      },
    }, function(res)
      result = res
      done = true
    end)

    assert.is_true(vim.wait(1000, function()
      return done
    end))
    assert.is_not_nil(result)

    local found_id_only_link = false
    for _, item in ipairs(result.items or {}) do
      local new_text = item.textEdit and item.textEdit.newText or nil
      if new_text == "[[148_排序链表#第三天总结思路]]" then
        found_id_only_link = true
        break
      end
    end

    assert.is_true(found_id_only_link)
  end)
end)
