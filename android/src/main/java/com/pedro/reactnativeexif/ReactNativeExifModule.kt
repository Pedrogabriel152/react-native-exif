package com.pedro.reactnativeexif

import com.facebook.react.bridge.ReactApplicationContext
import com.facebook.react.module.annotations.ReactModule
import com.facebook.react.bridge.*
import androidx.exifinterface.media.ExifInterface
import java.io.IOException



@ReactModule(name = ReactNativeExifModule.NAME)
class ReactNativeExifModule(reactContext: ReactApplicationContext) :
    NativeReactNativeExifSpec(reactContext) {

    override fun getName(): String {
        return NAME
    }

    @ReactMethod
    fun getExif(path: String, promise: Promise) {
        try {
            val exif = ExifInterface(path)

            val result = Arguments.createMap()
            result.putString("datetime", exif.getAttribute(ExifInterface.TAG_DATETIME))
            result.putString("make", exif.getAttribute(ExifInterface.TAG_MAKE))
            result.putString("model", exif.getAttribute(ExifInterface.TAG_MODEL))
            result.putString("orientation", exif.getAttribute(ExifInterface.TAG_ORIENTATION))
            result.putString("lat", exif.getAttribute(ExifInterface.TAG_GPS_LATITUDE))
            result.putString("lon", exif.getAttribute(ExifInterface.TAG_GPS_LONGITUDE))

            // helper que já converte lat/lon para double
            exif.latLong?.let {
                result.putDouble("latDecimal", it[0])
                result.putDouble("lonDecimal", it[1])
            }

            promise.resolve(result)

        } catch (e: IOException) {
            promise.reject("EXIF_ERROR", "Erro ao ler EXIF", e)
        }
    }

    // Example method
    // See https://reactnative.dev/docs/native-modules-android
    override fun multiply(a: Double, b: Double): Double {
        return a * b
    }

    companion object {
        const val NAME = "ReactNativeExif"
    }
}
