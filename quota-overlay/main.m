#import <Cocoa/Cocoa.h>
#import <math.h>

static NSString * const QGProductName = @"Gauge for Codex";
static NSString * const QGPreviousBundleID = @"com.local.codexgauge";
static NSString * const QGLegacyBundleID = @"com.local.codex-quota-overlay";
static NSString * const QGLegacyPrefix = @"CodexQuotaOverlay";
static NSString * const QGWindowsKey = @"QuotaWindows";
static NSString * const QGLastSyncKey = @"LastSuccessfulSync";
static NSString * const QGDisplayModeKey = @"DisplayMode";

static NSString *QGL(NSString *key) {
    return [NSBundle.mainBundle localizedStringForKey:key value:key table:nil];
}

static NSNumber *QGNumber(id value) {
    if ([value isKindOfClass:NSNumber.class]) return value;
    if ([value isKindOfClass:NSString.class]) {
        NSScanner *scanner = [NSScanner scannerWithString:value];
        double number = 0;
        if ([scanner scanDouble:&number] && scanner.isAtEnd) return @(number);
    }
    return nil;
}

static BOOL QGIDEquals(id value, NSInteger expected) {
    NSNumber *number = QGNumber(value);
    return number && number.integerValue == expected;
}

static NSDictionary *QGNormalizedWindow(NSDictionary *dictionary, NSString *kind) {
    if (![dictionary isKindOfClass:NSDictionary.class]) return nil;
    NSNumber *usedNumber = QGNumber(dictionary[@"usedPercent"]);
    NSNumber *remainingNumber = QGNumber(dictionary[@"remainingPercent"]);
    if (!usedNumber && !remainingNumber) return nil;

    double used = usedNumber ? usedNumber.doubleValue : 100.0 - remainingNumber.doubleValue;
    if (!isfinite(used)) return nil;
    used = MIN(100.0, MAX(0.0, used));

    NSNumber *resetNumber = QGNumber(dictionary[@"resetsAt"]);
    if (!resetNumber) resetNumber = QGNumber(dictionary[@"resetAt"]);
    if (!resetNumber) resetNumber = QGNumber(dictionary[@"resets_at"]);
    NSTimeInterval resetAt = resetNumber.doubleValue;
    if (resetAt > 100000000000.0) resetAt /= 1000.0;

    NSNumber *durationNumber = QGNumber(dictionary[@"windowDurationMins"]);
    if (!durationNumber) durationNumber = QGNumber(dictionary[@"windowDurationMinutes"]);
    double durationMinutes = MAX(0.0, durationNumber.doubleValue);
    NSNumber *durationSeconds = QGNumber(dictionary[@"windowDurationSeconds"]);
    if (!durationMinutes && durationSeconds) durationMinutes = MAX(0.0, durationSeconds.doubleValue / 60.0);

    return @{
        @"usedPercent": @(used),
        @"remainingPercent": @(100.0 - used),
        @"resetsAt": @(MAX(0.0, resetAt)),
        @"windowDurationMins": @(durationMinutes),
        @"kind": kind ?: @"primary"
    };
}

static NSArray<NSDictionary *> *QGWindowsFromBucket(NSDictionary *bucket) {
    if (![bucket isKindOfClass:NSDictionary.class]) return @[];
    NSMutableArray<NSDictionary *> *windows = [NSMutableArray array];
    NSDictionary *primary = QGNormalizedWindow(bucket[@"primary"], @"primary");
    NSDictionary *secondary = QGNormalizedWindow(bucket[@"secondary"], @"secondary");
    if (primary) [windows addObject:primary];
    if (secondary) [windows addObject:secondary];
    if (windows.count) return windows;

    NSDictionary *direct = QGNormalizedWindow(bucket, @"primary");
    if (direct) return @[direct];

    for (NSString *key in @[@"rateLimit", @"rateLimits", @"limit"]) {
        NSArray<NSDictionary *> *nested = QGWindowsFromBucket(bucket[key]);
        if (nested.count) return nested;
    }
    return @[];
}

static NSDictionary *QGQuotaFromBucket(NSDictionary *bucket, NSString *bucketName) {
    NSArray<NSDictionary *> *windows = QGWindowsFromBucket(bucket);
    if (!windows.count) return nil;
    NSDictionary *selected = windows.firstObject;
    for (NSDictionary *window in windows) {
        if ([window[@"remainingPercent"] doubleValue] < [selected[@"remainingPercent"] doubleValue]) selected = window;
    }
    return @{
        @"windows": windows,
        @"selected": selected,
        @"remainingPercent": selected[@"remainingPercent"],
        @"resetsAt": selected[@"resetsAt"],
        @"bucket": bucketName ?: @"Codex"
    };
}

static NSArray<NSString *> *QGSortedStringKeys(NSDictionary *dictionary) {
    NSMutableArray<NSString *> *keys = [NSMutableArray array];
    for (id key in dictionary) if ([key isKindOfClass:NSString.class]) [keys addObject:key];
    [keys sortUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
    return keys;
}

static NSDictionary *QGQuotaFromResult(NSDictionary *result) {
    if (![result isKindOfClass:NSDictionary.class]) return nil;
    NSDictionary *byID = result[@"rateLimitsByLimitId"];
    if ([byID isKindOfClass:NSDictionary.class]) {
        NSArray<NSString *> *keys = QGSortedStringKeys(byID);
        NSMutableArray<NSString *> *ordered = [NSMutableArray array];
        if ([byID[@"codex"] isKindOfClass:NSDictionary.class]) [ordered addObject:@"codex"];
        for (NSString *key in keys) {
            if (![ordered containsObject:key] && [key caseInsensitiveCompare:@"codex"] == NSOrderedSame) [ordered addObject:key];
        }
        for (NSString *key in keys) {
            if (![ordered containsObject:key] && [key rangeOfString:@"codex" options:NSCaseInsensitiveSearch].location != NSNotFound) {
                [ordered addObject:key];
            }
        }
        for (NSString *key in keys) if (![ordered containsObject:key]) [ordered addObject:key];
        for (NSString *key in ordered) {
            NSDictionary *quota = QGQuotaFromBucket(byID[key], key);
            if (quota) return quota;
        }
    }

    NSDictionary *legacy = QGQuotaFromBucket(result[@"rateLimits"], @"Codex");
    if (legacy) return legacy;
    return QGQuotaFromBucket(result, @"Codex");
}

static BOOL QGRunSelfTests(void) {
    NSArray<NSDictionary *> *cases = @[
        @{
            @"name": @"prefers exact codex bucket",
            @"input": @{@"rateLimitsByLimitId": @{
                @"alpha": @{@"primary": @{@"usedPercent": @91, @"resetsAt": @1000}},
                @"codex": @{@"primary": @{@"usedPercent": @23, @"resetsAt": @2000}}
            }},
            @"remaining": @77, @"reset": @2000, @"windowCount": @1
        },
        @{
            @"name": @"supports remaining percent and nested rateLimit",
            @"input": @{@"rateLimitsByLimitId": @{
                @"Codex-General": @{@"rateLimit": @{@"primary": @{@"remainingPercent": @62, @"resetAt": @3000}}}
            }},
            @"remaining": @62, @"reset": @3000, @"windowCount": @1
        },
        @{
            @"name": @"supports legacy rateLimits",
            @"input": @{@"rateLimits": @{@"remainingPercent": @1, @"primary": @{@"usedPercent": @7, @"resetsAt": @4000}}},
            @"remaining": @93, @"reset": @4000, @"windowCount": @1
        },
        @{
            @"name": @"converts millisecond reset epoch",
            @"input": @{@"rateLimitsByLimitId": @{@"codex": @{@"primary": @{@"usedPercent": @50, @"resetsAt": @2000000000000LL}}}},
            @"remaining": @50, @"reset": @2000000000, @"windowCount": @1
        },
        @{
            @"name": @"selects the most constrained window",
            @"input": @{@"rateLimitsByLimitId": @{@"codex": @{
                @"primary": @{@"usedPercent": @10, @"resetsAt": @5000, @"windowDurationMins": @10080},
                @"secondary": @{@"usedPercent": @84, @"resetsAt": @6000, @"windowDurationMins": @300}
            }}},
            @"remaining": @16, @"reset": @6000, @"windowCount": @2
        }
    ];

    NSUInteger failures = 0;
    for (NSDictionary *test in cases) {
        NSDictionary *quota = QGQuotaFromResult(test[@"input"]);
        BOOL passed = quota
            && fabs([quota[@"remainingPercent"] doubleValue] - [test[@"remaining"] doubleValue]) < 0.001
            && fabs([quota[@"resetsAt"] doubleValue] - [test[@"reset"] doubleValue]) < 0.001
            && [quota[@"windows"] count] == [test[@"windowCount"] unsignedIntegerValue];
        fprintf(stdout, "%s %s\n", passed ? "PASS" : "FAIL", [test[@"name"] UTF8String]);
        if (!passed) failures++;
    }
    BOOL localizationPassed = ![QGL(@"menu.refresh") isEqualToString:@"menu.refresh"];
    fprintf(stdout, "%s localization resources\n", localizationPassed ? "PASS" : "FAIL");
    if (!localizationPassed) failures++;
    fprintf(stdout, "%lu tests, %lu failures\n", (unsigned long)(cases.count + 1), (unsigned long)failures);
    return failures == 0;
}

typedef NS_ENUM(NSInteger, QGSyncState) {
    QGSyncStateIdle,
    QGSyncStateSyncing,
    QGSyncStateSuccess,
    QGSyncStateFailed
};

typedef NS_ENUM(NSInteger, QGDisplayMode) {
    QGDisplayModeFull,
    QGDisplayModeCompact
};

@interface QGStatusContentView : NSView
@property (copy, nonatomic) NSString *displayText;
@property (nonatomic) double remainingPercent;
@property (nonatomic) BOOL hasQuota;
@property (nonatomic) BOOL showProgress;
@property (nonatomic) BOOL stale;
@end

@implementation QGStatusContentView
- (BOOL)isFlipped { return YES; }
- (NSView *)hitTest:(NSPoint)point { (void)point; return nil; }
- (void)setDisplayText:(NSString *)displayText { _displayText = [displayText copy]; [self setNeedsDisplay:YES]; }
- (void)setRemainingPercent:(double)value { _remainingPercent = MIN(100.0, MAX(0.0, value)); [self setNeedsDisplay:YES]; }
- (void)setHasQuota:(BOOL)value { _hasQuota = value; [self setNeedsDisplay:YES]; }
- (void)setShowProgress:(BOOL)value { _showProgress = value; [self setNeedsDisplay:YES]; }
- (void)setStale:(BOOL)value { _stale = value; [self setNeedsDisplay:YES]; }
- (void)viewDidChangeEffectiveAppearance { [super viewDidChangeEffectiveAppearance]; [self setNeedsDisplay:YES]; }
- (NSColor *)statusTextColor {
    NSAppearanceName match = [self.effectiveAppearance bestMatchFromAppearancesWithNames:@[
        NSAppearanceNameAqua, NSAppearanceNameDarkAqua,
        NSAppearanceNameVibrantLight, NSAppearanceNameVibrantDark
    ]];
    BOOL dark = [match isEqualToString:NSAppearanceNameDarkAqua] || [match isEqualToString:NSAppearanceNameVibrantDark];
    return dark ? NSColor.whiteColor : NSColor.blackColor;
}
- (void)drawRect:(NSRect)dirtyRect {
    (void)dirtyRect;
    NSString *text = _displayText.length ? _displayText : @"--";
    NSColor *textColor = self.statusTextColor;
    NSDictionary *attributes = @{
        NSFontAttributeName: [NSFont monospacedDigitSystemFontOfSize:14.5 weight:NSFontWeightSemibold],
        NSForegroundColorAttributeName: textColor
    };
    NSSize textSize = [text sizeWithAttributes:attributes];
    CGFloat textAreaHeight = NSHeight(self.bounds) - (_showProgress ? 4.5 : 0.0);
    CGFloat textX = floor((NSWidth(self.bounds) - textSize.width) / 2.0);
    CGFloat textY = floor((textAreaHeight - textSize.height) / 2.0) - 0.5;
    [text drawAtPoint:NSMakePoint(textX, textY) withAttributes:attributes];
    if (!_showProgress) return;

    NSRect track = NSMakeRect(5.0, NSHeight(self.bounds) - 3.5, MAX(0.0, NSWidth(self.bounds) - 10.0), 2.5);
    [[textColor colorWithAlphaComponent:0.22] setFill];
    [[NSBezierPath bezierPathWithRoundedRect:track xRadius:1.25 yRadius:1.25] fill];
    if (!_hasQuota || _remainingPercent <= 0) return;
    NSColor *fillColor = _stale ? NSColor.systemGrayColor :
        (_remainingPercent <= 20 ? NSColor.systemRedColor :
         (_remainingPercent <= 40 ? NSColor.systemOrangeColor : NSColor.systemGreenColor));
    [fillColor setFill];
    CGFloat fillWidth = MAX(3.0, NSWidth(track) * _remainingPercent / 100.0);
    NSRect fill = NSMakeRect(NSMinX(track), NSMinY(track), MIN(NSWidth(track), fillWidth), NSHeight(track));
    [[NSBezierPath bezierPathWithRoundedRect:fill xRadius:1.25 yRadius:1.25] fill];
}
@end

@interface QGAppDelegate : NSObject <NSApplicationDelegate, NSMenuDelegate>
@property NSStatusItem *statusItem;
@property QGStatusContentView *statusContentView;
@property NSMenu *statusMenu;
@property NSMenuItem *summaryMenuItem;
@property NSArray<NSMenuItem *> *windowMenuItems;
@property NSMenuItem *resetMenuItem;
@property NSMenuItem *syncStateMenuItem;
@property NSMenuItem *refreshMenuItem;
@property NSMenuItem *manualMenuItem;
@property NSMenuItem *displayMenuItem;
@property NSMenuItem *fullModeMenuItem;
@property NSMenuItem *compactModeMenuItem;
@property NSMenuItem *aboutMenuItem;
@property NSMenuItem *quitMenuItem;
@property NSTimer *syncTimer;
@property NSTimer *displayTimer;
@property NSArray<NSDictionary *> *quotaWindows;
@property NSDictionary *selectedWindow;
@property QGSyncState syncState;
@property QGDisplayMode displayMode;
@property BOOL syncInProgress;
@property NSDate *lastSuccessfulSync;
@property NSString *syncDetail;
@property NSString *lastError;
@end

@implementation QGAppDelegate
- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    (void)notification;
    [NSApp setActivationPolicy:NSApplicationActivationPolicyAccessory];
    [self restoreCachedQuota];

    _statusItem = [NSStatusBar.systemStatusBar statusItemWithLength:56.0];
    _statusItem.autosaveName = @"CodexGaugeStatusItem";
    _statusItem.button.image = nil;
    _statusItem.button.title = @"";
    _statusContentView = [[QGStatusContentView alloc] initWithFrame:_statusItem.button.bounds];
    _statusContentView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    [_statusItem.button addSubview:_statusContentView];
    _statusMenu = [self makeMenu];
    _statusItem.menu = _statusMenu;
    [self updateStatusItem];

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(localeOrTimeZoneChanged:)
                                                 name:NSCurrentLocaleDidChangeNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(localeOrTimeZoneChanged:)
                                                 name:NSSystemTimeZoneDidChangeNotification object:nil];
    [NSWorkspace.sharedWorkspace.notificationCenter addObserver:self selector:@selector(workspaceDidWake:)
                                                            name:NSWorkspaceDidWakeNotification object:nil];

    __weak QGAppDelegate *weakSelf = self;
    _syncTimer = [NSTimer timerWithTimeInterval:60.0 repeats:YES block:^(NSTimer *timer) {
        (void)timer;
        [weakSelf refreshQuota:nil];
    }];
    _syncTimer.tolerance = 5.0;
    [NSRunLoop.mainRunLoop addTimer:_syncTimer forMode:NSRunLoopCommonModes];
    _displayTimer = [NSTimer timerWithTimeInterval:30.0 repeats:YES block:^(NSTimer *timer) {
        (void)timer;
        [weakSelf displayTimerFired];
    }];
    _displayTimer.tolerance = 3.0;
    [NSRunLoop.mainRunLoop addTimer:_displayTimer forMode:NSRunLoopCommonModes];
    [self refreshQuota:nil];
}

- (void)applicationWillTerminate:(NSNotification *)notification {
    (void)notification;
    [_syncTimer invalidate];
    [_displayTimer invalidate];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [NSWorkspace.sharedWorkspace.notificationCenter removeObserver:self];
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender { (void)sender; return NO; }

- (NSMenu *)makeMenu {
    NSMenu *menu = [NSMenu new];
    menu.delegate = self;
    _summaryMenuItem = [menu addItemWithTitle:QGProductName action:nil keyEquivalent:@""];
    _summaryMenuItem.enabled = NO;
    NSMutableArray<NSMenuItem *> *windowItems = [NSMutableArray array];
    for (NSInteger index = 0; index < 3; index++) {
        NSMenuItem *item = [menu addItemWithTitle:@"" action:nil keyEquivalent:@""];
        item.enabled = NO;
        item.hidden = YES;
        [windowItems addObject:item];
    }
    _windowMenuItems = windowItems;
    _resetMenuItem = [menu addItemWithTitle:@"" action:nil keyEquivalent:@""];
    _resetMenuItem.enabled = NO;
    _syncStateMenuItem = [menu addItemWithTitle:@"" action:nil keyEquivalent:@""];
    _syncStateMenuItem.enabled = NO;
    [menu addItem:NSMenuItem.separatorItem];

    _refreshMenuItem = [menu addItemWithTitle:@"" action:@selector(refreshQuota:) keyEquivalent:@"r"];
    _refreshMenuItem.target = self;
    _displayMenuItem = [menu addItemWithTitle:@"" action:nil keyEquivalent:@""];
    NSMenu *displayMenu = [NSMenu new];
    _fullModeMenuItem = [displayMenu addItemWithTitle:@"" action:@selector(changeDisplayMode:) keyEquivalent:@""];
    _fullModeMenuItem.target = self;
    _fullModeMenuItem.tag = QGDisplayModeFull;
    _compactModeMenuItem = [displayMenu addItemWithTitle:@"" action:@selector(changeDisplayMode:) keyEquivalent:@""];
    _compactModeMenuItem.target = self;
    _compactModeMenuItem.tag = QGDisplayModeCompact;
    _displayMenuItem.submenu = displayMenu;
    _manualMenuItem = [menu addItemWithTitle:@"" action:@selector(editQuota:) keyEquivalent:@""];
    _manualMenuItem.target = self;
    [menu addItem:NSMenuItem.separatorItem];
    _aboutMenuItem = [menu addItemWithTitle:@"" action:@selector(showAbout:) keyEquivalent:@""];
    _aboutMenuItem.target = self;
    _quitMenuItem = [menu addItemWithTitle:@"" action:@selector(terminate:) keyEquivalent:@"q"];
    _quitMenuItem.target = NSApp;
    return menu;
}

- (void)menuWillOpen:(NSMenu *)menu {
    (void)menu;
    [self updateStatusItem];
    NSTimeInterval age = _lastSuccessfulSync ? -_lastSuccessfulSync.timeIntervalSinceNow : DBL_MAX;
    if (!_syncInProgress && age > 60.0) [self refreshQuota:nil];
}

- (void)localeOrTimeZoneChanged:(NSNotification *)notification {
    (void)notification;
    [self updateStatusItem];
}

- (void)workspaceDidWake:(NSNotification *)notification {
    (void)notification;
    [self refreshQuota:nil];
}

- (void)displayTimerFired {
    [self updateStatusItem];
    NSTimeInterval resetAt = [_selectedWindow[@"resetsAt"] doubleValue];
    if (resetAt > 0 && resetAt <= NSDate.date.timeIntervalSince1970 && !_syncInProgress) {
        NSTimeInterval age = _lastSuccessfulSync ? -_lastSuccessfulSync.timeIntervalSinceNow : DBL_MAX;
        if (age > 20.0) [self refreshQuota:nil];
    }
}

- (NSString *)percentageString:(double)remaining {
    NSNumberFormatter *formatter = [NSNumberFormatter new];
    formatter.numberStyle = NSNumberFormatterPercentStyle;
    formatter.minimumFractionDigits = 0;
    formatter.maximumFractionDigits = 0;
    return [formatter stringFromNumber:@(remaining / 100.0)] ?: [NSString stringWithFormat:@"%.0f%%", remaining];
}

- (NSString *)relativeDuration:(NSTimeInterval)seconds maximumUnits:(NSInteger)maximumUnits {
    NSDateComponentsFormatter *formatter = [NSDateComponentsFormatter new];
    formatter.unitsStyle = NSDateComponentsFormatterUnitsStyleAbbreviated;
    formatter.maximumUnitCount = maximumUnits;
    formatter.zeroFormattingBehavior = NSDateComponentsFormatterZeroFormattingBehaviorDropAll;
    if (seconds >= 86400.0) formatter.allowedUnits = NSCalendarUnitDay | NSCalendarUnitHour;
    else if (seconds >= 3600.0) formatter.allowedUnits = NSCalendarUnitHour | NSCalendarUnitMinute;
    else formatter.allowedUnits = NSCalendarUnitMinute;
    return [formatter stringFromTimeInterval:MAX(60.0, seconds)] ?: @"";
}

- (NSString *)exactResetTextForWindow:(NSDictionary *)window {
    NSTimeInterval resetAt = [window[@"resetsAt"] doubleValue];
    if (resetAt <= 0) return QGL(@"quota.resetUnknown");
    NSDateFormatter *formatter = [NSDateFormatter new];
    formatter.locale = NSLocale.currentLocale;
    formatter.timeZone = NSTimeZone.localTimeZone;
    formatter.dateStyle = NSDateFormatterMediumStyle;
    formatter.timeStyle = NSDateFormatterShortStyle;
    return [formatter stringFromDate:[NSDate dateWithTimeIntervalSince1970:resetAt]];
}

- (NSString *)resetDescriptionForWindow:(NSDictionary *)window {
    NSTimeInterval resetAt = [window[@"resetsAt"] doubleValue];
    if (resetAt <= 0) return QGL(@"quota.resetUnknown");
    NSTimeInterval remaining = resetAt - NSDate.date.timeIntervalSince1970;
    if (remaining <= 0) return QGL(@"quota.awaitingRefresh");
    return [NSString stringWithFormat:QGL(@"quota.resetIn"),
            [self relativeDuration:remaining maximumUnits:2], [self exactResetTextForWindow:window]];
}

- (NSString *)windowLabel:(NSDictionary *)window {
    double minutes = [window[@"windowDurationMins"] doubleValue];
    if (minutes > 0) return [self relativeDuration:minutes * 60.0 maximumUnits:1];
    NSString *kind = window[@"kind"];
    return [kind isEqualToString:@"secondary"] ? QGL(@"quota.secondaryWindow") : QGL(@"quota.primaryWindow");
}

- (BOOL)dataIsStale {
    return !_lastSuccessfulSync || -_lastSuccessfulSync.timeIntervalSinceNow > 300.0;
}

- (NSString *)freshnessText {
    if (_syncState == QGSyncStateSyncing) return QGL(@"sync.syncing");
    NSString *ageText = nil;
    if (_lastSuccessfulSync) {
        NSTimeInterval age = MAX(0.0, -_lastSuccessfulSync.timeIntervalSinceNow);
        ageText = age < 75.0 ? QGL(@"sync.justNow") :
            [NSString stringWithFormat:QGL(@"sync.ago"), [self relativeDuration:age maximumUnits:1]];
    }
    if (_syncState == QGSyncStateFailed) {
        NSString *failure = _lastError.length ? _lastError : QGL(@"sync.failed");
        return ageText.length ? [NSString stringWithFormat:QGL(@"sync.failedWithLastUpdate"), failure, ageText] : failure;
    }
    if (!_lastSuccessfulSync) return _syncDetail.length ? _syncDetail : QGL(@"sync.waiting");
    if (self.dataIsStale) return [NSString stringWithFormat:QGL(@"sync.stale"), ageText];
    return ageText;
}

- (void)updateStatusItem {
    BOOL hasQuota = _selectedWindow != nil;
    double remaining = hasQuota ? [_selectedWindow[@"remainingPercent"] doubleValue] : 0.0;
    NSString *percent = hasQuota ? [self percentageString:remaining] : @"--";
    NSDictionary *statusTextAttributes = @{
        NSFontAttributeName: [NSFont monospacedDigitSystemFontOfSize:14.5 weight:NSFontWeightSemibold]
    };
    CGFloat measuredWidth = ceil([percent sizeWithAttributes:statusTextAttributes].width);
    CGFloat minimumWidth = _displayMode == QGDisplayModeCompact ? 46.0 : 56.0;
    _statusItem.length = MAX(minimumWidth, measuredWidth + 14.0);
    _statusContentView.displayText = percent;
    _statusContentView.hasQuota = hasQuota;
    _statusContentView.remainingPercent = remaining;
    _statusContentView.showProgress = _displayMode == QGDisplayModeFull;
    _statusContentView.stale = self.dataIsStale || _syncState == QGSyncStateFailed;

    _summaryMenuItem.title = hasQuota
        ? [NSString stringWithFormat:QGL(@"menu.summary"), QGProductName, percent]
        : [NSString stringWithFormat:QGL(@"menu.summaryUnknown"), QGProductName];
    for (NSUInteger index = 0; index < _windowMenuItems.count; index++) {
        NSMenuItem *item = _windowMenuItems[index];
        if (index < _quotaWindows.count) {
            NSDictionary *window = _quotaWindows[index];
            item.hidden = NO;
            item.title = [NSString stringWithFormat:QGL(@"menu.window"), [self windowLabel:window],
                          [self percentageString:[window[@"remainingPercent"] doubleValue]]];
        } else {
            item.hidden = YES;
        }
    }
    _resetMenuItem.title = hasQuota ? [self resetDescriptionForWindow:_selectedWindow] : QGL(@"quota.resetUnknown");
    _syncStateMenuItem.title = [self freshnessText];
    _refreshMenuItem.title = QGL(@"menu.refresh");
    _manualMenuItem.title = QGL(@"menu.manual");
    _displayMenuItem.title = QGL(@"menu.display");
    _fullModeMenuItem.title = QGL(@"menu.displayFull");
    _compactModeMenuItem.title = QGL(@"menu.displayCompact");
    _fullModeMenuItem.state = _displayMode == QGDisplayModeFull ? NSControlStateValueOn : NSControlStateValueOff;
    _compactModeMenuItem.state = _displayMode == QGDisplayModeCompact ? NSControlStateValueOn : NSControlStateValueOff;
    _aboutMenuItem.title = [NSString stringWithFormat:QGL(@"menu.about"), QGProductName];
    _quitMenuItem.title = [NSString stringWithFormat:QGL(@"menu.quit"), QGProductName];

    NSString *reset = hasQuota ? [self resetDescriptionForWindow:_selectedWindow] : QGL(@"quota.resetUnknown");
    _statusItem.button.toolTip = [NSString stringWithFormat:@"%@ · %@ · %@", QGProductName, percent, reset];
    [_statusItem.button setAccessibilityLabel:[NSString stringWithFormat:QGL(@"accessibility.menu"), QGProductName]];
    [_statusItem.button setAccessibilityValue:[NSString stringWithFormat:QGL(@"accessibility.value"), percent, reset, self.freshnessText]];
}

- (void)changeDisplayMode:(NSMenuItem *)sender {
    _displayMode = (QGDisplayMode)sender.tag;
    [NSUserDefaults.standardUserDefaults setInteger:_displayMode forKey:QGDisplayModeKey];
    [self updateStatusItem];
}

- (void)migrateLegacyDefaultsIfNeeded {
    NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
    if ([defaults objectForKey:QGWindowsKey]) return;

    NSDictionary *previous = [defaults persistentDomainForName:QGPreviousBundleID];
    NSArray *previousWindows = previous[QGWindowsKey];
    if ([previousWindows isKindOfClass:NSArray.class] && previousWindows.count) {
        [defaults setObject:previousWindows forKey:QGWindowsKey];
        NSNumber *lastSync = QGNumber(previous[QGLastSyncKey]);
        if (lastSync) [defaults setDouble:lastSync.doubleValue forKey:QGLastSyncKey];
        NSNumber *displayMode = QGNumber(previous[QGDisplayModeKey]);
        if (displayMode) [defaults setInteger:displayMode.integerValue forKey:QGDisplayModeKey];
        return;
    }

    NSDictionary *legacy = [defaults persistentDomainForName:QGLegacyBundleID];
    NSNumber *remaining = legacy[[QGLegacyPrefix stringByAppendingString:@"Remaining"]];
    if (![remaining isKindOfClass:NSNumber.class]) return;
    NSNumber *reset = legacy[[QGLegacyPrefix stringByAppendingString:@"ResetsAt"]] ?: @0;
    NSDictionary *window = @{
        @"usedPercent": @(100.0 - remaining.doubleValue),
        @"remainingPercent": remaining,
        @"resetsAt": reset,
        @"windowDurationMins": @0,
        @"kind": @"primary"
    };
    [defaults setObject:@[window] forKey:QGWindowsKey];
    NSNumber *lastSync = legacy[[QGLegacyPrefix stringByAppendingString:@"LastSuccessfulSync"]];
    if ([lastSync isKindOfClass:NSNumber.class]) [defaults setDouble:lastSync.doubleValue forKey:QGLastSyncKey];
}

- (void)restoreCachedQuota {
    [self migrateLegacyDefaultsIfNeeded];
    NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
    NSArray *stored = [defaults arrayForKey:QGWindowsKey];
    NSMutableArray<NSDictionary *> *valid = [NSMutableArray array];
    for (id item in stored) {
        if (![item isKindOfClass:NSDictionary.class]) continue;
        NSString *kind = [item[@"kind"] isKindOfClass:NSString.class] ? item[@"kind"] : @"primary";
        NSDictionary *window = QGNormalizedWindow(item, kind);
        if (window) [valid addObject:window];
    }
    if (valid.count) [self applyWindows:valid];
    NSTimeInterval lastSync = [defaults doubleForKey:QGLastSyncKey];
    if (lastSync > 0) _lastSuccessfulSync = [NSDate dateWithTimeIntervalSince1970:lastSync];
    NSInteger mode = [defaults integerForKey:QGDisplayModeKey];
    _displayMode = mode == QGDisplayModeCompact ? QGDisplayModeCompact : QGDisplayModeFull;
    _syncState = QGSyncStateIdle;
    if (valid.count) _syncDetail = QGL(@"sync.cached");
}

- (void)applyWindows:(NSArray<NSDictionary *> *)windows {
    _quotaWindows = [windows copy];
    _selectedWindow = _quotaWindows.firstObject;
    for (NSDictionary *window in _quotaWindows) {
        if ([window[@"remainingPercent"] doubleValue] < [_selectedWindow[@"remainingPercent"] doubleValue]) _selectedWindow = window;
    }
}

- (void)saveQuotaWindows:(NSArray<NSDictionary *> *)windows {
    [NSUserDefaults.standardUserDefaults setObject:windows forKey:QGWindowsKey];
}

- (NSArray<NSString *> *)codexBinaryCandidates {
    NSMutableArray<NSString *> *paths = [NSMutableArray array];
    for (NSString *bundleID in @[@"com.openai.codex", @"com.openai.chatgpt"]) {
        NSURL *appURL = [NSWorkspace.sharedWorkspace URLForApplicationWithBundleIdentifier:bundleID];
        if (appURL) [paths addObject:[[appURL path] stringByAppendingPathComponent:@"Contents/Resources/codex"]];
    }
    NSString *userApplications = [NSHomeDirectory() stringByAppendingPathComponent:@"Applications"];
    [paths addObjectsFromArray:@[
        @"/Applications/Codex.app/Contents/Resources/codex",
        @"/Applications/ChatGPT.app/Contents/Resources/codex",
        [userApplications stringByAppendingPathComponent:@"Codex.app/Contents/Resources/codex"],
        [userApplications stringByAppendingPathComponent:@"ChatGPT.app/Contents/Resources/codex"],
        @"/opt/homebrew/bin/codex",
        @"/usr/local/bin/codex",
        [NSHomeDirectory() stringByAppendingPathComponent:@".local/bin/codex"],
        [NSHomeDirectory() stringByAppendingPathComponent:@".npm-global/bin/codex"]
    ]];
    return [[NSOrderedSet orderedSetWithArray:paths] array];
}

- (NSString *)codexBinaryPath {
    for (NSString *path in self.codexBinaryCandidates) {
        if ([NSFileManager.defaultManager isExecutableFileAtPath:path]) return path;
    }
    return nil;
}

- (void)refreshQuota:(id)sender {
    (void)sender;
    if (_syncInProgress) return;
    _syncInProgress = YES;
    _syncState = QGSyncStateSyncing;
    _lastError = nil;
    [self updateStatusItem];
    NSString *binary = self.codexBinaryPath;
    if (!binary) {
        [self finishSyncWithQuota:nil error:QGL(@"error.codexNotFound")];
        return;
    }

    __weak QGAppDelegate *weakSelf = self;
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
        NSString *errorMessage = nil;
        NSDictionary *quota = [weakSelf readQuotaUsingBinary:binary error:&errorMessage];
        dispatch_async(dispatch_get_main_queue(), ^{
            [weakSelf finishSyncWithQuota:quota error:errorMessage];
        });
    });
}

- (NSDictionary *)readQuotaUsingBinary:(NSString *)binary error:(NSString **)errorMessage {
    NSTask *task = [NSTask new];
    task.executableURL = [NSURL fileURLWithPath:binary];
    task.arguments = @[@"app-server", @"--stdio"];
    NSPipe *input = [NSPipe pipe];
    NSPipe *output = [NSPipe pipe];
    task.standardInput = input;
    task.standardOutput = output;
    task.standardError = NSFileHandle.fileHandleWithNullDevice;

    dispatch_semaphore_t completed = dispatch_semaphore_create(0);
    NSObject *stateLock = [NSObject new];
    NSMutableData *pending = [NSMutableData data];
    __block NSDictionary *resultQuota = nil;
    __block NSString *resultError = nil;
    __block BOOL finished = NO;
    __block BOOL requestSent = NO;

    void (^finish)(NSDictionary *, NSString *) = ^(NSDictionary *quota, NSString *failure) {
        BOOL shouldSignal = NO;
        @synchronized (stateLock) {
            if (!finished) {
                finished = YES;
                resultQuota = quota;
                resultError = failure;
                shouldSignal = YES;
            }
        }
        if (shouldSignal) dispatch_semaphore_signal(completed);
    };

    output.fileHandleForReading.readabilityHandler = ^(NSFileHandle *handle) {
        NSData *chunk = handle.availableData;
        if (!chunk.length) {
            finish(nil, QGL(@"error.noQuotaData"));
            return;
        }
        NSMutableArray<NSDictionary *> *messages = [NSMutableArray array];
        @synchronized (stateLock) {
            [pending appendData:chunk];
            while (pending.length) {
                const uint8_t *bytes = pending.bytes;
                NSUInteger newlineIndex = NSNotFound;
                for (NSUInteger index = 0; index < pending.length; index++) {
                    if (bytes[index] == '\n') {
                        newlineIndex = index;
                        break;
                    }
                }
                if (newlineIndex == NSNotFound) break;
                NSData *lineData = [pending subdataWithRange:NSMakeRange(0, newlineIndex)];
                [pending replaceBytesInRange:NSMakeRange(0, newlineIndex + 1)
                                   withBytes:NULL
                                      length:0];
                if (!lineData.length) continue;
                NSDictionary *json = [NSJSONSerialization JSONObjectWithData:lineData options:0 error:nil];
                if ([json isKindOfClass:NSDictionary.class]) [messages addObject:json];
            }
        }
        for (NSDictionary *json in messages) {
            if (QGIDEquals(json[@"id"], 1) && [json[@"result"] isKindOfClass:NSDictionary.class] && !requestSent) {
                requestSent = YES;
                NSString *request = @"{\"method\":\"account/rateLimits/read\",\"id\":2}\n";
                @try {
                    [input.fileHandleForWriting writeData:[request dataUsingEncoding:NSUTF8StringEncoding]];
                } @catch (__unused NSException *exception) {
                    finish(nil, QGL(@"error.connectionClosed"));
                }
                continue;
            }
            if (QGIDEquals(json[@"id"], 2)) {
                if ([json[@"result"] isKindOfClass:NSDictionary.class]) {
                    NSDictionary *quota = QGQuotaFromResult(json[@"result"]);
                    finish(quota, quota ? nil : QGL(@"error.unrecognizedResponse"));
                } else {
                    finish(nil, QGL(@"error.noQuotaData"));
                }
            }
        }
    };

    task.terminationHandler = ^(NSTask *terminatedTask) {
        (void)terminatedTask;
        finish(nil, QGL(@"error.connectionClosed"));
    };
    NSError *launchError = nil;
    if (![task launchAndReturnError:&launchError]) {
        output.fileHandleForReading.readabilityHandler = nil;
        if (errorMessage) *errorMessage = launchError.localizedDescription ?: QGL(@"error.launchFailed");
        return nil;
    }

    NSString *initialize = @"{\"method\":\"initialize\",\"id\":1,\"params\":{\"clientInfo\":{\"name\":\"gauge-for-codex\",\"title\":\"Gauge for Codex\",\"version\":\"1.0\"},\"capabilities\":null}}\n";
    @try {
        [input.fileHandleForWriting writeData:[initialize dataUsingEncoding:NSUTF8StringEncoding]];
    } @catch (__unused NSException *exception) {
        finish(nil, QGL(@"error.connectionClosed"));
    }

    long waitResult = dispatch_semaphore_wait(completed, dispatch_time(DISPATCH_TIME_NOW, 20 * NSEC_PER_SEC));
    if (waitResult != 0) finish(nil, QGL(@"error.timeout"));
    output.fileHandleForReading.readabilityHandler = nil;
    @try { [input.fileHandleForWriting closeFile]; } @catch (__unused NSException *exception) {}
    if (task.running) [task terminate];
    if (errorMessage) *errorMessage = resultError ?: (resultQuota ? nil : QGL(@"error.noQuotaData"));
    return resultQuota;
}

- (void)finishSyncWithQuota:(NSDictionary *)quota error:(NSString *)errorMessage {
    _syncInProgress = NO;
    if (quota) {
        [self applyWindows:quota[@"windows"]];
        _syncState = QGSyncStateSuccess;
        _syncDetail = [NSString stringWithFormat:QGL(@"sync.source"), quota[@"bucket"] ?: @"Codex"];
        _lastSuccessfulSync = NSDate.date;
        _lastError = nil;
        [self saveQuotaWindows:_quotaWindows];
        [NSUserDefaults.standardUserDefaults setDouble:_lastSuccessfulSync.timeIntervalSince1970 forKey:QGLastSyncKey];
    } else {
        _syncState = QGSyncStateFailed;
        _lastError = errorMessage ?: QGL(@"sync.failed");
    }
    [self updateStatusItem];
}

- (BOOL)parseLocalizedNumber:(NSString *)string value:(double *)value {
    NSString *trimmed = [string stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (!trimmed.length) return NO;
    NSNumberFormatter *formatter = [NSNumberFormatter new];
    formatter.locale = NSLocale.currentLocale;
    formatter.numberStyle = NSNumberFormatterDecimalStyle;
    formatter.lenient = NO;
    NSRange range = NSMakeRange(0, trimmed.length);
    NSNumber *number = nil;
    BOOL valid = [formatter getObjectValue:&number forString:trimmed range:&range error:nil];
    if (!valid || range.length != trimmed.length || !isfinite(number.doubleValue)) return NO;
    if (value) *value = number.doubleValue;
    return YES;
}

- (void)editQuota:(id)sender {
    (void)sender;
    NSAlert *alert = [NSAlert new];
    alert.messageText = QGL(@"manual.title");
    alert.informativeText = QGL(@"manual.help");
    [alert addButtonWithTitle:QGL(@"common.save")];
    [alert addButtonWithTitle:QGL(@"common.cancel")];

    double currentUsed = _selectedWindow ? 100.0 - [_selectedWindow[@"remainingPercent"] doubleValue] : 0.0;
    NSTextField *usedField = [NSTextField textFieldWithString:[NSString stringWithFormat:@"%.0f", currentUsed]];
    usedField.placeholderString = @"0–100";
    NSTextField *hoursField = [NSTextField textFieldWithString:@""];
    hoursField.placeholderString = QGL(@"manual.hoursPlaceholder");
    NSTextField *usedLabel = [NSTextField labelWithString:QGL(@"manual.usedLabel")];
    NSTextField *hoursLabel = [NSTextField labelWithString:QGL(@"manual.hoursLabel")];
    usedLabel.alignment = hoursLabel.alignment = NSTextAlignmentRight;
    [usedLabel.widthAnchor constraintEqualToConstant:110].active = YES;
    [hoursLabel.widthAnchor constraintEqualToConstant:110].active = YES;
    [usedField.widthAnchor constraintEqualToConstant:178].active = YES;
    [hoursField.widthAnchor constraintEqualToConstant:178].active = YES;
    NSStackView *row1 = [NSStackView stackViewWithViews:@[usedLabel, usedField]];
    NSStackView *row2 = [NSStackView stackViewWithViews:@[hoursLabel, hoursField]];
    row1.spacing = row2.spacing = 8;
    NSStackView *stack = [NSStackView stackViewWithViews:@[row1, row2]];
    stack.orientation = NSUserInterfaceLayoutOrientationVertical;
    stack.spacing = 8;
    stack.frame = NSMakeRect(0, 0, 300, 56);
    alert.accessoryView = stack;

    [NSApp activateIgnoringOtherApps:YES];
    while ([alert runModal] == NSAlertFirstButtonReturn) {
        double used = 0;
        if (![self parseLocalizedNumber:usedField.stringValue value:&used] || used < 0 || used > 100) {
            NSBeep();
            alert.informativeText = QGL(@"manual.invalidPercent");
            continue;
        }
        NSTimeInterval resetAt = [_selectedWindow[@"resetsAt"] doubleValue];
        NSString *hoursText = [hoursField.stringValue stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
        if (hoursText.length) {
            double hours = 0;
            if (![self parseLocalizedNumber:hoursText value:&hours] || hours <= 0 || hours > 24 * 365) {
                NSBeep();
                alert.informativeText = QGL(@"manual.invalidHours");
                continue;
            }
            resetAt = NSDate.date.timeIntervalSince1970 + hours * 3600.0;
        }
        NSDictionary *window = @{
            @"usedPercent": @(used), @"remainingPercent": @(100.0 - used),
            @"resetsAt": @(MAX(0.0, resetAt)), @"windowDurationMins": @0, @"kind": @"primary"
        };
        [self applyWindows:@[window]];
        _syncState = QGSyncStateIdle;
        _syncDetail = QGL(@"sync.manual");
        _lastSuccessfulSync = NSDate.date;
        [self saveQuotaWindows:_quotaWindows];
        [NSUserDefaults.standardUserDefaults setDouble:_lastSuccessfulSync.timeIntervalSince1970 forKey:QGLastSyncKey];
        [self updateStatusItem];
        break;
    }
}

- (void)showAbout:(id)sender {
    (void)sender;
    NSString *version = [NSBundle.mainBundle objectForInfoDictionaryKey:@"CFBundleShortVersionString"] ?: @"2.0";
    NSAlert *alert = [NSAlert new];
    alert.messageText = [NSString stringWithFormat:@"%@ %@", QGProductName, version];
    alert.informativeText = [NSString stringWithFormat:QGL(@"about.body"), QGProductName];
    [alert addButtonWithTitle:QGL(@"common.ok")];
    [NSApp activateIgnoringOtherApps:YES];
    [alert runModal];
}
@end

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        if (argc > 1 && strcmp(argv[1], "--self-test") == 0) return QGRunSelfTests() ? 0 : 1;
        NSApplication *application = NSApplication.sharedApplication;
        QGAppDelegate *delegate = [QGAppDelegate new];
        application.delegate = delegate;
        [application run];
    }
    return 0;
}
