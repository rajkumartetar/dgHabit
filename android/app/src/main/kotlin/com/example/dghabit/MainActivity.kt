package com.example.dghabit

import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.drawable.BitmapDrawable
import android.graphics.drawable.Drawable
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream

class MainActivity : FlutterActivity() {
	override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
		super.configureFlutterEngine(flutterEngine)
		MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.example.dghabit/app_info").setMethodCallHandler { call, result ->
			when (call.method) {
				"getAppInfos" -> {
					val args = call.arguments as? Map<*, *>
					val list = (args?.get("packages") as? List<*>)?.mapNotNull { it as? String } ?: emptyList()
					val pm = applicationContext.packageManager
					val out = HashMap<String, Map<String, Any?>>()
					for (pkg in list) {
						try {
							val appInfo = pm.getApplicationInfo(pkg, 0)
							val label = pm.getApplicationLabel(appInfo).toString()
							val iconDrawable = pm.getApplicationIcon(pkg)
							val iconBytes = drawableToBytes(iconDrawable)
							out[pkg] = mapOf(
								"name" to label,
								"icon" to iconBytes
							)
						} catch (e: Exception) {
							out[pkg] = mapOf(
								"name" to pkg,
								"icon" to null
							)
						}
					}
					result.success(out)
				}
				else -> result.notImplemented()
			}
		}
	}

	private fun drawableToBytes(drawable: Drawable): ByteArray {
		val bitmap: Bitmap = if (drawable is BitmapDrawable) {
			drawable.bitmap
		} else {
			val width = if (drawable.intrinsicWidth > 0) drawable.intrinsicWidth else 96
			val height = if (drawable.intrinsicHeight > 0) drawable.intrinsicHeight else 96
			val bmp = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
			val canvas = Canvas(bmp)
			drawable.setBounds(0, 0, canvas.width, canvas.height)
			drawable.draw(canvas)
			bmp
		}
		val stream = ByteArrayOutputStream()
		bitmap.compress(Bitmap.CompressFormat.PNG, 100, stream)
		return stream.toByteArray()
	}
}
