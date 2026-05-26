# 编码规范

## 通用规范（所有项目适用）

### 文件编辑规范
- **优先用 `edit`（精确替换）修改已有文件，不用 `write` 全量重写**
- 一次 turn 内只修改一个文件，改完输出简短确认（"文件X已更新"），等下一 turn 再改下一个
- `edit` 的 tool result 远小于 `write`，减少 context 膨胀，降低各类超时/abort 概率
- 全量重写仅在创建新文件时使用

### 项目目录结构
所有项目放在 `~/DevTeam/projects/<项目名>/` 下。技术栈特定结构见下方分节。

### 交付标准：图标（macOS .app）
所有 macOS .app 打包**必须**集成自定义图标，不允许出现默认空白图标：
1. 图标文件：`.icns` 格式（包含 16x16 到 1024x1024 全尺寸）
2. Xcode 项目：通过 `Assets.xcassets/AppIcon.appiconset` 集成，Contents.json 正确配置
3. 验证：打包后 Finder 和 Dock 中确认图标显示正确

---

## Swift/SwiftUI 规范

### 项目结构
```
projects/<项目名>/
├── <AppName>/
│   ├── App/              # App 入口、Coordinator
│   ├── Views/            # SwiftUI 视图
│   ├── ViewModels/       # ObservableObject
│   ├── Models/           # 数据模型
│   ├── Repositories/     # 数据访问层
│   ├── Services/         # 业务服务
│   └── Resources/        # Assets、配置文件
├── <AppName>.xcodeproj/
└── docs/
```

### SwiftUI 视图生命周期（踩过坑，必须遵守）

#### 1. ViewModel 持有方式
- **用 `@StateObject`，不用 `@ObservedObject`** 传递 ViewModel
- `@ObservedObject` 在父视图 body 重新求值时会重建 ViewModel，导致状态丢失
- sheet dismiss、tab 切换后父视图重渲染，`@ObservedObject` 绑定的 ViewModel 会被新实例替换
- **反例**（已导致关卡列表消失等 bug）：
  ```swift
  // ❌ body 中创建 ViewModel 传给 @ObservedObject
  var body: some View {
      ChildView(viewModel: MyViewModel(repo: app.repo))
  }
  ```
- **正例**：
  ```swift
  // ✅ 子视图用 @StateObject 自行持有 ViewModel
  struct ChildView: View {
      @StateObject private var viewModel = MyViewModel()
      // 或通过外部传入 repo 在 init 后加载数据
  }
  ```

#### 2. ViewModel init 必须加载初始数据
- **不要依赖 `onAppear` 加载数据**，`onAppear` 只在视图首次出现时触发
- sheet dismiss 后视图可能不重新触发 `onAppear`，导致数据为空
- **规则**：`init` 中加载初始数据，`onAppear` 仅用于刷新（需要时）
  ```swift
  class MyViewModel: ObservableObject {
      @Published var items: [Item] = []
      init(repo: MyRepository) {
          self.repo = repo
          loadItems()  // ✅ init 中加载
      }
  }
  ```

#### 3. 条件链必须有 loading 兜底
- View body 的 if/else if 条件链必须覆盖所有中间状态
- **session 为 nil + errorMessage 为 nil** = 正在加载中，必须显示 ProgressView，不能显示"暂未开放"或空白
- **反例**：
  ```swift
  if let session = session { ... }
  else if errorMessage != nil { ... }
  else { Text("暂未开放") }  // ❌ 加载中也显示这个
  ```
- **正例**：
  ```swift
  if let session = session { ... }
  else if errorMessage != nil { ... }
  else { ProgressView() }  // ✅ 加载中显示转圈
  ```

#### 4. sheet dismiss 后的状态恢复
- macOS 用 `.sheet`（不用 `.fullScreenCover`）
- onDismiss 回调中清理相关 State：levelId = nil、clearActiveSession、sheetId = UUID()
- sheet content 用 `.id(sheetId)` 强制重建，避免 SwiftUI 复用旧实例
- `DispatchQueue.main.asyncAfter` 回调中用 `[weak self]` 防止 sheet dismiss 后操作已释放的视图

#### 5. 硬编码防御
- 不要假设数组长度固定（如 `ForEach(0..<25)`），应使用实际数据源长度
- 关卡数量、题目数量等应从数据层获取，不硬编码

---

## Java/Spring Boot Web 规范

### 项目结构
```
projects/<项目名>/
├── <name>-backend/
│   ├── src/main/java/com/xxx/
│   ├── src/test/java/com/xxx/
│   └── pom.xml / build.gradle
├── <name>-frontend/
│   ├── src/
│   └── package.json
├── docker-compose.yml
├── docs/
└── README.md
```

### Java 环境
- 使用 jenv 管理 Java 版本
- 项目级 `.java-version` 设为 Java 17
- 需要先 `eval "$(jenv init -)"` 才能生效
- CI/构建前确保 jenv 已初始化

### 已知坑（来自 meetroom / knowledge-base 项目）
- `@TableLogic` 软删除注解会在所有 BaseMapper 方法自动追加 `WHERE deleted=0`，对已删除记录的 UPDATE 始终匹配 0 行
- 编码前必须对照 proposal 权限矩阵表实现权限逻辑，不能凭印象
- 同一实体的不同入口应共享校验逻辑，抽取公共 validator
- 无法本地编译时应在 Docker 内做编译验证

---

## 全局工具
```
~/DevTeam/
├── knowledge/               # 团队共享知识
│   ├── coding-standards.md  ← 你在这里
│   ├── design-checklist.md
│   ├── review-checklist.md
│   └── known-issues.md
├── projects/                # 所有项目
├── scripts/
│   └── verify_delivery.sh   # 交付门禁脚本
├── run_tests.sh
└── task_tracker.py
```
