// @ts-ignore
import { EventEmitter, NativeEventEmitter, NativeModules } from 'react-native'

const RNGalleryPicker = NativeModules.RNGalleryPicker
const RNTImagePickerEventEmitter: EventEmitter = new NativeEventEmitter(RNGalleryPicker)

const callbackMap: any = {}

type MediaResultType = {
    creationDate: number
    exif?: any | null
    cropRect?: {
                   x: number
                   y: number
                   width: number
                   height: number
               } | null
    height: number
    id: string
    mimeType: string
    modificationDate: number
    ratio: number
    sku: string
    type: 'image' | 'video'
    url: string
    width: number
}

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

export function getRecentMedia(option?: { size?: number }): Promise<MediaResultType[]> {
    return RNGalleryPicker.getMedias(option)
}

export function openPicker(options?: {
    currentSelections?: { sku: string }[]
    multiple?: boolean
    minFiles?: number
    maxFiles?: number
    showsSelectedCount?: boolean
    smartAlbums?: boolean
    cropping?: boolean
    mediaType: 'any' | 'photo' | 'video'
}): Promise<MediaResultType> {
    return RNGalleryPicker.openPicker(options)
}

export function openCropper(options?: {
    path: string
}): Promise<MediaResultType> {
    return RNGalleryPicker.openCropper(options)
}

export function openCamera(options?: {
    useFrontCamera?: boolean
}): Promise<MediaResultType> {
    return RNGalleryPicker.openCamera(options)
}
