# 顾海龙快手 — GuHaiLongKuaishou

**开源：源码就在这个仓库里，免费使用，仅限学习交流。**

原创 Theos 插件工程。目标机：iPhone 11 / iOS 16.5 / Dopamine (rootless)。
目标快手版本：**14.10.10 / build 10089**（Lee 2026-11-15 确认）。

## 版本

- **v1.0.0（面板外壳版）**：深色毛玻璃设置卡片、悬浮入口钮、
  诊断反馈、关于页；8–12 号菜单入口只有「规划」空页；底栏透明是探针（试验开关）、
  精选纯净只有探针日志。详见 BUILD_LOG.md 与
  `~/workspace/user/files/kuaishou-feasibility.md`。
- **v1.0.1**：关于页新增 QQ 群行（QQ群 1130823454，点按复制）与金色
  「加入QQ群」大按钮（照抖音的做法，加群链接与抖音同群）；头像换成哆啦A梦，
  通用设置可从相册任意换头像（默认哆啦A梦，可恢复默认）；日志页复制日志隔壁
  加分享日志（系统分享发日志文件）。其余与 1.0.0 相同。
- **v1.0.2**：批一 11 项——通用设置加配置导入／导出／恢复默认；导航入口、
  首页、精选、消息、我、播放互动六个格子做实（长按面板外壳 + 顶栏、底栏项、
  AD 章节、续火花、头像、自动连播 6 个新探针，诊断页加格子 ivar 探针；底栏透明
  与精选纯净确认在位，不重复造开关）；底栏透明探针闪退已修（NSDictionary 当
  NSValue 用的类型混淆 + 野指针 + recheck 堆积）；关于页去掉金色加入 QQ 群
  大按钮，只留 QQ 群号一行。详见 BUILD_LOG.md。

## 工程

- `Tweak.xm` — 入口（%ctor，无 Hook）：延后建悬浮钮、恢复探针开关、回前台重跑探针。
- `GHLKS.h/.m` — 字串、日志（Documents/GuHaiLongKuaishou.log）、
  设置（CFPreferences 域 com.guhailong.kuaishou）、路径。
- `GHLKSProbe.h/.m` — 底栏透明探针（通用 UIKit 遍历）+ 精选探针日志（只记类名与模型属性名）。
- `GHLKSPanel.h/.m` — 悬浮钮 + 设置卡片（菜单、规划页、诊断页、日志页、关于页）。
- `layout/` — 哆啦A梦图（分屏插件同款 `doraemon-button@3x.png`，168×168 PNG），
  装到 `/var/jb/Library/Application Support/GuHaiLongKuaishou/doraemon.png`。
- `GuHaiLongKuaishou.plist` — Filter：`com.jiangjia.gif`（公开资料值，上真机前须用 Filza 核对）。

## 规则

- 原创代码；不复制、不反编译、不分发任何闭源插件（人民的快手／快手图层只学了影片里看得见的 UI 样子）。
- 零字面量：源码里不写 ObjC 字串字面量，dylib 的 `__cfstring` 必须为 0。
- 本版已改：Lee 2026-11-15 10:58 定只留本地（不推、不部署、不上源），11:59 改批建公开仓库 + macOS 编真机包，随后又改口编好验过后上越狱源（见 BUILD_LOG.md 末节）。

## 构建（冒烟，Linux）

```sh
cp -a <staging> /tmp/ghlks100 && cd /tmp/ghlks100
chmod -R 0755 . && chmod -R g-s .
umask 022; THEOS=~/theos TARGET=iphone:clang:16.5:15.0 make package
```

冒烟包验完后复制一份到 staging 的 `packages/` 留存，/tmp 里的构建目录删干净。
真机发布包走 macOS GitHub Actions（见 .github/workflows/build.yml；建库与推送由主聊天接手，见 BUILD_LOG.md 末节）。
