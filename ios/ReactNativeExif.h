#import <React/RCTBridgeModule.h>

#if __has_include(<ReactNativeExifSpec/ReactNativeExifSpec.h>)
#import <ReactNativeExifSpec/ReactNativeExifSpec.h>
#define RNEXIF_HAS_CODEGEN 1
#else
#define RNEXIF_HAS_CODEGEN 0
#endif

#if RNEXIF_HAS_CODEGEN
@interface ReactNativeExif : NSObject <NativeReactNativeExifSpec>
#else
@interface ReactNativeExif : NSObject <RCTBridgeModule>
#endif

- (NSNumber *)multiply:(double)a b:(double)b;
- (void)getExif:(NSString *)path
        resolve:(RCTPromiseResolveBlock)resolve
         reject:(RCTPromiseRejectBlock)reject;
- (void)getLatLong:(NSString *)path
           resolve:(RCTPromiseResolveBlock)resolve
            reject:(RCTPromiseRejectBlock)reject;

@end
