# Flutter
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Firebase
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }

# Crashlytics
-keepattributes SourceFile,LineNumberTable
-keep public class * extends java.lang.Exception
-keep class com.google.firebase.crashlytics.** { *; }

# App Check / Play Integrity
-keep class com.google.android.play.core.integrity.** { *; }

# Firestore
-keep class com.google.firestore.** { *; }

# Mobile Scanner
-keep class com.google.mlkit.** { *; }
-keep class com.google.android.gms.vision.** { *; }

# Prevent stripping of OTP / Auth classes
-keep class com.google.firebase.auth.** { *; }

# Keep crypto
-keep class javax.crypto.** { *; }
-keep class java.security.** { *; }

# Remove all logging in release
-assumenosideeffects class android.util.Log {
    public static int d(...);
    public static int v(...);
    public static int i(...);
}