package com.pedro.reactnativeexif

import android.content.ContentResolver
import android.net.Uri
import androidx.exifinterface.media.ExifInterface
import java.io.IOException
import java.util.concurrent.Executor
import java.util.concurrent.atomic.AtomicInteger

/** Resultado de um item de lote: `data` em caso de sucesso, `error` caso contrário. */
data class BatchResult<T>(val path: String, val data: T?, val error: String?)

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

    /** Lê várias imagens em paralelo no [executor]; [onComplete] recebe os itens na ordem de [paths]. */
    fun readExifBatch(
        paths: List<String>,
        executor: Executor,
        onComplete: (List<BatchResult<LinkedHashMap<String, String?>>>) -> Unit
    ) = runBatch(paths, executor, ::readExif, onComplete)

    /** Igual a [readExifBatch], para coordenadas (`data` null quando a imagem não tem GPS). */
    fun readLatLongBatch(
        paths: List<String>,
        executor: Executor,
        onComplete: (List<BatchResult<DoubleArray?>>) -> Unit
    ) = runBatch(paths, executor, ::readLatLong, onComplete)

    /**
     * Cada path vira uma tarefa independente; o último a terminar entrega o
     * resultado. Não bloqueia nenhuma thread do pool esperando as outras.
     */
    private fun <T> runBatch(
        paths: List<String>,
        executor: Executor,
        read: (String) -> T,
        onComplete: (List<BatchResult<T>>) -> Unit
    ) {
        if (paths.isEmpty()) {
            onComplete(emptyList())
            return
        }

        val results = arrayOfNulls<BatchResult<T>>(paths.size)
        val remaining = AtomicInteger(paths.size)

        fun finish(index: Int, result: BatchResult<T>) {
            results[index] = result
            if (remaining.decrementAndGet() == 0) {
                @Suppress("UNCHECKED_CAST")
                onComplete((results as Array<BatchResult<T>>).asList())
            }
        }

        paths.forEachIndexed { index, path ->
            val task = Runnable {
                val result = try {
                    BatchResult(path, read(path), null)
                } catch (e: Exception) {
                    BatchResult<T>(path, null, e.message ?: e.javaClass.simpleName)
                }
                finish(index, result)
            }
            try {
                executor.execute(task)
            } catch (e: Exception) {
                // Executor encerrado (módulo invalidado): registra o erro no item.
                finish(index, BatchResult(path, null, e.message ?: "Leitura cancelada"))
            }
        }
    }

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
