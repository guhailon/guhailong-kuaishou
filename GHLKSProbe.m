// GHLKSProbe.m — 底栏透明（试验）与精选探针日志。
// 全部通用 UIKit 遍历；不用任何快手类名；不改 feed 数据。
#import "GHLKSProbe.h"
#import "GHLKS.h"
#import <objc/runtime.h>

@interface GHLKSProbe ()
@property (nonatomic, strong) NSTimer *bottomBarTimer;
@property (nonatomic, strong) NSTimer *feedTimer;
@property (nonatomic, strong) NSMutableArray *modifiedViews; // NSValue(nonretainedObject) + 原 backgroundColor
@property (nonatomic, strong) NSMutableArray *modifiedEffectViews; // 被藏起来的 UIVisualEffectView
@property (nonatomic, strong) NSMutableArray *modifiedTabBars; // 被改过的 UITabBar
@property (nonatomic, assign) long bottomBarNodes;
@property (nonatomic, assign) BOOL bottomBarApplied;
@property (nonatomic, assign) BOOL bottomBarSticks;
@property (nonatomic, assign) long feedScans;
@property (nonatomic, assign) long feedCells;
@property (nonatomic, strong) NSString *lastFeedSignature;
@end

@implementation GHLKSProbe

+ (instancetype)sharedProbe {
    static GHLKSProbe *shared = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        shared = [[GHLKSProbe alloc] init];
        shared.modifiedViews = [NSMutableArray array];
        shared.modifiedEffectViews = [NSMutableArray array];
        shared.modifiedTabBars = [NSMutableArray array];
    });
    return shared;
}

// App 主窗口：normal 层级、可见、有尺寸的最后一个 window。
// 不用已废弃的旧读法（分屏插件同款禁项），多场景也稳。
+ (UIWindow *)mainAppWindow {
    NSArray *windows = [[UIApplication sharedApplication] windows];
    UIWindow *fallback = nil;
    for (UIWindow *w in windows) {
        if (w.hidden) continue;
        if (CGRectIsEmpty(w.bounds)) continue;
        if (w.windowLevel == UIWindowLevelNormal) fallback = w;
    }
    if (fallback) return fallback;
    for (UIWindow *w in windows) {
        if (!w.hidden && !CGRectIsEmpty(w.bounds)) return w;
    }
    return nil;
}

+ (void)collectSubviewsOf:(UIView *)view into:(NSMutableArray *)out {
    if (!view) return;
    [out addObject:view];
    for (UIView *sub in view.subviews) {
        [GHLKSProbe collectSubviewsOf:sub into:out];
    }
}

#pragma mark - 底栏透明（试验）

- (void)setBottomBarProbeEnabled:(BOOL)enabled {
    if (enabled) {
        [self runBottomBarProbeOnce];
        if (!self.bottomBarTimer) {
            self.bottomBarTimer = [NSTimer scheduledTimerWithTimeInterval:2.0
                                                                   target:self
                                                                 selector:@selector(bottomBarTimerFired)
                                                                 userInfo:nil
                                                                  repeats:YES];
        }
    } else {
        [self.bottomBarTimer invalidate];
        self.bottomBarTimer = nil;
        [self restoreBottomBar];
    }
}

- (BOOL)bottomBarProbeEnabled {
    return self.bottomBarTimer != nil;
}

- (void)bottomBarTimerFired {
    [self runBottomBarProbeOnce];
}

- (void)runBottomBarProbeOnce {
    UIWindow *win = [GHLKSProbe mainAppWindow];
    if (!win) return;
    CGFloat screenW = CGRectGetWidth([UIScreen mainScreen].bounds);
    CGFloat screenH = CGRectGetHeight([UIScreen mainScreen].bounds);
    NSMutableArray *all = [NSMutableArray array];
    [GHLKSProbe collectSubviewsOf:win into:all];
    long found = 0;
    for (UIView *v in all) {
        CGRect f = [v convertRect:v.bounds toView:nil];
        if (CGRectIsEmpty(f)) continue;
        BOOL nearBottom = CGRectGetMaxY(f) >= screenH - 120.0;
        BOOL barHeight = CGRectGetHeight(f) >= 40.0 && CGRectGetHeight(f) <= 110.0;
        BOOL fullWidth = CGRectGetWidth(f) >= screenW * 0.8;
        BOOL isTabBar = [v isKindOfClass:[UITabBar class]];
        if (!nearBottom) continue;
        if (!isTabBar && !(barHeight && fullWidth)) continue;
        found++;
        if (isTabBar) {
            [self applyTransparentToTabBar:(UITabBar *)v];
        } else {
            [self applyTransparentToContainer:v];
        }
    }
    self.bottomBarNodes = found;
    if (found > 0) self.bottomBarApplied = YES;
    GHLKSLog("v1.0.0 bottom probe: nodes=%ld applied=%d", found, self.bottomBarApplied ? 1 : 0);
    // 2.5 秒后复查：改动还在不在。
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self recheckBottomBar];
    });
}

- (void)applyTransparentToTabBar:(UITabBar *)bar {
    if ([self.modifiedTabBars containsObject:bar]) return;
    [self.modifiedTabBars addObject:bar];
    bar.translucent = YES;
    bar.backgroundColor = [UIColor clearColor];
    bar.barTintColor = [UIColor clearColor];
    bar.backgroundImage = [UIImage new];
    bar.shadowImage = [UIImage new];
}

- (void)applyTransparentToContainer:(UIView *)v {
    for (NSValue *nv in self.modifiedViews) {
        if ([nv nonretainedObjectValue] == v) return;
    }
    NSDictionary *record = [NSDictionary dictionaryWithObjectsAndKeys:
        [NSValue valueWithNonretainedObject:v], GHLKSStr("view"),
        v.backgroundColor ? v.backgroundColor : [UIColor clearColor], GHLKSStr("bg"),
        nil];
    [self.modifiedViews addObject:record];
    v.backgroundColor = [UIColor clearColor];
    // 直接子视图里的毛玻璃背景层藏起来（图标一般是兄弟视图，不受影响）。
    for (UIView *sub in v.subviews) {
        if ([sub isKindOfClass:[UIVisualEffectView class]] && !sub.hidden) {
            [self.modifiedEffectViews addObject:[NSValue valueWithNonretainedObject:sub]];
            sub.hidden = YES;
        }
    }
}

- (void)recheckBottomBar {
    if (!self.bottomBarApplied) return;
    long alive = 0;
    long total = 0;
    for (NSValue *nv in self.modifiedViews) {
        UIView *v = [nv nonretainedObjectValue];
        if (!v || !v.window) continue;
        total++;
        if ([v.backgroundColor isEqual:[UIColor clearColor]]) alive++;
    }
    for (UITabBar *bar in self.modifiedTabBars) {
        if (!bar.window) continue;
        total++;
        if ([bar.backgroundColor isEqual:[UIColor clearColor]]) alive++;
    }
    self.bottomBarSticks = (total > 0 && alive == total);
    GHLKSLog("v1.0.0 bottom probe recheck: alive=%ld total=%ld sticks=%d", alive, total, self.bottomBarSticks ? 1 : 0);
}

- (void)restoreBottomBar {
    for (NSDictionary *record in self.modifiedViews) {
        UIView *v = [[record objectForKey:GHLKSStr("view")] nonretainedObjectValue];
        UIColor *bg = [record objectForKey:GHLKSStr("bg")];
        if (v && v.window && bg) v.backgroundColor = bg;
    }
    [self.modifiedViews removeAllObjects];
    for (NSValue *nv in self.modifiedEffectViews) {
        UIView *v = [nv nonretainedObjectValue];
        if (v && v.window) v.hidden = NO;
    }
    [self.modifiedEffectViews removeAllObjects];
    for (UITabBar *bar in self.modifiedTabBars) {
        if (!bar.window) continue;
        bar.backgroundImage = nil;
        bar.shadowImage = nil;
        bar.barTintColor = nil;
        bar.backgroundColor = nil;
    }
    [self.modifiedTabBars removeAllObjects];
    self.bottomBarApplied = NO;
    self.bottomBarSticks = NO;
    self.bottomBarNodes = 0;
    GHLKSLog("v1.0.0 bottom probe restored");
}

- (NSString *)bottomBarProbeStatus {
    char buf[160];
    snprintf(buf, sizeof(buf), "nodes:%ld enabled:%d sticks:%s",
             (long)self.bottomBarNodes,
             self.bottomBarTimer ? 1 : 0,
             self.bottomBarSticks ? "yes" : "no");
    return GHLKSStr(buf);
}

#pragma mark - 精选探针日志（只读，不改 feed）

- (void)setFeedProbeEnabled:(BOOL)enabled {
    if (enabled) {
        [self runFeedProbeOnce];
        if (!self.feedTimer) {
            self.feedTimer = [NSTimer scheduledTimerWithTimeInterval:3.0
                                                              target:self
                                                            selector:@selector(feedTimerFired)
                                                            userInfo:nil
                                                             repeats:YES];
        }
    } else {
        [self.feedTimer invalidate];
        self.feedTimer = nil;
    }
}

- (BOOL)feedProbeEnabled {
    return self.feedTimer != nil;
}

- (void)feedTimerFired {
    [self runFeedProbeOnce];
}

- (void)runFeedProbeOnce {
    UIWindow *win = [GHLKSProbe mainAppWindow];
    if (!win) return;
    NSMutableArray *all = [NSMutableArray array];
    [GHLKSProbe collectSubviewsOf:win into:all];
    NSMutableArray *signatures = [NSMutableArray array];
    NSMutableString *log = [NSMutableString string];
    long cellCount = 0;
    for (UIView *v in all) {
        NSArray *cells = nil;
        if ([v isKindOfClass:[UITableView class]]) {
            cells = [(UITableView *)v visibleCells];
        } else if ([v isKindOfClass:[UICollectionView class]]) {
            cells = [(UICollectionView *)v visibleCells];
        } else {
            continue;
        }
        if (!cells || [cells count] == 0) continue;
        [signatures addObject:NSStringFromClass([v class])];
        for (UITableViewCell *cell in cells) {
            if (cellCount >= 12) break;
            cellCount++;
            NSString *cellClass = NSStringFromClass([cell class]);
            [signatures addObject:cellClass];
            [log appendFormat:GHLKSStr("cell %ld: %s"), (long)cellCount, [cellClass UTF8String]];
            // 通用键读模型对象（未知键会抛异常，必须包住）；只记对象类名与属性名，不记内容。
            static const char *modelKeys[] = { "model", "data", "item", "viewModel", "feedModel", NULL };
            for (int k = 0; modelKeys[k]; k++) {
                id model = nil;
                @try {
                    model = [cell valueForKey:GHLKSStr(modelKeys[k])];
                } @catch (NSException *e) {
                    model = nil;
                }
                if (!model || model == (id)[NSNull null]) continue;
                NSString *modelClass = NSStringFromClass([model class]);
                [signatures addObject:modelClass];
                [log appendFormat:GHLKSStr(" | %s=%s"), modelKeys[k], [modelClass UTF8String]];
                unsigned int propCount = 0;
                objc_property_t *props = class_copyPropertyList([model class], &propCount);
                if (props) {
                    NSMutableString *names = [NSMutableString string];
                    unsigned int shown = propCount > 40 ? 40 : propCount;
                    for (unsigned int i = 0; i < shown; i++) {
                        const char *name = property_getName(props[i]);
                        if (i > 0) [names appendString:GHLKSStr(", ")];
                        [names appendString:GHLKSStr(name)];
                    }
                    free(props);
                    [log appendFormat:GHLKSStr(" props[%u]: %s"), propCount, [names UTF8String]];
                }
                break; // 一个 cell 只取第一个读得到的模型键
            }
            [log appendString:GHLKSStr("\n")];
        }
    }
    self.feedScans++;
    self.feedCells = cellCount;
    NSString *sig = [signatures componentsJoinedByString:GHLKSStr(",")];
    if ([sig isEqualToString:self.lastFeedSignature]) return; // 没变就不刷日志
    self.lastFeedSignature = sig;
    if (cellCount == 0) {
        GHLKSLog("v1.0.0 feed probe scan %ld: no visible cells", self.feedScans);
        return;
    }
    GHLKSLog("v1.0.0 feed probe scan %ld: cells=%ld\n%s", self.feedScans, cellCount, [log UTF8String]);
}

- (NSString *)feedProbeStatus {
    char buf[160];
    snprintf(buf, sizeof(buf), "feed probe enabled:%d scans:%ld cells:%ld",
             self.feedTimer ? 1 : 0, self.feedScans, self.feedCells);
    return GHLKSStr(buf);
}

@end
