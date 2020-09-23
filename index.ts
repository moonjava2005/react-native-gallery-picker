// @ts-ignore
import { EventEmitter, NativeEventEmitter, NativeModules } from 'react-native'

const RNGalleryPicker = NativeModules.RNGalleryPicker
const RNTImagePickerEventEmitter: EventEmitter = new NativeEventEmitter(RNGalleryPicker)

const callbackMap: any = {}

export function addExportVideoProgressListener(id: string, callback: (progress: number) => void) {
    if (RNTImagePickerEventEmitter) {
        callbackMap[id] = RNTImagePickerEventEmitter.addListener('onExportVideoProgress',
            ({ id: resultId, progress }: { id: string, progress: number }) => {
                if (progress >= 100) {
                    if (resultId && callbackMap[resultId]) {
                        callbackMap[resultId].remove()
                        delete callbackMap[resultId]
                    }
                }
                if (resultId && resultId === id) {
                    callback && callback(progress)
                }
            }, null)
    }
}

export function addCameraRollChangeListener(callback: () => void) {
    if (RNTImagePickerEventEmitter) {
        return RNTImagePickerEventEmitter.addListener('onCameraRollChange', callback, null)
    }
    return null
}

export function getRecentMedia(option?: { size?: number }): Promise<{
    type: 'image' | 'video'
    id: string | null
    sku?: string | null
    url: string | null
    width: number
    height: number
    ratio: number
    mimeType?: string | null
    exif?: any | null
    cropRect?: {
                   x: number
                   y: number
                   width: number
                   height: number
               } | null
    creationDate: number
    modificationDate: number
}[]> {
    return RNGalleryPicker.getMedias(option)
}

export default RNGalleryPicker
