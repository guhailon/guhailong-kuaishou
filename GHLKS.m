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

NSString *GHLKSDragonImagePath(void) {
    static const char *candidates[] = {
        "/var/jb/Library/Application Support/GuHaiLongKuaishou/dragon-head.jpg",
        "/Library/Application Support/GuHaiLongKuaishou/dragon-head.jpg",
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
