// GHLKS.m — 日志、设置、路径的实现。
#import "GHLKS.h"
#import <stdio.h>
#import <stdarg.h>
#import <time.h>

static const long kGHLKSLogMaxBytes = 512 * 1024;

void GHLKSLog(const char *fmt, ...) {
    if (!fmt) return;
    char msg[2048];
    va_list ap;
    va_start(ap, fmt);
    vsnprintf(msg, sizeof(msg), fmt, ap);
    va_end(ap);
    time_t t = time(NULL);
    struct tm tmv;
    localtime_r(&t, &tmv);
    char line[2300];
    snprintf(line, sizeof(line), "%04d-%02d-%02d %02d:%02d:%02d [GuHaiLongKuaishou v%s] %s\n",
             tmv.tm_year + 1900, tmv.tm_mon + 1, tmv.tm_mday,
             tmv.tm_hour, tmv.tm_min, tmv.tm_sec, kGHLKSVersion, msg);
    fprintf(stderr, "%s", line);
    NSString *path = GHLKSLogFilePath();
    if (!path) return;
    NSFileManager *fm = [NSFileManager defaultManager];
    NSString *dir = [path stringByDeletingLastPathComponent];
    if (![fm fileExistsAtPath:dir]) {
        [fm createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:nil];
    }
    NSDictionary *attrs = [fm attributesOfItemAtPath:path error:nil];
    if (attrs) {
        NSNumber *size = [attrs objectForKey:GHLKSStr("NSFileSize")];
        if (size && [size longValue] > kGHLKSLogMaxBytes) {
            NSData *data = [NSData dataWithContentsOfFile:path];
            if (data && [data length] > (NSUInteger)(kGHLKSLogMaxBytes / 2)) {
                NSData *tail = [data subdataWithRange:NSMakeRange([data length] - (NSUInteger)(kGHLKSLogMaxBytes / 2), (NSUInteger)(kGHLKSLogMaxBytes / 2))];
                [tail writeToFile:path atomically:NO];
            }
        }
    }
    FILE *f = fopen([path UTF8String], "a");
    if (f) {
        fputs(line, f);
        fclose(f);
    }
}

NSString *GHLKSLogFilePath(void) {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *docs = [paths firstObject];
    if (!docs) return nil;
    return [docs stringByAppendingPathComponent:GHLKSStr(kGHLKSLogFileName)];
}

NSString *GHLKSLogTail(long maxBytes) {
    NSString *path = GHLKSLogFilePath();
    if (!path) return GHLKSStr("");
    NSData *data = [NSData dataWithContentsOfFile:path];
    if (!data || [data length] == 0) return GHLKSStr("");
    if ([data length] > (NSUInteger)maxBytes) {
        data = [data subdataWithRange:NSMakeRange([data length] - (NSUInteger)maxBytes, (NSUInteger)maxBytes)];
    }
    NSString *text = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    if (!text) {
        // 截断点落在多字节字元中间时丢掉第一行，保证可读。
        NSRange nl = [data rangeOfData:[GHLKSStr("\n") dataUsingEncoding:NSUTF8StringEncoding]
                               options:0
                                 range:NSMakeRange(0, [data length])];
        if (nl.location != NSNotFound && nl.location + 1 < [data length]) {
            NSData *cut = [data subdataWithRange:NSMakeRange(nl.location + 1, [data length] - nl.location - 1)];
            text = [[NSString alloc] initWithData:cut encoding:NSUTF8StringEncoding];
        }
    }
    return text ? text : GHLKSStr("");
}

void GHLKSClearLog(void) {
    NSString *path = GHLKSLogFilePath();
    if (!path) return;
    [[NSFileManager defaultManager] removeItemAtPath:path error:nil];
    GHLKSLog("log cleared by user");
}

static const char *kGHLKSCustomAvatarDirName = "GuHaiLongKuaishou";
static const char *kGHLKSCustomAvatarFileName = "custom-avatar.jpg";

NSString *GHLKSCustomAvatarPath(void) {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *docs = [paths firstObject];
    if (!docs) return nil;
    NSString *dir = [docs stringByAppendingPathComponent:GHLKSStr(kGHLKSCustomAvatarDirName)];
    return [dir stringByAppendingPathComponent:GHLKSStr(kGHLKSCustomAvatarFileName)];
}

// 读一张图并校验能解码（尺寸大于 0 才算有效，否则当损坏处理）。
static UIImage *GHLKSValidImageAtPath(NSString *path) {
    if (!path || [path length] == 0) return nil;
    NSData *data = [NSData dataWithContentsOfFile:path];
    if (!data || [data length] == 0) return nil;
    UIImage *image = [UIImage imageWithData:data];
    if (!image || image.size.width <= 0 || image.size.height <= 0) return nil;
    return image;
}

BOOL GHLKSHasCustomAvatar(void) {
    return GHLKSValidImageAtPath(GHLKSCustomAvatarPath()) != nil;
}

// 居中裁成正方形：短边等比铺满正方形、长边两端对称裁掉（方向自动正确，不拉伸变形）。
static UIImage *GHLKSCenterCroppedSquare(UIImage *image) {
    if (!image) return nil;
    CGFloat side = MIN(image.size.width, image.size.height);
    if (side <= 0) return nil;
    CGFloat k = side / MIN(image.size.width, image.size.height);
    CGSize drawSize = CGSizeMake(image.size.width * k, image.size.height * k);
    CGRect drawRect = CGRectMake((side - drawSize.width) / 2.0, (side - drawSize.height) / 2.0, drawSize.width, drawSize.height);
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(side, side), YES, 1.0);
    [image drawInRect:drawRect];
    UIImage *result = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return result ? result : image;
}

// 按比例缩放（保持宽高比，不拉伸；目标是长边不超过 maxDimension）。
static UIImage *GHLKSScaledToMaxDimension(UIImage *image, CGFloat maxDimension) {
    if (!image || maxDimension <= 0) return image;
    CGFloat longest = MAX(image.size.width, image.size.height);
    if (longest <= maxDimension) return image;
    CGFloat scale = maxDimension / longest;
    CGSize newSize = CGSizeMake(image.size.width * scale, image.size.height * scale);
    UIGraphicsBeginImageContextWithOptions(newSize, YES, 1.0);
    [image drawInRect:CGRectMake(0, 0, newSize.width, newSize.height)];
    UIImage *scaled = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return scaled ? scaled : image;
}

BOOL GHLSaveCustomAvatarImage(UIImage *image) {
    if (!image) return NO;
    NSString *path = GHLKSCustomAvatarPath();
    if (!path) return NO;
    NSFileManager *fm = [NSFileManager defaultManager];
    NSString *dir = [path stringByDeletingLastPathComponent];
    if (![fm fileExistsAtPath:dir]) {
        [fm createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:nil];
    }
    UIImage *square = GHLKSCenterCroppedSquare(image);
    UIImage *resized = GHLKSScaledToMaxDimension(square, 256);
    NSData *jpeg = UIImageJPEGRepresentation(resized, 0.88);
    if (!jpeg) return NO;
    return [jpeg writeToFile:path atomically:YES];
}

void GHLClearCustomAvatar(void) {
    NSString *path = GHLKSCustomAvatarPath();
    if (!path) return;
    [[NSFileManager defaultManager] removeItemAtPath:path error:nil];
}

NSString *GHLKSLogoImagePath(void) {
    // 自选头像优先（文件损坏时当没有，继续试默认图）。
    NSString *custom = GHLKSCustomAvatarPath();
    if (custom && GHLKSValidImageAtPath(custom)) return custom;
    static const char *candidates[] = {
        "/var/jb/Library/Application Support/GuHaiLongKuaishou/doraemon.png",
        "/Library/Application Support/GuHaiLongKuaishou/doraemon.png",
        NULL
    };
    NSFileManager *fm = [NSFileManager defaultManager];
    for (int i = 0; candidates[i]; i++) {
        NSString *p = GHLKSStr(candidates[i]);
        if ([fm fileExistsAtPath:p]) return p;
    }
    return nil;
}

NSString *GHLKSAppVersionString(void) {
    NSBundle *bundle = [NSBundle mainBundle];
    NSDictionary *info = [bundle infoDictionary];
    NSString *shortVer = [info objectForKey:GHLKSStr("CFBundleShortVersionString")];
    NSString *build = [info objectForKey:GHLKSStr("CFBundleVersion")];
    if (shortVer && build) {
        return [NSString stringWithFormat:GHLKSStr("%@ (%@)"), shortVer, build];
    }
    if (shortVer) return shortVer;
    char buf[64];
    snprintf(buf, sizeof(buf), "%s (%s)", kGHLKSTargetKuaishouVersion, kGHLKSTargetKuaishouBuild);
    return GHLKSStr(buf);
}

BOOL GHLKSPrefsBool(const char *key, BOOL defValue) {
    CFStringRef k = GHLKSCFStr(key);
    CFStringRef d = GHLKSCFStr(kGHLKSPrefsDomain);
    CFPropertyListRef v = CFPreferencesCopyValue(k, d, kCFPreferencesCurrentUser, kCFPreferencesAnyHost);
    BOOL r = defValue;
    if (v) {
        if (CFGetTypeID(v) == CFBooleanGetTypeID()) r = CFBooleanGetValue((CFBooleanRef)v);
        CFRelease(v);
    }
    if (k) CFRelease(k);
    if (d) CFRelease(d);
    return r;
}

void GHLKSPrefsSetBool(const char *key, BOOL value) {
    CFStringRef k = GHLKSCFStr(key);
    CFStringRef d = GHLKSCFStr(kGHLKSPrefsDomain);
    CFPreferencesSetValue(k, value ? kCFBooleanTrue : kCFBooleanFalse, d, kCFPreferencesCurrentUser, kCFPreferencesAnyHost);
    CFPreferencesSynchronize(d, kCFPreferencesCurrentUser, kCFPreferencesAnyHost);
    if (k) CFRelease(k);
    if (d) CFRelease(d);
}

double GHLKSPrefsDouble(const char *key, double defValue) {
    CFStringRef k = GHLKSCFStr(key);
    CFStringRef d = GHLKSCFStr(kGHLKSPrefsDomain);
    CFPropertyListRef v = CFPreferencesCopyValue(k, d, kCFPreferencesCurrentUser, kCFPreferencesAnyHost);
    double r = defValue;
    if (v) {
        if (CFGetTypeID(v) == CFNumberGetTypeID()) CFNumberGetValue((CFNumberRef)v, kCFNumberDoubleType, &r);
        CFRelease(v);
    }
    if (k) CFRelease(k);
    if (d) CFRelease(d);
    return r;
}

void GHLKSPrefsSetDouble(const char *key, double value) {
    CFStringRef k = GHLKSCFStr(key);
    CFStringRef d = GHLKSCFStr(kGHLKSPrefsDomain);
    CFNumberRef n = CFNumberCreate(NULL, kCFNumberDoubleType, &value);
    CFPreferencesSetValue(k, n, d, kCFPreferencesCurrentUser, kCFPreferencesAnyHost);
    CFPreferencesSynchronize(d, kCFPreferencesCurrentUser, kCFPreferencesAnyHost);
    if (n) CFRelease(n);
    if (k) CFRelease(k);
    if (d) CFRelease(d);
}

long GHLKSPrefsInteger(const char *key, long defValue) {
    CFStringRef k = GHLKSCFStr(key);
    CFStringRef d = GHLKSCFStr(kGHLKSPrefsDomain);
    CFPropertyListRef v = CFPreferencesCopyValue(k, d, kCFPreferencesCurrentUser, kCFPreferencesAnyHost);
    long r = defValue;
    if (v) {
        if (CFGetTypeID(v) == CFNumberGetTypeID()) CFNumberGetValue((CFNumberRef)v, kCFNumberLongType, &r);
        CFRelease(v);
    }
    if (k) CFRelease(k);
    if (d) CFRelease(d);
    return r;
}

void GHLKSPrefsSetInteger(const char *key, long value) {
    CFStringRef k = GHLKSCFStr(key);
    CFStringRef d = GHLKSCFStr(kGHLKSPrefsDomain);
    CFNumberRef n = CFNumberCreate(NULL, kCFNumberLongType, &value);
    CFPreferencesSetValue(k, n, d, kCFPreferencesCurrentUser, kCFPreferencesAnyHost);
    CFPreferencesSynchronize(d, kCFPreferencesCurrentUser, kCFPreferencesAnyHost);
    if (n) CFRelease(n);
    if (k) CFRelease(k);
    if (d) CFRelease(d);
}
