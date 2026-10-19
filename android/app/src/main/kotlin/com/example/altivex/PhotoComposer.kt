package com.example.altivex

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Matrix
import android.graphics.Paint
import android.graphics.RectF
import android.media.ExifInterface
import java.io.File
import kotlin.math.roundToInt

/** Keeps the full photograph on Android; Flutter supplies only a transparent watermark. */
class PhotoComposer(private val dataDirectory: File, private val cacheDirectory: File) {
    private fun source(path: String): File {
        val file = File(path).canonicalFile
        require(file.isFile && (file.path.startsWith(dataDirectory.canonicalPath + File.separator) ||
            file.path.startsWith(cacheDirectory.canonicalPath + File.separator)))
        return file
    }

    private fun orientation(file: File, width: Int, height: Int): Pair<Matrix, RectF> {
        val tag = ExifInterface(file.path).getAttributeInt(ExifInterface.TAG_ORIENTATION, 1)
        val values = when (tag) {
            2 -> floatArrayOf(-1f, 0f, 0f, 0f, 1f, 0f, 0f, 0f, 1f)
            3 -> floatArrayOf(-1f, 0f, 0f, 0f, -1f, 0f, 0f, 0f, 1f)
            4 -> floatArrayOf(1f, 0f, 0f, 0f, -1f, 0f, 0f, 0f, 1f)
            5 -> floatArrayOf(0f, 1f, 0f, 1f, 0f, 0f, 0f, 0f, 1f)
            6 -> floatArrayOf(0f, -1f, 0f, 1f, 0f, 0f, 0f, 0f, 1f)
            7 -> floatArrayOf(0f, -1f, 0f, -1f, 0f, 0f, 0f, 0f, 1f)
            8 -> floatArrayOf(0f, 1f, 0f, -1f, 0f, 0f, 0f, 0f, 1f)
            else -> floatArrayOf(1f, 0f, 0f, 0f, 1f, 0f, 0f, 0f, 1f)
        }
        val matrix = Matrix().apply { setValues(values) }
        val bounds = RectF(0f, 0f, width.toFloat(), height.toFloat())
        matrix.mapRect(bounds)
        matrix.postTranslate(-bounds.left, -bounds.top)
        return matrix to RectF(0f, 0f, bounds.width(), bounds.height())
    }

    fun info(path: String): Map<String, Int> {
        val file = source(path)
        val options = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        BitmapFactory.decodeFile(file.path, options)
        require(options.outWidth > 0 && options.outHeight > 0)
        val bounds = orientation(file, options.outWidth, options.outHeight).second
        return mapOf("width" to bounds.width().toInt(), "height" to bounds.height().toInt())
    }

    fun compose(path: String, destinationPath: String, cropValues: List<Number>, tiles: List<Map<String, Any?>>) {
        val file = source(path)
        val destination = File(destinationPath).canonicalFile
        val photoDirectory = File(dataDirectory, "app_flutter/AltivexCamera").canonicalFile
        require(destination.parentFile == photoDirectory && Regex("Altivex_[0-9]+\\.jpg").matches(destination.name))
        require(cropValues.size == 4)
        val crop = RectF(cropValues[0].toFloat(), cropValues[1].toFloat(), cropValues[2].toFloat(), cropValues[3].toFloat())
        require(crop.width() >= 1 && crop.height() >= 1)
        var input: Bitmap? = BitmapFactory.decodeFile(file.path, BitmapFactory.Options().apply { inMutable = true }) ?: error("照片解码失败")
        var output: Bitmap? = null
        val pending = File(destination.path + ".writing")
        try {
            val (transform, bounds) = orientation(file, input!!.width, input!!.height)
            require(bounds.contains(crop))
            val width = crop.width().roundToInt()
            val height = crop.height().roundToInt()
            val paint = Paint(Paint.ANTI_ALIAS_FLAG or Paint.FILTER_BITMAP_FLAG)
            val canvas: Canvas
            if (transform.isIdentity && crop.left == 0f && crop.top == 0f && width == input!!.width && height == input!!.height) {
                output = input
                input = null
                canvas = Canvas(output!!)
            } else {
                output = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
                canvas = Canvas(output!!)
                canvas.save()
                canvas.scale(width / crop.width(), height / crop.height())
                canvas.translate(-crop.left, -crop.top)
                canvas.concat(transform)
                canvas.drawBitmap(input!!, 0f, 0f, paint)
                canvas.restore()
                input!!.recycle()
                input = null
            }
            for (tile in tiles) {
                val overlay = tile["bytes"] as? ByteArray ?: error("缺少水印")
                val left = (tile["left"] as? Number)?.toInt() ?: error("缺少水印位置")
                val top = (tile["top"] as? Number)?.toInt() ?: error("缺少水印位置")
                val watermark = BitmapFactory.decodeByteArray(overlay, 0, overlay.size) ?: error("水印解码失败")
                try {
                    require(left >= 0 && top >= 0 && left + watermark.width <= width && top + watermark.height <= height)
                    canvas.drawBitmap(watermark, left.toFloat(), top.toFloat(), paint)
                } finally { watermark.recycle() }
            }
            pending.outputStream().use { check(output!!.compress(Bitmap.CompressFormat.JPEG, 92, it)) }
            check(pending.renameTo(destination))
        } finally {
            input?.recycle()
            output?.recycle()
            if (pending.exists()) pending.delete()
        }
    }
}
