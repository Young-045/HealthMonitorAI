# HealthMonitorAI 开发路线

## Phase 0：仓库与契约

- [x] 创建私有 GitHub 仓库
- [x] 初始化 `main`
- [x] 完成架构文档
- [x] 建立 AI JSON Schema
- [x] 建立服务端与 Swift Package 骨架
- [x] 建立服务端和 macOS GitHub Actions

## Phase 1：本地健康核心

- [x] 最小 SwiftUI iPhone App 和 XcodeGen 工程
- [x] HealthKit 读取授权与今日活动摘要
- [ ] HealthKit 权限与增量查询
- [ ] SwiftData 本地模型
- [ ] 营养计算引擎
- [ ] 每日聚合与评分引擎
- [ ] 手动饮食记录

## Phase 2：AI 与 BYOK

- [ ] AIProvider 抽象
- [ ] 官方网关 Provider
- [ ] OpenAI Compatible Provider
- [ ] Keychain 密钥存储
- [ ] 连接与视觉能力测试
- [ ] 发送数据预览和独立授权

## Phase 3：官方服务端

- [ ] App Attest
- [x] 官方 AI 供应商路由
- [x] 后台登录与加密 Provider 配置
- [ ] 用量和额度
- [ ] StoreKit Server Notifications V2
- [ ] 食物目录版本发布
- [ ] 审计和成本指标

## Phase 4：Watch 与闭环

- [ ] Watch App
- [ ] 表盘复杂功能
- [ ] 快捷饮水和常用餐食
- [ ] 恢复评分
- [ ] 训练建议
- [ ] 周报

## Phase 5：上线

- [ ] 真机与后台同步测试
- [ ] 隐私和安全审计
- [ ] 中国区合规评估
- [ ] App Store 元数据和审核材料
- [ ] 灰度发布与监控
