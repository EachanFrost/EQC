# 电子排卡器（街机厅排队叫号）

面向 **iPadOS 15**（测试设备 iPad mini 4）、**完全离线** 的公共排队终端 App。两台机台完全独立，各自队列、叫号、游玩状态。

- 语言：SwiftUI + Core Data
- 最低部署目标：iOS/iPadOS 15.0
- 产物：**未签名离线 IPA**（不上传 App Store、不签名）

> ⚠️ iOS 的 IPA 只能在 **macOS + Xcode** 上编译，Windows 无法直接产出 iOS 二进制。本仓库提供完整源码 + 本地构建脚本 + GitHub Actions 云构建，任选其一即可得到 IPA。

---

## 一、目录结构

```
ElectronicQueueCard/
├── ElectronicQueueCard.xcodeproj/        Xcode 工程
├── ElectronicQueueCard/                  源码
│   ├── App/                              入口 + Core Data 容器
│   ├── Models/                           枚举（机台/状态/条目类型）
│   ├── Services/                         队列调度、玩家、二维码、备份、PIN 哈希
│   ├── Views/                            公共屏 + 各流程界面
│   ├── QueueKiosk.xcdatamodeld/          Core Data 模型（7 个实体）
│   └── Info.plist
├── build_ipa.sh                          本地一键生成未签名 IPA
├── .github/workflows/build-ios.yml       云构建（无 Mac 时用）
└── README.md
```

---

## 二、本地编译（macOS）

1. 安装 Xcode 14 或更高版本（需含 iOS 15 SDK）。
2. 打开终端进入本目录，执行：

   ```bash
   bash build_ipa.sh
   ```

3. 完成后得到 `ElectronicQueueCard-unsigned.ipa`。

若脚本因换行符（从 Windows 下载后出现 `\r`）报错，先执行：

```bash
sed -i '' $'s/\r$//' build_ipa.sh
```

---

## 三、云构建（无 Mac 时，GitHub Actions）

1. 把本目录推送到 GitHub 仓库。
2. 在仓库 **Actions** 页运行 `Build unsigned IPA` 工作流（或推送 `v*` 标签自动触发）。
3. 完成后在运行记录里下载 `ElectronicQueueCard-unsigned` 产物。

---

## 四、把 IPA 装到 iPad

未签名 IPA 不能直接安装。请任选其一：

- **用 Xcode + 免费 Apple ID**：连接 iPad，在 Xcode 里打开工程，选择你的免费团队直接 Run（会自动用免费个人证书签名并安装）。
- **用已有开发者证书重签**：`codesign -f -s "iPhone Distribution: ..." --entitlements ... ElectronicQueueCard.app` 后重新打包。
- 企业内部/个人自有分发工具按各自流程签名安装。

> 首次运行会请求相机权限，请点击允许。营业时建议在「设置 → 辅助功能 → 引导式访问」开启锁定，防止玩家退出 App。

---

## 五、功能对照

| 需求 | 实现 |
| --- | --- |
| 双机独立（左机/右机，各自队列/叫号/状态） | ✅ 两台完全独立 |
| 游客排队（临时昵称 / 自动「游客#N」） | ✅ 底部栏「游客排队」 |
| 注册玩家（昵称 + 头像 + PIN + 专属二维码） | ✅ 「账号注册」 |
| 扫码登录 / 昵称+PIN 登录 / 找回二维码 | ✅ 「扫码登录」 |
| 单人 / 双人匹配 / 双人组三种模式 | ✅ 入队时选择 |
| 拼机配对（同边、不占新位、可取消） | ✅ 队列行「拼机」→ 第二位玩家登录确认 |
| 叫号 60 秒倒计时、注册扫码确认 / 游客点名字确认 | ✅ 叫号横幅 |
| 过号栏（30 分钟倒计时、点「我回来了」回到队首） | ✅ |
| 取消排队（双人组一起移除） | ✅ 队列行「取消」 |
| JSON 备份导出 | ✅ 代码已实现（`BackupService`），见下方说明 |

---

## 六、运营操作

- **结束本局**：机台显示「游玩中」时，点横幅里的 **「结束本局（员工）」**，机台恢复空闲并自动叫下一位。
- **维护模式**：**长按**机台栏目顶部（左侧/右侧机名处）可在「空闲 ↔ 维护」间切换，维护中暂停叫号。
- **过号**：叫号 60 秒未确认会自动进入该机的过号栏；玩家点「我回来了」回到队首优先叫号。

---

## 七、JSON 备份导出

`BackupService.exportJSON()` 会把全部数据导出为 JSON 到 App 的 `Documents/Backups/queue-backup-<时间>.json`。工程已开启 `UIFileSharingEnabled` + `LSSupportsOpeningDocumentsInPlace`，可用「文件」App 或数据线（访达）取走。

> 当前版本把导出功能预留为服务层接口；如需在界面加一个「导出备份」按钮，可在公共屏顶部新增一个按钮调用 `BackupService(context:).exportJSON()` 并提示保存路径。

---

## 八、注意事项

- 两台机完全独立，不做跨机调度；双人匹配不跨边。
- 过号栏 30 分钟从进入过号栏起算，到期自动清除，需重新排队。
- 过号后回到队首，但仍需玩家自主确认（点「我回来了」）。
- 取消排队不进过号栏，直接移除。
- iPad 摄像头在旧机型上可能扫码不稳，已保留「昵称 + PIN」登录兜底。
- 引导式访问锁定 App；营业时 iPad 需持续充电，亮屏 + 摄像头耗电较快。
- 当前工程未附带 App 图标，如需可在 Xcode 里添加 `Assets.xcassets` 并设置图标。
