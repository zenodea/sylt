#import <Foundation/Foundation.h>
#import <dlfcn.h>

typedef void (*MRGetInfoFn)(dispatch_queue_t, void (^)(NSDictionary *));
typedef void (*MRGetIsPlayingFn)(dispatch_queue_t, void (^)(Boolean));
typedef void (*MRGetClientFn)(dispatch_queue_t, void (^)(id));
typedef NSString *(*MRClientBundleFn)(id);
typedef void (*MRRegisterFn)(dispatch_queue_t);
typedef Boolean (*MRSendCommandFn)(unsigned int, NSDictionary *);
typedef void (*MRSetElapsedFn)(double);

static MRGetInfoFn getInfo;
static MRGetIsPlayingFn getIsPlaying;
static MRGetClientFn getClient;
static MRClientBundleFn clientBundle;
static MRRegisterFn registerForNotifications;
static MRSendCommandFn sendCommand;
static MRSetElapsedFn setElapsed;

static NSUInteger lastArtworkHash;
static BOOL refreshPending;

static id valueOrNull(id value) { return value ?: NSNull.null; }

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

static NSUInteger generation;

static void refresh(void) {
    refreshPending = NO;
    NSUInteger current = ++generation;
    dispatch_queue_t queue = dispatch_get_main_queue();
    dispatch_group_t group = dispatch_group_create();
    __block NSDictionary *info = nil;
    __block Boolean playing = NO;
    __block NSString *bundle = nil;
    dispatch_group_enter(group);
    getInfo(queue, ^(NSDictionary *result) { info = result; dispatch_group_leave(group); });
    dispatch_group_enter(group);
    getIsPlaying(queue, ^(Boolean result) { playing = result; dispatch_group_leave(group); });
    dispatch_group_enter(group);
    getClient(queue, ^(id client) { bundle = client ? clientBundle(client) : nil; dispatch_group_leave(group); });

    __block BOOL published = NO;
    void (^publishOnce)(void) = ^{
        if (published || current != generation) return;
        published = YES;
        publish(info ?: @{}, playing, bundle);
    };
    dispatch_group_notify(group, queue, publishOnce);
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 2 * NSEC_PER_SEC), queue, ^{
        if (!published) publishOnce();
        dispatch_group_notify(group, queue, ^{
            if (current == generation) publish(info ?: @{}, playing, bundle);
        });
    });
}

static void scheduleRefresh(void) {
    if (refreshPending) return;
    refreshPending = YES;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 60 * NSEC_PER_MSEC), dispatch_get_main_queue(), ^{
        refresh();
    });
}

static void handleCommand(NSString *line) {
    NSArray<NSString *> *parts = [line componentsSeparatedByString:@" "];
    NSString *name = parts.firstObject;
    if ([name isEqualToString:@"play"]) sendCommand(0, nil);
    else if ([name isEqualToString:@"pause"]) sendCommand(1, nil);
    else if ([name isEqualToString:@"toggle"]) sendCommand(2, nil);
    else if ([name isEqualToString:@"next"]) sendCommand(4, nil);
    else if ([name isEqualToString:@"previous"]) sendCommand(5, nil);
    else if ([name isEqualToString:@"seek"] && parts.count > 1) setElapsed(parts[1].doubleValue);
    else if ([name isEqualToString:@"refresh"]) scheduleRefresh();
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
    sendCommand = dlsym(handle, "MRMediaRemoteSendCommand");
    setElapsed = dlsym(handle, "MRMediaRemoteSetElapsedTime");
    return getInfo && getIsPlaying && getClient && clientBundle && registerForNotifications && sendCommand && setElapsed;
}

__attribute__((constructor))
static void start(void) {
    @autoreleasepool {
        if (!loadMediaRemote()) {
            emit(@{@"error": @"MediaRemote unavailable"});
            exit(1);
        }
        registerForNotifications(dispatch_get_main_queue());
        NSArray *names = @[
            @"kMRMediaRemoteNowPlayingInfoDidChangeNotification",
            @"kMRMediaRemoteNowPlayingApplicationIsPlayingDidChangeNotification",
            @"kMRMediaRemoteNowPlayingApplicationDidChangeNotification",
        ];
        for (NSString *name in names) {
            [NSNotificationCenter.defaultCenter addObserverForName:name object:nil queue:NSOperationQueue.mainQueue
                                                        usingBlock:^(NSNotification *note) { scheduleRefresh(); }];
        }
        [NSThread detachNewThreadWithBlock:^{ readCommands(); }];
        refresh();
    }
    dispatch_main();
}
