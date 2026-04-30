#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import <WebKit/WebKit.h>
#import <objc/runtime.h>
#import <substrate.h>

typedef NS_ENUM(NSUInteger, CHZZKRequestPolicy) {
    CHZZKRequestPolicyAllow = 0,
    CHZZKRequestPolicyStubAdPolling,
    CHZZKRequestPolicyBlock
};

static NSString *const kCHZZKAdPollingResponse = @"{\"hacked\":1,\"id\":null,\"event\":null,\"ts\":null,\"adCount\":null,\"adControlType\":\"STUDIO_CONTROL\"}";
static NSString *const kCHZZKAutoSkipScript =
@"(() => {"
"if (window.__chzzkShieldInstalled) return;"
"window.__chzzkShieldInstalled = true;"
"const fixed = { hacked: 1, id: null, event: null, ts: null, adCount: null, adControlType: 'STUDIO_CONTROL' };"
"const fixedText = JSON.stringify(fixed);"
"const isAdPolling = (url) => typeof url === 'string' && url.includes('/ad-polling/');"
"const clickSkip = () => {"
"  const selectors = [\"button[data-role='skipBtn']\", \"button[aria-label*='Skip']\", \"button[aria-label*='건너뛰기']\", \"button[class*='skip']\"];"
"  for (const s of selectors) {"
"    const btn = document.querySelector(s);"
"    if (!btn) continue;"
"    const style = window.getComputedStyle(btn);"
"    if (style && style.display === 'none') continue;"
"    btn.click();"
"  }"
"};"
"const originalFetch = window.fetch;"
"if (typeof originalFetch === 'function') {"
"  window.fetch = async function(input, init) {"
"    const url = typeof input === 'string' ? input : (input && input.url) || '';"
"    if (isAdPolling(url)) {"
"      return new Response(fixedText, { status: 200, headers: { 'Content-Type': 'application/json' } });"
"    }"
"    return originalFetch.call(this, input, init);"
"  };"
"}"
"const XHR = XMLHttpRequest && XMLHttpRequest.prototype;"
"if (XHR && !XHR.__chzzkShieldPatched) {"
"  XHR.__chzzkShieldPatched = true;"
"  const open = XHR.open;"
"  const send = XHR.send;"
"  XHR.open = function(method, url) { this.__chzzkShieldUrl = url; return open.apply(this, arguments); };"
"  XHR.send = function() {"
"    if (isAdPolling(this.__chzzkShieldUrl || '')) {"
"      try {"
"        Object.defineProperty(this, 'readyState', { configurable: true, get: () => 4 });"
"        Object.defineProperty(this, 'status', { configurable: true, get: () => 200 });"
"        Object.defineProperty(this, 'responseText', { configurable: true, get: () => fixedText });"
"        Object.defineProperty(this, 'response', { configurable: true, get: () => fixedText });"
"      } catch (e) {}"
"      try { this.dispatchEvent(new Event('readystatechange')); } catch (e) {}"
"      try { this.dispatchEvent(new Event('load')); } catch (e) {}"
"      try { this.dispatchEvent(new Event('loadend')); } catch (e) {}"
"      return;"
"    }"
"    return send.apply(this, arguments);"
"  };"
"}"
"clickSkip();"
"setInterval(clickSkip, 450);"
"new MutationObserver(clickSkip).observe(document.documentElement || document.body, { childList: true, subtree: true });"
"})();";

static NSString *const kCHZZKHandledKey = @"com.lemonflare.chzzkshield.handled";
static const void *kCHZZKScriptInstalledKey = &kCHZZKScriptInstalledKey;

@interface CHZZKAdBlockURLProtocol : NSURLProtocol
@end

static NSString *LowerString(NSString *value) {
    if (![value isKindOfClass:[NSString class]]) return @"";
    return value.lowercaseString;
}

static BOOL HasAnySuffix(NSString *value, NSArray<NSString *> *suffixes) {
    if (value.length == 0 || suffixes.count == 0) return NO;
    for (NSString *suffix in suffixes) {
        if (suffix.length == 0) continue;
        if ([value isEqualToString:suffix] || [value hasSuffix:[@"." stringByAppendingString:suffix]]) {
            return YES;
        }
    }
    return NO;
}

static BOOL ContainsAnyFragment(NSString *value, NSArray<NSString *> *fragments) {
    if (value.length == 0 || fragments.count == 0) return NO;
    for (NSString *fragment in fragments) {
        if (fragment.length == 0) continue;
        if ([value containsString:fragment]) return YES;
    }
    return NO;
}

static BOOL IsHTTPURL(NSURL *url) {
    if (![url isKindOfClass:[NSURL class]]) return NO;
    NSString *scheme = LowerString(url.scheme);
    return [scheme isEqualToString:@"http"] || [scheme isEqualToString:@"https"];
}

static BOOL IsAdPollingURL(NSURL *url) {
    NSString *absolute = LowerString(url.absoluteString);
    return [absolute containsString:@"/ad-polling/"] || [absolute containsString:@"ad-polling"];
}

static BOOL IsKnownAdHost(NSString *host) {
    return HasAnySuffix(host, @[
        @"veta.naver.com",
        @"adcr.naver.com",
        @"gfa.naver.com",
        @"doubleclick.net",
        @"googlesyndication.com",
        @"googleadservices.com",
        @"adservice.google.com"
    ]);
}

static BOOL IsNaverFamilyHost(NSString *host) {
    return HasAnySuffix(host, @[
        @"chzzk.naver.com",
        @"naver.com",
        @"navercorp.com",
        @"pstatic.net"
    ]);
}

static BOOL HasAdPathSignal(NSString *path) {
    if (path.length == 0) return NO;

    NSArray<NSString *> *segments = [path componentsSeparatedByString:@"/"];
    for (NSString *raw in segments) {
        NSString *segment = LowerString(raw);
        if (segment.length == 0) continue;

        if ([segment isEqualToString:@"ad"] || [segment isEqualToString:@"ads"]) return YES;
        if ([segment hasPrefix:@"ad-"] || [segment hasPrefix:@"ads-"]) return YES;
        if ([segment hasSuffix:@"-ad"] || [segment hasSuffix:@"-ads"]) return YES;
        if ([segment containsString:@"advert"] || [segment containsString:@"adpoll"]) return YES;
    }

    return NO;
}

static BOOL HasAdQuerySignal(NSString *query) {
    return ContainsAnyFragment(query, @[
        @"adid=",
        @"ad_id=",
        @"adunit=",
        @"ad_unit=",
        @"advert=",
        @"advertising="
    ]);
}

static CHZZKRequestPolicy RequestPolicyForURL(NSURL *url) {
    if (!IsHTTPURL(url)) return CHZZKRequestPolicyAllow;

    if (IsAdPollingURL(url)) return CHZZKRequestPolicyStubAdPolling;

    NSString *host = LowerString(url.host);
    NSString *path = LowerString(url.path);
    NSString *query = LowerString(url.query);
    NSString *absolute = LowerString(url.absoluteString);

    if (IsKnownAdHost(host)) return CHZZKRequestPolicyBlock;

    if (ContainsAnyFragment(absolute, @[
        @"doubleclick.net",
        @"googlesyndication.com",
        @"googleadservices.com",
        @"adservice.google.com"
    ])) {
        return CHZZKRequestPolicyBlock;
    }

    if (IsNaverFamilyHost(host) && (HasAdPathSignal(path) || HasAdQuerySignal(query))) {
        return CHZZKRequestPolicyBlock;
    }

    return CHZZKRequestPolicyAllow;
}

@implementation CHZZKAdBlockURLProtocol

+ (BOOL)canInitWithRequest:(NSURLRequest *)request {
    if (![request isKindOfClass:[NSURLRequest class]]) return NO;

    if ([NSURLProtocol propertyForKey:kCHZZKHandledKey inRequest:request]) {
        return NO;
    }

    CHZZKRequestPolicy policy = RequestPolicyForURL(request.URL);
    return policy != CHZZKRequestPolicyAllow;
}

+ (NSURLRequest *)canonicalRequestForRequest:(NSURLRequest *)request {
    return request;
}

- (void)startLoading {
    NSMutableURLRequest *markedRequest = [self.request mutableCopy];
    if (markedRequest) {
        [NSURLProtocol setProperty:@YES forKey:kCHZZKHandledKey inRequest:markedRequest];
    }

    NSURL *url = self.request.URL;
    CHZZKRequestPolicy policy = RequestPolicyForURL(url);

    if (policy == CHZZKRequestPolicyStubAdPolling) {
        NSData *data = [kCHZZKAdPollingResponse dataUsingEncoding:NSUTF8StringEncoding];
        NSDictionary<NSString *, NSString *> *headers = @{
            @"Content-Type": @"application/json; charset=utf-8",
            @"Cache-Control": @"no-store, no-cache"
        };

        NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:url
                                                                   statusCode:200
                                                                  HTTPVersion:@"HTTP/1.1"
                                                                 headerFields:headers];

        [self.client URLProtocol:self didReceiveResponse:response cacheStoragePolicy:NSURLCacheStorageNotAllowed];
        [self.client URLProtocol:self didLoadData:data];
        [self.client URLProtocolDidFinishLoading:self];
        NSLog(@"[CHZZKShield] Stubbed ad-polling response: %@", url.absoluteString);
        return;
    }

    NSDictionary *userInfo = url ? @{ NSURLErrorFailingURLErrorKey: url } : nil;
    NSError *error = [NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorCancelled userInfo:userInfo];
    [self.client URLProtocol:self didFailWithError:error];
    NSLog(@"[CHZZKShield] Blocked ad request: %@", url.absoluteString);
}

- (void)stopLoading {
}

@end

static void InstallProtocolClassIfNeeded(NSURLSessionConfiguration *configuration) {
    if (![configuration isKindOfClass:[NSURLSessionConfiguration class]]) return;

    NSArray *currentClasses = configuration.protocolClasses ?: @[];
    for (Class cls in currentClasses) {
        if (cls == [CHZZKAdBlockURLProtocol class]) {
            return;
        }
    }

    NSMutableArray *updated = [NSMutableArray arrayWithObject:[CHZZKAdBlockURLProtocol class]];
    [updated addObjectsFromArray:currentClasses];
    configuration.protocolClasses = updated;
}

static void InstallAutoSkipScriptIfNeeded(WKWebViewConfiguration *configuration) {
    if (![configuration isKindOfClass:[WKWebViewConfiguration class]]) return;

    @synchronized (configuration) {
        NSNumber *installed = objc_getAssociatedObject(configuration, kCHZZKScriptInstalledKey);
        if (installed.boolValue) return;

        WKUserContentController *controller = configuration.userContentController;
        if (!controller) {
            controller = [[WKUserContentController alloc] init];
            configuration.userContentController = controller;
        }

        WKUserScript *script = [[WKUserScript alloc] initWithSource:kCHZZKAutoSkipScript
                                                      injectionTime:WKUserScriptInjectionTimeAtDocumentEnd
                                                   forMainFrameOnly:NO];
        [controller addUserScript:script];
        objc_setAssociatedObject(configuration, kCHZZKScriptInstalledKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
}

static void BootstrapWebViewIfNeeded(WKWebView *webView) {
    if (![webView isKindOfClass:[WKWebView class]]) return;
    InstallAutoSkipScriptIfNeeded(webView.configuration);
    [webView evaluateJavaScript:kCHZZKAutoSkipScript completionHandler:nil];
}

%hook NSURLSessionConfiguration

+ (NSURLSessionConfiguration *)defaultSessionConfiguration {
    NSURLSessionConfiguration *configuration = %orig;
    InstallProtocolClassIfNeeded(configuration);
    return configuration;
}

+ (NSURLSessionConfiguration *)ephemeralSessionConfiguration {
    NSURLSessionConfiguration *configuration = %orig;
    InstallProtocolClassIfNeeded(configuration);
    return configuration;
}

+ (NSURLSessionConfiguration *)backgroundSessionConfigurationWithIdentifier:(NSString *)identifier {
    NSURLSessionConfiguration *configuration = %orig(identifier);
    InstallProtocolClassIfNeeded(configuration);
    return configuration;
}

+ (NSURLSessionConfiguration *)backgroundSessionConfiguration:(NSString *)identifier {
    NSURLSessionConfiguration *configuration = %orig(identifier);
    InstallProtocolClassIfNeeded(configuration);
    return configuration;
}

%end

%hook NSURLSession

+ (NSURLSession *)sessionWithConfiguration:(NSURLSessionConfiguration *)configuration {
    InstallProtocolClassIfNeeded(configuration);
    return %orig(configuration);
}

+ (NSURLSession *)sessionWithConfiguration:(NSURLSessionConfiguration *)configuration delegate:(id)delegate delegateQueue:(NSOperationQueue *)queue {
    InstallProtocolClassIfNeeded(configuration);
    return %orig(configuration, delegate, queue);
}

- (instancetype)initWithConfiguration:(NSURLSessionConfiguration *)configuration {
    InstallProtocolClassIfNeeded(configuration);
    return %orig(configuration);
}

- (instancetype)initWithConfiguration:(NSURLSessionConfiguration *)configuration delegate:(id)delegate delegateQueue:(NSOperationQueue *)queue {
    InstallProtocolClassIfNeeded(configuration);
    return %orig(configuration, delegate, queue);
}

%end

%hook WKWebView

- (instancetype)initWithFrame:(CGRect)frame configuration:(WKWebViewConfiguration *)configuration {
    InstallAutoSkipScriptIfNeeded(configuration);
    id instance = %orig(frame, configuration);
    BootstrapWebViewIfNeeded(instance);
    return instance;
}

- (instancetype)initWithCoder:(NSCoder *)coder {
    id instance = %orig(coder);
    BootstrapWebViewIfNeeded(instance);
    return instance;
}

- (WKNavigation *)loadRequest:(NSURLRequest *)request {
    BootstrapWebViewIfNeeded(self);
    return %orig(request);
}

- (WKNavigation *)loadHTMLString:(NSString *)string baseURL:(NSURL *)baseURL {
    BootstrapWebViewIfNeeded(self);
    return %orig(string, baseURL);
}

%end

%ctor {
    NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier] ?: @"(unknown)";
    NSLog(@"[CHZZKShield] Tweak loaded in bundle: %@", bundleID);
    [NSURLProtocol registerClass:[CHZZKAdBlockURLProtocol class]];
}
