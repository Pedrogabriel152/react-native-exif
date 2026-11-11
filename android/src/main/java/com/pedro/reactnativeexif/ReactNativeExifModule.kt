package com.pedro.reactnativeexif

import com.facebook.react.bridge.Arguments
import com.facebook.react.bridge.Promise
import com.facebook.react.bridge.ReactApplicationContext
import com.facebook.react.bridge.ReactMethod
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
            val exifMap = Arguments.createMap()
            for ((tag, value) in reader.readExif(uri)) {
                exifMap.putString(tag, value)
            }
            exifMap.putString("originalUri", uri)
            exifMap
        }
    }

    @ReactMethod
    override fun getLatLong(path: String, promise: Promise) {
        runAsync(promise, "Erro ao ler EXIF") {
            val latLong = reader.readLatLong(path)
            val result = Arguments.createMap()
            result.putDouble("latitude", latLong?.get(0) ?: 0.0)
            result.putDouble("longitude", latLong?.get(1) ?: 0.0)
            result
        }
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
