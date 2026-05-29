#import "IPSettingsViewController.h"
#import "IPScannerService.h"
#import "IPDeviceStore.h"

@interface IPSettingsViewController ()
@property (nonatomic, strong) UIStackView *stack;
@property (nonatomic, strong) UILabel *statsLabel;
@property (nonatomic, strong) NSTimer *refreshTimer;
@end

@implementation IPSettingsViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Settings";
    self.view.backgroundColor = [UIColor systemBackgroundColor];

    UIScrollView *scroll = [[UIScrollView alloc] init];
    scroll.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:scroll];

    self.stack = [[UIStackView alloc] init];
    self.stack.axis = UILayoutConstraintAxisVertical;
    self.stack.spacing = 16;
    self.stack.alignment = UIStackViewAlignmentFill;
    self.stack.layoutMarginsRelativeArrangement = YES;
    self.stack.directionalLayoutMargins = NSDirectionalEdgeInsetsMake(20, 20, 20, 20);
    self.stack.translatesAutoresizingMaskIntoConstraints = NO;
    [scroll addSubview:self.stack];

    UILayoutGuide *g = self.view.safeAreaLayoutGuide;
    [NSLayoutConstraint activateConstraints:@[
        [scroll.topAnchor constraintEqualToAnchor:g.topAnchor],
        [scroll.leadingAnchor constraintEqualToAnchor:g.leadingAnchor],
        [scroll.trailingAnchor constraintEqualToAnchor:g.trailingAnchor],
        [scroll.bottomAnchor constraintEqualToAnchor:g.bottomAnchor],

        [self.stack.topAnchor constraintEqualToAnchor:scroll.topAnchor],
        [self.stack.leadingAnchor constraintEqualToAnchor:scroll.leadingAnchor],
        [self.stack.trailingAnchor constraintEqualToAnchor:scroll.trailingAnchor],
        [self.stack.bottomAnchor constraintEqualToAnchor:scroll.bottomAnchor],
        [self.stack.widthAnchor constraintEqualToAnchor:scroll.widthAnchor],
    ]];

    [self _build];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    self.refreshTimer = [NSTimer scheduledTimerWithTimeInterval:1.0
                                                         target:self
                                                       selector:@selector(_refreshStats)
                                                       userInfo:nil
                                                        repeats:YES];
    [self _refreshStats];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [self.refreshTimer invalidate];
    self.refreshTimer = nil;
}

- (UIView *)_card:(NSString *)title body:(UIView *)body {
    UIView *card = [[UIView alloc] init];
    card.backgroundColor = [UIColor secondarySystemBackgroundColor];
    card.layer.cornerRadius = 12;
    card.translatesAutoresizingMaskIntoConstraints = NO;

    UILabel *t = [[UILabel alloc] init];
    t.text = title;
    t.font = [UIFont preferredFontForTextStyle:UIFontTextStyleHeadline];
    t.translatesAutoresizingMaskIntoConstraints = NO;

    body.translatesAutoresizingMaskIntoConstraints = NO;

    [card addSubview:t];
    [card addSubview:body];
    [NSLayoutConstraint activateConstraints:@[
        [t.topAnchor constraintEqualToAnchor:card.topAnchor constant:14],
        [t.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:16],
        [t.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-16],

        [body.topAnchor constraintEqualToAnchor:t.bottomAnchor constant:8],
        [body.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:16],
        [body.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-16],
        [body.bottomAnchor constraintEqualToAnchor:card.bottomAnchor constant:-14],
    ]];
    return card;
}

- (UILabel *)_bodyLabel:(NSString *)text {
    UILabel *l = [[UILabel alloc] init];
    l.text = text;
    l.font = [UIFont monospacedSystemFontOfSize:13 weight:UIFontWeightRegular];
    l.textColor = [UIColor secondaryLabelColor];
    l.numberOfLines = 0;
    return l;
}

- (void)_build {
    // Stats
    self.statsLabel = [self _bodyLabel:@"…"];
    [self.stack addArrangedSubview:[self _card:@"Live Stats" body:self.statsLabel]];

    // About
    NSString *aboutText =
        @"iProx decodes Apple Continuity BLE advertisements to surface nearby "
        @"iPhones, AirPods, Macs and FindMy beacons in real time. Bluetooth and "
        @"manufacturer-data fields are parsed locally on device — nothing leaves "
        @"the phone.\n\n"
        @"Audience: mobile security research, OSINT, counter-surveillance.\n"
        @"Phase: 0.2 — UIKit app, foreground scanning.\n"
        @"Source: jailbroken iOS only.";
    [self.stack addArrangedSubview:[self _card:@"About" body:[self _bodyLabel:aboutText]]];

    // Decoder support
    NSString *typesText =
        @"0x05 AirDrop          — sender phone+email hash prefixes\n"
        @"0x07 ProximityPairing — AirPods/Beats model + L/R/case battery\n"
        @"0x09 AirPlayTarget    — IPv4 + flags\n"
        @"0x0B WatchConnection  — state byte\n"
        @"0x0C Handoff          — IV/auth-tag/encrypted (not cracked)\n"
        @"0x0D TetheringTarget  — battery + cell signal\n"
        @"0x0E TetheringSource  — version flag\n"
        @"0x0F NearbyAction     — popup action type\n"
        @"0x10 NearbyInfo       — lock state, iOS version, iCloud bit\n"
        @"0x12 FindMy           — public key prefix, battery, lost mode";
    [self.stack addArrangedSubview:[self _card:@"Supported TLV types" body:[self _bodyLabel:typesText]]];

    // Clear button
    UIButton *clearBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    [clearBtn setTitle:@"  Clear All Captured Devices  " forState:UIControlStateNormal];
    [clearBtn setTitleColor:[UIColor systemRedColor] forState:UIControlStateNormal];
    clearBtn.titleLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleHeadline];
    [clearBtn addTarget:self action:@selector(_clear) forControlEvents:UIControlEventTouchUpInside];
    [self.stack addArrangedSubview:[self _card:@"Maintenance" body:clearBtn]];

    // Legal
    NSString *legal =
        @"iProx only passively receives BLE advertisements that nearby Apple "
        @"devices broadcast in the clear. It performs no active probing, no "
        @"injection, and no remote transmission. Use only in jurisdictions "
        @"where passive radio monitoring is lawful.";
    [self.stack addArrangedSubview:[self _card:@"Legal" body:[self _bodyLabel:legal]]];
}

- (void)_refreshStats {
    IPScannerService *s = [IPScannerService shared];
    IPDeviceStore *store = [IPDeviceStore shared];
    NSString *txt = [NSString stringWithFormat:
                     @"%@\nScanning: %@\nDevices tracked: %lu\nApple records: %lu\n\n"
                     @"DIAGNOSTICS\nBLE callbacks: %lu\nWith mfr-data: %lu\nApple (4C00): %lu\n"
                     @"Company IDs seen:\n%@",
                     s.bluetoothStateDescription,
                     s.isScanning ? @"yes" : @"no",
                     (unsigned long)[store snapshotSortedByRecency].count,
                     (unsigned long)store.totalAppleRecordCount,
                     (unsigned long)s.cbCallbacks,
                     (unsigned long)s.cbWithMfrData,
                     (unsigned long)s.cbApple,
                     [s recentCompanyIDsString]];
    self.statsLabel.text = txt;
}

- (void)_clear {
    [[IPDeviceStore shared] clearAll];
}

@end
