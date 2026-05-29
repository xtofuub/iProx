#import "IPAppDelegate.h"
#import "IPDeviceListViewController.h"
#import "IPSettingsViewController.h"
#import "IPScannerService.h"

@implementation IPAppDelegate

- (BOOL)application:(UIApplication *)application
didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    self.window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];

    IPDeviceListViewController *liveVC = [[IPDeviceListViewController alloc] init];
    UINavigationController *liveNav = [[UINavigationController alloc] initWithRootViewController:liveVC];
    liveNav.tabBarItem = [[UITabBarItem alloc] initWithTitle:@"Live"
                                                       image:[UIImage systemImageNamed:@"dot.radiowaves.left.and.right"]
                                                         tag:0];

    IPSettingsViewController *settingsVC = [[IPSettingsViewController alloc] init];
    UINavigationController *settingsNav = [[UINavigationController alloc] initWithRootViewController:settingsVC];
    settingsNav.tabBarItem = [[UITabBarItem alloc] initWithTitle:@"Settings"
                                                           image:[UIImage systemImageNamed:@"gearshape.fill"]
                                                             tag:1];

    UITabBarController *tabs = [[UITabBarController alloc] init];
    tabs.viewControllers = @[liveNav, settingsNav];
    if (@available(iOS 15.0, *)) {
        UITabBarAppearance *ap = [[UITabBarAppearance alloc] init];
        [ap configureWithDefaultBackground];
        tabs.tabBar.standardAppearance = ap;
        tabs.tabBar.scrollEdgeAppearance = ap;
    }

    self.window.rootViewController = tabs;
    self.window.tintColor = [UIColor systemPurpleColor];
    [self.window makeKeyAndVisible];

    // Start scanning only after the UI is on screen, so a Bluetooth issue
    // can never block first paint. Gentle duty-cycle scan inside the service.
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        @try {
            [[IPScannerService shared] start];
        } @catch (NSException *e) {
            NSLog(@"[iprox] scanner start exception: %@", e);
        }
    });

    return YES;
}

// Stop scanning when backgrounded — never hold the radio while not visible.
- (void)applicationDidEnterBackground:(UIApplication *)application {
    [[IPScannerService shared] stop];
}

- (void)applicationWillResignActive:(UIApplication *)application {
    [[IPScannerService shared] stop];
}

- (void)applicationDidBecomeActive:(UIApplication *)application {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        [[IPScannerService shared] start];
    });
}

@end
