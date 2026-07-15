# GitHub Actions 构建方案

## 当前自动化

- `Server CI` 在 Ubuntu runner 上还原并以 Release 配置编译 ASP.NET Core 服务端。
- `Apple Package CI` 在 `macos-15` runner 上编译并测试 `HealthMonitorCore` Swift Package，然后用 XcodeGen 生成工程并执行无签名的 iPhone 模拟器构建。
- 两个工作流都采用只读仓库权限，并通过路径过滤减少无关运行。
- `Apple Temporary IPA` 在 Apple 客户端 PR 更新时自动运行，合并到默认分支后也可手动触发；它生成供 AltStore 重新签名的 IPA，并将下载 Artifact 保留 7 天。

仓库使用 `clients/apple/project.yml` 描述工程，不提交生成的 `.xcodeproj`。常规 CI 只验证 App Target；手动 IPA 工作流会产出无开发者签名包，必须由 AltStore 使用用户自己的 Apple ID 重新签名后才能尝试安装。Watch App 和正式签名仍属于后续阶段。

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

证书、profile、API Key 和密码不得提交到仓库。当前公共仓库使用标准 GitHub 托管 runner；仍通过手动触发、路径过滤和并发取消减少不必要构建。

## AltStore 下载和安装

1. 打开仓库的 `Actions` 页面并选择 `Apple Temporary IPA`。
2. 点击 `Run workflow`，选择需要构建的分支。
3. 等待 `build-ipa` 通过，在运行页面底部下载 `HealthMonitorAI-AltStore-IPA`。
4. 解压 Artifact，得到 `HealthMonitorAI-unsigned.ipa` 和 SHA-256 校验文件。
5. 在 iPhone 的 AltStore Classic 中从 `My Apps` 选择该 IPA，由 AltStore 重新签名并安装。

该 IPA 不是 App Store 正式签名包。免费 Apple ID 安装通常需要定期刷新；HealthKit entitlement 能否被 AltStore 的 provisioning profile 保留，以真机安装与系统授权结果为最终验收标准。
