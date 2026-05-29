#import "IPDeviceCell.h"
#import "IPDeviceEntry.h"

@interface IPDeviceCell ()
@property (nonatomic, strong) UIView *accentBar;
@property (nonatomic, strong) UIImageView *iconView;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *subtitleLabel;
@property (nonatomic, strong) UIStackView *badgesStack;
@property (nonatomic, strong) UILabel *rssiLabel;
@property (nonatomic, strong) UIProgressView *rssiBar;
@property (nonatomic, strong) UILabel *seenLabel;
@end

@implementation IPDeviceCell

+ (NSString *)reuseID { return @"IPDeviceCell"; }

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    if ((self = [super initWithStyle:UITableViewCellStyleDefault reuseIdentifier:reuseIdentifier])) {
        self.selectionStyle = UITableViewCellSelectionStyleDefault;
        [self _build];
    }
    return self;
}

- (void)_build {
    self.accentBar = [[UIView alloc] init];
    self.accentBar.translatesAutoresizingMaskIntoConstraints = NO;
    self.accentBar.backgroundColor = [UIColor clearColor];

    self.iconView = [[UIImageView alloc] init];
    self.iconView.translatesAutoresizingMaskIntoConstraints = NO;
    self.iconView.contentMode = UIViewContentModeScaleAspectFit;
    self.iconView.tintColor = [UIColor systemPurpleColor];

    self.titleLabel = [[UILabel alloc] init];
    self.titleLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleHeadline];
    self.titleLabel.translatesAutoresizingMaskIntoConstraints = NO;

    self.subtitleLabel = [[UILabel alloc] init];
    self.subtitleLabel.font = [UIFont monospacedSystemFontOfSize:13 weight:UIFontWeightRegular];
    self.subtitleLabel.textColor = [UIColor secondaryLabelColor];
    self.subtitleLabel.numberOfLines = 2;
    self.subtitleLabel.translatesAutoresizingMaskIntoConstraints = NO;

    self.badgesStack = [[UIStackView alloc] init];
    self.badgesStack.axis = UILayoutConstraintAxisHorizontal;
    self.badgesStack.spacing = 4;
    self.badgesStack.alignment = UIStackViewAlignmentCenter;
    self.badgesStack.translatesAutoresizingMaskIntoConstraints = NO;

    self.rssiLabel = [[UILabel alloc] init];
    self.rssiLabel.font = [UIFont monospacedSystemFontOfSize:11 weight:UIFontWeightMedium];
    self.rssiLabel.textColor = [UIColor tertiaryLabelColor];
    self.rssiLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.rssiLabel.textAlignment = NSTextAlignmentRight;

    self.rssiBar = [[UIProgressView alloc] initWithProgressViewStyle:UIProgressViewStyleDefault];
    self.rssiBar.translatesAutoresizingMaskIntoConstraints = NO;
    self.rssiBar.progressTintColor = [UIColor systemGreenColor];
    self.rssiBar.trackTintColor = [UIColor systemFillColor];

    self.seenLabel = [[UILabel alloc] init];
    self.seenLabel.font = [UIFont systemFontOfSize:11];
    self.seenLabel.textColor = [UIColor tertiaryLabelColor];
    self.seenLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.seenLabel.textAlignment = NSTextAlignmentRight;

    [self.contentView addSubview:self.accentBar];
    [self.contentView addSubview:self.iconView];
    [self.contentView addSubview:self.titleLabel];
    [self.contentView addSubview:self.subtitleLabel];
    [self.contentView addSubview:self.badgesStack];
    [self.contentView addSubview:self.rssiLabel];
    [self.contentView addSubview:self.rssiBar];
    [self.contentView addSubview:self.seenLabel];

    UILayoutGuide *g = self.contentView.layoutMarginsGuide;
    [NSLayoutConstraint activateConstraints:@[
        [self.accentBar.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor],
        [self.accentBar.topAnchor constraintEqualToAnchor:self.contentView.topAnchor],
        [self.accentBar.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor],
        [self.accentBar.widthAnchor constraintEqualToConstant:4],

        [self.iconView.leadingAnchor constraintEqualToAnchor:g.leadingAnchor],
        [self.iconView.centerYAnchor constraintEqualToAnchor:g.centerYAnchor],
        [self.iconView.widthAnchor constraintEqualToConstant:36],
        [self.iconView.heightAnchor constraintEqualToConstant:36],

        [self.titleLabel.leadingAnchor constraintEqualToAnchor:self.iconView.trailingAnchor constant:12],
        [self.titleLabel.topAnchor constraintEqualToAnchor:g.topAnchor],
        [self.titleLabel.trailingAnchor constraintLessThanOrEqualToAnchor:self.rssiLabel.leadingAnchor constant:-8],

        [self.subtitleLabel.leadingAnchor constraintEqualToAnchor:self.titleLabel.leadingAnchor],
        [self.subtitleLabel.topAnchor constraintEqualToAnchor:self.titleLabel.bottomAnchor constant:2],
        [self.subtitleLabel.trailingAnchor constraintLessThanOrEqualToAnchor:self.rssiLabel.leadingAnchor constant:-8],

        [self.badgesStack.leadingAnchor constraintEqualToAnchor:self.titleLabel.leadingAnchor],
        [self.badgesStack.topAnchor constraintEqualToAnchor:self.subtitleLabel.bottomAnchor constant:4],
        [self.badgesStack.bottomAnchor constraintEqualToAnchor:g.bottomAnchor],
        [self.badgesStack.trailingAnchor constraintLessThanOrEqualToAnchor:self.rssiBar.leadingAnchor constant:-8],

        [self.rssiLabel.topAnchor constraintEqualToAnchor:g.topAnchor],
        [self.rssiLabel.trailingAnchor constraintEqualToAnchor:g.trailingAnchor],
        [self.rssiLabel.widthAnchor constraintEqualToConstant:60],

        [self.rssiBar.topAnchor constraintEqualToAnchor:self.rssiLabel.bottomAnchor constant:4],
        [self.rssiBar.trailingAnchor constraintEqualToAnchor:g.trailingAnchor],
        [self.rssiBar.widthAnchor constraintEqualToConstant:80],

        [self.seenLabel.topAnchor constraintEqualToAnchor:self.rssiBar.bottomAnchor constant:4],
        [self.seenLabel.trailingAnchor constraintEqualToAnchor:g.trailingAnchor],
        [self.seenLabel.widthAnchor constraintEqualToConstant:80],
    ]];
}

- (UIImage *)_iconForCategory:(NSString *)cat {
    NSDictionary *map = @{
        @"AirPods":         @"airpodspro",
        @"iPhone":          @"iphone",
        @"Apple Watch":     @"applewatch",
        @"AirPlay Target":  @"airplayvideo",
        @"AirDrop Sender":  @"square.and.arrow.up",
        @"FindMy Beacon":   @"location.circle",
        @"Apple Device":    @"applelogo",
        @"Mac":             @"laptopcomputer",
    };
    NSString *name = map[cat] ?: @"applelogo";
    return [UIImage systemImageNamed:name];
}

- (UILabel *)_badgeLabel:(NSString *)text bg:(UIColor *)bg {
    UILabel *lbl = [[UILabel alloc] init];
    lbl.text = [NSString stringWithFormat:@"  %@  ", text];
    lbl.font = [UIFont systemFontOfSize:10 weight:UIFontWeightSemibold];
    lbl.textColor = [UIColor whiteColor];
    lbl.backgroundColor = bg;
    lbl.layer.cornerRadius = 6;
    lbl.layer.masksToBounds = YES;
    lbl.translatesAutoresizingMaskIntoConstraints = NO;
    [lbl.heightAnchor constraintEqualToConstant:18].active = YES;
    return lbl;
}

- (void)configureWithEntry:(IPDeviceEntry *)entry {
    NSString *cat  = [entry inferredDeviceCategory];
    NSString *name = [entry bestDisplayName];
    self.iconView.image = [self _iconForCategory:cat];
    self.iconView.tintColor = entry.tagged ? [UIColor systemOrangeColor]
                                           : [UIColor systemPurpleColor];
    self.accentBar.backgroundColor = entry.tagged ? [UIColor systemOrangeColor]
                                                  : [UIColor clearColor];
    self.contentView.backgroundColor = entry.tagged
        ? [[UIColor systemOrangeColor] colorWithAlphaComponent:0.18]
        : [UIColor clearColor];

    // If we got a real device name, lead with it and use the category as the
    // first line of the subtitle. Otherwise the category itself is the title.
    NSString *model = [entry inferredModelLabel];
    if (name.length > 0 && ![name isEqualToString:cat]) {
        self.titleLabel.text = name;
        if (model.length > 0 && ![model isEqualToString:@"--"]) {
            self.subtitleLabel.text = [NSString stringWithFormat:@"%@  •  %@", cat, model];
        } else {
            self.subtitleLabel.text = cat;
        }
    } else {
        self.titleLabel.text = cat;
        self.subtitleLabel.text = model;
    }

    // Badges
    for (UIView *v in [self.badgesStack.arrangedSubviews copy]) {
        [self.badgesStack removeArrangedSubview:v];
        [v removeFromSuperview];
    }
    if (entry.tagged) {
        [self.badgesStack addArrangedSubview:[self _badgeLabel:@"MINE"
                                                            bg:[UIColor systemOrangeColor]]];
    }
    for (NSString *b in [entry activeBadges]) {
        UIColor *bg = [UIColor systemBlueColor];
        if ([b isEqualToString:@"Lock"]) bg = [UIColor systemGrayColor];
        else if ([b isEqualToString:@"FindMy"]) bg = [UIColor systemOrangeColor];
        else if ([b isEqualToString:@"AirDrop"]) bg = [UIColor systemTealColor];
        else if ([b isEqualToString:@"AirPods"]) bg = [UIColor systemIndigoColor];
        else if ([b isEqualToString:@"iCloud"]) bg = [UIColor systemPurpleColor];
        else if ([b isEqualToString:@"Handoff"]) bg = [UIColor systemPinkColor];
        else if ([b isEqualToString:@"Siri"]) bg = [UIColor systemRedColor];
        else if ([b isEqualToString:@"Hotspot"]) bg = [UIColor systemGreenColor];
        else if ([b isEqualToString:@"Tether"]) bg = [UIColor systemGreenColor];
        else if ([b isEqualToString:@"Action"]) bg = [UIColor systemYellowColor];
        [self.badgesStack addArrangedSubview:[self _badgeLabel:b bg:bg]];
    }

    NSInteger rssi = entry.lastRSSI;
    self.rssiLabel.text = [NSString stringWithFormat:@"%ld dBm", (long)rssi];
    // Convert RSSI [-100,-30] → [0,1]
    float frac = (float)(MAX(-100, MIN(-30, (int)rssi)) + 100) / 70.0f;
    self.rssiBar.progress = frac;
    self.rssiBar.progressTintColor = frac > 0.6 ? [UIColor systemGreenColor]
                                                : frac > 0.3 ? [UIColor systemYellowColor]
                                                             : [UIColor systemRedColor];

    NSTimeInterval age = -[entry.lastSeen timeIntervalSinceNow];
    if (age < 2) self.seenLabel.text = @"now";
    else if (age < 60) self.seenLabel.text = [NSString stringWithFormat:@"%.0fs", age];
    else self.seenLabel.text = [NSString stringWithFormat:@"%.0fm", age / 60.0];
}

@end
