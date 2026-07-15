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
- [`docs/admin-console.md`](docs/admin-console.md)：后台账户与官方 AI 配置；
- [`docs/github-actions.md`](docs/github-actions.md)：服务端和 Apple CI/签名方案；
- `src/server/HealthMonitorAI.Api`：官方 AI 最小化网关；
- `clients/apple/Packages/HealthMonitorCore`：iPhone/watchOS 共享 Swift Package；
- `contracts/ai`：跨端 AI JSON Schema。

## 本地构建

```powershell
dotnet restore HealthMonitorAI.slnx
dotnet build HealthMonitorAI.slnx --no-restore
dotnet run --project src/server/HealthMonitorAI.Api
```

运行后台前需通过环境变量设置至少 12 位的 `Admin__Password`，然后访问 `/admin`。官方 Provider API Key 只以加密形式保存在服务端 `App_Data`；用户自己的 BYOK Key 仍只在设备 Keychain。

Apple 客户端已包含 XcodeGen 描述和最小 SwiftUI iPhone App。macOS 上执行 `xcodegen generate` 即可生成工程；当前 App 能申请 HealthKit 读取权限，显示今日步数、活动能量和锻炼时间，并通过 SwiftData 在本地记录饮食和汇总当日营养。

需要使用 AltStore 真机测试时，在 GitHub Actions 中手动运行 `Apple Temporary IPA`，下载 `HealthMonitorAI-AltStore-IPA` Artifact，解压后选择 `HealthMonitorAI-unsigned.ipa` 交给 AltStore 重新签名。

## 当前状态

项目已进入架构与 MVP 骨架阶段。后台可配置 OpenAI 兼容的官方 AI Provider；未启用或未配置时，餐食识别端点会明确返回 `503 AI_PROVIDER_NOT_CONFIGURED`。GitHub Actions 已在 macOS runner 上编译并测试共享 Swift Package。
