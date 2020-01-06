import React from 'react';

import {NativeEventEmitter, NativeModules} from 'react-native';

const RNTImagePicker = NativeModules.RNTImagePicker;
const RNTImagePickerEventEmitter = new NativeEventEmitter(RNTImagePicker);

let callbackMap = {};

export function addExportVideoProgressListener(id, callback) {
    if (RNTImagePickerEventEmitter) {
        callbackMap[id] = RNTImagePickerEventEmitter.addListener('onExportVideoProgress', ({id: resultId, progress}) => {
            if (progress >= 100) {
                if (resultId && callbackMap[resultId]) {
                    callbackMap[resultId].remove();
                    delete callbackMap[resultId];
                }
            }
            if (resultId && resultId === id) {
                callback && callback(progress);
            }
        }, null);
    }
}
export function addCameraRollChangeListener(callback) {
    if (RNTImagePickerEventEmitter) {
        return RNTImagePickerEventEmitter.addListener('onCameraRollChange', callback, null);
    }
    return null;
}

export default RNTImagePicker;
