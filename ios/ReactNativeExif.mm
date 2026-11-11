#import "ReactNativeExif.h"

#import <React/RCTBridgeModule.h>
#import <Photos/Photos.h>
#import <CoreLocation/CoreLocation.h>

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

static NSError *RNExifPhotoError(NSInteger code, NSString *message) {
    return [NSError errorWithDomain:@"ReactNativeExifError"
                               code:code
                           userInfo:@{NSLocalizedDescriptionKey : message}];
}

static dispatch_queue_t RNExifWorkQueue(void) {
    return dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0);
}

// So pede permissao quando ainda nao foi decidida; caso contrario usa o
// status atual sem passar pelo PHPhotoLibrary a cada chamada.
static void RNExifRequestPhotoAuthorization(void (^completion)(BOOL granted)) {
    if (@available(iOS 14, *)) {
        PHAuthorizationStatus status =
            [PHPhotoLibrary authorizationStatusForAccessLevel:PHAccessLevelReadWrite];
        if (status != PHAuthorizationStatusNotDetermined) {
            completion(status == PHAuthorizationStatusAuthorized ||
                       status == PHAuthorizationStatusLimited);
            return;
        }
        [PHPhotoLibrary requestAuthorizationForAccessLevel:PHAccessLevelReadWrite
                                                   handler:^(PHAuthorizationStatus newStatus) {
                                                     completion(newStatus == PHAuthorizationStatusAuthorized ||
                                                                newStatus == PHAuthorizationStatusLimited);
                                                   }];
    } else {
        PHAuthorizationStatus status = [PHPhotoLibrary authorizationStatus];
        if (status != PHAuthorizationStatusNotDetermined) {
            completion(status == PHAuthorizationStatusAuthorized);
            return;
        }
        [PHPhotoLibrary requestAuthorization:^(PHAuthorizationStatus newStatus) {
          completion(newStatus == PHAuthorizationStatusAuthorized);
        }];
    }
}

static void RNExifFetchAsset(NSString *path,
                             void (^completion)(PHAsset *asset, NSError *error)) {
    RNExifRequestPhotoAuthorization(^(BOOL granted) {
        if (!granted) {
            completion(nil, RNExifPhotoError(20, @"Permissao para fotos negada"));
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
            completion(nil, RNExifPhotoError(21, @"Asset nao encontrado"));
            return;
        }
        completion(asset, nil);
    });
}

// Obtem a URL do arquivo do asset em vez de carregar todos os bytes em
// memoria: o ImageIO le so o cabecalho de metadados a partir da URL.
static void RNExifFetchAssetFileURL(PHAsset *asset,
                                    void (^completion)(NSURL *url, NSError *error)) {
    PHContentEditingInputRequestOptions *options =
        [[PHContentEditingInputRequestOptions alloc] init];
    options.networkAccessAllowed = YES;
    options.canHandleAdjustmentData = ^BOOL(PHAdjustmentData *adjustmentData) {
        return NO;
    };

    [asset requestContentEditingInputWithOptions:options
                               completionHandler:^(PHContentEditingInput *input,
                                                   NSDictionary *info) {
                                 NSURL *url = input.fullSizeImageURL;
                                 if (!url) {
                                     NSError *error = info[PHContentEditingInputErrorKey];
                                     completion(nil, error ?: RNExifPhotoError(22, @"Nao foi possivel ler o asset"));
                                     return;
                                 }
                                 // O completion vem na main queue; o parse vai para background.
                                 dispatch_async(RNExifWorkQueue(), ^{
                                   completion(url, nil);
                                 });
                               }];
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

    RNExifFetchAsset(path, ^(PHAsset *asset, NSError *error) {
        if (!asset) {
            reject(@"EXIF_ERROR", error.localizedDescription ?: @"Erro ao ler EXIF", error);
            return;
        }

        RNExifFetchAssetFileURL(asset, ^(NSURL *url, NSError *urlError) {
            if (!url) {
                reject(@"EXIF_ERROR", urlError.localizedDescription ?: @"Erro ao ler EXIF", urlError);
                return;
            }

            NSError *readError = nil;
            NSMutableDictionary *exifData =
                [[RNExifReader exifDataForPath:url.absoluteString error:&readError] mutableCopy];
            if (!exifData) {
                reject(@"EXIF_ERROR", readError.localizedDescription ?: @"Erro ao ler EXIF", readError);
                return;
            }
            exifData[@"originalUri"] = path ?: @"";
            resolve(exifData);
        });
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

    RNExifFetchAsset(path, ^(PHAsset *asset, NSError *error) {
        if (!asset) {
            reject(@"EXIF_ERROR", error.localizedDescription ?: @"Erro ao ler EXIF", error);
            return;
        }

        // A localizacao ja esta no banco do Photos: nenhum arquivo precisa ser lido.
        CLLocation *location = asset.location;
        if (location && CLLocationCoordinate2DIsValid(location.coordinate)) {
            resolve(@{
                @"latitude" : @(location.coordinate.latitude),
                @"longitude" : @(location.coordinate.longitude),
            });
            return;
        }

        RNExifFetchAssetFileURL(asset, ^(NSURL *url, NSError *urlError) {
            if (!url) {
                reject(@"EXIF_ERROR", urlError.localizedDescription ?: @"Erro ao ler EXIF", urlError);
                return;
            }

            NSError *readError = nil;
            NSDictionary *latLong = [RNExifReader latLongForPath:url.absoluteString error:&readError];
            if (!latLong) {
                reject(@"EXIF_ERROR", readError.localizedDescription ?: @"Erro ao ler EXIF", readError);
                return;
            }
            resolve(latLong);
        });
    });
}

@implementation ReactNativeExif
RCT_EXPORT_MODULE()

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
