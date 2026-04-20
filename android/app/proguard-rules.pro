# QR Vault - ProGuard Rules

# Keep Hive adapters
-keep class com.yourname.qrvault.** { *; }
-keep class * extends com.hive.TypeAdapter { *; }
-keep class * implements com.hive.TypeAdapter { *; }

# Keep ML Kit classes
-keep class com.google.mlkit.** { *; }
-dontwarn com.google.mlkit.**

# Keep mobile_scanner classes
-keep class io.lucaseal.** { *; }
-keep class dev.gitlab.** { *; }
-dontwarn io.lucaseal.**

# Keep RevenueCat (if using)
-keep class com.revenuecat.** { *; }
-dontwarn com.revenuecat.**

# Keep Firebase classes
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.firebase.**
-dontwarn com.google.android.gms.**

# Keep barcode scanning
-keep class com.google.mlkit.vision.** { *; }
-keep class com.google.android.gms.** { *; }

# Keep Google Mobile Ads
-keep class com.google.android.gms.ads.** { *; }
-keep class com.google.ads.** { *; }

# Keep Flutter
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }

# Keep dart:core
-keep class dart.** { *; }

# Keep serialization
-keepclassmembers class * {
  @com.google.gson.annotations.SerializedName <fields>;
}

# Obfuscation settings
-allowaccessmodification
-dontpreverify
-repackageclasses ''