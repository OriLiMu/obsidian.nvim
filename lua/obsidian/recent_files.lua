local util = require "obsidian.util"
local log = require "obsidian.log"

local M = {}

-- 创建一个用于最近文件列表的augroup
local recent_files_group = vim.api.nvim_create_augroup("ObsidianRecentFiles", { clear = true })

-- 存储最近文件列表的全局变量
M.recent_files = {}
-- 存储侧边栏窗口ID和缓冲区ID
M.sidebar = {
  links_win = nil,
  links_buf = nil,
  backlinks_win = nil,
  backlinks_buf = nil,
  recent_files_win = nil,
  recent_files_buf = nil,
}

-- 创建一个函数来更新最近文件列表
function M.update_recent_files_window(client)
  -- 获取配置
  local opts = client.opts.recent_files

  -- 如果未启用功能，直接返回
  if not opts.enabled then
    return
  end

  -- 查找最近文件窗口的缓冲区
  local recent_buf = nil
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_valid(buf) then
      local name = vim.api.nvim_buf_get_name(buf)
      if name:match "Recent Files$" then
        recent_buf = buf
        break
      end
    end
  end

  if not recent_buf then
    return
  end

  -- 获取当前文件路径
  local current_file = vim.fn.expand "%:p"

  -- 获取所有打开的 markdown 缓冲区
  local markdown_buffers = {}
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_valid(buf) then
      local name = vim.api.nvim_buf_get_name(buf)
      if name:match "%.md$" and name ~= "" and not name:match "Recent Files$" and name ~= "/tmp/ai_chat.md" then
        table.insert(markdown_buffers, name)
      end
    end
  end

  -- 重新排序 markdown_buffers，把当前文件放在第一位
  M.recent_files = {}
  -- 先添加当前文件（如果是 markdown 文件）
  if
    current_file:match "%.md$"
    and current_file ~= ""
    and not current_file:match "Recent Files$"
    and current_file ~= "/tmp/ai_chat.md"
  then
    table.insert(M.recent_files, current_file)
  end

  -- 添加其他打开的 markdown 文件
  for _, file in ipairs(markdown_buffers) do
    if file ~= current_file then
      table.insert(M.recent_files, file)
      if #M.recent_files >= opts.max_files then
        break
      end
    end
  end

  -- 如果还没有达到max_files个文件，从 oldfiles 添加其他最近的 markdown 文件
  if #M.recent_files < opts.max_files then
    for _, file in ipairs(vim.v.oldfiles) do
      if file:match "%.md$" and file ~= "/tmp/ai_chat.md" and not vim.tbl_contains(M.recent_files, file) then
        table.insert(M.recent_files, file)
        if #M.recent_files >= opts.max_files then
          break
        end
      end
    end
  end

  -- 准备显示内容
  local content = {
    "󱔗 Recent Files",
    "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━",
  }

  for i, file in ipairs(M.recent_files) do
    -- 只获取文件名，不包含路径
    local display_name = vim.fn.fnamemodify(file, ":t")
    -- 添加序号
    local prefix = string.format("%d", i)
    -- 使用统一的格式，不添加任何图标
    table.insert(content, string.format("%d %s", i, display_name))
  end

  -- 设置缓冲区为可修改
  vim.api.nvim_buf_set_option(recent_buf, "modifiable", true)
  -- 更新内容
  vim.api.nvim_buf_set_lines(recent_buf, 0, -1, false, content)
  -- 设置回只读
  vim.api.nvim_buf_set_option(recent_buf, "modifiable", false)

  -- 设置语法高亮
  vim.api.nvim_buf_call(recent_buf, function()
    vim.cmd [[
      syntax clear
      syntax match RecentFileTitle /^󱔗 Recent Files$/
      syntax match RecentFileDivider /^━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━$/
      syntax match RecentFileNumber /^\d/
      syntax match RecentFilePath /.*$/
      syntax match RecentFileFirst /^1.*$/

      highlight RecentFileTitle guifg=#7aa2f7 gui=bold
      highlight RecentFileDivider guifg=#3b4261
      highlight RecentFileNumber guifg=#737aa2
      highlight RecentFilePath guifg=#a9b1d6
      highlight RecentFileFirst guifg=#111111 guibg=#7FDBFF
    ]]
  end)
end

-- 更新Links窗口内容
function M.update_links_window(client)
  local links_buf = M.sidebar.links_buf
  if not links_buf or not vim.api.nvim_buf_is_valid(links_buf) then
    return
  end

  -- 获取当前文件中的所有链接
  local links = {}
  local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
  local search = require "obsidian.search"
  local iter = require("obsidian.itertools").iter
  local enumerate = require("obsidian.itertools").enumerate

  for lnum, line in enumerate(lines) do
    for match in iter(search.find_refs(line, { include_naked_urls = true, include_file_urls = true })) do
      local m_start, m_end = unpack(match)
      local link = string.sub(line, m_start, m_end)
      if not links[link] then
        links[link] = { text = link, line = lnum + 1 }
      end
    end
  end

  -- 准备显示内容
  local content = {
    " Links",
    "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━",
  }

  local sorted_links = {}
  for _, link_data in pairs(links) do
    table.insert(sorted_links, link_data)
  end

  table.sort(sorted_links, function(a, b)
    return a.line < b.line
  end)

  for i, link_data in ipairs(sorted_links) do
    -- 显示链接文本，最多显示30个字符
    local display_text = link_data.text
    if #display_text > 30 then
      display_text = display_text:sub(1, 27) .. "..."
    end
    table.insert(content, display_text)
  end

  if #content == 2 then
    table.insert(content, "No links found")
  end

  -- 设置缓冲区为可修改
  vim.api.nvim_buf_set_option(links_buf, "modifiable", true)
  -- 更新内容
  vim.api.nvim_buf_set_lines(links_buf, 0, -1, false, content)
  -- 设置回只读
  vim.api.nvim_buf_set_option(links_buf, "modifiable", false)

  -- 设置语法高亮
  vim.api.nvim_buf_call(links_buf, function()
    vim.cmd [[
      syntax clear
      syntax match LinksTitle /^ Links$/
      syntax match LinksDivider /^━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━$/
      syntax match LinksNoLinks /^No links found$/
      syntax match LinksPath /.*$/

      highlight LinksTitle guifg=#7dcfff gui=bold
      highlight LinksDivider guifg=#3b4261
      highlight LinksNoLinks guifg=#737aa2
      highlight LinksPath guifg=#a9b1d6
    ]]
  end)
end

-- 更新Backlinks窗口内容
function M.update_backlinks_window(client)
  local backlinks_buf = M.sidebar.backlinks_buf
  if not backlinks_buf or not vim.api.nvim_buf_is_valid(backlinks_buf) then
    return
  end

  -- 准备显示内容
  local content = {
    " Backlinks",
    "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━",
  }

  -- 获取当前笔记
  local note = client:current_note(0)
  if not note then
    table.insert(content, "Not in a note")
  else
    -- 异步查找反向链接
    client:find_backlinks_async(note, function(backlinks)
      if vim.tbl_isempty(backlinks) then
        table.insert(content, "No backlinks found")
      else
        for _, backlink in ipairs(backlinks) do
          -- 获取文件名（不包含路径）
          local display_name = vim.fn.fnamemodify(tostring(backlink.path), ":t")
          table.insert(content, display_name)
        end
      end

      -- 设置缓冲区为可修改
      if vim.api.nvim_buf_is_valid(backlinks_buf) then
        vim.api.nvim_buf_set_option(backlinks_buf, "modifiable", true)
        -- 更新内容
        vim.api.nvim_buf_set_lines(backlinks_buf, 0, -1, false, content)
        -- 设置回只读
        vim.api.nvim_buf_set_option(backlinks_buf, "modifiable", false)
      end
    end)
  end

  -- 设置缓冲区为可修改
  vim.api.nvim_buf_set_option(backlinks_buf, "modifiable", true)
  -- 先显示加载内容
  if #content == 2 then
    table.insert(content, "Loading backlinks...")
  end
  vim.api.nvim_buf_set_lines(backlinks_buf, 0, -1, false, content)
  -- 设置回只读
  vim.api.nvim_buf_set_option(backlinks_buf, "modifiable", false)

  -- 设置语法高亮
  vim.api.nvim_buf_call(backlinks_buf, function()
    vim.cmd [[
      syntax clear
      syntax match BacklinksTitle /^ Backlinks$/
      syntax match BacklinksDivider /^━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━$/
      syntax match BacklinksNoLinks /^No backlinks found$/
      syntax match BacklinksLoading /^Loading backlinks...$/
      syntax match BacklinksPath /.*$/

      highlight BacklinksTitle guifg=#bb9af7 gui=bold
      highlight BacklinksDivider guifg=#3b4261
      highlight BacklinksNoLinks guifg=#737aa2
      highlight BacklinksLoading guifg=#737aa2
      highlight BacklinksPath guifg=#a9b1d6
    ]]
  end)
end

-- 创建侧边栏窗口和缓冲区
function M.create_sidebar_windows(client, current_win)
  local opts = client.opts.recent_files
  if not opts.enabled then
    return false
  end

  -- 创建右侧边框
  vim.cmd "botright vsplit"
  local sidebar_win = vim.api.nvim_get_current_win()

  -- 使用vim命令直接强制设置宽度为20%
  vim.cmd "let &winwidth = 20"
  vim.cmd("vertical resize " .. math.floor(vim.o.columns * 0.2))

  -- 使用API再次确保宽度正确
  local initial_width = math.floor(vim.o.columns * 0.2)
  vim.api.nvim_win_set_width(sidebar_win, initial_width)

  -- 创建 Links 窗口（顶部）
  local links_buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_name(links_buf, "Links")
  vim.api.nvim_win_set_buf(sidebar_win, links_buf)
  M.sidebar.links_win = sidebar_win
  M.sidebar.links_buf = links_buf

  -- 设置 Links 缓冲区选项
  vim.api.nvim_buf_set_option(links_buf, "modifiable", false)
  vim.api.nvim_buf_set_option(links_buf, "buftype", "nofile")
  vim.api.nvim_buf_set_option(links_buf, "swapfile", false)
  vim.api.nvim_buf_set_option(links_buf, "filetype", "obsidian-links")
  vim.api.nvim_buf_set_option(links_buf, "bufhidden", "wipe")

  -- 设置 Links 窗口选项
  vim.api.nvim_win_set_option(sidebar_win, "number", false)
  vim.api.nvim_win_set_option(sidebar_win, "relativenumber", false)
  vim.api.nvim_win_set_option(sidebar_win, "signcolumn", "no")
  vim.api.nvim_win_set_option(sidebar_win, "wrap", false)
  vim.api.nvim_win_set_option(sidebar_win, "cursorline", true)
  vim.api.nvim_win_set_option(sidebar_win, "statusline", " 链接")

  -- 添加 Links 窗口键位映射
  vim.keymap.set("n", "<CR>", function()
    local line = vim.api.nvim_get_current_line()
    if
      line ~= " Links"
      and line ~= "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
      and line ~= "No links found"
    then
      -- 切换到主窗口
      vim.api.nvim_set_current_win(current_win)
      -- 在主窗口中打开链接
      client:follow_link_async(line)
    end
  end, { buffer = links_buf, silent = true })
  vim.keymap.set("n", "q", ":q<CR>", { buffer = links_buf, silent = true })

  -- 创建 Backlinks 窗口（中部）
  vim.cmd "split"
  local backlinks_win = vim.api.nvim_get_current_win()
  local backlinks_buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_name(backlinks_buf, "Backlinks")
  vim.api.nvim_win_set_buf(backlinks_win, backlinks_buf)
  M.sidebar.backlinks_win = backlinks_win
  M.sidebar.backlinks_buf = backlinks_buf

  -- 设置 Backlinks 缓冲区选项
  vim.api.nvim_buf_set_option(backlinks_buf, "modifiable", false)
  vim.api.nvim_buf_set_option(backlinks_buf, "buftype", "nofile")
  vim.api.nvim_buf_set_option(backlinks_buf, "swapfile", false)
  vim.api.nvim_buf_set_option(backlinks_buf, "filetype", "obsidian-backlinks")
  vim.api.nvim_buf_set_option(backlinks_buf, "bufhidden", "wipe")

  -- 设置 Backlinks 窗口选项
  vim.api.nvim_win_set_option(backlinks_win, "number", false)
  vim.api.nvim_win_set_option(backlinks_win, "relativenumber", false)
  vim.api.nvim_win_set_option(backlinks_win, "signcolumn", "no")
  vim.api.nvim_win_set_option(backlinks_win, "wrap", false)
  vim.api.nvim_win_set_option(backlinks_win, "cursorline", true)
  vim.api.nvim_win_set_option(backlinks_win, "statusline", " 反向链接")

  -- 添加 Backlinks 窗口键位映射
  vim.keymap.set("n", "<CR>", function()
    local line = vim.api.nvim_get_current_line()
    if
      line ~= " Backlinks"
      and line ~= "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
      and line ~= "No backlinks found"
      and line ~= "Loading backlinks..."
      and line ~= "Not in a note"
    then
      -- 获取当前笔记
      local note = client:current_note(0)
      if note then
        -- 搜索匹配的反向链接
        client:find_backlinks_async(note, function(backlinks)
          for _, backlink in ipairs(backlinks) do
            -- 获取文件名（不包含路径）
            local display_name = vim.fn.fnamemodify(tostring(backlink.path), ":t")
            if display_name == line then
              -- 切换到主窗口
              vim.api.nvim_set_current_win(current_win)
              -- 在主窗口中打开文件
              util.open_buffer(backlink.path)
              break
            end
          end
        end)
      end
    end
  end, { buffer = backlinks_buf, silent = true })
  vim.keymap.set("n", "q", ":q<CR>", { buffer = backlinks_buf, silent = true })

  -- 创建 Recent Files 窗口（底部）
  vim.cmd "split"
  local recent_files_win = vim.api.nvim_get_current_win()
  local recent_files_buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_name(recent_files_buf, "Recent Files")
  vim.api.nvim_win_set_buf(recent_files_win, recent_files_buf)
  M.sidebar.recent_files_win = recent_files_win
  M.sidebar.recent_files_buf = recent_files_buf

  -- 设置 Recent Files 缓冲区选项
  vim.api.nvim_buf_set_option(recent_files_buf, "modifiable", false)
  vim.api.nvim_buf_set_option(recent_files_buf, "buftype", "nofile")
  vim.api.nvim_buf_set_option(recent_files_buf, "swapfile", false)
  vim.api.nvim_buf_set_option(recent_files_buf, "filetype", "obsidian-recent-files")
  vim.api.nvim_buf_set_option(recent_files_buf, "bufhidden", "wipe")

  -- 设置 Recent Files 窗口选项
  vim.api.nvim_win_set_option(recent_files_win, "number", false)
  vim.api.nvim_win_set_option(recent_files_win, "relativenumber", false)
  vim.api.nvim_win_set_option(recent_files_win, "signcolumn", "no")
  vim.api.nvim_win_set_option(recent_files_win, "wrap", false)
  vim.api.nvim_win_set_option(recent_files_win, "cursorline", true)
  vim.api.nvim_win_set_option(recent_files_win, "statusline", " 最近文件")

  -- 添加 Recent Files 键位映射以打开文件
  vim.keymap.set("n", "<CR>", function()
    local line = vim.api.nvim_get_current_line()
    local file_index = tonumber(line:match "^(%d)")
    if file_index then
      -- 获取对应索引的文件
      if file_index > 0 and file_index <= #M.recent_files then
        local file = M.recent_files[file_index]
        if file and file:match "%.md$" then
          -- 切换到主窗口
          vim.api.nvim_set_current_win(current_win)
          -- 在主窗口打开选中的文件
          vim.cmd("edit " .. vim.fn.fnameescape(file))
        end
      end
    end
  end, { buffer = recent_files_buf, silent = true })

  -- 添加数字键映射以打开对应文件
  for i = 1, 9 do
    vim.keymap.set("n", tostring(i), function()
      if i <= #M.recent_files then
        local file = M.recent_files[i]
        if file and file:match "%.md$" then
          -- 切换到主窗口
          vim.api.nvim_set_current_win(current_win)
          -- 在主窗口打开选中的文件
          vim.cmd("edit " .. vim.fn.fnameescape(file))
        end
      end
    end, { buffer = recent_files_buf, silent = true })
  end

  -- 添加 q 键映射以关闭窗口
  vim.keymap.set("n", "q", ":q<CR>", { buffer = recent_files_buf, silent = true })

  -- 调整窗口大小，使三个窗口高度大致相等
  vim.cmd "wincmd ="

  -- 更新各个窗口的内容
  M.update_links_window(client)
  M.update_backlinks_window(client)
  M.update_recent_files_window(client)

  -- 返回到链接窗口
  vim.api.nvim_set_current_win(sidebar_win)

  return true
end

-- 初始化最近文件窗口功能
function M.setup(client)
  -- 获取配置
  local opts = client.opts.recent_files

  -- 如果未启用功能，直接返回
  if not opts.enabled then
    log.debug "最近文件功能未启用"
    return
  end

  log.debug "正在设置侧边栏窗口功能"

  -- 设置打开 Markdown 文件时显示侧边栏
  vim.api.nvim_create_autocmd("FileType", {
    group = recent_files_group,
    pattern = "markdown",
    desc = "在打开 Markdown 文件时显示侧边栏",
    callback = function()
      -- 如果是 /tmp/ai_chat.md，直接返回
      if vim.fn.expand "%:p" == "/tmp/ai_chat.md" then
        return
      end

      -- 检查是否在Obsidian工作区内
      local buf_dir = vim.fs.dirname(vim.fn.expand "%:p")
      local workspace = require("obsidian.workspace").get_workspace_for_dir(buf_dir, client.opts.workspaces)
      if not workspace then
        return
      end

      -- 检查是否已经存在侧边栏窗口
      for _, win in ipairs(vim.api.nvim_list_wins()) do
        local buf = vim.api.nvim_win_get_buf(win)
        if vim.api.nvim_buf_is_valid(buf) then
          local name = vim.api.nvim_buf_get_name(buf)
          if name:match "Links$" or name:match "Backlinks$" or name:match "Recent Files$" then
            return -- 如果已存在，直接返回
          end
        end
      end

      -- 保存当前窗口ID
      local current_win = vim.api.nvim_get_current_win()

      -- 创建侧边栏窗口
      M.create_sidebar_windows(client, current_win)

      -- 移回主窗口
      vim.api.nvim_set_current_win(current_win)
    end,
  })

  -- 添加自动命令以在切换缓冲区时更新侧边栏内容
  vim.api.nvim_create_autocmd({ "BufEnter", "BufWrite" }, {
    group = recent_files_group,
    pattern = "*.md",
    callback = function()
      vim.schedule(function()
        M.update_links_window(client)
        M.update_backlinks_window(client)
        M.update_recent_files_window(client)
      end)
    end,
  })

  -- 添加自动命令以在窗口大小改变时调整侧边栏窗口的宽度
  vim.api.nvim_create_autocmd("VimResized", {
    group = recent_files_group,
    callback = function()
      -- 查找侧边栏窗口（Links窗口是最外层窗口）
      for _, win in ipairs(vim.api.nvim_list_wins()) do
        local buf = vim.api.nvim_win_get_buf(win)
        local name = vim.api.nvim_buf_get_name(buf)
        if name:match "Links$" then
          -- 当窗口大小调整时，强制设置为20%
          vim.api.nvim_set_current_win(win)
          vim.cmd("vertical resize " .. math.floor(vim.o.columns * 0.2))

          -- 使用API再次确保宽度正确
          local resize_width = math.floor(vim.o.columns * 0.2)
          vim.api.nvim_win_set_width(win, resize_width)

          -- 回到原来的窗口
          vim.cmd "wincmd p"
          break
        end
      end
    end,
  })
end

-- 关闭所有侧边栏窗口
function M.close_sidebar_windows()
  -- 关闭所有匹配的窗口
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    if vim.api.nvim_win_is_valid(win) then
      local buf = vim.api.nvim_win_get_buf(win)
      local name = vim.api.nvim_buf_get_name(buf)
      if name:match "Links$" or name:match "Backlinks$" or name:match "Recent Files$" then
        vim.api.nvim_win_close(win, true)
      end
    end
  end

  -- 清空记录的窗口ID和缓冲区ID
  M.sidebar = {
    links_win = nil,
    links_buf = nil,
    backlinks_win = nil,
    backlinks_buf = nil,
    recent_files_win = nil,
    recent_files_buf = nil,
  }

  return true
end

-- 手动打开侧边栏窗口
function M.open_sidebar_windows(client)
  -- 如果已经存在，先关闭
  M.close_sidebar_windows()

  -- 获取配置
  local opts = client.opts.recent_files

  -- 如果未启用功能，直接返回
  if not opts.enabled then
    log.debug "侧边栏功能未启用"
    return
  end

  -- 保存当前窗口ID
  local current_win = vim.api.nvim_get_current_win()

  -- 创建侧边栏窗口
  M.create_sidebar_windows(client, current_win)

  -- 移回主窗口
  vim.api.nvim_set_current_win(current_win)

  return true
end

-- 切换侧边栏窗口的可见状态
function M.toggle_sidebar_windows(client)
  if not M.close_sidebar_windows() then
    M.open_sidebar_windows(client)
  end
end

-- 为向后兼容性保留的函数
function M.close_recent_files_window()
  return M.close_sidebar_windows()
end

function M.open_recent_files_window(client)
  return M.open_sidebar_windows(client)
end

function M.toggle_recent_files_window(client)
  return M.toggle_sidebar_windows(client)
end

return M
