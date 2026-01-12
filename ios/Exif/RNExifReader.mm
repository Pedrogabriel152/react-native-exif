#import "RNExifReader.h"

#import <ImageIO/ImageIO.h>
#import <ImageIO/CGImageProperties.h>

static NSString *const RNExifReaderErrorDomain = @"ReactNativeExifError";

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

  return [value description];
}

static NSArray<NSString *> *RNExifTags(void) {
  static NSArray<NSString *> *tags;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    tags = @[
      @"DateTime",
      @"DateTimeDigitized",
      @"ExposureTime",
      @"Flash",
      @"FocalLength",
      @"GPSAltitude",
      @"GPSAltitudeRef",
      @"GPSDateStamp",
      @"GPSLatitude",
      @"GPSLatitudeRef",
      @"GPSLongitude",
      @"GPSLongitudeRef",
      @"GPSProcessingMethod",
      @"GPSTimeStamp",
      @"ImageLength",
      @"ImageWidth",
      @"Make",
      @"Model",
      @"Orientation",
      @"XResolution",
      @"YResolution",
      @"PhotometricInterpretation",
      @"SubSecTime",
      @"WhiteBalance",
      @"BitsPerSample",
      @"CompressedBitsPerPixel",
      @"ColorSpace",
      @"Software",
      @"YCbCrPositioning",
      @"ResolutionUnit",
      @"ExposureProgram",
      @"ExifVersion",
      @"ExposureBiasValue",
      @"MaxApertureValue",
      @"MeteringMode",
      @"InteroperabilityIndex",
      @"MakerNote",
      @"ShutterSpeedValue",
      @"Compression",
      @"SamplesPerPixel",
      @"PlanarConfiguration",
      @"ThumbnailImageLength",
      @"ThumbnailImageWidth",
      @"ThumbnailOrientation",
      @"DNGVersion",
      @"DefaultCropSize",
      @"ORFThumbnailImage",
      @"ORFPreviewImageStart",
      @"ORFPreviewImageLength",
      @"ORFAspectFrame",
      @"RW2SensorLeftBorder",
      @"RW2SensorRightBorder",
      @"RW2SensorTopBorder",
      @"RW2ISO",
      @"RW2JpgFromRaw",
      @"DateTimeOriginal",
    ];
  });

  return tags;
}

static id RNExifValueForTag(NSString *tag,
                            NSDictionary *properties,
                            NSDictionary *tiff,
                            NSDictionary *exif,
                            NSDictionary *gps) {
  if ([tag isEqualToString:@"DateTime"]) {
    return tiff[(NSString *)kCGImagePropertyTIFFDateTime];
  }
  if ([tag isEqualToString:@"DateTimeDigitized"]) {
    return exif[(NSString *)kCGImagePropertyExifDateTimeDigitized];
  }
  if ([tag isEqualToString:@"DateTimeOriginal"]) {
    return exif[(NSString *)kCGImagePropertyExifDateTimeOriginal];
  }
  if ([tag isEqualToString:@"ExposureTime"]) {
    return exif[(NSString *)kCGImagePropertyExifExposureTime];
  }
  if ([tag isEqualToString:@"Flash"]) {
    return exif[(NSString *)kCGImagePropertyExifFlash];
  }
  if ([tag isEqualToString:@"FocalLength"]) {
    return exif[(NSString *)kCGImagePropertyExifFocalLength];
  }
  if ([tag isEqualToString:@"GPSAltitude"]) {
    return gps[(NSString *)kCGImagePropertyGPSAltitude];
  }
  if ([tag isEqualToString:@"GPSAltitudeRef"]) {
    return gps[(NSString *)kCGImagePropertyGPSAltitudeRef];
  }
  if ([tag isEqualToString:@"GPSDateStamp"]) {
    return gps[(NSString *)kCGImagePropertyGPSDateStamp];
  }
  if ([tag isEqualToString:@"GPSLatitude"]) {
    return gps[(NSString *)kCGImagePropertyGPSLatitude];
  }
  if ([tag isEqualToString:@"GPSLatitudeRef"]) {
    return gps[(NSString *)kCGImagePropertyGPSLatitudeRef];
  }
  if ([tag isEqualToString:@"GPSLongitude"]) {
    return gps[(NSString *)kCGImagePropertyGPSLongitude];
  }
  if ([tag isEqualToString:@"GPSLongitudeRef"]) {
    return gps[(NSString *)kCGImagePropertyGPSLongitudeRef];
  }
  if ([tag isEqualToString:@"GPSProcessingMethod"]) {
    return gps[(NSString *)kCGImagePropertyGPSProcessingMethod];
  }
  if ([tag isEqualToString:@"GPSTimeStamp"]) {
    return gps[(NSString *)kCGImagePropertyGPSTimeStamp];
  }
  if ([tag isEqualToString:@"ImageLength"]) {
    return properties[(NSString *)kCGImagePropertyPixelHeight];
  }
  if ([tag isEqualToString:@"ImageWidth"]) {
    return properties[(NSString *)kCGImagePropertyPixelWidth];
  }
  if ([tag isEqualToString:@"Make"]) {
    return tiff[(NSString *)kCGImagePropertyTIFFMake];
  }
  if ([tag isEqualToString:@"Model"]) {
    return tiff[(NSString *)kCGImagePropertyTIFFModel];
  }
  if ([tag isEqualToString:@"Orientation"]) {
    return properties[(NSString *)kCGImagePropertyOrientation];
  }
  if ([tag isEqualToString:@"XResolution"]) {
    return tiff[(NSString *)kCGImagePropertyTIFFXResolution];
  }
  if ([tag isEqualToString:@"YResolution"]) {
    return tiff[(NSString *)kCGImagePropertyTIFFYResolution];
  }
  if ([tag isEqualToString:@"PhotometricInterpretation"]) {
    return tiff[(NSString *)kCGImagePropertyTIFFPhotometricInterpretation];
  }
  if ([tag isEqualToString:@"SubSecTime"]) {
    return exif[(NSString *)kCGImagePropertyExifSubsecTime];
  }
  if ([tag isEqualToString:@"WhiteBalance"]) {
    return exif[(NSString *)kCGImagePropertyExifWhiteBalance];
  }
  if ([tag isEqualToString:@"BitsPerSample"]) {
    #ifdef kCGImagePropertyTIFFBitsPerSample
      return tiff[(NSString *)kCGImagePropertyTIFFBitsPerSample];
    #else
      return tiff[@"BitsPerSample"];
    #endif
  }
  if ([tag isEqualToString:@"CompressedBitsPerPixel"]) {
    return exif[(NSString *)kCGImagePropertyExifCompressedBitsPerPixel];
  }
  if ([tag isEqualToString:@"ColorSpace"]) {
    return exif[(NSString *)kCGImagePropertyExifColorSpace];
  }
  if ([tag isEqualToString:@"Software"]) {
    return tiff[(NSString *)kCGImagePropertyTIFFSoftware];
  }
  if ([tag isEqualToString:@"YCbCrPositioning"]) {
    #ifdef kCGImagePropertyTIFFYCbCrPositioning
      return tiff[(NSString *)kCGImagePropertyTIFFYCbCrPositioning];
    #else
      return tiff[@"YCbCrPositioning"];
    #endif
  }
  if ([tag isEqualToString:@"ResolutionUnit"]) {
    return tiff[(NSString *)kCGImagePropertyTIFFResolutionUnit];
  }
  if ([tag isEqualToString:@"ExposureProgram"]) {
    return exif[(NSString *)kCGImagePropertyExifExposureProgram];
  }
  if ([tag isEqualToString:@"ExifVersion"]) {
    return exif[(NSString *)kCGImagePropertyExifVersion];
  }
  if ([tag isEqualToString:@"ExposureBiasValue"]) {
    return exif[(NSString *)kCGImagePropertyExifExposureBiasValue];
  }
  if ([tag isEqualToString:@"MaxApertureValue"]) {
    return exif[(NSString *)kCGImagePropertyExifMaxApertureValue];
  }
  if ([tag isEqualToString:@"MeteringMode"]) {
    return exif[(NSString *)kCGImagePropertyExifMeteringMode];
  }
  if ([tag isEqualToString:@"InteroperabilityIndex"]) {
    #ifdef kCGImagePropertyExifInteroperabilityIndex
      return exif[(NSString *)kCGImagePropertyExifInteroperabilityIndex];
    #else
      return exif[@"InteroperabilityIndex"];
    #endif
  }
  if ([tag isEqualToString:@"MakerNote"]) {
    return exif[(NSString *)kCGImagePropertyExifMakerNote];
  }
  if ([tag isEqualToString:@"ShutterSpeedValue"]) {
    return exif[(NSString *)kCGImagePropertyExifShutterSpeedValue];
  }
  if ([tag isEqualToString:@"Compression"]) {
    return tiff[(NSString *)kCGImagePropertyTIFFCompression];
  }
  if ([tag isEqualToString:@"SamplesPerPixel"]) {
    #ifdef kCGImagePropertyTIFFSamplesPerPixel
      return tiff[(NSString *)kCGImagePropertyTIFFSamplesPerPixel];
    #else
      return tiff[@"SamplesPerPixel"];
    #endif
  }
  if ([tag isEqualToString:@"PlanarConfiguration"]) {
    #ifdef kCGImagePropertyTIFFPlanarConfiguration
      return tiff[(NSString *)kCGImagePropertyTIFFPlanarConfiguration];
    #else
      return tiff[@"PlanarConfiguration"];
    #endif
  }
  if ([tag isEqualToString:@"ThumbnailImageLength"]) {
    #ifdef kCGImagePropertyTIFFThumbnailImageLength
      return tiff[(NSString *)kCGImagePropertyTIFFThumbnailImageLength];
    #else
      return tiff[@"ThumbnailImageLength"];
    #endif
  }
  if ([tag isEqualToString:@"ThumbnailImageWidth"]) {
    #ifdef kCGImagePropertyTIFFThumbnailImageWidth
      return tiff[(NSString *)kCGImagePropertyTIFFThumbnailImageWidth];
    #else
      return tiff[@"ThumbnailImageWidth"];
    #endif
  }
  if ([tag isEqualToString:@"ThumbnailOrientation"]) {
    #ifdef kCGImagePropertyTIFFThumbnailOrientation
      return tiff[(NSString *)kCGImagePropertyTIFFThumbnailOrientation];
    #else
      return tiff[@"ThumbnailOrientation"];
    #endif
  }
  if ([tag isEqualToString:@"DNGVersion"]) {
    #ifdef kCGImagePropertyExifDNGVersion
      return exif[(NSString *)kCGImagePropertyExifDNGVersion];
    #else
      return exif[@"DNGVersion"];
    #endif
  }
  if ([tag isEqualToString:@"DefaultCropSize"]) {
    #ifdef kCGImagePropertyExifDefaultCropSize
      return exif[(NSString *)kCGImagePropertyExifDefaultCropSize];
    #else
      return exif[@"DefaultCropSize"];
    #endif
  }

  return nil;
}

static NSDictionary *RNExifPropertiesForPath(NSString *path, NSError **error) {
  NSURL *url = RNExifURLForPath(path);
  if (!url) {
    if (error) {
      *error = [NSError errorWithDomain:RNExifReaderErrorDomain
                                   code:1
                               userInfo:@{NSLocalizedDescriptionKey : @"Caminho vazio"}];
    }
    return nil;
  }

  CGImageSourceRef source =
      CGImageSourceCreateWithURL((__bridge CFURLRef)url, NULL);
  if (!source) {
    if (error) {
      *error = [NSError errorWithDomain:RNExifReaderErrorDomain
                                   code:2
                               userInfo:@{NSLocalizedDescriptionKey : @"Nao foi possivel abrir a imagem"}];
    }
    return nil;
  }

  CFDictionaryRef properties =
      CGImageSourceCopyPropertiesAtIndex(source, 0, NULL);
  CFRelease(source);

  if (!properties) {
    if (error) {
      *error = [NSError errorWithDomain:RNExifReaderErrorDomain
                                   code:3
                               userInfo:@{NSLocalizedDescriptionKey : @"Nao foi possivel ler as propriedades"}];
    }
    return nil;
  }

  NSDictionary *result = [(__bridge NSDictionary *)properties copy];
  CFRelease(properties);
  return result;
}

static NSDictionary *RNExifPropertiesForData(NSData *data, NSError **error) {
  if (!data || data.length == 0) {
    if (error) {
      *error = [NSError errorWithDomain:RNExifReaderErrorDomain
                                   code:4
                               userInfo:@{NSLocalizedDescriptionKey : @"Dados de imagem vazios"}];
    }
    return nil;
  }

  CGImageSourceRef source =
      CGImageSourceCreateWithData((__bridge CFDataRef)data, NULL);
  if (!source) {
    if (error) {
      *error = [NSError errorWithDomain:RNExifReaderErrorDomain
                                   code:5
                               userInfo:@{NSLocalizedDescriptionKey : @"Nao foi possivel abrir os dados da imagem"}];
    }
    return nil;
  }

  CFDictionaryRef properties =
      CGImageSourceCopyPropertiesAtIndex(source, 0, NULL);
  CFRelease(source);

  if (!properties) {
    if (error) {
      *error = [NSError errorWithDomain:RNExifReaderErrorDomain
                                   code:6
                               userInfo:@{NSLocalizedDescriptionKey : @"Nao foi possivel ler as propriedades"}];
    }
    return nil;
  }

  NSDictionary *result = [(__bridge NSDictionary *)properties copy];
  CFRelease(properties);
  return result;
}

@implementation RNExifReader

+ (NSDictionary<NSString *, id> *)exifDataForPath:(NSString *)path
                                            error:(NSError **)error {
  NSDictionary *properties = RNExifPropertiesForPath(path, error);
  if (!properties) {
    return nil;
  }

  NSDictionary *tiff = properties[(NSString *)kCGImagePropertyTIFFDictionary];
  NSDictionary *exif = properties[(NSString *)kCGImagePropertyExifDictionary];
  NSDictionary *gps = properties[(NSString *)kCGImagePropertyGPSDictionary];

  NSMutableDictionary<NSString *, id> *result =
      [NSMutableDictionary dictionaryWithCapacity:RNExifTags().count + 1];

  for (NSString *tag in RNExifTags()) {
    id value = RNExifValueForTag(tag, properties, tiff, exif, gps);
    NSString *stringValue = RNExifStringValue(value);
    result[tag] = stringValue ?: [NSNull null];
  }

  result[@"originalUri"] = path ?: @"";
  return result;
}

+ (NSDictionary<NSString *, NSNumber *> *)latLongForPath:(NSString *)path
                                                   error:(NSError **)error {
  NSDictionary *properties = RNExifPropertiesForPath(path, error);
  if (!properties) {
    return nil;
  }

  NSDictionary *gps = properties[(NSString *)kCGImagePropertyGPSDictionary];
  NSNumber *latitudeNumber = gps[(NSString *)kCGImagePropertyGPSLatitude];
  NSNumber *longitudeNumber = gps[(NSString *)kCGImagePropertyGPSLongitude];
  NSString *latitudeRef = gps[(NSString *)kCGImagePropertyGPSLatitudeRef];
  NSString *longitudeRef = gps[(NSString *)kCGImagePropertyGPSLongitudeRef];

  double latitude = latitudeNumber ? [latitudeNumber doubleValue] : 0.0;
  double longitude = longitudeNumber ? [longitudeNumber doubleValue] : 0.0;

  if ([latitudeRef isKindOfClass:[NSString class]] &&
      [[latitudeRef uppercaseString] isEqualToString:@"S"]) {
    latitude = -latitude;
  }
  if ([longitudeRef isKindOfClass:[NSString class]] &&
      [[longitudeRef uppercaseString] isEqualToString:@"W"]) {
    longitude = -longitude;
  }

  return @{
    @"latitude" : @(latitude),
    @"longitude" : @(longitude),
  };
}

+ (NSDictionary<NSString *, id> *)exifDataForImageData:(NSData *)data
                                                 error:(NSError **)error {
  NSDictionary *properties = RNExifPropertiesForData(data, error);
  if (!properties) {
    return nil;
  }

  NSDictionary *tiff = properties[(NSString *)kCGImagePropertyTIFFDictionary];
  NSDictionary *exif = properties[(NSString *)kCGImagePropertyExifDictionary];
  NSDictionary *gps = properties[(NSString *)kCGImagePropertyGPSDictionary];

  NSMutableDictionary<NSString *, id> *result =
      [NSMutableDictionary dictionaryWithCapacity:RNExifTags().count + 1];

  for (NSString *tag in RNExifTags()) {
    id value = RNExifValueForTag(tag, properties, tiff, exif, gps);
    NSString *stringValue = RNExifStringValue(value);
    result[tag] = stringValue ?: [NSNull null];
  }

  return result;
}

+ (NSDictionary<NSString *, NSNumber *> *)latLongForImageData:(NSData *)data
                                                        error:(NSError **)error {
  NSDictionary *properties = RNExifPropertiesForData(data, error);
  if (!properties) {
    return nil;
  }

  NSDictionary *gps = properties[(NSString *)kCGImagePropertyGPSDictionary];
  NSNumber *latitudeNumber = gps[(NSString *)kCGImagePropertyGPSLatitude];
  NSNumber *longitudeNumber = gps[(NSString *)kCGImagePropertyGPSLongitude];
  NSString *latitudeRef = gps[(NSString *)kCGImagePropertyGPSLatitudeRef];
  NSString *longitudeRef = gps[(NSString *)kCGImagePropertyGPSLongitudeRef];

  double latitude = latitudeNumber ? [latitudeNumber doubleValue] : 0.0;
  double longitude = longitudeNumber ? [longitudeNumber doubleValue] : 0.0;

  if ([latitudeRef isKindOfClass:[NSString class]] &&
      [[latitudeRef uppercaseString] isEqualToString:@"S"]) {
    latitude = -latitude;
  }
  if ([longitudeRef isKindOfClass:[NSString class]] &&
      [[longitudeRef uppercaseString] isEqualToString:@"W"]) {
    longitude = -longitude;
  }

  return @{
    @"latitude" : @(latitude),
    @"longitude" : @(longitude),
  };
}

@end
