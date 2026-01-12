#import "ReactNativeExif.h"

#import <React/RCTBridgeModule.h>
#import <Photos/Photos.h>

#import "Exif/RNExifReader.h"

static BOOL RNExifFileExistsAtPath(NSString *path) {
    if (path.length == 0) {
        return NO;
    }

    NSURL *url = [NSURL URLWithString:path];
    if (url && url.isFileURL) {
        return [[NSFileManager defaultManager] fileExistsAtPath:url.path];
    }

    if (url && url.scheme.length > 0) {
        return NO;
    }

    return [[NSFileManager defaultManager] fileExistsAtPath:path];
}

static BOOL RNExifIsPhotoLibraryPath(NSString *path) {
    if (path.length == 0) {
        return NO;
    }

    if ([path hasPrefix:@"ph://"] || [path hasPrefix:@"assets-library://"]) {
        return YES;
    }

    NSURL *url = [NSURL URLWithString:path];
    if (url && url.scheme.length > 0 && !url.isFileURL) {
        return YES;
    }

    return NO;
}

static NSString *RNExifPhotoIdentifierFromPath(NSString *path) {
    if ([path hasPrefix:@"ph://"]) {
        return [path substringFromIndex:5];
    }
    return path;
}

static void RNExifRequestPhotoAuthorization(void (^completion)(BOOL granted)) {
    if (@available(iOS 14, *)) {
        [PHPhotoLibrary requestAuthorizationForAccessLevel:PHAccessLevelReadWrite
                                                   handler:^(PHAuthorizationStatus status) {
                                                     BOOL granted = (status == PHAuthorizationStatusAuthorized ||
                                                                     status == PHAuthorizationStatusLimited);
                                                     completion(granted);
                                                   }];
    } else {
        [PHPhotoLibrary requestAuthorization:^(PHAuthorizationStatus status) {
          BOOL granted = (status == PHAuthorizationStatusAuthorized);
          completion(granted);
        }];
    }
}

static void RNExifFetchAssetData(NSString *path,
                                 void (^completion)(NSData *data, NSError *error)) {
    RNExifRequestPhotoAuthorization(^(BOOL granted) {
        if (!granted) {
            NSError *error =
                [NSError errorWithDomain:@"ReactNativeExifError"
                                    code:20
                                userInfo:@{NSLocalizedDescriptionKey : @"Permissao para fotos negada"}];
            completion(nil, error);
            return;
        }

        PHFetchResult<PHAsset *> *assets = nil;
        if ([path hasPrefix:@"assets-library://"]) {
            NSURL *url = [NSURL URLWithString:path];
            if (url) {
                assets = [PHAsset fetchAssetsWithALAssetURLs:@[ url ] options:nil];
            }
        } else {
            NSString *identifier = RNExifPhotoIdentifierFromPath(path);
            assets = [PHAsset fetchAssetsWithLocalIdentifiers:@[ identifier ] options:nil];
        }

        PHAsset *asset = assets.firstObject;
        if (!asset) {
            NSError *error =
                [NSError errorWithDomain:@"ReactNativeExifError"
                                    code:21
                                userInfo:@{NSLocalizedDescriptionKey : @"Asset nao encontrado"}];
            completion(nil, error);
            return;
        }

        PHImageRequestOptions *options = [[PHImageRequestOptions alloc] init];
        options.networkAccessAllowed = YES;
        options.resizeMode = PHImageRequestOptionsResizeModeNone;
        options.deliveryMode = PHImageRequestOptionsDeliveryModeHighQualityFormat;
        options.version = PHImageRequestOptionsVersionOriginal;

        [[PHImageManager defaultManager]
            requestImageDataAndOrientationForAsset:asset
                                            options:options
                                      resultHandler:^(NSData *imageData,
                                                      NSString *dataUTI,
                                                      CGImagePropertyOrientation orientation,
                                                      NSDictionary *info) {
                                        NSError *error = info[PHImageErrorKey];
                                        if (!imageData || error) {
                                            NSError *finalError =
                                                error ?: [NSError errorWithDomain:@"ReactNativeExifError"
                                                                            code:22
                                                                        userInfo:@{NSLocalizedDescriptionKey : @"Nao foi possivel ler o asset"}];
                                            completion(nil, finalError);
                                            return;
                                        }
                                        completion(imageData, nil);
                                      }];
    });
}

static void RNExifGetExif(NSString *path,
                          RCTPromiseResolveBlock resolve,
                          RCTPromiseRejectBlock reject) {
    if (RNExifFileExistsAtPath(path) || !RNExifIsPhotoLibraryPath(path)) {
        NSError *error = nil;
        NSDictionary *exifData = [RNExifReader exifDataForPath:path error:&error];

        if (!exifData) {
            reject(@"EXIF_ERROR", error.localizedDescription ?: @"Erro ao ler EXIF", error);
            return;
        }

        resolve(exifData);
        return;
    }

    RNExifFetchAssetData(path, ^(NSData *data, NSError *error) {
        if (!data) {
            reject(@"EXIF_ERROR", error.localizedDescription ?: @"Erro ao ler EXIF", error);
            return;
        }

        NSError *readError = nil;
        NSMutableDictionary *exifData =
            [[RNExifReader exifDataForImageData:data error:&readError] mutableCopy];
        if (!exifData) {
            reject(@"EXIF_ERROR", readError.localizedDescription ?: @"Erro ao ler EXIF", readError);
            return;
        }
        exifData[@"originalUri"] = path ?: @"";
        resolve(exifData);
    });
}

static void RNExifGetLatLong(NSString *path,
                             RCTPromiseResolveBlock resolve,
                             RCTPromiseRejectBlock reject) {
    if (RNExifFileExistsAtPath(path) || !RNExifIsPhotoLibraryPath(path)) {
        NSError *error = nil;
        NSDictionary *latLong = [RNExifReader latLongForPath:path error:&error];

        if (!latLong) {
            reject(@"EXIF_ERROR", error.localizedDescription ?: @"Erro ao ler EXIF", error);
            return;
        }

        resolve(latLong);
        return;
    }

    RNExifFetchAssetData(path, ^(NSData *data, NSError *error) {
        if (!data) {
            reject(@"EXIF_ERROR", error.localizedDescription ?: @"Erro ao ler EXIF", error);
            return;
        }

        NSError *readError = nil;
        NSDictionary *latLong = [RNExifReader latLongForImageData:data error:&readError];
        if (!latLong) {
            reject(@"EXIF_ERROR", readError.localizedDescription ?: @"Erro ao ler EXIF", readError);
            return;
        }

        resolve(latLong);
    });
}

@implementation ReactNativeExif
RCT_EXPORT_MODULE()

- (NSNumber *)multiply:(double)a b:(double)b {
    NSNumber *result = @(a * b);

    return result;
}

#if !RNEXIF_HAS_CODEGEN
RCT_REMAP_METHOD(getExif,
                 getExif:(NSString *)path
                 resolve:(RCTPromiseResolveBlock)resolve
                 reject:(RCTPromiseRejectBlock)reject)
{
    RNExifGetExif(path, resolve, reject);
}
#else
- (void)getExif:(NSString *)path
        resolve:(RCTPromiseResolveBlock)resolve
         reject:(RCTPromiseRejectBlock)reject {
    RNExifGetExif(path, resolve, reject);
}
#endif

#if !RNEXIF_HAS_CODEGEN
RCT_REMAP_METHOD(getLatLong,
                 getLatLong:(NSString *)path
                 resolve:(RCTPromiseResolveBlock)resolve
                 reject:(RCTPromiseRejectBlock)reject)
{
    RNExifGetLatLong(path, resolve, reject);
}
#else
- (void)getLatLong:(NSString *)path
           resolve:(RCTPromiseResolveBlock)resolve
            reject:(RCTPromiseRejectBlock)reject {
    RNExifGetLatLong(path, resolve, reject);
}
#endif

#if RNEXIF_HAS_CODEGEN
- (std::shared_ptr<facebook::react::TurboModule>)getTurboModule:
    (const facebook::react::ObjCTurboModule::InitParams &)params
{
    return std::make_shared<facebook::react::NativeReactNativeExifSpecJSI>(params);
}
#endif

@end
