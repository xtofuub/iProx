#import <Foundation/Foundation.h>
#import "IPDeviceEntry.h"
#import "../Daemon/ContinuityRecord.h"

NS_ASSUME_NONNULL_BEGIN

extern NSNotificationName const IPDeviceStoreDidChangeNotification;

@interface IPDeviceStore : NSObject

+ (instancetype)shared;

- (NSArray<IPDeviceEntry *> *)snapshotSortedByRecency;
- (nullable IPDeviceEntry *)snapshotForIdentifier:(NSString *)identifier;
- (NSUInteger)deviceCount;
- (void)ingestRecords:(NSArray<IPContinuityRecord *> *)records
        forIdentifier:(NSString *)identifier
                 rssi:(NSInteger)rssi
             metadata:(nullable NSDictionary<NSString *, id> *)metadata;
- (void)clearAll;

// "That one's mine" tagging — persisted across launches via NSUserDefaults.
// Note: Apple devices rotate BLE MAC every ~15 min, so the tag follows the
// current CBPeripheral identifier and falls off at the next rotation. Re-tag
// when you see the new uuid show up.
@property (atomic, copy, readonly) NSSet<NSString *> *taggedIdentifiers;
- (void)toggleTagForIdentifier:(NSString *)identifier;
- (BOOL)isTagged:(NSString *)identifier;
- (void)clearAllTags;

@property (atomic, assign) NSUInteger totalDiscoveryCount;
@property (atomic, assign) NSUInteger totalAppleRecordCount;

@end

NS_ASSUME_NONNULL_END
