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
        NSString *bL = pp.fields[@"battery_left"]  ?: @"?";
        NSString *bR = pp.fields[@"battery_right"] ?: @"?";
        NSString *bc = pp.fields[@"case_battery"];
        BOOL lCh    = [pp.fields[@"left_charging"]  boolValue];
        BOOL rCh    = [pp.fields[@"right_charging"] boolValue];
        BOOL cCh    = [pp.fields[@"case_charging"]  boolValue];
        BOOL inCase = [pp.fields[@"in_case"]        boolValue];
        if (model) {
            NSString *lTag = lCh ? @"+" : @"";
            NSString *rTag = rCh ? @"+" : @"";
            NSString *cTag = cCh ? @"+" : @"";
            NSMutableString *s = [NSMutableString stringWithFormat:@"%@  L:%@%@  R:%@%@",
                                  model, bL, lTag, bR, rTag];
            if (bc) [s appendFormat:@"  case:%@%@", bc, cTag];
            if (inCase) [s appendString:@"  in-case"];
            return s;
        }
    }
    IPContinuityRecord *wc = [self _latestRecordOfType:IPContinuityTypeWatchConnection];
    if (wc) {
        BOOL locked   = [wc.fields[@"watch_locked"] boolValue];
        BOOL active   = [wc.fields[@"watch_active"] boolValue];
        BOOL charging = [wc.fields[@"watch_charging"] boolValue];
        return [NSString stringWithFormat:@"%@%@%@",
                locked   ? @"locked "   : @"unlocked ",
                active   ? @"active "   : @"idle ",
                charging ? @"charging" : @""];
    }
    IPContinuityRecord *ni = [self _latestRecordOfType:IPContinuityTypeNearbyInfo];
    if (ni) {
        NSString *lock = ni.fields[@"lock_state"] ?: @"?";
        NSNumber *act = ni.fields[@"activity_level"];
        return [NSString stringWithFormat:@"%@  activity=%@", lock, act ?: @"?"];
    }
    IPContinuityRecord *ap = [self _latestRecordOfType:IPContinuityTypeAirPlayTarget];
    if (ap) {
        NSString *ip = ap.fields[@"ipv4"];
        if (ip) return [NSString stringWithFormat:@"AirPlay  %@", ip];
    }
    IPContinuityRecord *na = [self _latestRecordOfType:IPContinuityTypeNearbyAction];
    if (na) {
        NSString *name = na.fields[@"action_name"];
        if (name) return [NSString stringWithFormat:@"action: %@", name];
    }
    IPContinuityRecord *tt = [self _latestRecordOfType:IPContinuityTypeTetheringTarget];
    if (tt) {
        NSString *batt = tt.fields[@"battery_percent"] ?: @"?";
        NSString *cell = tt.fields[@"cell_service"]    ?: @"?";
        NSNumber *bars = tt.fields[@"cell_bars"];
        return [NSString stringWithFormat:@"Tether  batt=%@  %@ %@bars",
                batt, cell, bars ?: @"?"];
    }
    IPContinuityRecord *fm = [self _latestRecordOfType:IPContinuityTypeFindMy];
    if (fm) {
        id batt = fm.fields[@"battery_state"];
        BOOL lost = [fm.fields[@"lost_mode"] boolValue];
        BOOL oas  = [fm.fields[@"oas_frame"] boolValue];
        return [NSString stringWithFormat:@"FindMy  batt=%@%@%@",
                batt ?: @"?",
                oas  ? @"  owner-nearby" : @"  separated",
                lost ? @"  LOST" : @""];
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
    if ([self _latestRecordOfType:IPContinuityTypeHandoff])          [out addObject:@"Handoff"];
    if ([self _latestRecordOfType:IPContinuityTypeFindMy])           [out addObject:@"FindMy"];
    if ([self _latestRecordOfType:IPContinuityTypeHeySiri])          [out addObject:@"Siri"];
    if ([self _latestRecordOfType:IPContinuityTypeTetheringSource])  [out addObject:@"Hotspot"];
    if ([self _latestRecordOfType:IPContinuityTypeTetheringTarget])  [out addObject:@"Tether"];
    if ([self _latestRecordOfType:IPContinuityTypeNearbyAction])     [out addObject:@"Action"];
    return out;
}

@end
