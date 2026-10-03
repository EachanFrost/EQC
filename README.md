# 电子排卡器（街机厅排队叫号）

面向 **iPadOS 15**（测试设备 iPad mini 4）、**完全离线** 的公共排队叫号终端 App。支持 **1~6 台机台** 独立排队、叫号、游玩，内置玩家账号体系、扫码登录、语音播报与后台用户管理。

- 语言：SwiftUI + Core Data（手动代码生成）
- 最低部署目标：iOS / iPadOS 15.0
- 当前版本：**1.0.0**
- Bundle ID：`com.eachan.queue`
- 产物：**未签名离线 IPA**（不上传 App Store、不签名）

> ⚠️ iOS 的 IPA 只能在 **macOS + Xcode** 上编译，Windows 无法直接产出 iOS 二进制。本仓库提供完整源码 + 本地构建脚本 + GitHub Actions 云构建，任选其一即可得到 IPA。

---

## 一、目录结构

```
ElectronicQueueCard/
├── ElectronicQueueCard.xcodeproj/        Xcode 工程
├── ElectronicQueueCard/                  源码
│   ├── App/                              App 入口 + Core Data 容器（PersistenceController）
│   ├── Models/                           枚举（机台/状态/条目类型/管理员配置）+ 实体类
│   ├── Services/                         队列调度、玩家、二维码、备份、PIN 哈希
│   ├── Views/                            公共屏 + 各流程界面 + 用户管理
│   ├── Assets.xcassets/                  App 图标（灰色）
│   ├── QueueKiosk.xcdatamodeld/          Core Data 模型（7 个实体）
│   └── Info.plist
├── build_ipa.sh                          本地一键生成未签名 IPA
├── .github/workflows/build-ios.yml       云构建（无 Mac 时用）
└── README.md
```

---

## 二、功能清单

### 机台
- 支持 **1~6 台机台**，数量可在首页顶部「机台数」菜单随时调整。
- 每台机独立队列、叫号、游玩状态，互不干扰。
- 机台名称可改：机台栏名称旁 **铅笔按钮** 弹出改名框。
- 维护模式：**长按机台栏顶部** 在「空闲 ↔ 维护」间切换，维护中暂停叫号。

### 排队模式
| 模式 | 说明 |
| --- | --- |
| 单人 | 一名玩家排队 |
| 双人匹配（拼机） | 与其他单人玩家配对，同机台、不额外占位，可取消 |
| 双人组 | 两名玩家一起排队，**未满两人不叫号**，满员后自动叫号 |

### 玩家账号
- 注册：昵称 + PIN，生成专属二维码（扫码登录用）。
- 登录：**扫码** 或 **昵称 + PIN** 两种方式。
- 找回二维码：忘记二维码时用昵称 + PIN 重新展示。
- 游客排队：临时昵称（可留空自动生成「游客#N」）。

### 叫号与过号
- 点玩家名字确认上机（无需扫码）。
- 叫号 **60 秒倒计时**，超时自动进入过号栏。
- 过号栏保留 **30 分钟**：可点「我回来了」回到队首，或点「离开」直接移除。

### 队列管理
- 队列中每条可 **上移 / 下移** 调整顺序。
- 取消排队（双人组会一起移除）。

### 语音播报
- 首页顶部「语音开 / 语音关」开关（状态会记住）。
- 播报格式：**「{机台名}叫号，请{玩家名}到{机台名}机台」重复两遍**。
- 音色、语速可在代码里调整（见「语音音色」一节）。

### 扫码
- 前置摄像头扫码，**横屏 / 竖屏画面随方向自动旋转**。
- 登录、拼机确认、加入双人组确认均为同一套扫码界面。

### 用户管理（后台）
- 首页顶部「用户管理」按钮 → 输入管理员密码进入。
- 初始管理员密码：**123456**（可在用户管理界面右上角「改密码」修改，修改后自动保存）。
- 支持：**删除用户、改名、改 PIN、显示用户二维码**。

---

## 三、语音音色修改

语音播报在 `Services/QueueManager.swift` 的 `announceCall` 方法。默认用系统中文女声：

```swift
utterance.voice = AVSpeechSynthesisVoice(language: "zh-CN")
```

**改法一：指定具体音色**

```swift
utterance.voice = AVSpeechSynthesisVoice(identifier: "com.apple.voice.compact.zh-CN.Tingting")
```

**改法二：列出设备所有可用中文音色**

```swift
for v in AVSpeechSynthesisVoice.speechVoices() where v.language.hasPrefix("zh") {
    print(v.identifier, "|", v.name, "|", v.language)
}
```

把打印出的 `identifier` 填到 `AVSpeechSynthesisVoice(identifier:)` 即可。同处还可调：

```swift
utterance.rate = 0.5              // 语速 0.0~1.0，越小越慢
utterance.pitchMultiplier = 1.0   // 音高 0.5~2.0，越大越尖
```

---

## 四、本地编译（macOS）

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

## 五、云构建（无 Mac 时，GitHub Actions）

1. 把本目录推送到 GitHub 仓库。
2. 在仓库 **Actions** 页运行 `Build unsigned IPA` 工作流（或推送 `v*` 标签自动触发）。
3. 完成后在运行记录里下载 `ElectronicQueueCard-unsigned` 产物。

---

## 六、把 IPA 装到 iPad

未签名 IPA 不能直接安装。请任选其一：

- **用 Xcode + 免费 Apple ID**：连接 iPad，在 Xcode 里打开工程，选择你的免费团队直接 Run（会自动用免费个人证书签名并安装）。
- **用已有开发者证书重签**：`codesign -f -s "iPhone Distribution: ..." --entitlements ... ElectronicQueueCard.app` 后重新打包。
- 企业内部/个人自有分发工具按各自流程签名安装。

> 首次运行会请求相机权限，请点击允许。营业时建议在「设置 → 辅助功能 → 引导式访问」开启锁定，防止玩家退出 App。

---

## 七、运营操作

| 操作 | 入口 |
| --- | --- |
| 结束本局 | 机台「游玩中」横幅里的「结束本局（员工）」 |
| 维护模式 | 长按机台栏顶部 |
| 改机台数量 | 首页顶部「机台数 N」菜单（1~6） |
| 改机台名称 | 机台栏名称旁铅笔按钮 |
| 语音开关 | 首页顶部「语音开 / 语音关」 |
| 用户管理 | 首页顶部「用户管理」→ 输入管理员密码（默认 123456） |
| 队列排序 | 队列条目上的 ▲ / ▼ |
| 取消排队 | 队列条目上的「取消」 |

---

## 八、JSON 备份导出

`BackupService.exportJSON()` 会把全部数据导出为 JSON 到 App 的 `Documents/Backups/queue-backup-<时间>.json`。工程已开启 `UIFileSharingEnabled` + `LSSupportsOpeningDocumentsInPlace`，可用「文件」App 或数据线（访达）取走。

> 当前版本把导出功能预留为服务层接口；如需在界面加一个「导出备份」按钮，可在公共屏顶部新增按钮调用 `BackupService(context:).exportJSON()` 并提示保存路径。

---

## 九、注意事项

- 各机台完全独立，不做跨机调度；双人匹配不跨机台。
- 过号栏 30 分钟从进入过号栏起算，到期自动清除，需重新排队。
- 过号回到队首后仍需玩家点「我回来了」确认。
- 取消排队不进过号栏，直接移除。
- iPad 摄像头在旧机型上可能扫码不稳，已保留「昵称 + PIN」登录兜底。
- 管理员密码、机台数量、语音开关、机台名称都会持久化保存。
- 引导式访问锁定 App；营业时 iPad 需持续充电（亮屏 + 摄像头耗电较快）。

---

## 十、版本记录

- **1.0.0** — 首个正式版本：多机台（1~6）、三种排队模式、玩家账号、扫码登录、语音播报、用户管理、队列排序、过号管理等完整功能。
