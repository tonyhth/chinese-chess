# 规范化批次 1+2：文档迁移 + tools 清理

> 负责人：Cody | 来源：Alex 规划 | 日期：2026-06-29
>
> ⚠️ **绝对约束：不允许操作 `~/DevTeam/projects/chinese-chess/src/` 下的任何文件。打包正在并行进行。**

---

## 批次 1：Git 清理 — 文档迁移（35 个 .md 文件）

### 目标目录结构（项目内）

```
~/DevTeam/projects/chinese-chess/docs/
├── active/
│   ├── design/
│   ├── phases/
│   ├── bugs/
│   └── spikes/
├── archive/
│   ├── v2.2.18/          # 已有
│   ├── v3.0/
│   ├── v3.1/             # 已有目录，合并
│   └── v3.2.x/
│   └── v3.3.0/
├── general/
├── guides/
├── reviews/
└── README.md
```

### 步骤 1.1：创建缺失目录

```bash
cd ~/DevTeam/projects/chinese-chess/docs
mkdir -p active/design active/phases active/bugs active/spikes
mkdir -p archive/v3.0 archive/v3.2.x archive/v3.3.0
```

### 步骤 1.2：迁移 v3.0 归档文档（13 个文件）

```bash
# v3 overview + phase1~11 → archive/v3.0/
SRC=~/DevTeam/docs/phases
DST=~/DevTeam/projects/chinese-chess/docs/archive/v3.0

mv "$SRC/v3-overview.md"    "$DST/overview.md"
mv "$SRC/v3-phase1.md"      "$DST/phase1.md"
mv "$SRC/v3-phase2.md"      "$DST/phase2.md"
mv "$SRC/v3-phase3.md"      "$DST/phase3.md"
mv "$SRC/v3-phase4.md"      "$DST/phase4.md"
mv "$SRC/v3-phase5.md"      "$DST/phase5.md"
mv "$SRC/v3-phase6.md"      "$DST/phase6.md"
mv "$SRC/v3-phase7.md"      "$DST/phase7.md"
mv "$SRC/v3-phase8.md"      "$DST/phase8.md"
mv "$SRC/v3-phase9.md"      "$DST/phase9.md"
mv "$SRC/v3-phase10.md"     "$DST/phase10.md"
mv "$SRC/v3-phase11.md"     "$DST/phase11.md"
mv ~/DevTeam/docs/v3.0-upgrade-plan.md  "$DST/upgrade-plan.md"
```

### 步骤 1.3：迁移 v3.1 归档文档（1 个文件）

```bash
# v3.1-phase2-design.md → 已有 archive/v3.1/ 目录（实际是 docs/v3.1/）
mv ~/DevTeam/docs/phases/v3.1-phase2-design.md \
   ~/DevTeam/projects/chinese-chess/docs/archive/v3.1/phase2-design.md
```

> 注意：项目内已有 `docs/v3.1/` 目录。执行后检查是否需要将 `docs/v3.1/` 整体移到 `docs/archive/v3.1/`。如果 `docs/v3.1/` 已有内容，合并即可。

### 步骤 1.4：迁移 v3.2.x 归档文档（3 个文件）

```bash
DST=~/DevTeam/projects/chinese-chess/docs/archive/v3.2.x

mv ~/DevTeam/docs/phases/v3.2.3-board-flip-design.md    "$DST/board-flip-design.md"
mv ~/DevTeam/docs/phases/v3.2.3-side-toggle-color-fix.md "$DST/side-toggle-color-fix.md"
mv ~/DevTeam/docs/phases/v3.2.3-side-toggle-design.md   "$DST/side-toggle-design.md"
```

### 步骤 1.5：迁移 v3.3.0 归档文档（1 个文件）

```bash
mv ~/DevTeam/docs/phases/v3.3.0-ios-engine-integration.md \
   ~/DevTeam/projects/chinese-chess/docs/archive/v3.3.0/ios-engine-integration.md
```

### 步骤 1.6：迁移 v3.4.0 活跃文档（6 个文件）

> ⚠️ Luke 指示：批次 2b（v3.4.0 文档迁移到 active/phases/）等打包完成后再做。
> 但 v3.4.0 文档必须从 `~/DevTeam/docs/phases/` 移走（因为整个目录要废弃）。
>
> 方案：先移到 `active/phases/`。这些是文档文件，不影响 src 编译和打包。

```bash
SRC=~/DevTeam/docs/phases
DST=~/DevTeam/projects/chinese-chess/docs/active/phases

mv "$SRC/v3.4.0-ios-engine-implementation-plan.md"  "$DST/"
mv "$SRC/v3.4.0-macos-static-embed-common.md"       "$DST/"
mv "$SRC/v3.4.0-macos-phase-a.md"                   "$DST/"
mv "$SRC/v3.4.0-macos-phase-b.md"                   "$DST/"
mv "$SRC/v3.4.0-macos-phase-c.md"                   "$DST/"
mv "$SRC/v3.4.0-macos-phase-d.md"                   "$DST/"
```

### 步骤 1.7：迁移 nnue-embedding-investigation.md

```bash
mv ~/DevTeam/docs/phases/nnue-embedding-investigation.md \
   ~/DevTeam/projects/chinese-chess/docs/active/spikes/
```

### 步骤 1.8：迁移通用设计文档（8 个文件）

```bash
DST=~/DevTeam/projects/chinese-chess/docs/active/design

mv ~/DevTeam/docs/cmaes-parallel-design.md              "$DST/"
mv ~/DevTeam/docs/guided-puzzle-design.md               "$DST/"
mv ~/DevTeam/docs/language-switch-fix.md                "$DST/"
mv ~/DevTeam/docs/quick-engine-toggle-design.md         "$DST/"
mv ~/DevTeam/docs/replayboardview-design.md             "$DST/"
mv ~/DevTeam/docs/replayviewmodel-observableobject-migration.md "$DST/"
mv ~/DevTeam/docs/v2.2.17-ios-bug-analysis.md           "$DST/"
mv ~/DevTeam/docs/design/r3-06c-spm-localization-fix.md "$DST/"
mv ~/DevTeam/docs/design/r3-07-commercial-delivery-checklist.md "$DST/"
```

### 步骤 1.9：删除 .bak / .deprecated 文件（4 个）

```bash
rm ~/DevTeam/docs/phases/v3.4.0-ios-engine-implementation-plan.md.bak2
rm ~/DevTeam/docs/phases/v3.4.0-ios-engine-implementation-plan.md.bak
rm ~/DevTeam/docs/phases/project-normalization-plan.md.bak
rm ~/DevTeam/docs/phases/v3.4.0-macos-engine-embedding.md.deprecated
```

### 步骤 1.10：标记废弃目录

```bash
cat > ~/DevTeam/docs/.DEPRECATED << 'EOF'
此目录已废弃。
所有文件已迁移到 ~/DevTeam/projects/chinese-chess/docs/。
删除日期：2026-07-13（2 周后）
负责人：Cody

例外：project-normalization-plan.md 保留作为规范化方案主文档，直到全部批次完成后迁移。
EOF
```

### 步骤 1.11：保留规范化方案主文档

```bash
# project-normalization-plan.md 是本次规范化方案的主文档
# 暂不迁移，等全部批次（1-6）完成后最后迁移到 docs/general/
# 确保 ~/DevTeam/docs/ 还有这一个文件 + .DEPRECATED
ls ~/DevTeam/docs/phases/project-normalization-plan.md
```

### 批次 1 验证清单

```bash
# 1. 确认 ~/DevTeam/docs/ 只剩 .DEPRECATED + project-normalization-plan.md
ls ~/DevTeam/docs/
# 预期：.DEPRECATED  design/  phases/（只剩 normalization-plan）
find ~/DevTeam/docs -name "*.md" | wc -l
# 预期：1（只有 project-normalization-plan.md）

# 2. 确认项目 docs 目录结构
find ~/DevTeam/projects/chinese-chess/docs -type d | sort

# 3. 确认迁移后文件数
find ~/DevTeam/projects/chinese-chess/docs/active -type f -name "*.md" | wc -l
find ~/DevTeam/projects/chinese-chess/docs/archive -type f -name "*.md" | wc -l
```

---

## 批次 2：tools/pikafish/ 清理（~97MB）

### 步骤 2.1：验证 NNUE MD5 一致后删除冗余

```bash
# 确认 tools/pikafish/pikafish.nnue 与项目内一致
md5 ~/DevTeam/tools/pikafish/pikafish.nnue
# 预期：afb02b1edd42defa33b0cdceaf5d3f44
# 项目内同 MD5 → 冗余，可安全删除

rm ~/DevTeam/tools/pikafish/pikafish.nnue
rm ~/DevTeam/tools/pikafish/pikafish.nnue.bak
```

### 步骤 2.2：删除旧外部引擎二进制

```bash
# pikafish-bmi2 是旧外部进程方案的二进制
# v3.4.0 已改为静态库嵌入，不再需要
rm ~/DevTeam/tools/pikafish/pikafish-bmi2
```

### 步骤 2.3：删除过期 profiling 数据

```bash
rm ~/DevTeam/tools/pikafish/default_13964231922265547118_0.profraw
```

### 步骤 2.4：清除空目录

```bash
rmdir ~/DevTeam/tools/pikafish/
# 如果 tools/ 下没有其他内容，也清除
ls ~/DevTeam/tools/ 2>/dev/null && rmdir ~/DevTeam/tools/ 2>/dev/null || true
```

### 批次 2 验证清单

```bash
# 确认 tools/pikafish/ 已不存在
ls ~/DevTeam/tools/pikafish/ 2>/dev/null
# 预期：ls: No such file or directory

# 确认项目内 NNUE 仍在（打包源）
ls -la ~/DevTeam/projects/chinese-chess/src/ChineseChess/Resources/pikafish.nnue
# 预期：48MB，存在
```

---

## 执行顺序

1. 批次 1 步骤 1.1 ~ 1.11（文档迁移）
2. 批次 1 验证
3. 批次 2 步骤 2.1 ~ 2.4（tools 清理）
4. 批次 2 验证
5. 完成后 git add + commit（在项目目录内）

### Commit 规范

```bash
cd ~/DevTeam/projects/chinese-chess

# 批次 1
git add docs/
git commit -m "docs: migrate ~/DevTeam/docs/ to project docs/ structure (batch 1)"

# 批次 2（如果 tools/ 在项目 git 管理范围内）
# 注意：~/DevTeam/tools/ 不在项目 git 内，无需 commit
```

---

## ⚠️ 禁止事项

1. **不碰 `src/` 目录下的任何文件**
2. **不碰 `scripts/` 目录**（脚本规范化是批次 4）
3. **不碰 `ChineseChess-iOS/` 目录**（Pikafish 去重是批次 3/4）
4. **不做 git commit 到 src/ 相关的任何变更**
5. **不删除 ~/DevTeam/docs/phases/project-normalization-plan.md**（规范化主文档，最后迁移）
