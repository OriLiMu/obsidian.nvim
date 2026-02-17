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

--- Translate text using AI API
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
    require("obsidian.log").warn("[ai_translate] API key not configured")
    return nil
  end

  local log = require("obsidian.log")
  log.debug("[ai_translate] Translating: %s", text)
  vim.notify("[Obsidian AI] Translating: " .. text, vim.log.levels.INFO)

  local body = vim.json.encode({
    model = model,
    messages = {
      {
        role = "user",
        content = "Translate the following Chinese text to English. Only output the English translation, nothing else. Text: " .. text,
      },
    },
    stream = false,
  })

  local result = vim.system({
    "curl",
    "-s",
    "-X",
    "POST",
    "-H",
    "Authorization: Bearer " .. api_key,
    "-H",
    "Content-Type: application/json",
    "-d",
    body,
    "--connect-timeout",
    tostring(math.floor(timeout / 1000)),
    "-m",
    tostring(math.floor(timeout / 1000)),
    url,
  }, { timeout = timeout })

  if result.code ~= 0 then
    log.err("[ai_translate] curl failed with code %d: %s", result.code, result.stderr)
    vim.notify("[Obsidian AI] Translation failed: curl error", vim.log.levels.ERROR)
    return nil
  end

  local response = result.stdout
  log.debug("[ai_translate] Response: %s", response)

  local ok, data = pcall(vim.json.decode, response)
  if not ok or not data then
    log.err("[ai_translate] Failed to parse JSON response: %s", response)
    vim.notify("[Obsidian AI] Failed to parse response", vim.log.levels.ERROR)
    return nil
  end

  local translated = data.choices and data.choices[1] and data.choices[1].message and data.choices[1].message.content

  if not translated then
    log.err("[ai_translate] No translation in response: %s", response)
    vim.notify("[Obsidian AI] No translation found in response", vim.log.levels.ERROR)
    return nil
  end

  -- Clean up the translation (remove quotes, extra whitespace)
  translated = translated:gsub('^"+', ""):gsub('"+$', ""):gsub("^%s+", ""):gsub("%s+$", "")

  log.debug("[ai_translate] Translated: %s -> %s", text, translated)
  vim.notify("[Obsidian AI] Translated: " .. text .. " -> " .. translated, vim.log.levels.INFO)

  return translated
end

--- Format translated text as alias (lowercase, spaces to hyphens)
---@param translated_text string
---@return string
M.format_alias = function(translated_text)
  if not translated_text then
    return ""
  end
  local result = translated_text:lower():gsub("%s+", "-"):gsub("[^%w%-]", "")
  return result
end

return M
