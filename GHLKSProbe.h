// GHLKSProbe.h — 探针：底栏透明（试验）、精选探针日志，v1.0.2 再加 7 个探针。
// 全部用通用 UIKit 遍历，不用任何快手类名（公开渠道查不到，不编造）。
// 探针只读 / 只改自家开关控制的范围，不动 feed 数据、不发消息、不改行为。
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@interface GHLKSProbe : NSObject

+ (instancetype)sharedProbe;

// App 主窗口：normal 层级、可见、有尺寸的最后一个 window。
// 不用已废弃的旧读法（分屏插件同款禁项），多场景也稳。
+ (UIWindow *)mainAppWindow;

// 按设置里的开关统一开／关全部探针（%ctor 恢复、配置导入后都用它）。
- (void)syncProbeStatesFromPrefs;
// 开着的探针各跑一次（回前台时用）。
- (void)runEnabledProbesOnce;

// 底栏透明（试验）开关：开 = 每 2 秒跑一次遍历 + 尝试透明 + 2.5 秒后复查是否还在；
// 关 = 还原改过的视图并停掉定时器。
- (void)setBottomBarProbeEnabled:(BOOL)enabled;
- (BOOL)bottomBarProbeEnabled;

// 精选探针日志开关：开 = 每 3 秒扫一次可见 cell，只记类名与模型属性名，不改 feed。
- (void)setFeedProbeEnabled:(BOOL)enabled;
- (BOOL)feedProbeEnabled;

// 顶栏探针（#5）：每 3 秒找顶栏候选（类名含 Top / Segment / Tab 或分段控件／导航栏），
// 只记类名与子按钮标题。
- (void)setTopBarProbeEnabled:(BOOL)enabled;
- (BOOL)topBarProbeEnabled;

// 底栏项探针（#6）：每 3 秒找 UITabBar 及其 item 标题 + 贴底自定义容器的按钮标题。
- (void)setTabBarProbeEnabled:(BOOL)enabled;
- (BOOL)tabBarProbeEnabled;

// AD 章节探针（#11）：每 3 秒扫可见 cell 的模型属性名，挑出含章节／广告／跳过字样的字段；
// 只记字段名，绝不跳过。
- (void)setAdChapterProbeEnabled:(BOOL)enabled;
- (BOOL)adChapterProbeEnabled;

// 续火花探针（#16）：每 3 秒找头像候选与输入框候选，只记数量与类名，绝不真发消息。
- (void)setSparkProbeEnabled:(BOOL)enabled;
- (BOOL)sparkProbeEnabled;

// 头像探针（#18）：每 3 秒找方形头像图候选，只记位置与图尺寸。
- (void)setAvatarProbeEnabled:(BOOL)enabled;
- (BOOL)avatarProbeEnabled;

// 自动连播探针（#27）：每 3 秒找播放器类视图与进度条，只记类名与进度值。
- (void)setAutoPlayProbeEnabled:(BOOL)enabled;
- (BOOL)autoPlayProbeEnabled;

// 格子 ivar 探针（#30）：每 3 秒扒可见 cell 自己的 ivar／属性名，只记名字与类型，
// 不记内容；是精选纯净下一步最现实的路。
- (void)setIvarProbeEnabled:(BOOL)enabled;
- (BOOL)ivarProbeEnabled;

// 前台回来时由 %ctor 的通知触发：探针开着就立刻跑一次。
- (void)runBottomBarProbeOnce;
- (void)runFeedProbeOnce;
- (void)runTopBarProbeOnce;
- (void)runTabBarProbeOnce;
- (void)runAdChapterProbeOnce;
- (void)runSparkProbeOnce;
- (void)runAvatarProbeOnce;
- (void)runAutoPlayProbeOnce;
- (void)runIvarProbeOnce;

// 诊断页用的状态字串（运行时拼出），如 bottom:1 enabled:1 nodes:3 sticks:yes。
- (NSString *)bottomBarProbeStatus;
- (NSString *)feedProbeStatus;
- (NSString *)topBarProbeStatus;
- (NSString *)tabBarProbeStatus;
- (NSString *)adChapterProbeStatus;
- (NSString *)sparkProbeStatus;
- (NSString *)avatarProbeStatus;
- (NSString *)autoPlayProbeStatus;
- (NSString *)ivarProbeStatus;

@end
