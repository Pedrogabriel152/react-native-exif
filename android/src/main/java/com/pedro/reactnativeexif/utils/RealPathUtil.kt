package com.pedro.reactnativeexif.utils

import android.annotation.SuppressLint
import android.content.ContentUris
import android.content.Context
import android.database.Cursor
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.DocumentsContract
import android.provider.MediaStore
import androidx.core.content.FileProvider
import java.io.File

object RealPathUtil {

    fun compatUriFromFile(context: Context, file: File): Uri? {
        return if (Build.VERSION.SDK_INT < 21) {
            Uri.fromFile(file)
        } else {
            val packageName = context.applicationContext.packageName
            val authority = "$packageName.provider"
            try {
                FileProvider.getUriForFile(context, authority, file)
            } catch (e: IllegalArgumentException) {
                e.printStackTrace()
                null
            }
        }
    }

    @SuppressLint("NewApi")
    fun getRealPathFromURI(context: Context, uri: Uri): String? {
        val isKitKat = Build.VERSION.SDK_INT >= Build.VERSION_CODES.KITKAT

        if (isKitKat && DocumentsContract.isDocumentUri(context, uri)) {
            // ExternalStorageProvider
            if (isExternalStorageDocument(uri)) {
                val docId = DocumentsContract.getDocumentId(uri)
                val split = docId.split(":")
                val type = split[0]
                if (type.equals("primary", ignoreCase = true)) {
                    return "${Environment.getExternalStorageDirectory()}/${split[1]}"
                }
                // TODO: handle non-primary volumes
            }
            // DownloadsProvider
            else if (isDownloadsDocument(uri)) {
                val id = DocumentsContract.getDocumentId(uri)
                val contentUri = ContentUris.withAppendedId(
                  Uri.parse("content://downloads/public_downloads"),
                    id.toLong()
                )
                return getDataColumn(context, contentUri, null, null)
            }
            // MediaProvider
            else if (isMediaDocument(uri)) {
                val docId = DocumentsContract.getDocumentId(uri)
                val split = docId.split(":")
                val type = split[0]

                val contentUri = when (type) {
                    "image" -> MediaStore.Images.Media.EXTERNAL_CONTENT_URI
                    "video" -> MediaStore.Video.Media.EXTERNAL_CONTENT_URI
                    "audio" -> MediaStore.Audio.Media.EXTERNAL_CONTENT_URI
                    else -> null
                }

                val selection = "_id=?"
                val selectionArgs = arrayOf(split[1])

                return contentUri?.let {
                    getDataColumn(context, it, selection, selectionArgs)
                }
            }
        } else if (uri.scheme.equals("content", ignoreCase = true)) {
            if (isGooglePhotosUri(uri)) return uri.lastPathSegment
            if (isFileProviderUri(context, uri)) return getFileProviderPath(context, uri)
            return getDataColumn(context, uri, null, null)
        } else if (uri.scheme.equals("file", ignoreCase = true)) {
            return uri.path
        }

        return null
    }

    private fun getDataColumn(
        context: Context,
        uri: Uri,
        selection: String?,
        selectionArgs: Array<String>?
    ): String? {
        var cursor: Cursor? = null
        val column = "_data"
        val projection = arrayOf(column)

        try {
            cursor = context.contentResolver.query(uri, projection, selection, selectionArgs, null)
            if (cursor != null && cursor.moveToFirst()) {
                val index = cursor.getColumnIndexOrThrow(column)
                return cursor.getString(index)
            }
        } finally {
            cursor?.close()
        }
        return null
    }

    fun isExternalStorageDocument(uri: Uri) = "com.android.externalstorage.documents" == uri.authority
    fun isDownloadsDocument(uri: Uri) = "com.android.providers.downloads.documents" == uri.authority
    fun isMediaDocument(uri: Uri) = "com.android.providers.media.documents" == uri.authority
    fun isGooglePhotosUri(uri: Uri) = "com.google.android.apps.photos.content" == uri.authority

    fun isFileProviderUri(context: Context, uri: Uri): Boolean {
        val authority = "${context.packageName}.provider"
        return authority == uri.authority
    }

    fun getFileProviderPath(context: Context, uri: Uri): String? {
        val appDir = context.getExternalFilesDir(Environment.DIRECTORY_PICTURES)
        val file = File(appDir, uri.lastPathSegment ?: "")
        return if (file.exists()) file.toString() else null
    }
}
