# ProGuard / R8 rules (release)
-dontobfuscate


# Flutter
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.embedding.** { *; }
-keep class io.flutter.** { *; }
-dontwarn io.flutter.**

# Hive
-keep class * extends hive.TypeAdapter { *; }
-keep @hive.HiveType class * { *; }
-keepclassmembers class * {
  @hive.HiveField <fields>;
}
-keep class com.dr_rank.qrcodescanner.** { *; }

# Mobile scanner / ML Kit
-keep class dev.steenbakker.mobile_scanner.** { *; }
-keep class com.google.mlkit.** { *; }
-dontwarn com.google.mlkit.**

# Play Core (deferred components)
-keep class com.google.android.play.core.** { *; }
-dontwarn com.google.android.play.core.**

# Gson (transitive)
-keepclassmembers class * {
  @com.google.gson.annotations.SerializedName <fields>;
}

# Unity Ads
-keep class com.unity3d.ads.** { *; }
-keep class com.unity3d.services.** { *; }
-dontwarn com.unity3d.ads.**
-dontwarn com.unity3d.services.**

-assumenosideeffects class android.util.Log {
  public static *** d(...);
  public static *** v(...);
  public static *** i(...);
}
