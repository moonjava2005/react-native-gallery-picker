package info.moonjava.gallery.picker;

import android.os.AsyncTask;

import com.facebook.react.bridge.Promise;
import com.facebook.react.bridge.ReactApplicationContext;
import com.facebook.react.bridge.WritableMap;

public class ExportVideoAsyncTask extends AsyncTask<ReactApplicationContext, Void, WritableMap> {
    Promise promise;
    String mediaId;
    String inputPath;

    @Override
    protected WritableMap doInBackground(ReactApplicationContext... params) {
        try {
            WritableMap result = RNTImagePickerUtils.resolveVideo(mediaId, inputPath);
            if (result != null) {
                String filePath = result.getString("url");
                if (filePath != null) {
                    result.putString("filePath", filePath);
                    return result;
                }
            }
        } catch (Throwable e) {
            promise.reject("E_IMAGE_PICKER", "Export Video Fail");
        }
        return null;
    }

    @Override
    protected void onPostExecute(WritableMap event) {
        if (promise != null) {
            if (event != null) {
                promise.resolve(event);
            } else {
                promise.reject("E_IMAGE_PICKER", "Export Video Fail");
            }
        }
    }
}
