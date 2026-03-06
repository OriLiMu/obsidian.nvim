## ADDED Requirements

### Requirement: Markdown 范围内的自动触发
系统 MUST 仅在 Markdown buffer 中提供已知笔记自动补全，并在当前匹配词长度达到配置阈值后触发候选，且不要求先输入 `[[`。

#### Scenario: Markdown 中达到最小字符触发
- **WHEN** 用户在 Markdown buffer 输入普通词且长度达到 `min_chars`
- **THEN** 系统返回已知笔记候选

#### Scenario: 非 Markdown 中不触发
- **WHEN** 用户在非 Markdown buffer 输入长度达到 `min_chars` 的普通词
- **THEN** 系统不返回该能力的候选

#### Scenario: 未达阈值不触发
- **WHEN** 用户在 Markdown buffer 输入长度小于 `min_chars` 的匹配词
- **THEN** 系统不返回该能力的候选

### Requirement: 候选必须来源于配置根路径下的索引
系统 MUST 仅使用配置项 `notes_root` 指定路径下递归扫描到的 `*.md` 文件构建索引，索引项 MUST 至少包含 `path`、`filename`、`aliases`，补全查询 MUST 只读取内存索引。

#### Scenario: 仅检索 notes_root 下 Markdown 文件
- **WHEN** `notes_root` 外部目录存在同名或同别名文件
- **THEN** 系统候选中不包含这些外部目录条目

#### Scenario: 索引包含必需字段
- **WHEN** 系统完成索引构建
- **THEN** 每个条目都可提供文件路径、文件名与 aliases 信息

#### Scenario: 查询不触发按键时全盘扫描
- **WHEN** 用户连续输入触发多次补全查询
- **THEN** 系统在查询阶段只读取内存索引而不启动全量磁盘扫描

### Requirement: 前缀匹配与大小写规则
系统 MUST 对文件名与 aliases 执行前缀匹配；当 `case_sensitive=false` 时 MUST 大小写不敏感匹配，当 `case_sensitive=true` 时 MUST 大小写敏感匹配。

#### Scenario: 默认大小写不敏感
- **WHEN** 存在 `How-to-eat-an-apple` 与 `How-to-learn-fast`，用户输入 `how`
- **THEN** 系统返回两个候选

#### Scenario: 大小写敏感开启后区分大小写
- **WHEN** `case_sensitive=true` 且候选为 `Ai-Help-Learning`，用户输入 `ai-`
- **THEN** 系统不返回该候选

### Requirement: 选择候选后插入 Wiki Link
系统 MUST 在确认候选后替换当前匹配词并插入 Wiki Link 文本。命中文件名时 MUST 插入 `[[文件名]]`；命中别名时 MUST 插入 `[[别名]]`。

#### Scenario: 命中文件名插入 Wiki Link
- **WHEN** 用户从候选中选择文件名 `How-to-eat-an-apple`
- **THEN** 当前匹配词被替换为 `[[How-to-eat-an-apple]]`

#### Scenario: 命中别名插入 Wiki Link
- **WHEN** 用户输入 `ai-` 并选择别名 `Ai-Help-Learning`
- **THEN** 当前匹配词被替换为 `[[Ai-Help-Learning]]`

### Requirement: Frontmatter 异常必须容错
当文件无 frontmatter、无 aliases 或 frontmatter 格式异常时，系统 MUST 不报错中断；异常文件的 aliases 可忽略，但文件名匹配能力 MUST 保持可用。

#### Scenario: 无 aliases 的文件仍可按文件名匹配
- **WHEN** 某 Markdown 文件没有 `aliases`
- **THEN** 该文件仍可通过文件名出现在候选中

#### Scenario: frontmatter 格式异常不影响整体补全
- **WHEN** 某 Markdown 文件 frontmatter 解析失败
- **THEN** 系统忽略该文件的异常 aliases 并继续为其他文件提供候选

### Requirement: 索引生命周期与增量更新
系统 MUST 在启动时完成一次初始索引构建，并在 `notes_root` 下 Markdown 文件新增、删除、保存后做增量更新。

#### Scenario: 新增文件后可被补全
- **WHEN** 用户在 `notes_root` 下新增并保存 `New-Topic.md`
- **THEN** 后续输入 `new` 时可匹配到该文件

#### Scenario: 删除文件后从候选移除
- **WHEN** `notes_root` 下某 Markdown 文件被删除
- **THEN** 该文件对应候选在后续查询中不再出现

#### Scenario: 保存后 aliases 变更生效
- **WHEN** 用户保存后修改了文件 frontmatter 的 aliases
- **THEN** 索引更新并在后续查询中体现新的 aliases

### Requirement: 查询过程必须非阻塞且可中断
系统 MUST 以异步或可中断方式执行补全查询，且在高频输入下不阻塞正常输入。

#### Scenario: 高频输入仅返回最新查询结果
- **WHEN** 用户快速连续输入触发多次查询
- **THEN** 系统只呈现最新输入对应的候选结果

### Requirement: notes_root 不可用时安全降级
当 `notes_root` 不存在或不可读时，系统 MUST 给出明确提示并禁用该补全能力，且 MUST 不影响其他编辑能力。

#### Scenario: notes_root 无效时禁用该能力
- **WHEN** 配置的 `notes_root` 不存在
- **THEN** 系统提示路径无效并停止提供已知笔记补全候选

#### Scenario: 其他能力不受影响
- **WHEN** 已知笔记补全因 `notes_root` 无效被禁用
- **THEN** 其他编辑与补全功能仍可继续使用

### Requirement: 提供可配置项与默认值
系统 SHOULD 提供 `min_chars`、`notes_root`、`case_sensitive` 三个配置项，并使用默认值 `3`、当前配置工作区根路径、`false`。

#### Scenario: 未显式配置时采用默认值
- **WHEN** 用户未提供该能力相关配置
- **THEN** 系统使用 `min_chars=3`、`notes_root=当前配置工作区根路径`、`case_sensitive=false`
