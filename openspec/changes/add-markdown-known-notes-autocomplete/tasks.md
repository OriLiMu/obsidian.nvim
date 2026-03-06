## 1. 配置与入口集成

- [ ] 1.1 在 `lua/obsidian/config.lua` 中新增 `completion.known_notes` 配置结构与默认值（`min_chars=3`、`notes_root=nil`、`case_sensitive=false`）。
- [ ] 1.2 在配置归一化流程中解析 `notes_root`，未配置时回退到当前 workspace/vault 根路径，并保留对现有 `completion` 配置的兼容。
- [ ] 1.3 在 `lua/obsidian/init.lua` 中注册新的 cmp source，并仅在 Markdown buffer 注入该 source。

## 2. 内存索引服务实现

- [ ] 2.1 新建 `lua/obsidian/known_notes_index.lua`，定义索引状态与数据结构（`path`、`filename`、`aliases`、查询 token）。
- [ ] 2.2 实现 `notes_root` 可读性校验与禁用状态管理：无效路径时输出明确提示并禁用该补全能力。
- [ ] 2.3 实现启动时异步全量构建索引：仅递归扫描 `notes_root` 下 `*.md`。
- [ ] 2.4 实现单文件索引构建逻辑：从文件名与 frontmatter `aliases` 提取候选，frontmatter 异常时忽略异常项且不中断。
- [ ] 2.5 实现基于前缀的内存查询 API，支持 `case_sensitive` 开关与去重。
- [ ] 2.6 实现单文件增量更新 API（新增/保存重建、删除移除），避免全量重建。

## 3. 已知笔记补全 Source

- [ ] 3.1 新建 `lua/cmp_obsidian_known_notes.lua`，实现“无需 `[[`”的当前匹配词提取与替换范围计算。
- [ ] 3.2 在补全请求中仅对 Markdown 生效，并在匹配词长度达到 `min_chars` 时调用索引查询。
- [ ] 3.3 实现异步或可中断查询回调（含请求代际标识），保证高频输入下仅返回最新结果。
- [ ] 3.4 构建候选 textEdit：选择文件名或别名后统一替换为 `[[候选文本]]`。

## 4. 索引增量更新事件接线

- [ ] 4.1 在 setup 阶段新增 `BufWritePost`、`BufDelete`、`BufNewFile` 的 Markdown 自动命令用于索引维护。
- [ ] 4.2 为事件处理增加 `notes_root` 路径过滤，仅处理该路径下 Markdown 文件。
- [ ] 4.3 验证保存后 aliases 变更可在后续补全中生效，删除后候选被及时移除。

## 5. 验证与文档

- [ ] 5.1 添加测试覆盖前缀匹配与大小写策略（默认不区分大小写、开启后区分大小写）。
- [ ] 5.2 添加测试覆盖插入行为：文件名命中插入 `[[文件名]]`，别名命中插入 `[[别名]]`。
- [ ] 5.3 添加测试覆盖容错与降级：无 aliases、frontmatter 异常、`notes_root` 无效场景。
- [ ] 5.4 更新文档说明新能力范围、配置项与默认值，以及 `notes_root` 无效时的行为。
