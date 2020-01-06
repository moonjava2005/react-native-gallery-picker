//
//

#import "RNAssetCell.h"

@interface RNAssetCell ()

@property (weak, nonatomic) IBOutlet UIView *overlayView;

@end

@implementation RNAssetCell

- (void)setSelected:(BOOL)selected
{
    [super setSelected:selected];
    
    // Show/hide overlay view
    self.overlayView.hidden = !(selected && self.showsOverlayViewWhenSelected);
}

@end
