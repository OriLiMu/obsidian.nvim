# TODO

- [x] 新增 `completion.known_notes.alias_insert_filename` 配置项（默认 `true`）
- [x] 调整 `cmp_obsidian_known_notes`：alias 候选显示 alias、确认写入 filename
- [x] 补充/更新单元测试（配置默认值与 known_notes 补全行为）
- [x] 更新 README 与 `doc/obsidian.txt` 配置文档
- [x] 运行相关测试并记录结果

## 修复 `[[note#]]` 补全误告警

- [x] 定位 `[[note#]]` 触发 “already exists” 告警的调用链与判断条件
- [x] 修正 `cmp_obsidian_new` 对未完成锚点链接的处理，避免误走新建笔记逻辑
- [x] 补充回归测试，覆盖中文路径与尾随 `#` 场景
- [x] 运行相关测试并记录结果

验证结果：
- [x] `test/obsidian/cmp_obsidian_new_spec.lua`
- [x] `test/obsidian/util_spec.lua`

## 忽略首个 Heading 1 参与 `follow link` 解析

- [x] 定位 `ObsidianFollowLink` 命中的引用标识集合，确认首个 H1 的进入点
- [x] 补充回归测试，覆盖忽略首个 H1 且保留 `id`、`alias`、文件名匹配
- [x] 调整引用标识生成逻辑，移除首个 H1 参与 note 解析
- [x] 运行相关测试并记录结果

验证结果：
- [x] `test/obsidian/resolve_note_spec.lua`
- [x] `test/obsidian/follow_link_spec.lua`
- [x] `test/obsidian/note_spec.lua`

## 排查“按笔记名 / 别名补全并插入 Markdown 链接”相关代码

- [x] 定位 `[[...]]` / `[...](...)` 上下文引用补全入口
- [x] 定位普通文本中的已知笔记补全入口
- [x] 阅读链接格式化实现，确认最终插入文本由谁生成
- [x] 整理后续修正可切入的代码路径

## 修复中文前缀下 known_notes 补全未删除触发词

- [x] 确认问题根因是 `textEdit.range` 被 `nvim-cmp` 按默认 UTF-16 误解
- [x] 为 `cmp_obsidian_known_notes` 显式声明 UTF-8 position encoding
- [x] 补充中文前缀回归测试与编码约束测试
- [x] 运行相关测试并记录结果

验证结果：
- [x] `make test TEST=test/obsidian/cmp_obsidian_known_notes_spec.lua`
- [x] `make test TEST=test/obsidian/config_spec.lua`
