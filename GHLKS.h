// GHLKS.h — 顾海龙快手共享工具：字串、日志、设置、路径。
// 零字面量规则：本工程任何源码文件里都不写 ObjC 字串字面量，
// 所有字串运行时由 C 字串拼出，dylib 的 __cfstring 必须为 0。
// 注释里也不出现字面量写法，以免 grep 误报。
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

#ifdef __cplusplus
extern "C" {
#endif

static const char *kGHLKSVersion = "1.0.1";
static const char *kGHLKSTargetKuaishouVersion = "14.10.10";
static const char *kGHLKSTargetKuaishouBuild = "10089";
static const char *kGHLKSPrefsDomain = "com.guhailong.kuaishou";
static const char *kGHLKSLogFileName = "GuHaiLongKuaishou.log";
static const char *kGHLKSQQNumber = "2309103548";
static const char *kGHLKSQQGroupNumber = "1130823454";
// QQ 群加群邀请链接（与抖音同群 1130823454，做法与链接值照抖音的抄，只留这一份）。
static const char *kGHLKSQQGroupJoinURL = "https://qun.qq.com/universal-share/share?ac=1&authKey=1jedvqhgrhj4mHm9Sn3c2xEkV3wYRdGeXsFSXn8hHJsRBfOUByIchAevdyEfS5zF&busi_data=eyJncm91cENvZGUiOiIxMTMwODIzNDU0IiwidG9rZW4iOiJxOE5XZTRWSi85emU0RjdNZXNyd2k2Y0lMYmw4MmtnNWVjNjRCeE56SnpNMWRYditLaFJFSU5iV2xoYzViNEl5IiwidWluIjoiMjMwOTEwMzU0OCJ9&data=nYcdCBHCI0lOt1ACENZWO6AfqrZ-Ha1TSfx7CBzkhHazin64W38fmSNXGIU0a9oPEvGgEk8ggiqR2imYH4J-pg&svctype=4&tempid=h5_group_info";

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

// 龙头图路径：优先 /var/jb/...（rootless），再试 /Library/...；找不到返回 nil。
NSString *GHLKSDragonImagePath(void);

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

#ifdef __cplusplus
}
#endif
