# Apple 客户端

该目录保存 iPhone、Apple Watch 和共享 Swift Package。当前已经提供最小 SwiftUI iPhone App、HealthKit 今日活动读取和 XcodeGen 工程描述；GitHub Actions 会在 macOS 上生成 Xcode 工程并执行模拟器构建。

## Xcode 接入步骤

1. 在 macOS 安装 XcodeGen：`brew install xcodegen`。
2. 在本目录执行 `xcodegen generate`。
3. 用 Xcode 打开生成的 `HealthMonitorAI.xcodeproj`。
4. 为 Target 选择开发团队并确认 Bundle Identifier 可用。
5. 在真机授权并验证步数、活动能量和锻炼时间；模拟器不能覆盖真实 HealthKit 数据。
6. 添加 Watch App 时最低使用 watchOS 10，并只启用实际需要的能力。

API Key 必须通过 `KeychainSecretStore` 保存，不应进入 Xcode 配置文件、源代码或 iCloud。
