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

## 分享日志 + 头像任意换（v1.0.1 未推之前，Lee 2026-11-15 12:31、12:32 定）

- 分享日志：日志查看页底部由 3 个按钮改成 4 个（复制日志、分享日志、清空日志、刷新），
  点分享日志弹出系统分享（UIActivityViewController），分享日志文件
  `Documents/GuHaiLongKuaishou.log`（走已有的 `GHLKSLogFilePath()`，文件不存在弹「暂无日志」；
  照抖音导出配置的做法，iPad 时锚到当前 view）。
- 头像任意换（照抖音自选龙头的做法，只学思路不抄代码）：
  - `GHLKS.h/.m`：新增自选头像 helper——`GHLKSCustomAvatarPath()`（存
    `Documents/GuHaiLongKuaishou/custom-avatar.jpg`）、`GHLKSHasCustomAvatar()`、
    `GHLSaveCustomAvatarImage()`（居中裁正方形、长边缩到 256、JPEG 0.88 存）、
    `GHLClearCustomAvatar()`；`GHLKSLogoImagePath()` 改成先试自选头像（损坏当没有），
    再试哆啦A梦图——悬浮钮、卡片头、关于页三处共用这个 helper，换一张图三处一起变。
  - `GHLKSPanel.m`：通用设置格子不再是规划页，改成真正的 `GHLKSGeneralSettingsViewController`
   （头像预览 72×72 + 状态行「默认哆啦A梦」/「已换自选图」+「更换头像」+「恢复默认头像」+
    说明小字）；「更换头像」开相册 picker（`UIImagePickerController`，本页自己当 delegate，
    存图是 256 像素小 JPEG，主线程直接存，不开后台队列——本工程禁 `dispatch_get_global_queue`）；
    换完 / 恢复后重刷悬浮钮图（`GHLKSRefreshFloatingButtonImage()`）和本页预览，菜单页
    `viewWillAppear` 回来时也重刷卡片头图；关于页描述文案同步加上这两项。
  - 菜单分发表 case 0 改走新页，其余 7 个格子仍是规划页；版本号保持 1.0.1 不动。
- 零字面量：新代码全部字串走 C 字串 + `GHLKSStr`，源码 `@"` 仍为 0 个（全部 7 个源码文件）。
- 构建教训（2026-11-15 12:40）：工作区直接 `make package` 在签名那步失败——
  `ldid` 在工作区 btrfs 上报 `Operation not permitted`，/tmp（tmpfs）上能跑。
  改在 /tmp 拷一份工程编（`cp -a` 后 `chmod -R a-s` 去 setgid，否则 dpkg-deb 嫌
  DEBIAN 目录权限 2755），编好把 .deb 拷回 staging 的 `packages/`。以后冒烟都这么编。
  另：这次包名是 `1.0.1-2+debug`（上次是 `-1`，theos 的 debian 修订号涨了），
  control 里 Version 仍是 1.0.1 系，macOS 发布包才是 1.0.1。

## 分享日志 + 头像任意换后重验（Linux 冒烟，/tmp/ghlks101，包验完已留 staging、/tmp 已清）

- `.deb`：`packages/com.guhailong.kuaishou_1.0.1-2+debug_iphoneos-arm64.deb`，
  **125,226 B，SHA256 `ae397055f21de71e35bd66be2c6e5373c0eb37dbb9c39c3047f4f0efea0491c5`**，
  control：Package `com.guhailong.kuaishou`、Version `1.0.1-2+debug`、
  Architecture `iphoneos-arm64`、Depends `firmware (>= 15.0), mobilesubstrate`。
  旧 1.0.1 冒烟包（114,456 B，`1.0.1-1+debug`）仍在 `packages/` 里，未动；1.0.0 冒烟包也在。
- 内容：dylib 429,616 B（比换图版的 372,160 B 大，新页 + picker + 存图 helper 在内）、
  Filter plist 52 B（`com.jiangjia.gif`）、`doraemon.png` 44,177 B；包里没有 `dragon-head.jpg`。
- dylib：universal arm64（cpusubtype 0，201,584 B）+ arm64e（cpusubtype 2，200,240 B）；
  `__cfstring` **0 / 0**（python 解析 Mach-O load commands 验过）；禁 API 全 0（两片）：
  `CFNotificationCenterAddObserver`、`LSApplicationWorkspace`、`dispatch_get_global_queue`、
  `keyWindow`、`NSUUID`、`uuid_generate`、`uuid_unparse`。
- 字串计数（两片一致，每片）：「1.0.1」×17（多了 2 条新日志行）、「1.0.0」×0、
  「dragon-head」×0、「doraemon.png」×2、「1130823454」×2、「qun.qq.com」×1、
  「加入QQ群」×1；新增：「分享日志」×2、「更换头像」×1、「恢复默认头像」×2、
  「已换自选图」×1、「默认哆啦A梦」×3、「custom-avatar.jpg」×1、「头像已更换」×1、
  「已恢复默认头像」×1、「暂无日志」×1、「选图失败」×1、「保存失败，换图没成功」×1、
  「custom avatar」×2；「顾海龙快手」×3、「GUHAILONG KUAISHOU」×1、「已复制日志」×1、
  「复制日志」×2、「清空日志」×1、「通用设置」×2、「完整日志」×2、「v1.0.1 loaded」×1、
  「panel opened」×1、「GuHaiLongKuaishou.log」×1、「com.guhailong.kuaishou」×1、「14.10.10」×2。
  （中文字串用字节级计数验，`strings` 默认会把 UTF-8 多字节字元切断，数出来是 0，不可信。）
- 诚实状态：分享日志与换头像只在本地冒烟验过，未真机验过——分享面板弹不弹得出、相册选图
  存不存得进、换完三处是不是都变新图、恢复默认回不回哆啦A梦，都要真机看。

## v1.0.2 批一 11 项 + 去加群按钮 + #7 闪退修（2026-11-15）

- 版本号 1.0.1 → 1.0.2（control、kGHLKSVersion、关于页文案、全部日志前缀全量替换；
  源码里 `1.0.1` 只剩关于页注释里一句历史说明，`1.0.0` 已归零）。
- 批一是 Lee 在 30 项清单里勾中的 11 项（2、23、30 能做 + 5、6、7、11、12、16、18、27 探针）。
  六个格子页做实（通用设置已是真页）：导航入口、首页、精选、消息、我、播放互动；
  其他页面仍是规划页；只放本项的行，没多加。

### 逐项结果

| # | 功能 | 状态 |
|---|---|---|
| 2 | 配置导入／导出／恢复默认（通用设置） | 做成：`GHLKSExportConfig`（域内全部键 → Documents/GuHaiLongKuaishou-config.plist）+ 系统分享导出；`UIDocumentPickerViewController`（public.property-list）挑文件导入（只认 NSNumber 值，安全域拷贝后读）；恢复默认先弹确认，清空域里全部键并关掉所有探针，头像文件不动；导入后探针开关立即生效（`syncProbeStatesFromPrefs`），悬浮钮位置需重启快手。 |
| 23 | 长按面板外壳（播放互动） | 做成：主窗口挂 `UILongPressGestureRecognizer`（0.6 秒，`cancelsTouchesInView = NO`，与快手自己的长按手势共存；设置卡片开着、点在悬浮钮上、面板已弹出时不弹）；6 钮网格（保存视频／保存封面／保存音频／复制链接／复制文案／取消）+ 点遮罩关闭；按钮是占位，点按只记日志 `long press action ... (pending)` 并提示「待接」；播放互动页有「预览长按面板」按钮，不用真长按就能看外壳；开关默认开，关掉就摘手势；回前台时没装上就补装。 |
| 30 | 格子 ivar 探针（诊断反馈） | 做成：第 3 个诊断开关；每 3 秒扒可见 cell（前 2 个不同类）的 ivar——沿类链上溯 3 层记名字与类型编码首字（每层 cap 30），对象型 ivar 只记值的类名（cap 10），不记内容；日志行超 1500 字截断（日志缓冲 2048 上限）。 |
| 5 | 顶栏探针（导航入口） | 探针就位：每 3 秒找顶栏候选（类名含 Top / Segment / Tab，或分段控件／导航栏，贴顶 + 宽 + 高 28–64），只记类名与子按钮标题；签名没变不刷日志。 |
| 6 | 底栏项探针（导航入口） | 探针就位：每 3 秒找 UITabBar（记 item 数与标题）+ 贴底自定义容器（记按钮标题）；只记日志。 |
| 7 | 底栏透明（导航入口） | 确认在位，不重复造开关：诊断页的试验开关照旧（通用遍历找贴底容器改透明，2.5 秒后复查，关开关还原）；导航入口格子里加一行说明指向它 + 显示当前状态。另见下面闪退修。 |
| 11 | 跳过 AD 章节（首页） | 探针就位：每 3 秒扫可见 cell 的模型属性名，挑出含 chapter / section / skip / segment / advert 的字段；只记字段名，绝不跳过。 |
| 12 | 精选纯净（精选） | 确认在位，不重做：诊断页的精选探针日志照旧（每 3 秒扫可见 cell）；精选格子里加一行说明指向它 + 显示当前状态。 |
| 16 | 续火花探针（消息） | 探针就位：每 3 秒数可见 cell 里的头像候选（UIImageView 数）与全窗口输入框候选（UITextField / UITextView 数 + 类名）；只记日志，绝不真发消息。 |
| 18 | 头像探针（我） | 探针就位：每 3 秒找方形头像图候选（30–120 像素近正方形、有图），记前 5 个的位置与图尺寸；只记日志。 |
| 27 | 自动连播探针（播放互动） | 探针就位：每 3 秒找类名含 player 的视图（cap 5）与进度条（UIProgressView / UISlider，记第一个的值）；只记日志。 |

- 探针通用：开关住在各自格子；每个探针 3 秒定时器（底栏 2 秒照旧），结果写进
  GuHaiLongKuaishou.log，签名没变不重复刷；`syncProbeStatesFromPrefs`（%ctor 恢复与
  配置导入共用）与 `runEnabledProbesOnce`（回前台重跑）统一管理 9 个探针。
- 去加群按钮（Lee 2026-11-15 12:59 定）：关于页金色「加入QQ群」大按钮与点击处理已删，
  加群邀请链接常量（`kGHLKSQQGroupJoinURL`，只有按钮在用）随按钮一起删；
  QQ群 1130823454 行留着（点群号复制照旧），QQ 号行不动；布局往上收，不留空洞。
  关于页描述文案同步改成 1.0.2 内容。

### #7 闪退根因与修法（Lee 2026-11-15 13:01 报，开一次开关后每次进快手都闪）

- 根因（只读诊断定案，比野指针更严重）：`modifiedViews` 存的是 NSDictionary 记录
  （键 view → NSValue(nonretainedObject)，键 bg → 原 backgroundColor），但两处读取
  把它当 NSValue 用、直接发 `nonretainedObjectValue`——去重循环（旧 :131-132）与
  `recheckBottomBar`（旧 :153-154）。NSDictionary 没有这个方法 → 未捕获异常 →
  立即闪退。只要探针改过任何一个非 UITabBar 容器，第一次跑（第二容器命中时）就闪，
  最晚 2.5 秒后的 recheck 必闪。这个 bug 在 v1.0.0 就有，只是开关从来没开过所以没触发。
- 修法（三件一起做）：
  1. 两处读取改成按 NSDictionary 取（与 `restoreBottomBar` 原来的写法一致），现在统一
     走弱键表，不再有这层混淆。
  2. 野指针二号问题一起修：`modifiedViews` 改成弱键 NSMapTable（视图 → 原背景色，
     键释放后条目自动消失），`modifiedEffectViews` 改成弱持有 NSHashTable；
     recheck/restore 里只碰还活着的视图（快照键 + 判空），绝不发消息给野指针。
     `modifiedTabBars` 本来就是强持有，不用动。
  3. recheck 只排一个：`bottomBarRecheckPending` 标志，上一轮的还没跑完就不重复排；
     restore 时清标志，recheck 入口先清标志再判断。
- 注意：修完之前不要再开底栏透明开关——旧版（源 v99 的 1.0.1）开一次就会闪，
  而且 prefs 里 `bottomBarProbeEnabled=YES` 会一直留着，%ctor 一读到就自动开探针、
  每次进快手都闪。1.0.2 装上后第一次进快手会按旧 prefs 自动开一次探针（修好的代码），
  探针自己会跑通；若仍不放心，可先在诊断页把开关关掉再开。

### 构建教训（本次新增）

- ARC 写回参数：`UISwitch **` / `NSTimer **` 默认是 `__autoreleasing` 写回，传 ivar
  地址会报错 `passing address of non-local object to __autoreleasing parameter`。
  写回参数要声明成 `__strong`（如 `UISwitch * __strong *switchOut`）。
- 同一方法里别用同一个局部变量名声明两次（通用设置页 `resetButton` 重名报错）。

## 验证（Linux 冒烟，/tmp/ghlks102，包验完已留 staging、/tmp 已清）

- `.deb`：`packages/com.guhailong.kuaishou_1.0.2-1+debug_iphoneos-arm64.deb`，
  **170,818 B，SHA256 `436b3fe7ab4d6de43ee7af4d87168177952400972b3c463dfa677e9a3d2e459f`**，
  control：Package `com.guhailong.kuaishou`、Version `1.0.2-1+debug`（+debug 是 Linux 冒烟版的后缀，
  macOS 发布包才是 1.0.2）、Architecture `iphoneos-arm64`、Depends `firmware (>= 15.0), mobilesubstrate`。
  旧 1.0.1 冒烟包（125,226 B，`1.0.1-2+debug`）与 1.0.0 包都在 `packages/` 里，未动。
- 内容：dylib 648,512 B、Filter plist 52 B（`com.jiangjia.gif`）、`doraemon.png` 44,177 B；
  包里没有 `dragon-head.jpg`。
- dylib：universal arm64（cpusubtype 0）+ arm64e（cpusubtype 2）；`__cfstring` **0 / 0**
  （python 解析 Mach-O load commands 验过）。
- 禁 API 全 0（两片）：`CFNotificationCenterAddObserver`、`LSApplicationWorkspace`、
  `dispatch_get_global_queue`、`keyWindow`、`NSUUID`、`uuid_generate`、`uuid_unparse`。
- 字串计数（双切片合计，grep -a 字节级数；`strings` 默认会把 UTF-8 多字节字元切断，不可信）：
  「1.0.2」×92、「1.0.1」×0、「1.0.0」×0、「qun.qq.com」×0、「加入QQ群」×0；
  新增：「导出配置」×4、「导入配置」×2、「恢复默认配置」×4、「长按菜单」×2、
  「顶栏探针」×2、「底栏项探针」×2、「AD 章节探针」×2、「续火花探针」×2、
  「头像探针」×2、「自动连播探针」×2、「格子 ivar 探针」×4、「待接」×4、
  「预览长按面板」×2、「GuHaiLongKuaishou-config.plist」×2；
  探针日志字串：「ivar probe」×8、「top bar probe」×6、「tab bar probe」×6、
  「ad chapter probe」×6、「spark probe」×4、「avatar probe」×6、
  「autoplay probe」×4、「long press」×10；
  「1130823454」×4（群号行留着）、「2309103548」×4、「doraemon.png」×4、
  「custom-avatar.jpg」×2；闪退修字串：「NSMapTable」×8、「NSHashTable」×8、
  「nonretainedObject」×0（源码里只剩两句注释说明）。
- 源码层：`@"` 0 个（全部源码文件）；禁 API 字串 0 处。
- 诚实状态：11 项 + 去加群按钮 + 闪退修只在本地冒烟验过，未真机验过——
  闪退修是真机才能最终证实的（旧版一开底栏开关就闪，新版要真机开一次开关、
  进出快手几次、看日志里的 bottom probe / recheck 行）；7 个新探针要等皇上的
  真机日志才知道找不找得到东西；长按面板外壳、配置导入导出、恢复默认也要真机点一点才算数。
