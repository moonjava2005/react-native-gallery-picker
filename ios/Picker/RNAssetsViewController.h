//
//

#import <UIKit/UIKit.h>

@class RNImagePickerController;
@class PHAssetCollection;

@interface RNAssetsViewController : UICollectionViewController

@property (nonatomic, weak) RNImagePickerController *imagePickerController;
@property (nonatomic, strong) PHAssetCollection *assetCollection;

@end
