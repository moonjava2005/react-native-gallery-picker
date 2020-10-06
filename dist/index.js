"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.exportVideo = exports.openCamera = exports.openCropper = exports.openPicker = exports.getRecentMedia = exports.addCameraRollChangeListener = exports.addExportVideoProgressListener = void 0;
// @ts-ignore
var react_native_1 = require("react-native");
var RNGalleryPicker = react_native_1.NativeModules.RNGalleryPicker;
var RNTImagePickerEventEmitter = new react_native_1.NativeEventEmitter(RNGalleryPicker);
var callbackMap = {};
function addExportVideoProgressListener(id, callback) {
    if (RNTImagePickerEventEmitter) {
        callbackMap[id] = RNTImagePickerEventEmitter.addListener('onExportVideoProgress', function (_a) {
            var resultId = _a.id, progress = _a.progress;
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
exports.addExportVideoProgressListener = addExportVideoProgressListener;
function addCameraRollChangeListener(callback) {
    if (RNTImagePickerEventEmitter) {
        return RNTImagePickerEventEmitter.addListener('onCameraRollChange', callback, null);
    }
    return null;
}
exports.addCameraRollChangeListener = addCameraRollChangeListener;
function getRecentMedia(option) {
    return RNGalleryPicker.getMedias(option);
}
exports.getRecentMedia = getRecentMedia;
function openPicker(options) {
    return RNGalleryPicker.openPicker(options);
}
exports.openPicker = openPicker;
function openCropper(options) {
    return RNGalleryPicker.openCropper(options);
}
exports.openCropper = openCropper;
function openCamera(options) {
    return RNGalleryPicker.openCamera(options);
}
exports.openCamera = openCamera;
function exportVideo(option) {
    return RNGalleryPicker.exportVideo(option);
}
exports.exportVideo = exportVideo;
