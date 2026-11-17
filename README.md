# LiteLog / 轻身记

一款本地优先的轻量体重与身体数据记录应用。支持体重、体脂、腰围、臀围、胸围、个人目标、趋势分析和每日提醒。

## 免费与 Pro

核心记录、统计、提醒、iCloud 云盘备份与恢复、CSV/JSON 导出与本地恢复保持免费，不收回已有功能。

- **iCloud 云盘备份与恢复（免费）**：保存记录后以及 App 进入后台时，将 JSON 备份写入用户自己的 iCloud 云盘 Documents 容器；开发者无法读取，也可从最近一次云盘备份恢复。
- **LiteLog Pro**：一次性买断，不订阅，商品 ID 为 `lt.LiteLog.pro.lifetime`。
- **身体数据报告**：生成包含概览、个人资料、体重趋势图和完整记录明细的 PDF，可按时间范围筛选，并通过系统分享面板保存或发送。
- **后续 Pro 功能**：一次购买后持续获得后续新增的 Pro 功能。

价格由 App Store Connect 配置，本地测试配置使用中国区 ¥38。支付、家庭共享、退款和恢复购买均由 Apple 处理。

## 数据与隐私

- 健康数据默认保存在设备本地 Core Data，LiteLog 不运营接收健康数据的后端。
- 不创建 LiteLog 账号，不采集设备标识，不接入广告或行为追踪 SDK。
- iCloud 云盘备份位于用户自己的 iCloud 云盘容器中，开发者没有读取权限。
- App 仅读取 StoreKit 交易结果来确认 Pro 权益，不接触支付卡信息。
- 头像仅保存在 App 沙盒中，可在个人资料页更换或删除。
- Core Data 和头像文件启用 iOS 文件保护。
- 数据可通过 CSV 或 JSON 导出，也可从本地或 iCloud 云盘 JSON 备份恢复。
- BMI 标准会根据设备区域选择中国标准或 WHO 标准。
- 目标趋势预估仅用于个人记录参考，不构成医疗建议。

## 构建

- Xcode 16.4 或更高版本。
- iOS 16.6 及以上。
- 打开 `LiteLog/LiteLog.xcodeproj`，不要使用残留的 `LiteLog.xcworkspace`。

```sh
xcodebuild -project LiteLog/LiteLog.xcodeproj \
  -scheme LiteLog \
  -configuration Debug \
  -sdk iphonesimulator \
  CODE_SIGNING_ALLOWED=NO \
  build
```

上线所需的产品、iCloud、StoreKit 测试与提交流程见 `Docs/ProSetup.md`。
