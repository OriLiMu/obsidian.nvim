---@diagnostic disable: invisible

local ai_translate = require "obsidian.ai_translate"
local Note = require "obsidian.note"

describe("ai_translate module", function()
  describe("contains_chinese()", function()
    it("should detect Chinese characters", function()
      assert.is_true(ai_translate.contains_chinese "吃苹果")
      assert.is_true(ai_translate.contains_chinese "测试test")
      assert.is_true(ai_translate.contains_chinese "你好世界")
    end)

    it("should return false for non-Chinese", function()
      assert.is_false(ai_translate.contains_chinese "hello")
      assert.is_false(ai_translate.contains_chinese "test123")
      assert.is_false(ai_translate.contains_chinese "")
      assert.is_false(ai_translate.contains_chinese(nil))
    end)
  end)

  describe("extract_translate_text()", function()
    it("should extract Chinese text from number_prefix pattern", function()
      local text, prefix = ai_translate.extract_translate_text "31_下一个排列"
      assert.equals("下一个排列", text)
      assert.equals("31_", prefix)
    end)

    it("should extract Chinese text from multi-digit prefix", function()
      local text, prefix = ai_translate.extract_translate_text "123_测试文本"
      assert.equals("测试文本", text)
      assert.equals("123_", prefix)
    end)

    it("should return full text for pure Chinese", function()
      local text, prefix = ai_translate.extract_translate_text "吃苹果"
      assert.equals("吃苹果", text)
      assert.is_nil(prefix)
    end)

    it("should handle edge cases", function()
      local text, prefix = ai_translate.extract_translate_text ""
      assert.equals("", text)
      assert.is_nil(prefix)

      local text2, prefix2 = ai_translate.extract_translate_text(nil)
      assert.equals("", text2)
      assert.is_nil(prefix2)
    end)
  end)

  describe("format_alias()", function()
    it("should format translation to alias", function()
      assert.equals("eat-apple", ai_translate.format_alias "eat apple")
      assert.equals("hello-world", ai_translate.format_alias "Hello World")
      assert.equals("eat-an-apple", ai_translate.format_alias "Eat an apple.")
    end)

    it("should format with prefix", function()
      assert.equals("31-next-permutation", ai_translate.format_alias("next permutation", "31_"))
      assert.equals("123-test-text", ai_translate.format_alias("test text", "123_"))
    end)

    it("should handle edge cases", function()
      assert.equals("", ai_translate.format_alias(nil))
      assert.equals("", ai_translate.format_alias "")
    end)
  end)

  describe("translate()", function()
    it("should translate Chinese to English", function()
      -- Skip if no API key
      if os.getenv "OBSIDIAN_AI_API_KEY" == nil then
        print "Skipping translate test - no API key"
        return
      end

      local result = ai_translate.translate("吃苹果", {
        api_url = "https://open.bigmodel.cn/api/coding/paas/v4/chat/completions",
        api_key = os.getenv "OBSIDIAN_AI_API_KEY",
        model = "glm-4.5-flash",
        timeout = 15000,
      })

      assert.is_not_nil(result)
      assert.is_true(string.find(result:lower(), "apple") ~= nil)
    end)
  end)
end)

describe("Note.needs_aliases_translation()", function()
  it("should return true for Chinese id with empty aliases", function()
    local note = Note.new("吃苹果", {}, {})
    assert.is_true(note:needs_aliases_translation())
  end)

  it("should return true for number_prefix Chinese id", function()
    local note = Note.new("31_下一个排列", {}, {})
    assert.is_true(note:needs_aliases_translation())
  end)

  it("should return false for non-Chinese id", function()
    local note = Note.new("hello", {}, {})
    assert.is_false(note:needs_aliases_translation())
  end)

  it("should return false when aliases not empty", function()
    local note = Note.new("吃苹果", { "existing-alias" }, {})
    assert.is_false(note:needs_aliases_translation())
  end)
end)
