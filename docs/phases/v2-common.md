# v3.7.0 通用设计信息

## 项目路径
`~/DevTeam/projects/chinese-chess/src`

## 构建与验证
```bash
cd ~/DevTeam/projects/chinese-chess/src && swift build
```
Xcode 测试：
```bash
cd ~/DevTeam/projects/chinese-chess && xcodebuild test -scheme ChineseChess -destination 'platform=macOS' -only-testing:ChineseChessTests/V370Phase1Tests
```

## 已完成（Phase 1）
- GameRecord 新增 source/tags/puzzleId + Codable 向后兼容
- GameRecordStore（JSON 文件存储引擎，替代 GameHistoryStore）
- FENRebuilder（从走法序列精确推算 FEN）
- PGNExporter（GameRecord → PGN 字符串）
- PGNImporter（PGN 字符串 → GameRecord，含容错）
- FENParser.isStandardInitial（归一化比较）
- RecordSummary 模型

## 关键约定
1. PGN ICCS 行号映射用 `9 - row`
2. GameRecordStore 写入用串行队列 + id 去重 + 原子写入
3. FEN 标准开局比较用 parse→generate→compare 归一化
4. Codable 新增字段必须 decodeIfPresent + 默认值
5. 现有 View 层仍使用旧 GameHistoryStore，Phase 1 未改 View

## 知识库
- ~/DevTeam/knowledge/coding-standards.md
- ~/DevTeam/knowledge/known-issues.md
