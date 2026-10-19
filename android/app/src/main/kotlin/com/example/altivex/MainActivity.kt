package com.example.altivex

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.content.ContentValues
import android.content.ContentUris
import android.net.Uri
import android.os.Build
import android.provider.MediaStore
import android.os.Environment
import java.io.File
import java.util.concurrent.Executors
import android.graphics.Bitmap
import java.io.ByteArrayOutputStream
import java.nio.ByteBuffer

class MainActivity : FlutterActivity() {
    private val galleryExecutor = Executors.newSingleThreadExecutor()
    private val supportsRgbaBuffer by lazy {
        val probe = Bitmap.createBitmap(1, 1, Bitmap.Config.ARGB_8888)
        try {
            probe.copyPixelsFromBuffer(ByteBuffer.wrap(byteArrayOf(17, 34, 51, -1)))
            probe.getPixel(0, 0) == 0xFF112233.toInt()
        } finally { probe.recycle() }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val composer = PhotoComposer(File(applicationInfo.dataDir), cacheDir)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "altivex/image")
            .setMethodCallHandler { call, result ->
                if (call.method !in listOf("encodeJpeg", "photoInfo", "composeJpeg")) {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                galleryExecutor.execute {
                    try {
                        if (call.method == "photoInfo") {
                            val info = composer.info(call.argument<String>("path") ?: error("缺少图片路径"))
                            runOnUiThread { result.success(info) }
                            return@execute
                        }
                        if (call.method == "composeJpeg") {
                            composer.compose(
                                call.argument<String>("path") ?: error("缺少图片路径"),
                                call.argument<String>("destination") ?: error("缺少输出路径"),
                                call.argument<List<Number>>("crop") ?: error("缺少裁切范围"),
                                call.argument<List<Map<String, Any?>>>("tiles") ?: emptyList(),
                            )
                            runOnUiThread { result.success(null) }
                            return@execute
                        }
                        val rgba = call.argument<ByteArray>("rgba") ?: error("缺少像素")
                        val width = call.argument<Int>("width") ?: 0
                        val height = call.argument<Int>("height") ?: 0
                        require(width > 0 && height > 0 && width.toLong() * height * 4 == rgba.size.toLong())
                        val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
                        val bytes = try {
                            if (supportsRgbaBuffer) {
                                // Probe the native pixel order before copying premultiplied RGBA.
                                bitmap.copyPixelsFromBuffer(ByteBuffer.wrap(rgba))
                            } else {
                                val row = IntArray(width)
                                for (y in 0 until height) {
                                    var offset = y * width * 4
                                    for (x in 0 until width) {
                                        val alpha = rgba[offset + 3].toInt() and 255
                                        fun straight(channel: Int): Int = if (alpha == 0) 0 else
                                            ((channel and 255) * 255 / alpha).coerceAtMost(255)
                                        row[x] = (alpha shl 24) or
                                            (straight(rgba[offset].toInt()) shl 16) or
                                            (straight(rgba[offset + 1].toInt()) shl 8) or
                                            straight(rgba[offset + 2].toInt())
                                        offset += 4
                                    }
                                    bitmap.setPixels(row, 0, width, 0, y, width, 1)
                                }
                            }
                            ByteArrayOutputStream().use { output ->
                                check(bitmap.compress(Bitmap.CompressFormat.JPEG, 92, output))
                                output.toByteArray()
                            }
                        } finally { bitmap.recycle() }
                        runOnUiThread { result.success(bytes) }
                    } catch (e: OutOfMemoryError) {
                        runOnUiThread { result.error("image_memory_unavailable", "照片处理内存不足，恢复文件已保留", null) }
                    } catch (e: Exception) {
                        runOnUiThread { result.error("image_encode_failed", "照片编码失败，恢复文件已保留", null) }
                    }
                }
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "altivex/gallery")
            .setMethodCallHandler { call, result ->
                if (call.method == "apiLevel") {
                    result.success(Build.VERSION.SDK_INT)
                    return@setMethodCallHandler
                }
                if (call.method != "saveImage" && call.method != "deleteImages") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                galleryExecutor.execute {
                    try {
                        val answer: String? = when (call.method) {
                            "saveImage" -> saveImage(call.argument<String>("path") ?: error("缺少图片路径"))
                            else -> {
                                deleteImages(call.argument<List<String>>("uris") ?: emptyList())
                                null
                            }
                        }
                        runOnUiThread { result.success(answer) }
                    } catch (e: Exception) {
                        runOnUiThread { result.error("gallery_operation_failed", "相册操作失败，请检查权限及存储空间后重试", null) }
                    }
                }
            }
    }

    private fun saveImage(path: String): String {
        val file = File(path).canonicalFile
        require(file.path.startsWith(filesDir.canonicalPath + File.separator) ||
            file.path.startsWith(File(applicationInfo.dataDir, "app_flutter").canonicalPath + File.separator)) { "图片不在应用目录" }
        require(file.isFile && file.extension.lowercase() in listOf("jpg", "png"))
        if (Build.VERSION.SDK_INT >= 29) {
            // Retry after a metadata write failure reuses this app's existing copy.
            contentResolver.query(MediaStore.Images.Media.EXTERNAL_CONTENT_URI,
                arrayOf(MediaStore.Images.Media._ID),
                "${MediaStore.Images.Media.DISPLAY_NAME}=? AND ${MediaStore.Images.Media.RELATIVE_PATH}=? AND ${MediaStore.Images.Media.OWNER_PACKAGE_NAME}=? AND ${MediaStore.Images.Media.IS_PENDING}=0",
                arrayOf(file.name, "Pictures/Altivex/", packageName), null)?.use {
                    if (it.moveToFirst()) return ContentUris.withAppendedId(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, it.getLong(0)).toString()
                }
        }
        val values = ContentValues().apply {
            put(MediaStore.Images.Media.DISPLAY_NAME, file.name)
            put(MediaStore.Images.Media.MIME_TYPE, if (file.extension == "png") "image/png" else "image/jpeg")
            if (Build.VERSION.SDK_INT >= 29) {
                put(MediaStore.Images.Media.RELATIVE_PATH, "Pictures/Altivex")
                put(MediaStore.Images.Media.IS_PENDING, 1)
            } else {
                val folder = File(Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_PICTURES), "Altivex")
                check(folder.exists() || folder.mkdirs())
                put(MediaStore.Images.Media.DATA, File(folder, file.name).path)
            }
        }
        val uri = contentResolver.insert(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, values)
            ?: error("无法创建相册记录")
        try {
            contentResolver.openOutputStream(uri)?.use { output -> file.inputStream().use { it.copyTo(output) } }
                ?: error("无法写入相册")
            if (Build.VERSION.SDK_INT >= 29) {
                contentResolver.update(uri, ContentValues().apply { put(MediaStore.Images.Media.IS_PENDING, 0) }, null, null)
            }
            return uri.toString()
        } catch (error: Exception) {
            contentResolver.delete(uri, null, null)
            throw error
        }
    }

    private fun deleteImages(values: List<String>) {
        for (value in values) {
            val uri = Uri.parse(value)
            require(uri.scheme == "content" && uri.authority == "media" &&
                Regex("^/external/images/media/[0-9]+$").matches(uri.path ?: ""))
            if (Build.VERSION.SDK_INT >= 29) {
                contentResolver.query(uri, arrayOf(MediaStore.Images.Media.OWNER_PACKAGE_NAME), null, null, null)?.use {
                    if (it.moveToFirst()) require(it.getString(0) == packageName) { "不允许删除其他应用的图片" }
                }
            }
            contentResolver.delete(uri, null, null)
        }
    }
}
