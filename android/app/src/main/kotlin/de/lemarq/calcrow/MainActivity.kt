package de.lemarq.calcrow

import android.content.ActivityNotFoundException
import android.content.ClipData
import android.content.Intent
import android.net.Uri
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
	private val openFileChannelName = "de.lemarq.calcrow/file_open"

	override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
		super.configureFlutterEngine(flutterEngine)
		MethodChannel(flutterEngine.dartExecutor.binaryMessenger, openFileChannelName)
			.setMethodCallHandler { call, result ->
				when (call.method) {
					"openSafDocument" -> {
						val uriString = call.argument<String>("uri")?.trim().orEmpty()
						val mimeType = call.argument<String>("mimeType")?.trim().orEmpty()
						if (uriString.isEmpty()) {
							result.error("invalid_uri", "Missing document uri.", null)
							return@setMethodCallHandler
						}

						val uri = Uri.parse(uriString)
						val openIntent = Intent(Intent.ACTION_VIEW).apply {
							setDataAndType(uri, mimeType.ifEmpty { "*/*" })
							addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
							addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
							clipData = ClipData.newUri(contentResolver, "Calcrow document", uri)
						}

						try {
							val chooser = Intent.createChooser(openIntent, "Open with")
							chooser.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
							startActivity(chooser)
							result.success("done")
						} catch (_: ActivityNotFoundException) {
							result.success("noAppToOpen")
						}
					}

					else -> result.notImplemented()
				}
			}
	}
}
