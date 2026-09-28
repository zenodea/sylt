#import <Foundation/Foundation.h>
#import <QuartzCore/QuartzCore.h>
#import <mach-o/dyld.h>
#import <dlfcn.h>
#import <crt_externs.h>
#import <unistd.h>

typedef void (*MRGetInfoFn)(dispatch_queue_t, void (^)(NSDictionary *));
typedef void (*MRGetIsPlayingFn)(dispatch_queue_t, void (^)(Boolean));
typedef void (*MRGetClientFn)(dispatch_queue_t, void (^)(id));
typedef NSString *(*MRClientBundleFn)(id);
typedef void (*MRRegisterFn)(dispatch_queue_t);

static MRGetInfoFn getInfo;
static MRGetIsPlayingFn getIsPlaying;
static MRGetClientFn getClient;
static MRClientBundleFn clientBundle;
static MRRegisterFn registerForNotifications;

static NSUInteger lastArtworkHash;
static BOOL refreshPending;

static id valueOrNull(id value) { return value ?: NSNull.null; }

static void trace(NSString *format, ...) {
    static BOOL enabled;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ enabled = getenv("ADAPTER_TRACE") != NULL; });
    if (!enabled) return;
    va_list args;
    va_start(args, format);
    NSString *message = [[NSString alloc] initWithFormat:format arguments:args];
    va_end(args);
    fprintf(stderr, "[adapter %d] %s\n", getpid(), message.UTF8String);
}

static void emit(NSDictionary *payload) {
    NSData *json = [NSJSONSerialization dataWithJSONObject:payload options:0 error:nil];
    if (!json) return;
    fwrite(json.bytes, 1, json.length, stdout);
    fputc('\n', stdout);
    fflush(stdout);
}

static void publish(NSDictionary *info, Boolean playing, NSString *bundle) {
    NSMutableDictionary *out = [NSMutableDictionary dictionary];
    out[@"title"] = valueOrNull(info[@"kMRMediaRemoteNowPlayingInfoTitle"]);
    out[@"artist"] = valueOrNull(info[@"kMRMediaRemoteNowPlayingInfoArtist"]);
    out[@"album"] = valueOrNull(info[@"kMRMediaRemoteNowPlayingInfoAlbum"]);
    out[@"duration"] = valueOrNull(info[@"kMRMediaRemoteNowPlayingInfoDuration"]);
    out[@"elapsed"] = valueOrNull(info[@"kMRMediaRemoteNowPlayingInfoElapsedTime"]);
    out[@"rate"] = valueOrNull(info[@"kMRMediaRemoteNowPlayingInfoPlaybackRate"]);
    out[@"playing"] = playing ? @YES : @NO;
    out[@"bundle"] = valueOrNull(bundle);

    NSDate *timestamp = info[@"kMRMediaRemoteNowPlayingInfoTimestamp"];
    out[@"timestamp"] = timestamp ? @(timestamp.timeIntervalSince1970) : NSNull.null;

    NSData *artwork = info[@"kMRMediaRemoteNowPlayingInfoArtworkData"];
    NSUInteger hash = artwork ? artwork.hash : 0;
    out[@"artworkHash"] = @(hash);
    if (artwork && hash != lastArtworkHash) {
        out[@"artwork"] = [artwork base64EncodedStringWithOptions:0];
    }
    lastArtworkHash = hash;
    emit(out);
}

static NSDictionary *latestInfo;
static Boolean latestPlaying;
static NSString *latestBundle;
static BOOL emitPending;

static void emitSoon(void) {
    if (emitPending) return;
    emitPending = YES;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 50 * NSEC_PER_MSEC), dispatch_get_main_queue(), ^{
        emitPending = NO;
        publish(latestInfo ?: @{}, latestPlaying, latestBundle);
    });
}

static void refresh(void) {
    trace(@"refresh");
    refreshPending = NO;
    dispatch_queue_t queue = dispatch_get_main_queue();
    getInfo(queue, ^(NSDictionary *info) {
        trace(@"info: %lu keys", (unsigned long)info.count);
        latestInfo = info;
        emitSoon();
    });
    getIsPlaying(queue, ^(Boolean playing) {
        latestPlaying = playing;
        emitSoon();
    });
    getClient(queue, ^(id client) {
        NSString *bundle = client ? clientBundle(client) : nil;
        trace(@"client: %@", bundle);
        if (!bundle && latestBundle) latestInfo = nil;
        latestBundle = bundle;
        emitSoon();
    });
}

/// MediaRemote answers the metadata request only once per process when hosted
/// this way, so a change means replacing the process in place: same pid, same
/// pipes, fresh answer.
static BOOL relaunchPending;
static CFTimeInterval lastRelaunch;

static CFTimeInterval launchedAt;
static double relaunchInterval = 3;

static void relaunch(void) {
    trace(@"relaunch");
    relaunchPending = NO;
    lastRelaunch = CACurrentMediaTime();
    fflush(stdout);
    execv(_dyld_get_image_name(0), *_NSGetArgv());
}

static void scheduleRelaunch(void) {
    if (relaunchPending || CACurrentMediaTime() - launchedAt < 1.0) return;
    relaunchPending = YES;
    CFTimeInterval wait = MAX(0.15, 1.0 - (CACurrentMediaTime() - lastRelaunch));
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(wait * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{ relaunch(); });
}

static void scheduleRefresh(void) {
    if (refreshPending) return;
    refreshPending = YES;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 60 * NSEC_PER_MSEC), dispatch_get_main_queue(), ^{
        refresh();
    });
}

/// Only "refresh" is accepted. Playback commands are deliberately not routed
/// through MediaRemote: hosted this way they never get a reply and deadlock
/// the framework's notification queue.
static void handleCommand(NSString *line) {
    NSArray<NSString *> *parts = [line componentsSeparatedByString:@" "];
    if ([parts.firstObject isEqualToString:@"refresh"]) scheduleRefresh();
    else if ([parts.firstObject isEqualToString:@"interval"] && parts.count > 1) relaunchInterval = MAX(1, parts[1].doubleValue);
}

static void readCommands(void) {
    char *line = NULL;
    size_t capacity = 0;
    ssize_t length;
    while ((length = getline(&line, &capacity, stdin)) >= 0) {
        NSString *text = [[NSString alloc] initWithBytes:line length:(NSUInteger)length encoding:NSUTF8StringEncoding];
        text = [text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
        if (text.length == 0) continue;
        dispatch_async(dispatch_get_main_queue(), ^{ handleCommand(text); });
    }
    free(line);
    exit(0);
}

static BOOL loadMediaRemote(void) {
    void *handle = dlopen("/System/Library/PrivateFrameworks/MediaRemote.framework/MediaRemote", RTLD_NOW);
    if (!handle) return NO;
    getInfo = dlsym(handle, "MRMediaRemoteGetNowPlayingInfo");
    getIsPlaying = dlsym(handle, "MRMediaRemoteGetNowPlayingApplicationIsPlaying");
    getClient = dlsym(handle, "MRMediaRemoteGetNowPlayingClient");
    clientBundle = dlsym(handle, "MRNowPlayingClientGetBundleIdentifier");
    registerForNotifications = dlsym(handle, "MRMediaRemoteRegisterForNowPlayingNotifications");
    return getInfo && getIsPlaying && getClient && clientBundle && registerForNotifications;
}

__attribute__((constructor))
static void start(void) {
    launchedAt = CACurrentMediaTime();
    @autoreleasepool {
        if (!loadMediaRemote()) {
            emit(@{@"error": @"MediaRemote unavailable"});
            exit(1);
        }
        trace(@"start");
        registerForNotifications(dispatch_get_main_queue());
        NSArray *names = @[
            @"kMRMediaRemoteNowPlayingInfoDidChangeNotification",
            @"kMRMediaRemoteNowPlayingApplicationIsPlayingDidChangeNotification",
            @"kMRMediaRemoteNowPlayingApplicationDidChangeNotification",
        ];
        for (NSString *name in names) {
            [NSNotificationCenter.defaultCenter addObserverForName:name object:nil queue:NSOperationQueue.mainQueue
                                                        usingBlock:^(NSNotification *note) {
                trace(@"notification: %@", name);
                scheduleRefresh();
                scheduleRelaunch();
            }];
        }
        [NSThread detachNewThreadWithBlock:^{ readCommands(); }];
        [NSTimer scheduledTimerWithTimeInterval:1 repeats:YES block:^(NSTimer *timer) {
            if (CACurrentMediaTime() - launchedAt >= relaunchInterval) relaunch();
            else scheduleRefresh();
        }];
        refresh();
    }
    while (YES) {
        CFRunLoopRun();
    }
}
