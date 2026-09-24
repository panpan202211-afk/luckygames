package com.nasirabbas.luckygames

import android.webkit.JavascriptInterface
import org.json.JSONObject

/** Narrow event-only interface. Dart remains the authority for validation/deduplication. */
class AndroidAirbridge(private val enqueue: (String) -> Unit) {
    @JavascriptInterface
    fun sdkStatus(): String = if (MainApplication.airbridgeReady) "initialized" else "disabled"

    @JavascriptInterface
    fun trackEvent(eventName: String?, json: String?): String {
        if (eventName !in setOf("register", "apply", "purchase")) return "invalid_event"
        if (json != null && json.length > 65536) return "invalid_params"
        return try {
            val params = JSONObject(json ?: "{}")
            val message = JSONObject().put("eventName", eventName).put("params", params).toString()
            if (message.length > 65536) return "invalid_params"
            enqueue(message)
            // Queue acknowledgement only; SDK delivery and deduplication are asynchronous.
            "ok"
        } catch (_: Exception) {
            "invalid_params"
        }
    }

    @JavascriptInterface
    fun track(eventName: String?, json: String?): Boolean = trackEvent(eventName, json) == "ok"
}
