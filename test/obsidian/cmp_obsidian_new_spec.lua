local obsidian = require "obsidian"
local source_mod = require "cmp_obsidian_new"

local with_fake_client = function(fake_client, run)
  fake_client.opts = vim.tbl_deep_extend("force", {
    completion = {
      min_chars = 1,
    },
    daily_notes = {
      template = nil,
    },
  }, fake_client.opts or {})

  local original_get_client = obsidian.get_client
  obsidian.get_client = function()
    return fake_client
  end

  local ok, err = pcall(run)
  obsidian.get_client = original_get_client

  if not ok then
    error(err)
  end
end

describe("cmp_obsidian_new.Source", function()
  it("should not create notes for incomplete anchor links", function()
    local source = source_mod.new()
    local callback_result
    local create_note_calls = 0

    with_fake_client({
      create_note = function()
        create_note_calls = create_note_calls + 1
      end,
    }, function()
      local input = "[[Ori/Computer/Alogrithm/Tests/1143_最长公共子序列#"
      source:complete({
        context = {
          cursor_before_line = input,
          cursor_after_line = "]]",
          cursor = { col = #input + 1, row = 1 },
        },
      }, function(res)
        callback_result = res
      end)
    end)

    assert.is_true(callback_result.isIncomplete)
    assert.is_nil(callback_result.items)
    assert.equals(0, create_note_calls)
  end)

  it("should still create candidates for plain wiki links", function()
    local source = source_mod.new()
    local callback_result
    local create_note_calls = 0

    with_fake_client({
      create_note = function(_, opts)
        create_note_calls = create_note_calls + 1
        return {
          title = opts.title,
          path = "/tmp/" .. opts.title .. ".md",
          display_info = function(_, info)
            return info.label
          end,
        }
      end,
      format_link = function(_, note)
        return "[[" .. note.title .. "]]"
      end,
    }, function()
      local input = "[[new-note"
      source:complete({
        context = {
          cursor_before_line = input,
          cursor_after_line = "]]",
          cursor = { col = #input + 1, row = 1 },
        },
      }, function(res)
        callback_result = res
      end)
    end)

    assert.equals(1, create_note_calls)
    assert.is_true(callback_result.isIncomplete)
    assert.equals(1, #callback_result.items)
    assert.equals("[[new-note]] (create)", callback_result.items[1].label)
    assert.equals("[[new-note]]", callback_result.items[1].textEdit.newText)
  end)
end)
