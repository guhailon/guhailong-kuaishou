// GHLKSPanel.m — 悬浮入口钮 + 深色毛玻璃设置卡片。
// 全部是我们自己的 UIKit 代码，不碰快手内部；菜单里的规划页诚实标明未接入 Hook。
#import "GHLKSPanel.h"
#import "GHLKS.h"
#import "GHLKSProbe.h"
#import <objc/runtime.h>

static UIWindow *GHLKSFloatWindow = nil;
static UIWindow *GHLKSPanelWindow = nil;
static UINavigationController *GHLKSPanelNav = nil;
static BOOL GHLKSPanelOpen = NO;
static UIWindow *GHLKSLongPressWindow = nil; // 长按面板的窗口（v1.0.2 #23）

#pragma mark - 小工具

static UIColor *GHLKSGoldColor(void) {
    return [UIColor colorWithRed:212.0 / 255.0 green:175.0 / 255.0 blue:55.0 / 255.0 alpha:1.0];
}

static UIColor *GHLKSRedColor(void) {
    return [UIColor colorWithRed:1.0 green:0.38 blue:0.32 alpha:1.0];
}

// 深色按钮（诊断页一节定义，通用设置页先用，先声明）。
static UIButton *GHLKSMakeDarkButton(const char *title, id target, SEL action);

static UILabel *GHLKSMakeLabel(const char *text, CGFloat size, BOOL bold, UIColor *color) {
    UILabel *label = [[UILabel alloc] init];
    label.text = GHLKSStr(text);
    label.font = bold ? [UIFont boldSystemFontOfSize:size] : [UIFont systemFontOfSize:size];
    label.textColor = color;
    label.backgroundColor = [UIColor clearColor];
    return label;
}

static UILabel *GHLKSMakeLabelStr(NSString *text, CGFloat size, BOOL bold, UIColor *color) {
    UILabel *label = [[UILabel alloc] init];
    label.text = text;
    label.font = bold ? [UIFont boldSystemFontOfSize:size] : [UIFont systemFontOfSize:size];
    label.textColor = color;
    label.backgroundColor = [UIColor clearColor];
    return label;
}

// 金底完成钮（卡片底部共用样式）。
static UIButton *GHLKSMakeGoldButton(const char *title, id target, SEL action) {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
    [button setTitle:GHLKSStr(title) forState:UIControlStateNormal];
    [button setTitleColor:[UIColor colorWithRed:0.10 green:0.10 blue:0.10 alpha:1.0] forState:UIControlStateNormal];
    button.titleLabel.font = [UIFont boldSystemFontOfSize:16];
    button.backgroundColor = GHLKSGoldColor();
    button.layer.cornerRadius = 12;
    button.layer.masksToBounds = YES;
    [button addTarget:target action:action forControlEvents:UIControlEventTouchUpInside];
    return button;
}

// 卡片：深色毛玻璃 + 圆角 + 淡金边。
static UIVisualEffectView *GHLKSMakeCardView(void) {
    UIBlurEffect *blur = [UIBlurEffect effectWithStyle:UIBlurEffectStyleDark];
    UIVisualEffectView *card = [[UIVisualEffectView alloc] initWithEffect:blur];
    card.layer.cornerRadius = 20;
    card.layer.masksToBounds = YES;
    card.layer.borderColor = [[GHLKSGoldColor() colorWithAlphaComponent:0.4] CGColor];
    card.layer.borderWidth = 1.0;
    UIView *shade = [[UIView alloc] init];
    shade.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.28];
    shade.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [card.contentView addSubview:shade];
    return card;
}

// 卡片在当前屏幕里的框：宽至多 380，高至多 620，居中。
static CGRect GHLKSCardFrameForBounds(CGRect bounds) {
    CGFloat w = CGRectGetWidth(bounds) - 40.0;
    if (w > 380.0) w = 380.0;
    CGFloat h = CGRectGetHeight(bounds) - 110.0;
    if (h > 620.0) h = 620.0;
    CGFloat x = (CGRectGetWidth(bounds) - w) / 2.0;
    CGFloat y = (CGRectGetHeight(bounds) - h) / 2.0;
    return CGRectMake(x, y, w, h);
}

static void GHLKSShowToast(NSString *text) {
    // 宿主优先用设置卡片窗口；长按面板里点按钮时设置窗可能还没建过，用长按窗口兜底。
    UIWindow *host = GHLKSPanelWindow ? GHLKSPanelWindow : GHLKSLongPressWindow;
    if (!host || !text) return;
    UILabel *toast = [[UILabel alloc] init];
    toast.text = text;
    toast.font = [UIFont systemFontOfSize:14];
    toast.textColor = [UIColor whiteColor];
    toast.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.8];
    toast.textAlignment = NSTextAlignmentCenter;
    toast.layer.cornerRadius = 10;
    toast.layer.masksToBounds = YES;
    CGSize size = [toast sizeThatFits:CGSizeMake(300, 40)];
    CGFloat w = size.width + 32;
    CGFloat h = 36;
    toast.frame = CGRectMake((CGRectGetWidth(host.bounds) - w) / 2.0,
                             CGRectGetHeight(host.bounds) - 120.0, w, h);
    [host addSubview:toast];
    toast.alpha = 0;
    [UIView animateWithDuration:0.2 animations:^{
        toast.alpha = 1;
    } completion:^(BOOL finished) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [UIView animateWithDuration:0.3 animations:^{
                toast.alpha = 0;
            } completion:^(BOOL f2) {
                [toast removeFromSuperview];
            }];
        });
    }];
}

#pragma mark - 悬浮入口钮

@interface GHLKSFloatHandler : NSObject
- (void)handleTap:(UITapGestureRecognizer *)gesture;
- (void)handlePan:(UIPanGestureRecognizer *)gesture;
@end

@implementation GHLKSFloatHandler

- (void)handleTap:(UITapGestureRecognizer *)gesture {
    if (gesture.state == UIGestureRecognizerStateRecognized) {
        GHLKSShowPanel();
    }
}

- (void)handlePan:(UIPanGestureRecognizer *)gesture {
    if (!GHLKSFloatWindow) return;
    CGPoint translation = [gesture translationInView:GHLKSFloatWindow];
    CGPoint center = GHLKSFloatWindow.center;
    center.x += translation.x;
    center.y += translation.y;
    [gesture setTranslation:CGPointZero inView:GHLKSFloatWindow];
    CGRect screen = [UIScreen mainScreen].bounds;
    CGFloat half = 28.0;
    if (center.x < half) center.x = half;
    if (center.x > CGRectGetWidth(screen) - half) center.x = CGRectGetWidth(screen) - half;
    if (center.y < half + 20.0) center.y = half + 20.0;
    if (center.y > CGRectGetHeight(screen) - half - 20.0) center.y = CGRectGetHeight(screen) - half - 20.0;
    GHLKSFloatWindow.center = center;
    if (gesture.state == UIGestureRecognizerStateEnded || gesture.state == UIGestureRecognizerStateCancelled) {
        GHLKSPrefsSetDouble("floatButtonXPercent", center.x / CGRectGetWidth(screen));
        GHLKSPrefsSetDouble("floatButtonYPercent", center.y / CGRectGetHeight(screen));
        GHLKSLog("v1.0.2 float button moved to %.0f,%.0f", center.x, center.y);
    }
}

@end

void GHLKSInstallFloatingButton(void) {
    if (GHLKSFloatWindow) return;
    CGRect screen = [UIScreen mainScreen].bounds;
    CGFloat xPercent = GHLKSPrefsDouble("floatButtonXPercent", -1);
    CGFloat yPercent = GHLKSPrefsDouble("floatButtonYPercent", -1);
    CGFloat cx = (xPercent >= 0) ? xPercent * CGRectGetWidth(screen) : CGRectGetWidth(screen) - 44.0;
    CGFloat cy = (yPercent >= 0) ? yPercent * CGRectGetHeight(screen) : 220.0;
    GHLKSFloatWindow = [[UIWindow alloc] initWithFrame:CGRectMake(cx - 28.0, cy - 28.0, 56.0, 56.0)];
    GHLKSFloatWindow.windowLevel = UIWindowLevelAlert;
    GHLKSFloatWindow.backgroundColor = [UIColor clearColor];
    UIViewController *holder = [[UIViewController alloc] init];
    holder.view.backgroundColor = [UIColor clearColor];
    GHLKSFloatWindow.rootViewController = holder;
    UIView *buttonView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 56.0, 56.0)];
    buttonView.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.55];
    buttonView.layer.cornerRadius = 28.0;
    buttonView.layer.masksToBounds = YES;
    buttonView.layer.borderColor = [[GHLKSGoldColor() colorWithAlphaComponent:0.9] CGColor];
    buttonView.layer.borderWidth = 2.0;
    NSString *imagePath = GHLKSLogoImagePath();
    if (imagePath) {
        UIImage *image = [UIImage imageWithContentsOfFile:imagePath];
        if (image) {
            UIImageView *iv = [[UIImageView alloc] initWithFrame:CGRectMake(4, 4, 48, 48)];
            iv.image = image;
            iv.contentMode = UIViewContentModeScaleAspectFill;
            iv.layer.cornerRadius = 24.0;
            iv.layer.masksToBounds = YES;
            [buttonView addSubview:iv];
        }
    }
    if ([buttonView.subviews count] == 0) {
        UILabel *fallback = GHLKSMakeLabel("顾", 24, YES, GHLKSGoldColor());
        fallback.frame = CGRectMake(0, 0, 56, 56);
        fallback.textAlignment = NSTextAlignmentCenter;
        [buttonView addSubview:fallback];
    }
    [holder.view addSubview:buttonView];
    GHLKSFloatHandler *handler = [[GHLKSFloatHandler alloc] init];
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:handler action:@selector(handleTap:)];
    [buttonView addGestureRecognizer:tap];
    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:handler action:@selector(handlePan:)];
    [buttonView addGestureRecognizer:pan];
    objc_setAssociatedObject(GHLKSFloatWindow, "handler", handler, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    GHLKSFloatWindow.hidden = NO;
    GHLKSLog("v1.0.2 float button installed at %.0f,%.0f image=%s", cx, cy, imagePath ? "yes" : "no");
}

// 换头像 / 恢复默认后重刷悬浮钮里的图（面板关掉、悬浮钮再出现时就是新图）。
static void GHLKSRefreshFloatingButtonImage(void) {
    if (!GHLKSFloatWindow) return;
    UIView *holderView = GHLKSFloatWindow.rootViewController.view;
    if (!holderView || [[holderView subviews] count] == 0) return;
    UIView *buttonView = [[holderView subviews] objectAtIndex:0];
    NSString *imagePath = GHLKSLogoImagePath();
    UIImage *image = imagePath ? [UIImage imageWithContentsOfFile:imagePath] : nil;
    if (!image) return;
    for (UIView *sub in [buttonView subviews]) {
        if ([sub isKindOfClass:[UIImageView class]]) {
            ((UIImageView *)sub).image = image;
            return;
        }
    }
    // 之前是文字兜底、没有图：把文字拿掉，补一张图上去。
    for (UIView *sub in [[buttonView subviews] copy]) {
        if ([sub isKindOfClass:[UILabel class]]) [sub removeFromSuperview];
    }
    UIImageView *iv = [[UIImageView alloc] initWithFrame:CGRectMake(4, 4, 48, 48)];
    iv.image = image;
    iv.contentMode = UIViewContentModeScaleAspectFill;
    iv.layer.cornerRadius = 24.0;
    iv.layer.masksToBounds = YES;
    [buttonView addSubview:iv];
}

#pragma mark - 子页基类（卡片 + 顶部返回行 + 底部完成钮）

@interface GHLKSPageViewController : UIViewController
@property (nonatomic, strong) UIVisualEffectView *card;
@property (nonatomic, strong) UIScrollView *scroll;
@property (nonatomic, strong) UIView *content;
@property (nonatomic, strong) UIButton *doneButton;
@property (nonatomic, copy) NSString *pageTitle;
- (instancetype)initWithPageTitle:(const char *)title;
- (void)layoutPage;
- (void)backTapped;
- (void)doneTapped;
@end

@implementation GHLKSPageViewController

- (instancetype)initWithPageTitle:(const char *)title {
    self = [super init];
    if (self) {
        _pageTitle = GHLKSStr(title);
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor clearColor];
    _card = GHLKSMakeCardView();
    [self.view addSubview:_card];
    UIButton *back = [UIButton buttonWithType:UIButtonTypeCustom];
    [back setTitle:GHLKSStr("‹ 全部菜单") forState:UIControlStateNormal];
    [back setTitleColor:GHLKSGoldColor() forState:UIControlStateNormal];
    back.titleLabel.font = [UIFont systemFontOfSize:15];
    [back addTarget:self action:@selector(backTapped) forControlEvents:UIControlEventTouchUpInside];
    back.tag = 1001;
    [_card.contentView addSubview:back];
    UILabel *title = GHLKSMakeLabelStr(self.pageTitle, 16, YES, [UIColor whiteColor]);
    title.textAlignment = NSTextAlignmentCenter;
    title.tag = 1002;
    [_card.contentView addSubview:title];
    _scroll = [[UIScrollView alloc] init];
    _scroll.backgroundColor = [UIColor clearColor];
    _scroll.showsVerticalScrollIndicator = NO;
    [_card.contentView addSubview:_scroll];
    _content = [[UIView alloc] init];
    _content.backgroundColor = [UIColor clearColor];
    [_scroll addSubview:_content];
    _doneButton = GHLKSMakeGoldButton("完成", self, @selector(doneTapped));
    [_card.contentView addSubview:_doneButton];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    [self layoutPage];
}

- (void)layoutPage {
    CGRect cardFrame = GHLKSCardFrameForBounds(self.view.bounds);
    _card.frame = cardFrame;
    CGFloat cw = CGRectGetWidth(cardFrame);
    CGFloat ch = CGRectGetHeight(cardFrame);
    UIButton *back = (UIButton *)[_card.contentView viewWithTag:1001];
    back.frame = CGRectMake(12, 10, 110, 32);
    UILabel *title = (UILabel *)[_card.contentView viewWithTag:1002];
    title.frame = CGRectMake(0, 10, cw, 32);
    _doneButton.frame = CGRectMake(16, ch - 64, cw - 32, 48);
    _scroll.frame = CGRectMake(0, 48, cw, ch - 48 - 80);
    _content.frame = CGRectMake(0, 0, cw, _scroll.contentSize.height);
}

- (void)backTapped {
    [self.navigationController popToRootViewControllerAnimated:YES];
}

- (void)doneTapped {
    GHLKSHidePanel();
}

@end

// 开关行（标题 + 右侧开关），调用方定 tag；布局时 label 左、开关右（行高 44）。
// switchOut 必须是 __strong 写回（ivar 地址传给 __autoreleasing 写回参数会报错）。
static UIView *GHLKSMakeSwitchRow(const char *title, id target, SEL action, BOOL on, UISwitch * __strong *switchOut) {
    UIView *row = [[UIView alloc] init];
    row.backgroundColor = [[UIColor whiteColor] colorWithAlphaComponent:0.05];
    row.layer.cornerRadius = 8;
    UILabel *label = GHLKSMakeLabel(title, 14, NO, [UIColor whiteColor]);
    label.tag = 4001;
    [row addSubview:label];
    UISwitch *sw = [[UISwitch alloc] init];
    sw.onTintColor = GHLKSGoldColor();
    sw.on = on;
    [sw addTarget:target action:action forControlEvents:UIControlEventValueChanged];
    [row addSubview:sw];
    if (switchOut) *switchOut = sw;
    return row;
}

static void GHLKSLayoutSwitchRow(UIView *row, UISwitch *sw, CGFloat cw, CGFloat y) {
    row.frame = CGRectMake(16, y, cw - 32, 44);
    UILabel *label = (UILabel *)[row viewWithTag:4001];
    label.frame = CGRectMake(12, 0, cw - 120, 44);
    CGRect sf = sw.frame;
    sw.frame = CGRectMake(cw - 32 - CGRectGetWidth(sf) - 12, (44 - CGRectGetHeight(sf)) / 2.0, CGRectGetWidth(sf), CGRectGetHeight(sf));
}

// 子页类声明（定义在文件后面，菜单页先引用）。
@interface GHLKSPlanningViewController : GHLKSPageViewController
@end
@interface GHLKSGeneralSettingsViewController : GHLKSPageViewController <UIImagePickerControllerDelegate, UINavigationControllerDelegate, UIDocumentPickerDelegate>
@end
@interface GHLKSNavViewController : GHLKSPageViewController
@end
@interface GHLKSHomeViewController : GHLKSPageViewController
@end
@interface GHLKSFeaturedViewController : GHLKSPageViewController
@end
@interface GHLKSMessageViewController : GHLKSPageViewController
@end
@interface GHLKSMeViewController : GHLKSPageViewController
@end
@interface GHLKSPlaybackViewController : GHLKSPageViewController
@end
@interface GHLKSDiagnosticsViewController : GHLKSPageViewController
@end
@interface GHLKSLogViewerViewController : GHLKSPageViewController
@end
@interface GHLKSAboutViewController : GHLKSPageViewController
@end

#pragma mark - 菜单首页

@interface GHLKSMenuViewController : UIViewController
@end

@implementation GHLKSMenuViewController {
    UIVisualEffectView *_card;
    UIButton *_doneButton;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor clearColor];
    _card = GHLKSMakeCardView();
    [self.view addSubview:_card];
    // 头：哆啦A梦图 + 金字标题 + 英文小字 + 版本行。
    NSString *imagePath = GHLKSLogoImagePath();
    if (imagePath) {
        UIImage *image = [UIImage imageWithContentsOfFile:imagePath];
        if (image) {
            UIImageView *iv = [[UIImageView alloc] init];
            iv.image = image;
            iv.contentMode = UIViewContentModeScaleAspectFill;
            iv.layer.cornerRadius = 10;
            iv.layer.masksToBounds = YES;
            iv.layer.borderColor = [[GHLKSGoldColor() colorWithAlphaComponent:0.8] CGColor];
            iv.layer.borderWidth = 1.5;
            iv.tag = 2001;
            [_card.contentView addSubview:iv];
        }
    }
    UILabel *title = GHLKSMakeLabel("顾海龙快手", 22, YES, GHLKSGoldColor());
    title.tag = 2002;
    [_card.contentView addSubview:title];
    UILabel *sub = GHLKSMakeLabel("GUHAILONG KUAISHOU", 10, NO, [UIColor lightGrayColor]);
    sub.tag = 2003;
    [_card.contentView addSubview:sub];
    char verBuf[96];
    snprintf(verBuf, sizeof(verBuf), "v%s · 快手 %s", kGHLKSVersion, kGHLKSTargetKuaishouVersion);
    UILabel *ver = GHLKSMakeLabel(verBuf, 11, NO, [UIColor lightGrayColor]);
    ver.tag = 2004;
    [_card.contentView addSubview:ver];
    // 10 个菜单格：两列五排。
    static const char *titles[] = {
        "通用设置", "导航入口", "首页", "精选", "消息",
        "我", "其他页面", "播放互动", "诊断反馈", "关于",
    };
    static const char *symbols[] = {
        "gearshape", "list.bullet", "house", "play.square", "message",
        "person", "doc", "play.circle", "stethoscope", "info.circle",
    };
    for (int i = 0; i < 10; i++) {
        UIView *tile = [[UIView alloc] init];
        tile.backgroundColor = [[UIColor whiteColor] colorWithAlphaComponent:0.08];
        tile.layer.cornerRadius = 12;
        tile.tag = 3000 + i;
        UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tileTapped:)];
        [tile addGestureRecognizer:tap];
        UIImage *icon = [UIImage systemImageNamed:GHLKSStr(symbols[i])];
        if (!icon) icon = [UIImage systemImageNamed:GHLKSStr("questionmark.circle")];
        UIImageView *iv = [[UIImageView alloc] initWithImage:icon];
        iv.tintColor = GHLKSGoldColor();
        iv.contentMode = UIViewContentModeScaleAspectFit;
        iv.tag = 3100 + i;
        [tile addSubview:iv];
        UILabel *label = GHLKSMakeLabel(titles[i], 13, NO, [UIColor whiteColor]);
        label.textAlignment = NSTextAlignmentCenter;
        label.tag = 3200 + i;
        [tile addSubview:label];
        [_card.contentView addSubview:tile];
    }
    _doneButton = GHLKSMakeGoldButton("完成", self, @selector(doneTapped));
    [_card.contentView addSubview:_doneButton];
}

// 从子页返回时重刷卡片头图（通用设置里换了头像，回来就要看到新图）。
- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    UIImageView *iv = (UIImageView *)[_card.contentView viewWithTag:2001];
    if (!iv) return;
    NSString *imagePath = GHLKSLogoImagePath();
    UIImage *image = imagePath ? [UIImage imageWithContentsOfFile:imagePath] : nil;
    if (image) iv.image = image;
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    CGRect cardFrame = GHLKSCardFrameForBounds(self.view.bounds);
    _card.frame = cardFrame;
    CGFloat cw = CGRectGetWidth(cardFrame);
    CGFloat ch = CGRectGetHeight(cardFrame);
    UIImageView *iv = (UIImageView *)[_card.contentView viewWithTag:2001];
    if (iv) iv.frame = CGRectMake(16, 16, 64, 64);
    UILabel *title = (UILabel *)[_card.contentView viewWithTag:2002];
    title.frame = CGRectMake(92, 18, cw - 108, 28);
    UILabel *sub = (UILabel *)[_card.contentView viewWithTag:2003];
    sub.frame = CGRectMake(92, 46, cw - 108, 14);
    UILabel *ver = (UILabel *)[_card.contentView viewWithTag:2004];
    ver.frame = CGRectMake(92, 62, cw - 108, 14);
    CGFloat gap = 10.0;
    CGFloat tileW = (cw - 32.0 - gap) / 2.0;
    CGFloat tileH = 64.0;
    CGFloat gridTop = 96.0;
    for (int i = 0; i < 10; i++) {
        UIView *tile = [_card.contentView viewWithTag:3000 + i];
        int row = i / 2;
        int col = i % 2;
        tile.frame = CGRectMake(16 + col * (tileW + gap), gridTop + row * (tileH + gap), tileW, tileH);
        UIImageView *icon = (UIImageView *)[tile viewWithTag:3100 + i];
        icon.frame = CGRectMake((tileW - 26) / 2.0, 8, 26, 26);
        UILabel *label = (UILabel *)[tile viewWithTag:3200 + i];
        label.frame = CGRectMake(0, 38, tileW, 18);
    }
    _doneButton.frame = CGRectMake(16, ch - 64, cw - 32, 48);
}

- (void)tileTapped:(UITapGestureRecognizer *)gesture {
    NSInteger index = gesture.view.tag - 3000;
    if (index < 0 || index > 9) return;
    UIViewController *vc = nil;
    switch (index) {
        case 0: vc = [[GHLKSGeneralSettingsViewController alloc] initWithPageTitle:"通用设置"]; break;
        case 1: vc = [[GHLKSNavViewController alloc] initWithPageTitle:"导航入口"]; break;
        case 2: vc = [[GHLKSHomeViewController alloc] initWithPageTitle:"首页设置"]; break;
        case 3: vc = [[GHLKSFeaturedViewController alloc] initWithPageTitle:"精选设置"]; break;
        case 4: vc = [[GHLKSMessageViewController alloc] initWithPageTitle:"消息设置"]; break;
        case 5: vc = [[GHLKSMeViewController alloc] initWithPageTitle:"我的设置"]; break;
        case 6: vc = [[GHLKSPlanningViewController alloc] initWithPageTitle:"其他页面"]; break;
        case 7: vc = [[GHLKSPlaybackViewController alloc] initWithPageTitle:"播放互动"]; break;
        case 8: vc = [[GHLKSDiagnosticsViewController alloc] init]; break;
        case 9: vc = [[GHLKSAboutViewController alloc] init]; break;
        default: break;
    }
    if (vc) [self.navigationController pushViewController:vc animated:YES];
}

- (void)doneTapped {
    GHLKSHidePanel();
}

@end

#pragma mark - 规划页

@implementation GHLKSPlanningViewController {
    UILabel *_badge;
    UILabel *_body;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    _badge = GHLKSMakeLabel("规 划", 13, YES, GHLKSGoldColor());
    _badge.textAlignment = NSTextAlignmentCenter;
    _badge.layer.borderColor = [[GHLKSGoldColor() colorWithAlphaComponent:0.8] CGColor];
    _badge.layer.borderWidth = 1.0;
    _badge.layer.cornerRadius = 8;
    _badge.layer.masksToBounds = YES;
    [self.content addSubview:_badge];
    char buf[512];
    snprintf(buf, sizeof(buf), "此页内容尚未接入 Hook，功能还在规划中。等拿到快手 %s 的类 dump、定位到相关 Hook 后，这里会填入真正的开关与功能。",
             kGHLKSTargetKuaishouVersion);
    _body = GHLKSMakeLabel(buf, 14, NO, [UIColor whiteColor]);
    _body.numberOfLines = 0;
    [self.content addSubview:_body];
}

- (void)layoutPage {
    [super layoutPage];
    CGFloat cw = CGRectGetWidth(self.content.bounds);
    if (cw <= 0) cw = CGRectGetWidth(self.card.frame);
    _badge.frame = CGRectMake(16, 12, 64, 28);
    CGFloat bodyW = cw - 32;
    CGSize bodySize = [_body sizeThatFits:CGSizeMake(bodyW, 1000)];
    _body.frame = CGRectMake(16, 56, bodyW, bodySize.height);
    self.scroll.contentSize = CGSizeMake(cw, 56 + bodySize.height + 20);
    CGRect cf = self.content.frame;
    cf.size.height = self.scroll.contentSize.height;
    self.content.frame = cf;
}

@end

#pragma mark - 通用设置页（更换头像 / 恢复默认）

@implementation GHLKSGeneralSettingsViewController {
    UIImageView *_avatarView;
    UILabel *_statusLabel;
}

- (instancetype)init {
    return [super initWithPageTitle:"通用设置"];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    _avatarView = [[UIImageView alloc] init];
    _avatarView.contentMode = UIViewContentModeScaleAspectFill;
    _avatarView.layer.cornerRadius = 12;
    _avatarView.layer.masksToBounds = YES;
    _avatarView.layer.borderColor = [[GHLKSGoldColor() colorWithAlphaComponent:0.8] CGColor];
    _avatarView.layer.borderWidth = 1.5;
    _avatarView.tag = 4601;
    [self.content addSubview:_avatarView];
    _statusLabel = GHLKSMakeLabel("", 14, NO, [UIColor whiteColor]);
    _statusLabel.textAlignment = NSTextAlignmentCenter;
    _statusLabel.tag = 4602;
    [self.content addSubview:_statusLabel];
    UIButton *changeButton = GHLKSMakeDarkButton("更换头像", self, @selector(changeAvatarTapped));
    changeButton.tag = 4603;
    [self.content addSubview:changeButton];
    UIButton *resetButton = GHLKSMakeDarkButton("恢复默认头像", self, @selector(resetAvatarTapped));
    resetButton.tag = 4604;
    [self.content addSubview:resetButton];
    UILabel *note = GHLKSMakeLabel("头像用在悬浮钮、菜单卡片头和关于页。从相册挑一张换上去，或恢复默认哆啦A梦。", 12, NO, [UIColor lightGrayColor]);
    note.numberOfLines = 0;
    note.tag = 4605;
    [self.content addSubview:note];
    // v1.0.2 #2：配置导入／导出／恢复默认（面板自己的设置存取，不用 Hook）。
    UILabel *configTitle = GHLKSMakeLabel("配置", 15, YES, [UIColor whiteColor]);
    configTitle.tag = 4606;
    [self.content addSubview:configTitle];
    UIButton *exportButton = GHLKSMakeDarkButton("导出配置", self, @selector(exportConfigTapped));
    exportButton.tag = 4607;
    [self.content addSubview:exportButton];
    UIButton *importButton = GHLKSMakeDarkButton("导入配置", self, @selector(importConfigTapped));
    importButton.tag = 4608;
    [self.content addSubview:importButton];
    UIButton *resetConfigButton = GHLKSMakeDarkButton("恢复默认配置", self, @selector(resetConfigTapped));
    resetConfigButton.tag = 4609;
    [self.content addSubview:resetConfigButton];
    UILabel *configNote = GHLKSMakeLabel("导出把当前设置存成 .plist 分享出去；导入从文件读回；恢复默认清空全部设置并关掉所有探针，头像不变。导入后探针开关立即生效，悬浮钮位置需重启快手。", 12, NO, [UIColor lightGrayColor]);
    configNote.numberOfLines = 0;
    configNote.tag = 4610;
    [self.content addSubview:configNote];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self refreshAvatar];
}

- (void)refreshAvatar {
    NSString *imagePath = GHLKSLogoImagePath();
    UIImage *image = imagePath ? [UIImage imageWithContentsOfFile:imagePath] : nil;
    if (image) _avatarView.image = image;
    _statusLabel.text = GHLKSStr(GHLKSHasCustomAvatar() ? "已换自选图" : "默认哆啦A梦");
}

// 更换头像：相册选图（照抖音自选龙头的做法；存图是 256 像素小 JPEG，主线程直接存，不开后台队列）。
- (void)changeAvatarTapped {
    UIImagePickerController *picker = [[UIImagePickerController alloc] init];
    picker.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
    picker.delegate = self;
    [self presentViewController:picker animated:YES completion:nil];
}

- (void)resetAvatarTapped {
    GHLClearCustomAvatar();
    GHLKSRefreshFloatingButtonImage();
    [self refreshAvatar];
    GHLKSLog("v1.0.2 custom avatar reset to default");
    GHLKSShowToast(GHLKSStr("已恢复默认头像"));
}

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info {
    UIImage *image = [info objectForKey:UIImagePickerControllerOriginalImage];
    [picker dismissViewControllerAnimated:YES completion:nil];
    if (!image) {
        GHLKSShowToast(GHLKSStr("选图失败"));
        return;
    }
    BOOL ok = GHLSaveCustomAvatarImage(image);
    if (!ok) {
        GHLKSShowToast(GHLKSStr("保存失败，换图没成功"));
        return;
    }
    GHLKSRefreshFloatingButtonImage();
    [self refreshAvatar];
    GHLKSLog("v1.0.2 custom avatar saved");
    GHLKSShowToast(GHLKSStr("头像已更换"));
}

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker {
    [picker dismissViewControllerAnimated:YES completion:nil];
}

// 导出配置：写成 .plist 再交系统分享（照日志页分享日志的做法）。
- (void)exportConfigTapped {
    if (!GHLKSExportConfig()) {
        GHLKSShowToast(GHLKSStr("导出失败"));
        return;
    }
    NSString *path = GHLKSConfigFilePath();
    NSURL *url = [NSURL fileURLWithPath:path];
    UIActivityViewController *activityVC = [[UIActivityViewController alloc] initWithActivityItems:[NSArray arrayWithObject:url] applicationActivities:nil];
    if ([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPad) {
        activityVC.popoverPresentationController.sourceView = self.view;
        activityVC.popoverPresentationController.sourceRect = self.view.bounds;
    }
    [self presentViewController:activityVC animated:YES completion:nil];
    GHLKSLog("v1.0.2 config exported");
}

// 导入配置：文件选择器挑 .plist 读回。
- (void)importConfigTapped {
    UIDocumentPickerViewController *picker = [[UIDocumentPickerViewController alloc]
        initWithDocumentTypes:[NSArray arrayWithObject:GHLKSStr("public.property-list")]
        inMode:UIDocumentPickerModeOpen];
    picker.delegate = self;
    [self presentViewController:picker animated:YES completion:nil];
}

- (void)documentPicker:(UIDocumentPickerViewController *)controller didPickDocumentsAtURLs:(NSArray<NSURL *> *)urls {
    NSURL *url = [urls firstObject];
    if (!url) {
        GHLKSShowToast(GHLKSStr("没有选到文件"));
        return;
    }
    BOOL ok = NO;
    if ([url startAccessingSecurityScopedResource]) {
        NSString *tmp = [[NSTemporaryDirectory() stringByAppendingPathComponent:GHLKSStr("ghlks-import.plist")] copy];
        [[NSFileManager defaultManager] removeItemAtPath:tmp error:nil];
        if ([[NSFileManager defaultManager] copyItemAtURL:url toURL:[NSURL fileURLWithPath:tmp] error:nil]) {
            ok = GHLKSImportConfigAtPath(tmp);
        }
        [[NSFileManager defaultManager] removeItemAtPath:tmp error:nil];
        [url stopAccessingSecurityScopedResource];
    }
    if (!ok) {
        GHLKSShowToast(GHLKSStr("导入失败，不是有效的配置文件"));
        return;
    }
    // 探针开关按新配置立即生效；悬浮钮位置要重启快手才动。
    [[GHLKSProbe sharedProbe] syncProbeStatesFromPrefs];
    GHLKSLog("v1.0.2 config imported");
    GHLKSShowToast(GHLKSStr("配置已导入"));
}

- (void)documentPickerWasCancelled:(UIDocumentPickerViewController *)controller {
}

// 恢复默认配置：先确认，清空全部设置并关掉所有探针，头像文件不动。
- (void)resetConfigTapped {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:GHLKSStr("恢复默认配置")
        message:GHLKSStr("清空全部设置并关掉所有探针，头像不变。")
        preferredStyle:UIAlertControllerStyleAlert];
    UIAlertAction *cancel = [UIAlertAction actionWithTitle:GHLKSStr("取消") style:UIAlertActionStyleCancel handler:nil];
    UIAlertAction *confirm = [UIAlertAction actionWithTitle:GHLKSStr("确定恢复") style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action) {
        GHLKSResetConfig();
        [[GHLKSProbe sharedProbe] syncProbeStatesFromPrefs];
        [self refreshAvatar];
        GHLKSLog("v1.0.2 config reset to defaults");
        GHLKSShowToast(GHLKSStr("已恢复默认配置"));
    }];
    [alert addAction:cancel];
    [alert addAction:confirm];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)layoutPage {
    [super layoutPage];
    CGFloat cw = CGRectGetWidth(self.content.bounds);
    if (cw <= 0) cw = CGRectGetWidth(self.card.frame);
    CGFloat y = 8;
    _avatarView.frame = CGRectMake((cw - 72) / 2.0, y, 72, 72);
    y += 80;
    _statusLabel.frame = CGRectMake(16, y, cw - 32, 22);
    y += 30;
    UIButton *changeButton = (UIButton *)[self.content viewWithTag:4603];
    changeButton.frame = CGRectMake(16, y, cw - 32, 44);
    y += 52;
    UIButton *resetButton = (UIButton *)[self.content viewWithTag:4604];
    resetButton.frame = CGRectMake(16, y, cw - 32, 44);
    y += 52;
    UILabel *note = (UILabel *)[self.content viewWithTag:4605];
    CGSize nSize = [note sizeThatFits:CGSizeMake(cw - 32, 1000)];
    note.frame = CGRectMake(16, y, cw - 32, nSize.height);
    y += nSize.height + 12;
    UILabel *configTitle = (UILabel *)[self.content viewWithTag:4606];
    configTitle.frame = CGRectMake(16, y, cw - 32, 22);
    y += 30;
    UIButton *exportButton = (UIButton *)[self.content viewWithTag:4607];
    exportButton.frame = CGRectMake(16, y, cw - 32, 44);
    y += 52;
    UIButton *importButton = (UIButton *)[self.content viewWithTag:4608];
    importButton.frame = CGRectMake(16, y, cw - 32, 44);
    y += 52;
    UIButton *resetConfigButton = (UIButton *)[self.content viewWithTag:4609];
    resetConfigButton.frame = CGRectMake(16, y, cw - 32, 44);
    y += 52;
    UILabel *configNote = (UILabel *)[self.content viewWithTag:4610];
    CGSize cSize = [configNote sizeThatFits:CGSizeMake(cw - 32, 1000)];
    configNote.frame = CGRectMake(16, y, cw - 32, cSize.height);
    y += cSize.height + 20;
    self.scroll.contentSize = CGSizeMake(cw, y);
    CGRect cf = self.content.frame;
    cf.size.height = y;
    self.content.frame = cf;
}

@end

#pragma mark - 导航入口页（#5 顶栏探针 / #6 底栏项探针 / #7 说明）

@implementation GHLKSNavViewController {
    UISwitch *_topBarSwitch;
    UISwitch *_tabBarSwitch;
    UILabel *_bottomNote;
}

- (instancetype)init {
    return [super initWithPageTitle:"导航入口"];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    UIView *rowA = GHLKSMakeSwitchRow("顶栏探针", self, @selector(topBarSwitchChanged:), GHLKSPrefsBool("topBarProbeEnabled", NO), &_topBarSwitch);
    rowA.tag = 4701;
    [self.content addSubview:rowA];
    UIView *rowB = GHLKSMakeSwitchRow("底栏项探针", self, @selector(tabBarSwitchChanged:), GHLKSPrefsBool("tabBarProbeEnabled", NO), &_tabBarSwitch);
    rowB.tag = 4702;
    [self.content addSubview:rowB];
    _bottomNote = GHLKSMakeLabel("", 12, NO, [UIColor lightGrayColor]);
    _bottomNote.numberOfLines = 0;
    _bottomNote.tag = 4703;
    [self.content addSubview:_bottomNote];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    char buf[256];
    snprintf(buf, sizeof(buf), "底栏透明试验开关在「诊断反馈」页。\n当前状态：%s",
             [[[GHLKSProbe sharedProbe] bottomBarProbeStatus] UTF8String]);
    _bottomNote.text = GHLKSStr(buf);
    _topBarSwitch.on = [[GHLKSProbe sharedProbe] topBarProbeEnabled];
    _tabBarSwitch.on = [[GHLKSProbe sharedProbe] tabBarProbeEnabled];
}

- (void)topBarSwitchChanged:(UISwitch *)sw {
    GHLKSPrefsSetBool("topBarProbeEnabled", sw.on);
    [[GHLKSProbe sharedProbe] setTopBarProbeEnabled:sw.on];
    GHLKSLog("v1.0.2 top bar probe switch %s", sw.on ? "on" : "off");
}

- (void)tabBarSwitchChanged:(UISwitch *)sw {
    GHLKSPrefsSetBool("tabBarProbeEnabled", sw.on);
    [[GHLKSProbe sharedProbe] setTabBarProbeEnabled:sw.on];
    GHLKSLog("v1.0.2 tab bar probe switch %s", sw.on ? "on" : "off");
}

- (void)layoutPage {
    [super layoutPage];
    CGFloat cw = CGRectGetWidth(self.content.bounds);
    if (cw <= 0) cw = CGRectGetWidth(self.card.frame);
    CGFloat y = 8;
    UIView *rowA = [self.content viewWithTag:4701];
    GHLKSLayoutSwitchRow(rowA, _topBarSwitch, cw, y);
    y += 52;
    UIView *rowB = [self.content viewWithTag:4702];
    GHLKSLayoutSwitchRow(rowB, _tabBarSwitch, cw, y);
    y += 52;
    CGSize nSize = [_bottomNote sizeThatFits:CGSizeMake(cw - 32, 1000)];
    _bottomNote.frame = CGRectMake(16, y, cw - 32, nSize.height);
    y += nSize.height + 20;
    self.scroll.contentSize = CGSizeMake(cw, y);
    CGRect cf = self.content.frame;
    cf.size.height = y;
    self.content.frame = cf;
}

@end

#pragma mark - 首页页（#11 AD 章节探针）

@implementation GHLKSHomeViewController {
    UISwitch *_adChapterSwitch;
}

- (instancetype)init {
    return [super initWithPageTitle:"首页设置"];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    UIView *rowA = GHLKSMakeSwitchRow("AD 章节探针", self, @selector(adChapterSwitchChanged:), GHLKSPrefsBool("adChapterProbeEnabled", NO), &_adChapterSwitch);
    rowA.tag = 4711;
    [self.content addSubview:rowA];
    UILabel *note = GHLKSMakeLabel("只记章节模型字段，等日志定下识别字段再接，绝不先跳过。", 12, NO, [UIColor lightGrayColor]);
    note.numberOfLines = 0;
    note.tag = 4712;
    [self.content addSubview:note];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    _adChapterSwitch.on = [[GHLKSProbe sharedProbe] adChapterProbeEnabled];
}

- (void)adChapterSwitchChanged:(UISwitch *)sw {
    GHLKSPrefsSetBool("adChapterProbeEnabled", sw.on);
    [[GHLKSProbe sharedProbe] setAdChapterProbeEnabled:sw.on];
    GHLKSLog("v1.0.2 ad chapter probe switch %s", sw.on ? "on" : "off");
}

- (void)layoutPage {
    [super layoutPage];
    CGFloat cw = CGRectGetWidth(self.content.bounds);
    if (cw <= 0) cw = CGRectGetWidth(self.card.frame);
    CGFloat y = 8;
    UIView *rowA = [self.content viewWithTag:4711];
    GHLKSLayoutSwitchRow(rowA, _adChapterSwitch, cw, y);
    y += 52;
    UILabel *note = (UILabel *)[self.content viewWithTag:4712];
    CGSize nSize = [note sizeThatFits:CGSizeMake(cw - 32, 1000)];
    note.frame = CGRectMake(16, y, cw - 32, nSize.height);
    y += nSize.height + 20;
    self.scroll.contentSize = CGSizeMake(cw, y);
    CGRect cf = self.content.frame;
    cf.size.height = y;
    self.content.frame = cf;
}

@end

#pragma mark - 精选页（#12 已在诊断页，确认在位）

@implementation GHLKSFeaturedViewController {
    UILabel *_feedNote;
}

- (instancetype)init {
    return [super initWithPageTitle:"精选设置"];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    _feedNote = GHLKSMakeLabel("", 13, NO, [UIColor whiteColor]);
    _feedNote.numberOfLines = 0;
    _feedNote.tag = 4721;
    [self.content addSubview:_feedNote];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    char buf[256];
    snprintf(buf, sizeof(buf), "精选纯净探针开关在「诊断反馈」页。\n当前状态：%s",
             [[[GHLKSProbe sharedProbe] feedProbeStatus] UTF8String]);
    _feedNote.text = GHLKSStr(buf);
}

- (void)layoutPage {
    [super layoutPage];
    CGFloat cw = CGRectGetWidth(self.content.bounds);
    if (cw <= 0) cw = CGRectGetWidth(self.card.frame);
    CGSize nSize = [_feedNote sizeThatFits:CGSizeMake(cw - 32, 1000)];
    _feedNote.frame = CGRectMake(16, 12, cw - 32, nSize.height);
    CGFloat y = 12 + nSize.height + 20;
    self.scroll.contentSize = CGSizeMake(cw, y);
    CGRect cf = self.content.frame;
    cf.size.height = y;
    self.content.frame = cf;
}

@end

#pragma mark - 消息页（#16 续火花探针）

@implementation GHLKSMessageViewController {
    UISwitch *_sparkSwitch;
}

- (instancetype)init {
    return [super initWithPageTitle:"消息设置"];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    UIView *rowA = GHLKSMakeSwitchRow("续火花探针", self, @selector(sparkSwitchChanged:), GHLKSPrefsBool("sparkProbeEnabled", NO), &_sparkSwitch);
    rowA.tag = 4731;
    [self.content addSubview:rowA];
    UILabel *note = GHLKSMakeLabel("只记日志，绝不真发消息；先确认头像与输入框找不找得到。", 12, NO, [UIColor lightGrayColor]);
    note.numberOfLines = 0;
    note.tag = 4732;
    [self.content addSubview:note];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    _sparkSwitch.on = [[GHLKSProbe sharedProbe] sparkProbeEnabled];
}

- (void)sparkSwitchChanged:(UISwitch *)sw {
    GHLKSPrefsSetBool("sparkProbeEnabled", sw.on);
    [[GHLKSProbe sharedProbe] setSparkProbeEnabled:sw.on];
    GHLKSLog("v1.0.2 spark probe switch %s", sw.on ? "on" : "off");
}

- (void)layoutPage {
    [super layoutPage];
    CGFloat cw = CGRectGetWidth(self.content.bounds);
    if (cw <= 0) cw = CGRectGetWidth(self.card.frame);
    CGFloat y = 8;
    UIView *rowA = [self.content viewWithTag:4731];
    GHLKSLayoutSwitchRow(rowA, _sparkSwitch, cw, y);
    y += 52;
    UILabel *note = (UILabel *)[self.content viewWithTag:4732];
    CGSize nSize = [note sizeThatFits:CGSizeMake(cw - 32, 1000)];
    note.frame = CGRectMake(16, y, cw - 32, nSize.height);
    y += nSize.height + 20;
    self.scroll.contentSize = CGSizeMake(cw, y);
    CGRect cf = self.content.frame;
    cf.size.height = y;
    self.content.frame = cf;
}

@end

#pragma mark - 我的页（#18 头像探针）

@implementation GHLKSMeViewController {
    UISwitch *_avatarSwitch;
}

- (instancetype)init {
    return [super initWithPageTitle:"我的设置"];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    UIView *rowA = GHLKSMakeSwitchRow("头像探针", self, @selector(avatarSwitchChanged:), GHLKSPrefsBool("avatarProbeEnabled", NO), &_avatarSwitch);
    rowA.tag = 4741;
    [self.content addSubview:rowA];
    UILabel *note = GHLKSMakeLabel("只记日志；先确认头像视图与图片地址能不能通用拿到。", 12, NO, [UIColor lightGrayColor]);
    note.numberOfLines = 0;
    note.tag = 4742;
    [self.content addSubview:note];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    _avatarSwitch.on = [[GHLKSProbe sharedProbe] avatarProbeEnabled];
}

- (void)avatarSwitchChanged:(UISwitch *)sw {
    GHLKSPrefsSetBool("avatarProbeEnabled", sw.on);
    [[GHLKSProbe sharedProbe] setAvatarProbeEnabled:sw.on];
    GHLKSLog("v1.0.2 avatar probe switch %s", sw.on ? "on" : "off");
}

- (void)layoutPage {
    [super layoutPage];
    CGFloat cw = CGRectGetWidth(self.content.bounds);
    if (cw <= 0) cw = CGRectGetWidth(self.card.frame);
    CGFloat y = 8;
    UIView *rowA = [self.content viewWithTag:4741];
    GHLKSLayoutSwitchRow(rowA, _avatarSwitch, cw, y);
    y += 52;
    UILabel *note = (UILabel *)[self.content viewWithTag:4742];
    CGSize nSize = [note sizeThatFits:CGSizeMake(cw - 32, 1000)];
    note.frame = CGRectMake(16, y, cw - 32, nSize.height);
    y += nSize.height + 20;
    self.scroll.contentSize = CGSizeMake(cw, y);
    CGRect cf = self.content.frame;
    cf.size.height = y;
    self.content.frame = cf;
}

@end

#pragma mark - 播放互动页（#23 长按面板外壳 / #27 自动连播探针）

@implementation GHLKSPlaybackViewController {
    UISwitch *_longPressSwitch;
    UISwitch *_autoPlaySwitch;
}

- (instancetype)init {
    return [super initWithPageTitle:"播放互动"];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    UIView *rowA = GHLKSMakeSwitchRow("长按弹出面板", self, @selector(longPressSwitchChanged:), GHLKSPrefsBool("longPressPanelEnabled", YES), &_longPressSwitch);
    rowA.tag = 4751;
    [self.content addSubview:rowA];
    UIButton *previewButton = GHLKSMakeDarkButton("预览长按面板", self, @selector(previewLongPressTapped));
    previewButton.tag = 4752;
    [self.content addSubview:previewButton];
    UIView *rowB = GHLKSMakeSwitchRow("自动连播探针", self, @selector(autoPlaySwitchChanged:), GHLKSPrefsBool("autoPlayProbeEnabled", NO), &_autoPlaySwitch);
    rowB.tag = 4753;
    [self.content addSubview:rowB];
    UILabel *note = GHLKSMakeLabel("长按面板的 6 个按钮目前是占位，点按只记日志、提示「待接」，动作以后再接。", 12, NO, [UIColor lightGrayColor]);
    note.numberOfLines = 0;
    note.tag = 4754;
    [self.content addSubview:note];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    _longPressSwitch.on = GHLKSPrefsBool("longPressPanelEnabled", YES);
    _autoPlaySwitch.on = [[GHLKSProbe sharedProbe] autoPlayProbeEnabled];
}

- (void)longPressSwitchChanged:(UISwitch *)sw {
    GHLKSPrefsSetBool("longPressPanelEnabled", sw.on);
    if (sw.on) {
        GHLKSInstallLongPressPanel();
    } else {
        GHLKSRemoveLongPressPanel();
    }
    GHLKSLog("v1.0.2 long press panel switch %s", sw.on ? "on" : "off");
}

- (void)previewLongPressTapped {
    GHLKSShowLongPressPanel();
}

- (void)autoPlaySwitchChanged:(UISwitch *)sw {
    GHLKSPrefsSetBool("autoPlayProbeEnabled", sw.on);
    [[GHLKSProbe sharedProbe] setAutoPlayProbeEnabled:sw.on];
    GHLKSLog("v1.0.2 autoplay probe switch %s", sw.on ? "on" : "off");
}

- (void)layoutPage {
    [super layoutPage];
    CGFloat cw = CGRectGetWidth(self.content.bounds);
    if (cw <= 0) cw = CGRectGetWidth(self.card.frame);
    CGFloat y = 8;
    UIView *rowA = [self.content viewWithTag:4751];
    GHLKSLayoutSwitchRow(rowA, _longPressSwitch, cw, y);
    y += 52;
    UIButton *previewButton = (UIButton *)[self.content viewWithTag:4752];
    previewButton.frame = CGRectMake(16, y, cw - 32, 44);
    y += 52;
    UIView *rowB = [self.content viewWithTag:4753];
    GHLKSLayoutSwitchRow(rowB, _autoPlaySwitch, cw, y);
    y += 52;
    UILabel *note = (UILabel *)[self.content viewWithTag:4754];
    CGSize nSize = [note sizeThatFits:CGSizeMake(cw - 32, 1000)];
    note.frame = CGRectMake(16, y, cw - 32, nSize.height);
    y += nSize.height + 20;
    self.scroll.contentSize = CGSizeMake(cw, y);
    CGRect cf = self.content.frame;
    cf.size.height = y;
    self.content.frame = cf;
}

@end

#pragma mark - 诊断页

static UIButton *GHLKSMakeDarkButton(const char *title, id target, SEL action) {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
    [button setTitle:GHLKSStr(title) forState:UIControlStateNormal];
    [button setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    button.titleLabel.font = [UIFont systemFontOfSize:15];
    button.backgroundColor = [[UIColor whiteColor] colorWithAlphaComponent:0.08];
    button.layer.cornerRadius = 10;
    button.layer.masksToBounds = YES;
    [button addTarget:target action:action forControlEvents:UIControlEventTouchUpInside];
    return button;
}

@implementation GHLKSDiagnosticsViewController {
    NSMutableArray *_valueLabels;
    UISwitch *_bottomBarSwitch;
    UISwitch *_feedSwitch;
    UISwitch *_ivarSwitch;
}

- (instancetype)init {
    return [super initWithPageTitle:"诊断反馈"];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    _valueLabels = [NSMutableArray array];
    static const char *keys[] = {
        "插件版本", "快手版本", "底栏探针", "精选探针", "格子 ivar", "打开面板",
    };
    for (int i = 0; i < 6; i++) {
        UIView *row = [[UIView alloc] init];
        row.backgroundColor = [[UIColor whiteColor] colorWithAlphaComponent:0.05];
        row.layer.cornerRadius = 8;
        [self.content addSubview:row];
        UILabel *key = GHLKSMakeLabel(keys[i], 14, NO, [UIColor lightGrayColor]);
        key.tag = 4001;
        [row addSubview:key];
        UILabel *value = GHLKSMakeLabel("-", 14, NO, [UIColor whiteColor]);
        value.textAlignment = NSTextAlignmentRight;
        value.tag = 4002;
        [row addSubview:value];
        [_valueLabels addObject:value];
        row.tag = 4100 + i;
    }
    // 两个探针开关。
    UIView *rowA = [[UIView alloc] init];
    rowA.backgroundColor = [[UIColor whiteColor] colorWithAlphaComponent:0.05];
    rowA.layer.cornerRadius = 8;
    [self.content addSubview:rowA];
    UILabel *labelA = GHLKSMakeLabel("底栏透明（试验）", 14, NO, [UIColor whiteColor]);
    [rowA addSubview:labelA];
    labelA.tag = 4001;
    _bottomBarSwitch = [[UISwitch alloc] init];
    _bottomBarSwitch.onTintColor = GHLKSGoldColor();
    _bottomBarSwitch.on = GHLKSPrefsBool("bottomBarProbeEnabled", NO);
    [_bottomBarSwitch addTarget:self action:@selector(bottomBarSwitchChanged:) forControlEvents:UIControlEventValueChanged];
    [rowA addSubview:_bottomBarSwitch];
    rowA.tag = 4201;
    UIView *rowB = [[UIView alloc] init];
    rowB.backgroundColor = [[UIColor whiteColor] colorWithAlphaComponent:0.05];
    rowB.layer.cornerRadius = 8;
    [self.content addSubview:rowB];
    UILabel *labelB = GHLKSMakeLabel("精选探针日志", 14, NO, [UIColor whiteColor]);
    [rowB addSubview:labelB];
    labelB.tag = 4001;
    _feedSwitch = [[UISwitch alloc] init];
    _feedSwitch.onTintColor = GHLKSGoldColor();
    _feedSwitch.on = GHLKSPrefsBool("feedProbeEnabled", NO);
    [_feedSwitch addTarget:self action:@selector(feedSwitchChanged:) forControlEvents:UIControlEventValueChanged];
    [rowB addSubview:_feedSwitch];
    rowB.tag = 4202;
    // v1.0.2 #30：格子 ivar 探针开关。
    UIView *rowC = [[UIView alloc] init];
    rowC.backgroundColor = [[UIColor whiteColor] colorWithAlphaComponent:0.05];
    rowC.layer.cornerRadius = 8;
    [self.content addSubview:rowC];
    UILabel *labelC = GHLKSMakeLabel("格子 ivar 探针", 14, NO, [UIColor whiteColor]);
    [rowC addSubview:labelC];
    labelC.tag = 4001;
    _ivarSwitch = [[UISwitch alloc] init];
    _ivarSwitch.onTintColor = GHLKSGoldColor();
    _ivarSwitch.on = GHLKSPrefsBool("ivarProbeEnabled", NO);
    [_ivarSwitch addTarget:self action:@selector(ivarSwitchChanged:) forControlEvents:UIControlEventValueChanged];
    [rowC addSubview:_ivarSwitch];
    rowC.tag = 4203;
    // 两个按钮。
    UIButton *copyButton = GHLKSMakeDarkButton("复制状态文本", self, @selector(copyStatusTapped));
    copyButton.tag = 4301;
    [self.content addSubview:copyButton];
    UIButton *logButton = GHLKSMakeDarkButton("查看完整日志", self, @selector(viewLogTapped));
    logButton.tag = 4302;
    [self.content addSubview:logButton];
    UILabel *privacy = GHLKSMakeLabel("只复制插件数字，不采集作品／评论／账号、不上传。", 12, NO, [UIColor lightGrayColor]);
    privacy.numberOfLines = 0;
    privacy.tag = 4303;
    [self.content addSubview:privacy];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self refreshValues];
}

- (void)refreshValues {
    if ([_valueLabels count] < 6) return;
    char openBuf[64];
    snprintf(openBuf, sizeof(openBuf), "%ld 次", GHLKSPrefsInteger("panelOpenCount", 0));
    NSArray *values = [NSArray arrayWithObjects:
        GHLKSStr(kGHLKSVersion),
        GHLKSAppVersionString(),
        [[GHLKSProbe sharedProbe] bottomBarProbeStatus],
        [[GHLKSProbe sharedProbe] feedProbeStatus],
        [[GHLKSProbe sharedProbe] ivarProbeStatus],
        GHLKSStr(openBuf),
        nil];
    for (int i = 0; i < 6; i++) {
        UILabel *value = [_valueLabels objectAtIndex:i];
        value.text = [values objectAtIndex:i];
    }
    _bottomBarSwitch.on = [[GHLKSProbe sharedProbe] bottomBarProbeEnabled];
    _feedSwitch.on = [[GHLKSProbe sharedProbe] feedProbeEnabled];
    _ivarSwitch.on = [[GHLKSProbe sharedProbe] ivarProbeEnabled];
}

- (void)bottomBarSwitchChanged:(UISwitch *)sw {
    GHLKSPrefsSetBool("bottomBarProbeEnabled", sw.on);
    [[GHLKSProbe sharedProbe] setBottomBarProbeEnabled:sw.on];
    GHLKSLog("v1.0.2 bottom probe switch %s", sw.on ? "on" : "off");
    [self refreshValues];
}

- (void)feedSwitchChanged:(UISwitch *)sw {
    GHLKSPrefsSetBool("feedProbeEnabled", sw.on);
    [[GHLKSProbe sharedProbe] setFeedProbeEnabled:sw.on];
    GHLKSLog("v1.0.2 feed probe switch %s", sw.on ? "on" : "off");
    [self refreshValues];
}

- (void)ivarSwitchChanged:(UISwitch *)sw {
    GHLKSPrefsSetBool("ivarProbeEnabled", sw.on);
    [[GHLKSProbe sharedProbe] setIvarProbeEnabled:sw.on];
    GHLKSLog("v1.0.2 ivar probe switch %s", sw.on ? "on" : "off");
    [self refreshValues];
}

- (void)copyStatusTapped {
    char openBuf[64];
    snprintf(openBuf, sizeof(openBuf), "%ld", GHLKSPrefsInteger("panelOpenCount", 0));
    NSString *text = [NSString stringWithFormat:GHLKSStr("顾海龙快手 %@\n快手 %@\n底栏：%@\n精选探针：%@\n格子 ivar：%@\n打开面板：%@ 次"),
        GHLKSStr(kGHLKSVersion),
        GHLKSAppVersionString(),
        [[GHLKSProbe sharedProbe] bottomBarProbeStatus],
        [[GHLKSProbe sharedProbe] feedProbeStatus],
        [[GHLKSProbe sharedProbe] ivarProbeStatus],
        GHLKSStr(openBuf)];
    [UIPasteboard generalPasteboard].string = text;
    GHLKSLog("v1.0.2 status text copied");
    GHLKSShowToast(GHLKSStr("已复制状态文本"));
}

- (void)viewLogTapped {
    GHLKSLogViewerViewController *vc = [[GHLKSLogViewerViewController alloc] init];
    [self.navigationController pushViewController:vc animated:YES];
}

- (void)layoutPage {
    [super layoutPage];
    CGFloat cw = CGRectGetWidth(self.content.bounds);
    if (cw <= 0) cw = CGRectGetWidth(self.card.frame);
    CGFloat y = 8;
    for (int i = 0; i < 6; i++) {
        UIView *row = [self.content viewWithTag:4100 + i];
        row.frame = CGRectMake(16, y, cw - 32, 40);
        UILabel *key = (UILabel *)[row viewWithTag:4001];
        key.frame = CGRectMake(12, 0, 100, 40);
        UILabel *value = (UILabel *)[row viewWithTag:4002];
        value.frame = CGRectMake(112, 0, cw - 32 - 124, 40);
        y += 48;
    }
    for (int t = 0; t < 3; t++) {
        UIView *row = [self.content viewWithTag:4201 + t];
        row.frame = CGRectMake(16, y, cw - 32, 44);
        UILabel *label = (UILabel *)[row viewWithTag:4001];
        label.frame = CGRectMake(12, 0, cw - 120, 44);
        UISwitch *sw = (t == 0) ? _bottomBarSwitch : (t == 1) ? _feedSwitch : _ivarSwitch;
        CGRect sf = sw.frame;
        sw.frame = CGRectMake(cw - 32 - CGRectGetWidth(sf) - 12, (44 - CGRectGetHeight(sf)) / 2.0, CGRectGetWidth(sf), CGRectGetHeight(sf));
        y += 52;
    }
    UIButton *copyButton = (UIButton *)[self.content viewWithTag:4301];
    copyButton.frame = CGRectMake(16, y, cw - 32, 44);
    y += 52;
    UIButton *logButton = (UIButton *)[self.content viewWithTag:4302];
    logButton.frame = CGRectMake(16, y, cw - 32, 44);
    y += 52;
    UILabel *privacy = (UILabel *)[self.content viewWithTag:4303];
    CGSize pSize = [privacy sizeThatFits:CGSizeMake(cw - 32, 1000)];
    privacy.frame = CGRectMake(16, y, cw - 32, pSize.height);
    y += pSize.height + 20;
    self.scroll.contentSize = CGSizeMake(cw, y);
    CGRect cf = self.content.frame;
    cf.size.height = y;
    self.content.frame = cf;
}

@end

#pragma mark - 日志查看页

@implementation GHLKSLogViewerViewController {
    UITextView *_textView;
}

- (instancetype)init {
    return [super initWithPageTitle:"完整日志"];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    _textView = [[UITextView alloc] init];
    _textView.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.4];
    _textView.textColor = [UIColor whiteColor];
    _textView.font = [UIFont fontWithName:GHLKSStr("Menlo-Regular") size:11];
    if (!_textView.font) _textView.font = [UIFont systemFontOfSize:11];
    _textView.editable = NO;
    _textView.layer.cornerRadius = 8;
    _textView.layer.masksToBounds = YES;
    [self.content addSubview:_textView];
    UIButton *copyButton = GHLKSMakeDarkButton("复制日志", self, @selector(copyLogTapped));
    copyButton.tag = 4401;
    [self.content addSubview:copyButton];
    UIButton *shareButton = GHLKSMakeDarkButton("分享日志", self, @selector(shareLogTapped));
    shareButton.tag = 4404;
    [self.content addSubview:shareButton];
    UIButton *clearButton = GHLKSMakeDarkButton("清空日志", self, @selector(clearLogTapped));
    clearButton.tag = 4402;
    [self.content addSubview:clearButton];
    UIButton *refreshButton = GHLKSMakeDarkButton("刷新", self, @selector(refreshLogTapped));
    refreshButton.tag = 4403;
    [self.content addSubview:refreshButton];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self reloadLog];
}

- (void)reloadLog {
    NSString *tail = GHLKSLogTail(200 * 1024);
    _textView.text = ([tail length] > 0) ? tail : GHLKSStr("暂无日志");
}

- (void)copyLogTapped {
    [UIPasteboard generalPasteboard].string = _textView.text;
    GHLKSShowToast(GHLKSStr("已复制日志"));
}

// 分享日志：把日志文件整个交系统分享（存到文件、发给别人都行），照抖音导出配置的做法。
- (void)shareLogTapped {
    NSString *path = GHLKSLogFilePath();
    if (!path || ![[NSFileManager defaultManager] fileExistsAtPath:path]) {
        GHLKSShowToast(GHLKSStr("暂无日志"));
        return;
    }
    NSURL *url = [NSURL fileURLWithPath:path];
    UIActivityViewController *activityVC = [[UIActivityViewController alloc] initWithActivityItems:[NSArray arrayWithObject:url] applicationActivities:nil];
    if ([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPad) {
        activityVC.popoverPresentationController.sourceView = self.view;
        activityVC.popoverPresentationController.sourceRect = self.view.bounds;
    }
    [self presentViewController:activityVC animated:YES completion:nil];
}

- (void)clearLogTapped {
    GHLKSClearLog();
    [self reloadLog];
    GHLKSShowToast(GHLKSStr("日志已清空"));
}

- (void)refreshLogTapped {
    [self reloadLog];
}

- (void)layoutPage {
    [super layoutPage];
    CGFloat cw = CGRectGetWidth(self.content.bounds);
    if (cw <= 0) cw = CGRectGetWidth(self.card.frame);
    CGFloat scrollH = CGRectGetHeight(self.scroll.frame);
    _textView.frame = CGRectMake(16, 8, cw - 32, scrollH - 8 - 52 - 8);
    CGFloat bw = (cw - 32 - 24) / 4.0;
    UIButton *copyButton = (UIButton *)[self.content viewWithTag:4401];
    copyButton.frame = CGRectMake(16, scrollH - 52, bw, 44);
    UIButton *shareButton = (UIButton *)[self.content viewWithTag:4404];
    shareButton.frame = CGRectMake(16 + (bw + 8), scrollH - 52, bw, 44);
    UIButton *clearButton = (UIButton *)[self.content viewWithTag:4402];
    clearButton.frame = CGRectMake(16 + (bw + 8) * 2, scrollH - 52, bw, 44);
    UIButton *refreshButton = (UIButton *)[self.content viewWithTag:4403];
    refreshButton.frame = CGRectMake(16 + (bw + 8) * 3, scrollH - 52, bw, 44);
    self.scroll.contentSize = CGSizeMake(cw, scrollH);
    CGRect cf = self.content.frame;
    cf.size.height = scrollH;
    self.content.frame = cf;
}

@end

#pragma mark - 关于页

@implementation GHLKSAboutViewController {
    UILabel *_descLabel;
    UILabel *_disclaimerLabel;
    UIView *_qqRow;
    UIView *_groupRow;
}

- (instancetype)init {
    return [super initWithPageTitle:"关于"];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    NSString *imagePath = GHLKSLogoImagePath();
    if (imagePath) {
        UIImage *image = [UIImage imageWithContentsOfFile:imagePath];
        if (image) {
            UIImageView *iv = [[UIImageView alloc] initWithImage:image];
            iv.contentMode = UIViewContentModeScaleAspectFill;
            iv.layer.cornerRadius = 12;
            iv.layer.masksToBounds = YES;
            iv.layer.borderColor = [[GHLKSGoldColor() colorWithAlphaComponent:0.8] CGColor];
            iv.layer.borderWidth = 1.5;
            iv.tag = 4501;
            [self.content addSubview:iv];
        }
    }
    UILabel *title = GHLKSMakeLabel("顾海龙快手", 20, YES, GHLKSGoldColor());
    title.textAlignment = NSTextAlignmentCenter;
    title.tag = 4502;
    [self.content addSubview:title];
    UILabel *sub = GHLKSMakeLabel("GUHAILONG KUAISHOU", 10, NO, [UIColor lightGrayColor]);
    sub.textAlignment = NSTextAlignmentCenter;
    sub.tag = 4503;
    [self.content addSubview:sub];
    char verBuf[128];
    snprintf(verBuf, sizeof(verBuf), "插件版本 %s\n适配快手 %s / build %s", kGHLKSVersion, kGHLKSTargetKuaishouVersion, kGHLKSTargetKuaishouBuild);
    UILabel *ver = GHLKSMakeLabel(verBuf, 13, NO, [UIColor whiteColor]);
    ver.numberOfLines = 0;
    ver.textAlignment = NSTextAlignmentCenter;
    ver.tag = 4504;
    [self.content addSubview:ver];
    _descLabel = GHLKSMakeLabel("顾海龙快手 1.0.2：通用设置可换头像、导入导出配置；导航入口、首页、精选、消息、我、播放互动六个格子已做实（长按面板外壳 + 7 个探针，只记日志）；诊断页加格子 ivar 探针；底栏透明探针闪退已修。关于页留 QQ 群号一行，点按复制。精选纯净与底栏透明目前仅为探针，待快手 14.10.10 类 dump 后再接实效。免费使用，仅限学习交流。", 13, NO, [UIColor whiteColor]);
    _descLabel.numberOfLines = 0;
    _descLabel.tag = 4505;
    [self.content addSubview:_descLabel];
    _disclaimerLabel = GHLKSMakeLabel("免责声明：本插件为个人学习作品，修改第三方 App 存在封号风险，作者不作任何不封号保证；请自行承担风险，仅限学习交流使用。", 13, NO, GHLKSRedColor());
    _disclaimerLabel.numberOfLines = 0;
    _disclaimerLabel.tag = 4506;
    [self.content addSubview:_disclaimerLabel];
    _qqRow = [[UIView alloc] init];
    _qqRow.backgroundColor = [[UIColor whiteColor] colorWithAlphaComponent:0.05];
    _qqRow.layer.cornerRadius = 8;
    _qqRow.tag = 4507;
    [self.content addSubview:_qqRow];
    UILabel *qqLabel = GHLKSMakeLabel("QQ：2309103548（点按复制）", 14, NO, [UIColor whiteColor]);
    qqLabel.tag = 4508;
    [_qqRow addSubview:qqLabel];
    UITapGestureRecognizer *qqTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(qqTapped)];
    [_qqRow addGestureRecognizer:qqTap];
    // 1.0.1：QQ 群行（照抖音的做法，点群号复制）；1.0.2 去掉了金色加入 QQ 群大按钮（太碍眼），只留群号行。
    _groupRow = [[UIView alloc] init];
    _groupRow.backgroundColor = [[UIColor whiteColor] colorWithAlphaComponent:0.05];
    _groupRow.layer.cornerRadius = 8;
    _groupRow.tag = 4509;
    [self.content addSubview:_groupRow];
    UILabel *groupLabel = GHLKSMakeLabel("QQ群：1130823454（点按复制）", 14, NO, [UIColor whiteColor]);
    groupLabel.tag = 4510;
    [_groupRow addSubview:groupLabel];
    UITapGestureRecognizer *groupTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(groupTapped)];
    [_groupRow addGestureRecognizer:groupTap];
}

- (void)qqTapped {
    [UIPasteboard generalPasteboard].string = GHLKSStr(kGHLKSQQNumber);
    GHLKSShowToast(GHLKSStr("已复制 QQ 号"));
}

- (void)groupTapped {
    [UIPasteboard generalPasteboard].string = GHLKSStr(kGHLKSQQGroupNumber);
    GHLKSShowToast(GHLKSStr("已复制群号"));
}

- (void)layoutPage {
    [super layoutPage];
    CGFloat cw = CGRectGetWidth(self.content.bounds);
    if (cw <= 0) cw = CGRectGetWidth(self.card.frame);
    CGFloat y = 8;
    UIImageView *iv = (UIImageView *)[self.content viewWithTag:4501];
    if (iv) {
        iv.frame = CGRectMake((cw - 72) / 2.0, y, 72, 72);
        y += 80;
    }
    UILabel *title = (UILabel *)[self.content viewWithTag:4502];
    title.frame = CGRectMake(16, y, cw - 32, 26);
    y += 30;
    UILabel *sub = (UILabel *)[self.content viewWithTag:4503];
    sub.frame = CGRectMake(16, y, cw - 32, 14);
    y += 22;
    UILabel *ver = (UILabel *)[self.content viewWithTag:4504];
    CGSize vSize = [ver sizeThatFits:CGSizeMake(cw - 32, 1000)];
    ver.frame = CGRectMake(16, y, cw - 32, vSize.height);
    y += vSize.height + 12;
    CGSize dSize = [_descLabel sizeThatFits:CGSizeMake(cw - 32, 1000)];
    _descLabel.frame = CGRectMake(16, y, cw - 32, dSize.height);
    y += dSize.height + 12;
    CGSize xSize = [_disclaimerLabel sizeThatFits:CGSizeMake(cw - 32, 1000)];
    _disclaimerLabel.frame = CGRectMake(16, y, cw - 32, xSize.height);
    y += xSize.height + 12;
    _qqRow.frame = CGRectMake(16, y, cw - 32, 44);
    UILabel *qqLabel = (UILabel *)[_qqRow viewWithTag:4508];
    qqLabel.frame = CGRectMake(12, 0, cw - 56, 44);
    y += 44 + 12;
    _groupRow.frame = CGRectMake(16, y, cw - 32, 44);
    UILabel *groupLabel = (UILabel *)[_groupRow viewWithTag:4510];
    groupLabel.frame = CGRectMake(12, 0, cw - 56, 44);
    y += 44 + 20;
    self.scroll.contentSize = CGSizeMake(cw, y);
    CGRect cf = self.content.frame;
    cf.size.height = y;
    self.content.frame = cf;
}

@end

#pragma mark - 面板窗口管理

@interface GHLKSDimTapHandler : NSObject
- (void)dimTapped:(UITapGestureRecognizer *)gesture;
@end

@implementation GHLKSDimTapHandler
- (void)dimTapped:(UITapGestureRecognizer *)gesture {
    if (gesture.state == UIGestureRecognizerStateRecognized) {
        GHLKSHidePanel();
    }
}
@end

static void GHLKSEnsurePanelWindow(void) {
    if (GHLKSPanelWindow) return;
    GHLKSPanelWindow = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    GHLKSPanelWindow.windowLevel = UIWindowLevelAlert;
    GHLKSPanelWindow.backgroundColor = [UIColor clearColor];
    GHLKSMenuViewController *menu = [[GHLKSMenuViewController alloc] init];
    GHLKSPanelNav = [[UINavigationController alloc] initWithRootViewController:menu];
    GHLKSPanelNav.navigationBarHidden = YES;
    GHLKSPanelNav.view.backgroundColor = [UIColor clearColor];
    UIView *dim = [[UIView alloc] initWithFrame:GHLKSPanelNav.view.bounds];
    dim.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.5];
    dim.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    GHLKSDimTapHandler *handler = [[GHLKSDimTapHandler alloc] init];
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:handler action:@selector(dimTapped:)];
    [dim addGestureRecognizer:tap];
    objc_setAssociatedObject(GHLKSPanelNav, "dimHandler", handler, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [GHLKSPanelNav.view insertSubview:dim atIndex:0];
    GHLKSPanelWindow.rootViewController = GHLKSPanelNav;
    GHLKSPanelWindow.hidden = YES;
}

void GHLKSShowPanel(void) {
    if (GHLKSPanelOpen) return;
    GHLKSEnsurePanelWindow();
    GHLKSPanelOpen = YES;
    long count = GHLKSPrefsInteger("panelOpenCount", 0) + 1;
    GHLKSPrefsSetInteger("panelOpenCount", count);
    if (GHLKSFloatWindow) GHLKSFloatWindow.hidden = YES;
    [GHLKSPanelNav popToRootViewControllerAnimated:NO];
    GHLKSPanelWindow.hidden = NO;
    GHLKSPanelNav.view.alpha = 0;
    GHLKSPanelNav.view.transform = CGAffineTransformMakeScale(0.96, 0.96);
    [UIView animateWithDuration:0.28 delay:0 usingSpringWithDamping:0.8 initialSpringVelocity:0.5 options:0 animations:^{
        GHLKSPanelNav.view.alpha = 1;
        GHLKSPanelNav.view.transform = CGAffineTransformIdentity;
    } completion:nil];
    GHLKSLog("v1.0.2 panel opened (%ld)", count);
}

void GHLKSHidePanel(void) {
    if (!GHLKSPanelOpen) return;
    GHLKSPanelOpen = NO;
    [UIView animateWithDuration:0.2 animations:^{
        GHLKSPanelNav.view.alpha = 0;
        GHLKSPanelNav.view.transform = CGAffineTransformMakeScale(0.96, 0.96);
    } completion:^(BOOL finished) {
        GHLKSPanelWindow.hidden = YES;
        GHLKSPanelNav.view.transform = CGAffineTransformIdentity;
        if (GHLKSFloatWindow) GHLKSFloatWindow.hidden = NO;
    }];
    GHLKSLog("v1.0.2 panel closed");
}

BOOL GHLKSPanelIsOpen(void) {
    return GHLKSPanelOpen;
}

#pragma mark - 长按面板（v1.0.2 #23，6 钮网格外壳）

static UILongPressGestureRecognizer *GHLKSLongPressRecognizer = nil;

@interface GHLKSLongPressHandler : NSObject <UIGestureRecognizerDelegate>
- (void)handleLongPress:(UILongPressGestureRecognizer *)gesture;
@end

@implementation GHLKSLongPressHandler

- (void)handleLongPress:(UILongPressGestureRecognizer *)gesture {
    if (gesture.state != UIGestureRecognizerStateBegan) return;
    if (GHLKSPanelIsOpen()) return;
    if (GHLKSLongPressWindow && !GHLKSLongPressWindow.hidden) return;
    // 点在悬浮钮上不弹（那是开面板的手势）。
    if (GHLKSFloatWindow && !GHLKSFloatWindow.hidden) {
        CGPoint p = [gesture locationInView:nil];
        if (CGRectContainsPoint(GHLKSFloatWindow.frame, p)) return;
    }
    GHLKSShowLongPressPanel();
}

// 和快手自己的长按手势共存，不抢触摸。
- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gr shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)other {
    return YES;
}

@end

@interface GHLKSLongPressDimHandler : NSObject
- (void)dimTapped:(UITapGestureRecognizer *)gesture;
@end

@implementation GHLKSLongPressDimHandler
- (void)dimTapped:(UITapGestureRecognizer *)gesture {
    if (gesture.state == UIGestureRecognizerStateRecognized) {
        GHLKSHideLongPressPanel();
    }
}
@end

@interface GHLKSLongPressButtonHandler : NSObject
- (void)buttonTapped:(UIButton *)sender;
@end

@implementation GHLKSLongPressButtonHandler
- (void)buttonTapped:(UIButton *)sender {
    long idx = sender.tag - 5000;
    if (idx < 0 || idx > 5) return;
    if (idx == 5) {
        GHLKSHideLongPressPanel();
        return;
    }
    // 6 个按钮目前是占位：只记日志、提示待接，动作以后再接。
    static const char *names[] = { "save video", "save cover", "save audio", "copy link", "copy text", NULL };
    GHLKSLog("v1.0.2 long press action %s (pending)", names[idx]);
    GHLKSShowToast(GHLKSStr("待接"));
}
@end

static void GHLKSSetupLongPressWindow(void) {
    CGRect screen = [UIScreen mainScreen].bounds;
    GHLKSLongPressWindow = [[UIWindow alloc] initWithFrame:screen];
    GHLKSLongPressWindow.windowLevel = UIWindowLevelAlert;
    GHLKSLongPressWindow.backgroundColor = [UIColor clearColor];
    UIViewController *holder = [[UIViewController alloc] init];
    holder.view.backgroundColor = [UIColor clearColor];
    UIView *dim = [[UIView alloc] initWithFrame:holder.view.bounds];
    dim.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.5];
    dim.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    GHLKSLongPressDimHandler *dimHandler = [[GHLKSLongPressDimHandler alloc] init];
    UITapGestureRecognizer *dimTap = [[UITapGestureRecognizer alloc] initWithTarget:dimHandler action:@selector(dimTapped:)];
    [dim addGestureRecognizer:dimTap];
    objc_setAssociatedObject(GHLKSLongPressWindow, "dimHandler", dimHandler, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [holder.view addSubview:dim];
    CGFloat cardW = CGRectGetWidth(screen) - 64.0;
    if (cardW > 320.0) cardW = 320.0;
    CGFloat cardH = 308.0;
    UIVisualEffectView *card = GHLKSMakeCardView();
    card.frame = CGRectMake((CGRectGetWidth(screen) - cardW) / 2.0, (CGRectGetHeight(screen) - cardH) / 2.0, cardW, cardH);
    card.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin;
    UILabel *title = GHLKSMakeLabel("长按菜单", 16, YES, GHLKSGoldColor());
    title.textAlignment = NSTextAlignmentCenter;
    title.frame = CGRectMake(0, 14, cardW, 24);
    [card.contentView addSubview:title];
    static const char *titles[] = { "保存视频", "保存封面", "保存音频", "复制链接", "复制文案", "取消", NULL };
    GHLKSLongPressButtonHandler *handler = [[GHLKSLongPressButtonHandler alloc] init];
    CGFloat gap = 10.0;
    CGFloat btnW = (cardW - 32.0 - gap) / 2.0;
    CGFloat btnH = 44.0;
    for (int i = 0; i < 6; i++) {
        int row = i / 2;
        int col = i % 2;
        UIButton *button = GHLKSMakeDarkButton(titles[i], handler, @selector(buttonTapped:));
        button.tag = 5000 + i;
        button.frame = CGRectMake(16 + col * (btnW + gap), 52 + row * (btnH + gap), btnW, btnH);
        [card.contentView addSubview:button];
    }
    objc_setAssociatedObject(GHLKSLongPressWindow, "buttonHandler", handler, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [holder.view addSubview:card];
    GHLKSLongPressWindow.rootViewController = holder;
    GHLKSLongPressWindow.hidden = YES;
}

void GHLKSInstallLongPressPanel(void) {
    // 主窗口换过就重装（手势还挂在旧窗口上就等于没装）。
    if (GHLKSLongPressRecognizer && GHLKSLongPressRecognizer.view) return;
    GHLKSLongPressRecognizer = nil;
    UIWindow *win = [GHLKSProbe mainAppWindow];
    if (!win) return;
    GHLKSLongPressHandler *handler = [[GHLKSLongPressHandler alloc] init];
    UILongPressGestureRecognizer *lp = [[UILongPressGestureRecognizer alloc] initWithTarget:handler action:@selector(handleLongPress:)];
    lp.minimumPressDuration = 0.6;
    lp.cancelsTouchesInView = NO;
    lp.delegate = handler;
    [win addGestureRecognizer:lp];
    objc_setAssociatedObject(win, "longPressHandler", handler, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    GHLKSLongPressRecognizer = lp;
    GHLKSLog("v1.0.2 long press panel installed");
}

void GHLKSRemoveLongPressPanel(void) {
    if (!GHLKSLongPressRecognizer) return;
    UIView *view = GHLKSLongPressRecognizer.view;
    if (view) [view removeGestureRecognizer:GHLKSLongPressRecognizer];
    GHLKSLongPressRecognizer = nil;
    GHLKSHideLongPressPanel();
    GHLKSLog("v1.0.2 long press panel removed");
}

void GHLKSShowLongPressPanel(void) {
    if (!GHLKSLongPressWindow) GHLKSSetupLongPressWindow();
    GHLKSLongPressWindow.hidden = NO;
    GHLKSLog("v1.0.2 long press panel shown");
}

void GHLKSHideLongPressPanel(void) {
    if (!GHLKSLongPressWindow) return;
    GHLKSLongPressWindow.hidden = YES;
}
