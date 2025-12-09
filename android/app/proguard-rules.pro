# Flutter Wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Google & Firebase
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-keep class com.google.android.play.core.** { *; }
-keep class com.google.android.play.core.splitinstall.** { *; }
-keep class com.google.android.play.core.tasks.** { *; }

# Prevent R8 from stripping SplitCompatApplication (The specific error you saw)
-keep class com.google.android.play.core.splitcompat.SplitCompatApplication { *; }
-keep public class * extends com.google.android.play.core.splitcompat.SplitCompatApplication

# Your App Specific
-keep class com.pegumax.studentsuite.** { *; }