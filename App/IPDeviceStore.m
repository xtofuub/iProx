#import "IPDeviceStore.h"

NSNotificationName const IPDeviceStoreDidChangeNotification = @"IPDeviceStoreDidChangeNotification";

@interface IPDeviceStore ()
@property (nonatomic, strong) NSMutableDictionary<NSString *, IPDeviceEntry *> *devicesByID;
@property (nonatomic, strong) dispatch_queue_t lock;
@property (nonatomic, assign) NSTimeInterval lastNotifyTime;   // touched on lock queue
@property (nonatomic, assign) BOOL notifyScheduled;            // touched on lock queue
@end

@implementation IPDeviceStore

+ (instancetype)shared {
    static IPDeviceStore *inst;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ inst = [[self alloc] init]; });
    return inst;
}

- (instancetype)init {
    if ((self = [super init])) {
        _devicesByID = [NSMutableDictionary dictionary];
        _lock = dispatch_queue_create("com.iprox.store", DISPATCH_QUEUE_SERIAL);
    }
    return self;
}

- (void)ingestRecords:(NSArray<IPContinuityRecord *> *)records
        forIdentifier:(NSString *)identifier
                 rssi:(NSInteger)rssi
             metadata:(NSDictionary<NSString *, id> *)metadata {
    if (identifier.length == 0) return;
    dispatch_async(self.lock, ^{
        IPDeviceEntry *entry = self.devicesByID[identifier];
        if (!entry) {
            entry = [[IPDeviceEntry alloc] init];
            entry.identifier = identifier;
            self.devicesByID[identifier] = entry;
        }
        entry.lastRSSI = rssi;
        entry.lastSeen = [NSDate date];
        if (records.count > 0) {
            entry.updateCount += records.count;
            for (IPContinuityRecord *r in records) {
                r.mac = identifier;
                r.rssi = rssi;
                [entry.records addObject:r];
                if (entry.records.count > 80) {
                    [entry.records removeObjectsInRange:NSMakeRange(0, entry.records.count - 80)];
                }
            }
            self.totalAppleRecordCount += records.count;
        }

        // Sticky metadata: only overwrite when the new advert actually
        // carries a non-nil value. Apple devices alternate which keys they
        // emit per advert, so missing == 'keep last known'.
        NSString *pn = metadata[@"peripheral_name"];
        if (pn.length > 0) entry.peripheralName = pn;
        NSString *ln = metadata[@"adv_local_name"];
        if (ln.length > 0) entry.advLocalName = ln;
        NSNumber *tx = metadata[@"tx_power"];
        if (tx) entry.txPower = tx;
        NSNumber *con = metadata[@"connectable"];
        if (con) entry.isConnectable = con;
        NSArray *svc = metadata[@"services"];
        if (svc.count > 0) entry.serviceUUIDs = svc;

        [self _postChangeThrottledLocked];
    });
}

// Coalesce change notifications to <= ~2.5/sec so a burst of adverts can't
// thrash the main thread with reloads. Must be called on self.lock.
- (void)_postChangeThrottledLocked {
    NSTimeInterval now = [NSDate timeIntervalSinceReferenceDate];
    if (now - self.lastNotifyTime >= 0.4) {
        self.lastNotifyTime = now;
        [self _emitChange];
    } else if (!self.notifyScheduled) {
        self.notifyScheduled = YES;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.4 * NSEC_PER_SEC)),
                       self.lock, ^{
            self.notifyScheduled = NO;
            self.lastNotifyTime = [NSDate timeIntervalSinceReferenceDate];
            [self _emitChange];
        });
    }
}

- (void)_emitChange {
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:IPDeviceStoreDidChangeNotification
                                                            object:nil];
    });
}

- (IPDeviceEntry *)snapshotForIdentifier:(NSString *)identifier {
    if (identifier.length == 0) return nil;
    __block IPDeviceEntry *out = nil;
    dispatch_sync(self.lock, ^{
        IPDeviceEntry *live = self.devicesByID[identifier];
        if (live) out = [live snapshotCopy];
    });
    return out;
}

- (NSUInteger)deviceCount {
    __block NSUInteger n = 0;
    dispatch_sync(self.lock, ^{ n = self.devicesByID.count; });
    return n;
}

- (NSArray<IPDeviceEntry *> *)snapshotSortedByRecency {
    __block NSArray<IPDeviceEntry *> *out = nil;
    dispatch_sync(self.lock, ^{
        NSMutableArray<IPDeviceEntry *> *copies =
            [NSMutableArray arrayWithCapacity:self.devicesByID.count];
        for (IPDeviceEntry *e in self.devicesByID.allValues) {
            [copies addObject:[e snapshotCopy]];
        }
        [copies sortUsingComparator:^NSComparisonResult(IPDeviceEntry *a, IPDeviceEntry *b) {
            return [b.lastSeen compare:a.lastSeen];
        }];
        out = copies;
    });
    return out ?: @[];
}

- (void)clearAll {
    dispatch_async(self.lock, ^{
        [self.devicesByID removeAllObjects];
        self.totalDiscoveryCount = 0;
        self.totalAppleRecordCount = 0;
        [self _emitChange];
    });
}

@end
