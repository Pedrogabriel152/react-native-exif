package com.pedro.reactnativeexif

import android.content.ContentResolver
import android.net.Uri
import androidx.exifinterface.media.ExifInterface
import java.io.IOException

/**
 * Leitura de EXIF sem dependência do React Native, para poder ser testada na JVM.
 */
class ExifReader(private val contentResolver: ContentResolver) {

    companion object {
        // Sem duplicatas e sem tags binárias grandes (MakerNote, thumbnails/JPEG
        // embutidos de RAW), que virariam strings enormes atravessando a ponte.
        val EXIF_ATTRIBUTES: Array<String> = arrayOf(
            ExifInterface.TAG_DATETIME,
            ExifInterface.TAG_DATETIME_DIGITIZED,
            ExifInterface.TAG_DATETIME_ORIGINAL,
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
            ExifInterface.TAG_SOFTWARE,
            ExifInterface.TAG_Y_CB_CR_POSITIONING,
            ExifInterface.TAG_RESOLUTION_UNIT,
            ExifInterface.TAG_EXPOSURE_PROGRAM,
            ExifInterface.TAG_EXIF_VERSION,
            ExifInterface.TAG_EXPOSURE_BIAS_VALUE,
            ExifInterface.TAG_MAX_APERTURE_VALUE,
            ExifInterface.TAG_METERING_MODE,
            ExifInterface.TAG_INTEROPERABILITY_INDEX,
            ExifInterface.TAG_SHUTTER_SPEED_VALUE,
            ExifInterface.TAG_COMPRESSION,
            ExifInterface.TAG_SAMPLES_PER_PIXEL,
            ExifInterface.TAG_PLANAR_CONFIGURATION,
            ExifInterface.TAG_THUMBNAIL_IMAGE_LENGTH,
            ExifInterface.TAG_THUMBNAIL_IMAGE_WIDTH,
            ExifInterface.TAG_THUMBNAIL_ORIENTATION,
            ExifInterface.TAG_DNG_VERSION,
            ExifInterface.TAG_DEFAULT_CROP_SIZE,
            ExifInterface.TAG_ORF_PREVIEW_IMAGE_START,
            ExifInterface.TAG_ORF_PREVIEW_IMAGE_LENGTH,
            ExifInterface.TAG_ORF_ASPECT_FRAME,
            ExifInterface.TAG_RW2_SENSOR_LEFT_BORDER,
            ExifInterface.TAG_RW2_SENSOR_RIGHT_BORDER,
            ExifInterface.TAG_RW2_SENSOR_TOP_BORDER,
            ExifInterface.TAG_RW2_ISO
        )
    }

    /** Mapa tag -> valor (null quando a tag não existe), na ordem de [EXIF_ATTRIBUTES]. */
    @Throws(IOException::class)
    fun readExif(uri: String): LinkedHashMap<String, String?> = withExif(uri) { exif ->
        val result = LinkedHashMap<String, String?>(EXIF_ATTRIBUTES.size)
        for (attribute in EXIF_ATTRIBUTES) {
            result[attribute] = exif.getAttribute(attribute)
        }
        result
    }

    /** `[latitude, longitude]` com sinal (S/W negativos), ou null sem GPS. */
    @Throws(IOException::class)
    fun readLatLong(uri: String): DoubleArray? = withExif(uri) { it.latLong }

    /**
     * Abre o arquivo e garante o fechamento do recurso ao final.
     *
     * Caminhos locais usam o construtor por path (seekable). Em `content://`,
     * providers baseados em arquivo devolvem um FileInputStream, no qual o
     * ExifInterface faz skip via seek e lê só os blocos de metadados; providers
     * baseados em pipe também funcionam.
     */
    @Throws(IOException::class)
    private fun <T> withExif(uriString: String, block: (ExifInterface) -> T): T {
        val uri = Uri.parse(uriString)
        return when (uri.scheme) {
            "content" -> {
                val stream = contentResolver.openInputStream(uri)
                    ?: throw IOException("Não foi possível abrir o arquivo: $uriString")
                stream.use { block(ExifInterface(it)) }
            }
            "file" -> block(
                ExifInterface(uri.path ?: throw IOException("Caminho inválido: $uriString"))
            )
            else -> block(ExifInterface(uriString))
        }
    }
}
