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
| 1 | 深色毛玻璃设置卡片（龙头图 + 金字「顾海龙快手」+ 英文小字，两列菜单，金底完成钮） | 做成（纯 UIKit） |
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
- 龙头图：`layout/Library/Application Support/GuHaiLongKuaishou/dragon-head.jpg`（256px，29,706 B，由官网龙头裁图缩来；未复制参考插件的书法图）。
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
