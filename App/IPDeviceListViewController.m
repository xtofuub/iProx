#import "IPDeviceListViewController.h"
#import "IPDeviceCell.h"
#import "IPDeviceEntry.h"
#import "IPDeviceStore.h"
#import "IPScannerService.h"
#import "IPDeviceDetailViewController.h"

static NSString * const kInfoBannerDismissedKey = @"iprox.info_banner_dismissed_v1";

@interface IPDeviceListViewController () <UITableViewDataSource, UITableViewDelegate>
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) NSArray<IPDeviceEntry *> *entries;
@property (nonatomic, strong) UILabel *statusLabel;
@property (nonatomic, strong) UIView *infoBanner;
@property (nonatomic, strong) UIView *emptyView;
@property (nonatomic, strong) NSTimer *refreshTimer;
@property (nonatomic, assign) BOOL hideTagged;
@end

@implementation IPDeviceListViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"iProx";
    self.view.backgroundColor = [UIColor systemBackgroundColor];

    self.navigationItem.rightBarButtonItem =
        [[UIBarButtonItem alloc] initWithImage:[UIImage systemImageNamed:@"trash"]
                                         style:UIBarButtonItemStylePlain
                                        target:self
                                        action:@selector(_clear)];
    self.navigationItem.leftBarButtonItem =
        [[UIBarButtonItem alloc] initWithImage:[UIImage systemImageNamed:@"line.3.horizontal.decrease.circle"]
                                         style:UIBarButtonItemStylePlain
                                        target:self
                                        action:@selector(_toggleHideTagged)];

    self.statusLabel = [[UILabel alloc] init];
    self.statusLabel.font = [UIFont monospacedSystemFontOfSize:11 weight:UIFontWeightRegular];
    self.statusLabel.textColor = [UIColor secondaryLabelColor];
    self.statusLabel.textAlignment = NSTextAlignmentCenter;
    self.statusLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.statusLabel];

    BOOL bannerDismissed = [[NSUserDefaults standardUserDefaults] boolForKey:kInfoBannerDismissedKey];
    self.infoBanner = bannerDismissed ? nil : [self _buildInfoBanner];
    if (self.infoBanner) {
        self.infoBanner.translatesAutoresizingMaskIntoConstraints = NO;
        [self.view addSubview:self.infoBanner];
    }

    self.tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    self.tableView.rowHeight = UITableViewAutomaticDimension;
    self.tableView.estimatedRowHeight = 84;
    self.tableView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.tableView registerClass:[IPDeviceCell class] forCellReuseIdentifier:[IPDeviceCell reuseID]];
    [self.view addSubview:self.tableView];

    self.emptyView = [self _buildEmptyView];
    self.emptyView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.emptyView];

    UILayoutGuide *g = self.view.safeAreaLayoutGuide;
    UIView *aboveTable = self.infoBanner ?: (UIView *)self.statusLabel;
    NSMutableArray *cons = [NSMutableArray arrayWithArray:@[
        [self.statusLabel.topAnchor constraintEqualToAnchor:g.topAnchor],
        [self.statusLabel.leadingAnchor constraintEqualToAnchor:g.leadingAnchor constant:12],
        [self.statusLabel.trailingAnchor constraintEqualToAnchor:g.trailingAnchor constant:-12],

        [self.tableView.topAnchor constraintEqualToAnchor:aboveTable.bottomAnchor constant:4],
        [self.tableView.leadingAnchor constraintEqualToAnchor:g.leadingAnchor],
        [self.tableView.trailingAnchor constraintEqualToAnchor:g.trailingAnchor],
        [self.tableView.bottomAnchor constraintEqualToAnchor:g.bottomAnchor],

        [self.emptyView.centerXAnchor constraintEqualToAnchor:self.tableView.centerXAnchor],
        [self.emptyView.centerYAnchor constraintEqualToAnchor:self.tableView.centerYAnchor],
        [self.emptyView.widthAnchor constraintLessThanOrEqualToAnchor:g.widthAnchor constant:-40],
    ]];
    if (self.infoBanner) {
        [cons addObjectsFromArray:@[
            [self.infoBanner.topAnchor constraintEqualToAnchor:self.statusLabel.bottomAnchor constant:6],
            [self.infoBanner.leadingAnchor constraintEqualToAnchor:g.leadingAnchor constant:12],
            [self.infoBanner.trailingAnchor constraintEqualToAnchor:g.trailingAnchor constant:-12],
        ]];
    }
    [NSLayoutConstraint activateConstraints:cons];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(_storeDidChange)
                                                 name:IPDeviceStoreDidChangeNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(_scannerStateChanged)
                                                 name:IPScannerStateDidChangeNotification
                                               object:nil];
    [self _refresh];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    self.refreshTimer = [NSTimer scheduledTimerWithTimeInterval:1.0
                                                         target:self
                                                       selector:@selector(_refresh)
                                                       userInfo:nil
                                                        repeats:YES];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [self.refreshTimer invalidate];
    self.refreshTimer = nil;
}

- (UIView *)_buildInfoBanner {
    UIView *card = [[UIView alloc] init];
    card.backgroundColor = [[UIColor systemBlueColor] colorWithAlphaComponent:0.12];
    card.layer.cornerRadius = 10;

    UILabel *txt = [[UILabel alloc] init];
    txt.text = @"iProx can't see the iPhone it's running on.\nTag your OTHER Apple devices (AirPods, Watch, Mac, second iPhone) to skip them.";
    txt.font = [UIFont systemFontOfSize:12];
    txt.textColor = [UIColor labelColor];
    txt.numberOfLines = 0;
    txt.translatesAutoresizingMaskIntoConstraints = NO;

    UIButton *dismiss = [UIButton buttonWithType:UIButtonTypeSystem];
    [dismiss setImage:[UIImage systemImageNamed:@"xmark.circle.fill"] forState:UIControlStateNormal];
    dismiss.tintColor = [UIColor systemBlueColor];
    dismiss.translatesAutoresizingMaskIntoConstraints = NO;
    [dismiss addTarget:self action:@selector(_dismissInfoBanner) forControlEvents:UIControlEventTouchUpInside];

    [card addSubview:txt];
    [card addSubview:dismiss];
    [NSLayoutConstraint activateConstraints:@[
        [txt.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:12],
        [txt.topAnchor constraintEqualToAnchor:card.topAnchor constant:10],
        [txt.bottomAnchor constraintEqualToAnchor:card.bottomAnchor constant:-10],
        [txt.trailingAnchor constraintEqualToAnchor:dismiss.leadingAnchor constant:-8],

        [dismiss.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-8],
        [dismiss.centerYAnchor constraintEqualToAnchor:card.centerYAnchor],
        [dismiss.widthAnchor constraintEqualToConstant:24],
        [dismiss.heightAnchor constraintEqualToConstant:24],
    ]];
    return card;
}

- (void)_dismissInfoBanner {
    [[NSUserDefaults standardUserDefaults] setBool:YES forKey:kInfoBannerDismissedKey];
    [UIView animateWithDuration:0.25 animations:^{
        self.infoBanner.alpha = 0;
    } completion:^(BOOL fin) {
        [self.infoBanner removeFromSuperview];
        self.infoBanner = nil;
    }];
}

- (UIView *)_buildEmptyView {
    UIStackView *s = [[UIStackView alloc] init];
    s.axis = UILayoutConstraintAxisVertical;
    s.spacing = 12;
    s.alignment = UIStackViewAlignmentCenter;

    UIImageView *iv = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"dot.radiowaves.left.and.right"]];
    iv.tintColor = [UIColor tertiaryLabelColor];
    iv.contentMode = UIViewContentModeScaleAspectFit;
    [iv.widthAnchor constraintEqualToConstant:64].active = YES;
    [iv.heightAnchor constraintEqualToConstant:64].active = YES;

    UILabel *t = [[UILabel alloc] init];
    t.text = @"Scanning for Apple devices…";
    t.font = [UIFont preferredFontForTextStyle:UIFontTextStyleHeadline];
    t.textColor = [UIColor secondaryLabelColor];
    t.textAlignment = NSTextAlignmentCenter;

    UILabel *sub = [[UILabel alloc] init];
    sub.text = @"Bring an iPhone, AirPods or Mac within ~10 m.\nUnlock and use AirDrop / Handoff to provoke richer adverts.";
    sub.font = [UIFont systemFontOfSize:13];
    sub.textColor = [UIColor tertiaryLabelColor];
    sub.numberOfLines = 0;
    sub.textAlignment = NSTextAlignmentCenter;

    [s addArrangedSubview:iv];
    [s addArrangedSubview:t];
    [s addArrangedSubview:sub];
    return s;
}

- (void)_storeDidChange { [self _refresh]; }
- (void)_scannerStateChanged { [self _refresh]; }

- (void)_refresh {
    NSArray *all = [[IPDeviceStore shared] snapshotSortedByRecency];
    NSUInteger taggedCount = 0;
    if (self.hideTagged) {
        NSMutableArray *filt = [NSMutableArray arrayWithCapacity:all.count];
        for (IPDeviceEntry *e in all) {
            if (e.tagged) { taggedCount++; continue; }
            [filt addObject:e];
        }
        self.entries = filt;
    } else {
        self.entries = all;
        for (IPDeviceEntry *e in all) if (e.tagged) taggedCount++;
    }
    IPScannerService *s = [IPScannerService shared];
    NSString *filtTag = self.hideTagged ? [NSString stringWithFormat:@"  •  %lu hidden", (unsigned long)taggedCount] : @"";
    NSString *line = [NSString stringWithFormat:@"%@  •  %lu devices  •  %lu adverts%@",
                      s.bluetoothStateDescription,
                      (unsigned long)self.entries.count,
                      (unsigned long)[IPDeviceStore shared].totalAppleRecordCount,
                      filtTag];
    self.statusLabel.text = line;
    self.emptyView.hidden = self.entries.count > 0;
    [self.tableView reloadData];
}

- (void)_toggleHideTagged {
    self.hideTagged = !self.hideTagged;
    NSString *icon = self.hideTagged ? @"line.3.horizontal.decrease.circle.fill"
                                     : @"line.3.horizontal.decrease.circle";
    self.navigationItem.leftBarButtonItem.image = [UIImage systemImageNamed:icon];
    [self _refresh];
}

- (void)_clear {
    UIAlertController *ac = [UIAlertController alertControllerWithTitle:@"Clear history?"
                                                                message:@"Removes all captured device entries."
                                                         preferredStyle:UIAlertControllerStyleAlert];
    [ac addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    [ac addAction:[UIAlertAction actionWithTitle:@"Clear" style:UIAlertActionStyleDestructive handler:^(UIAlertAction * _Nonnull a) {
        [[IPDeviceStore shared] clearAll];
    }]];
    [self presentViewController:ac animated:YES completion:nil];
}

#pragma mark - Table

- (NSInteger)tableView:(UITableView *)t numberOfRowsInSection:(NSInteger)s {
    return self.entries.count;
}

- (UITableViewCell *)tableView:(UITableView *)t cellForRowAtIndexPath:(NSIndexPath *)ip {
    IPDeviceCell *cell = [t dequeueReusableCellWithIdentifier:[IPDeviceCell reuseID] forIndexPath:ip];
    [cell configureWithEntry:self.entries[ip.row]];
    return cell;
}

- (void)tableView:(UITableView *)t didSelectRowAtIndexPath:(NSIndexPath *)ip {
    [t deselectRowAtIndexPath:ip animated:YES];
    IPDeviceDetailViewController *vc = [[IPDeviceDetailViewController alloc] init];
    vc.entry = self.entries[ip.row];
    [self.navigationController pushViewController:vc animated:YES];
}

- (UISwipeActionsConfiguration *)tableView:(UITableView *)tv
trailingSwipeActionsConfigurationForRowAtIndexPath:(NSIndexPath *)ip {
    if (ip.row >= self.entries.count) return nil;
    IPDeviceEntry *e = self.entries[ip.row];
    NSString *title = e.tagged ? @"Untag" : @"Tag as Mine";
    UIContextualAction *act = [UIContextualAction
        contextualActionWithStyle:UIContextualActionStyleNormal
        title:title
        handler:^(UIContextualAction *a, UIView *v, void (^done)(BOOL)) {
            [[IPDeviceStore shared] toggleTagForIdentifier:e.identifier];
            // Store ingest -> notify -> _refresh is async; flip the local
            // snapshot in place + reload the single row so the user sees
            // the change instantly. The next throttled refresh confirms.
            e.tagged = !e.tagged;
            if (ip.row < self.entries.count) {
                [tv reloadRowsAtIndexPaths:@[ip]
                         withRowAnimation:UITableViewRowAnimationFade];
            }
            done(YES);
        }];
    act.backgroundColor = e.tagged ? [UIColor systemGrayColor] : [UIColor systemOrangeColor];
    act.image = [UIImage systemImageNamed:e.tagged ? @"person.crop.circle.badge.xmark"
                                                   : @"person.crop.circle.badge.checkmark"];
    return [UISwipeActionsConfiguration configurationWithActions:@[act]];
}

@end
