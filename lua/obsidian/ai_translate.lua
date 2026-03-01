---@class obsidian.AITranslate
local M = {}

--- Check if string contains Chinese characters
---@param str string
---@return boolean
M.contains_chinese = function(str)
  if not str then
    return false
  end
  -- Match Chinese character ranges
  return string.match(str, "[\228-\233][\128-\191][\128-\191]") ~= nil
end

--- Extract text to translate from id
--- If id is like "31_下一个排列", return "下一个排列" and prefix "31_"
--- If id is like "吃苹果", return "吃苹果" and prefix nil
---@param id string
---@return string text_to_translate, string|nil prefix
M.extract_translate_text = function(id)
  if not id then
    return "", nil
  end

  -- Check for pattern: number + underscore + text
  local prefix, text = id:match("^(%d+_)(.+)$")
  if prefix and text and M.contains_chinese(text) then
    return text, prefix
  end

  -- No prefix pattern, return full id
  return id, nil
end

--- Format translated text as alias (lowercase, spaces to hyphens)
---@param translated_text string
---@param prefix string|nil Optional prefix to prepend (e.g., "31_")
---@return string
M.format_alias = function(translated_text, prefix)
  if not translated_text then
    return ""
  end
  local result = translated_text:lower():gsub("%s+", "-"):gsub("[^%w%-]", "")

  -- Add prefix if present (convert "31_" to "31-")
  if prefix then
    local clean_prefix = prefix:gsub("_$", "-")
    result = clean_prefix .. result
  end

  return result
end

--- Check if alias needs formatting (contains spaces)
---@param alias string
---@return boolean
M.needs_formatting = function(alias)
  if not alias or alias == "" then
    return false
  end
  return alias:match("%s") ~= nil
end

--- Convert string to Title-Case-With-Hyphens
--- Example: "How to break down notes" -> "How-To-Break-Down-Notes"
---@param str string
---@return string
M.format_alias_title_case = function(str)
  if not str or str == "" then
    return ""
  end

  -- Split by spaces
  local words = {}
  for word in str:gmatch("%S+") do
    -- Capitalize first letter of each word
    local capitalized = word:sub(1, 1):upper() .. word:sub(2):lower()
    table.insert(words, capitalized)
  end

  -- Join with hyphens
  return table.concat(words, "-")
end

--- Format all aliases in a note that contain spaces
---@param aliases string[]
---@return string[] formatted_aliases
M.format_aliases = function(aliases)
  if not aliases then
    return {}
  end

  local formatted = {}
  for _, alias in ipairs(aliases) do
    if M.needs_formatting(alias) then
      table.insert(formatted, M.format_alias_title_case(alias))
    else
      table.insert(formatted, alias)
    end
  end

  return formatted
end

--- Translate text using AI API (synchronous - blocks)
---@param text string Text to translate
---@param opts { api_url: string, api_key: string, model: string, timeout: integer }
---@return string|nil translated_text
M.translate = function(text, opts)
  if not text or text == "" then
    return nil
  end

  local url = opts.api_url or "https://open.bigmodel.cn/api/coding/paas/v4/chat/completions"
  local api_key = opts.api_key
  local model = opts.model or "glm-4.5-flash"
  local timeout = opts.timeout or 10000

  if not api_key or api_key == "" then
    return nil
  end

  local log = require("obsidian.log")

  -- Build the JSON body
  local prompt = "Translate the following Chinese text to English. Only output the English translation, nothing else. Text: " .. text
  local body = vim.json.encode({
    model = model,
    messages = {
      { role = "user", content = prompt },
    },
    stream = false,
  })

  -- Write body to temp file to avoid shell escaping issues
  local tmp_file = vim.fn.tempname()
  vim.fn.writefile({ body }, tmp_file)

  -- Build curl command as string for io.popen
  local timeout_sec = math.floor(timeout / 1000)
  local curl_cmd = string.format(
    'curl -s -X POST -H "Authorization: Bearer %s" -H "Content-Type: application/json" -d @%s --connect-timeout %d -m %d "%s"',
    api_key, tmp_file, timeout_sec, timeout_sec + 5, url
  )

  local handle = io.popen(curl_cmd)
  local response = nil

  if handle then
    response = handle:read("*a")
    handle:close()
  end

  -- Clean up temp file
  vim.fn.delete(tmp_file)

  if not response or response == "" then
    log.err("[ai_translate] curl returned empty response")
    return nil
  end

  local ok, data = pcall(vim.json.decode, response)
  if not ok or not data then
    log.err("[ai_translate] Failed to parse JSON response")
    return nil
  end

  local translated = data.choices and data.choices[1] and data.choices[1].message and data.choices[1].message.content

  if not translated then
    log.err("[ai_translate] No translation in response")
    return nil
  end

  -- Clean up the translation (remove quotes, extra whitespace)
  translated = translated:gsub('^"+', ""):gsub('"+$', ""):gsub("^%s+", ""):gsub("%s+$", "")

  return translated
end

--- Translate text using AI API (asynchronous - non-blocking)
---@param text string Text to translate
---@param opts { api_url: string, api_key: string, model: string, timeout: integer }
---@param callback fun(translated: string|nil) Callback function called with translation result
M.translate_async = function(text, opts, callback)
  if not text or text == "" then
    callback(nil)
    return
  end

  local url = opts.api_url or "https://open.bigmodel.cn/api/coding/paas/v4/chat/completions"
  local api_key = opts.api_key
  local model = opts.model or "glm-4.5-flash"
  local timeout = opts.timeout or 10000

  if not api_key or api_key == "" then
    callback(nil)
    return
  end

  local log = require("obsidian.log")

  -- Build the JSON body
  local prompt = "Translate the following Chinese text to English. Only output the English translation, nothing else. Text: " .. text
  local body = vim.json.encode({
    model = model,
    messages = {
      { role = "user", content = prompt },
    },
    stream = false,
  })

  -- Write body to temp file
  local tmp_file = vim.fn.tempname()
  vim.fn.writefile({ body }, tmp_file)

  local timeout_sec = math.floor(timeout / 1000)

  -- Use vim.loop (vim.uv) for async execution
  local uv = vim.loop or vim.uv

  local stdout = uv.new_pipe()
  local stderr = uv.new_pipe()

  local curl_args = {
    "-s", "-X", "POST",
    "-H", "Authorization: Bearer " .. api_key,
    "-H", "Content-Type: application/json",
    "-d", "@" .. tmp_file,
    "--connect-timeout", tostring(timeout_sec),
    "-m", tostring(timeout_sec + 5),
    url,
  }

  local response_data = {}

  local handle
  handle = uv.spawn("curl", {
    args = curl_args,
    stdio = { nil, stdout, stderr },
  }, function(code, signal)
    -- Cleanup uv handles
    uv.close(handle)
    uv.close(stdout)
    uv.close(stderr)

    vim.schedule(function()
      -- Delete temp file in scheduled context
      vim.fn.delete(tmp_file)

      if code ~= 0 then
        log.err("[ai_translate] Translation failed")
        callback(nil)
        return
      end

      local response = table.concat(response_data)
      if not response or response == "" then
        log.err("[ai_translate] Empty response")
        callback(nil)
        return
      end

      local ok, data = pcall(vim.json.decode, response)
      if not ok or not data then
        log.err("[ai_translate] Failed to parse response")
        callback(nil)
        return
      end

      local translated = data.choices and data.choices[1] and data.choices[1].message and data.choices[1].message.content

      if not translated then
        log.err("[ai_translate] No translation in response")
        callback(nil)
        return
      end

      -- Clean up the translation
      translated = translated:gsub('^"+', ""):gsub('"+$', ""):gsub("^%s+", ""):gsub("%s+$", "")

      callback(translated)
    end)
  end)

  if not handle then
    log.err("[ai_translate] Failed to spawn curl")
    vim.fn.delete(tmp_file)
    callback(nil)
    return
  end

  -- Read stdout
  uv.read_start(stdout, function(err, data)
    if data then
      table.insert(response_data, data)
    end
  end)

  -- Read stderr (ignore)
  uv.read_start(stderr, function(err, data) end)
end

return M
