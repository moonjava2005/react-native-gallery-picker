//
//

#import <UIKit/UIKit.h>

#import "RNVideoIconView.h"
#import "RNSlomoIconView.h"

@interface RNVideoIndicatorView : UIView

@property (nonatomic, weak) IBOutlet UILabel *timeLabel;
@property (nonatomic, weak) IBOutlet RNVideoIconView *videoIcon;
@property (nonatomic, weak) IBOutlet RNSlomoIconView *slomoIcon;


@end
