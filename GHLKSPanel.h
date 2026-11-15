// GHLKSPanel.h — 悬浮入口钮 + 深色毛玻璃设置卡片（菜单、规划页、诊断页、日志页、关于页）。
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

#ifdef __cplusplus
extern "C" {
#endif

// 建悬浮钮窗口（%ctor 里调一次；位置从设置里恢复）。
void GHLKSInstallFloatingButton(void);

// 打开 / 关闭设置卡片（打开时悬浮钮先藏起来，关闭时再出现；打开次数会记数）。
void GHLKSShowPanel(void);
void GHLKSHidePanel(void);
BOOL GHLKSPanelIsOpen(void);

#ifdef __cplusplus
}
#endif
