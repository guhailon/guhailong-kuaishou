// GHLKSProbe.m — 底栏透明（试验）与精选探针日志。
// 全部通用 UIKit 遍历；不用任何快手类名；不改 feed 数据。
#import "GHLKSProbe.h"
#import "GHLKS.h"
#import <objc/runtime.h>

@interface GHLKSProbe ()
@property (nonatomic, strong) NSTimer *bottomBarTimer;
@property (nonatomic, strong) NSTimer *feedTimer;
@property (nonatomic, strong) NSTimer *topBarTimer;
@property (nonatomic, strong) NSTimer *tabBarTimer;
@property (nonatomic, strong) NSTimer *adChapterTimer;
@property (nonatomic, strong) NSTimer *sparkTimer;
@property (nonatomic, strong) NSTimer *avatarTimer;
@property (nonatomic, strong) NSTimer *autoPlayTimer;
@property (nonatomic, strong) NSTimer *ivarTimer;
// v1.0.2 闪退修：改过的视图绝不再存 nonretainedObject 裸指针。
// modifiedViews 是弱键 NSMapTable（视图 → 原 backgroundColor，键释放后条目自动消失），
// modifiedEffectViews 是弱持有 NSHashTable；recheck/restore 里只碰还活着的视图。
// modifiedTabBars 本来就是强持有，不用动。
@property (nonatomic, strong) NSMapTable *modifiedViews;
@property (nonatomic, strong) NSHashTable *modifiedEffectViews;
@property (nonatomic, strong) NSMutableArray *modifiedTabBars; // 被改过的 UITabBar
@property (nonatomic, assign) long bottomBarNodes;
@property (nonatomic, assign) BOOL bottomBarApplied;
@property (nonatomic, assign) BOOL bottomBarSticks;
@property (nonatomic, assign) BOOL bottomBarRecheckPending; // 复查只排一个，别越积越多
@property (nonatomic, assign) long feedScans;
@property (nonatomic, assign) long feedCells;
@property (nonatomic, strong) NSString *lastFeedSignature;
// 各探针的去重签名（键：探针名，值：上次记过的签名；没变就不刷日志）。
@property (nonatomic, strong) NSMutableDictionary *lastSignatures;
@property (nonatomic, assign) long topBarScans;
@property (nonatomic, assign) long topBarFound;
@property (nonatomic, assign) long tabBarScans;
@property (nonatomic, assign) long tabBarFound;
@property (nonatomic, assign) long adChapterScans;
@property (nonatomic, assign) long adChapterFound;
@property (nonatomic, assign) long sparkScans;
@property (nonatomic, assign) long sparkFound;
@property (nonatomic, assign) long avatarScans;
@property (nonatomic, assign) long avatarFound;
@property (nonatomic, assign) long autoPlayScans;
@property (nonatomic, assign) long autoPlayFound;
@property (nonatomic, assign) long ivarScans;
@property (nonatomic, assign) long ivarFound;
@end

@implementation GHLKSProbe

+ (instancetype)sharedProbe {
    static GHLKSProbe *shared = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        shared = [[GHLKSProbe alloc] init];
        shared.modifiedViews = [NSMapTable weakToStrongObjectsMapTable];
        shared.modifiedEffectViews = [NSHashTable weakObjectsHashTable];
        shared.modifiedTabBars = [NSMutableArray array];
        shared.lastSignatures = [NSMutableDictionary dictionary];
    });
    return shared;
}

// 探针通用小工具：3 秒定时器的开关（已开着就不重复建；关掉就停）。
// slot 必须是 __strong 写回（ivar 地址传给 __autoreleasing 写回参数会报错）。
- (void)setProbeTimer:(NSTimer * __strong *)slot enabled:(BOOL)enabled interval:(NSTimeInterval)interval block:(void (^)(void))block {
    if (enabled) {
        if (!*slot) {
            __weak GHLKSProbe *weakSelf = self;
            *slot = [NSTimer scheduledTimerWithTimeInterval:interval repeats:YES block:^(NSTimer *t) {
                __strong GHLKSProbe *strongSelf = weakSelf;
                if (strongSelf && block) block();
            }];
        }
    } else {
        [*slot invalidate];
        *slot = nil;
    }
}

// 签名变了才记日志（没变返回 NO）。
- (BOOL)signatureChanged:(NSString *)sig forKey:(const char *)key {
    NSString *k = GHLKSStr(key);
    NSString *old = [self.lastSignatures objectForKey:k];
    if ([sig isEqualToString:old]) return NO;
    [self.lastSignatures setObject:sig forKey:k];
    return YES;
}

// 按设置里的开关统一开／关全部探针（%ctor 恢复、配置导入后都用它；
// 状态没变的开关不重复调，避免没改过也记一条恢复日志）。
- (void)syncProbeStatesFromPrefs {
    if ([self bottomBarProbeEnabled] != GHLKSPrefsBool("bottomBarProbeEnabled", NO)) {
        [self setBottomBarProbeEnabled:GHLKSPrefsBool("bottomBarProbeEnabled", NO)];
    }
    if ([self feedProbeEnabled] != GHLKSPrefsBool("feedProbeEnabled", NO)) {
        [self setFeedProbeEnabled:GHLKSPrefsBool("feedProbeEnabled", NO)];
    }
    if ([self topBarProbeEnabled] != GHLKSPrefsBool("topBarProbeEnabled", NO)) {
        [self setTopBarProbeEnabled:GHLKSPrefsBool("topBarProbeEnabled", NO)];
    }
    if ([self tabBarProbeEnabled] != GHLKSPrefsBool("tabBarProbeEnabled", NO)) {
        [self setTabBarProbeEnabled:GHLKSPrefsBool("tabBarProbeEnabled", NO)];
    }
    if ([self adChapterProbeEnabled] != GHLKSPrefsBool("adChapterProbeEnabled", NO)) {
        [self setAdChapterProbeEnabled:GHLKSPrefsBool("adChapterProbeEnabled", NO)];
    }
    if ([self sparkProbeEnabled] != GHLKSPrefsBool("sparkProbeEnabled", NO)) {
        [self setSparkProbeEnabled:GHLKSPrefsBool("sparkProbeEnabled", NO)];
    }
    if ([self avatarProbeEnabled] != GHLKSPrefsBool("avatarProbeEnabled", NO)) {
        [self setAvatarProbeEnabled:GHLKSPrefsBool("avatarProbeEnabled", NO)];
    }
    if ([self autoPlayProbeEnabled] != GHLKSPrefsBool("autoPlayProbeEnabled", NO)) {
        [self setAutoPlayProbeEnabled:GHLKSPrefsBool("autoPlayProbeEnabled", NO)];
    }
    if ([self ivarProbeEnabled] != GHLKSPrefsBool("ivarProbeEnabled", NO)) {
        [self setIvarProbeEnabled:GHLKSPrefsBool("ivarProbeEnabled", NO)];
    }
}

// 开着的探针各跑一次（回前台时用）。
- (void)runEnabledProbesOnce {
    if ([self bottomBarProbeEnabled]) [self runBottomBarProbeOnce];
    if ([self feedProbeEnabled]) [self runFeedProbeOnce];
    if ([self topBarProbeEnabled]) [self runTopBarProbeOnce];
    if ([self tabBarProbeEnabled]) [self runTabBarProbeOnce];
    if ([self adChapterProbeEnabled]) [self runAdChapterProbeOnce];
    if ([self sparkProbeEnabled]) [self runSparkProbeOnce];
    if ([self avatarProbeEnabled]) [self runAvatarProbeOnce];
    if ([self autoPlayProbeEnabled]) [self runAutoPlayProbeOnce];
    if ([self ivarProbeEnabled]) [self runIvarProbeOnce];
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
    GHLKSLog("v1.0.2 bottom probe: nodes=%ld applied=%d", found, self.bottomBarApplied ? 1 : 0);
    // 2.5 秒后复查：改动还在不在。只排一个，上一轮的还没跑完就不重复排。
    if (!self.bottomBarRecheckPending) {
        self.bottomBarRecheckPending = YES;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self recheckBottomBar];
        });
    }
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
    // 弱键表里查得到就是改过（v1.0.2 修：原来这里把 NSDictionary 记录当 NSValue 用，
    // 发 nonretainedObjectValue 是未识别方法，必闪）。
    if ([self.modifiedViews objectForKey:v]) return;
    [self.modifiedViews setObject:(v.backgroundColor ? v.backgroundColor : [UIColor clearColor]) forKey:v];
    v.backgroundColor = [UIColor clearColor];
    // 直接子视图里的毛玻璃背景层藏起来（图标一般是兄弟视图，不受影响）。
    for (UIView *sub in v.subviews) {
        if ([sub isKindOfClass:[UIVisualEffectView class]] && !sub.hidden) {
            [self.modifiedEffectViews addObject:sub];
            sub.hidden = YES;
        }
    }
}

- (void)recheckBottomBar {
    self.bottomBarRecheckPending = NO;
    if (!self.bottomBarApplied) return;
    long alive = 0;
    long total = 0;
    // 弱键快照：已释放的视图自动不在里面，不会发消息给野指针。
    NSArray *views = [[self.modifiedViews keyEnumerator] allObjects];
    for (UIView *v in views) {
        UIColor *bg = [self.modifiedViews objectForKey:v];
        if (!v || !v.window || !bg) continue;
        total++;
        if ([v.backgroundColor isEqual:[UIColor clearColor]]) alive++;
    }
    for (UITabBar *bar in self.modifiedTabBars) {
        if (!bar.window) continue;
        total++;
        if ([bar.backgroundColor isEqual:[UIColor clearColor]]) alive++;
    }
    self.bottomBarSticks = (total > 0 && alive == total);
    GHLKSLog("v1.0.2 bottom probe recheck: alive=%ld total=%ld sticks=%d", alive, total, self.bottomBarSticks ? 1 : 0);
}

- (void)restoreBottomBar {
    NSArray *views = [[self.modifiedViews keyEnumerator] allObjects];
    for (UIView *v in views) {
        UIColor *bg = [self.modifiedViews objectForKey:v];
        if (v && v.window && bg) v.backgroundColor = bg;
    }
    [self.modifiedViews removeAllObjects];
    // 弱哈希表遍历只给还活着的对象，已释放的自动跳过。
    for (UIView *v in self.modifiedEffectViews) {
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
    self.bottomBarRecheckPending = NO;
    GHLKSLog("v1.0.2 bottom probe restored");
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
        GHLKSLog("v1.0.2 feed probe scan %ld: no visible cells", self.feedScans);
        return;
    }
    GHLKSLog("v1.0.2 feed probe scan %ld: cells=%ld\n%s", self.feedScans, cellCount, [log UTF8String]);
}

- (NSString *)feedProbeStatus {
    char buf[160];
    snprintf(buf, sizeof(buf), "feed probe enabled:%d scans:%ld cells:%ld",
             self.feedTimer ? 1 : 0, self.feedScans, self.feedCells);
    return GHLKSStr(buf);
}

#pragma mark - 新探针共用小工具（v1.0.2）

// 主窗口里所有可见 cell（表视图 / 集合视图）。
+ (NSArray *)visibleCellsInWindow:(UIWindow *)win {
    if (!win) return [NSArray array];
    NSMutableArray *all = [NSMutableArray array];
    [GHLKSProbe collectSubviewsOf:win into:all];
    NSMutableArray *cells = [NSMutableArray array];
    for (UIView *v in all) {
        NSArray *vc = nil;
        if ([v isKindOfClass:[UITableView class]]) vc = [(UITableView *)v visibleCells];
        else if ([v isKindOfClass:[UICollectionView class]]) vc = [(UICollectionView *)v visibleCells];
        else continue;
        if (vc) [cells addObjectsFromArray:vc];
    }
    return cells;
}

// cell 的模型对象：5 个通用键挨个试（未知键抛异常，必须包住），只取第一个读得到的。
+ (id)modelOfCell:(id)cell {
    if (!cell) return nil;
    static const char *modelKeys[] = { "model", "data", "item", "viewModel", "feedModel", NULL };
    for (int k = 0; modelKeys[k]; k++) {
        id model = nil;
        @try {
            model = [cell valueForKey:GHLKSStr(modelKeys[k])];
        } @catch (NSException *e) {
            model = nil;
        }
        if (model && model != (id)[NSNull null]) return model;
    }
    return nil;
}

#pragma mark - 顶栏探针（#5）

- (void)setTopBarProbeEnabled:(BOOL)enabled {
    if (enabled) [self runTopBarProbeOnce];
    __weak GHLKSProbe *weakSelf = self;
    [self setProbeTimer:&_topBarTimer enabled:enabled interval:3.0 block:^{
        [weakSelf runTopBarProbeOnce];
    }];
}

- (BOOL)topBarProbeEnabled {
    return _topBarTimer != nil;
}

- (void)runTopBarProbeOnce {
    UIWindow *win = [GHLKSProbe mainAppWindow];
    if (!win) return;
    CGFloat screenW = CGRectGetWidth([UIScreen mainScreen].bounds);
    NSMutableArray *all = [NSMutableArray array];
    [GHLKSProbe collectSubviewsOf:win into:all];
    NSMutableString *sig = [NSMutableString string];
    NSMutableString *log = [NSMutableString string];
    long found = 0;
    for (UIView *v in all) {
        if (found >= 3) break;
        CGRect f = [v convertRect:v.bounds toView:nil];
        if (CGRectIsEmpty(f)) continue;
        if (CGRectGetMaxY(f) > 140.0) continue;
        if (CGRectGetWidth(f) < screenW * 0.8) continue;
        CGFloat h = CGRectGetHeight(f);
        if (h < 28.0 || h > 64.0) continue;
        NSString *cls = NSStringFromClass([v class]);
        BOOL named = [cls rangeOfString:GHLKSStr("Top")].location != NSNotFound
            || [cls rangeOfString:GHLKSStr("Segment")].location != NSNotFound
            || [cls rangeOfString:GHLKSStr("Tab")].location != NSNotFound
            || [v isKindOfClass:[UISegmentedControl class]]
            || [v isKindOfClass:[UINavigationBar class]];
        if (!named) continue;
        found++;
        // 子视图里的按钮标题与标签文字（导航栏文字，不记内容）。
        NSMutableArray *subs = [NSMutableArray array];
        [GHLKSProbe collectSubviewsOf:v into:subs];
        NSMutableArray *titles = [NSMutableArray array];
        for (UIView *sub in subs) {
            if ([titles count] >= 8) break;
            if ([sub isKindOfClass:[UIButton class]]) {
                NSString *t = [(UIButton *)sub titleForState:UIControlStateNormal];
                if (t && [t length] > 0) [titles addObject:t];
            } else if ([sub isKindOfClass:[UILabel class]]) {
                NSString *t = [(UILabel *)sub text];
                if (t && [t length] > 0) [titles addObject:t];
            }
        }
        [sig appendFormat:GHLKSStr("%s|"), [cls UTF8String]];
        [log appendFormat:GHLKSStr(" [%s: %s]"), [cls UTF8String], [[titles componentsJoinedByString:GHLKSStr("/")] UTF8String]];
    }
    self.topBarScans++;
    self.topBarFound = found;
    if (![self signatureChanged:sig forKey:"topBarProbe"]) return;
    if (found == 0) {
        GHLKSLog("v1.0.2 top bar probe scan %ld: no top bar candidate", self.topBarScans);
        return;
    }
    GHLKSLog("v1.0.2 top bar probe scan %ld: candidates=%ld%s", self.topBarScans, found, [log UTF8String]);
}

- (NSString *)topBarProbeStatus {
    char buf[160];
    snprintf(buf, sizeof(buf), "top bar enabled:%d scans:%ld found:%ld",
             _topBarTimer ? 1 : 0, self.topBarScans, self.topBarFound);
    return GHLKSStr(buf);
}

#pragma mark - 底栏项探针（#6）

- (void)setTabBarProbeEnabled:(BOOL)enabled {
    if (enabled) [self runTabBarProbeOnce];
    __weak GHLKSProbe *weakSelf = self;
    [self setProbeTimer:&_tabBarTimer enabled:enabled interval:3.0 block:^{
        [weakSelf runTabBarProbeOnce];
    }];
}

- (BOOL)tabBarProbeEnabled {
    return _tabBarTimer != nil;
}

- (void)runTabBarProbeOnce {
    UIWindow *win = [GHLKSProbe mainAppWindow];
    if (!win) return;
    CGFloat screenW = CGRectGetWidth([UIScreen mainScreen].bounds);
    CGFloat screenH = CGRectGetHeight([UIScreen mainScreen].bounds);
    NSMutableArray *all = [NSMutableArray array];
    [GHLKSProbe collectSubviewsOf:win into:all];
    NSMutableString *sig = [NSMutableString string];
    NSMutableString *log = [NSMutableString string];
    long tabBars = 0;
    long customBars = 0;
    for (UIView *v in all) {
        if ([v isKindOfClass:[UITabBar class]]) {
            tabBars++;
            UITabBar *bar = (UITabBar *)v;
            NSMutableArray *titles = [NSMutableArray array];
            for (UITabBarItem *item in bar.items) {
                if (item.title && [item.title length] > 0) [titles addObject:item.title];
            }
            [sig appendFormat:GHLKSStr("tabbar:%ld|"), (long)[titles count]];
            [log appendFormat:GHLKSStr(" [UITabBar items=%ld: %s]"), (long)[titles count], [[titles componentsJoinedByString:GHLKSStr("/")] UTF8String]];
            continue;
        }
        // 贴底的非 TabBar 自定义容器：记它里面按钮的标题。
        CGRect f = [v convertRect:v.bounds toView:nil];
        if (CGRectIsEmpty(f)) continue;
        if (CGRectGetMaxY(f) < screenH - 120.0) continue;
        if (CGRectGetHeight(f) < 40.0 || CGRectGetHeight(f) > 110.0) continue;
        if (CGRectGetWidth(f) < screenW * 0.8) continue;
        NSMutableArray *titles = [NSMutableArray array];
        for (UIView *sub in v.subviews) {
            if ([titles count] >= 6) break;
            if ([sub isKindOfClass:[UIButton class]]) {
                NSString *t = [(UIButton *)sub titleForState:UIControlStateNormal];
                if (t && [t length] > 0) [titles addObject:t];
            }
        }
        if ([titles count] == 0) continue;
        customBars++;
        NSString *cls = NSStringFromClass([v class]);
        [sig appendFormat:GHLKSStr("%s|"), [cls UTF8String]];
        [log appendFormat:GHLKSStr(" [%s: %s]"), [cls UTF8String], [[titles componentsJoinedByString:GHLKSStr("/")] UTF8String]];
    }
    self.tabBarScans++;
    self.tabBarFound = tabBars + customBars;
    if (![self signatureChanged:sig forKey:"tabBarProbe"]) return;
    if (tabBars == 0 && customBars == 0) {
        GHLKSLog("v1.0.2 tab bar probe scan %ld: no tab bar found", self.tabBarScans);
        return;
    }
    GHLKSLog("v1.0.2 tab bar probe scan %ld: tabbars=%ld custom=%ld%s", self.tabBarScans, tabBars, customBars, [log UTF8String]);
}

- (NSString *)tabBarProbeStatus {
    char buf[160];
    snprintf(buf, sizeof(buf), "tab bar enabled:%d scans:%ld found:%ld",
             _tabBarTimer ? 1 : 0, self.tabBarScans, self.tabBarFound);
    return GHLKSStr(buf);
}

#pragma mark - AD 章节探针（#11）

- (void)setAdChapterProbeEnabled:(BOOL)enabled {
    if (enabled) [self runAdChapterProbeOnce];
    __weak GHLKSProbe *weakSelf = self;
    [self setProbeTimer:&_adChapterTimer enabled:enabled interval:3.0 block:^{
        [weakSelf runAdChapterProbeOnce];
    }];
}

- (BOOL)adChapterProbeEnabled {
    return _adChapterTimer != nil;
}

- (void)runAdChapterProbeOnce {
    UIWindow *win = [GHLKSProbe mainAppWindow];
    if (!win) return;
    NSArray *cells = [GHLKSProbe visibleCellsInWindow:win];
    NSMutableString *sig = [NSMutableString string];
    NSMutableString *log = [NSMutableString string];
    long withModel = 0;
    long checked = 0;
    static const char *chapterKeys[] = { "chapter", "section", "skip", "segment", "advert", NULL };
    for (id cell in cells) {
        if (checked >= 4) break;
        checked++;
        id model = [GHLKSProbe modelOfCell:cell];
        if (!model) continue;
        withModel++;
        NSString *modelClass = NSStringFromClass([model class]);
        unsigned int propCount = 0;
        objc_property_t *props = class_copyPropertyList([model class], &propCount);
        NSMutableArray *hits = [NSMutableArray array];
        if (props) {
            unsigned int shown = propCount > 40 ? 40 : propCount;
            for (unsigned int i = 0; i < shown; i++) {
                const char *name = property_getName(props[i]);
                if (!name) continue;
                NSString *lower = [[GHLKSStr(name) lowercaseString] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
                for (int k = 0; chapterKeys[k]; k++) {
                    if ([lower rangeOfString:GHLKSStr(chapterKeys[k])].location != NSNotFound) {
                        [hits addObject:GHLKSStr(name)];
                        break;
                    }
                }
            }
            free(props);
        }
        [sig appendFormat:GHLKSStr("%s:%ld|"), [modelClass UTF8String], (long)[hits count]];
        [log appendFormat:GHLKSStr(" [model %s props=%u chapterFields=%s]"), [modelClass UTF8String], propCount, [[hits componentsJoinedByString:GHLKSStr(",")] UTF8String]];
    }
    self.adChapterScans++;
    self.adChapterFound = withModel;
    if (![self signatureChanged:sig forKey:"adChapterProbe"]) return;
    if (withModel == 0) {
        GHLKSLog("v1.0.2 ad chapter probe scan %ld: cells=%ld no model", self.adChapterScans, (long)[cells count]);
        return;
    }
    GHLKSLog("v1.0.2 ad chapter probe scan %ld: models=%ld%s", self.adChapterScans, withModel, [log UTF8String]);
}

- (NSString *)adChapterProbeStatus {
    char buf[160];
    snprintf(buf, sizeof(buf), "ad chapter enabled:%d scans:%ld models:%ld",
             _adChapterTimer ? 1 : 0, self.adChapterScans, self.adChapterFound);
    return GHLKSStr(buf);
}

#pragma mark - 续火花探针（#16）

- (void)setSparkProbeEnabled:(BOOL)enabled {
    if (enabled) [self runSparkProbeOnce];
    __weak GHLKSProbe *weakSelf = self;
    [self setProbeTimer:&_sparkTimer enabled:enabled interval:3.0 block:^{
        [weakSelf runSparkProbeOnce];
    }];
}

- (BOOL)sparkProbeEnabled {
    return _sparkTimer != nil;
}

- (void)runSparkProbeOnce {
    UIWindow *win = [GHLKSProbe mainAppWindow];
    if (!win) return;
    NSArray *cells = [GHLKSProbe visibleCellsInWindow:win];
    long avatars = 0;
    for (id cell in cells) {
        if (![cell isKindOfClass:[UIView class]]) continue;
        NSMutableArray *subs = [NSMutableArray array];
        [GHLKSProbe collectSubviewsOf:(UIView *)cell into:subs];
        for (UIView *sub in subs) {
            if ([sub isKindOfClass:[UIImageView class]]) avatars++;
        }
    }
    NSMutableArray *all = [NSMutableArray array];
    [GHLKSProbe collectSubviewsOf:win into:all];
    long inputs = 0;
    NSString *inputClass = nil;
    for (UIView *v in all) {
        if ([v isKindOfClass:[UITextField class]] || [v isKindOfClass:[UITextView class]]) {
            inputs++;
            if (!inputClass) inputClass = NSStringFromClass([v class]);
        }
    }
    self.sparkScans++;
    self.sparkFound = avatars;
    char sigBuf[128];
    snprintf(sigBuf, sizeof(sigBuf), "cells:%ld avatars:%ld inputs:%ld %s",
             (long)[cells count], avatars, inputs, inputClass ? [inputClass UTF8String] : "-");
    if (![self signatureChanged:GHLKSStr(sigBuf) forKey:"sparkProbe"]) return;
    GHLKSLog("v1.0.2 spark probe scan %ld: cells=%ld avatars=%ld inputs=%ld inputClass=%s",
             self.sparkScans, (long)[cells count], avatars, inputs, inputClass ? [inputClass UTF8String] : "-");
}

- (NSString *)sparkProbeStatus {
    char buf[160];
    snprintf(buf, sizeof(buf), "spark enabled:%d scans:%ld avatars:%ld",
             _sparkTimer ? 1 : 0, self.sparkScans, self.sparkFound);
    return GHLKSStr(buf);
}

#pragma mark - 头像探针（#18）

- (void)setAvatarProbeEnabled:(BOOL)enabled {
    if (enabled) [self runAvatarProbeOnce];
    __weak GHLKSProbe *weakSelf = self;
    [self setProbeTimer:&_avatarTimer enabled:enabled interval:3.0 block:^{
        [weakSelf runAvatarProbeOnce];
    }];
}

- (BOOL)avatarProbeEnabled {
    return _avatarTimer != nil;
}

- (void)runAvatarProbeOnce {
    UIWindow *win = [GHLKSProbe mainAppWindow];
    if (!win) return;
    NSMutableArray *all = [NSMutableArray array];
    [GHLKSProbe collectSubviewsOf:win into:all];
    NSMutableString *sig = [NSMutableString string];
    NSMutableString *log = [NSMutableString string];
    long found = 0;
    for (UIView *v in all) {
        if (found >= 5) break;
        if (![v isKindOfClass:[UIImageView class]]) continue;
        CGFloat w = CGRectGetWidth(v.bounds);
        CGFloat h = CGRectGetHeight(v.bounds);
        if (w < 30.0 || w > 120.0 || h < 30.0 || h > 120.0) continue;
        if (fabs(w - h) > 10.0) continue;
        UIImage *img = [(UIImageView *)v image];
        if (!img) continue;
        found++;
        CGRect f = [v convertRect:v.bounds toView:nil];
        [sig appendFormat:GHLKSStr("%.0f,%.0f|"), CGRectGetMinX(f), CGRectGetMinY(f)];
        [log appendFormat:GHLKSStr(" [%.0f,%.0f %.0fx%.0f img %.0fx%.0f]"),
            CGRectGetMinX(f), CGRectGetMinY(f), w, h, img.size.width, img.size.height];
    }
    self.avatarScans++;
    self.avatarFound = found;
    if (![self signatureChanged:sig forKey:"avatarProbe"]) return;
    if (found == 0) {
        GHLKSLog("v1.0.2 avatar probe scan %ld: no avatar candidate", self.avatarScans);
        return;
    }
    GHLKSLog("v1.0.2 avatar probe scan %ld: candidates=%ld%s", self.avatarScans, found, [log UTF8String]);
}

- (NSString *)avatarProbeStatus {
    char buf[160];
    snprintf(buf, sizeof(buf), "avatar enabled:%d scans:%ld found:%ld",
             _avatarTimer ? 1 : 0, self.avatarScans, self.avatarFound);
    return GHLKSStr(buf);
}

#pragma mark - 自动连播探针（#27）

- (void)setAutoPlayProbeEnabled:(BOOL)enabled {
    if (enabled) [self runAutoPlayProbeOnce];
    __weak GHLKSProbe *weakSelf = self;
    [self setProbeTimer:&_autoPlayTimer enabled:enabled interval:3.0 block:^{
        [weakSelf runAutoPlayProbeOnce];
    }];
}

- (BOOL)autoPlayProbeEnabled {
    return _autoPlayTimer != nil;
}

- (void)runAutoPlayProbeOnce {
    UIWindow *win = [GHLKSProbe mainAppWindow];
    if (!win) return;
    NSMutableArray *all = [NSMutableArray array];
    [GHLKSProbe collectSubviewsOf:win into:all];
    NSMutableArray *players = [NSMutableArray array];
    double progress = -1;
    for (UIView *v in all) {
        NSString *cls = NSStringFromClass([v class]);
        NSString *lower = [cls lowercaseString];
        if ([lower rangeOfString:GHLKSStr("player")].location != NSNotFound) {
            if ([players count] < 5 && ![players containsObject:cls]) [players addObject:cls];
        }
        if (progress < 0) {
            if ([v isKindOfClass:[UIProgressView class]]) {
                progress = [(UIProgressView *)v progress];
            } else if ([v isKindOfClass:[UISlider class]]) {
                progress = [(UISlider *)v value];
            }
        }
    }
    self.autoPlayScans++;
    self.autoPlayFound = [players count];
    char sigBuf[256];
    snprintf(sigBuf, sizeof(sigBuf), "players:%s progress:%.2f",
             [[players componentsJoinedByString:GHLKSStr(",")] UTF8String], progress);
    if (![self signatureChanged:GHLKSStr(sigBuf) forKey:"autoPlayProbe"]) return;
    GHLKSLog("v1.0.2 autoplay probe scan %ld: players=[%s] progress=%.2f",
             self.autoPlayScans, [[players componentsJoinedByString:GHLKSStr(",")] UTF8String], progress);
}

- (NSString *)autoPlayProbeStatus {
    char buf[160];
    snprintf(buf, sizeof(buf), "autoplay enabled:%d scans:%ld players:%ld",
             _autoPlayTimer ? 1 : 0, self.autoPlayScans, self.autoPlayFound);
    return GHLKSStr(buf);
}

#pragma mark - 格子 ivar 探针（#30）

- (void)setIvarProbeEnabled:(BOOL)enabled {
    if (enabled) [self runIvarProbeOnce];
    __weak GHLKSProbe *weakSelf = self;
    [self setProbeTimer:&_ivarTimer enabled:enabled interval:3.0 block:^{
        [weakSelf runIvarProbeOnce];
    }];
}

- (BOOL)ivarProbeEnabled {
    return _ivarTimer != nil;
}

- (void)runIvarProbeOnce {
    UIWindow *win = [GHLKSProbe mainAppWindow];
    if (!win) return;
    NSArray *cells = [GHLKSProbe visibleCellsInWindow:win];
    NSMutableString *sig = [NSMutableString string];
    NSMutableString *log = [NSMutableString string];
    NSMutableArray *seenClasses = [NSMutableArray array];
    long dumped = 0;
    for (id cell in cells) {
        if (dumped >= 2) break;
        NSString *cellClass = NSStringFromClass([cell class]);
        if ([seenClasses containsObject:cellClass]) continue;
        [seenClasses addObject:cellClass];
        dumped++;
        [sig appendFormat:GHLKSStr("%s|"), [cellClass UTF8String]];
        [log appendFormat:GHLKSStr(" [%s"), [cellClass UTF8String]];
        // 沿类链上溯 3 层扒 ivar（只记名字与类型编码首字，不记内容）。
        Class cls = [cell class];
        int depth = 0;
        while (cls && depth < 3) {
            unsigned int ivarCount = 0;
            Ivar *ivars = class_copyIvarList(cls, &ivarCount);
            if (ivars) {
                unsigned int shown = ivarCount > 30 ? 30 : ivarCount;
                [log appendFormat:GHLKSStr(" %s#%u:"), class_getName(cls), ivarCount];
                for (unsigned int i = 0; i < shown; i++) {
                    const char *name = ivar_getName(ivars[i]);
                    const char *enc = ivar_getTypeEncoding(ivars[i]);
                    if (!name) continue;
                    [sig appendFormat:GHLKSStr("%s,"), name];
                    char typeCh = (enc && enc[0]) ? enc[0] : '?';
                    [log appendFormat:GHLKSStr(" %s(%c)"), name, typeCh];
                }
                free(ivars);
            }
            cls = class_getSuperclass(cls);
            depth++;
        }
        // 对象型 ivar 的值只记类名（前 10 个），不记内容。
        Class cls2 = [cell class];
        int depth2 = 0;
        int objShown = 0;
        NSMutableString *objs = [NSMutableString string];
        while (cls2 && depth2 < 3 && objShown < 10) {
            unsigned int ivarCount = 0;
            Ivar *ivars = class_copyIvarList(cls2, &ivarCount);
            if (ivars) {
                unsigned int shown = ivarCount > 30 ? 30 : ivarCount;
                for (unsigned int i = 0; i < shown && objShown < 10; i++) {
                    const char *enc = ivar_getTypeEncoding(ivars[i]);
                    if (!enc || enc[0] != '@') continue;
                    id obj = nil;
                    @try {
                        obj = object_getIvar(cell, ivars[i]);
                    } @catch (NSException *e) {
                        obj = nil;
                    }
                    if (!obj || obj == (id)[NSNull null]) continue;
                    const char *name = ivar_getName(ivars[i]);
                    [objs appendFormat:GHLKSStr(" %s=%s"), name ? name : "?", [NSStringFromClass([obj class]) UTF8String]];
                    objShown++;
                }
                free(ivars);
            }
            cls2 = class_getSuperclass(cls2);
            depth2++;
        }
        if (objShown > 0) [log appendFormat:GHLKSStr(" objs:%s"), [objs UTF8String]];
        [log appendString:GHLKSStr("]")];
    }
    self.ivarScans++;
    self.ivarFound = dumped;
    if (![self signatureChanged:sig forKey:"ivarProbe"]) return;
    if (dumped == 0) {
        GHLKSLog("v1.0.2 ivar probe scan %ld: no visible cells", self.ivarScans);
        return;
    }
    // 日志行有 2048 字节上限，超了截断，留个尾巴。
    NSString *line = [NSString stringWithFormat:GHLKSStr("v1.0.2 ivar probe scan %ld: cells=%ld%s"),
        self.ivarScans, dumped, log];
    if ([line length] > 1500) line = [[line substringToIndex:1500] stringByAppendingString:GHLKSStr("...")];
    GHLKSLog("%s", [line UTF8String]);
}

- (NSString *)ivarProbeStatus {
    char buf[160];
    snprintf(buf, sizeof(buf), "ivar probe enabled:%d scans:%ld cells:%ld",
             _ivarTimer ? 1 : 0, self.ivarScans, self.ivarFound);
    return GHLKSStr(buf);
}

@end
