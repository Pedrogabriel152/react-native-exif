package com.pedro.reactnativeexif

import com.facebook.react.bridge.Arguments
import com.facebook.react.bridge.Promise
import com.facebook.react.bridge.ReactApplicationContext
import com.facebook.react.bridge.ReactMethod
import com.facebook.react.bridge.ReadableArray
import com.facebook.react.bridge.WritableArray
import com.facebook.react.bridge.WritableMap
import com.facebook.react.module.annotations.ReactModule
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

@ReactModule(name = ReactNativeExifModule.NAME)
class ReactNativeExifModule(reactContext: ReactApplicationContext) :
    NativeReactNativeExifSpec(reactContext) {

    // Leituras de EXIF fazem I/O; rodam fora da thread de módulos nativos
    // para não bloquear outras chamadas e permitir leituras em paralelo.
    private val executor: ExecutorService = Executors.newFixedThreadPool(
        Runtime.getRuntime().availableProcessors().coerceIn(2, 4)
    )

    private val reader = ExifReader(reactContext.contentResolver)

    override fun getName(): String = NAME

    override fun invalidate() {
        executor.shutdownNow()
        super.invalidate()
    }

    companion object {
        const val NAME = "ReactNativeExif"
    }

    @ReactMethod
    override fun getExif(uri: String, promise: Promise) {
        runAsync(promise, "Erro ao ler EXIF") {
            exifToMap(uri, reader.readExif(uri))
        }
    }

    @ReactMethod
    override fun getLatLong(path: String, promise: Promise) {
        runAsync(promise, "Erro ao ler EXIF") {
            latLongToMap(reader.readLatLong(path))
        }
    }

    @ReactMethod
    override fun getExifBatch(paths: ReadableArray, promise: Promise) {
        reader.readExifBatch(toPathList(paths), executor) { results ->
            promise.resolve(batchToArray(results) { path, exif -> exifToMap(path, exif) })
        }
    }

    @ReactMethod
    override fun getLatLongBatch(paths: ReadableArray, promise: Promise) {
        reader.readLatLongBatch(toPathList(paths), executor) { results ->
            promise.resolve(batchToArray(results) { _, latLong -> latLongToMap(latLong) })
        }
    }

    private fun toPathList(paths: ReadableArray): List<String> =
        List(paths.size()) { index -> paths.getString(index) ?: "" }

    private fun exifToMap(uri: String, exif: Map<String, String?>): WritableMap {
        val map = Arguments.createMap()
        for ((tag, value) in exif) {
            map.putString(tag, value)
        }
        map.putString("originalUri", uri)
        return map
    }

    // Sem GPS devolve 0,0 (mesmo contrato do getLatLong individual).
    private fun latLongToMap(latLong: DoubleArray?): WritableMap {
        val map = Arguments.createMap()
        map.putDouble("latitude", latLong?.get(0) ?: 0.0)
        map.putDouble("longitude", latLong?.get(1) ?: 0.0)
        return map
    }

    private fun <T> batchToArray(
        results: List<BatchResult<T>>,
        toMap: (String, T) -> WritableMap
    ): WritableArray {
        val array = Arguments.createArray()
        for (result in results) {
            val item = Arguments.createMap()
            item.putString("path", result.path)
            if (result.error == null) {
                @Suppress("UNCHECKED_CAST")
                item.putMap("data", toMap(result.path, result.data as T))
                item.putNull("error")
            } else {
                item.putNull("data")
                item.putString("error", result.error)
            }
            array.pushMap(item)
        }
        return array
    }

    private fun runAsync(promise: Promise, fallbackMessage: String, block: () -> WritableMap) {
        try {
            executor.execute {
                try {
                    promise.resolve(block())
                } catch (e: Exception) {
                    promise.reject("EXIF_ERROR", e.message ?: fallbackMessage, e)
                }
            }
        } catch (e: Exception) {
            // Executor encerrado (módulo invalidado) ou rejeitado.
            promise.reject("EXIF_ERROR", e.message ?: fallbackMessage, e)
        }
    }
}
