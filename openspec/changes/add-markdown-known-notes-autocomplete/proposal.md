## Why

在 Markdown 笔记编辑中，用户需要快速插入已知笔记链接，但当前缺少基于本地笔记元数据的自动补全能力，导致链接输入效率低且容易拼写不一致。现在引入该能力可以在不改变现有编辑流程的前提下，提高链接创建速度与一致性。

## What Changes

- 新增仅对 Markdown buffer 生效的“已知笔记自动补全”能力，输入达到最小字符数后触发候选，不要求先输入 `[[`。
- 候选来源限定为 `notes_root` 下 Markdown 笔记文件名（去除 `.md`）与 YAML frontmatter 的 `aliases`。
- 匹配规则采用前缀匹配，默认大小写不敏感，可通过配置切换是否区分大小写。
- 选择候选后，替换当前匹配词并插入 Wiki Link：命中文件名插入 `[[文件名]]`，命中别名插入 `[[别名]]`。
- 建立并维护内存索引（文件名、aliases、路径），启动时全量构建，后续基于 `notes_root` 下 Markdown 文件新增/删除/保存事件做增量更新。
- 当 frontmatter 缺失、aliases 缺失或格式异常时忽略异常项，不中断补全流程。
- 当 `notes_root` 不存在或不可读时，给出明确提示并禁用该补全功能，不影响其他编辑能力。

## Capabilities

### New Capabilities
- `known-notes-autocomplete`: 基于笔记文件名与 frontmatter aliases 的 Markdown Wiki Link 自动补全能力，包含索引构建、增量更新、查询与插入行为。

### Modified Capabilities
- 无

## Impact

- 受影响模块：Markdown 补全入口、笔记元数据解析、索引生命周期管理、配置处理与校验、与 Neovim 事件集成。
- 受影响行为：Markdown 输入体验与补全候选来源；非 Markdown 文件保持无影响。
- 配置影响：新增或扩展 `min_chars`、`notes_root`、`case_sensitive` 配置项的读取与默认值处理。
- 运行影响：增加内存索引与后台更新流程，避免按键时磁盘全量扫描，降低输入阻塞风险。
