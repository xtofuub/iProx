#import <Foundation/Foundation.h>
#import "ContinuityRecord.h"

NS_ASSUME_NONNULL_BEGIN

@interface IPContinuityDecoder : NSObject

// Decode raw Apple manufacturer-data payload (with or without leading 0x4C 0x00).
// Returns one record per TLV. Skips bytes that don't parse cleanly.
+ (NSArray<IPContinuityRecord *> *)decodeManufacturerData:(NSData *)payload
                                                       mac:(nullable NSString *)mac
                                                      rssi:(NSInteger)rssi;

@end

NS_ASSUME_NONNULL_END
