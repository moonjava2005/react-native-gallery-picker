import React from 'react';

import {NativeEventEmitter, NativeModules} from 'react-native';

const RNGalleryPicker = NativeModules.RNGalleryPicker;
const RNTImagePickerEventEmitter = new NativeEventEmitter(RNGalleryPicker);

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

export default RNGalleryPicker;
