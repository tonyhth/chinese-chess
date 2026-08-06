# 规范化批次 3+4+6：NNUE 去重 + 编译产物清理 + Pikafish 源码去重 + 旧 .app 清理

> 负责人：Cody | 来源：Alex 规划 | 日期：2026-06-29
>
> ⚠️ **绝对禁止操作以下路径**：
> - `src/ChineseChess/Resources/pikafish.nnue`（打包源，48MB）
> - `src/ChineseChess/Pikafish/lib/`（3 个预编译静态库，编译依赖）
> - `中国象棋-v3.3.0.app`（上一稳定版，Tina 测试中）
> - `中国象棋-v3.4.0.app`（最新版，Tina 测试中）

---

## 批次 6：旧 .app 清理（独立，优先执行）

> 独立于批次 3/4，先清理释放空间。用 `trash` 而非 `rm`，保留恢复可能性。

### 步骤 6.1：确认 trash 命令可用

```bash
which trash 2>/dev/null || echo "trash not found"
```

如果没有 `trash`，用 macOS 系统命令：

```bash
# macOS 自带：移到废纸篓
trash_func() {
  osascript -e 'tell application "Finder" to delete POSIX file "'"$1"'"'
}
```

或安装：`brew install trash`（如果 brew 可用）。

如果以上都不可用，用 `mv` 移到临时目录：

```bash
mkdir -p ~/DevTeam/.trash
# 然后用 mv 而非 rm
```

### 步骤 6.2：移除旧 .app（12 个）

**保留**（不碰）：
- `中国象棋-v3.3.0.app`（35MB）— 上一稳定版
- `中国象棋-v3.4.0.app`（83MB）— 最新版

**删除**（12 个，约 367MB）：

```bash
cd ~/DevTeam/projects/chinese-chess

# 用 trash（如果可用）
trash 中国象棋-v2.2.10.app \
      中国象棋-v2.2.11.app \
      中国象棋-v2.2.12.app \
      中国象棋-v2.2.13.app \
      中国象棋-v2.2.14.app \
      中国象棋-v2.2.15.app \
      中国象棋-v2.2.20.app \
      中国象棋-v2.2.20n.app \
      中国象棋-v2.2.21.app \
      中国象棋-v3.2.1.app \
      中国象棋-v3.2.2.app \
      中国象棋-v3.2.3.app

# 如果 trash 不可用，用 mv 到临时目录
# mkdir -p ~/DevTeam/.trash
# mv 中国象棋-v2.2.*.app ~/DevTeam/.trash/
# mv 中国象棋-v3.2.*.app ~/DevTeam/.trash/
```

### 批次 6 验证

```bash
ls -d ~/DevTeam/projects/chinese-chess/*.app
# 预期：只有 v3.3.0 和 v3.4.0
```

---

## 批次 3：NNUE 去重 + 编译产物清理

### 当前状态

| 项目 | 数量 | 大小 |
|------|------|------|
| NNUE 冗余副本 | 4 份 | 4×48MB = 192MB |
| .o 编译产物 | 197 个 | ~67MB |
| .a 编译产物 | 7 个 | ~11MB |
| build_phase6/ | 整个目录 | 49MB |
| build_smoke/ | 整个目录 | 49MB |
| src/.build/ | SPM 编译缓存 | 648MB |

**总预计释放：~1016MB**

### 步骤 3.1：删除 build_phase6 和 build_smoke 目录

```bash
rm -rf ~/DevTeam/projects/chinese-chess/ChineseChess-iOS/build_phase6/
rm -rf ~/DevTeam/projects/chinese-chess/ChineseChess-iOS/build_smoke/
```

验证：
```bash
ls ~/DevTeam/projects/chinese-chess/ChineseChess-iOS/build_phase6 2>/dev/null
# 预期：No such file or directory
```

### 步骤 3.2：删除 NNUE 冗余副本（保留打包源）

```bash
# 以下 3 份 NNUE 副本在 build_phase6/build_smoke 删除后可能已不存在
# 如果在 Pikafish/ 目录下还有，逐个删除

# Pikafish/pikafish.nnue（48MB）
rm -f ~/DevTeam/projects/chinese-chess/ChineseChess-iOS/Pikafish/pikafish.nnue

# Pikafish/src/nnue.bin（48MB，与 pikafish.nnue 内容相同）
rm -f ~/DevTeam/projects/chinese-chess/ChineseChess-iOS/Pikafish/src/nnue.bin
```

**受保护文件确认（不允许碰）**：
```bash
# 以下文件必须存在，不允许删除
ls -lh ~/DevTeam/projects/chinese-chess/src/ChineseChess/Resources/pikafish.nnue
# 预期：48MB
```

### 步骤 3.3：删除 .o 编译产物（197 个）

```bash
rm -f ~/DevTeam/projects/chinese-chess/ChineseChess-iOS/Pikafish/src/*.o
rm -f ~/DevTeam/projects/chinese-chess/ChineseChess-iOS/Pikafish/src/uci_sim.o
rm -f ~/DevTeam/projects/chinese-chess/ChineseChess-iOS/Pikafish/src/uci_sim_x64.o
```

> 注意：部分 .o 可能在子目录中。先确认：
> ```bash
> find ~/DevTeam/projects/chinese-chess/ChineseChess-iOS/Pikafish/src/ -name "*.o" -delete
> ```

验证：
```bash
find ~/DevTeam/projects/chinese-chess/ChineseChess-iOS/Pikafish/src/ -name "*.o" | wc -l
# 预期：0
```

### 步骤 3.4：删除 .a 编译产物（7 个）

```bash
# 这些是 iOS 项目直接编译方案产生的静态库
# v3.4.0 已改为预编译方案，静态库统一在 src/ChineseChess/Pikafish/lib/ 下
# ChineseChess-iOS/Pikafish/src/ 下的 .a 不再需要

rm -f ~/DevTeam/projects/chinese-chess/ChineseChess-iOS/Pikafish/src/libpikafish.a
rm -f ~/DevTeam/projects/chinese-chess/ChineseChess-iOS/Pikafish/src/libpikafish_no_main.a
rm -f ~/DevTeam/projects/chinese-chess/ChineseChess-iOS/Pikafish/src/libpikafish_x86_64.a
rm -f ~/DevTeam/projects/chinese-chess/ChineseChess-iOS/Pikafish/src/libpikafish_arm64_no_main.a
rm -f ~/DevTeam/projects/chinese-chess/ChineseChess-iOS/Pikafish/src/libpikafish_ios_sim_x64.a
rm -f ~/DevTeam/projects/chinese-chess/ChineseChess-iOS/Pikafish/src/libpikafish_ios_sim_arm64.a
rm -f ~/DevTeam/projects/chinese-chess/ChineseChess-iOS/Pikafish/src/libpikafish_ios_arm64.a
```

**受保护文件确认（不允许碰）**：
```bash
ls -lh ~/DevTeam/projects/chinese-chess/src/ChineseChess/Pikafish/lib/ios/libpikafish.a
ls -lh ~/DevTeam/projects/chinese-chess/src/ChineseChess/Pikafish/lib/ios-sim/libpikafish.a
ls -lh ~/DevTeam/projects/chinese-chess/src/ChineseChess/Pikafish/lib/macos/libpikafish.a
# 预期：3 个文件都存在
```

### 步骤 3.5：清理 SPM 编译缓存

```bash
rm -rf ~/DevTeam/projects/chinese-chess/src/.build/
```

> 注意：`.build/` 是 SPM 编译缓存，下次 `swift build` 会重新生成。不影响编译。

### 步骤 3.6：Git 追踪 docs/ 目录

> 丹妮追加任务（2026-06-29）。当前 .gitignore 把整个 docs/ 和所有 *.md 忽略了，改为追踪 docs/。

**操作步骤**：

1. 先查看当前 .gitignore 中的 docs/ 和 *.md 规则：
```bash
cd ~/DevTeam/projects/chinese-chess
grep -n 'docs/' .gitignore
grep -n '\*.md' .gitignore
```

2. 从 .gitignore 删除 `docs/` 行（如果有）

3. 把全局 `*.md` 忽略收窄为只忽略根目录散落的临时 .md：
```gitignore
# Temporary docs (not in docs/ directory)
/*.md
!README.md
```

> ⚠️ 注意：修改 .gitignore 时不能误伤已追踪文件。修改前先 `git status` 确认。

4. 纳入追踪：
```bash
git add docs/
```

5. 确认暂存状态：
```bash
git status --short docs/ | head -20
git status --short docs/ | wc -l
# 预期：73 个新文件被追踪
```

6. 提交：
```bash
git commit -m "feat: track docs/ directory in git"
```

### 批次 3 验证

```bash
# 1. NNUE 剩余份数
find ~/DevTeam/projects/chinese-chess -name "pikafish.nnue" -o -name "nnue.bin" | wc -l
# 预期：1（只有 src/ChineseChess/Resources/pikafish.nnue）

# 2. .o 清零
find ~/DevTeam/projects/chinese-chess/ChineseChess-iOS -name "*.o" 2>/dev/null | wc -l
# 预期：0

# 3. ChineseChess-iOS 下 .a 清零
find ~/DevTeam/projects/chinese-chess/ChineseChess-iOS -name "*.a" 2>/dev/null | wc -l
# 预期：0

# 4. build_phase6 / build_smoke 不存在
ls ~/DevTeam/projects/chinese-chess/ChineseChess-iOS/build_phase6 2>/dev/null
ls ~/DevTeam/projects/chinese-chess/ChineseChess-iOS/build_smoke 2>/dev/null
# 预期：No such file or directory

# 5. .build 不存在
ls ~/DevTeam/projects/chinese-chess/src/.build 2>/dev/null
# 预期：No such file or directory

# 6. 受保护文件完好
ls -lh ~/DevTeam/projects/chinese-chess/src/ChineseChess/Resources/pikafish.nnue
ls ~/DevTeam/projects/chinese-chess/src/ChineseChess/Pikafish/lib/ios/libpikafish.a
ls ~/DevTeam/projects/chinese-chess/src/ChineseChess/Pikafish/lib/ios-sim/libpikafish.a
ls ~/DevTeam/projects/chinese-chess/src/ChineseChess/Pikafish/lib/macos/libpikafish.a
# 预期：全部存在

# 7. ChineseChess-iOS/Pikafish/ 当前大小
du -sh ~/DevTeam/projects/chinese-chess/ChineseChess-iOS/Pikafish/
# 预期：远小于 113MB（只剩源码文件）
```

---

## 批次 4：Pikafish 源码去重

> 依赖：批次 3 完成后执行。

### 背景

`ChineseChess-iOS/Pikafish/` 是 iOS 项目早期的直接编译方案，包含完整 C++ 源码。
v3.4.0 已改为预编译静态库方案（`src/ChineseChess/Pikafish/lib/`），整个目录不再需要。

### 步骤 4.1：删除整个 ChineseChess-iOS/Pikafish/ 目录

```bash
rm -rf ~/DevTeam/projects/chinese-chess/ChineseChess-iOS/Pikafish/
```

> ⚠️ 执行前二次确认：
> - 批次 3 已完成（编译产物 + NNUE 已清除）
> - `src/ChineseChess/Pikafish/lib/` 下有 ios、ios-sim、macos 三个平台的预编译库
> - `src/ChineseChess/Pikafish/include/pikafish_api.h` 是统一的 API 头文件
> - `ChineseChess-iOS/Pikafish/` 下的 C++ 源码、Makefile、pikafish_api.h 等全部冗余

### 步骤 4.2：确认 ChineseChess-iOS/ 剩余内容

```bash
ls ~/DevTeam/projects/chinese-chess/ChineseChess-iOS/
# 检查是否还有其他需要的内容
# 如果目录为空或只剩过期内容，可以清除整个目录
```

### 批次 4 验证

```bash
# 1. ChineseChess-iOS/Pikafish/ 已删除
ls ~/DevTeam/projects/chinese-chess/ChineseChess-iOS/Pikafish/ 2>/dev/null
# 预期：No such file or directory

# 2. pikafish_api.h 仅存在一处
find ~/DevTeam/projects/chinese-chess -name "pikafish_api.h" 2>/dev/null
# 预期：只有 src/ChineseChess/Pikafish/include/pikafish_api.h

# 3. 受保护文件完好
ls -lh ~/DevTeam/projects/chinese-chess/src/ChineseChess/Pikafish/lib/ios/libpikafish.a
ls -lh ~/DevTeam/projects/chinese-chess/src/ChineseChess/Pikafish/lib/ios-sim/libpikafish.a
ls -lh ~/DevTeam/projects/chinese-chess/src/ChineseChess/Pikafish/lib/macos/libpikafish.a
ls -lh ~/DevTeam/projects/chinese-chess/src/ChineseChess/Pikafish/include/pikafish_api.h
# 预期：全部存在
```

---

## 执行顺序

1. **批次 6**（旧 .app 清理）— 独立，先执行释放空间
2. **批次 3**（NNUE 去重 + 编译产物清理）— 依赖：无
3. **批次 3 验证**
4. **批次 4**（Pikafish 源码去重）— 依赖：批次 3 完成
5. **批次 4 验证**

---

## 空间节省预估

| 批次 | 清理项 | 节省 |
|------|--------|------|
| 6 | 12 个旧 .app | ~367MB |
| 3 | build_phase6 + build_smoke | ~98MB |
| 3 | NNUE 冗余副本（2 份） | ~96MB |
| 3 | .o 文件（197 个） | ~67MB |
| 3 | .a 文件（7 个） | ~11MB |
| 3 | src/.build/ SPM 缓存 | ~648MB |
| 4 | ChineseChess-iOS/Pikafish/（源码去重） | ~113MB（批次3后剩余部分） |
| **总计** | | **~1400MB** |

---

## ⚠️ 禁止事项总表

1. ❌ 不碰 `src/ChineseChess/Resources/pikafish.nnue`
2. ❌ 不碰 `src/ChineseChess/Pikafish/lib/`（ios/ios-sim/macos 三个 .a）
3. ❌ 不碰 `src/ChineseChess/Pikafish/include/pikafish_api.h`
4. ❌ 不碰 `中国象棋-v3.3.0.app`
5. ❌ 不碰 `中国象棋-v3.4.0.app`
6. ❌ 不碰 `src/` 目录下任何源码文件
7. ❌ 不碰 `scripts/` 目录
