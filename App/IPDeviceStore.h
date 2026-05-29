#import <Foundation/Foundation.h>
#import "IPDeviceEntry.h"
#import "../Daemon/ContinuityRecord.h"

NS_ASSUME_NONNULL_BEGIN

extern NSNotificationName const IPDeviceStoreDidChangeNotification;

@interface IPDeviceStore : NSObject

+ (instancetype)shared;

- (NSArray<IPDeviceEntry *> *)snapshotSortedByRecency;
- (void)ingestRecords:(NSArray<IPContinuityRecord *> *)records
        forIdentifier:(NSString *)identifier
                 rssi:(NSInteger)rssi;
- (void)clearAll;

@property (atomic, assign) NSUInteger totalDiscoveryCount;
@property (atomic, assign) NSUInteger totalAppleRecordCount;

@end

NS_ASSUME_NONNULL_END
