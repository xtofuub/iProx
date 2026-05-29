#import "IPScannerService.h"
#import "IPDeviceStore.h"
#import "../Daemon/ContinuityDecoder.h"
#import "../Daemon/ContinuityRecord.h"

NSNotificationName const IPScannerStateDidChangeNotification = @"IPScannerStateDidChangeNotification";

// Duty cycle: scan window then short idle, to avoid hammering the shared
// BT/WiFi/cellular wireless coprocessor (coexistence). Restarting the scan
// also refreshes RSSI without needing AllowDuplicates flooding.
static const NSTimeInterval kScanWindow = 6.0;
static const NSTimeInterval kScanIdle   = 2.0;

@interface IPScannerService () <CBCentralManagerDelegate>
@property (nonatomic, strong) CBCentralManager *central;
@property (nonatomic, strong) dispatch_queue_t cbQueue;
@property (nonatomic, strong) dispatch_source_t dutyTimer;
@property (nonatomic, assign) BOOL wantScanning;   // user intent
@property (nonatomic, assign) BOOL scanWindowOpen;
@property (nonatomic, strong) NSMutableOrderedSet<NSString *> *companyIDs; // cbQueue only
@end

@implementation IPScannerService

+ (instancetype)shared {
    static IPScannerService *inst;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ inst = [[self alloc] init]; });
    return inst;
}

- (instancetype)init {
    if ((self = [super init])) {
        _cbQueue = dispatch_queue_create("com.iprox.app.cb", DISPATCH_QUEUE_SERIAL);
        _bluetoothState = CBManagerStateUnknown;
        _isScanning = NO;
        _wantScanning = NO;
        _scanWindowOpen = NO;
        _companyIDs = [NSMutableOrderedSet orderedSet];
    }
    return self;
}

- (NSString *)recentCompanyIDsString {
    __block NSString *s = nil;
    dispatch_sync(self.cbQueue, ^{
        if (self.companyIDs.count == 0) {
            s = @"(none seen)";
        } else {
            s = [[self.companyIDs array] componentsJoinedByString:@" "];
        }
    });
    return s;
}

- (void)start {
    self.wantScanning = YES;
    if (!self.central) {
        // First state callback (on cbQueue) begins the duty cycle.
        self.central = [[CBCentralManager alloc] initWithDelegate:self
                                                            queue:self.cbQueue
                                                          options:@{
            CBCentralManagerOptionShowPowerAlertKey: @YES,
        }];
    } else {
        // Re-entry: hop onto cbQueue so all scan-state access stays single-threaded.
        dispatch_async(self.cbQueue, ^{
            if (self.bluetoothState == CBManagerStatePoweredOn) {
                [self _beginDutyCycle];
            }
        });
    }
}

- (void)stop {
    self.wantScanning = NO;
    dispatch_async(self.cbQueue, ^{
        [self _stopDutyCycle];
        if (self.central) [self.central stopScan];
        self->_isScanning = NO;
        [self _notify];
    });
}

#pragma mark - Duty cycle

// Must run on cbQueue.
- (void)_beginDutyCycle {
    [self _stopDutyCycle];
    if (self.bluetoothState != CBManagerStatePoweredOn || !self.wantScanning) return;

    self.dutyTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, self.cbQueue);
    uint64_t period = (uint64_t)((kScanWindow + kScanIdle) * NSEC_PER_SEC);
    // First fire immediately so every window (including the first) is kScanWindow long.
    dispatch_source_set_timer(self.dutyTimer,
                              DISPATCH_TIME_NOW,
                              period,
                              (uint64_t)(0.2 * NSEC_PER_SEC));
    __weak typeof(self) weakSelf = self;
    dispatch_source_set_event_handler(self.dutyTimer, ^{
        [weakSelf _runOneCycle];
    });
    dispatch_resume(self.dutyTimer);
}

// Must run on cbQueue. Opens a scan window and schedules its close kScanWindow later.
- (void)_runOneCycle {
    if (!self.wantScanning || self.bluetoothState != CBManagerStatePoweredOn) {
        [self _stopDutyCycle];
        if (self.central) [self.central stopScan];
        self->_isScanning = NO;
        [self _notify];
        return;
    }
    [self _openScanWindow];
    __weak typeof(self) weakSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(kScanWindow * NSEC_PER_SEC)),
                   self.cbQueue, ^{
        [weakSelf _closeScanWindow];
    });
}

- (void)_openScanWindow {
    if (self.scanWindowOpen) return;
    [self.central scanForPeripheralsWithServices:nil options:@{
        CBCentralManagerScanOptionAllowDuplicatesKey: @NO,
    }];
    self.scanWindowOpen = YES;
    _isScanning = YES;
    [self _notify];
}

- (void)_closeScanWindow {
    if (!self.scanWindowOpen) return;
    if (self.central) [self.central stopScan];
    self.scanWindowOpen = NO;
    // leave _isScanning YES (we resume shortly); flips to NO only on full stop
}

- (void)_stopDutyCycle {
    if (self.dutyTimer) {
        dispatch_source_cancel(self.dutyTimer);
        self.dutyTimer = nil;
    }
    self.scanWindowOpen = NO;
}

- (void)_notify {
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:IPScannerStateDidChangeNotification
                                                            object:nil];
    });
}

- (NSString *)bluetoothStateDescription {
    switch (self.bluetoothState) {
        case CBManagerStatePoweredOn:     return @"Bluetooth on";
        case CBManagerStatePoweredOff:    return @"Bluetooth off — enable in Settings";
        case CBManagerStateUnauthorized:  return @"Bluetooth permission denied — grant in Settings";
        case CBManagerStateUnsupported:   return @"Bluetooth unsupported on this device";
        case CBManagerStateResetting:     return @"Bluetooth resetting…";
        case CBManagerStateUnknown:
        default:                          return @"Bluetooth state unknown";
    }
}

#pragma mark - CBCentralManagerDelegate

- (void)centralManagerDidUpdateState:(CBCentralManager *)central {
    _bluetoothState = central.state;
    [self _notify];
    if (central.state == CBManagerStatePoweredOn && self.wantScanning) {
        [self _beginDutyCycle];
    } else {
        [self _stopDutyCycle];
        _isScanning = NO;
    }
}

- (void)centralManager:(CBCentralManager *)central
 didDiscoverPeripheral:(CBPeripheral *)peripheral
     advertisementData:(NSDictionary<NSString *, id> *)advertisementData
                  RSSI:(NSNumber *)RSSI {
    @try {
        _cbCallbacks++;
        [IPDeviceStore shared].totalDiscoveryCount++;
        NSData *mfr = advertisementData[CBAdvertisementDataManufacturerDataKey];
        if (mfr.length >= 2) {
            _cbWithMfrData++;
            const uint8_t *b = mfr.bytes;
            // BLE company ID is little-endian; show as 0xHHHH big-endian for readability.
            NSString *cid = [NSString stringWithFormat:@"%02X%02X", b[1], b[0]];
            if (self.companyIDs.count < 40) [self.companyIDs addObject:cid];

            if (b[0] == 0x4C && b[1] == 0x00) {
                _cbApple++;
                NSString *uuid = peripheral.identifier.UUIDString;
                NSArray<IPContinuityRecord *> *records =
                    [IPContinuityDecoder decodeManufacturerData:mfr
                                                            mac:uuid
                                                           rssi:RSSI.integerValue];
                if (records.count > 0) {
                    [[IPDeviceStore shared] ingestRecords:records
                                            forIdentifier:uuid
                                                     rssi:RSSI.integerValue];
                }
            }
        }
    } @catch (NSException *e) {
        NSLog(@"[iprox] disc exception: %@", e);
    }
}

@end
