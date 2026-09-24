package com.nasirabbas.luckygames

import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.MediaStore
import android.webkit.MimeTypeMap
import android.webkit.WebView
import android.widget.Toast
import androidx.webkit.WebViewCompat
import androidx.webkit.WebViewFeature
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugins.webviewflutter.WebViewFlutterAndroidExternalApi

class MainActivity : FlutterActivity() {
    private var fileResult: MethodChannel.Result? = null
    private var channel: MethodChannel? = null
    private val fileRequestCode = 48109

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "lucky_games/webview")
        channel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "isAirbridgeReady" -> result.success(MainApplication.airbridgeReady)
                "installTrackingScript" -> {
                    val identifier = call.argument<Number>("identifier")?.toLong()
                    val script = call.argument<String>("script")
                    @Suppress("DEPRECATION")
                    val view = identifier?.let {
                        WebViewFlutterAndroidExternalApi.getWebView(flutterEngine, it)
                    }
                    if (view == null || script == null) {
                        result.error("webview_missing", "Tracking WebView is unavailable.", null)
                    } else {
                        // Register before the first load, including on older WebViews
                        // without document-start scripts. Available in every frame.
                        view.addJavascriptInterface(AndroidAirbridge { message ->
                            runOnUiThread {
                                channel?.invokeMethod("trackH5Event", message)
                            }
                        }, "AndroidAirbridge")
                        if (WebViewFeature.isFeatureSupported(WebViewFeature.DOCUMENT_START_SCRIPT)) {
                        // Runs before H5 scripts, including in cross-origin iframe documents.
                        WebViewCompat.addDocumentStartJavaScript(view, script, setOf("*"))
                        result.success(true)
                        } else {
                        // Dart injects on page callbacks on old System WebView versions.
                        result.success(false)
                        }
                    }
                }
                "selectFiles" -> selectFiles(
                    call.argument<List<String>>("acceptTypes") ?: emptyList(),
                    call.argument<Boolean>("multiple") == true,
                    result,
                )
                "openExternal" -> result.success(openExternal(call.argument<String>("url") ?: ""))
                "configureWebView" -> {
                    val identifier = call.argument<Number>("identifier")?.toLong()
                    @Suppress("DEPRECATION")
                    val view = identifier?.let {
                        WebViewFlutterAndroidExternalApi.getWebView(flutterEngine, it)
                    }
                    if (view == null) {
                        result.error("webview_missing", "WebView is unavailable.", null)
                    } else {
                        configureFrames(view)
                        result.success(null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun selectFiles(types: List<String>, multiple: Boolean, result: MethodChannel.Result) {
        if (fileResult != null) {
            result.success(emptyList<String>())
            return
        }
        val mimeTypes = types.flatMap { it.split(',') }.mapNotNull { value ->
            val type = value.trim().lowercase()
            when {
                type.startsWith(".") -> MimeTypeMap.getSingleton()
                    .getMimeTypeFromExtension(type.drop(1))
                type.contains('/') -> type
                else -> null
            }
        }.distinct().ifEmpty { listOf("*/*") }
        val documentIntent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = mimeTypes.singleOrNull() ?: "*/*"
            putExtra(Intent.EXTRA_MIME_TYPES, mimeTypes.toTypedArray())
            putExtra(Intent.EXTRA_ALLOW_MULTIPLE, multiple)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
        // Android 13+ has a permission-free system photo picker. Older devices
        // use the system document picker, which grants access only to selections.
        val photoType = mimeTypes.singleOrNull()?.takeIf {
            it.startsWith("image/") || it.startsWith("video/")
        }
        val picker = if (Build.VERSION.SDK_INT >= 33 && photoType != null) {
            Intent(MediaStore.ACTION_PICK_IMAGES).apply {
                type = photoType
                if (multiple) putExtra(MediaStore.EXTRA_PICK_IMAGES_MAX, MediaStore.getPickImagesMaxLimit())
            }
        } else documentIntent
        fileResult = result
        try {
            @Suppress("DEPRECATION")
            startActivityForResult(picker, fileRequestCode)
        } catch (_: ActivityNotFoundException) {
            try {
                @Suppress("DEPRECATION")
                startActivityForResult(documentIntent, fileRequestCode)
            } catch (_: Exception) {
                completeFileSelection(emptyList())
            }
        } catch (_: SecurityException) {
            completeFileSelection(emptyList())
        }
    }

    @Deprecated("Android activity result callback used by FlutterActivity")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (requestCode != fileRequestCode) {
            super.onActivityResult(requestCode, resultCode, data)
            return
        }
        val uris = mutableListOf<String>()
        if (resultCode == Activity.RESULT_OK) {
            data?.clipData?.let { clip ->
                for (index in 0 until clip.itemCount) {
                    clip.getItemAt(index).uri?.takeIf { it.scheme == "content" }
                        ?.let { uris.add(it.toString()) }
                }
            }
            data?.data?.takeIf { it.scheme == "content" }?.let { uris.add(it.toString()) }
        }
        completeFileSelection(uris.distinct())
    }

    private fun completeFileSelection(uris: List<String>) {
        val pending = fileResult
        fileResult = null
        pending?.success(uris)
    }

    private fun openExternal(rawUrl: String): Map<String, Any> {
        var fallback: String? = null
        try {
            val uri = Uri.parse(rawUrl)
            val parsed = if (uri.scheme == "intent") {
                Intent.parseUri(rawUrl, Intent.URI_INTENT_SCHEME)
            } else null
            fallback = parsed?.getStringExtra("browser_fallback_url")?.takeIf { isHttps(it) }
            val target = parsed?.data ?: uri
            val scheme = target.scheme?.lowercase()
            if (scheme.isNullOrEmpty() || scheme in blockedExternalSchemes) {
                return mapOf("opened" to false)
            }
            // Build a fresh browsable intent. Never honor arbitrary components,
            // selectors, actions, extras or URI permission flags supplied by H5.
            val intent = Intent(Intent.ACTION_VIEW, target).apply {
                addCategory(Intent.CATEGORY_BROWSABLE)
                parsed?.`package`?.let { setPackage(it) }
            }
            // No resolveActivity/canOpen query, no QUERY_ALL_PACKAGES permission.
            startActivity(intent)
            return mapOf("opened" to true)
        } catch (_: Exception) {
            return buildMap {
                put("opened", false)
                fallback?.let { put("fallbackUrl", it) }
            }
        }
    }

    private fun configureFrames(view: WebView) {
        if (!WebViewFeature.isFeatureSupported(WebViewFeature.GET_WEB_VIEW_CLIENT)) return
        val delegate = WebViewCompat.getWebViewClient(view) ?: return
        if (delegate is FrameNavigationClient) return
        view.webViewClient = FrameNavigationClient(delegate) { request ->
            val uri = request.url
            val scheme = uri.scheme?.lowercase()
            when {
                scheme == "https" -> if (isHttps(uri.toString())) null else true
                scheme == "about" && uri.schemeSpecificPart in setOf("blank", "srcdoc") -> false
                scheme == "blob" || scheme == "data" -> false
                scheme.isNullOrEmpty() || scheme in blockedExternalSchemes -> true
                else -> {
                    val response = openExternal(uri.toString())
                    if (response["opened"] != true) {
                        // A fallback must not replace the parent document just
                        // because an iframe could not open another application.
                        Toast.makeText(this, "Unable to open this app. It may not be installed.", Toast.LENGTH_SHORT).show()
                    }
                    true
                }
            }
        }
    }

    private fun isHttps(value: String): Boolean {
        val uri = Uri.parse(value)
        return uri.scheme == "https" && !uri.host.isNullOrEmpty() && uri.userInfo == null
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        completeFileSelection(emptyList())
        channel?.setMethodCallHandler(null)
        channel = null
        super.cleanUpFlutterEngine(flutterEngine)
    }

    companion object {
        private val blockedExternalSchemes = setOf(
            "http", "file", "content", "javascript", "data", "blob", "about", "intent",
        )
    }
}
