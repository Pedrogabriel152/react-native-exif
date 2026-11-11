#import "RNExifReader.h"

#import <ImageIO/ImageIO.h>
#import <ImageIO/CGImageProperties.h>

static NSString *const RNExifReaderErrorDomain = @"ReactNativeExifError";

typedef NS_ENUM(NSInteger, RNExifSource) {
  RNExifSourceRoot,
  RNExifSourceTIFF,
  RNExifSourceExif,
  RNExifSourceGPS,
};

// Mapeamento tag -> (dicionário de origem, chave no ImageIO). Montado uma vez;
// a ordem do array define a ordem das chaves no resultado.
// __unsafe_unretained: todas as strings são literais/constantes do ImageIO
// (vida estática), e o struct é copiado por bytes para dentro de NSValue.
typedef struct {
  __unsafe_unretained NSString *tag;
  RNExifSource source;
  __unsafe_unretained NSString *key;
} RNExifTagEntry;

static NSDictionary *RNExifShouldNotCacheOptions(void) {
  static NSDictionary *options;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    options = @{(NSString *)kCGImageSourceShouldCache : @NO};
  });
  return options;
}

static NSURL *RNExifURLForPath(NSString *path) {
  if (path.length == 0) {
    return nil;
  }

  NSURL *url = [NSURL URLWithString:path];
  if (url && url.scheme.length > 0) {
    return url;
  }

  return [NSURL fileURLWithPath:path];
}

static NSString *RNExifStringValue(id value) {
  if (!value || value == [NSNull null]) {
    return nil;
  }

  if ([value isKindOfClass:[NSString class]]) {
    return (NSString *)value;
  }

  if ([value isKindOfClass:[NSNumber class]]) {
    return [(NSNumber *)value stringValue];
  }

  if ([value isKindOfClass:[NSData class]]) {
    // Blobs binários não são serializados (evita strings enormes na ponte).
    return nil;
  }

  return [value description];
}

static NSError *RNExifError(NSInteger code, NSString *message) {
  return [NSError errorWithDomain:RNExifReaderErrorDomain
                             code:code
                         userInfo:@{NSLocalizedDescriptionKey : message}];
}

static NSDictionary *RNExifPropertiesForSource(CGImageSourceRef source,
                                               NSInteger errorCode,
                                               NSError **error) {
  CFDictionaryRef properties = CGImageSourceCopyPropertiesAtIndex(
      source, 0, (__bridge CFDictionaryRef)RNExifShouldNotCacheOptions());
  CFRelease(source);

  if (!properties) {
    if (error) {
      *error = RNExifError(errorCode, @"Nao foi possivel ler as propriedades");
    }
    return nil;
  }

  return (__bridge_transfer NSDictionary *)properties;
}

static NSDictionary *RNExifPropertiesForPath(NSString *path, NSError **error) {
  NSURL *url = RNExifURLForPath(path);
  if (!url) {
    if (error) {
      *error = RNExifError(1, @"Caminho vazio");
    }
    return nil;
  }

  CGImageSourceRef source = CGImageSourceCreateWithURL(
      (__bridge CFURLRef)url, (__bridge CFDictionaryRef)RNExifShouldNotCacheOptions());
  if (!source) {
    if (error) {
      *error = RNExifError(2, @"Nao foi possivel abrir a imagem");
    }
    return nil;
  }

  return RNExifPropertiesForSource(source, 3, error);
}

static NSDictionary *RNExifPropertiesForData(NSData *data, NSError **error) {
  if (!data || data.length == 0) {
    if (error) {
      *error = RNExifError(4, @"Dados de imagem vazios");
    }
    return nil;
  }

  CGImageSourceRef source = CGImageSourceCreateWithData(
      (__bridge CFDataRef)data, (__bridge CFDictionaryRef)RNExifShouldNotCacheOptions());
  if (!source) {
    if (error) {
      *error = RNExifError(5, @"Nao foi possivel abrir os dados da imagem");
    }
    return nil;
  }

  return RNExifPropertiesForSource(source, 6, error);
}

static NSArray<NSValue *> *RNExifTagTable(void) {
  static NSArray<NSValue *> *table;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    RNExifTagEntry entries[] = {
      {@"DateTime", RNExifSourceTIFF, (NSString *)kCGImagePropertyTIFFDateTime},
      {@"DateTimeDigitized", RNExifSourceExif, (NSString *)kCGImagePropertyExifDateTimeDigitized},
      {@"ExposureTime", RNExifSourceExif, (NSString *)kCGImagePropertyExifExposureTime},
      {@"Flash", RNExifSourceExif, (NSString *)kCGImagePropertyExifFlash},
      {@"FocalLength", RNExifSourceExif, (NSString *)kCGImagePropertyExifFocalLength},
      {@"GPSAltitude", RNExifSourceGPS, (NSString *)kCGImagePropertyGPSAltitude},
      {@"GPSAltitudeRef", RNExifSourceGPS, (NSString *)kCGImagePropertyGPSAltitudeRef},
      {@"GPSDateStamp", RNExifSourceGPS, (NSString *)kCGImagePropertyGPSDateStamp},
      {@"GPSLatitude", RNExifSourceGPS, (NSString *)kCGImagePropertyGPSLatitude},
      {@"GPSLatitudeRef", RNExifSourceGPS, (NSString *)kCGImagePropertyGPSLatitudeRef},
      {@"GPSLongitude", RNExifSourceGPS, (NSString *)kCGImagePropertyGPSLongitude},
      {@"GPSLongitudeRef", RNExifSourceGPS, (NSString *)kCGImagePropertyGPSLongitudeRef},
      {@"GPSProcessingMethod", RNExifSourceGPS, (NSString *)kCGImagePropertyGPSProcessingMethod},
      {@"GPSTimeStamp", RNExifSourceGPS, (NSString *)kCGImagePropertyGPSTimeStamp},
      {@"ImageLength", RNExifSourceRoot, (NSString *)kCGImagePropertyPixelHeight},
      {@"ImageWidth", RNExifSourceRoot, (NSString *)kCGImagePropertyPixelWidth},
      {@"Make", RNExifSourceTIFF, (NSString *)kCGImagePropertyTIFFMake},
      {@"Model", RNExifSourceTIFF, (NSString *)kCGImagePropertyTIFFModel},
      {@"Orientation", RNExifSourceRoot, (NSString *)kCGImagePropertyOrientation},
      {@"XResolution", RNExifSourceTIFF, (NSString *)kCGImagePropertyTIFFXResolution},
      {@"YResolution", RNExifSourceTIFF, (NSString *)kCGImagePropertyTIFFYResolution},
      {@"PhotometricInterpretation", RNExifSourceTIFF, (NSString *)kCGImagePropertyTIFFPhotometricInterpretation},
      {@"SubSecTime", RNExifSourceExif, (NSString *)kCGImagePropertyExifSubsecTime},
      {@"WhiteBalance", RNExifSourceExif, (NSString *)kCGImagePropertyExifWhiteBalance},
      {@"BitsPerSample", RNExifSourceTIFF, @"BitsPerSample"},
      {@"CompressedBitsPerPixel", RNExifSourceExif, (NSString *)kCGImagePropertyExifCompressedBitsPerPixel},
      {@"ColorSpace", RNExifSourceExif, (NSString *)kCGImagePropertyExifColorSpace},
      {@"Software", RNExifSourceTIFF, (NSString *)kCGImagePropertyTIFFSoftware},
      {@"YCbCrPositioning", RNExifSourceTIFF, @"YCbCrPositioning"},
      {@"ResolutionUnit", RNExifSourceTIFF, (NSString *)kCGImagePropertyTIFFResolutionUnit},
      {@"ExposureProgram", RNExifSourceExif, (NSString *)kCGImagePropertyExifExposureProgram},
      {@"ExifVersion", RNExifSourceExif, (NSString *)kCGImagePropertyExifVersion},
      {@"ExposureBiasValue", RNExifSourceExif, (NSString *)kCGImagePropertyExifExposureBiasValue},
      {@"MaxApertureValue", RNExifSourceExif, (NSString *)kCGImagePropertyExifMaxApertureValue},
      {@"MeteringMode", RNExifSourceExif, (NSString *)kCGImagePropertyExifMeteringMode},
      {@"InteroperabilityIndex", RNExifSourceExif, @"InteroperabilityIndex"},
      {@"ShutterSpeedValue", RNExifSourceExif, (NSString *)kCGImagePropertyExifShutterSpeedValue},
      {@"Compression", RNExifSourceTIFF, (NSString *)kCGImagePropertyTIFFCompression},
      {@"SamplesPerPixel", RNExifSourceTIFF, @"SamplesPerPixel"},
      {@"PlanarConfiguration", RNExifSourceTIFF, @"PlanarConfiguration"},
      {@"ThumbnailImageLength", RNExifSourceTIFF, @"ThumbnailImageLength"},
      {@"ThumbnailImageWidth", RNExifSourceTIFF, @"ThumbnailImageWidth"},
      {@"ThumbnailOrientation", RNExifSourceTIFF, @"ThumbnailOrientation"},
      {@"DNGVersion", RNExifSourceExif, @"DNGVersion"},
      {@"DefaultCropSize", RNExifSourceExif, @"DefaultCropSize"},
      // Sem fonte equivalente no ImageIO: mantidas como null para paridade de chaves.
      {@"ORFPreviewImageStart", RNExifSourceRoot, nil},
      {@"ORFPreviewImageLength", RNExifSourceRoot, nil},
      {@"ORFAspectFrame", RNExifSourceRoot, nil},
      {@"RW2SensorLeftBorder", RNExifSourceRoot, nil},
      {@"RW2SensorRightBorder", RNExifSourceRoot, nil},
      {@"RW2SensorTopBorder", RNExifSourceRoot, nil},
      {@"RW2ISO", RNExifSourceRoot, nil},
      {@"DateTimeOriginal", RNExifSourceExif, (NSString *)kCGImagePropertyExifDateTimeOriginal},
    };

    size_t count = sizeof(entries) / sizeof(entries[0]);
    NSMutableArray<NSValue *> *values = [NSMutableArray arrayWithCapacity:count];
    for (size_t i = 0; i < count; i++) {
      [values addObject:[NSValue valueWithBytes:&entries[i] objCType:@encode(RNExifTagEntry)]];
    }
    table = [values copy];
  });
  return table;
}

static NSMutableDictionary<NSString *, id> *RNExifDataFromProperties(NSDictionary *properties) {
  NSDictionary *sources[4] = {
    properties,
    properties[(NSString *)kCGImagePropertyTIFFDictionary],
    properties[(NSString *)kCGImagePropertyExifDictionary],
    properties[(NSString *)kCGImagePropertyGPSDictionary],
  };

  NSArray<NSValue *> *table = RNExifTagTable();
  NSMutableDictionary<NSString *, id> *result =
      [NSMutableDictionary dictionaryWithCapacity:table.count + 1];

  for (NSValue *value in table) {
    RNExifTagEntry entry;
    [value getValue:&entry];
    id raw = entry.key ? sources[entry.source][entry.key] : nil;
    result[entry.tag] = RNExifStringValue(raw) ?: [NSNull null];
  }

  return result;
}

static NSDictionary<NSString *, NSNumber *> *RNExifLatLongFromProperties(NSDictionary *properties) {
  NSDictionary *gps = properties[(NSString *)kCGImagePropertyGPSDictionary];
  NSNumber *latitudeNumber = gps[(NSString *)kCGImagePropertyGPSLatitude];
  NSNumber *longitudeNumber = gps[(NSString *)kCGImagePropertyGPSLongitude];
  NSString *latitudeRef = gps[(NSString *)kCGImagePropertyGPSLatitudeRef];
  NSString *longitudeRef = gps[(NSString *)kCGImagePropertyGPSLongitudeRef];

  double latitude = latitudeNumber ? [latitudeNumber doubleValue] : 0.0;
  double longitude = longitudeNumber ? [longitudeNumber doubleValue] : 0.0;

  if ([latitudeRef isKindOfClass:[NSString class]] &&
      [latitudeRef caseInsensitiveCompare:@"S"] == NSOrderedSame) {
    latitude = -latitude;
  }
  if ([longitudeRef isKindOfClass:[NSString class]] &&
      [longitudeRef caseInsensitiveCompare:@"W"] == NSOrderedSame) {
    longitude = -longitude;
  }

  return @{
    @"latitude" : @(latitude),
    @"longitude" : @(longitude),
  };
}

@implementation RNExifReader

+ (NSDictionary<NSString *, id> *)exifDataForPath:(NSString *)path
                                            error:(NSError **)error {
  NSDictionary *properties = RNExifPropertiesForPath(path, error);
  if (!properties) {
    return nil;
  }

  NSMutableDictionary<NSString *, id> *result = RNExifDataFromProperties(properties);
  result[@"originalUri"] = path ?: @"";
  return result;
}

+ (NSDictionary<NSString *, NSNumber *> *)latLongForPath:(NSString *)path
                                                   error:(NSError **)error {
  NSDictionary *properties = RNExifPropertiesForPath(path, error);
  return properties ? RNExifLatLongFromProperties(properties) : nil;
}

+ (NSDictionary<NSString *, id> *)exifDataForImageData:(NSData *)data
                                                 error:(NSError **)error {
  NSDictionary *properties = RNExifPropertiesForData(data, error);
  return properties ? RNExifDataFromProperties(properties) : nil;
}

+ (NSDictionary<NSString *, NSNumber *> *)latLongForImageData:(NSData *)data
                                                        error:(NSError **)error {
  NSDictionary *properties = RNExifPropertiesForData(data, error);
  return properties ? RNExifLatLongFromProperties(properties) : nil;
}

@end
