# VocabGame（背单词游戏）

面向初二女生的趣味背单词应用，融合蛋仔派对风格，内置 376 个单词。

## 技术栈
- SwiftUI, iOS 17+ / macOS 14+
- MVVM + Repository 架构
- 纯本地数据，无需网络

## Phase 1 功能（当前）
- ✅ 25 关线性解锁关卡系统
- ✅ 学习→练习→测试循环（选释义 / 选单词 / 听音选词 / 拼写）
- ✅ 星星评级 + 连击加分
- ✅ 蛋仔宠物（SwiftUI 绘制，5 级形态变化）
- ✅ 错词本（自动收录，连续答对 3 次移除）
- ✅ 间隔重复算法（简化版 SM-2）
- ✅ 原子写入持久化（杀进程恢复）
- ✅ 游戏会话保存/恢复

## 项目结构
```
VocabGame/
├── App/          # 入口 + AppCoordinator
├── Models/       # 数据模型
├── Repositories/ # 数据读写（Word/Progress/Pet）
├── ViewModels/   # 业务逻辑
├── Views/        # SwiftUI 视图
│   ├── Home/     # 首页
│   ├── LevelSelect/ # 关卡选择
│   ├── Game/     # 答题 + 结算
│   ├── PetHouse/ # 蛋仔之家
│   └── Profile/  # 我的 + 错词本
├── Services/     # 音效/TTS/间隔重复
├── Helpers/      # 常量/扩展
└── Resources/    # 数据 + Assets
```

## 构建
```bash
# 重新生成 wordlist.json（如修改了 data/wordlist.md）
python3 scripts/generate_wordlist.py data/wordlist.md VocabGame/Resources/Data/wordlist.json

# 生成 Xcode 项目（如修改了 project.yml）
xcodegen generate

# 编译（需 xcodebuild -runFirstLaunch 先配置好）
xcodebuild -project VocabGame.xcodeproj -scheme VocabGame -destination 'platform=iOS Simulator,name=iPhone 16' build
```
