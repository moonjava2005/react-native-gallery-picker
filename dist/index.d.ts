declare type MediaResultType = {
    creationDate: number;
    exif?: any | null;
    cropRect?: {
        x: number;
        y: number;
        width: number;
        height: number;
    } | null;
    height: number;
    id: string;
    mimeType: string;
    modificationDate: number;
    ratio: number;
    sku: string;
    type: 'image' | 'video';
    url: string;
    width: number;
};
export declare function addExportVideoProgressListener(id: string, callback: (progress: number) => void): void;
export declare function addCameraRollChangeListener(callback: () => void): any;
export declare function getRecentMedia(option?: {
    size?: number;
}): Promise<MediaResultType[]>;
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
}): Promise<MediaResultType[]>;
export declare function openCropper(options?: {
    path: string;
}): Promise<MediaResultType>;
export declare function openCamera(options?: {
    useFrontCamera?: boolean;
}): Promise<MediaResultType>;
export declare function exportVideo(option: {
    url: string;
    id?: string | null;
    compressVideoPreset?: '640x480' | '960x540' | '1280x720' | '1920x1080' | 'LowQuality' | 'MediumQuality' | 'HighestQuality' | 'Passthrough';
}): Promise<{
    filePath: string;
    playableDuration: number;
    width: number;
    height: number;
    ratio: number;
}>;
export {};
