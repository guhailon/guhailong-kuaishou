# 顾海龙快手 — BUILD_LOG

## v1.0.0 面板外壳版（2026-11-15）

- 目标机：iPhone 11 / iOS 16.5 / Dopamine (rootless)。
- 目标快手版本：**14.10.10 / build 10089**（Lee 2026-11-15 确认）。
- 包名：`com.guhailong.kuaishou`，Version 1.0.0。
- **只留本地（Lee 2026-11-15 10:58 定）**：不推送、不部署、不上越狱源。
  交付物 = 本 staging 目录里的源码 + 验过的冒烟 .deb + 本文件。

## 做了什么（Lee 勾中的 13 项，#3 搜索设置没勾、不做）

| # | 功能 | 状态 |
|---|---|---|
| 1 | 深色毛玻璃设置卡片（哆啦A梦图 + 金字「顾海龙快手」+ 英文小字，两列菜单，金底完成钮） | 做成（纯 UIKit） |
| 2 | 悬浮入口钮（独立 UIWindow，可拖动，位置记忆，点开面板） | 做成（纯 UIKit） |
| 4 | 金底「完成」按钮 | 做成（每页底部都有） |
| 5 | 面板开合动画（0.28s 弹簧放大淡入，关闭 0.2s） | 做成 |
| 6 | 精选纯净 | **探针日志 only**：每 3 秒扫可见 cell，只记类名与模型属性名，不改 feed |
| 7 | 底栏透明 | **探针（试验开关）**：通用 UIKit 遍历找贴底容器，改透明，2.5 秒后复查是否还在；关开关还原 |
| 8–12 | 通用设置／导航入口／首页／精选／消息／我／其他页面／播放互动 | 页面外壳，诚实标「规划」，无假开关 |
| 13 | 诊断反馈：本机状态（版本、探针结果、打开次数）、两个探针开关、一键复制状态文本、查看完整日志 | 做成 |
| 14 | 关于页：版本、说明、红字免责、QQ 2309103548（点按复制）；无 QQ 群链接 | 做成 |

- 菜单 10 格与参考卡片一致：通用设置、导航入口、首页、精选、消息、我、其他页面、播放互动、诊断反馈、关于。
- 日志：`Documents/GuHaiLongKuaishou.log`（超 512KB 丢前一半），诊断页可看尾部 200KB、复制、清空。
- 设置：CFPreferences 域 `com.guhailong.kuaishou`（App 沙盒 `Library/Preferences/com.guhailong.kuaishou.plist`）。
- Filter：`com.jiangjia.gif`（公开资料值；**上真机前须用 Filza 核对 Lee 手机上快手的实际 Bundle ID**）。
- 本版 **没有任何 Hook**：%ctor 只延后建悬浮钮、恢复探针开关、注册回前台通知。探针全是定时器 + 通用 UIKit 遍历。
- 哆啦A梦图：`layout/Library/Application Support/GuHaiLongKuaishou/doraemon.png`（168×168 PNG，44,177 B，分屏插件同款 `doraemon-button@3x.png`；Lee 2026-11-15 12:30 说图片换成哆啦A梦，v1.0.1 里龙头图已换掉）。
- 零字面量：源码 `@"` 0 个；`__cfstring` 0（见验证）。

## 构建过程（Linux 冒烟）

命令（分屏同款）：复制 staging 到 /tmp，`chmod -R 0755` + `chmod -R g-s`，
`umask 022; THEOS=~/theos TARGET=iphone:clang:16.5:15.0 make package`。

修了 3 个错才编过（都是写码时的手误）：
1. 子类直接访问父类自动合成的 ivar 被判 private → 子类改走 `self.scroll` / `self.content` / `self.card` 属性。
2. 诊断／日志／关于三个子页类只有 `@class` 前向声明、没有 `@interface`，编译器当成 root class → 补齐四个子页的 `@interface` 声明。
3. `objc_setAssociatedObject` 缺 `<objc/runtime.h>` → 补 import。
4. 链接报 C++ 修饰名 `__Z26GHLKSInstallFloatingButtonv` → `GHLKSPanel.h` 的 C 函数声明补 `extern "C"`。

其余只有已知的 arm64e ABI 警告（Linux 交叉工具链已知现象，分屏各版同款）。

## 验证（Linux 冒烟，/tmp/ghlks100，包验完已留 staging、/tmp 已清）

- `.deb`：`packages/com.guhailong.kuaishou_1.0.0-1+debug_iphoneos-arm64.deb`，
  **97,730 B，SHA256 `c271ef7eef52ba9175e1e3331977863acfa9e1baa59af1612045e62ee5adb8b0`**，
  control：Package `com.guhailong.kuaishou`、Version `1.0.0-1+debug`（+debug 是 Linux 冒烟版的后缀，macOS 发布包才是 1.0.0）、
  Architecture `iphoneos-arm64`、Depends `firmware (>= 15.0), mobilesubstrate`。
- 内容：dylib 370,656 B（`Library/MobileSubstrate/DynamicLibraries/GuHaiLongKuaishou.dylib`，
  Linux 冒烟路径；macOS rootless 发布包会自动落到 `var/jb/...`）、
  Filter plist 52 B（`com.jiangjia.gif`）、龙头图 29,706 B（256x256 JPEG，验过）。
- dylib：universal arm64 + arm64e（Linux 编的 arm64e 切片照例无 PAC00，macOS 编才有——冒烟只验语法）。
- `__cfstring`：**0 / 0**（两片皆无此 section，python 解析 Mach-O load commands 验过）。
- 禁 API 全 0（两片）：`CFNotificationCenterAddObserver`、`LSApplicationWorkspace`、
  `dispatch_get_global_queue`、`keyWindow`、`NSUUID`、`uuid_generate`、`uuid_unparse`。
  （主窗口用 normal 层级扫描找，不用已废弃的旧读法。）
- 中文字串 UTF-8 计数（两片一致）：「顾海龙快手」×3、「GUHAILONG KUAISHOU」×1、
  「底栏透明」×2、「精选探针」×3、「诊断反馈」×2、「规划」×1、「免责声明」×1、
  「2309103548」×2；版本字串「1.0.0」×15、「14.10.10」×2；
  「com.guhailong.kuaishou」×1、「GuHaiLongKuaishou.log」×1、「dragon-head.jpg」×2；
  日志字串「v1.0.0 loaded」×1、「panel opened」×1、「bottom probe」×4、「feed probe」×4。
- 源码层：`@"` 0 个（全部 7 个源码文件）；禁 API 字串 0 处。

## 诚实状态（没真机验过，不能算做成）

- 面板长什么样、悬浮钮能不能拖、点开收起顺不顺、10 个菜单格进不进得去——都要真机看。
- 底栏透明探针：遍历找不找得到底栏、改透明后留不留得住——只看真机日志 `v1.0.0 bottom probe` 那几行才知道。
- 精选探针：扫不扫得到 cell、模型属性名里有没有广告标记字段——只看真机日志 `v1.0.0 feed probe`。
- SF Symbol 图标（gearshape、stethoscope 等）在 iOS 16.5 上应有；万一某个名字不存在，代码有 fallback（questionmark.circle），格子不会空。
- Filter 的 `com.jiangjia.gif` 是公开资料值，上真机前必须核对。

## 下一步（等决定）

1. 类 dump 怎么做（Lee 没电脑）：没有 14.10.10 的 dump，精选纯净做不出实效，底栏透明也只能停在探针。
2. 若 Lee 要真机测：本冒烟包是 Linux debug 版、路径是 `Library/...`，**绝不能直接装到 rootless 真机上**；
   真机测试包要走 macOS 发布构建——但 Lee 已定本版只留本地，不推不编发布包，真机测的事等他另行定。

## 2026-11-15 11:59 — Lee 改批：公开仓库 + macOS 编译 + 上源

- 10:58 Lee 定本版只留本地（不推、不部署、不上源）；11:54 Lee 问"做了吗"，回的是冒烟包已验过、真机包要走 macOS 编、没批不动。
- 11:59 Lee 说"我现在批"，经确认：新建公开 GitHub 仓库 `guhailon/guhailong-kuaishou`、走 macOS 编真机包、包直接发他、不上源。
- 随后（11:59）Lee 又改口"上源吧"——最终决定：**macOS 包编好验过后上越狱源**（不再是只留本地）。
- 本地准备（本机完成，未推送、未调 GitHub API、未部署、未动越狱源）：
  git init + `.github/workflows/build.yml`（照分屏改，artifact 名 `com.guhailong.kuaishou_1.0.0_iphoneos-arm64`）
  + `.gitignore`（排除 `packages/` 里的 Linux debug .deb 与 `.theos/`）+ README 过期"只留本地"字句已改。
- 本地提交：`3d2cf2f` "v1.0.0: panel shell, macOS build"（15 文件，见 git show）；本节记录在随后提交。
- 待主聊天接手：建公开空仓库 `guhailon/guhailong-kuaishou` → 按 push 规则用 gh_push.py 推送 → 跑 Actions
  → 下载验包（Version 1.0.0、universal arm64+arm64e、__cfstring 0、禁 API 0）→ 验过后部署上越狱源。

## v1.0.1 关于页加 QQ 群（2026-11-15）

- 起因：v1.0.0 已上源（源 v98）。Lee 真机测关于页照片确认面板正常跑、Filter `com.jiangjia.gif` 是对的，
  但关于页只有 QQ 号 2309103548，没有 QQ 群行。Lee 2026-11-15 12:26 批：加上，跟抖音一样（QQ群 1130823454＋金色加群按钮）。
- 改了什么（只动关于页，其余不动）：
  - `GHLKS.h`：版本号 1.0.0 → 1.0.1；新增 `kGHLKSQQGroupNumber = "1130823454"` 与
    `kGHLKSQQGroupJoinURL`（加群邀请链接照抖音的 `GHL_QQ_GROUP_JOIN_URL` 抄，与抖音同群，只留这一份）。
  - `GHLKSPanel.m` 关于页：QQ 行下面加 QQ 群行「QQ群：1130823454（点按复制）」（tag 4509/4510），
    点按复制群号并弹「已复制群号」；再加金色「加入QQ群」大按钮（tag 4511，用共用的金底钮样式），
    点按 `openURL` 打开邀请链接，打不开弹「打开失败，请检查网络后重试」（completion 可能不在主线程，提示走主线程）。
  - 日志字串前缀 `v1.0.0` → `v1.0.1`（`GHLKSPanel.m`、`GHLKSProbe.m`、`Tweak.xm` 全量替换）；
    关于页描述文案同步改成 1.0.1 并写明新增了 QQ 群行与加群按钮。
  - `control`：Version 1.0.1，Description 同步改；`README.md` 加 v1.0.1 一节。
- 零字面量：新代码的全部字串走 C 字串 + `GHLKSStr`（照 QQ 号行的写法），源码 `@"` 仍为 0 个。
- 诚实状态：QQ 群行与加群按钮只在本地冒烟验过，未真机验过——点按复制、打开邀请链接进群，都要真机看。
  （加群链接与抖音是同一条，抖音那边 1.0.4 起就在用，链接本身是经过真机的。）

## 验证（Linux 冒烟，/tmp/ghlks101，包验完已留 staging、/tmp 已清）

- `.deb`：`packages/com.guhailong.kuaishou_1.0.1-1+debug_iphoneos-arm64.deb`，
  **99,774 B，SHA256 `37a81521e98fcf5ac83cdd10b26c57e339ba1fe6530a3e53a50b5cf0ab2cc580`**，
  control：Package `com.guhailong.kuaishou`、Version `1.0.1-1+debug`（+debug 是 Linux 冒烟版的后缀，macOS 发布包才是 1.0.1）、
  Architecture `iphoneos-arm64`、Depends `firmware (>= 15.0), mobilesubstrate`。
  旧 1.0.0 冒烟包（97,730 B，SHA256 `c271ef7e…`）仍在 `packages/` 里，未动。
- 内容：dylib 388,688 B（比 1.0.0 的 370,656 B 大，新增的群行与按钮代码在内）、
  Filter plist 52 B（`com.jiangjia.gif`）、龙头图 29,706 B。
- dylib：universal arm64 + arm64e（Linux 编的 arm64e 切片照例无 PAC00，macOS 编才有——冒烟只验语法）。
- `__cfstring`：**0 / 0**（两片皆无此 section，python 解析 Mach-O load commands 验过）。
- 禁 API 全 0（两片）：`CFNotificationCenterAddObserver`、`LSApplicationWorkspace`、
  `dispatch_get_global_queue`、`keyWindow`、`NSUUID`、`uuid_generate`、`uuid_unparse`。
- 中文字串 UTF-8 计数（两片一致，×2 即双切片合计）：「1.0.1」×30（双切片合计，单片 ×15）、
  「1.0.0」×0（代码层已归零，BUILD_LOG/README 历史记录除外）；「1130823454」×4（常量 + 群行标签，双切片）、
  「qun.qq.com」×2（加群链接，双切片）、「加入QQ群」×2、「已复制群号」×2、「QQ群」×4（群行标签 + 按钮标题）、
  「2309103548」×4、「顾海龙快手」×6、「GUHAILONG KUAISHOU」×2、「v1.0.1 loaded」×2、
  「panel opened」×2、「bottom probe」×8、「feed probe」×8、「14.10.10」×4、
  「com.guhailong.kuaishou」×2、「GuHaiLongKuaishou.log」×2、「dragon-head.jpg」×4、
  「已复制 QQ 号」×2、「打开失败，请检查网络后重试」×2。
- 源码层：`@"` 0 个（全部 7 个源码文件）；禁 API 字串 0 处；`1.0.0` 只剩主聊天验包留下的
  `build-1.0.0/verify/control`（未跟踪目录，已由 `.gitignore` 的 `build-*/` 排除，不进仓库）。

## 换图：龙头图 → 哆啦A梦图（v1.0.1 未推之前，Lee 2026-11-15 12:30 定）

- `layout/Library/Application Support/GuHaiLongKuaishou/dragon-head.jpg` 已删，
  `doraemon-button@3x.png`（分屏插件同款，168×168 PNG，44,177 B）复制为
  `layout/Library/Application Support/GuHaiLongKuaishou/doraemon.png`。
- helper 改名 `GHLKSDragonImagePath` → `GHLKSLogoImagePath`（`GHLKS.h` 声明 + 注释、`GHLKS.m` 定义、
  `GHLKSPanel.m` 三处调用同步改；路径仍走 C 字串，两个候选路径都改成 `doraemon.png`）。
  悬浮钮、卡片头、关于页三处共用这张图，裁剪方式不变（ScaleAspectFill + 圆角）。
- README 与本文件现状描述同步改成哆啦A梦图；v1.0.0 验包小节里的旧数字是历史记录（那时的包确实装的是龙头图），未改。
- 零字面量：源码 `@"` 仍为 0 个。

## 换图后重验（Linux 冒烟，/tmp/ghlks101，包验完已留 staging、/tmp 已清）

- `.deb`：`packages/com.guhailong.kuaishou_1.0.1-1+debug_iphoneos-arm64.deb`，
  **114,456 B，SHA256 `ab6ff1d4836474029d81180f1675943aa9d191a56a5691f50345d721f5610a1e`**，
  control Version `1.0.1-1+debug`，Package `com.guhailong.kuaishou`，Architecture `iphoneos-arm64`，
  Depends `firmware (>= 15.0), mobilesubstrate`。一次编过，只有已知的 arm64e ABI 警告。
  旧 cbed577 冒烟包（99,774 B）已被新包覆盖（packages/ 不进仓库，旧包可随时从提交重编）。
- 内容：dylib 372,160 B、Filter plist 52 B（`com.jiangjia.gif`）、`doraemon.png` 44,177 B；
  包里没有 `dragon-head.jpg`。
- dylib：universal arm64（cpusubtype 0）+ arm64e（cpusubtype 2）；`__cfstring` **0 / 0**；
  禁 API 全 0（两片）。
- 字串计数（每片）：「1.0.1」×15、「1.0.0」×0、「doraemon.png」×2、「dragon-head」×0、
  「1130823454」×2、「qun.qq.com」×1、「加入QQ群」×1、「GuHaiLongKuaishou.log」×1、
  「com.guhailong.kuaishou」×1、「14.10.10」×2。
- 说明：cbed577 报告里写的 dylib 388,688 B 与本次重编的 372,160 B 对不上（包大小变化与换图完全吻合：
  99,774 − 29,706 + 44,177 ≈ 114,456），字串计数全部对得上，应为上次量法不同；旧包已被覆盖，无法复核，记一笔。
- 诚实状态：换图只在本地冒烟验过，未真机验过——悬浮钮、卡片头、关于页三处是不是都显示哆啦A梦，要真机看。
