## Context

当前 `cmp_obsidian` 引用补全依赖 `obsidian.completion.refs`，只会在输入 `[` 或 `[[` 语境下触发；这与“任意位置输入达到最小长度即可触发”的目标不一致。现有 `find_notes_async` 路径基于异步搜索与按需加载笔记，无法保证“查询仅使用内存索引、按键时不做全盘扫描”的约束。

本变更需要在不破坏现有链接补全行为的前提下，新增一条独立能力链路：仅在 Markdown buffer 生效、基于 `notes_root` 的 Markdown 文件名与 aliases 建立索引、前缀匹配并插入 `[[...]]`。

## Goals / Non-Goals

**Goals:**
- 在 Markdown buffer 中输入达到 `min_chars`（默认 3）后触发“已知笔记”候选，不要求先输入 `[[`。
- 候选仅来自 `notes_root` 下 `*.md`：文件名（去扩展名）与 frontmatter `aliases`。
- 查询走内存索引，支持前缀匹配与大小写配置；默认不区分大小写。
- 选择候选后替换当前词并插入 `[[候选文本]]`。
- 对 frontmatter 缺失/异常具备容错；`notes_root` 不可用时禁用能力并明确提示。
- 索引启动时构建一次，并在 Markdown 文件新增/删除/保存后做增量更新。

**Non-Goals:**
- 不做全文内容搜索。
- 不做跨仓库或远程索引。
- 不重写历史已有链接。

## Decisions

### 1. 新增独立 nvim-cmp source，而不是改写现有 refs source
- 决策：新增独立 source（例如 `cmp_obsidian_known_notes`），仅负责“裸词 -> `[[...]]`”补全。
- 原因：现有 refs source 强绑定 `[` 语义和 wiki/markdown 双链接风格，直接改写会引入行为耦合与回归风险。
- 备选：在 `obsidian.completion.refs` 中放宽触发条件。放弃原因是会污染既有链接解析逻辑。

### 2. 引入专用内存索引服务 `known_notes_index`
- 决策：新增索引模块，常驻于 client 生命周期，至少保存 `path`、`filename`、`aliases`，并维护可查询视图。
- 结构：
  - `entries_by_path[path] = { filename, aliases }`
  - `tokens = { { key_norm, label, kind, path } ... }`（`kind` 为 `filename|alias`）
  - 可选辅助映射用于快速删除/重建单文件 token。
- 原因：满足“查询只查内存、不按键扫盘”。
- 备选：每次补全调用 `find_notes_async`。不满足性能约束。

### 3. 索引根路径由配置提供，默认取当前配置工作区根
- 决策：新增配置 `completion.known_notes`：
  - `min_chars`（默认 `3`）
  - `notes_root`（默认当前 workspace/vault 根）
  - `case_sensitive`（默认 `false`）
- 原因：与现有配置体系兼容，同时满足“路径由配置提供，不依赖 CWD 推断”。
- 备选：顶层新增同名字段。放弃原因是与现有 `completion.min_chars` 语义冲突风险更高。

### 4. 索引构建与增量更新采用“启动全量 + 事件驱动重建单文件”
- 决策：
  - 启动后异步递归扫描 `notes_root/**/*.md` 建索引。
  - 监听 Markdown 文件 `BufWritePost`、`BufDelete`、`BufNewFile`，仅当路径位于 `notes_root` 时更新对应条目。
- 原因：实现复杂度和一致性平衡，满足新增/删除/保存的增量更新要求。
- 备选：文件系统递归 watcher（uv fs_event）。跨平台递归行为与稳定性成本更高。

### 5. aliases 解析复用 Note/frontmatter 解析并加保护
- 决策：索引文件时优先读取 `path.stem`，再通过受保护解析获取 `aliases`；frontmatter 缺失或格式异常时仅忽略 aliases，不中断流程。
- 原因：复用现有解析语义，减少重复实现。
- 备选：自写轻量 YAML 提取器。复杂 YAML 情况下易偏离现有行为。

### 6. 查询回调采用异步调度 + 代际取消
- 决策：completion 调用中使用异步/调度执行索引查询，维护 `request_id`，仅最新请求可回调 UI。
- 原因：避免输入高频时旧请求回流，保证“可中断/不阻塞输入”。
- 备选：纯同步查询。虽然内存查询通常很快，但在超大索引下可能造成可感知卡顿。

### 7. 插入语义固定为 Wiki Link
- 决策：命中文件名或别名均插入 `[[label]]`，`label` 取候选展示文本本身；用 textEdit 替换当前匹配词。
- 原因：与需求明确一致，避免引入 markdown link 分支。
- 备选：根据全局 `preferred_link_style` 切换。与本次需求冲突。

## Risks / Trade-offs

- [风险] 外部工具改动文件但未触发 Neovim 事件，索引可能短暂过期
  -> 缓解：在 `BufEnter` 进入 `notes_root` 下 Markdown 时可做轻量一致性校验，必要时重建单文件。

- [风险] 大型笔记库下索引体积增长
  -> 缓解：索引仅保存最小必要字段（path/filename/aliases），不缓存正文内容。

- [风险] `notes_root` 配置错误导致能力不可用
  -> 缓解：启动时校验可读性并明确告警，自动禁用该 source，不影响其他补全源。

- [权衡] 采用 autocmd 增量更新而非递归文件系统 watcher
  -> 收益是可维护性更高；代价是对编辑器外部批量改动的实时性较弱。

## Migration Plan

- 默认启用该能力，使用默认配置即可工作；不改动现有 source 的外部接口。
- 当 `notes_root` 无效时，仅禁用该能力并输出提示，不影响已有命令与补全能力。
- 通过单元测试与集成测试覆盖索引构建、增量更新、匹配与插入，确保无回归。

## Open Questions

- 是否需要提供显式命令（如 `:ObsidianRebuildKnownNotesIndex`）用于手动全量重建索引。
