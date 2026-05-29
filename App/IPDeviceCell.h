#import <UIKit/UIKit.h>
@class IPDeviceEntry;

@interface IPDeviceCell : UITableViewCell
+ (NSString *)reuseID;
- (void)configureWithEntry:(IPDeviceEntry *)entry;
@end
