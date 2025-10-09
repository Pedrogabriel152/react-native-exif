package com.pedro.reactnativeexif


import com.facebook.react.bridge.ReactApplicationContext
import com.facebook.react.module.annotations.ReactModule
import com.facebook.react.bridge.*
import androidx.exifinterface.media.ExifInterface
import android.net.Uri;
import java.io.IOException
import android.util.Log
import java.io.FileInputStream
import java.io.InputStream
import com.pedro.reactnativeexif.utils.RealPathUtil
import java.io.File

@ReactModule(name = ReactNativeExifModule.NAME)
class ReactNativeExifModule(reactContext: ReactApplicationContext) :
    NativeReactNativeExifSpec(reactContext) {

    override fun getName(): String {
        return NAME
    }

    companion object {
        const val NAME = "ReactNativeExif"
        private val EXIF_ATTRIBUTES = arrayOf(
            ExifInterface.TAG_DATETIME,
            ExifInterface.TAG_DATETIME_DIGITIZED,
            ExifInterface.TAG_EXPOSURE_TIME,
            ExifInterface.TAG_FLASH,
            ExifInterface.TAG_FOCAL_LENGTH,
            ExifInterface.TAG_GPS_ALTITUDE,
            ExifInterface.TAG_GPS_ALTITUDE_REF,
            ExifInterface.TAG_GPS_DATESTAMP,
            ExifInterface.TAG_GPS_LATITUDE,
            ExifInterface.TAG_GPS_LATITUDE_REF,
            ExifInterface.TAG_GPS_LONGITUDE,
            ExifInterface.TAG_GPS_LONGITUDE_REF,
            ExifInterface.TAG_GPS_PROCESSING_METHOD,
            ExifInterface.TAG_GPS_TIMESTAMP,
            ExifInterface.TAG_IMAGE_LENGTH,
            ExifInterface.TAG_IMAGE_WIDTH,
            ExifInterface.TAG_MAKE,
            ExifInterface.TAG_MODEL,
            ExifInterface.TAG_ORIENTATION,
            ExifInterface.TAG_X_RESOLUTION,
            ExifInterface.TAG_Y_RESOLUTION,
            ExifInterface.TAG_PHOTOMETRIC_INTERPRETATION,
            ExifInterface.TAG_SUBSEC_TIME,
            ExifInterface.TAG_WHITE_BALANCE,
            ExifInterface.TAG_BITS_PER_SAMPLE,
            ExifInterface.TAG_COMPRESSED_BITS_PER_PIXEL,
            ExifInterface.TAG_COLOR_SPACE,
            ExifInterface.TAG_FLASH,
            ExifInterface.TAG_SOFTWARE,
            ExifInterface.TAG_Y_CB_CR_POSITIONING,
            ExifInterface.TAG_RESOLUTION_UNIT,
            ExifInterface.TAG_EXPOSURE_PROGRAM,
            ExifInterface.TAG_EXIF_VERSION,
            ExifInterface.TAG_EXPOSURE_BIAS_VALUE,
            ExifInterface.TAG_MAX_APERTURE_VALUE,
            ExifInterface.TAG_METERING_MODE,
            ExifInterface.TAG_INTEROPERABILITY_INDEX,
            ExifInterface.TAG_MAKER_NOTE,
            ExifInterface.TAG_BITS_PER_SAMPLE,
            ExifInterface.TAG_SHUTTER_SPEED_VALUE,
            ExifInterface.TAG_COMPRESSION,
            ExifInterface.TAG_SAMPLES_PER_PIXEL,
            ExifInterface.TAG_PLANAR_CONFIGURATION,
            ExifInterface.TAG_THUMBNAIL_IMAGE_LENGTH,
            ExifInterface.TAG_THUMBNAIL_IMAGE_WIDTH,
            ExifInterface.TAG_THUMBNAIL_ORIENTATION,
            ExifInterface.TAG_DNG_VERSION,
            ExifInterface.TAG_DEFAULT_CROP_SIZE,
            ExifInterface.TAG_ORF_THUMBNAIL_IMAGE,
            ExifInterface.TAG_ORF_PREVIEW_IMAGE_START,
            ExifInterface.TAG_ORF_PREVIEW_IMAGE_LENGTH,
            ExifInterface.TAG_ORF_ASPECT_FRAME,
            ExifInterface.TAG_RW2_SENSOR_LEFT_BORDER,
            ExifInterface.TAG_RW2_SENSOR_RIGHT_BORDER,
            ExifInterface.TAG_RW2_SENSOR_TOP_BORDER,
            ExifInterface.TAG_RW2_ISO,
            ExifInterface.TAG_RW2_JPG_FROM_RAW,
            ExifInterface.TAG_ORF_ASPECT_FRAME,
            ExifInterface.TAG_ORF_ASPECT_FRAME,
            ExifInterface.TAG_ORF_ASPECT_FRAME,
            ExifInterface.TAG_ORF_ASPECT_FRAME,
            ExifInterface.TAG_DATETIME_ORIGINAL
        )
    }

    @ReactMethod
    override fun getExif(uri: String, promise: Promise) {
        try {
            val exif = createExifInterface(uri)
            val exifMap = Arguments.createMap()

            for (attribute in EXIF_ATTRIBUTES) {
                val value = exif.getAttribute(attribute)
                exifMap.putString(attribute, value)
            }

            exifMap.putString("originalUri", uri)
            promise.resolve(exifMap)
        } catch (e: Exception) {
            promise.reject("EXIF_ERROR", e.message, e)
        }
    }

    @ReactMethod
    override fun getLatLong(path: String, promise: Promise) {
        try {
            val exif = createExifInterface(path);
            val result = Arguments.createMap()
            val latLong = exif.getLatLong()
            if(latLong != null) {
                latLong?.let {
                    result.putDouble("latitude", it[0])
                    result.putDouble("longitude", it[1])
                }
            }else {
                result.putDouble("latitude", 0.0)
                result.putDouble("longitude", 0.0)
            }

            promise.resolve(result)
        } catch (e: IOException) {
            promise.reject("EXIF_ERROR", "Erro ao ler EXIF", e)
        }
    }

    override fun multiply(a: Double, b: Double): Double {
        return a * b
    }

    @Throws(IOException::class)
    private fun createExifInterface(uriString: String): ExifInterface {
        val context = reactApplicationContext
        val uri = Uri.parse(uriString)
        val inputStream = when (uri.scheme) {
            "content" -> context.contentResolver.openInputStream(uri)
            "file" -> FileInputStream(File(uri.path!!))
            else -> FileInputStream(File(uriString))
        } ?: throw IOException("Não foi possível abrir InputStream para: $uriString")

        return ExifInterface(inputStream)
    }
}
