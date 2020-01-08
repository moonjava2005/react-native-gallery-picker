package info.moonjava.gallery.picker;

import android.Manifest;
import android.app.Activity;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.database.ContentObserver;
import android.database.Cursor;
import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.graphics.Color;
import android.media.ExifInterface;
import android.net.Uri;
import android.os.Handler;
import android.os.Looper;
import android.provider.MediaStore;
import android.util.Patterns;

import androidx.core.app.ActivityCompat;
import androidx.loader.content.CursorLoader;

import com.esafirm.imagepicker.features.ImagePicker;
import com.esafirm.imagepicker.model.Image;
import com.facebook.react.bridge.ActivityEventListener;
import com.facebook.react.bridge.Arguments;
import com.facebook.react.bridge.Promise;
import com.facebook.react.bridge.ReactApplicationContext;
import com.facebook.react.bridge.ReactContextBaseJavaModule;
import com.facebook.react.bridge.ReactMethod;
import com.facebook.react.bridge.ReadableArray;
import com.facebook.react.bridge.ReadableMap;
import com.facebook.react.bridge.WritableArray;
import com.facebook.react.bridge.WritableMap;
import com.facebook.react.bridge.WritableNativeArray;
import com.facebook.react.bridge.WritableNativeMap;
import com.facebook.react.modules.core.DeviceEventManagerModule;
import com.facebook.react.modules.core.PermissionAwareActivity;
import com.facebook.react.modules.core.PermissionListener;
import com.yalantis.ucrop.UCrop;
import com.yalantis.ucrop.UCropActivity;

import java.io.File;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.Collections;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.concurrent.Callable;


class RNGalleryPickerModule extends ReactContextBaseJavaModule implements ActivityEventListener {

    private static final String MODULE_NAME = "RNGalleryPicker";
    private static final String E_ACTIVITY_DOES_NOT_EXIST = "E_ACTIVITY_DOES_NOT_EXIST";

    private static final String ERROR_RNT_IMAGE_PICKER_MEDIA_NOT_FOUND = "ERROR_RNT_IMAGE_PICKER_MEDIA_NOT_FOUND";

    private static final String E_CALLBACK_ERROR = "E_CALLBACK_ERROR";
    private static final String E_CAMERA_IS_NOT_AVAILABLE = "E_CAMERA_IS_NOT_AVAILABLE";
    private static final String E_PERMISSIONS_MISSING = "E_PERMISSION_MISSING";
    private static final String E_ERROR_WHILE_CLEANING_FILES = "E_ERROR_WHILE_CLEANING_FILES";

    private String mediaType = "any";
    private String albumTitle = "Albums";
    private boolean multiple = false;
    private boolean cropping = false;
    private boolean cropperCircleOverlay = false;
    private boolean freeStyleCropEnabled = false;
    private boolean showCropGuidelines = true;
    private boolean hideBottomControls = false;
    private boolean enableRotationGesture = false;
    private boolean disableCropperColorSetters = false;
    private int maxFiles = 10;
    private ReadableArray currentSelections;

    //Grey 800
    private final String DEFAULT_TINT = "#54d3a2";
    private String cropperActiveWidgetColor = DEFAULT_TINT;
    private String cropperStatusBarColor = DEFAULT_TINT;
    private String cropperToolbarColor = DEFAULT_TINT;
    private String cropperToolbarTitle = null;

    //Light Blue 500
    private static final String DEFAULT_WIDGET_COLOR = "#A533B0";
    private int width = 0;
    private int height = 0;

    private Promise resultPromise;
    private ReactApplicationContext reactContext;
    private DeviceEventManagerModule.RCTDeviceEventEmitter emitter;
    private static int PREFINE_CROP_SIZE = 612;

    private Map<String, Image> cachedImages = new HashMap<>();
    private ArrayList<Image> errorImages = new ArrayList<>();

    RNGalleryPickerModule(ReactApplicationContext reactContext) {
        super(reactContext);
        reactContext.addActivityEventListener(this);
        this.reactContext = reactContext;
        this.reactContext.getContentResolver().registerContentObserver(MediaStore.Images.Media.INTERNAL_CONTENT_URI, true,
                new ContentObserver(new Handler(Looper.getMainLooper())) {
                    @Override
                    public void onChange(boolean selfChange, Uri uri) {
                        super.onChange(selfChange, uri);
                        WritableMap map = Arguments.createMap();
                        if (uri != null) {
                            map.putString("uri", uri.toString());
                        }
                        emit("onCameraRollChange", map);
                    }
                }
        );
        this.reactContext.getContentResolver().registerContentObserver(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, true,
                new ContentObserver(new Handler(Looper.getMainLooper())) {
                    @Override
                    public void onChange(boolean selfChange, Uri uri) {
                        super.onChange(selfChange, uri);
                        WritableMap map = Arguments.createMap();
                        if (uri != null) {
                            map.putString("uri", uri.toString());
                        }
                        emit("onCameraRollChange", map);
                    }
                }
        );
    }

    private void emit(String eventName, WritableMap data) {
        try {
            if (this.emitter == null) {
                this.emitter = this.reactContext.getJSModule(DeviceEventManagerModule.RCTDeviceEventEmitter.class);
            }
            emitter.emit(eventName, data);
        } catch (Throwable e) {

        }
    }


    @Override
    public String getName() {
        return MODULE_NAME;
    }

    private void setConfiguration(final ReadableMap options) {
        mediaType = options.hasKey("mediaType") ? options.getString("mediaType") : "any";
        multiple = options.hasKey("multiple") && options.getBoolean("multiple");
        width = options.hasKey("width") ? options.getInt("width") : PREFINE_CROP_SIZE;
        height = options.hasKey("height") ? options.getInt("height") : PREFINE_CROP_SIZE;
        cropping = options.hasKey("cropping") && options.getBoolean("cropping");
        cropperActiveWidgetColor = options.hasKey("cropperActiveWidgetColor") ? options.getString("cropperActiveWidgetColor") : DEFAULT_TINT;
        cropperStatusBarColor = options.hasKey("cropperStatusBarColor") ? options.getString("cropperStatusBarColor") : DEFAULT_TINT;
        cropperToolbarColor = options.hasKey("cropperToolbarColor") ? options.getString("cropperToolbarColor") : DEFAULT_TINT;
        cropperToolbarTitle = options.hasKey("cropperToolbarTitle") ? options.getString("cropperToolbarTitle") : null;
        cropperCircleOverlay = !options.hasKey("cropperCircleOverlay") || options.getBoolean("cropperCircleOverlay");
        freeStyleCropEnabled = options.hasKey("freeStyleCropEnabled") && options.getBoolean("freeStyleCropEnabled");
        showCropGuidelines = !options.hasKey("showCropGuidelines") || options.getBoolean("showCropGuidelines");
        hideBottomControls = options.hasKey("hideBottomControls") && options.getBoolean("hideBottomControls");
        enableRotationGesture = !options.hasKey("enableRotationGesture") || options.getBoolean("enableRotationGesture");
        disableCropperColorSetters = options.hasKey("disableCropperColorSetters") && options.getBoolean("disableCropperColorSetters");
        maxFiles = options.hasKey("maxFiles") ? options.getInt("maxFiles") : 10;
        albumTitle = options.hasKey("albumTitle") ? options.getString("albumTitle") : albumTitle;
        currentSelections = options.hasKey("currentSelections") ? options.getArray("currentSelections") : null;
    }

    @ReactMethod
    public void openPicker(final ReadableMap options, final Promise promise) {
        final Activity activity = getCurrentActivity();

        if (activity == null) {
            promise.reject(E_ACTIVITY_DOES_NOT_EXIST, "Activity doesn't exist");
            return;
        }

        setConfiguration(options);
        resultPromise = promise;
//        resultCollector.setup(promise);

        permissionsCheck(activity, promise, Collections.singletonList(Manifest.permission.WRITE_EXTERNAL_STORAGE), new Callable<Void>() {
            @Override
            public Void call() {
                startImagePicker(activity);
                return null;
            }
        });
    }

    @ReactMethod
    public void openCamera(final ReadableMap options, final Promise promise) {
        final Activity activity = getCurrentActivity();

        if (activity == null) {
            promise.reject(E_ACTIVITY_DOES_NOT_EXIST, "Activity doesn't exist");
            return;
        }

        if (!isCameraAvailable(activity)) {
            promise.reject(E_CAMERA_IS_NOT_AVAILABLE, "Camera not available");
            return;
        }

        setConfiguration(options);
        resultPromise = promise;

        permissionsCheck(activity, promise, Arrays.asList(Manifest.permission.CAMERA, Manifest.permission.WRITE_EXTERNAL_STORAGE), new Callable<Void>() {
            @Override
            public Void call() {
                ImagePicker.cameraOnly().start(activity);
                return null;
            }
        });
    }

    @ReactMethod
    public void openCropper(final ReadableMap options, final Promise promise) {
        final Activity activity = getCurrentActivity();

        if (activity == null) {
            promise.reject(E_ACTIVITY_DOES_NOT_EXIST, "Activity doesn't exist");
            return;
        }

        setConfiguration(options);
        resultPromise = promise;

        Uri uri = Uri.parse(options.getString("path"));
        startCropping(activity, uri);
    }

    @ReactMethod
    public void getMedias(final ReadableMap options, final Promise promise) {
        try {
            QueryMediaAsyncTask asyncTask = new QueryMediaAsyncTask();
            asyncTask.promise = promise;
            asyncTask.options = options;

            String[] projection = {
                    MediaStore.Files.FileColumns._ID,
                    MediaStore.Files.FileColumns.DATA,
                    MediaStore.Files.FileColumns.DATE_ADDED,
                    MediaStore.Files.FileColumns.MEDIA_TYPE,
                    MediaStore.Files.FileColumns.MIME_TYPE,
                    MediaStore.Files.FileColumns.TITLE
            };
            String selection = MediaStore.Files.FileColumns.MEDIA_TYPE + "="
                    + MediaStore.Files.FileColumns.MEDIA_TYPE_IMAGE
                    + " OR "
                    + MediaStore.Files.FileColumns.MEDIA_TYPE + "="
                    + MediaStore.Files.FileColumns.MEDIA_TYPE_VIDEO;

            Uri externalUri = MediaStore.Files.getContentUri("external");
            Uri internalUri = MediaStore.Files.getContentUri("internal");

            CursorLoader externalCursorLoader = new CursorLoader(
                    reactContext,
                    externalUri,
                    projection,
                    selection,
                    null, // Selection args (none).
                    MediaStore.Files.FileColumns.DATE_ADDED + " DESC"
            );
            CursorLoader internalCursorLoader = new CursorLoader(
                    reactContext,
                    internalUri,
                    projection,
                    selection,
                    null, // Selection args (none).
                    MediaStore.Files.FileColumns.DATE_ADDED + " DESC"
            );
            Cursor externalCursor = externalCursorLoader.loadInBackground();
            Cursor internalCursor = internalCursorLoader.loadInBackground();
            List<Cursor> cursorArray = new ArrayList<>(2);
            if (externalCursor != null) {
                cursorArray.add(externalCursor);
            }
            if (internalCursor != null) {
                cursorArray.add(internalCursor);
            }
            asyncTask.cursorArray = cursorArray;
            asyncTask.execute(this.reactContext);
        } catch (Throwable e) {
            promise.resolve(null);
        }
    }

    @ReactMethod
    public void exportVideo(final ReadableMap options, final Promise promise) {
        try {
            String inputPath = options.getString("url");
            String videoId = inputPath;
            if (options.hasKey("id")) {
                videoId = options.getString("id");
            }
            if (!RNTImagePickerUtils.isBundleAsset(inputPath)) {
                Uri tempUri = Uri.parse(inputPath);
                inputPath = RealPathUtil.getRealPathFromURI(this.reactContext, tempUri);
            }
            if (inputPath == null || inputPath.length() == 0) {
                promise.reject("E_IMAGE_PICKER", "No Input file path");
                return;
            }
            ExportVideoAsyncTask exportVideoAsyncTask = new ExportVideoAsyncTask();
            exportVideoAsyncTask.mediaId = videoId;
            exportVideoAsyncTask.promise = promise;
            exportVideoAsyncTask.inputPath = inputPath;
            exportVideoAsyncTask.execute(this.reactContext);
        } catch (Throwable e) {
            promise.reject("E_IMAGE_PICKER", "Exception", e);
        }
    }

    @ReactMethod
    public void clean(final Promise promise) {

        final Activity activity = getCurrentActivity();
        final RNGalleryPickerModule module = this;

        if (activity == null) {
            promise.reject(E_ACTIVITY_DOES_NOT_EXIST, "Activity doesn't exist");
            return;
        }

        permissionsCheck(activity, promise, Collections.singletonList(Manifest.permission.WRITE_EXTERNAL_STORAGE), new Callable<Void>() {
            @Override
            public Void call() {
                try {
                    promise.resolve(null);
                } catch (Throwable ex) {
                    promise.reject(E_ERROR_WHILE_CLEANING_FILES, ex.getMessage());
                }

                return null;
            }
        });
    }


    private void permissionsCheck(final Activity activity, final Promise promise, final List<String> requiredPermissions, final Callable<Void> callback) {

        List<String> missingPermissions = new ArrayList<>();

        for (String permission : requiredPermissions) {
            int status = ActivityCompat.checkSelfPermission(activity, permission);
            if (status != PackageManager.PERMISSION_GRANTED) {
                missingPermissions.add(permission);
            }
        }

        if (!missingPermissions.isEmpty()) {

            ((PermissionAwareActivity) activity).requestPermissions(missingPermissions.toArray(new String[missingPermissions.size()]), 1, new PermissionListener() {

                @Override
                public boolean onRequestPermissionsResult(int requestCode, String[] permissions, int[] grantResults) {
                    if (requestCode == 1) {

                        for (int grantResult : grantResults) {
                            if (grantResult == PackageManager.PERMISSION_DENIED) {
                                promise.reject(E_PERMISSIONS_MISSING, "Required permission missing");
                                return true;
                            }
                        }

                        try {
                            callback.call();
                        } catch (Exception e) {
                            promise.reject(E_CALLBACK_ERROR, "Unknown error", e);
                        }
                    }

                    return true;
                }
            });

            return;
        }

        // all permissions granted
        try {
            callback.call();
        } catch (Exception e) {
            promise.reject(E_CALLBACK_ERROR, "Unknown error", e);
        }
    }


    private void startImagePicker(final Activity activity) {
        ArrayList<Image> selectedImages = new ArrayList<>();
        if (currentSelections != null) {
            for (int i = 0, n = currentSelections.size(); i < n; i++) {
                try {
                    ReadableMap tempImageInfo = currentSelections.getMap(i);
                    if (tempImageInfo != null && tempImageInfo.hasKey("sku")) {
                        String _tempSku = tempImageInfo.getString("sku");
                        if (_tempSku != null) {
                            Image tempImage = cachedImages.get(_tempSku);
                            if (tempImage != null) {
                                selectedImages.add(tempImage);
                            }
                        }
                    }
                } catch (Throwable e) {

                }
            }
        }
        ImagePicker imagePicker = ImagePicker.create(activity).limit(maxFiles).theme(R.style.ImagePickerTheme).toolbarFolderTitle(albumTitle);
        if (imagePicker != null) {
            if (errorImages.size() > 0) {
                imagePicker.exclude(errorImages);
            }
            if (cropping) {
                imagePicker.folderMode(false).single().includeVideo(false);
            } else {
                imagePicker.folderMode(true);
                if (selectedImages.size() > 0) {
                    imagePicker.origin(selectedImages);
                }
                if (mediaType.equals("any") || mediaType.equals("video")) {
                    imagePicker.includeVideo(true);
                } else {
                    imagePicker.includeVideo(true);
                }
                if (multiple) {
                    imagePicker.multi();
                } else {
                    imagePicker.single();
                }
            }
            imagePicker.start();
        }

    }


    private BitmapFactory.Options validateImage(String path) throws Exception {
        BitmapFactory.Options options = new BitmapFactory.Options();
        options.inJustDecodeBounds = true;
        options.inPreferredConfig = Bitmap.Config.RGB_565;
        options.inDither = true;

        BitmapFactory.decodeFile(path, options);

        if (options.outMimeType == null || options.outWidth == 0 || options.outHeight == 0) {
            throw new Exception("Invalid image selected");
        }

        return options;
    }

    private void configureCropperColors(UCrop.Options options) {
        int activeWidgetColor = Color.parseColor(cropperActiveWidgetColor);
        int toolbarColor = Color.parseColor(cropperToolbarColor);
        int statusBarColor = Color.parseColor(cropperStatusBarColor);
        options.setToolbarColor(toolbarColor);
        options.setStatusBarColor(statusBarColor);
        if (activeWidgetColor == Color.parseColor(DEFAULT_TINT)) {
            /*
            Default tint is grey => use a more flashy color that stands out more as the call to action
            Here we use 'Light Blue 500' from https://material.google.com/style/color.html#color-color-palette
            */
            options.setActiveWidgetColor(Color.parseColor(DEFAULT_WIDGET_COLOR));
        } else {
            //If they pass a custom tint color in, we use this for everything
            options.setActiveWidgetColor(activeWidgetColor);
        }
    }

    private void startCropping(Activity activity, Uri uri) {
        UCrop.Options options = new UCrop.Options();
        options.setCompressionFormat(Bitmap.CompressFormat.JPEG);
        options.setCompressionQuality(100);
        options.setCircleDimmedLayer(cropperCircleOverlay);
        options.setFreeStyleCropEnabled(freeStyleCropEnabled);
        options.setShowCropGrid(showCropGuidelines);
        options.setHideBottomControls(hideBottomControls);
        if (cropperToolbarTitle != null) {
            options.setToolbarTitle(cropperToolbarTitle);
        }
        if (enableRotationGesture) {
            // UCropActivity.ALL = enable both rotation & scaling
            options.setAllowedGestures(
                    UCropActivity.ALL, // When 'scale'-tab active
                    UCropActivity.ALL, // When 'rotate'-tab active
                    UCropActivity.ALL  // When 'aspect ratio'-tab active
            );
        }
        if (!disableCropperColorSetters) {
            configureCropperColors(options);
        }
        String path = uri.getPath();
        File tempOutputFile = RealPathUtil.createTempFile(path, "crop", "jpeg", null, this.reactContext);
        try {
            String tempCachePath = RealPathUtil.getRealPathFromURI(this.reactContext, uri);
            BitmapFactory.Options bitmapOptions = validateImage(tempCachePath);
            double tempWidth = bitmapOptions.outWidth;
            double tempHeight = bitmapOptions.outHeight;
            try {
                ExifInterface exif = new ExifInterface(tempCachePath);
                int orientation = exif.getAttributeInt(ExifInterface.TAG_ORIENTATION, ExifInterface.ORIENTATION_NORMAL);
                switch (orientation) {
                    case ExifInterface.ORIENTATION_ROTATE_90:
                    case ExifInterface.ORIENTATION_ROTATE_270: {
                        double _tempWidth = width;
                        tempWidth = tempHeight;
                        tempHeight = _tempWidth;
                    }
                    break;
                }
            } catch (Throwable ex) {
            }
            if (width > 0 && height > 0 && tempWidth > 0 && tempHeight > 0) {
                if (width == PREFINE_CROP_SIZE) {
                    width = (int) Math.min(tempWidth, tempHeight);
                    height = width;
                }
                double sourceRatio = width / height;
                if (tempWidth < width) {
                    if ((tempWidth / sourceRatio) <= tempHeight) {
                        width = (int) tempWidth;
                        height = (int) (tempWidth / sourceRatio);
                    } else {
                        width = (int) (tempHeight * sourceRatio);
                        height = (int) tempHeight;
                    }
                } else if (tempHeight < height) {
                    if ((tempHeight * sourceRatio) <= tempWidth) {
                        width = (int) (tempHeight * sourceRatio);
                        height = (int) tempHeight;
                    } else {
                        width = (int) tempWidth;
                        height = (int) (tempWidth / sourceRatio);
                    }
                }
            }
        } catch (Throwable e) {

        }

        UCrop uCrop = UCrop
                .of(uri, Uri.fromFile(tempOutputFile))
                .withOptions(options);

        if (width > 0 && height > 0) {
            uCrop.withMaxResultSize(width, height).withAspectRatio(width, height);
        }

        uCrop.start(activity);
    }

    private void croppingResult(final Intent data) {
        try {
            final Uri resultUri = UCrop.getOutput(data);
            WritableMap imageMap = RNTImagePickerUtils.resolveMedia(this.reactContext, resultUri);
            if (imageMap != null) {
                imageMap.putMap("cropRect", RNGalleryPickerModule.getCroppedRectMap(data));
                WritableArray resultArray = new WritableNativeArray();
                resultArray.pushMap(imageMap);
                resultPromise.resolve(resultArray);
                return;
            }
        } catch (Throwable ex) {
        }
        if (resultPromise != null) {
            resultPromise.reject(ERROR_RNT_IMAGE_PICKER_MEDIA_NOT_FOUND, "Could not file crop result");
        }
    }

    @Override
    public void onActivityResult(Activity activity, final int requestCode, final int resultCode, final Intent data) {
        if (ImagePicker.shouldHandle(requestCode, resultCode, data)) {
            // Get a list of picked images
            WritableNativeArray resultArray = new WritableNativeArray();
            if (!cropping && multiple) {
                List<Image> images = ImagePicker.getImages(data);
                if (images != null && images.size() > 0) {

                    for (Image tempImage : images) {
                        String tempPath = tempImage.getPath();
                        String mime = RNTImagePickerUtils.getMimeType(activity, tempPath);
                        if (Patterns.WEB_URL.matcher(tempPath).matches()) {

                        }
                        final WritableMap mediaMap;
                        String imageId = tempImage.getId() + "";
                        if (mime != null && mime.startsWith("video/")) {
                            mediaMap = RNTImagePickerUtils.resolveVideo(imageId, tempPath);
                        } else {
                            mediaMap = RNTImagePickerUtils.resolveImage(imageId, tempPath);
                        }
                        if (mediaMap != null) {
                            if (mediaMap.hasKey("sku")) {
                                String _tempSku = mediaMap.getString("sku");
                                if (_tempSku != null) {
                                    cachedImages.put(_tempSku, tempImage);
                                }
                            }
                            resultArray.pushMap(mediaMap);
                        } else {
                            errorImages.add(tempImage);
                        }
                    }
                }
                if (resultPromise != null) {
                    resultPromise.resolve(resultArray);
                }
            } else {
                Image image = ImagePicker.getFirstImageOrNull(data);
                String tempPath = image.getPath();
                if (cropping) {
                    WritableMap mediaMap = RNTImagePickerUtils.resolveImage(image.getId() + "", tempPath);
                    if (mediaMap != null) {
                        tempPath = mediaMap.getString("url");
                        Uri tempUri = Uri.parse(tempPath);
                        startCropping(activity, tempUri);
                    } else {
                        errorImages.add(image);
                        resultPromise.reject(ERROR_RNT_IMAGE_PICKER_MEDIA_NOT_FOUND, "Media not found or invalid");
                    }
                } else {
                    String mime = RNTImagePickerUtils.getMimeType(activity, tempPath);
                    if (Patterns.WEB_URL.matcher(tempPath).matches()) {

                    }
                    WritableMap mediaMap;
                    if (mime != null && mime.startsWith("video/")) {
                        mediaMap = RNTImagePickerUtils.resolveVideo(image.getId() + "", tempPath);
                    } else {
                        mediaMap = RNTImagePickerUtils.resolveImage(image.getId() + "", tempPath);
                    }
                    if (mediaMap != null) {
                        if (mediaMap.hasKey("sku")) {
                            String _tempSku = mediaMap.getString("sku");
                            if (_tempSku != null) {
                                cachedImages.put(_tempSku, image);
                            }
                        }
                        resultArray.pushMap(mediaMap);
                    } else {
                        errorImages.add(image);
                    }
                    if (resultPromise != null) {
                        resultPromise.resolve(resultArray);
                    }
                }
            }
        } else if (requestCode == UCrop.REQUEST_CROP) {
            croppingResult(data);
        }
    }

    @Override
    public void onNewIntent(Intent intent) {
    }

    private boolean isCameraAvailable(Activity activity) {
        return activity.getPackageManager().hasSystemFeature(PackageManager.FEATURE_CAMERA)
                || activity.getPackageManager().hasSystemFeature(PackageManager.FEATURE_CAMERA_ANY);
    }

    private static WritableMap getCroppedRectMap(Intent data) {
        final int DEFAULT_VALUE = -1;
        final WritableMap map = new WritableNativeMap();

        map.putInt("x", data.getIntExtra(UCrop.EXTRA_OUTPUT_OFFSET_X, DEFAULT_VALUE));
        map.putInt("y", data.getIntExtra(UCrop.EXTRA_OUTPUT_OFFSET_Y, DEFAULT_VALUE));
        map.putInt("width", data.getIntExtra(UCrop.EXTRA_OUTPUT_IMAGE_WIDTH, DEFAULT_VALUE));
        map.putInt("height", data.getIntExtra(UCrop.EXTRA_OUTPUT_IMAGE_HEIGHT, DEFAULT_VALUE));

        return map;
    }
}
