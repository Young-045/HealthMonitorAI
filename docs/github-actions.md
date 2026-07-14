# GitHub Actions 构建方案

## 当前自动化

- `Server CI` 在 Ubuntu runner 上还原并以 Release 配置编译 ASP.NET Core 服务端。
- `Apple Package CI` 在 `macos-15` runner 上编译并测试 `HealthMonitorCore` Swift Package，然后用 XcodeGen 生成工程并执行无签名的 iPhone 模拟器构建。
- 两个工作流都采用只读仓库权限，并通过路径过滤减少无关运行。

仓库使用 `clients/apple/project.yml` 描述工程，不提交生成的 `.xcodeproj`。当前 Actions 会验证 iPhone App Target，但不会产出可安装 IPA；真机安装、Watch App 和正式签名仍属于后续阶段。

## 创建 Xcode 工程后的构建

无签名的模拟器构建适合 Pull Request 验证：

```bash
xcodebuild \
  -project clients/apple/HealthMonitorAI.xcodeproj \
  -scheme HealthMonitorAI \
  -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  CODE_SIGNING_ALLOWED=NO \
  build
```

Watch App 应增加独立 Scheme 的模拟器构建。真正的设备归档、TestFlight 或 App Store 发布还需要：

- Apple Developer 证书（`.p12`）及其密码；
- 对应 App ID 的 provisioning profile；
- App Store Connect API Key；
- 将以上内容放入 GitHub Actions Secrets，并在临时 Keychain 中导入；
- 在 job 结束时清理临时 Keychain 和 profile。

证书、profile、API Key 和密码不得提交到仓库。私有仓库使用 GitHub 托管 macOS runner 会消耗 Actions 配额，macOS 计费分钟倍率高于 Linux，需通过路径过滤、并发取消和缓存控制成本。
