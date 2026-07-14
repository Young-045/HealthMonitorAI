# 服务端后台管理

后台地址为 `/admin`，用于维护官方 AI Provider，不管理用户的 HealthKit 原始数据或 BYOK 密钥。

## 启动

首次启动前设置后台账户。密码至少 12 位，禁止写入 `appsettings.json`：

```powershell
$env:Admin__Username = "admin"
$env:Admin__Password = "replace-with-a-long-random-password"
dotnet run --project src/server/HealthMonitorAI.Api
```

在反向代理和生产部署中必须使用 HTTPS。登录 Cookie 为 HttpOnly、Secure、SameSite=Strict，登录会话最长 8 小时并采用滑动过期。

## AI Provider 配置

登录后可配置：

- 是否启用官方 AI；
- Provider 显示名称；
- OpenAI 兼容 HTTPS 基础地址；
- 视觉模型和文字模型；
- 服务端 API Key。

API Key 由 ASP.NET Core Data Protection 加密后保存在 `App_Data/official-ai-config.protected`。目录已被 Git 忽略，页面和客户端接口都不会回显密钥。生产环境必须将 Data Protection key ring 持久化到受保护的卷或密钥服务，并纳入备份和轮换方案；否则实例重建后将无法解密旧配置。

用户自行配置的 BYOK 地址和 API Key 仍只保存在 iPhone Keychain，并由 App 直接调用用户选择的 Provider，不经过本后台。
