# T-1023-OC-01·P2·dim7 — 工程与发布健康度检查报告

> 角色：Alex（架构师）| 日期：2026-10-20 | 版本：v1.0
> 范围：静态取证（零构建/零打包，P1-P3 约束）；对照面=releases/中国象棋-v6.4.2.app + 仓库 HEAD（v6.4.2-1-g1cfd109）
> 依据：docs/plans/T-1023-OC-01-inspection-plan.md v1.1 §四增补⑦（丹妮裁示②批准）

---

## 检查项与结论

### 1. [已实现/销项] 版本三字段一致性
CFBundleShortVersionString=6.4.2 = CFBundleVersion=6.4.2（v6.4.2 发布包 Info.plist PlistBuddy 亲证）= tag v6.4.2（v6.4.0/6.4.1/6.4.2 序列无跳号）= project.yml MARKETING_VERSION/CURRENT_PROJECT_VERSION 6.4.2（L63-64）。
HEAD=v6.4.2-1-g1cfd109（tag 后 1 个在途 commit，正常形态非缺陷）。
｜证据：PlistBuddy 输出、git tag --list、git describe｜处置：销项

### 2. [文档过时/P2·候选] release-notes 滞后两代
docs/release/release-notes.md v6.4 提及=0 次、v6.3=5 次，章节头部停在"v6.3.0 已知缺陷中间态"警示条——v6.4.0/v6.4.1/v6.4.2 三次正式发布（含 L10n 段位制换轨/工具栏 IA 重构/移动端适配等用户可感变更）零入册。
商业交付视角（r3-07 R4 交付验收面）发布说明缺三版。
｜doc: docs/release/release-notes.md（grep 计数+章节结构）｜code: releases/ 三包在盘｜处置：**P3 整改 B 包**——补 v6.4.x 发布条目（内容源=台账 T-1019/T-1020/T-1021 收口记录+tag log）

### 3. [已实现/销项] 发布包资产四件套完整
NNUE：pikafish.nnue 50,760,458B（Oct 18 23:25 与 v6.4.2 cut 同时点）✅；字体：LXGWWenKai-Regular.ttf ✅；音效：move/capture/check/checkmate/defeat/victory/undo.wav 七件 ✅；开局库：opening_book_v2.json+openings.json+opening-categories.json+pgn-extracted/ ✅；残局：puzzles.json+puzzles-v3-backup.json（551×2）✅；**AppIcon.icns 在位**（打包规范必查项+图标强制交付标准符合）；另有 eval-weights.json/master-game-index.json/asset-manifest.json/en.lproj ✅
｜证据：Resources/ ls 全列｜处置：销项

### 4. [卫生缺口/P2·候选] 发布包 tmp 残留
Resources/ 含 tmp.1y39nu、tmp.MPQY5y、tmp.ZkH6Tj 三个临时文件混入发布包——打包清理缺口（非功能影响，商业交付观感+包体卫生）。
｜证据：ls Resources/ 亲证三文件｜处置：**P3 整改 B 包**——P4 重打包时打包脚本排除 tmp.*（并清本包残留）

### 5. [规范漂移/P3·候选] DEVTEAM.md docs-gitignore 声明与实践不符
DEVTEAM.md"禁止提交的文件"声明 docs/ *.md（除 README）通过 .gitignore 排除；实际近期 history 含 docs 批量 commit（6fdc513 phase-6 批/ac98447 prd 等），且 git status 将 docs/*.md 显示为 untracked（??）而非 ignored——规范文本与仓库实践漂移。
另：当前 7 个 untracked 均为 t1023 检查文档（本线+各维在途稿；OC 审计线零 commit，处置归 P3 文档修批统一定）。
｜doc: DEVTEAM.md Git 规范节｜code: git log 6fdc513/ac98447+git status 形态｜处置：P3 澄清（二选一：补 .gitignore 或修订 DEVTEAM.md 文本）

## 汇总

| 销项 | P2 候选 | P3 候选 | P0 | P1 |
|------|---------|---------|----|----|
| 3 | 2（release-notes 滞后/tmp 残留） | 1（DEVTEAM gitignore 漂移） | 0 | 0 |
