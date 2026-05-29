#import <Foundation/Foundation.h>
#import "../Daemon/ContinuityRecord.h"

NS_ASSUME_NONNULL_BEGIN

@interface IPDeviceEntry : NSObject

@property (nonatomic, copy) NSString *identifier;       // CBPeripheral.identifier UUID
@property (nonatomic, copy, nullable) NSString *peripheralName;
@property (nonatomic, copy, nullable) NSString *advLocalName;
@property (nonatomic, copy, nullable) NSNumber *txPower;
@property (nonatomic, copy, nullable) NSNumber *isConnectable;
@property (nonatomic, copy, nullable) NSArray<NSString *> *serviceUUIDs;
@property (nonatomic, assign) NSInteger lastRSSI;
@property (nonatomic, strong) NSMutableArray<IPContinuityRecord *> *records;
@property (nonatomic, copy) NSDate *firstSeen;
@property (nonatomic, copy) NSDate *lastSeen;
@property (nonatomic, assign) NSUInteger updateCount;

// Derived helpers used by cell
- (nullable NSString *)inferredDeviceCategory;   // iPhone / AirPods / Mac / Watch / ...
- (nullable NSString *)inferredModelLabel;       // "AirPods Pro 2", "iOS 17 iPhone", etc.
- (nullable NSString *)lockStateLabel;
- (nullable NSString *)bestDisplayName;          // peripheralName || advLocalName || category
- (BOOL)isAirDropReceiver;
- (NSArray<NSString *> *)activeBadges;
- (double)advertsPerSecond;                       // rate over [firstSeen, lastSeen]
- (nullable NSNumber *)estimatedDistanceMeters;   // path-loss from RSSI + txPower

// Immutable snapshot for cross-thread UI reads. The contained records are
// effectively immutable after ingest, so they are shared, but the array is new.
- (instancetype)snapshotCopy;

@end

NS_ASSUME_NONNULL_END
