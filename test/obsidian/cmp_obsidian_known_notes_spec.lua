local obsidian = require "obsidian"
local source_mod = require "cmp_obsidian_known_notes"

local with_fake_client = function(fake_client, run)
  fake_client.opts = vim.tbl_deep_extend("force", {
    completion = {
      known_notes = {
        alias_insert_filename = true,
      },
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

describe("cmp_obsidian_known_notes.find_current_term()", function()
  it("should extract current term and replace range", function()
    local request = {
      context = {
        cursor_before_line = "prefix how-to",
        cursor = {
          col = string.len "prefix how-to" + 1,
        },
      },
    }

    local term, insert_start, insert_end = source_mod.find_current_term(request)
    assert.equals("how-to", term)
    assert.equals(7, insert_start)
    assert.equals(13, insert_end)
  end)
end)

describe("cmp_obsidian_known_notes.get_keyword_pattern()", function()
  it("should include hyphenated terms", function()
    local regex = vim.regex(source_mod.get_keyword_pattern())
    assert.is_not_nil(regex:match_str "ai-")
    assert.is_not_nil(regex:match_str "note-")
  end)
end)

describe("cmp_obsidian_known_notes.Source", function()
  it("should expose '-' as trigger character", function()
    assert.is_true(vim.tbl_contains(source_mod.get_trigger_characters(), "-"))
  end)

  it("should use utf-8 position encoding for textEdit ranges", function()
    local source = source_mod.new()
    assert.equals("utf-8", source:get_position_encoding_kind())
  end)

  it("should not return candidates for non-markdown filetype", function()
    local bufnr = vim.api.nvim_create_buf(false, true)
    vim.bo[bufnr].filetype = "lua"

    local source = source_mod.new()
    local callback_result
    source:complete({
      context = {
        bufnr = bufnr,
        cursor_before_line = "how",
        cursor = { col = 4, row = 1 },
      },
    }, function(res)
      callback_result = res
    end)

    assert.is_true(callback_result.isIncomplete)
    assert.is_nil(callback_result.items)
  end)

  it("should build wiki link textEdit from match", function()
    local bufnr = vim.api.nvim_create_buf(false, true)
    vim.bo[bufnr].filetype = "markdown"

    local source = source_mod.new()
    local callback_result

    with_fake_client({
      known_notes_index = {
        is_enabled = function()
          return true
        end,
        min_chars = function()
          return 3
        end,
        query = function()
          return {
            { label = "How-to-eat-an-apple", kind = "filename", path = "/tmp/How-to-eat-an-apple.md" },
          }
        end,
      },
    }, function()
      source:complete({
        context = {
          bufnr = bufnr,
          cursor_before_line = "how",
          cursor = { col = 4, row = 1 },
        },
      }, function(res)
        callback_result = res
      end)
      vim.wait(1000, function()
        return callback_result ~= nil
      end, 20)
    end)

    assert.is_true(callback_result.isIncomplete)
    assert.equals(1, #callback_result.items)
    assert.equals("[[How-to-eat-an-apple]]", callback_result.items[1].textEdit.newText)
  end)

  it("should insert filename when alias match and alias_insert_filename is true", function()
    local bufnr = vim.api.nvim_create_buf(false, true)
    vim.bo[bufnr].filetype = "markdown"

    local source = source_mod.new()
    local callback_result

    with_fake_client({
      known_notes_index = {
        is_enabled = function()
          return true
        end,
        min_chars = function()
          return 3
        end,
        query = function()
          return {
            { label = "bbbb", kind = "alias", path = "/tmp/aaaa.md" },
          }
        end,
      },
    }, function()
      source:complete({
        context = {
          bufnr = bufnr,
          cursor_before_line = "bbb",
          cursor = { col = 4, row = 1 },
        },
      }, function(res)
        callback_result = res
      end)
      vim.wait(1000, function()
        return callback_result ~= nil
      end, 20)
    end)

    assert.equals("[[bbbb]]", callback_result.items[1].label)
    assert.equals("[[aaaa]]", callback_result.items[1].textEdit.newText)
  end)

  it("should insert alias when alias_insert_filename is false", function()
    local bufnr = vim.api.nvim_create_buf(false, true)
    vim.bo[bufnr].filetype = "markdown"

    local source = source_mod.new()
    local callback_result

    with_fake_client({
      opts = {
        completion = {
          known_notes = {
            alias_insert_filename = false,
          },
        },
      },
      known_notes_index = {
        is_enabled = function()
          return true
        end,
        min_chars = function()
          return 3
        end,
        query = function()
          return {
            { label = "bbbb", kind = "alias", path = "/tmp/aaaa.md" },
          }
        end,
      },
    }, function()
      source:complete({
        context = {
          bufnr = bufnr,
          cursor_before_line = "bbb",
          cursor = { col = 4, row = 1 },
        },
      }, function(res)
        callback_result = res
      end)
      vim.wait(1000, function()
        return callback_result ~= nil
      end, 20)
    end)

    assert.equals("[[bbbb]]", callback_result.items[1].textEdit.newText)
  end)

  it("should replace only the trailing ascii trigger after chinese text", function()
    local bufnr = vim.api.nvim_create_buf(false, true)
    vim.bo[bufnr].filetype = "markdown"

    local source = source_mod.new()
    local callback_result
    local prefix = "测试"
    local input = prefix .. "mark"

    with_fake_client({
      known_notes_index = {
        is_enabled = function()
          return true
        end,
        min_chars = function()
          return 3
        end,
        query = function()
          return {
            { label = "马克洛夫性质", kind = "alias", path = "/tmp/马克洛夫性质.md" },
          }
        end,
      },
    }, function()
      source:complete({
        context = {
          bufnr = bufnr,
          cursor_before_line = input,
          cursor = { col = string.len(input) + 1, row = 1 },
        },
      }, function(res)
        callback_result = res
      end)
      vim.wait(1000, function()
        return callback_result ~= nil
      end, 20)
    end)

    assert.equals(string.len(prefix), callback_result.items[1].textEdit.range.start.character)
    assert.equals(string.len(input), callback_result.items[1].textEdit.range["end"].character)
    assert.equals("[[马克洛夫性质]]", callback_result.items[1].textEdit.newText)
  end)

  it("should discard stale request results", function()
    local bufnr = vim.api.nvim_create_buf(false, true)
    vim.bo[bufnr].filetype = "markdown"

    local source = source_mod.new()
    local first_result
    local second_result

    with_fake_client({
      known_notes_index = {
        is_enabled = function()
          return true
        end,
        min_chars = function()
          return 3
        end,
        query = function(_, term)
          return {
            { label = term .. "-note", kind = "filename", path = "/tmp/" .. term .. "-note.md" },
          }
        end,
      },
    }, function()
      source:complete({
        context = {
          bufnr = bufnr,
          cursor_before_line = "how",
          cursor = { col = 4, row = 1 },
        },
      }, function(res)
        first_result = res
      end)

      source:complete({
        context = {
          bufnr = bufnr,
          cursor_before_line = "ai-",
          cursor = { col = 4, row = 1 },
        },
      }, function(res)
        second_result = res
      end)

      vim.wait(1000, function()
        return first_result ~= nil and second_result ~= nil
      end, 20)
    end)

    assert.is_true(first_result.isIncomplete)
    assert.is_nil(first_result.items)
    assert.equals("[[ai--note]]", second_result.items[1].textEdit.newText)
  end)
end)
