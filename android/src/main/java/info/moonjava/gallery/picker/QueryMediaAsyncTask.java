package info.moonjava.gallery.picker;

import android.database.Cursor;
import android.database.MergeCursor;
import android.net.Uri;
import android.os.AsyncTask;
import android.provider.MediaStore;
import android.util.Log;

import com.facebook.react.bridge.Promise;
import com.facebook.react.bridge.ReactApplicationContext;
import com.facebook.react.bridge.ReadableMap;
import com.facebook.react.bridge.WritableMap;
import com.facebook.react.bridge.WritableNativeArray;

import java.util.ArrayList;
import java.util.List;

public class QueryMediaAsyncTask extends AsyncTask<ReactApplicationContext, Void, WritableNativeArray> {
    Promise promise;
    ReadableMap options;
    List<Cursor> cursorArray;

    @Override
    protected WritableNativeArray doInBackground(ReactApplicationContext... reactContexts) {
        WritableNativeArray mediaArray = new WritableNativeArray();
        if (reactContexts != null && reactContexts.length > 0) {
            ReactApplicationContext reactContext = reactContexts[0];
            if (reactContext != null && cursorArray != null) {
                try {
                    int size = 20;
                    if (options.hasKey("size")) {
                        size = options.getInt("size");
                    }
                    if (cursorArray.size() > 0) {
                        Cursor cursors[] = new Cursor[cursorArray.size()];
                        MergeCursor mergeCursor = new MergeCursor(cursorArray.toArray(cursors));
                        int count = Math.min(mergeCursor.getCount(), size);
                        List<MediaItem> mediaList = new ArrayList<>(count);
                        for (int i = 0; i < count; i++) {
                            mergeCursor.moveToPosition(i);
                            final int index = mergeCursor.getColumnIndex(MediaStore.MediaColumns.DATA);
                            String path = index > -1 ? mergeCursor.getString(index) : null;
                            if (path != null) {
                                path = "file://" + path;
                                int dateIndex = mergeCursor.getColumnIndex(MediaStore.MediaColumns.DATE_ADDED);
                                if (dateIndex >= 0) {
                                    double createdDate = mergeCursor.getDouble(dateIndex);
                                    String mediaId = RealPathUtil.MD5(path);
                                    MediaItem tempMedia = new MediaItem();
                                    tempMedia.mediaId = mediaId;
                                    tempMedia.uri = Uri.parse(path);
                                    tempMedia.creationDate = createdDate;
                                    mediaList.add(tempMedia);
                                }
                            }
                        }
                        for (MediaItem mediaItem : mediaList) {
                            Uri contentUri = mediaItem.uri;
                            if (contentUri != null) {
                                WritableMap mediaInfo = RNTImagePickerUtils.resolveMedia(reactContext, contentUri);
                                if (mediaInfo != null) {
                                    mediaArray.pushMap(mediaInfo);
                                }
                            }
                        }
                    }
                } catch (Throwable e) {
                    Log.e("ImagePicker", "Error", e);
                } finally {
                    if (cursorArray != null) {
                        for (Cursor tempCursor : cursorArray) {
                            if (tempCursor != null) {
                                tempCursor.close();
                            }
                        }
                    }
                }
            }
        }
        return mediaArray;
    }

    @Override
    protected void onPostExecute(WritableNativeArray mediaArray) {
        if (promise != null) {
            promise.resolve(mediaArray);
        }
    }
}
