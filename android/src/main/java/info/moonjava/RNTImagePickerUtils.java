package info.moonjava;

import android.content.ContentResolver;
import android.content.Context;
import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.media.ExifInterface;
import android.media.MediaMetadataRetriever;
import android.net.Uri;
import android.util.Patterns;
import android.webkit.MimeTypeMap;

import com.facebook.react.bridge.WritableMap;
import com.facebook.react.bridge.WritableNativeMap;

import java.io.File;

public class RNTImagePickerUtils {
    public static String getMimeType(Context context, String url) {
        String mimeType = null;
        Uri uri = Uri.fromFile(new File(url));
        if (uri.getScheme().equals(ContentResolver.SCHEME_CONTENT)) {
            ContentResolver cr = context.getContentResolver();
            mimeType = cr.getType(uri);
        } else {
            String fileExtension = MimeTypeMap.getFileExtensionFromUrl(uri
                    .toString());
            if (fileExtension != null) {
                mimeType = MimeTypeMap.getSingleton().getMimeTypeFromExtension(fileExtension.toLowerCase());
            }
        }
        return mimeType;
    }

    public static boolean isBundleAsset(String path) {
        if (null != path) {
            return path.startsWith("bundle-assets://");
        }
        return false;
    }

    public static BitmapFactory.Options validateImage(String path) throws Exception {
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

    public static WritableMap resolveMedia(Context context, Uri uri) {
        String realPath = RealPathUtil.getRealPathFromURI(context, uri);
        if (realPath != null) {
            String mediaId = RealPathUtil.MD5(realPath);
            String mime = RNTImagePickerUtils.getMimeType(context, realPath);
            if (Patterns.WEB_URL.matcher(realPath).matches()) {

            }
            if (mime != null && mime.startsWith("video/")) {
                return RNTImagePickerUtils.resolveVideo(mediaId, realPath);
            }
            return RNTImagePickerUtils.resolveImage(mediaId, realPath);
        }
        return null;
    }

    public static WritableMap resolveVideo(String mediaId, String inputPath) {
        double ratio = 0;
        MediaMetadataRetriever retriever = null;
        try {
            if (inputPath != null) {
                retriever = new MediaMetadataRetriever();
                retriever.setDataSource(inputPath);
                final double playableDuration = Integer.parseInt(retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_DURATION));
                double width = Integer.parseInt(retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_WIDTH));
                double height = Integer.parseInt(retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_HEIGHT));
                int orientation = Integer.parseInt(retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_ROTATION));
                if (width > 0 && height > 0) {
                    if (orientation == 90 || orientation == 270) {
                        double tempValue = height;
                        height = width;
                        width = tempValue;
                    }
                    ratio = width / height;
                }
                File tempFile = new File(inputPath);
                double modificationDate = tempFile.lastModified();

                WritableMap video = new WritableNativeMap();
                video.putString("type", "video");
                if (mediaId != null) {
                    video.putString("id", mediaId);
                }
                video.putString("url", "file://" + inputPath);
                video.putString("coverUrl", "file://" + inputPath);
                video.putInt("width", (int) width);
                video.putInt("height", (int) height);
                video.putDouble("ratio", ratio);
                video.putDouble("playableDuration", playableDuration);
                video.putDouble("creationDate", modificationDate);
                video.putDouble("modificationDate", modificationDate);
                return video;
            }
        } catch (Throwable e) {
        } finally {
            if (retriever != null) {
                retriever.release();
            }
        }
        return null;
    }

    public static WritableMap resolveImage(String imageId, String inputPath) {
        try {
            if (inputPath != null) {
                WritableMap image = new WritableNativeMap();
                BitmapFactory.Options options = RNTImagePickerUtils.validateImage(inputPath);
                long modificationDate = new File(inputPath).lastModified();
                double ratio = 1;
                double width = options.outWidth;
                double height = options.outHeight;
                try {
                    ExifInterface exif = new ExifInterface(inputPath);
                    int orientation = exif.getAttributeInt(ExifInterface.TAG_ORIENTATION, ExifInterface.ORIENTATION_NORMAL);
                    switch (orientation) {
                        case ExifInterface.ORIENTATION_ROTATE_90:
                        case ExifInterface.ORIENTATION_ROTATE_270: {
                            double tempWidth = width;
                            width = height;
                            height = tempWidth;
                        }
                        break;
                    }
                } catch (Throwable ex) {
                }
                if (width > 0 && height > 0) {
                    ratio = (width / height);
                }
                image.putString("type", "image");
                image.putString("id", imageId);
                image.putString("url", "file://" + inputPath);
                image.putInt("width", (int) width);
                image.putInt("height", (int) height);
                image.putDouble("ratio", ratio);
                image.putString("mimeType", options.outMimeType);
                image.putDouble("creationDate", modificationDate);
                image.putDouble("modificationDate", modificationDate);
                return image;
            }
        } catch (Throwable e) {

        }
        return null;
    }
}
