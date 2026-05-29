#import "ContinuityDecoder.h"
#import "Logger.h"

static const uint8_t kAppleMfrLE0 = 0x4C;
static const uint8_t kAppleMfrLE1 = 0x00;

static NSString *_HexFromBytes(const uint8_t *p, NSUInteger n) {
    NSMutableString *s = [NSMutableString stringWithCapacity:n * 2];
    for (NSUInteger i = 0; i < n; i++) [s appendFormat:@"%02x", p[i]];
    return s;
}

static NSDictionary *_DecodeAirDrop(const uint8_t *v, NSUInteger n) {
    NSMutableDictionary *d = [NSMutableDictionary dictionary];
    d[@"raw"] = _HexFromBytes(v, n);
    if (n >= 2) d[@"phone_hash"] = _HexFromBytes(v, 2);
    if (n >= 4) d[@"email_hash"] = _HexFromBytes(v + 2, 2);
    if (n >= 6) d[@"appleid_hash"] = _HexFromBytes(v + 4, 2);
    return d;
}

static NSString *_AirPodsModel(uint16_t code) {
    switch (code) {
        case 0x0220: return @"AirPods 1";
        case 0x0F20: return @"AirPods 2";
        case 0x1320: return @"AirPods 3";
        case 0x0E20: return @"AirPods Pro";
        case 0x1420: return @"AirPods Pro 2";
        case 0x0A20: return @"AirPods Max";
        case 0x0520: return @"BeatsX";
        case 0x0620: return @"Beats Solo3";
        case 0x0920: return @"BeatsStudio3";
        case 0x0B20: return @"Powerbeats3";
        case 0x0C20: return @"Powerbeats Pro";
        case 0x1020: return @"Beats Solo Pro";
        case 0x1120: return @"PowerBeats4";
        case 0x1720: return @"Beats Studio Buds";
        case 0x1B20: return @"Beats Fit Pro";
        default:     return @"unknown";
    }
}

static NSDictionary *_DecodeProximityPairing(const uint8_t *v, NSUInteger n) {
    NSMutableDictionary *d = [NSMutableDictionary dictionary];
    d[@"raw"] = _HexFromBytes(v, n);
    if (n >= 3) {
        uint16_t code = ((uint16_t)v[1] << 8) | v[2];
        d[@"model_code"] = [NSString stringWithFormat:@"0x%04X", code];
        d[@"model"] = _AirPodsModel(code);
    }
    if (n >= 5) {
        uint8_t batt = v[4];
        d[@"battery_right"] = [NSString stringWithFormat:@"%u%%", (batt & 0x0F) * 10];
        d[@"battery_left"]  = [NSString stringWithFormat:@"%u%%", ((batt >> 4) & 0x0F) * 10];
    }
    if (n >= 6) {
        uint8_t casebyte = v[5];
        d[@"case_battery"]  = [NSString stringWithFormat:@"%u%%", (casebyte & 0x0F) * 10];
        d[@"case_charging"] = @((casebyte & 0x40) != 0);
    }
    return d;
}

static NSDictionary *_DecodeNearbyInfo(const uint8_t *v, NSUInteger n) {
    NSMutableDictionary *d = [NSMutableDictionary dictionary];
    d[@"raw"] = _HexFromBytes(v, n);
    if (n < 1) return d;
    uint8_t status = v[0];
    d[@"status_byte"]       = [NSString stringWithFormat:@"0x%02X", status];
    d[@"airpods_connected"] = @((status & 0x10) != 0);
    d[@"airdrop_receiver"]  = @((status & 0x04) || (status & 0x40));
    d[@"primary_icloud"]    = @((status & 0x02) != 0);
    d[@"lock_state"]        = (status & 0x08) ? @"locked" : @"unlocked";
    if (n > 1) {
        uint8_t activity = v[1];
        d[@"activity_byte"]  = [NSString stringWithFormat:@"0x%02X", activity];
        d[@"activity_level"] = @(activity & 0x0F);
    }
    if (n >= 5) d[@"auth_tag"] = _HexFromBytes(v + 2, 3);
    return d;
}

static NSDictionary *_DecodeHandoff(const uint8_t *v, NSUInteger n) {
    NSMutableDictionary *d = [NSMutableDictionary dictionary];
    d[@"raw"]  = _HexFromBytes(v, n);
    d[@"note"] = @"encrypted, requires IRK";
    if (n >= 1)  d[@"clipboard_status"] = @(v[0]);
    if (n >= 3)  d[@"iv"]                = _HexFromBytes(v + 1, 2);
    if (n >= 4)  d[@"auth_tag"]          = _HexFromBytes(v + 3, 1);
    if (n >= 14) d[@"encrypted_payload"] = _HexFromBytes(v + 4, 10);
    return d;
}

static NSString *_NearbyActionName(uint8_t code) {
    switch (code) {
        case 0x01: return @"AppleTV Setup";
        case 0x04: return @"Mobile Backup";
        case 0x05: return @"Watch Setup";
        case 0x06: return @"AppleTV Pair";
        case 0x07: return @"Internet Relay";
        case 0x08: return @"WiFi Password";
        case 0x09: return @"iOS Setup";
        case 0x0A: return @"Repair";
        case 0x0B: return @"Speaker Setup";
        case 0x0C: return @"AppleID Setup";
        case 0x0D: return @"Share Contacts";
        case 0x0E: return @"WhoAmI";
        case 0x0F: return @"DevSetup";
        case 0x10: return @"AccessoryPairing";
        case 0x11: return @"HomeKit Setup";
        case 0x13: return @"TVOS Setup";
        default:   return @"unknown";
    }
}

static NSDictionary *_DecodeNearbyAction(const uint8_t *v, NSUInteger n) {
    NSMutableDictionary *d = [NSMutableDictionary dictionary];
    d[@"raw"] = _HexFromBytes(v, n);
    if (n >= 2) {
        d[@"action_flags"] = [NSString stringWithFormat:@"0x%02X", v[0]];
        d[@"action_type"]  = [NSString stringWithFormat:@"0x%02X", v[1]];
        d[@"action_name"]  = _NearbyActionName(v[1]);
    }
    return d;
}

static NSDictionary *_DecodeFindMy(const uint8_t *v, NSUInteger n) {
    NSMutableDictionary *d = [NSMutableDictionary dictionary];
    d[@"raw"] = _HexFromBytes(v, n);
    if (n >= 1) {
        uint8_t status = v[0];
        d[@"status_byte"]   = [NSString stringWithFormat:@"0x%02X", status];
        d[@"battery_state"] = @((status >> 6) & 0x03);
        d[@"lost_mode"]     = @((status & 0x04) != 0);
        d[@"maintained"]    = @((status & 0x02) != 0);
    }
    if (n >= 23) d[@"public_key_prefix"] = _HexFromBytes(v + 1, 22);
    return d;
}

static NSDictionary *_DecodeAirPlayTarget(const uint8_t *v, NSUInteger n) {
    NSMutableDictionary *d = [NSMutableDictionary dictionary];
    d[@"raw"] = _HexFromBytes(v, n);
    if (n >= 6) {
        d[@"flags"] = [NSString stringWithFormat:@"0x%02X", v[0]];
        d[@"seed"]  = @(v[1]);
        d[@"ipv4"]  = [NSString stringWithFormat:@"%u.%u.%u.%u", v[2], v[3], v[4], v[5]];
    }
    return d;
}

static NSDictionary *_DecodeTetheringTarget(const uint8_t *v, NSUInteger n) {
    NSMutableDictionary *d = [NSMutableDictionary dictionary];
    d[@"raw"] = _HexFromBytes(v, n);
    if (n >= 1) d[@"battery_percent"] = @(v[0]);
    if (n >= 3) {
        d[@"cell_service_type"] = @(v[1]);
        d[@"cell_bars"]         = @(v[2]);
    }
    return d;
}

static NSDictionary *_DecodeRaw(const uint8_t *v, NSUInteger n) {
    return @{ @"raw": _HexFromBytes(v, n) };
}

@implementation IPContinuityDecoder

+ (NSArray<IPContinuityRecord *> *)decodeManufacturerData:(NSData *)payload
                                                       mac:(NSString *)mac
                                                      rssi:(NSInteger)rssi {
    if (payload.length < 2) return @[];
    const uint8_t *bytes = (const uint8_t *)payload.bytes;
    NSUInteger len = payload.length;
    NSUInteger cursor = 0;

    if (len >= 2 && bytes[0] == kAppleMfrLE0 && bytes[1] == kAppleMfrLE1) {
        cursor = 2;
    }

    NSMutableArray<IPContinuityRecord *> *out = [NSMutableArray array];
    NSDate *now = [NSDate date];

    while (cursor + 1 < len) {
        uint8_t t = bytes[cursor];
        uint8_t l = bytes[cursor + 1];
        if (cursor + 2 + l > len) {
            IPDebug("truncated TLV at cursor=%lu type=0x%02X len=%u remaining=%lu",
                    (unsigned long)cursor, t, l, (unsigned long)(len - cursor - 2));
            break;
        }
        const uint8_t *v = bytes + cursor + 2;
        NSDictionary *fields = nil;
        switch (t) {
            case IPContinuityTypeAirDrop:           fields = _DecodeAirDrop(v, l); break;
            case IPContinuityTypeProximityPairing:  fields = _DecodeProximityPairing(v, l); break;
            case IPContinuityTypeAirPlayTarget:     fields = _DecodeAirPlayTarget(v, l); break;
            case IPContinuityTypeHandoff:           fields = _DecodeHandoff(v, l); break;
            case IPContinuityTypeTetheringTarget:   fields = _DecodeTetheringTarget(v, l); break;
            case IPContinuityTypeNearbyAction:      fields = _DecodeNearbyAction(v, l); break;
            case IPContinuityTypeNearbyInfo:        fields = _DecodeNearbyInfo(v, l); break;
            case IPContinuityTypeFindMy:            fields = _DecodeFindMy(v, l); break;
            default:                                fields = _DecodeRaw(v, l); break;
        }

        IPContinuityRecord *rec = [[IPContinuityRecord alloc] init];
        rec.mac = mac;
        rec.rssi = rssi;
        rec.type = (IPContinuityType)t;
        rec.typeName = [IPContinuityRecord nameForType:(IPContinuityType)t];
        rec.fields = fields ?: @{};
        rec.rawValue = [NSData dataWithBytes:v length:l];
        rec.timestamp = now;
        [out addObject:rec];

        cursor += 2 + l;
    }
    return out;
}

@end
