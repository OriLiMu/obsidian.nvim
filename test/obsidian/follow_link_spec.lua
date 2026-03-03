local Client = require "obsidian.client"
local Path = require "obsidian.path"
local search = require "obsidian.search"
local util = require "obsidian.util"

describe("Client.follow_link_async()", function()
  local function make_client(tmp_dir)
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

    client.open_note = function(_, _, _)
      return true
    end

    return client
  end

  it("should create directly in checkbox_new_note_dir when direct mode is selected", function()
    local created_id, created_dir, created_tags = nil, nil, nil
    local tmp_dir = Path.temp { suffix = "-obsidian" }
    tmp_dir:mkdir { parents = true, exist_ok = true }

    local client = make_client(tmp_dir)

    client.create_note = function(_, opts)
      created_id = opts.id
      created_dir = opts.dir
      created_tags = opts.tags
      return { path = tmp_dir / "apple-pear.md" }
    end

    local original_confirm = util.confirm
    local original_is_checkbox_task_line = util.is_checkbox_task_line
    local original_select = vim.ui.select

    local ok, err = pcall(function()
      util.confirm = function(_)
        return true
      end

      util.is_checkbox_task_line = function(_)
        return true
      end

      vim.ui.select = function(items, _, callback)
        callback(items[1])
      end

      Client.follow_link_async(client, "[[apple /pear]]")

      local done = vim.wait(1000, function()
        return created_id ~= nil
      end, 10)

      assert.is_true(done)
      assert.equals("apple -pear", created_id)
      assert.equals(tostring(tmp_dir / "tasks"), tostring(created_dir))
      assert.same({ "task" }, created_tags)
    end)

    util.confirm = original_confirm
    util.is_checkbox_task_line = original_is_checkbox_task_line
    vim.ui.select = original_select
    tmp_dir:rmtree()

    if not ok then
      error(err)
    end
  end)

  it("should create in selected folder when folder mode is selected on checkbox line", function()
    local created_dir, created_tags = nil, nil
    local fzf_called = false
    local tmp_dir = Path.temp { suffix = "-obsidian" }
    local projects_dir = tmp_dir / "projects"
    projects_dir:mkdir { parents = true, exist_ok = true }

    local client = make_client(tmp_dir)

    client.create_note = function(_, opts)
      created_dir = opts.dir
      created_tags = opts.tags
      return { path = tmp_dir / "projects" / "apple-pear.md" }
    end

    local original_confirm = util.confirm
    local original_is_checkbox_task_line = util.is_checkbox_task_line
    local original_select = vim.ui.select
    local original_fzf = package.loaded["fzf-lua"]

    local ok, err = pcall(function()
      util.confirm = function(_)
        return true
      end

      util.is_checkbox_task_line = function(_)
        return true
      end

      vim.ui.select = function(items, _, callback)
        callback(items[2])
      end

      package.loaded["fzf-lua"] = {
        fzf_exec = function(_, opts)
          fzf_called = true
          opts.actions["default"] { "projects" }
        end,
      }

      Client.follow_link_async(client, "[[apple /pear]]")

      local done = vim.wait(1000, function()
        return created_dir ~= nil
      end, 10)

      assert.is_true(done)
      assert.is_true(fzf_called)
      assert.equals(tostring(projects_dir), tostring(created_dir))
      assert.same({ "task" }, created_tags)
    end)

    util.confirm = original_confirm
    util.is_checkbox_task_line = original_is_checkbox_task_line
    vim.ui.select = original_select
    package.loaded["fzf-lua"] = original_fzf
    tmp_dir:rmtree()

    if not ok then
      error(err)
    end
  end)

  it("should abort when creation mode selection is cancelled", function()
    local create_note_called = false
    local select_called = false
    local tmp_dir = Path.temp { suffix = "-obsidian" }
    tmp_dir:mkdir { parents = true, exist_ok = true }

    local client = make_client(tmp_dir)

    client.create_note = function(_, _)
      create_note_called = true
      return nil
    end

    local original_confirm = util.confirm
    local original_is_checkbox_task_line = util.is_checkbox_task_line
    local original_select = vim.ui.select

    local ok, err = pcall(function()
      util.confirm = function(_)
        return true
      end

      util.is_checkbox_task_line = function(_)
        return true
      end

      vim.ui.select = function(_, _, callback)
        select_called = true
        callback(nil)
      end

      Client.follow_link_async(client, "[[apple /pear]]")

      local done = vim.wait(1000, function()
        return select_called
      end, 10)

      assert.is_true(done)
      assert.is_false(create_note_called)
    end)

    util.confirm = original_confirm
    util.is_checkbox_task_line = original_is_checkbox_task_line
    vim.ui.select = original_select
    tmp_dir:rmtree()

    if not ok then
      error(err)
    end
  end)

  it("should not crash when is_checkbox_task_line is missing", function()
    local created_dir, created_tags = nil, nil
    local fzf_called = false
    local tmp_dir = Path.temp { suffix = "-obsidian" }
    tmp_dir:mkdir { parents = true, exist_ok = true }

    local client = make_client(tmp_dir)

    client.create_note = function(_, opts)
      created_dir = opts.dir
      created_tags = opts.tags
      return { path = tmp_dir / "apple-pear.md" }
    end

    local original_confirm = util.confirm
    local original_is_checkbox_task_line = util.is_checkbox_task_line
    local original_fzf = package.loaded["fzf-lua"]

    local ok, err = pcall(function()
      util.confirm = function(_)
        return true
      end

      util.is_checkbox_task_line = nil

      package.loaded["fzf-lua"] = {
        fzf_exec = function(_, opts)
          fzf_called = true
          opts.actions["default"] { "." }
        end,
      }

      Client.follow_link_async(client, "[[apple /pear]]")

      local done = vim.wait(1000, function()
        return created_dir ~= nil
      end, 10)

      assert.is_true(done)
      assert.is_true(fzf_called)
      assert.equals(tostring(tmp_dir), tostring(created_dir))
      assert.equals(nil, created_tags)
    end)

    util.confirm = original_confirm
    util.is_checkbox_task_line = original_is_checkbox_task_line
    package.loaded["fzf-lua"] = original_fzf
    tmp_dir:rmtree()

    if not ok then
      error(err)
    end
  end)
end)
