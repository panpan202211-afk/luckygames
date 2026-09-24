# Airbridge optionally integrates with Firebase Messaging. This app does not
# include Firebase Messaging, so its absent callback type is safe to ignore.
-dontwarn com.google.firebase.messaging.RemoteMessage

# H5 calls these names directly, including in obfuscated release APKs.
-keepclassmembers class com.nasirabbas.luckygames.AndroidAirbridge {
    @android.webkit.JavascriptInterface <methods>;
}
