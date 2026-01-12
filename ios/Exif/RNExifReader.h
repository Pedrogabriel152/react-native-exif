#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface RNExifReader : NSObject

+ (nullable NSDictionary<NSString *, id> *)exifDataForPath:(NSString *)path
                                                     error:(NSError **)error;
+ (nullable NSDictionary<NSString *, NSNumber *> *)latLongForPath:(NSString *)path
                                                            error:(NSError **)error;
+ (nullable NSDictionary<NSString *, id> *)exifDataForImageData:(NSData *)data
                                                         error:(NSError **)error;
+ (nullable NSDictionary<NSString *, NSNumber *> *)latLongForImageData:(NSData *)data
                                                                error:(NSError **)error;

@end

NS_ASSUME_NONNULL_END
