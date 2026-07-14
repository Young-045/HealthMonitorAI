# Apple 客户端

该目录保存 iPhone、Apple Watch 和共享 Swift Package。当前 Windows 工作区先维护可复用核心代码；完整 Xcode 工程需要在 macOS 上创建并接入 `Packages/HealthMonitorCore`。

## Xcode 接入步骤

1. 创建 SwiftUI iOS App，最低 iOS 17。
2. 添加配套 watchOS App，最低 watchOS 10。
3. 为两个 Target 启用 HealthKit；只勾选实际使用的能力。
4. 将本地 Package `Packages/HealthMonitorCore` 加入工程。
5. 在 iPhone Target 添加 HealthKit 权限说明、相机和照片权限说明。
6. 真机验证 HealthKit 后台查询；模拟器不能覆盖全部后台场景。

API Key 必须通过 `KeychainSecretStore` 保存，不应进入 Xcode 配置文件、源代码或 iCloud。
