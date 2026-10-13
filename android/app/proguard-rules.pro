# flutter_local_notifications + Gson
-keep class com.dexterous.** { *; }
-keep class com.google.gson.** { *; }
-keepattributes Signature
-keepattributes *Annotation*

# Gson type tokens (fixes "Missing type parameter")
-keepclassmembers,allowobfuscation class * {
  @com.google.gson.annotations.SerializedName <fields>;
}
-keep class * extends com.google.gson.TypeToken { *; }
-keep class com.google.gson.reflect.TypeToken { *; }

# Keep model classes the plugin serializes (scheduled notifications)
-keep class com.dexterous.flutterlocalnotifications.** { *; }