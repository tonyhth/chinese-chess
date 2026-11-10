# 商业化启动包：Apple Developer 开通＋物料差距盘点＋上架路径建议

> 角色：coder2（Eric）｜日期：2026-11-10｜版本：v1.0
> 依据：台账 T-1104-2（洪涛 11-10 22:10 终裁②启动商业化；原派 Alex 会话故障转派 Eric，docs-only）
> 事实来源：象棋仓工程文件只读核查（2026-11-10 23:0x 时点：根 project.yml／ChineseChess-iOS/project.yml／两份 Info.plist／Assets.xcassets）＋Apple 公开流程常识
> 标注约定：【洪涛】=必须本人操作（实名/支付/协议主体）；【可查】=可代查代办；【候裁】=涉及产品取舍不擅自定；所有 Apple 界面细节以开通页面实时为准

## §0 结论先行

1. **唯一硬前置=付费开发者资格**（¥688/年）：iOS 工程签名链已配 Team Q86QW2K44W（疑似免费个人 team——10-30 真机部署来源），付费注册后同 Apple ID 通常延续同 Team ID，工程零改动即可出 TestFlight/App Store。
2. **工程面四项硬缺口**（提交前必补，合计约 1 天量级）：隐私政策 URL／PrivacyInfo.xcprivacy／ITSAppUsesNonExemptEncryption／商店规格截图。
3. **bundle id 无差距**：iOS 上架主体=com.tonyhuang.chinesechess（与任务书一致；com.chinesechess.app 是 macOS 根工程的另一 ID，双 ID 并存勿混）。
4. **建议节奏**：账号开通（1-2 天）→ 四缺口小批 → TestFlight 内测一轮 → App Store 免费直发 1.0 → IAP 第二批（先免费后付费=最简首审路径）。

## §1 Apple Developer 个人账号开通步骤（¥688/年）

> 前提判断：10-30 真机部署签名链已含 Team Q86QW2K44W（Xcode 登录免费个人 team 的典型特征）——**开通时必须用同一 Apple ID**（个人 team 注册付费计划后通常延续同 Team ID，工程里 DEVELOPMENT_TEAM=Q86QW2K44W 无需改）。

0. 前置确认【洪涛】：
   - 确认现用 Apple ID（Xcode 真机部署所用账号）；若记不清，Xcode → Settings → Accounts 查看
   - 双重认证确认：appleid.apple.com → 登录与安全 → 双重认证须为开启状态（开发者注册硬性要求；真机部署过则大概率已开）
   - 法定信息核对：注册用姓名/地址须与身份证件一致（个人账号以个人身份签约）
1. 开通入口【洪涛】：developer.apple.com/programs/enroll → 同一 Apple ID 登录 → 主体类型选 **Individual（个人）**
   - 个人 vs 组织：个人无需 D-U-N-S 编号；组织账号须公司实体——按个人走
2. 身份验证【洪涛】：按页面填写法定姓名/地址/证件信息（可能要求证件照片或人脸核验）
3. 签署协议【洪涛】：App Store Connect → Agreements, Tax, and Banking → 接受《付费应用协议》（Paid Application Agreement）
4. 缴费【洪涛】：¥688/年（等值 $99；支付通道以页面为准，含支付宝/银行卡选项，区域而定）。注意：**开发者会员资格不自动扣款，每年须手动续费**
5. 激活【洪涛查收】：通常 ≤48h 邮件通知；超 72h 未激活联系 Apple 开发者支持
6. App Store Connect 验证【洪涛＋Eric 核】：appstoreconnect.apple.com 同一 Apple ID 登录 → 会员详情页核对 Team ID：
   - 延续 Q86QW2K44W → 工程零改动
   - 若变化 → 告知 Eric，同步 ChineseChess-iOS/project.yml 一行
7. 后置（IAP 批次前完成，免费直发可暂缓）【洪涛】：ASC → Agreements, Tax, and Banking → 收款银行＋税务表格
8. 可选【洪涛】：ASC → Users and Access → 邀请协作者（个人账号支持有限角色：开发者/营销/财务等——需要 Eric 代管 ASC 时用）

**洪涛人工步照做清单（八步）**：①同一 Apple ID ②双重认证开 ③实名信息齐 ④选 Individual ⑤证件验证 ⑥签付费协议 ⑦付 ¥688 ⑧等激活邮件。除第⑧步外预计一个工作日内可完成。

## §2 物料差距盘点（逐项：现状→差距→动作）

事实基线：象棋仓两套工程——根 project.yml（macOS 主 target）＋ChineseChess-iOS/project.yml（iOS target，**App Store 上架主体**）。

### 2.1 Bundle ID ✅ 无差距
- 现状：iOS=**com.tonyhuang.chinesechess**（ChineseChess-iOS/project.yml:14，与任务书一致）；macOS=com.chinesechess.app（根 project.yml:13）——双 ID 并存，各归各
- 提示：bundle id 上架后**终身不可改**；现值即定稿值，勿再动
- 附注（候裁）：com.chinesechess.app 若日后上 Mac App Store 也可用，无需统一

### 2.2 签名链 ⚠️ 缺付费资格（§1 解决）
- 现状：iOS target 已配 DEVELOPMENT_TEAM=Q86QW2K44W＋CODE_SIGN_STYLE=Automatic（ChineseChess-iOS/project.yml:17-18）——10-30 真机部署即此链
- 差距：该 team 疑似免费个人资格（profile 7 天有效期、无 TestFlight/App Store 分发权限）——付费注册后解锁
- 动作：§1 完成后核对 Team ID 延续性；无需改工程签名配置
- 附注：macOS 根工程无 team＋CODE_SIGN_IDENTITY="-"（ad-hoc）——Mac App Store 直发（如做）需补；iOS 优先，macOS 暂缓

### 2.3 隐私政策 ❌ 硬缺口
- 现状：全仓无隐私政策文档/URL
- 差距：ASC 提交必填 Privacy Policy URL（免费 app 同样必填）
- 动作：出一页隐私政策（离线棋类口径：数据不收集/无追踪/本地存储/棋谱导入导出说明）→ 托管（GitHub Pages 最简）→ URL 入 ASC。文档 Eric 可代起草，托管与发布【洪涛】或交由既有通道

### 2.4 隐私清单 PrivacyInfo.xcprivacy ❌ 硬缺口
- 现状：两工程全无（全仓 find 零命中）
- 差距：UserDefaults 属 required-reason API（理由码 CA92.1），2024-05 起 App Store 提交强制要求隐私清单
- 动作：iOS target（及 macOS，随批）加 PrivacyInfo.xcprivacy：声明 UserDefaults=CA92.1；无追踪域；无数据收集。半小时量级，随四缺口小批

### 2.5 出口合规 ITSAppUsesNonExemptEncryption ❌ 小缺口
- 现状：两份 Info.plist 均无该键（grep 0 命中）——每次提交都会被问出口合规
- 差距：非阻塞但每次多一步答题
- 动作：iOS Info.plist 加 `ITSAppUsesNonExemptEncryption=YES`（仅用系统标准加密/HTTPS=豁免；棋类 app 无自研加密，YES 成立）。一行，随四缺口小批

### 2.6 年龄分级 ✅ 无代码动作
- 现状：分级在 ASC 问卷，仓内无对应项
- 动作：ASC 分级问卷——棋类无暴力/赌博/成人内容 → **4+ 全龄**。顺带：内容描述如实勾选即可

### 2.7 截图素材 ❌ 硬缺口
- 现状：releases/ 只有 macOS 旧窗口截图（v5.5.x 时代）；iOS 商店规格截图零；t1020 验收截图目录已清空
- 差距：提交必填（iPhone 6.9" 与 6.5" 两档规格必填；iPad 档因 TDF=1 不适用）
- 动作：模拟器按规格出图（对局主界面/教练页/复盘页等 3-10 张）＋可选文案叠加；0.5 天量级。规格以 ASC 提交页实时为准（6.9"=1320×2868 等）

### 2.8 IAP 面 ✅ 现状零（策略项非缺陷）
- 现状：全仓零 StoreKit 引用（grep 证实）
- 差距：变现面为零——但 1.0 免费直发恰是最简首审路径（无 IAP 审核面/无银行税表阻塞）
- 动作（候裁）：IAP（会员/道具/棋谱包）第二批立项：ASC 产品配置＋银行税表（§1 第 7 步）＋StoreKit 接入。本包不展开

### 2.9 图标与其他核对项 ✅ 基本可用（一项卫生项）
- 图标：共享 Assets.xcassets（src/ChineseChess/Resources/）——iOS 构建产物已见 AppIcon60x60@2x 生成在案；上架前核对 Contents.json 的 iOS 槽位映射＋1024 marketing icon 在集即可
- 版本/显示名/类别/本地化：6.5.0/6.5.0、中国象棋、board-games、zh-Hans ✅
- iOS 17.0+、iPhone only（TDF=1）、竖屏——如实提交，iPad 支持候裁
- 遗留小项：iOS Info.plist 的 UIRequiredDeviceCapabilities=armv7（32 位古董值）建议清理或换 arm64（随四缺口小批顺手）
- **工程卫生项（候裁，不阻塞）**：ChineseChess-iOS/ 整目录（含 project.yml＋Info.plist＋xcodeproj）在 gitignore——iOS 工程定义不在版本库；商业化工程面建议入库或至少双备份（工程再生性风险）

## §3 TestFlight vs App Store 直发对比＋节奏建议

| 维度 | TestFlight | App Store 直发 |
|------|-----------|----------------|
| 定位 | 测试分发（内测/灰度） | 面向公众的正式发布 |
| 审核 | 内部测试者（ASC 用户）零审核；外部测试者需简版 beta 审核（1-2 天） | 全量审核（棋类离线 app 低风险，通常 1-3 天） |
| 有效期 | 每个构建 90 天过期 | 长期有效，自动更新 |
| 规模 | 内部 ≤100／外部 ≤10000 | 公众 |
| 反馈 | 崩溃报告＋截图反馈内建 | 用户评价/评分 |
| 前置 | 同一签名链＋同一物料（隐私政策/合规键） | 全套物料（§2 四缺口） |

**节奏建议（三步，前提=§1 账号开通）**：

1. **D+0~D+2 账号开通**（§1 八步，预计一个工作日）＋四缺口小批（2.3 隐私政策/2.4 xcprivacy/2.5 合规键/2.7 截图——Eric 一批小 commit，含 armv7 顺手清理）
2. **D+2~D+7 TestFlight 内测一轮**：内部组（洪涛＋核心圈 ≤100）——目标=付费签名链真机验证＋隐私清单/合规键生效确认＋隐私政策链接走查
3. **D+7~D+14 App Store 免费直发 1.0**：全量审核（1-3 天）→ 可选 phased release（7 天逐步放量）→ 上线
4. **后置（候裁）**：IAP 第二批立项（§2.8）

**首审退回风险对照**（三大常见退回点均已被 §2 动作覆盖）：隐私政策缺失→2.3；截图规格不符→2.7；出口合规未答→2.5。

## 附：本包事实核查记录

- 核查时点：2026-11-10 23:0x；工程实态以仓 commit 时点为准（核查时树上有 T-1101-1 测试文件 WIP，与本包零交集）
- 事实源：根 project.yml（macOS）/ChineseChess-iOS/project.yml（iOS）/ChineseChess-iOS/Info.plist/src/ChineseChess/Resources/Info.plist/Assets.xcassets/全仓 StoreKit 与 PrivacyInfo find
- Apple 流程面（§1/§3）为公开流程常识，界面细节以 developer.apple.com 与 App Store Connect 实时页面为准
