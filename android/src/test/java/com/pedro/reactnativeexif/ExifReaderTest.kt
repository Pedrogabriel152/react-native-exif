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
