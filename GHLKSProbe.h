// GHLKSProbe.h — 两个探针：底栏透明（试验）、精选探针日志。
// 全部用通用 UIKit 遍历，不用任何快手类名（公开渠道查不到，不编造）。
// 探针只读 / 只改自家开关控制的范围，不动 feed 数据。
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@interface GHLKSProbe : NSObject

+ (instancetype)sharedProbe;

// 底栏透明（试验）开关：开 = 每 2 秒跑一次遍历 + 尝试透明 + 2.5 秒后复查是否还在；
// 关 = 还原改过的视图并停掉定时器。
- (void)setBottomBarProbeEnabled:(BOOL)enabled;
- (BOOL)bottomBarProbeEnabled;

// 精选探针日志开关：开 = 每 3 秒扫一次可见 cell，只记类名与模型属性名，不改 feed。
- (void)setFeedProbeEnabled:(BOOL)enabled;
- (BOOL)feedProbeEnabled;

// 前台回来时由 %ctor 的通知触发：探针开着就立刻跑一次。
- (void)runBottomBarProbeOnce;
- (void)runFeedProbeOnce;

// 诊断页用的状态字串（运行时拼出），如 bottom:1 enabled:1 nodes:3 sticks:yes。
- (NSString *)bottomBarProbeStatus;
- (NSString *)feedProbeStatus;

@end
