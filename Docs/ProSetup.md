# LiteLog Pro 上线配置

本版本已实现 StoreKit 2 一次性购买、付费墙、iCloud 自动备份、身体数据报告和评分引导。以下项目仍需在 Apple Developer 与 App Store Connect 中完成。

## 1. 商品配置

| 项目 | 值 |
| --- | --- |
| Product ID | `lt.LiteLog.pro.lifetime` |
| 类型 | Non-Consumable / 非消耗型 |
| 建议价格 | 中国区 ¥38 |
| 家庭共享 | 开启 |
| 订阅 | 不使用 |

在 App Store Connect 的 App 内购买项目中创建上述商品，并填写至少简体中文和英文的显示名称、描述与审核截图。完成付费应用协议、税务和收款银行信息后，真实商品才能返回价格并完成测试购买。

本地 `LiteLog.storekit` 中的 ¥38 仅用于 StoreKit 测试，不会同步到 App Store Connect。

## 2. iCloud 能力

工程已加入：

- Entitlement：`LiteLog/LiteLog.entitlements`
- iCloud 容器：`iCloud.lt.LiteLog`
- 服务：CloudDocuments
- `Info.plist` 中的 `NSUbiquitousContainers`
- Debug/Release 的 `CODE_SIGN_ENTITLEMENTS`

仍需在 Apple Developer 后台确认 App ID `lt.LiteLog` 已启用 iCloud，并创建或关联容器 `iCloud.lt.LiteLog`，然后让 Xcode 自动签名刷新描述文件。若容器名称被占用或需要改名，必须同步修改：

- `ICloudBackupManager.containerIdentifier`
- `LiteLog.entitlements`
- `Info.plist` 中的 `NSUbiquitousContainers`

备份文件路径为用户 iCloud 容器内的 `Documents/LiteLog-AutoBackup.json`。开发者无法读取该文件。

## 3. StoreKit 本地测试

1. 在 Xcode 中打开 `LiteLog/LiteLog.xcodeproj`。
2. 选择 Product > Scheme > Edit Scheme。
3. 在 Run > Options 中选择 StoreKit Configuration。
4. 选择 `LiteLog/LiteLog.storekit`。
5. 运行 App，在设置页进入 Pro 付费墙，验证动态价格、购买、恢复购买和身体数据报告。

`.storekit` 文件包含商品 `lt.LiteLog.pro.lifetime`，中国区显示价格为 ¥38，并启用家庭共享。StoreKit 配置只在本地开发环境生效；发布版本会读取 App Store Connect 的真实商品。

## 4. 功能验收

- 免费用户可以继续使用记录、统计、提醒、CSV/JSON 导出和本地恢复。
- 未解锁 Pro 时，点击 iCloud 行会展示备份内容预览；点击身体数据报告行会生成并展示完整的只读 PDF；点击预览页底部解锁按钮后才打开付费墙。
- Pro 用户点击 iCloud/PDF 行也进入同一个功能页，底部按钮分别变为“立即备份”和“分享 / 导出 PDF”。
- 完成购买或恢复购买后，设置页显示 Pro 已解锁。
- Pro 用户保存记录后会尝试 iCloud 备份；备份失败不会阻断记录保存。
- 后台自动备份有 15 分钟节流；设置页“立即备份”可强制写入。
- iCloud 恢复前会二次确认，并显示恢复条数。
- 身体数据报告至少需要一条记录；生成失败会显示可读错误。
- 评分引导只在记录保存后判断：至少 7 条记录、首条记录满 3 天、两次提示间隔 120 天。

## 5. 隐私与支持

公开页面：

- 隐私政策：`https://lt2058914895.github.io/LiteLog/privacy.html`
- 技术支持：`https://lt2058914895.github.io/LiteLog/support.html`
- 使用条款：Apple 标准 EULA

上线前需确认这些页面已经随仓库发布，且 App Store Connect 的隐私政策 URL 与支持 URL 指向公开可访问版本。

## 6. 提交流程

1. 将 `MARKETING_VERSION` 设为 `1.6`、`CURRENT_PROJECT_VERSION` 设为 `21`。
2. 使用真实证书 Archive，确认签名中包含 iCloud entitlement。
3. 上传到 App Store Connect。
4. 在“App 内购买”中关联首屏商品，并提交审核。
5. 在审核备注中说明 Pro 为一次性买断，iCloud 备份使用用户自己的 iCloud，身体数据报告在设置页生成。
6. 准备付费墙截图、购买成功状态和身体数据报告分享流程截图。

## 7. 本版不做

自定义围度、主题系统、Widget、HealthKit、Apple Watch 与 CloudKit 跨设备同步留到后续版本，不阻塞本次买断版上线。
