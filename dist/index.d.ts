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
export declare function openPicker(options?: {
    currentSelections?: {
        sku: string;
    }[];
    multiple?: boolean;
    minFiles?: number;
    maxFiles?: number;
    showsSelectedCount?: boolean;
    smartAlbums?: boolean;
    cropping?: boolean;
    mediaType: 'any' | 'photo' | 'video';
}): Promise<any>;
export declare function openCropper(options?: {
    path: string;
}): Promise<any>;
export declare function openCamera(options?: {
    useFrontCamera?: boolean;
}): Promise<any>;
