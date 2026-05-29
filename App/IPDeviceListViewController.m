#import "IPDeviceListViewController.h"
#import "IPDeviceCell.h"
#import "IPDeviceEntry.h"
#import "IPDeviceStore.h"
#import "IPScannerService.h"
#import "IPDeviceDetailViewController.h"

@interface IPDeviceListViewController () <UITableViewDataSource, UITableViewDelegate>
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) NSArray<IPDeviceEntry *> *entries;
@property (nonatomic, strong) UILabel *statusLabel;
@property (nonatomic, strong) UIView *emptyView;
@property (nonatomic, strong) NSTimer *refreshTimer;
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

    self.statusLabel = [[UILabel alloc] init];
    self.statusLabel.font = [UIFont monospacedSystemFontOfSize:11 weight:UIFontWeightRegular];
    self.statusLabel.textColor = [UIColor secondaryLabelColor];
    self.statusLabel.textAlignment = NSTextAlignmentCenter;
    self.statusLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.statusLabel];

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
    [NSLayoutConstraint activateConstraints:@[
        [self.statusLabel.topAnchor constraintEqualToAnchor:g.topAnchor],
        [self.statusLabel.leadingAnchor constraintEqualToAnchor:g.leadingAnchor constant:12],
        [self.statusLabel.trailingAnchor constraintEqualToAnchor:g.trailingAnchor constant:-12],

        [self.tableView.topAnchor constraintEqualToAnchor:self.statusLabel.bottomAnchor constant:4],
        [self.tableView.leadingAnchor constraintEqualToAnchor:g.leadingAnchor],
        [self.tableView.trailingAnchor constraintEqualToAnchor:g.trailingAnchor],
        [self.tableView.bottomAnchor constraintEqualToAnchor:g.bottomAnchor],

        [self.emptyView.centerXAnchor constraintEqualToAnchor:self.tableView.centerXAnchor],
        [self.emptyView.centerYAnchor constraintEqualToAnchor:self.tableView.centerYAnchor],
        [self.emptyView.widthAnchor constraintLessThanOrEqualToAnchor:g.widthAnchor constant:-40],
    ]];

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
    self.entries = [[IPDeviceStore shared] snapshotSortedByRecency];
    IPScannerService *s = [IPScannerService shared];
    NSString *line = [NSString stringWithFormat:@"%@  •  %lu devices  •  %lu adverts",
                      s.bluetoothStateDescription,
                      (unsigned long)self.entries.count,
                      (unsigned long)[IPDeviceStore shared].totalAppleRecordCount];
    self.statusLabel.text = line;
    self.emptyView.hidden = self.entries.count > 0;
    [self.tableView reloadData];
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

@end
