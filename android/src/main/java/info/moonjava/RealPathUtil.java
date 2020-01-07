package info.moonjava;

import android.content.ContentUris;
import android.content.Context;
import android.database.Cursor;
import android.net.Uri;
import android.os.Build;
import android.os.Environment;
import android.provider.DocumentsContract;
import android.provider.MediaStore;

import com.facebook.react.bridge.Promise;

import java.io.File;
import java.io.FileOutputStream;
import java.io.InputStream;
import java.security.MessageDigest;
import java.util.UUID;

class RealPathUtil {

    public static String getRealPathFromURI(final Context context, final Uri uri) {

        try {
            final boolean isKitKat = Build.VERSION.SDK_INT == Build.VERSION_CODES.KITKAT;

            // DocumentProvider
            if (isKitKat && DocumentsContract.isDocumentUri(context, uri)) {
                // ExternalStorageProvider
                if (isExternalStorageDocument(uri)) {
                    final String docId = DocumentsContract.getDocumentId(uri);
                    final String[] split = docId.split(":");
                    final String type = split[0];

                    if ("primary".equalsIgnoreCase(type)) {
                        return Environment.getExternalStorageDirectory() + "/" + split[1];
                    } else {
                        final int splitIndex = docId.indexOf(':', 1);
                        final String tag = docId.substring(0, splitIndex);
                        final String path = docId.substring(splitIndex + 1);

                        String nonPrimaryVolume = getPathToNonPrimaryVolume(context, tag);
                        if (nonPrimaryVolume != null) {
                            String result = nonPrimaryVolume + "/" + path;
                            File file = new File(result);
                            if (file.exists() && file.canRead()) {
                                return result;
                            }
                            return null;
                        }
                    }
                }
                // DownloadsProvider
                else if (isDownloadsDocument(uri)) {
                    final String id = DocumentsContract.getDocumentId(uri);
                    final Uri contentUri = ContentUris.withAppendedId(
                            Uri.parse("content://downloads/public_downloads"), Long.valueOf(id));

                    return getDataColumn(context, contentUri, null, null);
                }
                // MediaProvider
                else if (isMediaDocument(uri)) {
                    final String docId = DocumentsContract.getDocumentId(uri);
                    final String[] split = docId.split(":");
                    final String type = split[0];

                    Uri contentUri = null;
                    if ("image".equals(type)) {
                        contentUri = MediaStore.Images.Media.EXTERNAL_CONTENT_URI;
                    } else if ("video".equals(type)) {
                        contentUri = MediaStore.Video.Media.EXTERNAL_CONTENT_URI;
                    } else if ("audio".equals(type)) {
                        contentUri = MediaStore.Audio.Media.EXTERNAL_CONTENT_URI;
                    }

                    final String selection = "_id=?";
                    final String[] selectionArgs = new String[]{
                            split[1]
                    };

                    return getDataColumn(context, contentUri, selection, selectionArgs);
                }
            }
            // MediaStore (and general)
            else if ("content".equalsIgnoreCase(uri.getScheme())) {
                // Return the remote address
                if (isGooglePhotosUri(uri))
                    return uri.getLastPathSegment();
                return getDataColumn(context, uri, null, null);
            }
            // File
            else if ("file".equalsIgnoreCase(uri.getScheme())) {
                return uri.getPath();
            }
        } catch (Throwable e) {

        }

        return uri.getPath();
    }

    /**
     * If an image/video has been selected from a cloud storage, this method
     * should be call to download the file in the cache folder.
     *
     * @param context  The context
     * @param fileName donwloaded file's name
     * @param uri      file's URI
     * @return file that has been written
     */
    private static File writeToFile(Context context, String fileName, Uri uri) {
        String extension = null;
        if (fileName != null) {
            int lastIndex = fileName.lastIndexOf('.');
            if (lastIndex >= 0) {
                extension = fileName.substring(lastIndex);
            }
        }
        String mediaId = uri.getPath();
        File file = createTempFile(mediaId, "media", extension, null, context);
        if (file.exists()) {
            file.delete();
        }
        try {
            FileOutputStream oos = new FileOutputStream(file);
            byte[] buf = new byte[8192];
            InputStream is = context.getContentResolver().openInputStream(uri);
            int c = 0;
            while ((c = is.read(buf, 0, buf.length)) > 0) {
                oos.write(buf, 0, c);
                oos.flush();
            }
            oos.close();
            is.close();
        } catch (Throwable e) {
        }
        return file;
    }

    /**
     * Get the value of the data column for this Uri. This is useful for
     * MediaStore Uris, and other file-based ContentProviders.
     *
     * @param context       The context.
     * @param uri           The Uri to query.
     * @param selection     (Optional) Filter used in the query.
     * @param selectionArgs (Optional) Selection arguments used in the query.
     * @return The value of the _data column, which is typically a file path.
     */
    private static String getDataColumn(Context context, Uri uri, String selection,
                                        String[] selectionArgs) {

        Cursor cursor = null;
        final String[] projection = {
                MediaStore.MediaColumns._ID,
                MediaStore.MediaColumns.DATA,
                MediaStore.Images.Media.DATA,
                MediaStore.MediaColumns.DISPLAY_NAME,
        };

        try {
            cursor = context.getContentResolver().query(uri, projection, selection, selectionArgs,
                    null);
            if (cursor != null && cursor.moveToFirst()) {
                // Fall back to writing to file if _data column does not exist
                final int index = cursor.getColumnIndex(MediaStore.MediaColumns.DATA);
                String path = index > -1 ? cursor.getString(index) : null;
                if (path == null) {
                    int imagePathIndex = cursor.getColumnIndex(MediaStore.Images.Media.DATA);
                    if (imagePathIndex > -1) {
                        path = cursor.getString(imagePathIndex);
                    }
                }
                if (path != null) {
                    return path;
                } else {
                    final int indexDisplayName = cursor.getColumnIndexOrThrow(MediaStore.MediaColumns.DISPLAY_NAME);
                    String fileName = cursor.getString(indexDisplayName);
                    File fileWritten = writeToFile(context, fileName, uri);
                    return fileWritten.getAbsolutePath();
                }
            }
        } finally {
            if (cursor != null)
                cursor.close();
        }
        return null;
    }


    /**
     * @param uri The Uri to check.
     * @return Whether the Uri authority is ExternalStorageProvider.
     */
    private static boolean isExternalStorageDocument(Uri uri) {
        return "com.android.externalstorage.documents".equals(uri.getAuthority());
    }

    /**
     * @param uri The Uri to check.
     * @return Whether the Uri authority is DownloadsProvider.
     */
    private static boolean isDownloadsDocument(Uri uri) {
        return "com.android.providers.downloads.documents".equals(uri.getAuthority());
    }

    /**
     * @param uri The Uri to check.
     * @return Whether the Uri authority is MediaProvider.
     */
    private static boolean isMediaDocument(Uri uri) {
        return "com.android.providers.media.documents".equals(uri.getAuthority());
    }

    /**
     * @param uri The Uri to check.
     * @return Whether the Uri authority is Google Photos.
     */
    public static boolean isGooglePhotosUri(Uri uri) {
        return "com.google.android.apps.photos.content".equals(uri.getAuthority());
    }

    private static String getPathToNonPrimaryVolume(Context context, String tag) {
        File[] volumes = context.getExternalCacheDirs();
        if (volumes != null) {
            for (File volume : volumes) {
                if (volume != null) {
                    String path = volume.getAbsolutePath();
                    if (path != null) {
                        int index = path.indexOf(tag);
                        if (index != -1) {
                            return path.substring(0, index) + tag;
                        }
                    }
                }
            }
        }
        return null;
    }

    static File createTempFile(String videoId, String prefix, String extension, final Promise promise, Context ctx) {
        String localId = videoId;
        if (localId != null) {
            localId = MD5(localId);
        }
        if (localId == null) {
            UUID uuid = UUID.randomUUID();
            localId = uuid.toString();
        }
        String fileName = prefix != null ? prefix + "-" + localId : "" + localId;
        if (extension == null) {
            extension = "mp4";
        }
        if (!extension.startsWith(".")) {
            extension = "." + extension;
        }

        File cacheDir = ctx.getCacheDir();
        File tempFile;
        try {
            tempFile = new File(cacheDir, fileName + extension);
        } catch (Throwable e) {
            if (promise != null) {
                promise.reject("Failed to create temp file", e.toString());
            }
            return null;
        }

        if (tempFile != null && tempFile.exists()) {
            tempFile.delete();
        }

        return tempFile;
    }

    public static String MD5(String md5) {
        try {
            MessageDigest digest = MessageDigest.getInstance("MD5");
            digest.update(md5.getBytes());
            byte messageDigest[] = digest.digest();
            StringBuffer hexString = new StringBuffer();
            for (int i = 0; i < messageDigest.length; i++) {
                hexString.append(Integer.toHexString(0xFF & messageDigest[i]));
            }
            return hexString.toString();
        } catch (Throwable e) {
        }
        return null;
    }
}
