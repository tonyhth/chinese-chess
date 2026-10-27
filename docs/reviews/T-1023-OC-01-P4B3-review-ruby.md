# T-1023-OC-01·P4·Batch3 首项审查（Ruby）— Enums.swift 渐升梯三轴单源表落地（方案 A 重锚）

- **对象**：d8d951f（父 b172bc3；6 files +190/-98）
- **审查人**：Ruby｜**日期**：2026-10-24 23:5x｜**链**：编码（Cody）→ **Ruby 审（本件）** → Tina 验 → 门禁 → tag
- **结论**：**代码面通过；测试面 P1-1 一项返工（CalibrationV3Tests 存量断言脱节未随批未申报），返工后可交 Tina**

---

## 一、独立验证记录（不依赖提审报告）

1. **变更清单**：`git show d8d951f --stat` 与申报逐行全等（6 files，+190/-98）；HEAD=d8d951f、父=b172bc3 亲验；tracked 面净（untracked 仅 docs 审查件）✅
2. **授权锚**：docs/design/t1023-remediation-plan.md v1.1 §五首项表与 s2Spec 代码**十档三轴逐格全等**（skill s0/s2/s4/s5/s7/s9/s11/s14/s17/s20｜movetime 1000豁免/500/700/1000/1400/2000/2800/3600/4400/5000｜ladderElo 1000/1338/1712/1801/2056/2336/2473/2627/2700/3170）；注记①（丹妮 10-24 22:4x movetime 首值 1000 定稿澄清）在 plan 正式记载；**无越权重锚** ✅
3. **单源纪律全仓扫描**：Enums.swift 外零梯表字面量（budgetMs/movetime/skill 映射面全过）；AIEngine:286/:425 novice 预算单源消费延续；SelfPlayRunner movetime 面全为 CLI 旗标处理非梯表散落 ✅
4. **日志证据**：BUILD SUCCEEDED（t1023p4-b3-build-1024.log）+ 四套件 4/4 PASS（t1023p4-b3-tests-1024.log，23:41-23:42，mutex owner=cody 单通道，skip 单含 EloBaselineTests 等 8 项）✅

## 二、四重点审查结论

1. **单源纪律 ✅**：三轴映射仅存 Enums.swift s2Spec；四处转正（skillToDifficulty 派生/skillLevel=s2Spec.skill/s2SkillToApply 单源简化/引擎锁表门=usesPikafish）之外无遗漏散落字面量。
2. **行为变更授权锚 ✅**：lvl6-9 消费转正（skill 0/4/7/10→9/11/14/17，预算 5000/6000/7000/8000→2000/2800/3600/4400）在方案 A 裁定表内；transitionSlot 标志保留=UI 分组语义（消费已单源）；s2SkillToApply 简化后旧 skillLevel 优先级通道退役为派生，无第二真相源。
3. **旧门放宽一致性 ✅**：plan 注记②四门与 T1023P4B3LadderTableTests 门①-④一一对应；S2Relevel 段距门 ≥100→全梯非降（1338<1712<1801<2056 严格段+lvl8↔lvl9 差 73 非降承载）；SelectionConsistency ①-7 载体口径（skillLevel≠nil ⇔ usesPikafishEngine）与单源派生自洽，isProfessional 五档分组显式维持。
4. **harness 兼容 ✅（附 P2-1 注释失真登记）**：pfmatch/calibrate 链路亲验——s2SkillToApply 外部 override 守卫未动（guard externalOverride==nil 优先）；depth 面：改动前 (override 存活∧skillLevel nil)→0 + s2LockTable→0，改动后 .amateurLow.skillLevel=4 使第一分支失效但 s2LockTable(=usesPikafish) depth=0 短路兜住，**终值等价**；timeLimitMs 经 mapDifficulty 尾部（>0 透传）不变；占位难度换新（就近=九档梯表）仅影响横幅显示与兜底路由，实际 Skill 由 override 控盘——无控盘面副作用。

## 三、问题清单

### 🔴 P1-1 CalibrationV3Tests 存量断言与新实现脱节，未随批更新且未申报（返工面）
- **位置**：src/ChineseChessTests/CalibrationV3Tests.swift:150-180（skillMap0/4/7/10/13/20 六断言）
- **事实**：skillToDifficulty 就近基准换新（旧五档 0/4/7/10/20 → 九档梯表），缺省开关（lvl1UsesPikafish=false）下亲验推演：

| 输入 | 旧断言 | 新实现实际 | 判定 |
|---|---|---|---|
| 0 | amateurDan(0) | beginner(2) | 🔴 红 |
| 4 | proApprentice(4) | amateurLow(4) | 🔴 红 |
| 7 | proExpert(7) | amateurHigh(7) | 🔴 红 |
| 10 | proMaster(10) | amateurDan(9) | 🔴 红 |
| 13 | proMaster(10) | proExpert(14) | 🔴 红 |
| 20 | grandmaster(20) | grandmaster(20) | ✅ 绿 |

- **六断言五必红**。本批测试批未含该套件（runner skip 单全量批 skip，定向批四套件清单外），"四套件 4/4 PASS"不覆盖此断裂面；提审报告亦未申报该遗留。
- **违反**：DEVTEAM.md 测试门规——改动面存量规格测试须同批自洽；skip-registry 注明该套件"单跑/定向批不受限"，Tina 隔离复跑即踩雷。
- **处置**：随返工批更新六断言至新就近语义（上表"新实现实际"列即期望值），不改 skillToDifficulty 实现——实现本身符合方案 A 单源纪律，返工仅测试面；若 skip 状态有变同步 skip-registry。

### 🟡 P2-1 .amateurLow"skillLevel 返回 nil"注释前提失真（三处）
- SelfPlayRunner.swift:936、:1244-1245、:1653 注释仍称".amateurLow（skillLevel 返回 nil）"——本批重锚后 .amateurLow.skillLevel=4。P0 防覆盖效果由 s2SkillToApply 守卫+s2LockTable depth=0 双保险维持（本批复核行为等价），但注释误导下一个维护者，且该等价依赖 s2LockTable 分支存活。建议同文件注释随批勘误（纯注释，零行为）。

### 🟡 P2-2 转正面清单补充：SelfPlayRunner:1106-1107 skillLevel 派生消费点
- `redSkillOverride ?? redDifficulty.skillLevel ?? 0`——无字面量、走单源派生（合规），但 redSkillOverride 缺省 nil 时载体档位实际强度随重锚实变（如 amateurDan 载体 0→9）。属"全 Pikafish 档从表"裁定自然延伸，非越权；申报"四处已转"未单列此点。登记供 Tina 验收对照，并备注**自弈历史对局基线可比性**（老数据锚旧刻度，跨版本对比需换轨说明）。

### ⚪ 观察（不阻塞）
- **O-1**：skillToDifficulty 候选集依赖全局开关 lvl1UsesPikafish：=true 时 novice(s0) 入候选，skill 0/1 就近结果随开关漂移（novice vs beginner）。开关为 dev 实验资产缺省 false，可接受；建议补一行注释声明该敏感性。
- **O-2**：skillToDifficulty 兜底 `?? .beginner`：min(by:) 非空候选集上不可达（死代码面），旧兜底 .amateurDan 同性质。可留。
- **O-3**：S2Relevel 完整性门① `?? -1`：a 形态 novice nil 视为 -1 使相邻比较虚假满足——门意图为 Pikafish 面刻度递增，语义可接受，注记即可。

## 四、红线自查（亲验）

| 项 | 结果 |
|---|---|
| L10n 锁表/xcstrings | diff 零触碰 ✅（C7 仅代码注记，UI 文案候具体文案令 ✅） |
| 定稿件（ChineseChess-iOS/） | 零触碰 ✅ |
| s2MigrationMap/Codable | map 本体零变更（仅冻结注记追加）；AIDifficulty rawValue 与 S2LevelSpec 结构零变更；Codable 恒等用例过 ✅ |
| 测试单通道 | run-tests-mutex owner=cody（23:41:00 获锁）✅ |
| 树净 | git status tracked 面空 ✅ |

## 五、判定

**代码面通过——方案 A 落地精确、授权锚逐格全等、无越权重锚、红线零触碰。测试面 P1-1 一项返工（CalibrationV3Tests 六断言更新，仅测试文件），返工批随带 P2-1 注释勘误后即可交 Tina 验收。**

依 2026-10-18 丹妮协议：判词落盘即完成，三方通知由 lead sweep 代行。

—— Ruby｜2026-10-24 23:5x｜OpenClaw 审计线（零 commit）
