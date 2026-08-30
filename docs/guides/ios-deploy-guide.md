# iOS 真机发布标准流程

> 每次发布到 iPhone 必须严格按此文档执行，不要凭记忆操作。

## 前提条件
- iPhone 已通过数据线连接 Mac，已解锁并信任电脑
- `xcrun devicectl list devices` 能看到设备
- xcodegen 已安装（`brew install xcodegen`）
- 免费Apple ID签名（DEVELOPMENT_TEAM: Q86QW2K44W），**7天有效期**

## 配置文件
- 路径：`ChineseChess-iOS/project.yml`
- xcodegen 配置，**版本号每次发布前更新**（MARKETING_VERSION）
- 排除 `ChineseChessApp.swift`（macOS入口），保留 `ChineseChessiOSApp.swift`（iOS入口）
- pbxproj 由 xcodegen 管理生成，**不要手动编辑**

## 发布步骤

### 1. 更新版本号
```bash
# 编辑 ChineseChess-iOS/project.yml
# 将 MARKETING_VERSION 改为目标版本号（如 "2.2.21"）
```

### 2. 生成 Xcode 项目
```bash
cd ~/DevTeam/projects/chinese-chess/ChineseChess-iOS
xcodegen generate
```

### 3. 确认设备连接
```bash
xcrun devicectl list devices
# 确认 Tony's iPhone 出现在列表中，记下设备 ID
```

> ⚠️ 双 ID 坑（2026-08-30 实战）：devicectl 列出的 Identifier 是 **coredevice ID**（如 0BB3D5AF-…，仅 devicectl install/info 用），**xcodebuild -destination 不认它**。构建前用 `xcodebuild -project … -showdestinations | grep iPhone` 实测取 **USB UDID**（如 00008130-…）填入 -destination。

### 4. 构建 iOS 版
```bash
cd ~/DevTeam/projects/chinese-chess/ChineseChess-iOS
xcodebuild -project ChineseChess.xcodeproj \
  -scheme ChineseChess \
  -sdk iphoneos \
  -destination "id=<设备ID>" \
  -configuration Release \
  -allowProvisioningUpdates \
  CODE_SIGN_STYLE=Automatic \
  DEVELOPMENT_TEAM=Q86QW2K44W \
  build
```

### 5. 找到构建产物
```bash
# 从 xcodebuild 输出中找到 .app 路径
# 通常在 ~/Library/Developer/Xcode/DerivedData/ChineseChess-*/Build/Products/Release-iphoneos/ChineseChess.app
```

### 6. 安装到真机
```bash
xcrun devicectl device install app \
  --device <设备ID> \
  <ChineseChess.app路径>
```

### 7. 验证
- iPhone 上打开 App，确认版本号正确
- 检查关键功能：棋盘显示、走棋、残局、回放
- 如果首次安装提示"不受信任的开发者"：
  iPhone → 设置 → 通用 → VPN与设备管理 → 信任开发者证书

## 常见问题

### xcodebuild 找不到设备
- 确认 iPhone 已解锁屏幕
- 拔插数据线重新连接
- `xcrun devicectl list devices` 重新检查

### 签名失败
- 确认 DEVELOPMENT_TEAM 正确（Q86QW2K44W）
- Xcode → Settings → Accounts → 确认 Apple ID 已登录
- 删除 DerivedData 后重试：`rm -rf ~/Library/Developer/Xcode/DerivedData/ChineseChess-*`

### 7天过期
- 免费 Apple ID 签名的 App 7天后无法打开
- 重新连接 iPhone，从步骤4开始重新构建+安装

## 注意事项
- ⚠️ **不要手动编辑 pbxproj**，始终通过 project.yml + xcodegen generate
- ⚠️ **版本号必须与 macOS 版本同步**
- ⚠️ **iOS 入口是 ChineseChessiOSApp.swift**，不是 ChineseChessApp.swift（macOS）
- ⚠️ **免费签名限制**：7天过期，最多3个App同时安装
