# HealthMonitorAI 开发路线

> 当前优先级（2026-07-25）：Phase 1 与 Phase 1.5 首版开发和自动化验收已完成；当前执行签名 iPhone 真机复测，并完成 Phase 2 第三方 AI（BYOK）真机端到端验收。
>
> 路线说明：第三方 AI API 直连属于 Phase 2；Phase 3 是官方服务端，保留已有成果但暂不继续扩展。

## 当前状态与执行顺序

1. Phase 1：开发任务与自动化验收完成；按真机清单复测 HealthKit 授权、增量同步、写入和删除。
2. Phase 1.5：首版开发与自动化验收完成；后续数据源、跨语言搜索和在线更新能力不阻塞首版完成状态。
3. Phase 2：开发任务与自动化验收完成；下一项是签名 iPhone 上的 Qwen 端到端验证。
4. Phase 1/2 真机验收和隐私检查完成后，再恢复 Phase 3 官方服务端开发。

## Phase 0：仓库与契约（已完成）

- [x] 创建 GitHub 仓库并调整为公共可见性
- [x] 初始化 `main`
- [x] 完成架构文档
- [x] 建立 AI JSON Schema
- [x] 建立服务端与 Swift Package 骨架
- [x] 建立服务端和 macOS GitHub Actions

## Phase 1：本地健康核心（开发与自动化验收已完成）

- [x] 最小 SwiftUI iPhone App 和 XcodeGen 工程
- [x] HealthKit 基础读取授权与今日活动摘要
- [x] 完善 HealthKit 权限状态、部分拒绝和错误提示
- [x] 使用 Observer Query 与 Anchored Query 增量读取并持久化 Anchor
- [x] 扩展 MVP HealthKit 数据：身体、活动、训练、睡眠与恢复
- [x] SwiftData 基础饮食模型
- [x] 建立本地食物与营养数据模型
- [x] 实现确定性营养计算引擎及单元测试
- [x] 实现每日健康聚合、数据完整度和评分引擎及单元测试
- [x] 手动饮食记录与今日营养汇总
- [x] 将用户确认的营养数据写回 Apple Health，并记录本 App 创建的样本 UUID
- [x] 验证增量同步不重复计入，核心功能在离线和无 AI 时可用

### Phase 1 完成标准

- HealthKit 变化能够增量同步，重启 App 后继续使用已保存的 Anchor。
- 相同输入和算法版本得到相同营养结果与每日评分。
- 评分包含总分、子分、数据完整度、原因代码和算法版本。
- 用户删除饮食时，只删除本 App 写入 Apple Health 的对应样本。

> 自动化状态：Swift Package 24 项测试全部通过；iOS App 模拟器构建成功，43 项测试通过，另 1 项 Keychain 测试因无签名模拟器无法访问 Keychain 而按设计跳过。真实 HealthKit 权限、后台 Observer、Keychain 和样本写入/删除仍须按 [`apple-phase1-validation.md`](apple-phase1-validation.md) 在签名 iPhone 上复测；这属于真机发布验收，不代表上述开发任务未完成。

## Phase 1.5：权威食品成分离线目录（首版开发与自动化验收已完成）

- [x] 将 USDA FoodData Central Foundation Foods 与日本文部科学省食品成分表确定为首期主数据源
- [x] 固定官方来源 URL、版本、许可和 SHA-256
- [x] 实现 USDA JSON ZIP 与 MEXT Excel 的无网络运行时导入管线
- [x] 统一食品、名称、营养素、份量、可食部、来源版本和缺失值模型
- [x] 生成版本化 SQLite、CSV、NDJSON、Manifest、署名和校验报告
- [x] 在 App Bundle 内置只读 SQLite，SwiftData 继续只保存用户自建目录和餐食快照
- [x] 用户自建精确匹配优先于权威目录；权威营养字段不完整时禁止伪造自动计算
- [x] 为来源版本、USDA 精确查询、MEXT 缺失总糖和 SQLite 完整性添加自动测试

### Phase 1.5 后续扩展（不阻塞首版）

- [ ] 加入 USDA FNDDS 与精选 SR Legacy，并评估独立地区数据包
- [ ] 增加中文受控别名、日英中跨语言搜索键和候选选择界面
- [ ] 增加签名 Manifest、原子更新和上一版本回滚
- [ ] 在取得明确批量使用及再分发许可后接入中国食物成分数据

### Phase 1.5 完成标准

- 飞行模式下可打开权威目录并执行确定性精确查询。
- 每条食品及营养值可追溯到来源 ID、来源版本和发布目录版本。
- 缺失、痕量、估算值和零值不会在导入时混为一谈。
- 更新权威目录不会改变已保存餐食的营养快照。
- 数据管线测试、SQLite 完整性检查、Apple 模拟器构建和客户端单元测试全部通过。

> 自动化状态：食品管线 4 项测试、SQLite 完整性和 2,841 条食品检查、内置目录客户端测试及 Apple 模拟器构建已通过。

## Phase 2：第三方 AI 直连 / BYOK（开发与自动化验收已完成，真机验收中）

- [x] `AIProvider` 基础协议、Provider Profile 和餐食分析契约模型
- [x] `KeychainSecretStore` 基础存取实现，使用 `ThisDeviceOnly`
- [x] 补齐 Provider Router、活动 Provider 选择和本地 Profile 持久化
- [x] 实现 `OpenAICompatibleProvider`，支持文字和图片餐食分析
- [x] 提供第三方 API 地址、模型、API Key 和超时设置界面
- [x] 将 API Key 与自定义鉴权信息接入 Keychain，不写入 SwiftData、日志或导出
- [x] 仅允许 HTTPS，并禁止跨主机重定向携带 Authorization
- [x] 实现连接测试、模型信息和视觉能力测试
- [x] 发送前展示目标域名、图片/文字和可选健康摘要的数据预览
- [x] 健康摘要采用独立授权，默认不发送 HealthKit 数据
- [x] 对 AI 输出执行契约与业务范围校验，显示置信度、不确定项并允许用户修正
- [x] 将用户确认结果接入本地食物匹配和营养计算，不直接采用 AI 生成的营养数字
- [x] 明确处理 401/403、429、超时、非法 JSON、不支持图片等错误，不静默切换 Provider
- [x] 添加 Provider、重定向、契约校验和 Keychain 相关测试
- [ ] 完成第三方 AI 真机端到端验证（按 [`apple-phase2-qwen-validation.md`](apple-phase2-qwen-validation.md) 在签名 iPhone 上执行）

### Phase 2 完成标准

- BYOK 请求由 iPhone 直接发往用户配置的第三方地址，不经过官方服务端。
- 密钥不出现在数据库、日志、崩溃报告、截图或导出文件中。
- 用户确认前不保存 AI 识别结果，也不写入 Apple Health。
- 第三方 AI 不可用时仍可手动记录、同步 HealthKit 并计算本地评分。

## Phase 3：官方服务端（暂停新增开发）

> 当前只维护已有网关和管理后台，不新增官方服务端能力。待 Phase 1、Phase 2 客户端 MVP 稳定后恢复。

- [ ] App Attest
- [x] 官方 AI 供应商路由
- [x] 后台登录与加密 Provider 配置
- [ ] 官方网关 Apple 客户端 Provider
- [ ] 用量和额度
- [ ] StoreKit Server Notifications V2
- [ ] 食物目录版本发布
- [ ] 审计和成本指标

## Phase 4：Watch 与闭环（后续）

- [ ] Watch App
- [ ] 表盘复杂功能
- [ ] 快捷饮水和常用餐食
- [ ] 恢复评分
- [ ] 训练建议
- [ ] 周报

## Phase 5：上线（后续）

- [ ] 真机与后台同步测试
- [ ] 隐私和安全审计
- [ ] 中国区合规评估
- [ ] App Store 元数据和审核材料
- [ ] 灰度发布与监控
