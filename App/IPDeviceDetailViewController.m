#import "IPDeviceDetailViewController.h"
#import "IPDeviceEntry.h"
#import "../Daemon/ContinuityRecord.h"

@interface IPDeviceDetailViewController ()
@property (nonatomic, strong) UIScrollView *scroll;
@property (nonatomic, strong) UIStackView *stack;
@end

@implementation IPDeviceDetailViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor systemBackgroundColor];
    self.title = [self.entry inferredDeviceCategory] ?: @"Device";

    self.scroll = [[UIScrollView alloc] init];
    self.scroll.translatesAutoresizingMaskIntoConstraints = NO;
    self.scroll.alwaysBounceVertical = YES;
    [self.view addSubview:self.scroll];

    self.stack = [[UIStackView alloc] init];
    self.stack.axis = UILayoutConstraintAxisVertical;
    self.stack.spacing = 12;
    self.stack.alignment = UIStackViewAlignmentFill;
    self.stack.layoutMarginsRelativeArrangement = YES;
    self.stack.directionalLayoutMargins = NSDirectionalEdgeInsetsMake(16, 16, 16, 16);
    self.stack.translatesAutoresizingMaskIntoConstraints = NO;
    [self.scroll addSubview:self.stack];

    UILayoutGuide *g = self.view.safeAreaLayoutGuide;
    [NSLayoutConstraint activateConstraints:@[
        [self.scroll.topAnchor constraintEqualToAnchor:g.topAnchor],
        [self.scroll.leadingAnchor constraintEqualToAnchor:g.leadingAnchor],
        [self.scroll.trailingAnchor constraintEqualToAnchor:g.trailingAnchor],
        [self.scroll.bottomAnchor constraintEqualToAnchor:g.bottomAnchor],

        [self.stack.topAnchor constraintEqualToAnchor:self.scroll.topAnchor],
        [self.stack.leadingAnchor constraintEqualToAnchor:self.scroll.leadingAnchor],
        [self.stack.trailingAnchor constraintEqualToAnchor:self.scroll.trailingAnchor],
        [self.stack.bottomAnchor constraintEqualToAnchor:self.scroll.bottomAnchor],
        [self.stack.widthAnchor constraintEqualToAnchor:self.scroll.widthAnchor],
    ]];

    [self _build];
}

- (UIView *)_card:(NSString *)title body:(NSString *)body {
    UIView *card = [[UIView alloc] init];
    card.backgroundColor = [UIColor secondarySystemBackgroundColor];
    card.layer.cornerRadius = 12;
    card.translatesAutoresizingMaskIntoConstraints = NO;

    UILabel *t = [[UILabel alloc] init];
    t.text = title;
    t.font = [UIFont preferredFontForTextStyle:UIFontTextStyleHeadline];
    t.translatesAutoresizingMaskIntoConstraints = NO;

    UILabel *b = [[UILabel alloc] init];
    b.text = body;
    b.font = [UIFont monospacedSystemFontOfSize:13 weight:UIFontWeightRegular];
    b.numberOfLines = 0;
    b.textColor = [UIColor secondaryLabelColor];
    b.translatesAutoresizingMaskIntoConstraints = NO;

    [card addSubview:t];
    [card addSubview:b];

    [NSLayoutConstraint activateConstraints:@[
        [t.topAnchor constraintEqualToAnchor:card.topAnchor constant:12],
        [t.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:14],
        [t.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-14],

        [b.topAnchor constraintEqualToAnchor:t.bottomAnchor constant:6],
        [b.leadingAnchor constraintEqualToAnchor:t.leadingAnchor],
        [b.trailingAnchor constraintEqualToAnchor:t.trailingAnchor],
        [b.bottomAnchor constraintEqualToAnchor:card.bottomAnchor constant:-12],
    ]];
    return card;
}

- (void)_build {
    IPDeviceEntry *e = self.entry;
    NSDateFormatter *df = [[NSDateFormatter alloc] init];
    df.dateStyle = NSDateFormatterShortStyle;
    df.timeStyle = NSDateFormatterMediumStyle;

    NSString *summary = [NSString stringWithFormat:
                         @"UUID: %@\nRSSI: %ld dBm\nFirst seen: %@\nLast seen: %@\nUpdates: %lu",
                         e.identifier ?: @"-",
                         (long)e.lastRSSI,
                         [df stringFromDate:e.firstSeen],
                         [df stringFromDate:e.lastSeen],
                         (unsigned long)e.updateCount];
    [self.stack addArrangedSubview:[self _card:@"Summary" body:summary]];

    // Group by type — show most recent per type
    NSMutableDictionary<NSNumber *, IPContinuityRecord *> *latestByType = [NSMutableDictionary dictionary];
    for (IPContinuityRecord *r in e.records) {
        latestByType[@(r.type)] = r;
    }

    NSArray *sortedTypes = [latestByType.allKeys sortedArrayUsingSelector:@selector(compare:)];
    for (NSNumber *tNum in sortedTypes) {
        IPContinuityRecord *r = latestByType[tNum];
        NSMutableString *body = [NSMutableString string];
        [r.fields enumerateKeysAndObjectsUsingBlock:^(NSString *k, id v, BOOL *stop) {
            [body appendFormat:@"%@: %@\n", k, v];
        }];
        if (body.length > 0 && [body characterAtIndex:body.length - 1] == '\n') {
            [body deleteCharactersInRange:NSMakeRange(body.length - 1, 1)];
        }
        NSString *cardTitle = [NSString stringWithFormat:@"%@ (0x%02X)", r.typeName, r.type];
        [self.stack addArrangedSubview:[self _card:cardTitle body:body]];
    }

    // Raw recent
    NSMutableString *rawLog = [NSMutableString string];
    NSInteger start = MAX(0, (NSInteger)e.records.count - 12);
    for (NSInteger i = start; i < (NSInteger)e.records.count; i++) {
        IPContinuityRecord *r = e.records[i];
        [rawLog appendFormat:@"%@  type=0x%02X  raw=%@\n",
            [df stringFromDate:r.timestamp],
            r.type,
            [self _hexFromData:r.rawValue]];
    }
    if (rawLog.length > 0) {
        [self.stack addArrangedSubview:[self _card:@"Recent raw TLV" body:rawLog]];
    }
}

- (NSString *)_hexFromData:(NSData *)d {
    NSMutableString *s = [NSMutableString stringWithCapacity:d.length * 2];
    const uint8_t *b = d.bytes;
    for (NSUInteger i = 0; i < d.length; i++) [s appendFormat:@"%02x", b[i]];
    return s;
}

@end
