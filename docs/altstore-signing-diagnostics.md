# AltStore 签名诊断

## 2026-07-15 日志结论

用户提供的 `altstore.log` 显示：

- AltStore 成功认证 Team `42H8WPY6KZ`；
- 使用既有 App ID `com.young045.healthmonitorai.42H8WPY6KZ`；
- 成功下载并验证原始 App；
- 成功获取 provisioning profile 并完成重签；
- 成功把重签 App 发送给 AltServer；
- AltServer 接收开始安装请求后返回格式解析错误；
- 同时存在多次 USB AltServer `Connection reset by peer` 和认证响应解析错误。

桌面 App 实际存在且可以启动，说明 iOS 已完成至少一次安装。日志中的格式错误不能单独证明 IPA 损坏，也不能证明 HealthKit entitlement 的去向。

## 诊断版证据

GitHub Actions Artifact 现在同时包含：

- `HealthMonitorAI-unsigned.ipa`；
- `PreAltStoreEntitlements.plist`：AltStore 重签前的实际代码签名 entitlement；
- `PreAltStoreSigningReport.txt`：AltStore 重签前的代码签名摘要；
- SHA-256 校验文件。

安装后打开 App 的“诊断”页，可读取：

- 当前进程实际拥有的 `com.apple.developer.healthkit`；
- `embedded.mobileprovision` 是否存在；
- profile 是否允许 HealthKit；
- AltStore 重写后的 Bundle ID、Application ID 和 Team ID。

如果 Artifact 中 HealthKit 为 `true`，而安装后进程或 profile 为 `false`，即可确认权限在 AltStore 的 App ID/provisioning/重签流程中丢失。

诊断页通过底层 `SecTask` 符号读取当前进程 entitlement。该实现只用于侧载问题定位，正式 App Store 构建前必须移除，改由受控签名流水线和发布前 codesign 检查保证权限一致性。
