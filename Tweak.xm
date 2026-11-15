// Tweak.xm — 顾海龙快手 v1.0.0 入口。
// 本版没有 Hook（面板外壳 + 两个探针都是纯 UIKit + 定时器），
// %ctor 只做：延后建悬浮钮、恢复探针开关、注册回前台通知。
#import "GHLKS.h"
#import "GHLKSProbe.h"
#import "GHLKSPanel.h"

static id GHLKSActiveObserver = nil;

%ctor {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        GHLKSLog("v1.0.0 loaded, target kuaishou %s build %s", kGHLKSTargetKuaishouVersion, kGHLKSTargetKuaishouBuild);
        GHLKSInstallFloatingButton();
        // 恢复上次的探针开关。
        if (GHLKSPrefsBool("bottomBarProbeEnabled", NO)) {
            [[GHLKSProbe sharedProbe] setBottomBarProbeEnabled:YES];
        }
        if (GHLKSPrefsBool("feedProbeEnabled", NO)) {
            [[GHLKSProbe sharedProbe] setFeedProbeEnabled:YES];
        }
        // 回前台时探针开着就立刻跑一次（底栏常被切回来后重绘）。
        if (!GHLKSActiveObserver) {
            GHLKSActiveObserver = [[NSNotificationCenter defaultCenter]
                addObserverForName:GHLKSStr("UIApplicationDidBecomeActiveNotification")
                object:nil
                queue:[NSOperationQueue mainQueue]
                usingBlock:^(NSNotification *note) {
                    if ([[GHLKSProbe sharedProbe] bottomBarProbeEnabled]) {
                        [[GHLKSProbe sharedProbe] runBottomBarProbeOnce];
                    }
                    if ([[GHLKSProbe sharedProbe] feedProbeEnabled]) {
                        [[GHLKSProbe sharedProbe] runFeedProbeOnce];
                    }
                }];
        }
    });
}
