#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(uint8_t, IPContinuityType) {
    IPContinuityTypeAirDrop           = 0x05,
    IPContinuityTypeProximityPairing  = 0x07,
    IPContinuityTypeHeySiri           = 0x08,
    IPContinuityTypeAirPlayTarget     = 0x09,
    IPContinuityTypeMagicSwitch       = 0x0A,
    IPContinuityTypeWatchConnection   = 0x0B,
    IPContinuityTypeHandoff           = 0x0C,
    IPContinuityTypeTetheringTarget   = 0x0D,
    IPContinuityTypeTetheringSource   = 0x0E,
    IPContinuityTypeNearbyAction      = 0x0F,
    IPContinuityTypeNearbyInfo        = 0x10,
    IPContinuityTypeFindMy            = 0x12,
};

@interface IPContinuityRecord : NSObject
@property (nonatomic, copy, nullable) NSString *mac;
@property (nonatomic, assign) NSInteger rssi;
@property (nonatomic, assign) IPContinuityType type;
@property (nonatomic, copy) NSString *typeName;
@property (nonatomic, copy) NSDictionary<NSString *, id> *fields;
@property (nonatomic, copy) NSData *rawValue;
@property (nonatomic, copy) NSDate *timestamp;

+ (NSString *)nameForType:(IPContinuityType)type;
- (NSString *)oneLineSummary;
@end

NS_ASSUME_NONNULL_END
