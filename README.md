# HealthMonitorAI

健康监控是一款面向 iPhone 与 Apple Watch 的隐私优先健康管理应用。项目计划通过 HealthKit 汇总运动、睡眠与恢复数据，结合中餐拍照、文字或语音记录，提供可解释的健康评分、减脂建议和训练调整。

## 核心原则

- HealthKit 原始健康数据保留在用户设备上。
- 营养计算和健康评分由本地确定性算法完成。
- 默认 AI 由最小化服务端网关提供。
- 支持用户配置自己的 API Key 和兼容 AI 地址，密钥仅保存在设备 Keychain。
- 没有 AI 或服务端不可用时，健康同步、手动记录和基础评分仍然可用。

## 仓库结构

- [`docs/architecture-design.md`](docs/architecture-design.md)：完整产品与技术设计；
- [`docs/roadmap.md`](docs/roadmap.md)：阶段路线和任务清单；
- `src/server/HealthMonitorAI.Api`：官方 AI 最小化网关；
- `clients/apple/Packages/HealthMonitorCore`：iPhone/watchOS 共享 Swift Package；
- `contracts/ai`：跨端 AI JSON Schema。

## 本地构建

```powershell
dotnet restore HealthMonitorAI.slnx
dotnet build HealthMonitorAI.slnx --no-restore
dotnet run --project src/server/HealthMonitorAI.Api
```

Apple 客户端需要在 macOS/Xcode 环境中创建最终 App Targets，并接入仓库中的 `HealthMonitorCore` Package。

## 当前状态

项目已进入架构与 MVP 骨架阶段。官方 AI Provider 尚未配置，调用餐食识别端点会明确返回 `503 AI_PROVIDER_NOT_CONFIGURED`。
