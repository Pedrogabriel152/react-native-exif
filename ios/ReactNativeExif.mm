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

typedef void (^RNExifResultBlock)(NSDictionary *data, NSError *error);

static NSUInteger const RNExifBatchConcurrency = 4;

static BOOL RNExifIsLocalPath(NSString *path) {
    return RNExifFileExistsAtPath(path) || !RNExifIsPhotoLibraryPath(path);
}

// --- leitura por asset (compartilhada entre chamada individual e lote) ----

static void RNExifReadExifForAsset(PHAsset *asset, NSString *path, RNExifResultBlock completion) {
    RNExifFetchAssetFileURL(asset, ^(NSURL *url, NSError *urlError) {
        if (!url) {
            completion(nil, urlError);
            return;
        }

        NSError *readError = nil;
        NSMutableDictionary *exifData =
            [[RNExifReader exifDataForPath:url.absoluteString error:&readError] mutableCopy];
        if (!exifData) {
            completion(nil, readError);
            return;
        }
        exifData[@"originalUri"] = path ?: @"";
        completion(exifData, nil);
    });
}

static void RNExifReadLatLongForAsset(PHAsset *asset, RNExifResultBlock completion) {
    // A localizacao ja esta no banco do Photos: nenhum arquivo precisa ser lido.
    CLLocation *location = asset.location;
    if (location && CLLocationCoordinate2DIsValid(location.coordinate)) {
        completion(@{
            @"latitude" : @(location.coordinate.latitude),
            @"longitude" : @(location.coordinate.longitude),
        }, nil);
        return;
    }

    RNExifFetchAssetFileURL(asset, ^(NSURL *url, NSError *urlError) {
        if (!url) {
            completion(nil, urlError);
            return;
        }

        NSError *readError = nil;
        NSDictionary *latLong = [RNExifReader latLongForPath:url.absoluteString error:&readError];
        completion(latLong, latLong ? nil : readError);
    });
}

// --- leitura por caminho -------------------------------------------------

static void RNExifReadExif(NSString *path, RNExifResultBlock completion) {
    if (RNExifIsLocalPath(path)) {
        NSError *error = nil;
        NSDictionary *exifData = [RNExifReader exifDataForPath:path error:&error];
        completion(exifData, exifData ? nil : error);
        return;
    }

    RNExifFetchAsset(path, ^(PHAsset *asset, NSError *error) {
        if (!asset) {
            completion(nil, error);
            return;
        }
        RNExifReadExifForAsset(asset, path, completion);
    });
}

static void RNExifReadLatLong(NSString *path, RNExifResultBlock completion) {
    if (RNExifIsLocalPath(path)) {
        NSError *error = nil;
        NSDictionary *latLong = [RNExifReader latLongForPath:path error:&error];
        completion(latLong, latLong ? nil : error);
        return;
    }

    RNExifFetchAsset(path, ^(PHAsset *asset, NSError *error) {
        if (!asset) {
            completion(nil, error);
            return;
        }
        RNExifReadLatLongForAsset(asset, completion);
    });
}

static RNExifResultBlock RNExifPromiseBlock(RCTPromiseResolveBlock resolve,
                                            RCTPromiseRejectBlock reject) {
    return ^(NSDictionary *data, NSError *error) {
        if (!data) {
            reject(@"EXIF_ERROR", error.localizedDescription ?: @"Erro ao ler EXIF", error);
            return;
        }
        resolve(data);
    };
}

// --- lote ----------------------------------------------------------------

// Busca todos os assets ph:// numa unica consulta ao Photos. Chaves: o
// localIdentifier completo e o prefixo antes de "/" (ph://UUID sem /L0/001).
static NSDictionary<NSString *, PHAsset *> *RNExifFetchAssetsByIdentifier(NSArray<NSString *> *paths) {
    NSMutableArray<NSString *> *identifiers = [NSMutableArray array];
    for (NSString *path in paths) {
        if ([path hasPrefix:@"ph://"]) {
            [identifiers addObject:RNExifPhotoIdentifierFromPath(path)];
        }
    }
    if (identifiers.count == 0) {
        return @{};
    }

    NSMutableDictionary<NSString *, PHAsset *> *byIdentifier = [NSMutableDictionary dictionary];
    PHFetchResult<PHAsset *> *assets =
        [PHAsset fetchAssetsWithLocalIdentifiers:identifiers options:nil];
    for (PHAsset *asset in assets) {
        NSString *identifier = asset.localIdentifier;
        byIdentifier[identifier] = asset;
        NSString *prefix = [identifier componentsSeparatedByString:@"/"].firstObject;
        if (prefix.length > 0 && !byIdentifier[prefix]) {
            byIdentifier[prefix] = asset;
        }
    }
    return byIdentifier;
}

static void RNExifRunBatch(NSArray<NSString *> *paths,
                           BOOL readLatLong,
                           RCTPromiseResolveBlock resolve) {
    NSUInteger count = paths.count;
    if (count == 0) {
        resolve(@[]);
        return;
    }

    BOOL needsPhotoLibrary = NO;
    for (NSString *path in paths) {
        if (!RNExifIsLocalPath(path)) {
            needsPhotoLibrary = YES;
            break;
        }
    }

    void (^start)(BOOL, NSDictionary<NSString *, PHAsset *> *) =
        ^(BOOL photoAccessGranted, NSDictionary<NSString *, PHAsset *> *assets) {
          NSMutableArray *results = [NSMutableArray arrayWithCapacity:count];
          for (NSUInteger i = 0; i < count; i++) {
              [results addObject:[NSNull null]];
          }

          NSObject *lock = [NSObject new];
          dispatch_group_t group = dispatch_group_create();
          dispatch_semaphore_t slots = dispatch_semaphore_create(RNExifBatchConcurrency);
          // Fila serial que so distribui as tarefas; a espera pelo semaforo
          // acontece aqui, nunca nas filas que executam os callbacks.
          dispatch_queue_t dispatcher =
              dispatch_queue_create("com.pedro.reactnativeexif.batch", DISPATCH_QUEUE_SERIAL);

          dispatch_async(dispatcher, ^{
            [paths enumerateObjectsUsingBlock:^(NSString *path, NSUInteger index, BOOL *stop) {
              dispatch_semaphore_wait(slots, DISPATCH_TIME_FOREVER);
              dispatch_group_enter(group);

              RNExifResultBlock done = ^(NSDictionary *data, NSError *error) {
                NSDictionary *item = @{
                    @"path" : path ?: @"",
                    @"data" : data ?: (id)[NSNull null],
                    @"error" : data ? (id)[NSNull null]
                                    : (error.localizedDescription ?: @"Erro ao ler EXIF"),
                };
                @synchronized(lock) {
                    results[index] = item;
                }
                dispatch_semaphore_signal(slots);
                dispatch_group_leave(group);
              };

              dispatch_async(RNExifWorkQueue(), ^{
                if (RNExifIsLocalPath(path)) {
                    if (readLatLong) {
                        RNExifReadLatLong(path, done);
                    } else {
                        RNExifReadExif(path, done);
                    }
                    return;
                }

                if (!photoAccessGranted) {
                    done(nil, RNExifPhotoError(20, @"Permissao para fotos negada"));
                    return;
                }

                PHAsset *asset = [path hasPrefix:@"ph://"]
                                     ? assets[RNExifPhotoIdentifierFromPath(path)]
                                     : nil;
                if (asset) {
                    if (readLatLong) {
                        RNExifReadLatLongForAsset(asset, done);
                    } else {
                        RNExifReadExifForAsset(asset, path, done);
                    }
                    return;
                }

                // assets-library:// (legado) ou id nao encontrado na consulta em lote.
                if (readLatLong) {
                    RNExifReadLatLong(path, done);
                } else {
                    RNExifReadExif(path, done);
                }
              });
            }];

            dispatch_group_notify(group, RNExifWorkQueue(), ^{
              resolve(results);
            });
          });
        };

    if (!needsPhotoLibrary) {
        start(NO, @{});
        return;
    }

    // Permissao pedida uma unica vez para o lote inteiro.
    RNExifRequestPhotoAuthorization(^(BOOL granted) {
        dispatch_async(RNExifWorkQueue(), ^{
          start(granted, granted ? RNExifFetchAssetsByIdentifier(paths) : @{});
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
    RNExifReadExif(path, RNExifPromiseBlock(resolve, reject));
}
#else
- (void)getExif:(NSString *)path
        resolve:(RCTPromiseResolveBlock)resolve
         reject:(RCTPromiseRejectBlock)reject {
    RNExifReadExif(path, RNExifPromiseBlock(resolve, reject));
}
#endif

#if !RNEXIF_HAS_CODEGEN
RCT_REMAP_METHOD(getLatLong,
                 getLatLong:(NSString *)path
                 resolve:(RCTPromiseResolveBlock)resolve
                 reject:(RCTPromiseRejectBlock)reject)
{
    RNExifReadLatLong(path, RNExifPromiseBlock(resolve, reject));
}
#else
- (void)getLatLong:(NSString *)path
           resolve:(RCTPromiseResolveBlock)resolve
            reject:(RCTPromiseRejectBlock)reject {
    RNExifReadLatLong(path, RNExifPromiseBlock(resolve, reject));
}
#endif

#if !RNEXIF_HAS_CODEGEN
RCT_REMAP_METHOD(getExifBatch,
                 getExifBatch:(NSArray *)paths
                 resolve:(RCTPromiseResolveBlock)resolve
                 reject:(RCTPromiseRejectBlock)reject)
{
    RNExifRunBatch(paths, NO, resolve);
}
#else
- (void)getExifBatch:(NSArray *)paths
             resolve:(RCTPromiseResolveBlock)resolve
              reject:(RCTPromiseRejectBlock)reject {
    RNExifRunBatch(paths, NO, resolve);
}
#endif

#if !RNEXIF_HAS_CODEGEN
RCT_REMAP_METHOD(getLatLongBatch,
                 getLatLongBatch:(NSArray *)paths
                 resolve:(RCTPromiseResolveBlock)resolve
                 reject:(RCTPromiseRejectBlock)reject)
{
    RNExifRunBatch(paths, YES, resolve);
}
#else
- (void)getLatLongBatch:(NSArray *)paths
                resolve:(RCTPromiseResolveBlock)resolve
                 reject:(RCTPromiseRejectBlock)reject {
    RNExifRunBatch(paths, YES, resolve);
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
