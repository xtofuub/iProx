#import "ContinuityRecord.h"

@implementation IPContinuityRecord

+ (NSString *)nameForType:(IPContinuityType)type {
    switch (type) {
        case IPContinuityTypeAirDrop:          return @"AirDrop";
        case IPContinuityTypeProximityPairing: return @"ProximityPairing";
        case IPContinuityTypeHeySiri:          return @"HeySiri";
        case IPContinuityTypeAirPlayTarget:    return @"AirPlayTarget";
        case IPContinuityTypeMagicSwitch:      return @"MagicSwitch";
        case IPContinuityTypeWatchConnection:  return @"WatchConnection";
        case IPContinuityTypeHandoff:          return @"Handoff";
        case IPContinuityTypeTetheringTarget:  return @"TetheringTarget";
        case IPContinuityTypeTetheringSource:  return @"TetheringSource";
        case IPContinuityTypeNearbyAction:     return @"NearbyAction";
        case IPContinuityTypeNearbyInfo:       return @"NearbyInfo";
        case IPContinuityTypeFindMy:           return @"FindMy";
    }
    return [NSString stringWithFormat:@"Unknown_0x%02X", type];
}

- (NSString *)oneLineSummary {
    NSMutableArray *kv = [NSMutableArray array];
    [self.fields enumerateKeysAndObjectsUsingBlock:^(NSString *k, id v, BOOL *stop) {
        [kv addObject:[NSString stringWithFormat:@"%@=%@", k, v]];
    }];
    NSString *joined = [kv componentsJoinedByString:@" "];
    return [NSString stringWithFormat:@"%@ rssi=%ld type=0x%02X(%@) %@",
            self.mac ?: @"??:??:??:??:??:??",
            (long)self.rssi,
            self.type,
            self.typeName,
            joined];
}

@end
