// GHLKS.h — 顾海龙快手共享工具：字串、日志、设置、路径。
// 零字面量规则：本工程任何源码文件里都不写 ObjC 字串字面量，
// 所有字串运行时由 C 字串拼出，dylib 的 __cfstring 必须为 0。
// 注释里也不出现字面量写法，以免 grep 误报。
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

#ifdef __cplusplus
extern "C" {
#endif

static const char *kGHLKSVersion = "1.0.2";
static const char *kGHLKSTargetKuaishouVersion = "14.10.10";
static const char *kGHLKSTargetKuaishouBuild = "10089";
static const char *kGHLKSPrefsDomain = "com.guhailong.kuaishou";
static const char *kGHLKSLogFileName = "GuHaiLongKuaishou.log";
static const char *kGHLKSQQNumber = "2309103548";
static const char *kGHLKSQQGroupNumber = "1130823454";
// 1.0.2 去掉了金色加入 QQ 群按钮，加群邀请链接随按钮一起删了（只留群号行，点按复制）。

// 由 UTF-8 C 字串在运行时拼出 NSString（不产生 __cfstring）。
static inline NSString *GHLKSStr(const char *c) {
    if (!c) return nil;
    return [NSString stringWithUTF8String:c];
}

// 由 UTF-8 C 字串在运行时拼出 CFString（调用方负责 CFRelease）。
static inline CFStringRef GHLKSCFStr(const char *c) {
    if (!c) return NULL;
    return CFStringCreateWithCString(NULL, c, kCFStringEncodingUTF8);
}

// 写日志：追加到 Documents/GuHaiLongKuaishou.log（超 512KB 时丢掉前一半），
// 同时打到 stderr（设备 Console 可见）。C 格式字串 + 变参。
void GHLKSLog(const char *fmt, ...);

// 日志文件完整路径（Documents/GuHaiLongKuaishou.log）。
NSString *GHLKSLogFilePath(void);
// 读日志尾部（最多 maxBytes 字节，UTF-8 安全截断到行首）。
NSString *GHLKSLogTail(long maxBytes);
// 清空日志。
void GHLKSClearLog(void);

// 自选头像：存在 Documents/GuHaiLongKuaishou/custom-avatar.jpg；
// 有它时三处（悬浮钮、卡片头、关于页）都显示它，没有时回默认哆啦A梦图。
// 存图时居中裁成正方形、长边缩到 256 再写 JPEG（照抖音自选龙头的做法）。
NSString *GHLKSCustomAvatarPath(void);
BOOL GHLKSHasCustomAvatar(void);
BOOL GHLSaveCustomAvatarImage(UIImage *image);
void GHLClearCustomAvatar(void);

// 头像图路径：先试自选头像，再试哆啦A梦图（/var/jb/... 优先，
// 再试 /Library/...）；都找不到返回 nil。
NSString *GHLKSLogoImagePath(void);

// 快手自身版本字串，如 14.10.10 (10089)；读不到时返回目标版本。
NSString *GHLKSAppVersionString(void);

// 设置读写（CFPreferences，域 com.guhailong.kuaishou，
// 落在 App 沙盒 Library/Preferences/com.guhailong.kuaishou.plist）。
BOOL GHLKSPrefsBool(const char *key, BOOL defValue);
void GHLKSPrefsSetBool(const char *key, BOOL value);
double GHLKSPrefsDouble(const char *key, double defValue);
void GHLKSPrefsSetDouble(const char *key, double value);
long GHLKSPrefsInteger(const char *key, long defValue);
void GHLKSPrefsSetInteger(const char *key, long value);

// 配置导入／导出／恢复默认（v1.0.2 #2）：面板自己的设置存取。
// 导出把当前域的全部键值写成 Documents/GuHaiLongKuaishou-config.plist；
// 导入从文件读回（只认 NSNumber 值）；恢复默认清空域里全部键。
NSString *GHLKSConfigFilePath(void);
BOOL GHLKSExportConfig(void);
BOOL GHLKSImportConfigAtPath(NSString *path);
void GHLKSResetConfig(void);

#ifdef __cplusplus
}
#endif
