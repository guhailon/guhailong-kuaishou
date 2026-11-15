# 顾海龙快手 — GuHaiLongKuaishou
# 原创 Theos 插件工程。目标机型：iPhone 11 / iOS 16.5 / Dopamine (rootless)。
# 目标快手版本：14.10.10 / build 10089（Lee 2026-11-15 确认）。
# 构建：macOS + Xcode + Theos，或 GitHub Actions（做法照抄分屏的 build.yml，
# gmake package FINALPACKAGE=1 THEOS_PACKAGE_SCHEME=rootless STRIP=0）。
# 本地 Linux 构建见 BUILD_LOG.md（冒烟用，产物必删）。
# 零字面量规则：源码里不写任何 ObjC 字串字面量，所有字串运行时由 C 字串拼出，
# dylib 的 __cfstring 必须为 0（分屏插件同一条规矩）。
ARCHS = arm64 arm64e
TARGET := iphone:clang:16.5:15.0

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = GuHaiLongKuaishou

GuHaiLongKuaishou_FILES = Tweak.xm GHLKS.m GHLKSProbe.m GHLKSPanel.m
GuHaiLongKuaishou_CFLAGS = -fobjc-arc -w
GuHaiLongKuaishou_FRAMEWORKS = UIKit Foundation CoreGraphics

include $(THEOS_MAKE_PATH)/tweak.mk
