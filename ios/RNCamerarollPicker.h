//
//  ImageManager.h
//
//  Created by Ivan Pusic on 5/4/16.
//  Copyright © 2016 Facebook. All rights reserved.
//

#ifndef RN_IMAGE_CROP_PICKER_h
#define RN_IMAGE_CROP_PICKER_h

#import <Foundation/Foundation.h>

#import <React/RCTBridgeModule.h>
#import <React/RCTImageLoader.h>
#import <React/RCTEventEmitter.h>

#import "RNImagePickerController.h"
#import "UIImage+Resize.h"
#import "Compression.h"
#import <math.h>

RCT_EXTERN NSString *const RNTImagePickerWillShow;
RCT_EXTERN NSString *const RNTImagePickerWillHide;

@interface RNCamerarollPicker : RCTEventEmitter<
PHPhotoLibraryChangeObserver,
UIImagePickerControllerDelegate,
UINavigationControllerDelegate,
RCTBridgeModule,
QBImagePickerControllerDelegate,
RSKImageCropViewControllerDelegate,
RSKImageCropViewControllerDataSource>

typedef enum selectionMode {
    CAMERA,
    CROPPING,
    PICKER
} SelectionMode;

@property (nonatomic) BOOL isObservedPhoto;
@property (nonatomic, strong) NSMutableDictionary *croppingFile;
@property (nonatomic, strong) NSDictionary *defaultOptions;
@property NSDictionary *exportPresets;
@property (nonatomic, strong) Compression *compression;
@property (nonatomic, retain) NSMutableDictionary *options;
@property (nonatomic, strong) RCTPromiseResolveBlock resolve;
@property (nonatomic, strong) RCTPromiseRejectBlock reject;
@property SelectionMode currentSelectionMode;

@end

#endif
