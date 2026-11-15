// Tweak.xm — 顾海龙快手 v1.0.2 入口。
// 本版没有 Hook（面板外壳 + 探针都是纯 UIKit + 定时器），
// %ctor 只做：延后建悬浮钮、恢复探针开关、注册回前台通知。
#import "GHLKS.h"
#import "GHLKSProbe.h"
#import "GHLKSPanel.h"

static id GHLKSActiveObserver = nil;

%ctor {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        GHLKSLog("v1.0.2 loaded, target kuaishou %s build %s", kGHLKSTargetKuaishouVersion, kGHLKSTargetKuaishouBuild);
        GHLKSInstallFloatingButton();
        // 恢复上次的探针开关（全部探针统一同步）。
        [[GHLKSProbe sharedProbe] syncProbeStatesFromPrefs];
        // 长按面板：开关默认开。
        if (GHLKSPrefsBool("longPressPanelEnabled", YES)) {
            GHLKSInstallLongPressPanel();
        }
        // 回前台时探针开着就立刻跑一次（底栏常被切回来后重绘），
        // 长按面板没装上也补装一次（快手换了主窗口时）。
        if (!GHLKSActiveObserver) {
            GHLKSActiveObserver = [[NSNotificationCenter defaultCenter]
                addObserverForName:GHLKSStr("UIApplicationDidBecomeActiveNotification")
                object:nil
                queue:[NSOperationQueue mainQueue]
                usingBlock:^(NSNotification *note) {
                    [[GHLKSProbe sharedProbe] runEnabledProbesOnce];
                    if (GHLKSPrefsBool("longPressPanelEnabled", YES)) {
                        GHLKSInstallLongPressPanel();
                    }
                }];
        }
    });
}
