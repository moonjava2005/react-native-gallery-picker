//
//

#import <UIKit/UIKit.h>
#import <Photos/Photos.h>

@class RNImagePickerController;

@protocol RNImagePickerControllerDelegate <NSObject>

@optional
- (void)qb_imagePickerController:(RNImagePickerController *)imagePickerController didFinishPickingAssets:(NSArray *)assets;
- (void)qb_imagePickerControllerDidCancel:(RNImagePickerController *)imagePickerController;

- (BOOL)qb_imagePickerController:(RNImagePickerController *)imagePickerController shouldSelectAsset:(PHAsset *)asset;
- (void)qb_imagePickerController:(RNImagePickerController *)imagePickerController didSelectAsset:(PHAsset *)asset;
- (void)qb_imagePickerController:(RNImagePickerController *)imagePickerController didDeselectAsset:(PHAsset *)asset;

@end

typedef NS_ENUM(NSUInteger, RNImagePickerMediaType) {
    RNImagePickerMediaTypeAny = 0,
    RNImagePickerMediaTypeImage,
    RNImagePickerMediaTypeVideo
};

@interface RNImagePickerController : UIViewController

- (instancetype)initWithSelections:(NSArray*)selection;
- (NSUInteger) getSelectedAssetCount;
- (BOOL) isContainsAsset:(PHAsset*) asset;
- (void) removeSelectionAtIndex:(NSUInteger)index;
- (void) removeSelection:(PHAsset*)asset;
- (void) addAsset:(PHAsset*) asset;
- (NSArray*) getSelectedAssets;
- (NSObject*) getSelectionAtIndex:(NSUInteger)index;
@property (nonatomic, weak) id<RNImagePickerControllerDelegate> delegate;

@property (nonatomic, strong, readonly) NSMutableOrderedSet *selectedAssets;
@property (nonatomic, strong,readonly) NSMutableOrderedSet *currentSelections;

@property (nonatomic, copy) NSArray *assetCollectionSubtypes;
@property (nonatomic, assign) RNImagePickerMediaType mediaType;

@property (nonatomic, assign) BOOL allowsMultipleSelection;
@property (nonatomic, assign) NSUInteger minimumNumberOfSelection;
@property (nonatomic, assign) NSUInteger maximumNumberOfSelection;

@property (nonatomic, copy) NSString *prompt;
@property (nonatomic, assign) BOOL showsNumberOfSelectedAssets;

@property (nonatomic, assign) NSUInteger numberOfColumnsInPortrait;
@property (nonatomic, assign) NSUInteger numberOfColumnsInLandscape;

@end
