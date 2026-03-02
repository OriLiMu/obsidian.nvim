local Client = require "obsidian.client"
local Path = require "obsidian.path"
local search = require "obsidian.search"
local util = require "obsidian.util"

describe("Client.follow_link_async()", function()
  it("should replace '/' with '-' before creating a new note", function()
    local created_id = nil
    local tmp_dir = Path.temp { suffix = "-obsidian" }
    tmp_dir:mkdir { parents = true, exist_ok = true }

    local client = {
      dir = tmp_dir,
      opts = { checkbox_new_note_dir = "tasks" },
    }

    client.resolve_link_async = function(_, _, callback)
      callback {
        location = "apple /pear",
        name = "apple /pear",
        link_type = search.RefTypes.Wiki,
      }
    end

    client.create_note = function(_, opts)
      created_id = opts.id
      return { path = tmp_dir / "apple-pear.md" }
    end

    client.open_note = function(_, _, _)
      return true
    end

    local original_confirm = util.confirm
    local original_is_checkbox_task_line = util.is_checkbox_task_line

    local ok, err = pcall(function()
      util.confirm = function(_)
        return true
      end

      util.is_checkbox_task_line = function(_)
        return true
      end

      Client.follow_link_async(client, "[[apple /pear]]")

      local done = vim.wait(1000, function()
        return created_id ~= nil
      end, 10)

      assert.is_true(done)
      assert.equals("apple -pear", created_id)
    end)

    util.confirm = original_confirm
    util.is_checkbox_task_line = original_is_checkbox_task_line
    tmp_dir:rmtree()

    if not ok then
      error(err)
    end
  end)
end)
