package com.pedro.reactnativeexif

import android.content.ContentProvider
import android.content.ContentValues
import android.database.Cursor
import android.net.Uri
import android.os.ParcelFileDescriptor
import androidx.exifinterface.media.ExifInterface
import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder
import org.junit.runner.RunWith
import org.robolectric.Robolectric
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.annotation.Config
import java.io.File
import java.io.IOException
import java.util.concurrent.CountDownLatch
import java.util.concurrent.Executor
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [34])
class ExifReaderTest {

    @get:Rule
    val tempFolder = TemporaryFolder()

    private lateinit var reader: ExifReader
    private lateinit var withGps: File
    private lateinit var noExif: File

    @Before
    fun setUp() {
        withGps = copyFixture("with_gps.jpg")
        noExif = copyFixture("no_exif.jpg")

        FixtureProvider.files = mapOf("with_gps.jpg" to withGps)
        Robolectric.setupContentProvider(FixtureProvider::class.java, FixtureProvider.AUTHORITY)

        reader = ExifReader(RuntimeEnvironment.getApplication().contentResolver)
    }

    // --- getExif ---------------------------------------------------------

    @Test
    fun readExif_plainPath_returnsTagValues() {
        assertWithGpsValues(reader.readExif(withGps.absolutePath))
    }

    @Test
    fun readExif_fileUri_returnsTagValues() {
        assertWithGpsValues(reader.readExif(Uri.fromFile(withGps).toString()))
    }

    @Test
    fun readExif_contentUri_returnsTagValues() {
        assertWithGpsValues(reader.readExif(FixtureProvider.uriFor("with_gps.jpg")))
    }

    @Test
    fun readExif_returnsEveryAttributeKeyInOrder() {
        val result = reader.readExif(withGps.absolutePath)

        assertEquals(ExifReader.EXIF_ATTRIBUTES.toList(), result.keys.toList())
    }

    @Test
    fun readExif_imageWithoutExif_returnsNullMetadata() {
        val result = reader.readExif(noExif.absolutePath)

        assertEquals(ExifReader.EXIF_ATTRIBUTES.size, result.size)
        assertNull(result[ExifInterface.TAG_MAKE])
        assertNull(result[ExifInterface.TAG_MODEL])
        assertNull(result[ExifInterface.TAG_DATETIME_ORIGINAL])
        assertNull(result[ExifInterface.TAG_GPS_LATITUDE])
    }

    @Test(expected = IOException::class)
    fun readExif_missingFile_throws() {
        reader.readExif(File(tempFolder.root, "missing.jpg").absolutePath)
    }

    @Test(expected = IOException::class)
    fun readExif_contentUriWithoutFile_throws() {
        reader.readExif(FixtureProvider.uriFor("missing.jpg"))
    }

    // --- getLatLong ------------------------------------------------------

    @Test
    fun readLatLong_southWest_returnsNegativeCoordinates() {
        val latLong = reader.readLatLong(withGps.absolutePath)

        assertNotNull(latLong)
        assertArrayEquals(doubleArrayOf(-23.5505, -46.6333), latLong, 1e-4)
    }

    @Test
    fun readLatLong_contentUri_returnsCoordinates() {
        val latLong = reader.readLatLong(FixtureProvider.uriFor("with_gps.jpg"))

        assertArrayEquals(doubleArrayOf(-23.5505, -46.6333), latLong, 1e-4)
    }

    @Test
    fun readLatLong_withoutGps_returnsNull() {
        assertNull(reader.readLatLong(noExif.absolutePath))
    }

    // --- lote -----------------------------------------------------------

    @Test
    fun readExifBatch_mixedInputs_keepsOrderAndReportsErrorsPerItem() {
        val missing = File(tempFolder.root, "missing.jpg").absolutePath
        val paths = listOf(
            withGps.absolutePath,
            missing,
            FixtureProvider.uriFor("with_gps.jpg"),
            noExif.absolutePath,
        )

        val results = awaitBatch<LinkedHashMap<String, String?>> { executor, done ->
            reader.readExifBatch(paths, executor, done)
        }

        assertEquals(paths, results.map { it.path })

        assertNull(results[0].error)
        assertWithGpsValues(results[0].data!!)

        assertNull(results[1].data)
        assertNotNull(results[1].error)

        assertNull(results[2].error)
        assertWithGpsValues(results[2].data!!)

        assertNull(results[3].error)
        assertNull(results[3].data!![ExifInterface.TAG_MAKE])
    }

    @Test
    fun readLatLongBatch_returnsCoordinatesOrNullPerItem() {
        val paths = listOf(withGps.absolutePath, noExif.absolutePath)

        val results = awaitBatch<DoubleArray?> { executor, done ->
            reader.readLatLongBatch(paths, executor, done)
        }

        assertArrayEquals(doubleArrayOf(-23.5505, -46.6333), results[0].data, 1e-4)
        assertNull(results[0].error)
        assertNull(results[1].data)
        assertNull(results[1].error)
    }

    @Test
    fun readExifBatch_manyConcurrentItems_returnsAllInOrder() {
        val paths = List(50) { index ->
            if (index % 2 == 0) withGps.absolutePath else noExif.absolutePath
        }

        val results = awaitBatch<LinkedHashMap<String, String?>> { executor, done ->
            reader.readExifBatch(paths, executor, done)
        }

        assertEquals(50, results.size)
        results.forEachIndexed { index, result ->
            assertNull(result.error)
            val expectedMake = if (index % 2 == 0) "TestMake" else null
            assertEquals(expectedMake, result.data!![ExifInterface.TAG_MAKE])
        }
    }

    @Test
    fun readExifBatch_emptyList_completesImmediately() {
        var results: List<BatchResult<LinkedHashMap<String, String?>>>? = null

        reader.readExifBatch(emptyList(), { error("não deve executar tarefas") }) { results = it }

        assertEquals(emptyList<Any>(), results)
    }

    @Test
    fun readExifBatch_executorShutDown_reportsErrorInsteadOfHanging() {
        val executor = Executors.newSingleThreadExecutor().apply { shutdown() }
        var results: List<BatchResult<LinkedHashMap<String, String?>>>? = null

        reader.readExifBatch(listOf(withGps.absolutePath), executor) { results = it }

        assertEquals(1, results!!.size)
        assertNull(results!![0].data)
        assertNotNull(results!![0].error)
    }

    private fun <T> awaitBatch(
        start: (Executor, (List<BatchResult<T>>) -> Unit) -> Unit
    ): List<BatchResult<T>> {
        val executor = Executors.newFixedThreadPool(4)
        val latch = CountDownLatch(1)
        var results: List<BatchResult<T>> = emptyList()
        try {
            start(executor) {
                results = it
                latch.countDown()
            }
            assertTrue("lote não terminou a tempo", latch.await(10, TimeUnit.SECONDS))
        } finally {
            executor.shutdownNow()
        }
        return results
    }

    // --- lista de atributos ----------------------------------------------

    @Test
    fun exifAttributes_hasNoDuplicates() {
        val attributes = ExifReader.EXIF_ATTRIBUTES.toList()

        assertEquals(attributes.size, attributes.toSet().size)
    }

    @Test
    fun exifAttributes_excludesLargeBinaryTags() {
        val attributes = ExifReader.EXIF_ATTRIBUTES.toSet()

        assertFalse(ExifInterface.TAG_MAKER_NOTE in attributes)
        assertFalse(ExifInterface.TAG_ORF_THUMBNAIL_IMAGE in attributes)
        assertFalse(ExifInterface.TAG_RW2_JPG_FROM_RAW in attributes)
    }

    // --- helpers ---------------------------------------------------------

    private fun assertWithGpsValues(result: Map<String, String?>) {
        assertEquals("TestMake", result[ExifInterface.TAG_MAKE])
        assertEquals("TestModel", result[ExifInterface.TAG_MODEL])
        assertEquals("2024:05:10 14:30:00", result[ExifInterface.TAG_DATETIME_ORIGINAL])
        assertEquals("6", result[ExifInterface.TAG_ORIENTATION])
        assertEquals("S", result[ExifInterface.TAG_GPS_LATITUDE_REF])
        assertEquals("W", result[ExifInterface.TAG_GPS_LONGITUDE_REF])
        assertEquals("8", result[ExifInterface.TAG_IMAGE_WIDTH])
        assertEquals("8", result[ExifInterface.TAG_IMAGE_LENGTH])
    }

    private fun copyFixture(name: String): File {
        val target = tempFolder.newFile(name)
        val stream = javaClass.classLoader!!.getResourceAsStream("fixtures/$name")
            ?: error("Fixture não encontrada: $name")
        stream.use { input -> target.outputStream().use { input.copyTo(it) } }
        return target
    }

    /** Provider mínimo que expõe as fixtures via `content://`, como MediaStore/DocumentsProvider. */
    class FixtureProvider : ContentProvider() {
        companion object {
            const val AUTHORITY = "com.pedro.reactnativeexif.fixtures"
            var files: Map<String, File> = emptyMap()

            fun uriFor(name: String) = "content://$AUTHORITY/$name"
        }

        override fun openFile(uri: Uri, mode: String): ParcelFileDescriptor? {
            val file = files[uri.lastPathSegment]
                ?: throw java.io.FileNotFoundException("Sem fixture para $uri")
            return ParcelFileDescriptor.open(file, ParcelFileDescriptor.MODE_READ_ONLY)
        }

        override fun onCreate() = true
        override fun query(
            uri: Uri,
            projection: Array<out String>?,
            selection: String?,
            selectionArgs: Array<out String>?,
            sortOrder: String?
        ): Cursor? = null
        override fun getType(uri: Uri): String = "image/jpeg"
        override fun insert(uri: Uri, values: ContentValues?): Uri? = null
        override fun delete(uri: Uri, selection: String?, selectionArgs: Array<out String>?) = 0
        override fun update(
            uri: Uri,
            values: ContentValues?,
            selection: String?,
            selectionArgs: Array<out String>?
        ) = 0
    }
}
