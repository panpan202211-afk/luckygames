package com.nasirabbas.luckygames

import android.app.Application
import android.util.Log
import co.ab180.airbridge.flutter.AirbridgeFlutter
import org.json.JSONObject

class MainApplication : Application() {
    override fun onCreate() {
        super.onCreate()

        val config = runCatching {
            assets.open("airbridge.json").bufferedReader().use {
                JSONObject(it.readText())
            }
        }.getOrElse {
            Log.w(TAG, "Unable to read airbridge.json; attribution is disabled.", it)
            return
        }

        val appName = config.optString("appName").trim()
        val appToken = config.optString("appToken").trim()
        if (!isConfigured(appName, appToken)) {
            Log.w(TAG, "Airbridge credentials are not configured; attribution is disabled.")
            return
        }

        AirbridgeFlutter.initializeSDK(this, appName, appToken)
        airbridgeReady = config.optBoolean("sdkEnabled", true)
    }

    private fun isConfigured(appName: String, appToken: String): Boolean {
        return appName.isNotEmpty() &&
            appToken.isNotEmpty() &&
            !appName.startsWith("YOUR_") &&
            !appToken.startsWith("YOUR_")
    }

    companion object {
        private const val TAG = "LuckyGamesAirbridge"
        var airbridgeReady = false
            private set
    }
}
