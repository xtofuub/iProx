#import "IPDeviceEntry.h"

@implementation IPDeviceEntry

- (instancetype)init {
    if ((self = [super init])) {
        _records = [NSMutableArray array];
        _firstSeen = [NSDate date];
        _lastSeen = _firstSeen;
        _updateCount = 0;
    }
    return self;
}

- (instancetype)snapshotCopy {
    IPDeviceEntry *c = [[IPDeviceEntry alloc] init];
    c.identifier = self.identifier;
    c.displayName = self.displayName;
    c.lastRSSI = self.lastRSSI;
    c.firstSeen = self.firstSeen;
    c.lastSeen = self.lastSeen;
    c.updateCount = self.updateCount;
    c.records = [NSMutableArray arrayWithArray:self.records];
    return c;
}

- (IPContinuityRecord *)_latestRecordOfType:(IPContinuityType)type {
    // Walk backwards for most recent of that type.
    for (NSInteger i = self.records.count - 1; i >= 0; i--) {
        IPContinuityRecord *r = self.records[i];
        if (r.type == type) return r;
    }
    return nil;
}

- (NSString *)inferredDeviceCategory {
    if ([self _latestRecordOfType:IPContinuityTypeProximityPairing]) return @"AirPods";
    if ([self _latestRecordOfType:IPContinuityTypeNearbyInfo])       return @"iPhone";
    if ([self _latestRecordOfType:IPContinuityTypeHandoff])           return @"Apple Device";
    if ([self _latestRecordOfType:IPContinuityTypeAirDrop])           return @"AirDrop Sender";
    if ([self _latestRecordOfType:IPContinuityTypeWatchConnection])   return @"Apple Watch";
    if ([self _latestRecordOfType:IPContinuityTypeAirPlayTarget])     return @"AirPlay Target";
    if ([self _latestRecordOfType:IPContinuityTypeFindMy])            return @"FindMy Beacon";
    return @"Apple Device";
}

- (NSString *)inferredModelLabel {
    IPContinuityRecord *pp = [self _latestRecordOfType:IPContinuityTypeProximityPairing];
    if (pp) {
        NSString *model = pp.fields[@"model"];
        NSString *bL = pp.fields[@"battery_left"] ?: @"?";
        NSString *bR = pp.fields[@"battery_right"] ?: @"?";
        if (model) return [NSString stringWithFormat:@"%@  L:%@  R:%@", model, bL, bR];
    }
    IPContinuityRecord *ni = [self _latestRecordOfType:IPContinuityTypeNearbyInfo];
    if (ni) {
        NSString *lock = ni.fields[@"lock_state"] ?: @"?";
        NSNumber *act = ni.fields[@"activity_level"];
        return [NSString stringWithFormat:@"%@  activity=%@", lock, act ?: @"?"];
    }
    IPContinuityRecord *ad = [self _latestRecordOfType:IPContinuityTypeAirDrop];
    if (ad) {
        NSString *phone = ad.fields[@"phone_hash"];
        NSString *email = ad.fields[@"email_hash"];
        return [NSString stringWithFormat:@"phone:%@ email:%@", phone ?: @"-", email ?: @"-"];
    }
    return @"--";
}

- (NSString *)lockStateLabel {
    IPContinuityRecord *ni = [self _latestRecordOfType:IPContinuityTypeNearbyInfo];
    if (!ni) return nil;
    return ni.fields[@"lock_state"];
}

- (BOOL)isAirDropReceiver {
    IPContinuityRecord *ni = [self _latestRecordOfType:IPContinuityTypeNearbyInfo];
    return [ni.fields[@"airdrop_receiver"] boolValue];
}

- (NSArray<NSString *> *)activeBadges {
    NSMutableArray *out = [NSMutableArray array];
    IPContinuityRecord *ni = [self _latestRecordOfType:IPContinuityTypeNearbyInfo];
    if (ni) {
        if ([ni.fields[@"airdrop_receiver"] boolValue]) [out addObject:@"AirDrop"];
        if ([ni.fields[@"airpods_connected"] boolValue]) [out addObject:@"AirPods"];
        if ([ni.fields[@"primary_icloud"] boolValue]) [out addObject:@"iCloud"];
        NSString *lock = ni.fields[@"lock_state"];
        if ([lock isEqualToString:@"locked"]) [out addObject:@"Lock"];
    }
    if ([self _latestRecordOfType:IPContinuityTypeHandoff]) [out addObject:@"Handoff"];
    if ([self _latestRecordOfType:IPContinuityTypeFindMy])  [out addObject:@"FindMy"];
    return out;
}

@end
