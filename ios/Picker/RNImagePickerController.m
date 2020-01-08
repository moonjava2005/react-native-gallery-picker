//
//

#import "RNImagePickerController.h"
#import <Photos/Photos.h>

// ViewControllers
#import "RNAlbumsViewController.h"

@interface RNImagePickerController ()

@property (nonatomic, strong) UINavigationController *albumsNavigationController;

@property (nonatomic, strong) NSBundle *assetBundle;

@end

@implementation RNImagePickerController

- (instancetype)initWithSelections:(NSArray*)selections
{
    self = [super init];
    
    if (self) {
        // Set default values
        self.assetCollectionSubtypes = @[
                                         @(PHAssetCollectionSubtypeSmartAlbumUserLibrary),
                                         @(PHAssetCollectionSubtypeAlbumMyPhotoStream),
                                         @(PHAssetCollectionSubtypeSmartAlbumPanoramas),
                                         @(PHAssetCollectionSubtypeSmartAlbumVideos),
                                         @(PHAssetCollectionSubtypeSmartAlbumBursts)
                                         ];
        self.minimumNumberOfSelection = 1;
        self.numberOfColumnsInPortrait = 4;
        self.numberOfColumnsInLandscape = 7;
        
        _selectedAssets = [NSMutableOrderedSet orderedSet];
        _currentSelections=[NSMutableOrderedSet orderedSet];
        if(selections!=nil&&![selections isEqual:[NSNull null]]&&[selections count]>0)
        {
            [_currentSelections addObjectsFromArray:selections];
        }
        
        // Get asset bundle
        self.assetBundle = [NSBundle bundleForClass:[self class]];
        NSString *bundlePath = [self.assetBundle pathForResource:@"RNImagePicker" ofType:@"bundle"];
        if (bundlePath) {
            self.assetBundle = [NSBundle bundleWithPath:bundlePath];
        }
        
        [self setUpAlbumsViewController];
        
        // Set instance
        RNAlbumsViewController *albumsViewController = (RNAlbumsViewController *)self.albumsNavigationController.topViewController;
        albumsViewController.imagePickerController = self;
    }
    
    return self;
}

- (void)setUpAlbumsViewController
{
    // Add RNAlbumsViewController as a child
    UIStoryboard *storyboard = [UIStoryboard storyboardWithName:@"RNImagePicker" bundle:self.assetBundle];
    UINavigationController *navigationController = [storyboard instantiateViewControllerWithIdentifier:@"RNAlbumsNavigationController"];
    
    [self addChildViewController:navigationController];
    
    navigationController.view.frame = self.view.bounds;
    [self.view addSubview:navigationController.view];
    
    [navigationController didMoveToParentViewController:self];
    
    self.albumsNavigationController = navigationController;
}
- (NSUInteger) getSelectedAssetCount
{
    NSUInteger count=0;
    if(self.selectedAssets!=nil)
    {
        count+=[self.selectedAssets count];
    }
    if(_currentSelections!=nil)
    {
        count+=[_currentSelections count];
    }
    return  count;
}
- (BOOL) isContainsAsset:(PHAsset*) asset
{
    if(asset)
    {
        if(self.selectedAssets!=nil&&[self.selectedAssets containsObject:asset])
        {
            return  YES;
        }
        if(_currentSelections!=nil)
        {
            for (NSDictionary *photo in _currentSelections) {
                NSString *_photoSku=[photo objectForKey:@"sku"];
                if(_photoSku!=nil&&asset.localIdentifier!=nil&&[_photoSku isEqualToString:asset.localIdentifier])
                {
                    return YES;
                }
            }
        }
    }
    return NO;
}

- (void) removeSelectionAtIndex:(NSUInteger)index
{
    NSUInteger currentSelectionCount=0;
    if(_currentSelections!=nil)
    {
        currentSelectionCount=[_currentSelections count];
    }
    if(index<currentSelectionCount)
    {
        [_currentSelections removeObjectAtIndex:index];
        return;
    }
    if(self.selectedAssets!=nil)
    {
        NSInteger indexOnSelectedAssets=index-currentSelectionCount;
        if(indexOnSelectedAssets<[self.selectedAssets count])
        {
            [self.selectedAssets removeObjectAtIndex:indexOnSelectedAssets];
            return;
        }
    }
}
- (NSObject*) getSelectionAtIndex:(NSUInteger)index
{
    NSUInteger currentSelectionCount=0;
    if(_currentSelections!=nil)
    {
        currentSelectionCount=[_currentSelections count];
    }
    if(index<currentSelectionCount)
    {
        return [_currentSelections objectAtIndex:index];
    }
    if(self.selectedAssets!=nil)
    {
        NSInteger indexOnSelectedAssets=index-currentSelectionCount;
        if(indexOnSelectedAssets<[self.selectedAssets count])
        {
            return [self.selectedAssets objectAtIndex:indexOnSelectedAssets];
        }
    }
    return  nil;
}
- (void) removeSelection:(PHAsset*)asset
{
    if(self.selectedAssets!=nil&&[self.selectedAssets containsObject:asset])
    {
        [self.selectedAssets removeObject:asset];
        return;
    }
    else if(_currentSelections!=nil)
    {
        for (int i=0; i<[_currentSelections count]; i++) {
            NSDictionary *photo=[_currentSelections objectAtIndex:i];
            NSString *_photoSku=[photo objectForKey:@"sku"];
            if(_photoSku!=nil&&asset.localIdentifier!=nil&&[_photoSku isEqualToString:asset.localIdentifier])
            {
                [_currentSelections removeObjectAtIndex:i];
                return;
            }
        }
    }
}

- (void) addAsset:(PHAsset*) asset
{
    if(self.selectedAssets!=nil)
    {
        [self.selectedAssets addObject:asset];
    }
}
- (NSArray*)getSelectedAssets{
    NSUInteger capacity=0;
    if(_currentSelections!=nil)
    {
        capacity+=[_currentSelections count];
    }if(self.selectedAssets!=nil)
    {
        capacity+=[self.selectedAssets count];
    }
    NSMutableArray *result=[NSMutableArray arrayWithCapacity:capacity];
    if(_currentSelections!=nil)
    {
        [result addObjectsFromArray:_currentSelections.array];
    }
    if(self.selectedAssets!=nil)
    {
        [result addObjectsFromArray:self.selectedAssets.array];
    }
    return result;
}
@end

