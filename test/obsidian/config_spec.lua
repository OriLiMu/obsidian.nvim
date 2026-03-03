local config = require "obsidian.config"

describe("config.ClientOpts.default()", function()
  it("should disable ai translate by default", function()
    local opts = config.ClientOpts.default()
    assert.is_false(opts.ai_translate.enabled)
  end)
end)
