#import <Foundation/Foundation.h>
#import <CoreBluetooth/CoreBluetooth.h>

NS_ASSUME_NONNULL_BEGIN

extern NSNotificationName const IPScannerStateDidChangeNotification;

@interface IPScannerService : NSObject

+ (instancetype)shared;

@property (atomic, assign, readonly) CBManagerState bluetoothState;
@property (atomic, assign, readonly) BOOL isScanning;

// Diagnostics — prove whether iOS delivers Apple manufacturer data to us.
@property (atomic, assign, readonly) NSUInteger cbCallbacks;
@property (atomic, assign, readonly) NSUInteger cbWithMfrData;
@property (atomic, assign, readonly) NSUInteger cbApple;
- (NSString *)recentCompanyIDsString;

- (void)start;
- (void)stop;
- (NSString *)bluetoothStateDescription;

@end

NS_ASSUME_NONNULL_END
