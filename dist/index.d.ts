declare const RNGalleryPicker: any;
export declare function addExportVideoProgressListener(id: string, callback: (progress: number) => void): void;
export declare function addCameraRollChangeListener(callback: () => void): any;
export declare function getRecentMedia(option?: {
    size?: number;
}): Promise<{
    type: 'image' | 'video';
    id: string | null;
    sku?: string | null;
    url: string | null;
    width: number;
    height: number;
    ratio: number;
    mimeType?: string | null;
    exif?: any | null;
    cropRect?: {
        x: number;
        y: number;
        width: number;
        height: number;
    } | null;
    creationDate: number;
    modificationDate: number;
}[]>;
export default RNGalleryPicker;
