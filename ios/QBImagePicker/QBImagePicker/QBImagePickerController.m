//
//  QBImagePickerController.m
//  QBImagePicker
//
//  Created by Katsuma Tanaka on 2015/04/03.
//  Copyright (c) 2015 Katsuma Tanaka. All rights reserved.
//

#import "QBImagePickerController.h"
#import <Photos/Photos.h>

// ViewControllers
#import "QBAlbumsViewController.h"

@interface QBImagePickerController ()

@property (nonatomic, strong) UINavigationController *albumsNavigationController;

@property (nonatomic, strong) NSBundle *assetBundle;

@end

@implementation QBImagePickerController

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
        NSString *bundlePath = [self.assetBundle pathForResource:@"QBImagePicker" ofType:@"bundle"];
        if (bundlePath) {
            self.assetBundle = [NSBundle bundleWithPath:bundlePath];
        }
        
        [self setUpAlbumsViewController];
        
        // Set instance
        QBAlbumsViewController *albumsViewController = (QBAlbumsViewController *)self.albumsNavigationController.topViewController;
        albumsViewController.imagePickerController = self;
    }
    
    return self;
}

- (void)setUpAlbumsViewController
{
    // Add QBAlbumsViewController as a child
    UIStoryboard *storyboard = [UIStoryboard storyboardWithName:@"QBImagePicker" bundle:self.assetBundle];
    UINavigationController *navigationController = [storyboard instantiateViewControllerWithIdentifier:@"QBAlbumsNavigationController"];
    
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
    if(self.currentSelections!=nil)
    {
        count+=[self.currentSelections count];
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
        if(self.currentSelections!=nil)
        {
            for (NSDictionary *photo in self.currentSelections) {
                NSString *photoId=[photo objectForKey:@"id"];
                if(photoId!=nil&&asset.localIdentifier!=nil&&[photoId isEqualToString:asset.localIdentifier])
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
    if(self.currentSelections!=nil)
    {
        currentSelectionCount=[self.currentSelections count];
    }
    if(index<currentSelectionCount)
    {
        [self.currentSelections removeObjectAtIndex:index];
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
    if(self.currentSelections!=nil)
    {
        currentSelectionCount=[self.currentSelections count];
    }
    if(index<currentSelectionCount)
    {
        return [self.currentSelections objectAtIndex:index];
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
    else if(self.currentSelections!=nil)
    {
        for (int i=0; i<[self.currentSelections count]; i++) {
            NSDictionary *photo=[self.currentSelections objectAtIndex:i];
            NSString *photoId=[photo objectForKey:@"id"];
            if(photoId!=nil&&asset.localIdentifier!=nil&&[photoId isEqualToString:asset.localIdentifier])
            {
                [self.currentSelections removeObjectAtIndex:i];
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
    if(self.currentSelections!=nil)
    {
        capacity+=[self.currentSelections count];
    }if(self.selectedAssets!=nil)
    {
        capacity+=[self.selectedAssets count];
    }
    NSMutableArray *result=[NSMutableArray arrayWithCapacity:capacity];
    if(self.currentSelections!=nil)
    {
        [result addObjectsFromArray:self.currentSelections.array];
    }
    if(self.selectedAssets!=nil)
    {
        [result addObjectsFromArray:self.selectedAssets.array];
    }
    return result;
}
@end
