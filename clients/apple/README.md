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

Phase 1 的自动化与真机复测步骤见 [`docs/apple-phase1-validation.md`](../../docs/apple-phase1-validation.md)。

## Qwen BYOK

在 App 的“AI”页添加 Qwen Provider，选择 API Key 所属区域，填写文字/视觉模型与 API Key 后执行连接测试。API Key 仅保存在本机 `ThisDeviceOnly` Keychain；Qwen Profile 只接受阿里云 `aliyuncs.com` HTTPS 地址。视觉测试发送 App 在内存中生成的测试图案，不访问照片库。

新建餐食时可以输入文字或选择照片。App 会先在本机缩放图片、重新编码并移除元数据，然后展示目标域名和实际发送范围；用户确认后才调用 Qwen。识别结果不会自动保存或写入 Apple 健康，只能先回填到可编辑表单。

健康摘要共享是独立且默认关闭的本机授权。用户在“AI”页确认开启后，请求预览会逐项显示今日步数、活动能量、锻炼分钟和最近睡眠日分钟；未授权或没有可用值时，请求不包含 `healthSummary`。睡眠日按本地时间前一日 12:00 至当日 12:00 统计，上午查询时截止当前时间。

Qwen 返回的食物只按本地目录名称或别名进行规范化精确匹配，不做模糊猜测。用户可以修正确认重量；只有全部食物匹配成功时，App 才使用本地版本化营养快照和确定性引擎计算，任何未匹配项都会退回手动营养填写。

在“饮食记录”页点击书本图标可管理本地食物目录。自建食物需要填写每 100 克的七项营养数据，可选填写默认份量和别名；自建条目可以侧滑删除。AI 命中自建名称或别名后，计算结果会把当时的目录标识、数据版本和每 100 克营养保存为快照，之后修改目录不会悄悄改变历史餐食。

Qwen 的签名真机端到端验收步骤见 [`docs/apple-phase2-qwen-validation.md`](../../docs/apple-phase2-qwen-validation.md)。不要把真实 API Key 写进测试代码、Scheme 环境变量、截图或问题记录。
