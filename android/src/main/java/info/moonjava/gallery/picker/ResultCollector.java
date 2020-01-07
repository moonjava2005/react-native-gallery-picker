package info.moonjava;

import android.util.Log;

import com.facebook.react.bridge.Promise;
import com.facebook.react.bridge.WritableArray;
import com.facebook.react.bridge.WritableMap;
import com.facebook.react.bridge.WritableNativeArray;

import java.util.ArrayList;
import java.util.Collections;
import java.util.List;
import java.util.concurrent.atomic.AtomicInteger;

/**
 * Created by ipusic on 12/28/16.
 */

class ResultCollector {
    private Promise promise;
    private int waitCount;
    private AtomicInteger waitCounter;
    private List<WritableMap> resultArrayList;
    private boolean resultSent;

    synchronized void setup(Promise promise) {
        this.promise = promise;

        this.resultSent = false;
        this.waitCount = 1;
        this.waitCounter = new AtomicInteger(0);
        this.resultArrayList = new ArrayList<>();
    }

    // if user has provided "multiple" option, we will wait for X number of result to come,
    // and also return result as an array
    synchronized void setWaitCount(int waitCount) {
        this.waitCount = waitCount;
        this.waitCounter = new AtomicInteger(0);
    }

    synchronized private boolean isRequestValid() {
        if (resultSent) {
            Log.w("image-crop-picker", "Skipping result, already sent...");
            return false;
        }

        if (promise == null) {
            Log.w("image-crop-picker", "Trying to notify success but promise is not set");
            return false;
        }

        return true;
    }

    @SuppressWarnings("unchecked")
    synchronized void notifySuccess(WritableMap result) {
        if (!isRequestValid()) {
            return;
        }
        resultArrayList.add(result);
        int currentCount = waitCounter.addAndGet(1);

        if (currentCount == waitCount) {
            if (waitCount > 1) {
                Collections.sort(resultArrayList, (WritableMap map1, WritableMap map2) -> {
                    int order1 = Integer.MAX_VALUE;
                    int order2 = Integer.MAX_VALUE;
                    if (map1 != null && map1.hasKey("order")) {
                        order1 = map1.getInt("order");
                    }
                    if (map2 != null && map2.hasKey("order")) {
                        order2 = map2.getInt("order");
                    }
                    if (order1 < order2) {
                        return -1;
                    }
                    if (order1 > order2) {
                        return 1;
                    }
                    return 0;
                });
            }
            WritableArray arrayResult = new WritableNativeArray();
            if (resultArrayList != null && resultArrayList.size() > 0) {
                for (WritableMap writableMap : resultArrayList) {
                    arrayResult.pushMap(writableMap);
                }
            }
            promise.resolve(arrayResult);
            resultSent = true;
        }
    }

    synchronized void notifyProblem(String code, String message) {
        if (!isRequestValid()) {
            return;
        }

        Log.e("image-crop-picker", "Promise rejected. " + message);
        promise.reject(code, message);
        resultSent = true;
    }

    synchronized void notifyProblem(String code, Throwable throwable) {
        if (!isRequestValid()) {
            return;
        }

        Log.e("image-crop-picker", "Promise rejected. " + throwable.getMessage());
        promise.reject(code, throwable);
        resultSent = true;
    }
}
