//
//  ImageManager.m
//
//  Created by Ivan Pusic on 5/4/16.
//  Copyright © 2016 Facebook. All rights reserved.
//

#import "RNGalleryPicker.h"
#import <CommonCrypto/CommonDigest.h>

#define ERROR_PICKER_CANNOT_RUN_CAMERA_ON_SIMULATOR_KEY @"E_PICKER_CANNOT_RUN_CAMERA_ON_SIMULATOR"
#define ERROR_PICKER_CANNOT_RUN_CAMERA_ON_SIMULATOR_MSG @"Cannot run camera on simulator"

#define ERROR_PICKER_NO_CAMERA_PERMISSION_KEY @"E_PICKER_NO_CAMERA_PERMISSION"
#define ERROR_PICKER_NO_CAMERA_PERMISSION_MSG @"User did not grant camera permission."

#define ERROR_PICKER_UNAUTHORIZED_KEY @"E_PERMISSION_MISSING"
#define ERROR_PICKER_UNAUTHORIZED_MSG @"Cannot access images. Please allow access if you want to be able to select images."

#define ERROR_PICKER_EXPORT_FAILED @"E_EXPORT_FAILED"
#define ERROR_PICKER_EXPORT_FAILED_MSG @"Export media failed."

#define ERROR_PICKER_CANCEL_KEY @"E_PICKER_CANCELLED"
#define ERROR_PICKER_CANCEL_MSG @"User cancelled image selection"

#define ERROR_PICKER_NO_DATA_KEY @"E_NO_IMAGE_DATA_FOUND"
#define ERROR_PICKER_NO_DATA_MSG @"Cannot find image data"

#define ERROR_CROPPER_IMAGE_NOT_FOUND_KEY @"E_CROPPER_IMAGE_NOT_FOUND"
#define ERROR_CROPPER_IMAGE_NOT_FOUND_MSG @"Can't find the image at the specified path"

#define ERROR_CLEANUP_ERROR_KEY @"E_ERROR_WHILE_CLEANING_FILES"
#define ERROR_CLEANUP_ERROR_MSG @"Error while cleaning up tmp files"

#define ERROR_CANNOT_SAVE_IMAGE_KEY @"E_CANNOT_SAVE_IMAGE"
#define ERROR_CANNOT_SAVE_IMAGE_MSG @"Cannot save image. Unable to write to tmp location."

#define ERROR_CANNOT_PROCESS_VIDEO_KEY @"E_CANNOT_PROCESS_VIDEO"
#define ERROR_CANNOT_PROCESS_VIDEO_MSG @"Cannot process video data"
NSString *const RNTImagePickerWillShow = @"RNTImagePickerWillShow";
NSString *const RNTImagePickerWillHide = @"RNTImagePickerWillHide";

@implementation ImageResult
@end

@interface LabeledCropView : RSKImageCropViewController {
}
@property NSString *toolbarTitle;
@property UILabel *_moveAndScaleLabel;
- (UILabel *)moveAndScaleLabel;
@end

@implementation LabeledCropView
- (UILabel *)moveAndScaleLabel
{
    if (!self._moveAndScaleLabel) {
        self._moveAndScaleLabel = [[UILabel alloc] init];
        self._moveAndScaleLabel.backgroundColor = [UIColor clearColor];
        self._moveAndScaleLabel.text = self.toolbarTitle;
        self._moveAndScaleLabel.textColor = [UIColor whiteColor];
        self._moveAndScaleLabel.translatesAutoresizingMaskIntoConstraints = NO;
        self._moveAndScaleLabel.opaque = NO;
    }
    return self._moveAndScaleLabel;
}
@end

NSMutableDictionary *timerDic;
dispatch_queue_t backgroundQueue;
@implementation RNGalleryPicker
{
    PHFetchResult *cameraRollResult;
    CGFloat _lastChangeTime;
}

//- (dispatch_queue_t)methodQueue
//{
//    return dispatch_get_main_queue();
//}

RCT_EXPORT_MODULE();

@synthesize bridge = _bridge;

- (instancetype)init
{
    if (self = [super init]) {
        timerDic=[[NSMutableDictionary alloc]init];
        self.defaultOptions = @{
            @"multiple": @NO,
            @"cropping": @NO,
            @"cropperCircleOverlay": @NO,
            @"writeTempFile": @YES,
            @"includeBase64": @NO,
            @"includeExif": @NO,
            @"compressVideo": @NO,
            @"minFiles": @1,
            @"maxFiles": @10,
            @"width": @200,
            @"trimStartMs": @0,
            @"trimLengthMs": @0,
            @"waitAnimationEnd": @YES,
            @"height": @200,
            @"useFrontCamera": @NO,
            @"avoidEmptySpaceAroundImage": @YES,
            @"compressImageQuality": @0.8,
            @"compressVideoPreset": @"MediumQuality",
            @"loadingLabelText": @"Processing assets...",
            @"mediaType": @"any",
            @"showsSelectedCount": @YES,
            @"forceJpg": @NO,
            @"cropperCancelText": @"Cancel",
            @"cropperChooseText": @"Choose",
            @"currentSelections":[NSNull null]
        };
        self.compression = [[Compression alloc] init];
        NSMutableDictionary *dic = [[NSMutableDictionary alloc] initWithDictionary:@{
            @"640x480": AVAssetExportPreset640x480,
            @"960x540": AVAssetExportPreset960x540,
            @"1280x720": AVAssetExportPreset1280x720,
            @"1920x1080": AVAssetExportPreset1920x1080,
            @"LowQuality": AVAssetExportPresetLowQuality,
            @"MediumQuality": AVAssetExportPresetMediumQuality,
            @"HighestQuality": AVAssetExportPresetHighestQuality,
            @"Passthrough": AVAssetExportPresetPassthrough,
        }];
        NSOperatingSystemVersion systemVersion = [[NSProcessInfo processInfo] operatingSystemVersion];
        if (systemVersion.majorVersion >= 9) {
            [dic addEntriesFromDictionary:@{@"3840x2160": AVAssetExportPreset3840x2160}];
        }
        self.exportPresets = dic;
        _lastChangeTime=0;
        [self setupPhotoChangeObserver];
    }
    
    return self;
}

- (void)dealloc
{
    if(self.isObservedPhoto)
    {
        self.isObservedPhoto=NO;
        [[PHPhotoLibrary sharedPhotoLibrary] unregisterChangeObserver:self];
    }
    backgroundQueue=nil;
    cameraRollResult=nil;
}

- (void) setupPhotoChangeObserver{
    if([PHPhotoLibrary authorizationStatus]==PHAuthorizationStatusAuthorized)
    {
        if(!self.isObservedPhoto)
        {
            self.isObservedPhoto=YES;
            [[PHPhotoLibrary sharedPhotoLibrary] registerChangeObserver:self];
        }
    }
}
- (void)photoLibraryDidChange:(PHChange *)changeInstance
{
    if(cameraRollResult)
    {
        PHFetchResultChangeDetails *collectionChanges = [changeInstance changeDetailsForFetchResult:cameraRollResult];
        if(collectionChanges)
        {
            cameraRollResult=[collectionChanges fetchResultAfterChanges];
            if([collectionChanges hasIncrementalChanges])
            {
                BOOL hasChanges=NO;
                NSIndexSet *_removedIndexes = [collectionChanges removedIndexes];
                NSIndexSet *_insertedIndexes = [collectionChanges insertedIndexes];
                NSIndexSet *_changedIndexes = [collectionChanges changedIndexes];
                if ((_removedIndexes!=nil&&[_removedIndexes count])||(_insertedIndexes!=nil&&[_insertedIndexes count])||(_changedIndexes!=nil&&[_changedIndexes count])) {
                    hasChanges=YES;
                }
                if(hasChanges)
                {
                    if(_changedIndexes!=nil&&[_changedIndexes count])
                    {
                        CGFloat _currentTime = [[NSDate date] timeIntervalSince1970]*1000;
                        if((_currentTime-_lastChangeTime)<5000)
                        {
                            return;
                        }
                        _lastChangeTime=_currentTime;
                    }
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self sendEventWithName:@"onCameraRollChange" body:@{}];
                    });
                }
            }
        }
    }
}

+ (BOOL)requiresMainQueueSetup {
    return YES;
}

- (void (^ __nullable)(void))waitAnimationEnd:(void (^ __nullable)(void))completion {
    if ([[self.options objectForKey:@"waitAnimationEnd"] boolValue]) {
        return completion;
    }
    
    if (completion != nil) {
        completion();
    }
    
    return nil;
}

- (void)checkCameraPermissions:(void(^)(BOOL granted))callback
{
    AVAuthorizationStatus status = [AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeVideo];
    if (status == AVAuthorizationStatusAuthorized) {
        callback(YES);
        return;
    } else if (status == AVAuthorizationStatusNotDetermined){
        [AVCaptureDevice requestAccessForMediaType:AVMediaTypeVideo completionHandler:^(BOOL granted) {
            callback(granted);
            return;
        }];
    } else {
        callback(NO);
    }
}

- (void) setConfiguration:(NSDictionary *)options
                 resolver:(RCTPromiseResolveBlock)resolve
                 rejecter:(RCTPromiseRejectBlock)reject {
    
    self.resolve = resolve;
    self.reject = reject;
    self.options = [NSMutableDictionary dictionaryWithDictionary:self.defaultOptions];
    for (NSString *key in options.keyEnumerator) {
        [self.options setValue:options[key] forKey:key];
    }
}

- (UIViewController*) getRootVC {
    UIViewController *root = [[[[UIApplication sharedApplication] delegate] window] rootViewController];
    while (root.presentedViewController != nil) {
        root = root.presentedViewController;
    }
    
    return root;
}

RCT_EXPORT_METHOD(openCamera:(NSDictionary *)options
                  resolver:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject) {
    
    [self setConfiguration:options resolver:resolve rejecter:reject];
    self.currentSelectionMode = CAMERA;
    
#if TARGET_IPHONE_SIMULATOR
    self.reject(ERROR_PICKER_CANNOT_RUN_CAMERA_ON_SIMULATOR_KEY, ERROR_PICKER_CANNOT_RUN_CAMERA_ON_SIMULATOR_MSG, nil);
    return;
#else
    [self checkCameraPermissions:^(BOOL granted) {
        if (!granted) {
            self.reject(ERROR_PICKER_NO_CAMERA_PERMISSION_KEY, ERROR_PICKER_NO_CAMERA_PERMISSION_MSG, nil);
            return;
        }
        
        UIImagePickerController *picker = [[UIImagePickerController alloc] init];
        picker.delegate = self;
        picker.allowsEditing = NO;
        picker.sourceType = UIImagePickerControllerSourceTypeCamera;
        if ([[self.options objectForKey:@"useFrontCamera"] boolValue]) {
            picker.cameraDevice = UIImagePickerControllerCameraDeviceFront;
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [[self getRootVC] presentViewController:picker animated:YES completion:nil];
        });
    }];
#endif
}

- (void)viewDidLoad {
    [self viewDidLoad];
}


- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info {
    UIImage *chosenImage = [info objectForKey:UIImagePickerControllerOriginalImage];
    NSDictionary *imageMetaData = [info objectForKey:UIImagePickerControllerMediaMetadata];
    
    NSDictionary *exif;
    if([[self.options objectForKey:@"includeExif"] boolValue]) {
        exif = [info objectForKey:UIImagePickerControllerMediaMetadata];
    }
    
    [self processSingleImagePick:chosenImage withExif:exif withViewController:picker withSourceURL:self.croppingFile[@"sourceURL"] withLocalIdentifier:self.croppingFile[@"localIdentifier"] withFilename:self.croppingFile[@"filename"] withCreationDate:self.croppingFile[@"creationDate"] withModificationDate:self.croppingFile[@"modificationDate"]];
}

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker {
    [[NSNotificationCenter defaultCenter] postNotificationName:RNTImagePickerWillHide
                                                        object:@{}];
    [picker dismissViewControllerAnimated:YES completion:[self waitAnimationEnd:^{
        self.reject(ERROR_PICKER_CANCEL_KEY, ERROR_PICKER_CANCEL_MSG, nil);
    }]];
}

- (NSString*) getTmpDirectory {
    NSString *TMP_DIRECTORY = @"react-native-image-picker/";
    NSString *tmpFullPath = [NSTemporaryDirectory() stringByAppendingString:TMP_DIRECTORY];
    
    BOOL isDir;
    BOOL exists = [[NSFileManager defaultManager] fileExistsAtPath:tmpFullPath isDirectory:&isDir];
    if (!exists) {
        [[NSFileManager defaultManager] createDirectoryAtPath: tmpFullPath
                                  withIntermediateDirectories:YES attributes:nil error:nil];
    }
    
    return tmpFullPath;
}

- (BOOL)cleanTmpDirectory {
    NSString* tmpDirectoryPath = [self getTmpDirectory];
    NSArray* tmpDirectory = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:tmpDirectoryPath error:NULL];
    
    for (NSString *file in tmpDirectory) {
        BOOL deleted = [[NSFileManager defaultManager] removeItemAtPath:[NSString stringWithFormat:@"%@%@", tmpDirectoryPath, file] error:NULL];
        
        if (!deleted) {
            return NO;
        }
    }
    
    return YES;
}

- (NSArray<NSString *> *)supportedEvents
{
    return @[@"onExportVideoProgress",@"onCameraRollChange"];
}

RCT_EXPORT_METHOD(cleanSingle:(NSString *) path
                  resolver:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject) {
    
    BOOL deleted = [[NSFileManager defaultManager] removeItemAtPath:path error:NULL];
    
    if (!deleted) {
        reject(ERROR_CLEANUP_ERROR_KEY, ERROR_CLEANUP_ERROR_MSG, nil);
    } else {
        resolve(nil);
    }
}

RCT_REMAP_METHOD(clean, resolver:(RCTPromiseResolveBlock)resolve
                 rejecter:(RCTPromiseRejectBlock)reject) {
    if (![self cleanTmpDirectory]) {
        reject(ERROR_CLEANUP_ERROR_KEY, ERROR_CLEANUP_ERROR_MSG, nil);
    } else {
        resolve(nil);
    }
}

RCT_EXPORT_METHOD(exportVideo:(NSDictionary *)options
                  resolver:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject) {
    NSURL *originalURL;
    NSString *source=[options objectForKey:@"url"];
    NSString *videoId=source;
    if([options objectForKey:@"id"])
    {
        videoId=[options objectForKey:@"id"];
    }
    if([source containsString:@"assets-library"]||[source containsString:@"bundle-assets"])
    {
        originalURL=[NSURL URLWithString:source];
    }
    else if([source hasPrefix:@"assets-content://"])
    {
        originalURL=[NSURL fileURLWithPath:[source substringFromIndex:[@"assets-content://" length]]];
    }
    else if([source hasPrefix:@"file://"]) {
        originalURL=[NSURL fileURLWithPath:[source substringFromIndex:[@"file://" length]]];
    }
    else{
        originalURL=[NSURL fileURLWithPath:source];
    }
    NSString *presetKey = [self.options valueForKey:@"compressVideoPreset"];
    if (presetKey == nil) {
        presetKey = @"MediumQuality";
    }
    NSString *preset = [self.exportPresets valueForKey:presetKey];
    if (preset == nil) {
        preset = AVAssetExportPresetMediumQuality;
    }
    AVURLAsset *asset = [AVURLAsset URLAssetWithURL:originalURL options:nil];
    NSTimeInterval videoDuration =CMTimeGetSeconds(asset.duration)*1000;
    
    //----------Get video dimension----------
    CGFloat videoWidth=0;
    CGFloat videoHeight=0;
    CGFloat videoRatio=1;
    NSArray *tracks = [asset tracksWithMediaType:AVMediaTypeVideo];
    if(tracks!=nil&&[tracks count]>0)
    {
        AVAssetTrack *track = [tracks objectAtIndex:0];
        if(track!=nil)
        {
            CGSize videoDimens = track.naturalSize;
            videoWidth=videoDimens.width;
            videoHeight=videoDimens.height;
            CGAffineTransform txf = [track preferredTransform];
            CGSize transformedVideoSize=CGSizeApplyAffineTransform(videoDimens,txf);
            BOOL videoIsPortrait = ABS(transformedVideoSize.width) < ABS(transformedVideoSize.height);
            if(videoWidth>0&&videoHeight>0)
            {
                if(videoIsPortrait)
                {
                    videoWidth=MIN(videoDimens.width,videoDimens.height);
                    videoHeight=MAX(videoDimens.width,videoDimens.height);
                }
                else{
                    videoWidth=MAX(videoDimens.width,videoDimens.height);
                    videoHeight=MIN(videoDimens.width,videoDimens.height);
                }
                videoRatio=(videoWidth/videoHeight);
            }
        }
    }
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSDictionary *attrs = [fileManager attributesOfItemAtPath: [originalURL absoluteString] error: NULL];
    unsigned long long result = [attrs fileSize];
    if(result>100)
    {
        resolve(@{@"filePath":[originalURL absoluteString],
                  @"playableDuration":[NSNumber numberWithFloat:videoDuration],
                  @"width":[NSNumber numberWithFloat:videoWidth],
                  @"height":[NSNumber numberWithFloat:videoHeight],
                  @"ratio":[NSNumber numberWithFloat:videoRatio],
        });
        return;
    }
    AVAssetExportSession *exportSession = [[AVAssetExportSession alloc] initWithAsset:asset presetName:preset];
    exportSession.shouldOptimizeForNetworkUse = YES;
    exportSession.outputFileType = AVFileTypeMPEG4;
    NSString *tempVideoFilePath =[RNGalleryPicker getTempFilePath:videoId prefix:@"video-exported" extension:@"mp4"];
    NSURL *outputURL = [NSURL fileURLWithPath:tempVideoFilePath];
    exportSession.outputURL = outputURL;
    NSTimer *currentTimer=[timerDic objectForKey:videoId];
    if(currentTimer!=nil)
    {
        [currentTimer invalidate];
    }
    dispatch_async(dispatch_get_main_queue(), ^{
        NSTimer *tempTimer=[NSTimer scheduledTimerWithTimeInterval:1 target:self selector:@selector(updateProgress:) userInfo:@{@"exporter":exportSession,@"id":videoId} repeats:YES];
        [timerDic setObject:tempTimer forKey:videoId];
    });
    [exportSession exportAsynchronouslyWithCompletionHandler:^(void){
        AVAssetExportSessionStatus _resultStatus=exportSession.status;
        switch (_resultStatus)
        {
            case AVAssetExportSessionStatusCompleted:
            {
                const NSString *tempOutputFilePath=[outputURL absoluteString];
                dispatch_async(dispatch_get_main_queue(), ^{
                    NSTimer *tempTimer=[timerDic objectForKey:videoId];
                    if(tempTimer!=nil)
                    {
                        [tempTimer invalidate];
                        tempTimer=nil;
                        [timerDic removeObjectForKey:videoId];
                    }
                    [self sendEventWithName:@"onExportVideoProgress" body:@{@"id": videoId,@"progress":[NSNumber numberWithFloat:100]}];
                    resolve(@{@"filePath":tempOutputFilePath,
                              @"playableDuration":[NSNumber numberWithFloat:videoDuration],
                              @"width":[NSNumber numberWithFloat:videoWidth],
                              @"height":[NSNumber numberWithFloat:videoHeight],
                              @"ratio":[NSNumber numberWithFloat:videoRatio],
                    });
                });
            }
                break;
            case AVAssetExportSessionStatusFailed:
            {
                if(videoWidth>0&&videoHeight>0&&videoDuration>0)
                {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        NSTimer *tempTimer=[timerDic objectForKey:videoId];
                        if(tempTimer!=nil)
                        {
                            [tempTimer invalidate];
                            tempTimer=nil;
                            [timerDic removeObjectForKey:videoId];
                        }
                        [self sendEventWithName:@"onExportVideoProgress" body:@{@"id": videoId,@"progress":[NSNumber numberWithFloat:100]}];
                        resolve(@{@"filePath":source,
                                  @"playableDuration":[NSNumber numberWithFloat:videoDuration],
                                  @"width":[NSNumber numberWithFloat:videoWidth],
                                  @"height":[NSNumber numberWithFloat:videoHeight],
                                  @"ratio":[NSNumber numberWithFloat:videoRatio],
                        });
                    });
                }
                else{
                    NSError *tempError=exportSession.error;
                    NSLog(@"Error: %@",[tempError localizedDescription]);
                    dispatch_async(dispatch_get_main_queue(), ^{
                        NSTimer *tempTimer=[timerDic objectForKey:videoId];
                        if(tempTimer!=nil)
                        {
                            [tempTimer invalidate];
                            tempTimer=nil;
                            [timerDic removeObjectForKey:videoId];
                        }
                        [self sendEventWithName:@"onExportVideoProgress" body:@{@"id": videoId,@"progress":[NSNumber numberWithFloat:100]}];
                        reject(ERROR_PICKER_EXPORT_FAILED, ERROR_PICKER_EXPORT_FAILED_MSG, nil);
                    });
                }
            }
                break;
            default:
            {
                dispatch_async(dispatch_get_main_queue(), ^{
                    NSTimer *tempTimer=[timerDic objectForKey:videoId];
                    if(tempTimer!=nil)
                    {
                        [tempTimer invalidate];
                        tempTimer=nil;
                        [timerDic removeObjectForKey:videoId];
                    }
                    [self sendEventWithName:@"onExportVideoProgress" body:@{@"id": videoId,@"progress":[NSNumber numberWithFloat:100]}];
                    resolve(nil);
                });
            }
                break;
        }
    }];
}

- (void) updateProgress:(NSTimer*)timer
{
    NSDictionary *info=timer.userInfo;
    if(info)
    {
        AVAssetExportSession *exportSession=info[@"exporter"];
        NSString *videoId=info[@"id"];
        if(exportSession!=nil)
        {
            const float progressPercent=exportSession.progress*100;
            [self sendEventWithName:@"onExportVideoProgress" body:@{@"id": videoId,@"progress":[NSNumber numberWithFloat:progressPercent]}];
        }
    }
}

RCT_EXPORT_METHOD(getMedias:(NSDictionary *) params
                  resolver:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject) {
    [self setupPhotoChangeObserver];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSUInteger size=10;
        if(params!=nil)
        {
            if([params objectForKey:@"size"]!=nil)
            {
                size=[[params objectForKey:@"size"] integerValue];
                if(size==0)
                {
                    size=10;
                }
            }
        }
        PHFetchOptions *fetchOptions = [PHFetchOptions new];
        //    fetchOptions.sortDescriptors = @[
        //                                     [NSSortDescriptor sortDescriptorWithKey:@"modificationDate" ascending:NO],
        //                                     ];
        PHFetchResult *fetchResult = [PHAssetCollection fetchAssetCollectionsWithType:PHAssetCollectionTypeSmartAlbum subtype:PHAssetCollectionSubtypeSmartAlbumUserLibrary options:fetchOptions];
        NSMutableArray *collectionArray=[[NSMutableArray alloc]init];
        [fetchResult enumerateObjectsUsingBlock:^(PHAssetCollection *assetCollection, NSUInteger index, BOOL *stop) {
            [collectionArray addObject:assetCollection];
        }];
        for(PHAssetCollection *assetCollection in collectionArray)
        {
            PHFetchOptions *assetFetchOptions = [PHFetchOptions new];
            //            assetFetchOptions.fetchLimit=size;
            //----Sort theo ngày hiển thị trên kho ảnh
            //        assetFetchOptions.sortDescriptors = @[
            //                                              [NSSortDescriptor sortDescriptorWithKey:@"modificationDate" ascending:NO],
            //                                              ];
            //        assetFetchOptions.sortDescriptors = @[
            //                                              [NSSortDescriptor sortDescriptorWithKey:@"modificationDate" ascending:NO],
            //                                              ];
            cameraRollResult = [PHAsset fetchAssetsInAssetCollection:assetCollection options:assetFetchOptions];
            
        }
        [self fetchCameraRoll:size resolve: resolve rejecter:reject];
    });
}

-(void) fetchCameraRoll:(NSUInteger )size resolve:(RCTPromiseResolveBlock)resolve
               rejecter:(RCTPromiseRejectBlock)reject
{
    BOOL hasData=YES;
    if(cameraRollResult)
    {
        NSLock *lock=[[NSLock alloc] init];
        int resultSize=(int)[cameraRollResult count];
        int listSize=(int)MIN(size, resultSize);
        NSMutableArray *unorderedSelections=[NSMutableArray arrayWithCapacity:listSize];
        __block int processed=0;
        int index=0;
        int i=resultSize-listSize;
        for(;i<resultSize;i++)
        {
            PHAsset *phAsset =[cameraRollResult objectAtIndex:i];
            hasData=YES;
            if (phAsset.mediaType == PHAssetMediaTypeVideo) {
                [self getVideoAsset:phAsset withIndex:index completion:^(NSDictionary* video,NSUInteger resultIndex) {
                    [lock lock];
                    if(video!=nil)
                    {
                        [unorderedSelections addObject:@{
                            @"item":video,
                            @"index":[NSNumber numberWithInteger:resultIndex]
                        }];
                    }
                    ++processed;
                    [lock unlock];
                    if (processed == listSize) {
                        NSArray *_tempSortedResult=[self getSortedResult:unorderedSelections];
                        dispatch_async( dispatch_get_main_queue(), ^{
                            resolve(_tempSortedResult);
                        });
                        return;
                    }
                }];
            }
            else if (phAsset.mediaType == PHAssetMediaTypeImage) {
                [self getImageAsset:phAsset withIndex:index completion:^(NSDictionary* image,NSUInteger resultIndex){
                    [lock lock];
                    if(image!=nil)
                    {
                        [unorderedSelections addObject:@{
                            @"item":image,
                            @"index":[NSNumber numberWithInteger:resultIndex]
                        }];
                    }
                    ++processed;
                    [lock unlock];
                    if (processed == listSize) {
                        NSArray *_tempSortedResult=[self getSortedResult:unorderedSelections];
                        dispatch_async( dispatch_get_main_queue(), ^{
                            resolve(_tempSortedResult);
                        });
                        return;
                    }
                }];
            }
            ++index;
        }
    }
    if(!hasData)
    {
        dispatch_async( dispatch_get_main_queue(), ^{
            resolve(@{});
        });
    }
}

-(NSArray*) getSortedResult:(NSArray*)unorderedSelections{
    if(unorderedSelections)
    {
        NSArray *sorted = [unorderedSelections sortedArrayUsingComparator:^(id obj1, id obj2){
            NSUInteger leftIndex=[obj1[@"index"] integerValue];
            NSUInteger rightIndex=[obj2[@"index"] integerValue];
            if(leftIndex<rightIndex)
            {
                return (NSComparisonResult)NSOrderedDescending;
            }
            if(leftIndex>rightIndex)
            {
                return (NSComparisonResult)NSOrderedAscending;
            }
            return (NSComparisonResult)NSOrderedSame;
        }];
        NSMutableArray *result=[NSMutableArray arrayWithCapacity:[sorted count]];
        for(NSDictionary *obj in sorted)
        {
            [result addObject:obj[@"item"]];
        }
        return result;
    }
    return unorderedSelections;
}

RCT_EXPORT_METHOD(openPicker:(NSDictionary *)options
                  resolver:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject) {
    
    [self setConfiguration:options resolver:resolve rejecter:reject];
    self.currentSelectionMode = PICKER;
    
    [PHPhotoLibrary requestAuthorization:^(PHAuthorizationStatus status) {
        if (status != PHAuthorizationStatusAuthorized) {
            self.reject(ERROR_PICKER_UNAUTHORIZED_KEY, ERROR_PICKER_UNAUTHORIZED_MSG, nil);
            return;
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            // init picker
            NSArray *currentSelections;
            if([self.options objectForKey:@"currentSelections"])
            {
                currentSelections=[self.options objectForKey:@"currentSelections"];
            }
            RNImagePickerController *imagePickerController =
            [[RNImagePickerController alloc] initWithSelections:currentSelections];
            imagePickerController.delegate = self;
            imagePickerController.allowsMultipleSelection = [[self.options objectForKey:@"multiple"] boolValue];
            imagePickerController.minimumNumberOfSelection = abs([[self.options objectForKey:@"minFiles"] intValue]);
            imagePickerController.maximumNumberOfSelection = abs([[self.options objectForKey:@"maxFiles"] intValue]);
            imagePickerController.showsNumberOfSelectedAssets = [[self.options objectForKey:@"showsSelectedCount"] boolValue];
            
            NSArray *smartAlbums = [self.options objectForKey:@"smartAlbums"];
            if (smartAlbums != nil) {
                NSDictionary *albums = @{
                    //user albums
                    @"Regular" : @(PHAssetCollectionSubtypeAlbumRegular),
                    @"SyncedEvent" : @(PHAssetCollectionSubtypeAlbumSyncedEvent),
                    @"SyncedFaces" : @(PHAssetCollectionSubtypeAlbumSyncedFaces),
                    @"SyncedAlbum" : @(PHAssetCollectionSubtypeAlbumSyncedAlbum),
                    @"Imported" : @(PHAssetCollectionSubtypeAlbumImported),
                    
                    //cloud albums
                    @"PhotoStream" : @(PHAssetCollectionSubtypeAlbumMyPhotoStream),
                    @"CloudShared" : @(PHAssetCollectionSubtypeAlbumCloudShared),
                    
                    //smart albums
                    @"Generic" : @(PHAssetCollectionSubtypeSmartAlbumGeneric),
                    @"Panoramas" : @(PHAssetCollectionSubtypeSmartAlbumPanoramas),
                    @"Videos" : @(PHAssetCollectionSubtypeSmartAlbumVideos),
                    @"Favorites" : @(PHAssetCollectionSubtypeSmartAlbumFavorites),
                    @"Timelapses" : @(PHAssetCollectionSubtypeSmartAlbumTimelapses),
                    @"AllHidden" : @(PHAssetCollectionSubtypeSmartAlbumAllHidden),
                    @"RecentlyAdded" : @(PHAssetCollectionSubtypeSmartAlbumRecentlyAdded),
                    @"Bursts" : @(PHAssetCollectionSubtypeSmartAlbumBursts),
                    @"SlomoVideos" : @(PHAssetCollectionSubtypeSmartAlbumSlomoVideos),
                    @"UserLibrary" : @(PHAssetCollectionSubtypeSmartAlbumUserLibrary),
                    @"SelfPortraits" : @(PHAssetCollectionSubtypeSmartAlbumSelfPortraits),
                    @"Screenshots" : @(PHAssetCollectionSubtypeSmartAlbumScreenshots),
                    @"DepthEffect" : @(PHAssetCollectionSubtypeSmartAlbumDepthEffect),
                    @"LivePhotos" : @(PHAssetCollectionSubtypeSmartAlbumLivePhotos),
                    @"Animated" : @(PHAssetCollectionSubtypeSmartAlbumAnimated),
                    @"LongExposure" : @(PHAssetCollectionSubtypeSmartAlbumLongExposures),
                };
                NSMutableArray *albumsToShow = [NSMutableArray arrayWithCapacity:smartAlbums.count];
                for (NSString* smartAlbum in smartAlbums) {
                    if ([albums objectForKey:smartAlbum] != nil) {
                        [albumsToShow addObject:[albums objectForKey:smartAlbum]];
                    }
                }
                imagePickerController.assetCollectionSubtypes = albumsToShow;
            }
            
            if ([[self.options objectForKey:@"cropping"] boolValue]) {
                imagePickerController.mediaType = RNImagePickerMediaTypeImage;
            } else {
                NSString *mediaType = [self.options objectForKey:@"mediaType"];
                
                if ([mediaType isEqualToString:@"any"]) {
                    imagePickerController.mediaType = RNImagePickerMediaTypeAny;
                } else if ([mediaType isEqualToString:@"photo"]) {
                    imagePickerController.mediaType = RNImagePickerMediaTypeImage;
                } else {
                    imagePickerController.mediaType = RNImagePickerMediaTypeVideo;
                }
                
            }
            [[NSNotificationCenter defaultCenter] postNotificationName:RNTImagePickerWillShow
                                                                object:@{}];
            [[self getRootVC] presentViewController:imagePickerController animated:YES completion:nil];
        });
    }];
}

RCT_EXPORT_METHOD(openCropper:(NSDictionary *)options
                  resolver:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject) {
    
    [self setConfiguration:options resolver:resolve rejecter:reject];
    self.currentSelectionMode = CROPPING;
    
    NSString *path = [options objectForKey:@"path"];
    
    [self.bridge.imageLoader loadImageWithURLRequest:[RCTConvert NSURLRequest:path] callback:^(NSError *error, UIImage *image) {
        if (error) {
            self.reject(ERROR_CROPPER_IMAGE_NOT_FOUND_KEY, ERROR_CROPPER_IMAGE_NOT_FOUND_MSG, nil);
        } else {
            [self startCropping:[image fixOrientation]];
        }
    }];
}

- (void)startCropping:(UIImage *)image {
    LabeledCropView *imageCropVC = [[LabeledCropView alloc] initWithImage:image];
    if ([[[self options] objectForKey:@"cropperCircleOverlay"] boolValue]) {
        imageCropVC.cropMode = RSKImageCropModeCircle;
    } else {
        imageCropVC.cropMode = RSKImageCropModeCustom;
    }
    imageCropVC.toolbarTitle = [[self options] objectForKey:@"cropperToolbarTitle"];
    imageCropVC.avoidEmptySpaceAroundImage = [[[self options] objectForKey:@"avoidEmptySpaceAroundImage"] boolValue];
    imageCropVC.dataSource = self;
    imageCropVC.delegate = self;
    NSString *cropperCancelText = [self.options objectForKey:@"cropperCancelText"];
    NSString *cropperChooseText = [self.options objectForKey:@"cropperChooseText"];
    [imageCropVC setModalPresentationStyle:UIModalPresentationCustom];
    [imageCropVC setModalTransitionStyle:UIModalTransitionStyleCrossDissolve];
    [imageCropVC.cancelButton setTitle:cropperCancelText forState:UIControlStateNormal];
    [imageCropVC.chooseButton setTitle:cropperChooseText forState:UIControlStateNormal];
    dispatch_async(dispatch_get_main_queue(), ^{
        [[self getRootVC] presentViewController:imageCropVC animated:YES completion:nil];
    });
}

- (void)showActivityIndicator:(void (^)(UIActivityIndicatorView*, UIView*))handler {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIView *mainView = [[self getRootVC] view];
        
        // create overlay
        UIView *loadingView = [[UIView alloc] initWithFrame:[UIScreen mainScreen].bounds];
        loadingView.backgroundColor = [UIColor colorWithRed:0 green:0 blue:0 alpha:0.5];
        loadingView.clipsToBounds = YES;
        
        // create loading spinner
        UIActivityIndicatorView *activityView = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge];
        activityView.frame = CGRectMake(65, 40, activityView.bounds.size.width, activityView.bounds.size.height);
        activityView.center = loadingView.center;
        [loadingView addSubview:activityView];
        
        // create message
        UILabel *loadingLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 115, 130, 22)];
        loadingLabel.backgroundColor = [UIColor clearColor];
        loadingLabel.textColor = [UIColor whiteColor];
        loadingLabel.adjustsFontSizeToFitWidth = YES;
        CGPoint loadingLabelLocation = loadingView.center;
        loadingLabelLocation.y += [activityView bounds].size.height;
        loadingLabel.center = loadingLabelLocation;
        loadingLabel.textAlignment = NSTextAlignmentCenter;
        loadingLabel.text = [self.options objectForKey:@"loadingLabelText"];
        [loadingLabel setFont:[UIFont boldSystemFontOfSize:18]];
        [loadingView addSubview:loadingLabel];
        
        // show all
        [mainView addSubview:loadingView];
        [activityView startAnimating];
        
        handler(activityView, loadingView);
    });
}


- (void) getVideoAsset:(PHAsset*)phAsset completion:(void (^)(NSDictionary* image))completion {
    [self getVideoAsset:phAsset withIndex:0 completion:^(NSDictionary* video,NSUInteger resultIndex) {
        if(completion)
        {
            completion(video);
        }
    }];
}
- (void) getVideoAsset:(PHAsset*)phAsset withIndex:(NSUInteger) index completion:(void (^)(NSDictionary* image,NSUInteger resultIndex))completion {
    dispatch_async([self getBackgroundQueue], ^{
        PHImageManager *manager = [PHImageManager defaultManager];
        PHVideoRequestOptions *options = [[PHVideoRequestOptions alloc] init];
        options.version = PHVideoRequestOptionsVersionCurrent;
        //        options.deliveryMode=PHVideoRequestOptionsDeliveryModeFastFormat;
        options.networkAccessAllowed = YES;
        [manager
         requestAVAssetForVideo:phAsset
         options:options
         resultHandler:^(AVAsset * asset, AVAudioMix * audioMix,
                         NSDictionary *info) {
            dispatch_async([self getBackgroundQueue], ^{
                if(asset==nil)
                {
                    completion(nil,index);
                    return;
                }
                BOOL isAvailable=YES;
                if(info!=nil)
                {
                    if (info[@"PHImageFileSandboxExtensionTokenKey"]) {
                        isAvailable = YES;
                    } else if ([info[PHImageResultIsInCloudKey] boolValue]) {
                        isAvailable = NO;
                    }
                }
                //             isAvailable=NO;
                PHImageRequestOptions *imageOptions = [[PHImageRequestOptions alloc] init];
                imageOptions.version = PHImageRequestOptionsVersionCurrent;
                imageOptions.networkAccessAllowed = YES;
                //             [imageOptions setSynchronous:NO];
                [manager requestImageDataForAsset:phAsset options:imageOptions resultHandler:^(NSData *__nullable imageData, NSString *__nullable dataUTI, UIImageOrientation orientation, NSDictionary *__nullable info)
                 {
                    dispatch_async([self getBackgroundQueue], ^{
                        NSURL *videoAssetUrl = nil;
                        if(isAvailable&&[asset isKindOfClass:[AVURLAsset class]])
                        {
                            @try {
                                videoAssetUrl = [(AVURLAsset*)asset URL];
                            }
                            @catch (NSException *exception) {
                                videoAssetUrl=nil;
                            }
                        }
                        NSFileManager *fileManager = [NSFileManager defaultManager];
                        NSString *tempVideoThumbnailPath =[RNGalleryPicker getTempFilePath:phAsset.localIdentifier prefix:@"thumbnail" extension:@"jpeg"];
                        [fileManager createFileAtPath:tempVideoThumbnailPath contents:imageData attributes:nil];
                        NSURL *tempVideoThumbnailURL = [NSURL fileURLWithPath:tempVideoThumbnailPath];
                        tempVideoThumbnailPath=[tempVideoThumbnailURL absoluteString];
                        
                        
                        NSTimeInterval videoDuration =CMTimeGetSeconds(asset.duration)*1000;
                        
                        //----------Get video dimension----------
                        CGFloat videoWidth=0;
                        CGFloat videoHeight=0;
                        CGFloat videoRatio=1;
                        NSArray *tracks = [asset tracksWithMediaType:AVMediaTypeVideo];
                        if(tracks!=nil&&[tracks count]>0)
                        {
                            AVAssetTrack *track = [tracks objectAtIndex:0];
                            if(track!=nil)
                            {
                                CGSize videoDimens = track.naturalSize;
                                videoWidth=videoDimens.width;
                                videoHeight=videoDimens.height;
                                CGAffineTransform txf = [track preferredTransform];
                                CGSize transformedVideoSize=CGSizeApplyAffineTransform(videoDimens,txf);
                                BOOL videoIsPortrait = ABS(transformedVideoSize.width) < ABS(transformedVideoSize.height);
                                if(videoWidth>0&&videoHeight>0)
                                {
                                    if(videoIsPortrait)
                                    {
                                        videoWidth=MIN(videoDimens.width,videoDimens.height);
                                        videoHeight=MAX(videoDimens.width,videoDimens.height);
                                    }
                                    else{
                                        videoWidth=MAX(videoDimens.width,videoDimens.height);
                                        videoHeight=MIN(videoDimens.width,videoDimens.height);
                                    }
                                    videoRatio=(videoWidth/videoHeight);
                                }
                            }
                        }
                        //-------------------------------
                        if(isAvailable&&videoAssetUrl!=nil)
                        {
                            NSString *assetContentUrl=[videoAssetUrl absoluteString];
                            completion([RNGalleryPicker createVideoResponse:assetContentUrl withThumbnailURL:tempVideoThumbnailPath withId:phAsset.localIdentifier withWidth:[NSNumber numberWithFloat:videoWidth] withHeight:[NSNumber numberWithFloat:videoHeight] withRatio:[NSNumber numberWithFloat:videoRatio]
                                                              withDuration:[NSNumber numberWithFloat:videoDuration]
                                                          withCreationDate:phAsset.creationDate withModificationDate:phAsset.modificationDate],index);
                        }
                        else{
                            NSString *tempVideoFilePath =[RNGalleryPicker getTempFilePath:phAsset.localIdentifier prefix:@"video" extension:@"mp4"];
                            NSString *presetKey = [self.options valueForKey:@"compressVideoPreset"];
                            if (presetKey == nil) {
                                presetKey = @"Passthrough";
                            }
                            NSString *preset = [self.exportPresets valueForKey:presetKey];
                            if (preset == nil) {
                                preset = AVAssetExportPresetMediumQuality;
                            }
                            NSURL *outputURL = [NSURL fileURLWithPath:tempVideoFilePath];
                            AVAssetExportSession *exportSession = [[AVAssetExportSession alloc] initWithAsset:asset presetName:preset];
                            exportSession.outputURL = outputURL;
                            exportSession.shouldOptimizeForNetworkUse = YES;
                            exportSession.outputFileType = AVFileTypeMPEG4;
                            //                      if([self.options valueForKey:@"trimLengthMs"])
                            //                      {
                            //                          CGFloat trimLengthMs=[[self.options valueForKey:@"trimLengthMs"] floatValue];
                            //                          if(trimLengthMs>0)
                            //                          {
                            //                              CGFloat startTimeMs=0;
                            //                              if([self.options valueForKey:@"trimStartMs"])
                            //                              {
                            //                                  startTimeMs=[[self.options valueForKey:@"trimStartMs"] floatValue];
                            //                              }
                            //                              CGFloat endTimeMs=MIN(startTimeMs+trimLengthMs, videoDuration);
                            //                              CMTime startTime=CMTimeMake(startTimeMs, 1);
                            //                              CMTime endTime=CMTimeMake(endTimeMs, 1);
                            //                              if(startTimeMs>0||endTimeMs<videoDuration)
                            //                              {
                            //                                  videoDuration=endTimeMs-startTimeMs;
                            //                                  CMTimeRange range = CMTimeRangeMake(startTime, endTime);
                            //                                  exportSession.timeRange = range;
                            //                              }
                            //                          }
                            //                      }
                            //                  NSFileManager *fileManager = [NSFileManager defaultManager];
                            //                  if ([fileManager fileExistsAtPath:[outputURL absoluteString]]){
                            //                      NSNumber * mySize = [NSNumber numberWithUnsignedLongLong:[[fileManager attributesOfItemAtPath:[outputURL absoluteString] error:nil] fileSize]];
                            //                  }
                            [exportSession exportAsynchronouslyWithCompletionHandler:^(void){
                                switch (exportSession.status)
                                {
                                    case AVAssetExportSessionStatusCompleted:
                                    {
                                        completion([RNGalleryPicker createVideoResponse:[outputURL absoluteString] withThumbnailURL:tempVideoThumbnailPath withId:phAsset.localIdentifier withWidth:[NSNumber numberWithFloat:videoWidth] withHeight:[NSNumber numberWithFloat:videoHeight] withRatio:[NSNumber numberWithFloat:videoRatio]
                                                                          withDuration:[NSNumber numberWithFloat:videoDuration]
                                                                      withCreationDate:phAsset.creationDate withModificationDate:phAsset.modificationDate],index);
                                    }
                                        break;
                                    case AVAssetExportSessionStatusFailed:
                                        completion(nil,index);
                                        break;
                                    case AVAssetExportSessionStatusCancelled:
                                        completion(nil,index);
                                        break;
                                    default:
                                        completion(nil,index);
                                        break;
                                }
                            }];
                        }
                    });
                }];
            });
        }];
    });
}

- (void) getImageAsset:(PHAsset*)asset  completion:(void (^)(NSDictionary* image))completion {
    [self getImageAsset:asset withIndex:0 completion:^(NSDictionary* image,NSUInteger resultIndex) {
        if(completion)
        {
            completion(image);
        }
    }];
}
- (void) getImageAsset:(PHAsset*)asset withIndex:(NSUInteger) index completion:(void (^)(NSDictionary* image,NSUInteger resultIndex))completion {
    dispatch_async([self getBackgroundQueue], ^{
        PHImageManager *manager = [PHImageManager defaultManager];
        PHImageRequestOptions *options = [[PHImageRequestOptions alloc] init];
        options.version = PHImageRequestOptionsVersionCurrent;
        options.networkAccessAllowed = YES;
        //        [options setSynchronous:NO];
        [manager requestImageDataForAsset:asset options:options resultHandler:^(NSData *__nullable imageData, NSString *__nullable dataUTI, UIImageOrientation orientation, NSDictionary *__nullable info)
         {
            dispatch_async([self getBackgroundQueue], ^{
                if(asset==nil)
                {
                    completion(nil,index);
                    return;
                }
                NSFileManager *fileManager = [NSFileManager defaultManager];
                NSString *imageFilePath =[RNGalleryPicker getTempFilePath:asset.localIdentifier prefix:@"thumbnail" extension:@"jpeg"];
                NSDictionary* exif = nil;
                if([[self.options objectForKey:@"includeExif"] boolValue]) {
                    exif = [[CIImage imageWithData:imageData] properties];
                }
                NSString *mimeType = [self determineMimeTypeFromImageData:imageData];
                Boolean isKnownMimeType = [mimeType length] > 0;
                
                UIImage *imgT = [UIImage imageWithData:imageData];
                ImageResult *imageResult = [[ImageResult alloc] init];
                if (isKnownMimeType) {
                    [fileManager createFileAtPath:imageFilePath contents:imageData attributes:nil];
                    imageResult.width = @(imgT.size.width);
                    imageResult.height = @(imgT.size.height);
                    imageResult.mime = mimeType;
                    imageResult.image = imgT;
                } else {
                    imageResult = [self.compression compressImage:[imgT fixOrientation] withOptions:self.options];
                    [fileManager createFileAtPath:imageFilePath contents:imageResult.data attributes:nil];
                }
                completion([RNGalleryPicker createImageResponse:asset.localIdentifier withUrl:imageFilePath withWidth:imageResult.width withHeight:imageResult.height withExif:exif withMime:imageResult.mime
                                                      withRect:CGRectNull
                                              withCreationDate:asset.creationDate withModificationDate:asset.modificationDate],index);
            });
        }];
    });
}

+ (NSDictionary*) createImageResponse:(NSString*)mediaId
                              withUrl:(NSString*)filePath
                            withWidth:(NSNumber*)width
                           withHeight:(NSNumber*)height
                             withExif:(NSDictionary*) exif
                             withMime:(NSString*)mime
                             withRect:(CGRect)cropRect
                     withCreationDate:(NSDate*)creationDate
                 withModificationDate:(NSDate*)modificationDate {
    NSString *tempUrl;
    if(filePath)
    {
        tempUrl=[[NSURL fileURLWithPath:filePath] absoluteString];
        
    }
    NSNumber *ratio=nil;
    if(width!=nil&&[width floatValue]>0&&height!=nil&&[height floatValue]>0)
    {
        ratio=[NSNumber numberWithFloat:([width floatValue]/[height floatValue])];
    }
    else{
        ratio=[NSNumber numberWithFloat:1.0];
    }
    CGFloat modificationDateInterval=0;
    CGFloat creationDateInterval=0;
    NSString *sku=nil;
    if(modificationDate!=nil)
    {
        modificationDateInterval=[modificationDate timeIntervalSince1970]*1000;
    }
    if(mediaId!=nil)
    {
        sku=[mediaId copy];
        mediaId=[NSString stringWithFormat:@"%@-%.f",mediaId,modificationDateInterval];
    }
    if(creationDate!=nil)
    {
        creationDateInterval=[creationDate timeIntervalSince1970]*1000;
    }
    return @{
        @"type":@"image",
        @"sku": (sku) ? sku : [NSNull null],
        @"id": (mediaId) ? mediaId : [NSNull null],
        @"url": (tempUrl && ![tempUrl isEqualToString:(@"")]) ? tempUrl : [NSNull null],
        @"width": width,
        @"height": height,
        @"ratio": ratio,
        @"mimeType": mime?mime:[NSNull null],
        @"exif": (exif) ? exif : [NSNull null],
        @"cropRect": CGRectIsNull(cropRect) ? [NSNull null] : [RNGalleryPicker cgRectToDictionary:cropRect],
        @"creationDate": [NSNumber numberWithFloat: creationDateInterval],
        @"modificationDate": [NSNumber numberWithFloat: modificationDateInterval],
    };
}

+ (NSDictionary*) createVideoResponse:(NSString*)filePath withThumbnailURL:(NSString*) thumbnailURL withId:(NSString*)mediaId withWidth:(NSNumber*)width withHeight:(NSNumber*)height withRatio:(NSNumber*) ratio withDuration:(NSNumber*)duration withCreationDate:(NSDate*)creationDate withModificationDate:(NSDate*)modificationDate {
    CGFloat modificationDateInterval=0;
    CGFloat creationDateInterval=0;
    NSString *sku=nil;
    if(modificationDate!=nil)
    {
        modificationDateInterval=[modificationDate timeIntervalSince1970]*1000;
    }
    if(mediaId!=nil)
    {
        sku=[mediaId copy];
        mediaId=[NSString stringWithFormat:@"%@-%.f",mediaId,modificationDateInterval];
    }
    if(creationDate!=nil)
    {
        creationDateInterval=[creationDate timeIntervalSince1970]*1000;
    }
    return @{
        @"type":@"video",
        @"sku": (sku) ? sku : [NSNull null],
        @"id": (mediaId) ? mediaId : [NSNull null],
        @"url": (filePath && ![filePath isEqualToString:(@"")]) ? filePath : [NSNull null],
        @"coverUrl": (thumbnailURL) ? thumbnailURL : [NSNull null],
        @"width": width,
        @"height": height,
        @"ratio": ratio,
        @"playableDuration": duration,
        @"creationDate": [NSNumber numberWithFloat: creationDateInterval],
        @"modificationDate":  [NSNumber numberWithFloat: modificationDateInterval],
    };
}

// See https://stackoverflow.com/questions/4147311/finding-image-type-from-nsdata-or-uiimage
- (NSString *)determineMimeTypeFromImageData:(NSData *)data {
    uint8_t c;
    [data getBytes:&c length:1];
    
    switch (c) {
        case 0xFF:
            return @"image/jpeg";
        case 0x89:
            return @"image/png";
        case 0x47:
            return @"image/gif";
        case 0x49:
        case 0x4D:
            return @"image/tiff";
    }
    return @"";
}

- (void)qb_imagePickerController:
(RNImagePickerController *)imagePickerController
          didFinishPickingAssets:(NSArray *)selectedAssets {
    NSArray *assets = [selectedAssets filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(id object, NSDictionary *bindings) {
        return (object!=nil&& [object isKindOfClass:[PHAsset class]]);
    }]];
    NSArray *lastSelections = [selectedAssets filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(id object, NSDictionary *bindings) {
        return (object!=nil&& [object isKindOfClass:[NSDictionary class]]);
    }]];
    PHImageManager *manager = [PHImageManager defaultManager];
    PHImageRequestOptions* options = [[PHImageRequestOptions alloc] init];
    //    options.synchronous = NO;
    options.networkAccessAllowed = YES;
    
    if ([[[self options] objectForKey:@"multiple"] boolValue]) {
        NSUInteger lastSelectionsCount=0;
        NSUInteger assetCount=0;
        if(lastSelections!=nil)
        {
            lastSelectionsCount=[lastSelections count];
        }
        if(assets!=nil)
        {
            assetCount=[assets count];
        }
        NSUInteger totalCount=lastSelectionsCount+assetCount;
        NSMutableArray *selections = [NSMutableArray arrayWithCapacity:totalCount];
        if(lastSelectionsCount>0)
        {
            [selections addObjectsFromArray:lastSelections];
        }
        if(assetCount>0)
        {
            NSMutableArray *unorderedSelections=[NSMutableArray arrayWithCapacity:assetCount];
            [self showActivityIndicator:^(UIActivityIndicatorView *indicatorView, UIView *overlayView) {
                NSLock *lock = [[NSLock alloc] init];
                __block int processed = 0;
                for (int i=0; i<assetCount; i++) {
                    PHAsset *phAsset=[assets objectAtIndex:i];
                    const NSUInteger mediaIndex=lastSelectionsCount+i;
                    if (phAsset.mediaType == PHAssetMediaTypeVideo) {
                        [self getVideoAsset:phAsset completion:^(NSDictionary* video) {
                            dispatch_async(dispatch_get_main_queue(), ^{
                                [lock lock];
                                if(video!=nil)
                                {
                                    [unorderedSelections addObject:@{
                                        @"index":[NSNumber numberWithInteger:mediaIndex],
                                        @"media":video
                                    }];
                                }
                                processed++;
                                [lock unlock];
                                if (processed == [assets count]) {
                                    [indicatorView stopAnimating];
                                    [overlayView removeFromSuperview];
                                    [[NSNotificationCenter defaultCenter] postNotificationName:RNTImagePickerWillHide
                                                                                        object:@{}];
                                    [imagePickerController dismissViewControllerAnimated:YES completion:[self waitAnimationEnd:^{
                                        [unorderedSelections sortUsingComparator:^NSComparisonResult(NSDictionary* obj1,NSDictionary *obj2){
                                            int leftIndex=[[obj1 objectForKey:@"index"] intValue];
                                            int rightIndex=[[obj2 objectForKey:@"index"] intValue];
                                            if(leftIndex<rightIndex)
                                            {
                                                return NSOrderedAscending;
                                            }
                                            else if(leftIndex>rightIndex)
                                            {
                                                return NSOrderedDescending;
                                            }
                                            return NSOrderedAscending;
                                        }];
                                        NSMutableArray *sortedSelections=[NSMutableArray arrayWithCapacity:[unorderedSelections count]];
                                        for (NSDictionary *obj in unorderedSelections) {
                                            [sortedSelections addObject:[obj objectForKey:@"media"]];
                                        }
                                        [selections addObjectsFromArray:sortedSelections];
                                        self.resolve(selections);
                                    }]];
                                    return;
                                }
                            });
                        }];
                    } else {
                        [self getImageAsset:phAsset completion:^(NSDictionary* image) {
                            dispatch_async(dispatch_get_main_queue(), ^{
                                [lock lock];
                                if(image!=nil)
                                {
                                    [unorderedSelections addObject:@{
                                        @"index":[NSNumber numberWithInteger:mediaIndex],
                                        @"media":image
                                    }];
                                }
                                processed++;
                                [lock unlock];
                                if (processed == [assets count]) {
                                    [indicatorView stopAnimating];
                                    [overlayView removeFromSuperview];
                                    [[NSNotificationCenter defaultCenter] postNotificationName:RNTImagePickerWillHide
                                                                                        object:@{}];
                                    [imagePickerController dismissViewControllerAnimated:YES completion:[self waitAnimationEnd:^{
                                        [unorderedSelections sortUsingComparator:^NSComparisonResult(NSDictionary* obj1,NSDictionary *obj2){
                                            int leftIndex=[[obj1 objectForKey:@"index"] intValue];
                                            int rightIndex=[[obj2 objectForKey:@"index"] intValue];
                                            if(leftIndex<rightIndex)
                                            {
                                                return NSOrderedAscending;
                                            }
                                            else if(leftIndex>rightIndex)
                                            {
                                                return NSOrderedDescending;
                                            }
                                            return NSOrderedAscending;
                                        }];
                                        NSMutableArray *sortedSelections=[NSMutableArray arrayWithCapacity:[unorderedSelections count]];
                                        for (NSDictionary *obj in unorderedSelections) {
                                            [sortedSelections addObject:[obj objectForKey:@"media"]];
                                        }
                                        [selections addObjectsFromArray:sortedSelections];
                                        self.resolve(selections);
                                    }]];
                                    return;
                                }
                            });
                        }];
                    }
                }
            }];
        }
        else{
            [[NSNotificationCenter defaultCenter] postNotificationName:RNTImagePickerWillHide
                                                                object:@{}];
            [imagePickerController dismissViewControllerAnimated:YES completion:[self waitAnimationEnd:^{
                self.resolve(selections);
            }]];
            return;
        }
    } else {
        PHAsset *phAsset = [assets objectAtIndex:0];
        [self showActivityIndicator:^(UIActivityIndicatorView *indicatorView, UIView *overlayView) {
            if (phAsset.mediaType == PHAssetMediaTypeVideo) {
                [self getVideoAsset:phAsset completion:^(NSDictionary* video) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [indicatorView stopAnimating];
                        [overlayView removeFromSuperview];
                        [[NSNotificationCenter defaultCenter] postNotificationName:RNTImagePickerWillHide
                                                                            object:@{}];
                        [imagePickerController dismissViewControllerAnimated:YES completion:[self waitAnimationEnd:^{
                            if (video != nil) {
                                NSMutableArray *selections = [[NSMutableArray alloc] init];
                                [selections addObject:video];
                                self.resolve(selections);
                            } else {
                                NSMutableArray *selections = [[NSMutableArray alloc] init];
                                self.resolve(selections);
                            }
                        }]];
                    });
                }];
            } else {
                if ([[[self options] objectForKey:@"cropping"] boolValue]) {
                    [manager
                     requestImageDataForAsset:phAsset
                     options:options
                     resultHandler:^(NSData *imageData, NSString *dataUTI,
                                     UIImageOrientation orientation,
                                     NSDictionary *info) {
                        NSURL *sourceURL = [info objectForKey:@"PHImageFileURLKey"];
                        NSDictionary* exif;
                        if([[self.options objectForKey:@"includeExif"] boolValue]) {
                            exif = [[CIImage imageWithData:imageData] properties];
                        }
                        
                        dispatch_async(dispatch_get_main_queue(), ^{
                            [indicatorView stopAnimating];
                            [overlayView removeFromSuperview];
                            
                            [self processSingleImagePick:[UIImage imageWithData:imageData]
                                                withExif: exif
                                      withViewController:imagePickerController
                                           withSourceURL:[sourceURL absoluteString]
                                     withLocalIdentifier:phAsset.localIdentifier
                                            withFilename:[phAsset valueForKey:@"filename"]
                                        withCreationDate:phAsset.creationDate
                                    withModificationDate:phAsset.modificationDate];
                        });
                    }];
                }
                else{
                    [self getImageAsset:phAsset completion:^(NSDictionary* image) {
                        dispatch_async(dispatch_get_main_queue(), ^{
                            [indicatorView stopAnimating];
                            [overlayView removeFromSuperview];
                            [[NSNotificationCenter defaultCenter] postNotificationName:RNTImagePickerWillHide
                                                                                object:@{}];
                            [imagePickerController dismissViewControllerAnimated:YES completion:[self waitAnimationEnd:^{
                                if (image != nil) {
                                    NSMutableArray *selections = [[NSMutableArray alloc] init];
                                    [selections addObject:image];
                                    self.resolve(selections);
                                } else {
                                    NSMutableArray *selections = [[NSMutableArray alloc] init];
                                    self.resolve(selections);
                                }
                            }]];
                        });
                    }];
                }
            }
        }];
    }
}

- (void)qb_imagePickerControllerDidCancel:(RNImagePickerController *)imagePickerController {
    [[NSNotificationCenter defaultCenter] postNotificationName:RNTImagePickerWillHide
                                                        object:@{}];
    [imagePickerController dismissViewControllerAnimated:YES completion:[self waitAnimationEnd:^{
        self.reject(ERROR_PICKER_CANCEL_KEY, ERROR_PICKER_CANCEL_MSG, nil);
    }]];
}

// when user selected single image, with camera or from photo gallery,
// this method will take care of attaching image metadata, and sending image to cropping controller
// or to user directly
- (void) processSingleImagePick:(UIImage*)image withExif:(NSDictionary*) exif withViewController:(UIViewController*)viewController withSourceURL:(NSString*)sourceURL withLocalIdentifier:(NSString*)localIdentifier withFilename:(NSString*)filename withCreationDate:(NSDate*)creationDate withModificationDate:(NSDate*)modificationDate {
    
    if (image == nil) {
        [[NSNotificationCenter defaultCenter] postNotificationName:RNTImagePickerWillHide
                                                            object:@{}];
        [viewController dismissViewControllerAnimated:YES completion:[self waitAnimationEnd:^{
            self.reject(ERROR_PICKER_NO_DATA_KEY, ERROR_PICKER_NO_DATA_MSG, nil);
        }]];
        return;
    }
    
    
    if ([[[self options] objectForKey:@"cropping"] boolValue]) {
        self.croppingFile = [[NSMutableDictionary alloc] init];
        self.croppingFile[@"sourceURL"] = sourceURL;
        self.croppingFile[@"localIdentifier"] = localIdentifier;
        self.croppingFile[@"filename"] = filename;
        self.croppingFile[@"creationDate"] = creationDate;
        self.croppingFile[@"modifcationDate"] = modificationDate;
        
        [self startCropping:[image fixOrientation]];
    } else {
        ImageResult *imageResult = [self.compression compressImage:[image fixOrientation]  withOptions:self.options];
        NSString *filePath = [RNGalleryPicker persistFile:imageResult.data withId:localIdentifier withPrefix:@"image" withExtension:@"jpeg"];
        if (filePath == nil) {
            [[NSNotificationCenter defaultCenter] postNotificationName:RNTImagePickerWillHide
                                                                object:@{}];
            [viewController dismissViewControllerAnimated:YES completion:[self waitAnimationEnd:^{
                self.reject(ERROR_CANNOT_SAVE_IMAGE_KEY, ERROR_CANNOT_SAVE_IMAGE_MSG, nil);
            }]];
            return;
        }
        
        // Wait for viewController to dismiss before resolving, or we lose the ability to display
        // Alert.alert in the .then() handler.
        NSMutableArray *selections = [[NSMutableArray alloc] init];
        [selections addObject:[RNGalleryPicker createImageResponse:localIdentifier withUrl:filePath
                                                        withWidth:imageResult.width
                                                       withHeight:imageResult.height
                                                         withExif:exif
                                                         withMime:imageResult.mime
                                                         withRect:CGRectNull
                                                 withCreationDate:creationDate
                                             withModificationDate:modificationDate
                               ]];
        [[NSNotificationCenter defaultCenter] postNotificationName:RNTImagePickerWillHide
                                                            object:@{}];
        [viewController dismissViewControllerAnimated:YES completion:[self waitAnimationEnd:^{
            self.resolve(selections);
        }]];
    }
}

#pragma mark - CustomCropModeDelegates

// Returns a custom rect for the mask.
- (CGRect)imageCropViewControllerCustomMaskRect:
(RSKImageCropViewController *)controller {
    CGSize maskSize = CGSizeMake(
                                 [[self.options objectForKey:@"width"] intValue],
                                 [[self.options objectForKey:@"height"] intValue]);
    
    CGFloat viewWidth = CGRectGetWidth(controller.view.frame);
    CGFloat viewHeight = CGRectGetHeight(controller.view.frame);
    
    CGRect maskRect = CGRectMake((viewWidth - maskSize.width) * 0.5f,
                                 (viewHeight - maskSize.height) * 0.5f,
                                 maskSize.width, maskSize.height);
    
    return maskRect;
}

// if provided width or height is bigger than screen w/h,
// then we should scale draw area
- (CGRect) scaleRect:(RSKImageCropViewController *)controller {
    CGRect rect = controller.maskRect;
    CGFloat viewWidth = CGRectGetWidth(controller.view.frame);
    CGFloat viewHeight = CGRectGetHeight(controller.view.frame);
    
    double scaleFactor = fmin(viewWidth / rect.size.width, viewHeight / rect.size.height);
    rect.size.width *= scaleFactor;
    rect.size.height *= scaleFactor;
    rect.origin.x = (viewWidth - rect.size.width) / 2;
    rect.origin.y = (viewHeight - rect.size.height) / 2;
    
    return rect;
}

// Returns a custom path for the mask.
- (UIBezierPath *)imageCropViewControllerCustomMaskPath:
(RSKImageCropViewController *)controller {
    CGRect rect = [self scaleRect:controller];
    UIBezierPath *path = [UIBezierPath bezierPathWithRoundedRect:rect
                                               byRoundingCorners:UIRectCornerAllCorners
                                                     cornerRadii:CGSizeMake(0, 0)];
    return path;
}

// Returns a custom rect in which the image can be moved.
- (CGRect)imageCropViewControllerCustomMovementRect:
(RSKImageCropViewController *)controller {
    return [self scaleRect:controller];
}

#pragma mark - CropFinishDelegate

// Crop image has been canceled.
- (void)imageCropViewControllerDidCancelCrop:
(RSKImageCropViewController *)controller {
    [self dismissCropper:controller selectionDone:NO completion:[self waitAnimationEnd:^{
        if (self.currentSelectionMode == CROPPING) {
            self.reject(ERROR_PICKER_CANCEL_KEY, ERROR_PICKER_CANCEL_MSG, nil);
        }
    }]];
}

- (void) dismissCropper:(RSKImageCropViewController*)controller selectionDone:(BOOL)selectionDone completion:(void (^)())completion {
    switch (self.currentSelectionMode) {
        case CROPPING:
            [[NSNotificationCenter defaultCenter] postNotificationName:RNTImagePickerWillHide
                                                                object:@{}];
            [controller dismissViewControllerAnimated:YES completion:completion];
            break;
        case PICKER:
            if (selectionDone) {
                [[NSNotificationCenter defaultCenter] postNotificationName:RNTImagePickerWillHide
                                                                    object:@{}];
                [controller.presentingViewController.presentingViewController dismissViewControllerAnimated:YES completion:completion];
            } else {
                // if user opened picker, tried to crop image, and cancelled cropping
                // return him to the image selection instead of returning him to the app
                [controller.presentingViewController dismissViewControllerAnimated:YES completion:completion];
            }
            break;
        case CAMERA:
            [[NSNotificationCenter defaultCenter] postNotificationName:RNTImagePickerWillHide
                                                                object:@{}];
            [controller.presentingViewController.presentingViewController dismissViewControllerAnimated:YES completion:completion];
            break;
    }
}

// The original image has been cropped.
- (void)imageCropViewController:(RSKImageCropViewController *)controller
                   didCropImage:(UIImage *)croppedImage
                  usingCropRect:(CGRect)cropRect {
    
    ImageResult *imageResult = [self.compression compressImage:croppedImage withOptions:self.options];
    
    NSString *filePath = [RNGalleryPicker persistFile:imageResult.data withId:nil withPrefix:@"crop" withExtension:@"png"];
    if (filePath == nil) {
        [self dismissCropper:controller selectionDone:YES completion:[self waitAnimationEnd:^{
            self.reject(ERROR_CANNOT_SAVE_IMAGE_KEY, ERROR_CANNOT_SAVE_IMAGE_MSG, nil);
        }]];
        return;
    }
    
    NSDictionary* exif = nil;
    if([[self.options objectForKey:@"includeExif"] boolValue]) {
        exif = [[CIImage imageWithData:imageResult.data] properties];
    }
    
    [self dismissCropper:controller selectionDone:YES completion:[self waitAnimationEnd:^{
        NSMutableArray *selections = [[NSMutableArray alloc] init];
        [selections addObject:[RNGalleryPicker createImageResponse:self.croppingFile[@"localIdentifier"] withUrl:filePath
                                                        withWidth:imageResult.width
                                                       withHeight:imageResult.height
                                                         withExif: exif
                                                         withMime:imageResult.mime
                                                         withRect:cropRect
                                                 withCreationDate:self.croppingFile[@"creationDate"]
                                             withModificationDate:self.croppingFile[@"modificationDate"]
                               ]];
        self.resolve(selections);
    }]];
}

-(dispatch_queue_t) getBackgroundQueue{
    if(backgroundQueue==nil)
    {
        backgroundQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0);
    }
    return  backgroundQueue;
}

// at the moment it is not possible to upload image by reading PHAsset
// we are saving image and saving it to the tmp location where we are allowed to access image later
+ (NSString*) persistFile:(NSData*)data withId:(NSString*)mediaId withPrefix:(NSString*)prefix withExtension:(NSString*) extension {
    if(mediaId==nil)
    {
        mediaId=[[NSProcessInfo processInfo] globallyUniqueString];
    }
    if(extension==nil)
    {
        extension=@"jpeg";
    }
    NSString *filePath = [RNGalleryPicker getTempFilePath:mediaId prefix:prefix extension:extension];
    BOOL status = [data writeToFile:filePath atomically:YES];
    if (!status) {
        return nil;
    }
    
    return filePath;
}

// The original image has been cropped. Additionally provides a rotation angle
// used to produce image.
- (void)imageCropViewController:(RSKImageCropViewController *)controller
                   didCropImage:(UIImage *)croppedImage
                  usingCropRect:(CGRect)cropRect
                  rotationAngle:(CGFloat)rotationAngle {
    [self imageCropViewController:controller didCropImage:croppedImage usingCropRect:cropRect];
}



+ (NSDictionary *)cgRectToDictionary:(CGRect)rect {
    return @{
        @"x": [NSNumber numberWithFloat: rect.origin.x],
        @"y": [NSNumber numberWithFloat: rect.origin.y],
        @"width": [NSNumber numberWithFloat: CGRectGetWidth(rect)],
        @"height": [NSNumber numberWithFloat: CGRectGetHeight(rect)]
    };
}

+ (NSString*) getTempFilePath:(NSString*)localId prefix:(NSString*) prefix extension:(NSString*) extension
{
    localId=[RNGalleryPicker md5:localId];
    NSString *tempFilePath = [NSTemporaryDirectory() stringByAppendingPathComponent:prefix?[NSString stringWithFormat:@"%@-",prefix]:@""];
    tempFilePath=[tempFilePath stringByAppendingString:localId];
    if(extension!=nil)
    {
        if([extension hasPrefix:@"."])
        {
            tempFilePath=[tempFilePath stringByAppendingString:extension];
        }
        else
        {
            tempFilePath=[tempFilePath stringByAppendingString:[NSString stringWithFormat:@".%@",extension]];
        }
    }
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if ([fileManager fileExistsAtPath:tempFilePath]){
        [fileManager removeItemAtPath:tempFilePath error:nil];
    }
    return  tempFilePath;
}
+ (NSString *)md5:(NSString*)inputString {
    if(inputString==nil)
    {
        inputString=@"";
    }
    const char* str = [inputString UTF8String];
    unsigned char result[CC_MD5_DIGEST_LENGTH];
    CC_MD5(str, (CC_LONG)strlen(str), result);
    
    NSMutableString *ret = [NSMutableString stringWithCapacity:CC_MD5_DIGEST_LENGTH*2];
    for(int i = 0; i<CC_MD5_DIGEST_LENGTH; i++) {
        [ret appendFormat:@"%02x",result[i]];
    }
    return ret;
}
@end
